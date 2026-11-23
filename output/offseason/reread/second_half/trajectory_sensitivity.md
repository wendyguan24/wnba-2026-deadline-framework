# Trajectory Sensitivity: Garbage-Time Exclusion (AMENDMENT_01 2c)

Generated: 2026-11-23 18:17:18 UTC

Pre-registered in output/eda_notes.md section 6. The five shortlist
trajectory metrics were recomputed per team-game excluding garbage-time
possessions and shots (period >= 4 and absolute score margin >= 20),
then re-fit with the same trajectory machinery. The expected-points
baseline was held fixed at its all-shots values.

Garbage-time possessions league-wide: 4.1% of live-ball possessions.

Per metric: main league trend and p, garbage-excluded (ng) league trend
and p, whether the trend sign flipped, whether significance crossed 0.05,
and how many of the 15 teams changed improving/flat/declining classification.

- transition_share: main 0.0007 (p=0.040) | ng 0.0007 (p=0.050) | sign flip: no | sig change: no | class flips: 0/15
- transition_pts_per_poss: main -0.0062 (p=0.152) | ng -0.0055 (p=0.220) | sign flip: no | sig change: no | class flips: 1/15
- assisted_rate: main 0.0005 (p=0.581) | ng 0.0005 (p=0.587) | sign flip: no | sig change: no | class flips: 0/15
- live_ball_tov_rate: main 0.0007 (p=0.039) | ng 0.0006 (p=0.093) | sign flip: no | sig change: YES | class flips: 4/15
- shot_making_residual: main -0.2716 (p=0.052) | ng -0.2659 (p=0.029) | sign flip: no | sig change: YES | class flips: 5/15

## Conclusion

At least one league-level trend flips sign or crosses the p < 0.05 significance boundary under garbage-time exclusion (see the rows flagged YES above). Report this as a caveat and do not publish the affected trajectory claim without it.

Per-team improving/flat/declining labels move for 10 team-metric cells in total (most for shot_making_residual, 5 of 15 teams). These per-team labels are interval-caveated directional reads, not standalone findings (AMENDMENT_01 section 1): most per-team intervals already span zero. Movement under a 3.9% possession swing is expected and reinforces the standing rule to report per-team trajectory only with its interval, and to base strong claims on the league fixed effect, never on a single team's label.
