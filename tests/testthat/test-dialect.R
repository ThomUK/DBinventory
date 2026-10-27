test_that("dialect is inferred from connection class and can be forced", {
  expect_equal(db_dialect(dialect = "mssql")$name, "mssql")
  expect_equal(db_dialect(structure(list(), class = "Microsoft SQL Server"))$name, "mssql")
  expect_equal(db_dialect(structure(list(), class = "duckdb_connection"))$name, "duckdb")
  expect_equal(db_dialect(structure(list(), class = "SQLiteConnection"))$name, "sqlite")
  expect_equal(db_dialect(structure(list(), class = "PqConnection"))$name, "postgres")
  expect_equal(db_dialect(structure(list(), class = "SomethingElse"))$name, "generic")
  d <- db_dialect(dialect = "duckdb")
  expect_identical(db_dialect(NULL, d), d)
  expect_output(print(d), "duckdb")
})

test_that("identifiers are quoted per dialect", {
  ms <- db_dialect(dialect = "mssql")
  expect_equal(DBinventory:::sql_quote_ident(ms, "a]b"), "[a]]b]")
  expect_equal(DBinventory:::sql_table_ref(ms, "dbo", "Patients"), "[dbo].[Patients]")
  dk <- db_dialect(dialect = "duckdb")
  expect_equal(DBinventory:::sql_quote_ident(dk, 'a"b'), '"a""b"')
  expect_equal(DBinventory:::sql_table_ref(dk, NULL, "t"), '"t"')
})

test_that("SQL Server SQL uses T-SQL forms", {
  ms <- db_dialect(dialect = "mssql")
  expect_match(DBinventory:::sql_list_tables(ms), "INFORMATION_SCHEMA.TABLES")
  expect_match(DBinventory:::sql_list_columns(ms), "INFORMATION_SCHEMA.COLUMNS")
  expect_match(DBinventory:::sql_table_sizes(ms)[1], "sys.dm_db_partition_stats")
  expect_equal(DBinventory:::sql_count_star(ms), "COUNT_BIG(*)")
  expect_equal(DBinventory:::sql_len(ms, "[x]"), "LEN([x])")
  expect_equal(DBinventory:::sql_select(ms, c("a", "b"), "[dbo].[t]", n = 10), "SELECT TOP (10) a, b FROM [dbo].[t]")
  expect_equal(
    DBinventory:::sql_select(ms, "a", "[t]", where = "a IS NOT NULL", group_by = "a", order_by = "n DESC", n = 5),
    "SELECT TOP (5) a FROM [t] WHERE a IS NOT NULL GROUP BY a ORDER BY n DESC"
  )
  expect_equal(DBinventory:::sql_to_text(ms, "MAX([d])", "datetime"), "CONVERT(VARCHAR(34), MAX([d]), 126)")
  expect_equal(DBinventory:::sql_to_text(ms, "MAX([d])", "date"), "CONVERT(VARCHAR(10), MAX([d]), 23)")
  expect_match(DBinventory:::sql_bool_is_true(ms, "[b]"), "= 1 THEN 1")
  smp <- DBinventory:::sql_sample_select(ms, "[dbo].[t]", 1000, 1e7)
  expect_match(smp$sql, "TABLESAMPLE SYSTEM \\(1100 ROWS\\)")
  expect_equal(smp$method, "tablesample_system")
  smp_view <- DBinventory:::sql_sample_select(ms, "[dbo].[v]", 1000, 1e7, is_view = TRUE)
  expect_equal(smp_view$sql, "SELECT TOP (1000) * FROM [dbo].[v]")
  tmp <- DBinventory:::sql_temp_table(ms, "s1", "SELECT * FROM [t]")
  expect_equal(tmp$ref, "[#s1]")
  expect_match(tmp$create, "^SELECT \\* INTO \\[#s1\\] FROM \\(SELECT \\* FROM \\[t\\]\\) AS")
  expect_equal(tmp$drop, "DROP TABLE [#s1]")
})

test_that("other dialects use LIMIT and their own sampling", {
  dk <- db_dialect(dialect = "duckdb")
  expect_equal(DBinventory:::sql_select(dk, "a", "t", n = 10), "SELECT a FROM t LIMIT 10")
  expect_match(DBinventory:::sql_sample_select(dk, "t", 500, 1e6)$sql, "USING SAMPLE 0.05 PERCENT \\(system, 42\\)")
  expect_match(DBinventory:::sql_sample_select(dk, "t", 500, NA)$sql, "USING SAMPLE reservoir\\(500 ROWS\\)")
  expect_match(DBinventory:::sql_sample_select(dk, "t", 20, 50)$sql, "USING SAMPLE reservoir\\(20 ROWS\\)")
  sq <- db_dialect(dialect = "sqlite")
  expect_match(DBinventory:::sql_sample_select(sq, "t", 500, 1e6)$sql, "ORDER BY random\\(\\) LIMIT 500")
  expect_null(DBinventory:::sql_list_columns(sq))
  expect_match(DBinventory:::sql_list_table_columns(sq, "main", "t"), "pragma_table_info\\('t'\\)")
  pg <- db_dialect(dialect = "postgres")
  expect_match(DBinventory:::sql_sample_select(pg, "t", 1000, 1e5)$sql, "TABLESAMPLE SYSTEM \\(1\\.1\\)")
  expect_equal(DBinventory:::sql_sample_select(pg, "v", 1000, 1e5, is_view = TRUE)$method, "first_rows")
  expect_match(DBinventory:::sql_table_sizes(pg), "pg_total_relation_size")
  expect_null(DBinventory:::sql_table_sizes(dk))
  tmp <- DBinventory:::sql_temp_table(dk, "s1", "SELECT 1")
  expect_equal(tmp$create, 'CREATE TEMPORARY TABLE "s1" AS SELECT 1')
})

test_that("type_class maps engine types", {
  expect_equal(
    type_class(c("nvarchar", "datetime2", "bit", "decimal", "uniqueidentifier", "varbinary", "text", "timestamp", "xml", "int", "float", "date", "time"), "mssql"),
    c("string", "datetime", "boolean", "numeric", "uuid", "binary", "lob", "binary", "lob", "integer", "numeric", "date", "time")
  )
  expect_equal(
    type_class(c("VARCHAR", "TIMESTAMP", "BOOLEAN", "DOUBLE", "BIGINT", "VARCHAR[]", "STRUCT(a INTEGER)", "UUID", "BLOB", "DATE"), "duckdb"),
    c("string", "datetime", "boolean", "numeric", "integer", "complex", "complex", "uuid", "binary", "date")
  )
  expect_equal(type_class(c("TEXT", "", "NUMERIC(10,2)", "VARCHAR(50)", "unsigned big int", "DATETIME"), "sqlite"),
               c("string", "other", "numeric", "string", "integer", "datetime"))
  expect_equal(type_class("timestamp without time zone", "postgres"), "datetime")
})

test_that("SQL Server text conversion is vectorised over type classes", {
  ms <- db_dialect(dialect = "mssql")
  out <- sql_to_text(ms, c("MAX(a)", "MAX(b)", "MAX(c)", "x"), c("datetime", "date", "numeric", "string"))
  expect_length(out, 4)
  expect_equal(out[1], "CONVERT(VARCHAR(34), MAX(a), 126)")
  expect_equal(out[2], "CONVERT(VARCHAR(10), MAX(b), 23)")
  expect_equal(out[3], "CONVERT(VARCHAR(60), MAX(c), 2)")
  expect_equal(out[4], "CAST(x AS NVARCHAR(200))")
  expect_equal(sql_to_text(ms, "t", "time"), "CONVERT(VARCHAR(16), t, 114)")
})

test_that("SQL Server table sizes offer a fallback that needs no VIEW DATABASE STATE", {
  q <- sql_table_sizes(db_dialect(dialect = "mssql"))
  expect_length(q, 2)
  expect_match(q[1], "dm_db_partition_stats")
  expect_match(q[2], "sys.allocation_units")
  expect_false(grepl("dm_db_partition_stats", q[2]))
  expect_null(sql_table_sizes(db_dialect(dialect = "sqlite")))
})
