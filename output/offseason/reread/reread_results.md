# Full-season re-read of v1: results

Regular season only for all hypotheses; playoffs are descriptive. Each window (first half = games 1 to 182, the v1 sample; second half = games 183 to 330; full = 330) computes its own stratified expected-points baseline and its own identity models, as v1 did. Hypotheses are the pre-registered H-R1 to H-R4, H1, H2, H3 (PLAN.md, commit b0c3c80); none were added. Regenerate with `Rscript R/15_reread.R && Rscript R/15b_reread_report.R`.

## Setup and caveats

- n = 15 teams (13 without trade-flagged teams). Spearman and leave-one-out comparisons at this n have very low power; bootstrap intervals are over teams (2,000 resamples, seed 20261123, percentile).
- First-half regression check against the committed v1 outputs: see `regression_check_v1.md` (max abs diff 0 in all five files).
- Own-window baselines: each window's expected points are league averages within that window, so team generation and making are relative to that window's league. A league-wide shift between halves is removed by construction.
- Trade flags: a team is flagged when players who appear for 2+ teams account for at least 10 percent of its first-half minutes (players who left) or second-half minutes (players who arrived). Flagged teams: LAS, PHX. The "no trade" population drops them. Moves are in `player_moves.csv` (11 of 22 moves have a first game for the new team within 2026-07-26 to 2026-08-09 or a gap spanning the Aug 2 deadline).
- Trajectory refits for the no-trade population (H1, H2) keep rows of non-flagged teams as the modeled team and all teams as opponents.
- Playoffs: R/06 mixed models were not run for the playoffs window (8 teams, 2 to 13 games each); R/05 and R/07 only.
- Game 7 ESPN gap is irrelevant here (our own pbp has the game).

### Trade flags

| team | minutes_share_out | minutes_share_in | n_players_out | n_players_in | trade_flag |
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

Pre-registered: the ICC >= 0.15 identity-anchor metrics rank teams similarly in the second half as in the first. Prediction: Spearman >= 0.7 for most anchor metrics. Rule: supported if rho >= 0.7 for more than half of the anchor metrics. Anchor metrics are those with ICC >= 0.15 in the v1 icc_table (8 metrics). Team scores are schedule-adjusted BLUPs from each window.

**all 15 teams**

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

Metrics with rho >= 0.7: 5 of 8; median rho 0.796. Verdict: **supported**.

**13 teams without trade flag**

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

Metrics with rho >= 0.7: 6 of 8; median rho 0.824. Verdict: **supported**.

## H-R2 (generation holds, making regresses)

Pre-registered: first-half shot generation predicts second-half generation better than first-half making predicts second-half making. Sharpest case: LVA (generation 7th percentile, making 100th, declining) sees making fall in the second half. Rule: supported if generation rho > making rho and the bootstrap CI of the difference excludes 0; directionally consistent if greater but the CI spans 0.

| population | n | rho_generation | gen_ci | rho_making | mk_ci | diff_gen_minus_mk | diff_ci | verdict |
|---|---|---|---|---|---|---|---|---|
| all 15 teams | 15 | 0.429 | [-0.191, 0.852] | 0.754 | [0.302, 0.948] | -0.325 | [-0.961, 0.317] | not supported |
| 13 teams without trade flag | 13 | 0.390 | [-0.335, 0.881] | 0.703 | [0.134, 0.928] | -0.313 | [-1.096, 0.418] | not supported |

LVA (not trade-flagged), per 100 possessions:

| window | generation | generation_pctile | making | making_pctile |
|---|---|---|---|---|
| first_half | 81.57 | 7 | 9.45 | 100 |
| second_half | 83.98 | 7 | 9.45 | 100 |
| full | 82.71 | 7 | 9.41 | 100 |

LVA making change, second half minus first half: 0.0003 per 100; percentile 100 to 100. Prediction (making falls): not met.

## H-R3 (reads beyond the record)

Pre-registered: first-half generation and making add information about second-half results (point differential per game, win pct) beyond first-half record. Rule: supported if model B beats model A on leave-one-out RMSE. A = outcome ~ first-half win pct; A' = outcome ~ first-half point differential per game (stricter baseline); B = outcome ~ first-half win pct + generation + making. Primary outcome: second-half point differential per game; secondary: second-half win pct. n is 15 (13), low power.

| population | outcome | n | rmse_A | rmse_Aprime | rmse_B | rmse_mean_only | B_beats_A | B_beats_Aprime |
|---|---|---|---|---|---|---|---|---|
| all 15 teams | pd_per_game | 15 | 5.1919 | 5.6548 | 5.9393 | 8.3946 | FALSE | FALSE |
| all 15 teams | win_pct | 15 | 0.1652 | 0.1710 | 0.1637 | 0.2607 | TRUE | TRUE |
| 13 teams without trade flag | pd_per_game | 13 | 5.4304 | 6.0979 | 5.9722 | 9.0060 | FALSE | TRUE |
| 13 teams without trade flag | win_pct | 13 | 0.1703 | 0.1868 | 0.1586 | 0.2738 | TRUE | TRUE |

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
| 13 teams without trade flag | pd_per_game | A | fh_win_pct | 40.2448 | 8.5194 | <0.001 | 0.670 |
| 13 teams without trade flag | pd_per_game | B | fh_win_pct | 54.7967 | 11.3296 | <0.001 | 0.763 |
| 13 teams without trade flag | pd_per_game | B | generation | -0.3975 | 0.4723 | 0.422 | 0.763 |
| 13 teams without trade flag | pd_per_game | B | making | -0.7121 | 0.3787 | 0.093 | 0.763 |
| 13 teams without trade flag | win_pct | A | fh_win_pct | 1.1965 | 0.2704 | 0.001 | 0.640 |
| 13 teams without trade flag | win_pct | B | fh_win_pct | 1.8089 | 0.3088 | <0.001 | 0.810 |
| 13 teams without trade flag | win_pct | B | generation | -0.0200 | 0.0129 | 0.154 | 0.810 |
| 13 teams without trade flag | win_pct | B | making | -0.0292 | 0.0103 | 0.020 | 0.810 |

Verdict, all 15 teams: point differential per game, B does not beat A (5.939 vs 5.192): **not supported** on the primary outcome. Win pct, B beats A (0.1637 vs 0.1652).

Verdict, 13 teams without trade flag: point differential per game, B does not beat A (5.972 vs 5.430): **not supported** on the primary outcome. Win pct, B beats A (0.1586 vs 0.1703).

## H-R4 (trajectory labels weak)

Pre-registered: v1 improving/declining labels, most with intervals spanning zero, do not predict second-half direction better than chance. Expected null. Label = v1 shot-making trajectory in `output/deadline_read.csv`; outcome direction = sign of (second-half minus first-half making per 100). Exact two-sided binomial test vs 0.5. Rule: H-R4 is supported (null) unless agreement > 0.5 with p < 0.05.

| population | subset | n | agree | agreement | p_two_sided | ci_95 | verdict |
|---|---|---|---|---|---|---|---|
| all 15 teams | all_labels | 15 | 6 | 0.400 | 0.607 | [0.163, 0.677] | supported (null) |
| all 15 teams | interval_excludes_zero |  2 | 1 | 0.500 | 1.000 | [0.013, 0.987] | supported (null) |
| 13 teams without trade flag | all_labels | 13 | 5 | 0.385 | 0.581 | [0.139, 0.684] | supported (null) |
| 13 teams without trade flag | interval_excludes_zero |  2 | 1 | 0.500 | 1.000 | [0.013, 0.987] | supported (null) |

Per team:

| team | v1_label | interval_spans_zero | making_first | making_second | change | outcome_direction | agree |
|---|---|---|---|---|---|---|---|
| LVA | declining | TRUE | 9.45 | 9.45 | 0.00 | improving | FALSE |
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

LVA's change is +0.0003, so its outcome direction (improving) is set by a near-zero sign.

## H1, H2 on the full season

Pre-registered: H1 (transition rises with reps) and H2 (chemistry proxies improve, strongest for TOR and PDX) were published v1 nulls; do they hold with twice the sample? League trend is the fixed effect of game_index (change per team game), two-sided normal p, from R/06's trajectory model. `fallback_used` TRUE means the random-slope model hit the singular or convergence fallback to random intercepts plus per-team residual slopes.

| population | window | metric | trend_per_game | p | fallback_used |
|---|---|---|---|---|---|
| all 15 teams | first_half (v1 sample) | transition_share | -8.23e-05 | 0.729 | TRUE |
| all 15 teams | first_half (v1 sample) | transition_pts_per_poss | 3.81e-03 | 0.214 | TRUE |
| all 15 teams | first_half (v1 sample) | assisted_rate | -2.11e-04 | 0.772 | TRUE |
| all 15 teams | first_half (v1 sample) | live_ball_tov_rate | 2.18e-04 | 0.364 | TRUE |
| all 15 teams | full | transition_share | 2.11e-05 | 0.833 | TRUE |
| all 15 teams | full | transition_pts_per_poss | -6.76e-04 | 0.600 | TRUE |
| all 15 teams | full | assisted_rate | 4.77e-04 | 0.099 | TRUE |
| all 15 teams | full | live_ball_tov_rate | 2.90e-05 | 0.820 | FALSE |
| 13 teams without trade flag | full | transition_share | -2.70e-05 | 0.799 | TRUE |
| 13 teams without trade flag | full | transition_pts_per_poss | -2.01e-04 | 0.886 | TRUE |
| 13 teams without trade flag | full | assisted_rate | 2.31e-04 | 0.456 | TRUE |
| 13 teams without trade flag | full | live_ball_tov_rate | 1.12e-05 | 0.940 | FALSE |

With 44 games per team the random-slope model still falls back for 3 of 4 of these four metrics (full window, all teams).

TOR and PDX team slopes (per game, 95% interval):

| population | window | metric | team | slope | interval | trajectory | interval_spans_zero |
|---|---|---|---|---|---|---|---|
| all 15 teams | first_half (v1 sample) | assisted_rate | PDX | 3.38e-03 | [-2.45e-03, 9.21e-03] | improving | TRUE |
| all 15 teams | first_half (v1 sample) | assisted_rate | TOR | 4.86e-03 | [-8.63e-04, 1.06e-02] | improving | TRUE |
| all 15 teams | first_half (v1 sample) | live_ball_tov_rate | PDX | 6.66e-04 | [-1.48e-03, 2.81e-03] | improving | TRUE |
| all 15 teams | first_half (v1 sample) | live_ball_tov_rate | TOR | 2.46e-04 | [-1.34e-03, 1.84e-03] | improving | TRUE |
| all 15 teams | full | assisted_rate | PDX | 8.45e-05 | [-2.38e-03, 2.55e-03] | improving | TRUE |
| all 15 teams | full | assisted_rate | TOR | 3.16e-04 | [-1.89e-03, 2.52e-03] | improving | TRUE |
| all 15 teams | full | live_ball_tov_rate | PDX | -1.16e-04 | [-5.66e-04, 3.34e-04] | declining | TRUE |
| all 15 teams | full | live_ball_tov_rate | TOR | 2.88e-04 | [-1.61e-04, 7.37e-04] | improving | TRUE |
| 13 teams without trade flag | full | assisted_rate | PDX | 1.65e-04 | [-2.32e-03, 2.65e-03] | improving | TRUE |
| 13 teams without trade flag | full | assisted_rate | TOR | 2.32e-04 | [-1.97e-03, 2.43e-03] | improving | TRUE |
| 13 teams without trade flag | full | live_ball_tov_rate | PDX | -1.73e-04 | [-6.79e-04, 3.32e-04] | declining | TRUE |
| 13 teams without trade flag | full | live_ball_tov_rate | TOR | 3.61e-04 | [-1.43e-04, 8.65e-04] | improving | TRUE |

Verdicts (rule: trend p < 0.05): transition_share p=0.833 (null); transition_pts_per_poss p=0.600 (null); assisted_rate p=0.099 (null); live_ball_tov_rate p=0.820 (null). TOR and PDX intervals span zero in every row above: yes.

## H3 (GSV making)

Pre-registered: GSV's low FG% is making below expectation on an acceptable diet; GSV won the title, so report whether its making moved toward expectation. Per 100 possessions; percentile over the teams in the window (15 for regular-season windows, 8 for playoffs).

| window | n_teams | generation | generation_pctile | making | making_pctile |
|---|---|---|---|---|---|
| first_half | 15 | 86.30 | 71 | 0.65 | 50 |
| second_half | 15 | 90.67 | 79 | -0.02 | 43 |
| full | 15 | 88.29 | 86 | 0.24 | 57 |
| playoffs |  8 | 83.83 | 86 | -3.40 | 29 |

GSV shot-making trajectory (R/06 slope per game, 95% interval):

| window | slope | interval | trajectory | interval_spans_zero |
|---|---|---|---|---|
| first_half (v1 sample) | 0.2513 | [-0.3007, 0.8033] | improving | TRUE |
| full | 0.0442 | [-0.2073, 0.2956] | improving | TRUE |

Playoffs rows are descriptive (13 games, 900 FGA).

## v1 read scorecard

Held 7, partly held 3, failed 5 of 15. Rule: held if both the generation and making tiers (ntile(x, 3) over 15 teams, second-half window) are unchanged; partly held if exactly one tier changed by one step; failed otherwise. Trajectory outcome is reported separately (H-R4). Full table: `scorecard.md`, `scorecard.csv`.

| team | verdict | gen_v1_to_sh | mk_v1_to_sh | trade_flag |
|---|---|---|---|---|
| ATL | held | 3 to 3 | 1 to 1 | FALSE |
| GSV | held | 3 to 3 | 2 to 2 | FALSE |
| IND | held | 2 to 2 | 3 to 3 | FALSE |
| LVA | held | 1 to 1 | 3 to 3 | FALSE |
| MIN | held | 3 to 3 | 3 to 3 | FALSE |
| PDX | held | 2 to 2 | 2 to 2 | FALSE |
| PHX | held | 1 to 1 | 2 to 2 | TRUE |
| CHI | partly held | 3 to 2 | 1 to 1 | FALSE |
| CON | partly held | 2 to 1 | 1 to 1 | FALSE |
| TOR | partly held | 2 to 2 | 2 to 1 | FALSE |
| DAL | failed | 3 to 1 | 3 to 3 | FALSE |
| LAS | failed | 2 to 1 | 2 to 3 | TRUE |
| NYL | failed | 1 to 3 | 3 to 2 | FALSE |
| SEA | failed | 1 to 3 | 1 to 1 | FALSE |
| WAS | failed | 1 to 2 | 1 to 2 | FALSE |

Scorecard by trade flag:

| trade_flag | failed | held | partly held |
|---|---|---|---|
| FALSE | 4 | 6 | 3 |
| TRUE | 1 | 1 | 0 |

## Playoffs (descriptive, no tests)

Regular-season full-window generation and making per 100 versus the playoffs window (own baselines, 8 teams). Playoff samples are small (126 to 900 FGA) and selected.

| team | games | series_result | rs_gen | po_gen | rs_making | po_making | po_fga |
|---|---|---|---|---|---|---|---|
| GSV | 13 | won 2-1 vs DAL; won 3-0 vs LVA; won 4-3 vs ATL | 88.29 | 83.83 | 0.24 | -3.40 | 900 |
| ATL | 12 | won 2-0 vs WAS; won 3-0 vs NYL; lost 4-3 vs GSV | 94.11 | 81.67 | -6.31 | -4.13 | 812 |
| LVA |  6 | won 2-1 vs IND; lost 3-0 vs GSV | 82.71 | 70.68 | 9.41 | 7.01 | 374 |
| NYL |  5 | won 2-0 vs MIN; lost 3-0 vs ATL | 85.59 | 77.56 | 2.62 | 13.15 | 321 |
| DAL |  3 | lost 2-1 vs GSV | 87.75 | 69.94 | 4.38 | 13.04 | 183 |
| IND |  3 | lost 2-1 vs LVA | 85.72 | 86.19 | 6.54 | 4.09 | 216 |
| MIN |  2 | lost 2-0 vs NYL | 89.80 | 80.78 | 4.29 | -0.13 | 135 |
| WAS |  2 | lost 2-0 vs ATL | 83.77 | 71.81 | -2.90 | -3.74 | 126 |

