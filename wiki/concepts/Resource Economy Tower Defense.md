---
type: concept
title: Resource Economy Tower Defense
created: 2026-05-08
updated: 2026-05-08
tags:
  - game-design
  - tower-defense
  - economy
  - lane-defense
status: developing
related:
  - "[[Lane Defense]]"
  - "[[Wave Pacing]]"
  - "[[Meta Progression]]"
  - "[[Plants vs Zombies]]"
sources:
  - "[[Wikipedia Plants vs Zombies]]"
  - "[[Game Developer Tower Defense Rules]]"
confidence: high
---

# Resource Economy Tower Defense

## The Two-Currency Pattern

Most successful lane and tower defense games run a **two-currency economy** (Source: [[Game Developer Tower Defense Rules]]):

1. **In-round currency.** Earned during a single match; spent on placements and upgrades inside that match. Resets at the end. Examples: PvZ **Sun**, Random Dice **SP**, Bloons **Cash**.
2. **Meta currency.** Earned across matches; spent on permanent unlocks and progression outside any single match. Examples: PvZ **Coins**, Random Dice **Gold/Gems**, Bloons **Monkey Money**.

The split exists because the two currencies serve different psychological roles: in-round drives moment-to-moment tension, meta drives session-to-session retention.

## In-Round Currency Generation Patterns

Four generation paradigms (Source: [[Game Developer Tower Defense Rules]]):

1. **Generator-unit** (PvZ Sunflower) — players pay to build economy, trading defense slots for income. Risky-but-scaleable.
2. **Kill-payout** (Bloons Cash) — currency comes from killing enemies. Risk-free if you're already winning, but no investment lever.
3. **Drop-from-the-sky** (PvZ ambient sun in some levels) — passive trickle independent of player action. Sets a floor.
4. **Wave-end bonus** — flat reward each round; encourages survival, not aggression.

A **mixed economy** (e.g., PvZ uses generator + ambient + drops) is the strongest pattern because it gives players an economy choice every round: build generators (slow ramp) vs save drops (faster ramp but capped).

## Sinks That Matter

- **Unit cost tier.** Cheap fast units (50–100 sun) for line-holding; expensive heroes (300–500) for crisis. Without tier separation, the economy is just one number.
- **Upgrades.** In-match upgrade paths (Bloons-style) create meaningful sinks beyond placement.
- **Re-rolls / merges.** Random Dice converts duplicate dice into upgrades via merge. The economy becomes a probability sink: gold → roll → maybe upgrade.

## Meta-Currency Roles

- **Unlock new units.** PvZ uses meta progression to unlock new plants between levels — the new unit is the reward, not the stat.
- **Permanent stat boosts.** Use sparingly. They cause power-creep and force constant rebalancing.
- **Cosmetic.** Safest sink. Doesn't affect balance. Strong on PvP-driven titles.
- **Card / dice copies.** Random Dice and Clash Royale use duplicate-card upgrade systems — meta currency buys card copies, copies upgrade the card. This is high-retention but the most predatory pattern.

## Economy Failure Modes

- **Single-currency collapse.** If meta and in-round are the same currency, every match feels like grinding meta and the in-round tension dies.
- **Generator dominance.** If the optimal first 5 moves are always "build sunflowers, ignore zombies," the early game is solved and uninteresting — fix by front-loading wave 1 pressure.
- **Pay-to-progress meta.** When meta currency is the only path to viable units, the game stops being a game and becomes a payment funnel. Mobile titles routinely cross this line.

## Numerical Anchors (Reference)

Plants vs. Zombies (single-player baseline):

- Sunflower: 50 sun, +25 sun every ~24s
- Peashooter: 100 sun
- Repeater: 200 sun
- Wall-nut: 50 sun (4000 HP)
- Cherry Bomb: 150 sun (one-shot AoE)

These ratios are widely studied and provide a sanity-check baseline for lane defense unit costing (Source: [[Wikipedia Plants vs Zombies]]).

## Implications For This Project

- Pick the **two-currency split early**. Retrofitting meta currency into a single-currency design is painful.
- Author a **cost spreadsheet** with at least 4 unit tiers (cheap line-holder, mid attacker, mid utility, expensive crisis) and define the time-to-affordable for each on wave 1, 5, 10.
- Avoid permanent stat-boost meta progression in the first version. Cosmetic and unit unlocks scale better.

## Open Questions

- Does an ambient-only economy (no generator units) work in lane defense, or is the generator-unit pattern load-bearing for "interesting decisions"?
- What is the right ratio of meta-currency-per-match to keep daily-session retention without grinding?
