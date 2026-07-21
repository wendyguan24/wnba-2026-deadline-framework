# 11_generation_gap.R
#
# Purpose: In-scope first part of the fit analysis -- names each team's
#   offensive shot-diet generation gap by ZONE against the league, labels each
#   gap zone, flags identity-driven gaps (a stable part of who the team is,
#   not a hole to fill), and assigns a fit mode. This is a generation-gap
#   attribution refinement of HANDOFF question 1 (what do we need), computed
#   entirely from the shot-diet side.
#
#   OUT OF SCOPE (post-deadline, see PLAN.md cut list): wins-over-replacement,
#   win-shares/RAPM, any player-value or dollar computation, candidate
#   matching. This script never touches those.
#
#   Method: for each team and zone, contribution(team, z) = (team_share(z) -
#   league_share(z)) * (league_pps(z) - mean_pps). The second factor is the
#   CENTERED league pps (league_pps(z) minus the overall league mean pps),
#   not the raw league pps -- centering is what makes each term's sign
#   interpretable (see decompose_generation_gap() below) while leaving the
#   per-team sum unchanged, because both team and league shares sum to 1
#   across zones.
#
#   Identity-driven flag: a gap zone is identity_driven when its mapped share
#   metric is ICC-eligible (icc >= 0.15 in output/icc_table.csv) AND the
#   team's z-score on that metric (within-metric z across the 15 teams, from
#   the identity BLUPs) has |z| >= 1.0 -- i.e. the over/under-weighting is a
#   stable, distinctive trait, a choice to protect rather than a gap to fill.
#
# Inputs:  data/processed/pbp_events.rds (shot events: actionType, shotResult,
#            area, teamTricode, gameId),
#          data/processed/team_generation_making.rds (team,
#            shot_generation_per100 -- the official generation percentile
#            source, kept consistent with the rest of the framework),
#          data/processed/team_blups.rds (metric, team, adjusted_value --
#            identity BLUPs for the identity-driven z-score check),
#          output/icc_table.csv (metric, icc -- the ICC >= 0.15
#            identity-eligibility floor)
# Outputs: output/generation_gap.csv, output/generation_gap.md

library(tidyverse)

ICC_ANCHOR_FLOOR <- 0.15  # same anchor rule as 08_deadline_read.R: only flag identity on metrics with ICC >= 0.15
IDENTITY_Z_FLOOR <- 1.0

ZONES <- c(
  "Restricted Area",
  "In The Paint (Non-RA)",
  "Mid-Range",
  "Corner 3",
  "Above the Break 3"
)

# Zone -> identity share metric in data/processed/team_blups.rds
ZONE_METRIC_MAP <- c(
  "Restricted Area" = "ra_share",
  "In The Paint (Non-RA)" = "paint_share",
  "Mid-Range" = "mid_share",
  "Corner 3" = "corner3_share",
  "Above the Break 3" = "atb3_share"
)

#' Build shot-level rows (one row per made-or-missed FG attempt) with points
#' scored and collapsed zone, from the raw pbp events table.
#'
#' @param pbp_events tibble, data/processed/pbp_events.rds
#' @return tibble, cols team (teamTricode), zone, points_scored
build_shot_rows <- function(pbp_events) {
  pbp_events %>%
    filter(actionType %in% c("2pt", "3pt")) %>%
    mutate(
      points_scored = case_when(
        shotResult != "Made" ~ 0,
        actionType == "3pt" ~ 3,
        TRUE ~ 2
      ),
      zone = case_when(
        area %in% c("Left Corner 3", "Right Corner 3") ~ "Corner 3",
        TRUE ~ area
      )
    ) %>%
    filter(zone %in% ZONES) %>%
    transmute(team = teamTricode, zone, points_scored)
}

#' Decompose each team's offensive shot-diet generation gap by zone versus
#' the league, using the centered-pps contribution formula (see file header).
#'
#' team_share(z) = team FGA in z / team total FGA
#' league_share(z) = league FGA in z / league total FGA
#' league_pps(z) = league mean points_scored per shot in z
#' mean_pps = overall league mean points_scored per shot (all FG)
#' contribution(team, z) = (team_share(z) - league_share(z)) * (league_pps(z) - mean_pps)
#'
#' Because team_share and league_share each sum to 1 across zones, centering
#' league_pps by mean_pps does not change sum_z contribution(team, z) -- it
#' only makes each per-zone term's sign interpretable:
#'   contribution < 0 from (team_share < league_share AND league_pps > mean_pps)
#'     -> under-weighting a high-value zone -> "missing efficient looks"
#'   contribution < 0 from (team_share > league_share AND league_pps < mean_pps)
#'     -> over-weighting a low-value zone -> "over-reliant on low-value looks"
#'
#' @param shot_rows tibble, from build_shot_rows()
#' @return tibble, one row per team-zone: team, zone, team_share, league_share,
#'   league_pps, mean_pps, contribution, type
decompose_generation_gap <- function(shot_rows) {
  mean_pps <- mean(shot_rows$points_scored)

  league_zone <- shot_rows %>%
    group_by(zone) %>%
    summarise(
      league_fga = n(),
      league_pps = mean(points_scored),
      .groups = "drop"
    ) %>%
    mutate(league_share = league_fga / sum(league_fga))

  team_zone <- shot_rows %>%
    group_by(team, zone) %>%
    summarise(team_fga = n(), .groups = "drop") %>%
    group_by(team) %>%
    mutate(team_share = team_fga / sum(team_fga)) %>%
    ungroup()

  # ensure every team has all 5 zones represented (0 share if a team never
  # shot from a given zone)
  all_team_zone <- expand_grid(
    team = unique(shot_rows$team),
    zone = ZONES
  ) %>%
    left_join(team_zone %>% select(team, zone, team_share), by = c("team", "zone")) %>%
    mutate(team_share = replace_na(team_share, 0))

  all_team_zone %>%
    left_join(league_zone %>% select(zone, league_share, league_pps), by = "zone") %>%
    mutate(
      mean_pps = mean_pps,
      contribution = (team_share - league_share) * (league_pps - mean_pps),
      type = case_when(
        contribution >= 0 ~ "",
        team_share < league_share & league_pps > mean_pps ~ "missing efficient looks",
        team_share > league_share & league_pps < mean_pps ~ "over-reliant on low-value looks",
        TRUE ~ "missing efficient looks"  # defensive fallback, should not trigger given the two cases above are exhaustive for contribution < 0
      )
    ) %>%
    select(team, zone, team_share, league_share, league_pps, mean_pps, contribution, type)
}

#' Flag each team-zone gap as identity_driven per the ICC + z-score anchor
#' rule (see file header).
#'
#' @param gap_table tibble, from decompose_generation_gap()
#' @param team_blups tibble, data/processed/team_blups.rds (metric, team, adjusted_value)
#' @param icc_table tibble, output/icc_table.csv (metric, icc)
#' @return tibble, gap_table with an added identity_driven logical column
flag_identity_driven <- function(gap_table, team_blups, icc_table) {
  eligible_metrics <- icc_table %>%
    filter(icc >= ICC_ANCHOR_FLOOR) %>%
    pull(metric)

  zone_metric <- tibble(
    zone = names(ZONE_METRIC_MAP),
    metric = unname(ZONE_METRIC_MAP)
  )

  z_scored <- team_blups %>%
    filter(metric %in% unname(ZONE_METRIC_MAP)) %>%
    group_by(metric) %>%
    mutate(z = as.numeric(scale(adjusted_value))) %>%
    ungroup() %>%
    select(team, metric, z)

  identity_flags <- zone_metric %>%
    left_join(z_scored, by = "metric") %>%
    mutate(
      metric_eligible = metric %in% eligible_metrics,
      identity_driven = metric_eligible & abs(z) >= IDENTITY_Z_FLOOR
    ) %>%
    select(team, zone, identity_driven)

  gap_table %>%
    left_join(identity_flags, by = c("team", "zone")) %>%
    mutate(identity_driven = replace_na(identity_driven, FALSE))
}

#' Assign each team a fit mode from its generation percentile and whether its
#' single most-negative gap zone is identity-driven (see file header).
#'
#' generation_pctile <= 33 (bottom tertile) AND the most-negative gap zone is
#' NOT identity_driven -> "gap-fill"
#' otherwise -> "style-amplify / protect"
#'
#' @param gap_table tibble, with identity_driven, from flag_identity_driven(),
#'   joined to generation_pctile
#' @return tibble, team, fit_mode
assign_fit_mode <- function(gap_table) {
  top_gap <- gap_table %>%
    group_by(team) %>%
    slice_min(contribution, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(team, generation_pctile, top_gap_identity_driven = identity_driven)

  top_gap %>%
    mutate(
      fit_mode = if_else(
        generation_pctile <= 33 & !top_gap_identity_driven,
        "gap-fill",
        "style-amplify / protect"
      )
    ) %>%
    select(team, fit_mode)
}

#' Build the full generation-gap table, one row per team-zone (5 zones per team)
#'
#' @param pbp_events tibble, data/processed/pbp_events.rds
#' @param team_generation_making tibble, data/processed/team_generation_making.rds
#' @param team_blups tibble, data/processed/team_blups.rds
#' @param icc_table tibble, output/icc_table.csv
#' @return list(gap_table = tibble with fit_mode joined in, fit_modes = tibble team/fit_mode)
build_generation_gap <- function(pbp_events, team_generation_making, team_blups, icc_table) {
  shot_rows <- build_shot_rows(pbp_events)

  gap_table <- decompose_generation_gap(shot_rows) %>%
    flag_identity_driven(team_blups, icc_table)

  generation_pctile_table <- team_generation_making %>%
    mutate(generation_pctile = round(percent_rank(shot_generation_per100) * 100)) %>%
    select(team, generation_pctile)

  gap_table <- gap_table %>%
    left_join(generation_pctile_table, by = "team")

  fit_modes <- assign_fit_mode(gap_table)

  gap_table_out <- gap_table %>%
    select(
      team, generation_pctile, zone, team_share, league_share, league_pps,
      contribution, type, identity_driven
    ) %>%
    arrange(team, zone)

  list(gap_table = gap_table_out, fit_modes = fit_modes)
}

#' Render the generation-gap markdown report
#'
#' @param gap_table tibble, from build_generation_gap()$gap_table
#' @param fit_modes tibble, from build_generation_gap()$fit_modes
#' @return character vector, markdown lines
render_generation_gap_md <- function(gap_table, fit_modes) {
  header <- c(
    "# WNBA 2026 Offensive Generation Gap by Zone",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    paste(
      "Each team's shot-diet generation gap versus the league is decomposed",
      "by zone using a centered-pps contribution: (team share minus league",
      "share) times (league pps minus overall mean pps), so per-zone signs",
      "are interpretable and the per-team sum equals that team's diet",
      "generation versus a league-average-diet team."
    ),
    ""
  )

  team_order <- fit_modes %>%
    arrange(team) %>%
    pull(team)

  team_blocks <- map(team_order, function(tm) {
    team_gaps <- gap_table %>% filter(team == tm)
    gen_pctile <- unique(team_gaps$generation_pctile)
    fit_mode <- fit_modes %>% filter(team == tm) %>% pull(fit_mode)

    top2 <- team_gaps %>%
      filter(contribution < 0) %>%
      arrange(contribution) %>%
      slice_head(n = 2)

    gap_lines <- if (nrow(top2) == 0) {
      "  - no negative-contribution zones"
    } else {
      top2 %>%
        mutate(
          identity_tag = if_else(identity_driven, " (identity-driven: protect)", ""),
          line = paste0(
            "  - ", zone, ": ", type,
            " (contribution: ", sprintf("%.3f", contribution), ")",
            identity_tag
          )
        ) %>%
        pull(line)
    }

    c(
      paste0("## ", tm),
      "",
      paste0("- Generation percentile: ", gen_pctile),
      paste0("- Fit mode: ", fit_mode),
      "- Top gap zones:",
      gap_lines,
      ""
    )
  }) %>%
    flatten_chr()

  caveats <- c(
    "## Caveats",
    "",
    paste(
      "This is a zone-level read: the alternative-stratification check found",
      "zone-only preserves team generation and making ranks (Spearman 0.98),",
      "so zone is a defensible grain, but a finer zone x context read would",
      "show transition vs halfcourt gaps."
    ),
    "",
    paste(
      "This reads only the offensive shot-diet side. The open play-by-play",
      "barely sees defense, rebounding value, or playmaking not expressed in",
      "shots, so these are offensive-generation gaps, not all roster gaps."
    )
  )

  c(header, team_blocks, caveats)
}

main <- function() {
  pbp_events <- readRDS("data/processed/pbp_events.rds")
  team_generation_making <- readRDS("data/processed/team_generation_making.rds")
  team_blups <- readRDS("data/processed/team_blups.rds")
  icc_table <- readr::read_csv("output/icc_table.csv", show_col_types = FALSE)

  result <- build_generation_gap(pbp_events, team_generation_making, team_blups, icc_table)
  gap_table <- result$gap_table
  fit_modes <- result$fit_modes

  write_csv(gap_table, "output/generation_gap.csv")
  writeLines(render_generation_gap_md(gap_table, fit_modes), "output/generation_gap.md")

  message("Fit mode by team (top gap zone shown):")
  top_gap_zone <- gap_table %>%
    group_by(team) %>%
    slice_min(contribution, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    left_join(fit_modes, by = "team") %>%
    select(team, fit_mode, top_gap_zone = zone, contribution)
  print(top_gap_zone, n = Inf)

  invisible(gap_table)
}

if (sys.nframe() == 0) {
  main()
}
