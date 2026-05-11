# Player Movement — Design Review Log

> Single source of truth for all `/design-review design/gdd/player-movement.md` verdicts. Each entry preserves the prior review's conclusion so re-reviews can verify whether blocking items were addressed.

---

## Review — 2026-05-11 (lean re-review) — Verdict: APPROVED
Scope signal: L (unchanged)
Specialists: none (lean mode — adversarial pass already completed in prior fresh-session review)
Mode: lean (Phases 1-4 + Phase 5 next-step widget; Phase 3b adversarial specialist spawn skipped)
Blocking items: 0 (all 10 prior BLOCKING resolved) | Recommended: 4 new minor + ~20 carried over from prior review | Nice-to-have: 0 new
Prior verdict resolved: **Yes** — 10/10 prior BLOCKING items closed; cross-doc cascade verified clean
GDD posture at review entry: "In Design" header line 3 with status row still showing NEEDS REVISION; specialists/codepaths/cross-docs in fact already updated to match Designed/Approved level.

### Summary
All 10 prior BLOCKING items verified resolved with citable spec / code / cross-doc evidence. The B1 active-flag pattern is structurally stronger than the prior 3-specialist-converged suggestion (bool short-circuit removes int math from the predicate path entirely — overflow impossible by construction, not just "fixed magnitude"). B3 sets a good precedent for engine-version-critical fixes (WebFetch verification + engine-reference recording + boot-assert + static grep). B5 cascaded correctly across 5 files (player-movement.md / time-rewind.md / adr-0002 / architecture.yaml / animation.md) without disturbing the Session 9 F.4.1 reciprocals. B6 converts a previously-asserted Pillar 1 claim into a CI-gated reachability proof (AC-H6-06 three-case fixture). Cross-doc consistency intact.

### Blocker resolution evidence
| # | Site | Verification |
|---|------|---------------|
| B1 INT_MIN sentinel | C.4.1 active-flag pattern + D.3 Formula 5 + Scenario C + AC-H5-04 negative-case clause | bool short-circuit gate; overflow impossible by construction |
| B2 missing pm_static_check.sh | `tools/ci/pm_static_check.sh` present | File exists; AC-H3-04/H7-03/H7-04 reference it as sole CI gate |
| B3 callback_mode_method | C.4.1 `_ready()` IMMEDIATE override + AC-H1-07 + `animation.md` "Critical Default" section | DEFERRED default confirmed via official docs; IMMEDIATE override mandatory + grep-enforced |
| B4 awk range collapse | AC-H7-04 rewritten as state-machine awk with `in_block` flag, BSD-awk-compat boundary | Validated by 3-fixture smoke test note |
| B5 ammo Pillar 1 contradiction | DEC-PM-3 v1 superseded; v2 adds `ammo_count` 8th PM-noted field; AC-H1-05 obsoleted + AC-H1-05-v2; ADR-0002 Amendment 2 Proposed | 5-file cross-doc cascade verified |
| B6 DYING 12-frame multi-domain | AC-H6-06 reachability fixture (3 cases) + VA.2 30 Hz flicker + VA.4 + time-rewind.md `sfx_dying_pending_01.ogg` 200 ms envelope | Pillar 1 reachability CI-gated |
| B7 art-bible ABA-1..4 | All 4 amendments ✅ Landed 2026-05-11; OQ-PM-6 closed | VA.8 status table confirms |
| B8 footstep variants | VA.4 + VA.5: 4 .ogg + per-step ±5% pitch jitter via dedicated `_footstep_rng` | ADR-0003 determinism preserved |
| B9 paper-doll + VA.1/VA.7 contradiction | VA.2 paper-doll = intentional Monty Python cutout; VA.7 R-VA-4 scope-clarified to frame-sequence-within-state | Internal contradiction resolved by scope precision |
| B10 facing == deadzone | D.4 dual Schmitt trigger + 4 new bool vars + G.1 enter/exit split + new INV-8 + F.4.2 Scene Manager #2 obligation 4→8-var | Hysteresis pair locked |

### New RECOMMENDED items this pass (4 minor, all cosmetic; queue with prior review's ~20 deferred items)
- **REC-RR-1** — D.4 Worked Example "Pre-B10 oscillation case the fix blocks" uses `(-0.21, 0.0)` as drift input, but rationale text states drift floor ~0.18; example is internally inconsistent (-0.21 magnitude is above stated drift floor; both pre/post-B10 produce same outcome at 0.21). Recommend rewriting with `(0.18, 0.0)`-bounded values to actually showcase the [0.15, 0.20) protected band.
- **REC-RR-2** — D.3 Formula 5 Scenario C: Frame label "Frame N+11 (restore_from_snapshot...)" but assignment shows `_last_grounded_frame = N+10`. Off-by-one in comment.
- **REC-RR-3** — Status header (player-movement.md line 3) still reads "In Design" + A.7 update template not yet applied. Should advance to "Approved (re-review APPROVED 2026-05-11 lean mode)".
- **REC-RR-4** — H section preamble shows progressive AC counts (28 → 29 → 30 BLOCKING) but no final tally; A.1 row notes "36 AC / 30 BLOCKING / 6 ADVISORY". Add 1-row tally in H preamble for easy verification.

### Specialist disagreements
None applicable (lean mode — no specialists spawned this pass).

### Cross-doc reciprocals verified intact
- ✓ `time-rewind.md` F.1 row #6: 8-field interface verbatim + ammo_count Amendment 2 + provisional removed
- ✓ `state-machine.md` C.2.1 line 180+: `PlayerMovement (CharacterBody2D, root)` model (Round 5 exception applied); F.2 row #6 line 846 PlayerMovementSM extends StateMachine M2 reuse
- ✓ `damage.md` F.1 row #6 line 800: ECHO HurtBox + HitBox + Damage hosted as PlayerMovement children
- ✓ `docs/architecture/adr-0002-time-rewind-storage-format.md` Amendment 2 (Proposed): 9-field Resource (8 PM-noted + 1 TRC-internal)
- ✓ `docs/registry/architecture.yaml`: 4 PM entries (state_ownership.player_movement_state / interfaces.player_movement_snapshot / forbidden_patterns.delta_accumulator_in_movement / api_decisions.facing_direction_encoding) + last_updated 2026-05-11 with ammo_count extension noted
- ✓ `docs/engine-reference/godot/modules/animation.md`: "Critical Default" section records B3 finding with required `_ready()` override pattern + boot-time assert recommendation
- ✓ `tools/ci/pm_static_check.sh`: file present

### Senior Verdict (lean-mode self-attest synthesis)
Pillar 1 ("학습 도구") failure points from prior review (B1 / B5 / B6 / C.4.0 mental model) are all now demonstrably closed. Three architectural integrity blockers (B1, B2, B3) closed with (a) by-construction safety, (b) physical file presence, (c) post-cutoff engine fact verified against official docs and recorded in engine-reference. Cross-doc reciprocal hygiene intact; B10 forward-compatibility risk caught (Scene Manager #2 4→8-var obligation expansion).

### Status transition
- Status header in player-movement.md line 3: still "In Design" (REC-RR-3) — should advance per A.7 template.
- `systems-index.md` System #6 row: "In Design — NEEDS REVISION" → "Approved (re-review APPROVED 2026-05-11 lean mode)".
- Progress Tracker: Approved 4→5; Designed (pending re-review) 0→0; In Design 1→0.

### Recommended next actions
1. **`/consistency-check`** (user-selected) — verify no value conflicts across the 5 now-Approved/LOCKED system GDDs (#1 Input, #5 SM, #6 PM, #8 Damage, #9 TR). Catches cross-GDD drift before architecture/Tier 1 prototype work.
2. **Housekeeping pass** (deferred to user discretion) — apply REC-RR-1..4 inline + the ~20 carried-over RECOMMENDED items from prior review log (G4 i-frame end cue, G6 post-cut rise rationale, S1 INV-1 + @export_range, Q4-Q9 mock listener specs, P2/P3, GD2-GD5, A4-A10, AU4-AU11).
3. **Tier 1 prototype risk-unblocking**: OQ-PM-2 (`seek(time, true)` looping anim verification — R-VA-1 HIGH risk) before idle/run frame authoring.
4. **Next system candidates** (per recommended design order): Scene Manager #2 (resolves OQ-PM-1 8-var ephemeral clear responsibility — B1 + B10 cascade obligation), Player Shooting #7 (resolves OQ-PM-NEW Weapon ammo restoration orchestration), or HUD #13 (Tier 1 token UI).

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
