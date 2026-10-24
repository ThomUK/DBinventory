# Read the top values of a profile row back into a data frame

Read the top values of a profile row back into a data frame

## Usage

``` r
top_values_of(x, table = NULL, column = NULL)
```

## Arguments

- x:

  A `column_profile` row's `top_values` JSON string, or the profile
  itself together with `column` and (optionally) `table`.

- table, column:

  Table and column name when `x` is a profile.

## Value

A data frame with `value` and `n`, or `NULL` when not recorded.
