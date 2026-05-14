# ADR-0012: AudioManager Bus and Playback Boundary

## Status

Accepted (ratified 2026-05-14)

## Date

2026-05-14

## Last Verified

2026-05-14 — checked against Godot 4.6 engine-reference audio notes, deprecated API list, current best practices, `design/gdd/audio.md`, `design/gdd/menu-pause.md`, and accepted ADR-0005/0006/0009.

## Decision Makers

Codex architecture-review adapter, based on approved Audio System GDD and Technical Setup gate concern resolution.

## Summary

`AudioManager` is the sole Tier 1 authority for audio bus volume state, SFX/BGM/UI playback routing, and signal-driven audio reactions. It is an Autoload presentation boundary that observes gameplay events or receives narrow direct facade calls, never mutates gameplay state, never owns persistence, and never occupies the deterministic physics-process ladder.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 / GDScript |
| **Domain** | Audio / Core presentation boundary |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff, but this ADR uses stable Godot 4.x audio concepts and records fixture obligations before implementation completion. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/audio.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md`, `.claude/docs/technical-preferences.md`, `design/gdd/audio.md`, `design/gdd/menu-pause.md`, `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md`, `docs/architecture/adr-0006-save-and-settings-persistence-boundary.md`, `docs/architecture/adr-0009-damage-hitbox-hurtbox-and-combat-event-ownership.md` |
| **Post-Cutoff APIs Used** | None selected as mandatory. The decision relies on stable concepts: `AudioServer` bus layout, `AudioStreamPlayer`, `Tween`, typed signals, `Engine.get_physics_frames()`, `linear_to_db()`, and Autoload nodes. |
| **Verification Required** | (1) Godot 4.6 fixture verifies exactly four buses `Master` / `Music` / `SFX` / `UI` in the expected order before AudioManager plays any sound. (2) Fixture verifies SFX pool size 8, dedicated Music player, and dedicated UI player route to correct buses. (3) Integration fixture verifies `scene_will_change()` kills duck tween, restores Music bus baseline, and stops BGM in order. (4) Static check proves AudioManager and audio callers do not use `FileAccess`, `ConfigFile`, `DirAccess`, `ResourceSaver`, `JSON.stringify`, `user://`, or gameplay-state writes. (5) Signal/direct-call fixtures verify every approved event in `design/gdd/audio.md` routes to playback without mutating simulation state. |

> Engine validation note: AudioServer and AudioStreamPlayer are stable Godot 4.x concepts, but the project still requires Godot 4.6 fixtures for bus layout, Tween timing, and route isolation before audio implementation stories can be marked done. Those fixtures are story completion evidence, not an architecture coverage gap.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 Cross-System Signal Architecture and Event Ordering; ADR-0006 Save and Settings Persistence Boundary; ADR-0009 Damage, HitBox/HurtBox, and Combat Event Ownership. |
| **Enables** | Audio System #4 implementation stories; Menu/Pause #18 session volume slider stories; Stage/Encounter #12 BGM start stories; Time Rewind #9 audio feedback integration; Player Shooting #7 and Damage #8 audio observer stories. |
| **Blocks** | Any production code that creates audio buses, writes session volume, plays gameplay SFX/BGM/UI sounds, subscribes AudioManager to gameplay signals, or persists audio settings. |
| **Ordering Note** | Implement ADR-0005 signal fixtures and ADR-0006 persistence denylist before completing AudioManager stories. ADR-0012 does not change ADR-0003 physics priority ordering because AudioManager must not implement `_physics_process` or `_process`. |

## Context

### Problem Statement

The Technical Setup → Pre-Production gate identified `TR-audio-001` as only partial/waived because AudioManager bus/playback authority was covered indirectly by event, persistence, and combat ADRs. Before prototype work begins, Audio needs an explicit architecture boundary so prototype stories do not invent ad-hoc bus ownership, persistence writes, or gameplay-affecting audio reactions.

### Current State

`design/gdd/audio.md` is approved and already defines concrete AudioManager rules: four audio buses, SFX pool size 8, BGM hard cut on scene transition, rewind Music ducking, UI bus isolation, session-only volume facade, and presentation-only signal reactions. Existing ADRs support parts of this boundary but do not name AudioManager as a first-class owner.

### Constraints

- Solo developer Tier 1 scope: CC0/stub audio only; no original music production pipeline until later scope.
- Godot 4.6 / GDScript project; Steam Deck-friendly PC target.
- Audio is presentation only: it cannot own hit resolution, lifecycle state, token state, pause state, or persistence.
- Menu/Pause exposes session-only sliders; ADR-0006 reserves durable settings for future Save / Settings Persistence #21.
- Audio reactions must not add a physics-process priority slot or timing authority.

### Requirements

- `AudioManager` owns the Master/Music/SFX/UI bus contract and runtime volume writes.
- Gameplay systems emit events or call narrow facade methods; they do not create audio players directly.
- SFX playback uses a bounded pool and null-safe behavior.
- BGM and rewind ducking are deterministic enough for tests and cannot leak DUCKED state across scene transitions.
- UI audio remains isolated from Music ducking and SFX pool exhaustion.
- No AudioManager path writes to disk in Tier 1.

## Decision

Accept a dedicated `AudioManager` architecture boundary for Tier 1.

1. `AudioManager` is an Autoload presentation service.
2. `project.godot` defines exactly four buses, in order: `Master`, `Music`, `SFX`, `UI`.
3. `AudioManager._ready()` asserts the bus layout before subscriptions or pool creation.
4. `AudioManager` owns one dedicated Music `AudioStreamPlayer`, one dedicated UI `AudioStreamPlayer`, and an eight-slot SFX `AudioStreamPlayer` pool assigned to the SFX bus.
5. `AudioManager` observes gameplay via the approved ADR-0005 signal/direct-call surface only:
   - `scene_will_change()` from SceneManager.
   - `rewind_started(remaining_tokens)` and `rewind_completed` from TimeRewindController.
   - `shot_fired(direction)` from Player Shooting.
   - `player_hit_lethal(cause)` and `boss_killed(boss_id)` from Damage.
   - `play_rewind_denied()` direct facade call from EchoLifecycleSM.
   - `play_ammo_empty()` direct facade call from Player Shooting.
   - `play_bgm(stream)`, `play_ui(stream)`, `set_session_bus_volume(bus_name, linear_value)`, and `get_session_bus_volume(bus_name)` direct facade calls from owning presentation/menu systems.
6. `AudioManager` may read `Engine.get_physics_frames()` only for presentation pitch-jitter lookup; this value never feeds gameplay simulation or snapshot state.
7. `AudioManager` must not implement `_physics_process` or `_process`, mutate gameplay objects, poll gameplay state, serialize data, or create persistence files.

### Architecture

```text
Gameplay owners / presenters
  SceneManager.scene_will_change() ─┐
  TimeRewind.rewind_started/done ───┤
  PlayerShooting.shot_fired ────────┤
  Damage.player_hit_lethal/boss_killed
  EchoLifecycleSM.play_rewind_denied() ─┐
  Menu/Pause play_ui + session sliders ─┤
  Stage/Encounter play_bgm ─────────────┤
                                        ▼
                                AudioManager Autoload
             ┌──────────────────────────┼─────────────────────────┐
             ▼                          ▼                         ▼
       Music player                SFX pool x8               UI player
       bus: Music                  bus: SFX                  bus: UI
             │                          │                         │
             └────────────── AudioServer buses ───────────────────┘
                      Master → Music / SFX / UI
```

### Key Interfaces

```gdscript
class_name AudioManager
extends Node

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
const SFX_POOL_SIZE: int = 8
const DUCK_TARGET_DB: float = -6.0
const DUCK_ATTACK_FRAMES: int = 2
const DUCK_RELEASE_FRAMES: int = 10

func play_bgm(stream: AudioStream) -> void
func stop_bgm() -> void
func play_ui(stream: AudioStream) -> void
func play_rewind_denied() -> void
func play_ammo_empty() -> void
func set_session_bus_volume(bus_name: StringName, linear_value: float) -> void
func get_session_bus_volume(bus_name: StringName) -> float
```

### Implementation Guidelines

- Use Callable-style typed signal connections only; string-based `connect("signal", obj, "method")` is forbidden by ADR-0005.
- Bus volume changes go through `AudioServer.set_bus_volume_db()` after clamping `linear_value` to `0.0..1.0`.
- Session volume state is memory-only. Do not use `FileAccess`, `ConfigFile`, `DirAccess`, `ResourceSaver`, `JSON.stringify`, or `user://` in AudioManager.
- Kill any active duck Tween before creating another duck/release Tween or before scene transition BGM stop.
- Null stream inputs return safely and may emit a once-per-session warning per missing asset key.
- SFX pool exhaustion silently drops the new SFX; it does not queue, allocate, or block gameplay.

## Alternatives Considered

### Alternative 1: Keep Audio covered indirectly by event/persistence/combat ADRs

- **Description**: Leave `TR-audio-001` partial/waived and rely on ADR-0005/0006/0009.
- **Pros**: No new ADR and less documentation.
- **Cons**: Gate remains in CONCERNS; implementers must infer bus ownership and routing from several documents.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: The Pre-Production gate needs explicit Audio coverage to prevent ad-hoc prototype audio code.

### Alternative 2: Dedicated AudioManager boundary (selected)

- **Description**: Add this ADR to make AudioManager authority explicit while preserving Tier 1 stub scope.
- **Pros**: Closes `TR-audio-001`; gives programmers concrete allowed/forbidden paths; aligns Audio GDD with architecture review.
- **Cons**: Adds one more ADR to keep current if Audio scope changes.
- **Estimated Effort**: Low.
- **Rejection Reason**: Selected.

### Alternative 3: Full audio middleware / event bus

- **Description**: Add an audio event routing layer or middleware abstraction now.
- **Pros**: More scalable for large productions.
- **Cons**: Overbuilt for solo Tier 1; conflicts with ADR-0005 no-global-event-bus decision; increases test burden.
- **Estimated Effort**: Medium to high.
- **Rejection Reason**: Not justified for CC0/stub Tier 1 audio.

## Consequences

### Positive

- `TR-audio-001` is fully covered by a dedicated accepted ADR.
- Audio prototype stories have clear bus, playback, persistence, and observer boundaries.
- Menu/Pause session sliders can integrate without violating the save/settings boundary.
- Rewind ducking and scene-transition cleanup become testable contracts.

### Negative

- Future expansion to middleware, original music tooling, or persistent audio settings must update or supersede this ADR.
- Audio implementation stories now have explicit fixture/static-check obligations before story completion.

### Neutral

- This ADR does not require final audio assets; CC0 placeholders and null-safe paths remain valid.
- This ADR does not change GDD scope, art direction, or gameplay balance.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Godot 4.6 AudioServer bus assumptions differ from project config | Low | High | `_ready()` bus-layout assert plus fixture before story completion. |
| Rewind duck Tween carries into next scene | Medium | Medium | Required scene transition fixture: kill Tween, restore baseline, stop BGM in order. |
| Session sliders accidentally become persistent settings | Medium | High | ADR-0006 denylist static check for persistence APIs outside future SettingsManager/SaveManager. |
| SFX pool cap drops important feedback | Medium | Low for Tier 1 | Preserve silent-drop rule, log no gameplay error, and re-evaluate pool invariant when SFX event set grows. |
| Audio feedback becomes gameplay authority | Low | High | Static/code review rule: AudioManager never mutates simulation state and consumes only approved signals/facades. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU frame time | No explicit audio architecture | Signal handlers < 0.5 ms each in isolation | 16.6 ms total frame; audio must remain negligible presentation overhead |
| Memory | No explicit cap | 10 AudioStreamPlayer nodes plus referenced placeholder streams | Within 1.5 GB resident ceiling |
| Load Time | N/A | Bus assert + pool creation in `_ready()` | No player-visible boot delay |
| Network | N/A | N/A | N/A |

## Migration Plan

No production AudioManager implementation exists yet, so this is a forward-only prototype constraint.

1. Ensure `project.godot` bus layout matches Master/Music/SFX/UI.
2. Implement AudioManager with bus assertion, SFX pool, Music player, UI player, and approved facades.
3. Add Godot 4.6 fixtures for bus layout, routing, ducking scene cleanup, session volume clamp, and no persistence writes.
4. Wire approved producers only after ADR-0005 signal fixtures exist.

**Rollback plan**: If prototype audio complexity grows beyond this boundary, mark ADR-0012 Superseded and write a new audio-routing ADR before adding middleware, a global audio event bus, or persistent audio settings.

## Validation Criteria

- [ ] `project.godot` defines exactly Master/Music/SFX/UI buses in expected order.
- [ ] AudioManager has no `_physics_process` or `_process` method.
- [ ] AudioManager creates exactly 8 SFX pool players, one Music player, and one UI player routed to the correct buses.
- [ ] `scene_will_change()` cleanup kills duck Tween, restores Music baseline, and stops BGM in order.
- [ ] `set_session_bus_volume()` clamps values, writes AudioServer bus dB, and performs no file/persistence writes.
- [ ] Static checks prove AudioManager does not write gameplay state or call persistence APIs.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/audio.md` | Audio | `AudioManager` owns AudioServer bus architecture, SFX pool, BGM lifecycle, scene signal subscription, and session-only bus volume facade. | Names `AudioManager` as the dedicated authority for bus layout, playback routing, ducking, and session volume writes. |
| `design/gdd/audio.md` | Audio | Audio operates as a signal/direct-call driven reactor and does not occupy the ADR-0003 physics ladder. | Forbids `_physics_process` / `_process` and gameplay-state mutation. |
| `design/gdd/audio.md` | Audio | Session bus volume facade must not use `FileAccess`, `ConfigFile`, or `user://` writes. | Ties audio sliders to ADR-0006 deny-by-default persistence and requires static checks. |
| `design/gdd/menu-pause.md` | Menu/Pause | Menu/Pause uses `AudioManager.play_ui()` and session-only bus volume methods. | Defines the allowed Menu/Pause → AudioManager facade and UI bus isolation. |
| `design/gdd/player-shooting.md`, `design/gdd/damage.md`, `design/gdd/time-rewind.md`, `design/gdd/scene-manager.md` | Cross-system audio observers | Gameplay events trigger audio presentation without giving AudioManager gameplay authority. | Restricts AudioManager to approved ADR-0005 signal/direct-call surfaces. |

## Related

- `design/gdd/audio.md`
- `design/gdd/menu-pause.md`
- `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md`
- `docs/architecture/adr-0006-save-and-settings-persistence-boundary.md`
- `docs/architecture/adr-0009-damage-hitbox-hurtbox-and-combat-event-ownership.md`
- `docs/architecture/architecture.md`
- `docs/architecture/architecture-traceability.md`
