# WNBA 2026 Trade Deadline Framework — Project Handoff (v2, Consolidated)

Prepared: July 18, 2026. Supersedes the July 17 handoff entirely.
Owner: Wendy Guan (WHoopsLab).
Hard deadline: **publish July 26-27, 2026** (All-Star break). Analysis is decision-relevant only until the August 2 trade deadline. No work extends past August 2.

---

## 1. Problem Statement (locked — do not drift from this)

> Between the All-Star break (July 23-27) and the trade deadline (August 2, 3:00 p.m. ET), every WNBA front office must decide whether their first half reflects a talent problem, a process problem, or a luck problem — because those imply opposite deadline strategies: acquire, adjust, or hold. Box-score results conflate all three. This framework decomposes each team's first-half offense into **schedule-adjusted identity** (what they choose to do), **shot generation** (the quality of looks the process creates), and **shot making** (whether they convert those looks) — so the deadline question "what do we actually need?" is answered from evidence rather than record.

The decision chain has two questions asked by two rooms:

1. **What do we need?** — front-office question. Answered by the open-PBP decomposition framework. This is the load-bearing analysis.
2. **Who fits how we play?** — coaching-staff question, triggered only when the answer to (1) is "acquire." Answered by Synergy play-type profiles and the existing WHoopsLab archetype/synergy-delta machinery. Case-study teams only.

Everything in the project must trace to one of these two questions. Anything that doesn't is out of scope for this cycle.

### Success criteria
- A reader in a front office can locate their team in the decomposition and know which lever it points to.
- Every quantitative claim in the framework reproduces from the public repo on open data alone.
- Published during the All-Star break. A late, perfect version is a failed version.

---

## 2. Audience & Distribution Plan

- **Primary:** WNBA front-office and analytics staff. Vocabulary: decomposition, schedule adjustment, expected points, roster construction.
- **Secondary:** coaching staff readers of the case studies. Vocabulary: actions, roles, fit, play types.
- **Tertiary:** WHoopsLab public audience (YouTube/Substack version).
- Outreach (deadline week, July 27 – Aug 2, individually, one team-specific observation each): Boki Wang (GSV section), Eli Horowitz / Lauren Manis / Mark Schindler (Toronto section), Portland HC contact (Portland section). Optional: Todd Whitehead (Synergy attribution courtesy).

---

## 3. Data Architecture — Two Layers, Hard Boundary

### Layer 1: Open PBP data (the spine)
Source: `https://github.com/shufinskiy/nba_data`, pinned commit `773ce29` ("add wnba 2026 data (ID 1 to 182)"). All models, all decomposition numbers, all charts derive from this layer. The public repo reproduces every quantitative claim from these files alone.

```
https://github.com/shufinskiy/nba_data/raw/main/datasets/wnba_cdnnba_2026.tar.xz       (primary PBP)
https://github.com/shufinskiy/nba_data/raw/main/datasets/wnba_shotdetail_2026.tar.xz   (shot table)
https://github.com/shufinskiy/nba_data/raw/main/datasets/wnba_nbastats_2026.tar.xz     (v2, reconciliation only)
```
Historical seasons (same naming, 1997-2025; cdnnba from 2022) exist for the expected-points baseline if 2024-25 priors are preferred over in-season 2026 averages.

**Data refresh:** current files run through July 16 (182 games). Games continue to July 22. Check the repo around July 23 for a fresh commit; if updated, re-pin and re-run (pipeline must be re-runnable end to end). If not, 182 games through July 16 is the stated, defensible cutoff.

### Layer 2: Synergy Sports (case-study enrichment — quarantined)
- **Team-aggregate exports only** (play-type frequency and PPP per team). **No possession-level joins to the open PBP under any circumstances** — the time-sequence alignment problem is a documented bottleneck from the WHoopsLab app and is the single biggest schedule risk. Do not attempt it.
- Used only in case-study prose for GSV, Toronto, Portland. Cited "Source: Synergy Sports | 2026 WNBA," never committed to the repo, never enters any model.
- Fit reads reuse the **existing WHoopsLab app outputs**: ball-handler behavioral archetypes (PCA/K-means, 16 features) and BH-screener synergy deltas (18,158 P&R plays). These are built on 2025 data — treat as priors on player style, not current-season measurements, and say so in the methodology note. If 2026 Synergy exports allow a quick play-type-mix refresh for the handful of named case-study players, do that; if slow, ship with 2025 priors.
- **Time-box: Synergy work happens July 24-25 only, after the open-data framework is complete.** If it isn't converging by July 25, the piece ships diagnosis-only and is still complete.

---

## 4. Verified Data Facts (audited July 17 — validate pipeline against these, do not re-derive from memory)

Coverage: 182 games, May 8 – July 16, 2026. All 15 teams. Row counts: cdn 89,735 · nbastats v2 74,224 · shotdetail 23,163 (one row per FGA).

Games per team: SEA 26; GSV, MIN, PDX, PHX 25; ATL, CHI, CON, DAL, IND, LVA, NYL, TOR 24; LAS, WAS 23.

**Tricode trap: LAS = Los Angeles Sparks, LVA = Las Vegas Aces.** Also PDX = Portland Fire, TOR = Toronto Tempo, GSV = Golden State Valkyries. A unit test must assert the LAS/LVA mapping.

### cdn PBP (`wnba_cdnnba_2026.csv`) — primary source, 56 columns
- Sort by `gameId`, `orderNumber`. `clock` is ISO-8601 duration (`PT09M57.00S`) — parse to seconds. Period boundaries: `actionType == 'period'`. `timeActual` = wall clock (ordering sanity checks only).
- `actionType` counts: substitution 20,672 · 2pt 15,640 · rebound 15,346 · 3pt 9,154 · freethrow 7,753 · foul 7,590 · turnover 5,172 · steal 2,711 · timeout 1,825 · period 1,478 · block 1,437 · jumpball 477 · violation 294 · game 182 · ejection 4.
- **`qualifiers`** (comma-separated, order varies — use `str_detect`, never exact match): `fastbreak`, `fromturnover`, `2ndchance`, `pointsinthepaint`. Transition/second-chance/points-off-TOV classification is given, not inferred.
- Shot `subType`: Jump Shot 15,252 · Layup 9,002 · Hook 539 · DUNK 1. `descriptor` (shot-creation flavor): driving 3,407 · pullup 3,170 · running 1,746 · cutting 1,550 · step back 1,095 · plus turnaround/putback/floating/fadeaway variants.
- Shot location: `x`, `y` on 100% of FGA; `area`/`areaDetail` zones (Restricted Area, In The Paint (Non-RA), Mid-Range, Left/Right Corner 3, Above the Break 3); `shotDistance`; `side`.
- Assists (`assistPersonId`) on made FGs only. **League assisted rate on makes = 66.0% (7,339 / 11,120)** — reconciliation anchor.
- `possession` column = teamId of possessing team (verified). Freethrow `subType` gives trip position (`1 of 2`, `2 of 2`, `1 of 1`, `x of 3`).
- Turnover subtypes available (bad pass 1,887 · out-of-bounds 985 · lost ball 874 · offensive foul 745 · shot clock 268 · traveling 253 · …).
- `scoreHome`/`scoreAway` on scoring events. Substitutions enable lineup tracking — **out of scope this cycle.**

### shotdetail (`wnba_shotdetail_2026.csv`) — expected-points table
NBA-standard schema: `LOC_X`/`LOC_Y`, `SHOT_DISTANCE`, `SHOT_ZONE_BASIC/AREA/RANGE`, granular `ACTION_TYPE` (Driving Layup Shot, Pullup Jump shot, Cutting Layup Shot, …), `SHOT_MADE_FLAG`, `GAME_DATE`, `HTM`/`VTM`, `GAME_EVENT_ID` (joins to cdn `shotActionNumber`/event number within game).
Zones: Above the Break 3 = 7,309 · Restricted Area = 7,037 · Paint non-RA = 4,991 · Mid-Range = 2,651 · Corner 3s = 1,114 · Backcourt = 61 (exclude/bucket as heaves).

### nbastats v2 — reconciliation only
Classic EVENTMSGTYPE format. Use solely to cross-validate per-game FGA/FGM/AST/3PA counts against cdn (the analog of the NCAA project's wehoop reconciliation and its documented 2.5-FGM gap). Ignore nbastatsv3.

### Baseline sanity table (pipeline must reproduce within rounding)
| Team | FGA | FG% | 3PA rate | Assisted rate (FGM) | Fastbreak share (FGA) | Paint share (FGM) |
|---|---|---|---|---|---|---|
| GSV | 1690 | .419 | .449 (1st) | .638 | .066 (14th) | .532 (15th) |
| NYL | 1559 | .459 | .440 | .686 | .079 | .609 |
| PDX | 1684 | .444 | .416 | .676 | .087 | .637 |
| TOR | 1630 | .447 | .410 | .660 | .097 | .575 |
| MIN | 1755 | .481 | .319 | .628 | .115 | .600 |
| WAS | 1489 | .430 | .306 | .679 | .064 | .746 (1st) |
| CON | 1634 | .435 | .266 (15th) | .649 | .086 | .675 |
| ATL | 1700 | .434 | .378 | .647 | .119 (1st) | .712 |

Storyline already visible: **GSV is the league's most extreme stylistic outlier** — highest 3PA rate, lowest paint reliance, near-lowest transition share, .419 FG%. The framework's flagship question: shot-generation problem or shot-making problem? Portland (three-heavy, .676 assisted) and Toronto (balanced perimeter) already show distinct identities — the expansion deadline question is accumulate assets vs. protect an emerging identity.

---

## 5. Methodology Spec

### 5a. Possession segmentation (also the future Phase-3 input — build it clean)
Output table: `possession_id, gameId, team, opponent, period, start_event, end_event, start_clock, end_clock, outcome, points, context flags (transition / second-chance / off-TOV)`. Handle: and-ones (made FG + shooting foul + FTs = one possession), FT trip sequencing via freethrow subType, technical FTs (no possession change), end-of-period truncations.

### 5b. Team-game style features (one row = team × game)
Pace (two estimates, reconciled: possession-table count vs. FGA + 0.44·FTA − OREB + TOV; note 0.44 is an NBA convention — validate before quoting), 3PA rate, assisted rate (of FGM), transition share, points-off-TOV share, second-chance share, paint FGM share, zone profile shares (RA / paint / mid / corner3 / ATB3), shot-descriptor mix (driving / pullup / cutting / putback shares), FT rate (FTA/FGA), TOV rate.

### 5c. Leg 1 — Schedule-adjusted identity (mixed effects)
For each style metric: `metric ~ (1|team) + (1|opponent)` in lme4. Extract team BLUPs (adjusted identity), report ICC (stable identity vs. matchup noise). Signature deliverable: raw rank vs. adjusted rank deltas. This is the NCAA Movement-vs-Gravity machinery ported directly.

### 5d. Legs 2 & 3 — Generation vs. making (expected-points baseline, NOT a trained model)
League-average points per shot by **zone × shot class × context (transition / halfcourt / second-chance)**, computed from 2026 data (or 2024-25 historicals as priors — analyst's choice, state it). Then per team:
- **Shot generation** = expected PTS/100 possessions given their shot diet (process quality)
- **Shot making** = actual − expected PTS/100 (conversion above/below the looks created)
Methodology note states plainly: this is a stratified expected-points baseline (qSQ-lite), not a trained shot-quality model; a trained model is named future work. Do not oversell it.

### 5e. The deadline read (the deliverable synthesis)
Per team, one row: adjusted identity summary · generation percentile · making percentile · schedule note → **which lever: acquire / adjust / hold.** This table is the piece.

### 5f. Fit layer (case studies only — GSV full treatment; TOR, PDX lighter)
Framework output ("what they need") → WHoopsLab archetype that addresses it → named candidate profiles from existing app outputs (archetypes + synergy deltas), in coaching vocabulary. One or two fit reads per case-study team, maximum. No league-wide fit matrix, no refreshed clustering, no new player-level models.

### 5g. Guardrails
- Never call descriptor-derived features "play types." They are shot-creation profiles. Synergy play-type language appears only in Synergy-sourced case-study prose.
- Player-level claims require ≥100 FGA or ≥150 possessions used.
- Every published number traces to a script; cdn-vs-v2 reconciliation deltas documented.
- Language hygiene: no em/en dashes, no smart quotes, no "leverage/robust/spearheaded/seamless."

---

## 6. Timeline (hard-scoped)

| Dates | Work |
|---|---|
| Jul 18-20 | Repo setup, download/parse/possession segmentation, reconciliation tests passing |
| Jul 21-22 | Style features, mixed-effects models, BLUPs/ICC |
| Jul 23 | Data refresh check (new commit?); expected-points baseline; generation/making decomposition; deadline-read table |
| Jul 24-25 | Synergy case-study enrichment + fit reads (time-boxed; drop if not converging) |
| Jul 25-26 | Writing, graphics, methodology notes |
| Jul 26-27 | Publish (repo + writeup + WHoopsLab version) |
| Jul 27-Aug 2 | Individual outreach notes, deadline-week engagement |

Cut list (explicitly out of scope this cycle): league style map PCA/clustering, lineup/on-off anything, defensive mirrors, trained xPTS model, possession-value model, Synergy-PBP joins. Post-deadline extensions (September+, separate decision): trained shot-quality model; possession-value framework timed for the November hiring window.

---

## 7. Repo Structure (public, R-first)

```
wnba-deadline-framework/
├── CLAUDE.md                    # Claude Code operating instructions (separate file)
├── README.md                    # problem statement, provenance (pinned commit + download date), run instructions
├── R/
│   ├── 01_download.R            # pull pinned tar.xz, extract, checksum/row-count log
│   ├── 02_parse_pbp.R           # clock parsing, qualifier expansion, LAS/LVA mapping
│   ├── 03_possessions.R         # possession segmentation (see 5a)
│   ├── 04_reconcile.R           # cdn vs v2 per-game counts; baseline-table validation
│   ├── 05_features.R            # team-game style features (5b)
│   ├── 06_models.R              # lme4 mixed effects, BLUPs, ICC (5c)
│   ├── 07_expected_points.R     # stratified xPTS baseline + decomposition (5d)
│   ├── 08_deadline_read.R       # synthesis table (5e)
│   └── 09_graphics.R            # publication charts
├── tests/testthat/              # port the NCAA project's assertion-suite pattern
├── data/raw/                    # gitignored; populated by 01_download.R
├── data/processed/
├── analysis/                    # case-study notebooks (Synergy numbers typed in as constants, cited)
└── output/                      # findings.md, deadline-read table, charts
```

Stack: R (tidyverse, lme4, testthat, hms/lubridate). Deployment/apps: none this cycle — static writeup + repo.
