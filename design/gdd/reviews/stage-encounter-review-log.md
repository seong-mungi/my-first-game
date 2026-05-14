# Stage / Encounter Review Log

## Review — 2026-05-13 — Verdict: APPROVED

Scope signal: L
Specialists: lean mode — none spawned
Blocking items: 0 | Recommended: 3
Summary: First lean review found the Stage / Encounter GDD structurally complete, implementable, and aligned with Echo's deterministic retry pillars. The design cleanly separates Scene Manager lifecycle, Enemy AI behavior, Damage hit authority, Camera limit delivery, and Stage-owned encounter orchestration; Boss Pattern #11 remains an explicit provisional dependency rather than a Stage blocker.
Prior verdict resolved: First review

### Completeness

- 8/8 required sections present: Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria.
- Visual/Audio Requirements and Open Questions are present.
- No `[To be designed]` placeholders found during review.

### Dependency Graph

- ✓ `scene-manager.md` — exists and already owns scene lifecycle plus `scene_post_loaded(anchor, limits)`.
- ✓ `enemy-ai.md` — exists and mirrors the Stage-provided spawn metadata / Area2D preflight contract.
- ✓ `damage.md` — exists and locks Damage-owned hit interpretation plus the `area2d_max_active = 80` constraint.
- ✓ `camera.md` — exists and receives Stage-authored limits through Scene Manager, not through direct Stage calls.
- ✓ `../../docs/architecture/adr-0003-determinism-strategy.md` — exists and supports physics-frame deterministic activation.
- ⚠ Boss Pattern #11 — GDD not started yet; acceptable for Stage approval because Stage only defines placement/final-gate handoff and marks production stage-clear proof blocked until Boss Pattern owns `boss_killed`.

### Required Before Implementation

None.

### Recommended Revisions

1. Clarify in Rule 13 / C.4 / AC-STG-02 that Scene Manager performs the pre-emit `stage_camera_limits` assert from Stage-authored data, while Stage validation gates encounter arming after POST-LOAD.
2. Tighten E.2 so multiple active checkpoint anchors are a production preflight failure; first-anchor registration should be diagnostic/fallback behavior only, not a valid Tier 1 content state.
3. Clarify that D.5 `other_damage_area2d_count` uses declared maximum/cap counts for preflight, not observed runtime active counts.

### Specialist Disagreements

None — lean mode skipped specialist delegation.

### Nice-to-Have

- When Boss Pattern #11 is authored, mirror the STRIDER final-gate contract back into both GDDs.
- During architecture, name the concrete StageDefinition / EncounterDefinition resource classes and exported property names.

### Senior Verdict

Approved for implementation planning. The GDD is multi-system and moderately high integration risk, but its boundaries are explicit and its provisional Boss Pattern dependency is contained by AC-STG-26.

### Scope Signal

Rough scope signal: L — multi-system integration touching Scene Manager, Enemy AI, Damage, Camera, determinism, and future Boss Pattern handoff.

### Verdict

APPROVED
