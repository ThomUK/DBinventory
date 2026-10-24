#' Propose foreign key relationships from the column profile
#'
#' Tier-one inference, from profile statistics alone and without extra
#' queries. Every column of a string, integer or uuid type is scored against
#' every `pk_candidate` column in another table (or another column of the same
#' table), and the best-scoring target at or above `min_confidence` is
#' recorded. These are candidates only: a shortlist for the key register's
#' match-rate tests, which are the only thing that can confirm a relationship.
#'
#' @section Exclusions:
#' A pair is ruled out, whatever else it scores, when:
#' * the type classes differ, or the child's string lengths fall outside the
#'   key's;
#' * the child is itself unique and shares the key's `value_fingerprint`: that
#'   is a copy of the key, which belongs in the duplicate map;
#' * the key's complete value set is known (its distinct count is within the
#'   values recorded for it) and a top value of the child is not in it;
#' * the key's table was profiled in full and the child has more distinct
#'   values than the key;
#' * the shapes of the two columns' top values (runs of digits, letters and
#'   other characters) do not overlap, so `100` cannot reference `Ward 3`;
#' * the child is a flag, or is empty;
#' * the key is in the child's own table and the names do not say it is a
#'   self-reference (exact or suffix match);
#' * the child is itself a `pk_candidate` and there is no name evidence: a key
#'   that merely resembles another key is a coincidence or a copy.
#'
#' @section Scoring:
#' Surviving pairs start at 0.1 and add:
#' * name evidence: 0.45 for the same normalised name, 0.3 when the child name
#'   ends with the key name (`prior_mrn` to `mrn`), 0.2 when it contains the
#'   key's table stem (`main_site` to `sites.site_code`). Generic column names
#'   such as `id`, `code`, `name` or `description` earn nothing on their own;
#'   their keys are reached through the table stem;
#' * values: when the key's complete value set is known and every top value of
#'   the child is in it, 0.4 times the share of the key's values the child
#'   uses, so a child that uses all of a code list scores more than one that
#'   uses two of its seven codes;
#' * range: when the value set is not known but both ranges are, 0.25 if the
#'   child's min and max lie inside the key's and -0.25 if they do not;
#' * cardinality, when the key's table was profiled in full: 0.15 for a
#'   many-to-one shape, 0.05 for one-to-one unless the child is itself a
#'   `pk_candidate`;
#' * 0.1 when both columns have the same minimum and maximum string length,
#'   unless the child is itself a `pk_candidate`.
#'
#' Scores are capped at 1. Ties go to the key with the fewest distinct values
#' when membership is known (the tightest fit) and the most when it is not (a
#' table rather than a view of it), then by name. `fk_n_targets` counts how many keys
#' reached the threshold, since a conformed code such as a site code
#' legitimately matches several.
#'
#' @param profile A `column_profile` from [db_profile()], ideally covering
#'   every table of interest: a key in a table that is not in `profile`
#'   cannot be proposed.
#' @param min_confidence Lowest score that counts as a candidate.
#' @return `profile` with `fk_candidate` (logical), `fk_target`
#'   (`schema.table.column` of the best key, or `NA`), `fk_confidence`,
#'   `fk_evidence` (the scoring components as text) and `fk_n_targets` added
#'   or replaced.
#' @examples
#' \dontrun{
#' con <- fakehospdata::fh_connect("sample")
#' inv <- db_inventory(con, include = c("pas_patients$", "pas_adt_events$"), progress = FALSE)
#' prof <- db_profile(con, inv, progress = FALSE)
#' prof[prof$fk_candidate, c("table_name", "column_name", "fk_target", "fk_confidence")]
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' }
#' @export
infer_foreign_keys <- function(profile, min_confidence = 0.6) {
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
  keys$generic <- keys$norm_name %in% generic_name_parts
  keys$stem <- table_stem(keys$table_name)
  keys$full_table <- !isTRUE_vec(keys$sampled)
  keys$range_known <- !isTRUE_vec(keys$values_suppressed) & keys$full_table & !is.na(keys$min_value) & !is.na(keys$max_value)
  key_top <- lapply(keys$top_values, parse_top_values)
  key_values <- lapply(seq_len(nrow(keys)), function(j) {
    tv <- key_top[[j]]
    if (!is.null(tv) && !is.na(keys$distinct_count[j]) && keys$distinct_count[j] <= nrow(tv) && keys$full_table[j]) tv$value else NULL
  })
  key_shapes <- lapply(key_top, function(tv) if (is.null(tv)) NULL else unique(value_shape(tv$value)))

  children <- which(p$type_class %in% key_types & !p$semantic_type %in% c("empty", "flag") &
    !is.na(p$rows_profiled) & (p$rows_profiled - p$null_count) > 0)

  for (i in children) {
    c_tab <- paste(p$table_schema[i], p$table_name[i], sep = ".")
    c_full <- paste(c_tab, p$column_name[i], sep = ".")
    idx <- which(keys$full != c_full & keys$type_class == p$type_class[i])
    if (length(idx) == 0) next
    k <- keys[idx, , drop = FALSE]
    kv <- key_values[idx]
    ks <- key_shapes[idx]

    # ---- exclusions --------------------------------------------------------
    is_copy <- isTRUE(p$is_unique[i]) & !is.na(k$value_fingerprint) & !is.na(p$value_fingerprint[i]) &
      k$value_fingerprint == p$value_fingerprint[i]
    keep <- !is_copy
    len_match <- rep(FALSE, nrow(k))
    if (p$type_class[i] == "string") {
      lens_known <- !is.na(p$min_length[i]) & !is.na(p$max_length[i]) & !is.na(k$min_length) & !is.na(k$max_length)
      len_ok <- !lens_known | (p$min_length[i] >= k$min_length & p$max_length[i] <= k$max_length)
      len_match <- lens_known & p$min_length[i] == k$min_length & p$max_length[i] == k$max_length
      keep <- keep & len_ok
    }
    child_top <- parse_top_values(p$top_values[i])
    values_within <- rep(NA, nrow(k))
    if (!is.null(child_top)) {
      values_within <- vapply(kv, function(v) if (is.null(v)) NA else all(child_top$value %in% v), logical(1))
      keep <- keep & (is.na(values_within) | values_within)
      child_shapes <- unique(value_shape(child_top$value))
      keep <- keep & vapply(ks, function(sh) is.null(sh) || any(child_shapes %in% sh), logical(1))
    }
    child_wider <- k$full_table & !is.na(p$distinct_count[i]) & !is.na(k$distinct_count) & p$distinct_count[i] > k$distinct_count
    keep <- keep & !child_wider
    if (!any(keep)) next
    k <- k[keep, , drop = FALSE]
    values_within <- values_within[keep]
    len_match <- len_match[keep]

    # ---- scoring -----------------------------------------------------------
    c_norm <- normalise_name(p$column_name[i])
    name_exact <- !k$generic & k$norm_name == c_norm
    name_suffix <- !name_exact & !k$generic & nchar(k$norm_name) >= 2 & endsWith(c_norm, k$norm_name)
    name_stem <- !name_exact & !name_suffix & nchar(k$stem) >= 3 &
      vapply(k$stem, function(st) grepl(st, c_norm, fixed = TRUE), logical(1), USE.NAMES = FALSE)
    name_score <- ifelse(name_exact, 0.45, ifelse(name_suffix, 0.3, ifelse(name_stem, 0.2, 0)))
    name_text <- ifelse(name_exact, "name=exact", ifelse(name_suffix, "name=suffix", ifelse(name_stem, "name=stem", "name=none")))

    coverage <- pmin(1, p$distinct_count[i] / pmax(k$distinct_count, 1))
    values_score <- ifelse(isTRUE_vec(values_within), 0.4 * coverage, 0)
    values_text <- ifelse(isTRUE_vec(values_within), sprintf("values=within(%d of %d)", as.integer(p$distinct_count[i]), as.integer(k$distinct_count)), "values=unknown")

    within <- rep(NA, nrow(k))
    child_range_known <- !isTRUE(p$values_suppressed[i]) && !is.na(p$min_value[i]) && !is.na(p$max_value[i])
    if (child_range_known) {
      known <- k$range_known & is.na(values_within)
      if (p$type_class[i] == "integer") {
        within[known] <- as_num(p$min_value[i]) >= as_num(k$min_value[known]) & as_num(p$max_value[i]) <= as_num(k$max_value[known])
      } else {
        within[known] <- p$min_value[i] >= k$min_value[known] & p$max_value[i] <= k$max_value[known]
      }
    }
    range_score <- ifelse(is.na(within), 0, ifelse(within, 0.25, -0.25))
    range_text <- ifelse(is.na(within), "range=unknown", ifelse(within, "range=within", "range=outside"))

    card_known <- k$full_table & !is.na(p$distinct_count[i]) & !is.na(k$distinct_count)
    child_is_key <- isTRUE(p$pk_candidate[i])
    many_to_one <- card_known & !isTRUE(p$is_unique[i])
    one_to_one <- card_known & isTRUE(p$is_unique[i]) & !child_is_key
    card_score <- ifelse(many_to_one, 0.15, ifelse(one_to_one, 0.05, 0))
    card_text <- ifelse(many_to_one, "cardinality=many_to_one",
      ifelse(card_known & isTRUE(p$is_unique[i]), "cardinality=one_to_one", "cardinality=unknown"))

    len_score <- ifelse(len_match & !child_is_key, 0.1, 0)
    len_text <- ifelse(len_match, "length=match", "length=unknown")

    score <- pmin(1, 0.1 + name_score + values_score + range_score + card_score + len_score)
    has_name <- name_exact | name_suffix | name_stem
    score[k$tab == c_tab & !(name_exact | name_suffix)] <- 0
    if (child_is_key) score[!has_name] <- 0

    ok <- score >= min_confidence
    p$fk_n_targets[i] <- sum(ok)
    if (!any(ok)) next
    # ties: the tightest containing set when membership is known, else the widest (a table over a view of it)
    tie <- ifelse(isTRUE_vec(values_within), k$distinct_count, -k$distinct_count)
    best <- order(-score, tie, k$full)[1]
    p$fk_candidate[i] <- TRUE
    p$fk_target[i] <- k$full[best]
    p$fk_confidence[i] <- round(score[best], 2)
    p$fk_evidence[i] <- paste(name_text[best], values_text[best], range_text[best], card_text[best], len_text[best], sep = "; ")
  }
  restore_profile_class(p, profile)
}

isTRUE_vec <- function(x) !is.na(x) & as.logical(x)

generic_name_parts <- c("id", "code", "name", "key", "no", "num", "number", "ref", "type", "desc",
                        "description", "value", "status", "date", "datetime", "time", "flag", "ind",
                        "indicator", "identifier", "ident", "text", "label")

#' The singular, normalised stem of a table name: "pas_referrals" -> "referral"
#' @noRd
table_stem <- function(x) {
  s <- normalise_name(sub("^(pas|ed|ris|endo|dim|fact|ref|tbl|vw|v|agg|derived|stg)_", "", tolower(x)))
  s <- sub("ies$", "y", s)
  s <- sub("([^s])s$", "\\1", s)
  s
}

#' The shape of a value: runs of digits to 9, letters to A, everything else kept
#' @noRd
value_shape <- function(x) {
  x <- gsub("[0-9]+", "9", as.character(x))
  gsub("[A-Za-z]+", "A", x)
}

parse_top_values <- function(json) {
  if (is.null(json) || is.na(json)) return(NULL)
  tv <- tryCatch(jsonlite::fromJSON(json), error = function(e) NULL)
  if (is.null(tv) || !is.data.frame(tv) || nrow(tv) == 0) return(NULL)
  tv$value <- as.character(tv$value)
  tv
}

restore_profile_class <- function(p, original) {
  out <- as_tbl(p)
  if (inherits(original, "column_profile")) class(out) <- c("column_profile", class(out))
  out
}
