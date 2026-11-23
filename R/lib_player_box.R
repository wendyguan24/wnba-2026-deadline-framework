# lib_player_box.R
#
# Purpose: player box aggregates and substitution-based minutes reconstruction,
#   extracted from R/13_player_value.R so R/04b_analysis_tables.R and R/13 share
#   one implementation. build_box() is byte-identical to the original.
#   build_minutes() keeps the original return shape and seconds identity but
#   replaces the period-starter inference (offseason change, see PLAN.md):
#   the v1 rule missed players with zero events in a period (4 starters) and
#   counted a player whose event shares a clock with their own sub-in (6 starters).

suppressMessages(library(tidyverse))

REG_PERIOD_SEC  <- 600    # WNBA quarter = 10 minutes
OT_PERIOD_SEC   <- 300    # WNBA overtime = 5 minutes

#' Aggregate per-player box-score counting stats over the half-season.
#' @param pev tibble, player-only pbp events
#' @return tibble, one row per personId with the Game Score inputs
build_box <- function(pev) {
  shots <- pev %>% filter(actionType %in% c("2pt", "3pt"))
  fts   <- pev %>% filter(actionType == "freethrow")
  rebs  <- pev %>% filter(actionType == "rebound")

  # assists are credited on the made-shot row via assistPersonId
  asts <- pev %>%
    filter(actionType %in% c("2pt", "3pt"), shotResult == "Made",
           !is.na(assistPersonId), assistPersonId != 0) %>%
    count(personId = assistPersonId, name = "AST")

  # key on personId only; a few players have name-spelling variants across rows,
  # and a traded player keeps one personId -- take the modal name and team
  base <- pev %>%
    group_by(personId) %>%
    summarise(playerName = names(sort(table(playerName), decreasing = TRUE))[1],
              team  = names(sort(table(teamTricode), decreasing = TRUE))[1],
              games = n_distinct(gameId),
              .groups = "drop")

  shot_agg <- shots %>%
    group_by(personId) %>%
    summarise(
      FG2M = sum(actionType == "2pt" & shotResult == "Made"),
      FG3M = sum(actionType == "3pt" & shotResult == "Made"),
      FGA  = n(),
      .groups = "drop"
    )
  ft_agg <- fts %>%
    group_by(personId) %>%
    summarise(FTM = sum(shotResult == "Made"), FTA = n(), .groups = "drop")
  reb_agg <- rebs %>%
    group_by(personId) %>%
    summarise(OREB = sum(subType == "offensive"),
              DREB = sum(subType == "defensive"), .groups = "drop")
  stl <- pev %>% filter(actionType == "steal") %>% count(personId, name = "STL")
  blk <- pev %>% filter(actionType == "block") %>% count(personId, name = "BLK")
  tov <- pev %>% filter(actionType == "turnover") %>% count(personId, name = "TOV")
  # PF = personal fouls (includes offensive fouls, excludes technicals)
  pf  <- pev %>% filter(actionType == "foul", subType %in% c("personal", "offensive")) %>%
    count(personId, name = "PF")

  base %>%
    left_join(shot_agg, by = "personId") %>%
    left_join(ft_agg, by = "personId") %>%
    left_join(reb_agg, by = "personId") %>%
    left_join(asts, by = "personId") %>%
    left_join(stl, by = "personId") %>%
    left_join(blk, by = "personId") %>%
    left_join(tov, by = "personId") %>%
    left_join(pf, by = "personId") %>%
    mutate(across(c(FG2M, FG3M, FGA, FTM, FTA, OREB, DREB, AST, STL, BLK, TOV, PF),
                  ~replace_na(., 0L))) %>%
    mutate(
      FGM = FG2M + FG3M,
      PTS = 2 * FG2M + 3 * FG3M + FTM,
      poss_used = FGA + 0.44 * FTA + TOV,
      game_score = PTS + 0.4 * FGM - 0.7 * FGA - 0.4 * (FTA - FTM) +
        0.7 * OREB + 0.3 * DREB + STL + 0.7 * AST + 0.7 * BLK - 0.4 * PF - TOV
    )
}

#' Reconstruct on-court minutes from substitution events.
#'
#' Starter inference, per (game, team), periods in order (the source has no
#' period-start lineups):
#'  1. Seed S: players whose first sub action in the period is "out", plus
#'     players with a non-sub event at a clock strictly earlier in the game
#'     (greater clock seconds) than their first sub-in in that period, or with
#'     no sub-in at all. Technical fouls do not count as on-court evidence
#'     (a bench player can be assessed one). An event at the SAME clock as the player's sub-in does
#'     not make them a starter.
#'  2. If |S| < 5 and period > 1: add players from the previous period's
#'     end-of-period on-court set who are not in S and whose first sub action
#'     this period is not "in". Used only if that yields exactly 5.
#'  3. Backward fill: if a period is still short of 5 and the next period has 5,
#'     the missing player is in the next period's starting lineup, absent from
#'     this period's partial closing lineup, and had no sub-in this period
#'     (between-period subs are logged at the start of the next period). Used
#'     only if that yields exactly 5.
#'  4. Anything still not exactly 5 is left as inferred (not guessed) and is
#'     listed in the `starter_counts` element (n_starters != 5).
#'
#' Minutes: on-clocks = c(period_len if starter, sub-in clocks); off-clocks =
#' c(sub-out clocks, 0 if the player ends the period on court). Because on/off
#' alternate, seconds = sum(on_clocks) - sum(off_clocks).
#'
#' @param pev tibble, player-only pbp events
#' @return list(minutes, minutes_by_game, gate_pass_rate, starter_counts);
#'   gate_pass_rate is the share of team-periods with exactly 5 starters.
build_minutes <- function(pev) {
  ev <- pev %>%
    mutate(is_sub = actionType == "substitution",
           is_in  = is_sub & subType == "in",
           is_out = is_sub & subType == "out",
           is_ev  = !is_sub & !(actionType == "foul" & subType %in% "technical"),
           period_len = if_else(period <= 4, REG_PERIOD_SEC, OT_PERIOD_SEC))

  # one row per (game, period, team, player)
  pp <- ev %>%
    group_by(gameId, period, teamTricode, personId) %>%
    summarise(
      first_sub = if (any(is_sub)) subType[is_sub][which.min(orderNumber[is_sub])] else NA_character_,
      first_in_clock = if (any(is_in)) parsed_clock_seconds[is_in][which.min(orderNumber[is_in])] else NA_real_,
      # on-court evidence: non-sub events, excluding technical fouls (a bench player
      # can be assessed one: seen in games 1022600237 and 1022600312)
      max_nonsub_clock = if (any(is_ev)) max(parsed_clock_seconds[is_ev]) else NA_real_,
      period_len = first(period_len),
      in_clocks = list(parsed_clock_seconds[is_in]),
      out_clocks = list(parsed_clock_seconds[is_out]),
      .groups = "drop") %>%
    mutate(seed = (!is.na(first_sub) & first_sub == "out") |
             (!is.na(max_nonsub_clock) & (is.na(first_in_clock) | max_nonsub_clock > first_in_clock)))

  plens <- ev %>% distinct(gameId, period, period_len)
  stint_rows <- list()
  count_rows <- list()
  groups <- pp %>% group_by(gameId, teamTricode) %>% group_split()
  finalize_period <- function(p, S) {
    p$started <- p$personId %in% S
    n_on <- p$started + lengths(p$in_clocks)
    p$ends_on <- n_on > lengths(p$out_clocks)
    p
  }
  for (grp in groups) {
    prev_end <- numeric(0)
    prev <- NULL   # state of the previous period: row indices, p (without extras), S
    for (per in sort(unique(grp$period))) {
      p <- grp[grp$period == per, ]
      S <- p$personId[p$seed]
      if (length(S) < 5 && per > 1) {
        add <- setdiff(prev_end, S)
        add <- add[!(add %in% p$personId[!is.na(p$first_sub) & p$first_sub == "in"])]
        if (length(S) + length(add) == 5) S <- c(S, add)
      }
      # Backward fill: if the previous period is still short of 5 starters, the
      # missing one is on this period's starting lineup (between-period subs are
      # logged at the start of the next period), is not on the previous period's
      # partial closing lineup, and had no sub-in in the previous period.
      if (!is.null(prev) && length(prev$S) < 5 && length(S) == 5) {
        cand <- setdiff(S, prev$end)
        cand <- cand[!(cand %in% prev$p$personId[!is.na(prev$p$first_sub) & prev$p$first_sub == "in"])]
        if (length(prev$S) + length(cand) == 5) {
          pp_prev <- prev$p
          extra <- setdiff(cand, pp_prev$personId)
          if (length(extra) > 0) {
            pp_prev <- bind_rows(pp_prev, tibble(gameId = pp_prev$gameId[1], period = pp_prev$period[1],
                                 teamTricode = pp_prev$teamTricode[1], personId = extra,
                                 period_len = pp_prev$period_len[1],
                                 in_clocks = list(numeric(0)), out_clocks = list(numeric(0))))
          }
          S_prev <- c(prev$S, cand)
          pp_prev <- finalize_period(pp_prev, S_prev)
          stint_rows[[prev$idx]] <- pp_prev
          count_rows[[prev$idx]]$n_starters <- length(S_prev)
          prev_end <- NULL
          # this period's step-3 fill (if any) used the partial lineup; it was not needed
          # when S already had 5 starters, so S stands.
        }
      }
      # rows for starters with no events this period (carried from prior period)
      extra <- setdiff(S, p$personId)
      p0 <- p
      if (length(extra) > 0) {
        p <- bind_rows(p, tibble(gameId = p$gameId[1], period = per, teamTricode = p$teamTricode[1],
                                 personId = extra, period_len = p$period_len[1],
                                 in_clocks = list(numeric(0)), out_clocks = list(numeric(0))))
      }
      p <- finalize_period(p, S)
      prev_end <- p$personId[p$ends_on]
      idx <- length(stint_rows) + 1
      stint_rows[[idx]] <- p
      count_rows[[idx]] <- tibble(gameId = p$gameId[1], period = per,
        teamTricode = p$teamTricode[1], n_starters = length(S))
      prev <- list(idx = idx, p = p0, S = S, end = prev_end)
    }
  }
  stints <- bind_rows(stint_rows)
  starter_counts <- bind_rows(count_rows)
  gate_pass_rate <- mean(starter_counts$n_starters == 5)

  # per-row seconds via the sum(on) - sum(off) identity
  secs <- pmap_dbl(
    list(stints$started, stints$period_len, stints$in_clocks, stints$out_clocks),
    function(started, plen, inc, outc) {
      inc  <- if (is.null(inc)) numeric(0) else inc
      outc <- if (is.null(outc)) numeric(0) else outc
      on_clocks <- c(if (started) plen else numeric(0), inc)
      # if the player ends the period on court, close the last stint at clock 0
      if (length(on_clocks) > length(outc)) outc <- c(outc, 0)
      sum(on_clocks) - sum(outc)
    }
  )
  stints$seconds <- secs

  minutes_by_game <- stints %>%
    group_by(personId, gameId) %>%
    summarise(minutes = sum(seconds) / 60, .groups = "drop")
  minutes <- minutes_by_game %>%
    group_by(personId) %>%
    summarise(minutes = sum(minutes), .groups = "drop")

  list(minutes = minutes, minutes_by_game = minutes_by_game,
       gate_pass_rate = gate_pass_rate, starter_counts = starter_counts)
}
