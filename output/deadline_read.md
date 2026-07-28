# WNBA 2026 Trade Deadline Read

Generated: 2026-07-28 13:53:55 UTC

The Recommendation column is the action, and it is the only action column: it is conditioned on the standing-derived window and the cap tier. The Offense diagnosis column is descriptive of the offense only (generation-short / balanced / generation-rich) and is not an instruction. Diagnosis is generation/making-driven per HANDOFF 5e: generation is the process axis (expected points per 100 given shot diet, from the stratified expected-points baseline), making is the finishing axis (actual minus expected). Trajectory shown is the finishing trend (finishing relative to shot quality, rising or falling).

| Team | Recommendation | Window | Cap | Offense diagnosis | Gen %ile | Making %ile | Trajectory | Identity |
|---|---|---|---|---|---|---|---|---|
| LVA | reassess: bottom-tier shot generation propped up by top-tier but declining making -- address the shot diet / identity before spending an asset on a new piece (trajectory directional) | buyer | capped | generation-short | 7 | 100 | declining* | low driving rate, high pullup rate |
| NYL | judgment (hold): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional) | bubble | tight | generation-short | 14 | 79 | declining* | high 3PA rate, high above-break-3 rate |
| PHX | sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy | seller | tight | generation-short | 21 | 36 | improving* | high transition rate, low rim rate |
| SEA | sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy | seller | tight | generation-short | 29 | 29 | improving* | low rim rate, high above-break-3 rate |
| WAS | judgment (lean hold or sell): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving | bubble | room (below floor) | generation-short | 0 | 7 | declining | high paint scoring, low transition rate |
| IND | adjust: offense is roughly league-average -- tune, not a splash; offense is not the primary lever | buyer | tight | balanced | 36 | 86 | improving | low transition rate, high above-break-3 rate |
| LAS | sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy | seller | tight | balanced | 43 | 64 | declining* | low mid-range rate, high above-break-3 rate |
| PDX | sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy | seller | room (below floor) | balanced | 64 | 43 | declining* | low mid-range rate, low pullup rate |
| TOR | judgment (hold): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional) | bubble | tight | balanced | 50 | 57 | improving* | low paint scoring, high 3PA rate |
| ATL | judgment (hold): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional) | bubble | tight | generation-rich | 100 | 0 | declining* | high rim rate, low mid-range rate |
| CHI | sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy | seller | capped | generation-rich | 79 | 21 | improving* | high rim rate, high driving rate |
| CON | sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy | seller | tight | balanced | 57 | 14 | improving* | low 3PA rate, low above-break-3 rate |
| DAL | amplify: extend the edge -- add on-style depth, protect the shot hierarchy | buyer | tight | generation-rich | 93 | 71 | improving* | high transition rate, high pullup rate |
| GSV | amplify: extend the edge -- add on-style depth, protect the shot hierarchy | buyer | capped | generation-rich | 71 | 50 | improving* | low paint scoring, high above-break-3 rate |
| MIN | amplify: extend the edge -- add on-style depth, protect the shot hierarchy | buyer | tight | generation-rich | 86 | 93 | declining* | high mid-range rate, high transition rate |

* interval spans zero: the per-team trajectory label is directional, not a standalone claim (AMENDMENT_01 Section 1).

Schedule note: the August 2 deadline sits just before the World Cup Hiatus (August 31 to September 16, dates per AMENDMENT_02; the Hiatus and prioritization rule is cba_rules_2026.md Section 5). The break is a hold incentive; a hold this deadline buys a mid-schedule reset. Forward strength-of-schedule is not modeled (no forward schedule in the open play-by-play).

Cap context is a flexibility tier (room / tight / capped), not a dollar figure; source data/reference/cap_context_2026.csv (Spotrac, 2026-07-19), grounded in cba_rules_2026.md Section 2. A "(below floor)" tag marks a team below the 85%-of-cap team-salary floor ($5.95M, cba_rules_2026.md Section 1). A below-floor team must reach the floor over the season, which it can satisfy by paying the shortfall out to its players -- a soft nudge toward adding salary, not a deadline-forcing mandate. Re-verify before publish (AMENDMENT_02 Section 4).

Trajectory note: the improving/flat/declining labels are directional reads of each team's within-season finishing trend, not standalone claims; the per-team intervals span zero (the "*" marker). The modeling detail (the full trend fit was singular, so a documented fallback was used) is in output/methodology.md. Source: output/trajectory_league_trends.csv.

Window (buyer/bubble/seller) is from standing (output/standing.csv), a data-driven proxy for a team's competitive window that blends win-loss record and scoring margin per game (equally weighted z-scores, see R/12_standing.R), not win_pct alone; it conditions the recommendation, not the diagnosis. Diagnosis (identity/generation/making/trajectory) is record-independent by design. A front office overrides window with private information (ownership mandate, injuries, the World Cup break).

Recommendation vocabulary (amplify / adjust / gap-fill / reassess / sell / judgment) is shared with output/generation_gap.md's fit_read, derived from the same signals (window, generation tier, making tier, making trajectory), so the two documents agree verb-for-verb.
