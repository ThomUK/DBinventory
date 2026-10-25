# A profile of the synthetic trust fixture, run once per test file
fixture_profile <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      con <- DBI::dbConnect(RSQLite::SQLite(), fixture_path(), flags = RSQLite::SQLITE_RO)
      on.exit(DBI::dbDisconnect(con))
      inv <- db_inventory(con, exclude = "^main\\.agg_", progress = FALSE, sizes = FALSE)
      prof <- db_profile(con, inv, progress = FALSE)
      cache <<- list(inv = inv, prof = prof)
    }
    cache
  }
})

test_that("cluster_tables recovers the synthetic lineage and classifies tables", {
  skip_if_no_sqlite()
  d <- fixture_profile()
  cl <- cluster_tables(d$prof, d$inv)
  expect_named(cl, c("clusters", "pairs", "matches"))
  x <- cl$clusters
  expect_equal(nrow(x), nrow(d$inv$tables))
  expect_true(all(x$role[x$cluster_id %in% x$cluster_id[duplicated(x$cluster_id)]] != "standalone"))
  expect_true(all(x$role[!x$cluster_id %in% x$cluster_id[duplicated(x$cluster_id)]] == "standalone"))
  # every cluster has exactly one canonical member, and it names itself
  for (cid in unique(x$cluster_id)) {
    m <- x[x$cluster_id == cid, ]
    expect_equal(sum(m$role == "canonical") + (nrow(m) == 1), 1)
    expect_true(all(m$canonical %in% x$table))
  }
  same <- function(a, b) x$cluster_id[x$table_name == a] == x$cluster_id[x$table_name == b]
  expect_true(same("pas_patients", "derived_patients"))              # the same patients, cleaned
  expect_true(same("pas_outpatient_appointments", "derived_op_appointments"))
  expect_false(same("sites", "pas_adt_events"))                        # a reference list is not a copy of what references it
  expect_false(same("admission_source", "discharge_destination"))      # code lists that share codes but not a name
  expect_true(all(x$table_class[x$table_name %in% c("sites", "specialties", "wards", "admission_method")] == "reference"))
  expect_true(all(x$table_class[x$table_name %in% c("pas_adt_events", "derived_spells")] == "event"))
  multi <- x[x$cluster_id %in% x$cluster_id[duplicated(x$cluster_id)], ]
  expect_true(all(!is.na(multi$rationale) & nchar(multi$rationale) > 20))
  expect_true(all(multi$confidence >= 0 & multi$confidence <= 1))
  expect_true(all(cl$pairs$relationship_a %in% c("copy", "filtered_subset", "wider_derivative", "narrower", "aggregate", "related")))
})

test_that("schema_priority overrides the canonical choice", {
  skip_if_no_sqlite()
  d <- fixture_profile()
  # the fixture has one schema, so fake two: tables named derived_* become schema "derived"
  inv <- d$inv; prof <- d$prof
  derived_t <- grepl("^derived_", inv$tables$table_name); derived_c <- grepl("^derived_", prof$table_name)
  inv$tables$table_schema[derived_t] <- "derived"; prof$table_schema[derived_c] <- "derived"
  a <- cluster_tables(prof, inv, schema_priority = c("derived", "main"))
  b <- cluster_tables(prof, inv, schema_priority = c("main", "derived"))
  pat_a <- unique(a$clusters$canonical[a$clusters$table_name == "pas_patients"])
  pat_b <- unique(b$clusters$canonical[b$clusters$table_name == "pas_patients"])
  expect_match(pat_a, "^derived\\.")
  expect_match(pat_b, "^main\\.")
})

test_that("cluster_tables refuses a sampled profile and handles an empty one", {
  skip_if_no_sqlite()
  d <- fixture_profile()
  p <- d$prof; p$sampled[1] <- TRUE
  expect_error(cluster_tables(p, d$inv), "full run")
  empty <- cluster_tables(DBinventory:::empty_profile(), list(tables = d$inv$tables[0, ]))
  expect_equal(nrow(empty$clusters), 0)
})

test_that("decisions are written, merged and applied", {
  skip_if_no_sqlite()
  d <- fixture_profile()
  cl <- cluster_tables(d$prof, d$inv)
  path <- withr::local_tempfile(fileext = ".csv")
  written <- write_cluster_decisions(cl$clusters, path)
  expect_equal(nrow(written), nrow(cl$clusters))
  expect_true(all(written$status == "proposed"))

  # the owners confirm a different canonical member for the patients cluster and reject a membership
  dec <- utils::read.csv(path, stringsAsFactors = FALSE)
  pat <- dec$table == "main.pas_patients"
  dec$status[pat] <- "confirmed"; dec$canonical[pat] <- "main.pas_patients"; dec$note[pat] <- "source system table"
  app <- dec$table == "main.derived_op_appointments"
  dec$status[app] <- "rejected"
  utils::write.csv(dec, path, row.names = FALSE)

  cl2 <- cluster_tables(d$prof, d$inv, decisions = read_cluster_decisions(path))
  x <- cl2$clusters
  expect_equal(unique(x$canonical[x$table_name %in% c("pas_patients", "derived_patients")]), "main.pas_patients")
  expect_equal(x$role[x$table == "main.pas_patients"], "canonical")
  expect_equal(x$status[x$table == "main.pas_patients"], "confirmed")
  expect_equal(x$role[x$table == "main.derived_op_appointments"], "standalone")
  expect_equal(x$status[x$table == "main.derived_op_appointments"], "rejected")
  expect_match(x$rationale[x$table == "main.pas_patients"], "confirmed by review")

  # rewriting keeps the decisions and only adds proposed rows
  merged <- write_cluster_decisions(cl2$clusters, path)
  expect_equal(merged$status[merged$table == "main.pas_patients"], "confirmed")
  expect_equal(merged$note[merged$table == "main.pas_patients"], "source system table")
  expect_null(read_cluster_decisions(withr::local_tempfile(fileext = ".csv")))
})

test_that("inventory_run clusters on a full run and skips phases 2 and 3 on a sampled run", {
  skip_if_no_sqlite()
  store <- withr::local_tempfile(fileext = ".sqlite")
  dec <- withr::local_tempfile(fileext = ".csv")
  out <- inventory_run(fixture_path(), store = store, include = c("pas_patients$", "derived_patients$", "sites$"),
                       decisions = dec, progress = FALSE)
  expect_false(is.null(out$clusters))
  expect_true(file.exists(dec))
  st <- store_open(store)
  expect_true(all(c("table_clusters", "table_pairs") %in% store_tables(st)))
  cl <- store_read(st, "table_clusters")
  store_close(st)
  expect_equal(cl$cluster_id[cl$table_name == "pas_patients"], cl$cluster_id[cl$table_name == "derived_patients"])

  store2 <- withr::local_tempfile(fileext = ".sqlite")
  expect_message(out2 <- inventory_run(fixture_path(), store = store2, include = c("pas_patients$", "derived_patients$"),
                                       sample_rows = 50, progress = FALSE), "Sampled run")
  expect_null(out2$clusters)
  expect_true(all(is.na(out2$profile$fk_candidate)))
  st <- store_open(store2)
  expect_false("table_clusters" %in% store_tables(st))
  store_close(st)
})
