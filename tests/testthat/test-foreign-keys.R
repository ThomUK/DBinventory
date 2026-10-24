test_that("foreign keys are proposed across the synthetic trust", {
  con <- fixture_con()
  inv <- db_inventory(con, include = c("pas_adt_events$", "pas_outpatient_appointments$", "pas_referrals$", "pas_patients$",
                                       "specialties$", "sites$", "wards$", "consultants$", "clinics$"),
                      progress = FALSE, sizes = FALSE, freshness = FALSE)
  prof <- db_profile(con, inv, progress = FALSE)
  expect_true(all(c("fk_candidate", "fk_target", "fk_confidence", "fk_evidence", "fk_n_targets") %in% names(prof)))
  target <- function(tab, col) prof$fk_target[prof$table_name == tab & prof$column_name == col]
  conf <- function(tab, col) prof$fk_confidence[prof$table_name == tab & prof$column_name == col]

  expect_equal(target("pas_outpatient_appointments", "referral_id"), "main.pas_referrals.referral_id")
  expect_equal(target("pas_outpatient_appointments", "clinic_code"), "main.clinics.clinic_code")
  expect_equal(target("pas_adt_events", "consultant_code"), "main.consultants.consultant_code")
  expect_equal(target("pas_adt_events", "site_code"), "main.sites.site_code")       # value set fully known
  expect_equal(conf("pas_adt_events", "site_code"), 1)
  expect_equal(target("pas_adt_events", "specialty_code"), "main.specialties.tfc")  # stem + range, no name match
  expect_equal(target("consultants", "main_site"), "main.sites.site_code")          # table stem in the name
  expect_equal(target("wards", "tfc"), "main.specialties.tfc")

  # primary keys and non-key columns are not children
  expect_false(prof$fk_candidate[prof$table_name == "pas_referrals" & prof$column_name == "referral_id"])
  expect_false(prof$fk_candidate[prof$table_name == "pas_adt_events" & prof$column_name == "bed"])
  expect_false(prof$fk_candidate[prof$table_name == "sites" & prof$column_name == "site_name"])
  expect_false(prof$fk_candidate[prof$table_name == "wards" & prof$column_name == "ward_id"])
  expect_true(all(prof$fk_confidence[prof$fk_candidate] >= 0.5))
  expect_true(all(is.na(prof$fk_target[!prof$fk_candidate])))
  expect_true(all(prof$fk_n_targets[prof$fk_candidate] >= 1))
})

test_that("infer_foreign_keys applies its hard filters on a hand-made profile", {
  row <- function(tab, col, type_class, distinct, nonnull, unique, pk, fp, minv, maxv, top = NA_character_,
                  minlen = NA, maxlen = NA, suppressed = FALSE, sampled = FALSE, semantic = "code") {
    data.frame(table_schema = "s", table_name = tab, column_name = col, type_class = type_class,
               rows_profiled = 100, null_count = 100 - nonnull, distinct_count = distinct, is_unique = unique,
               pk_candidate = pk, value_fingerprint = fp, min_value = minv, max_value = maxv, top_values = top,
               min_length = minlen, max_length = maxlen, values_suppressed = suppressed, sampled = sampled,
               semantic_type = semantic, stringsAsFactors = FALSE)
  }
  top <- function(...) as.character(jsonlite::toJSON(data.frame(value = c(...), n = 1)))
  prof <- rbind(
    row("sites", "site_code", "string", 2, 100, TRUE, TRUE, "fp_site", "A1", "B2", top("A1", "B2"), 2, 2),
    row("events", "site_code", "string", 2, 100, FALSE, FALSE, "fp_site", "A1", "B2", top("A1", "B2"), 2, 2),   # same fingerprint, not unique: a reference
    row("events", "flag", "string", 2, 100, FALSE, FALSE, "fp_flag", "N", "Y", top("N", "Y"), 1, 1, semantic = "flag"),
    row("events", "region", "string", 2, 100, FALSE, FALSE, "fp_reg", "C3", "D4", top("C3", "D4"), 2, 2),   # values outside the key set
    row("copy", "site_code", "string", 2, 100, TRUE, TRUE, "fp_site", "A1", "B2", top("A1", "B2"), 2, 2),    # unique with the key's fingerprint: a copy
    row("events", "code", "string", 2, 100, FALSE, FALSE, "fp_c", "100", "200", top("100", "200"), 3, 3),   # digits cannot reference letters
    row("events", "amount", "numeric", 50, 100, FALSE, FALSE, "fp_a", "1", "9", NA_character_)
  )
  out <- infer_foreign_keys(prof)
  pick <- function(tab, col) out[out$table_name == tab & out$column_name == col, ]
  expect_true(pick("events", "site_code")$fk_candidate)
  expect_true(pick("events", "site_code")$fk_target %in% c("s.sites.site_code", "s.copy.site_code"))  # identical keys tie
  expect_equal(pick("events", "site_code")$fk_n_targets, 2L)
  expect_match(pick("events", "site_code")$fk_evidence, "values=within")
  expect_false(pick("events", "flag")$fk_candidate)
  expect_false(pick("events", "region")$fk_candidate)
  expect_false(pick("copy", "site_code")$fk_candidate)
  expect_false(pick("events", "code")$fk_candidate)
  expect_false(pick("events", "amount")$fk_candidate)
  expect_false(pick("sites", "site_code")$fk_candidate)

  empty <- infer_foreign_keys(DBinventory:::empty_profile())
  expect_equal(nrow(empty), 0)
  expect_true("fk_target" %in% names(empty))
})

test_that("helpers normalise table stems and value shapes", {
  expect_equal(DBinventory:::table_stem(c("pas_referrals", "specialties", "dim_sites", "wards")), c("referral", "specialty", "site", "ward"))
  expect_equal(DBinventory:::value_shape(c("RX1", "RXH", "100", "Ward 3")), c("A9", "A", "9", "A 9"))
})

test_that("inventory_run infers foreign keys across the whole store and writes them back", {
  skip_if_no_sqlite()
  store <- withr::local_tempfile(fileext = ".sqlite")
  # first run profiles only the key table, second run adds the child and must link across both
  inventory_run(fixture_path(), store = store, include = "sites$", progress = FALSE)
  out <- inventory_run(fixture_path(), store = store, include = c("sites$", "pas_outpatient_appointments$"), progress = FALSE)
  p <- out$profile
  expect_equal(p$fk_target[p$table_name == "pas_outpatient_appointments" & p$column_name == "site_code"], "main.sites.site_code")
  st <- store_open(store)
  stored <- store_read(st, "column_profile")
  store_close(st)
  expect_type(stored$fk_candidate, "logical")
  expect_equal(sum(stored$fk_candidate), sum(p$fk_candidate))
})
