# 22_wehoop_expected_points.R
#
# Purpose: Build a stratified expected-points baseline from full-season
#   wehoop shot data -- the wehoop analogue of R/07_expected_points.R. League
#   points per shot by zone x shot-creation profile x context, then per team:
#   shot generation (expected PTS/100 given shot diet) vs. shot making
#   (actual - expected PTS/100). This is a lookup baseline, never a trained
#   model -- see CLAUDE.md vocabulary discipline ("stratified expected-points
#   baseline," never a "shot-quality model").
#
#   Context caveat: stats_shots.csv carries no possession_number, so
#   individual shots cannot be linked to individual possessions in
#   stats_possessions.csv. Every shot is therefore coded context =
#   "halfcourt" here -- second_chance/transition splitting is not available
#   at the shot level with this data contract. Team-level secondchance_share
#   and transition_share (possession-grain, not shot-grain) are still
#   available from R/19_wehoop_team_features.R via stats_possessions.csv
#   directly. Because context never varies, the zone x context and
#   zone x shot_class x context collapse levels below collapse to zone and
#   zone x shot_class respectively -- documented, not a bug.
#
# Inputs:  data/wehoop/stats_shots.csv, data/wehoop/live/shot_zones.csv
#          (optional -- zones derived from x_legacy/y_legacy if absent or
#          for any shot that doesn't match), data/wehoop/stats_possessions.csv,
#          data/wehoop/team_lookup.rds
# Outputs: output/wehoop/expected_points_baseline.rds -- league xpts per
#            (zone, shot_class, context) stratum
#          output/wehoop/team_generation_making.csv -- one row per team:
#            generation per 100, making per 100, actual per 100
#          output/wehoop/team_game_shot_making.rds -- one row per team-game
#            (feeds trajectory in R/23_wehoop_trajectory.R)

library(dplyr)
library(readr)
library(stringr)

DATA_DIR <- file.path("data", "wehoop")
LIVE_DIR <- file.path(DATA_DIR, "live")
OUT_DIR  <- file.path("output", "wehoop")

# Minimum shots required for a (zone, shot_class, context) cell to stand on
# its own before falling back to a coarser stratum. Matches
# R/07_expected_points.R's threshold.
MIN_CELL_N <- 100L

#' Read a required CSV, stopping with a helpful pointer if it is missing.
#'
#' @param path character
#' @param hint character, which upstream script produces it
#' @return tibble
read_required_csv <- function(path, hint) {
  if (!file.exists(path)) {
    stop(sprintf("%s not found. Run %s first.", path, hint))
  }
  read_csv(path, show_col_types = FALSE)
}

#' Coerce a set of id columns to character so joins never fail on
#' numeric-vs-character type mismatches.
#'
#' @param df tibble
#' @param cols character vector of column names present in df
#' @return tibble
ids_as_character <- function(df, cols) {
  cols <- intersect(cols, names(df))
  df %>% mutate(across(all_of(cols), as.character))
}

#' Classify shots into shot-creation profiles from action_type + sub_type.
#' Precedence putback > cutting > driving > pullup > other, identical to
#' R/19_wehoop_team_features.R's classify_shot_creation().
#'
#' @param action_type character vector
#' @param sub_type character vector
#' @return character vector of shot-creation profile labels
classify_shot_creation <- function(action_type, sub_type) {
  action_text <- str_c(coalesce(action_type, ""), " ", coalesce(sub_type, ""))
  case_when(
    str_detect(action_text, regex("putback", ignore_case = TRUE)) ~ "putback",
    str_detect(action_text, regex("cut", ignore_case = TRUE)) ~ "cutting",
    str_detect(action_text, regex("driving|layup", ignore_case = TRUE)) ~ "driving",
    str_detect(action_text, regex("pullup|pull-up|pull up", ignore_case = TRUE)) ~ "pullup",
    TRUE ~ "other"
  )
}

#' Map live/shot_zones.csv's shot_zone values to the project's zone labels.
#'
#' @param shot_zone character vector, raw shot_zone values
#' @return character vector of zone labels, NA where unrecognized
map_zone_label <- function(shot_zone) {
  case_when(
    shot_zone == "restricted_area" ~ "Restricted Area",
    shot_zone == "in_the_paint_non_ra" ~ "In The Paint (Non-RA)",
    shot_zone == "mid_range" ~ "Mid-Range",
    shot_zone == "corner_3" ~ "Corner 3",
    shot_zone == "above_the_break_3" ~ "Above the Break 3",
    TRUE ~ NA_character_
  )
}

#' Derive a zone label directly from x_legacy/y_legacy/shot_distance/
#' shot_value when live/shot_zones.csv is missing or doesn't cover a shot.
#' Boundaries: corner 3 is abs(x) >= 220 & y <= 87.5 (the standard corner-3
#' geometry cutoff); any other 3 is above-the-break; inside 4 ft is
#' restricted area, inside 14 ft is non-RA paint, beyond that is mid-range.
#' This is an approximation, not the Stats API's own zone classifier.
#'
#' @param x_legacy numeric vector
#' @param y_legacy numeric vector
#' @param shot_distance numeric vector
#' @param shot_value numeric vector, 2 or 3
#' @return character vector of zone labels
derive_zone_from_xy <- function(x_legacy, y_legacy, shot_distance, shot_value) {
  case_when(
    shot_value == 3 & abs(x_legacy) >= 220 & y_legacy <= 87.5 ~ "Corner 3",
    shot_value == 3 ~ "Above the Break 3",
    shot_distance <= 4 ~ "Restricted Area",
    shot_distance <= 14 ~ "In The Paint (Non-RA)",
    TRUE ~ "Mid-Range"
  )
}

#' Prepare shot-level data: FG-only, made/points_scored, zone (joined from
#' live/shot_zones.csv where possible, derived from x/y otherwise),
#' shot_class, and context (always "halfcourt" -- see file header caveat).
#'
#' @param shots_raw tibble, raw stats_shots.csv
#' @param shot_zones_raw tibble or NULL, raw live/shot_zones.csv
#' @return tibble, one row per FG attempt
prepare_shots <- function(shots_raw, shot_zones_raw) {
  shots <- shots_raw %>%
    ids_as_character(c("game_id", "team_id", "player_id")) %>%
    filter(shot_value %in% c(2, 3)) %>%
    mutate(
      made = str_detect(coalesce(shot_result, ""), regex("made", ignore_case = TRUE)),
      points_scored = if_else(made, shot_value, 0),
      shot_class = classify_shot_creation(action_type, sub_type),
      # Every shot is coded halfcourt -- see file header caveat on why
      # second_chance/transition can't be linked at the shot level here.
      context = "halfcourt",
      derived_zone = derive_zone_from_xy(x_legacy, y_legacy, shot_distance, shot_value)
    )

  if (is.null(shot_zones_raw)) {
    message("  NOTE: live/shot_zones.csv not supplied; all zones derived from x_legacy/y_legacy")
    return(shots %>% mutate(zone = derived_zone) %>% select(-derived_zone))
  }

  zones <- shot_zones_raw %>%
    ids_as_character(c("game_id", "team_id", "player_id")) %>%
    transmute(game_id, player_id, x_legacy, y_legacy, zone_lookup = map_zone_label(shot_zone))

  # Defensive dedupe key: same (game_id, player_id, x_legacy, y_legacy) can
  # repeat within a game (two shots from the same exact spot), so a plain
  # join would multiply rows. shot_seq breaks ties by within-group order on
  # both sides before joining.
  shots_keyed <- shots %>%
    group_by(game_id, player_id, x_legacy, y_legacy) %>%
    mutate(shot_seq = row_number()) %>%
    ungroup()

  zones_keyed <- zones %>%
    group_by(game_id, player_id, x_legacy, y_legacy) %>%
    mutate(shot_seq = row_number()) %>%
    ungroup() %>%
    distinct(game_id, player_id, x_legacy, y_legacy, shot_seq, .keep_all = TRUE)

  joined <- shots_keyed %>%
    left_join(zones_keyed, by = c("game_id", "player_id", "x_legacy", "y_legacy", "shot_seq"))

  n_fallback <- sum(is.na(joined$zone_lookup))
  if (n_fallback > 0) {
    message(sprintf(
      "  NOTE: %d of %d shots had no live/shot_zones.csv match; zone derived from x_legacy/y_legacy for those",
      n_fallback, nrow(joined)
    ))
  }

  joined %>%
    mutate(zone = coalesce(zone_lookup, derived_zone)) %>%
    select(-zone_lookup, -derived_zone, -shot_seq)
}

#' Build the league-average points-per-shot baseline stratified by
#' zone x shot_class x context. Collapse cascade is full cell ->
#' zone x context -> zone -> global, identical to
#' R/07_expected_points.R's build_xpts_table().
#'
#' @param shots tibble, prepared shot-level data (zone, shot_class, context,
#'   points_scored)
#' @return tibble, one row per (zone, shot_class, context) stratum
build_xpts_table <- function(shots) {
  cell <- shots %>%
    group_by(zone, shot_class, context) %>%
    summarise(n_cell = n(), pps_cell = mean(points_scored), .groups = "drop")
  zc <- shots %>%
    group_by(zone, context) %>%
    summarise(n_zc = n(), pps_zc = mean(points_scored), .groups = "drop")
  z <- shots %>%
    group_by(zone) %>%
    summarise(n_z = n(), pps_z = mean(points_scored), .groups = "drop")
  pps_global <- mean(shots$points_scored)
  n_global   <- nrow(shots)

  cell %>%
    left_join(zc, by = c("zone", "context")) %>%
    left_join(z,  by = "zone") %>%
    mutate(
      source_level = case_when(
        n_cell >= MIN_CELL_N ~ "full",
        n_zc   >= MIN_CELL_N ~ "zone_context",
        n_z    >= MIN_CELL_N ~ "zone",
        TRUE                 ~ "global"
      ),
      xpts = case_when(
        source_level == "full"         ~ pps_cell,
        source_level == "zone_context" ~ pps_zc,
        source_level == "zone"         ~ pps_z,
        TRUE                           ~ pps_global
      ),
      n_source = case_when(
        source_level == "full"         ~ n_cell,
        source_level == "zone_context" ~ n_zc,
        source_level == "zone"         ~ n_z,
        TRUE                           ~ n_global
      )
    ) %>%
    select(zone, shot_class, context, n_cell, xpts, source_level, n_source)
}

#' Attach the xpts lookup value to each shot by (zone, shot_class, context).
#'
#' @param shots tibble, prepared shot-level data
#' @param xpts_table tibble, output of build_xpts_table()
#' @return tibble, shots with an xpts column joined on
attach_xpts <- function(shots, xpts_table) {
  shots %>% left_join(xpts_table %>% select(zone, shot_class, context, xpts),
                       by = c("zone", "shot_class", "context"))
}

#' Count possessions per (game_id, offense team) or per offense team for the
#' season, matching R/19_wehoop_team_features.R's real_possessions() filter.
#'
#' @param possessions tibble, raw stats_possessions.csv
#' @param by_game logical, TRUE for team-game grain, FALSE for season grain
#' @return tibble, poss_count per (game_id, team_id) or per team_id
poss_counts <- function(possessions, by_game = TRUE) {
  possessions <- possessions %>% ids_as_character(c("game_id", "offense_team_id"))
  base <- if ("count_as_possession" %in% names(possessions)) {
    possessions %>% filter(count_as_possession == TRUE)
  } else {
    possessions
  }
  if (by_game) {
    base %>% count(game_id, team_id = offense_team_id, name = "poss_count")
  } else {
    base %>% count(team_id = offense_team_id, name = "poss_count")
  }
}

#' Compute each team's shot generation (expected PTS/100 given shot diet)
#' and shot making (actual - expected PTS/100) at the TEAM-GAME grain. This
#' feeds R/23_wehoop_trajectory.R.
#'
#' @param shots tibble, prepared shot-level data
#' @param xpts_table tibble, output of build_xpts_table()
#' @param possessions tibble, raw stats_possessions.csv
#' @return tibble, one row per team-game
compute_team_game_shot_making <- function(shots, xpts_table, possessions) {
  attach_xpts(shots, xpts_table) %>%
    group_by(game_id, team_id) %>%
    summarise(fga = n(), expected_pts = sum(xpts), actual_pts = sum(points_scored), .groups = "drop") %>%
    left_join(poss_counts(possessions, by_game = TRUE), by = c("game_id", "team_id")) %>%
    mutate(
      shot_generation_per100 = expected_pts / poss_count * 100,
      shot_making_residual   = (actual_pts - expected_pts) / poss_count * 100
    ) %>%
    select(game_id, team_id, fga, poss_count, expected_pts, actual_pts,
           shot_generation_per100, shot_making_residual)
}

#' Compute each team's shot generation and shot making at the SEASON grain.
#'
#' @param shots tibble, prepared shot-level data
#' @param xpts_table tibble, output of build_xpts_table()
#' @param possessions tibble, raw stats_possessions.csv
#' @return tibble, one row per team
compute_season_generation_making <- function(shots, xpts_table, possessions) {
  attach_xpts(shots, xpts_table) %>%
    group_by(team_id) %>%
    summarise(fga = n(), expected_pts = sum(xpts), actual_pts = sum(points_scored), .groups = "drop") %>%
    left_join(poss_counts(possessions, by_game = FALSE), by = "team_id") %>%
    mutate(
      shot_generation_per100 = expected_pts / poss_count * 100,
      shot_making_per100     = (actual_pts - expected_pts) / poss_count * 100,
      actual_pts_per100      = actual_pts / poss_count * 100
    ) %>%
    select(team_id, fga, poss_count, expected_pts, actual_pts,
           shot_generation_per100, shot_making_per100, actual_pts_per100)
}

# Reporting is per 100 possessions, matching R/07_expected_points.R; the
# xpts lookup itself stays per-shot.

main <- function() {
  shots_raw <- read_required_csv(file.path(DATA_DIR, "stats_shots.csv"), "R/15_wehoop_download.R")
  possessions <- read_required_csv(file.path(DATA_DIR, "stats_possessions.csv"), "R/15_wehoop_download.R")

  lookup_path <- file.path(DATA_DIR, "team_lookup.rds")
  if (!file.exists(lookup_path)) {
    stop(sprintf("%s not found. Run R/17_wehoop_scaffold.R first.", lookup_path))
  }
  team_lookup <- readRDS(lookup_path)

  shot_zones_path <- file.path(LIVE_DIR, "shot_zones.csv")
  shot_zones_raw <- if (file.exists(shot_zones_path)) {
    read_csv(shot_zones_path, show_col_types = FALSE)
  } else {
    NULL
  }

  shots <- prepare_shots(shots_raw, shot_zones_raw)

  xpts_table <- build_xpts_table(shots)
  team_game  <- compute_team_game_shot_making(shots, xpts_table, possessions)
  season     <- compute_season_generation_making(shots, xpts_table, possessions)

  team_names <- team_lookup %>% select(team_id, team = tricode)
  team_game <- team_game %>% left_join(team_names, by = "team_id") %>%
    select(game_id, team, team_id, fga, poss_count, expected_pts, actual_pts,
           shot_generation_per100, shot_making_residual)
  season <- season %>% left_join(team_names, by = "team_id") %>%
    select(team, team_id, fga, poss_count, expected_pts, actual_pts,
           shot_generation_per100, shot_making_per100, actual_pts_per100)

  dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
  saveRDS(xpts_table, file.path(OUT_DIR, "expected_points_baseline.rds"))
  saveRDS(team_game,  file.path(OUT_DIR, "team_game_shot_making.rds"))
  write_csv(season, file.path(OUT_DIR, "team_generation_making.csv"))

  message(sprintf(
    "Wrote expected_points_baseline.rds (%d strata), team_generation_making.csv (%d teams), team_game_shot_making.rds (%d team-games)",
    nrow(xpts_table), nrow(season), nrow(team_game)
  ))

  invisible(list(xpts_table = xpts_table, team_game = team_game, season = season))
}

if (sys.nframe() == 0) {
  main()
}
