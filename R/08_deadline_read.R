# 08_deadline_read.R
#
# Purpose: Build the deadline-read synthesis table -- the core deliverable.
#   Per team, one row: adjusted identity summary, generation percentile,
#   making percentile, trajectory, cap_context, schedule note -> which lever
#   (acquire / adjust / hold, feasibility-conditioned). See HANDOFF §5e,
#   AMENDMENT_01 §1 (trajectory), AMENDMENT_02 §3b (cap_context + lever
#   conditioning).
#
#   Trajectory column (AMENDMENT_01 §1, new §5c-bis): improving / flat /
#   declining, assigned in 06_models.R from the trajectory slope sign and
#   interval, footnoted here when the interval spans zero. This column is
#   required, not optional -- if the team_trajectories input is unavailable,
#   fall back to raw trends with a stated caveat rather than dropping the
#   column (see PLAN.md cut order).
#
#   cap_context column (AMENDMENT_02 §3b): room / tight / capped, read
#   directly from data/reference/cap_context_2026.csv (hand-curated by
#   Wendy, not scripted -- see data/reference/README.md). This column is
#   never cut (PLAN.md cut order), same as trajectory.
#
#   Lever conditioning rule (AMENDMENT_02 §3b): the lever call is never
#   presented context-free. An "acquire" read paired with a "capped"
#   cap_context becomes "acquire (constrained: requires salary out)" -- or
#   downgrades to adjust/hold with the constraint stated in prose. The
#   framework must never recommend a move the cap forbids without naming the
#   constraint. See condition_lever_on_cap() below.
#
#   Window column and recommendation (standing/window layer, R/12_standing.R):
#   `window` (buyer/bubble/seller) is joined in from output/standing.csv, a
#   data-driven proxy for a team's competitive window built from game results
#   -- win-loss record AND scoring margin per game, equally weighted (one
#   more pass, accepted gm fix) -- never from anything modeled above.
#   Standing conditions the RECOMMENDATION column only -- the `lever` column
#   above stays the record-independent diagnosis, unchanged. See
#   reconcile_recommendation() below: this is the SAME shared recommendation
#   logic used in R/11_generation_gap.R's fit_read, keyed on window,
#   generation_tier, making_tier, and making_trajectory (the shot_making_
#   residual trajectory), so the two documents agree verb-for-verb: a seller
#   reads "sell / accumulate" regardless of diagnosis; a buyer with bottom-
#   tertile generation propped up by top-tertile but declining making reads
#   "reassess" (the paper-tiger case); a buyer with bottom-tertile generation
#   otherwise reads "gap-fill" (naming the acquire lever and its cap
#   constraint); a buyer with top-tertile generation reads "amplify"; a buyer
#   with mid-tertile generation reads "adjust"; a bubble team gets a
#   trajectory-resolved "judgment" call that names the World Cup break.
#
#   Run the `gm-agent` review (see .claude/agents/gm-agent.md) on this table
#   the moment it exists, before any prose is written around it -- it checks
#   both "is trajectory doing honest work" (a hold justified by an improving
#   trend is a real bet; flag any trajectory call where the uncertainty note
#   contradicts the confidence of the lever call) and, per AMENDMENT_02 §4,
#   that every acquire read is conditioned on cap context and that no cap or
#   CBA mechanic is stated without attribution.
#
# Inputs:  data/processed/team_blups.rds,
#          data/processed/team_generation_making.rds,
#          data/processed/team_trajectories.rds (from 06_models.R:
#            extract_trajectory_slopes() + classify_trajectory()),
#          data/reference/cap_context_2026.csv (hand-curated, tracked in
#            git, NOT gitignored -- see data/reference/README.md),
#          output/standing.csv (from R/12_standing.R -- run 12 before 08)
# Outputs: output/deadline_read.csv, output/deadline_read.md

library(tidyverse)

ICC_ANCHOR_FLOOR <- 0.15  # eda_notes.md spec change 6: only anchor identity on metrics with mixed-model ICC >= 0.15

#' Classify a team's deadline lever from its generation/making tiers.
#'
#' HANDOFF §5e talent/process/luck framing: generation (shot_generation_per100,
#' expected points per 100 given shot diet from the stratified expected-points
#' baseline) is the process axis -- did the team's shot selection create good
#' looks. Making (shot_making_per100, actual minus expected) is the
#' finishing/luck axis -- did the team convert the looks it created. The lever
#' call is a generation/making-driven position; identity_summary is accepted
#' for signature parity with the surrounding table build but is descriptive
#' only and does NOT enter the decision (trajectory likewise stays out of this
#' function -- see build_deadline_read()).
#'
#' Mapping (tiers are ntile(x, 3): 1 = low, 2 = mid, 3 = high):
#'   generation_tier == 1 (low)  -> "acquire": poor looks created, a
#'     shot-creation need.
#'   generation_tier == 3 (high) -> "hold": process creates good looks, keep it.
#'   generation_tier == 2 (mid):
#'     making_tier == 1 (low)    -> "hold": looks are competitive, finishing
#'       is below expectation -- a luck problem, expect regression.
#'     else (making_tier 2 or 3) -> "adjust": competitive process, finishing
#'       is not the issue -- marginal scheme gains.
#'
#' @param generation_tier integer, ntile(shot_generation_per100, 3), 1=low..3=high
#' @param making_tier integer, ntile(shot_making_per100, 3), 1=low..3=high
#' @param identity_summary character, descriptive only, not used in the decision
#' @return character, one of "acquire", "adjust", "hold"
classify_lever <- function(generation_tier, making_tier, identity_summary = NULL) {
  if (generation_tier == 1) {
    return("acquire")
  }
  if (generation_tier == 3) {
    return("hold")
  }
  # generation_tier == 2 (mid)
  if (making_tier == 1) {
    return("hold")
  }
  "adjust"
}

#' Describe a team's offense in the table's "Offense diagnosis" column.
#'
#' This is a DESCRIPTIVE phrase of the generation (process) axis, not an
#' action verb. The acquire/adjust/hold machinery (classify_lever) still runs
#' internally and feeds the cap conditioning and the Recommendation column, but
#' the displayed diagnosis column deliberately drops the action verbs so a
#' reader cannot mistake the diagnosis for the recommendation (accepted gm +
#' analytics-reviewer fix, 2026-07-26). The action lives in exactly one place:
#' the Recommendation column.
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

#' Format a team's trajectory value for the deadline-read table, with a
#' footnote marker when its interval spans zero (AMENDMENT_01 §1)
#'
#' Vectorized: works on a column of trajectory/interval_spans_zero pairs, not
#' just a single value. The "*" marks that the per-team trajectory interval
#' spans zero, so the label is directional, not a standalone claim
#' (AMENDMENT_01 §1).
#'
#' @param trajectory character vector, one of "improving"/"flat"/"declining"
#' @param interval_spans_zero logical vector
#' @return character vector, e.g. "improving" or "improving*"
format_trajectory_column <- function(trajectory, interval_spans_zero) {
  ifelse(interval_spans_zero, paste0(trajectory, "*"), trajectory)
}

#' Load the hand-curated cap-context reference table
#'
#' @param path character, defaults to data/reference/cap_context_2026.csv
#' @return tibble: team, committed_salary_est, cap_room_est, expiring_count,
#'   max_supermax_count, flexibility_tier (room/tight/capped), source, as_of_date
load_cap_context <- function(path = "data/reference/cap_context_2026.csv") {
  cap_context <- readr::read_csv(path, show_col_types = FALSE)

  bad_tiers <- setdiff(unique(cap_context$flexibility_tier), c("room", "tight", "capped"))
  if (length(bad_tiers) > 0) {
    stop(
      "load_cap_context(): flexibility_tier must be one of room/tight/capped, found: ",
      paste(bad_tiers, collapse = ", ")
    )
  }

  cap_context
}

#' Condition a raw generation/making-driven lever call on cap context
#' (AMENDMENT_02 §3b), grounded in data/reference/cba_rules_2026.md Section 2
#' (hard cap: a team needs Room or a qualifying Exception to take on salary,
#' by signing or by trade -- there is no going over the cap to absorb a
#' contract). Only "acquire" is gated here: "adjust" and "hold" do not
#' require taking on outside salary, so they pass through unchanged for any
#' flexibility_tier. This is the mechanism that keeps the framework from
#' recommending a move the hard cap forbids without naming the constraint.
#'
#' @param lever character, raw lever from classify_lever() ("acquire"/"adjust"/"hold")
#' @param flexibility_tier character, one of "room"/"tight"/"capped"
#' @return character, the feasibility-conditioned lever string, e.g.
#'   "acquire (constrained: requires salary out)"
condition_lever_on_cap <- function(lever, flexibility_tier) {
  if (lever != "acquire") {
    return(lever)
  }
  switch(
    flexibility_tier,
    room   = "acquire",
    tight  = "acquire (constrained: limited room, minimum/depth only)",
    capped = "acquire (constrained: requires salary out)",
    stop("condition_lever_on_cap(): unrecognized flexibility_tier: ", flexibility_tier)
  )
}

#' Load the standing/window table (R/12_standing.R)
#'
#' @param path character, defaults to output/standing.csv
#' @return tibble: team, wins, losses, win_pct, point_diff, rank,
#'   games_back_from_8th, window (buyer/bubble/seller)
load_standing <- function(path = "output/standing.csv") {
  standing <- readr::read_csv(path, show_col_types = FALSE)

  bad_windows <- setdiff(unique(standing$window), c("buyer", "bubble", "seller"))
  if (length(bad_windows) > 0) {
    stop(
      "load_standing(): window must be one of buyer/bubble/seller, found: ",
      paste(bad_windows, collapse = ", ")
    )
  }

  standing
}

#' Reconcile the diagnostic lever with the standing-derived window into the
#' table's bottom-line recommendation (standing/window layer, PART 2; one
#' more pass, accepted gm fix: shared recommendation vocabulary with
#' R/11_generation_gap.R's fit_read -- see that script's buyer_branch_text()/
#' assign_fit_read(), which implements the identical logic keyed on window,
#' generation tier, making tier, and making trajectory).
#'
#' `lever` is the cap-conditioned diagnosis from condition_lever_on_cap()
#' (e.g. "acquire", "acquire (constrained: requires salary out)", "adjust",
#' "hold") -- record-independent, computed above and left untouched by this
#' function; only its text is carried into the buyer/gap-fill branch below so
#' the cap constraint stays attached to any acquire recommendation.
#' `generation_tier`/`making_tier` are the record-independent ntile(x, 3)
#' tiers (1 = low, 2 = mid, 3 = high) computed above; `making_trajectory` is
#' the raw shot_making_residual trajectory label (improving/flat/declining/
#' NA), read from `trajectory` before the "*" display formatting. `window` is
#' the record-derived proxy for a team's competitive standing
#' (R/12_standing.R). This function is the only place standing enters the
#' table: it conditions the RECOMMENDATION, never the diagnosis.
#'
#' @param lever character, the cap-conditioned lever string
#' @param generation_tier integer, ntile(shot_generation_per100, 3), 1=low..3=high
#' @param making_tier integer, ntile(shot_making_per100, 3), 1=low..3=high
#' @param making_trajectory character or NA, shot_making_residual trajectory label
#' @param making_interval_spans_zero logical, TRUE when the shot_making_residual
#'   trajectory interval spans zero (AMENDMENT_01 Section 1). When TRUE and the
#'   recommendation leans on the trajectory direction (the reassess and bubble
#'   branches), a "(trajectory directional)" caveat is appended so the
#'   recommendation carries the same directional-not-standalone caveat the "*"
#'   marker gives the trajectory column.
#' @param window character, one of "buyer"/"bubble"/"seller"
#' @return character, the reconciled recommendation
reconcile_recommendation <- function(lever, generation_tier, making_tier, making_trajectory, making_interval_spans_zero, window) {
  # A trajectory-direction-driven recommendation carries the same caveat the
  # "*" marker gives the trajectory column: the per-team interval spans zero,
  # so the direction is a lean, not a standalone claim (AMENDMENT_01 Section 1).
  traj_caveat <- if (isTRUE(making_interval_spans_zero)) " (trajectory directional)" else ""

  if (window == "seller") {
    return(paste(
      "sell / accumulate: out of the race -- deal expirings and prioritize",
      "asset value over a deadline buy"
    ))
  }

  if (window == "buyer") {
    if (generation_tier == 1) {
      # bottom-tertile generation
      if (making_tier == 3 && identical(making_trajectory, "declining")) {
        return(paste0(paste(
          "reassess: bottom-tier shot generation propped up by top-tier",
          "but declining making -- address the shot diet / identity before",
          "spending an asset on a new piece"
        ), traj_caveat))
      }
      return(paste0("gap-fill: ", lever))
    }
    if (generation_tier == 3) {
      # top-tertile generation
      return(paste(
        "amplify: extend the edge -- add on-style depth, protect the shot",
        "hierarchy"
      ))
    }
    # generation_tier == 2, mid-tertile generation
    return(paste(
      "adjust: offense is roughly league-average -- tune, not a splash;",
      "offense is not the primary lever"
    ))
  }

  # window == "bubble"
  # A directional lean (lean buy / lean hold or sell) is only asserted when the
  # per-team making trajectory interval does NOT span zero. When it spans zero
  # the direction is indistinguishable from flat, so the recommendation defaults
  # to "hold" rather than reading a buy or sell into a zero-spanning slope
  # (accepted gm fix, 2026-07-26: no bubble buy/sell on a directionless trend).
  verb <- case_when(
    isTRUE(making_interval_spans_zero) ~ "hold",
    identical(making_trajectory, "improving") ~ "lean buy",
    identical(making_trajectory, "declining") ~ "lean hold or sell",
    TRUE ~ "hold"
  )
  paste0(
    "judgment (", verb, "): the late-August World Cup break favors",
    " hold-and-reassess unless the trajectory is clearly improving",
    traj_caveat
  )
}

#' Build a short readable identity-descriptor phrase per team from the
#' schedule-adjusted BLUPs (descriptive only -- not used by classify_lever()).
#'
#' For each team, z-score adjusted_value WITHIN each metric across the 15
#' teams, take the 2 metrics with the largest absolute z for that team, and
#' compose a phrase like "high 3PA rate, low rim rate" ("high" for z > 0,
#' "low" for z < 0), ordered most-extreme-first by descending |z|. Metric
#' names are mapped to readable labels via METRIC_LABELS, falling back to the
#' raw metric name if a metric is not in the map.
#'
#' ICC anchor filter (eda_notes.md spec change 6): before z-scoring, team_blups
#' is restricted to metrics whose output/icc_table.csv ICC is >= ICC_ANCHOR_FLOOR,
#' so the identity claim never anchors on a noise metric (e.g. assisted_rate).
#'
#' @param team_blups tibble, cols metric, team, adjusted_value
#' @param icc_path character, defaults to output/icc_table.csv (cols metric, icc)
#' @return tibble, cols team, identity_summary
build_identity_summary <- function(team_blups, icc_path = "output/icc_table.csv") {
  icc_table <- readr::read_csv(icc_path, show_col_types = FALSE)
  eligible_metrics <- icc_table %>%
    filter(icc >= ICC_ANCHOR_FLOOR) %>%
    pull(metric)

  team_blups <- team_blups %>%
    filter(metric %in% eligible_metrics)

  METRIC_LABELS <- c(
    pace_per40 = "pace",
    fg3a_rate = "3PA rate",
    assisted_rate = "assisted rate",
    transition_share = "transition rate",
    transition_pts_per_poss = "transition efficiency",
    off_tov_share = "points off turnovers",
    secondchance_share = "second-chance rate",
    paint_fgm_share = "paint scoring",
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

#' Build the full deadline-read table, one row per team
#'
#' Trajectory column: only the shot_making_residual metric rows from
#' team_trajectories are used for the headline trajectory column. This is a
#' deliberate choice, not an oversight -- shot_making_residual is the temporal
#' dimension of the making axis (the finishing/luck axis this table's lever
#' call is partly built on), so it is the trajectory most directly relevant
#' to the deadline read. The other four shortlist metrics (transition_share,
#' transition_pts_per_poss, assisted_rate, live_ball_tov_rate) have their own
#' trajectories and live in output/team_trajectories.csv, not here.
#'
#' Defensive fallback (PLAN.md cut order: trajectory is never dropped): if
#' team_trajectories has zero shot_making_residual rows, trajectory is set to
#' NA_character_ and trajectory_display to "n/a (trajectory input
#' unavailable)" for every team, with a warning emitted, rather than dropping
#' the column.
#'
#' @param team_blups tibble
#' @param team_generation_making tibble
#' @param team_trajectories tibble, from 06_models.R (team, trajectory,
#'   interval_spans_zero, per TRAJECTORY_METRICS metric)
#' @param cap_context tibble, from load_cap_context()
#' @param standing tibble, from load_standing() (team, window, ...
#'   R/12_standing.R) -- conditions recommendation only, never the diagnosis
#' @return tibble, one row per team: team, identity_summary,
#'   generation_rank, making_rank, generation_tier, making_tier,
#'   trajectory, interval_spans_zero, trajectory_display, cap_context,
#'   below_floor, lever_raw, lever, window, recommendation -- sorted by lever
#'   (acquire, adjust, hold) then team
build_deadline_read <- function(team_blups, team_generation_making, team_trajectories, cap_context, standing) {
  # Team-level rank is the published unit, not a percentile: with 15 teams a
  # percentile ("7th percentile") reads as false precision, so generation and
  # making are shown as league rank of 15, 1 = best (highest generation / highest
  # making). The generation_tier / making_tier below (ntile(x, 3)) still drive the
  # diagnosis and recommendation and are unchanged; rank is display only, and the
  # two agree by construction (rank 1-5 = tier 3, 6-10 = tier 2, 11-15 = tier 1).
  base <- team_generation_making %>%
    mutate(
      generation_rank = rank(-shot_generation_per100, ties.method = "min"),
      making_rank = rank(-shot_making_per100, ties.method = "min"),
      generation_tier = ntile(shot_generation_per100, 3),
      making_tier = ntile(shot_making_per100, 3)
    ) %>%
    select(team, generation_rank, making_rank, generation_tier, making_tier)

  making_residual_traj <- team_trajectories %>%
    filter(metric == "shot_making_residual") %>%
    select(team, trajectory, interval_spans_zero)

  if (nrow(making_residual_traj) == 0) {
    warning(
      "build_deadline_read(): no shot_making_residual rows in team_trajectories -- ",
      "trajectory set to NA for all teams (trajectory column is never dropped, see PLAN.md cut order)."
    )
    traj <- base %>%
      transmute(
        team,
        trajectory = NA_character_,
        interval_spans_zero = NA,
        trajectory_display = "n/a (trajectory input unavailable)"
      )
  } else {
    traj <- making_residual_traj %>%
      mutate(trajectory_display = format_trajectory_column(trajectory, interval_spans_zero))
  }

  identity_summary <- build_identity_summary(team_blups)

  # Team-salary floor is 85% of the $7.0M cap = $5,950,000 (cba_rules_2026.md
  # Section 1). A team below the floor must reach it over the SEASON, which it can
  # satisfy by paying the shortfall out to its players (cba_rules_2026.md Section
  # 1) -- so being below the floor is a soft nudge toward adding salary, not a
  # deadline-forcing mandate. The flag is a tier-compatible boolean;
  # committed_salary_est is used only to derive it and is never published
  # (tiers-not-dollars, AMENDMENT_02 Section 3a). The clean flexibility_tier (not
  # the floor-annotated display string) drives the lever.
  team_salary_floor <- 5950000
  cap <- cap_context %>%
    mutate(
      below_floor = committed_salary_est < team_salary_floor,
      cap_context = if_else(below_floor,
                            paste0(flexibility_tier, " (below floor)"),
                            flexibility_tier)
    ) %>%
    select(team, flexibility_tier, cap_context, below_floor)

  window_tbl <- standing %>% select(team, window)

  deadline_read <- base %>%
    left_join(traj, by = "team") %>%
    left_join(identity_summary, by = "team") %>%
    left_join(cap, by = "team") %>%
    left_join(window_tbl, by = "team") %>%
    rowwise() %>%
    mutate(
      lever_raw = classify_lever(generation_tier, making_tier, identity_summary),
      lever = condition_lever_on_cap(lever_raw, flexibility_tier),
      diagnosis = classify_diagnosis(generation_tier),
      recommendation = reconcile_recommendation(lever, generation_tier, making_tier, trajectory, interval_spans_zero, window)
    ) %>%
    ungroup() %>%
    select(
      team, identity_summary, generation_rank, making_rank,
      generation_tier, making_tier, trajectory, interval_spans_zero,
      trajectory_display, cap_context, below_floor, lever_raw, lever,
      diagnosis, window, recommendation
    )

  lever_order <- c("acquire", "adjust", "hold")
  deadline_read %>%
    mutate(lever_sort = factor(lever_raw, levels = lever_order)) %>%
    arrange(lever_sort, team) %>%
    select(-lever_sort)
}

#' Render the deadline-read table to markdown lines
#'
#' @param deadline_read tibble, from build_deadline_read()
#' @return character vector, markdown lines
render_deadline_read_md <- function(deadline_read) {
  header <- c(
    "# WNBA 2026 Trade Deadline Read",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    paste(
      "The Recommendation column is the action, and it is the only action",
      "column: it is conditioned on the standing-derived window and the cap",
      "tier. The Offense diagnosis column is descriptive of the offense only",
      "(generation-short / balanced / generation-rich) and is not an",
      "instruction. Diagnosis is generation/making-driven per HANDOFF 5e:",
      "generation is the process axis (expected points per 100 given shot",
      "diet, from the stratified expected-points baseline), making is the",
      "finishing axis (actual minus expected). Trajectory shown is the",
      "finishing trend (finishing relative to shot quality, rising or",
      "falling)."
    ),
    ""
  )

  n_teams <- nrow(deadline_read)

  table_header <- c(
    "| Team | Recommendation | Window | Cap | Offense diagnosis | Gen rank | Making rank | Trajectory | Identity |",
    "|---|---|---|---|---|---|---|---|---|"
  )

  table_rows <- deadline_read %>%
    mutate(
      row = paste0(
        "| ", team,
        " | ", recommendation,
        " | ", window,
        " | ", cap_context,
        " | ", diagnosis,
        " | ", generation_rank,
        " | ", making_rank,
        " | ", trajectory_display,
        " | ", identity_summary, " |"
      )
    ) %>%
    pull(row)

  footnotes <- c(
    "",
    paste0(
      "Gen rank and Making rank are the team's league rank of ", n_teams,
      " (1 = best): Gen rank 1 is the most and best looks created (highest shot",
      " generation), Making rank 1 is the best finishing relative to shot quality",
      " (highest shot making). Rank is the published team-level unit, not a",
      " percentile, since a percentile across ", n_teams, " teams is false precision."
    ),
    "",
    paste(
      "* interval spans zero: the per-team trajectory label is directional,",
      "not a standalone claim (AMENDMENT_01 Section 1)."
    ),
    "",
    paste(
      "Schedule note: the August 2 deadline sits just before the World Cup",
      "Hiatus (August 31 to September 16, dates per AMENDMENT_02; the Hiatus",
      "and prioritization rule is cba_rules_2026.md Section 5). The break is a",
      "hold incentive; a hold this deadline buys a mid-schedule reset. Forward",
      "strength-of-schedule is not modeled (no forward schedule in the open",
      "play-by-play)."
    ),
    "",
    paste(
      "Cap context is a flexibility tier (room / tight / capped), not a",
      "dollar figure; source data/reference/cap_context_2026.csv (Spotrac,",
      "2026-07-19), grounded in cba_rules_2026.md Section 2. A \"(below floor)\"",
      "tag marks a team below the 85%-of-cap team-salary floor ($5.95M,",
      "cba_rules_2026.md Section 1). A below-floor team must reach the floor",
      "over the season, which it can satisfy by paying the shortfall out to its",
      "players -- a soft nudge toward adding salary, not a deadline-forcing",
      "mandate. Re-verify before publish (AMENDMENT_02 Section 4)."
    ),
    "",
    paste(
      "Trajectory note: the improving/flat/declining labels are directional",
      "reads of each team's within-season finishing trend, not standalone",
      "claims; the per-team intervals span zero (the \"*\" marker). The",
      "modeling detail (the full trend fit was singular, so a documented",
      "fallback was used) is in output/methodology.md. Source:",
      "output/trajectory_league_trends.csv."
    ),
    "",
    paste(
      "Window (buyer/bubble/seller) is from standing (output/standing.csv), a",
      "data-driven proxy for a team's competitive window that blends win-loss",
      "record and scoring margin per game (equally weighted z-scores, see",
      "R/12_standing.R), not win_pct alone; it conditions the recommendation,",
      "not the diagnosis. Diagnosis (identity/generation/making/trajectory)",
      "is record-independent by design. A front office overrides window with",
      "private information (ownership mandate, injuries, the World Cup",
      "break)."
    ),
    "",
    paste(
      "Recommendation vocabulary (amplify / adjust / gap-fill / reassess /",
      "sell / judgment) is shared with output/generation_gap.md's fit_read,",
      "derived from the same signals (window, generation tier, making tier,",
      "making trajectory), so the two documents agree verb-for-verb."
    )
  )

  c(header, table_header, table_rows, footnotes)
}

main <- function() {
  team_blups <- readRDS("data/processed/team_blups.rds")
  team_generation_making <- readRDS("data/processed/team_generation_making.rds")
  team_trajectories <- readRDS("data/processed/team_trajectories.rds")
  cap_context <- load_cap_context()
  standing <- load_standing()

  deadline_read <- build_deadline_read(
    team_blups, team_generation_making, team_trajectories, cap_context, standing
  )

  write_csv(deadline_read, "output/deadline_read.csv")
  writeLines(render_deadline_read_md(deadline_read), "output/deadline_read.md")

  message("Lever distribution (diagnosis, record-independent):")
  print(table(deadline_read$lever))
  message("Window distribution (standing-derived):")
  print(table(deadline_read$window))
  message("Recommendation (lever reconciled with window):")
  print(table(deadline_read$recommendation))

  invisible(deadline_read)
}

if (sys.nframe() == 0) {
  main()
}
