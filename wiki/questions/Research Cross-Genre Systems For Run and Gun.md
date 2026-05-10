---
type: synthesis
title: "Research: Cross-Genre Systems For Run-and-Gun"
created: 2026-05-10
updated: 2026-05-10
tags:
  - research
  - run-and-gun
  - cross-genre
  - mechanic-transplant
status: developing
related:
  - "[[Time Manipulation Run and Gun]]"
  - "[[Roguelite Metaprogression For Run and Gun]]"
  - "[[Stealth Information Visualization]]"
  - "[[Solo Contra 2026 Concept]]"
  - "[[Echo Story Spine]]"
  - "[[Katana Zero]]"
  - "[[Cuphead]]"
sources:
  - "[[Wikipedia Run and Gun]]"
---

# Research: Cross-Genre Systems For Run-and-Gun

## Overview

Five systems originated outside run-and-gun, were validated commercially in their home genres, and have been transplanted (partially or fully) into run-and-gun-adjacent action games. Each has a known integration cost and a known payoff. Echo's design space evaluates these against the existing time-rewind anchor (Source: [[Solo Contra 2026 Concept]]).

## Key Findings (5 Transplant Candidates)

### 1. Time Manipulation (Puzzle/Platformer → Run-and-Gun)
- **Source genre**: cinematic platformer ([Prince of Persia: Sands of Time, 2003], [Braid, 2008]). PoP introduced **dagger-of-time rewind** (15s, recharge); Braid extended to **unlimited rewind as core puzzle verb** (Source: https://tvtropes.org/pmwiki/pmwiki.php/Main/TimeRewindMechanic).
- **Run-and-gun transplant**: [[Katana Zero]] (2019, Askiisoft) ported the mechanic — Chronos drug grants **slow-mo precognition + auto-rewind on death**. The level-rewind-on-death is *narratively justified* as Zero's time power (https://en.wikipedia.org/wiki/Katana_Zero).
- **Implementation cost (medium)**: state-snapshot per N frames + delta deltas; Braid takes a full snapshot every few seconds with bit-packed deltas between (Source: https://gamedevelopment.tutsplus.com/tutorials/how-to-build-a-prince-of-persia-style-time-rewind-system-part-1--cms-26090).
- **Confidence**: high (Katana Zero is a published, profitable proof — see [[Indie Self Publishing Run and Gun]]).

### 2. Roguelite Metaprogression (Roguelite → Run-and-Gun)
- **Source genre**: roguelite ([Dead Cells, 2018], [Risk of Rain 2, 2020], [Hades, 2020]). Permadeath + procedural levels + **persistent unlocks across runs** (Source: https://rogueranker.com/roguelike-vs-roguelite/).
- **Run-and-gun transplant**: [[Hard Corps Uprising]] Rising Mode (2011) — Score → CP → permanent HP / weapon-speed / maneuver upgrades — was the first run-and-gun roguelite-lite. [[Contra Operation Galuga]] Perk Shop (2024) is the modern lighter form (in-run credits, two equip slots, no permanent player power) (Source: [[Roguelite Metaprogression For Run and Gun]]).
- **Design caveat**: "metaprogression must be a difficulty slider, not a gate" (resetera consensus). Permanent power-ups break Contra's 1-hit-fairness contract.

### 3. Reactive Narrative (Roguelite Storytelling → Action Games)
- **Source**: [[Hades]] (Supergiant 2020). Branching dialogue keyed to run-state — every death rewinds to the hub and **NPCs comment on what happened in the prior run**. Built on Pyre's branching-dialog tech (Source: https://www.gamedeveloper.com/design/how-supergiant-weaves-narrative-rewards-into-i-hades-i-cycle-of-perpetual-death).
- **Run-and-gun transplant potential**: Echo's Tier 3 vision — VEIL probability-of-success commentary that updates per failed run could be reactive narrative ([[Echo Story Spine]] open question).
- **Cost**: very high (massive dialogue authoring); Hades shipped 800k+ lines (Greg Kasavin GDC). Tier 1/2 budget cannot afford this.

### 4. Bullet-Time / Slow-Motion (Action Shooter → Run-and-Gun)
- **Source**: [[Max Payne]] (Remedy 2001) — Adrenaline-resource-bound slow-mo with player retains aim + fire rates. Distinct from Chronos because Max Payne **is not** a death-rewind; it's slow-mo aim assist (Source: https://en.wikipedia.org/wiki/Bullet_time).
- **2D adaptations**: [[Hotline Miami]] uses no slow-mo (instant restart instead); [[Katana Zero]] uses Chronos slow-mo + rewind, hybridizing both. Pure 2D bullet-time without rewind is **rare** — open question why.
- **Note**: Echo's time-rewind is *closer to Chronos hybrid* than Max-Payne pure-slow.

### 5. Stealth Information Visualization (Stealth → Action)
- **Source**: [[Mark of the Ninja]] (Klei 2012) introduced **explicit visual indicators** for enemy senses — pulsing yellow vision cones, blue noise circles, **binary stealth state** (hidden xor illuminated, no analog "light gem") (Source: https://www.gamedeveloper.com/design/-i-mark-of-the-ninja-i-s-five-stealth-design-rules).
- **Run-and-gun transplant potential**: Echo's time-rewind could borrow the **vision-cone / threat-indicator** layer. When time-rewind is consumed, show **red predicted-bullet trails** to telegraph next-state. Cheap, communicates time mechanic visually.
- **Cost**: low (UI overlay only, no new gameplay system). High payoff for Echo's specific mechanic.

## Key Entities

- [[Katana Zero]] — time-mechanic transplant proof
- [[Hades]] — reactive narrative pinnacle
- [[Hotline Miami]] — instant-restart-as-feedback-loop adjacent
- [[Cuphead]] — already-transplanted parry (run-and-gun native)

## Key Concepts

- [[Time Manipulation Run and Gun]]
- [[Roguelite Metaprogression For Run and Gun]]
- [[Stealth Information Visualization]]
- [[Modern Difficulty Accessibility]] (parent — Easy-toggle pattern)

## Contradictions

- **Metaprogression: gate or slider?** [[Hard Corps Uprising]] used it as a *gate* (Rising Mode purchases mandatory at higher difficulty); [[Hades]] used it as a *slider* (God Mode +2% damage reduction per death). Hades sold 4M+, Uprising sold ~hundreds-of-thousands. Slider model wins commercially.
- **Time mechanic — full vs limited rewind?** Braid (unlimited free) makes puzzles; PoP/Chronos (limited resource) makes combat feel. Echo's solo run-and-gun should follow PoP/Chronos — limited resource preserves stakes; unlimited would erase 1-hit-death tension that's already locked in [[Solo Contra 2026 Concept]].

## Open Questions

- Echo Tier 1: which **one** of these 5 to layer on top of locked time-rewind without overstacking? Recommend: **Stealth-Visualization layer** (cost: low, synergy with time-rewind: very high — show predicted bullet trails). Defer roguelite metaprogression to Tier 2 evaluation; defer reactive narrative to Tier 3 only.
- **Bullet-time pure-2D ablation**: why no successful 2D-only Max-Payne-style shooter without rewind? Likely 2D camera makes slow-mo less spectacle. Verify if [[Hotline Miami]] devs commented.
- Are Mark-of-the-Ninja's binary-stealth-states transferable as a **time-rewind binary state** ("rewinding" / "not rewinding")? Hypothesis: yes, both are about reducing analog ambiguity.

## Sources

- https://tvtropes.org/pmwiki/pmwiki.php/Main/TimeRewindMechanic
- https://gamedevelopment.tutsplus.com/tutorials/how-to-build-a-prince-of-persia-style-time-rewind-system-part-1--cms-26090
- https://en.wikipedia.org/wiki/Katana_Zero
- https://katana-zero.fandom.com/wiki/Chronos
- https://uppercutcrit.com/katana-zero-playing-with-time-to-fix-a-fractured-memory/
- https://rogueranker.com/roguelike-vs-roguelite/
- https://gamerant.com/roguelike-roguelite-games-best-power-creep/
- https://www.gamedeveloper.com/design/how-supergiant-weaves-narrative-rewards-into-i-hades-i-cycle-of-perpetual-death
- https://en.wikipedia.org/wiki/Bullet_time
- https://www.gamedeveloper.com/design/-i-mark-of-the-ninja-i-s-five-stealth-design-rules
- https://www.gamedeveloper.com/design/reinventing-stealth-in-2d-with-i-mark-of-the-ninja-i-
