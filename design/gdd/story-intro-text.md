# Story Intro Text System

> **Status**: Approved
> **Author**: Codex Game Studios
> **Last Updated**: 2026-05-13
> **Implements Pillars**: Pillar 3 (Collage is the first impression), Pillar 4 (5-Minute Rule), Pillar 5 (Small Success)
> **Engine**: Godot 4.6 / GDScript / `CanvasLayer` + `Control` text presentation
> **Review Mode**: Lean authoring; CD-GDD-ALIGN skipped per lean mode

---

## A. Overview

Story Intro Text System #17 is the Tier 1 narrative entry beat: a passive, five-line typewriter text sequence shown on the cold-boot intro scene before gameplay begins. It gives Echo one immediate worldbuilding impression without becoming a cutscene, tutorial page, menu gate, or dialogue framework. The system owns only intro copy, pacing, text reveal, visual treatment, and safe interruption behavior; Scene Manager #2 owns the cold-boot scene transition, and Input #1 owns the first-input route into gameplay.

Tier 1 scope is deliberately tiny: exactly five English lines, one screen, no branching, no player choice, no save flag, no localization pipeline, no cinematic camera, and no blocking "Press any key" prompt. The player may skip the atmosphere by providing the normal first start input; the intro must never delay the core loop beyond Pillar 4's 5-minute rule.

## B. Player Fantasy

The intro fantasy is not "watching a story"; it is the feeling of being dropped into a city that has already been edited by someone else. The player should read a few cold, definitive fragments, understand that ECHO is a surviving signal inside a surveilled megacity, and then immediately act.

Player-facing emotional target:

- **Grim certainty**: the world is hostile and controlled before the player moves.
- **Agency under compression**: the final line should feel like an order the player can obey right now.
- **No cutscene resentment**: a player who wants to get to movement and shooting can do so without fighting a modal text box.

The five-line copy is:

1. `WE BUILT A CITY THAT REMEMBERS EVERYTHING.`
2. `THEN THEY TAUGHT IT TO FORGET.`
3. `YOU ARE ECHO — THE LAST SIGNAL IN THE NOISE.`
4. `ONE SECOND IS ALL THEY COULDN'T ERASE.`
5. `TAKE IT BACK.`

This supports the game concept's resolved dystopian serious tone and the "post-death revoke" fantasy without explaining mechanics in tutorial prose.

## C. Detailed Design

### C.1 Core Rules

**Rule 1 — Five-line hard cap.**  
Tier 1 Story Intro contains exactly five visible narrative lines. More lines require a GDD revision because added copy directly competes with Pillar 4.

**Rule 2 — Passive renderer only.**  
The intro text controller is a presentation node inside the cold-boot intro scene. It may reveal text, hide text, emit local presentation signals, and free its own timers/tweens. It must not mutate gameplay state, grant tokens, move ECHO, alter input mappings, change scenes, or write save data.

**Rule 3 — Scene transition ownership stays with Scene Manager.**  
Story Intro must not call `SceneTree.change_scene_to_packed()` directly. Cold-boot transition into `stage_1_packed` remains owned by Scene Manager #2 through its approved `TransitionIntent.COLD_BOOT` flow.

**Rule 4 — First input is not an intro-specific action.**  
Story Intro adds no new InputMap action. Input #1's existing cold-boot first-input route decides when gameplay starts. Story Intro is allowed to be interrupted by that scene transition at any point.

**Rule 5 — No explicit "Press any key" prompt.**  
The intro may show story copy only. It must not display "Press any key", "Start", "Continue", a blinking confirm glyph, or any equivalent input gate. This preserves Scene Manager Rule 13 and Pillar 4.

**Rule 6 — Skip/interruption is safe and silent.**  
If the cold-boot input route starts gameplay before the five lines finish, Story Intro stops all local reveal work immediately as part of scene unload. It does not show a confirmation, does not replay on the stage scene, and does not attempt to finish remaining lines.

**Rule 7 — Deterministic text reveal.**  
Reveal progress is based on a fixed timer derived from `Engine.get_physics_frames()` or an equivalent fixed-step counter, not wall-clock drift. Identical boot frame sequences reveal the same character counts at the same frames.

**Rule 8 — Copy is data, not code.**  
The five lines live in a small data resource or exported string array owned by this system. Code must not scatter the five string literals across unrelated scripts.

**Rule 9 — Localization-ready, not localized.**  
Tier 1 ships English-only text, but each line has a stable string key so Localization #22 can replace the values later without changing timing or scene flow.

**Rule 10 — No tutorialization.**  
The intro must not explain controls, token counts, enemy rules, boss rules, or rewind timing. HUD #13 owns the first-death rewind prompt; gameplay onboarding remains "force shoot + jump + one rewind within 30 seconds" from the game concept.

### C.2 States and Transitions

| State | Entry Trigger | Exit Trigger | Behavior |
|---|---|---|---|
| `HIDDEN` | Cold-boot scene `_ready()` not yet completed | Intro node ready | No text visible; no input focus. |
| `REVEALING_LINE` | Start of each line | Current line visible character count reaches line length | Increment visible characters at `story_intro_chars_per_second`. |
| `LINE_HOLD` | A line finishes revealing | `story_intro_line_hold_frames` expires | Hold the completed line before the next line begins. |
| `COMPLETE_HOLD` | Fifth line finishes revealing | Scene transition or player remains idle | Keep all five lines visible; no prompt appears. |
| `INTERRUPTED` | Scene Manager begins cold-boot transition / scene unload | Node freed | Stop timers/tweens; do not emit gameplay events. |

Valid transitions:

```text
HIDDEN
  -> REVEALING_LINE(1)
  -> LINE_HOLD(1)
  -> REVEALING_LINE(2)
  -> LINE_HOLD(2)
  -> REVEALING_LINE(3)
  -> LINE_HOLD(3)
  -> REVEALING_LINE(4)
  -> LINE_HOLD(4)
  -> REVEALING_LINE(5)
  -> COMPLETE_HOLD

Any active state -> INTERRUPTED when the cold-boot scene is unloaded.
```

There is no failure state in Tier 1; missing text data falls back to the exact five default lines from Section B.

### C.3 Interactions with Other Systems

| System | Story Intro receives / reads | Story Intro provides | Forbidden |
|---|---|---|---|
| Scene Manager #2 | Cold-boot intro scene lifetime; scene unload interruption | A passive scene-internal text node; no required SM signal | Calling `change_scene_to_packed`; owning `TransitionIntent`; extending restart budget |
| Input #1 | Existing cold-boot first-input route may interrupt intro via scene transition | No new action; no raw input mapping reads | Adding `skip_intro`; reading `InputMap` directly for bindings |
| HUD #13 | None in Tier 1 | Clear ownership boundary: HUD owns prompts; Story Intro owns only intro copy | Reusing HUD as a general text overlay; showing prompts during gameplay |
| Menu / Pause #18 | Future menu may link to credits/story recap outside Tier 1 | No dependency in Tier 1 | Adding options, pause, replay, or settings UI here |
| Localization #22 | Future replacement of `STORY_INTRO_LINE_01..05` | Stable keys and English defaults | Shipping full multilingual options in Tier 1 |
| Art Bible | Story Intro mood, palette, typography direction | One screen-space text treatment | Full-screen cinematic/photo montage beyond the approved collage background |

## D. Formulas

### D.1 Typewriter Reveal Formula

The `story_intro_reveal_chars` formula is defined as:

`story_intro_reveal_chars = min(line_length_chars, floor(elapsed_frames * story_intro_chars_per_second / 60.0))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `line_length_chars` | `L` | int | `1..64` | Character count for the current line, including spaces and punctuation. |
| `elapsed_frames` | `F` | int | `0..240` | Fixed-step frames since current line reveal began. |
| `story_intro_chars_per_second` | `CPS` | float | `30..48` | Designer pacing knob; default `32.0`. |

**Output Range:** `0..L`; clamps at the current line length.  
**Example:** For line 1 (`L=42`) at default `CPS=32.0`, after `F=60` frames: `floor(60 * 32 / 60) = 32`, so 32 of 42 characters are visible.

### D.2 Total Intro Auto-Reveal Duration

The `story_intro_total_reveal_seconds` formula is defined as:

`story_intro_total_reveal_seconds = (sum(line_length_chars) / story_intro_chars_per_second) + ((story_intro_line_count - 1) * line_hold_seconds) + final_hold_seconds`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `sum(line_length_chars)` | `ΣL` | int | `1..320` | Total visible characters across all five lines. Tier 1 default copy totals `167`. |
| `story_intro_chars_per_second` | `CPS` | float | `30..48` | Reveal speed; default `32.0`. |
| `story_intro_line_count` | `N` | int | `5 only` | Locked Tier 1 line count. |
| `line_hold_seconds` | `H` | float | `0.0..0.30` | Pause after lines 1–4; default `0.30`. |
| `final_hold_seconds` | `FH` | float | `0.5..1.0` | Pause after line 5 completes; default `1.0`. |

**Output Range:** With the default five-line copy, safe tuning produces `3.98..7.77 s`; Tier 1 default `7.41875 s`. The validation invariant is `story_intro_total_reveal_seconds <= intro_screen_duration_seconds` from Scene Manager #2 (`8.0 s` default).  
**Example:** `(167 / 32.0) + ((5 - 1) * 0.30) + 1.0 = 7.41875 s`.

### D.3 Intro UI Draw-Call Estimate

The `story_intro_draw_call_estimate` formula is defined as:

`story_intro_draw_call_estimate = background_draws + watermark_draws + text_draws + panel_draws`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `background_draws` | `B` | int | `0..3` | Static collage/photo background layers used by the intro scene. |
| `watermark_draws` | `W` | int | `0..2` | VEIL surveillance icon watermark or ARCA stamp overlays. |
| `text_draws` | `T` | int | `1..5` | Font/material draws for visible text lines. |
| `panel_draws` | `P` | int | `0..2` | Optional dark text panel or mask draws. |

**Output Range:** `1..12`; Tier 1 budget `<= 12` draw calls, inside the Art Bible UI/HUD allocation of 40.  
**Example:** `B=2`, `W=1`, `T=5`, `P=1` gives `9` draw calls.

## E. Edge Cases

- **If the player provides the first cold-boot input before line 1 finishes**: Scene Manager may transition to gameplay immediately through the approved cold-boot path; Story Intro enters `INTERRUPTED` and does not block the transition.
- **If the player never provides input**: the intro completes, holds all five lines visible, and shows no prompt. This is an idle title-like state, not a gameplay gate.
- **If text data is missing or empty**: load the five default English lines from Section B and log one warning. Do not show an empty screen.
- **If a line exceeds 64 characters**: fail the content validation check and require copy edit before implementation merge. Long lines risk Steam Deck readability and timing overflow.
- **If `story_intro_chars_per_second <= 0`**: clamp to default `32.0` and log a configuration warning; do not divide by zero.
- **If total reveal duration exceeds Scene Manager's `intro_screen_duration_seconds` default of 8.0 s**: content validation fails. Either shorten copy, increase CPS inside safe range, or revise Scene Manager's intro timing through a cross-doc batch.
- **If `scene_will_change()` fires while a reveal tween/timer is active**: local reveal work stops and the node frees normally with the scene. No extra cleanup signal is required.
- **If the approved font is missing**: fall back to the approved monospace UI/body font family; do not render tofu boxes for the five critical lines.
- **If localization later expands Korean/English line length beyond the timing budget**: Localization #22 must tune localized CPS/line breaks while preserving the five-line structure and no-prompt rule.
- **If the intro scene is revisited after a checkpoint restart**: this is a bug. Checkpoint restart reloads the active stage scene, not the cold-boot intro scene.

## F. Dependencies

### F.1 Upstream Dependencies

| Upstream | Status | Contract | Hard / Soft |
|---|---|---|---|
| Scene Manager #2 | Approved 2026-05-13 | Owns cold-boot scene lifetime, `TransitionIntent.COLD_BOOT`, and transition into `stage_1_packed`. Story Intro is scene-internal presentation only. | **Hard** |
| Input #1 | Approved 2026-05-11 | Owns cold-boot first-input route and action catalog. Story Intro adds no new InputMap action. | **Hard boundary** |
| Art Bible | Draft/active | Defines Story Intro mood: near darkness, single text light source, typewriter typography, VEIL watermark. | **Soft visual** |

### F.2 Downstream Dependents

| Downstream | Expected Use | Status |
|---|---|---|
| Localization #22 | Replaces `STORY_INTRO_LINE_01..05` values and validates per-locale line length. | Tier 3 |
| Accessibility #24 | Audits text size, contrast, reduced animation, and skip affordance if needed. | Tier 3 |
| Menu / Pause #18 | May later expose "Replay intro" from extras/options, outside Tier 1. | Not Started |

### F.3 Reciprocal Notes

- Scene Manager #2 already lists Story Intro #17 as a soft downstream presentation owner. This GDD closes the "Not Started" mirror by specifying that Story Intro requests no Scene Manager signal and must not call scene transition APIs directly.
- HUD #13 states that Story Intro #17 owns narrative text. This GDD preserves that boundary by not using HUD as an intro overlay framework.
- Input #1 remains the owner of cold-boot input semantics; this GDD avoids a new skip action to prevent action-catalog drift.

## G. Tuning Knobs

| Knob | Default | Safe Range | Affects | Out-of-range Behavior |
|---|---:|---:|---|---|
| `story_intro_line_count` | `5` | `5 only` | Scope and timing. | Any other value requires GDD revision. |
| `story_intro_chars_per_second` | `32.0` | `30.0..48.0` | Reveal readability and duration. | Clamp to default and warn if outside range. |
| `story_intro_line_hold_frames` | `18` | `0..18` | Pause after lines 1–4. | Too low reduces readability; too high risks timing overflow. |
| `story_intro_final_hold_frames` | `60` | `30..60` | Final "TAKE IT BACK." emphasis. | Too low weakens punch; too high delays stage start for idle players. |
| `story_intro_max_line_chars` | `64` | `64 only` | Steam Deck readability and timing validation. | Content validation fails above cap. |
| `story_intro_draw_call_budget` | `12` | `1..12` | UI/HUD draw-call allocation. | Remove panels/watermark or merge atlas; do not exceed budget. |

Non-tunable invariants:

- No explicit "Press any key" prompt.
- No new InputMap action.
- No scene transition API calls from Story Intro.
- Five lines remain the Tier 1 hard cap.
- Cross-knob validation must enforce `story_intro_total_reveal_seconds <= 8.0` before implementation merge.

## H. Acceptance Criteria

- [ ] **AC-STI-01**: **GIVEN** the cold-boot intro scene loads, **WHEN** Story Intro initializes, **THEN** exactly five narrative lines are available with keys `STORY_INTRO_LINE_01..05` and English defaults matching Section B.
- [ ] **AC-STI-02**: **GIVEN** line 1 has length `42` and default `story_intro_chars_per_second = 32.0`, **WHEN** 60 fixed frames elapse, **THEN** exactly 32 visible characters are shown and the line is not marked complete yet.
- [ ] **AC-STI-03**: **GIVEN** all five default lines reveal without interruption, **WHEN** the total reveal formula is evaluated, **THEN** `story_intro_total_reveal_seconds == 7.41875` and remains `<= 8.0`.
- [ ] **AC-STI-04**: **GIVEN** any active reveal state, **WHEN** Scene Manager unloads the cold-boot intro scene for `TransitionIntent.COLD_BOOT`, **THEN** Story Intro stops local timers/tweens and does not block or delay the scene transition.
- [ ] **AC-STI-05**: **GIVEN** the player provides first cold-boot input before the intro finishes, **WHEN** the approved Input #1 / Scene Manager #2 cold-boot route fires, **THEN** gameplay may start immediately and Story Intro does not require confirmation.
- [ ] **AC-STI-06**: **GIVEN** the intro reaches `COMPLETE_HOLD`, **WHEN** no input occurs, **THEN** all five lines remain visible and no "Press any key", "Start", "Continue", or confirm glyph is displayed.
- [ ] **AC-STI-07**: **GIVEN** production text data is missing, **WHEN** Story Intro initializes, **THEN** it falls back to the five Section B lines, logs one warning, and renders readable text.
- [ ] **AC-STI-08**: **GIVEN** a configured line exceeds `story_intro_max_line_chars = 64` or the configured copy/timing produces `story_intro_total_reveal_seconds > 8.0`, **WHEN** content validation runs, **THEN** the validation fails and identifies the offending line key or timing invariant.
- [ ] **AC-STI-09**: **GIVEN** the intro scene runs on Steam Deck target resolution, **WHEN** all lines are visible, **THEN** text remains legible with approved monospace/body font fallback and no tofu boxes.
- [ ] **AC-STI-10**: **GIVEN** intro visual assets are enabled, **WHEN** `story_intro_draw_call_estimate` is calculated, **THEN** it is `<= 12` and remains inside the Art Bible UI/HUD allocation.
- [ ] **AC-STI-11**: **GIVEN** static analysis scans Story Intro implementation, **WHEN** it checks scene transition calls, **THEN** no Story Intro script directly calls `change_scene_to_packed`, `change_scene_to_file`, or mutates `TransitionIntent`.
- [ ] **AC-STI-12**: **GIVEN** static analysis scans InputMap usage, **WHEN** it checks Story Intro implementation, **THEN** no new `skip_intro` or equivalent action is declared and no raw binding lookup is performed.

## I. Visual/Audio Requirements

Visual requirements are mandatory for this narrative presentation system.

| Element | Requirement | Source |
|---|---|---|
| Background | Near-dark concrete/collage background; not full black. Use Concrete Dark `#1A1A1E` baseline with subdued photo texture. | Art Bible Story Intro Text state |
| Text style | Monospace terminal/body font for typewriter lines; display cutout font may be used only for a small title/stamp, not the five body lines. | Art Bible Typography |
| Watermark | Optional VEIL surveillance icon watermark, low-contrast and non-animated. | Art Bible environmental storytelling |
| Energy | Lowest energy level; no shake, no flashing, no REWIND shader, no combat VFX. | Art Bible State Lighting |
| Animation | Character-by-character reveal at fixed-step pacing. No cinematic camera movement. | Pillar 4 / Pillar 5 |
| Audio | No required Tier 1 audio dependency. Optional typewriter tick is deferred until Audio/Menu UI SFX catalog is revisited; Story Intro must be fully readable in silence. | Anti-Pillar #4 / Audio #4 boundary |

📌 **Asset Spec** — Visual requirements are defined. After the art bible is approved, run `/asset-spec system:story-intro-text` to produce the intro background, watermark, typography, and optional text-panel asset descriptions.

## J. UI Requirements

Story Intro is a screen-space UI scene, but it is not a menu.

- Use a `CanvasLayer` or equivalent screen-space root so the intro is independent of Camera #3.
- Use non-focusable `Control` nodes. No intro `Control` may grab keyboard/gamepad focus.
- Text should fit 16:9 desktop and Steam Deck handheld scale without wrapping the five default lines.
- No buttons, confirm glyphs, focus rings, cursor hover states, or selectable controls appear in Tier 1.
- Visible strings use stable keys:
  - `STORY_INTRO_LINE_01`
  - `STORY_INTRO_LINE_02`
  - `STORY_INTRO_LINE_03`
  - `STORY_INTRO_LINE_04`
  - `STORY_INTRO_LINE_05`
- If a future "Replay intro" option is added, Menu / Pause #18 owns that navigation surface; this system remains the content renderer.

**📌 UX Flag — Story Intro Text System**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design design/gdd/story-intro-text.md` before writing implementation stories that reference the cold-boot intro scene.

## K. Open Questions

| ID | Question | Owner | Target |
|---|---|---|---|
| OQ-STI-1 | Should the optional VEIL watermark use the same icon as environmental surveillance props or a simplified UI-only mark? | art-director | Asset-spec pass |
| OQ-STI-2 | Should Tier 3 localization preserve all-caps English tone in Korean, or switch to a mixed-weight Korean gothic style for readability? | localization-lead | Localization #22 |
| OQ-STI-3 | Does the optional typewriter tick improve atmosphere or feel like UI noise against the immediate combat start? | audio-director + playtest | Audio polish pass |

---

## L. Decision Log

| Decision | Date | Owner | Rationale |
|---|---|---|---|
| Five lines only | 2026-05-13 | game-designer | Matches systems-index scope and protects Pillar 4 / Pillar 5. |
| No explicit press-any-key prompt | 2026-05-13 | game-designer | Preserves Scene Manager Rule 13 and avoids turning atmosphere into a gate. |
| No new input action | 2026-05-13 | game-designer | Input #1 action catalog is locked; first-input cold-boot routing already exists. |
| No required audio dependency | 2026-05-13 | game-designer | Avoids expanding #17 dependencies beyond Scene Manager; Tier 1 must work silently. |
