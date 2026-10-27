
fixture_path <- function() testthat::test_path("fixtures", "fakehosp_tiny.sqlite")

fixture_con <- function() {
  con <- DBI::dbConnect(RSQLite::SQLite(), fixture_path(), flags = RSQLite::SQLITE_RO)
  withr::defer(DBI::dbDisconnect(con), envir = parent.frame())
  con
}

# A 30-row in-memory SQLite table with known values, for exact assertions.
#   id      1..30, unique
#   code    'A' / 'B' / '' by id %% 3, ten each
#   flag    1 for odd ids (15 true)
#   amount  id * 1.5, NULL when id %% 5 == 0 (6 nulls, mean 22.5)
#   seen    2024-01-01 + id days at 10:00, NULL for id 4
#   note    long free text, NULL when id %% 7 == 0
#   blank   always NULL
#   nhs_number  10-digit text, unique, NULL for id 30
toy_con <- function() {
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  withr::defer(DBI::dbDisconnect(con), envir = parent.frame())
  DBI::dbExecute(con, "CREATE TABLE toy (id INTEGER, code TEXT, flag BOOLEAN, amount REAL, seen TIMESTAMP, note TEXT, blank TEXT, nhs_number TEXT)")
  DBI::dbExecute(con, paste(
    "WITH RECURSIVE n(id) AS (SELECT 1 UNION ALL SELECT id + 1 FROM n WHERE id < 30)",
    "INSERT INTO toy SELECT id,",
    "  CASE id % 3 WHEN 0 THEN 'A' WHEN 1 THEN 'B' ELSE '' END,",
    "  id % 2,",
    "  CASE WHEN id % 5 = 0 THEN NULL ELSE id * 1.5 END,",
    "  CASE WHEN id = 4 THEN NULL ELSE date('2024-01-01', '+' || id || ' days') || ' 10:00:00' END,",
    "  CASE WHEN id % 7 = 0 THEN NULL ELSE 'note number ' || id || ' about things, written at some length so it reads as free text' END,",
    "  NULL,",
    "  CASE WHEN id = 30 THEN NULL ELSE '94347659' || printf('%02d', id) END",
    "FROM n"
  ))
  DBI::dbExecute(con, "CREATE VIEW toy_view AS SELECT id, code FROM toy WHERE flag = 1")
  con
}
