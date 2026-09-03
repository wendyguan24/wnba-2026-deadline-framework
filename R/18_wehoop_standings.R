# 18_wehoop_standings.R
#
# Purpose: Full-season standings and playoff positioning from the wehoop
#   pipeline. This is the wehoop-era reframe of 12_standing.R's buyer /
#   bubble / seller windows: with the season complete there is no deadline
#   to buy or sell toward, so the tiers become playoff readiness --
#   contender / in / out.
#
# Inputs:  data/wehoop/stats_schedule.csv (game_id, home_team_id,
#            away_team_id, home_team_score, away_team_score, game_date)
#          data/wehoop/team_lookup.rds (from 17_wehoop_scaffold.R)
#          data/wehoop/leaguedash_standings.csv (cross-validation only)
# Outputs: output/wehoop/standings.csv (team, wins, losses, win_pct,
#            point_diff, point_diff_per_game, standing_score, rank,
#            games_back_from_8th, playoff_position[, rank_change])
#          output/wehoop/standings.md

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

DATA_DIR <- file.path("data", "wehoop")
OUT_DIR  <- file.path("output", "wehoop")

#' Build one row per team-game (team, opponent, points scored/allowed, win)
#' from stats_schedule.csv, then resolve numeric team_id to project tricode
#' via team_lookup.
#'
#' @param schedule tibble from data/wehoop/stats_schedule.csv
#' @param team_lookup tibble from data/wehoop/team_lookup.rds
#' @return tibble: game_id, team, team_pts, opp_pts, win
build_game_scores <- function(schedule, team_lookup) {
  # wehoop's stats schedule names the score columns home_pts/away_pts; older
  # exports used home_team_score/away_team_score. Accept either.
  home_score_col <- intersect(c("home_pts", "home_team_score", "home_score"), names(schedule))
  away_score_col <- intersect(c("away_pts", "away_team_score", "away_score"), names(schedule))
  needed_ids <- c("game_id", "home_team_id", "away_team_id")
  missing_cols <- setdiff(needed_ids, names(schedule))
  if (length(missing_cols) > 0 || length(home_score_col) == 0 || length(away_score_col) == 0) {
    stop(
      "build_game_scores(): stats_schedule.csv missing expected columns. Need ",
      "game_id/home_team_id/away_team_id plus a home/away score column ",
      "(home_pts or home_team_score). Found: ", paste(names(schedule), collapse = ", ")
    )
  }
  home_score_col <- home_score_col[1]
  away_score_col <- away_score_col[1]

  sched <- schedule %>%
    mutate(
      home_team_id = as.character(home_team_id),
      away_team_id = as.character(away_team_id),
      .home_pts = .data[[home_score_col]],
      .away_pts = .data[[away_score_col]]
    ) %>%
    filter(!is.na(.home_pts), !is.na(.away_pts))

  home_rows <- sched %>%
    transmute(
      game_id, team_id = home_team_id,
      team_pts = .home_pts, opp_pts = .away_pts
    )
  away_rows <- sched %>%
    transmute(
      game_id, team_id = away_team_id,
      team_pts = .away_pts, opp_pts = .home_pts
    )

  game_scores <- bind_rows(home_rows, away_rows) %>%
    mutate(win = team_pts > opp_pts)  # no ties in basketball

  lookup_small <- team_lookup %>% select(team_id, tricode) %>% distinct()

  resolved <- game_scores %>%
    left_join(lookup_small, by = "team_id")

  unresolved <- resolved %>% filter(is.na(tricode)) %>% distinct(team_id)
  if (nrow(unresolved) > 0) {
    message(
      "  WARN: could not resolve team_id(s) to a tricode via team_lookup.rds: ",
      paste(unresolved$team_id, collapse = ", ")
    )
  }

  resolved %>%
    filter(!is.na(tricode)) %>%
    transmute(game_id, team = tricode, team_pts, opp_pts, win)
}

#' Build the per-team standings table: record, point differential,
#' standing_score, rank, games_back_from_8th, and playoff_position tier.
#' Modeled on build_standing() in 12_standing.R, with the window relabeled
#' contender / in / out for the full-season (post-deadline) reframe.
#'
#' standing_score = (scale(win_pct) + scale(point_diff_per_game)) / 2,
#' equally weighted, same blend as 12_standing.R.
#'
#' playoff_position from standing_score rank:
#'   1-4  -> "contender"
#'   5-8  -> "in"
#'   9-15 -> "out"
#'
#' @param game_scores tibble from build_game_scores()
#' @return tibble: team, wins, losses, win_pct, point_diff,
#'   point_diff_per_game, standing_score, rank, games_back_from_8th,
#'   playoff_position
build_standings <- function(game_scores) {
  standings <- game_scores %>%
    group_by(team) %>%
    summarise(
      wins = sum(win),
      losses = sum(!win),
      games = wins + losses,
      point_diff = sum(team_pts - opp_pts),
      .groups = "drop"
    ) %>%
    mutate(
      win_pct = wins / games,
      point_diff_per_game = point_diff / games
    ) %>%
    arrange(desc(win_pct), desc(point_diff)) %>%
    mutate(rank = row_number())

  n_teams <- nrow(standings)
  if (n_teams < 8) {
    stop(sprintf(
      "build_standings(): only %d teams found, need at least 8 to set a playoff cut line.",
      n_teams
    ))
  }

  eighth <- standings %>% filter(rank == 8)
  if (nrow(eighth) != 1) {
    stop("build_standings(): expected exactly one rank-8 team (the playoff cut line).")
  }
  w8 <- eighth$wins
  l8 <- eighth$losses

  standings <- standings %>%
    mutate(
      games_back_from_8th = ((w8 - l8) - (wins - losses)) / 2,
      standing_score = (as.numeric(scale(win_pct)) + as.numeric(scale(point_diff_per_game))) / 2
    )

  position_tbl <- standings %>%
    arrange(desc(standing_score), desc(win_pct)) %>%
    mutate(
      position_rank = row_number(),
      playoff_position = case_when(
        position_rank <= 4 ~ "contender",  # comfortably in playoff position
        position_rank <= 8 ~ "in",         # holding a playoff spot
        TRUE               ~ "out"         # out of the field
      )
    ) %>%
    select(team, playoff_position)

  standings %>%
    left_join(position_tbl, by = "team") %>%
    select(team, wins, losses, win_pct, point_diff, point_diff_per_game,
           standing_score, rank, games_back_from_8th, playoff_position)
}

#' Cross-validate wins/losses against leaguedash_standings.csv where
#' available. Reports mismatches, does not error -- this is a sanity check,
#' not a hard assertion, since leaguedash column names/conventions vary.
cross_validate_standings <- function(standings, leaguedash_path) {
  if (!file.exists(leaguedash_path)) {
    message(sprintf("  WARN: %s not found, skipping cross-validation", leaguedash_path))
    return(invisible(NULL))
  }

  ld <- tryCatch(
    readr::read_csv(leaguedash_path, show_col_types = FALSE),
    error = function(e) {
      message("  WARN: failed to read leaguedash_standings.csv: ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(ld)) return(invisible(NULL))

  tricode_col <- intersect(c("team_abbreviation", "tricode", "team_tricode"), names(ld))
  wins_col    <- intersect(c("wins", "w"), names(ld))
  losses_col  <- intersect(c("losses", "l"), names(ld))

  if (length(tricode_col) == 0 || length(wins_col) == 0 || length(losses_col) == 0) {
    message("  WARN: leaguedash_standings.csv missing expected columns, skipping cross-validation")
    return(invisible(NULL))
  }

  ld_small <- ld %>%
    transmute(
      team = toupper(.data[[tricode_col[1]]]),
      ld_wins = .data[[wins_col[1]]],
      ld_losses = .data[[losses_col[1]]]
    )

  compare <- standings %>%
    select(team, wins, losses) %>%
    left_join(ld_small, by = "team") %>%
    mutate(wins_match = wins == ld_wins, losses_match = losses == ld_losses)

  mismatches <- compare %>% filter(!wins_match | !losses_match | is.na(ld_wins))
  if (nrow(mismatches) > 0) {
    message("  WARN: record mismatches vs leaguedash_standings.csv:")
    print(mismatches)
  } else {
    message("  cross-validation ok: all team records match leaguedash_standings.csv")
  }

  invisible(compare)
}

#' Try to load midseason standings from output/standing.csv (12_standing.R's
#' output) and attach a rank_change column (midseason rank minus full-season
#' rank; positive means the team rose). Returns standings unchanged if the
#' midseason file is not found.
add_rank_change <- function(standings, midseason_path = file.path("output", "standing.csv")) {
  if (!file.exists(midseason_path)) {
    message(sprintf("  WARN: %s not found, skipping rank_change", midseason_path))
    return(standings)
  }

  midseason <- tryCatch(
    readr::read_csv(midseason_path, show_col_types = FALSE),
    error = function(e) {
      message("  WARN: failed to read midseason standing.csv: ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(midseason) || !all(c("team", "rank") %in% names(midseason))) {
    message("  WARN: midseason standing.csv missing team/rank columns, skipping rank_change")
    return(standings)
  }

  midseason_rank <- midseason %>% select(team, midseason_rank = rank)

  standings %>%
    left_join(midseason_rank, by = "team") %>%
    mutate(rank_change = midseason_rank - rank) %>%
    select(-midseason_rank)
}

write_standings_md <- function(standings, path) {
  has_rank_change <- "rank_change" %in% names(standings)
  header <- c(
    "team", "wins", "losses", "win_pct", "point_diff", "point_diff_per_game",
    "standing_score", "rank", "games_back_from_8th", "playoff_position"
  )
  if (has_rank_change) header <- c(header, "rank_change")

  lines <- c(
    "# Full-season standings",
    "",
    sprintf("Generated: %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    "",
    paste0("| ", paste(header, collapse = " | "), " |"),
    paste0("| ", paste(rep("---", length(header)), collapse = " | "), " |")
  )

  fmt_row <- function(r) {
    vals <- vapply(header, function(col) {
      v <- r[[col]]
      if (is.numeric(v)) format(round(v, 3)) else as.character(v)
    }, character(1))
    paste0("| ", paste(vals, collapse = " | "), " |")
  }

  row_lines <- vapply(seq_len(nrow(standings)), function(i) fmt_row(standings[i, ]), character(1))
  writeLines(c(lines, row_lines), path)
}

main <- function() {
  dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

  sched_path  <- file.path(DATA_DIR, "stats_schedule.csv")
  lookup_path <- file.path(DATA_DIR, "team_lookup.rds")

  if (!file.exists(sched_path)) {
    stop(sprintf("stats_schedule.csv not found at %s. Run 15_wehoop_download.R first.", sched_path))
  }
  if (!file.exists(lookup_path)) {
    stop(sprintf("team_lookup.rds not found at %s. Run 17_wehoop_scaffold.R first.", lookup_path))
  }

  schedule    <- readr::read_csv(sched_path, show_col_types = FALSE)
  team_lookup <- readRDS(lookup_path)

  message("=== Building game scores ===")
  game_scores <- build_game_scores(schedule, team_lookup)
  message(sprintf("  %d team-games across %d games", nrow(game_scores), dplyr::n_distinct(game_scores$game_id)))

  message("\n=== Building standings ===")
  standings <- build_standings(game_scores)

  message("\n=== Cross-validating against leaguedash_standings.csv ===")
  cross_validate_standings(standings, file.path(DATA_DIR, "leaguedash_standings.csv"))

  message("\n=== Checking for midseason standings (rank_change) ===")
  standings <- add_rank_change(standings)

  readr::write_csv(standings, file.path(OUT_DIR, "standings.csv"))
  write_standings_md(standings, file.path(OUT_DIR, "standings.md"))

  message(sprintf(
    "\nWrote %s and %s",
    file.path(OUT_DIR, "standings.csv"), file.path(OUT_DIR, "standings.md")
  ))

  message("\nFull-season standings (playoff_position from standing_score rank: 1-4 contender, 5-8 in, 9-15 out):")
  print(standings, n = Inf)
  message("\nPlayoff position distribution:")
  print(table(standings$playoff_position))

  invisible(standings)
}

if (sys.nframe() == 0) {
  main()
}
