# Damage GDD Review Log

`design/gdd/damage.md` 디자인 리뷰 이력. 신규 리뷰 시 *위*에 prepend.

---

## Review — 2026-05-09 (Round 4) — Verdict: LOCK & PROTOTYPE → 적용 완료

Scope signal: **L** — 39 ACs unchanged, 3 surgical fixes applied (2 AC-text + 1 spec off-by-one correction). creative-director meta-verdict: "Pillar 5 'small success > big ambition' is being violated by *continuing to review*, not by stopping."
Specialists consulted: qa-lead (sync), godot-specialist (async ✓), game-designer (async ✓), systems-designer (async ✓ — post-lock return triggered "Locked Decision empirical falsification" exception)
Senior: creative-director (synthesis)
Blocking items: **3** | Recommended: **5 (deferred to post-lock observations)** | Resolved: **3/3 BLOCKING in same session**

### Summary

Round 4 invoked despite Round 3's "stop reviewing and start prototyping" directive. qa-lead surfaced 2 genuinely tightenable AC defects:

- **BLOCK-R4-1 (qa-lead)**: AC-21 grep regex `state_machine\.(current_state|is_rewinding|get_state)` only catches 3 named members. Misses `state_machine.active_state`, `state_machine.state`, and `get_node("StateMachine").current_state` aliases. Architectural gate `damage_polls_sm_state` overstates coverage. Solo dev under time pressure is exactly the scenario where this shortcut appears.
- **BLOCK-R4-2 (qa-lead)**: AC-29 1000-cycle determinism test as written allows self-referential baseline (run-1 captured as expected, runs 2-1000 compared against). A system broken from t=0 produces a consistent-wrong order and the test passes silently. Time-rewind prototype is the riskiest system; a determinism test that lies is worse than no test.

creative-director synthesis upheld both as surgical fixes (~30 min total), explicitly *not* design changes, applied inline without spawning a Round 5. Other Round 4 specialist findings (if returned post-lock) go to "post-lock observations" log only — no further revision rounds short of empirical falsification of a Locked Decision during prototype.

### Fixes Applied

- **BLOCK-R4-1 (qa-lead)**: AC-21 broadened to two greps — (1) `state_machine\.[a-zA-Z_]+` for any member access, (2) `get_node\(.*StateMachine.*\)\.[a-zA-Z_]+` for node-path aliases. Added PR review checklist obligation when new SM members are named.
- **BLOCK-R4-2 (qa-lead)**: AC-29 reframed — `expected_order` is now a hardcoded fixture constant (`const EXPECTED_ORDER := [&"enemy_A", &"enemy_B", &"enemy_C"]`) defined by parent-child + sibling index; each cycle compares actual emit order against this fixture via strict equality. Run-1 self-capture explicitly forbidden in AC text.
- **B-R4-1 (systems-designer — Locked Decision empirical falsification)**: DEC-6 hazard grace counter initialization changed to `hazard_grace_frames + 1` (default 13) in `start_hazard_grace()`. Trace verified: F0 set 13 → priority-2 decrement → 12; subsequent flush windows F0+1..F0+12 block hazards (12 ✓); F0+13 passes through (counter=0). C.6.4 invariant note rewritten with full trace; AC-24 reframed to verify 12 distinct blocks + 1 pass-through; G.1 knob description updated to clarify `+1` is implementation detail (player-facing semantics still 12 frames / 200ms protection). DEC-6 design intent preserved.

### Deferred (Round 4 RECOMMENDED — non-blocking)

- AC-30 Steam Deck Integration label vs deferred hardware reality (OQ-DMG-10) — milestone-gate dependency, not sprint-Done.
- AC-15 dual placement in H.10 file layout — intentional but unmarked.
- `architecture.yaml` line 33 metadata staleness ("Round 2 review" comment) — opportunistic update during next ADR pass.

### Post-Lock Observations (per creative-director directive — log only, do not gate prototype)

- **[godot-specialist] Verdict: GODOT PATTERNS CORRECT — no BLOCKING.** All 9 targeted Godot 4.6 idiom checks pass against `docs/engine-reference/godot/`: Area2D monitorable semantics, bit/value translation (D.1.4 Example 3 math verified `0b100100`=36), `process_physics_priority` API name (Round 3 B-3 fix correct), `area_entered`-before-`_physics_process` ordering invariant (C.6.4 confirmed), `get_connections()` connect-order determinism (AC-28 sound assuming no pre-`_ready()` connects), `class_name HitBox/HurtBox` registry safety, `&""` StringName literal syntax stable, `queue_free()` deferred-to-frame-end timing (E.12 correct), broadphase cost distinction. Round 3 B-3 fix (Damage=2 priority slot + Frame-N boundary invariant) sound.
- **[godot-specialist] R-NEW-1 (RECOMMENDED, post-lock)**: GDD does not note that future code paths toggling `HurtBox.monitorable` from inside a `hurtbox_hit` handler or `area_entered` callback MUST use `set_deferred("monitorable", false)` to avoid Godot's physics-step property-modification guard. Current design (SM toggles in `_physics_process`) is safe. One-line implementation note in C.6.2 or F.4 would pre-empt future risk. **Apply during Tier 1 prototype only if a future story moves the toggle into a callback context** — not gating.
- **[game-designer] Verdict: PROTOTYPE-READY — no BLOCKING.** Pillar 1/2/5 all UPHELD. B.1–B.4 Player Fantasy integrity confirmed throughout C–G mechanical sections. No HP-bar leakage, no pity mechanic, no soft-currency contamination. Spec density high but justified by 5-upstream/5-downstream integration scope. No gold-plating.
- **[game-designer] REC-R4-GD-1 (APPLIED inline)**: Cross-doc timing gap between damage.md DEC-6 (12-frame hazard-only grace post-rewind) and time-rewind.md E-17 (`hazard_oob` re-death at i-frame end). Net behavior: re-death in REWINDING-then-hazard_oob scenario is deferred frame N+30+12 = N+42, not N+30. Two programmers reading two docs in isolation would implement different timings. **Applied**: damage.md E.13 now includes cross-reference note acknowledging additive delay + reciprocal-note obligation for time-rewind.md E-17. Single source: damage.md DEC-6 + C.6.4. (time-rewind.md E-17 reciprocal update queued for next time-rewind GDD edit.)
- **[systems-designer] Verdict: NEW DEGENERACY → B-R4-1 BLOCKING (APPLIED inline — Locked Decision empirical falsification)**. DEC-6 hazard grace was 11 flush windows, not 12 — off-by-one from priority ladder. Trace: `RewindingState.exit()` runs in ECHO `_physics_process` (priority 0) → sets counter=12 → same-frame Damage `_physics_process` (priority 2) decrements to 11 before next flush_queries. Player got ~183ms protection, spec promised 200ms. **Applied**: counter initialization changed to `hazard_grace_frames + 1` (=13) in `start_hazard_grace()`; AC-24 reframed to verify 12 distinct flush blocks + 1 pass-through; C.6.4 invariant note rewritten with full trace; G.1 knob description updated. This was the exception-to-lock case creative-director allowed: "Locked Decision empirically falsified". DEC-6's "12 frames" intent preserved by spec correction.
- **[systems-designer] R-R4-1 (RECOMMENDED, post-lock — deferred)**: `begins_with("hazard_")` predicate case-sensitive, no runtime guard. Future stage dev setting `cause = &"Hazard_spike"` (capital H) silently fails grace. Apply during Tier 1 prototype if a stage author trips this; otherwise add `assert` in `start_hazard_grace()` opportunistically.
- **[systems-designer] R-R4-2 (RECOMMENDED, post-lock — deferred)**: AC-29 1000-cycle determinism depends on `(spawn_frame, spawn_id)` ordering from ADR-0003, but `spawn_id` allocation strategy (global monotonic vs per-orchestrator) is unspecified. AC-29 effectively blocked pending ADR-0003 amendment. Flag during ADR-0003 priority-ladder update (already queued).
- **[systems-designer] R-R4-3 (RECOMMENDED, post-lock — deferred)**: AC-35 doesn't catch dynamically spawned hazards with `collision_layer=0` or zero-area shapes. Low risk for authored .tscn hosts; relevant only if Tier 2 stage code spawns hazards programmatically. Add `push_error` guards in HitBox/HurtBox `_ready()` then.

### Cross-GDD Sync (verified in-sync, no edits needed)

- `time-rewind.md` F.1 #8 row → links + signatures + DEC-6 cross-link present.
- `state-machine.md` F.1 #8 row → confirms `damage.start_hazard_grace()` invocation in `RewindingState.exit()`.
- `systems-index.md` System #8 row → bumped to "LOCKED for prototype (Round 4)".
- `architecture.yaml` damage_signals contract → reflects Round 2 changes; minor metadata staleness noted but non-blocking.

### Meta-Verdict (creative-director)

> "The doc is done. Apply the two AC fixes inline now, lock damage.md, and start the time-rewind ring buffer prototype. Cancel any in-flight Round 4 specialist agents; their findings, if any, go to the post-lock log. No Round 5 under any circumstance short of a Locked Decision being empirically falsified by the prototype."

Prior verdict resolved: Round 3 NEEDS REVISION (4 BLOCKING applied) — Round 4 confirmed all Round 3 fixes hold.

---

## Review — 2026-05-09 (Round 3) — Verdict: NEEDS REVISION → 적용 완료

Scope signal: **L (bordering XL)** — 39 ACs, 9 signals, 5+5 cross-system touchpoints, 3 ADRs queued. creative-director meta-observation: "AAA-studio specification density for a Tier 1 combat subsystem."
Specialists: game-designer, systems-designer, qa-lead, godot-specialist
Senior: creative-director (synthesis)
Blocking items: **4** | Recommended: **18 (deferred per creative-director)** | Resolved: **4/4 BLOCKING in same session**

### Summary

4-specialist Round 3 adversarial pass identified residual issues post-Round-2. Convergent BLOCKING findings:

- **B-1 (game-designer + godot-specialist)**: `hurtbox_hit` emission contract contradicted across C.1.2 / D.3.1 / F.1#7 / F.4.1 / AC-19. Two programmers reading two sections produce different code (double-emit or recursion).
- **B-2 (systems-designer)**: D.2.1 aggregate formula vs C.4.2 per-call handler — concrete trace shows boss multi-hit can advance two phases in one tick when `phase_hp_table[next] < remaining_hits`. AC-14 worked example accidentally passes only because `phase_hp_table[1]=8 >> hit_count`.
- **B-3 (godot-specialist)**: Damage `_physics_process` priority absent from ADR-0003 ladder. Frame-N boundary ordering between `area_entered` dispatch and grace decrement undocumented.
- **B-4 (qa-lead + systems-designer)**: H.11 AC count math wrong — stated 27 Logic GUT, actual 29; column sum 37 vs claimed 39.

creative-director synthesis demoted 14 specialist findings (RECOMMENDED) to deferral status, citing solo-dev pragmatism: "You are no longer protecting yourself from ambiguity — you are simulating a multi-person review process for an audience of one." Verdict: **NEEDS REVISION** with surgical fixes only, then "stop reviewing and start prototyping."

### Fixes Applied

- **B-1**: Single emit point at HitBox script (C.1.2). D.3.1 reframed as host-side cause assignment obligation table (not runtime function). F.4.1 ECHO/Boss blocks remove redundant re-emit. AC-19 reframed to "host sets cause at instantiation". AC-8 extended to verify `hurtbox_hit` not re-emitted from Damage handler.
- **B-2**: `_phase_advanced_this_frame: bool` flag on BossHost, reset in `_physics_process`, early-return at handler entry. D.2.3 reconciled. AC-14 worst-case `phase_hp_table[next]=1` added.
- **B-3**: Damage `_physics_process` priority=2 (between TRC=1 and enemies=10). C.6.4 frame-N boundary invariant documented. ADR-0003 1-line update queued.
- **B-4**: "Logic GUT: 27" → "29" with AC-29 explicit in enumeration. Sum check 29+6+3+1=39 ✓.

### Cross-GDD Sync

- `state-machine.md` F.1 row #8: `damage.start_hazard_grace()` invocation obligation in `RewindingState.exit()` documented (Round 2 미완 의무 해소).
- `time-rewind.md` Rule 11: DEC-6 cross-link added (Round 2 미완 의무 해소).

### ADR Queue (3건 — Round 2의 2건 + 신규 1건)

1. **OQ-DMG-8 → ADR `boss-phase-advance-monotonicity`** — D.2.3 monotonic +1 lock (Boss Pattern GDD #11 작성 직전)
2. **OQ-DMG-9 → ADR `signal-emit-order-determinism`** — F.4.1/F.4.2 결정론 contract (Tier 1 prototype 시작 직전)
3. **신규** — ADR-0003 `physics_step_ordering` 사다리에 Damage=2 1-line 추가 (Boss Pattern GDD 작성 시 OQ-DMG-9와 함께 처리)

### Deferred Recommendations (18건 — 의도적)

creative-director 권고: 다음 리뷰는 "Round 4 design-review"가 아니라 *Tier 1 prototype의 ambiguity discovery*일 때만 발동. 주요 deferred items:
- DEC-6 hazard grace player-readable 시그널 (B.3 fantasy contract — playtest 결정)
- DEC-5 `is_last_hit` boolean lock vs anti-counter AC (solo-dev self-discipline mitigates)
- AC-21 grep 정규식 robustness (90% 솔루션 수용)
- AC-30 Steam Deck CPU 프로파일 split (실측 시 정밀화)
- HurtBox.monitoring=true 디폴트 vs PhysicsServer2D 비용 (실측 시 결정)
- AC-28 `get_connections()[0]` 행동 검증 idiom 변경
- AC-25 `await physics_frame` → `process_frame` 변경
- 외 11건 (각각 Tier 1 prototype 발견 시 단발 갱신)

Prior verdict resolved: Round 2 verdict (MAJOR REVISION) — Round 3 confirmed Round 2's 8 BLOCKING all addressed; Round 3 found 4 *new* structural defects.

---

## Review — 2026-05-09 (Round 2) — Verdict: MAJOR REVISION NEEDED → 적용 완료

Scope signal: **XL** (5 upstream + 5 downstream + 9 시그널 + 신규 ADR 2건 queued)
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, godot-gdscript-specialist, ai-programmer, performance-analyst
Senior: creative-director (synthesis)
Blocking items: **8** | Recommended: **12** | Resolved: **20/20** in same session

### Summary

7-specialist 적대적 리뷰가 5개 BLOCKING 합의를 식별: (1) `monitoring`/`monitorable` 7개 사이트 일관성 결함, (2) E.13 hazard 영구 거주가 Pillar 1 직접 위반, (3) D.1.4 Example 3 mask `0b101100` typo, (4) emit 순서 결정론 contract 부재, (5) AC 4건 커버리지 갭 + AC-9/15/22 broken. creative-director 시놉시스가 MAJOR REVISION 권고. 사용자 4개 디자인 결정 widget 처리 후 일괄 수정 적용:

- DEC-5 (`boss_hit_absorbed` 2-arg, hits_remaining 제거 — binary contract architectural 보호)
- DEC-6 (REWINDING.exit() 직후 12프레임 hazard-only grace — Pillar 1 보호)
- 신규 시그널 `boss_pattern_interrupted` (in-flight pattern cleanup)
- 신규 invocation API `start_hazard_grace`
- D.2.3 monotonic +1 phase advance를 ADR로 격상 (queued)
- emit 순서 결정론 contract (F.4.1 / F.4.2)
- AC 8건 신규 (AC-28~35) + AC-6 분할 (6a~6d) + AC-18 분할 (18a/b) → 27 → 39 ACs
- B.2 "Mirror Principle" → "Threat Symmetry"로 재명명 + 회복 비대칭 명시
- Steam Deck 멀티플라이어 명시 + frame budget 1.0ms knob 추가
- monitoring → monitorable 7개 사이트 일괄 정정
- D.1.4 mask typo 정정 (0b101100 → 0b100100)

Prior verdict resolved: First review (Round 1 design 기반)

### Architecture Registry 동기화

`docs/registry/architecture.yaml`:
- `interfaces.damage_signals.signal_signature`: `boss_hit_absorbed` 2-arg + `boss_pattern_interrupted` 신규
- `interfaces.damage_signals.invocation_api`: `start_hazard_grace` 추가
- `interfaces.damage_signals.emit_ordering_contract`: 신규 키 (F.4.1)
- `last_updated`: 2026-05-09 Round 2

### Cross-GDD Sync

- `state-machine.md`: RewindingState.exit()에서 `damage.start_hazard_grace()` 호출 1줄 추가 의무
- `time-rewind.md`: Rule 11 보강 (DEC-6 hazard grace 명시 가능)
- `systems-index.md`: System #8 Status → "Designed (Round 2 reviewed)"

### ADR Queue (2건)

1. **OQ-DMG-8 → ADR `boss-phase-advance-monotonicity`** — D.2.3 monotonic +1 lock (Boss Pattern GDD #11 작성 직전)
2. **OQ-DMG-9 → ADR `signal-emit-order-determinism`** — F.4.1/F.4.2 결정론 contract architecture-level 격상 (Tier 1 prototype 시작 직전)

### 미완 의무 (Round 2 후속)

- `state-machine.md` RewindingState.exit() invocation 1줄 추가
- `time-rewind.md` Rule 11 DEC-6 cross-link 추가
- ADR 2건 작성

---
