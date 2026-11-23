# Execution plan: re-read revision pass (triage approved by Wendy 2026-11-23)

Repo: /home/user/wnba-2026-deadline-framework, branch `claude/exciting-knuth-djz7m1`.
Inputs: `R/15_reread.R`, `R/15b_reread_report.R`, `output/offseason/reread/`, PLAN.md "Scope"
(hypotheses, b0c3c80) and "Review triage log" (2026-11-23 entry), `docs/plans/reread_plan.md`
(the original execution plan, committed now as the audit trail for B1).

## Rules
- No v1 logic changes (R/05-R/07 modeling, defaults). No new hypotheses. Anything not in the
  registry is labeled EXPLORATORY in its own section, never mixed into hypothesis verdicts.
- Outputs only under `output/offseason/reread/`. No em/en dashes, no "--", no smart quotes.
- Every number in reread_results.md and scorecard.md is computed from CSVs/code, not hard-coded.
- Commit with trailer (Co-Authored-By line per the session attribution reminder, plus
  `Claude-Session: https://claude.ai/code/session_01LqKYRNijtLZHhieuyMkmRN`); push to the session
  branch only; no PR.

## Pre-registration framing (B1, B2)
1. Report header: "Hypotheses and predicted directions pre-registered in b0c3c80. Decision rules
   were specified in the execution plan (docs/plans/reread_plan.md) before any second-half output
   was computed, but first committed with the code at cd66cc0." Remove every "pre-registered
   rule" phrasing. Mark A' (point-differential baseline) and the tier scorecard EXPLORATORY.
2. H-R3: both outcomes equal (no primary/secondary). Verdict: "mixed / inconclusive: no gain on
   point differential, negligible gain on win pct (state % RMSE change)".

## Analytic additions (all from existing data)
3. W1: H-R2 exploratory decomposition: Spearman first vs second half (with bootstrap CI, seed
   20261123) for expected points per FGA (diet = expected_pts/fga) and FGA per possession
   (volume = fga/poss_count), next to generation per100 and making per100. One sentence: generation
   per100 combines diet and volume.
4. W2: sensitivity: score both halves with the full-window baseline (build the xpts table on the
   full regular-season window, attach per half, recompute generation/making per100), report the
   H-R2 rhos and difference CI next to the main ones. Write to
   `output/offseason/reread/sensitivity_full_baseline.csv`.
5. W4: H-R3: per-team paired LOO squared-error differences (B minus A), mean and bootstrap 95% CI,
   for both outcomes. State the sign of the making coefficient and the regression-to-the-mean
   reading. Note fh_win_pct coefficient shift (collinearity). Relabel A' "alternative baseline
   (point differential)"; not "stricter".
6. W5 + GM 5/6: scorecard (EXPLORATORY): add v1 and second-half percentiles and percentile change
   per axis; flag `boundary_sensitive` if the team is within one rank of a tier boundary in either
   half on either axis; report held/partly/failed counts as a range under one-rank swaps; chance
   rate for held = 1/9 (expected 1.67 of 15); benchmark row: same tertile rule applied to
   first-half vs second-half win pct (count of teams keeping their record tier).
   Label the scorecard "descriptor stability, not advice outcome".
7. GM 1, 2, 7 (EXPLORATORY section "Advice outcome"): per team: v1 window (buyer/bubble/seller),
   v1 recommendation text, deadline action from player_moves.csv (bought / sold / stood pat:
   net minutes-weighted moves within Jul 20 to Aug 2 inclusive; define and state the rule),
   second-half record, playoff result, advice outcome (right / wrong / not scored). Rules: seller
   right if missed playoffs; buyer right if made playoffs; bubble "lean hold or sell" right if
   second-half win pct < .500, "lean buy" right if >= .500, state that "lean hold or sell" is a
   two-way call; LAS and PHX (roster-turnover flag) not scored. Summary: counts by window.
   Note it is exploratory and the windows come from record plus margin.

## Disclosures and fixes
8. W3: caveat: H-R2 uses raw per100, H-R1 uses schedule-adjusted BLUPs.
9. W6: H-R1: lead with median rho; state the verdict flips if one more metric drops below 0.7.
10. W7: H3 verdict line: "Premise not supported in either half; making near zero throughout;
    playoff -3.40 descriptive."
11. W8: drop diff_generation/diff_making from playoffs_descriptive.csv; add sentence that rs and
    po columns are not on a common baseline.
12. W9: compute all hard-coded report values (R/15b lines ~47, 55, 110, 135, 150).
13. W10: disclose fallback inference limits (anticonservative p-values), mixed interval types in
    the TOR/PDX table, full window overlaps v1 (182 of 330 games); add second_half league trend rows.
14. N1: sign changes with |delta| < 0.01 per100 count as ties, excluded; report n. N2: one line on
    label (within-half slope) vs outcome (level change). N3: rename trade flag to
    "roster-turnover flag". N4: regenerate command points to README run order. N5: write
    `output/offseason/reread/session_info.txt` (sessionInfo, lme4 1.1-35.1 from apt). N7: replace
    "--" in copied v1 text.
15. GM 8: one-line caveats: injuries/availability not controlled; cap feasibility of constrained
    acquire reads not assessed (parked); World Cup break noted.

## Wrap-up
16. Update tests/testthat/test-reread.R for new columns (boundary flag, advice outcome values in
    {right, wrong, not scored}, sensitivity file exists). Full suite 0 failures (v1 player-value skip
    expected).
17. PLAN.md: tick triage items; "Next session should": re-run analytics-reviewer on the revised
    reread_results.md, then write-up (framing per GM 4: description not forecast; headline the null).
    Commit, push, clean tree. Report: key new numbers (W1 rhos, W2 sensitivity, W4 CIs, scorecard
    range + benchmark, advice-outcome counts), commit hash.
