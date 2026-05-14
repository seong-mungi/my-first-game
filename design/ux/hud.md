# HUD Design: Echo

> **Status**: In Design
> **Author**: Codex UX designer
> **Last Updated**: 2026-05-14
> **Game**: Echo
> **Platform Targets**: PC (Steam), Steam Deck-friendly
> **Related GDDs**: `design/gdd/hud.md`, `design/gdd/time-rewind.md`, `design/gdd/input.md`, `design/gdd/player-shooting.md`, `design/gdd/boss-pattern.md`, `design/gdd/damage.md`, `design/gdd/camera.md`, `design/gdd/collage-rendering.md`, `design/gdd/time-rewind-visual-shader.md`, `design/gdd/menu-pause.md`
> **Accessibility Tier**: Basic
> **Style Reference**: `design/art/art-bible.md` §7 UI/HUD Visual Direction
> **Input Reference**: `.claude/docs/technical-preferences.md` — gamepad primary, keyboard/mouse parity, no touch

> **Scope boundary**: This document specifies the active gameplay HUD only:
> token counter, first-death rewind prompt, weapon/ammo readout, boss presence
> pulse, death/victory cues, and related presentation feedback. Pause menus,
> title/menu navigation, remapping, localization screens, and settings are owned
> by separate UX/GDD documents.

---

## 1. HUD Philosophy

Echo's HUD is a sharp combat instrument panel, not a stat dashboard. The player
should read the next survival decision in under a glance while still watching the
stage, enemies, projectiles, and collage environment. Because Echo is one-hit-kill,
there is no health bar; the persistent HUD answers only three Tier 1 questions:

1. Can I revoke this mistake?
2. What weapon/ammo state am I acting with?
3. Is a boss/state transition demanding attention right now?

**Visibility principle**: Default to **contextual minimalism**. Keep the REWIND
token counter visible during active gameplay; show every other element only when it
affects the next immediate player decision.

**Rule of Necessity**: A HUD element earns its place when removing it would make a
player meaningfully worse at reading survival, recovery, weapon, or boss-state
decisions within a 0.2-second glance.

**Non-goals**

- No traditional health bar.
- No boss HP bar, remaining-hit counter, phase HP table, or damage numbers.
- No focusable gameplay HUD controls.
- No menu/options functionality inside the active HUD.
- No color-only meaning; every critical state also uses shape, count, text, icon,
  motion, position, or timing.

---

## 2. Information Architecture

### 2.1 Full Information Inventory

| Information Type | Always Show | Contextual | On Demand | Hidden / Diegetic | Reasoning |
|---|---:|---:|---:|---:|---|
| REWIND token count | X |  |  |  | Highest-priority survival resource; required by Pillar 1 and Time Rewind UI contract. |
| Token feedback kind: consumed / gained / cap-full / denied |  | X |  |  | Only meaningful at the moment of the event; should animate on the token counter itself. |
| First-death rewind prompt |  | X |  |  | Teaches the one critical recovery action during DYING before the first successful rewind. |
| Current weapon icon |  | X |  |  | Shows only while a weapon is equipped; secondary to token state. |
| Ammo count |  | X |  |  | Exact `0..30` display supports weapon decisions without creating a spreadsheet HUD. |
| Boss phase / presence pulse |  | X |  |  | Communicates pressure/escalation without exposing hidden boss math. |
| Boss HP / hits remaining / phase table |  |  |  | X | Explicitly forbidden by Boss Pattern and HUD GDDs. |
| Death committed overlay |  | X |  |  | Only after no revoke path is available; should support sub-1-second recovery. |
| Victory / stage clear cue |  | X |  |  | Minimal event confirmation; Scene Manager owns scene transition. |
| Pause/options/menu UI |  |  | X |  | Owned by Menu / Pause #18, not HUD. |
| VEIL alert / surveillance intensity |  |  |  | X | Tier 2+ diegetic environmental language. |

### 2.2 Categorization

| Category | Elements | Display Rule |
|---|---|---|
| Persistent survival state | REWIND token counter | Visible in active gameplay unless a full-screen transition explicitly hides gameplay HUD. |
| Immediate teaching | First-death rewind prompt | Show only during DYING before first successful rewind in the current session. |
| Combat equipment state | Weapon icon, ammo count | Show while weapon is equipped; suppress misleading empty flashes during auto-reload unless a true fallback/empty condition occurs. |
| Encounter pressure | Boss presence / phase pulse | Show only on boss encounter and phase/kill events; never reveal HP math. |
| Terminal gameplay feedback | Death committed overlay, victory cue | Brief, high-priority transition feedback with no scene-state authority. |

---

## 3. Layout Zones

### 3.1 Zone Diagram

Reference layout for 16:9 at 1920×1080. Steam Deck uses the same logic with 5%
safe margins and slightly larger minimum text/icon targets.

```text
0%                                                        100%
┌────────────────────────────────────────────────────────────┐
│  safe margin: 3% PC / 5% Steam Deck                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ [TOKEN ZONE]            [BOSS/PRESENCE]              │  │
│  │ upper-left              upper-center                 │  │
│  │ REWIND icons/count      phase/title pulse only        │  │
│  │                                                      │  │
│  │                                                      │  │
│  │                  [CENTER PLAY AREA]                  │  │
│  │         no persistent HUD; death/victory only         │  │
│  │                                                      │  │
│  │                                                      │  │
│  │ [PROMPT ZONE]                         [WEAPON ZONE]  │  │
│  │ lower-center                          lower-right    │  │
│  │ first-death prompt                     weapon/ammo    │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

### 3.2 Zone Specification Table

| Zone Name | Screen Position | Safe Zone Compliant | Primary Elements | Max Simultaneous Elements | Notes |
|---|---|---|---|---:|---|
| Token Zone | Upper-left, inside safe margin | Yes | REWIND token icons + numeric fallback | 1 grouped widget | Largest persistent HUD element; must pass 0.2-second glance test. |
| Boss / Presence Zone | Upper-center, inside top safe margin | Yes | Boss title flash, phase pulse, victory cue variant | 1 | Event-only; not a boss HP bar. |
| Center Play Area | Center 40% of screen | N/A | Death committed overlay, brief victory cue if needed | 1 transient | No persistent HUD here. Preserve projectile/platform readability. |
| Prompt Zone | Lower-center above bottom safe margin | Yes | First-death rewind prompt | 1 | Uses Input Glyph Label pattern. Must not steal focus. |
| Weapon Zone | Lower-right inside safe margin | Yes | Weapon icon + ammo count | 1 grouped widget | Secondary combat state; should be smaller than Token Zone. |

### 3.3 Platform Safe Margins

| Platform | Top | Bottom | Left | Right | Notes |
|---|---:|---:|---:|---:|---|
| PC Steam 1080p reference | 3% | 3% | 3% | 3% | Avoid window edge crowding and ultrawide stretching. |
| Steam Deck 1280×800 | 5% | 5% | 5% | 5% | Validate handheld readability; minimum touch targets are irrelevant because touch is unsupported. |
| 1280×720 minimum PC check | 5% | 5% | 5% | 5% | Treat as worst-case readability target for Tier 1. |

---

## 4. HUD Element Specifications

### 4.1 Element Overview Table

| Element Name | Zone | Always Visible | Visibility Trigger | Data Source | Update Frequency | Max Size | Min Readable Size | Overlap Priority | Accessibility Alt |
|---|---|---:|---|---|---|---|---|---:|---|
| REWIND Token Counter | Token Zone | Yes during gameplay | Gameplay scene active | TimeRewindController | Init + token signals | ≤18% screen W | 32×32px token icons at 1080p; readable at Steam Deck | 1 | Icon count + exact number; active/spent shape difference. |
| Token Feedback | Token Zone | No | consume / replenish / cap-full / denied | TimeRewindController / SM | Event-driven | Same widget | Same as token counter | 1 | Motion/timing + text/icon state, not color only. |
| First-Death Rewind Prompt | Prompt Zone | No | DYING before first successful rewind | Input + EchoLifecycleSM | Event-driven, 12-frame fade | ≤32% screen W | Glyph + text readable at 720p | 2 | Text fallback: `[LT] Rewind` / `[Shift] Rewind`. |
| Weapon & Ammo Readout | Weapon Zone | No | Weapon equipped | Player Shooting / WeaponSlot | Equip signal + diff-read ammo | ≤14% screen W | Icon 28px, text 18px at 1080p | 3 | Weapon icon + number; no color-only ammo warning. |
| Boss Presence / Phase Pulse | Boss Zone | No | Boss active / phase advanced / boss killed | Boss Pattern / Damage | Event-driven | ≤38% screen W | Title text readable at 720p | 2 | Pulse shape/timing and optional short text; no HP values. |
| Death Committed Overlay | Center Play Area | No | Death committed with no token recovery | Damage / StateMachine | Event-driven | Full-screen tint allowed briefly | Text fallback if any | 1 | Static fallback; no unsafe flashes. |
| Victory Cue | Boss Zone or Center | No | boss killed / stage clear | Damage / Scene Manager | Event-driven | ≤38% screen W | Text readable at 720p | 2 | Stable string key `hud_victory_clear`. |

### 4.2 Element Detail Blocks

#### REWIND Token Counter

- **Visual description**: Three to five token icons arranged horizontally in the
  upper-left. Active token = cyan filled circle inside inverted triangle. Spent
  token = gray outline only. Numeric fallback appears as compact monospace text
  when icon count or scale becomes hard to read.
- **Data displayed**: `remaining_tokens`, `max_tokens`, and infinite-policy symbol
  if `RewindPolicy.infinite == true`.
- **Update behavior**: Initialize from `get_remaining_tokens()`, then update from
  `token_consumed` / `token_replenished`; do not poll TRC after initialization.
- **Urgency states**:
  - Available: active icon count + stable cyan accent.
  - Empty: all spent icons + short denied outline pulse on failed attempt.
  - Cap-full: brief contained flash on token group without count-change animation.
  - Rewinding/protection: cache logical token changes and delay count-changing
    animation until `rewind_protection_ended`.
- **Interaction**: Display only. Non-focusable `Control`; no click/hover action.
- **Patterns**: Rewind Token Counter, Gameplay HUD Readout, Denied Action Pulse.

#### First-Death Rewind Prompt

- **Visual description**: Lower-center button glyph plus verb: `[LT] Rewind` or
  `[Shift] Rewind`, on a small high-contrast panel using the approved monospace HUD
  font. The prompt points attention to the token counter without covering Echo.
- **Data displayed**: Device-profile-aware label from Input #1 `button_label`.
- **Update behavior**: Appears during DYING before first successful rewind; fades
  for 12 frames; suppresses after `first_rewind_success_in_session` until scene reset.
- **Interaction**: The prompt does not handle input. Input #1 and gameplay systems
  own the action.
- **Patterns**: Transient Button Prompt, Input Glyph Label.

#### Weapon & Ammo Readout

- **Visual description**: Small weapon icon plus exact ammo count in lower-right.
  Use line-flat icon style with no photo texture. Ammo text is secondary to token
  state but still readable at Steam Deck scale.
- **Data displayed**: `weapon_id` icon and `WeaponSlot.ammo_count` in exact
  `0..30` range for Tier 1.
- **Update behavior**: Update on `weapon_equipped` / fallback signals; ammo may be
  diff-read once per physics/render tick if no signal exists, without allocation
  when unchanged.
- **Urgency states**: True fallback/invalid weapon may show a brief warning cue.
  Do not flash misleading empty warning during same-tick auto-reload unless
  Player Shooting exposes a real empty/fallback condition.
- **Patterns**: Weapon & Ammo Readout, Gameplay HUD Readout.

#### Boss Presence / Phase Pulse

- **Visual description**: Upper-center title flash or angular pulse frame using
  magenta/cyan/yellow accents. It communicates "boss pressure changed" rather
  than numeric health.
- **Data displayed**: Boss name/title or phase presence label only if approved by
  content; never HP, hit count, remaining hits, or `phase_hp_table`.
- **Update behavior**: Event-driven on boss activation, `boss_phase_advanced`, and
  `boss_killed`.
- **Patterns**: Boss Presence / Phase Pulse, Flash-Safe Fullscreen Feedback.

#### Death Committed Overlay

- **Visual description**: Brief center/full-screen tint or cut-in that confirms
  death has committed after no token recovery remains. It must not delay the
  sub-1-second restart promise.
- **Data displayed**: Optional short stable-key text only if needed; avoid turning
  death into a menu.
- **Update behavior**: Event-driven. HUD displays; Scene Manager owns restart.
- **Patterns**: Flash-Safe Fullscreen Feedback.

#### Victory Cue

- **Visual description**: Compact upper-center or center cut-in using collage
  headline style for boss/stage clear. It should feel like a photo/card snapping
  into place, not a long modal.
- **Data displayed**: `hud_victory_clear` string key and optional boss/stage label.
- **Update behavior**: Event-driven; HUD does not change scene or grant tokens.
- **Patterns**: Boss Presence / Phase Pulse, Flash-Safe Fullscreen Feedback.

---

## 5. HUD States by Gameplay Context

| Context | Elements Shown | Elements Hidden | Elements Modified | Transition Into This State |
|---|---|---|---|---|
| Active gameplay, no boss | REWIND Token Counter; Weapon & Ammo if equipped | Boss pulse, death/victory, first-death prompt | Token counter at full opacity; weapon readout secondary | Immediate on gameplay scene active. |
| DYING, first rewind opportunity | Token Counter, First-Death Rewind Prompt | Boss pulse unless already active and non-overlapping | Token counter may call out available token; prompt appears lower-center | Prompt appears within same DYING event, 12-frame fade. |
| Rewinding / protection | Token Counter | Prompt if first success already happened | Counter buffers delayed gain/count-changing animations | Rewind shader owns fullscreen effect; HUD remains readable. |
| Token denied / no token | Token Counter with denied pulse | First-death prompt after denial completes if appropriate | Spent tokens pulse with shape/timing cue | Immediate event pulse; avoid unsafe flashes. |
| Weapon equipped | Token Counter, Weapon & Ammo | None | Weapon readout appears lower-right | Cut-in or short glitch flicker; no smooth fade dependency. |
| Boss encounter active | Token Counter, Weapon & Ammo, Boss Presence / Phase Pulse on events | Boss HP / hit counts always hidden | Boss pulse uses upper-center event lane | Pulse on boss activation and phase events. |
| Death committed | Death overlay | Gameplay widgets may fade/cut out | Overlay confirms fail state without delaying restart | Immediate, then Scene Manager restart path. |
| Stage/boss clear | Token Counter if still in gameplay, Victory Cue | First-death prompt, boss pulse replaced by victory cue | Cue uses upper-center/center priority | Event cut-in; Scene Manager owns transition. |
| Pause/menu open | None from gameplay HUD | All gameplay HUD | Menu/Pause #18 owns visible UI and focus | Hide gameplay HUD as pause overlay opens. |

---

## 6. Information Hierarchy

| Element | Priority Tier | Reasoning | What Replaces It If Hidden |
|---|---|---|---|
| REWIND Token Counter | MUST KEEP during active gameplay | Token availability is the core recovery decision. | Nothing; if hidden by full-screen transition, gameplay control should not be active. |
| First-Death Rewind Prompt | MUST KEEP during first DYING teach moment | Without it, the signature mechanic may be missed. | None in Tier 1; environmental tutorials are intentionally absent. |
| Death Committed Overlay | MUST KEEP when death commits | Clarifies that no token recovery remains and restart is occurring. | Scene restart itself, but overlay should still communicate transition. |
| Boss Presence / Phase Pulse | SHOULD KEEP during boss events | Boss state changes require pressure readability without HP math. | Boss VFX/world-shell phase changes from VFX #14. |
| Weapon & Ammo Readout | SHOULD KEEP while weapon equipped | Supports shooting decisions but is secondary to survival tokens. | Weapon animation/audio can supplement, not fully replace. |
| Victory Cue | CAN HIDE if scene transition is obvious | Confirmation/polish, not survival-critical. | Stage clear transition. |

---

## 7. Visual Budget

| Budget Constraint | Limit | Measurement Method | Current Estimate | Status |
|---|---:|---|---:|---|
| Normal combat HUD draw calls | ≤20 | HUD element draw-call estimate in `design/gdd/hud.md` | TBD | To verify in prototype. |
| Transient boss/prompt/victory draw calls | ≤40 | Same estimate during peak transient event | TBD | To verify in prototype. |
| Maximum persistent active HUD groups | 2 | Token group + weapon/ammo group | 2 | In budget. |
| Maximum transient event groups | 2 | Prompt or boss/victory plus persistent widgets | 1–2 | In budget if not stacked. |
| Center screen persistent HUD occupancy | 0% | No persistent HUD in center play area | 0% | Design pass. |
| Critical text/icon glance readability | 0.2 seconds | Playtest/screenshot read test | TBD | Required before implementation sign-off. |
| HUD text/icon readability at Steam Deck scale | Pass | 1280×800 capture/manual test | TBD | Required evidence in `tests/evidence/`. |

---

## 8. Feedback & Notification Systems

| Notification Type | Trigger System | Screen Position | Duration / Timing | Animation In / Out | Max Simultaneous | Priority | Queue Behavior | Dismissible? |
|---|---|---|---|---|---:|---|---|---|
| Token Consumed | Time Rewind | Token Zone | Immediate; count updates before REWINDING | One contained cut/glitch pulse | 1 | Critical | Not queued | No |
| Token Replenished | Time Rewind / Boss Kill | Token Zone | Immediate unless during rewind protection | Cyan gain pulse after legal display time | 1 | High | Delay until `rewind_protection_ended` if needed | No |
| Cap Full | Time Rewind | Token Zone | Brief | Shape flash, no count animation | 1 | Medium | Not queued | No |
| Token Denied | SM / Time Rewind | Token Zone | Brief | Gray/magenta denied pulse + shape jitter | 1 | Critical | Not queued | No |
| First-Death Prompt | Input / SM | Prompt Zone | Until action, fade, or session latch | 12-frame fade | 1 | Critical teach | Not queued | No |
| Boss Phase Pulse | Boss Pattern / Damage | Boss Zone | Short event pulse | Cut-in / 1-frame glitch / cut-out | 1 | High | Replace prior boss pulse, do not stack | No |
| Victory Cue | Damage / Scene Manager | Boss or Center Zone | Short transition cue | Cut-in, then scene transition | 1 | Medium | Not queued | No |
| Death Committed | Damage / SM | Center / full screen | As short as restart flow allows | Static or single cut, no repeated flash | 1 | Critical | Not queued | No |

**Notification rules**

1. HUD event feedback is local to HUD widgets; no general toast queue exists in Tier 1.
2. Token feedback has priority over boss/victory feedback if both would animate the
   same frame.
3. Boss/victory pulses replace each other rather than stacking.
4. No notification may obscure the Token Zone or Prompt Zone during DYING.
5. All flash/glitch effects must respect ADR-0010 readability and photosensitivity
   constraints.

---

## 9. Platform Adaptation

| Platform | Safe Zone | Resolution Range | Input Method | HUD-Specific Notes |
|---|---|---|---|---|
| PC Steam reference | 3% margin | 1280×720 to 3840×2160 | Gamepad primary; KB+M parity | Scale by viewport; never stretch token icon proportions. |
| Steam Deck | 5% margin | 1280×800 target | Built-in gamepad controls | Validate token count, ammo, and prompt from handheld distance. |
| Ultrawide PC | 3% margin within gameplay viewport | 21:9 possible | Gamepad / KB+M | Anchor to safe viewport edges, not arbitrary art bounds. |

**Input display adaptation**

- Primary prompt glyph: gamepad profile (`[LT] Rewind` or equivalent).
- Keyboard/mouse fallback: `[Shift] Rewind` per Input GDD Tier 1 stub.
- HUD must accept device label updates from Input #1 when available; it must not
  inspect raw InputMap bindings.

---

## 10. Accessibility — HUD Specific

### 10.1 Basic Tier Commitments

| Requirement | HUD Rule |
|---|---|
| Minimum HUD readability | Token icons/text, ammo text, and prompt glyph/text must be readable at 1080p and Steam Deck 1280×800. |
| No color-only meaning | Token availability uses count/shape/text; boss pulse uses shape/timing/text; ammo uses number/icon. |
| Photosensitivity guard | No repeated strobe; glitch/cut effects are brief and must defer to ADR-0010 visibility limits. |
| Non-focusable gameplay display | HUD `Control` nodes must not grab keyboard/gamepad focus or consume gameplay input. |

### 10.2 Color-Only Risk Audit

| Element | Risk | Non-Color Backup |
|---|---|---|
| REWIND tokens | Cyan vs gray alone may fail | Filled vs outline icons, exact count text, consistent position. |
| Token denied | Magenta/red alone may fail | Denied pulse shape/timing and optional text/icon mark. |
| Boss pulse | Phase color alone may fail | Different pulse shape/timing and optional boss title/phase text. |
| Weapon fallback | Warning hue alone may fail | Icon swap plus short text key `hud_weapon_fallback`. |

### 10.3 Text Scaling and Readability

Tier 1 does not implement a full UI scaling option, but authored sizes must remain
readable at target resolutions.

| Element | 1080p Baseline | Steam Deck 1280×800 | Overflow Behavior |
|---|---|---|---|
| Token count numeric fallback | Pass target: ≥18px equivalent | Pass target: ≥16px equivalent | Switch to compact number if icons crowd. |
| First-death prompt | Glyph + text readable | Glyph + text readable | Short labels only; no multiline prompt. |
| Ammo count | ≥18px equivalent | ≥16px equivalent | Keep exact number; icon may shrink before text does. |
| Boss/victory text | Large display text | Readable short label | Truncate decorative copy; preserve semantic label. |

### 10.4 Motion / Flash Sensitivity

| Animation / Motion Element | Severity | Reduced-Motion Fallback |
|---|---|---|
| Token consume/gain pulse | Mild | Single static state change plus count update. |
| Denied pulse | Mild | Static denied outline for same duration. |
| Boss phase cut-in/glitch | Moderate | Static title/pulse card with no glitch flicker. |
| Death committed overlay | Moderate | Static tint/cut only; no repeated flash. |
| Rewind fullscreen shader | High owner risk | Governed by ADR-0010 and Shader #16, not HUD; HUD must remain readable. |

### 10.5 Localization Considerations

Tier 1 is English-first, but visible strings must use stable keys:

- `hud_prompt_rewind`
- `hud_victory_clear`
- `hud_weapon_fallback`
- `hud_token_denied`

Glyph/text combinations must leave room for longer future localized strings even
though full localization is deferred to Localization #22.

---

## 11. Tuning Knobs

| Parameter | Current Value | Range | Effect of Increase | Effect of Decrease | Player Adjustable? | Notes |
|---|---:|---|---|---|---|---|
| `token_icon_size_1080p` | 32px | 28–40px | Better readability, more screen use | Cleaner HUD, higher miss risk | No | Match art-bible token icon detail. |
| `token_icon_spacing_px` | 6px | 4–10px | Easier individual token read | More compact | No | Keep count readable at max 5. |
| `first_death_prompt_fade_frames` | 12 frames | 12 only Tier 1 | N/A | N/A | No | Locked by HUD GDD. |
| `hud_normal_draw_call_target` | 20 | 12–24 | More visual richness | More austere | No | Must stay under Art Bible budget. |
| `hud_peak_draw_call_target` | 40 | 24–40 | Allows transient effects | Safer performance | No | Peak only during prompt/boss/victory. |
| `weapon_readout_opacity` | 100% in combat | 60–100% | More readable | Less intrusive | Future | No Tier 1 settings UI. |
| `boss_pulse_duration_frames` | TBD | 12–60 | More readable | Less intrusive | No | Resolve in first boss prototype. |

---

## 12. Acceptance Criteria

**Layout & Visibility**

- [ ] All HUD elements remain within the safe zone at 1920×1080, 1280×720, and Steam Deck 1280×800.
- [ ] Token counter is readable in a 0.2-second glance at 1080p and Steam Deck scale.
- [ ] No persistent HUD element occupies the center play area.
- [ ] Token counter and first-death prompt never overlap each other.
- [ ] Normal combat HUD draw-call estimate remains `<= 20`; transient peak remains `<= 40`.

**Per-Context Correctness**

- [ ] Gameplay start initializes token counter from `TimeRewindController.get_remaining_tokens()` without mutating Time Rewind state.
- [ ] `token_consumed` updates the displayed token count and feedback without allocation when value/feedback is unchanged.
- [ ] Token reward during rewind protection delays count-changing display until `rewind_protection_ended`.
- [ ] First DYING before successful rewind shows a device-specific prompt from Input #1 `button_label`.
- [ ] First successful rewind suppresses future first-death prompts for the session.
- [ ] Weapon equipped displays icon and exact ammo `0..30`.
- [ ] Boss phase/kill events show only phase/presence/victory cues and never show HP, hit counters, remaining hits, or phase tables.
- [ ] HUD never changes scenes, grants tokens, mutates ammo, advances boss phase, plays raw audio buses, or moves camera.

**Accessibility**

- [ ] Critical token availability is communicated by icon count/shape and text/number, not color alone.
- [ ] Boss pulse communicates with shape/timing/text, not color alone.
- [ ] First-death prompt has readable glyph and text fallback if glyph art is missing.
- [ ] HUD text/icons remain readable at Steam Deck handheld scale.
- [ ] Reduced-motion/static fallback exists for token, boss, death, and victory animations.
- [ ] No gameplay HUD `Control` node can receive keyboard/gamepad focus or consume gameplay input.

**Verification / Evidence**

- [ ] Screenshot evidence captured for 1080p and Steam Deck target into `tests/evidence/`.
- [ ] Grep/static check confirms no production HUD references boss HP, remaining hits, `phase_hp_table`, or damage numbers.
- [ ] UX review confirms this spec remains aligned with `design/accessibility-requirements.md` Basic tier.

---

## 13. Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Exact boss pulse duration and title/phase copy style? | UX designer + game designer | First boss prototype | Pending; default 12–60 frames, no HP values. |
| Does Token Zone use icons only at max 5 or always include numeric fallback? | UX designer + QA | First HUD readability capture | Pending; default includes numeric fallback when icon count becomes ambiguous. |
| Exact keyboard/gamepad glyph art for Rewind? | Input designer + UI artist | HUD asset pass | Pending; text fallback is binding. |
| Does death committed overlay show text or only tint/cut? | UX designer + producer | First playable prototype | Pending; default is minimal non-blocking overlay. |
| Should victory cue appear center or upper-center for boss kill? | UX designer + art director | First boss prototype | Pending; must not hide Token Zone during token reward animation. |

