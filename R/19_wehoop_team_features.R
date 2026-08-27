# 19_wehoop_team_features.R
#
# Purpose: Build the team-game style feature table from wehoop data -- the
#   wehoop analogue of R/05_features.R. Pace, zone profile shares, shot-
#   creation profiles (shot-creation profiles, not "play types" -- see
#   CLAUDE.md vocabulary discipline), rate stats, context shares, and game
#   context (home/away, opponent, game index, game minutes).
#
#   Two columns are documented as unavailable rather than faked:
#   assisted_rate (stats_shots.csv carries no assist indicator) and
#   transition_share (stats_possessions.csv's possession_start_type is used
#   if it carries a transition-like tag, otherwise the column is NA with a
#   message explaining why). live_ball_tov_rate is approximated from the
#   plain tov count, which does not distinguish live-ball from dead-ball
#   turnovers -- also a documented caveat, not a real live-ball figure.
#
# Inputs:  data/wehoop/stats_shots.csv, data/wehoop/live/shot_zones.csv,
#          data/wehoop/stats_possessions.csv, data/wehoop/stats_schedule.csv,
#          data/wehoop/team_lookup.rds
# Outputs: output/wehoop/team_game_features.rds -- one row per team-game

library(dplyr)
library(readr)
library(stringr)
library(tidyr)

DATA_DIR <- file.path("data", "wehoop")
LIVE_DIR <- file.path(DATA_DIR, "live")
OUT_DIR  <- file.path("output", "wehoop")

#' Read a required CSV, stopping with a helpful pointer if it is missing.
#'
#' @param path character, path to the CSV
#' @param hint character, which upstream script produces it
#' @return tibble
read_required_csv <- function(path, hint) {
  if (!file.exists(path)) {
    stop(sprintf("%s not found. Run %s first.", path, hint))
  }
  read_csv(path, show_col_types = FALSE)
}

#' Coerce a set of id columns to character so joins across files never fail
#' on numeric-vs-character type mismatches.
#'
#' @param df tibble
#' @param cols character vector of column names present in df
#' @return tibble
ids_as_character <- function(df, cols) {
  cols <- intersect(cols, names(df))
  df %>% mutate(across(all_of(cols), as.character))
}

#' Filter stats_possessions.csv down to possessions that count toward pace,
#' matching the cdn pipeline's outcome-filter convention in 05_features.R.
#' Falls back to counting every row if count_as_possession isn't present.
#'
#' @param possessions tibble, raw stats_possessions.csv
#' @return tibble, filtered possessions
real_possessions <- function(possessions) {
  if ("count_as_possession" %in% names(possessions)) {
    possessions %>% filter(count_as_possession == TRUE)
  } else {
    message("  NOTE: count_as_possession column not found in stats_possessions.csv; counting all rows as possessions")
    possessions
  }
}

#' Pace, FT rate, TOV rate, second-chance share, and transition share, all
#' from stats_possessions.csv. game_minutes uses 40 regulation + 5 per OT
#' period played (matches 05_features.R's game_minutes convention), and
#' pace_per40 normalizes pace_poss to that so OT team-games don't read as a
#' raw-count artifact.
#'
#' @param possessions tibble, raw stats_possessions.csv
#' @return tibble, one row per (game_id, team_id)
compute_possession_features <- function(possessions) {
  poss_real <- real_possessions(possessions) %>%
    ids_as_character(c("game_id", "offense_team_id", "defense_team_id"))

  game_minutes_tbl <- poss_real %>%
    group_by(game_id) %>%
    summarise(max_period = max(period, na.rm = TRUE), .groups = "drop") %>%
    mutate(game_minutes = 40 + 5 * pmax(0, max_period - 4))

  has_second_chance <- "is_second_chance" %in% names(poss_real)
  has_fta  <- all(c("fta", "fg2a", "fg3a") %in% names(poss_real))
  has_tov  <- "tov" %in% names(poss_real)

  # Transition detection: only claimed if possession_start_type actually
  # carries a transition-like tag. If it doesn't, transition_share is NA
  # with a message -- CLAUDE.md forbids claiming iso/transition trends from
  # data that doesn't support them, and this data contract may not.
  has_start_type <- "possession_start_type" %in% names(poss_real)
  transition_tag_present <- FALSE
  if (has_start_type) {
    start_types <- unique(coalesce(as.character(poss_real$possession_start_type), ""))
    transition_tag_present <- any(str_detect(start_types, regex("transition|fast\\s?break", ignore_case = TRUE)))
  }
  if (!transition_tag_present) {
    message("  NOTE: no transition-like value found in possession_start_type; transition_share set to NA")
  }

  poss_real %>%
    group_by(game_id, team_id = offense_team_id) %>%
    summarise(
      poss_count = n(),
      fta_sum   = if (has_fta) sum(fta, na.rm = TRUE) else NA_real_,
      fga_sum   = if (has_fta) sum(fg2a, na.rm = TRUE) + sum(fg3a, na.rm = TRUE) else NA_real_,
      tov_sum   = if (has_tov) sum(tov, na.rm = TRUE) else NA_real_,
      secondchance_poss = if (has_second_chance) sum(is_second_chance == TRUE, na.rm = TRUE) else NA_real_,
      transition_poss = if (transition_tag_present) {
        sum(str_detect(coalesce(as.character(possession_start_type), ""),
                        regex("transition|fast\\s?break", ignore_case = TRUE)))
      } else {
        NA_real_
      },
      .groups = "drop"
    ) %>%
    left_join(game_minutes_tbl, by = "game_id") %>%
    mutate(
      pace_per40 = poss_count / game_minutes * 40,
      ft_rate = if (has_fta) fta_sum / fga_sum else NA_real_,
      tov_rate = if (has_tov) tov_sum / poss_count else NA_real_,
      # live_ball_tov_rate: stats_possessions has no steal/deadball flag, so
      # this is the plain turnover rate re-labeled, not a true live-ball
      # figure. Documented caveat, not a real distinction.
      live_ball_tov_rate = tov_rate,
      secondchance_share = if (has_second_chance) secondchance_poss / poss_count else NA_real_,
      transition_share = if (transition_tag_present) transition_poss / poss_count else NA_real_
    ) %>%
    select(game_id, team_id, poss_count, game_minutes, pace_per40, ft_rate,
           tov_rate, live_ball_tov_rate, secondchance_share, transition_share)
}

#' Zone profile shares (RA / paint / mid / corner3 / ATB3) from
#' live/shot_zones.csv, one row per team-game.
#'
#' @param shot_zones tibble, raw live/shot_zones.csv
#' @return tibble, one row per (game_id, team_id)
compute_zone_profile <- function(shot_zones) {
  shot_zones %>%
    ids_as_character(c("game_id", "team_id")) %>%
    group_by(game_id, team_id) %>%
    summarise(
      n_zone_shots = n(),
      ra_share = mean(shot_zone == "restricted_area"),
      paint_share = mean(shot_zone == "in_the_paint_non_ra"),
      mid_share = mean(shot_zone == "mid_range"),
      corner3_share = mean(shot_zone == "corner_3"),
      atb3_share = mean(shot_zone == "above_the_break_3"),
      .groups = "drop"
    )
}

#' Classify shots into shot-creation profiles from action_type + sub_type.
#' Precedence putback > cutting > driving > pullup > other: first match
#' wins, layup implies driving. Everything unmatched (incl. NA) is "other",
#' a real stratum, never dropped.
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

#' Shot-creation profile shares (driving/pullup/cutting/putback) per
#' team-game, from stats_shots.csv.
#'
#' @param shots tibble, raw stats_shots.csv
#' @return tibble, one row per (game_id, team_id)
compute_shot_creation_profile <- function(shots) {
  shots %>%
    ids_as_character(c("game_id", "team_id")) %>%
    mutate(shot_class = classify_shot_creation(action_type, sub_type)) %>%
    group_by(game_id, team_id) %>%
    summarise(
      fga = n(),
      driving_share = mean(shot_class == "driving"),
      pullup_share = mean(shot_class == "pullup"),
      cutting_share = mean(shot_class == "cutting"),
      putback_share = mean(shot_class == "putback"),
      .groups = "drop"
    )
}

#' fg3a_rate and assisted_rate per team-game, from stats_shots.csv.
#' assisted_rate is set NA with a documented caveat: stats_shots.csv carries
#' no assist indicator column in this data contract.
#'
#' @param shots tibble, raw stats_shots.csv
#' @return tibble, one row per (game_id, team_id)
compute_shot_rate_stats <- function(shots) {
  has_assist <- any(str_detect(tolower(names(shots)), "assist"))
  if (!has_assist) {
    message("  NOTE: no assist indicator column found in stats_shots.csv; assisted_rate set to NA")
  }

  shots <- shots %>% ids_as_character(c("game_id", "team_id"))

  out <- shots %>%
    group_by(game_id, team_id) %>%
    summarise(
      fga = n(),
      fg3a = sum(shot_value == 3, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(fg3a_rate = fg3a / fga, assisted_rate = NA_real_) %>%
    select(game_id, team_id, fg3a_rate, assisted_rate)

  if (has_assist) {
    assist_col <- names(shots)[str_detect(tolower(names(shots)), "assist")][1]
    made_col_ok <- "shot_result" %in% names(shots)
    if (made_col_ok) {
      assisted_tbl <- shots %>%
        mutate(made = str_detect(coalesce(shot_result, ""), regex("made", ignore_case = TRUE)),
               is_assisted = !is.na(.data[[assist_col]]) & .data[[assist_col]] != 0) %>%
        group_by(game_id, team_id) %>%
        summarise(fgm = sum(made), assisted_fgm = sum(made & is_assisted), .groups = "drop") %>%
        mutate(assisted_rate = assisted_fgm / fgm) %>%
        select(game_id, team_id, assisted_rate)
      out <- out %>%
        select(-assisted_rate) %>%
        left_join(assisted_tbl, by = c("game_id", "team_id"))
    }
  }
  out
}

#' Build the game x team spine from stats_schedule.csv: one row per team
#' per game, with is_home, opponent_id, and game_date for game_index.
#'
#' @param schedule tibble, raw stats_schedule.csv
#' @return tibble: game_id, team_id, opponent_id, is_home, game_date
build_game_team_spine <- function(schedule) {
  date_col <- intersect(c("game_date", "date", "game_date_time"), names(schedule))
  if (length(date_col) == 0) {
    stop("stats_schedule.csv has no recognizable game date column (expected game_date/date/game_date_time)")
  }
  date_col <- date_col[1]

  schedule <- schedule %>% ids_as_character(c("game_id", "home_team_id", "away_team_id"))

  bind_rows(
    schedule %>% transmute(game_id, team_id = home_team_id, opponent_id = away_team_id,
                            is_home = TRUE, game_date = .data[[date_col]]),
    schedule %>% transmute(game_id, team_id = away_team_id, opponent_id = home_team_id,
                            is_home = FALSE, game_date = .data[[date_col]])
  ) %>%
    distinct(game_id, team_id, .keep_all = TRUE)
}

#' Add each team's own chronological game_index (1..N) to the spine.
#'
#' @param spine tibble, output of build_game_team_spine()
#' @return tibble, spine with game_index added
add_game_index <- function(spine) {
  spine %>%
    arrange(team_id, game_date, game_id) %>%
    group_by(team_id) %>%
    mutate(game_index = row_number()) %>%
    ungroup()
}

#' Join all feature groups into the final team-game feature table, keyed off
#' the schedule spine so every scheduled team-game is present even if a
#' team-game happens to be missing from one of the optional feeds.
#'
#' @param shots tibble, raw stats_shots.csv
#' @param shot_zones tibble, raw live/shot_zones.csv
#' @param possessions tibble, raw stats_possessions.csv
#' @param schedule tibble, raw stats_schedule.csv
#' @param team_lookup tibble, data/wehoop/team_lookup.rds
#' @return tibble, one row per team-game
build_team_game_features <- function(shots, shot_zones, possessions, schedule, team_lookup) {
  spine <- build_game_team_spine(schedule) %>% add_game_index()

  poss_tbl <- compute_possession_features(possessions)
  zone_tbl <- compute_zone_profile(shot_zones)
  creation_tbl <- compute_shot_creation_profile(shots)
  rate_tbl <- compute_shot_rate_stats(shots)

  team_names <- team_lookup %>% select(team_id, team = tricode)
  opponent_names <- team_lookup %>% select(opponent_id = team_id, opponent = tricode)

  spine %>%
    left_join(poss_tbl, by = c("game_id", "team_id")) %>%
    left_join(zone_tbl, by = c("game_id", "team_id")) %>%
    left_join(creation_tbl, by = c("game_id", "team_id")) %>%
    left_join(rate_tbl, by = c("game_id", "team_id")) %>%
    left_join(team_names, by = "team_id") %>%
    left_join(opponent_names, by = "opponent_id") %>%
    select(game_id, team, team_id, opponent, opponent_id, is_home, game_index,
           game_date, game_minutes, poss_count, pace_per40,
           ra_share, paint_share, mid_share, corner3_share, atb3_share,
           driving_share, pullup_share, cutting_share, putback_share,
           fg3a_rate, ft_rate, tov_rate, live_ball_tov_rate, assisted_rate,
           secondchance_share, transition_share)
}

main <- function() {
  shots <- read_required_csv(file.path(DATA_DIR, "stats_shots.csv"), "R/15_wehoop_download.R")
  possessions <- read_required_csv(file.path(DATA_DIR, "stats_possessions.csv"), "R/15_wehoop_download.R")
  schedule <- read_required_csv(file.path(DATA_DIR, "stats_schedule.csv"), "R/15_wehoop_download.R")
  shot_zones <- read_required_csv(file.path(LIVE_DIR, "shot_zones.csv"), "R/16_wehoop_live_api.R")

  lookup_path <- file.path(DATA_DIR, "team_lookup.rds")
  if (!file.exists(lookup_path)) {
    stop(sprintf("%s not found. Run R/17_wehoop_scaffold.R first.", lookup_path))
  }
  team_lookup <- readRDS(lookup_path)

  features <- build_team_game_features(shots, shot_zones, possessions, schedule, team_lookup)

  n_missing <- features %>%
    select(-game_date) %>%
    summarise(across(everything(), ~ sum(is.na(.)))) %>%
    pivot_longer(everything(), names_to = "col", values_to = "n_na") %>%
    filter(n_na > 0)
  if (nrow(n_missing) > 0) {
    message("team_game_features has missing values in: ", paste(n_missing$col, collapse = ", "))
  }

  dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
  saveRDS(features, file.path(OUT_DIR, "team_game_features.rds"))
  message(sprintf(
    "Wrote %s (%d team-games, %d games)",
    file.path(OUT_DIR, "team_game_features.rds"),
    nrow(features), n_distinct(features$game_id)
  ))

  invisible(features)
}

if (sys.nframe() == 0) {
  main()
}
