---
type: concept
title: Time Manipulation in Run-and-Gun
created: 2026-05-10
updated: 2026-05-10
tags:
  - run-and-gun
  - time-rewind
  - cross-genre
  - design-pattern
  - katana-zero
  - braid
related:
  - "[[Katana Zero]]"
  - "[[Solo Contra 2026 Concept]]"
  - "[[Echo Story Spine]]"
  - "[[Research Cross-Genre Systems For Run and Gun]]"
---

# Time Manipulation in Run-and-Gun

Cross-genre transplant: time-rewind, slow-motion, and time-loop mechanics imported from puzzle / cinematic-platformer / action-shooter sources into run-and-gun. Echo's locked differentiating axis (Source: [[Solo Contra 2026 Concept]]).

## Three Source Mechanics

### A. Resource-Bounded Rewind (Prince of Persia: Sands of Time, 2003)
- Dagger of Time stores sand; ~15 seconds of rewindable time per discharge.
- Recharge requires sand pickups from defeated enemies.
- Used to **undo death** + scout traps + reposition.
- Implementation: state-snapshot per N frames + delta deltas; bit-packed.

### B. Unlimited Rewind (Braid, 2008)
- No resource — rewind is free, infinite, instant.
- Designed for puzzle, not combat: rewinding a wrong jump or missed key is the core verb.
- Implementation: full snapshot every few seconds + per-object deltas in between (Jonathan Blow's published technique).
- **Combat impact**: would erase tension if applied to run-and-gun (no permanent loss).

### C. Slow-Mo + Death Rewind (Katana Zero, 2019)
- Chronos drug: limited slow-mo meter (refills) + auto-rewind on player death (level resets, narrative says "you tried again").
- Hybridizes A (resource) + B (free death rewind) + adds **dialogue-rewind** as narrative beat.
- Implementation: time-scale multiplier in slow-mo; full level reset on death (no per-frame rewind needed).

## Run-and-Gun Integration Tradeoffs

| Model | Combat tension | Implementation cost | Echo fit |
|---|---|---|---|
| PoP resource | High (limited) | Medium (snapshot+delta) | **Best** — preserves 1-hit-death stakes |
| Braid unlimited | Low (infinite) | High (full snapshot) | Worst — erases tension |
| Katana Zero hybrid | High (auto on death) | Low (just level reset) | Strong but requires narrative scaffold |

## Echo's Choice (Tier 1 Prototype)

Per [[Solo Contra 2026 Concept]] open questions:
- **Decision target**: PoP-style resource model (token-bounded rewind) for combat moments.
- **Open**: rewind scope — player only (Katana Zero checkpoint model) vs everything-in-screen (Braid model). Verify in 1-week prototype.

## Implementation Patterns (Godot 4.6)

Two viable approaches (per [[Solo Contra 2026 Concept]] open question):

1. **State snapshot**: every N frames, serialize CharacterBody2D position/velocity/state into a ring buffer; rewind = playback in reverse. Memory: ~bytes per entity per frame × buffer length × entity count.
2. **Input replay**: record player inputs only; on rewind, deterministically re-simulate from a stored checkpoint forward to a desired earlier time. Requires deterministic physics; harder with multiple enemies.

Snapshot model is simpler and proven (Braid implementation). Input-replay is leaner but fragile against non-determinism — risky for run-and-gun where many entities + procedural patterns exist.

## Sources

- https://tvtropes.org/pmwiki/pmwiki.php/Main/TimeRewindMechanic
- https://gamedevelopment.tutsplus.com/tutorials/how-to-build-a-prince-of-persia-style-time-rewind-system-part-1--cms-26090
- https://en.wikipedia.org/wiki/Prince_of_Persia:_The_Sands_of_Time
- https://en.wikipedia.org/wiki/Katana_Zero
- https://katana-zero.fandom.com/wiki/Chronos
- https://uppercutcrit.com/katana-zero-playing-with-time-to-fix-a-fractured-memory/
