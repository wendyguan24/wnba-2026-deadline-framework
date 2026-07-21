# WNBA 2026 Trade Deadline Read

Generated: 2026-07-21 19:09:22 UTC

Lever is generation/making-driven per HANDOFF 5e; generation is the process axis (expected points per 100 given shot diet, from the stratified expected-points baseline), making is the finishing axis (actual minus expected). Trajectory shown is the shot_making_residual trend.

| Team | Identity | Gen %ile | Making %ile | Trajectory | Cap | Lever | Window | Recommendation |
|---|---|---|---|---|---|---|---|---|
| LVA | low driving rate, high pullup rate | 7 | 100 | declining* | capped | acquire (constrained: requires salary out) | buyer | acquire (constrained: requires salary out) |
| NYL | high 3PA rate, high above-break-3 rate | 14 | 79 | declining* | tight | acquire (constrained: limited room, minimum/depth only) | bubble | judgment: acquire (constrained: limited room, minimum/depth only) -- window is contested; weigh trajectory (see deadline read / trajectory outputs) before buying or selling |
| PHX | high transition rate, low rim rate | 21 | 36 | improving* | tight | acquire (constrained: limited room, minimum/depth only) | seller | sell-side: diagnosis needs the acquire, but team is out of the race -- accumulate/deal expirings, do not buy |
| SEA | low rim rate, high above-break-3 rate | 29 | 29 | improving* | tight | acquire (constrained: limited room, minimum/depth only) | seller | sell-side: diagnosis needs the acquire, but team is out of the race -- accumulate/deal expirings, do not buy |
| WAS | high paint scoring, low transition rate | 0 | 7 | declining | room (below floor) | acquire | bubble | judgment: acquire -- window is contested; weigh trajectory (see deadline read / trajectory outputs) before buying or selling |
| IND | low transition rate, high above-break-3 rate | 36 | 86 | improving | tight | adjust | buyer | adjust |
| LAS | low mid-range rate, high above-break-3 rate | 43 | 64 | declining* | tight | adjust | seller | hold/sell: out of the race, prioritize development and asset value |
| PDX | low mid-range rate, low pullup rate | 64 | 43 | declining* | room (below floor) | adjust | bubble | judgment: adjust -- window is contested; weigh trajectory (see deadline read / trajectory outputs) before buying or selling |
| TOR | low paint scoring, high 3PA rate | 50 | 57 | improving* | tight | adjust | seller | hold/sell: out of the race, prioritize development and asset value |
| ATL | high rim rate, low mid-range rate | 100 | 0 | declining* | tight | hold | bubble | judgment: hold -- window is contested; weigh trajectory (see deadline read / trajectory outputs) before buying or selling |
| CHI | high rim rate, high driving rate | 79 | 21 | improving* | capped | hold | seller | hold/sell: out of the race, prioritize development and asset value |
| CON | low 3PA rate, low above-break-3 rate | 57 | 14 | improving* | tight | hold | seller | hold/sell: out of the race, prioritize development and asset value |
| DAL | high transition rate, high pullup rate | 93 | 71 | improving* | tight | hold | buyer | hold |
| GSV | low paint scoring, high above-break-3 rate | 71 | 50 | improving* | capped | hold | buyer | hold |
| MIN | high mid-range rate, high transition rate | 86 | 93 | declining* | tight | hold | buyer | hold |

* interval spans zero: the per-team trajectory label is directional, not a standalone claim (AMENDMENT_01 Section 1).

Schedule note: the August 2 deadline sits just before the World Cup Hiatus (August 31 to September 16, dates per AMENDMENT_02; the Hiatus and prioritization rule is cba_rules_2026.md Section 5). The break is a hold incentive; a hold this deadline buys a mid-schedule reset. Forward strength-of-schedule is not modeled (no forward schedule in the open play-by-play).

Cap context is a flexibility tier (room / tight / capped), not a dollar figure; source data/reference/cap_context_2026.csv (Spotrac, 2026-07-19), grounded in cba_rules_2026.md Section 2. A "(below floor)" tag marks a team below the 85%-of-cap team-salary floor ($5.95M, cba_rules_2026.md Section 1), which is pushed to add salary rather than free to stand pat. Re-verify before publish (AMENDMENT_02 Section 4).

Trajectory note: all five trajectory metrics used the documented random-intercept-plus-residual-slope fallback (the full random-slope fit was singular); the improving/flat/declining labels are directional reads, not random-slope BLUPs. Source: output/trajectory_league_trends.csv (fallback_used = TRUE for all five).

Window (buyer/bubble/seller) is from standing (output/standing.csv), a data-driven proxy for a team's competitive window; it conditions the recommendation, not the diagnosis. Diagnosis (identity/generation/ making/trajectory) is record-independent by design. A front office overrides window with private information (ownership mandate, injuries, the World Cup break).
