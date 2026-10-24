# Infer a semantic type for each profiled column

The categories are the roadmap's (identifier, date, code, free text,
flag) plus a few that fall out naturally. Rules are deliberately simple
and ordered; the result is a first draft for a person to confirm.

## Usage

``` r
infer_semantic_type(profile, top = NULL)
```

## Arguments

- profile:

  A data frame with the statistics produced by
  [`db_profile()`](https://thomuk.github.io/DBinventory/reference/db_profile.md).

- top:

  A list of top-value data frames, one per row of `profile`, or `NULL`.

## Value

A character vector, one semantic type per row.

## Details

- `empty`: no non-null values

- `constant`: one distinct value

- `flag`: boolean type, or at most two values that look like yes/no

- `datetime`, `date`, `time`: by type, or text whose values parse as
  such

- `identifier`: nearly unique, a key-like name with high uniqueness, or
  short strings with more than half their values distinct

- `code`: short strings from a small set

- `category`: longer labels from a small set

- `free_text`: long or highly varied strings

- `count`: integers; `measure`: other numerics

- `unknown`: anything else (binary, LOB, complex types)
