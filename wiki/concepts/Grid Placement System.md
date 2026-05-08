---
type: concept
title: Grid Placement System
created: 2026-05-08
updated: 2026-05-08
tags:
  - game-design
  - level-design
  - tower-defense
  - lane-defense
status: developing
related:
  - "[[Lane Defense]]"
  - "[[Plants vs Zombies]]"
sources:
  - "[[Game Developer Tower Defense Rules]]"
  - "[[Wikipedia Plants vs Zombies]]"
confidence: high
---

# Grid Placement System

## Definition

A grid placement system constrains tower/unit placement to **discrete cells in a fixed grid** rather than free 2D positioning. In lane defense, the grid is typically 5–6 lanes (rows) by 9–10 columns. One unit occupies one cell.

## Four Tower-Defense Placement Paradigms

(Source: [[Game Developer Tower Defense Rules]])

| Paradigm | Description | Example |
|---|---|---|
| **Roadside** | Build only beside predefined paths | Kingdom Rush |
| **Fixed positions** | Predetermined tower slots | Kingdom Rush (mixed) |
| **Player-generated paths** | Towers create the maze; enemies pathfind around | Field Runners, Madness TD |
| **Grid-based combat** | Cells are both tower placement AND enemy movement | Plants vs. Zombies |

Lane defense almost always sits in the fourth paradigm: the grid cell is dual-purpose.

## Grid Design Knobs

- **Grid dimensions.** PvZ: 9 columns × 5 rows (front yard). Adding a row (pool, 6 rows) or shrinking columns (tighter levels) shifts the strategic surface.
- **One-per-cell vs stack.** PvZ enforces one plant per cell except via Lily Pad / Flower Pot terrain modifiers, which create deliberate "two-units-stacked" exceptions.
- **Cell terrain.** Some cells are water (only aquatic units), some are roof (only ballistic units), some have gravestones (zombie spawn-blockers). Terrain creates per-cell placement constraints without changing grid topology.
- **Spawn column.** Enemies always enter at the rightmost column. The leftmost column is the loss line.

## Cognitive Properties

- **Discrete = forgiving.** Players read a grid as a chessboard, not as continuous space. Planning is "what goes in cell (3,2)?" rather than "what arc do I want?"
- **Mistake-bounded.** Misplacing one unit costs one cell, not a strategic chain reaction.
- **Replay-ready.** Identical grid every match makes balance signal clean — designers can isolate variables.

## Spatial Asymmetries Worth Designing

- **Front-row plants.** Cell column 9 (closest to spawn) carries higher defensive stress; column 1 is rarely engaged. Design plant niches around this gradient.
- **Lane-boss cells.** Mark certain cells as "anchor" cells where boss-tier plants are intended. Without explicit anchors, players spread defenses too evenly.
- **Vacant-lane invitation.** Empty cells on a given row signal "this lane is undefended" — the wave generator should *occasionally* exploit this to force lane re-balancing.

## Comparison: Grid vs Free Placement

| Trait | Grid | Free placement |
|---|---|---|
| Strategic depth | Lower per match, higher per game | Higher per match |
| Production cost | Lower (every level uses same template) | Higher (every level needs spatial design) |
| Mobile fit | Excellent | Poor |
| Balance signal | Crisp | Noisy |

## Implications For This Project

- Standardize on **9×5 grid** (PvZ's proven layout) unless there's a specific reason to deviate.
- Build the **grid as data**, not as scene nodes. Lane terrain (water, roof, fog) should be properties of the cell, not separate scenes.
- Reserve **cell metadata** for: terrain type, spawn flags, occupancy, debug overlays.

## Open Questions

- Does adding a 6th lane meaningfully change strategy or just dilute the design? PvZ's pool levels suggest "yes, but only with new unit types."
- Is dynamic grid (shrinking cells over time) ever a good idea, or just chaos?
