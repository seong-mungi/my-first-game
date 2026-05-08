---
type: concept
title: Upgrade Path System
created: 2026-05-08
updated: 2026-05-08
tags:
  - game-design
  - tower-defense
  - progression
  - upgrade
status: developing
related:
  - "[[Lane Defense]]"
  - "[[Bloons TD]]"
  - "[[Meta Progression]]"
sources:
  - "[[Bloons Wiki Towers]]"
  - "[[Tower Defense Design Guide]]"
confidence: high
---

# Upgrade Path System

## Definition

In-match progression for individual units: a unit can be upgraded along **branching paths** during the round, each path specializing the unit toward a different role. The pioneering example is **Bloons TD 6**'s three-path × five-tier per-tower system.

## Bloons TD 6 Reference Implementation

(Source: [[Bloons Wiki Towers]])

- Each tower has **3 upgrade paths**.
- Each path has **5 tiers**.
- **Crosspathing rule**: only one path per tower can reach Tier 5. A second path can reach at most Tier 2. The third path is locked at Tier 0 once the first two are committed.
- **Paragon tier**: merging three Tier 5s of the same tower fuses all three paths into a single Paragon unit, with a "Degree" 1–100 quality score derived from total spend, pop count, and tier 5 sacrifices.

The crosspath rule is the load-bearing piece. Without it, every player would max all three paths and the upgrade system would collapse into a stat curve.

## Why Paths Beat Linear Upgrades

| Linear upgrade | Path upgrade |
|---|---|
| One number goes up | Multiple distinct identities |
| Trivial decision | Forces player commitment |
| Predictable balance | Many viable specs |
| Boring late game | Buildcrafting at every tier |

Linear upgrades make units stronger; path upgrades make units **different**. Different is what fills a deck variety bar.

## Path Design Anti-Patterns

- **Three paths, one is always best.** If 90% of players pick path A every match, the system is decorative. Audit pick rates.
- **Top-tier convergence.** Tier 5 abilities of every path do "lots of damage" rather than each owning a distinct role (single-target vs AoE vs utility). Make Tier 5s feel like different units.
- **Cost-doubling with linear power.** If Tier 5 costs 10× Tier 1 and does 10× damage, the upgrade is just a more expensive purchase. Tier 5 should do *qualitatively new things* — pierce armor, ignore camo, spawn sub-towers — not just scale.

## Lane-Defense Compatibility

PvZ does **not** use in-match path upgrades — it uses **plant variety as the upgrade dimension**. Random Dice uses **merge tiers** rather than paths. So path upgrades are not universal in lane defense; they're a TD-genre import.

When to import path upgrades into lane defense:

- **Long matches** (10+ minutes). Path upgrades pay off when there's time to grow into a Tier 4–5 unit.
- **Limited deck size**. PvZ-style 10-plant decks already have variety; piling paths on top creates decision fatigue.
- **Idle / endless modes**. Paths give clear long-term goals during long sessions.

## The Paragon Concept

Paragons (Bloons) are interesting because they:

- Reward investment (need 3× Tier 5s)
- Create a clear "win condition" for late game (pursue Degree 100)
- Sacrifice variety for power (one super-tower replaces three)

Lane defense equivalents could be: a "fully-leveled lane" bonus, or a unit that requires sacrificing 3 mid-tier units of the same type.

## Implications For This Project

- If matches are short (<5 min): use unit *variety*, not path upgrades.
- If matches are long: 2-path × 3-tier is the minimum viable. 3×5 is the gold standard but has a content cost.
- Crosspath constraint is **not optional** — without it, the system collapses.

## Open Questions

- Is there a known "minimum match length" below which path upgrades stop adding value?
- Can path upgrades coexist with merge mechanics (Random Dice) or do they fight for the same design space?
