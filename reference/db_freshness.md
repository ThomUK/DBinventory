# Find the newest datetime in each table

For every table with at least one date or datetime column, runs one
query taking `MAX()` of each such column and records the overall newest
value and the column that held it. This is the freshness signal of the
inventory.

## Usage

``` r
db_freshness(
  con,
  tables = NULL,
  columns = NULL,
  dialect = NULL,
  progress = interactive()
)
```

## Arguments

- con:

  A `DBIConnection`.

- tables:

  A table list as returned by
  [`db_tables()`](https://thomuk.github.io/DBinventory/reference/db_tables.md).
  Defaults to every table visible on the connection.

- columns:

  A column list from
  [`db_columns()`](https://thomuk.github.io/DBinventory/reference/db_columns.md);
  computed if `NULL`.

- dialect:

  Optional dialect override, see
  [`db_dialect()`](https://thomuk.github.io/DBinventory/reference/db_dialect.md).

- progress:

  Show a progress bar? Default `TRUE` in interactive use.

## Value

`tables` with `newest_datetime`, `newest_datetime_column` and
`n_datetime_columns` added. `newest_datetime` is ISO 8601 text as the
engine rendered it, so that date-only and sub-second types coexist. It
is the newest value up to a year ahead of today across the table's date
columns, so a column of placeholder dates (`2099-12-31`) does not hide
the real activity; only when every date column is beyond that horizon is
the far-future value reported.
