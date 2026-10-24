# Renders the example report that the pkgdown site embeds under "Example Report".
# Run from the package root, after installing the package:
#   Rscript pkgdown/render_example_report.R
# The pkgdown workflow runs it before building the site. The output lands in
# pkgdown/assets/, which pkgdown copies to the site root, so the article at
# vignettes/articles/example_report.Rmd can embed ../example-report.html.
library(DBinventory)

dir.create("pkgdown/assets", showWarnings = FALSE, recursive = TRUE)
store <- tempfile("fakehosp_", fileext = ".sqlite")
inventory_run(fakehosp_path(), store = store, progress = FALSE)

out <- "pkgdown/assets/example-report.html"
rendered <- tryCatch(
  render_report(store, out, engine = "auto", title = "Fake NHS Trust: inventory and column profile"),
  error = function(e) {
    message("Quarto render failed, falling back to rmarkdown: ", conditionMessage(e))
    render_report(store, out, engine = "rmarkdown", title = "Fake NHS Trust: inventory and column profile")
  }
)
cat("Rendered", rendered, "(", round(file.size(rendered) / 1e6, 1), "MB )\n")
