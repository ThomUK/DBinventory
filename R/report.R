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
#' @param organisation Name of the trust or organisation the database belongs
#'   to, used as a prefix to the title: `"Fake NHS Trust: Database inventory
#'   and column profile"`. If `NULL`, the organisation recorded by the last
#'   [inventory_run()] into this store is used, if any.
#' @param title Report title, after the organisation prefix.
#' @param quiet Suppress rendering output?
#' @return The path of the rendered file, invisibly.
#' @examples
#' \dontrun{
#' out <- inventory_run(fakehosp_path(), store = "fakehosp_inventory.sqlite", organisation = "Fake NHS Trust")
#' render_report("fakehosp_inventory.sqlite", "fakehosp_inventory.html")   # titled "Fake NHS Trust: ..."
#' }
#' @export
render_report <- function(store, output_file = "db_inventory_report.html",
                          engine = c("auto", "quarto", "rmarkdown"), organisation = NULL,
                          title = "Database inventory and column profile", quiet = TRUE) {
  engine <- match.arg(engine)
  if (is.null(organisation)) organisation <- store_organisation(store)
  if (!is.null(organisation) && nzchar(organisation)) title <- paste0(organisation, ": ", title)
  for (pkg in c("ggplot2", "scales")) {
    if (!has_pkg(pkg)) rlang::abort(paste0("render_report() needs the ", pkg, " package: install.packages('", pkg, "')"))
  }
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

#' The organisation recorded by the most recent inventory_run() into a store
#' @noRd
store_organisation <- function(store) {
  st <- store_open(store)
  on.exit(store_close(st), add = TRUE)
  meta <- store_read(st, "run_meta")
  if (is.null(meta) || nrow(meta) == 0 || !"organisation" %in% names(meta)) return(NULL)
  org <- meta$organisation[nrow(meta)]
  if (is.na(org) || !nzchar(org)) NULL else org
}
