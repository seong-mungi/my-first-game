# Cross-GDD Review Report

**Date**: 2026-05-13
**Mode**: `/review-all-gdds full`
**Scope**: 9 Approved GDDs (audio · camera · damage · input · player-movement · player-shooting · scene-manager · state-machine · time-rewind)
**Excluded**: `enemy-ai.md` (Section A only — incomplete)
**Anchor docs**: `game-concept.md`, `systems-index.md`, `design/registry/entities.yaml`

---

## Verdict: **FAIL**

5 BLOCKING issues must be resolved before architecture begins.

| Phase | BLOCKING | WARNING | Verified Clean |
|---|---|---|---|
| Phase 2 — Consistency | 4 | 3 | Tuning Knobs / Formula compatibility / Acceptance Criteria |
| Phase 3 — Design Holism | 0 | 3 (forward-flags) | All 7 categories |
| Phase 4 — Cross-System Scenarios | 1 | 8 | — |
| **Total** | **5** | **14** | |

---

## Consistency Issues (Phase 2)

### Blocking

#### 🔴 B2b-1 — `shot_fired` signal signature contradiction (CRITICAL)

- **Canonical**: `shot_fired(direction: int)` — owned by `player-shooting.md` (C.3 + C.4 + F.4.2 + line 109 / 272 / 330 / 336 / 342)
- **Conforming**: `audio.md` Rule 16 (line 85, 112, 268, 438) ✓
- **Wrong**: `camera.md` records `(weapon_id: int)` at:
  - line 331 (signal contract row)
  - line 669 (F.4 dependencies #6 Player Shooting row)
  - line 695 (signal catalog row)
- **Risk**: silent logic error if Camera connects expecting `weapon_id` and receives a direction value (no crash, no type error in GDScript — would corrupt downstream lookups)
- **Fix locus**: `camera.md` — update 3 sites to `(direction: int)`

#### 🔴 B2b-2 — `death_committed` subscriber list contradicts Audio spec (CRITICAL)

- `damage.md` line 188 (signal table): consumers include "Audio (sting)"
- `damage.md` line 827 (F.3 catalog): consumers "#9 TRC, #4 Audio, #13 HUD"
- `damage.md` line 897 (F.4.1 connect-order): `damage.death_committed.connect(audio._on_death_committed) # 4`
- `audio.md`: **no** `_on_death_committed` handler exists. Rule 17 + AC-H4 subscribe to `player_hit_lethal` for death SFX.
- **Canonical**: Audio uses `player_hit_lethal`, not `death_committed`. damage.md is wrong.
- **Fix locus**: `damage.md` — remove `#4 Audio` from `death_committed` consumers (lines 188, 827); delete connect-order line 897 entry #4

#### 🔴 B2c-1 — `camera.md` references stale PlayerMovementSM state names + wrong state machine

- `camera.md` F.1 #3 (line 666): "`player_movement_sm.state` read (state enum: IDLE/RUN/JUMPING/FALLING/REWINDING/DYING)"
- `camera.md` R-C1-4 table (lines 147-149): uses `JUMPING / FALLING / REWINDING / DYING`
- `camera.md` `_compute_initial_look_offset` pseudocode (lines 232, 237-239): same names
- `camera.md` AC-CAM-H2-01/02/03/04 (lines 872, 875, 883, 887): asserts on these state names
- **Canonical** (registry + DEC-PM-1): PlayerMovementSM states are `idle / run / jump / fall / aim_lock / dead` (lowercase, 6 states)
- **Compounding**: `REWINDING` and `DYING` are **EchoLifecycleSM** states (state-machine.md), not PlayerMovementSM — camera.md reads the wrong SM for those checks
- **Risk**: R-C1-8 freeze guard likely prevents runtime crash by short-circuiting before the state check fires; AC tests would fail when implemented; design logic is architecturally wrong
- **Fix locus**: `camera.md`
  - Rename to canonical states across R-C1-4 table, pseudocode, AC-CAM-H2-01..04, F.1 #3, INV constants
  - Add `aim_lock` row to lookahead table (likely target_y=0)
  - Route REWINDING/DYING checks via `lifecycle_sm.state` (EchoLifecycleSM) instead of `movement_sm.state`

#### 🔴 B2a-1 — `scene-manager.md` F.1 #4 Audio row stale

- Line 663: Status "Not Started" + description "Tier 1 stub-level; bus reset not applied"
- Audio #4 is `Approved · 2026-05-12` (audio.md Rule 7 actively subscribes Tier 1)
- Line 715 cross-doc obligations table also still lists open Audio items
- **Fix locus**: `scene-manager.md` — update F.1 #4 Status + description; close cross-doc obligation row 715

### Warnings

⚠️ **W2a-1** — `state-machine.md` F.4 Scene Manager row contains stale "Not yet written" annotation (Scene Manager is Approved · RR9 PASS)
⚠️ **W2a-2** — `player-shooting.md` F.4.1 lists 7 cross-doc obligations still "Pending"; Camera #3 row labeled "Not Started" (Camera is Approved · RR2 PASS)
⚠️ **W2c-1** — camera.md `_compute_initial_look_offset` freeze path implicitly correct via R-C1-8 but reads wrong SM (subsumed by B2c-1)

### Verified Clean

- ✅ **2d** — Tuning Knob Ownership: no duplicates across 9 GDDs
- ✅ **2e** — Formula Compatibility:
  - `FIRE_COOLDOWN_FRAMES (10) < REWIND_WINDOW_FRAMES (90)` ✓
  - `RESTORE_OFFSET_FRAMES (9) < REWIND_WINDOW_FRAMES (90)` ✓
  - jump_height_invariant 144 px = 480² / (2×800) ✓
  - PlayerSnapshot 9-field schema consistent across PM / TR / ADR-0002 Amendment 2
- ✅ **2f** — Acceptance Criteria: no contradictions
- ✅ **Phase 5d Audio batch** (Session 25 commit `26bf7cd`) — all 7 items landed correctly (Rules 16/17 in audio.md + 5 upstream AudioManager downstream rows)

---

## Game Design Issues (Phase 3)

### Blocking
*None.*

### Warnings (forward-flags for downstream GDDs)

⚠️ **W3b-1 — Attention budget at ceiling**
Current core-loop peak = 4 concurrent active systems (Movement + Shooting + Damage-threat-reading + Time Rewind). `aim_lock` is the cognitive relief valve (collapses Movement from active to frozen). When Enemy AI #10 / Boss #11 / Stage #12 land, budget hits 5+. Flag for re-review of Phase 3b at next `/review-all-gdds`. Enemy AI #10 must not invalidate aim_lock as relief mechanism.

⚠️ **W3c-1 — AimLock turret dominance**
Correctly deferred to Tier 1 playtest (systems-index D1). Enemy AI #10 author must include ≥1 archetype that punishes stationary play (e.g., closer/flanker that ignores cover line).

⚠️ **W3d-1 — Tier 3 token cap waste**
Cap=5 + 5–6 boss rewards → 3–4 wasted boss rewards per Tier 3 run if player hoards. Two options: (a) keep cap=5 as intentional dump-pressure, (b) raise to 8 for Tier 3. Tuning decision deferred to Boss Pattern #11 + Tier 3 design pass. Not Tier 1 concern.

### Key Insight

> Every Player Fantasy section converges on a single thematic spine: ***defiance through revocation***. 8/9 GDDs serve Pillar 1 or 2. Zero anti-pillar violations. Token economy correctly tuned-tight for Tier 1 (3 starting, +1 per boss, cap=5 → only 3/2/1/0 states relevant Tier 1). The holism is sound; downstream design risk lives entirely in the un-authored Enemy AI / Boss / Stage trio.

### Pillar Alignment Matrix

| GDD | Primary Pillar(s) | Anti-Pillar Conflict? |
|---|---|---|
| audio.md | P3 (collage audio), P1 (rewind whoosh confirmation), P2 (deterministic pitch jitter), P5 (CC0 Tier 1) | ✅ Honors Anti-Pillar #4 (no original music Tier 1) |
| camera.md | P1 (no-lerp restore), P3 (readable third), P2 (deterministic shake) | ✅ DEC-CAM-B3 rejects camera-control inputs (Anti-Pillar #6) |
| damage.md | P2 (binary, no HP), P1 (12-frame grace), P4 (no HP bar) | ✅ B.5 rejects HP bars / damage numbers / hit-stun |
| input.md | P2 (zero-input-loss), P4 (no device-confirm UI) | ✅ No remap Tier 1 (Anti-Pillar #6) |
| player-movement.md | P1 (restore-to-body), P2 (deterministic), P5 (6-state lock) | ✅ Dash / double-jump explicitly deferred |
| player-shooting.md | P4 (first shot immediate), P2 (no random spread), P1 (ammo restored) | ✅ Single rifle Tier 1 (Anti-Pillar #3) |
| scene-manager.md | P1 (sub-1s restart), P2 (deterministic spawn), P4 (≤300s boot) | ✅ Invariant-only framework |
| state-machine.md | P1 (input window protection), P2 (frame-counter), P5 (small framework) | ✅ Anti-Pillar #5 (no cutscenes) |
| time-rewind.md | **P1 PRIMARY**, P2 (ring buffer determinism), P3 (color-inversion glitch marketing) | ✅ Anti-fantasy rejects invincibility/safety-net |

---

## Cross-System Scenario Issues (Phase 4)

**Scenarios walked**: 5
- S1: Lethal Hit → DYING grace → Rewind → REWINDING → ALIVE
- S2: Scene Boundary Crossing During Active Combat
- S3: Boss Kill at Token Cap
- S4: Death While Holding AimLock
- S5: Rewind Consume During Camera Mid-Shake

### Blocker

#### 🔴 B1-S2 — Same-tick `scene_will_change` + lethal hit silently denies rewind

**Sequence**:
1. Frame T: `scene_will_change` fires → TRC `_buffer_invalidate()` sets `_buffer_primed = false`
2. Same frame: lethal hit lands → `lethal_hit_detected` → TRC caches `_lethal_hit_head` → SM transitions to DYING
3. Frame T+1: DyingState `physics_update` detects pre-buffered `rewind_consume` input
4. `try_consume_rewind()` is called → returns false because `_buffer_primed == false`
5. 12-frame DYING window expires → SM transitions to DEAD

**Problem**: Token denial cue (Rule 7) only fires when `_tokens == 0`. Here tokens > 0 but buffer is unprimed → player gets NO denial cue.

**Violates**: `state-machine.md` B.3 anti-fantasy — *"I gave input but the character ignored it"*

**Fix options** (one required):
- **(a) Scene Manager defer** — If `EchoLifecycleSM` is in DYING or `_lethal_hit_latched == true` when `change_scene_to_packed` is requested, defer `scene_will_change` emit by 1 frame
- **(b) TRC denial taxonomy** — Extend `rewind_denied(reason: StringName)` cue to fire when tokens > 0 but `_buffer_primed == false` with `reason = &"buffer_invalidated"`; audio.md adds corresponding SFX

**Fix locus**: `scene-manager.md` (preferred — single-source guard) + `time-rewind.md` Rule 7 (secondary if Scene Manager can't guarantee deferral)

### Warnings

⚠️ **W1-S1** — `damage.md` C.1.2 "connect order" framing is misleading. TRC subscribes to `lethal_hit_detected` and SM subscribes to `player_hit_lethal` — these are different signals. The constraint is on signal-emit order within the damage handler, not subscriber connect order. Clarify in AC-28.

⚠️ **W2-S1** — 1-frame minimum DYING gap. DyingState polls input in `physics_update`, so even with perfect pre-buffered input, DYING entry on frame N means earliest consume on frame N+1. This is undocumented as intentional. Add note to `time-rewind.md` Rule 5.

⚠️ **W1-S2** — `audio.md` Rule 7 (`_on_scene_will_change`) currently restores Music bus to 0 dB as direct set. Should explicitly **kill `_duck_tween` first** (like Rule 8 does for new duck Tweens) to prevent a stale duck Tween extending into the new scene.

⚠️ **W1-S3** — Silent cap-overflow non-communicative at `max_tokens=5`. Boss kill at cap → `token_replenished(5)` fires with unchanged count → HUD diff-check suppresses animation → player at cap gets identical audio feedback to player who gained a token. Forward dep on HUD #13: distinct "token cap reached" visual required when `new_total == max_tokens AND prior_total == max_tokens`.

⚠️ **W1-S4** — 1-frame cosmetic desync on AimLock-death-restore. Snapshot records `animation_name = "aim_lock"` and PM's `_derive_movement_state` resolves to Idle (velocity was 0 in AimLock). For 1 frame, ECHO displays aim_lock animation while SM is in Idle state. Self-corrects on next tick. Not a logic fault.

⚠️ **W2-S4** — AC-CAM-H4 (camera) missing aim-lock-death subcase. Add explicit test.

⚠️ **W1-S5** — Camera freeze during REWINDING preserves non-zero shake offset for 30 frames, then `rewind_completed` snaps to zero in 1 frame. Visible 1-frame pop. DT-CAM-1 (0 px drift) tests `global_position` not `offset`, so technically compliant. Add AC-CAM-H4 subcase for "shake-active-at-rewind".

### Highest-Risk Scenario

**S2 — Scene Boundary During Active Combat** — only BLOCKER. Violates stated anti-fantasy. Frame-ordering rule needed.

---

## GDDs Flagged for Revision

| GDD | Issues | Severity | Type |
|---|---|---|---|
| **camera.md** | B2b-1, B2c-1, W1-S5, W2-S4 | 🔴 Blocking | Consistency + Scenario |
| **damage.md** | B2b-2, W1-S1 | 🔴 Blocking | Consistency + Scenario |
| **scene-manager.md** | B2a-1, B1-S2 | 🔴 Blocking | Consistency + Scenario |
| **time-rewind.md** | W2-S1, B1-S2 (secondary), Rule 7 taxonomy | ⚠️ Warning | Scenario |
| **audio.md** | W1-S2 | ⚠️ Warning | Scenario |
| **state-machine.md** | W2a-1 | ⚠️ Warning | Consistency |
| **player-shooting.md** | W2a-2 | ⚠️ Warning | Consistency |

---

## Required Actions Before Re-Running `/review-all-gdds`

### Must Fix (BLOCKING)

1. **camera.md**
   - Fix `shot_fired(direction: int)` at 3 sites (lines 331, 669, 695)
   - Rename PlayerMovementSM states to canonical: `idle / run / jump / fall / aim_lock / dead`
   - Add `aim_lock` row to lookahead table (target_y likely 0)
   - Route REWINDING/DYING checks via `lifecycle_sm.state` (EchoLifecycleSM)
   - Update AC-CAM-H2-01/02/03/04 to canonical state names

2. **damage.md**
   - Remove `#4 Audio` from `death_committed` consumers (lines 188, 827)
   - Delete connect-order line 897 `damage.death_committed.connect(audio._on_death_committed) # 4`
   - Renumber subsequent connect-order entries

3. **scene-manager.md**
   - Update F.1 #4 Audio row to `Approved · 2026-05-12` Status; remove "Tier 1 stub-level" wording; align with audio.md Rule 7
   - Close cross-doc obligation row 715 (Audio #4)
   - Add new Rule for same-tick `scene_will_change` + `_lethal_hit_latched` collision resolution (preferred fix locus for B1-S2)

4. **time-rewind.md**
   - Extend Rule 7 denial cue taxonomy to include `buffer_invalidated` reason (secondary fix locus for B1-S2 if Scene Manager fix is rejected)
   - Document 1-frame DYING minimum gap as intentional (W2-S1)

### Should Fix (Warning)

5. **audio.md** Rule 7 — explicitly kill `_duck_tween` first on scene_will_change
6. **state-machine.md** F.4 — remove stale "Not yet written" Scene Manager annotation
7. **player-shooting.md** F.4.1 — apply 7 pending cross-doc obligations (housekeeping pass)

### Forward Obligations (downstream GDD authoring)

- **enemy-ai.md** (#10): include ≥1 archetype that punishes stationary play (counters AimLock turret deferred D1)
- **boss-pattern.md** (#11): model Tier 3 token economy explicitly (W3d-1)
- **hud.md** (#13): distinct "token cap reached" visual (W1-S3)

---

## Re-Review Trigger

After items 1–4 land, re-run `/review-all-gdds since-last-review` to verify BLOCKERS resolved. Expected verdict: PASS or CONCERNS (assuming Warning items remain deferred).

After enemy-ai.md / boss-pattern.md / stage.md are added (3 missing MVP gameplay GDDs), re-run `/review-all-gdds full` for the full 12-GDD set. Re-evaluate Phase 3b (attention budget) + Phase 3c (AimLock dominance) + Phase 3d (Tier 2/3 token economy) at that point.
