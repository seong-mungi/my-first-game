# ADR-0003: Determinism Strategy — CharacterBody2D + Direct Transform / Area2D Projectiles

## Status
Proposed

## Date
2026-05-09

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Physics (2D — node-type strategy for ECHO, enemies, projectiles) |
| **Knowledge Risk** | HIGH — 4.6 is post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md` (Physics 4.6 section), `docs/engine-reference/godot/modules/physics.md`, ADR-0001 (Player-only scope), ADR-0002 (Snapshot ring buffer), `docs/registry/architecture.yaml`, godot-specialist validation 2026-05-09 |
| **Post-Cutoff APIs Used** | None — `CharacterBody2D`, `Area2D`, `move_and_slide()`, `Engine.get_physics_frames()`, `Node.process_physics_priority`, `PhysicsDirectSpaceState2D.intersect_ray()`, `RandomNumberGenerator` are all stable across 4.4-4.6 with no breaking changes (verified via `breaking-changes.md`: 2D physics unchanged; 4.5 rearchitecture was 3D-interpolation only). Jolt 4.6 default is 3D-only; 2D physics still uses Godot Physics 2D and is unaffected. |
| **Verification Required** | (1) 1000-cycle determinism test on 5-enemy + 20-projectile scene — bit-identical position state across runs on the dev machine. (2) 60fps on Steam Deck with 30 enemies + 50 active projectiles. (3) Snapshot restore round-trip exact-equality test (capture → restore → step 1 frame → assert position == captured + velocity × delta). (4) Swept-raycast bullet anti-tunneling: 10000 high-velocity bullet × thin-wall trials, zero tunneling. (5) `_physics_process` ordering verification: priority-tied siblings must not exhibit determinism breakage in the 1000-cycle test. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001 (R-T1)** [Accepted 2026-05-09] — Player-only rewind scope. **ADR-0002 (R-T2)** [Accepted 2026-05-09] — Snapshot ring buffer with direct-field restoration. R-T3 closes the triplet by specifying which Godot 2D node types make those decisions implementable. |
| **Enables** | `design-system time-rewind` GDD (System #9), `design-system player-movement` GDD (System #6), `design-system damage` GDD (System #8), `design-system enemy-ai` GDD (System #10), `design-system player-shooting` GDD (System #7), `design-system boss-pattern` GDD (System #11). |
| **Blocks** | `prototype time-rewind` (Tier 1 Week 1) — cannot start without node-type decision; `design-system time-rewind` GDD — Engine Compatibility section needs this ADR to cite. |
| **Ordering Note** | R-T1 → R-T2 → R-T3 sequence complete with this ADR. All three time-rewind ADRs Accepted unblocks every dependent GDD listed above. |

## Context

### Problem Statement

ADR-0001 locked Player-only rewind. ADR-0002 locked the snapshot ring buffer with direct field assignment via `PlayerMovement.restore_from_snapshot()`. R-T3 must answer: which Godot 2D node type should ECHO, enemies, and projectiles use to satisfy three constraints simultaneously?

1. **ECHO snapshot restoration must be bit-identical.** No physics integrator may overwrite the directly-assigned snapshot fields between the restore call and the next `_physics_process` read.
2. **Enemy patterns must be deterministic across player attempts (Pillar 2).** Same input sequence + same encounter seed → same enemy positions and behavior every run on the dev machine.
3. **Projectile motion must be reproducible** under the same constraints, with no solver-introduced drift.

The decision is non-obvious because Godot 4.6 ships three viable 2D physics node families (`CharacterBody2D`, `RigidBody2D`, `Area2D`), each with distinct determinism guarantees and authoring ergonomics. Choosing wrong here invalidates ADR-0002's contract or breaks Pillar 2.

### Constraints

- **Pillar 2** — Deterministic patterns; "운(luck)은 적이다" (`design/gdd/game-concept.md` line 138).
- **Forbidden pattern (registered)** — `direct_player_state_write_during_rewind`: only `PlayerMovement.restore_from_snapshot()` may write rewind state. R-T3's chosen node type must make direct field assignment in `restore_from_snapshot()` actually be the next-tick-authoritative state.
- **ADR-0002 contract** — Snapshot stores 7 primitive fields (position, velocity, facing, animation_name, animation_time, weapon_id, is_grounded). R-T3 must NOT require additional state (e.g., solver internal state, contact island data) to fully restore ECHO.
- **Godot Physics 2D solver is NOT bit-identical-deterministic across runs/machines** (verified via best-practices doc + community discussion). RigidBody2D motion driven by the solver inherits this nondeterminism.
- **Performance** — 60 fps × 16.6 ms; Steam Deck target; 100+ active dynamic entities at Tier 2; ≤ 500 draw call ceiling.
- **Solo budget** — Avoid maintaining two parallel physics paradigms (CharacterBody + RigidBody mixed).
- **Engine** — Godot 4.6, GDScript only, 2D only.

### Requirements

- **R-RT3-01** ECHO restoration: setting `global_position`/`velocity`/`facing_direction` on tick N is the actual state read on tick N+1 (no integrator drift).
- **R-RT3-02** Enemy AI: deterministic with respect to `Engine.get_physics_frames()` counter; no wall-clock dependence; no global RNG.
- **R-RT3-03** Projectile motion: scripted, monotonic, no solver involvement.
- **R-RT3-04** High-velocity projectiles must not tunnel through thin colliders.
- **R-RT3-05** `_physics_process` step ordering must be deterministic and explicit (player → enemies → projectiles).
- **R-RT3-06** Cosmetic-only debris (no gameplay impact, not snapshot-restored) is exempt from the determinism contract.

## Decision

**Use `CharacterBody2D` + script-controlled transform/velocity for ECHO and all enemies. Use `Area2D` + script-stepped position for all projectiles. `RigidBody2D` is BANNED for any entity that must be deterministic or rewind-restorable. Cosmetic-only debris (no gameplay consequence, not in snapshot scope) MAY use `RigidBody2D` outside the determinism boundary.**

### Per-Entity Model

**1. ECHO (Player) — `CharacterBody2D`**

```gdscript
class_name PlayerMovement extends CharacterBody2D

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _weapon: WeaponSlot = $WeaponSlot

var facing_direction: int = 1
var current_weapon_id: int = 0
var is_grounded: bool = false

func _physics_process(delta: float) -> void:
    _apply_gravity(delta)
    _read_input_into_velocity()
    move_and_slide()
    is_grounded = is_on_floor()

func restore_from_snapshot(snap: PlayerSnapshot) -> void:
    global_position = snap.global_position
    velocity = snap.velocity
    facing_direction = snap.facing_direction
    _weapon.set_active(snap.current_weapon_id)
    _anim.play(snap.animation_name)
    _anim.seek(snap.animation_time, true)  # update=true forces immediate pose
    # is_grounded is recomputed on the next move_and_slide() call
```

`CharacterBody2D` has no solver overriding the transform — the next `_physics_process` reads exactly the values just written by `restore_from_snapshot()`.

**2. Enemies (drone, security bot, STRIDER boss) — `CharacterBody2D`**

```gdscript
class_name EnemyBase extends CharacterBody2D

@export var ai_seed: int = 0
@export var spawn_physics_frame: int = -1  # set by Encounter system on spawn

var _rng: RandomNumberGenerator

func _ready() -> void:
    _rng = RandomNumberGenerator.new()
    _rng.seed = ai_seed  # explicit per-encounter seed; never the global RNG
    process_physics_priority = 10  # enemies after player (player = 0)

func _physics_process(_delta: float) -> void:
    var frame_offset: int = Engine.get_physics_frames() - spawn_physics_frame
    velocity = compute_ai_velocity(frame_offset)  # pure function of frame + state + seeded RNG
    move_and_slide()

func compute_ai_velocity(frame_offset: int) -> Vector2:
    # Subclasses implement deterministic patterns keyed off frame_offset
    return Vector2.ZERO
```

AI logic is a pure function of `frame_offset` (monotonic counter, no wall clock) plus a seeded `RandomNumberGenerator` — no global random, no `Time.get_ticks_msec()`-based decisions.

**3. Projectiles (player + enemy bullets) — `Area2D`**

```gdscript
class_name Projectile extends Area2D

@export var velocity: Vector2
@export var max_step_distance: float = 8.0  # px — threshold above which swept raycast is required

var _last_position: Vector2

func _ready() -> void:
    monitoring = true
    process_physics_priority = 20  # projectiles step after enemies (player=0, enemy=10)
    _last_position = global_position
    body_entered.connect(_on_body_entered)
    area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
    var step: Vector2 = velocity * delta
    if step.length() > max_step_distance:
        _swept_collision_check(_last_position, _last_position + step)
    position += step
    _last_position = global_position

func _swept_collision_check(from_pos: Vector2, to_pos: Vector2) -> void:
    var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
    var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
    query.collision_mask = collision_mask  # mirrors Area2D's mask
    var hit: Dictionary = space_state.intersect_ray(query)
    if hit.is_empty():
        return
    global_position = hit.position
    _resolve_hit(hit.collider, hit.position, hit.normal)
    queue_free()
```

`Area2D` has no integrator and never sleeps. Position is fully script-owned. High-velocity tunneling is prevented by an explicit swept raycast before the position step.

### Determinism Source

| Mechanism | Use |
|---|---|
| `Engine.get_physics_frames()` | Monotonic int, incremented each physics step. Drives ALL AI/timer logic. Replaces wall-clock time fully. |
| `RandomNumberGenerator` with explicit `seed` | Per-encounter seed (e.g., `seed = stage_index * 1000 + encounter_index`). NEVER use `randi()` / global RNG. |
| `Node.process_physics_priority` | Player = 0, Enemies = 10, Projectiles = 20. Lower priority steps first. **CRITICAL**: this is `process_physics_priority`, NOT `process_priority` — the latter only orders `_process()` and has no effect on `_physics_process()`. |

### RigidBody2D — Where Banned vs. Where Allowed

**Banned (gameplay-affecting, must be deterministic):**
- ECHO Player
- All enemies (drone, security bot, STRIDER boss, future archetypes)
- All projectiles (player bullets, enemy bullets, grenades, missiles)

**Allowed (cosmetic-only, NOT in snapshot scope, NOT determinism-critical):**
- Death gibs / debris that have no collision with gameplay entities
- Background prop physics (e.g., a chain swaying)
- Particle-driven decorative bodies

The Allowed list MUST satisfy two conditions:
1. The body is on a collision layer that no gameplay-affecting entity (enemy, projectile, hazard) collides with.
2. The body is destroyed or out-of-camera before the next snapshot capture cycle could be affected by its state.

If a future encounter design wants "physical knockback feel" for an enemy or boss, it MUST be implemented as scripted velocity application on a `CharacterBody2D`, not by switching to `RigidBody2D`.

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│ Determinism Boundary                                              │
│ ──────────────────────────────────────────────────────────────── │
│                                                                   │
│  Inside boundary (script-controlled, no solver):                  │
│    ┌──────────────────┐   ┌─────────────────┐   ┌─────────────┐  │
│    │ ECHO             │   │ Enemy / Boss    │   │ Projectile  │  │
│    │ CharacterBody2D  │   │ CharacterBody2D │   │ Area2D      │  │
│    │ + move_and_slide │   │ + move_and_slide│   │ + script pos│  │
│    │ + restore_from_  │   │ + frame-counter │   │ + swept ray │  │
│    │   snapshot()     │   │   AI            │   │   for fast  │  │
│    │ priority = 0     │   │ priority = 10   │   │ priority=20 │  │
│    └──────────────────┘   └─────────────────┘   └─────────────┘  │
│                                                                   │
│  Determinism source: Engine.get_physics_frames() (monotonic int)  │
│  RNG: RandomNumberGenerator with explicit per-encounter seed      │
│                                                                   │
│ ──────────────────────────────────────────────────────────────── │
│                                                                   │
│  Outside boundary (cosmetic only — RigidBody2D allowed):          │
│    debris, gibs, decorative particles                             │
│    ↳ NOT recorded in snapshot, NOT determinism-critical,          │
│      NOT colliding with gameplay layers                           │
└──────────────────────────────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# PlayerMovement — sole writer of player rewind state under ADR-0002 contract
class_name PlayerMovement extends CharacterBody2D
func restore_from_snapshot(snap: PlayerSnapshot) -> void

# EnemyBase — deterministic AI base, frame-counter driven
class_name EnemyBase extends CharacterBody2D
func compute_ai_velocity(frame_offset: int) -> Vector2  # subclass override

# Projectile — script-stepped Area2D
class_name Projectile extends Area2D
@export var velocity: Vector2
@export var max_step_distance: float
```

### Registry Candidates (added in Step 6)

- **Forbidden Pattern**: `rigidbody2d_for_gameplay_entities` — Player, enemies, and projectiles MUST NOT be `RigidBody2D`. Cosmetic-only debris exempt under stated conditions.
- **API Decision**: `physics_node_strategy` — `CharacterBody2D` for player + enemies; `Area2D` for projectiles; `RigidBody2D` cosmetic-only.
- **API Decision**: `determinism_clock` — `Engine.get_physics_frames()` is the single source of game time for AI/timers; wall-clock APIs forbidden in gameplay-critical paths.
- **API Decision**: `physics_step_ordering` — `Node.process_physics_priority` ladder: player=0, enemies=10, projectiles=20.

## Alternatives Considered

### Alternative 1: CharacterBody2D + Area2D (Selected)

Described above.

### Alternative 2: RigidBody2D Unified for All Dynamic Entities

- **Description**: ECHO, enemies, and projectiles all `RigidBody2D`. Restoration via `PhysicsServer2D.body_set_state()`. AI applies forces / impulses instead of setting velocity.
- **Pros**:
  - Free physics interactions (knockback, environmental physics, particle-driven feel) handled by solver.
  - Bullets can use built-in continuous collision detection.
- **Cons**:
  - **Pillar 2 break**: Godot Physics 2D solver introduces float drift; 1000-cycle bit-identical determinism test fails by construction (verified pattern in community discussions).
  - **ADR-0002 contract violation risk**: After `body_set_state()`, the solver may re-settle the body within the same frame depending on collision overlap, changing actual restored state from what the snapshot recorded.
  - **Snapshot scope expansion**: must capture full PhysicsServer2D body state (sleep state, contact islands, accumulated forces) — contradicts ADR-0002's 7-field primitive snapshot.
  - **Bullet trajectory non-determinism**: high-velocity RigidBody2D projectiles tunnel/bounce inconsistently; CCD adds solver cost and is still float-drift-bound.
  - **Steam Deck risk**: solver workload scales with active body count; 100+ enemies + 50+ bullets stresses the solver under our 0.5 ms determinism budget allocation.
  - **Two writer paths to ECHO state**: snapshot direct-set + solver step → ADR-0002's "single legitimate restoration path" forbidden pattern is harder to enforce.
- **Rejection Reason**: Direct break of Pillar 2 and ADR-0002 contract. No mitigation closes the float-drift gap.

### Alternative 3: Mixed — Player CharacterBody2D / Enemies + Projectiles RigidBody2D

- **Description**: ECHO uses `CharacterBody2D` (preserves snapshot restore correctness). Enemies and bullets use `RigidBody2D` for richer interactions.
- **Pros**:
  - ECHO restoration stays clean (same as Alternative 1).
  - Enemy / bullet code can leverage Godot solver features.
- **Cons**:
  - **Pillar 2 still broken** for enemies and bullets — and Pillar 2 governs the WHOLE GAME, not just the player. Player learns enemy patterns; if enemy patterns drift, learning is moot.
  - Two paradigms = two debug surfaces, two test paths, two performance profiles. Solo budget waste.
  - Mixed-physics interactions (`CharacterBody2D` ↔ `RigidBody2D` collision) have asymmetric resolution depending on mass; bug-prone edge cases.
  - No corresponding gain over Alternative 1: ECHO-only `CharacterBody2D` gives all the snapshot-restore correctness; the "free physics" benefit only applies to entities where Pillar 2 fails.
- **Rejection Reason**: Saves nothing, breaks Pillar 2 for the entities where Pillar 2 matters most.

## Consequences

### Positive

- **Pillar 2 holds with zero solver-introduced drift.** 1000-run single-machine determinism test passes by construction.
- **ADR-0002 snapshot contract remains valid** — 7 primitive fields + direct field assignment IS the source of truth, with no integrator between write and next read.
- **One paradigm to learn, debug, and profile** (`CharacterBody2D` + `Area2D`).
- **Bullet motion is trivial** (one line of code per step). Bullet count scales linearly with no solver overhead.
- **Enemy AI authoring is purely scripted** — encounter designers reason about velocities and frame timings, not impulses.
- **Steam Deck-friendly** — zero `RigidBody2D` solver load on gameplay-critical entities.
- **Save system future-compat** — same snapshot serialization works for Tier 2+ Save / Settings Persistence (ADR-0002 already noted; R-T3 makes the assumption real).

### Negative

- **No "free physics" features for gameplay entities.** Enemies cannot ragdoll on death (cosmetic ragdoll handled by separate `RigidBody2D` corpses outside the boundary). Knockback is scripted, not solver-derived.
- **Projectiles cannot use built-in CCD.** Mitigation: explicit swept raycast for high-velocity bullets (specified in Decision; codified in System #8 Damage / Hit Detection GDD).
- **Joints / constraints unavailable** for gameplay entities. Mitigation: nothing in Echo's GDD requires joints.
- **Discipline cost**: every new gameplay node added to Echo must consciously be `CharacterBody2D` or `Area2D`. The forbidden pattern in the registry is the enforcement mechanism — `/architecture-review` flags violations.

### Risks

- **R1 — RigidBody2D temptation**: A future encounter design wants "feel-physical" knockback and a contributor reaches for `RigidBody2D`, breaking the contract.
  - **Mitigation**: Forbidden pattern registered (`rigidbody2d_for_gameplay_entities`); `/architecture-review` flags it; this ADR is cited in every gameplay GDD's Engine Compatibility section.
- **R2 — Bullet tunneling**: high-velocity projectiles tunnel through thin walls if step distance exceeds collider thickness.
  - **Mitigation**: `max_step_distance` threshold in `Projectile` triggers swept raycast via `PhysicsRayQueryParameters2D.create(from, to)` on `get_world_2d().direct_space_state`. System #8 Damage / Hit Detection GDD specifies the threshold per weapon.
- **R3 — Simultaneous-collision step ordering**: `move_and_slide` is documented as deterministic, but multiple `CharacterBody2D` entities colliding in the same frame have ordering-dependent results.
  - **Mitigation**: explicit `process_physics_priority` ladder (player=0, enemies=10, projectiles=20); Tier 1 prototype runs the 1000-cycle determinism test on a 5-enemy + 20-bullet scene as a regression gate.
- **R4 — Cosmetic debris drift**: `RigidBody2D` debris in the cosmetic-only boundary drifts visually across replays in the same session.
  - **Mitigation**: explicitly outside determinism boundary; documented so QA does not file determinism bugs against debris; cosmetic bodies must use a collision layer disjoint from all gameplay layers.
- **R5 — Cross-machine bit-identity is NOT guaranteed.** IEEE 754 float intrinsics differ by CPU and compiler optimization. The 1000-cycle determinism test is a single-machine / single-build guarantee.
  - **Mitigation**: scope claims accordingly in QA docs; rely on input-replay-style determinism only on the dev machine; do not advertise frame-perfect speedrun cross-platform parity.
- **R6 — Signal dispatch order ambiguity**: when two projectiles' `body_entered` / `area_entered` signals fire on the same tick against the same target, dispatch order is implementation-defined (tree order, not priority-stable). This does NOT break snapshot-restore (state is captured AFTER the tick completes), but can cause non-deterministic damage *registration* when two bullets hit one target in the same frame.
  - **Mitigation**: System #8 Damage / Hit Detection GDD MUST specify a deterministic damage application policy — e.g., "all damage in the same physics tick is summed, not applied in arrival order" — to neutralize this risk.
- **R7 — Sibling step order under priority ties**: when two siblings have the same `process_physics_priority`, fallback is scene-tree order, which is stable only if the tree is never modified at runtime. Dynamic `add_child` / `remove_child` during gameplay can silently reorder siblings.
  - **Mitigation**: every gameplay node MUST explicitly set `process_physics_priority` (no ties within a category); spawn orchestrators (encounter, bullet pool) MUST insert children in a deterministic order (sorted by spawn frame + spawn id).
- **R8 — Contact resolution patch-version drift**: Godot Physics 2D contact resolution order under simultaneous threshold collisions is not guaranteed stable across engine patch versions.
  - **Mitigation**: pin engine version (already pinned to 4.6 in `VERSION.md`); re-run 1000-cycle determinism test as a regression gate before any engine bump; document the test in `tests/integration/time-rewind/`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| `design/gdd/game-concept.md` Pillar 2 (line 138) | "결정론 패턴, 운은 적이다" | Determinism boundary excludes solver entirely; AI is `Engine.get_physics_frames()`-driven; RNG is per-encounter seeded; explicit `process_physics_priority` ordering. |
| `design/gdd/systems-index.md` System #6 Player Movement | "달리기/점프/낙하, 1히트 즉사, 리스폰 핸들링" | `CharacterBody2D` + `move_and_slide()`; `restore_from_snapshot()` is the sole rewind-state writer; matches forbidden pattern `direct_player_state_write_during_rewind`. |
| `design/gdd/systems-index.md` System #7 Player Shooting | "8방향 조준, 발사체 스폰, 무기 스왑" | Projectile = `Area2D` + script position step; weapon swap restored via `PlayerSnapshot.current_weapon_id`. |
| `design/gdd/systems-index.md` System #8 Damage / Hit Detection | "탄환 vs 엔티티, 1히트 룰, 히트박스 레이어" | `Area2D.body_entered` / `area_entered` + swept raycast for fast bullets (R2 mitigation); R6 mitigation requires deterministic damage policy in this GDD. |
| `design/gdd/systems-index.md` System #9 Time Rewind | ADR-0002 snapshot restoration must be bit-identical (single-machine) | `CharacterBody2D` direct field assignment — no solver between write and next read. |
| `design/gdd/systems-index.md` System #10 Enemy AI Base | "공통 적 컨트롤러 + 드론/경비로봇/STRIDER 서브클래스" | `EnemyBase extends CharacterBody2D`; `compute_ai_velocity(frame_offset)` is the deterministic extension point. |
| `design/gdd/systems-index.md` System #11 Boss Pattern | "다페이즈 스크립트, 텔레그래프, HP 게이팅, REWIND 토큰 보상" | Boss inherits `EnemyBase`; phase scripts are pure functions of `frame_offset`; token replenish via existing `token_replenished` signal (ADR-0001 contract). |
| `docs/registry/architecture.yaml` `direct_player_state_write_during_rewind` | "Single legitimate restoration path: `PlayerMovement.restore_from_snapshot()`" | This ADR confirms the path is implementable via direct field assignment on `CharacterBody2D` without solver interference; no second writer needed. |

## Performance Implications

- **CPU**: `move_and_slide()` ≈ 5-15 μs per `CharacterBody2D` depending on slide count and collider density. 1 player + 30 enemies × 60 Hz = ~30 μs/frame baseline. Projectile script step ≈ 0.5 μs each × 50 active = 25 μs. Swept raycast ≈ 2 μs each × ~5 high-velocity bullets per frame = 10 μs. Total ≈ 65 μs/frame for entity motion: **0.4% of 16.6 ms budget**. Well under target.
- **Memory**: no per-entity solver-state allocation. `CharacterBody2D` base instance ≈ 200 B vs `RigidBody2D` ≈ 400 B (engine internal). `Area2D` projectile ≈ 150 B vs `RigidBody2D` projectile ≈ 400 B. ~20-50 KB savings on Tier 2 active count. Negligible against 1.5 GB ceiling.
- **Load Time**: no solver islands to build for enemies / bullets at scene load. Negligible.
- **Network**: N/A (Echo is single-player).

## Migration Plan

No prior code exists. New construction. Each affected system GDD will cite this ADR in its Engine Compatibility section:

- System #6 Player Movement → `extends CharacterBody2D`
- System #7 Player Shooting → projectile spawn produces `Area2D` instances
- System #8 Damage / Hit Detection → `body_entered` / `area_entered` + swept raycast
- System #10 Enemy AI Base → `EnemyBase extends CharacterBody2D`
- System #11 Boss Pattern → boss subclasses inherit `EnemyBase`

Estimated initial Tier 1 code: ~250 lines GDScript across `PlayerMovement`, `EnemyBase`, `Projectile`, plus the existing `TimeRewindController` (~90 lines from ADR-0002).

## Validation Criteria

This ADR is correct if:

1. **1000-cycle single-machine determinism test PASSES**: 5 enemies + 20 active projectiles + scripted player input. PASS = bit-identical `CharacterBody2D` positions and `Area2D` positions at every recorded frame across all 1000 runs on the dev machine.
2. **60 fps on Steam Deck PASSES** with 30 enemies + 50 active projectiles. PASS = 99% of frames under 16.6 ms in a representative encounter.
3. **Snapshot restore round-trip PASSES**: `capture → restore → step 1 frame → assert position == captured + velocity × delta`. PASS = exact equality (bit-identical).
4. **Anti-tunneling PASSES**: 10000 high-velocity (>500 px/s) bullet × thin-wall (4 px) trials, **zero tunneling failures**.
5. **Pillar 2 playtest PASSES**: 5 testers attempt the same encounter 10 times each; same input sequence yields the same enemy positions ≥ 99% of trials (allowing minor human input jitter).
6. **Step ordering PASSES**: 1000-cycle test on a scene that dynamically spawns and despawns 10 enemies during the run. PASS = position state still bit-identical, confirming `process_physics_priority` ladder works under runtime tree mutation.

If any of #1, #3, #4, or #6 FAIL, this ADR is broken and must be revised. #2 and #5 failures may indicate tuning issues rather than ADR-level error.

## Related Decisions

- **ADR-0001 (R-T1, Accepted 2026-05-09)** — Time Rewind Scope: Player-only checkpoint model.
- **ADR-0002 (R-T2, Accepted 2026-05-09)** — Time Rewind Storage Format: Snapshot ring buffer + write-into-place + direct restoration.
- **`design/gdd/game-concept.md`** — Pillar 2 (deterministic patterns), Pillar 5 (solo budget).
- **`design/gdd/systems-index.md`** — Systems #6, #7, #8, #9, #10, #11 (all dependent on this ADR).
- **`docs/registry/architecture.yaml`** — registered stances: `direct_player_state_write_during_rewind` (this ADR confirms direct-assign path); registry candidates added by this ADR are listed in Decision → Registry Candidates.
- **`docs/engine-reference/godot/modules/physics.md`** — 4.6 Physics quick reference (2D unchanged).
- **`docs/engine-reference/godot/breaking-changes.md`** — verifies no 2D physics API changes 4.4-4.6.
- **`docs/engine-reference/godot/current-best-practices.md`** — Physics (4.6) section.
- **godot-specialist validation 2026-05-09** — Resolved 2 BLOCKING items (`process_physics_priority` correction, `intersect_ray` 4.6 pattern correction) and added 3 residual nondeterminism risks (R6, R7, R8).
