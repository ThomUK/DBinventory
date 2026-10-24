# Connect to a database, Parquet store or SQLite file from one argument

Turns the thing you have into a `DBIConnection`:

## Usage

``` r
db_connect(x, ...)
```

## Arguments

- x:

  A connection, path(s) or connection string.

- ...:

  Passed to the underlying
  [`DBI::dbConnect()`](https://dbi.r-dbi.org/reference/dbConnect.html).

## Value

A `DBIConnection`. The caller disconnects it.

## Details

- a `DBIConnection` is returned as is;

- a path ending in `.sqlite`, `.sqlite3` or `.db` opens with `RSQLite`;

- a path ending in `.duckdb` or `.ddb` opens read-only with `duckdb`;

- a `.parquet` file, a vector of them, or a directory containing Parquet
  files becomes an in-memory DuckDB database of views, see
  [`parquet_connect()`](https://thomuk.github.io/DBinventory/reference/parquet_connect.md);

- a string containing `=` and `;` is treated as an ODBC connection
  string
  (`"Driver={ODBC Driver 18 for SQL Server};Server=...;Database=...;Trusted_Connection=yes;"`);

- anything else is treated as an ODBC DSN name.

## Examples

``` r
con <- db_connect(fakehosp_path())
db_tables(con)[1:3, ]
#> # A tibble: 3 × 4
#>   table_catalog table_schema table_name       table_type
#>   <chr>         <chr>        <chr>            <chr>     
#> 1 NA            main         admission_method table     
#> 2 NA            main         admission_source table     
#> 3 NA            main         agg_ae_monthly   table     
DBI::dbDisconnect(con)
```
