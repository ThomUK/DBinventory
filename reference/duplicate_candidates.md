# Find columns that share a fingerprint across tables

A first look at artefact 3 (the duplicate map): groups of columns in
different tables with the same `value_fingerprint` (or the stricter
`column_fingerprint`). Constant and empty columns are excluded because
they match trivially.

## Usage

``` r
duplicate_candidates(
  profile,
  by = c("value_fingerprint", "column_fingerprint"),
  min_distinct = 20
)
```

## Arguments

- profile:

  A `column_profile` from
  [`db_profile()`](https://thomuk.github.io/DBinventory/reference/db_profile.md).

- by:

  Which fingerprint to group on.

- min_distinct:

  Ignore columns with fewer distinct values than this; small code lists
  match across tables legitimately.

## Value

A tibble of candidate groups: `fingerprint`, `n_columns`, `n_tables`,
`columns` (a `schema.table.column` list in one string).
