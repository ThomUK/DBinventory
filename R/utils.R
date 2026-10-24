# Internal helpers shared across the package

now_utc <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")

#' Run a query and return a data frame, with the SQL attached to any error
#' @noRd
db_query <- function(con, sql) {
  tryCatch(
    DBI::dbGetQuery(con, sql),
    error = function(e) {
      rlang::abort(
        c(conditionMessage(e), i = paste("SQL:", substr(sql, 1, 500))),
        class = "db_inventory_sql_error", parent = e
      )
    }
  )
}

db_exec <- function(con, sql) {
  tryCatch(
    DBI::dbExecute(con, sql),
    error = function(e) {
      rlang::abort(
        c(conditionMessage(e), i = paste("SQL:", substr(sql, 1, 500))),
        class = "db_inventory_sql_error", parent = e
      )
    }
  )
}

#' Filter a table list with regular expressions on "schema.table"
#' @noRd
filter_tables <- function(tables, schema = NULL, include = NULL, exclude = NULL, views = TRUE) {
  keep <- rep(TRUE, nrow(tables))
  if (!is.null(schema)) keep <- keep & tolower(tables$table_schema) %in% tolower(schema)
  full <- paste0(tables$table_schema, ".", tables$table_name)
  if (!is.null(include)) {
    keep <- keep & Reduce(`|`, lapply(include, grepl, x = full, ignore.case = TRUE, perl = TRUE))
  }
  if (!is.null(exclude)) {
    keep <- keep & !Reduce(`|`, lapply(exclude, grepl, x = full, ignore.case = TRUE, perl = TRUE))
  }
  if (!views) keep <- keep & tables$table_type != "view"
  tables[keep, , drop = FALSE]
}

as_tbl <- function(x) {
  rownames(x) <- NULL
  tibble::as_tibble(x)
}

#' Coerce a column that may come back as integer64, character or numeric
#' @noRd
as_num <- function(x) {
  if (inherits(x, "integer64")) return(as.numeric(x))
  suppressWarnings(as.numeric(x))
}

as_chr <- function(x) {
  if (is.null(x)) return(NA_character_)
  x <- as.character(x)
  x[is.na(x)] <- NA_character_
  x
}

#' Normalise a column name for fingerprinting: lower case, alphanumerics only
#' @noRd
normalise_name <- function(x) gsub("[^a-z0-9]", "", tolower(x))

#' Does an optional package exist?
#' @noRd
has_pkg <- function(pkg) requireNamespace(pkg, quietly = TRUE)

elapsed_secs <- function(start) as.numeric(difftime(Sys.time(), start, units = "secs"))
