# Renders the example reports the pkgdown site shows under "Example Reports":
# one sampled run and one unsampled run over the Fake NHS Trust synthetic
# dataset, read through the fakehospdata package. Run by the example-reports
# GitHub Actions workflow (Actions tab, "Run workflow"), which commits the
# output to pkgdown/assets/; the pkgdown build then publishes it.
#
# Environment variables:
#   FH_SCALE      "full" (default) or "sample"
#   FH_SAMPLE_ROWS sampling threshold for the sampled report, default 1e6
library(DBinventory)

scale <- Sys.getenv("FH_SCALE", "full")
sample_rows <- as.numeric(Sys.getenv("FH_SAMPLE_ROWS", "1e6"))
dir.create("pkgdown/assets", showWarnings = FALSE, recursive = TRUE)

run_one <- function(label, sample_rows) {
  con <- fakehospdata::fh_connect(scale, quiet = FALSE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  store <- tempfile(paste0("fakehosp_", label, "_"), fileext = ".sqlite")
  started <- Sys.time()
  out <- inventory_run(con, store = store, organisation = "Fake NHS Trust", sample_rows = sample_rows, progress = FALSE)
  secs <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  file <- file.path("pkgdown/assets", paste0("example-report-", label, ".html"))
  render_report(store, file, engine = "auto")
  list(
    label = label, file = basename(file), scale = scale, sample_rows = sample_rows,
    tables = nrow(out$inventory$tables), columns = nrow(out$profile),
    rows = sum(out$inventory$tables$row_count, na.rm = TRUE),
    tables_sampled = length(unique(out$profile$table_name[out$profile$sampled])),
    fk_candidates = sum(out$profile$fk_candidate), seconds = round(secs),
    rendered_at = format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC"),
    size_mb = round(file.size(file) / 1e6, 1)
  )
}

runs <- list(
  run_one("sampled", sample_rows),
  run_one("unsampled", Inf)
)
jsonlite::write_json(runs, "pkgdown/assets/example-reports.json", auto_unbox = TRUE, pretty = TRUE)
for (r in runs) cat(sprintf("%-10s %d tables, %d columns, %d sampled, %d fk candidates, %d s, %.1f MB\n",
                            r$label, r$tables, r$columns, r$tables_sampled, r$fk_candidates, r$seconds, r$size_mb))
