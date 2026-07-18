# AMENDMENT 01 — Trajectory Layer, Workflow Hardening, Review Agents

Date: July 18, 2026. Amends `HANDOFF_wnba_deadline_framework.md` (v2). Where this amendment conflicts with the handoff, the amendment wins. Everything else in the handoff stands.

---

## Part 1: Trajectory Layer (new section 5c-bis)

### Rationale
A deadline decision is a bet on trajectory. "Hold" assumes the process is stabilizing or improving; "acquire" assumes the current trend will not close the gap on its own. The framework currently answers "what are we?" The deadline question is "what are we becoming?" Trajectory is therefore a required column in the deadline-read table, not an optional extra.

### Hypotheses registry (write results against these; do not invent hypotheses after seeing results)
- H1: Transition share and transition efficiency increase league-wide as the season progresses (reps hypothesis).
- H2: Chemistry proxies improve with shared reps: assisted rate rises, live-ball turnover rate falls. Expected strongest for the expansion teams (TOR, PDX), which started from zero shared reps.
- H3: GSV's below-average FG% reflects shot making below expectation on an acceptable shot diet, not a generation problem. (Carried from handoff section 4; the trajectory layer adds: is GSV's making trending toward expectation or flat?)
- H-null discipline: report which hypotheses the data does not support. A published null on H1 is a finding, not a failure.

### Model form
Extend the existing mixed-effects spec with a time term:

```
metric ~ game_index + (1 + game_index | team) + (1 | opponent)
```

- `game_index` = each team's own game number (1..N), not calendar date, so teams with different schedules are comparable.
- Random slopes give each team a schedule-adjusted trajectory; the fixed effect gives the league-wide trend (H1 at scale).
- If random-slope models fail to converge on 23-26 games per team (likely for some metrics), fall back per metric to fixed `game_index` plus random intercepts, and report only the league trend plus observed-minus-expected late-season residuals per team. Document which fallback fired.

### Metric shortlist (trajectory models run on these only)
1. Transition share (H1)
2. Transition points per transition possession (H1, efficiency side)
3. Assisted rate of FGM (H2)
4. Live-ball TOV rate (steals conceded per possession) (H2)
Optional fifth if time allows: shot-making residual (actual minus expected PTS, from script 07) as a trajectory, GSV-relevant (H3).

### Hard boundary carried from guardrails
Isolation trends are NOT measurable in the open data (no play-type tags) and must not be claimed from it. Iso trajectory, if used at all, comes from Synergy date-filtered team exports, appears only in case-study prose for GSV/TOR/PDX, and only if the exports support date splits cleanly within the July 24-25 time box.

### Reporting rules
- Per-team slopes reported with uncertainty intervals; describe individual teams as directional, lean on the league-wide fixed effect for strong claims.
- Sample caveat stated plainly: 23-26 games per team; early-season games double as the left tail of every trend.
- Deadline-read table (handoff 5e) gains one column: `trajectory` with values improving / flat / declining, assigned from the slope sign and interval, with a footnote when the interval spans zero.
- One trajectory graphic maximum (small multiples, adjusted trends, expansion teams highlighted). No rolling-window machinery, no month-by-month split tables.

### Scope cost
Roughly half a day inside the July 21-22 modeling block. If it threatens the block, cut the optional fifth metric first, then H1's efficiency side, never the deadline-read column itself (fall back to raw trends with a stated caveat before dropping the column).

---

## Part 2: Workflow Hardening (senior DS process audit)

Honest audit of the project against a senior data scientist's workflow. What already meets the bar: problem definition with decision-maker and deadline (handoff 1), data audit before commitment (handoff 4), validation gates before modeling (CLAUDE.md standing rules), reproducibility boundary, scope cut list. What is missing, now added:

### 2a. Explicit EDA phase (new, between reconciliation and features)
The current plan jumps from parsing to feature engineering. Insert a dedicated EDA deliverable:

- New file: `analysis/eda_midseason.Rmd`, run after script 04 tests pass and before script 05 is written.
- Required contents: distributions of every planned style metric at the team-game level; missingness and coverage checks (including the Toronto shotdetail zero-row flag from PLAN.md, which is resolved here, not in passing); game-level variance per metric (previews which ICCs will be meaningful); outlier games identified and dispositioned (keep / exclude / flag, e.g. blowouts, OT games); raw trajectory eyeball plots for the Part 1 shortlist before any model runs.
- Output: a short `output/eda_notes.md` logging findings and any spec changes they force. Models are not written until this exists. EDA that changes the plan is the point of EDA.

### 2b. Hypotheses registered before modeling
The Part 1 registry, plus H3, live in `output/eda_notes.md` before script 06 runs. Findings are written against the registry. This is the difference between analysis and curve-fitting, and it is cheap insurance for a public piece.

### 2c. Framework evaluation criteria (how we know the decomposition is right)
Lightweight, deadline-appropriate checks, logged in the methodology notes:
- Face validity: adjusted identity BLUPs should broadly match known team identities (e.g. GSV perimeter-heavy). Surprises are findings only after passing the reconciliation and EDA gates.
- Stability: split-half check on one or two headline metrics (first half of each team's games vs second half); identity metrics should correlate strongly across halves; note where they do not.
- Sensitivity: expected-points decomposition recomputed under one alternative stratification (e.g. zone only vs zone by context); headline generation/making conclusions should survive. If a conclusion flips, report the fragility.
- Garbage-time decision: decide explicitly (include, exclude, or flag possessions with margin above a threshold in Q4) and state it. Do not leave it implicit.

### 2d. Stakeholder review loop
Formalized as agent gates in Part 3. A senior analyst does not ship a decision product without a consumer-side read; the agents simulate that within the solo constraint.

### Updated session flow
1. Setup (done)
2. Scripts 01-04, reconciliation gate
3. **EDA notebook + hypotheses registry (new gate)**
4. Scripts 05-06 including trajectory models; run `analytics-reviewer` agent
5. Scripts 07-08; run `gm-agent` on the deadline-read table
6. Graphics + findings draft; run `coach-agent` on case studies and `analytics-reviewer` on the full draft
7. Case-study integration, final pass, publish

---

## Part 3: Review Agents

Three Claude Code subagents, defined in `.claude/agents/`. Files provided alongside this amendment: `analytics-reviewer.md`, `coach-agent.md`, `gm-agent.md`. Copy them into the repo's `.claude/agents/` directory.

Invocation gates (also mirrored in PLAN.md):
- `analytics-reviewer`: after script 06 results exist; again on the full findings draft.
- `gm-agent`: on the deadline-read table the moment script 08 produces it, before any prose is written around it.
- `coach-agent`: on the case-study sections (GSV, TOR, PDX) once fit reads are drafted.

Usage notes:
- Run agents on artifacts (tables, drafts, model summaries), not on intentions. Give them the file, not a description of the file.
- Agent feedback is triaged, not obeyed: accept, reject with a one-line reason, or defer to post-deadline. Log the triage in PLAN.md. The deadline outranks any single piece of feedback.
- The persona agents (coach, GM) assess usefulness and clarity for their role. The reviewer agent assesses correctness and rigor. Do not let persona agents relitigate methodology; do not let the reviewer relitigate scope.
