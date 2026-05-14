# ADR-0011: Enemy, Boss, and Projectile Deterministic Scheduling

## Status
Accepted (ratified 2026-05-14)

## Date
2026-05-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Physics / Gameplay Scheduling / AI |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff and deterministic gameplay depends on exact 2D physics, process ordering, and `Area2D` signal behavior. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/physics.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md`, `.claude/docs/technical-preferences.md`, `docs/registry/architecture.yaml`, `docs/architecture/adr-0001-time-rewind-scope.md`, `docs/architecture/adr-0003-determinism-strategy.md`, `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md`, `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md`, `docs/architecture/adr-0009-damage-hitbox-hurtbox-and-combat-event-ownership.md`, `design/gdd/enemy-ai.md`, `design/gdd/boss-pattern.md`, `design/gdd/player-shooting.md`, `design/gdd/stage-encounter.md`, `design/gdd/damage.md`, `design/gdd/time-rewind.md`, `design/gdd/state-machine.md`, `design/gdd/game-concept.md` |
| **Post-Cutoff APIs Used** | No new Godot 4.5/4.6-only API is required. This decision depends on stable Godot 4.x APIs and behavior: `CharacterBody2D`, `Area2D`, `Engine.get_physics_frames()`, `Node.process_physics_priority`, `RandomNumberGenerator`, typed signals, `Node.queue_free()`, `get_world_2d().direct_space_state`, and direct script-controlled movement. Godot 4.6's Jolt default affects 3D only; 2D physics remains Godot Physics 2D. |
| **Verification Required** | (1) 1000-cycle deterministic encounter replay with identical enemy positions, boss phase state, active projectile set, and combat signal order. (2) Same-frame spawn insertion is sorted by `(spawn_physics_frame, spawn_id, projectile_sequence_id)` in fixtures, not by dictionary or scene-tree accident. (3) Boss same-frame multi-hit advances at most one phase via the Damage `_phase_advanced_this_frame` lock. (4) No gameplay-critical enemy, boss, or projectile code calls wall-clock APIs, global RNG, `_process(delta)` timers, or animation-finished transitions for lethal scheduling. (5) Enemy/Boss priority 10 and Projectile priority 20 are asserted at runtime/test load. (6) Projectile pool checkout order is stable across runs. (7) Stage preflight fails boss/enemy projectile budget overflow instead of silently skipping required scheduled projectiles. (8) Rewind signal audit proves enemies, boss, and projectiles do not subscribe to `rewind_started` or `rewind_completed`. (9) Same-tick boss kill/lethal-hit ordering preserves the Time Rewind consume-then-grant invariant. |

> Engine validation note: primary engine specialist from `.claude/docs/technical-preferences.md` is `godot-specialist`. In this Codex adapter run, no subagent was spawned because the repository adapter limits `Task`/subagent use to explicit user-requested delegation. The draft was validated locally against the pinned Godot 4.6 reference files listed above. The high-risk engine points remain Godot 4.6 `Area2D` signal flush timing, explicit physics priority ordering, and 2D direct-space query fixtures for fast projectiles.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Time Rewind Scope; ADR-0003 Determinism Strategy; ADR-0004 Scene Lifecycle and Checkpoint Restart Architecture; ADR-0005 Cross-System Signal Architecture and Event Ordering; ADR-0009 Damage, HitBox/HurtBox, and Combat Event Ownership. ADR-0003, ADR-0005, and ADR-0009 must be Accepted before production stories rely on this scheduling contract. |
| **Enables** | Enemy AI #10 implementation, Boss Pattern #11 implementation, Player Shooting #7 projectile pools, Stage/Encounter #12 spawn orchestration, Damage #8 same-frame combat fixtures, and deterministic replay QA stories. |
| **Blocks** | Any production story that implements enemy AI clocks, STRIDER phase scripts, boss projectile patterns, enemy projectile pools, same-frame spawn ordering, projectile movement/cap behavior, boss kill cleanup, or token-grant timing before this ADR is Accepted. |
| **Ordering Note** | ADR-0003 owns node-type choices and the priority ladder. ADR-0009 owns combat components/signals and boss phase-transition signal procedure. This ADR refines those decisions by specifying deterministic scheduling, spawn ordering, boss pattern clocks, projectile pool ordering, and rewind immunity for enemies/boss/projectiles. If wording conflicts, ADR-0003 controls node types/priority numbers and ADR-0009 controls Damage signal semantics. |

## Context

### Problem Statement

ADR-0003 establishes the deterministic node model: ECHO and enemies use `CharacterBody2D`, gameplay projectiles use script-stepped `Area2D`, and explicit `process_physics_priority` orders the physics tick. That is necessary but not sufficient for Tier 1 combat implementation.

Enemy AI #10, Boss Pattern #11, Player Shooting #7, Stage/Encounter #12, and Damage #8 also require a shared scheduling grammar:

1. when same-frame enemy, boss, and projectile spawns are inserted;
2. which clock drives enemy/boss attack decisions;
3. how projectile pools are checked out deterministically;
4. how the STRIDER boss advances phases without same-frame skips;
5. how rewind remains player-only while the rest of the world keeps moving; and
6. how cap/preflight failures are handled without hidden nondeterministic branches.

Without this ADR, implementations could individually satisfy ADR-0003 while still drifting into dictionary iteration, runtime random attack selection, culling-driven AI, animation-signal timers, unordered projectile pools, or same-frame boss phase skips.

### Constraints

- Pillar 2: deterministic patterns; repeated attempts must teach the player rather than add hidden luck.
- ADR-0001: only ECHO rewinds; enemies, boss, projectiles, environment, and camera do not restore.
- ADR-0003: enemies/boss use `CharacterBody2D` at priority 10; projectiles use `Area2D` at priority 20; Damage uses priority 2.
- ADR-0009: Damage owns `HitBox`/`HurtBox`, the collision matrix, combat signal order, and the boss phase transition signal procedure.
- Stage/Encounter owns spawn manifests, room metadata, `Projectiles` container setup, Area2D budget preflight, and deterministic activation data.
- Enemy AI and Boss Pattern must not use wall-clock time, global RNG, `_process(delta)` timers, animation-finished callbacks for gameplay timing, or `RigidBody2D`.
- Visibility/culling may reduce presentation work only; it must never change gameplay decisions, attack sequence, projectile spawn count, or AI target selection.
- Tier 1 has exactly one authored STRIDER boss, no summons/adds/knockback, and no HP bar or visible hit counter.
- Area2D cap is 80 active gameplay-relevant areas for the stage; Boss Pattern reserves 21 maximum (`1` hurtbox + `16` projectiles + `4` warnings).

### Requirements

- Stage supplies each scheduled actor with `spawn_id`, `ai_seed`, `spawn_physics_frame`, authored anchors/bounds, and an explicit `target_player`.
- `EnemyBase` exposes a deterministic scheduling contract for Drone, Security Bot, and STRIDER-compatible hosts.
- Enemy AI behavior is a pure function of `encounter_seed`, `spawn_id`, `spawn_physics_frame`, `frame_offset`, authored tables, stable state, and explicit target snapshots.
- STRIDER boss patterns use authored phase tables and fixed attack sequences, never runtime-random attack choice.
- Boss phase transitions are Damage-compatible and advance at most one phase per physics tick.
- All gameplay projectiles are `Area2D` instances with priority 20, stable IDs, deterministic movement, and deterministic pool checkout.
- Same-frame spawn and projectile insertion use explicit sort keys, not unordered dictionaries, editor tree accident, distance from player, or wall-clock creation order.
- Enemy, boss, and projectile nodes do not subscribe to rewind signals and are not restored by the player rewind snapshot.
- Stage/boss preflight fails if required scheduled boss/enemy Area2D budgets cannot fit; required projectiles must not be silently dropped at runtime.

## Decision

Use a **deterministic encounter scheduling contract** layered on top of ADR-0003 and ADR-0009:

1. **Stage/Encounter owns the spawn manifest.**
   - Every gameplay-affecting enemy, boss host, warning area, and non-player-authored projectile schedule originates from authored encounter data.
   - Stage activates manifest entries in stable ascending order by `(activation_frame, spawn_id)`.
   - If multiple children are inserted on the same physics frame, their final insertion key is `(spawn_physics_frame, spawn_id, local_sequence_id)`.

2. **EnemyBase owns deterministic enemy clocks.**
   - `EnemyBase extends CharacterBody2D`.
   - `EnemyBase.process_physics_priority = 10`.
   - Enemy elapsed time is `frame_offset = Engine.get_physics_frames() - spawn_physics_frame`.
   - Enemy AI may read the current explicit `target_player` snapshot during its priority-10 tick, but it must not discover targets through unordered groups as a gameplay fallback.
   - Seeded variant selection is allowed only at spawn. After spawn, lethal behavior is driven by frame counters, authored tables, current state, and explicit target reads.

3. **BossPattern owns authored STRIDER phase schedules.**
   - STRIDER uses an `EnemyBase`-compatible `CharacterBody2D` host at priority 10.
   - Boss attack choice comes from `BossPhaseSpec.pattern_sequence` and `phase_elapsed_frames`, not RNG.
   - Each lethal boss output follows `telegraph -> commit -> active -> recovery`.
   - Damage-compatible phase transitions use the ADR-0009 `_phase_advanced_this_frame` lock: at most one phase advance per physics tick, even if multiple ECHO projectile hits overlap in the same frame.
   - Terminal `boss_killed` cleanup is single-fire. Boss-owned warnings/projectiles are queued for cleanup after the current signal cascade; SceneManager owns stage clear and Time Rewind Controller owns token mutation.

4. **Projectile scheduling is script-owned and pool-ordered.**
   - All player, enemy, and boss gameplay projectiles are `Area2D` nodes at priority 20.
   - Projectile movement is fixed-physics-tick script movement; implementation may use Godot's physics `delta` only as the configured fixed tick duration and must not accumulate variable render delta.
   - Each projectile receives `projectile_sequence_id`, `owner_spawn_id`, `spawn_physics_frame`, `cause`, `direction`, `speed_px_per_sec`, and lifetime/active-frame values at spawn.
   - Projectile pools check out by stable ascending pool index and return by stable ID; unordered dictionary/set iteration is forbidden for active projectile order.
   - Player Shooting's authored `PROJECTILE_CAP` may skip player shots according to Player Shooting #7. Enemy/boss required projectile schedules must be covered by Stage preflight; they must not silently disappear from runtime budget pressure.

5. **Damage remains the combat consequence owner.**
   - Hit detection components are still ADR-0009 `HitBox` and `HurtBox`.
   - Projectile hosts set collision layers/masks and cause labels, but they do not interpret player death, enemy death, boss phase advance, or boss kill.
   - Same-frame combat event ordering is verified through ADR-0009 signal fixtures. This ADR only requires scheduled hosts to emit/instantiate in stable order so ADR-0009 receives deterministic contacts.

6. **Rewind immunity is explicit.**
   - Enemy, boss, warning-area, and projectile clocks do not pause, restore, or rewind when ECHO rewinds.
   - These nodes must not subscribe to `rewind_started`, `rewind_completed`, or any future player-snapshot restore signal.
   - If presentation needs a rewind visual on non-player actors, it must be observer-only and must not change gameplay scheduling.

### Architecture Diagram

```text
Physics frame N
────────────────────────────────────────────────────────────────────

Stage/Encounter manifest (authoring data)
  sort by (activation_frame, spawn_id)
  └── inserts EnemyBase/Boss/Projectile requests in stable order

Godot physics tick ordering
  priority 0   PlayerMovement / ECHO
  priority 1   TimeRewindController
  priority 2   Damage frame-boundary resolution / queued combat consequences
  priority 10  EnemyBase + STRIDER BossPattern
               ├── frame_offset = Engine.get_physics_frames() - spawn_frame
               ├── authored enemy behavior tables
               └── boss phase sequence / attack windows
  priority 20  Projectile Area2D hosts
               ├── stable pool-index order
               ├── fixed-tick movement
               └── ADR-0009 HitBox contacts

Rewind event:
  TimeRewindController restores ECHO only
  enemies/boss/projectiles keep current clocks and active schedules
```

### Key Interfaces

#### Encounter spawn manifest

```gdscript
class_name EncounterSpawnSpec
extends Resource

@export var entity_kind: StringName          # &"drone", &"security_bot", &"strider_tier1"
@export var spawn_id: int                    # unique inside encounter
@export var activation_frame: int            # room-local authored activation frame
@export var ai_seed: int
@export var spawn_anchor: NodePath
@export var patrol_anchors: Array[NodePath]
@export var activation_bounds_id: StringName
@export var target_player_path: NodePath
```

Stage converts `activation_frame` to `spawn_physics_frame` when the actor is instantiated. If two entries share `activation_frame`, the lower `spawn_id` must be inserted first.

#### EnemyBase scheduling contract

```gdscript
class_name EnemyBase
extends CharacterBody2D

@export var archetype_id: StringName
@export var spawn_id: int
@export var ai_seed: int
@export var spawn_physics_frame: int
@export var target_player_path: NodePath

var entity_id: StringName
var target_player: PlayerMovement
var authored_variant: int

func configure_from_spawn(spec: EncounterSpawnSpec, target: PlayerMovement) -> void:
    spawn_id = spec.spawn_id
    ai_seed = spec.ai_seed
    spawn_physics_frame = Engine.get_physics_frames()
    target_player = target
    process_physics_priority = 10
    authored_variant = _variant_for_spawn(spec.ai_seed, spec.spawn_id, archetype_id)

func _physics_process(_delta: float) -> void:
    var frame_offset: int = Engine.get_physics_frames() - spawn_physics_frame
    velocity = compute_ai_velocity(frame_offset, _target_snapshot())
    move_and_slide()

func compute_ai_velocity(frame_offset: int, target_snapshot: Dictionary) -> Vector2:
    return Vector2.ZERO
```

Variant selection is allowed once at spawn:

```text
authored_variant =
  (encounter_seed + spawn_id * 1103515245 + archetype_salt) mod variant_count
```

After spawn, `randf()`, `randi()`, `randomize()`, global RNG, and new runtime random attack choices are forbidden for lethal scheduling.

#### BossPattern schedule contract

```gdscript
class_name BossStartSpec
extends Resource

@export var boss_id: StringName              # &"strider_tier1"
@export var arena_bounds: Rect2
@export var entry_anchor: NodePath
@export var exit_gate_id: StringName
@export var target_player_path: NodePath
@export var spawn_id: int
@export var ai_seed: int
@export var spawn_physics_frame: int
```

```gdscript
class_name BossPhaseSpec
extends Resource

@export var phase_index: int
@export var hits_required: int               # Tier 1 table: [3, 4, 5]
@export var pattern_sequence: Array[StringName]
```

```gdscript
class_name BossAttackSpec
extends Resource

@export var attack_id: StringName
@export var telegraph_frames: int
@export var commit_frames: int
@export var active_frames: int
@export var recovery_frames: int
@export var projectile_schedule: Array[BossProjectileSpawnSpec]
```

Boss attack index is derived only from phase elapsed frames and the fixed sequence:

```text
phase_elapsed_frames = Engine.get_physics_frames() - phase_enter_frame
attack_slot = authored_attack_slot_for(phase_elapsed_frames, BossPhaseSpec.pattern_sequence)
```

#### Projectile schedule contract

```gdscript
class_name ProjectileSpawnSpec
extends Resource

@export var projectile_id: StringName
@export var projectile_sequence_id: int
@export var owner_spawn_id: int
@export var spawn_physics_frame: int
@export var direction: Vector2
@export var speed_px_per_sec: float
@export var lifetime_frames: int
@export var cause: StringName                # e.g. &"projectile_enemy", &"projectile_boss"
@export var collision_layer_bits: int
@export var collision_mask_bits: int
```

```gdscript
class_name DeterministicProjectile
extends Area2D

var projectile_sequence_id: int
var owner_spawn_id: int
var spawn_physics_frame: int
var velocity_px_per_sec: Vector2
var lifetime_frames: int

func configure(spec: ProjectileSpawnSpec) -> void:
    projectile_sequence_id = spec.projectile_sequence_id
    owner_spawn_id = spec.owner_spawn_id
    spawn_physics_frame = spec.spawn_physics_frame
    velocity_px_per_sec = spec.direction.normalized() * spec.speed_px_per_sec
    lifetime_frames = spec.lifetime_frames
    collision_layer = spec.collision_layer_bits
    collision_mask = spec.collision_mask_bits
    process_physics_priority = 20

func _physics_process(delta: float) -> void:
    var age_frames: int = Engine.get_physics_frames() - spawn_physics_frame
    if age_frames >= lifetime_frames:
        queue_free()
        return
    global_position += velocity_px_per_sec * delta
```

Fast projectile implementations must reuse ADR-0003's swept raycast pattern before applying the position step when the per-tick step exceeds the projectile anti-tunneling threshold.

#### Same-frame ordering keys

| Object | Primary sort key | Secondary sort key | Tertiary sort key |
|--------|------------------|--------------------|-------------------|
| Enemy/Boss spawns | `spawn_physics_frame` | `spawn_id` | authored manifest order assertion |
| Enemy projectiles | `spawn_physics_frame` | `owner_spawn_id` | `projectile_sequence_id` |
| Boss projectiles/warnings | `spawn_physics_frame` | `boss spawn_id` | `attack_id`, then `projectile_sequence_id` |
| Player projectiles | `spawn_physics_frame` | player weapon slot / fire sequence | pool index |
| Damage contact fixtures | ADR-0009 signal source order | host insertion order sorted above | component local index |

#### Forbidden implementation paths

- `RigidBody2D` for gameplay-affecting enemies, boss, or projectiles.
- Runtime-random enemy or boss lethal attack selection after spawn.
- `Time.get_ticks_msec()`, `Time.get_unix_time_from_system()`, `_process(delta)` timers, or animation-finished callbacks for gameplay attack windows.
- Global `randf()`, `randi()`, or `randomize()` in enemy/boss/projectile scheduling.
- Iterating unordered dictionaries/sets to decide spawn, pool checkout, collision consequence, or signal emission order.
- Enemy/boss/projectile subscription to `rewind_started`, `rewind_completed`, or future player restore signals.
- Visibility, culling, occlusion, or camera distance changing gameplay schedules.
- Silent runtime dropping of required enemy/boss projectiles due to cap pressure.
- Boss phase skips caused by same-frame multi-hit overlap.

## Alternatives Considered

### Alternative 1: ADR-0003 physics priority only

- **Description**: Rely on `CharacterBody2D`, `Area2D`, and `process_physics_priority` from ADR-0003 without adding a scheduling grammar.
- **Pros**: Minimal new architecture; fewer documents.
- **Cons**: Leaves same-frame spawn order, projectile pool order, boss attack sequence, phase skip prevention, and rewind-immune behavior open to per-story interpretation.
- **Rejection Reason**: Fails the architecture-review gap. Node types and priority are necessary but do not prove deterministic combat scheduling.

### Alternative 2: Stage-owned deterministic manifest + host-local clocks (Selected)

- **Description**: Stage owns spawn ordering and budget preflight; enemy/boss/projectile hosts use local frame counters, authored tables, stable IDs, and deterministic pool order.
- **Pros**: Matches GDD ownership, keeps implementation simple for solo Tier 1, preserves direct signal architecture, and makes replay fixtures straightforward.
- **Cons**: Requires disciplined data authoring and explicit test fixtures for ordering/caps.
- **Selection Reason**: Best fit for Godot 4.6, existing ADRs, Pillar 2 determinism, player-only rewind, and the one-stage Tier 1 scope.

### Alternative 3: Global runtime event scheduler/autoload

- **Description**: Route every enemy, boss, projectile, and Damage event through a centralized global scheduler queue.
- **Pros**: One queue could make ordering visually obvious and support replay logging.
- **Cons**: Adds an autoload-like coordinator, duplicates Godot physics order, conflicts with ADR-0005 direct signals, and risks replacing local GDD ownership with a god object.
- **Rejection Reason**: Over-architected for Tier 1 and contradicts existing registry constraints against state-machine/autoload ownership drift.

### Alternative 4: Randomized encounter/boss director with deterministic seed

- **Description**: Use seeded RNG throughout combat to choose enemy variants, attack timings, boss moves, and projectile spreads.
- **Pros**: More variety with a small authored content set.
- **Cons**: Seeded randomness can still obscure learnable patterns, makes replay failures harder to inspect, and contradicts Boss Pattern #11's authored sequence requirement.
- **Rejection Reason**: Tier 1 design wants readable authored patterns, not seeded surprise as the primary scheduler.

### Alternative 5: Rewind-synchronized world rollback

- **Description**: Restore enemies, boss, and projectiles along with ECHO when rewind triggers.
- **Pros**: Easier mental model for some time-control games.
- **Cons**: Directly violates ADR-0001 and Time Rewind #9; requires snapshots for every actor, projectile, and boss phase; invalidates hostile-world pressure after rewind.
- **Rejection Reason**: Player-only rewind is already accepted and is central to the design.

### Alternative 6: Culling-driven AI/projectile scheduling

- **Description**: Disable offscreen enemy AI, boss warnings, or projectile movement based on camera visibility.
- **Pros**: Potential CPU savings.
- **Cons**: Changes gameplay outcomes based on camera/culling, breaks deterministic replay, and makes hidden projectiles/enemies inconsistent across viewports.
- **Rejection Reason**: Visibility optimization may affect presentation only; gameplay schedules must remain camera-independent.

## Consequences

### Positive

- Closes the missing architecture coverage for Enemy AI #10, Boss Pattern #11, and deterministic projectile scheduling.
- Makes same-frame ordering and cap behavior testable instead of implicit.
- Preserves existing ADR boundaries: Stage spawns, Enemy/Boss schedule, Damage interprets combat, SceneManager clears stages, TRC mutates rewind tokens.
- Keeps Godot implementation idiomatic: no custom physics loop, no global scheduler autoload, no post-cutoff engine features.
- Provides stable metadata and IDs for deterministic replay tests and future debugging overlays.

### Negative

- Authors must maintain explicit `spawn_id`, `projectile_sequence_id`, and fixed sequence data.
- Encounter setup becomes stricter: budget failures block stage load/preflight instead of forgiving at runtime.
- Some visual optimization options are unavailable because culling cannot alter gameplay schedules.
- Boss/enemy variety is constrained by authored tables rather than runtime randomization.

### Risks

- **Risk: Godot `Area2D` contact ordering differs from assumptions.** Mitigation: ADR-0009 fixtures must assert Godot 4.6 contact/source order; this ADR's stable insertion keys reduce but do not replace engine fixtures.
- **Risk: Hidden unordered iteration enters implementation.** Mitigation: add static checks for dictionaries/sets in scheduler/pool code and replay tests with deliberately same-frame spawns.
- **Risk: Cap pressure drops scheduled boss/enemy projectiles.** Mitigation: Stage preflight reserves boss/enemy budgets and fails loudly before combat starts.
- **Risk: Same-frame boss multi-hit skips phases.** Mitigation: Damage-owned `_phase_advanced_this_frame` lock and a dedicated multi-overlap fixture.
- **Risk: Rewind visual code accidentally pauses enemies/projectiles.** Mitigation: signal subscription audit and runtime assertions that only TRC/PlayerMovement consume restore semantics.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `game-concept.md` | Pillar 2 deterministic patterns, no hidden luck. | Uses frame counters, authored tables, stable IDs, and forbids runtime random lethal scheduling. |
| `enemy-ai.md` | `EnemyBase extends CharacterBody2D`, priority 10, frame-counted AI, no wall-clock/global RNG. | Defines `EnemyBase` fields, priority, spawn configuration, frame offset, and variant-only seeded spawn randomness. |
| `enemy-ai.md` | Same-frame enemy/projectile insertion order is `(spawn_physics_frame, spawn_id)` ascending; projectiles use deterministic pool order. | Defines explicit sort keys for enemy/boss/projectile insertion and stable pool-index checkout. |
| `enemy-ai.md` | Enemy AI is not rewind-restored and does not subscribe to rewind signals. | Makes rewind immunity mandatory for enemy, boss, warning, and projectile nodes. |
| `boss-pattern.md` | STRIDER uses an EnemyBase-compatible host, authored phases, no random attack order, and telegraph/commit/active/recovery. | Defines BossStart/Phase/Attack contracts and phase elapsed frame sequencing. |
| `boss-pattern.md` | Boss phase table `[3, 4, 5]`, at most one phase transition per physics tick, terminal `boss_killed` cleanup. | Locks Boss Pattern to ADR-0009 phase procedure and `_phase_advanced_this_frame` behavior. |
| `boss-pattern.md` | Boss projectile cap 16 and warning cap 4; Stage preflight fails Area2D overflow. | Requires preflight reservation and forbids silent runtime drops for required boss/enemy scheduled projectiles. |
| `player-shooting.md` | Player projectiles are `Area2D` at priority 20 with deterministic motion/lifetime/cap behavior. | Defines the projectile schedule contract and explicitly preserves Player Shooting's authored `PROJECTILE_CAP` behavior. |
| `stage-encounter.md` | Stage supplies spawn IDs, seeds, spawn frames, anchors, activation bounds, target reference, and `Projectiles` container/budget validation. | Assigns spawn manifest ownership and activation sorting to Stage/Encounter. |
| `damage.md` | Damage owns hit interpretation, 6-bit collision matrix, combat signals, and boss phase monotonicity. | Keeps projectile/enemy/boss hosts as schedulers only and routes consequences through ADR-0009 Damage. |
| `time-rewind.md` | Only ECHO rewinds; enemies and projectiles keep moving. | Forbids enemy/boss/projectile rewind subscription or restore behavior. |
| `state-machine.md` | State machines must not be bypassed by cross-entity transition calls or combat polling. | Keeps enemy/boss scheduling separate from Damage interpretation and avoids cross-system state-machine calls. |

## Performance Implications

- **CPU**: Expected low overhead beyond existing AI/projectile work. Stable sorting is limited to spawn activation and same-frame insertion lists; per-frame gameplay should operate over arrays/pools in stable index order. Worst-case combat still needs ADR-0003/ADR-0009 performance fixtures.
- **Memory**: Requires explicit manifest resources and projectile pools. Boss Pattern reserves up to 21 Area2D-relevant nodes; total stage active Area2D budget remains 80.
- **Load Time**: Stage preflight performs budget and duplicate-ID validation before combat. This may fail earlier but should not materially affect Tier 1 load time.
- **Network**: None. The deterministic contract is local replay/test determinism, not lockstep multiplayer.

## Migration Plan

1. Add static authoring checks for duplicate `spawn_id`, duplicate `projectile_sequence_id` within owner scope, missing `target_player`, and unsorted same-frame manifest entries.
2. Implement `EncounterSpawnSpec`, `EnemyBase.configure_from_spawn()`, Boss Pattern schedule resources, and `ProjectileSpawnSpec` with the names in this ADR or update the GDDs before renaming them.
3. Add runtime assertions for `process_physics_priority` on enemy/boss/projectile nodes in debug builds.
4. Convert enemy/boss projectile pools to stable arrays with explicit free-index queues; prohibit dictionary/set iteration in checkout and active update order.
5. Add Stage preflight for Area2D cap reservation, boss projectile/warning caps, and required projectile schedule feasibility.
6. Add deterministic replay fixtures before implementing content-heavy enemy/boss behavior.
7. Add static/runtime audits proving enemies, boss, and projectiles do not connect to rewind restore signals.

## Validation Criteria

- 1000 repeated runs of the same encounter produce identical actor positions, boss phase state, projectile active IDs, and combat signal logs.
- Same-frame enemy spawns with intentionally shuffled authoring input instantiate in sorted `(spawn_physics_frame, spawn_id)` order.
- Same-frame projectile spawns instantiate/update in sorted `(spawn_physics_frame, owner_spawn_id, projectile_sequence_id)` order.
- Boss multi-hit fixture with two or more ECHO projectile contacts in one physics frame advances only one phase or kills once.
- Boss terminal fixture proves `boss_killed` is single-fire and token grant/stage clear ordering matches ADR-0009/Time Rewind requirements.
- Rewind fixture proves enemies, boss, warnings, and projectiles keep current clocks and are not restored to prior snapshots.
- Static scan finds no wall-clock APIs, global RNG, `_process(delta)` gameplay timers, or animation-finished lethal timing in enemy/boss/projectile scheduler code.
- Projectile pool fixture proves checkout/return/update order is stable across repeated runs.
- Stage preflight fixture fails required boss/enemy projectile cap overflow before runtime combat starts.
- Performance fixture sustains 60 fps on target-equivalent hardware with Tier 1 worst-case enemy/boss/projectile counts and the ADR-0009 Area2D budget.

## Registry Candidates

These candidates should be appended to `docs/registry/architecture.yaml` only after explicit approval:

- **NEW interface contract**: `deterministic_spawn_manifest` — Stage-owned sorted spawn manifest keyed by `(activation_frame, spawn_id)`.
- **NEW interface contract**: `enemy_base_scheduling_contract` — `EnemyBase` fields and `configure_from_spawn()` semantics.
- **NEW interface contract**: `boss_pattern_schedule_contract` — `BossStartSpec`, `BossPhaseSpec`, `BossAttackSpec`, and authored sequence clock.
- **NEW interface contract**: `projectile_schedule_contract` — stable projectile spawn IDs, pool checkout, priority 20 motion contract.
- **EXISTING referenced-by update**: `physics_step_ordering` — add ADR-0011 as a scheduling refinement.
- **EXISTING referenced-by update**: `determinism_clock` — add enemy/boss/projectile frame-counter scheduling.
- **EXISTING referenced-by update**: `collision_layer_assignment` and `damage_signals` — hosts schedule/label contacts, Damage interprets.
- **NEW API decision**: `boss_phase_schedule_model` — authored phase sequences, no runtime random attack choice.
- **NEW API decision**: `projectile_pool_ordering` — stable ascending pool index checkout/return/update.
- **NEW forbidden pattern**: `wall_clock_enemy_boss_projectile_logic`.
- **NEW forbidden pattern**: `unordered_spawn_or_pool_iteration`.
- **NEW forbidden pattern**: `enemy_or_boss_rewind_subscription`.
- **NEW forbidden pattern**: `runtime_culling_changes_gameplay_schedule`.
- **NEW forbidden pattern**: `boss_phase_skip_from_same_frame_multihit`.
- **NEW forbidden pattern**: `silent_required_enemy_boss_projectile_drop`.

## Related Decisions

- `docs/architecture/adr-0001-time-rewind-scope.md`
- `docs/architecture/adr-0003-determinism-strategy.md`
- `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md`
- `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md`
- `docs/architecture/adr-0009-damage-hitbox-hurtbox-and-combat-event-ownership.md`
- `design/gdd/enemy-ai.md`
- `design/gdd/boss-pattern.md`
- `design/gdd/player-shooting.md`
- `design/gdd/stage-encounter.md`
- `design/gdd/damage.md`
- `design/gdd/time-rewind.md`
- `design/gdd/game-concept.md`
