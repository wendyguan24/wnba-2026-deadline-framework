# CLAUDE.md — WNBA Trade Deadline Framework

You are working in the `wnba-deadline-framework` repo. The single source of truth for
this project is `HANDOFF_wnba_deadline_framework.md` in the repo root, as amended by
`AMENDMENT_01_trajectory_workflow_agents.md` (trajectory layer / §5c-bis, EDA gate,
three review agents in `.claude/agents/`). Read both fully before doing anything —
where the amendment conflicts with the handoff, the amendment wins; where either
conflicts with an instruction here, flag the conflict rather than silently picking one.

**Live status and next steps live in `PLAN.md`, not here.** Check it first — it has
the checked-off history, the current gate, and the "Next session should" line. The
phase/roadmap text below is the *process*, not the current state.

## Setup phase (session 1 + 1b — complete, kept here as a record)

Session 1 (2026-07-18): scaffolded the repo per handoff §7 — directory structure,
`.gitignore`, `README.md`, skeleton R scripts `01`-`09` (header/inputs/outputs/
roxygen stubs/`stop()` guard each), named empty-bodied `tests/testthat/` files,
`analysis/case_study_template.Rmd` (Synergy quarantine stub), `PLAN.md`, first commit.
No data downloaded, no logic implemented, no Python.

Session 1b (2026-07-18, amendment intake): read `AMENDMENT_01_...md`, updated
`PLAN.md` to the amended session flow, added the trajectory-layer spec (§5c-bis) to
the `R/06_models.R` skeleton, added the `analysis/eda_midseason.Rmd` stub, installed
the three review agents to `.claude/agents/`. Still no data downloaded.

## Standing rules for all future sessions

- **Deadline physics:** publish window is July 26-27. When in doubt between thorough and shipped, choose shipped and document the shortcut in the methodology notes.
- **Reproducibility boundary:** every quantitative claim in `output/findings.md` must reproduce from open data via the numbered scripts. Synergy-derived numbers live only in `analysis/` case-study prose with "Source: Synergy Sports | 2026 WNBA" attribution and never enter models, `data/`, or `output/` tables.
- **No Synergy-PBP possession-level joins. Ever.** (Documented failure mode; see handoff §3.)
- **No isolation trends from open data.** The open PBP has no play-type tags, so iso trajectory cannot be claimed from it. If used at all, it comes only from Synergy date-filtered team exports, in case-study prose, quarantined like all Synergy numbers. (AMENDMENT_01 §1.)
- **Validation before features:** scripts 05+ do not get written until (1) the tests in 04 pass against the baseline table in handoff §4, and (2) `analysis/eda_midseason.Rmd` + `output/eda_notes.md` (hypotheses registry: H1, H2, H3, H-null) exist — AMENDMENT_01 §2a-2b, the EDA gate. EDA that changes the plan is the point of EDA; a finding there can force a spec change, note it in PLAN.md rather than absorbing it silently downstream.
- **Hypotheses discipline:** findings are written against the registry in `output/eda_notes.md`. Do not invent hypotheses after seeing results; a published null is a finding, not a failure.
- **Trajectory is a required deadline-read column**, not an optional extra (AMENDMENT_01 §1) — if the July 21-22 modeling block is threatened, cut the optional 5th trajectory metric first, then H1's efficiency side, never the `trajectory` column itself (fall back to raw trends with a stated caveat before dropping it).
- **Review-agent gates are mandatory, not optional polish.** Run `analytics-reviewer` after script 06 and again on the full findings draft; `gm-agent` on the deadline-read table before any prose is written around it; `coach-agent` on drafted case-study sections. Give agents artifacts (tables, drafts, model summaries), not descriptions. Triage feedback (accept / reject with a one-line reason / defer post-deadline) and log the triage in PLAN.md — feedback is triaged, not obeyed, and the deadline outranks any single piece of feedback.
- **Vocabulary discipline:** descriptor-derived features are "shot-creation profiles," never "play types." The expected-points layer is a "stratified expected-points baseline," never a "shot-quality model."
- **Language hygiene in all written output:** no em dashes, no en dashes, no smart quotes; avoid "leverage," "robust," "spearheaded," "seamless." Concise, specific, grounded.
- **Scope control:** if a task isn't traceable to the two questions in handoff §1 (what do we need / who fits), or appears on the cut list in §6, do not build it. Note it in PLAN.md under "post-deadline" instead. The amendment hardens process; it does not add scope.
- **Data refresh:** on or after July 23, check `shufinskiy/nba_data` for a commit newer than `773ce29`. If found, re-pin, re-run 01-04, and confirm tests still pass before proceeding. If counts shift, update the baseline expectations deliberately and note it.
- End every session by updating PLAN.md checkboxes and stating what the next session should do.

## Session roadmap (for orientation; PLAN.md has the live, checkable detail)

Per AMENDMENT_01 Part 2, supersedes the original 6-step roadmap:

1. **Setup** (done) — scaffold, then amendment intake.
2. Implement 01-04; run download deliberately; get reconciliation tests green; show reconciliation report before proceeding.
3. **EDA notebook + hypotheses registry** (new gate) — `analysis/eda_midseason.Rmd` → `output/eda_notes.md`.
4. Implement 05-06, including the trajectory extension; present BLUP/ICC results and raw-vs-adjusted rank deltas; run `analytics-reviewer`.
5. Implement 07-08; present the deadline-read table (the core deliverable); run `gm-agent`.
6. Graphics + findings.md draft; run `coach-agent` on case studies and `analytics-reviewer` on the full draft.
7. Case-study integration (fit reads), final review, publish prep.
