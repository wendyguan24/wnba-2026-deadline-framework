# Data dictionary: analysis-ready tables

Built by `R/04b_analysis_tables.R` from the reconciled pipeline (`R/01` to `R/04`),
pin `46488f0`, season 2026. Stored as parquet in `data/processed/full2026/tables/`
(gitignored, regenerable). Counts per table are in `output/offseason/tables_report.md`.

## Quick start

```r
source("R/00_config.R"); source("R/load_tables.R")
list_tables()
load_table("player_games", "regular")   # "regular", "playoffs" or "all"
```

## Rules for every table

- Regular season and playoffs are separate populations. Pick one with `season_type`; if you
  use `"all"`, carry the flag into the model and state why.
- `game_id` is the cdn/NBA game id as a double (for example 1022600001 regular season,
  1042600101 playoffs). Raw-copy tables (`possessions`, `pbp_events`) keep the original
  name `gameId`.
- Home/away comes from cdn scoring events (`derive_home_away()` in `R/04_reconcile.R`), not
  from shotdetail. It agrees with shotdetail HTM/VTM in every game that has shotdetail rows.
- Toronto has no shotdetail rows in the regular season (known source gap). Nothing in these
  tables depends on shotdetail except `game_date`, which falls back to the cdn UTC date.
- Minutes are reconstructed from substitution events, not taken from an official box score.
  The source has no period-start lineups, so starters are inferred per team-period
  (`build_minutes()` in `R/lib_player_box.R`): seed with players whose first substitution is
  "out" or who have a non-substitution event earlier in the game clock than their first
  sub-in (technical fouls and same-clock events do not count); if fewer than 5, fill from the
  previous period's end-of-period on-court set (players with no sub-in first), only when that
  gives exactly 5. This differs from the v1 R/13 rule, which missed players with zero events
  in a period. One team-period (1042600304 ATL, period 1) still has 4 inferred starters and
  is flagged via `minutes_reconciled`.

## games

Grain: one row per game. Primary key: `game_id`. Source: `R/04b`, from cdn plus shotdetail dates.

| column | type | meaning |
|---|---|---|
| game_id | double | game id |
| season | integer | 2026 |
| season_type | character | regular or playoffs |
| game_date | date | local game date (shotdetail GAME_DATE) |
| home_team, away_team | character | tricodes |
| home_pts, away_pts | integer | final score from the last cdn event |
| n_periods | integer | periods played; more than 4 means overtime |

## team_games

Grain: one row per team per game. Primary key: `game_id` + `team`.

| column | type | meaning |
|---|---|---|
| game_id, season, season_type | | as above |
| team, opponent | character | tricodes |
| is_home | logical | team was home |
| pts, opp_pts | integer | final score |
| win | logical | pts > opp_pts |
| possessions | integer | possession rows for the team, excluding out-of-band technical/flagrant FT rows (R/03) |
| FGA, FGM, AST, FG3A | integer | from `compute_team_game_counts_cdn()` (R/04) |
| minutes_reconciled | logical | TRUE when summed reconstructed player minutes for the team-game are within 1 minute of 200 + 25*(n_periods-4). Kept as a guard: FALSE for 1 of 706 team-games (playoff game 1042600304, ATL: the fifth period-1 starter has no events and no earlier period to infer from, so 10 minutes are missing). Counts are stored in `data/reference/pipeline_baseline.csv` (`minutes_unreconciled_team_games`, written by R/04b, preserved by R/04). |
| FG3M, FTM, FTA, OREB, DREB, STL, BLK, TOV, PF | integer | counted from cdn events by the event's team; OREB, DREB and TOV include team rebounds and team turnovers; PF is personal plus offensive fouls (no technicals) |

## player_games

Grain: one row per player per game (players with at least one cdn player event).
Primary key: `game_id` + `team` + `person_id`. Source: `build_box()` and `build_minutes()` in
`R/lib_player_box.R` (extracted from R/13), applied per game.

| column | type | meaning |
|---|---|---|
| game_id, season, season_type, team | | |
| person_id | double | cdn person id |
| player_name | character | modal name for that game (cdn uses surnames) |
| minutes | double | reconstructed on-court minutes |
| FG2M, FG3M, FGM, FGA, FTM, FTA, OREB, DREB, AST, STL, BLK, TOV, PF, PTS | integer | box counts as in R/13; AST is credited via `assistPersonId` |
| poss_used | double | FGA + 0.44 FTA + TOV |
| game_score | double | Hollinger Game Score (NBA weights, unvalidated for the WNBA) |
| minutes_reconciled | logical | the team-game flag from `team_games`; rows with FALSE have unreliable `minutes` for that team |

Caveat: a player with only an assist and no other event in a game gets no row, so AST can be
undercounted by that case. Points reconcile to team points in every team-game.

## players

Grain: one row per `person_id` (season_type is `both`; the `load_table` season filter does not apply).

| column | type | meaning |
|---|---|---|
| season, season_type | | 2026, both |
| person_id, player_name | | modal name across games |
| teams | character | comma-separated tricodes played for |
| games, games_regular, games_playoffs | integer | games with a player-event row |
| minutes_regular, minutes_playoffs | double | reconstructed minutes by season type |

## possessions

Copy of `possessions.rds` (R/03) plus `season`. Grain: one row per possession; technical or
flagrant FTs shot out of band are separate rows with `outcome == "technical_ft"`. Columns:
`possession_id, gameId, team, opponent, period, start_event, end_event, start_clock, end_clock,
outcome, points, is_transition, is_2ndchance, is_off_turnover, season_type`.

## pbp_events

Copy of `pbp_events.rds` (R/02) plus `season`: raw cdn columns (see upstream) plus `season_type`,
`parsed_clock_seconds`, `is_fastbreak`, `is_fromturnover`, `is_2ndchance`, `is_pointsinthepaint`
and `team_full_name`. Grain: one row per event, key `gameId` + `orderNumber`.

## shots

Grain: one row per cdn field-goal attempt. Key: `game_id` + `order_number`.

| column | type | meaning |
|---|---|---|
| game_id, season, season_type, order_number | | |
| team, person_id, player_name | | shooter |
| period, clock_seconds | | seconds left in period |
| shot_type | character | 2pt or 3pt |
| sub_type, descriptor | character | cdn shot descriptors (shot-creation profile inputs, not play types) |
| area, area_detail, side, shot_distance | | cdn zone fields |
| x, y, x_legacy, y_legacy | double | cdn coordinates |
| made | logical | |
| points | integer | 0, 2 or 3 |
| is_assisted, assist_person_id | | |
| is_fastbreak, is_2ndchance, is_fromturnover, is_pointsinthepaint | logical | cdn qualifier flags |

Made-shot points per team-game equal team points minus FTM.
