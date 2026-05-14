# Collage Rendering Pipeline

> **System**: #15 Collage Rendering Pipeline  
> **Category**: Presentation  
> **Priority**: MVP (Tier 1)  
> **Status**: Approved · 2026-05-13  
> **Author**: technical-artist + godot-shader-specialist + game-designer  
> **Engine**: Godot 4.6 / Forward+ / 2D CanvasItem rendering  
> **Depends On**: Scene Manager #2, Art Bible, Camera #3, Stage / Encounter #12  
> **Consumed By**: Time Rewind Visual Shader #16, VFX / Particle #14, Stage / Encounter #12, QA/performance instrumentation

---

## A. Overview

The Collage Rendering Pipeline owns Echo's Tier 1 visual signature: every gameplay screen must read as **1990s magazine cutouts collaged over 2030s megacity photography** while still preserving the 0.2-second gameplay readability test. It defines how stage backgrounds, photo fragments, line-art overlays, magazine cutout details, and atlas/import settings are assembled in Godot 4.6 without exceeding the project's 60 fps, ≤500 draw-call, and 1.5 GB resident memory constraints.

This system is a rendering and asset-organization contract, not a gameplay system. It does not own enemy silhouettes, player sprites, hitboxes, VFX particles, full-screen rewind shader timing, camera movement, stage activation, or scene transitions. It owns the **static and semi-static stage collage composition** that those systems render against.

**Tier 1 scope**:

1. One rooftop stage collage composition.
2. Three-layer environment structure: base photo, mid line-art/gameplay structure, top collage detail.
3. Maximum 30 authored collage fragments for the Tier 1 stage.
4. Import settings and atlas rules for photo/cutout assets.
5. Draw-call and memory budgets for collage assets.
6. Readability rules for ECHO, enemies, bullets, hazards, boss silhouette, and HUD separation.
7. Scene boundary cleanup policy for Collage-owned strong references.
8. Handoff contracts for Time Rewind Visual Shader #16 and VFX #14.

**Tier 2+ deferred risk**: multi-stage texture cache release, async loading, and photo-source licensing require an ADR before Tier 2 entry. Tier 1 uses one stage and clears local references on scene transition; it does not depend on global cache manipulation.

---

## B. Player Fantasy

**"Every screenshot looks like a handmade sci-fi ransom note, but I never die because the art hid the bullet."**

The player should instantly recognize Echo as the collage sci-fi run-and-gun: concrete megacity photos, torn ads, ARCA/VEIL fragments, black pen lines, cyan rewind energy, and magenta threat signs. The collage should feel tactile and authored, not like a generic shader filter.

The pipeline supports three player-facing promises:

1. **Screenshot identity** — one still frame shows both photography and line/cutout drawing simultaneously.
2. **Combat clarity** — ECHO, enemies, bullets, hazards, and boss warnings remain readable in a 0.2-second glance.
3. **Solo-craftable spectacle** — the style comes from disciplined layer reuse, not unbounded bespoke art.

### Anti-Fantasy

| Rejected | Reason |
|---|---|
| Photoreal background without cutout/line layer | Loses Pillar 3; looks like generic realism. |
| Texture noise over gameplay silhouettes | Violates Art Bible Principle A and turns deaths into visual ambiguity. |
| Runtime-random collage placement | Violates deterministic readability and makes screenshots non-authorial. |
| Per-layer wobble/parallax during camera shake | Camera #3 and Art Bible confirm all collage layers must move uniformly under `camera.offset`. |
| Manual viewport shader chains for basic collage | Too fragile in Godot 4.6; Shader #16 owns full-screen post-process. |
| Unlimited photo fragments | Exceeds solo scope, draw-call budget, and memory ceiling. |

---

## C. Detailed Rules

### C.1 Layer Contract

Every Tier 1 gameplay stage with collage rendering uses a `CollageRoot: Node2D` under the stage root. `CollageRoot` contains exactly three authored layer classes:

| Layer | Purpose | Typical Godot nodes | Import / filter | Gameplay priority |
|---|---|---|---|---|
| **Layer 1 — Base Photo** | Megacity mass, atmosphere, broad value blocks | `Sprite2D`, static wide background-strip `Node2D` groups, large background sprites | Photo textures: LINEAR | Lowest; must not compete with threats. |
| **Layer 2 — Line-Art / Structure** | Platforms, readable rails, hazard silhouettes, architectural outlines | `TileMapLayer` / `Sprite2D` atlas pieces / `Line2D` if needed | Atlases: NEAREST | Highest environment readability. |
| **Layer 3 — Collage Detail** | ARCA/VEIL ads, magazine typography, torn paper, story fragments | `Sprite2D` atlas fragments | Atlases: NEAREST | Decorative/story; cannot hide gameplay. |

All three layers are world-space children. They move together under Camera #3. No Tier 1 layer may apply independent screen-space wobble, offset, or time-based parallax during camera shake.

Tier 1 must not use `Parallax2D` or independent camera-relative offsets for `CollageRoot` layers. Art Bible references to background depth mean authored wide strips and layer composition, not runtime differential motion.

### C.2 Stage Node Pattern

Tier 1 stage root must include:

```text
StageRoot
  CollageRoot
    BasePhotoLayer
    LineArtStructureLayer
    CollageDetailLayer
  GameplayRoot
  Projectiles
  VFXRoot
```

Rules:

1. `CollageRoot` is loaded and freed with the stage scene.
2. Gameplay nodes render above background collage and below HUD.
3. VFX #14 renders combat effects above gameplay sprites unless explicitly world-background.
4. HUD #13 remains `CanvasLayer` and is never a child of `CollageRoot`.
5. Collage Rendering does not emit gameplay signals.

### C.3 Fragment Budget

Tier 1 uses a hard authored cap:

```text
max_collage_fragments_per_stage = 30
```

A "fragment" is any independently placed torn paper, ad, typography, logo, graffiti, or photo cutout on Layer 3. A repeated tile in a tilemap is not counted as a fragment; a unique placed story/ad piece is counted.

Fragment density rules:

| Zone | Max fragment pressure | Notes |
|---|---:|---|
| Combat lane foreground | Low | Do not place detail behind bullets/enemy silhouettes unless contrast is proven. |
| Readable third around boss/hazards | Medium | May frame the boss, but cannot be the only read path. |
| Background skyline | High | Best place for story flavor and ads. |
| HUD-safe corners | Low | Avoid visual competition with HUD #13 upper-left token/ammo area. |

### C.4 Readability Rules

**Rule 1 — 0.2-second glance gate.**  
Every production collage room must pass the Art Bible test: at 1080p, ECHO, enemies, bullets, hazards, and the boss silhouette must be distinguishable from a screenshot shown for 0.2 seconds at real gameplay speed.

**Rule 2 — critical silhouette protection.**  
No photo texture or top collage detail may overlap a critical gameplay silhouette in a way that reduces its outline contrast below the Stage/Enemy/Boss readability target. If conflict occurs, lower collage detail opacity, move the fragment, or simplify the fragment.

**Rule 3 — readable-third placement.**  
Gameplay-critical collage hints — boss silhouette framing, jump-threat hazard read, rewind residue narrative cues — must not exist only outside the Camera #3 readable third (`viewport_width / 6 = ±213 px` at Tier 1 1280×720).

**Rule 4 — threat colors stay reserved.**  
Background collage may use magenta ads, but direct magenta threat highlights must remain shape-separated from enemy/boss projectile silhouettes. Cyan-dominant fragments must not masquerade as ECHO bullets or rewind UI.

**Rule 5 — pure white remains reserved.**  
Fully saturated white is reserved for the 1-frame death flash per Art Bible. Collage fragments may use dirty white/off-white paper, not pure `#FFFFFF`.

### C.5 Import and Texture Rules

| Asset class | Import rule | Reason |
|---|---|---|
| Line-art, UI-like cutouts, atlas fragments | `TextureFilter.NEAREST` | Preserves hard magazine/scissor edges. |
| Photo fragments / base photography | `TextureFilter.LINEAR` | Keeps photography from shimmering while scrolling. |
| Collage atlas | 512×512 target for Tier 1 | Fits Art Bible atlas plan and batching. |
| Single photo fragment | 256×256 or smaller | Prevents memory creep and keeps fragment authoring cheap. |
| Wide background strip | 1920×360 per layer target | Art Bible Tier 1 background budget. |

Godot 4.6 note: Windows defaults to D3D12. This GDD must not assume Vulkan-specific shader behavior or GPU timings. Shader Baker should be used later if Shader #16 introduces many variants; Collage #15 itself avoids shader-variant explosion.

### C.6 Rendering Implementation Rule

Tier 1 collage rendering uses authored 2D scene composition (`Node2D` + `Sprite2D` + `TileMapLayer`/atlas pieces). It does not require a custom renderer, GDExtension, manual `RenderingDevice` draw lists, or a chain of Viewports.

If a future feature needs full-screen post-processing, Time Rewind Visual Shader #16 owns that surface. Collage #15 provides layer metadata and compatible material organization only.

### C.7 Layer Metadata for Shader #16

Collage nodes may be tagged for downstream shader/readability tooling:

| Metadata / group | Applies to | Meaning |
|---|---|---|
| `collage_base_photo` | Base photo layer sprites | Eligible for global color inversion but not per-fragment gameplay logic. |
| `collage_line_structure` | Line art, platforms, hazard outlines | Must preserve contrast during rewind shader. |
| `collage_detail_fragment` | Ads, paper, typography | Eligible for glitch decomposition in Shader #16 if budget allows. |
| `rewind_glitch_eligible: bool` | Optional per fragment | Allows Shader #16 to pick decorative fragments for glitch; defaults false for gameplay-critical silhouettes. |

Collage #15 does not implement the rewind shader. It only ensures nodes are named/tagged consistently so Shader #16 can consume them without guessing.

### C.8 Scene Boundary Policy

On `scene_will_change()`:

1. Tier 1: clear Collage-owned registries and strong references; allow the stage scene unload to free `CollageRoot` nodes.
2. Tier 1: do not attempt global `ResourceLoader` cache manipulation.
3. Tier 2+ multi-stage: before loading more than one production stage in a session, write an ADR for explicit texture release/cache strategy and async loading.

This resolves Scene Manager #2's Collage #15 obligation for Tier 1 while preserving the Tier 2 memory-risk gate.

### C.9 Asset Source Rule

Q2 photo-source decision remains open at the project level. Until IP/license review resolves stock vs AI-generated vs original photography:

- Tier 1 design/prototype may use clearly marked placeholder grayscale photo textures.
- Production assets must have license metadata before release.
- No untracked internet image or copyrighted magazine scan may enter the production atlas.
- Each source photo/cutout needs an asset-spec record before final art lock.

### C.10 Ownership Boundaries

| Surface | Owner | Collage #15 role |
|---|---|---|
| ECHO/enemy/boss sprites | Player Movement / Enemy AI / Boss Pattern / Art Bible | Provide background contrast only. |
| Projectile/VFX particles | VFX #14 | Reserve visual headroom and avoid background confusion. |
| Full-screen rewind color inversion/glitch | Shader #16 | Provide layer metadata and avoid incompatible material assumptions. |
| Camera shake/follow/zoom | Camera #3 | Keep world-space layers moving uniformly; no independent wobble. |
| Stage activation/spawn order | Stage #12 | Consume stage root placement; no gameplay lifecycle authority. |
| Scene load/unload | Scene Manager #2 | Clear local references on boundary; no scene swap calls. |
| HUD/readouts | HUD #13 | Avoid HUD-safe areas; no UI widgets. |

---

## D. Formulas

### D.1 Fragment Cap

```text
collage_fragment_count(stage) <= max_collage_fragments_per_stage
max_collage_fragments_per_stage = 30
```

Fragments above the cap must be merged into an atlas/tile, deleted, or deferred to Tier 2.

### D.2 Draw-Call Estimate

```text
collage_draw_call_estimate =
  base_photo_draw_calls
  + line_structure_draw_calls
  + collage_detail_draw_calls

collage_draw_call_estimate <= collage_draw_call_budget
collage_draw_call_budget = 80
```

This follows the Art Bible draw-call allocation: Collage layer target 60–80 calls inside the project-wide ≤500 frame budget.

### D.3 Texture Memory Estimate

```text
rgba_texture_mb(width, height) = width * height * 4 / 1_048_576

collage_texture_memory_mb =
  sum(rgba_texture_mb(photo_i.width, photo_i.height))
  + sum(rgba_texture_mb(atlas_j.width, atlas_j.height))
  + sum(rgba_texture_mb(background_k.width, background_k.height))
```

Tier 1 targets:

```text
collage_photo_texture_budget_mb = 60
collage_total_stage_texture_target_mb <= 80
```

The total project resident ceiling remains 1.5 GB. Collage must warn when project resident memory reaches 75% of that ceiling during test instrumentation.

### D.4 Readable Third

```text
readable_third_half_width_px = viewport_width / 6
```

Tier 1 viewport:

```text
1280 / 6 = 213.33 px
```

Critical collage hints cannot be placed exclusively outside horizontal center ±213 px unless paired with a second readable cue inside that zone.

### D.5 Contrast Guard

For critical gameplay silhouettes against collage background:

```text
silhouette_luma_delta = abs(luma(foreground_edge) - luma(background_region))
silhouette_luma_delta >= 0.35
```

This numeric threshold is a production art-check target. If automated luma capture is not available during Tier 1, use manual screenshot review and mark the AC as visual-review evidence.

### D.6 Fragment Density Per Screen

```text
visible_fragment_density =
  visible_collage_fragments_in_viewport / viewport_area_megapixels
```

Tier 1 soft target:

```text
visible_fragment_density <= 18 fragments / megapixel
```

This is a clutter warning threshold, not a hard art rule. The hard cap remains D.1 and the hard readability gate remains C.4 / H.

---

## E. Edge Cases

### E.1 Collage hides a lethal projectile

If a projectile, hazard, or boss warning cannot be distinguished in the 0.2-second glance test, collage loses. Move/remove/desaturate the fragment or simplify the background. Do not solve by changing projectile gameplay timing.

### E.2 Boss silhouette competes with background fragments

Boss readability takes priority. Move Layer 3 fragments away from the boss readable zone, add line-structure framing, or darken the background mass. Do not add a boss HP bar to compensate.

### E.3 Camera shake makes torn-paper edges look detached

If collage layers appear to wobble independently during shake, implementation has violated C.1. All three layers must be world-space siblings moving under the same Camera #3 offset.

### E.4 Rewind shader inversion destroys contrast

Shader #16 must adjust its shader pass, but Collage #15 must provide `collage_line_structure` tags and avoid color-only threat separation. If inversion collapses readability, preserve shape/outline first.

### E.5 Scene transition while collage textures are loaded

Tier 1 clears local references on `scene_will_change` and relies on scene unload for node cleanup. If memory instrumentation shows resident memory does not drop after repeated reloads, trigger the Tier 2 ADR early.

### E.6 Missing photo texture or unresolved license

Use a gray placeholder with visible "PLACEHOLDER_SOURCE" label in debug builds. Do not silently substitute unlicensed images into production atlases.

### E.7 Draw-call budget exceeded

Cull in this order:

1. decorative Layer 3 fragments outside combat lanes;
2. duplicate photo fragments;
3. non-story ad fragments;
4. background-strip detail pieces;
5. only as a last resort, simplify line-structure art while preserving gameplay outlines.

Do not cull ECHO/enemy/boss/hazard readability aids.

### E.8 Steam Deck low-resolution readability

If 720p Steam Deck capture fails while 1080p desktop passes, adjust collage density and silhouette contrast for 720p. Steam Deck is a target platform, not a nice-to-have.

### E.9 Photo-source Q2 later changes pipeline

Changing from placeholders to stock/original/AI-generated photos may alter color, noise, or licensing metadata. Re-run draw-call, memory, and 0.2-second screenshot checks after the Q2 decision.

### E.10 Multiple stages introduced before texture ADR

Reject the implementation plan. Multi-stage collage loading requires an ADR for texture release/cache strategy and async loading before Tier 2.

### E.11 Fragment overlaps HUD safe area

HUD #13 remains on top, but background clutter can still reduce token/ammo glance speed. Move or desaturate top-left fragments if HUD 0.2-second glance fails.

### E.12 Atlas bleeding or filtering artifacts

If NEAREST cutout edges bleed from atlas neighbors, add padding to atlas cells or split the fragment into a separate texture. Do not switch all cutouts to LINEAR, which softens collage edges.

---

## F. Dependencies

### F.1 Upstream Dependencies

| # | System / Source | Hardness | Collage consumes | Forbidden coupling |
|---|---|---|---|---|
| **#2** | [Scene Manager](scene-manager.md) | Hard lifecycle | `scene_will_change()` boundary; stage scene load/unload lifecycle | Calling scene swap APIs or owning checkpoint restart. |
| **#3** | [Camera](camera.md) | Hard visual constraint | Camera uniform movement contract, readable third, `MAX_SHAKE_PX=12` | Independent layer wobble or camera signal requests. |
| **#12** | [Stage / Encounter](stage-encounter.md) | Hard authoring | stage root, room bounds, hazard placement context | Changing spawn order, hazards, encounters, or camera limits. |
| Art Bible | Hard visual source | 3-layer collage, palette, import settings, fragment and memory budgets | Contradicting visual identity or readability rules. |
| Technical Preferences | Hard performance source | Godot 4.6, Forward+, ≤500 draw calls, 1.5 GB memory | Vulkan-only assumptions, addon dependency, custom renderer. |

### F.2 Downstream Dependents

| # | System | Dependency | Collage provides |
|---|---|---|---|
| **#16** | [Time Rewind Visual Shader](time-rewind-visual-shader.md) | Hard visual substrate | Approved 2026-05-13. Layer metadata, contrast constraints, shader ownership boundary, and decorative glitch eligibility. |
| **#14** | [VFX / Particle](vfx-particle.md) | Soft budget/readability | Background contrast and draw-call headroom for impacts, near-miss, boss bursts. |
| **#12** | Stage / Encounter | Soft authoring | Stage composition rules, hazard background contrast, room screenshot gate. |
| QA / Performance | Verification | draw-call, memory, and 0.2-second screenshot checks. |
| Asset Spec | Production art | atlas names, fragment caps, source-license metadata obligations. |

### F.3 Interface / Data Catalog

| Data / interface | Owner | Reader | Notes |
|---|---|---|---|
| `CollageRoot` node | Collage #15 / Stage scene | Stage, QA, Shader #16 | Three child layer classes required. |
| `collage_base_photo` group | Collage #15 | Shader #16 / QA | Full-screen inversion eligible, not gameplay authority. |
| `collage_line_structure` group | Collage #15 | Shader #16 / QA | Preserve contrast during rewind. |
| `collage_detail_fragment` group | Collage #15 | Shader #16 / QA | Decorative glitch-eligible candidates. |
| `rewind_glitch_eligible` metadata | Collage #15 | Shader #16 | Defaults false for gameplay-critical silhouettes. |
| `scene_will_change()` | Scene Manager #2 | Collage #15 | Clear local refs only in Tier 1. |

### F.4 Cross-Doc Mirror Status

| Source / Target | Mirror Status | Required Follow-up |
|---|---|---|
| `systems-index.md` | Row #15 links this GDD and marks Approved with review log | Keep status and counts in sync if Collage is revised. |
| `scene-manager.md` | Collage #15 obligation clarified: Tier 1 local ref cleanup; Tier 2 ADR required for explicit cache release | Re-check when Tier 2 multi-stage begins. |
| `time-rewind.md` | Collage readability dependency mirrored; 0.2-second glance AC specified here | Shader #16 now consumes contrast preservation in `time-rewind-visual-shader.md`. |
| `vfx-particle.md` | VFX draw-call/readability dependency mirrored | Re-check only if VFX budgets change. |
| `camera.md` / `art-bible.md` | Uniform camera movement and readable third mirrored | No new Camera signal. |
| `design/registry/entities.yaml` | Collage constants added | Keep in sync if fragment/memory/draw-call caps change. |

---

## G. Tuning Knobs

| Knob | Type | Default | Safe Range | Affects | Too Low | Too High |
|---|---|---:|---:|---|---|---|
| `max_collage_fragments_per_stage` | int | 30 | 12..30 | Visual richness / draw calls | Style too sparse | Budget/readability risk |
| `collage_draw_call_budget` | int calls | 80 | 50..80 | Render cost | Collage loses identity | Exceeds Art Bible allocation |
| `collage_photo_texture_budget_mb` | int MB | 60 | 20..60 | Memory | Photos too repetitive | Resident memory risk |
| `collage_total_stage_texture_target_mb` | int MB | 80 | 40..100 | Stage texture memory | Underproduced stage | Tier 2 memory pressure |
| `photo_fragment_max_size_px` | int px | 256 | 128..256 | Memory / texture clarity | Photos blur or repeat | Memory creep |
| `collage_atlas_size_px` | int px | 512 | 256..1024 | Batching / asset packing | Too many textures | Large atlas waste |
| `background_strip_count` | int | 3 | 2..3 | Depth / composition | Flat background | Draw-call/memory pressure |
| `line_stroke_px` | int px | 3 | 2..4 | Readability | Weak outlines | Heavy comic look |
| `detail_fragment_alpha_max` | float | 0.70 | 0.40..0.80 | Visual clutter | Detail invisible | Masks threats |
| `silhouette_luma_delta_min` | float | 0.35 | 0.30..0.50 | Gameplay clarity | Threats blend | Over-flattened art |
| `memory_warning_fraction` | float | 0.75 | 0.70..0.85 | Early memory warning | Too noisy | Warning too late |

Locked constraints:

- `max_collage_fragments_per_stage` cannot exceed 30 without Art Bible + performance review.
- `collage_draw_call_budget` cannot exceed 80 without borrowing from another presentation budget.
- Pure white remains reserved for death flash; not tunable here.
- Multi-stage cache release requires ADR before implementation.

---

## H. Acceptance Criteria

| ID | Criterion | Verification |
|---|---|---|
| **AC-COL-01** | GIVEN Tier 1 stage scene loads, WHEN the scene tree is inspected, THEN `CollageRoot` exists with `BasePhotoLayer`, `LineArtStructureLayer`, and `CollageDetailLayer` children. | Scene inspection / integration. |
| **AC-COL-02** | GIVEN a production gameplay screenshot at 1080p, WHEN shown for 0.2 seconds, THEN ECHO, standard enemies, bullets, hazards, and boss silhouette are distinguishable. | Visual review / playtest capture. |
| **AC-COL-03** | GIVEN the same screenshot, WHEN art review checks identity, THEN both photo texture and line/cutout drawing are visible. | Art review. |
| **AC-COL-04** | GIVEN Layer 3 fragments are counted for Tier 1 stage, WHEN count completes, THEN `collage_fragment_count <= 30`. | Static content audit. |
| **AC-COL-05** | GIVEN render stats are captured during Tier 1 combat, WHEN collage layers are visible, THEN `collage_draw_call_estimate <= 80` and whole-frame draw calls remain ≤500. | Performance capture. |
| **AC-COL-06** | GIVEN Tier 1 collage textures are loaded, WHEN memory is estimated, THEN photo textures are ≤60 MB and total stage collage texture target is ≤80 MB unless an explicit review exception exists. | Asset audit / import report. |
| **AC-COL-07** | GIVEN `scene_will_change()` emits, WHEN Collage cleanup runs, THEN Collage-owned registries and strong refs are cleared and no gameplay signal emits. | Integration test / signal spy. |
| **AC-COL-08** | GIVEN Tier 1 uses one stage, WHEN scene transition occurs, THEN Collage does not call global ResourceLoader cache-release APIs. | Static scan. |
| **AC-COL-09** | GIVEN Tier 2 multi-stage collage loading is proposed, WHEN implementation planning starts, THEN an ADR for explicit texture release/cache strategy exists first. | Gate check. |
| **AC-COL-10** | GIVEN Camera shake reaches `MAX_SHAKE_PX`, WHEN a frame is inspected, THEN all three collage layers move uniformly, torn-paper edge distances do not change, and no `Parallax2D` or independent camera-relative offsets are active. | Visual/integration capture / static scan. |
| **AC-COL-11** | GIVEN Time Rewind Shader #16 applies inversion/glitch, WHEN readability is checked, THEN `collage_line_structure` remains contrast-preserving for threats and traversal. | Shader integration review. |
| **AC-COL-12** | GIVEN a collage fragment is placed near HUD upper-left, WHEN HUD #13 token/ammo glance is tested, THEN the HUD remains readable in 0.2 seconds or the fragment is moved/desaturated. | Visual review. |
| **AC-COL-13** | GIVEN a critical gameplay silhouette overlaps a collage background region, WHEN luma or manual contrast check runs, THEN `silhouette_luma_delta >= 0.35` or visual review records an equivalent pass. | Art/perf QA. |
| **AC-COL-14** | GIVEN texture import settings are audited, WHEN line/cutout atlases are checked, THEN they use NEAREST; photo fragments use LINEAR. | Import audit. |
| **AC-COL-15** | GIVEN source textures enter production atlas, WHEN asset metadata is audited, THEN every photo/cutout source has license/source metadata. | Asset audit. |
| **AC-COL-16** | GIVEN a missing or unlicensed photo source is detected, WHEN production export audit runs, THEN export fails or blocks art lock until placeholder/source issue is resolved. | Build/content gate. |
| **AC-COL-17** | GIVEN Steam Deck 720p capture is reviewed, WHEN combat is active, THEN the 0.2-second readability gate still passes. | Device capture / manual AC. |
| **AC-COL-18** | GIVEN draw-call pressure exceeds budget, WHEN culling is applied, THEN decorative Layer 3 fragments are reduced before gameplay outlines or VFX readability are reduced. | Content review. |
| **AC-COL-19** | GIVEN Shader #16 consumes Collage metadata, WHEN groups are inspected, THEN base/photo, line/structure, and detail fragments are tagged consistently. | Static scene audit. |
| **AC-COL-20** | GIVEN repeated restart/scene reload soak test runs, WHEN resident memory approaches 75% of 1.5 GB, THEN a warning is recorded and Tier 2 texture-release ADR trigger is surfaced. | Soak/performance test. |

---

## Visual / Audio Requirements

Collage #15 owns visual composition only. It owns no audio.

| Visual element | Owner behavior |
|---|---|
| Rooftop base photo layer | Low-saturation megacity mass; no threat-like cyan/magenta confusion. |
| Line-art structure | Platforms, hazard outlines, and traversal edges readable at 0.2 seconds. |
| Collage detail | ARCA/VEIL ads, torn paper, Sigma graffiti; decorative unless paired with Stage/Story. |
| Boss framing | Supports STRIDER silhouette without hiding telegraphs or phase shell VFX. |
| Rewind shader substrate | Provides tagged layers and preserves contrast under inversion. |

Reserved Tier 1 assets:

| Asset | Purpose |
|---|---|
| `atlas_collage_stage1.png` | ARCA ads, VEIL icons, Sigma graffiti, torn paper fragments. |
| `bg_rooftop_photo_layer_01.png` | Base photo strip / skyline mass. |
| `bg_rooftop_photo_layer_02.png` | Secondary photo/background strip if budget allows. |
| `env_rooftop_line_structure.png` or atlas cells | Line-art structure pieces. |
| `col_placeholder_photo_*.png` | License-pending prototype placeholders only. |

---

## UI Requirements

Collage #15 owns no HUD, menu, prompt, cursor, or debug UI.

| UI surface | Owner | Collage rule |
|---|---|---|
| Token/ammo/boss widgets | HUD #13 | Keep top-left and boss UI areas visually calm enough for 0.2-second glance. |
| Pause/menu background | Menu #18 | May reuse collage assets later; not owned in Tier 1. |
| Debug draw-call/memory overlay | QA/performance | Optional debug-only; disabled in production. |
| Story intro typography | Story Intro #17 | May use cutout aesthetic; not owned by gameplay Collage #15. |

---

## Cross-References

- `design/art/art-bible.md` — visual identity, 3-layer collage, palette, import settings, draw-call/memory budgets.
- `design/gdd/systems-index.md` — high-risk status and MVP ordering.
- `design/gdd/scene-manager.md` — scene boundary, memory ceiling triggers, Tier 2 explicit release obligation.
- `design/gdd/camera.md` — uniform camera shake / readable third / `MAX_SHAKE_PX=12`.
- `design/gdd/stage-encounter.md` — stage root, room/hazard placement, camera limits.
- `design/gdd/vfx-particle.md` — VFX draw-call/readability handoff.
- `design/gdd/time-rewind.md` — rewind learning-tool readability dependency.
- `docs/engine-reference/godot/modules/rendering.md` — Godot 4.6 rendering constraints, D3D12 default, shader/postprocess cautions.
- `.claude/docs/technical-preferences.md` — 60 fps, ≤500 draw calls, 1.5 GB memory ceiling, Steam Deck target.

---

## Open Questions

| ID | Question | Owner | Timing | Blocking? | Notes |
|---|---|---|---|---|---|
| OQ-COL-1 | Final Q2 photo source: stock, AI-generated, or original photography? | creative-director + legal/IP reviewer | Before production art lock | No for Tier 1 design; yes before release | Placeholder textures allowed only with clear labels. |
| OQ-COL-2 | Exact Godot texture cache release strategy for multi-stage Tier 2? | technical director + godot-specialist | Before Tier 2 multi-stage implementation | Yes for Tier 2 | Requires ADR before implementation. |
| OQ-COL-3 | ✅ Resolved 2026-05-13 by `time-rewind-visual-shader.md`: Shader #16 may use `rewind_glitch_eligible` for decorative tearing, but Tier 1 does not require per-fragment gameplay logic. | shader specialist + technical artist | Closed by Shader #16 approval | No for Collage | Collage metadata supports optional decorative glitch only. |
| OQ-COL-4 | Does Steam Deck Gen 1 need a lower `max_collage_fragments_per_stage` than 30? | performance analyst | First device capture | No for authoring | AC-COL-17/20 captures the proof. |
| OQ-COL-5 | Should Tier 2 menus reuse gameplay collage layer assets? | UX designer + art-director | Menu #18 GDD | No | Avoid coupling HUD/Menu to stage `CollageRoot`. |

---

## Deferred Follow-Up Actions

1. Run `/asset-spec system:collage-rendering` for the approved Collage pipeline.
2. Before Tier 2 multi-stage work, create an ADR for texture release/cache strategy and async loading.
3. Re-check C.7 metadata and AC-COL-11/19 only if Shader #16 or Collage metadata is revised.
4. Capture a Steam Deck 720p screenshot/playtest sample for AC-COL-17 before implementation sign-off.
