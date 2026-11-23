# Analysis tables report

Generated: 2026-11-23 16:55:35 UTC. Pin 46488f0.

## Row counts per table and season type

| table | season_type | rows |
|---|---|---|
| games | playoffs | 23 |
| games | regular | 330 |
| team_games | playoffs | 46 |
| team_games | regular | 660 |
| player_games | playoffs | 436 |
| player_games | regular | 6588 |
| players | both | 238 |
| possessions | playoffs | 3630 |
| possessions | regular | 54182 |
| pbp_events | playoffs | 10776 |
| pbp_events | regular | 161135 |
| shots | playoffs | 3067 |
| shots | regular | 45297 |

## Invariant results

| check | passed |
|---|---|
| games: game_id unique | PASS |
| team_games: game_id+team unique | PASS |
| player_games: game_id+team+person_id unique | PASS |
| every game has exactly 2 team_games | PASS |
| team_games pts equals games home/away pts | PASS |
| sum of player_games PTS per team-game equals team_games pts | PASS |
| sum of player minutes per team-game within 1 minute of 200 + 25*(n_periods-4) | FAIL |
| season_type never NA in any table | PASS |
| shots made-points per team-game equals team pts minus FTM | PASS |

## Minutes gate (R/13 rule: exactly 5 on court per team-period)

Pass rate, regular: 0.9970
Pass rate, playoffs: 0.9895
Team-games whose summed player minutes are more than 1 minute from 200 + 25*(n_periods-4): 10 of 706 (1.42%).
Largest absolute deviation: 10.00 minutes.
