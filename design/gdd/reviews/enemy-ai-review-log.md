# Enemy AI Review Log

## Review — 2026-05-13 — Verdict: NEEDS REVISION

Scope signal: L
Specialists: lean mode — none spawned
Blocking items: 1 | Recommended: 4
Summary: First lean design review found the GDD structurally complete and strongly aligned with the deterministic-pattern fantasy, but one internal contradiction blocks implementation handoff: D.9/E.14 define Area2D budget overflow as a pre-runtime authoring error while AC-EAI-22 requires runtime projectile refusal. Resolve that contract before approval; remaining issues are cleanup/mirror polish.
Prior verdict resolved: First review

### Completeness

- 8/8 required sections present: Overview, Player Fantasy, Detailed Design, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria.
- Optional Visual/Audio Requirements and Open Questions are present.

### Dependency Graph

- ✓ `state-machine.md` — exists.
- ✓ `damage.md` — exists.
- ✓ `player-movement.md` — exists.
- ✓ `player-shooting.md` — exists.
- ✓ `time-rewind.md` — exists.
- ✓ `audio.md` — exists.
- ✓ `camera.md` — exists.
- ✗ `stage-encounter.md` — not started; acceptable because Enemy AI marks the contract provisional.
- ✗ `boss-pattern.md` — not started; acceptable because STRIDER phase ownership is explicitly delegated.

### Required Before Implementation

1. [main-review] Resolve the Area2D budget contract contradiction:
   - D.9 and E.14 say `damage_area2d_safe == false` is a Stage/Encounter authoring error and that Enemy AI must not pause/deactivate runtime behavior based on budget pressure.
   - AC-EAI-22 says Enemy AI refuses new non-critical enemy projectile spawns when the total would exceed Damage #8 `area2d_max_active=80`.
   - Choose one canonical behavior. Recommended fix: make AC-EAI-22 a validation/preflight criterion that rejects invalid encounter configs before gameplay activation, matching D.9/E.14.

### Recommended Revisions

1. [main-review] Normalize C.7 VFX hook names. It currently mentions `spot_started`, `attack_committed`, and `enemy_killed`, while C.8/F.3/VA.4 define the canonical Enemy AI presentation signals as `enemy_spotted_player`, `enemy_attack_committed`, `enemy_projectile_spawned`, and `enemy_died`, with Damage owning `enemy_killed`.
2. [main-review] Refresh stale post-authoring text in F.6/F.7 now that Open Questions are closed. In particular, `state-machine.md` follow-up still says to re-check after Open Questions close, and F.7 step 1 still says to finish G-H and Visual/Audio/Open Questions.
3. [main-review] Clarify D.4 `facing_gate` behavior when `dx == 0` and `allow_back_detection == false`. `sign_or_zero(dx) == facing_direction` makes directly vertical targets fail the facing gate; confirm this is intended or specify a deterministic tie rule.
4. [main-review] After blocker fix, update reciprocal mirrors that still describe Enemy AI as in-progress, especially `state-machine.md` F.2/F.4 text.

### Nice-to-Have

- Add a short note that D.2 arithmetic assumes Godot/GDScript integer capacity is sufficient for `spawn_id * 1103515245`, or constrain `spawn_id`/intermediate handling if implementation uses narrower integer contexts.
- Consider splitting AC-EAI-33 into a required Tier 1 budget smoke check and a later hardware profile if Steam Deck-equivalent validation is not available before first implementation.

### Senior Verdict

Lean mode skipped specialist and creative-director delegation. Main-review verdict: the design is close and substantially implementable, but the Area2D budget contradiction would cause programmers and QA to implement opposite behaviors. Mark as Needs Revision until that contract is unified.

## Re-review — 2026-05-13 — Verdict: NEEDS REVISION

Scope signal: L
Specialists: lean mode — none spawned
Blocking items: 1 | Recommended: 4
Summary: Lean re-review found no evidence that the prior blocking Area2D budget contradiction was revised. `D.9` / `E.14` still classify budget overflow as a Stage/Encounter pre-runtime authoring error, while `AC-EAI-22` still requires Enemy AI to refuse non-critical projectile spawns at runtime. Verdict remains Needs Revision.
Prior verdict resolved: No

### Required Before Implementation

1. [main-review] Resolve the still-open Area2D budget contract contradiction by aligning `AC-EAI-22` with `D.9` / `E.14`, or by explicitly revising `D.9` / `E.14` to authorize runtime projectile refusal.

### Systems Index

- No status change required: `systems-index.md` already lists Enemy AI #10 as `Needs Revision · 2026-05-13`.

## Revision — 2026-05-13 — Area2D Budget Contract Fix

Applied fixes:

1. Revised `AC-EAI-22` to match `D.9` / `E.14`: Area2D budget overflow is now a deterministic preflight validation failure before gameplay activation, not a runtime Enemy AI projectile-refusal branch.
2. Normalized C.7 VFX hook names to the canonical signal surface: `enemy_spotted_player`, `enemy_attack_committed`, `enemy_projectile_spawned`, and `enemy_died`; Damage remains the source of record for `enemy_killed`.
3. Clarified D.4 facing-gate behavior for `dx == 0`: vertically aligned targets pass the facing gate when range checks pass.
4. Refreshed F.6/F.7 post-authoring text now that Open Questions are closed.
5. Refreshed State Machine reciprocal mirror text for Enemy AI #10.

Status after revision: `Designed · 2026-05-13 · pending re-review`.

## Re-review — 2026-05-13 — Verdict: APPROVED

Scope signal: L
Specialists: lean mode — none spawned
Blocking items: 0 | Recommended: 0
Summary: RR1 verified the prior Area2D budget blocker is resolved. `AC-EAI-22` now matches `D.9` / `E.14` by requiring deterministic preflight validation failure before gameplay activation, while preserving the rule that Enemy AI must not silently pause AI ticks or refuse scheduled projectile emissions at runtime as hidden budget correction.
Prior verdict resolved: Yes

### Completeness

- 8/8 required sections present.
- No `[To be designed]` placeholders remain.
- Visual/Audio Requirements and Open Questions remain present and non-blocking.

### Dependency Graph

- ✓ `state-machine.md` — exists; reciprocal Enemy AI mirror refreshed.
- ✓ `damage.md` — exists.
- ✓ `player-movement.md` — exists.
- ✓ `player-shooting.md` — exists.
- ✓ `time-rewind.md` — exists.
- ✓ `audio.md` — exists.
- ✓ `camera.md` — exists.
- ✗ `stage-encounter.md` — not started; acceptable provisional dependency.
- ✗ `boss-pattern.md` — not started; acceptable provisional dependency.

### Required Before Implementation

None.

### Recommended Revisions

None blocking for implementation handoff. Future Stage/Encounter #12 and Boss Pattern #11 GDDs must mirror Enemy AI's spawn metadata and STRIDER host contracts when authored.

### Senior Verdict

Lean mode skipped specialist and creative-director delegation. Main-review verdict: Approved. The GDD is structurally complete, internally consistent after the Area2D contract fix, and implementable enough for programmer handoff.
