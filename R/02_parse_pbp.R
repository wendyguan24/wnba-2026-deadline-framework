# 02_parse_pbp.R
#
# Purpose: Parse the raw cdn play-by-play feed into a clean, ordered event
#   table: parse `clock` (ISO-8601 duration) to seconds, expand `qualifiers`
#   into boolean flags (order-independent), and apply the LAS/LVA tricode
#   mapping so teams are never silently swapped.
#   See HANDOFF §4 (cdn PBP section, "Tricode trap").
#
# Inputs:  data/raw/wnba_cdnnba_2026.csv
# Outputs: data/processed/pbp_events.rds — one row per PBP event, ordered by
#   gameId, orderNumber, with parsed_clock_seconds and qualifier flag columns
#   (is_fastbreak, is_fromturnover, is_2ndchance, is_pointsinthepaint) added.

library(tidyverse)
library(hms)
library(lubridate)

# LAS = Los Angeles Sparks, LVA = Las Vegas Aces. Never swap. See CLAUDE.md
# and HANDOFF §4.
TEAM_TRICODE_MAP <- tibble::tribble(
  ~teamTricode, ~team_city,
  "LAS", "Los Angeles",
  "LVA", "Las Vegas"
  # remaining 13 teams to be added when implemented
)

#' Parse an ISO-8601-duration clock string (e.g. "PT09M57.00S") to seconds
#'
#' @param clock_str character vector
#' @return numeric vector, seconds remaining in the period
parse_clock <- function(clock_str) {
  stop("Not yet implemented — see HANDOFF §4")
}

#' Expand the comma-separated, order-unstable `qualifiers` column into
#' boolean flag columns. Must use str_detect, never exact string match.
#'
#' @param qualifiers_col character vector
#' @return tibble with columns is_fastbreak, is_fromturnover, is_2ndchance,
#'   is_pointsinthepaint
expand_qualifiers <- function(qualifiers_col) {
  stop("Not yet implemented — see HANDOFF §4")
}

#' Apply the LAS/LVA (and full 15-team) tricode-to-city mapping
#'
#' @param pbp tibble with a teamTricode column
#' @return tibble with team_city added
apply_team_mapping <- function(pbp) {
  stop("Not yet implemented — see HANDOFF §4, CLAUDE.md tricode trap")
}

main <- function() {
  stop("Not yet implemented — see HANDOFF §4. Depends on 01_download.R output.")
}

if (sys.nframe() == 0) {
  main()
}
