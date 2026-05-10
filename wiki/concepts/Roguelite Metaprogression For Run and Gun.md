---
type: concept
title: Roguelite Metaprogression For Run-and-Gun
created: 2026-05-10
updated: 2026-05-10
tags:
  - run-and-gun
  - roguelite
  - metaprogression
  - cross-genre
  - design-pattern
related:
  - "[[Hard Corps Uprising]]"
  - "[[Contra Operation Galuga]]"
  - "[[Research Cross-Genre Systems For Run and Gun]]"
  - "[[Modern Difficulty Accessibility]]"
---

# Roguelite Metaprogression For Run-and-Gun

Cross-genre transplant: persistent across-run upgrades imported from roguelite (Dead Cells, Risk of Rain 2, Hades) into run-and-gun. Two run-and-gun entries have shipped this — [[Hard Corps Uprising]] (gate model, 2011) and [[Contra Operation Galuga]] (slider model, 2024).

## Roguelite Source Patterns

| Game | Metaprogression Style |
|---|---|
| Rogue Legacy (2013) | Permanent stat upgrades + class unlocks; clear gate model |
| Dead Cells (2018) | Weapon/skill blueprints unlock across runs; player-skill still primary |
| Risk of Rain 2 (2020) | Items unlock to drop pool; in-run build randomness primary |
| Hades (2020) | Boons via Mirror of Night (+% damage / +HP / +cast count) — slider, not gate |

## Run-and-Gun Adaptations

### Hard Corps: Uprising — Gate Model (2011)

- **Rising Mode**: Score → CP → Shop. Permanent character upgrades: HP, weapon-effect speed, maneuver unlocks.
- **Arcade Mode**: shops removed; pure default character.
- **Result**: hardcore Contra fans rejected as a gate (cannot reach later content without grinding upgrades). Mixed reviews.

### Contra: Operation Galuga — Slider Model (2024)

- **Perk Shop**: in-run credits (no microtransactions); 2 equippable perks per run.
- **Examples**: extra HP, longer i-frames, start-with-laser, double-jump unlock.
- **Result**: PC Gamer "new ideas that actually work." 2024 well-received.

## Design Rule (validated by both)

> [!key-insight] Slider, not gate
> **Metaprogression must be a difficulty slider, not a content gate.** A gate (Uprising's HP upgrades required for hard stages) breaks the run-and-gun "fair-but-hard" contract from [[Run and Gun Success Pattern Matrix]]. A slider (Galuga 2-perk equip; Hades % stat) keeps the content equally accessible — player chooses how much help to take.

## Caveats For 1-Hit Run-and-Gun

If permanent HP increases are available, the **1-hit-death contract is broken**. Echo's [[Solo Contra 2026 Concept]] locks 1-hit-with-Easy-toggle as the death model. Therefore any roguelite layer should grant:
- ✅ Cosmetic / visual unlocks
- ✅ Weapon variant unlocks (new behaviors, not strictly stronger)
- ✅ Difficulty modifier toggles
- ❌ Permanent +HP, +damage, +i-frames stacking with player skill

Galuga's Perk Shop walks this line by **per-run** rather than permanent — a viable Echo template.

## Echo Applicability

Tier 2 evaluation candidate. Could replace or complement weapon-pickup variety. Recommend per-run perk shop (Galuga template) over permanent upgrades (Uprising template). Tie perks to **rewind tokens** (e.g., perk: "+1 rewind token at stage start") to integrate with locked time-rewind axis rather than competing with it.

## Sources

- https://en.wikipedia.org/wiki/Hard_Corps:_Uprising
- https://contra.fandom.com/wiki/Hard_Corps:_Uprising
- https://en.wikipedia.org/wiki/Contra:_Operation_Galuga
- https://www.pcgamer.com/games/action/the-new-contra-operation-galuga-crushed-my-skepticism-with-new-ideas-that-actually-work/
- https://rogueranker.com/roguelike-vs-roguelite/
- https://gamerant.com/roguelike-roguelite-games-best-power-creep/
