# Write and read the cluster review file

The review file is a CSV the warehouse owners edit: one row per table
with the proposed cluster, role and canonical member, a `status` column
(`proposed`, `confirmed` or `rejected`) and a `note`. Writing merges
with an existing file so that decisions already made are kept and only
new tables are added as `proposed`. Reading returns the decisions for
[`cluster_tables()`](https://thomuk.github.io/DBinventory/reference/cluster_tables.md),
where a `confirmed` row fixes that table's canonical member and a
`rejected` row takes the table out of its cluster.

## Usage

``` r
write_cluster_decisions(clusters, path)

read_cluster_decisions(path)
```

## Arguments

- clusters:

  The `clusters` tibble from
  [`cluster_tables()`](https://thomuk.github.io/DBinventory/reference/cluster_tables.md).

- path:

  Path of the CSV file.

## Value

`write_cluster_decisions()` returns the merged data frame invisibly;
`read_cluster_decisions()` returns a data frame, or `NULL` if the file
does not exist.
