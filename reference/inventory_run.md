# Inventory and profile a database in one call

The end-to-end run: connect, build the inventory (artefact 1), write it
to the store, profile every column (artefact 2) with per-table
checkpointing, optionally export CSV or Parquet and render the report.
Re-running with the same store resumes an interrupted profile; pass
`resume = FALSE` to start over.

## Usage

``` r
inventory_run(
  source,
  store = "db_inventory.sqlite",
  export_dir = NULL,
  export_format = c("csv", "parquet"),
  report = NULL,
  organisation = NULL,
  schema = NULL,
  include = NULL,
  exclude = NULL,
  views = TRUE,
  sample_rows = 1e+06,
  top_n = 10,
  full_set_max = 50,
  top_values_max_distinct = 10000,
  keep_values = FALSE,
  resume = TRUE,
  sizes = TRUE,
  dialect = NULL,
  progress = interactive(),
  disconnect = TRUE
)
```

## Arguments

- source:

  Anything
  [`db_connect()`](https://thomuk.github.io/DBinventory/reference/db_connect.md)
  accepts: a `DBIConnection`, an ODBC connection string or DSN, a SQLite
  or DuckDB file, or a Parquet file or directory.

- store:

  Path to the SQLite results store. Default `"db_inventory.sqlite"` in
  the working directory.

- export_dir:

  If given, the store is exported here after the run.

- export_format:

  `"csv"` (default) or `"parquet"`.

- report:

  If given, the path of an HTML report to render, see
  [`render_report()`](https://thomuk.github.io/DBinventory/reference/render_report.md).

- organisation:

  Name of the trust or organisation the database belongs to. Recorded in
  the store's `run_meta` and used to prefix the report title.

- schema:

  Optional character vector of schema names to keep.

- include, exclude:

  Optional regular expressions matched (case insensitively) against
  `"schema.table"`. A table is kept if it matches any `include` pattern
  and no `exclude` pattern.

- views:

  Keep views as well as base tables? Default `TRUE`.

- sample_rows:

  Tables with more rows than this are profiled on a sample of roughly
  this many rows. `Inf` disables sampling, which is the faster choice on
  DuckDB and Parquet, where aggregates over the full table cost less
  than materialising a sample; the threshold is for engines such as SQL
  Server where a full scan is the expensive part.

- top_n:

  How many most-frequent values to record per column.

- full_set_max:

  Columns with at most this many distinct values have every value
  recorded, not just the top `top_n`, so that a code list's frequency
  table is complete and foreign key membership can be tested against it.

- top_values_max_distinct:

  Only compute top values for columns with at most this many distinct
  values; beyond that a frequency table says little.

- keep_values:

  If `FALSE` (the default) the literal min, max and top values of
  columns inferred as identifiers or free text, or whose names suggest
  personal data, are suppressed and only their hashes kept. Set `TRUE`
  on a system where the profile output is itself safe to hold.

- resume:

  Skip tables already profiled in `store`? Default `TRUE`.

- sizes:

  Read table sizes from system views? Default `TRUE`.

- dialect:

  Optional dialect override, see
  [`db_dialect()`](https://thomuk.github.io/DBinventory/reference/db_dialect.md).

- progress:

  Show progress bars? Default `TRUE` in interactive use.

- disconnect:

  Disconnect a connection this function opened? Default `TRUE`; a
  connection passed in is never closed.

## Value

Invisibly, a list with `inventory` (a `db_inventory`), `profile` (a
`column_profile`, the full contents of the store including earlier runs)
and `store` (the store path).

## Examples

``` r
if (FALSE) { # \dontrun{
# the synthetic trust, through the fakehospdata package
con <- fakehospdata::fh_connect("sample")
out <- inventory_run(con, store = "fakehosp_inventory.sqlite", organisation = "Fake NHS Trust",
                     report = "fakehosp_inventory.html")
out$profile[, c("table_name", "column_name", "semantic_type", "null_rate")]
DBI::dbDisconnect(con, shutdown = TRUE)
} # }
```
