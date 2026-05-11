# Scene / Stage Manager — Review Log

This log tracks every `/design-review` pass on `design/gdd/scene-manager.md`. Each entry records the verdict, blockers found, and what changed between passes so future re-reviews can verify prior closure.

---

## Review — 2026-05-11 — Verdict: NEEDS REVISION (resolved inline this session)

**Mode**: `/design-review design/gdd/scene-manager.md --depth lean`
**Scope signal**: L (Large — multi-system integration: 5 cross-doc reciprocals + 2 registry batch entries + 7 Phase 5d GDD edits + 17-site `boss_defeated→boss_killed` housekeeping batch; 6 formulas, 25 ACs, 11 downstream dependents; no new ADR required)
**Specialists**: None (lean mode — single-session analysis)
**Re-review of prior verdict**: First review — no prior log entry
**Completeness**: 8/8 required sections present (Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria) + Visual/Audio + UI + Open Questions + Z Appendix

### Findings

| Severity | Count | Items |
|---|---|---|
| **BLOCKING** | 1 | D.5 `BoundaryState` enum omits PANIC referenced in E.1 |
| **RECOMMENDED** | 4 | Cross-doc drift count undercount · AC-H1 mock-shim test scope · C.3.3 priority-ladder rationale · F.1 system-number breadcrumb |
| **Nice-to-Have** | 2 | D.4 engine-bootloader scope · A.4 protocol guardrail |

#### BLOCKING — fixed inline

1. **D.5 `BoundaryState` enum omits PANIC referenced in E.1** — D.5 variable table declared `BoundaryState enum {CLEAR_PENDING, RESTART_PENDING, ACTIVE, BOOT_INTRO}` (4 values) but E.1 said "boundary state를 PANIC으로 진입" on null PackedScene. Implementability gap — a programmer couldn't determine whether PANIC was (a) a 5th enum value or (b) a separate `_panic` flag.
   - **Fix**: Added PANIC as 5th enum value (per user choice). D.5 variable table now reads `{BOOT_INTRO, ACTIVE, RESTART_PENDING, CLEAR_PENDING, PANIC}` (5 values). D.5 Output Range note added clarifying PANIC is set by E.1's diagnostic path and bypasses D.5's same-tick evaluation (lifecycle blocked). E.1 text changed from "boundary state를 PANIC으로 진입" to `` `_boundary_state = BoundaryState.PANIC` 설정 (D.5 enum 5번째 값) ``.

#### RECOMMENDED — fixed inline

2. **Cross-doc drift count undercount** — C.1 Rule 12 / C.3.5 / F.4.1 estimated "TR ~8 sites + SM ~5 sites = ~13 simple replacements" for `boss_defeated → boss_killed` housekeeping. Actual `grep -c` at HEAD: TR 13 sites + SM 4 sites = **17 simple replacements**. Risk: sprint-planning underestimates scope.
   - **Fix**: All 4 occurrences (Rule 12 rationale, drift table, C.3.5, F.4.1) updated to "TR 13 + SM 4 = 17 simple replacements (HEAD `grep -c` 실측 2026-05-11)".

3. **AC-H1 test mechanism uses mock shim — doesn't exercise real Godot engine path** — AC-H1's GUT integration test uses a mock `change_scene_to_packed` shim, validating the wiring contract (M+K+1 ≤ 60 arithmetic) but not the real engine path. AC-H23 `[MANUAL]` covers real hardware but is ADVISORY.
   - **Fix**: Added explicit "Test scope" notes to both ACs (per user choice — option A: relabel rather than add AC-H1b or promote AC-H23 to BLOCKING). AC-H1 labeled "contract-level (mock shim)"; AC-H23 labeled "real-engine path on Steam Deck 1세대"; both cross-reference each other. Gap acknowledged: AC-H1 catches wiring regressions in CI; AC-H23 catches engine/asset-budget regressions only visible on real hardware.

4. **C.3.3 same-tick rationale cites priority ladder EchoLifecycleSM isn't on** — Text claimed "ADR-0003 priority ladder forces Damage(2) → Boss host(10) emit order, so `state_changed` fires before `boss_killed`." But `state_changed` is emitted by EchoLifecycleSM (player lifecycle SM), whose slot is not enumerated in the ADR-0003 ladder (PlayerMovement=0, TRC=1, Damage=2, enemies=10, projectiles=20). The defensive early-return guard in the GDScript pattern handles both orders correctly, so the **policy** was sound but the **rationale** was misleading.
   - **Fix**: C.3.3 + D.5 Edge note (2 sites) rewritten (per user choice — option A: rephrase rather than amend ADR-0003) to drop the priority-ladder ordering claim and lean on the early-return guard: "order is undefined; the `_boundary_state == CLEAR_PENDING` early-return guard ensures CLEAR_PENDING wins regardless of arrival order."

5. **F.1 system-number references lack breadcrumb** — F.1 cited "#3 Camera", "#4 Audio", etc. without saying these were `systems-index.md` row numbers.
   - **Fix**: One-sentence breadcrumb added at F.1 head: "Numbering convention: `#N` references the row number in `design/gdd/systems-index.md`. Status mirrors that index at HEAD; status drift between this table and the index is a lint signal."

#### Nice-to-Have — fixed inline

6. **D.4 cold-boot scope boundary** — `t_process_start_ms` is captured at `SceneManager._ready()`, not at OS process launch. Engine bootloader time before any GDScript runs was silently excluded.
   - **Fix**: D.4 "Engine bootloader gap (scope boundary)" paragraph added — acknowledges gap (typically ≪ 1 s on SSD), notes that if Steam Deck 1세대 AC-H2b measurements approach the 300 s ceiling, switch to OS stopwatch or `OS.get_unix_time_from_system()` capture.

7. **A.4 protocol violation guardrail** — A.4 self-flagged that qa-lead wrote Section H directly to file without Draft→Approval→Write protocol. User accepted post-hoc.
   - **Fix**: Guardrail sentence added: "agents must surface a user-visible draft and obtain explicit approval before any Write/Edit, regardless of section size or perceived quality. H's content quality is **not** a precedent for skipping protocol — see `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`."

### Strengths (noted but not actionable)

- **Section B → AC traceability**: 3 invariants in Player Fantasy map 1:1 to AC-H1 / AC-H2a-b / AC-H3a-b
- **Coverage matrices**: H.5 explicitly verifies all 14 Rules + 6 Formulas + 8 of 10 Edges → AC coverage; 2 Edges deferred with surfaced reason (H.U1–H.U3)
- **Falsifiability**: 6 formulas with worked examples, boundary values, and unit-test mechanisms
- **Pre-registered Tier 2 revision triggers**: A.5 explicitly enumerates which rules/sections need amendment when Tier 2 (2-3 stages) is unlocked, reducing future re-design risk
- **OQ resolution log**: 3 carried OQs (OQ-4 / OQ-PM-1 / OQ-SM-2) cleanly closed via numbered Rules with explicit "Resolves" pointers; 5 new OQs registered with closure owners and triggers

### Verification

- Re-grep at HEAD post-fixes: no stale `~13`, `~8 사이트`, `~5 사이트`, `4 values`, or priority-ladder ordering claim residuals.
- Edits touched 10 sites: D.5 variable table · D.5 Output Range note · E.1 · C.3.3 priority paragraph · D.5 Edge note · C.1 Rule 12 rationale · C.1 drift table · C.3.5 · F.4.1 · AC-H1 · AC-H23 · F.1 head · D.4 · A.4. No section-skeleton changes; no AC count change (still 25 ACs).
- Cross-doc reciprocals (Phase 5d batch): not yet applied. Deferred to post-re-review per session state plan.
- `boss_defeated → boss_killed` housekeeping batch: not yet applied. Deferred to separate non-blocking commit.

### Outcome

- **Verdict at start**: NEEDS REVISION (1 BLOCKING + 4 RECOMMENDED + 2 Nice-to-Have)
- **Verdict at end of session**: All 7 items fixed inline. Status promoted In Design → **Designed (pending re-review)** in systems-index Row #2.
- **Next**: Fresh `/clear` session + `/design-review design/gdd/scene-manager.md --depth lean` for independent re-review. Only after that PASS, promote to **Approved** and apply Phase 5d batch + housekeeping batch.
- **Prior verdict resolved**: First review — no prior verdict to compare.

---

## Review — 2026-05-11 (second pass, same day) — Verdict: NEEDS REVISION (resolved inline this session)

**Mode**: `/design-review design/gdd/scene-manager.md --depth lean` (re-review session — independent verification of prior NEEDS REVISION 7-item closure)
**Scope signal**: L (unchanged — multi-system integration; 5 cross-doc reciprocals + Phase 5d batch + housekeeping batch queued)
**Specialists**: None (lean mode — single-session analysis)
**Re-review of prior verdict**: Yes — prior verdict on this same day was NEEDS REVISION with 7 items reported fixed inline.

### Prior closure verification (7 items)

All 7 items from the earlier same-day NEEDS REVISION pass verified at HEAD:

| # | Prior item | HEAD evidence |
|---|---|---|
| 1 | BLOCKING — D.5 `BoundaryState` enum omits PANIC | ✅ D.5 line 516 lists 5 values incl. PANIC; E.1 cites "D.5 enum 5번째 값"; Output Range note explains PANIC bypass |
| 2 | RECOMMENDED — Cross-doc drift count undercount (~13 → 17) | ✅ `grep -c boss_defeated` HEAD measured: TR=13, SM=4, sum=17; all 4 quoted sites in scene-manager.md updated |
| 3 | RECOMMENDED — AC-H1 mock-shim test scope | ✅ AC-H1 line 813 "contract-level (mock shim)"; AC-H23 "real-engine path on Steam Deck 1세대"; cross-references intact |
| 4 | RECOMMENDED — C.3.3 priority-ladder rationale | ✅ C.3.3 + D.5 Edge both lean on `_boundary_state == CLEAR_PENDING` early-return guard; ordering claim removed |
| 5 | RECOMMENDED — F.1 system-number breadcrumb | ✅ F.1 head sentence present; `#N` → systems-index row number convention stated |
| 6 | Nice-to-Have — D.4 engine-bootloader scope | ✅ D.4 "Engine bootloader gap (scope boundary)" paragraph present |
| 7 | Nice-to-Have — A.4 protocol guardrail | ✅ A.4 guardrail sentence + `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` cross-ref present |

### Findings (this re-review)

| Severity | Count | Items |
|---|---|---|
| **BLOCKING** | 1 | Registry path drift: `docs/registry/entities.yaml` cited but file does NOT exist; canonical is `design/registry/entities.yaml` |
| **RECOMMENDED** | 2 | H.0 AC tally drift (preamble said 25 / 23 BLOCKING vs H.5 enumerates 27 / 25 BLOCKING) · PANIC recovery undefined (C.3.3 handlers would overwrite `_boundary_state == PANIC` set in E.1) |
| **Nice-to-Have** | 1 | C.2.1 vs D.1 notation drift — POST-LOAD column used `< M` while D.1 uses `K` |

#### BLOCKING — fixed inline

1. **Registry path drift**: `docs/registry/entities.yaml` cited 3 times (C.3.5, F.4.1 summary, Z.A.2) but `find` shows the file exists only at `design/registry/entities.yaml` (populated Session 17 per time-rewind.md line 7 + gdd-cross-review-2026-05-11.md I8). Phase 5d batch as written would write to a non-existent path.
   - **Fix**: `replace_all` `docs/registry/entities.yaml` → `design/registry/entities.yaml` (3 sites). Post-fix grep at HEAD: 0 stale matches, 3 canonical matches. Phase 5d batch path unblocked.

#### RECOMMENDED — fixed inline

2. **H.0 AC tally drift**: Preamble said 12 Logic + 11 Integration = 23 BLOCKING + 2 Manual = 25 total. H.5 actually enumerates 27 ACs (14 Logic BLOCKING + 11 Integration BLOCKING + 2 ADVISORY). With AC-H26 added for fix #3, final count is 28 ACs / 26 BLOCKING.
   - **Fix**: H.0 preamble updated — Total ACs: 28; Logic: 15; Integration: 11 BLOCKING; BLOCKING total: 26; Manual ADVISORY: 2 (AC-H2b, AC-H23). Added enumeration line listing each AC ID per classification for future grep verification.

3. **PANIC recovery undefined**: E.1 sets `_boundary_state = BoundaryState.PANIC` + holds `_phase = IDLE`. But C.3.3 handlers `_on_boss_killed` and `_on_state_changed` unconditionally overwrite `_boundary_state` to CLEAR_PENDING / RESTART_PENDING and call `_trigger_transition()` — no PANIC short-circuit guard. PANIC could be lost on next signal arrival.
   - **Fix (Option b chosen — terminal-PANIC documentation)**: E.1 now explicitly states PANIC is terminal in Tier 1 (no recovery); subsequent `boss_killed` / `state_changed(_, &"dead")` signals must early-return via `if _boundary_state == BoundaryState.PANIC: return` guard in C.3.3 handlers; lifecycle stays IDLE-locked. Tier 2 panic-recovery policy (e.g., stage 1 fallback) explicitly deferred. New **AC-H26** added (Logic — BLOCKING) under H.4 — `test_panic_state_is_terminal_no_further_transition` GUT unit test with `_trigger_transition` spy + 3 signal-ordering scenarios. H.5 Rule 4, D.5, and E.1 coverage rows updated to include AC-H26.

#### Nice-to-Have — fixed inline

4. **C.2.1 vs D.1 notation drift**: C.2.1 phase table cell said `POST-LOAD | < M 틱` while D.1 used `K` symbol. D.1 footnote acknowledged `K < M` as design guidance but readers had to cross-reference to translate.
   - **Fix**: C.2.1 POST-LOAD cell now reads `` `K` 틱 (design guidance: `K < M`; D.1 binding constraint는 sum) ``; budget formula block under the table updated from `POST-LOAD(< M ticks)` to `POST-LOAD(K ticks)` with one-line gloss `where K < M is design guidance; D.1 binding constraint is the sum.`

### Verification

- BLOCKING-1: `grep -nc "docs/registry/entities" design/gdd/scene-manager.md` → 0 (was 3); `grep -c "design/registry/entities.yaml"` → 3 (canonical).
- REC-1: H.0 preamble post-edit shows Total ACs: 28 / Logic 15 / Integration 11 / BLOCKING 26 / ADVISORY 2. Reconciles with H.5 enumeration (27 prior + 1 new AC-H26 = 28).
- REC-2: AC-H26 present at line 1148 (H.4 group placement before H.5); E.1 terminality paragraph at line 602; H.5 Rule 4 / D.5 / E.1 rows updated.
- NH-1: C.2.1 table cell line 173 + budget formula line 180 both use `K` symbol with `K < M` glossing.
- Line count delta: 1350 → 1365 (+15 lines; all from inline additions — no section-skeleton changes).
- AC count delta: 25 enumerated → 28 enumerated (+ AC-H26; H.0 preamble reconciled).

### Outcome

- **Verdict at start**: NEEDS REVISION (1 BLOCKING + 2 RECOMMENDED + 1 Nice-to-Have)
- **Verdict at end of session**: All 4 items fixed inline. **Status remains "Designed (pending re-review)"** in systems-index Row #2 — per inline-fix-then-reverify preference, user chose to perform fresh-session `/clear` + independent `/design-review` re-review before promoting to Approved.
- **Prior verdict resolved**: Yes — same-day prior NEEDS REVISION (7 items, all fixed inline) verified intact at HEAD; this re-review surfaced 4 additional items that were missed in the prior pass (registry path drift, AC tally, panic terminality, notation alignment).
- **Next**: Fresh `/clear` session + `/design-review design/gdd/scene-manager.md --depth lean` for independent verdict. Only after PASS, promote to **Approved** and apply Phase 5d batch + housekeeping batch.

---

## Review — 2026-05-11 (third pass, same day) — Verdict: NEEDS REVISION (resolved inline this session)

**Mode**: `/design-review design/gdd/scene-manager.md --depth lean` (re-review #3 — independent fresh-session verification of prior NEEDS REVISION #2 closures)
**Scope signal**: L (unchanged — multi-system integration; 5 cross-doc reciprocals + Phase 5d batch + housekeeping batch queued)
**Specialists**: None (lean mode — single-session analysis)
**Re-review of prior verdict**: Yes — re-review #2 same day was NEEDS REVISION with 4 inline fixes reported applied.

### Prior closure verification (4 items from re-review #2 + 7 items from re-review #1)

All 11 cumulative prior items verified at HEAD:

| # | Prior item (source) | HEAD evidence |
|---|---|---|
| RR2-1 | BLOCKING — Registry path drift `design/registry/entities.yaml` (3 sites) | ✅ C.3.5 line 326 + F.4.1 summary line 685 + Z.A.2 line 1322 all canonical; `docs/registry/entities` 0 matches |
| RR2-2 | RECOMMENDED — H.0 AC tally drift | ✅ Total 28 / Logic 15 / Integration 11 BLOCKING / ADVISORY 2; enumeration line lists each AC ID per classification |
| RR2-3 | RECOMMENDED — PANIC recovery undefined | ✅ E.1 terminality clause (line 602) + AC-H26 (line 1148) + H.5 Rule 4 / D.5 / E.1 coverage rows updated |
| RR2-4 | Nice-to-Have — C.2.1 `< M` vs D.1 `K` notation | ✅ C.2.1 phase table + budget formula both use `K` with `K < M` glossing |
| RR1-1..7 | All 7 items from re-review #1 (PANIC enum, boss_defeated count 17, AC-H1/H23 test scope, C.3.3 priority-ladder rephrase, F.1 breadcrumb, D.4 bootloader paragraph, A.4 guardrail) | ✅ Verified intact at HEAD per re-review #2 closure verification table; no regressions |

### Findings (this re-review #3)

| Severity | Count | Items |
|---|---|---|
| **BLOCKING** | 1 | `debug_simulate_load_failure` flag has two contradictory definitions between G.3 (panic) and AC-H17 (budget overrun) — AC-H17 cannot pass under G.3 behavior |
| **RECOMMENDED** | 4 | C.3.3 GDScript pattern missing PANIC + `_phase != IDLE` guards required by AC-H19/H20/H26 · AC-H14 doesn't assert `_boundary_state == BoundaryState.PANIC` (PANIC entry coverage gap) · G.4 narrative includes engine boot in 300s budget contradicting D.4 scope · AC-H5 sub-check #2 grep `scene_will_change` in PM is too broad (false-positive on comments) |
| **Nice-to-Have** | 1 | F.3 stale line-number refs (`line 766`, `line 832`) — line numbers drift on file edits |

#### BLOCKING — fixed inline

1. **`debug_simulate_load_failure` flag has two contradictory definitions** — G.3 (line 732) defines it as "panic state 진입 (E.1/E.8 시나리오 수동 테스트)"; AC-H17 (line 1043) uses it as "(forces M+K+1 > 60)" requiring READY phase eventually reached. Same flag, two contradictory behaviors. A programmer implementing per G.3 fails AC-H17 (panic blocks lifecycle, READY never reached); implementing per AC-H17 fails G.3's stated purpose.
   - **Fix (Option A — chosen by user)**: Added new G.3 row `debug_simulate_budget_overrun` with deterministic mock-shim latency-injection semantics; kept `debug_simulate_load_failure` for panic. Retargeted AC-H17 Given + Test mechanism to new flag with cross-reference: "(distinct from `debug_simulate_load_failure` which forces panic)". Both flags now mutually exclusive with clear separate purposes.

#### RECOMMENDED — fixed inline

2. **C.3.3 GDScript pattern missing PANIC + `_phase != IDLE` guards required by AC-H19/H20/H26** — The pattern at lines 285–298 shows only the `_boundary_state == CLEAR_PENDING` same-tick early-return. It is missing PANIC guard (E.1 terminality + AC-H26) and `_phase != IDLE` guard (E.4/E.5 + AC-H19/H20). A programmer copying the pattern verbatim would fail 3 BLOCKING ACs.
   - **Fix (Option A — chosen by user, one-line gloss)**: Added `> Pattern scope note` block after the GDScript snippet specifying both required guards with precedence order: "panic > phase ≠ idle > 동일-틱 우선순위". Snippet remains focused on same-tick CLEAR vs RESTART logic; production handlers add both required guards at function top.

3. **AC-H14 doesn't assert `_boundary_state == BoundaryState.PANIC`** — The PANIC enum 5th value (BLOCKING fix from re-review #1) lacked entry-state assertion. AC-H14 only checked `push_error` + `_phase remains IDLE` + `no emit`. AC-H26 verifies terminality *after* panic entry but no AC verifies entry itself.
   - **Fix**: Added 4th post-condition to AC-H14 Then clause: `_boundary_state == BoundaryState.PANIC` (D.5 5th enum value — distinguishes panic entry from any other IDLE state). Test mechanism updated to assert all four post-conditions + cross-ref AC-H26 (entry vs terminality pairing). H.5 AC-H14 row + D.5 formula row updated to include AC-H14 (PANIC entry).

4. **G.4 narrative includes engine boot in 300s budget contradicting D.4 scope** — G.4 (line 737) said "엔진 부트 시간 + intro 8 s + input ~0 s = ~11 s". But D.4 "Engine bootloader gap (scope boundary)" (line 482) explicitly excludes engine boot from `cold_boot_elapsed_s` (capture starts at `SceneManager._ready()`, not OS process launch).
   - **Fix**: Rewrote G.4 bullet to exclude engine bootloader per D.4 scope; revised estimate to `intro 8 s + 첫 stage 로드 < 1 s + input ~0 s ≈ 9 s ≪ 300 s ceiling` (engine boot external, separately OS-measured); cross-link D.4 advisory for Steam Deck 1세대 AC-H2b near-ceiling escalation.

5. **AC-H5 sub-check #2 grep too broad** — `grep -nE 'scene_will_change' src/gameplay/player_movement.gd → 0 matches` false-fails on any comment or docstring mentioning the signal name. Rule 5 bans subscription, not mention.
   - **Fix**: Tightened pattern to `(\.connect\s*\(\s*&?"?scene_will_change|scene_will_change\.connect)` targeting `.connect(...)` subscription syntax specifically; added comment-strip pipeline note `sed -E 's|#.*$||'` per `pm_static_check.sh` precedent. Bare-string mentions in docstrings/comments no longer trip the gate.

#### Nice-to-Have — fixed inline

6. **F.3 stale line-number refs** — `line 766` (input.md) and `line 832` (damage.md) drift on every edit to those files.
   - **Fix**: Replaced with section refs — damage.md: `F.4 row (boss_killed → #2 Scene Manager)`; input.md: `C.5 (cold-boot router; F.4.1 #4 cross-doc row)`. Resilient to line drift in source GDDs.

### Verification

- All 6 edits grep-verified at HEAD post-fix.
- BLOCKING-1: `grep -c "debug_simulate_budget_overrun"` → 3 (G.3 row + AC-H17 Given + AC-H17 Test mechanism); `grep -c "debug_simulate_load_failure"` → 2 (G.3 row + AC-H17 cross-ref note); both flags now distinct.
- REC-2: `Pattern scope note` block present at line 300; mentions both guards by name with precedence order.
- REC-3: AC-H14 Then clause line 1008 includes `_boundary_state == BoundaryState.PANIC (D.5 5th enum value...)`; H.5 D.5 formula row line 1227 now lists AC-H11, AC-H14, AC-H26.
- REC-4: G.4 cold-boot bullet at line 740 explicitly excludes engine bootloader; estimate revised to ~9 s within scope.
- REC-5: AC-H5 sub-check #2 grep at line 894 targets `.connect(...)` subscription syntax + comment-strip pipeline note.
- NH-6: `grep -nE "line 832|line 766"` → 0 matches in F.3; section refs replace prior line citations.
- AC count unchanged at 28 enumerated; H.0 preamble math unchanged (15 Logic + 11 Integration BLOCKING + 2 ADVISORY = 28).
- Line count delta: 1365 → 1368 (+3 lines; all from inline additions — no section-skeleton changes).
- Cross-doc reciprocals + Phase 5d batch + `boss_defeated → boss_killed` housekeeping batch still queued; this re-review did not modify their scope.

### Outcome

- **Verdict at start**: NEEDS REVISION (1 BLOCKING + 4 RECOMMENDED + 1 Nice-to-Have)
- **Verdict at end of session**: All 6 items fixed inline. **Status remains "Designed (pending re-review)"** in systems-index Row #2 — per inline-fix-then-reverify preference, user chose to perform a 4th fresh-session `/clear` + independent `/design-review` re-review before promoting to Approved (BLOCKING fix introduced new debug flag + AC change; independent eye warranted).
- **Prior verdict resolved**: Yes — re-review #2's 4 items + re-review #1's 7 items (11 cumulative) all verified intact at HEAD; this re-review surfaced 6 additional items that were missed in the prior two passes (debug flag contradiction was a latent spec defect; C.3.3 pattern gap predates re-review #1; AC-H14 PANIC entry coverage gap introduced by re-review #2's PANIC enum addition; G.4 vs D.4 scope tension surfaced from re-review #1's D.4 bootloader paragraph addition; AC-H5 grep too broad; F.3 line refs).
- **Next**: Fresh `/clear` session + `/design-review design/gdd/scene-manager.md --depth lean` for re-review #4 independent verdict. Only after PASS, promote to **Approved** and apply Phase 5d batch + housekeeping batch.

---

## Review — 2026-05-11 (fourth pass, same day) — Verdict: NEEDS REVISION (resolved inline this session)

**Mode**: `/design-review design/gdd/scene-manager.md --depth lean` (re-review #4 — independent fresh-session verification of prior NEEDS REVISION #3 closures)
**Scope signal**: L (unchanged — multi-system integration; 5 cross-doc reciprocals + Phase 5d batch + housekeeping batch queued)
**Specialists**: None (lean mode — single-session analysis)
**Re-review of prior verdict**: Yes — re-review #3 same day was NEEDS REVISION with 6 inline fixes reported applied.

### Prior closure verification (17 cumulative items from R1+R2+R3)

All 17 cumulative prior items verified intact at HEAD via re-review #3's verification table + spot-checks this session:

| # | Prior item (source) | HEAD evidence |
|---|---|---|
| RR3-1..6 | All 6 items from re-review #3 (debug_simulate_load_failure split, C.3.3 PANIC + phase guards, AC-H14 PANIC entry, G.4 vs D.4, AC-H5 grep tightening, F.3 line refs) | ✅ Verified — `debug_simulate_budget_overrun` flag separate in G.3; `Pattern scope note` block present after C.3.3 GDScript pattern; AC-H14 asserts `_boundary_state == BoundaryState.PANIC`; G.4 cold-boot bullet excludes engine bootloader; AC-H5 sub-check #2 grep targets `.connect(...)` syntax; F.3 uses section refs |
| RR2-1..4 | All 4 items from re-review #2 (registry path drift, AC tally, PANIC recovery, K notation) | ✅ Verified via re-review #3 table |
| RR1-1..7 | All 7 items from re-review #1 (PANIC enum, boss_defeated count 17, AC-H1/H23 test scope, C.3.3 priority-ladder rephrase, F.1 breadcrumb, D.4 bootloader, A.4 guardrail) | ✅ Verified via re-review #3 table |

No regressions from prior 17 fixes.

### Findings (this re-review #4)

| Severity | Count | Items |
|---|---|---|
| **BLOCKING** | 2 | TransitionIntent enum API contradiction + missing declaration · `src/autoload/scene_manager.gd` path likely wrong (PM B2 / Input B7 trap recurrence) |
| **RECOMMENDED** | 3 | `tree_changed` POST-LOAD entry trigger lacks filter mechanism · No AC validates `change_scene_to_packed` call cardinality · PM F.4.2 reciprocal annotation drift carries into HEAD |
| **Nice-to-Have** | 1 | AC-H1 / AC-H17 mock-shim harness reuse cross-reference |

#### BLOCKING — fixed inline

1. **TransitionIntent enum API contradiction + missing declaration** — Rule 14 (line 136) + AC-H12 (line 983) + AC-H13 (line 995) used `change_scene_to_packed(packed, is_checkpoint_restart: bool)` API; C.2.3 (line 211) + C.3.3 GDScript pattern (lines 287, 297) used `_trigger_transition(packed, intent: TransitionIntent)` with `TransitionIntent.STAGE_CLEAR / CHECKPOINT_RESTART`. The `TransitionIntent` enum was **never declared** — only `enum Phase` appeared at line 207. Two-API ambiguity: programmer cannot determine bool vs enum, full enum value set, or whether Rule 14's no-op guard applies to internal `_trigger_transition` calls.
   - **Fix (Option A — Enum only, chosen by user)**: Added `enum TransitionIntent { COLD_BOOT, CHECKPOINT_RESTART, STAGE_CLEAR }` declaration in C.2.3 (after `enum Phase`); added **"API 단일 출처 정책"** paragraph specifying enum-only external + internal API + Rule 14 guard scope (`SceneManager.change_scene_to_packed` external entry point, not `_trigger_transition` internal); rewrote Rule 14 to use `intent: TransitionIntent` with `CHECKPOINT_RESTART` pass-through; rewrote C.3.2 same-PackedScene reload semantics to use enum; rewrote AC-H12 (uses `STAGE_CLEAR` non-restart variant + COLD_BOOT cross-check) + AC-H13 (uses `CHECKPOINT_RESTART`). Post-fix grep at HEAD: `is_checkpoint_restart` = 0 matches; `TransitionIntent` = 5+ matches across C.2.3/Rule 14/C.3.2/C.3.3/AC-H12/AC-H13.

2. **`src/autoload/scene_manager.gd` path likely wrong — PM B2 / Input B7 trap recurrence** — AC-H4/H5/H6/H7/H24 (5 BLOCKING grep ACs) all cited `src/autoload/scene_manager.gd`. Verified against project: `find src -type d` shows `src/{ui,tools,core,networking,ai,gameplay}` only — **no `src/autoload/` subdirectory exists**. `.claude/docs/directory-structure.md` enumerates `src/` subdirs as `core/gameplay/ai/networking/ui/tools`. Sibling conventions: input.md uses `src/input/` (Input B7), state-machine.md uses `src/core/state_machine/`. If canonical path differs, all 5 grep gates silently pass against a non-existent file — exact PM B2 / Input B7 trap.
   - **Fix (Option A — `src/core/scene_manager/`, chosen by user)**: `replace_all src/autoload/scene_manager.gd → src/core/scene_manager/scene_manager.gd` (11 sites — 5 ACs × multiple sub-checks within each). Post-fix grep at HEAD: `src/autoload` = 0 matches; `src/core/scene_manager` = 11 matches. Matches state-machine.md `src/core/state_machine/` Foundation precedent.

#### RECOMMENDED — fixed inline

3. **`tree_changed` signal as POST-LOAD entry trigger lacks filter mechanism** — C.2.1 POST-LOAD row 173 + C.3.2 T+M+K row 252 + A.3 reference relied on SM `tree_changed` to detect "new scene `_ready()` chain complete → POST-LOAD entry". Godot 4.6 `SceneTree.tree_changed` fires on every child add/move/rename — many times during a single scene swap. GDD did not specify filter logic. Risk: naive `tree_changed.connect()` triggers `_register_checkpoint_anchor()` mid-swap → race with `_ready()` chain.
   - **Fix (Option A — `process_frame.connect(..., CONNECT_ONE_SHOT)`, chosen by user)**: Switched POST-LOAD entry trigger to `get_tree().process_frame.connect(_on_post_load, CONNECT_ONE_SHOT)` — signal-based one-shot pattern (NOT coroutine — preserves Rule 9 비협상 "코루틴 금지"). Initial attempt with `await get_tree().process_frame` was reverted after realising `await` is a coroutine yield that violates Rule 9. Updated C.2.1 POST-LOAD row, C.3.2 T+M+K row, A.3 Godot 4.6 SceneTree API reference (3 sites). Post-fix grep at HEAD: `tree_changed` = 0 matches; `process_frame` = 3 matches.

4. **No AC validates `change_scene_to_packed` call cardinality is exactly 1 per transition** — D.6 covered `scene_will_change` emit cardinality (AC-H8) but the symmetric "exactly one `SceneTree.change_scene_to_packed` call per transition" was untested. Combined with finding #1 (multiple API entry points), an internal bug could trigger a double scene swap.
   - **Fix**: Added new **AC-H27** (Logic — BLOCKING) `test_change_scene_to_packed_cardinality_one_per_transition` covering Rule 4 + D.6 swap-call face. Tests all 3 entry paths (DEAD signal, boss_killed, cold-boot first input) with mock SceneTree counter. Updated H.0 preamble (Total ACs 28→29; Logic 15→16; BLOCKING 26→27; enumeration line adds AC-H27); H.5 AC-H27 row inserted; H.5 Rule 4 + D.6 coverage rows updated to cite AC-H27 (swap-call cardinality symmetric to emit cardinality).

5. **PM F.4.2 reciprocal annotation drift carries into HEAD** — Per C.3.5 Phase 5d obligation, `player-movement.md` F.1 row #2 should drop `*(provisional)*` annotations. Verified at HEAD: PM F.1 row line 978 still `*(provisional re #2 Not Started)*`; PM F.4.2 row line 531 still `*(provisional)*` + `TBD` wiring. GDD acknowledged the obligation in C.3.5 but the gate semantics weren't explicit — promotion could slip past stale reciprocals.
   - **Fix**: Added **"⚠️ Approved promotion gate (BLOCKING)"** note at the end of F.4.1 explicitly making Phase 5d batch a BLOCKING gate for Designed → Approved promotion. Note cites HEAD evidence of stale PM reciprocals and notes that the 17-site `boss_defeated → boss_killed` housekeeping batch is NOT part of the BLOCKING gate (damage.md single-source authority covers it).

#### Nice-to-Have — fixed inline

6. **AC-H1 / AC-H17 mock-shim harness reuse opportunity** — Both ACs construct deterministic mock `change_scene_to_packed` shims (AC-H1: M-tick normal; AC-H17: M+K+1 > 60 via `debug_simulate_budget_overrun`). One-line cross-ref aids implementer.
   - **Fix**: Appended **"Harness reuse note"** to AC-H17 Test mechanism specifying that AC-H1 and AC-H17 share the same mock infrastructure parameterized by `latency_ticks: int` (AC-H1 default = M; AC-H17 = M+K+2 to force overrun).

### Verification

- F1: `grep -c is_checkpoint_restart` → 0 (was 5); `grep enum TransitionIntent` → line 208 declared; `grep TransitionIntent.STAGE_CLEAR\|.CHECKPOINT_RESTART\|.COLD_BOOT` → 8 matches across C.2.3/Rule 14/C.3.2/C.3.3/AC-H12/AC-H13.
- F2: `grep -c src/autoload` → 0 (was 11 across 5 ACs); `grep -c src/core/scene_manager` → 11.
- F3: `grep -c tree_changed` → 0 (was 3); `grep -c process_frame` → 3.
- F4: AC-H27 present (5 references — H.0 enum line, AC body, H.5 row, Rule 4 row, D.6 row); AC enumerated count = 29 (was 28); H.0 math reconciles (16 Logic + 11 Integration BLOCKING + 2 ADVISORY = 29).
- F5: "Approved promotion gate" note present at F.4.1 end.
- F6: "Harness reuse note" present in AC-H17 Test mechanism.
- Line count delta: 1368 → 1386 (+18 lines; all from inline additions — no section-skeleton changes).

### Outcome

- **Verdict at start**: NEEDS REVISION (2 BLOCKING + 3 RECOMMENDED + 1 Nice-to-Have)
- **Verdict at end of session**: All 6 items fixed inline. **Status remains "Designed (pending re-review)"** in systems-index Row #2 — per inline-fix-then-reverify preference, user chose to perform fresh-session `/clear` + independent `/design-review` re-review #5 before promoting to Approved (BLOCKING #1 introduced new enum + API single-source policy; BLOCKING #2 changed canonical source-file path affecting 5 BLOCKING grep ACs; independent eye warranted).
- **Prior verdict resolved**: Yes — re-review #3's 6 items + re-review #2's 4 items + re-review #1's 7 items (17 cumulative) all verified intact at HEAD; this re-review surfaced 6 additional items the prior three passes missed (TransitionIntent contradiction was a latent spec defect spanning Rule 14 + C.2.3 + C.3.3 + AC-H12/H13 — surfaced only by reading the four sections together; path drift surfaced by `find src -type d` validation prior reviews did not run; `tree_changed` signal-semantics issue required Godot 4.6 API knowledge that lean review caught on adversarial pass).
- **Next**: Fresh `/clear` session + `/design-review design/gdd/scene-manager.md --depth lean` for re-review #5 independent verdict. Only after PASS, promote to **Approved** and apply Phase 5d batch + housekeeping batch.

---

## Review — 2026-05-11 (fifth pass, same day) — Verdict: NEEDS REVISION (resolved inline this session)

**Mode**: `/design-review design/gdd/scene-manager.md --depth lean` (re-review #5 — independent fresh-session verification of prior NEEDS REVISION #4 closures)
**Scope signal**: L (unchanged — multi-system integration; 5 cross-doc reciprocals + Phase 5d batch + housekeeping batch queued)
**Specialists**: None (lean mode — single-session analysis)
**Re-review of prior verdict**: Yes — re-review #4 same day was NEEDS REVISION with 6 inline fixes reported applied (TransitionIntent enum + API single-source policy, `src/core/scene_manager/` path, `process_frame` one-shot pattern, AC-H27 + H.0 reconciliation, Approved promotion gate, AC-H1/H17 harness reuse note).

### Prior closure verification (23 cumulative items from R1+R2+R3+R4)

All 23 cumulative prior items verified intact at HEAD via targeted grep evidence:

| # | Prior item (source) | HEAD evidence |
|---|---|---|
| RR4-1 | BLOCKING — TransitionIntent enum + API single-source | ✅ Line 208 `enum TransitionIntent { COLD_BOOT, CHECKPOINT_RESTART, STAGE_CLEAR }`; `is_checkpoint_restart` 0 matches; `TransitionIntent` 10 matches across C.2.3/Rule 14/C.3.2/C.3.3/AC-H12/AC-H13 |
| RR4-2 | BLOCKING — `src/core/scene_manager/` path | ✅ `src/autoload` 0 matches; `src/core/scene_manager` 11 matches |
| RR4-3 | RECOMMENDED — `process_frame` one-shot pattern | ✅ `tree_changed` 0 matches; `process_frame` 3 matches at C.2.1/C.3.2/A.3 |
| RR4-4 | RECOMMENDED — AC-H27 + H.0 reconciliation | ✅ AC-H27 at line 1168; H.0 Total ACs=29 |
| RR4-5 | RECOMMENDED — Approved promotion gate | ✅ Line 695 "⚠️ Approved promotion gate (BLOCKING)" present |
| RR4-6 | Nice-to-Have — AC-H1/AC-H17 harness reuse note | ✅ Line 1055 present |
| RR3-1..6 | All 6 items (debug flag split, C.3.3 pattern scope note, AC-H14 PANIC entry, G.4 bootloader, AC-H5 grep tightening, F.3 section refs) | ✅ All intact (debug_simulate_budget_overrun separate flag in G.3; Pattern scope note at line 303; AC-H14 4th post-condition; G.4 excludes engine bootloader; AC-H5 `.connect(...)` pattern; F.3 section refs) |
| RR2-1..4 | All 4 items (registry path drift, H.0 AC tally, PANIC recovery, K notation) | ✅ All intact (3 sites `design/registry/entities.yaml`; H.0 reconciled; AC-H26 + E.1 terminality; K notation with `K < M` gloss) |
| RR1-1..7 | All 7 items (PANIC enum, boss_defeated count 17, AC-H1/H23 test scope, C.3.3 priority rephrase, F.1 breadcrumb, D.4 bootloader, A.4 guardrail) | ✅ All intact; `boss_defeated` HEAD count: TR=13 + SM=4 = 17 still queued for housekeeping batch (not BLOCKING per RR4-5) |

No regressions across 23 prior fixes.

### Findings (this re-review #5)

| Severity | Count | Items |
|---|---|---|
| **BLOCKING** | 2 | `enum BoundaryState` declaration missing in C.2.3 (latent spec defect — same pattern as RR4-1 TransitionIntent gap) · F.1 omits #1 Input System as downstream dependent (dependency graph hole) |
| **RECOMMENDED** | 2 | C.2.3 `_boundary_state` / `_respawn_position` / `_current_scene_packed` / `_stage_1_packed` / `_victory_screen_packed` member declarations missing · D.3 N=0 "panic state" wording contradicts E.2 / AC-H10 fallback semantics |
| **Nice-to-Have** | 2 | C.3.5/F.4.1 damage.md "*(미작성)*" obligation stale at HEAD (annotation already absent) · A.4/A.6 historical "25 ACs" count outdated (current = 29 post-RR2/RR3/RR4 additions) |

#### BLOCKING — fixed inline

1. **`enum BoundaryState` declaration missing in C.2.3** — C.2.3 declared `enum Phase` and `enum TransitionIntent` (RR4-1) but `enum BoundaryState` was never declared, despite `BoundaryState.{BOOT_INTRO, ACTIVE, RESTART_PENDING, CLEAR_PENDING, PANIC}` being referenced 11+ times across the GDD (D.5 line 522, C.3.3 GDScript pattern lines 289–300, E.1 line 606, AC-H14 line 1013, AC-H26 line 1162, Pattern scope note line 303). Same latent-spec-defect pattern as RR4-1 TransitionIntent gap — a programmer copying C.2.3's enum block would write only `enum Phase` + `enum TransitionIntent`, then fail on `BoundaryState.CLEAR_PENDING` references throughout C.3.3 and AC tests.
   - **Fix**: Added `enum BoundaryState { BOOT_INTRO, ACTIVE, RESTART_PENDING, CLEAR_PENDING, PANIC }` declaration in C.2.3 immediately after `enum TransitionIntent` (line 209). Inline comment ties back to D.5 5-value enum range. Post-fix grep at HEAD: `enum BoundaryState` 1 match; `BoundaryState.` 15 usages now resolve.

2. **F.1 omits #1 Input System as downstream dependent** — F.1 enumerated 11 downstream dependents (#3, #4, #5, #6, #8, #9, #12, #13, #15, #17, #18) but did not include #1 Input System even though E.6 line 619 + E.7 line 623 explicitly state input.md C.5 router calls `SM.change_scene_to_packed(stage_1_packed)` on cold-boot first input. F.3 line 677 already had reciprocal row for input.md with status ✅ Present — but F.3 is titled "Bidirectional Verification — F.1 reciprocals already in Approved GDDs", which presupposes F.1 source row exists. Structural inconsistency + dependency graph hole.
   - **Fix**: Added F.1 row for `#1 Input System | Approved | input.md C.5 router calls SM.change_scene_to_packed(stage_1_packed, TransitionIntent.COLD_BOOT) on first cold-boot input (E.6 / E.7) | Hard | Cold-boot trigger source (Pillar 4 5분 룰 critical path)...` (inserted before #3 Camera). Hard classification rationale: cold-boot path is broken without input.md C.5 router (Pillar 4 비협상).

#### RECOMMENDED — fixed inline

3. **C.2.3 member variable declarations missing** — C.2.3 declared `var _phase: Phase = Phase.IDLE` but did not declare `_boundary_state`, `_respawn_position`, `_current_scene_packed`, `_stage_1_packed`, `_victory_screen_packed` despite their use throughout C.3.3 pattern, D.3, D.5, AC-H3b, AC-H10, and Rule 14 same-PackedScene guard logic.
   - **Fix**: Added 5 member variable declarations at C.2.3 (lines 212–217). Initial values: `_boundary_state = BoundaryState.BOOT_INTRO` (per C.2.2 cold-boot slot); `_respawn_position = Vector2.ZERO`; `_current_scene_packed: PackedScene = null`. `@export var _stage_1_packed` / `@export var _victory_screen_packed` use `@export` per G.2 designer-tunable knob policy. Inline comments cross-reference C.2.2 / D.3 / AC-H3b/H10 / Rule 14.

4. **D.3 N=0 "panic state" wording contradicts E.2 / AC-H10 fallback semantics** — D.3 (named expression line 434, variable result row line 445, Edge note line 460) said "N = 0 → SM panic state". But E.2 line 609 explicitly sets `_respawn_position = current_player_position` (fallback) + `push_error` + debug `assert(false)` — does NOT set `_boundary_state = BoundaryState.PANIC`. AC-H10 line 965 verifies the fallback (`SM._respawn_position == player.global_position`) — not PANIC entry. Only E.1 (null PackedScene) sets PANIC (terminal per RR2-3 fix). D.3 wording was misleading — N=0 is a *fallback* (lifecycle continues), not E.1 PANIC terminality (lifecycle blocked).
   - **Fix**: Rewrote 3 D.3 sites — named expression (line 442) uses `respawn_position = player.global_position (E.2 fallback)  (if N = 0; push_error + assert in debug — NOT BoundaryState.PANIC)`; result row (line 453) changed type from `Vector2 | panic` to `Vector2` with explicit "not BoundaryState.PANIC" note; Edge note (line 468) rewritten to explicitly distinguish from E.1 terminality and cite AC-H10 as the verification gate.

#### Nice-to-Have — fixed inline

5. **C.3.5 / F.4.1 damage.md *(미작성)* obligation stale at HEAD** — C.3.5 line 328 + F.4.1 line 687 listed "damage.md F.4 row `boss_killed` — *(미작성)* annotation 제거" as Phase 5d obligation. HEAD verification: `grep "미작성" design/gdd/damage.md` returns 0 matches near line 832 (the `boss_killed` row). Annotation either was removed at an earlier point or never existed — obligation already complete.
   - **Fix**: Annotated C.3.5 line 336 row with "annotation 이미 부재 (verified at HEAD 2026-05-11 RR5...); **obligation closed (no edit needed)**". Strike-through F.4.1 line 696 with "✅ **Closed at RR5 2026-05-11**: annotation verified absent at HEAD; no edit needed." Phase 5d batch list now accurately reflects HEAD state.

6. **A.4 / A.6 historical "25 ACs" count outdated** — A.4 qa-lead row line 1363 and A.6 Last Updated narrative line 1385 both cited "25 ACs (23 BLOCKING / 2 ADVISORY)" — qa-lead's original Session 19 draft figure. Current HEAD state after RR2/RR3/RR4 additions: 29 ACs / 27 BLOCKING / 2 ADVISORY. Top-to-bottom readers encountering "25 ACs" then H.0's "29 ACs" would experience confusion.
   - **Fix**: Annotated A.4 qa-lead row (line 1372) with "Original Session 19 draft: 25 ACs ... **Post-RR cumulative HEAD state (canonical — see H.0 preamble)**: 29 ACs / 27 BLOCKING / 2 ADVISORY — additions: AC-H26 PANIC terminality (RR2), AC-H14 PANIC entry post-condition (RR3 enhancement, not new AC), AC-H27 swap-call cardinality (RR4)." Same cumulative annotation applied to A.6 Last Updated narrative (line 1394).

### Verification

- B1: `grep -n "enum BoundaryState" design/gdd/scene-manager.md` → line 209 declared; `grep -c "BoundaryState\."` → 15 (was 11; +4 from new declarations and reference cross-checks).
- B2: F.1 row line 659 `| **#1** | Input System | Approved | input.md C.5 router calls...` present.
- R1: 5 new declarations at lines 212–217; `var _boundary_state` / `var _respawn_position` / `var _current_scene_packed` / `@export var _stage_1_packed` / `@export var _victory_screen_packed` all present.
- R2: D.3 sites line 442 / 453 / 468 all use "(E.2 fallback)" or "**not** `BoundaryState.PANIC`" wording; old "panic state" wording for N=0 gone.
- N1: Line 336 (C.3.5) + line 696 (F.4.1) both annotated as obligation closed; cross-verified `grep "미작성" damage.md` → 0 matches.
- N2: Line 1372 (A.4) + line 1394 (A.6) both have "Post-RR cumulative HEAD state: 29 ACs / 27 BLOCKING / 2 ADVISORY" annotation.
- Line count delta: 1386 → 1395 (+9 lines; all from inline additions — no section-skeleton changes).
- AC count unchanged at 29 (H.0 preamble line 802 "Total ACs: 29" intact; H.5 coverage table enumerates 29 rows).

### Outcome

- **Verdict at start**: NEEDS REVISION (2 BLOCKING + 2 RECOMMENDED + 2 Nice-to-Have)
- **Verdict at end of session**: All 6 items fixed inline. **Status remains "Designed (pending re-review)"** in systems-index Row #2 — per inline-fix-then-reverify preference, user chose to perform fresh-session `/clear` + independent `/design-review` re-review #6 before promoting to Approved (BLOCKING fixes are small declarations but match the latent-spec-defect family from RR4-1; independent eye recommended even at diminishing returns).
- **Prior verdict resolved**: Yes — re-review #4's 6 items + re-review #3's 6 items + re-review #2's 4 items + re-review #1's 7 items (23 cumulative) all verified intact at HEAD; this re-review surfaced 6 additional items prior four passes missed (BoundaryState enum declaration gap = same pattern as RR4-1 TransitionIntent — emerged because RR4 added TransitionIntent but didn't audit for sibling missing enums; F.1 #1 input.md omission surfaced via dependency-graph audit that prior reviews did not run; D.3 N=0 wording surfaced by reading D.3 + E.2 + AC-H10 together for the first time).
- **Cumulative review tally**: 5 passes, 29 items closed total (RR1×7 + RR2×4 + RR3×6 + RR4×6 + RR5×6). Pattern shows diminishing complexity — RR5 BLOCKING items are minimal-edit declarations (1 enum line + 1 F.1 row), suggesting RR6 may converge to PASS.
- **Next**: Fresh `/clear` session + `/design-review design/gdd/scene-manager.md --depth lean` for re-review #6 independent verdict. Only after PASS, promote to **Approved** and apply Phase 5d batch + housekeeping batch (housekeeping NOT in Approved BLOCKING gate per RR4-5 F.4.1 note).
