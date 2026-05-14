# Enemy AI Base + Archetypes

> **Status**: Approved
> **Author**: user + game-designer + ai-programmer + systems-designer
> **Created**: 2026-05-12
> **Last Updated**: 2026-05-13
> **Implements Pillar**: Pillar 2 (Deterministic Patterns) primary; Pillar 1 (Learning Tool) via readable, learnable patterns
> **Engine**: Godot 4.6 / GDScript / 2D / `CharacterBody2D`
> **System #**: 10 (Feature / Gameplay)

---

## A. Overview

Enemy AI Base + Archetypes is the Feature-layer system that makes all non-player combat entities in Echo (Drone, Security Bot, STRIDER mini-boss) behave with *deterministic and readable* patterns. The system is the single source of truth for two aspects.

**(1) Architecture Layer** — Built on `EnemyBase extends CharacterBody2D` (ADR-0003), providing `compute_ai_velocity(frame_offset: int) -> Vector2` as the deterministic extension point. All AI logic is written as pure functions of `frame_offset` (`Engine.get_physics_frames() - spawn_physics_frame`) and a per-encounter seed `RandomNumberGenerator` — no global RNG, no wall-clock dependency. `process_physics_priority = 10`: after Player (0) · TRC (1) · Damage (2), before Projectiles (20) (ADR-0003 priority ladder).

**(2) Player-Perception Layer** — Each archetype creates threats the player can learn and predict through *telegraphed patterns*. Pillar 2 ("Deterministic Patterns — luck is the enemy") is realized by basing every behavioral decision in this system on frame counters and fixed seeds — the same inputs in the same encounter always produce the same enemy behavior. This is what enables Pillar 1 ("Time Rewind is a learning tool"): because death converts to *repeatable pattern exposure*.

**Tier 1 archetypes (3 types)**: Drone (aerial patrol + single shot), Security Bot (ground patrol + burst fire), STRIDER (mini-boss — multi-phase patterns, host of Boss Pattern #11). All archetypes inherit from a single `EnemyBase`; the differences lie in `compute_ai_velocity()` implementation and HitBox layout. Damage #8 provisions enemy HitBox/HurtBox components, and standard enemies die in 1 hit (DEC-3) — firing the `enemy_killed` signal on death. Stage/Encounter #12 handles spawn orchestration, and Boss Pattern #11 owns the STRIDER phase script.

---

## B. Player Fantasy

**Lead fantasy: "VEIL's army runs on rules. You are the anomaly."**

Enemy AI is a direct player-facing combat system with an infrastructure layer beneath it. The player should not feel that enemies are "smart" in a black-box simulation sense. The player should feel that every enemy is a visible, repeatable rule set: a machine that can kill them once, teach them once, and then be broken on the next attempt.

The anchor moment is:

> ECHO enters a corridor and a Security Bot fires a three-shot burst. On the first attempt, the second bullet catches the landing arc and triggers death. Rewind restores ECHO just before the mistake. On the next attempt, the player jumps one frame earlier, sees the same burst timing repeat, fires through the opening, and destroys the bot before the third shot. The player's sentence is not "I got lucky." It is: "I learned the rule."

This is the emotional contract of Enemy AI #10: enemies are **readable threats**, not improvising opponents. They look dangerous because their telegraphs, spacing, and bullet patterns create pressure; they feel fair because the same encounter seed and same frame history produce the same pattern. Pillar 2 is therefore not an implementation detail here — it is the player's trust contract.

### B.1 Core Emotional Targets

| Target | Player Feeling | Design Meaning |
|---|---|---|
| **Readable danger** | "I know what this enemy is about to do, even if I am too slow this time." | Telegraphs must precede lethal output. Silhouette, wind-up, aim line, muzzle flash, and movement cadence communicate the rule. |
| **Pattern mastery** | "I died because I misread the pattern, not because the game rolled a bad outcome." | Randomness is prohibited in lethal decisions. Seeded variation may select a pattern at spawn, but once the encounter begins, execution is frame-deterministic. |
| **Rewind-as-learning** | "The rewind gave me a second look at the same lesson." | Enemy rule tables and state transitions do not mutate after player death or rewind. Enemies are not snapshot-restored, but the lesson remains deterministic, visible, and correctable. |
| **Pressure without overload** | "There is one problem to solve right now." | Each archetype teaches one primary read in Tier 1. Mixed encounters may combine reads, but the combined cognitive load must stay below the core-loop budget. |

### B.2 Reference Lineage

| Reference | Echo borrows | Echo differs |
|---|---|---|
| **Contra** | Side-scrolling soldiers, deterministic enemy waves, learnable projectile lanes | Echo replaces "memorize the entire level or restart" with immediate rewind-based retry of the same local pattern. |
| **Katana Zero** | One-hit lethality, time manipulation, precision mastery | Katana Zero's fantasy is pre-visualized execution. Echo's enemy fantasy is post-death pattern recognition: the player learns after being hit, then revokes the mistake. |
| **Hotline Miami** | Fast death, fast retry, "my fault" clarity | Hotline Miami restarts the room. Echo restores a pre-death frame inside the same encounter, so the enemy rule must remain stable across the rewind. |
| **Metal Slug / arcade run-and-gun lineage** | Strong silhouettes, exaggerated wind-ups, simple enemy archetypes | Echo cannot rely on chaos or comedic surprise for lethal outcomes; every lethal pattern must be deterministic and inspectable. |

### B.3 Pillar Alignment

- **Pillar 1 — Time Rewind is a learning tool, not a punishment**: Enemy patterns are the lessons that rewind lets the player re-read. A rewind that returns the player into a different enemy behavior would convert learning into gambling, so Enemy AI must preserve pattern identity across attempts.
- **Pillar 2 — Deterministic Patterns: luck is the enemy**: This system is the primary owner of Pillar 2 in moment-to-moment play. All lethal behavior must be derived from frame counters, authored pattern tables, fixed encounter seeds, and explicit state transitions — never wall-clock time or global randomness.
- **Pillar 3 — Collage is the first impression**: Enemy silhouettes must remain distinguishable inside collage noise. A threat that cannot be identified in a short glance is not readable danger; it is visual ambiguity.
- **Pillar 4 — 5-Minute Rule**: The first enemy encounter must teach the loop without text: spot the telegraph, dodge or shoot, die if misread, rewind, correct the timing.
- **Pillar 5 — Small success over big ambition**: Tier 1 favors three clear archetypes over a large bestiary. The promise is depth of read, not quantity of enemy types.

### B.4 Tier 1 Archetype Fantasy Roles

| Archetype | Fantasy Role | Primary Read | Anti-Stationary Pressure |
|---|---|---|---|
| **Drone** | Aerial metronome | "The sky lane is not safe forever." | Patrol + single shot punishes players who tunnel-aim horizontally. |
| **Security Bot** | Ground burst instructor | "Count the burst, then move through the gap." | Three-shot cadence punishes stationary AimLock play without requiring random flanking. |
| **STRIDER** | Pattern exam / mini-boss host | "You know the grammar; now survive the paragraph." | Multi-phase pressure belongs to Boss Pattern #11, but STRIDER must still inherit EnemyBase determinism and readable telegraphs. |

### B.5 Anti-Fantasy

Enemy AI must never create the following feelings:

- **"The enemy randomly decided to kill me"** — Global RNG, wall-clock timers, and nondeterministic physics are forbidden for lethal behavior.
- **"The enemy cheated after I rewound"** — Rewind must not cause enemies to silently retarget, skip wind-up, or advance hidden timers in a way the player cannot infer.
- **"I cannot tell what hit me"** — Damage #8 owns cause-aware death, but Enemy AI owns the visual readability of the projectile and attacker that caused it.
- **"The only safe strategy is standing still with AimLock"** — At least one Tier 1 archetype must punish stationary play with a deterministic, readable pattern.
- **"Every enemy is a different rulebook"** — Tier 1 archetypes must share a common grammar: telegraph, commit, fire/move, recovery. Differences should be visible, not hidden in code.
- **"The game is simulating intelligence I cannot inspect"** — Complex emergent AI is out of scope. Echo's enemies are authored pattern instruments.

### B.6 Fantasy Protection Decisions

The Player Fantasy is protected by four locked design commitments:

1. **Frame-based behavior**: All enemy decisions use `Engine.get_physics_frames() - spawn_physics_frame` or state-local frame counters as their time source.
2. **Readable telegraph before lethal output**: Every projectile, burst, leap, or phase attack has a visible anticipation window before it can kill ECHO.
3. **One-hit standard enemy clarity**: Damage #8 DEC-3 remains intact. Standard enemies differ by pattern, not HP count.
4. **Read-only player dependency**: Enemy AI may read Player Movement `global_position`; it may not mutate player state, call player methods, or depend on player-owned signals.

---

## C. Detailed Design

### C.1 Core Rules

**Rule 1 — `EnemyBase` is the common host contract.**
Every Tier 1 enemy root is `EnemyBase extends CharacterBody2D`, inheriting ADR-0003's deterministic movement contract. `EnemyBase` owns:

- `entity_id: StringName`
- `archetype_id: StringName`
- `ai_seed: int`
- `spawn_id: int`
- `spawn_physics_frame: int`
- `process_physics_priority = 10`
- `enemy_sm: StateMachine`
- `target_player: PlayerMovement` as an explicit exported node reference or Stage-injected reference

`EnemyBase` may expose virtual methods such as `compute_ai_velocity(frame_offset: int) -> Vector2`, `can_spot_player(frame_offset: int) -> bool`, and `emit_attack(frame_offset: int) -> void`, but subclasses may not replace the deterministic clock, physics node type, or damage model.

**Rule 2 — enemy time is frame-counted, not wall-clocked.**
All behavior uses:

```gdscript
frame_offset = Engine.get_physics_frames() - spawn_physics_frame
state_frame = Engine.get_physics_frames() - enemy_sm.current_state_entered_frame
```

Forbidden in enemy gameplay logic:

- `Time.get_ticks_msec()`
- `_process(delta)` timers
- global `randf()`, `randi()`, or `RandomNumberGenerator.randomize()`
- animation-finished callbacks as authoritative gameplay transition clocks
- `RigidBody2D` or solver-driven movement

Seeded RNG is allowed only for selecting an authored variant at spawn time. After `_ready()` / Stage spawn initialization completes, lethal behavior must be a deterministic function of `(encounter_seed, spawn_id, spawn_physics_frame, frame_offset, state, target snapshot reads)`.

**Rule 3 — Enemy AI is not a rewind-restored system.**
ADR-0001 keeps rewind scope player-only. Enemy entities, enemy projectiles, and enemy state machines are not captured in `PlayerSnapshot` and are not restored when ECHO rewinds. Therefore Enemy AI's learning guarantee is not "the whole world rewinds." The guarantee is:

1. enemy rule tables do not change because a rewind occurred;
2. hidden timers do not branch on rewind events in Tier 1;
3. any post-rewind attack still obeys the same telegraph → commit → output grammar;
4. any future `on_player_rewind` behavior must be authored as an explicit new rule and review item, not a hidden side effect.

Tier 1 Enemy AI does **not** subscribe to `rewind_started` or `rewind_completed`; it only reads ECHO's current `global_position` during its own priority-10 physics tick.

**Rule 4 — every lethal output has a readable telegraph.**
No enemy projectile, contact hitbox, leap, laser, burst, or boss-hosted attack may become lethal before a visible anticipation interval completes. The telegraph can be a pose, aim line, muzzle charge, audio cue, animation frame, or silhouette change, but it must be tied to an explicit state-local frame counter. Cosmetic animation can lead or follow the counter; it cannot replace the counter.

**Rule 5 — standard enemies die in one hit.**
Damage #8 DEC-3 is inherited without modification. Drone and Security Bot use enemy HurtBox layer L3 and die on the first valid ECHO projectile hit. Standard enemies differ through movement, telegraph, projectile cadence, and arena placement — never through hidden HP or armor.

**Rule 6 — STRIDER is an EnemyBase host, but Boss Pattern owns phases.**
STRIDER inherits EnemyBase for deterministic movement, damage-component placement, state-machine reuse, and process ordering. Boss Pattern #11 owns phase scripts, phase thresholds, boss-only projectile patterns, and token reward timing. Enemy AI #10 defines only the base contract that allows STRIDER to be a deterministic enemy host.

**Rule 7 — player dependency is read-only.**
Enemy AI may read `target_player.global_position` during priority-10 `_physics_process`. It may not:

- call PlayerMovement methods;
- mutate ECHO velocity, position, animation, weapon, hurtbox, or state;
- subscribe to player-owned movement signals;
- directly cause Time Rewind token consumption;
- bypass Damage #8 for lethal outcomes.

**Rule 8 — projectile ownership follows ADR-0003 and Damage #8.**
Enemy projectiles are `Area2D` script-stepped projectiles with `process_physics_priority = 20`. Standard enemy projectile HitBoxes use layer L4 and mask ECHO HurtBox L1 only. Friendly fire remains blocked in Tier 1. Enemy AI instantiates projectiles; Damage owns hit interpretation.

**Rule 9 — Tier 1 cause labels are archetype-specific for standard enemies.**
To satisfy Damage #8 B.3 "cause-aware death" when Drone and Security Bot coexist, standard enemy projectiles use specific causes:

| Archetype | Projectile cause |
|---|---|
| Drone | `&"projectile_enemy_drone"` |
| Security Bot | `&"projectile_enemy_secbot"` |
| STRIDER / boss-hosted attacks | `&"projectile_boss"` |

`damage.md` originally listed `&"projectile_enemy"` as the Tier 1 baseline and explicitly delegated the 3-type coexistence decision to Enemy AI #10. This section resolves that obligation in favor of subtype causes; Damage #8 C.5.2, D.3.1, D.3.2, and F.1 were mirrored on 2026-05-13.

**Rule 10 — Stage/Encounter owns spawn orchestration.**
Enemy AI does not choose when or where enemies spawn. Stage/Encounter #12 supplies spawn position, `spawn_id`, `ai_seed`, `spawn_physics_frame`, patrol anchors, activation bounds, and target player reference. Enemy AI consumes those values deterministically. If Stage/Encounter is not yet implemented, test fixtures may inject the same fields directly.

**Rule 11 — dynamic child order must be deterministic.**
When multiple enemies or projectiles are spawned in the same physics frame, insertion order follows `(spawn_physics_frame, spawn_id)` ascending. Enemy AI may not call `add_child()` using iteration over an unordered dictionary. Projectile pools must preserve deterministic checkout order.

**Rule 12 — visibility and culling must not change gameplay decisions.**
Tier 1 enemies do not self-disable AI because they are outside the camera view. Stage/Encounter may despawn or deactivate enemies only at deterministic room boundaries. Visual culling, if added, is render-only and cannot pause state counters, cooldowns, or projectile schedules.

**Rule 13 — squad coordination is out of scope for Tier 1.**
Enemies do not broadcast perception or subscribe to each other. No per-enemy signal fanout is allowed for "alert all nearby enemies" behavior in Tier 1. Mixed encounters are authored by Stage/Encounter placement, not by runtime squad intelligence.

### C.2 Tier 1 Archetype Specifications

| Archetype | Movement Model | Attack Model | Primary Lesson | Tier 1 Scope Lock |
|---|---|---|---|---|
| **Drone** | Aerial patrol between two Stage-provided anchors. Ignores floor navigation. Movement is a deterministic patrol curve, not `NavigationAgent2D`. | Single projectile after a telegraphed aim pose. Projectile direction is selected from authored lanes, biased toward ECHO's position read at FIRE commit. | The vertical lane is unsafe; watch sky silhouettes while moving horizontally. | No flocking, no homing projectile, no random hover jitter. |
| **Security Bot** | Ground patrol between two Stage-provided anchors. Turns at anchors or wall bounds. No chase outside patrol band in Tier 1. | Three-shot burst after wind-up. Direction locks at commit, then fires at fixed cadence. | Count the burst, cross through the gap, punish recovery. | Anti-stationary AimLock pressure owner. No cover system, no crouch, no pathfinding. |
| **STRIDER** | EnemyBase-compatible boss host. Base locomotion and HurtBox layout are deterministic. | Boss Pattern #11 owns phase attacks and projectile scripts. Enemy AI provides only base hooks. | Pattern exam: combines known grammar into a longer sequence. | No phase design in this GDD beyond the host contract. |

### C.3 Common Enemy State Machine

All Tier 1 standard enemies use the reusable State Machine Framework (#5) without forking `State.gd` or `StateMachine.gd`.

| State | Purpose | Allowed Actions | Exit Conditions |
|---|---|---|---|
| `IDLE` | Spawned but not active, or waiting for Stage activation. | Hold velocity at zero; collisions active only if Stage marks the enemy active. | Stage activation → `PATROL`; valid lethal hit → `DEAD`. |
| `PATROL` | Default deterministic movement. | Call `compute_ai_velocity(frame_offset)`; move between patrol anchors; read player position for perception checks only. | Player enters detection rule → `SPOT`; valid lethal hit → `DEAD`; Stage deactivation → `IDLE`. |
| `SPOT` | Recognition / telegraph start. | Face or orient toward the player; cache `target_snapshot_position`; start `state_frame` counter; play/readable warning pose. | `state_frame >= spot_confirm_frames` → `FIRE`; player exits detection before confirm → `PATROL`; valid lethal hit → `DEAD`. |
| `FIRE` | Telegraph completion, attack commit, projectile emission, and recovery. | Execute state-local substages `WIND_UP`, `EMIT`, `RECOVER` using `state_frame`; spawn projectiles only during `EMIT`; block retargeting until recovery ends. | `state_frame >= fire_total_frames` → `PATROL` or `SPOT` based on current detection; valid lethal hit → `DEAD`. |
| `DEAD` | One-shot cleanup. | Disable HurtBox monitoring; emit/relay exactly one `enemy_killed`; play death VFX/SFX hook; queue deterministic cleanup. | Terminal; `queue_free()` after cleanup frames or pool return. |

`FIRE` contains substages so the Tier 1 DroneAISM still satisfies state-machine.md C.4.1's 5-state reuse proof (`IDLE / PATROL / SPOT / FIRE / DEAD`) while preserving the Player Fantasy requirement that lethal output is telegraphed.

### C.4 Transition Table

| From | Trigger | To | Determinism Rule |
|---|---|---|---|
| `IDLE` | Stage activation flag true | `PATROL` | Stage supplies activation frame and spawn metadata. |
| `IDLE` / `PATROL` / `SPOT` / `FIRE` | Enemy HurtBox receives valid ECHO projectile hit | `DEAD` | Damage signal path executes synchronously; duplicate hits are ignored after death latch. |
| `PATROL` | `can_spot_player(frame_offset)` true | `SPOT` | Uses player position read at priority 10 and authored detection bounds. |
| `SPOT` | `state_frame >= spot_confirm_frames` | `FIRE` | No wall-clock timer; frame counter only. |
| `SPOT` | player exits detection before confirm | `PATROL` | Exit threshold must use deterministic bounds/hysteresis, not a timer callback. |
| `FIRE` | state-local `EMIT` substage reached | `FIRE` | Projectile spawned once per configured shot frame. State does not change. |
| `FIRE` | `state_frame >= fire_total_frames` and player still detected | `SPOT` | Re-acquires through normal telegraph path; no immediate second burst. |
| `FIRE` | `state_frame >= fire_total_frames` and player not detected | `PATROL` | Resume patrol from current deterministic position. |
| `DEAD` | cleanup frames elapsed | terminal | Queue-free or pool return in deterministic order. |

### C.5 Archetype-Specific State Behavior

#### C.5.1 Drone

- `PATROL`: moves along a Stage-provided aerial lane. The lane may be horizontal or shallow diagonal; no terrain navigation.
- `SPOT`: rotates/poses toward ECHO if ECHO is inside a rectangular detection band.
- `FIRE`: caches ECHO position at attack commit, selects one authored projectile lane, emits one projectile, then recovers.
- `DEAD`: falls or pops visually, but gameplay collision is disabled immediately on death entry.

#### C.5.2 Security Bot

- `PATROL`: walks between ground anchors and flips at endpoints.
- `SPOT`: stops, faces ECHO, and visibly winds up.
- `FIRE`: locks aim direction at commit and emits three shots at fixed frame offsets. The bot cannot move during burst emission.
- `DEAD`: disables HurtBox and body collision before cleanup to prevent post-death blocking.

Security Bot is the Tier 1 anti-stationary AimLock counter. Its burst cadence should punish players who freeze in AimLock through the whole wind-up, but the wind-up must be long enough for a moving player to dodge on reaction after learning the pattern.

#### C.5.3 STRIDER

- `IDLE` / `PATROL` / `DEAD` semantics come from EnemyBase.
- Boss Pattern #11 may replace `SPOT` / `FIRE` behavior with phase-specific states, but must preserve the same deterministic clock, process priority, Damage #8 integration, and readable telegraph requirement.
- STRIDER uses boss HurtBox/Boss Pattern damage semantics, not standard enemy 1-hit death.

### C.6 States and Transitions Summary

See C.3–C.5. The canonical Tier 1 standard enemy state list is:

```text
IDLE → PATROL → SPOT → FIRE → PATROL
  │       │       │      │
  └───────┴───────┴──────┴──→ DEAD
```

Only `DEAD` is terminal. All non-terminal transitions must be expressible with the existing State Machine Framework virtual methods and synchronous `transition_to(...)` calls. No enemy state may trigger transitions from `_process`, Godot `Timer` nodes, animation-finished callbacks, or deferred callbacks.

### C.7 Interactions with Other Systems

| System | Direction | Contract | Forbidden Coupling |
|---|---|---|---|
| **#5 State Machine Framework** | Enemy AI consumes | `EnemySM` reuses `State` / `StateMachine` unchanged. Host priority 10 determines tick order. `last_transition_frame` is recorded for determinism tests. | Forking the framework for enemies; HSM assumptions in Tier 1; wall-clock transition triggers. |
| **#8 Damage / Hit Detection** | Bidirectional composition | Enemy hosts HurtBox L3. Enemy projectiles host HitBox L4. Standard enemy death emits `enemy_killed(enemy_id, cause)` once. | Enemy directly deciding player death; enemy-specific HP for standard enemies; friendly fire unless Tier 2 mode explicitly reopens it. |
| **#6 Player Movement** | Enemy AI reads | Enemy reads `target_player.global_position` during priority-10 physics tick. | Calling PM methods, subscribing to PM state changes, mutating player state, or depending on PM internals beyond `global_position`. |
| **#7 Player Shooting** | Indirect through Damage | ECHO projectile HitBox L2 can hit enemy HurtBox L3. Enemy AI does not inspect weapon state. | Enemy reading ammo, weapon cooldown, or player input. |
| **#9 Time Rewind** | No direct Tier 1 dependency | Enemy is not snapshot-restored and does not subscribe to rewind signals. Determinism is preserved by stable rules, not world rollback. | Hidden retargeting or timer reset on rewind; adding `on_player_rewind` without an explicit design review. |
| **#12 Stage / Encounter** | Stage provides spawn data | Stage supplies `spawn_id`, `ai_seed`, `spawn_physics_frame`, patrol anchors, activation bounds, and target reference. Enemy consumes these values. | Enemy self-spawning, random spawn selection, or reading scene-tree groups to discover player/anchors implicitly. |
| **#11 Boss Pattern** | Boss Pattern consumes EnemyBase | STRIDER inherits EnemyBase and priority 10. Boss Pattern owns phases, boss attacks, phase transitions, and token reward implications. | Enemy AI defining boss phase scripts or boss HP thresholds. |
| **#4 Audio** | Downstream via signals/events | Enemy attack telegraphs and death events provide hooks for SFX. Audio owns playback and pool limits. | Enemy directly mixing buses or controlling music ducking. |
| **#3 Camera** | Downstream via combat events | Enemy projectile/death effects may indirectly cause camera feedback through Damage/Boss signals. | Enemy directly shaking camera. |
| **#14 VFX / #16 Rewind Visual Shader** | Downstream presentation | Enemy exposes canonical presentation/debug signals (`enemy_spotted_player`, `enemy_attack_committed`, `enemy_projectile_spawned`, `enemy_died`) plus animation names for VFX. Damage remains the source of record for `enemy_killed`. | VFX changing gameplay state counters or projectile timing. |

### C.8 Event / Signal Surface Owned by Enemy AI

Enemy AI may expose these signals for downstream presentation and debug consumers:

| Signal | Signature | Fire Condition | Notes |
|---|---|---|---|
| `enemy_spotted_player` | `(enemy_id: StringName, archetype_id: StringName)` | Enter `SPOT` | Presentation/debug only; no gameplay consumer may rely on this for player state. |
| `enemy_attack_committed` | `(enemy_id: StringName, archetype_id: StringName, cause: StringName)` | `FIRE` reaches commit frame before projectile spawn | Lets Audio/VFX line up telegraph completion. |
| `enemy_projectile_spawned` | `(enemy_id: StringName, projectile: Node2D, cause: StringName)` | Projectile instance created | Debug/test hook; Damage remains hit authority. |
| `enemy_died` | `(enemy_id: StringName, archetype_id: StringName)` | Enter `DEAD` | Local presentation hook. Damage `enemy_killed` remains the cross-system kill signal of record. |

Enemy AI must not emit `player_hit_lethal`, `lethal_hit_detected`, `death_committed`, `boss_phase_advanced`, or `boss_killed`; those remain Damage/Boss/Scene contracts.

### C.9 Debug / Test Observability

For determinism testing, each EnemyBase exposes read-only debug fields in debug builds:

- `debug_current_state: StringName`
- `debug_state_frame: int`
- `debug_frame_offset: int`
- `debug_last_transition_frame: int`
- `debug_projectile_emit_frames: PackedInt32Array`
- `debug_target_snapshot_position: Vector2`

These values are observational only. Tests may read them; gameplay code may not branch on debug fields.

---

## D. Formulas

All formulas in this section use integer physics frames as the gameplay clock. Unless explicitly stated otherwise, Tier 1 assumes 60 physics ticks per second. Formula values are Tier 1 authoring defaults; Section G records them as tuning knobs and safe ranges.

### D.1 Enemy Frame Offsets

The enemy_frame_offsets formula is defined as:

`frame_offset = current_physics_frame - spawn_physics_frame`

`state_frame = current_physics_frame - current_state_entered_frame`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| current_physics_frame | `F_now` | int | `0..2,147,483,647` | Value read from `Engine.get_physics_frames()` during the enemy priority-10 physics tick. |
| spawn_physics_frame | `F_spawn` | int | `0..F_now` | Frame when Stage/Encounter created or activated the enemy. |
| current_state_entered_frame | `F_state` | int | `F_spawn..F_now` | Frame recorded by EnemySM when the current state was entered. |
| frame_offset | `F_offset` | int | `0..2,147,483,647` | Enemy lifetime clock, used for patrol and deterministic variant timing. |
| state_frame | `F_local` | int | `0..2,147,483,647` | State-local clock, used for telegraphs, burst timing, and recovery. |

**Output Range:** `frame_offset >= 0`, `state_frame >= 0`. Negative outputs are invalid and indicate spawn metadata was not initialized before activation.
**Example:** If `current_physics_frame = 1260`, `spawn_physics_frame = 1200`, and `current_state_entered_frame = 1248`, then `frame_offset = 60` and `state_frame = 12`.

### D.2 Deterministic Variant Selection

The enemy_variant_index formula is defined as:

`enemy_variant_index = (encounter_seed + spawn_id * 1103515245 + archetype_salt) mod variant_count`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| encounter_seed | `S_enc` | int | `0..2,147,483,647` | Stage/Encounter-owned seed for the room or encounter. |
| spawn_id | `S_id` | int | `0..9999` Tier 1 | Deterministic per-encounter spawn order identifier. |
| archetype_salt | `S_arch` | int | `0..9999` | Fixed per-archetype constant; Drone default `101`, Security Bot default `211`, STRIDER default `307`. |
| variant_count | `N_var` | int | `1..8` Tier 1 | Number of authored variants for the archetype. |
| enemy_variant_index | `I_var` | int | `0..N_var-1` | Selected authored variant. |

**Output Range:** `0` to `variant_count - 1`. If `variant_count == 1`, output is always `0`.
**Example:** `encounter_seed = 42`, `spawn_id = 3`, `archetype_salt = 101`, `variant_count = 4` gives `(42 + 3 * 1103515245 + 101) mod 4 = 2`. The enemy uses authored variant index `2`.

This formula replaces global RNG for Tier 1 variant selection. It may select patrol timing offsets, animation pose variants, or authored lane variants, but it must not produce runtime improvisation after the enemy is active.

### D.3 Back-and-Forth Patrol Position

The patrol_position formula is defined as:

`cycle_frame = frame_offset mod patrol_period_frames`

`patrol_t = 1.0 - abs((2.0 * cycle_frame / patrol_period_frames) - 1.0)`

`patrol_position = patrol_anchor_a.lerp(patrol_anchor_b, patrol_t)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| frame_offset | `F_offset` | int | `0..2,147,483,647` | Enemy lifetime clock from D.1. |
| patrol_period_frames | `P_patrol` | int | `60..300` | Full A→B→A patrol cycle. Drone default `180`; Security Bot default `240`. |
| cycle_frame | `F_cycle` | int | `0..P_patrol-1` | Position inside current patrol cycle. |
| patrol_anchor_a | `A` | Vector2 | Stage-authored | First patrol endpoint. |
| patrol_anchor_b | `B` | Vector2 | Stage-authored | Second patrol endpoint. |
| patrol_t | `t` | float | `0.0..1.0` | Interpolation factor between anchors. |
| patrol_position | `P_enemy` | Vector2 | segment `A..B` | Desired enemy position before collision adjustment. |

**Output Range:** `patrol_t` is always `0.0..1.0`; `patrol_position` always lies on the authored A-B segment.
**Example:** A Drone with `A=(100, 180)`, `B=(260, 180)`, `patrol_period_frames=180`, and `frame_offset=45` gives `cycle_frame=45`, `patrol_t=0.5`, and `patrol_position=(180, 180)`.

Security Bot uses the same formula but applies `move_and_slide()` along the ground lane. Drone uses it directly as the desired aerial lane position.

### D.4 Spot Gate

The spot_gate formula is defined as:

`dx = target_player_position.x - enemy_position.x`

`dy = target_player_position.y - enemy_position.y`

`spot_gate = active and abs(dx) <= detect_range_x and abs(dy) <= detect_range_y and facing_gate(dx, facing_direction)`

Where:

`facing_gate(dx, facing_direction) = true if allow_back_detection == true else sign_or_zero(dx) == facing_direction or dx == 0`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| active | `A_on` | bool | `true/false` | Stage activation flag. Inactive enemies cannot spot. |
| target_player_position | `P_player` | Vector2 | world coordinates | ECHO `global_position` read during priority-10 tick. |
| enemy_position | `P_enemy` | Vector2 | world coordinates | Enemy `global_position` during priority-10 tick. |
| detect_range_x | `R_x` | float | `96..480 px` | Horizontal detection half-width. Drone default `320`; Security Bot default `360`. |
| detect_range_y | `R_y` | float | `48..240 px` | Vertical detection half-height. Drone default `180`; Security Bot default `96`. |
| facing_direction | `D_face` | int | `-1 or 1` | Enemy's current horizontal facing. |
| allow_back_detection | `B_back` | bool | `true/false` | Tier 1 default `false` for Security Bot, `true` for Drone. |
| spot_gate | `G_spot` | bool | `true/false` | Whether `PATROL` may transition to `SPOT`. |

**Output Range:** Boolean. `true` allows `PATROL → SPOT`; `false` keeps or returns to patrol.
**Example:** Security Bot at `(500, 300)`, ECHO at `(740, 320)`, `R_x=360`, `R_y=96`, `facing_direction=1`, `allow_back_detection=false`: `dx=240`, `dy=20`, all checks pass, so `spot_gate=true`.

If `dx == 0`, the target is vertically aligned with the enemy. Treat that as inside the facing gate when the range checks pass; this avoids a one-pixel dead zone directly above or below the enemy and keeps vertical-lane Drone/Security Bot fixtures deterministic.

This formula is intentionally rectangular rather than raycast-based in Tier 1. Line-of-sight and cover are Stage/Encounter Tier 2 candidates, not baseline Enemy AI.

### D.5 Telegraph and Attack Window

The attack_window formula is defined as:

`commit_frame = wind_up_frames`

`emit_window_start = commit_frame`

`emit_window_end = commit_frame + emit_duration_frames - 1`

`fire_total_frames = wind_up_frames + emit_duration_frames + recovery_frames`

`can_emit_attack = state_frame >= emit_window_start and state_frame <= emit_window_end`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| state_frame | `F_local` | int | `0..fire_total_frames` | Frame since entering `FIRE`. |
| wind_up_frames | `W_fire` | int | `18..60` | Visible anticipation before lethal output. Drone default `24`; Security Bot default `30`. |
| emit_duration_frames | `E_fire` | int | `1..36` | Active emission window. Drone default `1`; Security Bot default `21`. |
| recovery_frames | `R_fire` | int | `12..60` | Post-attack recovery before re-spotting. Drone default `24`; Security Bot default `24`. |
| commit_frame | `F_commit` | int | `18..60` | First frame where attack output may begin. |
| fire_total_frames | `F_total` | int | `31..156` | Total `FIRE` state duration. |
| can_emit_attack | `G_emit` | bool | `true/false` | Whether this frame is inside the attack emission window. |

**Output Range:** `can_emit_attack` is boolean; `fire_total_frames` is positive and bounded by the configured ranges.
**Example:** Security Bot defaults: `W_fire=30`, `E_fire=21`, `R_fire=24`. Then `commit_frame=30`, `emit_window=30..50`, and `fire_total_frames=75`. The player sees 30 frames of wind-up before the first shot.

### D.6 Security Bot Burst Shot Frames

The secbot_burst_shot_frame formula is defined as:

`shot_frame(i) = wind_up_frames + i * burst_interval_frames`

`should_emit_shot_i = state_frame == shot_frame(i)`

for `i ∈ [0, burst_count - 1]`.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| i | `i` | int | `0..burst_count-1` | Zero-based shot index in the burst. |
| wind_up_frames | `W_fire` | int | `18..60` | Shared with D.5. Security Bot default `30`. |
| burst_interval_frames | `I_burst` | int | `6..18` | Frames between shots. Security Bot default `10`. |
| burst_count | `N_burst` | int | `2..4` | Shots per burst. Tier 1 default `3`. |
| state_frame | `F_local` | int | `0..fire_total_frames` | Frame since entering `FIRE`. |
| shot_frame(i) | `F_shot_i` | int | `W_fire..W_fire+(N_burst-1)*I_burst` | Exact frame for shot `i`. |
| should_emit_shot_i | `G_shot_i` | bool | `true/false` | Whether shot `i` emits on this frame. |

**Output Range:** Shot frames are strictly increasing when `burst_interval_frames > 0`.
**Example:** With `wind_up_frames=30`, `burst_interval_frames=10`, and `burst_count=3`, the three shots emit at state frames `30`, `40`, and `50`.

This formula is the anti-stationary AimLock pressure baseline: freezing through the full wind-up and burst exposes the player to three predictable shots, while moving through the learned gap remains fair.

### D.7 Projectile Direction Selection

The projectile_direction formula is defined as:

`raw_aim = (target_snapshot_position - muzzle_position).normalized()`

`projectile_direction = argmax(allowed_lane in allowed_lanes, dot(raw_aim, allowed_lane))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| target_snapshot_position | `P_target` | Vector2 | world coordinates | Player position cached when the attack commits. Does not retarget during the same attack. |
| muzzle_position | `P_muzzle` | Vector2 | world coordinates | Enemy projectile spawn point. |
| raw_aim | `V_raw` | Vector2 | unit vector | Direction from muzzle to cached player position. |
| allowed_lanes | `L` | Array[Vector2] | 1..8 lanes | Authored unit vectors allowed for the archetype. Drone default: 5 downward/diagonal lanes. Security Bot default: horizontal lane plus slight diagonals. |
| projectile_direction | `V_dir` | Vector2 | unit vector from `allowed_lanes` | Final deterministic projectile direction. |

**Output Range:** One unit vector from `allowed_lanes`. No interpolated or random direction is produced.
**Example:** If `raw_aim=(0.78, 0.62)` and Security Bot lanes are `(1,0)`, `(0.894,0.447)`, `(0.707,0.707)`, the max dot product selects `(0.707,0.707)` if that lane has the highest alignment.

Lane snapping keeps projectiles readable and repeatable. It also prevents tiny floating-point differences in player position from creating visually surprising aim changes.

### D.8 Enemy Projectile Velocity

The enemy_projectile_velocity formula is defined as:

`enemy_projectile_velocity = projectile_direction * projectile_speed_px_s`

`projectile_step_delta = enemy_projectile_velocity / physics_fps`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| projectile_direction | `V_dir` | Vector2 | unit vector | Output of D.7. |
| projectile_speed_px_s | `S_proj` | float | `240..480 px/s` | Enemy projectile speed. Drone default `300`; Security Bot default `360`. |
| physics_fps | `FPS` | int | `60` Tier 1 | Godot physics tick rate. |
| enemy_projectile_velocity | `V_proj` | Vector2 | `240..480 px/s` magnitude | Script-stepped projectile velocity. |
| projectile_step_delta | `D_step` | Vector2 | `4..8 px/frame` magnitude | Per-frame movement delta at 60 Hz. |

**Output Range:** Projectile speed magnitude stays `240..480 px/s`; per-frame step stays `4..8 px/frame` at 60 Hz.
**Example:** A Security Bot projectile with `projectile_direction=(1,0)` and `projectile_speed_px_s=360` yields `enemy_projectile_velocity=(360,0)` and `projectile_step_delta=(6,0)` per physics frame.

Enemy projectiles are slower than ECHO's Tier 1 projectile default (`600 px/s` in player-shooting.md), preserving readability and dodge timing.

### D.9 Enemy AI Area2D Budget

The enemy_ai_area2d_budget formula is defined as:

`enemy_ai_area2d_count = active_standard_enemy_count + active_enemy_projectile_count + active_boss_enemy_ai_projectile_count`

`damage_area2d_safe = enemy_ai_area2d_count + non_enemy_damage_area2d_count <= area2d_max_active`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| active_standard_enemy_count | `N_enemy` | int | `0..30` | Active Drone + Security Bot HurtBoxes. State-machine.md performance note allows up to 30 enemy SMs. |
| active_enemy_projectile_count | `N_eproj` | int | `0..24` Tier 1 recommended | Active Drone + Security Bot projectiles. |
| active_boss_enemy_ai_projectile_count | `N_bproj` | int | `0..16` placeholder | STRIDER-hosted boss projectile count; Boss Pattern #11 owns final cap. |
| non_enemy_damage_area2d_count | `N_other` | int | `0..80` | ECHO HurtBox, ECHO projectiles, hazards, pickups, boss hurtboxes, and other Damage-owned Area2Ds. |
| area2d_max_active | `N_area_max` | int | `80` Tier 1 | Damage #8 G.1 `area2d_max_active` ceiling. |
| damage_area2d_safe | `G_area` | bool | `true/false` | Whether total active Area2D count remains within Damage #8's Tier 1 ceiling. |

**Output Range:** `enemy_ai_area2d_count` is `0..70` under listed ranges, but Tier 1 encounter authoring should keep standard enemy contribution `N_enemy + N_eproj <= 54` so ECHO, hazards, and boss/stage components retain budget headroom.
**Example:** `N_enemy=8`, `N_eproj=12`, `N_bproj=0`, `N_other=20` gives `enemy_ai_area2d_count=20` and total Area2D count `40`, so `damage_area2d_safe=true` under the `80` ceiling.

This budget is not an enemy culling rule. It is an encounter authoring constraint and test fixture bound; enemy AI itself must not pause decisions based on visibility or budget pressure.

---

## E. Edge Cases

Each edge case below names the exact condition and the required resolution. The guiding principles are: deterministic order first, Damage #8 owns hit outcomes, Stage #12 owns spawn/activation, and Enemy AI must not create hidden behavior changes during player-only rewind.

### E.1 Missing spawn metadata

- **If `spawn_physics_frame < 0`, `spawn_id < 0`, or `ai_seed` is unset when the enemy attempts to leave `IDLE`**: keep the enemy in `IDLE`, set `velocity = Vector2.ZERO`, disable attack emission, and `push_error("EnemyBase spawn metadata missing")` in debug builds. Do not synthesize a seed from wall-clock time or scene-tree index.

### E.2 Negative frame offsets

- **If `current_physics_frame < spawn_physics_frame` or `current_physics_frame < current_state_entered_frame`**: treat the enemy as invalid for this tick, emit no projectile, perform no transition except optional fail-safe return to `IDLE`, and `push_error("EnemyBase negative frame offset")` in debug builds. Negative frame math must never wrap through `mod` and create a fake valid patrol/attack frame.

### E.3 `variant_count <= 0`

- **If an archetype is configured with `variant_count <= 0`**: fail fast in `_ready()` / spawn validation with `push_error("EnemyBase variant_count must be >= 1")`, clamp runtime behavior to variant `0`, and emit no RNG calls. This protects D.2 from divide-by-zero and preserves deterministic fallback.

### E.4 Patrol anchors missing or identical

- **If either patrol anchor is missing**: keep the enemy in `IDLE` and fail fast in debug builds. Stage/Encounter owns anchors; Enemy AI must not infer anchors from current position or nearby nodes.
- **If `patrol_anchor_a == patrol_anchor_b`**: allow the enemy to operate as a stationary enemy at that point. `PATROL` velocity remains zero, but `SPOT` and `FIRE` still work. This is valid for turret-like staging and test fixtures.

### E.5 Player reference missing

- **If `target_player == null` during `PATROL`, `SPOT`, or `FIRE`**: transition to `IDLE`, hold velocity at zero, emit no projectile, and `push_error("EnemyBase target_player missing")` in debug builds. Do not discover ECHO through `get_tree().get_first_node_in_group()` as an implicit fallback; Stage/Encounter must inject the reference.

### E.6 Player exits detection during wind-up

- **If ECHO exits `spot_gate` while the enemy is still in `SPOT` before `spot_confirm_frames` completes**: transition back to `PATROL` and clear `target_snapshot_position`.
- **If ECHO exits `spot_gate` after the enemy has entered `FIRE`**: do not cancel the attack. The attack has committed; continue the telegraph/emission/recovery timeline using the cached `target_snapshot_position`. This prevents last-frame movement from erasing a visible attack and keeps the rule learnable.

### E.7 Player crosses behind Security Bot at the exact spot boundary

- **If `allow_back_detection == false` and ECHO crosses from front to back on the same frame `SPOT` would begin**: evaluate `spot_gate` once using priority-10 positions and the current `facing_direction`. If the sign check fails, remain in `PATROL`. Do not flip and spot in the same frame. The earliest possible spot is the next physics tick after patrol-facing has updated.

### E.8 ECHO rewinds while enemy is in `SPOT` or `FIRE`

- **If Time Rewind restores ECHO while an enemy is in `SPOT`**: Enemy AI receives no rewind signal in Tier 1 and continues its state-frame counter. On the next priority-10 tick it reads the restored `target_player.global_position`; if `spot_gate` fails before confirm, it returns to `PATROL` per E.6.
- **If Time Rewind restores ECHO while an enemy is already in `FIRE`**: the enemy continues the committed attack timeline and does not retarget inside that attack. ECHO's REWINDING i-frame is handled solely by State Machine + Damage through `HurtBox.monitorable=false`. Enemy AI must not special-case invulnerability.

### E.9 Enemy projectile overlaps ECHO during REWINDING i-frames

- **If an enemy projectile HitBox overlaps ECHO while ECHO HurtBox.monitorable is false**: Damage #8's Area2D predicate blocks `area_entered` and no enemy-side recovery, retarget, or compensation occurs. The projectile continues or expires according to projectile lifetime rules; Enemy AI does not know the hit was blocked.

### E.10 Standard enemy hit on the same frame it emits a projectile

- **If an ECHO projectile hits a standard enemy on the same state frame that the enemy's `FIRE` substage would emit**: Damage/HitBox signal processing and `_physics_process` order determine the exact sequence, but the enemy death latch wins for future behavior. If `DEAD` is entered before projectile emission code runs, the enemy emits no projectile. If projectile emission already occurred earlier in the same tick, the projectile remains valid and continues normally. In both cases `enemy_killed` emits exactly once.

### E.11 Multiple ECHO projectiles hit the same enemy in one tick

- **If two or more ECHO projectiles overlap the same standard enemy HurtBox in the same physics tick**: the first valid hit by deterministic scene-tree/projectile order causes `DEAD`, emits one `enemy_killed`, disables HurtBox monitoring, and queues cleanup. Later overlaps must not emit additional `enemy_killed` signals or resurrect/extend the enemy. Extra ECHO projectiles may still consume their own projectile lifecycle normally.

### E.12 Multiple enemies die in one tick

- **If enemies A, B, and C die in the same physics tick**: `enemy_killed` / `enemy_died` order follows deterministic scene-tree order, which Stage/Encounter must create by `(spawn_physics_frame, spawn_id)` insertion. Audio, VFX, and stats consumers must receive the same order. Enemy AI must not sort by distance, screen position, or dictionary key at death time.

### E.13 Projectile pool exhausted

- **If the enemy projectile pool/cap is exhausted when an enemy reaches an emission frame**: skip that projectile emission, record a debug-only skipped-emission counter, and continue the `FIRE` timeline. Do not extend wind-up, retry on the next frame, or spawn a slower substitute projectile. Retrying would alter the learned burst cadence and break Pillar 2.

### E.14 Area2D budget exceeds Damage #8 ceiling

- **If an encounter configuration would make `damage_area2d_safe == false` from D.9**: this is a Stage/Encounter authoring error, not an Enemy AI runtime branch. In debug/test fixtures, fail the encounter validation before play begins. During runtime, Enemy AI must not silently deactivate enemies or pause projectile emission based on the budget check because doing so would create hidden culling-dependent behavior.

### E.15 Scene transition during enemy attack

- **If Scene Manager emits `scene_will_change` while enemies or enemy projectiles are active**: Stage/Scene cleanup owns freeing or pooling those nodes. Enemy AI does not emit death, kill, or attack-cancel signals during scene teardown. Any in-flight enemy attack becomes a non-event after the scene root is removed.

### E.16 Enemy dies during scene transition

- **If an enemy HurtBox receives a valid ECHO projectile hit in the same tick as `scene_will_change`**: Scene Manager teardown wins as the lifecycle boundary. If the enemy has already entered `DEAD`, the single `enemy_killed` emission may complete; if teardown happens before the HurtBox event reaches enemy code, no kill signal is required. Stage/Encounter and score/stat systems must not rely on same-boundary kills. Tier 1 has no scoring system, so this is intentionally low-risk.

### E.17 Security Bot burst would fire after death

- **If Security Bot enters `DEAD` after shot 1 or shot 2 of a three-shot burst**: remaining burst shots are canceled. Already spawned projectiles remain valid. This preserves one-hit standard enemy clarity and avoids a dead enemy emitting invisible delayed shots.

### E.18 Detection at exact range boundary

- **If `abs(dx) == detect_range_x` or `abs(dy) == detect_range_y` exactly**: treat the target as inside the detection rectangle (`<=`, not `<`). This makes boundary behavior deterministic and testable. If flicker becomes visible in playtest, add hysteresis as a future formula; do not switch to analog timers.

### E.19 Lane selection tie in projectile direction

- **If two `allowed_lanes` have the same dot product against `raw_aim`**: select the lane with the lowest array index. The authored lane array order is therefore part of the deterministic contract and must be stable. Do not choose randomly between tied lanes.

### E.20 Zero-length aim vector

- **If `target_snapshot_position == muzzle_position` when D.7 computes `raw_aim`**: use the enemy's current facing lane as `projectile_direction`. If the archetype has no facing lane in `allowed_lanes`, use `allowed_lanes[0]`. Do not normalize a zero vector and do not skip the attack after a completed telegraph.

### E.21 STRIDER phase logic requests unsupported EnemyBase behavior

- **If Boss Pattern #11 needs STRIDER behavior that cannot be expressed by EnemyBase + StateMachine without forking**: stop the implementation path and classify the need as either (a) EnemyBase generalization, (b) Boss Pattern simplification, or (c) Tier 2 feature pull-forward. Do not create a STRIDER-only hidden physics clock, RigidBody2D branch, or parallel state-machine fork.

### E.22 Enemy path blocked by static level geometry

- **If Security Bot's `move_and_slide()` is blocked before reaching its patrol anchor**: reverse facing and continue the patrol cycle from the current position on the next tick. Do not invoke pathfinding or teleport to the anchor. Stage/Encounter should author patrol anchors on valid ground lanes; collision blockage is a stage layout issue.

### E.23 Enemy outside camera view

- **If an enemy is outside the current camera viewport but still inside the active encounter**: continue AI ticks normally. Enemy AI may suppress presentation-only animation updates if the renderer supports it, but state counters, patrol position, telegraphs, and projectile schedules continue unchanged. Visibility must not change gameplay behavior.

### E.24 Deprecated generic cause label appears

- **If a fixture or legacy enemy projectile uses `&"projectile_enemy"` instead of subtype causes**: Damage may still process it as a non-hazard enemy projectile for compatibility, but new Enemy AI content must treat this as a debug warning and replace it with `&"projectile_enemy_drone"` or `&"projectile_enemy_secbot"`. Tier 1 authored content must not ship with the generic label.

---

## F. Dependencies

Enemy AI #10 is a Feature-layer system with three hard upstream dependencies already listed in `systems-index.md`: State Machine #5, Damage #8, and Player Movement #6. It also has architecture-level constraints from ADR-0001 and ADR-0003, provisional spawn data from Stage/Encounter #12, and downstream consumers in Boss Pattern #11, Stage/Encounter #12, Audio #4, Camera #3, and future VFX #14.

### F.1 Upstream Dependencies Consumed by Enemy AI

| # | System / Source | Type | Hardness | Enemy AI consumes | Contract Status | Forbidden Coupling |
|---|---|---|---|---|---|---|
| **#5** | [State Machine Framework](state-machine.md) | System | **Hard** | `State` / `StateMachine`, synchronous `transition_to(...)`, host-owned priority-10 tick context, `last_transition_frame` observability | Approved; reciprocal row exists in state-machine.md F.2 and is updated to A-H + V/A | Forking StateMachine for enemies; HSM assumptions in Tier 1; transition triggers from `_process`, `Timer`, animation-finished, or deferred callbacks |
| **#8** | [Damage / Hit Detection](damage.md) | System | **Hard** | Enemy HurtBox L3, enemy projectile HitBox L4, one-hit standard enemy kill flow, subtype cause taxonomy, `enemy_killed(enemy_id, cause)` signal | LOCKED for prototype; reciprocal F.1 row exists and C.5.2/D.3.1/D.3.2 were mirrored for subtype causes on 2026-05-13 | Enemy deciding ECHO death directly; enemy HP for standard enemies; generic `projectile_enemy` in authored Tier 1 content |
| **#6** | [Player Movement](player-movement.md) | System | **Hard read-only** | `target_player.global_position` during priority-10 physics tick | Approved; reciprocal row exists in player-movement.md F.4.1 | Calling PM methods; mutating player state; subscribing to PM signals; reading ammo/input/SM internals |
| **ADR-0003** | [Determinism Strategy](../../docs/architecture/adr-0003-determinism-strategy.md) | Architecture | **Hard** | `EnemyBase extends CharacterBody2D`, `compute_ai_velocity(frame_offset)`, `process_physics_priority=10`, seeded/no-global-RNG rule, projectile priority 20 | Accepted; Enemy AI implements the declared #10 requirement | `RigidBody2D` gameplay enemies; global RNG; wall-clock AI; unspecified spawn order |
| **ADR-0001** | [Time Rewind Scope](../../docs/architecture/adr-0001-time-rewind-scope.md) | Architecture | **Hard negative dependency** | Player-only rewind boundary: enemies are not snapshot-restored and do not subscribe to rewind lifecycle in Tier 1 | Accepted; Section C/E encode no Tier 1 rewind subscription | Hidden `on_player_rewind` retarget/reset behavior; enemy/projectile snapshot ring buffers |
| **#12** | [Stage / Encounter System](stage-encounter.md) | System | **Hard for real encounters** | `spawn_id`, `ai_seed`, `spawn_physics_frame`, activation bounds, patrol anchors, target reference, deterministic insertion order | Approved 2026-05-13; mirrors this contract | Enemy self-spawning; implicit group lookup for player/anchors; runtime random spawn choice |
| **#7** | [Player Shooting / Weapon System](player-shooting.md) | System | **Indirect** | ECHO projectile HitBox L2 can hit enemy HurtBox L3 through Damage #8 | Approved; no direct method/signal dependency | Enemy reading ECHO ammo, fire cooldown, weapon ID, or projectile internals |

### F.2 Downstream Systems Depending on Enemy AI

| # | System | Dependency | What Enemy AI provides | Current Status | Notes / Obligation |
|---|---|---|---|---|---|
| **#11** | [Boss Pattern System](boss-pattern.md) | **Hard** | STRIDER inherits EnemyBase deterministic host contract; boss phases reuse EnemyBase priority 10, target read pattern, and Damage integration | Approved 2026-05-13 | Boss Pattern #11 owns phase scripts, `phase_hp_table=[3,4,5]`, boss projectile patterns/cap, and token reward timing. It must not fork EnemyBase or introduce RigidBody2D boss logic. |
| **#12** | [Stage / Encounter System](stage-encounter.md) | **Hard** | Spawn metadata contract, patrol anchor contract, encounter Area2D budget constraints, deterministic insertion order `(spawn_physics_frame, spawn_id)` | Approved 2026-05-13 | Stage #12 mirrors F.1/F.2 by providing spawn data to Enemy AI and consuming Enemy AI archetypes for room composition. |
| **#4** | [Audio System](audio.md) | **Soft presentation** | `enemy_spotted_player`, `enemy_attack_committed`, `enemy_died`; Damage-side `enemy_killed` remains kill signal of record | Approved | Audio may subscribe for telegraph/attack/death cues, but Enemy AI never controls buses or ducking. Per-cause enemy projectile SFX mapping remains a future Audio mapping update. |
| **#3** | [Camera System](camera.md) | **Soft presentation** | Combat events may indirectly drive camera feedback through Damage/Boss signals; Enemy AI itself emits no camera commands | Approved | Camera must not subscribe to Enemy AI for gameplay. Enemy AI must not call camera shake directly. |
| **#14** | [VFX / Particle System](vfx-particle.md) | **Soft presentation** | Enemy state/event hooks, subtype projectile causes, silhouette/telegraph event timing | Approved 2026-05-13 | VFX owns impact, telegraph, near-miss, death burst, and cause-specific visual signatures. Enemy AI provides timing hooks only. |
| **#16** | Time Rewind Visual Shader | **Soft visual constraint** | During rewind color inversion, enemy silhouette identity must remain readable | Not Started | Shader/VFX must preserve enemy-vs-ECHO readability; Enemy AI only supplies consistent silhouettes/state hooks. |
| **#13** | HUD System | **No direct Tier 1 dependency** | None in Tier 1 | Approved 2026-05-13 | HUD may display boss-phase or token information via Damage/Boss/Time Rewind, not Enemy AI. Standard enemy indicators are out of scope. |

### F.3 Enemy AI-Owned Signal Catalog

These are the only signals owned by Enemy AI #10. They are for presentation/debug consumers and must not become gameplay authority over ECHO, Damage, or Time Rewind.

| Signal | Signature | Fire Condition | Allowed Consumers | Forbidden Consumers / Uses |
|---|---|---|---|---|
| `enemy_spotted_player` | `(enemy_id: StringName, archetype_id: StringName)` | Enemy enters `SPOT` | Audio #4, VFX #14, debug HUD | Player Movement, Time Rewind, Damage lethal flow |
| `enemy_attack_committed` | `(enemy_id: StringName, archetype_id: StringName, cause: StringName)` | `FIRE` reaches commit frame before projectile spawn | Audio #4, VFX #14, debug trace | Camera direct shake, token logic, player state mutation |
| `enemy_projectile_spawned` | `(enemy_id: StringName, projectile: Node2D, cause: StringName)` | Enemy projectile instance is created | Debug tests, VFX #14 if needed | Damage hit authority replacement; projectile steering after spawn |
| `enemy_died` | `(enemy_id: StringName, archetype_id: StringName)` | Enemy enters `DEAD` | Audio #4, VFX #14, debug trace | Score/stat authority if future systems require exact kill cause; use Damage `enemy_killed` instead |

Damage #8 remains the source of record for `enemy_killed(enemy_id, cause)`. Enemy AI must not emit `player_hit_lethal`, `lethal_hit_detected`, `death_committed`, `boss_phase_advanced`, `boss_killed`, `rewind_started`, or `rewind_completed`.

### F.4 Data Interfaces

| Data | Owner | Reader | Mutability | Notes |
|---|---|---|---|---|
| `spawn_id` | Stage #12 | Enemy AI | Immutable after spawn | Used for deterministic variant selection and child insertion order. |
| `ai_seed` / `encounter_seed` | Stage #12 | Enemy AI | Immutable after spawn | No global RNG fallback. |
| `spawn_physics_frame` | Stage #12 or test fixture | Enemy AI | Immutable after activation | D.1 lifetime clock source. |
| `current_state_entered_frame` | EnemySM | Enemy AI states/tests | Mutates only on state transition | D.1 state-local clock source. |
| `target_player.global_position` | Player Movement #6 | Enemy AI | Read-only | Read during priority-10 tick only. |
| `patrol_anchor_a/b` | Stage #12 | Enemy AI | Immutable during active encounter | Missing anchors keep enemy in `IDLE`; identical anchors are allowed stationary behavior. |
| `HitBox.cause` | Enemy AI host at projectile instantiation, taxonomy owned by Damage #8 | Damage #8, Audio/VFX downstream | Immutable per projectile | Drone = `projectile_enemy_drone`; Security Bot = `projectile_enemy_secbot`; STRIDER/Boss = `projectile_boss`. |
| `process_physics_priority` | ADR-0003 / EnemyBase | Godot scheduler | Constant | Enemies = 10; projectiles = 20. |

### F.5 Dependency Hardness Summary

| Hardness | Dependencies | Meaning |
|---|---|---|
| **Hard runtime** | State Machine #5, Damage #8, Player Movement #6, ADR-0003 | Enemy AI cannot function correctly without these contracts. |
| **Hard authoring / integration** | Stage #12, Boss Pattern #11 | Enemy AI can be unit-tested without them, but real encounters/bosses require their authored contracts. |
| **Soft presentation** | Audio #4, Camera #3, VFX #14, Rewind Shader #16 | Missing presentation consumers do not block logic; they reduce readability/juice and must be completed before final prototype polish. |
| **Negative dependency** | Time Rewind #9 runtime signals, Player Shooting internals, HUD #13 | Enemy AI intentionally does not depend on these directly in Tier 1. |

### F.6 Bidirectional Mirror Status

| Source / Target | Mirror Status | Required Follow-up |
|---|---|---|
| `systems-index.md` | Current row lists State Machine, Damage, Player Movement as Depends On | Keep concise row; do not expand to every soft presentation consumer. |
| `state-machine.md` | Reciprocal row exists and was refreshed to Designed/pending re-review on 2026-05-13 | Re-check after Enemy AI review approval. |
| `damage.md` | Reciprocal host row exists; subtype causes mirrored on 2026-05-13 | Later VFX/Audio per-cause mapping updates remain outside Damage. |
| `player-movement.md` | Reciprocal row exists: enemies/bosses read PM `global_position` only | No immediate update required. |
| `player-shooting.md` | Indirect Damage-mediated relationship already documented; no direct Enemy AI dependency | No immediate update required. |
| `time-rewind.md` / ADR-0001 | Player-only rewind scope documented; Enemy AI uses negative dependency | Any future `on_player_rewind` behavior requires explicit design review/ADR amendment check. |
| `audio.md` | Audio is approved but does not yet map Enemy AI presentation signals or subtype causes | Add when Audio/VFX polish pass consumes enemy telegraph/death cues. |
| `camera.md` | Camera should remain Damage/Boss-driven, not Enemy AI-driven | No immediate update required. |
| `stage-encounter.md` | Approved 2026-05-13; mirrors spawn metadata, patrol anchors, activation bounds, Area2D preflight, and deterministic insertion order | Re-check only if future Stage revisions change spawn schema or Area2D budget ownership. |
| Boss #11 | Approved 2026-05-13 | Re-check only if future Boss Pattern revisions change STRIDER host boundaries. |
| VFX #14 / Shader #16 | VFX #14 Approved 2026-05-13; Shader #16 not started | VFX mirrors Enemy AI hooks and subtype causes; Shader #16 must still preserve enemy-vs-ECHO readability when authored. |

### F.7 Integration Order

Recommended implementation/design order after this GDD:

1. Re-review Enemy AI #10 after the 2026-05-13 Area2D budget contract fix.
2. Review Stage/Encounter #12 to validate spawn metadata, patrol anchors, activation bounds, and deterministic insertion order.
3. Implement one standard archetype first (Security Bot preferred, because it validates anti-stationary AimLock pressure).
4. Verify State Machine #5 three-machine reuse target with `EnemySM`.
5. Re-check `boss-pattern.md` after Boss Pattern #11 design review if STRIDER host findings change EnemyBase constraints.
6. Add Audio/VFX per-cause presentation mappings after logic determinism passes.

---

## G. Tuning Knobs

Enemy AI tuning knobs are designer-authored values on archetype configuration resources or exported scene fields. They may be changed between test runs, encounters, or authored variants, but they must not be mutated mid-encounter by hidden runtime logic. Runtime state may only read the configured values and derive deterministic frame outcomes from them.

All frame values assume the ADR-0003 Tier 1 physics target of 60 Hz. Values are expressed in frames unless the unit is explicitly listed as pixels or pixels-per-second.

### G.1 Authoring Knob Table

| Knob | Type / Unit | Drone Default | Security Bot Default | Safe Range | Formula / Rule | Too Low | Too High |
|---|---:|---:|---:|---:|---|---|---|
| `variant_count` | int | 1 | 1 | 1-8 | D.2 | No authored variety; acceptable for first slice | Too many variants to verify deterministically |
| `patrol_period_frames` | int frames | 180 | 240 | 60-300 | D.3 | Enemy appears twitchy and hard to read | Enemy becomes background decoration |
| `detect_range_x` | float px | 320 | 360 | 96-480 | D.4 | Enemy fails to teach before contact | Enemy fires from off-screen or outside readable range |
| `detect_range_y` | float px | 180 | 96 | 48-240 | D.4 | Vertical reads feel arbitrary or missed | Drone/bot threatens too many lanes at once |
| `allow_back_detection` | bool | true | false | archetype-authored | D.4 / C.5 | If false for Drone, aerial threat becomes too easy to bypass | If true for Security Bot, facing telegraph loses meaning |
| `spot_confirm_frames` | int frames | 12 | 12 | 6-30 | C.3 / C.4 | Enemy snaps into attack before the player can read intent | Enemy feels asleep after clearly seeing ECHO |
| `wind_up_frames` | int frames | 24 | 30 | 18-60 | D.5 | Lethal output violates readability | Encounter pace stalls and AimLock dominance rises |
| `emit_duration_frames` | int frames | 1 | 21 | 1-36 | D.5 / D.6 | Burst shots may not fit in the emit window | Enemy occupies too much combat time with one attack |
| `recovery_frames` | int frames | 24 | 24 | 12-60 | D.5 | No punish window after surviving attack | Enemy becomes passive after every shot |
| `burst_count` | int shots | 1 | 3 | Drone: 1; Security Bot: 2-4 | D.6 | Security Bot fails its anti-stationary role | Cognitive load exceeds Tier 1 read budget |
| `burst_interval_frames` | int frames | N/A | 10 | 6-18 | D.6 | Burst becomes a near-instant wall | Gap is too large to pressure stationary AimLock |
| `projectile_speed_px_s` | float px/s | 300 | 360 | 240-480 | D.8 | Projectile is decorative and easy to ignore | Reaction window becomes unfair without longer wind-up |
| `allowed_lanes` | ordered `Array[Vector2]` | 5 authored aerial lanes | 3 authored ground lanes | 1-8 normalized vectors | D.7 | Enemy cannot express its role or has no valid shot | Lane set becomes visually noisy and hard to learn |
| `active_standard_enemy_count_cap` | int entities | encounter-authored | encounter-authored | 1-30 | D.9 / State Machine AC-25 | Encounter cannot combine reads | State-machine and attention budgets are exceeded |
| `active_enemy_projectile_count_cap` | int Area2D | shared 24 | shared 24 | 8-32, recommended 24 | D.9 | Shots silently fail too often | Damage #8 Area2D ceiling is threatened |
| `cleanup_frames` | int frames | 6 | 6 | 0-30 | C.3 / E.16 | Death VFX may pop instantly | Dead enemies block space or delay pool return |
| `debug_draw_ai_state` | bool | false | false | debug-only | C.9 | No visual diagnostics in tests | If shipped on, collage readability and performance suffer |

### G.2 Locked Constants, Not Tuning Knobs

The following values protect cross-system contracts and must not be exposed as ordinary encounter tuning:

- `process_physics_priority = 10` for enemy hosts and `20` for enemy projectiles (ADR-0003).
- `EnemyBase extends CharacterBody2D`; enemy projectiles remain script-stepped `Area2D` nodes.
- `spawn_id`, `spawn_physics_frame`, and `ai_seed` are Stage/Encounter-provided identity data, not balance dials.
- Standard Drone and Security Bot enemies remain one-hit enemies under Damage #8 DEC-3.
- Projectile cause labels are fixed per archetype: `&"projectile_enemy_drone"`, `&"projectile_enemy_secbot"`, and `&"projectile_boss"`.
- Enemy AI does not subscribe to Time Rewind events in Tier 1.
- Damage #8 owns the global `area2d_max_active = 80` ceiling; Enemy AI only budgets within it.
- Player Movement data is read-only. Tuning cannot add enemy-owned player mutations, slows, forced movement, or state changes.

### G.3 Cross-Knob Invariants

1. **Readable-output invariant**: `wind_up_frames >= 18` for all lethal output. If `projectile_speed_px_s > 360`, the archetype should use `wind_up_frames >= 24` unless a playtest review explicitly approves otherwise.
2. **Burst-fit invariant**: for Security Bot, `emit_duration_frames >= ((burst_count - 1) * burst_interval_frames) + 1`. If this is false, validation fails before runtime.
3. **Attack-loop invariant**: `fire_total_frames = wind_up_frames + emit_duration_frames + recovery_frames` should stay at or below 156 frames for standard enemies. Longer loops are boss-pattern territory, not standard-enemy tuning.
4. **Punish-window invariant**: `recovery_frames >= 12` so a player who survives the pattern has a reliable response window.
5. **Area2D invariant**: `active_enemy_projectile_count_cap + active_boss_projectile_placeholder + other_combat_area2d <= Damage.area2d_max_active`. Enemy AI recommended Tier 1 contribution is 24 standard enemy projectiles plus up to 30 standard enemy bodies.
6. **Lane-order invariant**: `allowed_lanes` order is part of the deterministic contract. Reordering lanes changes tie-break outcomes in D.7 and must be treated as a balance change.
7. **Variant-freeze invariant**: `variant_count` and selected variant data are resolved at spawn initialization only. They cannot change after activation or after a player rewind.

### G.4 Tier 1 Presets

| Preset | Primary Use | Key Values | Expected Player Read |
|---|---|---|---|
| **Drone / Intro Aerial** | First vertical-lane lesson | `patrol_period_frames=180`, `detect_range_x=320`, `detect_range_y=180`, `allow_back_detection=true`, `wind_up_frames=24`, `projectile_speed_px_s=300` | Notice the aerial silhouette, dodge one committed shot, punish during recovery. |
| **Security Bot / Intro Burst** | First anti-stationary AimLock lesson | `patrol_period_frames=240`, `detect_range_x=360`, `detect_range_y=96`, `allow_back_detection=false`, `wind_up_frames=30`, `burst_count=3`, `burst_interval_frames=10`, `projectile_speed_px_s=360` | Count the three-shot burst, move through the gap, shoot during recovery. |
| **STRIDER / EnemyBase Host** | Boss Pattern #11 host only | `process_physics_priority=10`, deterministic `spawn_id`, `ai_seed`, `spawn_physics_frame`; boss projectile tuning delegated to Boss Pattern | Trust that the mini-boss obeys the same clock and telegraph grammar as standard enemies. |

### G.5 Playtest Tuning Priority

When a playtest flags Enemy AI difficulty, tune in this order:

1. **Telegraph clarity first**: adjust `wind_up_frames`, visual pose timing, and aim-line readability before changing damage or enemy counts.
2. **Cadence second**: adjust Security Bot `burst_interval_frames`, `emit_duration_frames`, and `recovery_frames` to preserve the countable burst lesson.
3. **Projectile speed third**: adjust `projectile_speed_px_s` only after telegraph and cadence are readable. Faster shots require stronger anticipation.
4. **Detection fourth**: adjust `detect_range_x`, `detect_range_y`, and `allow_back_detection` to prevent off-screen or behind-the-back unfairness.
5. **Encounter density last**: adjust active enemy/projectile caps only after single-enemy reads are fair. Density tuning belongs jointly to Stage/Encounter #12 and Enemy AI #10.

Do not solve Enemy AI difficulty by adding random misses, hidden HP, untelegraphed delay jitter, or player-state mutations. Those changes violate the Player Fantasy and Pillar 2 contract.

---

## H. Acceptance Criteria

Acceptance criteria are written as independently verifiable Given-When-Then tests. Logic criteria should be covered by GUT or equivalent Godot headless integration tests unless the Verification Type column explicitly calls for a playtest or hardware profile.

### H.1 Core Rule Acceptance

| ID | Criterion | Verification Type | Covers |
|---|---|---|---|
| **AC-EAI-01** | **GIVEN** a Tier 1 Drone or Security Bot scene is instantiated, **WHEN** QA inspects the root node and exported fields, **THEN** the root is `EnemyBase extends CharacterBody2D`, has `entity_id`, `archetype_id`, `ai_seed`, `spawn_id`, `spawn_physics_frame`, `enemy_sm`, `target_player`, and `process_physics_priority == 10`. | Logic / scene inspection | C.1 Rule 1 |
| **AC-EAI-02** | **GIVEN** an enemy runs for 300 physics frames with fixed spawn metadata, **WHEN** the run is repeated with the same inputs, **THEN** `frame_offset`, `state_frame`, state names, positions, and projectile spawn frames are identical across both runs, with no calls to wall-clock timers, global RNG, `_process(delta)` gameplay timers, or animation-finished gameplay transitions. | Logic / determinism test + forbidden-pattern scan | C.1 Rule 2 |
| **AC-EAI-03** | **GIVEN** ECHO starts Time Rewind while an enemy is in `SPOT` or `FIRE`, **WHEN** the rewind lifecycle completes, **THEN** the enemy has not restored from a `PlayerSnapshot`, has not subscribed to `rewind_started` / `rewind_completed`, and continues only through its authored frame-clock state logic. | Integration | C.1 Rule 3 / E.8 |
| **AC-EAI-04** | **GIVEN** any enemy attack can produce lethal output, **WHEN** the attack is triggered, **THEN** at least `wind_up_frames` of visible telegraph occur before a projectile, contact hitbox, leap, laser, burst, or boss-hosted attack can damage ECHO. | Logic + visual review | C.1 Rule 4 / D.5 |
| **AC-EAI-05** | **GIVEN** a standard Drone or Security Bot has an active HurtBox, **WHEN** one valid ECHO projectile hit is processed by Damage #8, **THEN** the enemy enters `DEAD`, disables gameplay collision/HurtBox monitoring behavior as specified, emits one death path, and requires no second hit. | Integration | C.1 Rule 5 / Damage DEC-3 |
| **AC-EAI-06** | **GIVEN** STRIDER is instantiated for a boss encounter, **WHEN** QA inspects its base host contract, **THEN** it inherits EnemyBase determinism, priority, target-read, and Damage integration while phase scripts, thresholds, boss projectile patterns, and token rewards are absent from Enemy AI and delegated to Boss Pattern #11. | Integration / architecture review | C.1 Rule 6 |
| **AC-EAI-07** | **GIVEN** an enemy detects ECHO, **WHEN** Enemy AI reads player data during its priority-10 physics tick, **THEN** the only Player Movement data read is `target_player.global_position`, and Enemy AI performs no player method calls, signal subscriptions, state mutations, or token operations. | Logic / code scan + spy test | C.1 Rule 7 |
| **AC-EAI-08** | **GIVEN** a standard enemy projectile is spawned, **WHEN** QA inspects and steps the projectile, **THEN** it is an `Area2D` script-stepped projectile with `process_physics_priority == 20`, L4 HitBox masking ECHO HurtBox L1 only, and no friendly-fire overlap against enemy HurtBoxes. | Logic / collision-layer test | C.1 Rule 8 |
| **AC-EAI-09** | **GIVEN** Drone, Security Bot, and STRIDER/boss projectiles are spawned, **WHEN** Damage receives their HitBox causes, **THEN** the causes are exactly `&"projectile_enemy_drone"`, `&"projectile_enemy_secbot"`, and `&"projectile_boss"`; authored Tier 1 content never emits deprecated `&"projectile_enemy"`. | Logic / cause-label test | C.1 Rule 9 / E.24 |
| **AC-EAI-10** | **GIVEN** Stage/Encounter supplies `spawn_id`, `ai_seed`, `spawn_physics_frame`, activation bounds, patrol anchors, and target player reference, **WHEN** an enemy activates, **THEN** Enemy AI consumes those values deterministically and does not self-spawn, group-search for hidden dependencies, or randomize spawn choice. | Integration | C.1 Rule 10 |
| **AC-EAI-11** | **GIVEN** multiple enemies or projectiles are spawned in the same physics frame, **WHEN** they are inserted into the scene tree or checked out from a pool, **THEN** insertion/check-out order is sorted by `(spawn_physics_frame, spawn_id)` ascending and is identical across repeated runs. | Logic / determinism test | C.1 Rule 11 |
| **AC-EAI-12** | **GIVEN** an enemy moves outside the camera view, **WHEN** visual culling or render visibility changes, **THEN** state counters, cooldowns, patrol position, projectile schedules, and detection logic continue unchanged until Stage/Encounter performs an explicit deterministic room-boundary deactivation. | Integration | C.1 Rule 12 / E.23 |
| **AC-EAI-13** | **GIVEN** two or more standard enemies are active in one room, **WHEN** one enemy spots ECHO, **THEN** no other enemy receives an alert broadcast, perception signal, or squad-coordination state change from that enemy in Tier 1. | Logic / signal-spy test | C.1 Rule 13 |

### H.2 Formula and Tuning Acceptance

| ID | Criterion | Verification Type | Covers |
|---|---|---|---|
| **AC-EAI-14** | **GIVEN** `spawn_physics_frame` and `current_state_entered_frame` are known, **WHEN** `Engine.get_physics_frames()` advances, **THEN** `frame_offset = current_frame - spawn_physics_frame` and `state_frame = current_frame - current_state_entered_frame` exactly match D.1 for every sampled frame. | Logic | D.1 |
| **AC-EAI-15** | **GIVEN** fixed `encounter_seed`, `spawn_id`, `archetype_salt`, and `variant_count`, **WHEN** variant selection runs 1000 times across repeated test sessions, **THEN** the selected variant is identical for identical inputs and always in `0 <= selected_variant < variant_count`. | Logic | D.2 / G.1 |
| **AC-EAI-16** | **GIVEN** two patrol anchors and a configured `patrol_period_frames`, **WHEN** Drone or Security Bot patrols for two full periods, **THEN** position remains within the anchor segment, reaches both endpoints on schedule, and repeats exactly on the next period. | Logic | D.3 |
| **AC-EAI-17** | **GIVEN** ECHO positions are sampled inside, outside, and exactly on the detection boundary, **WHEN** `can_spot_player(frame_offset)` evaluates, **THEN** the result follows D.4 inclusive boundary rules, `allow_back_detection`, and archetype detection ranges exactly. | Logic | D.4 / E.18 |
| **AC-EAI-18** | **GIVEN** an enemy enters `FIRE`, **WHEN** `state_frame` advances through `wind_up_frames`, `emit_duration_frames`, and `recovery_frames`, **THEN** no projectile is spawned before emit start, all configured projectiles spawn only inside emit, and the enemy cannot leave recovery before `fire_total_frames`. | Logic | D.5 |
| **AC-EAI-19** | **GIVEN** Security Bot has `burst_count=3` and `burst_interval_frames=10`, **WHEN** it reaches emit start, **THEN** shots spawn at emit frames `0`, `10`, and `20`, and no later burst shot spawns after the bot enters `DEAD`. | Logic | D.6 / E.17 |
| **AC-EAI-20** | **GIVEN** a target vector and ordered `allowed_lanes`, **WHEN** projectile direction is selected, **THEN** Enemy AI chooses the lane with the largest dot product, resolves exact ties by lower array index, and uses the fallback facing lane for a zero-length aim vector. | Logic | D.7 / E.19 / E.20 |
| **AC-EAI-21** | **GIVEN** `projectile_speed_px_s` and `physics_fps=60`, **WHEN** an enemy projectile steps one physics frame, **THEN** its displacement equals `projectile_direction * projectile_speed_px_s / 60` within fixed-point/test tolerance and repeats identically across runs. | Logic | D.8 |
| **AC-EAI-22** | **GIVEN** a Stage/Encounter or test-fixture configuration declares active standard enemies, enemy projectiles, boss-placeholder projectiles, and non-enemy Area2Ds, **WHEN** preflight validation computes a total that would exceed Damage #8 `area2d_max_active=80`, **THEN** the encounter fails validation before gameplay activation with a deterministic error naming the over-budget counts; Enemy AI must not silently deactivate enemies, pause AI ticks, or refuse scheduled projectile emissions at runtime as a hidden budget correction. | Logic / preflight budget test | D.9 / E.14 / G.3 |
| **AC-EAI-23** | **GIVEN** a designer-authored enemy config is loaded, **WHEN** any G.1 knob is outside its safe range or Security Bot violates the burst-fit invariant, **THEN** validation fails before gameplay activation with a deterministic error that names the invalid knob. | Logic / config validation | G.1 / G.3 |

### H.3 Archetype, State, and Cross-System Acceptance

| ID | Criterion | Verification Type | Covers |
|---|---|---|---|
| **AC-EAI-24** | **GIVEN** Drone is active with default Tier 1 preset values, **WHEN** ECHO enters its detection band, **THEN** Drone transitions `PATROL -> SPOT -> FIRE`, emits exactly one telegraphed projectile using `&"projectile_enemy_drone"`, then returns to `PATROL` or `SPOT` according to detection. | Integration | C.2 / C.5.1 / G.4 |
| **AC-EAI-25** | **GIVEN** Security Bot is active with default Tier 1 preset values, **WHEN** ECHO enters its forward detection band, **THEN** Security Bot stops, faces ECHO, telegraphs, emits a three-shot burst using `&"projectile_enemy_secbot"`, and creates a recovery punish window before any next attack. | Integration | C.2 / C.5.2 / G.4 |
| **AC-EAI-26** | **GIVEN** any standard enemy is in `IDLE`, `PATROL`, `SPOT`, or `FIRE`, **WHEN** Damage reports a valid ECHO projectile hit, **THEN** the enemy transitions to `DEAD` synchronously, ignores duplicate same-frame hits, and emits death/kill events exactly once through the defined Damage/Enemy AI split. | Integration | C.3 / C.4 / E.10 / E.11 / E.12 |
| **AC-EAI-27** | **GIVEN** required spawn metadata or patrol anchors are missing, **WHEN** the enemy scene initializes, **THEN** it remains in `IDLE`, logs/debug-flags the missing field for QA, emits no attack signal, and spawns no projectile. | Logic / fixture test | E.1 / E.4 / F.4 |
| **AC-EAI-28** | **GIVEN** ECHO HurtBox `monitorable=false` during rewind i-frames, **WHEN** an enemy projectile geometrically overlaps ECHO, **THEN** Damage #8 blocks the hit and Enemy AI does not retarget, refund, respawn, or compensate for the blocked overlap. | Integration | E.9 / Damage DEC-4 |
| **AC-EAI-29** | **GIVEN** Scene Manager starts a scene transition while enemies or enemy projectiles are active, **WHEN** the scene root is removed or Stage cleanup runs, **THEN** Enemy AI emits no new kill, death, attack-cancel, or projectile-spawn authority signals during teardown. | Integration | E.15 / E.16 / F.2 |
| **AC-EAI-30** | **GIVEN** the enemy projectile pool is exhausted, **WHEN** another enemy reaches an emit frame, **THEN** the spawn fails through a deterministic no-op/debug counter path, the enemy still completes recovery, and no unordered allocation or emergency instance breaks determinism. | Logic | E.13 / D.9 |
| **AC-EAI-31** | **GIVEN** EnemyAI signals are connected to Audio/VFX/debug spies, **WHEN** an enemy spots, commits an attack, spawns a projectile, and dies, **THEN** only `enemy_spotted_player`, `enemy_attack_committed`, `enemy_projectile_spawned`, and `enemy_died` are emitted by Enemy AI, while Damage remains the source of record for `enemy_killed(enemy_id, cause)`. | Integration / signal-spy test | F.3 |
| **AC-EAI-32** | **GIVEN** a 1000-cycle deterministic test scene with 5 enemies, 20 active enemy/player projectiles, and scripted player input, **WHEN** the scene is replayed on the same dev machine, **THEN** enemy positions, state transitions, projectile positions, cause labels, and death frames are bit-identical across all runs. | Integration / determinism soak | ADR-0003 / Pillar 2 |
| **AC-EAI-33** | **GIVEN** a representative Steam Deck or Deck-equivalent profile scene with 30 active standard enemy state machines and 50 total active projectiles, **WHEN** it runs for a 5-minute sample, **THEN** 99% of frames remain under 16.6 ms and the State Machine cumulative budget remains compatible with state-machine.md AC-25 (`sm/frame_us < 0.5 ms` average). | Hardware / performance profile | D.9 / State Machine AC-25 / ADR-0003 |

### H.4 First QA Pass Order

QA should validate Enemy AI in this order:

1. **Determinism and forbidden APIs**: AC-EAI-02, AC-EAI-14, AC-EAI-15, AC-EAI-32.
2. **Damage, collision, and budget preflight contracts**: AC-EAI-05, AC-EAI-08, AC-EAI-09, AC-EAI-22, AC-EAI-28.
3. **State-machine behavior**: AC-EAI-16, AC-EAI-17, AC-EAI-18, AC-EAI-19, AC-EAI-24, AC-EAI-25, AC-EAI-26.
4. **Cross-system cleanup and signals**: AC-EAI-03, AC-EAI-10, AC-EAI-11, AC-EAI-27, AC-EAI-29, AC-EAI-31.
5. **Performance and playtest proof**: AC-EAI-04, AC-EAI-12, AC-EAI-13, AC-EAI-23, AC-EAI-30, AC-EAI-33.

---

## Visual/Audio Requirements

Enemy AI presentation exists to make deterministic rules visible. Visual and audio feedback may add juice, but it must never become gameplay authority. Frame counters from Sections C-D decide state and projectile timing; animations, VFX, and SFX must follow those counters.

### VA.1 Silhouette and Readability Contract

Enemy visuals inherit Art Bible Principle A: at 1080p, the player must distinguish ECHO, enemies, and bullets with a 0.2-second glance at real gameplay speed. Collage texture belongs primarily in backgrounds, bosses, and UI frames; standard enemy outlines stay simple and high-contrast.

| Entity | Required Shape Read | Required Contrast | Forbidden Visuals |
|---|---|---|---|
| **Drone** | Small circular/elliptical body, rotating blade silhouette, two eye lights | Red-family hostile outline or glow against cyan/magenta city lighting | Rectangular body, photo texture on outline, background-neon bullet color |
| **Security Bot** | Wide rectangular/turret body, track or grounded base read | Heavy straight-line silhouette distinct from ECHO's organic/angular shape | Circular drone-like body, blade parts, thin vertical ECHO-like lines |
| **STRIDER** | Large inverted-triangle boss platform, four turret reads, central core glow | Occupies boss visual hierarchy; roughly 3-4x standard enemy scale | Vertical silhouette similar to ECHO; standard-enemy scale |
| **Enemy projectiles** | Small but clear hostile bullet shapes with stable lane direction | Must remain distinct from ECHO bullets, background neon, and pickup/token visuals | Same color as background signage; same shape language as ECHO shots |

### VA.2 Telegraph and State Presentation

Every enemy state that can lead to lethal output needs visible state language:

| State / Substage | Visual Requirement | Audio Requirement | Timing Rule |
|---|---|---|---|
| `IDLE` | Low-threat idle pose; no attack glow or aim line | None required | Must not imply an imminent attack. |
| `PATROL` | Stable movement cadence; facing direction readable for Security Bot | Optional low-volume mechanical loop, if Audio #4 later budgets it | Movement VFX follows patrol formula; it cannot affect patrol timing. |
| `SPOT` | Recognition pose: eye flash, head/turret snap, or silhouette lift | Short spotted cue per archetype | Starts on `SPOT` entry and lasts at least `spot_confirm_frames` if not interrupted. |
| `WIND_UP` | Clear aim line, muzzle charge, or body compression before any lethal output | Attack-commit warning cue, not louder than rewind/death-critical SFX | Must begin before projectile emission and respect `wind_up_frames`. |
| `EMIT` | Muzzle flash exactly on each projectile spawn frame | Shot cue per projectile or per burst, depending on mix budget | Cosmetic flash follows D.6 shot frames; it cannot add extra shots. |
| `RECOVER` | Cooldown smoke, dimmed weapon light, or recoil settle pose | Optional short mechanical release | Communicates punish window; cannot be skipped visually if recovery is gameplay-relevant. |
| `DEAD` | Immediate gameplay collision-off read, then deterministic pop/fall/shutdown VFX | Death cue through Enemy AI presentation signal and/or Damage kill signal mapping | VFX may continue after collision is disabled; it cannot block or delay `DEAD` logic. |

Drone telegraphs should read as aerial lane danger: eye flash + single muzzle charge + one projectile flash. Security Bot telegraphs should read as countable burst danger: turret lock + three distinct emit pulses + visible recovery. STRIDER's detailed boss presentation is owned by Boss Pattern #11, but it must preserve the same telegraph -> commit -> output grammar.

### VA.3 Projectile Visual Requirements

- Drone projectile: single-shot aerial threat; compact hostile bullet with a simple trail that does not imply homing.
- Security Bot projectile: heavier ground-lane burst bullet; three emit pulses must be visually countable at `burst_interval_frames`.
- STRIDER / boss projectile: uses `projectile_boss` cause and Boss Pattern-owned visuals; should be larger or more intense than standard projectiles without reusing ECHO bullet language.
- Enemy projectile trails are render-only. They cannot steer, delay, accelerate, or change lane after spawn.
- Projectile VFX must remain readable during Time Rewind shader inversion and against neon billboard backgrounds. If color inversion collapses hostile/projectile identity, Shader/VFX #16 must adjust presentation while preserving logic.

### VA.4 Audio Event Hooks

Audio #4 is currently approved for core player/rewind/death SFX but does not yet own detailed Enemy AI cue mapping. Enemy AI therefore exposes presentation signals and proposes cue intents; Audio remains the owner of bus routing, pool limits, pitch jitter, and final file names.

| Event | Signal / Source | Proposed Cue Intent | Constraint |
|---|---|---|---|
| Enemy spots ECHO | `enemy_spotted_player(enemy_id, archetype_id)` | Short archetype cue: drone chirp / bot servo lock | Must not mask rewind-denied, death, or boss-killed cues. |
| Enemy commits attack | `enemy_attack_committed(enemy_id, archetype_id, cause)` | Telegraph confirmation cue aligned to wind-up | Cue timing follows state frame; it is not gameplay authority. |
| Enemy projectile spawned | `enemy_projectile_spawned(enemy_id, projectile, cause)` | Optional projectile launch cue or burst tick | If pitch variation is used, it must follow Audio Rule 15 deterministic jitter style, not `randf()`. |
| Enemy dies | Enemy AI `enemy_died(...)` for presentation; Damage `enemy_killed(enemy_id, cause)` for source of record | Shutdown pop, metal crack, or boss-host transition cue | Audio must use Damage kill signal when exact kill cause matters. |

No Enemy AI cue may directly duck music, trigger camera shake, consume rewind tokens, or decide player damage. Music bus ducking remains Time Rewind-owned in Audio #4.

### VA.5 Asset and Implementation Handoff

Minimum Tier 1 presentation assets:

| Asset Class | Drone | Security Bot | STRIDER Host |
|---|---|---|---|
| Sprite / silhouette | Idle/patrol body, spotted eye flash, wind-up charge, death pop | Patrol body, turret lock, wind-up charge, three-shot muzzle flash, shutdown | Base platform silhouette, central core glow, host death/phase handoff placeholder |
| Projectile VFX | Single hostile bullet + simple trail | Burst bullet + countable muzzle flash | Boss projectile placeholder owned by Boss Pattern |
| Audio cue intent | spotted, attack commit, projectile launch, death | spotted, attack commit, burst tick/launch, death | boss-host spotted/phase cue placeholder |
| Debug overlay | state name, state frame, selected lane | state name, burst shot index, selected lane | EnemyBase host metadata |

Prototype fallback is allowed: simple colored geometry, debug text, and placeholder SFX may stand in for final assets as long as the 0.2-second readability test passes and every lethal output still has a visible telegraph. Final art/audio polish should run `/asset-spec system:enemy-ai` after the Art Bible is approved and this section is accepted.

---

## Open Questions

Enemy AI Tier 1 behavior is specified enough for design review and prototype planning. The following questions are intentionally deferred because they depend on asset sourcing, implementation spikes, or downstream systems that are not authored yet. None of these questions may change the core deterministic combat contract without a follow-up `/propagate-design-change` pass.

| # | Question | Owner | Target | Blocking? | Notes |
|---|---|---|---|---|---|
| OQ-EAI-1 | Should Tier 1 use dedicated enemy sprites immediately, or prototype with simple colored geometry plus debug labels first? | art-director + technical-artist | Before `/asset-spec system:enemy-ai` | No | Prototype fallback is allowed by VA.5 as long as the 0.2-second readability test passes. |
| OQ-EAI-2 | Which exact Audio #4 cue names should map to `enemy_spotted_player`, `enemy_attack_committed`, `enemy_projectile_spawned`, and `enemy_died`? | audio-director + sound-designer | Audio/VFX polish pass after Enemy AI review | No | Enemy AI owns the signal surface only; Audio owns bus routing, pool limits, file names, and deterministic pitch jitter. |
| OQ-EAI-3 | **RESOLVED 2026-05-13 by approved `boss-pattern.md`** — STRIDER remains an EnemyBase-compatible host (`CharacterBody2D`, priority 10, read-only target reference); Boss Pattern owns boss-local lifecycle, phase scripts, phase thresholds, boss projectiles, and cleanup. | ai-programmer + game-designer | Closed | No | Current GDD treats STRIDER Host as compatibility metadata and reserves detailed boss behavior for Boss Pattern #11. |
| OQ-EAI-4 | **RESOLVED 2026-05-13 by `stage-encounter.md`** — final Tier 1 schema covers `spawn_id`, `ai_seed`, `spawn_physics_frame`, patrol anchors, room bounds, activation triggers, Area2D preflight, and deterministic insertion order. | level-designer + gameplay-programmer | Closed | No | Stage/Encounter now owns placement authoring and room lifecycle. |
| OQ-EAI-5 | What Tier 1 encounter proves AimLock is not a dominant stationary strategy without exceeding the 4-decision attention budget? | game-designer + level-designer | Tier 1 playtest D1 after Enemy AI/Boss/Stage docs land | No | Drone vertical pressure plus Security Bot burst timing are the current anti-stationary tools. Stage layout must validate the combined pressure. |
| OQ-EAI-6 | What is the exact maximum active enemy count per Tier 1 room after Stage/Encounter and performance budgets are finalized? | performance-analyst + level-designer | Before implementation milestone sizing | No | D.9 currently budgets up to 8 active standard enemies. Stage/Encounter may choose a lower room cap for readability or performance. |
| OQ-EAI-7 | **RESOLVED 2026-05-13 by `vfx-particle.md`** — Tier 1 keeps the three coarse projectile causes (`projectile_enemy_drone`, `projectile_enemy_secbot`, `projectile_boss`) for VFX readability. | gameplay-programmer + technical-artist | Closed for Tier 1 VFX | No | Any future split must update Damage, Audio/VFX mappings, and tests together. |
| OQ-EAI-8 | Should enemy debug overlays ship only in dev builds, or remain accessible through a QA toggle in prototype builds? | QA lead + gameplay-programmer | Test setup / first Enemy AI implementation story | No | H.4 assumes state-frame and selected-lane observability for QA. Shipping exposure is an implementation/debug policy decision. |

### Deferred Follow-Up Actions

1. Run `/design-review design/gdd/enemy-ai.md --depth lean` in a fresh session to validate this GDD independently.
2. If approved or revised to approval, update reciprocal downstream mirrors where needed:
   - `audio.md` for final cue mapping once Audio consumes Enemy AI signals.
   - `stage-encounter.md` only if future Stage revisions change spawn schema or Area2D budget ownership.
   - `boss-pattern.md` only if Boss Pattern review changes STRIDER host boundaries.
3. Register any final cross-system constants or entities only after design review confirms that D.1-D.9 values are stable enough to become shared facts.
