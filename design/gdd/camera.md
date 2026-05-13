# Camera System

> **Status**: Approved · 2026-05-12 · RR2 PASS — see design/gdd/reviews/camera-review-log.md for full history.
> **System**: #3 — Core layer, MVP priority
> **Author**: solo dev + game-designer / ux-designer / gameplay-programmer / systems-designer / qa-lead / art-director / creative-director (inline consults)
> **Last Updated**: 2026-05-12 — see design/gdd/reviews/camera-review-log.md for full history.
> **Implements Pillars**: Pillar 3 (collage first impression — screenshot composition) · Pillar 1 (sub-second checkpoint restart — snap-no-cut) · Pillar 2 (determinism — shake RNG seeded, no smoothing residual across rewind)
> **Depends on**: Scene Manager #2 (Approved RR7 PASS 2026-05-11) — triggers Q2 deferred signal addition `scene_post_loaded(anchor: Vector2)` to scene-manager.md C.2.1 (Phase 5 cross-doc batch — this GDD is the first-use case per Session 19 design call)
> **Engine**: Godot 4.6 / GDScript / 2D Forward+ / 60 fps locked

---

## A. Overview

Camera2D is a side-scrolling camera that follows ECHO, with **three responsibilities**:

1. **Follow** — tracks player position using horizontal deadzone-based advance (vertical uses grounded-baseline lookahead lerp).
2. **Snap** — upon receiving the `scene_post_loaded(anchor: Vector2)` signal emitted by Scene Manager at checkpoint restart, immediately calls `global_position = anchor` + `reset_smoothing()` to align **within 1 frame** with zero delay (Pillar 1 non-negotiable — within 60-tick restart budget).
3. **Shake** — visual emphasis for gameplay events (`shot_fired` micro-vibration, `player_hit_lethal` impact, `boss_killed` heavy shake). Shake intensity/duration/frequency are defined by this GDD as single source of truth (architecture.yaml line 358 registration contract).

### Data Layer (infrastructure framing)

`extends Camera2D`; single node (not autoload — placed at stage root as sibling of PlayerMovement). Each frame `global_position` = `target.global_position + look_offset + shake_offset`, where `shake_offset` is determined by `Engine.get_physics_frames()`-seeded `RandomNumberGenerator` → ADR-0003 determinism boundary compliant.

### Player Experience Layer (player-facing framing)

ECHO moves freely within screen center ±deadzone (horizontal 64 px, vertical 32 px), and the camera follows when ECHO reaches the deadzone edge. At jump apex, a subtle lookahead secures headroom above ECHO; on firing: 1-3 px micro-vibration (attack feel); on 1-hit lethal: 6 px heavy shake (frustration→reset visual signal); on boss kill: 8-12 px heavy shake (catharsis). Zoom is fixed at 1.0 in Tier 1 to preserve collage visual signature (Pillar 3) (Tier 2 boss zoom expansion deferred).

### ADR References

- **ADR-0001 (Player-only rewind)**: Camera is **NOT** a rewind target — after time rewind, camera restarts the next follow cycle from ECHO's restored position (ADR-0003 single writer `PlayerMovement.restore_from_snapshot()`).
- **ADR-0002 (Snapshot 9-field)**: Camera state is **not included** in PlayerSnapshot. Upon receiving `rewind_completed` signal, camera: (a) immediately clamps shake state to 0 (discards residual vibration), (b) recalculates `global_position` from restored player position. No snapshot scope expansion needed.
- **ADR-0003 (Determinism)**: shake offset is deterministic via per-event RNG seeded with `Engine.get_physics_frames()` + event emission frame; camera-relative decisions forbidden (e.g., despawning projectiles via VisibleOnScreenNotifier2D — already forbidden in Player Shooting #7 G.3 invariant #3).

### One-Line Summary

> Always keep ECHO within screen center ±deadzone, emphasize gameplay impact with deterministic shake, and align to the new anchor within 1 frame on checkpoint restart.

### A.1 Locked Decisions (this section)

| ID | Decision | Source |
|---|---|---|
| **DEC-CAM-A1** | Camera2D **NOT autoload** — placed at stage root as sibling of PlayerMovement (single instance per scene; Scene Manager creates a new instance on scene swap) | Scene Manager #2 C.2.4 ownership boundary compliant — scene boundary owner is SM, nodes inside the scene are stage responsibility |
| **DEC-CAM-A2** | Camera state **NOT in PlayerSnapshot** — ADR-0002 9-field lock maintained; camera restarts fresh after rewind | ADR-0002 Amendment 2 (9 fields locked); snapshot scope expansion risks memory budget pressure (Tier 1 17.64 KB) + Pillar 1 1-second restart obligation violation |
| **DEC-CAM-A3** | Shake `Engine.get_physics_frames()`-seeded RNG — ADR-0003 determinism compliant | ADR-0003 R-RT3-02 + R-RT3-06 (cosmetic exempt, but shake cross-links to projectile visual feedback → strict determinism adopted) |
| **DEC-CAM-A4** | Tier 1 zoom=1.0 fixed — Tier 2 boss zoom deferred | Pillar 5 (small successes > big ambition); art-bible 1080p/720p baseline (3px line @ 1080p; 1280×720 Steam Deck native) |
| **DEC-CAM-A5** | **Split horizontal/vertical position model**: horizontal incremental advance (`camera.x += overshoot` when \|delta_x\|>DEADZONE_HALF_X), vertical target+lookahead (`camera.y = target.y + look_offset.y`). `look_offset.x` is always 0 (unused). | Session 22 design-review BLOCKING #1 resolution 2026-05-12 — previous unified `camera = target + look_offset` model is arithmetically incompatible with F-CAM-2 worked example + AC-CAM-H1-01 (`camera.x = 501`); split adopted for deadzone semantics alignment (Katana Zero/Celeste pattern) |

## B. Player Fantasy

> **The camera never forgets.**
>
> Time rewinds, the player rewinds — but the camera does not. In the 1.5-second lookback the world resets, but the camera holds its ground — the **only thread of continuity** between the death just suffered and the second chance now taken. *Time rewinds; the gaze does not.* The camera is the player's memory made physical.

### B.1 What Does It Feel Like

| Pillar | How the camera contributes |
|---|---|
| **Pillar 1** (learning tool) | Immediately after time rewind, the camera reconstructs from ECHO's restored position without lerp — so the player reads it as "*I rewound myself*" rather than "*the world rewound me*". View continuity makes rewind a *non-punishing* learning tool. |
| **Pillar 2** (determinism) | Shake offset is determined by RNG seeded with `Engine.get_physics_frames()` + event emission frame. Same input sequence → same shake → same screenshot. Luck does not enter the camera. |
| **Pillar 3** (collage first impression) | Sub-principle "**The camera that remembers also composes**": even at the peak of boss-kill shake (8-12 px), the boss silhouette stays within the viewport's readable third (center legibility zone) — shake does not break collage composition. Screenshot signature preserved. |

### B.2 0.2-Second Design Tests (3)

These tests specify conditions under which the camera can *visibly* break player fantasy in a single frame. All are seeds for acceptance criteria.

| ID | 0.2-second moment | Pass condition | Fantasy broken on failure |
|---|---|---|---|
| **DT-CAM-1** | Rewind complete frame (T+0, after RESTORE_OFFSET_FRAMES=9) | Camera `global_position` identical to position just before T+0 — 0 px drift, 0 frame smoothing residual | "I rewound myself" → misread as "the world rewound me" (Pillar 1 learning-tool identity collapse) |
| **DT-CAM-2** | 8-12 px shake peak frame immediately after `boss_killed` emit | Boss sprite silhouette stays within viewport's readable third (horizontal center ±213 px @ 1280 width) | Pillar 3 collage signature collapse — catharsis screenshot taken with boss off-screen |
| **DT-CAM-3** | `player_hit_lethal` emit frame | 6 px impact shake starts *before* rewind UI/flash; rewind visual effect enters after shake ends | Camera shake read as UI chrome (weight of outcome lost) — Pillar 1 death→learning transition catharsis weakened |

### B.3 What Does It *Not* Feel Like (negative space)

- **No camera control actions**: the player does not directly manipulate the camera (RT-stick free-look, dedicated zoom button, etc. — all **explicitly rejected** — Tier 1 Anti-Pillar #6 input remapping excluded + Pillar 5 small successes).
- **No cinematic cutscenes**: on boss entry/defeat the camera does not wrest player control for cut-to-boss-portrait or similar cinematic staging (Anti-Pillar Story Spine cutscenes X + Pillar 4 5-minute rule + Pillar 1 1-second restart obligation).
- **No vision loss from camera lerp lag**: jump-apex lookahead is sufficient — players never fail to see overhead threats due to insufficient headroom above ECHO (directly tied to Pillar 2 determinism — not dying to luck).

### B.4 Locked Decisions (this section)

| ID | Decision | Source |
|---|---|---|
| **DEC-CAM-B1** | Player Fantasy headline = "The camera never forgets" — player-facing translation of Section A `Camera NOT in PlayerSnapshot` decision | creative-director consensus (Session 22 2026-05-12); Framing C adopted, Framing B absorbed as Pillar 3 sub-principle, Framing A motif integrated into DT-CAM-3 |
| **DEC-CAM-B2** | 3 0.2-second design tests (DT-CAM-1/2/3) → direct seeds for Section H acceptance criteria | All GDD player fantasies must reduce to falsifiable 0.2-second tests (game-concept.md Pillar 3 design test pattern compliant) |
| **DEC-CAM-B3** | Camera receives no player control input — Tier 1 / Tier 2 / Tier 3 all | Anti-Pillar #6 (input remapping deferred) + Pillar 5 (small successes) + Pillar 4 (5-minute rule — no additional controls to learn) |

## C. Detailed Design

### C.1 Core Rules (12 numbered rules — evaluation order)

These 12 rules are evaluated **in order** within a single `_physics_process(_delta)` callback. R-C1-1 is the core calculation for the frame budget; the rest are separated as guards, responses, or signal handlers.

**R-C1-1 (Per-frame position formula — split horizontal/vertical model)**

Each `_physics_process` tick, split horizontal/vertical model (Session 22 design-review 2026-05-12 BLOCKING #1 resolution — DEC-CAM-A5):

```
# Horizontal: deadzone incremental advance (applied immediately in R-C1-3)
delta_x = target.global_position.x - camera.global_position.x
if abs(delta_x) > DEADZONE_HALF_X:
    camera.global_position.x += delta_x - sign(delta_x) * DEADZONE_HALF_X
# else: camera.global_position.x unchanged (inside deadzone)

# Vertical: target + lookahead (state-scaled)
camera.global_position.y = target.global_position.y + look_offset.y

# Shake: channel applied after smoothing pass
camera.offset = shake_offset                        # NOTE: offset, NOT global_position
```

The horizontal/vertical split is **load-bearing**: horizontal uses incremental advance (Katana Zero/Celeste deadzone pattern — camera trails target by exactly DEADZONE_HALF_X in steady-state), vertical uses target+lookahead (pre-visualization for jump/fall). `look_offset` is a Vector2 but `.x` is always 0; only vertical lookahead `look_offset.y` carries meaning (DEC-CAM-A5).

The dual split keeps follow smooth with `position_smoothing_enabled=true`, while shake is written to the `offset` channel which is applied after the smoothing pass and therefore not blurred by lerp. Godot 4.6 Camera2D treats `offset` as a post-smoothing displacement (gameplay-programmer verified 2026-05-12).

`limit_left/right/top/bottom` clamping is Camera2D built-in (see Rule R-C1-12 stage limit setup).

**R-C1-2 (Rewind freeze guard)**

If `is_rewind_frozen == true`, skip all of R-C1-1. Both `global_position` and `offset` are frozen at their last unfrozen tick values. Pillar 1 "the gaze does not rewind" compliant + trivial verification path for DT-CAM-1 (0 px drift at rewind end).

**R-C1-3 (Horizontal deadzone follow — incremental advance)**

```
delta_x = target.global_position.x - camera.global_position.x
if abs(delta_x) <= DEADZONE_HALF_X (= 64):
    camera.global_position.x unchanged   # inside deadzone
else:
    # Limit-boundary guard (E-CAM-1 amendment 2026-05-12 — defense-in-depth under split-H/V):
    # if camera is already clamped at limit_left and delta_x < 0 (player moving further left),
    # or limit_right clamp + delta_x > 0 — skip advance (Godot built-in clamp absorbs, but explicit here).
    if (camera.global_position.x <= limit_left and delta_x < 0) or \
       (camera.global_position.x >= limit_right and delta_x > 0):
        pass  # skip advance when pinned against wall
    else:
        camera.global_position.x += delta_x - sign(delta_x) * DEADZONE_HALF_X  # incremental advance
```

When ECHO is within ±64 px of screen center, camera.x is stationary; the moment ECHO crosses the deadzone boundary, camera.x immediately advances by the overshoot amount (in steady-state, camera trails target.x by exactly DEADZONE_HALF_X). 64 px = 5% of viewport_width 1280, midpoint between Katana Zero (80) and Celeste (32) — appropriate for 6 rps run-and-gun pacing (ux-designer verified 2026-05-12).

**Limit-boundary guard rationale** (E-CAM-1, 2026-05-12 systems-designer verified + Session 22 BLOCKING #1 amendment): in the split-H/V model (DEC-CAM-A5) there is no `look_offset.x`, so wall-pinch deficit accumulation is structurally impossible — Godot built-in `limit_*` clamp absorbs each tick's advance. This explicit guard is defense-in-depth — protection against Godot clamp failure or future changes.

**R-C1-4 (Vertical asymmetric lookahead — state-scaled)**

| Player Movement state | `look_offset.y` target | Lerp |
|---|---|---|
| `idle` / `run` (grounded) | `0` | — (immediate) |
| `jump` (rising) | `-JUMP_LOOKAHEAD_UP_PX` (= -20) | `LOOKAHEAD_LERP_FRAMES` (= 8 frames) |
| `fall` | `FALL_LOOKAHEAD_DOWN_PX` (= 52) | 8 frames |
| `aim_lock` | `0` | — (immediate) |
| `REWINDING` / `DYING` (EchoLifecycleSM — checked before movement state) | immediately clamp to 0 | — (immediate) |

The `y` axis is negative upward (Godot standard). Run-and-gun landing threats (spikes, floor enemies) are more frequent than jump-apex threats, so the fall direction is 2.6× deeper (52/20 ≈ 2.6). State-scaled wins over velocity-scaled — velocity-based creates residual lerp after rewind, threatening DT-CAM-1 (ux-designer + game-designer consensus).

**R-C1-5 (Shake — per-event timer pool)**

Each shake event has an independent timer slot (per-event, NOT a single trauma scalar):

```
class ShakeEvent:
    amplitude_peak_px: float
    duration_frames: int
    frame_start: int           # Engine.get_physics_frames() at emit
    event_seed: int            # monotonic counter, per-camera-instance
```

`shake_offset` calculation each tick:

```
shake_offset = Vector2.ZERO
for event in active_events:
    frame_elapsed = current_frame - event.frame_start
    if frame_elapsed >= event.duration_frames:
        remove(event); continue
    decay = 1.0 - (frame_elapsed / event.duration_frames)        # linear decay
    rng.seed = (current_frame * 1_000_003) ^ event.event_seed     # patch-stable (NOT hash())
    direction = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
    shake_offset += direction * event.amplitude_peak_px * decay
shake_offset = shake_offset.limit_length(MAX_SHAKE_PX)            # = 12 px clamp
```

Event parameters (Tier 1):

| Event signal | Peak amplitude (px) | Duration (frames) | Source |
|---|---|---|---|
| `shot_fired` | 2 (range 1-3) | 6 | Player Shooting #7 (6 rps fire rate; FIRE_COOLDOWN_FRAMES=10 > 6 → natural decay before next shot) |
| `player_hit_lethal` | 6 | 12 | Damage #8 |
| `boss_killed` | 10 (range 8-12) | 18 | Damage #8 |

**R-C1-6 (Shake stacking — sum-clamped)**

When 2+ events are simultaneously active in the same tick, amplitudes are vector-summed and clamped to `MAX_SHAKE_PX = 12`. The larger event visually dominates (boss_killed's 10 px absorbs a simultaneous shot_fired's 2 px). Events do not cancel each other (Vlambeer trauma model variant; Nuclear Throne pattern compliant — ux-designer cited 2026-05-12).

`shot_fired` 6-frame duration < FIRE_COOLDOWN_FRAMES 10-frame → micro-shake accumulation is **structurally** blocked (guaranteed by timeline gap, not just clamp).

**R-C1-7 (Shake RNG determinism)**

Per-event `event_seed` is a per-camera-instance monotonic counter (`var _shake_event_seed_counter: int = 0`; `_shake_event_seed_counter += 1` called in each emit handler). RNG seed = `(current_frame * 1_000_003) ^ event_seed`, re-seeded each frame (gameplay-programmer verified: `hash(Vector2i(...))` has no patch-stability guarantee in Godot 4.6; explicit prime mix is safe).

ADR-0003 R-RT3-02 compliant: shake offset is a pure function of the `Engine.get_physics_frames()` monotonic counter.

**R-C1-8 (`rewind_started` handler)**

```gdscript
func _on_rewind_started() -> void:
    is_rewind_frozen = true
    # active shake events continue their timer countdown, but R-C1-2 skips R-C1-1 so they are not reflected visually
```

The camera does not track ECHO while frozen — literal implementation of "the gaze does not rewind". Direct architecture-to-experience translation of Player Fantasy Framing C.

**R-C1-9 (`rewind_completed` handler)**

```gdscript
func _on_rewind_completed(player_node: PlayerMovement, restored_to_frame: int) -> void:
    is_rewind_frozen = false
    active_events.clear()                          # force-terminate all active shakes
    shake_offset = Vector2.ZERO
    offset = Vector2.ZERO
    look_offset = _compute_initial_look_offset(player_node)   # .x = 0 (unused per DEC-CAM-A5); .y = state-mapped
    # Split H/V reset (per R-C1-1 model):
    global_position.x = player_node.global_position.x         # deadzone re-establishes next ticks via R-C1-3
    global_position.y = player_node.global_position.y + look_offset.y
    reset_smoothing()                              # force-sync smoothing accumulator to new position
    # R-C1-1 evaluated normally from next _physics_process tick
```

Order is non-negotiable: (1) unfreeze, (2) clear shake, (3) recompute look_offset, (4) assign global_position.x/.y, (5) call reset_smoothing. **(5) must come after (4)** — if `reset_smoothing()` is called before (4), it treats the old position as the new anchor, causing lerp residual (gameplay-programmer verified 2026-05-12).

**`_compute_initial_look_offset(player_node)` spec (BLOCKING #3 resolution Session 22 2026-05-12)**:

```gdscript
func _compute_initial_look_offset(player_node: PlayerMovement) -> Vector2:
    var lifecycle: StringName = player_node.lifecycle_sm.state
    if lifecycle == &"REWINDING" or lifecycle == &"DYING":
        return Vector2.ZERO                                          # lifecycle state takes priority (DEC-PM-1 fix)
    var target_y: float = _target_y_for_state(player_node.movement_sm.state)
    return Vector2(0.0, target_y)   # .x = 0 always (split-H/V model — DEC-CAM-A5)

func _target_y_for_state(state: StringName) -> float:
    match state:
        &"jump":  return -JUMP_LOOKAHEAD_UP_PX                      # −20 (DEC-PM-1 canonical)
        &"fall":  return  FALL_LOOKAHEAD_DOWN_PX                    # +52
        _:        return 0.0                                         # idle / run / aim_lock / dead / default
```

1:1 mapping with R-C1-4 state→target_y. AC-CAM-H4-02 field (e) directly asserts this spec.

DT-CAM-1 trivial verification: at T+0 (1 tick immediately after `rewind_completed`) `global_position.x` equals `player.global_position.x` (deterministic, identity function), `global_position.y` equals `player.global_position.y + look_offset.y` (deterministic, state-mapped) — 0 px drift, 0 frame smoothing residual.

**R-C1-10 (`scene_post_loaded(anchor: Vector2, limits: Rect2)` handler — checkpoint snap)**

```gdscript
func _on_scene_post_loaded(anchor: Vector2, limits: Rect2) -> void:
    limit_left   = int(limits.position.x)
    limit_right  = int(limits.position.x + limits.size.x)
    limit_top    = int(limits.position.y)
    limit_bottom = int(limits.position.y + limits.size.y)
    look_offset  = Vector2.ZERO
    offset       = Vector2.ZERO
    active_events.clear()
    is_rewind_frozen = false
    global_position = anchor
    reset_smoothing()
```

Emitted in the same tick as Scene Manager #2 C.2.1 POST-LOAD phase (first-use case of the Q2 deferred signal — see Phase 5 cross-doc obligation). Camera cost = **≤ 1 tick** within SM 60-tick restart budget (absorbed into K of `M + K + 1 ≤ 60`, no additional overhead — just 9 assignments + `reset_smoothing()`).

`limits: Rect2` absorbs stage-by-stage variation. Tier 1 single stage = single `Rect2`; on Tier 2 multi-room entry, same signal reused (signature unchanged).

**R-C1-11 (`_physics_process` priority = 30)**

```gdscript
func _ready() -> void:
    process_physics_priority = 30
    process_callback = CAMERA2D_PROCESS_PHYSICS
    position_smoothing_enabled = true
    position_smoothing_speed = 32.0    # exponential decay rate; ~5-frame settle on 64 px delta
    zoom = Vector2.ONE                 # Tier 1 lock; Tier 2 boss zoom deferred
```

ADR-0003 ladder compliant: player=0, TRC=1, Damage=2, enemies=10, projectiles=20, **Camera=30**. All gameplay sources settle within the same tick before camera calculates final position. Priority 100 rejected — intended next slot on ADR-0003 ladder is 30 (70 empty slots reserved for future systems; 30 is the natural "post-gameplay visual layer" slot).

`CAMERA2D_PROCESS_PHYSICS` callback mode is non-negotiable — `IDLE` mode is 1-tick out-of-phase with player transform → breaks rewind snap correctness (godot-specialist verified 2026-05-12).

`position_smoothing_speed = 32.0` is an **exponential decay rate** (godot 4.6 doc "points/sec" is misleading — actual behavior is `pos = pos.lerp(target, speed * delta)` per-frame): a 64 px delta converges to ~1 px residual within 5 frames (`(1 - 32 * 0.0167)^5 ≈ 0.014` → 64 × 0.014 ≈ 0.9 px). `reset_smoothing()` force-syncs the accumulator in 1 call → residual 0 after snap.

**R-C1-12 (Stage limits — single source via signal)**

Stage limits have `limits` argument of `scene_post_loaded(anchor, limits: Rect2)` as **single source of truth**. R-C1-10 handler sets `limit_left/right/top/bottom` atomically. No other path may write limits (single-writer principle).

**Boot ordering contract** (scene-manager.md C.2.1 lifecycle compliant): SM 5-phase lifecycle transitions to READY after emitting `scene_post_loaded` within the POST-LOAD phase, and player input dispatch does not start before READY — therefore the first `scene_post_loaded` emit always arrives before the camera's first meaningful `_physics_process` tick. No separate guard needed on the camera side — this ordering is structurally guaranteed by the SM contract (AC-CAM-H-INTEG-1 verified).

---

### C.2 States and Transitions

The camera has a **single logical state `FOLLOWING`**, with 2 bool flags guarding the branches of R-C1-1:

| Flag | Set when | Cleared when | Effect |
|---|---|---|---|
| `is_rewind_frozen` | `_on_rewind_started` (R-C1-8) | `_on_rewind_completed` (R-C1-9) | skip R-C1-1 — camera frozen |
| `apply_snap_next_frame` | set inside `_on_scene_post_loaded`, consumed and cleared in same handler | — | R-C1-10 body executed directly (no 1-tick latency) |

**Why no formal state machine**: the camera's branching can be expressed as if-guards within a single update flow, and the `extends StateMachine` framework in state-machine.md targets multi-instance + concurrent reactive transitions. Camera is a single instance per scene, single caller, single update path → does not justify framework overhead (Scene Manager #2 C.2.3 enum+match pattern precedent compliant).

**Why REWIND_FREEZE is not a separate state**: two options — α-freeze (current decision) vs β-follow-player-back. α adopted. β keeps `is_rewind_frozen=false` and has the camera follow player position during rewind, but creates lerp residual at rewind end, making DT-CAM-1 (0 px drift / 0 frame smoothing residual) verification fragile. α is trivially testable — single equality assert `global_position(T+0) == global_position(T-1, last frozen frame)`.

**Diagram**:

```
                ┌──────────────────────┐
                │                      │
                │  FOLLOWING           │ ← all tick behavior is R-C1-1
                │  (single state)      │
                │                      │
                │  flags:              │
                │   is_rewind_frozen   │ ← R-C1-8 set / R-C1-9 clear
                │   apply_snap_next    │ ← self-consumed inside R-C1-10 handler
                │                      │
                └──────────────────────┘
                    (entry: _ready;
                     no exit — node persists for stage lifetime)
```

---

### C.3 Interactions with Other Systems

#### C.3.1 Signal Subscribe Matrix (Camera subscribes to 6 signals, emits 0)

| Signal | Signature | Emitter | Camera handler | Side-effect | Frame cost |
|---|---|---|---|---|---|
| `scene_post_loaded` | `(anchor: Vector2, limits: Rect2)` | Scene Manager #2 (Q2 deferred, **this GDD is the first-use trigger — Phase 5 cross-doc obligation**) | `_on_scene_post_loaded` (R-C1-10) | set 4 `limit_*` values + position snap + `reset_smoothing()` | ≤ 1 tick |
| `shot_fired` | `(direction: int)` | Player Shooting #7 (Approved 2026-05-11; F.4.2 Camera #3 obligation registered) | `_on_shot_fired` | add micro shake to active_events (2 px / 6 frames) | negligible |
| `player_hit_lethal` | `(_cause: StringName)` | Damage #8 (LOCKED for prototype) | `_on_player_hit_lethal` | add impact shake to active_events (6 px / 12 frames) | negligible |
| `boss_killed` | `(boss_id: StringName)` | Damage #8 F.4 LOCKED single-source | `_on_boss_killed` | add catharsis shake to active_events (10 px / 18 frames) | negligible |
| `rewind_started` | `()` | Time Rewind #9 Approved | `_on_rewind_started` (R-C1-8) | `is_rewind_frozen = true` | negligible |
| `rewind_completed` | `(player: PlayerMovement, restored_to_frame: int)` | Time Rewind #9 Approved (canonical signature per W2 housekeeping 2026-05-10) | `_on_rewind_completed` (R-C1-9) | unfreeze + clear shake + re-derive position + `reset_smoothing()` | ≤ 1 tick |

**Camera emits**: **NONE in Tier 1**. Pillar 3 collage screenshot capture is a Steam built-in function + user-triggered (F12 default); no downstream for the camera to emit to. Hypothetical future emitter `composition_changed` etc. has no dependents → YAGNI rejected.

#### C.3.2 ADR-0003 Determinism Boundary

The camera is located **outside** or at the **edge** of the ADR-0003 determinism boundary:

- **Outside (cosmetic-exempt candidate)**: `global_position` / `offset` are not gameplay-affecting state and are not included in PlayerSnapshot → ADR-0003 R-RT3-06 cosmetic exemption clause applicable.
- **However, this GDD adopts a stricter contract**: since shake RNG is `Engine.get_physics_frames()`-seeded, it trivially satisfies ADR-0003 R-RT3-02 (deterministic w.r.t. frame counter, no wall clock, no global RNG) without needing cosmetic exemption. Reasons: (1) camera visuals are Pillar 3 collage screenshot signature — bit-identical replay guarantees marketing image consistency, (2) camera determinism is a prerequisite for Tier 2+ replay/share features, (3) cosmetic exemption risks boundary-creep → strict adoption protects future expansion.

**Forbidden patterns verified**:
- ❌ `VisibleOnScreenNotifier2D` for gameplay trigger decisions — already forbidden in Player Shooting #7 G.3 invariant #3 (projectile despawn camera-relative forbidden).
- ❌ `Time.get_ticks_msec()` / `OS.get_unix_time()` based shake — wall-clock dependency, ADR-0003 violation.
- ❌ `randf()` global RNG — use per-event `RandomNumberGenerator`.
- ❌ `hash(Vector2i(...))` seed — no patch-stability guarantee in Godot 4.6; use explicit `(frame * 1_000_003) ^ event_seed` (gameplay-programmer verified).

#### C.3.3 Cross-doc Reciprocal Obligations (Phase 5 batch application — BLOCKING gate)

The signal contracts for which this GDD is the first-use trigger must be reflected in the following GDDs (Phase 5 cross-doc batch — Approved promotion gate obligation, scene-manager.md F.4.1 RR4 precedent compliant):

| Affected GDD | Change | Location |
|---|---|---|
| `design/gdd/scene-manager.md` | C.2.1 POST-LOAD phase: not exposed SM-internally → **add `scene_post_loaded(anchor: Vector2, limits: Rect2)` signal**. Add emitter row to C.3 signal matrix. Close C.3.4 Q2 obligation (Camera #3 first-use). DEC-SM-9 status flip: deferred → resolved | C.2.1 + C.3.1 + C.3.4 + DEC-SM-9 |
| `design/gdd/scene-manager.md` | F.4.2 row Camera #3: obligation status check — "signal added with this GDD revision" → "done (Camera #3 #C.1.10 handler called)" | F.4.2 row #3 |
| `design/gdd/scene-manager.md` | OQ-SM-A1 → resolved (Camera #3 first-use occurred) | Z OQ table |
| `design/gdd/scene-manager.md` | Add boot-time assert to C.2.1 POST-LOAD emit handler: `assert(limits.size.x > 0 and limits.size.y > 0)` (E-CAM-7 — prevent invalid Rect2) | C.2.1 POST-LOAD body |
| `design/art/art-bible.md` | Add "Camera Viewport Contract" subsection at end of Section 6 (Environment Design Language) — screen-shake uniform displacement + readable third definition + Tier 2 zoom bound 0.85..1.25× + ECHO ≥32 px apparent height floor (art-director verified 2026-05-12) | Section 6 |
| `docs/registry/architecture.yaml` | Add `scene_post_loaded(anchor: Vector2, limits: Rect2)` to `interfaces.scene_lifecycle.signals` + consumers=[camera] (append stage + hud on Tier 2 entry) | interfaces.scene_lifecycle |
| `docs/registry/architecture.yaml` | New entry `interfaces.camera_shake_events` — consumers=[camera-system], producers=[player-shooting, damage] | new entry |
| `docs/registry/architecture.yaml` | New forbidden pattern `camera_state_in_player_snapshot` — Camera state must never be included in PlayerSnapshot (protects ADR-0002 9-field lock) | forbidden_patterns |
| `design/registry/entities.yaml` | 6 new constants: `DEADZONE_HALF_X`, `JUMP_LOOKAHEAD_UP_PX`, `FALL_LOOKAHEAD_DOWN_PX`, `LOOKAHEAD_LERP_FRAMES`, `MAX_SHAKE_PX`, `POSITION_SMOOTHING_SPEED` | constants |
| `design/gdd/systems-index.md` | Row #3 Camera System: Status Not Started → Designed (or Approved post-review); add Design Doc link | Row #3 |

## D. Formulas

All formulas in this section encode Section C rules in falsifiable quantitative form. All variables are defined in tables and include output ranges + worked examples.

---

### F-CAM-1 — Per-Frame Position Resolution (split H/V model)

```
# Horizontal: incremental deadzone advance (F-CAM-2)
delta_x = target.global_position.x - camera.global_position.x
if abs(delta_x) > DEADZONE_HALF_X:
    camera.global_position.x += delta_x - sign(delta_x) * DEADZONE_HALF_X

# Vertical: target + lookahead
camera.global_position.y = target.global_position.y + look_offset.y

# Shake: smoothing-bypass channel
camera.offset = shake_offset
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `target.global_position` | Vector2 | stage-bounded (Tier 1 single-stage) | Player world position this tick |
| `look_offset.x` | — | always 0 (unused per DEC-CAM-A5) | Reserved field; horizontal uses incremental advance, not offset |
| `look_offset.y` | float | −20..+52 px | Vertical lookahead (F-CAM-3 state-scaled lerp output) |
| `shake_offset` | Vector2 | length ≤ MAX_SHAKE_PX (=12 px) | Post-smoothing screen displacement (F-CAM-5 output) |
| `camera.global_position.x` | float | stage-limit-clamped by Camera2D built-in | Incremental — trails target.x by DEADZONE_HALF_X in steady-state |
| `camera.global_position.y` | float | stage-limit-clamped by Camera2D built-in | = target.global_position.y + look_offset.y |
| `camera.offset` | Vector2 | length ≤ 12 px | Post-smoothing pixel offset (bypasses smoothing) |

**Output range**: `camera.global_position` has built-in `limit_*` clamp applied; `camera.offset` is clamped to within 12 px by F-CAM-5. The two write-site separation is non-negotiable — Godot 4.6 Camera2D applies `offset` after the smoothing pass, guaranteeing shake is not blurred by lerp (Pillar 2/3).

**Worked example**: ECHO at world position `(640, 360)`, ECHO has been sprinting right such that camera trails target by exactly DEADZONE_HALF_X (steady-state), shake inactive, grounded (look_offset.y = 0):
- Previous tick `camera.x = 576` (= 640 − 64), ECHO new position `target.x = 643` → `delta_x = 67 > 64` → `camera.global_position.x += 67 − 64 = +3` → `camera.x = 579`.
- `camera.global_position.y = 360 + 0 = 360`
- `camera.offset = Vector2(0, 0)`
- Result: ECHO is +64 px right of viewport center (`viewport_relative.x = ECHO.x − camera.x = 643 − 579 = 64 px`); as long as ECHO stays at deadzone edge, camera advances in lock-step with player.

---

### F-CAM-2 — Horizontal Deadzone Camera Advance

```
delta_x = target.global_position.x − camera.global_position.x
if abs(delta_x) > DEADZONE_HALF_X:
    camera.global_position.x += delta_x − sign(delta_x) × DEADZONE_HALF_X
# else: camera.global_position.x unchanged (inside deadzone — no change)
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `delta_x` | float | unbounded | `target.x − camera.x` (this tick, before advance) |
| `DEADZONE_HALF_X` | int (locked) | **64 px** | Horizontal deadzone half-width |
| `camera.global_position.x` | float | stage-limit-clamped (Godot built-in `limit_left/right`) | Incremental advance result (this tick after update) |

**Output range**: `camera.global_position.x` advances by the overshoot amount; Godot built-in `limit_left/right` clamp applied. In steady-state, camera trails target.x by exactly DEADZONE_HALF_X.

**Worked example** — crossing deadzone edge (AC-CAM-H1-01 compliant):
- Previous tick `camera.x = 500`, new tick `target.x = 565` → `delta_x = 65`, `|65| > 64` → `camera.global_position.x += 65 − sign(65) × 64 = +1 px` → `camera.x = 501`.
- Next tick `target.x = 566` → `delta_x = 566 − 501 = 65` → again `+1 px` advance → `camera.x = 502`.
- As long as ECHO stays at deadzone edge, camera follows player at the same speed in lock-step (camera trails target by DEADZONE_HALF_X=64 exactly). Pillar 1 — deterministic, no sub-pixel residual.

---

### F-CAM-3 — Vertical Lookahead State Lerp

```
look_offset.y = lerp(look_offset.y, target_y, 1.0 / LOOKAHEAD_LERP_FRAMES)
```

State → `target_y` mapping:

| State | `target_y` (px) |
|---|---|
| `idle` / `run` (grounded) | 0 |
| `jump` (rising) | −JUMP_LOOKAHEAD_UP_PX = **−20** |
| `fall` | +FALL_LOOKAHEAD_DOWN_PX = **+52** |
| `aim_lock` | 0 |
| `REWINDING` / `DYING` (EchoLifecycleSM — checked before movement state) | 0 (immediate clamp — no lerp) |

| Variable | Type | Range | Description |
|---|---|---|---|
| `look_offset.y` | float | −20..+52 px | Current vertical leading offset |
| `target_y` | int | {−20, 0, +52} px | State-based target |
| `LOOKAHEAD_LERP_FRAMES` | int (locked) | **8 frames** | Lerp rate reciprocal |
| `JUMP_LOOKAHEAD_UP_PX` | int (locked) | **20 px** | Jump apex lookahead |
| `FALL_LOOKAHEAD_DOWN_PX` | int (locked) | **52 px** | Fall lookahead (2.6× asymmetric — landing threats dominant) |

**Output range**: bounded −20..+52. Immediate clamp when EchoLifecycleSM is in `REWINDING`/`DYING` (lifecycle check before movement state; no lerp applied) prevents residual crossing rewind boundary (Pillar 1 DT-CAM-1 0 px drift).

**Worked example** — JUMP → APEX → FALL key frames (per-tick `lerp(y, target, 1/8)`; exponential convergence — *not* linear settle):

| Frame | State | `look_offset.y` (computed, rounded) | % to target |
|---|---|---|---|
| 0 (`jump` entry) | `jump` | 0 (pre-lerp) | 0% |
| 1 | `jump` | **−2.5** | 13% |
| 4 | `jump` | **−8.3** | 41% |
| 8 | `jump` | **−13.1** | 66% |
| 9 (`fall` entry, lerp toward +52) | `fall` | **−5.0** | — (re-targeting from −13.1) |
| 17 (8 ticks into `fall`) | `fall` | **+29.6** | 66% to +52 |
| 24 (16 ticks into `fall`) | `fall` | **+43.7** | 87% |
| 36 (apex-equivalent window) | `fall` | **+50.6** | 97% |

**Note** (Session 22 design-review BLOCKING #2 resolution 2026-05-12): `LOOKAHEAD_LERP_FRAMES = 8` is a *time-constant* (~66% convergence frame count), not a settle frame count. The previous worked example displayed ~1/4-rate convergence values that were incompatible with the formula. INV-CAM-5 ("settle complete before reaching apex") is satisfied by the fact that this time-constant is less than frames_to_apex=36 (8<36) — ~97% convergence at apex.

(Pillar 3 — lookahead secures headroom above ECHO, collage composition does not collapse at jump apex.)

---

### F-CAM-4 — Shake Amplitude Decay (per active event, linear)

```
amplitude_this_frame = amplitude_peak_px × (1.0 − frame_elapsed / duration_frames)
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `amplitude_peak_px` | float | 1..10 px | Peak shake magnitude at event start |
| `frame_elapsed` | int | 0..(duration_frames − 1) | Frames elapsed since event start |
| `duration_frames` | int | 6..18 | Event lifetime |
| `amplitude_this_frame` | float | 0..amplitude_peak_px | Scalar amplitude fed to F-CAM-5 |

**Output range**: 0 when `frame_elapsed == duration_frames` (event removed from active_events before this frame — disappears before render). Monotonically decreasing.

**Worked example** — `shot_fired` (peak=2, duration=6):

| `frame_elapsed` | `amplitude_this_frame` |
|---|---|
| 0 | 2 × (1 − 0/6) = **2.000** |
| 1 | 2 × (1 − 1/6) = **1.667** |
| 2 | 2 × (1 − 2/6) = **1.333** |
| 3 | 2 × (1 − 3/6) = **1.000** |
| 4 | 2 × (1 − 4/6) = **0.667** |
| 5 | 2 × (1 − 5/6) = **0.333** |
| 6 | event removed (≥ duration) |

---

### F-CAM-5 — Shake Vector-Sum + Length Clamp

```
shake_offset = Vector2.ZERO
for each active event e:
    decay = 1.0 − (frame_elapsed_e / duration_frames_e)
    rng.seed = (current_frame × 1_000_003) XOR event_seed_e          # F-CAM-6
    dir = Vector2(rng.randf_range(−1, 1), rng.randf_range(−1, 1)).normalized()
    shake_offset += dir × amplitude_peak_px_e × decay
shake_offset = shake_offset.limit_length(MAX_SHAKE_PX)               # = 12 px
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `shake_offset` | Vector2 | length ≤ 12 px | Final displacement to be written to `camera.offset` |
| `dir` | unit Vector2 | normalized | Per-event, per-frame RNG-seeded direction |
| `MAX_SHAKE_PX` | int (locked) | **12 px** | Global length clamp |

**Output range**: always length ≤ 12 px (Pillar 2 determinism; Pillar 3 readability floor preserved).

**Worked example** — `shot_fired` (frame 0, amplitude=2) + `player_hit_lethal` (frame 0, amplitude=6) simultaneously active. Worst-case collinear sum = 2 + 6 = 8 px < 12 → **clamp not engaged**. Scenario where clamp engages: `boss_killed` (10) + `player_hit_lethal` (6) → sum = 16 → **clamped to 12 px**. A single event can never reach the clamp alone (INV-CAM-4).

---

### F-CAM-6 — Shake RNG Seed → Direction Unit Vector

```
rng.seed = (current_frame × 1_000_003) XOR event_seed
direction = Vector2(rng.randf_range(−1, 1), rng.randf_range(−1, 1)).normalized()
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `current_frame` | int (≥ 0) | `Engine.get_physics_frames()` monotonic counter | ADR-0003 determinism clock |
| `1_000_003` | int (prime constant) | — | Avalanche multiplier; avoids cycle-1 patterns at small frame values |
| `event_seed` | int (≥ 0) | per-camera-instance monotonic counter, incremented +1 per emit handler | Per-event unique seed |
| `direction` | unit Vector2 | normalized | Determined by (current_frame, event_seed) pair |

**Output range**: `direction.length() ≈ 1.0`. (Probability of `(0,0)` = probability of exact 0 from `randf_range` — negligible in Godot PCG implementation; `.normalized()` returns zero on zero-vector input, so worst case is 1 frame of zero shake — graceful.)

**Reproducibility verified**: `frame=100`, `event_seed=0` → `rng.seed = 100 × 1_000_003 XOR 0 = 100_000_300`. Determined by only two integers — Engine.get_physics_frames + per-event counter — so same build + same input sequence → bit-identical direction (Pillar 2 ADR-0003 R-RT3-02 guarantee). `hash()` function explicitly not used — no patch-stability guarantee in Godot 4.6 (R-C1-7 + gameplay-programmer verified 2026-05-12).

---

### F-CAM-7 — Settle Time for Position Smoothing (reference formula)

```
frames_to_settle = ceil(log(ε / δ) / log(1 − speed × delta))
```

| Variable | Type | Description |
|---|---|---|
| `δ` | float | Initial offset to target (px) |
| `ε` | float | Tolerance — frames to come within ε px (px) |
| `speed` | float | `position_smoothing_speed` (32.0 Tier 1 default) |
| `delta` | float | `_physics_process` delta (1/60 ≈ 0.01667 s @ 60 Hz) |

**Worked example** — `δ = 64 px` (DEADZONE_HALF_X step), `ε = 1 px`, `speed = 32.0`, `delta = 1/60`:
- `1 − 32 × 0.01667 = 1 − 0.5333 = 0.4667` per frame multiplier
- `log(1/64) / log(0.4667) = log(0.0156) / log(0.4667) ≈ −4.16 / −0.762 ≈ 5.46`
- `ceil(5.46) = 6` frames (practically, residual at 5-frame mark ≈ `64 × 0.4667^5 ≈ 0.9 px` — below visual detection threshold).

This formula is the justification for the R-C1-11 `position_smoothing_speed = 32.0` choice (INV-CAM-3 cross-knob invariant verified).

---

### G.3 Cross-Knob Invariants

These invariants specify the relationships the values exposed in G (Tuning Knobs) must maintain to keep gameplay intact. Candidates for CI / boot-time asserts.

| ID | Invariant | Formal condition | Serves Pillar |
|---|---|---|---|
| **INV-CAM-1** | `shot_fired` shake fully decays before next shot | `shot_fired_duration_frames (6) < FIRE_COOLDOWN_FRAMES (10)` — 4-frame natural gap; micro shake accumulation on sustained fire structurally blocked | P2 (predictability), P3 (readability) |
| **INV-CAM-2** | Peak shake does not intrude on readable third | `MAX_SHAKE_PX (12) << viewport_width / 6 (=213 px)` — even when worst-case clamp engages, boss silhouette stays within readable third center (DT-CAM-2 verified) | P3 (collage signature) |
| **INV-CAM-3** | Smoothing settles within deadzone trigger window | `frames_to_settle(δ=64, ε=1, speed=32, delta=1/60) ≤ 6` (F-CAM-7) — camera does not lag player by more than 6 frames after deadzone cross | P1 (sub-second restart compliant), P2 |
| **INV-CAM-4** | Single shake event cannot reach clamp alone | All peak {2, 6, 10} < `MAX_SHAKE_PX (12)` — clamp only engages on multi-event collinear worst-case sum | P2, P3 |
| **INV-CAM-5** | Vertical lookahead settles before reaching jump apex | `LOOKAHEAD_LERP_FRAMES (8) < frames_to_apex (=36)` — `frames_to_apex = jump_velocity_initial / gravity_rising × 60 = 480/800 × 60 = 36`. Lookahead settle complete 28 frames before apex → DT-CAM-2 holds | P2, P3 |
| **INV-CAM-6** | Tuning knob safe-range lower bound — prevent designer misconfig (E-CAM-9) | `SHOT_FIRED_DURATION_FRAMES > 0` ∧ `PLAYER_HIT_LETHAL_DURATION_FRAMES > 0` ∧ `BOSS_KILLED_DURATION_FRAMES > 0` ∧ `POSITION_SMOOTHING_SPEED > 0.0` — prevents F-CAM-4 division-by-zero / lerp lock | P2 (production stability) |

**Boot-time assert candidates** (statically verified in `tools/ci/camera_static_check.sh`; registered as acceptance criteria in H.5):
```
assert(shot_fired_duration_frames < FIRE_COOLDOWN_FRAMES)              # INV-CAM-1
assert(MAX_SHAKE_PX × 6 < viewport_width)                              # INV-CAM-2 (integer variant safe against rounding)
assert(LOOKAHEAD_LERP_FRAMES < int(jump_velocity_initial / gravity_rising × 60))  # INV-CAM-5
assert(shot_fired_duration_frames > 0)                                 # INV-CAM-6
assert(player_hit_lethal_duration_frames > 0)                          # INV-CAM-6
assert(boss_killed_duration_frames > 0)                                # INV-CAM-6
assert(position_smoothing_speed > 0.0)                                 # INV-CAM-6
```

## E. Edge Cases

This section specifies corner scenarios not covered by Section C rules and Section D formulas. Each item has a classification tag:

- **[DESIGN-RESOLVED]**: Already resolved by a contract or invariant defined in this GDD.
- **[CROSS-DOC]**: Resolved by another GDD's contract / assert; included in Phase 5 cross-doc batch.
- **[ESCALATE-TO-C]**: This item triggers a Section C rule amendment (already applied this session).
- **[DEFERRED-PLAYTEST]**: Requires Tier 1 playtest data.
- **[WONT-FIX-COSMETIC]**: Practically impossible to occur, or visual-only.

---

**E-CAM-1 (wall-pinch deadzone drift)** [ESCALATE-TO-C / **applied 2026-05-12** + amended Session 22 BLOCKING #1]: In the original unified `camera = target + look_offset` model, `look_offset.x` risked accumulating directional deficit during wall-pinch, causing reversal lag. **In the current split-H/V model (DEC-CAM-A5), `look_offset.x` does not exist, so deficit accumulation is structurally impossible** — Godot built-in `limit_*` clamp absorbs each tick's advance. **Resolution**: R-C1-3 limit-boundary guard retained as defense-in-depth (if camera is clamped and delta_x is in clamp direction, skip advance) — protection against Godot clamp failure or limit setter race condition.

**E-CAM-2 (signal dispatch order — umbrella resolution)** [DESIGN-RESOLVED]: All gameplay signals in the same tick are synchronously dispatched in `process_physics_priority` ladder order (Player=0, TRC=1, Damage=2, enemies=10, projectiles=20, Camera=30 — always last). Camera processes signals only after all gameplay sources have settled — this single contract structurally resolves all of E-CAM-3/4/5 below. ADR-0003 R-RT3-05 compliant.

**E-CAM-3 (rewind_completed + boss_killed same frame)** [DESIGN-RESOLVED — cites E-CAM-2]: If both emit in the same tick, dispatch order follows emitter priority (TRC=1 < Damage=2 → `rewind_completed` first). R-C1-9 performs `active_events.clear()` + reset_smoothing() first, then the `boss_killed` handler adds a fresh catharsis shake event. Result: camera has exactly one shake event at rewind end, no cross-contamination.

**E-CAM-4 (rewind_started while boss_killed shake mid-decay)** [DESIGN-RESOLVED]: R-C1-8 sets `is_rewind_frozen = true` → R-C1-2 skips R-C1-1 each tick. Active shake events continue their internal timer countdown but are not reflected visually (R-C1-2 short-circuit). R-C1-9 forcibly calls `active_events.clear()` on `rewind_completed`, discarding all residual decay. No residual shake crosses the rewind boundary — literal implementation of Pillar 1 "the gaze does not rewind".

**E-CAM-5 (scene_post_loaded during rewind freeze)** [DESIGN-RESOLVED]: SM C.2.1 lifecycle emits `scene_post_loaded` only in the POST-LOAD phase, and POST-LOAD does not overlap in time with an in-flight rewind (rewind can only trigger inside ALIVE state). Even if a race occurs, R-C1-10 unconditionally sets `is_rewind_frozen = false` explicitly before performing the snap — safe (defensive — graceful termination on contract violation).

**E-CAM-6 (shot_fired during rewind freeze)** [CROSS-DOC]: Impossible in Tier 1 — Player Shooting #7 C.1 Rule 1 gates `fire` input dispatch only when `EchoLifecycleSM not in REWINDING/DYING` state. No defensive handler needed on the Camera side — the upstream gate is the contract boundary. **Cross-doc obligation**: player-shooting.md F.4.2 row must state that Camera #3 depends on the fire gate blocking when `EchoLifecycleSM` is in `REWINDING` or `DYING` state (already registered as Player Shooting #7 F.4.2 row #5 "Camera #3 obligation" — this GDD closes it).

**E-CAM-7 (invalid `limits: Rect2` from scene_post_loaded)** [CROSS-DOC]: `limits.size.x ≤ 0` or `limits.size.y ≤ 0` (zero-size or inverted Rect2) → Camera2D `limit_*` setter receives meaningless values and player immediately escapes the visible world. **Resolution**: add boot-time assert to scene-manager.md C.2.1 before emit — `assert(limits.size.x > 0 and limits.size.y > 0)`. Phase 5 cross-doc batch item (added to C.3.3 table).

**E-CAM-8 (player node freed while camera still ticking)** [DESIGN-RESOLVED]: In Tier 1, Camera2D is a sibling of PlayerMovement at stage root. Scene Manager C.2.4 teardown atomically frees the entire stage subtree — Camera is freed in the same tree-free call as PlayerMovement. No window where Camera ticks with a freed `target`. `is_instance_valid()` defensive code is for Tier 2+ multi-scene architecture (not needed in Tier 1).

**E-CAM-9 (designer misconfig — `duration_frames ≤ 0`, `position_smoothing_speed = 0`)** [DESIGN-RESOLVED via **INV-CAM-6**]: F-CAM-4 division-by-zero on 0 or negative `duration_frames`; `position_smoothing_speed = 0` gives lerp factor 0 → camera permanently locked. Both are designer typos. **New invariant INV-CAM-6** added (G.3 table + `tools/ci/camera_static_check.sh` boot-time assert):

```
assert(SHOT_FIRED_DURATION_FRAMES > 0)
assert(PLAYER_HIT_LETHAL_DURATION_FRAMES > 0)
assert(BOSS_KILLED_DURATION_FRAMES > 0)
assert(POSITION_SMOOTHING_SPEED > 0.0)
```

These 4 asserts align with the "safe range" lower bound for each knob in the G tuning knob definitions.

**E-CAM-10 (event_seed overflow / stray second Camera2D)** [WONT-FIX-COSMETIC]: `event_seed` is a GDScript `int` (64-bit signed). Time to overflow at 6 rps sustained fire @ 60 Hz ≈ 97 billion years — impractical. A stray second Camera2D node calling `make_current()` (debug probe, editor artifact) → original camera signals handled correctly but rendering switches to the second camera. Both are operationally non-issues in Tier 1 single-camera single-instance deployment. No code change needed.

**E-CAM-11 (player position NaN/Inf)** [DESIGN-RESOLVED — upstream contract]: PlayerMovement is a deterministic transform writer per ADR-0003 R-RT3-01; NaN/Inf cannot occur in ADR-0002 PlayerSnapshot serialization (primitive float fields are valid). Camera trusts player.global_position — no separate validation needed. If a Tier 2 enemy/projectile bug brings player to an invalid position, PlayerMovement's boot assert fires first.

**E-CAM-12 (deadzone span > viewport width — Tier 2 risk)** [DEFERRED-PLAYTEST]: Tier 1 viewport_width = 1280, DEADZONE_HALF_X = 64 → deadzone 128 px ≪ 1280, ample safety margin. In Tier 2, if viewport shrinks (options menu letterbox) or deadzone expands, the invariant `2 × DEADZONE_HALF_X < viewport_width` must be maintained — not currently occurring; add to INV-CAM-2 family for review when Tier 2 is introduced.

---

### E.S — Section E Summary

| Edge case | Resolution | Where applied |
|---|---|---|
| E-CAM-1 | Section C R-C1-3 limit-boundary guard | **applied this session 2026-05-12** |
| E-CAM-2..5 | DESIGN-RESOLVED by signal priority ladder + R-C1-2/8/9/10 | No edit needed |
| E-CAM-6 | CROSS-DOC — Player Shooting #7 fire gate (closes F.4.2 #5) | Phase 5 verify (no new edit) |
| E-CAM-7 | CROSS-DOC — scene-manager.md boot assert | **Phase 5 batch — new C.3.3 row** |
| E-CAM-8 | DESIGN-RESOLVED (Tier 1 scope) | — |
| E-CAM-9 | New INV-CAM-6 + `camera_static_check.sh` boot asserts | **G.3 amendment + new tooling deliverable** |
| E-CAM-10 | WONT-FIX-COSMETIC | — |
| E-CAM-11 | DESIGN-RESOLVED — upstream ADR-0003 / ADR-0002 contract | — |
| E-CAM-12 | DEFERRED-PLAYTEST (Tier 2) | Registered as OQ (Section Z) |

## F. Dependencies

### F.1 — Upstream Dependencies (Camera depends on)

| # | System | Status | Interface | Hard / Soft | Description |
|---|---|---|---|---|---|
| 1 | **Scene Manager #2** | Approved (RR7 PASS 2026-05-11) | `scene_post_loaded(anchor: Vector2, limits: Rect2)` signal — **Q2 deferred, Camera #3 first-use trigger** | **HARD** | Camera snap to anchor + stage limit set on checkpoint restart / cold-boot / stage clear. 60-tick budget compliance. |
| 2 | **Player Movement #6** | Approved (re-review 2026-05-11) | `target.global_position` (Vector2 read per tick) | **HARD** | R-C1-1 / R-C1-3 / R-C1-4 all use ECHO position as follow base. ADR-0003 R-RT3-01 (CharacterBody2D + direct transform) compliant. |
| 3 | **State Machine #5** (PlayerMovementSM + EchoLifecycleSM) | Approved (Round 2 + Round 5) | `player_movement_sm.state` (DEC-PM-1 canonical: `idle/run/jump/fall/aim_lock/dead`) + `lifecycle_sm.state` (EchoLifecycleSM: `ALIVE/DYING/REWINDING/DEAD`) | **HARD** | R-C1-4 state-scaled lookahead; `lifecycle_sm` checked first — immediate 0 clamp on `REWINDING`/`DYING`; `jump`/`fall` drive lerp targets. |
| 4 | **Damage #8** | LOCKED for prototype (Round 5 cross-doc S1 fix) | `player_hit_lethal(_cause: StringName)` + `boss_killed(boss_id: StringName)` signals | **HARD** | R-C1-5 shake event start (6 px / 12f and 10 px / 18f respectively). `boss_killed` is damage.md F.4 LOCKED single-source authority. |
| 5 | **Time Rewind #9** | Approved (Round 2 + Round 5 + cross-review B1+B2 fix) | `rewind_started()` + `rewind_completed(player: PlayerMovement, restored_to_frame: int)` signals (canonical signature per W2 housekeeping 2026-05-10) | **HARD** | R-C1-8 freeze + R-C1-9 unfreeze/clear/snap — Pillar 1 "the gaze does not rewind" compliant + DT-CAM-1 verified. |
| 6 | **Player Shooting #7** | Approved (re-review Round 2 2026-05-11) | `shot_fired(direction: int)` signal — Player Shooting F.4.2 row #5 "Camera #3 obligation" registered | **SOFT** | R-C1-5 micro shake (2 px / 6f). Non-essential for normal gameplay — core loop functions even if shake is blocked. P3 polish contribution. |
| 7 | **ADR-0003 (Determinism)** | Accepted 2026-05-09 | `process_physics_priority = 30` slot (next slot in player=0/TRC=1/Damage=2/enemies=10/projectiles=20 ladder) + `Engine.get_physics_frames()` determinism clock + `RandomNumberGenerator` per-event seed | **HARD** | R-C1-7 / R-C1-11 / F-CAM-6 all built on ADR-0003 contract. Shake adopts ADR-0003 strict (cosmetic exemption rejected). |
| 8 | **ADR-0002 (Snapshot 9-field)** | Accepted (Amendment 2 ratified via Player Shooting #7) | **Negative dependency** — Camera state is **not included** in PlayerSnapshot | **HARD** | DEC-CAM-A2 lock; new forbidden pattern `camera_state_in_player_snapshot` (Phase 5 architecture.yaml registration). This decision is the architectural source of B's player fantasy headline "The camera never forgets". |
| 9 | **art-bible.md** | Approved (Session 15 ABA-1..4 applied) | 1280×720 baseline + readable third composition principle | **SOFT** | Readable third definition for preserving Pillar 3 collage signature (INV-CAM-2). Source of DT-CAM-2 verification criterion. |

---

### F.2 — Downstream Dependents (these systems depend on Camera)

| # | System | Status | What they need from Camera | Source GDD |
|---|---|---|---|---|
| 1 | **HUD #13** | Not Started | Camera coordinate system reference (screen-anchored UI vs world-anchored boss HP bar). Camera emits no signal for HUD to subscribe to directly — HUD reads Camera Node's `get_screen_center_position()` or viewport transform directly. | F.4.2 row #1 |
| 2 | **VFX / Particle #14** | Not Started | Screenshake state read (camera.offset) for particle emitter to decide world vs viewport-anchored. Separate timing from Time Rewind Visual Shader #16. | F.4.2 row #2 |
| 3 | **Stage / Encounter #12** | Not Started | Stage scene passes camera's `limits: Rect2` in `scene_post_loaded` payload (queried from stage root just before Scene Manager #2 C.2.1 emit). Stage GDD decides between `Marker2D` `StageBoundsMin`/`StageBoundsMax` or stage root export var pattern. | F.4.2 row #3 |
| 4 | **Boss Pattern #11** | Not Started | Camera zoom or locked-composition request on boss arena entry when Tier 2 introduced — deferred in Tier 1 (DEC-CAM-A4 lock). When Boss GDD is written, review adding `boss_arena_entered(arena_rect: Rect2)` or similar signal via this GDD revision. | F.4.2 row #4 (deferred Tier 2) |
| 5 | **Time Rewind Visual Shader #16** | Not Started | Shader fade timing must align with R-C1-9 `reset_smoothing()` call for ux-designer F3 answer option (c) "shader inherits camera snap" to work. When Shader GDD is written, reference this GDD's `rewind_completed` handler order sequence. | F.4.2 row #5 |

---

### F.3 — Interface Contracts (signal signature lock-ins)

Signal contracts that this Camera #3 GDD locks in with other GDDs:

| Signal | Owner | Producers | Consumers | Status |
|---|---|---|---|---|
| `scene_post_loaded(anchor: Vector2, limits: Rect2)` | Scene Manager #2 | Scene Manager only | **Camera #3 first** (Tier 1) → Stage #12 (Tier 2) → HUD #13 (Tier 2) | **Confirmed by this GDD authoring** — signal added to scene-manager.md via Phase 5 cross-doc batch (Q2 deferral closure) |
| `shot_fired(direction: int)` | Player Shooting #7 | Player Shooting only | Camera #3, Audio #4 (deferred), VFX #14 (deferred) | Approved 2026-05-11 (player-shooting.md C.3 + F.4.2 #5) |
| `player_hit_lethal(_cause: StringName)` | Damage #8 | Damage only | Camera #3, Time Rewind #9, EchoLifecycleSM | Approved (damage.md DEC-1 1-arg signature) |
| `boss_killed(boss_id: StringName)` | Damage #8 | Damage F.4 LOCKED single-source | Camera #3, Scene Manager #2, Time Rewind #9 | Approved (damage.md F.4 LOCKED + AC-13 BLOCKING) |
| `rewind_started()` | Time Rewind #9 | TR only | Camera #3, VFX #14 (deferred), Audio #4 (deferred) | Approved (TR Rule 4 + AC-A3) |
| `rewind_completed(player: PlayerMovement, restored_to_frame: int)` | Time Rewind #9 | TR only | Camera #3, VFX #14 (deferred) | Approved (TR canonical signature W2 housekeeping 2026-05-10) |

---

### F.4 — Cross-Doc Reciprocal Obligations

#### F.4.1 — Phase 5 Cross-Doc Batch (BLOCKING for Approved promotion gate)

Camera #3 Designed-state promotion has the following cross-doc batch application as a BLOCKING gate, per scene-manager.md F.4.1 RR4 precedent. Edits closing the `scene_post_loaded` signal contract where this GDD is the first-use trigger + new architecture/entities registry entries + host GDD systems-index update:

**See C.3.3 table** — 10-row batch (9 cross-doc edits + 1 systems-index row update). Includes Rect2 validation assert from E-CAM-7.

#### F.4.2 — Future-GDD Obligations (obligations when downstream systems are written)

Obligations that the following GDDs must fulfill to align with Camera #3 contract when written for Tier 1 and beyond:

| # | Target GDD | Obligation | Trigger |
|---|---|---|---|
| 1 | **HUD #13** | HUD GDD must: (a) choose Camera Node reference pattern (expose via autoload vs `get_tree().get_first_node_in_group("camera")`); (b) classify screen-anchored vs world-anchored UI elements; (c) handle any new signal requests from Camera via this GDD revision | When HUD GDD is written |
| 2 | **VFX / Particle #14** | VFX GDD must: (a) define screenshake offset (camera.offset) consume pattern; (b) specify world-anchored vs viewport-anchored particle emitter classification contract; (c) coordinate timing with Time Rewind Visual Shader #16 | When VFX GDD is written |
| 3 | **Stage / Encounter #12** | Stage GDD must: (a) decide `limits: Rect2` exposure pattern at stage root (export var `stage_camera_limits: Rect2` or `Marker2D` child node query); (b) specify contract for Scene Manager to extract Rect2 from stage root and pass it in `scene_post_loaded` payload | When Stage GDD is written |
| 4 | **Boss Pattern #11** (Tier 2) | When Boss GDD requests camera zoom/lock behavior on boss arena entry, add new signal contract such as `boss_arena_entered(arena_rect: Rect2)` via this Camera #3 GDD revision | When Tier 2 is introduced |
| 5 | **Time Rewind Visual Shader #16** | Shader GDD must specify that shader fade timing is synchronized with this Camera #3 R-C1-9 `rewind_completed` handler order sequence (unfreeze → clear shake → reset_smoothing) | When Shader GDD is written |
| 6 | **Player Shooting #7** | (status: **Already done** — Player Shooting F.4.2 row #5 "Camera #3 obligation" registration complete 2026-05-11 Round 2). This GDD closes it — Phase 5 verify no edit. | — |

---

### F.5 — Bidirectional Consistency Check

Verify that F.1 (upstream) of this GDD and F.2 (downstream Camera #3 row) of all upstream GDDs are consistent (prevents one-directional dependency — design-docs.md rule "Dependencies must be bidirectional"):

| Upstream | Camera #3 F.1 row | Their F.2 Camera #3 row exists? |
|---|---|---|
| Scene Manager #2 | F.1 #1 (HARD) | ✅ scene-manager.md F.2 row Camera #3 (already listed); Phase 5 batch flips status "Q2 deferred" → "resolved (Camera #3 first-use)" |
| Player Movement #6 | F.1 #2 (HARD) | ✅ player-movement.md F.2 row Camera #3 added 2026-05-12 (Phase 5 batch) — read-only `target.global_position` per-tick + camera.md F.1 #2 reciprocal explicit |
| State Machine #5 | F.1 #3 (HARD) | ✅ state-machine.md F.2 row Camera #3 added 2026-05-12 (Phase 5 batch) — read-only state subscriber pattern (Player Shooting #7 row precedent), `transition_to()` call forbidden + 6-signal subscribe contract reciprocal |
| Damage #8 | F.1 #4 (HARD) | ✅ damage.md F.2 row Camera #3 added 2026-05-12 (Phase 5 batch) — `player_hit_lethal` (6 px / 12f impact shake) + `boss_killed` (10 px / 18f catharsis shake) consumer; cause taxonomy ignored |
| Time Rewind #9 | F.1 #5 (HARD) | ✅ time-rewind.md Downstream Dependents row Camera #3 added 2026-05-12 (Phase 5 batch) — `rewind_started` freeze + `rewind_completed` clear/snap cascade; DT-CAM-1 0 px drift verification path |
| Player Shooting #7 | F.1 #6 (SOFT) | ✅ player-shooting.md F.4.2 row #5 Camera #3 obligation already registered (Round 2 2026-05-11) |
| ADR-0003 | F.1 #7 (HARD) | ✅ Camera #3 not explicitly listed in ADR-0003 "Enables" section (only Player Movement, Damage, Enemy AI, Player Shooting, Boss listed) — but camera determinism contract is covered by ADR-0003 R-RT3-02 / R-RT3-05. No ADR revision needed (downstream relationship implicit). |
| ADR-0002 | F.1 #8 (HARD, negative dep) | ✅ Closed by registering new forbidden pattern `camera_state_in_player_snapshot` in Phase 5 architecture.yaml |

**Phase 5 cross-doc batch (landed 2026-05-12)**: 4 reciprocity additions above (Camera #3 downstream row added to Player Movement / State Machine / Damage / Time Rewind) + C.3.3 original 10-row = total 14-row batch applied. Bidirectional-dep rule (`.claude/rules/design-docs.md`) satisfied. All F.5 row statuses flipped to ✅.

## G. Tuning Knobs

This section specifies the designer-tunable values exposed by Camera #3. All knobs are exposed to the Godot inspector via `@export` annotation, with defaults recorded in `assets/data/camera.tres` Resource (Tier 1 single instance). Section D's INV-CAM-1..6 invariants define cross-knob constraints — knob value changes must not violate invariants (enforced via boot-time assert).

### G.1 Knob Catalog

#### G.1.1 — Follow Knobs

| Knob | Default | Safe Range | Unit | Effect | Cross-knob constraints |
|---|---|---|---|---|---|
| `DEADZONE_HALF_X` | **64** | 32..128 | px | Horizontal deadzone half-width. Smaller → camera follows ECHO faster (Celeste-tight) / larger → more free movement range (Contra-loose). | INV-CAM-3: affects `position_smoothing_speed` adequacy (larger deadzone = larger step → whether 5-frame settle is possible) |
| `JUMP_LOOKAHEAD_UP_PX` | **20** | 12..32 | px (negative direction) | Amount camera pre-moves upward in viewport during `jump` state. Smaller → less overhead information for ECHO. | — |
| `FALL_LOOKAHEAD_DOWN_PX` | **52** | 32..72 | px (positive direction) | Amount camera pre-moves downward in viewport during `fall` state. Core to run-and-gun landing threat readability. | INV-CAM-5: lookahead settle complete before reaching apex |
| `LOOKAHEAD_LERP_FRAMES` | **8** | 4..16 | frames | Time to complete lookahead lerp on state entry/exit. Smaller → snappier / larger → more cinematic. | INV-CAM-5: `< frames_to_apex (=36)` |
| `POSITION_SMOOTHING_SPEED` | **32.0** | 16.0..64.0 | exponential decay rate | `position_smoothing_speed` Godot 4.6 Camera2D built-in. Smaller → more lag, larger → snappier. | INV-CAM-3: 64 px step ≤ 5 frame settle; INV-CAM-6: `> 0.0` |

#### G.1.2 — Shake Knobs

| Knob | Default | Safe Range | Unit | Effect | Cross-knob constraints |
|---|---|---|---|---|---|
| `MAX_SHAKE_PX` | **12** | 6..20 | px | Global shake length clamp (F-CAM-5). Smaller → readability priority, larger → impact priority. | INV-CAM-2: `× 6 < viewport_width (=1280)` ⇒ ≤ 213 readable third |
| `SHOT_FIRED_PEAK_PX` | **2** | 1..3 | px | Micro-vibration peak amplitude. | INV-CAM-4: `< MAX_SHAKE_PX` |
| `SHOT_FIRED_DURATION_FRAMES` | **6** | 3..9 | frames | Micro-vibration lifetime. Shorter → sustained fire readability priority. | INV-CAM-1: `< FIRE_COOLDOWN_FRAMES (=10)`; INV-CAM-6: `> 0` |
| `PLAYER_HIT_LETHAL_PEAK_PX` | **6** | 4..8 | px | 1-hit lethal impact shake peak. Strength of death catharsis signal. | INV-CAM-4: `< MAX_SHAKE_PX` |
| `PLAYER_HIT_LETHAL_DURATION_FRAMES` | **12** | 6..18 | frames | Impact shake lifetime. | INV-CAM-6: `> 0` |
| `BOSS_KILLED_PEAK_PX` | **10** | 8..12 | px | Boss-kill catharsis shake peak. Strongest single event. | INV-CAM-4: `< MAX_SHAKE_PX (=12)` (default 10 / cap 12 — 2 px headroom) |
| `BOSS_KILLED_DURATION_FRAMES` | **18** | 12..30 | frames | Boss-kill shake lifetime. Tier 1 catharsis 0.3 s duration. | INV-CAM-6: `> 0` |

#### G.1.3 — Locked (Tier 1 — not tunable)

| Knob | Locked Value | Reason | Tier 2 review |
|---|---|---|---|
| `zoom` | `Vector2(1.0, 1.0)` | DEC-CAM-A4 lock — Pillar 5 (small successes) + art-bible 1280×720 baseline compliant | Unlock this lock when Tier 2 boss zoom is introduced; hook defined in Boss Pattern #11 GDD |
| `process_callback` | `CAMERA2D_PROCESS_PHYSICS` | godot-specialist V2 — `IDLE` mode is 1-tick out-of-phase with player transform → breaks rewind snap | Tier 2 unchanged (deterministic core) |
| `process_physics_priority` | `30` | ADR-0003 ladder slot (player=0, TRC=1, Damage=2, enemies=10, projectiles=20). Camera calculates after all gameplay sources have settled | Maintain 30 even when Tier 2 enemy AI is added (40 free for future systems) |
| `position_smoothing_enabled` | `true` | gameplay-programmer Q2 — use single `reset_smoothing()` snap path instead of toggle | Tier 2 unchanged |

---

### G.2 Tuning Resource Pattern (Godot 4.6)

```gdscript
class_name CameraTuning extends Resource

@export_range(32, 128) var deadzone_half_x: int = 64
@export_range(12, 32)  var jump_lookahead_up_px: int = 20
@export_range(32, 72)  var fall_lookahead_down_px: int = 52
@export_range(4, 16)   var lookahead_lerp_frames: int = 8
@export_range(16.0, 64.0, 0.5) var position_smoothing_speed: float = 32.0

@export_range(6, 20)   var max_shake_px: int = 12
@export_range(1, 3)    var shot_fired_peak_px: int = 2
@export_range(3, 9)    var shot_fired_duration_frames: int = 6
@export_range(4, 8)    var player_hit_lethal_peak_px: int = 6
@export_range(6, 18)   var player_hit_lethal_duration_frames: int = 12
@export_range(8, 12)   var boss_killed_peak_px: int = 10
@export_range(12, 30)  var boss_killed_duration_frames: int = 18
```

Camera node references via `@export var tuning: CameraTuning = preload("res://assets/data/camera.tres")`. Can be swapped in inspector to an alternate tuning Resource other than default `camera.tres` (Tier 2 difficulty toggle or Steam Deck-specific tuning slot).

---

### G.3 Cross-Knob Invariants — already specified in D.G.3 (INV-CAM-1..6)

The cross-knob constraints column in G.1 references the D.G.3 invariant table. When a knob value change causes an invariant violation, a boot-time assert fires — `tools/ci/camera_static_check.sh` verifies 0 emits on release fixture (registered as acceptance criteria in H.5).

**Intended interactions between knobs** (relationships where changing knob A makes knob B meaningless):

| Knob A change | Knob B impact |
|---|---|
| `DEADZONE_HALF_X` ↑ | `POSITION_SMOOTHING_SPEED` needs re-tuning — larger deadzone = larger step → risk of INV-CAM-3 5-frame settle violation |
| `MAX_SHAKE_PX` ↓ | Review all `*_PEAK_PX` proportionally — if peaks hit clamp too often, differentiation is lost |
| `FIRE_COOLDOWN_FRAMES` (owned by Player Shooting #7) ↓ | Re-examine `SHOT_FIRED_DURATION_FRAMES` — risk of INV-CAM-1 violation (micro-shake accumulation on sustained fire) |
| `jump_velocity_initial` / `gravity_rising` (owned by Player Movement #6) changed | Re-examine `LOOKAHEAD_LERP_FRAMES` — risk of INV-CAM-5 `< frames_to_apex` violation |

These 4 dependencies registered as new `interfaces.camera_tuning_dependencies` entry in architecture.yaml (Phase 5 batch).

---

### G.4 Designer Notes

- **First playtest priority tuning candidate**: `FALL_LOOKAHEAD_DOWN_PX` (whether 52 px is appropriate for Steam Deck first-gen 720p screen — DT-CAM-2 can be fine-tuned).
- **Tier 1 unused reserved**: zoom, vertical drag margins (drag_top_margin / drag_bottom_margin Godot built-in unused — R-C1-4's lerp replaces them). Review adding zoom + drag margins when Tier 2 boss arena is introduced.
- **Audio linkage**: this GDD does not expose audio knobs — whether shake intensity aligns with Audio #4's SFX ducking intensity is decided when Audio GDD is written (derived signal such as `amplitude_peak_px` × ducking_coefficient is possible).

## H. Acceptance Criteria

### H.0 Preamble

Total **26 ACs**. Classification: **20 BLOCKING** (Logic 18 / Integration 2) + **6 ADVISORY** (Config 1 / Visual-Feel 5).

**Counting convention**: the 3 shake event types (`shot_fired` / `player_hit_lethal` / `boss_killed`) are consolidated as parameter variants of the same test path and each variant is not counted as a separate AC (AC-CAM-H3-01 parameterized fixture covers all 3). ADVISORY-Visual/Feel ACs (H.X) cannot be automated → manual sign-off required.

**BLOCKING distribution verification** (per coding-standards.md Test Evidence by Story Type):
- Logic BLOCKING (18): H.1×5 + H.2×4 + H.3×4 + H.4×3 + H.5×1 + H.6×1 = 18 ✓
- Integration BLOCKING (2): AC-CAM-H4-04 + AC-CAM-H5-02 = 2 ✓
- ADVISORY (6): AC-CAM-H6-02 (Config) + AC-CAM-HX-01..05 (Visual/Feel) = 6 ✓

---

### H.1 Per-Frame Position + Deadzone (R-C1-1, R-C1-3, F-CAM-1/2, E-CAM-1)

**AC-CAM-H1-01** [BLOCKING-Logic] — **GIVEN** `camera.x = 500`, `look_offset.y = 0`, no shake, `target.x = 565`; **WHEN** `_physics_process(1/60)` runs once; **THEN** `camera.global_position.x == 501.0` AND `look_offset.x == 0.0` (unused per DEC-CAM-A5).
- Covers: R-C1-1 horizontal incremental advance, R-C1-3, F-CAM-2 worked example.
- Test: `tests/unit/camera/test_deadzone_edge_crossing_advances_one_pixel.gd`.
- Mechanism: inject `MockTarget`, set fields, call `_physics_process`, assert `camera.global_position.x == 501` (split-H/V incremental).

**AC-CAM-H1-02** [BLOCKING-Logic] — **GIVEN** `camera.x = 500`, `target.x = 520` (delta=20 ≤ 64); **WHEN** one tick runs; **THEN** `camera.global_position.x == 500.0` (inside deadzone — no advance).
- Covers: R-C1-3 (deadzone inside no-update branch).
- Test: `tests/unit/camera/test_deadzone_inside_no_camera_move.gd`.

**AC-CAM-H1-03** [BLOCKING-Logic] — **GIVEN** active ShakeEvent with `shake_offset == Vector2(5, 3)` (frozen direction via RNG override), `look_offset.y = 10`, `target.x` inside deadzone (no horizontal advance); **WHEN** one tick runs; **THEN** `camera.global_position.y == target.global_position.y + 10` AND `camera.offset == Vector2(5, 3)` (independent assert of vertical write site and offset write site).
- Covers: R-C1-1 split-H/V dual-write contract (load-bearing per F-CAM-1) — shake is not blurred into vertical follow.
- Test: `tests/unit/camera/test_position_and_offset_write_sites_independent.gd`.
- Mechanism: inject deterministic ShakeEvent, override RNG seed for direction control, assert `camera.global_position.y` and `.offset` separately.

**AC-CAM-H1-04** [BLOCKING-Logic] — **GIVEN** `camera.global_position.x == limit_left == 100`, `target.x = 30` (delta_x = −70, |−70| > 64); **WHEN** one tick runs; **THEN** wall-pinch guard fires → `camera.global_position.x == 100` (unchanged; advance skipped).
- Covers: R-C1-3 wall-pinch guard, E-CAM-1 defense-in-depth resolution.
- Test: `tests/unit/camera/test_wall_pinch_guard_no_deficit.gd`.

**AC-CAM-H1-05** [BLOCKING-Logic] — **GIVEN** camera wall-pinched at `limit_left = 100` for 10 ticks (target oscillating left of camera, guard firing each tick), then player reverses right; **WHEN** `target.x` first exceeds `camera.x + DEADZONE_HALF_X (=164)`; **THEN** `camera.global_position.x` advances in the same tick (immediate follow — deficit accumulation is structurally impossible in the split-H/V model, so no reversal lag).
- Covers: R-C1-3 guard verification, E-CAM-1 retrofit fix, F-CAM-2.
- Test: `tests/unit/camera/test_wall_pinch_guard_reversal_no_lag.gd`.

---

### H.2 Vertical Lookahead State Lerp (R-C1-4, F-CAM-3)

**AC-CAM-H2-01** [BLOCKING-Logic] — **GIVEN** player `state=jump` (PlayerMovementSM, DEC-PM-1 canonical), `look_offset.y=0`; **WHEN** 8 ticks have elapsed; **THEN** `look_offset.y` is in the **−13.1 ± 0.5 px** range (per F-CAM-3 time-constant — ~66% convergence to target −20; ≥99% convergence at frame ~36 ≈ apex).
- Covers: R-C1-4, F-CAM-3 worked example frame 8.
- Test: `tests/unit/camera/test_jump_lookahead_lerp_8frames.gd`.
- Mechanism: `MockPlayerMovementSM.state = &"jump"`, call 8 `_physics_process`, record frame-by-frame look_offset.y.
- Note (Session 22 BLOCKING #2 resolution): previous `−18.7 ± 1.0` tolerance was incorrectly derived from rate 1/4 convergence. Corrected value calculated as `y_n = −20 × (1 − (7/8)^n)`.

**AC-CAM-H2-02** [BLOCKING-Logic] — **GIVEN** player `state=fall` (PlayerMovementSM, DEC-PM-1 canonical), `look_offset.y=0`; **WHEN** 8 ticks have elapsed; **THEN** `look_offset.y` is in the **+34.1 ± 0.5 px** range (per F-CAM-3 time-constant — ~66% convergence to target +52).
- Covers: R-C1-4 `fall` branch, F-CAM-3.
- Test: `tests/unit/camera/test_fall_lookahead_lerp_8frames.gd`.
- Note (Session 22 BLOCKING #2 resolution): previous `≥ +47.0` (≥90%) tolerance was incorrectly derived from rate 1/4 convergence; corrected formula `y_n = +52 × (1 − (7/8)^n)`.

**AC-CAM-H2-03** [BLOCKING-Logic] — **GIVEN** look_offset.y == −15.0 (mid-jump lerp), EchoLifecycleSM transitions to `REWINDING`; **WHEN** one tick runs; **THEN** `look_offset.y == 0.0` (immediate clamp, no lerp applied).
- Covers: R-C1-4 lifecycle REWINDING immediate clamp, DT-CAM-1 prerequisite.
- Test: `tests/unit/camera/test_rewind_state_clamps_lookahead_immediately.gd`.

**AC-CAM-H2-04** [BLOCKING-Logic] — **GIVEN** look_offset.y == +30.0, EchoLifecycleSM transitions to `DYING`; **WHEN** one tick runs; **THEN** `look_offset.y == 0.0`.
- Covers: R-C1-4 lifecycle DYING immediate clamp.
- Test: `tests/unit/camera/test_dying_state_clamps_lookahead_immediately.gd`.

---

### H.3 Shake — Decay, Sum-Clamp, RNG Determinism (R-C1-5/6/7, F-CAM-4/5/6)

**AC-CAM-H3-01** [BLOCKING-Logic] — **GIVEN** `shot_fired` ShakeEvent (peak=2, duration=6) at frame F=0; **WHEN** frame_elapsed=3; **THEN** `amplitude_this_frame == 1.0` (= 2 × (1 − 3/6)). Parameterized for `player_hit_lethal` (peak=6, duration=12, elapsed=6 → 3.0) + `boss_killed` (peak=10, duration=18, elapsed=9 → 5.0) — covers all 3 types.
- Covers: R-C1-5 timer pool, F-CAM-4 linear decay.
- Test: `tests/unit/camera/test_shake_linear_decay_midpoint.gd`.
- Mechanism: GUT `parameterize` pattern — 3 variants same fixture, assert amplitude_this_frame at each frame_elapsed.

**AC-CAM-H3-02** [BLOCKING-Logic] — **GIVEN** `boss_killed` (peak=10, frame_elapsed=0) + `player_hit_lethal` (peak=6, frame_elapsed=0) simultaneously active, RNG direction overridden to collinear (1, 0) worst-case; **WHEN** one tick runs; **THEN** `camera.offset.length() <= MAX_SHAKE_PX (=12)`.
- Covers: R-C1-6 sum-clamp, F-CAM-5 worked example, INV-CAM-4.
- Test: `tests/unit/camera/test_shake_sum_clamp_multi_event.gd`.
- Mechanism: inject two events, guarantee direction determinism via RNG override, assert .offset.length().

**AC-CAM-H3-03** [BLOCKING-Logic] — **GIVEN** event_seed=0, current_frame=100; **WHEN** seed formula `(100 × 1_000_003) XOR 0` computed twice; **THEN** the two resulting direction vectors are bit-identical (component-wise equality assert).
- Covers: R-C1-7 patch-stable formula, F-CAM-6, ADR-0003 R-RT3-02.
- Test: `tests/unit/camera/test_shake_rng_determinism_same_seed_same_direction.gd`.
- Mechanism: call seed formula twice with same input, extract normalized direction from each, bit-equal assert.

**AC-CAM-H3-04** [BLOCKING-Logic] — **GIVEN** `shot_fired` first emit at frame 0 (active frames 0..5), next `shot_fired` at frame 10 (FIRE_COOLDOWN_FRAMES satisfied); **WHEN** frame 10 arrives; **THEN** frame 0..5 event already removed from active_events (from frame 6); new event at frame 10 starts at fresh peak (no stacking).
- Covers: R-C1-5 event lifecycle, INV-CAM-1 (`shot_fired_duration < FIRE_COOLDOWN`), F-CAM-4 decay-to-removal.
- Test: `tests/unit/camera/test_shot_fired_duration_less_than_cooldown_no_stacking.gd`.

---

### H.4 Rewind Freeze / Unfreeze (R-C1-2/8/9, DT-CAM-1, DT-CAM-3)

**AC-CAM-H4-01** [BLOCKING-Logic] — **GIVEN** `rewind_started` received (is_rewind_frozen=true), player.global_position moved +100 px; **WHEN** 5 ticks have elapsed; **THEN** `camera.global_position` unchanged from last unfrozen tick value.
- Covers: R-C1-2 freeze guard, R-C1-8, Pillar 1 "the gaze does not rewind" literal.
- Test: `tests/unit/camera/test_rewind_freeze_skips_position_update.gd`.

**AC-CAM-H4-02** [BLOCKING-Logic] — **GIVEN** frozen camera at pos P, 2 active shake events, `look_offset.y = −15` (`look_offset.x` always 0 per DEC-CAM-A5); **WHEN** `rewind_completed(player, restored_to_frame)` received; **THEN** all following fields pass simultaneously in the same tick:
  (a) `is_rewind_frozen == false`
  (b) `active_events.size() == 0`
  (c) `shake_offset == Vector2.ZERO`
  (d) `camera.offset == Vector2.ZERO`
  (e) `look_offset == _compute_initial_look_offset(player)` — i.e. `look_offset.x == 0.0` AND `look_offset.y == _target_y_for_state(player.movement_sm.state)` (R-C1-9 inline spec)
  (f) split-H/V: `camera.global_position.x == player.global_position.x` AND `camera.global_position.y == player.global_position.y + look_offset.y`
- Covers: R-C1-9 unfreeze cascade, **DT-CAM-1** 0 px drift trivial verification, Player Fantasy Framing C headline literal, BLOCKING #3 `_compute_initial_look_offset` spec.
- Test: `tests/unit/camera/test_rewind_completed_clears_all_state.gd`.
- Mechanism: inject frozen camera + stale events, call `_on_rewind_completed`, assert fields in single tick (split-H/V separated verification).

**AC-CAM-H4-03** [BLOCKING-Logic] — **GIVEN** `_on_rewind_completed` implementation; **WHEN** GDScript source order inspection; **THEN** `reset_smoothing()` call site is *after* `global_position = ...` assignment site.
- Covers: R-C1-9 call order non-negotiable (gameplay-programmer Q2 verified: reverse order causes lerp residual).
- Test: `tests/unit/camera/test_rewind_completed_reset_smoothing_order.gd`.
- Mechanism: subclass `CameraSystem`, record call index by overriding `reset_smoothing()` + `global_position` setter spy → assert `_global_position_set_index < _reset_smoothing_call_index`.

**AC-CAM-H4-04** [BLOCKING-Integration] — **GIVEN** `player_hit_lethal` emit at frame T; **WHEN** timeline inspected; **THEN** `camera.offset.length() > 0` at frame T (shake starts same frame) AND `rewind_started` not fired before frame T+1.
- Covers: R-C1-5 + DT-CAM-3 ordering — shake fires before rewind UI.
- Test: `tests/integration/camera/test_lethal_shake_before_rewind_ui.gd`.
- Mechanism: integration harness — mock `TimeRewindSystem` + mock `Damage`. Damage emits `player_hit_lethal(T)`, record frame-by-frame `camera.offset` and TR `rewind_started` emit timing, assert temporal ordering.

---

### H.5 Checkpoint Snap (R-C1-10/11/12, F-CAM-7)

**AC-CAM-H5-01** [BLOCKING-Logic] — **GIVEN** `scene_post_loaded(anchor=Vector2(320, 180), limits=Rect2(0, 0, 2560, 720))` received; **WHEN** handler completes; **THEN** in the same tick: `camera.global_position == Vector2(320, 180)`, `limit_left == 0`, `limit_right == 2560`, `limit_top == 0`, `limit_bottom == 720`, `look_offset == Vector2.ZERO`, `shake_offset == Vector2.ZERO`, `active_events.size() == 0`.
- Covers: R-C1-10, R-C1-12.
- Test: `tests/unit/camera/test_scene_post_loaded_snap_and_limits.gd`.

**AC-CAM-H5-02** [BLOCKING-Integration] — **GIVEN** mock SceneManager emits `scene_post_loaded` within 60-tick restart budget; **WHEN** Camera handler runs; **THEN** `Engine.get_physics_frames()` delta between handler entry and completion ≤ 1 (normal case is 0 — completes within same tick).
- Covers: R-C1-10 + R-C1-11 + SM 60-tick budget Pillar 1 compliant.
- Test: `tests/integration/camera/test_scene_post_loaded_within_60tick_budget.gd`.

---

### H.6 Invariants + Boot Asserts (INV-CAM-1..6)

**AC-CAM-H6-01** [BLOCKING-Logic] — **GIVEN** default `assets/data/camera.tres` tuning Resource; **WHEN** `tools/ci/camera_static_check.sh` run on release fixture; **THEN** all 7 asserts pass + script exit code 0:
```
assert SHOT_FIRED_DURATION_FRAMES (6) < FIRE_COOLDOWN_FRAMES (10)        # INV-CAM-1
assert MAX_SHAKE_PX (12) × 6 < viewport_width (1280)                     # INV-CAM-2
assert LOOKAHEAD_LERP_FRAMES (8) < int(480 / 800 × 60) (=36)             # INV-CAM-5
assert SHOT_FIRED_DURATION_FRAMES > 0                                    # INV-CAM-6
assert PLAYER_HIT_LETHAL_DURATION_FRAMES > 0                             # INV-CAM-6
assert BOSS_KILLED_DURATION_FRAMES > 0                                   # INV-CAM-6
assert POSITION_SMOOTHING_SPEED > 0.0                                    # INV-CAM-6
```
- Covers: INV-CAM-1, INV-CAM-2, INV-CAM-5, INV-CAM-6 (static verification of 4 invariants).
- Test: `tools/ci/camera_static_check.sh` (PM #6 `pm_static_check.sh` pattern compliant). CI gate before manual QA hand-off.

**AC-CAM-H6-02** [ADVISORY-Config] — **GIVEN** designer creates an arbitrary tuning Resource variant within G.1 safe range (including boundary values — min/max); **WHEN** game boots in Godot editor; **THEN** no GDScript runtime assert fires + no boot error/warning log in Godot output panel.
- Covers: INV-CAM-6 boot-time enforcement, E-CAM-9 designer misconfig prevention.
- Test: Smoke check — load alternate `.tres` boundary fixtures (low + high) → manual editor boot.

---

### H.X ADVISORY — Visual/Feel Sign-Off Items (cannot be automated, manual sign-off required)

**AC-CAM-HX-01** [ADVISORY-Visual] — Pillar 3 collage signature aesthetic — **WHEN** Tier 1 first playtest screenshots (peak shake frame at `boss_killed`); **THEN** art-director sign-off: boss silhouette is within readable third (±213 px center) and collage composition readability is not broken.
- Covers: DT-CAM-2 aesthetic half. AC-CAM-H3-02 verifies spatial math as BLOCKING; this AC is perceptual verification.
- Evidence: `production/qa/evidence/dt-cam-2-peak-shake-{stage1}.png` + art-director sign-off comment.

**AC-CAM-HX-02** [ADVISORY-Feel] — DT-CAM-3 emotional read — **WHEN** Tier 1 first playtest; **THEN** ≥ 3 testers agree on questionnaire item "death shake felt like *the weight of the outcome* (not read as UI chrome)".
- Covers: DT-CAM-3 perceptual half. AC-CAM-H4-04 is BLOCKING for temporal ordering.
- Evidence: `production/qa/evidence/playtest-q-dt-cam-3.md`.

**AC-CAM-HX-03** [ADVISORY-Feel] — Follow smoothness — **WHEN** Tier 1 playtest; **THEN** testers respond negatively to item "the camera felt like it lagged behind the character or felt floaty" (POSITION_SMOOTHING_SPEED=32.0 is appropriate).
- Covers: F-CAM-7 + INV-CAM-3 perceptual side.
- Evidence: `production/qa/evidence/playtest-q-camera-feel.md`.

**AC-CAM-HX-04** [ADVISORY-Feel] — Checkpoint snap perception — **WHEN** playtester perception at restart after death; **THEN** "the screen snapped immediately without cutting" response is dominant.
- Covers: R-C1-10 + DT-CAM-1 perceptual half. AC-CAM-H4-02 is BLOCKING for spatial 0 drift.
- Evidence: `production/qa/evidence/playtest-q-restart-snap.md`.

**AC-CAM-HX-05** [ADVISORY-Visual] — Lookahead asymmetric ratio (52/20) playtest verification — **WHEN** Tier 1 playtest encounter with landing threats (spikes, etc.); **THEN** ≥ 80% of testers do not report dying because they couldn't see the threat just before landing (Pillar 2 — "not dying to luck" compliant).
- Covers: R-C1-4 FALL_LOOKAHEAD_DOWN_PX adequacy. Re-examine at E-CAM-12 Tier 2 viewport change.
- Evidence: `production/qa/evidence/playtest-q-fall-lookahead.md`.

---

### H.7 0.2-Sec Design Test Coverage Map

Each DT-CAM is covered on both sides with ≥ 1 BLOCKING + ≥ 1 ADVISORY:

| DT | Spatial (BLOCKING) | Perceptual (ADVISORY) |
|---|---|---|
| **DT-CAM-1** (0 drift rewind complete) | AC-CAM-H4-02, AC-CAM-H4-03, AC-CAM-H2-03 | AC-CAM-HX-04 |
| **DT-CAM-2** (readable third peak shake) | AC-CAM-H3-02 | AC-CAM-HX-01 |
| **DT-CAM-3** (shake before rewind UI) | AC-CAM-H4-04 | AC-CAM-HX-02 |

---

### H.8 Test Deliverables

**(a) Unit test files** (`tests/unit/camera/`):

1. `test_deadzone_edge_crossing_advances_one_pixel.gd`
2. `test_deadzone_inside_no_camera_move.gd`
3. `test_position_and_offset_write_sites_independent.gd`
4. `test_wall_pinch_guard_no_deficit.gd`
5. `test_wall_pinch_guard_reversal_no_lag.gd`
6. `test_jump_lookahead_lerp_8frames.gd`
7. `test_fall_lookahead_lerp_8frames.gd`
8. `test_rewind_state_clamps_lookahead_immediately.gd`
9. `test_dying_state_clamps_lookahead_immediately.gd`
10. `test_shake_linear_decay_midpoint.gd`
11. `test_shake_sum_clamp_multi_event.gd`
12. `test_shake_rng_determinism_same_seed_same_direction.gd`
13. `test_shot_fired_duration_less_than_cooldown_no_stacking.gd`
14. `test_rewind_freeze_skips_position_update.gd`
15. `test_rewind_completed_clears_all_state.gd`
16. `test_rewind_completed_reset_smoothing_order.gd`
17. `test_scene_post_loaded_snap_and_limits.gd`

**(b) Integration test files** (`tests/integration/camera/`):

1. `test_lethal_shake_before_rewind_ui.gd` — mock `TimeRewindSystem` + mock `Damage` harness
2. `test_scene_post_loaded_within_60tick_budget.gd` — mock `SceneManager` emitter fixture

**(c) CI tooling**:

1. `tools/ci/camera_static_check.sh` — reads `assets/data/camera.tres` and evaluates INV-CAM-1/2/5/6 conditions; exit 1 on violation. CI gate before manual QA hand-off (PM `pm_static_check.sh` pattern compliant).

**(d) Required fixtures / mocks**:

1. `MockTarget` (Node2D, settable `global_position`) — shared by H.1, H.2, H.4 unit tests.
2. `MockPlayerMovementSM` — controllable `.state: StringName` getter; used in H.2 tests.
3. `MockEngine_get_physics_frames` — injects monotone counter via GUT `partial_double` pattern (ADR-0003 determinism). Used in H.3 tests.
4. `MockSceneManagerEmitter` — emits `scene_post_loaded` signal with configurable args (anchor + limits). Used in H.5 integration tests.

**(e) Source path** (project convention compliant):

- `src/gameplay/camera/camera_system.gd` (PM `src/gameplay/player_movement/` pattern compliant — Camera is gameplay layer source). Tier 1 single instance, not autoload.

---

### H.9 Test Evidence by Story Type (project coding-standards.md compliant)

| AC group | Story type | Evidence requirement | Location |
|---|---|---|---|
| AC-CAM-H1..H3, H4-01..03, H5-01, H6-01 (Logic BLOCKING ×18) | Logic | Automated GUT test PASS | `tests/unit/camera/` |
| AC-CAM-H4-04, H5-02 (Integration BLOCKING ×2) | Integration | Mock-harness GUT test PASS | `tests/integration/camera/` |
| AC-CAM-H6-02 (Config ADVISORY ×1) | Config/Data | Smoke check PASS | `production/qa/smoke-{date}.md` |
| AC-CAM-HX-01..05 (Visual/Feel ADVISORY ×5) | Visual/Feel | Screenshot + lead sign-off OR playtester questionnaire | `production/qa/evidence/` |

## Visual / Audio Requirements

This section specifies the contract Camera #3 has at the visual/audio boundary. **Camera owns no visual assets within this GDD scope** (Camera2D is a code node; no textures/materials used). Camera does not own audio events either (Audio #4 owns shake-source SFX; Camera is just the visual response).

### VA.1 — Shake Amplitudes vs Collage Readability (art-director verified 2026-05-12)

Art-director analysis (inline consult this session): Tier 1 amplitude scale (2 / 6 / 10 px vs 1280 px viewport = 0.16% / 0.47% / 0.78% width) is conservative — conservative relative to Vlambeer standard; MAX_SHAKE_PX=12 is ~17× inside the readable third (±213 px). **No changes needed to Section C/G amplitudes**.

**Important architectural confirmation**: art-bible Section 6 collage 3-layer (Base photo / Mid line-art / Top collage-detail) are all world-space geometry. `camera.offset` is a uniform displacement of the entire viewport → no differential displacement between layers → torn-paper edges do **not** read as wobble (no per-element independent movement).

**Micro-shake readability sign-off criterion** (AC-CAM-HX-01 evidence base):
- Freeze `boss_killed` frame at peak shake (frame 1, decay=1.0, offset = 10 px max direction).
- STRIDER sprite (192×128 px from art-bible Section 3) and background collage layer shift by the same vector.
- Distance between torn-paper boundaries changes by 0 pixels.
- **PASS**: layered composition does not decompose even when shaking.

### VA.2 — Tier 2 Zoom Bounds (deferred, but art-direction intent locked now)

Tier 1: `zoom = Vector2(1.0, 1.0)` fixed (DEC-CAM-A4). Zoom activated when Tier 2 boss arena is introduced — this GDD pre-records art-direction intent for Tier 2 work:

| Zoom scenario | Range | Constraint source |
|---|---|---|
| Arena pull-out (boss entry) | `0.85` min | art-bible Principle A: ECHO identifiability — 48 px sprite × 0.85 zoom → ~41 px apparent (passes ≥32 px floor) |
| Boss face push-in (phase transition) | `1.25` max | art-bible Section 3 shape-language: STRIDER 192 px at 1.25× = 18.75% of viewport — within readable third |
| Tier 2 default (normal gameplay) | `1.0` | Tier 1 baseline carry-forward |

**Hard floor** (register as new INV on Tier 2 GDD revision): "ECHO rendered pixel height ≥ 32 px apparent at any Tier 2 zoom level" (art-bible Section 3 thumbnail test). Verified on 720p Steam Deck native.

**Zoom transitions**: tween, not hard cut (Pillar 3 — collage composition must "breathe into" the new frame; hard cut reads as glitch). Exact tween curve/speed decided in Tier 2 GDD revision.

### VA.3 — Ownership Boundary Table (Visual signals Camera does NOT own)

This table explicitly distinguishes often-confused ownership (boundary clarity when writing downstream GDDs):

| Visual signal | Owner | Camera #3 role |
|---|---|---|
| **Color inversion + glitch on rewind** | **Time Rewind Visual Shader #16** (art-bible Section 1 Principle C locked) | Camera does NOT own. Camera's R-C1-9 `reset_smoothing()` call timing synchronizes with shader fade window (ux-designer F3 option (c) — shader inherits camera snap) |
| **Screen flash on `player_hit_lethal`** | **VFX #14** (CanvasLayer top overlay). Damage #8 is signal source, VFX is renderer | Camera does NOT own. No visual overlap with shake — separate channel |
| **Boss arena letterbox bars** (Tier 2) | **VFX #14** (CanvasLayer overlay, screen-space). Avoids camera coupling — single-responsibility | Camera does NOT own. Specified in VFX GDD when Tier 2 is introduced |
| **Particle world-vs-viewport anchoring during shake** | **VFX #14** (polls Camera.offset as readable property). No signal needed — Camera only exposes state | Camera does NOT own. No emit signals in C.3.1 signal matrix |

### VA.4 — Audio Events (Camera is not owner — Audio #4 cross-ref)

All shake-source events within this GDD scope (`shot_fired`, `player_hit_lethal`, `boss_killed`) emit their own SFX, but **Camera #3 does not own audio output**. Audio routing/mixing/ducking is owned by Audio #4 (Tier 1 stub-level, Not Started).

**Reciprocal obligation when Audio #4 GDD is written in future** (F.4.2 row #6 candidate): Audio GDD decides whether to align `shot_fired` SFX amplitude with Camera's shake amplitude (e.g., strengthen SFX ducking when `MAX_SHAKE_PX` is reached). Currently no-op on Camera side.

### VA.5 — Asset Spec Implications (zero assets)

Camera #3 **does not require** the following assets:
- Textures (Camera2D is a code node)
- Materials / shaders (post-processing owned by Shader #16)
- Audio files (owned by Audio #4)
- Animations (Tier 1 zoom fixed; Tier 2 zoom transition uses GDScript Tween)
- Models / meshes (2D)

**Result when running `/asset-spec system:camera`**: empty asset manifest. Review adding separate assets when Tier 2 zoom transition is introduced (e.g., zoom curve resource — built-in `Tween` is sufficient).

### VA.6 — Cross-doc Art-Bible Reciprocal (Phase 5 addition)

Art-director recommends adding "Camera Viewport Contract" subsection to art-bible.md **Section 6 (Environment Design Language)** (inline consult Q4 this session):

> **Camera Composition Contract (Camera System #3 2026-05-12):** Screen-shake moves all layers uniformly via `camera.offset` (post-smoothing). Readable third = viewport horizontal center ±213 px; gameplay-critical collage elements must not be *placed exclusively* outside this band, assuming 12 px MAX_SHAKE_PX displacement. Tier 2 zoom range 0.85–1.25× maintains ECHO apparent height ≥ 32 px (Section 3 thumbnail test).

This amendment adds 1 row to Phase 5 cross-doc batch (augments C.3.3 + F.4.1 batch).

📌 **Asset Spec**: Visual/Audio requirements are defined as **zero new assets** for Tier 1 + art-direction intent for Tier 2 zoom. art-bible is already Approved + ABA-1..4 landed (2026-05-11) → this Camera #3 GDD has no additional asset blockers. `/asset-spec system:camera` expected to return empty manifest (until Tier 2 entry).

## UI Requirements

**Camera #3 does not own UI elements**. Camera2D is an infrastructure node that controls the game world viewport; user interfaces such as HUD/menus/overlays are owned by separate systems.

### UI.1 — UI Surfaces Camera Does NOT Provide

- HUD elements (REWIND token counter, weapon icon, boss HP bar) — **HUD #13** owns.
- Pause/menu overlays — **Menu #18** owns (Anti-Pillar #6: Tier 1 minimal — pause overlay only).
- Story intro 5-line typewriter — **Story Intro Text System #17** owns.
- Boss arena letterbox bars (Tier 2 deferred) — **VFX #14** owns (per VA.3 ownership boundary).
- Screenshot capture UI / share — Steam built-in (F12 default).

### UI.2 — Coordinate Primitives Exposed by Camera (read by HUD etc.)

Primitives downstream UI systems can read from Camera:

| Primitive | Type | Usage |
|---|---|---|
| `camera.global_position` | Vector2 | Read by HUD when calculating position of world-anchored UI (e.g., boss HP bar above boss) |
| `camera.offset` | Vector2 | Shake state read — read by VFX when deciding particle world-vs-viewport anchoring (UI generally does not read) |
| `camera.get_screen_center_position()` | Vector2 (Godot 4.6 built-in) | Viewport center world coord — assists HUD anchoring |
| `camera.get_viewport_rect()` | Rect2 (Godot 4.6 built-in) | Viewport bounds — screen-anchored UI placement |

**HUD #13 obligation** (F.4.2 row #1 compliant): when HUD GDD is written, (a) decide Camera Node reference pattern (`get_tree().get_first_node_in_group("camera")` or autoload exposure vs sibling lookup); (b) classify screen-anchored (CanvasLayer top) vs world-anchored (sibling in stage tree) UI; (c) any new signal requests from Camera handled via this GDD revision.

### UI.3 — UX Flag (NO new ux-spec required)

Camera #3 does not trigger ux-spec authoring — there is no visual UI screen. Run `/ux-design` separately when HUD #13 / Menu #18 / Story Intro #17 GDDs are written. **This GDD does not generate any ux-design obligations**.

## Z. Open Questions

This section specifies decisions not yet resolved in this GDD. Each item has an owner + target resolution timing.

### Z.1 — Closed (this session)

| ID | Question | Resolution | Resolved In |
|---|---|---|---|
| **OQ-CAM-CLOSED-1** | Camera2D vs Phantom Camera vs custom Node2D | stock Camera2D + thin script (`extends Camera2D`) — godot-specialist V1 verified | A.1 DEC-CAM-A1 |
| **OQ-CAM-CLOSED-2** | Whether to include Camera state in PlayerSnapshot | NOT included — ADR-0002 9-field lock maintained (Pillar 1 / B headline) | A.1 DEC-CAM-A2 |
| **OQ-CAM-CLOSED-3** | Shake RNG seed pattern | `(frame × 1_000_003) ^ event_seed` (patch-stable; `hash()` rejected) — gameplay-programmer Q3 + godot-specialist V4 verified | R-C1-7, F-CAM-6 |
| **OQ-CAM-CLOSED-4** | Camera behavior during rewind playback | α-freeze (current — skip R-C1-1 via `is_rewind_frozen` guard) — β-follow breaks DT-CAM-1 with lerp residual | R-C1-8/9, C.2 |
| **OQ-CAM-CLOSED-5** | Stage limit delivery pattern | Add `limits: Rect2` argument to scene_post_loaded signal (single-source atomic delivery) — godot-specialist V5 recommendation adopted | R-C1-10/12, C.3.3 |
| **OQ-CAM-CLOSED-6** | Player Fantasy headline selection | Framing C "The camera never forgets" — creative-director recommendation + player-facing translation of A architectural decision | B.4 DEC-CAM-B1 |
| **OQ-CAM-CLOSED-7** | Shake stacking policy (replace / add-capped / decay-replace) | Add-capped (per-event timer pool + vector-sum + length-clamp 12 px) — fusion of ux-designer F2 + game-designer C.1 | R-C1-6, F-CAM-5 |
| **OQ-CAM-CLOSED-8** | Wall-pinch deadzone drift (E-CAM-1) | Add limit-boundary guard to R-C1-3 (surfaced in systems-designer E.section consult) | R-C1-3 amendment, E-CAM-1 |
| **OQ-CAM-CLOSED-9** | Per-frame position formula contradiction (Session 22 design-review BLOCKING #1) | Split horizontal/vertical model adopted — horizontal incremental advance, vertical target+lookahead. Unified `camera = target + look_offset` is incompatible with deadzone semantics (F-CAM-2 worked example + AC-CAM-H1-01 `camera.x = 501`) | A.1 DEC-CAM-A5, R-C1-1, F-CAM-1, F-CAM-2 |
| **OQ-CAM-CLOSED-10** | F-CAM-3 lerp rate vs worked example numerical inconsistency (BLOCKING #2) | LOOKAHEAD_LERP_FRAMES=8 retained; worked example recalculated with actual rate 1/8 convergence (frame 8 ≈ −13.1; time-constant interpretation). AC-CAM-H2-01/02 tolerances updated | F-CAM-3 worked example, AC-CAM-H2-01/02 |
| **OQ-CAM-CLOSED-11** | `_compute_initial_look_offset(player_node)` undefined (BLOCKING #3) | Inline spec added — `Vector2(0.0, _target_y_for_state(state))` with state→target_y mapping per R-C1-4 (split-H/V compliant) | R-C1-9 inline definition |

### Z.2 — Open / Deferred

| ID | Question | Owner | Target resolution | Priority | Notes |
|---|---|---|---|---|---|
| **OQ-CAM-1** | Tier 1 Steam Deck first-gen real measurement — does POSITION_SMOOTHING_SPEED=32.0 feel visually laggy or floaty? INV-CAM-3 guarantees spatial safety but perceptual is unverified | game-designer + ux-designer | Tier 1 Week 1 playtest | MEDIUM | Collect AC-CAM-HX-03 evidence |
| **OQ-CAM-2** | FALL_LOOKAHEAD_DOWN_PX=52 adequacy — is landing threat visibility sufficient? If below 80% threshold, consider raising to 60 px or 70 px | game-designer | Tier 1 Week 1-2 playtest (when landing threat encounter appears) | MEDIUM | AC-CAM-HX-05 evidence; can only change within INV-CAM-5 36-frame limit |
| **OQ-CAM-3** | Tier 2 zoom introduction timing — is zoom-out (0.85×) on boss arena entry valuable? Isn't a simple Cuphead-locked letterbox sufficient? | art-director + game-designer | When Tier 2 Boss Pattern #11 GDD is written | LOW (Tier 2 deferred) | 0.85..1.25× intent recorded in VA.2; this decision owned by Boss GDD |
| **OQ-CAM-4** | Tier 2 zoom transition curve — linear lerp vs ease-in/ease-out? Exact curve for "collage breathes into new frame" | art-director | When Tier 2 zoom is introduced (Boss #11 GDD) | LOW (Tier 2) | VA.2 specifies "tween" but curve not yet determined |
| **OQ-CAM-5** | Camera Node reference pattern — which does HUD #13 use: `get_tree().get_first_node_in_group("camera")` vs autoload exposure vs direct sibling lookup? | ui-designer + ux-designer | When HUD #13 GDD is written | LOW | F.4.2 row #1 / UI.2 deferred to HUD owner |
| **OQ-CAM-6** | Ducking alignment with Audio #4 — should Camera shake amplitude (`shake_offset.length()`) align with SFX ducking intensity? e.g., strengthen BGM ducking at `boss_killed` peak 10 px | audio-director | When Audio #4 GDD is written | LOW | VA.4 reciprocal candidate; currently no-op on Camera side |
| **OQ-CAM-7** | Tier 2 viewport change scenario (viewport shrink on options menu letterbox or multi-room) → DEADZONE_HALF_X re-tuning needed? Re-run INV-CAM-2 `× 6 < viewport_width` verification | game-designer + ux-designer | When Tier 2 viewport scaling is introduced | LOW (Tier 2) | E-CAM-12 carry-over |
| **OQ-CAM-8** | Tier 2 need for new signal such as `boss_arena_entered(arena_rect: Rect2)` — for cases where boss arena triggers only camera lock without stage scene change | game-designer + boss-pattern-designer | When Boss Pattern #11 GDD is written | LOW (Tier 2) | F.4.2 row #4 reciprocal candidate |

### Z.3 — Tension / Untestable

These items are not OQs but ADVISORY criteria that cannot be automated (already enumerated in H.X section):

| ID | Tension | Resolution path |
|---|---|---|
| **T-CAM-1** | Pillar 3 collage signature aesthetic verification cannot be automated | AC-CAM-HX-01 art-director sign-off |
| **T-CAM-2** | DT-CAM-3 emotional read ("felt like the weight of the outcome") cannot be automated | AC-CAM-HX-02 playtester questionnaire |
| **T-CAM-3** | Follow smoothness perceptual feel (absence of "floaty/lag") cannot be automated | AC-CAM-HX-03 playtester feedback |
| **T-CAM-4** | Snap-no-cut perception ("snapped without cutting") cannot be automated | AC-CAM-HX-04 playtester questionnaire |
| **T-CAM-5** | Lookahead asymmetric ratio (52/20) real-world effectiveness — playtest data needed | AC-CAM-HX-05 + OQ-CAM-2 cycle
