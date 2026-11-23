# 15b_reread_report.R
#
# Purpose: render output/offseason/reread/reread_results.md, scorecard.md and session_info.txt
#   from the CSVs written by R/15_reread.R. Every number in the two markdown files is computed
#   here from those CSVs (or from the analysis tables), not typed in. Registered hypotheses
#   (H-R1 to H-R4, H1, H2, H3; PLAN.md "Scope", commit b0c3c80) and EXPLORATORY sections are
#   kept apart; exploratory sections never change a hypothesis verdict.
#   Run after R/15_reread.R (see README for the full run order).

suppressMessages(library(tidyverse))
source(file.path(if (exists("PROJECT_ROOT")) PROJECT_ROOT else ".", "R", "00_config.R"))
source(file.path(PROJECT_ROOT, "R", "load_tables.R"))
REREAD_DIR <- file.path(OUTPUT_DIR, "reread")
rd <- function(f) read_csv(file.path(REREAD_DIR, paste0(f, ".csv")), show_col_types = FALSE)

f1 <- function(x) ifelse(is.na(x), "NA", sprintf("%.1f", x))
f2 <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f", x))
f3 <- function(x) ifelse(is.na(x), "NA", sprintf("%.3f", x))
f4 <- function(x) ifelse(is.na(x), "NA", sprintf("%.4f", x))
fp <- function(x) ifelse(is.na(x), "NA", ifelse(x < 0.001, "<0.001", sprintf("%.3f", x)))
fe <- function(x) ifelse(is.na(x), "NA", formatC(x, format = "e", digits = 2))
pct <- function(x) paste0(sprintf("%+.1f", x), "%")
ci3 <- function(lo, hi) paste0("[", f3(lo), ", ", f3(hi), "]")
md_table <- function(df) {
  df <- df %>% mutate(across(everything(), ~ ifelse(is.na(.x), "NA", as.character(.x))))
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(trimws(r), collapse = " | "), " |")))
}
pop_label <- c(all15 = "all 15 teams", no_turnover13 = "13 teams without roster-turnover flag")
sm <- function(tbl, item) tbl$value[tbl$item == item]

main <- function() {
  flags <- rd("roster_turnover_flags")
  flagged <- flags$team[flags$roster_turnover_flag]
  hr1 <- rd("hr1_spearman"); hr1v <- rd("hr1_verdict")
  hr2 <- rd("hr2_generation_vs_making"); lva <- rd("hr2_lva_making")
  dec <- rd("hr2_decomposition"); sens <- rd("sensitivity_full_baseline")
  hr3 <- rd("hr3_loo_rmse"); hr3c <- rd("hr3_coefficients"); hr3p <- rd("hr3_paired_loo")
  hr3k <- rd("hr3_collinearity")
  hr4 <- rd("hr4_trajectory_labels"); hr4d <- rd("hr4_detail")
  h12t <- rd("h1h2_league_trends"); h12m <- rd("h1h2_tor_pdx")
  h3m <- rd("h3_gsv_making"); h3t <- rd("h3_gsv_trajectory")
  sc <- rd("scorecard"); ss <- rd("scorecard_summary"); adv <- rd("advice_outcome")
  po <- rd("playoffs_descriptive"); moves <- rd("player_moves")

  games <- load_table("games", "all")
  n_fh <- length(window_game_ids(games, "first_half")); n_sh <- length(window_game_ids(games, "second_half"))
  n_full <- length(window_game_ids(games, "full"))
  gpt <- load_table("team_games", "regular") %>% count(team) %>% pull(n) %>% unique()
  reg_dates <- sort(unique(games$game_date[games$season_type == "regular" & games$game_id > V1_LAST_GAME_ID]))
  gaps <- as.integer(diff(reg_dates)); gi <- which.max(gaps)
  rc <- readLines(file.path(REREAD_DIR, "regression_check_v1.md"))
  rc_rows <- rc[grepl("^\\| [a-z_]+\\.csv \\|", rc)][1:5]
  rc_max <- max(as.numeric(map_chr(strsplit(rc_rows, "\\|"), ~ trimws(.x[6]))))
  rc_pass <- all(map_chr(strsplit(rc_rows, "\\|"), ~ trimws(.x[8])) == "TRUE")

  L <- character()
  add <- function(...) L <<- c(L, ...)

  # ---------------------------------------------------------------- header and setup
  add("# Full-season re-read of v1: results", "",
      "Hypotheses and predicted directions pre-registered in b0c3c80. Decision rules were specified in the execution plan (docs/plans/reread_plan.md) before any second-half output was computed, but first committed with the code at cd66cc0.", "",
      paste0("Regular season only for all hypotheses; playoffs are descriptive. Each window (first half = games 1 to ", n_fh, ", the v1 sample; second half = games ", n_fh + 1, " to ", n_full,
             "; full = ", n_full, ") computes its own stratified expected-points baseline and its own identity models, as v1 did. Registered hypotheses: H-R1 to H-R4, H1, H2, H3 (PLAN.md, commit b0c3c80); none were added. Everything not in that registry sits in a section labeled EXPLORATORY and never changes a verdict. Regenerate with the run order in `README.md` (windows, then `R/15a_regression_check.R`, `R/15_reread.R`, `R/15b_reread_report.R`)."), "",
      "## Setup and caveats", "",
      paste0("- n = 15 teams (", 15 - length(flagged), " without roster-turnover-flagged teams). Spearman and leave-one-out comparisons at this n have very low power; bootstrap intervals are over teams (2,000 resamples, seed 20261123, percentile)."),
      paste0("- First-half regression check against the committed v1 outputs: see `regression_check_v1.md` (max abs diff ", rc_max, " across the five files; all pass: ", rc_pass, ")."),
      "- Own-window baselines: each window's expected points are league averages within that window, so team generation and making are relative to that window's league. A league-wide shift between halves is removed by construction. The full-window alternative is in the EXPLORATORY sensitivity below.",
      paste0("- Roster-turnover flag: a team is flagged when players who appear for 2+ teams account for at least 10 percent of its first-half minutes (players who left) or second-half minutes (players who arrived). The flag marks roster turnover over the whole season, not only deadline trades. Flagged teams: ", paste(flagged, collapse = ", "), ". The \"without flag\" population drops them. Moves are in `player_moves.csv` (", sum(moves$around_deadline), " of ", nrow(moves), " moves have a first game for the new team within 2026-07-26 to 2026-08-09 or a gap spanning the Aug 2 deadline)."),
      "- Trajectory refits for the without-flag population (H1, H2) keep rows of non-flagged teams as the modeled team and all teams as opponents.",
      paste0("- Playoffs: R/06 mixed models were not run for the playoffs window (", nrow(po), " teams, ", min(po$po_games), " to ", max(po$po_games), " games each); R/05 and R/07 only."),
      paste0("- Scope of the second-half window: the full regular-season window overlaps v1 (the ", n_fh, " v1 games are ", n_fh, " of ", n_full, " games); full-window results are not out-of-sample."),
      "- Metric scales differ by test: H-R1 uses schedule-adjusted BLUPs from R/06, H-R2 uses raw per100 team values from R/07 (no opponent adjustment). The two are not directly comparable.",
      "- Fallback inference: where `fallback_used` is TRUE (see H1, H2), R/06 fits random intercepts only and takes the league trend p-value from that model. It ignores team-specific slope variance, so its standard error is too small and its p-values are anticonservative. Team slopes in those rows are per-team OLS slopes of residuals, not model-based intervals.",
      "- Not controlled: injuries and player availability. Not assessed: cap feasibility of the constrained acquire reads (parked in PLAN.md).",
      paste0("- Schedule: the v1 read cited a late-August World Cup break; schedule effects are not modeled. The longest league-wide gap between second-half game dates is ", gaps[gi], " days (", reg_dates[gi], " to ", reg_dates[gi + 1], ")."),
      paste0("- Regular season is ", paste(gpt, collapse = "/"), " games per team."), "",
      "### Roster-turnover flags", "")
  add(md_table(flags %>% transmute(team, minutes_share_out = f3(minutes_share_out), minutes_share_in = f3(minutes_share_in),
                                    n_players_out = n_players_out, n_players_in = n_players_in, roster_turnover_flag)), "")

  # ---------------------------------------------------------------- H-R1
  add("## H-R1 (identity stable)", "",
      paste0("Hypothesis: the ICC >= 0.15 identity-anchor metrics rank teams similarly in the second half as in the first. Predicted direction: Spearman >= 0.7 for most anchor metrics. Decision rule: supported if rho >= 0.7 for more than half of the anchor metrics. Anchor metrics are those with ICC >= 0.15 in the v1 icc_table (", hr1v$n_anchor[1], " metrics). Team scores are schedule-adjusted BLUPs from each window."), "")
  for (p in c("all15", "no_turnover13")) {
    v <- hr1v %>% filter(population == p)
    flip <- (v$n_rho_ge_0.7 - 1) <= v$n_anchor / 2
    add(paste0("**", pop_label[[p]], "**: median rho ", f3(v$median_rho), "; rho >= 0.7 for ", v$n_rho_ge_0.7, " of ", v$n_anchor,
               " metrics. Verdict: **", v$verdict, "**. ", ifelse(flip, "The verdict flips if one more metric drops below 0.7.", "The verdict does not flip if one more metric drops below 0.7."), ""), "")
    add(md_table(hr1 %>% filter(population == p) %>%
                   transmute(metric, v1_icc = f3(v1_icc), rho = f3(rho), ci_95 = ci3(ci_low, ci_high))), "")
  }

  # ---------------------------------------------------------------- H-R2
  add("## H-R2 (generation holds, making regresses)", "",
      "Hypothesis: first-half shot generation predicts second-half generation better than first-half making predicts second-half making. Predicted direction: generation rho > making rho; sharpest case LVA (making falls in the second half). Decision rule: supported if generation rho > making rho and the bootstrap CI of the difference excludes 0; directionally consistent if greater but the CI spans 0. Uses raw per100 team values (see caveat on metric scales).", "")
  add(md_table(hr2 %>% transmute(population = pop_label[population], n = n_teams,
                                  rho_generation = f3(rho_generation), gen_ci = ci3(gen_ci_low, gen_ci_high),
                                  rho_making = f3(rho_making), mk_ci = ci3(mk_ci_low, mk_ci_high),
                                  diff_gen_minus_mk = f3(diff), diff_ci = ci3(diff_ci_low, diff_ci_high), verdict)), "")
  add(paste0("Verdict: ", paste0(pop_label[hr2$population], " ", hr2$verdict, collapse = "; "), ". ", ifelse(all(hr2$rho_making > hr2$rho_generation), "Making ranks were more stable than generation ranks in both populations, the opposite of the predicted direction.", "Making ranks were not more stable than generation ranks in both populations."), ""), "")
  add("LVA (not flagged), per 100 possessions:", "")
  add(md_table(lva %>% transmute(window, generation = f2(shot_generation_per100), generation_pctile,
                                  making = f2(shot_making_per100), making_pctile)), "")
  d <- lva$shot_making_per100[lva$window == "second_half"] - lva$shot_making_per100[lva$window == "first_half"]
  add(paste0("LVA making change, second half minus first half: ", sprintf("%+.4f", d), " per 100; percentile ",
             lva$making_pctile[lva$window == "first_half"], " to ", lva$making_pctile[lva$window == "second_half"],
             ". Predicted direction (making falls): ", ifelse(abs(d) < 0.01, "not met (the change is within the 0.01 per100 tie tolerance, so making did not move)", ifelse(d < 0, "met", "not met")), "."), "")

  add("### EXPLORATORY: why generation is less stable than making (H-R2 decomposition)", "",
      "Not in the registry; does not change the H-R2 verdict. Expected points per FGA (diet = expected_pts / fga) and FGA per possession (volume = fga / poss_count) are tracked separately next to generation per100 and making per100, with Spearman first half vs second half and the same team bootstrap. Generation per100 combines diet and volume (generation per100 = 100 x diet x volume).", "")
  add(md_table(dec %>% transmute(population = pop_label[population], measure, n = n_teams, rho = f3(rho), ci_95 = ci3(ci_low, ci_high))), "")
  a15 <- dec %>% filter(population == "all15") %>% select(measure, rho) %>% deframe()
  add(paste0("All 15 teams: diet rho ", f3(a15[["diet"]]), ", volume rho ", f3(a15[["volume"]]), ", generation rho ", f3(a15[["generation"]]), ", making rho ", f3(a15[["making"]]),
             ". ", ifelse(a15[["diet"]] > a15[["volume"]], "Diet is more stable than volume, so the weaker link in generation per100 is volume (FGA per possession), not shot diet.", "Volume is at least as stable as diet; the weaker link in generation per100 is not volume."),
             ifelse(a15[["generation"]] < min(a15[["diet"]], a15[["volume"]]), " Generation per100 is less stable than either component, so changes in diet and volume partly offset each way in the product.", ""), ""), "")

  add("### EXPLORATORY: sensitivity to the baseline window", "",
      paste0("Both halves scored with one baseline built on the full regular-season window (", n_full, " games), then generation and making per100 recomputed and the H-R2 rhos redone. Written to `sensitivity_full_baseline.csv`. The full window includes both halves, so this baseline is not independent of either. Does not change the H-R2 verdict."), "")
  add(md_table(sens %>% transmute(baseline, population = pop_label[population], n = n_teams, rho_generation = f3(rho_generation),
                                   rho_making = f3(rho_making), diff_gen_minus_mk = f3(diff), diff_ci = ci3(diff_ci_low, diff_ci_high), verdict)), "")

  # ---------------------------------------------------------------- H-R3
  add("## H-R3 (reads beyond the record)", "",
      "Hypothesis: first-half generation and making add information about second-half results beyond first-half record. Both outcomes (second-half point differential per game and second-half win pct) are treated as equal; neither is primary. Decision rule: supported if model B beats model A on leave-one-out RMSE for both outcomes; not supported if it beats it for neither; mixed / inconclusive otherwise. A = outcome ~ first-half win pct; B = outcome ~ first-half win pct + generation + making. The alternative baseline A' (outcome ~ first-half point differential per game) is EXPLORATORY and is shown for context only. n is 15 (13), low power.", "")
  add(md_table(hr3 %>% transmute(population = pop_label[population], outcome = if_else(outcome == "sh_pd", "pd_per_game", "win_pct"),
                                  n = n_teams, rmse_A = f4(loo_rmse_A_record), rmse_B = f4(loo_rmse_B_record_gen_mk),
                                  rmse_mean_only = f4(loo_rmse_mean_only), B_beats_A = B_beats_A,
                                  rmse_Aprime_alt_baseline_pd_EXPLORATORY = f4(loo_rmse_Aprime_pd), B_beats_Aprime_EXPLORATORY = B_beats_Aprime)), "")
  add("Coefficients (OLS on all teams in the population; estimate, SE, p):", "")
  add(md_table(hr3c %>% filter(model %in% c("A", "B"), term != "(Intercept)") %>%
                 transmute(population = pop_label[population], outcome = if_else(outcome == "sh_pd", "pd_per_game", "win_pct"),
                           model, term, estimate = f4(estimate), se = f4(se), p = fp(p), r_squared = f3(r_squared))), "")
  for (p in c("all15", "no_turnover13")) {
    x <- hr3 %>% filter(population == p); pp <- hr3p %>% filter(population == p, comparator == "A_record")
    xpd <- x %>% filter(outcome == "sh_pd"); xwp <- x %>% filter(outcome == "sh_win_pct")
    ppd <- pp %>% filter(outcome == "sh_pd"); pwp <- pp %>% filter(outcome == "sh_win_pct")
    chg_pd <- 100 * (xpd$loo_rmse_B_record_gen_mk / xpd$loo_rmse_A_record - 1)
    chg_wp <- 100 * (xwp$loo_rmse_B_record_gen_mk / xwp$loo_rmse_A_record - 1)
    lab <- case_when(!xpd$B_beats_A & !xwp$B_beats_A ~ "not supported", xpd$B_beats_A & xwp$B_beats_A ~ "supported", TRUE ~ "mixed / inconclusive")
    add(paste0("Verdict, ", pop_label[[p]], ": **", lab, "**: ", ifelse(xpd$B_beats_A, "gain", "no gain"), " on point differential (B vs A LOO RMSE ", f3(xpd$loo_rmse_B_record_gen_mk), " vs ", f3(xpd$loo_rmse_A_record),
               ", change ", pct(chg_pd), "), ", ifelse(xwp$B_beats_A, "gain", "gain absent"), " on win pct (", f4(xwp$loo_rmse_B_record_gen_mk), " vs ", f4(xwp$loo_rmse_A_record), ", RMSE change ", pct(chg_wp), ")."), "")
    add(paste0("Paired per-team LOO squared-error difference (B minus A; negative favors B): point differential mean ", f3(ppd$mean_sq_err_diff), " ", ci3(ppd$ci_low, ppd$ci_high),
               "; win pct mean ", f4(pwp$mean_sq_err_diff), " ", ci3(pwp$ci_low, pwp$ci_high), " (team bootstrap, 2,000 resamples, seed 20261123). Intervals span zero: ",
               ifelse(ppd$ci_low <= 0 & ppd$ci_high >= 0 & pwp$ci_low <= 0 & pwp$ci_high >= 0, "both outcomes", "not both outcomes"), "."), "")
  }
  mk <- hr3c %>% filter(model == "B", term == "making")
  rc_ <- hr3c %>% filter(term == "fh_win_pct", outcome == "sh_win_pct", population == "all15")
  rk <- hr3k %>% filter(population == "all15")
  add(paste0("Making coefficient in model B is ", ifelse(all(mk$estimate < 0), "negative", ifelse(all(mk$estimate > 0), "positive", "mixed in sign")), " for both outcomes and both populations (all 15 teams: point differential ", f3(mk$estimate[mk$population == "all15" & mk$outcome == "sh_pd"]),
             ", win pct ", f3(mk$estimate[mk$population == "all15" & mk$outcome == "sh_win_pct"]), "). ",
             ifelse(all(mk$estimate < 0), "A negative sign is the regression-to-the-mean reading: conditional on record, a team whose first half included more shot making above expectation did worse afterward, because above-expectation making partly reverts. It does not say making is bad for results. ", ""),
             "The fh_win_pct coefficient moves from ", f3(rc_$estimate[rc_$model == "A"]), " in A to ", f3(rc_$estimate[rc_$model == "B"]),
             " in B (win pct outcome, all 15 teams), which fits collinearity: first-half win pct correlates ", f3(rk$cor_record_making), " with making and ", f3(rk$cor_record_generation), " with generation (all 15 teams)."), "")

  # ---------------------------------------------------------------- H-R4
  add("## H-R4 (trajectory labels weak)", "",
      "Hypothesis: v1 improving/declining labels, most with intervals spanning zero, do not predict second-half direction better than chance. Expected null. Label = v1 shot-making trajectory in `output/deadline_read.csv`, a within-first-half slope; outcome direction = sign of the level change (second-half minus first-half making per 100). These are different quantities, so disagreement is not a contradiction of the slope. Changes with |delta| < 0.01 per100 count as ties and are excluded from the test. Exact two-sided binomial test vs 0.5. Decision rule: null supported unless agreement > 0.5 with p < 0.05.", "")
  add(md_table(hr4 %>% transmute(population = pop_label[population], subset, n = n_teams, ties_excluded = n_ties, agree = n_agree,
                                  agreement = f3(agreement), p_two_sided = f3(p_two_sided), ci_95 = ci3(ci_low, ci_high), verdict)), "")
  add("Per team:", "")
  add(md_table(hr4d %>% transmute(team, v1_label = trajectory, interval_spans_zero, making_first = f2(mk1),
                                   making_second = f2(mk2), change = f2(making_change), outcome_direction, agree)), "")
  ties <- hr4d %>% filter(outcome_direction == "tie")
  add(paste0("Ties excluded: ", ifelse(nrow(ties) == 0, "none", paste0(paste(ties$team, collapse = ", "), " (change ", paste(sprintf("%+.4f", ties$making_change), collapse = ", "), " per100)")), "."), "")

  # ---------------------------------------------------------------- H1, H2
  nfb <- function(w) { x <- h12t %>% filter(population == "all15", window == w); paste0(sum(x$fallback_used), " of ", nrow(x)) }
  add("## H1, H2 on the full season", "",
      "Hypothesis: H1 (transition rises with reps) and H2 (chemistry proxies improve, strongest for TOR and PDX) were published v1 nulls; do they hold with twice the sample? League trend is the fixed effect of game_index (change per team game), two-sided normal p, from R/06's trajectory model. `fallback_used` TRUE means the random-slope model hit the singular or convergence fallback to random intercepts plus per-team residual slopes (anticonservative p-values; see caveats). Decision rule: trend p < 0.05.", "")
  add(md_table(h12t %>% transmute(population = pop_label[population], window, metric, trend_per_game = fe(league_trend),
                                   p = f3(league_trend_p), fallback_used)), "")
  add(paste0("Random-slope fallback used for these four metrics (all 15 teams): first half ", nfb("first_half (v1 sample)"), ", second half ", nfb("second_half"), ", full ", nfb("full"), " (", paste(gpt, collapse = "/"), " games per team in the full window)."), "")
  add("TOR and PDX team slopes (per game, 95% interval). `interval_type` differs by row: `residual_OLS_slope` rows are per-team OLS slopes of residuals from the fallback model; `random_slope_posterior` rows are posterior intervals from the random-slope model. Compare within a type only.", "")
  add(md_table(h12m %>% transmute(population = pop_label[population], window, metric, team, slope = fe(slope),
                                   interval = paste0("[", fe(ci_low), ", ", fe(ci_high), "]"), interval_type, trajectory, interval_spans_zero)), "")
  full_all <- h12t %>% filter(population == "all15", window == "full")
  add(paste0("Verdicts (full window, all 15 teams, rule p < 0.05): ",
             paste0(full_all$metric, " p=", f3(full_all$league_trend_p), ifelse(full_all$league_trend_p < 0.05, " (significant)", " (null)"), collapse = "; "),
             ". TOR and PDX intervals span zero in every row above: ", ifelse(all(h12m$interval_spans_zero), "yes", "no"), "."), "")
  sh_tr <- h12t %>% filter(population == "all15", window == "second_half")
  sig <- sh_tr %>% filter(league_trend_p < 0.05)
  add(paste0("Second-half league-trend rows are shown for reference and are not the registered full-season test. ", nrow(sig), " of ", nrow(sh_tr), " second-half metrics have p < 0.05",
             ifelse(nrow(sig) > 0, paste0(" (", paste0(sig$metric, " p=", f3(sig$league_trend_p), ", fallback_used ", sig$fallback_used, collapse = "; "), ")"), ""),
             "; with fallback p-values anticonservative and several metrics tested on one half, these are not treated as findings and change no verdict. Per-team TOR and PDX slopes for the second half were not produced."), "")

  # ---------------------------------------------------------------- H3
  g <- h3m %>% filter(window != "playoffs")
  pl <- h3m %>% filter(window == "playoffs")
  gm1 <- g$shot_making_per100[g$window == "first_half"]; gm2 <- g$shot_making_per100[g$window == "second_half"]
  add("## H3 (GSV making)", "",
      paste0("Hypothesis: GSV's low FG% is making below expectation on an acceptable diet; GSV won the title, so report whether its making moved toward expectation. Per 100 possessions; percentile over the teams in the window (", g$n_teams[1], " for regular-season windows, ", pl$n_teams, " for playoffs)."), "")
  add(md_table(h3m %>% transmute(window, n_teams, generation = f2(shot_generation_per100), generation_pctile,
                                  making = f2(shot_making_per100), making_pctile)), "")
  add("GSV shot-making trajectory (R/06 slope per game, 95% interval):", "")
  add(md_table(h3t %>% transmute(window, slope = f4(slope), interval = paste0("[", f4(ci_low), ", ", f4(ci_high), "]"), trajectory, interval_spans_zero)), "")
  add(paste0("Verdict line: premise not supported in either half (first-half making ", f2(gm1), ", second-half ", f2(gm2), " per 100, neither meaningfully below zero); making near zero throughout (full window ",
             f2(g$shot_making_per100[g$window == "full"]), "); playoff ", f2(pl$shot_making_per100), " descriptive (GSV, ", po$po_games[po$team == "GSV"], " games, ", po$po_fga[po$team == "GSV"], " FGA)."), "")

  # ---------------------------------------------------------------- scorecard (exploratory)
  v <- c("held", "partly held", "failed"); vk <- gsub(" ", "_", v)
  rng <- map_chr(vk, ~ paste0(sm(ss, paste0("range_min_", .x)), " to ", sm(ss, paste0("range_max_", .x))))
  add("## EXPLORATORY: v1 read scorecard (descriptor stability, not advice outcome)", "",
      paste0("Not in the registry; no verdict above depends on it. Tiers follow v1 (ntile(x, 3) over 15 teams, second-half window). Held if both generation and making tiers are unchanged; partly held if exactly one tier changed by one step; failed otherwise. Main counts: held ", sm(ss, "main_count_held"), ", partly held ", sm(ss, "main_count_partly_held"), ", failed ", sm(ss, "main_count_failed"), " of ", sm(ss, "n_teams"),
             ". ", sm(ss, "n_boundary_sensitive"), " teams are boundary_sensitive (rank adjacent to a tier boundary in either half on either axis). Under one-rank swaps the counts range over: held ", rng[1], ", partly held ", rng[2], ", failed ", rng[3],
             " (each team's tiers varied independently, so the range is conservative; the lower bound counts teams whose verdict cannot change)."), "",
      paste0("Chance benchmarks: if tiers were unrelated across halves, P(held) = 1/9 = ", f3(sm(ss, "chance_rate_held")), ", an expected ", f2(sm(ss, "chance_expected_held")), " of ", sm(ss, "n_teams"), " teams. Record-tertile benchmark: the same tertile rule applied to first-half vs second-half win pct (ties broken by point differential per game) keeps ", sm(ss, "benchmark_record_tier_kept"),
             " of ", sm(ss, "n_teams"), " teams in the same record tier (chance for one axis is 1/3, an expected ", f2(sm(ss, "benchmark_record_tier_chance_expected")), "). The scorecard uses two axes, so its chance rate is lower than the benchmark's."), "",
      "Percentiles and changes (second half minus v1):", "")
  add(md_table(sc %>% transmute(team, verdict, boundary_sensitive, verdicts_possible = gsub(" \\| ", " or ", verdicts_possible),
                                 gen_tier = paste0(v1_generation_tier, " to ", sh_generation_tier),
                                 gen_pctile = paste0(v1_generation_pctile, " to ", sh_generation_pctile, " (", sprintf("%+d", generation_pctile_change), ")"),
                                 mk_tier = paste0(v1_making_tier, " to ", sh_making_tier),
                                 mk_pctile = paste0(v1_making_pctile, " to ", sh_making_pctile, " (", sprintf("%+d", making_pctile_change), ")"),
                                 roster_turnover_flag)), "")
  add("Scorecard by roster-turnover flag:", "")
  add(md_table(sc %>% count(roster_turnover_flag, verdict) %>% pivot_wider(names_from = verdict, values_from = n, values_fill = 0)), "")

  # ---------------------------------------------------------------- advice outcome (exploratory)
  cnt <- adv %>% count(v1_window, advice_outcome) %>%
    pivot_wider(names_from = advice_outcome, values_from = n, values_fill = 0)
  for (cn in c("right", "wrong", "not scored")) if (!cn %in% names(cnt)) cnt[[cn]] <- 0L
  cnt <- cnt %>% select(v1_window, right, wrong, `not scored`) %>% arrange(factor(v1_window, levels = c("buyer", "bubble", "seller")))
  add("## EXPLORATORY: advice outcome", "",
      "Not in the registry; separate from every hypothesis verdict. Windows (buyer, bubble, seller) come from v1 record plus margin, so a buyer is by construction a team already winning; the outcome checks the label more than any model read.", "",
      paste0("Scoring rules: seller right if the team missed the playoffs; buyer right if it made them; bubble \"lean buy\" right if second-half win pct >= .500; bubble \"lean hold or sell\" right if second-half win pct < .500 (a two-way call: hold and sell are not separated, so it is scored on the below-.500 side only); ", paste(flagged, collapse = " and "), " carry the roster-turnover flag and are not scored."), "",
      paste0("Deadline action rule: a move counts if the new team's first game is 2026-07-20 to 2026-08-02 inclusive, or the gap between the player's last game for the old team and first game for the new team contains 2026-08-02 and is at most 14 days (the plan's date window applied to observable game dates; the trade date itself is not in the data). Each move is valued by the player's second-half minutes with the new team. Net = minutes in minus minutes out, as a share of the team's second-half minutes; bought if >= +2 percent, sold if <= -2 percent, otherwise stood pat. The 2 percent threshold is a descriptive choice. Moves with long gaps that do not meet the rule (for example players who sat out for weeks) are not counted."), "")
  add(md_table(adv %>% transmute(team, window = v1_window, v1_read = sub(":.*", "", v1_recommendation), deadline_action,
                                  net_minutes_share = sprintf("%+.3f", net_minutes_share), second_half_record = sh_record,
                                  playoff_result, advice_outcome)), "")
  add("Counts by window:", "", md_table(cnt %>% rename(window = v1_window)), "")
  add(paste0("Right ", sum(adv$advice_outcome == "right"), ", wrong ", sum(adv$advice_outcome == "wrong"), ", not scored ", sum(adv$advice_outcome == "not scored"), " of ", nrow(adv), ". Deadline action counts: ",
             paste(names(table(adv$deadline_action)), table(adv$deadline_action), collapse = ", "), "."), "")

  # ---------------------------------------------------------------- playoffs
  add("## Playoffs (descriptive, no tests)", "",
      paste0("Regular-season full-window generation and making per 100 versus the playoffs window (own baselines, ", nrow(po), " teams). Playoff samples are small (", min(po$po_fga), " to ", max(po$po_fga), " FGA) and selected. The rs and po columns are not on a common baseline (each is relative to its own window's league), so no difference column is computed."), "")
  add(md_table(po %>% transmute(team, games = po_games, series_result, rs_gen = f2(rs_generation), po_gen = f2(po_generation),
                                 rs_making = f2(rs_making), po_making = f2(po_making), po_fga)), "")

  writeLines(L, file.path(REREAD_DIR, "reread_results.md"))

  # ---------------------------------------------------------------- scorecard.md
  S <- c("# v1 read scorecard (EXPLORATORY: descriptor stability, not advice outcome)", "",
         "Per team: the v1 deadline read (generation tier, making tier, trajectory, lever, recommendation, from `output/deadline_read.csv`) against the second-half window (own baseline, ntile(x, 3) over 15 teams as in v1). Verdict: held = both tiers unchanged; partly held = exactly one tier changed by one step; failed = otherwise. boundary_sensitive = rank adjacent to a tier boundary in either half on either axis; verdicts_possible lists the verdicts reachable under one-rank swaps. Trajectory outcome compares the v1 shot-making label with the sign of the second-half minus first-half making change (ties within 0.01 per100 excluded); it is not part of the verdict. Tier 1 = low, 3 = high. Percentile change = second half minus v1.", "",
         paste0("Counts: held ", sm(ss, "main_count_held"), ", partly held ", sm(ss, "main_count_partly_held"), ", failed ", sm(ss, "main_count_failed"), " of ", sm(ss, "n_teams"),
                "; range under one-rank swaps: held ", rng[1], ", partly held ", rng[2], ", failed ", rng[3], "; boundary_sensitive teams ", sm(ss, "n_boundary_sensitive"),
                "; chance rate for held 1/9 (expected ", f2(sm(ss, "chance_expected_held")), " teams); record-tertile benchmark keeps ", sm(ss, "benchmark_record_tier_kept"), " of ", sm(ss, "n_teams"), " teams in the same record tier."), "",
         md_table(sc %>% transmute(team, verdict, boundary_sensitive, verdicts_possible = gsub(" \\| ", " or ", verdicts_possible),
                                    gen_tier_v1 = v1_generation_tier, gen_tier_sh = sh_generation_tier,
                                    gen_pctile_v1 = v1_generation_pctile, gen_pctile_sh = sh_generation_pctile, gen_pctile_change = generation_pctile_change,
                                    mk_tier_v1 = v1_making_tier, mk_tier_sh = sh_making_tier,
                                    mk_pctile_v1 = v1_making_pctile, mk_pctile_sh = sh_making_pctile, mk_pctile_change = making_pctile_change,
                                    v1_trajectory, spans_zero = v1_interval_spans_zero, trajectory_outcome,
                                    v1_lever, roster_turnover_flag, sh_record, sh_pd_per_game = f2(sh_pd_per_game), final_record, final_rank)), "",
         "v1 recommendations (text from deadline_read.csv, dashes replaced by semicolons):", "",
         paste0("- ", sc$team, " (", sc$verdict, "): ", sc$v1_recommendation))
  writeLines(S, file.path(REREAD_DIR, "scorecard.md"))

  # ---------------------------------------------------------------- session info
  si <- c(capture.output(print(sessionInfo())), "",
          paste0("lme4 ", as.character(packageVersion("lme4")), " (installed from the distribution package r-cran-lme4 via apt; CRAN was not reachable)"),
          paste0("Bootstrap: seed 20261123, 2,000 team resamples"))
  writeLines(si, file.path(REREAD_DIR, "session_info.txt"))
  message("Wrote reread_results.md, scorecard.md and session_info.txt")
}

if (sys.nframe() == 0) main()
