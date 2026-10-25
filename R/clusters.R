#' Cluster tables that hold the same data and propose a canonical member
#'
#' Artefact 3 of the roadmap, from profile statistics alone. Columns are
#' matched across tables by what they hold (complete value sets for small
#' code lists, value ranges, distinct rate, value shape, string lengths, and
#' name as a secondary signal), table pairs are scored by how much of each
#' table's information is found in the other, each related pair is labelled
#' (copy, filtered subset, aggregate, wider derivative, related), related
#' tables are grouped into clusters, and a canonical member is proposed for
#' each cluster with a one-line rationale. Every table also gets a class
#' (`event`, `reference`, `aggregate` or `other`) from its own shape.
#'
#' The proposals are a starting point for the warehouse owners to confirm,
#' not a verdict: see [write_cluster_decisions()] for the review file.
#' Clustering needs exact statistics, so it refuses a profile in which any
#' table was sampled.
#'
#' @section Scoring:
#' Two columns of the same type class score between 0 and 1 on the evidence
#' available for both: Jaccard overlap of complete value sets (weight 0.5),
#' overlap of ranges or, for suppressed identifiers, of string lengths
#' (0.3), closeness of distinct rate (0.2), overlap of value shapes (0.15)
#' and name similarity (0.15); missing components are left out and the
#' weights rescaled. A match needs a score of at least `min_column_score`.
#' Columns are weighted by information content (log10 of distinct count), so
#' a shared two-value flag counts for little and a shared identifier for a
#' lot. For a pair of tables, a greedy best-match assignment gives
#' `contain_a_in_b` (the share of A's information found in B), the reverse,
#' and `similarity` (their harmonic mean). Pairs with containment of at
#' least `min_containment` in either direction are related. Copy, subset,
#' wider and narrower also need a shared entity: a matched column that is
#' near-unique and mostly populated in both tables, so a table that merely
#' references this one through a foreign key is not mistaken for a copy. When
#' that shared column has identical values in both tables (equal
#' fingerprints) the rows are known to be the same rows, and the containment
#' threshold drops to 0.5 to allow for renamed or recomputed columns. Two
#' reference tables additionally need a word in common in their names.
#'
#' @section Labels:
#' With A the table being described and B the other:
#' * `copy`: containment at least `min_containment` both ways and row counts
#'   within 10 per cent; or an identical identifier column (equal
#'   fingerprints) with row counts within 10 per cent, which makes the pair
#'   a copy, wider derivative or narrower by column count alone;
#' * `filtered_subset`: A's information is in B, B's is not all in A, and A
#'   has fewer rows;
#' * `wider_derivative`: B's information is in A, A has more columns, rows
#'   within 10 per cent;
#' * `narrower`: A's information is in B, which has more columns, rows
#'   within 10 per cent (the other side of a wider derivative);
#' * `aggregate`: A is of class `aggregate` and its grouping columns are
#'   found in B, which has more rows;
#' * `related`: anything else above the thresholds.
#'
#' @section Canonical member:
#' Within a cluster, unless `schema_priority` decides it, the canonical
#' member is the one with the highest score from: a primary key candidate
#' (+2), lowest grain (log10 rows), width (log10 informative columns),
#' freshness (rank of newest datetime, up to +1), and penalties for being a
#' filtered subset (-3) or aggregate (-5) of another member.
#'
#' @param profile A `column_profile` covering every table, from a full
#'   (unsampled) run.
#' @param inventory The matching `db_inventory`, for row counts, column
#'   counts and freshness.
#' @param min_column_score Lowest column similarity that counts as a match.
#' @param min_containment Lowest containment that makes two tables related.
#' @param schema_priority Optional character vector of schemas in order of
#'   preference for the canonical member, for example `c("layer1",
#'   "derived")` to prefer source tables over cleaned copies. Tables in
#'   schemas not listed rank after those listed.
#' @param decisions Optional data frame of reviewed decisions, as read by
#'   [read_cluster_decisions()]; confirmed and rejected rows override the
#'   proposals.
#' @return A list with three tibbles: `clusters` (one row per table:
#'   `cluster_id`, `table`, `table_class`, `role`, `canonical`, `confidence`,
#'   `rationale`, `status`), `pairs` (the evidence for every related pair)
#'   and `matches` (the column matches behind the pairs).
#' @examples
#' \dontrun{
#' con <- fakehospdata::fh_connect("sample")
#' inv <- db_inventory(con, exclude = "^answers\\\\.", progress = FALSE)
#' prof <- db_profile(con, inv, sample_rows = Inf, progress = FALSE)
#' cl <- cluster_tables(prof, inv)
#' cl$clusters[cl$clusters$role != "standalone", ]
#' }
#' @export
cluster_tables <- function(profile, inventory, min_column_score = 0.7, min_containment = 0.75,
                           schema_priority = NULL, decisions = NULL) {
  p <- as.data.frame(profile, stringsAsFactors = FALSE)
  if (nrow(p) > 0 && any(isTRUE_vec(p$sampled))) {
    rlang::abort("cluster_tables() needs a full run: the profile has sampled tables. Re-run with sample_rows = Inf.")
  }
  tabs <- as.data.frame(inventory$tables, stringsAsFactors = FALSE)
  tabs$table <- paste(tabs$table_schema, tabs$table_name, sep = ".")
  if (nrow(tabs) == 0) return(empty_clusters())
  p$table <- paste(p$table_schema, p$table_name, sep = ".")
  p <- p[p$table %in% tabs$table, , drop = FALSE]

  cols <- informative_columns(p)
  tabs$table_class <- classify_tables(tabs, p)

  matches <- match_columns(cols, min_column_score)
  pairs <- score_table_pairs(matches, cols, tabs)
  pairs <- label_pairs(pairs, tabs, cols, min_containment)
  clusters <- assign_clusters(tabs, pairs, cols, min_containment, schema_priority)
  if (!is.null(decisions)) clusters <- apply_cluster_decisions(clusters, decisions)
  clusters <- add_rationale(clusters, pairs, tabs, cols)

  list(clusters = as_tbl(clusters), pairs = as_tbl(pairs), matches = as_tbl(matches))
}

# ---- columns ------------------------------------------------------------------

#' Columns that carry information about what a table holds
#' @noRd
informative_columns <- function(p) {
  keep <- p$type_class %in% c("string", "integer", "numeric", "uuid", "datetime", "date") &
    !p$semantic_type %in% c("empty", "constant") & !is.na(p$distinct_count) & p$distinct_count > 1
  c <- p[keep, , drop = FALSE]
  if (nrow(c) == 0) return(c)
  c$col_id <- seq_len(nrow(c))
  c$weight <- log10(c$distinct_count + 1)
  c$norm_name <- normalise_name(c$column_name)
  c$nonnull <- c$rows_profiled - c$null_count
  tv <- lapply(c$top_values, parse_top_values)
  c$value_set <- lapply(seq_len(nrow(c)), function(i) {
    if (!is.null(tv[[i]]) && c$distinct_count[i] <= nrow(tv[[i]])) sort(unique(tv[[i]]$value)) else NULL
  })
  c$shapes <- lapply(tv, function(t) if (is.null(t)) NULL else unique(value_shape(t$value)))
  c$range_known <- !isTRUE_vec(c$values_suppressed) & !is.na(c$min_value) & !is.na(c$max_value)
  c$num_min <- range_number(c$min_value, c$type_class)
  c$num_max <- range_number(c$max_value, c$type_class)
  c$block <- paste(c$type_class, ifelse(c$type_class %in% c("string", "uuid"), round(c$distinct_rate, 1), ""))
  c
}

#' Numbers for range comparison: numerics as given, dates and datetimes as days
#' @noRd
range_number <- function(x, type_class) {
  out <- rep(NA_real_, length(x))
  num <- type_class %in% c("integer", "numeric")
  out[num] <- as_num(x[num])
  d <- type_class == "date"
  out[d] <- suppressWarnings(as.numeric(as.Date(substr(x[d], 1, 10))))
  dt <- type_class == "datetime"
  if (any(dt)) {
    txt <- sub("T", " ", substr(x[dt], 1, 19), fixed = TRUE)
    secs <- suppressWarnings(as.numeric(as.POSIXct(txt, tz = "UTC", format = "%Y-%m-%d %H:%M:%S")))
    out[dt] <- secs / 86400          # days, so that dates and datetimes share a scale
  }
  out
}

#' Score every plausible pair of columns in different tables
#' @return data.frame(col_a, col_b, score)
#' @noRd
match_columns <- function(cols, min_column_score) {
  empty <- data.frame(col_a = integer(), col_b = integer(), score = numeric())
  if (nrow(cols) < 2) return(empty)
  out <- list()
  for (tc in unique(cols$type_class)) {
    idx <- which(cols$type_class == tc)
    if (length(idx) < 2) next
    pr <- utils::combn(idx, 2)
    a <- pr[1, ]; b <- pr[2, ]
    keep <- cols$table[a] != cols$table[b]
    a <- a[keep]; b <- b[keep]
    if (length(a) == 0) next
    s <- column_score(cols, a, b)
    ok <- !is.na(s) & s >= min_column_score
    if (any(ok)) out[[tc]] <- data.frame(col_a = cols$col_id[a[ok]], col_b = cols$col_id[b[ok]], score = s[ok])
  }
  if (length(out) == 0) return(empty)
  do.call(rbind, out)
}

#' Vectorised similarity of column pairs (same type class assumed)
#' @noRd
column_score <- function(cols, a, b) {
  n <- length(a)
  num <- matrix(0, n, 5); den <- matrix(0, n, 5)
  w <- c(values = 0.5, range = 0.3, rate = 0.2, shape = 0.15, name = 0.15)

  # complete value sets
  va <- cols$value_set[a]; vb <- cols$value_set[b]
  has <- !vapply(va, is.null, logical(1)) & !vapply(vb, is.null, logical(1))
  if (any(has)) {
    j <- vapply(which(has), function(i) {
      u <- union(va[[i]], vb[[i]]); if (length(u) == 0) 0 else length(intersect(va[[i]], vb[[i]])) / length(u)
    }, numeric(1))
    num[has, 1] <- w["values"] * j; den[has, 1] <- w["values"]
  }
  # ranges, or lengths for suppressed strings
  rk <- cols$range_known[a] & cols$range_known[b]
  numeric_like <- cols$type_class[a] %in% c("integer", "numeric", "date", "datetime")
  r1 <- rk & numeric_like & !is.na(cols$num_min[a]) & !is.na(cols$num_min[b]) & !is.na(cols$num_max[a]) & !is.na(cols$num_max[b])
  if (any(r1)) {
    lo <- pmax(cols$num_min[a[r1]], cols$num_min[b[r1]]); hi <- pmin(cols$num_max[a[r1]], cols$num_max[b[r1]])
    ulo <- pmin(cols$num_min[a[r1]], cols$num_min[b[r1]]); uhi <- pmax(cols$num_max[a[r1]], cols$num_max[b[r1]])
    ov <- ifelse(uhi > ulo, pmax(0, hi - lo) / (uhi - ulo), as.numeric(hi >= lo))
    # a copy has exactly the same extremes; columns that merely span the same
    # period (every timestamp in a warehouse does) earn much less
    exact <- cols$num_min[a[r1]] == cols$num_min[b[r1]] & cols$num_max[a[r1]] == cols$num_max[b[r1]]
    num[r1, 2] <- w["range"] * ifelse(exact, 1, 0.6 * ov); den[r1, 2] <- w["range"]
  }
  r2 <- rk & !numeric_like
  if (any(r2)) {
    same <- cols$min_value[a[r2]] == cols$min_value[b[r2]] & cols$max_value[a[r2]] == cols$max_value[b[r2]]
    overlap <- cols$min_value[a[r2]] <= cols$max_value[b[r2]] & cols$min_value[b[r2]] <= cols$max_value[a[r2]]
    num[r2, 2] <- w["range"] * ifelse(same, 1, ifelse(overlap, 0.5, 0)); den[r2, 2] <- w["range"]
  }
  r3 <- !rk & !is.na(cols$min_length[a]) & !is.na(cols$min_length[b]) & !is.na(cols$max_length[a]) & !is.na(cols$max_length[b])
  if (any(r3)) {
    same <- cols$min_length[a[r3]] == cols$min_length[b[r3]] & cols$max_length[a[r3]] == cols$max_length[b[r3]]
    overlap <- cols$min_length[a[r3]] <= cols$max_length[b[r3]] & cols$min_length[b[r3]] <= cols$max_length[a[r3]]
    num[r3, 2] <- w["range"] * ifelse(same, 1, ifelse(overlap, 0.5, 0)); den[r3, 2] <- w["range"]
  }
  # distinct rate
  rt <- !is.na(cols$distinct_rate[a]) & !is.na(cols$distinct_rate[b])
  num[rt, 3] <- w["rate"] * (1 - abs(cols$distinct_rate[a[rt]] - cols$distinct_rate[b[rt]])); den[rt, 3] <- w["rate"]
  # shapes
  sa <- cols$shapes[a]; sb <- cols$shapes[b]
  hs <- !vapply(sa, is.null, logical(1)) & !vapply(sb, is.null, logical(1))
  if (any(hs)) {
    j <- vapply(which(hs), function(i) length(intersect(sa[[i]], sb[[i]])) / length(union(sa[[i]], sb[[i]])), numeric(1))
    num[hs, 4] <- w["shape"] * j; den[hs, 4] <- w["shape"]
  }
  # names
  na_ <- cols$norm_name[a]; nb_ <- cols$norm_name[b]
  contains <- mapply(function(x, y) nchar(x) >= 3 && nchar(y) >= 3 && (grepl(x, y, fixed = TRUE) || grepl(y, x, fixed = TRUE)), na_, nb_, USE.NAMES = FALSE)
  nm <- ifelse(na_ == nb_, 1, ifelse(contains, 0.5, 0))
  num[, 5] <- w["name"] * nm; den[, 5] <- w["name"]

  d <- rowSums(den)
  score <- ifelse(d > 0, rowSums(num) / d, NA_real_)
  # Suppressed identifiers carry no values here, but their fingerprints were
  # hashed before suppression: equal fingerprints mean the same values, and
  # count as a full match. Otherwise, with length as the only evidence, a
  # match needs the names to agree.
  no_values <- !has & !rk
  same_fp <- !is.na(cols$value_fingerprint[a]) & !is.na(cols$value_fingerprint[b]) & cols$value_fingerprint[a] == cols$value_fingerprint[b]
  score[no_values & same_fp] <- 1
  score[no_values & !same_fp & nm == 0] <- pmin(score[no_values & !same_fp & nm == 0], 0.5)
  score
}

# ---- table pairs --------------------------------------------------------------

#' Containment and similarity for every pair of tables with matched columns
#' @noRd
score_table_pairs <- function(matches, cols, tabs) {
  empty <- data.frame(table_a = character(), table_b = character(), n_matches = integer(),
                      contain_a_in_b = numeric(), contain_b_in_a = numeric(), similarity = numeric(),
                      shared_key = logical(), shared_entity = logical(), shared_entity_exact = logical(), stringsAsFactors = FALSE)
  if (nrow(matches) == 0) return(empty)
  m <- matches
  m$table_a <- cols$table[m$col_a]; m$table_b <- cols$table[m$col_b]
  swap <- m$table_a > m$table_b
  m[swap, c("col_a", "col_b", "table_a", "table_b")] <- m[swap, c("col_b", "col_a", "table_b", "table_a")]
  weight_of <- stats::setNames(tapply(cols$weight, cols$table, sum), NULL)
  names(weight_of) <- names(tapply(cols$weight, cols$table, sum))
  out <- lapply(split(m, paste(m$table_a, m$table_b, sep = "\r")), function(g) {
    g <- g[order(-g$score), ]
    used_a <- character(); used_b <- character(); keep <- logical(nrow(g))
    for (i in seq_len(nrow(g))) {           # greedy one-to-one assignment
      if (!g$col_a[i] %in% used_a && !g$col_b[i] %in% used_b) {
        keep[i] <- TRUE; used_a <- c(used_a, g$col_a[i]); used_b <- c(used_b, g$col_b[i])
      }
    }
    g <- g[keep, , drop = FALSE]
    wa <- cols$weight[g$col_a]; wb <- cols$weight[g$col_b]
    ca <- sum(wa * g$score) / weight_of[[g$table_a[1]]]
    cb <- sum(wb * g$score) / weight_of[[g$table_b[1]]]
    data.frame(
      table_a = g$table_a[1], table_b = g$table_b[1], n_matches = nrow(g),
      contain_a_in_b = min(1, ca), contain_b_in_a = min(1, cb),
      similarity = if (ca + cb > 0) 2 * ca * cb / (ca + cb) else 0,
      shared_key = any(isTRUE_vec(cols$pk_candidate[g$col_a]) & isTRUE_vec(cols$pk_candidate[g$col_b])),
      # a matched column that is near-unique in both tables: the same entity at the same grain,
      # which is what separates a copy or subset from a table that merely references this one
      shared_entity = any(!is.na(cols$distinct_rate[g$col_a]) & !is.na(cols$distinct_rate[g$col_b]) &
                            cols$distinct_rate[g$col_a] >= 0.9 & cols$distinct_rate[g$col_b] >= 0.9 &
                            cols$null_rate[g$col_a] <= 0.5 & cols$null_rate[g$col_b] <= 0.5),
      # the same identifier values in both (equal fingerprints): the rows are the same rows
      shared_entity_exact = any(!is.na(cols$distinct_rate[g$col_a]) & !is.na(cols$distinct_rate[g$col_b]) &
                                  cols$distinct_rate[g$col_a] >= 0.9 & cols$distinct_rate[g$col_b] >= 0.9 &
                                  cols$null_rate[g$col_a] <= 0.5 & cols$null_rate[g$col_b] <= 0.5 &
                                  !is.na(cols$value_fingerprint[g$col_a]) & !is.na(cols$value_fingerprint[g$col_b]) &
                                  cols$value_fingerprint[g$col_a] == cols$value_fingerprint[g$col_b]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

#' Label each related pair from both sides
#' @noRd
label_pairs <- function(pairs, tabs, cols, min_containment) {
  pairs$relationship_a <- rep(NA_character_, nrow(pairs))   # what A is, relative to B
  pairs$relationship_b <- rep(NA_character_, nrow(pairs))
  if (nrow(pairs) == 0) return(pairs)
  info <- function(t, what) tabs[[what]][match(t, tabs$table)]
  n_cols <- stats::setNames(as.integer(table(factor(cols$table, levels = tabs$table))), tabs$table)
  rows_a <- info(pairs$table_a, "row_count"); rows_b <- info(pairs$table_b, "row_count")
  class_a <- info(pairs$table_a, "table_class"); class_b <- info(pairs$table_b, "table_class")
  # two code lists can share codes and even descriptions (NHS admission source
  # and discharge destination do), so between reference tables the names must
  # also agree before one is called a copy or subset of the other
  names_agree <- mapply(table_names_agree, pairs$table_a, pairs$table_b, USE.NAMES = FALSE)
  entity <- pairs$shared_entity & !(class_a == "reference" & class_b == "reference" & !names_agree)
  # when the rows are known to be the same rows (an identical identifier), the
  # other columns may be renamed or recomputed, so less of them need to match
  thr <- ifelse(pairs$shared_entity_exact & entity, min(min_containment, 0.5), min_containment)
  for (i in seq_len(nrow(pairs))) {
    exact <- pairs$shared_entity_exact[i] && entity[i]
    pairs$relationship_a[i] <- relationship(pairs$contain_a_in_b[i], pairs$contain_b_in_a[i], rows_a[i], rows_b[i],
                                            n_cols[[pairs$table_a[i]]], n_cols[[pairs$table_b[i]]], class_a[i],
                                            entity[i], exact, thr[i])
    pairs$relationship_b[i] <- relationship(pairs$contain_b_in_a[i], pairs$contain_a_in_b[i], rows_b[i], rows_a[i],
                                            n_cols[[pairs$table_b[i]]], n_cols[[pairs$table_a[i]]], class_b[i],
                                            entity[i], exact, thr[i])
  }
  related <- pairs$contain_a_in_b >= thr | pairs$contain_b_in_a >= thr | (pairs$shared_entity_exact & entity)
  pairs[related, , drop = FALSE]
}

relationship <- function(c_in_other, other_in_me, rows, rows_other, ncol, ncol_other, class_me, shared_entity, exact, min_containment) {
  above <- c_in_other >= min_containment || other_in_me >= min_containment
  if (is.na(rows) || is.na(rows_other)) return(if (above) "related" else "unrelated")
  similar_rows <- rows >= 0.9 * rows_other & rows <= 1.1 * rows_other
  if (exact && similar_rows) {
    # the same identifier values and the same number of rows: the same rows,
    # however many of the other columns were renamed or recomputed
    if (c_in_other >= 0.5 && other_in_me >= 0.5) return("copy")
    if (ncol > ncol_other) return("wider_derivative")
    if (ncol < ncol_other) return("narrower")
    return("copy")
  }
  if (class_me == "aggregate" && c_in_other >= 0.8 && rows < 0.9 * rows_other) return("aggregate")
  if (shared_entity) {
    if (c_in_other >= min_containment && other_in_me >= min_containment && similar_rows) return("copy")
    if (c_in_other >= min_containment && rows < 0.9 * rows_other) return("filtered_subset")
    if (other_in_me >= min_containment && ncol > ncol_other && rows >= 0.9 * rows_other) return("wider_derivative")
    if (c_in_other >= min_containment && ncol < ncol_other && similar_rows) return("narrower")
  }
  if (above) "related" else "unrelated"
}

# ---- table classes ------------------------------------------------------------

#' A class for each table from its own shape: event, reference, aggregate, other
#' @noRd
classify_tables <- function(tabs, p) {
  vapply(tabs$table, function(t) {
    cols <- p[p$table == t, , drop = FALSE]
    rows <- tabs$row_count[tabs$table == t]
    if (nrow(cols) == 0) return("other")
    sem <- cols$semantic_type
    has_id <- any(sem == "identifier" & !is.na(cols$distinct_rate) & cols$distinct_rate > 0.5)
    has_pk <- any(isTRUE_vec(cols$pk_candidate))
    has_date <- any(cols$type_class %in% c("date", "datetime"))
    has_measure <- any(sem %in% c("count", "measure"))
    n_codes <- sum(sem %in% c("code", "category"))
    if (!has_id && has_measure && (has_date || n_codes > 0)) return("aggregate")
    if (!is.na(rows) && rows <= 2000 && has_pk && !has_date && sum(sem %in% c("code", "category", "flag", "free_text", "identifier")) >= nrow(cols) * 0.5) return("reference")
    if (has_id || has_pk) return("event")
    "other"
  }, character(1), USE.NAMES = FALSE)
}

# ---- clusters -----------------------------------------------------------------

assign_clusters <- function(tabs, pairs, cols, min_containment, schema_priority) {
  n <- nrow(tabs)
  parent <- seq_len(n)
  find <- function(i) { while (parent[i] != i) { parent[i] <<- parent[parent[i]]; i <- parent[i] }; i }
  joins <- c("copy", "filtered_subset", "wider_derivative", "narrower", "aggregate")
  if (nrow(pairs) > 0) {
    for (i in which(pairs$relationship_a %in% joins | pairs$relationship_b %in% joins)) {
      a <- match(pairs$table_a[i], tabs$table); b <- match(pairs$table_b[i], tabs$table)
      ra <- find(a); rb <- find(b)
      if (ra != rb) parent[ra] <- rb
    }
  }
  root <- vapply(seq_len(n), find, integer(1))
  cluster_id <- match(root, unique(root[order(tabs$table)]))

  out <- data.frame(
    cluster_id = cluster_id, table = tabs$table, table_schema = tabs$table_schema, table_name = tabs$table_name,
    table_class = tabs$table_class, row_count = tabs$row_count, n_columns = tabs$n_columns,
    newest_datetime = tabs$newest_datetime, role = "standalone", canonical = tabs$table,
    confidence = NA_real_, rationale = NA_character_, status = "proposed", stringsAsFactors = FALSE
  )
  has_pk <- tapply(isTRUE_vec(cols$pk_candidate), factor(cols$table, levels = tabs$table), any)
  has_pk[is.na(has_pk)] <- FALSE
  n_info <- as.integer(table(factor(cols$table, levels = tabs$table)))

  for (cid in unique(cluster_id)) {
    members <- which(cluster_id == cid)
    if (length(members) < 2) next
    m <- out[members, ]
    score <- rep(0, length(members))
    score <- score + ifelse(has_pk[m$table], 2, 0)
    score <- score + log10(pmax(m$row_count, 1))
    score <- score + log10(n_info[members] + 1)
    fresh <- rank(ifelse(is.na(m$newest_datetime), "", m$newest_datetime), ties.method = "min")
    score <- score + (fresh - 1) / max(1, length(members) - 1)
    for (j in seq_along(members)) {
      rel <- member_relationships(m$table[j], pairs)
      if (any(rel == "filtered_subset")) score[j] <- score[j] - 3
      if (any(rel == "aggregate")) score[j] <- score[j] - 5
    }
    if (!is.null(schema_priority)) {
      pr <- match(m$table_schema, schema_priority); pr[is.na(pr)] <- length(schema_priority) + 1
      score <- score - 100 * pr          # schema order decides, score breaks ties
    }
    best <- members[order(-score, m$table)[1]]
    out$canonical[members] <- out$table[best]
    out$role[best] <- "canonical"
    for (j in members[members != best]) {
      out$role[j] <- role_towards(out$table[j], out$table[best], pairs)
    }
    sc <- sort(score, decreasing = TRUE)
    out$confidence[members] <- if (length(sc) > 1) round(min(1, (sc[1] - sc[2]) / 3), 2) else 1
  }
  out
}

#' Do two table names share a word? "pas_referrals" and "derived_referrals" do
#' @noRd
table_names_agree <- function(a, b) {
  tok <- function(x) {
    x <- sub("^[^.]*\\.", "", x)
    w <- strsplit(gsub("[^a-z0-9]+", " ", tolower(x)), " ")[[1]]
    w <- sub("ies$", "y", w); w <- sub("([^s])s$", "\\1", w)
    setdiff(w[nchar(w) >= 3], c("pas", "ref", "dim", "fact", "tbl", "derived", "agg"))
  }
  length(intersect(tok(a), tok(b))) > 0
}

member_relationships <- function(t, pairs) {
  if (nrow(pairs) == 0) return(character())
  c(pairs$relationship_a[pairs$table_a == t], pairs$relationship_b[pairs$table_b == t])
}

#' The role of table t relative to the canonical member c, from their pair if any
#' @noRd
role_towards <- function(t, c, pairs) {
  i <- which(pairs$table_a == t & pairs$table_b == c)
  if (length(i) == 1) return(pairs$relationship_a[i])
  i <- which(pairs$table_b == t & pairs$table_a == c)
  if (length(i) == 1) return(pairs$relationship_b[i])
  "related"
}

add_rationale <- function(clusters, pairs, tabs, cols) {
  fmt <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
  for (cid in unique(clusters$cluster_id)) {
    members <- which(clusters$cluster_id == cid)
    if (length(members) < 2) next
    can <- members[clusters$role[members] == "canonical"]
    if (length(can) != 1) next
    others <- members[members != can]
    c_name <- clusters$table[can]
    has_key <- any(isTRUE_vec(cols$pk_candidate[cols$table == c_name]))
    why <- paste0(
      "Chosen: ", fmt(clusters$row_count[can]), " rows, ", clusters$n_columns[can], " columns",
      if (has_key) ", has a key candidate" else "",
      if (!is.na(clusters$newest_datetime[can])) paste0(", newest ", substr(clusters$newest_datetime[can], 1, 10)) else "",
      if (clusters$status[can] == "confirmed") " (confirmed by review)" else "", "."
    )
    rest <- vapply(others, function(j) {
      paste0(clusters$table[j], ": ", gsub("_", " ", clusters$role[j]), " (", fmt(clusters$row_count[j]), " rows, ", clusters$n_columns[j], " columns)")
    }, character(1))
    clusters$rationale[members] <- paste(why, paste(rest, collapse = "; "))
  }
  clusters
}

empty_clusters <- function() {
  list(
    clusters = tibble::tibble(cluster_id = integer(), table = character(), table_schema = character(), table_name = character(),
                              table_class = character(), row_count = numeric(), n_columns = integer(), newest_datetime = character(),
                              role = character(), canonical = character(), confidence = numeric(), rationale = character(), status = character()),
    pairs = tibble::tibble(table_a = character(), table_b = character(), n_matches = integer(), contain_a_in_b = numeric(),
                           contain_b_in_a = numeric(), similarity = numeric(), shared_key = logical(), shared_entity = logical(), shared_entity_exact = logical(),
                           relationship_a = character(), relationship_b = character()),
    matches = tibble::tibble(col_a = integer(), col_b = integer(), score = numeric())
  )
}

# ---- review file ---------------------------------------------------------------

#' Write and read the cluster review file
#'
#' The review file is a CSV the warehouse owners edit: one row per table with
#' the proposed cluster, role and canonical member, a `status` column
#' (`proposed`, `confirmed` or `rejected`) and a `note`. Writing merges with
#' an existing file so that decisions already made are kept and only new
#' tables are added as `proposed`. Reading returns the decisions for
#' [cluster_tables()], where a `confirmed` row fixes that table's canonical
#' member and a `rejected` row takes the table out of its cluster.
#'
#' @param clusters The `clusters` tibble from [cluster_tables()].
#' @param path Path of the CSV file.
#' @return `write_cluster_decisions()` returns the merged data frame
#'   invisibly; `read_cluster_decisions()` returns a data frame, or `NULL` if
#'   the file does not exist.
#' @export
write_cluster_decisions <- function(clusters, path) {
  new <- data.frame(table = clusters$table, cluster_id = clusters$cluster_id, role = clusters$role,
                    canonical = clusters$canonical, status = "proposed", note = "", stringsAsFactors = FALSE)
  if (file.exists(path)) {
    old <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = character())
    keep <- old[old$table %in% new$table & old$status != "proposed", , drop = FALSE]
    new <- new[!new$table %in% keep$table, , drop = FALSE]
    new <- rbind(keep[, names(new)], new)
  }
  new <- new[order(new$cluster_id, new$table), ]
  utils::write.csv(new, path, row.names = FALSE)
  invisible(new)
}

#' @rdname write_cluster_decisions
#' @export
read_cluster_decisions <- function(path) {
  if (!file.exists(path)) return(NULL)
  d <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = character())
  needed <- c("table", "status")
  if (!all(needed %in% names(d))) rlang::abort(paste("The decisions file needs columns:", paste(needed, collapse = ", ")))
  d
}

apply_cluster_decisions <- function(clusters, decisions) {
  d <- decisions[decisions$status %in% c("confirmed", "rejected"), , drop = FALSE]
  for (i in seq_len(nrow(d))) {
    j <- which(clusters$table == d$table[i])
    if (length(j) != 1) next
    if (d$status[i] == "rejected") {
      clusters$cluster_id[j] <- max(clusters$cluster_id) + 1L
      clusters$role[j] <- "standalone"; clusters$canonical[j] <- clusters$table[j]
      clusters$status[j] <- "rejected"
    } else if (d$status[i] == "confirmed" && "canonical" %in% names(d) && nzchar(d$canonical[i]) && d$canonical[i] %in% clusters$table) {
      members <- which(clusters$cluster_id == clusters$cluster_id[j])
      clusters$canonical[members] <- d$canonical[i]
      clusters$role[members] <- ifelse(clusters$table[members] == d$canonical[i], "canonical",
                                       ifelse(clusters$role[members] == "canonical", "related", clusters$role[members]))
      clusters$status[j] <- "confirmed"
    }
  }
  clusters
}
