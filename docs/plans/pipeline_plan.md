# Execution plan: offseason data pipeline (full 2026 season, regular + playoffs)

Repo: /home/user/wnba-2026-deadline-framework, branch `claude/exciting-knuth-djz7m1`.
Upstream clone for reference (read-only): /home/user/shufinskiy/nba_data (HEAD = 46488f0).

## Hard rules for the executor
- Follow steps in order. Do NOT redesign. If a step is impossible or a check fails
  (especially reconciliation), STOP and report what failed with game IDs / numbers.
  Do not patch possession or parsing logic to force a pass.
- Do not modify `output/` files (v1 artifacts). New outputs go to `output/offseason/`.
- Do not touch R/05-R/14 except the R/13 function extraction in step 6.
- Written text: no em dashes, en dashes, or smart quotes. Use "-" or "to".
- Commit at the end of each numbered block (A, B, C, D) with messages ending:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01LqKYRNijtLZHhieuyMkmRN
  ```
  Push only to `claude/exciting-knuth-djz7m1` (`git push -u origin claude/exciting-knuth-djz7m1`).

## Block A: environment
1. Install R packages for this session:
   `Rscript -e 'install.packages(c("tidyverse","testthat","arrow","digest"), Ncpus=4)'`
   (repos come from /etc/R/Rprofile.site; if missing, pass
   `repos="https://packagemanager.posit.co/cran/__linux__/noble/latest"`). Verify each loads.
2. Resolve the full hash: `git -C /home/user/shufinskiy/nba_data rev-parse 46488f0`.

## Block B: docs fixes (CLAUDE.md, PLAN.md)
3. Replace em dashes in headings: `CLAUDE.md:1` -> `# CLAUDE.md: WNBA 2026 Analysis (offseason phase)`;
   `PLAN.md:1` -> `# PLAN: WNBA 2026 Offseason Analysis`; `PLAN.md` "## Phase 1 — ", "## Phase 2 — ",
   "## Phase 3 — " -> use ": " instead of " — ".
4. CLAUDE.md "Data pin discipline" bullet: replace the sentences from "Re-pinning changes the
   baseline counts" to the end of the bullet with:
   "Expected counts for the current pin live in `data/reference/pipeline_baseline.csv`
   (one row per season_type: games, cdn rows, v2 rows, shotdetail rows, team-games). Re-pinning
   means regenerating that file deliberately and recording old vs new counts in PLAN.md; tests
   never silently pass on stale numbers. The v1 half-season checks (handoff §4 8-team table,
   182 games) are kept as a regression test on the v1 game subset, not deleted. `R/01_download.R`
   fetches tarballs directly from raw.githubusercontent.com, not via upstream's
   `loading/utils.R`; on re-pin, check the new files' column schema and dataset names."
5. CLAUDE.md "What carries over" section: change the first bullet's start to say v1 is recoverable
   at commit `4b78e2e` (tag `v1-deadline`, local only until pushed by Wendy). Replace "(published,
   tagged `v1-deadline`)" in the intro with "(v1 at commit `4b78e2e`, tag `v1-deadline`)".
   Replace the "Output files in `output/` are v1 artifacts" bullet with: "Paths come from
   `R/00_config.R`. Offseason processed data goes to `data/processed/full2026/`, offseason outputs
   to `output/offseason/`. Files directly in `output/` are v1 artifacts; never overwrite them.
   R/05 to R/14 still hard-code v1 paths and must be wired to `R/00_config.R` before they are re-run."
   Add after it a new bullet: "**v1 modeling decisions are defaults, not accidents:** ICC >= 0.15
   identity-anchor rule, garbage-time flag (period >= 4 and |margin| >= 20, flag not exclude),
   `pace_per40` for pace, `is_home` fixed effect, transition-possession weighting, R/13 200-minute
   floor. Change one only with a logged reason in PLAN.md (the full season may justify it)."
   Add to the analysis-tables section a new bullet: "**Analysis-ready tables** are the interface
   for offseason questions: see `docs/data_dictionary.md` and `R/load_tables.R`. New questions
   should start from these tables, not from raw files."
6. CLAUDE.md review-agent bullet: append "The agent definitions in `.claude/agents/` are still
   written for the deadline; update them once the offseason scope is set, and until then tell
   the agent in the prompt that the deadline framing does not apply."
7. PLAN.md: remove "expansion draft effects," from candidate 2. In the "Status" list add an item
   `- [ ] v1 publish blockers: status UNVERIFIED (Synergy case studies + §3d structural paragraph,
   coach-agent gate, cap/CBA verification checklist were open in the archived plan). Wendy to
   confirm done or abandoned.` In "Repo housekeeping" add `- [ ] Push tag v1-deadline (proxy
   refused it from the cloud session; run \`git push origin v1-deadline\` locally or tag 4b78e2e
   in the GitHub UI)` and `- [ ] Update .claude/agents/*.md for offseason scope (after scope set)`.
   Replace the Phase 1 Toronto item with: "Toronto has no shotdetail rows (v1 finding); `is_home`
   comes from shotdetail HTM/VTM. Confirm home/away comes from cdn or the games table instead, and
   check Toronto playoff games if any." Mark the scope as deferred: add under Scope "Decision
   2026-11-23: build the data pipeline first, settle the question later."
   Commit block B.

## Block C: config + re-pin + reconcile (R/00 to R/04)
8. Create `R/00_config.R`:
   - `PINNED_COMMIT <- "<full hash from step 2>"`, `PIN_SHORT <- "46488f0"`, `SEASON <- 2026L`
   - `RUN_TAG <- "full2026"`
   - `PROJECT_ROOT`: if `exists("PROJECT_ROOT")` keep it, else `normalizePath(".")`
     (scripts are run from repo root; tests set PROJECT_ROOT in setup.R before sourcing).
   - `proj_path <- function(...) file.path(PROJECT_ROOT, ...)` (only define if not already defined)
   - `RAW_DIR <- proj_path("data","raw",PIN_SHORT)`, `PROCESSED_DIR <- proj_path("data","processed",RUN_TAG)`,
     `OUTPUT_DIR <- proj_path("output","offseason")`
   - `SEASON_TYPES <- c(regular = "", playoffs = "_po")` (dataset name suffix)
   - `SOURCES <- c("cdnnba","nbastats","shotdetail")`
   - `dataset_name(source, season_type)` -> e.g. `wnba_cdnnba_po_2026` / `wnba_cdnnba_2026`
   - `raw_csv(source, season_type)` -> path in RAW_DIR
   - `V1_CUTOFF_GAMES <- 182L` and a comment: v1 pin 773ce29 covered regular-season game IDs 1-182.
9. `R/01_download.R`: source `R/00_config.R` (via `source(file.path("R","00_config.R"))` guarded so it
   works from repo root); delete local PINNED_COMMIT/DATASETS; loop over SOURCES x SEASON_TYPES;
   download into RAW_DIR; manifest (in RAW_DIR) gains columns `season_type`, `sha256`
   (digest::digest(file=..., algo="sha256")) and the commit. Keep `--latest`. Update the header.
10. `R/02_parse_pbp.R`: read both cdn files, add `season_type` ("regular"/"playoffs") column,
    bind_rows, then existing parse/qualifier/team-mapping steps unchanged. Assert gameId sets of
    the two season types do not overlap (stop if they do). If `apply_team_mapping` stops on an
    unmapped tricode (e.g. All-Star or Commissioner's Cup exhibition teams), STOP and report the
    tricodes and gameIds; do not add mappings or drop games without escalation.
    Write `PROCESSED_DIR/pbp_events.rds`.
11. `R/03_possessions.R`: read/write via PROCESSED_DIR. No logic changes; carry `season_type`
    through to possessions (join by gameId if it is not naturally carried).
12. `R/04_reconcile.R`: read via RAW_DIR/PROCESSED_DIR for both season types; run reconciliation
    per season_type; `validate_baseline_table()` runs on regular-season games with gameId in the
    v1 set (the first 182 regular-season gameIds when sorted; verify the 182nd game's date is
    2026-07-16 or earlier and the 183rd is later, else STOP and report); report written to
    `OUTPUT_DIR/reconciliation_report.md` with sections per season type, games per team per
    season type, date range per season type, and a "v1 subset regression" section.
    Also write `data/reference/pipeline_baseline.csv` (season_type, games, cdn_rows, v2_rows,
    shotdetail_rows, team_games, first_date, last_date, pin) from this run.
13. Tests: `tests/testthat/setup.R` sources `R/00_config.R` after setting PROJECT_ROOT (remove its
    own proj_path definition if config defines it identically). Update
    `test-baseline-table.R` to restrict to the v1 subset (comment why). `test-reconcile-cdn-v2.R`:
    keep a "v1 subset has 182 games" check and add per-season_type game counts compared to
    `data/reference/pipeline_baseline.csv`. `test-possession-invariants.R`: run over all games,
    both season types; retitle. Paths: replace any `data/processed/...` with PROCESSED_DIR-based
    paths. Leave test-fit-targets.R and test-player-value.R untouched (they test v1 outputs).
14. Run `Rscript R/01_download.R && Rscript R/02_parse_pbp.R && Rscript R/03_possessions.R && Rscript R/04_reconcile.R`
    then `cd tests && Rscript testthat.R` (check how testthat.R expects to be run; it uses
    test_dir("tests/testthat") so run from repo root: `Rscript tests/testthat.R`).
    Required: possession points equal final score in every team-game in both season types, 0 test
    failures. If not, STOP and report. Commit block C (data/raw and data/processed stay gitignored;
    commit pipeline_baseline.csv and output/offseason/reconciliation_report.md).

## Block D: analysis-ready tables
15. Extract `build_box()` and `build_minutes()` (and any helpers they call) from
    `R/13_player_value.R` verbatim into new `R/lib_player_box.R`; R/13 sources that file instead
    of defining them. No logic edits. Confirm with a diff that function bodies are byte-identical.
16. Create `R/04b_analysis_tables.R` (runs after R/04). Writes parquet (arrow::write_parquet)
    to `PROCESSED_DIR/tables/`. Every table carries `season` and `season_type`. Tables and grain:
    - `games`: one row per game. game_id, season, season_type, game_date, home_team, away_team,
      home_pts, away_pts, n_periods (OT = n_periods > 4). Home/away from cdn (not shotdetail;
      Toronto is missing in shotdetail).
    - `team_games`: one row per team per game. game_id, team, opponent, is_home, pts, opp_pts, win,
      possessions (from possessions table), plus FGM, FGA, FG3M, FG3A, FTM, FTA, OREB, DREB, AST,
      STL, BLK, TOV, PF (reuse `compute_team_game_counts_cdn()` from R/04 where it covers them;
      compute the rest from pbp_events).
    - `player_games`: one row per player per game. game_id, team, person_id, player_name, minutes,
      plus the box columns from `build_box()`. Apply R/13's minutes gate as a check (report the
      failure rate; do not abort here, write it to the report).
    - `players`: one row per person_id: player_name, teams (comma-separated), games, minutes per
      season_type.
    - `possessions`, `pbp_events`: copies of the processed tables as parquet.
    - `shots`: one row per FGA from cdn: game_id, team, person_id, period, clock seconds, zone/area
      fields, shot type, made, points, x/y if cdn has them, is_assisted.
    Then write `OUTPUT_DIR/tables_report.md`: row counts per table per season_type and the
    invariant results from step 18.
17. Create `R/load_tables.R`: `load_table(name, season_type = c("regular","playoffs","all"))`
    reading `PROCESSED_DIR/tables/<name>.parquet` and filtering; plus `list_tables()`.
18. Add `tests/testthat/test-analysis-tables.R` (skip_if_not tables exist): primary keys unique
    (games: game_id; team_games: game_id+team; player_games: game_id+team+person_id); every game has
    exactly 2 team_games; team_games pts == games home/away pts; sum of player_games pts per
    team-game == team_games pts; sum of player minutes per team-game within 1 minute of
    200 + 25*(n_periods-4); season_type never NA; shots made-points per team-game == team pts minus
    FT points.
19. Write `docs/data_dictionary.md`: per table, grain, primary key, every column with type and
    meaning, source script, known caveats (Toronto shotdetail gap, regular season vs playoffs
    are separate populations, minutes derived from substitutions). Add a short "quick start"
    showing `source("R/00_config.R"); source("R/load_tables.R"); load_table("player_games", "regular")`.
20. Run R/04b and the full test suite. 0 failures required (a test that cannot pass is reported,
    not deleted or skipped).
21. PLAN.md: check off completed Phase 1 items, record the new counts vs v1 counts, the
    reconciliation result, and add "Next session should" = choose offseason scope; wire R/05+ to
    R/00_config.R as needed by that scope. Commit block D and push.

## Report back (concise)
- Counts per season_type (games, rows per source, date range), games per team.
- Reconciliation result per season type; test summary.
- Any STOP conditions hit, anomalies (unmapped tricodes, exhibition games, minutes-gate rate).
- Commits pushed.
