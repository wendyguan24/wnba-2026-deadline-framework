# WNBA 2026 Trade Deadline Framework

Prepared by Wendy Guan (WHoopsLab). Hard deadline: publish July 26-27, 2026 (All-Star
break); decision-relevant only through the August 2 trade deadline.

## Problem statement

> Between the All-Star break (July 23-27) and the trade deadline (August 2, 3:00 p.m.
> ET), every WNBA front office must decide whether their first half reflects a talent
> problem, a process problem, or a luck problem — because those imply opposite
> deadline strategies: acquire, adjust, or hold. Box-score results conflate all three.
> This framework decomposes each team's first-half offense into **schedule-adjusted
> identity** (what they choose to do), **shot generation** (the quality of looks the
> process creates), and **shot making** (whether they convert those looks) — so the
> deadline question "what do we actually need?" is answered from evidence rather than
> record.

Two questions, two rooms:

1. **What do we need?** — front-office question, answered by the open-PBP
   decomposition framework. This is the load-bearing analysis.
2. **Who fits how we play?** — coaching-staff question, triggered only when the
   answer to (1) is "acquire." Answered by Synergy play-type profiles and the
   existing WHoopsLab archetype/synergy-delta machinery. Case-study teams only.

Full spec: [HANDOFF_wnba_deadline_framework.md](HANDOFF_wnba_deadline_framework.md).
Agent operating rules: [CLAUDE.md](CLAUDE.md).

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

`R/01_download.R` (session 2) will resolve the pinned commit against a full commit
hash, download and extract the files, and write `data/raw/download_manifest.txt`
recording the exact commit hash, download timestamp, and per-file row counts — so
every later result states exactly what snapshot it used. A `--latest` flag will swap
the pin for `main` for the planned July 23 data-refresh check (handoff §3, §6).

## Known issue to verify on first download

A prior exploratory pull against this same commit (before this repo's setup pass)
found that `wnba_shotdetail_2026.csv` contains **zero rows for Toronto Tempo** — 14 of
15 teams only, while the primary `cdn` feed has all 15. This has not been re-verified
in this repo's history and must be confirmed by `R/04_reconcile.R` before any
shotdetail-based feature (including the §5d expected-points layer) is trusted for
Toronto. If confirmed, Toronto's shot geometry for that layer should come from `cdn`
(`x`/`y` + `area`/`areaDetail`), not `shotdetail`. See `PLAN.md`.

## Run instructions

To be completed as scripts land. Planned invocation pattern (R 4.3.1 is not on PATH):

```powershell
& "C:\Program Files\R\R-4.3.1\bin\Rscript.exe" R\01_download.R
```

## Repo structure

See `HANDOFF_wnba_deadline_framework.md` §7 for the full script-by-script spec.
