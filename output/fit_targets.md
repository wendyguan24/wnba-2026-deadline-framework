# Fit-first target reads (R/14)

The value screen (R/13) is a filter here, not the driver. Reads shop in order:
need, then attainability (candidate pool is the sellers only), then affordability
(the acquiring team's cap tier), then production tier. Offense-scope only.

Read the following before acting on any row:
- Each line leads with the ADVANTAGE the player would add (production tier + her
  primary shot bucket), i.e. what the acquiring team actually gains, qualified by
  her CREATION PROFILE.
- CREATION PROFILE (on-ball creator / off-ball finisher / combo) is a shot-creation
  profile derived from the share of her made field goals that were assisted (a
  descriptor-derived signal, not a play-type claim). It is what separates a lead
  ball-handler who needs the ball from a movement shooter who plays off one, so two
  players with the same `perimeter shooting` advantage can be different adds. Use it
  to judge DUPLICATION against your own creators; that duplication read is the
  coaching staff's against its incumbent roster, not modeled here.
- POSITION (`pos G/W/F/C`) is hand-curated reference metadata, the same class as the
  contract band: it is NOT in the open play-by-play, so a blank reads `pos:
  hand-curate` until curated from a roster source. The reproducible interior-vs-
  perimeter signal in the meantime is the rim / mid / three profile on each line
  (a stretch big shoots threes, so read profile and position together).
- Movability (hand-curated, from contract designation + judgment) marks each row
  `target` (actionable: gettable and affordable) or `context` (kept for visibility,
  not actionable). `core` and `untouchable` players are KEPT for context, not a
  `target` -- a cored player cannot be approached, but the best on-style fit is still
  worth seeing. `keep` means not core but in the team's plans, so low availability;
  `available` means not core and not long-term, where a team may deal her for value
  before the expansion draft rather than lose her for nothing. A blank (uncurated)
  movability reads `context`, never `target`, until it is hand-curated. A list may
  extend past five names to guarantee at least a few gettable and affordable `target` rows.
- style_match is a COARSE on-style gate (rim / mid / three shares), not a precise
  ranker; do not read the second decimal, and it is not the deadline_read descriptor.
- A candidate's shot profile reflects her CURRENT team's system; that it travels to a
  new offense is an assumption, disclosed not modeled.
- Affordability is shown where a contract band has been hand-curated; a blank band
  reads `band: hand-curate`. Bands and movability are hand-curated, attributed,
  tiers not dollars.
- ASSET COST (what the acquiring team sends out) is out of scope; the affordability
  column is salary tier only. A top-tier candidate at a min band still costs real assets.
- Rim-heavy sellers (centers) may be absent from perimeter teams' on-style lists by
  construction; that is the style gate working, not a data gap.
- Production tiers are the offense-weighted, half-season box screen from R/13; small
  samples are flagged by the games count on each line.

Candidate pool (sellers): CHI, CON, LAS, PDX, PHX, SEA.

## DAL (buyer -- amplify)

Recommendation: amplify: extend the edge -- add on-style depth, protect the shot hierarchy

On-style depth that protects the shot hierarchy:

- Ogwumike (LAS, pos: hand-curate, 22 g / 695 min) -- advantage: top mid-range scoring (off-ball finisher); profile rim 31 / mid 39 / three 30; on-style 1.0; affordable (tight); movability: available; [target] -- SHARED TARGET (targeted by DAL, MIN): one player, not independent adds
- Plum (LAS, pos: hand-curate, 12 g / 414 min) -- advantage: top perimeter shooting (on-ball creator); profile rim 24 / mid 32 / three 43; on-style 0.9; over-tier (tight cannot absorb max); movability: core; [context]
- Leite (PDX, pos: hand-curate, 23 g / 586 min) -- advantage: top mid-range scoring (on-ball creator); profile rim 35 / mid 45 / three 20; on-style 0.9; affordable (tight); movability: hand-curate; [context]
- Hiedeman (SEA, pos: hand-curate, 26 g / 756 min) -- advantage: upper rotation perimeter shooting (combo creator/finisher); profile rim 16 / mid 38 / three 46; on-style 0.9; affordable (tight); movability: available; [target]
- Copper (PHX, pos: hand-curate, 24 g / 777 min) -- advantage: upper rotation perimeter shooting (combo creator/finisher); profile rim 28 / mid 33 / three 39; on-style 0.9; over-tier (tight cannot absorb max); movability: available; [context]
- Diggins (CHI, pos: hand-curate, 19 g / 553 min) -- advantage: upper rotation mid-range scoring (combo creator/finisher); profile rim 27 / mid 42 / three 31; on-style 1.0; affordable (tight); movability: available; [target] -- SHARED TARGET (targeted by DAL, MIN): one player, not independent adds

Offense-only: this list matches shot diet, not defense. The open play-by-play carries no matchup or tracking data, so get your own defensive read (switchability, matchup fit, second-unit hold-up) on any name before acting.

## GSV (buyer -- amplify)

Recommendation: amplify: extend the edge -- add on-style depth, protect the shot hierarchy

On-style depth that protects the shot hierarchy:

- Plum (LAS, pos: hand-curate, 12 g / 414 min) -- advantage: top perimeter shooting (on-ball creator); profile rim 24 / mid 32 / three 43; on-style 1.0; over-tier (capped cannot absorb max); movability: core; [context]
- Hiedeman (SEA, pos: hand-curate, 26 g / 756 min) -- advantage: upper rotation perimeter shooting (combo creator/finisher); profile rim 16 / mid 38 / three 46; on-style 0.9; over-tier (capped cannot absorb mid); movability: available; [context]
- Copper (PHX, pos: hand-curate, 24 g / 777 min) -- advantage: upper rotation perimeter shooting (combo creator/finisher); profile rim 28 / mid 33 / three 39; on-style 0.9; over-tier (capped cannot absorb max); movability: available; [context]
- Engstler (PDX, pos: hand-curate, 25 g / 596 min) -- advantage: rotation perimeter shooting (off-ball finisher); profile rim 34 / mid 27 / three 40; on-style 0.9; affordable (capped); movability: available; [target] -- SHARED TARGET (targeted by GSV, IND, MIN): one player, not independent adds
- Johnson (SEA, pos: hand-curate, 26 g / 740 min) -- advantage: rotation perimeter shooting (combo creator/finisher); profile rim 32 / mid 31 / three 38; on-style 0.9; affordable (capped); movability: hand-curate; [context]
- Burrell (LAS, pos: hand-curate, 23 g / 637 min) -- advantage: rotation perimeter shooting (combo creator/finisher); profile rim 36 / mid 26 / three 38; on-style 0.9; affordable (capped); movability: available; [target] -- SHARED TARGET (targeted by GSV, IND): one player, not independent adds

Offense-only: this list matches shot diet, not defense. The open play-by-play carries no matchup or tracking data, so get your own defensive read (switchability, matchup fit, second-unit hold-up) on any name before acting.

## MIN (buyer -- amplify)

Recommendation: amplify: extend the edge -- add on-style depth, protect the shot hierarchy

On-style depth that protects the shot hierarchy:

- Ogwumike (LAS, pos: hand-curate, 22 g / 695 min) -- advantage: top mid-range scoring (off-ball finisher); profile rim 31 / mid 39 / three 30; on-style 1.0; affordable (tight); movability: available; [target] -- SHARED TARGET (targeted by DAL, MIN): one player, not independent adds
- Plum (LAS, pos: hand-curate, 12 g / 414 min) -- advantage: top perimeter shooting (on-ball creator); profile rim 24 / mid 32 / three 43; on-style 0.9; over-tier (tight cannot absorb max); movability: core; [context]
- Leite (PDX, pos: hand-curate, 23 g / 586 min) -- advantage: top mid-range scoring (on-ball creator); profile rim 35 / mid 45 / three 20; on-style 0.9; affordable (tight); movability: hand-curate; [context]
- Copper (PHX, pos: hand-curate, 24 g / 777 min) -- advantage: upper rotation perimeter shooting (combo creator/finisher); profile rim 28 / mid 33 / three 39; on-style 0.9; over-tier (tight cannot absorb max); movability: available; [context]
- Diggins (CHI, pos: hand-curate, 19 g / 553 min) -- advantage: upper rotation mid-range scoring (combo creator/finisher); profile rim 27 / mid 42 / three 31; on-style 0.9; affordable (tight); movability: available; [target] -- SHARED TARGET (targeted by DAL, MIN): one player, not independent adds
- Engstler (PDX, pos: hand-curate, 25 g / 596 min) -- advantage: rotation perimeter shooting (off-ball finisher); profile rim 34 / mid 27 / three 40; on-style 0.9; affordable (tight); movability: available; [target] -- SHARED TARGET (targeted by GSV, IND, MIN): one player, not independent adds

Offense-only: this list matches shot diet, not defense. The open play-by-play carries no matchup or tracking data, so get your own defensive read (switchability, matchup fit, second-unit hold-up) on any name before acting.

## IND (buyer -- adjust)

Recommendation: adjust: offense is roughly league-average -- tune, not a splash; offense is not the primary lever

Low-priority depth only: offense is roughly league-average and is not the primary lever.

- Gustafson (PDX, pos: hand-curate, 24 g / 549 min) -- advantage: upper rotation rim finishing (off-ball finisher); profile rim 45 / mid 20 / three 36; on-style 0.9; affordable (tight); movability: available; [target]
- Copper (PHX, pos: hand-curate, 24 g / 777 min) -- advantage: upper rotation perimeter shooting (combo creator/finisher); profile rim 28 / mid 33 / three 39; on-style 0.9; over-tier (tight cannot absorb max); movability: available; [context]
- Morrow (CON, pos: hand-curate, 17 g / 386 min) -- advantage: upper rotation rim finishing (combo creator/finisher); profile rim 45 / mid 24 / three 31; on-style 0.9; affordable (tight); movability: hand-curate; [context]
- Engstler (PDX, pos: hand-curate, 25 g / 596 min) -- advantage: rotation perimeter shooting (off-ball finisher); profile rim 34 / mid 27 / three 40; on-style 1.0; affordable (tight); movability: available; [target] -- SHARED TARGET (targeted by GSV, IND, MIN): one player, not independent adds
- Johnson (SEA, pos: hand-curate, 26 g / 740 min) -- advantage: rotation perimeter shooting (combo creator/finisher); profile rim 32 / mid 31 / three 38; on-style 1.0; affordable (tight); movability: hand-curate; [context]
- Burrell (LAS, pos: hand-curate, 23 g / 637 min) -- advantage: rotation perimeter shooting (combo creator/finisher); profile rim 36 / mid 26 / three 38; on-style 1.0; affordable (tight); movability: available; [target] -- SHARED TARGET (targeted by GSV, IND): one player, not independent adds

Offense-only: this list matches shot diet, not defense. The open play-by-play carries no matchup or tracking data, so get your own defensive read (switchability, matchup fit, second-unit hold-up) on any name before acting.

## ATL (bubble -- hold-judgment)

Recommendation: judgment (hold): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)

No target list: the World Cup break favors hold-and-reassess unless the trajectory is clearly improving.

## NYL (bubble -- hold-judgment)

Recommendation: judgment (hold): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)

No target list: the World Cup break favors hold-and-reassess unless the trajectory is clearly improving.

## TOR (bubble -- hold-judgment)

Recommendation: judgment (hold): the late-August World Cup break favors hold-and-reassess unless the trajectory is clearly improving (trajectory directional)

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

