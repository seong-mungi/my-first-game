# Architecture Review Report — 2026-05-14

Date: 2026-05-14
Engine: Godot 4.6 / GDScript
Mode: full
GDDs Reviewed: 20 design sources (`game-concept.md`, `systems-index.md`, 18 MVP GDDs)
ADRs Reviewed: 12 (`ADR-0001` through `ADR-0012`)
Engine References Reviewed: `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, and module notes for animation, audio, input, physics, rendering, and UI.

---

## Executive Summary

The Tier 1 MVP architecture is **ready**: all Foundation/Core/Feature/Presentation technical requirements extracted in the registry have architectural coverage, no blocking cross-ADR conflict was found, and every ADR has a Godot 4.6 engine compatibility section. The previous `TR-audio-001` partial/waived concern is closed by ADR-0012, which explicitly owns AudioManager bus, playback, ducking, UI-bus, and session-volume boundaries.

Loaded 20 GDD/design sources and 12 ADRs. Engine pin confirmed from `.claude/docs/technical-preferences.md`: **Godot 4.6**, PC Steam / Steam Deck-friendly, statically typed GDScript.

---

## Traceability Summary

Total requirements: 46
✅ Covered: 46
⚠️ Partial: 0
❌ Gaps: 0

### Full Traceability Matrix

| Requirement ID | GDD | System | Requirement | ADR Coverage | Status |
|---|---|---|---|---|---|
| TR-concept-001 | game-concept.md | Concept | PC Steam single-player side-scrolling run-and-gun; no co-op. | Architecture principle | ✅ Covered |
| TR-concept-002 | game-concept.md | Concept | One-hit death must convert into sub-second learning/retry loop. | ADR-0001/0002/0004 | ✅ Covered |
| TR-concept-003 | game-concept.md | Concept | Revoke token restores safe pre-death state from 1.5s lookback, 0.15s restore depth. | ADR-0001/0002 | ✅ Covered |
| TR-concept-004 | game-concept.md | Concept | Deterministic patterns; luck must not cause death. | ADR-0003/0005/0011 | ✅ Covered |
| TR-concept-005 | game-concept.md | Concept | Collage visual signature must survive clarity/performance constraints. | ADR-0010 | ✅ Covered |
| TR-sys-001 | systems-index.md | Systems | 18 MVP systems must be operational for Tier 1 prototype. | This document | ✅ Covered |
| TR-sys-002 | systems-index.md | Systems | Foundation → Core → Feature → Presentation dependency ordering. | This document | ✅ Covered |
| TR-sys-003 | systems-index.md | Systems | MVP systems must avoid circular dependencies. | ADR-0005 | ✅ Covered |
| TR-input-001 | input.md | Input | Fixed 9-action catalog for Tier 1. | ADR-0007 | ✅ Covered |
| TR-input-002 | input.md | Input | Gameplay input polling occurs in `_physics_process` only. | ADR-0003/0007 | ✅ Covered |
| TR-input-003 | input.md | Input | Pause/menu callbacks are explicit exceptions, not gameplay logic. | ADR-0007 | ✅ Covered |
| TR-input-004 | input.md | Input | Use `StringName` action constants, not inline action strings. | ADR-0007 | ✅ Covered |
| TR-scene-001 | scene-manager.md | Scene Manager | `SceneManager` owns scene lifecycle, checkpoint restart, stage clear transitions. | ADR-0004 | ✅ Covered |
| TR-scene-002 | scene-manager.md | Scene Manager | `scene_will_change()` emitted exactly once before scene swap. | ADR-0004/0005 | ✅ Covered |
| TR-scene-003 | scene-manager.md | Scene Manager | `scene_post_loaded(anchor, limits)` initializes camera and stage bounds. | ADR-0004 | ✅ Covered |
| TR-scene-004 | scene-manager.md | Scene Manager | Restart path must fit within 60 physics frames. | ADR-0004 | ✅ Covered |
| TR-state-001 | state-machine.md | State Machine | Entity-local `StateMachine` nodes; never Autoload state machines. | ADR-0008 | ✅ Covered |
| TR-state-002 | state-machine.md | State Machine | Cross-entity transitions use signals, never direct foreign SM calls. | ADR-0005 | ✅ Covered |
| TR-state-003 | state-machine.md | State Machine | ECHO lifecycle states ALIVE/DYING/REWINDING/DEAD drive rewind/death flow. | ADR-0008 | ✅ Covered |
| TR-pm-001 | player-movement.md | Player Movement | ECHO root is `CharacterBody2D`, process priority 0. | ADR-0003/0008 | ✅ Covered |
| TR-pm-002 | player-movement.md | Player Movement | Snapshot-visible movement state is restored only through `restore_from_snapshot()`. | ADR-0002/0008 | ✅ Covered |
| TR-pm-003 | player-movement.md | Player Movement | Animation method-track side effects must be guarded during restore. | ADR-0008 | ✅ Covered |
| TR-ps-001 | player-shooting.md | Player Shooting | `WeaponSlot` owns `ammo_count` and is sole writer except snapshot restore path. | ADR-0002/0008 | ✅ Covered |
| TR-ps-002 | player-shooting.md | Player Shooting | `shot_fired(direction)` is the public event for VFX/audio/camera feedback. | ADR-0005 | ✅ Covered |
| TR-damage-001 | damage.md | Damage | Damage owns HitBox/HurtBox contracts and cause taxonomy. | ADR-0009 | ✅ Covered |
| TR-damage-002 | damage.md | Damage | Damage emits lethal/boss/enemy signals in deterministic order. | ADR-0005/0009 | ✅ Covered |
| TR-damage-003 | damage.md | Damage | Damage must not poll SM state; SM controls ECHO HurtBox monitorability. | ADR-0008/0009 | ✅ Covered |
| TR-tr-001 | time-rewind.md | Time Rewind | Capture 90-frame ring buffer at 60 fps. | ADR-0002 | ✅ Covered |
| TR-tr-002 | time-rewind.md | Time Rewind | Player-only rewind scope; enemies/projectiles/environment continue normal simulation. | ADR-0001 | ✅ Covered |
| TR-tr-003 | time-rewind.md | Time Rewind | TRC process priority 1, after PlayerMovement and before Damage/enemies/projectiles. | ADR-0003 | ✅ Covered |
| TR-enemy-001 | enemy-ai.md | Enemy AI | Enemies derive from deterministic `EnemyBase extends CharacterBody2D`. | ADR-0003/0011 | ✅ Covered |
| TR-enemy-002 | enemy-ai.md | Enemy AI | Enemy behavior uses authored/pure frame-based patterns, not random lethal decisions. | ADR-0011 | ✅ Covered |
| TR-boss-001 | boss-pattern.md | Boss Pattern | STRIDER phases are authored deterministic scripts with discrete hit thresholds. | ADR-0011 | ✅ Covered |
| TR-boss-002 | boss-pattern.md | Boss Pattern | Boss owns phase scripts; Damage owns hit/phase signal contract. | ADR-0009/0011 | ✅ Covered |
| TR-stage-001 | stage-encounter.md | Stage | Stage owns room metadata, encounter activation, checkpoint anchors, camera limits. | ADR-0004/0011 | ✅ Covered |
| TR-stage-002 | stage-encounter.md | Stage | Stage owns `Projectiles: Node2D` container presence/lifetime; projectile behavior remains Player Shooting/Damage-owned. | ADR-0011 | ✅ Covered |
| TR-camera-001 | camera.md | Camera | Camera is scene-local, not Autoload; not included in PlayerSnapshot. | ADR-0002/0004/0005/0010 | ✅ Covered |
| TR-camera-002 | camera.md | Camera | Camera consumes scene/damage/weapon/rewind events for snap, limits, freeze, shake. | ADR-0004/0005/0009/0010 | ✅ Covered |
| TR-audio-001 | audio.md | Audio | `AudioManager` owns bus hierarchy and all sound playback; gameplay emits events only. | ADR-0012 | ✅ Covered |
| TR-hud-001 | hud.md | HUD | HUD is observer-only CanvasLayer; never mutates simulation state. | ADR-0005/0007/0009/0010 | ✅ Covered |
| TR-menu-001 | menu-pause.md | Menu/Pause | PauseHandler controls pause lifecycle; Menu UI owns focus/navigation and session-only options. | ADR-0004/0005/0006/0007 | ✅ Covered |
| TR-story-001 | story-intro-text.md | Story Intro | One passive five-line intro; no prompt gate or extra input actions. | ADR-0004/0007 | ✅ Covered |
| TR-vfx-001 | vfx-particle.md | VFX | VFX owns non-HUD visual feedback; no gameplay collision/damage ownership. | ADR-0005/0009/0010 (dedicated ADR waived) | ✅ Covered |
| TR-collage-001 | collage-rendering.md | Collage Rendering | Layered collage pipeline must preserve 0.2s readability and draw/memory budgets. | ADR-0010 | ✅ Covered |
| TR-shader-001 | time-rewind-visual-shader.md | Rewind Shader | Full-viewport rewind signature triggers from rewind lifecycle and remains budget-safe. | ADR-0010 | ✅ Covered |
| TR-persist-001 | systems-index.md | Save/Settings | Save/settings persistence is Vertical Slice and must not be accidentally invented in Tier 1 systems. | ADR-0006 | ✅ Covered |

### Coverage Gaps (no ADR exists)

None. No new ADR is required before the next Technical Setup gate rerun.

### Partial / Waived Coverage

None. `TR-audio-001` is fully covered by ADR-0012. Story/test evidence must still verify bus setup, playback routing, duck cleanup, and no gameplay mutation from AudioManager before audio implementation stories are marked done.

---

## Cross-ADR Conflicts

No blocking conflict detected.

Checked conflict classes:

- **Data ownership**: Player snapshot fields, ammo, lifecycle state, Damage HitBox/HurtBox, SceneManager scene phase, persistence authority, and presentation observers have single owners.
- **Integration contracts**: ADR-0004 scene signals, ADR-0005 typed-signal ordering, ADR-0008 player/SM ownership, ADR-0009 combat event order, ADR-0010 rendering observer boundaries, ADR-0011 scheduling contracts, and ADR-0012 AudioManager bus/playback boundaries align.
- **Performance budgets**: Time Rewind ≤1 ms, active Area2D cap 80, Damage ≤1 ms target, rendering ≤500 draw calls, Collage ≤80 draw calls, shader ≤500 µs, and memory 1.5 GB do not over-allocate the same budget in a contradictory way.
- **Dependency cycles**: none found in ADR dependency declarations.
- **Pattern conflicts**: direct-call exceptions in ADR-0005 are owner APIs only and do not conflict with the signal-first pattern.
- **State management**: no two ADRs claim exclusive write ownership of the same gameplay state. ADR-0012 owns presentation-only session audio state and explicitly excludes gameplay state and persistence writes.

### Advisory Notes (not blockers)

- ADR-0006 reserves future `SettingsManager` / `SaveManager`, while Menu/Pause #18 remains session-only. This is consistent but must be preserved in stories: do not add ad-hoc persistence for pause/menu sliders.
- ADR-0010 and ADR-0011 both depend on ADR-0005 event ordering. This is intentional; production stories should implement ADR-0005 signal fixtures before presentation/combat observers rely on ordering.

---

## ADR Dependency Order

All referenced dependencies exist and are marked Accepted/ratified in their ADR status blocks. No unresolved dependency or cycle was found.

### Recommended ADR Implementation Order

1. **ADR-0001** — Time Rewind Scope: player-only checkpoint model.
2. **ADR-0002** — Time Rewind Storage Format: state snapshot ring buffer; depends on ADR-0001.
3. **ADR-0003** — Determinism Strategy: CharacterBody2D + direct transform / Area2D projectiles; depends on ADR-0001/0002.
4. **ADR-0004** — Scene Lifecycle and Checkpoint Restart Architecture; depends on ADR-0001/0002 and uses ADR-0003 timing constraints.
5. **ADR-0005** — Cross-System Signal Architecture and Event Ordering; depends on ADR-0001 through ADR-0004.
6. **ADR-0006** — Save and Settings Persistence Boundary; depends on ADR-0001 through ADR-0005.
7. **ADR-0007** — Input Polling, Pause Handling, and UI Focus Boundary; depends on ADR-0003/0004/0005/0006.
8. **ADR-0008** — Player Entity Composition and Lifecycle State Ownership; depends on ADR-0001/0002/0003/0004/0005/0007.
9. **ADR-0009** — Damage, HitBox/HurtBox, and Combat Event Ownership; depends on ADR-0001/0002/0003/0004/0005/0008.
10. **ADR-0010** — Collage Rendering and Rewind Shader Pipeline; depends on ADR-0001/0003/0004/0005.
11. **ADR-0011** — Enemy, Boss, and Projectile Deterministic Scheduling; depends on ADR-0001/0003/0004/0005/0009.
12. **ADR-0012** — AudioManager Bus and Playback Boundary; depends on ADR-0005/0006/0009.

### ADR Status Sweep

| ADR | Title | Status |
|---|---|---|
| adr-0001-time-rewind-scope.md | ADR-0001: Time Rewind Scope — Player-Only Checkpoint Model | Accepted (with Amendment 1 — 2026-05-10) |
| adr-0002-time-rewind-storage-format.md | ADR-0002: Time Rewind Storage Format — State Snapshot Ring Buffer | Accepted (with Amendment 1 — 2026-05-09; Amendment 2 — Accepted 2026-05-11 via Player Shooting #7 GDD ratification) |
| adr-0003-determinism-strategy.md | ADR-0003: Determinism Strategy — CharacterBody2D + Direct Transform / Area2D Projectiles | Accepted (ratified 2026-05-14; decision date 2026-05-09) |
| adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md | ADR-0004: Scene Lifecycle and Checkpoint Restart Architecture | Accepted (ratified 2026-05-14) |
| adr-0005-cross-system-signal-architecture-and-event-ordering.md | ADR-0005: Cross-System Signal Architecture and Event Ordering | Accepted (ratified 2026-05-14) |
| adr-0006-save-and-settings-persistence-boundary.md | ADR-0006: Save and Settings Persistence Boundary | Accepted (ratified 2026-05-14) |
| adr-0007-input-polling-pause-handling-and-ui-focus-boundary.md | ADR-0007: Input Polling, Pause Handling, and UI Focus Boundary | Accepted (ratified 2026-05-14) |
| adr-0008-player-entity-composition-and-lifecycle-state-ownership.md | ADR-0008: Player Entity Composition and Lifecycle State Ownership | Accepted (ratified 2026-05-14) |
| adr-0009-damage-hitbox-hurtbox-and-combat-event-ownership.md | ADR-0009: Damage, HitBox/HurtBox, and Combat Event Ownership | Accepted (ratified 2026-05-14) |
| adr-0010-collage-rendering-and-rewind-shader-pipeline.md | ADR-0010: Collage Rendering and Rewind Shader Pipeline | Accepted (ratified 2026-05-14) |
| adr-0011-enemy-boss-projectile-deterministic-scheduling.md | ADR-0011: Enemy, Boss, and Projectile Deterministic Scheduling | Accepted (ratified 2026-05-14) |
| adr-0012-audio-manager-bus-and-playback-boundary.md | ADR-0012: AudioManager Bus and Playback Boundary | Accepted (ratified 2026-05-14) |

---

## GDD Revision Flags

No GDD revision flags. The reviewed GDD assumptions are consistent with verified Godot 4.6 behavior and accepted ADRs.

---

## Engine Compatibility Issues

Engine audit result: **no blocking Godot 4.6 compatibility issue found in ADR text**.

### Engine Audit Results

- Engine: Godot 4.6, pinned 2026-05-08.
- ADRs with `## Engine Compatibility`: 12 / 12.
- Version consistency: all ADR engine compatibility sections use Godot 4.6.
- Deprecated API references: references to deprecated terms are bans, migration notes, or safe caveats, not selected implementation paths.
  - ADR-0004 bans `PackedScene.instance()` / `instance()` and requires `PackedScene.instantiate()` where instantiation is needed.
  - ADR-0005 shows string-based `connect("signal", obj, "method")` only in a deprecated/banned example and requires Callable-style typed signals.
  - ADR-0010 bans `TileMap` and requires `TileMapLayer`.
  - ADR-0002 notes `duplicate()` is safe only for Tier 1 primitive `PlayerSnapshot` fields and requires `duplicate_deep()` if nested resources are introduced later.
- Post-cutoff API conflicts: none found. Rendering/UI/Animation/Resources risks are consistently recorded as verification obligations rather than assumed solved.

### Engine Specialist Findings

No separate Task/subagent consultation was spawned in this Codex adapter run because the repository adapter limits Claude-style `Task` delegation to explicit user-requested parallel/delegated work. Local audit used the pinned engine reference docs and the ADRs' own engine-compatibility evidence. Treat the remaining items below as story/test obligations, not architecture blockers:

1. Steam Deck / Windows D3D12 capture for ADR-0010 collage + rewind shader.
2. Godot 4.6 dual-focus gamepad/keyboard/mouse focus tests for ADR-0007 Menu/Pause.
3. Area2D signal ordering and same-frame contact fixtures for ADR-0009/0011.
4. Animation method-track restore suppression fixture for ADR-0008.
5. Scene transition timing fixture for ADR-0004.
6. Audio bus layout, route isolation, duck-cleanup, and no-persistence fixtures for ADR-0012.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` covers all 18 MVP systems plus concept/systems-index baseline requirements.

### System Coverage

- **Foundation/Core**: Input, Scene Manager, State Machine, Player Movement, Player Shooting, Damage, Time Rewind, Camera — covered by ADR-0001 through ADR-0009.
- **Feature**: Enemy AI, Boss Pattern, Stage/Encounter — covered by ADR-0009 and ADR-0011, with scene/signal dependencies covered by ADR-0004/0005.
- **Presentation/UI/Audio/Narrative**: HUD, VFX, Collage, Rewind Shader, Story Intro, Menu/Pause, Audio — covered by ADR-0005/0006/0007/0009/0010 and ADR-0012; no Audio coverage waiver remains.
- **Deferred systems**: Pickup, Difficulty, Save/Settings, Localization, Input Remapping, Accessibility are recognized as Vertical Slice / Full Vision or foundation artifacts outside Tier 1 implementation. ADR-0006 prevents accidental Tier 1 persistence work.

### Orphaned Architecture

No blocking orphaned architecture found. Process-level items such as CI/static checks, architecture registry, and control manifest are implementation governance rather than game systems.

---

## Verdict: PASS

**PASS** because all 46 tracked Tier 1 requirements are covered, `TR-audio-001` is now directly covered by ADR-0012, all reviewed ADRs include Godot 4.6 engine compatibility and GDD linkage sections, and there are **no blocking ADR gaps** or **blocking cross-ADR conflicts**. Godot 4.6 fixture/static-check obligations remain story completion evidence, not architecture-review concerns.

### Blocking Issues (must resolve before PASS)

None.

### Required ADRs

None for the current Tier 1 MVP architecture.

### Required Follow-up Before Pre-Production Gate

No architecture-review follow-up is required for gate readiness. Continue to use story-level fixtures and static checks as implementation completion evidence.

---

## Validation Evidence

- Read canonical `$architecture-review` workflow and applied full mode.
- Reviewed registry-backed requirement baseline in `docs/architecture/tr-registry.yaml` and architecture baseline in `docs/architecture/architecture.md`.
- Confirmed 46 active TR entries, 12 ADR files, and Godot 4.6 technical preferences.
- Checked ADR status/dependency declarations and engine compatibility sections.
- Scanned ADRs for deprecated Godot API references and classified hits as bans/caveats rather than selected implementation paths.
- Added ADR-0012 and updated traceability to close the prior `TR-audio-001` partial/waived concern.

