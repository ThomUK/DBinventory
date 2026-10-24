# List the columns of a set of tables

List the columns of a set of tables

## Usage

``` r
db_columns(con, tables = NULL, dialect = NULL)
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

## Value

A tibble with one row per column: `table_schema`, `table_name`,
`column_name`, `ordinal_position`, `data_type`, `type_class`,
`character_maximum_length`, `numeric_precision`, `numeric_scale`,
`is_nullable`.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- fakehospdata::fh_connect("sample")
cols <- db_columns(con, db_tables(con, include = "pas_patients"))
cols[, c("column_name", "data_type", "type_class")]
DBI::dbDisconnect(con, shutdown = TRUE)
} # }
```
