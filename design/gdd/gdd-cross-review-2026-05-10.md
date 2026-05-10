# Cross-GDD Review Report

**Date**: 2026-05-10
**Reviewer**: `/review-all-gdds` (full mode — Phase 2 Consistency + Phase 3 Holism + Phase 4 Scenarios, parallel)
**GDDs Reviewed**: 3 system GDDs + game-concept + systems-index
**Systems Covered**: #5 State Machine Framework · #8 Damage / Hit Detection · #9 Time Rewind System
**Anchor docs**: `design/gdd/game-concept.md` · `design/gdd/systems-index.md` · `docs/architecture/adr-0001/0002/0003.md` · `docs/registry/architecture.yaml` · `design/registry/entities.yaml` (empty — pre-built baseline N/A)

---

## Verdict: **FAIL**

One BLOCKING issue prevents architecture work from beginning. The blocker is a cross-doc contract violation: `time-rewind.md` Rule 17 asserts that the SM `_lethal_hit_latched` blocks TRC `_lethal_hit_head` re-cache and `damage.md` E.1 asserts that `_pending_cause` is fixed to the first hit — but the implementation contract in `damage.md` C.3.2 has no mechanism enforcing either invariant. This is a real implementation gap, not a doc-drift cosmetic issue, and it crosses the Round 4 LOCK threshold via the `cross-doc contradiction` exception in `damage.md`'s own Round 5 directive.

All other findings (5 consistency warnings, 2 design-theory warnings, 8 info notes) are non-blocking.

---

## 1. Consistency Findings (Phase 2)

### Blocking
*(none from Phase 2 — see Phase 4 Scenario 1 for the cross-doc invariant violation)*

### Warning

**⚠ W1. Hazard grace duration: time-rewind.md says "12프레임", damage.md F.4 says `= hazard_grace_frames`, but DEC-6 / C.6.5 / G.1 require `+ 1` (= 13)**
- GDDs: `damage.md`, `time-rewind.md`
- Quote A — `damage.md` C.6.4/C.6.5: "`_hazard_grace_remaining: int = hazard_grace_frames + 1 = 13` set (Round 4 B-R4-1 fix — `+1`은 동프레임 priority-2 decrement 보상)"
- Quote B — `damage.md` F.4 row: "`_hazard_grace_remaining = hazard_grace_frames` set" (missing `+ 1`)
- Quote C — `time-rewind.md` Rule 11: "12프레임 *hazard-only* grace 윈도우" (no mention of internal `+ 1` init)
- Why this contradicts: Three locations, two values. F.4 row is the *single-source contract* row exposed to other GDDs. A reader of F.4 implements 12; AC-24 expects 13 effective windows. Both within `damage.md` and across GDDs, the math reconciles only if you read C.6.5/G.1 — which a downstream programmer is not required to read.
- Suggested resolution: edit `damage.md` F.4 row to read "`_hazard_grace_remaining = hazard_grace_frames + 1` set (DEC-6 / B-R4-1 — same-frame priority-2 decrement compensation)". Add a one-line `time-rewind.md` Rule 11 note: "(damage.md DEC-6 single source: counter init = `hazard_grace_frames + 1` internally; do not implement counter init here.)"

**⚠ W2. `rewind_completed` signal parameter name drift**
- GDDs: `time-rewind.md`, `state-machine.md`
- Quote A — `time-rewind.md` Rule 9: `rewind_completed.emit(_player, snap.captured_at_physics_frame)`
- Quote B — `state-machine.md` F.1 row #9: `rewind_completed(player: Node2D, restored_to_frame: int)`
- Why this contradicts: same int value, different declared parameter name. Behaviour identical, but the declared `signal` line must be one canonical name; downstream subscribers (HUD, VFX) implementing `_on_rewind_completed(player, restored_to_frame)` will mismatch the actual declared signal signature.
- Suggested resolution: pick one canonical parameter name. Recommend `restored_to_frame: int` since it describes downstream semantics (the snapshot's captured frame IS the frame the player is now restored to). Update `time-rewind.md` C.3 declaration + `architecture.yaml` `interfaces.rewind_lifecycle`.

**⚠ W3. Input polling implementation prose mismatch**
- GDDs: `time-rewind.md`, `state-machine.md`
- Quote A — `time-rewind.md` Rule 5: "치명타 등록 직전 `RewindPolicy.input_buffer_pre_hit_frames` 프레임(기본 4 / 0.067s)부터 DYING 윈도우 종료까지의 `\"rewind_consume\"` 입력은 유효하다."
- Quote B — `state-machine.md` C.2.2 O3: "AliveState/DyingState 모두 `physics_update`에서 `Input.is_action_just_pressed(\"rewind_consume\")` 체크 → 발견 시 위 변수 갱신."
- Why this contradicts: `time-rewind.md` prose suggests a backwards-looking window starting at `F_lethal - B`, which would require historical input log. `state-machine.md` solves it correctly with always-poll + predicate-gate. Both converge to the same valid-window predicate, but a programmer reading `time-rewind.md` alone would implement the wrong primitive.
- Suggested resolution: append to `time-rewind.md` Rule 5: "(implementation: SM polls input every tick from AliveState onward; predicate `F_input >= F_lethal - B ∧ F_input <= F_lethal + D - 1` gates validity — see state-machine.md D.2.)"

**⚠ W4. Process priority ladder missing Damage=2 row in state-machine.md**
- GDDs: `state-machine.md`, `damage.md`, `time-rewind.md`
- Quote A — `state-machine.md` C.3.1: ladder lists priorities `0` (Player), `1` (TRC), `10` (enemies), `20` (projectiles) — **`2` (Damage) row missing**.
- Quote B — `damage.md` C.6.4 + Quote C `time-rewind.md` Rule 16: both explicitly state Damage=2 between TRC and enemies.
- Why this contradicts: cross-doc drift only — SM behaviour does not depend on Damage=2 (host inherits priority 0). But the table in C.3.1 is shown to readers as the canonical ladder reference; missing row implies Damage is unscheduled.
- Suggested resolution: insert `| 2 | Damage component (damage.md C.6.4) |` between TRC=1 and enemies=10 rows in `state-machine.md` C.3.1.

**⚠ W5. `damage.md` E.13 ↔ `time-rewind.md` E-17 reciprocal note still outstanding (Session 5 deferred)**
- GDDs: `damage.md`, `time-rewind.md`
- Quote A — `damage.md` E.13: "**time-rewind E-17에도 reciprocal note (DEC-6 12프레임 추가 지연 명시) 의무**"
- Quote B — `time-rewind.md` E-17: no DEC-6 cross-link or `+12` qualifier
- Why this contradicts: `hazard_oob` re-death timing differs by GDD: `time-rewind.md` E-17 reads "frame N+30" (i-frame end). `damage.md` E.13 says actual re-death is N+30+12=N+42 because `hazard_oob` is a hazard-prefixed cause that triggers DEC-6 grace. Two readers will implement different timings. (Note: this was logged as REC-R4-GD-1 in Session 5 active.md as "queued for next time-rewind GDD edit" — still pending.)
- Suggested resolution: edit `time-rewind.md` E-17 to add the cross-doc paragraph specified in `damage.md` E.13. Single-paragraph edit.

### Info

**ℹ I1. `boss_pattern_interrupted` parameter naming (damage.md internal)** — F.3 declares `prev_phase_index`, C.4.2 emits with local var `phase_index`. Value matches (pre-increment); add inline comment.

**ℹ I2. DYING→DEAD direct path latch clear** — `time-rewind.md` AC-C2 Round-2 explicitly enumerates this clearance, but `state-machine.md` AC-15 / Rule 17 only lists REWINDING→ALIVE and REWINDING→DEAD. Implied (DEAD always clears) but not enumerated. Add explicit row to AC-15.

**ℹ I3. ECHO 4-state machine single-source ownership confirmed** — `time-rewind.md` is sole owner; `state-machine.md` and `damage.md` correctly reference rather than redefine. Clean.

**ℹ I4. RESTORE_OFFSET_FRAMES (O=9) ownership clean** — owned by ADR-0002, referenced (not duplicated) by `time-rewind.md`. `state-machine.md` and `damage.md` do not duplicate.

**ℹ I5. Snapshot capture pause invariants clean** — owned by `time-rewind.md` Rule 2/9 + ADR-0002 Amendment 1. No drift.

**ℹ I6. systems-index Depends-On column update outstanding** — `time-rewind.md` System #9 row already lists Input(#1) + Scene Manager(#2) per Session 3 update; verified.

**ℹ I7. `_lethal_hit_head` cache lifetime across scene transition unspecified** — `time-rewind.md` Rule 4 caches it on `lethal_hit_detected`; AC-D3 invalidates `_buffer_primed` on `scene_will_change` but does not explicitly clear `_lethal_hit_head`. Naturally guarded by Rule 13-bis warm-up (90 frames) — safe today but worth a one-line note.

**ℹ I8. Entity registry empty** — `design/registry/entities.yaml` has no entries. Pre-built consistency baseline unavailable. Recommend running `/consistency-check` after this review to seed it.

### Dependency Edge Inventory

| From | Edge | To | Reciprocated? |
|---|---|---|---|
| time-rewind.md | depends on | state-machine.md (#5) | ✅ state-machine.md F.1 + F.2 + C.2.2 6 obligations |
| time-rewind.md | depends on | damage.md (#8) signals | ✅ damage.md F.2 + F.3 + DEC-1 |
| time-rewind.md | depends on | Input (#1) / Scene Manager (#2) / Player Movement (#6) | ❌ those GDDs not yet written (acknowledged provisional) |
| state-machine.md | depends on | damage.md (#8) — `player_hit_lethal` 1-arg | ✅ damage.md F.2 + DEC-1 |
| state-machine.md | depends on | time-rewind.md (#9) — 5 signals + `try_consume_rewind()` | ✅ time-rewind.md C.3 + Rules 4–11 |
| state-machine.md | depends on | Scene Manager (#2) / Input (#1) | ❌ those GDDs not yet written |
| damage.md | depends on | state-machine.md — invokes `commit_death()` / `cancel_pending_death()` / `start_hazard_grace()` | ✅ state-machine.md C.2.2 O1+O2 + F.1 |
| damage.md | depends on | host clients (#6/#7/#10/#11/#12) | ❌ host GDDs not yet written (provisional) |
| damage.md | depended on by | state-machine.md (#5), time-rewind.md (#9), HUD/VFX/Audio | ✅ first two; remainder pending |
| damage.md (DEC-6) | imposes obligation on | state-machine.md `RewindingState.exit()` | ✅ state-machine.md F.1 row #8 explicitly mentions invocation |
| damage.md E.13 | imposes reciprocal note on | time-rewind.md E-17 | ❌ **outstanding** (W5) |

### Frame-by-frame Walkthrough Verdict (lethal-hit sequence)

**PASS with one CONCERN (W5 cross-doc reciprocal)**. The three GDDs agree on every numbered frame of the lethal-hit sequence: frame N hit → flush-phase emit ordering → connect-order-determined TRC→SM dispatch → DYING entry + latch set + `_pending_cause` set → frames N+1..N+11 grace → either DYING→DEAD via `commit_death()` OR DYING→REWINDING via `cancel_pending_death()` → REWINDING 30-frame i-frame → `RewindingState.exit()` → `start_hazard_grace()` → AliveState entry + latch clear. Process-priority ladder consistent (W4 doc-drift only). Snapshot capture pause invariants consistent. Lethal-hit-head freeze timing consistent.

---

## 2. Game Design Holism Findings (Phase 3)

### Blocking
*(none)*

### Warning

**⚠ D1. Silent Token Cap Overflow at Boss Kill**
- Affected systems: Time Rewind (#9), HUD (#13)
- Issue: When `_tokens == max_tokens` (5) and `boss_defeated` fires, `grant_token()` clamps silently. AC-B3 confirms cap holds, but no feedback contract exists for a "no-op grant". `token_replenished` still emits, but the player sees no net change. Anti-fantasy "비싼 자원을 썼다 — 모든 거래가 느껴져야" is broken at cap.
- Recommendation: define a "cap already full" branch in HUD token contract — distinct visual flash or audio cue. Add note in `time-rewind.md` Tuning Knobs that `max_tokens=5` makes this case inevitable in some runs (player caps before final boss).

**⚠ D2. Aggregate Invisible Recovery Window (~58 frames / 0.97s)**
- Affected systems: Time Rewind (#9), Damage (#8), Stage/Encounter (#12 — not yet designed)
- Issue: Lethal hit → recovery aggregate = 4f input buffer + 12f DYING grace + 30f REWINDING i-frame + 12f hazard-only grace = 58 frames (~0.97s) of *some* form of protection. Each window is justified individually; the aggregate is invisible. Damage.md B.1's "binary clarity — 한 발이 곧 죽음" promise operates at the moment of contact, but post-hit aggregate materially softens threat density. Stage GDD #12 (the actual difficulty carrier — see I-D3 below) will need this aggregate as a calibration constraint.
- Recommendation: document the 58-frame aggregate as a first-class design constraint. When Stage GDD #12 is authored, name this as a level-design input.

### Info

**ℹ D3. Difficulty curve lives in an undesigned system** — None of the 3 approved GDDs have difficulty-scaling mechanics; binary damage is flat across stages, token capacity is flat. Difficulty = enemy density + pattern complexity = entirely Stage GDD #12. Reasonable choice given Pillar 2, but means a reader of these 3 GDDs alone would conclude Echo has no difficulty curve. When Stage GDD is authored, name it as the sole difficulty carrier.

**ℹ D4. Pillar 1 / Pillar 2 alignment gated on Collage Rendering visual readability** — Time Rewind functions as a *learning* tool only when deaths are caused by player error rather than perceptual failure. Pillar 2 handles AI determinism; the residual risk is Collage Rendering occluding bullet readability (game-concept R-D2). The 0.2s glance test is the named gate. Add Collage Rendering (#15) as a soft dependency to `time-rewind.md` Dependencies with the note: "Pillar 1 fantasy integrity depends on #15 passing 0.2s glance test (R-D2 mitigation)."

### Pillar Alignment Matrix

| System | Player Fantasy | Pillars served | Pillars violated | Verdict |
|---|---|---|---|---|
| Time Rewind | "Defiant Loop" — 사망 직전 0.15s 복원, 토큰 소비, 항의 | P1 (primary), P2 (player-only scope preserves determinism), P4 (5분 룰), P5 (Tier 1 single-mechanic scope) | None | Aligned |
| State Machine | Framework invariant — player won't notice | P1 (input buffer + latch saves 12-frame grace), P2 (signal-reactive, not polled → determinism foundation) | None | Aligned |
| Damage | "Binary Clarity — kill or be killed, no fog" | P1 (2-stage death = mechanical realisation of learning loop), P2 (cause taxonomy = traceable death = determinism), P3 (cause-aware VFX/SFX = collage signature foundation), P5 (binary model prevents HP balance table explosion) | None | Aligned |

P1 vs P2 special check: rewind does NOT paper over RNG (rewind into same RNG outcome = no help). System serves P1 only when P2 already holds. Mutually reinforcing, not competing.

### Token Economy Verdict

**CONCERNS** — sources/sinks balance is sound (sources: starting 3 + 1 per boss kill; sink: rewind consumption; cap 5 prevents runaway). The concern is **silent overflow behaviour at cap** (D1), not economy collapse.

### Cognitive Load Verdict

**CONCERNS** — 2 active decisions in core loop (movement context + binary rewind decision); 4 passive surfaces. Under the 3-4 active threshold. Concern is boss-phase awareness without HP bar (DEC-2): first-session players manage 3 active loads (movement + shoot + rewind) while *also* learning boss phase structure for the first time. Tier 1 playtest risk, not design flaw.

### Holism Verdict

**PASS** — the three Player Fantasies (Defiant Loop / systemic invariant / binary clarity) are not merely compatible; they are mutually load-bearing. SM's grace-window guarantee is the prerequisite for the rewind to feel intentional. Binary clarity (Damage) is the prerequisite for rewind to function as a learning tool (you cannot learn from a death you don't understand).

---

## 3. Cross-System Scenario Findings (Phase 4)

### Blocking

**🔴 S1. `_pending_cause` overwrite + `_lethal_hit_head` re-cache during DYING — invariants asserted but not implemented**
- Affected systems: Damage (#8), Time Rewind (#9), State Machine (#5)
- Steps where the gap appears:
  1. Frame N flush: ECHO HurtBox `area_entered` → `_on_hurtbox_hit(cause)` → `damage.md` C.3.2 step 1 sets `_pending_cause = cause₀` *unconditionally* → step 2 emits `lethal_hit_detected(cause₀)` → TRC caches `_lethal_hit_head = _write_head` → step 3 emits `player_hit_lethal(cause₀)` → SM AliveState → DyingState; latch=true.
  2. **`DyingState.enter()` does NOT toggle `echo_hurtbox.monitorable=false`** — DEC-4 + `damage.md` C.6.2 explicitly assign that responsibility only to `RewindingState.enter()`. So during DYING (frames N..N+11), HurtBox stays monitorable and `area_entered` keeps firing on subsequent hits.
  3. Frame N or any of N+1..N+11: second hit fires (piercing AOE, multi-projectile burst, acid pool tick). Damage handler re-enters: step 1 `_pending_cause = cause₁` (overwrites cause₀). Step 2 emits `lethal_hit_detected(cause₁)` → TRC re-runs handler → re-caches `_lethal_hit_head` (now possibly = `_write_head` advanced by 1+ frames if the second hit is on a later tick). Step 3 emits `player_hit_lethal(cause₁)` → SM latch guard short-circuits ✓.
  4. Frame N+12 (no rewind): `commit_death()` emits `death_committed(cause₁)` — **wrong cause**. Or, if rewind was attempted at frame N+5, `restore_idx` derived from possibly-stale `_lethal_hit_head` → restore to a position the player wasn't actually at when struck.
- Failure modes: contradictory messaging (cause attribution), broken state transition (TRC cache integrity), undefined behaviour (cross-frame multi-hit semantics).
- Contracts asserted but not enforced:
  - `damage.md` E.1 step 3: "`_pending_cause`는 첫 hit의 cause로 고정. 잔여 hit cause는 폐기."
  - `time-rewind.md` Rule 17: "연속 데미지(산성 풀, 레이저 sweep)와 같은 틱 다중 치명타가 `_lethal_hit_head`를 재캐시하는 것을 차단한다 (E-12, E-13)."
  - Both invariants depend on the SM `_lethal_hit_latched`. But the latch only blocks step 3 (SM dispatch). Steps 1–2 run before the latch is reached, and `lethal_hit_detected` (TRC) and `player_hit_lethal` (SM) are *separate signals* — TRC has no equivalent latch.
- Recommended resolution (single-line, preserves DEC-4 single-source):
  Add an idempotency guard at the top of `damage.md` C.3.2 step 1, mirroring the existing `commit_death()` guard at C.3.3:
  ```text
  ECHO Damage._on_hurtbox_hit(cause):
    if _pending_cause != &"": return    # ← NEW — first-hit lock
    _pending_cause = cause
    emit lethal_hit_detected(cause)
    emit player_hit_lethal(cause)
  ```
  - Add new acceptance criterion AC-30: "Same-frame second `hurtbox_hit` arrival during DYING does not overwrite `_pending_cause` and does not re-emit `lethal_hit_detected`."
  - Update `damage.md` E.1 to point to the C.3.2 guard instead of just claiming the invariant.
  - Update `time-rewind.md` Rule 17 to clarify: "TRC re-cache prevention is provided by the Damage-side `_pending_cause` guard at `damage.md` C.3.2 step 0; SM `_lethal_hit_latched` is the *secondary* guard for SM dispatch only."
  - The fix is a 1-line code addition + a 1-line AC + a 2-doc cross-link. It does not change any locked decision (DEC-1..6) or any ADR. It IS a post-LOCK change — requires user judgment per `damage.md`'s own Round 5 directive: *"Round 5 차단 except (a) prototype empirical falsification (b) new cross-doc contradiction"*. This finding qualifies as exception (b).

### Warning

**⚠ S6. Hazard grace 12-frame off-by-one — cross-doc reciprocal note missing (= W5)**
- This is the same finding as W5 above. Phase 4 walked through the math frame-by-frame and confirmed: the implementation math (init=13, decrement once same-frame to 12, then 11 more flushes blocked) is correct in `damage.md`. The remaining gap is purely the missing reciprocal note in `time-rewind.md` E-17.
- Severity: WARNING (already raised as W5). Not a logic gap — a doc-reciprocity gap.

### Info

**ℹ S3-info. `_lethal_hit_head` non-clearing on scene transition** — same as I7 above. Not a defect today; worth a one-line note in Rule 4 / AC-D3.

### Scenario Verdict Table

| Scenario | Severity |
|---|---|
| 1 — Tick boundary (`_pending_cause` overwrite + TRC re-cache during DYING) | **🔴 BLOCKER** |
| 2 — Frame N+11 rewind (latch lifecycle, i-frame entry timing) | ✅ CLEAN |
| 3 — Death commit (cause data flow + scene transition) | ✅ CLEAN (1 INFO) |
| 4 — Boss advance during DYING (phase lock + rewind immunity) | ✅ CLEAN |
| 5 — i-frame double-rewind | ✅ CLEAN |
| 6 — Hazard grace off-by-one (math correct; doc reciprocal missing) | ⚠ WARNING |

The four already-applied fixes (lethal-hit head freeze, `_phase_advanced_this_frame` lock, hazard grace `+1`, AC-C2 latch clear) all close their stated scenarios correctly. Scenario 1 is the new finding — a genuine implementation gap masked by the invariant-claim language in two GDDs.

---

## 4. GDDs Flagged for Revision

| GDD | Issue | Phase | Severity | Edit size |
|---|---|---|---|---|
| `damage.md` | S1 — add `_pending_cause` first-hit lock to C.3.2; new AC-30 | 4 | **BLOCKING** | 1 line code + 1 line AC + footnote |
| `damage.md` | W1 — F.4 row missing `+ 1` on `start_hazard_grace()` | 2 | Warning | 1 line in F.4 row |
| `damage.md` | I1 — C.4.2 `boss_pattern_interrupted` emit-name comment | 2 | Info | inline comment |
| `time-rewind.md` | S1/W5 — Rule 17 secondary-guard clarification + E-17 DEC-6 reciprocal note | 4 + 2 | Blocking + Warning | 2 single-paragraph edits |
| `time-rewind.md` | W2 — `rewind_completed` parameter name canonicalisation | 2 | Warning | 1 declaration line + ADR registry update |
| `time-rewind.md` | W3 — Rule 5 implementation note (always-poll predicate) | 2 | Warning | 1 sentence |
| `time-rewind.md` | D4 — add Collage Rendering (#15) as soft dependency for Pillar 1 readability | 3 | Info | 1 row in Dependencies + 1 sentence |
| `time-rewind.md` | I7 — Rule 4 / AC-D3 `_lethal_hit_head` non-clear note | 2 | Info | 1 sentence |
| `state-machine.md` | W4 — C.3.1 ladder missing Damage=2 row | 2 | Warning | 1 table row |
| `state-machine.md` | I2 — AC-15 enumerate DYING→DEAD direct latch clear | 2 | Info | 1 sentence in AC-15 |
| `time-rewind.md` (HUD) | D1 — silent cap-overflow feedback contract gap | 3 | Warning | 1 paragraph in Tuning Knobs + cross-link to future HUD GDD |
| Stage GDD #12 (future) | D2/D3 — 58-frame aggregate recovery + difficulty-carrier role | 3 | Info | document at authoring time |

Single most important edit: **`damage.md` C.3.2 first-hit lock** (1 line of pseudocode). Everything else is doc reciprocity or future-system cross-links.

---

## 5. Recovery Path

`damage.md` is currently `LOCKED for prototype` (Round 4). The S1 BLOCKER falls under the Round 5 exception clause `cross-doc contradiction`. Suggested next step:

1. **Apply S1 fix** to `damage.md` C.3.2 + new AC-30 + footnote pointing to invariant claim now being enforced. Update `time-rewind.md` Rule 17 secondary-guard clarification reciprocally. (Round 5 surgical post-lock fix per the same precedent that allowed Round 4 B-R4-1.)
2. **Apply W1–W5 + I1, I2, I7** in the same revision pass (single editing session — all are 1-paragraph or 1-line edits across the three GDDs).
3. Re-run `/review-all-gdds since-last-review` to confirm closure, then proceed to next system GDD authoring.

The Phase 3 holism findings (D1/D2/D3/D4) are non-blocking and can be addressed at HUD GDD / Stage GDD / Collage Rendering GDD authoring time.

---

## 6. Required Actions Before Re-Run (FAIL → PASS)

- [ ] `damage.md` C.3.2: add first-hit `_pending_cause` lock; document new AC-30; update E.1 to point to enforcement site.
- [ ] `time-rewind.md` Rule 17: clarify primary guard is Damage-side, SM latch is secondary.
- [ ] (Optional but recommended in same pass) `damage.md` F.4 row `+ 1` fix; `time-rewind.md` E-17 reciprocal note; `state-machine.md` C.3.1 Damage=2 row.

After these edits, all blocking and most warning items close. Architecture work (#5/#8/#9 stack) can begin.
