# WNBA 2026 Trade Deadline Framework: Findings (draft)

Draft of the quantitative framework findings for the 2026 WNBA trade deadline
(August 2). This document covers the reproducible framework: schedule-adjusted
identity, shot generation, shot making, trajectory, and the feasibility-conditioned
deadline read. The Synergy case studies (GSV, TOR, PDX) and the league-wide
structural paragraph are attended work and are left as marked stubs at the end.

Every quantitative claim here reproduces from the numbered scripts in `R/` against
open play-by-play data. Cap context is reported as a flexibility tier, never a
dollar figure. Descriptor-derived features are shot-creation profiles, never play
types. The expected-points layer is a stratified expected-points baseline
(qSQ-lite), not a trained model.

## 0. Data and reconciliation

- Source: `shufinskiy/nba_data` open play-by-play (cdn feed), pinned commit
  `773ce29`. 182 games, 364 team-games, 24,794 field-goal attempts through the
  midseason snapshot.
- cdn vs nbastats v2 reconciliation: total absolute deltas of 1 FGA and 1 FGM
  across all 364 team-games (both traced to one game, IND game 1022600004). 3PA
  reconciles exactly. Documented, not hidden.
- shotdetail covers 14 of 15 teams (Toronto absent), so every shot-level feature
  is built from the cdn feed (area / areaDetail / descriptor), never shotdetail.
- Test suite: 38 expectations, 0 failures, 0 skipped, including the data-dependent
  baseline-table, cdn-vs-v2, and possession-invariant checks.

## 1. Schedule-adjusted identity (Leg 1)

For each style metric we fit `metric ~ is_home + (1 | team) + (1 | opponent)` in
lme4, extract team BLUPs (schedule-adjusted identity), and report the ICC (share
of variance that is stable team identity versus matchup noise).

- Identity is carried by shot location, not by rate stats. Highest ICCs:
  `mid_share` 0.53, `fg3a_rate` 0.36, `atb3_share` 0.31, `pullup_share` 0.29,
  `ra_share` 0.26. Lowest: `assisted_rate` 0.0004, `transition_pts_per_poss`
  0.006, `off_tov_share` 0.017. A team's shot-location profile is a real,
  stable identity; its assisted-rate is close to noise once schedule is removed.
- Schedule adjustment moves ranks very little: mean absolute rank change 0.31,
  maximum 5 (MIN on transition efficiency, raw rank 9 to adjusted 14). The one
  decision-relevant mover is PDX on assisted rate, raw rank 5 to adjusted rank 1:
  its schedule was suppressing an already high assisted-ball-movement identity.
- Face validity (evaluation criterion, Section 6): the adjusted BLUPs match known
  identities. GSV sits first in adjusted `fg3a_rate` and `atb3_share`, the
  league's most extreme perimeter profile, consistent with its reputation as the
  most stylistically extreme team. See `output/identity_map.png`.

## 2. Shot generation and shot making (Legs 2 and 3)

A stratified expected-points baseline (qSQ-lite, not a trained model) gives
league-average points per shot by zone x shot-creation profile x context
(transition / halfcourt / second-chance), 49 realized strata, 2026 in-season
shots only. Per team:

- Shot generation = expected points per 100 possessions given the team's shot diet
  (the quality of looks the process creates).
- Shot making = actual minus expected points per 100 (conversion above or below
  the looks created).

The decomposition separates teams the record conflates:

- ATL: shot generation 100th percentile, shot making 0th. The looks are the best
  in the league; the points left on the floor are a finishing result, not a
  process failure.
- LVA: shot generation 7th percentile, shot making 100th. The inverse: poor looks
  carried by finishing that a baseline reads as unsustainable.
- GSV (the flagship): shot generation 71st percentile, shot making 50th. Neither a
  generation deficit nor a making deficit (see H3 below).

The ATL and LVA rows are mirror images, and the framework refuses to let hot or
cold finishing drive the read. That discipline is the point of the decomposition.
See `output/generation_vs_making.png`.

## 3. Trajectory (what teams are becoming)

Trajectory models fit `metric ~ game_index + (1 + game_index | team) + (1 |
opponent)` on the five-metric shortlist. All five hit a singular random-slope fit
(the small-sample boundary case at 23 to 26 games per team) and used the
documented random-intercept-plus-residual-slope fallback. `game_index` is each
team's own game number, so uneven schedules stay comparable.

League-wide trends (the test of the hypotheses at scale), all not statistically
distinguishable from zero:

| metric | league trend per game | p |
| --- | --- | --- |
| transition_share | -0.00008 | 0.73 |
| transition_pts_per_poss | 0.0038 | 0.21 |
| assisted_rate | -0.0002 | 0.77 |
| live_ball_tov_rate | 0.0002 | 0.36 |
| shot_making_residual | 0.115 | 0.20 |

See `output/trajectory_small_multiples.png`, which shows the per-team slopes with
95% intervals: most intervals span zero, so per-team labels are directional, not
standalone claims.

## 4. Results against the hypotheses registry

Written against the pre-registered H1 / H2 / H3 / H-null registry in
`output/eda_notes.md`. A published null is a finding, not a failure.

- H1 (transition volume and efficiency rise league-wide with reps): NOT SUPPORTED.
  Transition share trends slightly negative (-0.00008 per game, p 0.73) and
  transition efficiency trends positive but not distinguishable from zero (0.0038,
  p 0.21). No league-wide reps effect is visible in the first-half sample.
- H2 (chemistry proxies improve: assisted rate rises, live-ball turnover rate
  falls, strongest for expansion teams TOR and PDX): NOT SUPPORTED at the league
  level. Assisted rate trends the wrong way (-0.0002, p 0.77) and live-ball
  turnover rate trends the wrong way (0.0002, p 0.36), both not significant. At the
  team level PDX and TOR do lean positive on assisted rate, and PDX's
  schedule-adjusted assisted rate is first in the league, but every per-team
  interval spans zero, so this is a direction, not a result.
- H3 (GSV's low field-goal percentage is shot making below expectation on an
  acceptable shot diet; trajectory: is GSV trending toward expectation or flat):
  the premise is REFUTED. GSV makes shots at or slightly above expectation (shot
  making 50th percentile, roughly +0.6 points per 100). GSV's low field-goal
  percentage is not a making deficit against its own shot diet; it is an identity
  of high-variance perimeter shot selection (first in 3-point-attempt rate and
  above-the-break-3 rate). GSV's making trajectory is directionally improving but
  its interval spans zero, so the honest read is at expectation and not
  distinguishable from flat.
- H-null: H1 and H2 are published nulls. The framework's value here is a clean
  negative: the first-half reps and chemistry stories that priors would expect are
  not present in this open-data sample, and the decomposition says so plainly.

## 5. The deadline read (synthesis)

The deadline-read table (`output/deadline_read.csv`, `output/deadline_read.md`) is
one row per team: identity summary, generation and making percentiles, the
shot-making-residual trajectory, cap-context tier, and a feasibility-conditioned
lever (acquire / adjust / hold). The lever is generation-and-making-driven and is
gated on cap feasibility: only an acquire read is conditioned, becoming
constrained for a tight team and requiring salary out for a capped team, grounded
in the hard-cap rule (`data/reference/cba_rules_2026.md` Section 2).

Lever distribution: 5 acquire (WAS on the room tier; NYL, PHX, SEA constrained by
limited room; LVA constrained, requires salary out), 4 adjust (IND, LAS, PDX,
TOR), 6 hold (ATL, CHI, CON, DAL, GSV, MIN).

Headline read (the framework's sharpest disagreement with consensus): ATL is told
to HOLD. A record-and-eye read of the team that leaves the most points on the
floor in the league would say buy a finisher. The framework says the looks are
100th-percentile and the losses are finishing, which a deadline acquisition of
shot creation does not fix. The open risk, stated honestly: ATL's shot-making
trajectory is declining (interval spans zero), so this hold is a bet on
generation, not a bet that the making trend reverts up. If making is a personnel
ceiling rather than variance, this is the read that ages badly. It is the piece's
headline bet and is presented as a bet, not a certainty.

Adjust drivers (so the softest lever is not a hedge): IND is overperforming its
process (making 86th percentile on 36th-percentile generation), an argument to
consolidate rather than overpay; TOR and PDX sit in the competitive middle on both
axes, an argument for scheme-level gains over a splashy move.

Limitations a front office would raise (from the gm-agent review, carried honestly
rather than papered over):

- The lever encodes no buyer-or-seller posture. WAS is worst on both axes and
  likely rebuilding, yet the rule maps bottom-generation to acquire mechanically; a
  cellar team acquiring at the deadline is a different act than a contender adding.
- The salary floor is not yet in the cap tier. The team-salary floor is 85% of the
  cap (`cba_rules_2026.md` Section 1), and the two room-tier teams (WAS, PDX) sit
  below it, so they are pushed to add salary rather than free to stand pat. A
  proposed below-floor flag is pending triage.
- Roster spots and market supply are unmodeled: acquire and minimum-or-depth reads
  both presume an open spot and an available profile, and four tight-or-capped
  teams chasing the same depth tier is a thin market.
- Forward strength-of-schedule is not modeled (the open play-by-play has no forward
  schedule). The one calendar fact carried is the World Cup Hiatus (August 31 to
  September 16), which makes a hold a mid-schedule reset window.

## 6. Framework evaluation (AMENDMENT_01 Section 2c)

- Face validity: the adjusted identity BLUPs match known team identities (GSV
  perimeter-extreme, first in adjusted 3-point-attempt rate). See Section 1.
- Split-half stability (`output/framework_evaluation.md`): each team's first-half
  versus second-half mean, correlated across teams. Shot-location identities are
  stable (`mid_share` 0.84, `pullup_share` 0.84, `fg3a_rate` 0.83); chemistry and
  rate metrics are noisy (`assisted_rate` -0.33, `secondchance_share` 0.06). Shot
  generation (0.63) and shot making (0.56) are moderately stable, so single-season
  team making and generation reads are directional and should be read with that
  caution. This split-half ordering tracks the ICC ordering closely, an
  independent confirmation of which identities carry real signal.
- Sensitivity to stratification (`output/framework_evaluation.md`): recomputing the
  expected-points baseline with a coarser zone-only stratification preserves the
  team ordering almost exactly (Spearman rank correlation 0.98 for generation, 1.00
  for making). The headline generation and making conclusions are not an artifact
  of the fine strata. GSV's generation rank shifts from 5th to 3rd under the coarser
  stratification (flagged); its making rank is unchanged.
- Garbage-time disposition (`output/trajectory_sensitivity.md`): garbage-time
  possessions (period 4 or later, absolute margin 20 or more) are flagged, not
  excluded, at 3.9% of possessions. The sensitivity re-run confirms all five
  trajectory league trends keep their sign and their non-significance when
  garbage-time is excluded, so the trajectory nulls are not garbage-time artifacts.

## 7. Attended work (not in this draft)

TODO (Synergy case studies): full fit read for GSV, lighter reads for TOR and PDX,
in coaching vocabulary, with candidate profiles (archetype plus contract class,
not named trades). Synergy-derived numbers stay in case-study prose with
attribution and never enter models, data, or output tables. Left as a stub.

TODO (AMENDMENT_02 Section 3d structural paragraph): the league-wide read on the
first post-CBA deadline (contract-length distribution after the 2026 free-agency
rush, movable-expiring liquidity, supermax immobility, the World Cup break as a
hold incentive), prose plus one summary count from the cap-context table. Left as a
stub.

---

Provenance: framework findings reproduce from `R/01`-`R/10` against `shufinskiy/nba_data`
commit `773ce29`. Cap tiers from `data/reference/cap_context_2026.csv` (Spotrac,
2026-07-19), CBA mechanics from `data/reference/cba_rules_2026.md`, both to be
re-verified before publish (AMENDMENT_02 Section 4).
