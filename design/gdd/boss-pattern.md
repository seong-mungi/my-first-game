# Boss Pattern System

> **Status**: Approved
> **Author**: user + game-designer + ai-programmer + systems-designer
> **Created**: 2026-05-13
> **Last Updated**: 2026-05-13
> **Implements Pillar**: Pillar 2 (Deterministic Patterns) primary; Pillar 1 (Time Rewind as learning tool) through phase-repeat readability; Pillar 4 (5-Minute Rule) through one compact STRIDER exam; Pillar 5 (Small Success) through one Tier 1 mini-boss only
> **Engine**: Godot 4.6 / GDScript / 2D / CharacterBody2D boss host + Area2D boss projectiles
> **System #**: 11 (Feature / Gameplay)

---

## A. Overview

Boss Pattern System #11 owns STRIDER's Tier 1 mini-boss behavior: phase scripts, phase hit thresholds, boss-only projectile schedules, boss telegraphs, phase interruption cleanup, and the final `boss_killed(boss_id)` timing that unlocks token reward and stage clear. It does **not** own stage placement, scene transitions, token mutation, damage collision primitives, standard enemy behavior, camera calls, or HUD layout. Its central promise is: STRIDER feels like a final exam of the stage's lessons, not a random damage sponge. Every phase repeats a deterministic pattern, every lethal output is telegraphed, and the final hit produces one authoritative boss-kill event consumed by Time Rewind #9, Scene Manager #2, Audio #4, Camera #3, and future HUD/VFX.

Tier 1 includes exactly one boss: `strider_tier1`. STRIDER is an EnemyBase-compatible host that reads ECHO's position, moves on the ADR-0003 priority-10 clock, owns three authored phases, and fires boss projectiles with Damage #8 cause `&"projectile_boss"`. Phase thresholds are discrete hit counts, not an HP bar. The player learns by seeing phase changes in behavior and silhouette, not by watching numbers.

---

## B. Player Fantasy

The player should feel: **"I learned the room grammar, and now STRIDER is speaking in full sentences."**

STRIDER is not meant to surprise the player with new invisible rules. It combines what the stage already taught:

- aerial lane awareness from Drone encounters;
- countable burst timing from Security Bot encounters;
- movement discipline against anti-stationary pressure;
- one-hit threat clarity from Damage #8;
- "try again with knowledge" recovery from Time Rewind #9.

The anchor moment is:

> ECHO enters the final service bay. STRIDER drops from the ceiling, its four legs lock into the rails, and a red eye sweeps the room before the first shot. The player dies once to the lane sweep, rewinds, and realizes the telegraph is not decoration. On the next attempt, they dodge through the gap, land a hit, and STRIDER's collage shell tears open into a faster pattern. The boss did not become random; it became a harder sentence.

### B.1 Player-Facing Promises

| Promise | Player Feeling | Design Meaning |
|---|---|---|
| **Readable escalation** | "The boss changed, but I understand why." | Phase changes alter pattern grammar and silhouette; no hidden HP math or random attack rolls. |
| **Fair rewind learning** | "I can reuse what I learned after a rewind." | Boss phase, active projectiles, and attack clocks are not rewound; pattern determinism lets the player adapt. |
| **Final-exam pressure** | "This tests the stage, not a whole new game." | STRIDER reuses Drone/Bot lane and burst reads; no new movement verbs or text tutorial. |
| **No damage accounting UI** | "I watch the boss, not a bar." | Discrete phase thresholds exist internally; production UI never exposes an HP bar or hit counter. |
| **One clear victory beat** | "The stage is complete." | Exactly one `boss_killed` event fires on final phase last hit, feeding token recharge and stage clear. |

### B.2 Tier 1 Boss Shape

Tier 1 STRIDER uses three authored phases:

1. **Phase 0 — Probe**: one lane shot, one reposition beat, obvious recovery. Teaches "read the eye before the projectile."
2. **Phase 1 — Crossfire**: two-lane alternating pressure and countable burst timing. Combines Drone lane read + Security Bot burst read.
3. **Phase 2 — Shutdown**: denser staggered barrage with longer recovery windows. Tests mastery without adding summons, random waves, or multi-screen arena rules.

### B.3 Anti-Fantasy

Boss Pattern must never create these feelings:

- **"The boss picked an unfair move because I died before."** No death-count scaling, no runtime random attack choice, no adaptive punishment.
- **"I lost because the boss HP was unknowable math."** Phase thresholds are internal; phase transitions are visible and audio-readable.
- **"The rewind broke the fight."** Boss phase state and projectiles are outside player rewind scope by ADR-0001.
- **"The boss stole stage clear from me."** Final hit emits one `boss_killed`; Scene Manager clear beats checkpoint restart on same-tick death.
- **"This became a production boss rush system."** Tier 1 includes one STRIDER mini-boss only; summons, boss rush, zoom choreography, and multi-boss support are Tier 2+.

---

## C. Detailed Design

### C.1 Core Rules

**Rule 1 — Boss Pattern owns phase behavior, not stage placement.**

Stage / Encounter #12 places STRIDER, owns the final gate, supplies room/arena metadata, and decides when the boss encounter starts. Boss Pattern #11 consumes that handoff and owns only STRIDER's behavior after activation. Boss Pattern must not call `change_scene_to_packed()`, emit Scene Manager lifecycle signals, or move the final gate directly.

**Rule 2 — STRIDER is an EnemyBase-compatible boss host.**

STRIDER is implemented as a `CharacterBody2D` boss host compatible with Enemy AI #10's `EnemyBase` contract:

- `process_physics_priority = 10`;
- deterministic `spawn_id`, `ai_seed`, and `spawn_physics_frame`;
- explicit `target_player: PlayerMovement` reference;
- read-only `target_player.global_position` / `target_player.velocity`;
- no RigidBody2D gameplay branch;
- no global RNG;
- no hidden parallel state-machine fork.

Boss Pattern may host a boss-specific child state machine or controller, but it must preserve State Machine #5's per-host, non-autoload pattern and EnemyBase's deterministic clock.

**Rule 3 — Damage #8 owns the phase-hit signal contract.**

Boss Pattern owns `phase_hp_table`, `phase_index`, attack phase scripts, and cleanup. Damage #8 owns the HitBox/HurtBox component contract, cause taxonomy, and signal signatures:

- `boss_hit_absorbed(boss_id: StringName, phase_index: int)`;
- `boss_pattern_interrupted(boss_id: StringName, prev_phase_index: int)`;
- `boss_phase_advanced(boss_id: StringName, new_phase: int)`;
- `boss_killed(boss_id: StringName)`.

The boss host must follow Damage #8 C.4.2 / F.4.1 emit ordering exactly. Boss Pattern must not introduce a second boss-kill signal, HP-change signal, or `hits_remaining` UI signal.

**Rule 4 — Tier 1 uses three discrete phases and no HP bar.**

The Tier 1 STRIDER phase table is:

| Phase Index | Phase ID | Internal Hits | Player-Facing Read |
|---:|---|---:|---|
| 0 | `&"strider_probe"` | 3 | Eye sweep + single lane shot |
| 1 | `&"strider_crossfire"` | 4 | Shell opens; alternating burst lanes |
| 2 | `&"strider_shutdown"` | 5 | Overheated core; staggered dense barrage |

`phase_hp_table = [3, 4, 5]`, `final_phase_index = 2`, and total required hits = 12. The numbers are internal tuning values only. HUD #13 may show phase state or boss presence, but it must not show an HP bar, hit counter, or remaining hit count.

**Rule 5 — every lethal boss output uses telegraph → commit → active → recovery.**

Every boss attack has:

- `telegraph_frames`: visible anticipation before any lethal output can occur;
- `commit_frame`: the exact frame when the attack becomes unavoidable by canceling the wind-up;
- `active_frames`: frames where projectiles / hitboxes exist or are emitted;
- `recovery_frames`: readable vulnerability / reset time after output.

No boss projectile, laser, contact zone, or arena hazard may become lethal before its telegraph completes. Cosmetic animation may lead or follow the counter, but cannot replace the frame counter.

**Rule 6 — phase interruption cleans patterns without rewinding history.**

When Damage emits `boss_pattern_interrupted(boss_id, prev_phase_index)`, Boss Pattern must:

1. stop uncommitted wind-ups and warning-only telegraphs;
2. disconnect or ignore obsolete phase-local timers/callbacks;
3. clear phase-local attack state counters;
4. preserve already-emitted boss projectiles unless the boss is killed;
5. enter the next phase only after `boss_phase_advanced` fires.

This prevents stale laser sweeps, charge attacks, or warning areas from leaking into the next phase. It does not rewind already-emitted projectiles; Time Rewind #9 is player-only.

**Rule 7 — final kill cleanup is one-way and single-fire.**

On the final phase's last hit, Damage emits `boss_pattern_interrupted(...)` then `boss_killed(boss_id)`. Boss Pattern must treat `boss_killed` as terminal:

- set lifecycle to `DEFEATED`;
- stop future boss attack scheduling;
- queue-free or disable boss-owned warning areas and non-projectile telegraphs;
- queue-free boss-owned projectiles only after the current signal cascade is complete;
- never emit `boss_killed` again for the same `boss_id`.

Scene Manager #2 owns the stage-clear transition. Time Rewind #9 owns token mutation. Audio #4 and Camera #3 own presentation response. Boss Pattern owns only boss-local cleanup.

**Rule 8 — boss projectiles are Area2D and use `&"projectile_boss"`.**

All Tier 1 boss projectiles are script-stepped `Area2D` nodes with `process_physics_priority = 20`. Their HitBoxes use Damage #8 layer L4 / mask L1 and set `HitBox.cause = &"projectile_boss"` at instantiation. Boss projectiles must not collide with STRIDER's own boss HurtBox or standard enemy HurtBoxes in Tier 1.

**Rule 9 — Boss Pattern must fit the Stage / Damage Area2D budget.**

Boss Pattern owns `boss_projectile_cap = 16` and `boss_warning_area_cap = 4` for Tier 1. Stage / Encounter #12 includes these caps in its preflight Area2D budget. If the declared cap would push a room above Damage #8 `area2d_max_active = 80`, the encounter fails preflight; Boss Pattern must not silently skip scheduled projectiles at runtime as a hidden budget correction.

**Rule 10 — boss phase state is rewind-immune.**

Boss Pattern does not subscribe to `rewind_started`, `rewind_completed`, or `rewind_protection_ended` in Tier 1. If ECHO rewinds after a phase advance, STRIDER remains in the new phase. If ECHO rewinds during a projectile pattern, already-existing boss projectiles and phase clocks continue according to their deterministic timeline.

**Rule 11 — token reward timing is exactly the final `boss_killed` event.**

Boss Pattern does not call Time Rewind Controller directly. The only token reward path is:

`final phase last hit` → Damage-compatible boss host emits `boss_killed(boss_id)` → Time Rewind #9 `grant_token()` via subscription → `token_replenished(new_total)`.

If `boss_killed` and ECHO lethal hit occur in the same physics tick, Time Rewind #9's existing consume-then-grant invariant applies. Boss Pattern's obligation is to keep STRIDER at priority 10 or later and never move boss logic before Damage priority 2.

**Rule 12 — Tier 1 boss pattern order is authored, not random.**

Each phase has a fixed pattern sequence. The current phase and elapsed phase frame determine the next attack slot. `ai_seed` may seed cosmetic-only micro-variation in non-gameplay visuals later, but Tier 1 attack choice, attack timing, projectile count, and projectile direction are authored and deterministic.

**Rule 13 — no Tier 1 summons or boss knockback.**

STRIDER does not spawn standard enemies, drone helpers, destructible adds, knockback zones, or non-lethal hit-stun in Tier 1. These features require explicit Tier 2 design review because they reopen Player Movement #6 knockback triggers, Enemy AI #10 spawn ownership, Stage #12 Area2D budgets, and Damage #8 binary threat assumptions.

**Rule 14 — arena size is a Boss Pattern requirement, Stage remains the owner.**

Boss Pattern requires a Tier 1 STRIDER arena of at least `960 × 540 px`, with a recommended authored room size of `1120 × 620 px` inside Stage #12 camera limits. Stage owns the actual `room_bounds` and `stage_camera_limits`; Boss Pattern validates the received `arena_bounds` before activation and refuses to arm if the arena is smaller than the minimum.

### C.2 Boss Lifecycle State Machine

Boss Pattern has one boss-local lifecycle machine. This is separate from Scene Manager's boundary state and separate from Stage / Encounter's room state.

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `UNINITIALIZED` | Node constructed, no start spec yet | Valid `BossStartSpec` injected | No movement, no attacks, no signal subscriptions except setup validation. |
| `DORMANT` | Start spec valid; final gate not triggered | Stage activates boss encounter | STRIDER visible or hidden according to Stage; no lethal output. |
| `INTRO` | Boss encounter starts | `intro_frames` elapsed | Plays drop-in / stance lock; HurtBox may be active, but attacks are disabled. |
| `PHASE_ACTIVE` | Intro complete or `boss_phase_advanced` handled | `boss_pattern_interrupted` or `boss_killed` | Runs the current phase's deterministic pattern sequence. |
| `PHASE_INTERRUPT` | Damage emits `boss_pattern_interrupted` | `boss_phase_advanced` handled or `boss_killed` handled | Cancels uncommitted phase-local behavior and freezes attack scheduling. |
| `DEFEATED` | Damage emits `boss_killed` | Scene transition / queue_free | No attack scheduling; boss-local cleanup only. |

### C.3 Phase Catalog

| Phase | Pattern Sequence | Telegraph Target | Projectile Cap Contribution | Notes |
|---|---|---|---:|---|
| `strider_probe` | `eye_lane_shot` → `rail_step` → `eye_lane_shot` | 36 frames minimum before projectile | 3 | Introductory read. One horizontal lane at a time. |
| `strider_crossfire` | `dual_lane_burst` → `floor_warning_sweep` → `dual_lane_burst` | 42 frames minimum before first burst | 8 | Combines countable burst with lane switching. |
| `strider_shutdown` | `staggered_barrage` → `overheat_recovery` → `staggered_barrage` | 54 frames minimum before dense output | 16 | Densest phase; long recovery creates learning window. |

### C.4 Data Structures

#### C.4.1 BossStartSpec

`BossStartSpec` is supplied by Stage / Encounter #12 when the final gate activates.

| Field | Type | Required | Owner | Rule |
|---|---|---|---|---|
| `boss_id` | `StringName` | Yes | Boss Pattern | Tier 1 value: `&"strider_tier1"`. |
| `arena_bounds` | `Rect2` | Yes | Stage | Must satisfy C.1 Rule 14. |
| `entry_anchor` | `Vector2` / `Marker2D` | Yes | Stage | STRIDER initial position. |
| `exit_gate_id` | `StringName` | Yes | Stage | Stage consumes after `boss_killed`; Boss does not open it directly. |
| `target_player` | `PlayerMovement` | Yes | Stage | Read-only target reference. No group lookup fallback. |
| `spawn_id` | `int` | Yes | Stage | Deterministic ordering with encounter spawns. |
| `ai_seed` | `int` | Yes | Stage | Reserved for deterministic cosmetic seeds; no random attack choice. |
| `spawn_physics_frame` | `int` | Yes | Stage | Basis for phase/frame calculations. |

#### C.4.2 BossPhaseSpec

| Field | Type | Required | Tier 1 Value |
|---|---|---|---|
| `phase_id` | `StringName` | Yes | `strider_probe`, `strider_crossfire`, `strider_shutdown` |
| `phase_index` | `int` | Yes | `0..2` |
| `phase_hits` | `int` | Yes | `[3, 4, 5]` |
| `pattern_sequence` | `Array[StringName]` | Yes | Fixed per phase |
| `phase_entry_lock_frames` | `int` | Yes | 30 |
| `phase_visual_tag` | `StringName` | Yes | Presentation hook only |

#### C.4.3 BossAttackSpec

| Field | Type | Required | Rule |
|---|---|---|---|
| `attack_id` | `StringName` | Yes | Unique within boss. |
| `telegraph_frames` | `int` | Yes | Minimum visible anticipation. |
| `commit_frame` | `int` | Yes | `0 <= commit_frame < telegraph_frames + active_frames`. |
| `active_frames` | `int` | Yes | Frames with projectile emission or active hitboxes. |
| `recovery_frames` | `int` | Yes | Frames before next attack can begin. |
| `projectile_pattern_id` | `StringName` | Optional | References boss projectile emission table. |
| `max_projectiles_alive` | `int` | Yes | Must respect C.1 Rule 9. |

### C.5 Signal / Event Surface

Boss Pattern does **not** own Damage signal signatures, but it is the boss host responsible for emitting them through the Damage-compatible phase procedure. It may own presentation/debug hooks that are not gameplay authority.

| Signal / Event | Owner | Allowed Consumers | Rule |
|---|---|---|---|
| `boss_attack_telegraphed(boss_id, attack_id, phase_index)` | Boss Pattern | Audio #4, VFX #14, debug HUD | Presentation only; cannot drive gameplay. |
| `boss_attack_committed(boss_id, attack_id, phase_index)` | Boss Pattern | Audio #4, VFX #14, debug tests | Fires on commit frame before projectile emission. |
| `boss_hit_absorbed(...)` | Damage contract via boss host | VFX #14 | Signature and emit timing owned by Damage #8. |
| `boss_pattern_interrupted(...)` | Damage contract via boss host | Boss Pattern, VFX #14 | Boss Pattern uses this for cleanup only. |
| `boss_phase_advanced(...)` | Damage contract via boss host | Boss Pattern, HUD #13, VFX #14, Audio #4 | Boss Pattern uses this to enter next phase. |
| `boss_killed(...)` | Damage contract via boss host | Scene Manager #2, Time Rewind #9, Audio #4, Camera #3, Boss Pattern | Single terminal event. |

Boss Pattern must not emit `player_hit_lethal`, `lethal_hit_detected`, `death_committed`, `enemy_killed`, `scene_will_change`, `scene_post_loaded`, `rewind_started`, `rewind_completed`, or `token_replenished`.

### C.6 Interaction with Other Systems

| System | Relationship | Boss Pattern Uses / Provides | Forbidden Coupling |
|---|---|---|---|
| **#10 Enemy AI** | Upstream base host | EnemyBase deterministic host, target read pattern, priority 10, no RigidBody2D branch | Forking EnemyBase or adding hidden boss-only physics clock. |
| **#8 Damage** | Hard signal / component contract | Boss HurtBox L6, boss projectile HitBox L4, phase threshold procedure, `projectile_boss` cause | New HP signal, HP bar data, direct ECHO death call. |
| **#9 Time Rewind** | Hard token economy consumer | Boss supplies exactly one `boss_killed`; TRC grants token | Direct TRC calls, boss rewind subscription, phase rollback. |
| **#12 Stage / Encounter** | Hard authoring handoff | Boss consumes `BossStartSpec`, arena bounds, target reference, final gate metadata | Boss moving stage gates, swapping scenes, or spawning itself. |
| **#2 Scene Manager** | Indirect stage clear | `boss_killed` triggers Scene Manager via Damage signal contract | Boss calling scene transition APIs. |
| **#6 Player Movement** | Read-only target | `target_player.global_position` and `velocity` for aiming reads | Mutating player state, knockback, direct movement calls. |
| **#7 Player Shooting** | Indirect through Damage | ECHO projectile hits Boss HurtBox L6 | Reading ammo, cooldown, weapon internals, or projectile owner state. |
| **#13 HUD** | Downstream approved 2026-05-13 | Phase/presence notification; no HP bar | Exposing hit count / remaining hits. |
| **#14 VFX** | Downstream designed 2026-05-13 | Attack telegraph, phase visual tags, impact and death burst hooks | VFX changing attack timing or hitboxes. |
| **#4 Audio** | Downstream soft | Telegraph, phase, and boss-killed cues | Audio changing gameplay timing. |

---

## D. Formulas

### D.1 Phase Hit Table

```
phase_hp_table[strider_tier1] = [3, 4, 5]
final_phase_index = phase_hp_table.size() - 1
total_boss_hits = sum(phase_hp_table) = 12
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `phase_hp_table` | `Array[int]` | size `1..4`, each `1..8` | Boss Pattern | Internal discrete phase hit thresholds. |
| `phase_index` | `int` | `0..final_phase_index` | Damage-compatible boss host | Current phase. |
| `final_phase_index` | `int` | `0..3` Tier 1-safe | Derived | Last phase index. |
| `total_boss_hits` | `int` | `3..24` Tier 1-safe | Derived | Total player hits required. |

**Output Range:** Tier 1 STRIDER requires exactly 12 successful ECHO projectile hits across three phases.

**Invariant:** `phase_hp_table.size() == final_phase_index + 1` and every entry is `>= 1`. Boss host validation fails before activation if not true.

### D.2 Damage-Compatible Phase Transition

Boss Pattern adopts Damage #8 D.2.1 / D.2.3 exactly:

```
remaining_next = max(phase_hits_remaining - hits_in_tick, 0)

if remaining_next > 0:
    emit boss_hit_absorbed(boss_id, phase_index)
elif phase_index < final_phase_index:
    emit boss_pattern_interrupted(boss_id, phase_index)
    phase_index += 1
    phase_hits_remaining = phase_hp_table[phase_index]
    emit boss_phase_advanced(boss_id, phase_index)
else:
    emit boss_pattern_interrupted(boss_id, phase_index)
    emit boss_killed(boss_id)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `hits_in_tick` | `int` | `0..PROJECTILE_CAP` | Damage collision callbacks | Count of ECHO projectile hits received in a physics tick. |
| `_phase_advanced_this_frame` | `bool` | `{true,false}` | Boss host | Per-Damage lock that discards second+ transition in same frame. |
| `phase_hits_remaining` | `int` | `0..phase_hp_table[phase_index]` | Boss host | Current phase's remaining internal hits. |

**Edge Case:** If 3 hits arrive when `phase_hits_remaining = 1`, the phase advances exactly one step. Extra hits are discarded; phase skipping is not supported in Tier 1.

### D.3 Pattern Sequence Selection

```
phase_elapsed_frames = Engine.get_physics_frames() - phase_enter_frame
loop_frames = sum(attack_total_frames for attack in current_phase.pattern_sequence)
loop_frame = phase_elapsed_frames % loop_frames
attack_slot = first attack whose cumulative_frame_range contains loop_frame
attack_local_frame = loop_frame - attack_slot.start_frame
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `phase_enter_frame` | `int` | `>= 0` | Boss Pattern | Frame when `boss_phase_advanced` was handled or intro ended. |
| `attack_total_frames` | `int` | `60..180` | BossAttackSpec | Telegraph + active + recovery. |
| `loop_frames` | `int` | `60..540` | Derived | Total frames for one phase pattern loop. |
| `attack_slot` | `BossAttackSpec` | fixed sequence entry | Derived | Current attack from authored order. |

**Output Range:** deterministic attack choice for every physics frame; no random branch.

### D.4 Attack Frame Budget

```
attack_total_frames = telegraph_frames + active_frames + recovery_frames
commit_frame <= telegraph_frames + active_frames - 1
lethal_output_first_frame >= telegraph_frames
```

| Attack | Telegraph | Active | Recovery | Total |
|---|---:|---:|---:|---:|
| `eye_lane_shot` | 36 | 6 | 30 | 72 |
| `dual_lane_burst` | 42 | 24 | 36 | 102 |
| `floor_warning_sweep` | 48 | 30 | 42 | 120 |
| `staggered_barrage` | 54 | 42 | 48 | 144 |
| `overheat_recovery` | 30 | 0 | 72 | 102 |

**Output Range:** Tier 1 boss attacks last `72..144` frames. Lethal output starts only after the telegraph window.

### D.5 Boss Area2D Cap

```
boss_area2d_declared =
    boss_hurtbox_count
  + boss_projectile_cap
  + boss_warning_area_cap

boss_area2d_declared = 1 + 16 + 4 = 21
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `boss_hurtbox_count` | `int` | `1` | Boss Pattern / Damage | STRIDER boss HurtBox L6. |
| `boss_projectile_cap` | `int` | `0..16` | Boss Pattern | Maximum live boss projectile HitBoxes. |
| `boss_warning_area_cap` | `int` | `0..4` | Boss Pattern | Non-damaging warning Area2Ds. |
| `boss_area2d_declared` | `int` | `1..21` | Derived | Boss contribution to Stage preflight. |

**Output Range:** Tier 1 STRIDER contributes at most 21 Area2D nodes to Stage #12 preflight. Stage validates the full room against Damage #8 `area2d_max_active = 80`.

### D.6 Token Grant Timing

```
T_after_boss_kill = min(T + 1, max_tokens)
```

Boss Pattern does not execute this formula. It is restated here only to lock timing: Boss Pattern provides one `boss_killed` event; Time Rewind #9 owns `grant_token()`.

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `T` | `int` | `0..max_tokens` | Time Rewind #9 | Token count before boss kill. |
| `max_tokens` | `int` | default `5` | Time Rewind #9 | Token cap. |
| `T_after_boss_kill` | `int` | `1..max_tokens` if grant enabled | Time Rewind #9 | Token count after TRC grant. |

**Same-Tick Edge:** If ECHO consumes a token and STRIDER dies in the same tick, Time Rewind #9 AC-B5 controls ordering and verifies net-zero / grant behavior. Boss Pattern must not alter it.

---

## E. Edge Cases

### E.1 BossStartSpec missing target player

- **If `target_player == null` when boss activation starts**: fail boss preflight with `boss_preflight_failed(boss_id, &"missing_target_player")`, stay `DORMANT`, and emit no boss attacks.

### E.2 Arena too small

- **If `arena_bounds.size.x < 960` or `arena_bounds.size.y < 540`**: fail boss preflight with `boss_preflight_failed(boss_id, &"arena_too_small")`. Stage may still load the room for debug, but production boss proof fails.

### E.3 Invalid phase table

- **If `phase_hp_table.size() != final_phase_index + 1` or any entry `< 1`**: fail validation before `INTRO`; do not arm boss HurtBox hit handling.

### E.4 Duplicate boss_id in one stage load

- **If two active Boss Pattern hosts share the same `boss_id`**: fail preflight. Tier 1 supports exactly one `strider_tier1` boss host per stage load.

### E.5 Phase transition while attack wind-up is uncommitted

- **If ECHO hits the boss enough to trigger `boss_pattern_interrupted` before an attack reaches commit**: cancel the wind-up, remove warning-only areas, and enter `PHASE_INTERRUPT`. No projectile is spawned from that canceled attack.

### E.6 Phase transition while projectiles are already active

- **If projectiles were emitted before the interrupt**: existing projectiles continue until lifetime expiry or collision. Do not rewind, delete, or retarget them on phase advance. This preserves player-only rewind scope and avoids hidden mercy behavior.

### E.7 Final hit while boss projectile hits ECHO in the same tick

- **If `boss_killed` and `player_hit_lethal` occur in the same physics tick**: do not special-case in Boss Pattern. Time Rewind #9 AC-B5 handles consume/grant ordering; Scene Manager #2 CLEAR_PENDING beats checkpoint restart for stage clear.

### E.8 Boss killed during Stage transition

- **If Stage / Scene Manager is already tearing down when `boss_killed` arrives**: Boss Pattern remains terminal and schedules no new attacks. Scene Manager owns duplicate transition guards.

### E.9 Duplicate final hit after boss_killed

- **If ECHO projectiles overlap the boss after `DEFEATED` is set but before queue_free completes**: ignore all boss HurtBox callbacks and emit no additional Damage boss signals.

### E.10 Boss projectile cap reached by authored pattern

- **If an authored attack would exceed `boss_projectile_cap = 16`**: fail preflight. Do not silently skip projectile emissions at runtime, because skipped bullets would change the learned pattern.

### E.11 Stage Area2D preflight rejects STRIDER

- **If Stage #12 computes the full room Area2D total above 80 using Boss caps**: Stage fails the encounter before play. Boss Pattern must not lower its projectile cap dynamically to make the room pass.

### E.12 Player rewind after phase advance

- **If ECHO rewinds to a position from before the phase transition**: STRIDER remains in the new phase and phase clocks continue. This is intentional and mirrors Time Rewind #9 E-18.

### E.13 Player rewind during active boss projectile

- **If ECHO rewinds while a boss projectile is mid-flight**: the projectile is not restored or moved backward. It continues from its current deterministic position.

### E.14 Boss phase wants to spawn standard enemies

- **If a designer requests drone/bot adds during STRIDER**: reject for Tier 1. Reopen Stage #12 Area2D budget, Enemy AI #10 spawn ownership, and Boss Pattern phase design in Tier 2.

### E.15 Boss knockback request

- **If an attack design requires ECHO knockback, hit-stun, or non-lethal displacement**: reject for Tier 1. This reopens Player Movement #6 DEC-PM-1 and Damage #8 DEC-3.

### E.16 Boss self-damage request

- **If a phase asks for STRIDER to be hit by its own projectile**: reject for Tier 1. Damage #8 E.15 requires a separate layer bit for future self-vulnerable boss designs.

### E.17 HUD asks for remaining hits

- **If HUD #13 requests `hits_remaining` or a boss HP bar**: deny the interface. HUD may subscribe to `boss_phase_advanced` and show phase/state feedback, but remaining hit count is intentionally hidden.

### E.18 Boss pattern timer uses wall-clock time

- **If implementation uses `Time.get_ticks_msec()`, `Timer`, or `_process(delta)` for gameplay attack timing**: fail static review. Boss attack scheduling uses physics frames only.

### E.19 Boss Pattern not authored but Stage final gate needs testing

- **If the stage is tested without this system implemented**: Stage #12 may use its debug-only `CLEAR_ON_TRIGGER_EXIT` final gate fixture. That fixture cannot satisfy production stage-clear proof.

### E.20 Phase entry hit on the same frame as `boss_phase_advanced`

- **If an ECHO projectile overlaps STRIDER on the same frame a phase starts**: Damage #8 `_phase_advanced_this_frame` lock discards second+ same-frame transition. Boss Pattern must not manually decrement phase hits during `PHASE_INTERRUPT`.

---

## F. Dependencies

Boss Pattern #11 is a Feature-layer system with hard upstream dependencies on Enemy AI #10, Damage #8, Time Rewind #9, and Stage / Encounter #12. It also consumes Player Movement #6 read-only target data and ADR-0003 process ordering.

### F.1 Upstream Dependencies Consumed by Boss Pattern

| # | System / Source | Type | Hardness | Boss Pattern consumes | Contract Status | Forbidden Coupling |
|---|---|---|---|---|---|---|
| **#10** | [Enemy AI Base + Archetypes](enemy-ai.md) | System | **Hard host** | EnemyBase-compatible STRIDER host, priority 10, deterministic target read pattern, no RigidBody2D branch | Approved · RR1 PASS | Forking EnemyBase or implementing hidden boss-only movement clock. |
| **#8** | [Damage / Hit Detection](damage.md) | System | **Hard signal/component** | Boss HurtBox L6, boss projectile HitBox L4, phase-hit transition procedure, `projectile_boss` cause, `boss_*` signals | LOCKED for prototype | New HP signal, HP bar data, direct player lethal logic. |
| **#9** | [Time Rewind System](time-rewind.md) | System | **Hard token economy** | `boss_killed` token grant contract, rewind-immunity of boss phase transitions, same-tick consume/grant invariant | Approved | Direct TRC calls; boss rewind state snapshots. |
| **#12** | [Stage / Encounter System](stage-encounter.md) | System | **Hard authoring** | STRIDER placement, arena bounds, target reference, final gate start metadata, Area2D preflight | Approved | Boss self-spawning, boss opening gates, scene swaps. |
| **#6** | [Player Movement](player-movement.md) | System | **Hard read-only** | `target_player.global_position` and `velocity` for aim reads | Approved | Mutating player state, knockback, or SM calls. |
| **ADR-0003** | [Determinism Strategy](../../docs/architecture/adr-0003-determinism-strategy.md) | Architecture | **Hard** | CharacterBody2D host, Area2D projectiles, `process_physics_priority` ladder, physics-frame clock | Accepted / used by approved GDDs | RigidBody2D gameplay boss, wall-clock pattern timers. |

### F.2 Downstream Systems Depending on Boss Pattern

| # | System | Dependency | What Boss Pattern provides | Current Status | Notes / Obligation |
|---|---|---|---|---|---|
| **#13** | HUD System | **Hard for boss UI** | `boss_phase_advanced` interpretation, no-HP-bar constraint, phase notification semantics | Approved 2026-05-13 | HUD shows phase/presence pulse only; no hit counter or HP bar. |
| **#14** | [VFX / Particle System](vfx-particle.md) | **Hard for boss readability** | Telegraph events, phase visual tags (`sealed_core` / `split_shell` / `exposed_core`), boss impact/death hooks | Approved 2026-05-13 | VFX preserves hit readability and phase clarity without exposing HP or remaining hits. |
| **#4** | [Audio System](audio.md) | **Soft / presentation** | Boss telegraph/commit hooks; already consumes `boss_killed` through Damage | Approved | Tier 1 audio can remain stub-level. |
| **#3** | [Camera System](camera.md) | **Indirect / presentation** | Boss uses existing `boss_killed` shake; no Tier 1 zoom requirement | Approved | Tier 1 boss does not require camera zoom. |
| **#2** | [Scene / Stage Manager](scene-manager.md) | **Indirect hard** | `boss_killed` terminal event enables stage clear through Damage signal contract | Approved | Boss does not call SM APIs. |

### F.3 Bidirectional Mirror Status

| Source / Target | Mirror Status | Required Follow-up |
|---|---|---|
| `systems-index.md` | Row #11 now links this GDD and lists Enemy AI, Damage, Time Rewind, and Stage | Keep row concise; do not list every presentation consumer. |
| `stage-encounter.md` | Stage final-gate handoff and STRIDER arena question resolved by this GDD | Re-check after Boss Pattern design review. |
| `enemy-ai.md` | STRIDER EnemyBase host contract mirrored by this GDD | Re-check after Boss Pattern design review. |
| `damage.md` | Boss phase table, boss projectile cause, and boss signal obligations mirrored by this GDD | No Damage status change; still LOCKED. |
| `time-rewind.md` | `boss_killed` token grant and phase rewind-immunity mirrored by this GDD | Re-check after Boss Pattern design review. |
| `hud.md` | Approved 2026-05-13 | Mirrors no-HP-bar and phase notification contract. |
| `vfx-particle.md` | Approved 2026-05-13 | Mirrors telegraph/phase/death visual requirements, resolves phase shell tags, and keeps final art specifics for asset-spec. |

### F.4 Data Interfaces

| Data | Owner | Reader | Mutability | Notes |
|---|---|---|---|---|
| `boss_id` | Boss Pattern | Damage, Time Rewind, Scene Manager, Audio, Camera, HUD/VFX | Immutable per boss instance | Tier 1: `&"strider_tier1"`. |
| `phase_hp_table` | Boss Pattern | Boss host / Damage-compatible procedure | Immutable after validation | Tier 1: `[3, 4, 5]`. |
| `phase_index` | Boss host | Boss Pattern, Damage signals, HUD/VFX | Mutates only via Damage-compatible hit procedure | No direct UI hit count. |
| `phase_hits_remaining` | Boss host | Boss host only | Mutates only on boss HurtBox hit | Not exposed to HUD/VFX/Audio. |
| `BossStartSpec` | Stage #12 + Boss Pattern | Boss Pattern | Immutable after activation | Stage supplies placement/arena; Boss validates. |
| `target_player.global_position` | Player Movement #6 | Boss Pattern | Read-only | Read during priority-10 physics tick. |
| `HitBox.cause` | Boss Pattern at projectile instantiation; taxonomy owned by Damage #8 | Damage #8 | Immutable per projectile | Always `&"projectile_boss"` for Tier 1 boss projectiles. |
| `process_physics_priority` | ADR-0003 / EnemyBase | Godot scheduler | Constant | Boss host = 10; boss projectiles = 20. |

### F.5 Dependency Hardness Summary

| Hardness | Dependencies | Meaning |
|---|---|---|
| **Hard runtime** | Enemy AI #10, Damage #8, Time Rewind #9, Stage #12, Player Movement #6, ADR-0003 | Boss Pattern cannot satisfy Tier 1 gameplay without these contracts. |
| **Hard downstream** | HUD #13, VFX #14 | Not required for logic tests, but required before production presentation proof. |
| **Soft presentation** | Audio #4, Camera #3 | Existing boss-killed hooks are enough for Tier 1 stubs; richer cues can arrive later. |
| **Negative dependency** | Scene Manager direct API, TRC direct API, Player Shooting internals, rewind signals | Boss Pattern intentionally does not call or subscribe to these in Tier 1. |

---

## G. Tuning Knobs

### G.1 Authoring Knob Table

| Knob | Type | Default | Safe Range | Source / Formula | Too Low | Too High |
|---|---|---:|---:|---|---|---|
| `phase_hp_table` | `Array[int]` | `[3,4,5]` | each `1..8`, total `3..24` | D.1 | Boss ends before phase learning | Damage sponge; violates 5-minute slice |
| `intro_frames` | int frames | 90 | `30..150` | C.2 | Boss starts before player reads arena | Delays core loop |
| `phase_entry_lock_frames` | int frames | 30 | `12..60` | C.4.2 | Phase change unreadable | Fight feels paused |
| `eye_lane_shot.telegraph_frames` | int frames | 36 | `24..72` | D.4 | Unfair first read | Too slow, no pressure |
| `dual_lane_burst.telegraph_frames` | int frames | 42 | `30..78` | D.4 | Burst feels random | Phase 1 too easy |
| `staggered_barrage.telegraph_frames` | int frames | 54 | `36..96` | D.4 | Dense phase unfair | Final phase loses tension |
| `boss_projectile_speed_px_s` | float | 480.0 | `320..720` | Projectile spec | Too easy to outrun | Tunneling risk / unreadable |
| `boss_projectile_cap` | int Area2D | 16 | `4..16` Tier 1 | D.5 | Pattern lacks density | Stage Area2D ceiling threatened |
| `boss_warning_area_cap` | int Area2D | 4 | `0..4` Tier 1 | D.5 | Telegraphs rely only on animation | Stage Area2D ceiling threatened |
| `arena_min_size_px` | Vector2 | `960×540` | min `960×540`, recommended `1120×620` | C.1 Rule 14 | Boss attacks have no dodge room | Camera/stage scope grows |

### G.2 Locked Constants, Not Tuning Knobs

- Boss host `process_physics_priority = 10`.
- Boss projectiles `process_physics_priority = 20`.
- Tier 1 boss id: `&"strider_tier1"`.
- Boss projectile cause: `&"projectile_boss"`.
- No production HP bar / hit counter.
- No Tier 1 summons, knockback, or boss self-damage.
- `boss_killed` is single-fire and terminal.

### G.3 Cross-Knob Invariants

1. **Readability invariant**: every attack has `telegraph_frames >= 24`.
2. **5-minute invariant**: total boss hits should stay `<= 24`; Tier 1 default is 12.
3. **Area2D invariant**: `boss_projectile_cap + boss_warning_area_cap + 1 <= 21`.
4. **No-HP-bar invariant**: increasing `phase_hp_table` cannot justify exposing remaining hit count.
5. **Projectile cap invariant**: authored attacks must pass preflight at max cap; runtime skip is forbidden.
6. **Rewind invariant**: tuning any phase timing must not require boss state rollback on player rewind.

### G.4 Tier 1 Preset

| Preset | Purpose | Values |
|---|---|---|
| `strider_tier1_default` | Production Tier 1 mini-boss | `phase_hp_table=[3,4,5]`, `boss_projectile_cap=16`, `arena_min_size=960×540`, no summons, no HP bar |
| `strider_debug_fast` | Developer smoke test only | `phase_hp_table=[1,1,1]`, same attack timing, same signals; cannot satisfy production balance proof |

---

## H. Acceptance Criteria

### H.1 Core Rule Acceptance

| ID | Criterion | Verification Type | Covers |
|---|---|---|---|
| **AC-BOSS-01** | **GIVEN** Stage activates STRIDER with a valid `BossStartSpec`, **WHEN** Boss Pattern enters `INTRO`, **THEN** STRIDER has `boss_id == &"strider_tier1"`, `process_physics_priority == 10`, a valid target reference, and no scene-swap API calls. | Integration | C.1 Rules 1-2 |
| **AC-BOSS-02** | **GIVEN** STRIDER initializes, **WHEN** validation runs, **THEN** `phase_hp_table == [3,4,5]`, `final_phase_index == 2`, and every value is `>= 1`. | Logic | C.1 Rule 4 / D.1 |
| **AC-BOSS-03** | **GIVEN** ECHO projectile hits STRIDER without crossing a phase threshold, **WHEN** the boss HurtBox handler runs, **THEN** exactly one `boss_hit_absorbed(boss_id, phase_index)` emits and no `hits_remaining` value is exposed. | Logic / signal spy | C.1 Rule 3 |
| **AC-BOSS-04** | **GIVEN** ECHO projectile reduces `phase_hits_remaining` to 0 in a non-final phase, **WHEN** Damage-compatible transition runs, **THEN** `boss_pattern_interrupted` emits before `boss_phase_advanced`, `phase_index` increases by exactly 1, and next phase attack scheduling starts only after the advance. | Logic / signal order | C.1 Rules 3, 6 / D.2 |
| **AC-BOSS-05** | **GIVEN** ECHO projectile lands the final hit in phase 2, **WHEN** transition runs, **THEN** `boss_pattern_interrupted` emits before exactly one `boss_killed(boss_id)`, lifecycle becomes `DEFEATED`, and no future attacks schedule. | Logic / integration | C.1 Rule 7 |
| **AC-BOSS-06** | **GIVEN** any boss attack can produce lethal output, **WHEN** attack local frames are stepped, **THEN** no projectile or active HitBox exists before `telegraph_frames` completes. | Logic + visual review | C.1 Rule 5 / D.4 |
| **AC-BOSS-07** | **GIVEN** boss projectile scene instances are spawned, **WHEN** QA inspects them, **THEN** each is an `Area2D` with `process_physics_priority == 20`, HitBox L4→L1 collision, and `HitBox.cause == &"projectile_boss"`. | Logic / collision test | C.1 Rule 8 |
| **AC-BOSS-08** | **GIVEN** authored boss attack specs, **WHEN** preflight computes max live boss projectiles and warning areas, **THEN** boss contribution is `<= 21` Area2Ds and Stage #12 can include it in the room total. | Logic / preflight | C.1 Rule 9 / D.5 |
| **AC-BOSS-09** | **GIVEN** ECHO rewinds after `boss_phase_advanced`, **WHEN** ECHO returns to a prior position, **THEN** STRIDER remains in the advanced phase and no boss phase/state rollback occurs. | Integration | C.1 Rule 10 / E.12 |
| **AC-BOSS-10** | **GIVEN** `boss_killed` fires, **WHEN** Time Rewind #9 handles the signal, **THEN** token grant occurs only through TRC subscription and Boss Pattern performs no direct TRC calls. | Integration / static scan | C.1 Rule 11 / D.6 |
| **AC-BOSS-11** | **GIVEN** a phase pattern loops for 1000 cycles with fixed start frame, **WHEN** attack selection is recorded, **THEN** the attack id sequence is identical across runs and contains no random branch. | Determinism | C.1 Rule 12 / D.3 |
| **AC-BOSS-12** | **GIVEN** Tier 1 content is inspected, **WHEN** static validation runs, **THEN** no boss summons, player knockback, boss self-damage layer, HP bar, death-count scaling, or wall-clock gameplay timer appears. | Static review | C.1 Rules 13-14 / E.14-E.18 |

### H.2 Formula Acceptance

| ID | Criterion | Verification Type | Covers |
|---|---|---|---|
| **AC-BOSS-13** | **GIVEN** `phase_hp_table=[3,4,5]`, **WHEN** total hits are summed, **THEN** `total_boss_hits == 12`. | Logic | D.1 |
| **AC-BOSS-14** | **GIVEN** `phase_hp_table=[2,1,5]`, `phase_index=0`, `phase_hits_remaining=2`, and 3 same-frame hits, **WHEN** the Damage-compatible transition lock runs, **THEN** `boss_phase_advanced` emits exactly once and `phase_index == 1`. | Logic / regression | D.2 / Damage AC-14 mirror |
| **AC-BOSS-15** | **GIVEN** fixed `phase_enter_frame` and current physics frame, **WHEN** D.3 computes attack slot, **THEN** the same attack id and local frame are returned across repeated runs. | Logic | D.3 |
| **AC-BOSS-16** | **GIVEN** every `BossAttackSpec`, **WHEN** D.4 validates timing, **THEN** `attack_total_frames == telegraph + active + recovery` and lethal output first frame is `>= telegraph_frames`. | Logic | D.4 |
| **AC-BOSS-17** | **GIVEN** boss caps `1 + 16 + 4`, **WHEN** D.5 computes `boss_area2d_declared`, **THEN** the result is exactly 21. | Logic | D.5 |
| **AC-BOSS-18** | **GIVEN** `boss_killed` and `player_hit_lethal` are injected in the same physics tick with boss priority 10, **WHEN** Time Rewind #9 AC-B5 harness runs, **THEN** consume-before-grant order and final token count match Time Rewind spec. | Integration | D.6 / TR AC-B5 |

### H.3 Edge Case Acceptance

| ID | Criterion | Verification Type | Covers |
|---|---|---|---|
| **AC-BOSS-19** | **GIVEN** `target_player == null`, **WHEN** activation starts, **THEN** Boss Pattern fails preflight and emits no attacks. | Logic | E.1 |
| **AC-BOSS-20** | **GIVEN** arena size below `960×540`, **WHEN** preflight validates `BossStartSpec`, **THEN** Boss Pattern refuses to arm and names `arena_too_small`. | Logic / content validation | E.2 |
| **AC-BOSS-21** | **GIVEN** an attack wind-up is interrupted before commit, **WHEN** `boss_pattern_interrupted` fires, **THEN** no projectile from that attack is spawned. | Logic | E.5 |
| **AC-BOSS-22** | **GIVEN** projectiles were emitted before a phase transition, **WHEN** `boss_phase_advanced` fires, **THEN** already-emitted projectiles continue until collision or lifetime expiry. | Integration | E.6 |
| **AC-BOSS-23** | **GIVEN** boss enters `DEFEATED`, **WHEN** additional HurtBox overlaps occur before queue_free, **THEN** no extra `boss_killed`, `boss_phase_advanced`, or `boss_hit_absorbed` signals emit. | Logic / signal spy | E.9 |
| **AC-BOSS-24** | **GIVEN** HUD requests boss remaining hits, **WHEN** interface review runs, **THEN** Boss Pattern exposes no `hits_remaining` signal/property to HUD. | Architecture review | E.17 |

### H.4 First QA Pass Order

1. **Preflight and structure**: AC-BOSS-01, AC-BOSS-02, AC-BOSS-08, AC-BOSS-19, AC-BOSS-20.
2. **Damage signal contract**: AC-BOSS-03, AC-BOSS-04, AC-BOSS-05, AC-BOSS-14, AC-BOSS-23.
3. **Pattern determinism and telegraphs**: AC-BOSS-06, AC-BOSS-11, AC-BOSS-15, AC-BOSS-16, AC-BOSS-21, AC-BOSS-22.
4. **Cross-system behavior**: AC-BOSS-07, AC-BOSS-09, AC-BOSS-10, AC-BOSS-18, AC-BOSS-24.
5. **Static scope guard**: AC-BOSS-12.

---

## Visual/Audio Requirements

### VA.1 Boss Readability

| Event | Visual Requirement | Audio Requirement | Notes |
|---|---|---|---|
| Boss intro | STRIDER silhouette drops/locks into arena; no lethal output during `intro_frames` | Low mechanical lock cue | Must not delay first playable dodge beyond Pillar 4 expectations. |
| Attack telegraph | Eye sweep, muzzle glow, lane warning, or floor warning visible for full telegraph window | Short warning cue; not louder than rewind-denied/death cues | Telegraph is gameplay-critical, not cosmetic. |
| Attack commit | One distinct flash/frame pose on commit | Click/servo snap | Helps player learn "now it is real." |
| Phase advance | Shell layer tears/open; phase color or stance changes | Rising break cue | No HP text required. |
| Boss hit absorbed | Small impact spark at boss HurtBox | Metallic tick | Must not expose remaining hit count. |
| Boss killed | Large collage tear / shutdown burst | Uses Audio #4 `sfx_boss_defeated_sting_01.ogg`; Camera #3 uses 10 px / 18 frame shake | Boss Pattern only triggers through `boss_killed`. |

### VA.2 Tier 1 Camera Policy

Tier 1 Boss Pattern does **not** require camera zoom. Camera #3 remains at `zoom = Vector2(1.0, 1.0)` and responds to `boss_killed` through its already-approved shake event. Tier 2 may revisit zoom-out / push-in via Camera OQ-CAM-3/OQ-CAM-4, but no Tier 1 acceptance criterion depends on it.

### VA.3 Projectile and Telegraph Language

- Boss projectiles use `projectile_boss` cause and must be visually distinct from ECHO bullets and standard enemy bullets.
- Telegraph warning colors should preserve ECHO readability against collage backgrounds.
- Dense Phase 2 barrage must remain countable enough for a 0.2-second glance at gameplay speed.

### VA.4 Asset and Implementation Handoff

| Asset Class | Tier 1 Need | Owner |
|---|---|---|
| STRIDER base sprite/silhouette | Large inverted-triangle / rail-legged boss host | Art/VFX |
| Phase shell variants | 3 phase-readable visual states | Art/VFX |
| Boss projectile | hostile, larger/intense but not ECHO-colored | VFX |
| Telegraph warning areas | lane/floor readable overlays | VFX |
| Boss defeat burst | collage tear/shutdown | VFX + Audio |

---

## UI Requirements

Boss Pattern has no direct UI widget in Tier 1. HUD #13 may consume `boss_phase_advanced` and `boss_killed` for:

- a boss presence frame or title flash;
- phase-transition pulse;
- token-replenishment feedback after `boss_killed`.

Boss Pattern explicitly forbids:

- boss HP bar;
- remaining-hit counter;
- damage number popup;
- UI text that reveals `phase_hp_table`.

Debug builds may show `phase_index`, `phase_hits_remaining`, and current `attack_id` in a developer overlay only. Debug overlay output must be disabled in production.

---

## Open Questions

The Tier 1 Boss Pattern contract is complete enough for design review. These questions are deferred to downstream presentation systems or Tier 2 scope decisions.

| # | Question | Owner | Target | Blocking? | Notes |
|---|---|---|---|---|---|
| OQ-BOSS-1 | **RESOLVED 2026-05-13 by `vfx-particle.md`** — STRIDER phase readability uses `sealed_core`, `split_shell`, and `exposed_core` shell/stance tags with phase-entry tear bursts and no HP/hit-count rendering. | art-director + VFX designer | Closed for design contract; final sprite execution moves to asset-spec | No for logic; yes for production art | VFX #14 defines behavior/readability tags; exact shell art remains `/asset-spec system:vfx-particle` / boss asset-spec. |
| OQ-BOSS-2 | RESOLVED 2026-05-13 — HUD #13 may show boss title/phase pulse or presence flash; all numeric phase/hit feedback remains hidden. | UX designer + game-designer | Closed by `design/gdd/hud.md` approval | Closed | HP bar remains forbidden either way. |
| OQ-BOSS-3 | Should boss-specific BGM/ducking exist in Tier 1 or remain Audio #4 stub-only? | audio-director | Audio polish pass | No | Audio #4 currently supports boss-killed sting only. |
| OQ-BOSS-4 | Should Tier 2 introduce boss arena camera zoom or letterbox? | camera designer + art-director | Tier 2 gate / Camera OQ-CAM-3 | No | Tier 1 explicitly does not require zoom. |
| OQ-BOSS-5 | Should future bosses support summons or self-damage phases? | game-designer + systems-designer | Tier 2+ boss expansion | No | Requires reopening Stage, Enemy AI, Damage, and Area2D budgets. |

### Deferred Follow-Up Actions

1. Run `/design-review design/gdd/boss-pattern.md --depth lean` in a fresh session.
2. Re-check reciprocal mirrors only if future Boss Pattern revisions change Boss/Damage/Stage/Time-Rewind wording.
3. HUD #13 is already approved and consumes this GDD as a no-HP-bar boss phase display contract.
4. Use this GDD plus `vfx-particle.md` as input to asset-spec so telegraphs and phase changes are readable before implementation stories.
