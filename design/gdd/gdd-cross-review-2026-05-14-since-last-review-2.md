# Cross-GDD Review Report

**Date**: 2026-05-14  
**Mode**: `/review-all-gdds since-last-review`  
**Baseline**: latest prior review file `design/gdd/gdd-cross-review-2026-05-14-since-last-review.md` written 2026-05-14 09:39 +0900  
**Scope rule**: no committed GDD changes exist after the baseline timestamp; this pass reviewed working-tree GDD files modified after the baseline plus their directly affected dependency mirrors.  
**In-scope changed anchors / GDDs**: `game-concept.md`, `camera.md`, `hud.md`, `stage-encounter.md`, `systems-index.md`.  
**Targeted dependency anchors checked**: `time-rewind.md`, `time-rewind-visual-shader.md`, `boss-pattern.md`, `design/registry/entities.yaml`.  
**Summary scan note**: current GDDs still do not use `## Summary`; this pass used Overview/A sections, status headers, dependency tables, registry constants, and targeted stale-reference scans.  
**Registry baseline**: `design/registry/entities.yaml` exists. The shader registry still records `rewind_shader_fullscreen_active_frames = 18` frames and zero visible fullscreen intensity by frame 19.

---

## Verdict: **CONCERNS**

No blocking contradiction was found. The prior since-last-review warnings for `systems-index.md`, `hud.md`, and `stage-encounter.md` are now resolved. Two warning-level concerns remain:

1. `camera.md` still carries stale downstream mirror statuses for Stage #12 and Boss Pattern #11, plus an old systems-index obligation phrased as `Not Started → Designed`.
2. `game-concept.md` still says the rewind shader/color inversion lasts `1 second`, while the approved Time Rewind / Shader contracts define an approximately 0.5-second recognition window and an 18-frame fullscreen active window.

| Phase | Blocking | Warning | Notes |
|---|---:|---:|---|
| Phase 2 — Cross-GDD Consistency | 0 | 2 | Status/mirror drift and shader-duration copy drift |
| Phase 3 — Game Design Holism | 0 | 2 | Prior attention-budget and AimLock playtest risks remain warning-level |
| Phase 4 — Cross-System Scenarios | 0 | 1 | Runtime chains remain coherent; documentation drift can mislead implementation/test specs |
| **Total unique findings** | **0** | **5** | No architecture-blocking issue found |

---

## Loaded Scope Manifest

### Changed since baseline

- `game-concept.md` — Approved concept copy was updated to align restore depth with ADR-0002: 1.5-second capture window, 0.15-second restore depth (`game-concept.md:4`, `game-concept.md:49`, `game-concept.md:75`, `game-concept.md:250`).
- `camera.md` — Approved Camera #3 sync updated 2026-05-14, but stale mirror/status rows remain (`camera.md:3-8`, `camera.md:686-687`, `camera.md:723`).
- `hud.md` — prior Boss Pattern mirror warning is fixed; Boss Pattern #11 now says Approved 2026-05-13 (`hud.md:353-357`).
- `stage-encounter.md` — prior Stage F.3 mirror warning is fixed; Scene Manager and Enemy AI rows now say Stage is mirrored as Approved and closed (`stage-encounter.md:475-481`).
- `systems-index.md` — prior reviewed-count warning is fixed; reviewed and approved counts both now say 18 (`systems-index.md:185-199`).

### Key dependency/anchor checks

- `boss-pattern.md` status is Approved (`boss-pattern.md:3`) and explicitly says no Tier 1 camera zoom requirement (`boss-pattern.md:649-651`).
- `time-rewind.md` says the visual signature plays for approximately 0.5 seconds (`time-rewind.md:17`, `time-rewind.md:60`) and mirrors Shader #16 as frames 0-18 visible/off for frames 19-30 (`time-rewind.md:143`, `time-rewind.md:472`).
- `time-rewind-visual-shader.md` says the shader must be recognizable within 0.5 seconds and visible fullscreen intensity must be zero by frame 19 (`time-rewind-visual-shader.md:18`, `time-rewind-visual-shader.md:75-76`, `time-rewind-visual-shader.md:384`, `time-rewind-visual-shader.md:399`).
- `design/registry/entities.yaml` records `rewind_shader_fullscreen_active_frames = 18` frames and frames 19-30 reserved for local i-frame readability signal (`entities.yaml:320-329`).

---

## Consistency Issues

### Blocking

None.

### Warnings

#### ⚠️ W2-1 — Camera mirror tables still carry stale Stage/Boss statuses

`camera.md` has several stale status/mirror rows even though the referenced GDDs are now approved:

- `camera.md` C.3.3 still says `systems-index.md` row #3 should move Camera from `Not Started → Designed (or Approved post-review)` (`camera.md:355-370`), while `systems-index.md` already lists Camera #3 as Approved (`systems-index.md:25-27`) and the Camera GDD status is Approved (`camera.md:3`).
- `camera.md` F.2 lists Stage / Encounter #12 as `Not Started` (`camera.md:686`), while `stage-encounter.md` is Approved (`stage-encounter.md:3`) and now defines `stage_camera_limits` as a Stage-owned data interface consumed by Scene Manager → Camera (`stage-encounter.md:486-490`).
- `camera.md` F.2 lists Boss Pattern #11 as `Designed pending review 2026-05-13` (`camera.md:687`), while `boss-pattern.md` is Approved (`boss-pattern.md:3`) and confirms no Tier 1 zoom requirement (`boss-pattern.md:649-651`).
- `camera.md` F.4.2 says Stage must decide the stage-limit exposure pattern when Stage is written (`camera.md:723`), but Stage is written and supplies immutable `stage_camera_limits` through Scene Manager → Camera (`stage-encounter.md:490`).

**Concern**: runtime design is coherent, but Camera's dependency tables can mislead architecture/story generation into treating Stage and Boss as not-yet-approved or unresolved.

**Recommendation**: update Camera C.3.3/F.2/F.4.2 to mark the systems-index row, Stage #12, and Boss Pattern #11 obligations as closed/approved. For Stage, point at `stage_camera_limits` in `stage-encounter.md` F.4.

#### ⚠️ W2-2 — Game Concept still says rewind shader lasts `1 second`

`game-concept.md` correctly fixes the mechanical rewind copy to 1.5-second lookback / 0.15-second restore depth (`game-concept.md:49`, `game-concept.md:75`, `game-concept.md:250`), but two presentation lines still claim a 1-second shader/read:

- Feedback clarity: `screen shader (color inversion 1 second)` (`game-concept.md:101`).
- Visual Identity Anchor: screen “plays in reverse” for `1 second` (`game-concept.md:324`).

Approved downstream contracts disagree:

- `time-rewind.md` defines approximately 0.5 seconds for the visual signature (`time-rewind.md:17`, `time-rewind.md:60`).
- `time-rewind-visual-shader.md` requires recognition within 0.5 seconds and zero visible fullscreen intensity by frame 19 (`time-rewind-visual-shader.md:18`, `time-rewind-visual-shader.md:75-76`, `time-rewind-visual-shader.md:384`, `time-rewind-visual-shader.md:399`).
- `design/registry/entities.yaml` records `rewind_shader_fullscreen_active_frames = 18` frames (`entities.yaml:320-329`).

**Concern**: this is concept-copy drift, not a runtime-rule blocker. However, the concept is the source anchor for product/design briefs; leaving `1 second` there can produce incorrect test criteria, art direction, or UX copy.

**Recommendation**: change those concept lines to the canonical framing: “recognizable within 0.5 seconds; fullscreen inversion/glitch active for frames 1-18, with the protection controller continuing to frame 30.”

---

## Resolved Since Prior Review

### ✅ Prior W2-1 — Systems Index reviewed-count ledger fixed

`systems-index.md` now records 18 design docs started, 18 reviewed, 18 approved/locked, 0 Needs Revision, and 0 Designed pending review (`systems-index.md:185-199`). This resolves the prior reviewed-count warning.

### ✅ Prior W2-2 — HUD Boss Pattern mirror fixed

`hud.md` F.1 now lists Boss Pattern #11 as `Approved 2026-05-13` (`hud.md:353-357`). This resolves the prior HUD status warning.

### ✅ Prior W2-3 — Stage F.3 mirror wording fixed

`stage-encounter.md` F.3 now says Scene Manager and Enemy AI mirror Stage as Approved and that both rows are closed unless lifecycle/spawn contracts change (`stage-encounter.md:475-481`). This resolves the prior Stage mirror wording warning.

---

## Game Design Issues

### Blocking

None.

### Warnings

#### ⚠️ W3-1 — Core attention budget remains at the comfortable ceiling

The core loop still asks players to manage four active concerns at once:

1. Player Movement — position/jump timing.
2. Player Shooting — aim direction, fire cadence, projectile cap feel.
3. Enemy/Boss pattern reading — Drone, Security Bot, STRIDER telegraphs.
4. Time Rewind decision — DYING window, tokens, and recovery timing.

The changed HUD/Stage/Camera docs remain presentation/infrastructure-supportive rather than adding a new active combat decision. This is acceptable but still tight.

**Recommendation**: preserve Stage's one-new-read-per-room tuning and keep HUD/VFX/Camera feedback clarifying rather than adding active decisions.

#### ⚠️ W3-2 — AimLock turret dominance remains an empirical playtest risk

No new dominant strategy was introduced. The prior risk still applies: if AimLock + hold-fire is safer than movement in most rooms, it can dominate. Stage's Security Bot room remains the mitigation path because it explicitly teaches anti-stationary pressure, but this still needs playtest proof.

**Recommendation**: keep the Systems Index D1 playtest item active and measure stationary AimLock combat time, deaths while stationary, and clear-time delta between AimLock-heavy and movement-heavy play.

---

## Cross-System Scenario Issues

Scenarios walked:

1. Concept pitch → Time Rewind GDD → Shader #16 → registry constants.
2. Stage load → Scene Manager `scene_post_loaded(anchor, limits)` → Camera snap/limits.
3. Boss killed → Damage `boss_killed` → Camera shake / no Tier 1 zoom.
4. HUD combat read → Camera screen-space boundary.
5. Lethal hit → rewind consume → Camera freeze/snap + Shader visible window + HUD token update.

### Blockers

None.

### Warnings

#### ⚠️ S1 — Rewind visual duration handoff can produce incorrect implementation/test criteria

**Systems involved**: `game-concept.md`, Time Rewind #9, Shader #16, registry constants, HUD/Camera presentation chain.

**Step where failure occurs**: concept-to-implementation handoff. The concept still says 1-second color inversion (`game-concept.md:101`, `game-concept.md:324`), but the approved implementation-facing contracts require a shorter visible fullscreen shader window: approximately 0.5 seconds in Time Rewind and zero visible fullscreen intensity by frame 19 in Shader #16/registry (`time-rewind.md:17`, `time-rewind-visual-shader.md:75-76`, `entities.yaml:320-329`).

**Nature of failure mode**: stale reference / contradictory messaging. Runtime ownership is clear, but a generated story, QA criterion, or art brief using the concept line could assert the wrong duration.

**Recommendation**: revise the two concept lines now, before generating prototype stories or QA specs from the concept.

### Info

#### ℹ️ Stage → Camera limit delivery is coherent despite Camera's stale mirror rows

Stage now owns `stage_camera_limits` and routes it through Scene Manager → Camera (`stage-encounter.md:490`). Camera's runtime rules for `scene_post_loaded(anchor, limits)` remain coherent (`camera.md:250-268`, `camera.md:951`). The issue is documentation freshness, not a design-breaker.

#### ℹ️ Boss kill presentation chain remains coherent

Boss Pattern is Approved, has no Tier 1 camera zoom dependency, and uses the existing `boss_killed` event consumed by Camera shake (`boss-pattern.md:3`, `boss-pattern.md:647-651`; `camera.md:187`, `camera.md:701`). Camera's stale Boss status row should be fixed, but no new runtime signal is required.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| `camera.md` | Stage #12 and Boss Pattern #11 mirror/status rows are stale; Stage obligation is already closed by `stage_camera_limits` | Consistency | Warning |
| `game-concept.md` | Rewind shader duration copy says `1 second`, conflicting with approved 0.5s / 18-frame shader contracts | Consistency / product copy | Warning |

---

## Required Actions Before Re-Running `/review-all-gdds`

No blocking actions required.

### Should fix

1. Update `camera.md` C.3.3/F.2/F.4.2 mirror rows for Systems Index, Stage #12, and Boss Pattern #11.
2. Update `game-concept.md` line 101 and line 324 to use the canonical Shader #16 timing language.
3. Re-run `/review-all-gdds since-last-review` after those edits; expected verdict should be PASS or low CONCERNS with only empirical playtest warnings remaining.

---

## Handoff Recommendation

Because the verdict is CONCERNS with no blockers, the pipeline can continue to `/gate-check pre-production` after the two warning-level doc cleanups, or proceed now if the team accepts the mirror/copy warnings as non-blocking.
