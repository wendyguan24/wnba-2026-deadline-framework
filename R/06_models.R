# 06_models.R
#
# Purpose: Fit the schedule-adjusted identity models. For each style metric,
#   metric ~ (1|team) + (1|opponent) in lme4. Extract team BLUPs (adjusted
#   identity) and ICC (stable identity vs. matchup noise). Signature
#   deliverable: raw rank vs. adjusted rank deltas. Ports the NCAA
#   Movement-vs-Gravity machinery directly.
#   See HANDOFF §5c.
#
#   ALSO fits the trajectory layer (new §5c-bis, AMENDMENT_01 Part 1): a
#   deadline decision is a bet on trajectory, not just current-state
#   identity, so trajectory is a required deadline-read column, not an
#   optional extra. Do not run this script until analysis/eda_midseason.Rmd
#   and output/eda_notes.md (hypotheses registry) exist — AMENDMENT_01 §2b.
#   Run the `analytics-reviewer` agent on this script's results before
#   proceeding to 07/08 — see PLAN.md.
#
# Inputs:  data/processed/team_game_features.rds, output/eda_notes.md
#   (hypotheses registry — H1, H2, H3, H-null; do not invent hypotheses
#   after seeing trajectory results)
# Outputs: data/processed/team_blups.rds, output/icc_table.csv,
#   data/processed/team_trajectories.rds (slopes, intervals, league trend,
#   improving/flat/declining classification per team per metric)

library(tidyverse)
library(lme4)

# Trajectory models run on this shortlist only (AMENDMENT_01 §1). Optional
# 5th metric and cut order documented in PLAN.md; never cut the deadline-read
# `trajectory` column itself — fall back to raw trends with a stated caveat
# first.
TRAJECTORY_METRICS <- c(
  "transition_share",              # H1
  "transition_pts_per_possession", # H1, efficiency side (cut first if time-constrained)
  "assisted_rate_of_fgm",          # H2
  "live_ball_tov_rate"             # H2
  # optional 5th: shot_making_residual (H3, from 07_expected_points.R) — GSV-relevant
)

# Hard boundary (AMENDMENT_01 §1, carried from HANDOFF guardrails): isolation
# trends are NOT measurable in the open data (no play-type tags) and must
# never be claimed from it. If used at all, iso trajectory comes only from
# Synergy date-filtered team exports, in case-study prose, quarantined per
# the Synergy rule — never in this script's output.

#' Fit a mixed-effects model for one style metric
#'
#' @param features tibble, team-game feature table
#' @param metric_name character, column name of the style metric
#' @return an lme4 model object (metric ~ (1|team) + (1|opponent))
fit_mixed_model <- function(features, metric_name) {
  stop("Not yet implemented — see HANDOFF §5c")
}

#' Extract team-level BLUPs (schedule-adjusted identity) from a fitted model
#'
#' @param model lme4 model object
#' @return tibble, one row per team, adjusted metric value
extract_blups <- function(model) {
  stop("Not yet implemented — see HANDOFF §5c")
}

#' Compute the intraclass correlation (ICC) for the team random effect
#'
#' @param model lme4 model object
#' @return numeric, ICC
compute_icc <- function(model) {
  stop("Not yet implemented — see HANDOFF §5c")
}

#' Compare raw (unadjusted) team rank to schedule-adjusted rank
#'
#' @param features tibble, raw team-game feature table
#' @param blups tibble, adjusted BLUPs
#' @return tibble, one row per team, raw_rank, adjusted_rank, delta
rank_deltas <- function(features, blups) {
  stop("Not yet implemented — see HANDOFF §5c")
}

# --- Trajectory layer (§5c-bis, AMENDMENT_01 Part 1) -----------------------

#' Fit the trajectory model for one metric on the TRAJECTORY_METRICS
#' shortlist: metric ~ game_index + (1 + game_index | team) + (1 | opponent).
#' `game_index` is each team's own game number (1..N), not calendar date, so
#' teams with unequal schedules are comparable. If the random-slope model
#' fails to converge (likely for some metrics at 23-26 games/team), fall
#' back to fixed game_index + random intercepts only (league trend + late-
#' season observed-minus-expected residuals per team), and record which
#' fallback fired.
#'
#' @param features tibble, team-game feature table with a game_index column
#' @param metric_name character, one of TRAJECTORY_METRICS
#' @return list(model = lme4 model object, fallback_used = logical)
fit_trajectory_model <- function(features, metric_name) {
  stop("Not yet implemented — see AMENDMENT_01 §1 (model form + fallback rule)")
}

#' Extract per-team trajectory slopes (random slope BLUPs) with uncertainty
#' intervals, and the fixed effect (league-wide trend, tests H1 at scale)
#'
#' @param model lme4 model object from fit_trajectory_model()
#' @return list(team_slopes = tibble(team, slope, ci_low, ci_high),
#'   league_trend = numeric)
extract_trajectory_slopes <- function(model) {
  stop("Not yet implemented — see AMENDMENT_01 §1")
}

#' Classify each team's trajectory as improving / flat / declining from its
#' slope sign and interval; footnote when the interval spans zero. Per-team
#' slopes are directional, not standalone claims — lean on the league-wide
#' fixed effect for strong claims (AMENDMENT_01 §1 "Reporting rules").
#'
#' @param team_slopes tibble from extract_trajectory_slopes()$team_slopes
#' @return tibble, adds columns trajectory ("improving"/"flat"/"declining")
#'   and interval_spans_zero (logical)
classify_trajectory <- function(team_slopes) {
  stop("Not yet implemented — see AMENDMENT_01 §1")
}

main <- function() {
  stop("Not yet implemented — see HANDOFF §5c and AMENDMENT_01 §1. Depends on 05_features.R output. Do not run before analysis/eda_midseason.Rmd + output/eda_notes.md exist.")
}

if (sys.nframe() == 0) {
  main()
}
