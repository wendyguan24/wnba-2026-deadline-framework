# WNBA 2026 Trade Deadline Framework: Methodology and Rationale

Companion to `output/findings.md`. Findings states what the results are and how each
method works. This document states WHY each method was chosen and how it maps to the
deadline problem, so a reviewer can judge the design, not just the output. Every method
here is executed by the numbered scripts in `R/`; every published number reproduces from
open play-by-play. Cap context is reported as a flexibility tier, never a dollar figure.
Descriptor-derived features are shot-creation profiles, never play types. The
expected-points layer is a stratified expected-points baseline (qSQ-lite), not a trained
model.

## 1. The problem and the three questions

A front office at the deadline must decide whether its first half reflects a talent
problem, a process problem, or a luck problem, because those imply opposite moves:
acquire, adjust, or hold. Box-score record conflates all three. The framework answers
three questions (HANDOFF Section 1, extended by AMENDMENT_02 Part 1):

1. What do we need? (a diagnostic decomposition of offense)
2. Who fits? (qualitative archetype fit reads, case-study teams only)
3. Can we do it? (cap and CBA feasibility)

Every layer below exists to answer one of these. Anything not traceable to them is out of
scope by design.

## 2. Why a decomposition instead of a rating

A single offensive rating tells you a team is good or bad, not why, so it cannot separate
acquire from hold. The framework decomposes first-half offense into four legs that each
isolate a different cause, so the deadline lever follows from the cause:

- Identity: what a team chooses to do (stable style).
- Generation: the quality of looks its process creates (expected points given shot diet).
- Making: whether it converts those looks (actual minus expected).
- Trajectory: what it is becoming (within-season direction).

The value of the decomposition is that it disagrees with the record where the record is
misleading. ATL leaves the most points on the floor in the league yet has the best looks;
the framework says hold (a making/luck problem), not buy a finisher. That disagreement is
the point.

## 3. Why each method

### 3a. Schedule-adjusted identity: mixed-effects BLUPs (R/06)
For each style metric we fit `metric ~ is_home + (1 | team) + (1 | opponent)` and take the
team random-effect BLUP as adjusted identity. Why this and not a raw team average:
- A raw average confounds a team's style with the schedule it happened to face. The
  opponent random effect removes the strength and style of opponents; the team BLUP is
  what remains, a team's style on a neutral, average-opponent schedule.
- BLUP shrinkage is a feature, not a nuisance. A metric with little stable team signal
  shrinks toward the league mean, which is the honest answer for a noisy metric, and it is
  why the framework can trust the metrics that do not shrink.
Why report ICC: the intraclass correlation is the share of variance that is stable team
identity versus matchup noise. It tells us which metrics carry a real identity (shot
location: `mid_share` 0.53, `fg3a_rate` 0.36) and which are essentially noise
(`assisted_rate` 0.0004). This drives an explicit rule below.

### 3b. The ICC >= 0.15 identity-anchor rule (eda_notes.md spec change 6)
An identity claim is only anchored on a metric whose mixed-model ICC is at least 0.15
(the observed break in the ICC distribution). Below that floor a BLUP has shrunk almost
entirely to the league mean, so ranking teams on it is ranking noise. This rule is why the
deadline-read identity column is built only from the eight eligible metrics, not all
twenty. It is the difference between describing a team and inventing a description.

### 3c. Generation and making: a stratified expected-points baseline, not a trained model (R/07)
League-average points per shot by zone x shot-creation profile x context (49 strata), from
2026 in-season shots. Generation is expected points per 100 given a team's shot diet;
making is actual minus expected. Why a stratified lookup and not a trained shot-quality
model:
- Honesty about what the open data supports. A trained model implies a fitted, validated
  predictor. A stratified league-average baseline is a transparent yardstick with no fitted
  parameters, which is what one half-season of open play-by-play can defend. A trained model
  is named future work, not oversold now.
- The decomposition is the goal, not prediction. Holding making at the league average and
  varying only the shot diet isolates process (generation) from finishing (making), which
  is exactly the acquire-versus-hold question.
Why field goals only, 2026 only: free throws are foul-triggered, not chosen from a diet;
and keeping the baseline on the same population the reads are drawn from avoids importing a
prior cap-and-roster environment that no longer exists.

### 3d. Trajectory: random slopes with a documented fallback (R/06)
`metric ~ game_index + (1 + game_index | team) + (1 | opponent)` on a five-metric shortlist
tied to the hypotheses. Why trajectory at all: a deadline decision is a bet on what a team
is becoming, not only on its current state (AMENDMENT_01). Why the fallback: at 23 to 26
games per team the random-slope model is singular, so the framework falls back to a
random-intercept model plus per-team residual slopes, and reports per-team labels only with
their intervals. The honest output is the league-wide fixed effect; per-team labels are
directional, not standalone claims.

### 3e. Cap feasibility: tiers as a hard gate, not a penalty (R/08, cba_rules_2026.md)
The WNBA is a hard-cap league (cba_rules Section 2): a team needs Room or an Exception to
take on salary. So feasibility gates the acquire lever rather than discounting it: a capped
team's acquire becomes "acquire (constrained: requires salary out)"; a below-floor team is
flagged (85 percent of cap, Section 1). Why tiers not dollars: year-one-of-a-new-CBA public
contract data is exactly when trackers lag, so the framework publishes the flexibility tier
it can defend and never a to-the-dollar ratio.

## 4. The honesty rules and why they exist

- Pre-registered hypotheses (eda_notes.md): findings are written against a frozen H1 / H2 /
  H3 / H-null registry, so a null is a finding and not a moved goalpost. H1 and H2 are
  published nulls; H3's premise is refuted. Reporting these plainly is the credibility.
- Reproducibility boundary: every published number traces to a numbered script and open
  data. Synergy-derived numbers are quarantined to case-study prose and never enter models,
  data, or output tables.
- Tiers not dollars, ICC anchor floor, no isolation trends from open play-by-play: each rule
  refuses a claim the data cannot support, which is what lets the claims that remain carry
  weight.

## 5. Defining fit: gap-fill versus style-amplify

Trades often fill a gap a roster is missing, but a team also trends toward its identity, so
"good fit" is ambiguous and must be defined before it is scored. The design decision: fit is
not one thing, and team philosophy selects the mode. The framework should output the mode,
not a single universal fit number.

Two modes, which can conflict:
- Gap-fill (complementary): the target supplies a capability the roster lacks, raising a
  weak part of the profile. Correct when a team has a real window but a specific,
  exploitable deficit.
- Style-amplify (reinforcing): the target does more of what the team already does well,
  deepening an identity strength. Correct when the identity is the edge and an off-style
  addition would dilute it.

These conflict because filling a gap can break an identity: a rim-running big fills a
perimeter team's paint-scoring gap and simultaneously destroys the spacing that was its
advantage. "Fills a gap" and "good fit" are not synonyms, and refusing that equivalence is
the discipline.

Philosophy selects the mode:

| Philosophy | Fit mode | What "good fit" means |
| --- | --- | --- |
| Win-now, flawed roster | Gap-fill | Cover the one real deficit that a playoff series exposes |
| Win-now, elite identity | Style-amplify / protect | Depth that extends the edge; refuse reshaping the shot hierarchy |
| Protect emerging identity (expansion) | Style-amplify, cheap | Complementary depth, do not hand usage to a new piece |
| Rebuild / seller | Asset mode | Controllable, movable future value; current style is secondary |

This is why the deadline read outputs acquire / adjust / hold rather than a fit score: the
lever is a coarse philosophy-and-need read, and fit refines it one level down.

### 5a. The value-versus-cost split (honest boundary)

Assessable now, inside the constraints, as categorical or ordinal reads:
- The gap: which shot-diet stratum drags a team's generation (Section 6 below).
- The mode: gap-fill versus style-amplify, from identity strength, generation deficit, and
  trajectory, with philosophy supplied qualitatively.
- Style-compatibility: whether an archetype's shot profile matches or clashes with the
  team's spacing and role needs (from the identity BLUPs, in the case-study fit reads).
- Feasibility and cost class: cap tier as a hard gate (built), asset class as an ordinal
  cost (expiring / multi-year / minimum-depth / supermax-immobile).

Requires the post-deadline player-value model, and must be flagged as such every time:
- Wins replaced / value over a freely-available replacement (needs a win-shares or RAPM
  layer that does not exist here).
- A numeric value-per-cost ratio (needs dollar-precise cap data, which breaks tiers not
  dollars).
- How much adding a specific target raises wins (needs a counterfactual lineup model plus
  transaction labels).

The fit read the framework can publish now is therefore an ordinal judgment, not a number:
(mode) applied to (does the archetype fill the named gap or amplify the identity), passed
through (feasible under the cap tier) at (asset-class cost). The clean value-per-cost ratio
is the post-deadline extension, and the biggest presentation trap is laundering a
philosophy-dependent judgment into an objective-looking fit number. Two front offices with
different philosophies should read the same team and reach different good fits; the piece
should make the philosophy explicit and switchable, the way the cap layer makes feasibility
explicit.

## 6. In-scope extension: generation-gap attribution (R/11)

The one piece of the fit question the open data can answer now, without a player-value
model, is naming the gap. R/11 decomposes each team's shot-diet generation shortfall by
zone: for each zone, (team shot share minus league shot share) times league points per shot.
Zones where a team is most below league are where its shot selection costs it expected
points relative to the field. Each is labeled:

- Missing efficient looks: the team under-weights a high-value zone. A candidate gap-fill.
- Over-reliant on low-value looks: the team over-weights a low-value zone. A shot-selection
  leak.
- Identity-driven (protect): the under- or over-weighting sits on a metric where the team
  has a strong, stable identity (high absolute z on an ICC-eligible share). This is a
  choice, not a gap, and filling it would be negative fit.

The per-team fit mode follows: bottom-tertile generation with a non-identity deficit reads
as gap-fill; strong generation or an identity-driven low reads as style-amplify or protect.

Two honesty caveats, stated in the output: this is a zone-level read (the alternative-
stratification check found zone-only preserves team ranks, Spearman 0.98, so zone is a
defensible grain), and it reads only the offensive shot-diet side. Open play-by-play barely
sees defense, rebounding value, or playmaking not expressed in shots, so R/11 names
offensive-generation gaps, not all roster gaps. See `output/generation_gap.md`.

## 7. Evaluation (AMENDMENT_01 Section 2c)

Face validity (adjusted BLUPs match known identities), split-half stability (identity metrics
correlate across halves, tracking the ICC ordering), alternative-stratification sensitivity
(zone-only preserves generation and making ranks, Spearman 0.98 and 1.00), and the
garbage-time disposition (flag not exclude, 3.9 percent, nulls survive exclusion). Detail in
`output/framework_evaluation.md` and `output/trajectory_sensitivity.md`.
