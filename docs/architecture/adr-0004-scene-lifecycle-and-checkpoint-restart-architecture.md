# ADR-0004: Scene Lifecycle and Checkpoint Restart Architecture

## Status
Accepted (ratified 2026-05-14)

## Date
2026-05-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / SceneTree / Scripting |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md`, `.claude/docs/technical-preferences.md`, `docs/registry/architecture.yaml`, `docs/architecture/architecture.md`, `design/gdd/scene-manager.md`, `design/gdd/camera.md`, `design/gdd/time-rewind.md`, `design/gdd/state-machine.md`, `design/gdd/stage-encounter.md`, `design/gdd/menu-pause.md` |
| **Post-Cutoff APIs Used** | None. This decision relies on stable Godot 4.x primitives: `SceneTree.change_scene_to_packed(packed: PackedScene)`, `PackedScene`, autoload nodes, typed signals, `StringName`, groups, `Rect2`, and `Vector2`. The implementation must avoid deprecated `PackedScene.instance()` / `instance()` and use `PackedScene.instantiate()` only when instantiating support fixtures or authored scenes outside the raw scene-swap call. |
| **Verification Required** | (1) `scene_will_change()` emits exactly once per accepted transition and before the raw `SceneTree.change_scene_to_packed` call in the same physics tick. (2) Exactly one raw `SceneTree.change_scene_to_packed` call occurs per accepted transition, and no raw scene swap calls exist outside `SceneManager`. (3) `scene_post_loaded(anchor: Vector2, limits: Rect2)` emits exactly once after checkpoint anchor registration and before READY. (4) `limits.size.x > 0 and limits.size.y > 0` is asserted before emit. (5) Checkpoint restart completes within `restart_window_max_frames = 60` physics ticks on the contract fixture and is manually measured on Steam Deck Gen 1 hardware before production lock. (6) No coroutine / `await` / `call_deferred()` wraps the restart swap path. (7) TRC invalidates only the ring buffer and preserves tokens. (8) EchoLifecycleSM clears PlayerMovement ephemeral state via O6 cascade; PlayerMovement does not subscribe directly. |

> Engine validation note: primary engine specialist from `.claude/docs/technical-preferences.md` is `godot-specialist`. In this Codex adapter run, no subagent was spawned because the repository adapter limits `Task`/subagent use to explicit user-requested delegation. The draft was validated locally against the pinned Godot 4.6 reference files listed above. No blocking Godot 4.6 API incompatibility was found; the main engine-risk mitigation is test evidence around `change_scene_to_packed` timing and avoiding deprecated `instance()` / string-based `connect()`.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Time Rewind Scope — player-only rewind and checkpoint model; ADR-0002 Time Rewind Storage Format — TRC-owned ring buffer and token semantics. |
| **Enables** | ADR-0005 Cross-system signal architecture and event ordering; Scene Manager #2 implementation stories; Stage / Encounter #12 checkpoint metadata stories; Camera #3 scene snap/limits integration tests; Menu/Pause #18 checkpoint restart request story. |
| **Blocks** | Any production code that calls `SceneTree.change_scene_to_packed`, implements checkpoint restart, handles `scene_will_change()`, registers checkpoint anchors, or emits/consumes `scene_post_loaded(anchor, limits)` must wait for this ADR to be accepted. |
| **Ordering Note** | ADR-0004 must be accepted before Foundation/Core coding begins. ADR-0003 Determinism Strategy remains a related upstream timing constraint for physics-frame order, but SceneManager itself must not occupy a `process_physics_priority` slot. |

## Context

### Problem Statement

Echo needs a single, deterministic scene lifecycle owner that can reload the Tier 1 stage after death within one second, preserve Time Rewind token policy, invalidate unsafe scene-local rewind coordinates, initialize camera/stage bounds, and prevent scattered raw scene-swap calls.

Without an explicit architecture decision, the GDD set already contains enough named contracts to implement in contradictory ways:

1. `SceneManager` owns scene lifecycle, checkpoint restart, and stage-clear transitions.
2. `TimeRewindController` must be told before the current scene is torn down so it can invalidate scene-local snapshot coordinates while preserving token count.
3. `EchoLifecycleSM` must clear DYING/REWINDING latches and PlayerMovement ephemeral state without PlayerMovement subscribing directly to Scene Manager.
4. `Camera` and `Stage / Encounter` need a post-load anchor and `Rect2` limits before meaningful gameplay resumes.
5. `Menu/Pause` may request restart but must never call raw `SceneTree` transition APIs.

This ADR locks the Foundation boundary so implementation stories do not invent separate transition owners, event timing, or fallback restart logic.

### Constraints

- Godot 4.6 / GDScript, statically typed.
- PC Steam / Steam Deck target, 60 fps locked.
- Pillar 1: checkpoint restart must complete within 60 physics ticks (`1.000 s @ 60 Hz`) under the nominal Tier 1 stage asset load.
- Pillar 2: scene boundary timing must be deterministic; no random spawn selection, unordered scene lifecycle owner, wall-clock gameplay branch, or per-frame SceneManager polling.
- Pillar 4: cold boot to first actionable input must remain under 300 seconds and must not add a press-any-key/options gate.
- Tier 1 scope: single stage slice; async loading, multi-stage routing, and explicit ResourceLoader cache release are deferred to Tier 2.
- Existing registry stance: `scene_phase` is SceneManager-owned; `scene_lifecycle` is a typed-signal contract; `checkpoint_anchor` group name and `scene_manager` group registration are locked.
- SceneManager is an autoload singleton and must not implement `_physics_process` or `_process`.
- The restart path must not be wrapped in coroutine / `await` / `call_deferred()` logic.

### Requirements

- **R-SCENE-01**: All external callers use `SceneManager.change_scene_to_packed(packed: PackedScene, intent: TransitionIntent) -> void`.
- **R-SCENE-02**: Raw `SceneTree.change_scene_to_packed` calls occur only inside SceneManager's transition implementation.
- **R-SCENE-03**: `TransitionIntent` has the Tier 1 values `COLD_BOOT`, `CHECKPOINT_RESTART`, and `STAGE_CLEAR`.
- **R-SCENE-04**: SceneManager owns a linear phase machine: `IDLE -> PRE_EMIT -> SWAPPING -> POST_LOAD -> READY`.
- **R-SCENE-05**: SceneManager owns boundary state: `BOOT_INTRO`, `ACTIVE`, `RESTART_PENDING`, `CLEAR_PENDING`, and terminal `PANIC`.
- **R-SCENE-06**: `scene_will_change()` emits exactly once in `PRE_EMIT`, before scene swap, within the same physics tick as the swap call.
- **R-SCENE-07**: TRC invalidates the rewind ring buffer on `scene_will_change()` and does not lose tokens.
- **R-SCENE-08**: EchoLifecycleSM handles `scene_will_change()` and cascades ephemeral PlayerMovement clear; PlayerMovement direct subscription is forbidden.
- **R-SCENE-09**: POST-LOAD registers the checkpoint anchor after the new scene `_ready()` chain and emits `scene_post_loaded(anchor: Vector2, limits: Rect2)` exactly once.
- **R-SCENE-10**: `limits.size.x > 0 and limits.size.y > 0` is a boot-time assertion before `scene_post_loaded`.
- **R-SCENE-11**: Missing `PackedScene` is a terminal `PANIC` path with no emit and no scene swap.
- **R-SCENE-12**: Same-PackedScene reload is accepted only for `TransitionIntent.CHECKPOINT_RESTART`; same-scene `COLD_BOOT` or `STAGE_CLEAR` is a no-op warning.

## Decision

Adopt a **single SceneManager-owned synchronous lifecycle pipeline** for all Tier 1 scene transitions.

SceneManager is the only owner of raw Godot scene swap authority. Other systems may request a transition only through the typed SceneManager API or through already-approved signals consumed by SceneManager. They do not call `SceneTree.change_scene_to_packed`, `change_scene_to_file`, or threaded load APIs directly.

### Selected Architecture

```text
External trigger
  - Input cold-boot route
  - EchoLifecycleSM state_changed(_, "dead")
  - Damage boss_killed(boss_id)
  - Menu/Pause restart request
        │
        ▼
SceneManager.change_scene_to_packed(packed, intent)
        │
        ├─ Guards:
        │    - PANIC terminal guard
        │    - phase must be IDLE
        │    - packed != null
        │    - same PackedScene allowed only for CHECKPOINT_RESTART
        │
        ▼
PRE_EMIT, tick T
  emit scene_will_change()
    ├─ TRC: _buffer_invalidate(); _tokens unchanged
    ├─ EchoLifecycleSM: O6 cascade; PM ephemeral state clear
    ├─ Audio/VFX/HUD/Collage: local cleanup only, where approved
    └─ no PlayerMovement direct subscription
        │
        ▼
SWAPPING, tick T..T+M
  get_tree().change_scene_to_packed(packed)
        │
        ▼
POST_LOAD, K ticks
  wait for new scene _ready() chain completion via one-shot process_frame signal callback
  register checkpoint anchor from "checkpoint_anchor" group
  read stage_camera_limits: Rect2 from stage root
  assert limits.size.x > 0 and limits.size.y > 0
  emit scene_post_loaded(anchor, limits)
        │
        ├─ Camera: set limit_left/right/top/bottom, clear transient state, snap global_position, reset_smoothing()
        └─ Stage / Encounter: validate metadata and arm encounters after POST-LOAD
        │
        ▼
READY / IDLE-effective
  EchoLifecycleSM self-boots via its _ready() chain; SceneManager never calls EchoLifecycleSM.boot()
```

The binding restart budget is:

```text
SWAPPING(M ticks) + POST_LOAD(K ticks) + 1 READY confirmation tick <= 60 physics ticks
```

`PRE_EMIT` is co-tick with the first swap tick and does not consume a separate budget tick.

### Phase Model

```gdscript
enum Phase { IDLE, PRE_EMIT, SWAPPING, POST_LOAD, READY }
enum TransitionIntent { COLD_BOOT, CHECKPOINT_RESTART, STAGE_CLEAR }
enum BoundaryState { BOOT_INTRO, ACTIVE, RESTART_PENDING, CLEAR_PENDING, PANIC }
```

SceneManager uses this local enum/match machine rather than the general State Machine Framework. The framework is for entity-local reactive machines; SceneManager is one autoload with a single linear transition pipeline.

### Key Interfaces

```gdscript
# SceneManager autoload
signal scene_will_change()
signal scene_post_loaded(anchor: Vector2, limits: Rect2)

enum TransitionIntent { COLD_BOOT, CHECKPOINT_RESTART, STAGE_CLEAR }
enum Phase { IDLE, PRE_EMIT, SWAPPING, POST_LOAD, READY }
enum BoundaryState { BOOT_INTRO, ACTIVE, RESTART_PENDING, CLEAR_PENDING, PANIC }

func change_scene_to_packed(packed: PackedScene, intent: TransitionIntent) -> void:
    # Public request boundary. Applies external guards, then delegates to
    # _trigger_transition(packed, intent) if accepted.
    pass

func _trigger_transition(packed: PackedScene, intent: TransitionIntent) -> void:
    # Internal synchronous phase progression. Owns the one raw
    # get_tree().change_scene_to_packed(packed) call.
    pass
```

### Checkpoint Anchor and Limits Contract

- Level/stage authors tag the active respawn anchor node with `checkpoint_anchor`.
- SceneManager registers anchors after the new scene `_ready()` chain.
- If exactly one anchor exists, its `global_position` becomes `_respawn_position`.
- If multiple anchors exist, SceneManager logs a warning and uses the last registered anchor, preserving the GDD/registry Tier 1 convention.
- If no anchor exists, SceneManager logs an error and falls back to `player.global_position`; this is **not** `PANIC`.
- The stage root exposes `stage_camera_limits: Rect2`.
- `limits.size.x > 0 and limits.size.y > 0` must be asserted before `scene_post_loaded`.

### Error and Guard Policy

| Case | Outcome |
|------|---------|
| `packed == null` | `push_error`, `_boundary_state = PANIC`, `_phase = IDLE`, no emit, no swap. |
| `_boundary_state == PANIC` | Ignore subsequent transition triggers; PANIC is terminal in Tier 1. |
| `_phase != IDLE` | `push_warning`, ignore duplicate transition request. |
| Same `PackedScene` + `CHECKPOINT_RESTART` | Accepted; this is the normal checkpoint reload path. |
| Same `PackedScene` + `COLD_BOOT` or `STAGE_CLEAR` | `push_warning`, no emit, no swap. |
| Restart budget exceeded | `push_warning` and continue to READY rather than freeze/crash; CI nominal budget test remains blocking. |

### Registry Candidates

The following stances already exist in `docs/registry/architecture.yaml` as GDD-owned entries and should be updated to reference ADR-0004 after explicit registry-update approval:

- **State ownership**: `scene_phase -> scene-manager`.
- **Interface contract**: `scene_lifecycle` typed signals:
  - `scene_will_change()`
  - `scene_post_loaded(anchor: Vector2, limits: Rect2)`
- **API decision**: `scene_manager_group_name`.
- **API decision**: `checkpoint_anchor_group_name`.
- **Forbidden pattern**: raw `SceneTree.change_scene_to_packed` calls outside SceneManager.
- **Forbidden pattern**: PlayerMovement direct subscription to `scene_will_change`.

This ADR does **not** update the registry file because `/architecture-decision` requires explicit approval before writing `docs/registry/architecture.yaml`.

## Alternatives Considered

### Alternative 1: SceneManager-Owned Synchronous Lifecycle (Selected)

- **Description**: One autoload owns all raw scene swaps, emits typed lifecycle signals, registers anchors/limits in POST-LOAD, and keeps restart synchronous for Tier 1.
- **Pros**:
  - Gives TRC and EchoLifecycleSM a deterministic pre-unload signal while old scene nodes are still valid.
  - Keeps restart implementation small and testable for the single-stage Tier 1 slice.
  - Avoids async loader complexity before the project has multi-stage asset pressure.
  - Provides a clean grep/static-analysis boundary: raw SceneTree swap calls outside SceneManager are violations.
  - Fits approved Camera and Stage GDD contracts without introducing a global event bus.
- **Cons**:
  - Same-scene reload may be heavier than an in-place checkpoint reset.
  - The exact Godot 4.6 tick cost of `change_scene_to_packed` is asset-size dependent and must be measured.
  - Tier 2 multi-stage memory release will need a follow-up ADR.
- **Selection Reason**: It is the smallest architecture that satisfies Pillar 1 restart speed, Pillar 2 deterministic ordering, and current GDD contracts.

### Alternative 2: Direct Raw SceneTree Calls by Each Requesting System

- **Description**: Input, Menu/Pause, Damage, and/or State Machine systems call `get_tree().change_scene_to_packed()` directly when they need a transition.
- **Pros**:
  - Lower upfront code.
  - Each requester can express its local behavior without a central API.
- **Cons**:
  - No single pre-unload signal owner; TRC buffer invalidation and EchoLifecycleSM O6 cascade become order-dependent.
  - Hard to guarantee exactly one swap per transition.
  - Menu/Pause or Story Intro could accidentally become transition owners.
  - Raw calls are difficult to audit once distributed across features.
- **Rejection Reason**: Contradicts Scene Manager ownership in the registry/GDDs and creates cross-system race risk at the scene boundary.

### Alternative 3: Global Event Bus for Scene Lifecycle

- **Description**: Scene transitions are requested and broadcast through a project event bus rather than direct SceneManager typed signals.
- **Pros**:
  - Flexible for Tier 2+ multi-stage/polish event routing.
  - Can decouple subscribers from direct SceneManager references.
- **Cons**:
  - Adds a new global architectural primitive before ADR-0005 resolves event/signal policy.
  - Makes strict cardinality and call-order tests harder than producer-owned typed signals.
  - Risks turning lifecycle into a generic event channel rather than a Foundation boundary.
- **Rejection Reason**: Premature for Tier 1. ADR-0005 will decide cross-system event policy separately; this ADR keeps direct typed signals for scene lifecycle.

### Alternative 4: Async / Threaded Loader for All Scene Swaps

- **Description**: Use `ResourceLoader.load_threaded_request()` or a loading scene for checkpoint restart and stage clear.
- **Pros**:
  - Better future fit for multi-stage content and texture memory pressure.
  - Can show loading UI or progress indicators.
- **Cons**:
  - Violates Tier 1 GDD rule that the only allowed scene swap API is synchronous `change_scene_to_packed`.
  - Adds progress state, cancellation, loading UI, and memory-release policy before they are needed.
  - Makes the 60-tick checkpoint restart harder to prove for the first playable slice.
- **Rejection Reason**: Deferred to Tier 2 multi-stage gate. The Tier 1 one-stage slice should prove the core loop first.

### Alternative 5: In-Place Checkpoint Reset Instead of Scene Reload

- **Description**: Keep the current scene loaded and reset enemies, projectiles, hazards, triggers, and player position by group cascades.
- **Pros**:
  - Potentially faster than scene reload.
  - Avoids asset reload hiccups.
- **Cons**:
  - Requires explicit reset contracts for every gameplay system.
  - Increases risk of stale enemy/projectile/hazard state after death.
  - Conflicts with ADR-0001 player-only rewind scope unless every non-player state reset is perfectly specified.
  - Too much infrastructure for Tier 1.
- **Rejection Reason**: Deferred to Tier 2 if reload timing or memory measurements fail. Tier 1 reset is scene swap.

## Consequences

### Positive

- One enforceable transition owner for cold boot, checkpoint restart, and stage clear.
- TRC token preservation and ring-buffer invalidation are synchronized before scene unload.
- EchoLifecycleSM remains the only cascade bridge to PlayerMovement ephemeral clear.
- Camera and Stage receive one authoritative anchor/limits payload after POST-LOAD.
- Menu/Pause can request restart without becoming a scene lifecycle owner.
- Test surface is clear: signal cardinality, raw swap cardinality, timing budget, and static grep for forbidden calls.

### Negative

- Scene reload is heavier than an in-place reset and may need asset diet if Steam Deck timing fails.
- `SceneManager.change_scene_to_packed` intentionally shadows the Godot `SceneTree` method name, so code review must distinguish wrapper calls from raw `get_tree().change_scene_to_packed`.
- Registry currently lists the same stances as GDD-owned; a separate approved registry update is needed to make ADR-0004 the authoritative source.
- Tier 2 async loading, title-route semantics, and multi-anchor checkpoint progression remain intentionally unresolved.

### Risks

- **Godot 4.6 scene swap timing varies with asset size**: mitigate with contract-level GUT tests plus Steam Deck Gen 1 real-engine measurement before production lock.
- **Post-load callback ordering bug**: if `scene_post_loaded` fires before `_ready()` chain completion, Camera/Stage consume invalid anchor/limits. Mitigate with one-shot process-frame callback tests and fixture scenes.
- **Raw SceneTree call leaks**: mitigate with static grep in CI against `change_scene_to_packed` / `change_scene_to_file` outside SceneManager.
- **PlayerMovement direct subscription drift**: mitigate with grep for `scene_will_change` connections in PlayerMovement files.
- **Zero-size camera limits**: mitigate with boot-time assert and Stage preflight validation.
- **Budget contract tension**: nominal path budget failure is blocking, but runtime violation logs warning and continues to avoid a frozen screen. Tests must cover both branches separately.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/scene-manager.md` | SceneManager owns scene lifecycle, checkpoint restart, stage clear transitions, and raw `SceneTree.change_scene_to_packed` authority. | Makes SceneManager the sole raw scene-swap owner and locks the wrapper API plus phase/boundary model. |
| `design/gdd/scene-manager.md` | `scene_will_change()` emits exactly once before scene swap, same physics tick. | Locks PRE_EMIT timing and signal cardinality as validation criteria. |
| `design/gdd/scene-manager.md` | Checkpoint restart completes within 60 physics ticks. | Locks the `M + K + 1 <= 60` budget formula and verification obligations. |
| `design/gdd/scene-manager.md` | POST-LOAD registers checkpoint anchor and emits `scene_post_loaded(anchor, limits)`. | Locks anchor/limits registration ordering and post-load signal signature. |
| `design/gdd/time-rewind.md` | TRC invalidates buffer on scene boundary while preserving tokens. | Defines `scene_will_change` as the only trigger and keeps token ownership outside SceneManager. |
| `design/gdd/state-machine.md` | EchoLifecycleSM clears latches/input buffers and cascades PlayerMovement ephemeral clear on scene boundary. | Keeps EchoLifecycleSM as the subscriber; forbids direct PlayerMovement subscription. |
| `design/gdd/camera.md` | Camera snaps to checkpoint anchor and receives stage limits within one tick of `scene_post_loaded`. | Guarantees signal payload and ordering; requires positive `Rect2` limits. |
| `design/gdd/stage-encounter.md` | Stage owns metadata, checkpoint anchors, camera limits, and deterministic encounter activation but not scene swaps. | Keeps Stage as metadata/validation owner and SceneManager as lifecycle owner. |
| `design/gdd/menu-pause.md` | Menu/Pause may request checkpoint restart but must not call raw SceneTree transition APIs. | Provides the approved SceneManager request boundary and static-analysis target. |
| `design/gdd/game-concept.md` | One-hit death must create a sub-second learning/retry loop and deterministic pattern repetition. | Makes restart timing and deterministic scene reset Foundation architecture, not per-feature behavior. |

## Performance Implications

- **CPU**: SceneManager itself does no per-frame polling. Transition work is burst-only. Camera post-load handler must complete within one tick; Stage validation runs before encounter activation.
- **Memory**: Tier 1 uses scene reload and Godot resource caching. No explicit cache release is introduced. Multi-stage texture/cache release requires a Tier 2 ADR.
- **Load Time**: Checkpoint restart path must meet 60 physics ticks under nominal Tier 1 content; real hardware measurement is mandatory before production lock.
- **Network**: None; game is local single-player.

## Migration Plan

No production implementation exists yet. Implementation should proceed in this order after ADR acceptance:

1. Create `SceneManager` autoload with group registration as the first executable line in `_ready()`.
2. Implement `Phase`, `TransitionIntent`, and `BoundaryState` enums.
3. Implement `change_scene_to_packed(packed, intent)` as the only external request API and `_trigger_transition(packed, intent)` as the only raw swap site.
4. Add `scene_will_change()` and `scene_post_loaded(anchor, limits)` typed signals using Callable-style connections.
5. Implement pre-swap guards: PANIC, non-IDLE duplicate, null PackedScene, same-scene non-restart no-op.
6. Implement POST-LOAD one-shot callback, checkpoint anchor registration, stage limits fetch, positive-size assert, and post-load emit.
7. Wire TRC, EchoLifecycleSM, Camera, Stage, and approved presentation cleanup consumers.
8. Add static checks for forbidden raw scene swap calls outside SceneManager and PlayerMovement direct `scene_will_change` subscription.
9. Add GUT unit/integration tests for cardinality, ordering, budget, fallback, and PANIC terminality.
10. Capture Steam Deck Gen 1 real-engine restart timing evidence before pre-production exit.

## Validation Criteria

This decision is correct if the following pass:

- `test_scene_will_change_emits_before_scene_swap`
- `test_scene_will_change_cardinality_one_per_transition`
- `test_change_scene_to_packed_cardinality_one_per_transition`
- `test_scene_post_loaded_emit_cardinality_and_limits`
- `test_restart_budget_within_60_ticks`
- `test_budget_exceeded_warns_and_continues`
- `test_scene_will_change_invalidates_buffer_preserves_tokens`
- `test_panic_state_is_terminal_no_further_transition`
- `test_same_scene_non_restart_noop_and_warns`
- `test_scene_boundary_wins_over_encounter_activation`
- Static grep: no `get_tree().change_scene_to_packed` or `change_scene_to_file` outside SceneManager implementation/test fixtures.
- Static grep: no PlayerMovement `scene_will_change` connection.
- Manual Steam Deck Gen 1 checkpoint restart measurement: 95th percentile restart time <= 60 physics ticks for the Tier 1 stage slice.

## Related Decisions

- `docs/architecture/adr-0001-time-rewind-scope.md` — Player-only rewind / checkpoint model.
- `docs/architecture/adr-0002-time-rewind-storage-format.md` — TRC ring buffer and token/snapshot ownership.
- `docs/architecture/adr-0003-determinism-strategy.md` — Physics frame and deterministic gameplay boundary.
- `docs/architecture/architecture.md` — Required ADR #1 for Scene lifecycle and checkpoint restart architecture.
- `docs/registry/architecture.yaml` — existing GDD-owned stances to be updated after explicit registry approval.
- `design/gdd/scene-manager.md`
- `design/gdd/time-rewind.md`
- `design/gdd/state-machine.md`
- `design/gdd/camera.md`
- `design/gdd/stage-encounter.md`
- `design/gdd/menu-pause.md`
