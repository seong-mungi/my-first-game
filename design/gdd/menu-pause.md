# Menu / Pause System

> **Status**: Approved · 2026-05-14
> **Author**: Codex Game Studios
> **Last Updated**: 2026-05-14
> **Implements Pillars**: Pillar 1 (Learning Tool — pause cannot extend DYING analysis), Pillar 4 (5-Minute Rule), Pillar 5 (Small Success)
> **Engine**: Godot 4.6 / GDScript / `CanvasLayer` + focusable `Control` UI
> **Review Mode**: Lean authoring; CD-GDD-ALIGN skipped per lean mode

---

## A. Overview

Menu / Pause System #18 owns Echo's navigable Tier 1 UI surfaces: the pause overlay and session-only options. It is the only Tier 1 system allowed to present focusable `Control` nodes during play. It consumes Input #1's approved pause architecture, Scene Manager #2's restart transition API, and Audio #4's UI bus facade; it does not own gameplay input polling, scene lifecycle, audio bus implementation, save persistence, input remapping, localization, HUD combat readouts, Story Intro narrative text, or a production title/menu shell.

Tier 1 Menu/Pause is intentionally small. Cold boot still follows the Story Intro #17 / Scene Manager #2 first-input route and must not be replaced by a blocking "Press any key" or options gate. The pause overlay exists to let the player resume, restart checkpoint, adjust basic session audio volume, or quit. Everything else — return-to-title, title/menu shell, remapping, persistence, accessibility options, language selection, credits, gallery, challenge menus — is deferred to later systems.

## B. Player Fantasy

The player fantasy is **control without bargaining**. The player can pause when it is fair, resume instantly, and adjust basic comfort settings without feeling that the game has become a front-end project. During combat the game stays sharp and deterministic; during pause the player sees a compact, readable menu that confirms they are in control.

Anti-fantasies this system must avoid:

- **"I paused to cheat death."** Pause must be swallowed during DYING and REWINDING, preserving Time Rewind #9's 12-frame decision pressure.
- **"The menu trapped my controller."** Focus must always have one visible selected item and must recover from mouse/gamepad focus split.
- **"Settings ate the prototype."** Tier 1 settings are session-only and minimal; persistence/remapping/localization are not smuggled into this GDD.
- **"The intro made me wait for a menu."** Cold boot remains fast and no-prompt; Menu/Pause does not insert a required title gate before gameplay.

## C. Detailed Design

### C.1 Core Rules

**Rule 1 — PauseHandler remains the pause toggle authority.**  
Input #1's `PauseHandler` autoload remains the single source for toggling `get_tree().paused`. Menu / Pause does not implement an independent pause-action listener and does not poll gameplay input in `_physics_process`.

**Rule 2 — Menu/Pause owns focusable UI, not gameplay input.**  
The pause overlay and options surface may use `_input` callbacks for UI navigation, confirmation, cancellation, slider changes, and mouse/gamepad focus repair. They must not run gameplay logic from `_input`.

**Rule 3 — Pause is allowed only when State Machine allows it.**  
On pause initiation, `PauseHandler` queries EchoLifecycleSM `can_pause()` / legacy `should_swallow_pause()` equivalent. If ECHO is DYING or REWINDING, pause is swallowed with zero menu visual and zero UI SFX.

**Rule 4 — Resume is always allowed.**  
When the tree is already paused, pressing the approved `pause` action resumes through `PauseHandler` without SM veto. Menu/Pause closes the overlay and restores gameplay focus on the same rendered frame or next process frame.

**Rule 5 — Pause overlay uses `PROCESS_MODE_ALWAYS`; gameplay UI does not.**  
The root pause UI controller and focusable controls run while the tree is paused. Gameplay HUD #13 remains non-focusable and does not become the menu surface.

**Rule 6 — Tier 1 cold boot is not a menu gate.**  
The initial launch path remains Story Intro #17 → Scene Manager #2 cold-boot route → Stage 1. Menu/Pause does not own a production title/menu shell in Tier 1 and must not block the first core-loop entry with Start/Options confirmation.

**Rule 7 — Scene transitions are requested, not owned.**  
Menu/Pause may call approved Scene Manager request methods for restart checkpoint routing. It must not call raw `SceneTree.change_scene_to_packed()` / `change_scene_to_file()` directly. Return-to-title/title-shell routing is deferred until Scene Manager has an explicit production title route.

**Rule 8 — Restart checkpoint is explicit and non-modal in Tier 1.**  
The pause menu may expose `Restart Checkpoint`. Tier 1 does not add a nested confirmation modal; selection enters `TRANSITION_REQUESTED`, disables all menu controls, and requests Scene Manager's existing checkpoint restart path. The pause UI does **not** immediately return to normal gameplay state; it remains a disabled transition surface until scene boundary/unload, though a same-frame accepted restart may make that interim state invisible to the player. If playtest shows accidental restarts, confirmation becomes a Tier 2 revision.

**Rule 9 — Options are session-only until Save / Settings Persistence #21.**  
Tier 1 options may expose Master/Music/SFX/UI volume sliders for the current process session. Slider changes call Audio #4's exact session facade:

- `AudioManager.set_session_bus_volume(bus_name: StringName, linear_value: float) -> void`
- `AudioManager.get_session_bus_volume(bus_name: StringName) -> float`

Allowed `bus_name` values are `&"Master"`, `&"Music"`, `&"SFX"`, and `&"UI"`. `linear_value` is clamped to `0.0..1.0`, defaults to `1.0` for all four buses at process start, and is never written to disk by Menu/Pause. The options UI must display a "session only" or equivalent non-blocking note if surfaced in UI copy. Persistence #21 owns future file save/load.

**Rule 10 — No input remapping or language selection in Tier 1.**  
Input Remapping #23 and Localization #22 are deferred. Menu/Pause may show disabled placeholder rows only if needed for future layout tests, but production Tier 1 should omit them rather than show unavailable features.

**Rule 11 — Audio feedback uses Audio #4 facade only.**  
Menu/Pause may call `AudioManager.play_ui(stream)` for select/confirm/cancel ticks and `AudioManager.set_session_bus_volume(bus_name, linear_value)` for session-only slider changes. It must not set AudioServer bus volume directly. Since Audio #4 has one dedicated UI player, Tier 1 Menu/Pause limits itself to one-shot, non-overlapping UI SFX.

**Rule 12 — HUD boundary stays intact.**  
Menu/Pause does not display REWIND tokens, ammo, boss phase, first-death prompt, or victory combat cue. HUD #13 remains the combat information owner.

**Rule 13 — Focus is deterministic and recoverable.**  
On opening a menu surface, the default selected control receives keyboard/gamepad focus. If Godot 4.6 mouse focus and keyboard/gamepad focus diverge, keyboard/gamepad focus remains authoritative for controller navigation and the visual selected state.

**Rule 14 — Pause freezes simulation, not UI.**  
When paused, gameplay nodes stop via normal Godot pause semantics. Menu/Pause UI, PauseHandler, and any required AudioManager/UI facade stay responsive. No gameplay timers or physics counters advance because of menu UI.

**Rule 15 — UI inputs reuse existing actions and Godot UI events only.**  
Menu/Pause must not add project actions such as `menu_confirm`, `menu_cancel`, `menu_back`, or `skip_intro`. Production Tier 1 UI input sources are fixed as:

| UI intent | Allowed input sources | Behavior |
|---|---|---|
| Navigate | Godot UI actions `ui_up`, `ui_down`, `ui_left`, `ui_right`; mouse hover over enabled focusable controls | Moves focus/slider value through `Control` UI only; no gameplay polling. |
| Confirm | Godot UI action `ui_accept`; primary mouse release on an enabled focused/hovered `Button` or slider drag/release on a focused slider | Activates the focused item or commits the slider delta. |
| Cancel / Back | Input #1 `pause` action via `PauseHandler`; Godot UI action `ui_cancel` | In `OPTIONS_SESSION`, returns to `PAUSE_ROOT`; in `PAUSE_ROOT`, resumes gameplay; in `TRANSITION_REQUESTED`, ignored. |

If confirm and cancel/back/pause are observed in the same process frame, cancel/back/pause priority wins unless the surface is already in `TRANSITION_REQUESTED`.

### C.2 States and Transitions

| State | Entry Trigger | Exit Trigger | Behavior |
|---|---|---|---|
| `CLOSED` | Default in gameplay | Successful pause initiation | No menu controls visible; no focus capture. |
| `PAUSE_ROOT` | PauseHandler sets `get_tree().paused = true` and emits/announces pause open | Resume, Restart, Options, Quit | Show pause root list and focus `Resume`. |
| `OPTIONS_SESSION` | Player chooses Options | Back / Cancel | Show session-only audio sliders; no save/persistence. |
| `TRANSITION_REQUESTED` | Restart or Quit selected | Scene Manager accepts restart request or process quit begins | Disable controls; prevent double-submit; wait for scene boundary/shutdown. |

Valid transitions:

```text
CLOSED -> PAUSE_ROOT
PAUSE_ROOT -> CLOSED                       # Resume
PAUSE_ROOT -> OPTIONS_SESSION
OPTIONS_SESSION -> PAUSE_ROOT
PAUSE_ROOT -> TRANSITION_REQUESTED         # Restart / Quit
TRANSITION_REQUESTED -> CLOSED             # Scene unload or application quit
```

Invalid transitions:

- DYING/REWINDING pause attempt → remain `CLOSED`; PauseHandler consumes input silently.
- `TRANSITION_REQUESTED` → another transition request before Scene Manager boundary completes is ignored.

### C.3 Interactions with Other Systems

| System | Menu / Pause consumes | Menu / Pause provides | Forbidden |
|---|---|---|---|
| Input #1 | `pause` action via PauseHandler, UI/Menu `_input` exception, focus/navigation events | No new Tier 1 InputMap actions | Gameplay polling in `_input`; dynamic remapping |
| State Machine #5 | `can_pause()` / `should_swallow_pause()` read-only query through PauseHandler | No state mutation | Overriding `pause_swallow_states` |
| Scene Manager #2 | Approved restart transition request API and scene boundary behavior | Restart requests only | Raw SceneTree transition calls; transition ownership; requesting title/start routes in Tier 1 |
| Audio #4 | `AudioManager.play_ui(stream)`, `set_session_bus_volume(bus_name, linear_value)`, `get_session_bus_volume(bus_name)` | UI SFX event catalog + session-only slider requests | Direct AudioServer writes from menu widgets |
| HUD #13 | Boundary only: HUD is not menu | Focusable UI ownership in #18 | Reusing HUD controls as menus |
| Story Intro #17 | Cold-boot route remains no-prompt | No first-launch gate | Replacing Story Intro with required Start menu |
| Save / Settings #21 | Future persistence owner | Session-only values to persist later | Disk writes in #18 |
| Localization #22 | Future string replacement owner | Stable string keys for menu text | Language selector in Tier 1 |
| Input Remapping #23 | Future remap UI owner | No dependency in Tier 1 | Remap screen in #18 |
| Accessibility #24 | Future accessibility options owner | Focus/text/contrast baseline to audit | Full accessibility option stack in #18 |

## D. Formulas

### D.1 Menu Focus Repeat Formula

The `menu_focus_repeat_ready` formula is defined as:

`menu_focus_repeat_ready = held_frames == 1 OR (held_frames >= menu_repeat_initial_frames AND ((held_frames - menu_repeat_initial_frames) % menu_repeat_interval_frames == 0))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `held_frames` | `Hf` | int | `0..600` | Fixed process frames a UI navigation direction has been held. |
| `menu_repeat_initial_frames` | `Ri` | int | `12..24` | Delay before held navigation repeats; default `18`. |
| `menu_repeat_interval_frames` | `Rv` | int | `4..10` | Repeat cadence after initial delay; default `6`. |

**Output Range:** boolean. First press moves once; held direction repeats every `Rv` frames after `Ri`.  
**Example:** With defaults, held down at `Hf=1` moves once; `Hf=18` moves again; `Hf=24`, `30`, `36` continue repeating.

### D.2 Pause Overlay Open Latency

The `pause_overlay_open_latency_frames` formula is defined as:

`pause_overlay_open_latency_frames = pause_handler_frames + ui_focus_frames`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `pause_handler_frames` | `Ph` | int | `0..1` | Frames for PauseHandler to consume action and set `get_tree().paused`. |
| `ui_focus_frames` | `Uf` | int | `0..1` | Frames for pause overlay to become visible and focus default item. |

**Output Range:** `0..2` frames; Tier 1 blocking target `<= 2`.  
**Example:** `Ph=1`, `Uf=1` gives `2` frames from accepted pause input to visible focused menu.

### D.3 Menu UI Draw-Call Estimate

The `menu_ui_draw_call_estimate` formula is defined as:

`menu_ui_draw_call_estimate = panel_draws + text_draws + focus_draws + slider_draws + icon_draws`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `panel_draws` | `P` | int | `1..6` | Background, darkened overlay, and frame panels. |
| `text_draws` | `T` | int | `4..18` | Menu labels, option labels, and session-only note. |
| `focus_draws` | `F` | int | `1..4` | Focus highlight/cursor visuals. |
| `slider_draws` | `S` | int | `0..12` | Audio option slider tracks/handles. |
| `icon_draws` | `I` | int | `0..6` | Small glyphs/icons. |

**Output Range:** `6..46`; Tier 1 target `<= 40` during pause/options. Values above 40 require deleting/merging visuals before implementation.  
**Example:** `P=3`, `T=12`, `F=2`, `S=8`, `I=2` gives `27` draw calls.

## E. Edge Cases

- **If pause is pressed during DYING or REWINDING**: PauseHandler consumes the input, SM vetoes via `can_pause()`/swallow policy, Menu/Pause remains `CLOSED`, and no UI SFX or overlay appears.
- **If pause is pressed while already paused**: resume always succeeds; the overlay closes even if ECHO's previous gameplay state would now veto initiation.
- **If a UI confirm and pause/cancel occur in the same frame**: cancel/resume priority wins unless the menu is in `TRANSITION_REQUESTED`; this prevents accidental restart/quit double-submits.
- **If focus is lost because mouse hover and gamepad focus diverge in Godot 4.6**: restore keyboard/gamepad focus to the last focused valid item before processing the next navigation event.
- **If the focused item is removed/disabled**: focus moves to the nearest enabled sibling; if none exists, focus returns to the surface default (`Resume` for pause root or `Master Volume` for options).
- **If `AudioManager.play_ui()` receives rapid selection ticks faster than the single UI player can finish**: restart or drop the prior tick deterministically; do not allocate another UI player in Tier 1.
- **If a session volume slider is changed and the game exits before Save #21 exists**: the value is lost; no disk write occurs.
- **If Restart Checkpoint is selected while Scene Manager is already transitioning**: ignore the second request and keep controls disabled until scene boundary/unload.
- **If a player expects Return to Title in Tier 1**: no production row is shown. Returning to a title/menu shell is deferred until Scene Manager has an explicit title route and Menu/Pause is revised.
- **If Quit is selected on desktop**: request normal application quit. Steam overlay/system quit remains outside game UI ownership.
- **If input device disconnects while paused**: keep menu visible and focused; keyboard/mouse can continue. Device reconnection is Input #1 responsibility.
- **If localization later makes labels longer**: Localization #22 must validate wrapping/autowrap without changing focus order or button semantics.

## F. Dependencies

### F.1 Upstream Dependencies

| Upstream | Status | Contract | Strength |
|---|---|---|---|
| Input #1 | Approved 2026-05-11 | `pause` action, PauseHandler, UI/Menu `_input` exception, no new Tier 1 actions. | HARD |
| Scene Manager #2 | Approved 2026-05-13 | Scene transition request for checkpoint restart; no raw transition calls from #18. Title/start routes deferred. | HARD |
| Audio #4 | Approved 2026-05-12 | `AudioManager.play_ui(stream)` facade and session bus-volume facade. | HARD |
| State Machine #5 | Approved 2026-05-10 | DYING/REWINDING pause swallow policy via read-only query. | HARD |
| HUD #13 | Approved 2026-05-13 | HUD remains combat information; Menu/Pause owns focusable UI. | SOFT boundary |
| Story Intro #17 | Approved 2026-05-13 | Cold boot no-prompt route remains intact. | SOFT boundary |
| Godot 4.6 UI docs | Verified 2026-02-12 | Dual focus behavior, `Control`, recursive disable, localization-ready labels. | HARD |

### F.2 Downstream Dependents

| Downstream | Expected Use | Status |
|---|---|---|
| Save / Settings Persistence #21 | Persists session-only audio/settings values later. | Vertical Slice |
| Localization #22 | Replaces menu string keys and validates wrap. | Full Vision |
| Input Remapping #23 | Adds remap UI under options later; not #18 Tier 1. | Full Vision |
| Accessibility #24 | Adds text scale, reduced motion, assistive navigation options later. | Full Vision |

**Deferred dependency policy (#21–#24).**
The absence of Tier 1 GDD files for Save / Settings Persistence #21, Localization #22, Input Remapping #23, and Accessibility #24 is intentional and non-blocking for Menu/Pause implementation. Menu/Pause #18 must preserve seams for those later owners — session-only values, stable string keys, no remap UI, and baseline focus/readability — but must not implement their full feature sets or add hard runtime dependencies on systems that do not exist in Tier 1.

### F.3 Reciprocal Notes

- Input #1 already grants Menu/Pause the UI/Menu `_input` exception and owns PauseHandler. This GDD closes the #18 specifics: no gameplay logic in `_input`, no new actions, and focusable UI only while menu surfaces are active.
- Audio #4 OQ-AU-5 is resolved at design-contract level: Tier 1 Menu/Pause uses at most one UI SFX at a time (`menu_select`, `menu_confirm`, `menu_cancel`), so the single dedicated UI player is sufficient.
- Audio #4 owns session bus-volume writes through `set_session_bus_volume()` / `get_session_bus_volume()`; Menu/Pause never calls AudioServer directly and never persists these values.
- Scene Manager #2's #18 mirror is updated by this GDD: #18 may request checkpoint restart but never owns raw scene swaps. Return-to-title/title-shell routing is deferred.
- State Machine #5 remains the pause swallow authority; #18 must not override `pause_swallow_states`.

## G. Tuning Knobs

| Knob | Default | Safe Range | Affects | Out-of-range Behavior |
|---|---:|---:|---|---|
| `menu_repeat_initial_frames` | `18` | `12..24` | Held d-pad/stick navigation delay. | Too low overshoots; too high feels unresponsive. |
| `menu_repeat_interval_frames` | `6` | `4..10` | Held navigation repeat cadence. | Too low overshoots; too high slows slider/list movement. |
| `pause_overlay_open_latency_budget_frames` | `2` | `2 only` | Responsiveness target. | Above 2 frames fails AC-MENU-01. |
| `menu_ui_draw_call_budget` | `40` | `20..40` | Pause/options visual complexity. | Above 40 requires visual merge/delete. |
| `menu_focus_repair_max_frames` | `1` | `1 only` | Focus recovery after device/mouse divergence. | Above 1 frame fails focus AC. |
| `ui_sfx_min_separation_frames` | `4` | `0..8` | Minimum spacing before replaying selection tick. | Too low stutters; too high drops useful feedback. |
| `session_volume_step` | `0.05` | `0.01..0.10` | Slider increment for Master/Music/SFX/UI. | Too low slow; too high coarse. |

Non-tunable invariants:

- No pause during DYING/REWINDING.
- Resume always allowed from paused tree.
- No new Tier 1 InputMap actions.
- No production Return to Title or title/menu shell in Tier 1.
- No disk persistence in #18.
- No first-launch menu gate before Story Intro/core loop.

## H. Acceptance Criteria

- [ ] **AC-MENU-01**: **GIVEN** gameplay is ALIVE and unpaused, **WHEN** the `pause` action is accepted by PauseHandler, **THEN** `get_tree().paused == true`, the pause overlay is visible, and `Resume` has keyboard/gamepad focus within `<= 2` frames.
- [ ] **AC-MENU-02**: **GIVEN** EchoLifecycleSM is DYING or REWINDING, **WHEN** the `pause` action fires, **THEN** PauseHandler consumes the input, `get_tree().paused` remains false, Menu/Pause stays `CLOSED`, and no UI SFX plays.
- [ ] **AC-MENU-03**: **GIVEN** the tree is paused, **WHEN** the `pause` action fires again, **THEN** the overlay closes and `get_tree().paused == false` without querying SM veto.
- [ ] **AC-MENU-04**: **GIVEN** Menu/Pause implementation files are scanned, **WHEN** static analysis runs, **THEN** no script under the Menu/Pause system directly calls `SceneTree.change_scene_to_packed` or `change_scene_to_file`.
- [ ] **AC-MENU-05**: **GIVEN** Menu/Pause implementation files are scanned, **WHEN** static analysis runs, **THEN** no new Tier 1 InputMap action such as `menu_confirm`, `menu_cancel`, `menu_back`, or `skip_intro` is declared; UI navigation, confirm, cancel, and back use only Rule 15 sources.
- [ ] **AC-MENU-06**: **GIVEN** pause root is open, **WHEN** the player navigates with d-pad/stick, **THEN** focus moves once on initial press and repeats according to `menu_focus_repeat_ready`.
- [ ] **AC-MENU-07**: **GIVEN** Godot 4.6 mouse focus and keyboard/gamepad focus diverge, **WHEN** the next controller navigation event occurs, **THEN** the visual selected state repairs to the keyboard/gamepad-focused item within `<= 1` frame.
- [ ] **AC-MENU-08**: **GIVEN** `Restart Checkpoint` is selected from pause, **WHEN** confirm is pressed, **THEN** controls disable, Menu/Pause requests Scene Manager's checkpoint restart route, and no second transition request can fire before scene boundary.
- [ ] **AC-MENU-09**: **GIVEN** Options is opened, **WHEN** Master/Music/SFX/UI sliders are changed, **THEN** Menu/Pause calls `AudioManager.set_session_bus_volume()` with one of `&"Master"`, `&"Music"`, `&"SFX"`, `&"UI"` and a clamped `0.0..1.0` value, `AudioManager.get_session_bus_volume()` returns that session value, and no file is written.
- [ ] **AC-MENU-10**: **GIVEN** UI SFX are configured, **WHEN** select/confirm/cancel events fire, **THEN** Menu/Pause calls `AudioManager.play_ui(stream)` and does not instantiate additional `AudioStreamPlayer` nodes.
- [ ] **AC-MENU-11**: **GIVEN** Menu/Pause surfaces are visible, **WHEN** `menu_ui_draw_call_estimate` is computed, **THEN** the value is `<= 40`.
- [ ] **AC-MENU-12**: **GIVEN** cold boot first launch, **WHEN** the player has not yet entered gameplay, **THEN** Menu/Pause does not display a required Start/Options gate before Story Intro #17/core-loop entry.
- [ ] **AC-MENU-13**: **GIVEN** static analysis scans for persistence APIs, **WHEN** Menu/Pause #18 files are checked, **THEN** no FileAccess/ConfigFile/user-data write occurs; persistence is deferred to #21.
- [ ] **AC-MENU-14**: **GIVEN** HUD is active during gameplay, **WHEN** pause opens, **THEN** Menu/Pause uses its own focusable controls and does not make HUD #13 controls focusable.
- [ ] **AC-MENU-15**: **GIVEN** pause root is open in production Tier 1, **WHEN** visible menu rows are enumerated, **THEN** the only rows are `Resume`, `Restart Checkpoint`, `Options`, and `Quit`; `Return to Title`, `Start`, and `Continue` are absent.
- [ ] **AC-MENU-16**: **GIVEN** a UI confirm event and a `pause`/`ui_cancel` back event are received in the same process frame outside `TRANSITION_REQUESTED`, **WHEN** Menu/Pause resolves the frame, **THEN** cancel/back/pause priority wins and no restart or quit request is emitted.
- [ ] **AC-MENU-17**: **GIVEN** Menu/Pause text controls are instantiated, **WHEN** label text is assigned, **THEN** every visible Tier 1 label uses a string key from J.3 rather than an ad hoc hard-coded literal outside the Menu/Pause string table.
- [ ] **AC-MENU-18**: **GIVEN** pause root is open on desktop, **WHEN** `Quit` is confirmed, **THEN** controls disable, Menu/Pause requests normal application quit through the approved platform/tree quit route, and no second quit or transition request can fire before shutdown begins.

## I. Visual/Audio Requirements

| Element | Requirement | Source |
|---|---|---|
| Pause overlay | Dark semi-transparent concrete panel, reduced-saturation cyan focus highlight, no gameplay stat readouts. | Art Bible Menu/HUD visual direction |
| Focus highlight | Must be visible by shape/position, not color alone. | Accessibility baseline |
| Animation | Cut-in or very short 4-frame open; no long fade that delays focus. | Pillar 4 / UI responsiveness |
| UI SFX | Optional `menu_select`, `menu_confirm`, `menu_cancel`; one at a time through Audio #4 `play_ui`. | Audio #4 OQ-AU-5 closure |
| Music/BGM | Menu/Pause does not own BGM. Audio #4 handles BGM lifecycle and bus volumes. | Audio #4 |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:menu-pause` for pause panel, focus cursor, options panel, and optional UI SFX asset descriptions.

## J. UI Requirements

### J.1 Pause Root

| Item | Action | Owner |
|---|---|---|
| Resume | Unpause and close overlay. | Menu/Pause + PauseHandler |
| Restart Checkpoint | Request Scene Manager checkpoint restart. | Scene Manager #2 |
| Options | Open session-only options surface. | Menu/Pause |
| Quit | Request application quit. | Menu/Pause / platform |

### J.2 Session Options

| Control | Range | Persistence | Owner |
|---|---|---|---|
| Master Volume | `0.0..1.0` step `0.05` | Session only | `AudioManager.set_session_bus_volume(&"Master", value)` |
| Music Volume | `0.0..1.0` step `0.05` | Session only | `AudioManager.set_session_bus_volume(&"Music", value)` |
| SFX Volume | `0.0..1.0` step `0.05` | Session only | `AudioManager.set_session_bus_volume(&"SFX", value)` |
| UI Volume | `0.0..1.0` step `0.05` | Session only | `AudioManager.set_session_bus_volume(&"UI", value)` |

### J.3 Stable Menu String Keys

Tier 1 text remains English-only until Localization #22, but visible labels must be assigned through stable keys so later localization cannot alter focus order, action semantics, or row identity.

| String key | Default English | Surface | Notes |
|---|---|---|---|
| `menu.pause.title` | `Paused` | Pause root | Header only; not focusable. |
| `menu.pause.resume` | `Resume` | Pause root | Default focused row. |
| `menu.pause.restart_checkpoint` | `Restart Checkpoint` | Pause root | Immediate restart request; no Tier 1 confirmation modal. |
| `menu.pause.options` | `Options` | Pause root | Opens `OPTIONS_SESSION`. |
| `menu.pause.quit` | `Quit` | Pause root | Desktop process quit route. |
| `menu.options.title` | `Options` | Options | Header only; not focusable. |
| `menu.options.master_volume` | `Master Volume` | Options | Session-only slider. |
| `menu.options.music_volume` | `Music Volume` | Options | Session-only slider. |
| `menu.options.sfx_volume` | `SFX Volume` | Options | Session-only slider. |
| `menu.options.ui_volume` | `UI Volume` | Options | Session-only slider. |
| `menu.options.session_only_note` | `Session only — resets when you quit.` | Options | Non-blocking note. |
| `menu.common.back` | `Back` | Options | Uses Rule 15 cancel/back input. |

### J.4 UI Input Sources

| Intent | Input source | Required handling |
|---|---|---|
| Navigate list | `ui_up` / `ui_down`; mouse hover | Moves focus to nearest enabled row and updates visible selected state. |
| Adjust slider | `ui_left` / `ui_right`; mouse drag on focused slider | Changes slider by `session_volume_step`; no disk write. |
| Confirm | `ui_accept`; primary mouse release on enabled focused/hovered control | Activates focused row unless cancel/back/pause occurred in the same frame. |
| Back from options | `ui_cancel`; Input #1 `pause` action via `PauseHandler` | Returns to `PAUSE_ROOT`. |
| Resume from pause root | `ui_cancel`; Input #1 `pause` action via `PauseHandler`; `ui_accept` on `Resume` | Closes overlay and unpauses. |

Deferred UI surfaces:

- Input Remapping → #23.
- Accessibility Options → #24.
- Language selection → #22.
- Persistent settings save/load → #21.
- Return to Title / title-menu shell → Tier 2 Scene Manager + Menu/Pause revision.

**📌 UX Flag — Menu / Pause System**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design design/gdd/menu-pause.md` before implementation stories for pause, options, or focus navigation.

## K. Open Questions

| ID | Question | Owner | Target |
|---|---|---|---|
| OQ-MENU-1 | Should `Restart Checkpoint` require a confirmation in Tier 2 after playtest, or is one-tap restart aligned with Pillar 1? | game-designer + QA | Tier 1 playtest review |
| OQ-MENU-2 | Which exact UI SFX assets fill `menu_select`, `menu_confirm`, `menu_cancel`? | audio-director | Asset-spec/audio pass |

---

## L. Decision Log

| Decision | Date | Owner | Rationale |
|---|---|---|---|
| PauseHandler remains authority | 2026-05-13 | game-designer | Prevents duplicate pause listeners and respects Input #1 architecture. |
| No pause during DYING/REWINDING | 2026-05-13 | game-designer | Preserves Time Rewind decision pressure; no analysis-time exploit. |
| Session-only options | 2026-05-13 | game-designer | Save/Persistence #21 not authored; avoids disk-write scope creep. |
| No first-launch menu gate | 2026-05-13 | game-designer | Preserves Story Intro #17 and Pillar 4 immediate core-loop access. |
| Return to Title deferred | 2026-05-13 | game-designer | Scene Manager has no explicit Tier 1 title route; keeps Menu/Pause shippable and avoids adding a front-end shell. |
