# Systems Index: Echo

> **Status**: Draft (v0)
> **Created**: 2026-05-09
> **Last Updated**: 2026-05-13 — see design/gdd/reviews/ for full history.
> **Source Concept**: design/gdd/game-concept.md
> **Visual Bible**: design/art/art-bible.md
> **Engine**: Godot 4.6 / GDScript
> **Director Gate**: TD-SYSTEM-BOUNDARY / PR-SCOPE / CD-SYSTEMS — SKIPPED (Lean mode)

---

## Overview

Echo is a solo-developed PC game built around a side-scrolling 2D run-and-gun + time rewind token mechanic as its core. It is decomposed into 24 systems, of which 18 must be functional in the Tier 1 MVP. The core mechanic (time rewind) carries the highest technical and design risk, so 3 ADRs (R-T1/R-T2/R-T3) must be resolved before any GDD authoring begins. The collage rendering pipeline is the second risk area — it must balance the visual signature (Pillar 3 marketing asset) against the memory ceiling (1.5 GB).

The core loop — Move → Spot enemy → Shoot → (Dodge OR Time Rewind) → Survive — can only be validated when all 8 Core systems (Player Movement, Player Shooting, Damage, Time Rewind, Enemy AI, Boss Pattern, Stage/Encounter, State Machine) are operational.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|---|---|---|---|---|---|
| 1 | Input System | Core | MVP | Approved · 2026-05-11 | [input.md](input.md) · [reviews/input-review-log.md](reviews/input-review-log.md) | — |
| 2 | Scene / Stage Manager | Core | MVP | Needs Revision · 2026-05-13 | [scene-manager.md](scene-manager.md) · [reviews/scene-manager-review-log.md](reviews/scene-manager-review-log.md) | — (Foundation — no upstream dependencies) |
| 3 | Camera System | Core | MVP | Needs Revision · 2026-05-13 | [camera.md](camera.md) · [reviews/camera-review-log.md](reviews/camera-review-log.md) | Scene Manager #2 (HARD — first-use of `scene_post_loaded(anchor, limits)` signal); Player Movement #6 (HARD — target.global_position); State Machine #5 (HARD — PlayerMovementSM state read); Damage #8 (HARD — player_hit_lethal, boss_killed signals); Time Rewind #9 (HARD — rewind_started, rewind_completed signals); Player Shooting #7 (SOFT — shot_fired micro-shake feedback); ADR-0003 (HARD — process_physics_priority=30 ladder slot); ADR-0002 (HARD — negative dep: Camera state NOT in PlayerSnapshot); art-bible.md (SOFT — Section 6 composition / readable third) |
| 4 | Audio System | Audio | MVP | Approved · 2026-05-12 | [audio.md](audio.md) | Scene Manager #2 (HARD — scene_will_change); State Machine #5 (HARD — play_rewind_denied direct call); Player Shooting #7 (HARD — shot_fired + play_ammo_empty); Damage #8 (HARD — boss_killed + player_hit_lethal); Time Rewind #9 (HARD — rewind_started + rewind_completed) |
| 5 | **State Machine Framework** | Core | MVP | Approved · 2026-05-10 | [state-machine.md](state-machine.md) · [reviews/state-machine-review-log.md](reviews/state-machine-review-log.md) | — (Foundation; signal consumers: Damage #8, Time Rewind #9, Scene #2, Input #1) |
| 6 | Player Movement | Gameplay | MVP | Approved · 2026-05-11 | [player-movement.md](player-movement.md) · [reviews/player-movement-review-log.md](reviews/player-movement-review-log.md) | Input #1, State Machine #5, Scene Manager #2, Player Shooting #7 (provisional cache), Damage #8 (hosting), Time Rewind #9 |
| 7 | Player Shooting / Weapon System | Gameplay | MVP | Approved · 2026-05-11 | [player-shooting.md](player-shooting.md) · [reviews/player-shooting-review-log.md](reviews/player-shooting-review-log.md) | Input #1, Player Movement #6, Damage #8 |
| 8 | Damage / Hit Detection | Gameplay | MVP | Needs Revision · 2026-05-13 | [damage.md](damage.md) · [reviews/damage-review-log.md](reviews/damage-review-log.md) | State Machine #5, Time Rewind #9, Player Movement #6, Player Shooting #7, Enemy AI #10, Boss Pattern #11, Stage #12 |
| 9 | **Time Rewind System** ⚠️ | Gameplay | MVP | Approved · 2026-05-11 | [time-rewind.md](time-rewind.md) · [reviews/time-rewind-review-log.md](reviews/time-rewind-review-log.md) | Input, Scene Manager, State Machine, Player Movement, Damage |
| 10 | Enemy AI Base + Archetypes | Gameplay | MVP | Not Started | — | State Machine, Damage, Player Movement |
| 11 | Boss Pattern System | Gameplay | MVP | Not Started | — | Enemy AI, Damage, Time Rewind |
| 12 | Stage / Encounter System | Gameplay | MVP | Not Started | — | Scene Manager, Enemy AI |
| 13 | HUD System | UI | MVP | Not Started | — | Time Rewind, Player Shooting, Boss Pattern |
| 14 | VFX / Particle System | Presentation | MVP | Not Started | — | Damage, Time Rewind |
| 15 | Collage Rendering Pipeline ⚠️ | Presentation | MVP | Not Started | — | Scene Manager |
| 16 | Time Rewind Visual Shader ⚠️ | Presentation | MVP | Not Started | — | VFX, Time Rewind, Collage Rendering |
| 17 | Story Intro Text System (inferred) | Narrative | MVP | Not Started | — | Scene Manager |
| 18 | Menu / Pause System (inferred) | UI | MVP | Not Started | — | Input, Scene, Audio |
| 19 | Pickup System | Gameplay | Vertical Slice | Not Started | — | Player Shooting, Stage |
| 20 | Difficulty Toggle System (Easy/Hard) | Meta | Vertical Slice | Not Started | — | Time Rewind, Player Movement |
| 21 | Save / Settings Persistence (inferred) | Persistence | Vertical Slice | Not Started | — | Menu, Scene |
| 22 | Localization System | Meta | Full Vision | Not Started | — | HUD, Menu (Anti-Pillar #6 deferred) |
| 23 | Input Remapping | Meta | Full Vision | Not Started | — | Input, Menu (Anti-Pillar #6 deferred) |
| 24 | Accessibility Options | Meta | Full Vision | Not Started | — | Menu, HUD |

⚠️ mark: High-risk system. See High-Risk Systems section below.

---

## Categories

| Category | Description | Systems in Echo |
|---|---|---|
| **Core** | Foundation systems that everything depends on | Input, Scene Manager, Camera, State Machine |
| **Gameplay** | Systems that create the core fun | Player Movement, Player Shooting, Damage, Time Rewind, Enemy AI, Boss Pattern, Stage/Encounter, Pickup |
| **Persistence** | Save / progress state | Save / Settings Persistence (Tier 2+) |
| **UI** | Player information display | HUD, Menu / Pause |
| **Audio** | Sound · music | Audio System (Tier 1 placeholder, Tier 3 outsourced) |
| **Narrative** | Story delivery | Story Intro Text System (Anti-Pillar no cutscenes — text only) |
| **Presentation** | Visuals · effects | VFX / Particle, Collage Rendering, Time Rewind Visual Shader |
| **Meta** | Systems outside the core | Difficulty Toggle, Localization, Input Remapping, Accessibility |

Progress / economy categories are not used in Echo — determinism + no metered progression (Pillar 2).

---

## Priority Tiers

| Tier | Definition | Echo Mapping | System Count |
|---|---|---|---|
| **MVP** | Systems that must be operational in Tier 1 Prototype (4–6 weeks) | 1 stage slice + time rewind token + 1 boss + 1 weapon | 18 |
| **Vertical Slice** | Tier 2 MVP 6-month cumulative: 3 stages + Easy toggle | Pickup + Difficulty + Persistence | 3 |
| **Full Vision** | Tier 3 launch 16-month cumulative | Localization + Remapping + Accessibility | 3 |

---

## Dependency Map

### Foundation Layer (0 dependencies)

1. **Input System** — KB+M / Gamepad mapping, 8-direction + action buttons. All gameplay depends on this.
2. **Scene / Stage Manager** — scene load/unload, checkpoint anchor, restart logic. Directly manages memory ceiling (1.5 GB).
3. **State Machine Framework** — common pattern for Player · Enemy · Boss state representation. GDScript pattern + class base.
4. **Audio System** — SFX/BGM buses, ducking, CC0 placeholder support. Tier 1 is stub-level.

### Core Layer (depends on Foundation)

5. **Camera System** — side-scrolling follow, screenshake hook, boss zoom. depends: Scene Manager
6. **Player Movement** — run/jump/fall, one-hit death, respawn handling. depends: Input, State Machine, Scene
7. **Damage / Hit Detection** — bullet vs entity, one-hit rule, hitbox layers. depends: State Machine, Scene
8. **Time Rewind System** ⚠️ — state snapshot ring buffer, token consumption, restore trigger. depends: Player Movement, State Machine, Damage. **R-T1/R-T2/R-T3 ADR prerequisite required.**

### Feature Layer (depends on Core)

9. **Player Shooting / Weapon System** — 8-direction aim, projectile spawn, weapon swap. depends: Input, Player Movement, Damage
10. **Enemy AI Base + Archetypes** — common enemy controller + Drone/Security Bot/STRIDER subclasses. depends: State Machine, Damage, Player Movement
11. **Boss Pattern System** — multi-phase script, telegraph, HP gating, REWIND token reward. depends: Enemy AI, Damage, Time Rewind
12. **Stage / Encounter System** — per-room triggers, checkpoints. depends: Scene Manager, Enemy AI
13. **Pickup System** (Tier 2) — weapon pickups + items. depends: Player Shooting, Stage

### Presentation Layer (depends on Feature)

14. **HUD System** — REWIND token counter, weapon icon, boss HP bar. depends: Time Rewind, Player Shooting, Boss Pattern
15. **VFX / Particle System** — bullet impact, death flash, REWIND glitch. depends: Damage, Time Rewind
16. **Collage Rendering Pipeline** ⚠️ — 3-layer collage compositing (photo + line + cutout). depends: Scene Manager
17. **Time Rewind Visual Shader** ⚠️ — color inversion + glitch UV. depends: VFX, Time Rewind, Collage Rendering
18. **Story Intro Text System** — 5-line typewriter intro. depends: Scene Manager
19. **Menu / Pause System** — main menu, pause, options. depends: Input, Scene, Audio

### Polish Layer (Tier 2–3)

20. **Difficulty Toggle System** — Easy toggle (unlimited tokens) / Hard (token 0). depends: Time Rewind, Player Movement
21. **Save / Settings Persistence** — options file, progress flags. depends: Menu, Scene
22. **Localization System** (Tier 3) — depends: HUD, Menu. Anti-Pillar #6 — deferred until Tier 3 launch.
23. **Input Remapping** (Tier 3) — depends: Input, Menu. Anti-Pillar #6 deferred.
24. **Accessibility Options** (Tier 3) — depends: Menu, HUD

---

## Circular Dependencies

| Cycle | Analysis | Resolution |
|---|---|---|
| Time Rewind ↔ Boss Pattern | Boss Pattern depends on Time Rewind token reward / Time Rewind does NOT depend on Boss Pattern HP gating signal (one-way) | **Not a cycle** — Boss → Time Rewind one-way notification (signal) pattern |
| HUD ↔ Time Rewind | HUD reads token count / Time Rewind does NOT call HUD directly | **Not a cycle** — Observer pattern (Time Rewind emits signal, HUD subscribes) |

No true cycles. All dependencies are one-directional and decoupled via signals/events.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|---|---|---|---|
| **Time Rewind System** | Technical + Design | Time rewind pattern unverified in Godot 4.6 (snapshot vs input replay). May over-relieve the catharsis of one-hit death and lose core fun. | (1) **R-T1/R-T2/R-T3 ADR 3 prerequisites** — scope (Player vs Braid), storage method (snapshot vs replay), determinism strategy. (2) Tier 1 Week 1 standalone prototype validation. Change the differentiating mechanic if it's not fun. |
| **Collage Rendering Pipeline** | Technical | Uncertain whether a 3-layer compositing pipeline can operate within 60fps + 500 draw calls + 1.5 GB memory constraints. Tier 3 with 5 simultaneous stage collage photo textures = 300 MB memory pressure. | (1) Validate full collage with 1 scene only in Tier 1. (2) Write ADR for explicit texture release on stage transition before entering Tier 2. (3) Hard cap of ≤30 collage pieces per stage. |
| **Time Rewind Visual Shader** | Technical | Impact of Godot 4.6 glow rework (4.5→4.6), unverified shader compatibility on D3D12 default Windows. Unknown performance when composited with collage layers. | Tier 1 Week 2–3 standalone shader test scene validation. Simplify effects if 60fps cannot be maintained. |
| **Boss Pattern System** | Design | Designing 5–6 deterministic multi-phase boss patterns as a solo developer — workload explosion risk. Tier 3 feasibility in question. | Validate pattern design tooling and workload with 1 STRIDER in Tier 1. Measure actual workload before deciding 4 or 5–6 bosses for Tier 3. |

---

## Recommended Design Order

**Principle**: Solo development + 16-month budget → *risk-first* design. Do not write Foundation first; prioritize R-T1/T2/T3 ADRs before all GDDs. After ADRs pass, write Time Rewind GDD first, then follow remaining Foundation/Core systems in dependency order.

| Order | System | Priority | Layer | Agent | Est. Effort | Notes |
|---|---|---|---|---|---|---|
| **0a** | ADR R-T1 (Time Rewind scope) | — | — | godot-specialist + game-designer | S | Player-only vs Braid model |
| **0b** | ADR R-T2 (storage method) | — | — | godot-specialist + lead-programmer | S | Snapshot vs input replay |
| **0c** | ADR R-T3 (determinism strategy) | — | — | godot-specialist | S | CharacterBody2D + direct transform |
| 1 | Time Rewind System | MVP | Core | game-designer + godot-gdscript-specialist | L | After 0a/0b/0c all pass |
| 2 | State Machine Framework | MVP | Foundation | godot-gdscript-specialist | S | Can parallel with 2–7 |
| 3 | Input System | MVP | Foundation | game-designer | S | Can parallel |
| 4 | Scene / Stage Manager | MVP | Foundation | godot-specialist | M | Can parallel |
| 5 | Camera System | MVP | Core | godot-specialist | S | Can parallel |
| 6 | Audio System | MVP | Foundation | sound-designer | S | Tier 1 stub-level |
| 7 | Damage / Hit Detection | MVP | Core | game-designer | M | One-hit death rule |
| 8 | Player Movement | MVP | Core | game-designer | M | depends: 2, 3, 4, 7 |
| 9 | Player Shooting | MVP | Feature | game-designer | M | depends: 8 |
| 10 | Enemy AI Base + 3 Archetypes | MVP | Feature | ai-programmer | L | depends: 2, 7, 8 |
| 11 | Boss Pattern System | MVP | Feature | game-designer + ai-programmer | L | depends: 1, 10 |
| 12 | Stage / Encounter System | MVP | Feature | level-designer | M | depends: 4, 10 |
| 13 | Collage Rendering Pipeline | MVP | Presentation | godot-shader-specialist + technical-artist | L | depends: 4. Follow art-bible ch.8 memory budget |
| 14 | Time Rewind Visual Shader | MVP | Presentation | godot-shader-specialist | M | depends: 1, 13 |
| 15 | VFX / Particle System | MVP | Presentation | technical-artist | M | depends: 7, 1 |
| 16 | HUD System | MVP | Presentation | game-designer + ux-designer | M | depends: 1, 9, 11 |
| 17 | Story Intro Text System | MVP | Presentation | writer + ux-designer | S | 5-line intro only |
| 18 | Menu / Pause System | MVP | Presentation | ux-designer | M | depends: 3, 4, 6 |
| 19 | Pickup System | Vertical Slice | Feature | game-designer | S | Tier 2 |
| 20 | Difficulty Toggle | Vertical Slice | Meta | game-designer | S | Tier 2 |
| 21 | Save / Settings Persistence | Vertical Slice | Persistence | gameplay-programmer | S | Tier 2 |
| 22 | Localization System | Full Vision | Meta | localization-lead | M | Tier 3 |
| 23 | Input Remapping | Full Vision | Meta | ux-designer + ui-programmer | M | Tier 3 |
| 24 | Accessibility Options | Full Vision | Meta | accessibility-specialist | M | Tier 3 |

**Effort key**: S = 1-session GDD / M = 2–3 sessions / L = 4+ sessions. Solo developer 1 session ≈ 2–3 hours of design conversation.

---

## Progress Tracker

| Metric | Count |
|---|---|
| Total systems identified | 24 |
| MVP systems | 18 |
| Vertical Slice systems | 3 |
| Full Vision systems | 3 |
| Design docs started | 9 |
| Design docs reviewed (Round 1 design-review applied at least once) | 3 |
| Design docs approved (re-review passed or LOCKED for prototype) | 6 |
| Design docs Needs Revision (post /review-all-gdds 2026-05-13) | 3 |
| Design docs Designed (pending re-review after Round 1 BLOCKING applied) | 0 |
| Deferred non-blocking warnings | 0 |
| ADRs queued (R-T1/T2/T3) | 3 |
| ADRs approved | 3 (R-T1 → ADR-0001, R-T2 → ADR-0002 with Amendment 1, R-T3 → ADR-0003) |

---

## Open Issues

> [!resolved] R-T1/R-T2/R-T3 ADR prerequisites (resolved 2026-05-09)
> All 3 ADRs Accepted (R-T1 ADR-0001, R-T2 ADR-0002 with Amendment 1, R-T3 ADR-0003). Time Rewind System GDD written and in Designed status. Recommend fresh-session `/design-review design/gdd/time-rewind.md` for verification.

> [!gap] Font license (Tier 3 gate)
> Korean font (Noto Sans KR vs officially licensed) decision deferred until just before Tier 3 launch. Tier 1/2 use Noto Sans KR by default.

> [!gap] Collage photo source (Q2)
> Stock vs AI-generated vs self-photographed — decide at `/asset-spec` or first concept art round for IP/license comparison.

---

## Next Steps

### Completed (Sessions 5–22)

- [x] `/architecture-decision R-T1` — Time Rewind scope: **Player-only** (ADR-0001 Accepted 2026-05-09)
- [x] `/architecture-decision R-T2` — storage method: **State Snapshot ring buffer** (ADR-0002 Accepted 2026-05-09; **Amendment 2 Accepted 2026-05-11** via Player Shooting #7 ratification)
- [x] `/architecture-decision R-T3` — determinism strategy (ADR-0003 Accepted 2026-05-09; CharacterBody2D + direct transform + `process_physics_priority` ladder)
- [x] `/design-system input` (#1) — Approved
- [x] `/design-system scene-manager` (#2) — Approved (RR7 PASS 2026-05-11)
- [x] `/design-system state-machine` (#5) — Approved
- [x] `/design-system player-movement` (#6) — Approved
- [x] `/design-system player-shooting` (#7) — Approved (Round 2; closed ADR-0002 Amendment 2 ratification gate)
- [x] `/design-system damage` (#8) — LOCKED for prototype
- [x] `/design-system time-rewind` (#9) — Approved
- [x] `/design-system camera` (#3) — NEEDS REVISION (Session 22 2026-05-12; BLOCKING #1/#2/#3 applied in same session per inline-fix-then-reverify workflow; pending fresh-session re-review)
- [x] `/design-review design/gdd/camera.md --depth lean` (Session 22 2026-05-12) — NEEDS REVISION verdict; 3 BLOCKING resolved inline (R-C1-1 split H/V, F-CAM-3 numerics, `_compute_initial_look_offset` spec); review log written

### Queued — Next GDD Authoring (sorted by unblocking value)

- [ ] `/design-review design/gdd/camera.md --depth lean` (fresh session — RE-REVIEW) — Verify BLOCKING #1/#2/#3 resolutions; promote Needs Revision → Designed → Approved on PASS
- [ ] `/architecture-review` — Validate cross-ADR consistency post-Amendment-2-Accepted (Effort S read-only sweep)
- [ ] `/design-system audio` (#4) — Audio. Depends on Scene Manager #2. Tier 1 stub-level. Effort S
- [ ] `/design-system stage-encounter` (#12) — Feature. Depends on Scene Manager #2 + Enemy AI #10. Effort M
- [ ] `/design-system enemy-ai` (#10) + 3 archetypes — Feature. Depends on State Machine + Damage + Player Movement. Effort L
- [ ] `/design-system hud` (#13) — UI. Depends on Time Rewind + Player Shooting + Boss Pattern. Closes TR D1 silent cap-overflow contract gap obligation. Effort M
- [ ] `/design-system boss-pattern` (#11) — Feature. Depends on Enemy AI + Damage + Time Rewind. Effort L

### Gates & Reviews

- [ ] `/design-review` each GDD after authoring (fresh session — never run in authoring session)
- [ ] `/review-all-gdds` after all MVP 18 GDDs are at least in Designed status — holistic cross-doc consistency + game design theory review
- [ ] `/gate-check pre-production` — after all MVP 18 GDDs Approved + 18 cross-system reciprocal batches landed

### Prototype & Tier 1 Playtest

- [ ] `/prototype time-rewind` — Tier 1 Week 1 validation (now unblocked — Scene Manager #2 + Player Shooting #7 both Approved)
- [ ] Tier 1 Steam Deck 1st-gen device session — S1 AimLock facing-strobe drift ±0.18 perceptibility test (Pillar 3 visual signature)
- [ ] Tier 1 playtest D1 review — AimLock-turret candidate dominant strategy (after Enemy AI #10 / Boss #11 / Stage #12 GDDs land)

### Outstanding Open Questions (deferred to later sessions)

- [ ] **D1** AimLock-turret dominant strategy → Tier 1 playtest after Enemy AI #10 / Boss #11 / Stage #12
- [ ] **S1** AimLock facing-strobe Steam Deck drift → creative call: (a) raise `FACING_THRESHOLD_AIM_LOCK` to ≥0.20 with hysteresis exit ≥0.15, or (b) INV-9 enforcing `FACING_THRESHOLD_AIM_LOCK > documented_steam_deck_drift_floor`. Defer to first Steam Deck Tier 1 device session.
