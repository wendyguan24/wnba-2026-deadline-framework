# Tests: analysis-ready tables built by R/04b_analysis_tables.R.
# Skipped until the tables exist. The minutes check is a hard invariant by design;
# the minutes reconstruction (R/13 rule) misses a few team-periods, see
# output/offseason/tables_report.md for the current failure list.

library(testthat)

tables_dir <- file.path(PROCESSED_DIR, "tables")
tables_available <- all(file.exists(file.path(
  tables_dir, paste0(c("games", "team_games", "player_games", "shots"), ".parquet"))))

rd <- function(n) dplyr::as_tibble(arrow::read_parquet(file.path(tables_dir, paste0(n, ".parquet"))))

test_that("primary keys are unique", {
  skip_if_not(tables_available, "analysis tables not built yet")
  expect_false(anyDuplicated(rd("games")$game_id) > 0)
  expect_false(anyDuplicated(rd("team_games")[c("game_id", "team")]) > 0)
  expect_false(anyDuplicated(rd("player_games")[c("game_id", "team", "person_id")]) > 0)
})

test_that("every game has exactly 2 team_games", {
  skip_if_not(tables_available, "analysis tables not built yet")
  n <- dplyr::count(rd("team_games"), game_id)
  expect_true(all(n$n == 2))
  expect_equal(nrow(n), nrow(rd("games")))
})

test_that("team_games pts equal the games table home/away pts", {
  skip_if_not(tables_available, "analysis tables not built yet")
  g <- rd("games"); tg <- rd("team_games")
  i <- match(tg$game_id, g$game_id)
  expect_equal(tg$pts, dplyr::if_else(tg$is_home, g$home_pts[i], g$away_pts[i]))
})

test_that("sum of player_games points per team-game equals team_games pts", {
  skip_if_not(tables_available, "analysis tables not built yet")
  j <- rd("player_games") %>% dplyr::group_by(game_id, team) %>%
    dplyr::summarise(p = sum(PTS), .groups = "drop") %>%
    dplyr::inner_join(rd("team_games"), by = c("game_id", "team"))
  expect_equal(nrow(j), nrow(rd("team_games")))
  expect_true(all(j$p == j$pts))
})

test_that("sum of player minutes per team-game is within 1 minute of 200 + 25*(n_periods-4)", {
  skip_if_not(tables_available, "analysis tables not built yet")
  j <- rd("player_games") %>% dplyr::group_by(game_id, team) %>%
    dplyr::summarise(m = sum(minutes), .groups = "drop") %>%
    dplyr::inner_join(rd("games") %>% dplyr::select(game_id, n_periods), by = "game_id")
  expect_true(all(abs(j$m - (200 + 25 * (j$n_periods - 4))) <= 1))
})

test_that("season_type is never NA", {
  skip_if_not(tables_available, "analysis tables not built yet")
  for (n in c("games", "team_games", "player_games", "shots")) {
    st <- rd(n)$season_type
    expect_false(anyNA(st), info = n)
    expect_true(all(st %in% c("regular", "playoffs")), info = n)
  }
})

test_that("shots made-points per team-game equal team pts minus free-throw points", {
  skip_if_not(tables_available, "analysis tables not built yet")
  fg <- rd("shots") %>% dplyr::group_by(game_id, team) %>%
    dplyr::summarise(fg_pts = sum(points), .groups = "drop")
  j <- rd("team_games") %>% dplyr::left_join(fg, by = c("game_id", "team"))
  expect_true(all(j$fg_pts == j$pts - j$FTM))
})
