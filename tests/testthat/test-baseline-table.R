# Tests: the parsed pipeline reproduces the HANDOFF §4 baseline sanity table
# (8 teams: GSV, NYL, PDX, TOR, MIN, WAS, CON, ATL) within rounding, for FGA,
# FG%, 3PA rate, assisted rate (of FGM), fastbreak share (of FGA), and paint
# share (of FGM). See R/04_reconcile.R validate_baseline_table().
#
# Verified against real data 2026-07-18: all 8 teams x 6 metrics reproduce
# with 0 delta at 3-decimal rounding. Paint share definition confirmed as
# made shots with area in {"Restricted Area", "In The Paint (Non-RA)"} / FGM.

library(testthat)

pbp_path <- proj_path("data/processed/pbp_events.rds")

get_baseline <- function() {
  pbp <- readRDS(pbp_path)
  validate_baseline_table(pbp)
}

test_that("team FGA matches HANDOFF §4 baseline table exactly", {
  skip_if_not(file.exists(pbp_path), "pbp_events.rds not built yet")
  baseline <- get_baseline()
  expect_true(all(baseline$FGA_delta == 0))
})

test_that("team FG% matches HANDOFF §4 baseline table within rounding", {
  skip_if_not(file.exists(pbp_path), "pbp_events.rds not built yet")
  baseline <- get_baseline()
  expect_true(all(abs(baseline$FG_pct_delta) < 0.001))
})

test_that("team 3PA rate matches HANDOFF §4 baseline table within rounding", {
  skip_if_not(file.exists(pbp_path), "pbp_events.rds not built yet")
  baseline <- get_baseline()
  expect_true(all(abs(baseline$FG3A_rate_delta) < 0.001))
})

test_that("team assisted rate (of FGM) matches HANDOFF §4 baseline table within rounding", {
  skip_if_not(file.exists(pbp_path), "pbp_events.rds not built yet")
  baseline <- get_baseline()
  expect_true(all(abs(baseline$assisted_rate_delta) < 0.001))
})

test_that("team fastbreak share (of FGA) matches HANDOFF §4 baseline table within rounding", {
  skip_if_not(file.exists(pbp_path), "pbp_events.rds not built yet")
  baseline <- get_baseline()
  expect_true(all(abs(baseline$fastbreak_share_delta) < 0.001))
})

test_that("team paint share (of FGM) matches HANDOFF §4 baseline table within rounding", {
  skip_if_not(file.exists(pbp_path), "pbp_events.rds not built yet")
  baseline <- get_baseline()
  expect_true(all(abs(baseline$paint_share_delta) < 0.001))
})
