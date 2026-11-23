# PLAN: WNBA 2026 Offseason Analysis

Successor to the deadline framework. The v1 plan, with its full review-gate triage log,
is archived at `docs/archive/PLAN_v1_deadline.md`. v1 is tagged `v1-deadline`
(pinned `shufinskiy/nba_data` `773ce29`, 182 games, May 8 to July 16, 2026).

Last updated: 2026-11-23 (full-season re-read of v1 executed; review-triage revision pass applied).

## Status

- [x] v1 tagged `v1-deadline`; old PLAN.md and CLAUDE.md archived to `docs/archive/`
- [x] CLAUDE.md and PLAN.md rewritten for the offseason phase
- [x] Offseason question written down: full-season re-read of v1 (see "Scope"; hypotheses pre-registered in b0c3c80)
- [x] v1 publish blockers complete (Synergy case studies + §3d structural paragraph, coach-agent gate, cap/CBA verification checklist), confirmed by Wendy 2026-11-23.
- [x] Re-pin to full-season data and clear the reconciliation gate (Phase 1; two open test items below)

## Scope (SET 2026-11-23: full-season re-read of v1, candidate 1)

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

**Chosen 2026-11-23 (Wendy): candidate 1, full-season re-read of v1.** Candidates 2 and 3
stay parked.

**Design: v1 as a forecast.** Regular-season games 1 to 182 (gameIds 1022600001 to
1022600182) are exactly the v1 sample ("first half"). Games 183 to 330 are out of sample
("second half"). Score each v1 read against the second half. Rosters changed at the
Aug 2 trade deadline: teams with material trades are flagged and analyzed with and without
them. Playoffs are descriptive only (23 games, selected sample); never pooled with the
regular season.

**Pre-registered hypotheses (recorded and committed before any full-season or second-half
model output was computed):**

- **H-R1 (identity stable):** the ICC >= 0.15 identity-anchor metrics rank teams similarly in
  the second half as in the first. Prediction: Spearman >= 0.7 for most anchor metrics.
- **H-R2 (generation holds, making regresses):** first-half shot generation predicts
  second-half generation better than first-half making predicts second-half making. Sharpest
  case: LVA (generation 7th pctile, making 100th, declining) sees making fall in the second
  half.
- **H-R3 (reads beyond the record):** first-half generation and making add information about
  second-half results (point differential per game, win pct) beyond first-half record. This
  is v1's core claim; a failure is the headline finding.
- **H-R4 (trajectory labels weak):** v1 improving/declining labels, most with intervals
  spanning zero, do not predict second-half direction better than chance. Expected null.
- **H1, H2, H3 re-run on the full season:** H1 (transition rises with reps) and H2
  (chemistry proxies improve, strongest for TOR and PDX) were published v1 nulls; do they
  hold with twice the sample? H3 (GSV's low FG% is making below expectation on an acceptable
  diet): GSV won the title, so report whether its making moved toward expectation.
- **H-null:** report what the data does not support. A null is a finding.

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
- [x] Minutes: starter inference in `build_minutes()` replaced (seed from first-sub-out and earlier-clock
      events, technical fouls ignored, fill from the previous period's end-of-period set when that gives
      exactly 5; then a backward fill from the next period's starting lineup for a period still short).
      Team-periods without 5 starters went from 45 to 0; team-games with unreconciled minutes from 10 to 0
      (all 706 reconcile). 10 player-games changed minutes vs the first build (max change 10 minutes; the
      last case, 1042600304 ATL period 1, is Hillmon, who has zero period-1 events and early period-2 events);
      box columns unchanged.
      The `minutes_reconciled` flag stays as a guard, counts in `pipeline_baseline.csv`.
      R/13 v1 outputs in `output/` are unchanged, but re-running R/13 would now use the improved minutes.
- [x] External validation against ESPN (wehoop), `R/04c_validate_external.R`, report
      `output/offseason/external_validation.md`, test `tests/testthat/test-external-validation.R`
      (ESPN files downloaded 2026-11-23; validator only, never merged). Results:
      games 352 of 353 matched on (date, home, away), 0 needing a date shift; the one unmatched game is Finals
      Game 7 (1042600307, 2026-10-31), which ESPN still lists as scheduled with no box score (so G7 and the
      title are checked only against our own reconciliation). All 15 ESPN franchise abbreviations mapped
      (`data/reference/espn_team_map.csv`); ESPN All-Star teams COOP and SPO are not franchises.
      None of our 330 regular-season games is a non-counting game (the ESPN All-Star game and Commissioner's
      Cup final are not in our table; the postponed July 16 DAL-NYL game was replayed July 20 and is ours).
      Team-games (704): pts, FGM, FG3M, FTM, FTA, BLK, PF exact in all; FGA 1, FG3A 1, OREB 2, DREB 1, AST 2,
      STL 1, TOV 2 mismatches (10 cells, 7 games). ESPN team rebounds exclude team-credited rebounds, so OREB
      and DREB are compared on player-credited sums. One cell is an ESPN-side error (game 1022600074 CON,
      ESPN team_turnovers is -5). Players: 7,009 of 7,009 matched (6,925 by name, 84 by an elimination plus id link for name changes: Coffey/Brodie,
      Gustafson/DiLeo, Hamzova/Joklova, Florez, and two repeated surnames); 40 count-stat cells in 13 games differ by at most 2, and where nbastats v2 can be recomputed
      (35 of 40 cells) it agrees with ESPN, not cdn (cdn credits a single event to the wrong player; ours
      reproduces cdn). All 50 mismatching cells are recorded in `data/reference/external_validation_exceptions.csv`
      with reasons and the test fails on any new or stale exception. Minutes: 7,009 of 7,009 within 0.51 of
      ESPN (whole-minute rounding); the 10 starter-fix player-games all agree with ESPN (old values 0 of 10).
      Standings: W-L for all 15 teams equals ESPN counting games. Playoffs: 23 games, 7 series (best of 3,
      5, 7), GSV beat ATL 4-3 in the Finals, no eliminated team plays again. Spot checks (OT game 1022600008,
      1042600112, 1022600312, 1022600237, 1042600304): only disagreements are the two cdn steal-attribution
      cells in 1042600112 (Williams 4/3, Burton 2/3, excepted).
      Consequence for later work: individual counting stats carry about 0.1 percent cdn attribution noise
      (14 games); not material for season-level reads, worth knowing for single-game claims.
- [x] `test-player-value.R` (v1 test) now skips when the v1 `data/processed/pbp_events.rds` is absent.
      Note: R/13 and the R/05+ scripts still use v1 paths and must be wired to `R/00_config.R`
      before re-running.

## Phase 2: Features and models on the full season (re-read of v1)

- [x] Scripts needed: `R/05`, `R/07`, `R/06` (wired to `R/00_config.R` with analysis windows `first_half`,
      `second_half`, `full`, `playoffs`); `R/11`, `R/13`, `R/14` not needed for this question (parked)
- [x] Regular season and playoffs kept separate; hypotheses use regular-season windows only
- [x] Regression check: `first_half` outputs equal the committed v1 `icc_table`, `team_generation_making`,
      `team_trajectories`, `trajectory_league_trends`, `team_rank_deltas` (max abs diff 0);
      `output/offseason/reread/regression_check_v1.md`, `R/15a_regression_check.R`
- [x] Trade flags (`trade_flags.csv`, `player_moves.csv`): LAS, PHX flagged
- [x] Hypothesis tests H-R1 to H-R4, H1, H2, H3, scorecard, playoffs table (`R/15_reread.R`,
      `R/15b_reread_report.R`); results in `output/offseason/reread/reread_results.md`, `scorecard.md`
- [x] `tests/testthat/test-reread.R`; full suite 0 failures (1 expected skip: v1 player-value test)
- [ ] Revisit v1 choices that were half-season shortcuts (R/13 minutes floor, `MIN_CELL_N`): not
      needed for the re-read; the trajectory random-slope model still falls back to random intercepts
      for 3 of 4 H1/H2 metrics at 44 games per team (see results)
- [x] `analytics-reviewer` on `reread_results.md`; `gm-agent` on `scorecard.md`; triage logged below and
      applied (revision pass, `docs/plans/reread_revision_plan.md`)
- [ ] `analytics-reviewer` re-run on the revised `reread_results.md` (see "Next session should")

Execution notes (2026-11-23):
- Design choices recorded: each window builds its own stratified expected-points baseline (as v1 did);
  `is_home` in R/05 now comes from the `games` table (shotdetail lacks Toronto), same values as v1;
  game_index is each team's chronological game number within the window.
- R/06 was not run for the `playoffs` window (8 teams, 2 to 13 games each, mixed models degenerate); R/05 and R/07 only.
- `lme4` came from the distribution package (`r-cran-lme4` 1.1-35.1); CRAN was unreachable.
- Trade-flag rule as written in the plan: moved = appears for 2+ teams; share out = first-half minutes of
  players whose stint with the team was followed by a stint elsewhere; share in = second-half minutes of
  players whose stint was preceded by a stint elsewhere; flag at >= 10 percent. PHX and LAS flags include
  moves well before and after the Aug 2 deadline (see `player_moves.csv`).

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

**Re-read review gates (2026-11-23), triage APPROVED by Wendy.** analytics-reviewer and gm-agent
run on `output/offseason/reread/`. Execution plan: `docs/plans/reread_revision_plan.md`.
- analytics-reviewer: B1 ACCEPT (decision rules were in the uncommitted execution plan, first
  committed at cd66cc0; reword, commit plans to docs/plans/, A' and scorecard exploratory);
  B2 ACCEPT (H-R3 mixed/inconclusive, no primary outcome); W1-W10 ACCEPT; N1-N5, N7 ACCEPT;
  N6 (bootstrap determinism test) DEFER.
- gm-agent: 1-2 ACCEPT as an EXPLORATORY "advice outcome" section, separate from registered
  verdicts; 3 ACCEPT refined by W1 (instability is volume, not diet); 4 ACCEPT for write-up
  framing (description, not forecast; headline the null); 5-7 ACCEPT; 8 one-line caveats only,
  cap-feasibility analysis PARKED.

Revision pass applied 2026-11-23 (all accepted items implemented; outputs under `output/offseason/reread/`):
- [x] B1 header reworded (hypotheses pre-registered in b0c3c80; decision rules in the execution plan, first
      committed at cd66cc0); "pre-registered rule" phrasing removed; A' and the scorecard labeled EXPLORATORY;
      `docs/plans/` committed as audit trail.
- [x] B2 H-R3: both outcomes equal; verdict "mixed / inconclusive" with RMSE change stated; per-team paired
      LOO squared-error differences (B minus A) with team-bootstrap CI (`hr3_paired_loo.csv`); making
      coefficient sign and regression-to-the-mean reading; fh_win_pct coefficient shift read with
      collinearity (`hr3_collinearity.csv`); A' relabeled "alternative baseline (point differential)".
- [x] W1 H-R2 decomposition (diet, volume, generation, making; `hr2_decomposition.csv`), EXPLORATORY.
- [x] W2 full-window baseline sensitivity (`sensitivity_full_baseline.csv`), EXPLORATORY.
- [x] W3 raw per100 (H-R2) vs schedule-adjusted BLUPs (H-R1) caveat. W4 see B2. W5 scorecard percentiles, change,
      `boundary_sensitive`, verdict range under one-rank swaps, chance rate 1/9, record-tertile benchmark
      (`scorecard_summary.csv`). W6 H-R1 leads with median rho and states the flip condition.
- [x] W7 H3 verdict line. W8 playoffs diff columns dropped, common-baseline caveat. W9 all report values
      computed. W10 fallback inference limits, mixed interval types (`interval_type` column), full-window
      overlap, second-half league-trend rows added.
- [x] N1 ties (|delta| < 0.01 per100) excluded from H-R4 (LVA). N2 label vs outcome line. N3 trade flag renamed
      roster-turnover flag (`trade_flags.csv` is now `roster_turnover_flags.csv`; population `no_turnover13`).
      N4 regenerate pointer to README run order. N5 `session_info.txt`. N7 "--" removed from copied v1 text.
      N6 (bootstrap determinism test) DEFERRED.
- [x] GM 1, 2, 7 EXPLORATORY advice outcome (`advice_outcome.csv`); GM 3 via W1; GM 4 framing carried to the
      write-up (below); GM 5, 6 via W5; GM 8 one-line caveats added, cap feasibility PARKED.
- Reinterpretations: (a) deadline action date window applied to observable first-game dates plus a spanning
  rule (gap contains Aug 2 and is at most 14 days), threshold 2 percent of second-half minutes; (b) one-rank
  swap range varies each team's four tier readings independently (conservative); (c) record-tertile benchmark
  breaks win pct ties with point differential per game.

## Next session should

1. Re-run analytics-reviewer on the revised `output/offseason/reread/reread_results.md` (tell it the deadline
   framing does not apply; give it the file, not a description), triage and log.
2. Then start the write-up (Phase 3). Framing per GM 4: description, not forecast; headline the nulls
   (H-R2 not supported, H-R3 mixed / inconclusive, H-R4 and H1/H2 nulls); keep EXPLORATORY sections labeled.
