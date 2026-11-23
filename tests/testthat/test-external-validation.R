# External validation against ESPN (wehoop). Skips when the wehoop files or the maps written by
# R/04c_validate_external.R are absent. ESPN is a validator only. See
# output/offseason/external_validation.md for the full report.

wh <- function(f) file.path(WEHOOP_DIR, f)
ref <- function(f) proj_path("data", "reference", f)
have_ev <- all(file.exists(
  wh("player_box_2026.parquet"), wh("team_box_2026.parquet"), wh("wnba_schedule_2026.parquet"),
  ref("espn_game_map.csv"), ref("espn_player_map.csv"), ref("espn_team_map.csv"),
  ref("external_validation_exceptions.csv"),
  file.path(PROCESSED_DIR, "tables", "player_games.parquet")))

if (have_ev) {
  suppressMessages({library(dplyr); library(readr); library(arrow)})
  rd <- function(n) as_tibble(read_parquet(file.path(PROCESSED_DIR, "tables", paste0(n, ".parquet"))))
  tmap <- read_csv(ref("espn_team_map.csv"), show_col_types = FALSE)
  tm <- setNames(tmap$our_tricode, tmap$espn_abbr)
  gmap <- read_csv(ref("espn_game_map.csv"), show_col_types = FALSE, col_types = cols(.default = "c")) %>%
    mutate(game_id = as.numeric(game_id))
  pmap <- read_csv(ref("espn_player_map.csv"), show_col_types = FALSE, col_types = cols(.default = "c"))
  exc <- read_csv(ref("external_validation_exceptions.csv"), show_col_types = FALSE,
                  col_types = cols(.default = "c"), na = character()) %>% mutate(ours = as.numeric(ours), espn = as.numeric(espn))
  games <- rd("games")
  tg <- rd("team_games")
  pg <- rd("player_games")
  sched <- read_parquet(wh("wnba_schedule_2026.parquet")) %>% as_tibble() %>% mutate(espn_game_id = as.character(game_id))
  tbox <- read_parquet(wh("team_box_2026.parquet")) %>% as_tibble() %>%
    mutate(espn_game_id = as.character(game_id), team = unname(tm[team_abbreviation]))
  pbox <- read_parquet(wh("player_box_2026.parquet")) %>% as_tibble() %>%
    mutate(espn_game_id = as.character(game_id), athlete_id = as.character(athlete_id))
}

skip_ev <- function() testthat::skip_if_not(have_ev, "wehoop files or ESPN maps absent; run R/04c_validate_external.R")

test_that("every game of ours is matched to ESPN except games ESPN has not finalized", {
  skip_ev()
  unmatched <- games %>% filter(!game_id %in% gmap$game_id)
  # ESPN still lists the 2026 Finals Game 7 (1042600307, 2026-10-31) as scheduled with no box score.
  expect_equal(sort(unmatched$game_id), 1042600307)
  expect_equal(nrow(gmap), nrow(games) - 1L)
  expect_false(anyDuplicated(gmap$game_id) > 0)
  expect_false(anyDuplicated(gmap$espn_game_id) > 0)
})

test_that("standings from our games match the ESPN schedule (counting games)", {
  skip_ev()
  cnt <- sched %>% filter(season_type == 2, type_abbreviation == "STD", status_type_name == "STATUS_FINAL")
  espn <- bind_rows(
    cnt %>% transmute(team = unname(tm[home_abbreviation]), win = home_score > away_score),
    cnt %>% transmute(team = unname(tm[away_abbreviation]), win = away_score > home_score)) %>%
    group_by(team) %>% summarise(W = sum(win), L = sum(!win), .groups = "drop")
  ours <- tg %>% filter(season_type == "regular") %>% group_by(team) %>%
    summarise(W = sum(win), L = sum(!win), .groups = "drop")
  j <- full_join(ours, espn, by = "team", suffix = c("", "_espn"))
  expect_equal(nrow(j), 15)
  expect_true(all(j$W == j$W_espn & j$L == j$L_espn))
  expect_equal(sum(ours$W + ours$L), 660)
})

compare_team <- function() {
  ps <- pg %>% group_by(game_id, team) %>% summarise(pOREB = sum(OREB), pDREB = sum(DREB), .groups = "drop")
  tg %>% inner_join(gmap %>% select(game_id, espn_game_id), by = "game_id") %>%
    inner_join(ps, by = c("game_id", "team")) %>%
    inner_join(tbox, by = c("espn_game_id", "team"), suffix = c("", "_e"))
}

test_that("team-game count stats equal ESPN except documented source disagreements", {
  skip_ev()
  x <- compare_team()
  expect_equal(nrow(x), 704)
  pairs <- list(pts = c("pts", "team_score"), FGM = c("FGM", "field_goals_made"), FGA = c("FGA", "field_goals_attempted"),
                FG3M = c("FG3M", "three_point_field_goals_made"), FG3A = c("FG3A", "three_point_field_goals_attempted"),
                FTM = c("FTM", "free_throws_made"), FTA = c("FTA", "free_throws_attempted"),
                OREB = c("pOREB", "offensive_rebounds"), DREB = c("pDREB", "defensive_rebounds"),
                AST = c("AST", "assists"), STL = c("STL", "steals"), BLK = c("BLK", "blocks"),
                TOV = c("TOV", "total_turnovers"), PF = c("PF", "fouls"))
  obs <- bind_rows(lapply(names(pairs), function(s) {
    d <- x[[pairs[[s]][1]]] - x[[pairs[[s]][2]]]
    x[which(d != 0), ] %>% transmute(game_id = format(game_id, scientific = FALSE), team, person_id = "", stat = s,
                                      ours = .data[[pairs[[s]][1]]], espn = .data[[pairs[[s]][2]]])
  }))
  allowed <- exc %>% filter(level == "team_game") %>% select(game_id, team, person_id, stat, ours, espn)
  expect_equal(nrow(anti_join(obs, allowed, by = names(allowed))), 0)   # no undocumented mismatch
  expect_equal(nrow(anti_join(allowed, obs, by = names(allowed))), 0)   # no stale exception
  # points and made field goals are never excepted
  expect_false(any(allowed$stat %in% c("pts", "FGM", "FTM", "FTA", "FG3M", "BLK", "PF")))
})

compare_player <- function() {
  shots <- rd("shots")
  fg3a <- shots %>% filter(shot_type == "3pt") %>% count(game_id, person_id = as.character(person_id), name = "FG3A")
  pg %>% mutate(person_id = as.character(person_id)) %>%
    inner_join(gmap %>% select(game_id, espn_game_id), by = "game_id") %>%
    inner_join(pmap %>% select(person_id, athlete_id), by = "person_id") %>%
    inner_join(pbox %>% select(-game_id, -season, -season_type), by = c("espn_game_id", "athlete_id")) %>%
    left_join(fg3a, by = c("game_id", "person_id")) %>%
    mutate(FG3A = ifelse(is.na(FG3A), 0L, FG3A), REB = OREB + DREB,
           across(c(minutes.y, points, field_goals_made, field_goals_attempted, three_point_field_goals_made,
                    three_point_field_goals_attempted, free_throws_made, free_throws_attempted, offensive_rebounds,
                    defensive_rebounds, rebounds, assists, steals, blocks, turnovers, fouls),
                  ~ ifelse(did_not_play & is.na(.x), 0, .x)))
}

test_that("player-game count stats equal ESPN except documented source disagreements", {
  skip_ev()
  x <- compare_player()
  expect_gte(nrow(x), 7000)
  # every one of our player-game rows in a matched game is mapped
  expect_equal(nrow(x), nrow(pg %>% filter(game_id %in% gmap$game_id)))
  pairs <- list(pts = c("PTS", "points"), FGM = c("FGM", "field_goals_made"), FGA = c("FGA", "field_goals_attempted"),
                FG3M = c("FG3M", "three_point_field_goals_made"), FG3A = c("FG3A", "three_point_field_goals_attempted"),
                FTM = c("FTM", "free_throws_made"), FTA = c("FTA", "free_throws_attempted"),
                OREB = c("OREB", "offensive_rebounds"), DREB = c("DREB", "defensive_rebounds"), REB = c("REB", "rebounds"),
                AST = c("AST", "assists"), STL = c("STL", "steals"), BLK = c("BLK", "blocks"),
                TOV = c("TOV", "turnovers"), PF = c("PF", "fouls"))
  obs <- bind_rows(lapply(names(pairs), function(s) {
    d <- x[[pairs[[s]][1]]] - x[[pairs[[s]][2]]]
    x[which(d != 0), ] %>% transmute(game_id = format(game_id, scientific = FALSE), team, person_id, stat = s,
                                      ours = .data[[pairs[[s]][1]]], espn = .data[[pairs[[s]][2]]])
  }))
  allowed <- exc %>% filter(level == "player_game") %>% select(game_id, team, person_id, stat, ours, espn)
  expect_equal(nrow(anti_join(obs, allowed, by = names(allowed))), 0)
  expect_equal(nrow(anti_join(allowed, obs, by = names(allowed))), 0)
})

test_that("minutes agree with ESPN within 1.0 for at least 99 percent of player-games", {
  skip_ev()
  x <- compare_player()
  rate <- mean(abs(x$minutes.x - x$minutes.y) <= 1.0 + 1e-9)
  expect_gte(rate, 0.99)
})

test_that("the 10 player-games changed by the starter-inference fix agree with ESPN", {
  skip_ev()
  x <- compare_player()
  fix10 <- data.frame(game_id = c(1022600312, 1022600149, 1022600230, 1022600237, 1022600183,
                                  1022600218, 1022600230, 1022600183, 1042600201, 1042600304),
                      person_id = c("203398", "204319", "204319", "204333", "1627673",
                                    "1629482", "1629482", "1630134", "1631044", "1631044"))
  y <- fix10 %>% inner_join(x, by = c("game_id", "person_id"))
  expect_equal(nrow(y), 10)
  expect_true(all(abs(y$minutes.x - y$minutes.y) <= 1.0))
})
