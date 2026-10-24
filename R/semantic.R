#' Infer a semantic type for each profiled column
#'
#' The categories are the roadmap's (identifier, date, code, free text, flag)
#' plus a few that fall out naturally. Rules are deliberately simple and
#' ordered; the result is a first draft for a person to confirm.
#'
#' * `empty`: no non-null values
#' * `constant`: one distinct value
#' * `flag`: boolean type, or at most two values that look like yes/no
#' * `datetime`, `date`, `time`: by type, or text whose values parse as such
#' * `identifier`: nearly unique, a key-like name with high uniqueness, or
#'   short strings with more than half their values distinct
#' * `code`: short strings from a small set
#' * `category`: longer labels from a small set
#' * `free_text`: long or highly varied strings
#' * `count`: integers; `measure`: other numerics
#' * `unknown`: anything else (binary, LOB, complex types)
#'
#' @param profile A data frame with the statistics produced by [db_profile()].
#' @param top A list of top-value data frames, one per row of `profile`,
#'   or `NULL`.
#' @return A character vector, one semantic type per row.
#' @export
infer_semantic_type <- function(profile, top = NULL) {
  n <- nrow(profile)
  if (n == 0) return(character())
  tc <- profile$type_class
  nonnull <- profile$rows_profiled - profile$null_count
  dist <- profile$distinct_count
  drate <- profile$distinct_rate
  avglen <- profile$mean_length
  maxlen <- profile$max_length
  name <- tolower(profile$column_name)
  out <- rep("unknown", n)

  looks_like_id <- grepl("(^|_)(id|key|no|num|number|nhs|mrn|identifier|ident|ref|reference|accession|uid|guid)(_|$)|(id|key|no|num|number|ref|identifier)$",
    gsub("[^a-z0-9_]", "_", name), perl = TRUE)
  flag_values <- c("0", "1", "y", "n", "yes", "no", "true", "false", "t", "f")

  top_vals <- function(i) if (!is.null(top) && !is.null(top[[i]])) tolower(as.character(top[[i]]$value)) else character()
  mostly <- function(vals, pattern) length(vals) > 0 && mean(grepl(pattern, vals, perl = TRUE)) >= 0.9

  for (i in seq_len(n)) {
    if (is.na(nonnull[i]) || nonnull[i] == 0) { out[i] <- "empty"; next }
    if (tc[i] %in% c("binary", "lob", "complex", "other")) { out[i] <- "unknown"; next }
    if (!is.na(dist[i]) && dist[i] == 1) { out[i] <- "constant"; next }
    if (tc[i] == "boolean") { out[i] <- "flag"; next }
    if (tc[i] == "datetime") { out[i] <- "datetime"; next }
    if (tc[i] == "date") { out[i] <- "date"; next }
    if (tc[i] == "time") { out[i] <- "time"; next }
    tv <- top_vals(i)
    if (!is.na(dist[i]) && dist[i] <= 2 && length(tv) > 0 && all(tv %in% flag_values)) { out[i] <- "flag"; next }
    if (tc[i] == "uuid") { out[i] <- "identifier"; next }
    if (tc[i] == "string") {
      if (mostly(tv, "^\\d{4}-\\d{2}-\\d{2}[ t]\\d{2}:\\d{2}") || mostly(tv, "^\\d{2}/\\d{2}/\\d{4} \\d{2}:\\d{2}")) { out[i] <- "datetime"; next }
      if (mostly(tv, "^\\d{4}-\\d{2}-\\d{2}$") || mostly(tv, "^\\d{2}/\\d{2}/\\d{4}$") || mostly(tv, "^\\d{8}$") && grepl("date|dob", name[i])) { out[i] <- "date"; next }
      if (mostly(tv, "^\\d{2}:\\d{2}(:\\d{2})?$")) { out[i] <- "time"; next }
    }
    long <- tc[i] == "string" && ((!is.na(avglen[i]) && avglen[i] > 30) || (!is.na(maxlen[i]) && maxlen[i] > 100))
    if (long) { out[i] <- "free_text"; next }
    if (tc[i] %in% c("string", "integer", "numeric")) {
      unique_ish <- !is.na(drate[i]) && drate[i] >= 0.95 && nonnull[i] >= 20
      keyish <- looks_like_id[i] && !is.na(drate[i]) && drate[i] >= 0.5 && nonnull[i] >= 20
      if (unique_ish && tc[i] != "numeric") { out[i] <- "identifier"; next }
      if (keyish) { out[i] <- "identifier"; next }
      if (tc[i] == "string" && !is.na(drate[i]) && drate[i] >= 0.95 && nonnull[i] >= 20 && !is.na(avglen[i]) && avglen[i] <= 40) { out[i] <- "identifier"; next }
    }
    if (tc[i] == "string") {
      small_set <- !is.na(dist[i]) && (dist[i] <= 50 || (!is.na(drate[i]) && drate[i] <= 0.01 && dist[i] <= 2000))
      if (small_set && !is.na(avglen[i]) && avglen[i] <= 12) { out[i] <- "code"; next }
      if (small_set) { out[i] <- "category"; next }
      # many distinct short strings are references or codes, not prose
      if (!is.na(drate[i]) && drate[i] > 0.5) { out[i] <- if (!is.na(avglen[i]) && avglen[i] <= 20) "identifier" else "free_text"; next }
      out[i] <- "category"; next
    }
    if (tc[i] == "integer") {
      small_set <- !is.na(dist[i]) && dist[i] <= 50 && !is.na(drate[i]) && drate[i] <= 0.05 && looks_like_id[i]
      out[i] <- if (small_set) "code" else "count"
      next
    }
    if (tc[i] == "numeric") { out[i] <- "measure"; next }
  }
  out
}

#' Which columns hold values that should not be copied into a profile?
#'
#' Free text, identifiers with more than 200 distinct values, and anything
#' whose name suggests personal data whatever its inferred type. Small
#' identifier lists are code lists. Dates are kept because freshness depends
#' on them.
#' @noRd
is_sensitive <- function(profile) {
  name <- tolower(profile$column_name)
  personal <- grepl("nhs|mrn|hosp(ital)?_?no|patient_?(id|ref|identifier)|postcode|post_code|zip|dob|date_of_birth|birth|surname|forename|first_?name|last_?name|full_?name|address|phone|tel|mobile|email|nino|national_insurance|passport|gp_?practice|free_?text|comment|note|narrative|report",
    name, perl = TRUE)
  # ...unless the name says it is a classifier of that thing (nhs_number_status, postcode_area_type)
  classifier <- grepl("(status|code|type|indicator|flag|group|desc|description|category|kind|area|district|sector|count|n)$|^(n|num|count|number_of|has|is)_", name, perl = TRUE)
  # an identifier drawn from a small set (a specialty or ward code list) is a code, not personal data
  small_list <- !is.na(profile$distinct_count) & profile$distinct_count <= 200
  type_sensitive <- profile$semantic_type == "free_text" | (profile$semantic_type == "identifier" & !small_list)
  (type_sensitive | (personal & !classifier)) & profile$type_class %in% c("string", "integer", "numeric", "uuid")
}
