# Time Rewind System

> **Status**: In Design
> **Author**: User + Claude (game-designer + creative-director + systems-designer + qa-lead + art-director)
> **Last Updated**: 2026-05-09
> **Implements Pillar**: Pillar 1 (primary — "Learning tool, not punishment") + Pillar 2 (secondary — preserve determinism)
> **Implements ADRs**: ADR-0001 (R-T1 scope), ADR-0002 (R-T2 storage), ADR-0003 (R-T3 determinism)

## Overview

The Time Rewind System captures ECHO's playable state into a 1.5-second sliding-window ring buffer every physics tick (60 Hz), allowing the player to spend a finite token resource to instantly restore the state just before death. It is the mechanism that transforms a one-hit kill from a *session reset* into a *learning beat*.

The player interacts with the system through 3 direct touchpoints:

1. The token counter in the HUD upper-left (remaining count + charge-lock indicator).
2. Explicit token consumption triggered by a single dedicated input (Gamepad Left Trigger / KB+M default key).
3. A fullscreen color-inversion + collage-glitch visual signature that plays for approximately 0.5 seconds immediately on activation (`design/art/art-bible.md` Principle C).

Beneath the surface, the system handles snapshot capture, token economy, and restoration sequencing, but does not expose these to menu or settings UI.

**Player Fantasy** — "VEIL calculates everything. Except one thing — I can rewind time." The immediate frustration of a one-hit kill is converted into the immediate recovery of a 1-second retrieval at the cost of a token. Death is not the end — it is *learning* (Pillar 1, primary).

Without this system, Echo's one-hit kill core becomes mere punishment and Pillar 1 collapses. The "tension → catharsis" cycle validated by Hotline Miami / Katana Zero becomes unreachable. **This system is Echo's differentiating mechanic and the game-concept hook itself** (see `design/gdd/game-concept.md` Unique Hook).

**Implementation locked by ADRs (reference only — this GDD is the behavioral spec; below are the authoritative implementation sources):**

- **ADR-0001 (R-T1)** — Player-only scope. Only ECHO is rewound; enemies, bullets, and environment continue normal simulation. 8-field PM-exposed `PlayerSnapshot` schema (Amendment 2 locked 2026-05-11: 7 PM-owned + 1 Weapon-owned `ammo_count`; full Resource 9 fields = 8 PM-exposed + 1 TRC-internal `captured_at_physics_frame` per Amendment 1). 4 signal contracts (`rewind_started`, `rewind_completed`, `token_consumed`, `token_replenished`).
- **ADR-0002 (R-T2)** — Ring buffer of 90 pre-allocated `PlayerSnapshot` Resources, write-into-place approach (0 per-tick allocations).
- **ADR-0003 (R-T3)** — `CharacterBody2D` + direct field assign restoration. Determinism source = `Engine.get_physics_frames()`. `process_physics_priority` ladder (player=0, enemies=10, projectiles=20).

## Player Fantasy

> **Anchor handle**: *Defiant Loop* (creative-director consultation 2026-05-09; selected from 3 candidates).

### The Moment

A bullet finds me — and I refuse it. The moment I press the time-rewind button, the screen tears into cyan and magenta and collage textures dissolve in a glitch. VEIL calculated my death to the millisecond. I *erase* that calculation. For 1.0 second I become a variable the algorithm did not predict, and when I return I am not merely alive — the hostility becomes *justified*. The boss did not kill me. The boss witnessed my *revocation*.

### Lineage

Katana Zero's noir-thriller defiance is the direct ancestor, but the time axis is flipped. Katana Zero *plans* combat — Will sees the simulation in advance. Echo *revokes* loss — REWIND Core rewinds the outcome after the fact. This difference determines the tone of the fantasy: Katana is the cold assassin, Echo is the *angry glitch* — more human, less composed, and more hostile to the system.

If Hotline Miami's instant restart is *floor-level* information refresh, Echo's REWIND is *moment-level* information refresh. If Cuphead's pattern learning happens *between* attempts, Echo's learning is compressed *inside* the attempt.

### Tone Register

Echo's unique emotion: synthwave noir + collage-glitch rage. Hotter than Hotline Miami's clinical violence, darker than Cuphead's vaudeville theater, more *raw* than Katana Zero's restrained noir. The visual signature (`design/art/art-bible.md` Principle C: color-inversion + glitch) is the direct expression of this tone — not treatment, but protest.

### Story Anchor

This fantasy aligns one-to-one with the core motif of Echo Story Spine — VEIL models human behavior, but *irrationality* is outside the model. ECHO's REWIND Core is that blind spot. Every moment the player uses the mechanic, they prove the fiction's proposition in action: *"When AI calculates the future, ECHO rewinds the past."* Pillar 1 ("learning tool, not punishment") and the story motif breathe in the same breath.

### Anti-Fantasy (emotions this system must never create)

This system must *never* cause the following feelings. Each item is used as a guard criterion in subsequent sections (especially Tuning Knobs and Acceptance Criteria).

- **Invincibility power fantasy**. Using a token should read as "spent an expensive resource," not "was saved." The moment tokens feel automatic, plentiful, or free, defiance turns into entitlement.
- **Safety net**. The *reality* of death must be alive every time. When tokens run out, the next one-hit is a real end — this permanence creates the weight of defiance (why Hard mode with 0 tokens is the core emotional anchor).
- **Time stop**. REWIND is not a *timeout from the present* but a *revocation of the past*. Enemies, bullets, and environment continue to simulate during activation (the emotional justification for ADR-0001 Player-only scope).
- **Tutorial popup**. If the activation effect feels like *instruction* or *kindness*, the Challenge aesthetic (MDA Primary) collapses. The signature is 0.5 seconds — rage time, not analysis time.

## Detailed Design

### Core Rules

**Capture & Resource Rules**

1. Every `_physics_process` tick, `TimeRewindController` updates 1 `PlayerSnapshot` into the ring buffer via *write-into-place* (0 allocations) (ADR-0002).
2. Capture pauses on `rewind_started` emit and resumes on `rewind_protection_ended` emit. `_write_head` is frozen during the pause.
3. At system start, `_tokens = RewindPolicy.starting_tokens` (default 3). Easy mode uses infinite tokens (unclamped integer simulation), Hard mode uses 0. `RewindPolicy` is injected once at `_ready()` and runtime mutation is prohibited — policy changes only apply on scene reload.

**Trigger & Window Rules**

4. On a lethal hit to ECHO, the State Machine (System #5) immediately triggers an `ALIVE → DYING` transition and opens a `RewindPolicy.dying_window_frames` frame (default 12 / 0.2s) grace window. The Damage system delays the death *decision* by the same length. **Upon receiving the `lethal_hit_detected` signal, TRC immediately caches `_lethal_hit_head: int = _write_head`** (TRC subscribes to `lethal_hit_detected`, SM subscribes to `player_hit_lethal` — both signals are emitted by Damage in the same frame N. F.1 #8 row single source) — this frozen value is the basis for future `restore_idx` calculation, ensuring that even though capture continues during the DYING grace, the restoration point is fixed *just before death* (systems-designer verification 2026-05-09 — accompanied by ADR-0002 amendment).
5. Input buffer: `"rewind_consume"` inputs from `RewindPolicy.input_buffer_pre_hit_frames` frames (default 4 / 0.067s) before lethal hit registration through DYING window end are valid. Inputs within this window are never dropped. The 4-frame default is a conservative choice relative to Celeste's 6-frame coyote-time, absorbing gamepad/USB poll jitter (8–4ms intervals).
    - **1-frame minimum DYING gap**: ALIVE→REWINDING always passes through DYING (minimum 1 physics tick). At least one `_physics_process` cycle executes in DYING before `try_consume_rewind()` evaluates the input predicate. This gap is architectural — DYING cannot be skipped and is not tunable.
    - **Implementation contract (W3 fix 2026-05-10)**: This window is implemented as a *forward-looking predicate*, not a *backwards-looking history*. The SM polls `Input.is_action_just_pressed("rewind_consume")` every tick in `physics_update` for both AliveState/DyingState → on detection, updates `_rewind_input_pressed_at_frame: int` member. Validity judgment is the sole source in `state-machine.md` D.2 predicate `F_input >= F_lethal - B ∧ F_input <= F_lethal + D - 1`. Input time is *always* recorded, and when `lethal_hit_detected` arrives, the SM evaluates the predicate to determine *retroactively* if it was a valid input. This approach guarantees the "4 frames before lethal hit" window without an input history log.
6. Input within window + `_tokens > 0` ⇒ State Machine calls `TimeRewindController.try_consume_rewind()`. On `true` return, `DYING → REWINDING` transition.
7. Input within window + `_tokens == 0` ⇒ Input is a no-op. Denial audio cue plays once (separate SFX identifier — distinct from token consumption cue). DYING countdown continues.
    - **Extended denial — `buffer_invalidated` case**: Input within window + `_tokens > 0` + `_buffer_primed == false` also triggers denial audio cue (same identifier — both mean "cannot rewind now"). Reason tag: `buffer_invalidated` — ring buffer was cleared by `scene_will_change` emission in the same tick as the lethal hit (scene-manager.md C.1 Rule 15). Silent return is **forbidden** in this case; silence is reserved exclusively for the Rule 13 re-entry guard (REWINDING in-progress).
8. Window timeout ⇒ `DYING → DEAD`. Scene Manager performs checkpoint/restart flow (outside this GDD's scope).

**Restoration Rules**

9. `try_consume_rewind()` executes the following sequence within a single physics tick (ADR-0002 Amendment 1 + Amendment 2 applied): `_tokens -= 1` → `token_consumed.emit(_tokens)` → **`restore_idx = (_lethal_hit_head - RESTORE_OFFSET_FRAMES + REWIND_WINDOW_FRAMES) mod REWIND_WINDOW_FRAMES`** calculation (using frozen value from Rule 4 — without this amendment, capture advancing `_write_head` during DYING grace +k frames would cause `restore_idx` to silently point to a time *after* death) → `rewind_started.emit(_tokens)` → `_player.restore_from_snapshot(snap)` → **`_weapon_slot.restore_from_snapshot(snap)`** (Amendment 2 ratification 2026-05-11 via Player Shooting #7 §C.2.6 — TRC orchestration of Weapon-owned `ammo_count` restoration; OQ-PM-NEW (a) locked, signal-subscription path (b) is dead-on-arrival under W2-locked signature) → `rewind_completed.emit(_player, snap.captured_at_physics_frame)`. Here `rewind_completed` means *restoration call complete*, not i-frame protection end.
    - **Canonical signal signature (W2 fix 2026-05-10)**: `signal rewind_completed(player: Node2D, restored_to_frame: int)` — single source is `docs/registry/architecture.yaml` `interfaces.rewind_lifecycle.signal_signature`. The second argument passed on emit is `snap.captured_at_physics_frame` (frame at capture == restored frame). Downstream subscribers (`HUD`, `VFX`, `state-machine.md` F.1 row #9) use `_on_rewind_completed(player: Node2D, restored_to_frame: int)` signature.
10. Immediately upon entering REWINDING, a 30-frame (0.5s) i-frame protection activates. ECHO is immune to all damage, and full input (movement, jump, shoot, weapon swap) is available from frame 1.
11. On 30-frame countdown completion, `REWINDING → ALIVE` transition + new signal `rewind_protection_ended(player: Node2D)` emitted. This signal is the single source of i-frame end — this GDD adds this signal to the ADR-0001 `rewind_lifecycle` contract (Phase 5b registry update target). **Hazard grace obligation (Round 3 — damage.md DEC-6 cross-link)**: `RewindingState.exit()` has a mandatory obligation to call `damage.start_hazard_grace()` once immediately *after* restoring `echo_hurtbox.set_deferred("monitorable", true)` (Round 2 correction — direct `monitorable = true` assignment is a race hazard in physics callback context; deferred-call pattern is mandatory). This opens a 12-frame *hazard-only* grace window (enemy bullets are blocked normally; only `&"hazard_*"` prefix causes are blocked) protecting Pillar 1 "learning tool, not punishment". Single source definition is `damage.md` DEC-6 + C.6.4 + E.13.
12. Enemies, bullets, and environment continue to simulate throughout DYING / REWINDING / i-frame periods (ADR-0001 Player-only scope, anti-fantasy "not time stop").

**Re-entry & Concurrency Rules**

13. Re-calling `try_consume_rewind()` while in REWINDING state immediately returns `false`. Uses `_is_rewinding: bool` guard. Re-entry is silently handled (no denial cue — silence used as *in-progress* signal).
13-bis. **Buffer-primed guard**: While `Engine.get_physics_frames() < REWIND_WINDOW_FRAMES` (first 1.5 seconds after session start), `try_consume_rewind()` immediately returns `false`. Before the ring buffer is filled, `restore_idx` would point to a `PlayerSnapshot.new()` default-value (origin, zero velocity) slot, teleporting ECHO to an invalid position. Set `_buffer_primed: bool` flag to `true` when frame counter first reaches `W`. If frame=W arrival and lethal hit occur simultaneously in the same tick, force `_buffer_primed` update *before* signal processing (ordering rule, E-20). Additionally, `_buffer_primed` is reset to `false` mid-session by `scene_will_change` emission (TRC `_buffer_invalidate()`). In this mid-session case, DYING may already be active — Rule 7 (`buffer_invalidated` denial) applies and the denial cue plays. The startup-only silent-return is inapplicable mid-session because DYING cannot be active during the first `W` frames.
17. **Lethal-hit latch (secondary guard)**: SM owns a `_lethal_hit_latched: bool` flag. Set to `true` on `ALIVE → DYING` transition, cleared to `false` on `REWINDING → ALIVE` or `DEAD` transition. While latch is `true`, SM ignores additional `player_hit_lethal` signals.
    - **Primary guard (single source: `damage.md` C.3.2 step 0 — Round 5 cross-doc S1 fix 2026-05-10)**: Blocking `_lethal_hit_head` re-cache on TRC's side is handled by the *Damage-side first-hit lock*. Since `lethal_hit_detected` (TRC subscribes) and `player_hit_lethal` (SM subscribes) are separate signals, SM `_lethal_hit_latched` alone cannot prevent TRC re-caching. The `if _pending_cause != &"": return` guard at Damage `_on_hurtbox_hit` entry blocks both signal emits, uniquely enforcing (a) preservation of `_pending_cause` first hit (`damage.md` E.1) and (b) blocking `_lethal_hit_head` re-cache (this Rule). The visual result of continuous damage (acid pool, laser sweep) and same-tick multiple lethal hits being silenced after the first hit is verified by `damage.md` E.1 + AC-36.
    - SM-side `_lethal_hit_latched` retains two roles: (1) *secondary defence* against future corner cases where Damage step 0 is bypassed (e.g., host wiring changes), and (2) internal branch consistency check for `current_state.handle_player_hit_lethal()` (E-12, E-13).
18. **Pause swallow**: SM intercepts and invalidates pause inputs while in `DYING` or `REWINDING` state. Converting the 12-frame grace into free decision time violates the anti-fantasy "rage time, not analysis time" (E-19). Pause system GDD must explicitly note this exception.
14. While in DEAD state, inputs are unconditionally ignored. No revival path.
15. If `boss_killed` signal arrives while REWINDING, `_tokens` immediately increases + `token_replenished` emitted. HUD delays visual update until `rewind_protection_ended` (visual change block during signature).
16. When `boss_killed` and `lethal_hit_detected` arrive in the same physics tick — **actual invariant** (Round 1 design-review correction): process_physics_priority lower=earlier (Godot 4.x). Ladder: player=0, TRC=1, Damage=2 (damage.md Round 3 lock), enemies/Boss=10, projectiles=20. Same-tick execution order is therefore Damage(2) → Boss(10) → projectile(20). Damage first emits `lethal_hit_detected` → SM with buffered rewind input calls `try_consume_rewind()` → `_tokens -= 1` (T → T-1, intermediate T=0 dip possible) → Boss emits `boss_killed` → `grant_token()` → `_tokens = min(T+1, max_tokens)` (T-1 → T, net zero). Intermediate T=0 dip is unobserved within the same tick (AC-B5 verifies net-zero, not intermediate state). **Invariant break condition**: Boss acquires a slot with priority < 2 in its own `_physics_process` node. Boss Pattern GDD is obligated to enforce priority ≥ 10 upper bound.

### States and Transitions

ECHO Time-Rewind State Machine (cooperative area with System #5).

| State | Entry Condition | Exit Condition | Notes |
|---|---|---|---|
| **ALIVE** | Session start / `REWINDING` expiry / Scene Manager revival | Lethal hit → DYING | Normal gameplay. Ring buffer capture active every tick. |
| **DYING** | Damage emits `player_hit_lethal` | Input + tokens ≥ 1 within 12 frames → REWINDING <br> 12-frame expiry or tokens 0 → DEAD | Capture continues (so last 0.2s remains in buffer). Input buffer active. |
| **REWINDING** | DYING + `try_consume_rewind() == true` | 30-frame expiry → ALIVE | Capture PAUSED (`_write_head` frozen). i-frame active. Full input active. Visual signature 0.5s proceeds simultaneously. |
| **DEAD** | DYING grace window expiry | Scene Manager checkpoint/restart → ALIVE | Terminal state. Time Rewind inactive. |

**Transitions forced by Time Rewind**: `DYING → REWINDING`, `REWINDING → ALIVE`.

**Transitions blocked by Time Rewind**: All damage inputs during REWINDING (i-frame), any revival from DEAD.

**Inputs permitted during REWINDING**: Movement, jump, shoot, weapon swap (from frame 1). Visual signature is *rage time*, not a lockout (Anti-fantasy).

**Hard mode behavior**: Tokens are 0 but the DYING 12-frame window still exists. On input, denial cue plays → DEAD. This is intentional design that confirms *the player tried*, the exact opposite of anti-fantasy "safety net".

### Interactions with Other Systems

All dependent systems have GDDs not yet written, so interfaces are marked *provisional*. Review this section at the time that system's GDD is written to confirm consistency.

#### Upstream

| # | System | Direction | Interface | Hard/Soft |
|---|---|---|---|---|
| [#5](state-machine.md) | State Machine Framework | SM is the sole arbiter at the moment of death. Subscribes to Damage `player_hit_lethal`, enters DYING, calls `try_consume_rewind()` on input. TRC does not read SM state directly. SM-side obligations are formalized as 6 obligations in `state-machine.md` C.2.2 (latch O1 / pause swallow O2 / input buffer O3 / 4-signal subscription O4 / boss_killed delay O5 / scene clear O6). | TRC exposes: `try_consume_rewind() -> bool`. SM subscribes: `rewind_started`, `rewind_completed`, `rewind_protection_ended`. | **Hard** |
| #6 | [Player Movement](player-movement.md) | TRC *reads* PlayerMovement properties every tick; calls `restore_from_snapshot()` as the *single write path*. **Wiring (Round 2 addition)**: TRC connects to PlayerMovement via explicit `@export var player: PlayerMovement` node reference — `get_parent()` / implicit lookup prohibited. Missing reference detectable in editor + dependency is declared in declarative form. **PM #6 Designed locked (2026-05-10)**: PlayerMovement is `class_name PlayerMovement extends CharacterBody2D` (= ECHO root node itself, player-movement.md A.Overview Decision A). `_is_restoring: bool` guard (player-movement.md C.4.4 single source) blocks anim method-track handlers from firing during restoration. `facing_direction` is int 0..7 enum (architecture.yaml api_decisions.facing_direction_encoding). **DEC-PM-3 v2 (2026-05-11, B5 Pillar 1 resolution)**: Schema expanded from 7→8 PM-exposed fields (ammo_count added) — ADR-0002 Amendment 2 obligatory. | Capture (read): `global_position: Vector2`, `velocity: Vector2`, `facing_direction: int`, `current_animation_name: StringName`, `current_animation_time: float`, `current_weapon_id: int`, `is_grounded: bool`, **`ammo_count: int` (Weapon #7 single-writer — Amendment 2 2026-05-11)**. Restoration (write): `func restore_from_snapshot(snap: PlayerSnapshot) -> void` (verbatim match with player-movement.md C.4.2) — `snap.ammo_count` is *ignored* by PM; Weapon-side restoration requires resolution of OQ-PM-NEW (TRC orchestration vs `rewind_completed` subscription). Forbidden pattern `direct_player_state_write_during_rewind` applies only to PM's 7 fields (ammo_count is enforced at Weapon site). | **Hard** |
| #8 | [Damage / Hit Detection](damage.md) | Damage emits; both TRC and SM subscribe. TRC subscribes to both `lethal_hit_detected(cause)` (frame N, `_lethal_hit_head` cache trigger) and `death_committed(cause)` (frame N+12, buffer cleanup). SM subscribes only to `player_hit_lethal(cause)`. SM invokes `damage.commit_death()` when grace expires (one-way). | Damage GDD F.3 signal catalog (single source): `signal lethal_hit_detected(cause: StringName)` + `signal player_hit_lethal(cause: StringName)` + `signal death_committed(cause: StringName)`. 1-arg locked DEC-1. 2-stage separation allows SM to insert 12-frame grace (Rule 4 + `damage.md` C.3). Cause taxonomy is solely owned by Damage GDD (D.3). | **Hard** (indirect) |
| #1 | [Input System](input.md) | InputMap action mapping. SM polls the action upon entering DYING. **Input #1 Designed 2026-05-11**: cross-doc obligations verbatim locked (input.md C.1.1 row 8 + C.3.1 KB+M Shift + C.3.2 Gamepad LT threshold 0.5 + C.2 single-button-no-chord Tier 1 invariant + C.2 Tier 3 `default_only` interpretation — OQ-15 closure). | InputMap action `"rewind_consume"`. Gamepad left trigger (`JOY_AXIS_TRIGGER_LEFT`, threshold 0.5). KB+M default `Shift`. Single button, no chord (technical-preferences constraint). | **Hard** |
| #2 | [Scene / Stage Manager](scene-manager.md) | Scene Manager emits just before `change_scene_to_packed` call (same physics tick, sync emit); TRC subscribes with its own `_buffer_invalidate()` handler to invalidate ring buffer. | `signal scene_will_change()` (0 args; Scene Manager autoload sole producer per scene-manager.md C.1 Rule 4) → TRC self `_buffer_invalidate()` (TRC ring buffer single owner — SM does not touch `_write_head`/`_buffer_primed` per scene-manager.md C.1 Rule 6): `_buffer_primed = false`, `_write_head = 0`. Token count is preserved (scene-manager.md C.1 Rule 7 + D.2 invariant). The next DYING is automatically blocked to `DEAD` by the buffer-primed guard (Rule 13-bis), preventing invalid coordinate restoration at scene boundaries (E-16). **OQ-4 closure 2026-05-11 (Scene Manager #2 Approved RR7)**: emit timing = same physics tick sync emit immediately before `change_scene_to_packed` call; token preservation invariant locked. | **Hard** |

#### Downstream

| # | System | Direction | Interface | Hard/Soft |
|---|---|---|---|---|
| #11 | Boss Pattern *(provisional)* | Emits on boss death; TRC subscribes and self-calls. Direct call prohibited. | `signal boss_killed(boss_id: StringName)` → TRC subscribes and calls `self.grant_token()` → emits `token_replenished(new_total: int)`. | **Hard** (token economy) |
| #13 | HUD *(provisional)* | HUD subscribes to TRC signals (observer, no polling). | Subscribes to `token_consumed(remaining_tokens: int)`, `token_replenished(new_total: int)`. Initial display via `TimeRewindController.get_remaining_tokens() -> int`. HUD updates only after `_displayed_tokens == remaining_tokens` diff check (per-fire allocation 0). | **Soft** |
| #14 | VFX / Particle *(provisional)* | VFX subscribes to `rewind_started` and sets `GPUParticles2D.emitting = false`. Subscribes to `rewind_protection_ended` to restart. | Subscribes to `rewind_started(remaining_tokens: int)` + `rewind_protection_ended(player: Node2D)`. (ADR-0001: GPUParticles2D reverse not supported in 4.6 → emit-pause + restart workaround.) | **Soft** |
| #16 | Time Rewind Visual Shader *(provisional)* | Shader subscribes only to `rewind_started` + ends via internal 0.5s `Timer` (one-shot). Wiring termination to `rewind_completed` is prohibited (same-tick emit). | Subscribes to `rewind_started(remaining_tokens: int)`. Internal Timer one-shot 0.5s. | **Soft** |
| #20 | Difficulty Toggle *(provisional)* | Difficulty provides `RewindPolicy` Resource; TRC receives injection at `_ready()`. Runtime mutation prohibited. | `class_name RewindPolicy extends Resource`: `@export var starting_tokens: int`, `@export var max_tokens: int`, `@export var grant_on_boss_kill: bool`, `@export var infinite: bool`, `@export var dying_window_frames: int = 12`(range 8–18), `@export var input_buffer_pre_hit_frames: int = 4`(range 2–6). TRC: `@export var rewind_policy: RewindPolicy`. | **Soft** (default values used when null) |
| #3 | [Camera System](camera.md) | Hard | `rewind_started()` + `rewind_completed(player: PlayerMovement, restored_to_frame: int)` signals | Camera freezes on `rewind_started` (`is_rewind_frozen=true` → R-C1-1 skip — Pillar 1 "the gaze does not rewind"); `rewind_completed` unfreezes + force-clears shake + re-targets position + calls `reset_smoothing()` (camera.md R-C1-8/9 + F.1 row #5 reciprocal). DT-CAM-1 0 px drift self-evident verification path. Camera #3 Approved 2026-05-12 RR1 PASS. |
| #4 | [Audio System](audio.md) | Hard | `rewind_started(remaining_tokens: int)` + `rewind_completed(player: Node2D, restored_to_frame: int)` signals | AudioManager: on `rewind_started` ducks Music bus −6 dB (2-frame Tween) + plays `sfx_rewind_activate_01.ogg`; on `rewind_completed` restores Music bus to 0 dB (10-frame linear Tween). audio.md Rules 8/9 + F. Upstream #9. Audio #4 Approved 2026-05-12. |

### Accumulated Contract Obligations (responsibilities dropped on other GDDs)

Explicit contract obligations this GDD places on other systems — must be reflected when those system GDDs are written:

| Target System | Obligation | Basis |
|---|---|---|
| #2 Scene Manager | Emit `scene_will_change()` signal + expose TRC subscription | E-16 |
| #5 State Machine | Own `_lethal_hit_latched` latch + pause swallow in DYING/REWINDING | Rule 17, 18 |
| #6 Player Movement | `restore_from_snapshot()`, 8 PM-exposed fields (7 PM-owned + 1 Weapon-owned `ammo_count` per ADR-0002 Amendment 2), `_is_restoring: bool` guard, `_is_restoring` check in anim method-track handlers | C.3, I9 |
| #8 Damage | Emit `player_hit_lethal(cause: StringName)`, separate `lethal_hit_detected`/`death_committed`, same signal for all hazards | E-11 |
| #11 Boss Pattern | Emit `boss_killed(boss_id: StringName)`, explicitly note phase transition rewind-immunity, `process_physics_priority = 10` | C.3, E-18 |
| #13 HUD | `_displayed_tokens` diff check (per-fire allocation 0), delay visual update during REWINDING | I6, Rule 15 |
| #14 VFX | Pause emit on `rewind_started`, restart on `rewind_protection_ended` | C.3 |
| #16 Visual Shader | Subscribe only to `rewind_started`, terminate via internal 0.5s Timer (wiring termination to `rewind_completed` prohibited) | I5 |
| #19 Pickup | Explicitly note one-way world mutation (unaffected by rewind) | E-14 |
| #7 Player Shooting / Weapon | `WeaponSlot.set_active(invalid_id)` silent fallback to id=0; ammo policy decision (resume with live ammo vs ADR amendment) | E-15, E-22, F6 |
| Pause System | Explicitly note pause swallow during DYING/REWINDING | Rule 18 |

### Systems-Index Update Requirements

Add `Input System` (#1) and `Scene Manager` (#2) to the "Depends On" column of `design/gdd/systems-index.md` System #9 row — apply in bulk during Phase 5d Update Systems Index.

### Circular Dependency Check

| Candidate Cycle | Analysis | Verdict |
|---|---|---|
| Boss Pattern (#11) ↔ Time Rewind (#9) | Boss → TRC one-way (signal). TRC has no direct call to Boss. | Not a cycle |
| HUD (#13) ↔ Time Rewind (#9) | HUD → TRC one-way (signal subscription + getter poll). TRC has no direct call to HUD. | Not a cycle |
| State Machine (#5) ↔ Time Rewind (#9) | SM → TRC one-way (`try_consume_rewind()` call). TRC → SM signals only (SM subscribes). | Not a cycle |
| Damage (#8) ↔ Time Rewind (#9) | Damage → SM → TRC. TRC does not directly subscribe to or call Damage. | Not a cycle |
| Visual Shader (#16) ↔ Time Rewind (#9) | Shader → TRC one-way (signal subscription). | Not a cycle |

No true cycles — all dependencies are one-way and decoupled via Observer pattern.

## Formulas

> systems-designer verification 2026-05-09. All time calculations are based on the monotonic integer frame counter (`Engine.get_physics_frames()`) — wall clock dependency prohibited (ADR-0003 `determinism_clock`).

### Shared Variable Glossary

| Symbol | Type | Range | Description |
|---|---|---|---|
| `W` | int | 90 (const) | `REWIND_WINDOW_FRAMES` — ring buffer slot count |
| `O` | int | 9 (const) | `RESTORE_OFFSET_FRAMES` — pre-death restoration offset |
| `R` | int | 30 (const) | `REWIND_SIGNATURE_FRAMES` — single source for i-frame + visual signature (same value as shader timer) |
| `D` | int | 8–18 (knob) | `RewindPolicy.dying_window_frames` — DYING grace |
| `B` | int | 2–6 (knob) | `RewindPolicy.input_buffer_pre_hit_frames` — pre-death input forgiveness |
| `H` | int | 0–89 | `_write_head` — next write slot (cycles 0..W-1) |
| `H_lethal` | int | 0–89 | `_lethal_hit_head` — frozen copy of H at `lethal_hit_detected` (TRC subscribed signal) |
| `P` | int | ≥ 0 | `Engine.get_physics_frames()` — monotonic physics frame counter |
| `T` | int | 0–∞ (Easy), 0 (Hard) | `_tokens` — current token count |
| `Ts` | int | 0–∞ | `RewindPolicy.starting_tokens` |
| `fps` | int | 60 | Physics tick rate (fixed per technical-preferences.md) |

---

### D1. Restore Index (ADR-0002 amendment)

The `restore_idx` formula is defined as:

`restore_idx = (H_lethal − O + W) mod W`

**Variables**: See glossary above. `+ W` prevents negative operands when `H_lethal < O`, so this is safe for all `H_lethal ∈ [0, W-1]`.

**Output Range**: `[0, W-1] = [0, 89]`.

**Example**: `H_lethal = 5`, `O = 9`, `W = 90` → `(5 − 9 + 90) mod 90 = 86`. Slot 86 holds the snapshot from 9 ticks ago (0.15s prior).

**ADR-0002 amendment justification**: The original ADR-0002 algorithm calculated `restore_idx` from the *live* `_write_head`. Since capture continues during the DYING grace window introduced in Section C (Rule 2), `_write_head` at the time of `try_consume_rewind()` call has advanced 0–`D`-1 frames beyond the lethal-hit point. Using live `H` makes `H − O` point to a time *after* death — a silent malfunction. Using the lethal-hit frozen copy `H_lethal` ensures the restoration point is always fixed *just before death*.

---

### D2. Token State Transitions

Token state transition formulas:

```
T_after_consume   = max(0, T − 1)                       -- on try_consume_rewind() (when not infinite)
T_after_boss_kill = min(T + 1, max_tokens)              -- on grant_token() (when grant_on_boss_kill); cap per RewindPolicy.max_tokens
T_session_start   = Ts                                   -- on _ready(); Ts = 3 (Normal), 0 (Hard)
T_easy_guard      = ∞ (no clamp; checks skipped) — RewindPolicy.infinite == true
T_hard_guard      = 0 (constant)                         -- starting_tokens=0, grant_on_boss_kill=false
```

**Round 1 correction (cap expression)**: The original `T_after_boss_kill = T + 1` was missing the cap expression — silent overshoot possible (e.g., duplicate signal emit). AC-B3 verifies the cap so behavior is correct, but the formula spec is the source of truth. ADR-0002 `grant_token()` pseudocode synchronization is obligatory.

**Variables**:

| Symbol | Type | Range | Description |
|---|---|---|---|
| `T` | int | 0–∞ | Token count before transition |
| `T_after_*` | int | 0–∞ | Token count after transition |
| `infinite` | bool | {true, false} | Easy mode flag |
| `grant_on_boss_kill` | bool | {true, false} | Whether +1 on boss kill |

**Output Range**: `T ≥ 0` always. Easy mode: infinite (GDScript int is large enough). Hard mode: T permanently 0.

**Example (Normal)**: Session start → `T = 3`. Boss kill → `T = 4`. Token consume → `T = 3`. Three consumes → `T = 0`. Next hit: `try_consume_rewind()` returns false, `DYING → DEAD`.

---

### D3. Capture Cadence

`_capture_to_ring()` call frequency and ring progression formula:

```
snapshots_per_second   = fps   = 60
H_after_capture        = (H + 1) mod W
capture_active         = NOT _is_rewinding AND _buffer_primed_or_warmup
```

**Variables**: See glossary. `_is_rewinding: bool` is true during REWINDING state (Rule 2 — write_head frozen).

**Output Range**: `H ∈ [0, W-1]`. Every W ticks the oldest snapshot is overwritten (write-into-place). During the first W ticks after session start, capture proceeds (warmup) but `try_consume_rewind()` is blocked (Rule 13-bis).

**Example**: `H = 89` → after capture `H = (89 + 1) mod 90 = 0`. Natural wrap. At 200 ticks, buffer holds frames 110–199.

---

### D4. Window-Depth Derivations

Frame → second conversions (all time calculations are monotonic integers based on `fps = 60`):

```
t_window  = W / fps  = 90 / 60 = 1.5  s    -- rewind lookback depth
t_offset  = O / fps  =  9 / 60 = 0.15 s    -- pre-death restoration margin
t_signat  = R / fps  = 30 / 60 = 0.5  s    -- i-frame + visual signature
t_dying   = D / fps  = 12 / 60 = 0.2  s    -- (default) DYING grace
t_buf     = B / fps  =  4 / 60 ≈ 0.067 s   -- (default) pre-death input buffer
```

**Output Range**: All results positive, unit seconds. Satisfies ADR + Pillar 1/2 + anti-fantasy guards.

**Example (full sequence, Normal)**: Lethal hit at T=0 → DYING T∈[0, 0.2]s → Input at T=0.05s (3 frames in) → `try_consume_rewind()` triggered → REWINDING T∈[0.05, 0.55]s → Restore to position 0.15s before death → i-frame 0.5s → ALIVE at T=0.55s.

---

### D5. Memory Budget

PlayerSnapshot resident byte calculation:

```
fields_bytes        = 8 + 8 + 4 + 8 + 4 + 4 + 4 + 4 + 8 = 52 B  (raw fields — 9 fields per Amendment 2 2026-05-11)
resource_overhead   ≈ 128–192 B  (Godot 4 Resource base)
snapshot_total      ≈ 196 B
ring_buffer_bytes   = W × snapshot_total = 90 × 196 = 17,640 B = 17.64 KB    (decimal — matches ADR-0002 Amendment 2 Performance subsection)
ceiling_bytes       = 1.5 GB = 1.5 × 10^9 B
budget_fraction     = 17,640 / 1.5e9 ≈ 0.0012%
ADR-0002_cap        = 25 KB (Amendment 1)        — 17.64 KB ≪ 25 KB → ✓ (7.36 KB headroom remaining per Amendment 2)
```

**Field breakdown** (Amendment 2 2026-05-11 — 9 fields: 8 PM-exposed + 1 TRC-internal):

| Field | GDScript Type | Bytes | Owner |
|---|---|---|---|
| `global_position` | Vector2 | 8 | PM |
| `velocity` | Vector2 | 8 | PM |
| `facing_direction` | int | 4 | PM |
| `animation_name` | StringName (pointer) | 8 | PM |
| `animation_time` | float | 4 | PM |
| `current_weapon_id` | int | 4 | PM |
| `is_grounded` | bool | 4 | PM |
| `ammo_count` | int | 4 | **Weapon #7** (Amendment 2 2026-05-11) |
| `captured_at_physics_frame` | int | 8 | TRC (Amendment 1) |
| **Raw total** | | **52 B** | |

**Output Range**: 17.64–22.1 KB resident (Amendment 2 +0.36 KB delta vs Amendment 1). Pre-allocated once in `_ready()` (per-tick allocation 0). StringName is interned in Godot's string table so pointer cost is a constant 8B. **ADR-0002 Amendment 1 25 KB cap remaining 7.36 KB** (Amendment 2 recalc — was 7.8 KB pre-Amendment-2; B1 fix `/review-all-gdds` 2026-05-11) — room for ~5 additional Tier 2 fields.

**Example**: 90 slots × 196 B = 17,640 B = 17.64 KB. Adding TRC node overhead (~500 B) → ~18.14 KB. 0.0012% of 1.5 GB ceiling.

**ADR-0001/0002 figure correction**: The "2.88 KB / ≤ 5 KB" figures stated in both ADRs did not account for Resource overhead. Corrected figures are **17–21 KB** (4× difference). Absolute ceiling ratio is still negligible — cosmetic correction only.

---

### D6. CPU Budget Per Tick

Cost of `_capture_to_ring()` and `restore_from_snapshot()`:

```
t_capture_per_tick  ≈ N_fields × t_field_copy = 9 × ~100–500 ns ≈ 0.9–4.5 μs (write-into-place; Round 2 correction + B2 fix `/review-all-gdds` 2026-05-11 N_fields 8→9 per Amendment 2)
t_restore_one_time  ≈ N_fields × t_field_copy + t_anim_seek
                    ≈ 9 × ~300 ns + 200 μs ≈ 203 μs                          (AnimationPlayer.seek dominant; t_field_copy impact negligible)
frame_budget        = 16,600 μs (1 / 60 fps)
rewind_subsys_cap   = 1,000 μs  (≤1 ms envelope, technical-preferences.md)
capture_fraction    ≤ 4.5 μs / 16,600 μs ≈ 0.027% per tick                   (worst case — Amendment 2 N_fields=9 + Round 2 correction)
restore_fraction    = 203 μs / 16,600 μs ≈ 1.2% (one-time, rewind activation frame only)
```

**Variables**:

| Symbol | Type | Range | Description |
|---|---|---|---|
| `N_fields` | int | 9 | PlayerSnapshot field count (Amendment 2 2026-05-11: 8 PM-exposed + 1 TRC-internal). Previous notation 8 was based on Amendment 1 (including capture_at_physics_frame). Capture/restore CPU estimate change is +12% within envelope — conclusion unchanged. |
| `t_field_copy` | ns | ~100–500 | GDScript single-field copy (Round 2 correction — previous ~6 ns notation assumed native; interpreter overhead reflected. Conclusion (safe within envelope) unchanged, methodology corrected only) |
| `t_anim_seek` | μs | ~200 | `AnimationPlayer.seek(time, true)` single-call cost |
| `frame_budget` | μs | 16,600 | One frame at 60fps |
| `rewind_subsys_cap` | μs | 1,000 | This subsystem envelope |

**Output Range**: Capture is 0.0003% per tick — negligible. Restore is 1.2% on activation frame — safe within 1 ms envelope.

**Example**: In normal 60fps play, capture cost = ~300 ns × 9 fields × 60 ticks ≈ 162 μs/sec → 16.6 ms frame budget × 60 frames/sec = 996,000 μs/sec; 162 / 996,000 ≈ 0.016% (Amendment 2 N_fields=9 + Round 2 correction; B2 fix `/review-all-gdds` 2026-05-11). Single rewind activation: 203 μs on activation frame, satisfies ≤ 1 ms envelope.

### 1ms Envelope Sub-Partition (Round 2 addition)

This system's 1 ms envelope (`rewind_subsys_cap`) is partitioned into the following sub-budgets on the activation frame — performance-analyst Round 1 HIGH-1+2 mitigation:

| Sub-budget | Cap (μs) | Responsible System | Verification AC |
|---|---|---|---|
| **Shader** (System #16 fullscreen post-process) | ≤ 500 | art-bible Principle C 18-frame inversion + UV distortion | OQ-11 (Tier 2 final shader) |
| **Restore** (`restore_from_snapshot()` + `AnimationPlayer.seek`) | ≤ 300 | TRC + PlayerMovement cooperation | AC-E2 (≤ 1,000 μs total — sub-cap is stricter) |
| **Headroom** (HUD diff update + signal cascade + noise) | 200 | HUD I6, signal 5-subscriber cascade | Auto-satisfied when AC-E1 passes |
| **Total** | **1,000** | — | technical-preferences.md ≤ 1 ms envelope |

**Steam Deck Zen 2 baseline obligation**: AC-E4 measurements are based on Steam Deck Zen 2 APU; direct transfer from dev machine (typically faster x86 desktop) measurements is prohibited. Perform device-specific calibration in Tier 1 perf-pass (HIGH-2 mitigation).

---

### Tuning Split (RewindPolicy fields vs hardcoded const)

| Constant | Classification | Rationale |
|---|---|---|
| `REWIND_WINDOW_FRAMES = 90` | **hardcoded const** | Locked by ADR-0001/0002. Changing requires ring buffer reallocation. Architecture contract. |
| `RESTORE_OFFSET_FRAMES = 9` | **hardcoded const** | Locked by ADR-0002. Coupled to `restore_idx` formula + lethal-hit interaction (D1). |
| `REWIND_SIGNATURE_FRAMES = 30` | **hardcoded const** | Single source for shader timer and i-frame (art-bible Principle C). Changing one side alone splits visual/mechanic contract. |
| `dying_window_frames` | **RewindPolicy field** | Player feel knob. Hard=8, Easy=16 possible. No impact on determinism contract. |
| `input_buffer_pre_hit_frames` | **RewindPolicy field** | Input forgiveness is an explicit difficulty lever. Range 2–6. Unrelated to ring buffer math. |
| `starting_tokens` | RewindPolicy field | (defined in Section C) |
| `max_tokens` | RewindPolicy field | (defined in Section C) |
| `grant_on_boss_kill` | RewindPolicy field | (defined in Section C) |
| `infinite` | RewindPolicy field | (defined in Section C) |

---

### Hidden Formula Risks (guards required at implementation)

**F1 — restore_idx vs DYING window**: Resolved by D1 amendment. Using the `_lethal_hit_head` frozen value is mandatory.

**F2 — Off-by-one at session start**: During the first W frames, ring buffer holds default slots (origin). `_buffer_primed` guard (Rule 13-bis) blocks `try_consume_rewind()`.

**F3 — `captured_at_physics_frame` gap**: `_write_head` frozen during REWINDING. The first snapshot after resumption has a `captured_at_physics_frame` that is R(30) frames apart from the previous stamp. Intentional invariant — future replay systems must assume R frames added per gap.

**F4 — Memory figure 4× correction (informational)**: Corrects the "2.88 KB / 5 KB" notation in ADR-0001/0002 to the actual 17–21 KB. Negligible relative to 1.5 GB ceiling.

**F5 — `animation_time` float drift**: f32 cumulative error after 100 frames ~10⁻⁵s — below visual threshold. However, `_capture_to_ring()` must read `_player._anim.current_animation_position` directly (manual delta accumulation prohibited).

**F6 — Ammo count restoration policy (RESOLVED 2026-05-11 via player-movement.md DEC-PM-3 v2 / B5)**: `PlayerSnapshot` captures and restores both weapon ID (`current_weapon_id`) and **`ammo_count: int` (8th PM-exposed field, 9th Resource field — Amendment 2)** per-tick. After `restore_from_snapshot(snap)`, ECHO's ammo is restored to the value at `restore_idx` (9 frames prior). Single source for Pillar 1 ("learning tool, not punishment") — rewind does not restore to 0-ammo state. **Write authority**: `ammo_count` is *not* subject to PM single-writer policy — Weapon (#7) is the single-writer. `PM.restore_from_snapshot(snap)` *ignores* `snap.ammo_count`; Weapon-side restoration follows OQ-PM-NEW with either (a) TRC orchestration or (b) Weapon subscribing to `rewind_completed` signal for self-restore. **ADR-0002 Amendment 2** (2026-05-11 Proposed) obligatory. ~~Previous policy (2026-05-10) "resume with live ammo" + (a)/(b) Weapon GDD choice is deprecated.~~

## Edge Cases

> systems-designer verification 2026-05-09. E-01 ~ E-10 are already locked in as Rule/Risk items in Sections C/D and are not re-listed here. E-11 onwards are additions to this section.

### Already locked (see Sections C/D)

- **E-01** Buffer not primed (warmup, P < W) → `try_consume_rewind()` no-op (Rule 13-bis)
- **E-02** Tokens = 0 + DYING input → no-op + denial audio cue (Rule 7)
- **E-03** Re-entry during REWINDING → returns `false` + silence (Rule 13)
- **E-04** Input while DEAD → ignored (Rule 14)
- **E-05** boss_killed during REWINDING → tokens immediately +1, HUD visual update delayed until `rewind_protection_ended` (Rule 15)
- **E-06** boss_killed and lethal_hit_detected same tick → consume-then-grant order (Damage priority=2 < Boss priority=10), net-zero, intermediate T=0 dip unobserved (Rule 16 correction)
- **E-07** AnimationPlayer.seek mid-blend → `update=true` forces immediate evaluation (I4)
- **E-08** lethal-hit head frozen (DYING grace capture continues) → ADR-0002 Amendment 1 + Rule 9
- **E-09** `animation_time` f32 accumulation → read `current_animation_position` directly (F5)
- **E-10** `captured_at_physics_frame` REWINDING gap → intentional invariant (F3)

### Damage Source

- **E-11**: When a hazard (spikes, pits, instant-kill floor) deals lethal damage, ECHO enters DYING just like a projectile lethal hit. `player_hit_lethal(cause: StringName)` is emitted with `cause` being the hazard type. `_lethal_hit_head` cache + 12-frame grace window proceeds. Damage GDD is obligated to emit the same signal for all hazard sources.
- **E-12**: If a continuous damage source (acid pool, laser sweep) emits an additional lethal hit while DYING, the SM's `_lethal_hit_latched` latch (Rule 17) ignores it. `_lethal_hit_head` re-cache is blocked, preserving anchor consistency.
- **E-13**: If multiple lethal hits (piercing bullet + collision) arrive in the same physics tick, only the first signal is processed in tree-order and the rest are blocked by the latch. Both are the same frame so anchor `_lethal_hit_head` is identical.

### Weapon and Pickup

- **E-14**: If ECHO picks up W2 and then dies, and the restoration point is a W1 capture, `current_weapon_id = W1` is restored. The W2 pickup object in the world remains permanently consumed (unaffected by rewind, ADR-0001 Player-only scope). ECHO revives with W1. Pickup/Weapon GDD must explicitly note *one-way world mutation*.
- **E-15**: If an expired weapon_id is restored, `WeaponSlot.set_active(invalid_id)` silently falls back to id=0 (default weapon). Assertions and crashes are prohibited. Weapon GDD obligation.

### Scene Boundaries

- **E-16**: If ECHO dies immediately after passing through a scene-transition trigger, the restoration coordinates may be in the previous scene's coordinate space, teleporting ECHO to an invalid position in the new scene. Scene Manager emits `scene_will_change()` before unloading and TRC calls `_buffer_invalidate()` — `_buffer_primed = false`, `_write_head = 0`, tokens preserved. The next death is automatically handled as `DYING → DEAD` by the buffer-primed guard (Rule 13-bis).
- **E-17**: If ECHO enters an OOB (out-of-bounds) kill volume, it is treated as a hazard lethal hit (E-11 applies). However, if the position 0.15s ago is also OOB, ECHO will die again after i-frame ends at restoration — this is intentional behavior. Level Design guidelines must place OOB volumes such that the position 0.15s prior is rarely OOB (level design constraint, not TRC's responsibility).
    - **Cross-doc timing correction (W5 fix 2026-05-10 — `damage.md` DEC-6 reciprocal)**: `hazard_oob` cause has the hazard prefix (`damage.md` C.5.2), so DEC-6's 12-frame hazard-only grace is **additionally applied** after `RewindingState.exit()`. The actual re-death frame is `lethal_hit_detected` frame N basis: N+30 (i-frame end) + 12 (hazard grace) = **N+42 frames** (= 0.7s @60fps). The simple "dies again at i-frame end" notation means N+42, not N+30. Single source: `damage.md` DEC-6 + C.6.4 + E.13.

### Boss Coupling

- **E-18**: If a boss phase transition (HP threshold crossed) occurs at frame F and ECHO dies at F+3, the restoration point is F-9 (before the phase transition), but the boss's `_phase` remains at the new phase. ADR-0001 states explicitly: enemies are not subject to rewind. The result is that ECHO learns the new phase quickly from a safer position — Pillar 2 intent. Boss Pattern GDD must explicitly note rewind-immunity of phase transitions.

### Input Pathological

- **E-19**: Pause input while in DYING or REWINDING state is swallowed by the SM (Rule 18). Converting the 12-frame grace into free decision time violates the anti-fantasy "rage time." Pause system GDD must explicitly note this exception.

### State Machine Corner

- **E-20**: If ECHO dies at exactly frame `W` (the tick where buffer is first primed), the ordering rule guaranteeing `_buffer_primed` update executes *before* signal processing in the same tick is enforced. Therefore `try_consume_rewind()` succeeds (Rule 13-bis reinforcement).

### Animation Pathological

- **E-21**: If ECHO dies mid-shooting-animation and `seek()` during restoration re-fires a method-track keyframe (e.g., spawn-projectile event), stale projectiles are created. PlayerMovement sets `_is_restoring: bool` flag to `true` immediately before the `seek()` call and restores to `false` in the next `_physics_process`. All anim method-track handlers must have a `if _is_restoring: return` guard obligation (noted in PlayerMovement GDD, I9 mitigation).
- **E-22** (RESOLVED 2026-05-11 via F6 (b) variant — DEC-PM-3 v2): ECHO dies immediately after ammo reaches 0 → on restoration, ammo recovers to the value at `restore_idx` (= 9 frames before rewind trigger). `PlayerSnapshot` captures `ammo_count: int` per-tick (8th PM-exposed field, ADR-0002 Amendment 2). Pillar 1 contradiction resolved. ~~Weapon GDD (a)/(b) choice obligation is deprecated~~ — policy is locked. Weapon GDD #7 only has the remaining obligation of implementing Amendment 2 (ammo_count write-into-snapshot mechanism + Weapon-side restoration hook on `rewind_completed`).

### Level Script Bypass

- **E-23** (Round 2 addition): A level script (e.g., cinematic trigger, scripted kill volume, BossArenaScript) attempting to bypass i-frame protection by *directly* calling `Damage.commit_death(cause)`. **Mitigation**: (a) Damage GDD DEC-4's `monitorable=false` protection only works for *collision-driven* damage, so script-driven paths require a separate obligation — all level scripts must check `damage.is_in_iframe(player) -> bool` before calling `commit_death()` (Damage GDD F.5 expected helper). (b) Violation is silent — Damage fires an assertion; lethal commit attempts during REWINDING immediately fail in dev builds. (c) In Tier 1 prototype there are 0 script-driven kill volumes (hazard nodes only) → this edge case is registered as an obligation in Level Design Guide when Tier 2+ scripted encounters are introduced.

## Dependencies

This section provides a dependency *map*. Interface details — signal signatures, method signatures, Hard/Soft classification — are maintained as single source in Section C.3 "Interactions with Other Systems".

### Upstream Dependencies (systems this one depends on)

| # | System | Hard/Soft | Data Flow | Dependency Nature |
|---|---|---|---|---|
| **#1** | Input System | Hard | Poll InputMap action `"rewind_consume"` | SM polls action state upon entering DYING |
| **#2** | Scene / Stage Manager | Hard | `signal scene_will_change()` | Ring buffer invalidate just before scene unload (E-16). Systems-index entry update required |
| **#5** | State Machine Framework | Hard | TRC emits signals, SM subscribes and arbitrates | SM is sole arbiter at moment of death (Rule 17, 18) |
| **#6** | Player Movement | Hard | TRC reads 7 fields every tick + `restore_from_snapshot()` write | Capture target + single restoration path |
| **#8** | Damage / Hit Detection | Hard (indirect) | `player_hit_lethal(cause)` → SM subscribes | TRC does not subscribe directly — routed through SM |
| **#15** | Collage Rendering Pipeline | Soft (Pillar 1 consistency) | No data flow — *visual readability* dependency | **D4 fix 2026-05-10**: Pillar 1 ("punishment→learning tool") consistency holds only when enemies, bullets, and hazards are not obscured by collage layers in a 0.2s glance (game-concept R-D2). If collage readability fails, rewind becomes a *perceptual failure patch* rather than a *learning tool*. When Collage Rendering #15 GDD is written, the 0.2s glance test must be specified as an acceptance criterion. |

### Downstream Dependents (systems that depend on this one)

| # | System | Hard/Soft | Data Flow | Dependency Nature |
|---|---|---|---|---|
| **#11** | Boss Pattern | Hard (token economy) | `boss_killed(boss_id)` → TRC calls `grant_token()` | Single token replenishment mechanism |
| **#13** | HUD | Soft | `token_consumed`, `token_replenished` signals + `get_remaining_tokens()` poll | UI display (presentation) |
| **#14** | VFX / Particle | Soft | `rewind_started` + `rewind_protection_ended` signals | GPUParticles2D emit-pause / restart |
| **#16** | Time Rewind Visual Shader | Soft | `rewind_started` signal only + internal 0.5s Timer | Color-inversion + glitch visual signature |
| **#20** | Difficulty Toggle | Soft | `RewindPolicy` Resource injection (once at `_ready()`) | Token policy + window knob |
| **#3** | [Camera System](camera.md) | Hard | `rewind_started()` + `rewind_completed(player: PlayerMovement, restored_to_frame: int)` signals | Camera freezes on `rewind_started` (`is_rewind_frozen=true` → R-C1-1 skip — Pillar 1 "the gaze does not rewind" literal); `rewind_completed` unfreezes + force-clears shake + re-targets position + calls `reset_smoothing()` (camera.md R-C1-8/9 + F.1 row #5 reciprocal). DT-CAM-1 0 px drift self-evident verification path. Camera #3 Approved 2026-05-12 RR1 PASS. |
| **#4** | [Audio System](audio.md) | Hard | `rewind_started(remaining_tokens: int)` + `rewind_completed(player: Node2D, restored_to_frame: int)` signals | AudioManager: on `rewind_started` ducks Music bus −6 dB (2-frame Tween) + plays `sfx_rewind_activate_01.ogg`; on `rewind_completed` restores Music bus to 0 dB (10-frame linear Tween). audio.md Rules 8/9 + F. Upstream #9. Audio #4 Approved 2026-05-12. |

### New Signal Addition (ADR-0001 contract extension)

This GDD adds 1 signal to the ADR-0001 `rewind_lifecycle` contract:

```gdscript
signal rewind_protection_ended(player: Node2D)  # emitted on REWINDING → ALIVE transition (30 frames after rewind_started)
```

All 4 existing signals (`rewind_started`, `rewind_completed`, `token_consumed`, `token_replenished`) are preserved (backward compatible). This allows VFX, State Machine, and HUD to learn i-frame end from a single source. Update `docs/registry/architecture.yaml` `interfaces.rewind_lifecycle.signal_signature` in Phase 5b.

## Tuning Knobs

Reorganization of Section D Tuning Split into *tuning specification* format. Each knob includes current value, safe range, extreme behaviors, and interactions with other knobs.

### Designer-Adjustable (RewindPolicy Resource fields)

| Knob | Default | Safe Range | Too Low | Too High | Hard Suggestion | Easy Suggestion |
|---|---|---|---|---|---|---|
| `starting_tokens` | 3 | 0–10 | 0 = Hard mode (intentional). 1-2 = steep learning curve before first boss | 5+ = weakened Pillar 1 pressure, threatens "safety net" anti-fantasy | 0 | ∞ (`infinite=true`) |
| `max_tokens` | 5 | 1–10 | 1 = boss kill charge loses meaning | 10+ = token resource management catharsis is neutralized | N/A | N/A (`infinite` handles it) |

> **D1 fix 2026-05-10 — Silent cap-overflow contract gap (HUD coordination obligation)**: When `boss_killed` arrives with `_tokens == max_tokens` (5), `grant_token()` silently clamps — `_tokens` unchanged, `token_replenished` emit fires (Rule 3 / AC-B3 invariant). However, the anti-fantasy "spent an expensive resource — every transaction must be felt" breaks at the cap (boss defeat reward is invisible visually/audibly). **HUD obligation**: When HUD GDD #13 is written, the `token_replenished` handler must handle the `_tokens == max_tokens` branch *before* emit as a *separate cap-full feedback* (a brief different-color pulse or a separate SFX). This GDD only owns the signal contract; the presentation branch is solely owned by HUD. In Tier 1 baseline, the cap-full case can occur one or more times (start with 3 tokens, reach cap after 4-5 boss kills).
| `grant_on_boss_kill` | true | bool | false + tokens=3 = OK for Tier 1 4-6 week budget | true (default) | false | true |
| `infinite` | false | bool | false (default policy applied) | true = Easy mode, all token checks bypassed | false | **true** |
| `dying_window_frames` | 12 | 8–18 | 8 (Hard) = input response limit (~133ms). 6 or below violates Pillar 1 | 18 (Easy) = comfortable confirmation. 24 or above violates anti-fantasy | 8 | 16 |
| `input_buffer_pre_hit_frames` | 4 | 2–6 | 2 = input loss possible from single poll jitter | 6 = preemptive spam possible, but doesn't reach anti-fantasy level | 4 | 6 |

### Hardcoded const (changing = architecture contract violation)

| Const | Value | Impact if Changed | When Adjustable |
|---|---|---|---|
| `REWIND_WINDOW_FRAMES` | 90 | Ring buffer reallocation + ADR-0001/0002 amendment required. 1.5s window is the precise spec from game-concept Unique Hook. | Reconsideration possible at Tier 2 gate (no change outside this) |
| `RESTORE_OFFSET_FRAMES` | 9 | Changes `restore_idx` formula + lethal-hit head freeze interaction → ADR-0002 amendment required | Can be changed after Tier 1 prototype validation with ADR update |
| `REWIND_SIGNATURE_FRAMES` | 30 | i-frame protection + shader timer + art-bible Principle C visual signature are all coupled — single source. Changing one side alone splits visual/mechanic contract | Can be changed after Tier 1 prototype validation when art-director consensus is reached |

### Knob Interactions (balance re-review required on change)

- **`starting_tokens` × `grant_on_boss_kill`**: If both are false for the latter, tokens are limited to `starting_tokens` uses for the entire game. Token resource management tension operates at *whole-game level*. Intentional design combination.
- **`dying_window_frames` × `input_buffer_pre_hit_frames`**: Actual input window = `B + D = 4 + 12 = 16` frames ≈ 0.27s. Check combined result when adjusting both. Easy (B=6, D=16) → 22 frames ≈ 0.37s cognitive leeway. Hard (B=4, D=8) → 12 frames ≈ 0.2s precision required.
- **`infinite` × `grant_on_boss_kill`**: When `infinite=true`, the latter is irrelevant (bypasses token checks entirely). Having both true is harmless — Easy mode is a single flag check.
- **`max_tokens` × `grant_on_boss_kill`**: If the latter is false, the former is also meaningless (`starting_tokens` is effectively the cap). Set both values together for policy consistency.

### Tier Recommendation Matrix

| Stage | starting_tokens | max_tokens | grant_on_boss_kill | infinite | dying_window_frames | input_buffer_pre_hit_frames |
|---|---|---|---|---|---|---|
| **Tier 1 Prototype** | 3 | 5 | true | false | 12 | 4 |
| **Tier 2 MVP — Easy** | ∞ | (N/A) | true | **true** | 16 | 6 |
| **Tier 2 MVP — Normal** | 3 | 5 | true | false | 12 | 4 |
| **Tier 2 MVP — Hard** | 0 | 0 | false | false | 8 | 4 |
| **Tier 3 Full — Challenge (0 tokens)** | 0 | 0 | false | false | 8 | 2 |

### Design Guards (absolute prohibitions during tuning)

1. `infinite=true` + `dying_window_frames < 6` prohibited — if Easy mode users die due to input limits, the mode's own consistency collapses.
2. `starting_tokens > 5` prohibited (without a special design decision) — anti-fantasy "safety net" violation threshold.
3. `input_buffer_pre_hit_frames > dying_window_frames` prohibited — if the pre-hit window is longer than the grace window, the window semantics collapse.
4. When changing `REWIND_SIGNATURE_FRAMES`, i-frame and shader timer must change simultaneously — changing only one side splits the visual/mechanic contract (Section D D4 referenced).

## Visual/Audio Requirements

> Locked references: art-bible principle C, sections 1–4 + ADR-0001 R3 mitigation.
> art-director consultation 2026-05-09. Tier 1 uses placeholder VFX/SFX; Tier 2 final shader; Tier 3 audio outsourcing.

### Visual Events (by Section C state transition)

| Event | What player sees | Duration | Layer | Principle | Performance |
|---|---|---|---|---|---|
| **DYING entry** (lethal hit, grace start) | ECHO outline pulses once from Neon Cyan `#00F5D4` → Ad Magenta `#FF2D7F`. No fullscreen effect | 12 frames (matches `dying_window_frames` default) | Character-local; no world-space change | Principle A — maintain silhouette readability during grace window | ≤ 50 μs GPU (outline pass) |
| **rewind_consume** (input + token registered) | Frame 0 pre-flash: 1-frame fullscreen cyan burst `#00F5D4`, 30% alpha | 1 frame | Fullscreen post-process | Principle C — color-inversion onset pre-signal; Neon Cyan = player/REWIND meaning | < 1 ms; fires in same tick as `rewind_started` |
| **rewind_started** (entering REWINDING) | Frames 1–3: fullscreen cyan/magenta inversion (Rewind Cyan `#7FFFEE` dominant). Frames 4–8: UV-distortion collage-layer glitch dissolve. Frames 9–18: reverse-playback animation + palette restoration. | 18 frames (art-bible Principle C full sequence) | Fullscreen post-process (System #16 shader) | Principle C — "time rewind = color inversion + glitch" | Shader ≤ 500 μs/frame (within ≤ 1 ms rewind subsystem envelope) |
| **During REWINDING — frames 19–30** (i-frame tail) | Fullscreen effect clears. ECHO renders a 2 px Rewind Cyan `#7FFFEE` halo outline above all layers, fading 100% → 0% alpha over frames 19–30. World returns to normal palette. | 12 frames (tail up to frame 30 = `REWIND_SIGNATURE_FRAMES`) | Character-local halo above post-process | Principle A — ECHO readability recovery; signals i-frame active without UI text | ≤ 80 μs GPU |
| **rewind_protection_ended** (REWINDING → ALIVE) | Halo disappears. Delayed HUD token update fires (Rule 15: HUD delays visual update until this signal) | 1 frame (immediate) | HUD signal contract only; no world-space | Principle A — no visual noise; clean state return | Nil |
| **Token replenishment** (boss kill + `token_replenished`) | If fired during REWINDING: no visible change until `rewind_protection_ended` (Rule 15). If fired during ALIVE: brief flash on token counter (owned by System #13 HUD GDD — this GDD only specifies signal contract) | If during REWINDING, delayed to protection-end frame | HUD signal contract; no world-space | Semantic Color: Neon Cyan = player-resource gain | Nil (signal emit) |
| **Token denied** (`tokens == 0`, input registered) | No fullscreen effect. ECHO outline flashes white-adjacent `#E8F8F4` (not pure white) for 3 frames. Token counter denial visualization owned by System #13 HUD GDD | 3 frames (character-local only) | Character-local | Principle A — failure signal distinct from grace-pulse; no Magenta filling scene to preserve enemy readability | ≤ 30 μs GPU |
| **DEAD entry** (DYING grace expiry) | 1-frame `#FFFFFF` whiteout (art-bible Mood table "post-death restart" — the single sanctioned use of pure white, Section 4 forbidden-color exception) → immediate scene restoration | 1 frame | Fullscreen post-process | Mood table — "concise / neutral / immediate"; no death ceremony, Pillar 1 < 1s restart absolute requirement | ≤ 1 ms (1 frame) |

**Visual Tier note**: All fullscreen post-process rows use flat-color shader stubs in Tier 1. Final inversion + UV-distortion shader (System #16) is Tier 2. Character-local outline can be a simple `CanvasItem.draw_circle` mock in Tier 1.

### Audio Events

| Event | Sound character | Mix priority | Distinct from | Tier note |
|---|---|---|---|---|
| **DYING entry** | `sfx_dying_pending_01.ogg` × 1 — synth filter sweep **80 → 400 Hz over 200 ms** (1:1 envelope match to 12-frame `dying_window_frames` grace; B6 fix 2026-05-11); rising; NO vocal grunt (**Q5 RESOLVED 2026-05-11 per `player-movement.md` B6 fix — no-grunt locked across all PM + TR audio**) | **Foreground**; ambient duck + combat SFX duck (escalated from "no combat duck" 2026-05-11 per B6 fix — DYING is the highest-priority perceptual signal; combat audio must yield to land Pillar 1 reachability inside 200 ms envelope) | All rewind cues — "damage registered, not rewind" readability. `player-movement.md` AC-H6-06 gates first-encounter reachability inside this 200 ms envelope | Tier 1 (`sfx_dying_pending_01.ogg` authoring obligation registered; cross-doc reciprocal from `player-movement.md` VA.4 DYING/DEAD row) |
| **rewind_consume** | Sharp synthwave glitch tear — bright attack, sub 100ms decay | **Foreground**; duck all mid/background during frames 1–8 | `denied` cue (AC-B4a binding); DYING pulse | Tier 1 placeholder |
| **rewind_started** | `rewind_consume` cue continues into low-drone reverse-sweep tail; perceived as a single synthesized cue (same physics tick — no 1-frame offset needed) | **Foreground**; same duck chain as consume | Denied cue, ambient, enemy SFX | Tier 1: single placeholder; Tier 2: split layers |
| **rewind_protection_ended** | Soft resolution click — low-pass, settled | Mid; duck lifts at this cue | All active rewind cues | Tier 1 placeholder |
| **Token replenishment** | Synthwave token-charge chime — ascending 2-note | Mid; if fired during REWINDING, delayed until `rewind_protection_ended` (Rule 15) | Consume cue (must read as gain, not spend) | Tier 1 placeholder |
| **Token denied** | Dry null-thunk — dull low transient, no reverb | **Foreground** (brief); no ducking | **`rewind_consume` cue (AC-B4a binding)** — perceptually shorter, lower, no synthwave character | Tier 1 placeholder |
| **DEAD entry** | Silence cut — immediate audio stop, no death sting | — duck all active audio 1 frame before scene reload | All rewind cues | Tier 1: hard mute; Tier 3: optional sub-100ms micro-sting |

### Critical Visual Requirements (binding gates)

1. **Full-viewport coverage**: The frames 1–18 inversion effect (System #16 shader) must cover 100% of the viewport. Character-local-only fallback fails this gate. ECHO's restoration position may be far from the death point — the signature announces rewind activation to the *entire scene*.
2. **ECHO readability 0.5s glance (Principle A)**: ECHO must be identifiable within 0.5s during frames 1–18 inversion. Implementation binding: ECHO sprite and all bullet sprites render on a CanvasLayer above the post-process shader (render order: world → post-process shader → ECHO + bullets on top CanvasLayer). **This is R3 mitigation** — bullets are composited *after* the fullscreen pass, remaining visible through the inversion. Alternative (luminance-mask threshold) is delegated to technical-artist as secondary if CanvasLayer alignment causes a perf regression.
3. **Color-swap identity rule (Pillar 2)**: During inversion, ECHO (Neon Cyan → appears magenta) and enemies (Ad Magenta → appears cyan) are swapped. This must not cause silhouette confusion. Silhouette differentiation (Section 3 Shape Language) is the identity carrier — color-swap should read as "world flipped," not "ally/enemy confused." Gate test: in a 1080p 0.2s glance test, ECHO vs drone identification must be possible without relying on color.
4. **Consume vs denied audio distinction (AC-B4a binding)**: `rewind_consume` cue is bright/synthwave/attack. `denied` cue is dry/thunk/short. Must be perceptually different. QA test: blind listen 100% accurate identification.
5. **Frames 19–30 tail definition**: The 12-frame tail after art-bible Principle C's 18-frame sequence is the ECHO halo decay (Visual Events table "During REWINDING" row). Closes the gap between Principle C frame 18 and `REWIND_SIGNATURE_FRAMES = 30`.
6. **HUD signal contract (System #13 boundary)**: This GDD only specifies signal events. Token counter layout, animation, positioning, and font are decided in System #13 HUD GDD. Token replenishment visualization is delayed per Rule 15 to `rewind_protection_ended`.

### VFX Asset Spec Hooks

- `vfx_rewind_signature_loop_large.gdshader` — fullscreen inversion + UV distortion shader, frames 1–18; spec at `/asset-spec` Tier 2. Tier 1 stub: flat `#7FFFEE` 40% alpha fullscreen `ColorRect`.
- `vfx_echo_halo_decay_small.png` — 2 px Rewind Cyan outline sprite, used for frames 19–30 tail + DYING pulse; character-local CanvasItem draw. Naming convention `vfx_[effect]_[variant]_[size]`.
- `vfx_dead_whiteout_flash_large.png` — 1-frame `#FFFFFF` fullscreen sprite (Mood table sanctioned pure-white use — single instance only). Single frame, no loop variant needed.

📌 **Asset Spec** — Visual/Audio requirements defined. After art-bible approval, run `/asset-spec system:time-rewind` to generate per-asset visual descriptions, dimensions, and generation prompts from this section.

### Open Visual/Audio Questions

1. **Frames 1–18 CanvasLayer alignment vs shader performance**: Confirm with technical-artist that placing ECHO + bullet sprites on top CanvasLayer above post-process pass does not break batching or exceed Steam Deck 500 μs shader budget. If exceeded, evaluate luminance-mask fallback.
2. **DYING pulse color**: Current spec is Neon Cyan → Ad Magenta pulse. If Tier 1 playtesting shows confusion with REWINDING inversion onset, change DYING pulse to Vintage Yellow `#F0C040` (no art-bible conflict — Yellow is Sigma Unit / human trace, reads as warning). Defer decision to first playtest.
3. **`rewind_consume` + `rewind_started` synthesized audio**: Specified as a single synthesized cue (same tick). If technical-artist's Tier 2 implementation requires split-layer architecture (consume = attack layer, started = tail layer), it is permitted as long as the perceptual result is a single continuous event with no silence gap.

## UI Requirements

> Time Rewind does not own its own UI widget. All UI display — token counter, denial visualization, charge animation — is **owned by System #13 HUD GDD**. This section only specifies the **data contract** of what HUD must receive from this system to display.

### Data HUD Receives from This System

| Data | Source | Update Frequency | Display Obligation |
|---|---|---|---|
| `remaining_tokens: int` | `TimeRewindController.get_remaining_tokens()` (initial) + `token_consumed`, `token_replenished` signals (thereafter) | Signal-driven | Upper-left counter. Display exact integer value. Display "∞" or infinity symbol when `RewindPolicy.infinite == true`. |
| `rewind_state: enum {ALIVE, DYING, REWINDING}` | Owned by SM; HUD subscribes to SM signals | At state transition | Show charge-lock indicator on counter during DYING (only when `tokens == 0`). Delay counter update during REWINDING (Rule 15). |
| `consume event` (one-time) | `token_consumed` signal | Immediately on emission | Counter −1 animation. art-bible Neon Cyan pulse. Immediate update (visualized *before* entering REWINDING). |
| `replenish event` (one-time) | `token_replenished` signal | If fired during REWINDING, delay until `rewind_protection_ended` | Counter +1 animation. |
| `denied event` (one-time) | Emitted by SM when `tokens == 0 && DYING` (HUD-dedicated signal or SM exposed) | Immediately on input | Counter denial visualization (defined by System #13 HUD GDD — Visual Events table "Token denied" row specifies character-local portion only) |

### HUD Implementation Constraints (binding)

- HUD must maintain a `_displayed_tokens` cache and only update `Label.text` when changed (Integration Risk I6, AC-B4 supplement).
- HUD must not poll TRC — signal subscription only (observer pattern).
- HUD must buffer visual updates during REWINDING and flush at `rewind_protection_ended` (Rule 15).

### Rationale

The exact position, size, animation timing, font, and color of the token counter are decided in HUD GDD following the art-bible color palette and Mood table — if Time Rewind decided these alone, HUD consistency would break. What this GDD decides is the data contract only.

## Acceptance Criteria

> Test framework: GUT (Godot Unit Test). Coverage targets: balance formulas 100%, gameplay logic 70%.
> 34 criteria organized into 7 groups A–G (A:5 / B:8 / C:6 / D:5 / E:4 / F:2 / G:4 — Round 2 correction, previous notation 33 was a miscount). Automated tests are [AUTO], manual tests are [MANUAL].
> Determinism is guaranteed per single machine, single build (ADR-0003 R5). qa-lead verification 2026-05-09.

### A. Capture & Restoration

> **Terminology** (canonical mapping — W4 fix `/review-all-gdds` 2026-05-11; mirrors `player-movement.md` C.1.3): **8 PM-noted = 7 PM-owned + 1 Weapon-noted**. *PM-noted* (PM-readable) = 8 fields that PM exposes via `PlayerSnapshot` schema (7 PM-owned single-writer + `ammo_count` Weapon-owned single-writer per Amendment 2). *PM-owned* (PM single-writer) = 7 fields. *Resource total* = 9 fields = 8 PM-noted + 1 TRC-internal `captured_at_physics_frame` (Amendment 1). Bare "PM-exposed" in this GDD always means *PM-noted* (8). AC-A1 round-trip identity asserts the 8 PM-noted fields restore bit-identically; `captured_at_physics_frame` is TRC-internal and not subject to round-trip.

- **AC-A1** [AUTO] GIVEN the session has progressed W(90) or more physics frames, WHEN `_physics_process` fires, THEN `_capture_to_ring()` completes the slot with the following 3-tier ownership pattern (W3 fix `/review-all-gdds` 2026-05-11 — single-writer contract made explicit): (a) **PM 7-field read** (`global_position`, `velocity`, `facing_direction`, `animation_name`, `animation_time`, `current_weapon_id`, `is_grounded` — conforming to `forbidden_pattern direct_player_state_write_during_rewind`; TRC only reads, never writes to PM node), (b) **WeaponSlot.ammo_count read** (Amendment 2 2026-05-11 Weapon single-writer per ADR-0002; TRC only reads, never writes to Weapon node), (c) **TRC self-set `captured_at_physics_frame`** (Amendment 1 — TRC is the sole writer of this field). Total 9-fields written to `_ring[_write_head]` and `_write_head = (_write_head + 1) % 90` advances in the same tick. Test fixture spy: verifies TRC does not alter PM/Weapon node's own state (assertion = `player.ammo_count_before == player.ammo_count_after` per tick). _Verifies Rule 1 / Formula D3 / ADR-0001 7-PM-owned + Amendment 2 Weapon-owned + Amendment 1 TRC-internal single sources._
- **AC-A2** [AUTO] GIVEN `rewind_started` emitted, WHEN `_physics_process` executes during REWINDING, THEN `_write_head` is unchanged. GIVEN `rewind_protection_ended` fires, WHEN next `_physics_process` executes, THEN `_write_head` advances by exactly 1. _Verifies Rule 2._
- **AC-A3** [AUTO] GIVEN `lethal_hit_detected` fires at frame F (TRC subscribed signal — Damage 2-stage F.1 #8), WHEN `try_consume_rewind()` is called at any point during DYING grace window (F~F+11), THEN `restore_idx == (_lethal_hit_head − 9 + 90) % 90` and `_lethal_hit_head` is the frozen value of `_write_head` at frame F (not the value at call time). Test fixture records `_write_head` at frame F in a spy variable and compares with `_lethal_hit_head`. _Verifies Rule 9 / Formula D1 / ADR-0002 Amendment 1._
- **AC-A4** [AUTO] GIVEN `try_consume_rewind()` returns `true`, WHEN `restore_from_snapshot(snap)` + Weapon-side restoration (OQ-PM-NEW orchestration) completes, THEN player node's `global_position`, `velocity`, `facing_direction`, `current_weapon_id`, `animation_name`, `animation_time`, `is_grounded` all match `snap` values via PM-side restoration AND `WeaponSlot.ammo_count == snap.ammo_count` (Weapon-side restoration). `AnimationPlayer.seek(snap.animation_time, true)` was called. _Verifies Rule 10 / ADR-0001 8 PM-exposed fields contract (Amendment 2 2026-05-11 — ammo_count Weapon-owned)._
- **AC-A5** [AUTO] GIVEN SM enters REWINDING at frame R, WHEN counting frames until `rewind_protection_ended`, THEN exactly 30 frames. `physics_frames(rewind_protection_ended) − physics_frames(rewind_started) == 30`. _Verifies Rule 11 / `REWIND_SIGNATURE_FRAMES`._

### B. Token Economy

- **AC-B1** [AUTO] GIVEN `_ready()` called with `starting_tokens=3`, `infinite=false` `RewindPolicy`, WHEN `get_remaining_tokens()` polled immediately, THEN returns 3. _Verifies Rule 3 / Formula D2 `T_session_start`._
- **AC-B2** [AUTO] GIVEN `grant_on_boss_kill=true`, WHEN `boss_killed` signal fires, THEN `get_remaining_tokens()` increases by exactly 1, `token_replenished` emitted with new total. _Verifies Rule 15 / Formula D2._
- **AC-B3** [AUTO] GIVEN `get_remaining_tokens() == max_tokens` (default 5), WHEN `boss_killed` fires again, THEN `get_remaining_tokens()` does not exceed `max_tokens`. _Verifies Rule 3 / `RewindPolicy.max_tokens` cap._
- **AC-B4** [AUTO] GIVEN `_tokens == 0` AND ECHO in DYING state, WHEN `rewind_consume` input registered, THEN `try_consume_rewind()` returns `false`, SM stays in DYING, denial SFX identifier (distinct from consume SFX) fires once. Token count remains 0. _Verifies Rule 7 / Formula D2._
- **AC-B4a** [MANUAL] GIVEN AC-B4 conditions, WHEN denial SFX plays, THEN an audibly distinct cue from the token consume sound is heard. _Verifies Rule 7 anti-confusion audio._
- **AC-B5** [AUTO] GIVEN test harness injects `boss_killed` and `lethal_hit_detected` in the same physics frame (Boss `process_physics_priority=10`, Damage `process_physics_priority=2` per damage.md Round 3 lock), player input is pre-buffered (Rule 5 input_buffer_pre_hit_frames), WHEN signals are processed, THEN signal log shows **`token_consumed` observed *before* `token_replenished`** (Round 1 correction — Damage(2) → SM consume → Boss(10) grant order), and after both events `get_remaining_tokens()` equals the pre-event value (consume + grant = net zero). Intermediate T=0 dip is unobserved within the same tick and not directly verified. _Verifies Rule 16 / Integration Risk I2._
- **AC-B6** [AUTO] GIVEN `RewindPolicy` injected at `_ready()` via `@export var rewind_policy`, WHEN external caller attempts `rewind_policy` field mutation after `_ready()` completes, THEN `_tokens`, `_is_rewinding`, and other derived state are unaffected (setter is private; export reference is read-only post-ready). _Verifies Rule 3 / Integration Risk I7._
- **AC-B7** [AUTO] GIVEN `RewindPolicy.infinite == true` (Easy), WHEN `try_consume_rewind()` is called any number of times, THEN `_tokens` never decreases (token check path bypassed), and always returns `true` as long as buffer is primed and state is DYING. _Verifies Formula D2 `T_easy_guard` — checks skipped, not infinity arithmetic._

### C. State Machine

- **AC-C1** [AUTO] GIVEN ECHO ALIVE, WHEN `player_hit_lethal` fires, THEN SM transitions to DYING in the same physics tick, `_lethal_hit_latched` set to `true`. _Verifies Rule 4 / States and Transitions._
- **AC-C2** [AUTO] GIVEN ECHO DYING AND 12 frames elapsed with no valid rewind input, WHEN frame 13 arrives, THEN SM transitions to DEAD AND `_lethal_hit_latched` is cleared to `false` (latch release on direct DYING→DEAD path — added in Round 2). _Verifies Rule 8 + Rule 17 latch clear on both paths (DYING→DEAD this AC + REWINDING→ALIVE AC-C3) / `dying_window_frames` default 12._
- **AC-C3** [AUTO] GIVEN ECHO REWINDING, WHEN 30 frames elapsed, THEN `rewind_protection_ended` emitted + SM transitions to ALIVE. `_lethal_hit_latched` cleared to `false`. _Verifies Rule 11 / States and Transitions._
- **AC-C4** [AUTO] GIVEN `_lethal_hit_latched == true` (already DYING), WHEN second `player_hit_lethal` fires, THEN SM ignores it — `_lethal_hit_head` not re-cached, DYING count not reset. _Verifies Rule 17 / E-12, E-13._
- **AC-C5** [AUTO] GIVEN ECHO DYING or REWINDING, WHEN pause input dispatched, THEN SM intercepts and swallows — pause system does not activate, DYING/REWINDING count continues without interruption. _Verifies Rule 18 / E-19._
- **AC-C5a** [MANUAL] GIVEN actual pause UI connected, WHEN player presses pause button during DYING, THEN pause menu does not appear, DYING timer visibly continues. _Verifies Rule 18 in full scene context._

### D. Edge Cases

- **AC-D1** [AUTO] GIVEN hazard source (spikes, pits, kill volume) fires `player_hit_lethal(cause)`, `cause` identifies the hazard type, WHEN SM receives it, THEN ECHO enters DYING identically to a projectile lethal hit — `_lethal_hit_head` cached, 12-frame grace window opens. _Verifies E-11._
- **AC-D2** [AUTO] GIVEN ECHO DYING AND continuous damage source fires a second `player_hit_lethal` in a subsequent frame, WHEN SM processes it, THEN `_lethal_hit_latched` blocks it, `_lethal_hit_head` retains original value, DYING count is neither extended nor reset. _Verifies E-12._
    - **Round 5 update note (2026-05-10)**: The second hit's `player_hit_lethal` emit is *primarily* blocked by Damage step 0 first-hit lock (`damage.md` C.3.2 + AC-36). The SM `_lethal_hit_latched` this AC verifies is the secondary defence (against future corner cases where Damage step 0 is bypassed). When the primary block fires, the second emit itself never fires, so the SM processing branch in this AC is unreachable; this AC verifies latch behavior in isolation by directly injecting `player_hit_lethal` via SM stub.
- **AC-D3** [AUTO] GIVEN `scene_will_change` signal fires, WHEN `_buffer_invalidate()` executes, THEN `_buffer_primed = false`, `_write_head = 0`, `_tokens` unchanged. Lethal hit before W frames in the new scene causes `DYING → DEAD` (buffer-primed guard Rule 13-bis). _Verifies E-16._
    - **Note (I7 fix 2026-05-10)**: `_lethal_hit_head` is not explicitly cleared by `_buffer_invalidate()` (intentional). The Rule 13-bis buffer-primed guard causes `try_consume_rewind()` to immediately return false for the first W frames of the new scene, so the probability of using `_lethal_hit_head`'s stale value in the new scene is 0. When a new `lethal_hit_detected` arrives, Rule 4 overwrites it with the current `_write_head` value. Not explicitly clearing `_lethal_hit_head` is superior for both simplicity and determinism.
- **AC-D4** [AUTO] GIVEN boss phase transition (HP threshold crossed) during ECHO DYING, WHEN SM processes the transition, THEN no boss phase rewind occurs — boss `_phase` retains new value even after ECHO restoration. **Test harness (Round 2 addition)**: frame-perfect injection helper — fixture stubs the deterministic physics frame counter to deterministically inject lethal hit at frame F and boss phase advance at frame F+k (direct Engine.get_physics_frames() polling prohibited; exact frame ordering enforced via signal injection). _Verifies E-18 / ADR-0001 Player-only scope._
- **AC-D5** [AUTO] GIVEN ECHO mid-shooting-animation when `restore_from_snapshot()` is called, WHEN `AnimationPlayer.seek()` fires and a method-track key (e.g., `_on_anim_spawn_bullet`) would normally trigger, THEN no projectile is spawned — because `PlayerMovement._is_restoring == true`. `_is_restoring` is restored to `false` in the next `_physics_process`. **Test harness (Round 2 addition)**: frame-perfect injection — fixture injects lethal hit at exact frame offset after animation starts (same deterministic frame-counter mapping pattern as AC-D4 harness, reused). _Verifies E-21 / Integration Risk I9._

### E. Performance

- **AC-E1** [MANUAL] GIVEN 60 Hz game + TRC active (Round 2 reclassification: [AUTO]→[MANUAL] — Godot editor built-in Profiler cannot run headless in GUT), WHEN `_capture_to_ring()` cost is sampled over 600 consecutive frames using the Godot editor built-in Profiler, THEN per-tick average ≤ 0.05% of 16.6 ms frame budget (≤ 8.3 μs/tick — after D6 correction, worst-case 4 μs/tick is safely within envelope). **Automatable supplemental check [AUTO]**: Measure capture cost via `Time.get_ticks_usec()` delta in GUT (±2 μs interpreter jitter tolerance vs Profiler accuracy). Both measurements must satisfy cap to PASS. _Verifies Formula D6 / technical-preferences.md time-rewind subsystem cap._
- **AC-E2** [AUTO] GIVEN single rewind event triggered in test harness, WHEN `restore_from_snapshot()` executes (including AnimationPlayer.seek), THEN total elapsed time for restore call ≤ 1 ms (1,000 μs). _Verifies Formula D6 / `rewind_subsys_cap`._
- **AC-E3** [AUTO] GIVEN `_ready()` pre-allocates 90 `PlayerSnapshot` Resources, WHEN 1000 consecutive rewind events triggered in test scene followed by Godot memory snapshot, THEN `PlayerSnapshot` instance count is exactly 90 (per-tick allocation 0, leak 0). Ring buffer resident memory ≤ 25 KB. _Verifies Formula D5 corrected figures._
- **AC-E4** [MANUAL] GIVEN Steam Deck with a representative encounter (30+ enemies, 50+ active projectiles), WHEN player triggers rewind, THEN 60fps maintained: ≥ 99% of frames complete within 16.6 ms (measured via Godot built-in frame-time overlay). _Verifies technical-preferences.md 60 fps locked._

### F. Determinism

- **AC-F1** [AUTO] GIVEN scripted test sequence (fixed player input, fixed enemy `ai_seed`, fixed `spawn_physics_frame`), WHEN the sequence is run 1000 times on the same machine, same build, THEN all restoration events show bit-identical `PlayerSnapshot` values (position, velocity, facing_direction, animation_time, weapon_id, is_grounded) across all 1000 runs. _Verifies ADR-0003 Validation #1 / R5 (single-machine guarantee)._
- **AC-F2** [AUTO] GIVEN same encounter seed + deterministic input sequence, WHEN ECHO dies and rewinds at the same point in two independent test runs, THEN ECHO's `global_position` and `velocity` on the frame after `rewind_protection_ended` are identical across both runs (bit-identical, same machine). _Verifies ADR-0003 R-RT3-01 / Formula D1._

### G. Anti-Fantasy Guards

- **AC-G1** [AUTO] GIVEN no boss kill event fired, WHEN arbitrary physics frames elapse, THEN `_tokens` neither decreases nor increases (passive decay prohibited, passive grant prohibited) — token changes only via `try_consume_rewind()` (consume) or `grant_token()` (boss kill). _Verifies Section B Anti-Fantasy "invincibility power fantasy" / Rule 3._
- **AC-G2** [AUTO] GIVEN ECHO DYING + player registers pause input at frame F, WHEN SM swallows pause (Rule 18), THEN DYING grace window expires at frame F + (12 − elapsed), unaffected by pause attempt. Window is not extended. _Verifies Anti-Fantasy "not time stop" / Rule 18 / Section G design guard._
- **AC-G3** [AUTO] GIVEN `RewindPolicy` with `starting_tokens=0` AND `infinite=false` (Hard), WHEN ECHO receives lethal hit, THEN SM enters DYING for exactly `dying_window_frames` frames, denial cue fires on any rewind input, transitions to DEAD on expiry. DYING window exists even with 0 tokens. _Verifies Section G Tuning guard / States and Transitions Hard mode notes._
- **AC-G3a** [MANUAL] GIVEN AC-G3 Hard conditions, WHEN player attempts rewind input during DYING, THEN denial audio cue is audible + DYING visual state is visible (e.g., rewind visual signature does not fire). _Verifies Hard mode UX intent._

### Test Evidence Mapping

| Coverage area | Test type | Evidence location |
|---|---|---|
| Capture cadence & ring buffer | Unit (GUT) | `tests/unit/time-rewind/` |
| `_lethal_hit_head` freeze / `restore_idx` | Unit (GUT) | `tests/unit/time-rewind/` |
| 8-field PM-exposed restore correctness (per ADR-0002 Amendment 2) | Unit (GUT) | `tests/unit/time-rewind/` |
| REWINDING 30-frame accuracy | Unit (GUT) | `tests/unit/time-rewind/` |
| Token economy (start, grant, cap, consume, infinite) | Unit (GUT) | `tests/unit/time-rewind/` |
| Same-tick boss/lethal signal ordering | Integration (GUT) | `tests/integration/time-rewind/` |
| State machine 4-state transitions | Unit (GUT) | `tests/unit/time-rewind/` |
| Lethal-hit latch / continuous damage | Unit (GUT) | `tests/unit/time-rewind/` |
| Pause swallow (SM level) | Unit (GUT) | `tests/unit/time-rewind/` |
| Buffer invalidate on scene transition | Unit (GUT) | `tests/unit/time-rewind/` |
| Animation method-track `_is_restoring` guard | Unit (GUT) | `tests/unit/time-rewind/` |
| 1000-cycle determinism | Integration (GUT) | `tests/integration/time-rewind/` |
| Resident memory / no-leak (1000 rewinds) | Integration (GUT) | `tests/integration/time-rewind/` |
| Denial audio cue distinctiveness | Manual playtest | `production/qa/evidence/` |
| Pause swallow full scene | Manual playtest | `production/qa/evidence/` |
| Steam Deck 60fps load | Manual (target HW) | `production/qa/evidence/` |
| Hard mode UX (denial cue, DYING visible) | Manual playtest | `production/qa/evidence/` |

### Out-of-Scope (intentionally not tested in this GDD)

Integration contracts owned by other system GDDs — test evidence belongs there:

- **Damage System (#8)**: `lethal_hit_detected`/`death_committed` 2-stage separation; `player_hit_lethal(cause)` emit from all hazard sources; deterministic damage policy for same-tick multiple bullet hits (ADR-0003 R6).
- **Scene Manager (#2)**: `scene_will_change()` emission timing and guarantees; TRC subscription wiring.
- **HUD (#13)**: `_displayed_tokens` diff check per-fire allocation prevention; delayed visual update during REWINDING.
- **Visual Shader (#16)**: Internal 0.5s `Timer` wired only to `rewind_started`; *absence* of `rewind_completed` termination trigger (Integration Risk I5).
- **Weapon / Pickup (#7, #19)**: `WeaponSlot.set_active(invalid_id)` silent fallback to `id=0`; ammo count restoration policy decision (F6 / E-22 — pending until Weapon GDD is written).
- **Boss Pattern (#11)**: Enforced `process_physics_priority = 10`; documented phase transition rewind-immunity.
- **Pause System**: DYING/REWINDING pause-swallow exception noted in pause GDD (Rule 18 obligation).

## Open Questions

List of unresolved questions identified during writing of this GDD. Each item has an **owner (responsible for resolution)** and **target (resolution milestone)**.

### External GDD Dependencies (decided when other system GDDs are written)

| ID | Question | Owner | Target |
|---|---|---|---|
| ~~**OQ-1**~~ | ~~Ammo count restoration policy — (a) ratify "resume with live ammo" vs (b) add `PlayerSnapshot.ammo_count` ADR amendment? (E-22, F6)~~ — **RESOLVED 2026-05-11 (b) variant** via player-movement.md DEC-PM-3 v2 / B5 Pillar 1 resolution. ADR-0002 Amendment 2 obligatory. Player Shooting #7 has remaining obligation to decide Weapon-side write/restoration mechanism (OQ-PM-NEW). | ~~Weapon GDD (#7)~~ | ✅ **2026-05-11 closed** |
| **OQ-2** | How does the Damage system implement the `lethal_hit_detected` and `death_committed` 2-stage separation? (E-11, Integration Risk I1) | Damage GDD (#8) | When Damage GDD is written |
| **OQ-3** | Exact behavior of `WeaponSlot.set_active(invalid_id)` silent fallback — beyond id=0 (default weapon), is a visual/audio signal needed on fallback? (E-15) | Weapon GDD (#7) | When Weapon GDD is written |
| ~~**OQ-4**~~ ✅ **Resolved 2026-05-11 (Scene Manager #2 Approved RR7)** | ~~When exactly is `scene_will_change()` signal emitted — at trigger entry vs unload start? Are tokens always preserved? (E-16)~~ → **Emit timing = same physics tick sync emit immediately before `change_scene_to_packed` call** (scene-manager.md C.1 Rule 4 sole-producer); tokens always preserved (scene-manager.md C.1 Rule 7 + D.2 invariant — SM has zero `_tokens` write sites). F.1 row #2 `*(provisional)*` removed + canonical wiring locked. | [`design/gdd/scene-manager.md`](scene-manager.md) C.1 Rules 4+7 + D.2 + D.6 | **Resolved** |
| **OQ-5** | UX signal for pause swallow during DYING/REWINDING — should a denial cue fire on a pause attempt, or be handled silently? (Rule 18, E-19) | Pause System GDD | When Pause System GDD is written |

### Awaiting Playtest Decision

| ID | Question | Owner | Target |
|---|---|---|---|
| **OQ-6** | DYING pulse color — current spec Neon Cyan → Ad Magenta. Change to Vintage Yellow `#F0C040` if confused with REWINDING inversion onset (V/A Open Q2) | art-director + qa-lead | Tier 1 first playtest |
| **OQ-7** | `dying_window_frames` default — does 12 frames satisfy Defiant Loop fantasy, or is it too lenient? Is Easy 16 / Hard 8 split sufficient? | game-designer + qa-lead | Tier 1 prototype playtest (3-5 persons) |
| **OQ-8** | `input_buffer_pre_hit_frames` default — is 4 frames sufficient for jitter absorption? Increase to 6 if input loss occurs across controller variety? | gameplay-programmer + qa-lead | Tier 1 prototype controller compatibility test |

### Awaiting Technical Verification

| ID | Question | Owner | Target |
|---|---|---|---|
| **OQ-9** | Does `AnimationPlayer.seek(time, true)` exact-frame restore work without glitches on looping animations? (Engine context HIGH risk) | technical-artist + godot-specialist | Tier 1 Week 1 prototype |
| **OQ-10** | Does 1000-cycle determinism test PASS on dev machine with single machine, single build guarantee? (ADR-0003 R5; AC-F1) | gameplay-programmer | Tier 1 Week 1 prototype |
| **OQ-11** | Does the structure of frames 1–18 fullscreen post-process + ECHO/bullet sprites on top CanvasLayer maintain the 500 μs shader budget on Steam Deck? (V/A Open Q1) | technical-artist | When Tier 2 final shader is written |
| **OQ-12** | Is `rewind_consume` + `rewind_started` single synthesized audio cue achievable with split-layer implementation in Tier 2? (V/A Open Q3) | audio-director | When Tier 2 audio outsourcing happens |

### Future System Decisions

| ID | Question | Owner | Target |
|---|---|---|---|
| **OQ-13** | Easy toggle interface — game-concept Q3 (single toggle Cuphead Simple vs slider Hades God Mode) — decided by Difficulty Toggle GDD | game-designer | When Difficulty Toggle GDD (#20) is written |
| **OQ-14** | KB+M default key `Shift` suitability — ergonomic verification in Steam Deck KB+M mode and desktop mode | ux-designer | Tier 2 input mapping formalization |
| ~~**OQ-15**~~ ✅ **Resolved 2026-05-11** | ~~Can `"rewind_consume"` action be chord-mapped in Tier 3 Input Remapping?~~ → **`default_only` interpretation locked** (input.md C.2 single source): "single-button no-chord" invariant is limited to *shipped default mapping*; Tier 3 #23 remap UI allows player-bound chords (1-frame latency advisory display obligation). Consistent with Anti-Pillar #6 (Tier 3 accessibility). | [`design/gdd/input.md`](input.md) C.2 + Input #1 F.4.1 #9 closure | **Resolved** |

### Resolved (for reference)

The following questions were resolved during the writing of this GDD and are locked into ADRs/Sections:

- ✅ Trigger model (explicit / auto / hybrid) → Constrained-A: explicit + DYING 12-frame grace (Rule 4-7)
- ✅ Post-restore protection length → 30 frames (0.5s) i-frame, time-based, same source as signature (Rule 11)
- ✅ Re-entry policy → Silent ignore during REWINDING (Rule 13), unconditional block from DEAD (Rule 14)
- ✅ State machine 4-state agreement (ALIVE / DYING / REWINDING / DEAD)
- ✅ Capture PAUSE policy → Frozen only during REWINDING (Rule 2). Rewinding further back with accumulated token usage is a desirable visual/mechanic consistency effect
- ✅ rewind_completed meaning conflict → Option α add new signal `rewind_protection_ended` (ADR-0001 contract extension)
- ✅ Boss token replenishment — signal-based, direct call prohibited (Rule 16, C.3 #11)
- ✅ `RewindPolicy` runtime mutation — prohibited, scene reload only (Rule 3, AC-B6)
- ✅ TRC `process_physics_priority = 1` position (architecture.yaml update target)
- ✅ `restore_idx` lethal-hit head freeze (ADR-0002 Amendment 1)
- ✅ Buffer-primed guard (Rule 13-bis, complements AC-D3)
- ✅ Lethal-hit latch (Rule 17, E-12, E-13)
- ✅ DYING/REWINDING pause swallow (Rule 18, E-19)
- ✅ Animation method-track `_is_restoring` guard (E-21, I9)
