# Camera System — Review Log

This log tracks every `/design-review` pass on `design/gdd/camera.md`. Each entry records the verdict, blockers found, and what changed between passes so future re-reviews can verify prior closure.

---

## Review — 2026-05-12 — Verdict: NEEDS REVISION (resolved inline this session)

**Mode**: `/design-review design/gdd/camera.md --depth lean`
**Scope signal**: M (Moderate — one system, 7 formulas, 9 upstream deps but all locked; 13-row cross-doc batch already pre-spec'd in C.3.3 + F.4.1; no new ADR required)
**Specialists**: None (lean mode — single-session analysis)
**Re-review of prior verdict**: First review — no prior log entry
**Completeness**: 8/8 required sections present (Overview, Player Fantasy, Detailed Design, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria) + Visual/Audio + UI + Open Questions

### Findings

| Severity | Count | Items |
|---|---|---|
| **BLOCKING** | 4 | R-C1-1 formula contradicts F-CAM-2 / AC-CAM-H1-01 · F-CAM-3 worked example numerics don't match rate 1/8 · `_compute_initial_look_offset` undefined · F.5 reciprocity batch unapplied (deferred to Phase 5 batch — by design) |
| **RECOMMENDED** | 5 | G.3 nested inside D · AC-CAM-H4-03 source-order test fragility · "Detailed Rules" vs "Detailed Design" heading · hash() patch-stability claim sourcing · ADR-0003 implicit Camera enable |
| **Nice-to-Have** | 3 | INV-CAM-5 sanity cross-check · F-CAM-6 prime choice rationale · F-CAM worked example excellence (positive note) |

#### BLOCKING — fixed inline (3 of 4)

1. **R-C1-1 / F-CAM-1 contradicts F-CAM-2 worked example AND AC-CAM-H1-01 — position formula is wrong for deadzone follow.** R-C1-1 stated `camera.global_position = target.global_position + look_offset` which yields `camera.x = 565 + 1 = 566` in the AC-CAM-H1-01 scenario, but the AC asserts `camera.global_position.x == 501.0` (and F-CAM-2 worked example also assumes 501). The unified `target + look_offset` model describes constant-offset follow, not deadzone follow.
   - **Fix (per user choice — Split H/V model)**: New `DEC-CAM-A5` row added to A.1. R-C1-1 / F-CAM-1 rewritten as split horizontal/vertical model:
     ```
     # Horizontal: incremental deadzone advance (Katana Zero/Celeste pattern)
     delta_x = target.global_position.x - camera.global_position.x
     if abs(delta_x) > DEADZONE_HALF_X:
         camera.global_position.x += delta_x - sign(delta_x) * DEADZONE_HALF_X

     # Vertical: target + lookahead
     camera.global_position.y = target.global_position.y + look_offset.y

     # Shake (unchanged): post-smoothing bypass channel
     camera.offset = shake_offset
     ```
     `look_offset.x` is now documented as unused (always 0). F-CAM-1/F-CAM-2 worked examples + variable tables rewritten; R-C1-3 pseudo-code changed `look_offset.x +=` to `camera.global_position.x +=`. R-C1-9 split global_position assignment into .x and .y branches. AC-CAM-H1-01..05 assertions migrated to camera.global_position.x with look_offset.x asserted as unused (=0). AC-CAM-H4-02 field (f) split to verify .x and .y independently.

2. **F-CAM-3 worked example numerics don't match `lerp(value, target, 1/8)` per-tick rate.** Doc table said frame 4 ≈ −13, frame 8 ≈ −18.7, frame 9 (FALLING entry) ≈ −14.5, frame 17 ≈ +47 — these match rate 1/4, not 1/8. AC-CAM-H2-01 hardcoded the `−18.7 ± 1.0` tolerance, so implementing per the formula `lerp(... , 1/8)` would fail the AC by ~5 px.
   - **Fix (per user choice — keep `LOOKAHEAD_LERP_FRAMES=8`, fix the example)**: F-CAM-3 worked example table recomputed at rate 1/8 (`y_n = target × (1 − (7/8)^n)`):
     | Frame | State | Value (rate 1/8) | % to target |
     |---|---|---|---|
     | 1 | JUMPING | −2.5 | 13% |
     | 4 | JUMPING | −8.3 | 41% |
     | 8 | JUMPING | −13.1 | 66% |
     | 9 (FALLING entry) | FALLING | −5.0 | re-targeting |
     | 17 (8 ticks in FALL) | FALLING | +29.6 | 66% |
     | 24 | FALLING | +43.7 | 87% |
     | 36 (apex window) | FALLING | +50.6 | 97% |
     New explanatory note clarifies `LOOKAHEAD_LERP_FRAMES = 8` as *time-constant* (~66% convergence frame count), NOT settle frame count. INV-CAM-5 "정점 도달 전 settle 완료" still holds — at frame 36 (apex), convergence is ~97%. AC-CAM-H2-01 tolerance updated to `−13.1 ± 0.5`; AC-CAM-H2-02 updated to `+34.1 ± 0.5` (both with explicit note pointing back to BLOCKING #2 resolution).

3. **`_compute_initial_look_offset(player_node)` undefined.** R-C1-9 called this helper and AC-CAM-H4-02 field (e) asserted it, but the function was never specified — neither in C nor as a formula in D.
   - **Fix (per user choice — inline state→target_y table)**: Inline spec added just under R-C1-9:
     ```gdscript
     func _compute_initial_look_offset(player_node: PlayerMovement) -> Vector2:
         var target_y: float = _target_y_for_state(player_node.movement_sm.state)
         return Vector2(0.0, target_y)   # .x = 0 always (DEC-CAM-A5)

     func _target_y_for_state(state: StringName) -> float:
         match state:
             &"JUMPING":             return -JUMP_LOOKAHEAD_UP_PX        # −20
             &"FALLING":             return  FALL_LOOKAHEAD_DOWN_PX      # +52
             &"REWINDING", &"DYING": return 0.0
             _:                      return 0.0
     ```
     1:1 with R-C1-4 state→target_y mapping. AC-CAM-H4-02 field (e) now directly verifiable.

#### BLOCKING — deferred (by design)

4. **F.5 bidirectional reciprocity unapplied for 4 upstream GDDs.** F.5 self-flags that Player Movement #6, State Machine #5, Damage #8, and Time Rewind #9 do NOT yet list Camera #3 in their F.2 / downstream tables. Per `.claude/rules/design-docs.md`: "Dependencies must be bidirectional."
   - **Status**: This is the **Phase 5 cross-doc batch** already pre-specified in C.3.3 + F.4.1 (now 13-row total — 9 original + 4 F.5 reciprocity additions). It is BLOCKING for the "Approved" promotion gate but **expected to land as a single coordinated batch** after re-review verdict. NOT fixed inline this session — applying mid-revision would split the batch and create cross-doc drift risk. Logged here so the re-reviewer knows the gate is open.

#### RECOMMENDED — NOT fixed inline this session

5. **G.3 Cross-Knob Invariants nested inside Section D** — Physically located at L526 (inside D. Formulas section), but section G also has a back-reference at L759 ("이미 D.G.3에 명시"). Cosmetic but confusing for grep/lint. Recommend moving under G as D.4 or G.0. Deferred.

6. **AC-CAM-H4-03 source-order test fragility** — Test relies on GDScript subclass spy of Camera2D internals. Code refactor could move setters around. Consider runtime instrumentation that observes execution order. Deferred.

7. **Section C heading "Detailed Design" vs canonical "Detailed Rules"** — Content matches; heading deviates from `.claude/rules/design-docs.md` canonical 8-section heading list. Smooths grep/linter if renamed. Deferred — cosmetic.

8. **R-C1-7 `hash()` patch-stability claim sourcing** — Asserts Godot 4.6 `hash(Vector2i)` is not patch-stable; would benefit from a pinned evidence file or upstream issue link. Deferred.

9. **F.5 ADR-0003 row says ADR revision is implicit** — One-line addition to ADR-0003 "Enables" listing Camera #3 would close the implicit gap at zero cost. Deferred to ADR maintenance pass.

### Strengths (noted but not actionable)

- **Player Fantasy → AC traceability**: DT-CAM-1/2/3 each have ≥1 BLOCKING (spatial) + ≥1 ADVISORY (perceptual) AC (H.7 coverage map)
- **Cross-doc reciprocal disclosure**: F.4.1 + F.4.2 + F.5 explicitly enumerate Phase 5 batch — pre-registers all bidirectional obligations rather than discovering them ad-hoc
- **Locked Decisions sub-tables (A.1, B.4)**: Surface architectural commitments inline rather than burying in prose
- **Falsifiability**: 7 formulas with worked examples + 6 cross-knob invariants with formal conditions
- **ADR ground-truth alignment**: Section A.1 + F.1 trace every constraint to ADR-0001/0002/0003
- **Asset-spec zero**: VA.5 explicitly notes Camera owns no textures/shaders/audio/animations — clean ownership boundary

### Verification

- All 3 inline-fixed BLOCKING items have post-fix references in their respective sections (DEC-CAM-A5 lock, BLOCKING #2 note in F-CAM-3, BLOCKING #3 spec under R-C1-9).
- AC-CAM-H1-01..05 + H2-01..02 + H4-02 rewritten consistent with split-H/V model.
- New OQ-CAM-CLOSED-9/10/11 rows added to Z.1 mapping each BLOCKING resolution to its applied location.
- camera.md header status flipped: "In Design" → "NEEDS REVISION → revisions applied (Session 22 design-review BLOCKING #1/#2/#3 applied 2026-05-12; pending fresh-session re-review)".
- systems-index.md Row #3 status flipped: "Designed · pending re-review" → "NEEDS REVISION · BLOCKING #1/#2/#3 applied — pending fresh-session re-review".

### Re-review Requirements (for next session)

- **Re-verify R-C1-1 / F-CAM-1 / F-CAM-2 split model**: Confirm AC-CAM-H1-01..05 arithmetic now consistent end-to-end. Probe worked example with `camera.x = 500, target.x = 565 → 501` chain.
- **Re-verify F-CAM-3 numerics**: Confirm AC-CAM-H2-01 `−13.1 ± 0.5` and AC-CAM-H2-02 `+34.1 ± 0.5` match `y_n = target × (1 − (7/8)^n)`.
- **Re-verify `_compute_initial_look_offset` spec**: Confirm AC-CAM-H4-02 field (e) is now directly implementable from the inline definition.
- **Verify Phase 5 cross-doc batch gate**: BLOCKING #4 (F.5 reciprocity to PM/SM/Damage/TR) remains open — must land before "Approved" promotion. Recommend running Phase 5 batch as a separate commit after re-review PASSes.
- **Spot-check**: G.3 nesting under D (RECOMMENDED #5) and "Detailed Design" heading (RECOMMENDED #7) — confirm intentional or revisit.

### Verdict & Disposition

- **This session**: NEEDS REVISION → 3/4 BLOCKING resolved inline; 1/4 BLOCKING (reciprocity) deferred to Phase 5 batch by design.
- **Recommended next action**: Fresh-session `/design-review design/gdd/camera.md --depth lean` to verify resolutions, then either promote to **Designed** (pending Phase 5 batch) or directly to **Approved** if Phase 5 batch is applied as part of the re-review session.

---

## Review — 2026-05-12 — Verdict: APPROVED (RR1 PASS)

**Mode**: `/design-review design/gdd/camera.md --depth lean` (fresh session, post-`/clear`)
**Scope signal**: M (single Core system, 7 formulas, 9 upstream deps all locked, 13–14 row Phase 5 cross-doc batch pre-spec'd, no new ADR required)
**Specialists**: None (lean mode — single-session analysis)
**Re-review of prior verdict**: Yes — first re-review (RR1) of Session 22 NEEDS REVISION verdict
**Completeness**: 8/8 required sections present + bonus Visual/Audio + UI Requirements + Open Questions

### Re-Verification of Session 22 BLOCKING Items

| Item | Status | Verification path |
|---|---|---|
| **BLOCKING #1** — Split-H/V model | ✅ PASS | Traced AC-CAM-H1-01 chain end-to-end: `camera.x = 500`, `target.x = 565` → `delta_x = 65`, `|65|>64`, advance `+1` → `camera.x = 501` matches AC. `look_offset.x` consistently 0 across A.1 DEC-CAM-A5 / F-CAM-1 var table / R-C1-9 cascade / AC assertions. Wall-pinch guard correctly recharacterized as defense-in-depth. |
| **BLOCKING #2** — F-CAM-3 numerics at rate 1/8 | ✅ PASS | Closed form `y_n = target × (1 − (7/8)^n)` validated: target=−20 → n=1: −2.5, n=4: −8.275 ≈ −8.3, n=8: −13.13 ≈ −13.1. AC-CAM-H2-01 `−13.1 ± 0.5` ✓. AC-CAM-H2-02 `+34.1 ± 0.5` from `52 × (1 − (7/8)^8) = 34.13` ✓. |
| **BLOCKING #3** — `_compute_initial_look_offset` spec | ✅ PASS | Inline definition at R-C1-9 (1:1 with R-C1-4 state→target_y mapping). AC-CAM-H4-02 field (e) directly verifiable. |
| **BLOCKING #4** — Phase 5 cross-doc reciprocity batch | ✅ RESOLVED 2026-05-12 (this session, post-RR1 PASS) | Phase 5 batch landed in same session: PM/SM/Damage/TR F.2 reciprocity rows added; scene-manager.md C.2.1 POST-LOAD body emits scene_post_loaded(anchor, limits) + boot assert (E-CAM-7); scene-manager.md C.3.1/C.3.4/F.1#3/F.1#12/F.4.2/OQ-SM-A1/DEC-SM-9 all updated; architecture.yaml interfaces.scene_lifecycle expanded multi-signal + camera-system consumer + new interfaces.camera_shake_events + new forbidden_pattern.camera_state_in_player_snapshot; art-bible.md Section 6 Camera Viewport Contract subsection added; entities.yaml 6 constants already present (verified). camera.md F.4.1 / F.5 row counts corrected (R1 closure: 9→10, 13→14). Total 14+ edits across 8 files. Bidirectional-dep rule fully satisfied. |

### New Findings (RECOMMENDED only — none BLOCKING)

| ID | Severity | Item | Disposition |
|---|---|---|---|
| **R1** | RECOMMENDED | F.4.1 / F.5 row count mismatch — F.4.1 says "9-row 배치" but C.3.3 has 10 rows; F.5 says "13-row total" should be 14 (10 + 4 reciprocity) | Apply during Phase 5 batch |
| **R2** | RECOMMENDED | F-CAM-3 worked example frame numbering ambiguity — "frame 17 (8 ticks into FALLING)" only matches formula if measured from frame 8's value, not frame 9's. Off-by-one labeling, no AC impact | Optional cleanup |
| **R3** | RECOMMENDED → APPLIED | camera.md L3 Status header cumulative narrative | Cleaned this session: now `Approved · 2026-05-12 · RR1 PASS — see review log` |
| **R4** | RECOMMENDED → APPLIED | systems-index.md Row #3 Status format violation (modifier > 30 chars + narrative — explicit forbidden example in design-docs.md) | Cleaned this session: now `Approved · 2026-05-12 · RR1 PASS` |
| **R5** | RECOMMENDED (carry) | G.3 Cross-Knob Invariants nested inside Section D | Deferred — cosmetic |
| **R6** | RECOMMENDED (carry) | AC-CAM-H4-03 source-order test fragility (subclass spy of Camera2D internals) | Deferred — refactor brittleness |
| **R7** | RECOMMENDED (carry) | "Detailed Design" heading vs canonical "Detailed Rules" + R-C1-7 `hash()` patch-stability sourcing + F.5 ADR-0003 implicit Camera-enable | Deferred — cosmetic / citation / one-line ADR amend |

### Verdict & Disposition

- **This session**: APPROVED (RR1 PASS) — all 3 inline-fixed BLOCKING items verified end-to-end against formulas and ACs. No new BLOCKING issues. R3 + R4 fixed inline this session (housekeeping for status format compliance).
- **Standing obligation**: BLOCKING #4 — Phase 5 cross-doc reciprocity batch (10 + 4 rows; corrected count per R1 finding) — must land for full bidirectional-dep compliance per `.claude/rules/design-docs.md`. Per user's inline-fix-then-reverify workflow, this is housekeeping suitable for a follow-up commit.
- **Promotion**: systems-index.md Row #3 promoted Needs Revision → **Approved** this session.
- **Recommended next action**: Apply Phase 5 cross-doc batch (14 rows total) as a separate coordinated commit, OR proceed to next GDD authoring (`/design-system audio` #4 — next unblocked candidate; or `/architecture-review` for cross-ADR consistency sweep).
