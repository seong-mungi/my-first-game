---
type: entity
title: Bloons TD
created: 2026-05-08
updated: 2026-05-08
tags:
  - game
  - tower-defense
  - reference-game
  - upgrade-paths
status: stable
related:
  - "[[Lane Defense]]"
  - "[[Upgrade Path System]]"
sources:
  - "[[Bloons Wiki Towers]]"
  - "[[Bloons TD Wikipedia]]"
confidence: high
---

# Bloons TD

## Identity

- **Developer:** Ninja Kiwi (NZ)
- **Series start:** 2007 (web flash)
- **Current flagship:** Bloons TD 6 (2018), still actively updated 2026
- **Platforms:** PC, mobile, browser
- **Genre:** Path-based tower defense (NOT lane defense)

## Why It's Cited Here

Bloons TD is **path-based** TD, not lane defense — but it's included in this research because:

1. **Upgrade-path design is the reference standard.** BTD6's 3-path × 5-tier per-tower system is the most-studied upgrade taxonomy in the genre and informs lane defense designs that adopt in-match upgrades.
2. **Bloons TD Battles** (the PvP variant) experiments with shared-wave PvP that influenced Random Dice and similar lane defense PvP titles.
3. **Tower class taxonomy** — Primary / Military / Magic / Support — is reusable as a unit-class framework regardless of placement system.

## Tower Class Taxonomy

(Source: [[Bloons Wiki Towers]])

| Class | Role | Examples |
|---|---|---|
| **Primary** | Foundation damage | Dart Monkey, Boomerang Monkey, Bomb Shooter, Tack Shooter, Ice Monkey, Glue Gunner |
| **Military** | High pierce, special targeting, infinite range | Sniper Monkey, Monkey Sub, Monkey Buccaneer, Monkey Ace, Heli Pilot, Mortar Monkey, Dartling Gunner |
| **Magic** | High-damage projectiles, status effects | Wizard Monkey, Super Monkey, Ninja Monkey, Alchemist, Druid |
| **Support** | Buff/debuff, economy, utility | Banana Farm, Spike Factory, Monkey Village, Engineer Monkey |

A 4-class taxonomy is a strong template for any TD-adjacent game. Lane defense designers can map plants/dice/units onto similar buckets to ensure deck variety.

## The Crosspath System

(Source: [[Bloons Wiki Towers]])

- 3 upgrade paths per tower
- 5 tiers per path
- One path can reach Tier 5; one other path can reach Tier 2; third path is locked
- Tier 5 + Tier 2 + Tier 0 is the maximum spec — designed to force commitment

Without crosspathing constraints, upgrade systems collapse. This is the load-bearing rule.

## Paragon Tier

Late-game investment goal: merge three Tier 5 towers of the same type into a single Paragon. Quality measured by "Degree" 1–100, calculated from total spend, pop count, bonus Tier 5s sacrificed, and total upgrade investment.

The Paragon design pattern — "sacrifice multiple maxed units to forge a transcendent unit" — is reusable in any progression system that needs a long-term goal beyond level cap.

## Lessons For This Project

- **3 paths × 5 tiers** is a content-heavy template. Indie projects should consider 2 paths × 3 tiers minimum.
- **Class taxonomy first, units second.** Define the 4–6 unit roles before authoring individual units; ensures deck variety.
- **Crosspath constraint is mandatory** if you adopt path upgrades.
- **Paragon-style late-game goals** are excellent retention drivers; design one even if you don't call it "Paragon."

## Bloons TD Battles (PvP variant)

- Released 2012, succeeded by Battles 2 (2021)
- Both players face identical wave at the same pace
- Win by surviving longer OR by sending bloons to attack the opponent
- The "send bloons" mechanic is unique — it's a single-currency aggression option

This "send aggression" pattern is rare and worth cherry-picking for any PvP lane defense.

## See Also

- [[Upgrade Path System]] for the path-upgrade design pattern
- [[Lane Defense]] for context on why this is *not* lane defense
