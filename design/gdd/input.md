# Input System

> **Status**: Approved · 2026-05-11
> **Author**: User + game-designer / godot-gdscript-specialist / ux-designer / accessibility-specialist (Phase 4 specialists per skill routing)
> **Last Updated**: 2026-05-14 — Menu/Pause #18 approval mirror
> **Implements Pillar**: Pillar 2 (deterministic patterns — primary; input is the sole non-deterministic gameplay surface and must be normalized into per-tick deterministic snapshots), Pillar 4 (5-min rule — secondary; sane Steam Deck defaults out-of-the-box), Pillar 1 (learning tool — supporting; `rewind_consume` delivery latency directly affects forgiveness window)
> **Engine**: Godot 4.6 / GDScript
> **ADR References**: ADR-0003 (determinism strategy — Input must poll in `_physics_process`, no wall-clock APIs)
> **Cross-doc obligations** (resolved in this GDD per F.4.1 of upstream GDDs): player-movement.md C.5.3 (4 items) + F.4.2 (AimLock-jump exclusivity + deadzone) · state-machine.md OQ-SM-3 (`rewind_consume` action name) · time-rewind.md C.3 #1 (gamepad LT + KB+M Shift + single-button-no-chord) · time-rewind.md OQ-15 (Tier 3 chord policy)

## A. Overview

Input is the Foundation layer that normalizes all OS input sources in Echo (KB+M, gamepad, Steam Deck built-in controls) into deterministic InputMap actions, and guarantees that all gameplay consumers read the same deadzone-applied action state inside `_physics_process`. This GDD is the single source of truth for: (a) the action catalog (`move_left/right/up/down`, `jump`, `aim_lock`, `shoot`, `rewind_consume`, `pause`) and each action's detect mode (analog axis · edge-trigger · hold), (b) gamepad stick deadzone policy (Tier 1 = 0.2, single source), (c) Steam Deck-aware default keymap (KB+M + Gamepad + Deck trigger compatible), (d) the gate between the Tier 1 single-button/no-chord constraint and the Tier 3 remap policy.

**ADR-0003 Determinism Contract Conformance**: To avoid violating ADR-0003 `determinism_clock` (all input timestamps are based on `Engine.get_physics_frames()`) and the `process_physics_priority` ladder (player=0 / TRC=1 / enemies=10 / projectiles=20), this system enforces the pattern that gameplay consumers poll `Input.is_action_*` / `Input.get_vector` only at the *Phase 2 input snapshot* point after entering `_physics_process`. Binding gameplay logic to `_input` / `_unhandled_input` callbacks is forbidden because it causes wall-clock latency + timing mismatch (player-movement.md C.6 row 470 ✓ single source) — this GDD promotes that prohibition to a `forbidden_patterns` candidate in architecture.yaml (F.4.1 obligation). UI/menu input is an *explicitly permitted exception* to this prohibition; the separate system (#18 Menu/Pause) uses `_input` callbacks.

**Player Visibility**: Tier 1 = none (automatic default mapping); Tier 3 = indirect (remapping menu #23, Anti-Pillar #6 deferred). Players *experience* Input through PM's jump-buffer forgiveness (C.5.2, 6 frames), SM's `rewind_consume` input window (D.2, `B + D = 16 frames`), and Pillar 4 5-min-rule immediate core-loop entry — Input is the *foundation* of that experience, not the *subject*.

**What This GDD Does *Not* Own** (single source for each item):
- `jump_buffer_frames` / `coyote_frames` time windows → player-movement.md C.5.2 + G
- `rewind_consume` input window predicate (`F_input ≥ F_lethal − B`) → state-machine.md D.2 + time-rewind.md Rule 5
- `pause` swallow policy (which SM states suppress it) → state-machine.md C.2.2 O2
- Shooting/aiming fire logic → Player Shooting #7
- Sprite2D directional visualization, animation, VFX, audio responses → each consumer GDD
- Input remapping UI widget itself → System #23 (Tier 3, Anti-Pillar #6)

**Tier Scope**:
- **Tier 1**: 9 actions × 2 device default mappings (KB+M + gamepad, Steam Deck auto-compatible) + 0.2 deadzone + polling discipline + gameplay/UI callback separation.
- **Tier 2**: Area affected by Easy/Hard toggle (System #20 Difficulty Toggle is owner — Input changes token count only, action mapping unchanged).
- **Tier 3**: Full remapping + Accessibility (Anti-Pillar #6, Systems #23/#24 owner). This GDD only specifies the invariant that Tier 3 permissions *do not break Tier 1 determinism*.

**Risks and Concerns**: (a) Steam Deck 1st-gen stick drift (official RMA 0.05–0.18 raw range) may conflict with the 0.2 deadzone lower bound — Tier 1 verification required (OQ); (b) Godot 4.6 SDL3 gamepad driver (4.5+) trigger axis semantics unverified — `JOY_AXIS_TRIGGER_LEFT` threshold 0.5 (time-rewind.md C.3 #1 acceptance obligation) regression test required (OQ); (c) forward-compat definition between the Tier 1 single-button-no-chord constraint and the Tier 3 chord remap policy (OQ-15 reconciliation).

## B. Player Fantasy

> Input is invisible on the gameplay surface, but the moment this system breaks, every promise Echo makes breaks with it. This section separately specifies what Input promises *to the player* (B.1) and what it promises *to consumer systems* (B.2). Follows the Foundation layer convention (state-machine.md B "systemic invariant" pattern).

### B.1 The Pact — Intent Is Sacred

This is a promise the player never sees, but it is the heaviest promise of all. **Pillar 2 ("luck is the enemy; every death is the player's mistake")** is only true when Input guarantees that *not a single input frame is ever lost, anywhere, anytime*.

If a player dies to a boss and misses the token timing by 2 frames and dies again, that death is *the player's mistake* — Pillar 2's promise holds. But if Input silently dropped a single input frame, the same-looking death becomes *a betrayal by the system*. Pillar 2 instantly becomes false.

This system's fantasy is *never letting that falsehood occur*. The reason a player doesn't put down their controller after dying and tries again is that they *trust their own mistake*. That trust is built or broken every frame in the Input layer.

> **Anchor moment**: 5th attempt learning a boss pattern. The player presses LT (`rewind_consume`) 2 frames too late after the boss attack. The character dies. The player doesn't curse at the screen. They say *"I was too slow"* — and on the next attempt, press 1 frame earlier. That *statement* determines whether Pillar 2 is true. Input's invariant is what makes that statement always accurate.

### B.2 The Cascade — Same Frame, Same Truth

Input provides *the same input truth during the same physics frame* to multiple consumers (PM #6, SM #5, TRC #9, Player Shooting #7, Menu #18). This unity is the foundation of the ADR-0003 determinism contract and all higher-level invariants.

**Concrete cascade — one `rewind_consume` press**:
- PM polls in `_physics_process` Phase 2 (jump_buffer registration possible — player-movement.md D.3 Formula 5).
- TRC polls the same input value in the `process_physics_priority=1` slot.
- SM `AliveState`/`DyingState` observes the same value in `physics_update` → updates `_rewind_input_pressed_at_frame` (state-machine.md D.2).
- When Damage emits `lethal_hit_detected`, SM's D.2 predicate evaluates *the same input all three consumers saw* in the same emit cycle.

If the three consumers see different truths, the 16-frame `rewind_consume` window (`B + D = 4 + 12`, state-machine.md D.2 + time-rewind.md Rule 5) collapses. This system's invariant is that *no two consumers ever see different input truth within the same frame*.

**Pillar 4 (5-min rule) derived fantasy**: As a *byproduct* of the above invariant, the player moves ECHO immediately after starting the game without going through any menus, remapping, or device recognition screens. Turn on Steam Deck and get the first jump within 30 seconds, first shot within 60 seconds, first `rewind_consume` activation within 5 minutes. Tier 1 default mapping (C.4 single source) guarantees this fantasy *without a single line of code*.

### B.3 Anti-Fantasy — What This System Does *Not* Provide

- **Input that concludes with "feels good" as its own justification**: Input only *enables* PM's jump-buffer forgiveness (C.5.2 6 frames) and SM's rewind window (D.2 16 frames); it does not directly provide that *feel*. Input buffering is PM/SM territory.
- **Player personalization**: In Tier 1, Input provides *defaults only*. Remapping is System #23 (Tier 3, Anti-Pillar #6 deferred). Input only promises that the defaults are *correct*.
- **Controller recognition UI**: No "Press A to start" device confirmation screen — that would violate Pillar 4. SDL3 gamepad driver (Godot 4.5+) and Godot 4.6 InputMap handle it automatically.

### B.4 Player Type Match

Echo's target audience (Achievers; Hotline Miami / Katana Zero / Cuphead fans, game-concept Player Type Appeal) is the group most sensitive to *input accuracy*. The greatest value they receive from this system is **"I was too slow" always being true** — that trust creates reps (deathless challenges, time attacks, Tier 3). The integrity of a single input frame is the retention hook.

## C. Detailed Design

### C.1 Core Rules

#### C.1.1 Action Catalog (9 actions, single source)

This table is the single source of truth for the `project.godot` `[input]` block + `InputActions` constants class (C.4). PM C.5.1 / state-machine.md D.2 / time-rewind.md C.3 #1 reference this table, and authoring this GDD clears all their *(provisional)* flags.

| # | Action | Detect Mode | Tier | Buffer Owner | Polled In | Notes |
|---|---|---|---|---|---|---|
| 1 | `move_left` | analog axis | T1 | — (per-tick poll) | `_physics_process` Phase 2 | `Input.get_vector` neg_x; deadzone radial 0.2 (C.1.3) |
| 2 | `move_right` | analog axis | T1 | — | Phase 2 | get_vector pos_x |
| 3 | `move_up` | analog axis | T1 | — | Phase 2 | AimLock 8-way aim only — no vertical platforming |
| 4 | `move_down` | analog axis | T1 | — | Phase 2 | AimLock 8-way aim only — no crouch |
| 5 | `jump` | edge `just_pressed` + `just_released` | T1 | PM `jump_buffer_frames=6` (PM C.5.2) | Phase 2 | PM polls exclusively; variable-cut uses `just_released` |
| 6 | `aim_lock` | hold `is_action_pressed` | T1 | — | Phase 2 | DEC-PM-2 Cuphead-style; independent from `jump` (C.3.3 AC) |
| 7 | `shoot` | hold (`is_action_pressed`) — locked by Player Shooting #7 §C Rule 1 (2026-05-11) | T1 | Player Shooting #7 | Phase 2 | PM does not read. Tap-spam gated by #7 cooldown counter (FIRE_COOLDOWN_FRAMES=10). |
| 8 | `rewind_consume` | edge `just_pressed` | T1 | SM `_rewind_input_pressed_at_frame` (state-machine.md D.2) | `physics_update` (AliveState/DyingState) | Single button / no-chord (Tier 1 invariant). LT chatter handled by SM hysteresis (C.5 cross-doc obligation) |
| 9 | `pause` | edge `just_pressed` | T1 | SM swallow O2 | dual-path: PauseHandler `_unhandled_input` (resume) + SM `_physics_process` (state-aware initiate veto) | C.1.4 single source |

**Catalog Extension Policy**: Tier 1 = exactly 9 actions. Candidates like `weapon_swap` are owned by **Player Shooting #7** — Input only hosts the additional mapping; detect/buffer is #7 single source. Tier 3 #23 may add player-bound actions; *default mapping table is immutable* (C.2 invariant).

#### C.1.2 Polling Discipline (Formalizing B.2 Cascade)

**Core invariant**: All gameplay consumers within the same `_physics_process` tick see the same InputMap action state (B.2 Cascade). Essential for guaranteeing the truthfulness of the ADR-0003 determinism contract and SM's 16-frame `rewind_consume` window predicate (D.2).

1. **Rule 1 (polling timing)**: Gameplay systems (PM #6 / SM #5 / TRC #9 / Player Shooting #7) call `Input.is_action_*` / `Input.get_vector` / `Input.get_action_strength` *only* inside `_physics_process`.
2. **Rule 2 (callback binding forbidden)**: Binding gameplay logic (movement/shooting/time-rewind) to `_input` / `_unhandled_input` / `_unhandled_key_input` callbacks is forbidden. **4 explicit exceptions** (Tier 1: 3 active + Tier 3 carve-out: 1 reserved):
    - (a) UI/Menu (#18) — legitimate use of `_input` callback.
    - (b) PauseHandler node (C.1.4) — `PROCESS_MODE_ALWAYS` autoload, `_unhandled_input`.
    - (c) **ActiveProfileTracker** autoload (D.1.1) — `_input` source classifier (`_input` fires before `_unhandled_input` per E-IN-NEW). Profile detection aims to sense input *type*, not *gameplay logic*, so it is outside this ban scope (exception explicitly stated).
    - (d) **AT bridge nodes (Tier 3 #24 Accessibility) — B22 carve-out 2026-05-11**: Assistive technology input injection nodes such as Xbox Adaptive Controller / switch access / eye-tracking. This carve-out is inactive in Tier 1 (currently 0 code entries) but is *pre-registered* so that the `forbidden_patterns.gameplay_input_in_callback` CI gate does not forever block Tier 3 #24. AT bridge node identification markers: (i) `class_name` has `AssistiveInputBridge` prefix, or (ii) node declares `@export var _at_bridge_exempt: bool = true` self-declaration marker. The forbidden_patterns scanner skips inspection when either matches. Tier 3 #24 GDD is responsible for activating the carve-out + implementing the scanner (new F.4.2 row).
3. **Rule 3 (Phase 2 mutation forbidden)**: Phase 2 input polling phase is *read-only* — state transitions/velocity calculations happen in Phase 3+ (PM C.3 5-phase pattern is single source).
4. **Rule 4 (action_press injection — tests only)**: GUT fixture's synchronous `Input.action_press(InputActions.X)` injection is visible to `is_action_just_pressed` polling within the same tick. *Injection must occur before `await get_tree().physics_frame`*. Testing `_input`/`_unhandled_input` paths uses `Input.parse_input_event(InputEventAction)` separately. **Mixing both APIs in the same fixture is forbidden** (false positive).
5. **Rule 5 (`forbidden_patterns` registration candidates — F.4.1 obligation)**: `gameplay_input_in_callback` (gameplay polling must not enter `_input`) + `deadzone_in_consumer` (individual systems must not re-implement deadzone as `> 0.2`).

#### C.1.3 Deadzone Policy

**Default**: Declare 4 move actions × `deadzone = 0.2` in the `project.godot` `[input]` block. Re-implementing the deadzone formula in gameplay code is forbidden (`forbidden_patterns.deadzone_in_consumer`).

**`Input.get_vector` semantics (verified)**:
- `Input.get_vector(neg_x, pos_x, neg_y, pos_y, deadzone=-1.0)` applies *radial composite magnitude* deadzone (not per-axis).
- With `deadzone=-1.0` (default), the average of each of the 4 actions' individual InputMap deadzones becomes the radial threshold.
- Echo Tier 1: all 4 actions = 0.2 → composite radial 0.2.

**Runtime change (Tier 3 only)**: `InputMap.action_set_deadzone(...)` runtime calls are only permitted in a *paused tree* — the `SettingsManager.apply_deadzone(value)` single entry point enforces the `get_tree().paused = true` → mutate → unpause pattern. Avoids same-frame race conditions.

**Steam Deck 1st-gen stick drift (RMA range 0.05–0.18 raw)**: 0.2 lower bound is sufficient — manual verification on *physical Steam Deck 1st-gen* for 5 minutes in Tier 1 Week 1 prototype (OQ-IN-2).

**B10 responsibility separation**: The problem of PM's `facing_threshold_outside == gamepad_deadzone` (both 0.2 — PM 2026-05-11 review B10 BLOCKING) **cannot be resolved at the Input layer** (explicitly stated by gdscript-specialist). Adding asymmetric hysteresis with enter=0.2 / exit=0.15 to PM is PM's responsibility. This GDD only guarantees the deadzone single source.

#### C.1.4 Pause Architecture (Dual-Path)

When `get_tree().paused = true`, `_physics_process` stops. The pause toggle is handled by an *always-running* node; SM only separates the swallow policy.

```gdscript
# src/input/pause_handler.gd (autoload, process_mode = PROCESS_MODE_ALWAYS)
class_name PauseHandler extends Node

func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed(InputActions.PAUSE):
        return
    if get_tree().paused:
        get_tree().paused = false           # resume: SM cannot veto
    else:
        var sm := get_tree().get_first_node_in_group(&"echo_lifecycle_sm")
        if sm and sm.call(&"can_pause"):    # state-machine.md C.2.2 O2
            get_tree().paused = true
        # else: SM vetoed (DYING/REWINDING swallow) — pause swallowed silently
    get_viewport().set_input_as_handled()   # consume on every decision (resume / initiate / veto) — Godot 4.6 canonical "consume on decision" pattern; AC-IN-24 + B4 reconciliation 2026-05-11
```

| Node | `process_mode` | Callback | Role |
|---|---|---|---|
| `PauseHandler` (autoload) | `PROCESS_MODE_ALWAYS` | `_unhandled_input` | toggle (resume + initiate + veto consumption) |
| `EchoLifecycleSM` (under ECHO) | `INHERIT` (=PAUSABLE) | `_physics_process` | swallow veto (`can_pause()` query interface) |

**Consumption invariant (B4 reconciliation 2026-05-11)**: PauseHandler MUST call `set_input_as_handled()` on **every** decision path — resume, initiate, AND veto. Rationale: (a) Godot 4.6 canonical pattern is consume-on-decision (any node that resolves the event should consume it to prevent downstream misclassification); (b) ActiveProfileTracker._input fires *before* `_unhandled_input` regardless (E-IN-NEW), so consumption here doesn't block profile classification — but it does prevent any other `_unhandled_input` listener from acting on a resolved pause event; (c) AC-IN-24 asserts both veto and resume call this — earlier draft (Session 12) only consumed on success, creating a 4-way contradiction (qa-lead BLK-1 + godot-specialist Item 1 + gameplay-programmer BLOCKING-1 + main-review). CD adjudication: veto SHOULD consume.

**SM-side cross-doc obligation (F.4.1)**: Recommend unifying naming from `should_swallow_pause()` → `can_pause()` in state-machine.md C.2.2 O2 (Round-7 cross-doc-contradiction exception candidate).

**Why not single SM polling?**: SM's `_physics_process` stops when paused → resume impossible (deadlock).

#### C.1.5 First-Death Onboarding Hint (Cross-Doc with HUD #13 + SM)

A *context-timed* hint that, under Tier 1's *zero tutorial pages/modals* promise (Pillar 4), mitigates the risk of *KB+M `Shift = rewind_consume` discovery* (players without Katana Zero experience may not reflexively press Shift within the 0.2s DYING grace).

**Pillar 4 carve-out explicit statement (B3 fix 2026-05-11)**: The 1-token button label (`[Shift] Rewind` / `[LT] Rewind`) exposed by this hint is a *carve-out* from game-concept Pillar 4 "zero lines of text tutorial". The *spirit* of Pillar 4's promise is "zero tutorial-dedicated text pages / modals / page-advancing textboxes" — a 1-token button label is classified as an in-game *UI element* (HUD action prompt) and is not a violation of that promise. Comparative justification: button-label affordances like `[LT]` are standard even in *text-free* games like Dark Souls/Cuphead/Hollow Knight. Tier 3 Localization #22 handles multilingual processing (F.4.1 #3) so there is no English lock-in either. Glyph alternative (ux-designer REC-2 `[LT] ↺`) was reviewed and rejected — no universal glyph standard exists for KB+M `Shift` (Mac ⇧ vs Windows shift logo), making cross-platform consistency impossible. See Decision Log A.1.

**B15 fix (2026-05-11 — Pillar 1/2 silent-betrayal prevention)**: If the latch closes on "first death in session", one panic-miss permanently eliminates the prompt → the same player enters a silent death loop on the next death still not knowing Shift/LT. Therefore, the prompt **displays on every DYING entry** and *permanently stops* immediately after **the first rewind success in session** (the point at which the learning tool is retired moves to when the player *proves* they have learned).

- **Display trigger (per-DYING)**: Every `ALIVE → DYING` transition. SM emits `first_death_in_session(profile)` signal (recurring; *not* a 1-time latch). HUD #13 subscribes + checks its own latch (`_first_rewind_success_latched: bool`) before showing prompt.
- **Permanent stop trigger (per-session)**: SM emits `first_rewind_success_in_session(profile)` signal — emitted once at the first `REWINDING → ALIVE` transition in session when `_lethal_hit_latched_prev == true` (= rewind actually reversed a lethal hit, distinguished from natural hazard-grace recovery). HUD receives → `_first_rewind_success_latched = true` → subsequent `first_death_in_session` ignored.
- **Latch reset**: On `scene_will_change` (a) HUD resets `_first_rewind_success_latched = false` (= new scene = new learning context), (b) SM resets `_session_first_success_emitted = false` (O6 cascade — state-machine.md C.2.2 O8).
- **Display duration**: DYING grace window (12 frames = 200ms). Disappears immediately on REWINDING/DEAD transition.

**Input responsibilities**:
- (a) On `first_death_in_session`, provide button-label matching the active device profile:
  - KB+M: `[Shift] Rewind`
  - Gamepad: `[LT] Rewind`
- (b) Active profile determination — `Input.get_connected_joypads().size() > 0 AND _last_input_source == &"gamepad"`. Godot 4.6 has no native "last input source" API → Input GDD tracks it internally (OQ-IN-3).

**HUD #13 responsibilities**: Visual rendering, 12-frame fade, position/size/color, HUD-local `_first_rewind_success_latched` ownership + `scene_will_change` reset.
**SM responsibilities**: `first_death_in_session` signal owner (emit on every DYING) + `first_rewind_success_in_session` signal owner (per-session 1-time emit + `_session_first_success_emitted` counter + O6 cascade reset). See state-machine.md C.2.2 O7/O8.

**Cross-doc obligations (F.4.1)**:
1. HUD #13 GDD: include prompt visual spec + 12-frame fade + HUD-local `_first_rewind_success_latched` + `scene_will_change` reset spec.
2. SM #5 (**Round-7 cross-doc-contradiction exception**, 2026-05-11): add 2 signals `first_death_in_session` + `first_rewind_success_in_session` (C.2.2 hosting obligation O7/O8). This change imposes *additive* state (`_session_first_success_emitted`) + 2 signals on the Approved/LOCKED SM GDD, authorized as cross-doc exception — follows `damage.md` Round 5 S1 BLOCKER cross-doc fix pattern (Session 6, 2026-05-10).
3. Localization #22 (Tier 3): register `[Shift] Rewind` / `[LT] Rewind` strings as multilingual keys.

#### C.1.6 InputStateProvider Adapter Seam (Tier 3 #24 Hook — B21 fix 2026-05-11)

**Problem (accessibility-specialist)**: In Tier 1, if gameplay consumers (PM/SM/TRC/PS/Menu) call `Input.is_action_*` / `Input.get_vector` *directly*, Tier 3 #24 Accessibility (motor features — hold-duration scaling, mash assist, toggle mode) has no *seam* to interpose. Anti-Pillar #6 defers Tier 3 *content* but does not foreclose *architecture*. This sub-section defines the seam *now* and operates it as a 1:1 passthrough in Tier 1, preserving the Tier 3 swap option.

**Tier 1 invariant (no obligation)**: Tier 1 gameplay consumers *keep their direct* `Input.is_action_*` calls — no additional layer abstraction forced (solo budget + Pillar 5 small wins). This sub-section only locks in the *signature*, making the Tier 3 mass-rename burden *immutable*.

```gdscript
# src/input/input_state_provider.gd (Tier 1: thin static wrapper — no usage obligation)
class_name InputStateProvider extends Node

## Tier 1: 1:1 passthrough. Tier 3 #24 overrides / instance-swaps these 5 methods.
static func is_pressed(action: StringName) -> bool:
    return Input.is_action_pressed(action)
static func is_just_pressed(action: StringName) -> bool:
    return Input.is_action_just_pressed(action)
static func is_just_released(action: StringName) -> bool:
    return Input.is_action_just_released(action)
static func get_vector(neg_x: StringName, pos_x: StringName, neg_y: StringName, pos_y: StringName) -> Vector2:
    return Input.get_vector(neg_x, pos_x, neg_y, pos_y)
static func get_action_strength(action: StringName) -> float:
    return Input.get_action_strength(action)
```

**5-method signature stability guarantee (Tier 1 → Tier 3 mutation forbidden)**: The above 5 method signatures are fixed. Tier 3 may *add methods* / *must not change the existing 5*. This invariant provides a lower bound on the raw `Input.*` mass-rename during Tier 3 PR.

**Tier 3 #24 migration scope (examples — not defined here, hook preservation only)**:
- `hold_duration_scaling`: `is_pressed` → gradual ramp (e.g. 0.5s hold = 0.5 strength).
- `mash_assist`: `is_just_pressed` → debounced auto-repeat (5Hz threshold).
- `toggle_mode`: `is_pressed` → toggle state (press once = pressed until pressed again).
- All of the above features are implemented via `InputStateProvider.*` static method override or instance swap. Raw `Input.*` call sites are mechanical grep-replaced in the Tier 3 PR.

**Tier 3 hook preservation mechanisms**:
1. `forbidden_patterns.gameplay_input_in_callback` (Rule 2 + F.4.1 #13) — prevents Tier 3 migration from escaping to `_input` callbacks (B22 carve-out is *bridge*-only).
2. 5-method signature lock-in (above) — backward-compat guaranteed.
3. Tier 3 #24 GDD imposes migration obligation on *all* gameplay consumers to `InputStateProvider.*` (new F.4.2 row).

**Tier 1 rationale**: seam *definition* is Tier 1, seam *utilization* is Tier 3. Solo budget + Pillar 5 = "define lightly, no obligation, future preservation only". At the time of this GDD, raw `Input.is_action_*` call sites = Tier 1 baseline N (exact count at PR time); Tier 3 migration transitions N → 0.

### C.2 States / Modes (Tier Gating)

Input does *not own* the gameplay state machine (Foundation; SM is #5). Tier modes are specified only for invariant gating purposes.

| Tier | Mode | Invariant |
|---|---|---|
| Tier 1 | `default_only` | 9 actions × 2 device profiles default mapping. **single-button no-chord** invariant absolute (C.3). |
| Tier 2 | `default_only` (unchanged) | Difficulty Toggle #20 does not modify InputMap; only `RewindPolicy` data changes. **0 Input deliverables.** |
| Tier 3 | `remap_permissive` | #23 Input Remapping dynamically calls `InputMap.action_*_event`. Player-bound chords allowed (1-frame latency warning in UI). **Default mapping table is immutable in Reset to Defaults** (0 chords). |

**OQ-15 closure**: Tier 3 chord policy = `default-only` interpretation locked (game-designer recommendation). Tier 3 permissions do not break the Tier 1 determinism contract.

### C.3 InputMap Default Bindings (Single Source)

#### C.3.1 KB+M Profile

| Action | Key / Button | Justification |
|---|---|---|
| `move_left` | A | WASD genre standard |
| `move_right` | D | WASD genre standard |
| `move_up` | W | 8-way aim only |
| `move_down` | S | 8-way aim only |
| `jump` | Space | Universal KB jump affordance |
| `aim_lock` | F | WASD home row **left index finger** natural reach (F is the normal reach position for left index); **Hotline Miami Shift-aim muscle-memory separation** (Shift is occupied by `rewind_consume` in this GDD, cannot be used for aim_lock); non-chord single-button. *B6 fix 2026-05-11*: previous "right ring finger" citation was anatomically incorrect — F is left hand index reach (when using WASD, left index slides 1 key right from D to F). |
| `shoot` | LMB (Mouse Button Left) | Hotline Miami convention; LMB primary fire instinct even when mouse-aim is unused |
| `rewind_consume` | Shift | Katana Zero precedent + LT body-mapping mirror; left pinky panic reflex |
| `pause` | Escape | OS-universal |

**RMB / Mouse-aim future expansion**: Mouse-aim currently unused. If Tier 3 mouse-aim is added, keep `aim_lock = F` + register `RMB` as a separate action.

#### C.3.2 Gamepad Profile (Xbox labels — Steam Deck inherits verbatim)

| Action | Button | Justification |
|---|---|---|
| `move_left` | Left Stick X− | stick primary |
| `move_right` | Left Stick X+ | stick primary |
| `move_up` | Left Stick Y− | 8-way aim direction (Godot Y axis: up = negative) |
| `move_down` | Left Stick Y+ | 8-way aim direction |
| `jump` | A (South face) | Contra/Cuphead universal jump |
| `aim_lock` | RB (Right Bumper) | **Left-right separation**: LT=`rewind_consume` (Pillar 1 LT exclusivity — time-rewind.md C.3 #1) ⇒ RB=`aim_lock` (right shoulder, opposite hand from rewind trigger). Right-hand pinch risk (simultaneous RB+RT hold = `aim_lock` + `shoot`) Tier 1 accepted → OQ-IN-6 playtest verify. *B16 fix 2026-05-11*: "Cuphead lock-aim precedent" citation removed — community consensus is LT=lock, RB=avoid right-hand pinch (web-verified Session 13). CD adjudication: keep RB (LT conflict is worse — Pillar 1 protect), remove false cite, re-justify on left-right separation. |
| `shoot` | RT (Right Trigger) | Cuphead RT shoot — right-hand dominance |
| `rewind_consume` | LT (Left Trigger), threshold 0.5 | time-rewind.md C.3 #1 lock |
| `pause` | Start / Menu | hardware convention; Steam Deck Menu button |

**Steam Deck verification**:
- No separate profile — gamepad table verbatim.
- LT threshold 0.5 chatter risk → SM hysteresis (`_trigger_held` gate; new cross-doc obligation).
- Tier 1 Week 1 *physical 1st-gen Deck* manual verification (OQ-IN-2).

#### C.3.3 AimLock-Jump Exclusivity AC (PM F.4.2 obligation fulfilled)

InputMap fires `aim_lock` hold + `jump` press as *independent events* — 0 chord swallows. PM *ignoring jump while both are seen* is PM-only policy (C.2.4 input ignore). This GDD only guarantees *input delivery*:

```
GIVEN: aim_lock = pressed (hold) + jump = just_pressed (same _physics_process tick)
WHEN: PM Phase 2 polls
THEN: Input.is_action_pressed(InputActions.AIM_LOCK) == true
  AND Input.is_action_just_pressed(InputActions.JUMP) == true
  AND no InputMap-level chord-swallow logic suppresses either
```

### C.4 Action Name Constants (StringName Autoload)

```gdscript
# src/input/input_actions.gd
class_name InputActions

const MOVE_LEFT      := &"move_left"
const MOVE_RIGHT     := &"move_right"
const MOVE_UP        := &"move_up"
const MOVE_DOWN      := &"move_down"
const JUMP           := &"jump"
const AIM_LOCK       := &"aim_lock"
const SHOOT          := &"shoot"
const REWIND_CONSUME := &"rewind_consume"
const PAUSE          := &"pause"
```

**Rule**: All `Input.*` calls use the `InputActions.JUMP` form. Scattering inline `&"jump"` literals is forbidden — refactor-safe (rename → 1 const location) + grep-able + reuse-safe (both gameplay code and GUT fixtures).

**Violation detection**: `tools/ci/input_action_static_check.sh` (Tier 1 CI gate; PM B2 trap avoidance — *writing the script itself* is part of this GDD's AC) — verifies that `grep -RE 'Input\.[a-z_]+\(\s*&?"' src/` output has 0 lines not of the form `InputActions.X`.

### C.5 Interactions With Other Systems

This table is the single source of truth for how Input exchanges data, signals, and method calls with other systems. F.1–F.4 are responsible for bidirectional consistency.

| Target System | Direction | Wiring Pattern | Forbidden Alternatives |
|---|---|---|---|
| **Player Movement (#6)** | PM polls `Input.get_vector` + `is_action_pressed/just_pressed` (5 actions: 4 move + jump + aim_lock) | `_physics_process` Phase 2 | `_input` / `_unhandled_input` callbacks; Input → PM signal emit |
| **State Machine (#5)** | SM AliveState/DyingState `physics_update` polls `is_action_just_pressed(REWIND_CONSUME)`; LT chatter hysteresis (`_trigger_held`) gate **new cross-doc obligation** | `_physics_process` (stops when paused — resume via PauseHandler) | `_input` callback; SM directly mutating InputMap |
| **Time Rewind Controller (#9)** | TRC polls input at same time as SM in `process_physics_priority=1` slot (verify only — actual logic owned by SM) | Phase 2 read | TRC mutating InputMap |
| **Player Shooting (#7)** *(provisional)* | PS polls `is_action_just_pressed(SHOOT)` or `is_action_pressed(SHOOT)` (decision owned by #7) | Phase 2 | — |
| **PauseHandler autoload (single source: this GDD)** | autoload toggles `pause` in `_unhandled_input`; queries SM `can_pause()` | autoload + `PROCESS_MODE_ALWAYS` | SM polling alone (deadlock when paused) |
| **Menu / Pause UI (#18)** | Approved 2026-05-14: focusable menu surfaces may handle UI navigation/confirm/cancel/slider events in `_input` only; pause toggling remains PauseHandler-owned | `_input` allowed for UI only + `PROCESS_MODE_ALWAYS` pause overlay | Polling gameplay actions in `_input`; adding Tier 1 InputMap actions (`menu_confirm`, `menu_cancel`, `skip_intro`); bypassing PauseHandler |
| **HUD (#13)** | HUD subscribes to `first_death_in_session` signal (SM owner) + Input's button-label string API | signal + read-only API | HUD calling `Input.get_action_*()` directly |
| **Story Intro Text (#17)** | Uses no input API directly; existing cold-boot first-input route may interrupt the passive intro via Scene Manager #2 | Input #1 / Scene Manager #2 cold-boot route; no new InputMap action | Adding `skip_intro` or intro-specific confirm action |
| **SettingsManager (Tier 3)** | On `apply_deadzone(v)` call, calls `InputMap.action_set_deadzone` in paused tree | paused-tree apply | mid-tick deadzone mutation |
| **Input Remapping (#23, Tier 3)** | #23 dynamically calls `InputMap.action_*_event` — *default mapping table immutable* | paused-tree apply + `default_only` invariant | Changing the 9-action base catalog from Tier 3 |
| **GUT Test Fixture (CI)** | Fixture uses `Input.action_press(InputActions.X)` or `parse_input_event(InputEventAction)` | inject before `await get_tree().physics_frame` | Mixing both APIs (false positive) |

## D. Formulas

Section D is intentionally narrow. Input is a Foundation/Infrastructure layer; all gameplay-meaningful formulas (jump buffer / coyote window / rewind predicate / velocity integration / 1.5s lookback) are single-sourced in consumer GDDs (see C.5 Interactions). The formulas Input *directly owns* are three: **D.1** active device profile resolution, **D.2** wall-clock exclusion rule, **D.3** radial composite deadzone (B9 addition 2026-05-11 — Session 12 draft deferred with "complete in C.1.3" but systems-designer review determined that the exact Godot `Input.get_vector` function definition + variable table + worked examples are required; C.1.3 holds only the *policy declaration*, D.3 is the single source for the function definition).

### D.1 Active Device Profile Resolution

C.1.5 first-death hint needs to know the active device profile (KB+M vs Gamepad) to select the button-label string (`[Shift] Rewind` vs `[LT] Rewind`). Since Godot 4.6 has no native "last input source" API, this GDD defines *its own tracking + heuristic* as the single source.

#### D.1.1 Part A — Source Classification (event-driven write)

Classifies `InputEvent` subtypes in the `_input` callback and updates two member variables (predicate, no arithmetic):

```gdscript
# src/input/active_profile_tracker.gd (autoload, PROCESS_MODE_ALWAYS)
class_name ActiveProfileTracker extends Node

enum DeviceProfile { NONE = 0, KB_M = 1, GAMEPAD = 2 }

var _last_input_source: DeviceProfile = DeviceProfile.NONE
var _last_input_frame: int = -1

func _input(event: InputEvent) -> void:
    if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
        _last_input_source = DeviceProfile.KB_M
        _last_input_frame = Engine.get_physics_frames()
    elif event is InputEventJoypadButton:
        _last_input_source = DeviceProfile.GAMEPAD
        _last_input_frame = Engine.get_physics_frames()
    elif event is InputEventJoypadMotion:
        # B8 axis filter (2026-05-11 fix): only intentional-input axes flip the profile.
        # Without this filter, RIGHT_STICK_X/Y drift in (0.3, 0.5) range — Steam Deck 1st-gen
        # right-stick drift is documented up to 0.18 raw on RMA units but third-party
        # controllers (Xbox One worn analog) can exceed GAMEPAD_DETECTION_THRESHOLD without
        # the player intending input. Right stick is *unbound* in Echo Tier 1 (no aim-stick),
        # so a profile flip from right-stick drift would be a silent false-positive.
        const PROFILE_AXES := [
            JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y,
            JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT,
        ]
        if event.axis not in PROFILE_AXES:
            return  # right stick / unbound axes never flip profile
        if absf(event.axis_value) > GAMEPAD_DETECTION_THRESHOLD:  # filter stick drift on bound axes
            _last_input_source = DeviceProfile.GAMEPAD
            _last_input_frame = Engine.get_physics_frames()
```

**B8 axis filter rationale (2026-05-11 review fix)**: Echo Tier 1 binds left-stick (move) + LT (rewind) + RT (shoot) + face buttons. Right-stick / D-pad axes are *unbound* but `InputEventJoypadMotion` fires on all axes regardless. Without `PROFILE_AXES` whitelist, an Xbox controller with worn right-stick analog could silently flip `_last_input_source = GAMEPAD` while the player is actively using KB+M — first-death prompt then displays `[LT] Rewind` even though `rewind_consume` was just bound to `Shift`. Whitelist enforces "intentional axes only" semantics. Test: `event.axis` IN `PROFILE_AXES` → process; otherwise early-return.

#### D.1.2 Part B — Profile Resolution (per-query read)

**Formula**:

`active_profile() = profile_decision(_last_input_source, _last_input_frame, current_frame, HYSTERESIS_FRAMES, joypads_connected)`

```
delta_frames := current_frame − _last_input_frame

active_profile() :=
  GAMEPAD                                 if _last_input_source == GAMEPAD AND delta_frames < HYSTERESIS_FRAMES
  KB_M                                    if _last_input_source == KB_M
  GAMEPAD if joypads_connected > 0 else KB_M
                                          if _last_input_source == NONE OR (GAMEPAD AND delta_frames ≥ HYSTERESIS_FRAMES)
```

**Variables**:

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `_last_input_source` | s | DeviceProfile enum | {NONE=0, KB_M=1, GAMEPAD=2} | Part A output. Last classified input source |
| `_last_input_frame` | f₀ | int | -1 or ≥ 0 | `Engine.get_physics_frames()` at the time Part A last updated. -1 = initial, no input yet |
| `current_frame` | f | int | ≥ 0 | `Engine.get_physics_frames()` at query time |
| `HYSTERESIS_FRAMES` | H | int | 60 ≤ H ≤ 600, default **180** | Gamepad sticky window. 60 = 1s (too short, mouse brush causes immediate KB+M flip), 600 = 10s (too long, wrong label for 10s after device switch) — Tier 1 default 180 (3s) balances mouse jitter absorption + device switch responsiveness. G.1 tunable. |
| `GAMEPAD_DETECTION_THRESHOLD` | T_g | float | **0.3** (OQ-IN-3 pending Tier 1 Steam Deck 1st-gen verification) | `InputEventJoypadMotion` `abs(axis_value)` filter. 50% margin above 0.2 deadzone — avoids drift false-positives. Sufficient above Steam Deck 1st-gen RMA 0.18 max raw. |
| `joypads_connected` | j | int | ≥ 0 | `Input.get_connected_joypads().size()` value at query time |
| **Output** `active_profile()` | — | DeviceProfile | {KB_M, GAMEPAD} | Never returns NONE (3rd branch is fallback) |

**Output Range**: `{KB_M, GAMEPAD}` — `NONE` is never exposed externally (3rd branch is fallback). No arithmetic unbounded region.

**Worked Examples** (HYSTERESIS_FRAMES = 180):

```
Scenario 1 — gamepad active session
  s = GAMEPAD, f₀ = 3000, f = 3050, H = 180, j = 1
  delta = 50; 50 < 180 → 1st branch hit → output = GAMEPAD ✓

Scenario 2 — gamepad expired, joypad still connected
  s = GAMEPAD, f₀ = 3000, f = 3500, H = 180, j = 1
  delta = 500; 500 ≥ 180 → 1st branch miss → s != KB_M → 3rd branch → j > 0 → GAMEPAD ✓

Scenario 3 — gamepad expired, joypad unplugged mid-session
  s = GAMEPAD, f₀ = 3000, f = 3500, H = 180, j = 0
  delta = 500; 500 ≥ 180 → 3rd branch → j == 0 → KB_M ✓

Scenario 4 — KB_M sticky (no hysteresis on KB+M side)
  s = KB_M, f₀ = 100, f = 100000, H = 180, j = 1
  s == KB_M → 2nd branch hit → KB_M ✓
  (reason: keyboard/mouse users are actively "at desk" — no gamepad fallback needed)

Scenario 5 — cold boot
  s = NONE, f₀ = -1, f = 60, H = 180, j = 1
  s == NONE → 3rd branch → j > 0 → GAMEPAD ✓
  (Pillar 4 byproduct: GAMEPAD default on first frame when booting Steam Deck)
```

**Asymmetric design**: GAMEPAD is sticky via hysteresis, KB_M is immediately-sticky (permanent). Rationale — gamepad users often *brush* the mouse, but KB+M users press keys intentionally. This asymmetry prevents first-death prompt label flickering (false KB_M flip → immediate KB_M label → mismatch with intent). G.1 tunable permission allows changing to symmetric hysteresis in the future.

**OQ-SM-3 closure**: `rewind_consume` action name is verbatim-locked in this GDD C.1.1 row 8 — state-machine.md OQ-SM-3 resolved (*no registry registration required* — single source naming, no cross-system value drift risk).

### D.2 Wall-Clock Exclusion Rule (non-formula clarification)

**Wall-clock API usage in gameplay is forbidden**. Per the ADR-0003 `determinism_clock` decision, input timing judgment uses only `Engine.get_physics_frames()` as the single source.

**Godot 4.6 verified banned API list** (`docs/engine-reference/godot/modules/input.md` + `Time` / `OS` API verification basis):
- `Time.get_ticks_msec()`, `Time.get_ticks_usec()`, `Time.get_unix_time_from_system()`
- `OS.get_ticks_msec()`, `OS.get_ticks_usec()`
- `Time.get_datetime_*` family

```gdscript
# Forbidden — wall-clock dependency
if Time.get_ticks_msec() - _last_press_msec < 100:  # ← BANNED (wall-clock source)
    handle_recent_input(event)

# Allowed — physics frame based
if Engine.get_physics_frames() - _last_input_frame < HYSTERESIS_FRAMES:
    use_recent_profile()
```

**B11 fix (2026-05-11 — Godot 4.6 unverified API citation correction)**: Session 12 draft cited `InputEvent.timestamp` as a wall-clock source, but *Godot 4.6 official `InputEvent` base class API has no official `timestamp` field* (`docs/engine-reference/godot/modules/input.md` reference absent — 2026-05-11 grep verified). This correction removes the false API citation and keeps only the actual wall-clock surfaces (`Time.*` / `OS.*` family) in the banned list. The AC-IN-18 wall-clock check script pattern (`Time\.get_ticks_msec\|Time\.get_ticks_usec\|OS\.get_ticks_msec`) already excludes `InputEvent.timestamp` — no change. The `forbidden_patterns.wall_clock_in_input_logic` (F.4.1 #13) scanner definition also maintains the same grep pattern.

Forbidden pattern registration candidate (F.4.1): `wall_clock_in_input_logic` — blocks when `Time.get_ticks_msec()` / `Time.get_ticks_usec()` / `OS.get_ticks_msec()` calls exist in Input/gameplay code. Verified by CI grep gate `tools/ci/wall_clock_check.sh` (C.4 obligation extension).

### D.3 Radial Composite Deadzone (B9 addition 2026-05-11)

**Formula**:

`deadzone_filter(raw_vec: Vector2, T: float) -> Vector2`

```
magnitude := raw_vec.length()                            # √(x² + y²)
deadzone_filter(raw_vec, T) :=
  Vector2.ZERO                                            if magnitude < T
  raw_vec * ((magnitude − T) / (1.0 − T)) / magnitude    if magnitude ≥ T
  (= raw_vec.normalized() * remapped_magnitude)
```

This is the equivalent expression for `Input.get_vector(neg_x, pos_x, neg_y, pos_y, deadzone=-1.0)` — Godot 4.6 engine internally uses the average of the 4 individual action `deadzone` values as `T`, and applies magnitude to the raw `(x, y)` vector before composition (`x = pos_x_strength − neg_x_strength`, same for y; based on raw `axis_value`).

**Variables**:

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `raw_vec` | $\vec{v}$ | Vector2 | $[-1.0, 1.0]^2$ | `(pos_x_strength − neg_x_strength, pos_y_strength − neg_y_strength)`. Godot composites the raw axis_value (or KB 1.0/0.0) of 4 actions. |
| `magnitude` | $m$ | float | $[0.0, \sqrt{2}]$ | $\|\vec{v}\|$ — radial composite length. Up to √2 on diagonal input. |
| `T` | $T$ | float | $[0.0, 1.0]$ default **0.2** | radial threshold. When `Input.get_vector(deadzone=-1.0)` = mean(action_get_deadzone(4 actions)) — Echo Tier 1 all 0.2 → T=0.2. |
| **Output** | $\vec{u}$ | Vector2 | $[-1.0, 1.0]^2$ (magnitude $\in [0.0, 1.0]$) | radial scaled vector. magnitude remapped from [T, 1.0] to [0.0, 1.0]. |

**Output Range**: `Vector2.ZERO` (m < T) or normalized-and-remapped vector with magnitude `[0.0, 1.0]`. Magnitude cannot reach √2 — Godot clamps output magnitude with `min(remapped, 1.0)` (diagonal input 1.0 limit).

**Worked Examples** (Echo Tier 1 case T=0.2):

```
Example 1 — within deadzone (Steam Deck 1st-gen stick drift)
  raw_vec = Vector2(0.15, 0.0); m = 0.15; T = 0.2
  m < T → output = Vector2.ZERO ✓
  (PM facing-lock invariant maintained — E-IN-1)

Example 2 — at deadzone boundary
  raw_vec = Vector2(0.2, 0.0); m = 0.2; T = 0.2
  m ≥ T → remapped_m = (0.2 − 0.2) / 0.8 = 0.0 → output = Vector2.ZERO
  (boundary inclusion is effectively zero output — no flickering)

Example 3 — mid-tilt cardinal
  raw_vec = Vector2(0.6, 0.0); m = 0.6; T = 0.2
  m ≥ T → remapped_m = (0.6 − 0.2) / 0.8 = 0.5 → output = Vector2(0.5, 0.0) ✓
  (m=0.6 raw → 0.5 effective — analog tilt linear remap)

Example 4 — diagonal full-tilt (diagonal 1.0 clamp)
  raw_vec = Vector2(1.0, 1.0); m = √2 ≈ 1.414; T = 0.2
  m ≥ T → remapped_m = (1.414 − 0.2) / 0.8 ≈ 1.518
  Godot clamps: output magnitude = min(1.518, 1.0) = 1.0
  output = (1.0, 1.0).normalized() = Vector2(0.707, 0.707) ✓
  (diagonal is no faster than cardinal — Echo PM facing 8-way stability)

Example 5 — KB+M (1.0/0.0 binary)
  raw_vec = Vector2(1.0, 0.0); m = 1.0; T = 0.2
  m ≥ T → remapped_m = (1.0 − 0.2) / 0.8 = 1.0 → output = Vector2(1.0, 0.0) ✓
  (KB 1.0 strength → full output, deadzone has no effect — matches KB+M user intent)
```

**Cross-knob Invariant (B10 addition 2026-05-11)**:

```
INVARIANT-IN-1: gamepad_stick_deadzone < GAMEPAD_DETECTION_THRESHOLD
INVARIANT-IN-2: GAMEPAD_DETECTION_THRESHOLD − gamepad_stick_deadzone ≥ 0.05
```

Rationale: if the two knobs are equal (e.g. both 0.2), the *same moment* the stick raw `axis_value` passes the deadzone and *fires PM movement*, a flip to `_last_input_source = GAMEPAD` is also triggered — not a race, but both effects occur in the same frame making debugging difficult. The ≥0.05 margin provides a clear 3-band separation: *pure stick drift passes neither*, *intentional input passes both*, *border region triggers detection only without triggering movement*. Echo Tier 1: 0.2 / 0.3 = 0.10 margin (sufficient).

**Boot-time assert** (gameplay-programmer R5 + R20 combined): at `ActiveProfileTracker._ready()` or InputManager boot time:

```gdscript
# B10 invariant boot assert (2026-05-11 fix)
const GAMEPAD_DETECTION_THRESHOLD := 0.3
const HYSTERESIS_FRAMES := 180
const MIN_KNOB_MARGIN := 0.05

func _ready() -> void:
    var deadzone := InputMap.action_get_deadzone(InputActions.MOVE_LEFT)
    assert(GAMEPAD_DETECTION_THRESHOLD - deadzone >= MIN_KNOB_MARGIN,
        "INVARIANT-IN-2 violated: GAMEPAD_DETECTION_THRESHOLD (%f) − gamepad_stick_deadzone (%f) < %f" %
        [GAMEPAD_DETECTION_THRESHOLD, deadzone, MIN_KNOB_MARGIN])
    assert(HYSTERESIS_FRAMES > 0,
        "INVARIANT: HYSTERESIS_FRAMES=0 produces silent GAMEPAD-sticky (R5)")
```

Test obligation: new H section AC-IN-22 (boot-time invariant assertion fires when knobs misconfigured in `project.godot`).

**Why is D.3 separate from D.1.1 axis filter?**: D.1.1 is about *which axes can trigger a profile flip* (axis whitelist). D.3 is about *for axes that can trigger a flip, what magnitude triggers the flip* (threshold + invariant). The two layers together reduce false-positives to zero — D.1.1 alone would ignore the right stick but left-stick 0.2–0.3 drift would create a GAMEPAD profile (false positive); D.3 alone would allow right-stick 0.5+ drift as a false positive (triggers regardless of axis).

## E. Edge Cases

This section specifies abnormal/edge situations that can arise in Input alone or in interaction with other systems. Each item uses *condition → outcome* format ("handle gracefully" is forbidden, per design-docs.md rule). Cases with large formula/gameplay significance are single-sourced in consumer GDDs — this section only registers cases the Input layer *directly* handles or *has explicit responsibility for* (systems-designer verified — 10 entries).

### E.1 Deadzone & Stick Drift

- **E-IN-1**: stick raw `abs(axis_value) ∈ [0.0, 0.2)` (includes Steam Deck 1st-gen RMA 0.05–0.18) → `Input.get_vector` returns `Vector2.ZERO` (radial composite deadzone 0.2). PM facing-lock invariant maintained — *conditional on PM B10 hysteresis fix (`facing_threshold_outside=0.2 / facing_threshold_inside=0.15` asymmetric) being applied*. With PM B10 unfixed, facing direction may flicker every frame (player-movement.md 2026-05-11 review B10 BLOCKING) — not Input's responsibility, PM-only responsibility.

- **E-IN-6**: gamepad `JOY_AXIS_TRIGGER_LEFT < 0.5` (below threshold) AND KB `Shift` pressed same tick → `Input.is_action_just_pressed("rewind_consume")` returns `true` (KB path fires directly at InputEventKey 1.0 strength, independent of `axis_value` 0.5 threshold). Additional outcome: D.1.1 classifier updates active profile to KB_M. SM's `_trigger_held` gate (C.5 cross-doc obligation) is based on *action state*, so KB path also fires normally — even if the gate was in LT-held state, KB Shift `just_pressed` is seen.

### E.2 Multi-Source & Device Convergence

- **E-IN-4 (E-IN-5 merged)**: KB `Shift` AND gamepad `LT` pressed simultaneously (same tick) or simultaneously released → `is_action_just_pressed`/`is_action_just_released` fires *exactly once each* (Godot action consolidation: multiple InputEvents → single action state). SM handles `rewind_consume` single fire normally. *However* active profile resolution is *indeterminate* — OS event arrival order is not guaranteed within the same tick, so D.1.1 decides by whichever device event was processed last. First-death prompt label shows whichever of the two. **Decision**: pathological scenario — whichever label is shown, there is no intent mismatch (both pressed = both intended) → no Tier 1 fix.

- **E-IN-12**: Steam Input (Big Picture) OS-level remapping *overrides* Godot InputMap → a different button than the player expected fires the action. **Decision**: Tier 1 doc-only stance. The Input layer cannot see below SDL3 events, so Steam Big Picture customization is the player's responsibility. When Tier 3 #23 GDD is authored, obligation to add Steam Deck guide cross-ref.

- **E-IN-13**: Player unplugs gamepad mid-DYING (or mid-game) → `Input.get_connected_joypads().size()` drops to 0; D.1.1's `_last_input_source = GAMEPAD` remains; D.1.2 returns stale `GAMEPAD` while `delta_frames < HYSTERESIS_FRAMES` (180). If `first_death_in_session` fires within that window, prompt may incorrectly show `[LT] Rewind`. **Decision**: Tier 1 accepted (mid-session unplug = pathological). Tier 2 fix candidate: subscribe to `Input.joy_connection_changed` signal → ActiveProfileTracker force-expires GAMEPAD hysteresis on disconnect (`_last_input_frame -= HYSTERESIS_FRAMES`). Registered as OQ-IN-4.

- **E-IN-14**: Cold boot with no input devices connected (`Input.get_connected_joypads().size() == 0` AND keyboard not OS-recognized) → D.1.2 Scenario 5 with `j=0` → returns KB_M default. Game waits for input on the title screen. PauseHandler autoload is active normally (no trigger since no input). If keyboard is later OS-recognized, `_input` functions normally. *No crash, no freeze.*

- **E-IN-NEW (PauseHandler vs ActiveProfileTracker dispatch order — B5 corrected 2026-05-11)**: Godot 4.6 input dispatch order is invariant: `_input` → GUI/Control → `_shortcut_input` → `_unhandled_key_input` → `_unhandled_input` (godot docs `Node.notification` + InputEvent propagation). Therefore: when `pause` keypress reaches the engine, `ActiveProfileTracker._input` fires **first**, classifies the source (KB → KB_M; gamepad button → GAMEPAD), updates `_last_input_source` + `_last_input_frame`, and returns. *Then* `PauseHandler._unhandled_input` runs and (a) toggles `get_tree().paused` per `can_pause()` query (b) calls `set_input_as_handled()` on every decision path (B4 invariant). Consumption here does **not** prevent ActiveProfileTracker from receiving the event — it already ran. Consumption *does* prevent any other `_unhandled_input` listener (UI/Menu #18 future hook, debug overlays, etc.) from re-acting on a resolved pause event. **Decision**: benign on different grounds than Session 12 draft assumed. The benign property holds because (i) ActiveProfileTracker classifying a pause keypress is meaningful and correct — pressing Escape on KB or Start on gamepad is a legitimate profile signal (player is reaching for menu); (ii) PauseHandler consumption gates downstream double-handling. Autoload **registration order in project.godot is irrelevant** — Godot dispatch order is determined by callback type (`_input` < `_unhandled_input`), not by autoload load order. Earlier Session 12 draft implied registration order mattered; this is **factually wrong** (3-way specialist convergence: systems-designer + gameplay-programmer + godot-specialist). Tier 1 prototype verification: GUT scenario asserts ActiveProfileTracker._last_input_frame increments on the same frame a `pause` keypress is dispatched, regardless of PauseHandler `set_input_as_handled()` invocation order.

### E.3 Pause Domain

- **E-IN-7 (E-IN-8 + E-IN-10 merged)**: `pause` input arrives when `EchoLifecycleSM.current_state ∈ {DYING, REWINDING}` → `PauseHandler._unhandled_input` queries `sm.can_pause()` → SM returns false (state-machine.md C.2.2 O2 swallow policy) → `get_tree().paused` is *not changed*; pause event is silently dropped. Outcomes: (a) `rewind_consume` 12-frame grace window counts normally — pause-cheat blocked; (b) i-frame 30-frame window counts normally; (c) if first-death prompt is currently displayed, prompt continues for remaining frames (no separate cancel logic — DYING veto handles it naturally). Obligation to register testable AC in H section.

- **E-IN-9**: `pause` input arrives when `get_tree().paused == true` → resume is always allowed (SM has no veto authority — C.1.4 single source). Cross-ref to C.1.4 only.

- **E-IN-11**: Game window loses focus mid-DYING → Godot 4.6 `application/run/pause_when_focus_lost = true` (default) → tree pauses → SM `_physics_process` stops → `_frames_in_state` counter freezes. On focus recovery, resumes exactly from that point. Net result: the 12-frame DYING window is extended *by the focus-lost duration*. **Decision**: Tier 1 accepted behavior — alt-tab players are outside Echo's target audience (Achievers), and the outcome (window extension) favors the player. Registered as OQ-IN-5 (Tier 2 playtest validation).

### E.4 Test Injection

- **E-IN-16**: GUT fixture calls *both* `Input.action_press(InputActions.X)` AND `Input.parse_input_event(InputEventAction.new())` on the same action in the same frame → action state is set twice (idempotent — same result); `_input` callback fires *once* (`parse_input_event` path only). `is_action_just_pressed` is `true` exactly once after `await get_tree().physics_frame`. **Decision**: undefined-but-not-crashing territory; explicit violation of C.1.2 Rule 4 "mixing both APIs is forbidden". The GUT helper template in this GDD's H section enforces the *single-API-only* pattern (prevents test author error).

### E.5 Cross-Reference (single sources in other GDDs/sections)

Specifies the single-source location of edge case candidates *not registered* in this section (systems-designer classification):

| Candidate | Single Source | Notes |
|---|---|---|
| LT chatter near threshold 0.5 → re-fire handling | state-machine.md **C.2.2 O9** (`_trigger_held` gate, applied Session 14 Task #11 2026-05-11) | Input only guarantees normal `is_action_just_pressed` firing — subsequent handling is SM's responsibility |
| Same-tick multi-consumer consistency verification | input.md H (Cascade invariant AC) + ADR-0003 1000-cycle | Registered in this GDD as AC-IN-XX |
| Tier 3 chord binding 1-frame latency display | input.md C.2 (Tier 3 remap_permissive) + #23 GDD | This GDD's single source is invariant only; UI handling is #23 |
| `_input` ↔ `_physics_process` order race (D.1.1 → D.1.2 same tick) | non-issue | Cascade invariant is *gameplay state* scope; `active_profile()` UI label query returns fresh within the same tick normally |

## F. Dependencies

This section holds the single source for the Input system's dependency map and bidirectional reciprocity (how other GDDs reference this GDD). Interface details (signal signatures · method signatures · polling patterns) are single-sourced in C.5 "Interactions With Other Systems" — this section only covers *map + obligations tracking*.

### F.1 Upstream Dependencies (Input depends on)

**None** — Input is the Foundation layer (stated in systems-index.md "Foundation Layer (0 dependencies)"). Depends only on the Godot 4.6 engine (`Input` singleton + `InputMap` API + SDL3 gamepad driver).

### F.2 Downstream Dependencies (consumers — depend on Input)

| # | System | Hard/Soft | Tier | Interface (C.5 single source) | Bidirectional update obligation after this GDD is authored |
|---|---|---|---|---|---|
| #6 Player Movement | **Hard** | T1 | `Input.get_vector` + `is_action_pressed`/`just_pressed`/`just_released` for 5 actions (4 move + jump + aim_lock). `_physics_process` Phase 2 only. | Resolve 4 PM C.5.3 *(provisional)* flags (F.4.1 #1) |
| #5 State Machine | **Hard** | T1 | `is_action_just_pressed("rewind_consume")` per-tick at AliveState/DyingState `physics_update`; `pause` swallow via `can_pause()`. New SM-side LT chatter `_trigger_held` gate obligation. | Resolve SM F.1 row 832 *(provisional)* + OQ-SM-3 Resolved + add `_trigger_held` cross-doc obligation (F.4.1 #4-7) |
| #9 Time Rewind Controller | **Soft** | T1 | Polling at same time as SM in `process_physics_priority=1` slot (verify-only — SM owns actual logic). | Resolve time-rewind.md C.3 #1 *(provisional)* + OQ-15 Resolved (F.4.1 #8-9) |
| #7 Player Shooting | **Hard** | T1 | `Input.is_action_pressed("shoot")` polled in WeaponSlot `_physics_process` Phase 2. Tap-spam gated by #7 cooldown counter (FIRE_COOLDOWN_FRAMES=10), not by edge-trigger. | **Locked 2026-05-11** by Player Shooting #7 §C Rule 1; C.1.1 row 7 *(provisional)* removed in same batch. |
| #13 HUD | **Hard** | T1 | Subscribe to `first_death_in_session` signal (SM owner) + Input's `button_label(profile, action)` API. | ✅ Closed 2026-05-13 by HUD #13 approval: prompt visual spec + 12-frame fade + HUD-local latch reset |
| #18 Menu / Pause UI | **Soft** | T1 | UI navigation/confirm/cancel/slider/focus-repair events in `_input` only; pause toggling remains PauseHandler-owned. | ✅ Closed 2026-05-14 by Menu/Pause #18 approval: no gameplay polling, no new Tier 1 InputMap actions, `PROCESS_MODE_ALWAYS` pause/options surfaces only. |
| PauseHandler autoload | — (본 GDD 단일 출처) | T1 | `_unhandled_input`에서 `pause` 토글; SM `can_pause()` 쿼리. | 자체 출처 — 갱신 의무 없음 |
| ActiveProfileTracker autoload | — (본 GDD 단일 출처) | T1 | `_input`에서 InputEvent 분류 → `_last_input_source` 갱신. | 자체 출처 — 갱신 의무 없음 |
| #20 Difficulty Toggle | **Soft** *(provisional)* | T2 | InputMap 미수정. `RewindPolicy` data만 변경. | #20 GDD 작성 시 zero InputMap mutation 확인 (F.4.2 #4) |
| #23 Input Remapping | **Hard** *(provisional)* | T3 | `InputMap.action_*_event` 동적 호출. *Default mapping table 불변* invariant + chord 1-frame latency UI advisory. | #23 GDD 작성 시 `default_only` Reset-to-Defaults invariant 수용 + chord 정책 cross-doc (F.4.2 #5) |
| #22 Localization | **Soft** *(provisional)* | T3 | `[Shift] Rewind` / `[LT] Rewind` 문자열 다국어 키. | #22 GDD 작성 시 button-label key 등록 (F.4.2 #6) |
| #24 Accessibility | **Soft** *(provisional)* | T3 | `SettingsManager.apply_deadzone()` paused-tree mutation 경유 — Input 직접 의존 X. | #24 GDD 작성 시 SettingsManager 패턴 채택 (F.4.2 #7) |
| GUT Test Fixture | (test infra) | T1+ | `Input.action_press(InputActions.X)` *or* `Input.parse_input_event(InputEventAction)` (혼용 금지 — E-IN-16). | GUT helper template 작성 (F.4.2 #8 — 본 GDD AC-IN-XX이 강제) |

### F.3 Cross-Doc Architectural Obligations Introduced By This GDD

본 GDD가 *기존* GDD에 신규 부과하는 의무 — F.4.1 batch에서 일괄 적용.

| # | 대상 GDD | 의무 | 사유 |
|---|---|---|---|
| O-IN-1 ✅ | state-machine.md **C.2.2 O9** (applied Session 14 Task #11 2026-05-11 via **Round-7 cross-doc-contradiction exception** per `damage.md` Round 5 S1 pattern) | `_trigger_held: bool` gate 추가 — `JOY_AXIS_TRIGGER_LEFT` chatter 시 `is_action_just_pressed`가 동일 hold 동안 한 번만 처리되도록. `_rewind_input_pressed_at_frame` 갱신 직전 가드. | E-IN-2 + Steam Deck 1세대 LT 마모 시 chatter 위험 (gdscript-specialist 검증). **B14 status**: 사전 인가된 Round-7 exception 우산(active.md Session 14 헤더) 하에 Task #11에서 SM C.2.2 O9으로 실제 적용 완료. SM re-review NOT required (additive state + 1 member + 1 gate, framework code 변경 0건). |
| O-IN-2 | state-machine.md C.2.2 O2 | `should_swallow_pause()` → `can_pause()` 명명 통일 (또는 양 메서드 공존 — 단순 alias). PauseHandler가 `can_pause()` 쿼리하므로. | C.1.4 PauseHandler 패턴 일관성. Round-7 cross-doc-contradiction exception 후보 |
| O-IN-3 | state-machine.md (신규 signal, **Round-7 cross-doc-contradiction exception** 2026-05-11) | `first_death_in_session(profile: StringName)` 신호 owner — **매** `ALIVE → DYING` 전이 시 emit (recurring, NOT 1-time latch). HUD가 자체 latch로 displays-or-suppress 판단. SM 측 latch 없음. C.2.2 O7. | C.1.5 first-death hint show 트리거 (per-DYING) |
| O-IN-3b | state-machine.md (신규 signal, **Round-7 cross-doc-contradiction exception** 2026-05-11) | `first_rewind_success_in_session(profile: StringName)` 신호 owner — 세션 내 최초 `REWINDING → ALIVE` 전이 + `_lethal_hit_latched_prev == true` (lethal-hit-driven rewind) 일 때 1회 emit. SM 멤버 `_session_first_success_emitted: bool` idempotency. Scene change(O6 cascade)에서 카운터 reset. C.2.2 O8. | C.1.5 first-death hint 영구 정지 (B15 Pillar 1/2 silent-betrayal 방지) |
| O-IN-4 | systems-index.md System #5 / #6 / #9 row "Depends On" 컬럼 | "Input #1" 추가 (현재 #5 row는 "(Foundation; 시그널 소비자: ... Input #1)" 이미 명시; #6 row는 "Input #1" 명시; #9 row는 "Input" 단축형). 통일 권장. | systems-index.md 컬럼 일관성 |

### F.4 Reciprocity Edits

#### F.4.1 Edits This GDD Owes (must apply at Phase 5 closure)

본 GDD 작성으로 *현재 작성된* GDD/registry에 일괄 적용해야 하는 reciprocal 수정 (Phase 5 batch).

1. **player-movement.md C.5.3** → "(Provisional pending Input System #1)" 헤더 제거 + 4 항목 verbatim lock (deadzone 0.2, KB+M 키맵, AimLock-jump exclusivity, action 명명).
2. **player-movement.md C.6 row 470 (Input System #1 row)** → "*provisional*" 플래그 제거 + `_input` 콜백 forbidden 단일 출처 cross-ref → input.md C.1.2 Rule 2.
3. **player-movement.md F.4.2 obligations registry** → "Input #1 (deadzone + AimLock-jump exclusivity)" 항목 *해소* 표시 + AC-H4-04 ADVISORY → obsolete (Input GDD AC-IN-XX이 BLOCKING으로 대체).
4. **state-machine.md F.1 row 832 (Input System row)** → "*provisional*" 제거 + `design/gdd/input.md` 링크 + `_trigger_held` gate cross-doc obligation 추가 cross-ref.
5. **state-machine.md F.1 line 868** → `input-system.md` placeholder를 `input.md`로 정정 (Round-7 cross-doc-contradiction exception applied at Phase 5).
6. **state-machine.md OQ-SM-3** → Resolved 표시 (`rewind_consume` action 이름 확정).
7. **state-machine.md C.2.2 O2** → `should_swallow_pause()` ↔ `can_pause()` 명명 정합 (alias 추가 또는 rename).
8. **time-rewind.md C.3 #1 row (`#1 Input System`)** → InputMap 매핑 cross-doc → input.md C.3.2 Gamepad LT row + C.3.1 KB+M Shift row.
9. **time-rewind.md OQ-15** → Resolved 표시 (Tier 3 chord = `default-only` interpretation locked, input.md C.2 단일 출처).
10. **systems-index.md System #1 row** → status `Designed (2026-05-10)`, Design Doc 링크 `input.md`, Depends On `—` 명시.
11. **systems-index.md Progress Tracker** → Designed `0` → `1` (Player Movement 제외, Input 추가).
12. **systems-index.md Last Updated header** → 본 세션(Session 12) 엔트리 prepend.
13. **docs/registry/architecture.yaml** → 신규 항목 4건 추가:
    - `state_ownership.input_actions_catalog` (9 actions, source = input.md C.1.1)
    - `interfaces.input_polling_contract` (pattern = `_physics_process Phase 2 only`)
    - `forbidden_patterns.gameplay_input_in_callback` (with Tier 1 exception list: `Menu` #18 + `PauseHandler` + `ActiveProfileTracker`; Tier 3 carve-out: AT bridge via `AssistiveInputBridge` class_name prefix OR `_at_bridge_exempt: bool` marker — B22 fix 2026-05-11) + `wall_clock_in_input_logic` + `deadzone_in_consumer` (3 신규)
    - `api_decisions.pause_handler_autoload` + `active_profile_tracker` (2 신규 autoload)
    - `last_updated` 필드 갱신.

#### F.4.2 Reciprocity Obligations on Unwritten GDDs (deferred — applied when each target GDD is authored)

미작성 GDD의 작성 시 *각 GDD 자체*에 본 GDD 참조 의무.

1. **#7 Player Shooting** GDD: `shoot` action detect mode 결정 (edge `just_pressed` vs hold `is_action_pressed`) — 본 GDD C.1.1 row 7 update + AC mirror.
2. **#13 HUD** GDD: first-death prompt 시각 시방 + 12프레임 fade + KB_M/GAMEPAD label switching. cross-ref input.md C.1.5 + D.1.
3. **#18 Menu/Pause UI** GDD: ✅ Closed 2026-05-13 by `design/gdd/menu-pause.md` — UI/Menu `_input` exception is limited to navigation/confirm/cancel/slider/focus repair, no gameplay polling, no new Tier 1 InputMap actions, and PauseHandler remains the pause toggle authority.
4. **#20 Difficulty Toggle** GDD: zero InputMap mutation 확인 (`RewindPolicy` data만 변경 — Input C.2 Tier 2 invariant 수용).
5. **#23 Input Remapping** (Tier 3) GDD: (a) `default_only` Reset-to-Defaults invariant 수용; (b) chord 바인딩 시 1-frame latency UI advisory 표시; (c) paused-tree apply 경유 (`SettingsManager` 패턴).
6. **#22 Localization** (Tier 3) GDD: 본 GDD button-label 문자열 (`[Shift] Rewind`, `[LT] Rewind` Tier 1 + Tier 3 player-rebound chord 변형) 다국어 키 등록.
7. **#24 Accessibility** (Tier 3) GDD: deadzone 슬라이더 UI는 `SettingsManager.apply_deadzone()` 호출 — Input 직접 mutate 금지 (input.md C.1.3).
8. **GUT Test Helper** (`tests/helpers/input_test_helper.gd`): `Input.action_press` *xor* `parse_input_event` 일관 패턴 강제 — 두 API 혼용 헬퍼 함수 제공 안 함 (E-IN-16 차단).

### F.5 Engine / Platform Dependencies

| 항목 | 버전 / 보장 | 의존도 |
|---|---|---|
| Godot Engine | **4.6** (pinned `docs/engine-reference/godot/VERSION.md` 2026-05-08) | Hard — Input API 핵심 |
| GDScript | 4.6 정적 타이핑 | Hard — `InputActions` const class 패턴 |
| SDL3 게임패드 드라이버 | Godot 4.5+ 내장 | Hard — Steam Deck 호환성 |
| `Input.get_vector` radial composite deadzone | 4.4+ stable | Hard — D.1 / E-IN-1 의존 |
| `Input.action_press` / `Input.parse_input_event` | 4.4+ stable | Hard — GUT 테스트 의존 |
| Steam Input Big Picture | Valve OS-level | **거부** (E-IN-12) — 플레이어 책임 |
| Forward+ 렌더러 / Jolt 물리(3D) | N/A | Echo 2D는 무관 |

## G. Tuning Knobs

본 절은 Input 시스템의 *디자이너 조정 가능* 값을 단일 출처로 등록한다. 각 항목은 `[default]` + `[safe range]` + `[조정 시 영향]` + `[조정 권한 owner]`. 게임플레이상 의미 있는 모든 시간/거리/힘 윈도우는 *소비자 GDD 단일 출처* (PM jump_buffer / SM rewind window / time-rewind ring buffer 길이) — 본 GDD가 *직접 owns*하는 knob은 아래 4건뿐이다.

### G.1 Owned Tuning Knobs (Input 단독 조정 영역)

| # | Knob | Default | Safe Range | 영향 | 소스 | 조정 권한 |
|---|---|---|---|---|---|---|
| G.1.1 | `gamepad_stick_deadzone` | **0.2** | 0.05–0.4 (단, **INVARIANT-IN-2**: G.1.1 + 0.05 ≤ G.1.3 — 둘 다 0.4면 boot assert fail) | 너무 낮음(<0.1) → Steam Deck 1세대 stick drift가 movement 발화. 너무 높음(>0.3) → 의도적 미세 입력 손실 (PM B10 hysteresis 같이 무너짐). PM의 `facing_threshold_outside` 와 *동기화* 권장 (현재 둘 다 0.2). **Cross-knob (B10 fix 2026-05-11)**: D.3 INVARIANT-IN-1/IN-2가 G.1.3와의 ≥0.05 마진을 강제 — boot assert 위반 시 게임 시작 실패. | `project.godot` `[input]` 4 move actions × `deadzone` 필드. C.1.3 + D.3 + Tier 3 `SettingsManager.apply_deadzone()`. | Tier 1: 디자이너 한 번 lock; Tier 3: 플레이어 슬라이더 (#24 Accessibility) — 슬라이더 max=`G.1.3 − 0.05` 동적 클램프. |
| G.1.2 | `HYSTERESIS_FRAMES` | **180** (3초 @60fps) | 60–600 (1–10초). 0 금지 (boot assert — R5 fix 2026-05-11) | 너무 짧음(60 = 1초) → 마우스 brush로 즉시 KB_M flip → first-death prompt label 잘못 표시. 너무 김(600 = 10초) → 디바이스 교체 후 10초 stale label. **0 = silent GAMEPAD-sticky** (delta_frames < 0은 항상 false → 1st 분기 영구 miss → fallback이 KB_M sticky로 영구 고정) — D.3 boot assert가 차단. | D.1.2 Part B; ActiveProfileTracker autoload. | 디자이너 (Tier 2 playtest 후 조정 가능). |
| G.1.3 | `GAMEPAD_DETECTION_THRESHOLD` | **0.3** | 0.2–0.5 (단, **INVARIANT-IN-1**: G.1.1 < G.1.3 strict; **INVARIANT-IN-2**: G.1.3 − G.1.1 ≥ 0.05) | 너무 낮음(0.2) → Steam Deck stick drift가 GAMEPAD profile flip(false positive). 너무 높음(0.5) → 미세 의도적 게임패드 input이 KB_M에 머무름. `gamepad_stick_deadzone`(0.2) 위 50% 마진 권장. **B10 fix 2026-05-11**: D.3 boot assert가 G.1.1 ≥ G.1.3 또는 마진 < 0.05 시 게임 시작 차단 (degenerate range 회피). | D.1.1 + D.3; ActiveProfileTracker `_input` 분류기. | 디자이너 (OQ-IN-3 — Tier 1 Week 1 Steam Deck 1세대 검증 후 lock). |
| G.1.4 | `first_death_prompt_label_format` | **`"[{key}] Rewind"`** | freeform string template | label 형식 변경 (예: `"{key}: 시간 되감기"` 다국어 / `"{key} → REWIND"` 시그니처 톤). placeholder `{key}` 한 개 의무. | C.1.5; ActiveProfileTracker `button_label()` API. | 디자이너 + (Tier 3) Localization #22. |

### G.2 Cross-Doc Knobs Referenced By Input (다른 GDD 단일 출처)

본 GDD가 *읽고 의존하지만 소유하지 않는* knob들 — 변경은 owner GDD에서.

| Knob | Owner | Input 의존 방식 |
|---|---|---|
| `LT_TRIGGER_THRESHOLD` (`JOY_AXIS_TRIGGER_LEFT` activation) | **time-rewind.md C.3 #1** | InputMap binding의 axis_value threshold (0.5). 변경 시 본 GDD C.3.2 Gamepad row + state-machine.md `_trigger_held` gate 동시 갱신 의무. |
| `dying_window_frames` (`D` 12 frames default) | **time-rewind.md G** | first-death prompt 표시 시간 = DYING grace window. 본 GDD C.1.5는 직접 의존 — D=8(Hard) 시 prompt 8 frames만 표시. |
| `input_buffer_pre_hit_frames` (`B` 4 frames default) | **time-rewind.md G** | `rewind_consume` 입력 윈도우 상한. 본 GDD는 polling discipline만 보장; 윈도우 술어는 SM 단일 출처. |
| `jump_buffer_frames` (6 frames default) | **player-movement.md G.1** | `jump` action edge 폴링 → PM이 `Engine.get_physics_frames()` 차감으로 윈도우 관리. Input은 polling 시점만 보장. |
| `coyote_frames` (6 frames default) | **player-movement.md G.1** | 동일 — PM 단일 출처. |
| `facing_threshold_outside` (0.2 default) | **player-movement.md G.1** | PM B10 unfix 상태에서 본 GDD `gamepad_stick_deadzone`(0.2)와 *동치 충돌*. PM B10 fix 후 `facing_threshold_inside=0.15` / `facing_threshold_outside=0.2` 비대칭 → Input deadzone과 분리. |

### G.3 Rejected Knobs (의도적 비-tunable)

다음 항목은 본 GDD가 *의도적으로* knob화하지 않는다 — 이유는 단일 출처/결정성/Tier 1 scope 보호.

| 거부된 knob | 이유 |
|---|---|
| `single_button_no_chord_invariant` (Tier 1) | technical-preferences.md hard rule. Tier 1에서는 *플래그가 아닌 invariant*. Tier 3 `default_only` interpretation이 default 매핑에 한정. |
| 9-action 카탈로그 자체 (action 추가/삭제) | C.1.1 단일 출처. 새 action은 GDD revise + cross-doc 동기화 필요 — knob 아님. |
| KB+M / Gamepad 디폴트 매핑 (C.3.1, C.3.2) | Tier 1 invariant — Pillar 4(5분 룰) 보장. Tier 3 #23 remap이 *플레이어*에게 권한 위임. 디자이너가 디폴트 변경 시 GDD revise. |
| `_input` ↔ `_physics_process` 폴링 site 결정 | C.1.2 Rule 1 architectural invariant. 변경 시 ADR-0003 결정성 계약 위반. |
| `process_physics_priority` 사다리(player=0/TRC=1/...) | ADR-0003 단일 출처. Input은 노드 아님 — 슬롯 없음. |
| `wall_clock_in_input_logic` 금지 | D.2 `forbidden_pattern` 후보 — knob 아님. |
| 첫-사망 prompt 1회 latch (세션당 1번) | C.1.5 invariant. 매 사망 표시는 Pillar 4 위반(5분 룰 spam). |

### G.4 Tuning Workflow

1. **Tier 1 prototype (Week 1)**: `gamepad_stick_deadzone` 0.2 + `HYSTERESIS_FRAMES` 180 + `GAMEPAD_DETECTION_THRESHOLD` 0.3 디폴트로 시작. 물리 Steam Deck 1세대 + Xbox Series 컨트롤러 + 키보드/마우스 3-디바이스 5분 manual 검증.
2. **OQ-IN-2/IN-3 closure**: Steam Deck stick drift가 0.2 deadzone 위에 머무르는지, 0.3 detection threshold가 false positive 0건인지 검증 → lock.
3. **Tier 2 playtest (월 단위)**: `HYSTERESIS_FRAMES` 후보 60/180/300 비교 — first-death prompt label 정확성 + Pillar 4 부합성.
4. **Tier 3 Accessibility (#24)**: `gamepad_stick_deadzone`을 *플레이어 슬라이더* (0.05–0.4 range)로 노출. `SettingsManager.apply_deadzone()` paused-tree mutation 경로(C.1.3).

## Visual/Audio Requirements

본 시스템은 Foundation/Infrastructure 레이어로 *직접* 시각·오디오 출력이 없다. 그러나 두 영역에서 다른 시스템에 *데이터를 제공*한다 — 시각화/오디오 렌더링은 각 owner GDD 단일 출처.

### V/A.1 First-Death Prompt — Label String Provider (Input → HUD #13)

- **Input 책임**: C.1.5 + D.1.2가 제공하는 button-label string (`[Shift] Rewind` / `[LT] Rewind`).
- **HUD #13 책임 (Approved 2026-05-13)**: 시각 렌더링, 위치, 크기, 색, 12-frame fade 애니메이션, 콜라주 톤 정합. art-bible Section 1 Principle B (사진 + 드로잉 둘 다) 준수 — prompt 자체가 콜라주 컷아웃 스타일.
- **art-direction status**: HUD #13 approved a Tier 1 minimal prompt treatment; exact glyph/icon asset pass remains for UX/asset-spec.

### V/A.2 Pause Menu Transition — No Input-Side Visuals

PauseHandler는 `get_tree().paused` 토글만 — 메뉴 진입/퇴장 시각 효과는 #18 Menu/Pause UI GDD owner. Input은 "pause" action 도달 + SM `can_pause()` 게이트만 처리.

### V/A.3 Audio — None (Foundation)

Input은 *직접* 오디오 큐를 발화하지 않는다. 입력에 반응한 오디오(점프 SFX, 사격 SFX, 시간되감기 SFX)는 각 owner GDD(PM #6 / Player Shooting #7 / Time Rewind #9) — Input의 역할은 *입력 도달 시점*만 결정성 있게 보장.

### V/A.4 Tier 3 Accessibility 시청각 영역 (#24 owner)

- 시각: deadzone 슬라이더 UI는 #24 GDD 시방.
- 오디오: rebind UI navigation SFX는 #18 + #24 GDD 시방.
- 본 GDD 직접 deliverable 0건.

## UI Requirements

본 시스템은 Tier 1에서 직접 UI 위젯을 소유하지 않는다. UI 영향은 *데이터 제공* 형태로만 발생.

### UI.1 First-Death Prompt 데이터 (HUD #13 owner)

- **Input 제공**: `button_label(profile: DeviceProfile, action_id: StringName) → String` 읽기 전용 API.
- **HUD #13 호출 시점**: SM `first_death_in_session` 신호 수신 시 1회.
- **반환 형식**: `[{key}] {label_text}` (G.1.4 tunable).
- **Tier 1 stub**: `[Shift] Rewind` / `[LT] Rewind` 두 형식만. Localization 없음 (영어 전용, Anti-Pillar #6).

### UI.2 Tier 3 Input Remapping UI (#23 owner)

- **본 GDD 미직접 소유**. #23 GDD가 InputMap 동적 mutation UI 시방.
- **Input 측 제약**: (a) `default_only` Reset-to-Defaults invariant — chord 0건; (b) chord 바인딩 시 1-frame latency advisory 표시 의무 (cross-doc obligation).
- **paused-tree apply 강제**: `SettingsManager.apply_remap()` 패턴 — runtime mid-tick mutation 금지 (C.1.3 deadzone과 동일 패턴).

### UI.3 Tier 3 Accessibility — Deadzone Slider (#24 owner)

- **본 GDD 미직접 소유**. #24 GDD가 슬라이더 위젯 시방.
- **Input 측 제약**: `SettingsManager.apply_deadzone(value: float)` 호출 → paused-tree mutation. 슬라이더 range = G.1.1 safe range (0.05–0.4).

### UI.4 Tier 1 Title / Boot UI 영향 없음

E-IN-14(cold boot 디바이스 미연결) 시 title/Story Intro #17 화면 대기 — 별도 "Press any key to start" UI 없음 (Pillar 4). 입력이 들어오면 자연스럽게 game start 트리거 (`#2 Scene Manager` owner). Story Intro #17은 입력 API를 직접 읽지 않고, 이 기존 cold-boot route가 발생시키는 scene transition으로 interrupt된다.

## H. Acceptance Criteria

본 절은 Input 시스템의 *독립적으로 검증 가능한* 합격 조건을 단일 출처로 등록한다 (qa-lead consult — 20 entries: 19 BLOCKING + 1 ADVISORY). 각 AC는 GIVEN / WHEN / THEN 형식 + cross-ref. **Script-Existence Discipline** (PM B2 trap learning): script을 cite하는 모든 AC는 그 script 파일을 *deliverable*로 본 GDD가 명시; meta-runner `tools/ci/run_static_checks.sh`가 모든 expected script 존재를 boot-time에 assert.

> **PM B4 trap 회피**: callback purity 검증은 Python multiline regex 사용 — awk-range pattern은 single-line body에서 collapse(`func _input(e): pass` 같은 케이스 silent skip)되므로 금지. 4 adversarial fixtures(one-line pass / empty body / logic-in-callback / no-func)로 recipe 자체 검증 후 gate 채택.

### H.1 Action Catalog (C.1.1)

**AC-IN-01** *(Logic GUT — BLOCKING)* — 9 actions exist in InputMap with correct primary event type.
GIVEN the game project is opened in Godot 4.6.
WHEN InputMap is queried for each of the 9 action names in C.1.1.
THEN each action exists AND its primary event matches the type column (Key / MouseButton / JoypadButton / JoypadMotion) as specified in the golden snapshot `tests/fixtures/input_map_default_snapshot.tres`.
_cross-ref: C.1.1 action catalog._

**AC-IN-02** *(Logic GUT — BLOCKING)* — InputActions const class has exactly **the 9-action StringName set** matching InputMap (B20 fix 2026-05-11: name-set equality, NOT just count + has_action).
GIVEN `InputActions` class is loaded + expected set `EXPECTED: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"aim_lock", &"shoot", &"rewind_consume", &"pause"]` (C.1.1 9-action catalog verbatim).
WHEN all const StringName members are collected into `ACTUAL: Array[StringName]`.
THEN (a) `ACTUAL.size() == EXPECTED.size()` AND `EXPECTED.all(func(e): return ACTUAL.has(e))` AND `ACTUAL.all(func(a): return EXPECTED.has(a))` — *exact set equality* (multiset since all StringNames unique); AND (b) for each `v in ACTUAL`: `InputMap.has_action(v) == true`. **Earlier draft (`count == 9 AND has_action(v)`) silent false-pass**: rename `jump → leap` while keeping const count 9 AND adding `leap` to InputMap → 카운트 통과 + has_action 통과 → silent rename. Set-equality 강제는 *exact* 9 StringName 매치로 rename 차단.
_cross-ref: C.4 + C.1.1._

### H.2 Polling Discipline (C.1.2)

**AC-IN-03** *(Logic GUT — BLOCKING)* — Cascade invariant: **5 consumers** read same action state in same tick + edge transitions decay synchronously + frame stamps prove non-trivial assertion (B1 fix 2026-05-11; B.2 Pillar 2 verification).
GIVEN `cascade_5_consumer_harness` scene with 5 mock nodes — PM #6 (gameplay), SM #5 AliveState (lifecycle), TRC #9 (rewind), Player Shooting #7 (combat), Menu #18 (pause). Each consumer stamps `(poll_value: bool, poll_frame: int)` pair from `Engine.get_physics_frames()` on every Phase 2 read.
WHEN scenario (a) — press cascade: `Input.action_press(InputActions.REWIND_CONSUME)` then `await get_tree().physics_frame`.
THEN ALL 5 `poll_value == true` AND ALL 5 `poll_frame` values pairwise equal (== expected tick). Pairwise frame equality is the *non-trivial* assertion — a false implementation where consumers polled different ticks would fail frame equality even with all-`true` values (corrects original 3-consumer trivially-true assertion: 3 consumers reading same global state is auto-true and proves nothing about per-tick atomicity).
WHEN scenario (b) — release cascade (edge-cleared): immediate `Input.action_release(InputActions.REWIND_CONSUME)` then `await get_tree().physics_frame`.
THEN ALL 5 `poll_value == false` AND ALL 5 `poll_frame` pairwise equal AND `poll_frame[next_tick] == poll_frame[prev_tick] + 1` (single-tick decay; no consumer 1-tick stale).
WHEN scenario (c) — third tick stability: no further input + `await get_tree().physics_frame`.
THEN ALL 5 `poll_value == false` AND `poll_frame` advances by exactly 1 across all consumers.
**Deliverable**: write `tests/helpers/cascade_5_consumer_harness.gd`. PS/Menu mocks are Tier-1 stubs (F.4.2 #1/#3 surfaces — minimal `_physics_process` Phase 2 poll only; no gameplay logic required for harness pass).
_cross-ref: C.1.2 Rule 1 + B.2 Cascade (5 consumers declared) + ADR-0003._

**AC-IN-04** *(Static analysis — BLOCKING)* — No inline action string literals in src/.
GIVEN `tools/ci/input_action_static_check.sh` is run against `src/`.
WHEN grep matches `Input\.[a-z_]+\(\s*&?"` in any `.gd` file.
THEN exit code 1 if any match is NOT of the form `InputActions.[A-Z_]+`; exit 0 otherwise.
**Deliverable**: write `tools/ci/input_action_static_check.sh` AND `tools/ci/run_static_checks.sh` meta-runner that asserts all expected CI scripts exist (exit 1 if any missing) before invoking them. *PM B2 prevention.*
_cross-ref: C.4._

**AC-IN-05** *(Static analysis — BLOCKING)* — No gameplay logic in `_input` / `_unhandled_input` callbacks of PM/SM/TRC/PS.
GIVEN `tools/ci/_input_purity.py` is run against PM, SM, TRC, PS source files.
WHEN the script searches for `func _input` / `func _unhandled_input` bodies using *Python multiline regex* (NOT awk-range — B4 trap avoidance).
THEN exit code 1 if any body contains non-pass, non-empty, non-comment lines. Exit code 0 if all callbacks are absent, empty, or single-line `pass`.
**Deliverable**: write `tools/ci/_input_purity.py` AND `tools/ci/input_callback_purity_check.sh` wrapper. Test the script against 4 adversarial fixtures (`fixture_one_line_pass.gd` / `fixture_empty_body.gd` / `fixture_logic_in_callback.gd` / `fixture_no_func.gd`) before accepting as gate.
_cross-ref: C.1.2 Rule 2._

### H.3 Deadzone (C.1.3)

**AC-IN-06** *(Logic GUT — BLOCKING)* — `project.godot` deadzone 0.2 for all 4 move actions.
GIVEN the project is running.
WHEN `InputMap.action_get_deadzone(InputActions.MOVE_LEFT)` (and the other 3 move actions) is queried.
THEN all 4 return 0.2.
_cross-ref: C.1.3._

**AC-IN-07** *(Logic GUT — BLOCKING)* — Radial composite deadzone suppresses sub-threshold input.
GIVEN 4 move actions configured with deadzone 0.2.
WHEN fixture injects JoypadMotion events for all 4 axes at strength 0.15 (<0.2).
THEN `Input.get_vector(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.MOVE_UP, InputActions.MOVE_DOWN).length() == 0.0`.
_cross-ref: C.1.3 + E-IN-1._

**AC-IN-08** *(Static analysis — BLOCKING)* — No `deadzone_in_consumer`: no hardcoded `0.2` axis checks in PM/SM/TRC src/.
GIVEN `tools/ci/deadzone_consumer_check.sh` is run against PM, SM, TRC source files.
WHEN grep searches for pattern `>\s*0\.2` adjacent to a joy axis read.
THEN exit code 1 on any match; exit code 0 if none.
**Deliverable**: write `tools/ci/deadzone_consumer_check.sh`.
_cross-ref: C.1.2 Rule 5 + C.1.3._

**AC-IN-09** *(Logic GUT — BLOCKING)* — Runtime deadzone mutation via `SettingsManager` only, in paused tree.
GIVEN deadzone is 0.2 at start.
WHEN `SettingsManager.apply_deadzone(0.1)` is called (which internally pauses tree, mutates, unpauses).
THEN before call: `InputMap.action_get_deadzone(InputActions.MOVE_LEFT) == 0.2`. After `await get_tree().physics_frame`: value == 0.1 AND mutation occurred while `get_tree().paused == true` (verified via spy).
_cross-ref: C.1.3 + G.1.1._

**AC-IN-22** *(Logic GUT — BLOCKING)* — D.3 cross-knob invariant boot assert fires on degenerate config (B10 fix 2026-05-11).
GIVEN ActiveProfileTracker `_ready()` is invoked.
WHEN test fixture A sets `project.godot` move-action deadzone to 0.30 + `GAMEPAD_DETECTION_THRESHOLD` const = 0.30 (INVARIANT-IN-1 violation: equal).
WHEN test fixture B sets deadzone 0.30 + threshold 0.32 (INVARIANT-IN-2 violation: margin 0.02 < 0.05).
WHEN test fixture C sets deadzone 0.20 + threshold 0.30 (valid: margin 0.10 ≥ 0.05).
THEN fixture A: `_ready()` raises assertion (INVARIANT-IN-2 with margin 0.0). Fixture B: assertion (margin 0.02 < 0.05). Fixture C: no assertion, `_ready()` completes normally.
_cross-ref: D.3 + G.1.1 + G.1.3._

**AC-IN-23** *(Logic GUT — BLOCKING)* — D.1.1 axis filter rejects unbound-axis profile flips (B8 fix 2026-05-11).
GIVEN ActiveProfileTracker is at `_last_input_source = KB_M`, `_last_input_frame = current − 50` (within hysteresis but KB_M sticky).
WHEN fixture dispatches `InputEventJoypadMotion` with `axis = JOY_AXIS_RIGHT_X`, `axis_value = 0.6` (above GAMEPAD_DETECTION_THRESHOLD 0.3 but unbound axis).
THEN `_last_input_source` remains `KB_M`. `_last_input_frame` not updated. (Right-stick drift cannot silently flip profile.)
WHEN second dispatch with `axis = JOY_AXIS_LEFT_X`, `axis_value = 0.4`.
THEN `_last_input_source = GAMEPAD`, `_last_input_frame = current_frame` (left-stick is in PROFILE_AXES whitelist).
_cross-ref: D.1.1 + B8 axis filter rationale._

### H.4 PauseHandler (C.1.4)

**AC-IN-10** *(Logic GUT — BLOCKING)* — PauseHandler autoload `process_mode == PROCESS_MODE_ALWAYS`.
GIVEN PauseHandler is registered as autoload.
WHEN `process_mode` is queried at runtime.
THEN `process_mode == Node.PROCESS_MODE_ALWAYS`.
_cross-ref: C.1.4._

**AC-IN-11** *(Logic GUT — BLOCKING)* — Resume always allowed; SM cannot veto unpause.
GIVEN `get_tree().paused == true`.
WHEN fixture dispatches `pause` InputEventAction via `PauseHandler._unhandled_input`.
THEN `get_tree().paused == false` after `await get_tree().physics_frame`. (SM.can_pause() is NOT queried on resume path — verified via SM spy.)
_cross-ref: C.1.4 + E-IN-9._

**AC-IN-12** *(Logic GUT — BLOCKING)* — SM veto blocks pause when `can_pause()` returns false.
GIVEN SM mock configured with `can_pause()` returning false (DYING or REWINDING state).
WHEN fixture dispatches `pause` InputEventAction while `get_tree().paused == false`.
THEN `get_tree().paused` remains false after `await get_tree().physics_frame`.
_cross-ref: C.1.4 + E-IN-7._

### H.5 First-Death Hint (C.1.5)

**AC-IN-13** *(Logic GUT — BLOCKING)* — First-death hint latch 정책: prompt show on every DYING, HUD-local permanent dismiss on first rewind success, scene-change re-arm (B15).
GIVEN SM mock emits `first_death_in_session(profile)` per O7 + `first_rewind_success_in_session(profile)` per O8 + `scene_will_change` per O6 cascade. HUD spy owns `_first_rewind_success_latched: bool` (init false) + `prompt_show_count: int = 0`.
WHEN scenario (a) — repeat without success: `ALIVE→DYING` 2회 (no `REWINDING→ALIVE` between).
THEN `first_death_in_session` received 2회 AND HUD `prompt_show_count == 2` AND `_first_rewind_success_latched == false`.
WHEN scenario (b) — first success closes latch: `ALIVE→DYING` (1차) → `REWINDING→ALIVE` with `_lethal_hit_latched_prev == true` (= `first_rewind_success_in_session` emit) → `ALIVE→DYING` (2차).
THEN `first_rewind_success_in_session` received exactly 1회 AND `_first_rewind_success_latched == true` after emit AND 2차 DYING의 `first_death_in_session` received 1회 BUT `prompt_show_count` delta == 0 (HUD-local latch suppressed).
WHEN scenario (c) — scene-change re-arm: scenario (b) 종료 직후 `scene_will_change` emit + `ALIVE→DYING` (3차).
THEN `_first_rewind_success_latched == false` after HUD scene-change handler AND 3차 `first_death_in_session` emit → `prompt_show_count` delta == 1.
WHEN scenario (d) — per-session idempotency: 세션 내 `REWINDING→ALIVE` 2회 (e.g., 2개 토큰 모두 lethal-driven 소비).
THEN `first_rewind_success_in_session` received 정확히 1회 (NOT per-rewind) AND SM `_session_first_success_emitted == true` after 1차.
WHEN scenario (e) — hazard-grace 자연 회복 제외: `REWINDING→ALIVE` 전이 with `_lethal_hit_latched_prev == false`.
THEN `first_rewind_success_in_session` emit 0회 (Pillar 1: 첫 *진짜* 성공만 학습 증명).
**Deliverable**: HUD spy fixture `tests/helpers/first_death_hint_spy.gd`.
_cross-ref: C.1.5 + state-machine.md C.2.2 O7/O8._

**AC-IN-14** *(Logic GUT — BLOCKING)* — `button_label` returns correct strings for each device profile.
GIVEN `ActiveProfileTracker` is initialized.
WHEN `button_label(DeviceProfile.GAMEPAD, InputActions.REWIND_CONSUME)` is called.
THEN returns `"[LT] Rewind"`.
WHEN `button_label(DeviceProfile.KB_M, InputActions.REWIND_CONSUME)` is called.
THEN returns `"[Shift] Rewind"`.
_cross-ref: C.1.5 + D.1._

### H.6 Default Bindings (C.3)

**AC-IN-15** *(Logic GUT — BLOCKING)* — Default bindings: 9 actions × 2 profiles match golden snapshot (18 rows).
GIVEN `tests/fixtures/input_map_default_snapshot.tres` golden resource — **Resource schema**: `class_name InputMapSnapshot extends Resource` with `@export var actions: Array[StringName]` (9-action catalog per C.1.1 verbatim), `@export var kb_m_bindings: Dictionary` (StringName → InputEvent), `@export var gamepad_bindings: Dictionary` (StringName → InputEvent), `@export var deadzones: Dictionary` (StringName → float). Full schema spec + production class location: **Appendix A.6.1** (B12 fix 2026-05-11).
WHEN InputMap is compared against the snapshot at game start (before any remapping).
THEN zero divergent rows. CI failure message names the specific action + profile that diverged.
**Deliverable**: write `src/input/input_map_snapshot.gd` (Resource class per A.6.1) + `tests/fixtures/input_map_default_snapshot.tres` (instance populated from C.3.1/C.3.2 + A.2 reference snapshot).
_cross-ref: C.3.1 + C.3.2 + **A.6.1**._

**AC-IN-16** *(Logic GUT — BLOCKING)* — AimLock-jump exclusivity: both actions independently visible same tick.
GIVEN PM mock observing `aim_lock` and `jump` action states.
WHEN fixture injects `aim_lock` hold AND `jump` `just_pressed` in same physics frame (no chord swallow).
THEN `Input.is_action_pressed(InputActions.AIM_LOCK) == true` AND `Input.is_action_just_pressed(InputActions.JUMP) == true` simultaneously.
_cross-ref: C.3.3 verbatim GIVEN/WHEN/THEN._

### H.7 Active Profile Formula (D.1)

**AC-IN-17** *(Logic GUT — BLOCKING)* — D.1.2 `active_profile()` formula: all 7 worked scenarios pass.
GIVEN `ActiveProfileTracker` autoload polled via **ActiveProfileMock node** (`tests/helpers/active_profile_mock.gd` — `class_name ActiveProfileMock extends Node` with public `_last_input_source: StringName` + `_last_input_frame: int` + `_hysteresis_frames: int = 180` writable members, replicating D.1.2 `active_profile()` formula verbatim). **Override pattern**: Test injects mock as test-scene child (NOT autoload override) — production code continues to use `ActiveProfileTracker` autoload; AC-IN-17 fixture wires `active_profile_provider := mock` 통해 *formula isolation* 검증. Full mock spec: **Appendix A.6.2** (B13 fix 2026-05-11).
WHEN scenarios 1–5 from D.1.2 AND E-IN-6 (KB Shift while LT<0.5 → KB_M profile) AND cold-boot j=0 (→ KB_M fallback) are each executed.
THEN `active_profile()` returns the expected `DeviceProfile` enum value for each scenario.
**Deliverable**: write `tests/helpers/active_profile_mock.gd`.
_cross-ref: D.1.2 worked examples + D.1.1 + E-IN-6._

### H.8 Wall-Clock Exclusion (D.2)

**AC-IN-18** *(Static analysis — BLOCKING)* — No wall-clock API calls in src/.
GIVEN `tools/ci/wall_clock_check.sh` is run against `src/`.
WHEN grep searches for `Time\.get_ticks_msec\|Time\.get_ticks_usec\|OS\.get_ticks_msec`.
THEN exit code 1 on any match; exit code 0 if none.
**Deliverable**: write `tools/ci/wall_clock_check.sh`.
_cross-ref: D.2._

### H.9 GUT Injection Contract (E-IN-16 closure)

**AC-IN-19** *(Logic GUT — BLOCKING)* — GUT helper enforces single-API injection; mixing APIs causes assertion.
GIVEN `tests/helpers/input_action_press_helper.gd` AND `tests/helpers/input_event_inject_helper.gd`.
WHEN a test calls both helpers on the same action within the same fixture.
THEN test-helper internal assertion fires, failing the test with explicit "API mix" error. (Prevents false positives from idempotent double-set; enforces C.1.2 Rule 4.)
**Deliverable**: write `tests/helpers/input_action_press_helper.gd` AND `tests/helpers/input_event_inject_helper.gd`.
_cross-ref: C.1.2 Rule 4 + E-IN-16._

### H.10 PauseHandler Input Consumption (E-IN-NEW closure)

**AC-IN-24** *(Logic GUT — BLOCKING; renumbered from AC-IN-20-A per B17 fix Session 14 2026-05-11 — ID collision with AC-IN-20 F.4.1 ledger resolved)* — `PauseHandler` calls `set_input_as_handled()` on both veto and resume paths.
GIVEN PauseHandler instantiated with a mock viewport spy.
WHEN `pause` action is dispatched with SM returning `can_pause() == false` (veto path).
THEN `get_viewport().set_input_as_handled()` is called once.
WHEN `pause` action is dispatched while tree is already paused (resume path).
THEN `get_viewport().set_input_as_handled()` is called once.
_cross-ref: C.1.4 + E-IN-NEW._

### H.11 F.4.1 Cross-Doc Ledger (Manual)

**AC-IN-20** *(Manual — BLOCKING; reclassified ADVISORY → BLOCKING per B19 fix Session 14 2026-05-11)* — F.4.1 cross-doc obligation batch fully applied before story closure.
**Reclass rationale**: F.4.1 closes OQ-SM-3 + OQ-15 (resolved-by-this-GDD) + 4 player-movement.md provisional flags + 13 reciprocal GDD/registry edits. *Until those edits land*, cross-doc claims in this GDD are unverified and downstream programmers reading state-machine.md / time-rewind.md / player-movement.md will see stale or contradictory references. Gate severity matches Logic-AC blocker level even though verification mechanism is git-diff manual check (not unit test).
GIVEN all 13 F.4.1 items are tracked in `production/qa/input-f41-batch.md`.
WHEN the Input System story is marked Done.
THEN all 13 checklist items are checked AND git diff against the 4 target GDD files (player-movement.md, state-machine.md, time-rewind.md, systems-index.md) + `architecture.yaml` shows the expected provisional-flag removals, naming unifications, and registry additions. **AC fails (BLOCKING)** if any checklist item unchecked OR git diff shows unmade changes.
**Deliverable**: write `production/qa/input-f41-batch.md` checklist file.
_cross-ref: F.4.1 #1–13._

### H.11b Pillar 4 (5-min Rule) Manual Validation — B2 fix 2026-05-11

**AC-IN-21** *(Playtest — ADVISORY)* — Pillar 4 "no-menu, no-confirmation" cold-boot times: first jump ≤30s median, first shoot ≤60s median, first rewind_consume ≤300s median (B.2 line 60 invariant verification).
GIVEN N=5 first-time playtesters per QA plan sampling (audience profile: action-platformer experience ≥ Hotline Miami / Cuphead familiarity; never played Echo). Test rig: Steam Deck 1세대 (preferred) or KB+M PC, cold-boot from desktop. No instructions beyond "ECHO를 플레이해라". Observer timestamps each first-event manually.
WHEN each playtester is timed from `executable_launch` to: (a) first `jump` action firing in gameplay, (b) first `shoot` action firing, (c) first `rewind_consume` action firing in DYING window (= a *consumed* rewind on lethal hit, NOT incidental ALIVE-state press).
THEN median(t_jump) ≤ 30s AND median(t_shoot) ≤ 60s AND median(t_rewind) ≤ 300s. *Any* median miss triggers Pillar 4 review (revisit default mapping C.3 + first-death hint C.1.5).
**Note**: Cold-boot = wall-clock from process spawn (Godot splash + main menu included). Steam Deck assumes *warm* shader cache (cold cache adds ≤15s but is excluded from t_jump per protocol).
**Sample size rationale**: N=5 is *minimum* for median stability; if any single playtester exceeds threshold by >50%, escalate to N+5 (max N=15) for distributional confirmation.
**Deliverable**: write `production/qa/pillar4-5min-rule-playtest.md` protocol template with: (a) audience-fit screening criteria, (b) observer log sheet, (c) per-tester timestamp aggregator + median calc, (d) threshold flag + escalation criteria.
_cross-ref: B.2 line 60 (5-min rule invariant) + C.3 default keymap + C.1.5 first-death hint._

### H.12 Coverage Summary

| 그룹 | AC 수 | BLOCKING | ADVISORY |
|---|---|---|---|
| H.1 Action Catalog | 2 | 2 | 0 |
| H.2 Polling Discipline | 3 | 3 | 0 |
| H.3 Deadzone | 6 | 6 | 0 |
| H.4 PauseHandler | 3 | 3 | 0 |
| H.5 First-Death Hint | 2 | 2 | 0 |
| H.6 Default Bindings | 2 | 2 | 0 |
| H.7 Active Profile Formula | 1 | 1 | 0 |
| H.8 Wall-Clock Exclusion | 1 | 1 | 0 |
| H.9 GUT Injection Contract | 1 | 1 | 0 |
| H.10 PauseHandler Input Consumption (AC-IN-24, was AC-IN-20-A) | 1 | 1 | 0 |
| H.11 F.4.1 Ledger (AC-IN-20, BLOCKING) | 1 | 1 | 0 |
| H.11b Pillar 4 5-min Rule (AC-IN-21) | 1 | 0 | 1 |
| **Total** | **24** | **23** | **1** |

*(2026-05-11 Session 14 Task #9 final cleanup: H.3 6 (was 4 — AC-IN-22 + AC-IN-23 added Task #5 for D.3 cross-knob invariant + D.1.1 axis filter, H.12 reflect deferred until now); H.10 AC-IN-24 (renumbered from AC-IN-20-A per B17 fix — ID collision with AC-IN-20 resolved); H.11 BLOCKING (was ADVISORY per B19 reclass — cross-doc gate severity); Total 24 (=21 prev + 2 Task #5 AC-IN-22/23 reflect + 1 net from B19 reclass migrating ADVISORY → BLOCKING). Final ID list: AC-IN-01..23 sequential + AC-IN-24.)*

### H.13 Tooling Deliverables (consolidated; B18 fix Session 14 2026-05-11: phantom F.4.1 #14 reference removed + 7 missing items added)

본 GDD AC가 강제하는 신규 테스트 인프라 + CI 스크립트. **Note**: 이전 draft는 "F.4.1 #14 batch에 포함"으로 명시했으나 F.4.1은 13 items만 존재 (phantom #14 reference). 본 list는 F.4.1과 *별개의* Tier 1 deliverable 묶음 — H.13은 AC가 deliverable로 명시한 모든 파일을 단일 출처로 추적한다.

1. `tests/helpers/input_action_press_helper.gd` (AC-IN-19)
2. `tests/helpers/input_event_inject_helper.gd` (AC-IN-19)
3. `tests/helpers/cascade_5_consumer_harness.gd` (AC-IN-03 — 5-consumer harness w/ frame stamps; B1 fix 2026-05-11)
4. `tests/helpers/active_profile_mock.gd` (AC-IN-17 — see A.6.2 class spec; B13 fix 2026-05-11)
5. `tests/fixtures/input_map_default_snapshot.tres` (AC-IN-01, AC-IN-15 — see A.6.1 Resource schema)
6. `src/input/input_map_snapshot.gd` Resource class (AC-IN-15 — production class backing #5 fixture; B12 fix 2026-05-11)
7. `tools/ci/input_action_static_check.sh` (AC-IN-04)
8. `tools/ci/_input_purity.py` + `tools/ci/input_callback_purity_check.sh` (AC-IN-05)
9. `tools/ci/deadzone_consumer_check.sh` (AC-IN-08)
10. `tools/ci/wall_clock_check.sh` (AC-IN-18)
11. `tools/ci/run_static_checks.sh` **meta-runner** — *PM B2 vaccine* (AC-IN-04)
12. `production/qa/input-f41-batch.md` checklist (AC-IN-20 — BLOCKING per B19 fix 2026-05-11)
13. `tests/fixtures/fixture_one_line_pass.gd` (AC-IN-05 adversarial #1 — B18 fix 2026-05-11: missing from earlier H.13)
14. `tests/fixtures/fixture_empty_body.gd` (AC-IN-05 adversarial #2 — B18 fix)
15. `tests/fixtures/fixture_logic_in_callback.gd` (AC-IN-05 adversarial #3 — B18 fix)
16. `tests/fixtures/fixture_no_func.gd` (AC-IN-05 adversarial #4 — B18 fix)
17. `tests/helpers/first_death_hint_spy.gd` (AC-IN-13 — B15 fix 2026-05-11; missing from earlier H.13)
18. `production/qa/pillar4-5min-rule-playtest.md` (AC-IN-21 — B2 fix 2026-05-11)

## Z. Open Questions

본 절은 본 GDD 작성 후 *미해결*로 남은 질문 + Tier 1 prototype/playtest 검증 의무를 단일 출처로 추적한다. 각 OQ는 `[owner] [target resolution]` 명시. 5 entries (qa-lead consult 후 정리).

| OQ ID | Question | Owner | Target Resolution | Risk | Notes |
|---|---|---|---|---|---|
| **OQ-IN-1** | Godot 4.6 `JOY_AXIS_TRIGGER_LEFT` semantics 변경 여부 — SDL3 (4.5+) backend에서 trigger axis가 `is_action_just_pressed` 발화 timing이 4.4와 동일한지 verify. | gameplay-programmer | Tier 1 Week 1 GUT 회귀 테스트 (LT axis_value 0.0 → 1.0 ramp + 단일 just_pressed 발화 검증) | LOW | gdscript-specialist는 *likely unchanged* — SDL3가 device enumeration만 담당하고 action-state discriminator는 영향 없음 (Q3 confidence: verified). 회귀 테스트만 추가하면 lock. |
| **OQ-IN-2** | Steam Deck 1세대 LT 마모 시 threshold 0.5 chatter rate — 물리 하드웨어 + Godot 4.6 SDL3 백엔드 5분 manual 검증. | gameplay-programmer + qa-lead | Tier 1 Week 1 *물리 Deck 1세대* manual test | MEDIUM | gdscript-specialist 명시 — "GUT만으로는 close 불가; 물리 Deck session 필수". SM `_trigger_held` gate가 chatter 흡수하므로 fail 시 stack 처리. |
| **OQ-IN-3** | `GAMEPAD_DETECTION_THRESHOLD = 0.3` 디폴트가 Steam Deck 1세대 stick drift(0.05–0.18 RMA)에 false positive 0건인지 검증. | gameplay-programmer + qa-lead | Tier 1 Week 1 *물리 Deck 1세대* manual test (OQ-IN-2 동일 세션) | LOW | 0.3 마진은 0.18 max raw 위에 약 67% 여유 — drift false positive 가능성 낮음. 0.4 fallback 권장 여부 결정. |
| **OQ-IN-4** | E-IN-13 mid-session gamepad unplug 후 stale `[LT] Rewind` label 문제 — Tier 2 fix(`Input.joy_connection_changed` 시그널 구독 → GAMEPAD hysteresis 즉시 만료)를 Tier 1에 backport 해야 하는가? | systems-designer + game-designer | Tier 2 playtest validation (월 단위) | LOW | Tier 1 accepted edge case (E-IN-13). playtest 시 mid-session unplug 빈도 측정 — 빈도 > 5% 시 Tier 1 backport. |
| **OQ-IN-5** | E-IN-11 focus-loss mid-DYING window 연장이 Echo target audience(Achievers)에게 *cheating으로 인식*되는가? | qa-lead + game-designer | Tier 2 playtest validation (월 단위) | LOW | Godot 4.6 default behavior. 변경 시 `application/run/pause_when_focus_lost = false` (또는 SM이 focus-lost를 SM lethal_hit으로 처리) — Tier 1 default 유지 권장. |
| **OQ-IN-6** | Gamepad `aim_lock=RB` + `shoot=RT` **right-hand pinch** — `aim_lock` hold(`RB` button hold) + `shoot` press(`RT` trigger) 동시 작동 시 right index/middle finger 부담이 audience(Hotline Miami / Cuphead 팬)에게 inhibitor가 되는가? B16 fix 2026-05-11 (Session 14)에서 Cuphead citation 제거 시 carve-out으로 등록된 Tier 1 risk. | ux-designer + qa-lead | Tier 1 Week 1 *물리 Deck 1세대* manual session (OQ-IN-2 동일 세션) + Tier 2 audience playtest cross-check | MEDIUM | playtester 5명 중 *3명 이상*이 5분 내 RB+RT pinch fatigue 호소 시 alternative mapping (예: `aim_lock=LB` + `rewind_consume=back paddle`) Tier 2 backport. 단, LB은 좌-우 separation 불가 → trade-off. CD: "RT는 Cuphead 정통, LT 충돌 회피" 결정 우선. |

### Z.1 Resolved-By-This-GDD (cross-doc OQ closures)

본 GDD 작성으로 *다른 GDD의 OQ가 자동 해소*됨 — Phase 5 F.4.1 batch에서 명시:

| Other GDD OQ | Resolved | 출처 |
|---|---|---|
| state-machine.md OQ-SM-3 (`rewind_consume` action 이름 확정) | ✅ | input.md C.1.1 row 8 |
| time-rewind.md OQ-15 (Tier 3 chord 정책) | ✅ `default_only` interpretation | input.md C.2 Tier 3 row |
| player-movement.md C.5.3 *(Provisional)* 4 항목 | ✅ verbatim lock | input.md C.1.3 (deadzone) + C.3.1 (KB+M) + C.3.3 (AimLock-jump) + C.1.1 (action 명명) |
| player-movement.md OQ-PM-7 (E-PM-9 deadzone Tier 1 임시 PM-side guard 필요?) | ✅ 불필요 | Input #1이 project.godot 0.2 deadzone 단일 출처로 enforce — PM-side guard 코드 추가 X |
| player-movement.md F.4.2 obligation registry "Input #1 (deadzone + AimLock-jump exclusivity)" | ✅ AC-IN-06/07 + AC-IN-16 | AC-H4-04 ADVISORY → obsolete |

### Z.2 Open-To-Other-GDDs (deferred down the chain)

본 GDD가 *제기*했으나 다른 GDD가 해소해야 할 미해결 항목 — F.4.2에 등록:

| 항목 | 다음 단계 |
|---|---|
| `shoot` action detect mode (edge vs hold) | #7 Player Shooting GDD |
| First-death prompt 시각·colors·colage tone | #13 HUD GDD + art-director consult (필수) |
| `_input` 콜백 exception protocol 명시 | #18 Menu/Pause UI GDD |
| Tier 3 chord 1-frame latency UI advisory 시각 | #23 Input Remapping GDD (Tier 3) |
| `SettingsManager.apply_deadzone()` API + paused-tree apply 패턴 | Settings/Persistence #21 GDD (Tier 2) |
| Button-label 다국어 키 | #22 Localization GDD (Tier 3) |
| `InputStateProvider` 5-method migration: raw `Input.is_action_*` / `Input.get_vector` / `Input.get_action_strength` 호출 site → `InputStateProvider.*` mechanical grep-replace. C.1.6 5-method signature *변경 금지* (backward-compat) | #24 Accessibility GDD (Tier 3) — B21 fix 2026-05-11 seam 활성화 책임 |
| AT bridge node carve-out 활성화: `AssistiveInputBridge` class_name prefix 또는 `@export var _at_bridge_exempt: bool = true` marker spec 정의 + `forbidden_patterns.gameplay_input_in_callback` 스캐너에 carve-out 매칭 로직 구현 (둘 중 하나 매치 시 검사 skip) | #24 Accessibility GDD (Tier 3) — B22 fix 2026-05-11 4번째 예외 활성화 책임 |

## Appendix

### A.1 Decision Log (본 세션 락인 결정)

| Decision | Date | 출처 | 비고 |
|---|---|---|---|
| KB+M `aim_lock` = **F** (not Shift) | 2026-05-10 | ux-designer + user pick | Shift conflict: rewind_consume이 우선 (Katana Zero precedent) |
| Tier 3 chord 정책 = **`default-only` interpretation** | 2026-05-10 | game-designer + user pick | OQ-15 closure |
| First-death onboarding = **one-time prompt** (cross-doc HUD #13 + SM) | 2026-05-10 | ux-designer + user pick | KB+M Shift discovery risk 완화 |
| Default deadzone = **0.2** (radial composite) | 2026-05-10 | gdscript-specialist + game-designer | PM 단일 출처와 동기화 |
| `HYSTERESIS_FRAMES` = **180** (3초) | 2026-05-10 | systems-designer | range 60–600 |
| `GAMEPAD_DETECTION_THRESHOLD` = **0.3** | 2026-05-10 | systems-designer | OQ-IN-3 pending Tier 1 verify |
| `PauseHandler` autoload (`PROCESS_MODE_ALWAYS` + `_unhandled_input`) | 2026-05-10 | gdscript-specialist | 4.6 canonical pattern |
| `ActiveProfileTracker` autoload (D.1) | 2026-05-10 | systems-designer | first-death prompt 디바이스 추적 |
| `InputActions` StringName const class (C.4) | 2026-05-10 | gdscript-specialist | `&"action"` literal 분산 금지 |
| 9-action 카탈로그 exact (no `weapon_swap` Tier 1) | 2026-05-10 | game-designer | #7 Player Shooting owner |
| Gamepad `aim_lock` = **RB** (left-right separation, NOT Cuphead) | 2026-05-10 (initial) / **2026-05-11 re-justify (B16 fix Session 14)** | ux-designer + CD adjudication | Initial Session 12 cite "Cuphead lock-aim precedent" — B16 verified false (web-verified Session 13: community consensus는 LT=lock, RB=avoid right-hand pinch). CD adjudication: keep RB (LT 충돌이 rewind_consume Pillar 1 위반, 더 나쁨), remove false cite. Real reason: left-right separation (rewind=LT, aim=RB). RB+RT right-hand pinch (`aim_lock`+`shoot` 동시) Tier 1 accepted risk → OQ-IN-6 playtest verify. |
| First-death hint **text label retained** (NOT glyph) + Pillar 4 *carve-out* explicit | 2026-05-11 | game-designer + user pick (B3 fix Session 14) | "텍스트 튜토리얼 0줄" 약속 = *튜토리얼 페이지/모달* scope. 1-token button label = UI affordance, NOT 위반. Glyph alt (ux-designer REC-2 `[LT] ↺`) reject — KB+M `Shift` 보편 글리프 부재 (Mac ⇧ vs Win shift logo). Localization #22 (Tier 3)가 다국어 처리. C.1.5 carve-out 명시. |
| Cascade harness **5 consumers** (was 3) + frame-stamp non-trivial assertion | 2026-05-11 | qa-lead + game-designer (B1 fix Session 14) | 3-consumer harness was trivially-true (all read same global state). 5-consumer (PM/SM/TRC/PS/Menu) + pairwise `poll_frame` equality + single-tick edge decay = non-trivial Pillar 2 verification. AC-IN-03 rewrite + deliverable `cascade_5_consumer_harness.gd`. |
| Pillar 4 5-min rule playtest AC (**AC-IN-21**) | 2026-05-11 | game-designer + qa-lead (B2 fix Session 14) | B.2 line 60 ("30s jump / 60s shoot / 5min rewind") testability gap 해소. ADVISORY classification (playtest 종속, N=5 min, N≤15 escalation). H.11b 신설. |
| First-death hint latch policy: **per-DYING show + permanent-dismiss on first rewind success** (was 1-time on first death) | 2026-05-11 | ux-designer + user pick (B15 fix Session 14) | Latch가 "첫 죽음"에 닫히면 panic-miss 시 silent betrayal. SM이 2 signal owner (`first_death_in_session` recurring + `first_rewind_success_in_session` per-session). HUD-local latch + scene-change reset. state-machine.md C.2.2 O7/O8 Round-7 cross-doc exception 적용. |
| `InputStateProvider` adapter seam **reserved** (Tier 1 thin static passthrough, Tier 3 #24 motor accessibility hook) | 2026-05-11 | accessibility-specialist + user pick (B21 fix Session 14) | 5-method static wrapper (`is_pressed` / `is_just_pressed` / `is_just_released` / `get_vector` / `get_action_strength`). Tier 1 사용 의무 X (passthrough only). Tier 3 #24가 override/swap. Signature 변경 금지 — backward-compat. Anti-Pillar #6: Tier 3 *content* defer, *architecture* foreclose 금지. C.1.6 신설 + F.4.2 신규 row. |
| `_input` ban exception list 확장: **3 active (Tier 1) + 1 carve-out (Tier 3)** | 2026-05-11 | accessibility-specialist + user pick (B22 fix Session 14) | C.1.2 Rule 2 expansion. Tier 1: Menu #18 + PauseHandler + ActiveProfileTracker(명시화). Tier 3 carve-out: AT bridge (`AssistiveInputBridge` class_name OR `_at_bridge_exempt: bool` marker). F.4.1 #13 architecture.yaml에 carve-out 명시. Tier 3 #24 forever-block 방지. |
| **Citation cleanup** (B6 + B11 + B16, Task #10) | 2026-05-11 | game-designer + ux-designer + godot-specialist + user pick (Session 14) | 3 factual errors 정정: **B6** C.3.1 KB+M `aim_lock=F` justification "right ring finger" → "left index finger + Hotline Miami Shift-aim muscle-memory" (해부학적 정정); **B11** D.2 `InputEvent.timestamp` wall-clock cite 제거 → Godot 4.6 `InputEvent` base class에 공식 `timestamp` 필드 없음 (engine-reference 검증). Banned list을 `Time.*` / `OS.*` family로 한정 (AC-IN-18 패턴과 정합); **B16** C.3.2 Gamepad `aim_lock=RB` justification "Cuphead lock-aim precedent" → "left-right separation + RB+RT right-hand pinch Tier 1 accepted risk + OQ-IN-6". 모두 *keymap 결정 자체는 보존*, *justification 본문만 정정* (CD adjudication: F-key/RB는 그대로). |
| **Schema + mock + SM gate** (B12 + B13 + B14, Task #11) | 2026-05-11 | gameplay-programmer + user pick (Session 14) | Programmer-readiness 3 blockers 해소: **B12** AC-IN-15 `.tres` Resource schema 미정의 → `InputMapSnapshot` Resource class 정의(`src/input/input_map_snapshot.gd`) + Appendix A.6.1 schema spec + AC 본문 cross-ref; **B13** AC-IN-17 mock override 패턴 미정의 → `ActiveProfileMock` test-only Node class + child-injection 패턴(autoload override 아님) + Appendix A.6.2 spec + AC 본문 cross-ref + formula-drift 방지 의무; **B14** O-IN-1 `_trigger_held` gate를 SM에 적용 → state-machine.md C.2.2 O9 row 신설 (Round-7 cross-doc exception 우산 활용, Task #6 B15와 동일 인가 범주). SM "8가지 의무" → "9가지 의무" (header + inline text). F.4.1 O-IN-1 row `✅` 표시. |
| **AC structure cleanup** (B17 + B18 + B19 + B20, Task #9) | 2026-05-11 | qa-lead + user pick (Session 14 — final BLOCKING batch) | AC structure 4 fixes: **B17** AC-IN-20-A → **AC-IN-24** renumber (ID collision with AC-IN-20 F.4.1 ledger 해소; 3 cross-ref site 동시 갱신); **B18** H.13 phantom "F.4.1 #14 batch" reference 제거 + 7 누락 deliverable 추가 (4 adversarial fixtures for AC-IN-05 + first_death_hint_spy + input_map_snapshot.gd + pillar4 playtest protocol); **B19** AC-IN-20 (F.4.1 ledger) **ADVISORY → BLOCKING** reclass (closes OQ-SM-3/OQ-15/4 PM provisional flags; until applied, cross-doc claims unverified); **B20** AC-IN-02 강화 — `count == 9 AND has_action()` (silent rename pass) → **exact 9-StringName set equality** (rename 차단). H.12 Coverage Summary 정확 갱신: 21 ACs → **24 ACs (23 BLOCKING + 1 ADVISORY)** — Task #5 AC-IN-22/23 reflect deferred 해소 + B17 renumber + B19 reclass 적용. |

### A.2 InputMap Default Snapshot (Reference)

본 GDD AC-IN-15가 require하는 `tests/fixtures/input_map_default_snapshot.tres` golden resource의 *논리 구조* (9 actions × 2 device profiles = 18 rows):

```
[action: move_left]
  KB+M     : InputEventKey(physical_keycode=KEY_A)
  Gamepad  : InputEventJoypadMotion(axis=JOY_AXIS_LEFT_X, axis_value=-1.0)

[action: move_right]
  KB+M     : InputEventKey(physical_keycode=KEY_D)
  Gamepad  : InputEventJoypadMotion(axis=JOY_AXIS_LEFT_X, axis_value=+1.0)

[action: move_up]
  KB+M     : InputEventKey(physical_keycode=KEY_W)
  Gamepad  : InputEventJoypadMotion(axis=JOY_AXIS_LEFT_Y, axis_value=-1.0)

[action: move_down]
  KB+M     : InputEventKey(physical_keycode=KEY_S)
  Gamepad  : InputEventJoypadMotion(axis=JOY_AXIS_LEFT_Y, axis_value=+1.0)

[action: jump]
  KB+M     : InputEventKey(physical_keycode=KEY_SPACE)
  Gamepad  : InputEventJoypadButton(button_index=JOY_BUTTON_A)

[action: aim_lock]
  KB+M     : InputEventKey(physical_keycode=KEY_F)
  Gamepad  : InputEventJoypadButton(button_index=JOY_BUTTON_RIGHT_SHOULDER)  # RB

[action: shoot]
  KB+M     : InputEventMouseButton(button_index=MOUSE_BUTTON_LEFT)
  Gamepad  : InputEventJoypadMotion(axis=JOY_AXIS_TRIGGER_RIGHT, axis_value=+1.0)  # RT

[action: rewind_consume]
  KB+M     : InputEventKey(physical_keycode=KEY_SHIFT)
  Gamepad  : InputEventJoypadMotion(axis=JOY_AXIS_TRIGGER_LEFT, axis_value=+1.0)  # LT, threshold 0.5

[action: pause]
  KB+M     : InputEventKey(physical_keycode=KEY_ESCAPE)
  Gamepad  : InputEventJoypadButton(button_index=JOY_BUTTON_START)
```

InputMap action deadzone:
```
move_left/right/up/down : 0.2 (radial composite via Input.get_vector)
jump / aim_lock / shoot / rewind_consume / pause : default (binary actions)
```

### A.3 Specialist Consult Trail

| Section | Specialists Consulted | Key Outputs |
|---|---|---|
| A Overview | (skip — derived from concept + ADR-0003) | Framing locked: technical / cite ADR-0003 / no fantasy |
| B Player Fantasy | **creative-director** (MANDATORY) | 3 framings → user-chosen synthesis: B.1 Intent Is Sacred + B.2 Cascade |
| C Detailed Design | **game-designer** (Primary) + **godot-gdscript-specialist** (feasibility) + **ux-designer** (default keymap) (3 parallel) | 9-action catalog + KB+M F-key resolution + Pillar 4 audit + Godot 4.6 verified |
| D Formulas | **systems-designer** (MANDATORY) | F1/F3/F4/F5 reject → D.1 active profile + D.2 wall-clock exclusion |
| E Edge Cases | **systems-designer** (MANDATORY — continuation) | 17 candidates → 10 final entries; merged E-IN-7/8/10 / E-IN-4/5 |
| F Dependencies | (mechanical — no consult) | Bidirectional table + F.4.1 13 reciprocal edits |
| G Tuning Knobs | (light — no consult) | 4 owned knobs + 6 cross-doc references |
| V/A + UI | (Foundation — no required consult) | Brief — data contribution to HUD #13 |
| H Acceptance Criteria | **qa-lead** (MANDATORY) | 20 ACs (19 BLOCKING + 1 ADVISORY) + Script-Existence Discipline + 11 tooling deliverables |

### A.4 Cross-Doc Reciprocity Status (Phase 5 closure pending)

본 GDD 작성 시점에 *미적용*인 F.4.1 13개 reciprocal edit + F.4.2 8개 deferred obligation. Phase 5에서 일괄 적용 + `production/qa/input-f41-batch.md` ledger 작성(AC-IN-20).

### A.5 References

- **Game Concept**: `design/gdd/game-concept.md` (Pillars 1-5, Anti-Pillar #6)
- **Systems Index**: `design/gdd/systems-index.md` System #1 row
- **ADR-0003**: `docs/architecture/adr-0003-determinism-strategy.md` (determinism_clock + process_physics_priority)
- **Player Movement**: `design/gdd/player-movement.md` C.5.3 + F.4.2 (cross-doc obligations satisfied here)
- **State Machine**: `design/gdd/state-machine.md` D.2 + OQ-SM-3 (cross-doc obligations satisfied here)
- **Time Rewind**: `design/gdd/time-rewind.md` C.3 #1 + OQ-15 (cross-doc obligations satisfied here)
- **Engine Reference**: `docs/engine-reference/godot/modules/input.md` (Godot 4.6 Input API verified 2026-02-12)
- **Technical Preferences**: `.claude/docs/technical-preferences.md` (Steam Deck verified target, gamepad primary, single-button-no-chord rule)
- **Architecture Registry**: `docs/registry/architecture.yaml` (4 new entries via F.4.1)

### A.6 Test Fixture Resource Schemas (B12 + B13 fix 2026-05-11)

본 절은 Task #11 (B12+B13 fix Session 14)에서 *programmer-readiness blocker* 해소 — AC-IN-15와 AC-IN-17이 참조하는 .tres / .gd fixture의 *정확한 schema*를 단일 출처로 정의한다. 이전(Session 12) AC 본문은 fixture 존재만 요구했고 *schema는 미정의* (gameplay-programmer가 "어떤 Resource subclass인가? @export 필드는?"으로 막힘).

#### A.6.1 InputMapSnapshot Resource (`tests/fixtures/input_map_default_snapshot.tres` golden)

**Production Resource class** (`src/input/input_map_snapshot.gd`):

```gdscript
class_name InputMapSnapshot extends Resource

## C.1.1 9-action 카탈로그 verbatim (StringName 정확 매치 의무).
@export var actions: Array[StringName] = [
    &"move_left", &"move_right", &"move_up", &"move_down",
    &"jump", &"aim_lock", &"shoot", &"rewind_consume", &"pause"
]

## KB+M 디바이스 프로필 (C.3.1 row 9건 verbatim).
## 키: action StringName · 값: InputEvent (InputEventKey / InputEventMouseButton)
@export var kb_m_bindings: Dictionary = {}

## Gamepad 디바이스 프로필 (C.3.2 row 9건 verbatim — Steam Deck inherits).
## 키: action StringName · 값: InputEvent (InputEventJoypadButton / InputEventJoypadMotion)
@export var gamepad_bindings: Dictionary = {}

## InputMap action deadzone (move_*=0.2, 나머지=Godot default).
## 키: action StringName · 값: float (0.0–1.0)
@export var deadzones: Dictionary = {
    &"move_left": 0.2, &"move_right": 0.2,
    &"move_up": 0.2, &"move_down": 0.2,
    # binary actions (jump/aim_lock/shoot/rewind_consume/pause): default
}
```

**.tres 파일 구조** (Godot 4.6 binary resource — A.2 reference snapshot에서 *machine-generation*):

```
[gd_resource type="Resource" script_class="InputMapSnapshot" load_steps=N format=3]

[ext_resource type="Script" path="res://src/input/input_map_snapshot.gd" id="1"]

[sub_resource type="InputEventKey" id="KbmMoveLeft"]
physical_keycode = KEY_A
# ... 18 sub_resources (KB+M 9 + Gamepad 9)

[resource]
script = ExtResource("1")
actions = [&"move_left", ...]
kb_m_bindings = { &"move_left": SubResource("KbmMoveLeft"), ... }
gamepad_bindings = { ... }
deadzones = { ... }
```

**AC-IN-15 검증 알고리즘**: `for action in snap.actions: assert InputMap.has_action(action) AND InputMap.action_get_events(action)[0].equals(snap.kb_m_bindings[action]) OR equals(snap.gamepad_bindings[action])`. CI failure message는 *diverged action StringName + profile* 두 값을 print.

#### A.6.2 ActiveProfileMock Node (`tests/helpers/active_profile_mock.gd`)

**Mock class** (test-only, NOT autoload):

```gdscript
class_name ActiveProfileMock extends Node

## D.1.1 surface (test-writable; production은 ActiveProfileTracker._input가 set)
var _last_input_source: StringName = &""  # &"kb_m" / &"gamepad" / &""
var _last_input_frame: int = 0  # Engine.get_physics_frames() value
var _hysteresis_frames: int = 180  # G.1 imported

## D.1.2 active_profile() formula verbatim — production tracker 동일 식.
## 변경 시 ActiveProfileTracker.active_profile() 동시 갱신 의무 (formula drift 금지).
func active_profile() -> StringName:
    var delta := Engine.get_physics_frames() - _last_input_frame
    if _last_input_source == &"gamepad" and delta < _hysteresis_frames:
        return &"GAMEPAD"
    if _last_input_source == &"kb_m":
        return &"KB_M"
    return &"KB_M"  # fallback (cold-boot j=0)
```

**Override 패턴**: 본 mock은 *autoload override가 아니다*. AC-IN-17 fixture는:
1. Test scene이 `ActiveProfileMock` instance를 자식 노드로 인스턴스화 (`mock := preload("res://tests/helpers/active_profile_mock.gd").new()` + `add_child(mock)`).
2. Test setup이 `mock._last_input_source = &"gamepad"`, `mock._last_input_frame = Engine.get_physics_frames()` 직접 set.
3. AC-IN-17 검증 함수는 `mock.active_profile()` 직접 호출 — production `ActiveProfileTracker` autoload은 *touch하지 않음* (formula isolation).
4. Integration test (별도)는 *production* `ActiveProfileTracker` autoload으로 wiring 검증 — `_input` callback 실제 발화 + hysteresis 실제 작동.

**프로덕션 분리 원칙**: production code (`src/`) 는 mock을 reference하지 않는다 (test-helpers만 사용). `forbidden_patterns.test_helper_in_production` (Tier 1 추가 후보; F.4.1 외 — 향후 검토) 으로 향후 enforce 가능. 본 Tier 1: convention.

**Formula drift 방지**: ActiveProfileTracker `active_profile()` 함수 본문 변경 시 본 mock도 동시 update — Tier 1에서 *2개 site, 동기화 의무*. Tier 2 검토 후보: production class를 mock interface와 share 하는 helper module로 리팩토 (현재 deferred — solo budget + Pillar 5).
