# 15_wehoop_download.R
#
# Purpose: Download full-season 2026 WNBA data via the wehoop package
#   (sportsdataverse). This script pulls from two pipelines:
#     1. ESPN-sourced bulk data (PBP, box scores, rosters, schedule)
#     2. WNBA Stats API-sourced bulk data (shots, possessions, game logs,
#        leaguedash cubes, hustle stats)
#
#   All data is saved as CSV to data/wehoop/ for downstream analysis.
#   Run this script LOCALLY -- it requires internet access to ESPN and
#   stats.wnba.com endpoints, plus CRAN packages.
#
# Inputs:  none (pulls from sportsdataverse CDN + ESPN + stats.wnba.com)
# Outputs: data/wehoop/*.csv (see file list below)
#          data/wehoop/wehoop_manifest.txt
#
# Requirements:
#   install.packages("wehoop")       # from CRAN (v3.0.0+)
#   install.packages("tidyverse")    # for data wrangling
#   install.packages("glmnet")       # for RAPM (optional)
#
# Usage:
#   Rscript R/15_wehoop_download.R              # 2026 season (default)
#   Rscript R/15_wehoop_download.R --season 2025  # different season

SEASON <- 2026L

# ---------------------------------------------------------------------------
# Parse CLI args
# ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if ("--season" %in% args) {
  idx <- which(args == "--season")
  if (idx < length(args)) {
    SEASON <- as.integer(args[idx + 1L])
  }
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(wehoop)
  library(dplyr)
  library(readr)
})

DEST_DIR <- file.path("data", "wehoop")
dir.create(DEST_DIR, recursive = TRUE, showWarnings = FALSE)

manifest_lines <- c(

  sprintf("wehoop data download manifest -- season %d", SEASON),
  sprintf("Downloaded (UTC): %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
  sprintf("wehoop version: %s", packageVersion("wehoop")),
  ""
)

safe_write <- function(df, name) {
  path <- file.path(DEST_DIR, paste0(name, ".csv"))
  readr::write_csv(df, path)
  nr <- nrow(df)
  nc <- ncol(df)
  msg <- sprintf("  %s: %d rows x %d cols", name, nr, nc)
  message(msg)
  manifest_lines <<- c(manifest_lines, msg)
  invisible(path)
}

# =========================================================================
# PART 1: ESPN-sourced bulk loaders (sportsdataverse-data releases)
# =========================================================================
message("\n=== ESPN-sourced bulk data ===\n")

# 1a. Play-by-play (coordinate_x, coordinate_y, type_text, scoring_play)
message("Loading ESPN PBP...")
espn_pbp <- tryCatch(load_wnba_pbp(seasons = SEASON), error = function(e) {
  message("  WARN: ESPN PBP failed: ", conditionMessage(e))
  NULL
})
if (!is.null(espn_pbp)) safe_write(espn_pbp, "espn_pbp")

# 1b. Player box scores
message("Loading ESPN player box scores...")
espn_player_box <- tryCatch(load_wnba_player_box(seasons = SEASON), error = function(e) {
  message("  WARN: ESPN player box failed: ", conditionMessage(e))
  NULL
})
if (!is.null(espn_player_box)) safe_write(espn_player_box, "espn_player_box")

# 1c. Team box scores
message("Loading ESPN team box scores...")
espn_team_box <- tryCatch(load_wnba_team_box(seasons = SEASON), error = function(e) {
  message("  WARN: ESPN team box failed: ", conditionMessage(e))
  NULL
})
if (!is.null(espn_team_box)) safe_write(espn_team_box, "espn_team_box")

# 1d. Schedule
message("Loading ESPN schedule...")
espn_schedule <- tryCatch(load_wnba_schedule(seasons = SEASON), error = function(e) {
  message("  WARN: ESPN schedule failed: ", conditionMessage(e))
  NULL
})
if (!is.null(espn_schedule)) safe_write(espn_schedule, "espn_schedule")

# 1e. Rosters
message("Loading ESPN rosters...")
espn_rosters <- tryCatch(load_wnba_rosters(seasons = SEASON), error = function(e) {
  message("  WARN: ESPN rosters failed: ", conditionMessage(e))
  NULL
})
if (!is.null(espn_rosters)) safe_write(espn_rosters, "espn_rosters")

# 1f. Game rosters (per-game: starter flag, DNP, etc.)
message("Loading ESPN game rosters...")
espn_game_rosters <- tryCatch(load_wnba_game_rosters(seasons = SEASON), error = function(e) {
  message("  WARN: ESPN game rosters failed: ", conditionMessage(e))
  NULL
})
if (!is.null(espn_game_rosters)) safe_write(espn_game_rosters, "espn_game_rosters")

# 1g. Player core (bio: height, weight, position, college)
message("Loading ESPN player core...")
espn_player_core <- tryCatch(load_wnba_player_core(seasons = SEASON), error = function(e) {
  message("  WARN: ESPN player core failed: ", conditionMessage(e))
  NULL
})
if (!is.null(espn_player_core)) safe_write(espn_player_core, "espn_player_core")

# 1h. Season-level player stats
message("Loading ESPN player stats...")
espn_player_stats <- tryCatch(load_wnba_player_stats(seasons = SEASON), error = function(e) {
  message("  WARN: ESPN player stats failed: ", conditionMessage(e))
  NULL
})
if (!is.null(espn_player_stats)) safe_write(espn_player_stats, "espn_player_stats")

# 1i. Season-level team stats
message("Loading ESPN team stats...")
espn_team_stats <- tryCatch(load_wnba_team_stats(seasons = SEASON), error = function(e) {
  message("  WARN: ESPN team stats failed: ", conditionMessage(e))
  NULL
})
if (!is.null(espn_team_stats)) safe_write(espn_team_stats, "espn_team_stats")

# 1j. Standings
message("Loading ESPN standings...")
espn_standings <- tryCatch(load_wnba_standings(seasons = SEASON), error = function(e) {
  message("  WARN: ESPN standings failed: ", conditionMessage(e))
  NULL
})
if (!is.null(espn_standings)) safe_write(espn_standings, "espn_standings")


# =========================================================================
# PART 2: WNBA Stats API-sourced bulk loaders
# =========================================================================
message("\n=== WNBA Stats API-sourced bulk data ===\n")

# 2a. Stats API shots (x_legacy, y_legacy, shot_distance, action_type,
#     sub_type, shot_value, shot_result)
message("Loading WNBA Stats shots...")
stats_shots <- tryCatch(load_wnba_stats_shots(seasons = SEASON), error = function(e) {
  message("  WARN: Stats shots failed: ", conditionMessage(e))
  NULL
})
if (!is.null(stats_shots)) safe_write(stats_shots, "stats_shots")

# 2b. Possessions (5-man lineups, per-possession shooting splits)
message("Loading WNBA Stats possessions...")
stats_possessions <- tryCatch(load_wnba_stats_possessions(seasons = SEASON), error = function(e) {
  message("  WARN: Stats possessions failed: ", conditionMessage(e))
  NULL
})
if (!is.null(stats_possessions)) safe_write(stats_possessions, "stats_possessions")

# 2c. Player game logs (per-player per-game: minutes, splits, +/-)
message("Loading WNBA Stats player game logs...")
stats_game_logs <- tryCatch(load_wnba_stats_player_game_logs(seasons = SEASON), error = function(e) {
  message("  WARN: Stats player game logs failed: ", conditionMessage(e))
  NULL
})
if (!is.null(stats_game_logs)) safe_write(stats_game_logs, "stats_player_game_logs")

# 2d. Stats schedule (pre-joined home/away with game_date, pts, W/L)
message("Loading WNBA Stats schedule...")
stats_schedule <- tryCatch(load_wnba_stats_schedule(seasons = SEASON), error = function(e) {
  message("  WARN: Stats schedule failed: ", conditionMessage(e))
  NULL
})
if (!is.null(stats_schedule)) safe_write(stats_schedule, "stats_schedule")

# 2e. Stats rosters
message("Loading WNBA Stats rosters...")
stats_rosters <- tryCatch(load_wnba_stats_rosters(seasons = SEASON), error = function(e) {
  message("  WARN: Stats rosters failed: ", conditionMessage(e))
  NULL
})
if (!is.null(stats_rosters)) safe_write(stats_rosters, "stats_rosters")

# 2f. Stats PBP (V3 play-by-play from stats.wnba.com)
message("Loading WNBA Stats PBP...")
stats_pbp <- tryCatch(load_wnba_stats_pbp(seasons = SEASON), error = function(e) {
  message("  WARN: Stats PBP failed: ", conditionMessage(e))
  NULL
})
if (!is.null(stats_pbp)) safe_write(stats_pbp, "stats_pbp")

# 2g. Leaguedash cubes -- the 24-table parameter set
# Key tables for our analysis:
LEAGUEDASH_TABLES <- c(
  "player_bio",
  "player_stats_base",
  "player_stats_advanced",
  "player_stats_usage",
  "player_stats_scoring",
  "player_stats_defense",
  "player_stats_misc",
  "team_stats_base",
  "team_stats_advanced",
  "team_stats_defense",
  "team_stats_fourfactors",
  "lineups_base",
  "lineups_advanced",
  "standings"
)

message("Loading WNBA Stats leaguedash cubes...")
for (tbl in LEAGUEDASH_TABLES) {
  message(sprintf("  leaguedash: %s", tbl))
  df <- tryCatch(
    load_wnba_stats_leaguedash(seasons = SEASON, table = tbl),
    error = function(e) {
      message(sprintf("    WARN: leaguedash %s failed: %s", tbl, conditionMessage(e)))
      NULL
    }
  )
  if (!is.null(df)) safe_write(df, paste0("leaguedash_", tbl))
}


# =========================================================================
# PART 3: Team crosswalk (ESPN <-> WNBA Stats ID mapping)
# =========================================================================
message("\n=== Crosswalk ===\n")

message("Loading team crosswalk...")
team_xwalk <- tryCatch(wnba_team_crosswalk(season = SEASON), error = function(e) {
  message("  WARN: team crosswalk failed: ", conditionMessage(e))
  NULL
})
if (!is.null(team_xwalk)) safe_write(team_xwalk, "team_crosswalk")


# =========================================================================
# Write manifest
# =========================================================================
manifest_path <- file.path(DEST_DIR, "wehoop_manifest.txt")
writeLines(manifest_lines, manifest_path)
message(sprintf("\nManifest written to %s", manifest_path))
message("Done.")
