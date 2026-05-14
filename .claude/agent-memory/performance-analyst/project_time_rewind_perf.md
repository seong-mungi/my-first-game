---
name: Time Rewind GDD Perf Review
description: Performance risks identified in design/gdd/time-rewind.md during May 2026 review — GDScript estimate gaps, shader batching risk, missing hardware baseline
type: project
---

Reviewed 2026-05-09. Key risks for future reference:

1. D6 `t_field_copy ≈ 6 ns` is a native C++ figure. GDScript field write to Resource is 100-500 ns. Capture estimate is 20-80x optimistic, though total capture stays well under 1 ms cap.
2. `t_anim_seek ≈ 200 μs` has no citation or hardware baseline. With 7+ animation tracks, Steam Deck real cost may be 400-600 μs. Restore budget may be tight.
3. Shader (≤500 μs) + restore (200-500 μs) together = 700-1000 μs against a 1 ms cap. No margin documented.
4. CanvasLayer for ECHO+bullets above post-process breaks batching. With 50+ bullets as individual nodes, draw call ceiling (500) is at risk during rewind.
5. No hardware disclaimer — all estimates appear to be dev-machine figures, not Steam Deck figures.
6. Signal cascade (4 signals × ~4 subscribers per restore) not included in D6 formula. Adds ~16-160 μs to restore cost.
7. `Label.text` allocation in HUD on every token signal emit — diff-check required but only indirectly tested.
8. No perf gate on PlayerSnapshot field additions (F6 ammo_count risk).

**Why:** These gaps were found during the first formal perf review of time-rewind.md. They are not blocking but need measurement before Tier 2 implementation.

**How to apply:** When time-rewind enters implementation, require Steam Deck benchmark numbers for seek cost before approving D6. Flag any field added to PlayerSnapshot as requiring perf re-validation.
