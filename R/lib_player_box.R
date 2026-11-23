# lib_player_box.R
#
# Purpose: player box aggregates and substitution-based minutes reconstruction,
#   extracted verbatim from R/13_player_value.R so R/04b_analysis_tables.R and
#   R/13 share one implementation. No logic changes. Function bodies are
#   byte-identical to the originals (checked by diff at extraction time).

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

#' Infer, per (game, period, team, player), whether the player started the period
#' (on court at period start) and reconstruct on-court seconds.
#'
#' Starter rule: a player is on court at period start iff, within the period,
#' their earliest event (of any type, including a sub-out) precedes their first
#' sub-in (Inf if none). Validated at 99.9 percent of team-periods returning
#' exactly 5 starters.
#'
#' Minutes: on-clocks = c(period_len if starter, sub-in clocks); off-clocks =
#' c(sub-out clocks, 0 if the player ends the period on court). Because on/off
#' alternate, seconds = sum(on_clocks) - sum(off_clocks).
#'
#' @param pev tibble, player-only pbp events
#' @return list(minutes = tibble personId/minutes, gate_pass_rate = numeric)
build_minutes <- function(pev) {
  ev <- pev %>%
    mutate(is_sub = actionType == "substitution",
           is_in  = is_sub & subType == "in",
           is_out = is_sub & subType == "out",
           period_len = if_else(period <= 4, REG_PERIOD_SEC, OT_PERIOD_SEC))

  # starter flag per (game, period, team, player)
  starter <- ev %>%
    group_by(gameId, period, teamTricode, personId) %>%
    summarise(first_in  = if (any(is_in)) min(orderNumber[is_in]) else Inf,
              first_any = min(orderNumber),
              period_len = first(period_len),
              .groups = "drop") %>%
    mutate(started = first_any < first_in)

  # validation gate: exactly 5 starters per team-period
  gate <- starter %>% filter(started) %>%
    count(gameId, period, teamTricode, name = "n_starters")
  gate_pass_rate <- mean(gate$n_starters == 5)

  # sub-in / sub-out clock lists per player-period
  ins <- ev %>% filter(is_in) %>%
    group_by(gameId, period, teamTricode, personId) %>%
    summarise(in_clocks = list(parsed_clock_seconds), .groups = "drop")
  outs <- ev %>% filter(is_out) %>%
    group_by(gameId, period, teamTricode, personId) %>%
    summarise(out_clocks = list(parsed_clock_seconds), .groups = "drop")

  stints <- starter %>%
    left_join(ins, by = c("gameId", "period", "teamTricode", "personId")) %>%
    left_join(outs, by = c("gameId", "period", "teamTricode", "personId"))

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
       gate_pass_rate = gate_pass_rate)
}
