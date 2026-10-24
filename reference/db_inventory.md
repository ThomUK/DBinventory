# Build the inventory: every table and column with counts and freshness

Artefact 1 of the roadmap. Combines
[`db_tables()`](https://thomuk.github.io/DBinventory/reference/db_tables.md),
[`db_columns()`](https://thomuk.github.io/DBinventory/reference/db_columns.md),
[`db_row_counts()`](https://thomuk.github.io/DBinventory/reference/db_row_counts.md),
[`db_freshness()`](https://thomuk.github.io/DBinventory/reference/db_freshness.md)
and
[`db_table_sizes()`](https://thomuk.github.io/DBinventory/reference/db_table_sizes.md)
into one call that needs only `SELECT` permission on the objects.

## Usage

``` r
db_inventory(
  con,
  schema = NULL,
  include = NULL,
  exclude = NULL,
  views = TRUE,
  row_counts = TRUE,
  freshness = TRUE,
  sizes = TRUE,
  dialect = NULL,
  progress = interactive()
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

- row_counts, freshness, sizes:

  Switch off the slower steps if needed.

- dialect:

  Optional dialect override, see
  [`db_dialect()`](https://thomuk.github.io/DBinventory/reference/db_dialect.md).

- progress:

  Show progress bars? Default `TRUE` in interactive use.

## Value

A list of class `db_inventory` with two tibbles: `tables` (one row per
table or view, with `n_columns`, `row_count`, `size_bytes`,
`newest_datetime`, `newest_datetime_column`, `inventoried_at`) and
`columns` (one row per column, see
[`db_columns()`](https://thomuk.github.io/DBinventory/reference/db_columns.md)).

## Examples

``` r
con <- fakehosp_connection()
inv <- db_inventory(con, include = "pas_", progress = FALSE)
#> ℹ 5 tables found (sqlite dialect)
#> ✔ Inventory of 5 tables and 65 columns in 0s
inv$tables[, c("table_name", "n_columns", "row_count", "newest_datetime")]
#> # A tibble: 5 × 4
#>   table_name                  n_columns row_count newest_datetime    
#>   <chr>                           <int>     <dbl> <chr>              
#> 1 pas_adt_events                     20      1000 2026-03-31 10:22:32
#> 2 pas_op_status_log                   8      1000 2026-03-30 17:58:28
#> 3 pas_outpatient_appointments        16      1000 2026-03-31 14:40:00
#> 4 pas_patients                       10      1000 2026-02-06         
#> 5 pas_referrals                      11      1000 2026-03-30         
DBI::dbDisconnect(con)
```
