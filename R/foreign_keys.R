#' Propose foreign key relationships from the column profile
#'
#' Tier-one inference, from profile statistics alone and without extra
#' queries. Every column of a string, integer or uuid type is scored against
#' every `pk_candidate` column in another table (or another column of the same
#' table), and the best-scoring target above `min_confidence` is recorded.
#' Confirming a candidate with a value match-rate query is the key register's
#' job, later; this is the shortlist for it.
#'
#' A pair is ruled out when the types differ, the child's string lengths fall
#' outside the key's, the child is itself unique and shares the key's
#' `value_fingerprint` (a copy, not a reference), or the key is a small code
#' list whose full value set is known and the child's top values include a
#' value outside it, or the shapes of the two columns' top values (digits,
#' letters, other characters) do not overlap. Flag columns are never children.
#' Surviving pairs score:
#'
#' * name evidence: 0.5 for the same normalised name, 0.35 when the child name
#'   ends with the key name (`prior_mrn` to `mrn`; generic endings such as
#'   `id`, `code` or `name` do not count), 0.2 when it contains the key's
#'   table stem (`main_site` to `sites.site_code`). A key in the child's own
#'   table needs exact or suffix name evidence;
#' * values: 0.3 when the key's full value set is known (its distinct count is
#'   within the recorded top values) and every top value of the child is in it;
#' * range: 0.25 when both ranges are known and the child's min and max lie
#'   inside the key's, -0.25 when they do not; nothing when either side's
#'   values are suppressed or the key table was sampled;
#' * cardinality: 0.15 for a many-to-one shape (the child has no more distinct
#'   values than the key and is not itself unique), 0.05 for one-to-one;
#'   skipped when either table was sampled;
#' * 0.1 for passing the type and length checks at all.
#'
#' Scores are capped at 1. Ties go to the key with more distinct values.
#'
#' @param profile A `column_profile` from [db_profile()], ideally covering
#'   every table of interest: a key in a table that is not in `profile`
#'   cannot be proposed.
#' @param min_confidence Lowest score that counts as a candidate.
#' @return `profile` with `fk_candidate` (logical), `fk_target`
#'   (`schema.table.column` of the best key, or `NA`), `fk_confidence`,
#'   `fk_evidence` (the scoring components as text) and `fk_n_targets` (how
#'   many keys scored at or above `min_confidence`; a conformed code such as a
#'   site code legitimately matches several) added or replaced.
#' @examples
#' con <- fakehosp_connection()
#' inv <- db_inventory(con, include = c("pas_patients$", "pas_adt_events$"), progress = FALSE)
#' prof <- db_profile(con, inv, progress = FALSE)
#' prof[prof$fk_candidate, c("table_name", "column_name", "fk_target", "fk_confidence")]
#' DBI::dbDisconnect(con)
#' @export
infer_foreign_keys <- function(profile, min_confidence = 0.5) {
  p <- as.data.frame(profile, stringsAsFactors = FALSE)
  n <- nrow(p)
  p$fk_candidate <- rep(FALSE, n)
  p$fk_target <- rep(NA_character_, n)
  p$fk_confidence <- rep(NA_real_, n)
  p$fk_evidence <- rep(NA_character_, n)
  p$fk_n_targets <- rep(0L, n)
  if (n == 0) return(restore_profile_class(p, profile))

  key_types <- c("string", "integer", "uuid")
  keys <- p[isTRUE_vec(p$pk_candidate) & p$type_class %in% key_types & p$rows_profiled >= 2, , drop = FALSE]
  if (nrow(keys) == 0) return(restore_profile_class(p, profile))

  keys$full <- paste(keys$table_schema, keys$table_name, keys$column_name, sep = ".")
  keys$tab <- paste(keys$table_schema, keys$table_name, sep = ".")
  keys$norm_name <- normalise_name(keys$column_name)
  keys$stem <- table_stem(keys$table_name)
  keys$range_known <- !isTRUE_vec(keys$values_suppressed) & !isTRUE_vec(keys$sampled) &
    !is.na(keys$min_value) & !is.na(keys$max_value)
  # the complete value set of a small code list, when its top values cover every distinct value
  key_values <- lapply(seq_len(nrow(keys)), function(j) {
    tv <- parse_top_values(keys$top_values[j])
    if (!is.null(tv) && !is.na(keys$distinct_count[j]) && keys$distinct_count[j] <= nrow(tv) && !isTRUE(keys$sampled[j])) tv$value else NULL
  })
  keys$values_known <- !vapply(key_values, is.null, logical(1))
  key_shapes <- lapply(seq_len(nrow(keys)), function(j) {
    tv <- parse_top_values(keys$top_values[j])
    if (is.null(tv)) NULL else unique(value_shape(tv$value))
  })

  children <- which(p$type_class %in% key_types & !p$semantic_type %in% c("empty", "flag") &
    !is.na(p$rows_profiled) & (p$rows_profiled - p$null_count) > 0)

  for (i in children) {
    c_tab <- paste(p$table_schema[i], p$table_name[i], sep = ".")
    c_full <- paste(c_tab, p$column_name[i], sep = ".")
    k <- keys[keys$full != c_full & keys$type_class == p$type_class[i], , drop = FALSE]
    if (nrow(k) == 0) next

    # ---- hard filters ------------------------------------------------------
    # a unique child with the key's fingerprint is a copy of it, not a reference
    is_copy <- isTRUE(p$is_unique[i]) & !is.na(k$value_fingerprint) & !is.na(p$value_fingerprint[i]) &
      k$value_fingerprint == p$value_fingerprint[i]
    keep <- !is_copy
    if (p$type_class[i] == "string") {
      len_ok <- is.na(p$min_length[i]) | is.na(k$min_length) | is.na(p$max_length[i]) | is.na(k$max_length) |
        (p$min_length[i] >= k$min_length & p$max_length[i] <= k$max_length)
      keep <- keep & len_ok
    }
    # membership against a key whose whole value set is known, and a shape check
    # (digits, letters, other) so that "100" cannot reference "Ward 3"
    child_top <- parse_top_values(p$top_values[i])
    values_within <- rep(NA, nrow(k))
    if (!is.null(child_top)) {
      idx <- match(k$full, keys$full)
      values_within <- vapply(key_values[idx], function(v) if (is.null(v)) NA else all(child_top$value %in% v), logical(1))
      keep <- keep & (is.na(values_within) | values_within)
      child_shapes <- unique(value_shape(child_top$value))
      shape_ok <- vapply(key_shapes[idx], function(ks) is.null(ks) || any(child_shapes %in% ks), logical(1))
      keep <- keep & shape_ok
    }
    # a key in the child's own table is only a self-reference if the names say so
    same_table <- k$tab == c_tab
    k <- k[keep, , drop = FALSE]
    values_within <- values_within[keep]
    same_table <- same_table[keep]
    if (nrow(k) == 0) next

    # ---- scoring -----------------------------------------------------------
    c_norm <- normalise_name(p$column_name[i])
    name_exact <- k$norm_name == c_norm
    name_suffix <- !name_exact & nchar(k$norm_name) >= 2 & !k$norm_name %in% generic_name_parts & endsWith(c_norm, k$norm_name)
    name_stem <- !name_exact & !name_suffix & nchar(k$stem) >= 3 &
      vapply(k$stem, function(st) grepl(st, c_norm, fixed = TRUE), logical(1), USE.NAMES = FALSE)
    name_score <- ifelse(name_exact, 0.5, ifelse(name_suffix, 0.35, ifelse(name_stem, 0.2, 0)))
    name_text <- ifelse(name_exact, "name=exact", ifelse(name_suffix, "name=suffix", ifelse(name_stem, "name=stem", "name=none")))

    child_range_known <- !isTRUE(p$values_suppressed[i]) && !is.na(p$min_value[i]) && !is.na(p$max_value[i])
    within <- rep(NA, nrow(k))
    if (child_range_known) {
      known <- k$range_known
      if (p$type_class[i] == "integer") {
        cmin <- as_num(p$min_value[i]); cmax <- as_num(p$max_value[i])
        within[known] <- cmin >= as_num(k$min_value[known]) & cmax <= as_num(k$max_value[known])
      } else {
        within[known] <- p$min_value[i] >= k$min_value[known] & p$max_value[i] <= k$max_value[known]
      }
    }
    range_score <- ifelse(is.na(within), 0, ifelse(within, 0.25, -0.25))
    range_text <- ifelse(is.na(within), "range=unknown", ifelse(within, "range=within", "range=outside"))

    card_known <- !isTRUE(p$sampled[i]) & !isTRUE_vec(k$sampled) & !is.na(p$distinct_count[i]) & !is.na(k$distinct_count)
    many_to_one <- card_known & p$distinct_count[i] <= k$distinct_count & !isTRUE(p$is_unique[i])
    one_to_one <- card_known & p$distinct_count[i] <= k$distinct_count & isTRUE(p$is_unique[i])
    card_score <- ifelse(many_to_one, 0.15, ifelse(one_to_one, 0.05, 0))
    card_text <- ifelse(many_to_one, "cardinality=many_to_one", ifelse(one_to_one, "cardinality=one_to_one",
      ifelse(card_known, "cardinality=child_wider", "cardinality=unknown")))

    values_score <- ifelse(isTRUE_vec(values_within), 0.3, 0)
    values_text <- ifelse(isTRUE_vec(values_within), "values=within", "values=unknown")

    score <- pmin(1, 0.1 + name_score + values_score + range_score + card_score)
    score[same_table & !(name_exact | name_suffix)] <- 0
    ok <- score >= min_confidence
    p$fk_n_targets[i] <- sum(ok)
    if (!any(ok)) next
    best <- order(-score, -k$distinct_count, k$full)[1]
    p$fk_candidate[i] <- TRUE
    p$fk_target[i] <- k$full[best]
    p$fk_confidence[i] <- round(score[best], 2)
    p$fk_evidence[i] <- paste(name_text[best], values_text[best], range_text[best], card_text[best], sep = "; ")
  }
  restore_profile_class(p, profile)
}

isTRUE_vec <- function(x) !is.na(x) & as.logical(x)

#' The singular, normalised stem of a table name: "pas_referrals" -> "referral"
#' @noRd
table_stem <- function(x) {
  s <- normalise_name(sub("^(pas|ed|ris|endo|dim|fact|ref|tbl|vw|v|agg|derived|stg)_", "", tolower(x)))
  s <- sub("ies$", "y", s)
  s <- sub("([^s])s$", "\\1", s)
  s
}

restore_profile_class <- function(p, original) {
  out <- as_tbl(p)
  if (inherits(original, "column_profile")) class(out) <- c("column_profile", class(out))
  out
}

parse_top_values <- function(json) {
  if (is.null(json) || is.na(json)) return(NULL)
  tv <- tryCatch(jsonlite::fromJSON(json), error = function(e) NULL)
  if (is.null(tv) || !is.data.frame(tv) || nrow(tv) == 0) return(NULL)
  tv$value <- as.character(tv$value)
  tv
}

generic_name_parts <- c("id", "code", "name", "key", "no", "num", "number", "ref", "type", "desc",
                        "description", "value", "status", "date", "datetime", "time", "flag", "ind", "indicator")

#' The shape of a value: digits to 9, letters to A, everything else kept
#' @noRd
value_shape <- function(x) {
  x <- gsub("[0-9]", "9", as.character(x))
  x <- gsub("[A-Za-z]", "A", x)
  gsub("(9)9+", "9", gsub("(A)A+", "A", x))   # collapse runs so "RX1" and "RXH" share a shape
}
