#' Inventory and profile a database in one call
#'
#' The end-to-end run: connect, build the inventory (artefact 1), write it to
#' the store, profile every column (artefact 2) with per-table checkpointing,
#' optionally export CSV or Parquet and render the report. Re-running with the
#' same store resumes an interrupted profile; pass `resume = FALSE` to start
#' over.
#'
#' @param source Anything [db_connect()] accepts: a `DBIConnection`, an ODBC
#'   connection string or DSN, a SQLite or DuckDB file, or a Parquet file or
#'   directory.
#' @param store Path to the SQLite results store. Default
#'   `"db_inventory.sqlite"` in the working directory.
#' @param export_dir If given, the store is exported here after the run.
#' @param export_format `"csv"` (default) or `"parquet"`.
#' @param report If given, the path of an HTML report to render, see
#'   [render_report()].
#' @param resume Skip tables already profiled in `store`? Default `TRUE`.
#' @param disconnect Disconnect a connection this function opened? Default
#'   `TRUE`; a connection passed in is never closed.
#' @inheritParams db_inventory
#' @inheritParams db_profile
#' @return Invisibly, a list with `inventory` (a `db_inventory`), `profile`
#'   (a `column_profile`, the full contents of the store including earlier
#'   runs) and `store` (the store path).
#' @examples
#' out <- inventory_run(fakehosp_path(), store = tempfile(fileext = ".sqlite"),
#'                      include = "pas_patients", progress = FALSE)
#' out$profile[, c("column_name", "semantic_type", "null_rate")]
#' @export
inventory_run <- function(source, store = "db_inventory.sqlite", export_dir = NULL,
                          export_format = c("csv", "parquet"), report = NULL,
                          schema = NULL, include = NULL, exclude = NULL, views = TRUE,
                          sample_rows = 1e6, top_n = 10, top_values_max_distinct = 10000,
                          keep_values = FALSE, resume = TRUE, sizes = TRUE,
                          dialect = NULL, progress = interactive(), disconnect = TRUE) {
  export_format <- match.arg(export_format)
  started <- Sys.time()
  opened <- !inherits(source, "DBIConnection")
  con <- db_connect(source)
  if (opened && disconnect) on.exit(try(DBI::dbDisconnect(con), silent = TRUE), add = TRUE)
  d <- db_dialect(con, dialect)

  inventory <- db_inventory(con, schema = schema, include = include, exclude = exclude, views = views,
                            sizes = sizes, dialect = d, progress = progress)
  st <- store_open(store)
  store_write_inventory(st, inventory)
  store_write(st, "run_meta", data.frame(
    started_at = format(started, "%Y-%m-%d %H:%M:%S", tz = "UTC"), dialect = d$name,
    source = if (is.character(source)) redact_source(source) else class(con)[1],
    n_tables = nrow(inventory$tables), n_columns = nrow(inventory$columns),
    sample_rows = sample_rows, top_n = top_n, keep_values = keep_values,
    package_version = as.character(utils::packageVersion("DBinventory")), stringsAsFactors = FALSE
  ), append = TRUE)
  if (!resume && DBI::dbExistsTable(st$con, "column_profile")) {
    DBI::dbExecute(st$con, "DELETE FROM column_profile")
    DBI::dbExecute(st$con, "DELETE FROM profile_log")
  }
  store_close(st)

  db_profile(con, inventory, sample_rows = sample_rows, top_n = top_n,
             top_values_max_distinct = top_values_max_distinct, keep_values = keep_values,
             store = store, resume = resume, dialect = d, progress = progress)

  st <- store_open(store)
  profile <- store_read(st, "column_profile")
  log <- store_read(st, "profile_log")
  store_close(st)
  if (!is.null(profile)) profile <- structure(profile, class = c("column_profile", class(profile)))
  n_err <- if (is.null(log)) 0L else sum(log$status == "error")
  cli::cli_alert_success("Run complete in {round(elapsed_secs(started), 1)}s: {nrow(profile %||% data.frame())} column profiles in {store}{if (n_err > 0) paste0('; ', n_err, ' table(s) failed, see profile_log') else ''}")

  if (!is.null(export_dir)) store_export(store, export_dir, export_format)
  if (!is.null(report)) render_report(store, report)
  invisible(list(inventory = inventory, profile = profile, store = store))
}

#' Strip passwords from a connection string before it is logged
#' @noRd
redact_source <- function(x) {
  gsub("(pwd|password|uid|user id|user)=[^;]*", "\\1=***", x, ignore.case = TRUE, perl = TRUE)
}
