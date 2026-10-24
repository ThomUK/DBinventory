#' Identify or construct a SQL dialect
#'
#' `DBinventory` issues plain SQL through DBI. The small set of things that
#' differ between engines (identifier quoting, metadata views, sampling,
#' `TOP` versus `LIMIT`, text conversion, system size views) live in a dialect
#' object. The dialect is normally inferred from the connection class, but can
#' be forced with `dialect`, which is useful for an unfamiliar ODBC driver.
#'
#' @param con A `DBIConnection`, or `NULL` when `dialect` is given.
#' @param dialect Optional dialect name to force: one of `"mssql"`, `"duckdb"`,
#'   `"sqlite"`, `"postgres"` or `"generic"`.
#' @return An object of class `db_dialect`.
#' @examples
#' db_dialect(dialect = "mssql")
#' @export
db_dialect <- function(con = NULL, dialect = NULL) {
  if (inherits(dialect, "db_dialect")) return(dialect)
  if (inherits(con, "db_dialect")) return(con)
  if (!is.null(dialect)) return(new_dialect(dialect))
  if (is.null(con)) return(new_dialect("generic"))
  cls <- class(con)
  name <- if (any(grepl("SQL Server", cls, ignore.case = TRUE))) {
    "mssql"
  } else if ("duckdb_connection" %in% cls) {
    "duckdb"
  } else if ("SQLiteConnection" %in% cls) {
    "sqlite"
  } else if (any(cls %in% c("PqConnection", "PostgreSQLConnection", "PostgreSQL"))) {
    "postgres"
  } else {
    info <- tryCatch(DBI::dbGetInfo(con), error = function(e) NULL)
    dbms <- tolower(info$dbms.name %||% "")
    if (grepl("sql server", dbms)) "mssql"
    else if (grepl("postgres", dbms)) "postgres"
    else if (grepl("duckdb", dbms)) "duckdb"
    else if (grepl("sqlite", dbms)) "sqlite"
    else "generic"
  }
  new_dialect(name)
}

new_dialect <- function(name) {
  name <- match.arg(name, c("mssql", "duckdb", "sqlite", "postgres", "generic"))
  structure(list(name = name), class = c(paste0("db_dialect_", name), "db_dialect"))
}

#' @export
print.db_dialect <- function(x, ...) {
  cat("<db_dialect: ", x$name, ">\n", sep = "")
  invisible(x)
}

# ---- identifier quoting -----------------------------------------------------

sql_quote_ident <- function(d, x) UseMethod("sql_quote_ident")
#' @export
sql_quote_ident.db_dialect <- function(d, x) paste0('"', gsub('"', '""', x, fixed = TRUE), '"')
#' @export
sql_quote_ident.db_dialect_mssql <- function(d, x) paste0("[", gsub("]", "]]", x, fixed = TRUE), "]")

sql_table_ref <- function(d, schema, table) {
  if (is.null(schema) || is.na(schema) || !nzchar(schema)) {
    sql_quote_ident(d, table)
  } else {
    paste0(sql_quote_ident(d, schema), ".", sql_quote_ident(d, table))
  }
}

sql_quote_string <- function(x) paste0("'", gsub("'", "''", x, fixed = TRUE), "'")

# ---- metadata ----------------------------------------------------------------

#' SQL that lists tables and views
#'
#' Returns one row per relation with columns `table_catalog`, `table_schema`,
#' `table_name` and `table_type` (`"table"` or `"view"`).
#' @noRd
sql_list_tables <- function(d) UseMethod("sql_list_tables")
#' @export
sql_list_tables.db_dialect <- function(d) {
  paste(
    "SELECT table_catalog, table_schema, table_name,",
    "CASE WHEN UPPER(table_type) = 'VIEW' THEN 'view' ELSE 'table' END AS table_type",
    "FROM information_schema.tables",
    "WHERE LOWER(table_schema) NOT IN ('information_schema', 'pg_catalog', 'sys')"
  )
}
#' @export
sql_list_tables.db_dialect_mssql <- function(d) {
  paste(
    "SELECT TABLE_CATALOG AS table_catalog, TABLE_SCHEMA AS table_schema,",
    "TABLE_NAME AS table_name,",
    "CASE WHEN TABLE_TYPE = 'VIEW' THEN 'view' ELSE 'table' END AS table_type",
    "FROM INFORMATION_SCHEMA.TABLES",
    "WHERE TABLE_SCHEMA NOT IN ('sys', 'INFORMATION_SCHEMA')"
  )
}
#' @export
sql_list_tables.db_dialect_sqlite <- function(d) {
  paste(
    "SELECT NULL AS table_catalog, 'main' AS table_schema, name AS table_name,",
    "CASE WHEN type = 'view' THEN 'view' ELSE 'table' END AS table_type",
    "FROM sqlite_master WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%'"
  )
}

#' SQL that lists every column of every table
#'
#' Returns `table_schema`, `table_name`, `column_name`, `ordinal_position`,
#' `data_type`, `character_maximum_length`, `numeric_precision`,
#' `numeric_scale`, `is_nullable`. Dialects without `information_schema`
#' return `NULL` and are handled per table by `sql_list_table_columns()`.
#' @noRd
sql_list_columns <- function(d) UseMethod("sql_list_columns")
#' @export
sql_list_columns.db_dialect <- function(d) {
  paste(
    "SELECT table_schema, table_name, column_name, ordinal_position, data_type,",
    "character_maximum_length, numeric_precision, numeric_scale, is_nullable",
    "FROM information_schema.columns",
    "WHERE LOWER(table_schema) NOT IN ('information_schema', 'pg_catalog', 'sys')"
  )
}
#' @export
sql_list_columns.db_dialect_mssql <- function(d) {
  paste(
    "SELECT TABLE_SCHEMA AS table_schema, TABLE_NAME AS table_name,",
    "COLUMN_NAME AS column_name, ORDINAL_POSITION AS ordinal_position,",
    "DATA_TYPE AS data_type, CHARACTER_MAXIMUM_LENGTH AS character_maximum_length,",
    "NUMERIC_PRECISION AS numeric_precision, NUMERIC_SCALE AS numeric_scale,",
    "IS_NULLABLE AS is_nullable",
    "FROM INFORMATION_SCHEMA.COLUMNS",
    "WHERE TABLE_SCHEMA NOT IN ('sys', 'INFORMATION_SCHEMA')"
  )
}
#' @export
sql_list_columns.db_dialect_sqlite <- function(d) NULL

# per-table column listing for dialects without information_schema
sql_list_table_columns <- function(d, schema, table) UseMethod("sql_list_table_columns")
#' @export
sql_list_table_columns.db_dialect <- function(d, schema, table) {
  stop("sql_list_table_columns() is only needed for dialects without information_schema")
}
#' @export
sql_list_table_columns.db_dialect_sqlite <- function(d, schema, table) {
  paste0(
    "SELECT ", sql_quote_string(schema %||% "main"), " AS table_schema, ",
    sql_quote_string(table), " AS table_name, name AS column_name, cid + 1 AS ordinal_position, ",
    "type AS data_type, NULL AS character_maximum_length, NULL AS numeric_precision, ",
    "NULL AS numeric_scale, CASE WHEN \"notnull\" = 1 THEN 'NO' ELSE 'YES' END AS is_nullable ",
    "FROM pragma_table_info(", sql_quote_string(table), ")"
  )
}

#' SQL that returns table sizes from system views, or NULL if unavailable
#'
#' Columns: `table_schema`, `table_name`, `size_bytes`, `row_count_stats`.
#' @noRd
sql_table_sizes <- function(d) UseMethod("sql_table_sizes")
#' @export
sql_table_sizes.db_dialect <- function(d) NULL
#' @export
sql_table_sizes.db_dialect_mssql <- function(d) {
  paste(
    "SELECT s.name AS table_schema, t.name AS table_name,",
    "SUM(ps.reserved_page_count) * 8192 AS size_bytes,",
    "SUM(CASE WHEN ps.index_id IN (0, 1) THEN ps.row_count ELSE 0 END) AS row_count_stats",
    "FROM sys.dm_db_partition_stats ps",
    "JOIN sys.tables t ON t.object_id = ps.object_id",
    "JOIN sys.schemas s ON s.schema_id = t.schema_id",
    "GROUP BY s.name, t.name"
  )
}
#' @export
sql_table_sizes.db_dialect_postgres <- function(d) {
  paste(
    "SELECT n.nspname AS table_schema, c.relname AS table_name,",
    "pg_total_relation_size(c.oid) AS size_bytes,",
    "CASE WHEN c.reltuples < 0 THEN NULL ELSE c.reltuples END AS row_count_stats",
    "FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace",
    "WHERE c.relkind IN ('r', 'p', 'm')",
    "AND n.nspname NOT IN ('pg_catalog', 'information_schema')"
  )
}

# ---- expressions -------------------------------------------------------------

sql_count_star <- function(d) UseMethod("sql_count_star")
#' @export
sql_count_star.db_dialect <- function(d) "COUNT(*)"
#' @export
sql_count_star.db_dialect_mssql <- function(d) "COUNT_BIG(*)"

sql_len <- function(d, x) UseMethod("sql_len")
#' @export
sql_len.db_dialect <- function(d, x) paste0("LENGTH(", x, ")")
#' @export
sql_len.db_dialect_mssql <- function(d, x) paste0("LEN(", x, ")")

sql_avg_float <- function(d, x) UseMethod("sql_avg_float")
#' @export
sql_avg_float.db_dialect <- function(d, x) paste0("AVG(CAST(", x, " AS DOUBLE PRECISION))")
#' @export
sql_avg_float.db_dialect_sqlite <- function(d, x) paste0("AVG(", x, ")")
#' @export
sql_avg_float.db_dialect_mssql <- function(d, x) paste0("AVG(CAST(", x, " AS FLOAT))")

# 1 when the boolean column is true, else 0
sql_bool_is_true <- function(d, x) UseMethod("sql_bool_is_true")
#' @export
sql_bool_is_true.db_dialect <- function(d, x) paste0("CASE WHEN ", x, " THEN 1 ELSE 0 END")
#' @export
sql_bool_is_true.db_dialect_mssql <- function(d, x) paste0("CASE WHEN ", x, " = 1 THEN 1 ELSE 0 END")
#' @export
sql_bool_is_true.db_dialect_sqlite <- function(d, x) {
  paste0("CASE WHEN ", x, " IN (1, 'true', 'TRUE', 'True', 't', 'T') THEN 1 ELSE 0 END")
}

#' Convert an expression to text so that mixed types come back in one row
#' @noRd
sql_to_text <- function(d, x, type_class) UseMethod("sql_to_text")
#' @export
sql_to_text.db_dialect <- function(d, x, type_class) paste0("CAST(", x, " AS VARCHAR)")
#' @export
sql_to_text.db_dialect_sqlite <- function(d, x, type_class) paste0("CAST(", x, " AS TEXT)")
#' @export
sql_to_text.db_dialect_mssql <- function(d, x, type_class) {
  switch(type_class,
    datetime = paste0("CONVERT(VARCHAR(34), ", x, ", 126)"),
    date = paste0("CONVERT(VARCHAR(10), ", x, ", 23)"),
    time = paste0("CONVERT(VARCHAR(16), ", x, ", 114)"),
    numeric = paste0("CONVERT(VARCHAR(60), ", x, ", 2)"),
    paste0("CAST(", x, " AS NVARCHAR(200))")
  )
}

#' Build a SELECT with an optional row limit, in the dialect's syntax
#' @noRd
sql_select <- function(d, select, from, where = NULL, group_by = NULL, order_by = NULL, n = NULL) {
  UseMethod("sql_select")
}
#' @export
sql_select.db_dialect <- function(d, select, from, where = NULL, group_by = NULL, order_by = NULL, n = NULL) {
  paste0(
    "SELECT ", paste(select, collapse = ", "), " FROM ", from,
    if (!is.null(where)) paste0(" WHERE ", where),
    if (!is.null(group_by)) paste0(" GROUP BY ", paste(group_by, collapse = ", ")),
    if (!is.null(order_by)) paste0(" ORDER BY ", paste(order_by, collapse = ", ")),
    if (!is.null(n)) paste0(" LIMIT ", format(n, scientific = FALSE))
  )
}
#' @export
sql_select.db_dialect_mssql <- function(d, select, from, where = NULL, group_by = NULL, order_by = NULL, n = NULL) {
  paste0(
    "SELECT ", if (!is.null(n)) paste0("TOP (", format(n, scientific = FALSE), ") "),
    paste(select, collapse = ", "), " FROM ", from,
    if (!is.null(where)) paste0(" WHERE ", where),
    if (!is.null(group_by)) paste0(" GROUP BY ", paste(group_by, collapse = ", ")),
    if (!is.null(order_by)) paste0(" ORDER BY ", paste(order_by, collapse = ", "))
  )
}

# ---- sampling ----------------------------------------------------------------

#' A SELECT that draws roughly `n` rows from a relation
#'
#' `row_count` is the known full row count, used by engines that sample by
#' percentage. Engines without row sampling fall back to the first `n` rows,
#' which is cheap but biased; the profile records which happened in
#' `sample_method`.
#' @return list(sql = <select>, method = <character>)
#' @noRd
sql_sample_select <- function(d, ref, n, row_count, is_view = FALSE) UseMethod("sql_sample_select")
#' @export
sql_sample_select.db_dialect <- function(d, ref, n, row_count, is_view = FALSE) {
  list(sql = sql_select(d, "*", ref, n = n), method = "first_rows")
}
#' @export
sql_sample_select.db_dialect_mssql <- function(d, ref, n, row_count, is_view = FALSE) {
  if (is_view) {
    list(sql = sql_select(d, "*", ref, n = n), method = "first_rows")
  } else {
    # TABLESAMPLE is page based so the row count is approximate; ask for a
    # little more than n and let the caller record how many came back.
    list(
      sql = paste0("SELECT * FROM ", ref, " TABLESAMPLE SYSTEM (", format(ceiling(n * 1.1), scientific = FALSE), " ROWS)"),
      method = "tablesample_system"
    )
  }
}
#' @export
sql_sample_select.db_dialect_duckdb <- function(d, ref, n, row_count, is_view = FALSE) {
  list(
    sql = paste0("SELECT * FROM ", ref, " USING SAMPLE reservoir(", format(n, scientific = FALSE), " ROWS) REPEATABLE (42)"),
    method = "reservoir"
  )
}
#' @export
sql_sample_select.db_dialect_sqlite <- function(d, ref, n, row_count, is_view = FALSE) {
  list(
    sql = paste0("SELECT * FROM ", ref, " ORDER BY random() LIMIT ", format(n, scientific = FALSE)),
    method = "random_order"
  )
}
#' @export
sql_sample_select.db_dialect_postgres <- function(d, ref, n, row_count, is_view = FALSE) {
  if (is_view || is.na(row_count) || row_count <= 0) {
    return(list(sql = sql_select(d, "*", ref, n = n), method = "first_rows"))
  }
  pct <- min(100, 100 * n / row_count * 1.1)
  list(
    sql = paste0("SELECT * FROM ", ref, " TABLESAMPLE SYSTEM (", format(pct, digits = 6), ")"),
    method = "tablesample_system"
  )
}

#' Materialise a SELECT as a session temporary table
#' @return list(create = <sql>, ref = <quoted reference>, drop = <sql>)
#' @noRd
sql_temp_table <- function(d, name, select_sql) UseMethod("sql_temp_table")
#' @export
sql_temp_table.db_dialect <- function(d, name, select_sql) {
  ref <- sql_quote_ident(d, name)
  list(
    create = paste0("CREATE TEMPORARY TABLE ", ref, " AS ", select_sql),
    ref = ref,
    drop = paste0("DROP TABLE IF EXISTS ", ref)
  )
}
#' @export
sql_temp_table.db_dialect_mssql <- function(d, name, select_sql) {
  ref <- paste0("[#", gsub("]", "]]", name, fixed = TRUE), "]")
  list(
    create = paste0("SELECT * INTO ", ref, " FROM (", select_sql, ") AS db_inventory_sample"),
    ref = ref,
    drop = paste0("DROP TABLE ", ref)
  )
}

# ---- type classification -----------------------------------------------------

#' Classify a database type name
#'
#' Maps engine-specific type names to one of: `datetime`, `date`, `time`,
#' `boolean`, `integer`, `numeric`, `string`, `uuid`, `binary`, `lob`,
#' `complex`, `other`. The class decides which statistics the profiler asks
#' for (for example no `MIN()` on a `bit`, no `COUNT(DISTINCT)` on `text`).
#'
#' @param data_type Character vector of type names as reported by the engine.
#' @param dialect A dialect object or name; SQL Server treats `timestamp` as
#'   a binary row version, other engines as a datetime.
#' @return Character vector of type classes.
#' @examples
#' type_class(c("nvarchar", "datetime2", "bit", "decimal", "uniqueidentifier"), "mssql")
#' @export
type_class <- function(data_type, dialect = "generic") {
  d <- if (inherits(dialect, "db_dialect")) dialect else new_dialect(dialect)
  t <- tolower(trimws(as.character(data_type)))
  t <- sub("\\s*\\(.*$", "", t)         # drop "(10, 2)" style suffixes
  t <- sub("\\[\\]$", "[]", t)
  out <- rep("other", length(t))
  is <- function(pattern) grepl(pattern, t, perl = TRUE)

  out[is("^(datetime|datetime2|smalldatetime|datetimeoffset|timestamp.*|timestamptz|timestamp_(s|ms|us|ns))$")] <- "datetime"
  out[is("^date$")] <- "date"
  out[is("^(time|time with time zone|time without time zone|timetz|interval)$")] <- "time"
  out[is("^(bit|bool|boolean|logical)$")] <- "boolean"
  out[is("^(int|integer|bigint|smallint|tinyint|int1|int2|int4|int8|int16|int32|int64|hugeint|uhugeint|ubigint|uinteger|usmallint|utinyint|serial|bigserial|smallserial|mediumint|long)$")] <- "integer"
  out[is("^(decimal|numeric|float|float4|float8|real|double|double precision|money|smallmoney|number|dec)$")] <- "numeric"
  out[is("^(char|nchar|varchar|nvarchar|varchar2|nvarchar2|character|character varying|text|string|clob|nclob|citext|name|bpchar|enum|json|jsonb|varying character|native character|longtext|mediumtext|tinytext)$")] <- "string"
  out[is("^(uniqueidentifier|uuid|guid)$")] <- "uuid"
  out[is("^(binary|varbinary|bytea|blob|longblob|mediumblob|tinyblob|raw)$")] <- "binary"
  out[is("^(image|xml|geography|geometry|hierarchyid|sql_variant|ntext)$")] <- "lob"
  out[is("\\[\\]$|^(list|struct|map|union|array)")] <- "complex"

  if (d$name == "mssql") {
    out[t %in% c("timestamp", "rowversion")] <- "binary"
    out[t == "text"] <- "lob"
  }
  if (d$name == "sqlite") {
    # SQLite declared types are free text; anything containing these words
    # follows SQLite's affinity rules.
    out[out == "other" & is("int")] <- "integer"
    out[out == "other" & is("char|clob|text")] <- "string"
    out[out == "other" & is("blob")] <- "binary"
    out[out == "other" & is("real|floa|doub")] <- "numeric"
    out[out == "other" & is("date|time")] <- "datetime"
  }
  out
}
