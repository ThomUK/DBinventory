# Render the inventory report

Renders the package's Quarto template against a results store: headline
counts, the table inventory ranked by size and freshness, type and
semantic-type mixes, null and uniqueness distributions, candidate
duplicate columns and the full column profile as a searchable table.

## Usage

``` r
render_report(
  store,
  output_file = "db_inventory_report.html",
  engine = c("auto", "quarto", "rmarkdown"),
  title = "Database inventory and column profile",
  quiet = TRUE
)
```

## Arguments

- store:

  Path to a store written by
  [`inventory_run()`](https://thomuk.github.io/DBinventory/reference/inventory_run.md)
  or
  [`db_profile()`](https://thomuk.github.io/DBinventory/reference/db_profile.md).

- output_file:

  Path of the HTML file to write.

- engine:

  `"auto"`, `"quarto"` or `"rmarkdown"`.

- title:

  Report title.

- quiet:

  Suppress rendering output?

## Value

The path of the rendered file, invisibly.

## Details

Uses the Quarto CLI if it is on the path (via the `quarto` package or
[`system2()`](https://rdrr.io/r/base/system2.html)); otherwise falls
back to
[`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html),
which renders the same template through knitr and pandoc. Interactive
tables need the `DT` package; plain tables are used without it.

## Examples

``` r
if (FALSE) { # \dontrun{
out <- inventory_run(fakehosp_path(), store = "fakehosp_inventory.sqlite")
render_report("fakehosp_inventory.sqlite", "fakehosp_inventory.html")
} # }
```
