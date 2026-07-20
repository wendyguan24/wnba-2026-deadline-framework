# data/reference/

Hand-curated, attributed reference data — distinct from `data/raw/` and
`data/processed/` (which are gitignored and machine-generated from the pinned open-PBP
pipeline). Files here are **tracked in git**, not gitignored, because they are small,
manually entered, and their value is the citation trail, not reproducibility from a
script. See `AMENDMENT_02_contracts_cba_cap.md` §3a.

## `cap_context_2026.csv`

One row per WNBA team (15 rows), estimated 2026 salary-cap context. Gathered by hand
by Wendy from Spotrac and Her Hoop Stats contract data — **not** scripted scraping
(AMENDMENT_02 §4: "an hour of Spotrac/Her Hoop Stats work for 15 team rows, done by
Wendy").

Populated 2026-07-19: `committed_salary_est`, `cap_room_est`, and `flexibility_tier`
come from the Spotrac WNBA cap tracker (spotrac.com/wnba/cap), captured 2026-07-19.
`expiring_count` and `max_supermax_count` are `NA` for now; they are hand-curated at
the fit-read stage (AMENDMENT_02 §3c), since they need player-level contract detail
this team-level tracker does not carry, and they are not used by R/08's lever
conditioning (which reads `flexibility_tier` only).

### Tier derivation

`flexibility_tier` is a documented, tunable summary of `cap_room_est`, not a hand
verdict. The dollar figures are the source of truth; the tier is derived from them by
this rule:

- `capped`: `cap_room_est` at or below $0 (over the hard cap, must shed salary to
  acquire) — CHI, GSV, LVA.
- `room`: `cap_room_est` at or above $1,000,000 (meaningful space to absorb a
  contract) — PDX, WAS.
- `tight`: everything in between (limited space, roughly salary-matching only) — the
  other ten teams.

The $1M room cutoff sits in the natural gap in the data (WAS at $1.84M, then PHX at
$873K), so no team is near the boundary. The cutoff is the one tunable knob: change it
and re-derive if the room/tight line should move. The $0 capped line is fixed by the
CBA hard-cap rule (a team over the cap cannot add salary without shedding it first;
see `cba_rules_2026.md` §2).

### Columns

| Column | Meaning |
|---|---|
| `team` | tricode, matching the pipeline's 15-team roster (see `R/02_parse_pbp.R` `TEAM_TRICODE_MAP`) |
| `committed_salary_est` | estimated total committed salary, 2026 |
| `cap_room_est` | estimated room under the $7.0M 2026 cap |
| `expiring_count` | count of contracts expiring after 2026 |
| `max_supermax_count` | count of max/supermax contracts on the roster |
| `flexibility_tier` | one of `room` / `tight` / `capped` — **this is the deliverable, not the dollar figures** |
| `source` | e.g. "Spotrac" or "Her Hoop Stats" — required, per row |
| `as_of_date` | ISO date the figure was pulled — required, per row |

### Rules (AMENDMENT_02 §3a, non-negotiable)

- **Tiers, not dollars.** Public WNBA contract data is thinner and less audited than
  NBA equivalents, and year one of a new CBA (ratified March 22, 2026) is exactly when
  public trackers lag. `committed_salary_est` and `cap_room_est` are approximate
  inputs used to *derive* `flexibility_tier` — the tier is what the framework
  publishes and defends, not the to-the-dollar number. Do not present these estimates
  as precise in any downstream prose.
- **Every row needs a source and a date.** This file is exempt from the
  pipeline-reproducibility rule (it isn't scraped, isn't pinned to a commit) but is
  **not** exempt from the traceability rule — every figure must be attributable.
- **No player-level contract data here.** This table is team-level only. Player-level
  contract detail (for named fit-read candidates) lives in the case-study prose
  itself, cited individually — see `AMENDMENT_02_contracts_cba_cap.md` §3c.
- **Re-verify before publish.** Per the AMENDMENT_02 §4 pre-publish checklist,
  re-check figures for the three case-study teams (GSV, Toronto, Portland) within 48
  hours of publish, and date-stamp the table in the published piece.
