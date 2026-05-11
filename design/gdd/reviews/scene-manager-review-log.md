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
