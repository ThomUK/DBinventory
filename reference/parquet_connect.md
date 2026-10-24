# Expose Parquet files as a database of views

Creates an in-memory DuckDB connection with one view per Parquet file
(or per directory of Parquet files, for partitioned tables), so that
every other function in the package works on a Parquet store exactly as
on a database. Requires the `duckdb` package.

## Usage

``` r
parquet_connect(path, union_by_name = TRUE, ...)
```

## Arguments

- path:

  A directory, or one or more `.parquet` files.

- union_by_name:

  Pass `union_by_name = true` to `read_parquet()` so partitions with
  evolving columns still load.

- ...:

  Passed to
  [`DBI::dbConnect()`](https://dbi.r-dbi.org/reference/dbConnect.html)
  for duckdb.

## Value

A `duckdb_connection`. Disconnect with
`DBI::dbDisconnect(con, shutdown = TRUE)`.

## Details

Given a directory, files are found recursively. Each directory becomes a
schema (nested paths joined with `_`; files at the root go in `main`). A
directory that holds two or more Parquet files, no subdirectories, and
whose files all share one column schema is read as a single partitioned
table named after the directory, so
`layer1/pas_adt_events/fy2022.parquet` and `fy2023.parquet` become the
view `layer1.pas_adt_events`. A directory whose files differ in schema
is a schema of separate tables.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- parquet_connect("data/v2/sample")
db_tables(con)
inv <- db_inventory(con)
} # }
```
