# 08_deadline_read.R
#
# Purpose: Build the deadline-read synthesis table — the core deliverable.
#   Per team, one row: adjusted identity summary, generation percentile,
#   making percentile, trajectory, schedule note -> which lever (acquire /
#   adjust / hold). See HANDOFF §5e.
#
#   Trajectory column (AMENDMENT_01 §1, new §5c-bis): improving / flat /
#   declining, assigned in 06_models.R from the trajectory slope sign and
#   interval, footnoted here when the interval spans zero. This column is
#   required, not optional — if the team_trajectories input is unavailable,
#   fall back to raw trends with a stated caveat rather than dropping the
#   column (see PLAN.md cut order). Run the `gm-agent` review (see
#   .claude/agents/gm-agent.md) on this table the moment it exists, before
#   any prose is written around it — it explicitly checks "is trajectory
#   doing honest work" (a hold justified by an improving trend is a real
#   bet; flag any trajectory call where the uncertainty note contradicts the
#   confidence of the lever call).
#
# Inputs:  data/processed/team_blups.rds,
#          data/processed/team_generation_making.rds,
#          data/processed/team_trajectories.rds (from 06_models.R:
#            extract_trajectory_slopes() + classify_trajectory())
# Outputs: output/deadline_read.csv, output/deadline_read.md

library(tidyverse)

#' Classify a team's deadline lever from its generation/making percentiles
#' and adjusted-identity profile. Trajectory is reported alongside the lever
#' (see build_deadline_read()) but does not change this function's inputs —
#' the lever call should stay a generation/making-driven position, with
#' trajectory used in the surrounding prose to say whether a "hold" is a bet
#' on an improving trend or a bet on stability. Keep the two legible as
#' separate claims; the gm-agent review will flag it if they blur.
#'
#' @param generation_pctile numeric
#' @param making_pctile numeric
#' @param identity_summary character or list
#' @return character, one of "acquire", "adjust", "hold"
classify_lever <- function(generation_pctile, making_pctile, identity_summary) {
  stop("Not yet implemented — see HANDOFF §5e")
}

#' Format a team's trajectory value for the deadline-read table, with a
#' footnote marker when its interval spans zero (AMENDMENT_01 §1)
#'
#' @param trajectory character, one of "improving"/"flat"/"declining"
#' @param interval_spans_zero logical
#' @return character, e.g. "improving" or "improving*" plus a footnote text
format_trajectory_column <- function(trajectory, interval_spans_zero) {
  stop("Not yet implemented — see AMENDMENT_01 §1")
}

#' Build the full deadline-read table, one row per team
#'
#' @param team_blups tibble
#' @param team_generation_making tibble
#' @param team_trajectories tibble, from 06_models.R (team, trajectory,
#'   interval_spans_zero, per TRAJECTORY_METRICS metric)
#' @return tibble, one row per team: identity summary, generation %ile,
#'   making %ile, trajectory (+ footnote flag), schedule note, lever
build_deadline_read <- function(team_blups, team_generation_making, team_trajectories) {
  stop("Not yet implemented — see HANDOFF §5e, AMENDMENT_01 §1")
}

main <- function() {
  stop("Not yet implemented — see HANDOFF §5e, AMENDMENT_01 §1. Depends on 06_models.R (incl. trajectory extension) and 07_expected_points.R output. Run gm-agent on the result before writing prose.")
}

if (sys.nframe() == 0) {
  main()
}
