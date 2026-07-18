# 04_reconcile.R
#
# Purpose: Validate the parsed data before any feature or model is built.
#   (1) Reconcile cdn vs nbastats v2 per-game FGA/FGM/AST/3PA counts (the
#       analog of the NCAA project's wehoop reconciliation and its documented
#       2.5-FGM gap — document deltas the same way, don't hide them).
#   (2) Validate the HANDOFF §4 baseline sanity table reproduces within
#       rounding (8 teams: GSV, NYL, PDX, TOR, MIN, WAS, CON, ATL).
#   (3) Confirm/refute the known shotdetail-Toronto coverage gap (see README
#       "Known issue to verify on first download") before any expected-points
#       feature is trusted for Toronto.
#   Per CLAUDE.md: scripts 05+ do not get written until tests in
#   tests/testthat/ pass against this script's output.
#
# Inputs:  data/processed/pbp_events.rds, data/raw/wnba_nbastats_2026.csv,
#          data/raw/wnba_shotdetail_2026.csv
# Outputs: output/reconciliation_report.md

library(tidyverse)

#' Compute per-team-game FGA/FGM/AST/3PA from the parsed cdn events
#'
#' @param pbp tibble, parsed PBP events
#' @return tibble, one row per team-game
compute_team_game_counts_cdn <- function(pbp) {
  stop("Not yet implemented — see HANDOFF §4")
}

#' Compute the same per-team-game counts from nbastats v2 for cross-check
#'
#' @param v2_raw tibble, raw nbastats v2 CSV
#' @return tibble, one row per team-game
compute_team_game_counts_v2 <- function(v2_raw) {
  stop("Not yet implemented — see HANDOFF §4")
}

#' Compare cdn vs v2 counts and summarize the delta distribution
#'
#' @param cdn_counts tibble
#' @param v2_counts tibble
#' @return tibble of per-team-game deltas, plus a summary
reconcile_cdn_v2 <- function(cdn_counts, v2_counts) {
  stop("Not yet implemented — see HANDOFF §4")
}

#' Reproduce the HANDOFF §4 baseline sanity table from parsed data
#'
#' @param pbp tibble
#' @return tibble, comparable to the HANDOFF §4 table, with deltas
validate_baseline_table <- function(pbp) {
  stop("Not yet implemented — see HANDOFF §4")
}

#' Check whether shotdetail has full 15-team coverage, or is missing Toronto
#' as found in a prior exploratory pass (see README)
#'
#' @param shotdetail_raw tibble, raw shotdetail CSV
#' @return tibble/list summarizing per-team row counts and any missing teams
check_shotdetail_coverage <- function(shotdetail_raw) {
  stop("Not yet implemented — see HANDOFF §4, README 'Known issue'")
}

main <- function() {
  stop("Not yet implemented — see HANDOFF §4. Depends on 02_parse_pbp.R output. Write output/reconciliation_report.md and stop for review before 05_features.R.")
}

if (sys.nframe() == 0) {
  main()
}
