# Write a data frame into the store

Write a data frame into the store

## Usage

``` r
store_write(store, name, x, append = FALSE)
```

## Arguments

- store:

  A `db_store`.

- name:

  Table name inside the store.

- x:

  A data frame.

- append:

  Append to an existing table (`TRUE`) or replace it.

## Value

`store`, invisibly.
