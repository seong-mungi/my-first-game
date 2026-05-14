# Architecture Traceability Index
Last Updated: 2026-05-14
Engine: Godot 4.6 / GDScript
Source Review: `docs/architecture/architecture-review-2026-05-14.md`

## Coverage Summary

- Total requirements: 46
- Covered: 46 (100%)
- Partial: 0
- Gaps: 0

## Full Matrix

| Requirement ID | GDD | Requirement | ADR / Architecture Coverage | Status |
|---|---|---|---|---|
| TR-concept-001 | game-concept.md | PC Steam single-player side-scrolling run-and-gun; no co-op. | Architecture principle | ✅ Covered |
| TR-concept-002 | game-concept.md | One-hit death must convert into sub-second learning/retry loop. | ADR-0001/0002/0004 | ✅ Covered |
| TR-concept-003 | game-concept.md | Revoke token restores safe pre-death state from 1.5s lookback, 0.15s restore depth. | ADR-0001/0002 | ✅ Covered |
| TR-concept-004 | game-concept.md | Deterministic patterns; luck must not cause death. | ADR-0003/0005/0011 | ✅ Covered |
| TR-concept-005 | game-concept.md | Collage visual signature must survive clarity/performance constraints. | ADR-0010 | ✅ Covered |
| TR-sys-001 | systems-index.md | 18 MVP systems must be operational for Tier 1 prototype. | This document | ✅ Covered |
| TR-sys-002 | systems-index.md | Foundation → Core → Feature → Presentation dependency ordering. | This document | ✅ Covered |
| TR-sys-003 | systems-index.md | MVP systems must avoid circular dependencies. | ADR-0005 | ✅ Covered |
| TR-input-001 | input.md | Fixed 9-action catalog for Tier 1. | ADR-0007 | ✅ Covered |
| TR-input-002 | input.md | Gameplay input polling occurs in `_physics_process` only. | ADR-0003/0007 | ✅ Covered |
| TR-input-003 | input.md | Pause/menu callbacks are explicit exceptions, not gameplay logic. | ADR-0007 | ✅ Covered |
| TR-input-004 | input.md | Use `StringName` action constants, not inline action strings. | ADR-0007 | ✅ Covered |
| TR-scene-001 | scene-manager.md | `SceneManager` owns scene lifecycle, checkpoint restart, stage clear transitions. | ADR-0004 | ✅ Covered |
| TR-scene-002 | scene-manager.md | `scene_will_change()` emitted exactly once before scene swap. | ADR-0004/0005 | ✅ Covered |
| TR-scene-003 | scene-manager.md | `scene_post_loaded(anchor, limits)` initializes camera and stage bounds. | ADR-0004 | ✅ Covered |
| TR-scene-004 | scene-manager.md | Restart path must fit within 60 physics frames. | ADR-0004 | ✅ Covered |
| TR-state-001 | state-machine.md | Entity-local `StateMachine` nodes; never Autoload state machines. | ADR-0008 | ✅ Covered |
| TR-state-002 | state-machine.md | Cross-entity transitions use signals, never direct foreign SM calls. | ADR-0005 | ✅ Covered |
| TR-state-003 | state-machine.md | ECHO lifecycle states ALIVE/DYING/REWINDING/DEAD drive rewind/death flow. | ADR-0008 | ✅ Covered |
| TR-pm-001 | player-movement.md | ECHO root is `CharacterBody2D`, process priority 0. | ADR-0003/0008 | ✅ Covered |
| TR-pm-002 | player-movement.md | Snapshot-visible movement state is restored only through `restore_from_snapshot()`. | ADR-0002/0008 | ✅ Covered |
| TR-pm-003 | player-movement.md | Animation method-track side effects must be guarded during restore. | ADR-0008 | ✅ Covered |
| TR-ps-001 | player-shooting.md | `WeaponSlot` owns `ammo_count` and is sole writer except snapshot restore path. | ADR-0002/0008 | ✅ Covered |
| TR-ps-002 | player-shooting.md | `shot_fired(direction)` is the public event for VFX/audio/camera feedback. | ADR-0005 | ✅ Covered |
| TR-damage-001 | damage.md | Damage owns HitBox/HurtBox contracts and cause taxonomy. | ADR-0009 | ✅ Covered |
| TR-damage-002 | damage.md | Damage emits lethal/boss/enemy signals in deterministic order. | ADR-0005/0009 | ✅ Covered |
| TR-damage-003 | damage.md | Damage must not poll SM state; SM controls ECHO HurtBox monitorability. | ADR-0008/0009 | ✅ Covered |
| TR-tr-001 | time-rewind.md | Capture 90-frame ring buffer at 60 fps. | ADR-0002 | ✅ Covered |
| TR-tr-002 | time-rewind.md | Player-only rewind scope; enemies/projectiles/environment continue normal simulation. | ADR-0001 | ✅ Covered |
| TR-tr-003 | time-rewind.md | TRC process priority 1, after PlayerMovement and before Damage/enemies/projectiles. | ADR-0003 | ✅ Covered |
| TR-enemy-001 | enemy-ai.md | Enemies derive from deterministic `EnemyBase extends CharacterBody2D`. | ADR-0003/0011 | ✅ Covered |
| TR-enemy-002 | enemy-ai.md | Enemy behavior uses authored/pure frame-based patterns, not random lethal decisions. | ADR-0011 | ✅ Covered |
| TR-boss-001 | boss-pattern.md | STRIDER phases are authored deterministic scripts with discrete hit thresholds. | ADR-0011 | ✅ Covered |
| TR-boss-002 | boss-pattern.md | Boss owns phase scripts; Damage owns hit/phase signal contract. | ADR-0009/0011 | ✅ Covered |
| TR-stage-001 | stage-encounter.md | Stage owns room metadata, encounter activation, checkpoint anchors, camera limits. | ADR-0004/0011 | ✅ Covered |
| TR-stage-002 | stage-encounter.md | Stage owns `Projectiles: Node2D` container presence/lifetime; projectile behavior remains Player Shooting/Damage-owned. | ADR-0011 | ✅ Covered |
| TR-camera-001 | camera.md | Camera is scene-local, not Autoload; not included in PlayerSnapshot. | ADR-0002/0004/0005/0010 | ✅ Covered |
| TR-camera-002 | camera.md | Camera consumes scene/damage/weapon/rewind events for snap, limits, freeze, shake. | ADR-0004/0005/0009/0010 | ✅ Covered |
| TR-audio-001 | audio.md | `AudioManager` owns bus hierarchy and all sound playback; gameplay emits events only. | ADR-0012 | ✅ Covered |
| TR-hud-001 | hud.md | HUD is observer-only CanvasLayer; never mutates simulation state. | ADR-0005/0007/0009/0010 | ✅ Covered |
| TR-menu-001 | menu-pause.md | PauseHandler controls pause lifecycle; Menu UI owns focus/navigation and session-only options. | ADR-0004/0005/0006/0007 | ✅ Covered |
| TR-story-001 | story-intro-text.md | One passive five-line intro; no prompt gate or extra input actions. | ADR-0004/0007 | ✅ Covered |
| TR-vfx-001 | vfx-particle.md | VFX owns non-HUD visual feedback; no gameplay collision/damage ownership. | ADR-0005/0009/0010 (dedicated ADR waived) | ✅ Covered |
| TR-collage-001 | collage-rendering.md | Layered collage pipeline must preserve 0.2s readability and draw/memory budgets. | ADR-0010 | ✅ Covered |
| TR-shader-001 | time-rewind-visual-shader.md | Full-viewport rewind signature triggers from rewind lifecycle and remains budget-safe. | ADR-0010 | ✅ Covered |
| TR-persist-001 | systems-index.md | Save/settings persistence is Vertical Slice and must not be accidentally invented in Tier 1 systems. | ADR-0006 | ✅ Covered |

## Known Gaps

None.

## Partial / Waived Requirements

None.

## Superseded Requirements

None detected in this review.

## History

| Date | Covered | Partial | Gaps | Notes |
|---|---:|---:|---:|---|
| 2026-05-14 | 45 | 1 | 0 | Initial Codex architecture-review traceability index. |
| 2026-05-14 | 46 | 0 | 0 | ADR-0012 added explicit AudioManager bus/playback coverage for TR-audio-001. |
