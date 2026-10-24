# Open (or create) a results store

The store is a SQLite file holding the inventory, the column profile and
a per-table log of profiling runs. It is the checkpoint that lets a
multi-hour profile resume, and the input to the report and exports.
Requires the `RSQLite` package.

## Usage

``` r
store_open(path)

store_close(store)

store_tables(store)
```

## Arguments

- path:

  Path to a `.sqlite` file; created if missing.

- store:

  A `db_store`.

## Value

A `db_store` object wrapping a DBI connection.

## Examples

``` r
st <- store_open(tempfile(fileext = ".sqlite"))
store_tables(st)
#> [1] "profile_log"
store_close(st)
```
