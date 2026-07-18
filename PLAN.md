# PLAN — WNBA 2026 Trade Deadline Framework

Timeline from `HANDOFF_wnba_deadline_framework.md` §6, as a checklist. Hard deadline:
publish July 26-27, 2026.

## Jul 18-20 — Repo setup, download/parse/possession segmentation, reconciliation tests passing

Setup (this session):
- [x] Directory structure (`R/`, `tests/testthat/`, `data/raw/`, `data/processed/`,
      `analysis/`, `output/`)
- [x] `.gitignore` (data/raw, data/processed, R artifacts, Synergy anything)
- [x] `README.md` (problem statement, two-layer architecture, provenance, known issue)
- [x] Skeleton R scripts 01-09 (`stop("Not yet implemented")` guards, function stubs)
- [x] `tests/testthat/` scaffold — 5 named files, empty-bodied (`skip()`), covering
      tricode mapping, baseline table, cdn-vs-v2 reconciliation, possession
      invariants, clock parsing
- [x] `analysis/case_study_template.Rmd` — Synergy quarantine rule documented
- [x] `PLAN.md` (this file)
- [x] Git initialized, setup committed

Not yet done (next session, implementation):
- [ ] Implement `R/01_download.R`; run deliberately so download date is logged
- [ ] Implement `R/02_parse_pbp.R`
- [ ] Implement `R/03_possessions.R`
- [ ] Implement `R/04_reconcile.R`; get all `tests/testthat/` assertions passing
- [ ] **Gate: show the reconciliation report before proceeding to features**

## Jul 21-22 — Style features, mixed-effects models, BLUPs/ICC
- [ ] Implement `R/05_features.R`
- [ ] Implement `R/06_models.R`
- [ ] Present BLUP/ICC results and raw-vs-adjusted rank deltas

## Jul 23 — Data refresh check; expected-points baseline; deadline-read table
- [ ] Check `shufinskiy/nba_data` for a commit newer than `773ce29`; re-pin and re-run
      01-04 if found, confirm tests still pass; update baseline expectations
      deliberately if counts shift
- [ ] Implement `R/07_expected_points.R` (stratified xPTS baseline, not a trained model)
- [ ] Implement `R/08_deadline_read.R`
- [ ] Present the deadline-read table (the core deliverable)

## Jul 24-25 — Synergy case-study enrichment + fit reads (time-boxed)
- [ ] GSV full case study, Toronto and Portland lighter treatment
- [ ] If not converging by Jul 25, drop and ship diagnosis-only — still a complete piece

## Jul 25-26 — Writing, graphics, methodology notes
- [ ] Implement `R/09_graphics.R`
- [ ] Draft `output/findings.md`

## Jul 26-27 — Publish (repo + writeup + WHoopsLab version)
- [ ] Final review, publish

## Jul 27-Aug 2 — Individual outreach notes, deadline-week engagement
- [ ] Boki Wang (GSV), Eli Horowitz / Lauren Manis / Mark Schindler (Toronto),
      Portland HC contact (Portland). Optional: Todd Whitehead (Synergy courtesy).

---

## Known issues to verify in session 2 (before trusting related outputs)

1. **shotdetail may be missing Toronto Tempo entirely.** A prior exploratory pull
   against commit `773ce29` (before this repo's setup pass, not yet re-verified in
   this repo's history) found `wnba_shotdetail_2026.csv` had 0 rows for Toronto — 14
   of 15 teams. If confirmed by `R/04_reconcile.R`, the `R/07_expected_points.R` shot
   geometry for Toronto must come from `cdn` (`x`/`y` + `area`/`areaDetail`), not
   `shotdetail`. This directly affects whether the Toronto section of the framework
   (an explicit outreach target) can use the expected-points layer at all.
2. **Commit hash resolution.** `773ce29` is a short hash; confirm it resolves
   unambiguously on the live repo when `R/01_download.R` runs (a prior check, not
   re-verified in this repo's history, found it resolves to
   `773ce292bb2cd9bc6ec98d70de95176607ccbaeb`, "add wnba 2026 data (ID 1 to 182)").
3. **§4 baseline table provenance.** The exact filter used for "paint share (of FGM)"
   (e.g. Restricted Area + In The Paint Non-RA, backcourt heaves excluded) is not
   stated in the handoff — `R/04_reconcile.R` should determine empirically which
   definition reproduces the table, and record it.

## Cut list (explicitly out of scope this cycle)

League style map PCA/clustering, lineup/on-off anything, defensive mirrors, trained
xPTS model, possession-value model, Synergy-PBP joins. Post-deadline (September+,
separate decision): trained shot-quality model; possession-value framework timed for
the November hiring window.

## Next session should

Implement `R/01_download.R` through `R/04_reconcile.R` per the plan above, get the
`tests/testthat/` suite green, and stop to present the reconciliation report — per
CLAUDE.md, do not proceed to `R/05_features.R` until that gate is cleared.
