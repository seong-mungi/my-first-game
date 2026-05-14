---
name: Pillar 2 and Audio Presentation Boundary
description: Pillar 2 determinism governs simulation state only — audio is presentation layer and pitch jitter does not violate it
type: feedback
---

Pillar 2 ("운은 적이다" — determinism) governs gameplay simulation state: projectile positions, damage outcomes, PlayerSnapshot equality, enemy AI determinism. Audio is presentation layer only and does not feed back into the simulation.

**Why:** This distinction prevents future implementers from removing pitch variation (a psychoacoustic necessity at 6 rps) for the wrong reason. The GDD must state this explicitly.

**How to apply:** When any audio feature involves randomness or variation (pitch jitter, volume variation, random SFX selection), do not flag it as a Pillar 2 violation. Pillar 2 only constrains the simulation layer. However, still prefer deterministic sources (frame-number hash tables) over randf() in the audio path so that integration test evidence remains replay-identical.
