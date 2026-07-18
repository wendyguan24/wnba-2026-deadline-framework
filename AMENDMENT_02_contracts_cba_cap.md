# AMENDMENT 02 — Contract, CBA, and Salary Cap Layer

Date: July 18, 2026. Amends `HANDOFF_wnba_deadline_framework.md` (v2) and builds on `AMENDMENT_01`. Where this amendment conflicts with either, this amendment wins for contract and cap matters only. Everything else stands.

---

## Part 1: Problem Statement Extension (amends handoff section 1)

The problem statement gains a feasibility clause. Replace the final sentence of the locked problem statement with:

> This framework decomposes each team's first-half offense into schedule-adjusted identity (what they choose to do), shot generation (the quality of looks the process creates), shot making (whether they convert those looks), and trajectory (what they are becoming), then filters the resulting deadline read through cap and contract feasibility, so the deadline question "what do we actually need, and what can we actually do about it?" is answered from evidence rather than record.

Rationale: an "acquire" recommendation without a feasibility check is a wish, not a strategy. The WNBA operates under a hard cap. A team can need a movement shooter and be unable to fit one; a team can hold not because the roster is right but because the cap makes any move impossible. The decision chain in handoff section 1 gains a third question:

3. **Can we do it?** Front-office question, answered by the cap-context layer: cap position, tradeable contracts, and CBA mechanics that constrain the move. This question gates question 2 (who fits): fit reads are only generated for moves that are feasible.

### Why this layer is unusually valuable this specific season
The new seven-year CBA (2026-2032) was ratified March 22, 2026 and took effect this season. **August 2, 2026 is the first trade deadline ever conducted under the new cap regime.** No front office has precedent for deadline behavior under a $7M cap, post-CBA contract structures, or the new roster economics. More than 100 players signed new contracts in the compressed 2026 free agency. A public analysis that reads the deadline through the new CBA's mechanics has no incumbent competition; every published priors-based take is calibrated to a cap environment that no longer exists. This is a differentiation opportunity, and it is also a risk: long-form CBA details were still emerging as of late May 2026, so every mechanic cited must be verified against a current source (Part 3).

---

## Part 2: Verified CBA Facts (July 18, 2026 — re-verify anything load-bearing before publish)

Fact sheet from reporting on the ratified CBA. Sources: WNBA.com official announcement, ESPN long-form CBA reporting (May 2026), Sportico, Swish Appeal, The Athleap. Each item below is safe to cite with attribution; items marked VERIFY need a primary-source check before they anchor a published claim.

- CBA term: seven years, 2026 through 2032, opt-out after 2031. Ratified March 22, 2026.
- 2026 salary cap: $7.0 million per team (up from $1.5M in 2025). Fixed for 2026; from 2027 the cap derives from a designated 20% of Shared Basketball Revenue (league + team revenue from the prior year), so the cap grows with revenue. League projects roughly $11M cap by end of the deal.
- Supermax: $1.4M in 2026 (20% of cap). Regular max: $1.19M (17% of cap). Average salary approximately $583K. Minimum salaries $270K-$300K in 2026 scaled by years of service, rising approximately 4% annually.
- Supermax contracts are ineligible for sign-and-trade; standard max and below are sign-and-trade eligible. Deadline implication: supermax players are structurally stickier assets.
- Core designation functions like a franchise tag: a player can be cored at most twice before her seventh season and is not core-eligible after seven years of service. Deadline implication: pending free agents on contending teams carry different retention risk depending on core eligibility.
- Rookie scale: restructured upward; the 2026 No. 1 pick earns approximately $500K in year one (approximately $2.2M over four years); lottery picks receive protected contracts. VERIFY the protection structure for non-lottery picks before making any claim about a specific rookie's contract security.
- Contract protection (the WNBA's guarantee mechanism): contracts are protected or unprotected, historically negotiable by year. VERIFY current protection rules under the new CBA before characterizing any specific player's contract as guaranteed or not; do not assume 2020-CBA protection norms carried over.
- Roster and trade mechanics under the new CBA (roster size, in-season cap compliance rules for trades, any new trade exceptions): VERIFY before use. The WNBA has historically been a hard-cap league where post-trade rosters must fit under the cap with no NBA-style salary-matching bands; confirm this carried into the new CBA before stating it.
- Calendar facts already in hand: trade deadline August 2, 3:00 p.m. ET; playoff eligibility from waivers August 24; World Cup break August 31 to September 16 (a "hold" this deadline buys a mid-schedule reset window, which changes the hold calculus and should be said in the piece).

---

## Part 3: Scope — What Gets Built (bounded hard; this is the third addition to a nine-day window)

### 3a. Team cap-context table (all 15 teams, small and shallow)
A hand-curated reference file, `data/reference/cap_context_2026.csv`, one row per team: estimated committed salary, estimated cap room, count of expiring contracts, count of supermax/max contracts, and a one-word flexibility tier (room / tight / capped). Sources: Spotrac WNBA team pages and Her Hoop Stats contract data, with a `source` and `as_of_date` column per row. This is reference data, hand-entered with attribution, and is exempt from the pipeline-reproducibility rule but not from the traceability rule: every figure carries its source.

Precision discipline: public WNBA contract data is less complete and less audited than NBA equivalents, and year one of a new CBA is exactly when public trackers lag. Cap figures are presented as approximate tiers, not to-the-dollar claims. The deliverable is the flexibility tier, not the number.

### 3b. Deadline-read table gains two columns (amends handoff 5e and Amendment 01)
- `cap_context`: room / tight / capped, from 3a.
- The `lever` column's decision rule is now conditioned: an acquire read with a capped context becomes "acquire (constrained: requires salary out)" or downgrades to adjust/hold with the constraint stated. The framework must never recommend a move the cap forbids without naming the constraint.

### 3c. Contract typology in fit reads (case-study teams only)
Each named candidate profile in a fit read gains a contract line: years remaining, 2026 salary tier (min / mid / max / supermax), expiring or not, protection status if verifiable, and the resulting asset class:
- Expiring mid-tier contracts: the classic deadline chip, cheapest to acquire, rental risk.
- Multi-year mid-tier: costlier to acquire, keeps the fit beyond September.
- Supermax: effectively immobile at the deadline (sign-and-trade ineligible, cap weight); fit reads should not propose supermax targets.
- Minimum/depth contracts: the feasible move for capped teams; frame accordingly.
Candidate profiles remain profiles (an archetype plus a contract class), not trade proposals. The piece does not propose specific trades; it defines what a feasible, fitting target looks like. This keeps the analysis credible and avoids fake-trade content that front offices dismiss.

### 3d. One structural paragraph in the findings (league-wide)
A short section on what the first post-CBA deadline means structurally: the contract-length distribution after the 2026 free agency rush, what that implies about market liquidity (how many movable expirings exist league-wide), the supermax immobility rule, and the World Cup break as a hold incentive. This is the differentiated angle; it is prose plus one summary count from the cap-context table, not a model.

### Explicitly out of scope (do not build)
- A cap model, trade machine, or salary-matching calculator.
- Player-level contract data beyond case-study rosters and named candidates.
- Multi-year cap projections or 2027 free-agency analysis.
- Any claim about a specific contract's protection status without a source.

---

## Part 4: Execution

### Where it lands in the timeline (amends handoff section 6 and Amendment 01 session flow)
- July 23 block: while building the deadline-read table (script 08), add the two columns; the cap-context CSV is gathered the same day (an hour of Spotrac/Her Hoop Stats work for 15 team rows, done by Wendy, not scripted scraping).
- July 24-25 block: contract typology folded into the fit reads during the existing Synergy case-study window.
- Findings draft: the Part 3d structural paragraph.
- Estimated added cost: half a day total. Updated cut order if time collapses: optional trajectory metric, then Synergy enrichment, then the Part 3d structural paragraph, then contract typology in fit reads. The cap_context column and the feasibility conditioning of the lever call are never cut; they are now part of the core deliverable.

### Agent updates (amends the three agent briefs)
- `gm-agent`: question 5 already asks about market realism; add to its brief: "Verify every acquire read is conditioned on cap context, and flag any cap or CBA mechanic stated without attribution. You know the new CBA took effect this season; punish any reasoning that imports old-CBA intuitions."
- `analytics-reviewer`: add to guardrail compliance: "Cap and contract figures must trace to the cap-context reference file with source and date, or to a cited CBA source. Flag to-the-dollar cap claims; tiers only."
- `coach-agent`: no change; contract mechanics are outside its lane by design.

### Verification checklist before publish (assign to the July 25-26 writing block)
1. Re-check cap figures for the three case-study teams against Spotrac/Her Hoop Stats within 48 hours of publish.
2. Confirm the hard-cap trade-fitting rule under the new CBA from a primary or top-tier source before the structural paragraph states it.
3. Confirm protection/guarantee rules before any candidate's contract security is characterized.
4. Date-stamp the cap-context table in the piece ("cap figures as of July 25, 2026") since deadline-week moves will stale it within days.
