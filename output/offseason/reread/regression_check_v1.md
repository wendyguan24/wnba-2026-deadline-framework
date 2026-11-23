# Regression check: first_half window vs committed v1 outputs

Tolerance: max abs diff <= 1e-06; character/logical columns must match exactly; row counts must match.

| file | rows v1 | rows first_half | rows joined | max abs diff | label mismatches | pass |
|---|---|---|---|---|---|---|
| icc_table.csv | 20 | 20 | 20 | 0 | 0 | TRUE |
| team_generation_making.csv | 15 | 15 | 15 | 0 | 0 | TRUE |
| team_rank_deltas.csv | 300 | 300 | 300 | 0 | 0 | TRUE |
| team_trajectories.csv | 75 | 75 | 75 | 0 | 0 | TRUE |
| trajectory_league_trends.csv | 5 | 5 | 5 | 0 | 0 | TRUE |

Overall: PASS

## Per column

| file | column | max abs diff | label mismatches |
|---|---|---|---|
| icc_table.csv | icc | 0 | 0 |
| team_generation_making.csv | fga | 0 | 0 |
| team_generation_making.csv | poss_count | 0 | 0 |
| team_generation_making.csv | expected_pts | 0 | 0 |
| team_generation_making.csv | actual_pts | 0 | 0 |
| team_generation_making.csv | shot_generation_per100 | 0 | 0 |
| team_generation_making.csv | shot_making_per100 | 0 | 0 |
| team_generation_making.csv | actual_pts_per100 | 0 | 0 |
| team_trajectories.csv | slope | 0 | 0 |
| team_trajectories.csv | ci_low | 0 | 0 |
| team_trajectories.csv | ci_high | 0 | 0 |
| team_trajectories.csv | trajectory | n/a | 0 |
| team_trajectories.csv | interval_spans_zero | n/a | 0 |
| trajectory_league_trends.csv | league_trend | 0 | 0 |
| trajectory_league_trends.csv | league_trend_p | 0 | 0 |
| trajectory_league_trends.csv | fallback_used | n/a | 0 |
| team_rank_deltas.csv | raw_value | 0 | 0 |
| team_rank_deltas.csv | raw_rank | 0 | 0 |
| team_rank_deltas.csv | adjusted_value | 0 | 0 |
| team_rank_deltas.csv | adjusted_rank | 0 | 0 |
| team_rank_deltas.csv | delta | 0 | 0 |
