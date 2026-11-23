# 00_config.R
#
# Purpose: single source of truth for the data pin, season, and paths used by
#   the offseason pipeline (R/01 to R/04b). Run scripts from the repo root, or
#   set PROJECT_ROOT before sourcing (tests/testthat/setup.R does this).
#   R/05 to R/14 still hard-code v1 paths and are not yet wired to this file.

# Pinned shufinskiy/nba_data commit (short hash 46488f0, 2026-11-06, regular
# season plus playoffs). Full SHA resolved from the upstream clone.
PINNED_COMMIT <- "46488f0f8e1cab58fc1256511ea808166a443a15"
PIN_SHORT <- "46488f0"
SEASON <- 2026L
RUN_TAG <- "full2026"

# v1 pin 773ce29 covered regular-season game IDs 1-182 (through 2026-07-16).
V1_CUTOFF_GAMES <- 182L

if (!exists("PROJECT_ROOT")) PROJECT_ROOT <- normalizePath(".")
if (!exists("proj_path", mode = "function")) {
  proj_path <- function(...) file.path(PROJECT_ROOT, ...)
}

RAW_DIR <- proj_path("data", "raw", PIN_SHORT)
PROCESSED_DIR <- proj_path("data", "processed", RUN_TAG)
OUTPUT_DIR <- proj_path("output", "offseason")

# Dataset name suffix per season type
SEASON_TYPES <- c(regular = "", playoffs = "_po")
SOURCES <- c("cdnnba", "nbastats", "shotdetail")

#' Dataset name, e.g. wnba_cdnnba_2026 (regular) or wnba_cdnnba_po_2026
dataset_name <- function(source, season_type) {
  sprintf("wnba_%s%s_%d", source, SEASON_TYPES[[season_type]], SEASON)
}

#' Path to the extracted raw CSV for a source and season type
raw_csv <- function(source, season_type) {
  file.path(RAW_DIR, paste0(dataset_name(source, season_type), ".csv"))
}

# External validator (wehoop/ESPN via sportsdataverse-data releases). Used only by
# R/04c_validate_external.R; never merged into the analysis tables or models.
WEHOOP_DIR <- proj_path("data", "raw", "wehoop")
WEHOOP_URLS <- c(
  player_box = "https://github.com/sportsdataverse/sportsdataverse-data/releases/download/espn_wnba_player_boxscores/player_box_2026.parquet",
  team_box = "https://github.com/sportsdataverse/sportsdataverse-data/releases/download/espn_wnba_team_boxscores/team_box_2026.parquet",
  schedule = "https://github.com/sportsdataverse/sportsdataverse-data/releases/download/espn_wnba_schedules/wnba_schedule_2026.parquet"
)
