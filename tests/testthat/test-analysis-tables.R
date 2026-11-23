# Tests: analysis-ready tables built by R/04b_analysis_tables.R.
# Skipped until the tables exist. The minutes reconstruction (R/13 rule) misses a few
# team-periods; those team-games carry minutes_reconciled == FALSE and the invariant
# is asserted on the rest. See output/offseason/tables_report.md.

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

test_that("minutes within 1 minute of 200 + 25*(n_periods-4) for every minutes_reconciled team-game", {
  skip_if_not(tables_available, "analysis tables not built yet")
  j <- rd("player_games") %>% dplyr::group_by(game_id, team) %>%
    dplyr::summarise(m = sum(minutes), .groups = "drop") %>%
    dplyr::inner_join(rd("team_games") %>% dplyr::select(game_id, team, minutes_reconciled), by = c("game_id", "team")) %>%
    dplyr::inner_join(rd("games") %>% dplyr::select(game_id, n_periods), by = "game_id")
  ok <- j %>% dplyr::filter(minutes_reconciled)
  expect_gt(nrow(ok), 0)
  expect_true(all(abs(ok$m - (200 + 25 * (ok$n_periods - 4))) <= 1))
  # the flag must be exactly the 1-minute rule, and identical on player_games
  expect_equal(j$minutes_reconciled, abs(j$m - (200 + 25 * (j$n_periods - 4))) <= 1)
  pg <- rd("player_games") %>% dplyr::distinct(game_id, team, minutes_reconciled)
  expect_equal(nrow(pg), nrow(j))
  expect_false(anyNA(pg$minutes_reconciled))
})

test_that("unreconciled-minutes team-game counts per season type match pipeline_baseline.csv", {
  skip_if_not(tables_available, "analysis tables not built yet")
  base <- readr::read_csv(proj_path("data/reference/pipeline_baseline.csv"), show_col_types = FALSE,
                          col_types = readr::cols(pin = "c", .default = readr::col_guess()))
  tg <- rd("team_games")
  for (st in names(SEASON_TYPES)) {
    expect_equal(sum(!tg$minutes_reconciled[tg$season_type == st]),
                 base$minutes_unreconciled_team_games[base$season_type == st], info = st)
  }
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
