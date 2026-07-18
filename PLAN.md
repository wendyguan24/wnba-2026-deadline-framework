# PLAN — WNBA 2026 Trade Deadline Framework

Timeline from `HANDOFF_wnba_deadline_framework.md` §6, amended 2026-07-18 by
`AMENDMENT_01_trajectory_workflow_agents.md` (trajectory layer, EDA gate, review
agents — amendment wins on conflicts with the handoff). Hard deadline: publish July
26-27, 2026.

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

Not yet done (next session, implementation — still no data downloaded):
- [ ] Implement `R/01_download.R`; run deliberately so download date is logged
- [ ] Implement `R/02_parse_pbp.R`
- [ ] Implement `R/03_possessions.R`
- [ ] Implement `R/04_reconcile.R`; get all `tests/testthat/` assertions passing
- [ ] **Gate: show the reconciliation report before proceeding**

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
      Cut order if time-constrained: optional 5th metric, then H1's efficiency side,
      never the deadline-read `trajectory` column itself (fall back to raw trends
      with a stated caveat before dropping the column).
- [ ] Present BLUP/ICC results and raw-vs-adjusted rank deltas
- [ ] **Run `analytics-reviewer` agent on script 06 results (BLUPs, ICCs, trajectory
      slopes) — triage feedback (accept / reject with one-line reason / defer
      post-deadline), log the triage below**

## Jul 23 — Data refresh check; expected-points baseline; deadline-read table

- [ ] Check `shufinskiy/nba_data` for a commit newer than `773ce29`; re-pin and re-run
      01-04 if found, confirm tests still pass; update baseline expectations
      deliberately if counts shift
- [ ] Implement `R/07_expected_points.R` (stratified xPTS baseline, not a trained model)
- [ ] Implement `R/08_deadline_read.R` — skeleton now includes the `trajectory`
      column (improving / flat / declining, footnoted when the interval spans zero,
      via `format_trajectory_column()`) and a `team_trajectories` input from script
      06; implement against that skeleton
- [ ] Present the deadline-read table (the core deliverable)
- [ ] **Run `gm-agent` on the deadline-read table before any prose is written around
      it — triage feedback, log below**

## Jul 24-25 — Synergy case-study enrichment + fit reads (time-boxed)

- [ ] GSV full case study, Toronto and Portland lighter treatment
- [ ] If not converging by Jul 25, drop and ship diagnosis-only — still a complete piece

## Jul 25-26 — Writing, graphics, methodology notes

- [ ] Implement `R/09_graphics.R` (includes one trajectory graphic maximum — small
      multiples, adjusted trends, expansion teams highlighted; no rolling-window
      machinery, no month-by-month split tables)
- [ ] Draft `output/findings.md`, including framework evaluation criteria
      (AMENDMENT_01 §2c: face validity, split-half stability, sensitivity check,
      garbage-time disposition)
- [ ] **Run `coach-agent` on case-study sections (GSV, TOR, PDX) once fit reads are
      drafted — triage feedback, log below**
- [ ] **Run `analytics-reviewer` on the full findings draft — triage feedback, log
      below**

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

## Known issues to verify in session 2 (before trusting related outputs)

1. **shotdetail may be missing Toronto Tempo entirely.** A prior exploratory pull
   against commit `773ce29` (before this repo's setup pass, not yet re-verified in
   this repo's history) found `wnba_shotdetail_2026.csv` had 0 rows for Toronto — 14
   of 15 teams. **Per AMENDMENT_01 §2a, this is resolved in `analysis/eda_midseason.Rmd`
   as a required coverage check — not left as a passing flag.** If confirmed, the
   `R/07_expected_points.R` shot geometry for Toronto must come from `cdn` (`x`/`y` +
   `area`/`areaDetail`), not `shotdetail`.
2. **Commit hash resolution.** `773ce29` is a short hash; confirm it resolves
   unambiguously on the live repo when `R/01_download.R` runs (a prior check, not
   re-verified in this repo's history, found it resolves to
   `773ce292bb2cd9bc6ec98d70de95176607ccbaeb`, "add wnba 2026 data (ID 1 to 182)").
3. **§4 baseline table provenance.** The exact filter used for "paint share (of FGM)"
   (e.g. Restricted Area + In The Paint Non-RA, backcourt heaves excluded) is not
   stated in the handoff — `R/04_reconcile.R` should determine empirically which
   definition reproduces the table, and record it.

## Cut list (explicitly out of scope this cycle)

League style map PCA/clustering, lineup/on-off anything, defensive mirrors, trained
xPTS model, possession-value model, Synergy-PBP joins. Post-deadline (September+,
separate decision): trained shot-quality model; possession-value framework timed for
the November hiring window.

Amendment adds no new cuts to this list; it hardens process around the existing scope
(trajectory is a required deadline-read column, not scope creep — see AMENDMENT_01 §1
rationale).

## Next session should

Implement `R/01_download.R` through `R/04_reconcile.R` per the plan above, get the
`tests/testthat/` suite green, and stop to present the reconciliation report — per
CLAUDE.md, do not proceed past that gate. After the gate, the next stop is the new EDA
notebook (`analysis/eda_midseason.Rmd`) before any feature/model script is written.
