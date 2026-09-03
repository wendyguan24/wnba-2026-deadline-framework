# WNBA 2026 Full-Season Playoff Readiness

Generated: 2026-09-03 00:03:55 UTC

This is a full-season view, not a deadline read: there is no acquire/adjust/hold lever left to pull, so Readiness replaces the deadline recommendation. Offense diagnosis is descriptive only (generation-short/balanced/generation-rich, from the stratified expected-points baseline's generation axis). Defense and Depth are new to the full-season view -- see the footnotes for their sourcing and caveats.

| Team | Playoff Position | Readiness | Defense | Depth | Gen Rank | Making Rank | Trajectory | Identity | Cap |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DAL | in | one piece away | elite defense | no positive-RAPM | 7 | 4 | improving* | high pullup rate, high mid-range rate | tight |
| GSV | contender | one piece away | elite defense | no positive-RAPM | 3 | 7 | improving* | low pace, low rim rate | capped |
| ATL | in | trending wrong | elite defense | no positive-RAPM | 1 | 14 | declining* | high driving rate, high rim rate | tight |
| NYL | in | trending wrong | average defense | no positive-RAPM | 9 | 5 | declining* | high corner-3 rate, high 3PA rate | tight |
| WAS | in | trending wrong | elite defense | no positive-RAPM | 8 | 12 | declining* | high driving rate, low above-break-3 rate | room |
| IND | contender | in but vulnerable | average defense | no positive-RAPM | 12 | 2 | improving | high pace, high above-break-3 rate | tight |
| LVA | contender | in but vulnerable | average defense | no positive-RAPM | 11 | 1 | improving* | high pullup rate, low driving rate | capped |
| MIN | contender | in but vulnerable | elite defense | no positive-RAPM | 13 | 3 | declining* | high mid-range rate, low above-break-3 rate | tight |
| CHI | out | out | average defense | no positive-RAPM | 4 | 13 | improving* | high rim rate, high pace | capped |
| CON | out | out | average defense | no positive-RAPM | 10 | 15 | improving* | low 3PA rate, low corner-3 rate | tight |
| LAS | out | out | weak defense | no positive-RAPM | 6 | 6 | declining* | high pace, low mid-range rate | tight |
| PDX | out | out | weak defense | no positive-RAPM | 5 | 8 | improving* | low pullup rate, low mid-range rate | room |
| PHX | out | out | weak defense | no positive-RAPM | 15 | 9 | improving* | high corner-3 rate, low rim rate | tight |
| SEA | out | out | weak defense | no positive-RAPM | 14 | 11 | improving* | low corner-3 rate, high above-break-3 rate | tight |
| TOR | out | out | weak defense | no positive-RAPM | 2 | 10 | improving* | high above-break-3 rate, high 3PA rate | tight |

Gen rank and Making rank are the team's league rank of 15 (1 = best): Gen rank 1 is the most and best looks created (highest shot generation), Making rank 1 is the best finishing relative to shot quality (highest shot making).

Readiness classification (first-match-wins precedence, see classify_readiness() in R/24_wehoop_playoff_read.R): complete = no structural weakness across generation, defense, and depth and a non-declining trajectory; one piece away = exactly one structural weakness and a non-declining trajectory; trending wrong = mid-tier- or-above generation with a declining trajectory; trending right = mid-tier generation with an improving trajectory; in but vulnerable = holding a playoff spot with a structural concern (or the conservative default when no other category fits); out = outside the playoff field regardless of the other dimensions.

* interval spans zero: the per-team trajectory label is directional, not a standalone claim. Trajectory shown is the shot_making_residual trend (finishing relative to shot quality, rising or falling), the same headline trajectory metric used in the deadline read. Source: output/wehoop/trajectory_league_trends.csv.

Defense is DEF_RATING rank from output/wehoop/team_advanced_profile.csv (script 20): rank 1-5 elite, 6-10 average, 11-15 weak, lower DEF_RATING is better. "unavailable" means the advanced-profile input was missing the expected column for this run.

Depth is a count of players with positive full-season RAPM from output/wehoop/player_value.csv (script 21): 5+ deep, 3-4 adequate, 1-2 thin, 0 no positive-RAPM player. RAPM at the individual-season level carries real uncertainty, particularly for low-minute players -- treat depth_count as a coarse signal, not a precise player count, and do not publish it as a ranking of individual players.

This is a full-season view: it describes where a team ended up, not a deadline decision. It does not carry a cap-conditioned lever call (compare output/deadline_read.md's Recommendation column) -- Cap, where shown, is the hand-curated flexibility_tier from data/reference/cap_context_2026.csv, included for reference only and not used to condition Readiness.
