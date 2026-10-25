# Cluster tables that hold the same data and propose a canonical member

Artefact 3 of the roadmap, from profile statistics alone. Columns are
matched across tables by what they hold (complete value sets for small
code lists, value ranges, distinct rate, value shape, string lengths,
and name as a secondary signal), table pairs are scored by how much of
each table's information is found in the other, each related pair is
labelled (copy, filtered subset, aggregate, wider derivative, related),
related tables are grouped into clusters, and a canonical member is
proposed for each cluster with a one-line rationale. Every table also
gets a class (`event`, `reference`, `aggregate` or `other`) from its own
shape.

## Usage

``` r
cluster_tables(
  profile,
  inventory,
  min_column_score = 0.7,
  min_containment = 0.75,
  schema_priority = NULL,
  decisions = NULL
)
```

## Arguments

- profile:

  A `column_profile` covering every table, from a full (unsampled) run.

- inventory:

  The matching `db_inventory`, for row counts, column counts and
  freshness.

- min_column_score:

  Lowest column similarity that counts as a match.

- min_containment:

  Lowest containment that makes two tables related.

- schema_priority:

  Optional character vector of schemas in order of preference for the
  canonical member, for example `c("layer1", "derived")` to prefer
  source tables over cleaned copies. Tables in schemas not listed rank
  after those listed.

- decisions:

  Optional data frame of reviewed decisions, as read by
  [`read_cluster_decisions()`](https://thomuk.github.io/DBinventory/reference/write_cluster_decisions.md);
  confirmed and rejected rows override the proposals.

## Value

A list with three tibbles: `clusters` (one row per table: `cluster_id`,
`table`, `table_class`, `role`, `canonical`, `confidence`, `rationale`,
`status`), `pairs` (the evidence for every related pair) and `matches`
(the column matches behind the pairs).

## Details

The proposals are a starting point for the warehouse owners to confirm,
not a verdict: see
[`write_cluster_decisions()`](https://thomuk.github.io/DBinventory/reference/write_cluster_decisions.md)
for the review file. Clustering needs exact statistics, so it refuses a
profile in which any table was sampled.

## Scoring

Two columns of the same type class score between 0 and 1 on the evidence
available for both: Jaccard overlap of complete value sets (weight 0.5),
overlap of ranges or, for suppressed identifiers, of string lengths
(0.3), closeness of distinct rate (0.2), overlap of value shapes (0.15)
and name similarity (0.15); missing components are left out and the
weights rescaled. A match needs a score of at least `min_column_score`.
Columns are weighted by information content (log10 of distinct count),
so a shared two-value flag counts for little and a shared identifier for
a lot. For a pair of tables, a greedy best-match assignment gives
`contain_a_in_b` (the share of A's information found in B), the reverse,
and `similarity` (their harmonic mean). Pairs with containment of at
least `min_containment` in either direction are related. Copy, subset,
wider and narrower also need a shared entity: a matched column that is
near-unique and mostly populated in both tables, so a table that merely
references this one through a foreign key is not mistaken for a copy.
When that shared column has identical values in both tables (equal
fingerprints) the rows are known to be the same rows, and the
containment threshold drops to 0.5 to allow for renamed or recomputed
columns. Two reference tables additionally need a word in common in
their names.

## Labels

With A the table being described and B the other:

- `copy`: containment at least `min_containment` both ways and row
  counts within 10 per cent; or an identical identifier column (equal
  fingerprints) with row counts within 10 per cent, which makes the pair
  a copy, wider derivative or narrower by column count alone;

- `filtered_subset`: A's information is in B, B's is not all in A, and A
  has fewer rows;

- `wider_derivative`: B's information is in A, A has more columns, rows
  within 10 per cent;

- `narrower`: A's information is in B, which has more columns, rows
  within 10 per cent (the other side of a wider derivative);

- `aggregate`: A is of class `aggregate` and its grouping columns are
  found in B, which has more rows;

- `related`: anything else above the thresholds.

## Canonical member

Within a cluster, unless `schema_priority` decides it, the canonical
member is the one with the highest score from: a primary key candidate
(+2), lowest grain (log10 rows), width (log10 informative columns),
freshness (rank of newest datetime, up to +1), and penalties for being a
filtered subset (-3) or aggregate (-5) of another member.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- fakehospdata::fh_connect("sample")
inv <- db_inventory(con, exclude = "^answers\\\\.", progress = FALSE)
prof <- db_profile(con, inv, sample_rows = Inf, progress = FALSE)
cl <- cluster_tables(prof, inv)
cl$clusters[cl$clusters$role != "standalone", ]
} # }
```
