# 15_reread.R
#
# Purpose: full-season re-read of v1 (PLAN.md "Scope"): trade flags (Block B), the
#   pre-registered hypothesis tests H-R1 to H-R4, H1, H2, H3 (Block C), the v1 read
#   scorecard and the playoffs descriptive table. Regular season only for all
#   hypotheses; playoffs are descriptive. No hypotheses are added here.
#
# Inputs:  window outputs from R/05, R/07, R/06 (first_half, second_half, full, playoffs)
#          under data/processed/full2026/windows/ and output/offseason/reread/;
#          v1 outputs in output/ (icc_table.csv, deadline_read.csv);
#          analysis tables (games, team_games, player_games).
# Outputs: output/offseason/reread/*.csv (trade_flags, test results, scorecard, playoffs table)
#
# Run from the repo root after the four windows have been built:
#   for w in first_half second_half full playoffs; do ... done  (see README)
#   Rscript R/15_reread.R

suppressMessages(library(tidyverse))
source(file.path(if (exists("PROJECT_ROOT")) PROJECT_ROOT else ".", "R", "00_config.R"))
source(file.path(PROJECT_ROOT, "R", "load_tables.R"))

REREAD_DIR <- file.path(OUTPUT_DIR, "reread")
BOOT_SEED <- 20261123L
N_BOOT <- 2000L
DEADLINE_DATE <- as.Date("2026-08-02")
# "Around the deadline" rule: the player's first game for the new team is within
# 2026-07-26 to 2026-08-09, or the gap between the last game for the old team and the
# first game for the new team contains the deadline date.
DEADLINE_BAND <- as.Date(c("2026-07-26", "2026-08-09"))
TRADE_FLAG_SHARE <- 0.10

window_dir <- function(w) file.path(PROCESSED_DIR, "windows", w)
window_out <- function(w) file.path(REREAD_DIR, w)

# Block B: trade flags -----------------------------------------------------

#' Player stints per team (regular season) in game_id order, with minutes by window
#'
#' @return tibble: person_id, player_name, team, first_game, last_game, first_date,
#'   last_date, games, minutes_first_half, minutes_second_half, stint_n, n_stints
build_stints <- function() {
  games <- load_table("games", "regular") %>% select(game_id, game_date)
  pg <- load_table("player_games", "regular") %>%
    left_join(games, by = "game_id") %>%
    mutate(half = if_else(game_id <= V1_LAST_GAME_ID, "first_half", "second_half"))
  stints <- pg %>%
    group_by(person_id, team) %>%
    summarise(player_name = last(player_name),
              first_game = min(game_id), last_game = max(game_id),
              first_date = min(game_date), last_date = max(game_date),
              n_games = n(),
              minutes_first_half = sum(minutes[half == "first_half"]),
              minutes_second_half = sum(minutes[half == "second_half"]),
              .groups = "drop") %>%
    group_by(person_id) %>%
    arrange(first_game, .by_group = TRUE) %>%
    mutate(stint_n = row_number(), n_stints = n()) %>%
    ungroup()
  stints
}

#' Trade flags per team, plus the list of moves
#'
#' A player is moved if he appears for 2+ teams in the regular season. For team T:
#' share_out = first-half minutes for T by players whose stint with T was followed by a
#' stint with another team, over T's first-half minutes; share_in = second-half minutes
#' for T by players whose stint with T was preceded by a stint with another team, over
#' T's second-half minutes. trade_flag = either share >= TRADE_FLAG_SHARE.
build_trade_flags <- function() {
  stints <- build_stints()
  teams <- load_table("team_games", "regular") %>% distinct(team) %>% pull(team) %>% sort()
  team_min <- stints %>% group_by(team) %>%
    summarise(team_min_first = sum(minutes_first_half),
              team_min_second = sum(minutes_second_half), .groups = "drop")
  moved <- stints %>% filter(n_stints > 1) %>%
    group_by(person_id) %>%
    mutate(left_team = stint_n < n_stints, arrived_team = stint_n > 1,
           prev_team = lag(team), prev_last_date = lag(last_date),
           next_team = lead(team)) %>%
    ungroup()

  flags <- tibble(team = teams) %>%
    left_join(team_min, by = "team") %>%
    left_join(moved %>% filter(left_team) %>% group_by(team) %>%
                summarise(min_out = sum(minutes_first_half),
                          n_out = n_distinct(person_id), .groups = "drop"), by = "team") %>%
    left_join(moved %>% filter(arrived_team) %>% group_by(team) %>%
                summarise(min_in = sum(minutes_second_half),
                          n_in = n_distinct(person_id), .groups = "drop"), by = "team") %>%
    mutate(across(c(min_out, n_out, min_in, n_in), ~ replace_na(.x, 0)),
           share_out = min_out / team_min_first,
           share_in = min_in / team_min_second,
           trade_flag = share_out >= TRADE_FLAG_SHARE | share_in >= TRADE_FLAG_SHARE)

  moves <- moved %>% filter(arrived_team) %>%
    transmute(person_id, player_name, from_team = prev_team, to_team = team,
              last_game_from = prev_last_date, first_game_to = first_date,
              games_with_to = n_games,
              minutes_to_first_half = minutes_first_half,
              minutes_to_second_half = minutes_second_half,
              around_deadline = (first_date >= DEADLINE_BAND[1] & first_date <= DEADLINE_BAND[2]) |
                (prev_last_date <= DEADLINE_DATE & first_date >= DEADLINE_DATE)) %>%
    arrange(first_game_to)

  names_out <- moved %>% filter(left_team) %>% group_by(team) %>%
    summarise(players_out = paste(player_name, collapse = "; "), .groups = "drop")
  names_in <- moved %>% filter(arrived_team) %>% group_by(team) %>%
    summarise(players_in = paste(player_name, collapse = "; "), .groups = "drop")
  flags <- flags %>% left_join(names_out, by = "team") %>% left_join(names_in, by = "team") %>%
    mutate(across(c(players_out, players_in), ~ replace_na(.x, ""))) %>%
    select(team, share_out, share_in, n_out, n_in, players_out, players_in, trade_flag)
  list(flags = flags, moves = moves)
}

run_block_b <- function() {
  tf <- build_trade_flags()
  dir.create(REREAD_DIR, recursive = TRUE, showWarnings = FALSE)
  write_csv(tf$flags %>% rename(minutes_share_out = share_out, minutes_share_in = share_in,
                                n_players_out = n_out, n_players_in = n_in),
            file.path(REREAD_DIR, "trade_flags.csv"))
  write_csv(tf$moves, file.path(REREAD_DIR, "player_moves.csv"))
  tf
}

if (sys.nframe() == 0) {
  tf <- run_block_b()
  print(tf$flags %>% select(-players_out, -players_in), n = 20)
  print(tf$moves, n = 40, width = 200)
}
