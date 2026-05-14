# HUD System

> **Status**: Approved
> **Author**: user + game-designer + ux-designer + ui-programmer
> **Created**: 2026-05-13
> **Last Updated**: 2026-05-14 — Menu/Pause #18 approval mirror
> **Implements Pillar**: Pillar 1 (Time Rewind as learning tool) through always-readable token state; Pillar 2 (Deterministic Patterns) through exact, non-random information; Pillar 4 (5-Minute Rule) through glanceable survival UI; Pillar 5 (Small Success) through a minimal Tier 1 HUD only
> **Engine**: Godot 4.6 / GDScript / 2D / `CanvasLayer` + `Control`
> **System #**: 13 (Presentation / UI)

---

## A. Overview

HUD System #13 owns the player-facing combat information layer for Tier 1: REWIND token count, weapon/ammo readout, first-death rewind prompt, boss phase/presence pulse, and minimal death/victory presentation hooks. It does **not** own menus, pause/options, input remapping, localization infrastructure, token mutation, ammo mutation, boss hit accounting, camera movement, or audio routing. Its central promise is: the player can read the next survival decision in under a glance without turning Echo into a stat-bar game.

Tier 1 HUD is screen-anchored. It renders above gameplay in a `CanvasLayer`, uses non-focusable `Control` nodes, and never changes simulation state. Time Rewind #9, Player Shooting #7, Input #1, Damage #8, Boss Pattern #11, Scene Manager #2, Camera #3, and Audio #4 remain the authoritative owners of their own data and signals. HUD subscribes, caches, and presents.

---

## B. Player Fantasy

The player should feel: **"I always know whether I can steal one more chance."**

Echo is one-hit-kill. The HUD should not make the player feel like they are managing health, cooldown spreadsheets, or boss math. It should act like a sharp instrument panel: tokens are immediately legible, ammo is visible but secondary, the first-death prompt teaches the one critical recovery action, and boss state is communicated as pressure and escalation rather than as a health bar.

### B.1 Player-Facing Promises

| Promise | Player Feeling | Design Meaning |
|---|---|---|
| **Token clarity first** | "I know if rewind is available." | REWIND tokens are the highest-priority persistent HUD element. |
| **No hidden resource ambiguity** | "A full token cap still tells me I earned something." | Boss reward at cap produces distinct cap-full feedback even when the displayed count is unchanged. |
| **Ammo as support, not anxiety** | "I can check my weapon without staring at the corner." | Ammo/weapon readout is small, exact, and secondary to tokens. |
| **Boss escalation over boss bookkeeping** | "The boss changed phase; I should read the pattern." | Boss UI may pulse phase/presence, but never exposes HP bars, hit counters, or remaining hits. |
| **Prompt, not tutorial modal** | "The game reminded me at the exact failure moment." | First-death rewind hint is brief, button-specific, and suppressed after first successful rewind in the session. |

### B.2 Anti-Fantasy

HUD must never create these feelings:

- **"I am playing the HUD, not the level."** Persistent UI stays minimal and screen-space; gameplay reads still come from enemy, boss, stage, audio, and VFX telegraphs.
- **"The boss is a health-bar race."** No boss HP bar, phase hit count, remaining hit count, or `phase_hp_table` value appears in production UI.
- **"The prompt stole control."** No modal tutorial, pause gate, or focus capture for the first-death hint.
- **"A UI bug changed my resources."** HUD never mutates tokens, ammo, phase state, or scene state.
- **"Gamepad navigation broke during gameplay."** HUD owns no focusable gameplay controls in Tier 1.

---

## C. Detailed Rules

### C.1 Core Rules

**Rule 1 — HUD is presentation-only.**

HUD subscribes to gameplay signals and reads approved public values. It must not call token grant/consume methods, write `WeaponSlot.ammo_count`, advance boss phases, change scenes, move camera, or play audio through raw bus access. HUD may request/emit HUD-local presentation events only, such as "token flash finished" or "prompt visibility changed", if implementation needs them.

**Rule 2 — REWIND token counter is the primary persistent element.**

The token counter is fixed in the upper-left safe area. It displays the current logical token count from Time Rewind #9, clamped to `0..max_tokens`, or `∞` if a future debug/accessibility mode marks tokens infinite. Tier 1 default values come from the registry:

- `starting_tokens = 3`;
- `max_tokens = 5`;
- `REWIND_SIGNATURE_FRAMES = 30`.

HUD initializes from `TimeRewindController.get_remaining_tokens()` and updates from:

- `token_consumed(remaining_tokens: int)`;
- `token_replenished(new_total: int)`;
- `rewind_protection_ended(player: Node2D)`.

**Rule 3 — token visuals distinguish four outcomes.**

HUD must visually distinguish:

1. **Consume**: count decreases; active token icon pops out or drains.
2. **Gain**: count increases; new token icon fills in with Neon Cyan pulse.
3. **Cap full**: `token_replenished` fires but the displayed count does not increase because `_tokens == max_tokens`; show a distinct cap-full pulse before or during the reward feedback.
4. **Denied**: rewind was attempted with no available token or invalid state; show a short denied pulse on the token counter and rely on Audio #4 for denied SFX.

The cap-full case is mandatory because Time Rewind #9 intentionally emits `token_replenished(new_total)` even when clamped at max.

**Rule 4 — token display can lag logical token state during rewind protection only.**

HUD maintains:

- `_logical_tokens`: latest value received from Time Rewind #9;
- `_displayed_tokens`: value currently drawn.

If `boss_killed` grants a token while Time Rewind #9 is in `REWINDING` or rewind protection, HUD caches `_logical_tokens` immediately but delays the count-changing animation until `rewind_protection_ended(player)` after `REWIND_SIGNATURE_FRAMES = 30`. Outside this specific case, the displayed count updates on the same frame the signal is handled.

**Rule 5 — no per-signal allocation in token update.**

HUD token update must diff `_displayed_tokens` against the incoming value before starting feedback. If the value and feedback kind are unchanged, it performs no new animation allocation. This preserves Time Rewind #9's requirement that HUD update is allocation-stable under repeated events.

**Rule 6 — first-death rewind prompt is owned by HUD, triggered by Input/System state.**

HUD subscribes to the first-death hint flow defined by Input #1 and Echo lifecycle:

- `first_death_in_session(profile)`;
- `first_rewind_success_in_session(profile)`;
- `scene_will_change`.

On every DYING entry before first successful rewind in the current session, HUD displays a one-token prompt such as `[Shift] Rewind` or `[LT] Rewind`. The button label comes from Input #1's `button_label(profile, action)` API. HUD must not inspect raw `Input.get_action_*()` mappings directly.

Prompt behavior:

- fade in/out over 12 frames;
- never pauses gameplay;
- never captures keyboard/gamepad focus;
- suppressed after `_first_rewind_success_latched == true`;
- latch resets on `scene_will_change`.

**Rule 7 — weapon/ammo readout is exact but secondary.**

HUD displays the current weapon icon and ammo count in the lower-right safe area. It consumes:

- `weapon_equipped(weapon_id: int)`;
- `weapon_fallback_activated(requested_id: int)`;
- `WeaponSlot.ammo_count` read access;
- weapon data from Player Shooting #7 / `weapons.tres`, including `MAGAZINE_SIZE = 30`.

Tier 1 does **not** require Player Shooting #7 to add a new `ammo_changed` signal. HUD may diff-read `WeaponSlot.ammo_count` once per physics tick or once per rendered frame, provided it does not allocate on unchanged values.

**Rule 8 — ammo display must tolerate instant auto-reload.**

Player Shooting #7 auto-reloads on the same tick when Tier 1 magazine reaches empty. HUD may briefly see `0` if implementation exposes the value during the tick, but production presentation should not flash a misleading "empty" warning unless Player Shooting #7 also triggers `play_ammo_empty` / fallback behavior. Normal Tier 1 ammo display should show exact count `0..30` and settle after auto-reload.

**Rule 9 — boss UI shows presence and phase pulse only.**

HUD may consume:

- `boss_phase_advanced(boss_id: StringName, new_phase: int)`;
- `boss_killed(boss_id: StringName)`.

HUD must **not** consume `boss_hit_absorbed`, `hits_remaining`, boss internal hit tables, or any `phase_hp_table` value for display. Tier 1 boss UI is limited to:

- a brief boss title/presence flash when the encounter arms;
- a phase-change pulse or frame tint when `boss_phase_advanced` fires;
- a victory/clear cue when `boss_killed` fires.

No HP bar, segmented boss bar, damage number, hit counter, or remaining-hit readout is allowed.

**Rule 10 — HUD is screen-anchored; world-anchored combat UI is out of scope for Tier 1.**

HUD lives in a `CanvasLayer` and uses viewport/safe-area placement. It does not need a Camera #3 signal, does not require a Camera node reference in Tier 1, and should not read `camera.global_position` for core HUD placement. If a future feature needs world-anchored labels above entities, that becomes VFX #14 or a Tier 2 HUD expansion requiring review.

**Rule 11 — HUD Controls do not take gameplay focus.**

Godot 4.6 has separate mouse/touch and keyboard/gamepad focus behavior. During gameplay, all HUD `Control` nodes must be non-interactive:

- `mouse_filter = MOUSE_FILTER_IGNORE` unless the node is a future menu overlay;
- no `focus_mode` on gameplay HUD controls;
- no `_gui_input` path that consumes gameplay actions.

Menu / Pause #18 (Approved 2026-05-14) owns navigable UI controls, focus testing, pause/options surfaces, and future input-remapping presentation. Title-shell/return-to-title routing is deferred outside Tier 1.

**Rule 12 — death and victory presentation remain minimal.**

HUD may show:

- a brief death-state overlay or prompt during DYING;
- a minimal victory/clear text beat after `boss_killed`.

Scene Manager #2 owns scene changes and restart/clear ordering. Menu / Pause #18 owns full menus. Story Intro #17 owns narrative text. HUD must not become a general overlay framework in Tier 1.

**Rule 13 — HUD uses Art Bible UI colors and avoids gameplay obstruction.**

HUD uses Art Bible UI direction:

- semi-transparent Concrete Dark panels for readability;
- Neon Cyan for available tokens and positive resource pulses;
- Ad Magenta for danger, denied feedback, and inactive resource warning;
- no pure white except death flash;
- no collage-photo texture inside small HUD icons;
- sharp cut/pulse transitions, except the first-death prompt's required 12-frame fade.

**Rule 14 — HUD has a hard UI draw-call budget.**

HUD must fit inside the Art Bible UI/HUD allocation of 40 draw calls. Tier 1 target is lower: `hud_draw_call_estimate <= 20` during normal combat and `<= 40` during brief boss/first-death/victory pulses.

### C.2 HUD State Model

HUD is not a gameplay state machine, but it has presentation state.

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `BOOTSTRAP` | HUD scene instanced | Initial token/weapon reads complete | Hide transient UI; initialize cached values from owners. |
| `COMBAT_NORMAL` | Scene active, player not dying/rewinding | Death, rewind, boss phase, scene change | Show token + weapon/ammo; listen for resource events. |
| `REWIND_PRESENTING` | `rewind_started` or token delay branch | `rewind_protection_ended` handled | Freeze/delay any count-changing reward animation that happened inside rewind protection. |
| `FIRST_DEATH_PROMPT` | `first_death_in_session(profile)` while latch false | 12-frame fade out or rewind success | Show one-token button prompt; do not pause/focus. |
| `BOSS_PRESENTING` | Boss encounter active or phase signal received | `boss_killed` or scene change | Show phase pulse/title flash only; no hit accounting. |
| `DEATH_OVERLAY` | Damage/Echo lifecycle commits death | Rewind success or scene reload | Optional brief overlay/prompt; Scene Manager owns restart timing. |
| `VICTORY_OVERLAY` | `boss_killed` handled | Scene Manager transition | Optional minimal clear text/cue. |

### C.3 Signal and Data Contracts

| Source System | HUD Consumes | Purpose | HUD Must Not Do |
|---|---|---|---|
| Time Rewind #9 | `get_remaining_tokens()`, `token_consumed`, `token_replenished`, `rewind_protection_ended` | Token count, delayed reward display, cap-full feedback | Mutate tokens; call `grant_token`; infer state from private fields. |
| Input #1 | `button_label(profile, action)` via first-death prompt flow | Correct keyboard/gamepad glyph text | Query raw action bindings directly; own remapping UI. |
| Echo lifecycle / State Machine #5 | `first_death_in_session`, `first_rewind_success_in_session` | Prompt latch and suppression | Own lifecycle transitions. |
| Player Shooting #7 | `weapon_equipped`, `weapon_fallback_activated`, `WeaponSlot.ammo_count`, weapon icon data | Weapon icon and ammo readout | Own ammo, reload, projectile, or fallback logic. |
| Boss Pattern #11 / Damage #8 | `boss_phase_advanced`, `boss_killed` | Boss phase pulse and victory cue | Display HP/hits; consume `boss_hit_absorbed`; expose phase thresholds. |
| Scene Manager #2 | `scene_will_change` | Reset prompt latch and clear transient overlays | Change scenes or decide restart/clear priority. |
| Audio #4 | Optional HUD feedback request events, if implemented | Let Audio own SFX presentation | Play raw audio buses directly. |
| Camera #3 | Viewport/safe-area primitives only if needed | Screen-space anchoring validation | Request new camera signals for Tier 1 HUD. |

### C.4 Layout Specification

| Element | Placement | Persistence | Priority | Notes |
|---|---|---|---:|---|
| REWIND token counter | Upper-left safe area | Always during gameplay | 1 | Largest HUD element. Uses icons + numeric fallback if icon count becomes unreadable. |
| Weapon icon | Lower-right safe area | Always while weapon equipped | 2 | Small silhouette/line icon; updates on `weapon_equipped`. |
| Ammo counter | Adjacent to weapon icon | Always while weapon equipped | 3 | Exact integer, subdued until low/empty/fallback. |
| First-death rewind prompt | Near lower center or token counter callout | Transient | 1 during DYING | One action label only; 12-frame fade. |
| Boss phase pulse/title flash | Upper center or boss-safe frame | Transient | 2 during boss | Phase/presence only; no HP/hit data. |
| Death overlay | Center or full-screen tint | Transient | 1 during committed death | No menu; does not own restart. |
| Victory cue | Center or upper center | Transient | 1 after boss kill | Minimal Tier 1 clear confirmation. |

### C.5 Tier Boundaries

| Feature | Tier 1 Decision | Deferred Version |
|---|---|---|
| Health UI | Not present; one-hit-kill only | Only if future mode changes health model. |
| Boss HP bar | Forbidden | Requires explicit Boss/Damage/HUD redesign. |
| Menu/pause/options | Out of HUD scope | Menu / Pause #18. |
| Localization | English/Korean-ready text keys where practical, but no full localization pipeline | Localization #22 Tier 3. |
| Accessibility options | HUD should avoid relying on color alone, but options UI deferred | Accessibility #24 Tier 3. |
| World-anchored labels | Out of Tier 1 HUD | VFX #14 or Tier 2 HUD review. |
| Ammo changed signal | Not required | May be added if profiling shows polling/diff-read is wasteful. |

---

## D. Formulas

### D.1 Token Display Value

The `token_display_value` formula is defined as:

`token_display_value = "∞" if infinite_tokens_enabled else clamp(_logical_tokens, 0, max_tokens)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `_logical_tokens` | `T` | int | `-∞..∞` input, expected `0..max_tokens` | Latest token count received from Time Rewind #9. |
| `max_tokens` | `M` | int | `0..5` Tier 1 modes; default `5` | Registry-owned token cap. |
| `infinite_tokens_enabled` | `I` | bool | `false..true` | Future debug/accessibility flag; false in production Tier 1. |

**Output Range:** `0..max_tokens` or `∞`.
**Example:** `_logical_tokens = 6`, `max_tokens = 5`, `infinite_tokens_enabled = false` → `token_display_value = 5`.

### D.2 Token Feedback Kind

The `token_feedback_kind` formula is defined as:

`token_feedback_kind = consume if new_total < old_displayed; gain if new_total > old_displayed; cap_full if event == token_replenished and new_total == old_displayed == max_tokens; no_op otherwise`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `old_displayed` | `D0` | int | `0..max_tokens` | Value currently drawn before handling event. |
| `new_total` | `T1` | int | `0..max_tokens` | Incoming token value after Time Rewind clamp. |
| `max_tokens` | `M` | int | `0..5` Tier 1 modes; default `5` | Registry-owned token cap. |
| `event` | `E` | enum | `token_consumed`, `token_replenished`, `manual_refresh` | Source of the update. |

**Output Range:** one of `consume`, `gain`, `cap_full`, `no_op`.
**Example:** `old_displayed = 5`, `new_total = 5`, `max_tokens = 5`, `event = token_replenished` → `cap_full`.

### D.3 Ammo Display Ratio

The `ammo_display_ratio` formula is defined as:

`ammo_display_ratio = clamp(ammo_count, 0, magazine_size) / max(1, magazine_size)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `ammo_count` | `A` | int | `0..MAGAZINE_SIZE` expected | Current ammo count read from `WeaponSlot.ammo_count`. |
| `magazine_size` | `C` | int | `10..60` tuning range; default `30` | Player Shooting #7 weapon data / registry constant. |

**Output Range:** `0.0..1.0`.
**Example:** `ammo_count = 12`, `magazine_size = 30` → `ammo_display_ratio = 0.4`.

### D.4 HUD Safe Anchor

The `hud_safe_anchor` formula is defined as:

`hud_safe_anchor = viewport_edge + round(base_margin_1080p * viewport_height / 1080) + platform_safe_area_offset`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `viewport_edge` | `E` | Vector2 | screen bounds | Target edge/corner anchor. |
| `base_margin_1080p` | `B` | int | `16..32 px`; default `24 px` | Design margin at 1080p. |
| `viewport_height` | `H` | int | `540..2160+ px` | Current viewport height. |
| `platform_safe_area_offset` | `S` | Vector2 | `0..128 px` typical | Platform-specific safe-area inset if available. |

**Output Range:** inside the visible viewport, at least scaled margin from edge.
**Example:** 1080p, upper-left, `B = 24`, `S = (0,0)` → anchor offset `(24,24)`.

### D.5 HUD Draw Call Estimate

The `hud_draw_call_estimate` formula is defined as:

`hud_draw_call_estimate = token_icon_draws + weapon_icon_draws + ammo_text_draws + boss_phase_draws + prompt_draws + panel_draws`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---:|---|---|---|
| `token_icon_draws` | `Ti` | int | `0..8` | Token icons/backgrounds after atlas batching. |
| `weapon_icon_draws` | `Wi` | int | `0..2` | Weapon icon and backing panel. |
| `ammo_text_draws` | `At` | int | `0..4` | Ammo font/material draws. |
| `boss_phase_draws` | `Bp` | int | `0..6` | Transient phase/title pulse. |
| `prompt_draws` | `Pr` | int | `0..6` | First-death prompt text/glyph panel. |
| `panel_draws` | `Pn` | int | `0..6` | Shared HUD panels/frames. |

**Output Range:** `0..20` target during normal combat; must remain `<= 40` under transient peak.
**Example:** `Ti=6`, `Wi=1`, `At=2`, `Bp=0`, `Pr=0`, `Pn=3` → `hud_draw_call_estimate = 12`.

---

## E. Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Token reward occurs while rewinding | Cache `_logical_tokens`; delay count-changing display until `rewind_protection_ended`. | Time Rewind #9 owns protection timing; HUD avoids contradictory feedback during rewind signature. |
| `token_replenished(5)` fires while already displaying 5 | Show cap-full pulse, not gain; leave count at 5. | Clamped reward still matters to the player. |
| Token consume and boss grant produce the same final count in one tick | Resolve by event order received; if final displayed value is unchanged, show the highest-priority feedback: consume/death survival first, then cap/gain pulse if still relevant. | Prevents hidden state changes while preserving survival readability. |
| `max_tokens = 0` in a future hard mode | Display zero/disabled token UI and use denied feedback; do not divide by zero. | Difficulty Toggle #20 may set zero-token modes later. |
| Infinite-token debug flag is true | Display `∞`; still show rewind feedback pulses when events fire. | Useful for debug/accessibility without changing production default. |
| First death occurs with keyboard then controller is used before prompt ends | Prompt may update label on the next profile/device update if Input #1 exposes one; otherwise keep the label from the triggering profile until the next DYING entry. | HUD does not own device detection. |
| First-death prompt appears, then scene changes | Immediately clear prompt and reset `_first_rewind_success_latched`. | Scene Manager #2 scene boundary resets session-local prompt presentation. |
| First successful rewind happens while prompt is fading | Finish or cut the fade safely, set latch true, and suppress future first-death prompts for the session. | Input #1 owns the success signal; HUD owns suppression. |
| Ammo auto-reload hides zero state | Show the stable post-reload value unless Player Shooting #7 exposes an explicit empty/fallback cue. | Tier 1 reload is instant; a false empty flash would be noisy. |
| Invalid weapon id or fallback activation | Keep previous valid icon if safe; show brief fallback indicator; never crash or display missing texture checker in production. | Player Shooting #7 owns fallback logic; HUD presents it. |
| Boss phase signal repeats with same phase | Ignore duplicate phase pulse unless `boss_id` changed. | Prevents double-pulsing from signal replay or scene reload bugs. |
| Boss killed and player death occur same physics tick | Show token/death/victory cues according to Scene Manager/Time Rewind final state; do not decide stage clear priority locally. | Scene Manager #2 and Time Rewind #9 own same-tick ordering. |
| Viewport resizes during gameplay | Recompute safe anchors on resize; no gameplay state changes. | Steam Deck/windowed PC support. |
| HUD Control receives mouse/gamepad focus accidentally | Treat as a bug; gameplay HUD controls must ignore focus/input. | Godot 4.6 dual-focus behavior can otherwise steal input. |
| Font or glyph missing | Fall back to approved UI font and text label; do not show tofu boxes in Tier 1-critical prompts. | Prompt readability is gameplay-critical. |

---

## F. Dependencies

### F.1 Upstream Dependencies

| System | Status | HUD Dependency | Contract Strength |
|---|---|---|---|
| Time Rewind #9 | Approved | Token counts, cap behavior, rewind protection signal, denied/consume/replenish timing. | HARD |
| Player Shooting #7 | Approved | Weapon equipped/fallback signals, `WeaponSlot.ammo_count`, `MAGAZINE_SIZE = 30`, icon data. | HARD |
| Boss Pattern #11 | Approved 2026-05-13 | Boss phase and kill signals; no HP/hit UI exposure. | HARD |
| Damage #8 | LOCKED for prototype | Boss/Damage signal signatures and death committed semantics. | HARD |
| Input #1 | Approved | `button_label(profile, action)` and first-death prompt profile contract. | HARD |
| State Machine #5 | Approved | Echo lifecycle prompt hooks and DYING/recover flow. | HARD |
| Scene Manager #2 | Approved | `scene_will_change` reset; death/victory scene ownership. | HARD |
| Camera #3 | Approved | Screen-space vs world-space boundary; no new Tier 1 camera signal. | SOFT |
| Audio #4 | Approved | Denied/resource/boss UI SFX ownership if HUD requests cues. | SOFT |
| Art Bible | Draft / living | Colors, typography, HUD draw-call target, no traditional health UI. | HARD |
| Godot 4.6 UI docs | Verified 2026-05-08 | `CanvasLayer`, `Control`, focus, accessibility, localization constraints. | HARD |

### F.2 Downstream Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| Localization #22 | Depends on HUD later | Will provide localized strings/glyph labels for prompt and victory text in Tier 3. |
| Accessibility #24 | Depends on HUD later | Will audit HUD contrast, non-color cues, text scaling, and remapping presentation. |
| [Menu / Pause #18](menu-pause.md) | Adjacent owner · Approved 2026-05-14 | Owns focusable menu controls and pause/options surfaces; title-shell/return-to-title routing is deferred and HUD must remain non-focusable combat presentation. |
| VFX #14 | Adjacent owner | May own world-anchored or shader-heavy feedback that HUD deliberately excludes. |

### F.3 Explicit Non-Dependencies

- HUD does not depend on internal boss `phase_hp_table`.
- HUD does not depend on Camera #3 `global_position` for core Tier 1 layout.
- HUD does not depend on raw input map queries.
- HUD does not depend on direct AudioServer bus calls.

---

## G. Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---:|---|---|---|
| `hud_base_margin_1080p` | `24 px` | `16..32 px` | More safe-area comfort, less screen space | Tighter arcade feel, higher cutoff risk |
| `token_pulse_frames` | `12 frames` | `6..24` | More readable feedback | Snappier, easier to miss |
| `cap_full_pulse_frames` | `18 frames` | `12..30` | Clearer capped reward | Less visible cap-full distinction |
| `denied_pulse_frames` | `10 frames` | `6..18` | Stronger denied read | Less noisy under repeat attempts |
| `first_death_prompt_fade_frames` | `12 frames` | `12 only Tier 1` | Not tunable without Input #1 review | Not tunable without Input #1 review |
| `boss_phase_pulse_frames` | `24 frames` | `12..45` | Stronger phase emphasis | Less distraction from boss telegraph |
| `ammo_low_threshold_ratio` | `0.2` | `0.1..0.35` | Earlier ammo warning | Later, less noisy warning |
| `hud_normal_draw_call_target` | `20` | `12..24` | More visual richness | More austere HUD |
| `hud_peak_draw_call_limit` | `40` | `40 max` | Not allowed beyond Art Bible budget | More headroom for VFX/collage |
| `prompt_vertical_offset_1080p` | `120 px` from bottom center | `80..180 px` | Further from player action | More likely to overlap danger reads |

---

## H. Acceptance Criteria

- [ ] **AC-HUD-1**: Given gameplay starts, when HUD initializes, then the upper-left token counter displays `TimeRewindController.get_remaining_tokens()` without mutating Time Rewind state.
- [ ] **AC-HUD-2**: Given `token_consumed(remaining_tokens)` fires, when `remaining_tokens < _displayed_tokens`, then HUD shows consume feedback and updates the count without allocating a new animation if the displayed value is unchanged.
- [ ] **AC-HUD-3**: Given `token_replenished(5)` fires while `_displayed_tokens == max_tokens == 5`, then HUD shows cap-full feedback and does not show a gain count animation.
- [ ] **AC-HUD-4**: Given a token reward occurs during rewind protection, when `rewind_protection_ended(player)` fires after `REWIND_SIGNATURE_FRAMES = 30`, then HUD applies the delayed count-changing animation.
- [ ] **AC-HUD-5**: Given the player first enters DYING before a successful rewind, then HUD shows one button-specific rewind prompt from Input #1 `button_label(profile, action)` with a 12-frame fade and no focus capture.
- [ ] **AC-HUD-6**: Given `first_rewind_success_in_session(profile)` fires, then HUD latches prompt suppression until `scene_will_change`.
- [ ] **AC-HUD-7**: Given `weapon_equipped(weapon_id)` fires, then HUD updates the weapon icon and begins displaying the current `WeaponSlot.ammo_count`.
- [ ] **AC-HUD-8**: Given Tier 1 magazine size is `MAGAZINE_SIZE = 30`, then HUD displays ammo in the exact range `0..30` and computes `ammo_display_ratio` without divide-by-zero.
- [ ] **AC-HUD-9**: Given `boss_phase_advanced(boss_id, new_phase)` fires, then HUD shows only a phase/presence pulse and never shows boss HP, remaining hits, phase thresholds, or damage numbers.
- [ ] **AC-HUD-10**: Given `boss_killed(boss_id)` fires, then HUD may show minimal victory cue but does not change scene or grant tokens.
- [ ] **AC-HUD-11**: Given gameplay is active, then no HUD `Control` node can receive keyboard/gamepad focus or consume gameplay input.
- [ ] **AC-HUD-12**: Given a viewport resize or Steam Deck resolution target, then HUD safe anchors remain inside visible bounds with scaled margins.
- [ ] **AC-HUD-13**: Given normal combat, then HUD draw-call estimate remains `<= 20`; given transient boss/prompt/victory feedback, it remains `<= 40`.
- [ ] **AC-HUD-14**: Given production text/glyph assets are missing, then HUD falls back to readable approved font/text and does not show missing texture checker or tofu boxes for critical prompts.
- [ ] **AC-HUD-15**: Review grep for boss UI confirms production HUD has no boss HP bar, hit counter, remaining hit count, or `phase_hp_table` exposure.

---

## I. Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|---|---|---|---:|
| Token available at start | Neon Cyan active token icons/count | None or subtle boot tick | 1 |
| Token consumed | Token icon drains/pops out; short cyan-to-dark pulse | Audio #4 rewind consume/activation path | 1 |
| Token gained | New token fills/pulses cyan | Audio #4 reward tick if implemented | 1 |
| Token cap full | Token row flashes cyan + magenta rim or alternate pulse | Audio #4 distinct cap-full tick if implemented | 1 |
| Rewind denied | Token counter shakes/pulses Ad Magenta | Audio #4 denied cue | 1 |
| First-death prompt | Small dark panel + action glyph/text; 12-frame fade | Optional low-priority prompt tick | 1 |
| Weapon equipped | Lower-right icon swaps with small cut pulse | Optional equip tick | 2 |
| Ammo low | Ammo text/icon tint shifts toward Ad Magenta | Optional low-ammo cue if not noisy | 3 |
| Weapon fallback | Brief fallback icon/rim pulse | Player Shooting/Audio fallback cue | 2 |
| Boss phase advanced | Upper/center phase pulse or boss frame flash; no bar | Boss Pattern/Audio phase cue | 2 |
| Boss killed | Minimal clear/victory cue | Audio #4 boss kill / stage clear cue | 1 |
| Death committed | Brief dark/death overlay; no menu | Damage/Audio death cue | 1 |

---

## J. UI Requirements

| Information | Display Location | Update Frequency | Condition |
|---|---|---|---|
| REWIND token count | Upper-left safe area | On token signal + initialization | Gameplay scene active |
| Token feedback kind | Token counter itself | Event-driven | Consume/gain/cap-full/denied |
| First-death rewind prompt | Lower-center or token callout | Event-driven; 12-frame fade | DYING before first successful rewind in session |
| Weapon icon | Lower-right safe area | On `weapon_equipped` / fallback | Weapon equipped |
| Ammo count | Adjacent to weapon icon | Diff-read each physics/render tick or event-driven if future signal exists | Weapon equipped |
| Boss phase/presence pulse | Upper center or boss-safe frame | On boss phase/kill events | Boss active |
| Death overlay | Center/full-screen tint | Event-driven | Death committed |
| Victory cue | Center/upper center | Event-driven | Boss killed / stage clear flow |

### J.1 Accessibility Baseline

- Critical token availability must be readable by icon count and text/number, not color alone.
- First-death prompt text must use approved high-legibility font and preserve a text fallback when glyph art is missing.
- Ad Magenta/Cyan pulses should be accompanied by shape, motion, or SFX differentiation where possible.
- HUD text should remain legible at Steam Deck handheld scale.

### J.2 Localization Baseline

Tier 1 may ship English-first, but HUD strings must be isolated as keys where practical:

- `hud_prompt_rewind`;
- `hud_victory_clear`;
- `hud_weapon_fallback`;
- `hud_token_denied`.

Localization #22 owns full translation, pluralization, and font fallback before Tier 3.

---

## K. Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| Token counter and reward display | `design/gdd/time-rewind.md` | `token_consumed`, `token_replenished`, `rewind_protection_ended`, `starting_tokens`, `max_tokens`, `REWIND_SIGNATURE_FRAMES` | Data dependency |
| First-death prompt | `design/gdd/input.md` | `first_death_in_session`, `first_rewind_success_in_session`, `button_label(profile, action)` | State trigger / API dependency |
| Ammo and weapon display | `design/gdd/player-shooting.md` | `weapon_equipped`, `weapon_fallback_activated`, `WeaponSlot.ammo_count`, `MAGAZINE_SIZE` | Data dependency |
| Boss phase-only UI | `design/gdd/boss-pattern.md` | `boss_phase_advanced`, `boss_killed`, no HP/hit UI rule | Rule dependency |
| Boss signal signatures | `design/gdd/damage.md` | Boss signal ownership and `death_committed` consumer | Rule dependency |
| Scene reset | `design/gdd/scene-manager.md` | `scene_will_change`, death/victory scene ownership | State trigger |
| Screen anchoring | `design/gdd/camera.md` | HUD is screen-space and does not require camera signal | Ownership boundary |
| Visual style | `design/art/art-bible.md` | UI/HUD colors, typography, draw-call allocation | Visual dependency |

---

## L. Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Exact HUD wireframe positions for token/ammo/prompt on 16:9 vs Steam Deck | ux-designer | Before UX spec for HUD | Recommend `/ux-design design/gdd/hud.md` after design-review approval. |
| Final icon/glyph asset source for keyboard/gamepad prompts | ui-designer + technical-artist | Before asset-spec pass | Use text fallback until glyph atlas is approved. |
| Whether boss phase pulse is upper-center title flash or boss-frame tint | game-designer + ux-designer | Before implementation | Either is allowed; no HP/hit data in either version. |
| Exact SFX split for gain vs cap-full vs denied | audio-director | Audio implementation pass | HUD defines events; Audio #4 owns sound assets. |
| Whether ammo polling moves from diff-read to `ammo_changed` signal | ai-programmer + ui-programmer | After first profiling pass | Tier 1 default is diff-read; add signal only if useful. |
