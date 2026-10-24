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
  schema = NULL,
  include = NULL,
  exclude = NULL,
  views = TRUE,
  sample_rows = 1e+06,
  top_n = 10,
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
  this many rows. `Inf` disables sampling.

- top_n:

  How many most-frequent values to record per column.

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
out <- inventory_run(fakehosp_path(), store = tempfile(fileext = ".sqlite"),
                     include = "pas_patients", progress = FALSE)
#> ℹ 1 table found (sqlite dialect)
#> ✔ Inventory of 1 table and 10 columns in 0s
#> ✔ Run complete in 0.1s: 10 column profiles in /tmp/Rtmps5p3kR/file1a9c30a7f7d4.sqlite
out$profile[, c("column_name", "semantic_type", "null_rate")]
#> # A tibble: 10 × 3
#>    column_name         semantic_type null_rate
#>    <chr>               <chr>             <dbl>
#>  1 mrn                 identifier        0    
#>  2 nhs_number          identifier        0.007
#>  3 nhs_number_status   code              0    
#>  4 sex                 code              0    
#>  5 dob                 date              0    
#>  6 ethnicity           code              0    
#>  7 gp_practice         category          0    
#>  8 postcode            identifier        0    
#>  9 registered_datetime datetime          0    
#> 10 date_of_death       date              0.987
```
