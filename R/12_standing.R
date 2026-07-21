# 12_standing.R
#
# Purpose: Standing/window layer -- a data-driven proxy for each team's
#   competitive window (buyer / bubble / seller), computed from game results
#   (win-loss record and point differential). This is the standing/window
#   layer added to the framework: it exists to CONDITION THE RECOMMENDATION
#   downstream (R/08_deadline_read.R, R/11_generation_gap.R), never the
#   diagnosis. Identity, generation, making, and trajectory (R/05-R/07, R/11's
#   gap decomposition) stay record-independent by design -- that is what lets
#   the framework claim it reads beyond the record. Standing/window enters
#   only at the recommendation step, downstream of this script.
#
#   Playoff-line assumption (stated explicitly, not derived): the WNBA takes
#   8 of 15 teams to the playoffs, so the 8th-ranked team by win_pct (ties
#   broken by season point differential) is used as the playoff cut line for
#   games_back_from_8th and for the window tiers below.
#
#   Window tier is a PROXY for front-office window, not a front-office
#   decision. It is a data-only read of the record; a real front office
#   overrides it with private information this framework cannot see
#   (ownership mandate, injury outlook, timeline preference, a rebuild
#   already underway despite a mediocre record). Treat window as a
#   data-driven default, not a verdict.
#
#     rank 1-5   -> "buyer"   comfortably in playoff position
#     rank 6-9   -> "bubble"  straddling the 8-seed line
#     rank 10-15 -> "seller"  out of the race
#
# Inputs:  data/processed/possessions.rds (possession_id, gameId, team,
#            opponent, points, ... -- see R/03_possessions.R). Summing
#            `points` by (gameId, team) gives each team's final game score;
#            this sums to the final box score exactly in all 364 team-games,
#            verified independently in R/04_reconcile.R / the test suite, not
#            re-derived tautologically here. Every gameId has exactly two
#            teams (checked below); the team with more points in a game wins
#            -- there are no ties in basketball.
# Outputs: output/standing.csv (team, wins, losses, win_pct, point_diff,
#            rank, games_back_from_8th, window); also printed to console.

library(tidyverse)

#' Compute each team's per-game score and win/loss from the possession-level
#' table.
#'
#' Sums `points` by (gameId, team) to get each team's final game score, then
#' derives each team's opponent score (the other team in the same gameId) and
#' win/loss. Asserts exactly two teams per gameId first.
#'
#' @param possessions tibble, data/processed/possessions.rds
#' @return tibble, one row per team-game: gameId, team, team_pts, opp_pts, win
build_game_scores <- function(possessions) {
  game_scores <- possessions %>%
    group_by(gameId, team) %>%
    summarise(team_pts = sum(points), .groups = "drop")

  teams_per_game <- game_scores %>% count(gameId)
  if (any(teams_per_game$n != 2)) {
    stop(
      "build_game_scores(): expected exactly 2 teams per gameId, found a ",
      "gameId with a different count -- check possessions.rds for a data issue."
    )
  }

  game_scores %>%
    group_by(gameId) %>%
    mutate(
      opp_pts = sum(team_pts) - team_pts,
      win = team_pts > opp_pts  # no ties in basketball
    ) %>%
    ungroup()
}

#' Build the per-team standing table: record, point differential, rank
#' (win_pct descending, ties broken by point_diff descending),
#' games_back_from_8th, and window tier.
#'
#' games_back_from_8th = ((W_8th - L_8th) - (W_team - L_team)) / 2, where the
#' 8th-ranked team (by the same rank order) is the playoff cut line (see file
#' header: WNBA takes 8 of 15 teams). Negative values mean a team sits ahead
#' of the cut line, by the standard "games back" convention.
#'
#' @param game_scores tibble, from build_game_scores()
#' @return tibble, team, wins, losses, win_pct, point_diff, rank,
#'   games_back_from_8th, window
build_standing <- function(game_scores) {
  standing <- game_scores %>%
    group_by(team) %>%
    summarise(
      wins = sum(win),
      losses = sum(!win),
      games = wins + losses,
      point_diff = sum(team_pts - opp_pts),
      .groups = "drop"
    ) %>%
    mutate(win_pct = wins / games) %>%
    arrange(desc(win_pct), desc(point_diff)) %>%
    mutate(rank = row_number())

  eighth <- standing %>% filter(rank == 8)
  if (nrow(eighth) != 1) {
    stop("build_standing(): expected exactly one rank-8 team (the playoff cut line).")
  }
  w8 <- eighth$wins
  l8 <- eighth$losses

  standing %>%
    mutate(
      games_back_from_8th = ((w8 - l8) - (wins - losses)) / 2,
      window = case_when(
        rank <= 5 ~ "buyer",    # comfortably in playoff position
        rank <= 9 ~ "bubble",   # straddling the 8-seed line
        TRUE      ~ "seller"    # out of the race
      )
    ) %>%
    select(team, wins, losses, win_pct, point_diff, rank, games_back_from_8th, window)
}

main <- function() {
  possessions <- readRDS("data/processed/possessions.rds")

  game_scores <- build_game_scores(possessions)
  standing <- build_standing(game_scores)

  write_csv(standing, "output/standing.csv")

  message("Standing / window table (rank 1-5 buyer, 6-9 bubble, 10-15 seller):")
  print(standing, n = Inf)
  message("Window distribution:")
  print(table(standing$window))

  invisible(standing)
}

if (sys.nframe() == 0) {
  main()
}
