# 04_reconcile.R
#
# Purpose: Validate the parsed data before any feature or model is built.
#   (1) Reconcile cdn vs nbastats v2 per-game FGA/FGM/AST/3PA counts (the
#       analog of the NCAA project's wehoop reconciliation and its documented
#       2.5-FGM gap — document deltas the same way, don't hide them).
#   (2) Validate the HANDOFF §4 baseline sanity table reproduces within
#       rounding (8 teams: GSV, NYL, PDX, TOR, MIN, WAS, CON, ATL).
#   (3) Confirm/refute the known shotdetail-Toronto coverage gap (see README
#       "Known issue") before any expected-points feature is trusted for
#       Toronto.
#   Per CLAUDE.md: scripts 05+ do not get written until tests in
#   tests/testthat/ pass against this script's output.
#
#   (4) Possession points equal final score in every team-game, per season type.
#   Everything is run per season_type (regular, playoffs); the two are separate
#   populations. The HANDOFF §4 8-team table is validated on the v1 game subset
#   only (regular-season gameIds 1-182, V1_CUTOFF_GAMES in R/00_config.R).
#
# Inputs:  <PROCESSED_DIR>/pbp_events.rds, possessions.rds, raw nbastats and
#          shotdetail CSVs for both season types (paths via R/00_config.R)
# Outputs: output/offseason/reconciliation_report.md,
#          data/reference/pipeline_baseline.csv

library(tidyverse)

#' Compute per-team-game FGA/FGM/AST/FG3A from the parsed cdn events
#'
#' @param pbp tibble, parsed PBP events
#' @return tibble, one row per team-game: gameId, team, FGA, FGM, AST, FG3A
compute_team_game_counts_cdn <- function(pbp) {
  pbp %>%
    filter(actionType %in% c("2pt", "3pt"), !is.na(teamTricode)) %>%
    group_by(gameId, team = teamTricode) %>%
    summarise(
      FGA = n(),
      FGM = sum(shotResult == "Made"),
      AST = sum(shotResult == "Made" & !is.na(assistPersonId)),
      FG3A = sum(actionType == "3pt"),
      .groups = "drop"
    )
}

#' Compute the same per-team-game counts from nbastats v2 for cross-check.
#' EVENTMSGTYPE 1 = made FG, 2 = missed FG (verified against real data
#' 2026-07-18). v2 has no direct 2pt/3pt flag or reliable assist ID column
#' (PLAYER2_ID is populated on every made-FG row, not just assisted ones —
#' verified, so it is NOT usable as an assist indicator); 3PT and AST are
#' both detected from the free-text description instead, matching the
#' handoff's documented approach.
#'
#' @param v2_raw tibble, raw nbastats v2 CSV
#' @return tibble, one row per team-game: gameId, team, FGA, FGM, AST, FG3A
compute_team_game_counts_v2 <- function(v2_raw) {
  v2_raw %>%
    filter(EVENTMSGTYPE %in% c(1, 2), !is.na(PLAYER1_TEAM_ABBREVIATION)) %>%
    mutate(desc = paste0(coalesce(HOMEDESCRIPTION, ""), coalesce(VISITORDESCRIPTION, ""))) %>%
    group_by(gameId = GAME_ID, team = PLAYER1_TEAM_ABBREVIATION) %>%
    summarise(
      FGA = n(),
      FGM = sum(EVENTMSGTYPE == 1),
      AST = sum(EVENTMSGTYPE == 1 & str_detect(desc, "AST")),
      FG3A = sum(str_detect(desc, "3PT")),
      .groups = "drop"
    )
}

#' Compare cdn vs v2 counts and summarize the delta distribution
#'
#' @param cdn_counts tibble
#' @param v2_counts tibble
#' @return tibble of per-team-game deltas (cdn - v2), one row per team-game
reconcile_cdn_v2 <- function(cdn_counts, v2_counts) {
  cdn_counts %>%
    full_join(v2_counts, by = c("gameId", "team"), suffix = c("_cdn", "_v2")) %>%
    mutate(
      FGA_delta = FGA_cdn - FGA_v2,
      FGM_delta = FGM_cdn - FGM_v2,
      AST_delta = AST_cdn - AST_v2,
      FG3A_delta = FG3A_cdn - FG3A_v2
    )
}

# HANDOFF §4 baseline sanity table (8 named teams). Definitions confirmed
# empirically against real data 2026-07-18: FGA = count of 2pt+3pt events;
# FG% = made/FGA; 3PA rate = 3pt events/FGA; assisted rate = made shots with
# a non-NA assistPersonId / FGM; fastbreak share = shots with "fastbreak" in
# qualifiers / FGA; paint share = made shots with area in {"Restricted
# Area","In The Paint (Non-RA)"} / FGM. All 8 teams x 6 metrics reproduced
# exactly (0 delta at 3-decimal rounding) against this definition.
BASELINE_TARGET <- tibble::tribble(
  ~team, ~FGA_target, ~FG_pct_target, ~FG3A_rate_target, ~assisted_rate_target, ~fastbreak_share_target, ~paint_share_target,
  "GSV", 1690, .419, .449, .638, .066, .532,
  "NYL", 1559, .459, .440, .686, .079, .609,
  "PDX", 1684, .444, .416, .676, .087, .637,
  "TOR", 1630, .447, .410, .660, .097, .575,
  "MIN", 1755, .481, .319, .628, .115, .600,
  "WAS", 1489, .430, .306, .679, .064, .746,
  "CON", 1634, .435, .266, .649, .086, .675,
  "ATL", 1700, .434, .378, .647, .119, .712
)

#' Reproduce the HANDOFF §4 baseline sanity table from parsed data
#'
#' @param pbp tibble
#' @return tibble, BASELINE_TARGET joined with computed values and deltas
validate_baseline_table <- function(pbp) {
  shots <- pbp %>% filter(actionType %in% c("2pt", "3pt"))

  computed <- shots %>%
    group_by(team = teamTricode) %>%
    summarise(
      FGA = n(),
      FGM = sum(shotResult == "Made"),
      FG_pct = round(FGM / FGA, 3),
      FG3A_rate = round(sum(actionType == "3pt") / FGA, 3),
      assisted_rate = round(sum(shotResult == "Made" & !is.na(assistPersonId)) / FGM, 3),
      fastbreak_share = round(sum(str_detect(coalesce(qualifiers, ""), "fastbreak")) / FGA, 3),
      paint_share = round(sum(shotResult == "Made" & area %in% c("Restricted Area", "In The Paint (Non-RA)")) / FGM, 3),
      .groups = "drop"
    ) %>%
    filter(team %in% BASELINE_TARGET$team)

  BASELINE_TARGET %>%
    left_join(computed, by = "team") %>%
    mutate(
      FGA_delta = FGA - FGA_target,
      FG_pct_delta = round(FG_pct - FG_pct_target, 3),
      FG3A_rate_delta = round(FG3A_rate - FG3A_rate_target, 3),
      assisted_rate_delta = round(assisted_rate - assisted_rate_target, 3),
      fastbreak_share_delta = round(fastbreak_share - fastbreak_share_target, 3),
      paint_share_delta = round(paint_share - paint_share_target, 3)
    )
}

#' Check whether shotdetail has full 15-team coverage, or is missing teams
#' (Toronto, per a prior finding — see README "Known issue")
#'
#' @param shotdetail_raw tibble, raw shotdetail CSV
#' @param all_teams character vector, the full expected team roster
#'   (team_full_name format, e.g. from pbp$team_full_name)
#' @return list summarizing per-team coverage
check_shotdetail_coverage <- function(shotdetail_raw, all_teams) {
  teams_present <- shotdetail_raw %>% distinct(TEAM_NAME) %>% pull(TEAM_NAME)
  missing <- setdiff(all_teams, teams_present)
  list(
    n_teams_present = length(teams_present),
    n_teams_expected = length(all_teams),
    missing_teams = missing,
    n_rows = nrow(shotdetail_raw)
  )
}

#' Game dates (local, YYYYMMDD from shotdetail GAME_DATE; falls back to the
#' UTC date of the first cdn event if a game has no shotdetail rows)
#'
#' @param pbp tibble, parsed PBP events
#' @param shotdetail_raw tibble, raw shotdetail CSV(s) bound together
#' @return tibble: gameId, game_date (Date)
compute_game_dates <- function(pbp, shotdetail_raw) {
  sd_dates <- shotdetail_raw %>%
    distinct(gameId = GAME_ID, GAME_DATE) %>%
    distinct(gameId, .keep_all = TRUE) %>%
    transmute(gameId, sd_date = as.Date(as.character(GAME_DATE), format = "%Y%m%d"))
  cdn_dates <- pbp %>%
    group_by(gameId) %>%
    summarise(cdn_date = as.Date(min(timeActual, na.rm = TRUE)), .groups = "drop")
  cdn_dates %>%
    left_join(sd_dates, by = "gameId") %>%
    transmute(gameId, game_date = coalesce(sd_date, cdn_date))
}

#' Derive home and away team per game from cdn alone: the team whose made
#' shots/free throws raise scoreHome is home, the one that raises scoreAway is
#' away. Independent of shotdetail (which omits Toronto's own rows).
#'
#' @param pbp tibble, parsed PBP events
#' @return tibble: gameId, home_team, away_team
derive_home_away <- function(pbp) {
  scoring <- pbp %>%
    arrange(gameId, orderNumber) %>%
    group_by(gameId) %>%
    mutate(d_home = scoreHome - lag(scoreHome, default = 0),
           d_away = scoreAway - lag(scoreAway, default = 0)) %>%
    ungroup() %>%
    filter(actionType %in% c("2pt", "3pt", "freethrow"), shotResult == "Made",
           !is.na(teamTricode), (d_home > 0) != (d_away > 0))
  votes <- scoring %>%
    mutate(side_of_team = if_else(d_home > 0, "home", "away")) %>%
    count(gameId, team = teamTricode, side_of_team)
  pick <- function(side) {
    votes %>% filter(side_of_team == side) %>% group_by(gameId) %>%
      slice_max(n, n = 1, with_ties = FALSE) %>% ungroup() %>%
      select(gameId, team)
  }
  inner_join(pick("home") %>% rename(home_team = team),
             pick("away") %>% rename(away_team = team), by = "gameId")
}

#' Compare summed possession points to final score per team-game
#'
#' @param pbp tibble
#' @param possessions tibble
#' @return tibble per team-game: gameId, team, final_score, pts, diff
reconcile_possession_points <- function(pbp, possessions) {
  final_scores <- pbp %>%
    group_by(gameId) %>%
    filter(orderNumber == max(orderNumber)) %>%
    ungroup() %>%
    select(gameId, scoreHome, scoreAway) %>%
    inner_join(derive_home_away(pbp), by = "gameId")
  final_long <- bind_rows(
    final_scores %>% transmute(gameId, team = home_team, final_score = scoreHome),
    final_scores %>% transmute(gameId, team = away_team, final_score = scoreAway)
  )
  poss_points <- possessions %>% group_by(gameId, team) %>%
    summarise(pts = sum(points), .groups = "drop")
  final_long %>%
    left_join(poss_points, by = c("gameId", "team")) %>%
    mutate(diff = pts - final_score)
}

#' The v1 game subset: first V1_CUTOFF_GAMES regular-season gameIds, sorted.
#' Checks the 182nd game is dated on or before 2026-07-16 and the 183rd later.
#'
#' @return list(ids, last_v1_date, next_date)
v1_subset <- function(pbp, game_dates, cutoff = V1_CUTOFF_GAMES) {
  reg_ids <- pbp %>% filter(season_type == "regular") %>% distinct(gameId) %>%
    arrange(gameId) %>% pull(gameId)
  ids <- reg_ids[seq_len(cutoff)]
  d <- function(id) game_dates$game_date[match(id, game_dates$gameId)]
  list(ids = ids, last_v1_date = d(reg_ids[cutoff]), next_date = d(reg_ids[cutoff + 1]))
}

#' Render the reconciliation report as markdown lines
#'
#' @param res list of per-season-type results (see main())
#' @return character vector of markdown lines
render_reconciliation_report <- function(res, v1) {
  md_table <- function(df) {
    c(paste0("| ", paste(names(df), collapse = " | "), " |"),
      paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
      apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
  }
  sections <- purrr::imap(res, function(r, st) {
    rec <- r$reconciliation
    worst_fgm <- rec %>% filter(!is.na(FGM_delta)) %>% arrange(desc(abs(FGM_delta))) %>% slice(1)
    nonzero <- rec %>%
      filter(coalesce(FGA_delta, 0) != 0 | coalesce(FGM_delta, 0) != 0 |
               coalesce(AST_delta, 0) != 0 | coalesce(FG3A_delta, 0) != 0) %>%
      select(gameId, team, FGA_delta, FGM_delta, AST_delta, FG3A_delta)
    bad <- r$poss_check %>% filter(is.na(pts) | diff != 0)
    c(
      paste0("## ", tools::toTitleCase(st)), "",
      paste0("Pin: ", PIN_SHORT, ". Games: ", r$games, ". Date range: ",
             r$first_date, " to ", r$last_date, "."),
      paste0("Rows: cdn ", r$cdn_rows, ", nbastats v2 ", r$v2_rows,
             ", shotdetail ", r$shotdetail_rows, ". Team-games: ", r$team_games, "."),
      "",
      "### Possession points vs final score", "",
      paste0("Team-games checked: ", nrow(r$poss_check), ". Mismatches (or missing): ", nrow(bad), "."),
      paste0("Home/away derived from cdn scoring events agrees with shotdetail HTM/VTM in ",
             r$home_away_agree, " of ", r$home_away_n, " games with shotdetail rows."),
      if (nrow(bad) > 0) c("", md_table(head(bad, 30) %>% mutate(across(everything(), as.character)))) else NULL,
      "",
      "### cdn vs nbastats v2", "",
      paste0("Team-games compared: ", nrow(rec)),
      paste0("Sum of |FGA delta|: ", sum(abs(rec$FGA_delta), na.rm = TRUE),
             " | |FGM delta|: ", sum(abs(rec$FGM_delta), na.rm = TRUE),
             " | |AST delta|: ", sum(abs(rec$AST_delta), na.rm = TRUE),
             " | |FG3A delta|: ", sum(abs(rec$FG3A_delta), na.rm = TRUE)),
      paste0("Largest single-game FGM delta: ", worst_fgm$FGM_delta[1],
             " (game ", worst_fgm$gameId[1], ", team ", worst_fgm$team[1], ")"),
      "",
      "Team-games with any nonzero delta (cdn minus v2):",
      if (nrow(nonzero) == 0) "none" else md_table(nonzero %>% mutate(across(everything(), as.character))),
      "",
      "### shotdetail coverage", "",
      paste0("Teams present: ", r$shotdetail_check$n_teams_present, " of ",
             r$shotdetail_check$n_teams_expected, " expected. Missing: ",
             if (length(r$shotdetail_check$missing_teams) == 0) "none"
             else paste(r$shotdetail_check$missing_teams, collapse = ", ")),
      "",
      "### Games per team", "",
      md_table(r$games_per_team %>% mutate(across(everything(), as.character))),
      ""
    )
  })
  b <- v1$baseline
  c(
    "# Reconciliation Report (offseason pin)", "",
    paste0("Generated: ", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    paste0("Pinned commit: ", PINNED_COMMIT), "",
    "Regular season and playoffs are separate populations; every section is per season type.",
    "",
    unlist(unname(sections)),
    "## v1 subset regression", "",
    paste0("v1 subset: first ", V1_CUTOFF_GAMES, " regular-season gameIds (",
           min(v1$ids), " to ", max(v1$ids), "). Game ", V1_CUTOFF_GAMES, " dated ",
           v1$last_v1_date, "; game ", V1_CUTOFF_GAMES + 1, " dated ", v1$next_date, "."),
    "",
    "HANDOFF §4 baseline table (8 teams, 6 metrics) on the v1 subset. Max abs deltas:",
    paste0("FGA ", max(abs(b$FGA_delta)), " | FG% ", max(abs(b$FG_pct_delta)),
           " | 3PA rate ", max(abs(b$FG3A_rate_delta)),
           " | assisted rate ", max(abs(b$assisted_rate_delta)),
           " | fastbreak share ", max(abs(b$fastbreak_share_delta)),
           " | paint share ", max(abs(b$paint_share_delta))),
    "",
    "## Gate", "",
    "Per CLAUDE.md, feature and model code is not built on this layer until this report",
    "is reviewed."
  )
}

main <- function() {
  if (!exists("PROCESSED_DIR")) source(file.path("R", "00_config.R"))
  pbp_all <- readRDS(file.path(PROCESSED_DIR, "pbp_events.rds"))
  poss_all <- readRDS(file.path(PROCESSED_DIR, "possessions.rds"))

  sd_all <- purrr::map_dfr(names(SEASON_TYPES), ~ read_csv(raw_csv("shotdetail", .x), show_col_types = FALSE, guess_max = 100000) %>% mutate(season_type = .x))
  game_dates <- compute_game_dates(pbp_all, sd_all)

  res <- purrr::map(setNames(names(SEASON_TYPES), names(SEASON_TYPES)), function(st) {
    pbp <- pbp_all %>% filter(season_type == st)
    poss <- poss_all %>% filter(season_type == st)
    v2_raw <- read_csv(raw_csv("nbastats", st), show_col_types = FALSE, guess_max = 100000)
    sd_raw <- sd_all %>% filter(season_type == st)
    # expected teams = teams that actually played in this season type
    all_teams <- pbp %>% filter(!is.na(team_full_name)) %>% distinct(team_full_name) %>% pull(team_full_name)
    cdn_counts <- compute_team_game_counts_cdn(pbp)
    v2_counts <- compute_team_game_counts_v2(v2_raw)
    ha <- derive_home_away(pbp)
    ha_sd <- sd_raw %>% distinct(gameId = GAME_ID, HTM, VTM) %>% distinct(gameId, .keep_all = TRUE)
    ha_cmp <- ha %>% inner_join(ha_sd, by = "gameId")
    dts <- game_dates %>% filter(gameId %in% pbp$gameId)
    list(
      games = n_distinct(pbp$gameId),
      cdn_rows = nrow(pbp), v2_rows = nrow(v2_raw), shotdetail_rows = nrow(sd_raw),
      team_games = nrow(cdn_counts),
      first_date = min(dts$game_date), last_date = max(dts$game_date),
      reconciliation = reconcile_cdn_v2(cdn_counts, v2_counts),
      poss_check = reconcile_possession_points(pbp, poss),
      home_away_agree = sum(ha_cmp$home_team == ha_cmp$HTM & ha_cmp$away_team == ha_cmp$VTM),
      home_away_n = nrow(ha_cmp),
      shotdetail_check = check_shotdetail_coverage(sd_raw, all_teams),
      games_per_team = cdn_counts %>% count(team, name = "games") %>% arrange(team)
    )
  })

  v1_info <- v1_subset(pbp_all, game_dates)
  if (!(v1_info$last_v1_date <= as.Date("2026-07-16") && v1_info$next_date > as.Date("2026-07-16"))) {
    stop("v1 subset check failed: game ", V1_CUTOFF_GAMES, " dated ", v1_info$last_v1_date,
         ", game ", V1_CUTOFF_GAMES + 1, " dated ", v1_info$next_date)
  }
  v1 <- c(v1_info, list(baseline = validate_baseline_table(pbp_all %>% filter(gameId %in% v1_info$ids))))

  report_lines <- render_reconciliation_report(res, v1)
  dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
  writeLines(report_lines, file.path(OUTPUT_DIR, "reconciliation_report.md"))
  message("Wrote ", file.path(OUTPUT_DIR, "reconciliation_report.md"))

  baseline_csv <- purrr::imap_dfr(res, function(r, st) {
    tibble(season_type = st, games = r$games, cdn_rows = r$cdn_rows, v2_rows = r$v2_rows,
           shotdetail_rows = r$shotdetail_rows, team_games = r$team_games,
           first_date = as.character(r$first_date), last_date = as.character(r$last_date),
           # Known cdn vs v2 source disagreement (sum of absolute per-team-game deltas);
           # tests compare to these stored values exactly, not to a loosened tolerance.
           v2_abs_delta_fga = sum(abs(r$reconciliation$FGA_delta), na.rm = TRUE),
           v2_abs_delta_fgm = sum(abs(r$reconciliation$FGM_delta), na.rm = TRUE),
           v2_abs_delta_ast = sum(abs(r$reconciliation$AST_delta), na.rm = TRUE),
           v2_abs_delta_fg3a = sum(abs(r$reconciliation$FG3A_delta), na.rm = TRUE),
           pin = PIN_SHORT)
  })
  dir.create(proj_path("data", "reference"), recursive = TRUE, showWarnings = FALSE)
  # preserve the column owned by R/04b (minutes_unreconciled_team_games) if it already exists
  bl_path <- proj_path("data", "reference", "pipeline_baseline.csv")
  if (file.exists(bl_path)) {
    old <- read_csv(bl_path, show_col_types = FALSE, col_types = cols(pin = "c", .default = col_guess()))
    if ("minutes_unreconciled_team_games" %in% names(old)) {
      baseline_csv <- baseline_csv %>%
        left_join(old %>% select(season_type, minutes_unreconciled_team_games), by = "season_type")
    }
  }
  write_csv(baseline_csv, bl_path)
  message("Wrote data/reference/pipeline_baseline.csv")

  invisible(list(res = res, v1 = v1))
}

if (sys.nframe() == 0) {
  main()
}
