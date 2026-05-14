# Cross-GDD Review Report

**Date**: 2026-05-13
**Mode**: `/review-all-gdds since-last-review`
**Rerun reason**: Re-review after applying warning-level quick edits from the previous since-last-review report.
**Baseline used**: previous latest report `design/gdd/gdd-cross-review-2026-05-13-since-last-review.md` mtime `2026-05-13T13:57:24 +0900`; in-scope files are GDDs modified after that report.
**Scope rule used**: modified GDDs since the latest report plus direct dependency/reference reads needed to verify cross-system contracts.

## GDD Manifest

**Primary in-scope GDDs**:

- `audio.md` — modified after latest report
- `input.md` — modified after latest report
- `player-shooting.md` — modified after latest report
- `scene-manager.md` — modified after latest report
- `state-machine.md` — modified after latest report
- `systems-index.md` — modified after latest report
- `time-rewind.md` — modified after latest report

**Dependency/reference reads**: `game-concept.md`, `enemy-ai.md`, `camera.md`, `damage.md`, `player-movement.md`, `design/registry/entities.yaml`.

**Summary-section scan**: no `## Summary` sections were found in current `design/gdd/*.md`; review used Overview / A. Overview / status blocks instead.

**Registry**: `design/registry/entities.yaml` exists and contains active cross-doc facts for ECHO, PlayerMovementSM states, rewind constants, and snapshot-related formulas. It was used as the conflict baseline.

**Loaded**: 7 primary modified GDDs, 5 dependency/reference GDDs, 1 entity registry. Systems covered directly or by dependency: Input, Audio, Player Shooting, Scene Manager, State Machine, Time Rewind, Enemy AI, Camera, Damage, Player Movement.

---

## Verdict: **CONCERNS**

The warning-level quick edits resolved the previous report's concrete quick-fix warnings for status/header drift, Audio Rule 7, Audio D.3 pool proof, Scene Manager/Time Rewind `buffer_invalidated` AC coverage, stale `boss_defeated` diagnostic text, State Machine mirror rows for Scene Manager/Time Rewind, and Systems Index Enemy AI status.

No **blocking** cross-GDD contradictions were found in this rerun. The current set is not yet a clean PASS because a few warning-level documentation residues and deferred design obligations remain.

| Phase | Blocking | Warning | Notes |
|---|---:|---:|---|
| Phase 2 — Consistency | 0 | 4 | Residual mirror/AC/order cleanup plus incomplete Enemy AI reverse mirror |
| Phase 3 — Design Holism | 0 | 3 | Carried-forward attention / AimLock / token-cap obligations |
| Phase 4 — Scenario Walkthrough | 0 | 0 | Prior scenario warnings now specified and AC-covered |
| **Total** | **0** | **7** | Safe to continue only if warning debt is accepted or cleaned up first |

---

## Prior Warning Quick Edits Re-Verified

### ✅ W2-1 — Approved GDD status/header drift resolved

- `audio.md`, `input.md`, `player-shooting.md`, `scene-manager.md`, and `time-rewind.md` now have approved-status headers matching `systems-index.md`.
- Targeted stale-text scan found no remaining `Status: In Design` header in the approved systems reviewed here; `enemy-ai.md` remains correctly `In Design` because only Section A exists.

**Result**: clean.

### ✅ W2-2 — State Machine Scene Manager / Time Rewind dependency mirror resolved

- `state-machine.md` F.4 now identifies Scene Manager as Approved and already mentioned.
- `state-machine.md` F.4 now identifies Time Rewind as already mentioned / resolved and closes the immediate cleanup action.

**Result**: clean for the rows targeted by the previous report.

### ✅ W2-3 — Systems Index Enemy AI row resolved

- `systems-index.md` row #10 now links `enemy-ai.md` and marks Enemy AI as `In Design · 2026-05-12 (Section A only)`.
- The design-doc started count is now 10.
- The Next Steps queue explicitly says Enemy AI is in progress and should continue from Section B.

**Result**: clean.

### ✅ W2-4 / W4-2 — Audio same-tick fire + lethal-hit proof resolved

- `audio.md` D.3 now allows same-tick `shot_fired` before later same-tick `player_hit_lethal`.
- Realistic maximum is recalculated at 7 slots, while the theoretical SFX pool invariant remains `N_worst (8) <= SFX_POOL_SIZE (8)`.
- Player Shooting remains the canonical producer of `shot_fired(direction: int)` and still blocks shooting from tick N+1 after lethal state changes.

**Result**: clean.

### ✅ W2-5 — Audio Rule 7 `_duck_tween.kill()` main-rule omission resolved

- `audio.md` Rule 7 now specifies the ordered handler: kill active `_duck_tween`, restore Music bus to 0 dB, then call `stop_bgm()`.
- The Audio interaction table mirrors that order for `scene_will_change()`.

**Result**: clean at rule/table level; see residual warning W2-2 for one acceptance-criteria mirror that still should be updated.

### ✅ W2-6 — Stale `boss_defeated` notes resolved

- `scene-manager.md` now treats `boss_defeated` → `boss_killed` as a closed historical note.
- Targeted stale-text scan found no remaining queued-housekeeping language for this drift.

**Result**: clean.

### ✅ W2-7 / W4-1 — `buffer_invalidated` denial AC coverage resolved

- `time-rewind.md` adds AC-B4b for same-tick scene-boundary + lethal-hit `buffer_invalidated` denial.
- `scene-manager.md` adds AC-H3c for the same scenario and updates AC totals.
- Rule-level contract remains coherent: Scene Manager emits `scene_will_change`, TRC invalidates the buffer, Time Rewind denies with `buffer_invalidated`, and Audio denial cue fires exactly once.

**Result**: clean.

---

## Consistency Issues

### Blocking

None.

### Warnings

#### ⚠️ W2-1 — `state-machine.md` Camera mirror still carries stale PlayerMovementSM state names

`state-machine.md` F.2 Camera row now correctly says Camera is a read-only subscriber and Approved, but the same row still describes Camera's direct read of PlayerMovementSM states using legacy uppercase / lifecycle names: `IDLE/RUN`, `JUMPING`, `FALLING`, `REWINDING`, and `DYING`.

Current canonical facts:

- `design/registry/entities.yaml` records PlayerMovementSM states as `idle / run / jump / fall / aim_lock / dead`.
- The previous blocking Camera stale-state issue was resolved in `camera.md`; Camera now treats `REWINDING` and `DYING` as EchoLifecycleSM states rather than PlayerMovementSM states.

**Risk**: this is a mirror-text warning, not a canonical behavior blocker, but it can reintroduce the old Camera/PM state-name confusion for implementers reading State Machine F.2.

**Recommendation**: update the `state-machine.md` F.2 Camera row to use `idle / run / jump / fall / aim_lock / dead`, and move `REWINDING / DYING` wording to EchoLifecycleSM-only context or remove it from the Camera row.

#### ⚠️ W2-2 — `audio.md` AC-D1 still mirrors the old two-step Rule 7 order

`audio.md` Rule 7 and the interaction table now correctly include `_duck_tween.kill()` before Music bus restoration and `stop_bgm()`. However, AC-D1 still says that when `scene_will_change` fires in BGM_PLAYING state the exact order is only:

1. Music bus restored to 0 dB;
2. BGM player `stop()` called.

AC-E4 covers the DUCKED-state case and includes `_duck_tween.kill()`, but Rule 7 now states that the kill step is part of the main handler, not only an edge-case patch.

**Risk**: an implementer or test author following AC-D1 alone can preserve a two-step test that does not assert the null-safe Tween kill path for the general Rule 7 handler.

**Recommendation**: update AC-D1 to include the null-safe `_duck_tween.kill()` first, or explicitly state that AC-D1 is the no-active-Tween BGM_PLAYING subcase and AC-E4 is the active-Tween coverage.

#### ⚠️ W2-3 — `scene-manager.md` Rule 15 appears before Rule 14

`scene-manager.md` now contains Rule 15 for same-tick scene-boundary + lethal-hit behavior, followed by Rule 14 for same-PackedScene reload guard. The contract content is coherent, but the numbering order is inverted in Section C.1.

**Risk**: low. Cross-references to Rule 14 and Rule 15 still resolve, but the out-of-order sequence is a documentation hygiene issue and can confuse future line-by-line review or generated rule indexes.

**Recommendation**: reorder the two rules or renumber them so Rule 14 precedes Rule 15.

#### ⚠️ W2-4 — Enemy AI remains Section A only, so reverse dependency mirrors are intentionally incomplete

`enemy-ai.md` exists and is correctly listed as `In Design · 2026-05-12 (Section A only)` in `systems-index.md`, but Sections B-H are placeholders. As a result, full F-section reverse mirrors for State Machine, Damage, and Player Movement are not yet available.

**Risk**: not a contradiction. The risk is that later gate checks or architecture work treat Enemy AI #10 as fully reviewed when only its overview exists.

**Recommendation**: continue `/design-system enemy-ai` from Section B before treating Enemy AI as part of the approved baseline.

---

## Game Design Issues

### Blocking

None.

### Warnings / carried forward

#### ⚠️ W3-1 — Attention budget remains at the Tier 1 ceiling

The current core-loop peak remains Movement + Shooting + Damage-threat-reading + Time Rewind. Enemy AI, Boss Pattern, Stage, HUD, and VFX may push concurrent active decisions past 4 if authored as actively managed systems.

**Recommendation**: make Enemy AI/Boss/Stage patterns readable rather than resource-management-heavy, and keep HUD/VFX as clarity layers rather than new active decision loops.

#### ⚠️ W3-2 — AimLock turret dominance remains deferred to Enemy AI #10

Enemy AI #10 should include at least one archetype or encounter rule that punishes stationary AimLock play; otherwise `aim_lock` risks becoming a low-risk dominant strategy.

**Recommendation**: encode a deterministic anti-stationary pattern or flank-pressure archetype in Enemy AI B-H.

#### ⚠️ W3-3 — Token cap economy remains deferred to Boss Pattern #11 / Tier 3 tuning

Tier 1 token economy remains sound. The Tier 3 cap-waste warning is still a downstream tuning obligation, not a current blocker.

**Recommendation**: when Boss Pattern #11 is authored, verify boss-kill token recharge cadence against `RewindPolicy.max_tokens` and HUD feedback for cap-overflow / wasted grant clarity.

---

## Cross-System Scenario Issues

### Scenarios walked

1. Lethal Hit → DYING grace → Rewind → REWINDING → ALIVE
2. Same-tick Scene Boundary + Lethal Hit
3. Same-tick Fire + Lethal Hit + Audio response
4. Boss Kill / Stage Clear / Audio Sting boundary

### Blockers

None.

### Warnings

None introduced by the rerun. The two prior scenario warnings now have rule-level and AC-level coverage.

### Info

#### ℹ️ Boss kill + scene change SFX persistence remains coherent

Audio preserves the boss sting across scene swap because the SFX pool lives under the autoload and Rule 7 stops only BGM. This remains aligned with the intended boss-kill boundary experience.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| `state-machine.md` | Camera F.2 mirror still uses stale PlayerMovementSM state names | Consistency | Warning |
| `audio.md` | AC-D1 still mirrors old two-step `scene_will_change` order, while Rule 7 now has three ordered steps | Test coverage / Consistency | Warning |
| `scene-manager.md` | Rule 15 appears before Rule 14 in Section C.1 | Documentation hygiene | Warning |
| `enemy-ai.md` | Continue sections B-H before including in approved baseline review | Design completion | Warning |

---

## Required Actions Before `/gate-check` or `/create-architecture`

No blocking actions are required.

Recommended warning cleanup before gate-check:

1. Update `state-machine.md` Camera mirror row to use canonical PlayerMovementSM state names.
2. Update `audio.md` AC-D1 to mirror Rule 7's `_duck_tween.kill()` → Music bus 0 dB → `stop_bgm()` order, or explicitly scope AC-D1 to the no-active-Tween subcase.
3. Reorder or renumber `scene-manager.md` Rule 14 / Rule 15.
4. Continue `/design-system enemy-ai` from Section B before treating Enemy AI as reviewed/approved.

---

## Recommended Next

- If staying in cleanup mode: apply the three simple documentation quick fixes above, then run `/review-all-gdds since-last-review` once more.
- If moving pipeline forward with accepted warnings: run `/gate-check` and explicitly list the remaining warnings as accepted risk.
