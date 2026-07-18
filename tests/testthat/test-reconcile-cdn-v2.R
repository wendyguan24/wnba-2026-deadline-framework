# Tests: cdn vs nbastats v2 per-game FGA/FGM/AST/3PA counts reconcile within
# a documented tolerance (mirrors the NCAA project's wehoop reconciliation
# and its documented 2.5-FGM gap — deltas must be reported, not hidden).
# See HANDOFF §4 ("nbastats v2 — reconciliation only") and R/04_reconcile.R.
#
# Verified against real data 2026-07-18, across 364 team-games: sum(|FGA
# delta|) = 1, sum(|FGM delta|) = 1 (same single game/team, IND game
# 1022600004), sum(|AST delta|) = 4, sum(|FG3A delta|) = 0. Tolerances below
# are set just above these observed values, not at 0, so the test documents
# the real (tiny) gap instead of demanding an unrealistic exact match.

library(testthat)

get_reconciliation <- function() {
  pbp <- readRDS(proj_path("data/processed/pbp_events.rds"))
  v2_raw <- readr::read_csv(proj_path("data/raw/wnba_nbastats_2026.csv"), show_col_types = FALSE, guess_max = 100000)
  cdn_counts <- compute_team_game_counts_cdn(pbp)
  v2_counts <- compute_team_game_counts_v2(v2_raw)
  reconcile_cdn_v2(cdn_counts, v2_counts)
}

data_available <- file.exists(proj_path("data/processed/pbp_events.rds")) && file.exists(proj_path("data/raw/wnba_nbastats_2026.csv"))

test_that("per-game FGA reconciles between cdn and nbastats v2 within a small documented tolerance", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  r <- get_reconciliation()
  expect_lte(sum(abs(r$FGA_delta), na.rm = TRUE), 5)
})

test_that("per-game FGM reconciles between cdn and nbastats v2 within a small documented tolerance", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  r <- get_reconciliation()
  expect_lte(sum(abs(r$FGM_delta), na.rm = TRUE), 5)
})

test_that("per-game AST reconciles between cdn and nbastats v2 within a small documented tolerance", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  r <- get_reconciliation()
  expect_lte(sum(abs(r$AST_delta), na.rm = TRUE), 10)
})

test_that("per-game 3PA reconciles between cdn and nbastats v2 exactly", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  r <- get_reconciliation()
  expect_equal(sum(abs(r$FG3A_delta), na.rm = TRUE), 0)
})

test_that("cdn and v2 agree on 182 total games and 15 teams", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  r <- get_reconciliation()
  expect_equal(dplyr::n_distinct(r$gameId), 182)
  expect_equal(dplyr::n_distinct(r$team), 15)
  expect_equal(nrow(r), 364)
})
