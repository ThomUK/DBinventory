#' Profile every column of a set of tables
#'
#' Artefact 2 of the roadmap. For each column: null rate, distinct count,
#' min and max, mean (numeric), string lengths, top values, uniqueness, an
#' inferred semantic type and two fingerprint hashes. Large tables are
#' profiled on a sample. Results can be checkpointed per table into a store
#' so that an interrupted run resumes where it stopped.
#'
#' @param con A `DBIConnection`.
#' @param inventory A `db_inventory` from [db_inventory()]. If `NULL` one is
#'   built first (row counts are needed to decide on sampling).
#' @param tables Optional subset of `inventory$tables` to profile.
#' @param sample_rows Tables with more rows than this are profiled on a
#'   sample of roughly this many rows. `Inf` disables sampling.
#' @param top_n How many most-frequent values to record per column.
#' @param top_values_max_distinct Only compute top values for columns with at
#'   most this many distinct values; beyond that a frequency table says little.
#' @param keep_values If `FALSE` (the default) the literal min, max and top
#'   values of columns inferred as identifiers or free text, or whose names
#'   suggest personal data, are suppressed and only their hashes kept. Set
#'   `TRUE` on a system where the profile output is itself safe to hold.
#' @param store Optional path to a SQLite store (see [store_open()]). Each
#'   table's profile is written as soon as it finishes.
#' @param resume If `TRUE` and `store` is given, tables already profiled
#'   successfully in the store are skipped.
#' @param column_batch Number of columns aggregated in one query. Lower it if
#'   the engine rejects very wide statements.
#' @param dialect Optional dialect override, see [db_dialect()].
#' @param progress Show a progress bar? Default `TRUE` in interactive use.
#' @return A tibble of class `column_profile`, one row per column. Columns
#'   include `null_rate`, `distinct_count`, `distinct_rate`, `is_unique`,
#'   `pk_candidate` (unique, never null and a string, integer or uuid type;
#'   on a sampled table this is evidence from the sample only),
#'   `min_value`, `max_value`, `mean_value`, `min_length`, `max_length`,
#'   `mean_length`, `true_count`, `top_values` (JSON), `top_values_hash`,
#'   `semantic_type`, `values_suppressed`, `value_fingerprint`,
#'   `column_fingerprint`, `rows_profiled`, `sampled`, `sample_method`,
#'   `profiled_at`.
#' @examples
#' con <- fakehosp_connection()
#' inv <- db_inventory(con, include = "pas_patients", progress = FALSE)
#' prof <- db_profile(con, inv, progress = FALSE)
#' prof[, c("column_name", "null_rate", "distinct_count", "semantic_type")]
#' DBI::dbDisconnect(con)
#' @export
db_profile <- function(con, inventory = NULL, tables = NULL, sample_rows = 1e6, top_n = 10,
                       top_values_max_distinct = 10000, keep_values = FALSE,
                       store = NULL, resume = TRUE, column_batch = 40,
                       dialect = NULL, progress = interactive()) {
  d <- db_dialect(con, dialect)
  if (is.null(inventory)) inventory <- db_inventory(con, dialect = d, progress = progress, sizes = FALSE, freshness = FALSE)
  if (is.null(tables)) tables <- inventory$tables
  columns <- inventory$columns

  st <- if (!is.null(store)) store_open(store) else NULL
  on.exit(if (!is.null(st)) store_close(st), add = TRUE)

  if (!is.null(st) && resume) {
    done <- store_tables_done(st)
    if (nrow(done) > 0) {
      key_t <- paste(tables$table_schema, tables$table_name, sep = "\r")
      key_d <- paste(done$table_schema, done$table_name, sep = "\r")
      skip <- key_t %in% key_d
      if (any(skip)) cli::cli_alert_info("Resuming: {sum(skip)} table{?s} already profiled, {sum(!skip)} to go")
      tables <- tables[!skip, , drop = FALSE]
    }
  }

  n <- nrow(tables)
  results <- vector("list", n)
  if (progress && n > 0) cli::cli_progress_bar("Profiling columns", total = n)
  for (i in seq_len(n)) {
    tab <- tables[i, , drop = FALSE]
    cols <- columns[columns$table_schema == tab$table_schema & columns$table_name == tab$table_name, , drop = FALSE]
    started <- Sys.time()
    res <- tryCatch(
      profile_table(con, d, tab, cols, sample_rows, top_n, top_values_max_distinct, keep_values, column_batch),
      error = function(e) e
    )
    if (inherits(res, "error")) {
      cli::cli_alert_warning("Profile failed for {tab$table_schema}.{tab$table_name}: {conditionMessage(res)}")
      if (!is.null(st)) store_log(st, tab, "error", elapsed_secs(started), conditionMessage(res))
    } else {
      results[[i]] <- res
      if (!is.null(st)) {
        store_write(st, "column_profile", res, append = TRUE)
        store_log(st, tab, "ok", elapsed_secs(started), NA_character_)
      }
    }
    if (progress) cli::cli_progress_update()
  }
  if (progress && n > 0) cli::cli_progress_done()
  out <- do.call(rbind, results)
  if (is.null(out)) out <- empty_profile()
  structure(as_tbl(out), class = c("column_profile", class(as_tbl(out))))
}

#' Profile one table
#' @noRd
profile_table <- function(con, d, tab, cols, sample_rows, top_n, top_values_max_distinct, keep_values, column_batch) {
  if (nrow(cols) == 0) rlang::abort("no columns listed for this object; it may be inaccessible or a broken view")
  ref <- sql_table_ref(d, tab$table_schema, tab$table_name)
  row_count <- as_num(tab$row_count %||% NA_real_)
  is_view <- identical(tab$table_type, "view")

  # ---- choose the source: the table itself or a materialised sample ---------
  sampled <- !is.na(row_count) && is.finite(sample_rows) && row_count > sample_rows
  sample_method <- "none"
  src <- ref
  drop_sql <- NULL
  if (sampled) {
    smp <- sql_sample_select(d, ref, sample_rows, row_count, is_view)
    tmp <- sql_temp_table(d, paste0("dbinv_", gsub("[^A-Za-z0-9]", "_", tab$table_name), "_", sample(1e6, 1)), smp$sql)
    db_exec(con, tmp$create)
    src <- tmp$ref
    drop_sql <- tmp$drop
    sample_method <- smp$method
  }
  on.exit(if (!is.null(drop_sql)) try(DBI::dbExecute(con, drop_sql), silent = TRUE), add = TRUE)

  # ---- aggregate statistics, a batch of columns per query --------------------
  cols$qname <- sql_quote_ident(d, cols$column_name)
  batches <- split(seq_len(nrow(cols)), ceiling(seq_len(nrow(cols)) / column_batch))
  rows_profiled <- NA_real_
  stats <- lapply(batches, function(idx) {
    sub <- cols[idx, , drop = FALSE]
    exprs <- c(paste0(sql_count_star(d), " AS n_rows"), unlist(lapply(seq_len(nrow(sub)), function(j) {
      column_aggregates(d, sub$qname[j], sub$type_class[j], paste0("c", j))
    })))
    res <- db_query(con, sql_select(d, exprs, src))
    rows_profiled <<- as_num(res$n_rows[1])
    lapply(seq_len(nrow(sub)), function(j) parse_aggregates(res, paste0("c", j), sub$type_class[j]))
  })
  stats <- do.call(rbind, lapply(unlist(stats, recursive = FALSE), as.data.frame, stringsAsFactors = FALSE))

  out <- data.frame(
    table_schema = cols$table_schema, table_name = cols$table_name, column_name = cols$column_name,
    ordinal_position = cols$ordinal_position, data_type = cols$data_type, type_class = cols$type_class,
    row_count = row_count, rows_profiled = rows_profiled, sampled = sampled, sample_method = sample_method,
    stringsAsFactors = FALSE
  )
  out$null_count <- rows_profiled - stats$nonnull
  out$null_rate <- if (isTRUE(rows_profiled > 0)) out$null_count / rows_profiled else rep(NA_real_, nrow(out))
  out$empty_count <- stats$empty
  out$distinct_count <- stats$distinct
  out$distinct_rate <- ifelse(stats$nonnull > 0, stats$distinct / stats$nonnull, NA_real_)
  out$is_unique <- !is.na(stats$distinct) & stats$nonnull > 0 & stats$distinct == stats$nonnull
  # a primary key candidate: unique, never null, and of a type keys are made of.
  # On a sampled table this is evidence from the sample only (see `sampled`).
  out$pk_candidate <- out$is_unique & out$null_count == 0 & cols$type_class %in% c("string", "integer", "uuid")
  out$min_value <- stats$min
  out$max_value <- stats$max
  out$mean_value <- stats$mean
  out$true_count <- stats$true
  out$min_length <- stats$minlen
  out$max_length <- stats$maxlen
  out$mean_length <- stats$avglen

  # ---- top values, one query per eligible column -----------------------------
  eligible <- cols$type_class %in% c("string", "integer", "numeric", "boolean", "date", "datetime", "uuid", "time") &
    !is.na(out$distinct_count) & out$distinct_count > 0 & out$distinct_count <= top_values_max_distinct
  top <- vector("list", nrow(cols))
  for (j in which(eligible)) {
    top[[j]] <- tryCatch(
      top_values(con, d, src, cols$qname[j], cols$type_class[j], top_n),
      error = function(e) NULL
    )
  }
  out$top_values <- vapply(top, function(x) if (is.null(x)) NA_character_ else jsonlite::toJSON(x, dataframe = "rows", na = "null", auto_unbox = FALSE), character(1))
  out$top_values_hash <- vapply(top, function(x) if (is.null(x)) NA_character_ else hash_values(x$value), character(1))

  # ---- inference, fingerprints, suppression ----------------------------------
  out$semantic_type <- infer_semantic_type(out, top)
  fp <- fingerprints(out)
  out$value_fingerprint <- fp$value
  out$column_fingerprint <- fp$column
  out$values_suppressed <- !keep_values & is_sensitive(out)
  sup <- out$values_suppressed
  out$min_value[sup & !out$type_class %in% c("date", "datetime", "time")] <- NA_character_
  out$max_value[sup & !out$type_class %in% c("date", "datetime", "time")] <- NA_character_
  out$top_values[sup] <- NA_character_
  out$profiled_at <- now_utc()
  out
}

#' SQL aggregate expressions for one column, by type class
#' @noRd
column_aggregates <- function(d, q, tc, prefix) {
  al <- function(expr, suffix) paste0(expr, " AS ", sql_quote_ident(d, paste0(prefix, "_", suffix)))
  nn <- al(paste0("COUNT(", q, ")"), "nn")
  dist <- al(paste0("COUNT(DISTINCT ", q, ")"), "dist")
  mn <- al(sql_to_text(d, paste0("MIN(", q, ")"), tc), "min")
  mx <- al(sql_to_text(d, paste0("MAX(", q, ")"), tc), "max")
  switch(tc,
    string = c(nn, dist, mn, mx,
      al(paste0("SUM(CASE WHEN ", q, " = '' THEN 1 ELSE 0 END)"), "empty"),
      al(paste0("MIN(", sql_len(d, q), ")"), "minlen"),
      al(paste0("MAX(", sql_len(d, q), ")"), "maxlen"),
      al(sql_avg_float(d, sql_len(d, q)), "avglen")),
    integer = , numeric = c(nn, dist, mn, mx, al(sql_avg_float(d, q), "mean")),
    datetime = , date = , time = , uuid = c(nn, dist, mn, mx),
    boolean = c(nn, dist, al(paste0("SUM(", sql_bool_is_true(d, q), ")"), "true")),
    nn
  )
}

parse_aggregates <- function(res, prefix, tc) {
  get <- function(suffix) {
    nm <- paste0(prefix, "_", suffix)
    if (nm %in% names(res)) res[[nm]][1] else NA
  }
  list(
    nonnull = as_num(get("nn")), distinct = as_num(get("dist")),
    min = as_chr(get("min")), max = as_chr(get("max")),
    mean = as_num(get("mean")), true = as_num(get("true")), empty = as_num(get("empty")),
    minlen = as_num(get("minlen")), maxlen = as_num(get("maxlen")), avglen = as_num(get("avglen"))
  )
}

top_values <- function(con, d, src, q, tc, top_n) {
  sql <- sql_select(
    d,
    select = c(paste0(sql_to_text(d, q, tc), " AS value"), paste0(sql_count_star(d), " AS value_count")),
    from = src, where = paste0(q, " IS NOT NULL"), group_by = q,
    order_by = c("value_count DESC", "value"), n = top_n
  )
  res <- db_query(con, sql)
  data.frame(value = as_chr(res$value), n = as_num(res$value_count), stringsAsFactors = FALSE)
}

hash_values <- function(x) digest::digest(sort(as.character(x)), algo = "xxhash64", serialize = TRUE)

empty_profile <- function() {
  data.frame(
    table_schema = character(), table_name = character(), column_name = character(),
    ordinal_position = integer(), data_type = character(), type_class = character(),
    row_count = numeric(), rows_profiled = numeric(), sampled = logical(), sample_method = character(),
    null_count = numeric(), null_rate = numeric(), empty_count = numeric(),
    distinct_count = numeric(), distinct_rate = numeric(), is_unique = logical(), pk_candidate = logical(),
    min_value = character(), max_value = character(), mean_value = numeric(), true_count = numeric(),
    min_length = numeric(), max_length = numeric(), mean_length = numeric(),
    top_values = character(), top_values_hash = character(), semantic_type = character(),
    value_fingerprint = character(), column_fingerprint = character(), values_suppressed = logical(),
    profiled_at = character(), stringsAsFactors = FALSE
  )
}

#' Read the top values of a profile row back into a data frame
#'
#' @param x A `column_profile` row's `top_values` JSON string, or the profile
#'   itself together with `column` and (optionally) `table`.
#' @param table,column Table and column name when `x` is a profile.
#' @return A data frame with `value` and `n`, or `NULL` when not recorded.
#' @export
top_values_of <- function(x, table = NULL, column = NULL) {
  if (is.data.frame(x)) {
    keep <- x$column_name == column
    if (!is.null(table)) keep <- keep & x$table_name == table
    x <- x$top_values[keep][1]
  }
  if (is.na(x)) return(NULL)
  jsonlite::fromJSON(x)
}
