# Time Rewind Visual Shader

> **System**: #16 Time Rewind Visual Shader  
> **Category**: Presentation  
> **Priority**: MVP (Tier 1 contract; final polish can scale in Tier 2)  
> **Status**: Approved · 2026-05-13  
> **Author**: godot-shader-specialist + technical-artist + game-designer  
> **Engine**: Godot 4.6 / Forward+ / D3D12-safe 2D CanvasItem fullscreen pass  
> **Depends On**: Time Rewind #9, Collage Rendering #15, VFX / Particle #14, Art Bible, Camera #3  
> **Consumed By**: QA/performance instrumentation, Asset Spec, future polish passes

---

## A. Overview

The Time Rewind Visual Shader owns Echo's full-viewport rewind signature: the instant a valid rewind begins, the screen flips into cyan/magenta inversion, the collage substrate tears into a short glitch/decomposition read, and the palette restores before ECHO's 30-frame protection window ends. It is a presentation system only. It does not decide whether rewind succeeds, restore player state, pause particles, move the camera, mutate tokens, or own ECHO's i-frame shape signal; those contracts remain in Time Rewind #9, VFX #14, Camera #3, HUD #13, Damage #8, and Player Movement #6.

Tier 1 may ship a simple fullscreen `ColorRect` / CanvasItem shader stub if it preserves timing, coverage, contrast, and performance. Final UV tearing or collage-specific decomposition is polishable, but the player-facing contract is not optional: rewind must be recognizable from screen visuals alone within 0.5 seconds without hiding bullets, ECHO, hazards, or boss silhouettes.

---

## B. Player Fantasy

**"I broke the frame for half a second, learned the mistake, and snapped back alive."**

The shader makes rewind feel like a violent but controlled recovery event. The player should not read it as a pause, invincibility spell, teleport, death animation, or random screen glitch. It should feel like the entire collage world briefly inverted around ECHO's mistake and then returned to playable clarity.

The fantasy has three promises:

1. **Instant recognition** — the player can identify a successful rewind activation in a 0.5-second glance.
2. **Recovery, not confusion** — the effect is spectacular for the first 18 frames, then clears so the remaining i-frame window is playable.
3. **Collage-specific identity** — the effect uses the established cyan/magenta inversion and magazine-cutout tearing language, not generic bloom, chromatic aberration, or VHS noise.

### Anti-Fantasy

| Rejected | Reason |
|---|---|
| Long cinematic rewind | Violates Pillar 1 sub-second recovery and converts rage time into waiting. |
| Time-stop shader | ADR-0001 says only ECHO rewinds; enemies, bullets, and environment continue simulation. |
| Color-only i-frame read | Art Bible forbids i-frame communication through color because inversion changes color semantics. |
| Pure bloom / gradient flash | Loses Pillar 3 collage identity and competes with bullet readability. |
| Terminating from `rewind_completed` | Time Rewind #9 emits `rewind_completed` in the same tick as restore; the shader must run from `rewind_started` + its own timer. |
| Vulkan-only shader assumptions | Godot 4.6 Windows defaults to D3D12; the effect must be backend-safe. |

---

## C. Detailed Rules

### C.1 Ownership Boundary

Shader #16 owns only the full-viewport rewind visual pass.

| Surface | Owner | Shader #16 role |
|---|---|---|
| Rewind success/failure decision | Time Rewind #9 / State Machine #5 | Consume success signal only. |
| Player restoration | Time Rewind #9 / Player Movement #6 / Player Shooting #7 | No state writes. |
| Particle pause/re-anchor/restart | VFX #14 | Coordinate visual timing; no particle simulation ownership. |
| Fullscreen inversion/glitch | Shader #16 | Sole owner. |
| ECHO i-frame shape signal frames 19–30 | Player Movement #6 / Time Rewind #9 visual contract | Do not tint or override; leave readable. |
| HUD token updates | HUD #13 | Do not draw token counters or UI effects. |
| Camera freeze/snap/smoothing reset | Camera #3 | Align visual timing; no Camera signal request. |
| Collage layer metadata | Collage #15 | Read tags/groups only; do not mutate scene composition. |

### C.2 Trigger Contract

Shader #16 subscribes to one Time Rewind #9 signal:

```gdscript
rewind_started(remaining_tokens: int)
```

Rules:

1. `rewind_started` starts a protection-aligned shader controller timeline.
2. The fullscreen pass has visible intensity only during frames 0–18 of that timeline.
3. Frames 19–30 are reserved for ECHO's i-frame shape/readability signal; Shader #16 must disable or reduce the fullscreen material to zero visible intensity by frame 19.
4. Shader #16 must not terminate from `rewind_completed(player, restored_to_frame)`, because Time Rewind #9 emits that signal in the same tick as restoration.
5. Shader #16 may observe `rewind_protection_ended(player)` only for debug assertions that its local frame index agreed with Time Rewind #9. It must not use that signal to drive normal visual termination.
6. If `rewind_started` arrives while a shader timeline is already active, ignore the second event and log a debug warning; Time Rewind #9 already guards against re-entry, so this is a defensive path only.

### C.3 Timeline Contract

Timeline frames are counted relative to the physics frame where `rewind_started` is received.

Index convention: frame `0` is the activation/pre-flash sample. Time Rewind #9 emits `rewind_protection_ended` after 30 elapsed physics frames, which corresponds to local shader index `f = 30` for debug agreement checks. The fullscreen shader must already have zero visible intensity for all `f >= 19`; this prevents any off-by-one visual tail even if the controller performs its final assertion at `f = 30`.

| Timeline frame | Visual state | Required behavior |
|---:|---|---|
| 0 | Pre-flash | 1-frame fullscreen Rewind Cyan burst, 30% alpha. |
| 1–3 | Inversion | Cyan/magenta inversion is dominant; full viewport covered. |
| 4–8 | Collage glitch | Decorative collage fragments may tear/decompose using low-amplitude UV offset; gameplay-critical line structure remains legible. |
| 9–18 | Palette restoration | Inversion/glitch intensity fades to 0; by frame 18 the world palette is normal. |
| 19–30 | Shader inactive tail | No fullscreen shader intensity; ECHO i-frame shape/visibility signal owns the read. |

This timeline inherits the `REWIND_SIGNATURE_FRAMES = 30` single source from Time Rewind #9 while respecting the Art Bible 18-frame fullscreen effect. The controller is protection-aligned for debug agreement with Time Rewind #9; the shader pass is visually active only through the first 18 local indices.

### C.4 Rendering Contract

Tier 1 implementation uses a single fullscreen 2D overlay pass. It must not require:

1. a custom renderer or GDExtension;
2. manual multi-Viewport chains;
3. Vulkan-only behavior;
4. shader variants that require Shader Baker to avoid hitches in Tier 1;
5. per-fragment gameplay logic.

Acceptable Tier 1 surfaces:

- a fullscreen `ColorRect` on a dedicated presentation layer with a CanvasItem shader;
- an equivalent engine-supported 2D post-process path, if verified for Godot 4.6 and D3D12;
- a flat-color fallback with the same frame envelope when UV distortion is disabled for performance.

### C.5 Collage Metadata Use

Shader #16 may read the Collage #15 groups/metadata:

| Collage metadata | Shader use | Constraint |
|---|---|---|
| `collage_base_photo` | Eligible for full-screen inversion. | No gameplay authority. |
| `collage_line_structure` | Preserve readability; reduce distortion first if contrast fails. | Must stay legible during frames 4–8. |
| `collage_detail_fragment` | Preferred decorative glitch/decomposition candidates. | Never the only readability cue. |
| `rewind_glitch_eligible: bool` | Allows stronger decorative tearing if true. | Defaults false; gameplay-critical silhouettes never require it. |

Shader #16 must not create independent camera-relative parallax or move `CollageRoot` layers. Collage #15's static wide-strip and uniform Camera #3 movement contracts remain authoritative.

### C.6 Readability Contract

1. Fullscreen coverage must be 100% of the viewport during frames 0–18.
2. ECHO, bullets, hazards, enemies, and boss warnings must remain identifiable in a 0.2-second screenshot during active combat.
3. ECHO vs enemy identification must not rely on cyan/magenta color alone during inversion; silhouette/shape remains the carrier.
4. Pure white remains reserved for the 1-frame death flash; rewind pre-flash uses Rewind Cyan, not `#FFFFFF`.
5. If inversion or glitch breaks readability, reduce glitch amplitude or disable collage tearing before changing gameplay timing, projectile visuals, enemy timing, or Camera #3.
6. If the Time Rewind #9 CanvasLayer R3 mitigation is used, ECHO and bullet readability layers render above the fullscreen shader; Shader #16 must not require a layer order that hides them.

### C.7 Performance Contract

Shader #16 gets the Art Bible fullscreen shader budget:

- draw-call allocation: ≤50 draw calls / pass-equivalent budget;
- active shader GPU target: ≤500 µs per active frame on target hardware;
- whole-frame project budget remains ≤500 draw calls and 16.6 ms at 60 fps;
- no per-frame allocations during the active timeline;
- no runtime compilation hitch during the first rewind.

If final UV tearing cannot meet budget, Tier 1 falls back to inversion + palette restoration only. The timing and recognition ACs still apply.

### C.8 Camera Synchronization

Camera #3 freezes on `rewind_started`, then unfreezes, clears shake, retargets, and calls `reset_smoothing()` on `rewind_completed`. Shader #16 does not own that order.

Shader timing rules:

1. Start visual timeline on `rewind_started`, the same event that freezes Camera #3.
2. Do not follow Camera offset for the fullscreen pass; the pass is viewport-space.
3. By frame 18, return the world palette to normal so Camera #3's post-restore snap does not remain hidden under a heavy inversion.
4. Never request a new Camera signal. If later visual polish needs camera-specific information, open an ADR or Camera #3 revision.

### C.9 VFX Coordination

VFX #14 owns local rewind shard bursts and particle pause/restart. Shader #16 owns full-screen inversion/glitch.

Coordination rules:

1. VFX may spawn player-local rewind shards on `rewind_started`; Shader #16 must not duplicate those as particles.
2. Shader #16 must not reverse-simulate particles.
3. VFX restart happens on `rewind_protection_ended`; Shader #16 must already be visually inactive by then.
4. If VFX and Shader budgets conflict, reduce decorative shader glitch before reducing gameplay telegraph VFX.

---

## D. Formulas

### D.1 Shader Timeline Frame

The `rewind_shader_frame` formula is defined as:

```text
rewind_shader_frame = current_physics_frame - shader_start_physics_frame
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `current_physics_frame` | `F_now` | int | `>= 0` | Current `Engine.get_physics_frames()` value. |
| `shader_start_physics_frame` | `F_start` | int | `>= 0` | Physics frame when `rewind_started` was received. |
| `rewind_shader_frame` | `f` | int | `0..30` agreement-check range | Local shader timeline frame. |

**Output Range:** `0..30` for protection-agreement checks; visible intensity must be `0` for all `f >= 19`, and values above 30 mean inactive.  
**Example:** `F_start = 1000`, `F_now = 1004` → `f = 4`, the first collage glitch frame.

### D.2 Phase Selection

The `rewind_shader_phase` formula is defined as:

```text
phase(f) =
  PREFLASH if f == 0
  INVERT if 1 <= f <= 3
  GLITCH if 4 <= f <= 8
  RESTORE if 9 <= f <= 18
  INACTIVE_TAIL if 19 <= f <= REWIND_SIGNATURE_FRAMES
  OFF otherwise
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `rewind_shader_frame` | `f` | int | `0..30` | Timeline frame from D.1. |
| `REWIND_SIGNATURE_FRAMES` | `R` | int | `30` | Time Rewind #9 single source for full protection/signature window. |

**Output Range:** one of `{PREFLASH, INVERT, GLITCH, RESTORE, INACTIVE_TAIL, OFF}`.  
**Example:** `f = 12` → `RESTORE`.

### D.3 Fullscreen Intensity Envelope

The `rewind_shader_intensity` formula is defined as:

```text
rewind_shader_intensity(f) =
  0.30                         if f == 0
  1.00                         if 1 <= f <= 8
  clamp(1.0 - ((f - 9) / 9.0), 0.0, 1.0)  if 9 <= f <= 18
  0.00                         otherwise
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `rewind_shader_frame` | `f` | int | `0..30` | Timeline frame from D.1. |
| `rewind_shader_intensity` | `I` | float | `0.0..1.0` | Fullscreen material strength. |

**Output Range:** `0.0..1.0`; must be `0.0` for frames 19–30.  
**Example:** `f = 13` → `1.0 - ((13 - 9) / 9) = 0.56`.

### D.4 UV Glitch Offset

The `rewind_shader_uv_offset_px` formula is defined as:

```text
rewind_shader_uv_offset_px = rewind_shader_glitch_uv_max_px * rewind_shader_intensity(f)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `rewind_shader_glitch_uv_max_px` | `G_max` | float | `0..6 px` | Maximum decorative UV tear amplitude. |
| `rewind_shader_intensity(f)` | `I` | float | `0.0..1.0` | Intensity envelope from D.3. |
| `rewind_shader_uv_offset_px` | `G` | float | `0..6 px` | Applied distortion amplitude. |

**Output Range:** `0..6 px` in Tier 1.  
**Example:** `G_max = 6`, `I = 0.50` → `G = 3 px`.

### D.5 Shader Budget Check

The `rewind_shader_budget_pass` formula is defined as:

```text
rewind_shader_budget_pass =
  shader_gpu_time_us <= rewind_shader_max_gpu_us
  AND shader_draw_call_equivalent <= rewind_shader_draw_call_budget
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `shader_gpu_time_us` | `T_gpu` | float | `>= 0` | Captured GPU time for active fullscreen pass. |
| `rewind_shader_max_gpu_us` | `T_max` | int | `500` | Active-frame shader budget. |
| `shader_draw_call_equivalent` | `D_shader` | int | `0..50` | Draw-call/pass-equivalent allocation. |
| `rewind_shader_draw_call_budget` | `D_max` | int | `50` | Art Bible fullscreen pass allocation. |

**Output Range:** boolean pass/fail.  
**Example:** `T_gpu = 420`, `D_shader = 1` → pass; `T_gpu = 700` → fail and reduce glitch first.

### D.6 Post-Shader Contrast Guard

The `post_shader_luma_delta` formula is defined as:

```text
post_shader_luma_delta = abs(luma(gameplay_edge_after_shader) - luma(background_region_after_shader))
post_shader_luma_delta >= 0.35
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `gameplay_edge_after_shader` | `L_fg` | float | `0.0..1.0` | Luma at ECHO/enemy/bullet/hazard/boss edge after shader. |
| `background_region_after_shader` | `L_bg` | float | `0.0..1.0` | Luma of adjacent collage/background region after shader. |
| `post_shader_luma_delta` | `ΔL` | float | `0.0..1.0` | Readability contrast after inversion/glitch. |

**Output Range:** `0.0..1.0`; Tier 1 pass threshold is `>= 0.35`, matching Collage #15.  
**Example:** `L_fg = 0.82`, `L_bg = 0.40` → `ΔL = 0.42`, pass.

---

## E. Edge Cases

- **If `rewind_started` fires while a shader timeline is active**: ignore the second event, keep the current timeline, and log a debug warning. Time Rewind #9 should prevent this; Shader #16 is defensive only.
- **If `rewind_completed` fires in the same tick as `rewind_started`**: do not terminate the shader. The 30-frame controller remains active from `rewind_started`.
- **If `rewind_protection_ended` fires before the shader controller reaches frame 30**: log an assertion in debug builds; Time Rewind #9 and Shader #16 disagree on `REWIND_SIGNATURE_FRAMES`.
- **If `rewind_protection_ended` fires after shader frame 30**: keep shader off and log an assertion. Do not extend fullscreen intensity.
- **If active shader GPU time exceeds 500 µs**: reduce or disable UV glitch first; preserve frame timing, fullscreen coverage, and inversion recognition.
- **If whole-frame draw calls exceed 500**: reduce decorative shader/VFX/collage effects before cutting gameplay telegraphs, HUD readability, or projectile visibility.
- **If cyan/magenta inversion makes ECHO look like an enemy**: rely on silhouette and reduce color inversion intensity during frames 1–3; do not recolor ECHO's i-frame signal.
- **If collage line structure becomes unreadable during frames 4–8**: disable glitch for `collage_line_structure` and apply tearing only to `collage_detail_fragment` / `rewind_glitch_eligible` content.
- **If no CollageRoot metadata exists in a prototype scene**: run the global inversion fallback; log a debug note, but do not block rewind visual feedback.
- **If the player dies during the first 90-frame buffer warmup and rewind is denied**: Shader #16 must not run; denial visuals remain Time Rewind/HUD/VFX local feedback only.
- **If pause is attempted during DYING/REWINDING**: Shader #16 does nothing special; State Machine #5 owns pause swallow.
- **If scene transition begins during an active shader timeline**: clear the local shader controller on scene unload; do not preserve fullscreen material state across scenes.
- **If D3D12 output differs from editor/Vulkan captures**: D3D12/Forward+ target wins for PC Windows verification; avoid backend-specific shader assumptions.
- **If UV distortion causes atlas bleeding**: reduce UV amplitude or disable distortion on NEAREST atlas fragments rather than switching collage cutouts to LINEAR.
- **If accessibility review flags the flash as unsafe**: add a future intensity reduction option in Accessibility #24; Tier 1 still uses the baseline but records the risk.

---

## F. Dependencies

### F.1 Upstream Dependencies

| # | System / Source | Hardness | Shader consumes | Forbidden coupling |
|---|---|---|---|---|
| **#9** | [Time Rewind](time-rewind.md) | Hard timing | `rewind_started(remaining_tokens: int)` and `REWIND_SIGNATURE_FRAMES = 30` | Token mutation, restore logic, terminating from `rewind_completed`. |
| **#15** | [Collage Rendering Pipeline](collage-rendering.md) | Hard visual substrate | Collage groups/metadata and contrast/readability contract | Moving `CollageRoot`, requiring parallax, changing fragment budgets. |
| **#14** | [VFX / Particle](vfx-particle.md) | Soft coordination | Local-vs-fullscreen ownership split; particle pause/restart boundary | Particle simulation, local shard ownership, telegraph VFX reduction. |
| **#3** | [Camera](camera.md) | Soft synchronization | `rewind_started` freeze and `rewind_completed` snap/reset order | Camera movement, extra Camera signals, camera shake mutation. |
| Art Bible | Hard visual source | Principle C timeline, palette, draw-call allocation, readability rules | Generic bloom/VHS effects, color-only i-frame feedback. |
| Technical Preferences / Rendering docs | Hard engine source | Godot 4.6, Forward+, D3D12 default, ≤500 draw calls, 16.6 ms frame | Vulkan-only assumptions, unapproved addons, custom renderer. |

### F.2 Downstream Dependents

| # | System | Dependency | Shader provides |
|---|---|---|---|
| QA / performance | Verification | GPU timing, draw-call, screenshot, and D3D12 capture gates. |
| Asset Spec | Production art | Final shader asset names, material parameters, and fallback requirements. |
| Accessibility #24 | Future option | Flash/intensity reduction risk record; no Tier 1 option yet. |
| Marketing capture | Soft | Signature rewind frame sequence for screenshots/trailers after implementation. |

### F.3 Interface / Data Catalog

| Data / interface | Owner | Reader | Notes |
|---|---|---|---|
| `rewind_started(remaining_tokens: int)` | Time Rewind #9 | Shader #16 | Sole runtime trigger. |
| `REWIND_SIGNATURE_FRAMES = 30` | Time Rewind #9 | Shader #16 | Controller lifetime; visible shader intensity ends earlier. |
| `collage_base_photo` | Collage #15 | Shader #16 | Eligible for global inversion. |
| `collage_line_structure` | Collage #15 | Shader #16 | Preserve readability; avoid strong distortion. |
| `collage_detail_fragment` | Collage #15 | Shader #16 | Preferred decorative glitch target. |
| `rewind_glitch_eligible` | Collage #15 | Shader #16 | Optional stronger glitch flag. |
| `camera.offset` | Camera #3 | VFX #14 only | Shader #16 does not need it; fullscreen pass is viewport-space. |

### F.4 Cross-Doc Mirror Status

| Source / Target | Mirror Status | Required Follow-up |
|---|---|---|
| `systems-index.md` | Row #16 links this GDD and marks Approved with review log | Keep status and counts in sync if Shader #16 is revised. |
| `time-rewind.md` | Provisional Shader #16 row is now replaced by this GDD's `rewind_started` + protection-aligned internal controller contract | Re-check only if Time Rewind #9 signal timing changes. |
| `vfx-particle.md` | VFX local-vs-fullscreen split mirrored | Re-check if VFX budget changes. |
| `collage-rendering.md` | Collage metadata and contrast handoff consumed | Re-check if Collage group names change. |
| `camera.md` | Shader timing aligned with Camera #3 freeze/snap/reset order without new signal | Re-check if Camera rewind handler order changes. |
| `design/registry/entities.yaml` | Shader timing/performance constants registered | Keep in sync if frame/budget values change. |
| `docs/registry/architecture.yaml` | `rewind_lifecycle` consumer list includes Shader #16 | Keep signal signature single-source in Time Rewind #9. |

---

## G. Tuning Knobs

| Knob | Type | Default | Safe Range | Affects | Too Low | Too High |
|---|---|---:|---:|---|---|---|
| `rewind_shader_preflash_alpha` | float | 0.30 | 0.20..0.40 | Frame 0 recognition | Weak activation read | Flash dominates bullets |
| `rewind_shader_inversion_strength` | float | 1.00 | 0.60..1.00 | Frames 1–3 rewind identity | Looks like tint, not inversion | ECHO/enemy confusion |
| `rewind_shader_glitch_uv_max_px` | float px | 6 | 0..6 | Frames 4–8 collage tear | Glitch invisible | Atlas bleed/readability risk |
| `rewind_shader_restore_end_frame` | int frame | 18 | 12..18 | Palette clear speed | Too abrupt, weak spectacle | Hides i-frame gameplay tail |
| `rewind_shader_max_gpu_us` | int µs | 500 | 250..500 | Performance budget | Over-constrains art | Frame-time risk |
| `rewind_shader_draw_call_budget` | int calls | 50 | 10..50 | Art Bible allocation | May force no pass | Steals from VFX/HUD/collage |
| `post_shader_luma_delta_min` | float | 0.35 | 0.30..0.50 | Readability | Threats blend | Over-flattened art |

Locked constraints:

- `REWIND_SIGNATURE_FRAMES = 30` is owned by Time Rewind #9 and must not be changed here.
- Visible fullscreen shader intensity must be 0 by frame 19.
- Shader #16 must not terminate from `rewind_completed`.
- Pure white remains reserved for DEAD whiteout, not rewind.
- Any accessibility flash-reduction option belongs to Accessibility #24 or a future options GDD.

---

## H. Acceptance Criteria

| ID | Criterion | Verification |
|---|---|---|
| **AC-SHD-01** | GIVEN `rewind_started(remaining_tokens)` emits, WHEN Shader #16 receives it, THEN a protection-aligned shader controller starts on that physics frame. | Unit/integration signal spy. |
| **AC-SHD-02** | GIVEN shader frame 0, WHEN a frame capture is inspected, THEN a fullscreen Rewind Cyan pre-flash is visible for exactly 1 frame at 30% alpha. | Frame capture. |
| **AC-SHD-03** | GIVEN shader frames 1–3, WHEN capture is inspected, THEN cyan/magenta inversion covers 100% of the viewport. | Visual capture / viewport coverage check. |
| **AC-SHD-04** | GIVEN shader frames 4–8, WHEN collage metadata exists, THEN decorative glitch affects only safe collage content and `collage_line_structure` remains legible. | Scene audit + screenshot review. |
| **AC-SHD-05** | GIVEN shader frame 18 has completed, WHEN frame 19 begins, THEN fullscreen shader visible intensity is 0 and ECHO's i-frame shape signal remains unobscured. | Frame capture / material param assertion. |
| **AC-SHD-06** | GIVEN `rewind_completed(player, restored_to_frame)` emits in the same tick as restoration, WHEN Shader #16 observes the event stream, THEN it does not terminate or restart the shader from `rewind_completed`. | Signal spy / source scan. |
| **AC-SHD-07** | GIVEN `rewind_protection_ended(player)` emits 30 frames after `rewind_started`, WHEN debug assertions compare timers, THEN Shader #16's controller frame is also 30. | Integration test. |
| **AC-SHD-08** | GIVEN active combat during frames 1–18, WHEN a 1080p screenshot is shown for 0.2 seconds, THEN ECHO, enemies, bullets, hazards, and boss warnings remain distinguishable. | Visual review / playtest capture. |
| **AC-SHD-09** | GIVEN a Steam Deck 720p capture during frames 1–18, WHEN readability is reviewed, THEN the same 0.2-second distinction test passes. | Device/manual capture. |
| **AC-SHD-10** | GIVEN a post-shader luma sample at a critical gameplay edge, WHEN `post_shader_luma_delta` is calculated, THEN it is `>= 0.35` or visual review records an equivalent pass. | Image analysis / art QA. |
| **AC-SHD-11** | GIVEN active shader profiling, WHEN GPU time is captured, THEN active shader cost is `<= 500 µs` per frame on target hardware or the UV glitch fallback is used. | Performance capture. |
| **AC-SHD-12** | GIVEN whole-frame render stats during rewind, WHEN draw calls are counted, THEN project total remains `<= 500` and Shader #16 stays within its 50-call/pass-equivalent budget. | Render stats capture. |
| **AC-SHD-13** | GIVEN no CollageRoot metadata exists, WHEN rewind starts in a prototype scene, THEN the global inversion fallback still runs and no error blocks gameplay. | Integration smoke test. |
| **AC-SHD-14** | GIVEN D3D12 Windows capture and editor capture differ, WHEN verification is recorded, THEN D3D12/Forward+ target behavior is treated as authoritative. | Platform capture note. |
| **AC-SHD-15** | GIVEN scene transition occurs during active shader timeline, WHEN the old scene unloads, THEN shader controller/material state is cleared and does not persist into the next scene. | Scene transition test. |
| **AC-SHD-16** | GIVEN source scan of Shader #16 implementation, WHEN forbidden patterns are checked, THEN no custom renderer, GDExtension, manual multi-Viewport chain, or Vulkan-only branch is required for Tier 1. | Static scan. |
| **AC-SHD-17** | GIVEN pure white usage is audited, WHEN rewind frames are inspected, THEN Shader #16 does not use `#FFFFFF`; pure white appears only in DEAD whiteout owned by death/restart flow. | Color audit. |
| **AC-SHD-18** | GIVEN `rewind_started` fires twice while the controller is active, WHEN the second event is received, THEN the current timeline continues unchanged and a debug warning is logged. | Defensive unit test. |
| **AC-SHD-19** | GIVEN the Time Rewind #9 CanvasLayer readability mitigation is active, WHEN render order is inspected, THEN ECHO and bullet readability layers render above the fullscreen shader and remain visible during frames 1–18. | Scene hierarchy audit / frame capture. |

---

## Visual / Audio Requirements

Shader #16 owns visuals only. It owns no audio event, sound routing, ducking, or mix behavior.

| Visual element | Requirement |
|---|---|
| Pre-flash | Rewind Cyan, 1 frame, 30% alpha, no pure white. |
| Inversion | Cyan/magenta dominant; readable silhouettes; full viewport. |
| Collage glitch | Low-amplitude tear/decomposition on decorative collage material first. |
| Palette restoration | Clear by frame 18; no fullscreen tint during frames 19–30. |
| ECHO/bullet readability | Must remain shape-readable under the shader; do not rely on color. |
| Fallback | Flat inversion/restore envelope may replace UV glitch if performance fails. |

Reserved Tier 1 asset/material hooks:

| Asset / Material | Purpose |
|---|---|
| `shader_rewind_fullscreen.gdshader` | Fullscreen inversion + optional UV glitch envelope. |
| `mat_rewind_fullscreen.tres` | Material instance with exposed intensity/glitch parameters. |
| `debug_rewind_shader_capture.tscn` | Standalone capture scene for 1080p / 720p / D3D12 verification. |

📌 **Asset Spec** — Visual requirements are defined. Run `/asset-spec system:time-rewind-visual-shader` to produce the final material parameter descriptions and capture references.

---

## UI Requirements

Shader #16 owns no HUD, menu, cursor, prompt, or debug UI in production.

| UI surface | Owner | Shader rule |
|---|---|---|
| Token counter | HUD #13 | Do not tint or delay token counter logic; HUD already buffers during REWINDING. |
| Boss phase UI | HUD #13 / Boss #11 | Fullscreen shader must not hide boss warning read. |
| Debug profiler overlay | QA/performance | Optional debug-only; disabled in production. |
| Accessibility flash option | Accessibility #24 | Future owner; Shader #16 exposes intensity knobs only after option spec exists. |

---

## Cross-References

- `design/gdd/time-rewind.md` — `rewind_started`, `rewind_completed`, `rewind_protection_ended`, `REWIND_SIGNATURE_FRAMES`.
- `design/gdd/collage-rendering.md` — collage layer metadata, static layer contract, contrast guard.
- `design/gdd/vfx-particle.md` — local-vs-fullscreen ownership split and particle pause/restart.
- `design/gdd/camera.md` — rewind freeze/snap/reset order and no new shader-camera signal.
- `design/art/art-bible.md` — Principle C timeline, palette, draw-call allocation, readability rules.
- `docs/engine-reference/godot/modules/rendering.md` — Godot 4.6 D3D12 default, Shader Baker, rendering constraints.
- `.claude/docs/technical-preferences.md` — 60 fps, ≤500 draw calls, 1.5 GB memory, Steam Deck target.

---

## Open Questions

| ID | Question | Owner | Timing | Blocking? | Notes |
|---|---|---|---|---|---|
| OQ-SHD-1 | Is the Tier 1 flat `ColorRect` / CanvasItem shader enough to pass the 0.5-second recognition test without UV tearing? | art-director + qa-lead | First visual prototype | No for GDD; yes before implementation sign-off | If yes, defer UV tearing polish to Tier 2. |
| OQ-SHD-2 | Do Windows D3D12 and Steam Deck target captures both stay under 500 µs with UV glitch enabled? | performance analyst + godot-shader-specialist | Shader prototype | Yes for final UV glitch | Fallback: inversion-only envelope; record platform-specific renderer evidence separately. |
| OQ-SHD-3 | Should Accessibility #24 expose rewind flash intensity or reduced-glitch mode? | accessibility-specialist | Accessibility GDD | No for Tier 1 baseline | Record risk now; design option later. |
| OQ-SHD-4 | Should Shader Baker be required if Tier 2 introduces multiple rewind shader variants? | technical director | Tier 2 polish planning | No for Tier 1 | Godot 4.5+ Shader Baker exists; avoid variant explosion in Tier 1. |

---

## Deferred Follow-Up Actions

1. Run `/asset-spec system:time-rewind-visual-shader` for the approved Shader #16 pipeline.
2. Build `debug_rewind_shader_capture.tscn` for 1080p, Steam Deck 720p, and Windows D3D12 captures.
3. If UV glitch exceeds budget, document the inversion-only fallback decision in the review log or a lightweight ADR.
4. When Accessibility #24 is authored, revisit reduced-flash / reduced-glitch options.
