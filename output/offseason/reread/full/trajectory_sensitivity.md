# Trajectory Sensitivity: Garbage-Time Exclusion (AMENDMENT_01 2c)

Generated: 2026-11-23 18:17:37 UTC

Pre-registered in output/eda_notes.md section 6. The five shortlist
trajectory metrics were recomputed per team-game excluding garbage-time
possessions and shots (period >= 4 and absolute score margin >= 20),
then re-fit with the same trajectory machinery. The expected-points
baseline was held fixed at its all-shots values.

Garbage-time possessions league-wide: 4.0% of live-ball possessions.

Per metric: main league trend and p, garbage-excluded (ng) league trend
and p, whether the trend sign flipped, whether significance crossed 0.05,
and how many of the 15 teams changed improving/flat/declining classification.

- transition_share: main 0.0000 (p=0.833) | ng 0.0000 (p=0.946) | sign flip: no | sig change: no | class flips: 0/15
- transition_pts_per_poss: main -0.0007 (p=0.600) | ng -0.0005 (p=0.730) | sign flip: no | sig change: no | class flips: 2/15
- assisted_rate: main 0.0005 (p=0.099) | ng 0.0004 (p=0.284) | sign flip: no | sig change: no | class flips: 2/15
- live_ball_tov_rate: main 0.0000 (p=0.820) | ng -0.0000 (p=0.952) | sign flip: YES | sig change: no | class flips: 2/15
- shot_making_residual: main 0.0717 (p=0.051) | ng 0.0770 (p=0.048) | sign flip: no | sig change: YES | class flips: 4/15

## Conclusion

At least one league-level trend flips sign or crosses the p < 0.05 significance boundary under garbage-time exclusion (see the rows flagged YES above). Report this as a caveat and do not publish the affected trajectory claim without it.

Per-team improving/flat/declining labels move for 10 team-metric cells in total (most for shot_making_residual, 4 of 15 teams). These per-team labels are interval-caveated directional reads, not standalone findings (AMENDMENT_01 section 1): most per-team intervals already span zero. Movement under a 3.9% possession swing is expected and reinforces the standing rule to report per-team trajectory only with its interval, and to base strong claims on the league fixed effect, never on a single team's label.
