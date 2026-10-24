# Read table sizes from the engine's system views

SQL Server (`sys.dm_db_partition_stats`) and PostgreSQL
(`pg_total_relation_size`) are supported. Other engines, or a SQL Server
login without `VIEW DATABASE STATE`, give `NA` with a message.

## Usage

``` r
db_table_sizes(con, tables = NULL, dialect = NULL)
```

## Arguments

- con:

  A `DBIConnection`.

- tables:

  A table list as returned by
  [`db_tables()`](https://thomuk.github.io/DBinventory/reference/db_tables.md).
  Defaults to every table visible on the connection.

- dialect:

  Optional dialect override, see
  [`db_dialect()`](https://thomuk.github.io/DBinventory/reference/db_dialect.md).

## Value

`tables` with `size_bytes` and `row_count_stats` (the engine's own row
estimate) added.
