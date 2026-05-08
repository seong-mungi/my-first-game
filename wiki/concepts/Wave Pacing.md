---
type: concept
title: Wave Pacing
created: 2026-05-08
updated: 2026-05-08
tags:
  - game-design
  - tower-defense
  - pacing
  - difficulty
status: developing
related:
  - "[[Lane Defense]]"
  - "[[Resource Economy Tower Defense]]"
  - "[[Dynamic Difficulty Adjustment]]"
sources:
  - "[[A NEAT Approach to Wave Generation]]"
  - "[[Tower Defense Design Guide]]"
confidence: high
---

# Wave Pacing

## Definition

Wave pacing is the design discipline of deciding **what enemies spawn, when, and at what intensity** across a tower-defense or lane-defense match. The forgettable-vs-memorable wave gap is mostly a timing problem, not a content problem (Source: [[Tower Defense Design Guide]]).

## Three Spawn-Timing Archetypes

| Archetype | Pattern | Player demand |
|---|---|---|
| **All-at-once** | Entire wave materializes simultaneously | Crowd control, AoE, split-second prioritization |
| **Staggered** | Enemies arrive at steady intervals | Resource management under sustained pressure |
| **Wave burst** | Group → pause → group → pause | Micro-narrative within a wave; recovery and re-engage |

Most well-paced TD games **mix all three** rather than pick one (Source: [[Tower Defense Design Guide]]).

## Difficulty-Curve Levers

The dominant lever in classic TD scaling is the **HP-to-Gold ratio (powHPG)**: every other variable's effect is largely framed by it (Source: [[A NEAT Approach to Wave Generation]]).

- **Higher powHPG** — early waves harder relative to economy; late game eases.
- **Lower powHPG** — early waves cheap; late waves spike sharply.

A staggering bump can be created with an **enemy count increment** that adds +1 enemy every X waves and then decays back, producing a "this wave was rough, recover, build, hit it again" rhythm.

## Dynamic Difficulty Adjustment (DDA)

Three between-wave scalars are the standard knobs (Source: [[Dynamic Difficulty Adjustment in Tower Defence]]):

1. **Status point** — affects enemy power and HP.
2. **Gold point** — affects player currency generation rate.
3. **Spawn point** — affects how many enemies arrive in a wave.

DDA reads in-game performance metrics (lives lost, fastest kill time, currency banked) and adjusts these scalars between waves. Lane defense complicates DDA: per-lane performance can diverge sharply, so a single global scalar can over/under-correct.

## Pacing Patterns That Work

- **Trickle → Threat → Test.** Three-beat wave: trickle of fodder to bait early commitment, mid-wave threat the early commitment must hold against, end-wave test that punishes naive openers.
- **Boss-as-pause.** A single high-HP boss late in a wave gives the player a long, clear target to kill while micro-pressure relaxes — useful for breath moments.
- **Air-and-ground split.** In lane defense, alternating ground waves with flier-only waves forces deck variety and resists "one tower per lane" optimization.

## Pacing Failure Modes

- **All-mode-1 waves.** Pure all-at-once waves train players to over-build AoE and trivialize everything else.
- **Linear HP scaling without economy scaling.** Fastest path to a difficulty wall — fix by tying gold drops to the same scaling curve.
- **No quiet beats.** Constant spawn pressure denies the player a moment to upgrade or re-think; it feels punishing rather than tense.

## Implications For This Project

- Plan a **wave script DSL** rather than hardcoding spawn lists. Lane defense projects burn weeks if every wave is hand-edited.
- Reserve a **DDA lane bank** that reads per-lane lives lost, not global lives — the signal is much sharper for diagnosing player struggle.
- Author the **first 10 waves by hand**, then move to procedural generation for endless or roguelike runs.

## Open Questions

- How do PvP lane defenses (Random Dice) handle wave pacing when both players see the same wave? — likely shared spawn script with mirrored RNG seed.
- Is procedural wave generation (NEAT-style) a real player win, or does it just produce "average" waves that no one remembers?
