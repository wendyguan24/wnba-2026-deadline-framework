# Full-season re-read of v1: results

Hypotheses and predicted directions pre-registered in b0c3c80. Decision rules were specified in the execution plan (docs/plans/reread_plan.md) before any second-half output was computed, but first committed with the code at cd66cc0.

Regular season only for all hypotheses; playoffs are descriptive. Each window (first half = games 1 to 182, the v1 sample; second half = games 183 to 330; full = 330) computes its own stratified expected-points baseline and its own identity models, as v1 did. Registered hypotheses: H-R1 to H-R4, H1, H2, H3 (PLAN.md, commit b0c3c80); none were added. Everything not in that registry sits in a section labeled EXPLORATORY and never changes a verdict. Regenerate with the run order in `README.md` (windows, then `R/15a_regression_check.R`, `R/15_reread.R`, `R/15b_reread_report.R`).

## Setup and caveats

- n = 15 teams (13 without roster-turnover-flagged teams). Spearman and leave-one-out comparisons at this n have very low power; bootstrap intervals are over teams (2,000 resamples, seed 20261123, percentile).
- First-half regression check against the committed v1 outputs: see `regression_check_v1.md` (max abs diff 0 across the five files; all pass: TRUE).
- Own-window baselines: each window's expected points are league averages within that window, so team generation and making are relative to that window's league. A league-wide shift between halves is removed by construction. The full-window alternative is in the EXPLORATORY sensitivity below.
- Roster-turnover flag: a team is flagged when players who appear for 2+ teams account for at least 10 percent of its first-half minutes (players who left) or second-half minutes (players who arrived). The flag marks roster turnover over the whole season, not only deadline trades. Flagged teams: LAS, PHX. The "without flag" population drops them. Moves are in `player_moves.csv` (11 of 22 moves have a first game for the new team within 2026-07-26 to 2026-08-09 or a gap spanning the Aug 2 deadline).
- Trajectory refits for the without-flag population (H1, H2) keep rows of non-flagged teams as the modeled team and all teams as opponents.
- Playoffs: R/06 mixed models were not run for the playoffs window (8 teams, 2 to 13 games each); R/05 and R/07 only.
- Scope of the second-half window: the full regular-season window overlaps v1 (the 182 v1 games are 182 of 330 games); full-window results are not out-of-sample.
- Metric scales differ by test: H-R1 uses schedule-adjusted BLUPs from R/06, H-R2 uses raw per100 team values from R/07 (no opponent adjustment). The two are not directly comparable.
- Fallback inference: where `fallback_used` is TRUE (see H1, H2), R/06 fits random intercepts only and takes the league trend p-value from that model. It ignores team-specific slope variance, so its standard error is too small and its p-values are anticonservative. Team slopes in those rows are per-team OLS slopes of residuals, not model-based intervals.
- Not controlled: injuries and player availability. Not assessed: cap feasibility of the constrained acquire reads (parked in PLAN.md).
- Schedule: the v1 read cited a late-August World Cup break; schedule effects are not modeled. The longest league-wide gap between second-half game dates is 18 days (2026-08-30 to 2026-09-17).
- Regular season is 44 games per team.

### Roster-turnover flags

| team | minutes_share_out | minutes_share_in | n_players_out | n_players_in | roster_turnover_flag |
|---|---|---|---|---|---|
| ATL | 0.004 | 0.035 | 3 | 2 | FALSE |
| CHI | 0.015 | 0.006 | 3 | 1 | FALSE |
| CON | 0.080 | 0.000 | 1 | 0 | FALSE |
| DAL | 0.000 | 0.031 | 0 | 2 | FALSE |
| GSV | 0.003 | 0.000 | 1 | 0 | FALSE |
| IND | 0.001 | 0.005 | 1 | 1 | FALSE |
| LAS | 0.145 | 0.070 | 4 | 4 | TRUE |
| LVA | 0.000 | 0.014 | 0 | 1 | FALSE |
| MIN | 0.000 | 0.015 | 0 | 1 | FALSE |
| NYL | 0.059 | 0.011 | 1 | 1 | FALSE |
| PDX | 0.025 | 0.013 | 2 | 1 | FALSE |
| PHX | 0.222 | 0.122 | 4 | 4 | TRUE |
| SEA | 0.009 | 0.008 | 1 | 1 | FALSE |
| TOR | 0.012 | 0.049 | 1 | 2 | FALSE |
| WAS | 0.000 | 0.048 | 0 | 1 | FALSE |

## H-R1 (identity stable)

Hypothesis: the ICC >= 0.15 identity-anchor metrics rank teams similarly in the second half as in the first. Predicted direction: Spearman >= 0.7 for most anchor metrics. Decision rule: supported if rho >= 0.7 for more than half of the anchor metrics. Anchor metrics are those with ICC >= 0.15 in the v1 icc_table (8 metrics). Team scores are schedule-adjusted BLUPs from each window.

**all 15 teams**: median rho 0.796; rho >= 0.7 for 5 of 8 metrics. Verdict: **supported**. The verdict flips if one more metric drops below 0.7.

| metric | v1_icc | rho | ci_95 |
|---|---|---|---|
| mid_share | 0.530 | 0.893 | [0.634, 0.989] |
| fg3a_rate | 0.359 | 0.857 | [0.593, 0.953] |
| atb3_share | 0.309 | 0.854 | [0.581, 0.945] |
| pullup_share | 0.285 | 0.743 | [0.333, 0.936] |
| ra_share | 0.262 | 0.850 | [0.523, 0.956] |
| driving_share | 0.219 | 0.564 | [-0.047, 0.907] |
| paint_fgm_share | 0.219 | 0.696 | [0.236, 0.952] |
| transition_share | 0.181 | 0.586 | [0.059, 0.895] |

**13 teams without roster-turnover flag**: median rho 0.824; rho >= 0.7 for 6 of 8 metrics. Verdict: **supported**. The verdict does not flip if one more metric drops below 0.7.

| metric | v1_icc | rho | ci_95 |
|---|---|---|---|
| mid_share | 0.530 | 0.885 | [0.591, 0.994] |
| fg3a_rate | 0.359 | 0.901 | [0.643, 0.983] |
| atb3_share | 0.309 | 0.857 | [0.559, 0.955] |
| pullup_share | 0.285 | 0.720 | [0.207, 0.913] |
| ra_share | 0.262 | 0.846 | [0.486, 0.950] |
| driving_share | 0.219 | 0.687 | [0.102, 0.955] |
| paint_fgm_share | 0.219 | 0.802 | [0.341, 0.983] |
| transition_share | 0.181 | 0.566 | [-0.076, 0.921] |

## H-R2 (generation holds, making regresses)

Hypothesis: first-half shot generation predicts second-half generation better than first-half making predicts second-half making. Predicted direction: generation rho > making rho; sharpest case LVA (making falls in the second half). Decision rule: supported if generation rho > making rho and the bootstrap CI of the difference excludes 0; directionally consistent if greater but the CI spans 0. Uses raw per100 team values (see caveat on metric scales).

| population | n | rho_generation | gen_ci | rho_making | mk_ci | diff_gen_minus_mk | diff_ci | verdict |
|---|---|---|---|---|---|---|---|---|
| all 15 teams | 15 | 0.429 | [-0.191, 0.852] | 0.754 | [0.302, 0.948] | -0.325 | [-0.961, 0.317] | not supported |
| 13 teams without roster-turnover flag | 13 | 0.390 | [-0.335, 0.881] | 0.703 | [0.134, 0.928] | -0.313 | [-1.096, 0.418] | not supported |

Verdict: all 15 teams not supported; 13 teams without roster-turnover flag not supported. Making ranks were more stable than generation ranks in both populations, the opposite of the predicted direction.

LVA (not flagged), per 100 possessions:

| window | generation | generation_pctile | making | making_pctile |
|---|---|---|---|---|
| first_half | 81.57 | 7 | 9.45 | 100 |
| second_half | 83.98 | 7 | 9.45 | 100 |
| full | 82.71 | 7 | 9.41 | 100 |

LVA making change, second half minus first half: +0.0003 per 100; percentile 100 to 100. Predicted direction (making falls): not met (the change is within the 0.01 per100 tie tolerance, so making did not move).

### EXPLORATORY: why generation is less stable than making (H-R2 decomposition)

Not in the registry; does not change the H-R2 verdict. Expected points per FGA (diet = expected_pts / fga) and FGA per possession (volume = fga / poss_count) are tracked separately next to generation per100 and making per100, with Spearman first half vs second half and the same team bootstrap. Generation per100 combines diet and volume (generation per100 = 100 x diet x volume).

| population | measure | n | rho | ci_95 |
|---|---|---|---|---|
| all 15 teams | diet | 15 | 0.911 | [0.703, 0.989] |
| all 15 teams | volume | 15 | 0.689 | [0.286, 0.931] |
| all 15 teams | generation | 15 | 0.429 | [-0.191, 0.852] |
| all 15 teams | making | 15 | 0.754 | [0.302, 0.948] |
| 13 teams without roster-turnover flag | diet | 13 | 0.912 | [0.689, 1.000] |
| 13 teams without roster-turnover flag | volume | 13 | 0.648 | [0.137, 0.927] |
| 13 teams without roster-turnover flag | generation | 13 | 0.390 | [-0.335, 0.881] |
| 13 teams without roster-turnover flag | making | 13 | 0.703 | [0.134, 0.928] |

All 15 teams: diet rho 0.911, volume rho 0.689, generation rho 0.429, making rho 0.754. Diet is more stable than volume, so the weaker link in generation per100 is volume (FGA per possession), not shot diet. Generation per100 is less stable than either component, so changes in diet and volume partly offset each way in the product.

### EXPLORATORY: sensitivity to the baseline window

Both halves scored with one baseline built on the full regular-season window (330 games), then generation and making per100 recomputed and the H-R2 rhos redone. Written to `sensitivity_full_baseline.csv`. The full window includes both halves, so this baseline is not independent of either. Does not change the H-R2 verdict.

| baseline | population | n | rho_generation | rho_making | diff_gen_minus_mk | diff_ci | verdict |
|---|---|---|---|---|---|---|---|
| own_window (main) | all 15 teams | 15 | 0.429 | 0.754 | -0.325 | [-0.961, 0.317] | not supported |
| own_window (main) | 13 teams without roster-turnover flag | 13 | 0.390 | 0.703 | -0.313 | [-1.096, 0.418] | not supported |
| full_window | all 15 teams | 15 | 0.464 | 0.754 | -0.289 | [-0.946, 0.342] | not supported |
| full_window | 13 teams without roster-turnover flag | 13 | 0.390 | 0.703 | -0.313 | [-1.096, 0.418] | not supported |

## H-R3 (reads beyond the record)

Hypothesis: first-half generation and making add information about second-half results beyond first-half record. Both outcomes (second-half point differential per game and second-half win pct) are treated as equal; neither is primary. Decision rule: supported if model B beats model A on leave-one-out RMSE for both outcomes; not supported if it beats it for neither; mixed / inconclusive otherwise. A = outcome ~ first-half win pct; B = outcome ~ first-half win pct + generation + making. The alternative baseline A' (outcome ~ first-half point differential per game) is EXPLORATORY and is shown for context only. n is 15 (13), low power.

| population | outcome | n | rmse_A | rmse_B | rmse_mean_only | B_beats_A | rmse_Aprime_alt_baseline_pd_EXPLORATORY | B_beats_Aprime_EXPLORATORY |
|---|---|---|---|---|---|---|---|---|
| all 15 teams | pd_per_game | 15 | 5.1919 | 5.9393 | 8.3946 | FALSE | 5.6548 | FALSE |
| all 15 teams | win_pct | 15 | 0.1652 | 0.1637 | 0.2607 | TRUE | 0.1710 | TRUE |
| 13 teams without roster-turnover flag | pd_per_game | 13 | 5.4304 | 5.9722 | 9.0060 | FALSE | 6.0979 | TRUE |
| 13 teams without roster-turnover flag | win_pct | 13 | 0.1703 | 0.1586 | 0.2738 | TRUE | 0.1868 | TRUE |

Coefficients (OLS on all teams in the population; estimate, SE, p):

| population | outcome | model | term | estimate | se | p | r_squared |
|---|---|---|---|---|---|---|---|
| all 15 teams | pd_per_game | A | fh_win_pct | 38.0254 | 7.7578 | <0.001 | 0.649 |
| all 15 teams | pd_per_game | B | fh_win_pct | 51.5048 | 10.5470 | <0.001 | 0.732 |
| all 15 teams | pd_per_game | B | generation | -0.4659 | 0.4564 | 0.329 | 0.732 |
| all 15 teams | pd_per_game | B | making | -0.6687 | 0.3629 | 0.092 | 0.732 |
| all 15 teams | win_pct | A | fh_win_pct | 1.1565 | 0.2498 | <0.001 | 0.622 |
| all 15 teams | win_pct | B | fh_win_pct | 1.7529 | 0.2927 | <0.001 | 0.786 |
| all 15 teams | win_pct | B | generation | -0.0223 | 0.0127 | 0.106 | 0.786 |
| all 15 teams | win_pct | B | making | -0.0290 | 0.0101 | 0.015 | 0.786 |
| 13 teams without roster-turnover flag | pd_per_game | A | fh_win_pct | 40.2448 | 8.5194 | <0.001 | 0.670 |
| 13 teams without roster-turnover flag | pd_per_game | B | fh_win_pct | 54.7967 | 11.3296 | <0.001 | 0.763 |
| 13 teams without roster-turnover flag | pd_per_game | B | generation | -0.3975 | 0.4723 | 0.422 | 0.763 |
| 13 teams without roster-turnover flag | pd_per_game | B | making | -0.7121 | 0.3787 | 0.093 | 0.763 |
| 13 teams without roster-turnover flag | win_pct | A | fh_win_pct | 1.1965 | 0.2704 | 0.001 | 0.640 |
| 13 teams without roster-turnover flag | win_pct | B | fh_win_pct | 1.8089 | 0.3088 | <0.001 | 0.810 |
| 13 teams without roster-turnover flag | win_pct | B | generation | -0.0200 | 0.0129 | 0.154 | 0.810 |
| 13 teams without roster-turnover flag | win_pct | B | making | -0.0292 | 0.0103 | 0.020 | 0.810 |

Verdict, all 15 teams: **mixed / inconclusive**: no gain on point differential (B vs A LOO RMSE 5.939 vs 5.192, change +14.4%), gain on win pct (0.1637 vs 0.1652, RMSE change -0.9%).

Paired per-team LOO squared-error difference (B minus A; negative favors B): point differential mean 8.319 [-2.743, 20.698]; win pct mean -0.0005 [-0.010, 0.008] (team bootstrap, 2,000 resamples, seed 20261123). Intervals span zero: both outcomes.

Verdict, 13 teams without roster-turnover flag: **mixed / inconclusive**: no gain on point differential (B vs A LOO RMSE 5.972 vs 5.430, change +10.0%), gain on win pct (0.1586 vs 0.1703, RMSE change -6.9%).

Paired per-team LOO squared-error difference (B minus A; negative favors B): point differential mean 6.177 [-5.886, 16.793]; win pct mean -0.0039 [-0.015, 0.006] (team bootstrap, 2,000 resamples, seed 20261123). Intervals span zero: both outcomes.

Making coefficient in model B is negative for both outcomes and both populations (all 15 teams: point differential -0.669, win pct -0.029). A negative sign is the regression-to-the-mean reading: conditional on record, a team whose first half included more shot making above expectation did worse afterward, because above-expectation making partly reverts. It does not say making is bad for results. The fh_win_pct coefficient moves from 1.157 in A to 1.753 in B (win pct outcome, all 15 teams), which fits collinearity: first-half win pct correlates 0.565 with making and 0.283 with generation (all 15 teams).

## H-R4 (trajectory labels weak)

Hypothesis: v1 improving/declining labels, most with intervals spanning zero, do not predict second-half direction better than chance. Expected null. Label = v1 shot-making trajectory in `output/deadline_read.csv`, a within-first-half slope; outcome direction = sign of the level change (second-half minus first-half making per 100). These are different quantities, so disagreement is not a contradiction of the slope. Changes with |delta| < 0.01 per100 count as ties and are excluded from the test. Exact two-sided binomial test vs 0.5. Decision rule: null supported unless agreement > 0.5 with p < 0.05.

| population | subset | n | ties_excluded | agree | agreement | p_two_sided | ci_95 | verdict |
|---|---|---|---|---|---|---|---|---|
| all 15 teams | all_labels | 14 | 1 | 6 | 0.429 | 0.791 | [0.177, 0.711] | supported (null) |
| all 15 teams | interval_excludes_zero | 2 | 0 | 1 | 0.500 | 1.000 | [0.013, 0.987] | supported (null) |
| 13 teams without roster-turnover flag | all_labels | 12 | 1 | 5 | 0.417 | 0.774 | [0.152, 0.723] | supported (null) |
| 13 teams without roster-turnover flag | interval_excludes_zero | 2 | 0 | 1 | 0.500 | 1.000 | [0.013, 0.987] | supported (null) |

Per team:

| team | v1_label | interval_spans_zero | making_first | making_second | change | outcome_direction | agree |
|---|---|---|---|---|---|---|---|
| LVA | declining | TRUE | 9.45 | 9.45 | 0.00 | tie | NA |
| NYL | declining | TRUE | 3.65 | 1.59 | -2.06 | declining | TRUE |
| PHX | improving | TRUE | -0.72 | -0.17 | 0.55 | improving | TRUE |
| SEA | improving | TRUE | -2.06 | -7.07 | -5.01 | declining | FALSE |
| WAS | declining | FALSE | -6.73 | 1.49 | 8.21 | improving | FALSE |
| IND | improving | FALSE | 4.69 | 8.96 | 4.28 | improving | TRUE |
| LAS | declining | TRUE | 1.03 | 1.79 | 0.76 | improving | FALSE |
| PDX | declining | TRUE | -0.68 | 0.91 | 1.59 | improving | FALSE |
| TOR | improving | TRUE | 1.00 | -7.80 | -8.80 | declining | FALSE |
| ATL | declining | TRUE | -7.79 | -4.32 | 3.47 | improving | FALSE |
| CHI | improving | TRUE | -5.54 | -4.85 | 0.69 | improving | TRUE |
| CON | improving | TRUE | -6.35 | -8.06 | -1.71 | declining | FALSE |
| DAL | improving | TRUE | 3.35 | 5.95 | 2.60 | improving | TRUE |
| GSV | improving | TRUE | 0.65 | -0.02 | -0.66 | declining | FALSE |
| MIN | declining | TRUE | 4.70 | 4.22 | -0.48 | declining | TRUE |

Ties excluded: LVA (change +0.0003 per100).

## H1, H2 on the full season

Hypothesis: H1 (transition rises with reps) and H2 (chemistry proxies improve, strongest for TOR and PDX) were published v1 nulls; do they hold with twice the sample? League trend is the fixed effect of game_index (change per team game), two-sided normal p, from R/06's trajectory model. `fallback_used` TRUE means the random-slope model hit the singular or convergence fallback to random intercepts plus per-team residual slopes (anticonservative p-values; see caveats). Decision rule: trend p < 0.05.

| population | window | metric | trend_per_game | p | fallback_used |
|---|---|---|---|---|---|
| all 15 teams | first_half (v1 sample) | transition_share | -8.23e-05 | 0.729 | TRUE |
| all 15 teams | first_half (v1 sample) | transition_pts_per_poss | 3.81e-03 | 0.214 | TRUE |
| all 15 teams | first_half (v1 sample) | assisted_rate | -2.11e-04 | 0.772 | TRUE |
| all 15 teams | first_half (v1 sample) | live_ball_tov_rate | 2.18e-04 | 0.364 | TRUE |
| all 15 teams | second_half | transition_share | 6.94e-04 | 0.040 | TRUE |
| all 15 teams | second_half | transition_pts_per_poss | -6.17e-03 | 0.152 | TRUE |
| all 15 teams | second_half | assisted_rate | 5.22e-04 | 0.581 | FALSE |
| all 15 teams | second_half | live_ball_tov_rate | 7.07e-04 | 0.039 | TRUE |
| all 15 teams | full | transition_share | 2.11e-05 | 0.833 | TRUE |
| all 15 teams | full | transition_pts_per_poss | -6.76e-04 | 0.600 | TRUE |
| all 15 teams | full | assisted_rate | 4.77e-04 | 0.099 | TRUE |
| all 15 teams | full | live_ball_tov_rate | 2.90e-05 | 0.820 | FALSE |
| 13 teams without roster-turnover flag | full | transition_share | -2.70e-05 | 0.799 | TRUE |
| 13 teams without roster-turnover flag | full | transition_pts_per_poss | -2.01e-04 | 0.886 | TRUE |
| 13 teams without roster-turnover flag | full | assisted_rate | 2.31e-04 | 0.456 | TRUE |
| 13 teams without roster-turnover flag | full | live_ball_tov_rate | 1.12e-05 | 0.940 | FALSE |

Random-slope fallback used for these four metrics (all 15 teams): first half 4 of 4, second half 3 of 4, full 3 of 4 (44 games per team in the full window).

TOR and PDX team slopes (per game, 95% interval). `interval_type` differs by row: `residual_OLS_slope` rows are per-team OLS slopes of residuals from the fallback model; `random_slope_posterior` rows are posterior intervals from the random-slope model. Compare within a type only.

| population | window | metric | team | slope | interval | interval_type | trajectory | interval_spans_zero |
|---|---|---|---|---|---|---|---|---|
| all 15 teams | first_half (v1 sample) | assisted_rate | PDX | 3.38e-03 | [-2.45e-03, 9.21e-03] | residual_OLS_slope | improving | TRUE |
| all 15 teams | first_half (v1 sample) | assisted_rate | TOR | 4.86e-03 | [-8.63e-04, 1.06e-02] | residual_OLS_slope | improving | TRUE |
| all 15 teams | first_half (v1 sample) | live_ball_tov_rate | PDX | 6.66e-04 | [-1.48e-03, 2.81e-03] | residual_OLS_slope | improving | TRUE |
| all 15 teams | first_half (v1 sample) | live_ball_tov_rate | TOR | 2.46e-04 | [-1.34e-03, 1.84e-03] | residual_OLS_slope | improving | TRUE |
| all 15 teams | full | assisted_rate | PDX | 8.45e-05 | [-2.38e-03, 2.55e-03] | residual_OLS_slope | improving | TRUE |
| all 15 teams | full | assisted_rate | TOR | 3.16e-04 | [-1.89e-03, 2.52e-03] | residual_OLS_slope | improving | TRUE |
| all 15 teams | full | live_ball_tov_rate | PDX | -1.16e-04 | [-5.66e-04, 3.34e-04] | random_slope_posterior | declining | TRUE |
| all 15 teams | full | live_ball_tov_rate | TOR | 2.88e-04 | [-1.61e-04, 7.37e-04] | random_slope_posterior | improving | TRUE |
| 13 teams without roster-turnover flag | full | assisted_rate | PDX | 1.65e-04 | [-2.32e-03, 2.65e-03] | residual_OLS_slope | improving | TRUE |
| 13 teams without roster-turnover flag | full | assisted_rate | TOR | 2.32e-04 | [-1.97e-03, 2.43e-03] | residual_OLS_slope | improving | TRUE |
| 13 teams without roster-turnover flag | full | live_ball_tov_rate | PDX | -1.73e-04 | [-6.79e-04, 3.32e-04] | random_slope_posterior | declining | TRUE |
| 13 teams without roster-turnover flag | full | live_ball_tov_rate | TOR | 3.61e-04 | [-1.43e-04, 8.65e-04] | random_slope_posterior | improving | TRUE |

Verdicts (full window, all 15 teams, rule p < 0.05): transition_share p=0.833 (null); transition_pts_per_poss p=0.600 (null); assisted_rate p=0.099 (null); live_ball_tov_rate p=0.820 (null). TOR and PDX intervals span zero in every row above: yes.

Second-half league-trend rows are shown for reference and are not the registered full-season test. 2 of 4 second-half metrics have p < 0.05 (transition_share p=0.040, fallback_used TRUE; live_ball_tov_rate p=0.039, fallback_used TRUE); with fallback p-values anticonservative and several metrics tested on one half, these are not treated as findings and change no verdict. Per-team TOR and PDX slopes for the second half were not produced.

## H3 (GSV making)

Hypothesis: GSV's low FG% is making below expectation on an acceptable diet; GSV won the title, so report whether its making moved toward expectation. Per 100 possessions; percentile over the teams in the window (15 for regular-season windows, 8 for playoffs).

| window | n_teams | generation | generation_pctile | making | making_pctile |
|---|---|---|---|---|---|
| first_half | 15 | 86.30 | 71 | 0.65 | 50 |
| second_half | 15 | 90.67 | 79 | -0.02 | 43 |
| full | 15 | 88.29 | 86 | 0.24 | 57 |
| playoffs | 8 | 83.83 | 86 | -3.40 | 29 |

GSV shot-making trajectory (R/06 slope per game, 95% interval):

| window | slope | interval | trajectory | interval_spans_zero |
|---|---|---|---|---|
| first_half (v1 sample) | 0.2513 | [-0.3007, 0.8033] | improving | TRUE |
| full | 0.0442 | [-0.2073, 0.2956] | improving | TRUE |

Verdict line: premise not supported in either half (first-half making 0.65, second-half -0.02 per 100, neither meaningfully below zero); making near zero throughout (full window 0.24); playoff -3.40 descriptive (GSV, 13 games, 900 FGA).

## EXPLORATORY: v1 read scorecard (descriptor stability, not advice outcome)

Not in the registry; no verdict above depends on it. Tiers follow v1 (ntile(x, 3) over 15 teams, second-half window). Held if both generation and making tiers are unchanged; partly held if exactly one tier changed by one step; failed otherwise. Main counts: held 7, partly held 3, failed 5 of 15. 12 teams are boundary_sensitive (rank adjacent to a tier boundary in either half on either axis). Under one-rank swaps the counts range over: held 2 to 9, partly held 1 to 12, failed 1 to 5 (each team's tiers varied independently, so the range is conservative; the lower bound counts teams whose verdict cannot change).

Chance benchmarks: if tiers were unrelated across halves, P(held) = 1/9 = 0.111, an expected 1.67 of 15 teams. Record-tertile benchmark: the same tertile rule applied to first-half vs second-half win pct (ties broken by point differential per game) keeps 7 of 15 teams in the same record tier (chance for one axis is 1/3, an expected 5.00). The scorecard uses two axes, so its chance rate is lower than the benchmark's.

Percentiles and changes (second half minus v1):

| team | verdict | boundary_sensitive | verdicts_possible | gen_tier | gen_pctile | mk_tier | mk_pctile | roster_turnover_flag |
|---|---|---|---|---|---|---|---|---|
| ATL | held | TRUE | held or partly held | 3 to 3 | 100 to 100 (+0) | 1 to 1 | 0 to 29 (+29) | FALSE |
| GSV | held | TRUE | held or partly held | 3 to 3 | 71 to 79 (+8) | 2 to 2 | 50 to 43 (-7) | FALSE |
| IND | held | TRUE | held or partly held | 2 to 2 | 36 to 43 (+7) | 3 to 3 | 86 to 93 (+7) | FALSE |
| LVA | held | FALSE | held | 1 to 1 | 7 to 7 (+0) | 3 to 3 | 100 to 100 (+0) | FALSE |
| MIN | held | FALSE | held | 3 to 3 | 86 to 93 (+7) | 3 to 3 | 93 to 79 (-14) | FALSE |
| PDX | held | TRUE | held or partly held | 2 to 2 | 64 to 50 (-14) | 2 to 2 | 43 to 50 (+7) | FALSE |
| PHX | held | TRUE | held or partly held | 1 to 1 | 21 to 0 (-21) | 2 to 2 | 36 to 36 (+0) | TRUE |
| CHI | partly held | TRUE | held or partly held | 3 to 2 | 79 to 64 (-15) | 1 to 1 | 21 to 21 (+0) | FALSE |
| CON | partly held | TRUE | held or partly held | 2 to 1 | 57 to 29 (-28) | 1 to 1 | 14 to 0 (-14) | FALSE |
| TOR | partly held | FALSE | partly held | 2 to 2 | 50 to 57 (+7) | 2 to 1 | 57 to 7 (-50) | FALSE |
| DAL | failed | TRUE | failed | 3 to 1 | 93 to 14 (-79) | 3 to 3 | 71 to 86 (+15) | FALSE |
| LAS | failed | TRUE | failed or partly held | 2 to 1 | 43 to 21 (-22) | 2 to 3 | 64 to 71 (+7) | TRUE |
| NYL | failed | TRUE | failed or partly held | 1 to 3 | 14 to 71 (+57) | 3 to 2 | 79 to 64 (-15) | FALSE |
| SEA | failed | TRUE | failed or partly held | 1 to 3 | 29 to 86 (+57) | 1 to 1 | 29 to 14 (-15) | FALSE |
| WAS | failed | TRUE | failed or partly held | 1 to 2 | 0 to 36 (+36) | 1 to 2 | 7 to 57 (+50) | FALSE |

Scorecard by roster-turnover flag:

| roster_turnover_flag | failed | held | partly held |
|---|---|---|---|
| FALSE | 4 | 6 | 3 |
| TRUE | 1 | 1 | 0 |

## EXPLORATORY: advice outcome

Not in the registry; separate from every hypothesis verdict. Windows (buyer, bubble, seller) come from v1 record plus margin, so a buyer is by construction a team already winning; the outcome checks the label more than any model read.

Scoring rules: seller right if the team missed the playoffs; buyer right if it made them; bubble "lean buy" right if second-half win pct >= .500; bubble "lean hold or sell" right if second-half win pct < .500 (a two-way call: hold and sell are not separated, so it is scored on the below-.500 side only); LAS and PHX carry the roster-turnover flag and are not scored.

Deadline action rule: a move counts if the new team's first game is 2026-07-20 to 2026-08-02 inclusive, or the gap between the player's last game for the old team and first game for the new team contains 2026-08-02 and is at most 14 days (the plan's date window applied to observable game dates; the trade date itself is not in the data). Each move is valued by the player's second-half minutes with the new team. Net = minutes in minus minutes out, as a share of the team's second-half minutes; bought if >= +2 percent, sold if <= -2 percent, otherwise stood pat. The 2 percent threshold is a descriptive choice. Moves with long gaps that do not meet the rule (for example players who sat out for weeks) are not counted.

| team | window | v1_read | deadline_action | net_minutes_share | second_half_record | playoff_result | advice_outcome |
|---|---|---|---|---|---|---|---|
| DAL | buyer | amplify | stood pat | +0.000 | 11-9 | lost in series 1 | right |
| GSV | buyer | amplify | stood pat | +0.000 | 14-5 | won title | right |
| IND | buyer | adjust | stood pat | +0.000 | 14-6 | lost in series 1 | right |
| LVA | buyer | reassess | stood pat | +0.014 | 14-6 | lost in series 2 | right |
| MIN | buyer | amplify | stood pat | +0.000 | 14-5 | lost in series 1 | right |
| ATL | bubble | judgment (lean hold or sell) | stood pat | +0.000 | 16-4 | lost Finals | wrong |
| NYL | bubble | judgment (lean hold or sell) | stood pat | +0.000 | 13-7 | lost in series 2 | wrong |
| TOR | bubble | judgment (lean buy) | bought | +0.034 | 1-19 | missed playoffs | wrong |
| WAS | bubble | judgment (lean hold or sell) | stood pat | +0.000 | 16-5 | lost in series 1 | wrong |
| CHI | seller | sell / accumulate | stood pat | +0.000 | 8-12 | missed playoffs | right |
| CON | seller | sell / accumulate | sold | -0.034 | 5-15 | missed playoffs | right |
| LAS | seller | sell / accumulate | bought | +0.036 | 6-15 | missed playoffs | not scored |
| PDX | seller | sell / accumulate | stood pat | +0.000 | 6-13 | missed playoffs | right |
| PHX | seller | sell / accumulate | sold | -0.055 | 8-11 | missed playoffs | not scored |
| SEA | seller | sell / accumulate | stood pat | +0.000 | 2-16 | missed playoffs | right |

Counts by window:

| window | right | wrong | not scored |
|---|---|---|---|
| buyer | 5 | 0 | 0 |
| bubble | 0 | 4 | 0 |
| seller | 4 | 0 | 2 |

Right 9, wrong 4, not scored 2 of 15. Deadline action counts: bought 2, sold 2, stood pat 11.

## Playoffs (descriptive, no tests)

Regular-season full-window generation and making per 100 versus the playoffs window (own baselines, 8 teams). Playoff samples are small (126 to 900 FGA) and selected. The rs and po columns are not on a common baseline (each is relative to its own window's league), so no difference column is computed.

| team | games | series_result | rs_gen | po_gen | rs_making | po_making | po_fga |
|---|---|---|---|---|---|---|---|
| GSV | 13 | won 2-1 vs DAL; won 3-0 vs LVA; won 4-3 vs ATL | 88.29 | 83.83 | 0.24 | -3.40 | 900 |
| ATL | 12 | won 2-0 vs WAS; won 3-0 vs NYL; lost 4-3 vs GSV | 94.11 | 81.67 | -6.31 | -4.13 | 812 |
| LVA | 6 | won 2-1 vs IND; lost 3-0 vs GSV | 82.71 | 70.68 | 9.41 | 7.01 | 374 |
| NYL | 5 | won 2-0 vs MIN; lost 3-0 vs ATL | 85.59 | 77.56 | 2.62 | 13.15 | 321 |
| DAL | 3 | lost 2-1 vs GSV | 87.75 | 69.94 | 4.38 | 13.04 | 183 |
| IND | 3 | lost 2-1 vs LVA | 85.72 | 86.19 | 6.54 | 4.09 | 216 |
| MIN | 2 | lost 2-0 vs NYL | 89.80 | 80.78 | 4.29 | -0.13 | 135 |
| WAS | 2 | lost 2-0 vs ATL | 83.77 | 71.81 | -2.90 | -3.74 | 126 |

