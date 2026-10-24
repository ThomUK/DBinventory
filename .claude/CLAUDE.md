# Working notes for Claude

- Merge completed work to `main` unless Tom asks otherwise. Feature branches
  are working space, not where work is delivered.
- The package is developed against the synthetic dataset at
  https://github.com/ThomUK/synthetic-hospital-data; the SQLite fixture in
  `inst/extdata/` is built from its sample by `data-raw/build_fixture.py`.
- Run `Rscript -e 'devtools::test()'` and `rcmdcheck::rcmdcheck()` before
  pushing. CRAN is unreachable from the default cloud environment; R and most
  dependencies install from the Ubuntu archive (`apt-get install r-base r-cran-*`).
