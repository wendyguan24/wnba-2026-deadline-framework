# Tests: LAS/LVA tricode mapping is applied correctly and teams are never
# silently swapped. See HANDOFF §4 ("Tricode trap") and CLAUDE.md.

library(testthat)

test_that("LAS maps to Los Angeles Sparks", {
  result <- TEAM_TRICODE_MAP$team_full_name[TEAM_TRICODE_MAP$teamTricode == "LAS"]
  expect_equal(result, "Los Angeles Sparks")
})

test_that("LVA maps to Las Vegas Aces", {
  result <- TEAM_TRICODE_MAP$team_full_name[TEAM_TRICODE_MAP$teamTricode == "LVA"]
  expect_equal(result, "Las Vegas Aces")
})

test_that("all 15 team tricodes are present and map to distinct full names", {
  expect_equal(nrow(TEAM_TRICODE_MAP), 15)
  expect_equal(length(unique(TEAM_TRICODE_MAP$team_full_name)), 15)
})

test_that("apply_team_mapping errors on an unmapped tricode instead of silently dropping it", {
  bad_data <- tibble::tibble(teamTricode = c("LAS", "ZZZ"))
  expect_error(apply_team_mapping(bad_data), "unmapped tricode")
})

test_that("real parsed data: LAS rows are tagged Los Angeles Sparks and LVA rows are tagged Las Vegas Aces (never swapped)", {
  skip_if_not(file.exists(proj_path("data/processed/pbp_events.rds")), "pbp_events.rds not built yet")
  pbp <- readRDS(proj_path("data/processed/pbp_events.rds"))
  # dplyr::filter (not base-R bracket indexing) to correctly drop NA
  # teamTricode rows rather than inserting a spurious NA element -- vec[cond]
  # with an NA in cond includes an NA in the result, which base-R bracket
  # indexing would otherwise silently do here.
  las_names <- unique(dplyr::filter(pbp, teamTricode == "LAS")$team_full_name)
  lva_names <- unique(dplyr::filter(pbp, teamTricode == "LVA")$team_full_name)
  expect_equal(las_names, "Los Angeles Sparks")
  expect_equal(lva_names, "Las Vegas Aces")
})
