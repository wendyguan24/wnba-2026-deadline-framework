# WNBA 2026 Offensive Generation Gap: Volume + Mix Decomposition

Generated: 2026-07-21 15:10:32 UTC

Each team's generation gap versus the league (generation = volume x mix quality: FGA per 100 possessions, times expected points per shot given shot diet) is split into a VOLUME gap ((team FGA/100 minus league FGA/100) times league mix quality) and a MIX gap (team FGA/100 times the difference between the team's and the league's mix quality), the second attributed by zone with a centered-pps contribution. The two components sum to the team's total generation gap, which reconciles with the team's shot_generation_per100 standing (generation percentile shown per team, computed in R/11 via percent_rank of shot_generation_per100, which itself comes from 07_expected_points.R). primary_driver names which component (volume or mix) accounts for more of the gap.

## ATL

- Generation percentile: 100
- Primary driver: mix
- Volume gap (per 100 poss): 3.46
- Mix gap, total (per 100 poss): 4.52
- Total gap (per 100 poss): 7.98
- Top mix-gap zones:
  - Above the Break 3: over-reliant on low-value looks (mix contribution: -0.023)
  - Corner 3: missing efficient looks (mix contribution: -0.015)
- Fit mode: style-amplify / protect

## CHI

- Generation percentile: 79
- Primary driver: mix
- Volume gap (per 100 poss): -0.72
- Mix gap, total (per 100 poss): 2.16
- Total gap (per 100 poss): 1.44
- Top mix-gap zones:
  - no negative-contribution mix zones
- Fit mode: style-amplify / protect

## CON

- Generation percentile: 57
- Primary driver: volume
- Volume gap (per 100 poss): 0.64
- Mix gap, total (per 100 poss): 0.03
- Total gap (per 100 poss): 0.66
- Fit mode: style-amplify / protect

## DAL

- Generation percentile: 93
- Primary driver: volume
- Volume gap (per 100 poss): 6.31
- Mix gap, total (per 100 poss): -2.79
- Total gap (per 100 poss): 3.52
- Fit mode: style-amplify / protect

## GSV

- Generation percentile: 71
- Primary driver: volume
- Volume gap (per 100 poss): 4.22
- Mix gap, total (per 100 poss): -2.19
- Total gap (per 100 poss): 2.03
- Fit mode: style-amplify / protect

## IND

- Generation percentile: 36
- Primary driver: volume
- Volume gap (per 100 poss): -1.64
- Mix gap, total (per 100 poss): 0.67
- Total gap (per 100 poss): -0.98
- Fit mode: style-amplify / protect

## LAS

- Generation percentile: 43
- Primary driver: volume
- Volume gap (per 100 poss): -1.52
- Mix gap, total (per 100 poss): 0.68
- Total gap (per 100 poss): -0.84
- Fit mode: style-amplify / protect

## LVA

- Generation percentile: 7
- Primary driver: mix
- Volume gap (per 100 poss): 0.30
- Mix gap, total (per 100 poss): -3.93
- Total gap (per 100 poss): -3.62
- Top mix-gap zones:
  - Restricted Area: missing efficient looks (mix contribution: -1.717) (identity-driven: protect)
  - Mid-Range: over-reliant on low-value looks (mix contribution: -1.178) (identity-driven: protect)
- Fit mode: style-amplify / protect

## MIN

- Generation percentile: 86
- Primary driver: volume
- Volume gap (per 100 poss): 2.44
- Mix gap, total (per 100 poss): -0.54
- Total gap (per 100 poss): 1.90
- Fit mode: style-amplify / protect

## NYL

- Generation percentile: 14
- Primary driver: volume
- Volume gap (per 100 poss): -3.47
- Mix gap, total (per 100 poss): 0.82
- Total gap (per 100 poss): -2.65
- Fit mode: gap-fill

## PDX

- Generation percentile: 64
- Primary driver: mix
- Volume gap (per 100 poss): -0.40
- Mix gap, total (per 100 poss): 1.05
- Total gap (per 100 poss): 0.64
- Top mix-gap zones:
  - In The Paint (Non-RA): over-reliant on low-value looks (mix contribution: -0.286)
  - Above the Break 3: over-reliant on low-value looks (mix contribution: -0.085) (identity-driven: protect)
- Fit mode: style-amplify / protect

## PHX

- Generation percentile: 21
- Primary driver: volume
- Volume gap (per 100 poss): -2.19
- Mix gap, total (per 100 poss): -1.24
- Total gap (per 100 poss): -3.44
- Fit mode: gap-fill

## SEA

- Generation percentile: 29
- Primary driver: mix
- Volume gap (per 100 poss): -0.95
- Mix gap, total (per 100 poss): -1.53
- Total gap (per 100 poss): -2.48
- Top mix-gap zones:
  - Restricted Area: missing efficient looks (mix contribution: -0.891)
  - In The Paint (Non-RA): over-reliant on low-value looks (mix contribution: -0.533)
- Fit mode: gap-fill

## TOR

- Generation percentile: 50
- Primary driver: volume
- Volume gap (per 100 poss): -1.17
- Mix gap, total (per 100 poss): 0.70
- Total gap (per 100 poss): -0.48
- Fit mode: style-amplify / protect

## WAS

- Generation percentile: 0
- Primary driver: volume
- Volume gap (per 100 poss): -5.25
- Mix gap, total (per 100 poss): 1.66
- Total gap (per 100 poss): -3.60
- Fit mode: gap-fill

## Method

Generation = volume (FGA per 100 possessions) x mix quality (expected points per shot given shot diet). Each team's generation gap versus the league is split into a volume gap and a mix gap; the mix gap is then attributed by zone. The two gap components sum to the team's total gap, which reconciles with the team's shot_generation_per100 standing -- this is by construction, not a coincidence, since total_gap is the zone-approximated version of the same generation-versus-league quantity.

## Caveats

Generation has two drivers: shot volume (FGA per 100 possessions) and shot-mix quality (expected points per shot). This report separates them; a team can generate poorly with a fine shot mix if its volume is low, and vice versa.

The mix component is a zone-level read (the alternative-stratification check found zone-only preserves team generation and making ranks, Spearman 0.98 for generation and 1.00 for making), so zone is a defensible grain.

This reads only the offensive side. The open play-by-play barely sees defense, rebounding value, or playmaking not expressed in shots, so these are offensive-generation gaps, not all roster gaps.

Footnote: Above the Break 3 (about 0.996 points per shot) sits just below the rim-inflated overall mean (about 1.02), so it is tagged low-value only relative to that mean; it is a league-average look, not an inefficient one.
