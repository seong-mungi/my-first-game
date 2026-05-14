# Control Manifest

> **Engine**: Godot 4.6 / GDScript
> **Last Updated**: 2026-05-14
> **Manifest Version**: 2026-05-14
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0012
> **Latest Architecture Review**: 2026-05-14 — PASS; 46 covered, 0 partial/waived, 0 gaps; no blocking ADR conflicts
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. It intentionally
matches `Last Updated`.

This is a programmer quick-reference extracted from Accepted ADRs, technical
preferences, and Godot 4.6 engine reference docs. For rationale, rejected
alternatives, and verification detail, read the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine setup,
persistence boundaries, and shared project contracts.*

### Required Patterns

- **Scene transitions must go through `SceneManager.change_scene_to_packed(packed, intent)`; `SceneManager` owns the single raw Godot scene swap site.** Source: ADR-0004.
- **Emit `scene_will_change()` exactly once before the raw scene swap and `scene_post_loaded(anchor: Vector2, limits: Rect2)` after checkpoint anchor and camera limits registration.** Source: ADR-0004.
- **Checkpoint restart must complete within `SWAPPING + POST_LOAD + 1 READY confirmation <= 60` physics ticks under nominal Tier 1 content.** Source: ADR-0004.
- **Stage roots must expose positive-size `stage_camera_limits: Rect2` before `scene_post_loaded`; active respawn anchors use the `checkpoint_anchor` group.** Source: ADR-0004.
- **Use direct producer-owned typed Godot signals for Tier 1 cross-system events; determine gameplay order by producer-local emit order, declared connection order, or ADR-0003 physics priority.** Source: ADR-0005.
- **If gameplay order is undefined, gameplay code must not depend on it. Add a GDD/ADR rule and tests before using that order.** Source: ADR-0005.
- **Use Callable-style signal connections (`signal.connect(callable)`) with default delivery for gameplay-critical events unless an ADR/GDD explicitly allows a carve-out.** Source: ADR-0005.
- **All new cross-system signals must update producer GDD catalogs, downstream consumer rows, emit order rules, tests, and registry candidates before implementation.** Source: ADR-0005.
- **Tier 1 persistence is deny-by-default: no MVP system writes persistent files.** Source: ADR-0006.
- **Future persistence authority is split: `SettingsManager` owns settings and `SaveManager` owns progress.** Source: ADR-0006.
- **Future save/settings files must be versioned Godot `ConfigFile` files under `user://echo_settings.cfg` and `user://echo_progress.cfg`; missing/corrupt files fall back to defaults with a warning.** Source: ADR-0006.
- **InputMap runtime mutation is allowed only through future `SettingsManager` while the tree is paused, then verified on the next physics frame.** Source: ADR-0006, ADR-0007.

### Forbidden Approaches

- **Never call raw `SceneTree.change_scene_to_packed`, `change_scene_to_file`, or threaded load APIs outside `SceneManager`.** Source: ADR-0004.
- **Never let `PlayerMovement` subscribe directly to `scene_will_change`; cleanup cascades through `EchoLifecycleSM`.** Source: ADR-0004, ADR-0008.
- **Never introduce a global gameplay event bus, topic-string event router, or dictionary-payload event queue for Tier 1 gameplay.** Source: ADR-0005.
- **Never use string-based signal connection syntax for gameplay signals.** Source: ADR-0005; Godot deprecated APIs.
- **Never defer gameplay-critical event delivery with `call_deferred` or deferred signal connections unless an ADR/GDD explicitly limits it to presentation-only or boot notification behavior.** Source: ADR-0005.
- **Never write `FileAccess`, `ConfigFile`, `DirAccess`, `ResourceSaver`, save-oriented `JSON.stringify`, or `user://` output outside the approved persistence module path.** Source: ADR-0006.
- **Never serialize `PlayerSnapshot`, TRC ring buffers, StateMachine current state, projectiles, enemies, boss state, or node paths as progress data.** Source: ADR-0006.
- **Never write persistent files from gameplay `_physics_process` or on every slider tick.** Source: ADR-0006.

### Performance Guardrails

- **SceneManager**: no per-frame polling; transition work is burst-only. Source: ADR-0004.
- **Checkpoint restart**: 95th percentile restart time must be `<= 60` physics ticks for the Tier 1 stage slice before production lock. Source: ADR-0004.
- **Signals**: no central production event queue/log allocation in Tier 1. Source: ADR-0005.
- **Persistence**: writes occur only on explicit commit/close/title-save/progress-milestone paths, not on continuous gameplay ticks. Source: ADR-0006.

---

## Core Layer Rules

*Applies to: core gameplay loop, player systems, input, rewind, state ownership,
physics, collision, combat, and camera-facing gameplay state.*

### Required Patterns

- **Only ECHO/player rewinds; enemies, bullets, environment, and gameplay schedules continue normal simulation.** Source: ADR-0001.
- **Time Rewind uses a 90-frame ring buffer at 60 fps and restores from a 9-frame / 0.15s pre-death offset.** Source: ADR-0001, ADR-0002.
- **`PlayerSnapshot` is a typed `Resource` with 9 fields: PM-owned movement/animation/weapon-id fields, `captured_at_physics_frame`, and WeaponSlot-owned `ammo_count`.** Source: ADR-0002.
- **Pre-allocate the 90-slot `PlayerSnapshot` ring buffer and write into existing slots; do not allocate per physics tick.** Source: ADR-0002.
- **Use the frozen lethal-hit head for restore index calculation; do not use the live write head after DYING grace advances captures.** Source: ADR-0002.
- **ECHO and all enemies must use `CharacterBody2D` with script-controlled transform/velocity.** Source: ADR-0003.
- **All gameplay projectiles must use `Area2D` with script-stepped movement; high-speed projectiles require deterministic swept raycast before stepping.** Source: ADR-0003.
- **Gameplay timing uses `Engine.get_physics_frames()` and explicit fixed-physics counters, not wall clock.** Source: ADR-0003, ADR-0007, ADR-0011.
- **Use `process_physics_priority`: PlayerMovement `0`, TRC `1`, Damage `2`, Enemy/Boss `10`, Projectile `20`.** Source: ADR-0003, ADR-0011.
- **Gameplay input reads action state only in `_physics_process` / state `physics_update` through `InputActions` `StringName` constants.** Source: ADR-0007.
- **`PauseHandler` is the single always-running pause listener; it consumes pause input on both accepted and vetoed paths.** Source: ADR-0007.
- **`PauseHandler` queries `EchoLifecycleSM.can_pause()` before initiating pause while unpaused; resume while paused always succeeds without querying SM.** Source: ADR-0007.
- **`ActiveProfileTracker` may observe raw `_input` events only for button-label/profile classification, using `Engine.get_physics_frames()` for timing.** Source: ADR-0007.
- **`PlayerMovement` is the ECHO scene root (`CharacterBody2D`) and owns movement-body fields.** Source: ADR-0008.
- **`EchoLifecycleSM` and `PlayerMovementSM` are entity-local child state machines under `PlayerMovement`.** Source: ADR-0008.
- **State transitions go through `StateMachine.transition_to()`; each SM owns its own state.** Source: ADR-0008.
- **TRC restores by owner APIs only: `PlayerMovement.restore_from_snapshot(snap)`, then `WeaponSlot.restore_from_snapshot(snap)`, then `rewind_completed`.** Source: ADR-0005, ADR-0008.
- **`WeaponSlot` is the sole writer of `ammo_count`, except snapshot data construction/read.** Source: ADR-0002, ADR-0008.
- **`AnimationPlayer.callback_mode_method` must be immediate, and animation method-track side effects must early-return while `_is_restoring` is true.** Source: ADR-0008; Godot deprecated APIs.
- **Damage owns reusable `HitBox` and `HurtBox` `Area2D` component classes; hosts instantiate them and set Damage-owned layers/masks/cause values.** Source: ADR-0009.
- **HitBox is the active scanner; HurtBox is the passive receiver; the first source emit is `HurtBox.hurtbox_hit(cause)`.** Source: ADR-0009.
- **Damage emits ECHO lethal signals in deterministic order: pending cause set, `lethal_hit_detected(cause)`, then `player_hit_lethal(cause)`.** Source: ADR-0009.
- **SM controls ECHO invulnerability by toggling `HurtBox.monitorable`; Damage must not poll SM state.** Source: ADR-0008, ADR-0009.
- **Use the locked 6-bit collision layer matrix: L1 ECHO HurtBox, L2 ECHO Projectile HitBox, L3 Enemy HurtBox, L4 Enemy/Boss Projectile HitBox, L5 Hazard HitBox, L6 Boss HurtBox.** Source: ADR-0009.

### Forbidden Approaches

- **Never rewind enemies, projectiles, environment, hazards, boss schedules, or VFX gameplay state.** Source: ADR-0001, ADR-0011.
- **Never implement input replay or hybrid replay as the Tier 1 rewind source of truth.** Source: ADR-0002.
- **Never use `RigidBody2D` for ECHO, enemies, bosses, or gameplay projectiles; only cosmetic debris outside gameplay/determinism boundaries may use it.** Source: ADR-0003.
- **Never use wall-clock APIs, global RNG, unordered dictionary/set iteration, `_process(delta)` timers, or animation-finished callbacks for gameplay-authoritative timing.** Source: ADR-0003, ADR-0011.
- **Never read gameplay input in `_input` or `_unhandled_input`; callbacks are reserved for PauseHandler, Menu/Pause UI, and profile classification carve-outs.** Source: ADR-0007.
- **Never use raw action string literals for gameplay input; use centralized `InputActions` constants.** Source: ADR-0007.
- **Never add Tier 1 menu-specific InputMap actions or Story Intro skip/press-any-key gates.** Source: ADR-0007.
- **Never create an outer ECHO gameplay wrapper above `PlayerMovement`, a global player state object, or Autoload state machines.** Source: ADR-0008.
- **Never assign `current_state` directly or call a foreign entity's `transition_to()`.** Source: ADR-0008.
- **Never let TRC write `PlayerMovement` fields directly; restore through owner methods.** Source: ADR-0008.
- **Never put camera state in `PlayerSnapshot`.** Source: ADR-0008.
- **Never let Damage own i-frame booleans, poll lifecycle state, or interpret boss phase table values outside the Damage-compatible procedure.** Source: ADR-0009.
- **Never introduce numeric player/enemy HP, HUD-facing boss hit counts, a global combat event bus, or PhysicsServer direct-query combat resolution for Tier 1.** Source: ADR-0009.

### Performance Guardrails

- **Time Rewind subsystem**: target `<= 1 ms` of frame budget; ring buffer memory is negligible relative to 1.5 GB ceiling. Source: technical preferences, ADR-0001, ADR-0002.
- **Projectile/entity motion**: script-controlled `CharacterBody2D` / `Area2D` strategy is expected to stay well under 1% of a 16.6 ms frame at Tier 1 counts; verify with ADR fixtures. Source: ADR-0003.
- **Damage**: `<= 1.0 ms` on baseline dev hardware and `<= 2.5 ms` on Steam Deck-equivalent worst-case Tier 1 combat scene. Source: ADR-0009.
- **Active gameplay `Area2D` count**: Tier 1 cap is 80; Tier 3 cap 160 requires future review. Source: ADR-0009.

---

## Feature Layer Rules

*Applies to: enemy AI, boss patterns, stage/encounter data, projectile pools,
and authored secondary gameplay systems.*

### Required Patterns

- **Stage/Encounter owns the spawn manifest for enemies, bosses, warning areas, and non-player-authored projectile schedules.** Source: ADR-0011.
- **Stage activates manifest entries in stable ascending order by `(activation_frame, spawn_id)`.** Source: ADR-0011.
- **Same-frame inserted children must use stable `(spawn_physics_frame, spawn_id, local_sequence_id)` ordering.** Source: ADR-0011.
- **`EnemyBase` extends `CharacterBody2D`, runs at `process_physics_priority = 10`, and computes `frame_offset = Engine.get_physics_frames() - spawn_physics_frame`.** Source: ADR-0011.
- **Enemy AI may read an explicit `target_player` snapshot during its priority-10 tick; it must not discover targets through unordered groups as gameplay fallback.** Source: ADR-0011.
- **Seeded variant selection is allowed only at spawn; lethal behavior after spawn is authored/frame-counter driven.** Source: ADR-0011.
- **STRIDER/BossPattern uses an EnemyBase-compatible `CharacterBody2D` host at priority 10 and authored phase schedules.** Source: ADR-0011.
- **Boss attack choice comes from `BossPhaseSpec.pattern_sequence` and `phase_elapsed_frames`, not RNG.** Source: ADR-0011.
- **Boss outputs follow `telegraph -> commit -> active -> recovery`.** Source: ADR-0011.
- **Boss phase advancement uses ADR-0009's `_phase_advanced_this_frame` lock: at most one phase advance per physics tick.** Source: ADR-0009, ADR-0011.
- **All gameplay projectile pools check out by stable ascending pool index and return by stable ID.** Source: ADR-0011.
- **Enemy/boss required projectile schedules must be covered by Stage preflight; required scheduled projectiles must not disappear silently from runtime budget pressure.** Source: ADR-0011.
- **Damage remains combat consequence owner; projectile/enemy/boss hosts set layers/masks/cause labels but do not interpret player death, enemy death, boss phase, or boss kill.** Source: ADR-0009, ADR-0011.

### Forbidden Approaches

- **Never add a global runtime scheduler/autoload that duplicates Godot physics order or replaces local GDD ownership.** Source: ADR-0011.
- **Never use runtime randomized lethal enemy/boss scheduling, even with a deterministic seed, after spawn.** Source: ADR-0011.
- **Never rewind, pause, or restore enemy, boss, warning-area, or projectile clocks when ECHO rewinds.** Source: ADR-0001, ADR-0011.
- **Never subscribe enemies, bosses, or gameplay projectiles to `rewind_started`, `rewind_completed`, or future player-snapshot restore signals.** Source: ADR-0011.
- **Never let culling/off-screen status alter gameplay schedules, projectile movement, AI clocks, or lethal behavior.** Source: ADR-0011.
- **Never iterate active projectile order through unordered dictionaries or sets.** Source: ADR-0011.

### Performance Guardrails

- **Stage preflight must validate projectile/Area2D budgets and duplicate IDs before combat begins.** Source: ADR-0011.
- **Boss Pattern reserves up to 21 Area2D-relevant nodes; total stage active Area2D budget remains 80.** Source: ADR-0011.
- **Per-frame feature logic should operate over stable arrays/pools; sorting is limited to spawn activation and same-frame insertion lists.** Source: ADR-0011.

---

## Presentation Layer Rules

*Applies to: rendering, collage, rewind shader, HUD, menu focus, audio, VFX,
camera presentation, story intro, particles, and animation presentation.*

### Required Patterns

- **Presentation observers (Camera, HUD, VFX, Audio, Story Intro, Menu/Pause UI) may consume approved signals/read-only APIs and cache local presentation state, but cannot mutate gameplay authority.** Source: ADR-0005.
- **`AudioManager` owns sound playback, bus layout validation, Music/SFX/UI player routing, rewind Music ducking, and runtime bus values; gameplay systems emit approved signals or call explicitly allowed audio facades only.** Source: ADR-0005, ADR-0006, ADR-0012.
- **Project audio buses must be exactly `Master`, `Music`, `SFX`, and `UI`; AudioManager must assert the layout before subscribing signals or creating players.** Source: ADR-0012.
- **AudioManager creates exactly one Music player, one UI player, and an 8-slot SFX pool assigned to the expected buses.** Source: ADR-0012.
- **Menu/Pause may use `AudioManager.set_session_bus_volume(bus_name, linear_value)` and `AudioManager.get_session_bus_volume(bus_name)` for session-only volume sliders; persistence remains future `SettingsManager` work.** Source: ADR-0006, ADR-0012.
- **Menu/Pause owns focusable Control surfaces while paused; HUD remains non-focusable combat display; Story Intro remains passive text.** Source: ADR-0007.
- **Opening Pause must focus `Resume` within `<= 2` frames; opening Options must focus `Master Volume` within `<= 2` frames.** Source: ADR-0007.
- **Godot 4.6 keyboard/gamepad vs mouse/touch focus divergence must be repaired on the next controller navigation event within `<= 1` frame.** Source: ADR-0007; Godot current best practices.
- **Story Intro displays five passive lines, adds no InputMap action, reads no bindings, and emits no gameplay event.** Source: ADR-0007.
- **Collage Rendering owns a stage-local `CollageRoot: Node2D` under the current Stage scene.** Source: ADR-0010.
- **`CollageRoot` must contain exactly three world-space child layers: `BasePhotoLayer`, `LineArtStructureLayer`, and `CollageDetailLayer`.** Source: ADR-0010.
- **Collage layers use `Sprite2D`, `TileMapLayer`, atlas `Sprite2D` pieces, and `Line2D` only when needed.** Source: ADR-0010; Godot deprecated APIs.
- **Collage layers move as ordinary world-space content under Camera; Tier 1 forbids independent camera-relative offsets and time-based layer drift.** Source: ADR-0010.
- **Time Rewind Visual Shader owns a separate fullscreen `CanvasLayer` / `ColorRect` CanvasItem shader through `RewindShaderController`.** Source: ADR-0010.
- **The rewind shader subscribes normally only to `rewind_started(remaining_tokens: int)`, runs a 30-frame local timeline, and has visible material intensity zero for all frames `f >= 19`.** Source: ADR-0010.
- **Shader #16 may read Collage groups/metadata but must not mutate `CollageRoot`, move layers, edit gameplay nodes, or make gameplay decisions.** Source: ADR-0010.
- **On `scene_will_change()`, Collage clears only Collage-owned registries/strong references and lets scene unload free stage-local nodes.** Source: ADR-0010.
- **Use `TextureFilter.NEAREST` for line-art/UI-like cutouts/atlas fragments; use authored texture policy for photo fragments/backgrounds.** Source: ADR-0010.

### Forbidden Approaches

- **Never let presentation observers grant/consume tokens, call foreign state transitions, write gameplay state, change scenes directly, add gameplay hit checks, or reorder gameplay events.** Source: ADR-0005.
- **Never let gameplay systems control raw audio buses or bypass `AudioManager` for sound playback.** Source: ADR-0005, ADR-0012.
- **Never let `AudioManager` implement `_physics_process` / `_process`, mutate gameplay state, poll gameplay state, or occupy a deterministic physics-priority slot.** Source: ADR-0012.
- **Never let `AudioManager` or Menu/Pause write `ConfigFile`, `FileAccess`, `DirAccess`, `ResourceSaver`, save-oriented `JSON.stringify`, or `user://` output for Tier 1 audio/session sliders.** Source: ADR-0006, ADR-0012.
- **Never let Menu/Pause implement a second pause listener or direct pause policy bypass.** Source: ADR-0007.
- **Never add press-any-key, Start/Continue, or skip-intro input gates to Story Intro in Tier 1.** Source: ADR-0007.
- **Never use deprecated `TileMap`; use `TileMapLayer`.** Source: ADR-0010; Godot deprecated APIs.
- **Never use `Parallax2D`, per-layer wobble, independent camera-relative offsets, or time-based layer drift for Tier 1 collage.** Source: ADR-0010.
- **Never use a manual multi-Viewport shader chain, full custom renderer/RenderingDevice pipeline, all-procedural/random collage placement, or local-VFX-only replacement for the required fullscreen rewind signature in Tier 1.** Source: ADR-0010.
- **Never require shader ordering that hides gameplay-critical ECHO/bullet/hazard silhouettes.** Source: ADR-0010.
- **Never introduce global multi-stage texture cache/release work before a Tier 2 ADR.** Source: ADR-0010.

### Performance Guardrails

- **Collage layers**: `<= 80` draw calls. Source: ADR-0010.
- **Fullscreen rewind shader**: pass-equivalent allocation `<= 50` draw calls and active GPU time target `<= 500 µs`; reduce UV glitch or use fallback before sacrificing readability/performance. Source: ADR-0010.
- **Whole project rendering**: `<= 500` draw calls and 16.6 ms/frame. Source: technical preferences, ADR-0010.
- **Texture memory**: Collage photo textures `<= 60 MB`; total stage collage texture target `<= 80 MB`; total resident ceiling remains 1.5 GB. Source: ADR-0010, technical preferences.
- **Readability**: 1080p and Steam Deck 720p 0.2-second readability captures must pass during normal combat and rewind frames 1-18. Source: ADR-0010.

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example | Source |
|---|---|---|---|
| Classes | PascalCase | `PlayerController` | technical-preferences.md |
| Variables / functions | snake_case | `move_speed`, `take_damage()` | technical-preferences.md |
| Signals | snake_case past tense | `health_changed`, `rewind_consumed` | technical-preferences.md |
| Files | snake_case matching class | `player_controller.gd` | technical-preferences.md |
| Scenes | PascalCase matching root node | `PlayerController.tscn` | technical-preferences.md |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `REWIND_WINDOW_SECONDS` | technical-preferences.md |

### Performance Budgets

| Target | Value | Source |
|---|---|---|
| Framerate | 60 fps locked | technical-preferences.md |
| Frame budget | 16.6 ms total | technical-preferences.md |
| Suggested split | gameplay+physics 6 ms / rendering 7 ms / time-rewind <= 1 ms / headroom 2.6 ms | technical-preferences.md |
| Draw calls | <= 500 per frame | technical-preferences.md |
| Memory ceiling | 1.5 GB resident | technical-preferences.md |
| Target platform | PC Steam / Steam Deck-friendly | technical-preferences.md |

### Approved Libraries / Addons

- None approved yet. Do not add dependencies speculatively. Source: technical-preferences.md.

### Required Engine Practices

- **Use statically typed GDScript.** Source: technical-preferences.md.
- **Use Godot Physics 2D for Echo; Jolt's Godot 4.6 default applies to 3D only and is unused here.** Source: technical-preferences.md; Godot current best practices.
- **Use `duplicate_deep()` when nested resources require true per-instance deep copies; Tier 1 `PlayerSnapshot` avoids nested resources.** Source: Godot current best practices, ADR-0002.
- **Account for Godot 4.6 D3D12 default on Windows, glow-before-tonemapping behavior, and shader texture type changes when validating rendering.** Source: Godot current best practices, ADR-0010.
- **Use `rg --glob "*.gd"` for GDScript shell searches; `rg --type gdscript` is invalid.** Source: Godot current best practices.

### Forbidden APIs and Deprecated Patterns (Godot 4.6)

| Forbidden / deprecated | Use instead | Since | Source |
|---|---|---:|---|
| `TileMap` | `TileMapLayer` | 4.3 | deprecated-apis.md |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 | deprecated-apis.md |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 | deprecated-apis.md |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 | deprecated-apis.md |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 | deprecated-apis.md |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 | deprecated-apis.md |
| `yield()` | `await signal` | 4.0 | deprecated-apis.md |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 | deprecated-apis.md, ADR-0005 |
| `instance()` / `PackedScene.instance()` | `instantiate()` / `PackedScene.instantiate()` | 4.0 | deprecated-apis.md |
| `get_world()` | `get_world_3d()` | 4.0 | deprecated-apis.md |
| `OS.get_ticks_msec()` for gameplay timing | `Engine.get_physics_frames()` for gameplay clocks | 4.0 | deprecated-apis.md, ADR-0003 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 | deprecated-apis.md |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 | deprecated-apis.md, ADR-0008 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 | deprecated-apis.md |
| `$NodePath` lookup in `_process()` | cached `@onready var` reference | n/a | deprecated-apis.md |
| untyped `Array` / `Dictionary` | `Array[Type]`, typed variables | n/a | deprecated-apis.md |
| `Texture2D` shader parameter assumptions | `Texture` base type | 4.4 | deprecated-apis.md, ADR-0010 |
| manual post-process viewport chains | `Compositor` + `CompositorEffect` for future advanced post-processing, or ADR-0010 simple CanvasItem path for Tier 1 | n/a | deprecated-apis.md, ADR-0010 |
| GodotPhysics3D for new 3D projects | Jolt Physics 3D | 4.6 | deprecated-apis.md |

### Cross-Cutting Constraints

- **Single writer, many observers**: every gameplay state field has one owner; other systems use signals or read-only APIs. Source: ADR-0005, ADR-0008, architecture.md.
- **Presentation is not gameplay authority**: HUD/VFX/Audio/Camera/shaders/UI must not mutate simulation state. Source: ADR-0005, ADR-0010, ADR-0012.
- **Physics-frame determinism**: gameplay clocks, schedules, and tests use physics-frame counters and stable ordering. Source: ADR-0003, ADR-0011.
- **No hidden expansion**: Tier 1 excludes persistence, remapping, localization, advanced accessibility, audio middleware, global event buses, world rewind, and multi-stage texture cache unless a future ADR explicitly accepts them. Source: ADR-0001, ADR-0005, ADR-0006, ADR-0010, ADR-0012.
- **Every implementation story that touches Godot 4.6 behavior must cite the relevant ADR and include fresh fixture/static-check evidence before completion.** Source: ADR Engine Compatibility sections.
