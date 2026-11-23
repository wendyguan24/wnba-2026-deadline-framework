# CLAUDE.md — WNBA 2026 Analysis (offseason phase)

This repo began as the WNBA 2026 Trade Deadline Framework (published, tagged
`v1-deadline`). It is now the home for the **2026 offseason analysis**, built on the
full 2026 season (regular season + playoffs) from `shufinskiy/nba_data`, with wehoop as
a possible second source. The repo has not been renamed yet; see PLAN.md.

**Live status and next steps live in `PLAN.md`, not here.** Check it first. This file is
the standing rules and orientation only.

## What carries over from v1 and what does not

- **Archived, read-only record of v1:** `docs/archive/PLAN_v1_deadline.md`,
  `docs/archive/CLAUDE_v1_deadline.md`, plus `HANDOFF_wnba_deadline_framework.md`,
  `AMENDMENT_01_...md`, `AMENDMENT_02_...md` in the root. Consult them for why v1 code is
  the way it is. They no longer govern scope, schedule or deliverables.
- **Reusable pipeline:** `R/01` to `R/04` (download, parse, possessions, reconcile) and
  their tests; `R/05` to `R/07` (features, models, stratified expected-points baseline);
  `R/13` player value; `R/14` fit reads. Reuse and extend them; do not fork copies.
- **Deadline-specific, leave alone unless the offseason question needs it:** `R/08`
  deadline read, `R/12` standing/window tiers, `data/reference/cap_context_2026.csv`,
  the acquire/adjust/hold lever, the July 26-27 publish window.
- **Output files in `output/` are v1 artifacts** (half-season, 182 games). Do not
  overwrite them. New offseason outputs go in `output/offseason/`.

## Standing rules

- **Scope is set in PLAN.md.** The offseason question(s) are written there before any
  new feature work. If a task is not traceable to a stated offseason question, note it in
  PLAN.md under "parked" instead of building it. No fixed deadline now, but keep each
  phase small and shippable; document shortcuts in the methodology notes.
- **Reproducibility boundary:** every quantitative claim in a published offseason
  write-up must reproduce from open data via the numbered scripts. Synergy-derived
  numbers live only in `analysis/` case-study prose with "Source: Synergy Sports | 2026
  WNBA" attribution and never enter models, `data/`, or `output/` tables.
- **No Synergy-PBP possession-level joins. Ever.** (Documented failure mode; handoff §3.)
- **No isolation trends from open data.** The open PBP has no play-type tags.
- **Data pin discipline:** the pinned `shufinskiy/nba_data` commit is recorded in
  `R/01_download.R`, `README.md` and PLAN.md. v1 pin: `773ce29` (182 games, through
  2026-07-16). Offseason target: `46488f0` (2026-11-06, regular season plus playoffs).
  Re-pinning changes the baseline counts in `tests/testthat/test-baseline-table.R`;
  update them deliberately, with the new counts and the reconciliation result in PLAN.md,
  and do not let tests silently pass on stale numbers. Check the upstream `loading/utils.R`
  change in `46488f0` before reusing `01_download.R` loaders.
- **Regular season and playoffs are separate populations.** Never pool them in a model or
  baseline without an explicit flag and a stated reason; playoff samples are small and
  selected.
- **Validation before features:** any new data layer (full season, playoffs, wehoop) must
  pass reconciliation against box scores (possession points sum to final score per
  team-game) before new feature or model code is written on top of it.
- **Hypotheses discipline:** state hypotheses in PLAN.md before looking at results.
  Do not invent them after seeing results; a published null is a finding, not a failure.
- **Cap and contract figures are tiers, not dollars,** unless a primary source and an
  as-of date are attached (see `data/reference/README.md`). Offseason cap data goes stale
  fastest around free agency; date-stamp everything.
- **Review-agent gates stay mandatory:** `analytics-reviewer` after modeling results and
  on any full write-up draft; `gm-agent` on any decision table or recommendation;
  `coach-agent` on drafted case-study or fit sections. Give agents artifacts, not
  descriptions. Triage feedback (accept / reject with one-line reason / defer) and log it
  in PLAN.md. Feedback is triaged, not obeyed.
- **Vocabulary discipline:** descriptor-derived features are "shot-creation profiles,"
  never "play types." The expected-points layer is a "stratified expected-points
  baseline," never a "shot-quality model."
- **Language hygiene in all written output:** no em dashes, no en dashes, no smart
  quotes; avoid "leverage," "robust," "spearheaded," "seamless." Concise, specific,
  grounded.
- **Branching:** develop on the session branch; tag milestones (`v1-deadline` exists).
  Do not push to `main` or open a PR unless the user asks.
- End every session by updating PLAN.md checkboxes and stating what the next session
  should do.
