---
type: concept
title: Hit Rate Grading System
created: 2026-05-10
updated: 2026-05-10
tags:
  - contra
  - run-and-gun
  - design-pattern
  - grading
  - score-attack
related:
  - "[[Contra Shattered Soldier]]"
  - "[[Neo Contra]]"
  - "[[Research Run and Gun Innovative Systems]]"
  - "[[Contra Per Entry Mechanic Matrix]]"
  - "[[Modern Difficulty Accessibility]]"
---

# Hit Rate Grading System

Per-stage destruction-percentage grading mechanic introduced in [[Contra Shattered Soldier]] (2002) and carried forward to [[Neo Contra]] (2004). Distinguishes itself from arcade high-score by **gating the true ending behind a rank threshold**.

## Mechanics

| Element | Rule |
|---|---|
| Counter | 0–100% per stage; visible top-center of HUD |
| Source | Each enemy / boss has a defined Hit Rate % yield |
| Excluded | Weak respawning enemies (Zako troops, Buggers) yield 0% — anti-farming |
| Stage end | Player ranked D / C / B / A / S based on hit % + lives lost + objects destroyed |
| Continue penalty | Using a continue drops a letter rank |
| Death penalty | Each death docks extra % off overall score |
| Final reward | Only S-rank (100% Hit Rate run) unlocks **true ending** + unlockables |

## Why It Works (Design)

1. **Skill ladder, not RNG ladder**. Unlike score-attack (where lucky bullet sprays inflate), Hit Rate is a deterministic measure of mastery — every enemy is "must kill or skipped." Anti-farming exclusion of respawners closes the cheese loophole.
2. **Single-life + ladder + ending = compound replay incentive**. Player wants to clear → wants to S-rank → wants true ending. Three rewards stacked on the same input.
3. **Compatible with 1-hit-fairness**. Doesn't change moment-to-moment combat; it's an evaluation overlay.

## Why It Hasn't Been Adopted Outside Konami

Hypothesis (open question): the **gated true ending** reads as punishing in modern accessibility climate ([[Modern Difficulty Accessibility]]). Ranking remains common (Devil May Cry SSS, Bayonetta) but rarely as the primary progression gate.

## Modern Adaptation Pattern

**Ungated grading**: keep the per-stage rank display, but make S-rank unlock cosmetics or challenge runs rather than the canonical ending. This is the modern compromise (see Cuphead expert grading, Hi-Fi Rush S-rank).

## Echo Applicability

Time-rewind synergy: Hit Rate could be **rewinds-conserved-this-stage**. "S-rank: cleared without consuming a single rewind token." Adds skill ceiling without gating story. Defer to Tier 2 evaluation.

## Sources

- https://contra.fandom.com/wiki/Hit_Rate
- https://contra.fandom.com/wiki/Score
- https://en.wikipedia.org/wiki/Contra:_Shattered_Soldier
- https://contrapedia.wordpress.com/contra-shattered-soldier/
