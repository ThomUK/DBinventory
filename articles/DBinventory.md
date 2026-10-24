# Getting started with DBinventory

DBinventory answers two questions about a database you have `SELECT`
access to and no documentation for: *what is in it* (the inventory) and
*what does each column hold* (the column profile). This article walks
through both on the synthetic hospital database bundled with the
package.

``` r

library(DBinventory)
```

## Connect

[`db_connect()`](https://thomuk.github.io/DBinventory/reference/db_connect.md)
takes whatever you have: a DBI connection, an ODBC connection string or
DSN for SQL Server, a SQLite or DuckDB file, or a Parquet file or
directory. The bundled fixture is a SQLite file.

``` r

con <- db_connect(fakehosp_path())
db_dialect(con)
#> <db_dialect: sqlite>
```

On a hospital warehouse it would be:

``` r

con <- db_connect("Driver={ODBC Driver 18 for SQL Server};Server=warehouse;Database=DW;Trusted_Connection=yes;TrustServerCertificate=yes;")
```

## Inventory

[`db_inventory()`](https://thomuk.github.io/DBinventory/reference/db_inventory.md)
lists every table and view, every column with its type, and adds exact
row counts, sizes from system views where available, and the newest
value in any date or datetime column as a freshness signal. Regular
expressions on `schema.table` narrow the scope.

``` r

inv <- db_inventory(con, include = c("pas_", "v_emergency"), progress = FALSE)
#> ℹ 6 tables found (sqlite dialect)
#> ✔ Inventory of 6 tables and 70 columns in 0.2s
inv$tables[, c("table_name", "table_type", "n_columns", "row_count", "newest_datetime", "newest_datetime_column")]
#> # A tibble: 6 × 6
#>   table_name                  table_type n_columns row_count newest_datetime    
#>   <chr>                       <chr>          <int>     <dbl> <chr>              
#> 1 pas_adt_events              table             20      1000 2026-03-31 10:22:32
#> 2 pas_op_status_log           table              8      1000 2026-03-30 17:58:28
#> 3 pas_outpatient_appointments table             16      1000 2026-03-31 14:40:00
#> 4 pas_patients                table             10      1000 2026-02-06         
#> 5 pas_referrals               table             11      1000 2026-03-30         
#> 6 v_emergency_spells          view               5       446 2026-03-31 16:25:03
#> # ℹ 1 more variable: newest_datetime_column <chr>
```

Columns carry a `type_class` that normalises engine type names, which is
what decides which statistics the profiler can ask for.

``` r

inv$columns[inv$columns$table_name == "pas_patients", c("column_name", "data_type", "type_class")]
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
```

## Column profile

[`db_profile()`](https://thomuk.github.io/DBinventory/reference/db_profile.md)
runs one aggregate query per table (batched by column) plus one
frequency query per column that has few enough distinct values for a
frequency table to mean something. Tables above `sample_rows` are
profiled on a sample materialised in a temporary table.

``` r

prof <- db_profile(con, inv, progress = FALSE)
prof[prof$table_name == "pas_patients",
     c("column_name", "null_rate", "distinct_count", "is_unique", "pk_candidate", "semantic_type", "values_suppressed")]
#> # A tibble: 10 × 7
#>    column_name     null_rate distinct_count is_unique pk_candidate semantic_type
#>    <chr>               <dbl>          <dbl> <lgl>     <lgl>        <chr>        
#>  1 mrn                 0               1000 TRUE      TRUE         identifier   
#>  2 nhs_number          0.007            993 TRUE      FALSE        identifier   
#>  3 nhs_number_sta…     0                  2 FALSE     FALSE        code         
#>  4 sex                 0                  2 FALSE     FALSE        code         
#>  5 dob                 0                981 FALSE     FALSE        date         
#>  6 ethnicity           0                 17 FALSE     FALSE        code         
#>  7 gp_practice         0                 90 FALSE     FALSE        category     
#>  8 postcode            0                995 FALSE     FALSE        identifier   
#>  9 registered_dat…     0               1000 TRUE      FALSE        datetime     
#> 10 date_of_death       0.987             13 TRUE      FALSE        date         
#> # ℹ 1 more variable: values_suppressed <lgl>
```

Literal values are suppressed by default for identifiers, free text and
columns whose names suggest personal data, because the profile of a
hospital warehouse will end up in a repository. Codes and dates keep
theirs:

``` r

top_values_of(prof, "pas_patients", "ethnicity")
#>    value   n
#> 1      A 775
#> 2      Z  55
#> 3      C  37
#> 4      H  22
#> 5      J  14
#> 6      N  14
#> 7      D  13
#> 8      S  13
#> 9      B  12
#> 10     L   9
prof[prof$column_name == "dob", c("min_value", "max_value")]
#> # A tibble: 1 × 2
#>   min_value  max_value 
#>   <chr>      <chr>     
#> 1 1925-05-01 2024-07-16
```

The hashes are computed before suppression, so copies of a suppressed
column in other tables still match on fingerprint:

``` r

inv2 <- db_inventory(con, include = c("pas_outpatient_appointments", "derived_op_appointments"), progress = FALSE)
#> ℹ 2 tables found (sqlite dialect)
#> ✔ Inventory of 2 tables and 44 columns in 0s
prof2 <- db_profile(con, inv2, progress = FALSE)
duplicate_candidates(prof2)[, c("n_tables", "columns")]
#> # A tibble: 9 × 2
#>   n_tables columns                                                              
#>      <int> <chr>                                                                
#> 1        2 main.derived_op_appointments.mrn_as_recorded; main.derived_op_appoin…
#> 2        2 main.derived_op_appointments.referral_id; main.pas_outpatient_appoin…
#> 3        2 main.derived_op_appointments.clinic_code; main.pas_outpatient_appoin…
#> 4        2 main.derived_op_appointments.consultant_code; main.pas_outpatient_ap…
#> 5        2 main.derived_op_appointments.dnadate; main.pas_outpatient_appointmen…
#> 6        2 main.derived_op_appointments.apptdate; main.pas_outpatient_appointme…
#> 7        2 main.derived_op_appointments.attendkey; main.pas_outpatient_appointm…
#> 8        2 main.derived_op_appointments.cancelled_datetime; main.pas_outpatient…
#> 9        2 main.derived_op_appointments.booked_datetime; main.pas_outpatient_ap…
```

## Foreign key candidates

Every string, integer or uuid column is scored against the
`pk_candidate` columns of the other tables on name, value range and
cardinality. The best target above a confidence threshold becomes
`fk_target`. It is a shortlist for the key register’s match-rate tests,
not a confirmed relationship.

``` r

prof2[prof2$fk_candidate, c("table_name", "column_name", "fk_target", "fk_confidence", "fk_evidence")]
#> # A tibble: 0 × 5
#> # ℹ 5 variables: table_name <chr>, column_name <chr>, fk_target <chr>,
#> #   fk_confidence <dbl>, fk_evidence <chr>
```

## Store, resume and report

For a warehouse of hundreds of tables, use
[`inventory_run()`](https://thomuk.github.io/DBinventory/reference/inventory_run.md).
It writes the inventory and each table’s profile to a SQLite store as it
goes, so an interrupted run resumes where it stopped, and it can export
CSV or Parquet and render the HTML report at the end.

``` r

out <- inventory_run(
  "Driver={ODBC Driver 18 for SQL Server};Server=warehouse;Database=DW;Trusted_Connection=yes;",
  store = "dw_inventory.sqlite",
  export_dir = "dw_inventory_csv",
  report = "dw_inventory.html"
)
```

``` r

DBI::dbDisconnect(con)
```
