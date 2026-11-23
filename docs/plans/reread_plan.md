# Execution plan: full-season re-read of v1 (forecast test)

Repo: /home/user/wnba-2026-deadline-framework, branch `claude/exciting-knuth-djz7m1`.
Read CLAUDE.md, the PLAN.md "Scope" section (pre-registered hypotheses H-R1 to H-R4, H1-H3,
committed in b0c3c80), docs/data_dictionary.md, R/00_config.R, R/load_tables.R.

## Rules
- Do NOT change v1 modeling logic or defaults (ICC >= 0.15 anchor rule, garbage-time flag,
  pace_per40, is_home fixed effect, transition weighting, ntile(…, 3) tiers, trajectory
  fallback). Only wiring (paths, input filtering) changes in R/05-R/07.
- Do NOT add hypotheses, tests of new questions, or extra metrics. Report results against the
  registry only. A null is reported as a null.
- Never write to files directly in `output/` or `data/processed/` root (v1). New outputs:
  `output/offseason/reread/`; intermediates: `data/processed/full2026/windows/<window>/`.
- Regular season and playoffs never pooled. Regular-season windows only for all hypotheses;
  playoffs descriptive.
- If the first-half regression check (step 4) fails beyond the stated tolerance, STOP and report.
- No em dashes, en dashes, smart quotes; avoid "leverage", "robust", "spearheaded", "seamless".
- Commit per block with trailer:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01LqKYRNijtLZHhieuyMkmRN
  ```
  Push to `claude/exciting-knuth-djz7m1` only (retry 4x with backoff). No PR.

## Block A: wiring R/05, R/07, R/06 to config with analysis windows
1. In `R/00_config.R` add:
   - `WINDOWS <- c("first_half", "second_half", "full", "playoffs")`
   - `ANALYSIS_WINDOW <- Sys.getenv("WNBA_WINDOW", "full")` (stop if not in WINDOWS)
   - `V1_LAST_GAME_ID <- 1022600182`
   - `window_game_ids(games_tbl, window)`: first_half = regular-season game_id <= V1_LAST_GAME_ID;
     second_half = regular-season game_id > V1_LAST_GAME_ID; full = all regular-season;
     playoffs = all playoff games.
   - `WINDOW_PROCESSED_DIR <- file.path(PROCESSED_DIR, "windows", ANALYSIS_WINDOW)` and
     `WINDOW_OUTPUT_DIR <- file.path(OUTPUT_DIR, "reread", ANALYSIS_WINDOW)`.
2. R/05_features.R, R/07_expected_points.R, R/06_models.R (run order 05, 07, 06):
   - source R/00_config.R; read pbp_events.rds / possessions.rds from PROCESSED_DIR, then filter
     to `window_game_ids()` for ANALYSIS_WINDOW before any computation.
   - R/05: replace the shotdetail HTM/VTM home/away join with `is_home` from the `games` table
     (load_table("games")); shotdetail lacks Toronto. Same semantics.
   - All saveRDS/write_csv paths -> WINDOW_PROCESSED_DIR / WINDOW_OUTPUT_DIR (create dirs).
     Inter-script reads (06 reading 07's outputs, etc.) use WINDOW_PROCESSED_DIR.
   - Each window computes its own stratified expected-points baseline, as v1 did (stated choice,
     document it in the results).
   - Playoffs window: R/06's mixed models may fail or be degenerate on 23 games; if so, skip R/06
     for playoffs (R/05 + R/07 only) and note it. Do not tune models to make them fit.
3. Run all four windows: for w in first_half second_half full playoffs:
   `WNBA_WINDOW=$w Rscript R/05_features.R && WNBA_WINDOW=$w Rscript R/07_expected_points.R && WNBA_WINDOW=$w Rscript R/06_models.R`
4. **Regression check (first_half vs v1):** compare first_half outputs to the committed v1 files
   in `output/`: `icc_table.csv`, `team_generation_making.csv`, `team_trajectories.csv`,
   `trajectory_league_trends.csv`, `team_rank_deltas.csv`. Expected: identical up to 1e-6 (the v1
   cdn data for games 1-182 is byte-identical; possessions unchanged for those games). Report
   max abs diff per file. Any difference beyond 1e-6: STOP and report which columns/teams.
   Write the comparison to `output/offseason/reread/regression_check_v1.md`.
   Commit block A.

## Block B: trade flags
5. In new `R/15_reread.R` (or a helper it sources), derive trade-affected teams from
   `player_games` (regular season): a player is "moved" if they appear for 2+ teams in the
   season; date of first game for the new team. A team is `trade_flag = TRUE` if moved players'
   minutes account for >= 10% of that team's first-half minutes (players who left) or >= 10% of
   its second-half minutes (players who arrived). Write `output/offseason/reread/trade_flags.csv`
   (team, minutes share out, minutes share in, players moved, flag). Report which moves happened
   around the Aug 2 deadline vs other dates.

## Block C: hypothesis tests (`R/15_reread.R`), regular season only
Inputs: window outputs from Block A; v1 `output/deadline_read.csv` for the v1 reads. Every test
is run on all 15 teams AND on the subset without trade_flag teams; report both.
6. **H-R1:** anchor metrics = those with ICC >= 0.15 in the v1 `output/icc_table.csv`. For each,
   team-level BLUP (or team mean if BLUPs absent) first_half vs second_half: Spearman rho with a
   bootstrap 95% CI over teams (2,000 resamples, set.seed(20261123)). Verdict per pre-registered
   rule: supported if rho >= 0.7 for most (more than half) anchor metrics.
7. **H-R2:** Spearman(first-half generation per100, second-half generation per100) vs
   Spearman(first-half making per100, second-half making per100), with bootstrap CI of the
   difference (same seed). Verdict: supported if generation rho > making rho and the CI of the
   difference excludes 0; "directionally consistent" if greater but CI spans 0. Also LVA: making
   per100 and making percentile, first vs second half (prediction: falls).
8. **H-R3:** per team: first-half win pct and point differential per game (from team_games),
   first-half generation and making per100; second-half point differential per game as outcome
   (also win pct as secondary). Compare leave-one-out RMSE: model A `y ~ first_half_win_pct`,
   model B `y ~ first_half_win_pct + generation + making`. Also report model A' with
   first-half point differential instead of win pct (a stricter baseline). Verdict: supported if
   B beats A on LOO RMSE; state n = 15 and that this is low power. Report coefficients with SEs.
9. **H-R4:** v1 trajectory label per team = `trajectory` in v1 `output/deadline_read.csv`
   (it is the shot_making_residual trajectory). Outcome direction = sign(second-half making per100
   minus first-half making per100). Agreement rate, exact binomial test vs 0.5. Also the same
   restricted to labels whose interval did not span zero (`interval_spans_zero == FALSE`).
10. **H1, H2 full season:** from the `full` window's `trajectory_league_trends.csv` and
    `team_trajectories.csv`: league trend estimates and p-values for transition share,
    transition pts per poss (H1), assisted rate and live-ball TOV rate (H2); TOR and PDX
    team slopes for the H2 metrics with intervals; whether the random-slope model still hits the
    singular fallback with 44 games per team. Compare to v1 values.
11. **H3:** GSV making per100 and making percentile: first half, second half, full; GSV
    shot_making_residual trajectory on the full season. Playoffs: GSV generation/making from the
    playoffs window, descriptive.
12. **v1 read scorecard** (`output/offseason/reread/scorecard.csv` + `.md`): per team: v1
    generation_tier, making_tier, trajectory, lever, recommendation (from v1 deadline_read.csv);
    second-half generation and making percentiles and tiers (ntile(x, 3) over 15 teams, same as
    v1); trade_flag; verdict: `held` if both tiers unchanged, `partly held` if exactly one tier
    changed by one step, `failed` otherwise; trajectory outcome (agree/disagree) as a separate
    column. Also second-half record and final standing.
13. **Playoffs descriptive table:** per playoff team: regular-season full-window generation and
    making per100 vs playoffs window, games played, series result. No tests.

## Block D: write-up of results (numbers only, no narrative claims beyond the registry)
14. `output/offseason/reread/reread_results.md`: one section per hypothesis with the pre-registered
    statement, the numbers (all teams and no-trade subset), the verdict (supported / not supported
    / directionally consistent / null), and caveats (n = 15, own-window baselines, trade flags,
    Game 7 ESPN gap irrelevant here). Then the scorecard summary (counts held/partly/failed) and
    the playoff table. No recommendations, no prose beyond what the numbers support.
15. Add `tests/testthat/test-reread.R` (skip if window outputs absent): first_half regression
    matches v1 within 1e-6; scorecard has 15 rows with valid verdicts; windows partition the
    regular season (first_half + second_half game counts = full = 330).
16. Run full test suite (0 failures; v1 player-value skip expected). Update PLAN.md (check off
    Phase 2 items, link results, "Next session should": run analytics-reviewer on
    reread_results.md and gm-agent on scorecard.md, triage, then write-up). Update README run
    order. Commit, push, clean tree.

## Report back (concise)
- Regression check result. Trade-flagged teams.
- Each hypothesis: key numbers and verdict (all teams / no-trade subset).
- Scorecard counts and notable teams. Any STOP conditions or skipped steps. Commit hashes.
