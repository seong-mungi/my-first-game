# Input System — Design Review Log

> Single source of truth for all `/design-review design/gdd/input.md` verdicts. Each entry preserves the prior review's conclusion so re-reviews can verify whether blocking items were addressed.

---

## Review — 2026-05-11 — Verdict: MAJOR REVISION NEEDED
Scope signal: L (8–10 hour single solo dev session)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, ux-designer, gameplay-programmer, accessibility-specialist, creative-director (synthesis)
Blocking items: 22 | Recommended: ~25 | Nice-to-have: ~10
Mode: full (all phases + 7 specialist agents in parallel + creative-director synthesis)
Prior verdict resolved: First review — no prior verdict
GDD posture at review entry: "Designed (2026-05-11)" via `/design-system input` lean mode Session 12; 12 sections + 20 ACs (19 BLOCKING + 1 ADVISORY) + 11 tooling deliverables + 13 F.4.1 cross-doc reciprocal edits; 939 lines, 0 placeholders. Specialists inline during authorship: creative-director (B framing) + game-designer + godot-gdscript-specialist + ux-designer + systems-designer + qa-lead.

### Summary
Pillars 1, 2, and 4 are **not provably delivered** by the ACs as written (creative-director synthesis). Three independent failure categories converge: (a) Pillar-deliverability gaps — B.2 Cascade promise is verified for only 3 of 5 declared consumers and the AC assertion is trivially-true; the 5-min rule has zero AC; the first-death hint latches on the wrong event silently failing Pillar 1; (b) 4 distinct factual/API/path errors that would cause silent false-passes (AC-IN-20-A vs C.1.4 veto-path contradiction with 4-way convergence; E-IN-NEW factually wrong on Godot `_input`/`_unhandled_input` dispatch order with 3-way convergence; `scripts/input/` violates `src/` standard → AC-IN-04 grep silent false-pass = PM B2 trap recurrence; `InputEvent.timestamp` claim unverified against Godot 4.6 reference); (c) two Foundation-layer architectural choices that constrain Tier 3 forever — no `InputStateProvider` adapter seam reserved + `_input` ban lacks AT-injection exception. Comparable in severity to PM #6's MAJOR REVISION but different in character (Input fails on cross-doc rigor + Pillar-deliverability rather than feel/balance). systems-index reverted from "Designed" to "In Design — NEEDS REVISION."

### Blocking items (consolidated, deduped across specialists)

| # | Tier | Source | Issue |
|---|------|--------|-------|
| B1 | Pillar | game-designer + qa-lead (2-way) | AC-IN-03 Cascade harness tests only 3/5 consumers (PM/SM/TRC); Player Shooting #7 + Menu #18 absent. Assertion trivially true (3 consumers reading same global state). B.2 Pillar-2 promise unverified for 40% of consumers. Rewrite with `poll_frame` equality + edge-cleared next-frame check. |
| B2 | Pillar | game-designer | B.2 line 59 hardcodes "30s first jump / 60s shoot / 5min rewind" — zero ACs verify. Pillar 4's primary Input claim is untestable. Add playtest AC-IN-21. |
| B3 | Pillar | game-designer | First-Death Hint returns text string. game-concept Pillar 4 = "텍스트 튜토리얼 0줄". Undeclared carve-out. Either declare Pillar 4 exception in C.1.5 + Decision Log, or change deliverable to `Texture2D` glyph (aligns with ux-designer REC-2 `[LT] ↺`). |
| B4 | Code/Spec | 4-way: qa-lead + godot-specialist + gameplay-programmer + main review | AC-IN-20-A asserts `set_input_as_handled()` on both veto + resume paths; C.1.4 code (lines 126-137) only calls on resume + successful initiate. Veto branch falls through. `architecture.yaml api_decisions.pause_handler_autoload` repeats wrong claim. CD adjudication: veto SHOULD call it (consume every decision path). Update code + registry to match AC. |
| B5 | Code/Spec | 3-way: systems-designer + gameplay-programmer + godot-specialist | E-IN-NEW (line 399) states Godot dispatch order backwards — `_input` always fires *before* `_unhandled_input`. ActiveProfileTracker._input already received event by the time PauseHandler runs. Rewrite mechanism (benign conclusion survives on different grounds). |
| B6 | Code/Spec | 2-way: ux-designer + game-designer | F-key `aim_lock` justification "WASD home row 우측 ring finger" (C.3.1 line 193 + A.1 line 851) is anatomically wrong — F is left **index** finger reach. Real argument: Hotline Miami Shift-aim muscle-memory separation. Fix documentation, keep keymap. |
| B7 | Path/CI | gameplay-programmer + main grep verification | All code snippets use `scripts/input/` (lines 124, 234, 282) but `directory-structure.md` mandates `src/`. AC-IN-04 grep against `src/` would find zero matches → silent false-pass = **PM B2 trap recurrence**. Standardize on `src/input/`. |
| B8 | Formula | systems-designer | D.1.1 JoypadMotion classifier (lines 297-300) has no `event.axis` filter. Right-stick drift or LT trigger drift in (0.3, 0.5) silently flips `_last_input_source = GAMEPAD` without `rewind_consume` firing → wrong first-death prompt label. Filter to `{LEFT_X, LEFT_Y, TRIGGER_LEFT, TRIGGER_RIGHT}`. |
| B9 | Formula | systems-designer | D.3 radial composite deadzone formula entirely missing. C.1.3 line 271 declares "단일 출처" with no math. Add D.3 with variable table + worked examples (Echo case T=0.2). |
| B10 | Formula | systems-designer | G.1.1 + G.1.3 lack cross-knob invariant — `gamepad_stick_deadzone=0.35` + `GAMEPAD_DETECTION_THRESHOLD=0.3` reachable within safe ranges → degenerate. Add invariant `gamepad_stick_deadzone < GAMEPAD_DETECTION_THRESHOLD` with ≥0.05 margin. |
| B11 | Engine | godot-specialist | `InputEvent.timestamp` field claim in D.2 (line 365) unverified vs Godot 4.6 — not in engine-reference snapshot. `wall_clock_in_input_logic` registry entry includes it as banned API. Verify against `docs/engine-reference/godot/modules/input.md` or remove from banned list. |
| B12 | Spec gap | gameplay-programmer | AC-IN-15 `.tres` golden snapshot — no `Resource` subclass schema defined. Programmer must invent comparison API + entry structure. |
| B13 | Spec gap | gameplay-programmer | AC-IN-17 `active_profile_mock` override pattern unspecified (3 valid approaches, wrong one breaks test). Specify `set_override(source, frame)` setter on `ActiveProfileTracker`. |
| B14 | Cross-doc | gameplay-programmer | O-IN-1 (`_trigger_held` gate) adds new state to **Approved** state-machine.md. SM directive says Round 3 차단 except cross-doc-contradiction exception. Sprint sequencing blocker — must either invoke exception or re-review SM; no owner assigned. |
| B15 | Pillar 1/2 | ux-designer | C.1.5 latch fires on first **death**, not first **rewind use**. Player who panic-misses 200ms prompt → latch closes forever → silent death loop. Direct Pillar 2 betrayal. Fix: add `first_rewind_success_in_session` SM signal; latch closes on success, re-arms on subsequent DYING until success. |
| B16 | Cite | ux-designer + verified web | C.3.2 line 209 "Cuphead lock-aim precedent" factually wrong — community consensus LT=lock, RB=avoid (right-hand pinch). CD adjudication: keep RB (LT collision with rewind_consume is worse) but remove false citation; re-justify on left-right separation + accept right-hand pinch as Tier 1 risk + add OQ for Tier 1 RB+RT pinch playtest. |
| B17 | AC structure | qa-lead + main | AC-IN-20-A / AC-IN-20 ID collision (line 758 vs 768); H.12 reports total=20, actual=21. Renumber to AC-IN-20 / AC-IN-21; fix coverage table. |
| B18 | AC structure | qa-lead + main | H.13 references "F.4.1 #14 batch" — F.4.1 has only 13 items. 4 adversarial fixtures cited in AC-IN-05 missing from H.13 deliverables — PM B2 recurrence. Fix references; add fixtures as H.13 items 12-15. |
| B19 | AC classification | qa-lead | AC-IN-20 (F.4.1 ledger) misclassified ADVISORY — closes OQ-SM-3 + OQ-15 + 4 PM provisional flags. Until edits land, cross-doc claims are unverified. Reclassify BLOCKING (manual git-diff gate). |
| B20 | AC rigor | qa-lead | AC-IN-02 checks `count == 9` but not name set. Renaming `jump→leap` silently passes. Add verbatim StringName set equality assertion. |
| B21 | Tier 3 hook | accessibility-specialist | No `InputStateProvider` adapter layer reserved between Phase 2 polling and consumers. Tier 3 #24 motor features (hold-duration scaling, mash assist, toggle mode) require interposition. Anti-Pillar #6 defers Tier 3 *content* not *architecture*. Add seam now (Tier 1 = 1:1 passthrough). |
| B22 | Tier 3 hook | accessibility-specialist | C.1.2 Rule 2 `_input` ban lacks AT injection exception (Xbox Adaptive Controller, switch access). CI gate `forbidden_patterns.gameplay_input_in_callback` will block Tier 3 #24 forever. Add 3rd explicit exception. |

### Recommended revisions (~25 items, deferred to revision pass)

- **R1** [game-designer] E-IN-7 uses word "silently drop" that B.1 defines as betrayal → rename to "state-aware swallow".
- **R2** [game-designer] Autoload processing order untested — add OQ-IN-6 + project.godot order static check.
- **R3** [game-designer] `&"echo_lifecycle_sm"` group lookup is undeclared cross-doc dependency. Add F.4.1 item: SM must register group in `_ready()`. Define null-SM semantics (fail-open vs fail-closed).
- **R4** [game-designer] AC-IN-04 grep is single-line only — same PM B4 trap AC-IN-05 fixed. Use Python multiline regex.
- **R5** [systems-designer] `HYSTERESIS_FRAMES=0` produces silent GAMEPAD-sticky — add boot assert.
- **R6** [systems-designer] `HYSTERESIS_FRAMES=180` no first-principle derivation → downgrade to OQ.
- **R7** [systems-designer] Gamepad hot-plug-IN mid-game undocumented (asymmetry with E-IN-13).
- **R8** [systems-designer] Tier 3 zero-event-binding for `rewind_consume` = silent Pillar 2 betrayal. Add invariant: each of 9 actions must have ≥1 event bound; #23 must refuse-save violations.
- **R9** [qa-lead] AC-IN-17 7-scenarios ambiguity (Scenario 5 with j=1 vs E-IN-14 with j=0).
- **R10** [qa-lead] AC-IN-09 spy implementation undefined.
- **R11** [qa-lead] AC-IN-13 "session" boundary undefined in GUT context.
- **R12** [qa-lead] AC-IN-19 failure mode underspecified — use GUT `fail()`, not `assert()` or `push_error()`.
- **R13** [qa-lead] AC-IN-04 must also ban `Input.action_press` and `parse_input_event` in `src/` (test-only APIs).
- **R14** [qa-lead] Meta-runner `run_static_checks.sh` has no self-test → PM B2 vaccine has no vaccine. Add test of meta-runner itself.
- **R15** [qa-lead] No AC for GAMEPAD_DETECTION_THRESHOLD=0.3 boundary behavior.
- **R16** [qa-lead] No AC for PauseHandler→ActiveProfileTracker downstream effect.
- **R17** [qa-lead] No Tier 1 static guard for Tier 3 `default_only` invariant.
- **R18** [godot-specialist] `class_name InputActions` missing `extends RefCounted`/`Object`.
- **R19** [godot-specialist] `Input.get_vector` "average" deadzone aggregation claim unverified → weaken to "irrelevant for Echo (all 4 = 0.2)" until cited.
- **R20** [godot-specialist] `GAMEPAD_DETECTION_THRESHOLD` and `HYSTERESIS_FRAMES` consts not declared in `ActiveProfileTracker` code snippet.
- **R21** [ux-designer] D.1.2 `InputEventMouseMotion` triggers permanent KB_M sticky → fails Steam Deck + docked-mouse multi-monitor. Separate mouse motion from key/button classification.
- **R22** [ux-designer] G.1.4 English "Rewind" is only Tier 1 in-game text → Korean cognitive accessibility regression. Use `[LT] ↺` glyph (or `[LT] ↺ Rewind` paired).
- **R23** [ux-designer] E-IN-9 silent on "DYING begins while paused" timer-freeze behavior.
- **R24** [gameplay-programmer] D.1.2 sequential-if-elif vs switch-statement translation ambiguity. Promote worked examples above formula.
- **R25** [gameplay-programmer] G.1.4 `{key}` substitution API unspecified (suggest `String.format()`).
- **R26** [gameplay-programmer] C.1.4 `PROCESS_MODE_ALWAYS` assignment location not shown.
- **R27** [gameplay-programmer] C.1.2 references "Phase 2" without local definition (cross-file lookup mandatory). Add inline 5-phase summary box.
- **R28** [accessibility] C.2 Tier 3 single default profile only — no preset slot (left-handed, one-handed).
- **R29** [accessibility] C.1.5 first-death repeat slot + audio companion cross-doc to Audio #4.
- **R30** [accessibility] E-IN-7 pause-veto during DYING has no Tier 3 override slot.
- **R31** [accessibility] G.1.1 deadzone single scalar — no per-stick / shape (radial/square/cross) hook for Tier 3 #24.

### Nice-to-have (~10 items)

- F-key Hotline Miami collision rationale currently undocumented (worth adding the real argument).
- E-IN-11 focus-loss DYING-window extension violates Pillar 2 symmetry — Decision Log entry needed. **CD addition**: also competitive-integrity concern for any future speedrun community (hard-gate at Tier 2 if community forms).
- HYSTERESIS_FRAMES no fixed-profile-lock for simultaneous-device adaptive setups.
- G.1.4 prompt no contrast/size cross-doc obligation to HUD #13 (WCAG AA 4.5:1).
- H.13 11 deliverables lack build-order annotation.
- AC-IN-03 cascade mock interface schema not specified.
- D.1.2 `f₀=-1` init value not called out in formula prose (worked example covers it).
- Pillar 3 (Collage = first impression) has zero presence in this GDD — the first-death prompt should be art-directed as a collage element. Add art-director consult to F.4.2 #2.
- 13-edit F.4.1 batch has no rollback story. Add `rollback-safe?` column to `production/qa/input-f41-batch.md`.
- B.4 "Achievers primary" framing may not be Pillar-1-consonant (학습 도구 ↔ mastery tension). Tier 2 playtest target audience validation.

### Senior verdict [creative-director]

The GDD is intellectually impressive — B.2 "Cascade" framing is some of the strongest player-fantasy writing this project has produced, and the F.4.1 reciprocity ledger is a genuine craft artifact. But it is **not ready for sprint pickup**. Three independent failure modes converge: (a) the pillar-promises the GDD makes are not provably delivered by the ACs as written, (b) at least 4 distinct factual/API errors will cause a programmer to come back with questions or silently mis-implement, and (c) Foundation-layer architectural choices that constrain Tier 3 forever are being made invisibly, in violation of Anti-Pillar #6's intent (defer Tier 3, not foreclose it). Comparable in severity to PM #6's MAJOR REVISION but different in character — PM #6 failed on feel/balance; Input #1 fails on cross-doc rigor + Pillar-deliverability. Solo revision pass estimated 8–10 hours single session. What's worth saving in revision: B.1/B.2 split, F.4.1 reciprocity batch, A.1 Decision Log + A.3 Consult Trail, OQ deferrals — all keep.

### Specialist disagreements adjudicated

| Topic | Disagreement | Adjudication |
|---|---|---|
| Gamepad `aim_lock = RB` | ux-designer: Cuphead citation false (community consensus is LT=lock, RB=avoid). game-designer Attack #3: "defenses hold" on left-right separation logic. | Keep RB (LT collision with rewind_consume is worse). Remove false Cuphead citation. Re-justify on left-right separation + Pillar 1 LT exclusivity. Accept right-hand pinch as Tier 1 risk + add OQ for playtest. |
| AC-IN-20-A veto-path consumption | 3-way "design decision required" (qa-lead BLK-1 + godot Item 1 + gameplay-programmer BLOCKING-1). | Veto SHOULD call `set_input_as_handled()` (canonical Godot 4.6 — consume on every decision). Update C.1.4 code + architecture.yaml registry to match AC-IN-20-A. |

### Recommended revision sequence

1. Fix the 4-way AC-IN-20-A vs C.1.4 vs architecture.yaml convergence first (~30 min).
2. Fix `scripts/input/` → `src/input/` everywhere + AC-IN-04 grep target (~20 min).
3. Fix E-IN-NEW factual error on `_input` ordering (~30 min).
4. Add D.3 deadzone formula + B8 axis filter + B10 cross-knob invariant together (~90 min).
5. Fix first-rewind-success latch + add SM signal (~45 min).
6. Add Pillar-deliverability ACs (5/5 Cascade, 5min-rule, Pillar 3 collage hook) (~90 min).
7. Add `InputStateProvider` seam + AT injection exception (~30 min).
8. Promote AC-IN-20 to BLOCKING + fix AC ID collision/count (~15 min).
9. Citation/factual cleanup (Cuphead, ring-finger, InputEvent.timestamp, get_vector "average") (~45 min).
10. Address remaining REC + GAP items in batch (~90 min).

Total: 8–10 hours focused solo revision, single session, `/clear` before re-review.

### Cross-doc impact of revision

- **state-machine.md** (currently Approved/LOCKED): O-IN-1 `_trigger_held` gate + new signal `first_rewind_success_in_session` are additive. May qualify for cross-doc-contradiction exception (Round-7 candidate per F.3 line 457). Decision needed before revision starts.
- **architecture.yaml**: `api_decisions.pause_handler_autoload` entry must be updated to match B4 resolution (`set_input_as_handled()` on both paths).
- **F.4.2 #2 to HUD #13** (deferred): add art-director consult for prompt as collage element (Pillar 3).
- **F.4.2 #4 to Audio #4** (deferred): add audio companion obligation for first-death hint (accessibility R29).

### Re-review expectation

Re-review can run `--depth lean` (single-session, no specialist agents) — the heavy adversarial pass has now been done, and lean re-review will confirm the 22 BLOCKING fixes without burning another 7-agent session. Recommend `/clear` before re-review.

---

## Review — 2026-05-11 — Verdict: APPROVED
Scope signal: L (unchanged from prior review — 1252 lines, 24 ACs, 18 deliverables, 13 F.4.1 cross-doc edits, 8 F.4.2 deferred obligations)
Specialists: none (lean mode — no specialist agents spawned; prior fresh-session review already completed the 7-agent adversarial pass)
Mode: lean (Phases 1–5, no Phase 3b specialist delegation per `--depth lean`)
Blocking items: 0 | Recommended: 2 | Nice-to-have: 4
Prior verdict resolved: Yes — all 22 BLOCKING from 2026-05-11 (MAJOR REVISION NEEDED) verified resolved with citable A.1 Decision Log mapping (Sessions 13–14 Tasks #5/#6/#9/#10/#11)
GDD posture at re-review entry: revised file 1252 lines, 24 ACs (23 BLOCKING + 1 ADVISORY), 18 deliverables, 4 architecture.yaml registry additions queued.

### Summary
Re-review evidence base: A.1 Decision Log row-by-row mapping + direct grep verification + comparison against the 2026-05-11 fresh-session review entry above. Every B# fix has a citable site in current text — no silent-pass risk. The revision tightened scope (24 ACs vs prior 20, 18 deliverables vs prior 11) without introducing new BLOCKING issues. Round-7 cross-doc-contradiction exception umbrella for SM additions (O7/O8/O9 — first_death_in_session signal owner + first_rewind_success_in_session signal owner + _trigger_held gate) is consistent with the Round 5 damage.md S1 precedent and is the right escape hatch given SM's Approved/LOCKED status. systems-index promoted from "In Design — NEEDS REVISION" to "Approved"; Designed counter 0→1.

### Blocking items resolved (22/22)

| # | Prior issue | Resolution site in current text |
|---|-------------|-------------------------------|
| B1 | Cascade 3/5 consumers + trivially-true | AC-IN-03 rewritten 5-consumer (PM/SM/TRC/PS/Menu) + pairwise `poll_frame` equality + edge-cleared next-frame check; harness deliverable `tests/helpers/cascade_5_consumer_harness.gd` (H.13 #3) |
| B2 | 5-min rule zero AC | AC-IN-21 added (H.11b ADVISORY playtest, N=5 min, escalation to N=15) + protocol deliverable `production/qa/pillar4-5min-rule-playtest.md` (H.13 #18) |
| B3 | First-death hint Pillar 4 carve-out undeclared | C.1.5 explicit Pillar 4 carve-out paragraph + comparative justification (Dark Souls / Cuphead / Hollow Knight precedent) + glyph-alt rejection rationale + Decision Log A.1 entry |
| B4 | AC-IN-20-A vs C.1.4 veto-path 4-way contradiction | C.1.4 line 141 `set_input_as_handled()` on every decision (resume + initiate + veto); AC-IN-24 (renumbered from AC-IN-20-A) verifies both paths; B4 reconciliation paragraph documents CD adjudication |
| B5 | E-IN-NEW factually wrong on `_input` dispatch order | E-IN-NEW rewritten with correct Godot 4.6 dispatch order (`_input` → GUI → `_shortcut_input` → `_unhandled_key_input` → `_unhandled_input`); benign conclusion preserved on different grounds; "registration order matters" claim removed |
| B6 | F-key anatomy "right ring finger" wrong | C.3.1 row corrected to "left index finger" + Hotline Miami Shift-aim muscle-memory separation rationale; Decision Log B6 row |
| B7 | `scripts/input/` violates `src/` standard | All 4 code snippets use `src/input/` (lines 128, 189, 284, 332); AC-IN-04 grep targets `src/` |
| B8 | D.1.1 axis filter missing | PROFILE_AXES whitelist `[LEFT_X, LEFT_Y, TRIGGER_LEFT, TRIGGER_RIGHT]` + early-return on unbound axes; AC-IN-23 verifies; B8 axis filter rationale paragraph |
| B9 | D.3 radial deadzone formula entirely missing | D.3 added with formula + variable table + 5 worked examples (Echo case T=0.2 from sub-deadzone Steam Deck drift through diagonal full-tilt clamp); cross-references C.1.3 policy |
| B10 | Cross-knob invariant absent | INVARIANT-IN-1 (`gamepad_stick_deadzone < GAMEPAD_DETECTION_THRESHOLD` strict) + INVARIANT-IN-2 (margin ≥ 0.05) + boot-time assert in ActiveProfileTracker `_ready()`; AC-IN-22 verifies degenerate config rejection |
| B11 | `InputEvent.timestamp` Godot 4.6 unverified | D.2 banned list reduced to `Time.*` / `OS.*` family only; B11 fix paragraph documents removal rationale (engine-reference verification 2026-05-11); AC-IN-18 grep pattern updated |
| B12 | `.tres` Resource schema undefined | A.6.1 InputMapSnapshot Resource class spec + production class location `src/input/input_map_snapshot.gd` (H.13 #6); AC-IN-15 cross-refs A.6.1 |
| B13 | Mock override pattern undefined | A.6.2 ActiveProfileMock Node class + child-injection pattern (NOT autoload override) + formula-drift prevention obligation; AC-IN-17 cross-refs A.6.2 |
| B14 | O-IN-1 `_trigger_held` adds state to Approved SM | F.4.1 #4 marked ✅ — applied to SM C.2.2 O9 under Round-7 cross-doc-contradiction exception (active.md Session 14 header umbrella); SM "8가지 의무" → "9가지 의무" |
| B15 | Latch on first death not first rewind use | C.1.5 rewritten — show every DYING + permanent dismiss on first rewind success (`_lethal_hit_latched_prev == true`) + scene-change re-arm; SM owns 2 signals (O7/O8); AC-IN-13 5-scenario coverage including hazard-grace exclusion |
| B16 | "Cuphead lock-aim precedent" false citation | C.3.2 row re-justified on left-right separation (LT=rewind, RB=avoid right-hand pinch); B16 fix paragraph documents CD adjudication; OQ-IN-6 added for Tier 1 RB+RT pinch playtest |
| B17 | AC-IN-20-A / AC-IN-20 ID collision | AC-IN-20-A renumbered to AC-IN-24 (3 cross-ref sites updated); H.10 + H.11 + H.12 all consistent |
| B18 | Phantom F.4.1 #14 + missing fixtures | H.13 cleaned to 18 deliverables; phantom #14 reference removed; 4 adversarial fixtures (one_line_pass / empty_body / logic_in_callback / no_func) + first_death_hint_spy + input_map_snapshot.gd + pillar4 protocol added (H.13 #13–18) |
| B19 | AC-IN-20 misclassified ADVISORY | AC-IN-20 reclassified BLOCKING with manual git-diff gate + reclass rationale paragraph (closes OQ-SM-3 + OQ-15 + 4 PM provisional flags) |
| B20 | AC-IN-02 checks count not names | AC-IN-02 strengthened — exact 9-StringName set equality (`size` + `EXPECTED.all(...)` + `ACTUAL.all(...)` + per-element `has_action`) + silent-rename trap documentation |
| B21 | No `InputStateProvider` adapter seam | C.1.6 added — 5-method static wrapper signature lock-in + Tier 1 passthrough invariant + Tier 3 #24 migration scope (hold_duration_scaling / mash_assist / toggle_mode); F.4.2 #7 row updated |
| B22 | `_input` ban lacks AT injection exception | C.1.2 Rule 2 expanded to 3 active (Tier 1: Menu / PauseHandler / ActiveProfileTracker) + 1 carve-out (Tier 3: AssistiveInputBridge prefix OR `_at_bridge_exempt: bool` marker); F.4.1 #13 architecture.yaml entry includes carve-out spec; F.4.2 row 8 (Tier 3 #24) hosts activation responsibility |

### Recommended revisions (2 — non-blocking)

- **R1** A.3 Specialist Consult Trail row "H Acceptance Criteria" reads "20 ACs (19 BLOCKING + 1 ADVISORY) + 11 tooling deliverables" — stale. Current state per H.12 + H.13 is **24 ACs (23 BLOCKING + 1 ADVISORY) + 18 tooling deliverables**. One-line edit; not a gate.
- **R2** F.4.1 #4 introduces O-IN-3b's `_lethal_hit_latched_prev` predicate via the new `first_rewind_success_in_session` signal but does not name a concrete SM exposure mechanism (private member vs signal payload vs `is_lethal_hit_rewind()` query method) for AC-IN-13 scenario (e) to inspect. SM authoring will surface this; recommend pre-deciding to avoid a second cross-doc-exception round. Suggested: payload `(profile: StringName, was_lethal_hit: bool)` so HUD can no-op on hazard-grace rewinds without a private read.

### Nice-to-have (4 — carried from prior review)

- F.4.2 #2 to HUD #13 — explicitly add art-director consult for first-death prompt as Pillar 3 collage element.
- F.4.2 #4 to Audio #4 — audio companion obligation for first-death hint (accessibility R29 from prior review).
- AC-IN-20 deliverable `production/qa/input-f41-batch.md` could include a `rollback-safe?` column.
- B.4 "Achievers primary" framing — Tier 2 audience playtest validation candidate (not gated).

### Senior verdict

*Lean mode — no creative-director synthesis spawned. Verdict reflects the main reviewer's synthesis based on row-by-row B# verification, dependency graph validation, and comparison against the prior fresh-session review.*

GDD is implementation-ready. The two recommended revisions are minor maintenance edits — neither blocks programmer pickup. The revision pass tightened scope without bloat (24 ACs vs prior 20, 18 deliverables vs prior 11; line count grew 939 → 1252 absorbing the 22 BLOCKING fixes + new D.3 formula + A.6 schema appendices). Cross-doc rigor — the prior review's primary failure mode — is now the GDD's strongest property: every Pillar promise has a citable AC, every cross-doc obligation has a reciprocal F.4.1 entry with a Round-7 exception umbrella where required, every test-helper has both a deliverable file path and a calling AC. Story closure for System #1 Input is gated on AC-IN-20 (BLOCKING manual ledger) confirming the 13-edit F.4.1 batch lands in target GDDs/registry — recommend that batch be applied in a single short follow-up session before #1's first sprint pickup.

### Specialist disagreements
None — lean mode, no specialist agents spawned. Prior-review (2026-05-11 fresh-session) adjudications stand: gamepad `aim_lock = RB` kept (LT collision worse); AC-IN-24 veto-path consume-on-decision applied.

### Cross-doc impact closure
- **state-machine.md** (Approved/LOCKED): F.4.1 #4 + #5 + #6 + #7 cross-doc edits queued (under Round-7 exception umbrella). SM C.2.2 O9 already applied per Session 14 Task #11 close-out. Remaining: O7/O8 signal additions + line 868 placeholder fix + can_pause naming alias.
- **time-rewind.md** (Approved/LOCKED): F.4.1 #8 + #9 cross-doc edits queued (C.3 #1 InputMap cross-ref + OQ-15 Resolved marker).
- **player-movement.md** (In Design — NEEDS REVISION 10 BLOCKING): F.4.1 #1 + #2 + #3 cross-doc edits queued (C.5.3 *(Provisional)* removal + C.6 row 470 cleanup + F.4.2 obligation registry close).
- **systems-index.md**: F.4.1 #10 + #11 + #12 applied this session (System #1 row → Approved + Designed counter 0→1 + Last Updated header prepend).
- **docs/registry/architecture.yaml**: F.4.1 #13 4 new entries pending (state_ownership.input_actions_catalog + interfaces.input_polling_contract + 3 forbidden_patterns + 2 autoload api_decisions + last_updated). AC-IN-20 BLOCKING gate.

### Re-review expectation
Story-readiness check (`/story-readiness` once stories are written) should confirm: (a) AC-IN-20 ledger fully checked, (b) all 13 F.4.1 cross-doc edits applied to target files, (c) 18 deliverables exist as scaffolds before sprint pickup. No further `/design-review` cycles required for input.md unless a downstream system surfaces a cross-doc contradiction.

---
