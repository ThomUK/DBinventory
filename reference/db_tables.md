# List the tables and views visible on a connection

Reads `INFORMATION_SCHEMA.TABLES` (or the engine's equivalent) and
applies optional filters. System schemas are excluded.

## Usage

``` r
db_tables(
  con,
  schema = NULL,
  include = NULL,
  exclude = NULL,
  views = TRUE,
  dialect = NULL
)
```

## Arguments

- con:

  A `DBIConnection`.

- schema:

  Optional character vector of schema names to keep.

- include, exclude:

  Optional regular expressions matched (case insensitively) against
  `"schema.table"`. A table is kept if it matches any `include` pattern
  and no `exclude` pattern.

- views:

  Keep views as well as base tables? Default `TRUE`.

- dialect:

  Optional dialect override, see
  [`db_dialect()`](https://thomuk.github.io/DBinventory/reference/db_dialect.md).

## Value

A tibble with `table_catalog`, `table_schema`, `table_name`,
`table_type`.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- fakehospdata::fh_connect("sample")   # the synthetic trust
db_tables(con, include = "^layer1\\.pas_")
DBI::dbDisconnect(con, shutdown = TRUE)
} # }
```
