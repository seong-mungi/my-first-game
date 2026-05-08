---
type: source
source_type: industry article
title: "Tower Defense Game Rules (Part 1)"
author: gamedeveloper.com (industry publication)
date_published: pre-2026 (exact date not retrieved)
date_accessed: 2026-05-08
url: https://www.gamedeveloper.com/design/tower-defense-game-rules-part-1-
confidence: high
key_claims:
  - Three primary loss conditions (enemy passage, direct combat, resource theft)
  - Four placement paradigms (roadside, fixed, player-generated paths, grid-based combat)
  - Revenue flows: enemy elimination, resource collection, obstacle destruction, early-wave bonus
  - PvZ exemplifies grid-based combat paradigm; Kingdom Rush exemplifies fixed positions
related:
  - "[[Grid Placement System]]"
  - "[[Resource Economy Tower Defense]]"
  - "[[Lane Defense]]"
tags:
  - source
  - reference
  - tower-defense
  - game-design
---

# Game Developer: Tower Defense Game Rules (Part 1)

## Summary

A formal taxonomy of tower defense rules from the gamedeveloper.com industry archive. Categorizes the genre by **win/loss condition**, **map layout**, **economic system**, **hero integration**, and **flying unit handling**. Useful as a checklist when designing a new TD-genre title.

## What It Contributes

### Loss Condition Taxonomy

1. **Enemy Passage** — letting enemies past the goal reduces HP. The dominant pattern. PvZ uses this (zombies eat the lawn-mower / reach the house).
2. **Direct Combat** — enemies attack a structure that has its own HP. Less common.
3. **Resource Theft** — enemies grab an objective and try to escape. Players must intercept *outbound*. Inverse of normal TD.

### Placement Paradigm Taxonomy (most useful piece)

| Paradigm | Description | Example |
|---|---|---|
| Roadside | Build adjacent to fixed paths | Bloons TD |
| Fixed | Pre-determined slots | Kingdom Rush |
| Player-generated paths | Towers create the maze | Field Runners |
| Grid-based combat | Cells dual-purpose: place AND traverse | **Plants vs. Zombies** |

This taxonomy is the cleanest framing of "where do towers go" available in the literature.

### Economic System Patterns

- Enemy elimination (kill payouts) — primary
- Resource collection mechanics
- Obstacle destruction bonuses
- Early-wave release bonus (skip the timer for cash)

The **early-release bonus** is an under-used mechanic worth considering for any TD-genre game. Lets aggressive players trade safety for tempo.

## What's Missing

- Exact numerical examples (no formulas, no tuning data)
- The article is "Part 1" — Part 2 may cover advanced systems but was not retrieved here.
- No discussion of PvP balance, which is critical for lane defense PvP titles.

## Notes On Confidence

gamedeveloper.com (formerly Gamasutra) is a respected industry publication. The taxonomy framing is widely-cited in design talks. High confidence on the taxonomy; medium confidence on completeness (the article is only Part 1).

> [!gap] Part 2 of this article was not located during research. Worth a follow-up search.
