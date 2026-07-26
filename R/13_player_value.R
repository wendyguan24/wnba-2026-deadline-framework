# ==============================================================================
# 13_player_value.R -- reproducible player production value (the "screen")
# ==============================================================================
#
# Purpose: a REPRODUCIBLE, open-data player-production proxy, built as Game Score
#   over replacement, per 40 minutes, from data/processed/pbp_events.rds. This is
#   the SCREEN, not the deliverable (R/14 is the fit-first deliverable). Per the
#   2026-07-22 design review (analytics-reviewer + gm-agent), the value NUMBER is
#   demoted: it is published only as coarse PRODUCTION TIERS attached to named
#   candidates inside fit reads, never as a ranked decimal leaderboard. This
#   script writes the full per-player table as an output/ reproducibility exhibit;
#   what enters the piece is tiers, offensive-scope, with the caveats below.
#
# What this is and is NOT (read before citing any number here):
#   - It is a BOX-SCORE PRODUCTION proxy (Hollinger Game Score). It is NOT an
#     impact metric (no RAPM/on-off: a half-season is too short for stable impact
#     estimates, and lineup/on-off work is on the handoff cut list).
#   - Game Score weights are NBA-derived and unvalidated for the WNBA -- disclosed
#     the same way the 0.44-FT pace convention is disclosed (output/eda_notes.md).
#   - It is OFFENSE-WEIGHTED and thin on defense (STL/BLK are the only defensive
#     terms). It values offensive production and matches offensive needs only. A
#     team whose deadline need is defensive cannot be served by this proxy. This
#     is a scope statement, not a footnote.
#   - It is a half-season rate. Published as tiers with a directional caveat, never
#     a defensible #7-vs-#12 ordering. Eligibility floors keep tiny samples out.
#   - "Value over replacement" here is in Game-Score points, NOT wins. No wins
#     conversion is claimed.
#
# Method:
#   1. Per-player box aggregates over the half-season (exclude personId 0 / team
#      non-player events).
#   2. Game Score (Hollinger):
#      GmSc = PTS + 0.4*FGM - 0.7*FGA - 0.4*(FTA-FTM) + 0.7*OREB + 0.3*DREB
#             + STL + 0.7*AST + 0.7*BLK - 0.4*PF - TOV
#   3. Minutes reconstructed from substitution events (validation gate: exactly 5
#      on court per team per period). Abort (stop()) if the gate fails on more than
#      FALLBACK_THRESH of team-periods: per the design-review abort criterion the
#      layer returns to post-deadline rather than publishing an untrustworthy
#      per-game rate. In practice the gate passes at 99.9 percent, so the
#      reconstructed per-40 rate is used.
#   4. Rate = Game Score per 40 minutes.
#   5. Eligibility (handoff Section 5g player-claim floor AND a minutes floor):
#      (FGA >= 100 OR possessions-used >= 150) AND minutes >= MIN_MINUTES.
#   6. Replacement = minutes-weighted mean GmSc/40 of BELOW-eligibility players
#      (freely-available-talent analogue), NOT a percentile of the rotation pool.
#      20th-percentile-of-eligible kept as a printed sensitivity only.
#   7. VOR = (GmSc/40 - replacement_rate) * (minutes / 40).
#   8. Production tiers = quartiles of GmSc/40 among eligible players.
#   9. Split-half (odd/even team-games) reliability diagnostic on GmSc/40, printed;
#      formal integration into R/10_framework_evaluation.R is a follow-up.
#
# Inputs:  data/processed/pbp_events.rds (personId, playerName, teamTricode,
#            actionType/subType, shotResult, period, parsed_clock_seconds,
#            orderNumber, assistPersonId, gameId).
# Outputs: output/player_value.csv (reproducibility exhibit, one row per player);
#            console summary (validation stats, replacement level, tiers, top by
#            production). No published leaderboard.
#
# Guardrails: reproducible from open data only; no Synergy; no dollars; language
#   hygiene (no em/en dashes, no smart quotes). Exploratory layer, no hypothesis
#   test (see PLAN.md addendum).
# ==============================================================================

suppressMessages(library(tidyverse))

proj_path <- function(...) {
  here <- tryCatch(rprojroot::find_root(rprojroot::has_file("README.md")),
                   error = function(e) getwd())
  file.path(here, ...)
}

# ---- tunables ----------------------------------------------------------------
MIN_MINUTES     <- 200    # minutes floor for eligibility (about 8+ min/game over
                          # the half-season). Deliberately below the design review's
                          # "~300" suggestion (Wendy, 2026-07-23): 200 keeps genuine
                          # rotation players in the eligible pool at the midseason
                          # snapshot; tiers are coarse so the looser floor is safe.
MIN_FGA         <- 100    # handoff Section 5g player-claim floor (OR poss-used)
MIN_POSS_USED   <- 150    # handoff Section 5g alternative floor
REPL_MIN_MIN    <- 50     # minutes floor for the replacement-anchor pool
FALLBACK_THRESH <- 0.10   # if > this share of team-periods fail the 5-on-court
                          # gate, fall back to a per-game rate (tiers only)
REG_PERIOD_SEC  <- 600    # WNBA quarter = 10 minutes
OT_PERIOD_SEC   <- 300    # WNBA overtime = 5 minutes

# ---- load --------------------------------------------------------------------
pbp <- readRDS(proj_path("data", "processed", "pbp_events.rds"))

# player events only (drop team / non-player rows: personId 0 or missing name)
pev <- pbp %>% filter(!is.na(personId), personId != 0, !is.na(playerName))

# ------------------------------------------------------------------------------
# 1. box aggregates per player
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 2. minutes from substitution reconstruction
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 3. assemble, rate, eligibility, replacement, VOR, tiers
# ------------------------------------------------------------------------------
box <- build_box(pev)
mn  <- build_minutes(pev)

# Abort criterion (design review 2026-07-22): if the 5-on-court gate fails on more
# than FALLBACK_THRESH of team-periods the per-40 rate is not trustworthy, so the
# layer returns to post-deadline rather than quietly degrading to a per-game rate.
if (mn$gate_pass_rate < (1 - FALLBACK_THRESH)) {
  stop(sprintf(
    paste0("build_minutes(): 5-on-court gate pass rate %.3f is below the %.2f ",
           "threshold. Per the abort criterion the player-value layer returns to ",
           "post-deadline; do not publish a per-game fallback."),
    mn$gate_pass_rate, 1 - FALLBACK_THRESH))
}
minutes_method <- "reconstructed"

tab <- box %>%
  left_join(mn$minutes, by = "personId") %>%
  mutate(minutes = replace_na(minutes, 0)) %>%
  mutate(exposure_40 = minutes / 40,
         gs_rate = if_else(exposure_40 > 0, game_score / exposure_40, NA_real_),
         rate_unit = "per40min")

# eligibility (handoff Section 5g floor AND minutes floor)
tab <- tab %>%
  mutate(eligible = (FGA >= MIN_FGA | poss_used >= MIN_POSS_USED) &
           (minutes >= MIN_MINUTES))

# replacement anchor: minutes-weighted mean rate of below-eligibility players
# with a minimum sample (freely-available-talent analogue, not a rotation pctile)
repl_pool <- tab %>% filter(!eligible, minutes >= REPL_MIN_MIN, !is.na(gs_rate))
replacement_rate <- with(repl_pool, sum(gs_rate * minutes) / sum(minutes))

# sensitivity: 20th percentile of eligible rate (printed only, not the anchor)
repl_sens_20 <- tab %>% filter(eligible) %>% pull(gs_rate) %>%
  quantile(0.20, na.rm = TRUE) %>% as.numeric()

tab <- tab %>%
  mutate(replacement_rate = replacement_rate,
         vor = (gs_rate - replacement_rate) * exposure_40)

# production tiers among eligible players (quartiles of rate); coarse by design
elig_rates <- tab %>% filter(eligible) %>% pull(gs_rate)
tier_breaks <- quantile(elig_rates, c(0, .25, .5, .75, 1), na.rm = TRUE)
tab <- tab %>%
  mutate(production_tier = case_when(
    !eligible ~ "below threshold",
    gs_rate >= tier_breaks[4] ~ "top",
    gs_rate >= tier_breaks[3] ~ "upper rotation",
    gs_rate >= tier_breaks[2] ~ "rotation",
    TRUE ~ "fringe"
  ))

# ------------------------------------------------------------------------------
# 4. split-half reliability diagnostic (odd/even team-games) on GmSc/40
# ------------------------------------------------------------------------------
#' Per (personId, gameId) Game Score, INCLUDING assists. Assists are credited on
#' the shooter's row via assistPersonId, so they are joined in separately (they
#' cannot be summed inside a group keyed on the acting player).
per_game_game_score <- function(pev) {
  base <- pev %>%
    group_by(personId, gameId) %>%
    summarise(
      FG2M = sum(actionType == "2pt" & shotResult == "Made"),
      FG3M = sum(actionType == "3pt" & shotResult == "Made"),
      FGA  = sum(actionType %in% c("2pt", "3pt")),
      FTM  = sum(actionType == "freethrow" & shotResult == "Made"),
      FTA  = sum(actionType == "freethrow"),
      OREB = sum(actionType == "rebound" & subType == "offensive"),
      DREB = sum(actionType == "rebound" & subType == "defensive"),
      STL  = sum(actionType == "steal"), BLK = sum(actionType == "block"),
      TOV  = sum(actionType == "turnover"),
      PF   = sum(actionType == "foul" & subType %in% c("personal", "offensive")),
      .groups = "drop")
  ast <- pev %>%
    filter(actionType %in% c("2pt", "3pt"), shotResult == "Made",
           !is.na(assistPersonId), assistPersonId != 0) %>%
    count(personId = assistPersonId, gameId, name = "AST")
  base %>%
    left_join(ast, by = c("personId", "gameId")) %>%
    mutate(AST = replace_na(AST, 0),
           FGM = FG2M + FG3M, PTS = 2 * FG2M + 3 * FG3M + FTM,
           gs = PTS + 0.4*FGM - 0.7*FGA - 0.4*(FTA-FTM) + 0.7*OREB + 0.3*DREB +
             STL + 0.7*AST + 0.7*BLK - 0.4*PF - TOV)
}

#' Split-half reliability of the PER-40 Game Score rate among eligible players
#' (the published unit). Per-game Game Score (with assists) is divided by per-game
#' reconstructed minutes to a per-40 rate; games under 5 minutes are dropped so a
#' tiny denominator cannot explode the rate. Each player's games are ordered and
#' split odd/even, the two half-mean rates correlated. Diagnostic; formal
#' integration into R/10 is a follow-up.
split_half_reliability <- function(pev, eligible_ids, minutes_by_game) {
  pg <- per_game_game_score(pev) %>%
    inner_join(minutes_by_game, by = c("personId", "gameId")) %>%
    filter(personId %in% eligible_ids, minutes >= 5) %>%
    mutate(rate = gs / (minutes / 40))

  halves <- pg %>%
    group_by(personId) %>%
    arrange(gameId, .by_group = TRUE) %>%
    mutate(half = if_else(row_number() %% 2 == 1, "odd", "even")) %>%
    group_by(personId, half) %>%
    summarise(rate_mean = mean(rate), n = n(), .groups = "drop")

  wide <- halves %>%
    pivot_wider(names_from = half, values_from = c(rate_mean, n)) %>%
    filter(!is.na(rate_mean_odd), !is.na(rate_mean_even), n_odd >= 3, n_even >= 3)
  if (nrow(wide) < 5) return(list(r = NA_real_, n = nrow(wide)))
  list(r = cor(wide$rate_mean_odd, wide$rate_mean_even), n = nrow(wide))
}

sh <- split_half_reliability(pev, tab$personId[tab$eligible], mn$minutes_by_game)

# ------------------------------------------------------------------------------
# 5. write exhibit + console summary
# ------------------------------------------------------------------------------
out <- tab %>%
  transmute(personId, playerName, team, games,
            minutes = round(minutes, 1), minutes_method,
            FGA, poss_used = round(poss_used, 1),
            game_score = round(game_score, 1),
            gs_rate = round(gs_rate, 3), rate_unit,
            replacement_rate = round(replacement_rate, 3),
            vor = round(vor, 2), eligible, production_tier) %>%
  arrange(desc(vor))

write_csv(out, proj_path("output", "player_value.csv"))

cat("=== R/13 player value (production screen) ===\n")
cat("minutes method:      ", minutes_method,
    "(5-on-court gate pass rate", round(mn$gate_pass_rate * 100, 1), "%)\n")
cat("players (all):       ", nrow(tab), "\n")
cat("eligible players:    ", sum(tab$eligible),
    sprintf("(FGA>=%d or poss>=%d, and minutes>=%d)\n", MIN_FGA, MIN_POSS_USED, MIN_MINUTES))
cat("replacement rate:    ", round(replacement_rate, 3),
    "GmSc/40 (below-eligibility pool, n =", nrow(repl_pool), ")\n")
cat("  sensitivity (20th pctile of eligible):", round(repl_sens_20, 3), "\n")
cat("split-half reliability of GmSc/40 per-40 rate (eligible, assists included): r =",
    ifelse(is.na(sh$r), "NA", round(sh$r, 2)), "on n =", sh$n, "players\n")
cat("tier counts:\n"); print(table(out$production_tier))
cat("\n=== top 15 eligible by production (GmSc/40); tiers are the published unit ===\n")
out %>% filter(eligible) %>% slice_head(n = 15) %>%
  select(playerName, team, games, minutes, gs_rate, vor, production_tier) %>%
  as.data.frame() %>% print(row.names = FALSE)
cat("\nWrote output/player_value.csv (reproducibility exhibit; publish tiers, not the leaderboard).\n")
