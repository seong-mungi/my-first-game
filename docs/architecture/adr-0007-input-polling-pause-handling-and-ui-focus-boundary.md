# ADR-0007: Input Polling, Pause Handling, and UI Focus Boundary

## Status
Accepted (ratified 2026-05-14)

## Date
2026-05-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Input / UI / Core / Pause Lifecycle |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/input.md`, `docs/engine-reference/godot/modules/ui.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md`, `.claude/docs/technical-preferences.md`, `docs/registry/architecture.yaml`, `docs/architecture/architecture.md`, `docs/architecture/adr-0003-determinism-strategy.md`, `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md`, `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md`, `docs/architecture/adr-0006-save-and-settings-persistence-boundary.md`, `design/gdd/input.md`, `design/gdd/menu-pause.md`, `design/gdd/story-intro-text.md`, `design/gdd/state-machine.md`, `design/gdd/scene-manager.md`, `design/gdd/hud.md`, `design/gdd/player-movement.md`, `design/gdd/player-shooting.md`, `design/gdd/time-rewind.md` |
| **Post-Cutoff APIs Used** | No new post-cutoff API is introduced. The decision depends on Godot 4.6 behavior already captured in local references: separate mouse/touch focus vs keyboard/gamepad focus, SDL3 gamepad backend behavior, recursive Control disable availability, `Control.grab_focus()`, `InputMap`, `Input.is_action_*`, `Input.get_vector`, `_input`, `_unhandled_input`, `Node.PROCESS_MODE_ALWAYS`, `Viewport.set_input_as_handled()`, and `Engine.get_physics_frames()`. |
| **Verification Required** | (1) Godot 4.6 fixture proves gameplay consumers read input only in `_physics_process` and never in `_input`/`_unhandled_input`. (2) PauseHandler remains responsive while paused via `PROCESS_MODE_ALWAYS`; resume always succeeds; initiation veto checks `EchoLifecycleSM.can_pause()`. (3) `Viewport.set_input_as_handled()` is called on pause resume, pause initiate, and pause veto paths. (4) Menu/Pause focus is valid within 2 frames of open and repairs keyboard/gamepad vs mouse focus divergence within 1 frame. (5) Story Intro adds no InputMap action and owns no scene transition. (6) ActiveProfileTracker classification uses `Engine.get_physics_frames()`, not wall-clock or `InputEvent.timestamp`. |

> Engine validation note: primary engine specialist from `.claude/docs/technical-preferences.md` is `godot-specialist`. In this Codex adapter run, no subagent was spawned because the repository adapter limits `Task`/subagent use to explicit user-requested delegation. The draft was validated locally against the pinned Godot 4.6 reference files listed above. No blocking Godot 4.6 input/UI API incompatibility was found. Because Godot 4.6 dual-focus behavior and SDL3 gamepad behavior are high-risk local-device behaviors, direct keyboard/mouse, gamepad, and Steam Deck fixture/manual validation is required before production coding claims are accepted.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 Determinism Strategy; ADR-0004 Scene Lifecycle and Checkpoint Restart Architecture; ADR-0005 Cross-System Signal Architecture and Event Ordering; ADR-0006 Save and Settings Persistence Boundary. |
| **Enables** | Input implementation, PauseHandler autoload, ActiveProfileTracker autoload, Menu/Pause focus implementation, Story Intro first-input boundary, and test/static-check setup for input purity. |
| **Blocks** | Any production story that polls gameplay input in `_input`/`_unhandled_input`, adds Tier 1 InputMap actions, implements a second pause listener, lets Menu/Pause bypass PauseHandler, makes Story Intro own scene transition/input mapping, mutates InputMap outside paused `SettingsManager` paths, or makes HUD/Camera/VFX/Audio consume raw gameplay input. |
| **Ordering Note** | ADR-0003 owns the physics priority ladder. This ADR owns the input callback vs physics-polling boundary, pause toggle path, and UI focus repair rules. |

## Context

### Problem Statement

Echo's current GDDs already define strong input and UI constraints:

- `design/gdd/input.md` locks a 9-action Tier 1 catalog and requires gameplay input polling inside `_physics_process`.
- `design/gdd/menu-pause.md` allows UI/Menu `_input` only for navigation, confirm/cancel, sliders, and focus repair.
- `design/gdd/state-machine.md` locks pause veto in DYING/REWINDING through `can_pause()` / `should_swallow_pause()`.
- `design/gdd/scene-manager.md` and `design/gdd/story-intro-text.md` keep cold-boot first input and scene transition ownership out of Story Intro.
- `docs/engine-reference/godot/modules/input.md` and `docs/engine-reference/godot/modules/ui.md` flag Godot 4.6 dual-focus behavior as a post-cutoff UI risk.

Implementation still needs one architecture-level decision that defines the hard boundary between gameplay input polling, pause handling, and focusable UI. Without it, separate stories could accidentally bind gameplay to callbacks, add duplicate pause listeners, or treat Godot 4.6 mouse hover as the same thing as keyboard/gamepad focus.

### Existing Architectural Stances

- **Input action catalog**: exactly 9 Tier 1 actions: `move_left`, `move_right`, `move_up`, `move_down`, `jump`, `aim_lock`, `shoot`, `rewind_consume`, `pause`.
- **Input polling contract**: gameplay consumers read action state in `_physics_process`; UI/Menu, PauseHandler, and ActiveProfileTracker are the only active Tier 1 callback exceptions.
- **PauseHandler autoload**: `PROCESS_MODE_ALWAYS`, `_unhandled_input`, single source for `pause` action toggle.
- **ActiveProfileTracker autoload**: `PROCESS_MODE_ALWAYS`, `_input`, source classification only; not gameplay logic.
- **Menu/Pause UI boundary**: Menu/Pause owns focusable `Control` surfaces; HUD is not a menu.
- **Story Intro boundary**: passive cold-boot presentation scene; no new InputMap action, no direct scene transition API.
- **Persistence boundary**: Menu/Pause options remain session-only until Save / Settings #21.

### Constraints

- Pillar 2 determinism requires all gameplay consumers to observe the same action truth in a physics tick.
- Pause must be responsive while `get_tree().paused == true`.
- DYING and REWINDING pause initiation is vetoed silently; resume is never vetoed.
- Godot 4.6 separates mouse/touch focus from keyboard/gamepad focus.
- Tier 1 must not add menu-specific actions such as `menu_confirm`, `menu_cancel`, `menu_back`, or `skip_intro`.
- Story Intro must not become a first-launch input gate or explicit "Press any key" screen.
- Steam Deck and gamepad defaults must work without a remapping UI.
- Future Input Remapping #23 and Accessibility #24 must not require rewriting Tier 1 gameplay consumers.

### Requirements

- **R-INPUT-01**: Gameplay systems poll `Input.is_action_*`, `Input.get_vector`, and `Input.get_action_strength` only inside `_physics_process` / state `physics_update`.
- **R-INPUT-02**: `_input`, `_unhandled_input`, and `_unhandled_key_input` are banned for gameplay logic.
- **R-INPUT-03**: Active Tier 1 callback exceptions are limited to UI/Menu `_input`, PauseHandler `_unhandled_input`, and ActiveProfileTracker `_input`.
- **R-INPUT-04**: Tier 3 Assistive Technology bridge carve-out remains reserved but inactive until Accessibility #24 defines it.
- **R-INPUT-05**: PauseHandler is the only pause toggle listener and calls `Viewport.set_input_as_handled()` on resume, initiate, and veto paths.
- **R-INPUT-06**: Pause initiation queries `EchoLifecycleSM.can_pause()`; resume does not query SM and always succeeds.
- **R-INPUT-07**: Menu/Pause owns focusable UI surfaces and focus repair; HUD and Story Intro do not become focusable menus.
- **R-INPUT-08**: Menu/Pause uses Godot `ui_*` actions and pointer events for UI; it adds no Tier 1 InputMap actions.
- **R-INPUT-09**: Story Intro adds no `skip_intro`/confirm action, displays no press-any-key prompt, and does not call SceneTree transition APIs.
- **R-INPUT-10**: ActiveProfileTracker uses `Engine.get_physics_frames()` and whitelisted input event types; it does not use wall-clock or decide gameplay outcomes.

## Decision

Use a **split input architecture**:

1. **Gameplay input path**: gameplay reads action state only during deterministic physics processing.
2. **Pause path**: one always-running `PauseHandler` autoload owns the `pause` toggle in `_unhandled_input`.
3. **UI focus path**: Menu/Pause owns focusable `Control` surfaces and handles UI navigation/confirm/cancel/slider/focus repair in `_input`.
4. **Profile classification path**: `ActiveProfileTracker` may observe raw events in `_input` only to choose button-label copy; it does not trigger gameplay.
5. **Cold-boot story path**: Story Intro is passive; Input/SceneManager own first-input transition into gameplay.

No global input event bus is introduced. No gameplay system subscribes to raw input events. No Tier 1 menu-specific actions are added.

### Architecture Diagram

```text
Godot InputMap action state
        │
        ├── Gameplay path: _physics_process / physics_update only
        │     PlayerMovement, EchoLifecycleSM, TRC verification, WeaponSlot
        │     → deterministic same-frame action truth
        │
        ├── Pause path: PauseHandler autoload
        │     PROCESS_MODE_ALWAYS + _unhandled_input
        │     pause pressed while unpaused → EchoLifecycleSM.can_pause()
        │       ├─ true  → set paused, consume input, Menu/Pause opens
        │       └─ false → consume input, no UI/SFX
        │     pause pressed while paused → resume, consume input
        │
        ├── UI path: Menu/Pause
        │     _input for ui_up/down/left/right, ui_accept, ui_cancel, mouse
        │     owns focusable Control tree and focus repair
        │
        └── Classification path: ActiveProfileTracker
              PROCESS_MODE_ALWAYS + _input
              event type → KB_M/GAMEPAD label profile only
```

### Key Interfaces

```gdscript
# Action catalog remains exact and centralized.
class_name InputActions
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"
const JUMP: StringName = &"jump"
const AIM_LOCK: StringName = &"aim_lock"
const SHOOT: StringName = &"shoot"
const REWIND_CONSUME: StringName = &"rewind_consume"
const PAUSE: StringName = &"pause"

# Single pause toggle owner.
class_name PauseHandler
extends Node

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed(InputActions.PAUSE):
        return

    if get_tree().paused:
        get_tree().paused = false
        get_viewport().set_input_as_handled()
        return

    var sm := get_tree().get_first_node_in_group(&"echo_lifecycle_sm")
    if sm != null and sm.can_pause():
        get_tree().paused = true
    # veto path is silent but still consumes the event
    get_viewport().set_input_as_handled()
```

```gdscript
# Source classification only; not gameplay input handling.
class_name ActiveProfileTracker
extends Node

enum DeviceProfile { NONE, KB_M, GAMEPAD }

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
    # Update _last_input_source + _last_input_frame using Engine.get_physics_frames().
    # Joypad motion is accepted only for the bound axes listed in input.md D.1.1.
    pass

func active_profile() -> DeviceProfile:
    # Uses HYSTERESIS_FRAMES = 180 and connected joypad fallback.
    pass

func button_label(profile: DeviceProfile, action_id: StringName) -> String:
    pass
```

```gdscript
# Menu/Pause owns focusable UI only.
func _input(event: InputEvent) -> void:
    # Allowed: ui_up/down/left/right, ui_accept, ui_cancel, mouse hover/click/drag.
    # Forbidden: movement, shooting, rewind_consume gameplay, scene transition calls,
    # new InputMap action declarations, or direct pause policy decisions.
    pass
```

### Gameplay Polling Rules

| Consumer | Allowed input read | Timing | Forbidden |
|----------|--------------------|--------|-----------|
| PlayerMovement | `Input.get_vector`, `is_action_pressed`, `is_action_just_pressed`, `is_action_just_released` via `InputActions` | `_physics_process` Phase 2 | `_input` / `_unhandled_input`, raw string action literals, deadzone reimplementation |
| EchoLifecycleSM | `rewind_consume` edge/hold gate through `physics_update` | Alive/Dying state `physics_update` | `_input`, wall-clock, direct InputMap mutation |
| TimeRewindController | Verification/read-only timing in priority slot; restore logic is SM-driven | `_physics_process` | consuming input in callbacks |
| WeaponSlot / Player Shooting | `shoot` hold via `InputActions.SHOOT` | `_physics_process` | `_input`, changing movement state, raw direct input event handling |
| HUD/Camera/VFX/Audio | None for gameplay input | Signals / read-only APIs only | Raw `Input.is_action_*` calls |

### Pause Rules

- `PauseHandler` is an autoload and the single listener for `InputActions.PAUSE`.
- `PauseHandler.process_mode = Node.PROCESS_MODE_ALWAYS`.
- Pause initiation while unpaused:
  1. consume event intent;
  2. query `EchoLifecycleSM.can_pause()`;
  3. if true, set `get_tree().paused = true`;
  4. if false, do nothing visible/audio and keep gameplay unpaused;
  5. call `get_viewport().set_input_as_handled()` either way.
- Pause resume while paused:
  1. set `get_tree().paused = false`;
  2. do not query SM;
  3. call `get_viewport().set_input_as_handled()`.
- Menu/Pause must not implement a second pause listener or bypass the veto rule.

### UI Focus Rules

- Menu/Pause root controls run while paused and own the only Tier 1 focusable gameplay UI.
- Opening pause root must focus `Resume` within `<= 2` frames.
- Opening options must focus `Master Volume` within `<= 2` frames.
- If Godot 4.6 mouse hover focus and keyboard/gamepad focus diverge, the next controller navigation event repairs the visual selected state to the keyboard/gamepad-focused item within `<= 1` frame.
- If the focused item becomes disabled, focus moves to the nearest enabled sibling; if none exists, focus returns to the surface default.
- Menu/Pause may use `Control.grab_focus()`, focus neighbors, stable string keys, and recursive disable for transition-locked surfaces.
- HUD remains non-focusable combat display. Story Intro remains passive text presentation.

### Cold-Boot / Story Intro Rules

- Story Intro displays five passive lines and no prompt.
- Story Intro adds no InputMap action and does not read bindings.
- The approved cold-boot first-input route is owned by Input + SceneManager.
- Story Intro may be interrupted by SceneManager unloading the intro scene; it stops local timers/tweens and emits no gameplay event.
- Press-any-key prompts, Start/Continue gates, and skip-intro actions are banned in Tier 1.

### Registry Candidates

`docs/registry/architecture.yaml` is not updated by this ADR draft without explicit approval. If approved, the registry should mirror this decision with candidates equivalent to:

- `interfaces.input_polling_contract.referenced_by`: add this ADR to the existing input polling contract.
- `api_decisions.pause_handler_autoload.referenced_by`: add this ADR and keep `PROCESS_MODE_ALWAYS`, `_unhandled_input`, `can_pause()`, and consume-on-decision invariant.
- `api_decisions.active_profile_tracker.referenced_by`: add this ADR and keep `_input` classification / `Engine.get_physics_frames()` profile timing.
- `api_decisions.menu_pause_ui_focus_owner`: Menu/Pause #18 owns focusable Tier 1 UI surfaces; HUD and Story Intro are not focus owners.
- `api_decisions.cold_boot_first_input_boundary`: Input + SceneManager own first-input transition; Story Intro remains passive and action-free.
- `forbidden_patterns.gameplay_input_in_callback.referenced_by`: add this ADR.
- `forbidden_patterns.raw_action_string_literals`: gameplay input reads use `InputActions` `StringName` constants, not raw action string literals.
- `forbidden_patterns.second_pause_listener`: bans any pause toggle owner outside `PauseHandler`.
- `forbidden_patterns.story_intro_input_gate`: bans press-any-key/start/continue prompts, skip actions, and direct scene changes from Story Intro.
- `forbidden_patterns.godot46_focus_assumption`: bans assuming `grab_focus()` also resolves mouse hover focus.

## Alternatives Considered

### Alternative 1: Split Physics Gameplay / Callback UI / Single PauseHandler (Selected)

- **Description**: Gameplay polls in `_physics_process`; UI uses `_input`; pause toggle is centralized in an always-running autoload; profile tracking observes raw events only for labels.
- **Pros**:
  - Preserves ADR-0003 deterministic same-frame input truth.
  - Matches approved Input and Menu/Pause GDDs.
  - Keeps pause responsive while tree is paused.
  - Minimizes Tier 1 action catalog and UI scope.
  - Makes Godot 4.6 dual-focus behavior testable in one UI owner.
- **Cons**:
  - Requires static checks to keep gameplay out of callbacks.
  - Requires explicit focus repair code in Menu/Pause.
  - ActiveProfileTracker is a narrowly-scoped callback exception that reviewers must not copy for gameplay.
- **Selection Reason**: Best fit for deterministic gameplay, responsive pause, and small Tier 1 UI.

### Alternative 2: Gameplay Handles Input Events in `_input`

- **Description**: Movement, shooting, rewind, and pause react directly to input callbacks.
- **Pros**:
  - Lower apparent latency for individual events.
  - Simple for small prototypes.
- **Cons**:
  - Breaks same-physics-tick cascade invariant.
  - Creates callback-vs-physics ordering ambiguity.
  - Makes rewind input windows dependent on event timing rather than frame timing.
  - Harder to test with deterministic physics fixtures.
- **Rejection Reason**: Violates ADR-0003 determinism and Input GDD C.1.2.

### Alternative 3: Pause Owned by Menu/Pause UI

- **Description**: Menu/Pause listens for `pause`, decides veto/resume, and toggles tree pause itself.
- **Pros**:
  - UI owner contains all menu open/close code.
  - Fewer autoloads.
- **Cons**:
  - UI may not process correctly when the tree is paused unless special-cased anyway.
  - Creates risk of a second pause listener or bypassed SM veto.
  - Blurs focus/navigation with gameplay pause policy.
- **Rejection Reason**: PauseHandler autoload is already the registered single source and keeps policy separate from focusable UI.

### Alternative 4: Add Tier 1 Menu-Specific Actions

- **Description**: Add `menu_confirm`, `menu_cancel`, `menu_back`, and `skip_intro` to the InputMap.
- **Pros**:
  - Menu logic could avoid Godot default `ui_*` actions.
  - Skip intro path becomes explicit.
- **Cons**:
  - Expands Tier 1 action catalog.
  - Violates Menu/Pause AC-MENU-05 and Story Intro no-skip-action rule.
  - Increases remapping/localization/accessibility surface before Tier 3 owners exist.
- **Rejection Reason**: Tier 1 must preserve the 9-action catalog and use existing Godot UI input actions for UI.

## Consequences

### Positive

- Locks deterministic gameplay input polling before implementation.
- Gives PauseHandler one clear owner and testable consume-on-decision behavior.
- Isolates Godot 4.6 dual-focus risk to Menu/Pause.
- Keeps Story Intro passive and prevents a first-launch gate.
- Preserves HUD as non-focusable presentation.
- Creates concrete static-check targets for `_input` purity, action catalog drift, second pause listeners, and focus assumptions.

### Negative

- UI and gameplay input have intentionally different paths, so tests must cover both.
- PauseHandler and Menu/Pause must coordinate without duplicating the toggle listener.
- ActiveProfileTracker remains a special exception to the callback ban and needs strong comments/static-check carve-outs.
- Mouse/gamepad focus repair adds small UI implementation overhead.

### Risks

- **Gameplay callback creep**: mitigate with multiline static scanner for `Input.*` inside `_input`/`_unhandled_input` in gameplay modules.
- **Pause double-consumption**: mitigate with tests that exactly one pause path fires and `set_input_as_handled()` executes on all decisions.
- **Godot 4.6 focus divergence**: mitigate with mouse-hover + gamepad-navigation integration tests.
- **Steam Deck trigger/profile drift**: mitigate with physical Steam Deck 1st-gen manual validation and SDL3 gamepad fixture coverage.
- **Story Intro becomes a menu**: mitigate with static checks for `skip_intro`, press-any-key copy, and direct SceneTree transition calls in Story Intro scripts.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/input.md` | Gameplay consumers poll only in `_physics_process`; Tier 1 has exactly 9 actions. | Elevates polling discipline and action catalog into architecture policy. |
| `design/gdd/menu-pause.md` | Menu/Pause owns focusable UI, uses `_input` only for UI, and adds no Tier 1 menu actions. | Locks Menu/Pause as the sole focusable Tier 1 UI owner and uses existing Godot `ui_*` actions. |
| `design/gdd/state-machine.md` | DYING/REWINDING swallow pause through `can_pause()` / `should_swallow_pause()`. | Makes PauseHandler query `can_pause()` on initiation and never on resume. |
| `design/gdd/scene-manager.md` | Cold-boot first input routes through SceneManager transition API. | Keeps Story Intro passive and routes cold boot through Input/SceneManager, not raw scene changes. |
| `design/gdd/story-intro-text.md` | No prompt gate, no new InputMap action, no direct scene transition. | Bans press-any-key/start/continue prompts, `skip_intro`, and transition APIs in Story Intro. |
| `design/gdd/hud.md` | HUD is combat display, not menu/focus owner. | Keeps HUD non-focusable and routes prompts through signals/read-only APIs. |
| `design/gdd/player-movement.md` | PM reads movement/jump/aim input in deterministic phases. | Requires PM polling in `_physics_process` via `InputActions` only. |
| `design/gdd/player-shooting.md` | WeaponSlot polls `shoot` in `_physics_process` and emits `shot_fired`. | Preserves shooting as gameplay physics polling, not callback handling. |
| `docs/engine-reference/godot/modules/ui.md` | Godot 4.6 mouse/touch focus is separate from keyboard/gamepad focus. | Requires explicit Menu/Pause focus repair and dual-path UI tests. |

## Performance Implications

- **CPU**: No per-frame overhead beyond existing input polling. Menu focus repair runs only on UI events/navigation while paused.
- **Memory**: No additional gameplay memory. PauseHandler and ActiveProfileTracker are tiny autoload nodes.
- **Load Time**: No impact.
- **Network**: None; local-only single-player. Networked input would require a future authority/prediction ADR.

## Migration Plan

No production implementation exists yet. Implementation should proceed as follows after ADR acceptance:

1. Implement `InputActions` constants and project InputMap defaults for the exact 9 actions.
2. Implement `PauseHandler` autoload with `PROCESS_MODE_ALWAYS`, `_unhandled_input`, `can_pause()` query, and consume-on-decision invariant.
3. Implement `ActiveProfileTracker` autoload with `_input` source classification and `Engine.get_physics_frames()` timing.
4. Implement Menu/Pause focus surfaces with `grab_focus()`, focus neighbors, disabled-state handling, and Godot 4.6 focus repair.
5. Ensure Story Intro contains no input action declarations, raw binding reads, prompts, or transition calls.
6. Add static checks for gameplay input callback purity, raw action string literals, action catalog drift, second pause listeners, story intro input gate, and focus ownership.
7. Add GUT/integration fixtures for pause veto/resume, menu focus open/repair, cold-boot first input, and ActiveProfileTracker profile selection.
8. Run Steam Deck / gamepad / KB+M manual validation for 5 minutes each before claiming input readiness.

## Validation Criteria

This decision is correct if the following pass:

- `test_input_action_catalog_exact_9`
- `test_gameplay_input_only_in_physics_process_static`
- `test_no_raw_action_string_literals_static`
- `test_pause_handler_single_listener_static`
- `test_pause_handler_resume_while_paused_always_succeeds`
- `test_pause_handler_veto_dying_rewinding_consumes_event`
- `test_pause_handler_initiate_alive_sets_tree_paused`
- `test_pause_handler_set_input_as_handled_all_paths`
- `test_menu_pause_focus_resume_within_two_frames`
- `test_menu_pause_focus_repair_after_mouse_gamepad_divergence`
- `test_menu_pause_no_new_inputmap_actions_static`
- `test_story_intro_no_skip_action_or_press_any_key_static`
- `test_story_intro_no_scene_transition_call_static`
- `test_active_profile_tracker_uses_physics_frames_static`
- `test_active_profile_tracker_bound_axis_filter`
- `test_inputmap_mutation_only_settingsmanager_paused_tree_static`
- `test_steam_deck_default_mapping_manual_5_minute`

## Related Decisions

- `docs/architecture/adr-0003-determinism-strategy.md` — physics priority ladder and frame clock.
- `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md` — SceneManager transition authority.
- `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md` — signal/direct-call boundary.
- `docs/architecture/adr-0006-save-and-settings-persistence-boundary.md` — no Tier 1 settings persistence and future SettingsManager seam.
- `docs/registry/architecture.yaml` — input polling, PauseHandler, ActiveProfileTracker, Menu/Pause, and forbidden-pattern stances.
- `design/gdd/input.md`
- `design/gdd/menu-pause.md`
- `design/gdd/story-intro-text.md`
- `design/gdd/state-machine.md`
- `design/gdd/scene-manager.md`
- `design/gdd/hud.md`
- `design/gdd/player-movement.md`
- `design/gdd/player-shooting.md`
- `design/gdd/time-rewind.md`
