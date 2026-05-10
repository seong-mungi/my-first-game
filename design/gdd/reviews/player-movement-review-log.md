# Player Movement — Design Review Log

> Single source of truth for all `/design-review design/gdd/player-movement.md` verdicts. Each entry preserves the prior review's conclusion so re-reviews can verify whether blocking items were addressed.

---

## Review — 2026-05-11 — Verdict: MAJOR REVISION NEEDED
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, gameplay-programmer, godot-gdscript-specialist, art-director, audio-director, creative-director (synthesis)
Blocking items: 10 | Recommended: ~22 | Nice-to-have: ~12
Mode: full (all phases + 7 specialist agents in parallel + creative-director synthesis)
Prior verdict resolved: First review — no prior verdict
GDD posture at review entry: "Designed (2026-05-10)" claimed in Status header line 3 + systems-index #6 row; specialists confirmed all 8 required sections + Visual/Audio + UI + Z + Appendix present (1658 lines, 0 placeholders, 34 AC, 12 locked decisions).

### Summary
Pillar 1 ("학습 도구") is **not delivered as written** per creative-director synthesis — 4 independent failures (B1, B5, B6, B.2/C.4.0 mental model gap REC-G3) each surfaced by a different specialist. Three architectural integrity blockers (B1 INT_MIN sentinel, B2 missing CI script, B3 unverified Godot 4.6 callback timing) compromise the foundation; B1 alone guarantees a phantom-jump bug on the first physics frame. The "Designed" posture was overstated. systems-index reverted to "In Design — NEEDS REVISION."

### Blocking items (consolidated, deduped across specialists)

| # | Tier | Source | Issue |
|---|------|--------|-------|
| B1 | Architectural | systems-designer + qa-lead + godot-gdscript-specialist (3-way convergence) | INT_MIN sentinel int64 overflow → phantom jump after restore (D.3 Formula 5 + AC-H5-04 + C.3.3 Scenario C). `current - INT_MIN` overflows to negative; predicate evaluates TRUE; jump fires unconditionally on first frame ≥ 1. AC-H5-04 prose describes the bug. |
| B2 | Architectural | qa-lead | `tools/ci/pm_static_check.sh` does not exist — 3 BLOCKING ACs (H7-03, H7-04, H3-04) silently pass. Same trap damage.md AC-26/27 hit pre-Round 4. |
| B3 | Architectural | gameplay-programmer | Godot 4.6 `AnimationPlayer.callback_mode_method` default unverified. If `DEFERRED`, entire `_is_restoring` guard model (C.4.1/4.2/4.4 + AC-H1-02/03 + VA.5) collapses — method-track callbacks fire next idle frame after Phase 1 cleared the guard. Engine-version-critical (post-cutoff). |
| B4 | Architectural | qa-lead | AC-H7-04 awk range pattern `,/^func \|^[a-zA-Z_]+/` collapses to function-signature line; body never inspected. Linked to B2. |
| B5 | Vision | game-designer | DEC-PM-3 "resume with live ammo" — Pillar 1 contradiction (rewind returns player to unwinnable state). Creative call required. 3 mitigation options: (A) partial restore, (B) snap exclusion, (C) schema amendment. |
| B6 | Vision | game-designer + art-director + audio-director (3-domain converged) | DYING-12-frame window: motor reaction <250ms (G1) + reads as engine hitch on couch (A6) + orphan "Q5" audio cue spec (AU2). 3 specialists, same window. No AC validates first-encounter rewind reachability. |
| B7 | Cross-doc | art-director | art-bible.md ABA-1..4 amendments deferred but VA.6 budget cites them (48×96 cell size, 8-way facing spec, i-frame flicker rule, DYING mood-table). Section 3 currently says "48px tall." VA section APPROVED contingent on amendments not yet applied. |
| B8 | Escalated | audio-director | 4 footstep variants × ~12 steps/sec sprint = robotic rattle within 1s. Pillar 1 readability issue. Escalated REC→BLOCKING. |
| B9 | Escalated | art-director | AimLock 1-frame body + sweeping arm = paper doll. + VA.1 "code-driven swap" contradicts VA.7 "AnimationPlayer-driven mandate" (internal contradiction). Escalated REC→BLOCKING. |
| B10 | Escalated | systems-designer + game-designer | `facing_threshold_outside=0.2` == `gamepad_deadzone=0.2`. Steam Deck stick drift flickers facing every frame. Need hysteresis pair (~0.25 enter / 0.15 exit). Escalated REC→BLOCKING. |

### Recommended revisions (22 items, deferred to revision pass)

- **G3** B.2 "되-실행 / 같은 탄막을 다시 본다" reads as world-rewind vs C.4.0 player-only mental model gap (no first-rewind comprehension AC).
- **G4** No audio cue for i-frame end (30 frames silent; player can't time re-engagement).
- **G6** Post-cut rise 7.9 px (5.5% of apex) sub-perceptual — variable jump cut functionally binary.
- **G7** DeadState single anim cannot dispatch DYING (12-frame stagger) vs DEAD (whiteout) — VA.2 spec gap.
- **S1** INV-1 + `@export_range` allow `gravity_rising=1100, gravity_falling=980` editor-valid combo; assert only catches in debug builds.
- **S4** D.2 (v_cut=100, g_falling=2200) → 2.27 px post-cut rise = functional jump cancel; INV protecting min cut absent.
- **S5** Sign-reversal frame count 9-22 across safe range; compound knob feel risk undocumented.
- **S6** `_ABS_VEL_X_EPS` boundary thrashing on slopes/walls (T14↔T15) — hysteresis missing.
- **Q4** AC-H1-02 mid-body `_is_restoring` observation needs mock listener spec.
- **Q5** AC-H3-01 1000-cycle test no const baseline — consistently-wrong values pass.
- **Q6** AC-H1-06 next-tick T5 auto-correct asserted in prose, no test clause.
- **Q7** AC-H2-04 emit-order assertion mechanism unspecified (count vs ordered tuple log).
- **Q8** AC-H4-04 ADVISORY playtest is feasible as Logic GUT (mock `Input.get_vector`).
- **Q9** AC-H8-01 ADVISORY label + BLOCKING failure-mode language inconsistent.
- **P2** C.3.4 `area_entered` claimed mid-`move_and_slide()` ordering — engine-implementation-specific; downgrade claim.
- **P3** Tuning Resource reference hot-swap bypasses INV-7 (setter-guarded only).
- **GD2** `call_deferred("connect", ...)` vs `signal.connect(callable, CONNECT_DEFERRED)` — different semantics; clarify intent.
- **GD3** `assert()` compiled out in Release — escalate INV-1/2 to `push_error()` + clamp.
- **GD4** `@export_range` editor-only enforcement; document explicitly in G.1 that runtime safe-range is debug-assert only.
- **GD5** `process_physics_priority` Inspector mandate is project policy, not engine constraint — clarify rationale.
- **A4–A10** (8 visual recommendations): AimLock paper-doll mitigation (lean variants), cyan→magenta inversion vs colorblind backup #4 cross-doc test, DYING flicker readability, pose-snap perceptual masking, 5+3 arm budget conditional on OQ-PM-5, idle/AimLock silence rationale vs Hotline Miami reference, VA.1/VA.7 contradiction.
- **AU4–AU11** (8 audio recommendations): -6 dB bus level deferral, idle silence rationale, land-impact fall-distance gate, "camera-autofocus" → "tactical bolt/safety-off" reference, DYING audio cross-ref, GUARD stale-fire behavior spec, audio reversal explicit, "ducks fully" dB number.

### Specialist disagreements
**No direct contradictions.** Closest case is the 12-frame DYING window: game-designer wants longer (motor reaction floor); art-director wants visually clearer at same length; audio-director needs cue spec — read as **3-domain convergence** on same finding (B6), not conflict.

VA.1 "code-driven swap" vs VA.7 "AnimationPlayer-driven mandate" is **internal GDD contradiction** (B9 part 2), not specialist disagreement.

### Cross-doc obligations preserved during revision
The 6 F.4.1 cross-doc edits applied in Session 9 (time-rewind.md F.1 #6, state-machine.md F.2 + C.2.1 + F.4 line 870, damage.md F.1 #6, systems-index #6, architecture.yaml 4 entries) **remain valid** — none are invalidated by the BLOCKING items. Revision should focus on player-movement.md sections D.3, C.4.x, VA.x, AC-H5-04/H7-03/H7-04/H3-04, DEC-PM-3 without disturbing cross-doc reciprocals.

### Recommended revision sequencing (solo dev, ~2-3 days)
1. **Research** (cheap): B3 verify Godot 4.6 `callback_mode_method` default in `docs/engine-reference/godot/` — 30 min.
2. **Math fix** (isolated): B1 INT_MIN → Optional/bool pattern + rewrite D.3 Formula 5 + AC-H5-04 + C.3.3 Scenario C. Half-day.
3. **Tooling fix** (isolated): B2 + B4 — author `tools/ci/pm_static_check.sh` OR rewrite the 3 ACs as runtime-checkable + fix awk regex. Half-day.
4. **Creative call** (user input): B5 ammo policy — pick A/B/C; cascade to time-rewind.md if C.
5. **Tier 2/3 cleanup**: B6 (DYING window option a/b/c), B7 (art-bible ABA pass or downgrade VA.6), B8 (footstep count), B9 (AimLock body variants + resolve VA.1/VA.7), B10 (hysteresis pair).
6. **RECOMMENDED batch** (~22 items) — apply inline during Tier 2/3 cleanup or queue as housekeeping pass.
7. **Re-review** in fresh session.

### Files to touch on revision
- `design/gdd/player-movement.md` — Sections D.3, C.4.x, VA.1/3/5/6/7, AC-H5-04/H7-03/H7-04/H3-04/H1-02/H3-01, DEC-PM-3, B.2 (mental model framing)
- `design/gdd/systems-index.md` row #6 — restore Status to `Designed (post-revision date)` after re-review PASS
- `tools/ci/pm_static_check.sh` — author, OR remove BLOCKING ACs that depend on it
- `design/art/art-bible.md` — ABA-1..4 amendments via separate `/quick-design` pass (if B7 takes "land ABA first" path)
- `docs/engine-reference/godot/` — record `callback_mode_method` 4.6 finding (whether IMMEDIATE or DEFERRED)
- (conditional on B5 option C) `design/gdd/time-rewind.md` + `docs/architecture/adr-0002-time-rewind-storage-format.md` Amendment 2 for ammo schema

### Confirmed correct (no action needed)
- 8/8 required sections present (Overview / Player Fantasy / C / D / E / F / G / H + Visual/Audio + UI + Z + Appendix)
- 12 locked decisions in Appendix A.1 — schema integrity preserved
- StateMachine multi-instance support (state-machine.md C.2.1 confirmed; PlayerMovementSM + EchoLifecycleSM both extend the framework)
- Typed const arrays (`Array[int]`, `Array[Vector2i]`) supported in GDScript 4.x
- `signi(0.0)=0` + threshold guard correctly gates encoding in D.4
- 64-bit `Engine.get_physics_frames()` — overflow ~4.8 billion years (non-issue)
- Palette hex values verified clean against art-bible Section 4 (Neon Cyan `#00F5D4`, Rewind Cyan `#7FFFEE`, Concrete Dark `#1A1A1E`, Concrete Mid `#3C3C44`, Pure White `#FFFFFF`)
- `StringName` correctly used for signal payload types
- OGG Vorbis format consistent with art-bible Section 8

### Cross-references for revision authors
- Specialist transcripts archived in conversation; key claims traceable via tags B1..B10 / G1..G8 / S1..S8 / Q1..Q12 / P1..P4 / GD1..GD10 / A1..A12 / AU1..AU13
- Mirror points to verify post-revision: `time-rewind.md` AC-A4/D5/F1/F2; `state-machine.md` AC-07/09/15/23; `damage.md` AC-9/12/20/21/29/36
