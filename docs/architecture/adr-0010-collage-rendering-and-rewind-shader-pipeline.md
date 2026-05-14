# ADR-0010: Collage Rendering and Rewind Shader Pipeline

## Status
Accepted (ratified 2026-05-14)

## Date
2026-05-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering / 2D CanvasItem / Presentation |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff and rendering changed in 4.4–4.6. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/rendering.md`, `docs/engine-reference/godot/modules/ui.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md`, `.claude/docs/technical-preferences.md`, `design/art/art-bible.md`, `design/gdd/collage-rendering.md`, `design/gdd/time-rewind-visual-shader.md`, `design/gdd/vfx-particle.md`, `design/gdd/camera.md`, `design/gdd/hud.md`, `design/gdd/stage-encounter.md`, `design/gdd/time-rewind.md`, `design/gdd/game-concept.md` |
| **Post-Cutoff APIs Used** | No new 4.5/4.6-only API is required for Tier 1. This decision depends on verified Godot 4.6 rendering behavior for `CanvasLayer`, `ColorRect`, `CanvasItem` shaders, `Sprite2D`, `TileMapLayer`, `TextureFilter.NEAREST`, `TextureFilter.LINEAR`, and typed signals. It must account for 4.6 D3D12 default on Windows, glow-before-tonemapping behavior, 4.5 Shader Baker availability, and 4.4 shader texture type changes (`Texture`, not `Texture2D`, for shader parameter assumptions). |
| **Verification Required** | (1) D3D12 / Forward+ capture on Windows or Steam Deck-equivalent target proves the shader looks correct and stays within budget. (2) 1080p and Steam Deck 720p 0.2-second readability captures pass during normal combat and frames 1–18 of rewind. (3) Active rewind shader GPU time is ≤500 µs per active frame or the inversion-only fallback is used. (4) Whole-frame draw calls remain ≤500; Collage layers remain ≤80 draw calls; fullscreen shader pass-equivalent remains ≤50. (5) Collage texture estimates remain ≤60 MB photo textures and ≤80 MB total stage texture target. (6) Static scene audit proves `TileMapLayer` is used instead of deprecated `TileMap`, no manual multi-Viewport shader chain is used, and no gameplay signal/state write originates from Collage or Shader systems. |

> Engine validation note: primary engine specialist from `.claude/docs/technical-preferences.md` is `godot-specialist`. In this Codex adapter run, no subagent was spawned because the repository adapter limits `Task`/subagent use to explicit user-requested delegation. The draft was validated locally against the pinned Godot 4.6 reference files listed above. The high-risk engine points are D3D12 capture parity, shader texture typing, and avoiding manual viewport-chain post-processing.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Time Rewind Scope; ADR-0003 Determinism Strategy; ADR-0004 Scene Lifecycle and Checkpoint Restart Architecture; ADR-0005 Cross-System Signal Architecture and Event Ordering. ADR-0004 and ADR-0005 must be Accepted before production stories rely on scene unload or signal wiring from this ADR. |
| **Enables** | Collage Rendering #15 implementation, Time Rewind Visual Shader #16 implementation, VFX #14 rewind coordination, Stage #12 `CollageRoot` scene authoring, QA/performance capture stories, and asset-spec work for Tier 1 visual production. |
| **Blocks** | Any production story that creates `CollageRoot`, implements the fullscreen rewind shader/controller, changes rewind visual timing, introduces a rendering post-process chain, adds multi-stage collage texture caching, or changes collage metadata/group names. |
| **Ordering Note** | Implement after ADR-0004/0005 are accepted for `scene_will_change()` and `rewind_started` wiring. Tier 2 multi-stage texture cache/release work remains blocked on a future ADR; this ADR only permits Tier 1 single-stage local scene ownership. |

## Context

### Problem Statement

Echo's visual signature depends on two tightly coupled rendering decisions:

1. how static/semi-static collage stage art is authored in Godot 4.6 without harming combat readability or performance; and
2. how the time-rewind fullscreen signature overlays that collage without hiding bullets, ECHO, hazards, boss silhouettes, HUD, or the post-restore i-frame shape signal.

The architecture review found `TR-concept-005`, `TR-collage-001`, and `TR-shader-001` had no ADR. Without this decision, implementation could drift into incompatible approaches: viewport-chain post-processing, shader-owned gameplay cues, unbounded collage fragments, parallax/wobble layers that fight Camera #3, or texture cache work that exceeds Tier 1 scope.

### Constraints

- Godot 4.6 / Forward+ / PC Steam target; Windows defaults to D3D12.
- 60 fps locked, 16.6 ms frame budget, ≤500 whole-frame draw calls, 1.5 GB resident memory ceiling.
- Steam Deck-friendly 720p readability is a target, not optional.
- Collage must satisfy the 0.2-second gameplay readability test.
- Rewind visual activation must be recognizable within 0.5 seconds.
- ADR-0001 says only ECHO rewinds; enemies, projectiles, environment, particles, and camera state do not rewind.
- HUD stays screen-space and observer-only; Collage and Shader systems must not own UI widgets or gameplay state.
- Tier 1 uses one stage. Multi-stage texture cache/release and async loading are explicitly deferred.

### Requirements

- Provide a deterministic, authorable `CollageRoot` scene structure for the Tier 1 rooftop stage.
- Use engine-supported 2D nodes and CanvasItem rendering only: no custom renderer, GDExtension, `RenderingDevice` draw lists, or manual multi-Viewport shader chain.
- Use `TileMapLayer`, not deprecated `TileMap`.
- Preserve Collage #15's three-layer contract: base photo, line-art/structure, collage detail.
- Keep all Collage layers in world space moving uniformly under Camera #3; no runtime parallax/wobble in Tier 1.
- Expose stable metadata/groups for Shader #16 and QA tooling.
- Drive the fullscreen rewind shader from `rewind_started(remaining_tokens: int)`, not from `rewind_completed`.
- Make fullscreen shader visible only on frames 0–18; frames 19–30 are reserved for ECHO i-frame shape readability.
- Reduce decorative glitch first when readability or performance fails.
- Keep Tier 2 multi-stage texture management behind a future ADR.

## Decision

Use a **split presentation pipeline**:

1. **Collage Rendering #15** owns a stage-local `CollageRoot: Node2D` under the current Stage scene.
2. `CollageRoot` has exactly three world-space child layers:
   - `BasePhotoLayer`
   - `LineArtStructureLayer`
   - `CollageDetailLayer`
3. Collage layers are authored with `Sprite2D`, `TileMapLayer`, atlas `Sprite2D` pieces, and `Line2D` only when needed.
4. Collage layers move as ordinary world-space content under Camera #3. Tier 1 forbids `Parallax2D`, independent camera-relative offsets, per-layer wobble, and time-based layer drift.
5. **Time Rewind Visual Shader #16** owns a separate fullscreen `CanvasLayer` / `ColorRect` CanvasItem shader overlay, implemented through a `RewindShaderController`.
6. The fullscreen shader subscribes only to `rewind_started(remaining_tokens: int)` as its normal runtime trigger. It does not terminate from `rewind_completed(player, restored_to_frame)`.
7. The shader controller runs a 30-frame protection-aligned local timeline, but the visible fullscreen material intensity is zero for all frames `f >= 19`.
8. ECHO/bullets may be kept readable above the fullscreen shader if the Time Rewind #9 CanvasLayer mitigation is used; Shader #16 must not require an order that hides gameplay-critical silhouettes.
9. Collage #15 provides metadata/groups that Shader #16 and QA may read, but Shader #16 must not mutate `CollageRoot`, move layers, edit gameplay nodes, or make gameplay decisions.
10. Tier 1 scene unload relies on stage-local ownership: on `scene_will_change()`, Collage clears only Collage-owned registries/strong references and allows scene unload to free nodes. No global ResourceLoader cache-release strategy is introduced until a Tier 2 ADR.

### Architecture Diagram

```text
StageRoot (current gameplay scene)
├── CollageRoot (Node2D, stage-local, Collage #15 owns)
│   ├── BasePhotoLayer (Sprite2D / static strip groups)
│   ├── LineArtStructureLayer (TileMapLayer / Sprite2D atlas / Line2D)
│   └── CollageDetailLayer (Sprite2D atlas fragments)
├── GameplayRoot
│   ├── PlayerMovement / ECHO
│   ├── Enemies / Boss
│   ├── Projectiles
│   └── VFX anchors
└── Stage metadata / checkpoints / camera limits

Presentation overlays
├── RewindShaderCanvasLayer
│   └── RewindShaderRect (ColorRect + CanvasItem shader)
├── HUD CanvasLayer
└── Debug/performance overlays (debug-only)

Signal flow
TimeRewindController.rewind_started(remaining_tokens)
  └── RewindShaderController.start_timeline(F_start)

SceneManager.scene_will_change()
  └── CollageRuntimeRegistry.clear_local_refs()
```

### Key Interfaces

#### Stage scene contract

```text
StageRoot
  CollageRoot: Node2D
    BasePhotoLayer: Node2D
    LineArtStructureLayer: Node2D
    CollageDetailLayer: Node2D
```

#### Collage groups / metadata

```gdscript
# Groups applied to authored collage nodes.
&"collage_base_photo"       # base photo sprites eligible for global inversion
&"collage_line_structure"   # platforms/hazard outlines; preserve readability
&"collage_detail_fragment"  # decorative ads/paper/typography

# Optional metadata on safe decorative fragments.
node.set_meta(&"rewind_glitch_eligible", true)
```

Defaults:

- `rewind_glitch_eligible` is false unless explicitly authored.
- Gameplay-critical silhouettes and traversal cues must not require the metadata for readability.
- Shader #16 may read groups/metadata but may not change node ownership, layer positions, collision, z-order, or gameplay state.

#### Rewind shader controller

```gdscript
class_name RewindShaderController
extends CanvasLayer

@onready var _rect: ColorRect = %RewindShaderRect

var _active: bool = false
var _start_physics_frame: int = -1

func _ready() -> void:
    # Connected using Callable-style typed signals by composition root.
    # trc.rewind_started.connect(_on_rewind_started)
    visible = false

func _on_rewind_started(remaining_tokens: int) -> void:
    if _active:
        push_warning("Duplicate rewind_started received while shader timeline is active.")
        return
    _active = true
    _start_physics_frame = Engine.get_physics_frames()
    visible = true

func _physics_process(_delta: float) -> void:
    if not _active:
        return
    var f: int = Engine.get_physics_frames() - _start_physics_frame
    _apply_shader_frame(f)
    if f >= 30:
        _active = false
        visible = false

func _apply_shader_frame(f: int) -> void:
    var intensity: float = _intensity_for_frame(f)
    _rect.material.set_shader_parameter(&"rewind_intensity", intensity)
    _rect.visible = intensity > 0.0

func _intensity_for_frame(f: int) -> float:
    if f == 0:
        return 0.30
    if f >= 1 and f <= 3:
        return 1.0
    if f >= 4 and f <= 8:
        return 0.75
    if f >= 9 and f <= 18:
        return float(18 - f) / 9.0
    return 0.0
```

#### Import / texture policy

| Asset class | Rule |
|-------------|------|
| Line-art, UI-like cutouts, atlas fragments | `TextureFilter.NEAREST` |
| Photo fragments / base photography | `TextureFilter.LINEAR` |
| Collage atlas | 512×512 target for Tier 1 |
| Single photo fragment | 256×256 or smaller |
| Wide background strip | 1920×360 per layer target |

#### Forbidden implementation paths

- `TileMap` for new stage layers; use `TileMapLayer`.
- Manual multi-Viewport shader chains for the rewind effect.
- Custom `RenderingDevice` draw-list renderer for Tier 1 collage.
- Runtime-random collage placement.
- Per-layer camera wobble, runtime parallax, or independent screen-space offsets.
- Shader-controlled gameplay state, collision, damage, token, camera, or HUD mutations.
- Terminating the rewind fullscreen effect from `rewind_completed`.
- Extending visible fullscreen shader intensity into frames 19–30.
- Global texture cache/release logic for Tier 1 single-stage collage.

## Alternatives Considered

### Alternative 1: Stage-local CollageRoot + fullscreen ColorRect CanvasItem shader (Selected)

- **Description**: Author collage as normal 2D scene content under `CollageRoot`; run rewind as a separate fullscreen CanvasLayer/ColorRect CanvasItem shader with strict timeline and fallback rules.
- **Pros**: Matches GDDs, minimizes engine complexity, keeps art authorable by a solo developer, isolates gameplay from presentation, avoids manual viewport chains, supports D3D12-safe validation, and preserves fallback to inversion-only if UV glitch fails.
- **Cons**: Less powerful than a full post-processing stack; per-fragment glitch is limited unless future tooling is added.
- **Selection Reason**: Best fit for Tier 1 scope, readability, performance, and Godot 4.6 risk containment.

### Alternative 2: Manual multi-Viewport post-process chain

- **Description**: Render gameplay/collage into one or more Viewports, apply custom post-process materials, then composite into the final screen.
- **Pros**: More control over layer-specific shader passes and compositing.
- **Cons**: Explicitly rejected by Collage #15 and Shader #16; fragile in Godot 4.6; increases render-target memory; complicates HUD/gameplay layer ordering; raises D3D12 parity risk.
- **Rejection Reason**: Too much engine risk and implementation burden for Tier 1; violates the local engine reference caution against manual viewport shader chains for post-processing.

### Alternative 3: Full custom renderer / RenderingDevice pipeline

- **Description**: Build a custom rendering path or GDExtension/RenderingDevice draw-list solution for collage and rewind.
- **Pros**: Maximum control and potential future optimization.
- **Cons**: Outside solo Tier 1 scope, high Godot 4.6 API risk, unnecessary for static 2D collage, and likely to consume the entire prototype budget.
- **Rejection Reason**: Violates Pillar 5 small-success scope and is not required by any Tier 1 GDD requirement.

### Alternative 4: All-shader collage with procedural/random placement

- **Description**: Generate collage fragments through shader/noise/procedural placement rather than authored scene nodes.
- **Pros**: Potentially dynamic and visually rich.
- **Cons**: Breaks deterministic authored readability, makes screenshots less intentional, complicates QA, and creates risk that visual randomness hides threats.
- **Rejection Reason**: Contradicts Clarity-First Collage and the 0.2-second glance gate.

### Alternative 5: No fullscreen shader; local VFX only

- **Description**: Represent rewind using only local ECHO/VFX particles and HUD/audio cues.
- **Pros**: Lowest GPU cost.
- **Cons**: Fails Game Concept, Art Bible Principle C, and Shader #16 requirement that rewind be visually recognizable within 0.5 seconds from screen visuals alone.
- **Rejection Reason**: Does not satisfy the player-facing rewind identity requirement.

## Consequences

### Positive

- Establishes a concrete Godot 4.6 rendering path for the last major presentation ADR gap.
- Keeps Collage, Shader, VFX, Camera, HUD, and gameplay ownership boundaries separate.
- Provides a safe Tier 1 fallback: inversion + palette restoration if UV glitch misses performance or readability budgets.
- Makes QA/static checks possible through stable scene names, groups, metadata, and budgets.
- Avoids deprecated `TileMap` and avoids manual multi-Viewport shader-chain complexity.
- Preserves the visual identity promise without turning presentation into gameplay authority.

### Negative

- Tier 1 will not have advanced per-fragment post-processing unless it fits inside the simple CanvasItem shader/controller model.
- Multi-stage texture cache/release remains unsolved until a future ADR.
- D3D12/Steam Deck capture is mandatory before sign-off; editor-only Vulkan/macOS captures are insufficient.
- Authoring discipline is required: fragments must be placed and tagged correctly, not generated freely.

### Risks

- **R1: Rewind shader hides bullets or hazards.** Mitigation: shader intensity reaches 0 by frame 19; if frames 1–18 fail readability, reduce UV glitch first and preserve inversion/timing.
- **R2: D3D12 output differs from editor captures.** Mitigation: D3D12/Forward+ target capture is required; backend-specific shader assumptions are banned.
- **R3: Collage draw-call pressure exceeds the 500-call frame budget.** Mitigation: Collage capped at 80 draw calls; reduce decorative Layer 3 fragments before gameplay outlines/VFX/HUD clarity.
- **R4: Texture memory creeps through photo fragments.** Mitigation: photo textures capped at 60 MB; total stage collage target capped at 80 MB; warn at 75% of 1.5 GB resident ceiling.
- **R5: Per-layer wobble/parallax undermines camera shake readability.** Mitigation: Tier 1 forbids `Parallax2D` and independent offsets for `CollageRoot`.
- **R6: Shader timeline drifts from Time Rewind protection timing.** Mitigation: use `Engine.get_physics_frames()` and debug-compare against `rewind_protection_ended`; do not drive normal termination from that signal.
- **R7: Stage scenes use stale Godot APIs.** Mitigation: static scan for deprecated `TileMap`, string-based `connect`, and manual viewport-chain patterns before story completion.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/game-concept.md` | Pillar 3: collage is first impression; `TR-concept-005` requires collage visual signature to survive clarity/performance constraints. | Locks a stage-local authored collage pipeline, 0.2-second readability gates, and budgets rather than ad-hoc rendering. |
| `design/art/art-bible.md` | Principle A clarity-first collage, Principle B photo + drawing together, Principle C time rewind color inversion + glitch. | Preserves three-layer collage, fullscreen rewind inversion/glitch, and shape/readability priority over color-only cues. |
| `design/gdd/collage-rendering.md` | `CollageRoot` three-layer contract, fragment cap 30, draw-call budget 80, photo texture budget 60 MB, total stage texture target 80 MB, metadata for Shader #16. | Makes `CollageRoot`, layer names, metadata groups, import rules, and budgets architectural implementation constraints. |
| `design/gdd/time-rewind-visual-shader.md` | Fullscreen rewind signature starts from `rewind_started`, remains visible only frames 0–18, costs ≤500 µs active GPU time, and must not hide gameplay. | Defines `RewindShaderController`, CanvasLayer/ColorRect shader path, timeline, fallback, and validation requirements. |
| `design/gdd/time-rewind.md` | Rewind visual feedback must align with `REWIND_SIGNATURE_FRAMES = 30` while gameplay restoration remains Time Rewind/Player owned. | Keeps shader protection-aligned but presentation-only; no token/state/restore ownership. |
| `design/gdd/vfx-particle.md` | VFX owns local particle bursts; shader owns fullscreen inversion/glitch; reduce decorative shader before gameplay telegraph VFX. | Splits local VFX from fullscreen shader and sets budget/readability priority. |
| `design/gdd/camera.md` | Collage layers must move uniformly under Camera #3; camera state is not in PlayerSnapshot. | Forbids layer parallax/wobble and keeps fullscreen pass viewport-space. |
| `design/gdd/hud.md` | HUD is observer-only CanvasLayer and must remain readable in 0.2 seconds. | Keeps HUD separate from `CollageRoot`; collage fragments near HUD-safe areas must be moved/desaturated if glance test fails. |
| `design/gdd/stage-encounter.md` | Stage owns authored room composition and validates scene contracts. | Adds the StageRoot `CollageRoot` hierarchy as a scene authoring/preflight contract for Tier 1. |

## Performance Implications

- **CPU**: Collage is static/semi-static scene content with no per-frame gameplay logic. Shader controller performs one frame-index calculation and material parameter update per active frame only.
- **GPU / Draw Calls**: Collage layer allocation is ≤80 draw calls; fullscreen shader pass-equivalent allocation is ≤50; whole project remains ≤500 draw calls and 16.6 ms/frame. Active shader GPU time target is ≤500 µs; UV glitch falls back before timing or recognition are compromised.
- **Memory**: Collage photo textures ≤60 MB; total stage collage texture target ≤80 MB; project resident ceiling remains 1.5 GB. Tier 1 does not introduce global texture-cache management.
- **Load Time**: Tier 1 uses one authored stage and normal scene loading. Shader Baker is not required for the simple Tier 1 shader; if future variants cause hitches, Shader Baker adoption must be validated before expanding variants.
- **Network**: None; Echo Tier 1 is local single-player.

## Migration Plan

1. Add/verify Stage #12 scene preflight for `CollageRoot`, `BasePhotoLayer`, `LineArtStructureLayer`, and `CollageDetailLayer`.
2. Add Collage metadata groups to authored nodes and default `rewind_glitch_eligible` to false.
3. Implement `RewindShaderController` as a presentation CanvasLayer with `RewindShaderRect: ColorRect`.
4. Wire `TimeRewindController.rewind_started` to `RewindShaderController._on_rewind_started` using Callable-style typed signal connection.
5. Add static checks for deprecated `TileMap`, manual viewport chains, and forbidden shader/collage gameplay writes.
6. Add visual/performance capture tasks for 1080p, Steam Deck 720p, active rewind frames 1–18, D3D12/Forward+ target, draw calls, and GPU time.
7. Defer any multi-stage texture cache/release or async loading implementation until a future ADR is written.

## Validation Criteria

- `CollageRoot` hierarchy exists exactly once in Tier 1 stage scenes.
- Collage groups/metadata exist and match this ADR.
- No Tier 1 `CollageRoot` child uses runtime parallax or independent camera-relative offsets.
- No deprecated `TileMap` use appears in production stage scenes or scripts.
- `RewindShaderController` starts only from `rewind_started`.
- `rewind_completed` does not terminate or restart the shader.
- Visible fullscreen shader intensity is zero by local frame 19.
- 1080p and 720p Steam Deck captures pass the 0.2-second readability gate during normal gameplay and active rewind.
- Rewind activation is recognizable from visuals alone within 0.5 seconds.
- Active shader GPU time is ≤500 µs per active frame or inversion-only fallback is used.
- Collage draw calls ≤80, shader pass-equivalent ≤50, whole-frame draw calls ≤500.
- Collage photo textures ≤60 MB and total stage collage texture target ≤80 MB unless an explicit exception review exists.
- Repeated checkpoint restart/scene reload soak does not retain Collage-owned strong references after `scene_will_change()`.

## Registry Candidates

The following candidates should be reviewed before any explicit registry write:

- **NEW interface contract candidate**: `collage_stage_scene_contract` → `StageRoot/CollageRoot` with exactly `BasePhotoLayer`, `LineArtStructureLayer`, and `CollageDetailLayer`.
- **NEW interface contract candidate**: `collage_shader_metadata` → groups `collage_base_photo`, `collage_line_structure`, `collage_detail_fragment`, and optional metadata `rewind_glitch_eligible`.
- **NEW interface contract candidate**: `rewind_shader_controller` → triggered by `rewind_started(remaining_tokens: int)`, local 30-frame timeline, visible intensity zero for frames `>= 19`.
- **EXISTING referenced_by update**: `interfaces.rewind_lifecycle` → add ADR-0010 as Shader #16 runtime consumer authority.
- **NEW performance budget candidate**: `collage_rendering_budget` → collage ≤80 draw calls, photo textures ≤60 MB, total stage collage textures ≤80 MB.
- **NEW performance budget candidate**: `rewind_shader_budget` → active GPU time ≤500 µs and pass-equivalent ≤50 draw calls.
- **NEW API decision candidate**: `tier1_collage_rendering_pipeline` → authored `Node2D` + `Sprite2D` + `TileMapLayer`/atlas pieces; no custom renderer.
- **NEW API decision candidate**: `tier1_rewind_shader_surface` → fullscreen `CanvasLayer` / `ColorRect` CanvasItem shader; no manual multi-Viewport chain.
- **NEW forbidden pattern candidate**: `collage_runtime_parallax_or_wobble` → no Tier 1 `Parallax2D`, independent layer offset, or time-based layer drift under `CollageRoot`.
- **NEW forbidden pattern candidate**: `manual_viewport_rewind_postprocess_chain` → no manual multi-Viewport shader chain for Tier 1 rewind effect.
- **NEW forbidden pattern candidate**: `shader_or_collage_gameplay_authority` → Collage/Shader systems may not mutate tokens, damage, collision, camera state, HUD state, or gameplay transforms.
- **NEW forbidden pattern candidate**: `rewind_shader_completed_driven_termination` → `rewind_completed` must not terminate/restart Shader #16.
- **NEW forbidden pattern candidate**: `tier1_global_collage_texture_cache_release` → Tier 1 single-stage Collage must not add global ResourceLoader cache/release logic; future multi-stage work requires a new ADR.

`docs/registry/architecture.yaml` was not modified by this ADR authoring pass because registry writes require explicit user approval.

## Related Decisions

- ADR-0001: Time Rewind Scope — Player-Only Checkpoint Model
- ADR-0002: Time Rewind Storage Format — State Snapshot Ring Buffer
- ADR-0003: Determinism Strategy — CharacterBody2D + Direct Transform / Area2D Projectiles
- ADR-0004: Scene Lifecycle and Checkpoint Restart Architecture
- ADR-0005: Cross-System Signal Architecture and Event Ordering
- `design/gdd/collage-rendering.md`
- `design/gdd/time-rewind-visual-shader.md`
- `design/gdd/vfx-particle.md`
- `design/art/art-bible.md`
- `docs/engine-reference/godot/modules/rendering.md`
