# ADR-0009: Damage, HitBox/HurtBox, and Combat Event Ownership

## Status
Accepted (ratified 2026-05-14)

## Date
2026-05-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Physics / Combat / Signals / Collision / State Boundaries |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/physics.md`, `docs/engine-reference/godot/modules/animation.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md`, `.claude/docs/technical-preferences.md`, `docs/registry/architecture.yaml`, `docs/architecture/architecture.md`, `docs/architecture/adr-0001-time-rewind-scope.md`, `docs/architecture/adr-0002-time-rewind-storage-format.md`, `docs/architecture/adr-0003-determinism-strategy.md`, `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md`, `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md`, `docs/architecture/adr-0008-player-entity-composition-and-lifecycle-state-ownership.md`, `design/gdd/damage.md`, `design/gdd/state-machine.md`, `design/gdd/time-rewind.md`, `design/gdd/player-movement.md`, `design/gdd/player-shooting.md`, `design/gdd/enemy-ai.md`, `design/gdd/boss-pattern.md`, `design/gdd/stage-encounter.md`, `design/gdd/scene-manager.md`, `design/gdd/hud.md`, `design/gdd/vfx-particle.md`, `design/gdd/audio.md`, `design/gdd/camera.md` |
| **Post-Cutoff APIs Used** | No new post-cutoff API is introduced. This decision depends on verified Godot 4.6 behavior for `Area2D`, `collision_layer`, `collision_mask`, `monitoring`, `monitorable`, `area_entered`, typed signals with Callable-style `signal.connect(callable)`, `Node.queue_free()`, `Engine.get_physics_frames()`, and the ADR-0003 priority ladder. |
| **Verification Required** | (1) `HitBox extends Area2D` and `HurtBox extends Area2D` match the locked properties and signals. (2) Godot 4.6 collision fixtures prove `HitBox.monitoring AND HurtBox.monitorable AND mask/layer AND shape_overlap` is the effective collision predicate. (3) `HurtBox.monitorable = false` suppresses `HitBox.area_entered`; toggling `HurtBox.monitoring` is not used for i-frames. (4) The 6-bit layer/mask matrix exactly matches Damage GDD C.2. (5) ECHO, enemy, boss, and hazard signal emit order matches this ADR. (6) Damage code does not read state-machine state. (7) Boss phase transition is monotonic +1 per physics tick. (8) Damage cumulative cost remains ≤ 2.5 ms on Steam Deck-equivalent measurement in the specified worst-case scene. |

> Engine validation note: primary engine specialist from `.claude/docs/technical-preferences.md` is `godot-specialist`. In this Codex adapter run, no subagent was spawned because the repository adapter limits `Task`/subagent use to explicit user-requested delegation. The draft was validated locally against the pinned Godot 4.6 reference files listed above and the already-locked Damage GDD's Godot 4.6 Area2D semantics. No blocking Godot 4.6 combat/collision API incompatibility was found. Because `Area2D.monitorable` semantics and signal flush timing are high-risk gameplay behaviors, direct Godot 4.6 physics fixtures are required before production coding claims are accepted.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Time Rewind Scope; ADR-0002 Time Rewind Storage Format; ADR-0003 Determinism Strategy; ADR-0004 Scene Lifecycle and Checkpoint Restart Architecture; ADR-0005 Cross-System Signal Architecture and Event Ordering; ADR-0008 Player Entity Composition and Lifecycle State Ownership. |
| **Enables** | Damage/HitBox/HurtBox implementation, ECHO lethal-hit flow, standard enemy death flow, boss phase/kill flow, hazard cause handling, combat signal tests, Stage Area2D budget validation, HUD/VFX/Audio/Camera combat consumers, and SceneManager `boss_killed` stage-clear wiring. |
| **Blocks** | Any production story that implements hit detection, enemy death, boss phase transitions, hazard lethal volumes, ECHO i-frames, boss kill stage clear, or combat presentation before accepting the Damage/HitBox/HurtBox ownership boundary. |
| **Ordering Note** | ADR-0003 owns physics priority. ADR-0005 owns the general direct-signal model. This ADR owns combat-specific component contracts, collision layer assignment, cause taxonomy, Damage invocation APIs, and same-frame combat emit order. |

## Context

### Problem Statement

Echo's combat loop is intentionally binary: ECHO, standard enemies, hazards, and boss attacks are resolved as hit/no-hit events, not numeric health accounting. The implementation still needs one architecture decision that assigns authority for the `Area2D` hit components, collision layers, cause taxonomy, lethal-hit grace, standard enemy kill signals, boss phase signals, and downstream presentation events.

Without this decision, separate implementation stories could accidentally let enemies decide player death directly, let Damage poll lifecycle state, expose boss remaining hits to HUD, add a second boss-kill signal, or change collision layers ad hoc. Any of those would break the one-hit clarity, deterministic rewind learning loop, and no-HP-bar design.

### Existing Architectural Stances

- **Damage component authority**: Damage owns the `HitBox` / `HurtBox` component contract and combat signal catalog.
- **Direct typed signals**: Tier 1 uses producer-owned Godot signals; no global gameplay event bus.
- **Physics scheduling**: Damage runs at `process_physics_priority = 2`; PlayerMovement runs at 0, TRC at 1, enemies/bosses at 10, projectiles at 20.
- **Projectile/body types**: ECHO and enemies use `CharacterBody2D`; gameplay projectiles use script-stepped `Area2D`; `RigidBody2D` is cosmetic-only.
- **ECHO i-frame authority**: `EchoLifecycleSM` toggles ECHO `HurtBox.monitorable`; Damage must not poll state-machine state.
- **ECHO death flow**: Damage emits `lethal_hit_detected(cause)` and `player_hit_lethal(cause)` in frame N; SM controls the 12-frame grace and calls Damage's direct invocation APIs.
- **Boss phase state**: Boss Pattern owns `phase_hp_table`, phase scripts, and boss state; Damage owns the hit/phase signal contract and phase transition procedure.
- **Scene clear**: `boss_killed(boss_id)` is the single stage-clear trigger consumed by SceneManager.
- **Cause taxonomy**: Damage owns append-only cause labels; Enemy AI, Boss Pattern, and Stage assign labels at host instantiation time.
- **Known registry drift**: `docs/registry/architecture.yaml` currently has a stale `damage_signals.emit_ordering_contract` line that places `hurtbox_hit` after Damage emits. The locked `damage.md` and ADR-0005 record `HurtBox.hurtbox_hit(cause)` as the preceding source emit before Damage handler-specific emits. This ADR follows the locked GDD/ADR ordering and lists a registry correction candidate; it does not mutate the registry without approval.

### Constraints

- Godot 4.6 `Area2D` collision behavior must be verified locally, not assumed from training data.
- Damage must remain unidirectional: it emits signals and exposes idempotent APIs, but it does not call external systems.
- State-machine invulnerability must be expressed through `HurtBox.monitorable`, not a Damage-owned state check.
- Boss feedback must not expose `hits_remaining`, hit counters, damage numbers, or an HP bar.
- All cause labels that affect player learning must be stable `StringName` values.
- Stage and Enemy AI must not silently remove collision actors to satisfy runtime budgets; Area2D budget violations are authoring/preflight errors.
- Tier 1 must remain solo-scope-friendly: no combat event bus, no full health/damage system, no physics direct-query combat path.

### Requirements

- **R-DMG-01**: Damage provides `class_name HitBox extends Area2D` and `class_name HurtBox extends Area2D`.
- **R-DMG-02**: `HitBox.area_entered(area)` is the single active fire point; it emits `(area as HurtBox).hurtbox_hit(self.cause)` only after `area is HurtBox`.
- **R-DMG-03**: `HurtBox.hurtbox_hit(cause)` is emitted exactly once per valid HitBox/HurtBox contact and is not re-emitted by Damage handlers.
- **R-DMG-04**: Collision layer assignment uses the locked 6-bit matrix from Damage GDD C.2.
- **R-DMG-05**: ECHO self-damage and enemy friendly fire are blocked by collision masks, not runtime cause checks.
- **R-DMG-06**: Damage owns `lethal_hit_detected`, `player_hit_lethal`, `death_committed`, `enemy_killed`, `boss_hit_absorbed`, `boss_pattern_interrupted`, `boss_phase_advanced`, and `boss_killed`.
- **R-DMG-07**: ECHO death uses the two-stage Damage/SM flow: first hit starts pending death; SM either commits or cancels it.
- **R-DMG-08**: Damage exposes `commit_death()`, `cancel_pending_death()`, and `start_hazard_grace()` as idempotent external-to-Damage calls.
- **R-DMG-09**: Damage never reads `EchoLifecycleSM` or any `StateMachine` state.
- **R-DMG-10**: Boss phase transitions advance at most one phase per physics tick.
- **R-DMG-11**: `boss_hit_absorbed` never exposes remaining hits; HUD must not receive hit-count data.
- **R-DMG-12**: Cause labels are assigned by hosts at instantiation time and are append-only after Tier 1 lock.

## Decision

Use a **Damage-owned component and signal architecture**:

1. Damage owns reusable `HitBox` and `HurtBox` `Area2D` component classes.
2. Host systems instantiate the components in their own scenes and set layer/mask/cause values from the Damage-owned tables.
3. HitBox is the active scanner; HurtBox is the passive receiver.
4. The first source emit is always `HurtBox.hurtbox_hit(cause)` from `HitBox.area_entered`.
5. Host-specific handlers convert `hurtbox_hit` into exactly one of the locked combat outcomes:
   - ECHO: pending lethal hit, rewind grace, and eventual death commit/cancel.
   - Standard enemy: one-hit kill and `enemy_killed`.
   - Boss: phase hit absorb, phase advance, or terminal `boss_killed`.
   - Hazard: same ECHO lethal path with hazard cause labels.
6. Damage never polls lifecycle state; SM controls ECHO `HurtBox.monitorable`.
7. Boss Pattern owns phase scripts and phase table values, but the boss host must use the Damage-compatible phase transition procedure and signal signatures.

No numeric player/enemy HP system, global combat event bus, PhysicsServer direct-query path, Damage-owned i-frame state, or HUD-facing boss hit count is introduced.

### Architecture Diagram

```text
Host systems instantiate Damage components:

PlayerMovement/ECHO
  ├── HurtBox (L1, masks L4/L5)
  ├── HitBox  (optional local contact component)
  └── Damage  (pending lethal cause + ECHO damage signals)

Player Shooting projectile
  └── HitBox (L2, masks L3/L6, cause = &"")

Standard enemy
  └── HurtBox (L3, masks L2)

Enemy / boss projectile
  └── HitBox (L4, masks L1, cause = projectile_* label)

Stage hazard
  └── HitBox (L5, masks L1, cause = hazard_* label)

Boss host
  └── HurtBox (L6, masks L2)
```

```text
Generic contact:

HitBox.area_entered(area)
  ├─ guard: area is HurtBox
  └─ area.hurtbox_hit.emit(self.cause)
       ├─ ECHO Damage handler
       ├─ Standard enemy handler
       ├─ Boss host handler
       └─ Presentation observers of hurtbox_hit
```

### Collision Layer Matrix

| Layer bit | Name | Host | Masks |
|-----------|------|------|-------|
| 1 | `echo_hurtbox` | ECHO body / PlayerMovement | 4, 5 |
| 2 | `echo_projectile_hitbox` | Player projectile | 3, 6 |
| 3 | `enemy_hurtbox` | Standard enemy | 2 |
| 4 | `enemy_projectile_hitbox` | Enemy projectile and boss projectile | 1 |
| 5 | `hazard_hitbox` | Stage hazard | 1 |
| 6 | `boss_hurtbox` | Boss Pattern host | 2 |

Runtime bitmask values must use Godot's 1-indexed layer convention:

- L1 = `1`
- L2 = `2`
- L3 = `4`
- L4 = `8`
- L5 = `16`
- L6 = `32`
- ECHO Projectile mask L3/L6 = `4 | 32 = 36`

### Key Interfaces

```gdscript
class_name HitBox
extends Area2D

@export var cause: StringName = &""
@export var host: Node

func _ready() -> void:
    monitoring = true
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    if not area is HurtBox:
        return
    (area as HurtBox).hurtbox_hit.emit(cause)
```

```gdscript
class_name HurtBox
extends Area2D

signal hurtbox_hit(cause: StringName)

@export var entity_id: StringName

func _ready() -> void:
    # HurtBox is passive; its detectability is controlled by monitorable.
    monitoring = true
    monitorable = true
```

```gdscript
class_name Damage
extends Node

signal lethal_hit_detected(cause: StringName)
signal player_hit_lethal(cause: StringName)
signal death_committed(cause: StringName)
signal enemy_killed(enemy_id: StringName, cause: StringName)
signal boss_hit_absorbed(boss_id: StringName, phase_index: int)
signal boss_pattern_interrupted(boss_id: StringName, prev_phase_index: int)
signal boss_phase_advanced(boss_id: StringName, new_phase: int)
signal boss_killed(boss_id: StringName)

var _pending_cause: StringName = &""
var _hazard_grace_remaining: int = 0

func _on_echo_hurtbox_hit(cause: StringName) -> void:
    if _pending_cause != &"":
        return
    if _should_skip_hazard(cause):
        return
    _pending_cause = cause
    lethal_hit_detected.emit(cause)
    player_hit_lethal.emit(cause)

func commit_death() -> void:
    if _pending_cause == &"":
        return
    var cause := _pending_cause
    _pending_cause = &""
    death_committed.emit(cause)

func cancel_pending_death() -> void:
    _pending_cause = &""

func start_hazard_grace() -> void:
    _hazard_grace_remaining = hazard_grace_frames + 1
```

### Emit Ordering Contracts

#### ECHO hurt path

```text
HitBox.area_entered(echo_hurtbox)
  1. echo_hurtbox.hurtbox_hit.emit(cause)          # source emit from HitBox script
  2. Damage._on_echo_hurtbox_hit(cause)
       a. if _pending_cause != &"": return
       b. if _should_skip_hazard(cause): return
       c. _pending_cause = cause
       d. lethal_hit_detected.emit(cause)          # TRC frame-N cache
       e. player_hit_lethal.emit(cause)            # EchoLifecycleSM DYING transition
```

Connect order on ECHO host must put TRC first for `lethal_hit_detected` and EchoLifecycleSM first for `player_hit_lethal`; all connections use `CONNECT_DEFAULT`.

#### Death commit / cancel path

```text
EchoLifecycleSM.DyingState
  ├─ rewind consumed before grace expires
  │    └─ damage.cancel_pending_death()
  └─ grace expires
       └─ damage.commit_death()
              └─ death_committed.emit(cause)
```

Both direct APIs are idempotent. Calling them when `_pending_cause == &""` does not emit errors or duplicate signals.

#### Standard enemy path

```text
ECHO Projectile HitBox.area_entered(enemy_hurtbox)
  ├─ enemy_hurtbox.hurtbox_hit.emit(cause)
  └─ EnemyHost enters DEAD once
       ├─ disables collision / HurtBox receive path
       ├─ emits enemy_killed(enemy_id, cause) exactly once
       └─ queues deterministic cleanup
```

Multi-enemy same-frame `enemy_killed` order is scene-tree order created by Stage/Encounter deterministic spawn ordering. It is not distance-sorted or dictionary-sorted at death time.

#### Boss path

```text
ECHO Projectile HitBox.area_entered(boss_hurtbox)
  ├─ boss_hurtbox.hurtbox_hit.emit(cause)
  └─ BossHost._on_hurtbox_hit(cause)
       1. if _phase_advanced_this_frame: return
       2. phase_hits_remaining -= 1
       3. if phase_hits_remaining > 0:
            boss_hit_absorbed.emit(boss_id, phase_index)
          elif phase_index < final_phase_index:
            boss_pattern_interrupted.emit(boss_id, phase_index)
            phase_index += 1
            phase_hits_remaining = phase_hp_table[phase_index]
            _phase_advanced_this_frame = true
            boss_phase_advanced.emit(boss_id, phase_index)
          else:
            boss_pattern_interrupted.emit(boss_id, phase_index)
            _phase_advanced_this_frame = true
            boss_killed.emit(boss_id)
```

`_phase_advanced_this_frame` resets at the start of the next boss `_physics_process` or equivalent frame boundary. This lock is mandatory because per-hit `area_entered` callbacks are sequential, not frame-aggregated.

### Cause Taxonomy

Damage owns the append-only Tier 1 cause table:

| Cause | Assigned by | Meaning |
|-------|-------------|---------|
| `&"projectile_enemy_drone"` | Enemy AI / Drone projectile | ECHO hit by Drone projectile |
| `&"projectile_enemy_secbot"` | Enemy AI / Security Bot projectile | ECHO hit by Security Bot projectile |
| `&"projectile_boss"` | Boss Pattern projectile | ECHO hit by boss projectile |
| `&"hazard_spike"` | Stage hazard | ECHO hit by spike/fixed trap |
| `&"hazard_pit"` | Stage hazard | ECHO entered pit/fall volume |
| `&"hazard_oob"` | Stage hazard | ECHO entered out-of-bounds kill volume |
| `&"hazard_crush"` | Stage hazard | ECHO hit by crush/moving-platform hazard |

`&"hazard_"` prefix is reserved for hazard-only grace detection. ECHO projectile HitBoxes intentionally use `&""` in Tier 1 because enemy/boss receivers do not use cause for player-fired projectile hits. If an unset cause reaches a context that requires a cause, Damage emits `&"unknown"` and uses debug-only `push_error` in debug builds.

### Ownership Matrix

| Item | Owner | May read | May write / emit |
|------|-------|----------|------------------|
| `HitBox` class contract | Damage | All host systems | Damage implementation only |
| `HurtBox` class contract | Damage | All host systems | Damage implementation only |
| HitBox host/cause assignment | Host systems using Damage table | Damage/VFX/Audio via emitted cause | Host at instantiation only |
| Collision layer/mask matrix | Damage | Player Shooting, Enemy AI, Boss Pattern, Stage, tests | Damage GDD/ADR update only |
| ECHO `HurtBox.monitorable` | EchoLifecycleSM | Damage fixtures / diagnostics | RewindingState enter/exit only |
| `_pending_cause` | Damage | Damage only | Damage only |
| `_hazard_grace_remaining` | Damage | Damage only | `start_hazard_grace()` and Damage countdown only |
| Standard enemy death latch | Enemy host / Enemy AI | Damage/presentation via signals | Enemy host once per valid hit |
| Boss phase table values | Boss Pattern | Boss host / tests | Boss Pattern validation / authoring only |
| Boss phase signal contract | Damage | HUD/VFX/Audio/Camera/SceneManager/TRC | Boss host using Damage-compatible procedure |
| Stage clear trigger | SceneManager | Damage emits `boss_killed` | SceneManager owns transition; Damage does not transition scenes |

### Forbidden Paths

- No Damage polling of `EchoLifecycleSM.current_state`, `StateMachine.current_state`, `is_rewinding()`, or state-machine node paths.
- No Damage-owned i-frame boolean separate from `HurtBox.monitorable`.
- No use of `HurtBox.monitoring` as the ECHO i-frame toggle.
- No direct enemy/boss/player death calls from Enemy AI, Boss Pattern, Stage, VFX, Audio, HUD, Camera, or Player Shooting.
- No `boss_defeated` signal; `boss_killed(boss_id)` is the single terminal boss signal.
- No `hits_remaining`, hit-counter, damage-number, HP-bar, or remaining-phase-count payload in production HUD-facing signals.
- No ad hoc layer/mask allocation by host systems.
- No PhysicsServer2D direct-query combat path in Tier 1.
- No `RigidBody2D` gameplay hit actors.
- No global combat event bus in Tier 1.
- No unordered dictionary iteration to determine same-frame enemy kill order.

## Alternatives Considered

### Alternative 1: Damage-owned Area2D components with host-owned instantiation

- **Description**: Damage defines `HitBox`, `HurtBox`, collision matrix, cause taxonomy, direct invocation APIs, and combat signals. Hosts instantiate the components and wire host-specific behavior.
- **Pros**: Matches locked GDDs; keeps collision semantics centralized; preserves host composition; blocks self-damage/friendly-fire at the engine layer; supports ECHO, enemy, boss, and hazard flows without a global bus.
- **Cons**: Requires strict host compliance and many static/integration tests across scenes.
- **Decision**: Selected.

### Alternative 2: Numeric HP/damage system

- **Description**: Give ECHO, enemies, and boss health values; Damage applies numeric damage and emits health-changed signals.
- **Pros**: Familiar combat pattern; easy to extend to armor or multiple damage values later.
- **Cons**: Contradicts one-hit clarity, standard enemy 1-hit design, no-HP-bar boss design, and the "read patterns, not numbers" fantasy. Exposes tuning complexity outside Tier 1 solo scope.
- **Rejection Reason**: Echo's Tier 1 combat is binary by design. Numeric HP requires a separate future ADR and GDD amendments.

### Alternative 3: Damage polls lifecycle state for i-frames

- **Description**: Damage checks `EchoLifecycleSM.current_state` or a helper like `is_rewinding()` before accepting a hit.
- **Pros**: Straightforward code inside Damage.
- **Cons**: Creates bidirectional Damage↔SM coupling, opens race conditions, and duplicates SM truth. It also contradicts DEC-4 and ADR-0008.
- **Rejection Reason**: SM must own `HurtBox.monitorable`; Damage should simply not receive `area_entered` during i-frames.

### Alternative 4: Global CombatManager event bus

- **Description**: All hit events go through a central Autoload or event bus that routes to TRC, SM, HUD, VFX, Audio, and SceneManager.
- **Pros**: One place to inspect combat events and add analytics later.
- **Cons**: Contradicts ADR-0005 direct producer-owned signal strategy; weakens per-producer ordering; adds solo-scope complexity.
- **Rejection Reason**: Tier 1 uses direct typed signals with explicit connect and emit order.

### Alternative 5: Physics direct-query combat resolution

- **Description**: Each gameplay system queries overlap state via PhysicsServer2D or space-state queries and resolves hits in `_physics_process`.
- **Pros**: Can centralize update order under a single loop.
- **Cons**: Duplicates Area2D signal behavior, increases query complexity, risks ordering drift with Godot signal flush, and weakens scene-authored collision debugging.
- **Rejection Reason**: Locked Damage GDD uses `Area2D` signal-driven HitBox/HurtBox components.

### Alternative 6: Boss Pattern owns boss phase/kill signal signatures

- **Description**: Boss Pattern defines its own `boss_hit`, `boss_phase_changed`, and `boss_defeated` events independent of Damage.
- **Pros**: Boss design could evolve independently.
- **Cons**: Creates duplicate boss terminal signals, risks `boss_defeated` / `boss_killed` drift, exposes HP-like data to HUD, and breaks SceneManager/TRC single trigger expectations.
- **Rejection Reason**: Boss Pattern owns phase scripts and tables; Damage owns the combat signal contract.

## Consequences

### Positive

- All combat hit semantics are traceable to one Damage-owned component contract.
- ECHO self-damage and enemy friendly-fire are blocked by collision masks before gameplay code runs.
- ECHO rewind i-frames are unidirectional and state-machine-owned.
- Boss phase signals remain readable without exposing hit counts.
- SceneManager, TRC, HUD, VFX, Audio, and Camera consume stable event names.
- Stage, Enemy AI, Player Shooting, and Boss Pattern can implement hosts without inventing new collision semantics.

### Negative

- The Damage GDD/ADR becomes a high-fan-out dependency across many systems.
- Collision layer changes require multi-GDD review and registry updates.
- Signal ordering is subtle because `hurtbox_hit` is emitted before host-specific Damage/Boss handlers.
- Boss phase transition logic is split: Boss Pattern owns data/scripts, Damage owns the signal contract and transition procedure.

### Risks

- **R1: Registry emit-order drift persists** — Mitigation: list a registry correction candidate and require architecture-review to check `hurtbox_hit` as the preceding source emit.
- **R2: Implementer toggles `monitoring` instead of `monitorable`** — Mitigation: explicit validation tests and static search for ECHO i-frame writes.
- **R3: Boss remaining hits leak to HUD/VFX** — Mitigation: no `hits_remaining` payload; HUD no-HP-bar ACs; reject hit-count signals.
- **R4: Same-frame boss multi-hit skips phases** — Mitigation: `_phase_advanced_this_frame` lock and worst-case `[2,1,5]` regression fixture.
- **R5: Cause taxonomy fragments** — Mitigation: append-only table and host-assignment tests for Enemy AI, Boss Pattern, and Stage.
- **R6: Worst-case Area2D scene exceeds Steam Deck budget** — Mitigation: `area2d_max_active = 80`, Stage preflight, and ≤ 2.5 ms Deck-equivalent Damage budget test.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/damage.md` | Damage owns HitBox/HurtBox contracts and cause taxonomy. | Defines `HitBox`, `HurtBox`, the cause table, and host assignment boundary. |
| `design/gdd/damage.md` | Damage emits lethal/boss/enemy signals in deterministic order. | Locks ECHO, enemy, and boss emit order and connect-order requirements. |
| `design/gdd/damage.md` | Damage must not poll SM state; SM controls ECHO HurtBox monitorability. | Bans SM polling and assigns i-frame writes to EchoLifecycleSM. |
| `design/gdd/boss-pattern.md` | Boss owns phase scripts; Damage owns hit/phase signal contract. | Splits Boss Pattern's phase table/scripts from Damage-compatible phase emit procedure. |
| `design/gdd/enemy-ai.md` | Standard enemies are 1-hit and emit one kill signal through Damage. | Defines standard enemy death path and one-shot `enemy_killed` semantics. |
| `design/gdd/player-shooting.md` | ECHO projectile HitBox L2 hits enemy/boss only and uses no cause label. | Locks L2 mask L3/L6, cause `&""`, and self-damage prevention. |
| `design/gdd/stage-encounter.md` | Stage owns hazard instances and Projectiles container; Damage owns hit interpretation. | Locks hazard cause labels, L5 mask L1, and Area2D budget preflight ownership. |
| `design/gdd/state-machine.md` | EchoLifecycleSM subscribes to `player_hit_lethal` and invokes Damage commit/cancel/hazard grace APIs. | Defines the direct Damage APIs and their idempotency. |
| `design/gdd/time-rewind.md` | TRC consumes `lethal_hit_detected`, `death_committed`, and `boss_killed`. | Preserves frame-N lethal cache, cleanup, and boss token-grant trigger names. |
| `design/gdd/scene-manager.md` | SceneManager uses `boss_killed` as stage-clear trigger. | Keeps `boss_killed(boss_id)` as the only terminal boss event. |
| `design/gdd/hud.md` | HUD shows phase/presence only; no boss HP/hit count. | Keeps `boss_hit_absorbed` away from HUD and excludes remaining-hit payloads. |
| `design/gdd/vfx-particle.md` | VFX maps Damage causes and signals without gameplay authority. | Exposes stable cause-bearing events while banning VFX hit authority. |
| `design/gdd/audio.md` | Audio consumes combat events presentation-only. | Provides stable signal names and cause labels without bus/control ownership. |
| `design/gdd/camera.md` | Camera consumes `player_hit_lethal` and `boss_killed` for shake only. | Keeps Damage as producer and Camera as read-only presentation observer. |

## Performance Implications

- **CPU**: Damage budget is locked to ≤ 1.0 ms on baseline dev hardware and ≤ 2.5 ms on Steam Deck-equivalent measurement for the worst-case Tier 1 combat scene. Area2D signal fan-out and cause branching must fit inside that budget.
- **Memory**: Components are ordinary scene nodes. Tier 1 active Area2D count is capped at 80; Tier 3 ceiling is 160 only after a future review.
- **Load Time**: No dynamic combat registry loading. Layer/mask/cause values are authored in scenes/resources and validated at startup/preflight.
- **Network**: None; Echo is local single-player Tier 1.

## Migration Plan

1. Implement `HitBox.gd` and `HurtBox.gd` from the ADR interfaces.
2. Implement ECHO `Damage.gd` with `_pending_cause`, `commit_death()`, `cancel_pending_death()`, and `start_hazard_grace()`.
3. Configure ECHO, player projectiles, enemy hosts, enemy projectiles, hazards, and boss hosts with the 6-bit layer/mask matrix.
4. Wire ECHO Damage signals in host `_ready()` using Callable-style connects and `CONNECT_DEFAULT`.
5. Implement standard enemy one-hit death latch and `enemy_killed(enemy_id, cause)` emission.
6. Implement boss host Damage-compatible phase procedure with `_phase_advanced_this_frame`.
7. Add Stage preflight for Area2D budget and hazard cause labels.
8. Add static checks for Damage polling SM state, `monitoring` i-frame toggles, ad hoc layer assignment, and forbidden boss hit-count payloads.
9. Add GUT integration fixtures for collision predicate, ECHO death flow, standard enemy kill flow, boss phase flow, hazard grace, and same-frame ordering.

## Validation Criteria

- `test_hitbox_class_contract`: `HitBox extends Area2D`, owns `cause`, `host`, default `monitoring = true`, and connects `area_entered`.
- `test_hurtbox_class_contract`: `HurtBox extends Area2D`, owns `entity_id`, default `monitorable = true`, and exposes `hurtbox_hit(cause)`.
- `test_hitbox_emits_hurtbox_hit_once`: valid HitBox/HurtBox overlap emits one `hurtbox_hit` from HitBox script.
- `test_damage_does_not_reemit_hurtbox_hit`: Damage handler does not re-emit `hurtbox_hit`.
- `test_collision_layer_matrix_exact`: all six layer/mask values match this ADR.
- `test_echo_projectile_self_damage_blocked`: L2 projectile overlapping L1 ECHO HurtBox emits no hit.
- `test_enemy_friendly_fire_blocked`: L4 projectile overlapping L3 enemy HurtBox emits no hit.
- `test_hurtbox_monitorable_false_blocks_area_entered`: ECHO i-frame fixture suppresses `area_entered`.
- `test_damage_no_sm_poll_static`: Damage code has no state-machine state reads or node-path aliases.
- `test_echo_hurt_emit_order`: `hurtbox_hit` precedes `_pending_cause`, then `lethal_hit_detected`, then `player_hit_lethal`.
- `test_echo_first_hit_lock`: second lethal in same tick or DYING window emits no new lethal signals and preserves first cause.
- `test_commit_death_idempotent`: commit with no pending cause emits nothing; commit with pending cause emits `death_committed` once and clears.
- `test_cancel_pending_death_idempotent`: cancel with or without pending cause emits nothing and clears.
- `test_hazard_grace_12_flush_windows`: `start_hazard_grace()` blocks hazard causes for exactly 12 flush windows and does not block enemy projectile causes.
- `test_enemy_killed_once`: one or more same-tick ECHO projectile hits produce one `enemy_killed`.
- `test_multi_enemy_kill_order_deterministic`: same-frame multi-enemy kill order matches deterministic scene-tree fixture for 1000 cycles.
- `test_boss_hit_absorbed_no_remaining_payload`: `boss_hit_absorbed` has exactly `(boss_id, phase_index)`.
- `test_boss_phase_advance_order`: `boss_pattern_interrupted` emits before `boss_phase_advanced`.
- `test_boss_kill_order`: final hit emits `boss_pattern_interrupted` before `boss_killed`.
- `test_boss_multi_hit_single_step`: `[2,1,5]` same-frame multi-hit advances exactly one phase.
- `test_no_boss_defeated_static`: no production signal named `boss_defeated`.
- `test_no_hits_remaining_payload_static`: no production signal exposes `hits_remaining` / hit count / HP to HUD.
- `test_stage_hazard_causes_prefixed`: all Tier 1 hazard causes begin with `hazard_`.
- `test_damage_budget_deck_equivalent`: worst-case Tier 1 scene stays ≤ 2.5 ms Damage cost on Steam Deck-equivalent hardware.

## Related Decisions

- `docs/architecture/adr-0001-time-rewind-scope.md`
- `docs/architecture/adr-0002-time-rewind-storage-format.md`
- `docs/architecture/adr-0003-determinism-strategy.md`
- `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md`
- `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md`
- `docs/architecture/adr-0008-player-entity-composition-and-lifecycle-state-ownership.md`
- `docs/architecture/architecture.md`
- `design/gdd/damage.md`
- `design/gdd/state-machine.md`
- `design/gdd/time-rewind.md`
- `design/gdd/player-movement.md`
- `design/gdd/player-shooting.md`
- `design/gdd/enemy-ai.md`
- `design/gdd/boss-pattern.md`
- `design/gdd/stage-encounter.md`
- `design/gdd/scene-manager.md`
- `design/gdd/hud.md`
- `design/gdd/vfx-particle.md`
- `design/gdd/audio.md`
- `design/gdd/camera.md`
- `docs/registry/architecture.yaml`

## Registry Candidates

The following candidates should be reviewed before any explicit registry write:

- **EXISTING stance update**: `interfaces.damage_signals.adr` → change from `design/gdd/damage.md` to ADR-0009 or add ADR-0009 as architecture authority.
- **EXISTING stance correction**: `interfaces.damage_signals.emit_ordering_contract` → record `HurtBox.hurtbox_hit(cause)` as the preceding source emit before ECHO Damage handler emits `lethal_hit_detected` and `player_hit_lethal`.
- **EXISTING referenced_by update**: `state_ownership.boss_phase_state` → add ADR-0009 as combat event ownership authority.
- **EXISTING referenced_by update**: `api_decisions.collision_layer_assignment` → add ADR-0009 as collision matrix authority.
- **EXISTING referenced_by update**: `api_decisions.gameplay_physics_node_types` → add ADR-0009 for combat actor type confirmation.
- **NEW interface contract candidate**: `hitbox_hurtbox_components` → `HitBox extends Area2D`, `HurtBox extends Area2D`, source `hurtbox_hit(cause)` emit, host-instantiated components.
- **NEW interface contract candidate**: `damage_invocation_api` → `commit_death()`, `cancel_pending_death()`, `start_hazard_grace()` idempotent direct APIs.
- **NEW API decision candidate**: `damage_cause_taxonomy` → append-only Tier 1 `StringName` cause table and `hazard_` prefix invariant.
- **EXISTING forbidden pattern referenced_by updates**: `damage_polls_sm_state`, `cross_entity_sm_transition_call`, `rigidbody2d_for_gameplay_entities`.
- **EXISTING forbidden pattern correction**: `damage_polls_sm_state.description` / `why` should say SM controls `echo_hurtbox.monitorable`, not `monitoring`, matching locked Damage GDD DEC-4.
- **NEW forbidden pattern candidate**: `boss_hits_remaining_signal_payload` → production signals must not expose boss remaining hits / HP / hit counters to HUD-facing consumers.
- **NEW forbidden pattern candidate**: `hurtbox_monitoring_iframe_toggle` → ECHO i-frames must use `HurtBox.monitorable`, not `HurtBox.monitoring`.

`docs/registry/architecture.yaml` was not modified by this ADR authoring pass because registry writes require explicit user approval.
