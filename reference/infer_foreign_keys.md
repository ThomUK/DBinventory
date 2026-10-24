# Propose foreign key relationships from the column profile

Tier-one inference, from profile statistics alone and without extra
queries. Every column of a string, integer or uuid type is scored
against every `pk_candidate` column in another table (or another column
of the same table), and the best-scoring target above `min_confidence`
is recorded. Confirming a candidate with a value match-rate query is the
key register's job, later; this is the shortlist for it.

## Usage

``` r
infer_foreign_keys(profile, min_confidence = 0.5)
```

## Arguments

- profile:

  A `column_profile` from
  [`db_profile()`](https://thomuk.github.io/DBinventory/reference/db_profile.md),
  ideally covering every table of interest: a key in a table that is not
  in `profile` cannot be proposed.

- min_confidence:

  Lowest score that counts as a candidate.

## Value

`profile` with `fk_candidate` (logical), `fk_target`
(`schema.table.column` of the best key, or `NA`), `fk_confidence`,
`fk_evidence` (the scoring components as text) and `fk_n_targets` (how
many keys scored at or above `min_confidence`; a conformed code such as
a site code legitimately matches several) added or replaced.

## Details

A pair is ruled out when the types differ, the child's string lengths
fall outside the key's, or the two columns share a `value_fingerprint`
(a copy, not a reference). Surviving pairs score:

- name evidence: 0.5 for the same normalised name, 0.35 when the child
  name ends with the key name (`prior_mrn` to `mrn`), 0.2 when it
  contains the key's table stem (`ward_name` to `wards.ward_id`);

- range: 0.25 when both ranges are known and the child's min and max lie
  inside the key's, -0.25 when they do not; nothing when either side's
  values are suppressed or the key table was sampled;

- cardinality: 0.15 for a many-to-one shape (the child has no more
  distinct values than the key and is not itself unique), 0.05 for
  one-to-one; skipped when either table was sampled;

- 0.1 for passing the type and length checks at all.

Scores are capped at 1. Ties go to the key with more distinct values.

## Examples

``` r
con <- fakehosp_connection()
inv <- db_inventory(con, include = c("pas_patients$", "pas_adt_events$"), progress = FALSE)
#> ℹ 2 tables found (sqlite dialect)
#> ✔ Inventory of 2 tables and 30 columns in 0s
prof <- db_profile(con, inv, progress = FALSE)
prof[prof$fk_candidate, c("table_name", "column_name", "fk_target", "fk_confidence")]
#> # A tibble: 1 × 4
#>   table_name     column_name fk_target             fk_confidence
#>   <chr>          <chr>       <chr>                         <dbl>
#> 1 pas_adt_events mrn         main.pas_patients.mrn          0.75
DBI::dbDisconnect(con)
```
