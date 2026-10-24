# DBinventory

An R package that builds the first two artefacts of a data-documentation
effort from a read-only database connection:

1.  **Inventory**: every table and column, with schema, name, type, row
    count, size, newest datetime and when it was profiled.
2.  **Column profile**: per column, the null rate, distinct count, min
    and max, top values, inferred semantic type (identifier, date, code,
    free text, flag, …), uniqueness and fingerprint hashes that let
    copies of the same data be found across tables.

It is general purpose and works over any DBI connection, with dialect
support for **Microsoft SQL Server** (the main target: hospital data
warehouses reached over ODBC with `SELECT` permission only), **Parquet**
files and directories (through DuckDB), DuckDB, SQLite and PostgreSQL.
Results go into a SQLite store with per-table checkpointing so a run
over hundreds of tables can be interrupted and resumed, and can be
exported to CSV or Parquet and rendered as an HTML report from a Quarto
template.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("ThomUK/DBinventory")

# optional, by source:
install.packages("odbc")    # SQL Server and other ODBC sources
install.packages("duckdb")  # Parquet files and DuckDB databases
install.packages("DT")      # interactive tables in the report

# the synthetic hospital dataset used in the articles and example reports
remotes::install_github("ThomUK/synthetic-hospital-data", subdir = "fakehospdata")
```

## Usage

One call does the whole run:

``` r

library(DBinventory)
con <- "Driver={ODBC Driver 18 for SQL Server};Server=warehouse;Database=DW;Trusted_Connection=yes;TrustServerCertificate=yes;"

# Sampled report: tables above a million rows are profiled on a sample of their
# rows. Best for a large warehouse, where reading every row of every table
# would take too long for a first look.
out <- inventory_run(con, organisation = "Example NHS Trust",
                     store = "dw_inventory.sqlite", report = "dw_inventory.html")

# Full report: every row of every table. Best when the database is small enough
# to read in full, or when exact distinct counts and uniqueness matter, as they
# do when choosing keys.
out <- inventory_run(con, organisation = "Example NHS Trust", sample_rows = Inf,
                     store = "dw_inventory_full.sqlite", report = "dw_inventory_full.html")

out$inventory$tables   # one row per table or view
out$profile            # one row per column
```

Other arguments: `export_dir` writes one CSV per store table
(`export_format = "parquet"` for Parquet), and `include`, `exclude` and
`schema` narrow the run to part of the database.

[`inventory_run()`](https://thomuk.github.io/DBinventory/reference/inventory_run.md)
accepts anything
[`db_connect()`](https://thomuk.github.io/DBinventory/reference/db_connect.md)
does: a DBI connection, an ODBC connection string or DSN name, a
`.sqlite` or `.duckdb` file, a `.parquet` file or a directory of them.

``` r

# a directory of Parquet files, one schema per subdirectory
out <- inventory_run("data/v2/sample", store = "sample_inventory.sqlite")

# the Fake NHS Trust synthetic dataset, for a first look (downloads the 130 MB sample once)
out <- inventory_run(fakehospdata::fh_connect("sample"), store = "fakehosp_inventory.sqlite",
                     organisation = "Fake NHS Trust")
```

Re-running with the same `store` resumes: tables already profiled are
skipped. Use `resume = FALSE` to start again.

### Step by step

``` r

con <- db_connect("Driver={ODBC Driver 18 for SQL Server};Server=...;Database=...;Trusted_Connection=yes;")

tables  <- db_tables(con, schema = "dbo", exclude = "\\.tmp_|_backup$")
inv     <- db_inventory(con, schema = "dbo")           # tables + columns + counts + freshness + sizes
prof    <- db_profile(con, inv, sample_rows = 1e6,     # sample tables above a million rows
                      store = "dw_inventory.sqlite")   # checkpoint per table
dups    <- duplicate_candidates(prof)                  # same data in more than one table?
render_report("dw_inventory.sqlite", "dw_inventory.html")

DBI::dbDisconnect(con)
```

### What the profile holds

| Column | Meaning |
|----|----|
| `row_count`, `rows_profiled`, `sampled`, `sample_method` | Full row count from the inventory; how many rows the statistics were computed on and how they were drawn |
| `null_count`, `null_rate`, `empty_count` | Nulls, and empty strings for text columns |
| `distinct_count`, `distinct_rate`, `is_unique` | Distinct values, distinct / non-null, and whether every non-null value is distinct |
| `pk_candidate` | Unique, never null and a string, integer or uuid type: worth testing as a primary key. On a sampled table this is evidence from the sample only |
| `fk_candidate`, `fk_target`, `fk_confidence`, `fk_evidence`, `fk_n_targets` | Best-scoring key column this column appears to reference, from name, range and cardinality evidence (see [`infer_foreign_keys()`](https://thomuk.github.io/DBinventory/reference/infer_foreign_keys.md)); a shortlist for the key register’s match-rate tests, not a confirmed relationship |
| `min_value`, `max_value`, `mean_value`, `true_count` | Range as text (ISO 8601 for dates), mean for numerics, count of `TRUE` for booleans |
| `min_length`, `max_length`, `mean_length` | String lengths |
| `top_values`, `top_values_hash` | The `top_n` most frequent values as JSON (read with [`top_values_of()`](https://thomuk.github.io/DBinventory/reference/top_values_of.md)), and a hash of them |
| `semantic_type` | `identifier`, `code`, `category`, `flag`, `date`, `datetime`, `time`, `free_text`, `count`, `measure`, `constant`, `empty`, `unknown` |
| `value_fingerprint`, `column_fingerprint` | Hash of what the column holds (type, distinct magnitude, min, max, top values), with and without the normalised column name |
| `values_suppressed` | Whether literal values were withheld (see below) |

### Key candidates

`pk_candidate` marks columns that are unique, never null and of a
key-like type. `fk_candidate` and `fk_target` propose, for each column,
the key column in another table it most looks like a reference to, from
name evidence, membership in a small key’s complete value set, range
containment, cardinality shape and value shape, with `fk_confidence`
from 0 to 1 and `fk_evidence` spelling out the components. Both are
**candidates only**: the profile cannot see whether a child’s values
actually exist in the key, so the shortlist is confirmed or rejected by
match-rate tests in the key register stage. The exclusions and the
scoring are documented in
[`?infer_foreign_keys`](https://thomuk.github.io/DBinventory/reference/infer_foreign_keys.md).

## Design decisions

These are the choices made where the brief left room; all are easy to
change.

**Values are suppressed by default.** The profile of a hospital
warehouse will be committed to a repository, so `min_value`, `max_value`
and `top_values` are withheld for columns inferred as free text or as
identifiers with more than 200 distinct values, and for columns whose
names suggest personal data (`nhs`, `mrn`, `postcode`, `dob`, `name`,
`address`, …). Hashes and fingerprints are computed before suppression,
so copies still match. Pass `keep_values = TRUE` where the output itself
is held securely.

**Large tables are sampled by default.** Exact `COUNT(*)` and
`MAX(datetime)` always run on the full table; value statistics for
tables above `sample_rows` (default a million) are computed on a sample
materialised in a session temporary table (`TABLESAMPLE SYSTEM` on SQL
Server, `USING SAMPLE ... (system)` on DuckDB, `ORDER BY random()` on
SQLite, `TABLESAMPLE SYSTEM (pct)` on PostgreSQL; views on SQL Server
fall back to the first rows). `sampled` and `sample_method` record what
happened. `sample_rows = Inf` gives the full report.

**One query per table for the aggregates, one per eligible column for
top values.** Aggregates are batched `column_batch` columns at a time.
Top values are skipped for columns with more than
`top_values_max_distinct` distinct values, where a frequency table says
little.

**Only `SELECT` is needed.** Metadata comes from `INFORMATION_SCHEMA`
(`sqlite_master` on SQLite). Table sizes come from
`sys.dm_db_partition_stats` on SQL Server and `pg_total_relation_size`
on PostgreSQL when the login can see them, and are `NA` otherwise.
Temporary tables need no extra rights.

**Statistics that a type cannot support are skipped, not failed.** No
`MIN()` on a SQL Server `bit`, no `COUNT(DISTINCT)` on `text`, `ntext`,
`xml` or geography; a `timestamp` on SQL Server is classified as binary
(it is a row version). A table that fails for any reason is logged in
`profile_log` and the run continues.

**The store is SQLite.** It is a single file, needs only `RSQLite`, and
is the checkpoint.
[`store_export()`](https://thomuk.github.io/DBinventory/reference/store_export.md)
writes CSV (always) or Parquet (with `arrow` or `duckdb`).

**The report is a Quarto document** at
`inst/report/inventory_report.qmd`, rendered with the Quarto CLI when
present and otherwise through
[`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html),
which handles the same knitr chunks.

## SQL Server notes

- Connection strings pass straight to
  `odbc::dbConnect(odbc::odbc(), .connection_string = ...)`; a bare name
  is treated as a DSN. Passwords are redacted before the source is
  written to `run_meta`.
- `COUNT_BIG(*)` is used for row counts. Datetimes are converted with
  `CONVERT(..., 126)` so min, max and freshness are ISO 8601 text.
- `TABLESAMPLE` is page based, so a sample is approximately
  `sample_rows` rows; the actual number is in `rows_profiled`.
- Column names are quoted with square brackets; the odbc driver class
  (`Microsoft SQL Server`) selects the dialect. Force it with
  `dialect = "mssql"` if a driver reports something else.
- The package has not yet been run against a live SQL Server from this
  repository; the T-SQL is covered by unit tests on the generated SQL.
  The first run against a real warehouse is the next step (see below).

## Parquet notes

`parquet_connect(dir)` exposes a directory as a DuckDB database of
views. Each subdirectory is a schema (nested paths joined with `_`),
each file a table. A directory holding two or more Parquet files that
share one column schema is read as a single partitioned table
(`layer1/pas_adt_events/fy2022.parquet`, `fy2023.parquet` become
`layer1.pas_adt_events`). Column types come from the Parquet metadata.

## Development

The package is developed against
[ThomUK/synthetic-hospital-data](https://github.com/ThomUK/synthetic-hospital-data),
read through its `fakehospdata` package. The tests run offline on
`tests/testthat/fixtures/fakehosp_tiny.sqlite`, 45 tables and a view
capped at 200 rows with declared types preserved, built from the sample
by the script beside it. The articles and the example reports on the
site use the real sample and full sets; the example reports are
regenerated by the `example-reports` workflow on the Actions tab.

``` sh
python3 tests/testthat/fixtures/build_fixture.py path/to/synthetic-hospital-data/data/v2/sample tests/testthat/fixtures/fakehosp_tiny.sqlite 200
Rscript -e 'devtools::test()'
Rscript -e 'rcmdcheck::rcmdcheck()'
```

## Roadmap

- First run against a live SQL Server warehouse; fix whatever the T-SQL
  gets wrong.
- Artefact 3, the duplicate and lineage map: cluster tables by shared
  fingerprints and propose a canonical member.
  [`duplicate_candidates()`](https://thomuk.github.io/DBinventory/reference/duplicate_candidates.md)
  is the seed.
- Value sketches (MinHash or HyperLogLog) for overlap tests between
  candidate key columns, feeding the key register.
- Incremental re-profiling: only tables whose row count or newest
  datetime changed since the last run.
