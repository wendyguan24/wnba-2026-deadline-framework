# Fit-first target reads (R/14)

The value screen (R/13) is a filter here, not the driver. Reads shop in order:
need, then attainability (candidate pool is the sellers only), then affordability
(the acquiring team's cap tier), then production tier. Offense-scope only.

Read the following before acting on any row:
- style_match is a COARSE on-style gate (rim / mid / three shares), not a precise
  ranker. It is used only to keep the more on-style half of the pool; do not read
  the second decimal, and note it is not the deadline_read identity descriptor.
- A candidate's shot profile reflects her CURRENT team's system; that it travels
  to a new offense is an assumption, disclosed not modeled.
- Affordability is PENDING until the contract bands are hand-curated (v1 ships with
  them blank). Contract bands and movability are hand-curated, attributed, tiers
  not dollars.
- Movability is NOT yet screened: a top-tier player on an expansion or rebuilding
  seller may not actually be available. Hand-curate the movability flag before use.
- ASSET COST (what the acquiring team sends out) is entirely out of scope here; the
  affordability column is salary tier only. A top-tier candidate at a min band still
  costs real assets.
- Rim-heavy sellers (centers) may be absent from perimeter teams' on-style lists by
  construction; that is the style gate working, not a data gap.
- Production tiers are the offense-weighted, half-season box screen from R/13; small
  samples are flagged by the games count on each line.

Candidate pool (sellers): CHI, CON, LAS, PDX, PHX, SEA.

## DAL (buyer -- amplify)

Recommendation: amplify: extend the edge -- add on-style depth, protect the shot hierarchy

On-style depth that protects the shot hierarchy:

- Ogwumike (LAS, top, 22 g / 695 min) -- rim 31 / mid 39 / three 30; on-style 1.0; band: hand-curate; movability: hand-curate
- Plum (LAS, top, 12 g / 414 min) -- rim 24 / mid 32 / three 43; on-style 0.9; band: hand-curate; movability: hand-curate
- Leite (PDX, top, 23 g / 586 min) -- rim 35 / mid 45 / three 20; on-style 0.9; band: hand-curate; movability: hand-curate
- Hiedeman (SEA, upper rotation, 26 g / 756 min) -- rim 16 / mid 38 / three 46; on-style 0.9; band: hand-curate; movability: hand-curate
- Copper (PHX, upper rotation, 24 g / 777 min) -- rim 28 / mid 33 / three 39; on-style 0.9; band: hand-curate; movability: hand-curate

## GSV (buyer -- amplify)

Recommendation: amplify: extend the edge -- add on-style depth, protect the shot hierarchy

On-style depth that protects the shot hierarchy:

- Plum (LAS, top, 12 g / 414 min) -- rim 24 / mid 32 / three 43; on-style 1.0; band: hand-curate; movability: hand-curate
- Hiedeman (SEA, upper rotation, 26 g / 756 min) -- rim 16 / mid 38 / three 46; on-style 0.9; band: hand-curate; movability: hand-curate
- Copper (PHX, upper rotation, 24 g / 777 min) -- rim 28 / mid 33 / three 39; on-style 0.9; band: hand-curate; movability: hand-curate
- Engstler (PDX, rotation, 25 g / 596 min) -- rim 34 / mid 27 / three 40; on-style 0.9; band: hand-curate; movability: hand-curate
- Johnson (SEA, rotation, 26 g / 740 min) -- rim 32 / mid 31 / three 38; on-style 0.9; band: hand-curate; movability: hand-curate

## MIN (buyer -- amplify)

Recommendation: amplify: extend the edge -- add on-style depth, protect the shot hierarchy

On-style depth that protects the shot hierarchy:

- Ogwumike (LAS, top, 22 g / 695 min) -- rim 31 / mid 39 / three 30; on-style 1.0; band: hand-curate; movability: hand-curate
- Plum (LAS, top, 12 g / 414 min) -- rim 24 / mid 32 / three 43; on-style 0.9; band: hand-curate; movability: hand-curate
- Leite (PDX, top, 23 g / 586 min) -- rim 35 / mid 45 / three 20; on-style 0.9; band: hand-curate; movability: hand-curate
- Copper (PHX, upper rotation, 24 g / 777 min) -- rim 28 / mid 33 / three 39; on-style 0.9; band: hand-curate; movability: hand-curate
- Diggins (CHI, upper rotation, 19 g / 553 min) -- rim 27 / mid 42 / three 31; on-style 0.9; band: hand-curate; movability: hand-curate

## TOR (bubble -- buy-judgment)

Recommendation: judgment (lean buy): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)

Tentative (bubble lean-buy): pursue only if the deal is clearly on-style and affordable.

- Ogwumike (LAS, top, 22 g / 695 min) -- rim 31 / mid 39 / three 30; on-style 0.9; band: hand-curate; movability: hand-curate
- Plum (LAS, top, 12 g / 414 min) -- rim 24 / mid 32 / three 43; on-style 0.9; band: hand-curate; movability: hand-curate
- Gustafson (PDX, upper rotation, 24 g / 549 min) -- rim 45 / mid 20 / three 36; on-style 0.9; band: hand-curate; movability: hand-curate
- Copper (PHX, upper rotation, 24 g / 777 min) -- rim 28 / mid 33 / three 39; on-style 0.9; band: hand-curate; movability: hand-curate
- Taylor (CHI, upper rotation, 22 g / 420 min) -- rim 28 / mid 18 / three 54; on-style 0.9; band: hand-curate; movability: hand-curate

## IND (buyer -- adjust)

Recommendation: adjust: offense is roughly league-average -- tune, not a splash; offense is not the primary lever

Low-priority depth only: offense is roughly league-average and is not the primary lever.

- Gustafson (PDX, upper rotation, 24 g / 549 min) -- rim 45 / mid 20 / three 36; on-style 0.9; band: hand-curate; movability: hand-curate
- Copper (PHX, upper rotation, 24 g / 777 min) -- rim 28 / mid 33 / three 39; on-style 0.9; band: hand-curate; movability: hand-curate
- Morrow (CON, upper rotation, 17 g / 386 min) -- rim 45 / mid 24 / three 31; on-style 0.9; band: hand-curate; movability: hand-curate
- Engstler (PDX, rotation, 25 g / 596 min) -- rim 34 / mid 27 / three 40; on-style 1.0; band: hand-curate; movability: hand-curate
- Johnson (SEA, rotation, 26 g / 740 min) -- rim 32 / mid 31 / three 38; on-style 1.0; band: hand-curate; movability: hand-curate

## ATL (bubble -- hold-judgment)

Recommendation: judgment (lean hold or sell): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)

No target list: the World Cup break favors hold-and-reassess unless the trajectory is clearly improving.

## NYL (bubble -- hold-judgment)

Recommendation: judgment (lean hold or sell): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)

No target list: the World Cup break favors hold-and-reassess unless the trajectory is clearly improving.

## WAS (bubble -- hold-judgment)

Recommendation: judgment (lean hold or sell): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving

No target list: the World Cup break favors hold-and-reassess unless the trajectory is clearly improving.

## LVA (buyer -- reassess)

Recommendation: reassess: bottom-tier shot generation propped up by top-tier but declining making -- address the shot diet / identity before spending an asset on a new piece (trajectory directional)

No target list: address the shot diet / identity before spending an asset.

## CHI (seller -- seller)

Recommendation: sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy

No target list: seller. This team is a source of candidates, not a buyer.

## CON (seller -- seller)

Recommendation: sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy

No target list: seller. This team is a source of candidates, not a buyer.

## LAS (seller -- seller)

Recommendation: sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy

No target list: seller. This team is a source of candidates, not a buyer.

## PDX (seller -- seller)

Recommendation: sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy

No target list: seller. This team is a source of candidates, not a buyer.

## PHX (seller -- seller)

Recommendation: sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy

No target list: seller. This team is a source of candidates, not a buyer.

## SEA (seller -- seller)

Recommendation: sell / accumulate: out of the race -- deal expirings and prioritize asset value over a deadline buy

No target list: seller. This team is a source of candidates, not a buyer.

