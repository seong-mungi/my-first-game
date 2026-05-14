# Player Movement

> **Status**: Approved (re-review APPROVED 2026-05-11 lean mode — all 10 prior BLOCKING resolved; see A.1 Locked Decisions B1-B10 rows)
> **Author**: user + game-designer + godot-gdscript-specialist + systems-designer (planned consultations)
> **Created**: 2026-05-10
> **Last Updated**: 2026-05-11
> **Implements Pillar**: Pillar 2 (Deterministic Patterns) primary; Pillar 1 (Time Rewind = Learning Tool) via clean `restore_from_snapshot()` single-writer; Pillar 5 (Shippable First) via 6-state Tier 1 floor (DEC-PM-1).
> **Engine**: Godot 4.6 / GDScript / 2D / `CharacterBody2D`
> **System #**: 6 (Core / Gameplay)
> **Tier 1 State Count**: 6 (idle / run / jump / fall / aim_lock / dead) — locked 2026-05-10 (revised post-advisor 2026-05-10: `hit_stun` removed per damage.md DEC-3 binary lethal model — no non-lethal damage trigger exists in Tier 1)

---

## Locked Scope Decisions

> *Decisions locked during authoring. Each line is permanent unless explicitly amended via Round 5 cross-doc-contradiction exception. Re-discussion not needed in fresh sessions.*

- **DEC-PM-1** (2026-05-10): Tier 1 PlayerMovementSM = **6 states** (`idle / run / jump / fall / aim_lock / dead`). `hit_stun` removed per damage.md DEC-3 (binary 1-hit lethal — no non-lethal damage trigger). `dash`, `double_jump`, `wall_grip` deferred to Tier 2 evaluation (Pillar 5 Small Wins). Reconsideration trigger: introduction of any non-lethal damage source in Damage GDD or knockback mechanic in Boss Pattern GDD.
- **DEC-PM-2** (2026-05-10): `aim_lock` semantics = **hold-button** (Cuphead-style lock-aim). Separate input action `aim_lock`. While button held: ECHO stops + free 8-way aim + facing_direction updated; on button release: immediate return to idle/run. `shoot` input does *not* freeze movement and is independent of aim_lock (preserves game-concept "jump + shoot simultaneously"). Input System #1 GDD has final obligation to confirm `aim_lock` action naming.
- **DEC-PM-3 v2** (2026-05-11 — supersedes 2026-05-10 "resume with live ammo" per fresh-session `/design-review` B5 Pillar 1 contradiction): Time Rewind restore ammo policy = **PlayerSnapshot captures `ammo_count: int` (8th PM-exposed field) per-tick**. When `restore_from_snapshot(snap)` is called, ECHO's ammo is restored to the value 9 frames prior (at `restore_idx`) — Pillar 1 ("learning tool, not punishment") single-source contract. Even if ammo dropped to 0 within the DYING window, after restore ammo recovers to the value 9 frames prior. `time-rewind.md` OQ-1 / E-22 / F6 all resolved as (b) variant. **ADR-0002 Amendment 2 obligatory** — schema 7→8 PM-exposed fields (Resource total 9 fields: 8 PM-exposed + 1 TRC-internal `captured_at_physics_frame`). Player Shooting #7 GDD owns ammo semantics + write authority (sub-decision: OQ-PM-NEW per advisor guidance — TRC orchestration vs Weapon parallel restoration; PM maintains `PM.restore_from_snapshot(snap)` signature and ignores `snap.ammo_count` — write authority belongs to Weapon).
- **DEC-PM-3 v1** *(superseded 2026-05-11)*: ~~Time Rewind restore ammo policy = "resume with live ammo" (PlayerSnapshot does not capture ammo). ADR-0002 amendment not required.~~ — Reason for deprecation: if rewind restores to a 0-ammo state it creates a Pillar 1 contradiction (rewind = punishment, not learning tool). Raised by fresh-session `/design-review` (2026-05-11) B5 before Player Shooting #7 GDD authoring.

---

## A. Overview

Player Movement is the core gameplay system that hosts ECHO's *2D side-scrolling movement · shooting stance · post-death restoration* under a single owner (`PlayerMovement extends CharacterBody2D`). The system is the single source for two aspects: (1) **Movement layer** — run · jump · fall control responsiveness, `facing_direction` for 8-way shooting, movement-freeze + free 8-way aim during `aim_lock` (DEC-PM-2 hold-button semantics), and the Tier 1 **6 states** hosted by PlayerMovementSM (`idle / run / jump / fall / aim_lock / dead`; DEC-PM-1) — responsible for the *responsiveness aspect* of Pillar 1 "1-hit instant death → 1-second recovery catharsis". (2) **Data layer** — the 8-field PM-exposed `PlayerSnapshot` schema read by Time Rewind (#9) every `_physics_process` tick (`global_position` · `velocity` · `facing_direction` · `animation_name` · `animation_time` · `current_weapon_id` · `is_grounded` PM-owned 7 fields + `ammo_count: int` Weapon-owned 1 field; ADR-0001 + ADR-0002 Amendment 2 locked-in 2026-05-11; Resource total 9 fields = 8 PM-exposed + 1 TRC-internal `captured_at_physics_frame`) + at death/rewind time only `restore_from_snapshot(snap: PlayerSnapshot) -> void` *single path* write allowed (enforcement site for forbidden_pattern `direct_player_state_write_during_rewind`). Determinism (Pillar 2) is guaranteed by ADR-0003's `CharacterBody2D` + direct transform + `process_physics_priority = 0` policy — bypassing the solver means direct field assignment in `restore_from_snapshot()` is the *authoritative* state for the next tick. Not a Foundation system, but carries triple hosting responsibility: ECHO HurtBox (#8 child node — per DEC-4 the `monitorable` toggle is SM's responsibility while this GDD only handles node *hosting*), WeaponSlot (#7), and position data read by enemies/bosses as chase target (#10/#11). This GDD owns movement mechanic design, and correctness of the restore procedure is maintained as single source through bidirectional consistency obligations with time-rewind.md C.3-C.4 + ADR-0001/0002/0003.

---

## B. Player Fantasy

### B.1 Core Fantasy — The Body Remembers

> "VEIL knows where my body will be *next*. I return to where my body *was*."

Echo's PlayerMovement is not *the character seen by the camera* but *the inertia felt at the fingertips*. Every movement decision hosted by this system — the run acceleration curve, jump angle, air control coefficient, the freeze+free 8-way aim during `aim_lock` (DEC-PM-2), and re-entry at the moment of death/rewind — is a definition of *what the player's body remembers within the screen*. No other game makes *the kinematic body itself returning to a previous state* the core fantasy. PlayerMovement is the *manifestation surface* of time rewind, and that single moment when ECHO's body *re-enters* its own self from 0.15 seconds ago delivers Pillar 1 ("time rewind is a learning tool, not punishment") *to the player's fingertips*.

### B.2 Anchored Player Moment — 9-Frame Recovery

*The very frame* the boss's spread barrage tears through ECHO's chest — the player presses the left trigger (`rewind_consume`). The screen tears in cyan-magenta, and the self from 0.15 seconds (9 frames) ago *returns into their own body*. If they were mid-jump, they return to mid-jump height; if they were aiming left, they return aiming left as-is (`PlayerSnapshot.facing_direction` restored). Input does not break — the very moment the same left trigger is released, new input *continues seamlessly* (protected for 30 i-frames + DEC-6 hazard grace 12 frames). *Re-running* those 9 frames, the player sees the same barrage again. This time they *know it* — this *re-experience* is the single kinematic representation of pattern learning.

### B.3 Reference Lineage

| Game | What was borrowed | How Echo differs |
|---|---|---|
| **Celeste** (2018) | Madeline's jump weight — 1:1 precision of input reaching the body every frame | Celeste *resets the scene* after death; Echo *resets the body, world preserved* |
| **Katana Zero** (2019) | Time mechanic + 1-hit + instant restart solo standard | Katana Zero's Will *re-runs a simulation after foresight*; Echo *re-enters the body after memory* (ex-post vs ex-ante) |
| **Hotline Miami** (2012) | Instant restart + deterministic patterns + "unfair" avoidance | HM is top-down *scene reset*; Echo is side-scroll *continuous body* (input never breaks) |
| **Contra** (1987-2024) | Side-scroll + 8-way shooting + 1-hit lethal kinematic template | Contra's jump allows slight momentum jitter; Echo has 0 jitter (Pillar 2 + ADR-0003) |

### B.4 The Pillar 1 Bridge — Two Non-Negotiables

Delivering Pillar 1 to the fingertips depends on *accuracy of the restore procedure*. The following two items are non-negotiable:

1. **Body continuity** — Input does not break immediately after `restore_from_snapshot()`. The token-consuming input (`rewind_consume`) is not itself the *last input*; starting from the next `_physics_process` tick, new input sequences are accepted immediately. Input queue reset is forbidden.
2. **Visibility of re-entry** — Within the collage-tone screen, it must be visually and sensorially identifiable that the body from *9 frames prior* has been reconstructed at exactly that position · facing · animation time. Forced immediate evaluation via `AnimationPlayer.seek(animation_time, true)` is the single source (time-rewind.md I4).

### B.5 Anti-Fantasy

| Anti-Fantasy | Why Movement is *not that* | Guarantee mechanism |
|---|---|---|
| **Feels good but breaks determinism** (Contra-style momentum jitter) | Pillar 2 violation — same input different result is unlearnable | ADR-0003 `CharacterBody2D` + direct transform; `process_physics_priority = 0` |
| **Heavy movement as signature** (Blasphemous intentional sluggishness) | Pillar 4 5-minute rule violation — delays reaching the core loop | Input→velocity mapping 1-frame latency limit (D.1) |
| **dash · double_jump · wall_grip · hit_stun in Tier 1** | Pillar 5 Shippable First violation — DEC-PM-1 6-state lock-in (2026-05-10) | C.2 machine has Tier 1 6 states only; `hit_stun` has no trigger due to damage.md DEC-3 binary lethal (Tier 2+); dash/double_jump/wall_grip expansion is Tier 2 gate |
| **Input *wait* forced after death** (recalls Contra restart wait) | Pillar 1 dismantled — "punishment" revived | Input accepted immediately after `restore_from_snapshot()` (B.4 item 1) |
| **360° control in air** (modern platformer trend) | Dilutes deterministic pattern learning value — if everything adjustable in air, jump timing learning is meaningless | Air control coefficient < 1.0 (D.1) |

### B.6 Pillar Service Matrix

| Design Decision | Pillar 1 Learning Tool | Pillar 2 Determinism | Pillar 5 Small Wins |
|---|---|---|---|
| 6-state Tier 1 lock-in (DEC-PM-1; hit_stun removed) | — | direct | **primary** |
| `restore_from_snapshot()` single path | **primary** | direct | — |
| `_is_restoring` flag + anim method-track guard | direct | **primary** | — |
| Air control coefficient < 1.0 | direct | direct | — |
| `CharacterBody2D` + direct transform | direct | **primary** | direct |
| 8-way shooting + jump simultaneously | direct | — | direct |

---

## C. Detailed Design

### C.1 Node Structure & Class Definition

#### C.1.1 Class hierarchy

`PlayerMovement` is the ECHO root node — a `CharacterBody2D` instance with `class_name PlayerMovement extends CharacterBody2D` script attached. It single-hosts both the Tier 1 movement layer (run / jump / fall / aim_lock — 6 movement states) and the 8-field PM-exposed PlayerSnapshot data layer (PM-owned 7 + Weapon-owned 1 `ammo_count` per ADR-0002 Amendment 2) simultaneously.

`process_physics_priority = 0` (ADR-0003 ladder: PM = 0, TimeRewindController = 1, enemies = 10). **Property location**: Set in the `.tscn` root node Inspector — *not* script-only (risk of omission when authoring scene).

#### C.1.2 Node Tree (.tscn — single source)

```
PlayerMovement (CharacterBody2D, process_physics_priority=0)
  [script: player_movement.gd / class_name PlayerMovement]
├── EchoLifecycleSM (Node)
│     [class_name EchoLifecycleSM extends StateMachine — state-machine.md C.2.1]
│   ├── AliveState     (Node — class_name AliveState extends State)
│   ├── DyingState     (Node)
│   ├── RewindingState (Node)
│   └── DeadState      (Node)
├── PlayerMovementSM (Node)
│     [class_name PlayerMovementSM extends StateMachine — state-machine.md M2 reuse]
│   ├── IdleState      (State)
│   ├── RunState       (State)
│   ├── JumpState      (State)
│   ├── FallState      (State)
│   ├── AimLockState   (State)
│   └── DeadState      (State — reactive to EchoLifecycleSM.DYING; NOT parallel ownership)
├── HurtBox            (Area2D — class_name HurtBox, damage.md C.1.1)
├── HitBox             (Area2D — class_name HitBox, damage.md C.1.1)
├── Damage             (Node   — class_name Damage, damage.md C.1; owns HurtBox/HitBox signal wiring)
├── WeaponSlot         (Node2D — Player Shooting #7 (provisional))
├── AnimationPlayer
└── Sprite2D
```

`EchoLifecycleSM` and `PlayerMovementSM` are **flat composition** — neither contains the other. `PlayerMovementSM.DeadState` enters *reactively* on DYING/DEAD values of the `EchoLifecycleSM.state_changed` signal (signal-reactive, NOT polled — C.6 wiring spec). This tree is the **single source** for the ECHO root node model, and state-machine.md C.2.1 lines 178-188 align to this GDD in F.4 Bidirectional Update (Round 5 cross-doc-contradiction exception — `PlayerMovement extends CharacterBody2D` model locked in A.Overview is authoritative).

#### C.1.3 8-Field PM-Exposed PlayerSnapshot Source Table (PlayerMovement + Weapon co-write; ADR-0002 Amendment 2 locked-in 2026-05-11)

> **Terminology** (per DEC-PM-3 v2): **PM-exposed 8 fields** (PlayerMovement single-writer 7 + Weapon single-writer 1 `ammo_count`) + **TRC-internal 1 field** (`captured_at_physics_frame`, Amendment 1) = **PlayerSnapshot Resource total 9 fields**. AC-H1-01 round-trip identity check targets the 8 PM-exposed fields.

| Field | Type | Source | Write site (single path) | Owner |
|---|---|---|---|---|
| `global_position` | Vector2 | CharacterBody2D inherited | `move_and_slide()` result (Phase 5) OR `restore_from_snapshot()` | PM |
| `velocity` | Vector2 | CharacterBody2D inherited | per-tick velocity calculation (Phase 4) OR `restore_from_snapshot()` | PM |
| `facing_direction` | int | PlayerMovement new `var facing_direction: int` | per-tick (Phase 6c) OR `restore_from_snapshot()` | PM |
| `current_animation_name` | StringName | `_anim.current_animation` proxy (read-only property) | `AnimationPlayer.play()` (auto-updated) | PM |
| `current_animation_time` | float | `_anim.current_animation_position` proxy (read-only property) | AnimationPlayer itself (auto-updated) | PM |
| `current_weapon_id` | int | PlayerMovement new `_current_weapon_id` member | WeaponSlot `weapon_equipped` signal handler OR `restore_from_snapshot()` | PM |
| `is_grounded` | bool | PlayerMovement new `_is_grounded` member (cached) | `is_on_floor()` result (Phase 6a, post-`move_and_slide()`) OR `restore_from_snapshot()` | PM |
| `ammo_count` | int | **WeaponSlot** (Player Shooting #7 — Tier 1 provisional) | WeaponSlot per-tick OR Weapon-side restoration trigger (OQ-PM-NEW); **PM ignores `snap.ammo_count` in `restore_from_snapshot(snap)`** — write authority owned by Weapon | **Weapon (#7)** |

> **TRC capture additional meta (not exposed by PM/Weapon)**: TRC separately records the 9th field `captured_at_physics_frame: int` in the ring buffer slot (ADR-0002 Amendment 1). Neither PlayerMovement nor WeaponSlot exposes this field; TRC directly reads `Engine.get_physics_frames()` at `_capture_to_ring()` time.

**Single-writer policy** (forbidden_pattern `direct_player_state_write_during_rewind` PM enforce site):

- The 7 PM-owned fields above cannot be directly written by any external system outside PlayerMovement's per-tick update path and `restore_from_snapshot()`. `ammo_count` has a separate single-writer (Weapon #7) — PM enforce site does not apply.
- During a `restore_from_snapshot()` call, the `_is_restoring: bool = true` flag guards all cascade write paths (anim method-track handlers / WeaponSlot signal handler / external emits) — see C.4 for details.
- This policy applies **only to PlayerMovement's own 7 fields**. The self-owned members of hosted child nodes (e.g., `HurtBox.monitorable`) have each owning GDD as single source — `HurtBox.monitorable` is owned by `EchoLifecycleSM.RewindingState.enter()/exit()` (damage.md DEC-4).

#### C.1.4 Child Node GDD Ownership Separation Table

| Child node | Class | Hosting GDD owner | PlayerMovement role |
|---|---|---|---|
| `EchoLifecycleSM` | `extends StateMachine` | state-machine.md (framework) + time-rewind.md (4-state behavior definition) | parent node provision only |
| `PlayerMovementSM` | `extends StateMachine` | **this GDD** (C.2 6-state matrix) | parent + behavior definition |
| `HurtBox` | `extends Area2D` | damage.md C.1.1 | node instance hosting only; `monitorable` write *forbidden* (DEC-4) |
| `HitBox` | `extends Area2D` | damage.md C.1.1 | node instance hosting only |
| `Damage` | `extends Node` (script) | damage.md C.1 | node instance hosting only; owns its own wiring |
| `WeaponSlot` | `extends Node2D` | Player Shooting #7 *(provisional)* | node instance hosting + caches `current_weapon_id` only (signal subscription) |
| `AnimationPlayer` | Godot built-in | — | per-tick `current_animation_name/_time` proxy; on restore: `play()` + `seek(time, true)` |
| `Sprite2D` | Godot built-in | — (art pipeline) | facing_direction visualization (flip_h vs left/right anim branching — Visual/Audio section decision) |

### C.2 Movement States and Transitions (PlayerMovementSM)

#### C.2.1 6-State Definitions

DEC-PM-1 locked-in 6 states. Each state is its own class `extends State` and reuses the framework state-machine.md pattern (M2 reuse verification case — state-machine.md AC-23).

| State | class_name | Entry condition (summary) | Primary behavior |
|---|---|---|---|
| Idle | IdleState | default start + stopped + grounded | `velocity.x → 0` (decel ramp), `facing_direction` maintained |
| Run | RunState | `move_axis.x ≠ 0` + grounded | `velocity.x` ramp to ±run_top_speed; **facing_direction = 8-way composite (sign(move_axis.x), sign(move_axis.y))** |
| Jump | JumpState | jump (edge) + (grounded OR coyote) | `velocity.y = −jump_velocity_initial`; `gravity_rising` applied; **facing_direction = 8-way composite** continually updated |
| Fall | FallState | `velocity.y ≥ 0` (apex) OR jump released early (variable cut) OR floor lost | `gravity_falling`; `air_control_coefficient < 1.0`; **facing_direction = 8-way composite** continually updated |
| AimLock | AimLockState | aim_lock pressed (hold) + **grounded only** (OQ-1 lock) | `velocity = Vector2.ZERO`; **facing_direction = 8-way input (full move_axis)** |
| Dead | DeadState | `EchoLifecycleSM.state_changed` → DYING OR DEAD (signal-reactive single path) | `velocity = Vector2.ZERO`; input ignored; anim "dead" |

#### C.2.2 Transition matrix (exhaustive)

> **Variable jump (OQ-4 lock — Celeste cut)**: If `velocity.y < 0` (still rising) at the moment jump input is *released*, apply `velocity.y = max(velocity.y, -jump_cut_velocity)` then transition to Fall.

> **facing_direction (OQ-2 lock — Composite 8-way)**: Even outside aim_lock, `move_axis.y` is *used* for `facing_direction` 8-way update (no effect on movement). So during Run/Jump/Fall, ECHO can run or jump left/right while aiming up/down — preserves B.6 "8-way shooting + jump simultaneously" fantasy.

| # | From | Trigger | Condition | To | Side effects |
|---|---|---|---|---|---|
| T1 | Idle | `move_axis.x ≠ 0` | grounded | Run | `facing_direction` updated |
| T2 | Run | `move_axis.x = 0` | grounded | Idle | velocity.x decel ramp |
| T3 | Idle/Run | jump (edge) | grounded OR `coyote_frames > 0` | Jump | `velocity.y = −jump_velocity_initial`; coyote / jump_buffer cleared |
| T4 | Idle/Run | aim_lock pressed (hold) | **grounded only** | AimLock | `velocity = Vector2.ZERO` |
| T5 | Idle/Run | `is_on_floor() = false` | — | Fall | gravity_falling; `_last_grounded_frame` locked (coyote start) |
| T6 | Jump | `velocity.y ≥ 0` | — | Fall | gravity_falling applied |
| T7 | Jump | jump released (edge) | `velocity.y < 0` (still rising) | Fall | `velocity.y = max(velocity.y, -jump_cut_velocity)`; gravity_falling applied |
| T8 | Fall | `is_on_floor() = true` | `move_axis.x = 0` | Idle | velocity.y = 0; landing anim |
| T9 | Fall | `is_on_floor() = true` | `move_axis.x ≠ 0` | Run | velocity.y = 0; facing_direction updated |
| T10 | AimLock | aim_lock released (edge) | `move_axis.x = 0` | Idle | velocity unfreeze (= 0); input normal return |
| T11 | AimLock | aim_lock released (edge) | `move_axis.x ≠ 0` | Run | velocity unfreeze; facing_direction updated |
| T12 | AimLock | `is_on_floor() = false` (platform lost) | — | Fall | aim_lock auto-released (regardless of input hold); gravity_falling |
| T13 | (Idle/Run/Jump/Fall/AimLock) | `EchoLifecycleSM.state_changed` (val=DYING OR DEAD) | signal-reactive | Dead | velocity = Vector2.ZERO; anim "dead" |
| T14 | Dead | `restore_from_snapshot(snap)` | `snap.is_grounded = true, abs(snap.velocity.x) < ε` | Idle | C.4 `_derive_movement_state(snap)` |
| T15 | Dead | `restore_from_snapshot(snap)` | `snap.is_grounded = true, abs(snap.velocity.x) ≥ ε` | Run | C.4 |
| T16 | Dead | `restore_from_snapshot(snap)` | `snap.is_grounded = false, snap.velocity.y < 0` | Jump | C.4 |
| T17 | Dead | `restore_from_snapshot(snap)` | `snap.is_grounded = false, snap.velocity.y ≥ 0` | Fall | C.4 |

> **T14-T17 note**: The Dead → normal movement state branch fires inside `restore_from_snapshot()` as a *forced re-enter* (`transition_to(target, payload, force=true)`). EchoLifecycleSM's REWINDING→ALIVE `state_changed` signal fires 30 frames *after* this point, but since PlayerMovementSM is already in a normal state no additional transition is forced — `_on_lifecycle_state_changed` ALIVE handler guards with `if current_state is not DeadState: return`.

#### C.2.3 Trigger Constraints (PlayerMovementSM signal subscription policy)

| Trigger candidate | Allowed? | Notes |
|---|---|---|
| `EchoLifecycleSM.state_changed` (DYING/DEAD) | ✅ Allowed | *Only* external signal path for PM Dead entry (T13) |
| `Damage.player_hit_lethal` direct subscription | ❌ Forbidden | forbidden_pattern `cross_entity_sm_transition_call`. Via EchoLifecycleSM only |
| `Damage.lethal_hit_detected` direct subscription | ❌ Forbidden | Same as above |
| Self-polling (`if damage.is_in_iframe(): ...`) | ❌ Forbidden | Unidirectional data flow violation (damage.md DEC-4) |
| `TimeRewindController.rewind_started` / `rewind_completed` direct subscription | ❌ Forbidden | EchoLifecycleSM is the single signal mediator (state-machine.md C.2.2 O4); PM only receives `restore_from_snapshot()` method calls |
| `restore_from_snapshot()` call (PM's own method) | ✅ Allowed | T14-T17 forced re-enter trigger |
| `Input.is_action_*` polling | ✅ Allowed | per-tick `_physics_process` Phase 2 input snapshot |

#### C.2.4 Input Ignore Rules (confusing cases)

- **jump input during AimLock**: *Ignored* (not added to jump_buffer). Cuphead-style hold semantics. Player must release aim_lock and input jump separately. AC obligation: `jump_just_pressed` fires during AimLock → no jump fires on next tick.
- **`move_axis.x` during AimLock**: *Ignored for movement* (no Run/Idle transition; ECHO velocity = ZERO maintained). However full `move_axis` (x + y) is used for `facing_direction` 8-way update (DEC-PM-2 free 8-way aim).
- **`move_axis.y` outside aim_lock**: *No effect on movement*. Used only for `facing_direction` 8-way update. ECHO can run left/right while aiming up/down/diagonal.
- **aim_lock input hold during Jump/Fall**: *Ignored* (violates T4 grounded guard; no transition). If hold continues on next grounded tick, T4 fires naturally.
- **All input during Dead**: *Ignored*. No input processed until next `restore_from_snapshot()` (T14-T17).
- **`rewind_consume` input**: *PM does not handle*. EchoLifecycleSM's DyingState polls this (state-machine.md C.2.2 O3). Irrelevant to PM.

#### C.2.5 Framework Atomicity Inheritance (decision to not introduce cross-tick deferred queue)

PlayerMovementSM inherits the framework's transition queue + `_is_transitioning` atomicity *without modification* via `extends StateMachine` (state-machine.md C.2.1 line 196-206). Result:

- Same-tick cascade scenarios — e.g.: PM `move_and_slide()` mid-execution → Area2D `area_entered` → Damage `lethal_hit_detected` synchronous emit → EchoLifecycleSM synchronous DYING transition → `state_changed` synchronous emit → PlayerMovementSM `_on_lifecycle_state_changed` synchronous call → `transition_to(DeadState)` — are *all processed synchronously in the same tick*.
- If PlayerMovementSM's own transition is in progress during synchronous cascade, the framework's `_is_transitioning` guard blocks the nested transition; it is enqueued in the pending queue and auto-dispatched after the current transition completes.
- **PM layer does not introduce a separate cross-tick deferred queue** — framework atomicity is sufficient for Tier 1. Matches M2 reuse verification (state-machine.md AC-23) case.
- Verification: state-machine.md AC-23 (framework reuse) + this GDD's new H section AC (mid-tick lethal cascade determinism).

### C.3 Per-Tick Frame Loop (`_physics_process`)

#### C.3.1 Phase ordering (PM priority=0, 16.6ms frame budget)

`PlayerMovement._physics_process(delta: float)` executes the following 7 Phases *synchronously in sequence* every frame. Since TRC runs at priority=1 immediately after PM, at the end of Phase 6c the PM-owned 7-field subset of PlayerSnapshot must be in an *authoritative* state (TRC calls `_capture_to_ring()` in the same tick). Per Amendment 2 (2026-05-11): the remaining 1 Weapon-owned field (`ammo_count`) is owned separately by Weapon, and 1 TRC-internal field (`captured_at_physics_frame`) is owned separately by TRC — Resource total 9 fields.

| Phase | Task | Key behavior |
|---|---|---|
| 1 | `_is_restoring` clear | `_is_restoring = false` (ends previous tick's restore guard). This line is at the *very top* of the method. |
| 2 | Input snapshot read | Cache to local vars: `move_axis: Vector2 = Input.get_vector("move_left","move_right","move_up","move_down")` / `jump_pressed = Input.is_action_just_pressed("jump")` / `jump_released = Input.is_action_just_released("jump")` / `aim_lock_held = Input.is_action_pressed("aim_lock")` etc. *No state mutation*. `shoot` is *not read* by PM (Player Shooting #7 owned). |
| 3a | SM input-driven transitions | PlayerMovementSM evaluates input-based transitions: T3 (jump edge → Jump), T4 (aim_lock pressed + grounded → AimLock), T1/T2 (move_axis.x change → Run/Idle), T10/T11 (aim_lock released → Idle/Run), T7 (jump_released during Jump → Fall + cut). *Must precede Phase 4* for velocity calculation to dispatch to the correct state. |
| 4 | Target velocity calculation | Dispatch based on current PlayerMovementSM state: AimLock → `velocity = Vector2.ZERO`; Jump entry first frame → `velocity.y = -jump_velocity_initial`; Jump → `velocity.y += gravity_rising * delta`, `velocity.x = move_toward(velocity.x, target_vx, step_size_air)` (D.1 step formula — D.1 unified unbounded-fix); Fall → `velocity.y += gravity_falling * delta`, lateral same; Run/Idle → `velocity.x = move_toward(velocity.x, target_vx, step_size_ground_*)` frame-count ramp (delta accumulation *forbidden* — D.1). Dead → no-op. |
| 5 | `move_and_slide()` | CharacterBody2D built-in call (`up_direction = Vector2.UP` default). `is_on_floor()` gives accurate value immediately after this call. ADR-0003's "direct transform" means *bypassing the RigidBody2D solver*, and `move_and_slide()` is that itself (deterministic integration). |
| 6a | `is_grounded` cache + coyote update | `is_grounded = is_on_floor()` (PM itself is single source — TRC priority=1 *reads* `is_grounded` only, direct `is_on_floor()` calls *forbidden*). `if is_grounded: _last_grounded_frame = Engine.get_physics_frames()`. |
| 6b | SM physics-driven transitions | PlayerMovementSM evaluates physics-result-based transitions: T6 (apex → Fall), T8/T9 (landing → Idle/Run), T12 (AimLock floor lost → Fall), T5 (Idle/Run → Fall on floor lost). Evaluates Phase 4 velocity results. |
| 6c | facing_direction + animation cache | `facing_direction` 8-way composite update (C.2.4 rules); `_anim.current_animation`/`_anim.current_animation_position` are auto-exposed as read-only properties (no separate cache variable needed). |
| 7 | (TRC implicit at priority=1) | This PM `_physics_process` ends → Godot calls `_physics_process` of priority=1 node (`TimeRewindController`) → TRC `_capture_to_ring()` reads 7 fields. PM-side obligation: all fields must be *authoritative* values at this point. |

#### C.3.2 Forbidden patterns within `_physics_process`

| Forbidden action | Reason |
|---|---|
| `Time.get_ticks_msec()` / wall-clock dependency | ADR-0003 determinism clock violation. All timers use `Engine.get_physics_frames()` differencing |
| `delta` accumulation counter (`_coyote_remaining += delta`) | float drift + restore boundary synchronization failure. Mandatory rejection in code review |
| `await get_tree().physics_frame` / coroutine-based transition | Determinism violation. All SM transitions are synchronous (C.2.5) |
| `velocity` mutation *after* Phase 5 | `move_and_slide()` result is the *official source* for TRC priority=1 read. Velocity changes in Phase 6+ cause 1-tick lag |
| `move_and_slide()` call *before* Phase 4 | Breaks input → state → velocity → physics integration order |
| `PlayerMovementSM.transition_to()` *before* Phase 1 | If transition fires before `_is_restoring` clear, anim guard is inactive → method-track callback stale write possible |
| `is_on_floor()` call *before* Phase 5 | Stale value since `move_and_slide()` hasn't run. Called exactly once in Phase 6a |

#### C.3.3 Coyote / jump buffer predicates (frame-counter based)

Deterministic measurement via `Engine.get_physics_frames()` differencing. Delta accumulation *forbidden*. **B1 fix 2026-05-11**: active-flag (bool) + frame (int) pair pattern — bool short-circuit AND blocks math evaluation *before* it executes, making int64 overflow impossible by construction (previous `INT_MIN` sentinel had an arithmetic overflow bug where `current - INT_MIN` always reversed predicate to TRUE, causing phantom-jumps; D.3 Formula 5 + AC-H5-04 single source).

```gdscript
# Phase 6a update:
if is_grounded:
    _last_grounded_frame = Engine.get_physics_frames()
    _grounded_history_valid = true

# Phase 3a evaluation (coyote — bool short-circuit blocks math evaluation):
var coyote_eligible: bool = (
    _grounded_history_valid
    and (Engine.get_physics_frames() - _last_grounded_frame) <= coyote_frames
    and not (current_movement_state is JumpState)
)
# jump fire condition: is_grounded OR coyote_eligible

# Phase 2 (input edge detection): register jump_buffer:
if jump_pressed:
    _jump_buffer_frame = Engine.get_physics_frames()
    _jump_buffer_active = true

# Phase 3a evaluation (auto-fire on landing):
var jump_buffered: bool = (
    _jump_buffer_active
    and (Engine.get_physics_frames() - _jump_buffer_frame) <= jump_buffer_frames
    and is_grounded
)

# Phase 3a post-fire — buffer consumed (when jump actually fires):
# if should_jump and _jump_buffer_active:
#     _jump_buffer_active = false
#
# On Dead entry / restore_from_snapshot() — single deactivate site:
# _jump_buffer_active = false ; _grounded_history_valid = (snap.is_grounded if restore else false)
# Single bool=false set permanently blocks phantom-jump — math overflow impossible (C.4.1 Step 4 single source).
```

#### C.3.4 mid-`move_and_slide()` SM cascade (atomicity inheritance)

If ECHO's HurtBox and an enemy HitBox shape overlap during Phase 5, `Area2D.area_entered` is *synchronously emitted* and a cascade can occur (damage.md C.1.2 + C.2.5):

```
move_and_slide() (Phase 5, PM priority=0)
  └─ HitBox.area_entered emit (synchronous)
     └─ HurtBox.hurtbox_hit emit (synchronous)
        └─ Damage._on_hurtbox_hit emit lethal_hit_detected (synchronous)
           └─ EchoLifecycleSM transition_to(DyingState) (synchronous)
              └─ EchoLifecycleSM.state_changed emit (DYING)
                 └─ PlayerMovementSM._on_lifecycle_state_changed
                    └─ PlayerMovementSM.transition_to(DeadState) (synchronous)
```

The cascade *completes* inside Phase 5. By the time Phase 6a is reached, PlayerMovementSM is already in DeadState. Physics-driven transition evaluation in Phase 6b is meaningless from DeadState and is automatically a no-op (DeadState.physics_update returns). facing_direction update in Phase 6c is also skipped from DeadState.

Framework `_is_transitioning` atomicity guarantees PlayerMovementSM in-flight transitions — e.g.: if the above cascade fires during a Run→Jump transition in Phase 3a, the Dead transition is enqueued in the pending queue and dispatched immediately after Run→Jump completes (C.2.5 decision).

### C.4 Restore Path (`restore_from_snapshot()` + `_is_restoring` Guard)

#### C.4.0 Metaphor bridge — why restoration is *not world rewind*

The vocabulary in B.2 ("9-frame *re-run*", "sees the same barrage again") can imply *world rewind*. However, per ADR-0001 Player-only checkpoint scope (time-rewind.md Rule 12), enemies · bullets · hazards · environment *continue simulating* throughout the DYING / REWINDING / i-frame period. `restore_from_snapshot()` mutates only the 7 fields of the PlayerMovement body + AnimationPlayer, and world simulation has been proceeding normally since `frame = rewind_trigger`.

**The mechanism by which the player "sees the same barrage again" is not *world re-execution* but *deterministic repetition*** — ADR-0003's determinism guarantee (`Engine.get_physics_frames()` clock + CharacterBody2D + `process_physics_priority` ladder) causes enemies/bullets to follow *identical* paths in the same frame sequence. Return to ECHO's position 9 frames prior → within that same frame sequence, the deterministic paths of enemies/bullets generate *a new collision sequence with the re-entered ECHO*. This combination of *deterministic repetition + body re-entry* is the kinematic representation of Pillar 1 "learning tool, not punishment".

Therefore the restore path hosted by this system handles *only* PM's own 7 fields + AnimationPlayer.seek + PlayerMovementSM force-transition. There is *no* mutation to enemies/bullets/HUD/the scene at large — invariant respect obligation toward other systems (forbidden_pattern `direct_player_state_write_during_rewind` is limited to single-writer for PM's 7 fields).

#### C.4.1 `restore_from_snapshot()` signature + single-source mutation path

```gdscript
class_name PlayerMovement extends CharacterBody2D

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _movement_sm: PlayerMovementSM = $PlayerMovementSM

# Single guard flag — cleared to `false` every tick at Phase 1 (C.3.1).
# Set to `true` inside restore_from_snapshot; auto-cleared at next _physics_process Phase 1.
var _is_restoring: bool = false

# Active-flag + frame pair (B1 fix 2026-05-11) — bool=false is the permanent phantom-jump block site.
# Replaces INT_MIN sentinel — removes `current - INT_MIN` int64 overflow predicate reversal bug.
# bool short-circuit AND returns false before math evaluation — D.3 Formula 5 + C.3.3 single pattern.
var _jump_buffer_active: bool = false
var _jump_buffer_frame: int = 0         # only meaningful when _jump_buffer_active == true
var _grounded_history_valid: bool = false
var _last_grounded_frame: int = 0       # only meaningful when _grounded_history_valid == true

# B10 fix 2026-05-11 — per-axis dual Schmitt trigger state for facing hysteresis
# (D.4 Formula 2). Mutually exclusive per axis. Cleared per F.4.2 #2 obligation.
var _facing_x_pos_active: bool = false
var _facing_x_neg_active: bool = false
var _facing_y_pos_active: bool = false
var _facing_y_neg_active: bool = false

# B3 — Godot 4.6 AnimationMixer.callback_mode_method default = DEFERRED (0).
# Force IMMEDIATE — _is_restoring guard model requires method-track callbacks synchronous-to-seek().
# Under DEFERRED, callbacks fire on next idle frame — stale write after guard clears → guard invalidated.
# Single source: docs/engine-reference/godot/modules/animation.md "Critical Default" section.
# AC-H1-07 (boot invariant) + C.4.4/C.4.5 guard patterns + VA.5 method-track policy all depend on this override.
func _ready() -> void:
    _anim.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
    assert(_anim.callback_mode_method == AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE, \
        "PlayerMovement requires IMMEDIATE callback mode for _is_restoring guard (B3 fix 2026-05-11)")

# Single path for applying PlayerSnapshot. Called by TRC priority=1. External direct calls forbidden.
# Single bypass method for forbidden_pattern `direct_player_state_write_during_rewind`.
func restore_from_snapshot(snap: PlayerSnapshot) -> void:
    # Step 1 — Set _is_restoring on *first line*. Guards all subsequent cascade writes.
    #   anim method-track callback / WeaponSlot.weapon_equipped signal handler / external emits.
    _is_restoring = true

    # Step 2 — Direct assignment of transform + physics fields (CharacterBody2D inherited).
    #   ADR-0003: bypasses Godot Physics solver, so direct field assignment is *authoritative* state for next tick.
    global_position = snap.global_position
    velocity = snap.velocity

    # Step 3 — Logic state fields (PM new members).
    facing_direction = snap.facing_direction
    _current_weapon_id = snap.current_weapon_id
    _is_grounded = snap.is_grounded

    # Step 4 — Active-flag deactivate — prevents phantom jump (B1 fix 2026-05-11; C.3.3 single pattern).
    #   bool=false set is the single deactivate site. First term of predicate AND is false → math evaluation skipped.
    #   Previous `INT_MIN` sentinel had int64 overflow predicate reversal bug with `current - INT_MIN`.
    _jump_buffer_active = false
    _jump_buffer_frame = 0
    if snap.is_grounded:
        _last_grounded_frame = Engine.get_physics_frames()
        _grounded_history_valid = true
    else:
        _grounded_history_valid = false
        _last_grounded_frame = 0

    # Step 5 — PlayerMovementSM forced re-enter (T14-T17 derivation).
    #   target is one of idle/run/jump/fall. dead/aim_lock are never targets (C.4.3).
    var target_state: State = _derive_movement_state(snap)
    _movement_sm.transition_to(target_state, {"is_restoring": true}, true)
    #                                          ^payload: signals enter() to skip anim play
    #                                                                      ^force_re_enter=true

    # Step 6 — Animation: play() *first* (track switch), then seek(time, true).
    #   AnimationPlayer.seek second arg `true` = *forced immediate evaluation* (time-rewind.md I4 single source).
    #   `seek(time)` alone is not allowed — base frame not updated until next frame, causing capture lag.
    _anim.play(snap.animation_name)
    _anim.seek(snap.animation_time, true)
```

#### C.4.2 `_is_restoring` lifetime

| Timing | Value | Effect |
|---|---|---|
| Phase 1 (top of `_physics_process` every tick) | forced `false` set (clears previous tick's residual) | Normal input processing resumes |
| `restore_from_snapshot()` Step 1 | `true` set | All cascade write guards activated |
| `restore_from_snapshot()` Step 6 (`seek(time, true)`) | `true` maintained | seek *synchronously calls* method-track callbacks; guard blocks stale writes |
| `restore_from_snapshot()` end | `true` maintained | Guards subsequent cascades in same tick (e.g., WeaponSlot signal) |
| Next tick Phase 1 | `false` auto-cleared | Normal operation resumes |

> **Single-tick lifetime**: Since TRC priority=1 runs *after* PM priority=0's `_physics_process` completes, `restore_from_snapshot()` is always called in the *latter half of that tick* for PM (TRC processes `try_consume_rewind()`). At the start of the next tick's PM `_physics_process`, `_is_restoring` is auto-cleared → guard is active for exactly 1 tick (= seek + subsequent same-tick cascades) only.

#### C.4.3 `_derive_movement_state(snap)` — T14-T17 derivation

```gdscript
const _ABS_VEL_X_EPS: float = 0.5  # px/s; stop-determination deadzone (G.1 tunable)

func _derive_movement_state(snap: PlayerSnapshot) -> State:
    if snap.is_grounded:
        if absf(snap.velocity.x) < _ABS_VEL_X_EPS:
            return _movement_sm.get_node(^"IdleState") as State    # T14
        else:
            return _movement_sm.get_node(^"RunState") as State     # T15
    else:
        if snap.velocity.y < 0.0:
            return _movement_sm.get_node(^"JumpState") as State    # T16
        else:
            return _movement_sm.get_node(^"FallState") as State    # T17
```

**Intentional omissions**:
- `DeadState` is never a target. EchoLifecycleSM's REWINDING→ALIVE transition fires 30 frames later, but PlayerMovementSM is already in a normal movement state. `_on_lifecycle_state_changed` ALIVE handler guards with `if current_state is not DeadState: return` (C.2.2 T13 note).
- `AimLockState` is never a target. PlayerSnapshot does not capture the aim_lock input hold state (B.4 non-negotiable #1: input queue reset forbidden + input is external polling). aim_lock input is polled in the tick *immediately after* restore at Phase 2; if still held, T4 fires naturally on the next tick (1-tick latency — consistent with DEC-PM-2 hold-button semantics).

#### C.4.4 Anim method-track handler guard pattern (mandatory)

`AnimationPlayer.seek(time, true)` *synchronously calls* method-track keyframes. Risk of stale callback emits (e.g., projectile spawn) (time-rewind.md I9 + AC-D5). **All anim method-track handlers** are obligated to use the following guard pattern:

```gdscript
# Projectile spawn method-track handler (cooperates with Player Shooting #7)
func _on_anim_spawn_bullet() -> void:
    if _is_restoring:
        return  # Block stale spawn — wait for normal playback to fire again
    _weapon_slot.spawn_projectile(facing_direction)
```

| Guard applies to | Owner | Notes |
|---|---|---|
| `_on_anim_spawn_bullet` | Player Shooting #7 / WeaponSlot | Most common case — guard mandatory |
| `_on_anim_play_footstep_sfx` | Audio (#21) | Lightweight SFX *may omit* guard — Audio GDD decision |
| `_on_anim_emit_dust_vfx` | VFX (#14) | Guard recommended — blocks stale dust trail on restore |
| `_on_anim_advance_phase_flag` | Boss Pattern (#11) — unrelated to ECHO | No guard concern on ECHO side |

> **AC obligation (H section)**: Verify with GUT test that `_is_restoring` guard exists for *every* ECHO anim method-track handler (static analysis via `grep "method_track\|anim_method"`). *Partial* guard is a silent regression risk.

#### C.4.5 External cascade guard (WeaponSlot signal etc.)

`restore_from_snapshot()` Step 3 direct assignment `_current_weapon_id = snap.current_weapon_id` can cascade-emit through setters or signal handlers. **`_current_weapon_id` uses *direct field assignment* only — setter definition forbidden**. WeaponSlot's `weapon_equipped` signal handler is also obligated to use the `_is_restoring` guard:

```gdscript
# PlayerMovement._on_weapon_equipped — WeaponSlot signal handler
func _on_weapon_equipped(weapon_id: int) -> void:
    if _is_restoring:
        return  # Ignore auto-emit from WeaponSlot side during restore — 7-field is authoritative
    _current_weapon_id = weapon_id
    # Normal swap UI/SFX cue etc...
```

### C.5 Input Contract (Locked — Input System #1 Designed 2026-05-11)

> **F.4.1 #1 closure (2026-05-11 — Input #1 re-review APPROVED)**: "(Provisional pending Input System #1)" header removed. Input #1 GDD now exists at [`design/gdd/input.md`](input.md). The 4 items previously deferred to Input #1 authorship are **verbatim locked** per Input #1 single source — see C.5.3 below for the resolution map.

#### C.5.1 Action map (Tier 1 floor — `project.godot` already mapped)

List of input actions *directly read* by this GDD. When Input System #1 GDD is formalized, this table is the single source.

| Action | PM Read site | Detect mode | Buffer / Notes |
|---|---|---|---|
| `move_left` / `move_right` | Phase 2 (`_physics_process`) | **Analog axis** (`Input.get_vector` or `get_axis`) | No buffer; sampled every tick |
| `move_up` / `move_down` | Phase 2 | Analog axis | Used for facing_direction 8-way update during Run/Jump/Fall (no movement effect — OQ-2 lock); 8-way aim during aim_lock (DEC-PM-2) |
| `jump` | Phase 2 + Phase 3a | **Edge-triggered** (`is_action_just_pressed`) + Edge-released (`is_action_just_released` for variable cut OQ-4) | `jump_buffer_frames` (default 6) pre-grounded window + `coyote_frames` (default 6) post-leave |
| `aim_lock` | Phase 2 + Phase 3a | **Hold-detect** (`is_action_pressed`) | No buffer. held=AimLock state, released=instant return (T10/T11). DEC-PM-2 hold semantics |
| `shoot` | **PM does not read** | — (Player Shooting #7 owned) | PM does not respond to `shoot` input. Movement not frozen (preserves game-concept "jump + shoot simultaneously") |
| `rewind_consume` | **PM does not read** | — (EchoLifecycleSM owned, state-machine.md C.2.2 O3) | PM only receives `restore_from_snapshot()` call; `rewind_consume` input is irrelevant |
| `pause` | **PM does not read** | — | EchoLifecycleSM's `should_swallow_pause()` polling (state-machine.md O2) |

#### C.5.2 Buffer window contract

| Window | Default | Unit | Measurement source | Clear timing |
|---|---|---|---|---|
| `jump_buffer_frames` | 6 frames (~100ms @60fps) | frames | `Engine.get_physics_frames()` differencing | T3 fires OR Dead entry OR `restore_from_snapshot()` |
| `coyote_frames` | 6 frames (~100ms @60fps) | frames | `Engine.get_physics_frames() - _last_grounded_frame` | T3 fires OR Jump entry (direct) OR Dead entry OR `restore_from_snapshot()` |

**Celeste precision match**: Both values follow Maddy Thorson's published 6 frames standard (G.1 tunable).

#### C.5.3 Resolved Lock (Input #1 F.4.1 closure 2026-05-11)

Input System #1 GDD `design/gdd/input.md` (re-review APPROVED 2026-05-11 lean mode) is the single source for the 4 items previously deferred to Input #1 authorship. Each item below is now **verbatim locked** with cross-ref:

| # | PM provisional item | Input #1 single source | Locked value |
|---|---|---|---|
| 1 | `aim_lock` action naming confirm (DEC-PM-2) | input.md C.1.1 row 6 + C.4 `InputActions.AIM_LOCK` | `aim_lock` (StringName const `&"aim_lock"`) |
| 2 | `move_left/right/up/down` 4-action split vs 2-axis decision | input.md C.1.1 rows 1–4 + C.4 (4 separate `MOVE_*` constants) | **4 separate actions** (`move_left`, `move_right`, `move_up`, `move_down`); composed via `Input.get_vector(...)` for radial composite. Locked. |
| 3 | Gamepad stick deadzone 0.2 (Tier 1 default) | input.md C.1.3 + D.3 + G.1.1; INVARIANT-IN-1/IN-2 cross-knob constraints | **0.2 radial composite** in `project.godot` `[input]` block for all 4 move actions. Tier 3 mutation only via `SettingsManager.apply_deadzone()` paused-tree apply. |
| 4 | KB+M default keys | input.md C.3.1 (KB+M Profile table) + A.1 Decision Log row "KB+M aim_lock = F" | `A/D/W/S` move, `Space` jump, **`F` aim_lock** (NOT `Shift` — Shift conflict resolved to `rewind_consume`; rationale: Hotline Miami Shift-aim muscle-memory separation per input.md C.3.1 row + B6 fix Session 14), `LMB` shoot, `Shift` rewind_consume, `Escape` pause |

**AimLock-jump exclusivity AC** (PM F.4.2 obligation): locked at input.md C.3.3 — InputMap fires `aim_lock` (hold) + `jump` (just_pressed) as independent events with zero chord-swallow logic. PM Phase 2 polling sees both action states simultaneously. Replaces PM AC-H4-04 (now obsolete — Input AC-IN-16 BLOCKING is the canonical contract).

**Deadzone enforcement** (PM E-PM-9 obligation): locked at input.md C.1.3 + AC-IN-06/07 — `project.godot` 0.2 radial composite is the single enforcement site; PM does NOT re-implement deadzone math (`forbidden_patterns.deadzone_in_consumer` per architecture.yaml). PM B10 `facing_threshold_outside` hysteresis is a **separate concern** (PM-side asymmetric thresholds enter=0.2 / exit=0.15 per PM B10 fix) and does not conflict with Input deadzone single source.

**No further mutation expected**: per Input #1 C.2 Tier 1 invariant + Round-7 cross-doc-contradiction exception protocol, any future change to the 4 locked values requires (a) Input #1 GDD revision, (b) PM C.5.3 sync update via cross-doc exception, (c) reciprocal architecture.yaml registry update.

### C.6 Interactions With Other Systems

This table is the single source for how PlayerMovement exchanges data · signals · method calls with other systems. F.1-F.4 carries bidirectional consistency (referenced_by) responsibility.

| Target system | Direction | Wiring pattern | Forbidden alternatives |
|---|---|---|---|
| **TimeRewindController (#9)** | TRC reads PM 7 fields every tick; invokes `restore_from_snapshot(snap)` during REWINDING | TRC-side `@export var player: PlayerMovement` (declarative; missing-ref editor-visible) | `get_parent()` / autoload lookup / `find_node()` / scene-tree group lookup |
| **EchoLifecycleSM (#5)** | EchoLifecycleSM `state_changed` signal → PM `_on_lifecycle_state_changed`. DYING/DEAD → PlayerMovementSM force-transition to DeadState (T13). ALIVE → no-op | Signal-reactive: `_lifecycle_sm.state_changed.connect(_on_lifecycle_state_changed)` in PM `_ready()`. **call_deferred connect recommended** (state-machine.md C.3.4 — avoids scene-tree-order race) | PM polling `_lifecycle_sm.current_state` per tick (violates `cross_entity_sm_transition_call` forbidden_pattern) |
| **Damage (#8)** | PM *hosts* HurtBox + HitBox + Damage nodes only. Damage component owns its own wiring. PM is indirect — Damage emit `lethal_hit_detected` is subscribed to by EchoLifecycleSM (PM direct subscription forbidden) | Composition: child node instantiation in `.tscn`. PM `_ready()` does *not touch* Damage node | PM directly subscribes to `Damage.player_hit_lethal` / `lethal_hit_detected` (C.2.3 forbidden); PM writes `HurtBox.monitorable` (DEC-4 enforce site violation) |
| **[Input System #1](input.md)** *(F.4.1 #2 closure 2026-05-11 — Input #1 Designed; provisional flag removed)* | PM polls `Input.is_action_*` per tick (`_physics_process` Phase 2 only). Single source for polling pattern + callback-forbidden is [`input.md` C.1.2 Rule 1+2](input.md) — PM is the *consumer* of those rules, has no policy of its own | Direct calls to `Input.is_action_pressed` / `is_action_just_pressed` / `get_vector` (must use input.md C.4 `InputActions.*` StringName consts) | Binding movement logic to `_unhandled_input` / `_input` callbacks (latency + timing mismatch — input.md C.1.2 Rule 2 single source forbidden, `forbidden_patterns.gameplay_input_in_callback` CI gate per architecture.yaml + AC-IN-05); subscribing to InputEvent emits; scattered `&"jump"` literals (input.md C.4 + AC-IN-04 BLOCKING) |
| **WeaponSlot (#7)** | PM hosts WeaponSlot child node. `weapon_equipped(weapon_id: int)` signal → PM `_on_weapon_equipped` caches `_current_weapon_id`. `restore_from_snapshot()` is authoritative for 7 fields — WeaponSlot signal cascade blocked by `_is_restoring` guard (C.4.5) | Composition: child node. signal-reactive cache | Firing `WeaponSlot.set_active(...)` during `_is_restoring` (even a silent fallback violates 7-field authority) |
| **[Scene Manager #2](scene-manager.md)** *(F.4.1 #2 closure 2026-05-11 — Scene Manager #2 Approved RR7; provisional flag removed; OQ-PM-1 resolved)* | PM does *not directly subscribe* to `scene_will_change` signal (scene-manager.md C.1 Rule 5 sole-subscribers TRC + EchoLifecycleSM; PM direct subscription forbidden). EchoLifecycleSM calls PM `_clear_ephemeral_state()` per O6 obligation to cascade-clear 8-var ephemeral state (4 coyote/buffer + 4 facing Schmitt flags). **OQ-PM-1 closure**: SM emit → EchoLifecycleSM `_on_scene_will_change()` → PM `_clear_ephemeral_state()` single cascade path (scene-manager.md C.3.2 T+0 row). | EchoLifecycleSM O6 cascade — PM `_clear_ephemeral_state()` synchronous call from `_lifecycle_sm._on_scene_will_change()` handler (signal-reactive; single-layer design — PM is unaware of SM emit timing) | PM independently subscribes to `scene_will_change` (duplicate handler, race with SM clear) |
| **AnimationPlayer (Godot built-in)** | PM hosts child node + per-tick read property + calls `play()` + `seek(time, true)` on restore | `_anim.current_animation` / `current_animation_position` proxy; `_anim.play(name)` / `_anim.seek(time, true)` | `_anim.seek(time)` alone (missing second arg `true` — capture lag); `_anim.advance(delta)` (determinism violation) |
| **Sprite2D (Godot built-in)** | PM hosts child node. facing_direction visualization — `flip_h` toggle vs left/right anim branching decision is art-director consult in **Visual/Audio section** | TBD | — |
| **Enemy AI (#10) / Boss Pattern (#11)** | Enemies/bosses *read* PM `global_position` only (chase target). PM subscribes to no enemy/boss signals | Read-only: `var target_pos := player.global_position` | Enemy/boss calls PM methods / emits signals / mutates state |

---

## D. Formulas

### D.1 Run Acceleration / Deceleration

**Formula** (frame-count based, `move_toward()` — *NOT* delta-accumulator):

```
target_vx = sign(move_axis.x) * run_top_speed       if abs(move_axis.x) > 0
target_vx = 0                                       if abs(move_axis.x) = 0

step_size_ground_accel = run_top_speed / run_accel_frames    # accelerating toward non-zero target
step_size_ground_decel = run_top_speed / run_decel_frames    # decel to 0 OR sign-reversal pass-through
step_size_air          = (active_step_ground) * air_control_coefficient

velocity.x = move_toward(velocity.x, target_vx, active_step)
```

`active_step` selection:
- ground (Idle/Run): `target_vx ≠ 0 AND sign(target_vx) == sign(velocity.x)` → accel; else → decel
- air (Jump/Fall): same ground choice above + `air_control_coefficient` multiplied

Sign reversal is handled naturally by `move_toward()` — at `+200 → -200`: decel 8 frames + accel 6 frames = 14 frames.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `run_top_speed` | v_max | float | 160–240 px/s | Maximum horizontal velocity (ground + air shared cap) |
| `run_accel_frames` | f_accel | int | 4–10 frames | Frames to reach v_max from stop (Tier 1 = 6) |
| `run_decel_frames` | f_decel | int | 5–12 frames | Frames to reach stop from v_max (Tier 1 = 8) |
| `air_control_coefficient` | k_air | float | 0.5–0.85 (B.5 hard cap < 1.0) | Air step_size multiplier (Tier 1 = 0.65) |
| `move_axis.x` | a_x | float | -1.0 ~ 1.0 | Analog input (Input layer deadzone applied) |
| `velocity.x` | v_x | float | ≈ -200 ~ +200 px/s | Horizontal velocity; input to `move_and_slide()` |

**Output Range:** `velocity.x` ∈ `[-run_top_speed, +run_top_speed]` always by `move_toward` cap — no unbounded accumulation in air either.

**Worked Example (Tier 1 v_max=200, f_accel=6, f_decel=8, k_air=0.65):**

```
Ground accel step = 200/6 ≈ 33.3 px/s/frame
Ground decel step = 200/8 = 25.0 px/s/frame
Air accel step    = 33.3 × 0.65 ≈ 21.7 px/s/frame

Ground accel from 0 (run): frames 1-6 = 33, 67, 100, 133, 167, 200 → cap
Ground decel from 200 (release): frames 1-8 = 175, 150, 125, 100, 75, 50, 25, 0
Sign reversal +200 → -200: decel 8 frames + accel 6 frames = 14 frames total
Air accel 0 → 200 (jump+run): 200/21.7 ≈ 9.2 frames
```

### D.2 Jump Velocity / Gravity / Apex

> **Tier 1 height invariant lock (Decision A 2026-05-10)**: `jump_velocity_initial = 480 px/s`, `gravity_rising = 800 px/s²` → `jump_height_max_px = 480² / (2 × 800) = 144 px` exactly. (Preserves the gameplay-programmer's existing 144 px target; gravity_rising adjusted 900→800.)

**Formula 1 — Jump impulse (on JumpState.enter()):**
```
velocity.y = -jump_velocity_initial    # = -480 px/s (upward)
```

**Formula 2 — Height invariant (verification formula):**
```
jump_height_max_px = jump_velocity_initial² / (2 × gravity_rising)
                   = 480² / (2 × 800) = 144 px ✓
```

**Formula 3 — Rising gravity integration (Phase 4 per-tick):**
```
velocity.y += gravity_rising * delta    # delta = 1/60 s; per-tick *single-use* integration
```

**Formula 4 — Apex predicate (T6 trigger):**
```
velocity.y >= 0   → Jump → Fall
```

**Formula 5 — Variable jump cut (T7, OQ-4 Celeste cut):**
```
if jump_released AND velocity.y < 0:
    velocity.y = max(velocity.y, -jump_cut_velocity)    # jump_cut_velocity = 160 px/s (Tier 1)
    transition_to(FallState)
```

**Formula 6 — Falling gravity integration (Phase 4 per-tick):**
```
velocity.y += gravity_falling * delta    # gravity_falling = 1620 px/s²
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `jump_velocity_initial` | v_j | float | 420–560 px/s | Upward velocity on jump entry (positive magnitude) |
| `gravity_rising` | g_up | float | 700–1100 px/s² | Applied while velocity.y < 0 (rising) (Tier 1 = 800) |
| `gravity_falling` | g_down | float | 980–2200 px/s² | Applied while velocity.y ≥ 0 (falling) (1.4–2.0× g_up) |
| `jump_cut_velocity` | v_cut | float | 100–200 px/s | Upward velocity ceiling at jump-cut moment (Tier 1 = 160) |
| `delta` | dt | float | ≈ 0.01667 s | 60fps frame; per-tick *single-use* integration |
| `velocity.y` | v_y | float | ≈ -560 ~ +∞ | Vertical velocity; − = upward |

**Output Range:**
- Max apex (full hold): 144 px
- Min apex (frame 1 cut): `160² / (2 × 1620) ≈ 7.9 px`
- Falling: no upward cap (naturally terminated by level design / void)

**Worked Example (Tier 1 v_j=480, g_up=800, g_down=1620, v_cut=160, dt=0.01667):**

```
Full press path (hold jump all the way to apex):
  Jump entry: velocity.y = -480
  per-frame Δv = 800 × 0.01667 ≈ 13.33 px/s
  Frames to apex: 480 / 13.33 ≈ 36 frames (apex tick when velocity.y >= 0)
  Apex height: 480² / (2 × 800) = 144 px ✓

Frame-4 cut path (release jump after 4 frames):
  Frame 4 velocity.y: -480 + 4 × 13.33 = -426.7 px/s
  jump_released → velocity.y = max(-426.7, -160) = -160 px/s; transition to Fall
  Continued rise after cut (now g_falling=1620): 160² / 3240 ≈ 7.9 px
  Frames 1-4 rise (avg velocity ≈ -460 px/s × 4 frames × 0.01667) ≈ 30 px
  Total apex: ~38 px (less than half, short hop)

Frame-12 cut path (release fairly late):
  Frame 12 velocity.y: -480 + 12 × 13.33 = -320 px/s
  -320 < -(-160) → cut: velocity.y = -160 px/s
  Frames 1-12 rise: ≈ 80 px + 7.9 ≈ 88 px (≈ 60% of full)
```

### D.3 Coyote Time / Jump Buffer Predicates

**Formula 1 — Coyote eligibility (Phase 3a evaluation) — B1 fix:**
```
coyote_eligible = (
    _grounded_history_valid                                              # B1 fix: bool short-circuit guard
    AND (Engine.get_physics_frames() - _last_grounded_frame) <= coyote_frames
    AND not (current_movement_state is JumpState)
)
```

**Formula 2 — Jump buffer eligibility (Phase 3a evaluation) — B1 fix:**
```
jump_buffered = (
    _jump_buffer_active                                              # B1 fix: bool short-circuit guard
    AND (Engine.get_physics_frames() - _jump_buffer_frame) <= jump_buffer_frames
    AND is_grounded
)
```

**Formula 3 — Combined jump-fire predicate (T3 trigger):**
```
should_jump = (
    (jump_pressed AND (is_grounded OR coyote_eligible))
    OR jump_buffered
)
```

**Formula 4 — Buffer registration (on Phase 2 jump_pressed) — B1 fix:**
```
_jump_buffer_frame = Engine.get_physics_frames()    # only on edge fire
_jump_buffer_active = true                          # B1 fix: set active flag simultaneously (pair invariant)
```

**Formula 5 — Active-flag reset (on Dead entry + restore_from_snapshot) — B1 fix 2026-05-11:**
```
# Active-flag pattern: bool=false single-set blocks the first AND term of the predicate.
# math evaluation skipped → int64 overflow impossible by construction.
_jump_buffer_active     = false
_jump_buffer_frame      = 0
_grounded_history_valid = snap.is_grounded   # restore: follows snap / Dead entry: false
_last_grounded_frame    = Engine.get_physics_frames() if snap.is_grounded else 0
```

> **B1 fix rationale**: The previous pattern `_jump_buffer_frame = INT_MIN (-9223372036854775808)` on the next tick when `Engine.get_physics_frames()=1` caused `1 - (-9223372036854775808)` int64 arithmetic overflow → negative result (or very large positive depending on platform — undefined behavior) → predicate `(current - INT_MIN) <= jump_buffer_frames` inverted to TRUE, the opposite of intent → phantom jump fired from the very first frame *without a fresh `jump_pressed` input*. Confirmed by 3-specialist convergence (systems-designer + qa-lead + godot-gdscript-specialist).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `coyote_frames` | C | int | 4–8 frames | Window after leaving a floor where jump is still possible (Tier 1 = 6) |
| `jump_buffer_frames` | B | int | 4–8 frames | Window before landing where a buffered jump fires automatically (Tier 1 = 6) |
| `_grounded_history_valid` | V_g | bool | true/false | true = has been grounded at least once since last reset (B1 fix active flag) |
| `_last_grounded_frame` | F_g | int | ≥ 0 | Last frame where `is_on_floor() = true`; **meaningful only when V_g=true** |
| `_jump_buffer_active` | V_b | bool | true/false | true = active jump buffer exists (B1 fix active flag) |
| `_jump_buffer_frame` | F_b | int | ≥ 0 | Most recent jump press frame; **meaningful only when V_b=true** |

**Output Range:** boolean. When **active flags V_g/V_b = false**, the predicate AND short-circuits *before* math evaluation → always false guaranteed immediately after reset (int64 overflow impossible by construction). The previous `INT_MIN` sentinel pattern was deprecated by B1 fix 2026-05-11.

**Worked Example:**

```
Scenario A (coyote): jump 3 frames after leaving platform
  Frame N:    is_grounded=true → _last_grounded_frame = N, _grounded_history_valid = TRUE
  Frame N+1:  is_grounded=false (left edge)
  Frame N+3:  jump_pressed = true
              coyote_eligible: V_g AND (N+3 - N) ≤ 6 AND not JumpState → TRUE AND 3 ≤ 6 AND TRUE → TRUE
              should_jump: (TRUE AND (FALSE OR TRUE)) = TRUE → T3 fires

Scenario B (buffer): jump 3 frames before landing
  Frame N:    jump_pressed → _jump_buffer_frame = N, _jump_buffer_active = TRUE; is_grounded=false
  Frames N+1, N+2:  is_grounded=false
  Frame N+3:  is_grounded=true (landed)
              jump_buffered: V_b AND (N+3 - N) ≤ 6 AND is_grounded → TRUE AND 3 ≤ 6 AND TRUE → TRUE
              should_jump: (FALSE OR TRUE) = TRUE → T3 fires on landing tick
              post-fire: _jump_buffer_active = FALSE (buffer consumed — C.3.3 post-fire pattern)

Scenario C (active-flag reset — B1 fix 2026-05-11): clear buffer on Dead entry
  Frame N (Dead entry — clear at DeadState.enter()):
    _jump_buffer_active     = false
    _jump_buffer_frame      = 0
    _grounded_history_valid = false   (grounded info invalidated at Dead entry)
    _last_grounded_frame    = 0
  Frame N+10 (restore_from_snapshot fires inside this tick; snap.is_grounded=true):
    _jump_buffer_active     = false   (idempotent re-clear; restore preserves cleared state)
    _grounded_history_valid = true    (grounded restored)
    _last_grounded_frame    = N+10    (Engine.get_physics_frames() returns N+10 at this tick)
  Frame N+11 (first tick AFTER restore; predicate evaluation, no fresh jump_pressed):
    jump_buffered = (_jump_buffer_active=false AND ...) → FALSE short-circuit
                   ↑ math evaluation skipped; the (N+11 - 0) subtraction itself is not executed
                   → phantom jump cannot fire at any frame counter value by construction.

# Previous sentinel pattern bug (B1 — removed 2026-05-11):
# Frame N+11: (N+11 - INT_MIN) = (N+11 - -9223372036854775808) → int64 overflow
#   → result is undefined behavior; measured Godot 4.6 GDScript wraps to a large negative number
#   → predicate `<= jump_buffer_frames` (6) inverted to TRUE
#   → phantom jump fires from first frame without a fresh jump_pressed (Pillar 1 violation)
```

### D.4 Facing Direction Update

> **Encoding lock (Decision B 2026-05-10)**: `facing_direction: int` 0..7 enum. CCW from East — 0=E, 1=NE, 2=N, 3=NW, 4=W, 5=SW, 6=S, 7=SE. Maintains PlayerSnapshot 7-field schema compatibility (no ADR-0002 change). PM internal helpers `_encode_facing()` / `_decode_facing()` are the single source.

**Formula 1 — Encoding helpers (PM private):**
```gdscript
# (x, y) ∈ {-1, 0, 1} × {-1, 0, 1}, (0,0) → -1 sentinel "preserve"
const _FACING_TABLE: Array[int] = [
    3, 4, 5,    # row x=-1: NW(=3), W(=4), SW(=5)
    2, -1, 6,   # row x=0:  N(=2),  PRESERVE(=-1), S(=6)
    1, 0, 7     # row x=1:  NE(=1), E(=0), SE(=7)
]

static func _encode_facing(v: Vector2i) -> int:
    var idx: int = (v.x + 1) * 3 + (v.y + 1)  # 0..8
    return _FACING_TABLE[idx]    # -1 sentinel for (0,0)

const _DIRS: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, -1),
    Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)
]

static func _decode_facing(f: int) -> Vector2i:
    return _DIRS[f]  # f ∈ 0..7 always
```

**Formula 2 — Outside aim_lock (Run/Jump/Fall/Idle Phase 6c) — B10 hysteresis pair fix 2026-05-11:**

```gdscript
# Per-axis dual Schmitt trigger. Each axis has independent pos/neg active
# flags (mutually exclusive). ENTER threshold (0.2) commits to a sign; EXIT
# threshold (0.15) releases. Drift on the opposite side below opposite-ENTER
# threshold ALSO releases (via "value < +exit" / "value > -exit" guard).
# This blocks Steam Deck stick drift (~±0.18) from oscillating facing
# across the deadzone-aligned single threshold.
#
# Ephemeral state vars (declared in C.4.1; cleared per F.4.2 #2):
#   _facing_x_pos_active : bool   # locked to +x
#   _facing_x_neg_active : bool   # locked to -x
#   _facing_y_pos_active : bool   # locked to +y
#   _facing_y_neg_active : bool   # locked to -y
#
# Invariant (G.4.1 INV-4 + new INV-8): t_exit < t_enter; t_aim_lock <= t_enter.

var t_enter: float = tuning.facing_threshold_outside_enter   # 0.20
var t_exit:  float = tuning.facing_threshold_outside_exit    # 0.15

# X-axis Schmitt
if _facing_x_pos_active:
    if move_axis.x < t_exit:           # also covers drift past zero on -x side
        _facing_x_pos_active = false
elif _facing_x_neg_active:
    if move_axis.x > -t_exit:          # symmetric
        _facing_x_neg_active = false
else:
    if move_axis.x >= t_enter:
        _facing_x_pos_active = true
    elif move_axis.x <= -t_enter:
        _facing_x_neg_active = true

# Y-axis Schmitt (same pattern)
if _facing_y_pos_active:
    if move_axis.y < t_exit:
        _facing_y_pos_active = false
elif _facing_y_neg_active:
    if move_axis.y > -t_exit:
        _facing_y_neg_active = false
else:
    if move_axis.y >= t_enter:
        _facing_y_pos_active = true
    elif move_axis.y <= -t_enter:
        _facing_y_neg_active = true

# Encode locked signs → facing
var x_sign: int = (1 if _facing_x_pos_active
                   else (-1 if _facing_x_neg_active else 0))
var y_sign: int = (1 if _facing_y_pos_active
                   else (-1 if _facing_y_neg_active else 0))
var encoded: int = _encode_facing(Vector2i(x_sign, y_sign))
if encoded != -1:    # (0,0) sentinel → preserve previous
    facing_direction = encoded
```

**Formula 3 — Inside AimLockState (Phase 6c override):**
```gdscript
const FACING_THRESHOLD_AIM_LOCK: float = 0.1    # Decision C — finer aim precision

if absf(move_axis.x) >= FACING_THRESHOLD_AIM_LOCK \
   or absf(move_axis.y) >= FACING_THRESHOLD_AIM_LOCK:
    var v: Vector2i = Vector2i(signi(move_axis.x), signi(move_axis.y))
    var encoded: int = _encode_facing(v)
    if encoded != -1:
        facing_direction = encoded
# else: preserve previous
```

**Formula 4 — null-input preservation rule:**
Both axes below threshold → `facing_direction` *unchanged* (retains previous value). `(0,0)` "direction undetermined" is never stored as *official facing*. PlayerSnapshot always guarantees a valid 0..7 enum value.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `facing_direction` | f | int | 0..7 enum | 8-way direction (E~SE CCW); PlayerSnapshot capture target |
| `move_axis` | a | Vector2 | -1.0 ~ 1.0 per axis | Analog input (Phase 2 read) |
| `facing_threshold_outside_enter` | t1_enter | float | 0.15–0.35 | **B10 fix 2026-05-11** — outside aim_lock ENTER threshold to commit to a new sign on an axis (Tier 1 = 0.2; matches `gamepad_deadzone` per input.md C.1.3 + AC-IN-06/07) |
| `facing_threshold_outside_exit` | t1_exit | float | 0.05–`t1_enter`-0.02 | **B10 fix 2026-05-11** — outside aim_lock EXIT threshold to release an active sign (Tier 1 = 0.15; below Steam Deck stick drift floor ~0.18 to ensure release on stick-rest noise; must be strictly less than `t1_enter` per INV-8) |
| `FACING_THRESHOLD_AIM_LOCK` | t2 | float | 0.05–0.2 | aim_lock threshold (Tier 1 = 0.1; well below stick drift floor — no hysteresis needed since drift can't oscillate facing across 0.1 from rest near 0) |
| `_facing_x_pos_active` | s_x+ | bool | {false, true} | **B10 fix** — ephemeral; true ↔ +x sign locked (mutually exclusive with `_facing_x_neg_active`) |
| `_facing_x_neg_active` | s_x- | bool | {false, true} | **B10 fix** — ephemeral; true ↔ -x sign locked |
| `_facing_y_pos_active` | s_y+ | bool | {false, true} | **B10 fix** — ephemeral; true ↔ +y sign locked |
| `_facing_y_neg_active` | s_y- | bool | {false, true} | **B10 fix** — ephemeral; true ↔ -y sign locked |

**Output Range:** `facing_direction` ∈ {0..7}. The `(0,0)` ≡ -1 sentinel is *internal only*; externally exposed facing_direction is always a valid enum.

**Worked Example:**

```
Initial:   facing_direction = 0 (E, _ready default)

Frame 1:   move_axis=(0.8, 0.0) → x ≥ 0.2; v=(1,0) → enc=0=E; facing=0 (no change)
Frame 2:   move_axis=(0.8, -0.7) → both ≥ 0.2; v=(1,-1) → enc=1=NE; facing=1 ✓ (diagonal upper-right)
Frame 3:   move_axis=(0.05, 0.0) → both < 0.2; preserve; facing=1 ✓ (held aim)
Frame 4:   move_axis=(0.0, 0.0) → both < 0.2; preserve; facing=1 ✓ (stick release)
Frame 5:   move_axis=(-0.9, 0.0) → x ≥ 0.2; v=(-1,0) → enc=4=W; facing=4 ✓ (left flip)

AimLock entry (threshold 0.1 applied):
Frame 10:  AimLockState; move_axis=(0.0, -0.15)
           y ≥ 0.1 (0.15); v=(0,-1) → enc=2=N; facing=2 ✓
           (if outside threshold were 0.2, would be below threshold → would preserve)

null input preservation:
AimLock + move_axis=(0,0): preserve; PlayerSnapshot facing=previous value (e.g. 2=N).
*Never* is "direction undetermined" captured.

B10 hysteresis drift defense (Steam Deck stick rest ~±0.18 noise; t_enter=0.2 / t_exit=0.15):
Frame 1:   move_axis=(0.21, 0.0); not active → 0.21 ≥ 0.2 enter → _x_pos_active=true;
           x_sign=+1, y_sign=0 → enc=0=E; facing=0
Frame 2:   move_axis=(0.18, 0.0); _x_pos_active=true → 0.18 < 0.15 exit? FALSE
           (0.18 is NOT < 0.15) → preserve _x_pos_active=true;
           x_sign=+1, y_sign=0 → enc=0=E; facing=0 ✓ (drift held)
Frame 3:   move_axis=(-0.18, 0.0); _x_pos_active=true → -0.18 < 0.15 exit? TRUE
           → release: _x_pos_active=false;
           check enter on -x: -0.18 ≤ -0.2? FALSE → NOT activated;
           x_sign=0, y_sign=0 → enc=-1 sentinel → preserve; facing=0 ✓
           (CRITICAL: pre-B10 single-threshold logic would have flipped to W
            here because |-0.18| < 0.2 → both axes below threshold → preserve
            previous facing=E; same result actually for THIS drift. The real
            failure mode is below ↓)
Frame 4:   move_axis=(0.21, 0.0); not active (released F3) → 0.21 ≥ 0.2 enter
           → _x_pos_active=true; facing=0 ✓
Frame 5:   move_axis=(-0.21, 0.0); _x_pos_active=true → -0.21 < 0.15 exit? TRUE
           → release: _x_pos_active=false; check -x enter: -0.21 ≤ -0.2? TRUE
           → _x_neg_active=true; x_sign=-1, y_sign=0 → enc=4=W; facing=4 ✓
           (Deliberate large stick flip — hysteresis allows intentional change.)

Pre-B10 oscillation case the fix blocks:
   Pre-B10 single threshold = 0.2 = `gamepad_deadzone` (input.md C.1.3).
   Steam Deck stick drift envelope ~±0.18 with occasional tails to ±0.21.
   
   Pre-B10 behavior on drift tail crossings:
   Frame 1: (0.21, 0.0) → 0.21 ≥ 0.2 → commit facing=E
   Frame 2: (0.18, 0.0) → 0.18 < 0.2 → preserve E (in-band drift OK)
   Frame 3: (-0.21, 0.0) → -0.21 ≤ -0.2 → flip facing=W  ← UNINTENDED on drift tail
   Frame 4: (0.21, 0.0) → 0.21 ≥ 0.2 → flip back to E    ← UNINTENDED on drift tail
   → Pre-B10 visual: facing oscillates E↔W on every drift-tail crossing of 0.2.

   Post-B10 protection via [0.15, 0.20) "protected band" (showcased in 5-frame
   trace above): the EXIT threshold 0.15 sits BELOW the typical drift envelope
   ±0.18, so an active sign stays committed under in-band drift. The fix
   narrows the unintended-flip zone from "any crossing of 0.2" to "deliberate
   stick flip — release first via |x| < 0.15, then commit via ≥ 0.20 in
   opposite direction". Drift staying within ±0.18 cannot achieve this
   sequence; only deliberate user input can. Drift between -0.15
   and -0.2 is in the "neither" zone — facing preserved at whatever was last
   locked. ✓ stable facing under drift.
```

---

## E. Edge Cases

This section specifies abnormal / edge situations that can arise in PlayerMovement alone and in interaction with other systems. Each entry uses *condition → outcome* format ("handle gracefully" is forbidden). 5 categories: Snapshot restore / Input / Physics / Animation / SM cascade.

### E.1 Snapshot Restore

- **E-PM-1**: `snap.is_grounded = true` but `snap.global_position` is an airborne coordinate above the floor (e.g., platform collapsed at capture time + scene change missed). → `restore_from_snapshot()` trusts `is_grounded` value as-is; on the next tick Phase 5 `move_and_slide()` + Phase 6a recalculates `is_grounded = is_on_floor()` for natural correction. During the 1-tick lag, IdleState/RunState is maintained (gravity not applied). If floor not detected next tick, T5 fires naturally → Fall.
- **E-PM-2**: `snap.velocity.y < 0` AND `snap.is_grounded = true` (theoretically contradictory — ground-launching at capture time). → `_derive_movement_state()` prioritizes `is_grounded` — Run/Idle. velocity.y restored as-is (may behave like a jump on next tick Phase 5). Design intent *unclear*; cannot occur in normal capture scenarios (is_grounded set to false immediately on jump entry).
- **E-PM-3**: `snap.animation_name` is an anim *removed* since capture (e.g., removed during hot-reload). → `_anim.play(snap.animation_name)` is a silent no-op (warning print). `seek()` is also no-op on an invalid track. PM restores only facing/velocity/position, anim stays at default. Intent: *graceful degradation*. AC obligation: verify with invalid anim_name fixture in `tests/integration/`.
- **E-PM-4**: `snap.animation_time` is negative or exceeds anim length. → `seek(time, true)` is Godot-clamped to `[0, length]`. Silent. However when `time = NaN`, behavior is undefined — `assert(not is_nan(snap.animation_time))` dev-only guard is mandatory after `_is_restoring` is set (G.4).
- **E-PM-5**: `snap.current_weapon_id` is *invalid* (e.g., id retired after weapon design change). → `_current_weapon_id = snap.current_weapon_id` direct assignment; `_on_weapon_equipped` cascade blocked by `_is_restoring` guard (C.4.5). On the next tick `_on_weapon_equipped` fires normally and falls back to id=0 (time-rewind.md E-15 contract). PM caches the invalid id and updates on next weapon_equipped signal.

### E.2 Input edge cases

- **E-PM-6**: AimLock entry + jump input *same tick*. → Phase 2 read: `aim_lock_held=true`, `jump_pressed=true` simultaneously. Phase 3a: T4 (AimLock) evaluated first → state=AimLock; jump_pressed discarded per C.2.4 rule (no buffer registration). Result: AimLock entered + jump discarded.
- **E-PM-7**: Floor lost (T12) on frame N while holding AimLock + floor reacquired on frame N+1. → frame N: T12 → Fall. frame N+1: is_grounded=true → T8/T9 → Idle/Run; since `aim_lock_held = true`, frame N+2 Phase 3a T4 fires naturally → AimLock. **Net effect**: 2-tick AimLock interruption then natural return.
- **E-PM-8**: jump_pressed during coyote → Run/Fall → Jump transition. Same tick mid-`move_and_slide()` Damage cascade → Dead. → framework atomicity: Run/Fall→Jump pending → Dead processed sequentially (C.2.5). Normal sequence: Run → Jump (current tick) → Dead (next tick mid-`move_and_slide` Damage cascade arrival).
- **E-PM-9**: Undeadzoned noise (`abs(move_axis.x) ≈ 0.05`) reaches PM — GDScript `sign(0.05) = 1.0` causes Run transition to fire incorrectly. → **Input System #1 GDD is obligated to guarantee 0.2 deadzone at the input layer**; this GDD assumes only deadzone-applied input is received. Verification is Input System #1 AC responsibility (provisional flag).

### E.3 Physics edge cases

- **E-PM-10**: `move_and_slide()` result has ECHO *clipped into a wall* (corner clip). → `is_on_floor()` result unchanged, `velocity.x` clamped to 0 by wall collision. State machine proceeds normally. Visual artifacts deferred to Tier 2 wall-grip design review (per DEC-PM-1).
- **E-PM-11**: 1000-cycle determinism: same starting state + same input sequence → identical 7-field result across 1000 runs. Verified by ADR-0003 R-RT3-01. PM is part of the determinism guarantee — `Engine.get_physics_frames()` subtraction + `move_toward()` determinism + `move_and_slide()` determinism (verified with Godot 4.6 CharacterBody2D + Forward+). AC-F1 (time-rewind.md) PlayerSnapshot bit-identical verification also covers this system.
- **E-PM-12**: 60fps drop causes delta to accumulate as 0.05s (3 frames worth) in a single tick. → ADR-0003 Validation #4 — Godot calls `_physics_process` *3 separate times*; delta is always 1/60 ≈ 0.01667s. PM is not exposed to delta fluctuation. `Engine.get_physics_frames()` also increments accordingly — determinism maintained.

### E.4 Animation edge cases

- **E-PM-13**: After `seek(time, true)`, a method-track callback triggers *its own state transition* (e.g., anim_method calls `_movement_sm.transition_to(JumpState)`). → framework atomicity (C.2.5) blocks nested transition; pending queue. `_is_restoring` guard blocks *the callback itself* (C.4.4) as primary defense. 2-layer defense prevents stale callbacks from mutating PM state.
- **E-PM-14**: `seek(snap.animation_time)` on a looping animation — anim_time = 0.5 at capture (1.0s looping anim). → seek is clamped to [0, length]; loop position 0.5 reproduced exactly. Loop continues naturally from next frame. **Tier 1 verification required (HIGH risk Godot 4.6)**: OQ-PM-2 — confirm looping anim seek behavior in Tier 1 prototype (same dependency as time-rewind.md OQ-9).

### E.5 SM cascade edge cases

- **E-PM-15**: In REWINDING state, ECHO HurtBox.monitorable=false → enemy projectiles do not collide. PM visual output is normal (anim play, position update). PM does not *directly perceive* i-frames — DEC-4 unidirectional. Tier 1 visual cue (i-frame flicker or outline) is an art-director decision in the Visual/Audio section.
- **E-PM-16**: `restore_from_snapshot()` called *same tick* immediately after Dead entry (TRC processes immediately when DyingState input buffer is satisfied). → Same-tick cascade: ALIVE → DYING (Damage) → 12-frame grace begins → input buffer satisfied → REWINDING entry → restore. PM receives `restore_from_snapshot()` at the *last step* of the cascade. Sequence: PM Run/Jump → Dead → Re-derive (T14-T17). framework atomicity guaranteed.
- **E-PM-17**: Dead re-entry immediately on the *next tick* after `restore_from_snapshot()` via Damage cascade. → `_is_restoring` cleared to `false` in Phase 1 of the next tick; Phase 5 `move_and_slide()` cascade fires normally. Result: 1-tick ALIVE → Dead. **i-frames are NOT PM's responsibility — they are EchoLifecycleSM RewindingState.enter()'s `HurtBox.monitorable=false` responsibility** (DEC-4) — in normal flow REWINDING 30 frames i-frame is active so this scenario is *impossible*; however it can occur in dev/test fixtures where EchoLifecycleSM is bypassed (PM handles silently).

---

## F. Dependencies

### F.1 Upstream Dependencies (Player Movement consumes)

| # | System | Data Flow | Interface | Hard/Soft |
|---|---|---|---|---|
| **#1** | Input System | PM polls InputMap actions | `Input.is_action_pressed/just_pressed/just_released` + `Input.get_vector("move_left","move_right","move_up","move_down")`. Action names: `move_left/move_right/move_up/move_down/jump/aim_lock` read directly. `shoot/rewind_consume/pause` are NOT read | **Hard** |
| **#2** | [Scene / Stage Manager](scene-manager.md) | On `scene_will_change`, PM ephemeral state cleared — *via EchoLifecycleSM* (single-layer cascade) | EchoLifecycleSM subscribes to `scene_will_change` (state-machine.md C.2.2 O6 confirmed); PM does NOT subscribe directly (scene-manager.md C.1 Rule 5 sole-subscribers). PM **8-var ephemeral state** cleared via EchoLifecycleSM cascade — 4 coyote/buffer (`_grounded_history_valid` + `_last_grounded_frame` + `_jump_buffer_active` + `_jump_buffer_frame`) + 4 facing Schmitt (`_facing_{x,y}_{pos,neg}_active`). **F.4.1 #2 closure 2026-05-11 (Scene Manager #2 Approved RR7)**: OQ-PM-1 resolved — provisional flag removed. | **Soft** |
| **#5** | State Machine Framework | PlayerMovementSM uses framework via `extends StateMachine` | `class_name PlayerMovementSM extends StateMachine` (M2 reuse). Inherits framework transition queue + atomicity (C.2.5). Framework code modification forbidden (state-machine.md C.2.1 line 206) | **Hard** |
| **#5** | EchoLifecycleSM (instance) | `state_changed` signal → PM `_on_lifecycle_state_changed`. On DYING/DEAD, PlayerMovementSM forced to `Dead` (T13). On ALIVE, no-op | `signal state_changed(from: StringName, to: StringName, frame: int)` (state-machine.md C.1.5). PM reads `to` value only | **Hard** |
| **#7** | Player Shooting / Weapon *(provisional)* | PM hosts WeaponSlot child node + subscribes to `weapon_equipped(weapon_id: int)` signal → `_current_weapon_id` cache | `signal weapon_equipped(weapon_id: int)` (to be defined in Player Shooting GDD). PM reads only | **Soft** *(cache; provisional)* |
| **#8** | Damage / Hit Detection | PM *hosts only* HurtBox + HitBox + Damage nodes. Does NOT subscribe to Damage signals directly — via EchoLifecycleSM | Composition only. PM `_ready()` does *not touch* Damage nodes | **Indirect Hard** *(hosting)* |
| **#9** | Time Rewind | TRC reads PM 7 fields every tick; invokes `restore_from_snapshot(snap)` | TRC `@export var player: PlayerMovement`. PM exposes `func restore_from_snapshot(snap: PlayerSnapshot) -> void`. forbidden_pattern `direct_player_state_write_during_rewind` single enforce site | **Hard** |
| **engine** | Godot 4.6 CharacterBody2D / AnimationPlayer | `move_and_slide()`, `is_on_floor()`, `AnimationPlayer.play()/seek(time, true)` | Godot built-in API. `seek` second arg `true` is mandatory (time-rewind.md I4) | **Hard** |

### F.2 Downstream Dependents (consume Player Movement state/signals)

| # | System | Data Flow | Interface | Hard/Soft |
|---|---|---|---|---|
| **#9** | Time Rewind | F.1 #9 reciprocal | See F.1 #9 | **Hard** |
| **#5** | State Machine Framework | PlayerMovementSM is the M2 reuse verification case for the framework | Verified by state-machine.md AC-23 | **Hard** |
| **#10** | Enemy AI | Enemies *read only* PM `global_position` (chase target) | `var target_pos := player.global_position` | **Soft** *(read-only)* |
| **#11** | Boss Pattern | Boss reads PM `global_position` + `velocity` (predictive firing) | Read-only | **Soft** |
| **#13** | HUD | (None in Tier 1) — HUD covers token count / boss phase only; PM state not directly exposed | — | — |
| **#14** | VFX | dust trail / landing puff etc. triggered by PM child method-track (`_on_anim_emit_dust_vfx`) | anim method-track emit | **Soft** |
| **#3** | [Camera System](camera.md) | Camera *reads only* PM `target.global_position` every tick (follow base) | Read-only `target.global_position: Vector2` per tick. Camera does not subscribe to PM signals (state read is via EchoLifecycleSM/PlayerMovementSM). camera.md F.1 row #2 reciprocal — Camera #3 Approved 2026-05-12 RR1 PASS. | **Soft** *(read-only)* |
| **engine** | rendering | `facing_direction` → `Sprite2D.flip_h` or anim branch | TBD (Visual/Audio section decision) | — |

### F.3 Signal Catalog (owned by Player Movement)

PlayerMovement does *not own any signals in Tier 1*.

| Signal | Signature | Emit Timing | Subscribers |
|---|---|---|---|
| (none — Tier 1) | — | — | — |

> **Tier 1 rationale**: External systems have sufficient access to PM state via *direct field read* + *PlayerMovementSM `state_changed` (framework inherited)* + *EchoLifecycleSM `state_changed`* alone. Own signals will be re-evaluated in Tier 2 if cinematic / animation trigger requirements arise (e.g., `landed(impact_force: float)` for landing dust VFX). Solo budget + Pillar 5 "small successes".

### F.4 Bidirectional Update Obligations

#### F.4.1 Immediate Obligations (apply immediately after this GDD F section — 6 cross-doc edits)

| # | Target File | Edit Type | Rationale |
|---|---|---|---|
| 1 | `time-rewind.md` F.1 row #6 | Remove `*(provisional)*` marker + lock in 7-field interface verbatim (C.1.3 table as-is) + specify `class_name PlayerMovement extends CharacterBody2D` + `restore_from_snapshot(snap: PlayerSnapshot) -> void` signature + `_is_restoring` guard cross-link | Player Movement #6 promoted to Designed |
| 2 | `state-machine.md` F.2 row #6 | Specify "PlayerMovementSM is independent of EchoLifecycleSM (Tier 1 flat composition)" + `extends StateMachine` (M2 reuse) + `Dead` state is reactive (NOT parallel ownership) | C.1.2 + C.2.5 single source cross-link |
| 3 | `state-machine.md` C.2.1 line 178-188 node tree correction (**Round 5 cross-doc-contradiction exception** per Decision A 2026-05-10) | Merge `ECHO (CharacterBody2D)` + `PlayerMovement (Node)` split notation into `PlayerMovement (CharacterBody2D, root)` single root + children (`EchoLifecycleSM`, `PlayerMovementSM`, `HurtBox`, `HitBox`, `Damage`, `WeaponSlot`, `AnimationPlayer`, `Sprite2D`) | A.Overview-locked `PlayerMovement extends CharacterBody2D` model authority |
| 4 | `damage.md` F.1 row | Specify that ECHO HurtBox + HitBox + Damage nodes are hosted as *child nodes* of PlayerMovement(CharacterBody2D) (HurtBox lifecycle = SM, node ownership = PM) | C.1.4 responsibility separation table cross-link |
| 5 | `design/gdd/systems-index.md` System #6 row | Status `Designed` + Design Doc link + Depends On expansion + Progress Tracker update + Last Updated | This GDD complete |
| 6 | `docs/registry/architecture.yaml` | 4 new entries: (1) `state_ownership.player_movement_state` (2) `interfaces.player_movement_snapshot` (3) `forbidden_patterns.delta_accumulator_in_movement` (4) `api_decisions.facing_direction_encoding` (int 0..7 enum) | 4 architecture stances from this GDD |

#### F.4.2 Obligations When Writing Subsequent GDDs

| Subsequent GDD | Obligation |
|---|---|
| **Input System #1** | (a) confirm `aim_lock` action naming; (b) decide `move_left/right/up/down` separate vs axis; (c) deadzone 0.2 (blocks E-PM-9); (d) KB+M default keys (C.5.3) |
| **Player Shooting #7** | (a) define `weapon_equipped(weapon_id: int)` signal; (b) `_on_anim_spawn_bullet` `_is_restoring` guard obligation (C.4.4); (c) whether reload + ammo restoration is a DEC-PM-3 re-evaluation trigger |
| ~~**Scene Manager #2**~~ ✅ **Closed 2026-05-11 (Scene Manager #2 Approved RR7)** | ~~`scene_will_change` emit timing + PM 8-var ephemeral state clear responsibility (resolves OQ-PM-1): **4-var coyote/buffer** (`_grounded_history_valid` + `_last_grounded_frame` + `_jump_buffer_active` + `_jump_buffer_frame` — B1 fix 2026-05-11) + **4-var facing hysteresis** (`_facing_x_pos_active` + `_facing_x_neg_active` + `_facing_y_pos_active` + `_facing_y_neg_active` — B10 fix 2026-05-11). All reset to `false` / `0`; failure-mode: if not cleared, stale-locked facing or phantom coyote/buffer jump fires on first tick immediately after scene transition~~ → **Resolved**: emit timing = same physics tick sync emit immediately before `change_scene_to_packed` call (scene-manager.md C.1 Rule 4); cascade path = SM emit → EchoLifecycleSM `_on_scene_will_change()` (O6 cascade) → PM `_clear_ephemeral_state()` (single-layer cascade per scene-manager.md C.1 Rule 5 — PM direct subscription forbidden). PM 8-var clear (4 coyote/buffer + 4 facing Schmitt) all reset to `false`/`0`. Verification: scene-manager.md AC-H15 (Integration BLOCKING) covers DEAD→ALIVE cascade clear via dependency-injected PM stub. F.1 row #2 + F.3 Scene Manager #2 row provisional flags removed in same Phase 5d commit. |
| **VFX #14** | landing puff / dust trail method-track callback `_is_restoring` guard policy (C.4.4 referenced_by) |
| **Audio #21** | footstep SFX method-track `_is_restoring` guard omission policy (lightweight artifact) |
| **Visual/Audio (this GDD)** | `facing_direction` visualization (`flip_h` vs left/right anim branch) art-director decision (C.6 + C.1.4) |
| **HUD #13** | PM signal exposure policy re-evaluation (Tier 2; F.3 Tier 1 decision = None) |

#### F.4.3 Subsequent ADR Obligations

| ADR | Obligation |
|---|---|
| **ADR-0003** | PM `process_physics_priority = 0` already registered; no change from this GDD |
| **ADR-0002** | PlayerSnapshot 7-field schema *unchanged* (Decision B encoding compatible). Amendment not required |
| **New ADR candidate** *(may omit in lean mode)* | "Variable jump cut policy" — DEC-PM-1/2/3 are locked within the GDD itself |

---

## G. Tuning Knobs

### G.1 Owned Knobs (PlayerMovement Resource)

> **Storage policy** (Decision G-A 2026-05-10; updated 2026-05-11 per B1 fix): All 13 owned numeric knobs live in `class_name PlayerMovementTuning extends Resource` (.tres asset at `assets/data/tuning/player_movement_tuning.tres`). PlayerMovement holds `@export var tuning: PlayerMovementTuning`. **Structural constants** (the 9-entry `_FACING_TABLE`, `_DIRS` array, encoding helper `const`s) remain as `const` in `player_movement.gd` — they are *encoding logic*, not balance. **Note (B1 fix 2026-05-11)**: The previously-listed `INT_MIN` sentinel constants have been *removed* — the buffer/coyote state is now represented by active-flag (bool) + frame (int) pairs (`_jump_buffer_active`/`_jump_buffer_frame` + `_grounded_history_valid`/`_last_grounded_frame`); these are *runtime ephemeral state vars*, not constants, and live as `var` declarations adjacent to `_is_restoring` (C.4.1). Resource hot-reload supported in editor; **runtime mutation of any owned knob during gameplay is forbidden** (G.4.1 invariant). Heading retains "PlayerMovement Resource" wording per skeleton; the canonical Resource class name is `PlayerMovementTuning`.

13 fields total. All `@export`-typed for editor visibility. Source formula column links to D-section verbatim.

| # | Knob | Type | Tier 1 default | Safe range | Source formula | Gameplay aspect |
|---|------|------|---------------|------------|----------------|-----------------|
| 1 | `run_top_speed` | float (px/s) | **200.0** | 160–240 | D.1 | Run velocity cap (shared ground + air). Below 160 = sluggish; above 240 = level layout retune required |
| 2 | `run_accel_frames` | int (frames) | **6** | 4–10 | D.1 step_size_ground_accel | Time to reach v_max from stop. Below 4 = ice-feel; above 10 = sluggish |
| 3 | `run_decel_frames` | int (frames) | **8** | 5–12 | D.1 step_size_ground_decel | Time to reach stop from v_max. Below 5 = snap stop (anti-feel); above 12 = sliding |
| 4 | `air_control_coefficient` | float | **0.65** | 0.5–0.85 | D.1 step_size_air | Air step_size multiplier. **Hard cap < 1.0** (B.5 anti-fantasy). Below 0.5 = floaty no-control; ≥1.0 = dilutes value of learning deterministic patterns |
| 5 | `jump_velocity_initial` | float (px/s) | **480.0** | 420–560 | D.2 Formula 1 | Upward magnitude on jump entry. To preserve 144 px max apex, g_rising must be adjusted in sync (D.2 Decision A invariant) |
| 6 | `gravity_rising` | float (px/s²) | **800.0** | 700–1100 | D.2 Formula 3 | Applied during ascent. **Invariant: ≤ gravity_falling** (G.4.1 INV-1). `2 × gravity_rising / jump_velocity_initial² = 1/apex_height` |
| 7 | `gravity_falling` | float (px/s²) | **1620.0** | 980–2200 | D.2 Formula 6 | Applied during descent. Recommend 1.4–2.0× gravity_rising (Celeste-style snappy fall) |
| 8 | `jump_cut_velocity` | float (px/s) | **160.0** | 100–200 | D.2 Formula 5 | Upward velocity cap when jump released mid-air. 100 = aggressive cut; 200 = subtle cut |
| 9 | `coyote_frames` | int (frames) | **6** | 4–8 | D.3 Formula 1 | Window after leaving floor where jump is still possible (~100ms @60fps). Maddy Thorson Celeste standard |
| 10 | `jump_buffer_frames` | int (frames) | **6** | 4–8 | D.3 Formula 2 | Buffered jump window before landing. Same default as coyote; asymmetric tuning tends to produce multiple bug reports |
| 11 | `facing_threshold_outside_enter` | float | **0.2** | 0.15–0.35 | D.4 Formula 2 | **B10 fix 2026-05-11** — Outside aim_lock ENTER threshold (commit to a sign on an axis). Matches Input #1 deadzone (0.2) — input.md C.1.3 + AC-IN-06/07 BLOCKING |
| 11b | `facing_threshold_outside_exit` | float | **0.15** | 0.05–`enter`-0.02 | D.4 Formula 2 | **B10 fix 2026-05-11** — Outside aim_lock EXIT threshold (release locked sign). Always < `enter` (INV-8). Covers Steam Deck stick drift floor ~0.18 to block drift-induced facing oscillation |
| 12 | `facing_threshold_aim_lock` | float | **0.1** | 0.05–0.2 | D.4 Formula 3 | AimLock internal facing precision (aiming accuracy). Always ≤ facing_threshold_outside_enter (INV-4) |
| 13 | `abs_vel_x_eps` | float (px/s) | **0.5** | 0.1–2.0 | C.4.3 `_ABS_VEL_X_EPS` | T14↔T15 derive boundary. Below 0.1 = float drift thrashing; above 2.0 = false Idle restore |

**Tuning Resource skeleton:**

```gdscript
class_name PlayerMovementTuning
extends Resource

# D.1 — Run accel/decel
@export_range(160.0, 240.0) var run_top_speed: float = 200.0
@export_range(4, 10)        var run_accel_frames: int = 6
@export_range(5, 12)        var run_decel_frames: int = 8
@export_range(0.5, 0.85)    var air_control_coefficient: float = 0.65
# D.2 — Jump / gravity / cut
@export_range(420.0, 560.0)  var jump_velocity_initial: float = 480.0
@export_range(700.0, 1100.0) var gravity_rising: float = 800.0
@export_range(980.0, 2200.0) var gravity_falling: float = 1620.0
@export_range(100.0, 200.0)  var jump_cut_velocity: float = 160.0
# D.3 — Coyote / buffer
@export_range(4, 8) var coyote_frames: int = 6
@export_range(4, 8) var jump_buffer_frames: int = 6
# D.4 — Facing thresholds
@export_range(0.15, 0.35) var facing_threshold_outside_enter: float = 0.2   # B10 fix 2026-05-11
@export_range(0.05, 0.33) var facing_threshold_outside_exit: float = 0.15   # B10 fix 2026-05-11 (< enter per INV-8)
@export_range(0.05, 0.2) var facing_threshold_aim_lock: float = 0.1
# C.4.3 — Movement-state derive epsilon
@export_range(0.1, 2.0) var abs_vel_x_eps: float = 0.5

# Validation called by PlayerMovement._ready() — see G.4.1 INV-1..8.
func _validate() -> void:
    assert(gravity_falling >= gravity_rising,
        "INV-1: gravity_falling must be >= gravity_rising")
    assert(air_control_coefficient < 1.0,
        "INV-2: air_control_coefficient must be < 1.0 (B.5 anti-fantasy)")
    assert(abs_vel_x_eps > 0.0,
        "INV-3: abs_vel_x_eps must be > 0 to prevent T14↔T15 thrashing")
    assert(facing_threshold_aim_lock <= facing_threshold_outside_enter,
        "INV-4: aim_lock threshold must be <= outside ENTER threshold (B10 fix 2026-05-11)")
    var apex_h: float = (jump_velocity_initial * jump_velocity_initial) \
        / (2.0 * gravity_rising)
    assert(apex_h >= 50.0 and apex_h <= 250.0,
        "INV-5: apex height %f px out of [50, 250] range" % apex_h)
    assert(coyote_frames + jump_buffer_frames <= 16,
        "INV-6: coyote + jump_buffer must be <= 16 frames")
    assert(facing_threshold_outside_exit < facing_threshold_outside_enter,
        "INV-8 (B10 fix 2026-05-11): hysteresis exit must be strictly less than enter; got exit=%f enter=%f" \
            % [facing_threshold_outside_exit, facing_threshold_outside_enter])
```

### G.2 Imported Knobs (referenced from other GDDs)

PM consumes these values via cross-system contracts; **owning GDD is single source**. PM may not redefine, mutate, or duplicate; PM AC must verify behaviour by *observation*, not by hardcoded comparison to the imported numeric value.

| Knob | Owner GDD | Owner value | PM use site | Mutation policy |
|------|-----------|-------------|-------------|-----------------|
| `hazard_grace_frames` (+1 compensation) | `damage.md` DEC-6 / G.1 | 12 (effective 13 due to RewindingState.exit() priority sequencing — `damage.md` B-R4-1 fix) | E-PM-13 (anim method-track stale callback timing); E-PM-16 (mid-tick lethal cascade timing); referenced as upper bound for any Visual/Audio fade decisions | Mutate in `damage.md` only; PM AC must verify via observation, never hardcode |
| `i_frame_frames` | `time-rewind.md` Rule 11 | 30 (REWINDING phase length, ≈0.5 s @60fps) | Visual/Audio i-frame flicker timing reference; E-PM-15 (PM does NOT directly inspect, but Visual cue duration = this value) | Mutate in `time-rewind.md` only |
| `gamepad_deadzone` | `Input System #1` *(provisional)* | 0.2 (Tier 1 default; C.5.3) | E-PM-9 (blocks `sign(0.05)` Run mistrigger). PM consumes *deadzone-applied* `move_axis`; PM's `facing_threshold_outside=0.2` aligns so that input below the threshold contributes neither to movement nor to facing | Input #1 owns; PM regression test asserts upstream deadzone applied before PM's Phase 2 read |

> **Not imported**: `REWIND_WINDOW_SECONDS` (1.5 s) and `max_tokens` (5) from `time-rewind.md` are *not referenced* by PM — TRC owns ring buffer slot count and token economy entirely. PM only receives `restore_from_snapshot(snap)` calls and is agnostic to the buffer's age semantics. DEC-PM-3 also explicitly excludes ammo from PlayerSnapshot, isolating PM from token + ammo state.

### G.3 Future Knobs (Tier 2+)

DEC-PM-1 locks Tier 1 to 6 states (`idle / run / jump / fall / aim_lock / dead`). The following knobs are **deferred**, *not designed*; each requires a documented DEC-PM-1 reconsideration trigger before authoring. Listed for traceability only — do not pre-allocate fields in `PlayerMovementTuning` until the trigger fires.

| Future Knob | Tier 2 state introduced | Reconsideration trigger | Current status |
|-------------|------------------------|-------------------------|----------------|
| `dash_velocity` (px/s), `dash_frames` (int), `dash_cooldown_frames` (int) | DashState (DEC-PM-1 deferred) | Tier 2 gate after passing Pillar 5 "small successes" — design-driven (no external trigger) | Deferred |
| `double_jump_velocity` (px/s), `max_air_jumps` (int) | DoubleJumpState (DEC-PM-1 deferred) | Tier 2 gate — design-driven | Deferred |
| `wall_grip_friction` (float), `wall_jump_velocity` (Vector2) | WallGripState (DEC-PM-1 deferred) | Tier 2 gate — design-driven; level-designer consultation required (wall surface design) | Deferred |
| `hit_stun_frames` (int) | HitStunState (DEC-PM-1 deferred) | **External trigger only** — when `damage.md` DEC-3 (binary 1-hit lethal) changes to a *non-lethal damage source* or a new boss knockback mechanism is introduced. damage.md GDD update is a prerequisite | Deferred (permanently deferred while damage.md DEC-3 lock holds) |
| `knockback_velocity` (float), `knockback_decel_frames` (int) | (no new state; modifies existing Run/Fall accelerations) | When Boss Pattern #11 GDD introduces knockback | Deferred |

> **Tier 2 gate obligations**: When introducing any of the above knobs: (1) issue DEC-PM-1 amendment (update Locked Scope Decisions), (2) expand PlayerMovementSM transition matrix (C.2.2), (3) add `restore_from_snapshot()` `_derive_movement_state()` branch (C.4.3), (4) add `PlayerMovementTuning` Resource fields + update `_validate()` invariants, (5) create new AC (H section). Single GDD work unit = 1 Tier 2 state added.

### G.4 Safety / Forbidden Mutations (3-layer enforcement)

This section defines the mutation policy for G.1 owned knobs and PM 7-fields (C.1.3). 3-layer defense (Decision G-C 2026-05-10) — extends the `damage.md` AC-21 / AC-29 precedent to PM.

#### G.4.1 Dev-only `assert()` invariants (runtime, debug builds)

`PlayerMovementTuning._validate()` is called from `PlayerMovement._ready()` (see G.1 skeleton). In release builds, Godot `assert()` is compiled out.

| # | Invariant | Assertion (summary) | Reason |
|---|-----------|---------------------|--------|
| INV-1 | `gravity_falling >= gravity_rising` | `assert(tuning.gravity_falling >= tuning.gravity_rising)` | Inverted gravity = anti-feel; violates Celeste-style snappy fall |
| INV-2 | `air_control_coefficient < 1.0` | `assert(tuning.air_control_coefficient < 1.0)` | B.5 anti-fantasy (full 360° air control = dilutes value of learning deterministic patterns) |
| INV-3 | `abs_vel_x_eps > 0.0` | `assert(tuning.abs_vel_x_eps > 0.0)` | If 0, T14↔T15 boundary thrashing on float noise |
| INV-4 | `facing_threshold_aim_lock <= facing_threshold_outside_enter` | `assert(tuning.facing_threshold_aim_lock <= tuning.facing_threshold_outside_enter)` | **B10 fix 2026-05-11** — aim_lock = precision aiming; less sensitive than outside enter is semantically contradictory. Naming updated per B10 split (`facing_threshold_outside` → `facing_threshold_outside_enter`) |
| INV-5 | apex height invariant: `(jump_velocity_initial² / (2 × gravity_rising))` ∈ [50.0, 250.0] px | `assert(50.0 <= h <= 250.0)` where `h = v_j²/(2*g_up)` | Protects the 144 px target during level-designer consultation (D.2 Decision A) — below 50 px is not-jumpy, above 250 px requires platform spacing retune |
| INV-6 | `coyote_frames + jump_buffer_frames <= 16` | `assert(tuning.coyote_frames + tuning.jump_buffer_frames <= 16)` | Sum > 16 = excessively forgiving input feel (~270 ms total slack); tends to produce multiple QA regressions |
| INV-7 | Owned knob changes forbidden during restore | runtime: when `_is_restoring=true`, `tuning.set_*` call triggers `assert(not _is_restoring)` (no setter defined in Tier 1 — `@export` direct assignment is sufficient; obligation applies when setter is introduced in the future) | Resource hot-swap mid-restore causes mid-tick determinism breach |
| INV-8 | `facing_threshold_outside_exit < facing_threshold_outside_enter` | `assert(tuning.facing_threshold_outside_exit < tuning.facing_threshold_outside_enter)` | **B10 fix 2026-05-11** — Schmitt hysteresis precondition: exit ≥ enter completely nullifies hysteresis (reverts to single-threshold logic → Steam Deck stick drift recurs). Equality (`==`) is also forbidden — exactly equal allows oscillation at boundary values |

PlayerMovement._ready() call pattern (specified in G.1 skeleton; this table is the INV catalog only):

```gdscript
func _ready() -> void:
    assert(tuning != null, "PlayerMovementTuning resource not assigned")
    tuning._validate()    # all INV-1..INV-6 + INV-8 (B10 fix 2026-05-11) checks
    # INV-7 to be added when setter is introduced
```

#### G.4.2 Static grep regressions (CI gate)

`tools/ci/forbidden-patterns.gd` (or equivalent grep step in CI) — extends the `damage.md` AC-21 / AC-29 precedent to PM.

| # | Pattern | Reason | Registered in architecture.yaml |
|---|---------|--------|----------------------------------|
| GREP-PM-1 | `\.global_position\s*=\|\.velocity\s*=\|\.facing_direction\s*=\|\._current_weapon_id\s*=\|\._is_grounded\s*=` outside `player_movement.gd` | forbidden_pattern `direct_player_state_write_during_rewind` single enforce site (C.1.3) | ✅ Registered (Session 9 architecture.yaml update) |
| GREP-PM-2 | `[a-zA-Z_]+\s*\+=\s*delta` in `player_movement.gd` (excluding the two `velocity.x/y` per-tick gravity integrations in Phase 4) | forbidden_pattern `delta_accumulator_in_movement` (float drift + restore boundary) | ✅ Registered (Session 9) |
| GREP-PM-3 | `Time\.get_ticks_msec\|OS\.get_ticks_msec\|Time\.get_unix_time` in `player_movement.gd` | ADR-0003 determinism clock — all timing uses `Engine.get_physics_frames()` subtraction | (candidate to add when cross-linked to architecture.yaml ADR-0003) |
| GREP-PM-4 | `_anim\.seek\s*\([^,]*\)` (single-arg seek) in `player_movement.gd` | Missing forced immediate evaluation of `seek(time, true)` (time-rewind.md I4) | (candidate to add to architecture.yaml `api_decisions`) |
| GREP-PM-5 | `_is_restoring\s*=\s*(true\|false)` outside `player_movement.gd` `restore_from_snapshot()` method | External mutation of `_is_restoring` is forbidden (single-writer = restore method only; C.4.1) | (registration candidate) |
| GREP-PM-6 | `await\s+get_tree\(\)\.physics_frame\|await\s+.*\.timeout` inside `player_movement.gd` SM transition handlers | Determinism violation — all SM transitions must be synchronous (C.2.5) | (registration candidate) |
| GREP-PM-7 | `is_on_floor\(\)` call location — fail if called outside Phase 6a within `player_movement.gd` | C.3.2 forbidden — stale value before Phase 5 | (registration candidate) |

> **CI script obligation (devops-engineer / tools-programmer task)**: Add the above 7 greps to the CI workflow. False-positive exemptions require `# ALLOW-PM-GREP-N` inline comment + justification (matches `damage.md` AC-21 pattern).

#### G.4.3 GUT unit tests (linked to H.7)

The H.7 *Static Analysis & Forbidden Patterns* section mandates GUT test fixtures for all `INV-1..7` + `GREP-PM-1..7`. This G.4 section is the catalog only; H.7 is the single source for test specs.

| Coverage obligation | H.7 AC ID (planned) |
|---------------------|---------------------|
| INV-1..6 invariant firing (debug builds) | H.7 AC verifies invariant violation with fail-fast PlayerMovementTuning fixture |
| GREP-PM-1..7 static analysis | H.7 AC verifies `player_movement.gd` + external .gd files via grep regex (`damage.md` AC-21 pattern) |
| Missing `_is_restoring` guard in anim method-track detected | H.7 AC: `grep "method_track\|anim_method"` + fail if `_is_restoring` guard is absent (C.4.4 obligation) |

#### G.4.4 Decision Summary (architecture.yaml registration status)

| forbidden_pattern | architecture.yaml registered | Source |
|-------------------|------------------------------|--------|
| `direct_player_state_write_during_rewind` | ✅ Session 9 registered (C.1.3 single-writer policy single enforce) | F.4.1 #6 |
| `delta_accumulator_in_movement` | ✅ Session 9 registered (C.3.2 + D.1 step_size unbounded-fix) | F.4.1 #6 |
| `single_arg_anim_seek` | ⏳ To be added at Tier 1 prototype (`time-rewind.md` I4 single-source reciprocal) | (deferred) |
| `cross_entity_sm_transition_call` | (already registered in `damage.md` / `state-machine.md`) | C.2.3 external system direct subscription forbidden |
| `wall_clock_in_gameplay_logic` | (already a candidate for ADR-0003 registration) | C.3.2 |

No new ADR issuance *required* — all items above are PM instantiations of the `damage.md` AC-21 precedent + ADR-0003 determinism ladder. Consistent with `lean` mode policy.

---

## H. Acceptance Criteria

> **Section Totals (post-revision 2026-05-11)**: **36 AC = 30 BLOCKING + 6 ADVISORY**.
> Per-fix delta: B3 +1 (AC-H1-07 boot invariant), B6 +1 (AC-H6-06 reachability fixture);
> B5 obsoletes-and-replaces AC-H1-05 → AC-H1-05-v2 (count neutral); B2+B4+B7+B8+B9+B10
> rewire existing AC bodies (count neutral). Per-row per-subsection tallies appear in
> each H.1–H.7 preamble below; final tally also locked in A.1 Locked Decisions.

### H.1 Snapshot Restoration (TR contract)

> **Coverage**: C.4.1 6-step `restore_from_snapshot()` · C.4.2 `_is_restoring` lifetime · C.4.3 `_derive_movement_state()` T14-T17 · C.4.4 anim method-track guard · C.4.5 WeaponSlot signal guard · DEC-PM-3 v2 ammo-captured · **B3 fix: `callback_mode_method = IMMEDIATE` boot invariant**. **7 AC** (all BLOCKING Logic GUT unless tagged). AC-H1-05 obsoleted by AC-H1-05-v2 (B5 fix 2026-05-11); AC-H1-07 newly added (B3 fix 2026-05-11).

**AC-H1-01** *(Logic GUT — BLOCKING)* — 7-field round-trip identity.
**GIVEN** `PlayerMovement` is in `DeadState` and a `PlayerSnapshot` with `is_grounded=true, abs(velocity.x) < abs_vel_x_eps, global_position=(100,200), velocity=(0,-5), facing_direction=3, current_weapon_id=2, animation_name=&"idle", animation_time=0.3` is applied via `restore_from_snapshot(snap)`,
**WHEN** the call returns,
**THEN** `global_position == snap.global_position` AND `velocity == snap.velocity` AND `facing_direction == snap.facing_direction` AND `_current_weapon_id == snap.current_weapon_id` AND `_is_grounded == snap.is_grounded` AND `AnimationPlayer.current_animation == snap.animation_name` AND `abs(AnimationPlayer.current_animation_position - snap.animation_time) < 0.002`.
*Mirror: time-rewind.md AC-A4 (TRC-side capture; both must pass for full TR contract).*

**AC-H1-02** *(Logic GUT — BLOCKING)* — `_is_restoring` single-tick lifetime.
**GIVEN** `_is_restoring == false` before `restore_from_snapshot(snap)` is called,
**WHEN** `restore_from_snapshot(snap)` begins (Step 1),
**THEN** `_is_restoring == true` throughout the body including the `AnimationPlayer.seek(snap.animation_time, true)` synchronous method-track invocation in Step 6;
**AND WHEN** the next `_physics_process` tick fires Phase 1,
**THEN** `_is_restoring == false`. Guard active for exactly one tick.

**AC-H1-03** *(Logic GUT — BLOCKING)* — anim method-track stale-spawn block.
**GIVEN** PlayerMovement hosts an anim method-track callback `_on_anim_spawn_bullet` AND `_is_restoring == true`,
**WHEN** `AnimationPlayer.seek(snap.animation_time, true)` synchronously fires the method-track key,
**THEN** `_on_anim_spawn_bullet` returns immediately without calling `_weapon_slot.spawn_projectile()`; projectile spawn count during restore tick = 0.
*Mirror: time-rewind.md AC-D5 (validates same guard from TRC seek-call side).*

**AC-H1-04** *(Logic GUT — BLOCKING)* — WeaponSlot cascade signal block.
**GIVEN** `PlayerMovement._on_weapon_equipped(new_id: int)` is connected to `WeaponSlot.weapon_equipped` signal AND `_is_restoring == true`,
**WHEN** `weapon_equipped` fires with `new_id != snap.current_weapon_id`,
**THEN** `_current_weapon_id` remains equal to `snap.current_weapon_id` (the value just set in Step 3); handler returns without mutating the field; `_current_weapon_id` change count during restore tick = 0.

**AC-H1-05** *(Logic GUT + Static grep — BLOCKING)* — ~~DEC-PM-3 ammo-not-captured.~~ **OBSOLETED 2026-05-11** by DEC-PM-3 v2 (B5 resolution) — superseded by AC-H1-05-v2 below.
~~**GIVEN** `PlayerSnapshot` schema is defined,~~
~~**WHEN** the test inspects `PlayerSnapshot.get_property_list()` (or equivalent reflection),~~
~~**THEN** no property named `ammo_count` (or `ammo`/`current_ammo`) exists; AND~~
~~**WHEN** static grep runs `grep -n 'ammo' src/.../player_movement.gd src/.../player_snapshot.gd`,~~
~~**THEN** zero matches in both files (DEC-PM-3 isolation: ammo is Player Shooting #7 territory).~~

**AC-H1-05-v2** *(Logic GUT + Static grep — BLOCKING)* — DEC-PM-3 v2 ammo-captured (ADR-0002 Amendment 2).
**GIVEN** `PlayerSnapshot` Resource schema is defined,
**WHEN** the test inspects `PlayerSnapshot.get_property_list()` (or equivalent reflection),
**THEN** property `ammo_count: int` EXISTS on the schema; AND
**GIVEN** a snapshot `snap` with `ammo_count=7`, `current_weapon_id=2`, and the other 6 PM-owned fields set per AC-H1-01 fixture,
**WHEN** `PlayerMovement.restore_from_snapshot(snap)` runs (PM side),
**THEN** PM does **NOT** mutate `WeaponSlot.ammo_count` directly — `WeaponSlot.ammo_count` is the same value it held before `restore_from_snapshot()` was invoked (write authority is Weapon #7, OQ-PM-NEW); AND
**WHEN** TRC orchestration completes the rewind (Weapon-side restoration triggered by `rewind_completed` signal — Weapon GDD #7 authoring obligation),
**THEN** `WeaponSlot.ammo_count == snap.ammo_count` after the orchestration tick.
*Resolves: time-rewind.md OQ-1 / E-22 / F6 (b) variant; obligates: Player Shooting #7 GDD H section reciprocal AC + ADR-0002 Amendment 2 stub at `docs/architecture/adr-0002-time-rewind-storage-format.md`.*

**AC-H1-06** *(Logic GUT — BLOCKING)* — T14-T17 4-branch derive correctness.
**GIVEN** four fixture snapshots covering the 4 valid branches:
- *Snap-T14*: `is_grounded=true, abs(velocity.x) < abs_vel_x_eps`
- *Snap-T15*: `is_grounded=true, abs(velocity.x) >= abs_vel_x_eps`
- *Snap-T16*: `is_grounded=false, velocity.y < 0`
- *Snap-T17*: `is_grounded=false, velocity.y >= 0`

**WHEN** `_derive_movement_state(snap)` is called for each,
**THEN** returns are: `IdleState`, `RunState`, `JumpState`, `FallState` respectively. No call ever returns `DeadState` or `AimLockState`.
**AND** for the pathological case (`is_grounded=true, velocity.y < 0` — E-PM-2 GAP-1 Decision A 2026-05-10 *is_grounded wins*): derive returns `IdleState` or `RunState` per `velocity.x` (is_grounded authority); the next-tick Phase 5 `move_and_slide()` + Phase 6a re-evaluation auto-corrects via T5 → Fall. Test asserts the 1-tick state at restore-tick is Idle/Run, NOT Jump.
*Cross-ref: state-machine.md AC-09 (force_re_enter mechanics).*

**AC-H1-07** *(Logic GUT — BLOCKING)* — AnimationPlayer `callback_mode_method = IMMEDIATE` boot invariant (B3 fix 2026-05-11).
**GIVEN** `PlayerMovement._ready()` has completed and the test scene's `AnimationPlayer` node (`$AnimationPlayer`, addressed via `_anim`) is initialized,
**WHEN** the test reads `_anim.callback_mode_method`,
**THEN** the value equals `AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE` (== 1) — NOT the Godot 4.6 default `ANIMATION_CALLBACK_MODE_METHOD_DEFERRED` (== 0).
**AND WHEN** the test invokes `_anim.seek(t, true)` where the animation at `t` contains a method-track key calling a no-op tracer method on `PlayerMovement` (e.g., `_test_tracer_callback`),
**THEN** the tracer method MUST fire *within the seek() call stack* (synchronous to the seek invocation) — verifiable via a counter incremented before/after the seek call in the test body. Tracer counter post-`seek()` == 1; tracer counter mid-`seek()` (inspected via guard) == 1.
**AND** the boot-time `assert` in `PlayerMovement._ready()` (per C.4.1 init pattern) MUST fire in debug builds if `_anim.callback_mode_method` is reverted to `DEFERRED` post-`_ready()`. Static grep `grep -nE 'callback_mode_method\s*=\s*AnimationMixer\.ANIMATION_CALLBACK_MODE_METHOD_(DEFERRED|MANUAL)' player_movement.gd` returns zero matches (only IMMEDIATE assignment allowed in the file — single-writer).
*B3 fix 2026-05-11 — Godot 4.6 `AnimationMixer.callback_mode_method` default verified DEFERRED via WebFetch (https://docs.godotengine.org/en/stable/classes/class_animationmixer.html); recorded in `docs/engine-reference/godot/modules/animation.md` "Critical Default" section. DEFERRED silently breaks the entire `_is_restoring` guard model (C.4.1/4.2/4.4/4.5 + AC-H1-02/03/04 + VA.5 method-track policy) — method-track callbacks would fire on the next idle frame *after* Phase 1 auto-cleared the guard, producing stale spawns/cues during rewind restoration. IMMEDIATE override is mandatory for the entire single-writer architecture. Engine-version-critical (post-LLM-cutoff Godot 4.6 May 2025 → Jan 2026).*

### H.2 Movement State Machine (PlayerMovementSM)

> **Coverage**: C.2.1 6 states · C.2.2 17-row T-matrix · C.2.3 trigger constraints · C.2.4 input ignore rules · C.2.5 framework atomicity (M2 reuse). **5 AC** (all BLOCKING).

**AC-H2-01** *(Logic GUT — BLOCKING)* — AimLock blocks jump buffer (C.2.4 input ignore).
**GIVEN** `PlayerMovementSM` is in `AimLockState` AND a `jump_just_pressed = true` is injected in Phase 2,
**WHEN** Phase 3a evaluates transitions,
**THEN** `JumpState` is NOT entered; `current_state` remains `AimLockState`; **neither** `_jump_buffer_frame` **nor** `_jump_buffer_active` is updated (buffer registration skipped — Formula 4 pair-set blocked). `_jump_buffer_active` remains at its pre-press value (typically `false`). Verified on the press tick AND the following tick.
*Cross-ref obligation: Input System #1 must include reciprocal AC asserting `aim_lock` hold + `jump` press are independent input events with PM ignore semantics — F.4.2 obligation.*

**AC-H2-02** *(Logic GUT — BLOCKING)* — T13 signal-reactive Dead entry.
**GIVEN** `PlayerMovementSM` is in `Idle` or `Run` AND `EchoLifecycleSM.state_changed` fires with value `DYING`,
**WHEN** `_on_lifecycle_state_changed` is called,
**THEN** `PlayerMovementSM` transitions to `DeadState`; `velocity == Vector2.ZERO`; `state_changed` emits with `to == &"DeadState"` exactly 1 time.
**AND GIVEN** the signal fires with value `DEAD`,
**THEN** same result (T13 handles DYING and DEAD identically). Verify also: PM does NOT poll `EchoLifecycleSM.current_state` during the test (signal-reactive only — C.2.3 forbidden).

**AC-H2-03** *(Logic GUT — BLOCKING)* — Variable jump cut (T7).
**GIVEN** `PlayerMovementSM` is in `JumpState` with `velocity.y = -426.7` (mid-rise after 4 frames of g_rising integration; derived from D.2 worked example),
**WHEN** `jump_released = true` is injected in Phase 3a,
**THEN** `velocity.y = max(-426.7, -160.0) = -160.0` exactly (cut applied); `FallState` entered the same tick; next Phase 4 uses `gravity_falling = 1620` instead of `gravity_rising = 800`.
*D.2 Formula 5 + Frame-4 cut path worked example.*

**AC-H2-04** *(Integration GUT — BLOCKING)* — M2 framework atomicity reuse.
**GIVEN** `PlayerMovementSM` extends framework `StateMachine` AND a `transition_to(DeadState)` is called mid-execution of a `Run → Jump` transition (framework `_is_transitioning == true`),
**WHEN** the second transition is requested,
**THEN** Dead transition is enqueued (NOT dropped, NOT immediately applied); after `Run → Jump` completes, Dead dispatches atomically; final `current_state == DeadState`. `state_changed` emits exactly twice in order: `Run → Jump` then `Jump → Dead`. No state skipped.
*Mirror: state-machine.md AC-23 (full-scene M2 reuse integration gate); H2-04 is the unit-level component test.*

**AC-H2-05** *(Logic GUT — BLOCKING)* — REWINDING → ALIVE no-op guard.
**GIVEN** `PlayerMovementSM.current_state` is already `IdleState` (or any non-Dead state, having been re-derived by `restore_from_snapshot()` 30 frames earlier) AND `EchoLifecycleSM.state_changed` fires with value `ALIVE`,
**WHEN** `_on_lifecycle_state_changed` handles ALIVE,
**THEN** the guard `if current_state is not DeadState: return` fires; `current_state` is NOT mutated; `state_changed` does NOT emit. `DeadState` entry count over the full restore + ALIVE sequence stays at 1 (boot-to-restore — only the initial Dead before restore).
*C.2.2 T13 note + C.4.3 intentional omission. Prevents double-transition on the 30-frame-deferred ALIVE signal.*

### H.3 Per-Tick Determinism

> **Coverage**: C.3.1 7-phase ordering · C.3.2 forbidden patterns · 1000-cycle bit-identical PlayerSnapshot · `delta = 1/60` invariant · ADR-0003 `process_physics_priority = 0` sequencing with TRC=1. **4 AC**.

**AC-H3-01** *(Integration GUT — BLOCKING)* — 1000-cycle bit-identical PlayerSnapshot.
**GIVEN** a scripted test sequence with fixed `move_axis` input timeline, fixed `PlayerMovementTuning` (G.1 Tier 1 defaults), fixed starting `global_position` and `velocity`, AND the same machine + build,
**WHEN** the sequence runs 1000 times from identical starting state,
**THEN** all 7 `PlayerSnapshot` fields captured at every tick N are bit-identical across all 1000 runs. Specifically: `global_position`, `velocity`, `facing_direction`, `current_animation_name`, `current_animation_time`, `current_weapon_id`, `is_grounded` produce identical values per (run, tick) pair.
**FORBIDDEN**: run-1 capture as expected baseline (per damage.md AC-29 precedent — expected order must be defined as a `const` array, never self-captured).
*Mirror: time-rewind.md AC-F1 (bit-identical PlayerSnapshot from TRC ring buffer side) + AC-F2 (post-rewind position identity). Together form full ADR-0003 R-RT3-01 validation.*

**AC-H3-02** *(Logic GUT + Static grep — BLOCKING)* — Delta accumulator absence (GREP-PM-2).
**GIVEN** `player_movement.gd` is committed,
**WHEN** static grep runs `grep -nE '[a-zA-Z_]+\s*\+=\s*delta' player_movement.gd`,
**THEN** the only matches are the two authorised per-tick velocity integrations in Phase 4 (`velocity.y += gravity_rising * delta` and `velocity.y += gravity_falling * delta`). Zero matches on counter-style accumulators (`_coyote_remaining += delta`, `_elapsed += delta`, etc).
**AND GIVEN** an integration GUT runs `_physics_process` with `delta = 1.0/60.0`,
**WHEN** Phase 4 executes the rising-gravity integration once,
**THEN** post-integration `velocity.y` differs from pre-integration by exactly `gravity_rising / 60.0 ≈ 13.333 px/s` (tolerance ±0.001).
*C.3.2 forbidden + GREP-PM-2.*

**AC-H3-03** *(Integration GUT + Static grep — BLOCKING, GAP-3 Decision A 2026-05-10)* — `process_physics_priority` Inspector-set + ordering.
**(a) Static grep**: `grep -nE 'process_physics_priority\s*=\s*0' src/<player_movement_scene>.tscn` MUST return exactly 1 match (.tscn-side enforcement).
**(b) Static grep negative**: `grep -nE 'process_physics_priority\s*=' src/.../player_movement.gd` MUST return zero matches (no script override allowed).
**(c) Runtime GUT**: a test scene with `PlayerMovement` (priority=0) and a `TimeRewindController` stub (priority=1) runs one physics frame; a spy in TRC's `_physics_process` records its read values for the 7 PlayerSnapshot fields; those values match PM's Phase 6c final state byte-for-byte. Additionally `assert(player_movement.process_physics_priority == 0)` and `assert(trc.process_physics_priority == 1)`.
*C.1.1 `.tscn` Inspector obligation + ADR-0003 priority ladder. Belt + suspenders per GAP-3 resolution.*

**AC-H3-04** *(Static grep / CI — BLOCKING)* — Wall-clock + async + single-arg seek absence.
**GIVEN** `player_movement.gd` is committed,
**WHEN** CI runs `tools/ci/pm_static_check.sh` (authored 2026-05-11 per B2 fix),
**THEN** zero matches for each of:
- `Time\.get_ticks_msec\|OS\.get_ticks_msec\|Time\.get_unix_time` (GREP-PM-3, ADR-0003 determinism clock)
- `await\s+get_tree\(\)\.physics_frame\|await\s+.*\.timeout` (GREP-PM-6, async transition forbidden)
- `_anim\.seek\s*\([^,)]*\)` matching single-arg `seek(time)` without the second `true` arg (GREP-PM-4, time-rewind.md I4 single source)

Any non-zero match → CI fail. False-positive exemption: `# ALLOW-PM-GREP-N` inline comment with justification.
*C.3.2 forbidden patterns + matches damage.md AC-21 precedent.*

### H.4 Input → Velocity Mapping

> **Coverage**: D.1 run accel/decel formula · D.4 facing 8-way encoding · C.5 input contract · E-PM-9 deadzone provisional. **4 AC**.

**AC-H4-01** *(Logic GUT — BLOCKING)* — Run accel reaches v_max in exactly run_accel_frames.
**GIVEN** `PlayerMovement` is in `RunState` with Tier 1 defaults (`run_top_speed = 200.0`, `run_accel_frames = 6`) AND `velocity.x == 0.0`,
**WHEN** Phase 4 executes for 6 consecutive ticks with `move_axis.x = 1.0`,
**THEN** `velocity.x` at end of tick 6 == `200.0` exactly (cap reached); at no intermediate tick does `velocity.x` exceed `200.0`. At end of tick 1, `velocity.x ≈ 33.333` (tolerance ±0.01).
**AND GIVEN** sign-reversal scenario (start `velocity.x = +200, move_axis.x = -1.0`),
**WHEN** ticks elapse,
**THEN** `velocity.x` reaches 0 at tick 8 (decel phase, `run_decel_frames = 8`) and reaches `-200` at tick 14 (decel 8 + accel 6). Per D.1 worked example.

**AC-H4-02** *(Logic GUT — BLOCKING)* — 8-way facing encoding worked-example sequence.
**GIVEN** outside-aim_lock with `facing_threshold_outside = 0.2`, the input sequence Frame 1 = `(0.8, 0.0)`, Frame 2 = `(0.8, -0.7)`, Frame 3 = `(0.05, 0.0)`, Frame 4 = `(0.0, 0.0)`, Frame 5 = `(-0.9, 0.0)`,
**WHEN** Phase 6c runs each frame,
**THEN** `facing_direction` sequence is exactly: `0` (E) → `1` (NE) → `1` (preserve, both axes < 0.2) → `1` (preserve, (0,0)) → `4` (W).
**AND GIVEN** `AimLockState` with `facing_threshold_aim_lock = 0.1`, input `(0.0, -0.15)`,
**WHEN** Phase 6c runs,
**THEN** `facing_direction = 2` (N) — the finer threshold passes where `0.2` would preserve.
*D.4 worked example verbatim.*

**AC-H4-03** *(Logic GUT — BLOCKING)* — AimLock freezes movement but updates facing.
**GIVEN** `PlayerMovementSM` is in `AimLockState` AND `move_axis = (0.5, -0.8)`,
**WHEN** Phase 4 executes,
**THEN** `velocity == Vector2.ZERO` (movement frozen — DEC-PM-2 hold semantics);
**AND** Phase 6c executes,
**THEN** `facing_direction == 1` (NE — encoding of `(sign(0.5), sign(-0.8)) = (1,-1)`). `RunState` is NOT entered despite non-zero `move_axis.x` (C.2.4 input ignore).

**AC-H4-04** *(Manual / Playtest — ADVISORY)* — E-PM-9 deadzone observation.
**GIVEN** Input System #1 GDD is not yet authored AND `project.godot` Tier 1 deadzone defaults are configured,
**WHEN** a 5-minute Tier 1 prototype playtest is conducted with a controller (analog stick at near-rest position),
**THEN** no unintended `RunState` entry is observable from stick noise below 0.2; documented in `production/qa/evidence/pm-deadzone-playtest-[date].md`. Provisional pending Input System #1 AC (C.5.3 deadzone obligation).
*F.4.2 obligation: Input #1 must include deadzone enforcement AC (0.2 default per C.5.3); upgrades H4-04 from ADVISORY to obsolete on Input #1 GDD authoring.*

### H.5 Jump / Gravity / Coyote / Buffer

> **Coverage**: D.2 jump impulse · apex height invariant (144 px) · variable cut · D.3 coyote/buffer predicates · **active-flag reset on Dead/restore (B1 fix 2026-05-11 — was INT_MIN sentinel)**. **4 AC** (count-34 plan: coyote + buffer collapsed into one compound AC).

**AC-H5-01** *(Logic GUT — BLOCKING)* — Jump impulse + apex height invariant.
**GIVEN** `PlayerMovement` is in `RunState` (grounded) with Tier 1 defaults (`jump_velocity_initial = 480.0`, `gravity_rising = 800.0`),
**WHEN** `jump_pressed = true` is injected (T3) and `JumpState.enter()` executes,
**THEN** `velocity.y == -480.0` exactly.
**AND WHEN** Phase 4 runs for 36 ticks with jump held (no release),
**THEN** `velocity.y >= 0.0` is reached at tick 36 (apex predicate triggers T6); maximum upward `global_position.y` displacement from launch equals `480² / (2 × 800) = 144 px` exactly (tolerance ±1 px).
*D.2 Formula 2 — Tier 1 height invariant lock (Decision A 2026-05-10).*

**AC-H5-02** *(Logic GUT — BLOCKING)* — Variable jump cut + post-cut rise.
**GIVEN** `JumpState` is active with `velocity.y = -426.7` (Frame 4 of full press, derived from D.2 worked example),
**WHEN** `jump_released = true` is injected and Phase 3a evaluates T7,
**THEN** `velocity.y = max(-426.7, -160.0) = -160.0` exactly; `FallState` entered same tick; gravity switches to `gravity_falling = 1620.0`.
**AND WHEN** post-cut Phase 4 ticks elapse until `velocity.y >= 0`,
**THEN** additional upward rise from `velocity.y = -160` equals `160² / (2 × 1620) ≈ 7.901 px` (tolerance ±0.5 px).
*D.2 Formula 5 + Frame-4 cut path worked example.*

**AC-H5-03** *(Logic GUT — BLOCKING, COMPOUND)* — Coyote + jump buffer predicates (boundary fixtures).
Combined per count-34 plan; both predicates use `Engine.get_physics_frames()` differencing with identical Tier 1 defaults (`coyote_frames = 6`, `jump_buffer_frames = 6`).

*Coyote case:*
**GIVEN** PM was grounded at frame N (`_last_grounded_frame = N`), is in `FallState`, and `coyote_frames = 6`,
**WHEN** `jump_pressed = true` fires at frame N+3,
**THEN** `coyote_eligible = (N+3 - N) <= 6 = true`; T3 fires; `JumpState` entered.
**AND WHEN** `jump_pressed` fires at frame N+7,
**THEN** `coyote_eligible = false`; T3 does NOT fire (window expired).

*Buffer case:*
**GIVEN** `jump_pressed = true` fires at frame M while `is_grounded = false` (Formula 4 sets `_jump_buffer_frame = M` AND `_jump_buffer_active = true`), `jump_buffer_frames = 6`,
**WHEN** PM lands at frame M+3,
**THEN** `jump_buffered = (_jump_buffer_active AND (M+3 - M) <= 6 AND is_grounded) = TRUE AND TRUE AND TRUE = true`; T3 auto-fires on landing tick without fresh `jump_pressed` input. Post-fire: `_jump_buffer_active = false` (buffer consumed).
**AND WHEN** PM lands at frame M+7,
**THEN** `jump_buffered = false` (math blocked; `_jump_buffer_active` still true but `(M+7-M)=7 > 6`); no auto-T3.
*D.3 Formulas 1, 2, 3 — both PASS and FAIL boundaries required per AC.*

**AC-H5-04** *(Logic GUT — BLOCKING)* — Active-flag reset on Dead + restore (B1 fix 2026-05-11).
**GIVEN** `_jump_buffer_active = true` AND `_jump_buffer_frame = M` (valid buffer registered at frame M) AND `PlayerMovementSM` transitions to `DeadState` (T13),
**WHEN** `DeadState.enter()` fires,
**THEN** `_jump_buffer_active == false` AND `_jump_buffer_frame == 0` AND `_grounded_history_valid == false` AND `_last_grounded_frame == 0`.
**AND WHEN** `restore_from_snapshot(snap)` is later called (Step 4),
**THEN** `_jump_buffer_active == false` (re-cleared, idempotent); `_grounded_history_valid == snap.is_grounded`; `_last_grounded_frame == Engine.get_physics_frames()` if `snap.is_grounded` else `0`.
**AND WHEN** the post-restore tick evaluates `jump_buffered` (C.3.3 predicate),
**THEN** `jump_buffered == false` via boolean short-circuit — `_jump_buffer_active == false` AND-shortcircuits *before* any subtraction `(current_frame - _jump_buffer_frame)` is evaluated. Equivalently, `coyote_eligible == false` via `_grounded_history_valid == false` short-circuit when `not snap.is_grounded`.
**AND** no phantom jump fires without fresh `jump_pressed` input. **Negative-case verification**: With `_jump_buffer_active = false` and `_jump_buffer_frame = 0`, set `current_frame = 1` and assert `jump_buffered == false` (regression catches accidental field reorder — the math `(1 - 0) <= 6` would be TRUE *if* the bool were missing from the predicate; only the bool short-circuit prevents the bug).
*D.3 Formula 5 + C.3.3 Scenario C. **B1 fix 2026-05-11** — sentinel `INT_MIN` pattern replaced with active-flag pattern; no int64 overflow possible by construction (the math operand pair `(current - frame)` is only evaluated when the bool is true, and when true the frame is a legitimate non-negative `Engine.get_physics_frames()` value). 3-specialist convergence (systems-designer + qa-lead + godot-gdscript-specialist). Phantom-jump prevention critical for Pillar 1 input continuity (B.4 #1).*

### H.6 Damage / SM Integration

> **Coverage**: C.3.4 mid-`move_and_slide()` cascade · C.6 Damage composition (PM hosts only) · DEC-4 single-direction (HurtBox.monitorable owned by SM, NOT PM) · E-PM-15..17 · EchoLifecycleSM signal-reactive Dead entry · **Pillar 1 first-encounter reachability (B6 fix 2026-05-11)**. **6 AC**.

**AC-H6-01** *(Integration GUT — BLOCKING)* — Mid-`move_and_slide()` lethal cascade atomicity.
**GIVEN** `PlayerMovement._physics_process` is executing Phase 5 (`move_and_slide()`) AND a collision triggers the full cascade chain `HitBox.area_entered → HurtBox.hurtbox_hit → Damage.lethal_hit_detected → EchoLifecycleSM transition_to(DyingState) → state_changed(DYING) → PlayerMovementSM._on_lifecycle_state_changed → transition_to(DeadState)`,
**WHEN** Phase 5 returns control to PM,
**THEN** `PlayerMovementSM.current_state == DeadState`; the entire cascade completed within the single physics tick; Phase 6a/6b/6c proceed with DeadState (physics-driven transitions in 6b are no-ops, 6c facing skip from Dead). Tick boundary verification: `Engine.get_physics_frames()` is identical at Phase 1 entry and Phase 7 exit (same frame).
*Mirror: damage.md AC-9 (Damage-side dying latch) + AC-36 (first-hit lock) + state-machine.md AC-15 (latch lifecycle). PM-side completion test for the full cascade.*

**AC-H6-02** *(Logic GUT — BLOCKING, NEGATIVE)* — PM does NOT directly subscribe to Damage signals.
**GIVEN** `PlayerMovement._ready()` has completed,
**WHEN** the test inspects the Damage component's signal connections via `Damage.get_signal_connection_list(&"player_hit_lethal")` and `Damage.get_signal_connection_list(&"lethal_hit_detected")`,
**THEN** no callable in either list points to a method on the `PlayerMovement` instance (or any descendant of `PlayerMovement` other than `EchoLifecycleSM` itself, which IS allowed). PM ↔ Damage is composition-only per C.6.
**AND** static grep `grep -nE 'damage.*\.connect\b|lethal_hit_detected\b|player_hit_lethal\b' player_movement.gd` returns zero matches.
*C.6 + C.2.3 forbidden subscription. Negative test prevents future regression where someone connects PM to Damage directly.*

**AC-H6-03** *(Integration GUT — BLOCKING, NEGATIVE)* — `HurtBox.monitorable` single-writer (DEC-4).
**GIVEN** `EchoLifecycleSM` transitions to `RewindingState` (REWINDING),
**WHEN** `RewindingState.enter()` fires,
**THEN** `HurtBox.monitorable == false` (verified by direct property read).
**AND WHEN** an enemy `HitBox` with matching collision layers overlaps `HurtBox` during REWINDING,
**THEN** `HitBox.area_entered` emits 0 times (Godot 4.6 Area2D: `monitorable=false` blocks detection).
**AND WHEN** `RewindingState.exit()` fires,
**THEN** `HurtBox.monitorable == true` restored.
**AND** static grep over `player_movement.gd`: `grep -nE 'HurtBox.*\.monitorable\s*=|hurt_box.*\.monitorable\s*=' player_movement.gd` returns zero matches (PM does NOT write the field at any point — DEC-4 single-direction enforce).
*Mirror: damage.md AC-12 + AC-20. Negative-direction enforcement on PM side.*

**AC-H6-04** *(Logic GUT — BLOCKING)* — `_is_restoring` clears before next-tick cascade (E-PM-17).
**GIVEN** `restore_from_snapshot(snap)` fires (T14-T17 derive) at tick T (sets `_is_restoring = true`) AND a damage cascade is set up to fire at tick T+1 mid-Phase 5,
**WHEN** tick T+1 begins Phase 1,
**THEN** `_is_restoring = false` cleared (single-tick lifetime per AC-H1-02);
**AND WHEN** Phase 5 cascade reaches `EchoLifecycleSM.state_changed(DYING) → PlayerMovementSM.transition_to(DeadState)`,
**THEN** the Dead transition fires normally (no `_is_restoring` block); final state at tick T+1 = Dead.
Total `DeadState` entry count over the two-tick (restore + re-hit) sequence = 2.
*E-PM-17 dev/test fixture scenario. In normal flow (REWINDING 30-frame i-frame active), this is unreachable; covered for fixture-bypass safety.*

**AC-H6-05** *(Integration GUT — BLOCKING)* — Mid-transition Dead enqueue + dispatch (E-PM-8).
**GIVEN** `PlayerMovementSM` is mid-`Run → Jump` transition (framework `_is_transitioning == true`) AND `EchoLifecycleSM.state_changed(DYING)` fires synchronously during Phase 5 cascade,
**WHEN** `_on_lifecycle_state_changed` calls `transition_to(DeadState)`,
**THEN** Dead enters the framework pending queue (per state-machine.md C.2.5); `Run → Jump` completes; Dead immediately dispatches; final `current_state == DeadState`. `state_changed` emits exactly: `(Run → Jump)` then `(Jump → Dead)` in that order. No state skipped, no transition dropped.
*Mirror: state-machine.md AC-07 (queue atomicity from framework side). E-PM-8 coyote + mid-`move_and_slide()` Damage overlap is covered by this same fixture.*

**AC-H6-06** *(Integration GUT — BLOCKING, B6 fix 2026-05-11)* — First-encounter rewind reachability within DYING window (Pillar 1 "learning tool" gate).

**Pillar anchor**: Pillar 1 — the 12-frame DYING grace is asserted in spec but, until this AC, was *never measured against simple-stimulus reaction time*. Without a scripted-input reachability proof, a player who never makes it from "I died" → "press rewind" within 200 ms still has theoretical access to rewind but practically dead — Pillar 1 ("punishment-free learning tool") becomes aspirational instead of contractual. AC-H6-06 closes the gap: the window's reachability is now a CI gate.

**GIVEN** the test fixture instantiates a PM scene with `PlayerMovement` in `RunState`, `EchoLifecycleSM._tokens >= 1`, and 1 active enemy `HitBox` scheduled to overlap PM at frame `N + 5`; `Input.is_action_just_pressed(&"rewind_consume")` is scripted via fixture (no human-in-loop) per AC-H4-01 input-injection pattern,

**WHEN** the test simulates the lethal hit at frame `N + 5` (Phase 5 cascade enters `DyingState` same tick; PM `transition_to(DeadState)` enqueued) AND injects `rewind_consume = true` at frame `N + 5 + 11` (window-end boundary in `[F_lethal, F_lethal + D - 1]` inclusive per `state-machine.md` D.2 predicate with `D = 12`; 11-frame reaction budget = 183 ms wall-clock @ 60 fps — within 1σ of 200 ms simple-stimulus reaction median per Welford & Brebner 1979, σ ≈ 25 ms; Pillar 1 still contractually delivered),

**THEN** `EchoLifecycleSM` transitions `DYING → REWINDING` within the input-arrival tick; `TimeRewindController.restore_from_snapshot()` fires (verified via 1-call spy on PM `_is_restoring` toggling); `PlayerMovementSM.current_state` is NOT `DeadState`-final after the REWINDING entry tick (the queued Dead is cancelled by signal-reactive ALIVE re-derive via T14-T17 30 frames later); `PlayerMovement.global_position` matches the position at frame `N - 4` (9 frames pre-impact per `time-rewind.md` Rule 4 + Rule 9 `RESTORE_OFFSET_FRAMES`).

**AND boundary FAIL case**: same setup but `rewind_consume` injected at frame `N + 5 + 12` (1 frame past grace; `F_input = F_lethal + D = N + 5 + 12 > F_lethal + D - 1 = N + 5 + 11` violates SM D.2 predicate) → `EchoLifecycleSM` transitions `DYING → DEAD`; `restore_from_snapshot()` does NOT fire (spy confirms 0 calls); PM `current_state == DeadState` final.

**AND token-zero FAIL case** (Pillar 4 anti-fantasy "not a safety net"): same boundary input at `N + 5 + 11` but `_tokens == 0` → `try_consume_rewind()` returns false; Token Denied audio cue plays (per `time-rewind.md` Audio Events table); `DYING → DEAD` regardless. Confirms the reachability gate is *capacity-gated*, not *latency-gated*.

*Mirror: `time-rewind.md` Rule 4 (12-frame grace) + Rule 7 (token-zero no-op) + Rule 9 (try_consume_rewind sequence); `damage.md` DEC-6 (hazard_grace_frames=12 + B-R4-1 effective 13); `state-machine.md` AC-15 (DYING→DEAD direct path). Reachability is a PM-side fixture because PM hosts the cascade endpoint (DeadState entry + restore_from_snapshot call site).*

### H.7 Static Analysis & Forbidden Patterns

> **Coverage**: G.4.1 INV-1..7 assertion fixtures · G.4.2 GREP-PM-1..7 regex CI gates · anim method-track `_is_restoring` guard scan · matches damage.md AC-21/29 precedent. **5 AC**.

**AC-H7-01** *(Logic GUT — BLOCKING)* — Tuning invariant assertions fire (INV-1..6).
**GIVEN** `PlayerMovementTuning` Resource is instantiated with each of these 6 violation fixtures (one per test case):
- (a) `gravity_falling = 799.0, gravity_rising = 800.0` → INV-1 violation
- (b) `air_control_coefficient = 1.0` → INV-2 violation
- (c) `abs_vel_x_eps = 0.0` → INV-3 violation
- (d) `facing_threshold_aim_lock = 0.25, facing_threshold_outside = 0.2` → INV-4 violation
- (e) `jump_velocity_initial = 100.0, gravity_rising = 800.0` (apex `100²/(2×800) = 6.25 px < 50 px`) → INV-5 violation
- (f) `coyote_frames = 10, jump_buffer_frames = 8` (sum = 18 > 16) → INV-6 violation

**WHEN** `tuning._validate()` is called for each fixture in a debug build (`OS.is_debug_build() == true`),
**THEN** each fires exactly 1 `assert()` failure (captured via push_error or assertion-trap mechanism).
**AND** a baseline-valid `PlayerMovementTuning` (G.1 Tier 1 defaults) calls `_validate()` with 0 assertions firing.
*G.4.1 INV-1..6 catalogue.*

**AC-H7-02** *(Logic GUT — ADVISORY/DEFERRED)* — INV-7 deferred enforcement gate.
**GIVEN** Tier 1 has no setter on `PlayerMovementTuning` fields (direct `@export` assignment only),
**WHEN** the test scans `PlayerMovementTuning` script for `set_*` setter methods,
**THEN** zero setters exist (INV-7 trivially passes — no setter = no runtime mutation path during restore).
**AND IF** a setter is later introduced for any tuning field,
**THEN** the test FAIL — the regression test fixture: inject a setter stub that calls `assert(not _is_restoring)` → invoke during `_is_restoring=true` → assert guard fires.
*G.4.1 INV-7 (conditional/deferred). Documents the contract for future Tier 2 setter introduction; passes trivially in Tier 1.*

**AC-H7-03** *(Static grep / CI — BLOCKING)* — External direct-write + `_is_restoring` mutation + Phase 6a `is_on_floor` enforce.
**GIVEN** `player_movement.gd` and all files in `src/` are committed,
**WHEN** CI runs `tools/ci/pm_static_check.sh` (authored 2026-05-11 per B2 fix),
**THEN** zero matches for each of:
- (a) GREP-PM-1: `grep -rnE '\.global_position\s*=|\.velocity\s*=|\.facing_direction\s*=|\._current_weapon_id\s*=|\._is_grounded\s*=' src/ --exclude=player_movement.gd` (external write to PM 7 fields forbidden)
- (b) GREP-PM-5: `grep -nE '_is_restoring\s*=\s*(true|false)' player_movement.gd` outside the `restore_from_snapshot()` method body (single-writer enforce)
- (c) GREP-PM-7: `grep -cE 'is_on_floor\(\)' player_movement.gd` returns exactly 1 (the Phase 6a single call site; any additional call = stale-value risk per C.3.2)

False-positive exemption: `# ALLOW-PM-GREP-N` inline comment + justification (matches damage.md AC-21 precedent).
*G.4.2 GREP-PM-1, 5, 7 consolidated.*

**AC-H7-04** *(Static grep / CI — BLOCKING, GAP-6 Decision A 2026-05-10; awk rewritten 2026-05-11 per B4 fix)* — Anim method-track `_is_restoring` guard universal scan.
**GIVEN** `player_movement.gd` is committed,
**WHEN** CI runs `tools/ci/pm_static_check.sh` (B2 fix 2026-05-11) which executes a state-machine awk over each `_on_anim_*` function body:
```bash
# Per _on_anim_* function: extract body via state-machine awk.
# Enter on `func FN[non-word]`; exit on next `^func ` or `^class `.
# Word-boundary uses [^a-zA-Z0-9_] for BSD-awk compat (macOS).
grep -nE '^func _on_anim_[a-z_]+' player_movement.gd \
  | sed -E 's/^[0-9]+:func[[:space:]]+(_on_anim_[a-z_]+).*/\1/' \
  | while read FN; do
      [[ -z "$FN" ]] && continue
      BODY=$(awk -v fn="$FN" '
        BEGIN { in_block = 0 }
        $0 ~ ("^func " fn "[^a-zA-Z0-9_]") { in_block = 1; print; next }
        in_block && /^(func |class )/ { in_block = 0 }
        in_block { print }
      ' player_movement.gd)
      if ! echo "$BODY" | grep -qE '_is_restoring' \
         && ! echo "$BODY" | grep -qE '# ALLOW-PM-GREP-4'; then
          echo "VIOLATION: $FN lacks _is_restoring guard"
          exit 1
      fi
  done
```
**Critical fix history (B4)**: The 2026-05-10 inline version used `awk "/^func $func_name/,/^func |^[a-zA-Z_]+/"` — the end pattern `^[a-zA-Z_]+` matches the start `func` line itself (because `func` starts with `f`), so the range collapsed to a single line and the body was *never inspected*. Every `_on_anim_*` callback silently passed regardless of guard presence. The state-machine awk above is the correct extractor; **`tools/ci/pm_static_check.sh` is the implementation source of truth** — the inline snippet here is documentation, not the executed code path.

**THEN** every `_on_anim_*` function in `player_movement.gd` either contains `_is_restoring` (`if _is_restoring: return` typically as first guard line) OR has `# ALLOW-PM-GREP-4: <justification>` inline comment.
Universal guard policy with explicit opt-out (lightweight SFX e.g. footstep can opt out via comment per Audio GDD decision — F.4.2 obligation gate).
*C.4.4 obligation. Partial guard = silent regression risk. Validated by 3-fixture smoke test (Tier 1 graceful pass / violation fixture / clean fixture) before B4 lock.*

**AC-H7-05** *(Logic GUT — BLOCKING)* — 1000-cycle PlayerMovementSM transition determinism.
**GIVEN** a fixture stubs `Engine.get_physics_frames()` to a deterministic counter AND scripts a fixed input sequence producing transitions `Idle → Run → Jump → Fall → Idle` (with apex T6, landing T8),
**WHEN** the fixture executes 1000 times from identical seed,
**THEN** `state_changed` emit sequence is byte-identical across all 1000 cycles. Expected sequence is defined by the fixture as:
```gdscript
const EXPECTED_TRANSITIONS: Array[StringName] = [
    &"Idle", &"Run", &"Jump", &"Fall", &"Idle"  # exact order; tick numbers also fixed
]
```
**FORBIDDEN**: run-1 self-capture (per damage.md AC-29 precedent — expected sequence must be a `const`, never the result of run-1).
*G.4.1 determinism + extends damage.md AC-29 to PM SM layer.*

### H.8 Bidirectional Update Verification

> **Coverage**: F.4.1 6 cross-doc reciprocals (compound — verified at architecture.yaml + grep level) + F.4.2 future GDD obligation registry. **1 compound AC** (count-34 plan: collapse 3→1).

**AC-H8-01** *(Manual / PR Review checklist — ADVISORY, COMPOUND)* — F.4.1 6-edit cross-doc reciprocals all present.
**GIVEN** Session 9 has applied the F.4.1 cross-doc edits batch (per `production/session-state/active.md` Session 9 close-out),
**WHEN** the PR Review reviewer runs the following grep checks against the repository working tree,
**THEN** all 6 patterns return matches consistent with the F.4.1 spec:

| # | F.4.1 obligation | Verification command | Expected result |
|---|------------------|----------------------|-----------------|
| 1 | `time-rewind.md` F.1 row #6 — `*(provisional)*` removed + 7-field interface locked + `restore_from_snapshot(snap: PlayerSnapshot) -> void` signature + `_is_restoring` cross-link | `grep -n 'provisional' design/gdd/time-rewind.md \| grep -i 'player_movement\|player movement\|#6'` | 0 matches (provisional marker gone) |
| 2 | `state-machine.md` F.2 row #6 — `PlayerMovementSM extends StateMachine` M2 reuse + flat composition + Dead reactive | `grep -n 'PlayerMovementSM\|extends StateMachine' design/gdd/state-machine.md \| grep -i 'F\.2\|row 6\|#6'` | ≥1 match in F.2 row #6 region naming `PlayerMovementSM` + `extends StateMachine` |
| 3 | `state-machine.md` C.2.1 lines 178-188 — node tree corrected to `PlayerMovement (CharacterBody2D, root)` model (Round 5 cross-doc-contradiction exception) | `grep -n 'CharacterBody2D' design/gdd/state-machine.md \| grep -i 'PlayerMovement'` | ≥1 match showing PM is the CharacterBody2D root, not split into ECHO + PlayerMovement Node |
| 4 | `damage.md` F.1 row — ECHO HurtBox + HitBox + Damage are PM child nodes; HurtBox lifecycle = SM, ownership = PM | `grep -n 'PlayerMovement\|player_movement' design/gdd/damage.md` | ≥1 match in F.1 row showing host/lifecycle ownership split |
| 5 | `design/gdd/systems-index.md` System #6 row Status = `Designed (2026-05-10)` + design doc link + Progress Tracker counts updated + Last Updated header | `grep -nE 'Designed.*2026-05-10\|player-movement\.md' design/gdd/systems-index.md` | ≥2 matches (status row + Last Updated entry) |
| 6 | `docs/registry/architecture.yaml` 4 new entries: `state_ownership.player_movement_state`, `interfaces.player_movement_snapshot`, `forbidden_patterns.delta_accumulator_in_movement`, `api_decisions.facing_direction_encoding` | `grep -nE 'player_movement_state\|player_movement_snapshot\|delta_accumulator_in_movement\|facing_direction_encoding' docs/registry/architecture.yaml` | exactly 4 matches (one per key) |

**AND** `python3 -c "import yaml; yaml.safe_load(open('docs/registry/architecture.yaml'))"` returns 0 exit code (YAML validity post-edits).

**Failure mode**: any check returns 0 matches when ≥1 expected, or fails YAML validation → PR Review BLOCKED until F.4.1 batch corrected.

**ADVISORY classification rationale** (per damage.md AC-26/27 precedent): document-state checks are PR Review checklist items, not BLOCKING automated CI gates, until `tools/ci/gdd_consistency_check.gd` is authored. **Upgrade path**: when CI tool is built (queued under damage.md OQ-DMG-5 tooling pattern), this AC promotes to BLOCKING with the same grep specs as the CI step.

> **F.4.2 obligations registry** (separate from this AC — *deferred to target GDD authoring*): ~~Input #1 (deadzone + AimLock-jump exclusivity)~~ ✅ **Resolved 2026-05-11** (Input #1 GDD Designed + re-review APPROVED 2026-05-11 lean mode; deadzone locked at input.md C.1.3 + AC-IN-06/07 BLOCKING; AimLock-jump exclusivity locked at input.md C.3.3 + AC-IN-16 BLOCKING; PM AC-H4-04 ADVISORY ⇒ **obsolete** — Input #1 BLOCKING ACs replace; F.4.1 #3 closure batch 2026-05-11), Player Shooting #7 (`_on_anim_spawn_bullet` `_is_restoring` guard + ammo restoration policy review), Scene Manager #2 (4-var coyote/buffer ephemeral state clear responsibility — `_grounded_history_valid`/`_last_grounded_frame`/`_jump_buffer_active`/`_jump_buffer_frame` per B1 fix; OQ-PM-1), VFX #14 (`_is_restoring` guard policy), Audio #21 (footstep guard decision — gates AC-H7-04 ALLOW exemption policy), Visual/Audio (this GDD's own pending section), HUD #13 (PM signal exposure re-eval). **Each target GDD's H section MUST include the reciprocal AC at authoring time** — this is not a current-PR PASS/FAIL gate.

---

## Visual / Audio Requirements

> **Authorship**: art-director (PRIMARY — character movement = REQUIRED visual category) + audio-director (LIGHT). Consults run 2026-05-10. Source: `design/art/art-bible.md` Sections 1/3/5/9, this GDD Sections B/C/D/E, `time-rewind.md` Visual/Audio + Rule 11.
> **Pillar anchors**: Pillar 1 (learning tool — Section VA.3 i-frame visual + restore re-entry visibility), Pillar 5 (shippable first — Section VA.6 25-frame asset budget).

### VA.1 Sprite2D facing_direction visualization (resolves C.1.4 + C.6 TBD)

**Decision (locked 2026-05-10): Option C — Modular body + 8-way arm overlay** (Contra-style cutout — pre-committed by art-bible.md Section 5 "gun barrel clearly protruding from the right side of the body — direction recognizable even during 8-way aiming").

| Element | Implementation | Asset class |
|---------|---------------|-------------|
| **Body** | Single E-facing sprite set per state. `Sprite2D.flip_h = (facing_direction in [3, 4, 5])` — W/NW/SW quadrant. **Driven by PM code (NOT AnimationPlayer track)** in `_physics_process` Phase 6c after facing_direction update. **Scope rationale (B9 fix 2026-05-11)**: `Sprite2D.flip_h` is a *scene-graph property mutation*, not a *frame-sequence animation* — same domain as `velocity` / `global_position` / VA.3 i-frame `Sprite2D.visible` toggle (which is also PM-code-driven, NOT AnimationPlayer-driven, per established precedent). VA.7 R-VA-4 AnimationPlayer mandate scope-clarified: applies to frame-sequence animations within a state (idle loop, run cycle, jump arc), not to scene-graph properties. No internal contradiction. | `char_echo_<state>.png` E-facing |
| **Gun arm overlay** | Separate `Sprite2D` child node (sibling of body Sprite2D); 8 directional sprites swapped per `facing_direction` (0..7); pose-to-pose cut, no interpolation (Section 9 Ref 2 cutout aesthetic). **Arm sprite swap (`Sprite2D.texture = _arm_pool[facing_direction]`) is also PM-code-driven per Phase 6c** — same scope as body `flip_h`. The 2-Sprite2D paper-doll architecture sits *under* one AnimationPlayer node that drives the **body's own frame sequences** (e.g., AimLock body is single-frame; idle/run are looping multi-frame); the arm Sprite2D has no AnimationPlayer track (texture-swap-only). | `char_echo_arm_<dir>_01.png` × 8 (reducible to 5 unique + 3 flip) |

**facing_direction → flip_h + arm sprite map:**

| `facing_direction` | Body `flip_h` | Arm sprite |
|---|---|---|
| 0 (E) | false | `char_echo_arm_e_01.png` |
| 1 (NE) | false | `char_echo_arm_ne_01.png` |
| 2 (N) | false | `char_echo_arm_n_01.png` |
| 3 (NW) | **true** | `char_echo_arm_nw_01.png` (or flip of NE) |
| 4 (W) | **true** | `char_echo_arm_w_01.png` (or flip of E) |
| 5 (SW) | **true** | `char_echo_arm_sw_01.png` (or flip of SE) |
| 6 (S) | false (canonical default) | `char_echo_arm_s_01.png` |
| 7 (SE) | false | `char_echo_arm_se_01.png` |

**Implementation owner**: Code-driven swap (PM `_on_facing_changed` → `_arm_sprite.texture = _arm_textures[facing_direction]`). NOT 8 parallel AnimationPlayer tracks. Delegate to `technical-artist` + `godot-gdscript-specialist` for final shape.

### VA.2 State-specific visual feedback (per PlayerMovementSM 6 states)

All ECHO body sprites authored at **60fps** (mandatory — see VA.7 RISK HIGH for Godot 4.6 `seek` precision). Cutout aesthetic per art-bible.md Section 9 Ref 2 — held poses, not tweens. Frame counts are Tier 1 floors.

| State | Frames | Hold pose / notes | Method-track keys |
|-------|--------|-------------------|-------------------|
| **Idle** | 4 (loop) | 1 base lean (E-facing reference frame for `_derive_movement_state` T14 restore target) + 2 weight-shift + 1 return; REWIND Core glow steady `#00F5D4` | none |
| **Run** | 6 (loop) | 2 contact + 2 passing + 2 transition; 45° forward lean (Section 5); cutout angular feet; NO motion blur on sprite (Section 9 Ref 2 forbids) | Frames 1 + 4 = `_on_anim_play_footstep_sfx` (foot-contact) |
| **Jump** | 2 | F1 ascent (knees drawn, REWIND Core silhouette pop) + F2 apex tuck (optional — single held pose acceptable Tier 1) | F1 = `_on_anim_play_jump_sfx` (one-shot launch) |
| **Fall** | 2 | F1 descent + F2 landing-prep (knees flex). Fall must read as committed weight (B.5 anti-fantasy: not floaty 360° control) | none on Fall; landing key on first frame of post-T8/T9 anim |
| **AimLock** | 1 | Static body anchor (no lean — squared/planted); REWIND Core glow brighter (luminosity bump) — signals "charged precision". 8-way arm overlay sweeps independently with `facing_threshold_aim_lock=0.1`. **Paper-doll aesthetic defense (B9 fix 2026-05-11)**: static body + sweeping arm = intentional Monty Python cutout aesthetic (`art-bible.md` Section 9 Ref 2). The "paper-doll" framing is the chosen visual language, NOT an unintended defect. Tier 1 mitigation = squared/planted stance + REWIND Core luminosity bump (not lean variants, which would contradict squared/planted). Tier 2+ may author 2-3 subtle weight-shift body frames (deferred, NOT BLOCKING) | T4 entry → `_on_anim_play_aimlock_press_sfx` |
| **Dead** | 1 (DYING) + 1 (DEAD) | DYING = hit-stagger held pose (NOT collapse) + REWIND Core flicker **at 2-frame cadence (6 pulses over 12-frame window — `visible=true 1f / visible=false 1f` toggle, B6 fix 2026-05-11)**; held for 12-frame `damage.md` DEC-6 grace; flicker cadence distinguishes DYING from engine hitch (≥4 Hz threshold for "intentional pulse" perception vs "stutter" per art-director A6 finding); DEAD = transition to 1-frame `#FFFFFF` whiteout (art-bible.md Section 4 — only permitted pure-white use) → scene checkpoint | none — TR owns death audio (see VA.4 DYING/DEAD row for `sfx_dying_pending_01.ogg` cue spec) |

**Cancellation by restore**: If `restore_from_snapshot()` fires during DYING grace, the stagger pose is cut by `seek(animation_time, true)` — no death animation completes. The rewind *cancels* the death, does not *reverse* it (matches B.2 fantasy + C.4.0 metaphor bridge).

### VA.3 Time-rewind cue interaction (PM role boundaries)

| Sub-effect | Owner | PM obligation |
|------------|-------|---------------|
| Cyan-magenta full-screen tear (frames 1–18 of restore) | **System #16 (Time Rewind Visual Shader)** + `time-rewind.md` Rule 11 | PM must NOT set `Sprite2D.modulate` / `self_modulate` color during REWINDING — would contaminate shader's color-inversion pass |
| 30-frame REWINDING i-frame (`HurtBox.monitorable=false`) — **PM-side visual cue** | **PM** (this GDD; flicker added to art-bible.md Section 1 Principle C as Amendment 3) | `Sprite2D.visible` 2:1 toggle (visible=true 2 frames / visible=false 1 frame) for 30 frames. Color-neutral (form signal — survives shader inversion). Driven from `EchoLifecycleSM.RewindingState._physics_update()`, NOT AnimationPlayer (avoids `seek()` interaction). Multi-channel safety per art-bible.md Section 4 backup #4 (form + audio + screen-shake redundancy) |
| Restore re-entry punctuation (the moment `restore_from_snapshot()` fires) | **TR** + screen-shake (art-bible.md Section 4) + `seek(animation_time, true)` snap | **PM owns no punctuation visual** — the frame-accurate snap to pre-death pose is itself the visual signal (B.4 #2 satisfied via 3-channel: tear + shake + pose-snap). Adding a PM-side flash would compete with shader's frame 1–3 inversion peak. VFX #14 (if it exists) may author position-localized burst on `rewind_completed` — that's its scope, not PM's |
| `rewind_completed` audio stinger | **TR + Audio GDD #21** | PM emits no audio during REWINDING — silent (audio-director Section 3 confirmed) |

### VA.4 PM-owned audio events (per state)

`Mix.Player.Movement` bus at -6 dB; ducks fully under TR's `rewind_consume`/`rewind_started` foreground stinger; peer-level with combat SFX. **Mix bus architecture is Audio GDD #21 scope** — this section provides the positioning contract.

| State / event | Trigger | Asset | Character |
|---------------|---------|-------|-----------|
| Idle ambient | none | none | **Silent Tier 1** — combat tension preserved; defer breath loop to Tier 3 if narrative-director requests |
| Run footstep | AnimationPlayer method-track keys at frames 1 + 4 of run loop; alternating L/R via internal `_footstep_side` toggle | `sfx_player_run_footstep_concrete_01..04.ogg` × 4 variants — pooled with **per-step ±5% pitch jitter (B8 fix 2026-05-11)** | Dry percussive transient ≤100 ms; cutout aesthetic (paper-on-concrete); Tier 1 single surface. **Pool + jitter pattern (resolves audio-director repetition-at-sprint finding)**: at every method-track callback, select 1 of 4 .ogg via uniform random + apply `AudioStreamPlayer.pitch_scale = 1.0 + randf_range(-0.05, 0.05)`. Perceptual math: 4 variants × continuous pitch values exceeds ~3 % human pitch-discrimination threshold (Just Noticeable Difference) — every step distinct under 12 steps/sec sprint cadence. **Asset budget unchanged** (7 PM audio files Tier 1 — VA.6 unchanged). RNG: dedicated `_footstep_rng: RandomNumberGenerator` (NOT shared `randf()` — capture/restore determinism per ADR-0003; seed from `Engine.get_physics_frames()` at callback entry to keep deterministic-replay-friendly without polluting global RNG). Industry reference: Celeste / Hollow Knight / Hades use same 4-pool + ~±5 % jitter pattern. **NOT** ±10 % (reads as different weight/surface — semantic noise). Pseudo-code: `func _on_anim_play_footstep_sfx() -> void: if _is_restoring: return # ALLOW-PM-GREP-4 (VA.5); var idx := _footstep_rng.randi() % 4; _footstep_player.stream = _footstep_pool[idx]; _footstep_player.pitch_scale = 1.0 + _footstep_rng.randf_range(-0.05, 0.05); _footstep_player.play()` |
| Jump launch | Method-track on JumpState entry frame (T3) | `sfx_player_jump_launch_01.ogg` × 1 | Synthetic exertion ≤150 ms; pitch-up whoosh / paper-tear; **NO vocal grunt (Q5 RESOLVED 2026-05-11 per B6 fix — no-grunt locked across all PM-owned audio + TR-owned DYING cue; consistent with collage SF tone register + art-bible.md Section 9 cutout aesthetic; revisitable only at Tier 3 if narrative-director requests vocalization)** |
| Fall | none | none | Silent — landing cue carries the arc |
| Land impact | Method-track on T8/T9 landing frame (knee-bend impact pose) | `sfx_player_land_impact_01.ogg` × 1 | Heavier dull thud ≤150 ms; Tier 1 single tier (no hard/soft split — defer Tier 2) |
| AimLock press | T4 entry (movement freeze + body anchor snap) | `sfx_player_aimlock_press_01.ogg` × 1 | Mechanical "lock" click ≤80 ms (camera-autofocus reference) |
| AimLock held ambient | none | none | **Silent Tier 1** — visual freeze + crosshair carries held-state communication |
| AimLock 8-way facing change tick | none | none | **Silent Tier 1** — high-frequency stick sweep would produce rattle; visual sufficient |
| DYING / DEAD | **`time-rewind.md` Audio Events table owns** (TR-side method-track on `DyingState.enter()`) | n/a | DYING = `sfx_dying_pending_01.ogg` × 1 — **synth filter sweep 80 → 400 Hz over 200 ms (B6 fix 2026-05-11; resolves orphan Q5 audio cue + audio-director AU2)**; foreground level, ducks combat SFX; NO vocal grunt (consistent with VA.4 Jump launch no-grunt lock); 200 ms duration matches 12-frame DYING grace exactly (1:1 audio-visual envelope); DEAD = silence cut (TR). PM emits zero audio in Dead state |

**Tier 1 PM-owned audio asset count: 7 .ogg files** (4 footstep + 1 jump + 1 land + 1 aim-press). All OGG Vorbis per art-bible.md Section 8 format spec.

### VA.5 Method-track guard policy (resolves GAP-6 from H.7)

Per-callback `_is_restoring` guard decisions, locking the AC-H7-04 ALLOW-PM-GREP-4 exemption matrix:

| Callback | Guard? | ALLOW-PM-GREP-4 justification | Rationale |
|----------|--------|------------------------------|-----------|
| `_on_anim_play_footstep_sfx` | **ALLOW** (opt-out) | `# ALLOW-PM-GREP-4: lightweight SFX, restore-tick double-fire masked by rewind stinger, no state mutation` | Rhythmic transient ≤100 ms; perceptually masked by TR foreground stinger; no state-corrupting side effect. **B8 fix 2026-05-11**: callback also applies ±5 % pitch jitter (VA.4) — `_footstep_rng` is a *dedicated* `RandomNumberGenerator` instance (NOT global `randf()`), so jitter consumption does not affect `PlayerSnapshot` capture/restore determinism (`Engine.get_physics_frames()` seed is identical at deterministic-replay tick N regardless of restore history). ALLOW exemption still valid: double-fire produces a single masked footstep at a slightly-different pitch, semantically identical to one normal fire |
| `_on_anim_play_landing_sfx` | **ALLOW** (opt-out) | `# ALLOW-PM-GREP-4: lightweight SFX, restore-tick double-fire masked by rewind stinger, no state mutation` | Same as footstep — pure playback, masked under stinger |
| `_on_anim_play_jump_sfx` | **GUARD required** (no opt-out) | n/a | Salient one-shot upward-motion semantic; stale fire during rewind = perceptual contradiction with backward-time visual; pitch-up character could read through stinger |
| `_on_anim_play_aimlock_press_sfx` | **GUARD required** | n/a | Mode-shift confirmation cue; semantic event (not rhythmic) — stale fire = false UI feedback |
| `_on_anim_spawn_bullet` (Player Shooting #7) | **GUARD required** | n/a | C.4.4 mandatory + state-mutation cascade (ammo decrement, projectile entity spawn) |
| `_on_anim_emit_dust_vfx` (VFX #14) | **GUARD recommended** | acceptable for opt-out per VFX GDD | Cosmetic cascade — VFX GDD owns final policy |
| `_on_anim_advance_phase_flag` (Boss Pattern #11) | n/a — not on ECHO tracks | n/a | ECHO never authors phase-flag method-tracks (forbidden — narrative state mutation cannot be safely re-fired) |

**Forbidden on PM tracks**: One-shot story flag setters (`_on_anim_trigger_lore_unlock`, `_on_anim_complete_tutorial_step`). Tier 1 has none; Tier 2+ would require both `_is_restoring` guard AND idempotency check.

### VA.6 Tier 1 asset list summary

**ECHO Body sprites (E-facing; W via runtime flip_h):**

| Animation | Frames |
|-----------|--------|
| `char_echo_idle` | 4 (loop) |
| `char_echo_run` | 6 (loop) |
| `char_echo_jump` | 2 |
| `char_echo_fall` | 2 |
| `char_echo_aimlockbody` | 1 |
| `char_echo_dying` | 1 (held 12 frames) |
| `char_echo_dead` | 1 (pre-whiteout) |
| **Subtotal** | **17 frames** |

**ECHO Gun-arm overlay**: 8 directional sprites (5 unique + 3 flip-mirrors if gun art is symmetric).

| Asset class | Count | Pixel area (48×96 body / 32×32 arm) |
|-------------|-------|-------------------------------------|
| Body frames | 17 | ~78,336 px |
| Arm frames | 8 | ~8,192 px |
| **Total ECHO** | **25 frames** | **~86 K px uncompressed** (fits 512×512 `atlas_chars_tier1.png` per art-bible.md Section 8) |

**Audio**: 7 OGG files (Section VA.4). Effort estimate (solo, placeholder pixel art OK per Pillar 5): **4–6 day art task** within Tier 1 4–6 week window — within art-bible.md Section 8 budget ("Tier 1 total assets producible solo within 4–6 weeks").

**Color palette references** (art-bible.md Section 4 swatches; v0 — confirm at first concept-art round):

| Element | Color | Hex |
|---------|-------|-----|
| Lineart / outline | Black ink stroke (2-4 px) | per Section 6 Layer 2 |
| REWIND Core glow (steady) | Neon Cyan | `#00F5D4` |
| REWIND Core glow (REWINDING / AimLock luminosity) | Rewind Cyan | `#7FFFEE` |
| Body suit base | Concrete Dark | `#1A1A1E` |
| Body suit mid-tone | Concrete Mid | `#3C3C44` |
| Helmet/mask accent | Neon Cyan | `#00F5D4` |
| DEAD whiteout | Pure White | `#FFFFFF` (single permitted use per Section 4) |

### VA.7 Engine constraints + risk flags

| # | Risk | Severity | Detail |
|---|------|----------|--------|
| R-VA-1 | `AnimationPlayer.seek(time, true)` on looping anim in Godot 4.6 | **HIGH** — post-cutoff API; OQ-PM-2 + `time-rewind.md` OQ-9 | Tier 1 prototype MUST verify before idle/run frame authoring is finalised. Looping seek may have unexpected behaviour (loop counter reset, loop-end callback fire, drift). If broken, idle + run animations have restore artifacts. |
| R-VA-2 | `Sprite2D.visible` toggle vs `self_modulate.a` for i-frame flicker | **MEDIUM** | `visible=false` removes node from draw list → batching-friendly (preserves ≤500 draw call budget per art-bible.md Section 8). `self_modulate.a` translucent path may break Forward+ batching. Lock `visible` toggle as the implementation. |
| R-VA-3 | REWIND Core `#00F5D4` inverts to ~`#FF0A2B` (magenta-red) during shader inversion frames 1–3 | **LOW** (aesthetically intentional) | Player-identification color appears to invert during peak inversion — semantically correct (reinforces inversion metaphor); do NOT shader-protect the cyan. |
| R-VA-4 | `Sprite2D` + AnimationPlayer (NOT `AnimatedSprite2D`) — pipeline lock | **LOW** | C.1.2 specifies `Sprite2D` driven by AnimationPlayer; `AnimatedSprite2D` has different `seek` API, breaks `restore_from_snapshot()`. Animator pipeline mandate: all ECHO **frame-sequence animations** (idle loop, run cycle, jump arc, fall, dying held pose, dead held pose) authored as AnimationPlayer-driven `Sprite2D` frame sequences. **Scope clarification (B9 fix 2026-05-11)**: the mandate covers *frame-sequence authoring within a state*, NOT scene-graph property mutations. The following are PM-code-driven (NOT AnimationPlayer tracks) and explicitly outside R-VA-4's scope: (a) `Sprite2D.flip_h` body mirroring per facing quadrant (VA.1 body row — Phase 6c); (b) `Sprite2D.texture` arm-overlay swap per facing_direction (VA.1 gun-arm row — Phase 6c); (c) `Sprite2D.visible` 2:1 toggle i-frame flicker (VA.3 — `EchoLifecycleSM.RewindingState._physics_update()`); (d) `Sprite2D.visible` 1:1 toggle DYING REWIND Core flicker (VA.2 Dead row — same domain). These are *scene-graph property assignments*, conceptually equivalent to `velocity` / `global_position` mutations, and authoring them as AnimationPlayer tracks would (i) bypass `_is_restoring` guards by routing through method-track callbacks (B3 fix territory), (ii) couple facing logic to anim timeline instead of input read, (iii) defeat the single-source-of-truth for facing_direction (D.4). VA.1/VA.7 internal contradiction (review-log B9 part 2) now resolved by scope precision. |
| R-VA-5 | `TextureFilter.NEAREST` on all character sprites | **LOW** | Standard project filter (art-bible.md Section 8). 48×96 sprites at 1:1 1080p are correctly served by NEAREST. |

### VA.8 Art bible amendment flags (deferred F.4.2 obligations)

art-director consult identified 4 amendments needed in `design/art/art-bible.md`. **✅ ALL 4 LANDED 2026-05-11 (B7 fix — Session 15)**:

| # | Section | Amendment | Status |
|---|---------|-----------|--------|
| ABA-1 | Section 3 (ECHO Silhouette) | Clarify ECHO sprite size: "Character visual height 48px; sprite cell 48×96px (cell space includes protrusions such as REWIND Core)." | ✅ **Landed 2026-05-11** — Section 3 "Sprite Spec" sub-block added (3 bullets: visual height / cell size / atlas placement); cites this GDD VA.6 as single source |
| ABA-2 | Section 5 (ECHO Q5 archetype table) | Add: "facing_direction visualization = flip_h body + 8-way arm overlay (Option C — System #6 Visual/Audio decision 2026-05-10)." | ✅ **Landed 2026-05-11** — new "facing visualization" row in ECHO archetype table between gun and pose; cites Contra-style modular cutout + 62.5% asset savings rationale + cites PM D.4 facing encoding |
| ABA-3 | Section 1 Principle C | Add: "REWINDING 30-frame i-frame visual = `Sprite2D.visible` 2:1 flicker (PM-owned, not a color signal — identifiable even during color inversion)." | ✅ **Landed 2026-05-11** — "REWINDING 30-frame i-frame visual rule" sub-block added with 4-bullet spec (mechanism / owner / no-color mandate / multi-channel safety) + cross-reference note distinguishing from ABA-4 DYING flicker (different cadence + owner) |
| ABA-4 | Section 2 Mood Table | Add row "DYING (12-frame grace after hit)": emotional target "urgent reversal anticipation"; visual: "hold hit-stagger pose + REWIND Core flicker; no whiteout." | ✅ **Landed 2026-05-11** — new DYING row in Mood Table inserted between Time-Rewind Active and Death & Restart; integrates B6 fix specifics (1:1 flicker cadence 30 Hz + `sfx_dying_pending_01.ogg` 200 ms envelope) |

**B6 + B7 integration**: ABA-3 (REWINDING i-frame, 2:1 30f = 20 Hz) and ABA-4 (DYING REWIND Core flicker, 1:1 12f = 30 Hz) are **distinct events with distinct cadences** — art-bible.md ABA-3 sub-block explicitly cross-references ABA-4 to prevent confusion.

> **📌 Asset Spec** — Visual/Audio requirements are defined; art bible amendments now landed. `/asset-spec system:player-movement` is now unblocked — recommended to run to produce per-asset visual descriptions, dimensions, and AI generation prompts for the 25 sprite frames + 7 audio files from this section.

---

## UI Requirements

**Tier 1 PM-owned UI: NONE.**

PlayerMovement does not author HUD elements, menus, dialogs, or any `Control` / `CanvasLayer` content in Tier 1. The system contributes *data* (velocity, facing_direction, is_grounded, current_weapon_id) and *state events* (`PlayerMovementSM.state_changed`, `EchoLifecycleSM.state_changed`) that other systems may consume for UI purposes, but PM does not host or render any UI surface.

| HUD/UI element candidate | Owner GDD | PM contribution |
|--------------------------|-----------|-----------------|
| Time-rewind token count | **HUD #13** (Approved 2026-05-13) | None — `time-rewind.md` Token State authority owns; PM agnostic to token economy (DEC-PM-3) |
| Boss phase indicator | **HUD #13** (Approved 2026-05-13) | None — Boss Pattern #11 owns |
| Health bar | Likely none (binary 1-hit lethal — `damage.md` DEC-3); if added Tier 2+, **HUD #13** owns | None |
| Aim crosshair (8-way during AimLock) | **TBD** — likely Player Shooting #7 or HUD #13 | PM exposes `facing_direction` 0..7 enum (D.4) as read-only property; consumer renders crosshair |
| Damage flash / hit indicator | `damage.md` Visual/Audio + system #16 shader | None — full-screen effect, not PM-local |
| i-frame visual cue | **PM** (Section VA.3 — `Sprite2D.visible` 2:1 flicker) | This IS PM's responsibility; documented in VA.3, not a HUD element (it's character sprite visibility, NOT a Control node overlay) |
| Pause menu / settings / weapon swap UI | UI Systems (likely separate GDD) + Input #1 | None — PM's `pause` action is read by `EchoLifecycleSM`, not PM (C.5.1) |

**F.4.2 obligation reminder**: HUD #13 GDD authoring (Tier 2) must re-evaluate whether PlayerMovement should expose any signal for UI consumption (e.g., `landed(impact_force)` for screen-shake on hard landings). Tier 1 decision: no PM signals (F.3 — relies on PlayerMovementSM `state_changed` from framework + `EchoLifecycleSM.state_changed`).

**Accessibility note** (for future Accessibility GDD coordination): PM-owned visual feedback (i-frame flicker, REWIND Core glow brightening during AimLock) uses **form + color** redundancy per `art-bible.md` Section 4 backup safety #4. The flicker (form-based) survives colorblind-mode shader transformations; the cyan luminosity bump (color-based) is the supplementary signal. Multi-channel design satisfies WCAG-style information redundancy without PM-side UI work in Tier 1.

---

## Z. Open Questions

This table is the single source for unresolved decisions deferred to subsequent GDDs / ADRs / prototype phases during GDD authoring. Each entry is updated in the target GDD's *F.4.2 obligations table* when its *closure trigger* fires.

| OQ ID | Question | Owner / Resolver | Closure trigger | Priority | Notes |
|-------|----------|-----------------|-----------------|----------|-------|
| **OQ-PM-1** | Responsibility for clearing the 4 ephemeral vars `_grounded_history_valid` / `_last_grounded_frame` / `_jump_buffer_active` / `_jump_buffer_frame` at `scene_will_change` (PM `_ready()` reconnect vs EchoLifecycleSM scene reset cascade vs Scene Manager direct call) | **Scene Manager #2 GDD** | When Scene Manager #2 GDD is authored (F.4.2 obligation) | MEDIUM (hot bug candidate when Tier 2 multi-stage is introduced) | Temporary: In Tier 1 single-stage, the **active-flag clear** in `restore_from_snapshot()` Step 4 (B1 fix 2026-05-11 — `_jump_buffer_active = false` + `_grounded_history_valid = snap.is_grounded`) is sufficient |
| **OQ-PM-2** | Godot 4.6 `AnimationPlayer.seek(time, true)` looping animation compatibility — same dependency as `time-rewind.md` OQ-9 + this GDD R-VA-1 | **Tier 1 prototype** (gameplay-programmer + technical-artist) | Verify 60fps capture + restore 1000-cycle determinism for idle/run looping anim in Tier 1 ring buffer prototype | **HIGH** (if any of loop counter reset / loop-end callback fire / seek drift occurs, idle/run frame work is blocked) | art-director recommendation: verify *before* Tier 1 art work begins |
| **OQ-PM-3** | E-PM-2 derive policy *empirical falsification* — is the 1-tick auto-correction (Idle/Run → next-tick T5 → Fall) for `is_grounded=true AND velocity.y<0` pathological snapshot visually acceptable? | **Tier 1 prototype** | Inject pathological snap via dev/test fixture + visual verification | LOW | GAP-1 Decision A 2026-05-10 *is_grounded wins* locked. If empirically broken, re-evaluate via Round 5 cross-doc-contradiction exception to add derive branch (option C dev assert) |
| **OQ-PM-4** | `Mix.Player.Movement` bus naming + compression/limiter chain + ducking automation script | **Audio GDD #21** | When Audio #21 is authored (F.4.2 obligation) | LOW | This GDD VA.4 defines only the mix priority statement; actual bus implementation is owned by Audio |
| **OQ-PM-5** | 8-way arm overlay asymmetric weapon art (e.g. left-right asymmetric gun details) — are 5 unique + 3 flip mirrors sufficient, or must all 8 be unique? | **First concept-art round** (art-director) | First concept art round | MEDIUM | art-director recommendation: confirm art simplicity in first round then lock |
| ~~**OQ-PM-6**~~ ✅ **RESOLVED 2026-05-11 (B7 fix)** | ~~Apply `art-bible.md` ABA-1..4 4 amendments~~ → **All 4 landed**: ABA-1 (Section 3 sprite spec sub-block), ABA-2 (Section 5 facing visualization row), ABA-3 (Section 1 Principle C REWINDING i-frame rule sub-block), ABA-4 (Section 2 Mood Table DYING row with B6 fix specifics integrated) | art-bible amendment pass — direct edit applied via Session 15 B7 cleanup | ✅ Landed 2026-05-11 | ~~MEDIUM~~ CLOSED | art-bible.md updated; VA.8 status table reflects landings; `/asset-spec system:player-movement` now unblocked |
| **OQ-PM-7** | E-PM-9 deadzone 0.2 — whether to add a temporary PM-side guard if noise drift occurs in Tier 1 prototype *before* Input System #1 GDD enforces it | **Input System #1 GDD** | When Input #1 GDD is authored (F.4.2 obligation) | LOW | Tier 1 temporary: directly setting `deadzone = 0.2` in `project.godot` is sufficient |
| **OQ-PM-8** | **RESOLVED 2026-05-13 by `vfx-particle.md`** — `_on_anim_emit_dust_vfx` / movement dust should be guarded during `_is_restoring`; rewind-specific local shards are separate VFX #14 effects. | **VFX #14 GDD** | Closed | LOW | VFX #14 C.1 Rule 6 keeps PM's provisional "GUARD recommended" policy as the final Tier 1 contract. |
| **OQ-PM-9** | Tier 2 gate — timing of DEC-PM-1 reconsideration trigger firing (dash / double_jump / wall_grip / hit_stun / knockback) | **Individual Tier 2 GDD amendments** | (a) when `damage.md` DEC-3 binary lethal changes OR (b) when Boss Pattern #11 knockback is introduced OR (c) when Pillar 5 is cleared | LOW | G.3 Future Knobs table is the single source for triggers |

### Resolved during authoring (reference — not blocking)

| Resolved-OQ | Resolution location | Decision |
|-------------|---------------------|----------|
| ~~OQ-1~~ AimLock floor-loss auto-release | C.2.2 T12 + AimLockState definition | Auto-released regardless of aim_lock input hold (T12); naturally re-entered on next grounded tick (E-PM-7) |
| ~~OQ-2~~ Meaning of `move_axis.y` outside aim_lock | C.2.2 + D.4 | Used for facing_direction composite 8-way update (no effect on movement — left/right movement + up/down/diagonal aiming possible during Run/Jump/Fall) |
| ~~OQ-3~~ AimLock entry grounded guard | C.2.2 T4 condition | Grounded only — aim_lock pressed in air is ignored (DEC-PM-2 hold semantics) |
| ~~OQ-4~~ Variable jump cut policy | D.2 Formula 5 + AC-H5-02 | Celeste cut: `velocity.y = max(velocity.y, -jump_cut_velocity)` (Tier 1 = 160 px/s) |
| ~~GAP-1~~ E-PM-2 derive policy | AC-H1-06 + GAP-1 Decision A 2026-05-10 | is_grounded wins → Idle/Run; 1-tick auto-correction |
| ~~GAP-3~~ `process_physics_priority` enforce | AC-H3-03 + GAP-3 Decision A 2026-05-10 | .tscn grep + runtime GUT both-direction belt-and-suspenders |
| ~~GAP-6~~ H7-04 footstep guard policy | VA.5 + GAP-6 Decision A 2026-05-10 | Universal guard + ALLOW-PM-GREP-4 per-callback opt-out (footstep/landing ALLOW; jump/aim_lock_press GUARD) |
| ~~Decision A (Visual/Audio)~~ Sprite2D facing visualization | VA.1 | Option C — flip_h body + 8-way arm overlay |
| ~~Decision G-A~~ Tuning storage | G.1 | Single `PlayerMovementTuning` Resource (.tres) |
| ~~Decision G-C~~ G.4 enforcement | G.4 | 3-layer (assert + grep + GUT) |

---

## Appendix: References

### A.1 Locked Decisions in this GDD (single source)

| ID | Section | Date | Summary |
|----|---------|------|---------|
| DEC-PM-1 | Locked Scope Decisions (top of file) | 2026-05-10 | Tier 1 PlayerMovementSM = 6 states (`idle/run/jump/fall/aim_lock/dead`); `hit_stun` removed (damage.md DEC-3 binary lethal); dash/double_jump/wall_grip Tier 2 |
| DEC-PM-2 | Locked Scope Decisions | 2026-05-10 | `aim_lock` = hold-button Cuphead-style (movement freeze + free 8-way aim); independent of `shoot` (preserves simultaneous jump+shoot fantasy); Input #1 owns final action naming |
| ~~DEC-PM-3 v1~~ | ~~Locked Scope Decisions~~ | ~~2026-05-10~~ | ~~Time-rewind restore ammo policy = "resume with live ammo"~~ — **SUPERSEDED 2026-05-11** by DEC-PM-3 v2 (B5 Pillar 1 resolution) |
| **DEC-PM-3 v2** | Locked Scope Decisions | **2026-05-11** | Time-rewind restore ammo policy = **per-tick captured `ammo_count: int`** (8th PM-noted field, Resource 9th — Weapon #7 single-writer); ADR-0002 **Amendment 2** obligatory; PM.restore_from_snapshot ignores snap.ammo_count (Weapon owns write authority — OQ-PM-NEW orchestration TBD); resolves time-rewind.md OQ-1 / E-22 / F6 (b) |
| **OQ-PM-NEW** | Z. Open Questions | 2026-05-11 | Snapshot `ammo_count` write/restore orchestration — (a) TRC orchestrates multi-target restore (PM 7-field + Weapon ammo + TRC bookkeeping atomic) vs (b) Weapon owns parallel restoration triggered by `rewind_completed` signal. Defer to Player Shooting #7 GDD authoring (Tier 1 Week 1). Either way `PM.restore_from_snapshot(snap)` signature unchanged. |
| Decision A (jump height) | D.2 (note above Formula 1) | 2026-05-10 | `jump_velocity_initial=480`, `gravity_rising=800` → `jump_height_max_px=144` exact (gameplay-programmer 144 px target preserved) |
| Decision B (facing encoding) | D.4 (note above Formula 1) | 2026-05-10 | `facing_direction: int` 0..7 enum CCW from East; `_FACING_TABLE` 9-entry LUT; `(0,0)→-1` preserve sentinel internal-only |
| Decision G-A | G.1 (Storage policy) | 2026-05-10 | All 13 owned numeric knobs in `PlayerMovementTuning extends Resource`; structural constants stay `const` in script |
| Decision G-C | G.4 | 2026-05-10 | 3-layer enforcement (assert INV-1..7 + static grep GREP-PM-1..7 + GUT H.7) — `damage.md` AC-21/29 precedent |
| GAP-1 (E-PM-2 derive) | H.1 AC-H1-06 | 2026-05-10 | Pathological `is_grounded=true AND velocity.y<0` snapshot → is_grounded wins; 1-tick auto-correct via T5 |
| GAP-3 (priority enforce) | H.3 AC-H3-03 | 2026-05-10 | `.tscn` grep + runtime GUT belt-and-suspenders for `process_physics_priority=0` Inspector-set obligation |
| GAP-6 (H7-04 guard policy) | H.7 AC-H7-04 + VA.5 | 2026-05-10 | Universal `_is_restoring` guard + per-callback `# ALLOW-PM-GREP-4` opt-out (footstep/landing ALLOW; jump/aim_lock_press/spawn_bullet GUARD) |
| Decision (Visual/Audio Option C) | VA.1 | 2026-05-10 | Sprite2D facing visualization = flip_h body + 8-way arm overlay (Contra-style modular cutout) |
| **B1 fix (active-flag pattern)** | C.3.3 / C.4.1 Step 4 / D.3 Formula 5 + var table / Scenario C / AC-H5-04 | **2026-05-11** | INT_MIN sentinel int64-overflow (`current - INT_MIN` wrap → predicate TRUE inverted → phantom jump) → bool active-flag + int frame pair pattern. `_jump_buffer_active` + `_grounded_history_valid` AND short-circuit blocks math evaluation. Overflow impossible by construction. /design-review 2026-05-11 B1 (3-specialist convergence: systems-designer + qa-lead + godot-gdscript-specialist) resolved |
| **B3 fix (IMMEDIATE callback override)** | C.4.1 `_ready()` + new AC-H1-07 + H.1 preamble 6→7 AC | **2026-05-11** | Godot 4.6 `AnimationMixer.callback_mode_method` default verified DEFERRED via WebFetch (docs.godotengine.org). PM `_ready()` forces IMMEDIATE + boot-time `assert` + static grep constraint. Under the engine default, the entire `_is_restoring` guard model (C.4.1/4.2/4.4/4.5 + AC-H1-02/03/04 + VA.5) is silently nullified — method-track callbacks fire after the guard is cleared. `docs/engine-reference/godot/modules/animation.md` "Critical Default" is the single source. /design-review 2026-05-11 B3 (gameplay-programmer) resolved. Engine-version critical (post-LLM-cutoff) |
| **B2 + B4 fix (pm_static_check.sh + awk range)** | AC-H3-04 / AC-H7-03 / AC-H7-04 + new `tools/ci/pm_static_check.sh` | **2026-05-11** | (1) **B2** — `tools/ci/pm_static_check.sh` authored (matches `damage.md` AC-21 `tools/ci/damage_static_check.sh` precedent). 3 BLOCKING ACs (H3-04, H7-03, H7-04) previously silent-passed because the script didn't exist; `(or equivalent)` hedge text in the AC bodies allowed CI to skip the gate. Script implements GREP-PM-3/4/6 (H3-04), GREP-PM-1/5/7 (H7-03), and the H7-04 per-callback guard scan, with `# ALLOW-PM-GREP-N` exemption mechanism. Tier 1 graceful pass when `src/player/player_movement.gd` doesn't yet exist; `PM_REQUIRE=1` env forces presence check. (2) **B4** — H7-04 inline awk `awk "/^func $func_name/,/^func \|^[a-zA-Z_]+/"` was structurally broken: end pattern `^[a-zA-Z_]+` matches the start `func` line itself (because `func` starts with `f`), so the awk range collapsed to a single line and the body was never inspected — every `_on_anim_*` callback silently passed regardless of guard presence. Rewritten as state-machine awk: `in_block` flag entered on `^func FN[non-word]`, exited on next `^func ` or `^class `. BSD-awk compatible (`[^a-zA-Z0-9_]` boundary, not `\b`). Validated by 3-fixture smoke test (Tier 1 graceful pass / 7-violation fixture / clean fixture all behave correctly) before lock. /design-review 2026-05-11 B2 + B4 (qa-lead, gameplay-programmer convergence) resolved |
| **B6 fix (DYING 12-frame visual + audio + reachability)** | H.6 new AC-H6-06 + VA.2 Dead row + VA.4 Jump launch + DYING/DEAD rows + time-rewind.md Audio Events DYING entry row | **2026-05-11** | **Option A locked** (creative call 2026-05-11) — keep `hazard_grace_frames = 12` (no `damage.md` cascade); resolve 3-domain convergence inside PM/TR scope: (a) **Motor reaction (game-designer G1)** — NEW AC-H6-06 first-encounter rewind reachability fixture: scripted-input injection at frame N+11 (window-end boundary in `[F_lethal, F_lethal+D-1]` inclusive per SM D.2 predicate with D=12; 11-frame reaction budget = 183 ms within 1σ of 200 ms simple-stimulus median per Welford & Brebner 1979, σ ≈ 25 ms; Pillar 1 contractually delivered) MUST trigger DYING→REWINDING; boundary FAIL at N+12 + token-zero FAIL at N+11 both required as negative cases. *(Boundary frames tightened from N+12/N+13 to N+11/N+12 by `/review-all-gdds` 2026-05-11 B3 Option β — Pillar 1 CI gate now agrees with SM D.2 + TR Rule 5 single-source predicate window.)* Pillar 1 reachability is now CI-gated instead of asserted. (b) **Visual hitch (art-director A6)** — VA.2 Dead row tightens "REWIND Core flicker" to explicit 2-frame cadence (`visible=true 1f / visible=false 1f` toggle, 6 pulses over 12 frames = 30 Hz). Distinguishes from engine hitch (≥4 Hz "intentional pulse" perception threshold). Held stagger pose unchanged. (c) **Audio cue (audio-director AU2 / orphan Q5)** — VA.4 DYING/DEAD row + time-rewind.md Audio Events DYING entry row specify `sfx_dying_pending_01.ogg`: synth filter sweep 80→400 Hz over 200 ms (1:1 envelope match to 12-frame window); foreground level, ducks combat SFX; NO vocal grunt (Q5 RESOLVED no-grunt locked across all PM + TR audio, consistent with collage SF tone register). PM-owned asset count unchanged (cue is TR-owned method-track per VA.4 row). Cross-doc reciprocal: time-rewind.md Audio Events DYING entry row updated. /design-review 2026-05-11 B6 (game-designer G1 + art-director A6 + audio-director AU2 3-domain convergence) resolved |
| **B7 fix (art-bible.md ABA-1..4 amendment pass)** | VA.8 status table (4 rows flipped to ✅ Landed) + OQ-PM-6 ✅ Resolved row + `design/art/art-bible.md` 4 amendments | **2026-05-11** | **All 4 ABA amendments landed in `art-bible.md`** via direct edit pass (Session 15 cleanup batch — `/quick-design art-bible` not required since amendments are surgical insertions with single-source authority already established): (a) **ABA-1** — `art-bible.md` Section 3 ECHO Silhouette gets new "Sprite Spec" sub-block: visual height 48px + cell 48×96px + atlas placement (`atlas_chars_tier1.png` 512×512); cites this GDD VA.6 as single source. (b) **ABA-2** — Section 5 ECHO Q5 archetype table gets new "facing visualization" row between gun and pose: `flip_h` body + 8-way arm overlay Contra-style modular cutout; 62.5% asset savings rationale (5 unique + 3 flip mirror vs 16 full-body); cites PM D.4 single source. (c) **ABA-3** — Section 1 Principle C gets new "REWINDING 30-frame i-frame visual rule" sub-block: `Sprite2D.visible` 2:1 toggle (visible=true 2f / false 1f = 10 pulses over 30f = ~20 Hz); PM-owned via `EchoLifecycleSM.RewindingState._physics_update()`; no-color mandate (survives shader inversion); multi-channel safety with audio + screen-shake; explicit cross-reference distinguishing from ABA-4 DYING flicker (different cadence + owner + scope). (d) **ABA-4** — Section 2 Mood Table gets new DYING row inserted between Time-Rewind Active and Death & Restart: emotional target "urgent reversal anticipation"; visual integrates B6 fix specifics (1:1 30 Hz REWIND Core flicker only, NOT whole sprite; `sfx_dying_pending_01.ogg` 80→400 Hz over 200 ms 1:1 envelope; no whiteout until DEAD entry). **B6+B7 integration**: ABA-3 (REWINDING 20 Hz whole-sprite) and ABA-4 (DYING 30 Hz Core-glow only) are now formally documented as distinct events. **OQ-PM-6 closed**. `/asset-spec system:player-movement` now unblocked. 0 AC change (cross-doc art doc updates, no PM AC body changes). /design-review 2026-05-11 B7 (art-director ABA-1..4 deferred amendment circular gate) resolved |
| **B8 fix (footstep variant pool + pitch jitter)** | VA.4 Run footstep row + VA.5 footstep ALLOW exemption row | **2026-05-11** | **Option A locked** (creative call 2026-05-11) — keep 4 `sfx_player_run_footstep_concrete_01..04.ogg` variants; add **per-step ±5 % pitch jitter** at method-track callback. Asset budget unchanged (Tier 1 PM audio = 7 files; VA.6 unchanged). Resolves audio-director "sprint-speed repetition perception" finding: at 12 steps/sec, 4 variants alone produce 25 % per-step repeat chance and a perceived 333 ms loop; adding pitch jitter that exceeds the ~3 % human Just-Noticeable-Difference threshold makes every step sonically distinct without authoring new assets. **Jitter mechanics**: `_footstep_rng: RandomNumberGenerator` dedicated instance (NOT global `randf()`), seeded from `Engine.get_physics_frames()` at callback entry — preserves ADR-0003 determinism + 1000-cycle PlayerSnapshot bit-identicality (AC-H3-01); restore-tick double-fire produces a single masked footstep at a slightly-different pitch (no semantic divergence). Industry precedent: Celeste / Hollow Knight / Hades same 4-pool + ~±5 % pattern. **NOT ±10 %** (semantic noise — reads as different weight/surface). VA.5 ALLOW exemption preserved (callback still restore-safe). 0 AC change (VA.4 row + VA.5 row notes are spec only — no formula or behavior contract added). /design-review 2026-05-11 B8 (audio-director AU3 footstep variant insufficient) resolved |
| **B9 fix (AimLock paper-doll + VA.1/VA.7 scope contradiction)** | VA.1 Body row + Gun arm overlay row + VA.2 AimLock row + VA.7 R-VA-4 risk row | **2026-05-11** | **Two-part resolution**: (1) **Paper-doll aesthetic defense** — static body + sweeping arm "paper-doll" framing is the *intentional* Monty Python cutout aesthetic (`art-bible.md` Section 9 Ref 2 established lineage); NOT an unintended defect. Tier 1 mitigation = existing "squared/planted" stance + REWIND Core luminosity bump (VA.2 AimLock row). Lean variants would *contradict* squared/planted decision. Tier 2+ subtle weight-shift body frames deferred (NOT BLOCKING). No asset budget change (VA.6 still 25 frames). (2) **VA.1/VA.7 scope contradiction resolved** — VA.1 stated body `flip_h` + arm sprite swap are "PM-code-driven (NOT AnimationPlayer track)", while VA.7 R-VA-4 mandated "all ECHO sprites authored as AnimationPlayer-driven `Sprite2D` frame sequences" → internal contradiction. Fix: scope-clarify R-VA-4 to cover *frame-sequence animations within a state* (idle loop / run cycle / jump arc / dying held / dead held), explicitly excluding scene-graph property mutations: (a) body `Sprite2D.flip_h`, (b) arm `Sprite2D.texture` swap, (c) i-frame `Sprite2D.visible` 2:1 toggle (VA.3), (d) DYING REWIND Core `Sprite2D.visible` 1:1 toggle (VA.2 B6 fix). All four are PM-code-driven per `_physics_process` Phase 6c (or `EchoLifecycleSM.RewindingState._physics_update()`), conceptually equivalent to `velocity` / `global_position` mutations. Authoring as AnimationPlayer tracks would (i) bypass `_is_restoring` guards via method-track callbacks (B3 fix territory), (ii) couple facing logic to anim timeline instead of input read, (iii) defeat D.4 facing_direction single-source. VA.1 body row + arm row tightened with scope rationale + cross-ref VA.3 pattern. 0 AC change (no new behavior; existing AC-H7-03 GREP-PM-1 already enforces external direct-write to facing_direction is PM-only; existing AC-H1-04 covers restore_from_snapshot calling AnimationPlayer.seek for frame-sequence restore). /design-review 2026-05-11 B9 (art-director AimLock paper-doll + VA.1/VA.7 internal contradiction Escalated REC→BLOCKING) resolved |
| **B10 fix (facing hysteresis pair — Schmitt trigger)** | D.4 Formula 2 rewrite + variable table + Worked Example drift scenario + C.4.1 declaration (+4 bool vars) + G.1 tuning table split (`facing_threshold_outside_enter` + `_exit`) + G.1 Resource @export (+1 field) + G.4.1 INV-4 rewording + new INV-8 + `_validate()` body update + F.4.2 Scene Manager #2 row 4→8-var expansion | **2026-05-11** | **Steam Deck stick drift (~±0.18) was oscillating facing across single threshold 0.2** (= `gamepad_deadzone` input.md C.1.3 + AC-IN-06/07). Fix: replace single `facing_threshold_outside = 0.2` with hysteresis pair **`facing_threshold_outside_enter = 0.2` + `facing_threshold_outside_exit = 0.15`**. Implementation = per-axis dual Schmitt trigger (4 bool flags: `_facing_{x,y}_{pos,neg}_active` mutually exclusive per axis). ENTER threshold commits axis to a sign; EXIT releases (also releases on drift past zero into opposite below-enter zone). Both axes encoded together → `_encode_facing()` → `facing_direction`. Drift below 0.15 cannot oscillate sign; drift between 0.15-0.2 on currently-active sign preserves; deliberate flip (|input| ≥ 0.2 opposite sign) re-locks new sign. Worked Example adds 5-frame drift defense scenario + 4-frame pre-B10 oscillation case the fix blocks. **New invariant INV-8**: `exit < enter` strict (`==` forbidden — boundary value re-introduces oscillation; runtime `_validate()` asserts). INV-4 renamed `facing_threshold_outside` → `facing_threshold_outside_enter`. **F.4.2 Scene Manager #2 obligation expanded 4→8-var** (must clear 4 B1 + 4 B10 ephemeral flags on `scene_will_change`; failure = phantom-jump *or* stale-locked facing on scene-entry first tick). AimLock formula (Formula 3) unchanged — `t_aim_lock = 0.1` is below drift floor, no hysteresis needed. Input #1 cross-doc decision (`gamepad_deadzone = 0.2` lock at input.md C.1.3) is the upstream anchor — PM hysteresis is a *separate concern* (PM-side asymmetric thresholds; does NOT re-implement deadzone math per `forbidden_patterns.deadzone_in_consumer`). 0 new AC (existing AC-H4-02 8-way facing worked-example sequence still passes verbatim with hysteresis — outcome unchanged on the documented frames; new drift scenario is in D.4 Worked Example, NOT a separate AC since it tests the same `_encode_facing` contract). /design-review 2026-05-11 B10 (Escalated REC→BLOCKING — `facing_threshold == gamepad_deadzone` Steam Deck stick drift) resolved |
| AC count target | H section preamble | **2026-05-11 (was 2026-05-10)** | 34 AC (2026-05-10) → 35 AC (2026-05-11 B3 fix; AC-H1-07 added) → **36 AC (2026-05-11 B6 fix; AC-H6-06 added)**. AC-H1-05 obsoleted by AC-H1-05-v2 (count unchanged, B5 fix). B2+B4 fix adds 0 ACs (rewires 3 existing AC bodies + new tooling). B7+B8+B9+B10 fixes add 0 ACs (spec tightening / cross-doc art docs / scope-clarify / formula refactor). 28 BLOCKING → 29 (B3) → **30 BLOCKING (B6)** + 6 ADVISORY. Collapse plan maintained. **Final post-revision: 36 AC / 30 BLOCKING / 6 ADVISORY** |

### A.2 Cross-doc citations (read for full context)

| Document | Sections cited | Relationship |
|----------|---------------|--------------|
| `design/gdd/game-concept.md` | Pillars 1, 2, 5 | Pillar service matrix (B.6) anchors all decisions |
| `design/gdd/systems-index.md` | System #6 row | Status: `Designed (2026-05-10)` Session 9 update |
| `design/gdd/time-rewind.md` | Rule 4 (12-frame grace), Rule 9 (`rewind_completed` signature), Rule 11 (REWINDING 30 frames i-frame), Rule 12 (Player-only checkpoint scope), Rule 17 (Primary Damage step 0 + Secondary SM latch), Visual/Audio (cyan-magenta tear), I4 (`seek(time, true)` forced immediate evaluation), Audio Events table (DYING/DEAD owns), F.1 row #6 (TR-PM contract); F.4.1 #1 reciprocal applied Session 9; AC-A4/D5/F1/F2 mirror obligations | **Hard upstream + downstream** (highest dependency); 4 mirror AC pairs |
| `design/gdd/state-machine.md` | C.1 (signal contract), C.2.1 (framework definitions + line 178-188 node tree per Round 5 cross-doc-contradiction exception), C.2.2 (host obligations), C.2.5 (`_lethal_hit_latched` secondary), C.3.4 (`call_deferred` connect best practice), AC-07 (queue atomicity), AC-09 (force_re_enter), AC-15 (DYING→DEAD direct path), AC-23 (3-machine M2 reuse integration); F.4.1 #2 + #3 reciprocals applied Session 9 | **Hard upstream** (framework + host obligations); 3 mirror AC |
| `design/gdd/damage.md` | C.1.1/C.1.2 (HurtBox/HitBox composition), C.3.2 step 0 (first-hit lock primary guard — Round 5 fix 2026-05-10), C.6.4/C.6.5 (priority ladder + frame-N invariant), DEC-3 (binary 1-hit lethal), DEC-4 (`HurtBox.monitorable` SM-owned single-direction), DEC-6 (12-frame hazard grace + 1 priority compensation), AC-9 (DYING latch), AC-12 (REWINDING monitorable=false), AC-20 (Rewinding enter/exit toggle), AC-21 (grep regex CI precedent), AC-29 (1000-cycle determinism), AC-36 (first-hit lock GUT); F.4.1 #4 reciprocal applied Session 9 | **Hard upstream** (composition only — no direct subscribe); 5 mirror AC |
| `design/art/art-bible.md` | Section 1 Principle A (Clarity-First Collage 0.2s glance test), Principle C (REWIND inversion + glitch), Section 2 Mood Table (DYING/DEAD), Section 3 (ECHO Silhouette 48px + dorsal REWIND Core), Section 4 (Color Palette — Neon Cyan `#00F5D4` / Rewind Cyan `#7FFFEE` / Concrete Dark `#1A1A1E` / Concrete Mid `#3C3C44`; backup safety #4 multi-channel), Section 5 (ECHO 8-way arm protrusion design), Section 6 (lineart layer black stroke 2-4 px), Section 8 (`atlas_chars_tier1.png` 512×512 NEAREST PNG OGG; ≤500 draw calls), Section 9 Ref 2 (Monty Python cutout) + Ref 4 (Cuphead frame economy) | **Visual single-source**; 4 amendment flags (ABA-1..4 — `art-director` consult 2026-05-10) |
| `docs/architecture/adr-0001-time-rewind-scope.md` | R-T1 Player-only checkpoint | Lock for `restore_from_snapshot()` scope (PM 7 fields only — no world rewind) |
| `docs/architecture/adr-0002-time-rewind-storage-format.md` | R-T2 State Snapshot ring buffer (90 PlayerSnapshot, write-into-place) + Amendment 1 (lethal-hit head freeze + `captured_at_physics_frame` Resource 9th field) + **Amendment 2 (2026-05-11 Proposed) — `ammo_count: int` 8th PM-exposed field per DEC-PM-3 v2** | 8 PM-exposed field schema lock (Resource 9 fields total — 8 PM-exposed + 1 TRC-internal); DEC-PM-3 v2 ammo inclusion drove Amendment 2 |
| `docs/architecture/adr-0003-determinism-strategy.md` | R-T3 `CharacterBody2D` + direct transform (no RigidBody2D); `Engine.get_physics_frames()` clock; `process_physics_priority` ladder PM=0, TRC=1, enemies=10 | C.1.1, C.3.1, C.3.2, D.3 sentinel reset core dependency |
| `docs/registry/architecture.yaml` | `state_ownership.player_movement_state`, `interfaces.player_movement_snapshot`, `forbidden_patterns.delta_accumulator_in_movement`, `api_decisions.facing_direction_encoding` (4 entries registered Session 9) | F.4.1 #6 reciprocal landed; AC-H8-01 grep verifier |
| `.claude/docs/coding-standards.md` | Test Evidence by Story Type (Logic/Integration/Visual/UI/Config-Data); Automated Test Rules (determinism + isolation + no hardcoded data); CI/CD Rules (Godot headless GUT4 runner) | H.1-H.8 AC test type tagging aligned |
| `.claude/docs/technical-preferences.md` | Engine pin (Godot 4.6 / GDScript / Forward+ / Godot Physics 2D); 60fps 16.6ms budget; ≤500 draw calls; 1.5 GB memory ceiling; Steam Deck verified target | VA.7 R-VA-1..R-VA-5 risk flags aligned |

### A.3 Reference games (B.3 Reference Lineage — full citation)

| Game | Year | Mechanic borrowed | Echo distinction |
|------|------|-------------------|-----------------|
| **Celeste** (Maddy Thorson / Noel Berry) | 2018 | Coyote time + jump buffer 6 frames; variable jump cut policy; jump weight feel | Death = scene reset (Celeste) vs body reset world preserved (Echo) |
| **Katana Zero** (Justin Stander / Askiisoft) | 2019 | Time mechanic + 1-hit + instant restart solo standard | Predict-then-replay (Katana Zero) vs remember-then-reenter (Echo); ex-ante vs ex-post |
| **Hotline Miami** (Dennaton Games) | 2012 | Instant restart + deterministic patterns + "unfair" avoidance | Top-down scene reset (HM) vs side-scroll continuous body (Echo) — input never breaks |
| **Contra** (Konami; series) | 1987–2024 | Side-scroll + 8-way shooting + 1-hit lethal kinematic template; modular character (gun overlay) | Contra has slight momentum jitter; Echo has 0 jitter (Pillar 2 + ADR-0003) |
| **Cuphead** (StudioMDHR) | 2017 | Reduced frame count + maximum expressiveness; cutout marketing-screenshot aesthetic | art-bible.md Section 9 Ref 4 (Tier 1 frame economy direct lineage) |

### A.4 External technical references

| Reference | Source | Used for |
|-----------|--------|----------|
| Godot 4.6 release notes (2026-01) | `https://godotengine.org/releases/4.6/` | Engine pin verification (R-VA-1 risk flag context) |
| Godot 4.5 → 4.6 migration guide | `https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html` | Forward+ default + Jolt 3D default (2D unaffected); Inspector-set property semantics |
| Maddy Thorson — "Celeste & Forgiveness" (GDC 2019 / Celeste devlog series) | published Celeste post-mortem articles | 6-frame coyote + 6-frame buffer industry-standard reference (D.3 Tier 1 default justification) |
| `damage.md` AC-21 grep CI precedent | this repo | H.7 AC-H7-03/04 pattern + `tools/ci/pm_static_check.sh` template |
| `damage.md` AC-29 1000-cycle determinism | this repo | H.3 AC-H3-01 + H.7 AC-H7-05 fixture pattern (run-1 self-capture forbidden) |

### A.5 Specialist consult log (this GDD authoring sessions)

| Session | Date | Specialists consulted | Sections produced |
|---------|------|----------------------|-------------------|
| Session 7 | 2026-05-09 | game-designer, gameplay-programmer, godot-gdscript-specialist (parallel) — A/B framing | A. Overview + B. Player Fantasy + Locked Scope Decisions DEC-PM-1/2/3 |
| Session 8 | 2026-05-10 | game-designer + gameplay-programmer + godot-gdscript-specialist (parallel for C); systems-designer (D); advisor (Phase 4 unbounded-accumulator post-write fix) | C.1–C.6 (Detailed Design) + D.1–D.4 (Formulas) + E (17 edge cases) + F.1–F.4 (Dependencies) |
| Session 9 | 2026-05-10 | advisor (pre-write blocker on `facing_direction_encoding` verification) | F.4.1 6 cross-doc reciprocal edits batch (time-rewind.md F.1, state-machine.md F.2 + C.2.1 + F.4 line 870, damage.md F.1, systems-index.md System #6 + Last Updated + Progress Tracker, architecture.yaml 4 new entries) |
| **Session 10** | **2026-05-10** | **systems-designer (light, G framing); qa-lead (MANDATORY for H, 37→34 AC validation + 7 GAPs surfaced); art-director (MANDATORY for Visual/Audio, Option C lock + 4 art-bible amendment flags); audio-director (LIGHT for Visual/Audio, per-callback guard policy locking AC-H7-04)** | **G.1–G.4 (Tuning Knobs) + H.1–H.8 (34 AC) + Visual/Audio Requirements + UI Requirements + Z. Open Questions + Appendix: References** |

### A.6 Round 5 cross-doc-contradiction exception log

1 Round 5 exception invoked during this GDD's authoring — `state-machine.md` C.2.1 lines 178-188 node tree correction (F.4.1 #3): merged `state-machine.md`'s split notation `ECHO (CharacterBody2D)` + `PlayerMovement (Node)` into a single corrected entry under the authority of the `PlayerMovement extends CharacterBody2D` root model locked in A.Overview. Surgical edit, no design space reopened. Applied in Session 9.

### A.7 Status header (top of file) — update candidate (Session 11 housekeeping)

> *Current Status header (line 3) remains "In Design". Recommended update when this GDD is complete in Phase 5d follow-up housekeeping*:
>
> ```
> > **Status**: Designed (2026-05-10) — pending fresh-session `/design-review`
> > **Creative Director Review (CD-GDD-ALIGN)**: Skipped — Lean mode (per `production/review-mode.txt`)
> ```

### A.8 Recommended next actions (post-completion)

1. **Fresh-session `/design-review design/gdd/player-movement.md`** — independent validation of all 8 sections + 34 AC + cross-doc consistency. NEVER run inline per skill protocol.
2. **`/consistency-check`** — verify no value conflicts across the now-4 designed system GDDs (#5/#6/#8/#9).
3. **Session 11 housekeeping**: Status header update (A.7 above) + commit Session 8/9/10 combined (recommended commit message in `production/session-state/active.md` Session 9 close-out).
4. **Tier 1 prototype OQ-PM-2 unblocking** — `seek(time, true)` looping anim verification BEFORE idle/run frame authoring (R-VA-1 HIGH risk).
5. **`/quick-design art-bible`** — apply 4 amendments ABA-1..4 (Section VA.8) to `design/art/art-bible.md`.
6. **Next system**: per recommended design order, candidates are Input #1 (resolves OQ-PM-7 + AimLock-jump exclusivity), Scene Manager #2 (resolves OQ-PM-1), Player Shooting #7 (resolves WeaponSlot signal contract + `_on_anim_spawn_bullet` policy), or HUD #13 (Tier 1 token UI).
