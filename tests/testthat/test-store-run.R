test_that("store round-trips inventory and profile, and resume skips done tables", {
  con <- fixture_con()
  store <- withr::local_tempfile(fileext = ".sqlite")
  inv <- db_inventory(con, include = c("pas_patients$", "sites$"), progress = FALSE)
  st <- store_open(store)
  expect_output(print(st), "profile_log")
  store_write_inventory(st, inv)
  back <- store_read_inventory(st)
  expect_equal(nrow(back$tables), 2)
  expect_equal(back$columns$column_name, inv$columns$column_name)
  expect_null(store_read(st, "missing"))
  store_close(st)

  p1 <- db_profile(con, inv, store = store, progress = FALSE)
  expect_equal(length(unique(p1$table_name)), 2)
  expect_message(p2 <- db_profile(con, inv, store = store, progress = FALSE), "already profiled")
  expect_equal(nrow(p2), 0)
  p3 <- db_profile(con, inv, store = store, resume = FALSE, progress = FALSE)
  expect_equal(nrow(p3), nrow(p1))

  st <- store_open(store)
  stored <- store_read(st, "column_profile")
  expect_type(stored$is_unique, "logical")
  expect_equal(nrow(stored), 2 * nrow(p1))   # the second full run appended
  store_close(st)
})

test_that("inventory_run does everything from a path and exports CSV", {
  store <- withr::local_tempfile(fileext = ".sqlite")
  export <- withr::local_tempdir()
  out <- inventory_run(fixture_path(), store = store, export_dir = export, organisation = "Fake NHS Trust",
                       include = c("pas_patients$", "v_emergency"), progress = FALSE)
  expect_s3_class(out$inventory, "db_inventory")
  expect_s3_class(out$profile, "column_profile")
  expect_equal(sort(unique(out$profile$table_name)), c("pas_patients", "v_emergency_spells"))
  files <- list.files(export)
  expect_true(all(c("inventory_tables.csv", "inventory_columns.csv", "column_profile.csv", "profile_log.csv", "run_meta.csv") %in% files))
  csv <- utils::read.csv(file.path(export, "column_profile.csv"))
  expect_equal(nrow(csv), nrow(out$profile))
  st <- store_open(store)
  meta <- store_read(st, "run_meta")
  store_close(st)
  expect_equal(meta$dialect, "sqlite")
  expect_equal(meta$n_tables, 2)
  expect_equal(meta$organisation, "Fake NHS Trust")
  expect_equal(DBinventory:::store_organisation(store), "Fake NHS Trust")

  # a second run resumes: nothing new is profiled, but the store is intact
  out2 <- inventory_run(fixture_path(), store = store, include = c("pas_patients$", "v_emergency"), progress = FALSE)
  expect_equal(nrow(out2$profile), nrow(out$profile))
})

test_that("connection strings are redacted in run_meta", {
  expect_equal(
    DBinventory:::redact_source("Driver={x};Server=s;Database=d;UID=me;PWD=secret;"),
    "Driver={x};Server=s;Database=d;UID=***;PWD=***;"
  )
})

test_that("store_export to parquet needs arrow or duckdb", {
  skip_if(requireNamespace("arrow", quietly = TRUE) || requireNamespace("duckdb", quietly = TRUE))
  store <- withr::local_tempfile(fileext = ".sqlite")
  st <- store_open(store)
  store_write(st, "x", data.frame(a = 1))
  store_close(st)
  expect_error(store_export(store, withr::local_tempdir(), "parquet"), "arrow or duckdb")
})

test_that("the report title is prefixed with the organisation", {
  skip_if_not_installed("rmarkdown")
  skip_if(!rmarkdown::pandoc_available())
  store <- withr::local_tempfile(fileext = ".sqlite")
  inventory_run(fixture_path(), store = store, include = "sites$", organisation = "Fake NHS Trust", progress = FALSE)
  out <- withr::local_tempfile(fileext = ".html")
  render_report(store, out, engine = "rmarkdown")
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "Fake NHS Trust: Database inventory and column profile", fixed = TRUE)
  render_report(store, out, engine = "rmarkdown", organisation = "Another Trust")
  expect_match(paste(readLines(out, warn = FALSE), collapse = "\n"), "Another Trust: Database inventory", fixed = TRUE)
})
