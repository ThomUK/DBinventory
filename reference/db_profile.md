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
  full_set_max = 50,
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
  this many rows. `Inf` disables sampling, which is the faster choice on
  DuckDB and Parquet, where aggregates over the full table cost less
  than materialising a sample; the threshold is for engines such as SQL
  Server where a full scan is the expensive part.

- top_n:

  How many most-frequent values to record per column.

- full_set_max:

  Columns with at most this many distinct values have every value
  recorded, not just the top `top_n`, so that a code list's frequency
  table is complete and foreign key membership can be tested against it.

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
on a sampled table this is evidence from the sample only),
`fk_candidate`, `fk_target`, `fk_confidence` and `fk_evidence` (see
[`infer_foreign_keys()`](https://thomuk.github.io/DBinventory/reference/infer_foreign_keys.md);
inferred across the tables profiled in this call, or across the whole
store by
[`inventory_run()`](https://thomuk.github.io/DBinventory/reference/inventory_run.md)),
`min_value`, `max_value`, `mean_value`, `min_length`, `max_length`,
`mean_length`, `true_count`, `top_values` (JSON), `top_values_hash`,
`semantic_type`, `values_suppressed`, `value_fingerprint`,
`column_fingerprint`, `rows_profiled`, `sampled`, `sample_method`,
`profiled_at`.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- fakehospdata::fh_connect("sample")
inv <- db_inventory(con, include = "pas_patients", progress = FALSE)
prof <- db_profile(con, inv, progress = FALSE)
prof[, c("column_name", "null_rate", "distinct_count", "semantic_type")]
DBI::dbDisconnect(con, shutdown = TRUE)
} # }
```
