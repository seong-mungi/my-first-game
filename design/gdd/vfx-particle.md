# VFX / Particle System

> **System**: #14 VFX / Particle System  
> **Category**: Presentation  
> **Priority**: MVP (Tier 1)  
> **Status**: Approved · 2026-05-13  
> **Author**: technical-artist + gameplay-programmer + game-designer  
> **Engine**: Godot 4.6 / GDScript / 2D (`Sprite2D`, `AnimatedSprite2D`, `GPUParticles2D`)  
> **Depends On**: Damage #8, Time Rewind #9, Player Shooting #7, Enemy AI #10, Boss Pattern #11, Stage #12, Scene Manager #2, Camera #3, Art Bible  
> **Consumed By**: Time Rewind Visual Shader #16, Collage Rendering #15, QA/performance instrumentation

---

## A. Overview

The VFX / Particle System owns Echo's **non-HUD visual feedback layer**: muzzle flashes, projectile travel accents, hit impacts, near-miss sparks, enemy/boss telegraph effects, death bursts, boss phase visual changes, scene-boundary particle cleanup, and local rewind-related particle handling. It makes the one-hit combat loop readable without adding health bars, damage numbers, hidden stun, or gameplay authority.

This GDD does **not** own:

- gameplay collision, damage decisions, phase counters, or projectile timing;
- HUD token counters, ammo icons, boss title/phase UI, or prompts;
- audio cue playback or bus ducking;
- camera shake amplitudes or camera follow;
- full-screen rewind color inversion / UV glitch shader, which is owned by Time Rewind Visual Shader #16;
- base collage layer composition, which is owned by Collage Rendering #15.

VFX is therefore an observer and renderer. It can subscribe to gameplay signals, read immutable or public presentation state, and spawn presentation-only nodes. It cannot mutate state, delay frees, alter hit outcomes, or introduce extra gameplay `Area2D` checks.

**Tier 1 scope**:

1. ECHO muzzle flash and optional weapon fallback glitch.
2. ECHO projectile impact and near-miss signatures.
3. Enemy attack telegraph and death burst mapping.
4. Cause-specific player lethal/death feedback.
5. Boss telegraph, hit, phase advance, interrupt cleanup, and defeat burst.
6. Time Rewind particle pause / local burst / restart handshake.
7. Scene transition cleanup with zero leftover active VFX.
8. Performance budget enforcement inside the Art Bible's 100-call VFX allocation.

---

## B. Player Fantasy

**"I know what almost killed me before I die again."**

Echo's combat is binary and fast: one shot kills a standard enemy, and one hostile hit kills ECHO. VFX exists to make that binary truth legible. A bullet that barely misses should scratch the air; an enemy wind-up should be readable before it becomes lethal; a boss phase should feel like a shell tearing open, not a hidden hit counter decreasing.

VFX supports three player-facing promises:

1. **Readable danger** — hostile output has a visible pre-contact signature, distinct silhouette, and cause-specific impact.
2. **Readable agency** — ECHO shots, impacts, and near-misses confirm where the player aimed without adding hit-stun.
3. **Readable rewind** — when time rewind starts, particles stop implying forward causality; when protection ends, ambient combat feedback resumes.

### Anti-Fantasy

| Rejected | Reason |
|---|---|
| VFX as gameplay authority | Effects cannot change hitboxes, damage, projectile timing, phase counters, or state transitions. |
| HP / hit-count presentation | Boss progression is phase readability only; no remaining-hit or HP signal may be rendered. |
| Full-screen shader ownership | Time Rewind Visual Shader #16 owns color inversion and screen-wide glitch. VFX owns particles/local overlays only. |
| Hidden VFX-only danger | Any gameplay-lethal output must originate from Damage/Enemy/Boss/Stage timing, not a visual node. |
| i-frame color override | Player Movement / Art Bible own REWINDING flicker; VFX cannot use the same color channel to imply invulnerability. |

---

## C. Detailed Rules

### C.1 Ownership Rules

**Rule 1 — presentation-only authority.**  
All VFX nodes are non-authoritative. They may be `Node2D`, `Sprite2D`, `AnimatedSprite2D`, `GPUParticles2D`, `CanvasLayer`, or debug-only overlay nodes. They must not add gameplay `Area2D` hit checks, write to Damage/Time Rewind/Enemy/Boss state, or delay gameplay `queue_free()`.

**Rule 2 — cause taxonomy single source.**  
Damage #8 remains the sole owner of `cause: StringName`. VFX maps existing causes to effect presets; it does not invent new causes locally.

**Rule 3 — no health vocabulary.**  
VFX may differentiate boss phases by `phase_index`, shell/stance tags, and phase-entry bursts. It must never render `phase_hits_remaining`, a health bar, numeric damage, "last hit" counters, or graded damage.

**Rule 4 — object lifetime cannot block gameplay lifetime.**  
If a projectile, enemy, boss pattern, or scene root is freed by its owning system, VFX may spawn a detached one-shot effect first, but the effect must not keep the gameplay node alive.

**Rule 5 — deterministic trigger order follows source signals.**  
When multiple VFX triggers arrive in the same physics tick, VFX processes them in the source signal order documented by the source GDDs. It must not sort by screen position, distance, dictionary key, or random priority.

**Rule 6 — restoration guard for animation-emitted dust.**  
Player Movement #6 animation callbacks such as `_on_anim_emit_dust_vfx` must be guarded during `_is_restoring` / REWINDING restoration. Ground dust, landing puffs, and run scuffs are suppressed while restoration is active, then normal movement VFX resumes after the source state exits restoration. Rewind-specific local shards remain owned by C.6.

**Rule 7 — callback origin binding.**  
Signals whose payload lacks a world position (for example `hurtbox_hit(cause)`) must be connected with a bound source node, bound `NodePath`, or owner lookup established at wiring time. VFX reads the source node's `global_position` during the callback and immediately caches a detached effect position. If the bound source is invalid, VFX skips the positional effect rather than requiring a new gameplay signal payload or delaying source cleanup.

### C.2 Signal Subscriptions

| Source | Signal / read | VFX behavior |
|---|---|---|
| Player Shooting #7 | `shot_fired(direction: int)` | Spawn 3-frame ECHO muzzle flash at the currently authored muzzle offset. |
| Player Shooting #7 | `weapon_fallback_activated(requested_id: int)` | Optional 3-frame local weapon glitch in Tier 2+; no Tier 1 gameplay effect. |
| Damage #8 / HurtBox | `hurtbox_hit(cause: StringName)` | Spawn cause-specific hit spark at callback-time `global_position` using C.1 Rule 7 bound-origin pattern; skip if source position is unavailable. |
| Damage #8 | `lethal_hit_detected(cause)`, `player_hit_lethal(cause)` | Spawn immediate local lethal-read spark; do not show full death flash yet. |
| Damage #8 | `death_committed(cause)` | Spawn death burst / 1-frame white cut if no rewind canceled the pending death. |
| Damage #8 | `enemy_killed(enemy_id, cause)` | Spawn standard enemy death burst; use cause preset for color/shape. |
| Damage #8 | `boss_hit_absorbed(boss_id, phase_index)` | Spawn boss impact by phase index only; no remaining-hit implication. |
| Damage #8 | `boss_phase_advanced(boss_id, new_phase)` | Spawn phase shell tear / stance transition burst. |
| Damage #8 | `boss_pattern_interrupted(boss_id, prev_phase_index)` | Cancel warning-only telegraph VFX for interrupted, uncommitted boss patterns. |
| Damage #8 | `boss_killed(boss_id)` | Spawn boss defeat burst; Audio and Camera own their own responses. |
| Time Rewind #9 | `rewind_started(remaining_tokens: int)` | Stop forward-causality particles and spawn local rewind shard burst. |
| Time Rewind #9 | `rewind_completed(player: Node2D, restored_to_frame: int)` | Re-anchor any player-local VFX to restored player position if still alive. |
| Time Rewind #9 | `rewind_protection_ended(player: Node2D)` | Restart eligible looping particles; do not resume earlier. |
| Enemy AI #10 | `enemy_spotted_player`, `enemy_attack_committed`, `enemy_projectile_spawned`, `enemy_died` | Optional telegraph/death helpers; Damage remains kill source of record. |
| Boss Pattern #11 | `boss_attack_telegraphed(boss_id, attack_id, phase_index)` | Start visible warning effect for the full telegraph window. |
| Scene Manager #2 | `scene_will_change()` | Cleanup VFX-owned active particles and one-shots only; not a presentation hub. |

### C.3 Effect Classes

| Effect class | Anchor | Tier 1 implementation | Notes |
|---|---|---|---|
| ECHO muzzle flash | World-anchored to muzzle | `Sprite2D` atlas animation, 3 frames | Uses Player Shooting #7 V/A.1 colors. |
| ECHO projectile sprite | Projectile-owned | Player Shooting #7 owns base sprite; VFX may add optional tiny impact only | No trail in Tier 1 unless draw-call budget proves safe. |
| Impact spark | World-anchored | 6–18 frame `Sprite2D`/`AnimatedSprite2D` one-shot | Cause-specific shape/color. |
| Near-miss spark | World-anchored to nearest pass point | 6-frame small paper-scratch puff | Mandatory to compensate for no hit-stun. |
| Enemy telegraph | World-anchored to enemy muzzle/body | Eye flash / muzzle charge / burst tick | Follows Enemy AI timing; cannot retime attacks. |
| Boss telegraph | World-anchored warning overlays | Lane/floor warning shape visible for entire telegraph window | Gameplay-readable but non-authoritative. |
| Boss phase burst | World-anchored boss shell | Shell tear + phase palette/stance tag | Uses `new_phase`, not hit count. |
| Boss defeat burst | World-anchored boss shell + small screen-local accent | Collage tear / shutdown burst | Camera shake and SFX are external. |
| Rewind local burst | Player-local and world-local | Cyan/magenta shard burst, 12 frames max | Full-screen shader belongs to #16. |
| Scene transition cleanup | VFX manager local registry | Immediate stop/free of VFX-owned nodes | Must leave 0 active particles after transition. |

### C.4 Cause Mapping

| Cause | Visual signature | Color / shape guidance |
|---|---|---|
| `projectile_enemy_drone` | Thin aerial spark / eye-line scratch | Magenta core, black paper edge; small vertical bias. |
| `projectile_enemy_secbot` | Countable burst spark | Magenta-orange tick marks; three-pulse compatibility. |
| `projectile_boss` | Heavy collage tear / thick warning residue | Magenta + dirty white paper rip; never cyan-dominant. |
| `hazard_spike` / other hazard causes | Sharp floor/wall scrape | Yellow-white edge with black cutout silhouette. |
| `unknown` | Debug-only red X spark + `push_warning` path | Must not ship as final Tier 1 content. |
| ECHO projectile hit | Enemy/boss impact burst | Cyan muzzle identity plus magenta enemy impact core. |

If Damage #8 adds a new cause, VFX must update this table in the same cross-doc batch before that cause is considered presentation-ready.

### C.5 Near-Miss Rule

Damage #8 does not emit near-miss events. VFX performs a **passive proximity check** using existing projectile positions and target positions. This check is presentation-only and must not instantiate `Area2D`.

A near-miss is eligible when all are true:

1. a projectile passed within `near_miss_radius_px` of a valid opposing target during the current physics tick;
2. no Damage hit signal was emitted for that projectile in that tick;
3. the target/cause pair is not on cooldown;
4. the projectile or target owner still exists at callback time, or the pass point was cached before free.

Default Tier 1 tuning uses one radius (`24 px`) for both ECHO and hostile projectiles. Boss projectiles may use `32 px` only if visual readability testing shows the larger projectile silhouette needs a larger scrape envelope.

### C.6 Time Rewind Particle Rule

Godot 4.6 does not provide a design-approved reverse simulation path for `GPUParticles2D`. Therefore:

1. on `rewind_started`, VFX sets eligible `GPUParticles2D.emitting = false`;
2. it does not attempt to reverse existing particle simulation;
3. it may spawn a short player-local shard burst to mark activation;
4. it keeps forward-causality ambient effects paused during the REWINDING protection window;
5. on `rewind_protection_ended`, it restarts eligible looping particles, using `restart(keep_seed=true)` where implementation chooses `GPUParticles2D` and deterministic-looking restart is required.

`rewind_completed` is a restoration-anchor event, not the resume event. Particle resume before `rewind_protection_ended` is forbidden.

### C.7 Boss Phase Visual Rule

STRIDER phase readability is expressed through **shell state**, **stance**, and **attack telegraph vocabulary**, not HP. Tier 1 phase tags:

| Phase | VFX tag | Readable change |
|---:|---|---|
| 0 | `sealed_core` | Intact outer shell, minimal tear, single-lane warnings. |
| 1 | `split_shell` | One shell plate tears away; wider warning shapes. |
| 2 | `exposed_core` | Core glow visible; heavier warning residue and defeat-prep sparks. |

Final art specifics remain an asset-spec responsibility, but implementation and review can validate phase readability using these three tags before final sprites exist. This resolves Boss Pattern OQ-BOSS-1 at design-contract level while leaving exact art production to the art/spec pass.

### C.8 Camera and Anchor Rule

World combat VFX are world-anchored by default and naturally shake with Camera #3. Screen-space overlays are rare and must be explicitly classified as viewport-anchored.

| Anchor class | Examples | `camera.offset` use |
|---|---|---|
| World-anchored | impact spark, near-miss spark, enemy telegraph, boss shell burst | No compensation; effect moves with world shake. |
| Viewport-anchored | 1-frame death cut, Tier 2 letterbox, debug readout | May read `camera.offset` only to avoid double-shake or classify overlay. |
| Shader-owned | rewind color inversion / UV glitch | Not VFX #14; coordinate via #16 timing. |

VFX reads Camera #3 state only as public presentation state. It must not request new Camera signals for Tier 1.

### C.9 Scene Boundary Cleanup

VFX maintains a local registry of VFX-owned active one-shots and looping emitters. On `scene_will_change()`:

1. stop emission for all registered looping particles;
2. free detached one-shots immediately unless the node is already leaving tree;
3. clear the registry;
4. emit no gameplay or kill/death signals;
5. leave zero active VFX-owned particles after the scene transition boundary.

This subscription exists for cleanup only. Scene Manager #2 remains the scene lifecycle owner and is not a general presentation distribution hub.

---

## D. Formulas

### D.1 Near-Miss Predicate

```text
near_miss(projectile, target, frame) :=
  distance(projectile.global_position, target.global_position) <= near_miss_radius_px
  AND projectile.did_not_emit_damage_hit_this_frame
  AND frame - last_near_miss_frame[target_id, cause] >= near_miss_cooldown_frames
```

Tier 1 defaults:

```text
near_miss_radius_px = 24
boss_near_miss_radius_px = 32
near_miss_cooldown_frames = 10
```

### D.2 One-Shot Lifetime Conversion

```text
effect_lifetime_frames = ceil(effect_lifetime_seconds * 60)
```

All Tier 1 combat one-shots must complete within 45 frames. Death and impact readability should prefer 6–30 frames.

### D.3 Telegraph Visibility Invariant

```text
visible_telegraph_frames >= source_telegraph_frames
```

VFX may start before the source telegraph if a source system explicitly emits an earlier presentation signal, but it may not start late or end early for gameplay-lethal boss/enemy output.

### D.4 Draw-Call Budget

```text
vfx_draw_call_estimate =
  active_sprite_effect_draws
  + active_particle_material_draws
  + active_warning_overlay_draws
  + active_boss_burst_draws

vfx_draw_call_estimate <= vfx_peak_draw_call_limit
```

Tier 1 defaults:

```text
vfx_normal_draw_call_target = 60
vfx_peak_draw_call_limit = 100
```

The peak limit matches the Art Bible VFX allocation. If Collage Rendering #15 or Shader #16 later needs to borrow budget, VFX must reduce effect concurrency rather than exceed the 500 total draw-call project ceiling.

### D.5 Pool Size Budget

```text
vfx_one_shot_pool_size =
  projectile_cap
  + max_enemy_projectile_cap
  + boss_projectile_cap
  + boss_warning_cap
  + safety_margin
```

Tier 1 implementation target:

```text
vfx_one_shot_pool_size = 64
```

No per-frame allocation is allowed in the normal combat path after warmup.

### D.6 Rewind Resume Frame

```text
particle_resume_frame = rewind_protection_ended_frame
```

Particles paused on `rewind_started` may not resume on `rewind_completed`; `rewind_completed` only re-anchors restored player-local effects.

---

## E. Edge Cases

### E.1 Projectile hit and near-miss in same tick

If a projectile emits a Damage hit in the same tick that the passive near-miss predicate would pass, the hit wins and near-miss is suppressed.

### E.2 Projectile freed before impact VFX reads position

VFX must cache callback-time `global_position` before the owning projectile queues free. If no valid position exists, skip the visual rather than delaying gameplay free.

### E.3 Scene changes while particles are active

`scene_will_change()` cleanup wins. Active VFX-owned nodes are stopped/freed immediately. No natural-expiry exception is allowed in Tier 1 because cross-scene particles risk visual leftovers and invalid parent references.

### E.4 Rewind starts during boss telegraph

Time Rewind does not rewind boss state. Boss telegraph gameplay timing remains authoritative. VFX pauses forward-causality particles but must not cancel boss-owned pattern state. If Boss Pattern emits `boss_pattern_interrupted`, then warning-only VFX for the interrupted pattern is canceled by that signal.

### E.5 Boss phase advances while projectiles are already emitted

Already-emitted boss projectiles continue per Boss Pattern #11. VFX updates future phase shell/telegraph vocabulary but does not delete or retarget existing projectiles.

### E.6 Death is canceled by rewind

`lethal_hit_detected` may show local cause-read feedback. If SM/Time Rewind cancels pending death, VFX must not play `death_committed` flash/burst.

### E.7 Hazard grace after rewind

Damage #8 owns the 12-frame hazard-only grace after REWINDING exit. VFX may show a subtle floor scrape suppression only if it does not resemble invulnerability flicker and does not use the Player Movement i-frame color channel.

### E.8 Missing Camera reference

World-anchored VFX does not require a Camera reference. If a viewport-anchored overlay cannot read Camera #3, it falls back to no offset compensation rather than requesting new camera signals.

### E.9 GPUParticles2D restart unsupported by implementation wrapper

If a wrapper cannot call `restart(keep_seed=true)`, Tier 1 may use `Sprite2D`/`AnimatedSprite2D` one-shots for the affected effect. It must still honor pause/resume timing and draw-call limits.

### E.10 Too many simultaneous effects

When the pool or draw-call cap would be exceeded, VFX drops lowest-priority cosmetic effects in this order:

1. fallback weapon glitch;
2. non-lethal ambient shards;
3. near-miss sparks on cooldown boundary;
4. duplicate impact sparks in the same 4-frame window.

It must never drop gameplay-critical telegraphs for active lethal attacks.

### E.11 Unknown cause

Unknown causes use debug-only red X feedback and `push_warning` during development. Shipping Tier 1 content must have zero unknown-cause VFX occurrences in smoke tests.

### E.12 HUD overlap

VFX screen-space overlays must not cover HUD token, ammo, or boss phase widgets. If overlap is unavoidable during a boss defeat burst, HUD remains visually above VFX.

---

## F. Dependencies

### F.1 Upstream Dependencies

| # | System | Hardness | VFX consumes | Forbidden coupling |
|---|---|---|---|---|
| **#8** | [Damage / Hit Detection](damage.md) | Hard | cause taxonomy; `hurtbox_hit`, `enemy_killed`, `boss_hit_absorbed`, `boss_phase_advanced`, `boss_pattern_interrupted`, `boss_killed`, lethal/death signals | New cause ownership, HP data, damage decisions. |
| **#9** | [Time Rewind](time-rewind.md) | Hard | `rewind_started`, `rewind_completed`, `rewind_protection_ended` | Reverse particle simulation as gameplay rewind; token mutation. |
| **#7** | [Player Shooting](player-shooting.md) | Hard for muzzle/impact | `shot_fired`, `weapon_fallback_activated`, projectile callback-time position | Extra projectile payload requirements or projectile timing changes. |
| **#10** | [Enemy AI](enemy-ai.md) | Soft presentation | enemy telegraph/death signals and subtype cause timing | Enemy behavior mutation or attack retiming. |
| **#11** | [Boss Pattern](boss-pattern.md) | Hard for boss readability | boss telegraph, phase tag, interrupt, hit, and defeat contracts | Remaining-hit exposure or boss state rollback. |
| **#12** | [Stage / Encounter](stage-encounter.md) | Soft presentation | hazard/room telegraph timing, encounter hooks | Spawn order or activation mutation. |
| **#2** | [Scene Manager](scene-manager.md) | Hard cleanup boundary | `scene_will_change()` cleanup boundary | Scene swap calls or lifecycle ownership. |
| **#3** | [Camera](camera.md) | Soft presentation | `camera.offset` read for viewport-anchor classification | New camera signals, shake amplitude changes. |
| Art Bible | Visual direction | Hard | collage SF palette, readability, draw-call allocation | Pure bloom/gradient effects that break cutout identity. |

### F.2 Downstream Dependents

| # | System | Dependency | VFX provides |
|---|---|---|---|
| **#16** | [Time Rewind Visual Shader](time-rewind-visual-shader.md) | Timing handoff | Approved 2026-05-13. Particle pause/resume boundary and local vs full-screen ownership split; Shader owns fullscreen frames 0–18, VFX owns local shards/particles. |
| **#15** | [Collage Rendering Pipeline](collage-rendering.md) | Readability/budget constraint | Approved 2026-05-13. Provides background contrast, collage draw-call budget, fragment cap, and 0.2-second visual-read requirements that VFX must preserve. |
| QA / performance | Verification | Signal-spy hooks, draw-call counters, pool overflow assertions. |
| Asset Spec | Production art | effect names, atlas requirements, boss phase tags, near-miss assets. |

### F.3 Interface Catalog

| Interface | Owner | VFX use |
|---|---|---|
| `shot_fired(direction: int)` | Player Shooting #7 | muzzle flash only; no projectile spawn authority. |
| `weapon_fallback_activated(requested_id: int)` | Player Shooting #7 | optional local glitch. |
| `hurtbox_hit(cause: StringName)` | Damage/HurtBox #8 | cause-specific impact. |
| `enemy_killed(enemy_id, cause)` | Damage #8 | enemy death burst. |
| `boss_hit_absorbed(boss_id, phase_index)` | Damage/Boss #8/#11 | boss impact by phase only. |
| `boss_phase_advanced(boss_id, new_phase)` | Damage/Boss #8/#11 | shell tear / phase burst. |
| `boss_pattern_interrupted(boss_id, prev_phase_index)` | Damage/Boss #8/#11 | cancel warning-only telegraphs. |
| `boss_killed(boss_id)` | Damage/Boss #8/#11 | boss defeat burst. |
| `rewind_started(remaining_tokens)` | Time Rewind #9 | pause particles and local shard burst. |
| `rewind_completed(player, restored_to_frame)` | Time Rewind #9 | re-anchor player-local VFX. |
| `rewind_protection_ended(player)` | Time Rewind #9 | restart eligible particles. |
| `scene_will_change()` | Scene Manager #2 | cleanup only. |

### F.4 Cross-Doc Mirror Status

| Source / Target | Mirror Status | Required Follow-up |
|---|---|---|
| `systems-index.md` | Row #14 links this GDD and marks Approved 2026-05-13 | Shader #16 now approved; re-check only if Shader timing changes. |
| `damage.md` | Cause mapping, near-miss obligation, and boss signal consumer status mirrored | Re-check if Damage taxonomy changes. |
| `time-rewind.md` | Particle pause/restart and shader ownership split mirrored | Shader #16 consumes timing split in `time-rewind-visual-shader.md`. |
| `player-shooting.md` | Muzzle/impact/near-miss obligations mirrored | No extra signal payload required. |
| `boss-pattern.md` | Phase shell tags, telegraph, interrupt, and defeat VFX mirrored | Exact final art deferred to asset-spec. |
| `camera.md` | World-vs-viewport anchoring and `camera.offset` read pattern mirrored | No new Camera signal. |
| `collage-rendering.md` | Approved 2026-05-13 | Mirrors VFX draw-call/readability handoff and keeps VFX above gameplay/background composition. |
| `scene-manager.md` | Cleanup-only `scene_will_change` usage mirrored | VFX must not become presentation hub. |
| `enemy-ai.md` / `stage-encounter.md` | Presentation hook status updated | No gameplay contract change. |

---

## G. Tuning Knobs

| Knob | Type | Default | Safe Range | Affects | Too Low | Too High |
|---|---|---:|---:|---|---|---|
| `near_miss_radius_px` | int px | 24 | 12..48 | Near-miss readability | Player misses feedback | Sparks feel disconnected from bullets |
| `boss_near_miss_radius_px` | int px | 32 | 24..56 | Boss projectile scrape | Boss near-miss underreads | False-positive clutter |
| `near_miss_cooldown_frames` | int frames | 10 | 6..18 | Spark spam control | Visual noise | Misses feel silent |
| `muzzle_flash_frames` | int frames | 3 | 1..5 | Shot readability | Shot feels absent | Flash lingers too long |
| `impact_lifetime_frames` | int frames | 18 | 6..30 | Hit clarity | Hit pops invisibly | Screen clutter |
| `death_flash_frames` | int frames | 1 | 1..1 | Death cut | Not applicable | Longer whiteout hides cause-read |
| `rewind_local_burst_frames` | int frames | 12 | 6..18 | Rewind activation feel | Rewind too subtle | Conflicts with Shader #16 |
| `boss_phase_burst_frames` | int frames | 30 | 18..45 | Phase readability | Phase missed | Fight feels paused |
| `max_live_one_shot_vfx` | int nodes | 64 | 32..96 | Pool size | Drops valid effects | Memory/draw overhead |
| `vfx_normal_draw_call_target` | int calls | 60 | 40..80 | Steady-state rendering | Over-aggressive culling | Eats collage budget |
| `vfx_peak_draw_call_limit` | int calls | 100 | 80..100 | Boss/rewind peak | Boss climax underwhelms | Violates Art Bible allocation |
| `warning_overlay_alpha` | float | 0.55 | 0.35..0.75 | Telegraph readability | Warning invisible | Obscures bullets/player |

**Locked tuning constraints**:

- `death_flash_frames` remains 1 in Tier 1 to preserve death-cause readability.
- VFX cannot tune gameplay telegraph frame counts; it only mirrors source timings.
- Any increase above `vfx_peak_draw_call_limit=100` requires Art Bible / performance review.

---

## H. Acceptance Criteria

| ID | Criterion | Verification |
|---|---|---|
| **AC-VFX-01** | GIVEN VFX effects are active, WHEN their nodes are inspected, THEN none of them own gameplay collision `Area2D` hit checks or mutate Damage/Time Rewind/Enemy/Boss state. | Static scan + integration smoke. |
| **AC-VFX-02** | GIVEN `shot_fired(direction)` emits, WHEN VFX receives it, THEN a 3-frame muzzle flash appears at the authored muzzle offset and no projectile timing is changed. | Signal-spy + visual smoke. |
| **AC-VFX-03** | GIVEN a projectile passes within `near_miss_radius_px` and no Damage hit occurs that tick, WHEN cooldown is ready, THEN exactly one near-miss spark appears and no gameplay signal is emitted. | Unit/integration test. |
| **AC-VFX-04** | GIVEN a projectile emits a Damage hit in the same tick as a near-miss candidate, WHEN VFX evaluates the pass, THEN the hit spark appears and near-miss is suppressed. | Integration test. |
| **AC-VFX-05** | GIVEN Damage emits a known `cause`, WHEN VFX maps it, THEN the effect preset comes from C.4 and no new cause label is created. | Static mapping test. |
| **AC-VFX-06** | GIVEN `lethal_hit_detected(cause)` emits, WHEN VFX responds, THEN only local cause-read feedback appears; death flash waits for `death_committed`. | Signal-order test. |
| **AC-VFX-07** | GIVEN pending death is canceled by rewind, WHEN no `death_committed` emits, THEN no death burst or white cut plays. | Rewind integration test. |
| **AC-VFX-08** | GIVEN `death_committed(cause)` emits, WHEN VFX responds, THEN the death burst/cut plays once and does not obscure HUD beyond 1 frame. | Visual smoke. |
| **AC-VFX-09** | GIVEN `rewind_started` emits, WHEN VFX has active eligible particles, THEN forward-causality particles stop emitting and no reverse simulation is attempted. | Signal-spy + static scan. |
| **AC-VFX-10** | GIVEN `rewind_completed` emits before `rewind_protection_ended`, WHEN VFX processes both, THEN particles remain paused until `rewind_protection_ended`. | Integration test. |
| **AC-VFX-11** | GIVEN `rewind_protection_ended(player)` emits, WHEN VFX restarts eligible particles, THEN restart occurs no earlier than that frame and player-local effects are re-anchored to the restored player. | Integration test. |
| **AC-VFX-12** | GIVEN an enemy attack has `wind_up_frames` / telegraph frames, WHEN VFX renders the warning, THEN the visual telegraph is visible for the full source telegraph window. | Visual review + frame counter. |
| **AC-VFX-13** | GIVEN `boss_hit_absorbed(boss_id, phase_index)` emits, WHEN VFX renders the impact, THEN it uses `phase_index` only and exposes no remaining-hit or HP value. | Signal spy + UI review. |
| **AC-VFX-14** | GIVEN `boss_phase_advanced(boss_id, new_phase)` emits, WHEN VFX renders phase transition, THEN shell/stance tag changes according to C.7 and no boss state rollback occurs after player rewind. | Integration + visual review. |
| **AC-VFX-15** | GIVEN `boss_pattern_interrupted` emits, WHEN warning-only boss VFX exists for that pattern, THEN uncommitted warning VFX is canceled while already-emitted projectiles remain unaffected. | Integration test. |
| **AC-VFX-16** | GIVEN `boss_killed(boss_id)` emits, WHEN VFX renders defeat burst, THEN it plays once, stays within draw-call budget, and does not trigger Audio or Camera behavior directly. | Signal-spy + perf smoke. |
| **AC-VFX-17** | GIVEN Camera shake is active, WHEN world-anchored VFX plays, THEN the effect naturally moves with world shake; viewport overlays avoid double-shake using read-only `camera.offset` if needed. | Visual smoke. |
| **AC-VFX-18** | GIVEN `scene_will_change()` emits, WHEN VFX cleanup runs, THEN all VFX-owned active particles/one-shots are stopped or freed and registry count becomes 0. | Integration test. |
| **AC-VFX-19** | GIVEN peak Tier 1 boss + rewind effects are active, WHEN render stats are sampled, THEN VFX draw calls are ≤100 and steady combat target is ≤60. | Performance capture. |
| **AC-VFX-20** | GIVEN shipping Tier 1 smoke tests run, WHEN VFX cause mapping is inspected, THEN unknown-cause debug VFX occurs 0 times. | Automated smoke assertion. |

---

## Visual / Audio Requirements

VFX owns visual effects only. Audio cue timing may share source signals, but Audio #4 owns cue names, bus routing, pitch jitter, and playback pools.

| Moment | VFX owner behavior | Audio owner behavior |
|---|---|---|
| ECHO shot | 3-frame muzzle flash | Audio #4 `shot_fired` cue. |
| Enemy/boss hit | Cause-specific impact spark | Audio #4 optional hit/defeat cue. |
| Player lethal read | Local cause spark | Audio #4 player death/denial cue. |
| Death committed | 1-frame cut + burst | Audio #4 death cue; Scene Manager owns restart. |
| Rewind start | Pause particles + local shard burst | Audio #4 duck + rewind activate cue. |
| Boss phase advance | Shell tear / phase burst | Audio #4 optional phase cue. |
| Boss defeated | Collage tear / shutdown burst | Audio #4 defeated sting; Camera #3 shake. |

Asset names reserved for Tier 1 asset-spec:

| Asset | Purpose |
|---|---|
| `atlas_vfx_tier1.png` | Shared muzzle, impact, near-miss, small telegraph cells. |
| `vfx_impact_enemy_magenta_small.png` | Standard enemy impact. |
| `vfx_near_miss_paper_scratch_small.png` | Near-miss spark. |
| `vfx_rewind_shard_burst_small.png` | Local rewind burst. |
| `vfx_boss_phase_shell_tear.png` | Boss phase burst. |
| `vfx_boss_defeat_collage_tear.png` | Boss defeat burst. |

---

## UI Requirements

VFX does not own production HUD widgets.

| UI-like surface | Owner | VFX rule |
|---|---|---|
| Token counter / token denied display | HUD #13 | VFX may only add local character burst; no token UI. |
| Ammo / weapon icon | HUD #13 | VFX may show muzzle/fallback local effect; no ammo UI. |
| Boss title / phase pulse | HUD #13 | VFX handles boss world-shell burst only. |
| Death or victory overlay | HUD #13 / Scene Manager #2 depending surface | VFX may supply 1-frame cut or world burst, not screen flow. |
| Debug draw-call / pool overlay | QA/debug only | Must be disabled in production builds. |

---

## Cross-References

- `design/gdd/damage.md` — cause taxonomy, one-hit rule, boss phase signals, near-miss obligation.
- `design/gdd/time-rewind.md` — rewind lifecycle signals and GPUParticles2D pause/restart workaround.
- `design/gdd/player-shooting.md` — `shot_fired`, projectile cap, muzzle flash art direction, no extra payload.
- `design/gdd/enemy-ai.md` — enemy telegraph and presentation signal timing.
- `design/gdd/boss-pattern.md` — STRIDER phase tags, telegraphs, interrupt cleanup, defeat burst.
- `design/gdd/stage-encounter.md` — hazard/encounter presentation hooks and Area2D budget.
- `design/gdd/scene-manager.md` — `scene_will_change` cleanup boundary.
- `design/gdd/camera.md` — world-vs-viewport anchoring and `camera.offset` read-only use.
- `design/art/art-bible.md` — collage SF palette, 0.2-second readability, VFX draw-call allocation.
- `docs/engine-reference/godot/modules/rendering.md` — Godot 4.6 rendering and particles reference.

---

## Open Questions

| ID | Question | Owner | Timing | Blocking? | Notes |
|---|---|---|---|---|---|
| OQ-VFX-1 | Final exact sprite/atlas cells for impact, near-miss, rewind shards, and boss phase tears? | art-director + technical-artist | `/asset-spec system:vfx-particle` | No for design-review; yes for production art | This GDD defines behavior and tags. |
| OQ-VFX-2 | Does Tier 1 need Line2D projectile trails after performance capture? | technical-artist + performance analyst | After first combat test scene | No | Default is no trail to protect draw calls. |
| OQ-VFX-3 | Should boss near-miss radius use 24 px or 32 px in production? | game-designer + QA | Boss playtest | No | Default contract allows 32 px only for boss projectile readability. |
| OQ-VFX-4 | ✅ Resolved 2026-05-13 by `time-rewind-visual-shader.md`: Shader starts on `rewind_started`, visible fullscreen intensity runs frames 0–18, uses a protection-aligned internal controller, and does not terminate from `rewind_completed`. | shader specialist | Closed by Shader #16 approval | No for VFX | VFX owns particle pause/resume; Shader owns full-screen. |
| OQ-VFX-5 | Steam Deck Gen 1 draw-call headroom for peak boss + rewind burst? | performance analyst | Tier 1 device session | No for authoring; yes before production proof | AC-VFX-19 captures the gate. |

---

## Deferred Follow-Up Actions

1. Run `/design-review design/gdd/vfx-particle.md --depth lean` in a fresh session.
2. Run `/asset-spec system:vfx-particle` after design-review approval.
3. Re-check Shader #16 timing and the full-screen ownership boundary only if Shader #16 is revised.
4. During implementation, add signal-spy tests for AC-VFX-03, AC-VFX-09, AC-VFX-10, AC-VFX-18, and AC-VFX-19 first.
