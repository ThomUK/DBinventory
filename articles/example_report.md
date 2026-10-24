# Example report

This is the report
[`render_report()`](https://thomuk.github.io/DBinventory/reference/render_report.md)
produces, run against the synthetic hospital database bundled with the
package: 46 tables and 523 columns from a fictional NHS trust, capped at
1,000 rows per table. It is regenerated every time the site is built, so
it always reflects the current package.

The report shows headline counts, the table inventory ranked by size and
freshness, the type and semantic-type mix, null and uniqueness
distributions, candidate duplicate columns, the full searchable column
profile and the run log. Identifier, free-text and personal-data columns
have their literal values suppressed, which is the default.

[Open the report in its own
window](https://thomuk.github.io/DBinventory/example-report.md)

To make one for your own database:

``` r

library(DBinventory)
inventory_run("Driver={ODBC Driver 18 for SQL Server};Server=...;Database=...;Trusted_Connection=yes;",
              store = "dw_inventory.sqlite", report = "dw_inventory.html")
```
