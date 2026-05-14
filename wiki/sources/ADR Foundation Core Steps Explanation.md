---
type: source
title: ADR Foundation Core Steps Explanation
tags: [source, adr, architecture, echo, godot, foundation]
aliases: []
cssclasses: []
created: 2026-05-14
updated: 2026-05-14
source_type: internal-document
source_file: .raw/adr-foundation-core-steps-explanation.md
confidence: high
---

# ADR Foundation Core Steps Explanation

Internal document explaining the 6 Foundation/Core ADR steps for the Echo project in plain language. These are the architectural decisions that must be made **before coding begins** — they define responsibility boundaries between systems.

> [!key-insight] Core idea
> These 6 steps are not feature-building work. They are **"traffic-control documents"** — defining who owns what state and who is responsible for each subsystem, so code does not become tangled and testing remains tractable.

---

## Source Summary

| Field | Value |
|---|---|
| Language | Korean (plain-language guide) |
| Scope | 6 pre-coding ADR steps for Echo |
| Purpose | Explain what each ADR decision entails in simple terms |
| Audience | Developer (solo) — quick reference before authoring each ADR |

---

## The 6 Steps at a Glance

| Step | ADR Topic | Core Question |
|---|---|---|
| 1 | Scene lifecycle + checkpoint restart | Who manages scene transitions and death-restart? |
| 2 | Cross-system signal architecture + event ordering | How do systems notify each other without direct coupling? |
| 3 | Save and settings persistence boundary | What gets saved, and who owns the save responsibility? |
| 4 | Input polling, pause handling, UI focus | Who processes input, and when does pause apply? |
| 5 | Player entity composition + lifecycle state ownership | What are the player's components, and who owns each state? |
| 6 | Damage, HitBox/HurtBox, combat event ownership | Who adjudicates hits, deaths, and combat events? |

---

## Step Details

### 1. Scene Lifecycle and Checkpoint Restart Architecture

Defines who is responsible for loading scenes, restarting after death, storing checkpoint positions, emitting pre/post-transition signals, and enforcing the 1-second restart constraint.

**Analogy**: Stage director. Actors, lights, and music must not swap the stage on their own — only the SceneManager may trigger transitions.

**Relevant GDD**: `design/gdd/scene-manager.md`

---

### 2. Cross-System Signal Architecture and Event Ordering

Defines how systems communicate: signal-based (publish/subscribe), not direct calls. Also resolves ordering conflicts when multiple events fire simultaneously:
- Player dies same frame as boss
- Bullet hits same frame as scene transition starts
- Time-rewind and damage fire on the same frame

**Analogy**: School PA system. The teacher broadcasts once; each classroom responds independently.

**Relevant GDD**: `design/gdd/state-machine.md`

---

### 3. Save and Settings Persistence Boundary

Defines what lives in save file vs. settings file vs. session-only memory:
- Volume setting → saveable eventually; session-only in Tier 1
- Time-rewind snapshot → never written to save file
- Checkpoint state → needs designated owner
- Prevents systems from secretly writing files without going through the save system

**Analogy**: Home safe rules. Only designated items go in; only the responsible party holds the key.

---

### 4. Input Polling, Pause Handling, and UI Focus Boundary

Defines when and where each input type is read:
- Gameplay input (move/jump/shoot) → physics tick only
- Pause/menu input → UI layer exception
- Menu button focus → owned by Menu/Pause UI
- HUD → display-only, never receives focus
- Rules for blocking pause during death or time-rewind

**Analogy**: Remote control context. Same buttons move the character during gameplay; same buttons navigate menus when paused. The context must be explicit.

**Relevant GDD**: `design/gdd/input.md`

---

### 5. Player Entity Composition and Lifecycle State Ownership

Defines the player's component architecture and state ownership:
- What is the root node?
- Does the weapon attach to the player scene?
- Who owns the ammo count?
- Who manages the dying state?
- What values does time-rewind restore?
- Which systems are forbidden from directly mutating player position?

**Analogy**: Car blueprint. Engine, steering, brakes, and dashboard each exist — but no component should freely change the speed value.

**Relevant GDDs**: `design/gdd/player-movement.md`, `design/gdd/player-shooting.md`

---

### 6. Damage, HitBox/HurtBox, and Combat Event Ownership

Defines the authority chain for combat:
- **HitBox**: attack detection area (bullet → enemy)
- **HurtBox**: hit-receive area (player/enemy ← attack)
- Who adjudicates: bullet hits enemy, player hit by enemy attack, one-hit-kill rule
- Multiple bullets in same frame → how resolved
- Who emits boss death signal
- VFX/Audio may **react** to damage but must never **decide** damage

**Core principle**: VFX can show an explosion, but it must not determine damage. Audio can play a hit sound, but it must not determine death. The Damage system is the referee.

**Analogy**: Sports referee. The crowd cheers and lights flash, but only the referee (Damage system) awards the point.

**Relevant GDD**: `design/gdd/damage.md`

---

## Relationship to Existing GDDs

These 6 ADR steps define the architectural contracts that the GDDs depend on. Most GDDs reference these boundaries in their Dependencies sections:

| ADR Step | Primary GDD | Dependencies Section |
|---|---|---|
| 1 — Scene lifecycle | scene-manager.md | F.1 upstream |
| 2 — Signal architecture | state-machine.md | F.1 upstream |
| 3 — Save/settings | (no dedicated GDD yet) | Referenced in input.md G tuning |
| 4 — Input/UI | input.md | F.1 upstream |
| 5 — Player entity | player-movement.md, player-shooting.md | F.1 upstream |
| 6 — Damage/combat | damage.md | F.1 upstream |

---

## Related Pages

- [[Echo ADR Foundation Steps]] — concept page with structured 6-step reference
- [[CCGS 7-Phase Development Pipeline]] — broader development pipeline context
- [[Research CCGS Implementation Gap Full Stack]] — implementation gap analysis
