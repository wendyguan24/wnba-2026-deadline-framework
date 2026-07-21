# WNBA 2026 Offensive Generation Gap: Volume + Mix Decomposition

Generated: 2026-07-21 19:09:26 UTC

Each team's generation gap versus the league (generation = volume x mix quality: FGA per 100 possessions, times expected points per shot given shot diet) is split into a VOLUME gap ((team FGA/100 minus league FGA/100) times league mix quality) and a MIX gap (team FGA/100 times the difference between the team's and the league's mix quality), the second attributed by zone with a centered-pps contribution. The two components sum to the team's total generation gap, which reconciles with the team's shot_generation_per100 standing (generation and making percentile shown per team, computed in R/11 via percent_rank of shot_generation_per100 / shot_making_per100, both from 07_expected_points.R). primary_driver names which component (volume, mix, or both when each individually exceeds 0.75 per 100 possessions) accounts for the gap.

fit_read is window-conditioned (standing/window layer, R/12_standing.R): window (buyer/bubble/seller, from each team's game-result record) sets the RECOMMENDATION here; the diagnostic decomposition above it (volume_gap, mix_gap_total, primary_driver, identity_driven) stays record-independent and unchanged by window.

## ATL

- Generation percentile: 100 (making percentile: 0)
- Window: bubble
- Primary driver: both
- Volume gap (per 100 poss): 3.46
- Mix gap, total (per 100 poss): 4.52
- Total gap (per 100 poss): 7.98
- Top mix-gap zones:
  - Above the Break 3: slightly below-mean volume (mix contribution: -0.023)
  - Corner 3: missing efficient looks (mix contribution: -0.015)
- Secondary tune (non-identity): Above the Break 3: slightly below-mean volume (mix contribution: -0.023)
- Fit read: judgment: amplify (extend the edge) -- contested window, weigh trajectory

## CHI

- Generation percentile: 79 (making percentile: 21)
- Window: seller
- Primary driver: mix
- Volume gap (per 100 poss): -0.72
- Mix gap, total (per 100 poss): 2.16
- Total gap (per 100 poss): 1.44
- Top mix-gap zones:
  - no negative-contribution mix zones
- Secondary tune (non-identity): none (no negative, non-identity-driven mix zone)
- Fit read: sell / accumulate (offense diagnosis below is context, not a buy)

## CON

- Generation percentile: 57 (making percentile: 14)
- Window: seller
- Primary driver: volume
- Volume gap (per 100 poss): 0.64
- Mix gap, total (per 100 poss): 0.03
- Total gap (per 100 poss): 0.66
- Secondary tune (non-identity): Corner 3: missing efficient looks (mix contribution: -0.138)
- Fit read: sell / accumulate (offense diagnosis below is context, not a buy)

## DAL

- Generation percentile: 93 (making percentile: 71)
- Window: buyer
- Primary driver: both
- Volume gap (per 100 poss): 6.31
- Mix gap, total (per 100 poss): -2.79
- Total gap (per 100 poss): 3.52
- Top mix-gap zones:
  - Mid-Range: over-reliant on low-value looks (mix contribution: -1.473) (identity-driven: protect)
  - Restricted Area: missing efficient looks (mix contribution: -0.964)
- Secondary tune (non-identity): Restricted Area: missing efficient looks (mix contribution: -0.964)
- Fit read: amplify (extend the edge)

## GSV

- Generation percentile: 71 (making percentile: 50)
- Window: buyer
- Primary driver: both
- Volume gap (per 100 poss): 4.22
- Mix gap, total (per 100 poss): -2.19
- Total gap (per 100 poss): 2.03
- Top mix-gap zones:
  - Restricted Area: missing efficient looks (mix contribution: -1.839) (identity-driven: protect)
  - Above the Break 3: slightly below-mean volume (mix contribution: -0.162) (identity-driven: protect)
- Secondary tune (non-identity): In The Paint (Non-RA): over-reliant on low-value looks (mix contribution: -0.147)
- Fit read: amplify (extend the edge)

## IND

- Generation percentile: 36 (making percentile: 86)
- Window: buyer
- Primary driver: volume
- Volume gap (per 100 poss): -1.64
- Mix gap, total (per 100 poss): 0.67
- Total gap (per 100 poss): -0.98
- Secondary tune (non-identity): Above the Break 3: slightly below-mean volume (mix contribution: -0.056)
- Fit read: offense not the lever (look to defense/other; offense is roughly league-average)

## LAS

- Generation percentile: 43 (making percentile: 64)
- Window: seller
- Primary driver: volume
- Volume gap (per 100 poss): -1.52
- Mix gap, total (per 100 poss): 0.68
- Total gap (per 100 poss): -0.84
- Secondary tune (non-identity): Corner 3: missing efficient looks (mix contribution: -0.052)
- Fit read: sell / accumulate (offense diagnosis below is context, not a buy)

## LVA

- Generation percentile: 7 (making percentile: 100)
- Window: buyer
- Primary driver: mix
- Volume gap (per 100 poss): 0.30
- Mix gap, total (per 100 poss): -3.93
- Total gap (per 100 poss): -3.62
- Top mix-gap zones:
  - Restricted Area: missing efficient looks (mix contribution: -1.717) (identity-driven: protect)
  - Mid-Range: over-reliant on low-value looks (mix contribution: -1.178) (identity-driven: protect)
- Secondary tune (non-identity): In The Paint (Non-RA): over-reliant on low-value looks (mix contribution: -1.101)
- Fit read: reassess: bottom-tier offense but the gap is identity-flagged -- see making/trajectory (the identity may be the problem, not a strength to protect)

## MIN

- Generation percentile: 86 (making percentile: 93)
- Window: buyer
- Primary driver: volume
- Volume gap (per 100 poss): 2.44
- Mix gap, total (per 100 poss): -0.54
- Total gap (per 100 poss): 1.90
- Secondary tune (non-identity): Corner 3: missing efficient looks (mix contribution: -0.023)
- Fit read: amplify (extend the edge)

## NYL

- Generation percentile: 14 (making percentile: 79)
- Window: bubble
- Primary driver: both
- Volume gap (per 100 poss): -3.47
- Mix gap, total (per 100 poss): 0.82
- Total gap (per 100 poss): -2.65
- Top mix-gap zones:
  - Restricted Area: missing efficient looks (mix contribution: -0.274)
  - Above the Break 3: slightly below-mean volume (mix contribution: -0.121) (identity-driven: protect)
- Secondary tune (non-identity): Restricted Area: missing efficient looks (mix contribution: -0.274)
- Fit read: judgment: gap-fill (acquire): Restricted Area -- contested window, weigh trajectory

## PDX

- Generation percentile: 64 (making percentile: 43)
- Window: bubble
- Primary driver: mix
- Volume gap (per 100 poss): -0.40
- Mix gap, total (per 100 poss): 1.05
- Total gap (per 100 poss): 0.64
- Top mix-gap zones:
  - In The Paint (Non-RA): over-reliant on low-value looks (mix contribution: -0.286)
  - Above the Break 3: slightly below-mean volume (mix contribution: -0.085) (identity-driven: protect)
- Secondary tune (non-identity): In The Paint (Non-RA): over-reliant on low-value looks (mix contribution: -0.286)
- Fit read: judgment: offense not the lever (look to defense/other; offense is roughly league-average) -- contested window, weigh trajectory

## PHX

- Generation percentile: 21 (making percentile: 36)
- Window: seller
- Primary driver: both
- Volume gap (per 100 poss): -2.19
- Mix gap, total (per 100 poss): -1.24
- Total gap (per 100 poss): -3.44
- Top mix-gap zones:
  - Restricted Area: missing efficient looks (mix contribution: -0.748)
  - Mid-Range: over-reliant on low-value looks (mix contribution: -0.384)
- Secondary tune (non-identity): Restricted Area: missing efficient looks (mix contribution: -0.748)
- Fit read: sell / accumulate (offense diagnosis below is context, not a buy)

## SEA

- Generation percentile: 29 (making percentile: 29)
- Window: seller
- Primary driver: both
- Volume gap (per 100 poss): -0.95
- Mix gap, total (per 100 poss): -1.53
- Total gap (per 100 poss): -2.48
- Top mix-gap zones:
  - Restricted Area: missing efficient looks (mix contribution: -0.891)
  - In The Paint (Non-RA): over-reliant on low-value looks (mix contribution: -0.533)
- Secondary tune (non-identity): Restricted Area: missing efficient looks (mix contribution: -0.891)
- Fit read: sell / accumulate (offense diagnosis below is context, not a buy)

## TOR

- Generation percentile: 50 (making percentile: 57)
- Window: seller
- Primary driver: volume
- Volume gap (per 100 poss): -1.17
- Mix gap, total (per 100 poss): 0.70
- Total gap (per 100 poss): -0.48
- Secondary tune (non-identity): Mid-Range: over-reliant on low-value looks (mix contribution: -0.049)
- Fit read: sell / accumulate (offense diagnosis below is context, not a buy)

## WAS

- Generation percentile: 0 (making percentile: 7)
- Window: bubble
- Primary driver: both
- Volume gap (per 100 poss): -5.25
- Mix gap, total (per 100 poss): 1.66
- Total gap (per 100 poss): -3.60
- Top mix-gap zones:
  - In The Paint (Non-RA): over-reliant on low-value looks (mix contribution: -0.413)
  - Corner 3: missing efficient looks (mix contribution: -0.021)
- Secondary tune (non-identity): In The Paint (Non-RA): over-reliant on low-value looks (mix contribution: -0.413)
- Fit read: judgment: gap-fill (acquire): In The Paint (Non-RA) -- contested window, weigh trajectory

## Method

Generation = volume (FGA per 100 possessions) x mix quality (expected points per shot given shot diet). Each team's generation gap versus the league is split into a volume gap and a mix gap; the mix gap is then attributed by zone. The two gap components sum to the team's total gap, which reconciles with the team's shot_generation_per100 standing -- this is by construction, not a coincidence, since total_gap is the zone-approximated version of the same generation-versus-league quantity.

fit_read is window-conditioned: a seller's offense diagnosis is context for a rebuild, not a buy signal ("sell / accumulate"); a buyer's diagnosis drives an actual gap-fill, amplify, reassess, or "offense not the lever" call; a bubble team gets a judgment call that names the contested window rather than a flat verdict. Window comes from each team's win-loss record and point differential (R/12_standing.R), never from anything in the offense decomposition above -- it conditions the recommendation, not the diagnosis.

## Caveats

Generation has two drivers: shot volume (FGA per 100 possessions) and shot-mix quality (expected points per shot). This report separates them; a team can generate poorly with a fine shot mix if its volume is low, and vice versa.

The mix component is a zone-level read (the alternative-stratification check found zone-only preserves team generation and making ranks, Spearman 0.98 for generation and 1.00 for making), so zone is a defensible grain.

This reads only the offensive side. The open play-by-play barely sees defense, rebounding value, or playmaking not expressed in shots, so these are offensive-generation gaps, not all roster gaps.

Footnote: Above the Break 3 (about 0.996 points per shot) sits just below the rim-inflated overall mean (about 1.02), so it is tagged low-value only relative to that mean ("slightly below-mean volume" when a team over-weights it); it is a league-average look, not an inefficient one.

Window (buyer/bubble/seller) is a data-driven proxy for a team's competitive standing from game results, not a front-office decision; a real front office overrides it with private information. See output/standing.csv and R/12_standing.R.
