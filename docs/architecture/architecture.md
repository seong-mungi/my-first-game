# Echo — Master Architecture

## Document Status

- Version: 0.1
- Last Updated: 2026-05-14
- Engine: Godot 4.6 / GDScript, statically typed
- Target Platform: PC Steam / Steam Deck-friendly controls and budgets
- Review Mode: lean
- GDDs Covered: `game-concept.md`, `systems-index.md`, 18 MVP GDDs (`input`, `scene-manager`, `camera`, `audio`, `state-machine`, `player-movement`, `player-shooting`, `damage`, `time-rewind`, `enemy-ai`, `boss-pattern`, `stage-encounter`, `hud`, `vfx-particle`, `collage-rendering`, `time-rewind-visual-shader`, `story-intro-text`, `menu-pause`)
- ADRs Referenced: ADR-0001 Time Rewind Scope, ADR-0002 Time Rewind Storage Format, ADR-0003 Determinism Strategy, ADR-0004 Scene Lifecycle, ADR-0005 Cross-System Signals, ADR-0006 Save/Settings Boundary, ADR-0007 Input/Pause/UI Focus, ADR-0008 Player Entity Ownership, ADR-0009 Damage/Combat Ownership, ADR-0010 Collage/Rewind Shader Pipeline, ADR-0011 Enemy/Boss/Projectile Scheduling, ADR-0012 AudioManager Bus/Playback Boundary
- Technical Director Sign-Off: 2026-05-14 — APPROVED; architecture-review remediation recorded 2026-05-14
- Lead Programmer Feasibility: LP-FEASIBILITY skipped — Lean mode

> **Condition**: The required Foundation/Core/Presentation ADR set now exists and is Accepted, including explicit AudioManager bus/playback coverage. Coding remains gated by story-level test evidence and each ADR's Godot 4.6 fixture/static-check obligations.

---

## Engine Knowledge Gap Summary

Godot 4.6 is post-cutoff relative to the local LLM baseline. All implementation stories must cross-check `docs/engine-reference/godot/` before relying on engine API memory.

| Risk | Domain | Architectural implication |
|---|---|---|
| HIGH | Godot 4.6 core/version | Treat all engine API details as verify-before-code; stamp ADRs and stories with Godot 4.6. |
| HIGH | Rendering | D3D12 default on Windows, glow-before-tonemapping, AgX controls, Shader Baker/SMAA/Stencils since 4.5; rendering/VFX ADRs must verify shader and post-process paths. |
| HIGH | UI | 4.6 dual-focus system and 4.5 accessibility improvements affect menu/pause and future accessibility options; UI focus behavior must be tested with gamepad + keyboard/mouse. |
| HIGH | Resources | `duplicate_deep()` exists for nested resources; ADR-0002 currently avoids nested `PlayerSnapshot` resources in Tier 1. |
| MEDIUM | Animation | `AnimationMixer.callback_mode_method` default is deferred; PlayerMovement restore guards require IMMEDIATE callback mode when suppressing method-track side effects. |
| MEDIUM | 2D physics | Echo uses Godot Physics 2D; Jolt default only affects 3D. Gameplay entities must avoid `RigidBody2D` per ADR-0003. |
| MEDIUM | Tile maps / rendering | `TileMapLayer`, not deprecated `TileMap`, is the permitted tile-layer node. |
| LOW | Audio | No major post-cutoff API break; still use `AudioServer` buses and explicit players. |

### Deprecated / forbidden Godot patterns

- Do not use `TileMap`; use `TileMapLayer`.
- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not use `instance()` / `PackedScene.instance()`; use `instantiate()`.
- Do not use `OS.get_ticks_msec()` for gameplay timing; use `Engine.get_physics_frames()` for deterministic gameplay clocks.
- Do not use `Texture2D` shader parameter assumptions for changed 4.4 shader texture types; verify shader code against current reference.

---

## Technical Requirements Baseline

Extracted from 20 design sources: concept + systems index + 18 MVP GDDs.

| Req ID | GDD | System | Requirement | Domain | Coverage |
|---|---|---|---|---|---|
| TR-concept-001 | game-concept.md | Concept | PC Steam single-player side-scrolling run-and-gun; no co-op. | Platform / Scope | Architecture principle |
| TR-concept-002 | game-concept.md | Concept | One-hit death must convert into sub-second learning/retry loop. | Core loop | ADR-0001/0002/0004 |
| TR-concept-003 | game-concept.md | Concept | Revoke token restores safe pre-death state from 1.5s lookback, 0.15s restore depth. | Time rewind | ADR-0001/0002 |
| TR-concept-004 | game-concept.md | Concept | Deterministic patterns; luck must not cause death. | Determinism | ADR-0003/0005/0011 |
| TR-concept-005 | game-concept.md | Concept | Collage visual signature must survive clarity/performance constraints. | Rendering | ADR-0010 |
| TR-sys-001 | systems-index.md | Systems | 18 MVP systems must be operational for Tier 1 prototype. | Scope | This document |
| TR-sys-002 | systems-index.md | Systems | Foundation → Core → Feature → Presentation dependency ordering. | Architecture | This document |
| TR-sys-003 | systems-index.md | Systems | MVP systems must avoid circular dependencies. | Architecture | ADR-0005 |
| TR-input-001 | input.md | Input | Fixed 9-action catalog for Tier 1. | Input | ADR-0007 |
| TR-input-002 | input.md | Input | Gameplay input polling occurs in `_physics_process` only. | Determinism | ADR-0003/0007 |
| TR-input-003 | input.md | Input | Pause/menu callbacks are explicit exceptions, not gameplay logic. | UI / Input | ADR-0007 |
| TR-input-004 | input.md | Input | Use `StringName` action constants, not inline action strings. | API | ADR-0007 |
| TR-scene-001 | scene-manager.md | Scene Manager | `SceneManager` owns scene lifecycle, checkpoint restart, stage clear transitions. | Foundation | ADR-0004 |
| TR-scene-002 | scene-manager.md | Scene Manager | `scene_will_change()` emitted exactly once before scene swap. | Eventing | ADR-0004/0005 |
| TR-scene-003 | scene-manager.md | Scene Manager | `scene_post_loaded(anchor, limits)` initializes camera and stage bounds. | Eventing | ADR-0004 |
| TR-scene-004 | scene-manager.md | Scene Manager | Restart path must fit within 60 physics frames. | Performance | ADR-0004 |
| TR-state-001 | state-machine.md | State Machine | Entity-local `StateMachine` nodes; never Autoload state machines. | Foundation / Core | ADR-0008 |
| TR-state-002 | state-machine.md | State Machine | Cross-entity transitions use signals, never direct foreign SM calls. | Eventing | ADR-0005 |
| TR-state-003 | state-machine.md | State Machine | ECHO lifecycle states ALIVE/DYING/REWINDING/DEAD drive rewind/death flow. | Core | ADR-0008 |
| TR-pm-001 | player-movement.md | Player Movement | ECHO root is `CharacterBody2D`, process priority 0. | Core / Physics | ADR-0003/0008 |
| TR-pm-002 | player-movement.md | Player Movement | Snapshot-visible movement state is restored only through `restore_from_snapshot()`. | Time rewind | ADR-0002/0008 |
| TR-pm-003 | player-movement.md | Player Movement | Animation method-track side effects must be guarded during restore. | Animation | ADR-0008 |
| TR-ps-001 | player-shooting.md | Player Shooting | `WeaponSlot` owns `ammo_count` and is sole writer except snapshot restore path. | Core state | ADR-0002/0008 |
| TR-ps-002 | player-shooting.md | Player Shooting | `shot_fired(direction)` is the public event for VFX/audio/camera feedback. | Eventing | ADR-0005 |
| TR-damage-001 | damage.md | Damage | Damage owns HitBox/HurtBox contracts and cause taxonomy. | Combat | ADR-0009 |
| TR-damage-002 | damage.md | Damage | Damage emits lethal/boss/enemy signals in deterministic order. | Eventing | ADR-0005/0009 |
| TR-damage-003 | damage.md | Damage | Damage must not poll SM state; SM controls ECHO HurtBox monitorability. | Core boundary | ADR-0008/0009 |
| TR-tr-001 | time-rewind.md | Time Rewind | Capture 90-frame ring buffer at 60 fps. | Time rewind | ADR-0002 |
| TR-tr-002 | time-rewind.md | Time Rewind | Player-only rewind scope; enemies/projectiles/environment continue normal simulation. | Time rewind | ADR-0001 |
| TR-tr-003 | time-rewind.md | Time Rewind | TRC process priority 1, after PlayerMovement and before Damage/enemies/projectiles. | Determinism | ADR-0003 |
| TR-enemy-001 | enemy-ai.md | Enemy AI | Enemies derive from deterministic `EnemyBase extends CharacterBody2D`. | AI / Physics | ADR-0003/0011 |
| TR-enemy-002 | enemy-ai.md | Enemy AI | Enemy behavior uses authored/pure frame-based patterns, not random lethal decisions. | AI | ADR-0011 |
| TR-boss-001 | boss-pattern.md | Boss Pattern | STRIDER phases are authored deterministic scripts with discrete hit thresholds. | Combat / AI | ADR-0011 |
| TR-boss-002 | boss-pattern.md | Boss Pattern | Boss owns phase scripts; Damage owns hit/phase signal contract. | Boundary | ADR-0009/0011 |
| TR-stage-001 | stage-encounter.md | Stage | Stage owns room metadata, encounter activation, checkpoint anchors, camera limits. | Level / Scene | ADR-0004/0011 |
| TR-stage-002 | stage-encounter.md | Stage | Stage owns `Projectiles: Node2D` container presence/lifetime; projectile behavior remains Player Shooting/Damage-owned. | Boundary | ADR-0011 |
| TR-camera-001 | camera.md | Camera | Camera is scene-local, not Autoload; not included in PlayerSnapshot. | Presentation / Core | ADR-0002/0004/0005/0010 |
| TR-camera-002 | camera.md | Camera | Camera consumes scene/damage/weapon/rewind events for snap, limits, freeze, shake. | Eventing | ADR-0004/0005/0009/0010 |
| TR-audio-001 | audio.md | Audio | `AudioManager` owns bus hierarchy and all sound playback; gameplay emits events only. | Presentation | ADR-0012 |
| TR-hud-001 | hud.md | HUD | HUD is observer-only CanvasLayer; never mutates simulation state. | UI | ADR-0005/0007/0009/0010 |
| TR-menu-001 | menu-pause.md | Menu/Pause | PauseHandler controls pause lifecycle; Menu UI owns focus/navigation and session-only options. | UI / Input | ADR-0004/0005/0006/0007 |
| TR-story-001 | story-intro-text.md | Story Intro | One passive five-line intro; no prompt gate or extra input actions. | Narrative / UI | ADR-0004/0007 |
| TR-vfx-001 | vfx-particle.md | VFX | VFX owns non-HUD visual feedback; no gameplay collision/damage ownership. | Presentation | ADR-0005/0009/0010 (dedicated ADR waived) |
| TR-collage-001 | collage-rendering.md | Collage Rendering | Layered collage pipeline must preserve 0.2s readability and draw/memory budgets. | Rendering | ADR-0010 |
| TR-shader-001 | time-rewind-visual-shader.md | Rewind Shader | Full-viewport rewind signature triggers from rewind lifecycle and remains budget-safe. | Rendering | ADR-0010 |
| TR-persist-001 | systems-index.md | Save/Settings | Save/settings persistence is Vertical Slice and must not be accidentally invented in Tier 1 systems. | Persistence | ADR-0006 |

---

## System Layer Map

```text
┌────────────────────────────────────────────────────────────┐
│ PRESENTATION LAYER                                         │
│ HUD #13, Menu/Pause #18, Story Intro #17, Audio #4,        │
│ VFX #14, Collage Rendering #15, Rewind Visual Shader #16   │
├────────────────────────────────────────────────────────────┤
│ FEATURE LAYER                                              │
│ Enemy AI #10, Boss Pattern #11, Stage/Encounter #12,       │
│ Pickup #19, Difficulty #20                                 │
├────────────────────────────────────────────────────────────┤
│ CORE LAYER                                                 │
│ Input #1, Camera #3, State Machine #5, Player Movement #6, │
│ Player Shooting #7, Damage #8, Time Rewind #9              │
├────────────────────────────────────────────────────────────┤
│ FOUNDATION LAYER                                           │
│ Scene Manager #2, architecture registry, signal contracts, │
│ test/static-check harness, Save/Settings #21               │
├────────────────────────────────────────────────────────────┤
│ PLATFORM LAYER                                             │
│ Godot 4.6, GDScript, Godot Physics 2D, Forward+, PC Steam  │
└────────────────────────────────────────────────────────────┘
```

### Layer assignment table

| Layer | Systems | Owns exclusively | Notes |
|---|---|---|---|
| Platform | Godot 4.6, GDScript, InputMap, SceneTree, PhysicsServer2D, AudioServer, Rendering/CanvasItem stack | Engine APIs and runtime services | Must verify 4.6 API references before implementation. |
| Foundation | Scene Manager #2, architecture registry, CI/static checks, Save/Settings #21 (deferred) | Scene lifecycle, boot order, transition intents, architecture contracts, persistence policy | Scene/Event/Save ADRs are required before coding. |
| Core | Input #1, State Machine #5, Player Movement #6, Player Shooting #7, Damage #8, Time Rewind #9, Camera #3 | Per-frame gameplay state, deterministic clocks, combat event order, snapshot/restore, camera composition | Camera is Core because it consumes gameplay timing and scene lifecycle, though output is visual. |
| Feature | Enemy AI #10, Boss Pattern #11, Stage/Encounter #12, Pickup #19, Difficulty #20 | Authored encounter logic, enemies, boss scripts, stage rooms, difficulty policy | Tier 1 implements Enemy/Boss/Stage; Pickup/Difficulty are deferred. |
| Presentation | HUD #13, Menu/Pause #18, Story Intro #17, Audio #4, VFX #14, Collage #15, Rewind Shader #16 | Player-facing display, audio, UI focus, visual feedback, collage rendering rules | Presentation observes simulation; it must not own gameplay truth. |

---

## Module Ownership

### State ownership

| State | Owner module | Exposed by | Write path | ADR / source |
|---|---|---|---|---|
| `player_rewind_state` | TimeRewindController | rewind lifecycle signals and token getters | TRC only | ADR-0001/0002 |
| `PlayerSnapshot` 9-field resource | TimeRewindController + PlayerMovement/WeaponSlot-owned fields | `PlayerMovement.restore_from_snapshot(snap)` and `WeaponSlot.restore_from_snapshot(snap)` | TRC orchestrates; owners restore their own fields | ADR-0002 |
| `echo_lifecycle_state` | EchoLifecycleSM | `state_changed`, `can_pause()`, `should_swallow_pause()` | StateMachine transition API only | State Machine GDD; ADR-0008 |
| `player_movement_state` | PlayerMovement | read-only properties + snapshot restore | PlayerMovement or restore method only | Player Movement GDD; ADR-0002 |
| `ammo_count` | WeaponSlot | read-only property + weapon signals | WeaponSlot only, plus `restore_from_snapshot()` | ADR-0002 Amendment 2 |
| `input_actions_catalog` | Input System | `InputActions` constants + Godot InputMap | Input system / future SettingsManager only | Input GDD; ADR-0007 |
| `scene_phase` | SceneManager | transition API + scene lifecycle signals | SceneManager only | ADR-0004 |
| `boss_phase_state` | Boss Pattern / Damage-mediated hit path | boss signals | Damage-mediated only | Damage + Boss GDDs; ADR-0009/0011 |
| UI focus/session options | Menu/Pause UI | UI signals / PauseHandler | Menu/Pause only; no gameplay writes | ADR-0007 |

### Engine API ownership

| Module | Direct Godot APIs | Risk / verification note |
|---|---|---|
| Scene Manager | `SceneTree.change_scene_to_packed`, `PackedScene.instantiate`, groups | Must avoid deprecated `instance()`; Scene lifecycle ADR required. |
| Input | `Input`, `InputMap`, `InputEvent`, `_physics_process`, `_input` exceptions | SDL3/gamepad and dual profile behavior need Steam Deck checks. |
| Player / Enemies | `CharacterBody2D`, `move_and_slide`, `Area2D`, `Engine.get_physics_frames()` | ADR-0003 bans `RigidBody2D` for gameplay entities. |
| Damage | `Area2D.monitoring/monitorable`, signals | Godot 4.6 Area2D semantics must be test-covered. |
| Time Rewind | `Resource`, preallocated arrays, `AnimationPlayer.seek` via PlayerMovement | `duplicate_deep()` not needed for primitive snapshots; nested Resource future requires it. |
| Camera | `Camera2D`, limits, smoothing reset, `offset` shake | Camera state banned from PlayerSnapshot. |
| HUD/Menu/Story | `CanvasLayer`, `Control`, focus/navigation | 4.6 dual-focus system is high-risk; UI ADR required. |
| Audio | `AudioServer`, `AudioStreamPlayer`, `Tween` | ADR-0012 owns bus/playback/session-volume boundary; Godot 4.6 fixtures must verify bus routing and duck cleanup. |
| Rendering/VFX | `Sprite2D`, `AnimatedSprite2D`, `GPUParticles2D`, `CanvasItem` shaders, `TileMapLayer` | Rendering is high-risk in 4.6; use `TileMapLayer`, verify shader texture types. |

---

## Data Flow

### 1. Frame update path

```text
InputMap / Input singleton
  ↓ _physics_process Phase 2 polling only
Input consumers (PM / SM / TRC / Shooting)
  ↓ deterministic frame clock: Engine.get_physics_frames()
PlayerMovement(priority 0) → TimeRewindController(priority 1) → Damage(priority 2)
  ↓
Enemy/Boss/projectile systems(priority 10/20)
  ↓
Camera/HUD/VFX/Audio observe emitted signals and read-only state
  ↓
CanvasItem / AudioServer presentation
```

Rules:

- Gameplay systems do not use wall-clock timers for authoritative logic.
- Presentation systems may animate cosmetically, but cannot change simulation state.
- Input callbacks are reserved for UI/Menu, PauseHandler, and profile detection carve-outs.

### 2. Event / signal path

```text
Damage / WeaponSlot / SceneManager / TRC / StateMachine
  emit typed signals
      ↓
Observers connect explicitly
      ↓
HUD, VFX, Audio, Camera, SM, TRC respond within their ownership boundary
```

There is no global event bus in Tier 1. The architecture uses typed Godot signals with producer-owned signatures. A future Event/Signal ADR must decide whether this remains direct typed signals or becomes a lightweight event bus for Tier 2+.

### 3. Rewind / death path

```text
Damage detects lethal hit
  → lethal_hit_detected(cause)
  → player_hit_lethal(cause)
  → EchoLifecycleSM enters DYING
  → TimeRewindController freezes lethal head and consumes token if available
  → PlayerMovement.restore_from_snapshot(snap)
  → WeaponSlot.restore_from_snapshot(snap)
  → rewind_completed(player, restored_to_frame)
  → Camera snaps/recomputes; HUD/VFX/Audio present feedback
```

Hard invariants:

- Enemies/projectiles/environment are not rewound.
- Camera state is not captured.
- Animation method-track side effects are guarded during restore.
- Rewind restore depth is 9 frames / 0.15s; lookback window is 90 frames / 1.5s.

### 4. Scene restart / stage clear path

```text
SceneManager.change_scene_to_packed(intent)
  → scene_will_change()
  → SceneTree.change_scene_to_packed(packed)
  → checkpoint anchors and limits registered
  → scene_post_loaded(anchor, limits)
  → Camera snap + limits; EchoLifecycleSM clears ephemeral state; TRC invalidates buffer but preserves token policy where specified
```

Scene lifecycle must become a Foundation ADR before coding because it is the cross-system boot and restart boundary.

### 5. Save/load path

Tier 1 has no persistent save/load system beyond session-local options. Vertical Slice Save/Settings #21 must be designed before any implementation writes persistence code. Until the Save ADR exists:

- Do not serialize `PlayerSnapshot` as a save file.
- Do not persist pause/menu session-only options.
- Do not add ad-hoc `ConfigFile` writes in UI systems.
- Do not invent progression state.

---

## API Boundaries

### Scene Manager

```gdscript
signal scene_will_change()
signal scene_post_loaded(anchor: Vector2, limits: Rect2)

func change_scene_to_packed(packed: PackedScene, intent: TransitionIntent) -> void
```

Guarantees:

- Emits `scene_will_change()` exactly once per transition.
- Emits `scene_post_loaded(anchor, limits)` after anchor/limits registration.
- Owns all raw `SceneTree.change_scene_to_packed` calls.

### Time Rewind Controller

```gdscript
signal rewind_started(remaining_tokens: int)
signal rewind_completed(player: Node2D, restored_to_frame: int)
signal rewind_protection_ended(player: Node2D)
signal token_consumed(remaining_tokens: int)
signal token_replenished(new_total: int)

func get_remaining_tokens() -> int
func try_consume_rewind() -> bool
```

Guarantees:

- Captures snapshots at 60 Hz in physics tick order.
- Restores through owner methods only.
- Never rewinds enemies, projectiles, camera, or environment state.

### Player Movement

```gdscript
func restore_from_snapshot(snap: PlayerSnapshot) -> void
func _clear_ephemeral_state() -> void
```

Guarantees:

- Owns PM fields and animation restore.
- Guards animation method-track callbacks during restore.
- Does not own weapon ammo writes.

### WeaponSlot

```gdscript
signal weapon_equipped(weapon_id: int)
signal shot_fired(direction: int)
signal weapon_fallback_activated(requested_id: int)

func restore_from_snapshot(snap: PlayerSnapshot) -> void
func set_active(weapon_id: int) -> void
```

Guarantees:

- Sole writer of `ammo_count`.
- Emits boot equip signal after subscribers can connect.
- Never mutates PlayerMovement state directly.

### Damage

```gdscript
signal lethal_hit_detected(cause: StringName)
signal player_hit_lethal(cause: StringName)
signal death_committed(cause: StringName)
signal hurtbox_hit(cause: StringName)
signal enemy_killed(enemy_id: StringName, cause: StringName)
signal boss_hit_absorbed(boss_id: StringName, phase_index: int)
signal boss_pattern_interrupted(boss_id: StringName, prev_phase_index: int)
signal boss_phase_advanced(boss_id: StringName, new_phase: int)
signal boss_killed(boss_id: StringName)
```

Guarantees:

- Owns HitBox/HurtBox semantics and emit order.
- Does not poll StateMachine state.
- Keeps boss phase transitions bounded and deterministic.

### Presentation observers

HUD, VFX, Audio, Camera, and Rewind Shader consume signals/read-only state. They may cache display state, but cannot write authoritative gameplay state.

---

## ADR Audit

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|---|---:|---:|---:|---|---:|
| ADR-0001 Time Rewind Scope | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |
| ADR-0002 Time Rewind Storage Format | ✅ | ✅ Godot 4.6 | ✅ | Persistence wording amended to defer to ADR-0006; nested Resource future needs `duplicate_deep()` | ✅ |
| ADR-0003 Determinism Strategy | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |
| ADR-0004 Scene Lifecycle and Checkpoint Restart Architecture | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |
| ADR-0005 Cross-System Signal Architecture and Event Ordering | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |
| ADR-0006 Save and Settings Persistence Boundary | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |
| ADR-0007 Input Polling, Pause Handling, and UI Focus Boundary | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |
| ADR-0008 Player Entity Composition and Lifecycle State Ownership | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |
| ADR-0009 Damage, HitBox/HurtBox, and Combat Event Ownership | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |
| ADR-0010 Collage Rendering and Rewind Shader Pipeline | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |
| ADR-0011 Enemy, Boss, and Projectile Deterministic Scheduling | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |
| ADR-0012 AudioManager Bus and Playback Boundary | ✅ | ✅ Godot 4.6 | ✅ | None | ✅ |

### Traceability coverage snapshot

| Area | Covered by existing ADRs | Gap |
|---|---|---|
| Time Rewind scope/storage/determinism | ADR-0001/0002/0003 | None for current Time Rewind core. |
| Scene lifecycle / restart / boot order | ADR-0004 | None. |
| Event/signal architecture | ADR-0005 | None. |
| Save/settings persistence | ADR-0006 | None. |
| Input polling / pause / UI focus | ADR-0007 | None. |
| Player entity composition / lifecycle | ADR-0008 | None. |
| Damage/combat signal ordering | ADR-0009 | None. |
| Enemy, boss, projectile scheduling | ADR-0011 | None. |
| Rendering/collage/shader pipeline | ADR-0010 | None. |
| AudioManager bus/playback/session-volume boundary | ADR-0012 | None. |
| VFX observer ownership | ADR-0005/0009/0010 | Dedicated VFX ADR waived for Tier 1; create one only if implementation adds new VFX authority or routing complexity. |

Current coverage count across the baseline: 46 covered, 0 partial-waived, 0 gaps. `TR-audio-001` is now covered directly by ADR-0012, while VFX remains covered by signal/combat/rendering ADRs without a dedicated VFX ADR.

---

## Required ADRs / Waivers

### Accepted before coding starts (Foundation, Core, and required Presentation boundaries)

1. ADR-0004 — Scene lifecycle and checkpoint restart architecture
   - Covers: TR-scene-001, TR-scene-003, TR-scene-004, TR-stage-001.
2. ADR-0005 — Cross-system signal architecture and event ordering
   - Covers: TR-scene-002, TR-state-002, TR-ps-002, TR-damage-002, TR-camera-002.
3. ADR-0006 — Save and settings persistence boundary
   - Covers: TR-persist-001, TR-menu-001 future persistence carve-outs.
4. ADR-0007 — Input polling, pause handling, and UI focus boundary
   - Covers: TR-input-001..004, TR-menu-001, TR-story-001.
5. ADR-0008 — Player entity composition and lifecycle state ownership
   - Covers: TR-state-001, TR-state-003, TR-pm-001..003.
6. ADR-0009 — Damage, HitBox/HurtBox, and combat event ownership
   - Covers: TR-damage-001..003, TR-boss-002.

### Accepted before the relevant system is built

7. ADR-0011 — Enemy, boss, projectile deterministic scheduling
   - Covers: TR-enemy-001..002, TR-boss-001, TR-stage-002.
8. ADR-0010 — Collage rendering and rewind shader pipeline
   - Covers: TR-concept-005, TR-collage-001, TR-shader-001.
9. ADR-0012 — AudioManager bus and playback boundary
   - Covers: TR-audio-001.

### Waived for Tier 1

- **Dedicated HUD/Menu observer-only UI ADR**: waived because ADR-0005 covers observer-only signal boundaries, ADR-0007 covers Menu/Pause focus/input ownership, ADR-0009 blocks boss HP/hit-count leakage to HUD, and ADR-0010 covers HUD readability against collage/shader effects.
- **Dedicated VFX observer event architecture ADR**: waived because ADR-0005 locks presentation observers and signal ordering, ADR-0009 provides combat event/cause contracts for VFX consumers, and ADR-0010 splits local VFX from fullscreen shader responsibility. Audio is no longer waived: ADR-0012 owns AudioManager bus/playback/session-volume boundaries. Create a new ADR if implementation introduces a pooled VFX router, global presentation event bus, audio middleware layer, or new authoring tool boundary.

### Deferred to implementation or later vertical slice

10. Pickup and difficulty toggle extension boundary.
11. Localization and accessibility future-proofing.

---

## Architecture Principles

1. **Single writer, many observers** — every piece of gameplay state has exactly one owner; other systems consume signals or read-only properties.
2. **Physics-frame determinism** — gameplay timing uses `Engine.get_physics_frames()` and deterministic process ordering, never wall-clock logic.
3. **Presentation is not authority** — HUD, VFX, Audio, shaders, camera shake, and menu chrome cannot mutate simulation state.
4. **Scene lifecycle is the foundation boundary** — scene transitions, checkpoint restart, boot order, and anchor/limits propagation are Scene Manager-owned.
5. **Small success before broad flexibility** — Tier 1 intentionally defers persistence, remapping, localization, advanced accessibility, and content scale until their ADRs exist.

---

## Resolved and Remaining Questions

| ID | Question | Status | Resolution / Remaining Gate |
|---|---|---|---|
| OQ-ARCH-001 | Will Tier 2+ introduce a lightweight event bus, or keep direct typed signals only? | Resolved for Tier 1 | ADR-0005 keeps direct typed signals and rejects a global event bus for Tier 1. Re-open only if Tier 2 introduces routing complexity. |
| OQ-ARCH-002 | What exact persistence format owns settings/save state? | Resolved boundary / implementation deferred | ADR-0006 reserves `SettingsManager`, `SaveManager`, `user://echo_settings.cfg`, and `user://echo_progress.cfg`; no Tier 1 system writes persistence. |
| OQ-ARCH-003 | How will Godot 4.6 dual-focus UI be tested on keyboard/mouse, gamepad, and Steam Deck? | Open validation gate | ADR-0007 requires fixture/manual validation for keyboard/mouse, gamepad, and Steam Deck-equivalent focus behavior before Menu/Pause completion. |
| OQ-ARCH-006 | Who owns Tier 1 audio bus/playback/session-volume boundaries? | Resolved | ADR-0012 assigns bus layout, SFX/BGM/UI playback routing, Music ducking, and session-only volume writes to AudioManager. |
| OQ-ARCH-004 | Is `TileMapLayer` required for Tier 1 stage layout or can Stage use Sprite2D/Node2D authored rooms only? | Resolved | ADR-0010 permits authored `Sprite2D`, atlas pieces, `Line2D`, and `TileMapLayer`; deprecated `TileMap` is forbidden. |
| OQ-ARCH-005 | Which rendering path handles full-screen rewind: simple `ColorRect` CanvasItem shader stub or CompositorEffect later? | Resolved for Tier 1 | ADR-0010 chooses a `CanvasLayer`/`ColorRect` CanvasItem shader path with an inversion-only fallback; CompositorEffect is not a Tier 1 requirement. |

---

## Technical Director Self-Review

TD-ARCHITECTURE criteria:

1. **Every technical requirement covered by an architectural decision?** Yes for Tier 1 MVP requirements: 46 covered, 0 partial-waived, 0 gaps.
2. **HIGH risk engine domains addressed or flagged?** Yes: Godot 4.6 rendering, UI, resources, animation, 2D physics, scene lifecycle, and signal-order risks are explicitly flagged with fixture/static-check obligations.
3. **API boundaries clean and implementable?** Yes for currently specified MVP boundaries; coding claims still require each ADR's validation evidence.
4. **Foundation layer ADR gaps resolved before implementation begins?** Yes: ADR-0004 through ADR-0009 close the Foundation/Core gaps identified in the initial lean architecture pass.

Verdict: **APPROVED** — master blueprint and required ADR coverage are complete enough to drive story implementation. Story completion still requires fresh Godot 4.6 fixture/static-check evidence required by the relevant ADRs, but no architecture coverage concern remains.
