# 17_wehoop_scaffold.R
#
# Purpose: Team crosswalk, ID resolution, data validation for the wehoop
#   pipeline. The wehoop analogue of 01-04 combined: it does NOT download
#   data (15_wehoop_download.R and 16_wehoop_live_api.R already did that),
#   it validates the data contract those scripts are supposed to have left
#   behind and builds the team ID lookup that downstream wehoop scripts use.
#
# Inputs:  data/wehoop/team_crosswalk.csv (espn_team_id, stats_team_id,
#            tricode, team_name, ...)
#          data/wehoop/stats_schedule.csv (game_id, home_team_id,
#            away_team_id, ...)
#          spot-checked only: espn_pbp.csv, stats_shots.csv,
#            stats_possessions.csv, leaguedash_*.csv,
#            live/hustle_player.csv, live/possessions_lineups.csv
# Outputs: data/wehoop/team_lookup.rds (team_id, espn_id, tricode, team_name)
#          output/wehoop/data_manifest.csv
#          output/wehoop/data_manifest.md

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

DATA_DIR <- file.path("data", "wehoop")
LIVE_DIR <- file.path(DATA_DIR, "live")
OUT_DIR  <- file.path("output", "wehoop")

# The 15 WNBA tricodes this project recognizes. LAS = Los Angeles Sparks,
# LVA = Las Vegas Aces -- never swap these.
PROJECT_TRICODES <- c(
  "ATL", "CHI", "CON", "DAL", "GSV", "IND", "LAS", "LVA",
  "MIN", "NYL", "PDX", "PHX", "SEA", "TOR", "WAS"
)

MIDSEASON_GAME_COUNT <- 182L

# Files spot-checked for existence and row count (not fully parsed).
SPOT_CHECK_FILES <- c(
  file.path(DATA_DIR, "espn_pbp.csv"),
  file.path(DATA_DIR, "stats_shots.csv"),
  file.path(DATA_DIR, "stats_possessions.csv"),
  file.path(LIVE_DIR, "hustle_player.csv"),
  file.path(LIVE_DIR, "possessions_lineups.csv")
)

#' Build the team_id lookup from team_crosswalk.csv.
#'
#' The crosswalk maps ESPN numeric team IDs to WNBA Stats API numeric team
#' IDs to project tricodes. team_id below is the Stats API ID, since that is
#' what most downstream wehoop tables (stats_shots, stats_possessions,
#' leaguedash_*) key on.
#'
#' @param crosswalk tibble read from data/wehoop/team_crosswalk.csv
#' @return tibble: team_id, espn_id, tricode, team_name
build_team_lookup <- function(crosswalk) {
  nm <- names(crosswalk)

  stats_id_col <- intersect(c("stats_team_id", "team_id"), nm)
  espn_id_col  <- intersect(c("espn_team_id", "espn_id"), nm)
  tricode_col  <- intersect(c("tricode", "team_abbreviation", "team_tricode"), nm)
  name_col     <- intersect(c("team_name", "team_display_name", "display_name"), nm)

  if (length(stats_id_col) == 0 || length(espn_id_col) == 0 || length(tricode_col) == 0) {
    stop(
      "build_team_lookup(): team_crosswalk.csv is missing one of the expected ",
      "columns (stats team id / espn team id / tricode). Found columns: ",
      paste(nm, collapse = ", ")
    )
  }

  lookup <- crosswalk %>%
    transmute(
      team_id   = as.character(.data[[stats_id_col[1]]]),
      espn_id   = as.character(.data[[espn_id_col[1]]]),
      tricode   = toupper(.data[[tricode_col[1]]]),
      team_name = if (length(name_col) > 0) .data[[name_col[1]]] else NA_character_
    ) %>%
    distinct()

  missing_tricodes <- setdiff(PROJECT_TRICODES, lookup$tricode)
  extra_tricodes    <- setdiff(lookup$tricode, PROJECT_TRICODES)
  if (length(missing_tricodes) > 0) {
    message(
      "  WARN: team_crosswalk.csv is missing expected tricodes: ",
      paste(missing_tricodes, collapse = ", ")
    )
  }
  if (length(extra_tricodes) > 0) {
    message(
      "  WARN: team_crosswalk.csv has unexpected tricodes not in the project's 15: ",
      paste(extra_tricodes, collapse = ", ")
    )
  }

  lookup
}

#' Check a CSV exists and has at least one row. Returns a one-row manifest
#' tibble (filename, rows, cols, exists) without fully loading large files
#' unnecessarily -- read_csv still has to be called to get rows/cols, but
#' the guard means a missing file never errors the whole script.
check_file <- function(path) {
  fname <- basename(path)
  if (!file.exists(path)) {
    message(sprintf("  MISSING: %s", path))
    return(tibble(filename = fname, path = path, exists = FALSE, rows = NA_integer_, cols = NA_integer_))
  }

  df <- tryCatch(
    readr::read_csv(path, show_col_types = FALSE, progress = FALSE),
    error = function(e) {
      message(sprintf("  WARN: failed to read %s: %s", path, conditionMessage(e)))
      NULL
    }
  )

  if (is.null(df)) {
    return(tibble(filename = fname, path = path, exists = TRUE, rows = NA_integer_, cols = NA_integer_))
  }

  nr <- nrow(df)
  nc <- ncol(df)
  if (nr == 0) {
    message(sprintf("  WARN: %s exists but has 0 rows", fname))
  } else {
    message(sprintf("  ok: %s -- %d rows x %d cols", fname, nr, nc))
  }

  tibble(filename = fname, path = path, exists = TRUE, rows = nr, cols = nc)
}

#' Spot-check leaguedash_*.csv files (variable set depending on what
#' 15_wehoop_download.R managed to pull) plus the fixed SPOT_CHECK_FILES list.
spot_check_files <- function() {
  leaguedash_files <- Sys.glob(file.path(DATA_DIR, "leaguedash_*.csv"))
  all_files <- unique(c(SPOT_CHECK_FILES, leaguedash_files))

  if (length(leaguedash_files) == 0) {
    message("  WARN: no leaguedash_*.csv files found in data/wehoop/")
  }

  bind_rows(lapply(all_files, check_file))
}

#' Cross-check games-per-team from stats_schedule.csv against the CDN
#' pipeline's 182-game midseason count. This is a sanity comparison, not a
#' hard assertion -- the wehoop pull may be full-season while the CDN
#' pipeline (01-04) is frozen at midseason, so a mismatch is expected and
#' just gets reported.
check_schedule_counts <- function(schedule) {
  needed <- c("game_id", "home_team_id", "away_team_id")
  missing_cols <- setdiff(needed, names(schedule))
  if (length(missing_cols) > 0) {
    message(
      "  WARN: stats_schedule.csv missing expected columns: ",
      paste(missing_cols, collapse = ", ")
    )
    return(invisible(NULL))
  }

  n_games <- dplyr::n_distinct(schedule$game_id)
  message(sprintf(
    "  stats_schedule.csv: %d distinct games (CDN midseason pipeline reference: %d)",
    n_games, MIDSEASON_GAME_COUNT
  ))

  games_per_team <- bind_rows(
    schedule %>% transmute(team_id = as.character(home_team_id), game_id),
    schedule %>% transmute(team_id = as.character(away_team_id), game_id)
  ) %>%
    distinct(team_id, game_id) %>%
    count(team_id, name = "games")

  message(sprintf(
    "  games per team: min=%s max=%s median=%s (%d teams)",
    min(games_per_team$games), max(games_per_team$games),
    median(games_per_team$games), nrow(games_per_team)
  ))

  invisible(games_per_team)
}

write_manifest_md <- function(manifest, path) {
  lines <- c(
    "# wehoop data manifest",
    "",
    sprintf("Generated: %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    "",
    "| filename | exists | rows | cols |",
    "| --- | --- | --- | --- |"
  )
  row_lines <- sprintf(
    "| %s | %s | %s | %s |",
    manifest$filename, manifest$exists, manifest$rows, manifest$cols
  )
  writeLines(c(lines, row_lines), path)
}

main <- function() {
  dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

  message("=== Team crosswalk ===")
  xwalk_path <- file.path(DATA_DIR, "team_crosswalk.csv")
  if (!file.exists(xwalk_path)) {
    stop(sprintf(
      "team_crosswalk.csv not found at %s. Run 15_wehoop_download.R first.",
      xwalk_path
    ))
  }
  crosswalk <- readr::read_csv(xwalk_path, show_col_types = FALSE)
  team_lookup <- build_team_lookup(crosswalk)

  message(sprintf("  built team_lookup: %d teams", nrow(team_lookup)))
  print(team_lookup)

  saveRDS(team_lookup, file.path(DATA_DIR, "team_lookup.rds"))
  message(sprintf("  wrote %s", file.path(DATA_DIR, "team_lookup.rds")))

  message("\n=== Schedule ===")
  sched_path <- file.path(DATA_DIR, "stats_schedule.csv")
  if (!file.exists(sched_path)) {
    message(sprintf("  WARN: %s not found, skipping schedule checks", sched_path))
    schedule_manifest <- tibble(
      filename = "stats_schedule.csv", path = sched_path,
      exists = FALSE, rows = NA_integer_, cols = NA_integer_
    )
  } else {
    schedule <- readr::read_csv(sched_path, show_col_types = FALSE)
    check_schedule_counts(schedule)
    schedule_manifest <- tibble(
      filename = "stats_schedule.csv", path = sched_path,
      exists = TRUE, rows = nrow(schedule), cols = ncol(schedule)
    )
  }

  message("\n=== Spot-checking data files ===")
  spot_manifest <- spot_check_files()

  xwalk_manifest <- tibble(
    filename = "team_crosswalk.csv", path = xwalk_path,
    exists = TRUE, rows = nrow(crosswalk), cols = ncol(crosswalk)
  )

  manifest <- bind_rows(xwalk_manifest, schedule_manifest, spot_manifest) %>%
    distinct(filename, .keep_all = TRUE)

  n_missing <- sum(!manifest$exists)
  if (n_missing > 0) {
    message(sprintf("\n%d expected file(s) missing:", n_missing))
    print(manifest %>% filter(!exists) %>% select(filename, path))
  } else {
    message("\nAll spot-checked files present.")
  }

  readr::write_csv(manifest, file.path(OUT_DIR, "data_manifest.csv"))
  write_manifest_md(manifest, file.path(OUT_DIR, "data_manifest.md"))
  message(sprintf(
    "\nManifest written to %s and %s",
    file.path(OUT_DIR, "data_manifest.csv"), file.path(OUT_DIR, "data_manifest.md")
  ))

  invisible(list(team_lookup = team_lookup, manifest = manifest))
}

if (sys.nframe() == 0) {
  main()
}
