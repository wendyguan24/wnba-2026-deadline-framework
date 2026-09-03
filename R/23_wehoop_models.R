# 23_wehoop_models.R
#
# Purpose: Fit the schedule-adjusted identity models and trajectory models
#   on full-season wehoop features. The wehoop analogue of R/06_models.R --
#   same machinery (metric ~ (1|team) + (1|opponent) + is_home for identity,
#   metric ~ game_index + (1 + game_index|team) + (1|opponent) for
#   trajectory, with the same singular-fit fallback), run on the full-season
#   wehoop feature table instead of the deadline-cut open-PBP table. No
#   garbage-time sensitivity pass here (that was a deadline-specific
#   pre-registered check, output/eda_notes.md 6, tied to the open-PBP
#   pipeline) and no possession-count weighting (the wehoop feature builder,
#   script 19, does not carry a transition_poss-style denominator column).
#
# Inputs:  output/wehoop/team_game_features.rds (script 19)
#          output/wehoop/team_game_shot_making.rds (script 22)
# Outputs: output/wehoop/icc_table.csv
#          output/wehoop/team_blups.rds
#          output/wehoop/team_rank_deltas.csv
#          output/wehoop/team_trajectories.csv
#          output/wehoop/trajectory_league_trends.csv

library(tidyverse)
library(lme4)

OUT_DIR <- file.path("output", "wehoop")

# Full identity-layer metric candidate list. Checked against the columns
# actually present in team_game_features.rds at runtime (see
# resolve_available_metrics()) rather than assumed, since the wehoop feature
# builder may not populate every column every run.
IDENTITY_METRIC_CANDIDATES <- c(
  "pace_per40", "fg3a_rate", "assisted_rate", "ra_share", "paint_share",
  "mid_share", "corner3_share", "atb3_share", "driving_share",
  "pullup_share", "cutting_share", "putback_share", "ft_rate", "tov_rate",
  "secondchance_share", "transition_share", "live_ball_tov_rate"
)

# Trajectory models run on this shortlist only, same discipline as
# 06_models.R's TRAJECTORY_METRICS: shot_making_residual is joined on from
# team_game_shot_making.rds before fitting (see main()).
TRAJECTORY_METRIC_CANDIDATES <- c(
  "assisted_rate", "shot_making_residual", "transition_share",
  "live_ball_tov_rate"
)

#' Resolve a candidate metric list down to columns actually present in
#' features, warning (not erroring) on anything dropped -- the wehoop
#' feature builder's column set can vary run to run.
#'
#' @param features tibble, team-game feature table
#' @param candidates character vector, candidate metric names
#' @param label character, used in the warning message only
#' @return character vector, candidates that are present in features
resolve_available_metrics <- function(features, candidates, label) {
  present <- intersect(candidates, names(features))
  not_present <- setdiff(candidates, names(features))

  # A column that is present but entirely NA (e.g. assisted_rate or
  # transition_share when this data contract does not supply them) or that is
  # constant cannot be modeled -- lmer fails with "0 (non-NA) cases" or a
  # degenerate fit. Require a minimum of non-NA cases and non-zero variance.
  MIN_NONNA <- 20L
  usable <- present[vapply(present, function(m) {
    x <- features[[m]]
    sum(!is.na(x)) >= MIN_NONNA && stats::var(x, na.rm = TRUE) > 0
  }, logical(1))]
  dropped_empty <- setdiff(present, usable)

  skipped <- c(not_present, dropped_empty)
  if (length(skipped) > 0) {
    message(sprintf(
      "  NOTE: %s metrics not usable (missing, all-NA, or constant), skipping: %s",
      label, paste(skipped, collapse = ", ")
    ))
  }
  if (length(usable) == 0) {
    stop(sprintf("resolve_available_metrics(): no usable %s metrics available in features.", label))
  }
  usable
}

#' Fit a mixed-effects identity model for one style metric:
#' metric ~ (1|team) + (1|opponent) + is_home.
#'
#' @param features tibble, team-game feature table
#' @param metric_name character, column name of the style metric
#' @return an lme4 model object
fit_mixed_model <- function(features, metric_name) {
  form <- as.formula(paste(metric_name, "~ is_home + (1 | team) + (1 | opponent)"))
  lmer(form, data = features)
}

#' Extract team-level BLUPs (schedule-adjusted identity) from a fitted
#' model: fixed intercept + team random effect.
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

#' Compare raw (unadjusted) team rank to schedule-adjusted rank.
#'
#' @param features tibble, raw team-game feature table
#' @param blups tibble, adjusted BLUPs for this metric
#' @param metric_name character, column name of the style metric
#' @return tibble, one row per team, raw_value, raw_rank, adjusted_value, adjusted_rank, delta
rank_deltas <- function(features, blups, metric_name) {
  raw <- features %>%
    group_by(team) %>%
    summarise(raw_value = mean(.data[[metric_name]], na.rm = TRUE), .groups = "drop") %>%
    mutate(raw_rank = rank(-raw_value, ties.method = "min"))

  blups %>%
    mutate(adjusted_rank = rank(-adjusted_value, ties.method = "min")) %>%
    left_join(raw, by = "team") %>%
    mutate(delta = raw_rank - adjusted_rank) %>%
    select(team, raw_value, raw_rank, adjusted_value, adjusted_rank, delta)
}

#' Fit identity models for every available identity metric and assemble the
#' BLUP table, ICC table, and rank-delta table.
#'
#' @param features tibble, team-game feature table
#' @param identity_metrics character vector, metrics to fit (post resolve_available_metrics())
#' @return list(blups = tibble, icc_table = tibble, rank_deltas = tibble)
fit_all_identity_models <- function(features, identity_metrics) {
  results <- map(identity_metrics, function(m) {
    model <- fit_mixed_model(features, m)
    blups <- extract_blups(model)
    list(
      metric = m,
      blups = blups %>% mutate(metric = m),
      icc = compute_icc(model),
      deltas = rank_deltas(features, blups, m) %>% mutate(metric = m)
    )
  })
  names(results) <- identity_metrics

  list(
    blups = map_dfr(results, "blups") %>% select(metric, team, adjusted_value),
    icc_table = tibble(metric = map_chr(results, "metric"), icc = map_dbl(results, "icc")) %>%
      arrange(desc(icc)),
    rank_deltas = map_dfr(results, "deltas")
  )
}

# --- Trajectory layer --------------------------------------------------

#' Fit the trajectory model for one metric: metric ~ game_index +
#' (1 + game_index | team) + (1 | opponent). Falls back to fixed game_index
#' + random intercepts only if the random-slope model fails to converge or
#' is singular, same fallback discipline as 06_models.R: per-team trajectory
#' is then approximated from that fallback model's residuals (each team's
#' own OLS slope of residuals against game_index).
#'
#' @param features tibble, team-game feature table with a game_index column
#' @param metric_name character, one of the trajectory metrics
#' @return list(model = lme4 model object, fallback_used = logical,
#'   fallback_residual_slopes = tibble or NULL)
fit_trajectory_model <- function(features, metric_name) {
  full_form <- as.formula(paste(metric_name, "~ game_index + (1 + game_index | team) + (1 | opponent)"))

  conv_messages <- character(0)
  full_model <- withCallingHandlers(
    tryCatch(
      lmer(full_form, data = features, control = lmerControl(optimizer = "bobyqa")),
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
  fallback_model <- lmer(fallback_form, data = features)

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
#' intervals, and the league-wide fixed effect. Uses the fallback's
#' residual-slope table directly when fit_trajectory_model() fell back to
#' random-intercepts-only.
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
      mutate(
        slope = slope + league_trend,
        ci_low = ci_low + league_trend,
        ci_high = ci_high + league_trend
      ) %>%
      select(team, slope, ci_low, ci_high)
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
#' slope sign; flag interval_spans_zero rather than force a "flat" label.
#'
#' @param team_slopes tibble from extract_trajectory_slopes()$team_slopes
#' @return tibble, adds columns trajectory and interval_spans_zero
classify_trajectory <- function(team_slopes) {
  team_slopes %>%
    mutate(
      trajectory = case_when(slope > 0 ~ "improving", slope < 0 ~ "declining", TRUE ~ "flat"),
      interval_spans_zero = ci_low <= 0 & ci_high >= 0
    )
}

#' Fit trajectory models for every available trajectory metric and assemble
#' the combined per-team, per-metric trajectory table plus the league-trend
#' summary.
#'
#' @param features tibble, team-game feature table
#' @param trajectory_metrics character vector, metrics to fit (post resolve_available_metrics())
#' @return list(team_trajectories = tibble, league_trends = tibble)
fit_all_trajectory_models <- function(features, trajectory_metrics) {
  results <- map(trajectory_metrics, function(m) {
    fit <- fit_trajectory_model(features, m)
    slopes <- extract_trajectory_slopes(fit)
    classified <- classify_trajectory(slopes$team_slopes) %>% mutate(metric = m)
    list(metric = m, team_trajectories = classified, league_trend = slopes$league_trend,
         league_trend_p = slopes$league_trend_p, fallback_used = slopes$fallback_used)
  })
  names(results) <- trajectory_metrics

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

main <- function() {
  dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

  features_path <- file.path(OUT_DIR, "team_game_features.rds")
  making_path <- file.path(OUT_DIR, "team_game_shot_making.rds")

  if (!file.exists(features_path)) {
    stop(sprintf("team_game_features.rds not found at %s. Run script 19 first.", features_path))
  }
  if (!file.exists(making_path)) {
    stop(sprintf("team_game_shot_making.rds not found at %s. Run script 22 first.", making_path))
  }

  features <- readRDS(features_path)
  tg_making <- readRDS(making_path)

  features <- features %>%
    left_join(select(tg_making, game_id, team, shot_making_residual), by = c("game_id", "team"))

  identity_metrics <- resolve_available_metrics(features, IDENTITY_METRIC_CANDIDATES, "identity")
  trajectory_metrics <- resolve_available_metrics(features, TRAJECTORY_METRIC_CANDIDATES, "trajectory")

  message("=== Fitting identity models (", length(identity_metrics), " metrics) ===")
  identity <- fit_all_identity_models(features, identity_metrics)

  message("=== Fitting trajectory models (", length(trajectory_metrics), " metrics) ===")
  trajectory <- fit_all_trajectory_models(features, trajectory_metrics)

  saveRDS(identity$blups, file.path(OUT_DIR, "team_blups.rds"))
  write_csv(identity$icc_table, file.path(OUT_DIR, "icc_table.csv"))
  write_csv(identity$rank_deltas, file.path(OUT_DIR, "team_rank_deltas.csv"))
  write_csv(trajectory$team_trajectories, file.path(OUT_DIR, "team_trajectories.csv"))
  write_csv(trajectory$league_trends, file.path(OUT_DIR, "trajectory_league_trends.csv"))

  message("Wrote ", file.path(OUT_DIR, "team_blups.rds"), " (", nrow(identity$blups), " rows)")
  message("Wrote ", file.path(OUT_DIR, "icc_table.csv"), " (", nrow(identity$icc_table), " metrics)")
  message("Wrote ", file.path(OUT_DIR, "team_rank_deltas.csv"), " (", nrow(identity$rank_deltas), " rows)")
  message("Wrote ", file.path(OUT_DIR, "team_trajectories.csv"), " (", nrow(trajectory$team_trajectories), " rows)")
  message("Wrote ", file.path(OUT_DIR, "trajectory_league_trends.csv"), " (", nrow(trajectory$league_trends), " metrics)")

  invisible(list(identity = identity, trajectory = trajectory))
}

if (sys.nframe() == 0) {
  main()
}
