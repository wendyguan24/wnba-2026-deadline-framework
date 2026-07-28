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
      NOT yet accepted -- awaiting Wendy's decision on each item before any fix is applied. (SINCE RESOLVED: accepted and applied during the PR #1 work.)

## Jul 23 — Data refresh check; expected-points baseline; deadline-read table; cap-context CSV

- [x] Check `shufinskiy/nba_data` for a commit newer than `773ce29`; re-pin and re-run
      01-04 if found, confirm tests still pass; update baseline expectations
      deliberately if counts shift -- CHECKED 2026-07-20: repo HEAD advanced to
      `e829d46`, but the WNBA 2026 cdn dataset is byte-identical (same 2,333,836-byte
      archive, same 182 games / 89,735 rows). The newer commit touched other datasets,
      not ours. No re-pin, no baseline shift, tests unaffected; pin stays at `773ce29`.
- [x] Implement `R/07_expected_points.R` (stratified expected-points baseline / qSQ-lite,
      NOT a trained model) -- 49 strata over zone x shot_class x context, cdn-only, 2026
      in-season, MIN_CELL_N=100 collapse cascade (full cell -> zone x context -> zone ->
      global). Outputs `expected_points_baseline.rds` (49 strata), season per-team
      `team_generation_making.rds` (generation/making per 100 poss), and team-game
      `team_game_shot_making.rds` (the `shot_making_residual` column feeding R/06's
      trajectory layer). Season identity generation + making = actual holds < 1e-8 for all
      15 teams; all xpts in [0.66, 1.54]. Run 2026-07-19 on the clean VM.
- [x] Implement `R/08_deadline_read.R` (DONE 2026-07-20, clean VM) -- skeleton now includes the `trajectory`
      column (improving / flat / declining, footnoted when the interval spans zero,
      via `format_trajectory_column()`), the `cap_context` column (room / tight /
      capped, AMENDMENT_02 §3b), the feasibility-conditioned `lever` rule (an
      "acquire" read under a capped context becomes `acquire (constrained: requires
      salary out)` or downgrades — never silently recommend a move the cap forbids),
      and a `team_trajectories` input from script 06 plus a `cap_context` input from
      `data/reference/cap_context_2026.csv`; implement against that skeleton.
      **Two requirements carried from the 2026-07-19 analytics-reviewer triage:**
      (WARNING 2) join `fallback_used` from `output/trajectory_league_trends.csv` and
      surface it, so a residual-slope-approximation trajectory is never presented as a
      random-slope BLUP; (NOTE 5) always surface the `interval_spans_zero` footnote so an
      "improving"/"declining" label is never read as a fact when its interval spans zero.
- [x] **Gather `data/reference/cap_context_2026.csv` (AMENDMENT_02 §3a/§4) -- DONE (populated
      on main, commit 8f6956b: 15 teams, flexibility_tier + source Spotrac + as_of_date
      2026-07-19; expiring_count/max_supermax_count left NA by design) -- all 15
      teams, hand-curated by Wendy from Spotrac WNBA team pages and Her Hoop Stats
      contract data, NOT scripted scraping. ~1 hour, same day as script 08. Every row
      needs a `source` and `as_of_date`. Tiers, not to-the-dollar figures.**
- [x] Present the deadline-read table (the core deliverable) -- `output/deadline_read.csv`
      + `.md`; lever distribution 5 acquire / 4 adjust / 6 hold, every acquire cap-conditioned
- [x] **Run `gm-agent` on the deadline-read table before any prose is written around
      it — triage feedback, log below. Includes the cap-conditioning check added by
      AMENDMENT_02 §4.** RUN 2026-07-20; findings + PROPOSED triage logged below under
      "gm-agent, deadline-read table run." Triage is PROPOSED, awaiting Wendy's decision. (SINCE RESOLVED: accepted and applied in ea2ee92; see the acceptance note in the triage log.)

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

- [x] Implement `R/09_graphics.R` (includes one trajectory graphic maximum -- small
      multiples, adjusted trends, expansion teams highlighted; no rolling-window
      machinery, no month-by-month split tables) -- DONE 2026-07-20: `output/identity_map.png`,
      `output/generation_vs_making.png`, `output/trajectory_small_multiples.png`
- [x] Draft `output/findings.md`, including framework evaluation criteria
      (AMENDMENT_01 §2c: face validity, split-half stability, sensitivity check,
      garbage-time disposition) -- DRAFT DONE 2026-07-20. The split-half and
      alt-stratification §2c checks are scripted in a new `R/10_framework_evaluation.R`
      (-> `output/framework_evaluation.md`); garbage-time §2c is in R/06
      (`output/trajectory_sensitivity.md`); face validity is qualitative in the draft.
      Synergy case studies and the §3d structural paragraph are left as marked stubs.
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
- [x] **Run `analytics-reviewer` on the full findings draft -- triage feedback, log
      below. Includes the cap-figure traceability and tiers-only checks added by
      AMENDMENT_02 §4.** RUN 2026-07-20; findings + PROPOSED triage logged below under
      "analytics-reviewer, findings-draft run." Triage is PROPOSED, awaiting Wendy's
      decision -- no fix applied to `findings.md`. (SINCE RESOLVED: accepted and applied in ea2ee92.)

## Jul 26-27 — Publish (repo + writeup + WHoopsLab version)

- [ ] Final review, publish

## Jul 27-Aug 2 — Individual outreach notes, deadline-week engagement

- [ ] Boki Wang (GSV), Eli Horowitz / Lauren Manis / Mark Schindler (Toronto),
      Portland HC contact (Portland). Optional: Todd Whitehead (Synergy courtesy).

## Fit analysis and future modeling

**Methodology doc (DONE 2026-07-21):** `output/methodology.md` -- the why-these-methods
rationale companion to findings.md, including the "defining fit" design (gap-fill vs
style-amplify, philosophy selects the mode, the honest value-vs-cost split).

**In-scope fit first part (DONE 2026-07-21, analytics-reviewer gated): `R/11_generation_gap.R`**
-> `output/generation_gap.md` + `.csv`. Decomposes each team's generation gap versus the league
into a VOLUME gap (FGA per 100 possessions -- turnovers, offensive rebounds, pace) and a MIX
gap (shot selection, attributed by zone via a centered-pps split), which sum to the team's
total gap and reconcile with shot_generation_per100 (Pearson 0.99). Reports a primary_driver
per team (volume for 10 teams, mix for 5), labels each mix zone (missing efficient looks vs
over-reliant on low-value), flags identity-driven zones (protect, not fill) via the ICC>=0.15
anchor rule, and assigns a fit mode (gap-fill: NYL/PHX/SEA/WAS; style-amplify/protect: the
other 11). Question-1 refinement, offense-only, NO player-value or dollar component.
Analytics-reviewer gate run 2026-07-20/21: no R/11 blockers; the volume+mix redesign was built
in response to its WAS warning (a low-volume team judged only on per-shot mix is misread), and
its methodology fixes (centered-formula description, Spearman 0.98 generation / 1.00 making)
were applied. Reviewer NOTES deferred: minor wording only.

**Standing / window layer (DONE 2026-07-21, gm-agent gated): `R/12_standing.R`** ->
`output/standing.csv`. Computes each team's record from game results and a `window` tier
(buyer / bubble / seller), blending win-loss record AND per-game scoring margin (equal-weight
z-scores, so a lucky record is not miscast). Window conditions the RECOMMENDATION, never the
diagnosis (identity/generation/making/trajectory stay record-independent -- the separation is
what preserves the "reads beyond the record" claim). Distribution: 5 buyer / 4 bubble / 6
seller. R/08 (deadline read) and R/11 (generation gap) both gained a window-conditioned
`recommendation`/`fit_read` derived from one SHARED logic (keyed on window + generation tier +
making + making-trajectory), so the two documents agree verb-for-verb. Design highlight the
standing data surfaced: record and offense-diagnosis disagree sharply -- LVA is 17-7 (buyer)
on the 7th-percentile shot generation carried by 100th-percentile but declining making, so it
reads "reassess" (a paper tiger); WAS is a .522 bubble team despite the league's worst offense.
gm-agent runs 2026-07-21: (1) on the pre-standing generation gap -- affirmed the volume-vs-mix
split, flagged that the recommendation ignored standing; (2) re-run with the standing gate --
affirmed the window layer "earns its place", named LVA the headline insight, and flagged a
point-differential window bug (PDX) plus a recommendation verb-seam between the two docs. Both
were fixed in a follow-up pass (point differential made a real window axis -> PDX reflows to
seller; the two documents unified on one recommendation vocabulary). Remaining gm items are
deferred to the case studies (the salary-out ledger, roster spots, zones-to-roles, market
supply). FOLLOW-UP before publish: an analytics-reviewer pass on R/12 + the standing-gated
R/08/R/11 -- DONE 2026-07-22, gate CLOSED (see the triage log entry
"analytics-reviewer, standing-layer gate (2026-07-22)" below).

**analytics-reviewer, standing-layer gate (2026-07-22) -- CLOSED.** Read-only pass on
R/12_standing.R and the standing-gated R/08/R/11. Returned NO BLOCKERS, two warnings and
two notes. Wendy accepted all four; applied 2026-07-22:
- **W1 (ACCEPT) -- trajectory-directional caveat in the recommendation.** The reassess
  and bubble recommendations lean on the making-trajectory direction, but all four
  affected teams (LVA/NYL/ATL/TOR) have a shot_making_residual interval that spans zero.
  Carried `making_interval_spans_zero` into `reconcile_recommendation()` (R/08) and
  `buyer_branch_text()`/`bubble_branch_text()`/`load_making_trajectory()` (R/11); the
  reassess and bubble strings now append "(trajectory directional)" when the interval
  spans zero, so the recommendation carries the same caveat the "*" gives the trajectory
  column. Diagnostic columns verified byte-identical before/after; cross-doc agreement holds.
- **W2 (ACCEPT) -- "bubble" is a blended-window read, not the literal 8-seed.** The
  standing_score blend can pull a sub-.500, several-games-back team up into the bubble band
  on scoring margin (the TOR case: 10-14, window "bubble" on a -70 differential). Added a
  clause to the R/12 header and output/methodology.md pointing readers to
  games_back_from_8th for literal playoff-line distance and reframing "straddling the
  8-seed line" as "near the standing_score playoff line".
- **Note 3 (ACCEPT) -- reconciliation citation.** R/12 header now cites the actual test
  (tests/testthat/test-possession-invariants.R:10) instead of "R/04_reconcile.R / the test
  suite".
- **Note 4 (ACCEPT) -- precise wording.** methodology.md "point differential far worse than
  most sellers'" -> "worse than the median seller" (PDX -130 vs the -118 seller median).

**Still post-deadline, NOT prioritized (build only if time, out of scope for Aug 2 --
cut list, tiers-not-dollars, no player-value layer):**

- **Fit-vs-cost target scoring (value per cap dollar).** Rank candidate targets by
  `(fit_delta x player_value_over_replacement) / cost`, where cost = cap hit + outgoing asset
  value. Requires: a player-value metric (win shares / RAPM, not currently built), to-the-
  dollar cap data (breaks tiers-not-dollars; year-one-CBA trackers lag), and asset valuation
  for the outgoing package (a trade machine, explicitly on the cut list). The in-scope first
  part above (R/11, naming the gap) is now built; what remains post-deadline is the
  player-value and cost sides. Recommended interim step that stays in scope: a
  "cost-adjusted feasibility" read -- keep fit categorical but rank profiles by fit WITHIN a
  team's feasible asset class, so the output is "best fit you can afford," never "best fit,
  cap be damned." Needs no new data.
- **Trade-outcome / win-share-boost model.** Predict a team's win delta from a fit-adjusted
  roster add. Requires: a player-value baseline, a counterfactual lineup / minutes model, a
  style-fit interaction term, and transaction history as training labels -- none identifiable
  from one half-season of open play-by-play, and it produces the fake-trade content the
  gm-agent persona rejects. Different product, not a tweak to this one.

**Mentor-informed v2 roadmap (defense + lineup flexibility), 2026-07-23.** From a mentor
brain dump. Decision (Wendy, 2026-07-23): case studies + v2 roadmap; NO in-window quant
build (deadline physics, and the three publish blockers keep priority). Defense enters v1
QUALITATIVELY through the Synergy case studies -- the case-study template now carries a
"Defensive fit and roster-disruption read" checklist (switchability, athleticism,
screen-assist/off-ball context, second-unit stabilization, defensive pace/activity,
roster-disruption cost), coach-agent gated, Synergy-attributed, quarantined. The
reproducible quantitative versions are v2 (all buildable from open PBP; feasibility probed
2026-07-23 -- box-defense events and 5-man lineup reconstruction both present, NO tracking /
matchup / defender / screen columns exist):
- **v2 FLAGSHIP -- lineup-flexibility "chess match" layer.** Reconstruct 5-man lineups from
  substitutions (proven via R/13's 99.9% 5-on-court gate); measure a target's teammate /
  lineup versatility and the acquiring team's thin second-unit slots (minutes drop-off from
  starters to bench). Most novel reproducible direction; needs a real build window.
- **Defensive-activity screen (symmetric to R/13).** DREB/40, STL/40, BLK/40, forced-TOV
  (steals + drawn offensive fouls), foul rate, as coarse tiers. Box-only, heavily caveated
  (no rim-protection or matchup context). Would extend R/13 / a new R/15.
- **Usage / offense-disruption fit-cost (the "easy add").** Per-player usage tier (usage
  already computable as poss_used); flag "improves defense without demanding the ball" =
  high defensive-activity tier AND low usage AND adequate 3P rate. Cheapest; reuses R/13.
- **Defensive rebounding by opponent shot-zone (the Dallas midrange example)** and
  **pace-fit** (transition-involvement proxy). Smaller follow-ons; A4 needs event-linkage.
- OUT OF SCOPE (no open-data support, not clean from Synergy exports either): tracking-based
  switch rates, true rim-deterrence, matchup-level defensive load, hustle stats.
- Dependency: apply the pending R/13/R/14 review triage before any v2 work builds on the
  value/fit layer.

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

**Triage resolved (Wendy's decisions, 2026-07-19).** The proposals above were triaged.
Dispositions and what was done:

- **BLOCKER 1, WARNING 1, NOTE 1, NOTE 4 -- ACCEPTED, FIXED.** Applied together:
  R/06's Inputs header now declares `team_game_shot_making.rds` plus the three §2c
  inputs and states "run 07 before 06" (correct order 05 -> 07 -> 06); R/07:162 now reads
  "expected-points baseline"; the shot_class precedence is documented with a comment; the
  MIN_CELL_N comment now states the SE near 0.10 (per-shot points SD close to 1.0).
- **WARNING 2 (fallback_used on the per-team trajectory table) -- ACCEPTED, deferred to
  R/08.** Decision: R/06's per-team output is left as-is; R/08 must join the
  `fallback_used` flag (from `trajectory_league_trends.csv`) when it is built, so the
  deadline-read never presents a residual-slope approximation as a random-slope BLUP.
  Recorded as an R/08 requirement below.
- **WARNING 3 (§2c sensitivity pass) -- ACCEPTED, RUN NOW (not deferred).** Implemented
  the pre-registered garbage-time-exclusion re-run in R/06 (see eda_notes.md §6):
  `recompute_trajectory_metrics_excluding_garbage()` re-derives all five shortlist
  metrics per team-game on non-garbage possessions/shots (period >= 4 and |margin| >= 20,
  3.9% of possessions), holds the expected-points baseline fixed, and re-fits with the
  same trajectory machinery. Result in `output/trajectory_sensitivity.md`: all five
  league trends keep their sign and their non-significance (no sign flip, no p < 0.05
  crossing) -- the league-level nulls are not garbage-time artifacts. Per-team
  improving/flat/declining labels move for 11 team-metric cells (most for
  live_ball_tov_rate, 5 of 15), which is expected for interval-caveated directional reads
  and reinforces basing strong claims on the league fixed effect, not per-team labels.
- **WARNING 4 (em dashes in R/06 comments) -- ACCEPTED, deferred as a repo-wide sweep.**
  Not fixed in this diff. R/02-R/06 all carry pre-existing em dashes in comments; the fix
  is one language-hygiene pass across the repo, tracked as post-deadline cleanup below.
- **NOTE 2 (GSV refutes H3's below-expectation premise) -- ACCEPTED, act at findings
  stage.** No code change. Carried forward as a flag for the findings draft: report H3 as
  a refutation/null, not a quiet reframe.
- **NOTE 3 (in-sample baseline) -- DEFERRED.** One methodology sentence at the writing
  stage.

New post-deadline cleanup tracked from this triage:
- Repo-wide language-hygiene sweep (em dashes -> `--` in R/02-R/06 comments and PLAN.md
  prose). Deferred per WARNING 4.

**Triage for the two 2026-07-20 gates (gm-agent + analytics-reviewer) below: ACCEPTED by
Wendy and APPLIED in commit `ea2ee92`.** Applied: gm NOT YET 4 (R/08 below-floor flag;
WAS/PDX show "room (below floor)"), analytics BLOCKER 1 (removed the PDX assisted-rate
identity claims), WARNING 2 (R/07 writes `output/team_generation_making.csv`), WARNING 3
(WAS wording), WARNING 4 (World Cup dates cited to AMENDMENT_02), NOTES 6-7 (wording +
fallback-p caveat). Held as decided: gm NOT YET 2 (deferred, case-study scope), NOT YET 3
(rejected the dollar-band fix, tiers-not-dollars), NOTE 5 (deferred); gm NOT YET 1/5 and
the room questions were already handled in the findings prose.

**gm-agent, deadline-read table run (2026-07-20).** Ran on `output/deadline_read.md` +
`.csv` the moment R/08 produced them, before any prose. The agent affirmed the floor:
the lever rule is applied correctly across all 15 rows, every acquire is cap-conditioned
and attributed, no CBA mechanic is unattributed, no old-CBA intuition leaked. It named
the LVA <-> ATL mirror as the forwardable idea and ATL as the sharpest disagreement with
consensus. **Triage below is PROPOSED, NOT applied; the deadline-read table is unchanged
pending Wendy's decision.** (SINCE RESOLVED: Wendy accepted this triage; fixes applied in ea2ee92.)

- **NOT YET 1 (ATL hold vs its own declining making trajectory) -- PROPOSED ACCEPT, in
  findings prose.** Addressed in `findings.md` Section 5: ATL argued explicitly, the
  declining-making contra-signal named as the open risk. Table unchanged.
- **NOT YET 2 (acquire rows have no need-profile) -- PROPOSED DEFER (scope).** Fit/need
  profiles are case-study-only attended work (HANDOFF §5f, AMENDMENT_02 §3c). Real gap
  flagged: the planned case studies (GSV/TOR/PDX) cover zero acquire teams.
- **NOT YET 3 ("tight -> minimum/depth only" over-compresses PHX vs NYL) -- PROPOSED
  REJECT the dollar-band fix** (violates tiers-not-dollars, AMENDMENT_02 §3a); alternative
  (soften the string, or split the tight tier) is Wendy's cap-curation call.
- **NOT YET 4 (salary floor flips WAS/PDX) -- PROPOSED ACCEPT (strongest fix).** Floor is
  85% of cap = $5.95M (cba_rules §1); WAS and PDX (both room tier) sit below it, so pushed
  to add. Add a below-floor boolean flag (tiers-compatible), publish "room (below floor)".
  Not applied; awaiting greenlight.
- **NOT YET 5 (adjust needs a driver) -- PROPOSED ACCEPT, in findings prose.** Addressed
  in `findings.md` Section 5 (e.g. IND overperforming its process -> consolidate). Table
  unchanged.
- **THE ROOM'S QUESTIONS (buyer/seller posture, roster spots, market supply, expansion
  overlay, break-both-ways) -- PROPOSED DEFER** to the structural paragraph (§3d) and case
  studies. The buyer/seller limitation is stated as a caveat in `findings.md` Section 5.

**analytics-reviewer, findings-draft run (2026-07-20).** The full-findings-draft gate on
`output/findings.md`. The reviewer confirmed the core numbers all trace to source files
(ICCs, the five league trends and p-values, generation/making percentiles, split-half and
Spearman values, garbage-time 3.9%, reconciliation deltas), that H1/H2 nulls and the H3
refutation are written against the registry, and that vocabulary, hygiene, tiers-not-dollars,
and Synergy quarantine all pass. **Triage below is PROPOSED, NOT applied; `findings.md` is
unchanged pending Wendy's decision.** (SINCE RESOLVED: Wendy accepted this triage; fixes applied in ea2ee92.)

- **BLOCKER 1 (assisted-rate identity claim on a shrunk BLUP; self-contradiction) --
  PROPOSED ACCEPT.** assisted_rate ICC 0.0004 shrinks all BLUPs to ~0.649, so the PDX
  "decision-relevant mover" sentence (Section 1) and "PDX's schedule-adjusted assisted rate
  is first in the league" clause (Section 4) are claims on noise and contradict Section 1's
  own "close to noise" line. Fix: delete both, keep only the interval-caveated trajectory
  direction note. Recommend accept (correctness fix).
- **WARNING 2 (GSV "+0.6 per 100" not in a readable output) -- PROPOSED ACCEPT.** The value
  lives only in binary `team_generation_making.rds`; the H3 refutation rests on its sign.
  Fix: have R/07 also write a readable `output/team_generation_making.csv` and cite it (the
  50th percentile alone does not establish "above own expectation").
- **WARNING 3 ("WAS worst on both axes" inaccurate) -- PROPOSED ACCEPT.** WAS is 0th on
  generation but 7th on making; ATL is 0th on making. Fix: "worst on generation and
  near-worst on making."
- **WARNING 4 (World Cup dates cited to cba_rules §5, which does not contain them) --
  PROPOSED ACCEPT.** The Aug 31-Sep 16 bracket traces to AMENDMENT_02 line 34, not
  cba_rules §5. Fix the citation in `findings.md`, `deadline_read.md`, and R/08.
- **NOTE 5 (test summary not captured to a file) -- PROPOSED DEFER.** Optionally write the
  testthat summary to output for a stranger's reproducibility.
- **NOTE 6 ("independent confirmation" overstates split-half vs ICC) -- PROPOSED ACCEPT
  (soften).** Both measure within-season stability on the same data; change to "consistent
  with the ICC ordering."
- **NOTE 7 (trajectory p-values are from the documented fallback) -- PROPOSED ACCEPT.** Add
  a one-line caveat that the p-values are approximate under the random-intercept fallback.

**Fable-5 analytics-reviewer second-opinion run (2026-07-20)** on `output/findings.md` + PLAN.md.
Confirmed every core number still traces to source and the guardrails hold. Found two real
blockers the earlier gates missed, plus warnings; Wendy ACCEPTED all and they were APPLIED:
- B1: `build_identity_summary()` now filters the z-score pool to metrics with mixed-model
  ICC >= 0.15 (eda_notes.md spec change 6), so the deadline-read identity column no longer
  anchors on noise metrics. GSV now reads as a perimeter profile, matching the findings prose.
- B2: `deadline_read.md` discloses the random-intercept fallback behind the trajectory labels.
- W1-W5 (findings + reconciliation_report): H2 interval claim corrected, stale salary-floor
  sentence fixed, test summary captured to `output/test_summary.txt`, trajectory fallback-output
  deviation disclosed, and the stale em dashes in reconciliation_report.md regenerated out.
- W6-W7 (PLAN): the pre-Jul-23 data-refresh caveat and the stale "PROPOSED" statements annotated.
- Deferred (notes): readable strata CSV, "0.996" rounding, one methodology line that agent
  gates supplement rather than replace human spec-tracing.
A gm-agent re-gate on the corrected identity_summary column is the remaining follow-up.

**Full three-gate review run (2026-07-26) -- PROPOSED, awaiting Wendy's decision.** Ran all
three review agents on the current output at Wendy's request: analytics-reviewer on the full
findings draft, gm-agent on the deadline-read table + framework sections, coach-agent on the
fit reads + case-study template (the Synergy case studies are still stubs, so coach reviewed
`output/fit_targets.md` / `deadline_read.md` / `analysis/case_study_template.Rmd` and was told
to flag the case-study gap rather than penalize the intentional stub). Every framework number
traced clean (analytics-reviewer reconciled ICCs, trajectory trends, gen/making percentiles,
split-half, stratification, garbage-time, H2 intervals to source CSVs); all guardrails passed
(vocabulary, Synergy quarantine, tiers-not-dollars, H1/H2/H3/H-null verbatim, language hygiene).
The material findings cluster on the findings draft being stale relative to the pipeline, and
on two action-shaped columns that disagree. Consolidated triage, proposals only:

- **TIER A (>=2 gates independently, high-confidence, pure edits):**
  - A1 -- Deadline-read action columns disagree; "Lever" reads like the action but is diagnosis
    (gm #1 + analytics-reviewer #2). PROPOSE ACCEPT: rename Lever -> "Offense diagnosis," make
    Recommendation the leftmost action column, delete the now-false §5 buyer-seller limitation
    bullet (R/12 encodes exactly that posture now).
  - A2 -- Doubled `movability: movability: hand-curate` token + `[target]` tag on uncurated
    rows (Leite/Johnson/Morrow) (gm #3 + coach). PROPOSE ACCEPT: fix token, drop to `[context]`
    until curated.
  - A3 -- "Affordability PENDING" header contradicts populated affordability rows (gm #4 +
    coach). PROPOSE ACCEPT: delete the PENDING line (bands are filled 10/11).
  - A4 -- BLUP/`shot_making_residual`/random-slope machinery leaking into reader-facing table
    footers (coach #7 + gm). PROPOSE ACCEPT: restate as "finishing relative to shot quality" /
    "directional trend," move the fallback sentence to an appendix, keep the caveat.
- **TIER B (single-gate, concrete correctness):**
  - B1 -- Provenance line unrunnable: claims R/01-10 but R/08 needs standing.csv from R/12
    (analytics-reviewer #1). PROPOSE ACCEPT: state real run set/order (...07, 08, 11, 12, with
    12 before 08).
  - B2 -- TOR "25 games" -> 24 (analytics-reviewer #3; 1,630 shots correct, team-games sum to
    364 only with TOR at 24). PROPOSE ACCEPT.
  - B3 -- Below-floor over-read as a deadline mandate; CBA remedy is a season payout, not a
    forced trade (gm #2). PROPOSE ACCEPT: downgrade to "soft nudge," which also clears the PDX
    "must add vs sell" contradiction.
  - B4 -- TOR `lean buy` on a zero-spanning trajectory while ATL (also zero-spanning) gets no
    list (gm #5). PROPOSE ACCEPT: demote TOR to "reassess after the break."
  - B5 -- `player_value.csv` emits a per-40 value-vs-replacement (9.207) reading like the VOR
    layer methodology says does not exist (analytics-reviewer #5). PROPOSE ACCEPT: relabel as an
    ordinal box-score production tier; confirm no such figure reaches findings.
- **TIER C (coach-usability, accept-after-fix, larger than a token edit):**
  - C1 -- No position/size column anywhere (coach; single biggest coach gap -- cannot slot a
    lineup). PROPOSE ACCEPT if time; else DEFER with an explicit "offense-only, no position"
    caveat on each list.
  - C2 -- Fit reads stop at shot diet, not fit; label by role (creator/movement/secondary) not
    bucket; add on-ball/off-ball + duplication clause (coach). PROPOSE ACCEPT (prose).
  - C3 -- No defensive read for buyer teams (DAL/MIN/IND) with no case study (coach). PROPOSE
    ACCEPT the minimal version: one "offense-only, get your own defensive read" line per list.
  - C4 -- Ogwumike is lead `[target]` for DAL+MIN+TOR at once (gm #7 + coach). PROPOSE ACCEPT:
    cross-reference the thin-market note so no one treats one player as three adds.
- **TIER D (defer post-deadline):** emit `window_rank` into standing.csv (or header note) so
  rank-vs-window stops looking contradictory (analytics-reviewer #4); §2 inline directional
  caveat cross-ref (analytics-reviewer #6); expansion-draft seller-timing lever; per-team
  roster-spot counts; broader "trajectory non-informative this half" note in §3.
- **MANDATORY pre-publish (unchanged, both gates):** re-pull cap tiers within 48h -- IND is
  tier-fragile at $6,654 from capped, one minimum move flips its conditioning; keep the $5.95M
  floor figure (CBA structural constant, within tiers-not-dollars) on the re-verify list.
- **Universally accepted / forwardable (no action):** the ATL hold (all three gates); the
  cap-feasibility conditioning of `acquire` (CBA-current -- "the part I'd trust at the table");
  the generation-vs-making split; the full reproducible numeric core.

**APPLIED 2026-07-28 (Wendy's decision: "start on tier a and b"). Tier A + Tier B
accepted and implemented; Tier C + Tier D remain open.** Changes, all reproduced
through the scripts (full testthat suite green, 60 pass / 0 fail; outputs
regenerated):
- A1 (R/08 + findings §5): the deadline-read table's action-verb "Lever" column is
  renamed "Offense diagnosis" and shows descriptive phrases (generation-short /
  balanced / generation-rich, new classify_diagnosis()); the Recommendation column
  is moved to be the leading action column and is the only action column. The
  acquire/adjust/hold machinery still runs internally (feeds cap conditioning and
  the recommendation), just no longer displayed as an action. findings §5's stale
  "the lever encodes no buyer-or-seller posture" limitation bullet is deleted
  (R/12 window now supplies that posture) and replaced with the window-is-a-proxy
  limitation; a diagnosis-vs-window reconciliation paragraph added.
- A2 (R/14): fixed the doubled `movability: movability: hand-curate` token
  (movability_disp drops the redundant prefix), and a blank/uncurated movability
  now reads `context`, never `target`, until curated (actionable no longer treats
  NA movability as gettable). Leite/Morrow/Johnson/Barker correctly drop to context.
- A3 (R/14): deleted the stale "Affordability is PENDING" header line (bands are
  curated 10/11); replaced with an accurate "shown where a band is curated" note.
- A4 (R/08): removed BLUP / shot_making_residual / random-slope machinery from the
  reader-facing deadline_read.md intro and trajectory footnote; restated as
  "finishing relative to shot quality" and "directional trend," modeling detail
  pointed to methodology.md.
- B1 (findings): provenance line corrected to the real run order (01-09, then 11
  and 12, then 08; 13 then 14) -- the old "R/01-R/10" was unrunnable (R/08 reads
  R/12's standing.csv).
- B2 (findings): Toronto "25 games" corrected to 24 (10-14 in standing.csv;
  team-games sum to 364 only at 24). 1,630 shots was already correct.
- B3 (R/08 + findings §5): below-floor downgraded from "pushed to add salary" to a
  soft nudge (a below-floor team can satisfy the floor by paying the shortfall out
  over the season; it is not a deadline-forcing mandate). Resolves the PDX
  "below-floor must add" vs "seller: sell" contradiction.
- B4 (R/08 + R/11, both bubble branches): a bubble team no longer asserts a
  directional lean (lean buy / lean hold or sell) when the making-trajectory
  interval spans zero; it defaults to "hold." TOR drops from `lean buy` to
  `judgment (hold)` and loses its fit_targets list (now hold-judgment, no list),
  matching ATL/NYL. WAS keeps its lean (its interval does not span zero). R/08 and
  R/11 stay verb-for-verb consistent.
- B5 (R/13 + R/14): the player-value exhibit's `vor` column renamed `prod_score`
  and reframed as an ordinal box-score production index in Game-Score points, NOT a
  value-over-replacement / wins metric; production_tier stays the published unit.
  R/14 updated to consume prod_score. The number does not enter findings.

**APPLIED 2026-07-28 (Wendy's decision: "fix tier c and d"). Tier C + Tier D
accepted and implemented; outputs regenerated, full testthat suite green (60/0).**
- C1 (R/14 + candidate_contracts_2026.csv): added a hand-curated `position` column
  to the candidate reference file (guard/wing/forward/center), the same class as
  contract_band -- it is NOT in the open PBP, so it is curated + attributed, blank
  until filled from a roster source (renders `pos: hand-curate`). The reproducible
  interior-vs-perimeter signal is the rim/mid/three profile already on each line;
  the doc says to read profile and position together (a stretch big shoots threes).
  Position VALUES still need Wendy's roster-source curation, exactly as the bands
  did before she supplied them.
- C2 (R/14): added a reproducible `creation` profile per candidate (on-ball creator
  / off-ball finisher / combo) from the assisted share of her made field goals (a
  shot-creation profile, descriptor-derived, never a play-type claim; thresholds
  0.40/0.65 stated). It qualifies the advantage line so Plum (on-ball creator) and
  Taylor/Hiedeman (movement/combo) no longer read as the same "perimeter shooting."
  Duplication vs incumbents is stated as the coach's own read, not modeled.
- C3 (R/14): every buy-side list now carries an explicit offense-only defensive
  disclaimer (no matchup/tracking data in the open PBP; get your own defensive read).
- C4 (R/14 + findings §5): a candidate who is an actionable `target` on more than
  one list is flagged inline ("SHARED TARGET (targeted by DAL, MIN): one player,
  not independent adds"); findings §5 names the Ogwumike DAL+MIN case (TOR dropped
  off after the B4 demotion, so the shared set is DAL+MIN, not the pre-fix
  DAL/MIN/TOR).
- D1 (R/12): standing.csv now emits `window_rank` (the standing_score rank that
  actually assigns the window) next to `window`, so it no longer looks broken
  against the win_pct `rank` column (they are different orderings by design).
- D2 (findings §2): added the inline directional caveat cross-ref (shot making
  split-half only 0.56, Section 6) to the ATL "finishing result" / LVA
  "unsustainable" single-season claims.
- D3 (findings §5): added the expansion-draft seller-timing limitation (a seller
  may deal a non-core player before the expansion draft; the framework uses it only
  to mark availability, does not price its effect on the ask).
- D4 (findings §5): the roster-spot / open-spot assumption is stated, and the
  offense-only fit-read limitation is now an explicit bullet.
- D5 (findings §3): added the plain statement that no team's finishing trajectory
  this half clears "clearly improving," so a trajectory arrow cannot justify a buy
  and bubble teams with zero-spanning intervals default to hold (the TOR case).

Only the MANDATORY pre-publish cap re-pull remains open from this triage: re-verify
the cap tiers within 48h of the deadline (IND is tier-fragile at $6,654 from
capped, one minimum move flips its conditioning) and keep the $5.95M floor figure
on the re-verify list. Position VALUES in the candidate reference file also await
Wendy's roster-source curation (the column and rendering are in place).

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

## Still REQUIRED before publish (2026-07-22, do not drop -- these are open, not done)

The framework pipeline (01-12), the three graphics, the framework evaluation, and the
analytics-reviewer / gm-agent gates are built and closed. The following are still
NECESSARY before the July 26-27 publish window and are NOT optional polish:

1. **Synergy case studies + the §3d structural paragraph in `output/findings.md`.**
   Currently TODO stubs. Synergy numbers stay quarantined in `analysis/` case-study
   prose with the "Source: Synergy Sports | 2026 WNBA" attribution and never enter
   data/models/output tables (reproducibility boundary).
2. **`coach-agent` gate.** Not yet run. Required on the drafted case-study sections
   (GSV, TOR, PDX) once they exist, per AMENDMENT_01 Part 3. This is the one mandatory
   review gate still un-fired.
3. **Primary-source cap/CBA verification + date-stamp (AMENDMENT_02 §4).** The four-item
   pre-publish checklist against `data/reference/cap_context_2026.csv` and
   `cba_rules_2026.md` still needs Wendy's manual re-verification and a fresh as-of date
   before the numbers are defended in print. Tiers-not-dollars stands regardless.

These three block publish. The player-value work below does NOT block publish and does
not displace them.

## Next: fit-vs-cost / player-value layer (2026-07-22, moved from post-deadline)

Wendy has elected to attempt this layer this week (time permits: ~5 days to the publish
window). NOTE THE STANDING CONFLICT before building: this layer as originally specced
`(fit_delta x player_value_over_replacement) / cost` collides with two published rules --
(a) no player-value metric exists in the framework, and none is cleanly derivable from
one half-season of open play-by-play (a validated RAPM/win-shares figure is a separate
product); (b) "cost = cap hit" is dollars, which breaks the tiers-not-dollars rule
(AMENDMENT_02 §3a); and (c) the outgoing-asset / trade-machine side is on the handoff §6
cut list. A guardrail-compliant version has to decide the player-value SOURCE and the
COST representation up front. Whatever is built here is additive and
must not touch the reproducibility boundary of the published 01-12 numbers.

**Scoping decisions (2026-07-22).** Value source: player-value proxy derived from open
PBP (stays inside the reproducibility boundary). Cost: tiers + coarse contract bands
(min/mid/max), never dollars. Primary metric: box value over replacement. Placement:
a new published table plus prose (later narrowed by review, see below).

**Design review, 2026-07-22 (analytics-reviewer + gm-agent, both on Fable 5).** Ran both
agents on a written design doc BEFORE writing code, to catch a wrong foundation cheaply.
They converged. Findings and PROPOSED triage (NOT yet Wendy-approved; recorded so the
record exists while forward motion continues on the low-regret core):

- Metric: **Game Score per 40 minutes** is the right engine (both). Reject Win Shares
  ("wins" is an overclaim from a half-season; assembly cost buys false precision), PER
  (opaque, biased), custom weights (un-citable), RAPM-family (half-season noise). Weights
  are NBA-derived and unvalidated for the WNBA -- disclose like the 0.44-FT convention.
  PROPOSED: ACCEPT.
- **Per-40, not per-100.** The doc's premise that possessions.rds sidesteps minutes
  reconstruction was wrong: a player per-100 needs stint/lineup attribution, MORE work
  and adjacent to the on-off cut list. PROPOSED: ACCEPT, commit to per-40.
- **Demote the value number.** A VOR leaderboard is the piece's biggest overclaim
  (volume-rewarded, defense-blind, half-season-unstable). Build it league-wide and
  reproducible, publish it only as production TIERS on NAMED candidates inside fit reads.
  Reframe R/13 = the screen, R/14 = the fit-first deliverable. PROPOSED: ACCEPT.
- **Fit-to-need is the product; value is a secondary filter.** Shop order: need ->
  attainability -> tier -> value. Candidate pool = the sellers in standing.csv (currently
  absent). Fit table must obey the deadline_read recommendation verbs (no buy lists for
  LVA/reassess or sellers). PROPOSED: ACCEPT.
- **No value/cost ratio, ever** (needs per-player dollars + package valuation, both out).
  Rank fit-then-value WITHIN the feasible asset class. Strike "wins replaced" language.
  PROPOSED: ACCEPT.
- **Offensive-fits-only scope statement** (not a footnote): a defensive need cannot be
  served by this table. PROPOSED: ACCEPT.
- **Replacement anchor:** drop 20th-pct-of-rotation (circular); anchor to sub-rotation
  mean, keep 20th-pct as a sensitivity. PROPOSED: ACCEPT.
- **Eligibility floor** must include the handoff §5g player-claim threshold (>=100 FGA or
  >=150 possessions used) AND a minutes floor (~300 min). PROPOSED: ACCEPT.
- **Register the layer as EXPLORATORY** (dated addendum; eda_notes.md is frozen) -- no
  hypothesis test, all statements descriptive. PROPOSED: ACCEPT.
- **Abort criterion:** minutes-reconstruction validation gate green by end of Jul 24, else
  the layer returns to post-deadline (does not displace the three publish blockers).
  PROPOSED: ACCEPT.
- Split-half reliability on GmSc/40 in R/10; garbage-time sensitivity for bench box stats;
  coarse rim/mid/three + creation-class fit buckets (5-zone is noise at the FGA floor);
  fallback degrades to tiers-only if it fires; disclose shot-diet context contamination.
  PROPOSED: ACCEPT.
- Team-pace sensitivity, empirical-Bayes shrinkage, bootstrap bands, header run-order.
  PROPOSED: DEFER post-deadline.

- **BLOCKER (analytics), flagged not resolved -- Wendy's call:** the layer conflicts with
  handoff §5f ("No league-wide fit matrix ... no new player-level models"). Per CLAUDE.md
  this must be FLAGGED, not silently built past. PROPOSED resolution: log an explicit §5f
  amendment and restrict PUBLISHED fit-matching + value tiers to NAMED candidates; the
  league-wide Game Score table stays a reproducible output/ exhibit only. AWAITING Wendy's
  explicit decision before anything is published league-wide or R/14 is written.

**Proceeding now on the low-regret core only:** build and validate the reproducible R/13
Game Score engine (needed under every non-abort option). HOLDING the contested publication
decisions (§5f, R/14 fit table, what enters findings.md) for Wendy's explicit sign-off.

**BUILD STATUS (2026-07-22):**
- §5f conflict RESOLVED: Wendy authorized adjusting the handoff to match the scope.
  HANDOFF_wnba_deadline_framework.md §5f now carries the dated amendment (value screen +
  fit layer in scope; league-wide value stays an exhibit; published matching/tiers on
  named candidates only; tiers-not-dollars; seller pool; verb obedience; exploratory).
- **R/13_player_value.R built** (commit e17b7b0). Game Score over replacement per 40 min;
  minutes reconstructed from substitutions, 5-on-court gate 99.9% (abort criterion met);
  eligibility = §5g floor + 200 min; replacement anchored to the below-eligibility pool;
  split-half GmSc/40 per-40-rate reliability r = 0.65 (assists included); published as
  production tiers. Output output/player_value.csv
  (exhibit) + tests/testthat/test-player-value.R (green). Face validity holds (Wilson,
  Bueckers, Stewart, Mitchell, Ogwumike lead).
- **R/14_fit_targets.R built.** Wendy authorized running it. Candidate pool = eligible
  players on seller teams (attainability); on-style match (coarse rim/mid/three) as a fit
  GATE, then production tier within it (value as the within-fit ranker); verb-obedient
  (amplify DAL/GSV/MIN get on-style depth lists; buy-judgment TOR tentative; adjust IND
  low-priority; reassess LVA + hold-judgment + sellers get a deliberate no-list with the
  reason). Contract bands are a hand-curation template (data/reference/candidate_contracts_2026.csv,
  15 named candidates, bands blank), never fabricated; affordability gated by the acquiring
  team's cap tier only where a band is filled. Outputs output/fit_targets.md + .csv +
  tests/testthat/test-fit-targets.R (green).

**R/13 + R/14 review gate CLOSED (2026-07-23).** gm-agent + analytics-reviewer run on the
built layer (Fable 5). Triage decisions (Wendy):
- analytics BLOCKER "csv does not reproduce / non-monotonic tiers" -- REJECTED, verified
  false: R/13 re-run diffs byte-identical and tiers are perfectly monotonic (0 violations).
  Kept the suggested tier-monotonicity test as a cheap guard (now in test-player-value.R).
- analytics BLOCKER "split-half mislabeled + omits assists" -- ACCEPTED and FIXED: the
  reliability now correlates the PER-40 rate (not per-game totals) with assists included and
  sub-5-minute games dropped; the honest number is r = 0.65 (was a miscomputed 0.76). Still
  supports coarse tiers.
- D1 (minutes floor): keep 200 (logged rationale in R/13; deliberately below the ~300
  suggestion for midseason rotation inclusion).
- D2 (IND adjust list): CAP adjust-team lists at upper rotation -- IND already has three
  top-tier scorers and a thin bench, so a fourth star is the wrong "depth"; the list now
  shows only upper-rotation/rotation on-style pieces. Amplify teams keep top-tier.
- D3 (affordability inert + no movability screen, gm blockers): SHIP v1 with affordability
  PENDING and movability disclosed. Added a `movability` column to the contract template and
  md disclosures (affordability pending, movability not screened, asset cost out of scope,
  rim-heavy sellers absent by construction). Bands + movability remain Wendy's hand-curation.
- D4 (fallback branch): replaced the per-game fallback with stop() (abort criterion; the gate
  passes 99.9%).
- Also applied: coarse_profile NA-area bug fixed (three defined by shot type); games/minutes
  surfaced on each shortlist line (flags e.g. Plum's 12-game sample); style_match relabeled
  "on-style" and rounded; test-fit-targets de-brittled (no-list teams derived from
  deadline_read, not hardcoded) + an adjust-cap test; PLAN candidate count corrected 15 -> 11.
- DEFERRED (logged, post-deadline): full per-(game,period,team) minutes invariant test,
  creation-class fit bucket, garbage-time bench sensitivity, sorting player_value.csv by team,
  the capped-min cap-mechanic citation. Full testthat suite green after all fixes.
- STILL pending for publish (unchanged): hand-curate contract bands + movability (source +
  as_of_date), Synergy case studies + coach-agent gate, cap/CBA primary-source verification.

**R/14 movability + advantage pass (2026-07-25, post-merge follow-up).** Wendy supplied
contract data from the Her Hoop Stats WNBA Salary Cap Database (as_of 2026-07-25), covering
8 of 11 shortlisted candidates (Taylor, Gustafson, Johnson still need a second source).
Three refinements built:
- **Cored players are excluded, not just flagged.** movability now gates the POOL:
  `core` / `untouchable` are dropped before ranking (a cored player cannot be approached),
  and the shortlist backfills with the next on-style candidate. Plum (LAS, Core tag) drops
  out; DAL/GSV/MIN/TOR reflow, and one new name (Barker) was auto-appended to the template
  for curation. `keep` (long-term, not core) and `available` stay in, annotated.
- **Advantage label** on every recommendation: production tier + primary shot bucket (e.g.
  "top mid-range scoring", "upper rotation perimeter shooting") -- what the acquiring team
  gains. New advantage / primary_bucket columns in fit_targets.csv.
- **Expansion-draft logic in movability**: `available` means not core and not long-term, so
  a team may deal her for value before the expansion draft rather than lose her for nothing;
  documented in the md. Affordability is now LIVE where a band is filled (e.g. Copper's max
  band reads "over-tier" for tight/capped teams; it is flagged, not yet dropped).
- Template is now self-maintaining (append new backfilled candidates blank, preserve filled
  rows). New test: cored/untouchable candidates never appear; every row carries an advantage.
  Full suite green.
- **HYBRID keep-and-flag (2026-07-25, Wendy's decision, planned Opus / executed Sonnet per
  /planning-executing).** Replaced the drop-and-backfill of cored players with a hybrid:
  nothing is excluded from the pool; every best on-style fit is KEPT and flagged, and each
  list is guaranteed to carry at least N_GETTABLE=3 actionable rows (gettable + affordable),
  extending past unavailable/over-tier names (cap MAX_LIST=8) rather than dropping them.
  Each row now carries a `status` of `target` (movability available/keep AND band affordable
  or unknown) or `context` (core/untouchable, or over-tier band). Rationale: dropping gave a
  tidy list but hid the reasoning a GM wants to make; the hybrid shows "your best on-style fit
  is X but she is cored/over-tier" AND the realistic targets. Plum (core, max) now reappears
  in DAL/GSV/MIN/TOR marked `context`, each list keeping 3-4 `target` rows. Contract bands are
  now filled for 10 of 11 (Taylor/Gustafson/Johnson from Spotrac 2026-07-25; only the
  backfilled Barker is blank). STILL pending: Barker's band, the provisional movability review.
