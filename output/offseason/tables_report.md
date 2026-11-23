# Analysis tables report

Generated: 2026-11-23 17:13:22 UTC. Pin 46488f0.

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
| minutes within 1 minute of 200 + 25*(n_periods-4) for every team-game with minutes_reconciled | PASS |
| season_type never NA in any table | PASS |
| shots made-points per team-game equals team pts minus FTM | PASS |

## Minutes gate (exactly 5 inferred starters per team-period; see build_minutes())

Pass rate, regular: 1.0000
Pass rate, playoffs: 1.0000
Unreconciled team-games (minutes_reconciled == FALSE; summed minutes more than 1 minute from 200 + 25*(n_periods-4)): 0 of 706 (0.00%).
Unreconciled by season type: 
Team-periods without exactly 5 inferred starters (left as inferred, not guessed): 0
Largest absolute deviation: 0.00 minutes.
