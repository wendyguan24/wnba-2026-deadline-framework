# Reconciliation Report (offseason pin)

Generated: 2026-11-23 17:09:45 UTC
Pinned commit: 46488f0f8e1cab58fc1256511ea808166a443a15

Regular season and playoffs are separate populations; every section is per season type.

## Regular

Pin: 46488f0. Games: 330. Date range: 2026-05-08 to 2026-09-24.
Rows: cdn 161135, nbastats v2 133244, shotdetail 42297. Team-games: 660.

### Possession points vs final score

Team-games checked: 660. Mismatches (or missing): 0.
Home/away derived from cdn scoring events agrees with shotdetail HTM/VTM in 330 of 330 games with shotdetail rows.

### cdn vs nbastats v2

Team-games compared: 660
Sum of |FGA delta|: 3 | |FGM delta|: 2 | |AST delta|: 5 | |FG3A delta|: 1
Largest single-game FGM delta: -1 (game 1022600004, team IND)

Team-games with any nonzero delta (cdn minus v2):
| gameId | team | FGA_delta | FGM_delta | AST_delta | FG3A_delta |
|---|---|---|---|---|---|
| 1022600004 | IND | -1 | -1 | -1 | 0 |
| 1022600022 | IND | 0 | 0 | -2 | 0 |
| 1022600065 | MIN | 0 | 0 | -1 | 0 |
| 1022600199 | CHI | -1 | -1 | -1 | 0 |
| 1022600210 | MIN | 1 | 0 | 0 | 1 |

### shotdetail coverage

Teams present: 14 of 15 expected. Missing: Toronto Tempo

### Games per team

| team | games |
|---|---|
| ATL | 44 |
| CHI | 44 |
| CON | 44 |
| DAL | 44 |
| GSV | 44 |
| IND | 44 |
| LAS | 44 |
| LVA | 44 |
| MIN | 44 |
| NYL | 44 |
| PDX | 44 |
| PHX | 44 |
| SEA | 44 |
| TOR | 44 |
| WAS | 44 |

## Playoffs

Pin: 46488f0. Games: 23. Date range: 2026-09-27 to 2026-10-31.
Rows: cdn 10776, nbastats v2 9052, shotdetail 3067. Team-games: 46.

### Possession points vs final score

Team-games checked: 46. Mismatches (or missing): 0.
Home/away derived from cdn scoring events agrees with shotdetail HTM/VTM in 23 of 23 games with shotdetail rows.

### cdn vs nbastats v2

Team-games compared: 46
Sum of |FGA delta|: 0 | |FGM delta|: 0 | |AST delta|: 0 | |FG3A delta|: 0
Largest single-game FGM delta: 0 (game 1042600101, team MIN)

Team-games with any nonzero delta (cdn minus v2):
none

### shotdetail coverage

Teams present: 8 of 8 expected. Missing: none

### Games per team

| team | games |
|---|---|
| ATL | 12 |
| DAL | 3 |
| GSV | 13 |
| IND | 3 |
| LVA | 6 |
| MIN | 2 |
| NYL | 5 |
| WAS | 2 |

## v1 subset regression

v1 subset: first 182 regular-season gameIds (1022600001 to 1022600182). Game 182 dated 2026-07-16; game 183 dated 2026-07-20.

HANDOFF §4 baseline table (8 teams, 6 metrics) on the v1 subset. Max abs deltas:
FGA 0 | FG% 0 | 3PA rate 0 | assisted rate 0 | fastbreak share 0 | paint share 0

## Gate

Per CLAUDE.md, feature and model code is not built on this layer until this report
is reviewed.
