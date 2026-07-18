# 07_expected_points.R
#
# Purpose: Build a stratified expected-points baseline (NOT a trained model —
#   a trained xPTS model is explicitly out of scope this cycle, see HANDOFF
#   §6 cut list). League-average points per shot by zone x shot class x
#   context (transition/halfcourt/second-chance), computed from 2026 data (or
#   2024-25 historicals as priors, analyst's choice — state which was used).
#   Then per team: shot generation (expected PTS/100 given shot diet) vs.
#   shot making (actual - expected PTS/100).
#   See HANDOFF §5d. Methodology note must call this a "stratified
#   expected-points baseline (qSQ-lite)," never a "shot-quality model."
#
# Inputs:  data/raw/wnba_shotdetail_2026.csv (or cdn x/y + area/areaDetail —
#            see README "Known issue": shotdetail may be missing Toronto;
#            if confirmed, Toronto must use cdn-derived geometry instead),
#          data/processed/possessions.rds
# Outputs: data/processed/expected_points_baseline.rds,
#          data/processed/team_generation_making.rds

library(tidyverse)

#' Build the league-average points-per-shot baseline stratified by
#' zone x shot class x context
#'
#' @param shots tibble, shot-level data with zone, shot class, context flags
#' @return tibble, one row per (zone, shot_class, context) stratum, with
#'   league-average points per shot
build_xpts_table <- function(shots) {
  stop("Not yet implemented — see HANDOFF §5d")
}

#' Compute each team's shot generation: expected PTS/100 possessions given
#' their actual shot diet (process quality)
#'
#' @param shots tibble, team's shots joined to xpts_table
#' @param possessions tibble
#' @return tibble, one row per team, expected_pts_per_100
compute_shot_generation <- function(shots, xpts_table, possessions) {
  stop("Not yet implemented — see HANDOFF §5d")
}

#' Compute each team's shot making: actual - expected PTS/100
#'
#' @param shots tibble
#' @param xpts_table tibble
#' @param possessions tibble
#' @return tibble, one row per team, actual_pts_per_100, expected_pts_per_100,
#'   shot_making_delta
compute_shot_making <- function(shots, xpts_table, possessions) {
  stop("Not yet implemented — see HANDOFF §5d")
}

main <- function() {
  stop("Not yet implemented — see HANDOFF §5d. Depends on 03_possessions.R and 04_reconcile.R's shotdetail-coverage finding.")
}

if (sys.nframe() == 0) {
  main()
}
