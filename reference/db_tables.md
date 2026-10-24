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
con <- fakehosp_connection()
db_tables(con, include = "^main\\.pas_")
#> # A tibble: 5 × 4
#>   table_catalog table_schema table_name                  table_type
#>   <chr>         <chr>        <chr>                       <chr>     
#> 1 NA            main         pas_adt_events              table     
#> 2 NA            main         pas_op_status_log           table     
#> 3 NA            main         pas_outpatient_appointments table     
#> 4 NA            main         pas_patients                table     
#> 5 NA            main         pas_referrals               table     
DBI::dbDisconnect(con)
```
