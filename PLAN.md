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
- [x] Re-pin to full-season data and clear the reconciliation gate (Phase 1; two open test items below)

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

- [x] Upstream `loading/utils.R` change in `46488f0`: not used. `R/01_download.R` fetches
      tarballs directly from raw.githubusercontent.com; dataset names
      `wnba_{cdnnba,nbastats,shotdetail}[_po]_2026` confirmed at the pin.
- [x] Pin `shufinskiy/nba_data` to `46488f0` (full SHA in `R/00_config.R`); regular season and
      playoff files downloaded for cdnnba, nbastats v2, shotdetail (nbastatsv3 excluded as in v1)
- [x] Counts (also in `data/reference/pipeline_baseline.csv`):

      | | v1 (773ce29) | regular (46488f0) | playoffs (46488f0) |
      |---|---|---|---|
      | games | 182 | 330 | 23 |
      | cdn rows | 89,735 | 161,135 | 10,776 |
      | v2 rows | 74,224 | 133,244 | 9,052 |
      | shotdetail rows | 23,163 | 42,297 | 3,067 |
      | team-games | 364 | 660 | 46 |
      | dates | 2026-05-08 to 07-16 | 2026-05-08 to 09-24 | 2026-09-27 to 10-31 |

      Regular season: 44 games per team. Playoffs: ATL 12, GSV 13, LVA 6, NYL 5, DAL 3, IND 3,
      MIN 2, WAS 2 (Toronto, Connecticut, Seattle, Phoenix, Chicago, Portland, Los Angeles did not play).
- [x] Baseline expectations: `test-baseline-table.R` now runs on the v1 subset (regular-season
      gameIds 1 to 182; game 182 is 2026-07-16, game 183 is 2026-07-20) and reproduces the
      handoff 8-team table with 0 delta. Full-season expectations live in `pipeline_baseline.csv`.
- [x] Re-run `R/01` to `R/04`: possession points equal final score in all 660 regular and
      all 46 playoff team-games. First run had one playoff mismatch (game 1042600112, DAL vs GSV,
      +-2): flagrant FTs listed under the shooter while cdn `possession` stays with the other team.
      Fix (approved by planner): `R/03` treats a made flagrant FT as out-of-band, like a technical FT,
      only when the shooter's team differs from the possession holder. v1-subset possession rows are
      byte-identical before and after; only game 1042600112 changed. Unit test added.
- [x] cdn vs v2: regular season sum |FGA| 3, |FGM| 2, |AST| 5, |FG3A| 1 (games 1022600004,
      1022600022, 1022600065, 1022600199, 1022600210); playoffs all 0. Stored as known source
      disagreement in `pipeline_baseline.csv` and tested for equality.
- [x] Toronto has no shotdetail rows in the regular season (confirmed); home/away now comes from cdn
      scoring events and matches shotdetail HTM/VTM in 330 of 330 regular and 23 of 23 playoff games.
      Toronto played no playoff games.
- [x] `output/offseason/reconciliation_report.md` written
- [x] Analysis-ready tables (`R/04b`, `R/load_tables.R`, `docs/data_dictionary.md`,
      `output/offseason/tables_report.md`)
- [ ] OPEN: `test-analysis-tables.R` minutes invariant fails for 10 of 706 team-games (the R/13
      starter inference misses a team-period; deviations of 5 or 10 minutes; list in tables_report).
      Decide: fix the reconstruction, accept a stated tolerance, or exclude those team-games.
- [ ] OPEN: `test-player-value.R` (v1 test) reads the v1 `data/processed/pbp_events.rds`, which
      does not exist in a fresh checkout; it fails here independent of this work.

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
2. Resolve the two OPEN items in Phase 1 (minutes invariant, v1 player-value test).
3. Wire the `R/05` to `R/07`, `R/11`, `R/13`, `R/14` scripts the chosen scope needs to
   `R/00_config.R` (they still hard-code v1 paths), and start questions from `load_table()`.
