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
#   gameId, orderNumber, with parsed_clock_seconds, qualifier flag columns
#   (is_fastbreak, is_fromturnover, is_2ndchance, is_pointsinthepaint), and
#   team_full_name added.

library(tidyverse)
library(hms)
library(lubridate)

# Full 15-team tricode map. LAS = Los Angeles Sparks, LVA = Las Vegas Aces —
# never swap. See CLAUDE.md and HANDOFF §4. team_full_name matches
# shotdetail's TEAM_NAME format exactly, so it doubles as a join key.
TEAM_TRICODE_MAP <- tibble::tribble(
  ~teamTricode, ~team_full_name,
  "ATL", "Atlanta Dream",
  "CHI", "Chicago Sky",
  "CON", "Connecticut Sun",
  "DAL", "Dallas Wings",
  "GSV", "Golden State Valkyries",
  "IND", "Indiana Fever",
  "LAS", "Los Angeles Sparks",
  "LVA", "Las Vegas Aces",
  "MIN", "Minnesota Lynx",
  "NYL", "New York Liberty",
  "PDX", "Portland Fire",
  "PHX", "Phoenix Mercury",
  "SEA", "Seattle Storm",
  "TOR", "Toronto Tempo",
  "WAS", "Washington Mystics"
)

#' Parse an ISO-8601-duration clock string (e.g. "PT09M57.00S") to seconds.
#' Verified against real data 2026-07-18: WNBA quarters run PT10M00.00S (not
#' PT12M, the NBA convention), OT periods run PT05M00.00S, clock is never NA.
#'
#' @param clock_str character vector
#' @return numeric vector, seconds remaining in the period
parse_clock <- function(clock_str) {
  m <- str_match(clock_str, "^PT(\\d+)M(\\d+(?:\\.\\d+)?)S$")
  minutes <- as.numeric(m[, 2])
  seconds <- as.numeric(m[, 3])
  bad <- is.na(minutes) & !is.na(clock_str)
  if (any(bad)) {
    stop("parse_clock: unrecognized clock format: ",
         paste(unique(clock_str[bad]), collapse = ", "))
  }
  minutes * 60 + seconds
}

#' Expand the comma-separated, order-unstable `qualifiers` column into
#' boolean flag columns. Uses str_detect, never exact string match, since
#' tag order varies (verified: "fastbreak, pointsinthepaint" vs
#' "pointsinthepaint, fastbreak" both occur).
#'
#' @param qualifiers_col character vector
#' @return tibble with columns is_fastbreak, is_fromturnover, is_2ndchance,
#'   is_pointsinthepaint
expand_qualifiers <- function(qualifiers_col) {
  q <- replace_na(qualifiers_col, "")
  tibble(
    is_fastbreak = str_detect(q, "fastbreak"),
    is_fromturnover = str_detect(q, "fromturnover"),
    is_2ndchance = str_detect(q, "2ndchance"),
    is_pointsinthepaint = str_detect(q, "pointsinthepaint")
  )
}

#' Apply the full 15-team tricode-to-full-name mapping. Errors loudly on any
#' unmapped tricode rather than silently dropping/NA-ing it.
#'
#' @param pbp tibble with a teamTricode column
#' @return tibble with team_full_name added
apply_team_mapping <- function(pbp) {
  unmapped <- pbp %>%
    filter(!is.na(teamTricode), !(teamTricode %in% TEAM_TRICODE_MAP$teamTricode)) %>%
    distinct(teamTricode) %>%
    pull(teamTricode)
  if (length(unmapped) > 0) {
    stop("apply_team_mapping: unmapped tricode(s): ", paste(unmapped, collapse = ", "))
  }
  pbp %>% left_join(TEAM_TRICODE_MAP, by = "teamTricode")
}

main <- function() {
  cdn <- read_csv("data/raw/wnba_cdnnba_2026.csv", show_col_types = FALSE, guess_max = 100000)

  cdn <- cdn %>%
    mutate(parsed_clock_seconds = parse_clock(clock)) %>%
    bind_cols(expand_qualifiers(cdn$qualifiers))

  cdn <- apply_team_mapping(cdn)
  cdn <- cdn %>% arrange(gameId, orderNumber)

  dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
  saveRDS(cdn, "data/processed/pbp_events.rds")
  message("Wrote data/processed/pbp_events.rds (", nrow(cdn), " rows, ",
          n_distinct(cdn$gameId), " games)")
  invisible(cdn)
}

if (sys.nframe() == 0) {
  main()
}
