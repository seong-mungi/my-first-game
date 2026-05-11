# Input #1 — F.4.1 Cross-Doc Reciprocal Edit Batch Ledger

> **AC-IN-20 deliverable** (BLOCKING — input.md H.11). Single-source progress tracker for the 13-edit cross-doc batch that closes Input #1's reciprocal obligations to neighbouring GDDs + architecture registry.
>
> **Story closure rule** (per AC-IN-20): all 13 items checked AND `git diff` against the 4 target GDDs (player-movement.md, state-machine.md, time-rewind.md, systems-index.md) + `architecture.yaml` shows the expected provisional-flag removals, naming unifications, and registry additions. **AC fails (BLOCKING)** if any checklist item unchecked OR `git diff` shows unmade changes.
>
> **Created**: 2026-05-11 (re-review APPROVED session)
> **Source**: `design/gdd/input.md` Section F.4.1 (items #1–#13)

---

## Status Legend

- ✅ **Applied** — edit is in the target file; git diff shows the expected change
- 🟡 **In progress** — edit started but not committed
- ⬜ **Pending** — edit not yet applied
- 🚫 **Blocked** — edit cannot be applied (dependency missing); explain in Notes

---

## Checklist

| # | Target file | Edit | Status | Verified by | Notes |
|---|-------------|------|--------|-------------|-------|
| 1 | `design/gdd/player-movement.md` C.5.3 | Remove "(Provisional pending Input System #1)" section header + lock 4 items verbatim (deadzone 0.2, KB+M `A/D/W/S` + `Space`/`F`/`Shift` + `Escape`, action names `move_left/right/up/down/jump/aim_lock/shoot/rewind_consume/pause`, AimLock-jump exclusivity) | ✅ Applied | re-review APPROVED session 2026-05-11 | C.5 header changed from "Input Contract (Provisional pending Input System #1)" to "Input Contract (Locked — Input System #1 Designed 2026-05-11)"; C.5.3 rewritten as resolved cross-doc lock referencing input.md C.1.1/C.1.3/C.3.1/C.3.3 |
| 2 | `design/gdd/player-movement.md` C.6 row "Input System #1" | Remove `*provisional*` indicator + add explicit cross-ref to input.md C.1.2 Rule 2 (`_input` callback forbidden) as single source | ✅ Applied | re-review APPROVED session 2026-05-11 | C.6 row Wiring column already references PM polling pattern; updated row to add cross-ref pointer to `input.md C.1.2 Rule 2` for the forbidden-callback policy single source |
| 3 | `design/gdd/player-movement.md` F.4.2 obligations registry | Mark "Input #1 (deadzone + AimLock-jump exclusivity)" obligation as **resolved** + AC-H4-04 ADVISORY → obsolete (Input GDD AC-IN-06/07/16 BLOCKING replace) | ✅ Applied | re-review APPROVED session 2026-05-11 | F.4.2 registry note appended with resolution stamp + AC-H4-04 obsolete marker |
| 4 | `design/gdd/state-machine.md` F.1 row 832 (Input System row) | Remove `*provisional*` flag + add `design/gdd/input.md` link + `_trigger_held` gate cross-doc obligation cross-ref | ✅ Applied (Session 14) | grep verification: line 835 reads "Input GDD [`design/gdd/input.md`](input.md) **Designed 2026-05-11**" + `_trigger_held` gate obligation paragraph; F.4 mirror line 871 also updated | Already applied per Session 14 close-out batch |
| 5 | `design/gdd/state-machine.md` F.1 line 868 | Correct `input-system.md` placeholder → `input.md` (Round-7 cross-doc-contradiction exception applied at Phase 5) | ✅ Applied (Session 14) | grep verification: no `input-system.md` substring remains in state-machine.md; line 871 uses `input.md` | Already applied per Session 14 close-out batch |
| 6 | `design/gdd/state-machine.md` OQ-SM-3 | Mark **Resolved** (`rewind_consume` action name verbatim locked at input.md C.1.1 row 8) | ✅ Applied (Session 14) | grep verification: line 1064 reads "~~**OQ-SM-3**~~ ✅ **Resolved 2026-05-11** ... Input #1 F.4.1 #6 closure" | Already applied per Session 14 close-out batch |
| 7 | `design/gdd/state-machine.md` C.2.2 O2 | `should_swallow_pause()` ↔ `can_pause()` naming unification (alias added or rename) — PauseHandler queries `can_pause()` per input.md C.1.4 | ✅ Applied | re-review APPROVED session 2026-05-11 | O2 row updated to document both names as aliases (alias method `can_pause()` returning `not should_swallow_pause()` for PauseHandler interop); both call sites supported |
| 8 | `design/gdd/time-rewind.md` C.3 #1 row (Input System) | Cross-doc to input.md C.3.2 Gamepad LT row + C.3.1 KB+M Shift row + C.1.1 row 8 + C.2 single-button-no-chord invariant | ✅ Applied (Session 14) | grep verification: line 131 reads "**Input #1 Designed 2026-05-11**: cross-doc obligations verbatim locked (input.md C.1.1 row 8 + C.3.1 KB+M Shift + C.3.2 Gamepad LT threshold 0.5 + C.2 single-button-no-chord Tier 1 invariant + C.2 Tier 3 `default_only` interpretation — OQ-15 closure)" | Already applied per Session 14 close-out batch |
| 9 | `design/gdd/time-rewind.md` OQ-15 | Mark **Resolved** (Tier 3 chord = `default_only` interpretation locked, input.md C.2 single source) | ✅ Applied (Session 14) | grep verification: line 755 reads "~~**OQ-15**~~ ✅ **Resolved 2026-05-11** ... `default_only` interpretation locked (input.md C.2 단일 출처) ... Input #1 F.4.1 #9 closure" | Already applied per Session 14 close-out batch |
| 10 | `design/gdd/systems-index.md` System #1 row | status `Approved`, Design Doc link `input.md`, Depends On `—` | ✅ Applied | re-review APPROVED session 2026-05-11 | System #1 row updated to "Approved (re-review APPROVED 2026-05-11 lean mode)" with full B# resolution citation; Design Doc + Review Log links present; Depends On `—` (Foundation, no upstream) |
| 11 | `design/gdd/systems-index.md` Progress Tracker | Designed `0` → `1` (Input added; PM remains In Design separately) | ✅ Applied | re-review APPROVED session 2026-05-11 | Progress Tracker "Design docs approved" 3 → 4 (Input #1 added to approved list alongside SM #5, Damage #8, Time Rewind #9); "Designed (pending re-review)" 0 → 0 with PM #6 standalone note |
| 12 | `design/gdd/systems-index.md` Last Updated header | Prepend re-review entry citing 22 BLOCKING resolution + lean mode + scope L unchanged | ✅ Applied | re-review APPROVED session 2026-05-11 | Header prepended with full re-review entry; prior 2026-05-11 NEEDS REVISION entry preserved for audit trail |
| 13 | `docs/registry/architecture.yaml` | Add 7 new entries: `state_ownership.input_actions_catalog` + `interfaces.input_polling_contract` + `forbidden_patterns.gameplay_input_in_callback` (with Tier 1 exception list: Menu #18 + PauseHandler + ActiveProfileTracker; Tier 3 carve-out: AT bridge via `AssistiveInputBridge` class_name prefix OR `_at_bridge_exempt: bool` marker — B22) + `wall_clock_in_input_logic` + `deadzone_in_consumer` + `api_decisions.pause_handler_autoload` + `active_profile_tracker` + `last_updated` field bump | ✅ Applied (Session 14) + carve-out gap-fill this session | grep verification: 7 entries present (lines 110, 268, 461, 473, 575, 585, 595); `last_updated` 2026-05-11 line 33; **gap-fixed this session**: `forbidden_patterns.gameplay_input_in_callback` description expanded to include ActiveProfileTracker as 3rd Tier 1 active exception + Tier 3 AT bridge carve-out (B22 fix) | Session 14 applied core 7 entries; 2026-05-11 re-review APPROVED session added missing B22 carve-out detail to exception list per F.4.1 #13 specification |

---

## Status Summary

| Status | Count |
|--------|-------|
| ✅ Applied | **13 / 13** |
| 🟡 In progress | 0 |
| ⬜ Pending | 0 |
| 🚫 Blocked | 0 |

**AC-IN-20 verdict**: ✅ **PASS** (all 13 items applied; ready for `git diff` verification at story-closure time)

---

## Cross-Doc Exception Audit

The following items required **Round-7 cross-doc-contradiction exception** invocation (additive state to Approved/LOCKED state-machine.md per the `damage.md` Round 5 S1 BLOCKER pattern, Session 6 2026-05-10 precedent):

- **Item #4** — SM F.1 row 832 update (additive cross-doc obligation reference, no API surface change)
- **Item #6** — OQ-SM-3 Resolved marker (closure annotation, no behaviour change)
- **Item #7** — C.2.2 O2 `can_pause()` alias addition (additive method, `should_swallow_pause()` preserved for backward compat)
- **SM C.2.2 O7/O8/O9 additions** (covered under same exception umbrella) — 2 new signals (`first_death_in_session` per-DYING + `first_rewind_success_in_session` per-session) + `_trigger_held` gate for LT chatter

CD pre-authorization: `production/session-state/active.md` Session 14 header umbrella + `damage.md` Round 5 S1 precedent. SM re-review **NOT** required — all additions are additive (state members + signals + gate) with zero framework code modification.

---

## Rollback-Safe Audit (NICE-TO-HAVE per prior review)

All 13 edits are **rollback-safe** — additive or annotation-only:

- Items #1/#2/#3 (PM): provisional-flag removals + obligation-resolved markers; original PM rules preserved verbatim under new lock heading
- Items #4/#5/#6 (SM provisional): cross-ref additions + Resolved annotations; no behavioural change
- Item #7 (SM O2 alias): additive method (`can_pause()` returns `not should_swallow_pause()`); both names callable
- Items #8/#9 (TR): cross-ref additions + Resolved annotation
- Items #10/#11/#12 (systems-index): status promotion + counter increment + header prepend (prior entry preserved as audit trail)
- Item #13 (architecture.yaml): 7 new entries (additive); `last_updated` bump + carve-out detail expansion

Rollback procedure if regression discovered: `git revert` of this session's commit will restore prior state across all 5 target files.

---

## Verification Commands (run at story-closure time)

```sh
# Item #4-#6 verification
grep -nE "input\.md|input-system\.md" design/gdd/state-machine.md
# Expected: zero `input-system.md` matches; multiple `input.md` matches; OQ-SM-3 Resolved row present

# Item #7 verification
grep -nE "can_pause|should_swallow_pause" design/gdd/state-machine.md
# Expected: O2 row + nearby text shows both names with alias relationship documented

# Item #8-#9 verification
grep -nE "input\.md|OQ-15" design/gdd/time-rewind.md
# Expected: C.3 #1 row references input.md C.1.1/C.3.1/C.3.2/C.2; OQ-15 marked Resolved

# Item #1-#3 verification
grep -nE "Provisional pending Input System|Input #1.*resolved|Input System #1.*Locked" design/gdd/player-movement.md
# Expected: zero "Provisional pending" matches in C.5; resolution markers present in F.4.2

# Item #10-#12 verification
grep -nE "Input System.*Approved|Designed 0.*1|input-review-log" design/gdd/systems-index.md
# Expected: System #1 row Approved status; counter increment present

# Item #13 verification
grep -nE "input_actions_catalog|input_polling_contract|gameplay_input_in_callback|wall_clock_in_input_logic|deadzone_in_consumer|pause_handler_autoload|active_profile_tracker" docs/registry/architecture.yaml
# Expected: 7 named entries present; `last_updated: "2026-05-11"` with Input #1 annotation
```

---

## Cross-Reference

- **Input GDD source**: `design/gdd/input.md` Section F.4.1 (items #1–#13)
- **AC contract**: `design/gdd/input.md` H.11 AC-IN-20 (BLOCKING per B19 fix Session 14 2026-05-11 reclass)
- **Re-review log**: `design/gdd/reviews/input-review-log.md` 2026-05-11 APPROVED entry
- **Round-7 exception precedent**: `design/gdd/damage.md` Round 5 S1 BLOCKER fix (Session 6 2026-05-10) + `design/gdd/gdd-cross-review-2026-05-10.md`
