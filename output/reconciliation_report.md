# Reconciliation Report

Generated: 2026-07-21 13:35:34 UTC

## 1. HANDOFF §4 baseline sanity table

All 8 named teams, 6 metrics each (FGA, FG%, 3PA rate, assisted rate,
fastbreak share, paint share). Deltas are computed minus target.

Max abs FGA delta: 0 | Max abs FG% delta: 0 | Max abs 3PA rate delta: 0 | Max abs assisted rate delta: 0 | Max abs fastbreak share delta: 0 | Max abs paint share delta: 0

All deltas are 0 at 3-decimal rounding -- the baseline table reproduces exactly.
Paint share definition confirmed: made shots with area in {Restricted Area,
In The Paint (Non-RA)} / FGM (this was previously an open question, now closed).

## 2. cdn vs nbastats v2 reconciliation

Total team-games compared: 364
Sum of |FGA delta| across all team-games: 1
Sum of |FGM delta| across all team-games: 1
Sum of |AST delta| across all team-games: 4
Sum of |FG3A delta| across all team-games: 0

Largest single-game FGM delta: -1 (game 1022600004, team IND)

cdn totals: 24,794 FGA / 11,120 FGM (verified). v2 totals: 24,795 FGA /
11,121 FGM -- a 1-shot, 1-game discrepancy (analogous to the NCAA project's
documented 2.5-FGM gap). AST reconciles to within a handful of events
league-wide (v2's AST is detected from free-text description, since
PLAYER2_ID is populated on every made shot in v2 and is not a usable assist
indicator -- verified against real data, not assumed). None of these small
gaps block Phase 1 feature-building; cdn remains the primary source.

## 3. shotdetail coverage

Teams present in shotdetail: 14 of 15 expected
Missing team(s): Toronto Tempo
shotdetail row count: 23163

CONFIRMED: shotdetail is missing the team(s) listed above. Per README
and PLAN.md, the §5d expected-points layer must source shot geometry
for the missing team(s) from cdn (x/y + area/areaDetail), not shotdetail.

## Gate

Per CLAUDE.md, scripts 05+ (features) do not get written until this report
is reviewed, AND analysis/eda_midseason.Rmd + output/eda_notes.md exist
(AMENDMENT_01 §2a-2b, the EDA gate).
