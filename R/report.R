#' Render the inventory report
#'
#' Renders the package's Quarto template against a results store: headline
#' counts, the table inventory ranked by size and freshness, type and
#' semantic-type mixes, null and uniqueness distributions, candidate duplicate
#' columns and the full column profile as a searchable table.
#'
#' Uses the Quarto CLI if it is on the path (via the `quarto` package or
#' `system2()`); otherwise falls back to `rmarkdown::render()`, which renders
#' the same template through knitr and pandoc. Interactive tables need the `DT`
#' package; plain tables are used without it.
#'
#' @param store Path to a store written by [inventory_run()] or [db_profile()].
#' @param output_file Path of the HTML file to write.
#' @param engine `"auto"`, `"quarto"` or `"rmarkdown"`.
#' @param title Report title.
#' @param quiet Suppress rendering output?
#' @return The path of the rendered file, invisibly.
#' @examples
#' \dontrun{
#' out <- inventory_run(fakehosp_path(), store = "fakehosp_inventory.sqlite")
#' render_report("fakehosp_inventory.sqlite", "fakehosp_inventory.html")
#' }
#' @export
render_report <- function(store, output_file = "db_inventory_report.html",
                          engine = c("auto", "quarto", "rmarkdown"),
                          title = "Database inventory and column profile", quiet = TRUE) {
  engine <- match.arg(engine)
  store <- normalizePath(store, mustWork = TRUE)
  template <- system.file("report", "inventory_report.qmd", package = "DBinventory", mustWork = TRUE)
  output_file <- normalizePath(output_file, mustWork = FALSE)
  if (!dir.exists(dirname(output_file))) dir.create(dirname(output_file), recursive = TRUE)

  have_quarto <- nzchar(Sys.which("quarto")) || (has_pkg("quarto") && !is.null(tryCatch(quarto::quarto_path(), error = function(e) NULL)))
  if (engine == "auto") engine <- if (have_quarto) "quarto" else "rmarkdown"

  work <- tempfile("dbinventory_report_")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  params <- list(store = store, title = title)

  if (engine == "quarto") {
    if (!have_quarto) rlang::abort("Quarto CLI not found; install Quarto or use engine = 'rmarkdown'")
    qmd <- file.path(work, "inventory_report.qmd")
    file.copy(template, qmd)
    if (has_pkg("quarto")) {
      quarto::quarto_render(qmd, output_file = "inventory_report.html", execute_params = params, quiet = quiet)
    } else {
      yml <- file.path(work, "params.yml")
      writeLines(c(paste0("store: '", gsub("'", "''", store), "'"), paste0("title: '", gsub("'", "''", title), "'")), yml)
      status <- system2("quarto", c("render", shQuote(qmd), "--execute-params", shQuote(yml), if (quiet) "--quiet"))
      if (status != 0) rlang::abort("quarto render failed")
    }
    rendered <- file.path(work, "inventory_report.html")
  } else {
    if (!has_pkg("rmarkdown")) rlang::abort("Rendering needs either Quarto or the rmarkdown package")
    rmd <- file.path(work, "inventory_report.Rmd")
    file.copy(template, rmd)
    rendered <- rmarkdown::render(
      rmd, output_format = rmarkdown::html_document(toc = TRUE, toc_float = TRUE, theme = "flatly", self_contained = TRUE),
      output_file = "inventory_report.html", params = params, quiet = quiet, envir = new.env()
    )
  }
  file.copy(rendered, output_file, overwrite = TRUE)
  cli::cli_alert_success("Report written to {output_file}")
  invisible(output_file)
}
