# ADR-0006: Save and Settings Persistence Boundary

## Status
Accepted (ratified 2026-05-14)

## Date
2026-05-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / File I/O / Persistence / UI Settings |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md`, `.claude/docs/technical-preferences.md`, `docs/registry/architecture.yaml`, `docs/architecture/architecture.md`, `docs/architecture/adr-0001-time-rewind-scope.md`, `docs/architecture/adr-0002-time-rewind-storage-format.md`, `docs/architecture/adr-0003-determinism-strategy.md`, `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md`, `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md`, `design/gdd/systems-index.md`, `design/gdd/menu-pause.md`, `design/gdd/audio.md`, `design/gdd/input.md`, `design/gdd/scene-manager.md`, `design/gdd/state-machine.md` |
| **Post-Cutoff APIs Used** | None. This ADR relies on stable Godot concepts: `ConfigFile`, `user://`, `FileAccess`/`DirAccess` static checks, `Error` return codes, `InputMap`, and existing runtime facades. Godot 4.4 changed low-level `FileAccess.store_*` return values to `bool`, so future code must not assume old `void` behavior if it bypasses `ConfigFile`. |
| **Verification Required** | (1) Direct Godot 4.6 fixture verifies `ConfigFile.load()` / `ConfigFile.save()` error behavior under `user://`. (2) Static checks prove `FileAccess`, `ConfigFile`, `DirAccess`, `ResourceSaver`, `JSON.stringify`, and `user://` writes appear only in the approved persistence module path. (3) Menu/Pause, Audio, Input, Scene Manager, StateMachine, TimeRewindController, and PlayerSnapshot production code have no ad-hoc persistence writes. (4) Corrupt settings/progress files fall back to defaults or Stage 1 without boot failure. (5) Runtime InputMap mutation occurs only through `SettingsManager` in a paused tree. |

> Engine validation note: primary engine specialist from `.claude/docs/technical-preferences.md` is `godot-specialist`. In this Codex adapter run, no subagent was spawned because the repository adapter limits `Task`/subagent use to explicit user-requested delegation. The draft was validated locally against the pinned Godot 4.6 reference files listed above. No blocking Godot 4.6 persistence API incompatibility was found, but direct Godot 4.6 fixtures are required before implementing Save / Settings Persistence #21.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Time Rewind Scope; ADR-0002 Time Rewind Storage Format; ADR-0003 Determinism Strategy; ADR-0004 Scene Lifecycle and Checkpoint Restart Architecture; ADR-0005 Cross-System Signal Architecture and Event Ordering. These must be accepted before any implementation persists settings or progress. |
| **Enables** | Static persistence boundary checks for Tier 1; future Save / Settings Persistence #21 GDD; future Input Remapping #23 and Accessibility #24 persistence seams. |
| **Blocks** | Any story that writes `user://`, saves settings, persists progress, serializes `PlayerSnapshot` as a save file, mutates `InputMap` from an unpaused tree, or adds file I/O to Menu/Pause, Audio, Scene Manager, StateMachine, TimeRewindController, PlayerMovement, WeaponSlot, HUD, VFX, or Camera. |
| **Ordering Note** | This ADR does not implement Save / Settings #21. It locks the boundary that Tier 1 systems must obey until #21 is designed and accepted. |

## Context

### Problem Statement

Echo's Tier 1 GDDs intentionally keep persistence out of the core loop:

- `design/gdd/systems-index.md` lists Save / Settings Persistence #21 as a Vertical Slice system, not MVP Tier 1.
- `design/gdd/menu-pause.md` allows only session-only Master/Music/SFX/UI sliders and forbids disk writes.
- `design/gdd/audio.md` exposes an in-memory session bus volume facade and forbids `FileAccess`, `ConfigFile`, and `user://` writes in AudioManager.
- `design/gdd/input.md` reserves future `SettingsManager.apply_deadzone()` / `apply_remap()` seams and requires paused-tree mutation for runtime InputMap changes.
- `design/gdd/scene-manager.md` defers invalid save-file scene fallback to Save / Settings #21.
- `design/gdd/state-machine.md` explicitly excludes StateMachine save/restore in Tier 1.

Without a Foundation persistence ADR, implementation could accidentally add ad-hoc `ConfigFile` writes to UI or serialize runtime rewind snapshots as player progress. This ADR locks the persistence boundary before coding starts.

### Existing Architectural Stances

- **Menu/Pause boundary**: Menu/Pause owns focusable UI and session-only audio options; it must not write persistent settings.
- **Audio boundary**: AudioManager owns runtime bus values through `set_session_bus_volume()` / `get_session_bus_volume()`; it must not save them.
- **Input boundary**: runtime InputMap mutation is future-only and must go through `SettingsManager` in a paused tree.
- **Scene boundary**: SceneManager owns transitions; invalid persisted stage references must fall back through SceneManager rather than raw SceneTree calls.
- **Rewind boundary**: `PlayerSnapshot` is a runtime rewind Resource, not a Tier 1 save file.
- **Determinism boundary**: gameplay timing remains `Engine.get_physics_frames()`; persistence timestamps or wall-clock values may not drive gameplay outcomes.

### Constraints

- Tier 1 must remain playable with zero persistent save/settings files.
- Settings persistence is a future Vertical Slice feature, not a Menu/Pause responsibility.
- Progress persistence is a future Vertical Slice feature, not a SceneManager or StateMachine responsibility.
- All file I/O must be non-fatal; corrupt files fall back to safe defaults.
- Settings writes must not occur from gameplay `_physics_process` or unpaused InputMap mutation.
- PC/Steam target uses Godot's `user://` sandbox path for player-specific files.
- Solo scope favors transparent text config over custom binary serialization.

### Requirements

- **R-PERSIST-01**: Tier 1 production gameplay and UI systems write no persistent files.
- **R-PERSIST-02**: Future settings persistence is owned by `SettingsManager`, not Menu/Pause or AudioManager.
- **R-PERSIST-03**: Future progress persistence is owned by `SaveManager`, not SceneManager, StateMachine, TRC, PlayerMovement, WeaponSlot, or gameplay entities.
- **R-PERSIST-04**: Future settings use a versioned `ConfigFile` at `user://echo_settings.cfg`.
- **R-PERSIST-05**: Future progress flags use a versioned `ConfigFile` at `user://echo_progress.cfg`.
- **R-PERSIST-06**: `PlayerSnapshot`, TRC ring buffers, projectiles, enemy/boss runtime state, and StateMachine current states are not serialized as save progress in Tier 1 or Vertical Slice #21 without a new ADR/amendment.
- **R-PERSIST-07**: Menu/Pause may apply session values immediately through AudioManager, but file writes can only happen through `SettingsManager`.
- **R-PERSIST-08**: Runtime InputMap deadzone/remap changes may only occur through `SettingsManager` while the scene tree is paused.
- **R-PERSIST-09**: Corrupt settings/progress files use defaults and emit warnings; they must not block cold boot.
- **R-PERSIST-10**: Static checks ban persistence API use outside the approved persistence module.

## Decision

Use a **deny-by-default Tier 1 persistence boundary** and reserve two future Vertical Slice authorities:

1. `SettingsManager` owns player settings persistence.
2. `SaveManager` owns progress persistence.

No Tier 1 MVP system may write persistent files. Menu/Pause remains session-only; AudioManager remains runtime-only; InputMap defaults remain project-owned; SceneManager, StateMachine, TRC, PlayerMovement, WeaponSlot, HUD, VFX, Audio, and Camera do not save or load progress.

When Save / Settings Persistence #21 is authored, it must use versioned Godot `ConfigFile` files under `user://`:

- `user://echo_settings.cfg` for settings.
- `user://echo_progress.cfg` for progress flags.

Both files are optional. Missing, corrupt, or invalid files fall back to defaults and log a warning.

### Architecture Diagram

```text
Tier 1 MVP
  Menu/Pause sliders ──direct runtime call──▶ AudioManager session bus values
        │                                      (in memory only)
        └── no file writes

Future Save / Settings #21
  SettingsManager ──ConfigFile──▶ user://echo_settings.cfg
        │
        ├── applies audio settings through AudioManager facade
        └── applies InputMap changes only in paused tree

  SaveManager ──ConfigFile──▶ user://echo_progress.cfg
        │
        └── resolves boot/progress stage through SceneManager API

Forbidden everywhere outside src/persistence/*
  FileAccess / ConfigFile / DirAccess / ResourceSaver / JSON save writes / user:// writes
```

### Key Interfaces

These interfaces are reserved for Save / Settings Persistence #21. They are not required Tier 1 implementation work.

```gdscript
# Future settings owner
class_name SettingsManager
extends Node

const SETTINGS_PATH: String = "user://echo_settings.cfg"
const SETTINGS_SCHEMA_VERSION: int = 1

func load_settings() -> Error
func commit_settings() -> Error
func set_audio_setting(bus_name: StringName, linear_value: float) -> void
func get_audio_setting(bus_name: StringName) -> float
func apply_loaded_audio_settings(audio_manager: Node) -> void

# Tier 3 seams already referenced by Input GDD
func apply_deadzone(value: float) -> Error
func apply_remap(action: StringName, events: Array[InputEvent]) -> Error

# Future progress owner
class_name SaveManager
extends Node

const PROGRESS_PATH: String = "user://echo_progress.cfg"
const PROGRESS_SCHEMA_VERSION: int = 1

func load_progress() -> Error
func commit_progress() -> Error
func mark_stage_completed(stage_id: StringName) -> void
func get_furthest_stage_id() -> StringName
func resolve_boot_stage(default_stage_id: StringName) -> StringName
```

### Settings File Schema

`user://echo_settings.cfg`:

```ini
[meta]
schema_version=1

[audio]
master=1.0
music=1.0
sfx=1.0
ui=1.0

[input]
# Reserved for Tier 3 #23/#24. Absent in Tier 1.
deadzone=0.2
remap_profile_version=0
```

Rules:

- Audio values are floats clamped to `0.0..1.0`.
- Missing audio keys default to `1.0`.
- `deadzone` is reserved for future accessibility/remap work and must satisfy Input GDD invariants before application.
- Settings apply to runtime systems through their public facades; settings file parsing does not directly write AudioServer or gameplay state.

### Progress File Schema

`user://echo_progress.cfg`:

```ini
[meta]
schema_version=1

[progress]
furthest_stage_id="stage_01"
completed_stage_ids=PackedStringArray()
progress_flags=PackedStringArray()
```

Rules:

- Stage IDs must be validated against the SceneManager stage table.
- Invalid or missing `furthest_stage_id` falls back to `stage_01`.
- Progress flags are append-only string identifiers owned by future #21 GDD content.
- This file does not contain player position, `PlayerSnapshot`, TRC ring buffer contents, current StateMachine state, projectile state, boss phase state, or scene node paths.

### Runtime Boundary Rules

- Menu/Pause #18 may call `AudioManager.set_session_bus_volume(bus_name, linear_value)` and `AudioManager.get_session_bus_volume(bus_name)`.
- Menu/Pause #18 must not call `ConfigFile`, `FileAccess`, `DirAccess`, `ResourceSaver`, `JSON.stringify` for save output, or write `user://`.
- AudioManager stores `_session_bus_linear` in memory only. Future settings load may call the existing facade; AudioManager still does not parse files.
- SceneManager may consume a validated stage ID from SaveManager, but SaveManager may not call raw `SceneTree.change_scene_to_packed`.
- InputMap runtime mutation must be performed only by `SettingsManager` while paused, then verified on the next physics frame.
- Save/settings writes should occur on explicit settings commit, options close, title/menu save action, or progress milestone; they must not happen every slider tick or gameplay physics tick.

### Registry Candidates

`docs/registry/architecture.yaml` is not updated by this ADR draft without explicit approval. If approved, the registry should mirror this decision with candidates equivalent to:

- `state_ownership.settings_persistence`: owner `SettingsManager`; file `user://echo_settings.cfg`; settings-only ConfigFile; runtime application through approved facades.
- `state_ownership.progress_persistence`: owner `SaveManager`; file `user://echo_progress.cfg`; progress flags / validated stage IDs only.
- `interfaces.settings_manager_persistence`: `load_settings()`, `commit_settings()`, `set_audio_setting()`, `get_audio_setting()`, `apply_loaded_audio_settings()`, `apply_deadzone()`, `apply_remap()`.
- `interfaces.save_manager_progress`: `load_progress()`, `commit_progress()`, `mark_stage_completed()`, `get_furthest_stage_id()`, `resolve_boot_stage()`.
- `api_decisions.persistence_configfile_paths`: `user://echo_settings.cfg` and `user://echo_progress.cfg`, both `schema_version=1`.
- `forbidden_patterns.file_io_outside_persistence_module`: bans `FileAccess`, `ConfigFile`, `DirAccess`, `ResourceSaver`, save-oriented `JSON.stringify`, and `user://` writes outside `src/persistence/`.
- `forbidden_patterns.player_snapshot_progress_serialization`: bans saving `PlayerSnapshot`, TRC ring buffers, StateMachine current state, projectiles, enemies, bosses, or node paths as progress.
- `forbidden_patterns.persistence_write_in_physics_process`: bans persistent writes from gameplay `_physics_process`.
- `forbidden_patterns.inputmap_mutation_outside_settings_manager`: reinforces paused-tree `SettingsManager.apply_*` as the only runtime InputMap mutation path.

## Alternatives Considered

### Alternative 1: No Tier 1 Persistence + Future ConfigFile Managers (Selected)

- **Description**: Tier 1 writes no files; future #21 uses `SettingsManager` and `SaveManager` with versioned `ConfigFile` files.
- **Pros**:
  - Matches current GDD scope and prevents settings creep.
  - Keeps Menu/Pause and Audio simple.
  - Human-readable files are easy to debug for a solo project.
  - Corruption handling can be tested with small fixtures.
  - Separates settings from progress for safer fallback.
- **Cons**:
  - Future #21 still needs schema migration tests.
  - Two small files add a little boot/load plumbing.
  - `ConfigFile` is less expressive than custom Resources for complex save state.
- **Selection Reason**: Smallest future-proof boundary that satisfies Tier 1 non-persistence and Vertical Slice options/progress needs.

### Alternative 2: Persist Settings Immediately from Menu/Pause

- **Description**: Menu/Pause writes `user://settings.cfg` every time a slider changes.
- **Pros**:
  - Fewer future systems.
  - Settings survive process exit sooner.
- **Cons**:
  - Contradicts Menu/Pause Rule 9 and AC-MENU-13.
  - Adds file I/O to a UI system before #21 is designed.
  - Encourages per-slider disk writes and scattered migration logic.
- **Rejection Reason**: Violates the current GDD boundary and turns a Tier 1 UI feature into persistence infrastructure.

### Alternative 3: Save Runtime Game State as Resources

- **Description**: Serialize `PlayerSnapshot`, StateMachine states, scene paths, boss/enemy data, and current runtime state into a save Resource.
- **Pros**:
  - Could support mid-run restore later.
  - Reuses Godot Resource patterns.
- **Cons**:
  - Contradicts Architecture "do not serialize `PlayerSnapshot` as a save file" guidance.
  - Blurs Time Rewind runtime state with long-term progress.
  - Requires broad ownership rules for enemies, bullets, bosses, and scene nodes before they are designed for persistence.
  - Much larger migration and corruption surface.
- **Rejection Reason**: Too broad for Tier 1/Vertical Slice. Reconsider only with a dedicated full-state save ADR.

### Alternative 4: Single JSON Save Blob

- **Description**: Store all settings and progress in one JSON file under `user://`.
- **Pros**:
  - Familiar format.
  - One file to inspect.
- **Cons**:
  - Settings corruption can destroy progress and vice versa.
  - Requires custom parse/validation/migration shape.
  - Easier to drift into generic Dictionary payloads with weak typing.
- **Rejection Reason**: Two `ConfigFile` files give better isolation and easier section/key validation for the current scope.

## Consequences

### Positive

- Makes Tier 1 non-persistence enforceable instead of aspirational.
- Protects Menu/Pause #18 from becoming a settings/save system.
- Preserves Audio #4 as runtime playback/mixing owner only.
- Preserves SceneManager #2 as transition owner while allowing future validated progress boot routing.
- Gives Input #1 a concrete future `SettingsManager` authority for paused-tree deadzone/remap mutation.
- Keeps corrupt files non-fatal.
- Creates clear static-check targets before implementation starts.

### Negative

- Tier 1 options reset on process exit by design.
- Future #21 must implement load/commit/migration tests before enabling persistence.
- Future #21 must update Menu/Pause copy if "session only" changes to persisted settings.
- ConfigFile schemas are intentionally small; larger save-state needs require a new ADR.

### Risks

- **Ad-hoc file I/O leaks into UI/audio code**: mitigate with static grep for persistence APIs outside `src/persistence/`.
- **PlayerSnapshot misuse as save state**: mitigate with static checks and code review gates banning `PlayerSnapshot` serialization in SaveManager.
- **Corrupt file boot crash**: mitigate with fixture tests for malformed ConfigFile contents and missing keys.
- **InputMap mutation during gameplay**: mitigate with `SettingsManager.apply_*` paused-tree tests and static bans on direct `InputMap.action_*` mutation outside SettingsManager.
- **Schema migration drift**: mitigate with explicit `schema_version` keys and migration tests before #21 acceptance.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `docs/architecture/architecture.md` | TR-persist-001: Save/settings persistence is Vertical Slice and must not be accidentally invented in Tier 1 systems. | Locks deny-by-default Tier 1 persistence and future #21 ownership. |
| `design/gdd/systems-index.md` | Save / Settings Persistence #21 owns options file and progress flags. | Reserves `SettingsManager`, `SaveManager`, `echo_settings.cfg`, and `echo_progress.cfg`. |
| `design/gdd/menu-pause.md` | Rule 9 / AC-MENU-13: options are session-only until #21; no FileAccess/ConfigFile/user-data write. | Keeps Menu/Pause runtime-only and bans file APIs from #18. |
| `design/gdd/audio.md` | Rule 18: AudioManager session bus volume facade is in-memory and forbids FileAccess/ConfigFile/user:// writes. | Preserves AudioManager as runtime owner; future settings apply through the facade. |
| `design/gdd/input.md` | Runtime InputMap mutation only through `SettingsManager.apply_deadzone()` / `apply_remap()` in a paused tree. | Reserves SettingsManager as the only future settings mutation authority. |
| `design/gdd/scene-manager.md` | E.9 invalid save scene reference is deferred to Save #21 and should fall back to Stage 1. | SaveManager validates stage IDs and routes boot stage through SceneManager API. |
| `design/gdd/state-machine.md` | Tier 1 excludes StateMachine save/restore; ECHO and enemies reset on scene reload. | Bans StateMachine state persistence in Tier 1 / Vertical Slice progress files. |
| `docs/architecture/adr-0002-time-rewind-storage-format.md` | `PlayerSnapshot` is a runtime rewind Resource schema. | Keeps `PlayerSnapshot` out of progress saves unless a future ADR/amendment explicitly expands scope. |

## Performance Implications

- **CPU**: Tier 1 has no persistence CPU cost. Future #21 loads tiny ConfigFiles at boot/options entry and commits only on explicit settings/progress events.
- **Memory**: Tier 1 no additional memory. Future settings/progress snapshots are tiny Dictionaries/ConfigFile sections.
- **Load Time**: Tier 1 none. Future #21 must keep missing/corrupt file fallback under normal cold-boot budget; file read should be negligible compared with scene load.
- **Network**: None; single-player local game. Steam Cloud or cross-device sync would require a future platform ADR.

## Migration Plan

No production persistence implementation exists yet. Implementation should proceed as follows after ADR acceptance:

1. Add static checks banning persistence APIs outside `src/persistence/`.
2. Keep Tier 1 Menu/Pause options session-only and retain "session only" UI copy.
3. Keep AudioManager's `_session_bus_linear` as in-memory runtime state.
4. When #21 is designed, create `SettingsManager` and `SaveManager` under `src/persistence/`.
5. Implement `user://echo_settings.cfg` and `user://echo_progress.cfg` schemas with `schema_version=1`.
6. Add corrupt/missing/invalid fixture tests.
7. Add SceneManager stage-table validation before SaveManager can resolve a boot stage.
8. Add paused-tree tests for `SettingsManager.apply_deadzone()` and future remap application.
9. Do not serialize `PlayerSnapshot` or StateMachine current state unless a later ADR explicitly supersedes this boundary.

## Validation Criteria

This decision is correct if the following pass:

- `test_no_persistence_api_outside_src_persistence_static`
- `test_menu_pause_no_file_io_static`
- `test_audio_manager_no_file_io_static`
- `test_scene_manager_no_save_file_parse_static`
- `test_player_snapshot_not_serialized_as_progress_static`
- `test_settings_config_missing_uses_defaults`
- `test_settings_config_corrupt_uses_defaults_and_warns`
- `test_progress_config_invalid_stage_falls_back_to_stage_01`
- `test_settings_audio_values_clamped_before_apply`
- `test_settings_commit_writes_schema_version_1`
- `test_progress_commit_writes_schema_version_1`
- `test_settingsmanager_inputmap_mutation_requires_paused_tree`
- `test_no_persistence_write_in_physics_process_static`

## Related Decisions

- `docs/architecture/adr-0001-time-rewind-scope.md` — player-only rewind scope.
- `docs/architecture/adr-0002-time-rewind-storage-format.md` — runtime `PlayerSnapshot` Resource schema.
- `docs/architecture/adr-0003-determinism-strategy.md` — deterministic frame clock and no gameplay wall-clock.
- `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md` — SceneManager transition authority.
- `docs/architecture/adr-0005-cross-system-signal-architecture-and-event-ordering.md` — cross-system signal/direct-call boundary.
- `docs/registry/architecture.yaml` — current Menu/Pause, InputMap, Scene, and forbidden-pattern stances.
- `design/gdd/systems-index.md`
- `design/gdd/menu-pause.md`
- `design/gdd/audio.md`
- `design/gdd/input.md`
- `design/gdd/scene-manager.md`
- `design/gdd/state-machine.md`
