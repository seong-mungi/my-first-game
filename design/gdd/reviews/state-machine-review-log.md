# State Machine Framework — Design Review Log

> **GDD**: [`../state-machine.md`](../state-machine.md) (System #5, Foundation Core, Echo project)
> **Engine**: Godot 4.6 / GDScript (statically typed)
> **Hosting**: ECHO 4-state lifecycle (single-sourced in `design/gdd/time-rewind.md` Section C)

---

## Review — 2026-05-10 — Verdict: NEEDS REVISION

**Round**: 1 (first formal `/design-review` — Lean review skipped during authoring 2026-05-09)
**Scope signal**: M (medium — text fixes against well-understood standards; no new ADR required)
**Specialists consulted (7)**: game-designer, systems-designer, godot-specialist, godot-gdscript-specialist, ai-programmer, qa-lead, performance-analyst
**Senior synthesis**: creative-director
**Re-review**: First review (no prior verdict)

### Blocking items: 8 | Recommended: 12 | Nice-to-have: 5 | Structural defect (out of scope): 1

### Summary

Framework's *spine* — single-source-of-truth split with Time Rewind GDD #9, minimal `State` + `StateMachine` primitives, 6 hosting obligations (C.2.2) — is correct architecture and well-aligned with Pillar 2 determinism + Pillar 5 solo budget. Defects are concentrated in *contract precision at the boundary*: one cross-doc numeric mismatch with locked owner, two formula tightenings, two Godot-API correctness gaps, two contract clarifications, and one AC-table cluster. None requires re-litigation with Time Rewind. Estimated revision effort 4–8 focused hours; this Round 1 revision was applied inline.

Comparison to Damage GDD (4 rounds, behavioral negotiation) and Time Rewind GDD (1 round, 6 BLOCKING applied): State Machine more closely resembles Time Rewind's pattern — one focused revision pass should clear cleanly.

### Blocking items applied (B1–B8)

| ID | Specialist | Issue | Fix Applied |
|---|---|---|---|
| **B1** | systems-designer F1 | B-range mismatch — SM doc 2–8 vs `time-rewind.md` owner 2–6 (verified by grep at lines 138, 175–176, 340, 483, 496) | D.1 / D.7 / G.2 → 2–6 with explicit "range owner = time-rewind.md" attribution |
| **B2** | game-designer F4 | Easy-mode `pause_swallow_states=[]` override directly violates Time Rewind Rule 18 ("prevent converting 12-frame grace into analysis time") | G.1 row → framework invariant; G.4 + H.7 Tier 3 row → "non-override verification"; OQ-SM-4 closed; F.6 + Tier 3 routing forces Easy mode through `RewindPolicy.dying_window_frames` / `starting_tokens` |
| **B3** | systems-designer F2 | D.2 input-buffer formula admits phantom input when `F_input == -1` and `F_lethal < B` (negative-frame arithmetic + sentinel false-positive) | Formula now reads `(F_input >= 0) ∧ ...` — sentinel guard encoded in expression, not prose; AC-17 extended with sentinel case |
| **B4** | systems-designer F3 | DyingState intra-tick ordering unspecified — last-frame valid input race with `transition_to(DeadState)` + `damage.commit_death()` | D.5 added explicit 4-step ordering rule (poll → predicate → increment → expiry); rationale; new **AC-17a** added to H.4 |
| **B5** | godot-specialist F2 | `get_first_node_in_group()` in `EchoLifecycleSM._ready()` returns null when ECHO subtree precedes TRC subtree → `.connect()` hard-crash | C.3.4 rewritten with `call_deferred("_connect_signals")` + null assertions on Damage / TRC / SceneManager lookups + explicit `CONNECT_DEFAULT` invariant; OQ-SM-6 closed; AC-14 verification rewritten to `Object.get_signal_connection_list()` post-deferred-flush |
| **B6** | godot-gdscript-specialist BLOCKER-1 | `Q_cap` self-contradictory: declared `const` (D.1, D.7) but given "Safe Range 2–8" (G.1); also fails UPPER_SNAKE_CASE convention | Renamed `Q_cap` → `TRANSITION_QUEUE_CAP` (const) at all sites: D.1, D.4, D.7, G.4, Z.5; removed from G.1 knob table; OQ-SM-5 closed |
| **B7** | godot-gdscript-specialist BLOCKER-2 | `EchoLifecycleSM` class hierarchy never declared; AC-23 reuse criterion ("framework code unchanged") unverifiable without explicit boundary | C.2.1 added explicit `class_name EchoLifecycleSM extends StateMachine` + framework-change-prohibition line + `super._ready()` rule + extension surface enumeration |
| **B8** | qa-lead #1, #5, #6, #7, #8 | AC count math wrong (Logic 23/Integration 3 → actual Logic 24/Integration 2); AC-14, AC-22, AC-25 verification methods non-implementable; E-13 had no AC | Header math corrected to Logic 25/Integration 2 = 27 (after additions); AC-14 verification → `Object.get_signal_connection_list()` + flag check; AC-22 (a) demoted to advisory + static-typing precondition; AC-25 → `Time.get_ticks_usec()` + `Performance.add_custom_monitor()` + Steam Deck mandatory; new AC-27 added (E-13 host==null boot rejection) |

### Recommended (deferred to v2 — non-blocking)

12 items captured for v2 pass / Tier 1 prototype validation:

- **R1** [game-designer CRIT-1] Q_cap silent discard violates B.3 anti-fantasy in shipped builds — document player-facing fallback policy when B6 resolved.
- **R2** [game-designer CRIT-2] TR-specific `player_hit_lethal` latch hardcoded in generic `dispatch_signal` D.3 guard 1 — refactor to generic consumed-signal latch registry OR rename framework "Echo Lifecycle Framework."
- **R3** [ai-programmer F2 + creative-director D3] Lock parallel-sibling-SM pattern (PhaseSM × AttackSM) for boss phases. **User deferred to v2.**
- **R4** [ai-programmer F3] Reconcile `compute_ai_velocity(frame_offset)` (ADR-0003) with `State.physics_update(delta)`. Recommend Path B: `EnemyState extends State` with virtual override.
- **R5** [godot-specialist F1, F3] Add explicit `CONNECT_DEFAULT` invariant to C.3.4 + AC-14 (partially applied via B5/B8); expand P3 ban list to include `await create_timer().timeout`, `Tween` (TWEEN_PROCESS_IDLE), `Engine.get_process_frames()`, `await get_tree().process_frame`.
- **R6** [godot-gdscript-specialist + godot-specialist MEDIUM] Type `Dictionary[StringName, Variant]`; emit `&""` not `""`; harden `current_state` via property setter with `push_error` (closes E-12 incorrect "cannot be enforced by static analysis" claim).
- **R7** [ai-programmer F4] Squad coordination (30 drones × 29 subscribers = 870 connections per signal at Tier 1 cap) — flag as Enemy-AI-#10-blocking; suggest SquadCoordinator pattern.
- **R8** [qa-lead #3, #10] Split H.7 gate (partially applied — Tier 1 framework-only vs integration gate added).
- **R9** [qa-lead #8] AC-27 added (already applied as part of B8).
- **R10** [qa-lead #2 + game-designer F3] AC-21 wording (silent-signature, not detection).
- **R11** [godot-gdscript-specialist DEFECT-8/11] `get_first_node_in_group` + `get_node` null assertions (partially applied via B5).
- **R12** [qa-lead #4] AC-24 CI runtime budget — convert OQ-SM-8 to binding constraint.

### Nice-to-have

- **N1** [qa-lead #11] Smoke-check AC.
- **N2** [qa-lead #9] AC for E-15 5-consumer dispatch breadth.
- **N3** [godot-gdscript-specialist DEFECT-10] `_state_history` ring buffer pseudocode in C.1.5.
- **N4** [ai-programmer F8] Tier 2 inter-SM coordination graph audit (defer to Tier 2 gate).
- **N5** [performance-analyst 7a] **OUT OF SCOPE — escalated to technical-director.** Project-level `architecture.yaml.performance_budgets[]` is empty. 60fps/16.6ms target + time-rewind ≤1ms exist as facts in `.claude/docs/technical-preferences.md` but are not registered. Registry's stated purpose (verify allocations sum ≤ 16.6ms via `/architecture-review`) is defeated.

### Specialist Disagreements (resolved)

- **D1**: GDD claims `current_state` is not statically enforceable (E-12). Both godot-specialist + godot-gdscript-specialist disagree — property-setter `push_error` enforcement IS available in Godot 4.6. Resolution: GDD wrong. Adopt setter (R6).
- **D2**: `Q_cap = 4` value backing — systems-designer says not measurement-backed (advisory); gdscript-specialist treats it as const. Not in conflict — adopt B6 (lock as const), value 4 stands for Tier 1.
- **D3**: Boss phase pattern. Creative-director call: lock parallel sibling SMs (mirrors PlayerMovementSM precedent). User deferred R3 to v2.

### Director directive

> "Round 2 blocked except (a) prototype empirical falsification of Locked Decision (B1–B8), (b) cross-doc contradiction with another GDD or ADR. Additional findings go to post-Round-1 observations recorded in this review-log only."

### Files modified in Round 1 revision

- `design/gdd/state-machine.md` — Status header rewrite + 11 inline edits across A/B/C.2.1/C.3.4/D.1/D.2/D.4/D.5/D.7/G.1/G.2/G.4/H header/H.4 (AC-14, AC-17, AC-17a, AC-26, AC-27)/H.5 (AC-22)/H.6 (AC-25)/H.7/H.8/Z.2 (OQ-SM-4, OQ-SM-5)/Z.5
- `design/gdd/systems-index.md` — System #5 row + Last Updated + Progress Tracker (3 reviewed / 1 approved / 2 pending re-review)
- `design/gdd/reviews/state-machine-review-log.md` — this file

### Awaiting

Fresh-session re-review (`/clear` → `/design-review design/gdd/state-machine.md`) to verify the 8 fixes hold cross-document and no new defects introduced. Promotion to Approved (or LOCKED for prototype) gated on re-review pass.

---

## Review — 2026-05-10 (Round 2) — Verdict: APPROVED

**Round**: 2 (re-review of Round 1 NEEDS REVISION → 8 BLOCKING applied)
**Mode**: Lean (single-session per `production/review-mode.txt`; Phase 3b specialist parallel-spawn skipped)
**Scope signal**: S — text-level refinements only; no formula/contract changes
**Re-review**: Yes — Round 1 verdict was NEEDS REVISION on 2026-05-10 (same day, separate session)

### Round 1 BLOCKING items (B1–B8) — verification status

All 8 verified PASS at fix sites. Mechanical traces:

| ID | Fix Site | Status |
|---|---|---|
| **B1** B-range 2–6 | D.1 line 411, D.7 line 587, G.2 line 908 (with `range owner = time-rewind.md` attribution); cross-doc match: time-rewind.md D-glossary line 176 + RewindPolicy line 138 | ✅ |
| **B2** pause_swallow_states framework invariant | G.1 line 900 (override prohibited, Rule 18 cite); G.4 Tier 3 (non-override verification); F.6 forbidden composition; OQ-SM-4 Resolved | ✅ |
| **B3** D.2 sentinel guard | D.2 formula line 428 first clause `(F_input ≥ 0)`; AC-17 sentinel case verifies | ✅ |
| **B4** D.5 intra-tick ordering | D.5 4-step rule + load-bearing rationale; new AC-17a verifies | ✅ |
| **B5** call_deferred + null assert + CONNECT_DEFAULT | C.3.4 (call_deferred + 3 null asserts on Damage/TRC/SceneManager + CONNECT_DEFAULT invariant); OQ-SM-6 Resolved | ✅ |
| **B6** TRANSITION_QUEUE_CAP const | D.1, D.4, D.7 use const; removed from G.1 knob table; OQ-SM-5 Resolved | ✅ |
| **B7** class_name EchoLifecycleSM extends StateMachine | C.2.1 line 192 + framework-change-prohibition line 202 | ✅ |
| **B8** AC verification rewrites + new AC-17a/AC-27 | AC-14, AC-22, AC-25 verification methods updated; AC-27 added; AC count math residual surfaced (see R2-1) | ⚠️ partial → R2-1 |

### Cross-doc consistency check (PASS)

- **`monitorable` (vs the previously-buggy `monitoring`)** — state-machine.md F.1 #8 (`echo_hurtbox.monitorable = false/true`) matches damage.md DEC-4 / C.6.2 / D.1.1 / D.4. Confirmed via `grep -n "monitor"` on damage.md — all 7 sites that were previously wrongly recorded as `monitoring` were corrected to `monitorable` in damage.md Round 2 fix.
- **1-arg `player_hit_lethal(cause: StringName)`** — state-machine.md F.1 / E-14 / AC-22 matches damage.md DEC-1.
- **B-range 2–6** — state-machine.md D.1 / D.7 / G.2 matches time-rewind.md D-glossary + RewindPolicy `@export`.
- **5-signal connect order** — state-machine.md C.3.4 `_connect_signals()` ↔ F.1 upstream table ↔ AC-14 verification — all three sites enumerate Damage / TRC×3 / SceneManager in identical order.
- **DEC-6 hazard grace cross-link** — F.1 #8 row notes `RewindingState.exit()` obligation `damage.start_hazard_grace()` matches damage.md DEC-6 + C.6.4 + E.13 single source.

### Residuals applied inline (Round 2 fixes)

- **R2-1** [B8 residual] AC count math header → **28 = Logic 26 + Integration 2**. Mechanical row count via `grep -c "^| \*\*AC-"` returns 28; H.4 has 9 ACs (AC-14, 15, 16, 17, **17a**, 18, 19, 26, 27), not 8. AC-17a is a separately enumerated row with materially distinct verification (intra-tick ordering vs predicate evaluation), not a sub-clause of AC-17. Header line 945 + Round 1 fixes prose updated; H.7 Tier 1 row line 1011 now reads "AC-01 ~ AC-22 (AC-17a included, separately enumerated row) + AC-24 + AC-26 + AC-27 = **26 Logic ACs**".
- **R2-2** [intra-doc tier inconsistency] `_state_history` ring buffer promoted Tier 2→Tier 1 in C.1.5. Justification: AC-12 + AC-24 are Tier 1 BLOCKING ACs that explicitly depend on `_state_history` (single-entry verification + 32-entry 1000-cycle hash compare); the previous "add after Tier 2 gate" placement created an unimplementable Tier 1 gate. Per-instance overhead (~512 B for 32 StringName entries) is well under solo-budget. Debug overlay label kept Tier 2 (UX-only, not gate-blocking).

### Required Before Implementation

**None.** No new BLOCKING items rise per director directive ("Round 2 blocked except (a) prototype empirical falsification (b) cross-doc contradiction"). Both Round 2 residuals are intra-doc bookkeeping, not contract-level.

### Recommended (carries forward to v2)

The 12 RECOMMENDED items + 5 nice-to-have from Round 1 remain v2-deferred. No new RECOMMENDED items added in Round 2 (lean re-review found no new defects beyond residuals applied inline).

### Senior verdict

Single-session lean re-review — independent reviewer assessment: revision quality of Round 1 fixes is high. All 8 BLOCKING items show explicit traceability (B-tag inline at fix sites + Z.5 resolved-questions log). The two residuals are minor (count math + tier placement) and were resolved with <20-line edit batch. The doc satisfies the director's Round 2 gate. Promote to **Approved**.

### Director directive (carry forward)

> "Round 3 blocked except (a) prototype empirical falsification of Locked Decision (B1–B8 + R2-1, R2-2), (b) cross-doc contradiction with another GDD or ADR. Additional findings go to post-Round-2 observations recorded in this review-log only."

### Files modified in Round 2 revision

- `design/gdd/state-machine.md` — Status header (line 6) → Approved; H header (line 945) → 28 / Logic 26; Round 1 fixes prose (line 947) appended Round 2 fix note; H.7 Tier 1 row (line 1011) → AC-17a explicit + 26 Logic ACs; C.1.5 (line 162–166) → split into Tier 1 (`_state_history` mandatory) + Tier 2 (debug overlay optional)
- `design/gdd/systems-index.md` — System #5 row → Approved (Round 2); Last Updated; Progress Tracker (3 reviewed / 2 approved / 1 pending re-review)
- `design/gdd/reviews/state-machine-review-log.md` — this entry

### Next gate

Tier 1 prototype implementation (`/prototype state-machine` or as part of `/prototype time-rewind` since EchoLifecycleSM is the first client). Empirical falsification of B1–B8 / R2-1 / R2-2 during prototype = only path to Round 3 design-review.

---
