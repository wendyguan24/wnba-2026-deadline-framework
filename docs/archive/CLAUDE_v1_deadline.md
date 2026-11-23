# CLAUDE.md — WNBA Trade Deadline Framework

You are working in the `wnba-2026-deadline-framework` repo. The single source of truth for
this project is `HANDOFF_wnba_deadline_framework.md` in the repo root, as amended by
`AMENDMENT_01_trajectory_workflow_agents.md` (trajectory layer / §5c-bis, EDA gate,
three review agents in `.claude/agents/`) and
`AMENDMENT_02_contracts_cba_cap.md` (cap-context layer, contract typology,
feasibility-conditioned lever calls — wins over the handoff and AMENDMENT_01, but
*only* on contract/cap matters; everything else stands as amended by AMENDMENT_01).
Read all three fully before doing anything — where an amendment conflicts with the
handoff, the amendment wins (within its own stated scope); where either amendment or
this file conflicts with something else, flag the conflict rather than silently
picking one.

**Live status and next steps live in `PLAN.md`, not here.** Check it first — it has
the checked-off history, the current gate, and the "Next session should" line. The
phase/roadmap text below is the *process*, not the current state.

## Setup phase (session 1 + 1b — complete, kept here as a record)

Session 1 (2026-07-18): scaffolded the repo per handoff §7 — directory structure,
`.gitignore`, `README.md`, skeleton R scripts `01`-`09` (header/inputs/outputs/
roxygen stubs/`stop()` guard each), named empty-bodied `tests/testthat/` files,
`analysis/case_study_template.Rmd` (Synergy quarantine stub), `PLAN.md`, first commit.
No data downloaded, no logic implemented, no Python.

Session 1b (2026-07-18, AMENDMENT_01 intake): read `AMENDMENT_01_...md`, updated
`PLAN.md` to the amended session flow, added the trajectory-layer spec (§5c-bis) to
the `R/06_models.R` skeleton, added the `analysis/eda_midseason.Rmd` stub, installed
the three review agents to `.claude/agents/`. Still no data downloaded.

Session 2b (2026-07-18, AMENDMENT_02 intake): read `AMENDMENT_02_...md`, folded the
cap-context layer into `PLAN.md` (Jul 23 cap-context CSV gathering, Jul 24-25 contract
typology, Jul 25-26 structural paragraph + 4-item pre-publish verification checklist,
updated cut order), added the `cap_context` column and feasibility-conditioned lever
rule to the `R/08_deadline_read.R` skeleton, created `data/reference/` (tracked, not
gitignored — attributed reference data, not raw data) with a
`cap_context_2026.csv` header-only template and a `README.md` stating the
hand-curation/attribution and tiers-not-dollars rules, and appended the amendment's
cap-conditioning checks to `.claude/agents/gm-agent.md` and `analytics-reviewer.md`.
Still no data downloaded, no script logic implemented beyond skeleton documentation.

## Standing rules for all future sessions

- **Deadline physics:** publish window is July 26-27. When in doubt between thorough and shipped, choose shipped and document the shortcut in the methodology notes.
- **Reproducibility boundary:** every quantitative claim in `output/findings.md` must reproduce from open data via the numbered scripts. Synergy-derived numbers live only in `analysis/` case-study prose with "Source: Synergy Sports | 2026 WNBA" attribution and never enter models, `data/`, or `output/` tables.
- **No Synergy-PBP possession-level joins. Ever.** (Documented failure mode; see handoff §3.)
- **No isolation trends from open data.** The open PBP has no play-type tags, so iso trajectory cannot be claimed from it. If used at all, it comes only from Synergy date-filtered team exports, in case-study prose, quarantined like all Synergy numbers. (AMENDMENT_01 §1.)
- **Validation before features:** scripts 05+ do not get written until (1) the tests in 04 pass against the baseline table in handoff §4, and (2) `analysis/eda_midseason.Rmd` + `output/eda_notes.md` (hypotheses registry: H1, H2, H3, H-null) exist — AMENDMENT_01 §2a-2b, the EDA gate. EDA that changes the plan is the point of EDA; a finding there can force a spec change, note it in PLAN.md rather than absorbing it silently downstream.
- **Hypotheses discipline:** findings are written against the registry in `output/eda_notes.md`. Do not invent hypotheses after seeing results; a published null is a finding, not a failure.
- **Trajectory is a required deadline-read column**, not an optional extra (AMENDMENT_01 §1) — if the July 21-22 modeling block is threatened, cut the optional 5th trajectory metric first, then H1's efficiency side, never the `trajectory` column itself (fall back to raw trends with a stated caveat before dropping it).
- **Cap figures are tiers, not dollars.** `data/reference/cap_context_2026.csv`'s `flexibility_tier` (room/tight/capped) is what the framework publishes and defends; `committed_salary_est`/`cap_room_est` are approximate inputs used to derive it, never precise claims. Every cap/CBA figure needs a source and date — see `data/reference/README.md` and AMENDMENT_02 §3a.
- **Review-agent gates are mandatory, not optional polish.** Run `analytics-reviewer` after script 06 and again on the full findings draft; `gm-agent` on the deadline-read table before any prose is written around it; `coach-agent` on drafted case-study sections. Give agents artifacts (tables, drafts, model summaries), not descriptions. Triage feedback (accept / reject with a one-line reason / defer post-deadline) and log the triage in PLAN.md — feedback is triaged, not obeyed, and the deadline outranks any single piece of feedback.
- **Vocabulary discipline:** descriptor-derived features are "shot-creation profiles," never "play types." The expected-points layer is a "stratified expected-points baseline," never a "shot-quality model."
- **Language hygiene in all written output:** no em dashes, no en dashes, no smart quotes; avoid "leverage," "robust," "spearheaded," "seamless." Concise, specific, grounded.
- **Scope control:** if a task isn't traceable to the three questions in handoff §1 as extended by AMENDMENT_02 §1 (what do we need / who fits / can we do it), or appears on the cut list in §6, do not build it. Note it in PLAN.md under "post-deadline" instead. The amendments harden process; they do not add scope.
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
