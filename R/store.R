#' Open (or create) a results store
#'
#' The store is a SQLite file holding the inventory, the column profile and
#' a per-table log of profiling runs. It is the checkpoint that lets a
#' multi-hour profile resume, and the input to the report and exports.
#' Requires the `RSQLite` package.
#'
#' @param path Path to a `.sqlite` file; created if missing.
#' @return A `db_store` object wrapping a DBI connection.
#' @examples
#' st <- store_open(tempfile(fileext = ".sqlite"))
#' store_tables(st)
#' store_close(st)
#' @export
store_open <- function(path) {
  if (inherits(path, "db_store")) return(path)
  if (!has_pkg("RSQLite")) rlang::abort("The store needs the RSQLite package: install.packages('RSQLite')")
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  st <- structure(list(con = con, path = path), class = "db_store")
  if (!DBI::dbExistsTable(con, "profile_log")) {
    DBI::dbExecute(con, paste(
      "CREATE TABLE profile_log (table_schema TEXT, table_name TEXT, status TEXT,",
      "seconds REAL, message TEXT, logged_at TEXT)"
    ))
  }
  st
}

#' @rdname store_open
#' @param store A `db_store`.
#' @export
store_close <- function(store) {
  if (DBI::dbIsValid(store$con)) DBI::dbDisconnect(store$con)
  invisible(NULL)
}

#' @export
print.db_store <- function(x, ...) {
  cat("<db_store> ", x$path, "\n", sep = "")
  tabs <- store_tables(x)
  for (t in tabs) cat("  ", t, ": ", store_count(x, t), " rows\n", sep = "")
  invisible(x)
}

#' @rdname store_open
#' @export
store_tables <- function(store) {
  setdiff(DBI::dbListTables(store$con), "sqlite_sequence")
}

store_count <- function(store, name) {
  DBI::dbGetQuery(store$con, paste0("SELECT COUNT(*) AS n FROM ", DBI::dbQuoteIdentifier(store$con, name)))$n
}

#' Write a data frame into the store
#'
#' @inheritParams store_close
#' @param name Table name inside the store.
#' @param x A data frame.
#' @param append Append to an existing table (`TRUE`) or replace it.
#' @return `store`, invisibly.
#' @export
store_write <- function(store, name, x, append = FALSE) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  for (nm in names(x)) {
    if (is.list(x[[nm]])) x[[nm]] <- vapply(x[[nm]], function(v) jsonlite::toJSON(v, auto_unbox = TRUE), character(1))
    if (inherits(x[[nm]], "integer64")) x[[nm]] <- as.numeric(x[[nm]])
  }
  DBI::dbWriteTable(store$con, name, x, append = append, overwrite = !append)
  invisible(store)
}

#' Read a table from the store
#'
#' @inheritParams store_write
#' @return A tibble, or `NULL` if the table does not exist.
#' @export
store_read <- function(store, name) {
  if (!DBI::dbExistsTable(store$con, name)) return(NULL)
  x <- DBI::dbReadTable(store$con, name)
  for (nm in intersect(names(x), c("sampled", "is_unique", "values_suppressed", "is_nullable"))) x[[nm]] <- as.logical(x[[nm]])
  as_tbl(x)
}

store_log <- function(store, tab, status, seconds, message) {
  DBI::dbExecute(
    store$con,
    "INSERT INTO profile_log (table_schema, table_name, status, seconds, message, logged_at) VALUES (?, ?, ?, ?, ?, ?)",
    params = list(tab$table_schema, tab$table_name, status, seconds, message, now_utc())
  )
}

#' Tables whose latest profile run succeeded
#' @noRd
store_tables_done <- function(store) {
  as_tbl(DBI::dbGetQuery(store$con, paste(
    "SELECT table_schema, table_name FROM profile_log l",
    "WHERE status = 'ok' AND logged_at = (SELECT MAX(logged_at) FROM profile_log l2",
    "WHERE l2.table_schema = l.table_schema AND l2.table_name = l.table_name)"
  )))
}

#' Save an inventory into the store
#'
#' Replaces the `inventory_tables` and `inventory_columns` tables.
#' @inheritParams store_close
#' @param inventory A `db_inventory`.
#' @return `store`, invisibly.
#' @export
store_write_inventory <- function(store, inventory) {
  store_write(store, "inventory_tables", inventory$tables)
  store_write(store, "inventory_columns", inventory$columns)
  invisible(store)
}

#' Read the inventory back from the store
#' @inheritParams store_close
#' @return A `db_inventory`, or `NULL` if none has been written.
#' @export
store_read_inventory <- function(store) {
  tables <- store_read(store, "inventory_tables")
  if (is.null(tables)) return(NULL)
  structure(list(tables = tables, columns = store_read(store, "inventory_columns"), dialect = "store"), class = "db_inventory")
}

#' Export the store's tables to CSV or Parquet files
#'
#' One file per store table, named after it. CSV needs nothing extra;
#' Parquet uses `arrow` if installed, else `duckdb`, else stops.
#'
#' @inheritParams store_close
#' @param dir Output directory, created if needed.
#' @param format `"csv"` or `"parquet"`.
#' @param tables Which store tables to export; default all.
#' @return Character vector of files written, invisibly.
#' @export
store_export <- function(store, dir, format = c("csv", "parquet"), tables = NULL) {
  format <- match.arg(format)
  st <- store_open(store)
  if (!inherits(store, "db_store")) on.exit(store_close(st), add = TRUE)
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  tables <- tables %||% store_tables(st)
  files <- character()
  for (t in tables) {
    x <- as.data.frame(store_read(st, t))
    f <- file.path(dir, paste0(t, ".", format))
    if (format == "csv") {
      utils::write.csv(x, f, row.names = FALSE, na = "")
    } else if (has_pkg("arrow")) {
      arrow::write_parquet(x, f)
    } else if (has_pkg("duckdb")) {
      dcon <- DBI::dbConnect(duckdb::duckdb())
      on.exit(DBI::dbDisconnect(dcon, shutdown = TRUE), add = TRUE)
      duckdb::duckdb_register(dcon, "x", x)
      DBI::dbExecute(dcon, paste0("COPY x TO ", sql_quote_string(f), " (FORMAT PARQUET)"))
      duckdb::duckdb_unregister(dcon, "x")
    } else {
      rlang::abort("Parquet export needs the arrow or duckdb package")
    }
    files <- c(files, f)
  }
  cli::cli_alert_success("Exported {length(files)} file{?s} to {dir}")
  invisible(files)
}
