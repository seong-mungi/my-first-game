# State Machine Framework

> **System**: #5 State Machine Framework
> **Category**: Core / Foundation
> **Priority**: MVP (Tier 1)
> **Status**: **Approved (Round 2 design-review 2026-05-10: APPROVED — Round 1 8 BLOCKING items all verified, 2 residuals applied inline)** — Lean re-review (single-session, per `production/review-mode.txt`). Cross-doc consistency verified: `monitorable` matches damage.md DEC-4/C.6/D.4; B-range 2–6 matches time-rewind.md D-glossary; 1-arg `player_hit_lethal(cause: StringName)` matches damage.md DEC-1; 5-signal connect order matches F.1 + AC-14. Round 2 residuals applied: (R2-1) AC count math 27→28 + Logic 25→26 (AC-17a was separately enumerated row, not AC-17 sub-clause); (R2-2) `_state_history` ring buffer promoted from Tier 2 to Tier 1 in C.1.5 (AC-12 + AC-24 BLOCKING dependency resolution). Round 1 BLOCKING summary preserved: B1 B-range 2–8 → 2–6 (matches `time-rewind.md` single source) · B2 `pause_swallow_states` framework invariant lock + Time Rewind Rule 18 citation (OQ-SM-4 Resolved) · B3 `(F_input ≥ 0)` sentinel guard encoded in D.2 input-buffer formula · B4 D.5 DyingState intra-tick ordering rule specified + new AC-17a · B5 `EchoLifecycleSM._ready()` `call_deferred("_connect_signals")` pattern + null assert (OQ-SM-6 Resolved) · B6 `Q_cap` → `TRANSITION_QUEUE_CAP` const (OQ-SM-5 Resolved) · B7 `class_name EchoLifecycleSM extends StateMachine` specified · B8 AC verification methods corrected + new AC-27 (E-13). 12 RECOMMENDED + 5 nice-to-have deferred to v2 pass / evaluate after Tier 1 prototype verification. creative-director directive maintained: Round 3 fires only on prototype empirical falsification or cross-doc contradiction.
> **Author**: game-designer + godot-gdscript-specialist
> **Created**: 2026-05-09 (Round 1 reviewed 2026-05-10)
> **Engine**: Godot 4.6 / GDScript (statically typed)
> **Depends On (provisional)**: — (Foundation; signals consumed from Input #1, Damage #8, Time Rewind #9, Scene Manager #2)
> **Consumed By (provisional)**: Player Movement #6, Enemy AI #10, Boss Pattern #11, Time Rewind System #9 (already locked)

---

## A. Overview

The State Machine Framework is a collection of GDScript primitives that makes all gameplay entities in Echo (ECHO, enemies, bosses) behave in *explicit and deterministic* states. It provides only two base classes — `State` (lifecycle virtual methods + context reference) and `StateMachine` (transitions + signal-reactive dispatch) — and does not itself enforce behavior definitions for any entity. The ECHO 4-state machine (ALIVE / DYING / REWINDING / DEAD) already locked in by System #9 Time Rewind, along with its associated `_lethal_hit_latched` latch + pause-swallow obligations, is merely **hosted** on this framework; the definitions themselves are held as the single source of truth by `design/gdd/time-rewind.md`. As a Foundation layer it has no *direct* dependencies on any system, but as a signal consumer it receives messages from Damage (`player_hit_lethal`), Time Rewind (`rewind_started` and 4 others), Scene Manager (`scene_will_change`), and Input to drive transitions. Within the solo 16-month budget it is sufficient to demonstrate *reusability* in Tier 1 with ECHO + 1 enemy archetype + 1 boss phase machine; full reuse across all 24 systems is the validation target for the Tier 2 gate.

**Core positioning**:

- **Framework, not behavior** — defines primitives only. The ECHO machine is owned by the Time Rewind GDD.
- **Signal-reactive, not polled** — does not use its own `_physics_process`. No `physics_step_ordering` ladder slot.
- **Reusable across entity types** — ECHO / enemies / bosses all built on the same framework.
- **Solo-budget aware** — verifies 3 types (ECHO + 1 enemy + 1 boss) in Tier 1; full reuse is Tier 2.

---

## B. Player Fantasy

The State Machine Framework is a Foundation system and is not a mechanic directly perceived by the player. Therefore the fantasy in this section is defined not as *player emotion* but as **system invariants** — a list of things the player must *never* see.

### B.1 The Invariant (what the player does not see)

Three *non-events* are the success criteria for this framework:

1. **There is never a moment where input disappears.** Jump, shoot, and rewind inputs pressed during the 0.067 seconds just before ECHO dies are *never dropped* during any state transition. The 4 frames immediately before DYING entry + 12 DYING frames + 0 REWINDING entry frames form a single window that guarantees 0% input loss.

2. **There is never a moment where the UI flickers.** Even if `boss_killed` arrives during REWINDING, the HUD token counter is not updated immediately — it is deferred until `rewind_protection_ended`. That is, the visual signature never changes twice within the same 0.5 seconds. The SM declares the timing constraint; HUD #13 implements the buffered display policy.

3. **There is never a *boundaryless vacuum* between states.** ECHO always has exactly one state. There is no path that jumps *directly* from ALIVE to REWINDING — it must pass through DYING. The silent bug where a player falls into a *0-frame stateless* condition immediately after taking damage (when a transition function emits a signal that triggers another transition) is blocked at the framework level.

### B.2 The Cascade (indirect fantasy)

When the SM guarantees the above three invariants, *the fantasy of higher-level systems* becomes possible:

- **Time Rewind's "Defiant Loop"** — For the 0.2 seconds of death to become *an angry decision-making window*, that time must remain alive to the end without missing input. The SM's input buffer + latch guarantees that.
- **Pillar 2 "Deterministic Patterns"** — The reason the boss follows the same phase transitions on every attempt is that the boss SM transitions on *signals + frame counters* rather than wall-clock time.
- **Anti-Pillar #5 "Story is not a cutscene"** — As long as game flow is expressed as SM transitions, story beats are exposed as *playable states* and cutscene lockouts do not occur.

### B.3 Anti-Fantasy (emotions the system must never create)

- **"I gave input but the character ignored it"** — Every discard is expressed as an *explicit rejection cue* (SFX + visual signal). Silent discards are prohibited.
- **"What is this character doing right now?"** — Every state must be *debuggable*. Debug builds can display a callout showing the current state name (convenience feature, Tier 2 option).
- **"I avoided death with rewind but immediately died"** — REWINDING's 30-frame i-frame is guaranteed at the SM level. The *damage signal arrives → ignored* path is blocked by the SM.

### B.4 Reference

The sources for these three *cascade fantasies* are the following GDDs/documents:

- Time Rewind System #9 — Defiant Loop ([`design/gdd/time-rewind.md`](time-rewind.md) Section B)
- Pillar 2 Determinism ([`design/gdd/game-concept.md`](game-concept.md))
- Anti-Pillar #5 ([`design/gdd/game-concept.md`](game-concept.md))

This GDD does *not redefine* the above fantasies; it defines only *which invariants the framework uses to make them possible*.

---

## C. Detailed Design

### C.1 Framework Primitives

The State Machine Framework provides only two core classes — `State` and `StateMachine`. Both extend `Node` and are composed as children of the host entity (Autoload forbidden).

#### C.1.1 Class Hierarchy Decisions

| Decision | Choice | Rejected Alternative | Rationale |
|---|---|---|---|
| State base type | `Node` (extends Node) | `RefCounted` | Current state tree is immediately visible in the SceneTree inspector during debugging. Child Timer/AnimationPlayer nodes can be used inside State. Solo debugging efficiency prioritized. |
| StateMachine base type | `Node` (extends Node) | Autoload | Per-entity instantiation is required (ECHO, N enemies, N bosses). Autoload forces single-instance and is unsuitable. |
| Hierarchy model | **Flat** (single-level machine) | Hierarchical (HSM) / Parallel | Tier 1 can express ECHO 4-state + enemy 5-state + boss N-phase all as flat. HSM implementation risks eroding solo 4-6 week budget. Hierarchy is simulated via *multiple SM composition* (PlayerMovement has its own sub-SM). |
| Transition model | Explicit call (`transition_to(state)`) | Guard-evaluated (auto-transition) | Signal-reactive + explicit calls align naturally with the Godot 4 signal model. Guard evaluation requires `_process` polling → weakens determinism. |

#### C.1.2 `State` Class API

```gdscript
class_name State extends Node

## Context host (the entity that owns this State). Auto-resolved via parent chain in _ready.
var host: Node = null

## Lifecycle — all virtual. Default implementation is no-op.
func enter(payload: Dictionary = {}) -> void: pass
func exit() -> void: pass

## Called from the host's _physics_process. delta is the host's delta as-is.
## State itself does not use _physics_process (prevents double-call).
func physics_update(delta: float) -> void: pass

## Signal handler — routed by the host StateMachine. No-op if not implemented.
## Naming convention: handle_<signal_name>(...) — StateMachine auto-dispatches.
## Example: handle_player_hit_lethal(cause: StringName) -> void: pass
```

**Rules**:
- `host` is resolved at `_ready()` via parent (StateMachine) → grandparent (entity) chain. No explicit setter used.
- `payload` in `enter()` is arbitrary data passed at transition time (e.g. `{"cause": &"laser"}`). Ignored if unused.
- State must *not override* its own `_physics_process`/`_process`. All per-tick logic goes in `physics_update(delta)`.
- State may emit its own signals, but transition *decisions* always go through StateMachine. That is, calling `state_machine.transition_to(...)` is allowed, direct changes like `host.global_position = ...` are also allowed. Directly *replacing state objects* is prohibited.

#### C.1.3 `StateMachine` Class API

```gdscript
class_name StateMachine extends Node

signal state_changed(from_state: StringName, to_state: StringName)

## Currently active State. Use as read-only from outside.
var current_state: State = null

## The physics frame on which the last transition occurred (for debug/testing).
var last_transition_frame: int = -1

## Enters the initial state. Called once by the host in _ready.
## initial_state must be one of the child nodes.
func boot(initial_state: State, payload: Dictionary = {}) -> void

## Requests a state transition. Guarantees queuing + atomicity (C.1.4).
func transition_to(new_state: State, payload: Dictionary = {}, force_re_enter: bool = false) -> void

## Called from the host's _physics_process. Delegates to current_state.physics_update.
func physics_update(delta: float) -> void

## Dispatches the naming-convention handler of a State. Helper for automatic signal emit routing.
## Example: dispatch_signal(&"player_hit_lethal", [cause]) →
##     calls handle_player_hit_lethal(cause) on current_state if it exists.
func dispatch_signal(signal_name: StringName, args: Array = []) -> void
```

**Rules**:
- `current_state` is `null` before `boot()` is called. External code must assume a `null` guard.
- In `transition_to(new_state)`, if `new_state == current_state` and `force_re_enter == false`, it is a no-op (E-7 self-transition policy).
- Only one of multiple child State nodes is active at a time. Inactive States have `_physics_process` not called, so zero additional cost.

#### C.1.4 Transition Atomicity (Re-entry Prevention)

When `transition_to()` is called *again* during `current_state.exit()` or `new_state.enter()` (e.g. a signal emitted inside enter reaches the same SM again), it is enqueued into a **single queue** rather than executed immediately. The queue is flushed after the currently-in-progress transition call returns.

| Step | Action |
|---|---|
| 1. Call | Enter `transition_to(new_state, payload)` |
| 2. Guard | If in-progress flag (`_is_transitioning`) is true, push to queue and return immediately |
| 3. Lock | `_is_transitioning = true` |
| 4. Exit | Call `current_state.exit()` |
| 5. Swap | `current_state = new_state`, `last_transition_frame = Engine.get_physics_frames()` |
| 6. Enter | Call `new_state.enter(payload)` |
| 7. Signal | `state_changed.emit(from_name, to_name)` |
| 8. Unlock | `_is_transitioning = false` |
| 9. Flush | If queue is not empty, pop the first item and recursively call transition_to |

**Queue length cap**: 4. If a single transition call triggers 5 or more subsequent transitions, it is treated as a *cascade bug* and `push_error()` + discard queue. In normal gameplay the queue depth should never exceed 1 (see E-6).

#### C.1.5 Debug Support

**Tier 1 — Determinism verification tool (required)**:

- `_state_history: Array[StringName]` — stores the last 32 transitions in a ring buffer (32 entries × ~16 B StringName ≈ 512 B; per-instance overhead negligible). Pushed once at the end of the `transition_to()` 9-step atomic sequence (old entries ring-overwrite). Used as verification tool for AC-12 `_state_history` single-entry verification + AC-24 1000-cycle determinism comparison. **Tier 1 BLOCKING ACs depend on this field**, so it must be active in the Tier 1 phase (Round 2 design-review intra-doc consistency correction).

**Tier 2 — UX convenience tool (optional)**:

- Debug overlay label subscribing to `state_changed` signal — displays `[ECHO] ALIVE → DYING (frame 12345)` in the upper-right corner. In Tier 1, replace with a single `print_debug` line if needed.

### C.2 ECHO Machine Hosting Obligations

The ECHO 4-state machine (ALIVE / DYING / REWINDING / DEAD) is the *first client* of this framework. Per single-source principle, the *behavior definitions* of the 4-state machine itself are held by [`design/gdd/time-rewind.md`](time-rewind.md) Section C; this GDD specifies only the *9 obligations this machine imposes on the framework* (O1-O6 original + O7/O8 Input #1 B15 + O9 Input #1 B14/O-IN-1, both Round-7 exception 2026-05-11). Since obligation violations break Time Rewind GDD ACs, this framework must be capable of *hosting* all obligations.

#### C.2.1 Hosting Location

The ECHO 4-state machine resides not in the `time-rewind-controller` (TRC) node but in a **`StateMachine` node that is a child of the ECHO entity**. Named `EchoLifecycleSM`. 4 child State nodes:

> **Round 5 cross-doc-contradiction exception (2026-05-10, Decision A — player-movement.md F.4.1 #3 obligation)**: This node tree was corrected to align with the model locked in by player-movement.md A.Overview (`PlayerMovement extends CharacterBody2D` = ECHO root). The previous draft's separate notation of `ECHO (CharacterBody2D)` + `PlayerMovement (Node)` is discarded — the root node *itself* of the ECHO entity is PlayerMovement (CharacterBody2D), and EchoLifecycleSM / PlayerMovementSM / HurtBox / HitBox / Damage / WeaponSlot / AnimationPlayer / Sprite2D are all its child nodes.

```
PlayerMovement (CharacterBody2D, root — ECHO entity itself, process_physics_priority=0; player-movement.md A.Overview)
├── EchoLifecycleSM (StateMachine — this framework instance, ALIVE/DYING/REWINDING/DEAD)
│   ├── AliveState (State)
│   ├── DyingState (State)
│   ├── RewindingState (State)
│   └── DeadState (State)
├── PlayerMovementSM (StateMachine — Player Movement GDD domain, M2 reuse verification case; idle/run/jump/fall/aim_lock/dead — DEC-PM-1)
├── HurtBox (Damage GDD #8 — entity_id = &"echo", monitorable toggle authority = SM DEC-4)
├── HitBox (Damage GDD #8 — unused in Tier 1; used for Tier 2 melee)
├── Damage (Damage GDD #8 — 2-stage death host: lethal_hit_detected → 12-frame grace → death_committed)
├── WeaponSlot *(provisional Player Shooting #7 child node)*
├── AnimationPlayer (Godot 4.6 — force immediate eval with `seek(time, true)` on restore, time-rewind.md I4)
└── Sprite2D
```

TRC is a *separate autonomous node* (process_physics_priority=1) that owns only the ring buffer and communicates with EchoLifecycleSM **via signals only**. There is exactly one path where SM directly calls TRC by function — `try_consume_rewind() -> bool` (Time Rewind GDD Rule 6).

**Class hierarchy** (B7 — Round 1 design-review BLOCKING):

```gdscript
class_name EchoLifecycleSM extends StateMachine
```

`EchoLifecycleSM` is an **explicit subclass** of the framework `StateMachine`. The parent `StateMachine`'s transition queue · `_is_transitioning` atomicity · `dispatch_signal` guard evaluation are *inherited without modification*, and ECHO-specific obligations (O1–O6, C.2.2) are *added* only in the following forms:

- **Instance member variables**: `_lethal_hit_latched: bool`, `_rewind_input_pressed_at_frame: int`, `pause_swallow_states: Array[StringName]`
- **`_ready()` override**: Signal connect + direct `boot()` call *without* calling `super._ready()` (parent `StateMachine._ready()` is a no-op so super call is unnecessary; this obligation is *documented* in this GDD)
- **Signal handler methods**: `_on_damage_lethal`, `_on_rewind_started`, `_on_rewind_completed`, `_on_rewind_protection_ended`, `_on_scene_will_change` (all `_` prefix — prohibited from external calls)
- **External polling methods**: `should_swallow_pause() -> bool` (called by Pause System #18) **+ alias `can_pause() -> bool`** (called by Input #1 PauseHandler autoload — input.md C.1.4 single source). The two methods are *co-existing aliases*: `func can_pause() -> bool: return not should_swallow_pause()`. Round-7 cross-doc-contradiction exception applied (Input #1 F.4.1 #7 closure 2026-05-11).

**Framework code change prohibition**: `EchoLifecycleSM` must *not override or shadow* the parent's `transition_to()` · `dispatch_signal()` · `physics_update()` · `boot()` · `state_changed` signal definition. Violation causes AC-23 (framework reuse) failure. M2 DroneAISM / M3 StriderBossSM follow the same principle with `extends StateMachine`.

#### C.2.2 Nine Obligations (imposed on SM by Time Rewind; O7/O8 from Input #1 B15 + O9 from Input #1 B14/O-IN-1 — both Round-7 cross-doc-contradiction exception 2026-05-11)

| # | Obligation | Source | Framework accommodation |
|---|---|---|---|
| **O1** | Own `_lethal_hit_latched: bool` latch + set `true` on `ALIVE → DYING` transition, clear `false` on `REWINDING → ALIVE` or `DEAD` transition | time-rewind.md Rule 17 | `EchoLifecycleSM` owns its own member variable `_lethal_hit_latched`. When `dispatch_signal(&”player_hit_lethal”, ...)` is called, if latch is true, *ignore at the framework level* (do not dispatch to current State). |
| **O2** | Swallow `pause` input in DYING/REWINDING states | time-rewind.md Rule 18 + input.md C.1.4 PauseHandler pattern (alias `can_pause()` obligation) | `EchoLifecycleSM` holds whitelist `pause_swallow_states: Array[StringName] = [&”DyingState”, &”RewindingState”]`. **Two co-existing alias methods**: (a) `should_swallow_pause() -> bool` — inverse-polarity API for existing SM-side caller (future Pause System #18); returns true if current state name is in whitelist; (b) `can_pause() -> bool` — positive-polarity API called by Input #1 PauseHandler autoload (input.md C.1.4 single source); implemented as 1-line `func can_pause() -> bool: return not should_swallow_pause()`. **Input #1 F.4.1 #7 closure 2026-05-11** (Round-7 cross-doc-contradiction exception). Both callers guaranteed to coexist — backward-compat maintained by adding alias, not renaming. |
| **O3** | Input buffer — no-drop of `”rewind_consume”` input during `B` frames before lethal hit + DYING window | time-rewind.md Rule 5 | `EchoLifecycleSM` owns member `_rewind_input_pressed_at_frame: int = -1`. Both AliveState/DyingState check `Input.is_action_just_pressed(“rewind_consume”)` in `physics_update` → update the variable when found. DyingState evaluates “input exists within window + tokens ≥ 1” in `physics_update`. |
| **O4** | Subscribe to 4 signals (`player_hit_lethal`, `rewind_started`, `rewind_completed`, `rewind_protection_ended`) | time-rewind.md Section C + ADR-0001 rewind_lifecycle | `EchoLifecycleSM._ready()` connects signals from the ECHO child tree (`Damage` component, TRC node). All handlers call `dispatch_signal()` to route to the current State's `handle_<name>(...)` virtual method. |
| **O5** | Token ++ processing when `boss_killed` arrives during REWINDING is *TRC*'s responsibility, but SM guarantees HUD visual update deferral (until `rewind_protection_ended`) | time-rewind.md Rule 15 | RewindingState does *not directly subscribe* to the `boss_killed` signal. TRC updates the token count and emits `token_replenished`, but to prevent HUD from updating immediately at that point, HUD itself uses a buffered-update pattern applied after `rewind_protection_ended` fires (HUD GDD domain — this GDD only *declares the constraint*). |
| **O6** | On `scene_will_change` arrival, SM clears `_lethal_hit_latched` + input buffer variables + O8 idempotency counter + **PM 8-var ephemeral state** (via PM `_clear_ephemeral_state()` call) — single-layer cascade design | time-rewind.md Rule 16 (premise) + E-16 + input.md C.1.5 (O7/O8 cascade) + scene-manager.md C.1 Rule 5 + C.3.2 T+0 row + player-movement.md F.4.2 row #2 | `EchoLifecycleSM` subscribes to [Scene Manager #2](scene-manager.md)'s `scene_will_change` signal (canonical contract — scene-manager.md C.1 Rule 4 sole producer, Rule 5 sole subscribers TRC + EchoLifecycleSM; PM direct subscription prohibited). Handler resets all ephemeral variables (`_lethal_hit_latched = false`, `_rewind_input_pressed_at_frame = -1`, `_session_first_success_emitted = false` — O8 cascade per input.md C.1.5 latch-reset obligation) **+ calls PM `_clear_ephemeral_state()`** (PM 8-var: 4 coyote/buffer + 4 facing Schmitt flag clear — player-movement.md F.4.2 row #2). Does not change current state (on next scene boot, [Scene Manager #2](scene-manager.md) forces ALIVE transition via natural `_ready()` chain — scene-manager.md C.1 Rule 10). **Provisional → confirmed 2026-05-11 (Scene Manager #2 Approved RR7)**. |
| **O7** | `first_death_in_session(profile: StringName)` signal emit — on **every** `ALIVE → DYING` transition (recurring, NOT 1-time latch) | input.md C.1.5 + B15 (2026-05-11) — **Round-7 cross-doc-contradiction exception** applied per `damage.md` Round 5 S1 BLOCKER pattern (Session 6 2026-05-10) | `EchoLifecycleSM` emits `first_death_in_session.emit(active_profile)` immediately after `transition_to(DyingState)` atomic completion. No latch on SM side — HUD owns its own latch (input.md C.1.5 `_first_rewind_success_latched`). `active_profile` is polled from ActiveProfileTracker autoload (input.md C.1.6). Not subject to dispatch_signal guard D.3 (this emit is SM's own transition observation, not reactive to external input). |
| **O8** | `first_rewind_success_in_session(profile: StringName)` signal emit — once on first `REWINDING → ALIVE` transition in session + lethal-hit-driven (`_lethal_hit_latched_prev == true`) | input.md C.1.5 + B15 (2026-05-11) — **Round-7 cross-doc-contradiction exception** applied | `EchoLifecycleSM` additionally owns member `_session_first_success_emitted: bool = false`. Evaluated immediately after `REWINDING → ALIVE` transition atomic completion: uses 1-frame preserved copy `_lethal_hit_latched_prev` before O1 latch clear (intra-tick ordering — captured *before* clear) → `if _lethal_hit_latched_prev AND NOT _session_first_success_emitted: first_rewind_success_in_session.emit(active_profile); _session_first_success_emitted = true`. Natural hazard-grace recovery (`REWINDING → ALIVE` w/o lethal hit, `_lethal_hit_latched_prev == false`) does not emit (Pillar 1: only first *genuine* success proves learning). O6 cascade resets `_session_first_success_emitted = false`. |
| **O9** | `_trigger_held: bool` gate — absorbs chatter near `JOY_AXIS_TRIGGER_LEFT` threshold 0.5 (Steam Deck Gen 1 LT wear): guarantees `is_action_just_pressed(“rewind_consume”)` fires exactly once per hold cycle | input.md F.4.1 O-IN-1 + B14 (2026-05-11) — **Round-7 cross-doc-contradiction exception** applied per `damage.md` Round 5 S1 BLOCKER pattern (Session 6 2026-05-10) | `EchoLifecycleSM` additionally owns member `_trigger_held: bool = false`. Guard placed *before* O3 input buffer (`_rewind_input_pressed_at_frame`) update in AliveState/DyingState `physics_update`: `if Input.is_action_pressed(&”rewind_consume”) and not _trigger_held: _trigger_held = true; _rewind_input_pressed_at_frame = Engine.get_physics_frames()` · `elif not Input.is_action_pressed(&”rewind_consume”): _trigger_held = false`. Even if axis oscillation (0.45↔0.55) causes `is_action_just_pressed` re-firing, the gate permits entry only once per hold. KB+M `Shift` path is `InputEventKey` binary source so no chatter — gate passes normally with no effect. O6 cascade resets `_trigger_held = false`. Not affected by dispatch_signal guard D.3 (this gate operates at the *external input polling level*, unrelated to framework signal routing). |

#### C.2.3 What the Framework Does *Not* Provide

For the ECHO machine, this framework does *not* provide:

- **Timer management**: The 12-frame DYING countdown and 30-frame REWINDING countdown are each implemented by the State with its own counter (`_frames_in_state: int`). The framework provides no automatic timers — solo budget + determinism clarity prioritized.
- **State serialization**: The ECHO 4-state is *not restored* to PlayerSnapshot (ADR-0002). Restoration always starts from ALIVE. The framework provides no serialization interface.
- **Signal priority**: When multiple signals arrive in the same tick, processing order follows Godot default order (connect order). The framework provides no priority queue. (See E-13 — multiple lethals are naturally blocked by the latch)

#### C.2.4 Verification Responsibility Separation

| Verification | Responsible GDD | Guaranteed in this GDD |
|---|---|---|
| ECHO 4-state transition correctness | time-rewind.md AC | — |
| 12-frame grace timing | time-rewind.md AC | — |
| 30-frame i-frame timing | time-rewind.md AC | — |
| Latch/swallow/input-buffer *hostability* | **this GDD AC** | Section H |
| `transition_to()` atomicity | **this GDD AC** | Section H |
| `dispatch_signal()` routing correctness | **this GDD AC** | Section H |

That is, "does DYING go to DEAD after 12 frames" is Time Rewind QA. "Does EchoLifecycleSM own 4 State nodes and are each State's `handle_<signal>` handlers called correctly" is this GDD QA.

### C.3 Process Order & Determinism

The determinism guarantee of the State Machine Framework rests on two core principles — (1) **no own `_physics_process`** so it occupies no ladder slot, and (2) **all transitions execute synchronously** so their occurrence within the same physics tick is deterministic. This section specifies the relationship between ADR-0003's `physics_step_ordering` ladder and this framework, and defines additional constraints for passing the 1000-cycle determinism test.

#### C.3.1 Ladder Slot Decision — *None*

ADR-0003 defined the following ladder:

| process_physics_priority | System |
|---|---|
| **0** | Player (PlayerMovement, ECHO entity) |
| **1** | TimeRewindController |
| **2** | Damage component (`damage.md` C.6.4 — DEC-6 hazard grace counter decrement slot) |
| **10** | Enemies (CharacterBody2D archetypes) |
| **20** | Projectiles (Area2D) |

**StateMachine has no slot on this ladder.** Reasons:

- SM does *not override* its own `_physics_process`. Therefore there is no callback to order.
- SM's `physics_update(delta)` is explicitly called by *the host* inside its own `_physics_process`. That is, the SM's per-tick execution time **inherits the host's priority** — ECHO's EchoLifecycleSM is priority 0, enemy's EnemySM is priority 10.
- When SM transitions occur *signal-reactively* (e.g. Damage emits `player_hit_lethal`), handlers execute synchronously within the emitter's `emit_signal()` call stack. A separate priority is meaningless.

This decision does *not change* the ADR-0003 `physics_step_ordering` registry entry. (No architecture.yaml update needed)

#### C.3.2 Two Occurrence Paths for Transitions

All SM transitions occur via exactly one of the following two paths:

| Path | Trigger | Execution context | Example |
|---|---|---|---|
| **P1. Signal-reactive** | External system's `signal.emit(...)` | Synchronous execution within the emitter's call stack | Damage emits `player_hit_lethal` → EchoLifecycleSM's handler calls `transition_to(DyingState)`. Call completes before Damage's `_physics_process` ends. |
| **P2. Tick-driven** | Host's `_physics_process(delta)` → `state_machine.physics_update(delta)` → `current_state.physics_update(delta)` call, then `transition_to(...)` from inside State | Synchronous execution in host's priority 0 (or per-host) slot | DyingState calls `transition_to(DeadState)` when `_frames_in_state >= D`. Occurs in ECHO priority 0 slot. |

**P3 (prohibited)** — Transitions triggered from `_process` or wall-clock timers are prohibited as determinism violations. No State may use `_process` or `Time.get_ticks_msec()` (ADR-0003 determinism clock decision).

#### C.3.3 Deterministic Order of Multiple Same-Tick Signals

Consider the situation where Damage emits `player_hit_lethal` twice in the same physics tick by two projectiles (E-13). The two emits execute in the following order:

1. Damage's `_physics_process` processes projectile collisions. Processing order is determined by **scene-tree-order** (parent-child + sibling index) within the priority 20 projectile slot of the `physics_step_ordering` ladder (ADR-0003 spawn orchestrator rule).
2. The first emit synchronously calls the EchoLifecycleSM handler → `transition_to(DyingState)` → sets `_lethal_hit_latched = true`.
3. The second emit synchronously calls the EchoLifecycleSM handler → since latch is true, *silently ignored* by dispatch_signal.

**What SM must manually guarantee**: The latch check in dispatch_signal must occur *before* the `current_state.handle_*` call. This ensures same-tick duplicates are blocked by the latch. (Verified by Section H AC-11)

#### C.3.4 Signal Connect Order Determinism

Godot 4's `signal.emit()` calls connected handlers in *connect order*. The order in which SM connects external signals must **always be the same** — in `EchoLifecycleSM._ready()`:

```gdscript
func _ready() -> void:
    # B5 (Round 1 design-review BLOCKING) — call_deferred pattern.
    # Reason: if ECHO subtree appears before TRC/SceneManager subtree in scene-tree-order,
    # EchoLifecycleSM._ready() runs before TRC._ready(), causing
    # get_first_node_in_group(&"time_rewind_controller") to return null → .connect()
    # call hard-crashes. call_deferred runs after all _ready() in the same frame complete,
    # so TRC's add_to_group() is guaranteed.
    call_deferred("_connect_signals")

func _connect_signals() -> void:
    # Fixed order. Changing it may alter 1000-cycle determinism test results.
    # All lookups guarded with null assertion to block silent failure.
    var damage: Damage = host.get_node_or_null(^"Damage") as Damage
    assert(damage != null, "EchoLifecycleSM: host '%s' missing 'Damage' child or wrong type" % host.name)
    damage.player_hit_lethal.connect(_on_damage_lethal)  # CONNECT_DEFAULT (no flags)

    var trc: Node = get_tree().get_first_node_in_group(&"time_rewind_controller")
    assert(trc != null, "EchoLifecycleSM: no node in group 'time_rewind_controller'")
    trc.rewind_started.connect(_on_rewind_started)
    trc.rewind_completed.connect(_on_rewind_completed)
    trc.rewind_protection_ended.connect(_on_rewind_protection_ended)

    var scene_mgr: Node = get_tree().get_first_node_in_group(&"scene_manager")
    assert(scene_mgr != null, "EchoLifecycleSM: no node in group 'scene_manager'")
    scene_mgr.scene_will_change.connect(_on_scene_will_change)

    boot(get_node(^"AliveState") as State)
```

**Rules**:

- Connect order *follows the recorded order* in `_connect_signals()`. Automatic sorting and dynamic order changes are prohibited.
- All signal connections must use **`CONNECT_DEFAULT` (no flags)** — `CONNECT_DEFERRED` (flag 2) breaks the atomicity model of latch guard (D.3) and transition queue (C.1.4) and is *prohibited*. AC-14 verifies via `Object.get_signal_connection_list()`.
- `boot()` must only be called *after* all connects are complete — last line of `_connect_signals()`. Signals arriving before boot are discarded by E-3 guard #2.
- `get_first_node_in_group` relies on the assumption that group registration order is deterministic — Scene Manager + TRC are obligated to register in group in the first line of their own `_ready()` (verified by Scene Manager GDD + Time Rewind GDD AC).
- When *multiple SMs* subscribe to one signal (e.g. enemy SM subscribes to player position change), even if all SMs' `_ready()` run in the same frame, the order is fixed by scene-tree-order.

**`_ready()` ↔ `_connect_signals()` 1-frame window**: `_connect_signals()` spawned by `_ready()` via `call_deferred` runs at the end of the *same* frame (Godot deferred call behavior). Therefore the ~1 frame immediately after `_ready()` has `current_state == null` and all signals are discarded by E-3 guard #2. In normal gameplay there is no input-capable ECHO before boot, so no effect. AC-19 verifies boot-pending state response.

#### C.3.5 SM Verification in the 1000-cycle Determinism Test

Time Rewind GDD AC-T31 (estimated — 1000-cycle determinism) must also be verified at the SM level. The determinism guarantee of this GDD is verified by Section H **AC-24** — when running 1000 times with the same input sequence, EchoLifecycleSM's `_state_history` last 32 entries must be identical every time. EnemySM's `last_transition_frame` sequence determinism is verified at the Tier 2 gate with the same pattern (reusing AC-24).

#### C.3.6 Hot-spot Avoidance (performance budget)

In the 16.6ms budget allocation in `.claude/docs/technical-preferences.md`, *time-rewind subsystem ≤1ms* refers only to **TRC's ring buffer capture**; SM cost is separate. SM per-tick cost estimates:

- ECHO: 1 SM × 1 active state × `physics_update` (simple counter/input polling) = **<0.05 ms**
- Enemies: max 30 concurrent SMs × 1 active state × simple branch = **<0.3 ms** (Tier 1 cap of 30 simultaneous enemies, revisit in Tier 2)
- Boss: 1 SM × phase logic = **<0.1 ms**

Total SM cost < 0.5 ms / 16.6 ms (3%). Absorbed into the 6ms gameplay budget. No separate budget registration needed. (architecture.yaml `performance_budgets` remains empty)

### C.4 Reuse Across Entities

The State Machine Framework must be self-justifying within the *solo 16-month budget*. That is, this framework must not exist for ECHO alone — enemies and bosses must also reuse the same two classes (`State` / `StateMachine`). This section defines the Tier 1 reuse verification target and framework feature-creep prevention guards.

#### C.4.1 Tier 1 Reuse Target — 3-machine proof

By the end of Tier 1 (4-6 week prototype), **three types of machines must operate without modification** on this framework:

| # | Machine | Host entity | State count | Machine type |
|---|---|---|---|---|
| **M1** | EchoLifecycleSM | ECHO (CharacterBody2D) | 4 | ALIVE / DYING / REWINDING / DEAD (Time Rewind GDD) |
| **M2** | DroneAISM | Security drone (CharacterBody2D, priority 10) | 5 | IDLE / PATROL / SPOT / FIRE / DEAD (defined in Enemy AI GDD #10; Approved 2026-05-13) |
| **M3** | StriderBossSM | STRIDER boss (CharacterBody2D, priority 10) | phases ≥ 3 | PHASE_1_LEGS / PHASE_2_LASER / PHASE_3_DESPERATION / DEFEATED (Boss Pattern GDD) |

**Success criteria**: M2/M3 instantiate framework code (`State.gd`, `StateMachine.gd`) *without copying, forking, or modifying it*. Framework defects discovered are fixed in a generalized form on the framework side and refluxed to M1 as well.

#### C.4.2 Tier 1 Out of Scope

The following are *intentionally unsupported in Tier 1*. Candidates for Tier 2 re-evaluation:

- **Hierarchical State Machine (HSM)** — parent-child states + automatic parent enter/exit. PlayerMovement simulates hierarchy in Tier 1 with a *separate sub-StateMachine* (two machines attached to ECHO: EchoLifecycleSM and PlayerMovementSM). HSM value re-evaluated when enemy archetypes grow to 5+ types in Tier 2.
- **Parallel/Concurrent States** — the pattern where one entity runs two orthogonal machines simultaneously. In Tier 1, *multiple StateMachine nodes* are sufficient (ECHO also has two SMs as above).
- **Visual Editor / graph tools** — visualize SM via Godot Editor plugin. Erodes solo one-person budget. State count is small enough that code alone suffices.
- **State Persistence (save/restore)** — SM state serialization integrated with the save system. ECHO 4-state is *decided not to restore* per ADR-0002. Enemy/boss SMs also reset to initial state on scene reload in Tier 1.
- **Animation-driven States** — map `AnimationPlayer.animation_finished` as automatic transition trigger. Tier 1 is sufficient with explicit signal connect.

By documenting these 5 unsupported features as *design intent* in this GDD, subsequent system GDDs are prevented from assuming these patterns (e.g. HSM assumption prohibited when designing M3 STRIDER boss).

#### C.4.3 Reuse Violation Discovery Protocol

If during Tier 1 implementation a machine (e.g. M3 StriderBossSM) proves impossible to express with the framework:

1. **Stop immediately** — do not proceed with a temporary forked implementation for that machine.
2. **Classify the defect** — determine whether it is *resolvable by framework generalization* or *Tier 2 feature pull-forward*.
3. **Response by classification**:
   - Generalizable: add additional conventions/methods to the framework side with *minimal surface*. E.g. add `State.handle_animation_finished()` virtual method.
   - Tier 2 feature: at the solo game designer's discretion, either (a) simplify the Tier 1 boss pattern (reduce PHASE count) or (b) extend Tier 1 budget by 1 week and introduce the framework feature.
4. **Record the decision** — document in this GDD's Open Questions section or a follow-up ADR.

#### C.4.4 Tier 2 Reuse Expansion (reference)

At the Tier 2 gate (6 months cumulative / 3 stages), the following must operate on the framework:

- 3 enemy archetypes (drone / security robot / STRIDER minion) — 5-7 states each
- 2 bosses (STRIDER boss + 1 additional) — ≥ 4 phases each
- PlayerMovement own sub-SM — 7-9 states (idle/run/jump/double_jump/fall/wall_grip/aim_lock/hit_stun/dash)
- Pickup system auxiliary machine (at vertical slice time)

Total 7-10 SMs operating simultaneously in a single engine build. Re-measure the cost estimates from C.3.6 at Tier 2 time. If measurement stays *< 1.0 ms / 16.6 ms*, the framework is validated. If exceeded, consider introducing a fast-path that inlines direct calls to hot-state (e.g. enemy SM's `physics_update`).

#### C.4.5 Hosting Prohibition Zones Outside Framework

The following systems *do not use the State Machine Framework*:

- **HUD System (#13)** — UI state (menu open/close) is sufficient with a simple boolean flag. Introducing SM is over-engineering.
- **Scene/Stage Manager (#2)** — scene lifecycle is delegated to Godot's SceneTree itself. No separate SM needed.
- **Audio System (#4)** — BGM track transitions are expressed via Audio Director's cue chart. SM not used.
- **Input System (#1)** — input is sufficient with instant-value polling (`Input.is_action_pressed`). SM not used.
- **Time Rewind Controller** — TRC is a *stateless ring buffer controller*. It does *not host* the ECHO 4-state machine (C.2.1 hosting location decision).

Subsequent PRs attempting to introduce SM in these 5 systems can be rejected based on this section.

---

## D. Formulas

The State Machine Framework is a system with few arithmetic formulas — because decision logic is expressed as *transition relations*. This section defines 5 *predicate / ordering / counter* formulas that must be verified at the framework level. All variables are defined from the single source of the D.1 glossary; ECHO machine-specific variables (D, B, R) are imported from [`time-rewind.md`](time-rewind.md)'s D-glossary.

### D.1 Variable Glossary

| Variable | Type | Range | Meaning | Source |
|---|---|---|---|---|
| `D` | int | 8–18 (knob), default 12 | DYING grace window length (frames) | time-rewind.md `RewindPolicy.dying_window_frames` |
| `B` | int | 2–6 (knob), default 4 | Input buffer pre-hit window length (frames) | time-rewind.md `RewindPolicy.input_buffer_pre_hit_frames` (range owner: time-rewind.md) |
| `R` | int | 30 (hardcoded const) | REWINDING i-frame length (frames) | time-rewind.md `REWIND_SIGNATURE_FRAMES` |
| `F_now` | int | ≥ 0 | Current physics frame count | `Engine.get_physics_frames()` |
| `F_lethal` | int | ≥ 0 | Physics frame at which `_lethal_hit_latched` was set to true | EchoLifecycleSM internal |
| `F_input` | int | ≥ 0 or -1 | Last frame where `"rewind_consume"` `is_action_just_pressed` was found. -1 = not occurred | EchoLifecycleSM internal |
| `F_enter` | int | ≥ 0 | Physics frame at which the current State was enter()ed | StateMachine.last_transition_frame |
| `Q_depth` | int | 0–4 | Current depth of transition_to queue | StateMachine internal |
| `TRANSITION_QUEUE_CAP` | int | 4 (const, hardcoded) | Maximum transition_to queue length — *safety invariant*, not a knob (B6 — Round 1) | C.1.4 decision |

### D.2 Input Buffer Window Predicate (E1)

Determines whether a `"rewind_consume"` input is within the *valid buffer window*. Evaluated every tick in DyingState's `physics_update`.

**Formula** (B3 — Round 1 design-review BLOCKING; explicitly encodes sentinel guard):

```
input_in_window := (F_input >= 0)
                 ∧ (F_input >= F_lethal - B)
                 ∧ (F_input <= F_lethal + D - 1)
```

**Variable meanings**:

- `F_input >= 0`: Guarantees that input *occurred*. Under the previous definition (`F_input == -1` not-occurred sentinel), in the first frames right after game start where `F_lethal < B`, `F_lethal - B` becomes negative and the sentinel would accidentally pass — this blocks that buggy path. An *explicit early-cutoff guard*, not arithmetic.
- `F_input >= F_lethal - B`: Input occurred within B frames *before* the lethal hit or after
- `F_input <= F_lethal + D - 1`: Input occurred *before* the DYING window ends (DYING window is `[F_lethal, F_lethal+D-1]` inclusive)

**Example (default knobs, D=12, B=4)**:

| Scenario | F_lethal | F_input | Result |
|---|---|---|---|
| Input 5 frames before lethal | 1000 | 995 | `995 ≥ 996` false → **out** (need `≥996` with B=4) |
| Input 4 frames before lethal | 1000 | 996 | `996 ≥ 996` ∧ `996 ≤ 1011` → **in** |
| Input immediately after lethal | 1000 | 1000 | true ∧ true → **in** |
| Input 11 frames after DYING entry | 1000 | 1011 | `1011 ≤ 1011` → **in** (last frame inclusive) |
| Input 12 frames after DYING entry | 1000 | 1012 | `1012 ≤ 1011` false → **out** (already transitioned to DEAD) |

**Edge cases (formula-encoded)**:

- When `F_input == -1` (no input), clause 1 (`F_input >= 0`) is false → entire predicate false. Pulls the previous prose-only guard *into the formula* so it is safe even if implementer misses the prose.
- Immediately after game start where `F_lethal < B` (e.g. F_lethal=2, B=4) — even if clause 2's `F_lethal - B = -2` is *mathematically* negative, clause 1 blocks -1. Therefore sentinel accidental pass (B3 degenerate path) does not occur.

### D.3 Transition Guard Ordering (E2)

Guard evaluation order inside `StateMachine.dispatch_signal(signal_name, args)`. Violating the order causes silent latch-bypass bugs (C.3.3).

**Formula (pseudocode)**:

```
function dispatch_signal(name, args):
    1. if name == &"player_hit_lethal" ∧ _lethal_hit_latched:
           return                         # latch short-circuit (highest priority)

    2. if current_state == null:
           return                         # ignore signal before boot()

    3. handler_name := "handle_" + name
       if not current_state.has_method(handler_name):
           return                         # unimplemented handler = no-op

    4. current_state.callv(handler_name, args)
       # transition_to() can be called inside handler — atomicity guaranteed by C.1.4 queue
```

**Why this order**: If guard #1 is placed after guards #2/3, when `current_state` is (e.g.) AliveState and the `handle_player_hit_lethal` handler exists, *the handler executes even when latch is true*, causing second lethal-hit processing to occur. Guard order #1 is a framework-level invariant.

**Example**:

| Situation | latch | current_state | name | Result |
|---|---|---|---|---|
| Normal first lethal | false | AliveState | `player_hit_lethal` | Call AliveState.handle_player_hit_lethal → transition to DyingState |
| Second lethal in same tick | true (set by call #1) | DyingState | `player_hit_lethal` | return at guard #1 — ignored |
| Signal before boot | false | null | `rewind_started` | return at guard #2 |
| Unimplemented handler | false | DyingState | `boss_killed` | return at guard #3 |

### D.4 Signal Handler Re-entrancy Budget (E3)

Enforces that queue depth does not exceed the cap when `transition_to()` is re-called during enter/exit. `Q_depth ≤ 1` is invariant in normal gameplay.

**Formula**:

```
Q_depth_new := Q_depth + 1

if Q_depth_new > TRANSITION_QUEUE_CAP:
    push_error("StateMachine cascade — Q_depth exceeded TRANSITION_QUEUE_CAP (= 4)")
    Q_depth_new := Q_depth         # no queue increment = additional transition discarded
    return
else:
    enqueue(new_state, payload, force_re_enter)
```

**Example**:

| Scenario | Q_depth progression | Result |
|---|---|---|
| Normal single transition | 0 → 1 → 0 (after atomic completion) | Normal |
| enter() emits 1 additional transition | 0 → 1 → 2 → 1 → 0 | Normal (Q_depth ≤ 4) |
| enter() emits 4 additional transitions (recursive) | 0 → 1 → 2 → 3 → 4 → 5 (cap violation) | push_error + 5th transition discarded |

**Expected value**: `Q_depth_max ≤ 1` in Tier 1 normal gameplay. ≤ 2 even in Tier 2 enemy archetypes where enter() triggers audio cue + animation start.

### D.5 State Frame Counter (E4)

Each State has its own `_frames_in_state: int` counter. Used for expiry evaluation in DyingState/RewindingState.

**Formula**:

```
on enter(payload):
    _frames_in_state := 0

on physics_update(delta):
    _frames_in_state += 1
    # expiry check is per-State:
    # DyingState:     if _frames_in_state >= D: transition_to(DeadState)
    # RewindingState: if _frames_in_state >= R: transition_to(AliveState)
```

**Invariant**: `_frames_in_state` increments by exactly 1 per `physics_update` call; incrementing inside *signal handlers* is forbidden.

**B4 — DyingState intra-tick ordering rule (Round 1 design-review BLOCKING)**:

The evaluation order inside `DyingState.physics_update(delta)` *must* be fixed to the following 4 steps. Violating the order causes the input on the last valid frame (`F_lethal + D - 1`) to be silently dropped:

```
1. poll input  →  F_input := frame if Input.is_action_just_pressed("rewind_consume") else _prev
2. evaluate    →  if input_in_window (D.2):
                       transition_to(RewindingState)
                       return                          # exit immediately *before* expiry check
3. increment   →  _frames_in_state += 1
4. expiry      →  if _frames_in_state >= D:
                       transition_to(DeadState)         # → DyingState.exit() → damage.commit_death()
```

**Why steps 1-2 must precede steps 3-4**:

- When input arrives on the last frame of DyingState (`_frames_in_state == D - 1`, e.g. frame 11 when D=12):
  - Correct order: poll → predicate true → `transition_to(RewindingState)` → DyingState.exit() calls `damage.cancel_pending_death()` → death avoided.
  - Violated order: increment first → `_frames_in_state == D` → expiry → `transition_to(DeadState)` → DyingState.exit() calls `damage.commit_death()` → the same-tick input is *permanently dropped*. The 12-frame grace is silently reduced to "11-frame grace".
- This is the *load-bearing* order that preserves the meaning of Time Rewind GDD Pillar 1 ("learning tool") + AC-C2 (*"DEAD on frame 13 arrival"*).

**RewindingState** has no input evaluation branch, so steps 1-2 can be omitted; only steps 3-4 apply.

**Verification**: This ordering rule is verified by Section H **AC-17a (new)** — fixture injects input into DyingState entered with `_frames_in_state = D - 1` → assert RewindingState transition + `damage.commit_death()` not called.

**Example (D=12)**:

| Frame | physics_update call count | `_frames_in_state` | Expired? |
|---|---|---|---|
| F_enter | 0 (enter call only) | 0 | no |
| F_enter+1 | 1 | 1 | no |
| F_enter+11 | 11 | 11 | no |
| F_enter+12 | 12 | 12 | **yes** → DeadState |

**Why frame counter, not delta accumulation**: `delta` is variable when physics steps are *missed* — `0.0334` instead of `0.0167`, etc., meaning a 12-frame grace could take as long as 24 frames. An `Engine.get_physics_frames()`-based counter expires after exactly 12 *physics steps* even when frames are dropped. (Direct application of ADR-0003 deterministic clock decision.)

### D.6 Hidden Risk — Connect-order Drift (F1)

Guard #1 in D.3 ensures `dispatch_signal` checks the latch first. However, if *other handlers besides SM are also connected to the signal emitted by Damage, and those handlers indirectly trigger a transition*, the D.3 invariant can be broken. Example:

```
Damage.player_hit_lethal → connect order:
  1. EchoLifecycleSM._on_damage_lethal  (sets latch)
  2. SomeOtherSystem._on_damage_lethal  (indirectly emits another signal → re-enters SM)
```

After handler 1 sets the latch, handler 2 executes and risks creating a second entry into SM *during the same signal dispatch*. **Prevention**: SM's `_on_damage_lethal` *must be connect order #1*. This obligation is verified by the C.3.4 connect-order rule + Section H **AC-14** (connect order).

### D.7 Tuning Split (knob vs const)

| Variable | Kind | Source | Change range | Owner |
|---|---|---|---|---|
| `D` | knob | RewindPolicy resource | 8–18 | Time Rewind GDD (Section G) |
| `B` | knob | RewindPolicy resource | 2–6 | Time Rewind GDD (Section G — range owner) |
| `R` | const | `REWIND_SIGNATURE_FRAMES` | hardcoded 30 | Time Rewind GDD (immutable) |
| `TRANSITION_QUEUE_CAP` | const | StateMachine class const | hardcoded 4 | **this GDD (safety invariant — not a knob; not registered in G.1)** |
| Signal handler connect order | invariant | code line order | change forbidden | **this GDD (C.3.4)** |
| State node name whitelist (`pause_swallow_states`) | knob | EchoLifecycleSM export var | `[&"DyingState", &"RewindingState"]` | **this GDD (Section G)** |

The D-glossary is *immutable* outside the framework. This GDD owns only the `TRANSITION_QUEUE_CAP` const, the connect-order invariant, and the `pause_swallow_states` whitelist (framework invariant — locked by Time Rewind Rule 18).

---

## E. Edge Cases

This section organises the **15** edge cases the framework must *explicitly* handle into 4 categories (E-1 ~ E-15). Each item describes *how* it is handled in behavioural terms; vague expressions such as "handle gracefully" are not used.

### E.1 Signal Arrival & Re-entrancy

#### E-1 — `player_hit_lethal` arrives more than once in the same physics tick

**Situation**: A projectile hits ECHO simultaneously (piercing round + collision, etc.). Damage emits `player_hit_lethal` twice in the same tick.

**Behaviour**:

1. The first emit reaches `EchoLifecycleSM._on_damage_lethal`.
2. SM immediately sets `_lethal_hit_latched = true`, caches `F_lethal = Engine.get_physics_frames()`.
3. `dispatch_signal(&"player_hit_lethal", ...)` is called → guard #1 sees the latch is *currently* false and passes → `AliveState.handle_player_hit_lethal` executes → `transition_to(DyingState)`.
4. The second emit arrives. The latch is already true. `dispatch_signal` guard #1 short-circuit returns. The second signal is ignored.

**Verification**: SM state transitions exactly once ALIVE→DYING between the two emits. Single entry in `_state_history`. (AC-12)

#### E-2 — Signal emitted inside `enter()` → SM re-entrancy

**Situation**: `DyingState.enter()` emits an audio cue event, and the event handler calls `transition_to(...)` again.

**Behaviour**:

1. SM is executing `enter(payload)` with `_is_transitioning = true`.
2. A recursive `transition_to()` call arrives → the C.1.4 step-2 guard sees the *in-progress* flag and pushes to the queue.
3. Queue depth 1. `enter()` completes → `_is_transitioning = false` → queue flushed at step 9 → additional transition executes as a normal atomic operation.

**Verification**: Two entries in `_state_history`, `last_transition_frame` identical (same tick). Queue depth max ≤ 1.

#### E-3 — Signal arrives before `boot()` is called

**Situation**: Another system's `_ready()` emits a signal *before* `EchoLifecycleSM._ready()` has finished connecting (possible per Godot 4's parent-first ready order).

**Behaviour**:

1. `current_state == null`.
2. `dispatch_signal()` guard #2 immediately returns. Signal discarded.
3. No console warning — this is part of the normal lifecycle.

**Verification**: No signal triggers a transition while `current_state` is `null`. (AC-10)

#### E-4 — Unimplemented `handle_<signal>` handler

**Situation**: AliveState does not implement `handle_rewind_started`, but TRC emits `rewind_started` (e.g. at a boss token bonus moment).

**Behaviour**:

1. `dispatch_signal(&"rewind_started", [tokens])` passes guards 1/2.
2. Guard #3 checks `current_state.has_method("handle_rewind_started")` → false → return.
3. Signal is discarded with no error/warning. *Opt-in handling* per State is the normal pattern.

**Verification**: Signal arrives at a State with no handler → SM state unchanged, console clean.

### E.2 Transition Mechanics

#### E-5 — Self-transition (`transition_to(current_state)`)

**Situation**: During AliveState, a signal handler calls `transition_to(get_node("AliveState"))`.

**Behaviour (force_re_enter == false, default)**:

1. `new_state == current_state` check → no-op return. `exit()` not called, `enter()` not called, `state_changed` signal not emitted.

**Behaviour (force_re_enter == true)**:

1. C.1.4 standard flow executes. `current_state.exit()` → state replaced (same object re-assigned) → `enter(payload)` → `state_changed.emit("AliveState", "AliveState")`.

**Intent**: Tier 1 uses *default false*. Use true only when Tier 2 enemy archetypes need an IDLE→IDLE *restart* (e.g. enemy resets to a new patrol path).

**Verification**: AC-08 (enter/exit not called when force_re_enter is false), AC-09 (called when true).

#### E-6 — Queue cap exceeded (cascade)

**Situation**: An enemy archetype's `enter()` triggers `transition_to` four times consecutively (design defect).

**Behaviour**:

1. Q_depth enqueues normally 1→2→3→4.
2. On the 5th call, the D.4 cap check fires → `push_error("StateMachine cascade — Q_depth exceeded cap (= 4)")` + 5th item discarded.
3. After queue processing completes, SM settles at *the state from the 4th enqueue*.

**Intent**: *Early detection*, not defect *masking*. push_error writes to the console + triggers debugger break in debug builds. A design fix is mandatory when discovered in Tier 1 prototype.

**Verification**: AC-20 (5-cascade triggers push_error + only 4 entries transitioned).

#### E-7 — New `transition_to` arrives during queue flush

**Situation**: The first queued item's enter() enqueues another `transition_to`.

**Behaviour**:

1. `_is_transitioning = true` is maintained throughout the flush.
2. The new call is appended to the *end* of the queue (FIFO).
3. The flush loop continues until the queue is empty.

**Edge**: Infinite loop risk — the *cap* is the safety net (E-6).

#### E-8 — Missing boot call

**Situation**: The host forgets to call `boot()` in `_ready()`, leaving `current_state == null`.

**Behaviour**:

1. Host `_physics_process` → `state_machine.physics_update(delta)` → `current_state == null` check → return.
2. Signals arriving are discarded at guard #2 (same as E-3).
3. SM remains in a *permanently inactive* state.

**Verification**: AC-19 — when boot is not called, SM does not respond to any signal/tick (*explicit inactivity*, not a silent freeze).

### E.3 Lifecycle & External Events

#### E-9 — Pause input — swallow during DYING/REWINDING

**Situation**: Player presses the Start button while ECHO is in DYING or REWINDING state.

**Behaviour**:

1. PauseHandler/Menu-Pause (#18) queries `EchoLifecycleSM.can_pause() -> bool` (positive polarity) or legacy `should_swallow_pause() -> bool` (inverse-polarity adapter).
2. SM checks `current_state.name in pause_swallow_states`; DyingState/RewindingState return `can_pause() == false` / `should_swallow_pause() == true`.
3. When the query vetoes pause, PauseHandler consumes the input, Menu/Pause remains closed, and no UI SFX or overlay appears.

**Intent**: Time Rewind GDD Rule 18 — prevents the 12-frame grace window from being converted into *analysis time*.

**Verification**: AC-16 (pause input during DYING/REWINDING produces zero visual/audio response).

#### E-10 — Input in DEAD state

**Situation**: Any input while ECHO is in DEAD state (movement, shooting, rewind_consume).

**Behaviour**:

1. DeadState's `physics_update` only increments `_frames_in_state` (no separate expiry — Scene Manager handles the transition).
2. DeadState implements no `handle_*` handlers → all signals discarded at guard #3 (E-4).
3. ECHO PlayerMovement's `physics_update` also independently ignores input when it detects DeadState (PlayerMovement GDD's responsibility).

**Intent**: No resurrection path. Scene Manager's checkpoint reload is the only path back to ALIVE.

**Verification**: AC-26 (all input after DeadState entry leaves ECHO position unchanged — new H.4 addition).

#### E-11 — DYING during `scene_will_change`

**Situation**: ECHO is in DYING state (12-frame grace in progress) when another trigger causes Scene Manager to emit `scene_will_change`.

**Behaviour**:

1. SM's `_on_scene_will_change` handler resets `_lethal_hit_latched = false`, `_rewind_input_pressed_at_frame = -1`.
2. State is *not changed* — DyingState is maintained.
3. Scene Manager shortly after unloads the scene → the ECHO node itself is destroyed. SM is destroyed along with it.
4. After the next scene loads, the new ECHO instance's `EchoLifecycleSM._ready()` → `boot(AliveState)` → starts ALIVE.

**Intent**: At scene boundaries, SM *clears ephemeral variables only*. State transitions themselves are delegated to host node destruction.

**Verification**: AC-18 (latch/input buffer at initial values on scene transition) + AC-19 (boot is called in the next scene and ALIVE starts).

### E.4 Misuse Prevention

#### E-12 — Attempt to replace `current_state` directly from outside

**Situation**: Another system's code attempts `state_machine.current_state = some_node` (incorrect pattern).

**Behaviour (statically typed GDScript)**:

1. `current_state` is **intended as read-only** — declared as `var` but *external writes are blocked in code review*.
2. If `current_state` is changed by any path other than `transition_to()`, the `_is_transitioning` flag stays false and the `state_changed` signal is not emitted → debug overlay/logs go *silent*.
3. Cannot be automatically detected → **AC-21**: GUT test attempts a direct assignment → confirms `state_changed` signal is not emitted (enforces that user code must always use `transition_to()`).

**Intent**: Solo development + low code-review intensity — cannot be enforced by static analysis, but *deterministically misbehaving* design exposes violations quickly.

#### E-13 — Host node resolution failure

**Situation**: A State attempts `host = get_parent().get_parent()` chain in `_ready()` but the parent structure is incorrect.

**Behaviour**:

1. When `host == null`, all `physics_update` / `handle_*` calls return through a `host == null` guard *at the State level*.
2. If `current_state.host == null` at SM `boot()` time, `push_error("State host unresolved")` is called and `boot()` is rejected.
3. The host entity remains in the scene as *inactive*. The designer notices immediately.

**Intent**: Exposed as *explicit error + rejection*, not silent inactivity.

#### E-14 — Signal arg arity mismatch

**Situation**: Damage changes to a 1-arg `player_hit_lethal(cause: StringName)` signal but the SM handler assumes 0 args.

**Behaviour (Godot 4 strict-typed signal)**:

1. The connect itself succeeds at `damage.player_hit_lethal.connect(_on_damage_lethal)` time.
2. On emit, the Godot runtime compares the `_on_damage_lethal()` signature against the emit args → mismatch causes a console error + call aborted.
3. SM performs neither the latch set nor the transition.

**Intent**: Type-safe signal obligation — all SM handlers must receive arguments that *exactly* match the signal signature. (AC-22)

#### E-15 — Signal handling order across multiple concurrent SMs

**Situation**: `rewind_started` emitted by Time Rewind is subscribed to by EchoLifecycleSM + HUD + VFX + Audio + 5 enemy archetypes.

**Behaviour**:

1. Connect order: ECHO children become ready first → EchoLifecycleSM is #1. Then HUD, VFX, Audio. Enemies are latest (at spawn moment).
2. Signal emit invokes handlers *synchronously in connect order*. One handler *cannot block the next* (Godot signal model).
3. Even if EchoLifecycleSM's handler emits another signal, the *next connected handler for the original signal* is unaffected.

**Intent**: Connect order is *deterministic* but *mutually isolated*. SM makes no assumptions about other subscribers' behaviour.

**Verification**: AC-24 (signal handler invocation order is identical across 1000 runs with the same input).

---

## F. Dependencies

The State Machine Framework is a Foundation-layer system with *no compile-time dependency on any other system*. All dependencies take the form of either (1) **signal subscriptions** (upstream) or (2) **composition clients** (downstream). This section describes both directions plus bidirectional verification status.

### F.1 Upstream — Signal Consumers (optional)

The *base classes* `State` / `StateMachine` of this framework know no external signals. **Only the EchoLifecycleSM instance** subscribes to signals from the following 4 systems (C.3.4 connect order):

| Producer system | Signal | SM handler | Effect | Status |
|---|---|---|---|---|
| **#8 Damage / Hit Detection** | `player_hit_lethal(cause: StringName)` | `_on_damage_lethal` | latch set + `transition_to(DyingState)` | **Already Designed** — [`design/gdd/damage.md`](damage.md) C.3.1 / DEC-1. AC-22 1-arg `cause: StringName` locked. SM invokes `damage.commit_death()` / `cancel_pending_death()` (damage.md F.4). **`RewindingState.exit()` obligation (Round 3 addition)**: call `damage.start_hazard_grace()` once *immediately after* restoring `echo_hurtbox.monitorable = true` (damage.md DEC-6 — triggers 12-frame hazard-only grace). `RewindingState.enter()` obligation (DEC-4): `echo_hurtbox.monitorable = false`. |
| **#9 Time Rewind System (TRC)** | `rewind_started(remaining_tokens: int)` | `_on_rewind_started` | `transition_to(RewindingState)` | **Already Designed** — `design/gdd/time-rewind.md` contract locked |
| **#9 Time Rewind System (TRC)** | `rewind_completed(player: Node2D, restored_to_frame: int)` | `_on_rewind_completed` | Handled in RewindingState.handle_* (triggers i-frame count start) | **Already Designed** |
| **#9 Time Rewind System (TRC)** | `rewind_protection_ended(player: Node2D)` | `_on_rewind_protection_ended` | `transition_to(AliveState)` | **Already Designed** — ADR-0001 rewind_lifecycle contract extension |
| **#2 [Scene / Stage Manager](scene-manager.md)** | `scene_will_change()` (0 args) | `_on_scene_will_change` | Clears latch + input buffer ephemeral vars + O8 idempotency counter + PM `_clear_ephemeral_state()` call (8-var cascade) (E-11 + O6) | **Scene Manager #2 Approved RR7 2026-05-11** — canonical contract locked: scene-manager.md C.1 Rule 4 (sole producer) + Rule 5 (sole subscribers TRC + EchoLifecycleSM; PM direct subscription forbidden) + C.3.2 T+0 cascade wiring; `*provisional*` removed. |
| **#1 Input System** | (not a signal — polling) `Input.is_action_just_pressed("rewind_consume")` | Polled in AliveState/DyingState `physics_update` | Updates `_rewind_input_pressed_at_frame`; LT chatter hysteresis requires new `_trigger_held` gate obligation (input.md C.5 + E-IN-2 cross-doc obligation 2026-05-11) | Input GDD [`design/gdd/input.md`](input.md) **Designed 2026-05-11** — `InputMap` action name verbatim lock (`rewind_consume`). Additional `_trigger_held` gate obligation: ignore re-fires during the same hold between `is_action_just_pressed` and `is_action_just_released` in AliveState/DyingState `physics_update` (absorbs Steam Deck Gen 1 LT wear chatter). |

Additionally, **per-enemy-archetype SMs (DroneAISM)** may subscribe to #8 Damage's `enemy_hit` signal, but this is determined at Tier 2 (Enemy AI GDD's responsibility).

### F.2 Downstream — Framework Clients

The following systems *compose* this framework's `State` / `StateMachine` classes to build their own machines — *compile-time dependency* is introduced.

| Client system | Machine name | Node location | Tier | Obligations when authoring GDD |
|---|---|---|---|---|
| **#9 Time Rewind System** | EchoLifecycleSM | ECHO child (priority 0 slot inherited) | Tier 1 | 6 obligations imposed on SM in `design/gdd/time-rewind.md` Section C (C.2.2) — **already written** |
| **[#6 Player Movement](player-movement.md)** | PlayerMovementSM | PlayerMovement (CharacterBody2D root) child (separate SM node, sibling of EchoLifecycleSM) | Tier 1 | **PM #6 Designed locked (2026-05-10)**: `class_name PlayerMovementSM extends StateMachine` — M2 reuse verification case for this framework. PlayerMovementSM has Tier 1 **6 states** (`idle/run/jump/fall/aim_lock/dead`, DEC-PM-1 — `hit_stun` removed by damage.md DEC-3 binary model; dash/double_jump/wall_grip deferred to Tier 2). **Independent from EchoLifecycleSM (Tier 1 flat composition — NOT parallel ownership)** — `dead` state force-transitions *reactively* on EchoLifecycleSM `state_changed(_, &"DYING")` / `(_, &"DEAD")` signals (player-movement.md T13). Inherits parent framework's transition queue + `_is_transitioning` atomicity (player-movement.md C.2.5). Framework code changes forbidden (this GDD C.2.1 line 206). |
| **[#7 Player Shooting / Weapon System](player-shooting.md)** | *(no SM — read-only subscriber)* | WeaponSlot Node2D, child of PM root | Tier 1 | **Player Shooting #7 Approved 2026-05-11 Round 2 (read-only state subscriber, NOT framework client)**: WeaponSlot does *not* host its own StateMachine (player-shooting.md C.2.1 — read-driven member-var + guard ladder pattern); subscribes only to `EchoLifecycleSM.state_changed(from, to)` signal to update the single source of truth for `_active: bool` toggle (C.2.3 `_on_lifecycle_state_changed` handler — `AliveState`/`RewindingState` → `_active = true`; `DyingState`/`DeadState` → `_active = false`). Reads `lifecycle_sm.current_state` for G2 guard (defined-depth guard — G1 mirror). **`transition_to()` calls forbidden** (matches forbidden_pattern `cross_entity_sm_transition_call`; GREP-PS-PS-H6-05 static check enforces 0 matches under `src/gameplay/player_shooting/`). This row is the first *read-only state subscriber* pattern entry in F.2 — future systems that only read SM signals (HUD #13 / Camera #3 / VFX #14 etc.) register in the same pattern. |
| **#10 Enemy AI Base + Archetypes** | DroneAISM / SecurityBotAISM / STRIDER host | Enemy entity child (priority 10 slot inherited) | Tier 1 GDD Approved 2026-05-13; implementation verification pending | Enemy AI GDD #10 defines the Tier 1 standard enemy state grammar (`IDLE / PATROL / SPOT / FIRE / DEAD`) and STRIDER host boundary. C.4.1 M2 |
| **#11 Boss Pattern System** | StriderBossSM | Boss entity child (priority 10 slot inherited) | Tier 1 (STRIDER boss 1 verified) | Boss Pattern GDD defines states per phase. C.4.1 M3 |
| **#19 Pickup System** (Tier 2) | (possible) PickupBehaviorSM | Pickup entity child | Tier 2 | When Pickup GDD defines states such as idle/collected/expired |
| **[#3 Camera System](camera.md)** | *(no SM — read-only state subscriber)* | Camera2D, stage root sibling | Tier 1 | **Camera #3 Approved 2026-05-12 RR1 PASS (read-only state subscriber, NOT framework client)**: Camera does *not* host its own StateMachine (camera.md C.2 — single logical state `FOLLOWING` + 2 bool flags `is_rewind_frozen` / `apply_snap_next_frame`; framework overhead not justified). Direct read of PlayerMovementSM `state` for vertical lookahead state-scaled lerp (R-C1-4 — IDLE/RUN → 0; JUMPING → −20; FALLING → +52; REWINDING/DYING → immediate 0 clamp). Subscription to EchoLifecycleSM/PlayerMovementSM `state_changed` signals is unused in Tier 1 (camera.md C.3.1 — Camera subscribes to 6 signals: scene_post_loaded · shot_fired · player_hit_lethal · boss_killed · rewind_started · rewind_completed; does not directly subscribe to SM-emitted signals). **`transition_to()` calls forbidden** (matches forbidden_pattern `cross_entity_sm_transition_call`). This row is the second *read-only state subscriber* pattern entry in F.2 (consistent with Player Shooting #7 precedent). |

### F.3 Indirect Touchpoints — Systems *adjacent* to signals

The following systems have no *direct dependency* on SM but are affected by SM behaviour:

| System | Form of impact | Interaction |
|---|---|---|
| **#13 HUD System** | Delays `boss_killed` token visual update until `rewind_protection_ended` (C.2.2 O5) and owns first-death prompt latch reset | HUD subscribes to TRC's `token_replenished` + `rewind_protection_ended` for token display and to EchoLifecycleSM/scene boundary signals for the first-death prompt; SM declares timing/lifecycle constraints, HUD owns visuals. |
| **#18 [Menu / Pause System](menu-pause.md)** | Approved 2026-05-14: pause initiation uses `can_pause()` / `should_swallow_pause()` through PauseHandler; DYING/REWINDING veto produces no overlay/SFX | Menu/Pause calls into SM read-only; SM remains pause-swallow authority |
| **#14 VFX / Particle System** | Subscribes to `state_changed` signal (optional) | VFX can trigger visual pulse on DYING entry, glitch effect on REWINDING entry — this framework only emits the signal, no dependency |
| **#4 [Audio System](audio.md)** | EchoLifecycleSM → `AudioManager.play_rewind_denied()` direct call | TR AC-B4: `_tokens == 0` + DYING + rewind input → EchoLifecycleSM calls directly. No signal (`play_rewind_denied()` pattern — audio.md Rule 12). Audio #4 Approved 2026-05-12. |

### F.4 Bidirectional Mirror Verification

`design/CLAUDE.md` rule: *if A depends on B, B's doc must also mention A*. Bidirectional status for the 4 systems this GDD depends on + the 4 systems that depend on this GDD:

| Direction | System | B doc → A mention | Status |
|---|---|---|---|
| F.1 (SM ← depends on) | #8 Damage | `design/gdd/damage.md` | **Already mentioned** (2026-05-09) — Damage GDD F.2 (player_hit_lethal subscriber = #5 SM) + F.3 (signal catalogue) + F.4 (commit_death/cancel_pending_death invocation API) |
| F.1 (SM ← depends on) | #9 Time Rewind | `design/gdd/time-rewind.md` | **Already mentioned** — Rule 4-7, Rule 17-18, Section C table, F dependencies, signals (C.2.2 cross-link) |
| F.1 (SM ← depends on) | #2 [Scene / Stage Manager](scene-manager.md) | `design/gdd/scene-manager.md` | **Already mentioned** — Scene Manager #2 Approved 2026-05-13; C.1 Rule 4/5 define `scene_will_change()` timing and sole-subscriber policy, and F.1 row #5 mirrors EchoLifecycleSM O6 cascade. |
| F.1 (SM ← depends on) | #1 Input System | [`design/gdd/input.md`](input.md) | **Designed 2026-05-11** — Input GDD F.1/F.4.1 cross-doc; `rewind_consume` action name verbatim lock; `_trigger_held` gate obligation (input.md C.5). This SM F.1 row + OQ-SM-3 closure applied in Input #1 F.4.1 batch. |
| F.2 (SM → depended on by) | #9 [Time Rewind](time-rewind.md) | `design/gdd/time-rewind.md` | **Already mentioned / resolved** — Time Rewind #9 references State Machine as the death-window arbiter; provisional marker cleanup completed by the approved cross-doc batch. |
| F.2 (SM → depended on by) | #6 Player Movement | [`design/gdd/player-movement.md`](player-movement.md) | **Already mentioned** (2026-05-10 PM #6 Designed) — F.1 #5 row specifies PlayerMovementSM `extends StateMachine` (M2 reuse) + framework code change forbidden + EchoLifecycleSM independent (Tier 1 flat composition, NOT parallel ownership) + `dead` state is EchoLifecycleSM `state_changed` reactive force (T13). C.1 / C.2.5 transition queue + `_is_transitioning` atomicity inherited. This row is a *bidirectional hygiene update* (player-movement.md F.4.1 #2 directly delegated; F.2 table at line 843 — PM lock-in already applied). |
| F.2 (SM → depended on by) | #10 [Enemy AI](enemy-ai.md) | `design/gdd/enemy-ai.md` | **Approved 2026-05-13 (RR1 PASS)** — EnemyBase defines StateMachine reuse expectations, tuning surface, acceptance criteria, and presentation hooks. Area2D budget review blocker resolved by preflight validation contract. |
| F.2 (SM → depended on by) | #11 Boss Pattern | `design/gdd/boss-pattern.md` | **Not yet written** |

**Closed action (Task #9)**: Time Rewind's provisional State Machine reference has been resolved by the approved cross-doc batch. No immediate SM↔TR mirror cleanup remains.

**Unwritten / incomplete GDD bidirectional obligations (Future)**: Boss Pattern #11 must explicitly name this GDD in its Dependencies section when authored. Enemy AI #10 already names State Machine #5 in its Dependencies section. The Depends On column in systems-index.md is already accurate (verified — "State Machine" listed under sections #6/#10/#11).

### F.5 Compile-time Dependency Analysis

The *class definitions* of this framework import no external classes:

- `State.gd`: extends `Node`. External imports: none.
- `StateMachine.gd`: extends `Node`. External imports: none (`State` class resolved as a same-directory sibling via `class_name`).

**In other words**: `src/core/state_machine/` references no other system code. Other systems import SM — one-directional. This *reverse cleanliness* is the definition of a Foundation layer.

### F.6 Forbidden Compositions

The following patterns are *forbidden* when using this framework:

- **State imports another State node** — direct references between sibling States within the same SM are forbidden. Transitions must always go through `state_machine.transition_to(...)`. (Violation → code review rejection)
- **State calls another entity's SM** — e.g. enemy SM calling ECHO SM's `transition_to`. Emit a signal instead and let ECHO SM make its own decision. (Reason: cross-entity tight coupling = determinism threat)
- **SM instantiated in an Autoload Singleton** — Time Rewind GDD/ADR allowed TRC to be *either an Autoload or a node*, but EchoLifecycleSM itself *must be an ECHO child node*. Required to guarantee lifecycle synchronisation on scene reload.

---

## G. Tuning Knobs

The State Machine Framework is a system with *very few tunable values* — intentionally so. Framework correctness comes from *invariants, not values*, so every knob added enlarges the determinism-verification surface. This section organises (1) the 3 knobs directly owned by the framework, (2) 4 knob candidates *explicitly rejected* by the framework, and (3) 2 knobs imported from external GDDs.

### G.1 Framework Owned Knobs (1 knob + 1 framework invariant)

> **Round 1 design-review changes**: `Q_cap` removed (B6 — promoted to `TRANSITION_QUEUE_CAP` class const, not a knob — see D.1/D.4/D.7). `pause_swallow_states` locked as a **framework invariant** (B2 — prevents Time Rewind Rule 18 violation).

| Field | Location | Type | Safe Range | Default | Gameplay aspect affected | Re-verification on change |
|---|---|---|---|---|---|---|
| **`pause_swallow_states`** *(invariant)* | `EchoLifecycleSM` member (not exported) | `Array[StringName]` | **Fixed `[&"DyingState", &"RewindingState"]` — override forbidden** | `[&"DyingState", &"RewindingState"]` | Pause swallow during DYING/REWINDING directly cites Time Rewind GDD Rule 18 ("prevent the 12-frame grace from being converted into *analysis time*"). Easy mode must *not* override this field — difficulty must be adjusted only through separate knobs like `D` (`dying_window_frames`) or `starting_tokens`. | Cannot be changed (framework invariant). |
| **`debug_overlay_enabled`** | `StateMachine` export var | bool | true / false | **false** (Tier 1) → **true** (Tier 2) | Displays `[ECHO] ALIVE → DYING (frame 12345)` label in the top-right corner in debug builds. *Runtime cost < 0.01ms* — performance impact negligible. | Promote debug build default to true at the Tier 2 gate. |

### G.2 Imported Knobs (owned by external GDDs, referenced here only)

| Knob | Source | Usage in this GDD | Change authority |
|---|---|---|---|
| **`D` (dying_window_frames)** | `RewindPolicy` resource (Time Rewind GDD Section G) | DyingState `_frames_in_state` expiry threshold (D.5) | Owned by Time Rewind GDD. This GDD guarantees *hosting capability* for any value within the 8–18 range. |
| **`B` (input_buffer_pre_hit_frames)** | `RewindPolicy` resource (Time Rewind GDD Section G) | Input buffer window predicate start point (D.2) | Owned by Time Rewind GDD. This GDD hosts the **2–6** range (range owner = `time-rewind.md`; B1 — corrected in Round 1 design-review from the previously incorrect `2–8`). |

Explicitly stating that this GDD *hosts `D`/`B` without change authority* is a guard to prevent the systems designer from confusing framework defects with gameplay tuning.

### G.3 Explicitly Rejected Knob Candidates (4)

The following are candidates that "might seem like knobs but are rejected at the framework level". Rejection reasons are provided.

| Candidate | Rejection reason | Alternative |
|---|---|---|
| **`R` (rewind_protection_frames)** | The 30-frame i-frame is a *visual signature* with a single source (`REWIND_SIGNATURE_FRAMES` const). Changing it would require re-tuning shader/audio/ACs — exceeds solo budget. | Time Rewind GDD locks it as a const. Changing requires an ADR. |
| **Signal connect order** | Determinism invariant. Dynamically reordering would make 1000-cycle test results *unpredictable*. | The code line order in C.3.4 is used as the *sole* source. |
| **Per-State transition cooldown** | Offered by most SM design patterns, but *no state needs a cooldown* in the ECHO/enemy/boss machine designs (all expiry is handled sufficiently by the `_frames_in_state` counter). Adding a knob = unused code = solo budget erosion. | Add a `_frames_since_X` field to the State itself when needed. Not the framework's responsibility. |
| **Auto signal routing disable toggle** | If `dispatch_signal` is disabled, the framework's core safety nets (latch, null guard) are bypassed. A single `bool` becomes a *remote weapon* that breaks determinism. | Simply leaving a handler unimplemented causes automatic discard (E-4) — no separate toggle needed. |

### G.4 Knob Activation Schedule by Tier

| Tier | Active knobs | Notes |
|---|---|---|
| **Tier 1 (4-6 weeks)** | `TRANSITION_QUEUE_CAP=4` (const), `pause_swallow_states=[DyingState, RewindingState]` (invariant) | `debug_overlay_enabled=false` (replaced by a single `print_debug` line) |
| **Tier 2 (6 months cumulative)** | + `debug_overlay_enabled=true` (debug build default) + `_state_history` ring buffer | Used as history comparison tool when running 1000-cycle determinism tests automatically |
| **Tier 3 (16 months — release)** | 0 additional knobs. **Easy mode must not override `pause_swallow_states`** (B2 — Time Rewind Rule 18 invariant). Difficulty Toggle (#20) adjusts only *Time Rewind-owned knobs* such as `RewindPolicy.dying_window_frames` (D=8/16/18) or `RewindPolicy.starting_tokens`. | Difficulty Toggle GDD registers this GDD's invariants as *read-only* clients. |

### G.5 Knob Addition Rejection Policy

Any subsequent PR adding a knob to this GDD must answer *yes* to all 3 questions or be rejected:

1. If this knob is *changed*, does the 1000-cycle determinism test *still PASS*?
2. Can a safe range for this knob be explicitly stated? (open-ended range = rejection)
3. Does the gameplay aspect this knob affects *map 1:1 to exactly one existing GDD*?

This policy blocks the framework from bloating into a "general-purpose SM library". An explicit protection for the solo budget.

---

## H. Acceptance Criteria

**28** acceptance criteria in total (Round 1 design-review adds new AC-17a for B4 + new AC-27 for B8). **26** are *Logic* (GUT automated tests, BLOCKING); **2** are *Integration* (integration test or documented playtest, BLOCKING) (AC-23 + AC-25). 0 visual/UI ACs — Foundation system, no visual evidence. All ACs must PASS by the end of the Tier 1 prototype.

> **Round 1 design-review fixes**: Corrected count arithmetic (Logic 23/Integration 3 → Logic 25/Integration 2; AC-24 + AC-26 are Logic; only AC-23 + AC-25 are Integration); AC-22 (a) demoted to advisory as it is not headless GUT-assertable; AC-25 verification method specifies `Time.get_ticks_usec()` instrumentation; AC-14 verification changed to `Object.get_signal_connection_list()` query post-`_ready()`; new AC-17a (B4 intra-tick ordering); new AC-27 (E-13 host==null boot rejection).
> **Round 2 design-review fix (2026-05-10)**: Corrected remaining count arithmetic defect from B8 — AC-17a is enumerated as a separate row so it counts as an independent entry, not a sub-clause of AC-17. 28 = Logic 26 + Integration 2 (mechanical row count via `grep -c`). AC-17a explicitly added to the H.7 Tier 1 gate row.

### H.1 Framework Primitives (AC-01 ~ AC-05)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-01** | `State` class extends `Node` and provides 4 members: `host`, `enter()`, `exit()`, `physics_update(delta)`. Default implementations are all no-ops (0 console output on `enter`/`exit`/`physics_update` calls). | GUT: instantiate `State.new()` → verify with `has_method` + confirm 0 side effects on call | Logic |
| **AC-02** | `StateMachine` class extends `Node` and provides `current_state`, `last_transition_frame`, `state_changed` signal + `boot()`, `transition_to()`, `physics_update()`, `dispatch_signal()` methods. | GUT: verify `has_method` + `has_signal` on `StateMachine.new()` instance | Logic |
| **AC-03** | On `boot(initial_state, payload)` call: (a) `current_state == initial_state` (b) `initial_state.enter(payload)` called exactly once (c) `state_changed("", "InitialStateName")` emitted once. | GUT: use spy State. Verify call count + signal counter | Logic |
| **AC-04** | When host calls `state_machine.physics_update(0.0167)`, `current_state.physics_update(0.0167)` is called exactly once. If `current_state == null`, called 0 times (silent return). | GUT: spy State + two cases for null branch | Logic |
| **AC-05** | On `dispatch_signal(&"foo", [arg1, arg2])` call, `current_state.handle_foo(arg1, arg2)` is called exactly once. If no handler, called 0 times + console clean. | GUT: spy State + two cases for handler present/absent | Logic |

### H.2 Transition Atomicity (AC-06 ~ AC-09)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-06** | On normal `transition_to(B)` call: (a) `current_state.exit()` called (b) `current_state := B` (c) `last_transition_frame := Engine.get_physics_frames()` updated (d) `B.enter(payload)` called (e) `state_changed("A_name", "B_name")` emitted. Order a→b→c→d→e is *strict*. | GUT: spy A/B + capture emit order + frame counter mock | Logic |
| **AC-07** | When `transition_to(C)` is called inside A's `enter()`: (a) the transition to C is *queued* (b) the C transition executes atomically *after* A's `enter()` completes (c) `state_changed` is emitted twice (`"" → "A"` + `"A" → "C"`) (d) both emits occur at the same `Engine.get_physics_frames()` value. | GUT: spy that triggers transition inside enter() + signal timing verification | Logic |
| **AC-08** | On `transition_to(current_state, force_re_enter=false)` call: (a) `current_state.exit()` not called (b) `current_state.enter()` not called (c) `state_changed` not emitted. | GUT: enter/exit counter on spy State = 1 (only from boot; 0 additional calls) | Logic |
| **AC-09** | On `transition_to(current_state, force_re_enter=true)` call, the AC-06 procedure executes normally (`exit` → object re-assigned → `enter` → emit). An emit occurs with `from_name == to_name`. | GUT: same spy as AC-08, only force_re_enter argument changed | Logic |

### H.3 Signal Handling Guards (AC-10 ~ AC-13)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-10** | On `dispatch_signal(&"any", [])` call with `current_state == null`: (a) handler called 0 times (b) 0 console errors/warnings (c) `state_changed` emitted 0 times. | GUT: attempt dispatch *before* boot() call | Logic |
| **AC-11** | dispatch_signal guard evaluation order is *latch first* (D.3 #1): if `_lethal_hit_latched == true`, the handler is not called for `name == &"player_hit_lethal"` *even if the handler is implemented*. | GUT: manually set latch + implement AliveState `handle_player_hit_lethal` → dispatch → verify 0 calls | Logic |
| **AC-12** | When `Damage.player_hit_lethal` is emitted twice in the same physics tick: (a) ALIVE→DYING transition exactly once (b) `_lethal_hit_latched` is true immediately after the first emit (c) second emit discarded at guard #1 (d) single entry in `_state_history`. | GUT: simulate two emits + count history entries | Logic |
| **AC-13** | E-4 unimplemented handler: when `current_state` (e.g. AliveState) has *no* `handle_rewind_started` implemented and TRC emits `rewind_started`: (a) console clean (b) SM state unchanged (c) next `dispatch_signal` call functions normally. | GUT: spy State with handler intentionally omitted | Logic |

### H.4 ECHO Machine Hosting (AC-14 ~ AC-19, AC-26, AC-27)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-14** | `EchoLifecycleSM` connects signals in `_connect_signals()` in the following *exact* order (all `CONNECT_DEFAULT`, no flags): (1) Damage.player_hit_lethal (2) TRC.rewind_started (3) TRC.rewind_completed (4) TRC.rewind_protection_ended (5) SceneManager.scene_will_change. Changing the order or using `CONNECT_DEFERRED` fails this AC. | GUT (Round 1 B5 + Round 1 godot-specialist F1): after `_ready()` completes, `await get_tree().process_frame` (deferred flush) → verify `Damage.get_signal_connection_list(&"player_hit_lethal")[0].callable.get_method() == &"_on_damage_lethal"`. Same pattern for TRC 4 signals · SceneManager 1 signal. Verify `flags` field of each connection is 0 (CONNECT_DEFAULT). | Logic |
| **AC-15** | O1 latch: `_lethal_hit_latched == true` immediately after `ALIVE → DYING` transition. `false` after all of: `REWINDING → ALIVE`, `REWINDING → DEAD`, **and the `DYING → DEAD` direct path** (on grace expiry — I2 fix 2026-05-10, time-rewind.md AC-C2 reciprocal). No change on other transitions. | GUT: verify latch value in each of 5 transition scenarios (`ALIVE→DYING` set / `DYING→REWINDING` unchanged / `REWINDING→ALIVE` clear / `REWINDING→DEAD` clear / `DYING→DEAD` clear) | Logic |
| **AC-16** | O2 pause swallow: `should_swallow_pause()` returns (a) `false` in ALIVE state (b) `true` in DYING state (c) `true` in REWINDING state (d) `false` in DEAD state. | GUT: verify polling result in each of the 4 states | Logic |
| **AC-17** | O3 input buffer: with defaults `D=12, B=4`, all 5 scenarios in the D.2 table are evaluated correctly (in/out). Additionally: when `F_input == -1` (no input received), clause 1 (`F_input >= 0`) is false → predicate false (B3 sentinel guard). | GUT: fix F_lethal + 5 F_input cases + sentinel `-1` case → evaluate predicate | Logic |
| **AC-17a** *(new Round 1 B4)* | DyingState intra-tick ordering: when a fixture injects `Input.is_action_just_pressed("rewind_consume")` in the same tick as DyingState entered with `_frames_in_state = D - 1` (default 11): (a) `transition_to(RewindingState)` call occurs (b) `damage.commit_death()` called 0 times (c) `_frames_in_state` incremented 0 times (early return from input branch). Violation causes last valid frame input to be silently dropped. | GUT: verify D.5 ordering rule — pre-set frame counter in DyingState mock + input mock + transition spy + commit_death spy. | Logic |
| **AC-18** | O6 scene clear: on `scene_will_change` signal arrival: (a) `_lethal_hit_latched == false` (b) `_rewind_input_pressed_at_frame == -1` (c) `current_state` unchanged. | GUT: set latch+buffer to arbitrary values → emit signal → verify | Logic |
| **AC-19** | E-8 missing boot call silent: when the host omits the `boot()` call: (a) 0 delegations on `physics_update` calls (b) 0 handler calls on signal arrival (c) console clean. *Permanently inactive*. | GUT: verify 0 responses to all 5 input types when boot is not called | Logic |
| **AC-26** | E-10 DEAD state input unresponsive: when `current_state == DeadState`: (a) DeadState *implements no* `handle_*` handlers → all signals discarded at D.3 guard #3 (b) `physics_update` only increments `_frames_in_state` (c) `state_changed` not emitted (no transition). No resurrection path — Scene Manager reload is the only path back to ALIVE. *Note*: this AC verifies SM-level unresponsiveness only; downstream systems (VFX/Audio/HUD) responding to Damage's `death_committed` signal to display death feedback are *not blocked* (game-designer F5 advisory — DEAD silence is SM-level; player feedback is owned by Damage GDD F.3 downstream). | GUT: after entering DeadState, emit 5 signal types + poll input → verify SM state unchanged + state_changed counter == 0 | Logic |
| **AC-27** *(new Round 1 B8)* | E-13 host==null boot rejection: when a `State` instance's `host` remains null after `_ready()`, on `boot(state)` call: (a) `push_error("State host unresolved")` fires exactly once (b) `current_state == null` maintained (boot rejected) (c) subsequent `physics_update` calls produce 0 delegations (same silent path as AC-19) (d) signals discarded at guard #2. *Explicit inactivity*. | GUT: spy State with host unassigned → call boot() → capture push_error (`OS.has_feature("debug")` environment) + verify current_state + verify 0 responses to 5 input types. | Logic |

### H.5 Cascade & Misuse (AC-20 ~ AC-22)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-20** | E-6 queue cap: when a design defect causes `enter()` to call `transition_to` 5 times consecutively: (a) enqueues 1-4 proceed normally (b) `push_error` fires on the 5th call (c) 5th item discarded (d) SM settles at the state from the 4th enqueue. | GUT: spy that calls transition 5 times inside enter() + capture push_error | Logic |
| **AC-21** | E-12 direct assignment detection: when external code directly assigns `state_machine.current_state = some_state`: (a) `state_changed` signal not emitted (b) `_is_transitioning` flag unchanged. **This AC is a negative test guaranteeing the *explicit silence signature*.** | GUT: attempt direct assignment → verify state_changed counter == 0 | Logic |
| **AC-22** | E-14 arity mismatch (Round 1 B8): when SM handler has different arg count from signal signature on emit: **(a — BLOCKING)** `_lethal_hit_latched` changes 0 times + `current_state` changes 0 times + `state_changed` emitted 0 times. **(b — advisory)** Godot console error fires — cannot capture `print-error` in headless GUT, so replaced with *visual inspection during playtest*. **Prerequisite**: all `handle_*` methods use statically typed args (`func handle_foo(cause: StringName) -> void`, NOT `func handle_foo(cause)`) — without this prerequisite, even (a) is not guaranteed (godot-specialist FINDING-4). | GUT: intentionally mismatch arg count → emit → verify all 3 states (latch, current_state, signal count) unchanged. | Logic |

### H.6 Reuse Across Entities (AC-23 ~ AC-25)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-23** | By the end of Tier 1, the following 3 machines operate correctly *without any framework code changes*: (M1) EchoLifecycleSM, (M2) DroneAISM (5 states), (M3) StriderBossSM (3+ phases). | Integration: manual playtest in a 3-entity integration scene + per-machine GUT tests | Integration |
| **AC-24** | C.3.5 1000-cycle determinism: when running GUT tests 1000 times with the same seeded input sequence, the last 32 `_state_history` entries of EchoLifecycleSM are *identical across all 1000 runs*. | GUT: fix seed + run 1000 iterations + compare result hash | Logic |
| **AC-25** | C.3.6 performance budget (Round 1 B8 measurement method specified + performance-analyst Steam Deck recommendation): with 32 concurrent SMs active (ECHO + 30 enemies + 1 boss) in 1 stage at 60fps, accumulated SM call time < 0.5ms / frame in a **Steam Deck hardware** 5-minute playtest. | Integration: measurement method = record `Time.get_ticks_usec()` at entry/exit of `StateMachine.physics_update()` → register 32 SM × per-frame cumulative value via `Performance.add_custom_monitor(&"sm/frame_us", ...)` → export Godot profiler to calculate 5-minute average. **Steam Deck only** measurement (desktop-only profiling insufficient — desktop ~0.6× CPU factor puts value near 0.45–0.5ms). Screenshot must include measured value + scene context. | Integration |

### H.7 Gate by Tier

| Tier | Required ACs |
|---|---|
| **Tier 1 (4-6 weeks)** | AC-01 ~ AC-22 (including AC-17a as a separately enumerated row) + AC-24 + AC-26 + AC-27 = **26 Logic ACs** — *framework-only gate* (evaluable without Enemy AI GDD #10 · Boss Pattern GDD #11). AC-17a newly included (B4 intra-tick ordering). |
| **Tier 1 integration gate** *(when available)* | AC-23 (3-machine reuse) + AC-25 (Steam Deck perf) — evaluable *only after* Enemy AI GDD #10 + Boss Pattern GDD #11 are written and implemented (qa-lead Round 1 BLOCKING #3·#10 — H.7 cross-system dependency made explicit). |
| **Tier 2 (6 months)** | + Re-verify AC-23 with 3 additional enemy archetypes + integrate 1000-cycle determinism (AC-24) into auto-CI |
| **Tier 3 (16 months)** | + When Difficulty Toggle is integrated, verify `pause_swallow_states` **non-override** — confirm Easy mode does *not* bypass this invariant (Difficulty Toggle GDD's responsibility, B2 — Time Rewind Rule 18 preserved) |

### H.8 Recommended GUT Test File Paths

Per `.claude/docs/coding-standards.md` Test Evidence by Story Type:

```
tests/unit/state_machine/
├── state_machine_primitives_test.gd      # AC-01 ~ AC-05
├── state_machine_atomicity_test.gd       # AC-06 ~ AC-09
├── state_machine_dispatch_guards_test.gd # AC-10 ~ AC-13
├── echo_lifecycle_sm_test.gd             # AC-14 ~ AC-19, AC-26, AC-27, AC-17a
├── state_machine_misuse_test.gd          # AC-20 ~ AC-22
└── state_machine_determinism_test.gd     # AC-24

tests/integration/state_machine/
├── tier1_three_machine_reuse_test.gd     # AC-23
└── tier1_perf_budget_test.gd             # AC-25
```

Naming convention: `[system]_[feature]_test.gd` (per coding-standards.md). Test function names: `test_[scenario]_[expected]`.

---

## Z. Open Questions

Remaining decisions open during authoring of this GDD. Organised by category with resolution timing/conditions specified. Follows the same format as the 15 OQs in the Time Rewind GDD.

### Z.1 External GDD Dependencies (3) — decided together when other system GDDs are authored

| ID | Question | Dependency GDD | Decision timing |
|---|---|---|---|
| ~~**OQ-SM-1**~~ ✅ **Resolved 2026-05-09** | ~~Is the `Damage.player_hit_lethal` signature 1-arg `cause: StringName` or 0-arg?~~ → **1-arg `cause: StringName` locked** (Damage GDD DEC-1). All E-14/F.1/AC-22 assumptions consistent — no separate changes needed. | [`design/gdd/damage.md`](damage.md) DEC-1 + C.3.1 | **Resolved** |
| ~~**OQ-SM-2**~~ ✅ **Resolved 2026-05-11 (Scene Manager #2 Approved RR7)** | ~~Who is responsible for calling SM's `boot()` — from ECHO node's `_ready()` (current assumption)? Or Scene Manager explicitly calls it immediately after instantiating ECHO?~~ → **EchoLifecycleSM boots itself from its own `_ready()`** (natural scene-tree boot per C.2.1 line 322 lock-in). Scene Manager **does not directly call** `EchoLifecycleSM.boot()` (scene-manager.md C.1 Rule 10 sole-source); SM only performs scene swap via `change_scene_to_packed` and the new scene's `_ready()` chain triggers the natural boot. Avoids double-boot risk + solo debugging complexity. | [`design/gdd/scene-manager.md`](scene-manager.md) C.1 Rule 10 | **Resolved** |
| ~~**OQ-SM-3**~~ ✅ **Resolved 2026-05-11** | ~~Is the name `Input.is_action_just_pressed("rewind_consume")` finalised?~~ → **`rewind_consume` verbatim lock** (input.md C.1.1 row 8 single source). All *provisional* assumptions in F.1/D.2/AC-17 are consistent — no separate changes needed. Input #1 F.4.1 #6 closure. | [`design/gdd/input.md`](input.md) C.1.1 row 8 | **Resolved** |

### Z.2 Awaiting Playtest Decisions (2)

| ID | Question | Decision timing |
|---|---|---|
| ~~**OQ-SM-4**~~ ✅ **Resolved 2026-05-10 (Round 1 design-review B2)** | ~~`pause_swallow_states` empty-array override (Easy mode option)~~ → **Resolved as framework invariant, not a difficulty knob** (G.1 row + G.4 Tier 3 row + F.6 forbidden composition). Locked by direct citation of Time Rewind Rule 18 ("prevent the 12-frame grace from being converted into analysis time"). Easy mode difficulty adjustment uses only *Time Rewind-owned knobs* such as `RewindPolicy.dying_window_frames` (D=8/16/18) or `RewindPolicy.starting_tokens`. | **Resolved** |
| ~~**OQ-SM-5**~~ ✅ **Resolved 2026-05-10 (Round 1 design-review B6)** | ~~Does the `Q_cap=4` default remain free of false positives in Tier 2?~~ → **Resolved as `TRANSITION_QUEUE_CAP` const (safety invariant, not a knob)**. If `Q_depth_max > 2` is observed during Tier 2 measurement, it is treated as a *design defect*, not a re-measurement (preserves the D.4 cap meaning). The Tier 2 gate measurement obligation is moved to the D.7 footnote. | **Resolved** |

### Z.3 Awaiting Technical Verification (4) — requires direct confirmation of Godot 4.6 behaviour

| ID | Question | Verification method | Timing |
|---|---|---|---|
| **OQ-SM-6** | Is Godot 4.6 node `_ready()` call order *always* children-first + sibling-index deterministic? Does the ready order from dynamic `add_child()` timing affect 1000-cycle determinism? | 1000-run empty-scene add_child test + capture ready call order | Tier 1 Week 1 (engine-reference verification) |
| **OQ-SM-7** | Is the `current_state.callv()` path in `dispatch_signal` a *synchronous call*? Are there cases in Godot 4.6 where `callv` is deferred? | Godot docs + experiment | Tier 1 Week 1 |
| **OQ-SM-8** | When the `_state_history` ring buffer is used for *hash comparison* in the 1000-cycle determinism test, does a single GUT test run complete within 60s? Simulation load of 16ms × 60fps × 60s = 57,600 frames. | GUT prototype test | Tier 1 Week 4 |
| **OQ-SM-9** | Does signal `connect` order in Godot 4.6 exactly match *code line order*? Need to confirm whether changes from 4.4→4.5 affected this. (engine-reference/godot/4.5 or 4.6 release notes) | Direct check of docs/engine-reference | Tier 1 Week 1 |

### Z.4 Future Systems / Tier 2-3 Evaluation (2)

| ID | Question | Decision timing |
|---|---|---|
| **OQ-SM-10** | Hierarchical State Machine (HSM) adoption — evaluate when enemy archetypes grow beyond 5 in Tier 2 and shared-state (e.g. HIT_STUN, SLOWED) duplicate code reaches a threshold. Adoption decision via a framework-level ADR. | Tier 2 gate + when 5+ enemy archetypes are reached |
| **OQ-SM-11** | Visual State Machine Editor as a Godot Editor plugin — can a 14+ phase boss machine be maintained code-only during Tier 3 boss phase design? Cost vs value evaluation. | Tier 3 gate (when 4-6 boss types are added) |

### Z.5 Questions Resolved During This GDD

Questions *decided* during authoring — for future reference:

- **(Resolved)** State base type — `Node` chosen (C.1.1). Rejected alternative: `RefCounted`.
- **(Resolved)** Hierarchical model — Flat + multiple SM composition (C.1.1). HSM evaluated at Tier 2.
- **(Resolved)** ECHO 4-state hosting location — ECHO child node (C.2.1). Rejected alternatives: TRC, Autoload.
- **(Resolved)** SM's `physics_step_ordering` ladder slot — *none* (C.3.1). No architecture.yaml update required.
- **(Resolved)** `force_re_enter` default — `false` (E-5, AC-08). `true` only on explicit call.
- **(Resolved)** `TRANSITION_QUEUE_CAP` constant — `const int = 4` (D.1, D.4, D.7). Appropriate for solo Tier 1. Promoted from *knob* to *safety invariant const* in Round 1 design-review (B6).
- **(Resolved — Round 1 B2)** `pause_swallow_states` framework invariant — Time Rewind Rule 18 lock. Easy mode override forbidden.
- **(Resolved — Round 1 B5)** `EchoLifecycleSM._ready()` connect race — `call_deferred("_connect_signals")` pattern + null assertion.
- **(Resolved — Round 1 B7)** `EchoLifecycleSM` class hierarchy — `class_name EchoLifecycleSM extends StateMachine` (C.2.1).
- **(Resolved)** Player Fantasy framing — Systemic invariant (B). ECHO Defiant Loop cited as cascade fantasy.
- **(Resolved)** 4-state machine single source — `time-rewind.md` (C.2). This GDD specifies only the 6 hosting obligations.

---

## Appendix A. References

- `design/gdd/time-rewind.md` — System #9 Time Rewind System (locks ECHO 4-state machine + latch + pause swallow + signal contract)
- `docs/architecture/adr-0001-time-rewind-scope.md` — `rewind_lifecycle` signal contract (5 signals)
- `docs/architecture/adr-0003-determinism-strategy.md` — process_physics_priority ladder (player=0, TRC=1, enemies=10, projectiles=20)
- `docs/registry/architecture.yaml` — `interfaces.rewind_lifecycle`, `api_decisions.physics_step_ordering`
- `design/gdd/systems-index.md` — System #5 row + dependency map
- `.claude/docs/technical-preferences.md` — naming conventions, performance budgets, testing requirements
