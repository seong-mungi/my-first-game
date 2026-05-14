# Accessibility Requirements: Echo

> **Status**: Committed for Tier 1 MVP baseline
> **Author**: Codex UX/Producer adapter
> **Last Updated**: 2026-05-14
> **Accessibility Tier Target**: Basic
> **Platform(s)**: PC Steam, Steam Deck-friendly
> **External Standards Targeted**:
> - WCAG 2.1 Level A principles for readable UI text and non-color-only communication where applicable to game UI
> - AbleGamers CVAA Guidelines: considered for motor, cognitive, visual, and auditory barriers
> - Xbox Accessibility Guidelines (XAG): No — not a target platform for Tier 1
> - PlayStation Accessibility: No — not a target platform for Tier 1
> - Apple / Google Accessibility Guidelines: N/A — mobile is not a target platform
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `.claude/docs/technical-preferences.md`, `docs/architecture/adr-0006-save-and-settings-persistence-boundary.md`, `docs/architecture/adr-0007-input-polling-pause-handling-and-ui-focus-boundary.md`, `design/gdd/input.md`, `design/gdd/hud.md`, `design/gdd/menu-pause.md`, `design/gdd/story-intro-text.md`

---

## Purpose

This document commits Echo's project-wide accessibility baseline before Pre-Production. Per-screen details belong in UX specs; this file defines the baseline tier, feature commitments, known intentional limitations, and validation obligations that UX specs and implementation stories must respect.

Echo is a solo-developed, fast 2D run-and-gun built around one-hit death and a single rewind token. Tier 1 intentionally avoids a full settings stack, input remapping system, localization system, and advanced accessibility options until later systems (#23 Input Remapping and #24 Accessibility Options). The Basic tier below preserves a realistic solo MVP scope while preventing avoidable exclusion from unreadable text, color-only signals, uncontrolled flashes, and missing audio volume separation.

---

## Accessibility Tier Definition

| Tier | Core Commitment | Echo Status |
|---|---|---|
| Basic | Critical player-facing text is readable at target resolutions; no feature requires color discrimination alone; independent music/SFX/UI volume controls exist; photosensitivity risk is controlled. | **Committed for Tier 1** |
| Standard | Basic plus full input remapping, subtitle support with speaker identification, adjustable text size, colorblind modes, and timed-input adjustments. | Deferred to Tier 2/3 unless a UX review elevates a feature. |
| Comprehensive | Standard plus screen reader menu support, mono audio, difficulty assists, HUD repositioning, reduced motion, and visual indicators for all gameplay-critical audio. | Deferred to future accessibility system #24. |
| Exemplary | Comprehensive plus broad customization, high contrast mode, cognitive assist tools, haptic/audio alternatives, and external audit. | Out of scope for current solo MVP. |

### This Project's Commitment

**Target Tier**: Basic.

**Rationale**: Echo's Tier 1 MVP must validate the core run-and-gun + rewind loop before adding a full accessibility/settings architecture. The design already defers Input Remapping #23, Accessibility Options #24, Localization #22, and persistence-backed settings beyond Tier 1. A Basic commitment is achievable now because the Menu/Pause GDD already provides session-only Master/Music/SFX/UI sliders through `AudioManager`, the HUD and Story Intro GDDs already require Steam Deck-readable text, and architecture ADR-0007 defines the input/UI focus boundaries needed for later accessibility expansion. Dropping below Basic would risk unreadable Steam Deck text, color-only combat communication, uncontrolled rewind shader flashes, and audio mix barriers; raising to Standard now would contradict the accepted Tier 1 scope unless a future ADR/GDD explicitly brings #23/#24 forward.

### Features In Scope for Tier 1

- Steam Deck-readable critical text for HUD, menu/pause, and story intro.
- No gameplay-critical meaning communicated by color alone.
- Session-only Master/Music/SFX/UI volume controls through Menu/Pause → AudioManager.
- Photosensitivity/strobe constraints for rewind shader, VFX, and collage presentation.
- Gamepad and keyboard/mouse default support, with no required input chords for core rewind.
- UI/gameplay focus separation so HUD/story text do not steal gameplay input and Menu/Pause remains controller navigable.

### Features Explicitly Out of Scope for Tier 1

- Full input remapping and persisted bindings (#23 Input Remapping / future SettingsManager).
- Player-facing accessibility options menu beyond session audio sliders (#24 Accessibility Options).
- Colorblind palette modes as runtime settings.
- Screen reader support.
- HUD repositioning or full UI scaling sliders.
- Subtitle customization; Tier 1 has no voiced dialogue requirement.
- Persistent settings writes from Menu/Pause or AudioManager; ADR-0006 reserves persistence for future `SettingsManager` / `SaveManager`.

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Requirement |
|---|---|---|---|---|
| Minimum HUD readability | Basic | Combat HUD | Committed | HUD critical text/icons must remain readable at 1080p and Steam Deck handheld scale. Source: `design/gdd/hud.md`. |
| Story intro readability | Basic | Five-line intro | Committed | Each line must fit the approved text cap and remain legible at Steam Deck target resolution. Source: `design/gdd/story-intro-text.md`. |
| Menu/Pause readability | Basic | Pause/options/title-shell UI | Committed | Focusable controls must be readable and controller navigable; exact layout belongs in UX specs. Source: `design/gdd/menu-pause.md`. |
| Color-as-only indicator ban | Basic | Gameplay + UI | Committed | No required player decision may depend on color alone; pair color with shape, icon, text, animation, or position. |
| Photosensitivity guard | Basic | Rewind shader, VFX, collage effects | Committed | Rewind shader visibility and intensity must follow ADR-0010 limits; visual effects must avoid unsafe flash/strobe patterns. |
| Runtime colorblind modes | Standard | Global settings | Deferred | Future #24 Accessibility Options candidate; not a Tier 1 gate requirement. |
| UI scaling slider | Standard | Menus/HUD | Deferred | Future #24 Accessibility Options candidate; Tier 1 uses authored readable scale. |
| High contrast mode | Comprehensive | Menus/HUD | Deferred | Future #24 Accessibility Options candidate. |

### Color-as-Only-Indicator Audit

| Location | Current/Planned Signal | Risk | Non-Color Backup Required | Status |
|---|---|---|---|---|
| Rewind token HUD | Token count / availability | Player may miss state if color-only | Numeric/icon state and prompt text, not hue alone | Required in UX spec |
| Boss phase/presence pulse | Phase feedback | Color-only phase feedback would be inaccessible | Pulse shape/timing or text/icon cue in addition to color | Required in UX spec |
| Projectile/hazard readability | Enemy vs player threat | Collage palette may reduce contrast | Distinct silhouette, motion, layer, or outline; not hue alone | Required in art/UX validation |
| Menu focus state | Focused control | Focus color alone may fail | Visible outline/selection shape and controller focus behavior | Required in UX spec |

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Requirement |
|---|---|---|---|---|
| Default gamepad + keyboard/mouse support | Basic | All Tier 1 gameplay | Committed | Technical preferences require gamepad primary and KB+M parity. |
| No core rewind chord | Basic | Rewind input | Committed | Time-rewind input must be a single dedicated button, not a chord. Source: technical preferences / Input GDD. |
| Pause access | Basic | Gameplay pause | Committed | PauseHandler owns pause lifecycle; resume is always allowed. Source: ADR-0007. |
| Full input remapping | Standard | All gameplay inputs | Deferred | Future #23 Input Remapping / #24 accessibility work; architecture reserves SettingsManager path. |
| Hold/toggle alternatives | Standard | Hold inputs | Deferred | Audit during #24 Accessibility Options; Tier 1 should avoid unnecessary hold requirements. |
| Aim assist sliders | Standard | Shooting | Deferred | Future difficulty/accessibility design; not a Tier 1 gate requirement. |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Requirement |
|---|---|---|---|---|
| Five-minute readability rule | Basic | First-time player onboarding | Committed | Core inputs and first-death rewind prompt must support the Pillar 4 onboarding goal. |
| Passive story intro | Basic | Opening text | Committed | Story Intro must not add a prompt gate, skip action, or extra input requirement. Source: ADR-0007 / Story Intro GDD. |
| Pause menu clarity | Basic | Pause/options UI | Committed | Menu/Pause must provide clear Resume/Options flow and restore focus predictably. |
| Objective/help archive | Standard | Tutorials/help | Deferred | Future UX/system scope if tutorial prompts expand. |
| Cognitive assist modes | Comprehensive | Gameplay assists | Deferred | Future #24 Accessibility Options candidate. |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Requirement |
|---|---|---|---|---|
| Independent audio volume controls | Basic | Master/Music/SFX/UI | Committed | Menu/Pause uses `AudioManager.set_session_bus_volume()` / `get_session_bus_volume()` for session-only sliders. No disk persistence in Tier 1. |
| Gameplay-critical audio has visual equivalent | Basic | Combat and UI feedback | Committed | AudioManager is presentation-only; no required survival decision may depend on sound alone. |
| Subtitles for voiced dialogue | Basic | Voiced content | N/A for Tier 1 | Tier 1 has no voiced dialogue requirement. If voice is added, subtitles become required before shipping that content. |
| Closed captions for SFX | Comprehensive | Gameplay-critical SFX | Deferred | Future #24 candidate; Tier 1 must still provide visual equivalents for critical audio. |
| Mono audio option | Comprehensive | Global audio | Deferred | Future #24 Accessibility Options candidate. |

---

## UI / UX Requirements for Upcoming Specs

The next UX artifacts must reflect this document:

1. `design/ux/interaction-patterns.md` must define focus, selection, disabled-state, prompt, and text-readability patterns that do not rely on color alone.
2. A key screen UX spec, preferably HUD or Menu/Pause, must explicitly list this document as an accessibility input.
3. Menu/Pause UX must keep audio controls session-only unless a future SettingsManager ADR/GDD changes the persistence boundary.
4. HUD UX must preserve non-focusable gameplay display behavior and avoid color-only token/boss/prompt communication.
5. Rewind shader/VFX UX notes must preserve ADR-0010 visibility windows and readability fallbacks.

---

## Test and Review Plan

| Check | Timing | Evidence |
|---|---|---|
| Steam Deck readability check for HUD/menu/story text | First UX pass and first playable prototype | UX review notes or screenshot evidence in `tests/evidence/` |
| Color-as-only indicator audit | Each UX spec and visual implementation story | UX review checklist row |
| Menu/Pause focus navigation check | Menu/Pause UX review and implementation story | GdUnit/integration test or manual evidence |
| Session audio slider check | Menu/Pause implementation story | Automated or manual evidence proving no persistence write |
| Photosensitivity/strobe sanity check | Rewind shader/VFX prototype | Capture notes against ADR-0010 limits |

---

## Known Intentional Limitations

- Basic tier does not make Echo broadly accessible to all motor-impaired players; full remapping and assist modes are deferred and must be revisited before wider production scope.
- No external accessibility consultant is engaged as of 2026-05-14.
- No runtime accessibility menu is committed for Tier 1 beyond session audio sliders.
- This document must be revised if the project brings Input Remapping #23, Accessibility Options #24, voiced dialogue, localization, or difficulty assists into an earlier tier.

---

## Revision History

| Date | Change | Notes |
|---|---|---|
| 2026-05-14 | Initial committed accessibility baseline | Created to satisfy Technical Setup → Pre-Production gate artifact and guide UX specs. |
