# Export the store's tables to CSV or Parquet files

One file per store table, named after it. CSV needs nothing extra;
Parquet uses `arrow` if installed, else `duckdb`, else stops.

## Usage

``` r
store_export(store, dir, format = c("csv", "parquet"), tables = NULL)
```

## Arguments

- store:

  A `db_store`.

- dir:

  Output directory, created if needed.

- format:

  `"csv"` or `"parquet"`.

- tables:

  Which store tables to export; default all.

## Value

Character vector of files written, invisibly.
