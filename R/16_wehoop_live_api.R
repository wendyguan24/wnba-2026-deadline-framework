# 16_wehoop_live_api.R
#
# Purpose: Pull WNBA data that is NOT available via wehoop's bulk loaders
#   (which read pre-built .rds/.parquet from sportsdataverse-data releases).
#   These functions hit the live ESPN or WNBA Stats API directly and require
#   an active internet connection.
#
#   This script is OPTIONAL. Run it only if you need:
#     - Hustle stats (contested shots, deflections, loose balls, box-outs)
#     - Player tracking boxscores (distance, touches, passes, speed)
#     - Real-time standings / scoreboard
#     - Possession-level stint matrix with 5v5 lineups (built from V3 PBP)
#     - Shot zone classifications (corner 3, ATB 3, RA, paint, mid-range)
#     - RAPM (regularized adjusted plus-minus)
#
# Inputs:  data/wehoop/stats_schedule.csv (for game IDs)
#          OR provide game_ids manually
# Outputs: data/wehoop/live/*.csv
#
# Requirements:
#   install.packages("wehoop")
#   install.packages("tidyverse")
#   install.packages("glmnet")   # only for RAPM
#   install.packages("Matrix")   # only for RAPM
#
# Usage:
#   Rscript R/16_wehoop_live_api.R                        # all completed games
#   Rscript R/16_wehoop_live_api.R --hustle-only          # just hustle stats
#   Rscript R/16_wehoop_live_api.R --possessions-only     # just possessions
#   Rscript R/16_wehoop_live_api.R --rapm                 # possessions + RAPM
#   Rscript R/16_wehoop_live_api.R --max-games 10         # limit game count

suppressPackageStartupMessages({
  library(wehoop)
  library(dplyr)
  library(readr)
})

SEASON <- 2026L
DEST_DIR <- file.path("data", "wehoop", "live")
dir.create(DEST_DIR, recursive = TRUE, showWarnings = FALSE)

# ---------------------------------------------------------------------------
# CLI args
# ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
do_hustle      <- !any(args == "--possessions-only")
do_possessions <- !any(args == "--hustle-only")
do_rapm        <- any(args == "--rapm")
max_games      <- Inf

if ("--season" %in% args) {
  idx <- which(args == "--season")
  if (idx < length(args)) SEASON <- as.integer(args[idx + 1L])
}
if ("--max-games" %in% args) {
  idx <- which(args == "--max-games")
  if (idx < length(args)) max_games <- as.integer(args[idx + 1L])
}

# ---------------------------------------------------------------------------
# Resolve game IDs from the schedule
# ---------------------------------------------------------------------------
sched_path <- file.path("data", "wehoop", "stats_schedule.csv")
if (file.exists(sched_path)) {
  sched <- readr::read_csv(sched_path, show_col_types = FALSE)
  # The schedule should have a game_id column; filter to completed games
  if ("game_id" %in% names(sched)) {
    game_ids <- unique(sched$game_id)
  } else {
    stop("stats_schedule.csv missing game_id column. Run 15_wehoop_download.R first.")
  }
} else {
  message("No stats_schedule.csv found. Attempting to load schedule from wehoop...")
  sched <- load_wnba_stats_schedule(seasons = SEASON)
  game_ids <- unique(sched$game_id)
}

game_ids <- sort(game_ids)
if (is.finite(max_games) && length(game_ids) > max_games) {
  message(sprintf("Limiting to first %d of %d games", max_games, length(game_ids)))
  game_ids <- game_ids[seq_len(max_games)]
}

message(sprintf("Processing %d games for season %d\n", length(game_ids), SEASON))


# =========================================================================
# Section A: Hustle stats (league-wide, not per-game)
# =========================================================================
if (do_hustle) {
  message("=== Hustle Stats (league-wide) ===\n")
  message("  NOTE: wnba_leaguehustlestatsplayer() and wnba_leaguehustlestatsteam()")
  message("  were deprecated in wehoop 3.0.0 and are now defunct.")
  message("  Hustle stats are no longer available via this endpoint.")
  message("  Scripts 20 and 21 will run without hustle data (hustle dimensions skipped).")
}


# =========================================================================
# Section B: Per-game possession lineups + shot zones
# =========================================================================
if (do_possessions) {
  message("\n=== Possession lineups + shot zones (per game) ===\n")

  all_possessions <- list()
  all_shot_zones  <- list()

  for (i in seq_along(game_ids)) {
    gid <- game_ids[i]
    message(sprintf("  [%d/%d] game_id=%s", i, length(game_ids), gid))

    # Possessions with 5v5 lineups
    poss <- tryCatch(
      wnba_possession_lineups(game_id = gid),
      error = function(e) {
        message(sprintf("    WARN poss: %s", conditionMessage(e)))
        NULL
      }
    )
    if (!is.null(poss) && nrow(poss) > 0) {
      all_possessions[[length(all_possessions) + 1L]] <- poss
    }

    # Shot zones
    sz <- tryCatch(
      wnba_shot_zones(game_id = gid),
      error = function(e) {
        message(sprintf("    WARN shot_zones: %s", conditionMessage(e)))
        NULL
      }
    )
    if (!is.null(sz) && nrow(sz) > 0) {
      shots_only <- sz[!is.na(sz$shot_zone), ]
      if (nrow(shots_only) > 0) {
        all_shot_zones[[length(all_shot_zones) + 1L]] <- shots_only
      }
    }

    # Rate limit: be polite to the API
    if (i < length(game_ids)) Sys.sleep(1)
  }

  # Combine and save
  if (length(all_possessions) > 0) {
    poss_df <- dplyr::bind_rows(all_possessions)
    readr::write_csv(poss_df, file.path(DEST_DIR, "possessions_lineups.csv"))
    message(sprintf("\npossessions_lineups: %d rows across %d games",
                    nrow(poss_df), length(unique(poss_df$game_id))))
  }

  if (length(all_shot_zones) > 0) {
    sz_df <- dplyr::bind_rows(all_shot_zones)
    readr::write_csv(sz_df, file.path(DEST_DIR, "shot_zones.csv"))
    message(sprintf("shot_zones: %d rows across %d games",
                    nrow(sz_df), length(unique(sz_df$game_id))))
  }
}


# =========================================================================
# Section C: RAPM (requires possessions)
# =========================================================================
if (do_rapm) {
  message("\n=== RAPM ===\n")

  poss_path <- file.path(DEST_DIR, "possessions_lineups.csv")
  if (!file.exists(poss_path)) {
    message("No possessions_lineups.csv found. Run with --possessions-only or without --hustle-only first.")
  } else {
    poss_df <- readr::read_csv(poss_path, show_col_types = FALSE)
    message(sprintf("Fitting RAPM on %d possessions...", nrow(poss_df)))

    rapm <- tryCatch(
      wnba_rapm(poss_df),
      error = function(e) {
        message("  WARN: RAPM failed: ", conditionMessage(e))
        NULL
      }
    )
    if (!is.null(rapm) && nrow(rapm) > 0) {
      readr::write_csv(rapm, file.path(DEST_DIR, "rapm.csv"))
      message(sprintf("rapm: %d players", nrow(rapm)))
    }
  }
}

message("\nDone.")
