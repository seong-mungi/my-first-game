# ADR-0008: Player Entity Composition and Lifecycle State Ownership

## Status
Accepted (ratified 2026-05-14)

## Date
2026-05-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Physics / Animation / Core / State Machines / Entity Composition |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/physics.md`, `docs/engine-reference/godot/modules/animation.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md`, `.claude/docs/technical-preferences.md`, `docs/registry/architecture.yaml`, `docs/architecture/architecture.md`, `docs/architecture/adr-0001-time-rewind-scope.md`, `docs/architecture/adr-0002-time-rewind-storage-format.md`, `docs/architecture/adr-0003-determinism-strategy.md`, `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md`, `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md`, `docs/architecture/adr-0007-input-polling-pause-handling-and-ui-focus-boundary.md`, `design/gdd/player-movement.md`, `design/gdd/state-machine.md`, `design/gdd/time-rewind.md`, `design/gdd/player-shooting.md`, `design/gdd/damage.md`, `design/gdd/scene-manager.md`, `design/gdd/input.md` |
| **Post-Cutoff APIs Used** | No new post-cutoff API is introduced. This decision depends on verified Godot 4.6 behavior for `CharacterBody2D`, `process_physics_priority`, `move_and_slide()`, `Node` child composition, typed signals, `Area2D.monitorable`, `AnimationPlayer.play()`, `AnimationPlayer.seek(time, true)`, and `AnimationMixer.callback_mode_method = ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE`. |
| **Verification Required** | (1) ECHO scene root is `PlayerMovement extends CharacterBody2D` with `process_physics_priority = 0`. (2) `EchoLifecycleSM` and `PlayerMovementSM` are sibling child nodes, never Autoloads. (3) `StateMachine.transition_to()` is the only state transition path and direct `current_state` assignment is absent. (4) `PlayerMovement.restore_from_snapshot(snap)` restores only PlayerMovement-owned fields; `WeaponSlot.restore_from_snapshot(snap)` restores `ammo_count`; PlayerMovement ignores `snap.ammo_count`. (5) `_is_restoring` is set before animation seek and remains true through immediate method-track callbacks. (6) `AnimationMixer.callback_mode_method` is immediate at boot. (7) Damage does not poll state-machine state; SM owns ECHO `HurtBox.monitorable` toggles. (8) PlayerMovement does not subscribe directly to `scene_will_change`; scene cleanup cascades through `EchoLifecycleSM`. |

> Engine validation note: primary engine specialist from `.claude/docs/technical-preferences.md` is `godot-specialist`. In this Codex adapter run, no subagent was spawned because the repository adapter limits `Task`/subagent use to explicit user-requested delegation. The draft was validated locally against the pinned Godot 4.6 reference files listed above. No blocking Godot 4.6 entity-composition, `CharacterBody2D`, `Area2D.monitorable`, or `AnimationPlayer.seek()` incompatibility was found. Because animation method-track callback timing is a known high-risk local behavior, direct Godot 4.6 fixture validation of `callback_mode_method = IMMEDIATE` is required before production coding claims are accepted.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Time Rewind Scope; ADR-0002 Time Rewind Storage Format; ADR-0003 Determinism Strategy; ADR-0004 Scene Lifecycle and Checkpoint Restart Architecture; ADR-0005 Cross-System Signal Architecture and Event Ordering; ADR-0007 Input Polling, Pause Handling, and UI Focus Boundary. |
| **Enables** | ECHO scene implementation, PlayerMovement implementation, EchoLifecycleSM / PlayerMovementSM wiring, time-rewind restore tests, WeaponSlot restore integration, Damage host wiring, and static checks for state ownership. |
| **Blocks** | Any production story that creates an outer ECHO wrapper above PlayerMovement, implements state machines as Autoloads, writes PlayerMovement snapshot fields outside PlayerMovement restore paths, writes `ammo_count` outside WeaponSlot, lets Damage poll SM state, adds camera state to `PlayerSnapshot`, or lets TRC/SceneManager/Damage directly transition PlayerMovementSM. |
| **Ordering Note** | This ADR owns ECHO's entity composition and local state ownership. ADR-0002 owns snapshot storage. ADR-0003 owns deterministic priority. ADR-0005 owns cross-system signal order. The next combat ADR owns Damage/HitBox/HurtBox event ownership in detail. |

## Context

### Problem Statement

Echo's GDD set defines ECHO as both a Godot body and a small aggregate of cooperating child systems: movement, lifecycle, weapon, damage boxes, animation, sprite, and restore logic. The architecture must decide which node is the root, which child owns which lifecycle state, and which fields can be restored after a lethal hit. Without a single entity composition decision, implementation stories could accidentally introduce parallel owners for movement, ammo, lifecycle, or invulnerability, breaking rewind determinism and cross-GDD contracts.

### Existing Architectural Stances

- **ECHO root**: `PlayerMovement` is the ECHO root node itself and extends `CharacterBody2D`; there is no outer `ECHO` wrapper above it.
- **Physics priority**: PlayerMovement runs at `process_physics_priority = 0`; TRC runs after it at priority 1; Damage runs at priority 2.
- **State-machine location**: `StateMachine` instances are entity-local child nodes and never Autoloads.
- **Lifecycle ownership**: `EchoLifecycleSM` owns ALIVE / DYING / REWINDING / DEAD lifecycle state and exposes `state_changed`, `can_pause()`, and `should_swallow_pause()`.
- **Movement ownership**: `PlayerMovementSM` owns idle / run / jump / fall / aim_lock / dead movement state. Its dead state reacts to lifecycle signals; it does not own lifecycle truth.
- **Snapshot ownership split**: PlayerMovement owns seven PM fields; WeaponSlot owns `ammo_count`; TRC owns the ring buffer and `captured_at_physics_frame`.
- **Restore boundary**: TRC orchestrates restore by direct method call: PlayerMovement restores PM-owned fields, WeaponSlot restores ammo, then TRC emits `rewind_completed`.
- **Animation guard**: `_is_restoring` guards method-track side effects during restore and requires `AnimationMixer.callback_mode_method = ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE`.
- **Damage boundary**: Damage must not poll SM state. SM controls ECHO `HurtBox.monitorable`.
- **Scene boundary**: PlayerMovement does not subscribe directly to `scene_will_change`; `EchoLifecycleSM` receives scene lifecycle and cascades local ephemeral cleanup to PlayerMovement.

### Constraints

- Tier 1 uses Godot 4.6, statically typed GDScript, and 2D Godot Physics.
- Player movement must remain deterministic at 60 fps.
- Time rewind is player-only; enemies, boss, projectiles, scene state, camera state, and environment are not restored.
- Animation method-track callbacks must not spawn bullets, VFX, or audio during restore.
- `ammo_count` must rewind to the captured value without making PlayerMovement the ammo writer.
- Scene restart and stage clear must clean ephemeral player state without duplicate scene-lifecycle subscriptions.
- Damage invulnerability must remain a state-machine-owned `HurtBox.monitorable` toggle, not a Damage-owned poll.

### Requirements

- **R-PLAYER-01**: ECHO root is `PlayerMovement extends CharacterBody2D`, not a wrapper node containing PlayerMovement.
- **R-PLAYER-02**: PlayerMovement has `process_physics_priority = 0`.
- **R-PLAYER-03**: `EchoLifecycleSM` and `PlayerMovementSM` are sibling child nodes under PlayerMovement.
- **R-PLAYER-04**: State machines are entity-local children and are never Autoloads.
- **R-PLAYER-05**: `EchoLifecycleSM` owns lifecycle state and is the only writer through `transition_to()`.
- **R-PLAYER-06**: `PlayerMovementSM` owns movement state and treats `Dead` as a reactive movement state entered from lifecycle signals or restore branching.
- **R-PLAYER-07**: PlayerMovement owns only these snapshot-visible fields: `global_position`, `velocity`, `facing_direction`, `current_animation_name`, `current_animation_time`, `current_weapon_id`, and `is_grounded`.
- **R-PLAYER-08**: WeaponSlot owns `ammo_count`; PlayerMovement never writes `snap.ammo_count`.
- **R-PLAYER-09**: TRC owns ring-buffer orchestration but does not directly write PlayerMovement or WeaponSlot state except by calling owner restore APIs.
- **R-PLAYER-10**: Animation restore sets `_is_restoring` before `AnimationPlayer.play()` / `seek(time, true)` and prevents method-track side effects.
- **R-PLAYER-11**: PlayerMovement hosts child nodes but does not take over each child's self-state ownership.
- **R-PLAYER-12**: PlayerMovement scene lifecycle cleanup is cascaded through EchoLifecycleSM, not a direct SceneManager subscription.

## Decision

Use a **PlayerMovement root aggregate** with flat child state machines and strict per-field ownership.

`PlayerMovement` is the ECHO scene root and the only node that owns movement-body state. It hosts the ECHO child systems in one Godot subtree, but each child keeps its own state authority:

- `EchoLifecycleSM` owns ECHO lifecycle.
- `PlayerMovementSM` owns movement state.
- `WeaponSlot` owns weapon state and ammo.
- `Damage`, `HitBox`, and `HurtBox` provide combat components and signals; SM owns ECHO invulnerability toggles.
- `AnimationPlayer` and `Sprite2D` are presentation children controlled by PlayerMovement.
- TRC reads owner-exposed values and restores by owner APIs only.

No outer player wrapper, global player state object, Autoload state machine, or cross-system write bus is introduced.

### Architecture Diagram

```text
PlayerMovement (CharacterBody2D, process_physics_priority = 0)
├── EchoLifecycleSM (Node, class_name EchoLifecycleSM extends StateMachine)
│   └── owns ALIVE / DYING / REWINDING / DEAD lifecycle state
├── PlayerMovementSM (Node, class_name PlayerMovementSM extends StateMachine)
│   └── owns idle / run / jump / fall / aim_lock / dead movement state
├── HurtBox (Area2D, ECHO defensive box)
│   └── monitorable toggled only by EchoLifecycleSM states
├── HitBox (Area2D, local contact component if present)
├── Damage (Node, lethal-hit event component)
├── WeaponSlot (Node2D)
│   └── owns ammo_count, active weapon id, firing guards, projectile spawn calls
├── AnimationPlayer
└── Sprite2D
```

```text
Restore path, single physics tick:

TRC.try_consume_rewind()
  ├─ snap = ring[restore_idx]
  ├─ PlayerMovement.restore_from_snapshot(snap)
  │    ├─ _is_restoring = true
  │    ├─ assign PM-owned fields only
  │    ├─ AnimationPlayer.play(snap.current_animation_name)
  │    ├─ AnimationPlayer.seek(snap.current_animation_time, true)
  │    └─ PlayerMovementSM.transition_to(derived_state, {"is_restoring": true}, true)
  ├─ WeaponSlot.restore_from_snapshot(snap)
  │    └─ ammo_count = snap.ammo_count
  └─ rewind_completed.emit(player, restored_to_frame)

Next PlayerMovement._physics_process() top:
  └─ clear prior restore guard after restore-side method-track callbacks were blocked
```

### Key Interfaces

```gdscript
class_name PlayerMovement
extends CharacterBody2D

@onready var lifecycle_sm: EchoLifecycleSM = %EchoLifecycleSM
@onready var movement_sm: PlayerMovementSM = %PlayerMovementSM
@onready var weapon_slot: WeaponSlot = %WeaponSlot
@onready var anim_player: AnimationPlayer = %AnimationPlayer

var _is_restoring: bool = false

func _ready() -> void:
    process_physics_priority = 0
    anim_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
    lifecycle_sm.state_changed.connect(_on_lifecycle_state_changed)
    weapon_slot.weapon_equipped.connect(_on_weapon_equipped)

func _physics_process(delta: float) -> void:
    if _is_restoring:
        _is_restoring = false
    # input phase, transition phase, velocity phase, move_and_slide phase,
    # post-movement cache phase.

func restore_from_snapshot(snap: PlayerSnapshot) -> void:
    _is_restoring = true

    global_position = snap.global_position
    velocity = snap.velocity
    facing_direction = snap.facing_direction
    _current_weapon_id = snap.current_weapon_id
    _is_grounded = snap.is_grounded

    anim_player.play(snap.current_animation_name)
    anim_player.seek(snap.current_animation_time, true)

    movement_sm.transition_to(
        _derive_movement_state_from_snapshot(snap),
        {"is_restoring": true},
        true
    )
    # snap.ammo_count is intentionally ignored: WeaponSlot owns ammo restoration.
```

```gdscript
class_name WeaponSlot
extends Node2D

var ammo_count: int = 0

func restore_from_snapshot(snap: PlayerSnapshot) -> void:
    ammo_count = snap.ammo_count
```

```gdscript
class_name EchoLifecycleSM
extends StateMachine

signal state_changed(from: StringName, to: StringName)

func can_pause() -> bool:
    return current_state.name not in [&"DYING", &"REWINDING"]

func should_swallow_pause() -> bool:
    return current_state.name in [&"DYING", &"REWINDING"]
```

### State Ownership Matrix

| State / field | Owner | Read interface | Write path |
|---------------|-------|----------------|------------|
| ECHO lifecycle state | `EchoLifecycleSM` | `state_changed`, `current_state.name`, `can_pause()`, `should_swallow_pause()` | `EchoLifecycleSM.transition_to()` only |
| Movement state | `PlayerMovementSM` | state name / owner-local query | `PlayerMovementSM.transition_to()` only |
| `global_position` | `PlayerMovement` | `PlayerMovement.global_position` | PlayerMovement movement step or PlayerMovement restore only |
| `velocity` | `PlayerMovement` | `PlayerMovement.velocity` | PlayerMovement movement step or PlayerMovement restore only |
| `facing_direction` | `PlayerMovement` | read-only gameplay property | PlayerMovement input/aim phase or PlayerMovement restore only |
| `current_animation_name` | `PlayerMovement` / `AnimationPlayer` | snapshot capture reads current animation | PlayerMovement animation update or PlayerMovement restore only |
| `current_animation_time` | `PlayerMovement` / `AnimationPlayer` | snapshot capture reads playback time | PlayerMovement animation update or PlayerMovement restore only |
| `current_weapon_id` | PlayerMovement cache from WeaponSlot | read-only PM property | `WeaponSlot.weapon_equipped` subscriber or PlayerMovement restore only |
| `is_grounded` | `PlayerMovement` | read-only PM property | PlayerMovement movement step or PlayerMovement restore only |
| `ammo_count` | `WeaponSlot` | `WeaponSlot.ammo_count` read by TRC/HUD | WeaponSlot fire/reload/set-active logic or WeaponSlot restore only |
| `captured_at_physics_frame` | TRC | PlayerSnapshot field | TRC capture only |
| ECHO `HurtBox.monitorable` | EchoLifecycleSM state enter/exit | Godot collision behavior / optional read-only diagnostics | RewindingState enter/exit only |

### Child Ownership Matrix

| Child | Hosted by | Owns | Host may do | Host must not do |
|-------|-----------|------|-------------|------------------|
| `EchoLifecycleSM` | PlayerMovement | lifecycle state and death/rewind flow | connect to `state_changed`; call local APIs when bootstrapping | assign `current_state` directly |
| `PlayerMovementSM` | PlayerMovement | movement state | call local transition API from PM-owned movement/restore branches | let Damage/TRC/SceneManager call foreign transitions |
| `WeaponSlot` | PlayerMovement | ammo, active weapon, firing guards | read `weapon_equipped`; keep `_current_weapon_id` cache | write `ammo_count` or `_active_id` directly |
| `Damage` | PlayerMovement | lethal-hit pending cause and combat event emission | receive signals; let SM call `commit_death()` / `cancel_pending_death()` / `start_hazard_grace()` | poll SM state or transition SMs |
| `HurtBox` | PlayerMovement | defensive collision surface | expose to SM for `monitorable` toggle | let Damage own i-frame state |
| `HitBox` | PlayerMovement / projectile hosts | offensive collision surface | set host/cause according to Damage GDD | bypass Damage signal contracts |
| `AnimationPlayer` | PlayerMovement | animation playback timeline | play/seek from PlayerMovement | run deferred method callbacks during restore |
| `Sprite2D` | PlayerMovement | visual sprite state | render current animation frame | own gameplay state |

### Forbidden Paths

- No outer `ECHO` wrapper node above PlayerMovement in Tier 1.
- No state-machine Autoloads for ECHO lifecycle or movement.
- No direct assignment to `current_state`.
- No foreign `transition_to()` calls across entity boundaries.
- No TRC direct writes to `PlayerMovement.global_position`, `velocity`, `facing_direction`, `current_weapon_id`, `is_grounded`, animation name, or animation time.
- No PlayerMovement writes to `snap.ammo_count` or `WeaponSlot.ammo_count`.
- No direct `ammo_count =` outside WeaponSlot and PlayerSnapshot data construction.
- No Damage polling of `EchoLifecycleSM.current_state`.
- No Damage-owned i-frame boolean separate from `HurtBox.monitorable`.
- No camera state in `PlayerSnapshot`.
- No PlayerMovement direct `scene_will_change` subscription.
- No animation method-track callback with side effects that lacks an `_is_restoring` early return.

## Alternatives Considered

### Alternative 1: PlayerMovement root aggregate with flat child state machines

- **Description**: Use `PlayerMovement extends CharacterBody2D` as the ECHO root. Put EchoLifecycleSM, PlayerMovementSM, Damage, HurtBox, HitBox, WeaponSlot, AnimationPlayer, and Sprite2D under it as child nodes. Enforce per-field ownership and owner-only restore APIs.
- **Pros**: Matches approved GDDs and registry; avoids wrapper/body drift; preserves deterministic priority; makes Godot scene ownership explicit; keeps lifecycle, movement, weapon, and damage state separated; makes restore tests direct.
- **Cons**: PlayerMovement hosts many children and needs strong static checks to avoid becoming a god object.
- **Decision**: Selected.

### Alternative 2: Outer ECHO wrapper with PlayerMovement child body

- **Description**: Create an `Echo` Node2D root that owns child PlayerMovement, state machines, weapon, and damage components.
- **Pros**: Visually separates "entity root" from "movement body"; could make presentation grouping easier.
- **Cons**: Contradicts `player_movement_state` registry notes and Player Movement GDD; introduces a second owner of transform/lifecycle; risks wrapper vs body global position drift; complicates TRC capture and scene anchoring.
- **Rejection Reason**: The approved architecture locks PlayerMovement as the ECHO root `CharacterBody2D`.

### Alternative 3: Autoload lifecycle and movement state machines

- **Description**: Place EchoLifecycleSM and/or PlayerMovementSM in project Autoloads and reference the ECHO node from global state.
- **Pros**: Easy global lookup from UI or tools.
- **Cons**: Directly violates state-machine GDD and registry; breaks per-entity composition; prevents multiple-player/test-instance fixtures; creates stale references across scene restart.
- **Rejection Reason**: Entity-local state machines are required, and state-machine Autoload is a forbidden pattern.

### Alternative 4: Single combined player state machine

- **Description**: Collapse lifecycle and movement into one state machine with states such as `alive_run`, `dying`, `rewinding`, `dead`.
- **Pros**: One state owner and fewer child nodes.
- **Cons**: Mixes orthogonal lifecycle and movement concerns; explodes state count; makes pause/rewind/death logic compete with movement transitions; weakens traceability to TR-state-003 and DEC-PM-1.
- **Rejection Reason**: Flat sibling state machines preserve separate lifecycle and movement ownership while allowing explicit signal-driven synchronization.

### Alternative 5: TRC writes raw fields directly during rewind

- **Description**: Let TimeRewindController set PlayerMovement and WeaponSlot fields directly when restoring a snapshot.
- **Pros**: Fewer method calls and simple procedural code.
- **Cons**: Violates owner-only state restoration; bypasses animation guard setup; risks PM/Weapon ordering drift; defeats static ownership checks.
- **Rejection Reason**: ADR-0002 and the registry require owner restore APIs.

## Consequences

### Positive

- ECHO's Godot scene tree matches the GDD composition tree exactly.
- Snapshot-visible fields have one writer each.
- Time rewind restore can be tested as a short atomic sequence.
- Lifecycle, movement, weapon, and damage state can evolve without silent cross-writes.
- Scene restart cleanup has a single cascade path through EchoLifecycleSM.
- Damage i-frame behavior remains Godot-native through `HurtBox.monitorable`, not duplicated in Damage logic.

### Negative

- PlayerMovement becomes a high-coordination host node and needs clear child ownership tests.
- Implementers must remember that "hosted by PlayerMovement" does not mean "owned by PlayerMovement."
- `_is_restoring` timing is subtle because Godot animation method callbacks depend on `callback_mode_method`.
- Static checks are required to keep forbidden cross-writes from entering later stories.

### Risks

- **R1: PlayerMovement god-object drift** — Mitigation: child ownership matrix, file-level static checks, and review rule that PlayerMovement may host but not own child self-state.
- **R2: Animation callbacks escape restore guard** — Mitigation: boot assert for `ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE` and integration test around `seek(time, true)`.
- **R3: Weapon ammo accidentally restored by PlayerMovement** — Mitigation: PlayerMovement restore test with `snap.ammo_count` mutation proving no PM write; WeaponSlot restore test proving ammo restoration.
- **R4: Lifecycle and movement transitions race** — Mitigation: state-machine signal order tests and explicit restore-derived movement-state transition inside PlayerMovement restore.
- **R5: Scene restart duplicate cleanup** — Mitigation: grep/static check that PlayerMovement does not connect to `scene_will_change`; EchoLifecycleSM owns O6 cascade.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/state-machine.md` | Entity-local `StateMachine` nodes; never Autoload state machines. | Requires EchoLifecycleSM and PlayerMovementSM as PlayerMovement children and bans state-machine Autoloads. |
| `design/gdd/state-machine.md` | ECHO lifecycle states ALIVE / DYING / REWINDING / DEAD drive rewind/death flow. | Assigns lifecycle ownership exclusively to EchoLifecycleSM and exposes `state_changed`, `can_pause()`, and `should_swallow_pause()`. |
| `design/gdd/player-movement.md` | ECHO root is `CharacterBody2D`, process priority 0. | Locks `PlayerMovement extends CharacterBody2D` as root and requires `process_physics_priority = 0`. |
| `design/gdd/player-movement.md` | PlayerMovementSM six-state set and dead state behavior. | Keeps PlayerMovementSM as sibling of EchoLifecycleSM and makes `Dead` a movement state reactive to lifecycle signals/restore branches. |
| `design/gdd/player-movement.md` | Snapshot-visible movement state restored only through `restore_from_snapshot()`. | Defines owner-only PlayerMovement restore API and bans TRC/raw external writes. |
| `design/gdd/player-movement.md` | Animation method-track side effects guarded during restore. | Requires `_is_restoring` before animation seek and immediate callback mode at boot. |
| `design/gdd/time-rewind.md` | TRC reads PM fields and WeaponSlot ammo, then restores by owner APIs. | Defines the atomic restore order: PlayerMovement restore, WeaponSlot restore, `rewind_completed`. |
| `design/gdd/player-shooting.md` | `ammo_count` is WeaponSlot single-writer and restored by TRC orchestration. | Assigns ammo ownership to WeaponSlot and requires PlayerMovement to ignore `snap.ammo_count`. |
| `design/gdd/damage.md` | Damage does not poll SM state; SM controls ECHO `HurtBox.monitorable`. | Keeps Damage as a child component while lifecycle SM owns invulnerability toggles. |
| `design/gdd/scene-manager.md` | Scene changes clear player ephemeral state through lifecycle cascade. | Forbids PlayerMovement direct `scene_will_change` subscription and routes cleanup through EchoLifecycleSM O6. |
| `design/gdd/input.md` | Gameplay input is read in deterministic physics phases. | Keeps PlayerMovement/WeaponSlot input in `_physics_process`; entity composition does not introduce callback input readers. |

## Performance Implications

- **CPU**: No additional per-frame scheduling layer. PlayerMovement remains priority 0; sibling child state machines run within normal Godot node processing. Restore cost is one direct PM method, one direct WeaponSlot method, animation seek, and one movement-state transition in a single physics tick.
- **Memory**: No new persistent data structure beyond the existing PlayerSnapshot ring buffer. The PlayerMovement subtree adds normal Godot child nodes already required by GDDs.
- **Load Time**: No new dynamic loading path. ECHO scene instantiates as one subtree.
- **Network**: None; Echo is local single-player Tier 1.

## Migration Plan

1. Create `PlayerMovement.tscn` with `PlayerMovement (CharacterBody2D)` as root.
2. Add sibling child nodes `EchoLifecycleSM`, `PlayerMovementSM`, `HurtBox`, `HitBox`, `Damage`, `WeaponSlot`, `AnimationPlayer`, and `Sprite2D`.
3. Set `PlayerMovement.process_physics_priority = 0` and assert it at boot.
4. Set `AnimationPlayer.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE` and assert it at boot.
5. Implement `PlayerMovement.restore_from_snapshot(snap)` with PM-owned field assignments only.
6. Implement `WeaponSlot.restore_from_snapshot(snap)` for `ammo_count`.
7. Wire Damage signals in host `_ready()` in the order required by ADR-0005 and Damage GDD.
8. Wire EchoLifecycleSM scene lifecycle cleanup and PlayerMovement ephemeral cleanup cascade.
9. Add static checks for forbidden direct writes, forbidden Autoload state machines, forbidden foreign transitions, and forbidden PlayerMovement direct scene subscription.

## Validation Criteria

- `test_echo_scene_tree_shape_player_movement_root`: root is `PlayerMovement extends CharacterBody2D`; there is no outer `Echo` gameplay wrapper.
- `test_player_movement_process_priority_zero`: PlayerMovement priority is 0 at boot.
- `test_state_machines_are_children_not_autoloads`: EchoLifecycleSM and PlayerMovementSM are descendants of PlayerMovement and absent from Autoloads.
- `test_echo_lifecycle_and_player_movement_sm_are_siblings`: lifecycle and movement state machines share PlayerMovement parent.
- `test_transition_api_only_static`: no direct `current_state =` assignments outside StateMachine internals.
- `test_no_cross_entity_sm_transition_call_static`: foreign systems do not call another entity's `transition_to()`.
- `test_player_movement_restore_assigns_only_pm_owned_fields`: PlayerMovement restore mutates only the seven PM-owned fields and movement state.
- `test_player_movement_ignores_snap_ammo_count`: changing `snap.ammo_count` does not change ammo during PM restore.
- `test_weapon_slot_restore_assigns_ammo_count`: WeaponSlot restore sets `ammo_count` to the snapshot value.
- `test_trc_restore_order_atomic`: TRC calls PM restore, then WeaponSlot restore, then emits `rewind_completed` in one physics tick.
- `test_restore_sets_is_restoring_until_next_physics_tick`: guard is true during restore callbacks and clears at the next PlayerMovement physics tick top.
- `test_animation_callback_mode_immediate_boot_assert`: AnimationPlayer callback mode is immediate.
- `test_animation_method_tracks_guard_is_restoring_static`: method-track callback handlers with side effects early-return when `_is_restoring` is true.
- `test_player_movement_dead_reacts_to_lifecycle_state_changed`: PlayerMovementSM dead state is entered from lifecycle `state_changed` and restore branches only.
- `test_no_pm_direct_damage_trc_scene_signal_subscriptions_static`: PlayerMovement does not directly subscribe to Damage lethal signals, TRC rewind signals, or SceneManager `scene_will_change`.
- `test_no_camera_state_in_player_snapshot_static`: `PlayerSnapshot` contains no camera fields.
- `test_damage_does_not_poll_sm_state_static`: Damage code does not read `EchoLifecycleSM.current_state`.
- `test_scene_will_change_cascade_clears_pm_ephemeral_via_lifecycle_sm`: scene cleanup enters EchoLifecycleSM O6 cascade and calls PlayerMovement ephemeral cleanup exactly once.

## Related Decisions

- `docs/architecture/adr-0001-time-rewind-scope.md`
- `docs/architecture/adr-0002-time-rewind-storage-format.md`
- `docs/architecture/adr-0003-determinism-strategy.md`
- `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md`
- `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md`
- `docs/architecture/adr-0007-input-polling-pause-handling-and-ui-focus-boundary.md`
- `docs/architecture/architecture.md`
- `design/gdd/player-movement.md`
- `design/gdd/state-machine.md`
- `design/gdd/time-rewind.md`
- `design/gdd/player-shooting.md`
- `design/gdd/damage.md`
- `design/gdd/scene-manager.md`
- `docs/registry/architecture.yaml`

## Registry Candidates

The following candidates should be reviewed before any explicit registry write:

- **EXISTING referenced_by update**: `state_ownership.player_movement_state` → add ADR-0008 as composition and lifecycle ownership authority.
- **EXISTING referenced_by update**: `state_ownership.echo_lifecycle_state` → add ADR-0008 as lifecycle host/owner authority.
- **EXISTING referenced_by update**: `state_ownership.ammo_count` → add ADR-0008 as entity-composition boundary; keep WeaponSlot as owner.
- **EXISTING referenced_by update**: `interfaces.player_movement_snapshot` → add ADR-0008 as restore boundary authority.
- **NEW interface contract candidate**: `player_entity_composition` → PlayerMovement root aggregate with sibling EchoLifecycleSM / PlayerMovementSM and child ownership matrix.
- **NEW interface contract candidate**: `player_movement_restore_contract` → PlayerMovement restores seven PM-owned fields, sets `_is_restoring`, uses immediate animation callbacks, ignores `ammo_count`.
- **NEW forbidden pattern candidate**: `outer_echo_wrapper_root` → gameplay ECHO wrapper above PlayerMovement is forbidden in Tier 1.
- **EXISTING forbidden pattern referenced_by updates**: `direct_player_state_write_during_rewind`, `direct_current_state_assignment`, `state_machine_in_autoload`, `cross_entity_sm_transition_call`, `damage_polls_sm_state`, `movement_float_accumulator`, `direct_ammo_count_write_outside_weapon_slot`, `camera_state_in_player_snapshot`.

`docs/registry/architecture.yaml` was not modified by this ADR authoring pass because registry writes require explicit user approval.
