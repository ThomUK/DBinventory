# Propose foreign key relationships from the column profile

Tier-one inference, from profile statistics alone and without extra
queries. Every column of a string, integer or uuid type is scored
against every `pk_candidate` column in another table (or another column
of the same table), and the best-scoring target at or above
`min_confidence` is recorded. These are candidates only: a shortlist for
the key register's match-rate tests, which are the only thing that can
confirm a relationship.

## Usage

``` r
infer_foreign_keys(profile, min_confidence = 0.6)
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
`fk_evidence` (the scoring components as text) and `fk_n_targets` added
or replaced.

## Exclusions

A pair is ruled out, whatever else it scores, when:

- the type classes differ, or the child's string lengths fall outside
  the key's;

- the child is itself unique and shares the key's `value_fingerprint`:
  that is a copy of the key, which belongs in the duplicate map;

- the key's complete value set is known (its distinct count is within
  the values recorded for it) and a top value of the child is not in it;

- the key's table was profiled in full and the child has more distinct
  values than the key;

- the shapes of the two columns' top values (runs of digits, letters and
  other characters) do not overlap, so `100` cannot reference `Ward 3`;

- the child is a flag, or is empty;

- the key is in the child's own table and the names do not say it is a
  self-reference (exact or suffix match);

- the child is itself a `pk_candidate` and there is no name evidence: a
  key that merely resembles another key is a coincidence or a copy.

## Scoring

Surviving pairs start at 0.1 and add:

- name evidence: 0.45 for the same normalised name, 0.3 when the child
  name ends with the key name (`prior_mrn` to `mrn`), 0.2 when it
  contains the key's table stem (`main_site` to `sites.site_code`).
  Generic column names such as `id`, `code`, `name` or `description`
  earn nothing on their own; their keys are reached through the table
  stem;

- values: when the key's complete value set is known and every top value
  of the child is in it, 0.4 times the share of the key's values the
  child uses, so a child that uses all of a code list scores more than
  one that uses two of its seven codes;

- range: when the value set is not known but both ranges are, 0.25 if
  the child's min and max lie inside the key's and -0.25 if they do not;

- cardinality, when the key's table was profiled in full: 0.15 for a
  many-to-one shape, 0.05 for one-to-one unless the child is itself a
  `pk_candidate`;

- 0.1 when both columns have the same minimum and maximum string length,
  unless the child is itself a `pk_candidate`.

Scores are capped at 1. Ties go to the key with the fewest distinct
values when membership is known (the tightest fit) and the most when it
is not (a table rather than a view of it), then by name. `fk_n_targets`
counts how many keys reached the threshold, since a conformed code such
as a site code legitimately matches several.

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
#> 1 pas_adt_events mrn         main.pas_patients.mrn           0.8
DBI::dbDisconnect(con)
```
