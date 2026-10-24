# The bundled synthetic hospital database

A SQLite file built from the sample of
<https://github.com/ThomUK/synthetic-hospital-data>: 45 tables and a
view from a fictional NHS trust, capped at 1,000 rows each, with the
declared column types preserved. Used by the examples and tests; handy
for trying the package before pointing it at a real warehouse.

## Usage

``` r
fakehosp_path()

fakehosp_connection()
```

## Value

`fakehosp_path()` gives the file path; `fakehosp_connection()` opens a
read-only `RSQLite` connection to it.

## Examples

``` r
con <- fakehosp_connection()
nrow(db_tables(con))
#> [1] 46
DBI::dbDisconnect(con)
```
