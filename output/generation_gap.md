# WNBA 2026 Offensive Generation Gap by Zone

Generated: 2026-07-21 14:43:49 UTC

Each team's shot-SELECTION quality is decomposed by zone using a per-shot centered-pps contribution: (team share minus league share) times (league pps minus overall mean pps). A negative zone is where a team's shot mix costs it points relative to the league -- the gap. This is the shot-MIX component of generation only. It is a per-shot quantity and deliberately not the same object as shot_generation_per100, which is a per-100-possessions level that also reflects shot volume (FGA per possession); the two are not expected to match. The gap names WHAT a better shot profile would fix; the generation percentile (shown per team, from 07_expected_points.R) sizes the overall need.

## ATL

- Generation percentile: 100
- Fit mode: style-amplify / protect
- Top gap zones:
  - Above the Break 3: over-reliant on low-value looks (contribution: -0.000)
  - Corner 3: missing efficient looks (contribution: -0.000)

## CHI

- Generation percentile: 79
- Fit mode: style-amplify / protect
- Top gap zones:
  - no negative-contribution zones

## CON

- Generation percentile: 57
- Fit mode: style-amplify / protect
- Top gap zones:
  - Mid-Range: over-reliant on low-value looks (contribution: -0.016) (identity-driven: protect)
  - Corner 3: missing efficient looks (contribution: -0.002)

## DAL

- Generation percentile: 93
- Fit mode: style-amplify / protect
- Top gap zones:
  - Mid-Range: over-reliant on low-value looks (contribution: -0.016) (identity-driven: protect)
  - Restricted Area: missing efficient looks (contribution: -0.011)

## GSV

- Generation percentile: 71
- Fit mode: style-amplify / protect
- Top gap zones:
  - Restricted Area: missing efficient looks (contribution: -0.021) (identity-driven: protect)
  - Above the Break 3: over-reliant on low-value looks (contribution: -0.002) (identity-driven: protect)

## IND

- Generation percentile: 36
- Fit mode: style-amplify / protect
- Top gap zones:
  - Above the Break 3: over-reliant on low-value looks (contribution: -0.001)
  - Corner 3: missing efficient looks (contribution: -0.000)

## LAS

- Generation percentile: 43
- Fit mode: style-amplify / protect
- Top gap zones:
  - Corner 3: missing efficient looks (contribution: -0.001)
  - Above the Break 3: over-reliant on low-value looks (contribution: -0.001)

## LVA

- Generation percentile: 7
- Fit mode: style-amplify / protect
- Top gap zones:
  - Restricted Area: missing efficient looks (contribution: -0.021) (identity-driven: protect)
  - Mid-Range: over-reliant on low-value looks (contribution: -0.014) (identity-driven: protect)

## MIN

- Generation percentile: 86
- Fit mode: style-amplify / protect
- Top gap zones:
  - Mid-Range: over-reliant on low-value looks (contribution: -0.018) (identity-driven: protect)
  - Corner 3: missing efficient looks (contribution: -0.000)

## NYL

- Generation percentile: 14
- Fit mode: gap-fill
- Top gap zones:
  - Restricted Area: missing efficient looks (contribution: -0.003)
  - Above the Break 3: over-reliant on low-value looks (contribution: -0.002) (identity-driven: protect)

## PDX

- Generation percentile: 64
- Fit mode: style-amplify / protect
- Top gap zones:
  - In The Paint (Non-RA): over-reliant on low-value looks (contribution: -0.003)
  - Above the Break 3: over-reliant on low-value looks (contribution: -0.001) (identity-driven: protect)

## PHX

- Generation percentile: 21
- Fit mode: gap-fill
- Top gap zones:
  - Restricted Area: missing efficient looks (contribution: -0.009)
  - Mid-Range: over-reliant on low-value looks (contribution: -0.005)

## SEA

- Generation percentile: 29
- Fit mode: gap-fill
- Top gap zones:
  - Restricted Area: missing efficient looks (contribution: -0.011)
  - In The Paint (Non-RA): over-reliant on low-value looks (contribution: -0.006)

## TOR

- Generation percentile: 50
- Fit mode: style-amplify / protect
- Top gap zones:
  - Mid-Range: over-reliant on low-value looks (contribution: -0.001)
  - Above the Break 3: over-reliant on low-value looks (contribution: -0.001)

## WAS

- Generation percentile: 0
- Fit mode: gap-fill
- Top gap zones:
  - In The Paint (Non-RA): over-reliant on low-value looks (contribution: -0.005)
  - Corner 3: missing efficient looks (contribution: -0.000)

## Caveats

This is a zone-level read: the alternative-stratification check found zone-only preserves team generation and making ranks (Spearman 0.98), so zone is a defensible grain, but a finer zone x context read would show transition vs halfcourt gaps.

This reads only the offensive shot-diet side. The open play-by-play barely sees defense, rebounding value, or playmaking not expressed in shots, so these are offensive-generation gaps, not all roster gaps.
