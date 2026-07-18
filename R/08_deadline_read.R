# 08_deadline_read.R
#
# Purpose: Build the deadline-read synthesis table — the core deliverable.
#   Per team, one row: adjusted identity summary, generation percentile,
#   making percentile, trajectory, cap_context, schedule note -> which lever
#   (acquire / adjust / hold, feasibility-conditioned). See HANDOFF §5e,
#   AMENDMENT_01 §1 (trajectory), AMENDMENT_02 §3b (cap_context + lever
#   conditioning).
#
#   Trajectory column (AMENDMENT_01 §1, new §5c-bis): improving / flat /
#   declining, assigned in 06_models.R from the trajectory slope sign and
#   interval, footnoted here when the interval spans zero. This column is
#   required, not optional — if the team_trajectories input is unavailable,
#   fall back to raw trends with a stated caveat rather than dropping the
#   column (see PLAN.md cut order).
#
#   cap_context column (AMENDMENT_02 §3b): room / tight / capped, read
#   directly from data/reference/cap_context_2026.csv (hand-curated by
#   Wendy, not scripted — see data/reference/README.md). This column is
#   never cut (PLAN.md cut order), same as trajectory.
#
#   Lever conditioning rule (AMENDMENT_02 §3b): the lever call is never
#   presented context-free. An "acquire" read paired with a "capped"
#   cap_context becomes "acquire (constrained: requires salary out)" — or
#   downgrades to adjust/hold with the constraint stated in prose. The
#   framework must never recommend a move the cap forbids without naming the
#   constraint. See condition_lever_on_cap() below.
#
#   Run the `gm-agent` review (see .claude/agents/gm-agent.md) on this table
#   the moment it exists, before any prose is written around it — it checks
#   both "is trajectory doing honest work" (a hold justified by an improving
#   trend is a real bet; flag any trajectory call where the uncertainty note
#   contradicts the confidence of the lever call) and, per AMENDMENT_02 §4,
#   that every acquire read is conditioned on cap context and that no cap or
#   CBA mechanic is stated without attribution.
#
# Inputs:  data/processed/team_blups.rds,
#          data/processed/team_generation_making.rds,
#          data/processed/team_trajectories.rds (from 06_models.R:
#            extract_trajectory_slopes() + classify_trajectory()),
#          data/reference/cap_context_2026.csv (hand-curated, tracked in
#            git, NOT gitignored — see data/reference/README.md)
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

#' Load the hand-curated cap-context reference table
#'
#' @param path character, defaults to data/reference/cap_context_2026.csv
#' @return tibble: team, committed_salary_est, cap_room_est, expiring_count,
#'   max_supermax_count, flexibility_tier (room/tight/capped), source, as_of_date
load_cap_context <- function(path = "data/reference/cap_context_2026.csv") {
  stop("Not yet implemented — see AMENDMENT_02 §3a. Requires Wendy's manual entry into data/reference/cap_context_2026.csv first (Jul 23 block, PLAN.md).")
}

#' Condition a raw generation/making-driven lever call on cap context
#' (AMENDMENT_02 §3b). An "acquire" call paired with a "capped" flexibility
#' tier is never presented unconditioned — it becomes constrained, or
#' downgrades. This is the mechanism that keeps the framework from
#' recommending a move the cap forbids.
#'
#' @param lever character, raw lever from classify_lever() ("acquire"/"adjust"/"hold")
#' @param flexibility_tier character, one of "room"/"tight"/"capped"
#' @return character, the feasibility-conditioned lever string, e.g.
#'   "acquire (constrained: requires salary out)"
condition_lever_on_cap <- function(lever, flexibility_tier) {
  stop("Not yet implemented — see AMENDMENT_02 §3b")
}

#' Build the full deadline-read table, one row per team
#'
#' @param team_blups tibble
#' @param team_generation_making tibble
#' @param team_trajectories tibble, from 06_models.R (team, trajectory,
#'   interval_spans_zero, per TRAJECTORY_METRICS metric)
#' @param cap_context tibble, from load_cap_context()
#' @return tibble, one row per team: identity summary, generation %ile,
#'   making %ile, trajectory (+ footnote flag), cap_context, schedule note,
#'   lever (feasibility-conditioned via condition_lever_on_cap())
build_deadline_read <- function(team_blups, team_generation_making, team_trajectories, cap_context) {
  stop("Not yet implemented — see HANDOFF §5e, AMENDMENT_01 §1, AMENDMENT_02 §3b")
}

main <- function() {
  stop("Not yet implemented — see HANDOFF §5e, AMENDMENT_01 §1, AMENDMENT_02 §3b. Depends on 06_models.R (incl. trajectory extension), 07_expected_points.R output, and data/reference/cap_context_2026.csv (Wendy's manual entry — see data/reference/README.md). Run gm-agent on the result before writing prose.")
}

if (sys.nframe() == 0) {
  main()
}
