# Fingerprint profiled columns

Two hashes per column. The `value` fingerprint summarises what the
column holds (type class, order of magnitude of the distinct count, min,
max, the hash of its top values); columns with the same value
fingerprint in different tables are very likely the same data stored
again, whatever they are called. The `column` fingerprint adds the
normalised column name, which is the stricter match used to cluster
straight copies. Both are computed before any sensitive values are
suppressed, so copies of identifier columns still match.

## Usage

``` r
fingerprints(profile)
```

## Arguments

- profile:

  A data frame with the statistics produced by
  [`db_profile()`](https://thomuk.github.io/DBinventory/reference/db_profile.md).

## Value

A list with character vectors `value` and `column`.
