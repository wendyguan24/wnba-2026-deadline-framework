# 10_framework_evaluation.R
#
# Purpose: AMENDMENT_01 Section 2c framework-evaluation criteria that are not
#   already scripted elsewhere -- split-half stability and alternative-
#   stratification sensitivity. Garbage-time disposition (the third Section
#   2c criterion) is handled in R/06_models.R (output/trajectory_sensitivity.md).
#   Face validity (the fourth) is assessed qualitatively in output/findings.md,
#   not computed here.
#
#   Split-half stability checks whether each identity metric (plus shot
#   generation and shot making from the stratified expected-points baseline)
#   is a stable within-season signal or noisy game-to-game: correlate each
#   team's first-half-of-season mean against its second-half-of-season mean
#   across the 15 teams.
#
#   Alternative-stratification sensitivity checks whether the shot
#   generation / shot making conclusions from the main stratified
#   expected-points baseline (zone x shot_class x context) survive under a
#   coarser, zone-only stratification -- i.e. whether the headline findings
#   depend on the finer strata or hold up either way.
#
# Inputs:  data/processed/team_game_features.rds,
#          data/processed/team_game_shot_making.rds,
#          data/processed/pbp_events.rds,
#          data/processed/possessions.rds,
#          data/processed/team_generation_making.rds
# Outputs: output/framework_evaluation.md

library(tidyverse)

# Identity metrics + shot-making metrics evaluated for split-half stability.
# Matches R/06_models.R's IDENTITY_METRICS list, plus shot_generation_per100
# and shot_making_residual from the stratified expected-points baseline
# (team_game_shot_making.rds).
SPLIT_HALF_METRICS <- c(
  "pace_per40", "fg3a_rate", "assisted_rate", "transition_share",
  "transition_pts_per_poss", "off_tov_share", "secondchance_share",
  "paint_fgm_share", "ra_share", "paint_share", "mid_share", "corner3_share",
  "atb3_share", "driving_share", "pullup_share", "cutting_share",
  "putback_share", "ft_rate", "tov_rate", "live_ball_tov_rate",
  "shot_generation_per100", "shot_making_residual"
)

#' Compute split-half stability (AMENDMENT_01 Section 2c "Stability"): for
#' each team, split its games into a first half and second half by its own
#' game_index median (so uneven schedules are handled), take each team's mean
#' on every metric in each half, then correlate first-half means against
#' second-half means ACROSS THE 15 TEAMS, one correlation per metric.
#'
#' @param features tibble, data/processed/team_game_features.rds
#' @param shot_making tibble, data/processed/team_game_shot_making.rds
#' @return tibble(metric, first_half_second_half_cor, n_teams), sorted
#'   descending by correlation
compute_split_half_stability <- function(features, shot_making) {
  joined <- features %>%
    left_join(
      shot_making %>% select(gameId, team, shot_generation_per100, shot_making_residual),
      by = c("gameId", "team")
    )

  half_labeled <- joined %>%
    group_by(team) %>%
    mutate(half = if_else(game_index <= median(game_index), "first", "second")) %>%
    ungroup()

  half_means <- half_labeled %>%
    group_by(team, half) %>%
    summarise(across(all_of(SPLIT_HALF_METRICS), ~ mean(.x, na.rm = TRUE)), .groups = "drop")

  first_half <- half_means %>% filter(half == "first") %>% select(-half)
  second_half <- half_means %>% filter(half == "second") %>% select(-half)

  map_dfr(SPLIT_HALF_METRICS, function(m) {
    x <- first_half[[m]]
    y <- second_half[[m]][match(first_half$team, second_half$team)]
    tibble(
      metric = m,
      first_half_second_half_cor = cor(x, y, use = "complete.obs"),
      n_teams = sum(!is.na(x) & !is.na(y))
    )
  }) %>%
    arrange(desc(first_half_second_half_cor))
}

#' Recompute the stratified expected-points baseline under a coarser,
#' zone-only stratification and roll it up to team-level generation/making.
#'
#' @param pbp tibble, data/processed/pbp_events.rds
#' @param possessions tibble, data/processed/possessions.rds
#' @return tibble(team, generation_alt_per100, making_alt_per100)
compute_alt_baseline <- function(pbp, possessions) {
  shots <- pbp %>%
    filter(actionType %in% c("2pt", "3pt")) %>%
    transmute(
      team = teamTricode,
      points_scored = case_when(
        shotResult != "Made" ~ 0,
        actionType == "3pt" ~ 3,
        TRUE ~ 2
      ),
      zone = case_when(
        area %in% c("Left Corner 3", "Right Corner 3") ~ "Corner 3",
        TRUE ~ area
      )
    )

  # Zone-only xpts lookup. All zones have far more than 100 shots so the
  # global-mean fallback below is never triggered in practice; kept as a
  # defensive guard, matching the main baseline's collapse-cascade spirit.
  zone_counts <- shots %>% count(zone, name = "n_zone")
  pps_global <- mean(shots$points_scored)
  xpts_zone <- shots %>%
    group_by(zone) %>%
    summarise(xpts_zone = mean(points_scored), .groups = "drop") %>%
    left_join(zone_counts, by = "zone") %>%
    mutate(xpts_zone = if_else(n_zone < 100, pps_global, xpts_zone)) %>%
    select(zone, xpts_zone)

  team_shots <- shots %>%
    left_join(xpts_zone, by = "zone") %>%
    group_by(team) %>%
    summarise(
      expected_pts_alt = sum(xpts_zone),
      actual_pts = sum(points_scored),
      .groups = "drop"
    )

  poss_counts <- possessions %>%
    filter(outcome != "technical_ft") %>%
    count(team, name = "poss")

  team_shots %>%
    left_join(poss_counts, by = "team") %>%
    mutate(
      generation_alt_per100 = expected_pts_alt / poss * 100,
      making_alt_per100 = (actual_pts - expected_pts_alt) / poss * 100
    ) %>%
    select(team, generation_alt_per100, making_alt_per100)
}

#' Compute alternative-stratification sensitivity (AMENDMENT_01 Section 2c
#' "Sensitivity"): recompute shot generation and shot making under a coarser,
#' zone-only stratification and check whether the main (zone x shot_class x
#' context) team conclusions survive, via Spearman rank correlation.
#'
#' @param pbp tibble, data/processed/pbp_events.rds
#' @param possessions tibble, data/processed/possessions.rds
#' @param team_generation_making tibble, data/processed/team_generation_making.rds
#'   (the main, full-stratification season-level result)
#' @return list(rank_cor_generation, rank_cor_making, joined_table)
compute_alt_stratification <- function(pbp, possessions, team_generation_making) {
  alt <- compute_alt_baseline(pbp, possessions)

  joined <- team_generation_making %>%
    select(team, shot_generation_per100, shot_making_per100) %>%
    left_join(alt, by = "team") %>%
    mutate(
      main_generation_rank = rank(-shot_generation_per100, ties.method = "min"),
      alt_generation_rank = rank(-generation_alt_per100, ties.method = "min"),
      main_making_rank = rank(-shot_making_per100, ties.method = "min"),
      alt_making_rank = rank(-making_alt_per100, ties.method = "min")
    ) %>%
    select(
      team, shot_generation_per100, generation_alt_per100,
      main_generation_rank, alt_generation_rank,
      shot_making_per100, making_alt_per100,
      main_making_rank, alt_making_rank
    ) %>%
    arrange(main_generation_rank)

  rank_cor_generation <- cor(
    joined$shot_generation_per100, joined$generation_alt_per100,
    method = "spearman"
  )
  rank_cor_making <- cor(
    joined$shot_making_per100, joined$making_alt_per100,
    method = "spearman"
  )

  list(
    rank_cor_generation = rank_cor_generation,
    rank_cor_making = rank_cor_making,
    joined_table = joined
  )
}

#' Render the framework-evaluation results as markdown report lines.
#'
#' @param split_half tibble from compute_split_half_stability()
#' @param alt list from compute_alt_stratification()
#' @return character vector of markdown lines
render_framework_evaluation_md <- function(split_half, alt) {
  top3 <- head(split_half, 3)
  bottom3 <- tail(split_half, 3)

  gsv_row <- alt$joined_table %>% filter(team == "GSV")
  gsv_gen_moves <- gsv_row$main_generation_rank != gsv_row$alt_generation_rank
  gsv_making_moves <- gsv_row$main_making_rank != gsv_row$alt_making_rank

  hdr <- c(
    "# Framework Evaluation (AMENDMENT_01 Section 2c)",
    "",
    paste0("Generated: ", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    "",
    "This report covers two of the four AMENDMENT_01 Section 2c",
    "framework-evaluation criteria: split-half stability and",
    "alternative-stratification sensitivity. The other two live elsewhere:",
    "garbage-time disposition in output/trajectory_sensitivity.md (R/06), and",
    "face validity qualitatively in output/findings.md.",
    ""
  )

  stab_intro <- c(
    "## 1. Split-half stability",
    "",
    "For each team, games are split into a first half and second half by that",
    "team's own game_index median. Each metric's team-level mean is computed",
    "in each half, then correlated across the 15 teams. A high correlation",
    "means the identity metric is a stable within-season signal (real",
    "signal, not noise); a low correlation means the metric is noisy",
    "game-to-game and any team ranking built on it is fragile.",
    "",
    "| metric | first-half/second-half correlation |",
    "| --- | --- |"
  )
  stab_rows <- sprintf("| %s | %.3f |", split_half$metric, split_half$first_half_second_half_cor)

  stab_reading <- paste0(
    "Most stable: ", paste(sprintf("%s (%.3f)", top3$metric, top3$first_half_second_half_cor), collapse = ", "),
    ". Least stable: ", paste(sprintf("%s (%.3f)", bottom3$metric, bottom3$first_half_second_half_cor), collapse = ", "),
    "."
  )

  alt_section <- c(
    "",
    "## 2. Alternative-stratification sensitivity (zone-only vs zone x shot_class x context)",
    "",
    "The stratified expected-points baseline is recomputed under a coarser,",
    "zone-only stratification (dropping shot_class and context) and rolled up",
    "to team-level shot generation and shot making, then compared to the main",
    "zone x shot_class x context baseline via Spearman rank correlation.",
    "",
    sprintf("Shot generation rank correlation (main vs zone-only): %.3f", alt$rank_cor_generation),
    "",
    sprintf("Shot making rank correlation (main vs zone-only): %.3f", alt$rank_cor_making),
    "",
    sprintf(
      "GSV: main generation rank %d (alt rank %d), main making rank %d (alt rank %d). %s",
      gsv_row$main_generation_rank, gsv_row$alt_generation_rank,
      gsv_row$main_making_rank, gsv_row$alt_making_rank,
      if (gsv_gen_moves || gsv_making_moves) {
        "GSV's position moves under the coarser stratification -- flagged."
      } else {
        "GSV's position holds under the coarser stratification."
      }
    )
  )

  conclusion <- c(
    "",
    "## Conclusion",
    "",
    paste0(
      "Split-half stability shows which identity metrics carry a real, ",
      "within-season signal versus which are noisy enough that a single-season ",
      "team ranking on them should be read cautiously. Alternative-stratification ",
      "sensitivity shows whether the shot generation and shot making conclusions ",
      "are an artifact of the fine zone x shot_class x context strata or hold up ",
      "under a coarser stratification. Together these two checks bound how much ",
      "weight the framework's identity and shot-making reads can carry into the ",
      "deadline-read table."
    )
  )

  c(hdr, stab_intro, stab_rows, "", stab_reading, alt_section, conclusion)
}

main <- function() {
  features <- readRDS("data/processed/team_game_features.rds")
  shot_making <- readRDS("data/processed/team_game_shot_making.rds")
  pbp <- readRDS("data/processed/pbp_events.rds")
  possessions <- readRDS("data/processed/possessions.rds")
  team_generation_making <- readRDS("data/processed/team_generation_making.rds")

  split_half <- compute_split_half_stability(features, shot_making)
  alt <- compute_alt_stratification(pbp, possessions, team_generation_making)

  dir.create("output", recursive = TRUE, showWarnings = FALSE)
  writeLines(render_framework_evaluation_md(split_half, alt), "output/framework_evaluation.md")

  message("Wrote output/framework_evaluation.md")
  message(sprintf("Shot generation rank correlation: %.3f", alt$rank_cor_generation))
  message(sprintf("Shot making rank correlation: %.3f", alt$rank_cor_making))
  message(sprintf(
    "Split-half correlation min/median/max: %.3f / %.3f / %.3f",
    min(split_half$first_half_second_half_cor),
    median(split_half$first_half_second_half_cor),
    max(split_half$first_half_second_half_cor)
  ))

  invisible(list(split_half = split_half, alt = alt))
}

if (sys.nframe() == 0) {
  main()
}
