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
#' @param organisation Name of the trust or organisation the database belongs
#'   to. Recorded in the store's `run_meta` and used to prefix the report
#'   title.
#' @param schema_priority Optional schema order for choosing a cluster's
#'   canonical table, see [cluster_tables()].
#' @param decisions Optional path to the cluster review CSV, see
#'   [write_cluster_decisions()]: existing decisions in it are applied, and
#'   the file is rewritten with any new tables added as proposed.
#' @param resume Skip tables already profiled in `store`? Default `TRUE`.
#' @param sizes Read table sizes from system views? Default `TRUE`.
#' @param disconnect Disconnect a connection this function opened? Default
#'   `TRUE`; a connection passed in is never closed.
#' @inheritParams db_inventory
#' @inheritParams db_profile
#' @return Invisibly, a list with `inventory` (a `db_inventory`), `profile`
#'   (a `column_profile`, the full contents of the store including earlier
#'   runs), `clusters` (the result of [cluster_tables()], or `NULL` on a
#'   sampled run) and `store` (the store path).
#'
#' @section Full and sampled runs:
#' Phase 1 (inventory and profile) runs either way. Phases 2 and 3, table
#' clustering and foreign key inference, need exact statistics and run only
#' when no table was sampled; on a sampled run they are skipped with a
#' message and the report says so on their tabs. `sample_rows = Inf` gives a
#' full run.
#' @examples
#' \dontrun{
#' # the synthetic trust, through the fakehospdata package
#' con <- fakehospdata::fh_connect("sample")
#' out <- inventory_run(con, store = "fakehosp_inventory.sqlite", organisation = "Fake NHS Trust",
#'                      report = "fakehosp_inventory.html")
#' out$profile[, c("table_name", "column_name", "semantic_type", "null_rate")]
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' }
#' @export
inventory_run <- function(source, store = "db_inventory.sqlite", export_dir = NULL,
                          export_format = c("csv", "parquet"), report = NULL, organisation = NULL,
                          schema_priority = NULL, decisions = NULL,
                          schema = NULL, include = NULL, exclude = NULL, views = TRUE,
                          sample_rows = 1e6, top_n = 10, full_set_max = 50, top_values_max_distinct = 10000,
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
    organisation = organisation %||% NA_character_,
    n_tables = nrow(inventory$tables), n_columns = nrow(inventory$columns),
    sample_rows = sample_rows, top_n = top_n, keep_values = keep_values,
    package_version = as.character(utils::packageVersion("DBinventory")), stringsAsFactors = FALSE
  ), append = TRUE)
  if (!resume && DBI::dbExistsTable(st$con, "column_profile")) {
    DBI::dbExecute(st$con, "DELETE FROM column_profile")
    DBI::dbExecute(st$con, "DELETE FROM profile_log")
  }
  store_close(st)

  db_profile(con, inventory, sample_rows = sample_rows, top_n = top_n, full_set_max = full_set_max,
             top_values_max_distinct = top_values_max_distinct, keep_values = keep_values,
             store = store, resume = resume, dialect = d, progress = progress)

  st <- store_open(store)
  profile <- store_read(st, "column_profile")
  log <- store_read(st, "profile_log")
  clusters <- NULL
  if (!is.null(profile) && nrow(profile) > 0) {
    profile <- structure(profile, class = c("column_profile", class(profile)))
    if (any(profile$sampled)) {
      n_s <- sum(tapply(profile$sampled, paste(profile$table_schema, profile$table_name), any))
      cli::cli_alert_info("Sampled run: {n_s} table{?s} {?was/were} profiled on a sample, so foreign keys and table clusters (phases 2 and 3) were skipped. Run again with sample_rows = Inf and the same store to profile {?it/them} in full")
      for (t in c("table_clusters", "table_pairs")) if (DBI::dbExistsTable(st$con, t)) DBI::dbRemoveTable(st$con, t)
    } else {
      # phases 2 and 3 run across every profiled table, including those from
      # earlier resumed runs, and are written back so the store carries them
      profile <- infer_foreign_keys(profile)
      store_write(st, "column_profile", profile)
      cli::cli_alert_info("{sum(profile$fk_candidate)} foreign key candidate{?s} proposed")
      full_inventory <- store_read_inventory(st)
      prior <- if (!is.null(decisions)) read_cluster_decisions(decisions) else NULL
      clusters <- cluster_tables(profile, full_inventory, schema_priority = schema_priority, decisions = prior)
      store_write(st, "table_clusters", clusters$clusters)
      store_write(st, "table_pairs", clusters$pairs)
      if (!is.null(decisions)) write_cluster_decisions(clusters$clusters, decisions)
      n_multi <- sum(table(clusters$clusters$cluster_id) > 1)
      cli::cli_alert_info("{n_multi} cluster{?s} of related tables proposed")
    }
  }
  store_close(st)
  n_err <- if (is.null(log)) 0L else sum(log$status == "error")
  cli::cli_alert_success("Run complete in {round(elapsed_secs(started), 1)}s: {nrow(profile %||% data.frame())} column profiles in {store}{if (n_err > 0) paste0('; ', n_err, ' table(s) failed, see profile_log') else ''}")

  if (!is.null(export_dir)) store_export(store, export_dir, export_format)
  if (!is.null(report)) render_report(store, report, organisation = organisation)
  invisible(list(inventory = inventory, profile = profile, clusters = clusters, store = store))
}

#' Strip passwords from a connection string before it is logged
#' @noRd
redact_source <- function(x) {
  gsub("(pwd|password|uid|user id|user)=[^;]*", "\\1=***", x, ignore.case = TRUE, perl = TRUE)
}
