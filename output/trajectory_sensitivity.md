# Trajectory Sensitivity: Garbage-Time Exclusion (AMENDMENT_01 2c)

Generated: 2026-07-19 23:22:08 UTC

Pre-registered in output/eda_notes.md section 6. The five shortlist
trajectory metrics were recomputed per team-game excluding garbage-time
possessions and shots (period >= 4 and absolute score margin >= 20),
then re-fit with the same trajectory machinery. The expected-points
baseline was held fixed at its all-shots values.

Garbage-time possessions league-wide: 3.9% of live-ball possessions.

Per metric: main league trend and p, garbage-excluded (ng) league trend
and p, whether the trend sign flipped, whether significance crossed 0.05,
and how many of the 15 teams changed improving/flat/declining classification.

- transition_share: main -0.0001 (p=0.729) | ng -0.0000 (p=0.862) | sign flip: no | sig change: no | class flips: 1/15
- transition_pts_per_poss: main 0.0038 (p=0.214) | ng 0.0038 (p=0.224) | sign flip: no | sig change: no | class flips: 1/15
- assisted_rate: main -0.0002 (p=0.772) | ng -0.0003 (p=0.681) | sign flip: no | sig change: no | class flips: 2/15
- live_ball_tov_rate: main 0.0002 (p=0.364) | ng 0.0002 (p=0.547) | sign flip: no | sig change: no | class flips: 5/15
- shot_making_residual: main 0.1152 (p=0.199) | ng 0.1237 (p=0.180) | sign flip: no | sig change: no | class flips: 2/15

## Conclusion

League-level trends are stable under garbage-time exclusion: no metric changes the sign of its league trend or its significance status at p < 0.05. Every league trend is non-significant (p > 0.05) both with and without garbage-time possessions, so the published-claim basis (the league-wide fixed effect) is not a garbage-time artifact.

Per-team improving/flat/declining labels move for 11 team-metric cells in total (most for live_ball_tov_rate, 5 of 15 teams). These per-team labels are interval-caveated directional reads, not standalone findings (AMENDMENT_01 section 1): most per-team intervals already span zero. Movement under a 3.9% possession swing is expected and reinforces the standing rule to report per-team trajectory only with its interval, and to base strong claims on the league fixed effect, never on a single team's label.
