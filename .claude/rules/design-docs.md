---
paths:
  - "design/gdd/**"
---

# Design Document Rules

- Every design document MUST contain these 8 sections: Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria
- Formulas must include variable definitions, expected value ranges, and example calculations
- Edge cases must explicitly state what happens, not just "handle gracefully"
- Dependencies must be bidirectional — if system A depends on B, B's doc must mention A
- Tuning knobs must specify safe ranges and what gameplay aspect they affect
- Acceptance criteria must be testable — a QA tester must be able to verify pass/fail
- No hand-waving: "the system should feel good" is not a valid specification
- Balance values must link to their source formula or rationale
- Design documents MUST be written incrementally: create skeleton first, then fill
  each section one at a time with user approval between sections. Write each
  approved section to the file immediately to persist decisions and manage context

## systems-index.md Status Column Format

The Status column in `design/gdd/systems-index.md` MUST use this format only:

  `<enum> · <YYYY-MM-DD>` (canonical)
  `<enum> · <YYYY-MM-DD> · <short modifier>` (when enum alone is ambiguous)

### Allowed enum values (6)

- `Not Started`
- `In Design`
- `Designed`
- `Needs Revision`
- `Approved`
- `LOCKED`

### Allowed short modifiers (≤30 chars, no narrative)

- `pending re-review`
- `for prototype`
- `RR<N> PASS` (re-review pass count, e.g. `RR7 PASS`)

### Format rules

- Single line per row. Status cell ≤ 150 chars.
- Use `·` (middle dot U+00B7) as separator, NOT `|` (would break markdown table).
- Date is ISO 8601 (`YYYY-MM-DD`).
- NO parentheses, NO "Previously:" chains, NO BLOCKING counts in Status column.
- NO multi-line content.
- ALL narrative — verdicts, blocker descriptions, reviewer notes, cross-doc effects — belongs in `design/gdd/reviews/<system>-review-log.md`.

### Examples (allowed)

- `Approved · 2026-05-11`
- `Designed · 2026-05-12 · pending re-review`
- `LOCKED · 2026-05-10 · for prototype`
- `Approved · 2026-05-11 · RR7 PASS`
- `Needs Revision · 2026-05-12`

### Examples (forbidden — write to review-log instead)

- `**Approved (re-review APPROVED 2026-05-11 lean mode)** — confirmed all 22 prior BLOCKING items ...`
- `Approved (Round 5 W4 fix applied inline; Round 6 housekeeping deferred)`
- `Designed (pending re-review) (Session 19 — Re-review #6 same-day NEEDS REVISION → 4 inline fixes applied; status still pending...)`
- `NEEDS REVISION · 2026-05-12 · BLOCKING #1/#2/#3 applied — pending fresh-session re-review` (modifier exceeds 30 chars + contains narrative; truncate to `Needs Revision · 2026-05-12`)

### Last Updated Header Format

The `> **Last Updated**:` line at the top of `design/gdd/systems-index.md` MUST be single-line:

  `> **Last Updated**: YYYY-MM-DD — see design/gdd/reviews/ for full history.`

NO cumulative narrative. Per-system history lives in `design/gdd/reviews/<system>-review-log.md`.
Cross-review history lives in `design/gdd/gdd-cross-review-<date>.md`.

### Skill enforcement

- `/design-review` Phase 5 systems-index update widget MUST write enum-only Status. Narrative goes to the review-log widget (separate widget) only.
- `/review-all-gdds` Phase 6 systems-index update writes `Needs Revision` exact-string (already enforced — do not append parentheticals; see line 555 of `.claude/skills/review-all-gdds/SKILL.md`).
- `/map-systems` writes initial enum (`Not Started` / `In Design` / `Designed`); no narrative.
- Manual edits violating this format will be cleaned by next review cycle or by `tools/ci/systems_index_bloat_check.sh` audit.

### CI audit

`tools/ci/systems_index_bloat_check.sh` validates:
- File total bytes ≤ 25 KB (warn) / ≤ 40 KB (fail)
- Last Updated header ≤ 150 chars
- Status cell max ≤ 300 chars (warn) / ≤ 500 chars (fail)
- Narrative leakage pattern count ≤ 5 (warn) / ≤ 10 (fail)
