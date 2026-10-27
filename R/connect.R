#' Connect to a database, Parquet store or SQLite file from one argument
#'
#' Turns the thing you have into a `DBIConnection`:
#'
#' * a `DBIConnection` is returned as is;
#' * a path ending in `.sqlite`, `.sqlite3` or `.db` opens with `RSQLite`;
#' * a path ending in `.duckdb` or `.ddb` opens read-only with `duckdb`;
#' * a `.parquet` file, a vector of them, or a directory containing Parquet
#'   files becomes an in-memory DuckDB database of views, see
#'   [parquet_connect()];
#' * a string containing `=` and `;` is treated as an ODBC connection string
#'   (`"Driver={ODBC Driver 18 for SQL Server};Server=...;Database=...;Trusted_Connection=yes;"`);
#' * anything else is treated as an ODBC DSN name.
#'
#' @param x A connection, path(s) or connection string.
#' @param ... Passed to the underlying `DBI::dbConnect()`.
#' @return A `DBIConnection`. The caller disconnects it.
#' @examples
#' \dontrun{
#' con <- db_connect("Driver={ODBC Driver 18 for SQL Server};Server=warehouse;Database=DW;Trusted_Connection=yes;")
#' con <- db_connect("warehouse_extract.sqlite")
#' con <- db_connect("data/v2/sample")            # a directory of Parquet files
#' }
#' @export
db_connect <- function(x, ...) {
  if (inherits(x, "DBIConnection")) return(x)
  if (!is.character(x) || length(x) == 0) rlang::abort("`x` must be a DBIConnection, a path or a connection string")
  if (length(x) > 1 || grepl("\\.parquet$", x, ignore.case = TRUE) || dir.exists(x)) {
    return(parquet_connect(x, ...))
  }
  if (grepl("\\.(sqlite|sqlite3|db)$", x, ignore.case = TRUE)) {
    return(DBI::dbConnect(RSQLite::SQLite(), x, ...))
  }
  if (grepl("\\.(duckdb|ddb)$", x, ignore.case = TRUE)) {
    if (!has_pkg("duckdb")) rlang::abort("Opening a DuckDB file needs the duckdb package")
    return(DBI::dbConnect(duckdb::duckdb(), dbdir = x, read_only = TRUE, ...))
  }
  if (!has_pkg("odbc")) rlang::abort("Connecting with a connection string or DSN needs the odbc package")
  if (grepl("=", x, fixed = TRUE) && grepl(";", x, fixed = TRUE)) {
    DBI::dbConnect(odbc::odbc(), .connection_string = x, ...)
  } else {
    DBI::dbConnect(odbc::odbc(), dsn = x, ...)
  }
}

#' Expose Parquet files as a database of views
#'
#' Creates an in-memory DuckDB connection with one view per Parquet file (or
#' per directory of Parquet files, for partitioned tables), so that every
#' other function in the package works on a Parquet store exactly as on a
#' database. Requires the `duckdb` package.
#'
#' Given a directory, files are found recursively. Each directory becomes a
#' schema (nested paths joined with `_`; files at the root go in `main`).
#' A directory that holds two or more Parquet files, no subdirectories, and
#' whose files all share one column schema is read as a single partitioned
#' table named after the directory, so `layer1/pas_adt_events/fy2022.parquet`
#' and `fy2023.parquet` become the view `layer1.pas_adt_events`. A directory
#' whose files differ in schema is a schema of separate tables.
#'
#' @param path A directory, or one or more `.parquet` files.
#' @param union_by_name Pass `union_by_name = true` to `read_parquet()` so
#'   partitions with evolving columns still load.
#' @param ... Passed to `DBI::dbConnect()` for duckdb.
#' @return A `duckdb_connection`. Disconnect with
#'   `DBI::dbDisconnect(con, shutdown = TRUE)`.
#' @examples
#' \dontrun{
#' con <- parquet_connect("data/v2/sample")
#' db_tables(con)
#' inv <- db_inventory(con)
#' }
#' @export
parquet_connect <- function(path, union_by_name = TRUE, ...) {
  if (!has_pkg("duckdb")) rlang::abort("Reading Parquet needs the duckdb package: install.packages('duckdb')")
  con <- DBI::dbConnect(duckdb::duckdb(), ...)
  d <- new_dialect("duckdb")
  same_schema <- function(files) {
    sigs <- vapply(files, function(f) {
      desc <- DBI::dbGetQuery(con, paste0("DESCRIBE SELECT * FROM read_parquet(", sql_quote_string(f), ")"))
      paste(desc$column_name, desc$column_type, collapse = "|")
    }, character(1))
    length(unique(sigs)) == 1
  }
  plan <- parquet_plan(path, same_schema)
  if (nrow(plan) == 0) {
    DBI::dbDisconnect(con, shutdown = TRUE)
    rlang::abort(c("No Parquet files found", i = paste(path, collapse = ", ")))
  }
  for (s in unique(plan$schema)) {
    if (s != "main") DBI::dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", sql_quote_ident(d, s)))
  }
  for (i in seq_len(nrow(plan))) {
    ref <- sql_table_ref(d, plan$schema[i], plan$table[i])
    DBI::dbExecute(con, paste0(
      "CREATE VIEW ", ref, " AS SELECT * FROM read_parquet(", sql_quote_string(plan$source[i]),
      if (union_by_name) ", union_by_name = true", ")"
    ))
  }
  cli::cli_alert_info("{nrow(plan)} Parquet table{?s} exposed as DuckDB views")
  con
}

#' Decide which schema and table each Parquet path becomes
#'
#' @param same_schema A function of a character vector of files returning
#'   `TRUE` when they share one column schema (so form a partitioned table).
#' @return data.frame(schema, table, source)
#' @noRd
parquet_plan <- function(path, same_schema = function(files) FALSE) {
  path <- normalizePath(path, mustWork = TRUE)
  rows <- list()
  add <- function(schema, table, source) rows[[length(rows) + 1]] <<- data.frame(schema = schema, table = table, source = source, stringsAsFactors = FALSE)
  files_in <- function(dir) list.files(dir, pattern = "\\.parquet$", ignore.case = TRUE, full.names = TRUE)
  dirs_in <- function(dir) list.dirs(dir, recursive = FALSE, full.names = TRUE)
  schema_name <- function(root, dir) {
    rel <- substring(dir, nchar(root) + 2)
    if (!nzchar(rel)) "main" else gsub("[^A-Za-z0-9_]", "_", gsub("[/\\\\]", "_", rel))
  }
  table_name <- function(f) gsub("[^A-Za-z0-9_]", "_", sub("\\.parquet$", "", basename(f), ignore.case = TRUE))

  walk <- function(root, dir) {
    for (f in files_in(dir)) add(schema_name(root, dir), table_name(f), f)
    for (sub in dirs_in(dir)) {
      sub_files <- files_in(sub)
      if (length(sub_files) >= 2 && length(dirs_in(sub)) == 0 && isTRUE(same_schema(sub_files))) {
        add(schema_name(root, dir), table_name(sub), file.path(sub, "*.parquet"))
      } else {
        walk(root, sub)
      }
    }
  }
  for (p in path) {
    if (dir.exists(p)) walk(p, p) else add("main", table_name(p), p)
  }
  out <- do.call(rbind, rows)
  if (is.null(out)) return(data.frame(schema = character(), table = character(), source = character()))
  out[!duplicated(paste(out$schema, out$table)), , drop = FALSE]
}
