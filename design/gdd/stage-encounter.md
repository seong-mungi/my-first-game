# Stage / Encounter System

> **Status**: Approved
> **Author**: user + game-designer + level-designer + systems-designer
> **Created**: 2026-05-13
> **Last Updated**: 2026-05-13
> **Implements Pillar**: Pillar 4 (5-Minute Rule) primary; Pillar 2 (Deterministic Patterns) through authored encounter order; Pillar 1 (Learning Tool) through checkpoint-safe room reset
> **Engine**: Godot 4.6 / GDScript / 2D / PackedScene stage root
> **System #**: 12 (Feature / Gameplay)

---

## A. Overview

Stage / Encounter System #12 owns the in-stage flow for Echo's Tier 1 single-stage slice: stage root metadata, room/encounter activation, deterministic enemy spawn metadata, checkpoint-local reset rules, hazard placement, and handoff to Scene Manager #2 for stage boundaries. It does **not** own scene swapping, death/rewind state, enemy behavior, boss phases, or hit authority. Its central promise is: when ECHO enters a room, every enemy, hazard, checkpoint anchor, and camera limit is authored and activated in a deterministic order so the player can learn the same pattern after death or rewind.

For Tier 1, the system supports one playable stage with a small sequence of encounter rooms: intro movement, first enemy read, anti-stationary burst read, combined pressure room, and STRIDER handoff. The system exists to connect already-approved systems into a playable level slice without turning scope into a full level editor, procedural generator, or multi-stage campaign framework.

---

## B. Player Fantasy

Stage / Encounter is a direct player-facing pacing system with an invisible infrastructure layer beneath it. The player should feel that the stage is a compact gauntlet of readable lessons, not a random arena. Each room asks one question, then the next room combines that question with one previously learned rule.

The anchor moment is:

> ECHO enters a neon service corridor. The camera snaps to the checkpoint anchor, a Drone starts patrolling the upper lane, and a Security Bot waits at ground level. The first death teaches the player that standing still in AimLock is unsafe. The restart is immediate, the same spawn order repeats, and the player recognizes the room as a learnable sentence: jump the burst, shoot the bot, then dodge the aerial shot.

This system protects Pillar 4 by getting the player into that loop within 5 minutes, protects Pillar 2 by making encounter order deterministic, and protects Pillar 1 by keeping checkpoint restart safe and fast.

### B.1 Player-Facing Promises

| Promise | Player Feeling | Design Meaning |
|---|---|---|
| **Fast stage entry** | "I am playing immediately." | No press-any-key gate, no long intro room, no multi-minute setup. |
| **Readable room grammar** | "This room is teaching me one pattern." | Tier 1 rooms introduce one new pressure at a time before combining pressures. |
| **Fair retry** | "The same room comes back; I can solve it." | Spawn IDs, activation frames, enemy seeds, and hazard causes repeat after checkpoint restart. |
| **Clear boundary** | "I know when a room starts and ends." | Trigger volumes activate rooms; checkpoint anchors and camera limits define the local arena. |
| **Small success** | "This is a complete slice, not a half-built campaign." | One stage, one mini-boss handoff, no procedural generation, no branching campaign. |

### B.2 Tier 1 Stage Shape

Tier 1 uses one stage slice made of five authored beats:

1. **Boot / Anchor Beat** — ECHO spawns at the first checkpoint anchor; camera limits are valid.
2. **Movement Beat** — safe lane with one jump/dodge read and no enemy fire.
3. **Drone Beat** — one aerial Drone teaches vertical-lane danger.
4. **Security Bot Beat** — one ground bot teaches burst timing and anti-AimLock pressure.
5. **Combined Beat + STRIDER Gate** — Drone + Security Bot pressure leads into the Boss Pattern #11 handoff.

### B.3 Anti-Fantasy

Stage / Encounter must never create these feelings:

- **"The room changed because I died."** Checkpoint restart repeats authored spawn metadata and encounter activation order.
- **"The stage killed me without telling me why."** Hazards use Damage #8 cause labels and visible telegraphs / silhouettes.
- **"The camera fought the room."** Stage camera limits are authored and emitted through Scene Manager's `scene_post_loaded(anchor, limits)` contract.
- **"Enemies appeared randomly."** No runtime random spawn choice, no unordered group iteration, no procedural room population in Tier 1.
- **"The first slice is too big."** Multi-stage routing, optional routes, secret rooms, and procedural waves are Tier 2+.

---

## C. Detailed Design

### C.1 Core Rules

**Rule 1 — Stage root owns static stage metadata, not scene lifecycle.**

The Tier 1 stage scene has a root script `StageDefinition` or equivalent exported metadata container. It exposes:

- `stage_id: StringName`
- `encounter_seed: int`
- `stage_camera_limits: Rect2`
- `checkpoint_anchor: Marker2D` for Tier 1
- `Projectiles: Node2D` as exactly one root-child container for Player Shooting #7 projectiles
- ordered `EncounterDefinition` child nodes or resources
- optional hazard nodes with Damage #8 HitBox causes

Scene Manager #2 loads the PackedScene and emits `scene_post_loaded(anchor: Vector2, limits: Rect2)`. Stage / Encounter consumes that signal or POST-LOAD phase timing; it does not call `change_scene_to_packed()` directly in Tier 1.

**Rule 2 — one checkpoint anchor is canonical in Tier 1.**

Tier 1 supports exactly one active checkpoint anchor per stage load. If multiple anchors exist, Stage / Encounter may tag future anchors as inactive authoring data, but Scene Manager #2 remains the canonical registered respawn anchor for the current load. Multi-anchor mid-stage checkpoint progression is Tier 2 and must reopen Scene Manager OQ-SM-A5.

**Rule 3 — encounter rooms are authored, ordered, and deterministic.**

Each encounter has:

- `encounter_id: StringName`
- `encounter_index: int`
- `activation_trigger: Area2D`
- `room_bounds: Rect2`
- `enemy_spawns: Array[EnemySpawnSpec]`
- `hazard_specs: Array[HazardSpec]`
- `completion_rule: EncounterCompletionRule`

`encounter_index` order is the canonical progression order. Stage / Encounter may not iterate over an unordered dictionary to activate rooms or spawn enemies.

**Rule 4 — Stage supplies Enemy AI spawn metadata.**

For every enemy, Stage / Encounter provides the exact fields required by Enemy AI #10:

| Field | Owner | Rule |
|---|---|---|
| `spawn_id` | Stage / Encounter | Unique within the stage; ascending order defines deterministic child insertion order. |
| `ai_seed` | Stage / Encounter | Derived deterministically from `encounter_seed`, `encounter_index`, and `spawn_id`. |
| `spawn_physics_frame` | Stage / Encounter | Captured on activation frame immediately before or while instantiating the enemy. |
| `activation_bounds` | Stage / Encounter | Room-local active bounds; enemies outside camera still tick if inside the active room. |
| `patrol_anchor_a/b` | Stage / Encounter | Authored `Vector2` positions or Marker2D references; immutable during active encounter. |
| `target_player` | Stage / Encounter | Explicit PlayerMovement reference injected; no enemy group lookup fallback. |

**Rule 5 — spawn order is `(activation_frame, spawn_id)` ascending.**

When an encounter activates, Stage / Encounter instantiates or enables enemies in ascending `spawn_id` order. If multiple projectiles or enemy child nodes are created in the same frame, pools and child insertion order must preserve the same ordering. This mirrors Enemy AI #10 AC-EAI-11.

**Rule 6 — activation is trigger-driven and one-shot per stage load.**

An encounter enters `ARMED` after Scene Manager POST-LOAD completes. When ECHO overlaps the encounter trigger, it transitions to `ACTIVE` exactly once for that stage load. Re-entering the trigger while the encounter is already `ACTIVE` or `CLEARED` does not respawn enemies.

**Rule 7 — checkpoint restart uses scene reload in Tier 1.**

Tier 1 restart is delegated to Scene Manager #2. Stage / Encounter does not implement in-place reset for enemies, projectiles, hazards, or triggers. After Scene Manager reloads the stage PackedScene, Stage / Encounter recreates the deterministic initial state from authored data. In-place checkpoint reset is Tier 2 and must reopen Scene Manager OQ-SM-A2.

**Rule 8 — Stage does not own enemy behavior.**

Stage / Encounter chooses which archetypes appear and where they start. Enemy AI #10 owns patrol math, spotting, firing, projectile causes, and state transitions. Stage / Encounter may not patch enemy frame counters, retarget enemies, or pause enemy AI based on camera visibility.

**Rule 9 — Stage owns environmental hazard instances.**

Environmental hazards use Damage #8 hazard causes:

| Hazard | Cause | Tier 1 Use |
|---|---|---|
| Spike / laser / fixed trap | `&"hazard_spike"` | Optional first-stage obstacle. |
| Pit / fall volume | `&"hazard_pit"` | Optional gap failure. |
| Out-of-bounds kill volume | `&"hazard_oob"` | Required safety net around the stage. |
| Crush / moving platform | `&"hazard_crush"` | Tier 1 optional; avoid unless needed. |

Stage supplies the hazard `Area2D` and the `HitBox.cause`; Damage owns hit interpretation.

**Rule 10 — Area2D budget validation is preflight, not runtime mutation.**

Before gameplay activation, Stage / Encounter validates the room's active standard enemies, enemy projectile cap, boss-placeholder projectile cap, hazards, and other Damage Area2Ds against Damage #8 `area2d_max_active = 80` using Enemy AI #10 D.9. If the total would exceed 80, the encounter fails validation before play begins with a deterministic error. Stage / Encounter must not silently remove enemies or alter enemy projectile schedules at runtime to satisfy the budget.

**Rule 11 — completion is explicit and local.**

An encounter is complete when its authored completion rule passes:

- `CLEAR_ON_ENEMIES_DEAD`: all standard enemies in the encounter are dead/removed.
- `CLEAR_ON_TRIGGER_EXIT`: ECHO exits through a marked room-end trigger.
- `CLEAR_ON_BOSS_KILLED`: Boss Pattern/Damage emits `boss_killed` for the configured boss id.

Tier 1 standard rooms use `CLEAR_ON_ENEMIES_DEAD` or `CLEAR_ON_TRIGGER_EXIT`; the final gate uses Boss Pattern #11 after its GDD passes review.

**Rule 12 — boss handoff is a boundary, not a phase script.**

Stage / Encounter places the STRIDER host and passes boss start metadata. Boss Pattern #11 owns phase thresholds, boss attacks, token reward timing, and `boss_killed`. Stage / Encounter may listen for `boss_killed` only to unlock the stage-clear route or allow Scene Manager's already-approved stage-clear branch to proceed.

**Rule 13 — camera limits are stage-authored and validated at POST-LOAD.**

`stage_camera_limits: Rect2` must have positive size before Scene Manager emits `scene_post_loaded(anchor, limits)`. Invalid camera limits fail stage validation; Camera #3 must not receive a zero-size Rect2.

**Rule 14 — no procedural generation in Tier 1.**

Tier 1 stage data is authored in scene/resources. Random encounter rolls, dynamic wave composition, secret-route generation, runtime enemy substitutions, and scaling by death count are forbidden.

**Rule 15 — Stage hosts the player projectile container, not projectile behavior.**

Every production Tier 1 stage scene must have exactly one root-child node named `Projectiles` with type `Node2D`. Player Shooting #7 resolves this node with `get_tree().current_scene.find_child("Projectiles", true, false)` and parents ECHO projectile roots there so projectiles are outside the ECHO subtree and outside ADR-0001 rewind scope. Stage / Encounter owns only the container's presence and scene-lifetime cleanup through normal Scene Manager #2 scene swap semantics; Player Shooting owns projectile creation, movement, caps, Damage HitBox setup, ammo/cooldown, and `shot_fired(direction: int)`.

### C.2 Tier 1 Stage State Machine

Stage / Encounter owns a simple stage-flow state machine separate from the State Machine Framework #5. This is not an entity behavior SM; it is a deterministic room lifecycle ledger.

| State | Meaning | Entry Trigger | Exit Trigger |
|---|---|---|---|
| `UNINITIALIZED` | Stage scene exists but POST-LOAD is not complete. | Stage root `_ready()` | Scene Manager `scene_post_loaded(anchor, limits)` / direct post-load callback |
| `READY` | Stage metadata validated; encounters armed. | Validation pass | ECHO enters first armed trigger |
| `ENCOUNTER_ACTIVE` | One encounter owns active spawn set and room bounds. | Trigger overlap | Completion rule passes, checkpoint restart, or scene transition |
| `ENCOUNTER_CLEARED` | Current encounter completed; next trigger may arm. | Completion rule pass | ECHO enters next armed trigger |
| `BOSS_GATE` | STRIDER host placed; Boss Pattern owns fight. | Final gate trigger | `boss_killed` or scene transition |
| `STAGE_CLEAR` | Stage clear route unlocked. | `boss_killed` / final completion rule | Scene Manager stage-clear transition |

### C.3 Data Structures

#### C.3.1 `EnemySpawnSpec`

| Field | Type | Required | Notes |
|---|---|---:|---|
| `spawn_id` | int | Yes | Unique in stage; recommended `encounter_index * 100 + local_index`. |
| `archetype_id` | StringName | Yes | `&"drone"`, `&"security_bot"`, or `&"strider_host"` in Tier 1. |
| `enemy_scene` | PackedScene | Yes | Scene root must satisfy Enemy AI #10 `EnemyBase`. |
| `spawn_marker` | Marker2D | Yes | World position source. |
| `patrol_anchor_a` | Marker2D | Yes for Drone/Bot | May equal B for stationary turret-like behavior. |
| `patrol_anchor_b` | Marker2D | Yes for Drone/Bot | Immutable after activation. |
| `activation_bounds` | Rect2 | Yes | Room-local active area. |
| `variant_count` | int | Yes | Passed to Enemy AI validation; default 1. |

#### C.3.2 `EncounterDefinition`

| Field | Type | Required | Notes |
|---|---|---:|---|
| `encounter_id` | StringName | Yes | Stable ID for QA and debug logs. |
| `encounter_index` | int | Yes | Ascending progression order. |
| `activation_trigger` | Area2D | Yes | Player-only overlap. |
| `room_bounds` | Rect2 | Yes | Used for active-room containment and future camera/lock rules. |
| `enemy_spawns` | Array[EnemySpawnSpec] | Yes | Empty allowed for movement/tutorial beats. |
| `hazard_specs` | Array[HazardSpec] | No | Environmental hazards. |
| `completion_rule` | enum | Yes | See C.1 Rule 11. |
| `max_active_enemy_projectiles` | int | Yes | Used for preflight Area2D validation; default 24. |

#### C.3.3 `HazardSpec`

| Field | Type | Required | Notes |
|---|---|---:|---|
| `hazard_id` | StringName | Yes | Stable ID for QA. |
| `cause` | StringName | Yes | Damage #8 hazard cause label. |
| `hitbox_area` | Area2D | Yes | Must use hazard layer/mask expected by Damage #8. |
| `telegraph_node` | Node2D | Optional | Visual read for spikes/lasers/crush. |
| `enabled_on_activation` | bool | Yes | Default true. |

### C.4 Activation Sequence

1. Stage root `_ready()` registers authored EncounterDefinition nodes and validates local IDs are unique.
2. Scene Manager completes POST-LOAD and emits `scene_post_loaded(anchor, limits)`.
3. Stage / Encounter validates `stage_camera_limits`, checkpoint anchor, the root-child `Projectiles: Node2D` container, encounter trigger order, hazard causes, and Area2D budgets.
4. Each encounter enters `ARMED` but spawns no active enemies until its trigger fires unless the encounter is marked `preplaced_active` for static hazards.
5. ECHO overlaps `activation_trigger` for encounter N.
6. Stage captures `activation_frame = Engine.get_physics_frames()`.
7. Stage creates/enables enemies in ascending `spawn_id` order and injects Enemy AI metadata.
8. Encounter state becomes `ENCOUNTER_ACTIVE`.
9. Completion rule passes; encounter becomes `ENCOUNTER_CLEARED` and the next encounter trigger is armed.

### C.5 Interactions with Other Systems

| System | Direction | Stage / Encounter Contract | Forbidden Coupling |
|---|---|---|---|
| **#2 Scene / Stage Manager** | Stage consumes lifecycle | Uses `scene_post_loaded(anchor, limits)` timing and Scene Manager-owned checkpoint reload/stage-clear branch. | Calling `change_scene_to_packed()` directly for restart; owning scene swap lifecycle. |
| **#10 Enemy AI** | Bidirectional | Stage supplies spawn metadata, patrol anchors, activation bounds, target reference, Area2D budget preflight, and deterministic insertion order. | Enemy self-spawn; Stage mutating enemy AI timers or behavior after activation. |
| **#8 Damage** | Stage supplies hosts | Stage places hazard HitBoxes with approved `hazard_*` causes and counts Area2Ds for preflight. | Stage interpreting hit outcomes or emitting `player_hit_lethal` directly. |
| **#3 Camera** | Indirect through Scene Manager | Stage-authored `stage_camera_limits` reach Camera through Scene Manager `scene_post_loaded`. | Stage calling Camera methods directly in Tier 1. |
| **#11 Boss Pattern** | Downstream/upstream mirror | Stage places STRIDER host and final gate; Boss Pattern owns phases, `BossStartSpec` validation, STRIDER arena minimums, and `boss_killed`. | Stage defining boss phase attacks, token reward timing, or boss projectile caps. |
| **#9 Time Rewind** | Negative runtime dependency | Stage is not snapshot-restored; checkpoint restart uses Scene Manager reload. | Stage subscribing to rewind signals to mutate enemy/room state in Tier 1. |
| **#6 Player Movement** | Read/trigger only | Activation triggers detect ECHO's body/area entering the room. | Mutating player velocity, state, hurtbox, or input. |
| **#7 Player Shooting** | Stage-owned container, shooting-owned behavior | Stage scene root provides exactly one `Projectiles: Node2D` root-child container for ECHO projectiles; scene swap frees the container and its children. | Stage spawning ECHO projectiles, mutating ammo/cooldown, interpreting projectile hits, or parenting projectiles under ECHO. |
| **#4 Audio / #14 VFX** | Future presentation | Room start, hazard telegraphs, and encounter clear may offer presentation hooks later. | Presentation changing spawn order, completion rules, or hazard timing. |

### C.6 Signal / Event Surface

Tier 1 Stage / Encounter may expose these debug/presentation signals. Gameplay authority remains with the owning systems listed above.

| Signal | Signature | Fire Condition | Allowed Consumers |
|---|---|---|---|
| `encounter_armed` | `(encounter_id: StringName)` | Encounter validates and becomes armed | Debug HUD, QA logs |
| `encounter_started` | `(encounter_id: StringName, activation_frame: int)` | ECHO enters trigger and activation succeeds | Debug HUD, Audio/VFX future hooks |
| `enemy_spawned_by_stage` | `(encounter_id: StringName, spawn_id: int, enemy: Node2D)` | Enemy instance created/enabled | QA, debug logs |
| `encounter_cleared` | `(encounter_id: StringName)` | Completion rule passes | Debug HUD, Audio/VFX future hooks |
| `stage_preflight_failed` | `(stage_id: StringName, reason: StringName)` | Validation fails before gameplay activation | QA/tests only |

Stage / Encounter must not emit `scene_will_change`, `scene_post_loaded`, `player_hit_lethal`, `enemy_killed`, `boss_killed`, `rewind_started`, or `rewind_completed`.

---

## D. Formulas

All formulas are deterministic and use authored integers, Rect2 bounds, or physics-frame values. Tier 1 assumes 60 physics frames per second.

### D.1 Encounter Seed

The encounter_seed formula is defined as:

`encounter_seed = stage_seed + encounter_index * 1009`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| stage_seed | `S_stage` | int | `0..2,147,483,647` | Authored stable seed on StageDefinition. |
| encounter_index | `I_enc` | int | `0..99` Tier 1 | Authored encounter order. |
| encounter_seed | `S_enc` | int | `0..2,147,483,647` expected | Deterministic seed passed into Enemy AI spawn derivation. |

**Output Range:** Non-negative integer under Tier 1 ranges.
**Example:** `stage_seed=4200`, `encounter_index=3` gives `encounter_seed = 4200 + 3*1009 = 7227`.

### D.2 Spawn ID

The spawn_id formula is defined as:

`spawn_id = encounter_index * 100 + local_spawn_index`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| encounter_index | `I_enc` | int | `0..99` Tier 1 | Encounter order. |
| local_spawn_index | `I_local` | int | `0..99` Tier 1 | Authoring order inside the encounter. |
| spawn_id | `S_id` | int | `0..9999` Tier 1 | Unique enemy spawn identifier consumed by Enemy AI #10. |

**Output Range:** `0..9999` for Tier 1, matching Enemy AI D.2.
**Example:** Encounter 4, local enemy 2 gives `spawn_id = 402`.

### D.3 Enemy AI Seed

The enemy_ai_seed formula is defined as:

`ai_seed = encounter_seed + spawn_id * 37 + archetype_salt`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| encounter_seed | `S_enc` | int | `0..2,147,483,647` | Output of D.1. |
| spawn_id | `S_id` | int | `0..9999` | Output of D.2. |
| archetype_salt | `S_arch` | int | Drone `101`, Security Bot `211`, STRIDER `307` | Mirrors Enemy AI D.2 salts. |
| ai_seed | `S_ai` | int | non-negative expected | Seed injected into EnemyBase. |

**Output Range:** Non-negative integer under Tier 1 ranges.
**Example:** `encounter_seed=7227`, `spawn_id=402`, Security Bot salt `211` gives `ai_seed = 22312`.

### D.4 Activation Frame

The activation_frame formula is defined as:

`activation_frame = Engine.get_physics_frames()`

`spawn_physics_frame(enemy) = activation_frame`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| activation_frame | `F_act` | int | `0..2,147,483,647` | Frame when encounter trigger activates. |
| spawn_physics_frame | `F_spawn` | int | `F_act` Tier 1 | Enemy AI lifetime-clock anchor. |

**Output Range:** `spawn_physics_frame` equals activation frame for all enemies spawned by that activation.
**Example:** If trigger activates on frame `3600`, every enemy created in that activation receives `spawn_physics_frame=3600`.

### D.5 Room Area2D Preflight Budget

The room_area2d_preflight formula is defined as:

`room_area2d_total = enemy_body_count + enemy_projectile_cap + boss_projectile_placeholder + hazard_hitbox_count + other_damage_area2d_count`

`room_area2d_safe = room_area2d_total <= area2d_max_active`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| enemy_body_count | `N_enemy` | int | `0..30` | Active Drone + Security Bot HurtBoxes in the room. |
| enemy_projectile_cap | `N_eproj` | int | `0..24` recommended | Max active standard enemy projectiles declared by the encounter. |
| boss_projectile_placeholder | `N_bproj` | int | `0..16` | Placeholder cap if STRIDER/Boss is present. |
| hazard_hitbox_count | `N_hazard` | int | `0..20` Tier 1 | Active environmental hazard HitBoxes. |
| other_damage_area2d_count | `N_other` | int | `0..80` | ECHO HurtBox, player projectiles, pickups, and other Damage-owned Area2Ds. |
| area2d_max_active | `N_max` | int | `80` | Damage #8 Tier 1 ceiling. |
| room_area2d_safe | `G_area` | bool | `true/false` | Whether the room can activate. |

**Output Range:** Boolean. `false` fails preflight before gameplay activation.
**Example:** `N_enemy=3`, `N_eproj=12`, `N_bproj=0`, `N_hazard=4`, `N_other=18` gives total `37`, so `room_area2d_safe=true`.

### D.6 Stage Progression Order

The stage_progression_order formula is defined as:

`next_encounter_index = current_encounter_index + 1`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| current_encounter_index | `I_current` | int | `0..N-1` | Encounter just cleared. |
| next_encounter_index | `I_next` | int | `1..N` | Next armed encounter; `N` means stage clear gate. |
| encounter_count | `N` | int | `1..8` Tier 1 | Authored encounters in the stage. |

**Output Range:** `0..N`; `N` is the terminal stage-clear route.
**Example:** Clearing encounter `2` in a 5-encounter stage arms encounter `3`.

---

## E. Edge Cases

### E.1 Missing checkpoint anchor

- **If the stage has no active checkpoint anchor during POST-LOAD validation**: fail stage preflight with `stage_preflight_failed(stage_id, &"missing_checkpoint_anchor")`, do not arm encounters, and rely on Scene Manager's existing anchor validation path to prevent unsafe respawn.

### E.2 Multiple active checkpoint anchors in Tier 1

- **If more than one active checkpoint anchor is found**: register the first deterministic scene-tree-order anchor with Scene Manager, emit a debug warning naming all duplicates, and fail CI/stage validation for Tier 1 content. Do not choose randomly or by nearest player distance.

### E.3 Invalid camera limits

- **If `stage_camera_limits.size.x <= 0` or `stage_camera_limits.size.y <= 0`**: fail preflight before emitting/consuming encounter activation. Camera #3 must never receive invalid limits.

### E.4 Encounter trigger overlaps at spawn

- **If ECHO spawns already overlapping an encounter trigger**: activation occurs on the first physics tick after POST-LOAD validation, not during `_ready()`. This keeps Scene Manager, Camera, and Stage initialization order deterministic.

### E.5 Two encounter triggers overlap in one frame

- **If ECHO overlaps two armed triggers in the same physics frame**: activate the lower `encounter_index` only. The higher index remains armed if still valid after the lower encounter clears.

### E.6 Duplicate spawn IDs

- **If two EnemySpawnSpec entries produce the same `spawn_id`**: fail preflight with a deterministic error naming both entries. Do not repair by adding offsets at runtime.

### E.7 Missing Enemy AI patrol anchors

- **If a Drone or Security Bot spawn is missing required patrol anchors**: fail stage preflight for that encounter. Enemy AI has a defensive IDLE fallback, but authored stage content must not rely on that fallback.

### E.8 Identical patrol anchors

- **If patrol anchors are identical**: allow activation and pass both positions to Enemy AI. This is a valid stationary turret-style setup, consistent with Enemy AI E.4.

### E.9 Missing target player reference

- **If Stage cannot find the explicit PlayerMovement reference after POST-LOAD**: fail preflight. Do not let enemies call group lookups for ECHO.

### E.10 Area2D budget overflow

- **If D.5 computes `room_area2d_safe == false`**: fail preflight before gameplay activation and emit `stage_preflight_failed(stage_id, &"area2d_budget_exceeded")`. Do not silently remove hazards, lower projectile caps, skip enemies, or alter Enemy AI runtime schedules.

### E.11 Checkpoint restart during active encounter

- **If ECHO dies and Scene Manager restarts the checkpoint while an encounter is active**: Stage / Encounter performs no in-place cleanup. The scene reload recreates the stage and all encounter state from authored data.

### E.12 Scene transition during activation

- **If `scene_will_change` fires on the same frame an encounter trigger activates**: scene boundary wins. Stage must not instantiate new enemies or emit `encounter_started` after boundary teardown begins.

### E.13 Enemy dies on room-clear frame

- **If the final standard enemy dies on the same frame ECHO touches the room-end trigger**: process deterministic completion once. Prefer `CLEAR_ON_ENEMIES_DEAD` if that is the room's completion rule; otherwise the configured trigger rule applies. Never emit `encounter_cleared` twice.

### E.14 Boss killed before final gate is active

- **If `boss_killed` is received before Stage enters `BOSS_GATE`**: ignore for stage progression and log a debug warning. Boss Pattern #11 should only emit for the active boss encounter.

### E.15 Hazard cause missing or deprecated

- **If a HazardSpec has no `cause` or uses a non-`hazard_` label**: fail preflight. Damage #8 owns taxonomy and Stage must supply exact labels.

### E.16 Enemy outside camera view but inside room bounds

- **If an active enemy leaves the camera viewport but remains inside the active encounter bounds**: keep it active. Visibility is presentation-only; Stage may deactivate enemies only at deterministic room boundary transitions.

### E.17 Player backtracks into a cleared room

- **If ECHO re-enters a cleared encounter trigger**: do not respawn enemies or reset hazards in Tier 1. The room remains cleared until checkpoint restart reloads the stage.

### E.18 Stage clear without Boss Pattern #11 authored

- **If the Tier 1 slice is tested before Boss Pattern #11 is implemented**: use a temporary `CLEAR_ON_TRIGGER_EXIT` final gate fixture marked debug-only. Do not mark production stage-clear proof complete until Boss Pattern owns STRIDER behavior and the Damage-compatible boss host emits `boss_killed`.

---

## F. Dependencies

Stage / Encounter #12 is a Feature-layer system with hard dependencies on Scene Manager #2 and Enemy AI #10. It also consumes Damage #8 hazard taxonomy and Camera #3 limits indirectly through Scene Manager.

### F.1 Upstream Dependencies Consumed by Stage / Encounter

| # | System / Source | Type | Hardness | Stage consumes | Contract Status | Forbidden Coupling |
|---|---|---|---|---|---|---|
| **#2** | [Scene / Stage Manager](scene-manager.md) | System | **Hard** | `scene_post_loaded(anchor, limits)`, checkpoint restart via scene reload, stage-clear branch, `scene_will_change` boundary | Approved | Stage calling scene swap APIs directly; Stage emitting scene lifecycle signals. |
| **#10** | [Enemy AI](enemy-ai.md) | System | **Hard** | Spawn metadata schema, patrol anchors, target reference, deterministic insertion order, Area2D preflight contract | Approved · RR1 PASS | Stage mutating enemy behavior, timers, or state after activation. |
| **#8** | [Damage / Hit Detection](damage.md) | System | **Hard for hazards** | Hazard HitBox cause labels and Area2D ceiling `area2d_max_active=80` | LOCKED for prototype | Stage interpreting hit outcomes or emitting lethal signals. |
| **#3** | [Camera System](camera.md) | System | **Indirect hard** | Valid `stage_camera_limits: Rect2` supplied through Scene Manager | Approved | Stage calling Camera methods directly. |
| **ADR-0003** | [Determinism Strategy](../../docs/architecture/adr-0003-determinism-strategy.md) | Architecture | **Hard** | Physics-frame activation, deterministic spawn order, CharacterBody2D/Area2D boundary | Accepted/Proposed in docs; used by approved GDDs | Runtime random wave composition; RigidBody2D gameplay hazards. |

### F.2 Downstream Systems Depending on Stage / Encounter

| # | System | Dependency | What Stage provides | Current Status | Notes / Obligation |
|---|---|---|---|---|---|
| **#7** | [Player Shooting / Weapon System](player-shooting.md) | **Soft scene-host contract** | Exactly one root-child `Projectiles: Node2D` container for ECHO projectile parenting and scene-swap cleanup | Approved 2026-05-11 | Player Shooting owns projectile behavior, Damage HitBox setup, ammo/cooldown, and null-container assertion; Stage owns only container presence/lifetime. |
| **#11** | [Boss Pattern System](boss-pattern.md) | **Hard** | STRIDER placement, final gate, room bounds, boss start metadata | Approved 2026-05-13 | Boss Pattern owns phases, `phase_hp_table=[3,4,5]`, arena minimum `960×540`, boss projectile cap 16, and `boss_killed`. |
| **#13** | HUD System | **Soft** | Future room/encounter clear presentation hooks | Approved 2026-05-13 | Tier 1 HUD may ignore standard encounter names. |
| **#14** | [VFX / Particle System](vfx-particle.md) | **Soft** | Hazard/room telegraph timing, near-miss/impact context, and encounter start/clear hooks | Approved 2026-05-13 | VFX cannot alter activation order or add gameplay Area2D checks. |
| **#15** | [Collage Rendering Pipeline](collage-rendering.md) | **Soft presentation / authoring** | Stage root `CollageRoot`, room composition context, hazard/background readability constraints | Approved 2026-05-13 | Collage cannot alter spawn order, hazards, camera limits, or encounter activation. |
| **#4** | Audio System | **Soft** | Future encounter start/clear cue hooks | Approved | Audio owns mix and cue mapping; Stage only emits presentation hooks. |

### F.3 Bidirectional Mirror Status

| Source / Target | Mirror Status | Required Follow-up |
|---|---|---|
| `systems-index.md` | Row #12 now links this GDD and lists Scene Manager + Enemy AI | Keep concise; do not list every soft presentation consumer. |
| `scene-manager.md` | Names Stage #12 as primary downstream client and now mirrors Stage as Approved. | Closed; re-check only if Stage lifecycle contracts change. |
| `enemy-ai.md` | Names Stage #12 as hard spawn metadata provider and now mirrors Stage as Approved. | Closed; re-check only if spawn metadata contracts change. |
| `damage.md` | Already names Stage #12 as hazard HitBox host and cause-label owner | No immediate update beyond design-review if hazards change. |
| `camera.md` | Stage limits consumed indirectly through Scene Manager | No immediate update required. |
| Boss Pattern #11 | Approved 2026-05-13 | Re-check only if future Boss Pattern revisions change arena or final-gate handoff. |

### F.4 Data Interfaces

| Data | Owner | Reader | Mutability | Notes |
|---|---|---|---|---|
| `stage_camera_limits` | Stage / Encounter | Scene Manager → Camera | Immutable per stage load | Must be valid before POST-LOAD completes. |
| `Projectiles: Node2D` | Stage / Encounter scene tree | Player Shooting #7 | Container exists for stage lifetime; children owned by Player Shooting | Root-child container; freed with the stage scene on `scene_will_change` / swap. |
| `checkpoint_anchor` | Stage / Encounter scene data | Scene Manager | Immutable Tier 1 | One active anchor in Tier 1. |
| `encounter_seed` | Stage / Encounter | Enemy AI seed derivation | Immutable per stage load | Derived from authored `stage_seed` and encounter index. |
| `spawn_id` | Stage / Encounter | Enemy AI | Immutable after spawn | Unique and ordered. |
| `ai_seed` | Stage / Encounter | Enemy AI | Immutable after spawn | Deterministic formula D.3. |
| `spawn_physics_frame` | Stage / Encounter | Enemy AI | Immutable after activation | Captured from `Engine.get_physics_frames()`. |
| `patrol_anchor_a/b` | Stage / Encounter | Enemy AI | Immutable during active encounter | Marker2D or resolved Vector2. |
| `HazardSpec.cause` | Stage / Encounter, taxonomy by Damage | Damage | Immutable per hazard | Must use Damage #8 `hazard_*` labels. |

---

## G. Tuning Knobs

Stage / Encounter tuning knobs are authored per stage or encounter. They should be changed in scene/resource data, not by hidden runtime logic.

### G.1 Authoring Knob Table

| Knob | Type / Unit | Tier 1 Default | Safe Range | Formula / Rule | Too Low | Too High |
|---|---:|---:|---:|---|---|---|
| `stage_seed` | int | 4200 | `0..2,147,483,647` | D.1 | No deterministic variation namespace | Risk of undocumented seed changes if edited casually |
| `encounter_count` | int | 5 | `1..8` | D.6 | Slice feels empty | Scope exceeds 5-minute core loop / solo budget |
| `enemy_count_per_room` | int | 1-3 | `0..6` Tier 1 | D.5 | Room cannot teach enemy reads | Attention budget and Area2D budget pressure |
| `enemy_projectile_cap_per_room` | int Area2D | 12 | `0..24` recommended | D.5 | Enemy pressure silently under-tested | Area2D ceiling threatened |
| `hazard_count_per_room` | int Area2D | 0-4 | `0..8` Tier 1 | D.5 | Stage lacks spatial threat | Hazards obscure enemy pattern learning |
| `room_bounds_margin_px` | float px | 32 | `0..128` | C.3 / C.4 | Triggers/camera feel cramped | Enemies stay active too far outside room |
| `trigger_width_px` | float px | 32 | `16..128` | C.4 | Player can skip trigger due to speed | Accidental activation from far away |
| `debug_draw_encounters` | bool | false | debug-only | C.6 | QA lacks diagnostics | Shipping visual clutter |

### G.2 Locked Constants, Not Tuning Knobs

- Scene Manager owns scene swap and checkpoint restart.
- Enemy AI owns enemy behavior and projectile schedules.
- Damage owns hit interpretation and hazard cause taxonomy.
- Tier 1 has one active checkpoint anchor.
- Runtime procedural wave composition is forbidden in Tier 1.
- Area2D overflow is a preflight failure, not a runtime culling rule.

### G.3 Cross-Knob Invariants

1. **Area2D invariant**: D.5 must pass before any room activates.
2. **One-new-read invariant**: each early room introduces at most one new enemy/hazard pressure before combined rooms.
3. **Activation-order invariant**: encounter triggers and spawn specs are sorted by `encounter_index` and `spawn_id`; changing order is a design change.
4. **Restart-repeat invariant**: after checkpoint restart, D.1-D.4 values repeat for the same authored stage and trigger sequence.
5. **Camera-limit invariant**: room content must fit inside positive `stage_camera_limits`; no playable room exists outside camera bounds.

### G.4 Tier 1 Presets

| Preset | Use | Key Values | Expected Player Read |
|---|---|---|---|
| **Intro Movement Room** | First 30-60 seconds | 0 enemies, 0-1 hazard, one exit trigger | Learn movement and camera bounds. |
| **Drone Room** | First enemy read | 1 Drone, 0-1 hazard, projectile cap 4 | Watch aerial lane, dodge one shot. |
| **Security Bot Room** | Anti-AimLock lesson | 1 Security Bot, projectile cap 8 | Count burst, move through gap. |
| **Combined Room** | Core-loop proof | 1 Drone + 1 Security Bot, projectile cap 12 | Combine vertical and ground reads. |
| **STRIDER Gate** | Boss handoff | STRIDER host, boss placeholder cap 16 | Enter boss pattern grammar. |

### G.5 Playtest Tuning Priority

When Stage / Encounter difficulty is wrong, tune in this order:

1. Room ordering and spacing.
2. Enemy count per room.
3. Trigger placement and room bounds.
4. Hazard count and visibility.
5. Projectile/enemy caps only after Enemy AI single-enemy reads are fair.

Do not solve difficulty by randomizing spawns, scaling by death count, or mutating Enemy AI behavior from Stage code.

---

## H. Acceptance Criteria

Acceptance criteria are independently testable Given-When-Then conditions.

### H.1 Core Rule Acceptance

| ID | Criterion | Verification Type | Covers |
|---|---|---|---|
| **AC-STG-01** | **GIVEN** the Tier 1 stage scene loads, **WHEN** Stage / Encounter validates metadata after Scene Manager POST-LOAD, **THEN** `stage_id`, `stage_camera_limits`, one active checkpoint anchor, and ordered encounter definitions are present and valid. | Integration | C.1 Rules 1-3 |
| **AC-STG-02** | **GIVEN** Scene Manager emits `scene_post_loaded(anchor, limits)`, **WHEN** Stage / Encounter receives or observes POST-LOAD completion, **THEN** encounters arm only after anchor/camera-limit validation passes. | Integration | C.1 Rule 1 / Rule 13 |
| **AC-STG-03** | **GIVEN** an encounter activates, **WHEN** Stage spawns Drone/Security Bot enemies, **THEN** each enemy receives `spawn_id`, `ai_seed`, `spawn_physics_frame`, activation bounds, patrol anchors, and target player reference without enemy-side group lookup. | Integration | C.1 Rule 4 / F.4 |
| **AC-STG-04** | **GIVEN** multiple enemy spawns share an activation frame, **WHEN** they are inserted into the scene tree, **THEN** insertion order is ascending `spawn_id` and repeated runs produce identical child order. | Logic / determinism | C.1 Rule 5 / D.2 |
| **AC-STG-05** | **GIVEN** ECHO re-enters an already cleared encounter trigger, **WHEN** the trigger overlaps again before checkpoint restart, **THEN** enemies do not respawn and `encounter_started` does not emit again. | Integration | C.1 Rule 6 / E.17 |
| **AC-STG-06** | **GIVEN** ECHO dies during an active encounter, **WHEN** Scene Manager checkpoint restart begins, **THEN** Stage performs no in-place enemy/projectile reset and relies on scene reload to recreate deterministic authored state. | Integration | C.1 Rule 7 / E.11 |
| **AC-STG-07** | **GIVEN** Stage places a standard enemy, **WHEN** the enemy begins behavior, **THEN** Stage does not mutate Enemy AI state counters, patrol math, spotting, firing, or projectile schedules after activation. | Code scan + spy test | C.1 Rule 8 |
| **AC-STG-08** | **GIVEN** a hazard is authored, **WHEN** preflight validates it, **THEN** the hazard has a Damage #8 `hazard_*` cause and Stage does not emit Damage lethal signals directly. | Logic / fixture | C.1 Rule 9 / E.15 |
| **AC-STG-09** | **GIVEN** a room's declared Area2D counts exceed Damage #8 `area2d_max_active=80`, **WHEN** preflight validation runs, **THEN** validation fails before gameplay activation with a deterministic error and no runtime enemy/hazard removal is used as correction. | Logic / preflight | C.1 Rule 10 / D.5 / E.10 |
| **AC-STG-10** | **GIVEN** an encounter's completion rule passes, **WHEN** Stage evaluates progression, **THEN** `encounter_cleared` emits exactly once and the next encounter arms according to `encounter_index + 1`. | Logic / integration | C.1 Rule 11 / D.6 |
| **AC-STG-11** | **GIVEN** STRIDER final gate activates, **WHEN** boss behavior begins, **THEN** Stage provides placement/start metadata only and Boss Pattern #11 owns phases, attacks, token reward timing, and `boss_killed`. | Integration / future mirror | C.1 Rule 12 |
| **AC-STG-12** | **GIVEN** Tier 1 stage data is inspected, **WHEN** grep/static validation runs, **THEN** no procedural generation, runtime random wave composition, or death-count scaling appears in Stage / Encounter gameplay logic. | Static check | C.1 Rule 14 |
| **AC-STG-27** | **GIVEN** the Tier 1 stage scene loads, **WHEN** Stage / Encounter preflight validates scene structure, **THEN** exactly one root-child `Projectiles: Node2D` container exists for Player Shooting #7, and Stage does not instantiate, move, or configure ECHO projectiles itself. | Integration + static check | C.1 Rule 15 / C.5 #7 / F.2 #7 |

### H.2 Formula and Tuning Acceptance

| ID | Criterion | Verification Type | Covers |
|---|---|---|---|
| **AC-STG-13** | **GIVEN** fixed `stage_seed` and `encounter_index`, **WHEN** D.1 computes `encounter_seed`, **THEN** the value is identical across repeated loads. | Logic | D.1 |
| **AC-STG-14** | **GIVEN** encounter/local spawn indices, **WHEN** D.2 computes `spawn_id`, **THEN** all IDs are unique and within Enemy AI's Tier 1 `0..9999` range. | Logic | D.2 |
| **AC-STG-15** | **GIVEN** an EnemySpawnSpec and archetype salt, **WHEN** D.3 computes `ai_seed`, **THEN** the same enemy receives the same seed across checkpoint restarts. | Logic | D.3 |
| **AC-STG-16** | **GIVEN** an encounter activates on frame N, **WHEN** enemies are spawned, **THEN** every spawned enemy receives `spawn_physics_frame == N`. | Integration | D.4 |
| **AC-STG-17** | **GIVEN** room Area2D counts, **WHEN** D.5 preflight runs, **THEN** `room_area2d_safe` exactly matches whether the total is `<= 80`. | Logic | D.5 |
| **AC-STG-18** | **GIVEN** encounter K clears in a stage with N encounters, **WHEN** Stage computes progression, **THEN** encounter K+1 arms or stage clear begins if K+1 == N. | Logic | D.6 |

### H.3 Edge Case and Cross-System Acceptance

| ID | Criterion | Verification Type | Covers |
|---|---|---|---|
| **AC-STG-19** | **GIVEN** no active checkpoint anchor or invalid camera limits, **WHEN** preflight runs, **THEN** Stage fails validation and no encounter activates. | Integration | E.1 / E.3 |
| **AC-STG-20** | **GIVEN** ECHO overlaps two armed triggers in the same frame, **WHEN** Stage processes activation, **THEN** only the lower `encounter_index` starts. | Integration | E.5 |
| **AC-STG-21** | **GIVEN** duplicate spawn IDs, **WHEN** preflight runs, **THEN** Stage fails validation and names both conflicting entries. | Logic | E.6 |
| **AC-STG-22** | **GIVEN** a Drone/Bot spawn lacks patrol anchors, **WHEN** preflight runs, **THEN** Stage fails validation instead of relying on Enemy AI fallback IDLE behavior. | Logic | E.7 |
| **AC-STG-23** | **GIVEN** `scene_will_change` fires while an encounter trigger activates, **WHEN** both events occur in the same physics frame, **THEN** scene boundary wins and Stage instantiates no new enemies after teardown begins. | Integration | E.12 |
| **AC-STG-24** | **GIVEN** the last enemy death and a room-end trigger happen in the same frame, **WHEN** Stage evaluates completion, **THEN** the configured completion rule resolves once and `encounter_cleared` emits once. | Integration | E.13 |
| **AC-STG-25** | **GIVEN** active enemies are outside camera viewport but inside encounter bounds, **WHEN** visibility changes, **THEN** Stage does not deactivate them until a deterministic room boundary transition. | Integration | E.16 / Enemy AI AC-EAI-12 |
| **AC-STG-26** | **GIVEN** Boss Pattern #11 is not authored, **WHEN** a debug final gate fixture is used, **THEN** it is marked debug-only and cannot satisfy production stage-clear proof. | Review / static check | E.18 |

### H.4 First QA Pass Order

1. **Preflight validation**: AC-STG-01, AC-STG-02, AC-STG-09, AC-STG-17, AC-STG-19, AC-STG-21, AC-STG-22, AC-STG-27.
2. **Enemy spawn determinism**: AC-STG-03, AC-STG-04, AC-STG-13, AC-STG-14, AC-STG-15, AC-STG-16.
3. **Encounter lifecycle**: AC-STG-05, AC-STG-06, AC-STG-10, AC-STG-18, AC-STG-20, AC-STG-23, AC-STG-24.
4. **Cross-system boundaries**: AC-STG-07, AC-STG-08, AC-STG-11, AC-STG-12, AC-STG-25, AC-STG-26, AC-STG-27.

---

## Visual/Audio Requirements

Stage / Encounter presentation must make room boundaries, hazard intent, and encounter pacing readable without becoming gameplay authority.

### VA.1 Room Readability

| Element | Visual Requirement | Audio Requirement | Constraint |
|---|---|---|---|
| Encounter trigger | Invisible in final art but aligned with visible doorway/room threshold | Optional subtle room-entry sting later | Trigger visuals/debug overlays must not ship as clutter. |
| Room bounds | Composition frames the active combat space; no important enemy starts outside readable view | None required | Camera limits come through Scene Manager/Camera, not direct Stage calls. |
| Checkpoint anchor | Spawn location visually safe and legible | Optional checkpoint pulse later | Tier 1 may use simple Marker2D/debug fallback during prototype. |
| Hazards | Clear hostile silhouette and pre-contact read | Short hazard cue if Audio budgets it | Hazard VFX cannot decide hit timing. |
| Encounter clear | Door/light/path opens or next room affordance appears | Optional clear cue | Completion rule remains Stage logic. |

### VA.2 Hazard Presentation

- Spike/laser/crush hazards need visible hostile language distinct from enemy bullets and ECHO shots.
- Pit / OOB kill zones need level-art framing that communicates danger before contact.
- Hazard telegraphs may animate, but Damage #8 HitBox timing and Stage activation state remain authoritative.
- During Time Rewind visual shader inversion, hazard silhouettes must remain distinguishable from background collage texture.

### VA.3 Debug Presentation

Debug builds may draw:

- encounter trigger rectangles;
- room bounds;
- spawn IDs above enemies;
- patrol anchor lines;
- Area2D budget totals;
- current encounter state.

Debug overlays must be controlled by `debug_draw_encounters` and must not affect gameplay branches.

### VA.4 Asset and Implementation Handoff

Minimum Tier 1 stage assets:

| Asset Class | Requirement |
|---|---|
| Stage geometry | One side-scrolling corridor/slice with readable platforms and boundaries. |
| Door/threshold markers | Visual affordance for room transitions. |
| Hazard placeholders | Simple colored geometry acceptable if Damage cause labels are testable. |
| Checkpoint marker | Prototype-safe spawn marker; final art can add visual polish later. |
| Debug overlay | Room bounds, spawn IDs, and validation labels for QA. |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:stage-encounter` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

---

## Open Questions

The Tier 1 Stage / Encounter contract is complete enough for design review. These questions are deferred to downstream systems or implementation proof.

| # | Question | Owner | Target | Blocking? | Notes |
|---|---|---|---|---|---|
| OQ-STG-1 | Should Tier 1 implement visible room locks/doors, or rely on camera bounds and encounter triggers only? | level-designer + game-designer | Before first stage implementation story | No | Door locks add clarity but may increase scope. |
| OQ-STG-2 | **RESOLVED 2026-05-13 by approved `boss-pattern.md`** — STRIDER requires `arena_bounds >= 960×540 px`, recommended `1120×620 px`, with Stage supplying `BossStartSpec` and Boss Pattern validating before activation. | level-designer + boss-pattern designer | Closed | No | Stage defines handoff, Boss Pattern defines fight needs. |
| OQ-STG-3 | Which hazard types are in Tier 1 production content versus debug fixtures only? | game-designer + QA lead | Before Stage implementation QA plan | No | Spike/OOB likely enough; crush is optional. |
| OQ-STG-4 | Should encounter clear produce an Audio cue in Tier 1 or wait for polish? | audio-director | Audio/VFX polish pass | No | Audio #4 currently focuses on core player/rewind/death cues. |
| OQ-STG-5 | Should Tier 2 in-place checkpoint reset replace Tier 1 scene reload for memory/performance reasons? | godot-specialist + performance-analyst | Tier 2 gate only | No | Requires reopening Scene Manager OQ-SM-A2. |

### Deferred Follow-Up Actions

1. Run `/design-review design/gdd/stage-encounter.md --depth lean` in a fresh session.
2. After approval, update reciprocal mirrors if review requests more precise Stage/Scene/Enemy/Damage wording.
3. Re-check `boss-pattern.md` after Boss Pattern #11 design review if arena or final-gate findings change Stage handoff.
