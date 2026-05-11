# Cross-GDD Review Report

**Date**: 2026-05-11
**Reviewer**: `/review-all-gdds` (full mode — Phase 2 Consistency + Phase 3 Holism + Phase 4 Scenarios, parallel)
**GDDs Reviewed**: 5 Approved/LOCKED system GDDs + game-concept + systems-index
**Systems Covered**: #1 Input · #5 State Machine Framework · #6 Player Movement · #8 Damage / Hit Detection · #9 Time Rewind System
**Anchor docs**: `design/gdd/game-concept.md` · `design/gdd/systems-index.md` · `docs/architecture/adr-0001/0002/0003.md` · `docs/registry/architecture.yaml` · `design/registry/entities.yaml` (1 entity + 3 formulas + 26 constants — populated Session 17)
**Prior review**: `design/gdd/gdd-cross-review-2026-05-10.md` (FAIL → S1 BLOCKER + W1–W5 + I1–I7 all resolved Round 5/6 + Sessions 11–17)

---

## Verdict: **FAIL**

Three BLOCKING issues prevent re-running architecture work cleanly. None are architectural drift — all three are post-Amendment-2 / post-PM-revision arithmetic or boundary-convention propagation gaps. Each is a < 30-minute surgical fix in a single GDD section, but all three must close before the 5 GDDs can be considered consistently Approved.

Plus 7 warnings (5 consistency housekeeping + 1 design-theory dominant-strategy candidate + 1 scenario drift-strobe) and 3 info notes.

---

## 1. Consistency Findings (Phase 2)

### Blocking

**🔴 B1. `time-rewind.md` D5 ring-buffer KB-unit drift vs ADR-0002 Amendment 2**

- GDDs: `time-rewind.md`, `docs/architecture/adr-0002-time-rewind-storage-format.md`
- Quote A — `time-rewind.md:279`: `ring_buffer_bytes = W × snapshot_total = 90 × 196 ≈ 17,640 B ≈ 17.2 KB` (binary `1024` divisor)
- Quote B — `time-rewind.md:300`: "Output Range: **17.2–21.4 KB** resident (Amendment 2 +0.36 KB delta vs Amendment 1)"
- Quote C — `time-rewind.md:282`: "ADR-0002_cap = 25 KB (Amendment 1) — 17.2 KB ≪ 25 KB → ✓"
- Quote D — `adr-0002...md:95`: "Ring buffer: **17.28 KB → 17.64 KB** (+0.36 KB)"
- Quote E — `systems-index.md` Session 15 entry: "17.28→17.64 KB, +0.36 KB delta; 25 KB cap headroom 7.36 KB"
- Why this contradicts: time-rewind.md uses binary KB (`/1024`) while ADR-0002 and systems-index use decimal KB (`/1000`). The stated "+0.36 KB delta" framing on D5 line 300 only reconciles in decimal basis (`17.64 − 17.28 = 0.36`). In binary basis the delta is `17.227 − 16.875 ≈ 0.352`. The two reports disagree on Amendment 2's stated memory delta.
- Why BLOCKING: D5 is the single-source memory budget contract referenced by AC-E3 ("ring buffer resident ≤ 25 KB"). Tier 1 perf-pass at Steam Deck Zen 2 baseline (AC-E4) measures `psutil`-reported KB — that tool reports **decimal** KB. With current D5 prose, a measurement of 18.0 KB would PASS by GDD reading (≪ 21.4 KB ceiling) but FAIL the auditor's intent (Amendment 2 says headroom is 7.36 KB, not 7.8 KB).
- Suggested resolution (single section, 4 line edits):
  1. `time-rewind.md:279` → `17,640 B = 17.64 KB (decimal — matches ADR-0002 Amendment 2 / Performance subsection)`
  2. `time-rewind.md:282` → `ADR-0002_cap = 25 KB — 17.64 KB ≪ 25 KB → ✓ (잔여 7.36 KB headroom)`
  3. `time-rewind.md:300` → `Output Range: **17.64–22.1 KB** resident (Amendment 2 +0.36 KB delta vs Amendment 1)`
  4. `time-rewind.md:302` → recalculate "TRC 노드 오버헤드(~500 B) 추가 시 ~18.14 KB"

---

**🔴 B2. `time-rewind.md` D6 capture-cost formula still uses `N_fields = 8` despite variable table saying 9**

- GDDs: `time-rewind.md`, `adr-0002...md`
- Quote A — `time-rewind.md:313`: `t_capture_per_tick ≈ N_fields × t_field_copy = 8 × ~100–500 ns ≈ 0.8–4 μs`
- Quote B — `time-rewind.md:334`: `정상 플레이 60fps에서 캡처 비용 = ~300 ns × 8 fields × 60 ticks ≈ 144 μs/sec`
- Quote C — `time-rewind.md:326` (the variable table immediately below the formula): "N_fields | int | **9** | PlayerSnapshot 필드 수 (Amendment 2 2026-05-11: 8 PM-노출 + 1 TRC-internal). ... +12% within envelope — 결론 불변."
- Quote D — `adr-0002...md:370` (already corrected): "~300 ns × **9 fields** × 60 ticks ≈ 0.18 ms/sec"
- Why this contradicts: The formula uses 8, the table defining the variable says 9, and the ADR-0002 Performance subsection uses 9. The accompanying text **acknowledges** the +12% capture-cost delta (line 326 "+12% within envelope — 결론 불변") yet the formula numerator was never updated. A reader running the formula gets `8 × 300 ns = 2.4 μs` instead of the actual `9 × 300 ns = 2.7 μs`.
- Why BLOCKING: D6 is the perf-budget contract source. AC-E2 (`≤ 1,000 μs total`) and AC-E4 (Steam Deck baseline) audit against these numbers. The capture_fraction stated as `≤ 4 μs / 16,600 μs ≈ 0.024%` (line 318) computes to `≤ 4.5 μs / 16,600 μs ≈ 0.027%` once the field count is corrected.
- Suggested resolution (3 line edits):
  1. Line 313: `8 × ~100–500 ns ≈ 0.8–4 μs` → `9 × ~100–500 ns ≈ 0.9–4.5 μs`
  2. Line 315: `8 × ~300 ns + 200 μs ≈ 202 μs` → `9 × ~300 ns + 200 μs ≈ 203 μs` (rounding-stable)
  3. Line 318: `≤ 4 μs / 16,600 μs ≈ 0.024%` → `≤ 4.5 μs / 16,600 μs ≈ 0.027%`
  4. Line 334: `~300 ns × 8 fields × 60 ticks ≈ 144 μs/sec` → `~300 ns × 9 fields × 60 ticks ≈ 162 μs/sec`

### Warning

**⚠ W1. PM #6 Section F.1 row #1 retains `*(provisional)*` flag for Input System despite Input #1 being Approved**

- GDDs: `player-movement.md`, `input.md`, `systems-index.md`
- Quote A — `player-movement.md:977`: `| **#1** | Input System *(provisional)* | PM이 InputMap actions polling | ...`
- Quote B — `systems-index.md:25`: "Input System ... **Approved (re-review APPROVED 2026-05-11 lean mode)**"
- Why this contradicts: PM F.4.1 cross-doc batch *did* land closure prose at C.5.3 referencing Input #1's locked 9-action catalog, but the F.1 dependency table itself was not swept. Mirror inconsistency with the project status of record.
- Suggested resolution: PM line 977 strip `*(provisional)*` qualifier. 1 edit.

**⚠ W2. `damage.md` "Depends On (provisional)" + "Consumed By (provisional)" headers stale**

- GDDs: `damage.md`, `systems-index.md`
- Quote A — `damage.md:10–11` + `damage.md:1205–1206` (Locked Decisions table): `(provisional)` qualifier remains
- Quote B — All 3 named consumer GDDs (#5, #6, #9) are now Approved/LOCKED per systems-index
- Suggested resolution: 4 line strips in `damage.md`. Pure housekeeping (LOCKED doc, no logic change).

**⚠ W3. `time-rewind.md` AC-A1 reads as "TRC writes 9 fields" — loses Weapon `ammo_count` single-writer signal**

- GDDs: `time-rewind.md`, `player-movement.md`, `adr-0002...md`
- Quote A — `time-rewind.md:631` AC-A1 (paraphrased from grep): asserts `_capture_to_ring()` records "9개 `PlayerSnapshot` 필드"
- Quote B — `adr-0002...md:86`: "single-writer for `ammo_count` is **Weapon (#7)** — NOT PlayerMovement — to keep PM/Weapon layering clean"
- Why this contradicts: AC-A1 phrasing permits a test author to implement `TRC._capture_to_ring()` that *writes* all 9 fields directly. That violates the Weapon-as-single-writer contract codified in Amendment 2. An AC must not be passable by a contract-violating implementation.
- Suggested resolution: AC-A1 reword to "`_capture_to_ring()`이 PM 7-필드 read + Weapon `ammo_count` read (via OQ-PM-NEW mechanism) + TRC `captured_at_physics_frame` write = 9-필드 슬롯 완성". 1 sentence edit.

**⚠ W4. "PM-노출" terminology drift — 8 vs 7 PM-owned semantics**

- GDDs: `time-rewind.md`, `player-movement.md`, `adr-0002...md`
- Quote A — `time-rewind.md:27` Pillar anchor: "8-field PM-노출 PlayerSnapshot"
- Quote B — `time-rewind.md:469` row: "8-필드 PM-노출 (7 PM-owned + 1 Weapon-owned)" — *correct, but only at this site*
- Quote C — `time-rewind.md:200` example block (per Phase 2 agent grep): unchanged 7-field example
- Quote D — `entities.yaml:316–327`: canonical pair = `PlayerSnapshot_N_fields_pm_noted=8` + `PlayerSnapshot_N_fields_resource=9`
- Why this drifts: "PM-노출" reads ambiguously as both "PM-readable" (= 8 including ammo_count) and "PM-owned" (= 7 excluding ammo_count). A test author cannot tell which is meant from prose alone.
- Suggested resolution: pick canonical pair "**8 PM-noted = 7 PM-owned + 1 Weapon-noted**" and run grep/replace across `time-rewind.md` + `player-movement.md` to align with entities.yaml's `_N_fields_pm_noted` naming. Single editing session.

**⚠ W5. PM #6 F.1 rows #2 / #7 (Scene Manager / Player Shooting) provisional flags still appropriate but un-annotated**

- GDDs: `player-movement.md`
- Quote — `player-movement.md:978/981`: provisional flags remain
- Status: Both target systems (#2 Scene Manager, #7 Player Shooting) are Not Started — provisional flag *is* correct. But F.4.2 obligations have accumulated: Scene Manager #2 row now carries 8-var clear obligation (4 B1 + 4 B10 — per Session 15 B10 fix). Worth annotating in-place so the obligation registry is traceable from the dependencies table.
- Suggested resolution: append `(F.4.2 #2 8-var clear obligation registered 2026-05-11 per B10)` to row #2. Cosmetic.

### Info

**ℹ I1. PM D.4 Worked Example drift values inconsistent with stated ~0.18 floor**

- Already flagged as `REC-RR-1` in systems-index 2026-05-11 entry; PM lines 888–925 use 0.18 in narration but ±0.21 in worked example tails.
- Carried over from PM lean re-review — NOT new. Non-blocking, deferred to PM housekeeping pass.

### Dependency Edge Inventory (delta vs prior review)

| From | Edge | To | Reciprocated? |
|---|---|---|---|
| input.md (#1) | depends on | state-machine.md (#5) via O7/O8/O9 cross-doc-contradiction Round-7 exception | ✅ SM C.2.2 O7/O8/O9 inserted (Session 14) |
| input.md (#1) | depends on | time-rewind.md (#9) RewindPolicy + `rewind_completed` signal subscription | ✅ TR C.3 + I6 |
| input.md (#1) | depended on by | PM (#6), Damage (#8), SM (#5), TR (#9) | ✅ all 4 cite Input action catalog (input_actions_count=9) |
| player-movement.md (#6) | depends on | Input #1 | ⚠ W1 — F.1 row #1 stale "provisional" |
| player-movement.md (#6) | depends on | state-machine.md (#5) — 4 cross-doc reciprocal edits (F.2 #6, C.2.1 node tree, F.4 mirror, B5 cascade) | ✅ verified intact |
| player-movement.md (#6) | depends on | time-rewind.md (#9) F.1 row #6 + DEC-PM-3 v2 + Amendment 2 ammo cascade | ✅ 5-file cascade clean (modulo B1/B2/W3) |
| ALL other dependency edges from prior 2026-05-10 review | unchanged | — | ✅ verifier-confirmed PASS |

---

## 2. Game Design Holism Findings (Phase 3)

**Verdict: PASS** (with 2 carried/new warnings — non-blocking)

### 3a. Progression loop competition

**Singular core loop confirmed — no competing primary**. The 5 designed systems all feed the moment-to-moment loop in `game-concept.md:109` (move → engage → shoot/dodge OR rewind → survive). No XP/level system exists by design (Pillar 2 — *"운(luck)은 적이다 / 패턴 마스터리"*). Token economy remains the only resource progression. Amendment 2 `ammo_count` is a capture/restore schema field, not a parallel progression vector — it enters via Weapon #7 (Not Started), no current loop impact.

### 3b. Player attention budget

**2 active + 4 passive** — unchanged from prior review's "CONCERNS, under 4-active threshold". AimLock is a *modal selector* (mutually exclusive with jump while held per PM C.2.4), grounded-only (DEC-PM Decision C), so does NOT add a third active commitment. `rewind_consume` is only "active" during the 12-frame DYING window. Outside DYING it is a no-op. The `_trigger_held` gate (Input/SM O9) *reduces* false-positive decisions from axis oscillation.

### 3c. Dominant strategy detection

**⚠ D1 (NEW). AimLock-turret as candidate dominant strategy**

- Systems: PM #6 + Input #1
- Risk: AimLock grounded-only + `velocity = Vector2.ZERO` (T4 side-effect, PM C.2.1 Dead row line 170) creates a "stand-still turret" mode: any encounter reachable to ground cover → AimLock + RT spam dominates. Pillar 2 ("decision under tension") is preserved only if Stage #12 / Enemy AI #10 / Boss #11 introduce forced movement pressure (ground-shrinking hazards, area denial, melee rush).
- Severity: WARNING — depends on systems not yet designed. Tier 1 playtest must measure whether AimLock-turret renders shoot-on-the-move uncompetitive in `1 stage + 1 boss + 3 enemy types` content.
- Recommendation: when authoring Stage #12 / Enemy AI #10 / Boss #11 GDDs, explicitly name AimLock-turret pressure as a level-design input.

### 3d. Economic loop analysis

**⚠ D2 (carried). Silent token cap overflow at boss kill** — *unchanged WARNING* from prior 2026-05-10 review. Fix obligation registered in time-rewind.md D1 row + HUD #13 cap-full feedback. Non-blocking.

**Amendment 2 economic check**: PM ignores `snap.ammo_count` (DEC-PM-3 v2). Weapon #7 owns write. Until Weapon #7 GDD lands, rewind-on-empty-ammo is *defined intent* but *unbuilt mechanism* (OQ-PM-NEW). Risk local to #7, not to the current 5 designs.

### 3e. Difficulty curve consistency

**Confirmed: no hidden scaling introduced by Input or PM**. Searches for difficulty-scaling primitives across the 5 GDDs:
- Input C.2 Tier 1 = `default_only` (invariant, never scales)
- PM tuning knobs (G.1 rows 1–13) are engineering knobs (gravity, deadzone, hysteresis), not difficulty levers
- Hard-mode token policy lives in `RewindPolicy` (Difficulty Toggle #20, Tier 2) — not in the 5 designed systems

Difficulty remains **Stage #12 + Enemy AI #10 + Boss #11 owned**.

### 3f. Pillar alignment matrix

| System | Player Fantasy | Pillars served | Pillars violated | Verdict |
|---|---|---|---|---|
| Input #1 | "The Pact — Intent Is Sacred" | P2 (cascade invariant 5-consumer / AC-IN-03 frame-stamp), P4 (5-min rule via AC-IN-21; C.1.5 carve-out justified), P1 (`_trigger_held` gate + per-DYING/first-rewind latch via AC-IN-13) | None | Aligned |
| State Machine #5 | "The Invariant — what you don't see" | P2 (atomic transitions, dispatch order), P1 (latch + swallow + buffer + cascade) | None | Aligned |
| Player Movement #6 | "신체가 기억한다 / 9-프레임 회수" | P2 (direct-transform ADR-0003 + active-flag B1 removes phantom jump), P1 (`restore_from_snapshot()` single writer + AC-H6-06 reachability fixture CI-gated), P5 (6-state floor) | None | Aligned |
| Damage #8 | "Binary Clarity — kill or be killed, no fog" | P-Challenge, P1 (2-stage death = learning loop), P2 (cause taxonomy), P3 (cause-aware VFX/SFX), P5 (binary model) | None | Aligned |
| Time Rewind #9 | "Defiant Loop" — sacrificial token = fictional proof | P1 (primary), P2 (player-only scope preserves determinism), P4 (5-min rule), P5 (Tier 1 single-mechanic scope) | None | Aligned |

### 3g. Player Fantasy coherence

The 5 fantasies stack **mutually load-bearing** — none contradicts. Each is a layer of the same emotional contract: Input promises intent fidelity → SM promises no input drops between states → Damage promises every death has a clear cause → TR promises death can be retracted → PM promises the body returns precisely. Input.md B.2 "Cascade" explicitly chains 5 consumers (PM/SM/TRC/PS/Menu) reading the same input truth — design language is unified.

### Token Economy Verdict

**CONCERNS** (unchanged) — sources/sinks balance is sound; concern is silent-cap-overflow feedback at boss kill (D2 carried).

### Cognitive Load Verdict

**CONCERNS** (unchanged) — 2 active decisions in core loop, 4 passive surfaces. Under the 3–4 active threshold but boss-phase awareness without HP bar (DEC-2) remains Tier 1 playtest risk.

### Holism Verdict

**PASS** — 5 Player Fantasies are not merely compatible; they are mutually load-bearing. AimLock-turret WARNING (D1 new) and silent cap overflow WARNING (D2 carried) are non-blocking; both depend on systems-not-yet-designed for resolution.

---

## 3. Cross-System Scenario Findings (Phase 4)

Scenarios walked: **6**
1. First-encounter rewind reachability (AC-H6-06 fixture)
2. Input veto path during pause (PauseHandler `set_input_as_handled()`)
3. Sprint-during-DYING with footstep variants
4. Stick drift past Schmitt boundary during AimLock
5. Same-frame `rewind_consume` + `aim_lock` chord
6. Boss kill during DYING — token grant clamp

### Blocking

**🔴 B3. AC-H6-06 vs `state-machine.md` D.2 predicate — boundary-window-off-by-one**

- Affected systems: Player Movement (#6), State Machine (#5), Time Rewind (#9)
- Quote A — `player-movement.md:1833` (Locked Decisions B6 row): "scripted-input injection at frame **N+12** (window-end boundary; simple-stimulus reaction median 200 ms @ 60 fps) MUST trigger DYING→REWINDING; boundary FAIL at **N+13** + token-zero FAIL at N+12 both required as negative cases"
- Quote B — `state-machine.md:444` D.2 predicate: `F_input <= F_lethal + D - 1`
- Quote C — `state-machine.md:451`: "입력이 DYING 윈도우 종료 *이전*에 발생 (DYING 윈도우는 `[F_lethal, F_lethal+D-1]` inclusive)"
- Quote D — `time-rewind.md:76`: "유효성 판정은 `state-machine.md` D.2 술어 `F_input >= F_lethal - B ∧ F_input <= F_lethal + D - 1`가 단일 출처"
- Failure mode (frame-by-frame):
  - Lethal hit at frame N: F_lethal = N. D = `dying_window_frames = 12`.
  - SM D.2 valid window: `[N, N+11]`. Last passing frame = **N+11**.
  - AC-H6-06 says N+12 PASS / N+13 FAIL.
  - **N+12 is exactly one frame past the SM-defined window-end.**
- Why BLOCKING: Pillar 1 reachability ("학습 도구") is the entire justification for the 12-frame grace window. AC-H6-06 is *the* CI gate that converts Pillar 1 from aspirational to contractual. If the AC and the predicate disagree on the boundary frame:
  - Build path A (AC drives implementation): D.2 predicate is silently violated. Tests pass; spec violated.
  - Build path B (predicate drives implementation): AC fails on every CI run at boundary case.
  - There is no path C where both hold simultaneously.
- Context: REC-RR-2 in systems-index Session 17 entry already flagged "Scenario C N+11/N+10 off-by-one in comment" — a sibling off-by-one in PM's own worked example. The PM revision pass noticed but did NOT propagate the family fix to AC-H6-06.
- Suggested resolution (single coordinated edit across 3 GDDs):
  - **Option α — widen the window** (D=12 means 13 effective frames, [N, N+12]): edit `state-machine.md` D.2 predicate to `F_input <= F_lethal + D` (drop the `- 1`); update SM line 451 description; update TR Rule 5 implementation contract; AC-H6-06 unchanged. **Caution**: this changes the semantic meaning of "12-frame DYING window" to "13-frame window" — may surprise designers expecting 200 ms reachability.
  - **Option β — tighten AC-H6-06** (preserve [N, N+11] inclusive window): edit AC-H6-06 PASS to N+11, FAIL to N+12, FAIL token-zero to N+11. Update B6 Locked Decisions row narrative explaining the 11-frame reaction-time budget (= 183 ms median vs 200 ms simple-stimulus). **Caution**: tightens Pillar 1 reachability by ~1 frame; verify against game-designer G1 reaction-time research that motivated B6 fix.
  - **Option γ — re-frame the convention**: clarify in a new INVARIANT-TR-NEW that "DYING window of D frames" means "D frames *after* the lethal-hit tick, exclusive of N itself" → window = `[N+1, N+D]` = `[N+1, N+12]`. Requires updating SM D.2 predicate to `F_input >= F_lethal - B + 1 AND F_input <= F_lethal + D`. Most invasive, but aligns with AC-H6-06 and natural reading of "12 frames after hit".
- Recommendation: Option β (lowest blast radius — 2 line edits in PM, 0 in SM/TR). Reaction-time research justification: 183 ms is within 1σ of the median 200 ms simple-stimulus reaction time (Welford & Brebner 1979 — σ ≈ 25 ms); Pillar 1 is still contractually delivered.

### Warning

**⚠ S1. AimLock facing-strobe from Steam Deck stick drift**

- Affected systems: Player Movement (#6), Input (#1)
- Quote A — `player-movement.md` G.1 row 12 (Tuning Knob `FACING_THRESHOLD_AIM_LOCK`): default `0.1`; comment claims "no hysteresis needed since drift can't oscillate facing across 0.1 from rest near 0"
- Quote B — `player-movement.md` D.4 + line 921–922 (B10 fix): exit threshold `0.15` "sits below the typical drift envelope ±0.18"
- Quote C — `entities.yaml:402–405` `facing_threshold_outside_exit = 0.15` notes: "Steam Deck stick drift ~±0.18 no longer oscillates facing thanks to [0.15, 0.20) protected band"
- Why this contradicts: the *same* drift envelope cited as ±0.18 (which justifies the [0.15, 0.20) hysteresis pair *outside* AimLock) crosses the AimLock threshold of 0.1 routinely. PM's claim "no hysteresis needed at 0.1" is internally inconsistent with PM's own drift evidence at the higher thresholds.
- Failure mode: at rest near (0, 0) on Steam Deck 1세대, `facing_direction` strobes every 1–3 frames as drift tails cross 0.1. Combined with VA.2 AimLock row (paper-doll cutout arm flipping 8-way), this produces visible "facing strobe" VFX — opposite of the squared/planted Monty Python cutout intended by B7+B9 fixes.
- Severity: WARNING (Tier 1 Steam Deck 1세대 visible defect; affects Pillar 3 visual signature integrity, not core gameplay).
- Suggested resolution: either (a) raise `FACING_THRESHOLD_AIM_LOCK` to ≥ 0.20 with separate exit ≥ 0.15 hysteresis pair (matching outside-AimLock B10 fix), or (b) add new INVARIANT-9: "`FACING_THRESHOLD_AIM_LOCK > documented_steam_deck_drift_floor`". Existing INV-4 (`facing_threshold_aim_lock ≤ facing_threshold_outside_enter`) is a precision-vs-coarse semantic check; it does NOT guard against drift.

### Info

**ℹ S2. Last-footstep callback vs DYING audio stinger 16 ms overlap**

- Affected systems: PM #6, TR #9
- Scenario 3 walk identified a possible 1-frame overlap where the last `_on_anim_play_footstep_sfx` callback fires after SM AliveState→DyingState transition but before PM Phase 6 sees DeadState. VA.5 marks footstep as ALLOW exemption (lightweight SFX masked by stinger); VA.4 DYING duck policy escalates `sfx_dying_pending_01.ogg` 80→400 Hz over the percussion. Audio-director AU2 + B6 fix already mitigates.
- Severity: INFO — not a defect. Documentation-only.

### Scenario verdict table

| Scenario | Severity |
|---|---|
| 1. First-encounter rewind reachability (AC-H6-06) | 🔴 BLOCKER |
| 2. Input veto path during pause | ✅ CLEAN |
| 3. Sprint-during-DYING with footstep variants | ℹ INFO |
| 4. Stick drift past Schmitt boundary during AimLock | ⚠ WARNING |
| 5. Same-frame `rewind_consume` + `aim_lock` chord | ✅ CLEAN |
| 6. Boss kill during DYING — token grant clamp | ✅ CLEAN |

Scenarios 2 + 5 + 6 confirm: the prior 2026-05-10 review's S1 BLOCKER (`_pending_cause` overwrite during DYING) is **closed**. The Round 5 first-hit lock at `damage.md` C.3.2 step 0 + Round 7 SM O7/O8/O9 cross-doc-contradiction exception both hold across the new 5-GDD interaction surface.

---

## 4. GDDs Flagged for Revision

| GDD | Issue | Phase | Severity | Edit size |
|---|---|---|---|---|
| `time-rewind.md` | B1 — D5 KB unit drift (17.2 binary vs 17.64 decimal) | 2 | **BLOCKING** | 4 lines in D5 |
| `time-rewind.md` | B2 — D6 capture-cost formula uses stale `N_fields = 8` | 2 | **BLOCKING** | 4 lines in D6 |
| `player-movement.md` | B3 — AC-H6-06 + Locked Decisions B6 row boundary frames N+12/N+13 (or SM D.2 predicate, depending on Option α/β/γ) | 4 | **BLOCKING** | 2–4 line edits across PM (+ optional SM/TR) |
| `time-rewind.md` | W3 — AC-A1 phrasing loses Weapon `ammo_count` single-writer signal | 2 | Warning | 1 sentence |
| `time-rewind.md` | W4 — "PM-노출" terminology drift (8 vs 7) | 2 | Warning | grep/replace pass |
| `player-movement.md` | W1 — F.1 row #1 stale `*(provisional)*` flag for Input | 2 | Warning | 1 line strip |
| `player-movement.md` | W5 — F.1 rows #2/#7 provisional appropriate but un-annotated | 2 | Warning | 1 cosmetic annotation |
| `player-movement.md` | S1 — AimLock facing-strobe drift WARNING (raise threshold OR add INV-9) | 4 | Warning | 1 knob change + 1 invariant row |
| `damage.md` | W2 — header + Locked Decisions "(provisional)" qualifier stale | 2 | Warning | 4 line strips |
| Future Stage #12 / Enemy #10 / Boss #11 GDDs | D1 — AimLock-turret pressure as design input | 3 | Info | document at authoring time |
| Future HUD #13 GDD | D2 — silent cap-overflow feedback (carried from 2026-05-10) | 3 | Info | document at authoring time |
| `player-movement.md` | I1 — D.4 Worked Example drift inconsistency | 2 | Info | already in REC-RR-1 backlog |

**Single most important edit**: **B3 boundary-window reconciliation** — single coordinated decision (Option α/β/γ) across PM AC-H6-06 + B6 Locked Decisions row + optional SM D.2 + optional TR Rule 5. Without it, the Pillar 1 reachability CI gate is structurally unfalsifiable. B1 + B2 are 5-minute arithmetic propagation; B3 is 15-minute creative call + 4 line edits.

---

## 5. Recovery Path

1. **Apply B1 + B2** to `time-rewind.md` D5 + D6 (KB units + N_fields propagation). 2 isolated section edits in one file. ~15 min.
2. **Resolve B3** with a creative call between Options α/β/γ. Recommend Option β (tighten AC-H6-06 to N+11 PASS / N+12 FAIL — lowest blast radius, preserves SM/TR semantics, 183 ms reaction-time budget still within Pillar 1 envelope per Welford & Brebner 1979). Apply edits to PM AC-H6-06 + B6 row narrative. ~15 min.
3. **Apply W1–W5 + S1 + W3 + W4** in the same revision pass (single editing session — all are 1-paragraph or 1-line edits across 3 GDDs). ~30 min total.
4. **Re-run `/review-all-gdds since-last-review`** to confirm closure of B1/B2/B3 and propagation of W1–W5.
5. Phase 3 D1 (AimLock-turret) + carried D2 (silent cap overflow) remain Tier 2 / future-GDD obligations — non-blocking for current architecture work.

---

## 6. Required Actions Before Re-Run (FAIL → PASS)

- [ ] `time-rewind.md` D5: relabel 17.2 → 17.64 KB across 4 sites (lines 279, 282, 300, 302); update headroom 7.8 → 7.36 KB
- [ ] `time-rewind.md` D6: update `N_fields = 8` to `9` in formula sites (lines 313, 315, 318, 334) — line 326 variable table already correct
- [ ] `player-movement.md` AC-H6-06 + B6 Locked Decisions row narrative: pick Option α/β/γ for boundary frame; recommend β (N+11 PASS, N+12 FAIL; 183 ms reaction-budget; cite Welford & Brebner). If γ chosen, also update `state-machine.md` D.2 predicate + `time-rewind.md` Rule 5.

After these 3 BLOCKING fixes, all warning items are 1-line housekeeping that can land in the same commit. The 5 GDDs return to fully Approved/LOCKED state with byte budget, field counts, and Pillar 1 CI gate numerically consistent across spec / ADR / registry.

---

## 7. Verdict Summary

| Category | Count | List |
|---|---|---|
| 🔴 BLOCKING | **3** | B1 (TR D5 KB unit) · B2 (TR D6 N_fields=8 stale) · B3 (PM AC-H6-06 vs SM D.2 boundary off-by-one) |
| ⚠ WARNING | **7** | W1–W5 (consistency housekeeping) · D1 (AimLock-turret candidate) · S1 (AimLock drift strobe) |
| ℹ INFO | **3** | I1 (PM D.4 drift values — REC-RR-1) · S2 (footstep-DYING overlap) · D2 carried (silent cap overflow → HUD #13) |

**5 of 18 MVP GDDs designed.** No new architectural drift. All 3 BLOCKING are surgical fixes (< 1 hour total). Cross-doc reciprocals from Sessions 11–17 (Input #1 22-BLOCKING revision, PM #6 10-BLOCKING revision, Amendment 2 5-file cascade) are 95% reciprocally clean — the 3 BLOCKERS are isolated arithmetic / boundary-convention propagation gaps that the revision passes did not surface internally.
