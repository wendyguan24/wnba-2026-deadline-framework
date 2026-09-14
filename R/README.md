# R pipeline reference

Summary of the numbered R scripts that produce the framework. This is a map of what
each script does, what it reads, and what it writes, plus the order they must run in.
It is documentation of the existing pipeline, not a spec: the spec is
`HANDOFF_wnba_deadline_framework.md` as amended by `AMENDMENT_01_...md` and
`AMENDMENT_02_...md`, and the live task record is `PLAN.md`.

Every quantitative claim in `output/findings.md` reproduces from open data through
these scripts. Synergy-derived numbers never enter this pipeline; they live only in
`analysis/` case-study prose (reproducibility boundary, see `CLAUDE.md`).

## Run order

Mostly numeric, with two dependencies that break strict numbering:

1. `01` to `04` in order, then the reconciliation gate must be green
   (`tests/testthat/` via `tests/testthat.R`).
2. The EDA gate runs next: `analysis/eda_midseason.Rmd` -> `output/eda_notes.md`
   (hypotheses registry). No feature or model script runs until this clears.
3. `05`, then **`07` before `06`** -- `06` reads `team_game_shot_making.rds`, which
   `07` writes (the trajectory layer's 5th metric, `shot_making_residual`).
4. `12` (standing) before `08` and `11` -- both condition their recommendation on the
   `window` tier `12` produces.
5. `08`, then `09`, `10`, `11`.
6. `13` before `14` -- `14` reads the player-value exhibit `13` writes.

So a full clean run is: `01 02 03 04` -> EDA gate -> `05 07 06 12 08 09 10 11 13 14`.

## Scripts

### 01_download.R -- pin and fetch open data
Downloads and extracts the pinned WNBA 2026 files from `shufinskiy/nba_data` and logs
a manifest (commit hash, timestamp, row/game counts) so downstream results state their
snapshot. `--latest` swaps the pinned commit for `main` (the July 23 data-refresh
check). Requires system `tar`.
- In: none (GitHub over HTTPS)
- Out: `data/raw/wnba_{cdnnba,shotdetail,nbastats}_2026.csv`, `data/raw/download_manifest.txt`

### 02_parse_pbp.R -- clean event table
Parses the cdn play-by-play feed: `clock` (ISO-8601 duration) to seconds, `qualifiers`
expanded into order-independent boolean flags, and the full 15-team tricode map applied
(LAS = Sparks, LVA = Aces, never swapped). WNBA quarters are PT10M, not PT12M.
- In: `data/raw/wnba_cdnnba_2026.csv`
- Out: `data/processed/pbp_events.rds`

### 03_possessions.R -- possession segmentation
Segments the event stream into possessions off the cdn `possession` column plus period
boundaries. And-one and technical-FT sequences keep the `possession` value by
construction, so `handle_and_ones()` / `handle_technical_fts()` are validation checks,
not merge logic. Technical FTs are emitted as their own possession rows credited to the
shooting team (the reconciliation bug fix). Possession points sum to the box score
exactly in all 364 team-games.
- In: `data/processed/pbp_events.rds`
- Out: `data/processed/possessions.rds`

### 04_reconcile.R -- validation gate
Reconciles cdn vs nbastats v2 per-game FGA/FGM/AST/3PA, validates the HANDOFF §4
baseline table reproduces within rounding, and confirms the shotdetail-Toronto coverage
gap. Scripts 05+ do not get written until `tests/testthat/` passes against this output.
- In: `data/processed/pbp_events.rds`, `data/raw/wnba_nbastats_2026.csv`, `data/raw/wnba_shotdetail_2026.csv`
- Out: `output/reconciliation_report.md`

### 05_features.R -- team-game style features
Builds the 364-row team-game feature table: pace (`pace_poss` primary, `pace_formula`
secondary cross-check), 3PA rate, assisted rate, transition / off-TOV / second-chance
shares, paint FGM share, zone-profile shares, descriptor mix, FT and TOV rates. Carries
the EDA-forced columns: `is_ot`, `game_minutes`/`pace_per40`, `garbage_time_poss_share`
(flag not exclude), `is_home` (from shotdetail HTM/VTM).
- In: `data/processed/pbp_events.rds`, `data/processed/possessions.rds`
- Out: `data/processed/team_game_features.rds`

### 06_models.R -- identity and trajectory models
Fits `metric ~ is_home + (1|team) + (1|opponent)` per style metric; extracts team BLUPs
(adjusted identity), ICC, and raw-vs-adjusted rank deltas. `pace_per40` is modeled, not
raw `pace_poss`. Also fits the trajectory layer (§5c-bis) on the shortlist -- transition
share, transition points per possession, assisted rate, live-ball TOV rate, and
`shot_making_residual` (the optional 5th, first to cut). Singular random-slope fits use
the documented random-intercept fallback (`fallback_used`). Includes the §2c
garbage-time-exclusion sensitivity re-run.
- In: `data/processed/team_game_features.rds`, `data/processed/team_game_shot_making.rds` (run 07 first)
- Out: `output/icc_table.csv`, `output/team_rank_deltas.csv`, `output/team_trajectories.csv`, `output/trajectory_league_trends.csv`, `output/trajectory_sensitivity.md`, and `data/processed/` `.rds` counterparts (`team_blups.rds`, `team_trajectories.rds`)

### 07_expected_points.R -- stratified expected-points baseline
Builds a stratified expected-points baseline (qSQ-lite, NOT a trained model): league
points per shot over 49 strata (zone x shot class x context), cdn-only, with a
MIN_CELL_N=100 collapse cascade. Splits each team into shot generation (expected PTS/100
given diet) and shot making (actual minus expected). Toronto shot geometry comes from
cdn, never shotdetail.
- In: `data/processed/pbp_events.rds`, `data/processed/possessions.rds`
- Out: `data/processed/expected_points_baseline.rds`, `data/processed/team_generation_making.rds` (+ `output/team_generation_making.csv`), `data/processed/team_game_shot_making.rds`

### 08_deadline_read.R -- deadline-read table (core deliverable)
One row per team: adjusted identity summary (anchored only on ICC >= 0.15 metrics),
generation and making percentiles, `trajectory` (improving / flat / declining, footnoted
when the interval spans zero, `fallback_used` surfaced), `cap_context` (room / tight /
capped from the reference CSV), and the feasibility-conditioned `lever` (acquire / adjust
/ hold, never recommending a move the cap forbids). Recommendation is window-conditioned
via shared logic with R/11. `trajectory` and `cap_context` are never cut.
- In: `data/processed/team_trajectories.rds` and `team_blups.rds` (06), `team_generation_making.rds` (07), `output/standing.csv` (12), `data/reference/cap_context_2026.csv`, `output/icc_table.csv`, `output/trajectory_league_trends.csv`
- Out: `output/deadline_read.csv`, `output/deadline_read.md`

### 09_graphics.R -- publication charts
Three charts: the schedule-adjusted identity map (raw vs adjusted rank), the shot
generation vs shot making scatter (the GSV storyline), and the fitted trajectory small
multiples (one trajectory graphic maximum; expansion teams highlighted). No
rolling-window machinery.
- In: `output/team_rank_deltas.csv`, `output/icc_table.csv`, `data/processed/team_generation_making.rds`, `data/processed/team_trajectories.rds`
- Out: `output/identity_map.png`, `output/generation_vs_making.png`, `output/trajectory_small_multiples.png`

### 10_framework_evaluation.R -- §2c evaluation criteria
Split-half stability (first-half vs second-half team means per metric) and
alternative-stratification sensitivity (headline generation/making findings under a
coarser zone-only baseline). Garbage-time disposition is in R/06; face validity is
qualitative in `findings.md`.
- In: `data/processed/team_game_features.rds`, `team_game_shot_making.rds`, `pbp_events.rds`, `possessions.rds`, `team_generation_making.rds`
- Out: `output/framework_evaluation.md`

### 11_generation_gap.R -- generation-gap attribution (in-scope fit, part 1)
Decomposes each team's offensive generation gap vs the league into a VOLUME component
and a MIX component, attributes mix by zone, labels each mix-gap zone, flags
identity-driven zones (protect, not fill, via the ICC >= 0.15 rule), and assigns a
window-conditioned `fit_read`. The decomposition itself stays record-independent; only
the recommendation is window-conditioned, sharing logic with R/08.
- In: `data/processed/pbp_events.rds`, `team_generation_making.rds`, `team_blups.rds`, `team_trajectories.rds`, `output/icc_table.csv`, `output/standing.csv`
- Out: `output/generation_gap.csv`, `output/generation_gap.md`

### 12_standing.R -- standing / window layer
Each team's record and a `window` tier (buyer / bubble / seller) from game results,
blending z-scored win percentage and z-scored point differential per game (so a lucky
record is not miscast). Conditions the recommendation downstream, never the diagnosis.
- In: `data/processed/possessions.rds`
- Out: `output/standing.csv`

### 13_player_value.R -- player-value screen
A reproducible open-data production proxy: Game Score over replacement per 40 minutes,
minutes reconstructed from substitutions (5-on-court gate 99.9%). The value number is
demoted to coarse production TIERS on named candidates; the full table is a
reproducibility exhibit only. Box-score, offense-weighted, NBA-derived weights disclosed
like the 0.44-FT convention. Not an impact metric.
- In: `data/processed/pbp_events.rds`
- Out: `output/player_value.csv`

### 14_fit_targets.R -- fit-first target reads (fit deliverable)
Shops in front-office order: need (R/08 / R/11) -> attainability (seller pool) ->
affordability (acquiring team's cap tier) -> value (R/13 tier as a within-fit filter).
Verb-obedient to each team's `deadline_read` recommendation. Hybrid keep-and-flag: every
best on-style fit is kept and labeled `target` or `context` (cored / over-tier), with a
guaranteed floor of actionable rows. Offense-scope only. Contract bands are hand-curated
in the reference CSV, never fabricated.
- In: `output/player_value.csv` (13), `output/standing.csv` (12), `output/deadline_read.csv` (08), `data/processed/pbp_events.rds`, `data/reference/candidate_contracts_2026.csv`
- Out: `output/fit_targets.md`, `output/fit_targets.csv`

## Tests

`tests/testthat/` (run via `tests/testthat.R`) covers tricode mapping, the baseline
table, cdn-vs-v2 reconciliation, possession invariants, clock parsing, player value
(tier monotonicity), and fit targets. The suite must be green before scripts 05+ are
trusted.
