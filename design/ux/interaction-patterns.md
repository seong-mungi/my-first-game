# Interaction Pattern Library

> **Status**: In Design
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-14
> **Template**: Interaction Pattern Library
> **Primary Inputs**: `design/gdd/game-concept.md`, `design/gdd/hud.md`, `design/gdd/menu-pause.md`, `design/gdd/story-intro-text.md`, `design/accessibility-requirements.md`, `.claude/docs/technical-preferences.md`

---

## Overview

This library defines Echo's reusable Tier 1 interaction patterns before individual UX specs are authored. Because no existing `design/ux/*.md` screen specs existed when this file was created, the first catalog is seeded from approved GDD requirements rather than extracted from completed UX specs.

Echo is a PC Steam / Steam Deck-friendly 2D run-and-gun with gamepad as the primary input and keyboard/mouse parity. Interaction patterns therefore prioritize:

- **Immediate combat readability**: survival information must be readable in a 0.2-second glance without turning the game into a stat-bar UI.
- **Controller-first navigation**: focusable UI must work with d-pad/stick, `ui_accept`, `ui_cancel`, and the existing `pause` action.
- **No color-only meaning**: every important state uses shape, text, icon, position, animation, or audio redundancy.
- **Minimal Tier 1 scope**: no input remapping UI, localization selector, persistent settings UI, accessibility options stack, or production title/menu shell.
- **Presentation-only UI boundaries**: HUD, Story Intro, and Menu/Pause display information or request approved owner actions; they do not mutate gameplay state directly.

---

## Pattern Catalog

| Pattern | Category | One-line Description | Primary Use |
|---|---|---|---|
| Gameplay HUD Readout | Data Display | Screen-anchored, non-focusable combat information shown without stealing gameplay input. | Token, ammo, weapon, boss pulse surfaces |
| Rewind Token Counter | Data Display / Feedback | Upper-left token readout with distinct consume, gain, cap-full, and denied feedback. | Time Rewind availability |
| Transient Button Prompt | Prompt / Feedback | Short, non-modal input hint with device-specific button label. | First-death rewind hint |
| Denied Action Pulse | Feedback | Brief unavailable-action response using shape/motion/audio, not color alone. | Rewind denied, unavailable menu action |
| Boss Presence / Phase Pulse | Feedback / Overlay | Non-numeric boss state cue that signals escalation without exposing HP or hit counts. | STRIDER encounter feedback |
| Weapon & Ammo Readout | Data Display | Lower-right secondary readout with weapon icon and exact ammo count. | Player Shooting HUD |
| Focusable Menu List | Navigation | Compact controller-navigable list with one visible selected item. | Pause root menu |
| Controller Focus Highlight | Input / Accessibility | Persistent focus shape that survives colorblind or low-contrast conditions. | All focusable Control UI |
| Session Audio Slider | Input / Settings | Non-persistent slider control using approved audio facade and clear session-only copy. | Pause options |
| Disabled Transition State | Feedback / Safety | Submitted controls become visibly disabled while restart/quit/scene transition is pending. | Pause restart/quit |
| Passive Typewriter Text | Narrative / Display | Deterministic non-focus text reveal with no prompt gate and safe interruption. | Story Intro |
| Input Glyph Label | Input / Prompt | Device-profile-derived label rendered as text/glyph without reading raw InputMap. | Prompts and future menu help |
| Flash-Safe Fullscreen Feedback | Feedback / Accessibility | Fullscreen visual effects with duration/intensity limits and non-color backup signals. | Rewind shader, death flash |

---

## Patterns

### Gameplay HUD Readout

**Category**: Data Display  
**Used In**: HUD, future combat UX specs

**Description**: A screen-anchored `CanvasLayer` display for live combat information that never captures focus or consumes gameplay input. This pattern preserves Echo's "sharp instrument panel" fantasy: the player can read survival-relevant state without playing the HUD.

**Specification**:
- Render in screen space using safe-area positions; do not parent core HUD to world entities.
- Use non-interactive `Control` nodes during gameplay: `mouse_filter = MOUSE_FILTER_IGNORE`, no focus mode, no `_gui_input` gameplay consumption.
- Keep persistent elements minimal: REWIND tokens, weapon icon, ammo count, and approved transient boss/prompt cues.
- Maintain visual separation from collage backgrounds using Concrete Dark panels/frames and readable typography.
- Pair color with shape, icon, count, position, or animation for every gameplay-critical state.

**When to Use**: Persistent or transient combat information that must stay visible while the player controls ECHO.  
**When NOT to Use**: Focusable pause/options controls, title menus, remap screens, or any UI that asks the player to make menu selections.  
**Reference**: `design/gdd/hud.md` C.1 Rules 1, 10, 11, 13.

### Rewind Token Counter

**Category**: Data Display / Feedback  
**Used In**: HUD

**Description**: The primary persistent HUD pattern. It displays Time Rewind availability as exact token state and makes consume/gain/denied/cap-full outcomes impossible to confuse.

**Specification**:
- Place in the upper-left safe area and keep larger than secondary ammo/weapon information.
- Initialize from `TimeRewindController.get_remaining_tokens()` and update only from approved token signals.
- Distinguish four feedback kinds:
  - **Consume**: count decreases; active token icon drains/pops out.
  - **Gain**: count increases; new token fills with Neon Cyan pulse.
  - **Cap full**: reward fires while already at max; show a distinct full-cap pulse even though count does not change.
  - **Denied**: unavailable rewind pulse on the counter plus Audio #4 denied SFX.
- During REWINDING protection, cache logical token changes and delay count-changing animation until `rewind_protection_ended`.
- Never rely on hue alone; the token count/icon shape must remain meaningful under color changes and rewind shader inversion.

**When to Use**: Any display of player-owned rewind availability.  
**When NOT to Use**: Health, boss HP, cooldown meters, or persistent score/progression displays.  
**Reference**: `design/gdd/hud.md` C.1 Rules 2–5; `design/gdd/time-rewind.md` UI Requirements.

### Transient Button Prompt

**Category**: Prompt / Feedback  
**Used In**: HUD first-death prompt, future contextual prompts

**Description**: A brief, non-modal prompt that appears at the moment the player needs one action. It teaches without pausing, stealing focus, or creating a tutorial overlay.

**Specification**:
- Show exactly one action label plus action meaning, e.g. `[LT] Rewind` or `[Shift] Rewind`.
- Button text must come from Input #1's `button_label(profile, action_id)` API.
- Fade in/out over the approved 12-frame prompt window unless a later UX spec tightens timing.
- Do not pause gameplay, open a modal, capture focus, or require confirmation.
- Suppress after the first successful rewind in the session; reset on scene change per HUD rules.
- Keep copy short enough for Steam Deck readability and future localization expansion.

**When to Use**: First-time or rare contextual teaching where one immediate action matters.  
**When NOT to Use**: Multi-step tutorials, persistent instructions, story text, or menu navigation help that needs focus.  
**Reference**: `design/gdd/hud.md` C.1 Rule 6; `design/gdd/input.md` UI.1.

### Denied Action Pulse

**Category**: Feedback  
**Used In**: HUD rewind denied, Menu/Pause disabled controls

**Description**: A short "you cannot do that now" response that confirms input was received while preserving the game's deterministic, fast feel.

**Specification**:
- Use a small scale shake, blocked outline, icon deformation, or count jiggle as the primary signal.
- Color such as Ad Magenta may support the state, but shape/motion/text/audio must carry the meaning.
- Optional audio must route through Audio #4 (`play_rewind_denied()` or `play_ui(stream)` as appropriate).
- Keep duration brief; do not add explanatory modal text during combat.
- For focusable UI, leave focus on the current valid control and avoid moving selection as part of the denied response.

**When to Use**: Rewind attempted with no token, unavailable pause/options control, blocked transition submit.  
**When NOT to Use**: Fatal errors, save corruption, crash handling, or any case needing explicit player recovery instructions.  
**Reference**: `design/gdd/hud.md` C.1 Rule 3; `design/gdd/menu-pause.md` C.1 Rules 3, 13, 15.

### Boss Presence / Phase Pulse

**Category**: Feedback / Overlay  
**Used In**: HUD, STRIDER boss encounter

**Description**: A non-numeric boss-state cue that reinforces escalation while keeping player attention on boss behavior and telegraphs.

**Specification**:
- Allowed cues: brief boss title/presence flash, phase-change pulse, victory/clear cue.
- Forbidden production cues: boss HP bar, segmented boss bar, hit counter, remaining-hit count, damage numbers, `phase_hp_table` exposure.
- Use pulse timing, frame shape, title text, icon, or silhouette-adjacent presentation rather than color alone.
- Keep the cue transient and screen-space; no Tier 1 world-anchored boss UI.
- Do not subscribe to or display `boss_hit_absorbed` or internal hit accounting.

**When to Use**: Boss encounter arming, phase advance, boss defeated.  
**When NOT to Use**: Standard enemy deaths, hidden damage math, scoring, or boss health visualization.  
**Reference**: `design/gdd/hud.md` C.1 Rule 9; `design/gdd/boss-pattern.md` UI Requirements.

### Weapon & Ammo Readout

**Category**: Data Display  
**Used In**: HUD

**Description**: A secondary lower-right readout that confirms weapon identity and exact current ammo without competing with the REWIND token counter.

**Specification**:
- Place in lower-right safe area, below token priority in size/contrast.
- Show weapon icon/silhouette and exact ammo integer.
- Read approved Player Shooting data: `weapon_equipped`, `weapon_fallback_activated`, `WeaponSlot.ammo_count`, and weapon data from `weapons.tres`.
- Tolerate same-tick auto-reload without flashing misleading empty warnings unless Player Shooting also emits/plays an explicit empty/fallback branch.
- Use subdued normal state and stronger non-color-backed feedback for low/empty/fallback states if those are surfaced in a later HUD UX spec.

**When to Use**: Current weapon and magazine display.  
**When NOT to Use**: Weapon inventory grids, pickup comparison cards, stats pages, or scoreboards.  
**Reference**: `design/gdd/hud.md` C.1 Rules 7–8; `design/gdd/player-shooting.md` UI Requirements.

### Focusable Menu List

**Category**: Navigation  
**Used In**: Pause root, future title/options surfaces

**Description**: A compact vertical menu list controlled by gamepad, keyboard, and mouse, with exactly one visible selected control.

**Specification**:
- On open, default focus goes to the safest/highest-frequency action (`Resume` for pause root).
- Navigation uses Godot UI actions (`ui_up`, `ui_down`, `ui_left`, `ui_right`) plus mouse hover over enabled controls.
- Confirm uses `ui_accept` or primary mouse release; cancel/back uses `pause` or `ui_cancel`.
- Held navigation follows the approved repeat formula from Menu/Pause GDD.
- If mouse and keyboard/gamepad focus diverge, keyboard/gamepad focus remains authoritative for controller navigation.
- Do not add project-specific Tier 1 actions such as `menu_confirm` or `menu_cancel`.

**When to Use**: Focusable UI where the player chooses among discrete actions.  
**When NOT to Use**: Gameplay HUD, Story Intro text, first-death rewind prompt, or combat overlays.  
**Reference**: `design/gdd/menu-pause.md` C.1 Rules 2, 13, 15 and D.1.

### Controller Focus Highlight

**Category**: Input / Accessibility  
**Used In**: Pause root, options, future focusable UI

**Description**: The selected UI element must be obvious on Steam Deck and keyboard/gamepad without depending on color.

**Specification**:
- Use at least one shape-based indicator: outline, bracket, cursor wedge, underline block, or selected-row panel.
- Color can supplement focus but cannot be the only signal.
- The focused row/control remains visible after mouse hover changes unless controller focus is intentionally moved.
- Disabled controls must be visibly distinct from enabled controls by opacity/shape/text state, not hue alone.
- Focus repair must complete within the Menu/Pause GDD's one-frame target after loss/divergence.

**When to Use**: Every focusable `Control` in Tier 1 and future menus.  
**When NOT to Use**: Non-focus HUD controls or passive story copy.  
**Reference**: `design/accessibility-requirements.md` Color-as-Only-Indicator Audit; `design/gdd/menu-pause.md` C.1 Rule 13.

### Session Audio Slider

**Category**: Input / Settings  
**Used In**: Pause options

**Description**: A controller-friendly slider for session-only Master/Music/SFX/UI volume. It adjusts comfort settings without implying persistence before Save/Settings exists.

**Specification**:
- Expose only approved Tier 1 buses: Master, Music, SFX, UI.
- Read/write via Audio #4 facade:
  - `AudioManager.get_session_bus_volume(bus_name)`
  - `AudioManager.set_session_bus_volume(bus_name, linear_value)`
- Clamp value to `0.0..1.0`; default `1.0`.
- Show a short "session only" note or equivalent copy when options are surfaced.
- Do not write to disk or call AudioServer directly.
- Slider focus, value change, and disabled state must follow Focusable Menu List and Controller Focus Highlight patterns.

**When to Use**: Tier 1 audio comfort controls.  
**When NOT to Use**: Persistent settings, input remapping, language selection, accessibility options, difficulty assists.  
**Reference**: `design/gdd/menu-pause.md` C.1 Rule 9; `design/gdd/audio.md` AudioManager session facade.

### Disabled Transition State

**Category**: Feedback / Safety  
**Used In**: Pause restart, quit, future scene-transition submits

**Description**: Once the player submits a transition action, controls become visibly non-interactive to prevent double submits and communicate that ownership has passed to the transition system.

**Specification**:
- Enter after Restart Checkpoint or Quit is accepted.
- Disable all menu controls and ignore further confirm/cancel submits while transition is pending.
- Keep a visible focus/selection state only if it helps communicate the submitted row; otherwise show a neutral "transition requested" state.
- Do not immediately resume gameplay while waiting for Scene Manager or process quit.
- If the scene boundary/shutdown completes same-frame, the state may be effectively invisible but must still exist in implementation logic.

**When to Use**: Any UI action that requests a scene transition, restart, quit, purchase, save, or other non-repeatable handoff.  
**When NOT to Use**: Ordinary menu navigation, slider changes, or reversible focus movement.  
**Reference**: `design/gdd/menu-pause.md` C.1 Rule 8 and C.2.

### Passive Typewriter Text

**Category**: Narrative / Display  
**Used In**: Story Intro

**Description**: Deterministic atmospheric text reveal that adds mood without becoming a prompt, modal, or cutscene gate.

**Specification**:
- Exactly five visible narrative lines in Tier 1.
- No "Press any key", "Start", "Continue", blinking glyph, or input gate.
- No focus, menu selection, pause, skip action, or custom input action.
- Reveal timing is deterministic and based on fixed-step counters.
- First input may interrupt via Scene Manager's cold-boot transition; Story Intro stops local reveal work on scene unload.
- Text must remain readable at Steam Deck scale and fit line-length caps.

**When to Use**: Passive cold-boot atmosphere or future non-interactive lore display.  
**When NOT to Use**: Tutorials, prompts, menu help, dialogue choices, mission briefings that require confirmation, or settings screens.  
**Reference**: `design/gdd/story-intro-text.md` C.1 Rules 1–10.

### Input Glyph Label

**Category**: Input / Prompt  
**Used In**: First-death prompt, future contextual prompts and menu help

**Description**: A device-profile-derived button label that stays consistent across gamepad and keyboard/mouse without letting UI inspect raw bindings.

**Specification**:
- Request labels from Input #1 using `button_label(profile: DeviceProfile, action_id: StringName) -> String`.
- Tier 1 approved examples: `[Shift] Rewind` / `[LT] Rewind`.
- Render label as text or glyph-like text inside a small stable frame.
- Maintain keyboard/mouse parity, but optimize layout for gamepad/Steam Deck first.
- Do not add full input-remap affordances in Tier 1.

**When to Use**: Any UI text that names a player input.  
**When NOT to Use**: Dynamic remapping UI, control settings screens, or hard-coded per-platform strings outside Input #1 ownership.  
**Reference**: `.claude/docs/technical-preferences.md` Input & Platform; `design/gdd/input.md` UI.1.

### Flash-Safe Fullscreen Feedback

**Category**: Feedback / Accessibility  
**Used In**: Rewind shader, death flash, intense VFX presentation

**Description**: Fullscreen feedback must be recognizable and punchy without creating unsafe strobe patterns or hiding gameplay-critical reads.

**Specification**:
- Rewind activation may use cyan/magenta inversion and glitch decomposition, but recognition must not depend on color alone.
- Pair fullscreen color effects with shape, silhouette, visibility cadence, audio, screen shake, or text/icon backup where the state matters.
- Death flash remains minimal; complex death animations that delay restart violate the core loop.
- Avoid unsafe flash/strobe patterns; follow the project's photosensitivity guard and ADR-0010 limits where applicable.
- HUD token counter and boss warning readability must not be hidden by fullscreen effects.

**When to Use**: Rewind activation, rewind protection, death transition, boss-kill catharsis, other high-intensity one-shot presentation.  
**When NOT to Use**: Routine menu selection, low ammo, focus movement, normal enemy damage, or any repeated feedback likely to strobe.  
**Reference**: `design/art/art-bible.md` Time-Rewind visual direction; `design/accessibility-requirements.md` Visual Accessibility; `design/gdd/time-rewind-visual-shader.md` UI Requirements.

---

## Gaps & Patterns Needed

| Gap | Why It Matters | Proposed Owner / Timing |
|---|---|---|
| HUD UX spec not yet authored | This library defines patterns, but `design/ux/hud.md` must still map exact layout, information hierarchy, states, and acceptance criteria. | `/ux-design hud` before Pre-Production gate |
| Pause/Menu UX spec not yet authored | Menu/Pause GDD defines behavior, but a UX spec should lock visual layout, focus order, options screen composition, and localization constraints. | `/ux-design menu-pause` |
| Accessibility options pattern deferred | Basic tier is committed, but full text scale/reduced motion/remap patterns are intentionally out of Tier 1. | Future Accessibility #24 / Tier 2–3 |
| Localization expansion pattern deferred | Tier 1 is English-only / Korean-ready; no localization UI or text expansion rules per screen are locked yet. | Future Localization #22 plus per-screen UX specs |
| Modal confirmation pattern not in Tier 1 | Restart confirmation is intentionally omitted; if playtest shows accidental restart, add a confirmation modal pattern. | Tier 2 Menu/Pause revision if needed |
| Title/menu shell pattern deferred | Cold boot remains Story Intro → gameplay; no production title menu exists in Tier 1. | Future Scene Manager/Menu revision |
| World-anchored UI pattern forbidden for Tier 1 | Boss HP bars and entity labels remain out of scope; if future features need world labels, ownership must be reviewed. | Tier 2 HUD/VFX review |

---

## Open Questions

- Should `design/ux/hud.md` be the first full UX spec, since HUD is the highest-value consumer of this pattern library and already blocks Pre-Production readiness?
- Should the pause/options UX spec include a visible "session only" note beside every slider or one note at the top/bottom of the options panel?
- Should low-ammo presentation remain purely secondary/subdued in Tier 1, or should a later HUD UX spec define a stronger low-ammo warning despite instant auto-reload?
- Should the first-death rewind prompt appear near the token counter or near lower center? HUD GDD allows either; the HUD UX spec must choose.
- Should future Korean/English readiness introduce a maximum label character budget for all prompt/menu labels before full Localization #22 exists?
