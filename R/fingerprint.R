#' Fingerprint profiled columns
#'
#' Two hashes per column. The `value` fingerprint summarises what the column
#' holds (type class, order of magnitude of the distinct count, min, max,
#' the hash of its top values); columns with the same value fingerprint in
#' different tables are very likely the same data stored again, whatever they
#' are called. The `column` fingerprint adds the normalised column name, which
#' is the stricter match used to cluster straight copies. Both are computed
#' before any sensitive values are suppressed, so copies of identifier
#' columns still match.
#'
#' @param profile A data frame with the statistics produced by [db_profile()].
#' @return A list with character vectors `value` and `column`.
#' @export
fingerprints <- function(profile) {
  n <- nrow(profile)
  if (n == 0) return(list(value = character(), column = character()))
  mag <- round(log10(pmax(profile$distinct_count, 0) + 1), 1)
  h <- function(parts) digest::digest(parts, algo = "xxhash64", serialize = TRUE)
  value <- vapply(seq_len(n), function(i) {
    h(list(profile$type_class[i], mag[i], profile$min_value[i], profile$max_value[i], profile$top_values_hash[i]))
  }, character(1))
  column <- vapply(seq_len(n), function(i) {
    h(list(normalise_name(profile$column_name[i]), value[i]))
  }, character(1))
  list(value = value, column = column)
}

#' Find columns that share a fingerprint across tables
#'
#' A first look at artefact 3 (the duplicate map): groups of columns in
#' different tables with the same `value_fingerprint` (or the stricter
#' `column_fingerprint`). Constant and empty columns are excluded because
#' they match trivially.
#'
#' @param profile A `column_profile` from [db_profile()].
#' @param by Which fingerprint to group on.
#' @param min_distinct Ignore columns with fewer distinct values than this;
#'   small code lists match across tables legitimately.
#' @return A tibble of candidate groups: `fingerprint`, `n_columns`,
#'   `n_tables`, `columns` (a `schema.table.column` list in one string).
#' @export
duplicate_candidates <- function(profile, by = c("value_fingerprint", "column_fingerprint"), min_distinct = 20) {
  by <- match.arg(by)
  p <- profile[!profile$semantic_type %in% c("empty", "constant", "unknown") &
    !is.na(profile$distinct_count) & profile$distinct_count >= min_distinct, , drop = FALSE]
  if (nrow(p) == 0) {
    return(tibble::tibble(fingerprint = character(), n_columns = integer(), n_tables = integer(), columns = character()))
  }
  p$full <- paste(p$table_schema, p$table_name, p$column_name, sep = ".")
  p$tab <- paste(p$table_schema, p$table_name, sep = ".")
  groups <- split(p, p[[by]])
  groups <- groups[vapply(groups, function(g) length(unique(g$tab)) > 1, logical(1))]
  out <- data.frame(
    fingerprint = names(groups),
    n_columns = vapply(groups, nrow, integer(1)),
    n_tables = vapply(groups, function(g) length(unique(g$tab)), integer(1)),
    columns = vapply(groups, function(g) paste(sort(g$full), collapse = "; "), character(1)),
    stringsAsFactors = FALSE
  )
  out <- out[order(-out$n_tables, -out$n_columns), ]
  as_tbl(out)
}
