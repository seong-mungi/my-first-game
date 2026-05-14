---
name: Echo Performance Budgets
description: Official per-category frame and memory budgets for Echo (from technical-preferences.md)
type: project
---

Frame budget: 16.6 ms total at 60 fps locked.
Split: gameplay+physics 6 ms / rendering 7 ms / time-rewind subsystem ≤1 ms / headroom 2.6 ms.
Draw calls: ≤500/frame.
Memory ceiling: 1.5 GB resident.
Target hardware: Steam Deck (Zen 2, RDNA 2 mobile — slower than typical dev machine by ~2-3x on CPU-bound tasks).

**Why:** Steam Deck is the verified shipping target. All perf claims must be validated against Deck hardware, not dev machines.

**How to apply:** Flag any estimate not benchmarked on Steam Deck. The 1 ms TRC cap is a hard contract shared across capture + restore + shader — treat it as indivisible until a sub-allocation is explicitly documented.
