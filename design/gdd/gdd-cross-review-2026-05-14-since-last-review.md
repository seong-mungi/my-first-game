# Cross-GDD Review Report

**Date**: 2026-05-14  
**Mode**: `/review-all-gdds since-last-review`  
**Baseline**: `design/gdd/gdd-cross-review-2026-05-14.md` written 2026-05-14 09:14 +0900  
**Scope rule**: GDDs modified after the baseline report plus directly affected dependency mirrors.  
**In-scope system GDDs**: `stage-encounter.md`, `player-shooting.md`, `menu-pause.md`, `input.md`, `state-machine.md`, `scene-manager.md`, `hud.md`.  
**Additional anchors checked**: `systems-index.md`, `design/registry/entities.yaml`, `design/gdd/reviews/menu-pause-review-log.md`, `audio.md`, `boss-pattern.md`.  
**Summary scan note**: current GDDs still do not use `## Summary`; this pass used status headers, Overview/A sections, dependency tables, and targeted cross-reference scans.  
**Registry baseline**: `design/registry/entities.yaml` exists and was updated 2026-05-14 for Menu / Pause #18 approval; no registry contradiction was found in the in-scope changes.

---

## Verdict: **CONCERNS**

No blocking issue remains from the 2026-05-14 full review. Architecture/gate review is no longer blocked by the prior Stage projectile-container gap or unreviewed Menu / Pause GDD.

Remaining concerns are warning-level ledger drift:

1. `systems-index.md` progress tracker says only 12 design docs have review logs, while the repository contains 18 review logs and the Systems Enumeration lists 18 approved/locked MVP docs.
2. `hud.md` still labels Boss Pattern #11 as `Designed pending review` even though `boss-pattern.md` is Approved.
3. `stage-encounter.md` F.3 still contains stale “refreshed to Designed / re-check after design-review” wording after Stage #12 is Approved and the Player Shooting container contract is closed.

| Phase | Blocking | Warning | Notes |
|---|---:|---:|---|
| Phase 2 — Cross-GDD Consistency | 0 | 3 | Prior blockers fixed; remaining issues are status/mirror drift |
| Phase 3 — Game Design Holism | 0 | 2 | Core attention budget remains tight; AimLock dominance remains empirical/playtest risk |
| Phase 4 — Cross-System Scenarios | 0 | 1 | Boss-kill/death priority still deserves implementation integration coverage |
| **Total unique findings** | **0** | **5** | No architecture-blocking contradiction found |

---

## Loaded Scope Manifest

### In-scope GDDs modified since baseline

- `stage-encounter.md` — Approved; now defines the Stage-owned `Projectiles: Node2D` container contract.
- `player-shooting.md` — Approved; now closes Stage #12 reciprocal obligation for projectile parenting.
- `menu-pause.md` — Approved · 2026-05-14; new lean review log exists and approves the GDD.
- `input.md` — Menu/Pause #18 mirror updated; PauseHandler remains toggle authority and UI/Menu `_input` exception is bounded.
- `state-machine.md` — Menu/Pause #18 mirror updated; `can_pause()` / `should_swallow_pause()` alias policy is coherent.
- `scene-manager.md` — Menu/Pause #18 mirror updated; restart/title-shell boundary is coherent.
- `hud.md` — Menu/Pause #18 mirror updated; one stale Boss Pattern status remains.

### Key dependency/anchor checks

- `systems-index.md` lines 25-42 list all MVP GDDs #1-#18 as Approved or LOCKED, including Menu/Pause #18 Approved · 2026-05-14.
- `design/gdd/reviews/menu-pause-review-log.md` lines 3-7 record Menu/Pause #18 APPROVED with 0 blocking items.
- `boss-pattern.md` line 3 says Boss Pattern is Approved.
- `audio.md` contains the `AudioManager.play_ui()` and session bus-volume facade used by Menu/Pause #18.

---

## Consistency Issues

### Blocking

None.

### Warnings

#### ⚠️ W2-1 — Systems Index reviewed-count ledger is stale

`systems-index.md` has internally inconsistent review accounting:

- Systems Enumeration lists all 18 MVP GDDs as Approved or LOCKED, with review links for #1-#18 (`systems-index.md:25-42`).
- Progress Tracker says `Design docs reviewed ... | 12 |` (`systems-index.md:193`).
- Progress Tracker also says `Design docs approved ... | 18 |` (`systems-index.md:194`).
- `design/gdd/reviews/` currently contains 18 `*-review-log.md` files.

**Concern**: the gate checklist can appear partially incomplete even though all MVP docs have review logs and approved/locked status.

**Recommendation**: update the reviewed count to 18, or clarify the metric if it intentionally counts only a subset. If this report's warnings are tracked in that same table, `Deferred non-blocking warnings` should no longer be 0 after this review.

#### ⚠️ W2-2 — HUD Boss Pattern mirror still says `Designed pending review`

`hud.md` F.1 labels Boss Pattern #11 as `Designed pending review` (`hud.md:357`). `boss-pattern.md` is Approved (`boss-pattern.md:3`), and `systems-index.md` row #11 is also Approved (`systems-index.md:35`).

**Concern**: this is not a functional contradiction because HUD's dependency text is otherwise correct — boss phase and kill signals, no HP/hit UI exposure — but it is stale status evidence in an Approved GDD.

**Recommendation**: change the HUD F.1 status cell for Boss Pattern #11 to `Approved 2026-05-13`.

#### ⚠️ W2-3 — Stage F.3 mirror status wording is stale after the projectile-container fix

`stage-encounter.md` now closes the Player Shooting #7 projectile container gap, but F.3 still says:

- `scene-manager.md` was “refreshed to Designed status” and should be re-checked after design-review (`stage-encounter.md:480`).
- `enemy-ai.md` was “refreshed to Designed status” and should be re-checked after design-review (`stage-encounter.md:481`).

Stage itself is Approved (`stage-encounter.md:3`), and its F.2/F.4 sections now contain current Approved dependency rows and the `Projectiles: Node2D` interface (`stage-encounter.md:468-491`).

**Concern**: this does not break the Stage ↔ Player Shooting contract, but it leaves stale review-state language in the same file that just received a cross-doc fix.

**Recommendation**: update those two F.3 rows to reflect the current Approved mirrors or mark them as historical closure notes.

---

## Resolved Prior Blocking Items

### ✅ Prior B2-1 / Scenario S2 — Stage now defines the required `Projectiles: Node2D` container

The prior full review found that Player Shooting required a Stage-owned projectile host but Stage did not define it. Current state is coherent:

- `stage-encounter.md` Rule 1 includes `Projectiles: Node2D` as exactly one root-child container (`stage-encounter.md:75`).
- Stage Rule 15 makes the ownership split explicit: Stage owns container presence/lifetime; Player Shooting owns projectile behavior, Damage HitBox setup, ammo/cooldown, and `shot_fired(direction)` (`stage-encounter.md:167-169`).
- Stage activation/preflight now validates the root-child `Projectiles: Node2D` container (`stage-encounter.md:224-226`).
- Stage F.2 and F.4 expose the same contract to Player Shooting (`stage-encounter.md:468`, `stage-encounter.md:491`).
- AC-STG-27 verifies exactly one root-child `Projectiles: Node2D` container and that Stage does not configure ECHO projectiles (`stage-encounter.md:580`).
- `player-shooting.md` Rule 7 now cites Stage's reciprocal closure (`player-shooting.md:90`), C.3.7 closes the F.4.2 obligation (`player-shooting.md:317-318`), the dependency table marks Stage #12 Approved (`player-shooting.md:590`), and F.4.2 row #1 is closed (`player-shooting.md:653`).

**Conclusion**: blocker resolved.

### ✅ Prior B3-1 / W2-1 — Menu / Pause #18 is now reviewed and Approved

The prior full review blocked on Menu/Pause being Designed and unreviewed. Current state is coherent:

- `menu-pause.md` status is Approved · 2026-05-14 (`menu-pause.md:3`).
- `design/gdd/reviews/menu-pause-review-log.md` records Verdict: APPROVED, 0 blocking items (`reviews/menu-pause-review-log.md:3-7`).
- `systems-index.md` row #18 is Approved · 2026-05-14 and links the review log (`systems-index.md:42`).
- Menu/Pause explicitly rejects a production title/menu shell in Tier 1 and defers return-to-title (`menu-pause.md:14-16`, `menu-pause.md:49-52`, `menu-pause.md:248-251`, `menu-pause.md:271`).
- Input, State Machine, Scene Manager, Audio, HUD, and Story Intro boundaries are listed and bounded in Menu/Pause dependencies (`menu-pause.md:206-212`, `menu-pause.md:226-232`).

**Conclusion**: blocker resolved.

---

## Game Design Issues

### Blocking

None.

### Warnings

#### ⚠️ W3-1 — Core attention budget remains at the comfortable ceiling

The core loop still asks the player to manage four active concerns at once:

1. Player Movement — continuous position/jump timing.
2. Player Shooting — aim direction, fire cadence, projectile cap feel.
3. Enemy/Boss pattern reading — Drone, Security Bot, STRIDER telegraphs.
4. Time Rewind decision — 12-frame DYING window, tokens, and recovery timing.

The new Menu/Pause GDD correctly keeps pause/options outside active gameplay and does not increase combat attention load (`menu-pause.md:33-46`, `menu-pause.md:71-78`).

**Recommendation**: preserve the “one new read per room” Stage tuning rule and keep HUD/VFX as clarifying, passive layers.

#### ⚠️ W3-2 — AimLock turret dominance remains an empirical playtest risk

No new contradiction was introduced, but the prior warning still applies: if AimLock + hold-fire is safer than movement in most rooms, it can dominate. Stage's Security Bot room is explicitly an anti-AimLock lesson, which mitigates the risk (`stage-encounter.md:541-543` in current file), but it still needs playtest proof.

**Recommendation**: keep the existing Systems Index D1 playtest item active and measure stationary AimLock combat time, deaths while stationary, and clear-time delta between AimLock-heavy and movement-heavy play.

---

## Cross-System Scenario Issues

Scenarios walked:

1. Stage load → POST-LOAD validation → Player Shooting projectile spawn.
2. Pause during ALIVE vs DYING/REWINDING.
3. Pause restart request → Scene Manager checkpoint route.
4. Menu options slider/UI SFX → Audio facade.
5. Boss final hit + player death same tick.

### Blockers

None.

### Warnings

#### ⚠️ S5 — Boss kill + player death same-tick path remains coherent but should receive implementation integration coverage

No design contradiction found. Scene Manager continues to specify `boss_killed` priority over same-tick dead state, and Menu/Pause does not alter that boundary. Because this path spans Damage, Scene Manager, Time Rewind, HUD, Audio, Camera, and VFX, the previous integration-test recommendation remains valid.

**Recommendation**: add an implementation test spec/story later for same-tick boss kill + player death asserting final boundary state, token count, HUD timing, and one-shot audio/VFX/camera responses.

### Info

#### ℹ️ Menu/Pause preserves the no-title-shell Tier 1 boundary

Menu/Pause #18 no longer conflicts with the Systems Index wording: it is a pause overlay + session-only options surface, not a cold-boot title/menu shell. It uses PauseHandler/State Machine gating for pause, Scene Manager for checkpoint restart, Audio facade calls for session audio, and leaves HUD combat presentation untouched.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| `systems-index.md` | Reviewed-count ledger says 12 despite 18 review logs and 18 approved/locked MVP docs; warning count also stale after this review | Consistency / Readiness | Warning |
| `hud.md` | Boss Pattern #11 mirror still says `Designed pending review` even though Boss Pattern is Approved | Consistency | Warning |
| `stage-encounter.md` | F.3 mirror rows still say Scene Manager / Enemy AI were refreshed to Designed and need re-check after design-review | Consistency | Warning |

---

## Required Actions Before Re-Running `/review-all-gdds`

No blocking actions required.

### Should fix

1. Update `systems-index.md` Progress Tracker review count from 12 to 18, or clarify the metric if 12 is intentional; consider incrementing `Deferred non-blocking warnings` while this report remains open.
2. Update `hud.md` F.1 Boss Pattern #11 status to Approved.
3. Clean `stage-encounter.md` F.3 stale Designed/re-check wording for Scene Manager and Enemy AI mirrors.

---

## Handoff Recommendation

Because there are no blockers, the next pipeline-advancing action is `/gate-check pre-production` or `/architecture-review` depending on whether the team wants a formal phase gate first or an architecture consistency sweep first.
