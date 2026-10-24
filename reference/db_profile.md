# Profile every column of a set of tables

Artefact 2 of the roadmap. For each column: null rate, distinct count,
min and max, mean (numeric), string lengths, top values, uniqueness, an
inferred semantic type and two fingerprint hashes. Large tables are
profiled on a sample. Results can be checkpointed per table into a store
so that an interrupted run resumes where it stopped.

## Usage

``` r
db_profile(
  con,
  inventory = NULL,
  tables = NULL,
  sample_rows = 1e+06,
  top_n = 10,
  top_values_max_distinct = 10000,
  keep_values = FALSE,
  store = NULL,
  resume = TRUE,
  column_batch = 40,
  dialect = NULL,
  progress = interactive()
)
```

## Arguments

- con:

  A `DBIConnection`.

- inventory:

  A `db_inventory` from
  [`db_inventory()`](https://thomuk.github.io/DBinventory/reference/db_inventory.md).
  If `NULL` one is built first (row counts are needed to decide on
  sampling).

- tables:

  Optional subset of `inventory$tables` to profile.

- sample_rows:

  Tables with more rows than this are profiled on a sample of roughly
  this many rows. `Inf` disables sampling.

- top_n:

  How many most-frequent values to record per column.

- top_values_max_distinct:

  Only compute top values for columns with at most this many distinct
  values; beyond that a frequency table says little.

- keep_values:

  If `FALSE` (the default) the literal min, max and top values of
  columns inferred as identifiers or free text, or whose names suggest
  personal data, are suppressed and only their hashes kept. Set `TRUE`
  on a system where the profile output is itself safe to hold.

- store:

  Optional path to a SQLite store (see
  [`store_open()`](https://thomuk.github.io/DBinventory/reference/store_open.md)).
  Each table's profile is written as soon as it finishes.

- resume:

  If `TRUE` and `store` is given, tables already profiled successfully
  in the store are skipped.

- column_batch:

  Number of columns aggregated in one query. Lower it if the engine
  rejects very wide statements.

- dialect:

  Optional dialect override, see
  [`db_dialect()`](https://thomuk.github.io/DBinventory/reference/db_dialect.md).

- progress:

  Show a progress bar? Default `TRUE` in interactive use.

## Value

A tibble of class `column_profile`, one row per column. Columns include
`null_rate`, `distinct_count`, `distinct_rate`, `is_unique`,
`pk_candidate` (unique, never null and a string, integer or uuid type;
on a sampled table this is evidence from the sample only), `min_value`,
`max_value`, `mean_value`, `min_length`, `max_length`, `mean_length`,
`true_count`, `top_values` (JSON), `top_values_hash`, `semantic_type`,
`values_suppressed`, `value_fingerprint`, `column_fingerprint`,
`rows_profiled`, `sampled`, `sample_method`, `profiled_at`.

## Examples

``` r
con <- fakehosp_connection()
inv <- db_inventory(con, include = "pas_patients", progress = FALSE)
#> ℹ 1 table found (sqlite dialect)
#> ✔ Inventory of 1 table and 10 columns in 0s
prof <- db_profile(con, inv, progress = FALSE)
prof[, c("column_name", "null_rate", "distinct_count", "semantic_type")]
#> # A tibble: 10 × 4
#>    column_name         null_rate distinct_count semantic_type
#>    <chr>                   <dbl>          <dbl> <chr>        
#>  1 mrn                     0               1000 identifier   
#>  2 nhs_number              0.007            993 identifier   
#>  3 nhs_number_status       0                  2 code         
#>  4 sex                     0                  2 code         
#>  5 dob                     0                981 date         
#>  6 ethnicity               0                 17 code         
#>  7 gp_practice             0                 90 category     
#>  8 postcode                0                995 identifier   
#>  9 registered_datetime     0               1000 datetime     
#> 10 date_of_death           0.987             13 date         
DBI::dbDisconnect(con)
```
