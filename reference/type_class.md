# Classify a database type name

Maps engine-specific type names to one of: `datetime`, `date`, `time`,
`boolean`, `integer`, `numeric`, `string`, `uuid`, `binary`, `lob`,
`complex`, `other`. The class decides which statistics the profiler asks
for (for example no `MIN()` on a `bit`, no `COUNT(DISTINCT)` on `text`).

## Usage

``` r
type_class(data_type, dialect = "generic")
```

## Arguments

- data_type:

  Character vector of type names as reported by the engine.

- dialect:

  A dialect object or name; SQL Server treats `timestamp` as a binary
  row version, other engines as a datetime.

## Value

Character vector of type classes.

## Examples

``` r
type_class(c("nvarchar", "datetime2", "bit", "decimal", "uniqueidentifier"), "mssql")
#> [1] "string"   "datetime" "boolean"  "numeric"  "uuid"    
```
