# 03_possessions.R
#
# Purpose: Segment the parsed PBP event stream into a clean possession table,
#   using the `possession` column (teamId currently holding the ball) plus
#   period boundaries. See HANDOFF §5a. This table is also the future
#   possession-value-model input — build it clean even though that model is
#   out of scope this cycle.
#
#   Design note (verified against real data 2026-07-18): and-one sequences
#   (made FG -> shooting foul -> free throws) and technical-foul free throws
#   do NOT change cdn's `possession` column value — the possessing team keeps
#   the ball through both. Segmenting purely on possession-column changes
#   therefore groups these sequences into a single possession correctly, by
#   construction, without bespoke merge logic. handle_and_ones() and
#   handle_technical_fts() below are VALIDATION checks of that assumption on
#   the actual data (not merge functions) — 476 true and-one candidates
#   found, 475 confirmed clean, 1 documented residual (see handle_and_ones()
#   docstring; a team-foul bonus FT, not a real and-one, surface-identical to
#   one). EXPECTED_AND_ONE_VIOLATIONS below pins this baseline so a
#   regression (e.g. back to the 699 false positives from the pre-refinement
#   heuristic) is caught, not silently accepted.
#
# Inputs:  data/processed/pbp_events.rds
# Outputs: data/processed/possessions.rds with columns:
#   possession_id, gameId, team, opponent, period, start_event, end_event,
#   start_clock, end_clock, outcome, points, is_transition, is_2ndchance,
#   is_off_turnover

library(tidyverse)

# Baseline residual violation count from handle_and_ones(), verified 2026-07-18
# (see docstring below). A different count on a later run signals either a
# data change or a regression in the detection logic, not necessarily a new
# problem in segment_possessions() itself (which doesn't use this heuristic).
EXPECTED_AND_ONE_VIOLATIONS <- 1

#' Points scored by a single event, if it's a made shot; 0 otherwise
#'
#' @param actionType character vector
#' @param shotResult character vector
#' @return numeric vector
compute_event_points <- function(actionType, shotResult) {
  case_when(
    actionType == "2pt" & shotResult == "Made" ~ 2,
    actionType == "3pt" & shotResult == "Made" ~ 3,
    actionType == "freethrow" & shotResult == "Made" ~ 1,
    TRUE ~ 0
  )
}

#' Segment a single game's events into possessions using the `possession`
#' column (teamId in possession) plus period boundaries. Possession == 0
#' (dead-ball / no team in possession, e.g. jump balls) is excluded from the
#' output — those spans aren't possessions.
#'
#' Technical free throws (verified against real data 2026-07-18) are shot by
#' a player on the team that did NOT commit the technical foul, but cdn's
#' `possession` column stays with the fouling team throughout — a technical
#' FT is not really part of either team's possession flow, it's an
#' out-of-band scoring event layered on top. Counting it into the enclosing
#' possession segment (as if scored by the possession-holding team) silently
#' misattributes points: verified as the root cause of a systematic +-1/+-2
#' point mismatch against final box scores in 78 of 364 team-games before
#' this fix. Technical FT points are therefore excluded from their enclosing
#' possession's own total and emitted as separate single-event possession
#' rows (outcome = "technical_ft"), credited to the actual shooting team.
#'
#' @param game_events tibble, one game's PBP events (from pbp_events.rds),
#'   already ordered by orderNumber
#' @return tibble, one row per possession (including technical-FT rows)
segment_possessions <- function(game_events) {
  ge <- game_events %>%
    arrange(orderNumber) %>%
    mutate(
      possession_filled = replace_na(possession, 0),
      seg_change = (possession_filled != lag(possession_filled, default = dplyr::first(possession_filled))) |
        (period != lag(period, default = dplyr::first(period))),
      possession_seg = cumsum(seg_change),
      is_technical_ft_made = actionType == "freethrow" & shotResult == "Made" &
        str_detect(coalesce(description, ""), regex("technical", ignore_case = TRUE))
    )

  teams_in_game <- ge %>% filter(!is.na(teamTricode)) %>% distinct(teamTricode) %>% pull(teamTricode)
  team_id_lookup <- ge %>% filter(!is.na(teamTricode)) %>% distinct(teamId, teamTricode)

  possessions <- ge %>%
    filter(possession_filled != 0) %>%
    group_by(possession_seg) %>%
    summarise(
      gameId = dplyr::first(gameId),
      period = dplyr::first(period),
      possession_team_id = dplyr::first(possession_filled),
      start_event = min(orderNumber),
      end_event = max(orderNumber),
      start_clock = max(parsed_clock_seconds, na.rm = TRUE),
      end_clock = min(parsed_clock_seconds, na.rm = TRUE),
      points = sum(compute_event_points(actionType, shotResult) * !is_technical_ft_made, na.rm = TRUE),
      is_transition = any(is_fastbreak, na.rm = TRUE),
      is_2ndchance = any(is_2ndchance, na.rm = TRUE),
      is_off_turnover = any(is_fromturnover, na.rm = TRUE),
      has_turnover = any(actionType == "turnover"),
      .groups = "drop"
    ) %>%
    left_join(team_id_lookup, by = c("possession_team_id" = "teamId")) %>%
    rename(team = teamTricode) %>%
    rowwise() %>%
    mutate(
      opponent = setdiff(teams_in_game, team)[1],
      outcome = if (points > 0) "score" else if (has_turnover) "turnover" else "no_score"
    ) %>%
    ungroup() %>%
    select(gameId, team, opponent, period, start_event, end_event,
           start_clock, end_clock, outcome, points, is_transition, is_2ndchance, is_off_turnover)

  technical_fts <- ge %>%
    filter(is_technical_ft_made) %>%
    transmute(
      gameId, period,
      team = teamTricode,
      opponent = purrr::map_chr(teamTricode, ~ setdiff(teams_in_game, .x)[1]),
      start_event = orderNumber, end_event = orderNumber,
      start_clock = parsed_clock_seconds, end_clock = parsed_clock_seconds,
      outcome = "technical_ft", points = 1,
      is_transition = FALSE, is_2ndchance = FALSE, is_off_turnover = FALSE
    )

  bind_rows(possessions, technical_fts) %>%
    arrange(start_event) %>%
    mutate(possession_id = paste0(gameId, "_", row_number())) %>%
    select(possession_id, gameId, team, opponent, period, start_event, end_event,
           start_clock, end_clock, outcome, points, is_transition, is_2ndchance, is_off_turnover)
}

#' Resolve free-throw trip sequencing ("1 of 2", "2 of 2", "1 of 1", "x of 3")
#'
#' @param ft_events tibble of freethrow actionType rows, with a subType column
#' @return tibble with trip_position, trip_total, is_last_ft_in_trip added
handle_ft_trips <- function(ft_events) {
  ft_events %>%
    mutate(
      trip_position = as.integer(str_extract(subType, "^\\d+")),
      trip_total = as.integer(str_extract(subType, "\\d+$")),
      is_last_ft_in_trip = trip_position == trip_total
    )
}

#' Flag technical free throws. Verified against real data 2026-07-18:
#' technical FTs carry normal subType ("1 of 1"), NOT a "technical" subType —
#' the marker is in the free-text `description` column instead.
#'
#' @param ft_events tibble of freethrow actionType rows, with a description column
#' @return tibble with is_technical_ft added
handle_technical_fts <- function(ft_events) {
  ft_events %>%
    mutate(is_technical_ft = str_detect(coalesce(description, ""), regex("technical", ignore_case = TRUE)))
}

#' Validate that and-one sequences (made FG immediately followed by a
#' non-technical shooting foul and a free throw taken by the SAME team that
#' made the basket) share a single possession (i.e. the `possession` column
#' does not change across them). Returns any violating rows found.
#'
#' Two refinements verified against real data 2026-07-18, both necessary to
#' avoid false positives:
#' (1) The FT shooter's team must match the made-shot team. A made basket
#'     immediately followed by the OPPONENT drawing a routine foul on the
#'     ensuing inbound (unrelated to the basket) has the same surface
#'     shape (make -> foul -> FT) but is not an and-one.
#' (2) The foul must not be technical. Technical FTs can coincidentally be
#'     taken by the team that just scored, matching refinement (1) by luck.
#'
#' Residual: 1 violation in 476 true and-one candidates (0.2%) — a team-foul
#' bonus free throw awarded to the scoring team on the ensuing inbound,
#' surface-identical to a true and-one and not distinguishable from event
#' fields alone. Documented and accepted rather than chased further
#' (deadline physics); it does not affect segment_possessions()'s own logic,
#' which reads the `possession` column directly rather than this heuristic.
#'
#' @param pbp tibble, full parsed pbp_events (pre-segmentation)
#' @return tibble of violations
handle_and_ones <- function(pbp) {
  pbp %>%
    arrange(gameId, orderNumber) %>%
    group_by(gameId) %>%
    mutate(
      next_action = lead(actionType, 1),
      next_subtype = lead(subType, 1),
      next_action2 = lead(actionType, 2),
      next_team2 = lead(teamTricode, 2),
      next_possession = lead(possession, 1),
      next_possession2 = lead(possession, 2)
    ) %>%
    ungroup() %>%
    filter(
      actionType %in% c("2pt", "3pt"), shotResult == "Made",
      next_action == "foul", next_subtype != "technical",
      next_action2 == "freethrow", teamTricode == next_team2,
      (possession != next_possession) | (possession != next_possession2)
    ) %>%
    select(gameId, orderNumber, actionType, possession, next_possession, next_possession2)
}

main <- function() {
  pbp <- readRDS("data/processed/pbp_events.rds")

  and_one_violations <- handle_and_ones(pbp)
  if (nrow(and_one_violations) != EXPECTED_AND_ONE_VIOLATIONS) {
    warning(nrow(and_one_violations), " and-one possession-continuity violation(s) found, expected ",
            EXPECTED_AND_ONE_VIOLATIONS, " — see handle_and_ones() docstring and output for detail")
  } else {
    message(nrow(and_one_violations), " and-one violation(s) found, matches documented baseline")
  }

  possessions <- pbp %>%
    split(.$gameId) %>%
    map_dfr(segment_possessions)

  dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
  saveRDS(possessions, "data/processed/possessions.rds")
  message("Wrote data/processed/possessions.rds (", nrow(possessions), " possessions, ",
          n_distinct(possessions$gameId), " games)")
  invisible(possessions)
}

if (sys.nframe() == 0) {
  main()
}
