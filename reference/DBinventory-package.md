# DBinventory: Inventory and Column Profile of a Database or Parquet Store

Builds the first two artefacts of a data-documentation effort from a
read-only connection: an inventory of every table and column (schema,
name, type, row count, size, newest datetime, when profiled) and a
per-column profile (null rate, distinct count, min and max, top values,
inferred semantic type, uniqueness, fingerprint hashes). Works against
any 'DBI' connection with dialect support for Microsoft SQL Server,
DuckDB (including Parquet files and directories), SQLite and PostgreSQL.
Results are written to a SQLite store with per-table checkpointing so
long runs can resume, and can be exported to CSV or Parquet and rendered
as a Quarto report.

## See also

Useful links:

- <https://github.com/ThomUK/DBinventory>

- Report bugs at <https://github.com/ThomUK/DBinventory/issues>

## Author

**Maintainer**: Tom Smith <tomsmith_uk@hotmail.com>
