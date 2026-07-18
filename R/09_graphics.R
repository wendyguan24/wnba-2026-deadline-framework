# 09_graphics.R
#
# Purpose: Publication charts for the writeup: schedule-adjusted identity
#   map (raw vs. adjusted rank deltas), shot generation vs. shot making
#   scatter (the GSV outlier storyline), and any deadline-read supporting
#   visuals. See HANDOFF §5c, §5d, §5e.
#
# Inputs:  data/processed/team_blups.rds,
#          data/processed/team_generation_making.rds,
#          output/deadline_read.csv
# Outputs: output/*.png (or .svg)

library(tidyverse)

#' Shared WHoopsLab plotting theme
#'
#' @return a ggplot2 theme object
theme_whoopslab <- function() {
  stop("Not yet implemented — see HANDOFF §5c/§5e")
}

#' Raw-rank vs. adjusted-rank identity map for one or more style metrics
#'
#' @param team_blups tibble
#' @param features tibble, raw (unadjusted) team-game features
#' @return a ggplot object
plot_identity_map <- function(team_blups, features) {
  stop("Not yet implemented — see HANDOFF §5c")
}

#' Shot generation vs. shot making scatter, teams labeled, GSV highlighted
#'
#' @param team_generation_making tibble
#' @return a ggplot object
plot_generation_vs_making <- function(team_generation_making) {
  stop("Not yet implemented — see HANDOFF §5d")
}

main <- function() {
  stop("Not yet implemented — see HANDOFF §5c, §5d, §5e. Depends on 06-08 output.")
}

if (sys.nframe() == 0) {
  main()
}
