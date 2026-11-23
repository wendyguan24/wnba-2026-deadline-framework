# PLAN: WNBA 2026 Offseason Analysis

Successor to the deadline framework. The v1 plan, with its full review-gate triage log,
is archived at `docs/archive/PLAN_v1_deadline.md`. v1 is tagged `v1-deadline`
(pinned `shufinskiy/nba_data` `773ce29`, 182 games, May 8 to July 16, 2026).

Last updated: 2026-11-23.

## Status

- [x] v1 tagged `v1-deadline`; old PLAN.md and CLAUDE.md archived to `docs/archive/`
- [x] CLAUDE.md and PLAN.md rewritten for the offseason phase
- [ ] Offseason question(s) written down (see "Scope", currently OPEN)
- [x] v1 publish blockers complete (Synergy case studies + §3d structural paragraph, coach-agent gate, cap/CBA verification checklist), confirmed by Wendy 2026-11-23.
- [ ] Re-pin to full-season data and clear the reconciliation gate (Phase 1)

## Scope (OPEN, must be settled before Phase 2)

Decision 2026-11-23: build the data pipeline first, settle the question later.

The offseason question is not yet written down. Candidates, to be chosen or replaced by
Wendy. Pick before building anything new:

1. **Full-season re-read of v1.** Do the half-season identity, generation, making and
   trajectory reads hold over the full season and playoffs? Which deadline reads were
   right? (Cheapest; mostly re-running `R/05` to `R/07` and `R/11`/`R/13` on the new pin.)
2. **Roster and fit for 2027.** Fit-first target reads (`R/14`) rebuilt on full-season
   player value, conditioned on offseason cap and contract status (free agency,
   expirings). Needs fresh, dated cap data.
3. **Multi-season / aging and development.** Uses wehoop and historical `shufinskiy`
   seasons (`cdnnba` from 2022, `nbastats` from 1997). Separate data layer, so
   reconciliation applies per source.

Hypotheses for the chosen question go here before results are viewed:

- H-offseason-1: _TBD_
- H-null: report what the data does not support.

## Phase 1: Re-pin and reconcile (first work, independent of the scope choice)

- [ ] Read upstream `loading/utils.R` change in commit `46488f0` and confirm
      `R/01_download.R` loaders still work (or adapt, noting the change)
- [ ] Pin `shufinskiy/nba_data` to `46488f0`; download full 2026 regular season and
      playoff files (`cdnnba`, `nbastats` v2, `nbastatsv3`, `shotdetail`, `_po_2026`)
- [ ] Report counts: games, rows per source, date range, games per team, regular season
      vs playoffs separately
- [ ] Update baseline expectations in `tests/testthat/test-baseline-table.R` deliberately
      (v1 values: 89,735 / 23,163 / 74,224 rows, 182 games) and record the new numbers here
- [ ] Re-run `R/01` to `R/04`; possession points must equal final score in every
      team-game; confirm the technical-FT fix still holds on the new games
- [ ] Toronto has no shotdetail rows (v1 finding); `is_home` comes from shotdetail HTM/VTM. Confirm home/away comes from cdn or the games table instead, and check Toronto playoff games if any.
- [ ] Write `output/offseason/reconciliation_report.md` and show it before proceeding

## Phase 2: Features and models on the full season (after Phase 1 and scope)

- [ ] Decide which of `R/05` to `R/07`, `R/11`, `R/13`, `R/14` the chosen question needs
- [ ] Keep regular season and playoffs separate populations (CLAUDE.md rule)
- [ ] Revisit v1 choices that were half-season shortcuts: minutes floor in `R/13`,
      trajectory fallback (random-slope models hit singular fits at 23 to 26 games per
      team; the full season may support the real model), `MIN_CELL_N` in `R/07`
- [ ] Any new EDA that changes the plan is noted here, not absorbed silently
- [ ] `analytics-reviewer` on model results; log triage below

## Phase 3: Write-up

- [ ] Draft in `output/offseason/`; reproducibility check (every number from the scripts)
- [ ] `analytics-reviewer` on the full draft; `gm-agent` / `coach-agent` if it contains
      decision tables or fit/case-study sections
- [ ] Synergy material, if any, stays in `analysis/` prose with attribution

## Repo housekeeping

- [ ] Rename repo (GitHub redirects the old URL). Candidate name: `wnba-2026-analysis`.
      Do after scope is settled. Update `README.md` title and problem statement then; the
      README still describes the deadline framework.
- [ ] Move deadline-only reference material (cap CSVs, amendments) under
      `docs/archive/` or keep in place with a note, decide at rename time
- [ ] Push tag v1-deadline (proxy refused it from the cloud session; run `git push origin v1-deadline` locally or tag 4b78e2e in the GitHub UI)
- [ ] Update .claude/agents/*.md for offseason scope (after scope set)
- [ ] Data refresh: before final write-up, check `shufinskiy/nba_data` for commits newer
      than the pin

## Parked (not in scope until a question needs it)

Carried from v1's post-deadline list, none prioritized:

- Defense and lineup-flexibility layer (mentor roadmap, v1 PLAN "Mentor-informed v2")
- Fit-vs-cost target scoring and trade-outcome model (need to-the-dollar cap data and an
  asset-valuation model; v1 kept both out)
- Deferred R/13 and R/14 items: full per-(game,period,team) minutes invariant test,
  creation-class fit bucket, garbage-time bench sensitivity, sorting `player_value.csv`
  by team, capped-min cap-mechanic citation

## Review triage log

(Empty for the offseason phase. v1 triage history is in the archived plan.)

## Next session should

1. Ask Wendy to pick the offseason scope (1, 2, 3 or other) and write hypotheses.
2. Start Phase 1: check the `46488f0` loader change, then re-pin and report full-season
   counts. Install R packages first if the setup script failed (network host now allowed
   for new sessions; this one may need `install.packages` by hand).
