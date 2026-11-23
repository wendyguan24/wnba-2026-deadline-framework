# 04b_analysis_tables.R
#
# Purpose: build the analysis-ready tables (parquet) that offseason questions
#   start from, on top of the reconciled R/01-R/04 outputs. Every table carries
#   `season` and `season_type` (regular / playoffs; the players table carries
#   season_type "both" and separate per-type minute columns). Regular season and
#   playoffs are separate populations: filter before modeling, do not pool.
#   See docs/data_dictionary.md for columns and caveats.
#
# Inputs:  <PROCESSED_DIR>/pbp_events.rds, possessions.rds, raw shotdetail CSVs
#          (game dates only), R/04_reconcile.R helpers, R/lib_player_box.R
# Outputs: <PROCESSED_DIR>/tables/{games,team_games,player_games,players,
#          possessions,pbp_events,shots}.parquet and
#          output/offseason/tables_report.md
#
# Run from the repo root after R/04. Requires the arrow package.

suppressMessages({library(tidyverse); library(arrow)})

if (!exists("PROCESSED_DIR")) source(file.path("R", "00_config.R"))
source(proj_path("R", "04_reconcile.R"))
source(proj_path("R", "lib_player_box.R"))

TABLES_DIR <- file.path(PROCESSED_DIR, "tables")

#' games: one row per game
build_games <- function(pbp, shotdetail_raw) {
  final <- pbp %>%
    group_by(gameId) %>%
    summarise(season_type = first(season_type), n_periods = as.integer(max(period)),
              home_pts = scoreHome[which.max(orderNumber)],
              away_pts = scoreAway[which.max(orderNumber)], .groups = "drop")
  final %>%
    inner_join(derive_home_away(pbp), by = "gameId") %>%
    inner_join(compute_game_dates(pbp, shotdetail_raw), by = "gameId") %>%
    transmute(game_id = gameId, season = SEASON, season_type, game_date,
              home_team, away_team, home_pts = as.integer(home_pts),
              away_pts = as.integer(away_pts), n_periods) %>%
    arrange(game_id)
}

#' team box counts per team-game from cdn events (team rebounds, team turnovers
#' included: counted by the event's teamTricode, not by player)
compute_team_box <- function(pbp) {
  ev <- pbp %>% filter(!is.na(teamTricode))
  ev %>%
    group_by(game_id = gameId, team = teamTricode) %>%
    summarise(
      FG3M = sum(actionType == "3pt" & shotResult == "Made"),
      FTM = sum(actionType == "freethrow" & shotResult == "Made"),
      FTA = sum(actionType == "freethrow"),
      OREB = sum(actionType == "rebound" & subType == "offensive"),
      DREB = sum(actionType == "rebound" & subType == "defensive"),
      STL = sum(actionType == "steal"),
      BLK = sum(actionType == "block"),
      TOV = sum(actionType == "turnover"),
      PF = sum(actionType == "foul" & subType %in% c("personal", "offensive")),
      .groups = "drop"
    )
}

#' team_games: one row per team per game
build_team_games <- function(pbp, possessions, games) {
  box <- compute_team_game_counts_cdn(pbp) %>% rename(game_id = gameId) %>%
    select(game_id, team, FGA, FGM, AST, FG3A) %>%
    left_join(compute_team_box(pbp), by = c("game_id", "team"))
  poss_n <- possessions %>% filter(outcome != "technical_ft") %>%
    count(game_id = gameId, team, name = "possessions")
  long <- bind_rows(
    games %>% transmute(game_id, season, season_type, team = home_team, opponent = away_team,
                        is_home = TRUE, pts = home_pts, opp_pts = away_pts),
    games %>% transmute(game_id, season, season_type, team = away_team, opponent = home_team,
                        is_home = FALSE, pts = away_pts, opp_pts = home_pts)
  )
  long %>%
    mutate(win = pts > opp_pts) %>%
    left_join(poss_n, by = c("game_id", "team")) %>%
    left_join(box, by = c("game_id", "team")) %>%
    arrange(game_id, desc(is_home))
}

#' player_games: one row per player per game, box via build_box() applied per game
build_player_games <- function(pbp) {
  pev <- pbp %>% filter(!is.na(personId), personId != 0, !is.na(playerName))
  box <- pev %>%
    split(.$gameId) %>%
    map_dfr(build_box, .id = "game_id") %>%
    mutate(game_id = as.numeric(game_id)) %>%
    select(-games)
  mn <- build_minutes(pev)
  out <- box %>%
    left_join(mn$minutes_by_game %>% rename(game_id = gameId), by = c("personId", "game_id")) %>%
    left_join(pev %>% distinct(game_id = gameId, season_type), by = "game_id") %>%
    transmute(game_id, season = SEASON, season_type, team, person_id = personId,
              player_name = playerName, minutes = replace_na(minutes, 0),
              across(c(FG2M, FG3M, FGM, FGA, FTM, FTA, OREB, DREB, AST, STL, BLK, TOV, PF,
                       PTS, poss_used, game_score))) %>%
    arrange(game_id, team, desc(minutes))
  list(player_games = out, gate_pass_rate = mn$gate_pass_rate, pev = pev)
}

#' players: one row per person_id
build_players <- function(player_games) {
  names_modal <- player_games %>% count(person_id, player_name) %>%
    group_by(person_id) %>% slice_max(n, n = 1, with_ties = FALSE) %>% ungroup() %>%
    select(person_id, player_name)
  agg <- player_games %>%
    group_by(person_id) %>%
    summarise(teams = paste(sort(unique(team)), collapse = ","),
              games = n_distinct(game_id),
              games_regular = n_distinct(game_id[season_type == "regular"]),
              games_playoffs = n_distinct(game_id[season_type == "playoffs"]),
              minutes_regular = sum(minutes[season_type == "regular"]),
              minutes_playoffs = sum(minutes[season_type == "playoffs"]),
              .groups = "drop")
  names_modal %>% left_join(agg, by = "person_id") %>%
    mutate(season = SEASON, season_type = "both", .before = 1) %>%
    arrange(person_id)
}

#' shots: one row per cdn field-goal attempt
build_shots <- function(pbp) {
  pbp %>%
    filter(actionType %in% c("2pt", "3pt"), !is.na(teamTricode)) %>%
    transmute(
      game_id = gameId, season = SEASON, season_type, order_number = orderNumber,
      team = teamTricode, person_id = personId, player_name = playerName,
      period, clock_seconds = parsed_clock_seconds,
      shot_type = actionType, sub_type = subType, descriptor,
      area, area_detail = areaDetail, side, shot_distance = shotDistance,
      x, y, x_legacy = xLegacy, y_legacy = yLegacy,
      made = shotResult == "Made",
      points = case_when(shotResult == "Made" & actionType == "3pt" ~ 3L,
                         shotResult == "Made" ~ 2L, TRUE ~ 0L),
      is_assisted = shotResult == "Made" & !is.na(assistPersonId),
      assist_person_id = assistPersonId,
      is_fastbreak, is_2ndchance, is_fromturnover, is_pointsinthepaint
    )
}

#' Invariant checks (same logic as tests/testthat/test-analysis-tables.R), as a table
check_invariants <- function(t) {
  tg <- t$team_games; g <- t$games; pg <- t$player_games; sh <- t$shots
  chk <- function(name, ok) tibble(check = name, passed = isTRUE(ok))
  tgj <- tg %>% left_join(g %>% select(game_id, n_periods), by = "game_id")
  pg_tg <- pg %>% group_by(game_id, team) %>%
    summarise(pts_p = sum(PTS), min_p = sum(minutes), .groups = "drop")
  j <- tgj %>% left_join(pg_tg, by = c("game_id", "team"))
  sh_pts <- sh %>% group_by(game_id, team) %>% summarise(fg_pts = sum(points), .groups = "drop")
  js <- tg %>% left_join(sh_pts, by = c("game_id", "team"))
  bind_rows(
    chk("games: game_id unique", !anyDuplicated(g$game_id)),
    chk("team_games: game_id+team unique", !anyDuplicated(tg[c("game_id", "team")])),
    chk("player_games: game_id+team+person_id unique", !anyDuplicated(pg[c("game_id", "team", "person_id")])),
    chk("every game has exactly 2 team_games", all(count(tg, game_id)$n == 2)),
    chk("team_games pts equals games home/away pts",
        all(tg$pts == if_else(tg$is_home, g$home_pts[match(tg$game_id, g$game_id)],
                              g$away_pts[match(tg$game_id, g$game_id)]))),
    chk("sum of player_games PTS per team-game equals team_games pts", all(j$pts_p == j$pts)),
    chk("sum of player minutes per team-game within 1 minute of 200 + 25*(n_periods-4)",
        all(abs(j$min_p - (200 + 25 * (j$n_periods - 4))) <= 1)),
    chk("season_type never NA in any table", !anyNA(g$season_type) && !anyNA(tg$season_type) &&
          !anyNA(pg$season_type) && !anyNA(sh$season_type)),
    chk("shots made-points per team-game equals team pts minus FTM", all(js$fg_pts == js$pts - js$FTM))
  )
}

main <- function() {
  pbp <- readRDS(file.path(PROCESSED_DIR, "pbp_events.rds"))
  possessions <- readRDS(file.path(PROCESSED_DIR, "possessions.rds"))
  sd_all <- map_dfr(names(SEASON_TYPES), ~ read_csv(raw_csv("shotdetail", .x), show_col_types = FALSE, guess_max = 100000))

  games <- build_games(pbp, sd_all)
  team_games <- build_team_games(pbp, possessions, games)
  pgres <- build_player_games(pbp)
  player_games <- pgres$player_games
  players <- build_players(player_games)
  shots <- build_shots(pbp)
  t <- list(games = games, team_games = team_games, player_games = player_games,
            players = players,
            possessions = possessions %>% mutate(season = SEASON, .before = 1),
            pbp_events = pbp %>% mutate(season = SEASON, .before = 1),
            shots = shots)

  dir.create(TABLES_DIR, recursive = TRUE, showWarnings = FALSE)
  iwalk(t, ~ write_parquet(.x, file.path(TABLES_DIR, paste0(.y, ".parquet"))))

  # minutes gate (R/13's 5-on-court gate), per season type, and the per-team-game
  # minutes check; reported, not enforced here
  gate_by_type <- map_dbl(names(SEASON_TYPES), function(st)
    build_minutes(pgres$pev %>% filter(season_type == st))$gate_pass_rate) %>% set_names(names(SEASON_TYPES))
  min_check <- team_games %>% left_join(games %>% select(game_id, n_periods), by = "game_id") %>%
    left_join(player_games %>% group_by(game_id, team) %>% summarise(min_p = sum(minutes), .groups = "drop"),
              by = c("game_id", "team")) %>%
    mutate(expected = 200 + 25 * (n_periods - 4), off = abs(min_p - expected) > 1)
  inv <- check_invariants(t)

  counts <- imap_dfr(t, function(df, nm) {
    if (nm == "players") return(tibble(table = nm, season_type = "both", rows = nrow(df)))
    df %>% count(season_type, name = "rows") %>% mutate(table = nm, .before = 1)
  })
  md <- function(df) c(paste0("| ", paste(names(df), collapse = " | "), " |"),
                       paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
                       apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
  lines <- c(
    "# Analysis tables report", "",
    paste0("Generated: ", format(Sys.time(), tz = "UTC", usetz = TRUE), ". Pin ", PIN_SHORT, "."), "",
    "## Row counts per table and season type", "",
    md(counts %>% mutate(across(everything(), as.character))), "",
    "## Invariant results", "",
    md(inv %>% mutate(passed = if_else(passed, "PASS", "FAIL"))), "",
    "## Minutes gate (R/13 rule: exactly 5 on court per team-period)", "",
    paste0("Pass rate, ", names(gate_by_type), ": ", sprintf("%.4f", gate_by_type)),
    paste0("Team-games whose summed player minutes are more than 1 minute from 200 + 25*(n_periods-4): ",
           sum(min_check$off), " of ", nrow(min_check), " (", sprintf("%.2f%%", 100 * mean(min_check$off)), ")."),
    paste0("Largest absolute deviation: ", sprintf("%.2f", max(abs(min_check$min_p - min_check$expected))), " minutes.")
  )
  writeLines(lines, file.path(OUTPUT_DIR, "tables_report.md"))
  message("Wrote tables to ", TABLES_DIR, " and ", file.path(OUTPUT_DIR, "tables_report.md"))
  invisible(list(tables = t, invariants = inv, min_check = min_check))
}

if (sys.nframe() == 0) {
  main()
}
