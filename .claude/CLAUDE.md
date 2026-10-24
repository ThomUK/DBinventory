# Working notes for Claude

- Merge completed work to `main` unless Tom asks otherwise. Feature branches
  are working space, not where work is delivered.
- The package is developed against the synthetic dataset at
  https://github.com/ThomUK/synthetic-hospital-data, read through its
  `fakehospdata` package (installed from GitHub, `subdir = "fakehospdata"`).
  No sample data ships in this package: the tests run offline on
  `tests/testthat/fixtures/fakehosp_tiny.sqlite` (built by the script beside
  it); examples are `\dontrun`; the articles use the real sample.
- Every commit to `main` increments the patch version in `DESCRIPTION`
  (`Version: 0.1.1` becomes `0.1.2`), in the same commit as the change.
- Run `Rscript -e 'devtools::test()'` and `rcmdcheck::rcmdcheck()` before
  pushing. CRAN is unreachable from the default cloud environment; R and most
  dependencies install from the Ubuntu archive (`apt-get install r-base r-cran-*`).
- The pkgdown site (https://thomuk.github.io/DBinventory/) is built by
  `.github/workflows/pkgdown.yaml` on every push to main. The "Example
  Reports" page embeds the HTML in `pkgdown/assets/`, which is committed and
  regenerated only by the manual `example-reports` workflow (Actions tab);
  the site build does not render reports.
