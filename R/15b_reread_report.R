# 15b_reread_report.R
#
# Purpose: render output/offseason/reread/reread_results.md and scorecard.md from the CSVs
#   written by R/15_reread.R. Numbers only: each hypothesis section carries the
#   pre-registered statement (PLAN.md "Scope"), the numbers, and the verdict from the
#   pre-registered rule. Run after R/15_reread.R.

suppressMessages(library(tidyverse))
source(file.path(if (exists("PROJECT_ROOT")) PROJECT_ROOT else ".", "R", "00_config.R"))
REREAD_DIR <- file.path(OUTPUT_DIR, "reread")
rd <- function(f) read_csv(file.path(REREAD_DIR, paste0(f, ".csv")), show_col_types = FALSE)

f2 <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f", x))
f3 <- function(x) ifelse(is.na(x), "NA", sprintf("%.3f", x))
f4 <- function(x) ifelse(is.na(x), "NA", sprintf("%.4f", x))
fp <- function(x) ifelse(is.na(x), "NA", ifelse(x < 0.001, "<0.001", sprintf("%.3f", x)))
fe <- function(x) ifelse(is.na(x), "NA", formatC(x, format = "e", digits = 2))
md_table <- function(df) {
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}
pop_label <- c(all15 = "all 15 teams", no_trade13 = "13 teams without trade flag")

main <- function() {
  flags <- rd("trade_flags")
  flagged <- flags$team[flags$trade_flag]
  hr1 <- rd("hr1_spearman"); hr1v <- rd("hr1_verdict")
  hr2 <- rd("hr2_generation_vs_making"); lva <- rd("hr2_lva_making")
  hr3 <- rd("hr3_loo_rmse"); hr3c <- rd("hr3_coefficients")
  hr4 <- rd("hr4_trajectory_labels"); hr4d <- rd("hr4_detail")
  h12t <- rd("h1h2_league_trends"); h12m <- rd("h1h2_tor_pdx")
  h3m <- rd("h3_gsv_making"); h3t <- rd("h3_gsv_trajectory")
  sc <- rd("scorecard"); po <- rd("playoffs_descriptive"); moves <- rd("player_moves")

  L <- character()
  add <- function(...) L <<- c(L, ...)

  add("# Full-season re-read of v1: results", "",
      "Regular season only for all hypotheses; playoffs are descriptive. Each window (first half = games 1 to 182, the v1 sample; second half = games 183 to 330; full = 330) computes its own stratified expected-points baseline and its own identity models, as v1 did. Hypotheses are the pre-registered H-R1 to H-R4, H1, H2, H3 (PLAN.md, commit b0c3c80); none were added. Regenerate with `Rscript R/15_reread.R && Rscript R/15b_reread_report.R`.", "",
      "## Setup and caveats", "",
      "- n = 15 teams (13 without trade-flagged teams). Spearman and leave-one-out comparisons at this n have very low power; bootstrap intervals are over teams (2,000 resamples, seed 20261123, percentile).",
      paste0("- First-half regression check against the committed v1 outputs: see `regression_check_v1.md` (max abs diff 0 in all five files)."),
      "- Own-window baselines: each window's expected points are league averages within that window, so team generation and making are relative to that window's league. A league-wide shift between halves is removed by construction.",
      paste0("- Trade flags: a team is flagged when players who appear for 2+ teams account for at least 10 percent of its first-half minutes (players who left) or second-half minutes (players who arrived). Flagged teams: ", paste(flagged, collapse = ", "), ". The \"no trade\" population drops them. Moves are in `player_moves.csv` (", sum(moves$around_deadline), " of ", nrow(moves), " moves have a first game for the new team within 2026-07-26 to 2026-08-09 or a gap spanning the Aug 2 deadline)."),
      "- Trajectory refits for the no-trade population (H1, H2) keep rows of non-flagged teams as the modeled team and all teams as opponents.",
      "- Playoffs: R/06 mixed models were not run for the playoffs window (8 teams, 2 to 13 games each); R/05 and R/07 only.",
      "- Game 7 ESPN gap is irrelevant here (our own pbp has the game).", "",
      "### Trade flags", "")
  add(md_table(flags %>% transmute(team, minutes_share_out = f3(minutes_share_out), minutes_share_in = f3(minutes_share_in),
                                    n_players_out, n_players_in, trade_flag)), "")

  # H-R1
  add("## H-R1 (identity stable)", "",
      "Pre-registered: the ICC >= 0.15 identity-anchor metrics rank teams similarly in the second half as in the first. Prediction: Spearman >= 0.7 for most anchor metrics. Rule: supported if rho >= 0.7 for more than half of the anchor metrics. Anchor metrics are those with ICC >= 0.15 in the v1 icc_table (8 metrics). Team scores are schedule-adjusted BLUPs from each window.", "")
  for (p in c("all15", "no_trade13")) {
    add(paste0("**", pop_label[[p]], "**"), "")
    add(md_table(hr1 %>% filter(population == p) %>%
                   transmute(metric, v1_icc = f3(v1_icc), rho = f3(rho), ci_95 = paste0("[", f3(ci_low), ", ", f3(ci_high), "]"))), "")
    v <- hr1v %>% filter(population == p)
    add(paste0("Metrics with rho >= 0.7: ", v$n_rho_ge_0.7, " of ", v$n_anchor, "; median rho ", f3(v$median_rho), ". Verdict: **", v$verdict, "**."), "")
  }

  # H-R2
  add("## H-R2 (generation holds, making regresses)", "",
      "Pre-registered: first-half shot generation predicts second-half generation better than first-half making predicts second-half making. Sharpest case: LVA (generation 7th percentile, making 100th, declining) sees making fall in the second half. Rule: supported if generation rho > making rho and the bootstrap CI of the difference excludes 0; directionally consistent if greater but the CI spans 0.", "")
  add(md_table(hr2 %>% transmute(population = pop_label[population], n = n_teams,
                                  rho_generation = f3(rho_generation), gen_ci = paste0("[", f3(gen_ci_low), ", ", f3(gen_ci_high), "]"),
                                  rho_making = f3(rho_making), mk_ci = paste0("[", f3(mk_ci_low), ", ", f3(mk_ci_high), "]"),
                                  diff_gen_minus_mk = f3(diff), diff_ci = paste0("[", f3(diff_ci_low), ", ", f3(diff_ci_high), "]"),
                                  verdict)), "")
  add("LVA (not trade-flagged), per 100 possessions:", "")
  add(md_table(lva %>% transmute(window, generation = f2(shot_generation_per100), generation_pctile,
                                  making = f2(shot_making_per100), making_pctile)), "")
  d <- lva$shot_making_per100[lva$window == "second_half"] - lva$shot_making_per100[lva$window == "first_half"]
  add(paste0("LVA making change, second half minus first half: ", sprintf("%.4f", d), " per 100; percentile ",
             lva$making_pctile[lva$window == "first_half"], " to ", lva$making_pctile[lva$window == "second_half"],
             ". Prediction (making falls): ", ifelse(d < 0, "met", "not met"), "."), "")

  # H-R3
  add("## H-R3 (reads beyond the record)", "",
      "Pre-registered: first-half generation and making add information about second-half results (point differential per game, win pct) beyond first-half record. Rule: supported if model B beats model A on leave-one-out RMSE. A = outcome ~ first-half win pct; A' = outcome ~ first-half point differential per game (stricter baseline); B = outcome ~ first-half win pct + generation + making. Primary outcome: second-half point differential per game; secondary: second-half win pct. n is 15 (13), low power.", "")
  add(md_table(hr3 %>% transmute(population = pop_label[population], outcome = if_else(outcome == "sh_pd", "pd_per_game", "win_pct"),
                                  n = n_teams, rmse_A = f4(loo_rmse_A_record), rmse_Aprime = f4(loo_rmse_Aprime_pd),
                                  rmse_B = f4(loo_rmse_B_record_gen_mk), rmse_mean_only = f4(loo_rmse_mean_only),
                                  B_beats_A = B_beats_A, B_beats_Aprime = B_beats_Aprime)), "")
  add("Coefficients (OLS on all teams in the population; estimate, SE, p):", "")
  add(md_table(hr3c %>% filter(model %in% c("A", "B"), term != "(Intercept)") %>%
                 transmute(population = pop_label[population], outcome = if_else(outcome == "sh_pd", "pd_per_game", "win_pct"),
                           model, term, estimate = f4(estimate), se = f4(se), p = fp(p), r_squared = f3(r_squared))), "")
  for (p in c("all15", "no_trade13")) {
    x <- hr3 %>% filter(population == p)
    add(paste0("Verdict, ", pop_label[[p]], ": point differential per game, B ",
               ifelse(x$B_beats_A[x$outcome == "sh_pd"], "beats", "does not beat"), " A (", f3(x$loo_rmse_B_record_gen_mk[x$outcome == "sh_pd"]),
               " vs ", f3(x$loo_rmse_A_record[x$outcome == "sh_pd"]), "): **",
               ifelse(x$B_beats_A[x$outcome == "sh_pd"], "supported", "not supported"), "** on the primary outcome. Win pct, B ",
               ifelse(x$B_beats_A[x$outcome == "sh_win_pct"], "beats", "does not beat"), " A (", f4(x$loo_rmse_B_record_gen_mk[x$outcome == "sh_win_pct"]),
               " vs ", f4(x$loo_rmse_A_record[x$outcome == "sh_win_pct"]), ")."), "")
  }

  # H-R4
  add("## H-R4 (trajectory labels weak)", "",
      "Pre-registered: v1 improving/declining labels, most with intervals spanning zero, do not predict second-half direction better than chance. Expected null. Label = v1 shot-making trajectory in `output/deadline_read.csv`; outcome direction = sign of (second-half minus first-half making per 100). Exact two-sided binomial test vs 0.5. Rule: H-R4 is supported (null) unless agreement > 0.5 with p < 0.05.", "")
  add(md_table(hr4 %>% transmute(population = pop_label[population], subset, n = n_teams, agree = n_agree,
                                  agreement = f3(agreement), p_two_sided = f3(p_two_sided),
                                  ci_95 = paste0("[", f3(ci_low), ", ", f3(ci_high), "]"), verdict)), "")
  add("Per team:", "")
  add(md_table(hr4d %>% transmute(team, v1_label = trajectory, interval_spans_zero, making_first = f2(mk1),
                                   making_second = f2(mk2), change = f2(making_change), outcome_direction, agree)), "")
  add("LVA's change is +0.0003, so its outcome direction (improving) is set by a near-zero sign.", "")

  # H1, H2
  add("## H1, H2 on the full season", "",
      "Pre-registered: H1 (transition rises with reps) and H2 (chemistry proxies improve, strongest for TOR and PDX) were published v1 nulls; do they hold with twice the sample? League trend is the fixed effect of game_index (change per team game), two-sided normal p, from R/06's trajectory model. `fallback_used` TRUE means the random-slope model hit the singular or convergence fallback to random intercepts plus per-team residual slopes.", "")
  add(md_table(h12t %>% transmute(population = pop_label[population], window, metric, trend_per_game = fe(league_trend),
                                   p = f3(league_trend_p), fallback_used)), "")
  nfb <- h12t %>% filter(population == "all15", window == "full")
  add(paste0("With 44 games per team the random-slope model still falls back for ", sum(nfb$fallback_used), " of ", nrow(nfb),
             " of these four metrics (full window, all teams)."), "")
  add("TOR and PDX team slopes (per game, 95% interval):", "")
  add(md_table(h12m %>% transmute(population = pop_label[population], window, metric, team, slope = fe(slope),
                                   interval = paste0("[", fe(ci_low), ", ", fe(ci_high), "]"), trajectory, interval_spans_zero)), "")
  full_all <- h12t %>% filter(population == "all15", window == "full")
  add(paste0("Verdicts (rule: trend p < 0.05): ",
             paste0(full_all$metric, " p=", f3(full_all$league_trend_p), ifelse(full_all$league_trend_p < 0.05, " (significant)", " (null)"), collapse = "; "),
             ". TOR and PDX intervals span zero in every row above: ", ifelse(all(h12m$interval_spans_zero), "yes", "no"), "."), "")

  # H3
  add("## H3 (GSV making)", "",
      "Pre-registered: GSV's low FG% is making below expectation on an acceptable diet; GSV won the title, so report whether its making moved toward expectation. Per 100 possessions; percentile over the teams in the window (15 for regular-season windows, 8 for playoffs).", "")
  add(md_table(h3m %>% transmute(window, n_teams, generation = f2(shot_generation_per100), generation_pctile,
                                  making = f2(shot_making_per100), making_pctile)), "")
  add("GSV shot-making trajectory (R/06 slope per game, 95% interval):", "")
  add(md_table(h3t %>% transmute(window, slope = f4(slope), interval = paste0("[", f4(ci_low), ", ", f4(ci_high), "]"), trajectory, interval_spans_zero)), "")
  add("Playoffs rows are descriptive (13 games, 900 FGA).", "")

  # scorecard
  cnt <- table(factor(sc$verdict, levels = c("held", "partly held", "failed")))
  add("## v1 read scorecard", "",
      paste0("Held ", cnt[["held"]], ", partly held ", cnt[["partly held"]], ", failed ", cnt[["failed"]],
             " of 15. Rule: held if both the generation and making tiers (ntile(x, 3) over 15 teams, second-half window) are unchanged; partly held if exactly one tier changed by one step; failed otherwise. Trajectory outcome is reported separately (H-R4). Full table: `scorecard.md`, `scorecard.csv`."), "")
  add(md_table(sc %>% transmute(team, verdict, gen_v1_to_sh = paste0(v1_generation_tier, " to ", sh_generation_tier),
                                 mk_v1_to_sh = paste0(v1_making_tier, " to ", sh_making_tier), trade_flag)), "")
  add("Scorecard by trade flag:", "")
  add(md_table(sc %>% count(trade_flag, verdict) %>% pivot_wider(names_from = verdict, values_from = n, values_fill = 0) %>%
                 mutate(across(everything(), as.character))), "")

  # playoffs
  add("## Playoffs (descriptive, no tests)", "",
      "Regular-season full-window generation and making per 100 versus the playoffs window (own baselines, 8 teams). Playoff samples are small (126 to 900 FGA) and selected.", "")
  add(md_table(po %>% transmute(team, games = po_games, series_result, rs_gen = f2(rs_generation), po_gen = f2(po_generation),
                                 rs_making = f2(rs_making), po_making = f2(po_making), po_fga)), "")

  writeLines(L, file.path(REREAD_DIR, "reread_results.md"))

  S <- c("# v1 read scorecard", "",
         "Per team: the v1 deadline read (generation tier, making tier, trajectory, lever, recommendation, from `output/deadline_read.csv`) against the second-half window (games 183 to 330, own baseline, ntile(x, 3) over 15 teams as in v1). Verdict: held = both tiers unchanged; partly held = exactly one tier changed by one step; failed = otherwise. Trajectory outcome (agree/disagree) compares the v1 shot-making label with the sign of the second-half minus first-half making change; it is not part of the verdict. Tier 1 = low, 3 = high.", "",
         md_table(sc %>% transmute(team, verdict, gen_tier_v1 = v1_generation_tier, gen_tier_sh = sh_generation_tier, gen_pctile_sh = sh_generation_pctile,
                                    mk_tier_v1 = v1_making_tier, mk_tier_sh = sh_making_tier, mk_pctile_sh = sh_making_pctile,
                                    v1_trajectory, spans_zero = v1_interval_spans_zero, trajectory_outcome,
                                    v1_lever, trade_flag, sh_record, sh_pd_per_game = f2(sh_pd_per_game), final_record, final_rank)), "",
         "v1 recommendations (text from deadline_read.csv):", "",
         paste0("- ", sc$team, " (", sc$verdict, "): ", gsub("\\s+", " ", sc$v1_recommendation)))
  writeLines(S, file.path(REREAD_DIR, "scorecard.md"))
  message("Wrote reread_results.md and scorecard.md")
}

if (sys.nframe() == 0) main()
