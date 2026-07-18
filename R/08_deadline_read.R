# 08_deadline_read.R
#
# Purpose: Build the deadline-read synthesis table — the core deliverable.
#   Per team, one row: adjusted identity summary, generation percentile,
#   making percentile, schedule note -> which lever (acquire / adjust /
#   hold). See HANDOFF §5e.
#
# Inputs:  data/processed/team_blups.rds,
#          data/processed/team_generation_making.rds
# Outputs: output/deadline_read.csv, output/deadline_read.md

library(tidyverse)

#' Classify a team's deadline lever from its generation/making percentiles
#' and adjusted-identity profile
#'
#' @param generation_pctile numeric
#' @param making_pctile numeric
#' @param identity_summary character or list
#' @return character, one of "acquire", "adjust", "hold"
classify_lever <- function(generation_pctile, making_pctile, identity_summary) {
  stop("Not yet implemented — see HANDOFF §5e")
}

#' Build the full deadline-read table, one row per team
#'
#' @param team_blups tibble
#' @param team_generation_making tibble
#' @return tibble, one row per team: identity summary, generation %ile,
#'   making %ile, schedule note, lever
build_deadline_read <- function(team_blups, team_generation_making) {
  stop("Not yet implemented — see HANDOFF §5e")
}

main <- function() {
  stop("Not yet implemented — see HANDOFF §5e. Depends on 06_models.R and 07_expected_points.R output.")
}

if (sys.nframe() == 0) {
  main()
}
