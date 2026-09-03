# 24_wehoop_playoff_read.R
#
# Purpose: Full-season playoff-readiness synthesis. The wehoop analogue of
#   R/08_deadline_read.R, reframed from deadline levers to playoff readiness:
#   with the season complete there is no deadline lever to pull, so the
#   question changes from "acquire / adjust / hold" to "is this team built
#   for a playoff run, and where is the structural risk."
#
#   Reuses 08's identity-summary and generation/making-tier machinery
#   unchanged (same ICC anchor floor, same z-score-and-describe approach, same
#   ntile(x, 3) tiers). Adds two dimensions 08 does not have, because a
#   full-season view has inputs a deadline read does not (a full season of
#   box data and a fitted RAPM): a defensive profile from
#   team_advanced_profile.csv, and a depth read from player_value.csv's
#   positive-RAPM player count.
#
#   Readiness classification (classify_readiness() below) synthesizes the
#   six-category spec into an explicit, exhaustive, first-match-wins
#   precedence order -- the six categories are not mutually exclusive by
#   construction (a team can be simultaneously "mid-tier" and "structurally
#   concerning"), so this script's own priority order is a design decision,
#   documented at classify_readiness().
#
# Inputs:  output/wehoop/standings.csv (script 18)
#          output/wehoop/team_generation_making.csv (script 22)
#          output/wehoop/team_blups.rds (script 23)
#          output/wehoop/team_trajectories.csv (script 23)
#          output/wehoop/icc_table.csv (script 23)
#          output/wehoop/team_advanced_profile.csv (script 20)
#          output/wehoop/player_value.csv (script 21)
#          data/reference/cap_context_2026.csv (hand-curated, optional --
#            loaded if present, skipped otherwise; see data/reference/README.md)
# Outputs: output/wehoop/playoff_read.csv
#          output/wehoop/playoff_read.md

library(tidyverse)

OUT_DIR <- file.path("output", "wehoop")

ICC_ANCHOR_FLOOR <- 0.15  # same floor as 08_deadline_read.R: only anchor identity on metrics with mixed-model ICC >= 0.15

METRIC_LABELS <- c(
  pace_per40 = "pace",
  fg3a_rate = "3PA rate",
  assisted_rate = "assisted rate",
  transition_share = "transition rate",
  secondchance_share = "second-chance rate",
  ra_share = "rim rate",
  paint_share = "paint rate",
  mid_share = "mid-range rate",
  corner3_share = "corner-3 rate",
  atb3_share = "above-break-3 rate",
  driving_share = "driving rate",
  pullup_share = "pullup rate",
  cutting_share = "cutting rate",
  putback_share = "putback rate",
  ft_rate = "free-throw rate",
  tov_rate = "turnover rate",
  live_ball_tov_rate = "live-ball turnover rate"
)

#' Format a team's trajectory value with a footnote marker ("*") when its
#' interval spans zero -- the label is directional, not a standalone claim.
#'
#' @param trajectory character vector
#' @param interval_spans_zero logical vector
#' @return character vector, e.g. "improving" or "improving*"
format_trajectory_column <- function(trajectory, interval_spans_zero) {
  ifelse(interval_spans_zero, paste0(trajectory, "*"), trajectory)
}

#' Build a short readable identity-descriptor phrase per team from the
#' schedule-adjusted BLUPs. Same approach as 08_deadline_read.R's
#' build_identity_summary(): ICC-anchor filter, then z-score adjusted_value
#' within each metric across teams, take the 2 most extreme metrics per team,
#' compose "high X, low Y".
#'
#' @param team_blups tibble, cols metric, team, adjusted_value
#' @param icc_path character, defaults to output/wehoop/icc_table.csv
#' @return tibble, cols team, identity_summary
build_identity_summary <- function(team_blups, icc_path = file.path(OUT_DIR, "icc_table.csv")) {
  icc_table <- readr::read_csv(icc_path, show_col_types = FALSE)
  eligible_metrics <- icc_table %>%
    filter(icc >= ICC_ANCHOR_FLOOR) %>%
    pull(metric)

  team_blups <- team_blups %>%
    filter(metric %in% eligible_metrics)

  label_for <- function(metric) {
    ifelse(metric %in% names(METRIC_LABELS), METRIC_LABELS[metric], metric)
  }

  z_scored <- team_blups %>%
    group_by(metric) %>%
    mutate(z = as.numeric(scale(adjusted_value))) %>%
    ungroup() %>%
    mutate(
      direction = ifelse(z > 0, "high", "low"),
      label = label_for(metric),
      descriptor = paste(direction, label)
    )

  z_scored %>%
    group_by(team) %>%
    arrange(desc(abs(z)), .by_group = TRUE) %>%
    slice_head(n = 2) %>%
    summarise(identity_summary = paste(descriptor, collapse = ", "), .groups = "drop")
}

#' Describe a team's offense from its generation tier. Same three labels as
#' 08_deadline_read.R's classify_diagnosis(), descriptive only.
#'
#' @param generation_tier integer, ntile(shot_generation_per100, 3), 1=low..3=high
#' @return character, one of "generation-short"/"balanced"/"generation-rich"
classify_diagnosis <- function(generation_tier) {
  switch(
    as.character(generation_tier),
    "1" = "generation-short",
    "2" = "balanced",
    "3" = "generation-rich",
    stop("classify_diagnosis(): unexpected generation_tier: ", generation_tier)
  )
}

#' Build generation/making rank and tier columns from
#' team_generation_making.csv. Same construction as 08_deadline_read.R:
#' rank is the published league-rank unit (1 = best, out of n_teams), tier is
#' ntile(x, 3) and drives the readiness classification.
#'
#' @param team_generation_making tibble, cols team, shot_generation_per100, shot_making_per100
#' @return tibble, cols team, generation_rank, making_rank, generation_tier, making_tier
build_generation_making_tiers <- function(team_generation_making) {
  team_generation_making %>%
    mutate(
      generation_rank = rank(-shot_generation_per100, ties.method = "min"),
      making_rank = rank(-shot_making_per100, ties.method = "min"),
      generation_tier = ntile(shot_generation_per100, 3),
      making_tier = ntile(shot_making_per100, 3)
    ) %>%
    select(team, generation_rank, making_rank, generation_tier, making_tier)
}

#' Build the headline trajectory column from the shot_making_residual rows
#' of team_trajectories.csv. Same deliberate choice as 08_deadline_read.R:
#' shot_making_residual is the temporal dimension of the making axis. Falls
#' back to "n/a" for every team (trajectory is never silently dropped) if no
#' shot_making_residual rows are present.
#'
#' @param team_trajectories tibble, cols metric, team, trajectory, interval_spans_zero
#' @param teams character vector, all team codes (for the fallback path)
#' @return tibble, cols team, trajectory, interval_spans_zero, trajectory_display
build_trajectory_summary <- function(team_trajectories, teams) {
  making_residual_traj <- team_trajectories %>%
    filter(metric == "shot_making_residual") %>%
    select(team, trajectory, interval_spans_zero)

  if (nrow(making_residual_traj) == 0) {
    warning(
      "build_trajectory_summary(): no shot_making_residual rows in team_trajectories -- ",
      "trajectory set to NA for all teams."
    )
    return(tibble(
      team = teams,
      trajectory = NA_character_,
      interval_spans_zero = NA,
      trajectory_display = "n/a (trajectory input unavailable)"
    ))
  }

  making_residual_traj %>%
    mutate(trajectory_display = format_trajectory_column(trajectory, interval_spans_zero))
}

#' Build the defensive profile: rank teams by DEF_RATING (lower = better
#' defense) and classify into three bands. Column-name matching is
#' case-insensitive and tolerant of the raw stats-provider naming
#' (DEF_RATING vs def_rating vs DEF_RATING_avg-style suffixes are not
#' handled -- exact match only, case-insensitive) since
#' team_advanced_profile.csv (script 20) is a forward dependency this script
#' has not seen run yet.
#'
#' @param team_advanced_profile tibble, must contain a team column and a
#'   DEF_RATING-named column (case-insensitive)
#' @return tibble, cols team, def_rating, def_rating_rank, defense_tier
build_defensive_profile <- function(team_advanced_profile) {
  team_col <- intersect(c("team", "tricode", "TEAM", "Team"), names(team_advanced_profile))
  def_col <- names(team_advanced_profile)[toupper(names(team_advanced_profile)) == "DEF_RATING"]

  if (length(team_col) == 0 || length(def_col) == 0) {
    message(
      "  WARN: team_advanced_profile.csv missing a team column or a DEF_RATING column -- ",
      "defensive profile set to unavailable for all teams."
    )
    return(tibble(
      team = character(0), def_rating = numeric(0),
      def_rating_rank = integer(0), defense_tier = character(0)
    ))
  }

  team_advanced_profile %>%
    transmute(team = .data[[team_col[1]]], def_rating = .data[[def_col[1]]]) %>%
    mutate(
      def_rating_rank = rank(def_rating, ties.method = "min"),  # lower DEF_RATING = better defense = lower (better) rank
      defense_tier = case_when(
        def_rating_rank <= 5  ~ "elite defense",
        def_rating_rank <= 10 ~ "average defense",
        TRUE                  ~ "weak defense"
      )
    )
}

#' Build the RAPM-informed depth read: count of players per team with
#' positive RAPM. player_value.csv (script 21) is a forward dependency this
#' script has not seen run yet, so a missing rapm column degrades to
#' "unavailable" per team rather than erroring.
#'
#' @param player_value tibble, must contain team and rapm columns
#' @param teams character vector, all team codes (for the fallback path)
#' @return tibble, cols team, depth_count, depth_label
build_depth_profile <- function(player_value, teams) {
  if (!all(c("team", "rapm") %in% names(player_value))) {
    message(
      "  WARN: player_value.csv missing team/rapm columns -- ",
      "depth read set to unavailable for all teams."
    )
    return(tibble(team = teams, depth_count = NA_integer_, depth_label = "unavailable"))
  }

  counts <- player_value %>%
    filter(!is.na(rapm)) %>%
    group_by(team) %>%
    summarise(depth_count = sum(rapm > 0), .groups = "drop")

  # teams with zero rows in player_value (e.g. no qualifying players) still
  # get a row, with depth_count 0 -- "no positive-RAPM" is a real label, not
  # a missing value.
  tibble(team = teams) %>%
    left_join(counts, by = "team") %>%
    mutate(
      depth_count = coalesce(depth_count, 0L),
      depth_label = case_when(
        depth_count >= 5 ~ "deep",
        depth_count >= 3 ~ "adequate",
        depth_count >= 1 ~ "thin",
        TRUE              ~ "no positive-RAPM"
      )
    )
}

#' Classify a team's playoff readiness from its generation tier, trajectory,
#' defensive tier, and depth label.
#'
#' The six-category spec (complete / one piece away / trending right /
#' trending wrong / in but vulnerable / out) is not a set of mutually
#' exclusive conditions -- a mid-tier team with a weak defense and an
#' improving trajectory could plausibly read as either "trending right" or
#' "in but vulnerable". This function resolves that with an explicit,
#' first-match-wins precedence (case_when, top to bottom):
#'
#'   1. out               -- playoff_position == "out" overrides every other
#'                            read; a team out of the field is not "vulnerable"
#'                            or "trending," it is out.
#'   2. complete           -- no structural weakness (generation, defense,
#'                            depth all pass) and the trajectory is not
#'                            declining.
#'   3. trending wrong     -- generation-tier mid-or-above (not the bottom
#'                            tertile) but the trajectory is declining. Takes
#'                            precedence over "one piece away" and "in but
#'                            vulnerable" because a declining trajectory is
#'                            the more urgent signal than a single structural
#'                            gap.
#'   4. one piece away     -- exactly one of the three structural checks
#'                            fails (generation, defense, depth) and the
#'                            trajectory is not declining.
#'   5. trending right     -- mid-tier generation specifically (not the
#'                            bottom or top tertile) with an improving
#'                            trajectory, not already caught above.
#'   6. in but vulnerable  -- playoff_position == "in" with a structural
#'                            concern (bottom-tertile generation, thin/no
#'                            depth, or weak defense) not already classified.
#'   7. in but vulnerable  -- default fallback for anything unclassified
#'                            (e.g. a contender with two-plus structural
#'                            weaknesses and a flat trajectory): a
#'                            conservative default rather than overstating
#'                            closeness with "one piece away".
#'
#' @param playoff_position character, one of "contender"/"in"/"out"
#' @param generation_tier integer, ntile(shot_generation_per100, 3), 1=low..3=high
#' @param trajectory character or NA, shot_making_residual trajectory label
#' @param defense_tier character, one of "elite defense"/"average defense"/"weak defense"/NA
#' @param depth_label character, one of "deep"/"adequate"/"thin"/"no positive-RAPM"/"unavailable"
#' @return character, one of the six readiness labels
classify_readiness <- function(playoff_position, generation_tier, trajectory, defense_tier, depth_label) {
  gen_ok <- generation_tier >= 2
  def_ok <- isTRUE(defense_tier %in% c("elite defense", "average defense"))
  depth_ok <- isTRUE(depth_label %in% c("deep", "adequate"))
  n_weak <- sum(!gen_ok, !def_ok, !depth_ok)
  traj_declining <- isTRUE(trajectory == "declining")
  traj_improving <- isTRUE(trajectory == "improving")

  case_when(
    playoff_position == "out" ~ "out",
    n_weak == 0 & !traj_declining ~ "complete",
    gen_ok & traj_declining ~ "trending wrong",
    n_weak == 1 & !traj_declining ~ "one piece away",
    generation_tier == 2 & traj_improving ~ "trending right",
    playoff_position == "in" ~ "in but vulnerable",
    TRUE ~ "in but vulnerable"
  )
}

#' Load the hand-curated cap-context reference table if present. Returns
#' NULL (with a message, not a warning) when the file is absent -- cap
#' context is hand-curated and may not exist for a full-season, non-deadline
#' run.
#'
#' @param path character, defaults to data/reference/cap_context_2026.csv
#' @return tibble (team, flexibility_tier, ...) or NULL
load_cap_context_optional <- function(path = file.path("data", "reference", "cap_context_2026.csv")) {
  if (!file.exists(path)) {
    message(sprintf("  NOTE: %s not found -- cap context omitted from this run.", path))
    return(NULL)
  }
  readr::read_csv(path, show_col_types = FALSE) %>%
    select(team, flexibility_tier)
}

#' Assemble the full playoff-read table, one row per team.
#'
#' @param standings tibble, output/wehoop/standings.csv
#' @param team_generation_making tibble, output/wehoop/team_generation_making.csv
#' @param team_blups tibble, output/wehoop/team_blups.rds
#' @param team_trajectories tibble, output/wehoop/team_trajectories.csv
#' @param team_advanced_profile tibble, output/wehoop/team_advanced_profile.csv
#' @param player_value tibble, output/wehoop/player_value.csv
#' @param cap_context tibble or NULL, from load_cap_context_optional()
#' @return tibble, one row per team, sorted by readiness then team
build_playoff_read <- function(standings, team_generation_making, team_blups,
                                team_trajectories, team_advanced_profile,
                                player_value, cap_context = NULL) {
  teams <- standings$team

  tiers <- build_generation_making_tiers(team_generation_making)
  traj <- build_trajectory_summary(team_trajectories, teams)
  identity_summary <- build_identity_summary(team_blups)
  defense <- build_defensive_profile(team_advanced_profile)
  depth <- build_depth_profile(player_value, teams)

  playoff_read <- standings %>%
    select(team, wins, losses, win_pct, point_diff, rank, games_back_from_8th, playoff_position) %>%
    left_join(tiers, by = "team") %>%
    left_join(traj, by = "team") %>%
    left_join(identity_summary, by = "team") %>%
    left_join(defense, by = "team") %>%
    left_join(depth, by = "team") %>%
    mutate(
      defense_tier = coalesce(defense_tier, "unavailable"),
      diagnosis = map_chr(generation_tier, classify_diagnosis)
    ) %>%
    rowwise() %>%
    mutate(
      readiness = classify_readiness(playoff_position, generation_tier, trajectory, defense_tier, depth_label)
    ) %>%
    ungroup()

  if (!is.null(cap_context)) {
    playoff_read <- playoff_read %>% left_join(cap_context, by = "team")
  }

  readiness_order <- c("complete", "one piece away", "trending right",
                        "trending wrong", "in but vulnerable", "out")
  playoff_read %>%
    mutate(readiness_sort = factor(readiness, levels = readiness_order)) %>%
    arrange(readiness_sort, team) %>%
    select(-readiness_sort)
}

#' Render the playoff-read table to markdown lines.
#'
#' @param playoff_read tibble, from build_playoff_read()
#' @return character vector, markdown lines
render_playoff_read_md <- function(playoff_read) {
  has_cap <- "flexibility_tier" %in% names(playoff_read)
  n_teams <- nrow(playoff_read)

  header <- c(
    "# WNBA 2026 Full-Season Playoff Readiness",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    paste(
      "This is a full-season view, not a deadline read: there is no",
      "acquire/adjust/hold lever left to pull, so Readiness replaces the",
      "deadline recommendation. Offense diagnosis is descriptive only",
      "(generation-short/balanced/generation-rich, from the stratified",
      "expected-points baseline's generation axis). Defense and Depth are",
      "new to the full-season view -- see the footnotes for their sourcing",
      "and caveats."
    ),
    ""
  )

  table_header_cols <- c("Team", "Playoff Position", "Readiness", "Defense", "Depth",
                          "Gen Rank", "Making Rank", "Trajectory", "Identity")
  if (has_cap) table_header_cols <- c(table_header_cols, "Cap")

  table_header <- c(
    paste0("| ", paste(table_header_cols, collapse = " | "), " |"),
    paste0("| ", paste(rep("---", length(table_header_cols)), collapse = " | "), " |")
  )

  table_rows <- playoff_read %>%
    mutate(
      row = paste0(
        "| ", team,
        " | ", playoff_position,
        " | ", readiness,
        " | ", defense_tier,
        " | ", depth_label,
        " | ", generation_rank,
        " | ", making_rank,
        " | ", trajectory_display,
        " | ", identity_summary,
        if (has_cap) paste0(" | ", coalesce(flexibility_tier, "n/a")) else "",
        " |"
      )
    ) %>%
    pull(row)

  footnotes <- c(
    "",
    paste0(
      "Gen rank and Making rank are the team's league rank of ", n_teams,
      " (1 = best): Gen rank 1 is the most and best looks created (highest",
      " shot generation), Making rank 1 is the best finishing relative to",
      " shot quality (highest shot making)."
    ),
    "",
    paste(
      "Readiness classification (first-match-wins precedence, see",
      "classify_readiness() in R/24_wehoop_playoff_read.R): complete = no",
      "structural weakness across generation, defense, and depth and a",
      "non-declining trajectory; one piece away = exactly one structural",
      "weakness and a non-declining trajectory; trending wrong = mid-tier-",
      "or-above generation with a declining trajectory; trending right =",
      "mid-tier generation with an improving trajectory; in but vulnerable",
      "= holding a playoff spot with a structural concern (or the",
      "conservative default when no other category fits); out = outside",
      "the playoff field regardless of the other dimensions."
    ),
    "",
    paste(
      "* interval spans zero: the per-team trajectory label is directional,",
      "not a standalone claim. Trajectory shown is the shot_making_residual",
      "trend (finishing relative to shot quality, rising or falling), the",
      "same headline trajectory metric used in the deadline read. Source:",
      "output/wehoop/trajectory_league_trends.csv."
    ),
    "",
    paste(
      "Defense is DEF_RATING rank from output/wehoop/team_advanced_profile.csv",
      "(script 20): rank 1-5 elite, 6-10 average, 11-15 weak, lower DEF_RATING",
      "is better. \"unavailable\" means the advanced-profile input was missing",
      "the expected column for this run."
    ),
    "",
    paste(
      "Depth is a count of players with positive full-season RAPM from",
      "output/wehoop/player_value.csv (script 21): 5+ deep, 3-4 adequate,",
      "1-2 thin, 0 no positive-RAPM player. RAPM at the individual-season",
      "level carries real uncertainty, particularly for low-minute players --",
      "treat depth_count as a coarse signal, not a precise player count, and",
      "do not publish it as a ranking of individual players."
    ),
    "",
    paste(
      "This is a full-season view: it describes where a team ended up, not",
      "a deadline decision. It does not carry a cap-conditioned lever call",
      "(compare output/deadline_read.md's Recommendation column) -- Cap, where",
      "shown, is the hand-curated flexibility_tier from",
      "data/reference/cap_context_2026.csv, included for reference only and",
      "not used to condition Readiness."
    )
  )

  c(header, table_header, table_rows, footnotes)
}

main <- function() {
  dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

  paths <- list(
    standings = file.path(OUT_DIR, "standings.csv"),
    generation_making = file.path(OUT_DIR, "team_generation_making.csv"),
    blups = file.path(OUT_DIR, "team_blups.rds"),
    trajectories = file.path(OUT_DIR, "team_trajectories.csv"),
    advanced_profile = file.path(OUT_DIR, "team_advanced_profile.csv"),
    player_value = file.path(OUT_DIR, "player_value.csv")
  )
  required <- c("standings", "generation_making", "blups", "trajectories")
  for (nm in required) {
    if (!file.exists(paths[[nm]])) {
      stop(sprintf("%s not found at %s.", nm, paths[[nm]]))
    }
  }

  standings <- readr::read_csv(paths$standings, show_col_types = FALSE)
  team_generation_making <- readr::read_csv(paths$generation_making, show_col_types = FALSE)
  team_blups <- readRDS(paths$blups)
  team_trajectories <- readr::read_csv(paths$trajectories, show_col_types = FALSE)

  if (!file.exists(paths$advanced_profile)) {
    message(sprintf("  WARN: %s not found. Run script 20 for a real defensive read.", paths$advanced_profile))
    team_advanced_profile <- tibble(team = character(0))
  } else {
    team_advanced_profile <- readr::read_csv(paths$advanced_profile, show_col_types = FALSE)
  }

  if (!file.exists(paths$player_value)) {
    message(sprintf("  WARN: %s not found. Run script 21 for a real depth read.", paths$player_value))
    player_value <- tibble(team = character(0))
  } else {
    player_value <- readr::read_csv(paths$player_value, show_col_types = FALSE)
  }

  cap_context <- load_cap_context_optional()

  playoff_read <- build_playoff_read(
    standings, team_generation_making, team_blups, team_trajectories,
    team_advanced_profile, player_value, cap_context
  )

  write_csv(playoff_read, file.path(OUT_DIR, "playoff_read.csv"))
  writeLines(render_playoff_read_md(playoff_read), file.path(OUT_DIR, "playoff_read.md"))

  message("Wrote ", file.path(OUT_DIR, "playoff_read.csv"), " (", nrow(playoff_read), " rows)")
  message("Wrote ", file.path(OUT_DIR, "playoff_read.md"))
  message("Readiness distribution:")
  print(table(playoff_read$readiness))

  invisible(playoff_read)
}

if (sys.nframe() == 0) {
  main()
}
