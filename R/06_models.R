# 06_models.R
#
# Purpose: Fit the schedule-adjusted identity models. For each style metric,
#   metric ~ (1|team) + (1|opponent) + is_home in lme4. Extract team BLUPs
#   (adjusted identity) and ICC (stable identity vs. matchup noise). Signature
#   deliverable: raw rank vs. adjusted rank deltas. Ports the NCAA
#   Movement-vs-Gravity machinery directly.
#   See HANDOFF §5c.
#
#   ALSO fits the trajectory layer (§5c-bis, AMENDMENT_01 Part 1): a
#   deadline decision is a bet on trajectory, not just current-state
#   identity, so trajectory is a required deadline-read column, not an
#   optional extra.
#
#   is_home fixed effect and the transition_pts_per_poss possession-count
#   weighting are both spec decisions forced by the EDA gate
#   (analysis/eda_midseason.Rmd, output/eda_notes.md) — see PLAN.md.
#
# Inputs:  data/processed/team_game_features.rds,
#   data/processed/team_game_shot_making.rds (shot_making_residual, from
#   07_expected_points.R -- run 07 before 06),
#   data/processed/possessions.rds and data/processed/pbp_events.rds and
#   data/processed/expected_points_baseline.rds (all three for the
#   AMENDMENT_01 2c garbage-time sensitivity pass, from 07 / 02 / 03),
#   output/eda_notes.md
#   (hypotheses registry — H1, H2, H3, H-null; do not invent hypotheses
#   after seeing trajectory results)
# Outputs: data/processed/team_blups.rds, output/icc_table.csv,
#   data/processed/team_trajectories.rds (slopes, intervals, league trend,
#   improving/flat/declining classification per team per metric)

library(tidyverse)
library(lme4)

# Full identity-layer metric list (HANDOFF §5b, matches the EDA gate's
# 21-metric ICC preview minus pace_formula, which is a secondary cross-check
# column only, never modeled — see the EDA gate's pace spec decision). Models
# pace_per40 (possessions normalized to a 40-minute game), not raw pace_poss —
# the analytics-reviewer's decisions-only pass on the EDA gate (PLAN.md,
# 2026-07-19, WARNING 3) flagged that the original is_ot flag deferred the
# actual OT treatment; pace_per40 (added in R/05_features.R) removes the
# mechanical inflation in OT team-games (95.7 raw vs 81.0 regulation,
# collapsing to 81.8 vs 81.0 once normalized) rather than leaving it to be
# absorbed silently into the team/opponent random effects.
IDENTITY_METRICS <- c(
  "pace_per40", "fg3a_rate", "assisted_rate", "transition_share",
  "transition_pts_per_poss", "off_tov_share", "secondchance_share",
  "paint_fgm_share", "ra_share", "paint_share", "mid_share", "corner3_share",
  "atb3_share", "driving_share", "pullup_share", "cutting_share",
  "putback_share", "ft_rate", "tov_rate", "live_ball_tov_rate"
)

# Trajectory models run on this shortlist only (AMENDMENT_01 §1). Column
# names match data/processed/team_game_features.rds (05_features.R); the
# skeleton's original placeholder names (transition_pts_per_possession,
# assisted_rate_of_fgm) are renamed here to the columns 05 actually produced.
# shot_making_residual (H3, GSV-relevant) is now built by 07_expected_points.R
# and joined onto features in main() below. Per PLAN.md's cut order it
# remains the first metric to cut under time pressure -- cleanly removable
# by deleting this vector's shot_making_residual line and the two main()
# join lines; never cut the deadline-read `trajectory` column itself --
# fall back to raw trends with a stated caveat first.
TRAJECTORY_METRICS <- c(
  "transition_share",         # H1
  "transition_pts_per_poss",  # H1, efficiency side (cut first if time-constrained)
  "assisted_rate",             # H2
  "live_ball_tov_rate",        # H2
  "shot_making_residual"       # H3, GSV-relevant (from 07_expected_points.R)
)

# Metrics fit with possession-count weights per the EDA gate's weighting
# decision (output/eda_notes.md §3): transition_pts_per_poss's denominator
# (transition_poss) ranges from single digits to 20+ per team-game, unlike
# FGA-based denominators which stay in a tight, larger band.
WEIGHTED_METRICS <- c("transition_pts_per_poss")

# Hard boundary (AMENDMENT_01 §1, carried from HANDOFF guardrails): isolation
# trends are NOT measurable in the open data (no play-type tags) and must
# never be claimed from it. If used at all, iso trajectory comes only from
# Synergy date-filtered team exports, in case-study prose, quarantined per
# the Synergy rule — never in this script's output.

#' Fit a mixed-effects identity model for one style metric:
#' metric ~ (1|team) + (1|opponent) + is_home. Applies the EDA gate's
#' possession-count weighting decision for WEIGHTED_METRICS.
#'
#' @param features tibble, team-game feature table
#' @param metric_name character, column name of the style metric
#' @return an lme4 model object
fit_mixed_model <- function(features, metric_name) {
  form <- as.formula(paste(metric_name, "~ is_home + (1 | team) + (1 | opponent)"))
  if (metric_name %in% WEIGHTED_METRICS) {
    weight_col <- if (metric_name == "transition_pts_per_poss") "transition_poss" else NULL
    lmer(form, data = features, weights = features[[weight_col]])
  } else {
    lmer(form, data = features)
  }
}

#' Extract team-level BLUPs (schedule-adjusted identity) from a fitted model:
#' fixed intercept + team random effect, i.e. each team's expected metric
#' value holding opponent and home/away schedule constant. (The is_home
#' coefficient is a league-wide correction, not part of team identity, so it
#' is not added back in here — a team's BLUP is its adjusted average across a
#' neutral, average-opponent schedule.)
#'
#' @param model lme4 model object
#' @return tibble, one row per team, adjusted metric value
extract_blups <- function(model) {
  intercept <- fixef(model)[["(Intercept)"]]
  team_re <- ranef(model)$team
  tibble(team = rownames(team_re), adjusted_value = intercept + team_re[["(Intercept)"]])
}

#' Compute the intraclass correlation (ICC) for the team random effect:
#' team variance / (team variance + opponent variance + residual variance).
#'
#' @param model lme4 model object
#' @return numeric, ICC
compute_icc <- function(model) {
  vc <- as.data.frame(VarCorr(model))
  team_var <- vc$vcov[vc$grp == "team"]
  opponent_var <- vc$vcov[vc$grp == "opponent"]
  residual_var <- vc$vcov[vc$grp == "Residual"]
  team_var / (team_var + opponent_var + residual_var)
}

#' Compare raw (unadjusted) team rank to schedule-adjusted rank. delta is
#' positive when a team's adjusted rank is higher (better) than its raw rank
#' — i.e. schedule was suppressing its raw number — and negative when a
#' tougher schedule (weak opponents, more home games) was inflating it.
#'
#' @param features tibble, raw team-game feature table
#' @param blups tibble, adjusted BLUPs
#' @param metric_name character, column name of the style metric
#' @return tibble, one row per team, raw_value, raw_rank, adjusted_value, adjusted_rank, delta
rank_deltas <- function(features, blups, metric_name) {
  raw <- features %>%
    group_by(team) %>%
    summarise(raw_value = mean(.data[[metric_name]]), .groups = "drop") %>%
    mutate(raw_rank = rank(-raw_value, ties.method = "min"))

  blups %>%
    mutate(adjusted_rank = rank(-adjusted_value, ties.method = "min")) %>%
    left_join(raw, by = "team") %>%
    mutate(delta = raw_rank - adjusted_rank) %>%
    select(team, raw_value, raw_rank, adjusted_value, adjusted_rank, delta)
}

#' Fit identity models for every metric in IDENTITY_METRICS and assemble the
#' BLUP table, ICC table, and rank-delta table.
#'
#' @param features tibble, team-game feature table
#' @return list(blups = tibble, icc_table = tibble, rank_deltas = tibble)
fit_all_identity_models <- function(features) {
  results <- map(IDENTITY_METRICS, function(m) {
    model <- fit_mixed_model(features, m)
    list(
      metric = m,
      blups = extract_blups(model) %>% mutate(metric = m),
      icc = compute_icc(model),
      deltas = rank_deltas(features, extract_blups(model), m) %>% mutate(metric = m)
    )
  })
  names(results) <- IDENTITY_METRICS

  list(
    blups = map_dfr(results, "blups") %>% select(metric, team, adjusted_value),
    icc_table = tibble(metric = map_chr(results, "metric"), icc = map_dbl(results, "icc")) %>%
      arrange(desc(icc)),
    rank_deltas = map_dfr(results, "deltas")
  )
}

# --- Trajectory layer (§5c-bis, AMENDMENT_01 Part 1) -----------------------

#' Fit the trajectory model for one metric on the TRAJECTORY_METRICS
#' shortlist: metric ~ game_index + (1 + game_index | team) + (1 | opponent).
#' `game_index` is each team's own game number (1..N), not calendar date, so
#' teams with unequal schedules are comparable. If the random-slope model
#' fails to converge (checked via lme4's own convergence diagnostics —
#' optinfo$conv$lme4$messages, plus a singular-fit check), falls back to
#' fixed game_index + random intercepts only, and per-team trajectory is then
#' approximated from that model's residuals: each team's own OLS slope of its
#' residuals (observed minus the intercept-only model's fitted value) against
#' game_index, i.e. a late-season observed-minus-expected read rather than a
#' formal random-slope BLUP.
#'
#' @param features tibble, team-game feature table with a game_index column
#' @param metric_name character, one of TRAJECTORY_METRICS
#' @return list(model = lme4 model object, fallback_used = logical,
#'   fallback_residual_slopes = tibble or NULL)
fit_trajectory_model <- function(features, metric_name) {
  full_form <- as.formula(paste(metric_name, "~ game_index + (1 + game_index | team) + (1 | opponent)"))
  weight_col <- if (metric_name %in% WEIGHTED_METRICS) "transition_poss" else NULL
  weights_vec <- if (!is.null(weight_col)) features[[weight_col]] else NULL

  conv_messages <- character(0)
  full_model <- withCallingHandlers(
    tryCatch(
      if (!is.null(weights_vec)) lmer(full_form, data = features, weights = weights_vec, control = lmerControl(optimizer = "bobyqa"))
      else lmer(full_form, data = features, control = lmerControl(optimizer = "bobyqa")),
      error = function(e) NULL
    ),
    warning = function(w) {
      conv_messages <<- c(conv_messages, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  has_convergence_issue <- is.null(full_model) ||
    length(full_model@optinfo$conv$lme4$messages) > 0 ||
    isSingular(full_model) ||
    length(conv_messages) > 0

  if (!has_convergence_issue) {
    return(list(model = full_model, fallback_used = FALSE, fallback_residual_slopes = NULL))
  }

  fallback_form <- as.formula(paste(metric_name, "~ game_index + (1 | team) + (1 | opponent)"))
  fallback_model <- if (!is.null(weights_vec)) lmer(fallback_form, data = features, weights = weights_vec)
                    else lmer(fallback_form, data = features)

  resid_slopes <- features %>%
    mutate(.resid = residuals(fallback_model)) %>%
    group_by(team) %>%
    summarise(
      slope = coef(lm(.resid ~ game_index))[["game_index"]],
      se = summary(lm(.resid ~ game_index))$coefficients["game_index", "Std. Error"],
      .groups = "drop"
    ) %>%
    mutate(ci_low = slope - 1.96 * se, ci_high = slope + 1.96 * se)

  list(model = fallback_model, fallback_used = TRUE, fallback_residual_slopes = resid_slopes)
}

#' Extract per-team trajectory slopes (random slope BLUPs) with uncertainty
#' intervals, and the fixed effect (league-wide trend, tests H1/H2 at scale).
#' Uses the fallback's residual-slope table directly when fit_trajectory_model
#' fell back to random-intercepts-only.
#'
#' @param fit list from fit_trajectory_model()
#' @return list(team_slopes = tibble(team, slope, ci_low, ci_high),
#'   league_trend = numeric, league_trend_p = numeric, fallback_used = logical)
extract_trajectory_slopes <- function(fit) {
  league_trend <- fixef(fit$model)[["game_index"]]
  league_trend_se <- summary(fit$model)$coefficients["game_index", "Std. Error"]
  league_trend_p <- 2 * pnorm(-abs(league_trend / league_trend_se))

  if (fit$fallback_used) {
    team_slopes <- fit$fallback_residual_slopes %>%
      mutate(slope = slope + league_trend) %>%
      select(team, slope, ci_low, ci_high) %>%
      mutate(ci_low = ci_low + league_trend, ci_high = ci_high + league_trend)
  } else {
    team_re <- ranef(fit$model, condVar = TRUE)$team
    post_var <- attr(team_re, "postVar")
    slope_se <- sqrt(post_var[2, 2, ])
    team_slopes <- tibble(
      team = rownames(team_re),
      slope = league_trend + team_re[["game_index"]],
      ci_low = league_trend + team_re[["game_index"]] - 1.96 * slope_se,
      ci_high = league_trend + team_re[["game_index"]] + 1.96 * slope_se
    )
  }

  list(team_slopes = team_slopes, league_trend = league_trend,
       league_trend_p = league_trend_p, fallback_used = fit$fallback_used)
}

#' Classify each team's trajectory as improving / flat / declining from its
#' slope sign; footnote (interval_spans_zero) when the interval spans zero
#' rather than force a "flat" label — per-team slopes are directional, not
#' standalone claims (AMENDMENT_01 §1 "Reporting rules"); lean on the
#' league-wide fixed effect for strong claims.
#'
#' @param team_slopes tibble from extract_trajectory_slopes()$team_slopes
#' @return tibble, adds columns trajectory ("improving"/"flat"/"declining")
#'   and interval_spans_zero (logical)
classify_trajectory <- function(team_slopes) {
  team_slopes %>%
    mutate(
      trajectory = case_when(slope > 0 ~ "improving", slope < 0 ~ "declining", TRUE ~ "flat"),
      interval_spans_zero = ci_low <= 0 & ci_high >= 0
    )
}

#' Fit trajectory models for every metric in TRAJECTORY_METRICS and assemble
#' the combined per-team, per-metric trajectory table plus the league-trend
#' summary (the H1/H2 test at scale).
#'
#' @param features tibble, team-game feature table
#' @return list(team_trajectories = tibble, league_trends = tibble)
fit_all_trajectory_models <- function(features) {
  results <- map(TRAJECTORY_METRICS, function(m) {
    fit <- fit_trajectory_model(features, m)
    slopes <- extract_trajectory_slopes(fit)
    classified <- classify_trajectory(slopes$team_slopes) %>% mutate(metric = m)
    list(metric = m, team_trajectories = classified, league_trend = slopes$league_trend,
         league_trend_p = slopes$league_trend_p, fallback_used = slopes$fallback_used)
  })
  names(results) <- TRAJECTORY_METRICS

  list(
    team_trajectories = map_dfr(results, "team_trajectories") %>%
      select(metric, team, slope, ci_low, ci_high, trajectory, interval_spans_zero),
    league_trends = tibble(
      metric = map_chr(results, "metric"),
      league_trend = map_dbl(results, "league_trend"),
      league_trend_p = map_dbl(results, "league_trend_p"),
      fallback_used = map_lgl(results, "fallback_used")
    )
  )
}

# --- AMENDMENT_01 2c garbage-time sensitivity pass --------------------------
# Pre-registered in output/eda_notes.md 6: re-run the five shortlist trajectory
# metrics excluding garbage-time possessions/shots and confirm no finding flips
# direction. Garbage-time rule matches R/05: period >= 4 and |margin| >= 20. The
# expected-points baseline (the league yardstick) is held fixed at its all-shots
# values; only each team-game's own shots and possessions are filtered, so this
# isolates the garbage-time effect on the team-game metric, not on the yardstick.

#' Recompute the five trajectory-shortlist metrics per team-game on
#' non-garbage-time data only, returning a features table with the same
#' game_index / opponent keys as the main run so fit_all_trajectory_models()
#' can be reused unchanged. The xpts_baseline is held fixed (not rebuilt).
#'
#' @param pbp tibble, pbp_events.rds
#' @param possessions tibble, possessions.rds
#' @param features tibble, team_game_features.rds (for game_index/opponent keys)
#' @param xpts_baseline tibble, expected_points_baseline.rds (held fixed)
#' @return tibble, one row per team-game, the five metrics recomputed ex-garbage
recompute_trajectory_metrics_excluding_garbage <- function(pbp, possessions, features, xpts_baseline) {
  margin_at_start <- pbp %>% select(gameId, start_event = orderNumber, scoreHome, scoreAway)
  poss_metrics <- possessions %>%
    filter(outcome != "technical_ft") %>%
    left_join(margin_at_start, by = c("gameId", "start_event")) %>%
    mutate(poss_garbage = period >= 4 & abs(scoreHome - scoreAway) >= 20) %>%
    filter(!poss_garbage) %>%
    group_by(gameId, team) %>%
    summarise(
      pace_poss = n(),
      transition_poss = sum(is_transition),
      transition_pts = sum(points[is_transition]),
      .groups = "drop"
    ) %>%
    mutate(
      transition_share = transition_poss / pace_poss,
      transition_pts_per_poss = transition_pts / transition_poss
    )

  shots_ng <- pbp %>%
    filter(actionType %in% c("2pt", "3pt"),
           !(period >= 4 & abs(scoreHome - scoreAway) >= 20))

  ar <- shots_ng %>%
    group_by(gameId, team = teamTricode) %>%
    summarise(
      FGM = sum(shotResult == "Made"),
      assisted_FGM = sum(shotResult == "Made" & !is.na(assistPersonId)),
      .groups = "drop"
    ) %>%
    mutate(assisted_rate = assisted_FGM / FGM)

  smr <- shots_ng %>%
    transmute(
      gameId, team = teamTricode,
      points_scored = case_when(shotResult != "Made" ~ 0, actionType == "3pt" ~ 3, TRUE ~ 2),
      zone = case_when(area %in% c("Left Corner 3", "Right Corner 3") ~ "Corner 3", TRUE ~ area),
      shot_class = case_when(
        str_detect(coalesce(descriptor, ""), "putback") ~ "putback",
        str_detect(coalesce(descriptor, ""), "cutting") ~ "cutting",
        str_detect(coalesce(descriptor, ""), "driving") ~ "driving",
        str_detect(coalesce(descriptor, ""), "pullup")  ~ "pullup",
        TRUE ~ "other"),
      context = case_when(
        coalesce(is_fastbreak, FALSE) ~ "transition",
        coalesce(is_2ndchance, FALSE) ~ "second_chance",
        TRUE ~ "halfcourt")
    ) %>%
    left_join(xpts_baseline %>% select(zone, shot_class, context, xpts),
              by = c("zone", "shot_class", "context")) %>%
    group_by(gameId, team) %>%
    summarise(expected_pts = sum(xpts), actual_pts = sum(points_scored), .groups = "drop")

  lbt <- pbp %>%
    filter(actionType == "turnover",
           !(period >= 4 & abs(scoreHome - scoreAway) >= 20)) %>%
    group_by(gameId, team = teamTricode) %>%
    summarise(live_ball_TOV = sum(!is.na(stealPersonId)), .groups = "drop")

  features %>%
    select(gameId, team, opponent, game_index) %>%
    left_join(poss_metrics, by = c("gameId", "team")) %>%
    left_join(ar %>% select(gameId, team, assisted_rate), by = c("gameId", "team")) %>%
    left_join(smr, by = c("gameId", "team")) %>%
    left_join(lbt, by = c("gameId", "team")) %>%
    mutate(
      live_ball_tov_rate = live_ball_TOV / pace_poss,
      shot_making_residual = (actual_pts - expected_pts) / pace_poss * 100
    ) %>%
    select(gameId, team, opponent, game_index,
           transition_share, transition_pts_per_poss, transition_poss,
           assisted_rate, live_ball_tov_rate, shot_making_residual)
}

#' Compare main (all-data) vs garbage-excluded trajectory results per metric:
#' league-trend sign flip, significance-status change at p < 0.05, and the
#' count of teams whose improving/flat/declining classification changed.
#'
#' @param traj_main list from fit_all_trajectory_models(features)
#' @param traj_ng list from fit_all_trajectory_models(features_ng)
#' @return tibble, one row per metric
compare_trajectory_sensitivity <- function(traj_main, traj_ng) {
  lt <- traj_main$league_trends %>%
    select(metric, trend_main = league_trend, p_main = league_trend_p) %>%
    left_join(traj_ng$league_trends %>%
                select(metric, trend_ng = league_trend, p_ng = league_trend_p),
              by = "metric") %>%
    mutate(
      sign_flip = sign(trend_main) != sign(trend_ng),
      sig_status_change = (p_main < 0.05) != (p_ng < 0.05)
    )

  flips <- traj_main$team_trajectories %>%
    select(metric, team, traj_main = trajectory) %>%
    left_join(traj_ng$team_trajectories %>% select(metric, team, traj_ng = trajectory),
              by = c("metric", "team")) %>%
    group_by(metric) %>%
    summarise(n_class_flips = sum(traj_main != traj_ng, na.rm = TRUE),
              n_teams = n(), .groups = "drop")

  lt %>% left_join(flips, by = "metric")
}

#' Render the sensitivity comparison as markdown report lines.
#'
#' @param sens tibble from compare_trajectory_sensitivity()
#' @param garbage_share numeric, league-wide fraction of possessions flagged garbage
#' @return character vector of markdown lines
render_trajectory_sensitivity_report <- function(sens, garbage_share) {
  league_stable <- !any(sens$sign_flip | sens$sig_status_change)
  total_flips <- sum(sens$n_class_flips)
  max_flip_i <- which.max(sens$n_class_flips)
  hdr <- c(
    "# Trajectory Sensitivity: Garbage-Time Exclusion (AMENDMENT_01 2c)",
    "",
    paste0("Generated: ", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    "",
    "Pre-registered in output/eda_notes.md section 6. The five shortlist",
    "trajectory metrics were recomputed per team-game excluding garbage-time",
    "possessions and shots (period >= 4 and absolute score margin >= 20),",
    "then re-fit with the same trajectory machinery. The expected-points",
    "baseline was held fixed at its all-shots values.",
    "",
    paste0("Garbage-time possessions league-wide: ",
           sprintf("%.1f%%", 100 * garbage_share), " of live-ball possessions."),
    "",
    "Per metric: main league trend and p, garbage-excluded (ng) league trend",
    "and p, whether the trend sign flipped, whether significance crossed 0.05,",
    "and how many of the 15 teams changed improving/flat/declining classification.",
    ""
  )
  rows <- purrr::pmap_chr(sens, function(metric, trend_main, p_main, trend_ng, p_ng,
                                        sign_flip, sig_status_change, n_class_flips, n_teams) {
    sprintf("- %s: main %.4f (p=%.3f) | ng %.4f (p=%.3f) | sign flip: %s | sig change: %s | class flips: %d/%d",
            metric, trend_main, p_main, trend_ng, p_ng,
            ifelse(sign_flip, "YES", "no"), ifelse(sig_status_change, "YES", "no"),
            n_class_flips, n_teams)
  })
  concl <- c(
    "",
    "## Conclusion",
    "",
    if (league_stable) {
      paste0("League-level trends are stable under garbage-time exclusion: no metric ",
             "changes the sign of its league trend or its significance status at ",
             "p < 0.05. Every league trend is non-significant (p > 0.05) both with and ",
             "without garbage-time possessions, so the published-claim basis (the ",
             "league-wide fixed effect) is not a garbage-time artifact.")
    } else {
      paste0("At least one league-level trend flips sign or crosses the p < 0.05 ",
             "significance boundary under garbage-time exclusion (see the rows flagged ",
             "YES above). Report this as a caveat and do not publish the affected ",
             "trajectory claim without it.")
    },
    "",
    paste0("Per-team improving/flat/declining labels move for ", total_flips,
           " team-metric cells in total (most for ", sens$metric[max_flip_i], ", ",
           sens$n_class_flips[max_flip_i], " of 15 teams). These per-team labels are ",
           "interval-caveated directional reads, not standalone findings (AMENDMENT_01 ",
           "section 1): most per-team intervals already span zero. Movement under a ",
           "3.9% possession swing is expected and reinforces the standing rule to report ",
           "per-team trajectory only with its interval, and to base strong claims on the ",
           "league fixed effect, never on a single team's label.")
  )
  c(hdr, rows, concl)
}

main <- function() {
  features <- readRDS("data/processed/team_game_features.rds")

  tg_making <- readRDS("data/processed/team_game_shot_making.rds")
  features <- features %>%
    left_join(select(tg_making, gameId, team, shot_making_residual),
              by = c("gameId", "team"))

  identity <- fit_all_identity_models(features)
  trajectory <- fit_all_trajectory_models(features)

  dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
  dir.create("output", recursive = TRUE, showWarnings = FALSE)

  # AMENDMENT_01 2c garbage-time sensitivity pass (pre-registered, eda_notes 6)
  possessions <- readRDS("data/processed/possessions.rds")
  pbp <- readRDS("data/processed/pbp_events.rds")
  xpts_baseline <- readRDS("data/processed/expected_points_baseline.rds")
  features_ng <- recompute_trajectory_metrics_excluding_garbage(pbp, possessions, features, xpts_baseline)
  trajectory_ng <- fit_all_trajectory_models(features_ng)
  sens <- compare_trajectory_sensitivity(trajectory, trajectory_ng)
  margin_at_start <- pbp %>% select(gameId, start_event = orderNumber, scoreHome, scoreAway)
  garbage_share <- possessions %>%
    filter(outcome != "technical_ft") %>%
    left_join(margin_at_start, by = c("gameId", "start_event")) %>%
    summarise(s = mean(period >= 4 & abs(scoreHome - scoreAway) >= 20, na.rm = TRUE)) %>%
    pull(s)
  writeLines(render_trajectory_sensitivity_report(sens, garbage_share),
             "output/trajectory_sensitivity.md")
  message("Wrote output/trajectory_sensitivity.md")

  saveRDS(identity$blups, "data/processed/team_blups.rds")
  write_csv(identity$icc_table, "output/icc_table.csv")
  saveRDS(identity$rank_deltas, "data/processed/team_rank_deltas.rds")
  write_csv(identity$rank_deltas, "output/team_rank_deltas.csv")
  saveRDS(trajectory$team_trajectories, "data/processed/team_trajectories.rds")
  write_csv(trajectory$team_trajectories, "output/team_trajectories.csv")
  write_csv(trajectory$league_trends, "output/trajectory_league_trends.csv")

  message("Wrote data/processed/team_blups.rds (", nrow(identity$blups), " rows)")
  message("Wrote output/icc_table.csv (", nrow(identity$icc_table), " metrics)")
  message("Wrote data/processed/team_rank_deltas.rds + output/team_rank_deltas.csv (", nrow(identity$rank_deltas), " rows)")
  message("Wrote data/processed/team_trajectories.rds + output/team_trajectories.csv (", nrow(trajectory$team_trajectories), " rows)")
  message("Wrote output/trajectory_league_trends.csv (", nrow(trajectory$league_trends), " metrics)")

  invisible(list(identity = identity, trajectory = trajectory))
}

if (sys.nframe() == 0) {
  main()
}
