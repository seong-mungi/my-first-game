# Cross-GDD Review Report

**Date**: 2026-05-14  
**Mode**: `/review-all-gdds full`  
**Scope**: 18 MVP system GDDs plus anchor docs `game-concept.md`, `systems-index.md`, and `design/registry/entities.yaml`  
**Summary scan note**: current `design/gdd/*.md` files do not use `## Summary`; this pass used `Overview` / `A. Overview` sections and status headers for the manifest.  
**Registry baseline**: `design/registry/entities.yaml` exists and contains active entries for ECHO, STRIDER, rewind / movement / shooting / presentation constants, and 67 registered constants.  

---

## GDD Manifest

System GDDs reviewed:

- `audio.md` — Approved · 2026-05-12
- `boss-pattern.md` — Approved
- `camera.md` — Approved · 2026-05-13
- `collage-rendering.md` — Approved · 2026-05-13
- `damage.md` — LOCKED for prototype · 2026-05-13 re-verified
- `enemy-ai.md` — Approved
- `hud.md` — Approved
- `input.md` — Approved · 2026-05-11
- `menu-pause.md` — Designed
- `player-movement.md` — Approved
- `player-shooting.md` — Approved · 2026-05-11
- `scene-manager.md` — Approved · 2026-05-13
- `stage-encounter.md` — Approved
- `state-machine.md` — Approved
- `story-intro-text.md` — Approved
- `time-rewind-visual-shader.md` — Approved · 2026-05-13
- `time-rewind.md` — Approved · 2026-05-11
- `vfx-particle.md` — Approved · 2026-05-13

Loaded 18 system GDDs covering the full MVP system set: Input, Scene Manager, Camera, Audio, State Machine, Player Movement, Player Shooting, Damage, Time Rewind, Enemy AI, Boss Pattern, Stage / Encounter, HUD, VFX, Collage Rendering, Time Rewind Visual Shader, Story Intro Text, and Menu / Pause.

Design pillars from `game-concept.md`:

1. Time Rewind is a learning tool, not a punishment.
2. Deterministic Patterns — luck is the enemy.
3. Collage is the first impression — screenshot = marketing.
4. 5-Minute Rule — immediate core loop.
5. First game = small success > big ambition.

Anti-pillars checked: no linear story bloat, no RPG progression sprawl, no multi-weapon inventory in Tier 1, no original music burden in Tier 1, no cutscene-heavy delivery, and no Tier 1 remapping/localization/accessibility stack.

---

## Verdict: **FAIL**

Two blocking issues must be resolved before architecture / implementation planning treats the MVP GDD set as stable:

1. `menu-pause.md` remains **Designed** and has no review log, while all other MVP GDDs are Approved or Locked.
2. `stage-encounter.md` does not close Player Shooting #7's required `Projectiles: Node2D` stage-root container contract.

| Phase | Blocking | Warning | Notes |
|---|---:|---:|---|
| Phase 2 — Cross-GDD Consistency | 1 | 7 | One functional contract gap plus stale mirror/status drift |
| Phase 3 — Game Design Holism | 1 | 3 | MVP approval gate blocker plus attention / playtest risks |
| Phase 4 — Cross-System Scenarios | 1 | 2 | Projectile-spawn chain is blocked by missing Stage contract |
| **Total unique findings** | **2** | **10** | Some warnings overlap phases |

---

## Consistency Issues

### Blocking

#### 🔴 B2-1 — Stage #12 does not define Player Shooting's required `Projectiles: Node2D` container

`player-shooting.md` requires the Stage scene root to host a named `Projectiles: Node2D` child:

- `player-shooting.md` C.3.7 says Stage #12 must provide `Projectiles: Node2D` as a root child, and that `WeaponSlot` finds it with `get_tree().current_scene.find_child("Projectiles", true, false)`.
- `player-shooting.md` F.1 still lists Stage #12 as `Not Started` and marks this interface `Soft *(provisional)*`.
- `player-shooting.md` says Stage's H section must include an AC for this container.

`stage-encounter.md` is now Approved, but a targeted scan found no `Projectiles` container contract, no `Projectiles: Node2D` data field, and no acceptance criterion covering the Player Shooting container. Stage does mention enemy projectile caps and generic `other_damage_area2d_count`, but not the player-projectile spawn host required by #7.

**Risk**: the core loop can reach "shoot" and fail to spawn bullets or push an implementation error because the required container is absent. This blocks the Move → Spot enemy → Shoot → Survive loop.

**Fix locus**:

- `stage-encounter.md`: add the `Projectiles: Node2D` root-child contract to C.1/C.3/F.4 and add an AC such as "Stage scene root contains one named `Projectiles: Node2D` child before gameplay activation."
- `player-shooting.md`: update Stage #12 status from `Not Started` to Approved and close the F.4.2 obligation after Stage is patched.
- Optional: register the scene-node contract in `docs/registry/architecture.yaml` if implementation tooling will grep scene contracts.

### Warnings

#### ⚠️ W2-1 — `menu-pause.md` is still Designed, not Approved

`systems-index.md` row #18 and `menu-pause.md` both mark Menu / Pause as `Designed · 2026-05-13`. No `design/gdd/reviews/menu-pause-review-log.md` exists. This is not a contradiction inside the GDD body, but it is a readiness mismatch for architecture gate criteria.

**Recommendation**: run `/design-review design/gdd/menu-pause.md --depth lean`, then update `systems-index.md` counts / status if approved.

#### ⚠️ W2-2 — Systems Index still describes Menu #18 as a "minimal title/menu shell"

`systems-index.md` Presentation Layer says Menu / Pause is "pause overlay, minimal title/menu shell, session-only options." `menu-pause.md` explicitly rejects a Tier 1 title/menu shell:

- Rule 6: cold boot remains Story Intro #17 → Scene Manager #2; Menu/Pause must not block first core-loop entry.
- Rule 7: return-to-title/title-shell routing is deferred.
- AC-MENU-15: `Return to Title`, `Start`, and `Continue` are absent in production Tier 1.

**Recommendation**: change the Systems Index description to "pause overlay and session-only options; title shell deferred."

#### ⚠️ W2-3 — Camera mirror rows still carry stale Stage/Boss statuses

`camera.md` F.2 lists:

- Stage / Encounter #12 as `Not Started`, though `stage-encounter.md` is Approved and defines `stage_camera_limits`.
- Boss Pattern #11 as `Designed pending review 2026-05-13`, though `boss-pattern.md` is Approved and explicitly rejects Tier 1 camera zoom.

The behavior contracts are otherwise coherent. This is mirror/status drift.

#### ⚠️ W2-4 — Enemy AI mirror still marks Shader #16 as Not Started

`enemy-ai.md` F.1 lists Time Rewind Visual Shader #16 as `Not Started`. `time-rewind-visual-shader.md` is Approved and contains the required readability rule: enemy-vs-ECHO identity cannot rely on cyan/magenta color alone during inversion.

**Recommendation**: update the mirror row to Approved and cite Shader #16 C.6.

#### ⚠️ W2-5 — HUD Boss Pattern mirror still says "Designed pending review"

`hud.md` F.1 lists Boss Pattern #11 as `Designed pending review`. `boss-pattern.md` is now Approved and locks `boss_phase_advanced` / `boss_killed` UI boundaries with no HP or hit counter.

**Recommendation**: update HUD #13's dependency row to Approved.

#### ⚠️ W2-6 — Story Intro / Systems Index status drift

`story-intro-text.md` and `design/gdd/reviews/story-intro-text-review-log.md` show Story Intro #17 Approved, and `systems-index.md` row #17 also says Approved. However, `systems-index.md` Next Steps still says "`/design-system story-intro-text` (#17) — Designed 2026-05-13."

**Recommendation**: update the Next Steps line to Approved.

#### ⚠️ W2-7 — Time Rewind's dependency preamble is stale

`time-rewind.md` still says "All dependent systems have GDDs not yet written, so interfaces are marked provisional," even though Boss Pattern #11, HUD #13, VFX #14, Shader #16, Audio #4, and others are now authored/approved and mirrored later in the same section.

**Recommendation**: replace the old blanket preamble with "Historical note: originally provisional; current rows below reflect authored downstream GDDs."

---

## Game Design Issues

### Blocking

#### 🔴 B3-1 — MVP design set is not gate-ready while Menu / Pause #18 is unreviewed

The Systems Index gate says `/gate-check pre-production` comes after all MVP 18 GDDs are Approved plus reciprocal batches landed. Current state is 17 Approved/Locked and 1 Designed. Because Menu/Pause owns pause cheating prevention, restart UI, session volume, quit, focus recovery, and the "no title shell" boundary, it should not be carried into architecture as unreviewed design.

**Required action**: review and either approve or revise `menu-pause.md` before architecture begins.

### Warnings

#### ⚠️ W3-1 — Core attention budget is at the comfortable ceiling

Typical active systems during gameplay:

1. Player Movement — continuous positioning / jump timing.
2. Player Shooting — aim direction, fire cadence, projectile cap feel.
3. Enemy / hazard / boss pattern reading — Drone, Security Bot, STRIDER telegraphs.
4. Time Rewind decision — 12-frame DYING window, tokens, and recovery timing.

HUD, Camera, Audio, VFX, Shader, and Collage are correctly passive presentation layers. Stage is mostly authoring/activation infrastructure. This keeps the moment-to-moment budget near 4 active systems, which is acceptable but tight.

**Recommendation**: implementation stories should preserve Enemy AI's "one problem at a time" rule and keep HUD/VFX feedback clarifying, not adding active decisions.

#### ⚠️ W3-2 — AimLock turret dominance is mitigated but still needs playtest proof

The previous risk is mostly addressed:

- `enemy-ai.md` and `stage-encounter.md` include Security Bot / anti-stationary pressure.
- `boss-pattern.md` makes STRIDER a deterministic final exam rather than a static target.

However, the risk remains empirical: if AimLock plus hold-fire is safer than movement in most rooms, it can dominate. Systems Index already tracks D1 as a Tier 1 playtest item.

**Recommendation**: keep D1 active and add a playtest metric: percentage of combat time spent stationary in AimLock, deaths caused while stationary, and clear-time delta between AimLock-heavy and movement-heavy play.

#### ⚠️ W3-3 — Projectile cap silent skip may become a perceived input drop

Player Shooting intentionally uses `PROJECTILE_CAP = 8` with silent skip when the cap is reached. At default fire/lifetime values, the theoretical max concurrent projectiles is `90 / 10 = 9`, so sustained fire can skip roughly one shot per cap cycle. This is deterministic and documented, but it interacts with Pillar 4 immediate feel and HUD's secondary ammo readout.

**Recommendation**: treat the existing Player Shooting playtest item as important: if players perceive "my gun ignored me," raise cap to 12+ or reduce projectile lifetime.

---

## Cross-System Scenario Issues

Scenarios walked:

1. Cold boot → Story Intro → first input route → Stage 1 load.
2. Stage room activation → enemy spawn → player shooting → damage / VFX / audio.
3. Lethal hit → DYING grace → rewind consume → restore → camera / shader / HUD / VFX settle.
4. Boss final hit → `boss_killed` → token grant → HUD/victory/audio/camera/VFX → Scene Manager clear.
5. Pause during ALIVE vs DYING/REWINDING.
6. Scene boundary while presentation autoloads and stage-local nodes clean up.

### Blockers

#### 🔴 S2 — Stage room activation → player shooting chain lacks a projectile host

**Systems involved**: Stage / Encounter #12, Player Shooting #7, Scene Manager #2, Damage #8.

**Step where failure occurs**:

1. Stage loads and Scene Manager emits `scene_post_loaded(anchor, limits)`.
2. Player presses shoot.
3. Player Shooting attempts to resolve `current_scene.find_child("Projectiles", true, false)`.
4. Stage #12 has no authored `Projectiles: Node2D` contract or AC.

**Failure mode**: undefined / implementation-dependent projectile spawn host. The player can have valid input, valid ammo, and a valid Damage HitBox class, but still fail to create player projectiles in the stage scene.

**Required fix**: add the stage-root `Projectiles` container contract and AC to `stage-encounter.md`, then close `player-shooting.md`'s Stage #12 dependency row.

### Warnings

#### ⚠️ S4 — Boss kill + player death priority is well-specified but should receive an integration test across all consumers

Scene Manager says CLEAR_PENDING beats RESTART_PENDING, Time Rewind says same-tick consume/grant is net-zero, Boss Pattern delegates ordering to Time Rewind, HUD does not decide priority locally, and Audio/VFX/Camera are presentation-only. The design is coherent.

**Risk**: this is a many-consumer event. A single integration test should assert final boundary state, token count, HUD display timing, and one-shot audio/VFX/camera responses.

#### ⚠️ S5 — Pause design is coherent but unreviewed

Menu/Pause correctly routes pause through Input #1's PauseHandler and State Machine #5's `can_pause()` / `should_swallow_pause()` boundary. It rejects pause during DYING/REWINDING and allows resume from paused state.

**Risk**: this is exactly the kind of UX/system boundary where review catches exploit and focus traps. The unreviewed status is the issue, not the current design content.

### Info

#### ℹ️ Presentation stack ownership is coherent

Camera, VFX, Time Rewind Visual Shader, Collage, Audio, HUD, Story Intro, and Menu/Pause all keep their ownership boundaries: no presentation GDD mutates tokens, damage, scene state, boss phases, or projectile behavior. The main remaining presentation issues are mirror/status cleanup, not design contradiction.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| `stage-encounter.md` | Missing required `Projectiles: Node2D` root-child contract and AC required by Player Shooting #7 | Consistency / Scenario | Blocking |
| `player-shooting.md` | Stage #12 row still `Not Started`; close obligation after Stage adds `Projectiles` contract | Consistency | Blocking follow-up |
| `menu-pause.md` | Designed but not reviewed/approved; architecture gate should not consume it as stable | Readiness / Design Review | Blocking |
| `systems-index.md` | Menu title-shell contradiction; Story Intro Next Steps stale; #18 still Designed | Consistency / Readiness | Warning |
| `camera.md` | Stage/Boss mirror statuses stale | Consistency | Warning |
| `enemy-ai.md` | Shader #16 mirror status stale | Consistency | Warning |
| `hud.md` | Boss Pattern #11 status stale | Consistency | Warning |
| `time-rewind.md` | Dependency preamble says dependents not yet written despite authored rows | Consistency | Warning |

---

## Required Actions Before Re-Running `/review-all-gdds`

### Must fix

1. Add `Projectiles: Node2D` root-child contract to `stage-encounter.md`.
2. Update `player-shooting.md` Stage #12 dependency row from `Not Started` / provisional to the approved Stage contract after item 1 lands.
3. Run `/design-review design/gdd/menu-pause.md --depth lean`; apply required fixes if the review does not approve.

### Should fix

4. Update `systems-index.md` wording for Menu #18 to remove "title/menu shell" from Tier 1 and update Story Intro's Next Steps line to Approved.
5. Clean stale status mirrors in `camera.md`, `enemy-ai.md`, `hud.md`, and `time-rewind.md`.
6. Add one integration test spec/story later for same-tick boss kill + player death across Scene Manager, Time Rewind, HUD, Audio, Camera, and VFX.

---

## Recommended Next

1. Apply the Stage / Player Shooting contract fix.
2. Run `/design-review design/gdd/menu-pause.md --depth lean`.
3. Run `/review-all-gdds since-last-review` to verify the blocking items are closed.
4. If the rerun is PASS or CONCERNS, proceed to `/gate-check pre-production` before `/create-architecture`.
