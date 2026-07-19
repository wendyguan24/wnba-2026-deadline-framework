# PLAN — WNBA 2026 Trade Deadline Framework

Timeline from `HANDOFF_wnba_deadline_framework.md` §6, amended 2026-07-18 by
`AMENDMENT_01_trajectory_workflow_agents.md` (trajectory layer, EDA gate, review
agents) and `AMENDMENT_02_contracts_cba_cap.md` (cap-context layer, contract
typology, feasibility-conditioned lever — wins over the handoff and AMENDMENT_01 on
contract/cap matters only). Hard deadline: publish July 26-27, 2026.

## Session flow (per AMENDMENT_01 Part 2, supersedes the prior 6-step roadmap)

1. Setup (done)
2. Scripts 01-04, reconciliation gate
3. **EDA notebook + hypotheses registry (new gate)**
4. Scripts 05-06 including trajectory models; run `analytics-reviewer` agent
5. Scripts 07-08; run `gm-agent` on the deadline-read table
6. Graphics + findings draft; run `coach-agent` on case studies and
   `analytics-reviewer` on the full draft
7. Case-study integration, final pass, publish

---

## Jul 18-20 — Repo setup, download/parse/possession segmentation, reconciliation tests passing

Setup (session 1):
- [x] Directory structure (`R/`, `tests/testthat/`, `data/raw/`, `data/processed/`,
      `analysis/`, `output/`)
- [x] `.gitignore` (data/raw, data/processed, R artifacts, Synergy anything)
- [x] `README.md` (problem statement, two-layer architecture, provenance, known issue)
- [x] Skeleton R scripts 01-09 (`stop("Not yet implemented")` guards, function stubs)
- [x] `tests/testthat/` scaffold — 5 named files, empty-bodied (`skip()`), covering
      tricode mapping, baseline table, cdn-vs-v2 reconciliation, possession
      invariants, clock parsing
- [x] `analysis/case_study_template.Rmd` — Synergy quarantine rule documented
- [x] `PLAN.md` (this file)
- [x] Git initialized, setup committed

Setup (session 1b, amendment intake):
- [x] `AMENDMENT_01_trajectory_workflow_agents.md` read and incorporated into PLAN.md
- [x] `R/06_models.R` skeleton gains the trajectory spec (§5c-bis)
- [x] `analysis/eda_midseason.Rmd` stub created (new EDA gate, step 3 above)
- [x] Three review agents installed to `.claude/agents/`
      (`analytics-reviewer`, `coach-agent`, `gm-agent`)

Session 2 (2026-07-18):
- [x] Implement and run `R/01_download.R` — data in `data/raw/`, manifest written,
      counts confirmed against handoff §4
- [x] Implement `R/02_parse_pbp.R` — clock parsing (WNBA quarters are PT10M, not
      PT12M — verified, corrected from an NBA-template placeholder), qualifier
      expansion, full 15-team tricode map with `team_full_name`
- [x] Implement `R/03_possessions.R` — possession segmentation via the `possession`
      column; found and fixed a real bug (technical FTs misattributed to the
      fouling team instead of the shooting team, causing a systematic +-1/+-2 point
      mismatch in 78 of 364 team-games); after the fix, possession points sum to
      final box score exactly in all 364 team-games (independent check against
      shotdetail HTM/VTM + cdn scoreHome/scoreAway, not tautological)
- [x] Implement `R/04_reconcile.R` — `tests/testthat/` suite passing (0
      failures, 0 errors; `tests/testthat.R` + `tests/testthat/setup.R` added
      as the runner, since `test_dir()` changes the working directory and
      test-file environment, which needed a `proj_path()` helper and
      testthat's `setup.R` convention rather than a plain source-then-run script)
- [x] **Gate cleared — reconciliation report at `output/reconciliation_report.md`,
      summarized below**

Session 2b (2026-07-18, AMENDMENT_02 intake — scaffold/documentation only, no data
downloads, no analysis execution):
- [x] `AMENDMENT_02_contracts_cba_cap.md` read and incorporated into PLAN.md
- [x] `R/08_deadline_read.R` skeleton gains the `cap_context` column and
      feasibility-conditioned lever rule
- [x] `data/reference/cap_context_2026.csv` template (header only) + `data/reference/README.md`
      created — tracked in git, not gitignored
- [x] `.claude/agents/gm-agent.md` and `analytics-reviewer.md` updated with the
      cap-conditioning / tiers-not-dollars checks from AMENDMENT_02 §4

## EDA & Hypotheses Registry — new gate (AMENDMENT_01 §2a-2b)

Runs after script 04 tests pass, before `R/05_features.R` is written. Models are not
written until this gate clears.

- [x] `analysis/eda_midseason.Rmd`: distributions of every planned style metric at the
      team-game level — built a 364-row team-game feature table (pace both estimates,
      3PA rate, assisted rate, transition/off-TOV/2nd-chance shares, paint FGM share,
      zone profile, descriptor mix, FT/TOV/live-ball-TOV rates) directly from
      `pbp_events.rds`/`possessions.rds`; zero missing values across all 21 metrics
- [x] Missingness/coverage checks, including **resolving** (not just flagging) the
      Toronto shotdetail zero-row question from session 1's README/PLAN note —
      confirmed every style metric is cdn-derived (area/areaDetail/descriptor), never
      shotdetail-derived; Toronto's 24 team-games have zero NAs on any such column
- [x] Game-level variance per metric (previews which ICCs will be meaningful) —
      approximate one-way ICC ranges from ~0 (assisted_rate) to ~0.53 (mid_share, the
      actual highest, not fg3a_rate at ~0.35 which is second);
      most rate stats are low-ICC, meaning R/06's BLUP shrinkage will matter a lot
- [x] Outlier games identified and dispositioned (keep / exclude / flag — blowouts,
      OT games) — 60/364 team-games are blowouts (final margin >= 20), kept, no
      aggregate distortion found; 16/364 are OT team-games, kept and flagged (`is_ot`)
      since raw `pace_poss` is mechanically inflated by extra game time (later resolved
      by adding `pace_per40`, see the W3 fix below)
- [x] Raw trajectory eyeball plots for the Part 1 metric shortlist (below), before any
      trajectory model runs — pooled naive OLS shows no distinguishable trend for any
      of the 4 shortlist metrics through ~game 24 (all p > 0.4, preliminary null at
      the pooled level); TOR/PDX both show rising raw assisted rate (H2-consistent),
      live-ball TOV rate direction is mixed for those two teams (not yet H2-consistent)
- [x] Garbage-time decision made explicitly and stated (include / exclude / flag
      possessions above a margin threshold in Q4) — AMENDMENT_01 §2c — rule: period
      >= 4 and |margin| >= 20 at possession start; 1,162/29,853 possessions (3.9%)
      flagged; decision is flag, not exclude, in the main feature table
- [x] Output: `output/eda_notes.md` — findings, any spec changes they force, and the
      hypotheses registry below, copied in before script 06 runs — generated
      programmatically from the notebook's own computed values, not hand-transcribed

**Spec changes forced by this EDA pass, for `R/05_features.R`:**
1. Use `pace_poss` (possession-table count, already box-score-verified) as the
   primary pace column; `pace_formula` (FGA + 0.44*FTA - OREB + TOV) is a secondary
   cross-check only — the two correlate at 0.899 but differ by ~4.6 possessions/
   team-game on average, a real gap worth carrying forward rather than picking
   silently.
2. Add an `is_ot` flag alongside `pace_poss` — OT team-games average ~95.7 raw
   possessions vs ~81.0 for regulation, a mechanical artifact of extra game time,
   not a pace signal.
3. Add a `garbage_time_poss_share` column per team-game (flag, not exclude) per the
   Section 6 decision above.
4. Add an `is_home` column (joined from shotdetail `HTM`/`VTM`, covers all 182 games
   including Toronto's); `R/06_models.R`'s identity models include it as a fixed
   effect rather than an unmodeled confounder — added after mentor review flagged it
   as the one genuine gap in the original EDA pass.

**Weighting decision for `R/06_models.R` (from mentor review, documented rather than
left to `lme4`'s default equal weighting):** weight team-game observations by
`transition_poss` when fitting `transition_pts_per_poss` specifically — its
denominator ranges from single digits to 20+ per team-game, unlike FGA-based
denominators which stay in a tight, larger band. All other shortlist/identity
metrics use equal weighting.

**Follow-up EDA additions from mentor review (2026-07-19), all now in
`analysis/eda_midseason.Rmd` and `output/eda_notes.md`:**
- Full 21-metric ICC table (not just the range) saved to `output/eda_icc_table.csv`
  — a methodology exhibit and the selection rule for which metrics the identity
  layer emphasizes. Highest ICC is actually `mid_share` (~0.53, mid-range shot
  frequency), not `fg3a_rate` (~0.35, second) as the original 11-metric pass implied.
  Shot selection/location separates WNBA teams; ball movement (`assisted_rate`,
  ICC ~ 0.00) does not — read as either talent compression across a 15-team elite
  league (vs. 300+ heterogeneous college programs) or as the one-way ICC ignoring
  opponent effects that the mixed model will partially recover. Practical rule:
  identity summaries in the deadline-read table should lead with high-ICC metrics,
  not `assisted_rate`. **Update after R/06_models.R ran (below): the opponent-effect
  explanation does not hold up — the mixed model's ICC for assisted_rate (0.0004,
  controlling for opponent and home) is essentially unchanged from the one-way
  estimate (-0.0026). Ball movement genuinely does not separate WNBA teams; it is
  not an artifact of the simpler EDA-stage ICC calculation.**
- Home/away added (see spec change 4 above).
- Schedule density (rest days between games) checked per team — no meaningful
  imbalance found, one sentence in methodology notes, not a model term this cycle.

### Hypotheses registry (write results against these; do not invent hypotheses after seeing results)

- **H1**: Transition share and transition efficiency increase league-wide as the
  season progresses (reps hypothesis).
- **H2**: Chemistry proxies improve with shared reps — assisted rate rises, live-ball
  turnover rate falls. Expected strongest for TOR and PDX (zero shared reps at
  season start).
- **H3**: GSV's below-average FG% reflects shot making below expectation on an
  acceptable shot diet, not a generation problem. Trajectory layer adds: is GSV's
  making trending toward expectation or flat?
- **H-null discipline**: report which hypotheses the data does not support. A
  published null on H1 is a finding, not a failure.

## Jul 21-22 — Style features, mixed-effects + trajectory models, BLUPs/ICC

- [x] Implement `R/05_features.R` — 364-row team-game feature table (`data/processed/
      team_game_features.rds`), formalizing the EDA gate's verified logic plus all 4
      forced spec-change columns (`pace_poss` primary, `is_ot`, `garbage_time_poss_share`,
      `is_home`). Output cross-checked line-for-line against the EDA notebook's
      independently computed numbers (pace correlation, assisted rate, zone-share sums,
      is_ot count, garbage-time share) — all match exactly. No missing values anywhere.
- [x] Implement `R/06_models.R` — identity models (`metric ~ is_home + (1|team) +
      (1|opponent)`) fit for all 20 HANDOFF §5b style metrics (`pace_formula` excluded,
      secondary-only; pace modeled as `pace_per40`, not raw `pace_poss` — see the W3
      fix below). `output/icc_table.csv` written. Several models hit
      "boundary (singular) fit" (opponent-variance component near zero) — expected and
      harmless for ICC/BLUP extraction, not a fallback trigger (that's trajectory-only).
      **Identity-anchor rule (from the analytics-reviewer's decisions-only EDA review,
      BLOCKER 1): a metric may anchor an identity claim in the deadline-read table only
      if its `output/icc_table.csv` ICC is >= 0.15. Eligible: mid_share, fg3a_rate,
      atb3_share, pullup_share, ra_share, paint_fgm_share, driving_share,
      transition_share. Everything else (including assisted_rate) is trajectory-only
      or descriptive — apply this when R/08_deadline_read.R is written.**
- [x] Implement `R/06_models.R` trajectory extension (§5c-bis) on the metric shortlist:
      1. Transition share (H1)
      2. Transition points per transition possession (H1, efficiency side)
      3. Assisted rate of FGM (H2)
      4. Live-ball TOV rate (H2)
      5. Optional: shot-making residual from script 07 (H3, GSV-relevant) — cut first
         if the block is threatened (NOW BUILT 2026-07-19: R/07 produces the team-game
         `shot_making_residual` and R/06 fits it as the 5th trajectory metric, unweighted,
         via the same random-slope + documented-fallback machinery; league trend
         +0.115/game, p=0.199, fallback fired like the other four)
      **Superseded by the project-wide cut order below (AMENDMENT_02 §4)** — the
      `trajectory` column itself is still never cut; the optional 5th metric is now
      the first thing to go project-wide, not just within this block.
      All 4 shortlist metrics hit a genuine singular fit on the full random-slope
      model (confirmed directly: team intercept/slope correlation locks at 1.000,
      the classic small-sample boundary case at 23-26 games/team) and used the
      documented fallback (random-intercept model + per-team residual-vs-game_index
      OLS slope). League-wide trend: all 4 metrics p > 0.2, consistent with the EDA
      gate's pooled-OLS preliminary null for H1/H2. TOR and PDX's raw assisted-rate
      slopes still point positive in the fallback model too (consistent with the EDA
      eyeball pass), both with intervals spanning zero — directionally
      H2-consistent, not yet statistically distinguishable from flat.
- [x] Present BLUP/ICC results and raw-vs-adjusted rank deltas — `output/icc_table.csv`,
      `output/team_rank_deltas.csv`, `output/team_trajectories.csv`,
      `output/trajectory_league_trends.csv` (all human-readable, alongside the `.rds`
      versions in `data/processed/`)
- [x] **Run `analytics-reviewer` agent on script 06 results (BLUPs, ICCs, trajectory
      slopes) — triage feedback (accept / reject with one-line reason / defer
      post-deadline), log the triage below** -- RUN 2026-07-19, scoped to the trajectory
      layer (incl. the new 5th metric) and the R/07 expected-points outputs. Findings
      logged below under "analytics-reviewer, post-06/07 gate run." Triage is PROPOSED,
      NOT yet accepted -- awaiting Wendy's decision on each item before any fix is applied.

## Jul 23 — Data refresh check; expected-points baseline; deadline-read table; cap-context CSV

- [ ] Check `shufinskiy/nba_data` for a commit newer than `773ce29`; re-pin and re-run
      01-04 if found, confirm tests still pass; update baseline expectations
      deliberately if counts shift
- [x] Implement `R/07_expected_points.R` (stratified expected-points baseline / qSQ-lite,
      NOT a trained model) -- 49 strata over zone x shot_class x context, cdn-only, 2026
      in-season, MIN_CELL_N=100 collapse cascade (full cell -> zone x context -> zone ->
      global). Outputs `expected_points_baseline.rds` (49 strata), season per-team
      `team_generation_making.rds` (generation/making per 100 poss), and team-game
      `team_game_shot_making.rds` (the `shot_making_residual` column feeding R/06's
      trajectory layer). Season identity generation + making = actual holds < 1e-8 for all
      15 teams; all xpts in [0.66, 1.54]. Run 2026-07-19 on the clean VM.
- [ ] Implement `R/08_deadline_read.R` — skeleton now includes the `trajectory`
      column (improving / flat / declining, footnoted when the interval spans zero,
      via `format_trajectory_column()`), the `cap_context` column (room / tight /
      capped, AMENDMENT_02 §3b), the feasibility-conditioned `lever` rule (an
      "acquire" read under a capped context becomes `acquire (constrained: requires
      salary out)` or downgrades — never silently recommend a move the cap forbids),
      and a `team_trajectories` input from script 06 plus a `cap_context` input from
      `data/reference/cap_context_2026.csv`; implement against that skeleton
- [ ] **Gather `data/reference/cap_context_2026.csv` (AMENDMENT_02 §3a/§4) — all 15
      teams, hand-curated by Wendy from Spotrac WNBA team pages and Her Hoop Stats
      contract data, NOT scripted scraping. ~1 hour, same day as script 08. Every row
      needs a `source` and `as_of_date`. Tiers, not to-the-dollar figures.**
- [ ] Present the deadline-read table (the core deliverable)
- [ ] **Run `gm-agent` on the deadline-read table before any prose is written around
      it — triage feedback, log below. Includes the cap-conditioning check added by
      AMENDMENT_02 §4.**

## Jul 24-25 — Synergy case-study enrichment + fit reads (time-boxed)

- [ ] GSV full case study, Toronto and Portland lighter treatment
- [ ] If not converging by Jul 25, drop and ship diagnosis-only — still a complete piece
- [ ] **Contract typology folded into fit reads (AMENDMENT_02 §3c):** each named
      candidate profile gains a contract line — years remaining, 2026 salary tier
      (min/mid/max/supermax), expiring or not, protection status if verifiable, and
      the resulting asset class (expiring mid-tier = classic deadline chip;
      multi-year mid-tier = costlier, keeps the fit past September; supermax =
      immobile, do not propose as a target; minimum/depth = the feasible move for
      capped teams). Profiles stay profiles, not trade proposals — no fake-trade
      content.

## Jul 25-26 — Writing, graphics, methodology notes

- [ ] Implement `R/09_graphics.R` (includes one trajectory graphic maximum — small
      multiples, adjusted trends, expansion teams highlighted; no rolling-window
      machinery, no month-by-month split tables)
- [ ] Draft `output/findings.md`, including framework evaluation criteria
      (AMENDMENT_01 §2c: face validity, split-half stability, sensitivity check,
      garbage-time disposition)
- [ ] **Structural paragraph (AMENDMENT_02 §3d, league-wide, findings draft):** what
      the first post-CBA deadline means structurally — contract-length distribution
      after the 2026 free agency rush, what that implies about market liquidity
      (movable expirings league-wide), the supermax immobility rule, the World Cup
      break as a hold incentive. Prose plus one summary count from the cap-context
      table — not a model.
- [ ] **Four-item pre-publish verification checklist (AMENDMENT_02 §4):**
      1. Re-check cap figures for the three case-study teams against Spotrac/Her Hoop
         Stats within 48 hours of publish.
      2. Confirm the hard-cap trade-fitting rule under the new CBA from a primary or
         top-tier source before the structural paragraph states it.
      3. Confirm protection/guarantee rules before any candidate's contract security
         is characterized.
      4. Date-stamp the cap-context table in the piece ("cap figures as of [date]")
         since deadline-week moves will stale it within days.
- [ ] **Run `coach-agent` on case-study sections (GSV, TOR, PDX) once fit reads are
      drafted — triage feedback, log below**
- [ ] **Run `analytics-reviewer` on the full findings draft — triage feedback, log
      below. Includes the cap-figure traceability and tiers-only checks added by
      AMENDMENT_02 §4.**

## Jul 26-27 — Publish (repo + writeup + WHoopsLab version)

- [ ] Final review, publish

## Jul 27-Aug 2 — Individual outreach notes, deadline-week engagement

- [ ] Boki Wang (GSV), Eli Horowitz / Lauren Manis / Mark Schindler (Toronto),
      Portland HC contact (Portland). Optional: Todd Whitehead (Synergy courtesy).

---

## Review agents (AMENDMENT_01 Part 3)

Installed at `.claude/agents/`: `analytics-reviewer.md`, `coach-agent.md`,
`gm-agent.md`. Run on artifacts (tables, drafts, model summaries), never on
descriptions of them.

| Agent | Gate | Reviews |
|---|---|---|
| `analytics-reviewer` | After script 06 results exist; again on full findings draft | Correctness, rigor, guardrail compliance |
| `gm-agent` | On the deadline-read table the moment script 08 produces it, before prose | Decision-usefulness for trade-deadline strategy |
| `coach-agent` | On case-study sections (GSV, TOR, PDX) once fit reads are drafted | Usefulness/clarity for a coaching staff |

Feedback is triaged, not obeyed: accept, reject with a one-line reason, or defer to
post-deadline. Log each triage decision here as it happens:

**analytics-reviewer, narrow decisions-only pre-gate run (2026-07-19).** Scoped to
the four EDA decisions, the low-ICC implication, H1/H2 null discipline, and spec
contradictions — NOT the formal post-06 gate, which still fires separately on the
full script-06 result set. Verdicts: all four EDA decisions defensible as made
(pace_poss primary, is_ot flag, garbage-time flag-not-exclude, Toronto
cdn-derivation); H1/H2 pooled-null discipline correct; no structural spec
contradictions. Triage of its findings, all applied 2026-07-19:

- **BLOCKER 1 — ACCEPT, FIXED.** eda_notes.md §3's own table contradicts its prose
  ("zone-profile shares" as a class includes corner3_share at 0.075 and
  paint_share at 0.082, both below tov_rate) and the class-level "lead with
  zone-profile shares" rule would let near-zero-ICC metrics anchor identity.
  Fix: name the specific high-ICC shares (mid_share, atb3_share, ra_share)
  instead of the class, and adopt the reviewer's formal anchor rule — identity
  anchors in the deadline-read table require mixed-model ICC >= 0.15 (from
  output/icc_table.csv, not the EDA one-way approximations), a stated judgment
  call placed at the observed break in the ICC distribution (transition_share
  0.181 is the last metric before the collapse to <= 0.113). Eligible anchors
  under the rule: mid_share, fg3a_rate, atb3_share, pullup_share, ra_share,
  driving_share, paint_fgm_share, transition_share.
- **WARNING 1 — ACCEPT, FIXED.** eda_notes.md self-contradiction: §2 says
  shotdetail is "reconciliation-only" while §1 builds is_home from its HTM/VTM.
  Reworded to "reconciliation and game-level metadata (HTM/VTM) only; no
  shot-level features."
- **WARNING 2 — ACCEPT, FIXED.** Pace gap reported unsigned only. Added the
  signed mean difference (pace_poss runs +4.6 possessions/team-game higher, not
  just "different") and attributed the main source (pace_formula's fixed 0.44 FT
  weight is an NBA convention the handoff itself flags as unvalidated for the
  WNBA).
- **WARNING 3 — ACCEPT, FIXED.** The is_ot spec change deferred the actual OT
  treatment without choosing. Added `game_minutes` (40 + 5 per OT period) and
  `pace_per40` (pace_poss normalized to a 40-minute game) to
  `R/05_features.R`; `R/06_models.R`'s `IDENTITY_METRICS` now models
  `pace_per40`, not raw `pace_poss` (which remains the rate-stat denominator).
  Confirmed the fix works: OT vs. regulation team-game means went from
  95.7 vs. 81.0 (raw pace_poss, the original artifact) to 81.8 vs. 81.0
  (pace_per40) — the mechanical gap is gone. Re-ran both scripts;
  `pace_per40`'s own mixed-model ICC is 0.146 (just under the 0.15 anchor
  floor from BLOCKER 1 — expected, pace was never a top-ICC identity metric).
- **WARNING 4 — ACCEPT, FIXED (disclosure only).** NA-margin possessions are
  silently not-flagged in the garbage-time rule. Confirmed count is 0; added a
  one-sentence disclosure of the rule and count to eda_notes.md §6, no
  recomputation needed.
- **NOTE 1 — ACCEPT, FIXED (half-sentence only, rest deferred).** Added to §5
  that pooled OLS p-values ignore within-team correlation (descriptive only)
  and that the pooled null bears on the league-wide clause of H1/H2, not H2's
  team-specific TOR/PDX prediction.
- **NOTE 2 — ACCEPT, FIXED.** eda_icc_table.csv now has an `icc_floored` column
  (`pmax(icc_approx, 0)`) alongside the raw `icc_approx`, with a footnote in
  eda_notes.md §3 explaining the one-way ANOVA estimator can go slightly
  negative.
- **NOTE 3 — DEFER post-deadline.** Blowout no-distortion check covered pace and
  transition_share only before generalizing; script 06's §2c sensitivity pass
  covers the shortlist, which is where it matters. Add the precision phrase only
  if a findings-draft reviewer asks.
- **NOTE 4 — ACCEPT, FIXED.** Aligned the stale "to ~0.35 (fg3a_rate)" line in the earlier
  EDA checkbox with the corrected mid_share finding to avoid quoting it by
  accident.
- **Process observation — ACCEPT as standing practice.** Keep eda_notes.md frozen
  as the pre-model record; post-model updates (like the assisted_rate
  opponent-effect retirement) live in PLAN.md, not retro-edited into the EDA
  notes. Exception: the accepted fixes above correct errors that existed at
  generation time (self-contradictions, missing disclosures), which is
  legitimate correction, not post-hoc rewriting.

**analytics-reviewer, post-06/07 gate run (2026-07-19).** The formal AMENDMENT_01
Part 3 gate after R/07 (expected-points baseline) was implemented and
shot_making_residual was added to R/06's trajectory layer. Reviewed the R/07
source, the R/06 trajectory block plus main() join, and a human-readable snapshot
of every R/07 output and the 5-metric trajectory tables. Positive traceability the
reviewer confirmed: R/07 is cdn-only (never shotdetail), calls itself a qSQ-lite
baseline, reports per 100 possessions with a denominator basis matching R/05's
pace_poss, season FGA reconcile to the HANDOFF baseline table, no Synergy, no
play-type language, no absolute-skill overclaim.

**Triage below is PROPOSED by Claude, NOT accepted. No fix has been applied to any
finding. Per the session instruction, feedback is triaged by Wendy, not obeyed by
Claude. The R/07 + R/06 commit is pushed as-is; each item awaits Wendy's
accept / reject / defer before code changes.** (The one pre-review change already in
the commit -- em dashes removed from R/07's header -- was Claude's own spec-review
catch before this gate ran, not a response to these findings.)

- **BLOCKER 1 (R/06 does not declare its new R/07 dependency; 05 -> 06 -> 07 numeric
  order hard-errors) -- PROPOSED ACCEPT.** Real reproducibility trap: R/06 main() reads
  `team_game_shot_making.rds` but the Inputs header lists only team_game_features.rds,
  and no run-order doc states 07 must run before 06. Proposed fix (not applied): add the
  input to R/06's header and state the correct order 05 -> 07 -> 06 in PLAN.md/README.
- **WARNING 1 (R/07:162 comment says "shot-quality baseline") -- PROPOSED ACCEPT.**
  Direct vocabulary-discipline violation; the layer is never "shot-quality." Proposed
  fix (not applied): change to "expected-points baseline."
- **WARNING 2 (per-team trajectory table omits fallback_used) -- PROPOSED ACCEPT, or
  defer to R/08.** All 5 metrics fell back to the residual-slope approximation, but
  team_trajectories.csv carries no fallback_used column, so a reader of per-team slopes
  cannot tell they are not random-slope BLUPs. Proposed fix (not applied): add
  fallback_used to the per-team output, or guarantee R/08 joins it when built -- Wendy's
  call which.
- **WARNING 3 (no AMENDMENT_01 §2c sensitivity / split-half pass for the trajectory
  shortlist) -- PROPOSED DEFER (already scheduled).** The garbage-time-exclusion re-run
  and split-half stability check are listed as pending for the Jul 25-26 findings-draft
  block; no trajectory sentence is published yet, so the check is not needed until prose
  is written. Gate any trajectory claim on it then; do not publish a trajectory finding
  without it.
- **WARNING 4 (em dashes in R/06 comments, lines 17/20/31/32/75/175/267) -- PROPOSED
  DEFER as a repo-wide hygiene pass.** All flagged lines are pre-existing from prior
  committed sessions, not introduced by this change (the lines Claude added use `--`);
  R/02-R/05 carry the same pre-existing em dashes, so a proper fix is one repo-wide
  language-hygiene sweep, not an R/06-only edit inside this diff.
- **NOTE 1 (shot_class precedence undocumented) -- PROPOSED ACCEPT (trivial).** Add one
  comment justifying putback > cutting > driving > pullup > other. Safe to defer.
- **NOTE 2 (H3 heads-up: GSV makes shots at/above expectation, refuting H3's registered
  "below expectation" premise) -- PROPOSED ACCEPT, act at findings stage.** No code change
  now (the code asserts nothing). Flagged loudly for the findings draft: report H3 as a
  refutation/null per hypotheses discipline, not a quiet reframe. This is the most
  decision-relevant finding for the eventual write-up.
- **NOTE 3 (in-sample baseline: each team-game's expected value includes ~1/15 its own
  shots) -- PROPOSED DEFER.** Inherent to a league-average baseline; one methodology
  sentence at the writing stage. Safe to defer.
- **NOTE 4 (MIN_CELL_N SE rationale optimistic: ~0.10 not 0.07) -- PROPOSED ACCEPT
  (comment-only accuracy fix) or DEFER.** Does not affect any output value. Safe to defer.
- **NOTE 5 ("flat" label unreachable since slope is never exactly 0; honesty rests on
  interval_spans_zero) -- PROPOSED DEFER to R/08.** A requirement on R/08's presentation
  (surface the interval_spans_zero footnote so improving/declining are not read as fact);
  R/08 is intentionally not built yet. Safe to defer.

## Data download (session 2, 2026-07-18)

`R/01_download.R` run against commit `773ce292bb2cd9bc6ec98d70de95176607ccbaeb`.
Downloaded and extracted `data/raw/{wnba_cdnnba_2026,wnba_shotdetail_2026,
wnba_nbastats_2026}.csv`. Manifest confirms 89,735 / 23,163 / 74,224 rows, 182
distinct games in each file — matches handoff §4 exactly. A follow-up raw-file
inspection (columns, date range, rows per team, actionType distribution, LAS/LVA
map, key-column missingness) confirmed every §4 figure reproduces exactly, including
the 66.0% assisted rate and the §4 baseline FGA-per-team column.

## Known issues (status after session 2 download)

1. **shotdetail is missing Toronto Tempo entirely — CONFIRMED, not just flagged.**
   Re-verified directly against this repo's own downloaded data (not a prior
   scratch pull): `wnba_shotdetail_2026.csv` has 0 rows for Toronto, 14 of 15 teams;
   `cdn` and `nbastats v2` both have all 15. **Per AMENDMENT_01 §2a, the *implication*
   for feature-building is still resolved formally in `analysis/eda_midseason.Rmd`**
   (as part of its required coverage check), but the underlying fact no longer needs
   re-verification. `R/07_expected_points.R` shot geometry for Toronto must come from
   `cdn` (`x`/`y` + `area`/`areaDetail`), not `shotdetail`.
2. **Commit hash resolution — CONFIRMED.** `773ce29` resolves to
   `773ce292bb2cd9bc6ec98d70de95176607ccbaeb` ("add wnba 2026 data (ID 1 to 182)");
   `R/01_download.R` ran successfully against it 2026-07-18.
3. **§4 baseline table provenance — RESOLVED.** Paint share (of FGM) = made shots
   with `area` in {"Restricted Area", "In The Paint (Non-RA)"} / FGM. Confirmed by
   reproducing all 8 teams x 6 metrics in the §4 table exactly (0 delta at
   3-decimal rounding) — see `R/04_reconcile.R` `validate_baseline_table()` and
   `output/reconciliation_report.md`.

## Reconciliation gate results (session 2, 2026-07-18) — GATE CLEARED

Full report: `output/reconciliation_report.md`. `tests/testthat/` suite: 0 failures,
0 errors (run via `tests/testthat.R`).

- **§4 baseline table:** reproduces exactly, all 8 teams, all 6 metrics.
- **cdn vs nbastats v2:** essentially exact — across 364 team-games, sum|FGA delta|
  = 1, sum|FGM delta| = 1 (same single game, IND game `1022600004`), sum|AST delta|
  = 4, sum|FG3A delta| = 0. Analogous to the NCAA project's documented small gap;
  does not block feature-building.
- **shotdetail coverage:** 14/15 teams, Toronto missing — confirmed (see Known
  issue 1 above).
- **Real bug found and fixed:** technical free throws are shot by the team that did
  NOT commit the foul, but cdn's `possession` column stays with the fouling team
  throughout the technical-FT sequence. The original possession-points calculation
  credited technical-FT points to the possession-holding (fouling) team instead of
  the actual shooter's team — a systematic +-1/+-2 point mismatch in 78 of 364
  team-games against final box scores. Fixed in `R/03_possessions.R`
  `segment_possessions()`: technical FTs are now excluded from their enclosing
  possession's points and emitted as their own single-event possession rows
  (`outcome == "technical_ft"`), credited to the shooting team. After the fix,
  possession points sum to the final box score exactly in all 364 team-games,
  verified independently via shotdetail's `HTM`/`VTM` + cdn's `scoreHome`/
  `scoreAway` (not a tautology of the pipeline's own point computation).
- **Documented residual:** `handle_and_ones()` finds 1 violation in 476 true
  and-one candidates (0.2%) — a team-foul bonus free throw awarded to the scoring
  team on the very next possession, surface-identical to a true and-one (made shot
  -> foul -> same-team FT) and not distinguishable from event fields alone. Does
  not affect `segment_possessions()`, which reads the `possession` column directly
  rather than this heuristic. Accepted and documented rather than chased further.

## Cut order under time pressure (AMENDMENT_02 §4 — supersedes AMENDMENT_01's narrower version)

If the schedule collapses, degrade in this order:

1. Optional trajectory metric (the 5th, shot-making-residual one)
2. Synergy enrichment (case-study time-box, ship diagnosis-only)
3. The AMENDMENT_02 §3d structural paragraph
4. Contract typology in fit reads

**Never cut, regardless of time pressure:** the `trajectory` column, the `cap_context`
column, and the feasibility conditioning of the `lever` call. These are now part of
the core deliverable, not optional extras — an acquire read the cap forbids is worse
than no read at all.

## Cut list (explicitly out of scope this cycle)

League style map PCA/clustering, lineup/on-off anything, defensive mirrors, trained
xPTS model, possession-value model, Synergy-PBP joins. Post-deadline (September+,
separate decision): trained shot-quality model; possession-value framework timed for
the November hiring window.

Neither amendment adds new cuts to this list; both harden process around the existing
scope (trajectory and cap-context are required deadline-read columns, not scope
creep — see AMENDMENT_01 §1 and AMENDMENT_02 §1 rationale). AMENDMENT_02 explicitly
excludes: a cap model, trade machine, or salary-matching calculator; player-level
contract data beyond case-study rosters and named candidates; multi-year cap
projections or 2027 free-agency analysis; any contract-protection claim without a
source.

## Next session should

Reconciliation gate is cleared (see "Reconciliation gate results" above; 0 test
failures) and the EDA gate is now cleared too — `analysis/eda_midseason.Rmd` runs
cleanly end to end (verified via `knitr::knit()`; no pandoc installed locally so
HTML rendering wasn't checked, only that every chunk executes without error) and
`output/eda_notes.md` is written. Next stop per the session roadmap: implement
`R/05_features.R` against the EDA gate's 3 forced spec changes (`pace_poss` as
primary pace, `is_ot` flag, `garbage_time_poss_share` column), then `R/06_models.R`
including the trajectory extension, then run `analytics-reviewer` on the results.
`data/reference/cap_context_2026.csv` still needs Wendy's manual entry (AMENDMENT_02
§3a/§4, Jul 23 block) before script 08 can be implemented against real cap data.
