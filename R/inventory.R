#' List the tables and views visible on a connection
#'
#' Reads `INFORMATION_SCHEMA.TABLES` (or the engine's equivalent) and applies
#' optional filters. System schemas are excluded.
#'
#' @param con A `DBIConnection`.
#' @param schema Optional character vector of schema names to keep.
#' @param include,exclude Optional regular expressions matched (case
#'   insensitively) against `"schema.table"`. A table is kept if it matches
#'   any `include` pattern and no `exclude` pattern.
#' @param views Keep views as well as base tables? Default `TRUE`.
#' @param dialect Optional dialect override, see [db_dialect()].
#' @return A tibble with `table_catalog`, `table_schema`, `table_name`,
#'   `table_type`.
#' @examples
#' \dontrun{
#' con <- fakehospdata::fh_connect("sample")   # the synthetic trust
#' db_tables(con, include = "^layer1\\.pas_")
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' }
#' @export
db_tables <- function(con, schema = NULL, include = NULL, exclude = NULL, views = TRUE, dialect = NULL) {
  d <- db_dialect(con, dialect)
  tables <- db_query(con, sql_list_tables(d))
  names(tables) <- tolower(names(tables))
  tables$table_catalog <- as_chr(tables$table_catalog)
  tables$table_schema <- as_chr(tables$table_schema)
  tables$table_name <- as_chr(tables$table_name)
  tables$table_type <- as_chr(tables$table_type)
  tables <- filter_tables(tables, schema, include, exclude, views)
  tables <- tables[order(tables$table_schema, tables$table_name), ]
  as_tbl(tables[, c("table_catalog", "table_schema", "table_name", "table_type")])
}

#' List the columns of a set of tables
#'
#' @inheritParams db_tables
#' @param tables A table list as returned by [db_tables()]. Defaults to every
#'   table visible on the connection.
#' @return A tibble with one row per column: `table_schema`, `table_name`,
#'   `column_name`, `ordinal_position`, `data_type`, `type_class`,
#'   `character_maximum_length`, `numeric_precision`, `numeric_scale`,
#'   `is_nullable`.
#' @examples
#' \dontrun{
#' con <- fakehospdata::fh_connect("sample")
#' cols <- db_columns(con, db_tables(con, include = "pas_patients"))
#' cols[, c("column_name", "data_type", "type_class")]
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' }
#' @export
db_columns <- function(con, tables = NULL, dialect = NULL) {
  d <- db_dialect(con, dialect)
  if (is.null(tables)) tables <- db_tables(con, dialect = d)
  sql <- sql_list_columns(d)
  if (!is.null(sql)) {
    cols <- db_query(con, sql)
    names(cols) <- tolower(names(cols))
    key_cols <- paste(cols$table_schema, cols$table_name, sep = "\r")
    key_tabs <- paste(tables$table_schema, tables$table_name, sep = "\r")
    cols <- cols[key_cols %in% key_tabs, , drop = FALSE]
  } else {
    parts <- lapply(seq_len(nrow(tables)), function(i) {
      tryCatch(
        db_query(con, sql_list_table_columns(d, tables$table_schema[i], tables$table_name[i])),
        error = function(e) {
          cli::cli_alert_warning("Column listing failed for {tables$table_schema[i]}.{tables$table_name[i]}: {conditionMessage(e)}")
          NULL
        }
      )
    })
    cols <- do.call(rbind, parts)
    if (is.null(cols)) cols <- empty_columns()
    names(cols) <- tolower(names(cols))
  }
  out <- data.frame(
    table_schema = as_chr(cols$table_schema),
    table_name = as_chr(cols$table_name),
    column_name = as_chr(cols$column_name),
    ordinal_position = as.integer(as_num(cols$ordinal_position)),
    data_type = as_chr(cols$data_type),
    stringsAsFactors = FALSE
  )
  out$type_class <- type_class(out$data_type, d)
  out$character_maximum_length <- as_num(cols$character_maximum_length)
  out$numeric_precision <- as_num(cols$numeric_precision)
  out$numeric_scale <- as_num(cols$numeric_scale)
  out$is_nullable <- toupper(as_chr(cols$is_nullable)) %in% c("YES", "Y", "1", "TRUE")
  out <- out[order(out$table_schema, out$table_name, out$ordinal_position), ]
  as_tbl(out)
}

empty_columns <- function() {
  data.frame(
    table_schema = character(), table_name = character(), column_name = character(),
    ordinal_position = integer(), data_type = character(),
    character_maximum_length = numeric(), numeric_precision = numeric(),
    numeric_scale = numeric(), is_nullable = character(), stringsAsFactors = FALSE
  )
}

#' Count the rows of each table
#'
#' Issues one `COUNT(*)` per table. Tables that fail (permissions, broken
#' views) get `NA` and a message rather than stopping the run.
#'
#' @inheritParams db_columns
#' @param progress Show a progress bar? Default `TRUE` in interactive use.
#' @return `tables` with a `row_count` column added.
#' @export
db_row_counts <- function(con, tables = NULL, dialect = NULL, progress = interactive()) {
  d <- db_dialect(con, dialect)
  if (is.null(tables)) tables <- db_tables(con, dialect = d)
  n <- nrow(tables)
  counts <- rep(NA_real_, n)
  if (progress && n > 0) cli::cli_progress_bar("Counting rows", total = n)
  for (i in seq_len(n)) {
    ref <- sql_table_ref(d, tables$table_schema[i], tables$table_name[i])
    counts[i] <- tryCatch(
      as_num(db_query(con, sql_select(d, paste0(sql_count_star(d), " AS n"), ref))$n[1]),
      error = function(e) {
        cli::cli_alert_warning("Row count failed for {ref}: {conditionMessage(e)}")
        NA_real_
      }
    )
    if (progress) cli::cli_progress_update()
  }
  if (progress && n > 0) cli::cli_progress_done()
  tables$row_count <- counts
  tables
}

#' Find the newest datetime in each table
#'
#' For every table with at least one date or datetime column, runs one query
#' taking `MAX()` of each such column and records the overall newest value and
#' the column that held it. This is the freshness signal of the inventory.
#'
#' @inheritParams db_row_counts
#' @param columns A column list from [db_columns()]; computed if `NULL`.
#' @return `tables` with `newest_datetime`, `newest_datetime_column` and
#'   `n_datetime_columns` added. `newest_datetime` is ISO 8601 text as the
#'   engine rendered it, so that date-only and sub-second types coexist.
#' @export
db_freshness <- function(con, tables = NULL, columns = NULL, dialect = NULL, progress = interactive()) {
  d <- db_dialect(con, dialect)
  if (is.null(tables)) tables <- db_tables(con, dialect = d)
  if (is.null(columns)) columns <- db_columns(con, tables, dialect = d)
  n <- nrow(tables)
  newest <- rep(NA_character_, n)
  newest_col <- rep(NA_character_, n)
  n_dt <- rep(0L, n)
  if (progress && n > 0) cli::cli_progress_bar("Finding newest datetimes", total = n)
  for (i in seq_len(n)) {
    cols <- columns[
      columns$table_schema == tables$table_schema[i] &
        columns$table_name == tables$table_name[i] &
        columns$type_class %in% c("datetime", "date"), ,
      drop = FALSE
    ]
    n_dt[i] <- nrow(cols)
    if (nrow(cols) > 0) {
      ref <- sql_table_ref(d, tables$table_schema[i], tables$table_name[i])
      exprs <- paste0(
        sql_to_text(d, paste0("MAX(", sql_quote_ident(d, cols$column_name), ")"), cols$type_class),
        " AS ", sql_quote_ident(d, paste0("c", seq_len(nrow(cols))))
      )
      res <- tryCatch(db_query(con, sql_select(d, exprs, ref)), error = function(e) {
        cli::cli_alert_warning("Freshness query failed for {ref}: {conditionMessage(e)}")
        NULL
      })
      if (!is.null(res) && nrow(res) == 1) {
        vals <- as_chr(unlist(res[1, ], use.names = FALSE))
        vals <- sub("T", " ", vals, fixed = TRUE)
        if (any(!is.na(vals))) {
          j <- which(vals == max(vals, na.rm = TRUE))[1]
          newest[i] <- vals[j]
          newest_col[i] <- cols$column_name[j]
        }
      }
    }
    if (progress) cli::cli_progress_update()
  }
  if (progress && n > 0) cli::cli_progress_done()
  tables$newest_datetime <- newest
  tables$newest_datetime_column <- newest_col
  tables$n_datetime_columns <- n_dt
  tables
}

#' Read table sizes from the engine's system views
#'
#' SQL Server (`sys.dm_db_partition_stats`) and PostgreSQL
#' (`pg_total_relation_size`) are supported. Other engines, or a SQL Server
#' login without `VIEW DATABASE STATE`, give `NA` with a message.
#'
#' @inheritParams db_row_counts
#' @return `tables` with `size_bytes` and `row_count_stats` (the engine's own
#'   row estimate) added.
#' @export
db_table_sizes <- function(con, tables = NULL, dialect = NULL) {
  d <- db_dialect(con, dialect)
  if (is.null(tables)) tables <- db_tables(con, dialect = d)
  tables$size_bytes <- NA_real_
  tables$row_count_stats <- NA_real_
  sql <- sql_table_sizes(d)
  if (is.null(sql)) return(tables)
  # a dialect may offer several queries, each needing fewer permissions than the last
  sizes <- NULL
  for (q in sql) {
    sizes <- tryCatch(db_query(con, q), error = function(e) {
      if (q == sql[length(sql)]) cli::cli_alert_info("Table sizes unavailable ({conditionMessage(e)}); size_bytes left NA")
      NULL
    })
    if (!is.null(sizes)) break
  }
  if (is.null(sizes) || nrow(sizes) == 0) return(tables)
  names(sizes) <- tolower(names(sizes))
  key_s <- paste(tolower(sizes$table_schema), tolower(sizes$table_name), sep = "\r")
  key_t <- paste(tolower(tables$table_schema), tolower(tables$table_name), sep = "\r")
  m <- match(key_t, key_s)
  tables$size_bytes <- as_num(sizes$size_bytes)[m]
  tables$row_count_stats <- as_num(sizes$row_count_stats)[m]
  tables
}

#' Build the inventory: every table and column with counts and freshness
#'
#' Artefact 1 of the roadmap. Combines [db_tables()], [db_columns()],
#' [db_row_counts()], [db_freshness()] and [db_table_sizes()] into one call
#' that needs only `SELECT` permission on the objects.
#'
#' @inheritParams db_tables
#' @param row_counts,freshness,sizes Switch off the slower steps if needed.
#' @param progress Show progress bars? Default `TRUE` in interactive use.
#' @return A list of class `db_inventory` with two tibbles: `tables` (one row
#'   per table or view, with `n_columns`, `row_count`, `size_bytes`,
#'   `newest_datetime`, `newest_datetime_column`, `inventoried_at`) and
#'   `columns` (one row per column, see [db_columns()]).
#' @examples
#' \dontrun{
#' con <- fakehospdata::fh_connect("sample")
#' inv <- db_inventory(con, include = "pas_", progress = FALSE)
#' inv$tables[, c("table_name", "n_columns", "row_count", "newest_datetime")]
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' }
#' @export
db_inventory <- function(con, schema = NULL, include = NULL, exclude = NULL, views = TRUE,
                         row_counts = TRUE, freshness = TRUE, sizes = TRUE,
                         dialect = NULL, progress = interactive()) {
  d <- db_dialect(con, dialect)
  started <- Sys.time()
  tables <- db_tables(con, schema, include, exclude, views, dialect = d)
  cli::cli_alert_info("{nrow(tables)} table{?s} found ({d$name} dialect)")
  columns <- db_columns(con, tables, dialect = d)
  key_c <- paste(columns$table_schema, columns$table_name, sep = "\r")
  key_t <- paste(tables$table_schema, tables$table_name, sep = "\r")
  tables$n_columns <- as.integer(table(factor(key_c, levels = key_t)))
  if (row_counts) tables <- db_row_counts(con, tables, dialect = d, progress = progress) else tables$row_count <- NA_real_
  if (sizes) tables <- db_table_sizes(con, tables, dialect = d) else { tables$size_bytes <- NA_real_; tables$row_count_stats <- NA_real_ }
  if (freshness) {
    tables <- db_freshness(con, tables, columns, dialect = d, progress = progress)
  } else {
    tables$newest_datetime <- NA_character_
    tables$newest_datetime_column <- NA_character_
    tables$n_datetime_columns <- NA_integer_
  }
  tables$inventoried_at <- now_utc()
  cli::cli_alert_success("Inventory of {nrow(tables)} table{?s} and {nrow(columns)} column{?s} in {round(elapsed_secs(started), 1)}s")
  structure(list(tables = as_tbl(tables), columns = columns, dialect = d$name), class = "db_inventory")
}

#' @export
print.db_inventory <- function(x, ...) {
  cat("<db_inventory>", nrow(x$tables), "tables,", nrow(x$columns), "columns,", x$dialect, "dialect\n")
  print(x$tables[, intersect(c("table_schema", "table_name", "table_type", "n_columns", "row_count", "newest_datetime"), names(x$tables))], ...)
  invisible(x)
}
