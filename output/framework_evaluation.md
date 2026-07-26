# Framework Evaluation (AMENDMENT_01 Section 2c)

Generated: 2026-07-20 04:50:18 UTC

This report covers two of the four AMENDMENT_01 Section 2c
framework-evaluation criteria: split-half stability and
alternative-stratification sensitivity. The other two live elsewhere:
garbage-time disposition in output/trajectory_sensitivity.md (R/06), and
face validity qualitatively in output/findings.md.

## 1. Split-half stability

For each team, games are split into a first half and second half by that
team's own game_index median. Each metric's team-level mean is computed
in each half, then correlated across the 15 teams. A high correlation
means the identity metric is a stable within-season signal (real
signal, not noise); a low correlation means the metric is noisy
game-to-game and any team ranking built on it is fragile.

| metric | first-half/second-half correlation |
| --- | --- |
| mid_share | 0.842 |
| pullup_share | 0.842 |
| fg3a_rate | 0.832 |
| paint_fgm_share | 0.811 |
| atb3_share | 0.806 |
| ra_share | 0.801 |
| transition_share | 0.794 |
| driving_share | 0.775 |
| transition_pts_per_poss | 0.692 |
| cutting_share | 0.645 |
| shot_generation_per100 | 0.632 |
| live_ball_tov_rate | 0.579 |
| corner3_share | 0.576 |
| shot_making_residual | 0.563 |
| pace_per40 | 0.541 |
| ft_rate | 0.479 |
| paint_share | 0.463 |
| tov_rate | 0.436 |
| putback_share | 0.423 |
| off_tov_share | 0.307 |
| secondchance_share | 0.064 |
| assisted_rate | -0.333 |

Most stable: mid_share (0.842), pullup_share (0.842), fg3a_rate (0.832). Least stable: off_tov_share (0.307), secondchance_share (0.064), assisted_rate (-0.333).

## 2. Alternative-stratification sensitivity (zone-only vs zone x shot_class x context)

The stratified expected-points baseline is recomputed under a coarser,
zone-only stratification (dropping shot_class and context) and rolled up
to team-level shot generation and shot making, then compared to the main
zone x shot_class x context baseline via Spearman rank correlation.

Shot generation rank correlation (main vs zone-only): 0.979

Shot making rank correlation (main vs zone-only): 0.996

GSV: main generation rank 5 (alt rank 3), main making rank 8 (alt rank 8). GSV's position moves under the coarser stratification -- flagged.

## Conclusion

Split-half stability shows which identity metrics carry a real, within-season signal versus which are noisy enough that a single-season team ranking on them should be read cautiously. Alternative-stratification sensitivity shows whether the shot generation and shot making conclusions are an artifact of the fine zone x shot_class x context strata or hold up under a coarser stratification. Together these two checks bound how much weight the framework's identity and shot-making reads can carry into the deadline-read table.
