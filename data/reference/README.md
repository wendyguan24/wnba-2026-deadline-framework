# data/reference/

Hand-curated, attributed reference data — distinct from `data/raw/` and
`data/processed/` (which are gitignored and machine-generated from the pinned open-PBP
pipeline). Files here are **tracked in git**, not gitignored, because they are small,
manually entered, and their value is the citation trail, not reproducibility from a
script. See `AMENDMENT_02_contracts_cba_cap.md` §3a.

## `cap_context_2026.csv`

One row per WNBA team (15 rows), estimated 2026 salary-cap context. Gathered by hand
by Wendy from Spotrac WNBA team pages and Her Hoop Stats contract data — **not**
scripted scraping (AMENDMENT_02 §4: "an hour of Spotrac/Her Hoop Stats work for 15
team rows, done by Wendy"). Currently a header-only template; rows land in the July 23
work block per `PLAN.md`.

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
