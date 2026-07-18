# WNBA 2026 Trade Deadline Framework

Prepared by Wendy Guan (WHoopsLab). Hard deadline: publish July 26-27, 2026 (All-Star
break); decision-relevant only through the August 2 trade deadline.

## Problem statement

> Between the All-Star break (July 23-27) and the trade deadline (August 2, 3:00 p.m.
> ET), every WNBA front office must decide whether their first half reflects a talent
> problem, a process problem, or a luck problem — because those imply opposite
> deadline strategies: acquire, adjust, or hold. Box-score results conflate all three.
> This framework decomposes each team's first-half offense into schedule-adjusted
> identity (what they choose to do), shot generation (the quality of looks the
> process creates), shot making (whether they convert those looks), and trajectory
> (what they are becoming), then filters the resulting deadline read through cap and
> contract feasibility, so the deadline question "what do we actually need, and what
> can we actually do about it?" is answered from evidence rather than record.

*(Extended sentence 2 verbatim per AMENDMENT_02 Part 1 — supersedes the original
handoff §1 wording, which is left untouched in `HANDOFF_wnba_deadline_framework.md`
itself.)*

Three questions, three rooms (the third added by AMENDMENT_02 §1):

1. **What do we need?** — front-office question, answered by the open-PBP
   decomposition framework. This is the load-bearing analysis.
2. **Who fits how we play?** — coaching-staff question, triggered only when the
   answer to (1) is "acquire." Answered by Synergy play-type profiles and the
   existing WHoopsLab archetype/synergy-delta machinery. Case-study teams only.
3. **Can we do it?** — front-office question, answered by the cap-context layer (cap
   position, tradeable contracts, CBA mechanics). Gates question 2: fit reads are only
   generated for moves the cap-context layer says are feasible.

Full spec: [HANDOFF_wnba_deadline_framework.md](HANDOFF_wnba_deadline_framework.md),
amended by [AMENDMENT_01_trajectory_workflow_agents.md](AMENDMENT_01_trajectory_workflow_agents.md)
(trajectory layer, EDA gate, review agents) and
[AMENDMENT_02_contracts_cba_cap.md](AMENDMENT_02_contracts_cba_cap.md) (cap-context
layer, contract typology, feasibility-conditioned lever calls — wins over both the
handoff and AMENDMENT_01 on contract/cap matters only).
Agent operating rules: [CLAUDE.md](CLAUDE.md). Live task tracker: [PLAN.md](PLAN.md).

### What AMENDMENT_01 adds

- **Trajectory layer (§5c-bis):** the deadline-read table gains a required
  `trajectory` column (improving / flat / declining), fit as
  `metric ~ game_index + (1 + game_index | team) + (1 | opponent)` on a four-metric
  shortlist, registered against hypotheses H1-H3 before modeling.
- **EDA gate:** `analysis/eda_midseason.Rmd` runs after reconciliation and before any
  feature/model script, producing `output/eda_notes.md` with the hypotheses registry.
- **Three review-agent gates** (`.claude/agents/`): `analytics-reviewer` (methodology
  rigor), `gm-agent` (deadline-read decision-usefulness), `coach-agent` (case-study
  usefulness for a coaching staff) — run on artifacts, feedback triaged and logged in
  `PLAN.md`, not auto-applied.

### What AMENDMENT_02 adds

- **Cap-context layer:** a hand-curated, attributed reference table,
  [data/reference/cap_context_2026.csv](data/reference/cap_context_2026.csv) (all 15
  teams — committed salary, cap room, expiring/max counts, a flexibility tier). Exempt
  from the pipeline-reproducibility rule (it's not scraped) but not from the
  traceability rule (every figure carries a source and date). See
  [data/reference/README.md](data/reference/README.md).
- **Deadline-read table gains two more columns:** `cap_context` (room / tight /
  capped) and a feasibility-conditioned `lever` — an "acquire" read under a capped
  context becomes `acquire (constrained: requires salary out)` or downgrades, never
  silently recommends a move the cap forbids.
- **Contract typology in case-study fit reads:** each candidate profile gains a
  contract line (years remaining, salary tier, expiring/not, asset class). Supermax
  targets are excluded from fit reads (immobile at the deadline). Profiles stay
  profiles, never trade proposals.
- **One structural paragraph** in the findings draft on what the first post-CBA
  deadline means league-wide (contract-length distribution, market liquidity,
  supermax immobility, the World Cup break as a hold incentive).
- Precision discipline: cap figures are **tiers, not to-the-dollar claims** — public
  WNBA contract data is thin and year one of a new CBA is exactly when trackers lag.

## Data architecture — two layers, hard boundary

- **Layer 1 (open PBP, the spine).** `github.com/shufinskiy/nba_data`, pinned commit
  `773ce29`. Every model, every decomposition number, every chart derives from this
  layer alone — the public repo reproduces every quantitative claim from these files.
- **Layer 2 (Synergy, quarantined).** Team-aggregate play-type frequency/PPP only, for
  case-study prose (GSV, Toronto, Portland). Cited `Source: Synergy Sports | 2026
  WNBA`, never committed to the repo, never joined to the open PBP at the possession
  level, never enters a model. See `.gitignore` and `analysis/case_study_template.Rmd`.

## Data provenance

Source URLs (pinned to commit `773ce29`, "add wnba 2026 data (ID 1 to 182)"):

```
https://github.com/shufinskiy/nba_data/raw/main/datasets/wnba_cdnnba_2026.tar.xz
https://github.com/shufinskiy/nba_data/raw/main/datasets/wnba_shotdetail_2026.tar.xz
https://github.com/shufinskiy/nba_data/raw/main/datasets/wnba_nbastats_2026.tar.xz
```

`R/01_download.R` downloads and extracts the files and writes
`data/raw/download_manifest.txt` recording the exact commit hash, download timestamp,
and per-file row/game counts, so every later result states exactly what snapshot it
used. Run 2026-07-18 against `773ce292bb2cd9bc6ec98d70de95176607ccbaeb`: 89,735 /
23,163 / 74,224 rows, 182 games each — matches handoff §4 exactly. A `--latest` flag
swaps the pin for `main` for the planned July 23 data-refresh check (handoff §3, §6).

## Known issue: shotdetail is missing Toronto Tempo (confirmed 2026-07-18)

`wnba_shotdetail_2026.csv` contains **zero rows for Toronto Tempo** — 14 of 15 teams
only, while `cdn` and `nbastats v2` both have all 15. Confirmed directly against this
repo's own downloaded data in `data/raw/` (not a prior scratch pull). Per
AMENDMENT_01 §2a, `analysis/eda_midseason.Rmd` still formally resolves the
*implication* for feature-building as part of its required coverage check, but the
underlying fact is settled: Toronto's shot geometry for the §5d expected-points layer
must come from `cdn` (`x`/`y` + `area`/`areaDetail`), not `shotdetail`. See `PLAN.md`.

## Run instructions

To be completed as scripts land. Planned invocation pattern (R 4.3.1 is not on PATH):

```powershell
& "C:\Program Files\R\R-4.3.1\bin\Rscript.exe" R\01_download.R
```

## Repo structure

See `HANDOFF_wnba_deadline_framework.md` §7 for the full script-by-script spec, and
`AMENDMENT_01_trajectory_workflow_agents.md` for what changed:

```
.claude/agents/          # analytics-reviewer, gm-agent, coach-agent (review gates)
analysis/
  case_study_template.Rmd  # Synergy-quarantined case-study stub
  eda_midseason.Rmd        # new EDA gate (AMENDMENT_01 §2a), before R/05
R/01-09_*.R               # numbered pipeline; 06 includes the trajectory extension
tests/testthat/
data/raw/  data/processed/  # gitignored, empty until R/01_download.R runs
output/
```
