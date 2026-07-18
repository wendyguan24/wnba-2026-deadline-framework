# Tests: clock-parsing round-trip. See HANDOFF §4 and R/02_parse_pbp.R
# parse_clock().

library(testthat)

test_that("parse_clock converts PT09M57.00S to 597 seconds", {
  expect_equal(parse_clock("PT09M57.00S"), 597)
})

test_that("parse_clock handles period boundaries: WNBA quarters run PT10M00.00S (not PT12M, the NBA convention), OT runs PT05M00.00S", {
  # Verified against real data 2026-07-18: 728 period-start events show
  # PT10M00.00S, 11 OT-period-start events show PT05M00.00S. No PT12M values
  # exist in this data.
  expect_equal(parse_clock("PT10M00.00S"), 600)
  expect_equal(parse_clock("PT05M00.00S"), 300)
  expect_equal(parse_clock("PT00M00.00S"), 0)
})

test_that("parse_clock handles fractional seconds correctly", {
  expect_equal(parse_clock("PT01M13.40S"), 73.4)
})

test_that("parse_clock errors loudly on an unrecognized format rather than silently returning NA", {
  expect_error(parse_clock("garbage"), "unrecognized clock format")
})

test_that("parsed clock values are monotonically non-increasing within a period, ordered by orderNumber", {
  skip_if_not(file.exists(proj_path("data/processed/pbp_events.rds")), "pbp_events.rds not built yet")
  pbp <- readRDS(proj_path("data/processed/pbp_events.rds"))
  sample_game <- pbp %>%
    dplyr::filter(gameId == dplyr::first(gameId), period == 1) %>%
    dplyr::arrange(orderNumber)
  diffs <- diff(sample_game$parsed_clock_seconds)
  expect_true(all(diffs <= 0 | is.na(diffs)))
})
