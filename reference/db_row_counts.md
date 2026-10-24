# Count the rows of each table

Issues one `COUNT(*)` per table. Tables that fail (permissions, broken
views) get `NA` and a message rather than stopping the run.

## Usage

``` r
db_row_counts(con, tables = NULL, dialect = NULL, progress = interactive())
```

## Arguments

- con:

  A `DBIConnection`.

- tables:

  A table list as returned by
  [`db_tables()`](https://thomuk.github.io/DBinventory/reference/db_tables.md).
  Defaults to every table visible on the connection.

- dialect:

  Optional dialect override, see
  [`db_dialect()`](https://thomuk.github.io/DBinventory/reference/db_dialect.md).

- progress:

  Show a progress bar? Default `TRUE` in interactive use.

## Value

`tables` with a `row_count` column added.
