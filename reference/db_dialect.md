# Identify or construct a SQL dialect

`DBinventory` issues plain SQL through DBI. The small set of things that
differ between engines (identifier quoting, metadata views, sampling,
`TOP` versus `LIMIT`, text conversion, system size views) live in a
dialect object. The dialect is normally inferred from the connection
class, but can be forced with `dialect`, which is useful for an
unfamiliar ODBC driver.

## Usage

``` r
db_dialect(con = NULL, dialect = NULL)
```

## Arguments

- con:

  A `DBIConnection`, or `NULL` when `dialect` is given.

- dialect:

  Optional dialect name to force: one of `"mssql"`, `"duckdb"`,
  `"sqlite"`, `"postgres"` or `"generic"`.

## Value

An object of class `db_dialect`.

## Examples

``` r
db_dialect(dialect = "mssql")
#> <db_dialect: mssql>
```
