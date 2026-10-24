# Package index

## Run everything

One call from a connection string, file or Parquet directory to a store,
exports and report.

- [`inventory_run()`](https://thomuk.github.io/DBinventory/reference/inventory_run.md)
  : Inventory and profile a database in one call
- [`db_connect()`](https://thomuk.github.io/DBinventory/reference/db_connect.md)
  : Connect to a database, Parquet store or SQLite file from one
  argument
- [`parquet_connect()`](https://thomuk.github.io/DBinventory/reference/parquet_connect.md)
  : Expose Parquet files as a database of views

## Inventory

Artefact 1. Every table and column with counts, sizes and freshness.

- [`db_inventory()`](https://thomuk.github.io/DBinventory/reference/db_inventory.md)
  : Build the inventory: every table and column with counts and
  freshness
- [`db_tables()`](https://thomuk.github.io/DBinventory/reference/db_tables.md)
  : List the tables and views visible on a connection
- [`db_columns()`](https://thomuk.github.io/DBinventory/reference/db_columns.md)
  : List the columns of a set of tables
- [`db_row_counts()`](https://thomuk.github.io/DBinventory/reference/db_row_counts.md)
  : Count the rows of each table
- [`db_freshness()`](https://thomuk.github.io/DBinventory/reference/db_freshness.md)
  : Find the newest datetime in each table
- [`db_table_sizes()`](https://thomuk.github.io/DBinventory/reference/db_table_sizes.md)
  : Read table sizes from the engine's system views

## Column profile

Artefact 2. Per-column statistics, semantic types and fingerprints.

- [`db_profile()`](https://thomuk.github.io/DBinventory/reference/db_profile.md)
  : Profile every column of a set of tables
- [`top_values_of()`](https://thomuk.github.io/DBinventory/reference/top_values_of.md)
  : Read the top values of a profile row back into a data frame
- [`infer_semantic_type()`](https://thomuk.github.io/DBinventory/reference/infer_semantic_type.md)
  : Infer a semantic type for each profiled column
- [`infer_foreign_keys()`](https://thomuk.github.io/DBinventory/reference/infer_foreign_keys.md)
  : Propose foreign key relationships from the column profile
- [`fingerprints()`](https://thomuk.github.io/DBinventory/reference/fingerprints.md)
  : Fingerprint profiled columns
- [`duplicate_candidates()`](https://thomuk.github.io/DBinventory/reference/duplicate_candidates.md)
  : Find columns that share a fingerprint across tables

## Store, export and report

- [`store_open()`](https://thomuk.github.io/DBinventory/reference/store_open.md)
  [`store_close()`](https://thomuk.github.io/DBinventory/reference/store_open.md)
  [`store_tables()`](https://thomuk.github.io/DBinventory/reference/store_open.md)
  : Open (or create) a results store
- [`store_write()`](https://thomuk.github.io/DBinventory/reference/store_write.md)
  : Write a data frame into the store
- [`store_read()`](https://thomuk.github.io/DBinventory/reference/store_read.md)
  : Read a table from the store
- [`store_write_inventory()`](https://thomuk.github.io/DBinventory/reference/store_write_inventory.md)
  : Save an inventory into the store
- [`store_read_inventory()`](https://thomuk.github.io/DBinventory/reference/store_read_inventory.md)
  : Read the inventory back from the store
- [`store_export()`](https://thomuk.github.io/DBinventory/reference/store_export.md)
  : Export the store's tables to CSV or Parquet files
- [`render_report()`](https://thomuk.github.io/DBinventory/reference/render_report.md)
  : Render the inventory report

## Dialects and types

- [`db_dialect()`](https://thomuk.github.io/DBinventory/reference/db_dialect.md)
  : Identify or construct a SQL dialect
- [`type_class()`](https://thomuk.github.io/DBinventory/reference/type_class.md)
  : Classify a database type name

## Synthetic test data

- [`fakehosp_path()`](https://thomuk.github.io/DBinventory/reference/fakehosp_path.md)
  [`fakehosp_connection()`](https://thomuk.github.io/DBinventory/reference/fakehosp_path.md)
  : The bundled synthetic hospital database
