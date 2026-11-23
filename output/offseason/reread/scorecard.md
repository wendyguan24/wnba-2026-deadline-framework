# v1 read scorecard

Per team: the v1 deadline read (generation tier, making tier, trajectory, lever, recommendation, from `output/deadline_read.csv`) against the second-half window (games 183 to 330, own baseline, ntile(x, 3) over 15 teams as in v1). Verdict: held = both tiers unchanged; partly held = exactly one tier changed by one step; failed = otherwise. Trajectory outcome (agree/disagree) compares the v1 shot-making label with the sign of the second-half minus first-half making change; it is not part of the verdict. Tier 1 = low, 3 = high.

| team | verdict | gen_tier_v1 | gen_tier_sh | gen_pctile_sh | mk_tier_v1 | mk_tier_sh | mk_pctile_sh | v1_trajectory | spans_zero | trajectory_outcome | v1_lever | trade_flag | sh_record | sh_pd_per_game | final_record | final_rank |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ATL | held | 3 | 3 | 100 | 1 | 1 |  29 | declining | TRUE | disagree | hold | FALSE | 16-4 | 10.85 | 30-14 |  4 |
| GSV | held | 3 | 3 |  79 | 2 | 2 |  43 | improving | TRUE | disagree | hold | FALSE | 14-5 | 8.32 | 32-12 |  2 |
| IND | held | 2 | 2 |  43 | 3 | 3 |  93 | improving | FALSE | agree | adjust | FALSE | 14-6 | 7.10 | 28-16 |  5 |
| LVA | held | 1 | 1 |   7 | 3 | 3 | 100 | declining | TRUE | disagree | acquire (constrained: requires salary out) | FALSE | 14-6 | 7.65 | 31-13 |  3 |
| MIN | held | 3 | 3 |  93 | 3 | 3 |  79 | declining | TRUE | agree | hold | FALSE | 14-5 | 4.95 | 33-11 |  1 |
| PDX | held | 2 | 2 |  50 | 2 | 2 |  50 | declining | TRUE | disagree | adjust | FALSE | 6-13 | -4.26 | 17-27 |  9 |
| PHX | held | 1 | 1 |   0 | 2 | 2 |  36 | improving | TRUE | agree | acquire (constrained: limited room, minimum/depth only) | TRUE | 8-11 | -2.21 | 16-28 | 10 |
| CHI | partly held | 3 | 2 |  64 | 1 | 1 |  21 | improving | TRUE | agree | hold | FALSE | 8-12 | -5.00 | 16-28 | 11 |
| CON | partly held | 2 | 1 |  29 | 1 | 1 |   0 | improving | TRUE | disagree | hold | FALSE | 5-15 | -12.25 | 11-33 | 14 |
| TOR | partly held | 2 | 2 |  57 | 2 | 1 |   7 | improving | TRUE | disagree | adjust | FALSE | 1-19 | -15.65 | 11-33 | 13 |
| DAL | failed | 3 | 1 |  14 | 3 | 3 |  86 | improving | TRUE | agree | hold | FALSE | 11-9 | 4.20 | 27-17 |  7 |
| LAS | failed | 2 | 1 |  21 | 2 | 3 |  71 | declining | TRUE | disagree | adjust | TRUE | 6-15 | -3.90 | 16-28 | 12 |
| NYL | failed | 1 | 3 |  71 | 3 | 2 |  64 | declining | TRUE | agree | acquire (constrained: limited room, minimum/depth only) | FALSE | 13-7 | 2.90 | 26-18 |  8 |
| SEA | failed | 1 | 3 |  86 | 1 | 1 |  14 | improving | TRUE | disagree | acquire (constrained: limited room, minimum/depth only) | FALSE | 2-16 | -9.11 | 8-36 | 15 |
| WAS | failed | 1 | 2 |  36 | 1 | 2 |  57 | declining | FALSE | disagree | acquire | FALSE | 16-5 | 5.76 | 28-16 |  6 |

v1 recommendations (text from deadline_read.csv):

- ATL (held): judgment (lean hold or sell): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)
- GSV (held): amplify: extend the edge -- add on-style depth, protect the shot hierarchy
- IND (held): adjust: offense is roughly league-average -- tune, not a splash; offense is not the primary lever
- LVA (held): reassess: bottom-tier shot generation propped up by top-tier but declining making -- address the shot diet / identity before spending an asset on a new piece (trajectory directional)
- MIN (held): amplify: extend the edge -- add on-style depth, protect the shot hierarchy
- PDX (held): sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy
- PHX (held): sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy
- CHI (partly held): sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy
- CON (partly held): sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy
- TOR (partly held): judgment (lean buy): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)
- DAL (failed): amplify: extend the edge -- add on-style depth, protect the shot hierarchy
- LAS (failed): sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy
- NYL (failed): judgment (lean hold or sell): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)
- SEA (failed): sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy
- WAS (failed): judgment (lean hold or sell): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving
