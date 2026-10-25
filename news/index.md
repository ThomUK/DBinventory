# Changelog

## DBinventory 0.1.6

- Report: a diagram of primary and foreign key candidates heads the
  phase 3 tab, and the sampled-run note shows what a sampled check
  reviewed against a full one.

## DBinventory 0.1.5

- The report’s sampled-run notes guide the reader: phase 1 is complete
  and usable, and a full (not sampled) check shows phase 2 onwards.

## DBinventory 0.1.4

- The report’s phase 2 tab opens with diagrams of how tables are
  matched, what counts as the same data, and what the labels mean.

## DBinventory 0.1.3

- Phase 2, table clustering:
  [`cluster_tables()`](https://thomuk.github.io/DBinventory/reference/cluster_tables.md)
  matches columns across tables by what they hold, scores table pairs by
  containment, labels each related pair (copy, filtered subset, wider
  derivative, narrower, aggregate), groups related tables into clusters
  and proposes a canonical member with a rationale; every table also
  gets a class (event, reference, aggregate).
  [`write_cluster_decisions()`](https://thomuk.github.io/DBinventory/reference/write_cluster_decisions.md)
  and
  [`read_cluster_decisions()`](https://thomuk.github.io/DBinventory/reference/write_cluster_decisions.md)
  keep the owners’ review in a CSV that overrides the proposals on later
  runs.
  [`inventory_run()`](https://thomuk.github.io/DBinventory/reference/inventory_run.md)
  gains `schema_priority` and `decisions`.
- Phases 2 and 3 are gated on a full run: on a sampled run, clustering
  and foreign key inference are skipped and the report says so.
- The report is tabbed by phase: inventory and profile, table clusters,
  keys.

## DBinventory 0.1.2

- Report tables offer dropdown filters for columns with few distinct
  values (schema, type class, semantic type, flags), a rows-per-page
  menu and highlighted search matches, all through DT.

## DBinventory 0.1.1

- DuckDB samples large tables (100,000 rows or more) with vector-level
  percentage sampling instead of a reservoir sample, which scanned and
  rewrote the table before profiling it. Smaller tables keep the exact
  reservoir sample.
- The example reports are called “sampled” and “full”;
  `sample_rows = Inf` gives the full report.

## DBinventory 0.1.0

First working version.

- Inventory:
  [`db_inventory()`](https://thomuk.github.io/DBinventory/reference/db_inventory.md)
  lists every table and column with exact row counts, sizes from system
  views where readable, and the newest datetime per table as a freshness
  signal.
- Column profile:
  [`db_profile()`](https://thomuk.github.io/DBinventory/reference/db_profile.md)
  records null rate, distinct count, uniqueness, min, max, mean, string
  lengths and top values per column, with an inferred semantic type,
  `pk_candidate`, and two fingerprint hashes. Literal values are
  suppressed for free text, large identifier columns and personal-data
  column names unless `keep_values = TRUE`.
- Foreign keys:
  [`infer_foreign_keys()`](https://thomuk.github.io/DBinventory/reference/infer_foreign_keys.md)
  proposes, for each column, the key column it most looks like a
  reference to, with a confidence score and the evidence behind it.
  Candidates only, for the key register to confirm.
- Dialects for Microsoft SQL Server (the main target), DuckDB, SQLite
  and PostgreSQL;
  [`db_connect()`](https://thomuk.github.io/DBinventory/reference/db_connect.md)
  takes a connection string, DSN, SQLite or DuckDB file, or Parquet
  files and directories;
  [`parquet_connect()`](https://thomuk.github.io/DBinventory/reference/parquet_connect.md)
  exposes a Parquet directory as a DuckDB database.
- SQLite results store with per-table checkpointing and resume, CSV and
  Parquet export, and
  [`inventory_run()`](https://thomuk.github.io/DBinventory/reference/inventory_run.md)
  to do everything in one call.
- Quarto report
  ([`render_report()`](https://thomuk.github.io/DBinventory/reference/render_report.md))
  with ggplot2 plots, candidate duplicate columns, foreign key
  candidates and a searchable column profile; the title takes an
  organisation prefix.
- Developed against the Fake NHS Trust synthetic dataset through the
  `fakehospdata` package; tests run offline on a small fixture.
