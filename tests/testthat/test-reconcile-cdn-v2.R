# Tests: cdn vs nbastats v2 per-game FGA/FGM/AST/3PA counts reconcile within
# a documented tolerance (mirrors the NCAA project's wehoop reconciliation
# and its documented 2.5-FGM gap -- deltas must be reported, not hidden).
# See HANDOFF §4 ("nbastats v2 -- reconciliation only") and R/04_reconcile.R.
#
# Two layers:
#  - v1 subset (regular-season gameIds 1 to 182): original v1 tolerances
#    (observed sum|FGA|=1, |FGM|=1, |AST|=4, |FG3A|=0 on 364 team-games).
#  - Full pin (46488f0), per season type: the observed sums are KNOWN source
#    disagreement between cdn and v2, stored in data/reference/pipeline_baseline.csv
#    and compared exactly. Changing them means re-baselining deliberately.

library(testthat)

baseline_path <- proj_path("data/reference/pipeline_baseline.csv")
pbp_path <- file.path(PROCESSED_DIR, "pbp_events.rds")
data_available <- file.exists(baseline_path) && file.exists(pbp_path) &&
  all(file.exists(vapply(names(SEASON_TYPES), function(st) raw_csv("nbastats", st), character(1))))

get_reconciliation <- function(season_type) {
  pbp <- readRDS(pbp_path) %>% dplyr::filter(season_type == !!season_type)
  v2_raw <- readr::read_csv(raw_csv("nbastats", season_type), show_col_types = FALSE, guess_max = 100000)
  reconcile_cdn_v2(compute_team_game_counts_cdn(pbp), compute_team_game_counts_v2(v2_raw))
}

v1_reconciliation <- function() {
  r <- get_reconciliation("regular")
  v1_ids <- sort(unique(r$gameId))[seq_len(V1_CUTOFF_GAMES)]
  r %>% dplyr::filter(gameId %in% v1_ids)
}

test_that("v1 subset: FGA, FGM, AST reconcile within the original v1 tolerances", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  r <- v1_reconciliation()
  expect_lte(sum(abs(r$FGA_delta), na.rm = TRUE), 5)
  expect_lte(sum(abs(r$FGM_delta), na.rm = TRUE), 5)
  expect_lte(sum(abs(r$AST_delta), na.rm = TRUE), 10)
})

test_that("v1 subset: per-game 3PA reconciles between cdn and v2 exactly", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  expect_equal(sum(abs(v1_reconciliation()$FG3A_delta), na.rm = TRUE), 0)
})

test_that("v1 subset has 182 games, 15 teams and 364 team-games", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  r <- v1_reconciliation()
  expect_equal(dplyr::n_distinct(r$gameId), 182)
  expect_equal(dplyr::n_distinct(r$team), 15)
  expect_equal(nrow(r), 364)
})

test_that("per-season-type game and team-game counts match pipeline_baseline.csv", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  base <- readr::read_csv(baseline_path, show_col_types = FALSE, col_types = readr::cols(pin = "c", .default = readr::col_guess()))
  for (st in names(SEASON_TYPES)) {
    b <- base %>% dplyr::filter(season_type == st)
    r <- get_reconciliation(st)
    expect_equal(dplyr::n_distinct(r$gameId), b$games, info = st)
    expect_equal(nrow(r), b$team_games, info = st)
    expect_equal(b$pin, PIN_SHORT)
  }
})

test_that("per-season-type cdn vs v2 deltas equal the stored known-disagreement values", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  base <- readr::read_csv(baseline_path, show_col_types = FALSE, col_types = readr::cols(pin = "c", .default = readr::col_guess()))
  for (st in names(SEASON_TYPES)) {
    b <- base %>% dplyr::filter(season_type == st)
    r <- get_reconciliation(st)
    expect_equal(sum(abs(r$FGA_delta), na.rm = TRUE), b$v2_abs_delta_fga, info = st)
    expect_equal(sum(abs(r$FGM_delta), na.rm = TRUE), b$v2_abs_delta_fgm, info = st)
    expect_equal(sum(abs(r$AST_delta), na.rm = TRUE), b$v2_abs_delta_ast, info = st)
    expect_equal(sum(abs(r$FG3A_delta), na.rm = TRUE), b$v2_abs_delta_fg3a, info = st)
  }
})
