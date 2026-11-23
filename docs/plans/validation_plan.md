# Execution plan: external validation of the full2026 analysis tables (steps 1-3)

Repo: /home/user/wnba-2026-deadline-framework, branch `claude/exciting-knuth-djz7m1`.
Read CLAUDE.md, docs/data_dictionary.md, R/00_config.R, R/load_tables.R first.
Tables already built in data/processed/full2026/tables/ (if missing, run R/01, R/02, R/03, R/04, R/04b).

## Rules
- Validation only. Do NOT change R/01-R/04b logic or the tables. If a check finds a real
  problem in our data, STOP at the end of that step and report it with examples; do not fix.
- wehoop/ESPN data is a validator, never merged into the analysis tables or used in models.
  Raw wehoop files go in `data/raw/wehoop/` (gitignored via data/raw/).
- New outputs go to `output/offseason/`. Never touch files directly in `output/`.
- No em dashes, en dashes, or smart quotes in written files.
- Commit at the end with trailer lines:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01LqKYRNijtLZHhieuyMkmRN
  ```
  Push to `claude/exciting-knuth-djz7m1` only (retry network errors up to 4x with backoff). No PR.

## Step 1: wehoop cross-check (new script `R/04c_validate_external.R`)
1. Add to R/00_config.R: `WEHOOP_DIR <- proj_path("data","raw","wehoop")` and the three URLs
   (verified reachable 2026-11-23):
   - https://github.com/sportsdataverse/sportsdataverse-data/releases/download/espn_wnba_player_boxscores/player_box_2026.parquet
   - https://github.com/sportsdataverse/sportsdataverse-data/releases/download/espn_wnba_team_boxscores/team_box_2026.parquet
   - https://github.com/sportsdataverse/sportsdataverse-data/releases/download/espn_wnba_schedules/wnba_schedule_2026.parquet
   Download if absent; record sha256, byte size and download date in `WEHOOP_DIR/manifest.csv`.
2. Inspect the schemas first (print column names, season_type values, game counts by season type).
   ESPN season_type is 2 = regular, 3 = playoffs; confirm from the data rather than assuming.
   Identify non-counting games (All-Star; Commissioner's Cup final) in the ESPN schedule.
3. Team mapping: build an explicit ESPN abbreviation -> our tricode table (ESPN uses e.g. LV, LA,
   NY, WSH, CONN, GS, POR, PHX, TOR). Write it to `data/reference/espn_team_map.csv` (tracked).
   Stop if any ESPN team in the 2026 data is unmapped.
4. Game matching: match ESPN game_id to our game_id by (game_date, home team, away team). Allow
   +/- 1 day on date only if needed for timezone, and report how many needed it. Write
   `data/reference/espn_game_map.csv` (our game_id, espn game_id, season_type). Report: our
   games unmatched, ESPN games unmatched (by season type, with ESPN's game type/notes).
5. Team-game comparison on matched games: pts, FGM, FGA, FG3M, FG3A, FTM, FTA, OREB, DREB, AST,
   STL, BLK, TOV, PF. Note ESPN team box may include team rebounds/turnovers; if a column
   differs systematically, check whether the ESPN total includes team-credited stats before
   calling it a mismatch, and document the definition used.
6. Player matching within each matched team-game: ESPN athlete_id -> our person_id by normalized
   name (lowercase, strip accents and punctuation, compare full name; fall back to last name
   unique within the team-game). Write `data/reference/espn_player_map.csv` (one row per
   person_id/athlete_id pair, with names). Report unmatched players both ways (DNP rows in ESPN
   with 0/NA minutes are expected unmatched: count them separately).
7. Player-game comparison: minutes, pts, FGM, FGA, FG3M, FG3A, FTM, FTA, OREB, DREB, REB, AST,
   STL, BLK, TOV, PF. Tolerances: minutes within 1.0 (ESPN rounds to whole minutes), all count
   stats exact. Report per stat: player-games compared, exact-match rate, number outside
   tolerance, max abs difference, and the worst 10 rows. For minutes also report the
   distribution of differences and specifically the 10 player-games whose minutes changed in
   the starter-inference fix (listed in PLAN.md / tables_report.md): do they now agree with ESPN?
8. Write `output/offseason/external_validation.md` with all of the above.

## Step 2: schedule, standings, playoff bracket (same script, separate report section)
9. Regular season: 330 games, each team 44, no duplicate game_id, no duplicate (date, home, away).
   Is any of our 330 a non-counting game (Commissioner's Cup final, All-Star)? Use the ESPN
   schedule's game type/notes. If so, report it; do NOT drop it.
10. Standings: W-L per team from our `games` vs W-L computed from the ESPN schedule (counting
    games only). Must match exactly. Also report the final standings table.
11. Playoffs: group our 23 playoff games into series (same two teams). Per series: teams, games,
    wins each, winner, and check the winner reached the required wins (infer best-of length per
    round from the data and state it). Check each series winner appears in a later round (except
    the champion) and no eliminated team plays again. Report the bracket and the champion.

## Step 3: manual-style spot checks (same report, own section)
12. For these games print side-by-side our vs ESPN team box and player box (all players):
    - one regular-season overtime game (pick the first with n_periods > 4),
    - playoff game 1042600112 (the flagrant-FT game; DAL 108 GSV 100),
    - 1022600312 CON (player 203398, minutes 10 to 0 after the fix),
    - 1022600237 CHI (player 204333, 36.7 to 26.7),
    - 1042600304 ATL (Hillmon, 25.8 to 35.8).
    Flag any disagreement.

## Tests and wrap-up
13. Add `tests/testthat/test-external-validation.R` (skip_if_not the wehoop files and maps exist):
    all our games matched to ESPN; standings match; count stats exact on team-games; player-game
    count stats exact except a documented allowlist (store any accepted known discrepancies in
    `data/reference/external_validation_exceptions.csv` with a reason column: only for differences
    attributable to source disagreement, e.g. the 5 cdn-vs-v2 games, never to our bugs);
    minutes within 1.0 for >= 99% of player-games (set the threshold to the observed rate only if
    it is >= 99%, else report and stop).
14. Run the full suite (0 failures required; the v1 player-value skip is expected).
15. Update docs/data_dictionary.md (validation section: what was checked, against what, results)
    and PLAN.md (check off, record results, "Next session should": write full-season re-read
    hypotheses). Update README run order to include R/04c. Commit, push, confirm clean tree.

## Report back (concise)
- Match rates (games, players), team-game and player-game agreement per stat, minutes agreement.
- Any non-counting games found; standings match; bracket and champion.
- Spot-check outcome. Any STOP conditions. Commit hash.
