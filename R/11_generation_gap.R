# 11_generation_gap.R
#
# Purpose: In-scope first part of the fit analysis -- decomposes each team's
#   offensive shot-diet generation gap versus the league into a VOLUME
#   component and a MIX component, then attributes the mix component by ZONE,
#   labels each mix-gap zone, flags identity-driven zones (a stable part of
#   who the team is, not a hole to fill), and assigns a window-conditioned fit
#   read (`fit_read`) driven by which component (volume or mix) dominates the
#   gap AND by the team's standing-derived window (buyer/bubble/seller, see
#   R/12_standing.R). This is a generation-gap attribution refinement of
#   HANDOFF question 1 (what do we need), computed entirely from the
#   shot-diet side.
#
#   Standing/window layer: `window` and `making_pctile` are added to the
#   per-team output, and the recommendation label (`fit_read`, replacing the
#   old `fit_mode`) is window-conditioned -- a seller's offense diagnosis is
#   context, not a buy signal; a buyer's diagnosis drives an actual gap-fill/
#   amplify/reassess call; a bubble team gets a judgment call. The diagnostic
#   decomposition itself (volume_gap, mix_gap_total, total_gap, primary_driver,
#   the per-zone mix rows, identity_driven) stays record-independent --
#   standing conditions the RECOMMENDATION only, never the diagnosis, same
#   design as R/08_deadline_read.R.
#
#   One more pass (accepted gm fix): fit_read is now built from the SAME
#   shared recommendation logic as R/08_deadline_read.R's `recommendation`
#   column, keyed on window, generation tertile (generation_pctile <= 33 low,
#   >= 67 high, else mid -- matching R/08's ntile tiers), making tertile
#   (making_pctile, same thresholds), and making_trajectory (the raw
#   shot_making_residual trajectory label, read from
#   data/processed/team_trajectories.rds, same source R/08 uses). This is
#   what makes the deadline-read recommendation and this script's fit_read
#   agree verb-for-verb instead of contradicting each other: LVA reads
#   "reassess" in both (a buyer winning on unsustainable, declining making),
#   DAL/GSV/MIN read "amplify" in both, and bubble teams resolve on
#   trajectory plus the World Cup break in both. See buyer_branch_text() and
#   assign_fit_read() below.
#
#   OUT OF SCOPE (post-deadline, see PLAN.md cut list): wins-over-replacement,
#   win-shares/RAPM, any player-value or dollar computation, candidate
#   matching. This script never touches those.
#
#   Method (price-volume variance split): generation = VOLUME x MIX_QUALITY,
#   where VOLUME = FGA per 100 possessions and MIX_QUALITY = expected points
#   per shot given a team's shot diet (league points-per-shot by zone, held
#   fixed for both team and league so only the diet varies). For each team:
#
#     gen_team - gen_league = (V_team - V_league) * M_league        [volume_gap]
#                           + V_team * (M_team - M_league)           [mix_gap_total]
#
#   volume_gap isolates how many shots a team gets relative to the league,
#   at league-average shot value; mix_gap_total isolates the value of the
#   shots a team chooses to take, at the team's own volume. The two sum
#   exactly to the team's zone-approximated generation gap (V_team*M_team -
#   V_league*M_league), which reconciles with shot_generation_per100 standing
#   -- asserted in code below.
#
#   mix_gap_total is then attributed by zone using a CENTERED league pps:
#   mix_contribution(z) = V_team * (team_share(z) - league_share(z)) *
#   (league_pps(z) - mean_pps). Centering by mean_pps is what makes each
#   zone's sign interpretable (see decompose_mix_by_zone() below) while
#   leaving sum_z mix_contribution(z) = mix_gap_total unchanged, because both
#   team and league shares sum to 1 across zones -- asserted in code below.
#
#   Identity-driven flag (unchanged from the mix-only version): a mix-gap
#   zone is identity_driven when its mapped share metric is ICC-eligible
#   (icc >= 0.15 in output/icc_table.csv) AND the team's z-score on that
#   metric (within-metric z across the 15 teams, from the identity BLUPs)
#   has |z| >= 1.0 -- i.e. the over/under-weighting is a stable, distinctive
#   trait, a choice to protect rather than a gap to fill. This flag depends
#   only on team_share vs. league_share, not on volume, so it is unaffected
#   by the volume/mix split.
#
#   primary_driver: "volume" if |volume_gap| >= |mix_gap_total|, "mix" if
#   |mix_gap_total| > |volume_gap|, OR "both" when BOTH abs(volume_gap) and
#   abs(mix_gap_total) exceed 0.75 per 100 possessions (accepted gm fix: a
#   team whose volume AND mix gaps are each individually large should not be
#   filed under a single driver label). fit_read (replacing the former
#   fit_mode) is window-conditioned and shares wording with R/08's
#   `recommendation` column (one more pass, accepted gm fix) -- see
#   assign_fit_read() / buyer_branch_text() below: seller -> sell/accumulate
#   regardless of generation tier; buyer with bottom-tertile generation and
#   top-tertile-but-declining making -> reassess (the paper-tiger case);
#   buyer with bottom-tertile generation otherwise -> gap-fill (named
#   non-identity zone, or "possession creation" if primary_driver is
#   "volume" or "both"); buyer with top-tertile generation -> amplify; buyer
#   mid-tertile -> adjust; bubble -> a trajectory-resolved judgment call
#   naming the contested window and the World Cup break (not the buyer-branch
#   text -- bubble no longer names a zone, see assign_fit_read()).
#
# Inputs:  data/processed/pbp_events.rds (shot events: actionType, shotResult,
#            area, teamTricode, gameId),
#          data/processed/team_generation_making.rds (team, fga, poss_count,
#            shot_generation_per100, shot_making_per100 -- the official
#            generation/making percentile source and the volume-component
#            basis, kept consistent with the rest of the framework),
#          data/processed/team_blups.rds (metric, team, adjusted_value --
#            identity BLUPs for the identity-driven z-score check),
#          output/icc_table.csv (metric, icc -- the ICC >= 0.15
#            identity-eligibility floor),
#          output/standing.csv (team, window -- from R/12_standing.R, run 12
#            before 11; window conditions fit_read only, never the diagnosis),
#          data/processed/team_trajectories.rds (metric, team, trajectory --
#            filtered to metric == "shot_making_residual" for
#            making_trajectory, same source and same metric R/08 uses)
# Outputs: output/generation_gap.csv, output/generation_gap.md

library(tidyverse)

ICC_ANCHOR_FLOOR <- 0.15  # same anchor rule as 08_deadline_read.R: only flag identity on metrics with ICC >= 0.15
IDENTITY_Z_FLOOR <- 1.0
ASSERT_TOL <- 1e-6

ZONES <- c(
  "Restricted Area",
  "In The Paint (Non-RA)",
  "Mid-Range",
  "Corner 3",
  "Above the Break 3"
)

# Zone -> identity share metric in data/processed/team_blups.rds
ZONE_METRIC_MAP <- c(
  "Restricted Area" = "ra_share",
  "In The Paint (Non-RA)" = "paint_share",
  "Mid-Range" = "mid_share",
  "Corner 3" = "corner3_share",
  "Above the Break 3" = "atb3_share"
)

#' Build shot-level rows (one row per made-or-missed FG attempt) with points
#' scored and collapsed zone, from the raw pbp events table.
#'
#' @param pbp_events tibble, data/processed/pbp_events.rds
#' @return tibble, cols team (teamTricode), zone, points_scored
build_shot_rows <- function(pbp_events) {
  pbp_events %>%
    filter(actionType %in% c("2pt", "3pt")) %>%
    mutate(
      points_scored = case_when(
        shotResult != "Made" ~ 0,
        actionType == "3pt" ~ 3,
        TRUE ~ 2
      ),
      zone = case_when(
        area %in% c("Left Corner 3", "Right Corner 3") ~ "Corner 3",
        TRUE ~ area
      )
    ) %>%
    filter(zone %in% ZONES) %>%
    transmute(team = teamTricode, zone, points_scored)
}

#' Build the league zone table (shares and points-per-shot) and the overall
#' league mean points-per-shot, from shot-level rows.
#'
#' @param shot_rows tibble, from build_shot_rows()
#' @return list(mean_pps = numeric, league_zone = tibble(zone, league_fga,
#'   league_pps, league_share))
build_league_zone_table <- function(shot_rows) {
  mean_pps <- mean(shot_rows$points_scored)

  league_zone <- shot_rows %>%
    group_by(zone) %>%
    summarise(
      league_fga = n(),
      league_pps = mean(points_scored),
      .groups = "drop"
    ) %>%
    mutate(league_share = league_fga / sum(league_fga))

  list(mean_pps = mean_pps, league_zone = league_zone)
}

#' Build each team's zone shot shares (team_share(z) = team zone FGA / team
#' total FGA, from shot-level rows), with all 5 zones represented (0 share if
#' a team never shot from a given zone).
#'
#' @param shot_rows tibble, from build_shot_rows()
#' @return tibble, team, zone, team_share
build_team_zone_shares <- function(shot_rows) {
  team_zone <- shot_rows %>%
    group_by(team, zone) %>%
    summarise(team_fga = n(), .groups = "drop") %>%
    group_by(team) %>%
    mutate(team_share = team_fga / sum(team_fga)) %>%
    ungroup()

  expand_grid(
    team = unique(shot_rows$team),
    zone = ZONES
  ) %>%
    left_join(team_zone %>% select(team, zone, team_share), by = c("team", "zone")) %>%
    mutate(team_share = replace_na(team_share, 0))
}

#' Decompose each team's generation gap versus the league into a VOLUME
#' component and a MIX component (see file header for the full derivation).
#'
#' V_team = fga / poss_count * 100 (team_generation_making, per team)
#' V_league = (total league FGA, i.e. nrow(shot_rows)) / (total league
#'   possessions, sum of poss_count across the 15 teams) * 100
#' M_league = sum_z league_share(z) * league_pps(z) (equals mean_pps)
#' M_team = sum_z team_share(z) * league_pps(z)
#' volume_gap = (V_team - V_league) * M_league
#' mix_gap_total = V_team * (M_team - M_league)
#' total_gap = volume_gap + mix_gap_total, asserted equal to
#'   V_team*M_team - V_league*M_league within ASSERT_TOL
#'
#' @param shot_rows tibble, from build_shot_rows()
#' @param team_generation_making tibble, data/processed/team_generation_making.rds
#' @return tibble, one row per team: team, V_team, M_team, V_league, M_league,
#'   mean_pps, volume_gap, mix_gap_total, total_gap, primary_driver
decompose_team_generation_gap <- function(shot_rows, team_generation_making) {
  league_parts <- build_league_zone_table(shot_rows)
  mean_pps <- league_parts$mean_pps
  league_zone <- league_parts$league_zone
  M_league <- mean_pps  # sum_z league_share(z) * league_pps(z) == mean_pps by construction

  team_zone_shares <- build_team_zone_shares(shot_rows)

  total_league_fga <- nrow(shot_rows)
  total_league_poss <- sum(team_generation_making$poss_count)
  V_league <- total_league_fga / total_league_poss * 100

  M_team_table <- team_zone_shares %>%
    left_join(league_zone %>% select(zone, league_pps), by = "zone") %>%
    group_by(team) %>%
    summarise(M_team = sum(team_share * league_pps), .groups = "drop")

  team_level <- team_generation_making %>%
    transmute(team, V_team = fga / poss_count * 100) %>%
    left_join(M_team_table, by = "team") %>%
    mutate(
      V_league = V_league,
      M_league = M_league,
      mean_pps = mean_pps,
      volume_gap = (V_team - V_league) * M_league,
      mix_gap_total = V_team * (M_team - M_league),
      total_gap = volume_gap + mix_gap_total
    )

  # Assert: total_gap reconciles algebraically with the zone-approximated
  # team generation minus league generation (V_team*M_team - V_league*M_league).
  recon_check <- with(team_level, total_gap - (V_team * M_team - V_league * M_league))
  stopifnot(all(abs(recon_check) < ASSERT_TOL))

  team_level %>%
    mutate(
      # Accepted gm fix: when both components individually exceed 0.75 per
      # 100 possessions, neither is the sole story -- label "both" instead of
      # picking the larger-magnitude one. Else fall back to the original
      # larger-magnitude rule.
      primary_driver = case_when(
        abs(volume_gap) > 0.75 & abs(mix_gap_total) > 0.75 ~ "both",
        abs(volume_gap) >= abs(mix_gap_total) ~ "volume",
        TRUE ~ "mix"
      )
    ) %>%
    select(team, V_team, M_team, V_league, M_league, mean_pps,
           volume_gap, mix_gap_total, total_gap, primary_driver)
}

#' Attribute each team's mix_gap_total by zone, using the centered league pps
#' contribution, and label each zone (see file header for the sign logic).
#'
#' mix_contribution(z) = V_team * (team_share(z) - league_share(z)) *
#'   (league_pps(z) - mean_pps)
#' sum_z mix_contribution(z) is asserted equal to mix_gap_total (from
#' decompose_team_generation_gap()) within ASSERT_TOL, per team.
#'
#' @param shot_rows tibble, from build_shot_rows()
#' @param team_level tibble, from decompose_team_generation_gap()
#' @return tibble, one row per team-zone: team, zone, team_share,
#'   league_share, league_pps, mix_contribution, type
decompose_mix_by_zone <- function(shot_rows, team_level) {
  league_parts <- build_league_zone_table(shot_rows)
  mean_pps <- league_parts$mean_pps
  league_zone <- league_parts$league_zone
  team_zone_shares <- build_team_zone_shares(shot_rows)

  zone_table <- team_zone_shares %>%
    left_join(league_zone %>% select(zone, league_share, league_pps), by = "zone") %>%
    left_join(team_level %>% select(team, V_team), by = "team") %>%
    mutate(
      mean_pps = mean_pps,
      mix_contribution = V_team * (team_share - league_share) * (league_pps - mean_pps),
      type = case_when(
        mix_contribution >= 0 ~ "",
        team_share < league_share & league_pps > mean_pps ~ "missing efficient looks",
        # Accepted gm fix (ATB3 relabel): a zone whose league_pps sits within
        # 0.05 of the overall league mean_pps is a league-average look, not an
        # inefficient one (this is Above the Break 3 specifically, ~0.996 vs
        # mean ~1.02 -- see the footnote in render_generation_gap_md()).
        # Over-weighting it is "slightly below-mean volume", not "over-reliant
        # on low-value looks".
        team_share > league_share & league_pps < mean_pps & abs(league_pps - mean_pps) < 0.05 ~ "slightly below-mean volume",
        team_share > league_share & league_pps < mean_pps ~ "over-reliant on low-value looks",
        TRUE ~ "missing efficient looks"  # defensive fallback, should not trigger given the cases above are exhaustive for mix_contribution < 0
      )
    ) %>%
    select(team, zone, team_share, league_share, league_pps, mix_contribution, type)

  # Assert: per-team sum of zone mix_contribution equals mix_gap_total.
  recon_check <- zone_table %>%
    group_by(team) %>%
    summarise(sum_mix = sum(mix_contribution), .groups = "drop") %>%
    left_join(team_level %>% select(team, mix_gap_total), by = "team") %>%
    mutate(delta = sum_mix - mix_gap_total)
  stopifnot(all(abs(recon_check$delta) < ASSERT_TOL))

  zone_table
}

#' Flag each team-zone gap as identity_driven per the ICC + z-score anchor
#' rule (see file header). Unchanged from the mix-only version: this flag
#' depends only on team_share vs. league_share (via the BLUP z-score), not on
#' volume, so it is unaffected by the volume/mix split.
#'
#' @param zone_table tibble, from decompose_mix_by_zone()
#' @param team_blups tibble, data/processed/team_blups.rds (metric, team, adjusted_value)
#' @param icc_table tibble, output/icc_table.csv (metric, icc)
#' @return tibble, zone_table with an added identity_driven logical column
flag_identity_driven <- function(zone_table, team_blups, icc_table) {
  eligible_metrics <- icc_table %>%
    filter(icc >= ICC_ANCHOR_FLOOR) %>%
    pull(metric)

  zone_metric <- tibble(
    zone = names(ZONE_METRIC_MAP),
    metric = unname(ZONE_METRIC_MAP)
  )

  z_scored <- team_blups %>%
    filter(metric %in% unname(ZONE_METRIC_MAP)) %>%
    group_by(metric) %>%
    mutate(z = as.numeric(scale(adjusted_value))) %>%
    ungroup() %>%
    select(team, metric, z)

  identity_flags <- zone_metric %>%
    left_join(z_scored, by = "metric") %>%
    mutate(
      metric_eligible = metric %in% eligible_metrics,
      identity_driven = metric_eligible & abs(z) >= IDENTITY_Z_FLOOR
    ) %>%
    select(team, zone, identity_driven)

  zone_table %>%
    left_join(identity_flags, by = c("team", "zone")) %>%
    mutate(identity_driven = replace_na(identity_driven, FALSE))
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

#' Load each team's shot_making_residual trajectory label (one more pass,
#' accepted gm fix: same source and same metric R/08_deadline_read.R uses
#' for its `trajectory` column, so both scripts key the paper-tiger/bubble
#' logic off the identical signal).
#'
#' Defensive fallback (mirrors R/08_deadline_read.R): if team_trajectories
#' has zero shot_making_residual rows, making_trajectory is NA for every
#' team (a warning is emitted), rather than the script failing -- fit_read's
#' case_when()/identical() checks treat NA as "not improving, not declining"
#' and fall through to the neutral branch (adjust's mid case is unaffected;
#' bubble falls to "hold"; the paper-tiger reassess check requires
#' identical(making_trajectory, "declining") and so is simply never
#' triggered).
#'
#' @param team_trajectories tibble, data/processed/team_trajectories.rds
#' @return tibble, team, making_trajectory, making_interval_spans_zero
load_making_trajectory <- function(team_trajectories) {
  making_residual_traj <- team_trajectories %>%
    filter(metric == "shot_making_residual") %>%
    select(team, making_trajectory = trajectory,
           making_interval_spans_zero = interval_spans_zero)

  if (nrow(making_residual_traj) == 0) {
    warning(
      "load_making_trajectory(): no shot_making_residual rows in ",
      "team_trajectories -- making_trajectory set to NA for all teams."
    )
    return(tibble(team = unique(team_trajectories$team),
                  making_trajectory = NA_character_,
                  making_interval_spans_zero = NA))
  }

  making_residual_traj
}

#' Find, per team, the most-negative NON-identity-driven mix-contribution
#' zone with mix_contribution < 0 -- a real, fixable shot-selection deficit,
#' as opposed to a stable identity trait to protect. Named unconditionally in
#' the md per-team block as a "secondary tune" line (accepted gm fix: fixable
#' non-identity deficits should surface even for amplify/volume-driven teams,
#' not only for primary_driver == "mix" teams as the prior version's "Top
#' mix-gap zones" section was restricted to).
#'
#' @param full_table tibble, team-zone rows with mix_contribution, identity_driven, type
#' @return tibble, one row per team in full_table: team, secondary_tune_zone,
#'   secondary_tune_contribution, secondary_tune_type (all NA if the team has
#'   no negative, non-identity-driven mix zone)
top_non_identity_negative_mix_zone <- function(full_table) {
  all_teams <- tibble(team = unique(full_table$team))

  candidates <- full_table %>%
    filter(mix_contribution < 0, !identity_driven) %>%
    group_by(team) %>%
    slice_min(mix_contribution, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(team,
           secondary_tune_zone = zone,
           secondary_tune_contribution = mix_contribution,
           secondary_tune_type = type)

  all_teams %>%
    left_join(candidates, by = "team")
}

#' Buyer-branch fit-read text: what a team with a real playoff window would
#' be told about its offense, from generation tertile, making tertile,
#' making trajectory, and primary_driver. Used only for window == "buyer"
#' (one more pass, accepted gm fix: window == "bubble" no longer wraps this
#' text -- see assign_fit_read() below, which uses a trajectory-resolved
#' judgment call instead, matching R/08_deadline_read.R's shared logic).
#'
#' generation_pctile <= 33 (bottom tertile):
#'   making_pctile >= 67 (top tertile) AND making_trajectory == "declining"
#'     -> "reassess: ..." (the paper-tiger case: bottom-tier generation
#'     propped up by top-tier but declining making)
#'   else, primary_driver %in% c("volume", "both") -> "gap-fill (acquire): possession creation"
#'   else -> "gap-fill (acquire): " + the named top non-identity mix zone
#' generation_pctile >= 67 (top tertile) -> "amplify: extend the edge --
#'   add on-style depth, protect the shot hierarchy"
#' else (middle tertile) -> "adjust: offense is roughly league-average --
#'   tune, not a splash; offense is not the primary lever"
#'
#' @param generation_pctile numeric, 0-100
#' @param making_pctile numeric, 0-100
#' @param making_trajectory character or NA, shot_making_residual trajectory label
#' @param making_interval_spans_zero logical, TRUE when the shot_making_residual
#'   trajectory interval spans zero -- appends a "(trajectory directional)"
#'   caveat to the reassess branch (the only buyer branch that leans on the
#'   trajectory direction), matching R/08_deadline_read.R's reconcile_recommendation()
#' @param primary_driver character, "volume"/"mix"/"both"
#' @param secondary_tune_zone character or NA, the named non-identity zone
#' @return character, the buyer-branch fit-read text
buyer_branch_text <- function(generation_pctile, making_pctile, making_trajectory,
                               making_interval_spans_zero, primary_driver, secondary_tune_zone) {
  traj_caveat <- if (isTRUE(making_interval_spans_zero)) " (trajectory directional)" else ""
  if (generation_pctile <= 33) {
    if (making_pctile >= 67 && identical(making_trajectory, "declining")) {
      return(paste0(paste(
        "reassess: bottom-tier shot generation propped up by top-tier but",
        "declining making -- address the shot diet / identity before",
        "spending an asset on a new piece"
      ), traj_caveat))
    }
    if (identical(primary_driver, "volume") || identical(primary_driver, "both")) {
      return("gap-fill (acquire): possession creation")
    }
    zone_name <- if (is.na(secondary_tune_zone)) "shot selection" else secondary_tune_zone
    return(paste0("gap-fill (acquire): ", zone_name))
  }
  if (generation_pctile >= 67) {
    return(paste(
      "amplify: extend the edge -- add on-style depth, protect the shot",
      "hierarchy"
    ))
  }
  paste(
    "adjust: offense is roughly league-average -- tune, not a splash;",
    "offense is not the primary lever"
  )
}

#' Bubble-window fit-read text: a trajectory-resolved judgment call naming
#' the World Cup break (one more pass, accepted gm fix -- shared with
#' R/08_deadline_read.R's bubble branch; no longer wraps buyer_branch_text()
#' / names a zone).
#'
#' @param making_trajectory character or NA, shot_making_residual trajectory label
#' @param making_interval_spans_zero logical, TRUE when the shot_making_residual
#'   trajectory interval spans zero -- appends a "(trajectory directional)"
#'   caveat, matching R/08_deadline_read.R's reconcile_recommendation() bubble branch
#' @return character, the bubble fit-read text
bubble_branch_text <- function(making_trajectory, making_interval_spans_zero) {
  traj_caveat <- if (isTRUE(making_interval_spans_zero)) " (trajectory directional)" else ""
  # A directional lean is only asserted when the interval does NOT span zero;
  # a zero-spanning trend is indistinguishable from flat and defaults to "hold"
  # (accepted gm fix, 2026-07-26, matching R/08_deadline_read.R's bubble branch).
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

#' Assign each team a window-conditioned fit_read (standing/window layer,
#' replaces the record-independent fit_mode; one more pass, accepted gm fix:
#' shares wording with R/08_deadline_read.R's `recommendation` column).
#' Window (buyer/bubble/seller, R/12_standing.R) conditions this
#' RECOMMENDATION only; the diagnostic decomposition (volume_gap,
#' mix_gap_total, primary_driver, identity_driven) feeding buyer_branch_text()
#' is untouched and stays record-independent.
#'
#'   window == "seller"  -> the same "sell / accumulate: ..." text as
#'     R/08_deadline_read.R, regardless of generation tier (offense
#'     diagnosis is context, not a buy)
#'   window == "buyer"   -> buyer_branch_text(...)
#'   window == "bubble"  -> bubble_branch_text(...) (trajectory-resolved,
#'     names the World Cup break -- no longer wraps buyer_branch_text() /
#'     names a zone, matching R/08_deadline_read.R's shared bubble logic)
#'
#' @param full_table tibble, team-zone rows (generation_pctile, making_pctile,
#'   primary_driver, mix_contribution, identity_driven, zone, type)
#' @param standing tibble, from load_standing() (team, window)
#' @param trajectories tibble, team, making_trajectory,
#'   making_interval_spans_zero (shot_making_residual trajectory label and its
#'   interval-spans-zero flag, from data/processed/team_trajectories.rds)
#' @return tibble, team, window, fit_read
assign_fit_read <- function(full_table, standing, trajectories) {
  team_level <- full_table %>%
    distinct(team, generation_pctile, making_pctile, primary_driver)

  secondary <- top_non_identity_negative_mix_zone(full_table)

  team_level %>%
    left_join(secondary, by = "team") %>%
    left_join(standing %>% select(team, window), by = "team") %>%
    left_join(trajectories, by = "team") %>%
    rowwise() %>%
    mutate(
      fit_read = case_when(
        window == "seller" ~ paste(
          "sell / accumulate: out of the race -- deal expirings and",
          "prioritize asset value over a deadline buy"
        ),
        window == "buyer"  ~ buyer_branch_text(
          generation_pctile, making_pctile, making_trajectory,
          making_interval_spans_zero, primary_driver, secondary_tune_zone
        ),
        window == "bubble" ~ bubble_branch_text(making_trajectory, making_interval_spans_zero),
        TRUE ~ NA_character_
      )
    ) %>%
    ungroup() %>%
    select(team, window, fit_read)
}

#' Build the full generation-gap table, one row per team-zone (5 zones per team)
#'
#' @param pbp_events tibble, data/processed/pbp_events.rds
#' @param team_generation_making tibble, data/processed/team_generation_making.rds
#' @param team_blups tibble, data/processed/team_blups.rds
#' @param icc_table tibble, output/icc_table.csv
#' @param standing tibble, from load_standing() (team, window --
#'   R/12_standing.R). Conditions fit_read only, never the diagnosis.
#' @param team_trajectories tibble, data/processed/team_trajectories.rds.
#'   Filtered to metric == "shot_making_residual" for making_trajectory
#'   (one more pass, accepted gm fix), which feeds fit_read's paper-tiger
#'   and bubble branches. Conditions fit_read only, never the diagnosis.
#' @return list(gap_table = tibble with window/fit_read joined in,
#'   fit_reads = tibble team/window/fit_read, secondary_tune = tibble of the
#'   per-team "secondary tune" non-identity negative mix zone)
build_generation_gap <- function(pbp_events, team_generation_making, team_blups, icc_table, standing, team_trajectories) {
  shot_rows <- build_shot_rows(pbp_events)

  team_level <- decompose_team_generation_gap(shot_rows, team_generation_making)

  zone_table <- decompose_mix_by_zone(shot_rows, team_level) %>%
    flag_identity_driven(team_blups, icc_table)

  # generation_pctile and making_pctile are computed HERE, in R/11, via
  # percent_rank of shot_generation_per100 / shot_making_per100 (both from
  # 07_expected_points.R). generation_pctile is the official per-100-
  # possessions generation standing, carried for the fit_read call;
  # total_gap (volume_gap + mix_gap_total) is this script's zone-approximated
  # version of the same quantity and is asserted to reconcile with it (see
  # decompose_team_generation_gap()). making_pctile is shown beside
  # generation_pctile in the md, and (one more pass, accepted gm fix) is now
  # also used directly in fit_read's paper-tiger check (making_pctile >= 67),
  # not only as descriptive context; the offense-only decomposition above it
  # is unaffected.
  pctile_table <- team_generation_making %>%
    mutate(
      generation_pctile = round(percent_rank(shot_generation_per100) * 100),
      making_pctile = round(percent_rank(shot_making_per100) * 100)
    ) %>%
    select(team, generation_pctile, making_pctile)

  full_table <- zone_table %>%
    left_join(team_level %>% select(team, volume_gap, mix_gap_total, total_gap, primary_driver),
               by = "team") %>%
    left_join(pctile_table, by = "team")

  making_trajectory <- load_making_trajectory(team_trajectories)
  fit_reads <- assign_fit_read(full_table, standing, making_trajectory)
  secondary_tune <- top_non_identity_negative_mix_zone(full_table)

  gap_table_out <- full_table %>%
    left_join(fit_reads, by = "team") %>%
    select(
      team, generation_pctile, making_pctile, window, volume_gap, mix_gap_total,
      total_gap, primary_driver, fit_read, zone, mix_contribution, type, identity_driven
    ) %>%
    arrange(team, zone)

  list(gap_table = gap_table_out, fit_reads = fit_reads, secondary_tune = secondary_tune)
}

#' Render the generation-gap markdown report
#'
#' @param gap_table tibble, from build_generation_gap()$gap_table
#' @param fit_modes tibble, from build_generation_gap()$fit_modes
#' @param fit_reads tibble, from build_generation_gap()$fit_reads (team,
#'   window, fit_read)
#' @return character vector, markdown lines
render_generation_gap_md <- function(gap_table, fit_reads) {
  header <- c(
    "# WNBA 2026 Offensive Generation Gap: Volume + Mix Decomposition",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    paste(
      "Each team's generation gap versus the league (generation = volume x",
      "mix quality: FGA per 100 possessions, times expected points per shot",
      "given shot diet) is split into a VOLUME gap ((team FGA/100 minus",
      "league FGA/100) times league mix quality) and a MIX gap (team FGA/100",
      "times the difference between the team's and the league's mix",
      "quality), the second attributed by zone with a centered-pps",
      "contribution. The two components sum to the team's total generation",
      "gap, which reconciles with the team's shot_generation_per100",
      "standing (generation and making percentile shown per team, computed",
      "in R/11 via percent_rank of shot_generation_per100 /",
      "shot_making_per100, both from 07_expected_points.R). primary_driver",
      "names which component (volume, mix, or both when each individually",
      "exceeds 0.75 per 100 possessions) accounts for the gap."
    ),
    "",
    paste(
      "fit_read is window-conditioned (standing/window layer,",
      "R/12_standing.R): window (buyer/bubble/seller, from each team's",
      "win-loss record AND scoring margin per game, equally weighted) sets",
      "the RECOMMENDATION here; the diagnostic decomposition above it",
      "(volume_gap, mix_gap_total, primary_driver, identity_driven) stays",
      "record-independent and unchanged by window."
    ),
    "",
    paste(
      "fit_read shares its recommendation vocabulary (amplify / adjust /",
      "gap-fill / reassess / sell / judgment) with output/deadline_read.md's",
      "`recommendation` column -- both are derived from the same signals",
      "(window, generation tier, making tier, making trajectory), so the two",
      "documents agree verb-for-verb rather than contradicting each other."
    ),
    ""
  )

  team_order <- fit_reads %>%
    arrange(team) %>%
    pull(team)

  team_blocks <- map(team_order, function(tm) {
    team_rows <- gap_table %>% filter(team == tm)
    gen_pctile <- unique(team_rows$generation_pctile)
    making_pctile <- unique(team_rows$making_pctile)
    window <- unique(team_rows$window)
    primary_driver <- unique(team_rows$primary_driver)
    volume_gap <- unique(team_rows$volume_gap)
    mix_gap_total <- unique(team_rows$mix_gap_total)
    total_gap <- unique(team_rows$total_gap)
    fit_read <- fit_reads %>% filter(team == tm) %>% pull(fit_read)

    gap_summary_lines <- c(
      paste0("- Generation percentile: ", gen_pctile, " (making percentile: ", making_pctile, ")"),
      paste0("- Window: ", window),
      paste0("- Primary driver: ", primary_driver),
      paste0("- Volume gap (per 100 poss): ", sprintf("%.2f", volume_gap)),
      paste0("- Mix gap, total (per 100 poss): ", sprintf("%.2f", mix_gap_total)),
      paste0("- Total gap (per 100 poss): ", sprintf("%.2f", total_gap))
    )

    mix_zone_lines <- if (primary_driver %in% c("mix", "both")) {
      top2 <- team_rows %>%
        filter(mix_contribution < 0) %>%
        arrange(mix_contribution) %>%
        slice_head(n = 2)

      lines <- if (nrow(top2) == 0) {
        "  - no negative-contribution mix zones"
      } else {
        top2 %>%
          mutate(
            identity_tag = if_else(identity_driven, " (identity-driven: protect)", ""),
            line = paste0(
              "  - ", zone, ": ", type,
              " (mix contribution: ", sprintf("%.3f", mix_contribution), ")",
              identity_tag
            )
          ) %>%
          pull(line)
      }
      c("- Top mix-gap zones:", lines)
    } else {
      character(0)
    }

    # Accepted gm fix: always name the top non-identity negative mix zone as
    # a "secondary tune" line, even for amplify/volume-driven teams, so a
    # fixable non-identity deficit (e.g. a team's Restricted Area gap) is not
    # silently dropped just because it isn't the primary driver.
    secondary_row <- team_rows %>%
      filter(mix_contribution < 0, !identity_driven) %>%
      arrange(mix_contribution) %>%
      slice_head(n = 1)

    secondary_tune_line <- if (nrow(secondary_row) == 0) {
      "- Secondary tune (non-identity): none (no negative, non-identity-driven mix zone)"
    } else {
      paste0(
        "- Secondary tune (non-identity): ", secondary_row$zone, ": ", secondary_row$type,
        " (mix contribution: ", sprintf("%.3f", secondary_row$mix_contribution), ")"
      )
    }

    c(
      paste0("## ", tm),
      "",
      gap_summary_lines,
      mix_zone_lines,
      secondary_tune_line,
      paste0("- Fit read: ", fit_read),
      ""
    )
  }) %>%
    flatten_chr()

  method_explainer <- c(
    "## Method",
    "",
    paste(
      "Generation = volume (FGA per 100 possessions) x mix quality (expected",
      "points per shot given shot diet). Each team's generation gap versus",
      "the league is split into a volume gap and a mix gap; the mix gap is",
      "then attributed by zone. The two gap components sum to the team's",
      "total gap, which reconciles with the team's shot_generation_per100",
      "standing -- this is by construction, not a coincidence, since total_gap",
      "is the zone-approximated version of the same generation-versus-league",
      "quantity."
    ),
    "",
    paste(
      "fit_read is window-conditioned: a seller's offense diagnosis is",
      "context for a rebuild, not a buy signal (\"sell / accumulate\"); a",
      "buyer's diagnosis drives an actual gap-fill, amplify, adjust, or",
      "reassess call (reassess is the paper-tiger read: bottom-tier shot",
      "generation propped up by top-tier but declining making); a bubble",
      "team gets a trajectory-resolved judgment call that names the World",
      "Cup break rather than a flat verdict. Window comes from each team's",
      "win-loss record AND scoring margin per game, equally weighted",
      "(R/12_standing.R), never from anything in the offense decomposition",
      "above -- it conditions the recommendation, not the diagnosis."
    ),
    ""
  )

  caveats <- c(
    "## Caveats",
    "",
    paste(
      "Generation has two drivers: shot volume (FGA per 100 possessions) and",
      "shot-mix quality (expected points per shot). This report separates",
      "them; a team can generate poorly with a fine shot mix if its volume",
      "is low, and vice versa."
    ),
    "",
    paste(
      "The mix component is a zone-level read (the alternative-stratification",
      "check found zone-only preserves team generation and making ranks,",
      "Spearman 0.98 for generation and 1.00 for making), so zone is a",
      "defensible grain."
    ),
    "",
    paste(
      "This reads only the offensive side. The open play-by-play barely sees",
      "defense, rebounding value, or playmaking not expressed in shots, so",
      "these are offensive-generation gaps, not all roster gaps."
    ),
    "",
    paste(
      "Footnote: Above the Break 3 (about 0.996 points per shot) sits just",
      "below the rim-inflated overall mean (about 1.02), so it is tagged",
      "low-value only relative to that mean (\"slightly below-mean volume\"",
      "when a team over-weights it); it is a league-average look, not an",
      "inefficient one."
    ),
    "",
    paste(
      "Window (buyer/bubble/seller) is a data-driven proxy for a team's",
      "competitive standing that blends win-loss record and scoring margin",
      "per game (equally weighted z-scores), not a front-office decision; a",
      "real front office overrides it with private information. See",
      "output/standing.csv and R/12_standing.R."
    )
  )

  c(header, team_blocks, method_explainer, caveats)
}

main <- function() {
  pbp_events <- readRDS("data/processed/pbp_events.rds")
  team_generation_making <- readRDS("data/processed/team_generation_making.rds")
  team_blups <- readRDS("data/processed/team_blups.rds")
  icc_table <- readr::read_csv("output/icc_table.csv", show_col_types = FALSE)
  standing <- load_standing()
  team_trajectories <- readRDS("data/processed/team_trajectories.rds")

  result <- build_generation_gap(pbp_events, team_generation_making, team_blups, icc_table, standing, team_trajectories)
  gap_table <- result$gap_table
  fit_reads <- result$fit_reads

  write_csv(gap_table, "output/generation_gap.csv")
  writeLines(render_generation_gap_md(gap_table, fit_reads), "output/generation_gap.md")

  message("Fit read + window + primary driver by team:")
  team_summary <- gap_table %>%
    distinct(team, generation_pctile, making_pctile, window, volume_gap,
             mix_gap_total, total_gap, primary_driver, fit_read) %>%
    arrange(team)
  print(team_summary, n = Inf)

  invisible(gap_table)
}

if (sys.nframe() == 0) {
  main()
}
