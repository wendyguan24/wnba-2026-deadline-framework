# Team advanced profile (wehoop)

Generated: 2026-09-03 00:03:47 UTC

## Offensive and defensive ratings

OFF_RATING / DEF_RATING are points scored / allowed per 100 possessions;
NET_RATING is the difference. PACE is possessions per 48 minutes.
Rank 1 is best in each column.

| tricode | off_rating | rank_off | def_rating | rank_def | net_rating | rank_net | pace |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MIN | 113.8 |  2 | 103.2 |  2 | 10.6 |  1 | 97.5 |
| GSV | 110.1 |  6 | 101.4 |  1 | 8.7 |  2 | 91.0 |
| IND | 115.0 |  1 | 108.0 |  8 | 7.1 |  3 | 99.3 |
| ATL | 110.0 |  7 | 105.6 |  4 | 4.5 |  4 | 97.8 |
| LVA | 112.3 |  3 | 107.8 |  6 | 4.5 |  4 | 96.4 |
| NYL | 112.1 |  4 | 108.1 |  9 | 4.0 |  6 | 96.5 |
| DAL | 110.8 |  5 | 107.4 |  5 | 3.3 |  7 | 95.7 |
| WAS | 101.7 | 14 | 103.2 |  2 | -1.4 |  8 | 94.2 |
| CHI | 105.5 | 11 | 108.3 | 10 | -2.8 |  9 | 99.1 |
| PHX | 104.4 | 12 | 108.9 | 12 | -4.4 | 10 | 96.0 |
| LAS | 107.5 |  8 | 112.8 | 14 | -5.3 | 11 | 99.2 |
| PDX | 106.8 | 10 | 112.6 | 13 | -5.8 | 12 | 96.1 |
| SEA | 102.6 | 13 | 108.8 | 11 | -6.2 | 13 | 97.3 |
| TOR | 107.5 |  8 | 115.5 | 15 | -8.0 | 14 | 97.5 |
| CON | 98.9 | 15 | 107.9 |  7 | -9.0 | 15 | 96.2 |

## Four factors

EFG_PCT (shooting efficiency), TM_TOV_PCT (turnover rate, lower is better),
OREB_PCT (offensive rebound rate), FTA_RATE (free-throw rate). primary_factor
is the factor with the most extreme z-score for that team, a rough read on
what is driving its offensive profile relative to the league.

| tricode | efg_pct | fta_rate | tm_tov_pct | oreb_pct | primary_factor |
| --- | --- | --- | --- | --- | --- |
| MIN | 0.549 | 0.246 | 0.160 | 0.328 | fta_rate |
| GSV | 0.507 | 0.283 | 0.151 | 0.323 | tm_tov_pct |
| IND | 0.562 | 0.332 | 0.183 | 0.326 | efg_pct |
| ATL | 0.496 | 0.352 | 0.171 | 0.367 | oreb_pct |
| LVA | 0.548 | 0.290 | 0.152 | 0.272 | oreb_pct |
| NYL | 0.542 | 0.316 | 0.185 | 0.324 | efg_pct |
| DAL | 0.521 | 0.253 | 0.147 | 0.307 | tm_tov_pct |
| WAS | 0.484 | 0.391 | 0.199 | 0.359 | fta_rate |
| CHI | 0.499 | 0.340 | 0.160 | 0.279 | oreb_pct |
| PHX | 0.503 | 0.358 | 0.172 | 0.271 | oreb_pct |
| LAS | 0.530 | 0.291 | 0.178 | 0.289 | oreb_pct |
| PDX | 0.529 | 0.272 | 0.189 | 0.303 | tm_tov_pct |
| SEA | 0.496 | 0.281 | 0.182 | 0.298 | efg_pct |
| TOR | 0.522 | 0.305 | 0.179 | 0.291 | oreb_pct |
| CON | 0.475 | 0.319 | 0.185 | 0.325 | efg_pct |

## Hustle profile

Not available: hustle endpoints deprecated in wehoop 3.0.0.

## Strengths and weaknesses

Two highest and two lowest z-scored dimensions per team, across 9
dimensions (ratings and four factors). Lower-is-better
metrics (DEF_RATING, TM_TOV_PCT) are sign-flipped so positive always
means better.

| tricode | strength_1 | strength_2 | weakness_1 | weakness_2 |
| --- | --- | --- | --- | --- |
| MIN | net_rating | pie | fta_rate | pace |
| GSV | def_rating | tm_tov_pct | pace | fta_rate |
| IND | efg_pct | off_rating | tm_tov_pct | def_rating |
| ATL | oreb_pct | fta_rate | efg_pct | tm_tov_pct |
| LVA | tm_tov_pct | pie | oreb_pct | fta_rate |
| NYL | efg_pct | off_rating | tm_tov_pct | pace |
| DAL | tm_tov_pct | off_rating | fta_rate | pace |
| WAS | fta_rate | oreb_pct | tm_tov_pct | off_rating |
| CHI | pace | tm_tov_pct | oreb_pct | efg_pct |
| PHX | fta_rate | tm_tov_pct | oreb_pct | off_rating |
| LAS | pace | efg_pct | def_rating | net_rating |
| PDX | efg_pct | off_rating | pie | def_rating |
| SEA | pace | def_rating | off_rating | pie |
| TOR | pace | efg_pct | def_rating | net_rating |
| CON | oreb_pct | fta_rate | off_rating | efg_pct |
