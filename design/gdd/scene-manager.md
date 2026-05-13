# Scene / Stage Manager

> **Status**: In Design
> **Author**: seong-mungi + game-designer / systems-designer / gameplay-programmer / engine-programmer (per `.claude/skills/design-system` Section 6 routing for Foundation/Infrastructure)
> **Last Updated**: 2026-05-11
> **Implements Pillars**: Pillar 1 (Learning Tool — < 1s restart non-negotiable) · Pillar 2 (Determinism — boot-time RNG forbidden) · Pillar 4 (5-Minute Rule — Press-any-key gate forbidden) · Pillar 5 (Small Wins — Tier 1 single-stage slice only)
> **Engine**: Godot 4.6 / GDScript (statically typed)
> **Review Mode**: lean (CD-GDD-ALIGN gate skipped per `production/review-mode.txt`)
> **Source Concept**: `design/gdd/game-concept.md`
> **Cross-doc obligations carried in**: PM #6 OQ-PM-1 (8-var ephemeral clear ownership) · SM #5 OQ-SM-2 (boot() caller) · TR #9 OQ-4 (`scene_will_change` emit timing + token preservation)

---

## A. Overview

Scene / Stage Manager is the Foundation system that single-sources Echo's scene lifecycle (load · unload · checkpoint restart) and deterministic boot order. A single `SceneManager` autoload node holds the following 5 responsibilities: (1) **PackedScene transitions** — scene swap via `change_scene_to_packed` and the async preload branch to be introduced in Tier 2 multi-stage phase, (2) **Checkpoint anchor registration + < 1s restart guarantee** (Pillar 1 non-negotiable — no concession on restarting within 1 second after death), (3) **Scene boundary signal `scene_will_change()` emit** — this signal is subscribed to by the Time Rewind Controller to invalidate the ring buffer (`_buffer_invalidate()` — E-16 invalid-coord teleport prevention), subscribed to by EchoLifecycleSM to drive the O6 cascade (`_lethal_hit_latched` + input buffer + O8 idempotency counter clear), and is the single trigger that cascade-clears Player Movement's 8-var ephemeral state (4 coyote/buffer + 4 facing Schmitt flags) — via EchoLifecycleSM rather than direct subscription, (4) **`boss_killed(boss_id)` signal subscription** — stage clear branch, (5) **`scene_manager` group registration** (at first line of `_ready()`) — so that EchoLifecycleSM can deterministically discover via `get_first_node_in_group(&"scene_manager")`. Two lifecycle responsibilities are also single-sourced by this system: forced ALIVE transition on ECHO boot + the only ALIVE revival path from DEAD state (state-machine.md AC-26 / DeadState permanence contract). **Tier 1 scope is limited to single-stage slice + checkpoint restart** (Pillar 5 — Anti-Pillar #2: 5+ stages permanently excluded · Tier 1 = 1 stage); explicit release of multi-scene transitions and collage photo texture memory (1.5 GB ceiling) is deferred to the Tier 2 (3 stages) entry gate and added via this GDD revision.

## B. Player Fantasy

Scene Manager is a Foundation system, and its fantasy is defined not as *player emotions* but as **non-events the player must never witness**: (1) a *moment to think* exceeding 1 second between death and restart — Pillar 1 non-negotiable; (2) *loading patience* exceeding 5 minutes between boot and first actionable input — Pillar 4 5-Minute Rule; (3) *non-deterministic drift* between the checkpoint anchor and the respawn position — Pillar 2 Determinism. Only when these three invariants are satisfied do TR#9's Defiant Loop and PM#6's ephemeral state clear cascade function correctly. This GDD only defines *which invariants* make the cascade possible; the fantasy body is owned by `time-rewind.md` Section B.

**Cross-reference**:
- Pillar 1 (Learning Tool) / Pillar 2 (Determinism) / Pillar 4 (5-Minute Rule) — `design/gdd/game-concept.md`
- Fantasy owner (Defiant Loop) — `design/gdd/time-rewind.md` Section B
- Cascade clear receiver (8-var ephemeral) — `design/gdd/player-movement.md` F.4.2 row #2

**Three invariants → AC mapping commitment**: Each invariant is encoded 1:1 in testable form in Section H Acceptance Criteria — (1) checkpoint restart time ≤ 1.000 s (60 ticks @ 60 Hz); (2) cold-boot to first-actionable-input ≤ 300 s measurement + headless smoke check; (3) `scene_will_change` emit timing determinism + ECHO `_ready()` spawn position determinism. A 1:1 correspondence is maintained between the fantasy promises of Section B and the verification of Section H (following state-machine.md B/H pattern).

## C. Detailed Design

### C.1 Core Rules

Scene Manager is a single `SceneManager` autoload node that owns the scene lifecycle of Godot's `SceneTree`. The following 14 rules form the Foundation's immutable contract.

---

**[Group Registration and Discovery]**

**Rule 1.** The **first line** of `SceneManager._ready()` must be `add_to_group(&"scene_manager")`. No other initialization code may execute before it.
*Rationale*: Pillar 2 Determinism — ensures that `EchoLifecycleSM._ready()`'s (state-machine.md C.2.1 line 322) `get_first_node_in_group(&"scene_manager")` discovery never returns null at any point in the `_ready()` chain. Since autoloads are initialized before scene tree instantiation, this constraint is safe.

---

**[Autoload Identity and Process Ladder]**

**Rule 2.** `SceneManager` is an autoload singleton and must **not** implement `_physics_process` or `_process`. The ADR-0003 `process_physics_priority` ladder (PlayerMovement=0, TRC=1, Damage=2, enemies=10, projectiles=20) applies only to scene nodes; SceneManager occupies no slot in this ladder.
*Rationale*: ADR-0003 determinism — signal-based async reactions + no per-tick polling needed in Tier 1 single-scene slice.

---

**[Tier 1 Scene Transition Scope — Anti-Pillar Gate]**

**Rule 3.** The only allowed scene swap API in Tier 1 is `SceneTree.change_scene_to_packed(packed: PackedScene)`. `change_scene_to_file()`, `ResourceLoader.load_threaded_request()`, and other async load patterns are **forbidden** in Tier 1. Explicit `ResourceLoader.load` release for collage texture memory (1.5 GB ceiling) is also deferred to the Tier 2 gate.
*Rationale*: Pillar 5 (Small Wins) + Anti-Pillar #2 (5+ stages permanently excluded) — Tier 1 = 1 stage slice + checkpoint restart only; multi-scene + async load + explicit texture release are added via this GDD revision as the Tier 2 (3 stages) entry gate.

---

**[`scene_will_change` Signal — Sole Producer + Timing]**

**Rule 4.** `SceneManager` is the **sole producer** of the `scene_will_change()` signal. This signal must be emitted synchronously **before** the `change_scene_to_packed()` call, within the same physics tick. No other node may emit `scene_will_change`.
*Rationale*: Pillar 2 Determinism + TR E-16 invalid-coord teleport prevention — subscribers (TRC `_buffer_invalidate()`, EchoLifecycleSM O6 cascade) need valid references to scene nodes that are still alive. Emitting *after* unload begins would cause subscribers to race against a partially freed tree.
*Resolves*: **OQ-4 (TR #9)** — emit timing is "at transition entry (`change_scene_to_packed` call immediately preceding, same tick)". The "after unload begins" alternative is rejected.

---

**[`scene_will_change` Subscribers — PM Direct Subscription Forbidden]**

**Rule 5.** The only systems permitted to subscribe to `scene_will_change` are **TRC · EchoLifecycleSM · AudioManager**. `PlayerMovement` must **not** directly subscribe to `scene_will_change`; PM's 8-var ephemeral state (player-movement.md F.4.2 row #2: 4 coyote/buffer + 4 facing Schmitt flags) is cleared only through EchoLifecycleSM's O6 cascade. AudioManager subscribes independently for BGM hard cut + DUCKED state clear purposes (audio.md Rule 7).
*Rationale*: ADR-0001 + single-layer cascade design — PM owns only the *content* of ephemeral clear and delegates *timing* to EchoLifecycleSM. Direct subscription would give PM implicit knowledge of scene boundary timing, causing cross-cutting concern leakage.
*Resolves*: **OQ-PM-1 (PM #6)** — SM emit → EchoLifecycleSM `_on_scene_will_change()` → PM `_clear_ephemeral_state()` cascade.

---

**[Ring Buffer No-Touch]**

**Rule 6.** `SceneManager` must **not** directly access or modify TRC's ring buffer (`_write_head`, `_buffer_primed`, `PlayerSnapshot` slots). SM only emits `scene_will_change()`, and TRC is responsible for invalidating the buffer in its own `_buffer_invalidate()` handler.
*Rationale*: ADR-0002 + `forbidden_patterns.direct_player_state_write_during_rewind` (architecture.yaml) — TRC is the sole owner of the ring buffer.

---

**[Token Preservation Invariant]**

**Rule 7.** TRC's `_tokens` count is **preserved** when `scene_will_change` is emitted. SM must **not** read, write, or reset token values. Only `_buffer_primed` and `_write_head` are reset by TRC's `_buffer_invalidate()` (time-rewind.md F.1 row #2 + E-16).
*Rationale*: The token economy spans scene boundaries as meta-progression; only ring buffer coordinates are scene-local.

---

**[Checkpoint Anchor Registration — Deterministic Single Source]**

**Rule 8.** `SceneManager` is the **sole source** for registering the `global_position` of nodes tagged with the `checkpoint_anchor` group in a scene. Checkpoint anchor registration must execute after the scene's `_ready()` chain completes (immediately before the next `_physics_process`). If two or more anchors exist in a scene, the most recently registered anchor is used and `push_warning("Multiple checkpoint anchors in scene — using last")` is logged.
*Rationale*: Pillar 2 Determinism (boot-time RNG forbidden) + Pillar 1 support (if anchors are non-deterministic, the < 1s restart guarantee is meaningless).

---

**[< 1s Restart — Non-Negotiable Timing Ceiling]**

**Rule 9.** The checkpoint restart flow (DEAD entry → `change_scene_to_packed` completion → EchoLifecycleSM ALIVE entry) must complete within **60 physics ticks (60 Hz @ 1.000 s)**. This budget is **non-negotiable**. SM's `change_scene_to_packed` call must be a synchronous call and must not be wrapped in a coroutine or `call_deferred()`.
*Rationale*: Pillar 1 non-negotiable — "no concession on restarting within 1 second" (game-concept.md Pillar 1 Design test).
*Quality flag*: The 60-tick budget is a *contract*, but the actual number of ticks consumed by a single `change_scene_to_packed` call in Godot 4.6 varies by scene size, texture load, etc. — Section H ACs must require headless smoke check + Steam Deck 1st-gen real measurement.

---

**[EchoLifecycleSM Boot Ownership — Scene Tree Natural Boot]**

**Rule 10.** After a new scene loads, the forced ALIVE transition of `EchoLifecycleSM` occurs not through SM's direct `boot()` call, but through `EchoLifecycleSM._ready()` **self-booting** via Godot's natural scene tree `_ready()` chain. `SceneManager` must **not** directly call `EchoLifecycleSM.boot()`.
*Rationale*: ADR-0003 + state-machine.md C.2.1 — `EchoLifecycleSM._ready()` override is locked-in to directly perform signal connect + `boot()` without calling `super._ready()`. Direct SM call risks double-boot + increases solo debugging complexity.
*Resolves*: **OQ-SM-2 (SM #5)** — EchoLifecycleSM boots in its own `_ready()`; no additional SM wiring needed.

---

**[Non-Player State Reset Ownership — Scene Swap Is the Reset]**

**Rule 11.** `SceneManager` owns the state reset of enemies, projectiles, and environmental objects on checkpoint restart, but **does not directly reset individual nodes** — when the scene is swapped via `change_scene_to_packed()`, enemies/projectiles/environment are reset by the scene swap itself. SM must not call state reset functions directly on individual nodes.
*Rationale*: ADR-0001 (Player-only rewind scope — TRC restores player only) + Tier 1 single-scene-slice assumption.
*Tier 2 revision warning*: "Scene swap handles reset" is a Tier 1 assumption. When Tier 2 introduces the "in-place checkpoint without scene swap" pattern (memory efficiency), this rule must be revised to an *explicit group-by-group reset cascade*.

---

**[`boss_killed` Subscription — Stage Clear Single Trigger]**

**Rule 12.** `SceneManager` subscribes to `boss_killed(boss_id: StringName)` signal to trigger the stage clear scene transition. This subscription is SM's **only** Damage signal subscription. The detailed wiring of the stage clear flow (next scene determination, timing, fade) is defined in C.3.
*Rationale*: damage.md F.4 9-signal contract single-source (AC-13 BLOCKING) — `boss_killed` is the single signal emitted at the final phase's last hit. damage.md F.4 row states: `boss_killed → #2 Scene Manager (stage clear trigger)`.
*Cross-doc drift flag*: `time-rewind.md` (Rules 15/16, E-05/06, AC-B2/B3/B5, F.1 row #11, F.4.1) + `state-machine.md` (B.2, C.2.2 O5, F.3 row, line 499) contain **stale `boss_defeated`** references — presumed carry-over from before damage.md Round 4 LOCK. **Post-C.1 housekeeping batch recommended**: bulk replace `boss_defeated` → `boss_killed` (time-rewind.md 13 sites + state-machine.md 4 sites = **17 simple replacements**, non-destructive simple substitution — `grep -c boss_defeated` HEAD measurement 2026-05-11).

---

**[Cold Boot 5-Minute Rule — Press-any-key Forbidden]**

**Rule 13.** SM must design the scene load flow such that the time from cold boot (first game launch) to first actionable input does **not exceed 300 s (5 minutes)**. **Press-any-key gates are forbidden**; the first input event naturally triggers game start from the intro screen (input.md C.5 owner).
*Rationale*: Pillar 4 5-Minute Rule + Anti-Pillar #6 (excluding input remapping and full multilingual options → initial options menu gate can be removed).

---

**[No-op Guard — Same-Scene Reload Guard]**

**Rule 15.** When `scene_will_change` is emitted in the same physics tick as (or one tick before) a `player_hit_lethal` signal, the order of operations is deterministic: SM emit fires at tick T → TRC `_buffer_invalidate()` sets `_buffer_primed = false` + EchoLifecycleSM O6 cascade clears `_lethal_hit_latched` (all at tick T). If a lethal hit also occurs at tick T, `player_hit_lethal` opens the DYING grace window per the normal flow. Within that DYING window, `try_consume_rewind()` returns `false` because `_buffer_primed == false` (time-rewind.md Rule 13-bis guard). **The denial audio cue MUST play in this case** — this is the `buffer_invalidated` reason in time-rewind.md Rule 7's denial taxonomy. Silent denial violates state-machine.md B.3 anti-fantasy ("the player must know why rewind failed"). This scenario is non-recoverable regardless of token count.

**Rule 14.** Immediately before calling `SceneManager.change_scene_to_packed()`, if the argument is the same `PackedScene` reference as the currently loaded scene and the intent is "a simple re-transition rather than a checkpoint restart", do early-return + `push_warning()`. Same-scene reload is valid when it *is part of a checkpoint restart* — the identity check is determined by `PackedScene` reference + `intent: TransitionIntent` argument (C.2.3 enum) (`intent == TransitionIntent.CHECKPOINT_RESTART` passes only; `TransitionIntent.STAGE_CLEAR` / `COLD_BOOT` are classified as "not a checkpoint restart" and are early-return targets).
*Rationale*: Defensive — blocks unintended restart flow from code bugs (duplicate transition calls); checkpoint restart passes via explicit intent flag.

---

**OQ Resolution Summary (encoded in Rules 4 / 5 / 10)**

| OQ | Source | Resolution (encoding Rule) |
|---|---|---|
| **OQ-4** | TR #9 OQ list | `scene_will_change` emit timing = immediately before `change_scene_to_packed` call, synchronous emit in same physics tick (Rule 4) |
| **OQ-PM-1** | PM #6 OQ list | PM does not directly subscribe; PM 8-var cleared via EchoLifecycleSM O6 cascade (Rule 5) |
| **OQ-SM-2** | SM #5 OQ list | EchoLifecycleSM boots in its own `_ready()`; SceneManager must not directly call `boot()` (Rule 10) |

**Cross-doc drift discovered (Post-C.1 housekeeping batch recommended)**

| Drift | Affected GDD | Estimated sites | Recommendation |
|---|---|---|---|
| Unify `boss_defeated` → `boss_killed` | time-rewind.md + state-machine.md | TR 13 + SM 4 = **17 simple replacements** (HEAD `grep -c` measurement 2026-05-11) | damage.md F.4 (LOCKED + AC-13 BLOCKING) is the single-source authority. This GDD uses `boss_killed`. Bulk-replace the two downstream GDDs separately (Session 19 follow-up or Session 20 housekeeping) |

**Tier 2 revision triggers (pre-registered)**

| Rule | Tier 2 trigger condition | Parts requiring revision |
|---|---|---|
| Rule 3 | Multi-stage (≥ 2 stages) introduced | Allow async load (`load_threaded_request`) + explicit collage texture release |
| Rule 11 | In-place checkpoint (reset enemies/projectiles without scene swap) | Specify group-by-group reset cascade |

### C.2 States and Transitions

Scene Manager holds two state machines: (a) **transition lifecycle phase machine** (C.2.1) — a linear 5-phase pipeline that all scene transitions pass through / (b) **stage boundary state diagram** (C.2.2) — Tier 1 single-stage boundary states (BOOT_INTRO / ACTIVE / RESTART_PENDING / CLEAR_PENDING). The latter triggers the former.

#### C.2.1 Transition Lifecycle Phase Machine (linear 5-phase)

| Phase | Tick Budget | Entry Trigger | Body |
|---|---|---|---|
| **IDLE** | steady-state | (default) | Single scene load complete, awaiting transition trigger. No work. |
| **PRE-EMIT** | Tick T (**co-tick** with SWAPPING) | DEAD enter / `boss_killed` / cold-boot first input | (a) `scene_will_change()` emit (Rule 4); (b) await handler completion within same tick (TRC `_buffer_invalidate()`, EchoLifecycleSM `_on_scene_will_change()` cascade); (c) proceed to SWAPPING within same tick T |
| **SWAPPING** | M ticks (Godot SceneTree internal — Section H AC verification) | PRE-EMIT complete (same tick T) | `SceneTree.change_scene_to_packed(packed)` synchronous call. SM cannot observe per-tick progress inside the call. |
| **POST-LOAD** | `K` ticks (design guidance: `K < M`; D.1 binding constraint is the sum) | `change_scene_to_packed` returns | New scene `_ready()` chain executes; SM registers one one-shot next-frame callback via `get_tree().process_frame.connect(_on_post_load, CONNECT_ONE_SHOT)` to deterministically capture the moment the `_ready()` cascade completes (no coroutine — Rule 9 non-negotiable compliance; signal-callback based); callback body performs (1) `checkpoint_anchor` registration (Rule 8); (2) **query `stage_camera_limits: Rect2` from stage root + boot-time assert `assert(limits.size.x > 0 and limits.size.y > 0)` (E-CAM-7 — prevents invalid Rect2 from setting Camera2D `limit_*` setters to meaningless values causing player to escape visible world)**; *(Tier 1 provisional query: `var limits: Rect2 = get_tree().current_scene.stage_camera_limits` — Stage #12 GDD finalises query pattern per F.4.2 obligation)* (3) **`scene_post_loaded(anchor: Vector2, limits: Rect2)` signal emit** (Camera #3 first-use applied 2026-05-12 — Q2 closure; camera.md R-C1-10 + R-C1-12 handler invocation); (4) transition to READY phase. |
| **READY** | steady-state | EchoLifecycleSM emits `state_changed(_, &"alive")` | Accept input; SM returns to IDLE-effective. |

**Budget formula** (Rule 9 non-negotiable contract):

```
SWAPPING(M ticks) + POST-LOAD(K ticks) + 1(READY confirmation) ≤ 60 ticks (= 1.000 s @ 60 Hz)
   where K < M is design guidance; D.1 binding constraint is the sum.
```

PRE-EMIT is a **co-tick** with the first tick of SWAPPING (Rule 4: `scene_will_change()` emit + `change_scene_to_packed()` call occur in the same physics tick T) — therefore PRE-EMIT does **not** count against the budget. Measured values for M and K are unverified in Godot 4.6; Section H AC holds the obligation for headless smoke check + Steam Deck Gen 1 measurement.

**Linear, no branching**: The 5 phases form a single forward chain. Any trigger (checkpoint restart vs stage clear vs cold-boot) passes through the same PRE-EMIT → SWAPPING → POST-LOAD → READY pipeline. The difference between triggers lies in *which PackedScene is loaded*, not in *how the lifecycle proceeds*.

**Failure path**: If PackedScene is null or OOM occurs, the SM exits this lifecycle and routes to panic state — detailed handling defined in Section E.1.

#### C.2.2 Stage / Encounter Boundary State Diagram (Tier 1 minimal)

Tier 1 = single stage slice. The SM owns **scene boundaries only**; the stage-internal encounter flow is owned by Stage / Encounter System #12 (Not Started).

| Boundary State | Owner | Entry Trigger | Next Action |
|---|---|---|---|
| **BOOT_INTRO** | SM | cold boot complete | first input arrives → enter PRE-EMIT (C.2.1) |
| **ACTIVE** | Stage #12 (Tier 1 deferred) | new scene `_ready()` complete + EchoLifecycleSM ALIVE entered | Stage #12 manages encounter triggers; SM awaits next boundary trigger |
| **RESTART_PENDING** | SM | EchoLifecycleSM DYING → DEAD transition | enter PRE-EMIT (C.2.1 — reload same PackedScene) |
| **CLEAR_PENDING** | SM | `boss_killed` received (Rule 12) | enter PRE-EMIT (C.2.1 — in Tier 1 single stage = "victory screen" PackedScene or same-stage reload; revised to next-stage PackedScene upon Tier 2 entry) |

These 4 boundary states are *entry slots* that trigger the C.2.1 lifecycle — there is no branching inside the C.2.1 phase machine.

#### C.2.3 Implementation Pattern — Enum + match

The internal phase machine is implemented with GDScript `enum Phase` + `match` statement and **does not use the state-machine.md `State`/`StateMachine` framework**. Rationale: (1) single instance (autoload), (2) 5-phase linear — no concurrent reactions, (3) signal-emit external notification synchronizes all external nodes — no need for a generalized signal like `state_changed(from, to)`.

```gdscript
enum Phase { IDLE, PRE_EMIT, SWAPPING, POST_LOAD, READY }
enum TransitionIntent { COLD_BOOT, CHECKPOINT_RESTART, STAGE_CLEAR }
enum BoundaryState { BOOT_INTRO, ACTIVE, RESTART_PENDING, CLEAR_PENDING, PANIC }  # D.5 variable table 5-value enum

var _phase: Phase = Phase.IDLE
var _boundary_state: BoundaryState = BoundaryState.BOOT_INTRO  # C.2.2 cold-boot initial slot
var _respawn_position: Vector2 = Vector2.ZERO                  # D.3 selection result; AC-H3b/AC-H10
var current_scene_packed: PackedScene = null                   # Rule 14 same-PackedScene guard tracking (no `_` prefix — matches walkthroughs C.3.2/C.3.3 + AC-H18; RR6 rename)

@export var stage_1_packed: PackedScene        # G.2 designer-tunable (default `preload("res://scenes/stage_1.tscn")`). `@export` field — `_` prefix convention reserved for private vars; inspector-public field uses bare name (RR6 rename matching G.2 / walkthroughs)
@export var victory_screen_packed: PackedScene # G.2 designer-tunable (default `preload("res://scenes/victory_screen.tscn")`). `@export` field — bare name per inspector-public convention (RR6 rename)
```

State entry/exit is handled by synchronous phase progression in the `_trigger_transition(packed: PackedScene, intent: TransitionIntent)` function (coroutines prohibited — Rule 9 non-negotiable). The state-machine.md framework targets multi-entity concurrent reactive machines for ECHO / enemies / bosses; SceneManager is a single-instance linear lifecycle and does not justify the framework overhead.

**Single-source API policy**: External callers (input.md C.5 cold-boot router, other future systems) use only the single entry point `SceneManager.change_scene_to_packed(packed: PackedScene, intent: TransitionIntent)` — bool flag API is not adopted (a bool cannot distinguish the 3-state cold-boot vs stage-clear vs checkpoint-restart). Internal handlers (`_on_boss_killed`, `_on_state_changed`) call `_trigger_transition()` directly, and both paths use the same `TransitionIntent` enum. The Rule 14 no-op guard is applied at the external API entry point (`SceneManager.change_scene_to_packed`); internal `_trigger_transition` is not protected by Rule 14 (internal handlers have their intent guaranteed by D.5 boundary state evaluation).

#### C.2.4 Ownership Boundary Note

- **SM owns**: scene boundaries, transition lifecycle (5 phases), `scene_will_change` emit, checkpoint anchor registration, `boss_killed` subscription, 4-state boundary diagram (BOOT_INTRO / ACTIVE / RESTART_PENDING / CLEAR_PENDING).
- **SM does not own**: in-stage encounter flow (Stage #12), enemy spawning (Stage #12), boss phase advance (damage.md D.2.1), token economy (TR #9 — Rule 7 preservation obligation only), HUD updates (HUD #13 — directly subscribes to TR/Damage signals).

**Tier 1 boundary state evolution (RR6 surfaced)**: C.2.2 says `ACTIVE` entry is owned by Stage #12 (Tier 1 deferred). Consequently, **in Tier 1 production `_boundary_state` never reaches ACTIVE** — the evolution path is BOOT_INTRO → (stays BOOT_INTRO after cold-boot transition close) → RESTART_PENDING (permanent after first DEAD) → CLEAR_PENDING (after boss_killed). The `_on_state_changed(_, &"alive")` handler only sets `_phase = READY` and leaves `_boundary_state` unchanged (C.3.3 pattern). This is not a contract bug but an *incomplete state machine* — when Stage #12 is introduced the ACTIVE slot owner is filled, and the evolution path normalizes to BOOT_INTRO → ACTIVE → RESTART_PENDING/CLEAR_PENDING → ACTIVE. Tier 1 ACs (especially AC-H18) rely on the handler's state-agnostic nature to verify the contract without mocking ACTIVE state — both AC-H11 and AC-H18 require only "SM is IDLE" as Given.

### C.3 Interactions with Other Systems

#### C.3.1 SM Signal Emit / Subscribe Matrix

**SM emits (2 signals — sole producer for both)**:

| Signal | Signature | Subscribers | Emit guard |
|---|---|---|---|
| `scene_will_change` | `()` (zero args) | TRC (`_buffer_invalidate()`) · EchoLifecycleSM (`_on_scene_will_change()` cascade — `_lethal_hit_latched` + input buffer + O8 counter + PM 8-var via PM `_clear_ephemeral_state()` call) · AudioManager (`_on_scene_will_change()` — Music bus 0 dB restore + `stop_bgm()`, audio.md Rule 7) | Single-emit per transition (Rule 4); SM is sole producer (Rule 4) |
| `scene_post_loaded` | `(anchor: Vector2, limits: Rect2)` | Camera #3 (`_on_scene_post_loaded` → snap-to-anchor + stage limit set + `reset_smoothing()`; camera.md R-C1-10 + R-C1-12) | Single-emit inside POST-LOAD phase immediately after `checkpoint_anchor` registration + after passing boot-time assert `limits.size > 0` (E-CAM-7). Camera #3 first-use 2026-05-12 (Q2 closure — DEC-SM-9 status flip). Additional subscribers Stage #12 / HUD #13 possible upon Tier 2 entry. |

**SM subscribes (3 signals)**:

| Subscribed signal | Signature | Source | SM handler behavior |
|---|---|---|---|
| `boss_killed` | `(boss_id: StringName)` | damage.md F.4 (boss host emits at final phase last hit per damage.md D.2.1) | SM → boundary CLEAR_PENDING → enter C.2.1 PRE-EMIT. boss_id logged for future analysis; not differentiated in Tier 1. |
| `state_changed(_, &"alive")` | from EchoLifecycleSM | state-machine.md C.2.1 framework | SM transitions POST-LOAD → READY phase (lifecycle close) |
| `state_changed(_, &"dead")` | from EchoLifecycleSM | state-machine.md C.2.2 (DYING → DEAD transition) | SM → boundary RESTART_PENDING → enter C.2.1 PRE-EMIT (subject to C.3.3 same-tick priority policy taking precedence) |

HUD #13, VFX #14, Camera #3 do **not directly subscribe** to SM's signals — each independently subscribes to TR / Damage / EchoLifecycleSM signals (separation of obligations; SM is the scene boundary owner, not a presentation distribution hub). Audio #4 is the exception — directly subscribes to `scene_will_change` for BGM hard-cut purposes (Rule 5 permitted, audio.md Rule 7).

#### C.3.2 Checkpoint Restart Wiring (DEAD → ALIVE in ≤ 60 ticks)

End-to-end tick-by-tick table (Rule 9 non-negotiable contract verification):

| Tick | Owner | Action |
|---|---|---|
| T−1 | EchoLifecycleSM | DYING grace expired (12 frames, damage.md DEC-6) → DEAD enter (state-machine.md C.2.2) |
| T+0 | SM (`_on_state_changed`) | DEAD detected → boundary RESTART_PENDING → enter PRE-EMIT phase |
| T+0 | SM | emit `scene_will_change()` (Rule 4 — sole producer) |
| T+0 | TRC (`_on_scene_will_change`) | `_buffer_invalidate()`: `_buffer_primed = false`, `_write_head = 0`, `_tokens` **preserved** (Rule 7 / TR E-16) |
| T+0 | EchoLifecycleSM (`_on_scene_will_change`) | O6 cascade: clear `_lethal_hit_latched`, input buffer, O8 counter; call PM `_clear_ephemeral_state()` → PM 8-var (4 coyote/buffer + 4 facing Schmitt) reset (Rule 5; player-movement.md F.4.2 row #2) |
| T+0 | SM | `change_scene_to_packed(current_scene_packed)` synchronous call (Rule 4 co-tick) → SWAPPING phase |
| T+1 .. T+M | SceneTree (engine internal) | scene unload + load — M ticks (unverified in Godot 4.6 — Section H AC measurement) |
| T+M+1 .. T+M+K | new scene `_ready()` chain | EchoLifecycleSM own `_ready()` boot (Rule 10) → enter initial state + (next tick) ALIVE state_changed emit |
| T+M+K | SM | `process_frame` one-shot callback fires (registered via `connect(..., CONNECT_ONE_SHOT)` immediately after `change_scene_to_packed` returns at T+M+K-1) → enter POST-LOAD phase → `checkpoint_anchor` registration (Rule 8) |
| T+M+K+1 | SM (`_on_state_changed`) | receive `state_changed(_, &"alive")` → READY phase transition (lifecycle close) |

**Budget check**: `M + K + 1 ≤ 60 ticks` (T+0 same-tick work is bundled into the single PRE-EMIT phase, not counted). Measurement of M and K verified by Section H AC via headless smoke check + Steam Deck Gen 1 measurement.

**Same-PackedScene reload semantics** (Rule 14 protection): Since checkpoint restart reloads the same PackedScene, the Rule 14 no-op guard passes it through with `intent == TransitionIntent.CHECKPOINT_RESTART` (C.2.3 enum). For `TransitionIntent.STAGE_CLEAR` or `COLD_BOOT` if the same PackedScene reference is found, early-return + `push_warning()` — this does not occur in the normal call path (cold-boot uses `stage_1_packed`, stage-clear uses `victory_screen_packed` — different references).

#### C.3.3 Stage Clear Wiring (`boss_killed` → stage clear)

End-to-end tick-by-tick table:

| Tick | Owner | Action |
|---|---|---|
| T−1 | Damage system | boss final phase last hit → boss host D.2.1 branch: `remaining' == 0 ∧ phase_index == final` → set `_phase_advanced_this_frame = true` → emit `boss_killed(boss_id)` (damage.md AC-13) → schedule `queue_free()` |
| T+0 | SM (`_on_boss_killed`) | boundary CLEAR_PENDING → enter PRE-EMIT phase |
| T+0 | SM | emit `scene_will_change()` (Rule 4) |
| T+0 | TRC + EchoLifecycleSM | (same cascade as C.3.2 — `_buffer_invalidate()` + O6 cascade; `_tokens` preserved; +1 token grant on boss_killed handled separately by TRC per TR Rule 15) |
| T+0 | SM | `change_scene_to_packed(victory_screen_packed)` — **Tier 1**: single "victory screen" PackedScene; **upon Tier 2 entry**: this GDD revised to next-stage PackedScene |
| T+1 .. T+M+K+1 | (same SWAPPING / POST-LOAD / READY flow as C.3.2) | (same lifecycle) |

**Same-tick `boss_killed` + `state_changed(_, &"dead")` priority policy** (TR I2 / E-06 reciprocal):

Both signals (`boss_killed` from Damage host + `state_changed(_, &"dead")` from EchoLifecycleSM) can arrive in the SM handler queue in the same physics tick. The ADR-0003 process priority ladder specifies PlayerMovement(0) / TRC(1) / Damage(2) / enemies(10) / projectiles(20) but **EchoLifecycleSM's slot is not registered on the ladder** — therefore the SM arrival order of the two signals is treated as **undefined**. This policy is implemented via the `_boundary_state == CLEAR_PENDING` early-return guard in the C.3.3 GDScript pattern to guarantee the same result (CLEAR_PENDING wins) regardless of arrival order:

| Simultaneous arrival scenario | SM policy |
|---|---|
| `boss_killed` and `state_changed(_, &"dead")` arrive same tick | **CLEAR_PENDING *takes priority* over RESTART_PENDING** — SM evaluates the boss_killed handler first and locks boundary state to CLEAR_PENDING; the same-tick `state_changed(_, &"dead")` handler **early-returns** when boundary state == CLEAR_PENDING (no boundary state change, no lifecycle progression change) |

**Rationale**: Death after defeating the boss gives precedence to stage-end semantics — proceeding to the clear screen rather than restarting matches the player's mental model (Pillar 1 — the time rewind *learning tool* model does not disrupt stage progression flow). This policy is held as a single source by the SM; neither EchoLifecycleSM nor Damage performs priority handling.

**Implementation pattern**:

```gdscript
func _on_boss_killed(boss_id: StringName) -> void:
    _boundary_state = BoundaryState.CLEAR_PENDING
    _trigger_transition(victory_screen_packed, TransitionIntent.STAGE_CLEAR)

func _on_state_changed(from: StringName, to: StringName) -> void:
    if to == &"dead" and _boundary_state == BoundaryState.CLEAR_PENDING:
        return  # CLEAR_PENDING wins; ignore RESTART_PENDING request same tick
    if to == &"alive":
        _phase = Phase.READY
        return
    if to == &"dead":
        _boundary_state = BoundaryState.RESTART_PENDING
        _trigger_transition(current_scene_packed, TransitionIntent.CHECKPOINT_RESTART)
```

> **Pattern scope note**: The above snippet shows only the same-tick CLEAR vs RESTART priority logic — other entry guards spec'd by this GDD must be included separately in the production handler: (a) **panic-state guard** `if _boundary_state == BoundaryState.PANIC: return` (E.1 terminality + AC-H26); (b) **`_phase != Phase.IDLE` guard** `if _phase != Phase.IDLE: push_warning(...); return` (E.4 `boss_killed` during transition + E.5 `dead` during transition + AC-H19/AC-H20). Both handlers place the two guards at the *very top* of the function body (precedence: panic > phase ≠ idle > same-tick priority).

#### C.3.4 Q2 Resolved — POST-LOAD Signal Exposure (Camera #3 first-use applied 2026-05-12)

The C.2.1 POST-LOAD phase **emits the `scene_post_loaded(anchor: Vector2, limits: Rect2)` signal** — Camera #3 first-use trigger (camera.md C.3.3 batch + F.1 row #1 HARD dependency alignment). This signal is single-emitted immediately after `checkpoint_anchor` registration + after passing boot-time assert `limits.size.x > 0 ∧ limits.size.y > 0` (E-CAM-7). The signature's single source of truth is architecture.yaml `interfaces.scene_lifecycle.signal_signature`; this GDD holds the reference.

| System | Hook necessity | Trigger condition | Signal / Status |
|---|---|---|---|
| **Camera #3** | Camera snap-to-anchor on new scene entry (instant alignment without cut on checkpoint restart) + stage limit set | POST-LOAD entry → expose checkpoint_anchor `global_position` + stage `Rect2` | `scene_post_loaded(anchor: Vector2, limits: Rect2)` — **Active 2026-05-12 (Camera #3 Approved RR1 PASS first-use)** |
| Stage / Encounter #12 | Timing for encounter trigger node wiring | Immediately after anchor registration in POST-LOAD (same signal) | Reuse same signal (no signature change) — add subscription when Stage #12 GDD is authored |
| HUD #13 (Tier 2) | HUD fade-out timing on victory screen transition | Can be replaced by signal exposure in POST-LOAD or direct `state_changed(_, &"dead")` subscription | TBD (Tier 2 HUD GDD decision) |

**Tier 1 status (2026-05-12)**: POST-LOAD signal exposure **Active** — Camera #3 is the first-use trigger. Signal signature `scene_post_loaded(anchor: Vector2, limits: Rect2)` was decided as 2-arg (`anchor` + `limits`) at Camera #3 GDD authoring time to satisfy Camera-side R-C1-10 / R-C1-12 + AC-CAM-H5-01/02 obligations (`limits: Rect2` absorbs per-stage variability + reuses same signal upon Tier 2 multi-room entry). This closure flips the Camera #3 row obligation status to "Active" in F.4.2 (obligation upon subsequent GDD authoring), and both OQ-SM-A1 + DEC-SM-9 are resolved.

#### C.3.5 Cross-doc Reciprocal Obligations (Phase 5d batch applied)

Signal contracts newly added or changed by this GDD must be reflected in the following GDDs — applied in batch when Phase 5d Update Systems Index:

| Affected GDD | Change | Location |
|---|---|---|
| `time-rewind.md` | F.1 row #2 (Scene Manager) *(provisional)* → confirmed; signal signature `scene_will_change()` locked in (0 args); `_buffer_invalidate()` handler owner specified (TRC self) | F.1 row #2 |
| `time-rewind.md` | OQ-4 → resolved (emit timing = same tick immediately before `change_scene_to_packed` call) | Section Z OQ table |
| `state-machine.md` | C.2.2 O6 — Scene Manager provisional contract → confirmed; signal `scene_will_change()` (0 args) locked in | C.2.2 row O6 |
| `state-machine.md` | F.3 row #2 (Scene / Stage Manager — `scene_will_change()` subscriber) — provisional → confirmed | F.3 row #2 |
| `state-machine.md` | OQ-SM-2 → resolved (SM does not call `EchoLifecycleSM.boot()`; natural scene-tree boot per state-machine.md C.2.1 lock-in) | Section Z OQ table |
| `player-movement.md` | F.4.2 row #2 (Scene Manager) — OQ-PM-1 closure: PM does not directly subscribe to `scene_will_change`; `_clear_ephemeral_state()` call via EchoLifecycleSM cascade is the single path | F.4.2 row #2 |
| `docs/registry/architecture.yaml` | 4 new entries: `interfaces.scene_lifecycle` (signal `scene_will_change()` producer=scene-manager, consumers=[trc, echo-lifecycle-sm]); `state_ownership.scene_phase` (owner=scene-manager autoload); `api_decisions.scene_manager_group_name = "scene_manager"`; `api_decisions.checkpoint_anchor_group_name = "checkpoint_anchor"` | new entries |
| `design/registry/entities.yaml` | 2 new constants: `restart_window_max_frames = 60` (= 1.000 s @ 60 Hz Pillar 1 non-negotiable — Rule 9 contract); `cold_boot_max_seconds = 300` (Pillar 4 5-minute rule — Rule 13 contract) | constants section |
| `design/gdd/systems-index.md` | Row #2 Scene / Stage Manager: Status Not Started → Designed (or Approved post-review); add Design Doc link + add dependency to empty Depends On cell (None — Foundation) | Row #2 |

**Cross-doc drift housekeeping** (C.1 Rule 12 discovery): `boss_defeated` → `boss_killed` bulk replacement — time-rewind.md 13 sites (Rules 15/16, E-05/06, AC-B2/B3/B5, F.1 row #11, F.4.1) + state-machine.md 4 sites (B.2, C.2.2 O5, F.3 row #11, line 499) = **17 simple replacements** (HEAD `grep -c` measured 2026-05-11). damage.md F.4 LOCKED + AC-13 BLOCKING is single-source authority. **Recommended as separate housekeeping batch outside Phase 5d** (17 simple replacements, non-destructive; Session 19 follow-up commit or Session 20).

## D. Formulas

Scene Manager is a Foundation system and holds no balance curves or damage formulas. The 6 formulas in this section are all **budget invariants and selection rules**, encoding the Pillar 1/2/4 non-negotiable contracts in falsifiable form.

---

### D.1 Restart Lifecycle Budget Invariant

**Serves**: Pillar 1 non-negotiable · Rule 9 · C.2.1 SWAPPING+POST-LOAD budget

**Named expression**:

```
M + K + 1 ≤ 60   (ticks @ 60 Hz = 1.000 s)
```

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| M | int | 1–59 | SWAPPING phase ticks: from `change_scene_to_packed()` call to return. Godot 4.6 engine-internal — unverified at design time; Section H AC holds measurement obligation. |
| K | int | 0–58 | POST-LOAD phase ticks: new scene `_ready()` chain complete + `checkpoint_anchor` registration (Rule 8). The informal bound `K < M` in C.2.1 is design guidance; the binding constraint in D.1 is the sum. |
| 1 | const int | 1 | READY confirmation tick: SM receives `state_changed(_, &"alive")` → enters READY phase. |
| result | bool | {true, false} | `M + K + 1 ≤ 60` iff Pillar 1 honoured. `false` = blocking defect (non-negotiable). |

**Output Range**: Boolean invariant. `true` = Pillar 1 honoured. `false` = blocking defect.

**Tick-zero note**: The PRE-EMIT co-tick (Rule 4 — `scene_will_change` emit + `change_scene_to_packed` call occur in the same tick T+0) is included as the start of the SWAPPING phase and is not counted separately (no double-count).

**Worked example** (placeholder values — pending Section H measurement):

```
M = 30 ticks  (0.500 s — Godot 4.6 estimate, single scene, no streaming)
K = 12 ticks  (0.200 s — _ready() chain + anchor registration)
1 =  1 tick   (READY confirmation)
──────────────────
sum = 43 ≤ 60 → PASS  (17-tick headroom)
```

Violation example: `M = 50, K = 10, 1 = 1 → 61 > 60 → FAIL (Pillar 1 breach)`.

**Edge**: `M = 0` is invalid (synchronous engine call consumes at least 1 tick). Boot-time assert obligation: `M ≥ 1`. `K = 0` is legal (sub-tick `_ready()` chain completion possible) but unverified.

---

### D.2 Token Preservation Invariant

**Serves**: Rule 7 · TR E-16 · C.3.2 T+0 wiring

**Named expression**:

```
Δ_tokens_attributable_to_SM = 0
```

That is, the SM holds **no** write site for `_tokens`. If a change in `_tokens` value is observed before and after a transition, that is TR's responsibility (e.g. TR Rule 15 `boss_killed` → `grant_token()`), not the SM's.

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `_tokens_pre` | int | 0–5 | TRC `_tokens` value in the tick immediately before `scene_will_change` emit |
| `_tokens_post_SM` | int | 0–5 | TRC `_tokens` value after SM's handler chain completes (SM contribution only) |
| `Δ_tokens_attributable_to_SM` | int | {0} | Must be 0. SM has no `_tokens` read/write site. |
| result | bool | {true, false} | `Δ = 0` iff invariant maintained. `false` = code defect (SM writes `_tokens`; TR sole-ownership violation). |

**Output Range**: Boolean invariant. `false` = code defect (SM writes `_tokens`; TR sole-ownership violation).

**Worked example — checkpoint restart (RESTART_PENDING)**:

```
_tokens_pre = 3
SM emits scene_will_change → TRC _buffer_invalidate() clears _buffer_primed + _write_head only
_tokens_post_SM = 3   → Δ = 0 → PASS
```

**Worked example — boss kill (CLEAR_PENDING, same-tick TR grant)**:

```
_tokens_pre = 3
SM emits scene_will_change → TRC _buffer_invalidate()
TR grant_token() fires (TR Rule 15 — independent of SM)
_tokens_post_SM = 3   (SM contribution only)
TR contribution: _tokens = 4 — TR attributable, not SM → PASS
```

**Falsifiability**: grep `_tokens` in `scene_manager.gd` → 0 write-sites. 1+ matches = blocking defect.

---

### D.3 Checkpoint Anchor Selection Rule

**Serves**: Rule 8 · Pillar 2 determinism

**Named expression**:

```
respawn_position = anchors[N-1].global_position           (if N ≥ 1)
respawn_position = player.global_position (E.2 fallback)  (if N = 0; push_error + assert in debug — NOT BoundaryState.PANIC)
```

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| N | int | 0–∞ | Number of `checkpoint_anchor` group member nodes after scene `_ready()` chain completes |
| anchors[ ] | Node2D[] | — | Ordered list of group members. Godot scene-tree top-down order (`.tscn` serialisation determinism). No runtime sorting. |
| anchors[N-1] | Node2D | — | Last-registered = tree-bottom-most (most recent in clock time X — preserves reboot determinism). |
| `respawn_position` | Vector2 | scene-local, unbounded | `global_position` of the selected anchor. Guaranteeing playable bounds is the level designer's responsibility. |
| result | Vector2 | — | N ≥ 1 → anchor position; N = 0 → `player.global_position` (E.2 last-known-position handling; **not** `BoundaryState.PANIC` — PANIC is exclusive to the E.1 null-PackedScene path). |

**Output Range**: `Vector2` — unbounded (scene coordinate space). Playable bounds clamping is the level designer's responsibility (outside SM).

**Worked example**:

```
1 anchor in scene (320, 448):
  N = 1 → anchors[0].global_position = (320, 448) → respawn_position = (320, 448)

2 anchors in scene (tree-order): A (100, 200), B (300, 400):
  N = 2 → anchors[1] = B → respawn_position = (300, 400)
  push_warning("Multiple checkpoint anchors in scene — using last")
```

**Edge**: `N = 0` → `push_error` + `_respawn_position = player.global_position` (last known position) per E.2 — **not** `BoundaryState.PANIC` (PANIC is exclusive to the E.1 null-PackedScene terminal path / D.5 5th enum value). N=0 is a diagnostic signal and the lifecycle proceeds normally through IDLE/ACTIVE; AC-H10 verifies. `N > 1` is a level design warning, not a hard error (multiple anchor placement mid-stage + stage-start may be a valid pattern during iteration; warning is non-fatal).

---

### D.4 Cold Boot Budget

**Serves**: Pillar 4 5-minute rule · Rule 13

**Named expression**:

```
cold_boot_elapsed_s = (t_first_input_ms - t_process_start_ms) / 1000.0 ≤ 300.0
```

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `t_process_start_ms` | int | 0–∞ | OS epoch ms — game process launch. Godot equivalent: capture `Time.get_ticks_msec()` when `SceneManager._ready()` executes. |
| `t_first_input_ms` | int | `t_process_start_ms`–∞ | First accepted `InputEvent` triggers a gameplay action (intro screen → game start). Press-any-key gate prohibited (Rule 13); first input is a natural gameplay trigger. |
| `cold_boot_elapsed_s` | float | 0.0–∞ | Elapsed seconds from process start to first actionable input. Unbounded above; ≤ 300.0 s contract. |
| result | bool | {true, false} | `true` iff `cold_boot_elapsed_s ≤ 300.0`. |

**Output Range**: Boolean invariant on float. `false` = Pillar 4 breach; non-blocking advisory defect (unlike D.1, not non-negotiable). Measured expected value is ≪ 10 s; 300 s ceiling prevents extreme asset-streaming design.

**Scope note**: D.4 measures cold boot only. Warm reload (checkpoint restart, D.1) is excluded — D.1 holds that budget.

**Engine bootloader gap (scope boundary)**: `t_process_start_ms` is captured at `SceneManager._ready()` entry time, not at OS process launch — the Godot engine's own bootloader time (before GDScript first executes) is excluded from this measurement. Typical < 1 s on SSD; this gap is generally negligible, but if AC-H2b Steam Deck Gen 1 measurement approaches the 300 s ceiling, either (a) add external measurement obligation via OS stopwatch, or (b) revise D.4 formula to capture `t_process_start_ms = OS.get_unix_time_from_system()`. Current Tier 1 measurement expected value ≪ 10 s so this gap is advisory.

**Worked example**:

```
t_process_start_ms = 1_000_000
t_first_input_ms   = 1_004_200  (4.2 s boot — typical SSD load)
elapsed            = 4200 / 1000.0 = 4.200 s ≤ 300.0 → PASS

Pathological: elapsed = 310.0 s (streaming hang) → FAIL (Pillar 4 breach)
```

**Edge**: In the headless smoke-check environment (Section H AC), there is no person at the keyboard. Automated by scripted input injection at a fixed frame count after boot. Steam Deck Gen 1 SSD is the real target hardware baseline.

---

### D.5 Same-Tick Boundary State Resolution

**Serves**: C.3.3 priority policy · Rule 12 · ADR-0003

**Named expression**:

```
new_boundary_state =
  CLEAR_PENDING    if boss_killed_seen = true
  RESTART_PENDING  if boss_killed_seen = false ∧ dead_seen = true
  (unchanged)      if boss_killed_seen = false ∧ dead_seen = false
```

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `boss_killed_seen` | bool | {true, false} | True when SM's `_on_boss_killed()` handler fires within the current `_physics_process` tick. Tick-scoped: cleared to false when boundary-state evaluation in the same tick ends. |
| `dead_seen` | bool | {true, false} | True when SM's `_on_state_changed()` receives `to == &"dead"` within the current tick. Tick-scoped: same lifetime as `boss_killed_seen`. |
| `new_boundary_state` | BoundaryState enum | {BOOT_INTRO, ACTIVE, RESTART_PENDING, CLEAR_PENDING, PANIC} | SM boundary state after all handlers fire. Directly leads to C.2.1 PRE-EMIT entry (PANIC is exclusive to E.1 null PackedScene path — blocks lifecycle progression). |
| result | BoundaryState | (enum — 5 values) | Deterministic; no RNG. |

**Output Range**: Enum — 5 discrete values. No clamping; set exactly once per tick. PANIC is entered only via the E.1 (null PackedScene) diagnostic path, not the D.5 same-tick evaluation path — D.5's `new_boundary_state` does not include the E.1 PANIC branch, and when PANIC is entered D.5 is bypassed entirely (lifecycle progression blocked).

**Boolean precedence**: `boss_killed_seen` short-circuits `dead_seen`. This encoding is a player-mental-model contract — "if the boss died and the player died in the same hit, the stage is a clear, not a restart" (Pillar 1 — the Defiant Loop learning model is not disrupted by same-tick corner cases).

**Worked example — normal restart**:

```
Tick: boss_killed_seen = false, dead_seen = true
→ new_boundary_state = RESTART_PENDING → C.2.1 PRE-EMIT (reload same PackedScene)
```

**Worked example — same-tick boss kill + player death**:

```
Tick: boss_killed_seen = true, dead_seen = true
→ new_boundary_state = CLEAR_PENDING  (boss_killed_seen wins)
→ subsequent dead_seen handler: early-return, no state change
→ C.2.1 PRE-EMIT → victory screen PackedScene
```

**Edge**: When both `dead_seen` and `boss_killed_seen` are true in the same tick, the SM handler call order is **undefined** because EchoLifecycleSM's slot is not registered on the ADR-0003 priority ladder (`state_changed` first vs `boss_killed` first — arrival order irrelevant). The `_boundary_state == CLEAR_PENDING` early-return guard in the C.3.3 GDScript pattern guarantees the same result (CLEAR_PENDING wins) regardless of arrival order.

---

### D.6 `scene_will_change` Emit Cardinality Invariant

**Serves**: Rule 4 (sole producer) · Rule 6 (no buffer touch) · TR E-16 (TRC `_buffer_invalidate()` idempotency dependency)

**Named expression**:

```
emit_count(scene_will_change, per_transition) = 1
emit_count(scene_will_change, while_phase = IDLE) = 0
```

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `per_transition` | scope | — | One complete C.2.1 lifecycle pass: IDLE → PRE-EMIT → SWAPPING → POST-LOAD → READY. |
| `emit_count(e, scope)` | int | {0, 1} | Number of SM's `scene_will_change` emits within `scope`. Values outside {0, 1} are a defect. |
| `phase_at_emit` | Phase enum | {PRE_EMIT} | Emit is valid only when `_phase == Phase.PRE_EMIT`. Emitting in any other phase is a defect. |
| result | bool | {true, false} | Invariant holds iff `emit_count == 1` during transition AND `emit_count == 0` during IDLE. |

**Output Range**: Boolean invariant. Either clause `false` = blocking defect — double-emit causes double `_buffer_invalidate()` call → duplicate reset of `_write_head` + `_buffer_primed` → potential corruption of in-flight rewind sequence before transition.

**Worked example — satisfied**:

```
Transition triggered (DEAD received):
  _phase: IDLE → PRE_EMIT
  emit scene_will_change()  [count = 1 ✓]
  _phase: PRE_EMIT → SWAPPING
  ... POST_LOAD ... READY ... IDLE
  No further emits [IDLE count = 0 ✓] → PASS
```

**Violation example** (defended by D.6):

```
Bug: _on_state_changed fires twice in one tick (duplicate signal connect)
  emit scene_will_change()  [count = 1]
  emit scene_will_change()  [count = 2 ✗] → FAIL
  → TRC _buffer_invalidate() double call → _write_head double reset → ring buffer corruption
```

**Falsifiability**: Unit test — attach counter subscriber to `scene_will_change`, trigger a complete lifecycle pass → verify `counter == 1` at READY. IDLE-phase test: N ticks without triggering transition → verify `counter == 0`.

---

**Registry candidates (Phase 5b batch registration)** — already queued in C.3.5:

- `restart_window_max_frames = 60` (D.1 ceiling)
- `cold_boot_max_seconds = 300` (D.4 ceiling)

## E. Edge Cases

10 edge cases organized as: **Panic conditions** (E.1–E.3 — SM cannot proceed) · **Lifecycle re-entrancy** (E.4–E.6 — concurrent triggers) · **Boot edge cases** (E.7–E.9) · **Performance/resource** (E.10).

### Panic conditions

- **E.1 — `change_scene_to_packed(packed)` where `packed == null`**: SM places a `packed != null` guard *before* the `change_scene_to_packed` call → if null: `push_error("SceneManager: null PackedScene")` + set `_boundary_state = BoundaryState.PANIC` (5th enum value in D.5 — bypasses D.5 same-tick evaluation path) + keep `_phase = IDLE` (blocks lifecycle progression) + `assert(false)` in debug build. Release build stays on current frozen scene with a debug label (if panic occurs after DEAD enter, player is inoperable — recommended UX is game exit). *Rationale*: Missing PackedScene resource is a build omission, not a normal case during gameplay.
  - **PANIC terminality (Tier 1)**: In Tier 1, PANIC is a **terminal** state — no recovery path defined. After entering `_boundary_state = BoundaryState.PANIC`, the SM does **not** cause any `_trigger_transition()` calls. Even when subsequent `boss_killed` or `state_changed(_, &"dead")` signals arrive, the C.3.3 handler early-returns via the panic-state priority guard (`if _boundary_state == BoundaryState.PANIC: return`), blocking both `_boundary_state` overwrite and `_trigger_transition` call. As a result the lifecycle freezes in IDLE-locked state and normal gameplay cannot proceed — UX is game-exit guidance (separate system) or process exit. When a panic recovery policy (e.g. stage 1 fallback) is introduced upon Tier 2 multi-stage entry, revise this item + AC-H26 together. *Guard AC*: AC-H26 (H.4 group) verifies that subsequent signals after panic entry do not trigger `_trigger_transition` calls.

- **E.2 — N=0 checkpoint anchors (D.3 panic branch)**: 0 `checkpoint_anchor` group member nodes at scene `_ready()` chain completion → `push_error("SceneManager: no checkpoint anchor in scene")` + `respawn_position = current_player_position` (last known position) fallback + debug build `assert(false)`. In Tier 1 single stage, the level designer is obligated to place 1+ anchors — this fallback is a debug signal only, not a normal path.

- **E.3 — Out-of-memory during scene load**: `change_scene_to_packed` does not throw OS OOM signals (Godot behavior) — when the 1.5 GB memory ceiling is exceeded, SceneTree returns the new scene with failed texture loads. SM does not monitor memory (outside Tier 1 scope); `OS.get_static_memory_usage()` monitoring + 75% threshold push_warning to be introduced at Tier 2 gate.

### Lifecycle re-entrancy

- **E.4 — `boss_killed` arrives while `_phase != IDLE`**: SM receives `boss_killed` signal while transition lifecycle is in progress (`_phase ∈ {PRE-EMIT, SWAPPING, POST-LOAD}`) → `_on_boss_killed` handler early-return + `push_warning("boss_killed during transition — ignored")`. *Rationale*: A new transition trigger while lifecycle is in progress is ill-defined; naturally handled in the next boundary evaluation after the in-progress transition completes (enters READY). After boss defeat, when ECHO arrives at the new scene the boss host is already destroyed, so no further emit occurs.

- **E.5 — `state_changed(_, &"dead")` arrives while `_phase != IDLE`**: SM receives ECHO DEAD transition signal while lifecycle is in progress → same early-return (same policy as E.4). In Tier 1 the ECHO node itself is replaced by `queue_free()` or new scene instantiation during transition, so it normally doesn't occur; however this guard is kept as SM-side coverage of the state-machine.md C.2.2 race (DYING + scene_will_change simultaneous arrival).

- **E.6 — First input during BOOT_INTRO but EchoLifecycleSM not yet booted**: On cold-boot, the first input arrives at the splash/intro screen but EchoLifecycleSM has not yet entered ALIVE (Rule 10 — EchoLifecycleSM's own `_ready()` boot incomplete). SM does not receive input — input itself is owned by `input.md` C.5; SM ensures that input.md C.5 does not directly trigger `change_scene_to_packed` from `_input()`/`_unhandled_input()`. Instead, input.md sends a *transition request* to SM via the "intro screen → game start" router node. In Tier 1, first input = `change_scene_to_packed(stage_1_packed)` call is synchronously called from the input.md C.5 router and SM enters PRE-EMIT.

### Boot edge cases

- **E.7 — Cold boot input is a game-start non-trigger action like Esc / Pause**: The `input.md` C.5 router decides which input is the "game start" trigger on the intro screen. SM only receives router calls, so handling of this case is owned by input.md C.5 (e.g. Esc is quit-to-desktop, all other inputs are game start). This GDD only registers the router contract.

- **E.8 — Scene file missing on disk (E.1 variant)**: PackedScene missing from export at build time → `preload()` fails → null reference → same panic path as E.1. Defended by build validation in Tier 1 single stage; for Tier 2+ multi-stage, recommended to add `_validate_scene_table()` boot-time check to SceneManager (validate all stage PackedScenes with `is_class("PackedScene")`).

- **E.9 — Save file references invalid scene**: Tier 1 = no persistence (single stage slice). Upon Tier 2+ entry, handling of this case is held by Save / Settings Persistence #21 GDD — requests SM stage 1 fallback when invalid scene reference is encountered.

### Performance / resource

- **E.10 — `change_scene_to_packed` exceeds 60-tick budget (D.1 violation)**: M+K+1 > 60 ticks occurs → SM does *not block* budget violations (avoids game freeze — a 1-second-late restart is better than a stopped screen); however `push_warning("Restart budget exceeded: %d ticks" % total_ticks)` + auto-logged in Tier 1 playtest review-log. If Steam Deck Gen 1 measurement consistently violates 60-tick in Tier 1 Week 1 prototype, consider (a) reducing scene size, (b) introducing async load (early carry-over to Tier 2 scope). *Rationale*: Pillar 1 non-negotiable, but avoiding hard-crash takes priority.

---

**Edge cases NOT in scope of SM** (defer to specified GDD):

- Token grant cap overflow (TR Rule 3 / D1 ⇨ HUD #13)
- DYING grace change (Damage DEC-6)
- TRC `_buffer_invalidate()` own idempotency (TR E-16 — TRC sole ownership)
- Input buffer ephemeral state clear (SM #5 O6 cascade)
- Boss phase advance double-fire (Damage `_phase_advanced_this_frame` lock — damage.md D.2.1)

## F. Dependencies

### F.1 Downstream Dependents (systems that depend on SM)

> **Numbering convention**: `#N` references the row number in `design/gdd/systems-index.md`. Status mirrors that index at HEAD; status drift between this table and the index is a lint signal.

| # | System | Status | Interface | Hard / Soft | Notes |
|---|---|---|---|---|---|
| **#1** | Input System | Approved | input.md C.5 router calls `SM.change_scene_to_packed(stage_1_packed, TransitionIntent.COLD_BOOT)` on first cold-boot input (E.6 / E.7) | **Hard** | Cold-boot trigger source (Pillar 4 5-minute rule critical path). input.md C.5 owns router; SM exposes receive API. F.3 reciprocal already present. Added Session 19 RR5 (was structural omission). |
| **#3** | Camera System | Approved (RR1 PASS 2026-05-12) | `scene_post_loaded(anchor: Vector2, limits: Rect2)` (Camera #3 first-use 2026-05-12 — Q2 closure per C.3.4) | **Hard** | Camera snap-to-anchor on checkpoint restart (no cut) + stage limit set. Active in Tier 1. camera.md R-C1-10 + R-C1-12 + AC-CAM-H5-01/02 reciprocal. |
| **#4** | Audio System | Approved · 2026-05-12 | `scene_will_change()` → `_on_scene_will_change()` (BGM hard cut + DUCKED state clear, audio.md Rule 7); `boss_killed` (stage clear SFX Tier 1 stub, audio.md Rule 13) | **Soft** | Audio #4 Approved 2026-05-12. Rule 7 active in Tier 1; bus reset deferred to Tier 2. |
| **#5** | State Machine Framework | Approved | `scene_will_change()` → EchoLifecycleSM `_on_scene_will_change()` O6 cascade (state-machine.md C.2.2 O6) | **Hard** | Cascade triggers `_lethal_hit_latched` + input buffer + O8 counter clear + PM `_clear_ephemeral_state()` call |
| **#6** | Player Movement | Approved | (via #5 cascade — PM does not directly subscribe; player-movement.md F.4.2 row #2) | **Hard (via cascade)** | OQ-PM-1 closure: SM emit → EchoLifecycleSM cascade → PM 8-var clear. PM does not directly depend on SM. |
| **#8** | Damage / Hit Detection | LOCKED | `boss_killed(boss_id: StringName)` subscribed by SM (damage.md F.4) | **Hard** | Damage emit → SM CLEAR_PENDING → stage clear lifecycle (Rule 12 + C.3.3) |
| **#9** | Time Rewind System | Approved | `scene_will_change()` → TRC `_buffer_invalidate()` (time-rewind.md F.1 row #2 + E-16) | **Hard** | Single trigger for ring buffer invalidation; `_tokens` preserved |
| **#12** | Stage / Encounter System | Not Started | `scene_post_loaded(anchor: Vector2, limits: Rect2)` (signature locked 2026-05-12 via Camera #3 first-use; Stage GDD decides `limits: Rect2` exposure pattern from stage root) + `boss_killed` (stage clear router) | **Hard** | Stage #12 = SM's primary downstream client; SM owns boundary, Stage #12 owns in-stage encounter flow. See F.4.2 Stage #12 row obligation. |
| **#13** | HUD System | Not Started | (Tier 2 decision) direct `state_changed(_, &"dead")` subscription vs `scene_will_change()` subscription | **Soft** | HUD independently subscribes to TR / Damage / EchoLifecycleSM signals |
| **#15** | Collage Rendering Pipeline | Not Started | (Tier 2+) `scene_will_change()` → explicit texture cache release | **Soft (Tier 2)** | Explicit release unnecessary in Tier 1 single stage; revise this GDD upon Tier 2 entry |
| **#17** | Story Intro Text System | Not Started | SM instantiates intro text node inside stage_1 PackedScene (scene-internal wiring); no separate signal | **Soft** | Pillar 4 5-minute rule — intro 5-line typewriter waits for first input after self-completion |
| **#18** | Menu / Pause System | Not Started | (Tier 2 decision) SM `_phase` freeze policy on Pause | **Soft** | Pause changes process_mode; SM operates normally only in IDLE phase |

### F.2 Upstream Dependencies (systems SM depends on)

| Upstream | Status | Reason |
|---|---|---|
| — | — | SM is Foundation (Layer 0). No design-level upstream dependencies. Engine-level only: Godot 4.6 `SceneTree` + autoload subsystem. |

### F.3 Bidirectional Verification — F.1 reciprocals already in Approved GDDs

| Approved GDD | SM-side claim (this GDD) | Reciprocal location (target GDD) | Status |
|---|---|---|---|
| time-rewind.md | TRC subscribes `scene_will_change()` → `_buffer_invalidate()` | F.1 row #2 + E-16 | ✅ Present (*(provisional)* annotation to remove per C.3.5) |
| state-machine.md | EchoLifecycleSM subscribes `scene_will_change()` (O6 cascade) | C.2.2 O6 + F.3 row #2 | ✅ Present (provisional contract to confirm per C.3.5) |
| damage.md | `boss_killed` emit → "#2 Scene Manager (stage clear trigger)" | F.4 row (`boss_killed → #2 Scene Manager`) | ✅ Present (remove "not yet written" annotation per C.3.5) |
| player-movement.md | PM does not directly depend on SM; F.4.2 row #2 SM cascade obligation | F.4.2 row #2 | ✅ Present (add OQ-PM-1 closure annotation — 8-var clear responsibility via EchoLifecycleSM cascade) |
| input.md | input event → game start (#2 Scene Manager owner) | C.5 (cold-boot router; F.4.1 #4 cross-doc row) | ✅ Present (no edit needed) |

### F.4 Cross-doc Reciprocal Obligations

#### F.4.1 One-time closures (apply at Phase 5d)

Detailed table in C.3.5 — 7 GDD edits + 2 registry batch (entities.yaml + architecture.yaml). Summary:

- `time-rewind.md` F.1 row #2 + OQ-4 closure
- `state-machine.md` C.2.2 O6 + F.3 row #2 + OQ-SM-2 closure
- ~~`damage.md` F.4 row `boss_killed` — remove *(not yet written)* annotation~~ ✅ **Closed at RR5 2026-05-11**: annotation verified absent at HEAD; no edit needed.
- `player-movement.md` F.4.2 row #2 — OQ-PM-1 closure annotation update
- `docs/registry/architecture.yaml` — 4 new entries (`interfaces.scene_lifecycle`, `state_ownership.scene_phase`, 2 group-name `api_decisions`)
- `design/registry/entities.yaml` — 2 new constants (`restart_window_max_frames=60`, `cold_boot_max_seconds=300`)
- `design/gdd/systems-index.md` row #2 — In Design → Designed (Phase 5d) → Approved (post-review)

**Cross-doc drift housekeeping** (C.1 Rule 12 discovery): `boss_defeated` → `boss_killed` bulk replacement — time-rewind.md 13 sites + state-machine.md 4 sites = **17 simple replacements** (HEAD `grep -c` measured 2026-05-11). damage.md F.4 LOCKED + AC-13 BLOCKING is single-source authority. Split to Session 19 follow-up housekeeping batch (17 simple replacements, non-destructive).

> **⚠️ Approved promotion gate (BLOCKING)**: F.4.1 Phase 5d batch must be applied before promoting this GDD from "Designed (pending re-review)" → **Approved**. If not applied, F.3 bidirectional verification items remain stale and are detected as cross-review lint signals (verified at HEAD 2026-05-11 re-review #4: PM F.1 row line 978 still `*(provisional re #2 Not Started)*`; PM F.4.2 row line 531 still `*(provisional)*` + `TBD` wiring). Phase 5d 7-GDD batch + 2 registry batch are part of the Approved gate and can be split into separate commits but must be completed before passing the gate. Housekeeping batch (17-site `boss_defeated → boss_killed`) is a separate commit and is NOT BLOCKING for the Approved gate (damage.md single-source authority is guaranteed).

#### F.4.2 Future GDD obligations (obligations when target GDD is authored)

Each target GDD's H section must include a reciprocal AC when authored — not a current-PR PASS/FAIL gate for this GDD.

| Target GDD | Obligation | Closure trigger |
|---|---|---|
| ~~**Camera #3**~~ ✅ **Closed 2026-05-12 (Camera #3 Approved RR1 PASS)** | ~~(1) add `scene_post_loaded(anchor: Vector2)` signal — requires this GDD revision; (2) Camera snap-to-anchor on POST-LOAD entry; (3) AC: camera alignment complete within 1 tick after checkpoint restart~~ → **Resolved**: signal signature finalized as `scene_post_loaded(anchor: Vector2, limits: Rect2)` (2-arg — limits added for stage-by-stage variability absorption per camera.md C.3.3 + R-C1-12 single-source). C.2.1 POST-LOAD body now emits the signal after `checkpoint_anchor` registration + boot-time `assert(limits.size > 0)` (E-CAM-7). Camera handler R-C1-10 cost ≤ 1 tick (snap + 4 limit setters + reset_smoothing); fits within SM 60-tick restart budget without additional accounting. Camera AC-CAM-H5-01 (snap correctness) + AC-CAM-H5-02 (60-tick budget) verify the integration. Phase 5 cross-doc batch landed 2026-05-12. | Camera #3 GDD authoring (Closed) |
| ~~**Audio #4**~~ ✅ **Closed 2026-05-12 (Audio #4 Approved)** | ~~(1) `scene_will_change()` → bus reset (Tier 2 only); (2) `boss_killed` → stage clear SFX trigger; (3) AC: no audible crackle on SFX bus transition~~ → **Resolved**: Rule 7 active in Tier 1 (BGM hard cut + DUCKED state clear, audio.md Rule 7). `boss_killed` Tier 1 stub registered (audio.md Rule 13). Bus reset deferred to Tier 2. | Audio #4 GDD authoring (Closed) |
| **Stage / Encounter #12** | (1) use `scene_post_loaded(anchor: Vector2, limits: Rect2)` 2-arg signal — encounter trigger node wiring + decide `limits: Rect2` exposure pattern from stage root (export var `stage_camera_limits: Rect2` or `Marker2D` child node query) — signature locked 2026-05-12 via Camera #3 first-use; (2) `boss_killed` next PackedScene routing — revise this GDD's `change_scene_to_packed` argument decision logic upon Tier 2 entry; (3) AC: all encounter triggers registered on stage entry + `limits.size > 0` boot assert passes (E-CAM-7) | Stage #12 GDD authoring |
| **HUD #13** | (1) decide direct `state_changed(_, &"dead")` subscription vs `scene_will_change()` subscription; (2) AC: determinism of HUD fade-out timing on stage clear | HUD #13 GDD authoring |
| **VFX #14** | (1) active particle cleanup policy on `scene_will_change()` (immediate free vs natural expiry); (2) AC: 0 leftover particles on scene transition | VFX #14 GDD authoring |
| **Collage Rendering #15** | Upon Tier 2 entry: (1) `scene_will_change()` → explicit texture cache release; (2) AC: memory 1.5 GB ceiling not violated + new scene GPU texture load complete verified | Collage Rendering #15 GDD authoring (Tier 2 gate) |
| **Menu / Pause #18** | (1) SM `_phase` freeze policy on Pause; (2) AC: `change_scene_to_packed` not triggered during pause | Menu #18 GDD authoring |
| **Save Persistence #21** | (Tier 2+) (1) invalid scene reference fallback → SM requests stage 1; (2) AC: corrupt save file → game boots normally | Save #21 GDD authoring (Tier 2 gate) |

## G. Tuning Knobs

SM is a contract-driven Foundation system. Pillar 1 (< 1s restart) + Pillar 4 (5-minute rule) lock the D.1/D.4 budget ceilings as **non-negotiable invariants** — not tunable. In Tier 1, the only designer-adjustable values are intro pacing + diagnostic warning thresholds + scene table entries.

### G.1 Locked Constants (NOT tunable — Pillar non-negotiable)

| Constant | Locked value | Locked by | Modification gate |
|---|---|---|---|
| `restart_window_max_frames` | **60 frames** (= 1.000 s @ 60 Hz) | Pillar 1 / Rule 9 / D.1 | requires game-concept revision (Pillar change) — `/architecture-decision` |
| `cold_boot_max_seconds` | **300.0 s** | Pillar 4 / Rule 13 / D.4 | requires game-concept revision (Pillar 4 5-minute rule change) |
| `scene_manager_group_name` | `&"scene_manager"` | state-machine.md C.2.1 line 322 cross-doc lock | Cross-doc batch revision (5+ files) |
| `checkpoint_anchor_group_name` | `&"checkpoint_anchor"` | Rule 8 / D.3 | Cross-doc batch revision (level designer convention change) |

### G.2 Designer-Tunable (Tier 1)

| Knob | Default | Safe range | Affects | Out-of-range behaviour |
|---|---|---|---|---|
| `intro_screen_duration_seconds` | 8.0 | 5.0 – 30.0 | Directly affects Pillar 4 5-minute rule. 8.0 s is display time for 5-line intro typewriter + first input guidance. | < 5.0 → player enters game before reading intro text; > 30.0 → risk of Pillar 4 violation (erodes cold_boot budget) |
| `multiple_anchors_warning_n` | 2 | 1 – 10 | Rule 8 / D.3 — fires `push_warning` when `N > threshold`. Default 2 = "warn if 2 or more". | 1 → always warns (fires even with 1 anchor — wrong signal); ≥ 10 → effectively no warning (ignores intentional multi-anchor patterns in large scenes) |
| `victory_screen_packed` | `preload("res://scenes/victory_screen.tscn")` | (PackedScene resource path) | `change_scene_to_packed` argument on stage clear (Tier 1 single stage). Revise this knob to `next_stage_packed` dynamic lookup upon Tier 2 entry. | `null` → E.1 panic path; wrong PackedScene → E.2 anchor-absent panic on new scene entry |
| `stage_1_packed` | `preload("res://scenes/stage_1.tscn")` | (PackedScene resource path) | First `change_scene_to_packed` argument on cold boot. Tier 1 single stage. | `null` → E.1 panic; wrong path → build export missing E.8 |

### G.3 Debug-only Toggles (NOT shipped in release builds)

| Knob | Default | Affects |
|---|---|---|
| `debug_print_phase_transitions` | `false` | When `true`, `print()` on every `_phase` transition (lifecycle trace debugging). Forced `false` in release builds. |
| `debug_simulate_load_failure` | `false` | When `true`, always enters panic state immediately before `change_scene_to_packed` call (manual testing of E.1/E.8 scenarios). Forced `false` in release builds. |
| `debug_simulate_budget_overrun` | `false` | When `true`, forces mock `change_scene_to_packed` shim to deterministically consume M+K+1 > 60 ticks (for automated testing of E.10 / Rule 9 violation branch). Does not enter panic state; lifecycle reaches READY phase even after budget overrun (E.10 contract — "a 1-second-late restart is better than a stopped screen"). Forced `false` in release builds. **AC-H17 dependent — separate flag from `debug_simulate_load_failure`.** |
| `debug_panic_use_player_position` | `true` | E.2 (N=0 anchors) diagnostic signal behavior — when set to `false`, E.2 falls through as hard-freeze (so level designer immediately discovers missing anchor). Always forced `true` in release builds. |

### G.4 Interaction Notes (knob interactions)

- **`intro_screen_duration_seconds` × `cold_boot_elapsed_s` accumulation**: D.4 `cold_boot_elapsed_s` scope is `SceneManager._ready()` entry → first actionable input, with **Godot engine bootloader time excluded** (see D.4 "Engine bootloader gap (scope boundary)"). Therefore the accumulation that must fit within `cold_boot_max_seconds = 300` budget is `intro_screen_duration + additional scene load + first input wait`; engine boot is external measurement. Tier 1 measured expectation: intro 8 s + first stage load < 1 s + input ~0 s ≈ 9 s ≪ 300 s ceiling. (Engine boot ~3 s is separate OS-measurement — D.4 advisory: add OS stopwatch measurement obligation if Steam Deck Gen 1 AC-H2b result approaches ceiling.)
- **`multiple_anchors_warning_n` vs Tier 2 stage design**: When Tier 2 introduces mid-stage checkpoints, `N > 1` becomes a normal pattern, so raising threshold to 3 or above is recommended.
- **Locked invariants (G.1) vs designer knobs (G.2) — separate enforcement**: G.1 values are code consts + no `@export_range` (not exposed in Inspector); G.2 values exposed in Inspector via `@export_range` decorator (designer adjustment allowed).
- **Debug toggles (G.3) vs release builds**: Force-reset G.3 toggles via `Engine.is_editor_hint()` or build flag when entering release. Ensures debug-only items do not leak into release (Pillar 4 non-negotiable — blocks cold boot 5-minute violation in release builds).

## Visual / Audio Requirements

Scene Manager is a Foundation/Infrastructure system and does not directly own presentation assets. This system's signal emits trigger downstream presentation system behavior, but the *content* of each visual/audio element is solely owned by the respective owner GDD.

| Visual/audio element | Trigger signal (SM emit) | Single-owner GDD | Tier |
|---|---|---|---|
| Intro 5-line typewriter (text + SFX) | None — scene-internal wiring | **Story Intro Text System #17** | Tier 1 |
| Intro → stage_1 fade-in transition | None — after Story Intro #17 completes, first input → SM `change_scene_to_packed` | Story Intro #17 (visual) | Tier 1 |
| Checkpoint restart fade-out / fade-in | (Tier 2 decision) can subscribe to `scene_will_change()` | **HUD #13** (Tier 2 gate) | Tier 2 |
| Stage clear victory screen entry fade | `boss_killed` → SM CLEAR_PENDING → `change_scene_to_packed(victory_screen)` | HUD #13 (Tier 1 minimal; Tier 2 full design) | Tier 1 minimal |
| Audio bus reset on scene transition (crackle prevention) | `scene_will_change()` subscription (Tier 2) | **Audio #4** | Tier 2 |
| Stage clear SFX | `boss_killed` subscription | Audio #4 | Tier 1 stub |
| Active particle cleanup on scene transition (prevent visual leftovers) | `scene_will_change()` subscription | **VFX #14** | Tier 1 |

**Tier 1 SM-owned visual/audio scope**: None. All presentation delegated downstream. In Tier 1, SM only performs signal emit and PackedScene swap; the visual transition (fade) itself proceeds from the PackedScene's internal node `_ready()` chain or is handled by Story Intro #17 / HUD #13 via separate subscriptions.

~~**Q2 deferred signal — `scene_post_loaded(anchor: Vector2)`** (see C.3.4): this signal was to be added as a revision to this GDD when Camera #3 or Stage #12 GDD was authored. Emitting at POST-LOAD entry would enable Camera snap-to-anchor + encounter trigger wiring.~~ ✅ **Resolved 2026-05-12 (DEC-SM-9 / OQ-SM-A1 / Camera #3 RR1 PASS)**: signal is **Active** with 2-arg signature `scene_post_loaded(anchor: Vector2, limits: Rect2)` — added to C.2.1 POST-LOAD body per C.3.4. The struck-through paragraph's 1-arg signature was the stale/pre-resolution form. Canonical: C.3.4 + C.3.1 emit matrix + F.1 row #3 + DEC-SM-9.

> **📌 Asset Spec**: Scene Manager owns no sprite/SFX/VFX assets, so `/asset-spec system:scene-manager` is not applicable. Asset spec is run separately for each downstream system (#4 / #13 / #14 / #17).

## UI Requirements

Scene Manager does not directly own UI. SM's signals trigger UI system behavior, but the design of UI surfaces (screens, widgets, focus management) is held by the respective owner GDD.

| UI surface | SM involvement | Single-owner GDD | Tier |
|---|---|---|---|
| Cold boot intro screen (5-line typewriter) | SM instantiates intro node immediately before loading `stage_1_packed` | **Story Intro Text System #17** | Tier 1 |
| Stage clear victory screen | SM calls `change_scene_to_packed(victory_screen_packed)` — UI content is a separate PackedScene | **HUD #13** (Tier 1 minimal) | Tier 1 minimal |
| Pause menu | SM freezes `_phase` in paused state (F.4.2 Menu #18 obligation) — Menu UI is a separate system | **Menu / Pause System #18** | Tier 2 |
| Loading screen | Tier 1 = no loading screen needed with synchronous `change_scene_to_packed` (completes within 60-tick budget). Introduce upon Tier 2 async load entry. | (Tier 2 decision — HUD #13 or Menu #18) | Tier 2 |
| Game-over screen | Tier 1 = immediate checkpoint restart (Pillar 1 < 1s non-negotiable) — no game-over screen. | — (Tier 1 N/A) | — |
| Quit-to-desktop confirm dialog | Not SM's concern — determined by input.md C.5 Esc router (E.7) | Menu #18 | Tier 2 |

**Tier 1 SM-owned UI scope**: None. SM is only a signal producer + scene swap executor; all UI surfaces delegated downstream.

**UX flow accessibility note**: Due to Pillar 1 non-negotiable (< 1s restart) + Pillar 4 5-minute rule (no Press-any-key), SM creates no UI elements directly perceived by the user — all SM actions are *invisible*. From an accessibility standpoint, this system has no direct impact on screen reader / colorblind mode / input remapping (handled by F.4.2 Audio #4 / HUD #13 / Menu #18 respectively).

> **📌 UX Flag — Scene Manager**: This system has no direct UI requirements. When authoring UX specs during Phase 4 (Pre-Production), SM is not a `/ux-design` target — instead, Story Intro #17, HUD #13 (victory screen), and Menu #18 (pause) each run `/ux-design` when their GDDs are authored.

## H. Acceptance Criteria

### H.0 Preamble

**Total ACs: 30**

| Classification | Count | Gate |
|---|---|---|
| Logic (automated unit test — GUT) | 17 | BLOCKING |
| Integration (automated integration test OR documented playtest) | 11 | BLOCKING |
| Visual/Feel | 0 | — |
| UI | 0 | — |
| **BLOCKING total** | **28** | |
| Manual only (`[MANUAL]`) | 2 | ADVISORY |

Scene Manager owns no presentation surface — Visual/Feel and UI counts are 0 by design (see UI Requirements section). Two ACs are `[MANUAL]` (AC-H2b, AC-H23) due to Steam Deck Gen 1 hardware dependency; all others are automatable in CI. Logic AC enumeration: AC-H3a, AC-H3b, AC-H4..AC-H14, AC-H24, AC-H26, AC-H27, AC-H28. Integration AC enumeration (BLOCKING): AC-H1, AC-H2a, AC-H15..AC-H22, AC-H25. Integration ADVISORY: AC-H2b, AC-H23.

---

### H.1 Group 1 — Section B Invariant ACs (1:1 contract)

These three ACs fulfil the Section B "each invariant is encoded 1:1 in Section H ACs in testable form" promise.

---

**AC-H1 — Checkpoint restart completes within 60 ticks (≤ 1.000 s)**
**Classification**: Integration — BLOCKING
**Covers**: B-Inv-1 · Rule 9 · D.1 · C.2.1 budget · C.3.2

- **Given** a running scene with a valid `checkpoint_anchor` node and EchoLifecycleSM in ALIVE state
- **When** EchoLifecycleSM emits `state_changed(_, &"dead")` (DYING → DEAD transition)
- **Then** `state_changed(_, &"alive")` is received by SM within ≤ 60 physics ticks from the DEAD signal tick, measured as `M + K + 1 ≤ 60`

**Test mechanism**: GUT integration test `test_restart_budget_within_60_ticks` — inject DEAD signal, advance `get_tree().physics_frame` in a loop, assert `alive_received_tick - dead_received_tick ≤ 60`. Uses mock `SceneTree.change_scene_to_packed` shim that completes in a deterministic M ticks.
**Test scope**: **contract-level** (mock shim). Validates the wiring contract (M+K+1 ≤ 60 budget arithmetic, signal ordering, phase transitions) but does NOT exercise the real Godot 4.6 `change_scene_to_packed` engine path. Real-engine path validation: AC-H23 `[MANUAL]` on Steam Deck Gen 1 hardware.
**Note**: Rule 9 and E.10 present two faces of this invariant; see AC-H17 for the violation / warning face.

---

**AC-H2a — Cold boot headless smoke: first-input latency ≤ 300 s**
**Classification**: Integration — BLOCKING
**Covers**: B-Inv-2 · Rule 13 · D.4

- **Given** the game launched headless (`godot --headless`)
- **When** a scripted input injection fires at a fixed frame count after process start
- **Then** `cold_boot_elapsed_s = (t_first_input_ms - t_process_start_ms) / 1000.0 ≤ 300.0`

**Test mechanism**: Headless smoke check via `godot --headless --script tests/smoke/cold_boot_smoke.gd`; script captures `Time.get_ticks_msec()` at `SceneManager._ready()` and again at first `_input()` dispatch; asserts elapsed ≤ 300 s; exits non-zero on failure.

---

**AC-H2b — Cold boot Steam Deck Gen 1 measured ≤ 300 s** `[MANUAL]`
**Classification**: Integration — ADVISORY (hardware-dependent)
**Covers**: B-Inv-2 · Rule 13 · D.4

- **Given** the release build installed on Steam Deck Gen 1 (first-gen OLED or LCD; SSD)
- **When** the game is cold-launched (not resumed)
- **Then** elapsed time from process launch to first actionable input ≤ 300 s; no Press-any-key gate appears

**Test mechanism**: Manual playtest tester starts a stopwatch at game launch, records time at first gameplay input. Log saved to `production/qa/evidence/scene-manager/steam-deck-coldboot-[YYYY-MM-DD].md`. Sign-off: QA Lead.

---

**AC-H3a — `scene_will_change` emits before `change_scene_to_packed` in same tick**
**Classification**: Logic — BLOCKING
**Covers**: B-Inv-3 · Rule 4 · D.6

- **Given** SM is IDLE
- **When** a transition is triggered (DEAD signal OR `boss_killed` signal)
- **Then** `scene_will_change` is emitted exactly once, and all subscriber handlers (`_buffer_invalidate`, `_on_scene_will_change`) complete before `change_scene_to_packed` is called within the same physics tick

**Test mechanism**: GUT unit test `test_scene_will_change_emits_before_scene_swap` — spy both `scene_will_change.emit()` call order and `SceneTree.change_scene_to_packed` call order using mocked SM; assert emit tick == swap tick and emit call-index < swap call-index.

---

**AC-H3b — ECHO `_ready()` respawn position equals last registered anchor**
**Classification**: Logic — BLOCKING
**Covers**: B-Inv-3 · Rule 8 · D.3

- **Given** the new scene contains exactly one node tagged `checkpoint_anchor` at `global_position = (Ax, Ay)`
- **When** SM completes POST-LOAD and `_register_checkpoint_anchor()` runs
- **Then** `SM._respawn_position == Vector2(Ax, Ay)` (deterministic; no RNG)

**Test mechanism**: GUT unit test `test_respawn_position_equals_anchor_global_position` — instantiate scene with known anchor position, call `_register_checkpoint_anchor()` directly, assert `_respawn_position`.

---

### H.2 Group 2 — Static / Grep ACs (forbidden writes + structural rules)

---

**AC-H4 — SM source contains zero `_tokens` write sites (D.2 grep gate)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 7 · D.2

- **Given** the file `src/core/scene_manager/scene_manager.gd` at HEAD
- **When** CI runs `grep -nE '_tokens\s*(=|\+=|-=)' src/core/scene_manager/scene_manager.gd`
- **Then** exit code 0, match count = 0

**Test mechanism**: `tools/ci/sm_static_check.sh` (pattern precedent: `pm_static_check.sh`). CI gate; any match = BLOCKING failure. Sub-check bundled in same script: `_tokens` read via property access is permitted; write site is not.

---

**AC-H5 — SM does not touch ring buffer, PM does not directly subscribe `scene_will_change`, SM does not call `EchoLifecycleSM.boot()`**
**Classification**: Logic — BLOCKING
**Covers**: Rule 5 · Rule 6 · Rule 10

- **Given** the files `src/core/scene_manager/scene_manager.gd` and `src/gameplay/player_movement.gd` at HEAD
- **When** `tools/ci/sm_static_check.sh` runs the following three grep patterns (comments stripped first per `pm_static_check.sh` precedent — `sed -E 's|#.*$||'` pipeline):
  1. `grep -nE '(_write_head|_buffer_primed|_buffer_invalidate)' src/core/scene_manager/scene_manager.gd` → 0 matches (Rule 6)
  2. `grep -nE '(\.connect\s*\(\s*&?"?scene_will_change|scene_will_change\.connect)' src/gameplay/player_movement.gd` → 0 matches (Rule 5 — targets *subscription* via `.connect(...)` only; bare-string mentions in docstrings/comments do not trip the gate)
  3. `grep -nE '\.boot\s*\(' src/core/scene_manager/scene_manager.gd` → 0 matches (Rule 10)
- **Then** all three patterns return 0 matches; any non-zero = BLOCKING CI failure

**Test mechanism**: `tools/ci/sm_static_check.sh` (extend `pm_static_check.sh` precedent). All three grep checks run in sequence; script exits non-zero on first failure.

---

**AC-H6 — `add_to_group(&"scene_manager")` is present in SM source (Rule 1 presence)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 1

- **Given** `src/core/scene_manager/scene_manager.gd` at HEAD
- **When** `grep -n 'add_to_group.*scene_manager' src/core/scene_manager/scene_manager.gd` runs
- **Then** match count ≥ 1; zero matches = BLOCKING failure

**Test mechanism**: `tools/ci/sm_static_check.sh`. Note — grep verifies *presence* only; first-line ordering is verified by code review checklist (see Untestable Surface note H.U1).

---

**AC-H7 — SM declares no `_process` or `_physics_process` override**
**Classification**: Logic — BLOCKING
**Covers**: Rule 2

- **Given** `src/core/scene_manager/scene_manager.gd` at HEAD
- **When** `grep -nE 'func (_process|_physics_process)' src/core/scene_manager/scene_manager.gd` runs
- **Then** match count = 0; any match = BLOCKING failure

**Test mechanism**: `tools/ci/sm_static_check.sh`.

---

### H.3 Group 3 — Lifecycle & Formula ACs

---

**AC-H8 — `scene_will_change` emits exactly once per transition, zero times during IDLE (D.6 cardinality)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 4 · D.6

- **Given** SM is IDLE with a counter subscribed to `scene_will_change`
- **When** one complete lifecycle pass is triggered (IDLE → PRE_EMIT → SWAPPING → POST_LOAD → READY → IDLE)
- **Then** counter == 1 at READY entry; counter remains 1 after N idle ticks with no transition triggered

**Test mechanism**: GUT unit test `test_scene_will_change_cardinality_one_per_transition` (counter subscriber) + `test_scene_will_change_zero_during_idle` (N ticks, no trigger). Both must pass.

---

**AC-H9 — Multiple checkpoint anchors triggers push_warning and uses last anchor (D.3 N>1)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 8 · D.3

- **Given** a scene with N=2 checkpoint anchors at positions A=(100, 200) and B=(300, 400) in scene-tree order
- **When** SM's `_register_checkpoint_anchor()` runs after `_ready()` chain completes
- **Then** `SM._respawn_position == Vector2(300, 400)` (last = anchors[N-1]) AND `push_warning` was called with message containing "Multiple checkpoint anchors"

**Test mechanism**: GUT unit test `test_multiple_anchors_uses_last_and_warns`.

---

**AC-H10 — N=0 anchors triggers push_error and uses fallback player position (E.2)**
**Classification**: Logic — BLOCKING
**Covers**: E.2 · D.3 (N=0 branch)

- **Given** a scene with zero nodes tagged `checkpoint_anchor`
- **When** SM's `_register_checkpoint_anchor()` runs after `_ready()` chain completes
- **Then** `push_error` is called with message containing "no checkpoint anchor" AND `SM._respawn_position == player.global_position` (last known position fallback)

**Test mechanism**: GUT unit test `test_zero_anchors_pushes_error_and_falls_back`.

---

**AC-H11 — `boss_killed_seen` short-circuits `dead_seen` in same-tick collision (D.5)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 12 · D.5 · C.3.3

- **Given** SM is IDLE
- **When** `_on_boss_killed()` and `_on_state_changed(_, &"dead")` both fire within the same physics tick (any order)
- **Then** `SM._boundary_state == BoundaryState.CLEAR_PENDING` and the `state_changed(&"dead")` handler returns without triggering RESTART_PENDING

**Test mechanism**: GUT unit test `test_boss_killed_wins_over_dead_same_tick` — call both handlers in sequence (dead-first and boss-first variants), assert final boundary state is CLEAR_PENDING both times.

---

**AC-H12 — No-op guard: same-scene non-restart call returns early with push_warning (Rule 14)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 14

- **Given** SM has a current scene loaded (PackedScene ref `S`)
- **When** `SceneManager.change_scene_to_packed(S, TransitionIntent.STAGE_CLEAR)` is called (or any non-CHECKPOINT_RESTART intent against same scene)
- **Then** `push_warning` fires, no `scene_will_change` is emitted, no scene swap occurs

**Test mechanism**: GUT unit test `test_same_scene_non_restart_noop_and_warns` — assert emit counter = 0 and swap not called. Verifies both `TransitionIntent.STAGE_CLEAR` and `TransitionIntent.COLD_BOOT` non-restart variants short-circuit.

---

**AC-H13 — Same-scene checkpoint restart intent bypasses no-op guard**
**Classification**: Logic — BLOCKING
**Covers**: Rule 14 (intent enum pass-through)

- **Given** SM has current scene `S` loaded
- **When** `SceneManager.change_scene_to_packed(S, TransitionIntent.CHECKPOINT_RESTART)` is called
- **Then** lifecycle proceeds normally (PRE_EMIT → SWAPPING) without early-return

**Test mechanism**: GUT unit test `test_same_scene_checkpoint_restart_proceeds`.

---

**AC-H14 — `change_scene_to_packed(null)` triggers panic state, no scene swap (E.1)**
**Classification**: Logic — BLOCKING
**Covers**: E.1

- **Given** SM is IDLE
- **When** `change_scene_to_packed(null)` is called (or triggered by `null` PackedScene reference)
- **Then** `push_error` fires with "null PackedScene", `_phase` remains IDLE, `_boundary_state == BoundaryState.PANIC` (D.5 5th enum value — distinguishes panic entry from any other IDLE state), and no `scene_will_change` is emitted

**Test mechanism**: GUT unit test `test_null_packed_scene_panics_no_emit` — assert all four post-conditions (push_error message, `_phase == Phase.IDLE`, `_boundary_state == BoundaryState.PANIC`, emit counter == 0). Pairs with AC-H26 (terminality after entry — this AC covers entry; AC-H26 covers post-entry signal suppression).

---

### H.4 Group 4 — Cascade / Integration ACs

---

**AC-H15 — Full DEAD→ALIVE cascade clears PM 8-var ephemeral state (Rule 5 cascade)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 5 · C.3.2

- **Given** PlayerMovement has non-zero values in all 8 ephemeral vars (4 coyote/buffer + 4 facing Schmitt flags)
- **When** SM triggers a full checkpoint restart lifecycle (DEAD → SWAPPING → READY)
- **Then** all 8 PM ephemeral vars == 0/false at READY phase entry (verified via EchoLifecycleSM O6 cascade → `_clear_ephemeral_state()`)

**Test mechanism**: GUT integration test `test_restart_clears_pm_8var_ephemeral_state` — instantiate SM + EchoLifecycleSM + PM mock; trigger DEAD; advance frames to READY; assert all 8 vars reset. Uses dependency-injected PM stub.

---

**AC-H16 — TRC `_buffer_invalidate()` called on `scene_will_change`; `_tokens` unchanged (Rule 6/7)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 6 · Rule 7 · D.2

- **Given** TRC has `_tokens = 3`, `_buffer_primed = true`, `_write_head = 5`
- **When** SM emits `scene_will_change()`
- **Then** TRC `_buffer_primed == false` AND `_write_head == 0` AND `_tokens == 3` (unchanged)

**Test mechanism**: GUT integration test `test_scene_will_change_invalidates_buffer_preserves_tokens`.

---

**AC-H17 — Budget overrun fires push_warning and game continues (E.10, Rule 9 violation face)**
**Classification**: Integration — BLOCKING
**Covers**: E.10 · Rule 9 (violation branch)

- **Given** SM is configured with `debug_simulate_budget_overrun = true` (forces M+K+1 > 60 via mock shim deterministic latency injection — see G.3; distinct from `debug_simulate_load_failure` which forces panic)
- **When** a checkpoint restart is triggered
- **Then** `push_warning` fires with message containing "Restart budget exceeded" and game continues (READY phase is eventually reached, no hard freeze)

**Test mechanism**: GUT integration test `test_budget_exceeded_warns_and_continues` — set `debug_simulate_budget_overrun = true`, trigger restart, advance frames past 60, assert warning fired and READY eventually reached. **Flag scope note**: `debug_simulate_budget_overrun` (this AC) and `debug_simulate_load_failure` (AC-H14 panic path) are mutually exclusive debug paths — see G.3. **Harness reuse note**: AC-H1 (contract-level mock shim, M-tick normal path) and this AC share the same mock `SceneTree.change_scene_to_packed` infrastructure parameterized by `latency_ticks: int` (AC-H1 default = M; this AC = **61**, chosen M/K-independent to guarantee `latency_ticks + K + 1 > 60` regardless of actual Godot 4.6 M/K values — `M+K+2` was rejected in RR6 as it yields 57 ticks at worked-example M=30/K=12, below the 60-tick ceiling). Consolidating reduces test rig duplication.

---

**AC-H18 — `boss_killed` signal triggers CLEAR_PENDING and stage clear lifecycle (Rule 12)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 12 · C.3.3

- **Given** SM is IDLE (mirror AC-H11 — handler is state-agnostic; `_on_boss_killed` unconditionally sets `_boundary_state = CLEAR_PENDING` per C.3.3 pattern regardless of prior boundary state. RR6 dropped earlier "in ACTIVE boundary state" qualifier — Tier 1 never enters ACTIVE without Stage #12 per C.2.2; see C.2.4 Tier 1 boundary state evolution note)
- **When** `boss_killed(&"boss_0")` signal fires
- **Then** `SM._boundary_state == CLEAR_PENDING` AND lifecycle proceeds through PRE_EMIT → `change_scene_to_packed(victory_screen_packed)` → SWAPPING

**Test mechanism**: GUT integration test `test_boss_killed_triggers_clear_pending_and_swap`.

---

**AC-H19 — `boss_killed` during active transition is ignored with push_warning (E.4)**
**Classification**: Integration — BLOCKING
**Covers**: E.4

- **Given** SM is in SWAPPING phase (lifecycle in progress)
- **When** `boss_killed(&"boss_0")` fires
- **Then** `push_warning` fires with message containing "boss_killed during transition — ignored"; `_boundary_state` does not change; lifecycle does not restart

**Test mechanism**: GUT integration test `test_boss_killed_during_transition_ignored`.

---

**AC-H20 — `state_changed(_, &"dead")` during active transition is ignored (E.5)**
**Classification**: Integration — BLOCKING
**Covers**: E.5

- **Given** SM is in SWAPPING phase
- **When** `state_changed(_, &"dead")` fires
- **Then** handler returns without changing `_boundary_state` or triggering a new lifecycle pass

**Test mechanism**: GUT integration test `test_dead_signal_during_transition_ignored`.

---

**AC-H21 — Non-player objects reset via scene swap; SM does not call direct reset on individual nodes (Rule 11)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 11

- **Given** a scene with enemy node E at non-origin position, SM in ACTIVE state
- **When** SM executes a checkpoint restart (`change_scene_to_packed` with same scene)
- **Then** enemy E is unloaded by scene swap and new instance starts at scene-default position; SM never calls any method directly on E before swap

**Test mechanism**: GUT integration test `test_non_player_reset_via_scene_swap_not_direct_call` — spy on enemy node methods; assert zero direct SM-→-E calls during restart.

---

**AC-H22 — Cold boot completes with no Press-any-key gate (Rule 13 / Pillar 4)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 13 · D.4 (structural gate, complements AC-H2a/b)

- **Given** the headless boot smoke test sequence (AC-H2a setup)
- **When** the scripted input fires immediately after EchoLifecycleSM ALIVE emit (no hold)
- **Then** the input event is consumed and gameplay proceeds; no "press any key" node exists in the scene tree at first input time

**Test mechanism**: Headless smoke — `godot --headless --script tests/smoke/cold_boot_smoke.gd`; after ALIVE state, search scene tree for any node with "press_any_key" or "any_key" in name/class; assert none found.

---

**AC-H23 — Checkpoint restart on Steam Deck Gen 1 completes within 1.000 s wall-clock** `[MANUAL]`
**Classification**: Integration — ADVISORY (hardware-dependent)
**Covers**: B-Inv-1 · Rule 9 · D.1 (real-hardware confirmation of AC-H1)

- **Given** release build running on Steam Deck Gen 1 with Tier 1 stage_1 scene
- **When** ECHO death is triggered (falls to hazard or enemy projectile)
- **Then** ECHO is alive and input-responsive within ≤ 1.000 s wall-clock, measured with phone stopwatch across 5 repeated deaths

**Test mechanism**: `[MANUAL]` playtest session. Log: `production/qa/evidence/scene-manager/steam-deck-restart-[YYYY-MM-DD].md`. Must record: 5× measured times, all ≤ 1.000 s. Sign-off: QA Lead.
**Test scope**: **real-engine path** on Steam Deck Gen 1 hardware. Complements AC-H1's contract-level gate by validating the actual Godot 4.6 `change_scene_to_packed` tick consumption on target hardware. AC-H1 (contract) and AC-H23 (real path) together cover both faces of Rule 9 — AC-H1 catches wiring regressions in CI; AC-H23 catches engine/asset-budget regressions that only manifest on real hardware.

---

**AC-H24 — Only `change_scene_to_packed` (sync) is used for scene transitions; no async APIs present (Rule 3)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 3

- **Given** `src/core/scene_manager/scene_manager.gd` at HEAD
- **When** `grep -nE '(change_scene_to_file|load_threaded_request|load_threaded_get|await)' src/core/scene_manager/scene_manager.gd` runs
- **Then** match count = 0; any match = BLOCKING CI failure (Tier 1 async API forbidden)

**Test mechanism**: `tools/ci/sm_static_check.sh`.

---

**AC-H25 — EchoLifecycleSM self-boots via `_ready()`; SM does not wire any boot call (Rule 10, integration)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 10 · C.3.2 T+M+K row

- **Given** SM triggers a checkpoint restart (DEAD → SWAPPING → POST-LOAD)
- **When** the new scene's `_ready()` chain completes
- **Then** EchoLifecycleSM reaches ALIVE state without any direct `boot()` call from SM (verified by absence of `boot()` invocation in SM's call log during POST-LOAD phase)

**Test mechanism**: GUT integration test `test_echo_lifecycle_sm_self_boots_no_sm_call` — spy on EchoLifecycleSM; assert SM issues zero `boot()` calls; assert EchoLifecycleSM reaches ALIVE within POST-LOAD + READY phases.

---

**AC-H26 — Panic state is terminal: subsequent signals do not trigger lifecycle (E.1 terminality)**
**Classification**: Logic — BLOCKING
**Covers**: E.1 (PANIC terminality clause) · D.5 (PANIC bypass) · Rule 4 (no spurious emit)

- **Given** SM has entered `_boundary_state == BoundaryState.PANIC` via the E.1 null-PackedScene path (`_phase == IDLE` held)
- **When** `_on_boss_killed(&"boss_0")` and `_on_state_changed(_, &"dead")` are each invoked (separately, then in the same tick) with a spy attached to `_trigger_transition`
- **Then** `_trigger_transition` is **never** called; `_boundary_state` remains `PANIC` (not overwritten to CLEAR_PENDING or RESTART_PENDING); `scene_will_change` emit counter remains 0

**Test mechanism**: GUT unit test `test_panic_state_is_terminal_no_further_transition` — set `_boundary_state = BoundaryState.PANIC` directly; install spy on `_trigger_transition` + counter subscriber on `scene_will_change`; call each handler in 3 orderings (boss_killed alone, dead alone, both same tick); assert spy call_count == 0 AND `_boundary_state == BoundaryState.PANIC` AND emit counter == 0 in all 3 cases.

---

**AC-H27 — `SceneTree.change_scene_to_packed` is called exactly once per transition (D.6 symmetric cardinality)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 4 · D.6 (symmetric to scene_will_change emit cardinality)

- **Given** SM is IDLE with a mock `SceneTree.change_scene_to_packed` that records every call
- **When** one complete lifecycle pass is triggered (any of: DEAD signal, `boss_killed`, cold-boot first input)
- **Then** the mock swap-call counter == 1 at READY entry; counter remains 1 after N idle ticks with no further trigger

**Test mechanism**: GUT unit test `test_change_scene_to_packed_cardinality_one_per_transition` — install mock shim with counter; trigger each of 3 entry paths (DEAD, boss_killed, cold-boot first input via input.md router) in separate test cases; assert counter == 1 after each. Pairs with AC-H8 (scene_will_change emit cardinality) to close both faces of D.6.

---

**AC-H28 — `scene_post_loaded(anchor, limits)` emits exactly once per POST-LOAD after anchor registration; E-CAM-7 assert fires on zero-size Rect2 (Rule 4 — `scene_post_loaded` sole-producer face)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 4 (`scene_post_loaded` sole-producer face — symmetric to AC-H8 for `scene_will_change`) · C.3.1 (2-signal emit matrix) · C.2.1 POST-LOAD body · C.3.4

- **Given** SM completes a full lifecycle pass (IDLE → PRE_EMIT → SWAPPING → POST_LOAD)
- **When** the `_on_post_load` one-shot callback fires with a mock stage root exposing a valid `stage_camera_limits: Rect2` (Tier 1 provisional: `get_tree().current_scene.stage_camera_limits`)
- **Then (cardinality)**: `scene_post_loaded` emit counter == 1 at READY entry; counter remains 1 after N subsequent idle ticks with no new transition
- **Then (ordering)**: `scene_post_loaded` is emitted *after* `_register_checkpoint_anchor()` completes — the `anchor` argument matches `SM._respawn_position` at emit time; `_phase != Phase.READY` at the tick of emit
- **Then (E-CAM-7 debug path)**: when stage root provides `limits.size.x == 0 or limits.size.y == 0` (invalid Rect2), an assertion error is logged in debug mode (`assert` fires per C.2.1 boot-time assert)

**Test mechanism**: GUT unit test `test_scene_post_loaded_emit_cardinality_and_ecam7` — three sub-tests:
1. **Normal**: inject lifecycle with mock stage root (`stage_camera_limits = Rect2(0, 0, 800, 600)`); assert emit counter == 1 after POST-LOAD; assert emitted `anchor` arg == `SM._respawn_position`; assert emit precedes `_phase = Phase.READY`.
2. **Idle**: N ticks with no transition after READY; assert cumulative emit counter unchanged (still 1).
3. **E-CAM-7**: inject `stage_camera_limits = Rect2(0, 0, 0, 0)` into mock stage root; call `_on_post_load` in GUT error-watch context; assert assertion error is logged (debug-build gate for the boot-time `assert(limits.size.x > 0 and limits.size.y > 0)` guard).

**Note**: Camera #3 AC-CAM-H5-01/02 verify the *consumer* side (camera snap-to-anchor correctness + 60-tick budget). This AC verifies the SM *producer* side (emit cardinality, arg ordering, E-CAM-7 guard). Together they close the full integration contract for `scene_post_loaded`. Added RR8 2026-05-12 (Camera first-use addition coverage gap).

---

### H.5 Coverage Summary Table

| AC | B-Inv | C Rules | D Formula | E Edge |
|---|---|---|---|---|
| AC-H1 | B-Inv-1 | Rule 9 | D.1 | — |
| AC-H2a | B-Inv-2 | Rule 13 | D.4 | — |
| AC-H2b `[M]` | B-Inv-2 | Rule 13 | D.4 | — |
| AC-H3a | B-Inv-3 | Rule 4 | D.6 | — |
| AC-H3b | B-Inv-3 | Rule 8 | D.3 | — |
| AC-H4 | — | Rule 7 | D.2 | — |
| AC-H5 | — | Rule 5, Rule 6, Rule 10 | — | — |
| AC-H6 | — | Rule 1 | — | — |
| AC-H7 | — | Rule 2 | — | — |
| AC-H8 | — | Rule 4 | D.6 | — |
| AC-H9 | — | Rule 8 | D.3 | — |
| AC-H10 | — | — | D.3 (N=0) | E.2 |
| AC-H11 | — | Rule 12 | D.5 | — |
| AC-H12 | — | Rule 14 | — | — |
| AC-H13 | — | Rule 14 | — | — |
| AC-H14 | — | — | D.5 (PANIC entry) | E.1 |
| AC-H15 | — | Rule 5 | — | — |
| AC-H16 | — | Rule 6, Rule 7 | D.2 | — |
| AC-H17 | — | Rule 9 | D.1 | E.10 |
| AC-H18 | — | Rule 12 | — | — |
| AC-H19 | — | — | — | E.4 |
| AC-H20 | — | — | — | E.5 |
| AC-H21 | — | Rule 11 | — | — |
| AC-H22 | — | Rule 13 | D.4 | — |
| AC-H23 `[M]` | B-Inv-1 | Rule 9 | D.1 | — |
| AC-H24 | — | Rule 3 | — | — |
| AC-H25 | — | Rule 10 | — | — |
| AC-H26 | — | Rule 4 (no spurious emit during PANIC) | D.5 (PANIC bypass) | E.1 (terminality) |
| AC-H27 | — | Rule 4 (swap-call cardinality symmetric to emit) | D.6 (swap-call face) | — |

**Section B Invariant coverage check**: B-Inv-1 → AC-H1, AC-H23; B-Inv-2 → AC-H2a, AC-H2b; B-Inv-3 → AC-H3a, AC-H3b. All 3 invariants covered. ✅

**Rule coverage check**:

| Rule | AC(s) |
|---|---|
| Rule 1 | AC-H6 |
| Rule 2 | AC-H7 |
| Rule 3 | AC-H24 |
| Rule 4 | AC-H3a, AC-H8, AC-H26 (panic-state no-emit guard), AC-H27 (symmetric swap-call cardinality), AC-H28 (`scene_post_loaded` sole-producer face) |
| Rule 5 | AC-H5, AC-H15 |
| Rule 6 | AC-H5, AC-H16 |
| Rule 7 | AC-H4, AC-H16 |
| Rule 8 | AC-H3b, AC-H9 |
| Rule 9 | AC-H1, AC-H17, AC-H23 |
| Rule 10 | AC-H5, AC-H25 |
| Rule 11 | AC-H21 |
| Rule 12 | AC-H11, AC-H18 |
| Rule 13 | AC-H2a, AC-H2b, AC-H22 |
| Rule 14 | AC-H12, AC-H13 |

All 14 rules covered. ✅

**Formula coverage check**:

| Formula | AC(s) |
|---|---|
| D.1 | AC-H1, AC-H17, AC-H23 |
| D.2 | AC-H4, AC-H16 |
| D.3 | AC-H3b, AC-H9, AC-H10 |
| D.4 | AC-H2a, AC-H2b, AC-H22 |
| D.5 | AC-H11, AC-H14 (PANIC entry), AC-H26 (PANIC bypass / terminality) |
| D.6 | AC-H3a, AC-H8 (emit face), AC-H27 (swap-call face) |

All 6 formulas covered. ✅

**Edge case coverage check**:

| Edge | AC | Status |
|---|---|---|
| E.1 null PackedScene | AC-H14 (panic entry) + AC-H26 (panic terminality) | Covered |
| E.2 N=0 anchors | AC-H10 | Covered |
| E.3 OOM | — | Deferred — see H.U2 |
| E.4 boss_killed during transition | AC-H19 | Covered |
| E.5 dead during transition | AC-H20 | Covered |
| E.6 first input before EchoLifecycleSM boot | — | Deferred to input.md C.5 (router owner); not SM AC scope |
| E.7 cold boot Esc/Pause input | — | Deferred to input.md C.5 (router owner per GDD E.7 text) |
| E.8 scene file missing | — | Deferred — covered by build-time validation; same code path as E.1 at runtime |
| E.9 save file invalid | — | Deferred to Tier 2 / Save Persistence #21 (Tier 1 has no persistence) |
| E.10 budget exceeded | AC-H17 | Covered |

---

### H.6 Untestable / Surfaced Items

**H.U1 — Rule 1: first-line ordering of `add_to_group` (partially untestable by grep)**

The AC-H6 grep verifies *presence* of `add_to_group(&"scene_manager")` in SM source, but cannot verify it is the *first executable statement* in `_ready()`. GDScript has no AST lint tool in CI at this project's current tooling.

**Workaround**: Add a manual code-review checklist item: "Verify `add_to_group(&"scene_manager")` is the first non-comment line inside `SceneManager._ready()` before any other initialization call." This checklist runs as part of the PR review gate, not CI. Classify as advisory review item.

---

**H.U2 — E.3 OOM: cannot trigger deterministically in CI**

OOM during `change_scene_to_packed` cannot be reproduced deterministically in headless CI without a real asset set approaching the 1.5 GB ceiling — which does not exist in Tier 1 scope.

**Workaround**: Deferred to Tier 2 gate. When Tier 2 collage texture pipeline is introduced (Collage Rendering #15), a stress test on Steam Deck low-memory mode (4 GB RAM device) should be added as a `[MANUAL]` AC. Document in F.4.2 Collage Rendering #15 obligation.

---

**H.U3 — Rule 9 / E.10 contract tension (non-blocking design ambiguity, surfaced)**

Rule 9 says ≤ 60-tick budget is "non-negotiable" (non-negotiable), but E.10 says a violation produces `push_warning` and the game continues rather than hard-blocking. These are not contradictory: Rule 9 is the *design contract* (must not be violated under nominal conditions), and E.10 is the *runtime safety valve* (if violated, don't crash — log and continue). AC-H1 covers the nominal path (assert ≤ 60); AC-H17 covers the violation path (assert warning fires + game continues). Both must pass independently. If AC-H1 fails in CI, it is a BLOCKING defect regardless of AC-H17 passing.

## Open Questions

The 3 OQs (OQ-4 / OQ-PM-1 / OQ-SM-2) carried over at the time of authoring this GDD (Session 19, 2026-05-11) are all encoded in C.1 Rules 4 / 5 / 10 and are **resolved**. This section holds as a single source the deferred items newly surfaced during authoring + Tier 2 revision triggers.

| ID | Question | Closure Owner | Closure Trigger | Severity | Tier 1 interim handling |
|---|---|---|---|---|---|
| ~~**OQ-SM-A1**~~ ✅ **Resolved 2026-05-12 (Camera #3 first-use)** | ~~POST-LOAD phase signal exposure — when to add `scene_post_loaded(anchor: Vector2)` signal~~ → **Resolved**: signal added 2026-05-12 with 2-arg signature `scene_post_loaded(anchor: Vector2, limits: Rect2)` (Camera #3 GDD authoring + Approved RR1 PASS). C.2.1 POST-LOAD body emit + C.3.1 SM emits matrix entry + C.3.4 Q2 closure section. F.4.2 row Camera #3 status: Active. | (Closed) | (Closed) | — | — |
| **OQ-SM-A2** | In-place checkpoint reset pattern (resetting enemies/projectiles without scene swap) — introduce when Tier 2 memory efficiency improvements are needed | Stage / Encounter #12 GDD (Tier 2) | Tier 2 gate passed + memory measurement results approach 1.5 GB ceiling | MEDIUM (Tier 2) | Tier 1: Rule 11 "scene swap handles reset" assumption valid — single stage slice |
| **OQ-SM-A3** | Revision of D.1 60-tick budget formula when async load (`ResourceLoader.load_threaded_request`) is introduced | this GDD revision (Tier 2 gate) | Tier 2 entry + async load adoption decision | MEDIUM (Tier 2) | Tier 1: Rule 3 (sync only) valid; roll forward early if Steam Deck Gen 1 measurement shows consistent 60-tick violations |
| **OQ-SM-A4** | Explicit memory release (`ResourceLoader.load` cache release) — for Tier 3 5-stage × 300MB collage texture handling | Collage Rendering #15 GDD (Tier 2 gate) | Tier 2 entry + collage texture memory measurement | MEDIUM (Tier 2/3) | Tier 1: explicit memory release not needed in single stage |
| **OQ-SM-A5** | Multi-anchor checkpoint pattern — support N>1 anchor as a normal pattern when Tier 2 mid-stage checkpoints are introduced | Stage / Encounter #12 GDD (Tier 2) | Tier 2 entry + multi-anchor use cases arise | LOW (Tier 2) | Tier 1: D.3 `push_warning` policy valid; recommend raising `multiple_anchors_warning_n` knob |

**Resolved this session (Session 19)**:

| OQ | Resolution | Encoded location |
|---|---|---|
| **OQ-4** (carried from TR #9) | `scene_will_change()` emit timing = same tick immediately before `change_scene_to_packed` call (sync emit). Tokens always preserved. | C.1 Rule 4 + Rule 7 |
| **OQ-PM-1** (carried from PM #6) | PM does not directly subscribe to `scene_will_change`; PM `_clear_ephemeral_state()` call via EchoLifecycleSM O6 cascade is the single path | C.1 Rule 5 |
| **OQ-SM-2** (carried from SM #5) | SM does not directly call `EchoLifecycleSM.boot()`; EchoLifecycleSM boots from its own `_ready()` (natural scene-tree boot) | C.1 Rule 10 |
| Q2 (Session 19 surfaced) | POST-LOAD signal exposure deferred — this GDD revision when Camera #3 / Stage #12 / HUD #13 first use case arises | C.3.4 + OQ-SM-A1 |

---

## Z. Appendix (References)

### A.1 Locked Decisions (Session 19, 2026-05-11)

| ID | Decision | Rationale | Cross-ref |
|---|---|---|---|
| **DEC-SM-1** | SM is an autoload singleton; `_physics_process` / `_process` not used | ADR-0003 priority ladder targets scene nodes; SM is a signal producer | C.1 Rule 2 |
| **DEC-SM-2** | Tier 1 = `change_scene_to_packed` (sync) only; async + memory release in Tier 2 | Pillar 5 + Anti-Pillar #2; single stage slice | C.1 Rule 3 |
| **DEC-SM-3** | `scene_will_change()` emit timing = same tick immediately before `change_scene_to_packed` call | OQ-4 closure; prevents E-16 invalid-coord teleport | C.1 Rule 4 |
| **DEC-SM-4** | PM does not directly subscribe to `scene_will_change`; EchoLifecycleSM O6 cascade is the single path | OQ-PM-1 closure; single-layer cascade design | C.1 Rule 5 |
| **DEC-SM-5** | EchoLifecycleSM boots from its own `_ready()` (SM does not call `boot()`) | OQ-SM-2 closure; maintains state-machine.md C.2.1 lock-in | C.1 Rule 10 |
| **DEC-SM-6** | `boss_killed` signal name adopted (`boss_defeated` rejected) | damage.md F.4 LOCKED 9-signal contract + AC-13 BLOCKING is single-source | C.1 Rule 12 + C.3.5 housekeeping batch |
| **DEC-SM-7** | Same-tick `boss_killed` + `state_changed(_, &"dead")` → **CLEAR_PENDING takes priority** | Pillar 1 — Defiant Loop learning model must not waver on same-tick corner cases | C.3.3 + D.5 |
| **DEC-SM-8** | 5-phase linear lifecycle (IDLE/PRE-EMIT/SWAPPING/POST-LOAD/READY) implemented as `enum Phase` + `match` (state-machine.md framework not used) | Single-instance autoload + 5-phase linear + no concurrent reactions — framework overhead not justified | C.2.3 |
| **DEC-SM-9** | POST-LOAD signal exposure — **resolved 2026-05-12 (Camera #3 first-use)**: `scene_post_loaded(anchor: Vector2, limits: Rect2)` 2-arg signal active, Camera #3 first consumer, signature locked at architecture.yaml `interfaces.scene_lifecycle`. Stage #12 / HUD #13 (Tier 2) reuses the same signal (signature unchanged) | Q2 closure via Camera #3 Approved RR1 PASS 2026-05-12 — was YAGNI deferred while all dependents Not Started; Camera #3 became first dependent → revision applied | C.3.4 + OQ-SM-A1 (resolved) |
| **DEC-SM-10** | Tier 2 revision triggers pre-registered — Rule 3 async load, Rule 11 in-place reset, OQ-SM-A2/A3/A4/A5 | Protects Tier 1 commitment + explicitly marks revision surface in preparation for Tier 2 gate | C.1 Rules 3/11 + OQ section |

### A.2 Cross-doc Citations

| Cited GDD / Doc | Citation Location | Reason |
|---|---|---|
| `design/gdd/game-concept.md` | A · B · C.1 R3/R9/R13 · D.1/D.4 · G.1 | Pillar 1/2/4/5 lock |
| `design/gdd/state-machine.md` | C.1 R1/R5/R10 · C.3.2 · F.1 row #5 · F.3 · G.1 group name | EchoLifecycleSM O6 cascade owner; group discovery contract; SM framework non-use justified |
| `design/gdd/time-rewind.md` | C.1 R6/R7 · C.3.2 · C.3.5 · F.1 row #9 · F.3 · F.4.1 | TRC `_buffer_invalidate()` sole owner; `_tokens` preserved; OQ-4 closure |
| `design/gdd/damage.md` | C.1 R12 · C.3.3 · C.3.5 · F.1 row #8 · F.3 · F.4.1 | `boss_killed` F.4 9-signal contract single-source authority + AC-13 BLOCKING |
| `design/gdd/player-movement.md` | C.1 R5 · F.1 row #6 · F.3 · F.4.1 | PM 8-var ephemeral state F.4.2 row #2 obligation; OQ-PM-1 closure |
| `design/gdd/input.md` | C.1 R13 · E.6/E.7 · F.3 | input.md C.5 router owner for cold-boot game-start trigger |
| `docs/architecture/adr-0001-time-rewind-scope.md` | C.1 R11 · F.1 row #9 | Player-only rewind scope; SM owns non-player reset |
| `docs/architecture/adr-0002-time-rewind-storage-format.md` | C.1 R6/R7 · D.2 · G.1 | PlayerSnapshot 9-field ring buffer; SM does not touch ring buffer |
| `docs/architecture/adr-0003-determinism-strategy.md` | C.1 R2/R10 · C.3.3 · D.5 · F.1 row #5 | process_physics_priority ladder; same-tick signal processing order |
| `docs/registry/architecture.yaml` | C.3.5 · F.4.1 | F.4.1 new entries: 4 items (scene_lifecycle / scene_phase / 2 api_decisions) |
| `design/registry/entities.yaml` | C.3.5 · F.4.1 | F.4.1 new constants: 2 items (restart_window_max_frames=60 / cold_boot_max_seconds=300) |

### A.3 Reference Games / External Tech Refs

This GDD is a Foundation/Infrastructure system with no direct reference game citations. Pillar 1/4 citations indirectly reflect reference game influence (Hotline Miami < 1s restart, Katana Zero instant restart) via game-concept.md.

| Tech Ref | Location | Reason |
|---|---|---|
| Godot 4.6 SceneTree API | C.1 R2/R3 · C.2.1 · D.1 · E.3 | `change_scene_to_packed` / `process_frame` one-shot connect / autoload subsystem |
| Godot 4.6 Time API | D.4 | `Time.get_ticks_msec()` cold boot measurement |
| GUT (Godot Unit Test) | H section | Integration test framework (project standard per coding-standards.md) |
| `tools/ci/pm_static_check.sh` precedent | H.2 + D.2 | Static grep CI gate pattern — obligation to author new `tools/ci/sm_static_check.sh` |

### A.4 Specialist Consult Log

| Specialist | Session 19 Role | Output |
|---|---|---|
| **creative-director** | Section B framing | 3 candidate framings (Pointer / Invariant frame / Claim < 1s ownership); recommended Candidate B (Invariant frame parallel to state-machine.md). User accepted. |
| **systems-designer** (1) | Section C.1 Core Rules draft | 14 numbered rules with rationale; resolved 3 carried OQs (OQ-4 / OQ-PM-1 / OQ-SM-2); flagged `boss_killed` vs `boss_defeated` cross-doc drift |
| **systems-designer** (2) | Section C.2 adversarial review | Surfaced Q1 tick-arithmetic co-tick fix (PRE-EMIT not additive) + Q2 POST-LOAD observability gap (deferred to C.3.4) |
| **qa-lead** | Section H Acceptance Criteria draft | **Original Session 19 draft**: 25 ACs (12 Logic + 11 Integration + 2 `[MANUAL]`); 23 BLOCKING / 2 ADVISORY. **Post-RR cumulative HEAD state (canonical — see H.0 preamble)**: 29 ACs / 27 BLOCKING / 2 ADVISORY (16 Logic + 11 Integration BLOCKING + 2 ADVISORY) — additions: AC-H26 PANIC terminality (RR2), AC-H14 PANIC entry post-condition (RR3 enhancement, not new AC), AC-H27 swap-call cardinality (RR4). B-Inv-1/2/3 1:1 covered; all 14 Rules + 6 Formulas covered; H.U1–H.U3 untestable surfaced. **Note**: qa-lead wrote H directly to file violating Draft→Approval→Write protocol; user reviewed post-hoc and accepted content. **Guardrail for future authoring sessions**: agents must surface a user-visible draft and obtain explicit approval before any Write/Edit, regardless of section size or perceived quality. H's content quality is **not** a precedent for skipping protocol — see `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`. |

### A.5 Tier 2 Revision Triggers (pre-registered)

Items pre-registered for revision when this GDD passes the Tier 2 gate, per the trigger conditions in this table:

| Trigger | This GDD revision area | Owner GDD (closure) |
|---|---|---|
| Multi-stage (≥ 2 stages) introduction | C.1 Rule 3 — allow async load + explicit memory release | this GDD (Tier 2 revision) |
| In-place checkpoint pattern (reset without scene swap) | C.1 Rule 11 — specify per-group reset cascade | Stage / Encounter #12 GDD |
| ~~`scene_post_loaded` first use case arises~~ ✅ **Fired 2026-05-12 (DEC-SM-9 / OQ-SM-A1 / Camera #3 RR1 PASS)**: signal active per C.3.4 | ~~C.2.1 POST-LOAD signal exposure addition (Q2 closure)~~ → Applied; AC-H28 added (RR8) | ~~Camera #3 OR Stage #12 GDD~~ |
| `boss_killed` → next stage PackedScene routing | C.3.3 victory_screen → next_stage dynamic lookup | Stage #12 GDD |
| Memory 1.5 GB ceiling reaches 75% | E.3 — `OS.get_static_memory_usage()` monitoring + push_warning | Collage Rendering #15 GDD |
| Steam Deck Gen 1 measured 60-tick consistent violation | D.1 worked example update with measured values + roll forward async load early if needed | this GDD (Tier 1 Week 1 playtest results) |

### A.6 Session 19 Status Header Update Queue (Phase 5d applied)

After this GDD reaches Designed status, update systems-index.md Row #2 status as follows:

- Status: **In Design (Session 19, A+B+C complete)** → **Designed (Session 19 — All 11 sections + Appendix complete)**
- Design Doc: keep `[scene-manager.md](scene-manager.md)` link
- Depends On: `—` (Foundation; no upstream)
- Last Updated narrative: "Session 19 GDD authoring complete — **original 25 ACs** (23 BLOCKING / 2 ADVISORY); **post-RR cumulative HEAD state: 29 ACs / 27 BLOCKING / 2 ADVISORY** (RR2 added AC-H26 PANIC terminality; RR3 enhanced AC-H14 with PANIC entry post-condition; RR4 added AC-H27 swap-call cardinality). 3 carried OQs resolved (OQ-4 / OQ-PM-1 / OQ-SM-2), 5 new SM-specific OQs registered (Tier 2 deferred), cross-doc drift `boss_defeated → boss_killed` follow-up housekeeping batch queued."
- Progress Tracker: Designed 5 → 5 (no change yet — pending fresh-session `/design-review`); Designed (pending re-review) 0 → 1 if user wants intermediate state, otherwise hold.
