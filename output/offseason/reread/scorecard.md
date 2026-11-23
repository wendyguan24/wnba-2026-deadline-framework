# v1 read scorecard (EXPLORATORY: descriptor stability, not advice outcome)

Per team: the v1 deadline read (generation tier, making tier, trajectory, lever, recommendation, from `output/deadline_read.csv`) against the second-half window (own baseline, ntile(x, 3) over 15 teams as in v1). Verdict: held = both tiers unchanged; partly held = exactly one tier changed by one step; failed = otherwise. boundary_sensitive = rank adjacent to a tier boundary in either half on either axis; verdicts_possible lists the verdicts reachable under one-rank swaps. Trajectory outcome compares the v1 shot-making label with the sign of the second-half minus first-half making change (ties within 0.01 per100 excluded); it is not part of the verdict. Tier 1 = low, 3 = high. Percentile change = second half minus v1.

Counts: held 7, partly held 3, failed 5 of 15; range under one-rank swaps: held 2 to 9, partly held 1 to 12, failed 1 to 5; boundary_sensitive teams 12; chance rate for held 1/9 (expected 1.67 teams); record-tertile benchmark keeps 7 of 15 teams in the same record tier.

| team | verdict | boundary_sensitive | verdicts_possible | gen_tier_v1 | gen_tier_sh | gen_pctile_v1 | gen_pctile_sh | gen_pctile_change | mk_tier_v1 | mk_tier_sh | mk_pctile_v1 | mk_pctile_sh | mk_pctile_change | v1_trajectory | spans_zero | trajectory_outcome | v1_lever | roster_turnover_flag | sh_record | sh_pd_per_game | final_record | final_rank |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ATL | held | TRUE | held or partly held | 3 | 3 | 100 | 100 | 0 | 1 | 1 | 0 | 29 | 29 | declining | TRUE | disagree | hold | FALSE | 16-4 | 10.85 | 30-14 | 4 |
| GSV | held | TRUE | held or partly held | 3 | 3 | 71 | 79 | 8 | 2 | 2 | 50 | 43 | -7 | improving | TRUE | disagree | hold | FALSE | 14-5 | 8.32 | 32-12 | 2 |
| IND | held | TRUE | held or partly held | 2 | 2 | 36 | 43 | 7 | 3 | 3 | 86 | 93 | 7 | improving | FALSE | agree | adjust | FALSE | 14-6 | 7.10 | 28-16 | 5 |
| LVA | held | FALSE | held | 1 | 1 | 7 | 7 | 0 | 3 | 3 | 100 | 100 | 0 | declining | TRUE | tie | acquire (constrained: requires salary out) | FALSE | 14-6 | 7.65 | 31-13 | 3 |
| MIN | held | FALSE | held | 3 | 3 | 86 | 93 | 7 | 3 | 3 | 93 | 79 | -14 | declining | TRUE | agree | hold | FALSE | 14-5 | 4.95 | 33-11 | 1 |
| PDX | held | TRUE | held or partly held | 2 | 2 | 64 | 50 | -14 | 2 | 2 | 43 | 50 | 7 | declining | TRUE | disagree | adjust | FALSE | 6-13 | -4.26 | 17-27 | 9 |
| PHX | held | TRUE | held or partly held | 1 | 1 | 21 | 0 | -21 | 2 | 2 | 36 | 36 | 0 | improving | TRUE | agree | acquire (constrained: limited room, minimum/depth only) | TRUE | 8-11 | -2.21 | 16-28 | 10 |
| CHI | partly held | TRUE | held or partly held | 3 | 2 | 79 | 64 | -15 | 1 | 1 | 21 | 21 | 0 | improving | TRUE | agree | hold | FALSE | 8-12 | -5.00 | 16-28 | 11 |
| CON | partly held | TRUE | held or partly held | 2 | 1 | 57 | 29 | -28 | 1 | 1 | 14 | 0 | -14 | improving | TRUE | disagree | hold | FALSE | 5-15 | -12.25 | 11-33 | 14 |
| TOR | partly held | FALSE | partly held | 2 | 2 | 50 | 57 | 7 | 2 | 1 | 57 | 7 | -50 | improving | TRUE | disagree | adjust | FALSE | 1-19 | -15.65 | 11-33 | 13 |
| DAL | failed | TRUE | failed | 3 | 1 | 93 | 14 | -79 | 3 | 3 | 71 | 86 | 15 | improving | TRUE | agree | hold | FALSE | 11-9 | 4.20 | 27-17 | 7 |
| LAS | failed | TRUE | failed or partly held | 2 | 1 | 43 | 21 | -22 | 2 | 3 | 64 | 71 | 7 | declining | TRUE | disagree | adjust | TRUE | 6-15 | -3.90 | 16-28 | 12 |
| NYL | failed | TRUE | failed or partly held | 1 | 3 | 14 | 71 | 57 | 3 | 2 | 79 | 64 | -15 | declining | TRUE | agree | acquire (constrained: limited room, minimum/depth only) | FALSE | 13-7 | 2.90 | 26-18 | 8 |
| SEA | failed | TRUE | failed or partly held | 1 | 3 | 29 | 86 | 57 | 1 | 1 | 29 | 14 | -15 | improving | TRUE | disagree | acquire (constrained: limited room, minimum/depth only) | FALSE | 2-16 | -9.11 | 8-36 | 15 |
| WAS | failed | TRUE | failed or partly held | 1 | 2 | 0 | 36 | 36 | 1 | 2 | 7 | 57 | 50 | declining | FALSE | disagree | acquire | FALSE | 16-5 | 5.76 | 28-16 | 6 |

v1 recommendations (text from deadline_read.csv, dashes replaced by semicolons):

- ATL (held): judgment (lean hold or sell): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)
- GSV (held): amplify: extend the edge; add on-style depth, protect the shot hierarchy
- IND (held): adjust: offense is roughly league-average; tune, not a splash; offense is not the primary lever
- LVA (held): reassess: bottom-tier shot generation propped up by top-tier but declining making; address the shot diet / identity before spending an asset on a new piece (trajectory directional)
- MIN (held): amplify: extend the edge; add on-style depth, protect the shot hierarchy
- PDX (held): sell / accumulate: out of the race; deal expirings and prioritize asset value over a deadline buy
- PHX (held): sell / accumulate: out of the race; deal expirings and prioritize asset value over a deadline buy
- CHI (partly held): sell / accumulate: out of the race; deal expirings and prioritize asset value over a deadline buy
- CON (partly held): sell / accumulate: out of the race; deal expirings and prioritize asset value over a deadline buy
- TOR (partly held): judgment (lean buy): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)
- DAL (failed): amplify: extend the edge; add on-style depth, protect the shot hierarchy
- LAS (failed): sell / accumulate: out of the race; deal expirings and prioritize asset value over a deadline buy
- NYL (failed): judgment (lean hold or sell): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)
- SEA (failed): sell / accumulate: out of the race; deal expirings and prioritize asset value over a deadline buy
- WAS (failed): judgment (lean hold or sell): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving
