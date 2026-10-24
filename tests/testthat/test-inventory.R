test_that("db_tables lists and filters tables and views", {
  con <- fixture_con()
  tabs <- db_tables(con)
  expect_s3_class(tabs, "tbl_df")
  expect_named(tabs, c("table_catalog", "table_schema", "table_name", "table_type"))
  expect_true("pas_patients" %in% tabs$table_name)
  expect_true("view" %in% tabs$table_type)
  expect_false("view" %in% db_tables(con, views = FALSE)$table_type)
  expect_equal(db_tables(con, include = "^main\\.pas_pat")$table_name, "pas_patients")
  expect_false(any(grepl("^agg_", db_tables(con, exclude = "\\.agg_")$table_name)))
  expect_equal(nrow(db_tables(con, schema = "nope")), 0)
})

test_that("db_columns returns typed columns in order", {
  con <- fixture_con()
  cols <- db_columns(con, db_tables(con, include = "pas_patients$"))
  expect_equal(cols$column_name[1:3], c("mrn", "nhs_number", "nhs_number_status"))
  expect_equal(cols$ordinal_position, 1:10)
  expect_equal(cols$type_class[cols$column_name == "dob"], "date")
  expect_equal(cols$type_class[cols$column_name == "registered_datetime"], "datetime")
  expect_true(all(cols$is_nullable))
})

test_that("db_inventory computes counts, freshness and column totals", {
  con <- fixture_con()
  inv <- db_inventory(con, include = c("pas_patients", "v_emergency_spells", "reference|sites"), progress = FALSE)
  expect_s3_class(inv, "db_inventory")
  expect_output(print(inv), "db_inventory")
  t <- inv$tables
  pp <- t[t$table_name == "pas_patients", ]
  expect_equal(pp$row_count, 1000)
  expect_equal(pp$n_columns, 10)
  expect_equal(pp$n_datetime_columns, 3)
  expect_match(pp$newest_datetime, "^20\\d\\d-\\d\\d-\\d\\d")
  expect_true(pp$newest_datetime_column %in% c("dob", "registered_datetime", "date_of_death"))
  v <- t[t$table_name == "v_emergency_spells", ]
  expect_equal(v$table_type, "view")
  expect_true(v$row_count > 0)
  expect_true(all(is.na(t$size_bytes)))
  expect_match(t$inventoried_at[1], "^\\d{4}-\\d{2}-\\d{2} ")
  s <- t[t$table_name == "sites", ]
  expect_true(is.na(s$newest_datetime))
})

test_that("inventory steps can be switched off", {
  con <- fixture_con()
  inv <- db_inventory(con, include = "pas_patients$", row_counts = FALSE, freshness = FALSE, sizes = FALSE, progress = FALSE)
  expect_true(is.na(inv$tables$row_count))
  expect_true(is.na(inv$tables$newest_datetime))
})

test_that("a failing table does not stop the run", {
  con <- toy_con()
  DBI::dbExecute(con, "CREATE TABLE gone (x INTEGER)")
  DBI::dbExecute(con, "CREATE VIEW broken AS SELECT * FROM gone")
  DBI::dbExecute(con, "DROP TABLE gone")
  expect_message(tabs <- db_row_counts(con, db_tables(con), progress = FALSE), "Row count failed")
  expect_true(is.na(tabs$row_count[tabs$table_name == "broken"]))
  expect_equal(tabs$row_count[tabs$table_name == "toy"], 30)
})
