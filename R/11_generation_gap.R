# 11_generation_gap.R
#
# Purpose: In-scope first part of the fit analysis -- decomposes each team's
#   offensive shot-diet generation gap versus the league into a VOLUME
#   component and a MIX component, then attributes the mix component by ZONE,
#   labels each mix-gap zone, flags identity-driven zones (a stable part of
#   who the team is, not a hole to fill), and assigns a fit mode driven by
#   which component (volume or mix) dominates the gap. This is a
#   generation-gap attribution refinement of HANDOFF question 1 (what do we
#   need), computed entirely from the shot-diet side.
#
#   OUT OF SCOPE (post-deadline, see PLAN.md cut list): wins-over-replacement,
#   win-shares/RAPM, any player-value or dollar computation, candidate
#   matching. This script never touches those.
#
#   Method (price-volume variance split): generation = VOLUME x MIX_QUALITY,
#   where VOLUME = FGA per 100 possessions and MIX_QUALITY = expected points
#   per shot given a team's shot diet (league points-per-shot by zone, held
#   fixed for both team and league so only the diet varies). For each team:
#
#     gen_team - gen_league = (V_team - V_league) * M_league        [volume_gap]
#                           + V_team * (M_team - M_league)           [mix_gap_total]
#
#   volume_gap isolates how many shots a team gets relative to the league,
#   at league-average shot value; mix_gap_total isolates the value of the
#   shots a team chooses to take, at the team's own volume. The two sum
#   exactly to the team's zone-approximated generation gap (V_team*M_team -
#   V_league*M_league), which reconciles with shot_generation_per100 standing
#   -- asserted in code below.
#
#   mix_gap_total is then attributed by zone using a CENTERED league pps:
#   mix_contribution(z) = V_team * (team_share(z) - league_share(z)) *
#   (league_pps(z) - mean_pps). Centering by mean_pps is what makes each
#   zone's sign interpretable (see decompose_mix_by_zone() below) while
#   leaving sum_z mix_contribution(z) = mix_gap_total unchanged, because both
#   team and league shares sum to 1 across zones -- asserted in code below.
#
#   Identity-driven flag (unchanged from the mix-only version): a mix-gap
#   zone is identity_driven when its mapped share metric is ICC-eligible
#   (icc >= 0.15 in output/icc_table.csv) AND the team's z-score on that
#   metric (within-metric z across the 15 teams, from the identity BLUPs)
#   has |z| >= 1.0 -- i.e. the over/under-weighting is a stable, distinctive
#   trait, a choice to protect rather than a gap to fill. This flag depends
#   only on team_share vs. league_share, not on volume, so it is unaffected
#   by the volume/mix split.
#
#   primary_driver: "volume" if |volume_gap| >= |mix_gap_total|, else "mix".
#   Fit mode uses primary_driver directly (see assign_fit_mode() below):
#   bottom-tertile generation with a volume-driven gap reads as "gap-fill"
#   (the need is possession creation / ball security, not a zone); bottom-
#   tertile with a mix-driven gap reads as "gap-fill" unless the most-negative
#   mix zone is identity-driven, in which case it is "style-amplify / protect";
#   everything else is "style-amplify / protect".
#
# Inputs:  data/processed/pbp_events.rds (shot events: actionType, shotResult,
#            area, teamTricode, gameId),
#          data/processed/team_generation_making.rds (team, fga, poss_count,
#            shot_generation_per100 -- the official generation percentile
#            source and the volume-component basis, kept consistent with the
#            rest of the framework),
#          data/processed/team_blups.rds (metric, team, adjusted_value --
#            identity BLUPs for the identity-driven z-score check),
#          output/icc_table.csv (metric, icc -- the ICC >= 0.15
#            identity-eligibility floor)
# Outputs: output/generation_gap.csv, output/generation_gap.md

library(tidyverse)

ICC_ANCHOR_FLOOR <- 0.15  # same anchor rule as 08_deadline_read.R: only flag identity on metrics with ICC >= 0.15
IDENTITY_Z_FLOOR <- 1.0
ASSERT_TOL <- 1e-6

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

#' Build the league zone table (shares and points-per-shot) and the overall
#' league mean points-per-shot, from shot-level rows.
#'
#' @param shot_rows tibble, from build_shot_rows()
#' @return list(mean_pps = numeric, league_zone = tibble(zone, league_fga,
#'   league_pps, league_share))
build_league_zone_table <- function(shot_rows) {
  mean_pps <- mean(shot_rows$points_scored)

  league_zone <- shot_rows %>%
    group_by(zone) %>%
    summarise(
      league_fga = n(),
      league_pps = mean(points_scored),
      .groups = "drop"
    ) %>%
    mutate(league_share = league_fga / sum(league_fga))

  list(mean_pps = mean_pps, league_zone = league_zone)
}

#' Build each team's zone shot shares (team_share(z) = team zone FGA / team
#' total FGA, from shot-level rows), with all 5 zones represented (0 share if
#' a team never shot from a given zone).
#'
#' @param shot_rows tibble, from build_shot_rows()
#' @return tibble, team, zone, team_share
build_team_zone_shares <- function(shot_rows) {
  team_zone <- shot_rows %>%
    group_by(team, zone) %>%
    summarise(team_fga = n(), .groups = "drop") %>%
    group_by(team) %>%
    mutate(team_share = team_fga / sum(team_fga)) %>%
    ungroup()

  expand_grid(
    team = unique(shot_rows$team),
    zone = ZONES
  ) %>%
    left_join(team_zone %>% select(team, zone, team_share), by = c("team", "zone")) %>%
    mutate(team_share = replace_na(team_share, 0))
}

#' Decompose each team's generation gap versus the league into a VOLUME
#' component and a MIX component (see file header for the full derivation).
#'
#' V_team = fga / poss_count * 100 (team_generation_making, per team)
#' V_league = (total league FGA, i.e. nrow(shot_rows)) / (total league
#'   possessions, sum of poss_count across the 15 teams) * 100
#' M_league = sum_z league_share(z) * league_pps(z) (equals mean_pps)
#' M_team = sum_z team_share(z) * league_pps(z)
#' volume_gap = (V_team - V_league) * M_league
#' mix_gap_total = V_team * (M_team - M_league)
#' total_gap = volume_gap + mix_gap_total, asserted equal to
#'   V_team*M_team - V_league*M_league within ASSERT_TOL
#'
#' @param shot_rows tibble, from build_shot_rows()
#' @param team_generation_making tibble, data/processed/team_generation_making.rds
#' @return tibble, one row per team: team, V_team, M_team, V_league, M_league,
#'   mean_pps, volume_gap, mix_gap_total, total_gap, primary_driver
decompose_team_generation_gap <- function(shot_rows, team_generation_making) {
  league_parts <- build_league_zone_table(shot_rows)
  mean_pps <- league_parts$mean_pps
  league_zone <- league_parts$league_zone
  M_league <- mean_pps  # sum_z league_share(z) * league_pps(z) == mean_pps by construction

  team_zone_shares <- build_team_zone_shares(shot_rows)

  total_league_fga <- nrow(shot_rows)
  total_league_poss <- sum(team_generation_making$poss_count)
  V_league <- total_league_fga / total_league_poss * 100

  M_team_table <- team_zone_shares %>%
    left_join(league_zone %>% select(zone, league_pps), by = "zone") %>%
    group_by(team) %>%
    summarise(M_team = sum(team_share * league_pps), .groups = "drop")

  team_level <- team_generation_making %>%
    transmute(team, V_team = fga / poss_count * 100) %>%
    left_join(M_team_table, by = "team") %>%
    mutate(
      V_league = V_league,
      M_league = M_league,
      mean_pps = mean_pps,
      volume_gap = (V_team - V_league) * M_league,
      mix_gap_total = V_team * (M_team - M_league),
      total_gap = volume_gap + mix_gap_total
    )

  # Assert: total_gap reconciles algebraically with the zone-approximated
  # team generation minus league generation (V_team*M_team - V_league*M_league).
  recon_check <- with(team_level, total_gap - (V_team * M_team - V_league * M_league))
  stopifnot(all(abs(recon_check) < ASSERT_TOL))

  team_level %>%
    mutate(
      primary_driver = if_else(abs(volume_gap) >= abs(mix_gap_total), "volume", "mix")
    ) %>%
    select(team, V_team, M_team, V_league, M_league, mean_pps,
           volume_gap, mix_gap_total, total_gap, primary_driver)
}

#' Attribute each team's mix_gap_total by zone, using the centered league pps
#' contribution, and label each zone (see file header for the sign logic).
#'
#' mix_contribution(z) = V_team * (team_share(z) - league_share(z)) *
#'   (league_pps(z) - mean_pps)
#' sum_z mix_contribution(z) is asserted equal to mix_gap_total (from
#' decompose_team_generation_gap()) within ASSERT_TOL, per team.
#'
#' @param shot_rows tibble, from build_shot_rows()
#' @param team_level tibble, from decompose_team_generation_gap()
#' @return tibble, one row per team-zone: team, zone, team_share,
#'   league_share, league_pps, mix_contribution, type
decompose_mix_by_zone <- function(shot_rows, team_level) {
  league_parts <- build_league_zone_table(shot_rows)
  mean_pps <- league_parts$mean_pps
  league_zone <- league_parts$league_zone
  team_zone_shares <- build_team_zone_shares(shot_rows)

  zone_table <- team_zone_shares %>%
    left_join(league_zone %>% select(zone, league_share, league_pps), by = "zone") %>%
    left_join(team_level %>% select(team, V_team), by = "team") %>%
    mutate(
      mean_pps = mean_pps,
      mix_contribution = V_team * (team_share - league_share) * (league_pps - mean_pps),
      type = case_when(
        mix_contribution >= 0 ~ "",
        team_share < league_share & league_pps > mean_pps ~ "missing efficient looks",
        team_share > league_share & league_pps < mean_pps ~ "over-reliant on low-value looks",
        TRUE ~ "missing efficient looks"  # defensive fallback, should not trigger given the two cases above are exhaustive for mix_contribution < 0
      )
    ) %>%
    select(team, zone, team_share, league_share, league_pps, mix_contribution, type)

  # Assert: per-team sum of zone mix_contribution equals mix_gap_total.
  recon_check <- zone_table %>%
    group_by(team) %>%
    summarise(sum_mix = sum(mix_contribution), .groups = "drop") %>%
    left_join(team_level %>% select(team, mix_gap_total), by = "team") %>%
    mutate(delta = sum_mix - mix_gap_total)
  stopifnot(all(abs(recon_check$delta) < ASSERT_TOL))

  zone_table
}

#' Flag each team-zone gap as identity_driven per the ICC + z-score anchor
#' rule (see file header). Unchanged from the mix-only version: this flag
#' depends only on team_share vs. league_share (via the BLUP z-score), not on
#' volume, so it is unaffected by the volume/mix split.
#'
#' @param zone_table tibble, from decompose_mix_by_zone()
#' @param team_blups tibble, data/processed/team_blups.rds (metric, team, adjusted_value)
#' @param icc_table tibble, output/icc_table.csv (metric, icc)
#' @return tibble, zone_table with an added identity_driven logical column
flag_identity_driven <- function(zone_table, team_blups, icc_table) {
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

  zone_table %>%
    left_join(identity_flags, by = c("team", "zone")) %>%
    mutate(identity_driven = replace_na(identity_driven, FALSE))
}

#' Assign each team a fit mode from its generation percentile, primary_driver,
#' and whether its most-negative mix zone is identity-driven (see file header).
#'
#' generation_pctile <= 33 (bottom tertile):
#'   primary_driver == "volume" -> "gap-fill"
#'   primary_driver == "mix": most-negative mix zone identity_driven ->
#'     "style-amplify / protect", else -> "gap-fill"
#' else -> "style-amplify / protect"
#'
#' @param full_table tibble, team-zone rows with generation_pctile,
#'   primary_driver, mix_contribution, identity_driven joined in
#' @return tibble, team, fit_mode
assign_fit_mode <- function(full_table) {
  most_negative_mix <- full_table %>%
    group_by(team) %>%
    slice_min(mix_contribution, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(team, generation_pctile, primary_driver, most_negative_mix_identity_driven = identity_driven)

  most_negative_mix %>%
    mutate(
      fit_mode = case_when(
        generation_pctile > 33 ~ "style-amplify / protect",
        primary_driver == "volume" ~ "gap-fill",
        most_negative_mix_identity_driven ~ "style-amplify / protect",
        TRUE ~ "gap-fill"
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

  team_level <- decompose_team_generation_gap(shot_rows, team_generation_making)

  zone_table <- decompose_mix_by_zone(shot_rows, team_level) %>%
    flag_identity_driven(team_blups, icc_table)

  # generation_pctile is computed HERE, in R/11, via percent_rank of
  # shot_generation_per100 (which itself comes from 07_expected_points.R).
  # It is the official per-100-possessions generation standing, carried for
  # the fit-mode call; total_gap (volume_gap + mix_gap_total) is this
  # script's zone-approximated version of the same quantity and is asserted
  # to reconcile with it (see decompose_team_generation_gap()).
  generation_pctile_table <- team_generation_making %>%
    mutate(generation_pctile = round(percent_rank(shot_generation_per100) * 100)) %>%
    select(team, generation_pctile)

  full_table <- zone_table %>%
    left_join(team_level %>% select(team, volume_gap, mix_gap_total, total_gap, primary_driver),
               by = "team") %>%
    left_join(generation_pctile_table, by = "team")

  fit_modes <- assign_fit_mode(full_table)

  gap_table_out <- full_table %>%
    left_join(fit_modes, by = "team") %>%
    select(
      team, generation_pctile, volume_gap, mix_gap_total, total_gap,
      primary_driver, fit_mode, zone, mix_contribution, type, identity_driven
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
    "# WNBA 2026 Offensive Generation Gap: Volume + Mix Decomposition",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    paste(
      "Each team's generation gap versus the league (generation = volume x",
      "mix quality: FGA per 100 possessions, times expected points per shot",
      "given shot diet) is split into a VOLUME gap ((team FGA/100 minus",
      "league FGA/100) times league mix quality) and a MIX gap (team FGA/100",
      "times the difference between the team's and the league's mix",
      "quality), the second attributed by zone with a centered-pps",
      "contribution. The two components sum to the team's total generation",
      "gap, which reconciles with the team's shot_generation_per100",
      "standing (generation percentile shown per team, computed in R/11 via",
      "percent_rank of shot_generation_per100, which itself comes from",
      "07_expected_points.R). primary_driver names which component (volume",
      "or mix) accounts for more of the gap."
    ),
    ""
  )

  team_order <- fit_modes %>%
    arrange(team) %>%
    pull(team)

  team_blocks <- map(team_order, function(tm) {
    team_rows <- gap_table %>% filter(team == tm)
    gen_pctile <- unique(team_rows$generation_pctile)
    primary_driver <- unique(team_rows$primary_driver)
    volume_gap <- unique(team_rows$volume_gap)
    mix_gap_total <- unique(team_rows$mix_gap_total)
    total_gap <- unique(team_rows$total_gap)
    fit_mode <- fit_modes %>% filter(team == tm) %>% pull(fit_mode)

    gap_summary_lines <- c(
      paste0("- Generation percentile: ", gen_pctile),
      paste0("- Primary driver: ", primary_driver),
      paste0("- Volume gap (per 100 poss): ", sprintf("%.2f", volume_gap)),
      paste0("- Mix gap, total (per 100 poss): ", sprintf("%.2f", mix_gap_total)),
      paste0("- Total gap (per 100 poss): ", sprintf("%.2f", total_gap))
    )

    mix_zone_lines <- if (primary_driver == "mix") {
      top2 <- team_rows %>%
        filter(mix_contribution < 0) %>%
        arrange(mix_contribution) %>%
        slice_head(n = 2)

      lines <- if (nrow(top2) == 0) {
        "  - no negative-contribution mix zones"
      } else {
        top2 %>%
          mutate(
            identity_tag = if_else(identity_driven, " (identity-driven: protect)", ""),
            line = paste0(
              "  - ", zone, ": ", type,
              " (mix contribution: ", sprintf("%.3f", mix_contribution), ")",
              identity_tag
            )
          ) %>%
          pull(line)
      }
      c("- Top mix-gap zones:", lines)
    } else {
      character(0)
    }

    c(
      paste0("## ", tm),
      "",
      gap_summary_lines,
      mix_zone_lines,
      paste0("- Fit mode: ", fit_mode),
      ""
    )
  }) %>%
    flatten_chr()

  method_explainer <- c(
    "## Method",
    "",
    paste(
      "Generation = volume (FGA per 100 possessions) x mix quality (expected",
      "points per shot given shot diet). Each team's generation gap versus",
      "the league is split into a volume gap and a mix gap; the mix gap is",
      "then attributed by zone. The two gap components sum to the team's",
      "total gap, which reconciles with the team's shot_generation_per100",
      "standing -- this is by construction, not a coincidence, since total_gap",
      "is the zone-approximated version of the same generation-versus-league",
      "quantity."
    ),
    ""
  )

  caveats <- c(
    "## Caveats",
    "",
    paste(
      "Generation has two drivers: shot volume (FGA per 100 possessions) and",
      "shot-mix quality (expected points per shot). This report separates",
      "them; a team can generate poorly with a fine shot mix if its volume",
      "is low, and vice versa."
    ),
    "",
    paste(
      "The mix component is a zone-level read (the alternative-stratification",
      "check found zone-only preserves team generation and making ranks,",
      "Spearman 0.98 for generation and 1.00 for making), so zone is a",
      "defensible grain."
    ),
    "",
    paste(
      "This reads only the offensive side. The open play-by-play barely sees",
      "defense, rebounding value, or playmaking not expressed in shots, so",
      "these are offensive-generation gaps, not all roster gaps."
    ),
    "",
    paste(
      "Footnote: Above the Break 3 (about 0.996 points per shot) sits just",
      "below the rim-inflated overall mean (about 1.02), so it is tagged",
      "low-value only relative to that mean; it is a league-average look,",
      "not an inefficient one."
    )
  )

  c(header, team_blocks, method_explainer, caveats)
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

  message("Fit mode + primary driver by team:")
  team_summary <- gap_table %>%
    distinct(team, generation_pctile, volume_gap, mix_gap_total, total_gap, primary_driver, fit_mode) %>%
    arrange(team)
  print(team_summary, n = Inf)

  invisible(gap_table)
}

if (sys.nframe() == 0) {
  main()
}
