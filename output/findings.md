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
- The auxiliary shotdetail feed covers only 14 of 15 teams (Toronto is absent from
  shotdetail), so to keep all 15 teams on equal footing every shot-level feature is
  built from the cdn feed (area / areaDetail / descriptor), never shotdetail. Toronto
  itself is fully present in the analysis via the cdn feed (24 games, 1,630 shots with
  zone data, and rows in every framework output); the gap is limited to the unused
  shotdetail feed and affects no published number.
- Test suite: 38 expectations, 0 failures, 0 skipped, including the data-dependent
  baseline-table, cdn-vs-v2, and possession-invariant checks (see
  `output/test_summary.txt`, reproduced via `Rscript tests/testthat.R`).

## 1. Schedule-adjusted identity (Leg 1)

For each style metric we fit `metric ~ is_home + (1 | team) + (1 | opponent)` in
lme4, extract team BLUPs (schedule-adjusted identity), and report the ICC (share
of variance that is stable team identity versus matchup noise).

- Identity is carried by shot location, not by rate stats. Highest ICCs:
  `mid_share` 0.53, `fg3a_rate` 0.36, `atb3_share` 0.31, `pullup_share` 0.29,
  `ra_share` 0.26. Lowest: `assisted_rate` 0.0004, `transition_pts_per_poss`
  0.006, `off_tov_share` 0.017. A team's shot-location profile is a real,
  stable identity; its assisted-rate is close to noise once schedule is removed.
- Schedule adjustment moves ranks very little (mean absolute rank change 0.31,
  maximum 5), and the few larger moves land on low-ICC metrics (transition
  efficiency, assisted rate) whose rankings are close to noise, so they are not
  read as identity shifts.
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

- ATL: shot generation 1st of 15, shot making 15th of 15. The looks are the best
  in the league; the points left on the floor are a finishing result, not a
  process failure.
- LVA: shot generation 14th of 15, shot making 1st of 15. The inverse: poor looks
  carried by finishing that a baseline reads as unsustainable.
- GSV (the flagship): shot generation 5th of 15, shot making 8th of 15. Neither a
  generation deficit nor a making deficit (see H3 below).

The ATL and LVA rows are mirror images, and the framework refuses to let hot or
cold finishing drive the read. That discipline is the point of the decomposition.
These are single-season reads: shot making is only moderately stable split-half
(0.56, Section 6), so "finishing result" and "unsustainable" are directional
signals to act on with that caution, not settled facts. See
`output/generation_vs_making.png`.

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

These league-trend p-values are approximate: all five metrics used the documented
random-intercept-plus-residual-slope fallback after the full random-slope fit was
singular. AMENDMENT_01's stated fallback output is the league trend plus per-team
observed-minus-expected late-season residuals; the per-team improving/flat/declining
labels shown here go one step further than that, which is why they are reported only
with their intervals.

See `output/trajectory_small_multiples.png`, which shows the per-team slopes with
95% intervals: most intervals span zero, so per-team labels are directional, not
standalone claims.

The practical consequence for the deadline read: no team's finishing trajectory
this half-season clears "clearly improving" (every per-team interval spans zero or
nearly so), so a trajectory arrow cannot by itself justify a buy. The deadline
read treats this honestly. Bubble teams whose interval spans zero default to hold
rather than reading a buy or sell into a directionless slope (this is why TOR,
improving on the point estimate but with an interval spanning zero, reads
hold-and-reassess, not lean buy). Trajectory earns its place as a required column
by flagging what is NOT distinguishable, not by manufacturing a direction.

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
  team level PDX and TOR do lean positive on assisted rate, but both PDX and TOR
  intervals span zero, so this is a direction, not a result. The assisted-rate
  intervals that do exclude zero (DAL, IND, NYL) point the wrong way for H2, if
  anything strengthening the null.
- H3 (GSV's low field-goal percentage is shot making below expectation on an
  acceptable shot diet; trajectory: is GSV trending toward expectation or flat):
  the premise is REFUTED. GSV makes shots at or slightly above expectation (shot
  making 8th of 15; shot_making_per100 is +0.6 in
  output/team_generation_making.csv). GSV's low field-goal
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
one row per team. The bottom line is the Recommendation column: the action
(amplify / adjust / gap-fill / reassess / sell / a bubble judgment call),
conditioned on the team's standing-derived window (buyer / bubble / seller, from
`R/12_standing.R`) and its cap tier. The rest of the row is the diagnosis behind
that action: an offense-diagnosis label (generation-short / balanced /
generation-rich), the generation and making league ranks (of 15, 1 = best), the finishing
trajectory, the cap-context tier, and the descriptive identity summary. The
offense diagnosis is generation-and-making-driven and is descriptive only; it is
not itself an instruction. Acquire feasibility is conditioned on the cap inside
the recommendation logic: a capped team's acquire requires salary out, a tight
team's is limited to minimum-or-depth, grounded in the hard-cap rule
(`data/reference/cba_rules_2026.md` Section 2).

Diagnosis and window can point in opposite directions, and the recommendation
reconciles them. A generation-short offense diagnoses as an acquire candidate, but
if the standing layer reads the team as a seller the recommendation is
sell/accumulate, not a buy: PHX and SEA diagnose short on generation yet are out
of the race, so the read is to deal expirings, not to add. This is the buyer-or-
seller posture the earlier draft of this section said the framework lacked; the
`R/12` standing layer now supplies it, so the diagnosis and the action are
separate columns by design.

Headline read (the framework's sharpest disagreement with consensus): ATL's read
is hold, a bubble judgment call the diagnosis backs rather than a buy. A
record-and-eye read of the team that leaves the most points on the
floor in the league would say buy a finisher. The framework says the looks are
1st of 15 and the losses are finishing, which a deadline acquisition of
shot creation does not fix. The open risk, stated honestly: ATL's shot-making
trajectory is declining (interval spans zero), so this hold is a bet on
generation, not a bet that the making trend reverts up. If making is a personnel
ceiling rather than variance, this is the read that ages badly. It is the piece's
headline bet and is presented as a bet, not a certainty.

Balanced offenses, split by window (so the softest diagnosis is not a hedge): four
teams diagnose balanced (mid generation), and the window is what separates their
reads. IND is a buyer and the one balanced offense told to adjust: it is
overperforming its process (making 3rd of 15 on 10th-of-15 generation),
an argument to consolidate rather than overpay. TOR is a balanced offense on the
bubble, so its read is a hold-and-reassess judgment around the World Cup break, not
a splash. PDX and LAS are balanced offenses too, but the standing layer reads them
as sellers, so a balanced diagnosis does not become a buy: their read is
sell/accumulate. Same offense diagnosis, three different actions, because the
window conditions the recommendation.

Limitations a front office would raise (from the gm-agent review, carried honestly
rather than papered over):

- The window is a record-derived proxy, not a front office's private book. The
  standing layer supplies the buyer-or-seller posture the offense diagnosis alone
  cannot, but it reads the posture from win-loss record and scoring margin only. A
  front office overrides it with information the data does not carry (an ownership
  mandate, injuries, the value of picks), so the recommendation is a starting
  position, not a verdict.
- The salary floor is carried as a flag, not a dollar tier. The team-salary floor is 85% of the
  cap (`cba_rules_2026.md` Section 1), and the two room-tier teams (WAS, PDX) sit
  below it. A below-floor team must reach the floor over the season, but it can
  satisfy that by paying the shortfall out to its players (`cba_rules_2026.md`
  Section 1), so the flag is a soft nudge toward adding salary, not a
  deadline-forcing mandate. The deadline-read table marks these teams "room (below
  floor)" and reads the nudge that way.
- Roster spots and market supply are unmodeled: acquire and minimum-or-depth reads
  both presume an open spot and an available profile, and four tight-or-capped
  teams chasing the same depth tier is a thin market. The fit reads make this
  concrete by flagging any candidate who is an actionable target for more than one
  team (Ogwumike is the lead target for both DAL and MIN): one player, not two
  independent adds.
- Seller timing is shaped by the expansion draft, which the framework does not
  price. A seller may deal a non-core player now, before an expansion draft can
  take her for nothing, which is a reason a name is available and a reason her
  price moves. The fit reads use this only to mark availability; they do not model
  its effect on what a seller will ask.
- The fit reads are offense-only. They match shot diet and shot-creation profile,
  not defense: the open play-by-play has no matchup, tracking, or defender data, so
  a defensive fit (switchability, matchup, second-unit hold-up) is the coaching
  staff's own read, stated as such on every buy-side list rather than implied by an
  on-style match.
- Forward strength-of-schedule is not modeled (the open play-by-play has no forward
  schedule). The one calendar fact carried is the World Cup Hiatus (August 31 to
  September 16, dates per AMENDMENT_02), which makes a hold a mid-schedule reset
  window.

## 6. Framework evaluation (AMENDMENT_01 Section 2c)

- Face validity: the adjusted identity BLUPs match known team identities (GSV
  perimeter-extreme, first in adjusted 3-point-attempt rate). See Section 1.
- Split-half stability (`output/framework_evaluation.md`): each team's first-half
  versus second-half mean, correlated across teams. Shot-location identities are
  stable (`mid_share` 0.84, `pullup_share` 0.84, `fg3a_rate` 0.83); chemistry and
  rate metrics are noisy (`assisted_rate` -0.33, `secondchance_share` 0.06). Shot
  generation (0.63) and shot making (0.56) are moderately stable, so single-season
  team making and generation reads are directional and should be read with that
  caution. This split-half ordering tracks the ICC ordering closely (both measure
  within-season stability on the same data, so they are consistent rather than
  independent confirmation).
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

Provenance: framework findings reproduce from the numbered scripts against
`shufinskiy/nba_data` commit `773ce29`, run in order `R/01` through `R/09`, then
`R/11` and `R/12`, then `R/08` (the deadline read reads `output/standing.csv` from
`R/12`, so `R/12` runs before `R/08`); the player screen and fit reads are `R/13`
then `R/14`. Cap tiers from `data/reference/cap_context_2026.csv` (Spotrac,
2026-07-19), CBA mechanics from `data/reference/cba_rules_2026.md`, both to be
re-verified before publish (AMENDMENT_02 Section 4).
