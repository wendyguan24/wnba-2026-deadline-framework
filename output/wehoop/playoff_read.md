# WNBA 2026 Full-Season Playoff Readiness

Generated: 2026-09-14 03:41:43 UTC

This is a full-season view, not a deadline read: there is no acquire/adjust/hold lever left to pull, so Readiness replaces the deadline recommendation. Offense diagnosis is descriptive only (generation-short/balanced/generation-rich, from the stratified expected-points baseline's generation axis). Defense and Depth are new to the full-season view -- see the footnotes for their sourcing and caveats.

Data limitation this run: RAPM was not pulled (the optional per-game live step, 16_wehoop_live_api.R --rapm, was not run), so the Depth column reads "unavailable" for every team and does NOT enter the readiness classification. Readiness here is decided on generation, defense, and trajectory only. Weak is the count of measured structural weaknesses driving the label (out of the dimensions actually measured), shown so a one-weakness read is distinct from a multi-weakness one.

Playoff Position is from standing_score (script 18, a win-pct and point-differential blend), so it can differ from a strict wins-losses rank: contender = top-4 by standing_score, in = 5th-8th, out = 9th-15th. Point differential itself is not an input to Readiness.

| Team | Playoff Position | Readiness | Weak | Defense | Depth | Gen Rank | Making Rank | Trajectory | Identity | Cap |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ATL | in | complete | 0 | elite defense | unavailable | 1 | 14 | declining* | high driving rate, high rim rate | tight |
| DAL | in | complete | 0 | elite defense | unavailable | 7 | 4 | improving* | high pullup rate, high mid-range rate | tight |
| GSV | contender | complete | 0 | elite defense | unavailable | 3 | 7 | improving* | low pace, low rim rate | capped |
| NYL | in | complete | 0 | average defense | unavailable | 9 | 5 | declining* | high corner-3 rate, high 3PA rate | tight |
| WAS | in | complete | 0 | elite defense | unavailable | 8 | 12 | declining* | high driving rate, low above-break-3 rate | room |
| IND | contender | one piece away | 1 | average defense | unavailable | 12 | 2 | improving | high pace, high above-break-3 rate | tight |
| LVA | contender | one piece away | 1 | average defense | unavailable | 11 | 1 | improving* | high pullup rate, low driving rate | capped |
| MIN | contender | one piece away | 1 | elite defense | unavailable | 13 | 3 | declining* | high mid-range rate, low above-break-3 rate | tight |
| CHI | out | out | 0 | average defense | unavailable | 4 | 13 | improving* | high rim rate, high pace | capped |
| CON | out | out | 0 | average defense | unavailable | 10 | 15 | improving* | low 3PA rate, low corner-3 rate | tight |
| LAS | out | out | 1 | weak defense | unavailable | 6 | 6 | declining* | high pace, low mid-range rate | tight |
| PDX | out | out | 1 | weak defense | unavailable | 5 | 8 | improving* | low pullup rate, low mid-range rate | room |
| PHX | out | out | 2 | weak defense | unavailable | 15 | 9 | improving* | high corner-3 rate, low rim rate | tight |
| SEA | out | out | 2 | weak defense | unavailable | 14 | 11 | improving* | low corner-3 rate, high above-break-3 rate | tight |
| TOR | out | out | 1 | weak defense | unavailable | 2 | 10 | improving* | high above-break-3 rate, high 3PA rate | tight |

Gen rank and Making rank are the team's league rank of 15 (1 = best): Gen rank 1 is the most and best looks created (highest shot generation), Making rank 1 is the best finishing relative to expected points given shot location and creation type (highest shot making).

Readiness classification (first-match-wins precedence, see classify_readiness() in R/24_wehoop_playoff_read.R): complete = no measured structural weakness (generation, defense, and depth when measured) and a non-declining trajectory; one piece away = exactly one measured structural weakness and a non-declining trajectory; trending wrong = mid-tier-or-above generation with a confident declining trajectory; trending right = mid-tier generation with a confident improving trajectory; in but vulnerable = holding a playoff spot with a structural concern, or the conservative default when no other category fits (the Weak column shows how many weaknesses drove the label, so a fallback-caught row can be told from a genuine single-weakness read); out = outside the playoff field regardless of the other dimensions. A trending label requires a trajectory whose interval excludes zero: a starred (*) trajectory is directional only and does not trigger one.

* interval spans zero: the per-team trajectory label is directional, not a standalone claim. Trajectory shown is the shot_making_residual trend (finishing relative to expected points given shot location and creation type, rising or falling). Per-team labels come from output/wehoop/team_trajectories.csv; the league-wide fixed effect (shot_making_residual trend +0.18, p=0.02) is in output/wehoop/trajectory_league_trends.csv and was fit via the singular-fit fallback (random intercepts plus a per-team OLS slope of residuals), so the per-team intervals are an approximation that can understate uncertainty, and the p-value is a Wald-z approximation. No garbage-time or split-half sensitivity pass is run in this pipeline.

Defense is DEF_RATING rank from output/wehoop/team_advanced_profile.csv (script 20): rank 1-5 elite, 6-10 average, 11-15 weak, lower DEF_RATING is better. "unavailable" means the advanced-profile input was missing the expected column for this run.

Depth is a count of players with positive full-season RAPM from output/wehoop/player_value.csv (script 21): 5+ deep, 3-4 adequate, 1-2 thin, 0 no positive-RAPM player, and "unavailable" when RAPM was not pulled at all. RAPM comes from the optional per-game live step (16_wehoop_live_api.R --rapm); it was NOT run this time, so every team reads "unavailable" and depth did not enter the readiness call. This is a missing input, not a finding: it does not mean a team lacks above-replacement players. When RAPM is present, treat depth_count as a coarse signal, not a precise player count, and do not publish it as a ranking of individual players.

This is a full-season view: it describes where a team ended up, not a deadline decision. It does not carry a cap-conditioned lever call (compare output/deadline_read.md's Recommendation column) -- Cap, where shown, is the hand-curated flexibility_tier from data/reference/cap_context_2026.csv, included for reference only and not used to condition Readiness.
