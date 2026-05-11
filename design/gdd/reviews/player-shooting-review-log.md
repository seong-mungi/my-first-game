# Player Shooting / Weapon System (#7) — Review Log

Revision history for `design/gdd/player-shooting.md`. Each entry records one `/design-review` pass: verdict, scope signal, specialists, blocking/recommended counts, key findings, and whether prior items were resolved.

---

## Review — 2026-05-11 — Verdict: NEEDS REVISION → inline-fixed → pending fresh-session re-verify

Scope signal: M (multi-system Feature layer; 5 Hard deps all Approved/LOCKED; 6 formulas; 12 core rules; 48 ACs after revision; 1 GREP precheck script with 8 patterns; 0 new ADRs — ratifies ADR-0002 Amendment 2 already Proposed; F.4.1 batch = 7 cross-doc edits)

Specialists: None (--depth lean; Phase 3b skipped). Authoring-time multi-specialist consult per GDD author note (game-designer / systems-designer / gameplay-programmer / godot-gdscript-specialist / art-director / audio-director / qa-lead); divergent views surfaced in-doc as Tensions T1 (priority=0 invariant) and T2 (boot signal ordering, RESOLVED this revision).

Blocking items: 1 | Recommended: 4 | Nice-to-Have: 2 (deferred)

Summary: Player Shooting #7 is the most rigorous GDD authored to date — 12 locked core rules with explicit 5-guard ladder, 6 formulas with worked examples, 18 condition→exact-outcome edge cases, and grep-verifiable ACs split BLOCKING (Logic 25 / Integration 8 / Static 9) / ADVISORY (11). Player Fantasy ("두 동사, 한 몸 — uninterrupted motion") is anchored to exactly two mechanic guarantors (PM C.1.3 movement preservation + ADR-0002 Amendment 2 ammo restoration). This GDD also closes 5 cross-doc OQs in a single pass (OQ-PM-NEW, OQ-3, input.md row 7, PM F.4.2 (a)/(b)/(c), ADR-0002 Amendment 2 sub-decisions) — largest cross-doc cascade since damage.md Round 4 LOCK.

The sole material implementability blocker was the `3 | 6 == 36` notation contradiction in PS-H1-08 (a literally-unsatisfiable boolean expression caused by mixing layer-index shorthand with integer-OR semantics). Resolved inline 2026-05-11 by adding a Notation Contract callout in Rule 8 as the single source for the project shorthand (`3 | 6` = Godot 1-indexed inspector layer numbers; runtime integer = `(1<<2) | (1<<5) = 36`); PS-H1-08 now asserts `== 36` with the bit derivation. Rule 9 / F.1 row #8 / G.2 mirror sites read consistently under the new contract.

Prior verdict resolved: First review (no prior log).

### Required Before Implementation (BLOCKING) — Inline-Fixed

1. **PS-H1-08 `3 | 6 == 36` mask notation contradiction** — Resolved. Rule 8 carries a "Notation contract" callout establishing the project shorthand convention. PS-H1-08 assertion replaced with `HitBox.collision_mask == 36` plus the bit derivation `(1 << (3-1)) | (1 << (6-1)) = 4 | 32 = 0b00100100`. Mirror sites (Rule 9, F.1 row #8, G.2) read consistently under the new contract.

### Recommended Revisions — All Inline-Fixed

1. **OQ-PS-2 / Tension T2 boot signal ordering** — Closed. C.2.3 `_ready()` now invokes `weapon_equipped.emit.call_deferred(_active_id)` (PM C.6 `EchoLifecycleSM` precedent). New AC PS-H6-04 (Integration BLOCKING) verifies positive + negative path (negative path replaces `call_deferred` with bare `emit` + places PM subscriber connect AFTER WeaponSlot `_ready()` in tree order → PM never receives the call, regression detector). OQ-PS-2 moved from Z.2 (deferred) to Z.1 (closed); Z.2 strikethrough points to Z.1 closure row.
2. **G.3 invariant 3 silently narrows G.1 safe ranges** — Closed. G.1.5 (`projectile_speed_px_s`) and G.1.6 (`projectile_lifetime_frames`) now carry `*(see G.3 invariant 3)*` flag plus explicit cross-knob caveat with derivation; "co-min invalid" stated literally.
3. **H.5 Tension T2 cross-ref typo "Z.5"** — Closed. Footnote now marked **RESOLVED 2026-05-11**; references Z.1 closure row + PS-H6-04.
4. **PS-H6-04 numbering gap** — Closed. New PS-H6-04 inserted between -03 and -05 (boot wiring AC for `call_deferred` contract). Enumeration line `PS-H6-01..05` now matches body.

### H.0 Count Updates (post-revision)

- Total ACs: 47 → 48 (added PS-H6-04)
- Integration BLOCKING: 7 → 8 (PS-H3-06, PS-H4-03/04/14, PS-H6-01/02/03/04)
- Total BLOCKING: 41 → 42

### Nice-to-Have — Deferred

1. Tier 1 default `projectile_cap = 8` produces 1 silent skip per sustained-fire cycle by design (E-PS-6 + Z.3 item 4 acknowledge); bumping to 9 (still within G.1 safe range 4..16; G.3 invariant 1 met) would eliminate the skip pre-playtest. Deferred to Tier 1 Week 1 playtest tuning per existing GDD plan.
2. D.6 worked-example aside ("DYING window 12프레임 + restore offset 9프레임 = 21프레임 전 ammo가 복원 source 후보") slightly muddled — `restore_idx` is computed against `_lethal_hit_head` (frame of lethal hit signal), not DYING entry. Deferred — clarity-only issue.

### Senior Verdict (creative-director — synthesised in lean mode)

Implementation-ready after the inline notation fix + boot-signal lock. The F.4.1 batch (7 cross-doc edits across input.md row 7 detect mode, TR Rule 9 + AC-A4 step (2) for `_weapon_slot.restore_from_snapshot(snap)`, SM F.2 new row #7, ADR-0002 Amendment 2 Proposed→Accepted, architecture.yaml 3 entries, entities.yaml 5 constants, systems-index Row #7 promotion) remains the BLOCKING Approved-promotion gate per scene-manager.md precedent.

### Next Step

`/clear` → fresh session → `/design-review design/gdd/player-shooting.md --depth lean` (re-verify). Independent re-verdict expected APPROVED if the 5 fixes hold without ripple. Post-Approved, run F.4.1 batch as commit follow-up before architecture-review ratifies ADR-0002 Amendment 2.

---

## Review — 2026-05-11 — Round 2 — Verdict: APPROVED

Scope signal: M (unchanged from Round 1 — multi-system Feature layer; 5 Hard deps all Approved/LOCKED; 6 formulas; 12 core rules; 52 composite ACs; 8 GREP static checks; 0 new ADRs — ratifies ADR-0002 Amendment 2 already Proposed; F.4.1 batch = 7 cross-doc edits remains the Approved-promotion-gate follow-up)

Specialists: None (`--depth lean`; Phase 3b skipped). Independent fresh-session re-verify per Round 1 next-step instruction.

Blocking items: 0 | Recommended: 3 (all applied inline same session) | Nice-to-Have: 1 (Tension T3 implicit reference) + Round 1 carry-forwards (cap=8→9, D.6 worded-example aside) — all deferred

Summary: Round 2 confirms all 5 Round 1 inline fixes hold at HEAD without ripple drift. PS-H1-08 mask notation contract correctly enforces `collision_mask == 36` with bit derivation across Rule 8 / Rule 9 / F.1 row #8 / G.2 mirror sites; C.2.3 `weapon_equipped.emit.call_deferred(_active_id)` lock holds with PS-H6-04 positive/negative path coverage; G.1.5/G.1.6 cross-knob caveats correctly flag co-min invalid; H.5 Tension T2 footnote points to Z.1 closure; PS-H6-04 numbering gap filled. Verdict APPROVED. 3 non-blocking RECOMMENDED housekeeping items surfaced and applied inline same session — none implementability-blocking, all clarity / test-correctness / stale-row corrections.

Prior verdict resolved: Yes — Round 1 (2026-05-11) NEEDS REVISION → inline-fixed (1 BLOCKING + 4 RECOMMENDED) → Round 2 fresh-session APPROVED. All 5 Round 1 items verified intact.

### Recommended Revisions — All Inline-Fixed Same Session

1. **H.0 AC tally arithmetic inconsistency** — Closed. Root cause: PS-H1-07, PS-H1-09, and PS-H2-06 are tagged Integration BLOCKING but live in H.1/H.2 sections — H.0 enumeration line listed them under Logic BLOCKING by section heading, producing 25 Logic / 8 Integration (mis-categorisation). Recount under composite-ID convention (matches Round 1 "47→48 +1 PS-H6-04" framing): **52 composite IDs / 41 BLOCKING / 11 ADVISORY**. New numbers: Logic BLOCKING 21 (was 25), Integration BLOCKING 11 (was 8), Static BLOCKING 9 (unchanged), ADVISORY 11 (unchanged). Added explicit counting-convention callout above the tally clarifying letter-suffixed sub-IDs (PS-H1-03a/b/c, -05a..e, -11a/b) count as one composite AC each, and that categorisation follows the AC body tag, not the section heading.

2. **PS-H1-12 sub-assertion stale post-`call_deferred` lock** — Closed. Round 1 fix introduced `weapon_equipped.emit.call_deferred(_active_id)` in C.2.3, but PS-H1-12 THEN clause still asserted "PM `_on_weapon_equipped` subscriber 호출됨" at `_ready()` exit — unreachable since deferred emit fires on next idle frame, not synchronously inside `_ready()`. Fix: WHEN clause clarified to "next idle frame 도달 *전*"; THEN clause replaces "subscriber 호출됨" with "`weapon_equipped.emit` call_deferred 스케줄 완료" + bold cross-reference to PS-H6-04 as subscriber-callback delivery owner. Anchor extended to "_C.2.3 call_deferred lock_". Test correctness now matches the locked wiring contract.

3. **F.3 row #7 OQ-3 source description stale** — Closed. Original description "silent fallback to id=0; ammo 정책" misrepresented the OQ-3 resolution (Rule 11 step 1 explicitly does NOT fallback to id=0 — it returns early without state mutation and emits `weapon_fallback_activated`). Fix: description column rewritten to enumerate all 3 options the question weighed ("invalid id handling — early return vs fallback-to-0 vs silent signal emit"); Status column annotated "resolution = early return + `weapon_fallback_activated` emit, NOT fallback-to-0". Resolution column unchanged (still points at Rule 11).

### Nice-to-Have — Deferred to Future Housekeeping Pass

1. **Tension T3 lacking explicit definition** — GREP-PS-1 line 1089 references "Tension T3 closure" for `player_snapshot.gd` scope exclusion, but T1 and T2 are documented while T3 is not. Either add a 1-line T3 definition near H.5/H.6 (qa-lead authoring-session tension on `player_snapshot.gd` Resource definition file write-scope exclusion) or rephrase the reference to drop the T3 label.

2. **Round 1 carry-forwards** (still deferred): Tier 1 `projectile_cap` 8→9 tuning to eliminate predictable silent skip pre-playtest; D.6 worked-example aside clarifying `_lethal_hit_head` is lethal-hit frame stamp, not DYING entry. Both remain appropriate deferrals to Tier 1 Week 1 playtest tuning / next-housekeeping-batch.

### H.0 Count Updates (post-revision)

- Total composite ACs: 48 (claimed) → 52 (recount)
- Logic BLOCKING: 25 (claimed) → 21 (recount; -07/-09/-06 reclassified to Integration BLOCKING per body tags)
- Integration BLOCKING: 8 (claimed) → 11 (recount; +PS-H1-07/-09/PS-H2-06)
- Static BLOCKING: 9 → 9 (unchanged)
- ADVISORY: 11 → 11 (unchanged)
- Total BLOCKING: 42 (claimed) → 41 (recount)

### Senior Verdict (creative-director — synthesised in lean mode)

Implementation-ready. Two clean rounds, zero ripple, AC tally now arithmetically self-consistent and test assertions match the locked wiring contracts. This is the most rigorously-specified GDD in the project — 12 locked core rules, 6 formulas with worked examples, 18 condition→exact-outcome edge cases, 7 INV-WS invariants with grep-enforced single-writer assertions, a directory-precheck pattern (GREP-PS-0) closing the PS-B2 trap class, and a TRC orchestration contract (C.2.6) ratifying ADR-0002 Amendment 2 with W2-signature dead-on-arrival rationale. Player Fantasy ("두 동사, 한 몸") anchored to exactly two mechanical guarantors (PM C.1.3 movement preservation + Amendment 2 ammo restoration) — a clean falsifiable fantasy→mechanic chain.

The F.4.1 batch (7 cross-doc edits) remains the BLOCKING Approved-promotion-gate follow-up commit per scene-manager.md precedent — promotion to Approved status reflects the GDD itself is implementation-ready; the batch is the commit gate before architecture-review consumes this GDD to ratify ADR-0002 Amendment 2.

### Next Step

F.4.1 cross-doc batch (7 edits, prepared in commit follow-up):

1. `design/gdd/input.md` C.1.1 row 7 — `*(provisional)*` 제거; detect mode = `is_action_pressed` (hold)
2. `design/gdd/time-rewind.md` C.3 Rule 9 + AC-A4 — Rule 9 step (2) `_weapon_slot.restore_from_snapshot(snap)` 추가; AC-A4 assertion에 `WeaponSlot.ammo_count == snap.ammo_count` 추가
3. `design/gdd/state-machine.md` F.2 — 신규 row #7 Player Shooting (subscribes `state_changed`; transition trigger X)
4. `docs/architecture/adr-0002-time-rewind-storage-format.md` Amendment 2 — Proposed → Accepted; OQ-PM-NEW = (a); Weapon-side capture = WeaponSlot per-tick; restoration = TRC sync method call
5. `docs/registry/architecture.yaml` — 신규 entries (state_ownership.ammo_count, interfaces.weapon_slot_signals, forbidden_patterns.direct_ammo_count_write_outside_weapon_slot)
6. `design/registry/entities.yaml` — 신규 constants (FIRE_COOLDOWN_FRAMES, MAGAZINE_SIZE, PROJECTILE_CAP, PROJECTILE_SPEED_PX_S, PROJECTILE_LIFETIME_FRAMES) ✅ already applied per row #31 note
7. `design/gdd/systems-index.md` Row #7 — Designed (pending re-review) → Approved ✅ applied this review session

Post-batch: `/architecture-review` ratifies ADR-0002 Amendment 2 Proposed → Accepted; then `/prototype time-rewind` Tier 1 Week 1 validation can commence.
