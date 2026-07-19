# 05_features.R
#
# Purpose: Build the team-game style feature table: pace (two estimates,
#   reconciled), 3PA rate, assisted rate (of FGM), transition share,
#   points-off-TOV share, second-chance share, paint FGM share, zone profile
#   shares (RA/paint/mid/corner3/ATB3), shot-descriptor mix (driving/pullup/
#   cutting/putback), FT rate, TOV rate. See HANDOFF §5b.
#
#   Formalizes the logic verified in analysis/eda_midseason.Rmd (the
#   AMENDMENT_01 §2a-2b EDA gate) and applies the five spec changes that
#   gate forced:
#     1. pace_poss (possession-table count) is the primary pace column;
#        pace_formula is a secondary cross-check only.
#     2. is_ot flag, since OT team-games have mechanically higher pace_poss.
#     3. garbage_time_poss_share column (flag, not exclude).
#     4. is_home column (joined from shotdetail HTM/VTM).
#     5. (R/06_models.R only, not this script) weight transition_pts_per_poss
#        fits by transition_poss.
#
# Inputs:  data/processed/pbp_events.rds, data/processed/possessions.rds,
#          data/raw/wnba_shotdetail_2026.csv (HTM/VTM home/away join only)
# Outputs: data/processed/team_game_features.rds — one row per team-game

library(tidyverse)

#' Each team's own chronological game number (1..N), not calendar date, plus
#' the game's timestamp (min timeActual across its events).
#'
#' @param pbp tibble, parsed pbp events
#' @param possessions tibble, possession table (used only for the team-game key)
#' @return tibble: gameId, team, game_index, game_time
compute_game_index <- function(pbp, possessions) {
  game_dates <- pbp %>%
    group_by(gameId) %>%
    summarise(game_time = min(timeActual, na.rm = TRUE), .groups = "drop")

  possessions %>%
    distinct(gameId, team) %>%
    left_join(game_dates, by = "gameId") %>%
    arrange(team, game_time) %>%
    group_by(team) %>%
    mutate(game_index = row_number()) %>%
    ungroup()
}

#' Compute pace via two methods and reconcile: possession-table count vs.
#' FGA + 0.44*FTA - OREB + TOV. Verified in the EDA gate: correlation 0.899,
#' mean absolute gap ~4.6 possessions/team-game. pace_poss is possession-
#' table-derived and already verified against final box scores, so it is the
#' primary figure; pace_formula is kept only as a secondary cross-check.
#'
#' @param possessions tibble
#' @param pbp tibble
#' @return tibble, one row per team-game, with both pace estimates
compute_pace <- function(possessions, pbp) {
  poss_real <- possessions %>% filter(outcome != "technical_ft")
  pace_poss_tbl <- poss_real %>%
    group_by(gameId, team) %>%
    summarise(pace_poss = n(), team_points = sum(points), .groups = "drop")

  fga <- pbp %>% filter(actionType %in% c("2pt", "3pt")) %>%
    group_by(gameId, team = teamTricode) %>% summarise(FGA = n(), .groups = "drop")
  fta <- pbp %>% filter(actionType == "freethrow") %>%
    group_by(gameId, team = teamTricode) %>% summarise(FTA = n(), .groups = "drop")
  oreb <- pbp %>% filter(actionType == "rebound", !is.na(teamTricode)) %>%
    group_by(gameId, team = teamTricode) %>%
    summarise(OREB = sum(subType == "offensive"), .groups = "drop")
  tov <- pbp %>% filter(actionType == "turnover") %>%
    group_by(gameId, team = teamTricode) %>% summarise(TOV = n(), .groups = "drop")

  pace_poss_tbl %>%
    left_join(fga, by = c("gameId", "team")) %>%
    left_join(fta, by = c("gameId", "team")) %>%
    left_join(oreb, by = c("gameId", "team")) %>%
    left_join(tov, by = c("gameId", "team")) %>%
    mutate(pace_formula = FGA + 0.44 * FTA - OREB + TOV)
}

#' Compute shot-zone profile shares (RA/paint/mid/corner3/ATB3) and
#' shot-descriptor mix (driving/pullup/cutting/putback) per team-game, plus
#' assisted rate and paint FGM share. All from cdn's own area/areaDetail/
#' descriptor/assistPersonId columns — never from shotdetail (see EDA gate
#' §2, the Toronto coverage resolution: shotdetail has zero Toronto rows,
#' but no feature here depends on it).
#'
#' @param pbp tibble
#' @return tibble, one row per team-game
compute_shot_profile <- function(pbp) {
  shots <- pbp %>% filter(actionType %in% c("2pt", "3pt"))

  shots %>%
    group_by(gameId, team = teamTricode) %>%
    summarise(
      FGA = n(), FGM = sum(shotResult == "Made"),
      FG3A = sum(actionType == "3pt"),
      assisted_FGM = sum(shotResult == "Made" & !is.na(assistPersonId)),
      paint_FGM = sum(shotResult == "Made" &
                         area %in% c("Restricted Area", "In The Paint (Non-RA)")),
      ra_n = sum(area == "Restricted Area"),
      paint_n = sum(area == "In The Paint (Non-RA)"),
      mid_n = sum(area == "Mid-Range"),
      corner3_n = sum(area %in% c("Left Corner 3", "Right Corner 3")),
      atb3_n = sum(area == "Above the Break 3"),
      driving_n = sum(str_detect(coalesce(descriptor, ""), "driving")),
      pullup_n = sum(str_detect(coalesce(descriptor, ""), "pullup")),
      cutting_n = sum(str_detect(coalesce(descriptor, ""), "cutting")),
      putback_n = sum(str_detect(coalesce(descriptor, ""), "putback")),
      .groups = "drop"
    ) %>%
    mutate(
      fg3a_rate = FG3A / FGA,
      assisted_rate = assisted_FGM / FGM,
      paint_fgm_share = paint_FGM / FGM,
      ra_share = ra_n / FGA, paint_share = paint_n / FGA, mid_share = mid_n / FGA,
      corner3_share = corner3_n / FGA, atb3_share = atb3_n / FGA,
      driving_share = driving_n / FGA, pullup_share = pullup_n / FGA,
      cutting_share = cutting_n / FGA, putback_share = putback_n / FGA
    ) %>%
    select(gameId, team, fg3a_rate, assisted_rate, paint_fgm_share,
           ra_share, paint_share, mid_share, corner3_share, atb3_share,
           driving_share, pullup_share, cutting_share, putback_share)
}

#' Compute context shares: transition, points-off-turnover, second-chance,
#' and the garbage-time possession share (AMENDMENT_01 §2c decision from the
#' EDA gate §6: flag, not exclude — every team-game carries the share so
#' downstream scripts can decide whether to condition on it).
#'
#' @param possessions tibble
#' @param pbp tibble, used only to look up the score margin at each
#'   possession's start event for the garbage-time flag
#' @return tibble, one row per team-game
compute_context_shares <- function(possessions, pbp) {
  poss_real <- possessions %>% filter(outcome != "technical_ft")

  margin_at_start <- pbp %>% select(gameId, start_event = orderNumber, scoreHome, scoreAway)
  poss_margin <- poss_real %>%
    left_join(margin_at_start, by = c("gameId", "start_event")) %>%
    mutate(garbage_time = period >= 4 & abs(scoreHome - scoreAway) >= 20)

  poss_margin %>%
    group_by(gameId, team) %>%
    summarise(
      transition_poss = sum(is_transition),
      transition_pts = sum(points[is_transition]),
      off_tov_pts = sum(points[is_off_turnover]),
      secondchance_pts = sum(points[is_2ndchance]),
      team_points = sum(points),
      pace_poss = n(),
      garbage_time_poss_share = mean(garbage_time, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      transition_share = transition_poss / pace_poss,
      transition_pts_per_poss = transition_pts / transition_poss,
      off_tov_share = off_tov_pts / team_points,
      secondchance_share = secondchance_pts / team_points
    ) %>%
    select(gameId, team, transition_poss, transition_share, transition_pts_per_poss,
           off_tov_share, secondchance_share, garbage_time_poss_share)
}

#' Compute rate stats: FT rate, TOV rate, live-ball TOV rate (turnovers with
#' a recorded steal — see AMENDMENT_01 §1 metric shortlist, H2).
#'
#' @param pbp tibble
#' @param pace_tbl tibble from compute_pace(), for the pace_poss denominator
#' @return tibble, one row per team-game
compute_rate_stats <- function(pbp, pace_tbl) {
  fga <- pbp %>% filter(actionType %in% c("2pt", "3pt")) %>%
    group_by(gameId, team = teamTricode) %>% summarise(FGA = n(), .groups = "drop")
  fta <- pbp %>% filter(actionType == "freethrow") %>%
    group_by(gameId, team = teamTricode) %>% summarise(FTA = n(), .groups = "drop")
  tov <- pbp %>% filter(actionType == "turnover") %>%
    group_by(gameId, team = teamTricode) %>%
    summarise(TOV = n(), live_ball_TOV = sum(!is.na(stealPersonId)), .groups = "drop")

  fga %>%
    left_join(fta, by = c("gameId", "team")) %>%
    left_join(tov, by = c("gameId", "team")) %>%
    left_join(pace_tbl %>% select(gameId, team, pace_poss), by = c("gameId", "team")) %>%
    mutate(
      ft_rate = FTA / FGA,
      tov_rate = TOV / pace_poss,
      live_ball_tov_rate = live_ball_TOV / pace_poss
    ) %>%
    select(gameId, team, ft_rate, tov_rate, live_ball_tov_rate)
}

#' Home/away and opponent, plus the OT flag (spec changes 2 and 4 from the
#' EDA gate). Home/away is joined from shotdetail's HTM/VTM columns, which
#' cover all 182 games including Toronto's (via the opponent's row) even
#' though shotdetail itself has zero Toronto shot rows.
#'
#' @param possessions tibble
#' @param pbp tibble
#' @param shotdetail_raw tibble, raw wnba_shotdetail_2026.csv
#' @return tibble: gameId, team, opponent, is_home, is_ot
compute_game_context_flags <- function(possessions, pbp, shotdetail_raw) {
  team_opponent <- possessions %>% distinct(gameId, team, opponent)

  home_away <- shotdetail_raw %>%
    distinct(GAME_ID, HTM, VTM) %>%
    distinct(GAME_ID, .keep_all = TRUE)

  ot_games <- pbp %>% filter(periodType == "OVERTIME") %>% distinct(gameId) %>% mutate(is_ot = TRUE)

  team_opponent %>%
    left_join(home_away, by = c("gameId" = "GAME_ID")) %>%
    mutate(is_home = team == HTM) %>%
    left_join(ot_games, by = "gameId") %>%
    mutate(is_ot = replace_na(is_ot, FALSE)) %>%
    select(gameId, team, opponent, is_home, is_ot)
}

#' Join all feature groups into the final team-game feature table.
#'
#' @param possessions tibble
#' @param pbp tibble
#' @param shotdetail_raw tibble, raw wnba_shotdetail_2026.csv (home/away join only)
#' @return tibble, one row per team-game, all HANDOFF §5b features plus the
#'   EDA-gate spec additions (is_ot, is_home, garbage_time_poss_share)
build_team_game_features <- function(possessions, pbp, shotdetail_raw) {
  game_index_tbl <- compute_game_index(pbp, possessions)
  pace_tbl <- compute_pace(possessions, pbp)
  shot_profile_tbl <- compute_shot_profile(pbp)
  context_tbl <- compute_context_shares(possessions, pbp)
  rate_tbl <- compute_rate_stats(pbp, pace_tbl)
  context_flags_tbl <- compute_game_context_flags(possessions, pbp, shotdetail_raw)

  game_index_tbl %>%
    left_join(context_flags_tbl, by = c("gameId", "team")) %>%
    left_join(pace_tbl %>% select(gameId, team, pace_poss, pace_formula, team_points),
               by = c("gameId", "team")) %>%
    left_join(shot_profile_tbl, by = c("gameId", "team")) %>%
    left_join(context_tbl, by = c("gameId", "team")) %>%
    left_join(rate_tbl, by = c("gameId", "team"))
}

main <- function() {
  pbp <- readRDS("data/processed/pbp_events.rds")
  possessions <- readRDS("data/processed/possessions.rds")
  shotdetail_raw <- read_csv("data/raw/wnba_shotdetail_2026.csv", show_col_types = FALSE)

  features <- build_team_game_features(possessions, pbp, shotdetail_raw)

  n_missing <- features %>%
    select(-game_time) %>%
    summarise(across(everything(), ~ sum(is.na(.)))) %>%
    pivot_longer(everything(), names_to = "col", values_to = "n_na") %>%
    filter(n_na > 0)
  if (nrow(n_missing) > 0) {
    warning("team_game_features has missing values in: ",
            paste(n_missing$col, collapse = ", "))
  }

  dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
  saveRDS(features, "data/processed/team_game_features.rds")
  message("Wrote data/processed/team_game_features.rds (", nrow(features), " team-games, ",
          n_distinct(features$gameId), " games)")
  invisible(features)
}

if (sys.nframe() == 0) {
  main()
}
