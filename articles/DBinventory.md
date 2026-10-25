# Getting started with DBinventory

DBinventory answers two questions about a database you have `SELECT`
access to and no documentation for: *what is in it* (the inventory) and
*what does each column hold* (the column profile). This article walks
through both on the 5% sample of the [Fake NHS Trust synthetic
dataset](https://github.com/ThomUK/synthetic-hospital-data), read
through its `fakehospdata` package: about 3.6 million rows in the
`layer1`, `reference`, `derived` and `aggregate` schemas. Its `answers`
schema (the mess log and the truth tables the derived layer is marked
against) is the dataset’s answer key rather than part of the trust’s
warehouse, so the examples exclude it.

``` r

library(DBinventory)
```

## Connect

[`db_connect()`](https://thomuk.github.io/DBinventory/reference/db_connect.md)
takes whatever you have: a DBI connection, an ODBC connection string or
DSN for SQL Server, a SQLite or DuckDB file, or a Parquet file or
directory.
[`fakehospdata::fh_connect()`](https://rdrr.io/pkg/fakehospdata/man/fh_connect.html)
downloads the sample once into a cache and returns a DuckDB connection
of views, which
[`db_connect()`](https://thomuk.github.io/DBinventory/reference/db_connect.md)
passes through.

``` r

con <- db_connect(fakehospdata::fh_connect("sample", quiet = TRUE))
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmprDPQSJ/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
db_dialect(con)
#> <db_dialect: duckdb>
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

inv <- db_inventory(con, schema = c("layer1", "reference"), progress = FALSE)
#> ℹ 23 tables found (duckdb dialect)
#> ✔ Inventory of 23 tables and 207 columns in 0.2s
inv$tables[, c("table_schema", "table_name", "n_columns", "row_count", "newest_datetime", "newest_datetime_column")]
#> # A tibble: 23 × 6
#>    table_schema table_name                  n_columns row_count newest_datetime 
#>    <chr>        <chr>                           <int>     <dbl> <chr>           
#>  1 layer1       ed_attendances                     22     40459 2026-04-01 08:1…
#>  2 layer1       ed_status_log                       5    172721 2026-04-01 08:1…
#>  3 layer1       endo_procedures                    23      3624 NA              
#>  4 layer1       pas_adt_events                     20    137841 2026-04-03 00:5…
#>  5 layer1       pas_op_status_log                   8   1095625 2026-03-31 19:3…
#>  6 layer1       pas_outpatient_appointments        16    316262 2026-03-31 16:2…
#>  7 layer1       pas_patients                       10     40300 2026-04-01      
#>  8 layer1       pas_referrals                      11    105953 2026-04-18      
#>  9 layer1       ris_imaging                        29     49175 2026-05-25 22:0…
#> 10 reference    admission_method                    3        11 NA              
#> # ℹ 13 more rows
#> # ℹ 1 more variable: newest_datetime_column <chr>
```

Columns carry a `type_class` that normalises engine type names, which is
what decides which statistics the profiler can ask for.

``` r

inv$columns[inv$columns$table_name == "pas_patients", c("column_name", "data_type", "type_class")]
#> # A tibble: 10 × 3
#>    column_name         data_type type_class
#>    <chr>               <chr>     <chr>     
#>  1 mrn                 VARCHAR   string    
#>  2 nhs_number          VARCHAR   string    
#>  3 nhs_number_status   VARCHAR   string    
#>  4 sex                 VARCHAR   string    
#>  5 dob                 DATE      date      
#>  6 ethnicity           VARCHAR   string    
#>  7 gp_practice         VARCHAR   string    
#>  8 postcode            VARCHAR   string    
#>  9 registered_datetime TIMESTAMP datetime  
#> 10 date_of_death       DATE      date
```

## Column profile

[`db_profile()`](https://thomuk.github.io/DBinventory/reference/db_profile.md)
runs one aggregate query per table (batched by column) plus one
frequency query per column that has few enough distinct values for a
frequency table to mean something. Tables above `sample_rows` are
profiled on a sample materialised in a temporary table; here that
threshold is set low so the audit logs are sampled.

``` r

prof <- db_profile(con, inv, sample_rows = 2e5, progress = FALSE)
#> ℹ Sampled run: foreign key inference needs exact statistics and was skipped (use sample_rows = Inf)
table(prof$sampled)
#> 
#> FALSE  TRUE 
#>   183    24
prof[prof$table_name == "pas_patients",
     c("column_name", "null_rate", "distinct_count", "is_unique", "pk_candidate", "semantic_type", "values_suppressed")]
#> # A tibble: 10 × 7
#>    column_name     null_rate distinct_count is_unique pk_candidate semantic_type
#>    <chr>               <dbl>          <dbl> <lgl>     <lgl>        <chr>        
#>  1 mrn               0                40300 TRUE      TRUE         identifier   
#>  2 nhs_number        0.00340          40051 FALSE     FALSE        identifier   
#>  3 nhs_number_sta…   0                    2 FALSE     FALSE        code         
#>  4 sex               0                    2 FALSE     FALSE        code         
#>  5 dob               0                23502 FALSE     FALSE        date         
#>  6 ethnicity         0                   17 FALSE     FALSE        code         
#>  7 gp_practice       0                   90 FALSE     FALSE        code         
#>  8 postcode          0                28643 FALSE     FALSE        identifier   
#>  9 registered_dat…   0                40297 FALSE     FALSE        datetime     
#> 10 date_of_death     0.987              430 FALSE     FALSE        date         
#> # ℹ 1 more variable: values_suppressed <lgl>
```

Literal values are suppressed by default for identifiers, free text and
columns whose names suggest personal data, because the profile of a
hospital warehouse will end up in a repository. Codes and dates keep
theirs:

``` r

top_values_of(prof, "pas_patients", "ethnicity")
#>    value     n
#> 1      A 31376
#> 2      Z  2392
#> 3      C  1207
#> 4      H  1016
#> 5      S   628
#> 6      N   604
#> 7      J   579
#> 8      B   479
#> 9      D   359
#> 10     K   311
#> 11     M   269
#> 12     L   245
#> 13     P   217
#> 14     E   183
#> 15     F   153
#> 16     R   150
#> 17     G   132
prof[prof$column_name == "dob", c("min_value", "max_value")]
#> # A tibble: 1 × 2
#>   min_value  max_value 
#>   <chr>      <chr>     
#> 1 1924-10-02 2024-09-29
```

The hashes are computed before suppression, so copies of a suppressed
column in other tables still match on fingerprint:

``` r

inv2 <- db_inventory(con, include = c("layer1\\.pas_outpatient_appointments", "derived\\.op_appointments", "reference\\."), progress = FALSE)
#> ℹ 16 tables found (duckdb dialect)
#> ✔ Inventory of 16 tables and 107 columns in 0s
prof2 <- db_profile(con, inv2, sample_rows = 2e5, progress = FALSE)
#> ℹ Sampled run: foreign key inference needs exact statistics and was skipped (use sample_rows = Inf)
duplicate_candidates(prof2)[, c("n_tables", "columns")]
#> # A tibble: 10 × 2
#>    n_tables columns                                                             
#>       <int> <chr>                                                               
#>  1        2 derived.op_appointments.mrn_as_recorded; derived.op_appointments.pe…
#>  2        2 derived.op_appointments.consultant_code; layer1.pas_outpatient_appo…
#>  3        2 derived.op_appointments.clinic_code; layer1.pas_outpatient_appointm…
#>  4        2 derived.op_appointments.attendkey; layer1.pas_outpatient_appointmen…
#>  5        2 derived.op_appointments.dnadate; layer1.pas_outpatient_appointments…
#>  6        2 reference.consultants.tfc; reference.specialties.tfc                
#>  7        2 derived.op_appointments.apptdate; layer1.pas_outpatient_appointment…
#>  8        2 derived.op_appointments.booked_datetime; layer1.pas_outpatient_appo…
#>  9        2 derived.op_appointments.cancelled_datetime; layer1.pas_outpatient_a…
#> 10        2 derived.op_appointments.referral_id; layer1.pas_outpatient_appointm…
```

## Foreign key candidates

Every string, integer or uuid column is scored against the
`pk_candidate` columns of the other tables on name, value range and
cardinality. The best target above a confidence threshold becomes
`fk_target`. It is a shortlist for the key register’s match-rate tests,
not a confirmed relationship.

``` r

prof2[prof2$fk_candidate, c("table_name", "column_name", "fk_target", "fk_confidence", "fk_evidence")]
#> # A tibble: 107 × 5
#>    table_name column_name fk_target fk_confidence fk_evidence
#>    <chr>      <chr>       <chr>             <dbl> <chr>      
#>  1 NA         NA          NA                   NA NA         
#>  2 NA         NA          NA                   NA NA         
#>  3 NA         NA          NA                   NA NA         
#>  4 NA         NA          NA                   NA NA         
#>  5 NA         NA          NA                   NA NA         
#>  6 NA         NA          NA                   NA NA         
#>  7 NA         NA          NA                   NA NA         
#>  8 NA         NA          NA                   NA NA         
#>  9 NA         NA          NA                   NA NA         
#> 10 NA         NA          NA                   NA NA         
#> # ℹ 97 more rows
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

DBI::dbDisconnect(con, shutdown = TRUE)
```
