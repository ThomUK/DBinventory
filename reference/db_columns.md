# List the columns of a set of tables

List the columns of a set of tables

## Usage

``` r
db_columns(con, tables = NULL, dialect = NULL)
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

A tibble with one row per column: `table_schema`, `table_name`,
`column_name`, `ordinal_position`, `data_type`, `type_class`,
`character_maximum_length`, `numeric_precision`, `numeric_scale`,
`is_nullable`.

## Examples

``` r
con <- fakehosp_connection()
cols <- db_columns(con, db_tables(con, include = "pas_patients"))
cols[, c("column_name", "data_type", "type_class")]
#> # A tibble: 10 × 3
#>    column_name         data_type type_class
#>    <chr>               <chr>     <chr>     
#>  1 mrn                 TEXT      string    
#>  2 nhs_number          TEXT      string    
#>  3 nhs_number_status   TEXT      string    
#>  4 sex                 TEXT      string    
#>  5 dob                 DATE      date      
#>  6 ethnicity           TEXT      string    
#>  7 gp_practice         TEXT      string    
#>  8 postcode            TEXT      string    
#>  9 registered_datetime TIMESTAMP datetime  
#> 10 date_of_death       DATE      date      
DBI::dbDisconnect(con)
```
