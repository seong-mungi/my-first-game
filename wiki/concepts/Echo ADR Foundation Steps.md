---
type: concept
title: Echo ADR Foundation Steps
tags: [concept, adr, architecture, echo, godot, foundation, pre-coding]
aliases: [Foundation ADR, Core ADR Steps, Echo Foundation ADRs]
cssclasses: []
created: 2026-05-14
updated: 2026-05-14
status: stable
---

# Echo ADR Foundation Steps

The 6 architectural decision records (ADRs) that must be authored **before coding begins** on Echo. These decisions define system ownership boundaries, preventing coupling and making each system independently testable.

> [!key-insight] Why these come first
> Without ownership boundaries, two systems will silently assume they both control the same state. The result is bugs that are impossible to reproduce — because both systems are "right" from their own perspective. These 6 ADRs eliminate that class of bug before any code exists.

---

## The 6 Foundation ADRs

### ADR-F1: Scene Lifecycle and Checkpoint Restart

**Question**: Who owns scene loading, scene transitions, and death-restart?

**Decision scope**:
- Which scene loads at game start
- Where the player respawns after death
- Who stores checkpoint position
- What signals fire before and after a scene transition
- How the 1-second restart constraint is enforced

**Owner**: `SceneManager` singleton
**Analogy**: Stage director — only one entity may call scene changes

**GDD**: `design/gdd/scene-manager.md`

---

### ADR-F2: Cross-System Signal Architecture and Event Ordering

**Question**: How do systems notify each other, and in what order do simultaneous events resolve?

**Decision scope**:
- Signal-based pub/sub pattern (no direct system calls)
- Priority ordering for same-frame conflicts:
  - Player death + boss death same frame
  - Bullet hit + scene transition same frame
  - Time-rewind + damage same frame
- Which signals are authoritative vs. reactive

**Analogy**: School PA system — one broadcast, each room responds independently

**GDD**: `design/gdd/state-machine.md`

---

### ADR-F3: Save and Settings Persistence Boundary

**Question**: What data is saved, and who is allowed to write to disk?

**Decision scope**:

| Data | Tier 1 treatment |
|---|---|
| Volume setting | Session-only (saveable later) |
| Pause-menu temp adjustment | Session-only |
| Time-rewind snapshot | Never saved to file |
| Checkpoint state | Needs designated owner |

- No system may write files without going through the save system
- Settings file and save file are distinct concerns

**Analogy**: Home safe — only designated items in; only the responsible party holds the key

---

### ADR-F4: Input Polling, Pause Handling, and UI Focus Boundary

**Question**: Who reads input, when is pause active, and who holds UI focus?

**Decision scope**:

| Input type | Handler | Tick |
|---|---|---|
| Move / jump / shoot | Gameplay layer | `_physics_process` only |
| Pause button | UI layer exception | Any tick |
| Menu focus | Menu/Pause UI | While menu open |
| HUD | Display only | Never receives focus |

- Pause is blocked during death animation and time-rewind
- Gamepad + keyboard simultaneous input → last-device-wins or explicit priority

**Analogy**: Remote control context — same buttons do different things depending on active context

**GDD**: `design/gdd/input.md`

---

### ADR-F5: Player Entity Composition and Lifecycle State Ownership

**Question**: What are the player's components, and who owns each piece of state?

**Decision scope**:
- Player root node type
- Weapon: attached to player scene or separate?
- Ammo count: owned by weapon component or player root?
- Dying state: owned by StateMachine or PlayerController?
- Time-rewind restore: which values are snapshotted?
- Forbidden writers: systems that must **not** directly set player position/velocity

**Analogy**: Car blueprint — each subsystem exists, but none may freely change the speed value

**GDDs**: `design/gdd/player-movement.md`, `design/gdd/player-shooting.md`

---

### ADR-F6: Damage, HitBox/HurtBox, and Combat Event Ownership

**Question**: Who adjudicates hits and deaths? Who emits combat signals?

**Vocabulary**:
- **HitBox** — attack detection area (what the attack can hit)
- **HurtBox** — receive-hit area (what can be hit)

**Decision scope**:
- Who detects: bullet → enemy contact
- Who detects: enemy attack → player contact
- Who owns one-hit-kill rule
- Same-frame multi-bullet resolution
- Who emits `boss_killed` signal
- VFX/Audio react to damage but **never decide** damage

**Core principle**:
> VFX shows the explosion. Audio plays the hit sound. The Damage system decides whether damage occurred. Authority belongs to exactly one system.

**Analogy**: Sports referee — crowd and lights react, but only the referee awards points

**GDD**: `design/gdd/damage.md`

---

## Sequencing

These 6 ADRs are authored before any GDD implementation work begins. Suggested order matches dependency depth:

```
F2 (signals) → F1 (scene lifecycle, uses signals)
             → F4 (input, uses signals)
             → F5 (player entity, uses signals + input)
             → F6 (damage, uses signals + player)
F3 (save) is parallel — minimal dependencies on F1-F6
```

---

## Status

| ADR | GDD Authored | ADR Status |
|---|---|---|
| F1 — Scene lifecycle | scene-manager.md ✓ | Pending ADR authoring |
| F2 — Signal architecture | state-machine.md ✓ | Pending ADR authoring |
| F3 — Save/settings | (no GDD) | Pending ADR authoring |
| F4 — Input/UI | input.md ✓ | Pending ADR authoring |
| F5 — Player entity | player-movement.md ✓, player-shooting.md ✓ | Pending ADR authoring |
| F6 — Damage/combat | damage.md ✓ | Pending ADR authoring |

---

## Related Pages

- [[ADR Foundation Core Steps Explanation]] — plain-language source document
- [[CCGS 7-Phase Development Pipeline]] — development phase context
- [[Research CCGS Implementation Gap Full Stack]] — implementation gap analysis
