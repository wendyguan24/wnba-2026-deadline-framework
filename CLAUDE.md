# CLAUDE.md — WNBA Trade Deadline Framework

You are working in the `wnba-deadline-framework` repo. The single source of truth for this project is `HANDOFF_wnba_deadline_framework.md` in the repo root. Read it fully before doing anything. If an instruction here ever conflicts with the handoff, the handoff wins; flag the conflict.

## Current phase: SETUP ONLY

Your first session sets up the project. **Do not execute any analysis, download any data, or run any scripts in this session.** Specifically:

Do:
1. Create the full directory structure from handoff §7, including `.gitignore` (ignore `data/raw/`, `data/processed/`, `.Rhistory`, `.RData`, Synergy anything).
2. Initialize git with a sensible first commit.
3. Write `README.md`: the problem statement verbatim from handoff §1, the two-layer data architecture summary, data provenance (pinned commit `773ce29`, URLs, planned download-date logging), and run instructions (to be completed as scripts land).
4. Create **skeleton** R scripts `01` through `09` — each containing: a header comment stating its purpose per handoff §5/§7, its inputs and outputs, `library()` calls, function stubs with roxygen-style comments, and a `stop("Not yet implemented — see HANDOFF §X")` guard so nothing runs accidentally.
5. Create the testthat scaffold with **named, empty-bodied test files** describing what each will assert: LAS/LVA tricode mapping test, baseline-table validation (handoff §4 table), cdn-vs-v2 per-game reconciliation, possession-count invariants (e.g., points in possession table == final scores), clock-parsing round-trip.
6. Create `analysis/` with a stub case-study notebook template noting the Synergy quarantine rule (numbers typed in as cited constants, never committed as data).
7. Write a short `PLAN.md`: the timeline table from handoff §6 as a checklist, with the setup items checked off.
8. Stop and present the tree + README for review.

Do not:
- Download the tar.xz files (that is session 2, script 01, run deliberately so the download date is logged).
- Implement parsing, features, or models.
- Touch anything Synergy-related beyond the notebook stub.
- Add Python; this is an R project (tidyverse, lme4, testthat, hms/lubridate).

## Standing rules for all future sessions

- **Deadline physics:** publish window is July 26-27. When in doubt between thorough and shipped, choose shipped and document the shortcut in the methodology notes.
- **Reproducibility boundary:** every quantitative claim in `output/findings.md` must reproduce from open data via the numbered scripts. Synergy-derived numbers live only in `analysis/` case-study prose with "Source: Synergy Sports | 2026 WNBA" attribution and never enter models, `data/`, or `output/` tables.
- **No Synergy-PBP possession-level joins. Ever.** (Documented failure mode; see handoff §3.)
- **Validation before features:** scripts 05+ do not get written until the tests in 04 pass against the baseline table in handoff §4.
- **Vocabulary discipline:** descriptor-derived features are "shot-creation profiles," never "play types." The expected-points layer is a "stratified expected-points baseline," never a "shot-quality model."
- **Language hygiene in all written output:** no em dashes, no en dashes, no smart quotes; avoid "leverage," "robust," "spearheaded," "seamless." Concise, specific, grounded.
- **Scope control:** if a task isn't traceable to the two questions in handoff §1 (what do we need / who fits), or appears on the cut list in §6, do not build it. Note it in PLAN.md under "post-deadline" instead.
- **Data refresh:** on or after July 23, check `shufinskiy/nba_data` for a commit newer than `773ce29`. If found, re-pin, re-run 01-04, and confirm tests still pass before proceeding. If counts shift, update the baseline expectations deliberately and note it.
- End every session by updating PLAN.md checkboxes and stating what the next session should do.

## Session roadmap (for orientation, one session ≈ one block)

1. **Setup** (this session) — scaffold only.
2. Implement 01-04; run download deliberately; get reconciliation tests green; show reconciliation report before proceeding.
3. Implement 05-06; present BLUP/ICC results and raw-vs-adjusted rank deltas.
4. Implement 07-08; present the deadline-read table (the core deliverable).
5. Graphics + findings.md draft.
6. Case-study integration (fit reads), final review, publish prep.
