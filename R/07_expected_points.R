# 07_expected_points.R
#
# Purpose: Build a stratified expected-points baseline (NOT a trained model --
#   a trained xPTS model is explicitly out of scope this cycle, see HANDOFF
#   §6 cut list). League-average points per shot by zone x shot class x
#   context (transition/halfcourt/second-chance), computed from 2026 data (or
#   2024-25 historicals as priors, analyst's choice -- state which was used).
#   Then per team: shot generation (expected PTS/100 given shot diet) vs.
#   shot making (actual - expected PTS/100).
#   See HANDOFF §5d. Methodology note must call this a "stratified
#   expected-points baseline (qSQ-lite)," never a "shot-quality model."
#
# Inputs:  data/processed/pbp_events.rds (cdn source: shot events with
#            x/y, area, areaDetail, descriptor, is_fastbreak, is_2ndchance),
#          data/processed/possessions.rds (possession counts per team-game).
#          (shotdetail was considered as a shot-geometry source and rejected:
#           the EDA gate found it covers only 14 of 15 teams, so every
#           shot-level feature in this framework is built from cdn instead.)
# Outputs: data/processed/expected_points_baseline.rds,
#          data/processed/team_generation_making.rds (+ output/team_generation_making.csv, season-level, per team),
#          data/processed/team_game_shot_making.rds (team-game level, feeds
#            the 06_models.R trajectory layer).

library(tidyverse)

# The baseline is computed from 2026 in-season shots only; 2024-25
# historicals were available as priors but were not used, to keep the
# baseline on the same population the team reads are drawn from and to
# avoid new data acquisition at the deadline.

# IDENTITY-style constants -----------------------------------------------
# Minimum shots required for a (zone, shot_class, context) cell to stand on
# its own. With ~24,794 league FGA a full cell at N=100 has a mean-PPS
# standard error near 0.10 (per-shot points SD is close to 1.0), tight
# enough for a lookup baseline; 100 is a round floor thin cells fall through.
MIN_CELL_N <- 100L

#' Build the league-average points-per-shot baseline stratified by
#' zone x shot class x context
#'
#' Collapse cascade is full cell -> zone x context -> zone -> global; zone
#' is never dropped before shot_class/context because zone is the dominant
#' points-per-shot driver.
#'
#' @param shots tibble, shot-level data with zone, shot class, context flags
#' @return tibble, one row per (zone, shot_class, context) stratum, with
#'   league-average points per shot
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

#' Attach the xpts lookup value to each shot by (zone, shot_class, context)
#'
#' @param shots tibble, shot-level data
#' @param xpts_table tibble, output of build_xpts_table()
#' @return tibble, shots with an xpts column joined on
attach_xpts <- function(shots, xpts_table) {
  shots %>% left_join(xpts_table %>% select(zone, shot_class, context, xpts),
                      by = c("zone", "shot_class", "context"))
}

#' Count possessions, excluding technical free throws, at either team-game
#' or season/per-team grain (matches 05_features.R's pace_poss basis).
#'
#' @param possessions tibble
#' @param by_game logical, TRUE for team-game grain, FALSE for season grain
#' @return tibble, poss_count per (gameId, team) or per team
poss_counts <- function(possessions, by_game = TRUE) {
  base <- possessions %>% filter(outcome != "technical_ft")
  if (by_game) count(base, gameId, team, name = "poss_count")
  else         count(base, team, name = "poss_count")
}

#' Compute each team's shot generation (process quality, expected PTS/100
#' given shot diet) and shot making (actual - expected PTS/100) at the
#' TEAM-GAME grain. This feeds the R/06 trajectory layer.
#'
#' @param shots tibble, shot-level data
#' @param xpts_table tibble, output of build_xpts_table()
#' @param possessions tibble
#' @return tibble, one row per team-game
compute_shot_making <- function(shots, xpts_table, possessions) {
  attach_xpts(shots, xpts_table) %>%
    group_by(gameId, team) %>%
    summarise(fga = n(),
              expected_pts = sum(xpts),
              actual_pts   = sum(points_scored), .groups = "drop") %>%
    left_join(poss_counts(possessions, by_game = TRUE), by = c("gameId", "team")) %>%
    mutate(
      shot_generation_per100 = expected_pts / poss_count * 100,
      shot_making_residual   = (actual_pts - expected_pts) / poss_count * 100
    ) %>%
    select(gameId, team, fga, poss_count, expected_pts, actual_pts,
           shot_generation_per100, shot_making_residual)
}

#' Compute each team's shot generation and shot making at the
#' SEASON/per-team grain.
#'
#' @param shots tibble, shot-level data
#' @param xpts_table tibble, output of build_xpts_table()
#' @param possessions tibble
#' @return tibble, one row per team
compute_shot_generation <- function(shots, xpts_table, possessions) {
  attach_xpts(shots, xpts_table) %>%
    group_by(team) %>%
    summarise(fga = n(),
              expected_pts = sum(xpts),
              actual_pts   = sum(points_scored), .groups = "drop") %>%
    left_join(poss_counts(possessions, by_game = FALSE), by = "team") %>%
    mutate(
      shot_generation_per100 = expected_pts / poss_count * 100,
      shot_making_per100     = (actual_pts - expected_pts) / poss_count * 100,
      actual_pts_per100      = actual_pts / poss_count * 100
    ) %>%
    select(team, fga, poss_count, expected_pts, actual_pts,
           shot_generation_per100, shot_making_per100, actual_pts_per100)
}

# Reporting is per 100 possessions (matches HANDOFF §5d "expected PTS/100
# possessions"); the xpts lookup itself stays per-shot.

main <- function() {
  pbp <- readRDS("data/processed/pbp_events.rds")
  possessions <- readRDS("data/processed/possessions.rds")

  # FG-only: free throws are excluded because they are foul-triggered, not
  # a shot chosen from a diet, so they do not belong in an expected-points
  # baseline.
  shots <- pbp %>%
    filter(actionType %in% c("2pt", "3pt")) %>%
    transmute(
      gameId,
      team  = teamTricode,
      made  = shotResult == "Made",
      points_scored = case_when(!made ~ 0, actionType == "3pt" ~ 3, TRUE ~ 2),
      zone = case_when(
        area %in% c("Left Corner 3", "Right Corner 3") ~ "Corner 3",
        TRUE ~ area
      ),
      # shot_class precedence putback > cutting > driving > pullup > other:
      # first match wins so a descriptor that names several resolves to the
      # most rim-proximal / most specific label; shots naming none (incl. NA
      # descriptor) fall to "other", a real stratum, never dropped.
      shot_class = case_when(
        str_detect(coalesce(descriptor, ""), "putback") ~ "putback",
        str_detect(coalesce(descriptor, ""), "cutting") ~ "cutting",
        str_detect(coalesce(descriptor, ""), "driving") ~ "driving",
        str_detect(coalesce(descriptor, ""), "pullup")  ~ "pullup",
        TRUE ~ "other"
      ),
      context = case_when(
        coalesce(is_fastbreak, FALSE)  ~ "transition",
        coalesce(is_2ndchance, FALSE)  ~ "second_chance",
        TRUE ~ "halfcourt"
      )
    )

  xpts_table <- build_xpts_table(shots)
  team_game  <- compute_shot_making(shots, xpts_table, possessions)
  season     <- compute_shot_generation(shots, xpts_table, possessions)

  dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
  dir.create("output", recursive = TRUE, showWarnings = FALSE)
  saveRDS(xpts_table, "data/processed/expected_points_baseline.rds")
  saveRDS(season,     "data/processed/team_generation_making.rds")
  saveRDS(team_game,  "data/processed/team_game_shot_making.rds")
  # Readable export of the season generation/making table so downstream prose
  # can cite shot_making_per100 (its sign is what makes the H3 read) without
  # opening the binary .rds.
  readr::write_csv(season, "output/team_generation_making.csv")

  message("Wrote expected_points_baseline.rds (", nrow(xpts_table), " strata), ",
          "team_generation_making.rds + output/team_generation_making.csv (", nrow(season), " teams), ",
          "team_game_shot_making.rds (", nrow(team_game), " team-games)")

  invisible(list(xpts_table = xpts_table, season = season, team_game = team_game))
}

if (sys.nframe() == 0) {
  main()
}
