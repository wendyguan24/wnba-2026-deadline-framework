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

- [ ] `analysis/eda_midseason.Rmd`: distributions of every planned style metric at the
      team-game level
- [ ] Missingness/coverage checks, including **resolving** (not just flagging) the
      Toronto shotdetail zero-row question from session 1's README/PLAN note
- [ ] Game-level variance per metric (previews which ICCs will be meaningful)
- [ ] Outlier games identified and dispositioned (keep / exclude / flag — blowouts,
      OT games)
- [ ] Raw trajectory eyeball plots for the Part 1 metric shortlist (below), before any
      trajectory model runs
- [ ] Garbage-time decision made explicitly and stated (include / exclude / flag
      possessions above a margin threshold in Q4) — AMENDMENT_01 §2c
- [ ] Output: `output/eda_notes.md` — findings, any spec changes they force, and the
      hypotheses registry below, copied in before script 06 runs

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

- [ ] Implement `R/05_features.R`
- [ ] Implement `R/06_models.R` — identity models (metric ~ (1|team) + (1|opponent))
- [ ] Implement `R/06_models.R` trajectory extension (§5c-bis) on the metric shortlist:
      1. Transition share (H1)
      2. Transition points per transition possession (H1, efficiency side)
      3. Assisted rate of FGM (H2)
      4. Live-ball TOV rate (H2)
      5. Optional: shot-making residual from script 07 (H3, GSV-relevant) — cut first
         if the block is threatened
      **Superseded by the project-wide cut order below (AMENDMENT_02 §4)** — the
      `trajectory` column itself is still never cut; the optional 5th metric is now
      the first thing to go project-wide, not just within this block.
- [ ] Present BLUP/ICC results and raw-vs-adjusted rank deltas
- [ ] **Run `analytics-reviewer` agent on script 06 results (BLUPs, ICCs, trajectory
      slopes) — triage feedback (accept / reject with one-line reason / defer
      post-deadline), log the triage below**

## Jul 23 — Data refresh check; expected-points baseline; deadline-read table; cap-context CSV

- [ ] Check `shufinskiy/nba_data` for a commit newer than `773ce29`; re-pin and re-run
      01-04 if found, confirm tests still pass; update baseline expectations
      deliberately if counts shift
- [ ] Implement `R/07_expected_points.R` (stratified xPTS baseline, not a trained model)
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

- (none yet — agents have not been run; no script 06 results exist)

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
failures). Per CLAUDE.md and the EDA gate (AMENDMENT_01 §2a-2b), the next stop is
`analysis/eda_midseason.Rmd` -> `output/eda_notes.md` (hypotheses registry) — do
not write `R/05_features.R` before that exists. `data/reference/cap_context_2026.csv`
also still needs Wendy's manual entry (AMENDMENT_02 §3a/§4) before `R/08` can be
implemented against real cap data, though that's a later (Jul 23) block.
`data/reference/cap_context_2026.csv` still needs Wendy's manual entry (AMENDMENT_02
§3a/§4, Jul 23 block) before script 08 can be implemented against real cap data.
