# 05_features.R
#
# Purpose: Build the team-game style feature table: pace (two estimates,
#   reconciled), 3PA rate, assisted rate (of FGM), transition share,
#   points-off-TOV share, second-chance share, paint FGM share, zone profile
#   shares (RA/paint/mid/corner3/ATB3), shot-descriptor mix (driving/pullup/
#   cutting/putback), FT rate, TOV rate.
#   See HANDOFF §5b. Do not write this script until reconciliation tests
#   (04_reconcile.R + tests/testthat) pass — CLAUDE.md "Validation before
#   features."
#
# Inputs:  data/processed/pbp_events.rds, data/processed/possessions.rds
# Outputs: data/processed/team_game_features.rds — one row per team-game

library(tidyverse)

#' Compute pace via two methods and reconcile: possession-table count vs.
#' FGA + 0.44*FTA - OREB + TOV. Validate agreement before quoting either.
#'
#' @param possessions tibble
#' @param pbp tibble
#' @return tibble, one row per team-game, with both pace estimates
compute_pace <- function(possessions, pbp) {
  stop("Not yet implemented — see HANDOFF §5b")
}

#' Compute shot-zone profile shares (RA/paint/mid/corner3/ATB3) and
#' shot-descriptor mix (driving/pullup/cutting/putback) per team-game
#'
#' @param pbp tibble
#' @return tibble, one row per team-game
compute_shot_profile <- function(pbp) {
  stop("Not yet implemented — see HANDOFF §5b")
}

#' Compute context shares: transition, points-off-turnover, second-chance
#'
#' @param pbp tibble
#' @return tibble, one row per team-game
compute_context_shares <- function(pbp) {
  stop("Not yet implemented — see HANDOFF §5b")
}

#' Compute rate stats: assisted rate (of FGM), 3PA rate, FT rate, TOV rate
#'
#' @param pbp tibble
#' @return tibble, one row per team-game
compute_rate_stats <- function(pbp) {
  stop("Not yet implemented — see HANDOFF §5b")
}

#' Join all feature groups into the final team-game feature table
#'
#' @param possessions tibble
#' @param pbp tibble
#' @return tibble, one row per team-game, all HANDOFF §5b features
build_team_game_features <- function(possessions, pbp) {
  stop("Not yet implemented — see HANDOFF §5b")
}

main <- function() {
  stop("Not yet implemented — see HANDOFF §5b. Do not run before reconciliation tests pass.")
}

if (sys.nframe() == 0) {
  main()
}
