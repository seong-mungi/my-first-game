# Damage / Hit Detection System

> **System**: #8 Damage / Hit Detection
> **Category**: Core / Gameplay
> **Priority**: MVP (Tier 1)
> **Status**: **LOCKED for prototype** (Round 4 review 2026-05-09 — 3 BLOCKING surgical fixes applied: BLOCK-R4-1 AC-21 regex broadening (state_machine.* all access + get_node alias paths included), BLOCK-R4-2 AC-29 hardcoded fixture baseline (run-1 self-capture forbidden), **B-R4-1 (systems-designer post-lock) DEC-6 hazard grace off-by-one** (`_hazard_grace_remaining` initial value `hazard_grace_frames + 1` — compensates same-frame priority-2 decrement; guarantees 12 flush windows; AC-24 updated). Round 3 review 2026-05-09: 4 BLOCKING applied. Round 2 review 2026-05-09: 8 BLOCKING / 12 RECOMMENDED applied. creative-director Round 4 verdict: **LOCK & PROTOTYPE** — Round 5 blocked, additional findings recorded in review-log only as post-lock observations. 3 new ADRs queued: OQ-DMG-8/9, ADR-0003 priority ladder update.)
> **Author**: game-designer + godot-gdscript-specialist
> **Created**: 2026-05-09
> **Engine**: Godot 4.6 / GDScript (statically typed)
> **Depends On**: Player Movement #6 (Approved 2026-05-11) + Player Shooting #7 *(provisional)* + Enemy AI #10 *(provisional)* + Boss Pattern #11 *(provisional)* + Stage #12 *(provisional)* — HitBox/HurtBox instantiation clients
> **Consumed By**: State Machine #5 (Approved — player_hit_lethal subscriber) + Time Rewind #9 (Approved — i-frame cooperation) + HUD #13 *(provisional)* — boss phase signal option

---

## Locked Scope Decisions (2026-05-09 user-approved)

- **DEC-1**: `player_hit_lethal(cause: StringName)` 1-arg signature. **OQ-SM-1 resolved**. cause taxonomy is solely owned by this GDD (D.3).
- **DEC-2**: Boss HP = **discrete phase thresholds** (`phase_hits_remaining: int` per phase). No UI HP bar (Anti-Pillar consistency). HUD consumes phase transition signals only.
- **DEC-3**: Standard enemy = **1-hit kill** (no hit-stun). Pillar 1-hit consistency. Tier 1 simplicity.
- **DEC-4**: i-frame control = **SM disables ECHO HurtBox.monitorable**. RewindingState.enter()/exit() controls ECHO HurtBox.monitorable. Damage system does not poll SM state (bypasses forbidden_pattern `cross_entity_sm_transition_call` + preserves unidirectional data flow). **2026-05-09 correction (round 2)**: 7 sites incorrectly recorded as `monitoring` in the draft + first correction (C.6.2, D.1.1 cond(2), D.4.1, D.4.2, D.4.3, D.4.4, AC-12, AC-20, AC-22) corrected en masse to `monitorable`. **Godot 4.6 Area2D semantics**: HitBox is the active scanner and `HitBox.area_entered` fires only when `HitBox.monitoring AND HurtBox.monitorable AND layer/mask AND shape_overlap`. Toggling HurtBox.monitoring does *not* suppress `HitBox.area_entered`, so the sole i-frame toggle is `HurtBox.monitorable` as the single source of truth.
- **DEC-5** (added 2026-05-09): `boss_hit_absorbed(boss_id, phase_index)` 2-arg. `hits_remaining` parameter removed. Protects B.1 "binary, not graded" data contract (specialist game-designer recommendation).
- **DEC-6** (added 2026-05-09): Hazard-only grace of 12 frames introduced immediately after REWINDING.exit(). For 12 frames (~200 ms) after monitorable=true is restored, only hazard causes (L5) are blocked. Enemy projectiles (L4) are accepted normally. SM's RewindingState.exit() calls Damage `start_hazard_grace()` → Damage owns `_hazard_grace_remaining: int = 12` counter. In `hurtbox_hit(cause)` handler, if `cause` is a hazard type and counter > 0, return immediately. Resolves E.13 Pillar 1 violation (creative-director recommendation).

---

## A. Overview

> **Status**: Approved 2026-05-09.

The Damage system is the hit-detection core that makes a single authoritative determination of *which entity delivered a lethal hit to which entity* and propagates that fact as a signal. In Echo's 1-hit-kill design (Pillar Challenge primary), this system defines damage not as *numeric calculation* but as a *binary event (hit or no-hit)*. ECHO, standard enemies, and hazards are all resolved by a single projectile hit, while only the boss expresses multi-stage defeat through *discrete phase thresholds* (DEC-2) — a UI HP bar is intentionally absent. For ECHO only, this system enforces the 2-stage separation imposed by the Time Rewind system (Rule 4), hosting the decision-delay window of `lethal_hit_detected → 12-frame grace → death_committed`. All hit notifications are unified into the `player_hit_lethal(cause: StringName)` (DEC-1) 1-arg signal, and the `cause` taxonomy (D.3) is solely owned by this GDD. The REWINDING 30-frame i-frame is not *directly perceived* by the Damage system — by the State Machine disabling ECHO HurtBox.monitorable (DEC-4), Damage simply emits collision signals unidirectionally. Though not a Foundation system, it *provides* HitBox/HurtBox components to 4 entity hosts (#6/#7/#10/#11/#12) and *propagates* binary events to 5 signal consumers (#5/#9/#13/#14/#4).

**Core Positioning**:

- **Binary, not graded** — Every hit is an instant-kill event. Damage *values* exist only in boss phase counters. `boss_hit_absorbed` signature is 2-arg (`boss_id`, `phase_index`) — architectural protection of binary data contract by withholding `hits_remaining` (DEC-5).
- **Threat Symmetry, recovery asymmetry** — damage model is symmetric (ECHO/enemies both 1-hit). Recovery layer is intentionally asymmetric (ECHO only: grace + rewind; enemies: instant death; boss only: phase). Stated explicitly to prevent downstream designer confusion (B.2).
- **Single signal contract** — 9 signals (`lethal_hit_detected`/`player_hit_lethal`/`death_committed`/`hurtbox_hit`/`enemy_killed`/`boss_hit_absorbed`/`boss_pattern_interrupted`/`boss_phase_advanced`/`boss_killed`). Emit order is a deterministic contract (F.4.1).
- **No HP bar** — No enemy or ECHO HP UI. Boss shows only phase transition (HUD GDD decision).
- **i-frame is SM's responsibility + DEC-6 hazard grace** — Damage does not query SM state. SM performs the single `HurtBox.monitorable` toggle (DEC-4). 12-frame hazard-only grace added immediately after REWINDING.exit() (DEC-6 — Pillar 1 protection).
- **2-stage is ECHO-only** — Standard enemies/boss resolve immediately. The 12-frame grace is the preservation mechanism for ECHO 1-hit catharsis.
- **Solo budget protection** — 9 signals + 3 invocation APIs (`commit_death`/`cancel_pending_death`/`start_hazard_grace`) — VFX/Audio/HUD mapping synchronization obligation (C.5.3).

---

## B. Player Fantasy

> **Status**: Approved 2026-05-09.

### B.1 Core Fantasy

**"You die in one hit, but you might *not* die in one hit."**

Echo's damage system promises the player **binary clarity**. At any moment only two states exist: "was I hit or not." There is no need to glance at an HP gauge to calculate remaining damage, or mentally track an enemy's cumulative hit count. All cognitive resources in combat are concentrated solely on *reading enemy bullet patterns*.

This clarity creates *fear*. The fact that one bullet means death makes every enemy projectile a *real threat* — the source of the "fair but brutal" tension that Pillar Challenge promises. However, the 12-frame grace window imposed by the Time Rewind system (Rule 4) transforms this fear into a *learning tool*: the brief quiet moment just after death — "why did I die?" — becomes the cost of the recovery decision. The Damage system honestly separates and emits the start of that grace (`lethal_hit_detected`) and its endpoint (`death_committed`), placing the *weight of the decision* in the player's hands.

### B.2 Threat Symmetry (explicit asymmetry included)

In Echo's world, **the damage model is symmetric, but the recovery layer is intentionally asymmetric**. ECHO's one shot kills a standard enemy — an enemy's one shot kills ECHO (DEC-3). There is no asymmetry of power in damage itself.

**However, recovery asymmetry is an intentional core mechanic**:
- ECHO only: 12-frame grace window (C.3) + Time Rewind tokens (Pillar 1)
- Standard enemies: 1-hit kill + immediate `queue_free` (DEC-3)
- Boss only: phase threshold (DEC-2) — no UI (Anti-Pillar)

This asymmetry is not a *violation of fairness* but *the core mechanic itself*. ECHO being able to rewind time is consistent with the game's fictional premise (VEIL blind spot). Players feel *threat density symmetry* — "every 1-hit is a real threat" — and recovery at the cost of a token is the *price paid* for that threat — not a free safety net.

**Important downstream obligation**: Subsequent level/enemy designers must assume the "attacker/victim same rule" only *at the damage model level*. Misinterpreting recovery asymmetry as a "fairness violation" and granting enemies grace/respawn as well will conflict with Pillar 1.

> **Previous name retired**: The previous name "Mirror Principle" risks misleading downstream designers by obscuring the recovery asymmetry. Renamed to "Threat Symmetry" with the asymmetry explicitly exposed.

### B.3 Cause-Aware Death

When a player dies, **"what killed me" must be immediately clear**. Was it a bullet, a spike, a pit, a boss AoE? This system attaches `cause: StringName` (DEC-1) to every lethal hit, so that VFX, SFX, and Time Rewind glitch signatures fire *differentiated feedback per cause*. An ambiguous death prevents learning — death without learning is frustration. This system's fantasy obligation is *to make every death traceable*.

### B.4 Boss as Erosion

If a standard enemy is *a glass*, the boss is *a wall*. Only the boss expresses multi-stage defeat through phase thresholds (DEC-2). However, **the HP bar is not exposed** (Anti-Pillar "Reveal Through Action" consistency). The player perceives the *moment the boss's weakness is revealed* through visual, audio, and pattern changes — a sudden change in stance, a new bullet curtain unfolds, a layer of the collage visual peels away. The world *changes* rather than numbers decreasing. The sensation of "one stage down" must come from *direction*, not data.

### B.5 Anti-Fantasy

| Rejected | Reason |
|---|---|
| **HP bar** (ECHO, standard enemies, boss all) | This is not a "health tracking game." Cognitive resources belong to pattern reading |
| **Enemy hit count** ("this enemy takes 3 hits") | Dilutes the clarity of 1-hit kill. Only the enemy's *bullet pattern* is a meaningful differentiator |
| **Damage number popup** ("12!") | RPG vocabulary. This game handles binary events only |
| **Ambiguous cause of death** (cause unknown) | Unlearnable death is frustration. Blocked by cause taxonomy |
| **i-frame flicker dependency** (Damage polling SM state) | Violates unidirectional data flow. SM handles it by disabling HurtBox.monitorable (DEC-4) |
| **Self-damage from own projectile** | Breaks self-consistency of shooting action. Guaranteed by collision_layer separation in F.1 |

> **Tier 3 explicit constraint (no armored variants)**: The "enemy hit count" rejection in B.5 is a *permanent lock through Tier 3*. For armored enemies/elite variants to appear by design, DEC-3 change + separate ADR + adding HURT state to Enemy AI GDD #10 + new AC in Damage GDD section H are all simultaneously required. *Do not attempt* introduction within Tier 3 — risk of solo budget erosion. Candidate for Tier 4 (post-launch DLC) review.

> **DEC-3 no hit-stun → VFX near-miss feedback obligation (game-designer recommendation)**: The risk of absent feedback for missed shots is compensated by VFX (#14) *mandatorily* providing *near-miss visual signatures* (puff/spark when a projectile passes close to an enemy/player). This obligation is registered as a Tier 1 Acceptance Criterion in VFX GDD #14. The Damage system itself does not *emit* near-miss information, but VFX can make its own proximity determination using single-source cause taxonomy + enemy projectile destroy timing (Player Shooting #7) data.

### B.6 Pillar Alignment Matrix

| Pillar | Damage System's Contribution |
|---|---|
| **Challenge — punishing but fair** | 1-hit kill + threat symmetry = foundation of punishing. cause clarity = foundation of fair. Recovery asymmetry (ECHO grace + rewind) is a *core mechanic* and the mechanical realization of the Pillar 1 learning tool (B.2) |
| **Time Rewind — defiant loop** | Hosts grace window via 2-stage separation (Rule 4 obligation) |
| **Reveal Through Action** | Boss phase transitions expressed through *direction only*. No HP UI |
| **Collage SF** | cause taxonomy is the differentiation basis for VFX/SFX → coupled with visual identity |
| **Solo-craftable Scope** | Binary model → prevents balancing table explosion (multiple damage values vs multiple HP matrix X) |

---

## C. Detailed Design

> **Status**: Approved 2026-05-09.

### C.1 HitBox / HurtBox Node Pattern (Damage system owned components)

This system *provides* two `Area2D`-based components. The host system (F.1) is obligated to attach these components as child nodes.

#### C.1.1 Component Definitions

| Component | Role | Base | `class_name` | Key Properties |
|---|---|---|---|---|
| `HitBox` | Offensive box that *deals* damage | `Area2D` | `class_name HitBox extends Area2D` | `cause: StringName` (per instance, default `&""`), `host: Node` (host explicitly sets at instantiation time, used in D.3.1 branching), `monitoring: bool` (**active scanner — always true by default**), `monitorable: bool` (unused, keep default true) |
| `HurtBox` | Defensive box that *receives* damage | `Area2D` | `class_name HurtBox extends Area2D` | `entity_id: StringName`, `monitorable: bool` (**i-frame toggle — DEC-4 single source**), `monitoring: bool` (HurtBox does not actively scan — always keep default true), `signal hurtbox_hit(cause: StringName)` |

> **Godot 4.6 Area2D semantics specification** (DEC-4 reinforcement): HitBox is the active scanner and HurtBox is the passive target. `HitBox.area_entered(area: Area2D)` is the single fire point, with firing condition `HitBox.monitoring AND HurtBox.monitorable AND layer/mask AND shape_overlap`. That is, **i-frames are blocked only by `HurtBox.monitorable=false`**, and toggling `HurtBox.monitoring` does not suppress `HitBox.area_entered` — all i-frame toggles in this GDD are unified to `HurtBox.monitorable`.

#### C.1.2 Signal Flow

The **single emit point for `hurtbox_hit` is the HitBox script**, and it is *not re-emitted from the Damage component or host handler*. (Round 3 lock-in — consistent with F.4.1 ECHO/Boss blocks.)

1. `HitBox.area_entered(area: Area2D)` fires (HitBox is the active scanner)
2. When `if area is HurtBox` guard passes (static type narrowing):
   - `(area as HurtBox).hurtbox_hit.emit(self.cause)` (propagates HitBox's cause label — instance call)
   - Same-frame ECHO self-damage blocked: pre-blocked by collision_layer/mask (C.2), no HitBox.cause verification needed
3. HurtBox host's (ECHO/enemy/boss) host script subscribes to `hurtbox_hit` for entity-specific handling (C.3–C.5)

> **`HitBox.cause` assignment responsibility (Round 3 clarification)**: `HitBox.cause` is **explicitly set by the host at instantiation time** (see F.1 Upstream Clients table). The cause branching table in D.3.1 is a *cause assignment obligation table that hosts must follow*, not a *runtime function*. The `self.cause` in C.1.2 step 2 simply propagates the value already set by the host — no additional branching logic.
>
> **Single emit verification**: The Damage component's `_on_hurtbox_hit(cause)` handler fires only `lethal_hit_detected` + `player_hit_lethal` and does *not re-emit* `hurtbox_hit` (AC-8 verification).

> **Signal connect order invariant**: `lethal_hit_detected` and `player_hit_lethal` fire at the *same emit moment* (C.3.1), but TRC must connect *before* SM — so that the `_lethal_hit_head` cache (frame N) executes before SM's ALIVE→DYING transition. This order is enforced by the *recorded code line order* in the host ECHO node's `_ready()`, and verified in AC-28.

#### C.1.3 Component Instantiation Responsibility (unidirectional)

- The host system (F.1 client) *manually instantiates* HitBox/HurtBox in its own .tscn. This GDD only provides *class definitions* for the components.
- This GDD does *not touch* the host's internal node tree — composition over inheritance.

---

### C.2 Collision Layer Matrix (Godot 4.6 collision_layer / collision_mask)

Godot 4.6's `Area2D.collision_layer` / `collision_mask` is 32-bit. This system occupies only 6 bits.

#### C.2.1 Layer Assignment (locked)

| Bit | Layer Name | Host |
|---|---|---|
| **1** | `echo_hurtbox` | ECHO body (#6) |
| **2** | `echo_projectile_hitbox` | Player projectile (#7) |
| **3** | `enemy_hurtbox` | Standard enemy (#10) |
| **4** | `enemy_projectile_hitbox` | Enemy projectile + boss projectile (#10/#11) |
| **5** | `hazard_hitbox` | Environmental hazard (#12) |
| **6** | `boss_hurtbox` | Boss (#11) — separated from standard enemy to isolate phase logic |

#### C.2.2 Mask Matrix (exhaustive)

| Component | layer | mask bits | Meaning |
|---|---|---|---|
| ECHO HurtBox | 1 | 4, 5 | Receives enemy projectiles + hazard only — ignores own projectiles |
| ECHO Projectile HitBox | 2 | 3, 6 | Hits standard enemies + boss only — ignores self and other ECHO projectiles |
| Enemy HurtBox | 3 | 2 | Receives player projectiles only |
| Enemy Projectile HitBox | 4 | 1 | Hits ECHO only — friendly fire blocked |
| Hazard HitBox | 5 | 1 | ECHO only — enemies unaffected by hazards (design simplification) |
| Boss HurtBox | 6 | 2 | Player projectiles only |

> **Self-damage blocked**: ECHO Projectile HitBox (L2) does not mask ECHO HurtBox (L1) → Godot collision engine preemptively blocks area_entered emit itself. No code guard needed.

> **Friendly-fire blocked**: Enemy projectiles (L4) do not mask other enemies (L3) → Tier 1 simplification. (Enemy vs enemy cooperative kills are validation targets for Tier 2 gate; current baseline is inactive.)

---

### C.3 ECHO 2-stage death (Time Rewind GDD Rule 4 hosting)

This sub-section is the *Damage-side implementation contract* that satisfies the obligations imposed by the Time Rewind GDD (Rule 4 + E-11).

#### C.3.1 Signal Contract (Damage system owned)

| Signal | Signature | Fire Moment | Consumers |
|---|---|---|---|
| `lethal_hit_detected` | `(cause: StringName)` | *Immediately after* ECHO HurtBox receives a hit (frame N) | TRC (`_lethal_hit_head` cache trigger) |
| `player_hit_lethal` | `(cause: StringName)` | *Same frame and same moment* as `lethal_hit_detected` | EchoLifecycleSM (DYING transition) |
| `death_committed` | `(cause: StringName)` | When grace window expires (frame N+12) | TRC (cleanup), HUD (death screen) |

> `lethal_hit_detected` and `player_hit_lethal` are semantically the same event but are maintained as *separate signals*. Reason: TRC must cache at exactly frame N (timing critical), and SM must pass through the latch guard (E-13 multi-hit defense), so separation of connect order and subscribers is necessary.

#### C.3.2 stage 1 — `lethal_hit_detected` fire (frame N)

```text
ECHO HurtBox.area_entered(HitBox)
  ↓ hurtbox_hit(cause) emit
  ↓ ECHO Damage component handles
  0. if _pending_cause != &"": return       # ← Round 5 first-hit lock (cross-doc S1 fix 2026-05-10)
                                            #   single-source enforcement of E.1 / time-rewind.md Rule 17 invariants
  1. _pending_cause = cause                 # stage 2 instance store — *before* emit
  2. emit lethal_hit_detected(cause)        # TRC cache (frame N)
  3. emit player_hit_lethal(cause)          # SM DYING transition
```

> **Ordering invariant** (godot-gdscript-specialist recommendation): `_pending_cause` assignment must execute *before* emit. Defends against future edge case where a synchronous signal handler calls `commit_death()` in the same call stack. AC-9's `_pending_cause = cause₀` verification assumes cause₀ is set at the post-emit point.

> **First-hit lock invariant** (Round 5 cross-doc S1 fix 2026-05-10 — `gdd-cross-review-2026-05-10.md`): the step 0 guard is the *sole enforcement site* of two invariants — (a) `damage.md` E.1 "_pending_cause is locked to the first hit's cause" and (b) `time-rewind.md` Rule 17 "same-tick multiple lethals are blocked from re-caching `_lethal_hit_head`". SM `_lethal_hit_latched` is only a *secondary* guard after step 3; because lethal_hit_detected (step 2) and player_hit_lethal (step 3) are separate signals, the SM-side latch alone cannot block TRC's `_lethal_hit_head` re-cache. `_pending_cause` is cleared to `&""` by `commit_death()` or `cancel_pending_death()`, so the first hit of the next lethal event passes normally. AC-36 verification.

#### C.3.3 stage 2 — `death_committed` fire (frame N+k, k=12 default)

The firing of `death_committed` is determined by SM's grace counter. SM *pushes* Damage (polling forbidden, DEC-4):

```text
EchoLifecycleSM.DyingState.physics_process(delta):
  _grace_frames_remaining -= 1
  if _grace_frames_remaining == 0 and not _rewind_consumed_during_grace:
    transition_to(DeadState)
    # inside DyingState.exit():
    damage.commit_death()    # Damage emits immediately using _pending_cause
```

`Damage.commit_death() -> void` is the single *invocation API* exposed by this GDD. No arguments — uses `_pending_cause` internally. After the call, `_pending_cause` is reset to `&""`.

> **Idempotency guard** (systems-designer recommendation): `commit_death()` short-circuits on entry with `if _pending_cause == &"": return`. Prevents `death_committed(&"")` empty-cause emit even if called redundantly while `_pending_cause` is already cleared. AC-31 verification.

> **`cancel_pending_death()` guard**: Likewise, calling when `_pending_cause == &""` is a silent no-op (no error — SM's RewindingState.enter() may have multiple entries in normal lifecycle). AC-32 verification.

#### C.3.4 Grace shortcut / invalidation (on Rewind consumption)

- Player inputs rewind within grace → SM `DyingState → RewindingState` transition
- In this case `death_committed` is **not emitted** (death is retracted)
- Damage-side responsibility: `_pending_cause = &""` reset (SM calls `damage.cancel_pending_death()` in RewindingState.enter())

---

### C.4 Enemy + Boss Damage Model

#### C.4.1 Standard Enemy (1-hit kill, DEC-3)

```text
Enemy HurtBox.area_entered(HitBox)
  ↓ hurtbox_hit(cause) emit
  ↓ enemy host handles
  1. emit enemy_killed(self.entity_id, cause)
  2. queue_free()  # same-frame processing
```

- No hit-stun. Removed immediately.
- Multiple hits in the same tick: first hit emits + queue_free → subsequent area_entered does not fire from a *freed node* (guaranteed by Godot).

#### C.4.2 Boss (discrete phase thresholds, DEC-2)

The boss host holds `phase_hits_remaining: int`, `phase_index: int` (0-based), and `_phase_advanced_this_frame: bool` (added Round 3 — D.2.3 monotonic +1 lock) as members. `_phase_advanced_this_frame` resets to `false` at the start of each `_physics_process(delta)`. This GDD specifies *the procedure that the boss host must follow*:

```text
Boss HurtBox.area_entered(HitBox)
  ↓ hurtbox_hit(cause) emit (from HitBox side — C.1.2 step 2)
  ↓ boss host handles (no re-emit)
  0. if _phase_advanced_this_frame: return            # ← Round 3 lock — guarantees single phase advance per tick for multi-hit
  1. phase_hits_remaining -= 1
  2. if phase_hits_remaining > 0:
       emit boss_hit_absorbed(self.entity_id, phase_index)
       # → VFX/SFX feedback trigger. No UI change. hits_remaining not propagated (DEC-5).
  3. elif phase_index < final_phase_index:
       emit boss_pattern_interrupted(self.entity_id, phase_index)   # Boss Pattern SM cleanup trigger — emit value `phase_index` is pre-increment value (= F.3 declared param `prev_phase_index`)
       phase_index += 1
       phase_hits_remaining = phase_hp_table[phase_index]
       _phase_advanced_this_frame = true                              # lock set
       emit boss_phase_advanced(self.entity_id, phase_index)
       # → HUD optional notification + VFX change + pattern SM re-entry
  4. else:
       emit boss_pattern_interrupted(self.entity_id, phase_index)
       _phase_advanced_this_frame = true                              # lock set (boss_killed branch also consistent)
       emit boss_killed(self.entity_id)
       # → stage clear trigger (Stage Manager #12). Summon cleanup is Boss Pattern GDD #11 responsibility (own summon registry).
```

- `phase_hp_table: Array[int]` is solely owned by Boss Pattern GDD (#11). This GDD enforces *format only*.
- **DEC-5** (added 2026-05-09): `boss_hit_absorbed(boss_id, phase_index)` — 2-arg signature. The draft's `hits_remaining: int` parameter is **removed**. Reason: protects B.1 "binary, not graded" data contract — architectural block preventing VFX/Audio consumers from *exposing remaining count on the design surface*. If multi-level intensity differentiation is needed, consider introducing `phase_index` or a separate boolean flag (`is_last_hit`).
- `boss_hit_absorbed` separates non-phase-transition hits as a distinct signal (VFX differentiation). HUD does not subscribe.
- `boss_pattern_interrupted(boss_id, prev_phase_index)` (new): emits in the *same frame* immediately before a phase transition or boss kill. Boss Pattern GDD #11 subscribes to self-cleanup in-flight active patterns (laser sweep, charge, AoE wind-up). Damage GDD only emits the signal and does not touch the cleanup mechanism (unidirectional data flow).
- Multiple hits *during* phase transition (E.6): even if a negative count occurs in step 1, the phase advances *only one step*. Remaining negative hits are discarded (DEC-2 consistency — phase is a binary gate). **Design decision justification for the monotonic +1 lock is in ADR-00XX (Boss Phase Advance Monotonicity, queued)** — a new ADR is required to open design space for perfect parry / weapon-skip etc. in Tier 3.

---

### C.5 Hazard Integration Signals + cause taxonomy

#### C.5.1 Hazard Host Pattern

The stage (#12) instantiates hazards in the following form:

```text
Hazard (Area2D, layer=5, mask=1)
  ├─ CollisionShape2D
  └─ HitBox (child component, cause = &"hazard_spike" etc.)
```

- Hazard holds only a single `HitBox` (no HurtBox — not destructible)
- ECHO HurtBox (L1) collides with hazard HitBox (L5) → *exactly the same* processing flow as the standard hurt path (C.3.2)
- The Damage system does not distinguish between hazards and enemy projectiles. The only difference is the `cause` label.

#### C.5.2 cause taxonomy (Tier 1 baseline, locked)

> **Tier 1 enemy archetype decision obligation (game-designer recommendation)**: If Tier 1 has *only one drone type*, the baseline 6 entries are sufficient. If *3 types coexist* (`&"projectile_enemy_drone"`, `&"projectile_enemy_secbot"` etc.) sub-entries must be added — guaranteeing B.3 "cause-aware death" learnability. Decision to be made when writing Enemy AI GDD #10 (OQ-DMG-7).

| StringName | Category | Source |
|---|---|---|
| `&"projectile_enemy"` | Enemy projectile (Tier 1 baseline — one drone type) | Standard enemy (#10) |
| `&"projectile_boss"` | Boss projectile | Boss (#11) |
| `&"hazard_spike"` | Environmental spike (`hazard_` prefix invariant — DEC-6) | Stage (#12) |
| `&"hazard_pit"` | Infinite fall | Stage (#12) |
| `&"hazard_oob"` | OOB kill volume | Stage (#12) — see Time Rewind E-17 |
| `&"hazard_crush"` | Crush death (moving platform) | Stage (#12) — Tier 1 option |

#### C.5.3 Tier Expansion Policy

- When adding new causes in Tier 2/3, update this table *append-only*.
- No semantic changes to existing causes (single source that VFX/SFX/Audio systems map to deterministically).
- When adding new entries: obligation to update `design/gdd/damage.md` D.3 + update mapping tables in VFX (#14) / Audio (#4) GDDs.

---

### C.6 i-frame Cooperation (DEC-4 — SM disables HurtBox.monitorable) + DEC-6 hazard grace

#### C.6.1 Unidirectional Data Flow Preservation

The invariant this GDD defends most strongly: **The Damage system does not know SM state**. This preemptively blocks violations of forbidden_pattern `cross_entity_sm_transition_call` + `damage_polls_sm_state`.

#### C.6.2 i-frame Mechanism (REWINDING)

| Moment | Actor | Action | Effect |
|---|---|---|---|
| `RewindingState.enter()` | SM (external system) | `echo_hurtbox.monitorable = false` | Godot collision engine does not fire `HitBox.area_entered` → Damage automatically *silenced* |
| `RewindingState.exit()` | SM (external system) | `echo_hurtbox.monitorable = true` + `damage.start_hazard_grace()` | Enemy projectile detection immediately activated. Hazard only: 12-frame grace (DEC-6) |

- The "i-frame predicate" is not a separate variable but the `HurtBox.monitorable` node property itself. Single source.
- The Damage system does *not query* the `monitorable` value. The self-evident causation of *not operating when `HitBox.area_entered` does not arrive* is sufficient.

#### C.6.3 Interaction between `lethal_hit_detected` and monitorable toggle

- In C.3.2, the ECHO Damage component does **not** additionally call `echo_hurtbox.monitorable = false` on its own in stage 1. SM handles it at the DYING transition as its own responsibility.
- Reason: If Damage toggles monitorable, two sources (Damage + SM) conflict. SM single-source principle (state-machine GDD AC-14 connect order consistency).

#### C.6.4 Hazard grace mechanism (DEC-6 — Pillar 1 protection)

Scenario where ECHO's position resides inside a hazard area immediately after `RewindingState.exit()` (e.g., respawning on spikes):

| Moment | Actor | Action | Effect |
|---|---|---|---|
| `RewindingState.exit()` | SM | calls `damage.start_hazard_grace()` | Damage sets `_hazard_grace_remaining: int = hazard_grace_frames + 1 = 13` (Round 4 B-R4-1 fix — `+1` compensates same-frame priority-2 decrement) |
| `RewindingState.exit() + 1 frame` | Damage | `_hazard_grace_remaining -= 1` in `_physics_process(delta)` | 13 → 12 → ... → 1 countdown, hazard blocked during 12 flush windows (200ms) |
| Hazard hit arrives during countdown | Damage | In `hurtbox_hit` handler, if cause has `&"hazard_*"` prefix and counter > 0, return immediately | Hazard causes blocked only; enemy projectiles accepted normally |
| 12 frames expired | Damage | Counter naturally reaches 0 | Normal hazard detection reactivated |

**Decision predicate**:

```text
should_skip_hazard(cause: StringName) :=
    _hazard_grace_remaining > 0
  ∧ str(cause).begins_with("hazard_")
```

> **`_physics_process` priority ladder registration (added Round 3 — B-3 BLOCKING)**: The ECHO Damage component's `_physics_process` occupies the **priority = 2** slot in the ADR-0003 `physics_step_ordering` ladder (player=0, time-rewind-controller=1, **damage=2**, enemies=10, projectiles=20). Slot selection rationale: Damage counter must decrement *after* TRC has cached frame state (priority 1 complete), and hazard grace check must be determined *before* enemy hit dispatch (priority 10).
>
> **Frame-N boundary invariant (Round 4 B-R4-1 correction)**: In Godot 4.6, `Area2D.area_entered` signals are synchronously dispatched during the PhysicsServer2D flush phase, which occurs *before* all nodes' `_physics_process`. However, SM's `RewindingState.exit()` is called **inside** ECHO's `_physics_process` (priority 0), so the counter set by `start_hazard_grace()` immediately decrements by 1 in the same frame's priority-2 Damage `_physics_process`. Therefore, for *effective protection length to be `hazard_grace_frames`*, the initial value must be set to `hazard_grace_frames + 1` (Round 4 B-R4-1 correction). Trace: F0 flush (monitorable=false remaining, blocked) → F0 process (ECHO sets 13, Damage 13→12) → F0+1 flush (counter=12, blocked) → ... → F0+12 flush (counter=1, blocked) → F0+13 flush (counter=0, pass). 12 flush windows blocked ✓.
>
> **ADR-0003 update obligation (queued)**: This priority slot requires adding 1 row to the ADR-0003 ladder table — to be handled immediately before writing Boss Pattern GDD #11 (together with OQ-DMG-9 ADR `signal-emit-order-determinism`). This GDD *declares* as single source, and the ADR provides the basis for architecture-level lock-in.

**Design justification** (Pillar 1 "learning tool, not punishment"):
- Guarantees a *learning opportunity* when a player consumes 1 token to rewind.
- 12 frames = 1 input cycle (60fps × 200ms = 12 ticks) — a window for 1 jump/move/shoot action.
- Enemy projectiles are not blocked — only *environmental hazards* qualify for grace. I.e., consistent fantasy of "time to re-orient after position recovery."
- All 4 external hazard causes (`hazard_spike`/`hazard_pit`/`hazard_oob`/`hazard_crush`) qualify for grace. Boss projectiles (`projectile_boss`) do *not* qualify.

**Tuning**: `hazard_grace_frames` knob (G.1) — Tier 1 lock 12, range 6–18.

#### C.6.5 `start_hazard_grace()` invocation API

`Damage.start_hazard_grace() -> void` (new):
- Caller: SM (RewindingState.exit())
- Effect: sets `_hazard_grace_remaining = hazard_grace_frames + 1` (Round 4 B-R4-1 — `+1` compensates same-frame priority-2 decrement; effective 12 flush blocking window)
- Registered in F.4. Unidirectional SM → Damage.

#### C.6.6 hazard cause prefix convention

The `&"hazard_"` prefix is *reserved* in cause taxonomy (D.3.2). The C.6.4 predicate uses this prefix to distinguish environmental hazards from enemy/boss projectiles. When expanding the taxonomy (D.3.3 append-only), hazard types must always start with `&"hazard_"` — this prefix invariant is mandatory when changing the G.1 `cause_taxonomy_entries` knob.

---

## D. Formulas

> **Status**: Approved 2026-05-09.
>
> Because Echo uses a binary damage model (DEC-3), there are no *numeric formulas* like `damage = base × crit × armor`. The "formulas" in this section consist of 4 types: (1) collision predicate, (2) phase state transition, (3) cause labeling mapping, and (4) i-frame predicate.

---

### D.1 HitBox-HurtBox Collision Predicate

#### D.1.1 Definition

`hit(hb, hh) -> bool` is determined by the **AND** of the following 4 conditions (consistent with Godot 4.6 Area2D semantics — DEC-4):

```text
hit(hb: HitBox, hh: HurtBox) :=
    hb.monitoring                                          # (1) HitBox active scan enabled
  ∧ hh.monitorable                                         # (2) HurtBox detectable (i-frame single source)
  ∧ layer_mask_check(hb.collision_mask, hh.collision_layer) # (3) layer matrix
  ∧ shape_overlap(hb.shape, hh.shape, hb.xform, hh.xform)  # (4) geometry overlap
```

> **[2026-05-09 correction round 2]** The draft's `hh.monitoring` condition is *removed*. In Godot 4.6, the HitBox (active scanner)'s `area_entered` fires regardless of HurtBox `monitoring` value — therefore `hh.monitoring` was an inert (irrelevant) condition. Reduced from 5 to 4 AND conditions.

#### D.1.2 Variable Definitions

| Variable | Type | Range | Source |
|---|---|---|---|
| `hb.monitoring` | bool | `{true, false}` (default true) | `Area2D.monitoring` (Godot built-in) — HitBox active scan enabled |
| `hh.monitorable` | bool | `{true, false}` (default true) | `Area2D.monitorable` (Godot built-in) — i-frame single source |
| `hb.collision_mask` | int (32-bit) | `0` ~ `2^32-1`, 6 bits actually used | C.2.2 matrix |
| `hh.collision_layer` | int (32-bit) | single bit (values 1·2·4·8·16·32 = bits 1·2·3·4·5·6) | C.2.1 assignment |
| `shape_overlap(...)` | bool | `{true, false}` | Godot 4.6 PhysicsServer2D built-in |

> **Layer notation footnote**: C.2.1 uses "Bit N" (1-indexed position), while D.1.2/examples use collision_layer *values* (2^(N-1)). Godot Inspector UI uses bit-index; code API (`collision_layer`, `collision_mask`) uses values. **Conversion**: bit 1 → value 1 (`0b000001`), bit 6 → value 32 (`0b100000`).

#### D.1.3 layer_mask_check Definition

```text
layer_mask_check(mask: int, layer: int) := (mask & layer) != 0
```

#### D.1.4 Example Calculations

**Example 1 — Normal hit (enemy projectile hits ECHO)**

| Item | Value |
|---|---|
| Enemy Projectile HitBox.monitoring | `true` |
| ECHO HurtBox.monitorable | `true` (ALIVE state) |
| HitBox.collision_mask | `0b000001` (L1 only) |
| HurtBox.collision_layer | `0b000001` (L1) |
| `mask & layer` | `0b000001 ≠ 0` → true |
| shape_overlap | `true` (collision) |
| **`hit(hb, hh)`** | **`true`** |

**Example 2 — i-frame blocked (enemy projectile during REWINDING)**

| Item | Value |
|---|---|
| Enemy Projectile HitBox.monitoring | `true` |
| ECHO HurtBox.monitorable | **`false`** (SM disabled in RewindingState.enter()) |
| **`hit(hb, hh)`** | **`false`** (condition (2) fails → short-circuit evaluation. `HitBox.area_entered` fire itself is blocked) |

**Example 3 — Self-damage blocked (ECHO projectile overlapping ECHO)**

| Item | Value |
|---|---|
| ECHO Projectile HitBox.collision_mask | `0b100100` (L3·L6 = 4 + 32 = 36) |
| ECHO HurtBox.collision_layer | `0b000001` (L1 = 1) |
| `mask & layer` | `0b000000` → **0** |
| **`hit(hb, hh)`** | **`false`** (condition (3) fails — Godot blocks area_entered emit itself) |

> **[2026-05-09 correction]** The draft's `0b101100` (bits {3,4,6} = 44) is a typo. Per the C.2.2 lock matrix, ECHO Projectile HitBox (L2) mask is `{L3, L6}` = `0b100100` = 36. The L4 (enemy projectile) bit is *not* included in the mask, and ECHO projectiles do not hit enemy projectiles (Tier 1 baseline — no projectile cancel mechanic).

---

### D.2 Boss Phase Transition Formula (DEC-2)

#### D.2.1 Definition

Let `hits_in_tick(N)` be the number of hits the boss received within the same physics tick. The state transition from Frame N → N+1 is:

```text
remaining'(b, N+1) := max(b.phase_hits_remaining(N) - hits_in_tick(N), 0)

if remaining'(b, N+1) > 0:
    state(b, N+1) := same phase, remaining = remaining'
elif b.phase_index(N) < b.final_phase_index:
    state(b, N+1) := advance phase, index += 1, remaining = b.phase_hp_table[index]
else:
    state(b, N+1) := killed
```

#### D.2.2 Variable Definitions

| Variable | Type | Range | Meaning |
|---|---|---|---|
| `b.phase_index` | int | `0` ~ `final_phase_index` | Current phase (0-based) |
| `b.phase_hits_remaining` | int | `0` ~ `phase_hp_table[phase_index]` | Remaining hit count |
| `b.phase_hp_table` | `Array[int]` | length = `final_phase_index + 1`, each entry ≥ 1 | Starting hit count per phase — solely owned by Boss Pattern GDD (#11) |
| `b.final_phase_index` | int | ≥ 0 | Final phase index (typically 1–3) |
| `hits_in_tick(N)` | int | ≥ 0 | Number of area_entered fires in the same frame |

#### D.2.3 Phase Single-Step Transition Guarantee (E.6 protection)

When `hits_in_tick(N) > b.phase_hits_remaining(N)` (multiple hits in the same tick):
- `max(..., 0)` clamp to prevent `remaining'` from going negative
- Phase index increases *by only 1* — remaining negative hits are discarded
- Reason: Pillar Reveal Through Action — phase transition is a *direction gate*, and skipping different phases within one frame breaks the visual/audio contract

> **D.2.1 aggregate formula vs C.4.2 per-call handler consistency (Round 3 lock)**: D.2.1 is a *specification model* treating `hits_in_tick(N)` as a single aggregate, but the actual implementation path has C.4.2's `area_entered` callback *called sequentially per hit*. For the two models to agree, one of the following invariants is required:
>
> 1. **per-call lock (Round 3 adopted)** — BossHost holds `_phase_advanced_this_frame: bool` flag. Resets to `false` at the start of each `_physics_process(delta)`. 2nd and subsequent `area_entered` callbacks within the same physics tick immediately `return` on lock entry → no additional `phase_hits_remaining` decrement, phase transition, or signal emit. Remaining hits effectively discarded (equivalent to D.2.1 max clamp).
> 2. ~~aggregate buffer~~ — frame-end batch processing model. Introduces 1-frame processing delay; not adopted.
> 3. ~~`phase_hp_table[i] >= max_simultaneous_projectile_count` constraint~~ — fragile because simultaneous hit count is outside Boss Pattern GDD control; not adopted.
>
> **Counterexample (without lock)**: `phase_hp_table=[2,1,5]`, `phase_index=0`, `phase_hits_remaining=2`, 3 hits same frame → call 1: remaining=1 (`boss_hit_absorbed`). call 2: remaining=0 → phase 0→1 (`boss_phase_advanced`). call 3: remaining=0 → phase 1→2 (**second `boss_phase_advanced` emit**). With lock adopted, call 3 returns at step 0 → monotonic +1 guaranteed.
>
> **AC-14 worst-case update obligation**: The consistency of this lock must be verified by AC-14 with the `phase_hp_table[next] = 1` case (the previous worked example's `phase_hp_table=[5,8,12]` passes coincidentally even without the lock — vacuous verification).

#### D.2.4 Example Calculations

**Example 1 — Standard single hit**

| Item | Value |
|---|---|
| `phase_index(N)` | `0` |
| `phase_hits_remaining(N)` | `5` |
| `hits_in_tick(N)` | `1` |
| `remaining'(N+1)` | `max(5 - 1, 0) = 4` |
| Result | Same phase maintained, `remaining=4` |

**Example 2 — Phase transition (exactly 0)**

| Item | Value |
|---|---|
| `phase_index(N)` | `0` |
| `phase_hits_remaining(N)` | `1` |
| `hits_in_tick(N)` | `1` |
| `remaining'(N+1)` | `0` |
| `final_phase_index` | `2`, `phase_hp_table = [5, 8, 12]` |
| Result | `phase_index → 1`, `phase_hits_remaining → 8` (`phase_hp_table[1]`) |

**Example 3 — Multi-hit phase transition protection**

| Item | Value |
|---|---|
| `phase_index(N)` | `0` |
| `phase_hits_remaining(N)` | `1` |
| `hits_in_tick(N)` | `3` (piercing shot + normal shot + explosion) |
| `remaining'` | `max(1 - 3, 0) = 0` (negative → 0 clamp) |
| Result | `phase_index → 1` (single step only), `phase_hits_remaining → phase_hp_table[1]` |
| Discarded | Remaining -2 hits |

**Example 4 — Final phase last hit**

| Item | Value |
|---|---|
| `phase_index(N)` | `2` (= final) |
| `phase_hits_remaining(N)` | `1` |
| `hits_in_tick(N)` | `1` |
| `remaining'` | `0` |
| Result | `boss_killed` emit, queue_free |

---

### D.3 cause taxonomy mapping (DEC-1 sole ownership)

#### D.3.1 cause Assignment Obligation Table (host-side contract — not a runtime function)

> **Round 3 clarification**: D.3.1 is a *cause assignment table that hosts must follow at instantiation time*, not a *runtime function*. The emit in C.1.2 step 2 simply propagates `self.cause` and does *not perform* branching logic. This table is the documentation contract referenced when host system authors set HitBox.cause.

`HitBox.cause` assignment rules (host system obligation):

```text
host_assigns_cause(hb: HitBox, host_type) :=
    &"projectile_boss"   if host_type is Boss            # Boss Pattern GDD #11 obligation
    else &"projectile_enemy"   if host_type is Enemy     # Enemy AI GDD #10 obligation
    else <hazard label>                                   # Stage GDD #12 per-instance label ("hazard_spike" etc.)
```

ECHO Projectile HitBox (L2) cause is *explicitly unset* (F.1 row #7) — ECHO projectiles hit enemy/boss HurtBoxes, and the enemy/boss-side handlers (C.4) do not use cause (`enemy_killed`/`boss_*` signals only emit; cause argument is forwarded as-is). The unset fallback is a safety net in D.3.4 with `&"unknown"` + debug-only push_error.

#### D.3.2 cause Registry (Tier 1, append-only)

| StringName | Source (host type) | Estimated Frequency |
|---|---|---|
| `&"projectile_enemy"` | Standard enemy (#10) projectile | Very high |
| `&"projectile_boss"` | Boss (#11) projectile | Medium |
| `&"hazard_spike"` | Stage spike | Medium |
| `&"hazard_pit"` | Infinite fall area | Low |
| `&"hazard_oob"` | OOB kill volume | Low (design safety net) |
| `&"hazard_crush"` | Crush trap | Low (Tier 1 option) |

#### D.3.3 Variable Definitions

| Variable | Type | Range |
|---|---|---|
| `hb.host` | `Node` | Boss / enemy / stage etc. — type determined by `is` |
| `hb.cause` | `StringName` | D.3.2 table entry or `&""` (when determined in host branch) |

#### D.3.4 Fallback when cause is unset (E.7 handling)

When `hb.cause == &""` and no host type branch matches:
- Signal emits with `&"unknown"` (never silent failure)
- Simultaneously outputs `push_error("HitBox cause unset: %s" % hb.get_path())` to Godot console
- Not an intended permanent entry — debug catch

---

### D.4 i-frame Predicate (HurtBox.monitorable single source)

#### D.4.1 Definition

```text
is_invulnerable(echo_hurtbox: HurtBox) := !echo_hurtbox.monitorable
```

#### D.4.2 Variable Definitions

| Variable | Type | Range | Meaning |
|---|---|---|---|
| `echo_hurtbox.monitorable` | bool | `{true, false}` | Godot Area2D built-in property. Single source. |

#### D.4.3 Single Source Contract

- `is_invulnerable` is *not a separate variable*. It is the negation of the `monitorable` node property.
- This system does **not** hold separate `_iframe_timer` or `_invulnerable: bool` cache variables.
- Authority to start/end the invulnerability window is solely owned by SM (`RewindingState.enter/exit`) + Time Rewind GDD Rule 11 (30-frame time-based).
- The Damage system does *not call* `is_invulnerable` — since Godot's collision engine does not fire *any HitBox's* `area_entered` for a HurtBox with `monitorable=false`, this predicate is only for *advisory* queries by external systems (e.g., VFX flicker decisions).

> **`hazard_grace_remaining` is a separate predicate** (DEC-6 / C.6.4): Hazard-only partial invulnerability is orthogonal to `is_invulnerable`. is_invulnerable is *total* blocking, hazard_grace is *partial cause-prefix-based* blocking. AC-33 verification.

#### D.4.4 Examples

| Moment | `monitorable` | `is_invulnerable` |
|---|---|---|
| ALIVE normal | `true` | `false` |
| DYING grace window | `true` | `false` (vulnerable — SM latch handles multi-hits) |
| REWINDING start (frame N+12) | `false` (SM disabled) | `true` |
| REWINDING end (frame N+42) | `true` (SM re-enabled) | `false` (however, hazard causes get 12-frame additional grace — DEC-6) |

---

## E. Edge Cases

> **Status**: Approved 2026-05-09.

### E.1 Same-frame ECHO multi-hit (piercing shot + direct collision)

**Situation**: A piercing enemy projectile + another directly colliding enemy both emit area_entered to ECHO HurtBox in the same physics tick.

**Result**:
- First area_entered → ECHO Damage passes step 0 first-hit lock guard (`_pending_cause == &""` → pass) → step 1 `_pending_cause = cause₀` → step 2 `lethal_hit_detected(cause₀)` emit (TRC `_lethal_hit_head` cache) → step 3 `player_hit_lethal(cause₀)` emit. SM transitions ALIVE → DYING + sets `_lethal_hit_latched = true`.
- Second area_entered (same frame N or N+k during DYING grace) → ECHO Damage re-enters `_on_hurtbox_hit(cause₁)` → **step 0 first-hit lock**: `_pending_cause = cause₀ != &""` → return immediately. None of steps 1/2/3 execute; `_pending_cause` not overwritten · `lethal_hit_detected` not re-emitted (TRC `_lethal_hit_head` not re-cached) · `player_hit_lethal` not re-emitted. SM's `_lethal_hit_latched` guard is the secondary defence after step 3 (unreached since Damage step 0 already blocked).
- Result: `_pending_cause = cause₀` preserved → `commit_death(cause₀)` emits 12 frames later. TRC `_lethal_hit_head` also preserves the value cached at first emit time.
- **Verification**: AC-36 (first-hit lock — Round 5 cross-doc S1 fix). Auxiliary: state-machine.md AC-12 (single DYING transition + single history entry). Single source: `damage.md` C.3.2 step 0.

### E.2 Enemy projectile hit attempt during REWINDING

**Situation**: An enemy projectile HitBox reaches ECHO's position within the 30-frame REWINDING window.

**Result**:
- SM's `RewindingState.enter()` has already set `echo_hurtbox.monitorable = false`.
- D.1.1 condition (2) fails → Godot blocks `HitBox.area_entered` from firing at all.
- Enemy projectile passes through ECHO's coordinates (visually the graphics may overlap). Hit effect = 0.
- ECHO Damage component code path is never entered.
- **Verification**: Integration scene test — REWINDING simulation + projectile fire + confirm `lethal_hit_detected` not emitted.

### E.3 Hazard + enemy projectile simultaneous hit

**Situation**: ECHO is inside a spike (hazard_spike) area and simultaneously hit by an enemy projectile.

**Result**:
- Two area_entered events emit at the same frame N. Godot 4.6's area_entered call order is deterministic based on instance ID + child index, but *which cause fires first* depends on scene configuration.
- `lethal_hit_detected` emits with the first-firing cause + SM DYING. Second is blocked by latch guard (same as E.1).
- `_pending_cause` is the first-firing cause. VFX/SFX are learnable signatures *either way*, so cause non-determinism is *acceptable*.
- **Verification**: GUT — two area_entered simulation + single `lethal_hit_detected` emit + cause matches first fire.

### E.4 Multi-hit during boss phase transition (D.2.3 cross-reference)

**Situation**: 3 hits in the same frame when `phase_hits_remaining = 1`.

**Result**: D.2.3 applies. `remaining' = max(1-3, 0) = 0` → phase advances exactly 1 step. Remaining -2 hits discarded. `boss_phase_advanced` emits exactly once.

**Verification**: GUT — phase_hits_remaining=1 + 3 hits emit + phase_index exactly +1 + advance signal once.

### E.5 Off-screen damage

**Situation**: ECHO hits an enemy with a projectile while the enemy is outside the camera viewport.

**Result**:
- This system does *not know* about camera/viewport. Only HitBox.monitoring + HurtBox.monitorable + collision_layer are the judgment criteria.
- If the enemy is in the active scene tree and enemy HurtBox.monitorable=true, processes normally → `enemy_killed` emit.
- Visibility-based deactivation optimization for enemies is Enemy AI GDD (#10)'s responsibility. Damage is unrelated.

### E.6 Pickup vs damage HitBox priority (Tier 2 future)

**Situation**: Enemy projectile + pickup item reach ECHO's position simultaneously.

**Result**:
- Pickup Area2D is on a *separate collision layer* (to be assigned in Tier 2 system #15, does not exist in current Tier 1).
- The two area_entered events are processed *independently* in ECHO host's separate handlers.
- Damage emits `lethal_hit_detected` → SM DYING transition.
- Pickup handling is at ECHO host's own discretion (normally ignores pickups during DYING/REWINDING/DEAD — defined in separate GDD).
- **Current Tier 1**: Pickup system does not exist, so this case cannot occur. Revisit at Tier 2 gate.

### E.7 Damage during weapon swap

**Situation**: Enemy projectile hits ECHO during a weapon change (weapon-system #7 transition).

**Result**:
- This system does *not know* about ECHO's weapon state. ECHO HurtBox is active regardless of weapon swap.
- Normal hit processing — `lethal_hit_detected` emit → SM DYING.
- ECHO host's weapon swap coroutine has its own cancel/cleanup obligation (Player Movement #6 or Player Shooting #7 GDD responsibility).

### E.8 Projectile passes through hazard area

**Situation**: Enemy projectile HitBox (L4) passes through spike hazard HitBox (L5) area.

**Result**:
- Enemy Projectile HitBox (L4) mask is `0b000001` (L1 only). L5 not included → collision ignored.
- Projectile *passes through* the spike. No interaction with hazard.
- If stage design wants "spikes block projectiles," the spike must additionally hold a separate *projectile-blocking collider* (stage #12 responsibility). This GDD is unrelated.

### E.9 Scene boundary projectile leak

**Situation**: Projectile moves outside stage boundary.

**Result**:
- This system does *not know* about scene boundaries. Projectile lifecycle is self-managed by the host (#7/#10/#11).
- When a projectile is `queue_free()`d by its host, area_entered no longer fires from the next frame (Godot guaranteed).
- This GDD only *states* that the host has the obligation to prevent leaks. No enforcement mechanism.

### E.10 ECHO projectile hits ECHO's own HurtBox (self-damage prevention)

**Situation**: ECHO projectile overlaps geometrically with own HurtBox immediately after firing.

**Result**: D.1.4 Example 3 applies. ECHO Projectile HitBox (L2) mask does not include L1 → Godot blocks area_entered emit *itself*. No code guard needed.

### E.11 Boss phase_hp_table length mismatch (host misuse)

**Situation**: Boss host instantiated with `phase_hp_table.size() != final_phase_index + 1`.

**Result**:
- `phase_hp_table[index]` out-of-bounds access in D.2.1 step 3 causes Godot runtime error.
- This GDD imposes a *validation obligation* on the Boss host: inside `_ready()`, `assert(phase_hp_table.size() == final_phase_index + 1, "phase_hp_table length mismatch")`.
- If validation is omitted, crash on first phase transition attempt → immediately caught at design stage.

### E.12 Same-frame projectile hit + self-destroy

**Situation**: Enemy projectile hits ECHO + in the same frame collides with another collider (wall etc.) and calls `queue_free()`.

**Result**:
- Godot processes `queue_free()` at *end of frame* (idle phase). The node is still valid at the moment area_entered was emitted.
- ECHO HurtBox's `hurtbox_hit` emits normally — `lethal_hit_detected` fires normally.
- Only the projectile node disappears next frame. ECHO death processing is unaffected.

### E.13 Permanent hazard residence immediately after RewindingState.exit()

**Situation**: ECHO revives on spikes after rewind. REWINDING → ALIVE transition.

**Result [DEC-6 policy — Pillar 1 protection]**:
- `RewindingState.exit()` calls `damage.start_hazard_grace()` simultaneously with restoring `echo_hurtbox.monitorable = true` → sets `_hazard_grace_remaining = 12`.
- During the same frame or the next 12 frames (~200ms):
  - Enemy projectile hits (`projectile_enemy`/`projectile_boss`) → processed normally (enters DYING). Pillar Challenge consistency — *not exempted*.
  - Hazard hits (`hazard_*` prefix) → return immediately in `hurtbox_hit` handler. Code path not entered.
- Within 12 frames, player can execute 1 input cycle (jump/move/shoot) → escape hazard position.
- After 12 frames, counter naturally reaches 0 → normal hazard detection reactivated. Instant hazard kill if escape fails.

**Design justification** (Pillar 1 vs Pillar Challenge balance):
- Prevents a player who consumed 1 token from being trapped in an instant-kill cycle with *zero learning opportunity* — ensures tokens *function*.
- 12 frames = 1 input cycle — *not analysis time*, *reaction time*. Consistent with anti-fantasy "rage time not lockout" (Time Rewind GDD B.4).
- *No* enemy projectile exemption → punishing-but-fair threat density preserved. ECHO received "time to move once within the environment," not "escape."

**Level Design obligation (advisory — not enforced)**: Recommended to place positions such that the 0.15s-ago location does not reside deep in a hazard area. The 12-frame grace only guarantees *one player input*, not automatic resolution of *all* hazard residence cases.

> **Cross-doc timing consistency (Round 4 — game-designer recommendation REC-R4-GD-1)**: `time-rewind.md` E-17 (`hazard_oob` 0.15s-ago position also OOB case) states "re-death at i-frame end is intended behavior" meaning REWINDING.exit() (frame N+30), but **DEC-6's 12-frame hazard-only grace additionally operates**, so actual re-death timing is frame N+30+12 = N+42. To prevent two programmers reading the two GDDs separately from implementing different timings, time-rewind E-17 also has a reciprocal note obligation (explicitly stating DEC-6 12-frame additional delay). **Single source is this GDD DEC-6 + C.6.4**.

**Verification**: AC-24 (rewritten).

### E.14 HitBox.cause unset (host misuse)

**Situation**: Stage/Enemy host instantiated without setting `HitBox.cause`.

**Result**: D.3.4 fallback applies. `&"unknown"` signal + `push_error` console output. Temporary entry for debug catch purposes.

**Mitigation responsibility**: Host systems are recommended (not required) to validate cause setting in `_ready()` — D.3.4 fallback is the safety net.

### E.15 Boss vs boss projectile self-damage (Tier 2 possibility)

**Situation**: Possibility of a design where the boss hits its own projectile in Tier 2/3.

**Result**:
- In the current Tier 1 matrix (C.2.2), Boss HurtBox (L6) has mask=2 (L2 ECHO projectile only). Boss projectiles (L4) are not in L6 mask → Godot blocks.
- If Tier 2 design introduces a "boss self-damage phase," a *separate layer bit addition* (e.g., L7 self-vulnerable boss) is required. Current Tier 1 baseline guarantees self-damage prevention.

---

## F. Dependencies

> **Status**: Approved 2026-05-09. F.5 update obligation to be handled in batch after Section H is complete.

### F.1 Upstream Clients (HitBox/HurtBox hosts)

This GDD *provides* components (HitBox/HurtBox classes + cause taxonomy), and the following systems *instantiate* them as child nodes and host them. This GDD does **not** touch the host's internal structure (composition over inheritance).

| # | System | Components Hosted | Responsibility |
|---|---|---|---|
| **#6** | [Player Movement](player-movement.md) | ECHO HurtBox (L1) + HitBox + Damage node (PlayerMovement child host) | **PM #6 Designed lock-in (2026-05-10)**: Instantiated as child of ECHO scene tree (= PlayerMovement CharacterBody2D root, player-movement.md A.Overview Decision A). ECHO HurtBox + HitBox + Damage nodes are *child nodes of PlayerMovement (CharacterBody2D)*, with PM holding node *ownership* and lifecycle (especially `monitorable` toggle) controlled by SM. Sets `entity_id = &"echo"`. **monitorable toggle authority delegated to SM (DEC-4) — node hosted by PM, lifecycle controlled by SM**. SM's RewindingState.enter()/exit() + DEC-6 `start_hazard_grace()` invocation. |
| **#7** | Player Shooting | ECHO Projectile HitBox (L2) | Instantiated as child of projectile .tscn. `cause` unset (ECHO projectile cause label irrelevant — enemy/boss destroy side does not use cause). |
| **#10** | Enemy AI | Enemy HurtBox (L3) + Enemy Projectile HitBox (L4) | HurtBox on enemy body, HitBox on enemy projectile. HitBox.cause = `&"projectile_enemy"` (D.3 auto branch). |
| **#11** | Boss Pattern | Boss HurtBox (L6) + Boss Projectile HitBox (L4) | Obligation to hold `phase_hits_remaining` / `phase_index` / `phase_hp_table` members (E.11 validation obligation). HitBox.cause = `&"projectile_boss"` (D.3 auto branch). |
| **#12** | Stage | Hazard HitBox (L5) | Instantiated as child of hazard Area2D. Obligation to set per-instance `cause` label (`&"hazard_spike"` etc.). Does not hold HurtBox (not destructible). |

### F.2 Downstream Consumers (signal subscribers)

The following systems *subscribe* to signals *emitted* by this GDD.

| # | System | Subscribed Signals | Handle Action |
|---|---|---|---|
| **#5** | State Machine Framework | `player_hit_lethal(cause)` | EchoLifecycleSM transitions ALIVE → DYING + sets `_lethal_hit_latched`. *Calls* `damage.commit_death()` / `damage.cancel_pending_death()` (unidirectional). |
| **#9** | Time Rewind | `lethal_hit_detected(cause)`, `death_committed(cause)` | TRC caches `_lethal_hit_head` (frame N) + buffer cleanup on `death_committed`. Consistent with ADR-0002 Amendment 1. |
| **#13** | HUD | `boss_phase_advanced(boss_id, new_phase)` | Phase transition notification (text or screen effect). No HP bar created (Anti-Pillar consistency). |
| **#14** | VFX | `hurtbox_hit(cause)`, `boss_hit_absorbed(...)`, `boss_phase_advanced(...)` | VFX differentiation based on cause (cause taxonomy D.3 mapping). Visual layer change on boss phase transition. |
| **#4** | [Audio System](audio.md) | `boss_killed(boss_id: StringName)`, `player_hit_lethal(cause: StringName)` | `boss_killed` → SFX pool: play `sfx_boss_defeated_sting_01.ogg` (audio.md Rule 13). `player_hit_lethal` → SFX pool: play `sfx_player_death_01.ogg` (audio.md Rule 17). cause + boss_id ignored in Tier 1. Audio #4 Approved 2026-05-12. |
| **#3** | [Camera System](camera.md) | `player_hit_lethal(_cause)`, `boss_killed(boss_id)` | Camera starts shake event — `player_hit_lethal` → 6 px / 12 frames impact shake; `boss_killed` → 10 px / 18 frames catharsis shake (camera.md R-C1-5 + F.1 row #4 reciprocal). cause ignored (Camera does not use cause taxonomy — signal arrival itself is the trigger). Camera #3 Approved 2026-05-12 RR1 PASS. |

### F.3 Signal Emission Catalog (Damage system owned, single source)

The *exhaustive catalog* of all signals emitted by this GDD. External systems must update this GDD to fire additional signals.

| Signal | Signature | Fire Condition | Consumers |
|---|---|---|---|
| `lethal_hit_detected` | `(cause: StringName)` | ECHO HurtBox `HitBox.area_entered` (frame N) | #9 TRC |
| `player_hit_lethal` | `(cause: StringName)` | Same frame and moment as `lethal_hit_detected` | #5 SM |
| `death_committed` | `(cause: StringName)` | When SM calls `damage.commit_death()` (frame N+12) | #9 TRC, #13 HUD |
| `hurtbox_hit` | `(cause: StringName)` | Per HurtBox instance (common to all entities) | #14 VFX, #4 Audio |
| `enemy_killed` | `(enemy_id: StringName, cause: StringName)` | On Enemy HurtBox hit | #4 Audio, (Tier 2: statistics system) |
| `boss_hit_absorbed` | `(boss_id: StringName, phase_index: int)` | Boss non-phase-transition hit (DEC-5 — `hits_remaining` removed) | #14 VFX |
| `boss_pattern_interrupted` | `(boss_id: StringName, prev_phase_index: int)` | Same-frame emit immediately before phase transition or boss kill (new — DEC-6 partner) | #11 Boss Pattern (in-flight active pattern cleanup) |
| `boss_phase_advanced` | `(boss_id: StringName, new_phase: int)` | On Boss phase transition | #13 HUD, #14 VFX, #4 Audio, #11 Boss Pattern (own pattern SM re-entry) |
| `boss_killed` | `(boss_id: StringName)` | Boss final phase last hit | #2 Scene Manager (stage clear trigger), #11 Boss Pattern (summon registry cleanup), #4 Audio |

### F.4 Inter-system Invocation API (unidirectional method calls)

Method APIs *exposed* by this GDD in addition to signals:

| API | Caller | Call Moment | Effect |
|---|---|---|---|
| `Damage.commit_death() -> void` | #5 SM (DyingState.exit()) | On grace expiry | Emits `death_committed` using `_pending_cause`. Resets `_pending_cause = &""`. **Idempotent**: returns immediately if `_pending_cause == &""`. |
| `Damage.cancel_pending_death() -> void` | #5 SM (RewindingState.enter()) | On rewind consumption | Resets `_pending_cause = &""`. No emit. **Idempotent**: silent no-op if already cleared. |
| `Damage.start_hazard_grace() -> void` | #5 SM (RewindingState.exit()) | New (DEC-6) — immediately after i-frame end | Sets `_hazard_grace_remaining = hazard_grace_frames + 1` (Round 4 B-R4-1: `+ 1` compensates same-frame priority-2 decrement; effective 12 flush blocking window). Countdown in `_physics_process`. Single source: C.6.5 / G.1. |

> **Unidirectionality guarantee**: Call direction is *always external → Damage*. Damage does *not call* external methods — only emits signals. This bypasses forbidden_pattern `cross_entity_sm_transition_call` + `damage_polls_sm_state` and prevents circular dependency graphs.

#### F.4.1 Emit order determinism contract (Pillar 2 — new)

When multiple signal emits occur in the same frame, the *deterministic* order that multiple consumers can depend on is specified here. The ADR-0003 `physics_step_ordering` ladder only orders `_physics_process` calls, so this GDD has an *additional* obligation to specify signal emit order.

**Frame N — emit order on ECHO HurtBox hit**:

> **Preceding emit (HitBox side)**: `HurtBox.hurtbox_hit(cause)` is already emitted by the HitBox script at C.1.2 step 2 *before entering the Damage handler*. VFX/Audio receive it at that moment.

```text
Damage._on_hurtbox_hit(cause):  # ← runs after receiving hurtbox_hit (hurtbox_hit not re-emitted inside this handler)
  (1) _pending_cause = cause
  (2) emit lethal_hit_detected(cause)        # connect #1: TRC → _lethal_hit_head cache
  (3) emit player_hit_lethal(cause)          # connect #1: SM → ALIVE→DYING transition + latch set
                                              # connect #2+: VFX/Audio (optional)
```

**Frame N — emit order on Boss HurtBox hit + phase transition**:

> **Preceding emit (HitBox side)**: `HurtBox.hurtbox_hit(cause)` is already emitted by the HitBox script at C.1.2 step 2 *before entering the BossHost handler*. VFX/Audio receive it at that moment.

```text
BossHost._on_hurtbox_hit(cause):  # ← runs after receiving hurtbox_hit (no re-emit inside this handler)
  (1) if _phase_advanced_this_frame:               # ← B-2 lock — 2nd+ hit same frame is discarded immediately on lock entry
        return
  (2) phase_hits_remaining -= 1
  (3) if phase_hits_remaining > 0:
        emit boss_hit_absorbed(boss_id, phase_index)
      elif phase_index < final_phase_index:
        emit boss_pattern_interrupted(boss_id, phase_index) # Boss Pattern SM cleanup signal — must be before phase_advanced
        phase_index += 1
        phase_hits_remaining = phase_hp_table[phase_index]
        _phase_advanced_this_frame = true                    # lock set
        emit boss_phase_advanced(boss_id, phase_index)      # HUD/VFX/Audio + Boss Pattern SM re-entry
      else:
        emit boss_pattern_interrupted(boss_id, phase_index)
        _phase_advanced_this_frame = true                    # lock set (boss_killed branch also monotonic +1 consistent)
        emit boss_killed(boss_id)                           # Scene Manager + Boss Pattern (summon cleanup)
```

> **`_phase_advanced_this_frame` lifecycle**: BossHost holds this bool flag as a member. Resets to `false` at the start of each `_physics_process(delta)` (or equivalent frame-end deferred reset). 2nd and subsequent `area_entered` callbacks within the same physics tick return immediately at step (1) lock → D.2.3 monotonic +1 guaranteed. Verified by AC-14 worst-case `phase_hp_table[next] = 1` + 3 simultaneous hits.

**Sequential multi-consumer order**: `lethal_hit_detected` connect order → `player_hit_lethal` connect order → the *host ECHO node's `_ready()`* guarantees that the connect order of each signal is deterministic (state-machine GDD AC-14 invariant + this GDD AC-28 new).

**Connect order invariant code** (ECHO host's `_ready()`):

```gdscript
# Damage signals — connect in specified order
damage.lethal_hit_detected.connect(trc._on_lethal_hit_detected)   # 1
damage.player_hit_lethal.connect(echo_lifecycle_sm._on_player_hit_lethal)   # 2
damage.death_committed.connect(trc._on_death_committed)            # 3
damage.death_committed.connect(hud._on_death_committed)            # 4
```

When adding consumers, obligation to simultaneously update this GDD's F.3 + F.4.1 tables.

#### F.4.2 Same-frame multi-enemy death emit order

**Situation**: Enemies A, B, C die simultaneously in the same frame (e.g., AOE explosion).

**Rules** (Pillar 2 determinism):
- `enemy_killed` emit order follows *scene-tree order* (parent-child + sibling index). ADR-0003 spawn orchestrator guarantees `(spawn_frame, spawn_id)` sorting.
- Enemy host's `_on_hurtbox_hit` handler is called in the `physics_step_ordering` ladder priority 10 slot, and same-priority siblings within the slot are deterministic by scene-tree order.
- Multiple consumers (VFX, Audio, Stats) receive emits in *the same order*.

**Verification**: AC-29 (new).

### F.5 Bidirectional Verification — Update Obligations (rule compliance)

design-docs.md rule: *"Dependencies must be bidirectional — if system A depends on B, B's doc must mention A"*.

> **Round 1 (2026-05-09 initial) updates complete** — all sites below.
> **Round 2 (2026-05-09 review)**: DEC-5/6 + new signals (`boss_pattern_interrupted`) + new invocation API (`start_hazard_grace`) reflection obligation.

| Other GDD | Round 1 Status | Round 2 Additional Obligation |
|---|---|---|
| `design/gdd/time-rewind.md` F.1 (Upstream table) | *(provisional)* removed + link + signature confirmed ✓ | DEC-6 hazard grace = SM must add `damage.start_hazard_grace()` call obligation in RewindingState.exit() (Time Rewind GDD Rule 11 reinforcement) |
| `design/gdd/state-machine.md` F.1 (Upstream table) | provisional removed + 1-arg confirmed ✓ | Add 1 line for `damage.start_hazard_grace()` invocation in RewindingState.exit() (DEC-6) |
| `design/gdd/state-machine.md` F.3 reverse-mention | "already mentioned — F.1" ✓ | No change |
| `design/gdd/systems-index.md` System #8 row | Designed + Depends On updated ✓ | Round 2 notation: "Designed (Round 2 reviewed 2026-05-09)" |
| `design/gdd/systems-index.md` Open Issue table | OQ-SM-1 Resolved ✓ | Add OQ-DMG-8/9 ADR queued |
| `docs/registry/architecture.yaml` | `interfaces.damage_signals` + `state_ownership.boss_phase_state` + `forbidden_patterns.damage_polls_sm_state` + `collision_layer_assignment` ✓ | Round 2: In `damage_signals.signal_signature`, add `boss_hit_absorbed` 2-arg + `boss_pattern_interrupted` new + `start_hazard_grace` invocation_api. Add 1 line emit ordering contract to `damage_signals.notes`. |

> **Signal naming convention consistency note**: Compared to project convention (snake_case past tense — `health_changed`), this GDD's signal naming is classified as:
> - **Past tense consistent**: `lethal_hit_detected`, `enemy_killed`, `boss_killed`, `boss_phase_advanced`, `boss_pattern_interrupted`, `boss_hit_absorbed`, `death_committed`, `hurtbox_hit`
> - **Exception (DEC-1 lock)**: `player_hit_lethal` — adjectival form. Changing requires synchronizing state-machine GDD AC-14 + Time Rewind GDD Rule 4. Preserved in Round 2 (phonetic analysis: "player has been lethally hit" semantically past-tense consistent, just English word order abbreviation).

### F.6 Dependency Graph (visual summary)

```text
                              ┌─────────────────────────────────────┐
                              │   Damage / Hit Detection (#8)       │
                              │   (HitBox/HurtBox classes + cause)  │
                              └──────────────┬──────────────────────┘
                                             │
   ┌────────── HitBox/HurtBox instance provision ──┴── signal emission ────────┐
   │                                                                            │
   ▼ Upstream (hosts)                                   Downstream (subscribers) ▼

   #6 Player Movement      ────►              ────► #5 State Machine (player_hit_lethal)
   #7 Player Shooting      ────►              ────► #9 Time Rewind (lethal_hit_detected, death_committed)
   #10 Enemy AI            ────►              ────► #13 HUD (boss_phase_advanced)
   #11 Boss Pattern        ────►              ────► #14 VFX (hurtbox_hit, boss_*)
   #12 Stage (hazard)      ────►              ────► #4 Audio (hurtbox_hit, *_killed, *_committed)

                              ▲
                              │ method invocation (unidirectional)
                              │
                              #5 SM → Damage.commit_death() / cancel_pending_death()
```

---

## G. Tuning Knobs

> **Status**: Approved 2026-05-09.

### G.1 Owned Knobs (solely owned by this GDD)

| Knob | Type / Unit | Safe Range | Impact Area | Obligation on Change |
|---|---|---|---|---|
| **`cause_taxonomy_entries`** | `Array[StringName]` (append-only registry) | Total entry count ≤ 32 (Tier 1: 6) | *Vocabulary richness* of cause-based VFX/SFX/Audio differentiation. Hazard types must have `&"hazard_"` prefix (DEC-6). | On append: obligation to add mapping in VFX (#14), Audio (#4), HUD (#13) GDDs |
| **`hurtbox_default_monitorable`** | const bool | locked: `true` (all HurtBoxes instantiated in detectable state) | *Default is hittable* unless host explicitly disables. Only ECHO's SM toggles in RewindingState. | Change forbidden in Tier 1 — changing requires redesigning i-frame system for enemies/boss too |
| **`hitbox_default_monitoring`** | const bool | locked: `true` | HitBox actively scans immediately on instantiation. Hittable from first frame after projectile launch. | Change forbidden in Tier 1 |
| **`hazard_grace_frames`** | const int | range 6–18, default **12** (locked Tier 1, DEC-6) | Length of hazard cause blocking window after REWINDING.exit() (effective flush blocks). Internal set in `start_hazard_grace()` is **`hazard_grace_frames + 1`** (Round 4 B-R4-1 — compensates same-frame priority-2 decrement). Too short: hazard residence unresolved. Too long: lengthens external threat exemption unrelated to enemy projectiles. | If changed in Tier 1: playtesting + re-verify Pillar 1 vs Challenge balance |
| **`friendly_fire_enabled`** | const bool | locked: `false` (Tier 1) | Enemy projectile (L4) ↔ enemy HurtBox (L3) collision ignored — blocks enemies killing each other. | Possible to convert to game-mode flag at Tier 2 gate (current baseline maintained) |
| **`debug_unset_cause_emit_value`** | const StringName | locked: `&"unknown"` | E.14 unset cause safety net. Accompanied by `push_error` in debug builds only (G.5). | Change forbidden in Tier 1 — debug catch signature |
| **`damage_frame_budget_ms`** | const float | locked: 1.0 ms (Tier 1) | Per-frame Damage system cumulative cost ceiling (of gameplay+physics 6ms). Sum of signal fan-out + collision handle + cause branching. | Re-measure when 3 enemy archetypes reached in Tier 2. If exceeded, introduce deferred connect or cause cache. |
| **`area2d_max_active`** | const int | locked: 80 (Tier 1) → 160 (Tier 3 ceiling) | Ceiling of simultaneously active Area2D count. Sum of ECHO, enemies, projectiles, hazards. Enemy AI GDD #10 has viewport-cull responsibility. | Update after measurement at Tier 2 gate. Steam Deck verification required. |

### G.2 Imported Knobs (owned by other GDDs, *referenced* by this GDD)

This GDD's behavior is determined by the following external knobs but *tuning authority is not held here*. Route change requests through the owning GDD.

| Knob | Owning GDD | Usage in This GDD | Impact Area |
|---|---|---|---|
| **`dying_window_frames`** | Time Rewind GDD Rule 4 (default 12) | C.3.3 stage 2 fire timing | Grace window length — ECHO 1-hit catharsis vs decision time |
| **`REWIND_SIGNATURE_FRAMES`** | Time Rewind GDD Rule 11 (locked 30) | C.6.2 i-frame window end timing | ECHO invulnerability time after REWINDING |
| **`phase_hp_table[boss_id]`** | Boss Pattern GDD (#11) per-boss | D.2.1 phase transition gate | Per-boss phase hit count — difficulty curve |
| **`final_phase_index[boss_id]`** | Boss Pattern GDD (#11) per-boss | D.2.1 final phase determination | Number of boss phase stages |
| **`collision_layer/mask` 6 bits** | architecture.yaml `api_decisions.collision_layer_assignment` (to be registered in F.5) | C.2.1, C.2.2 matrices | Entire collision graph — ADR required for design changes |

### G.3 Future Knob Candidates (Tier 2/3, not activated in current Tier 1)

The following are *not introduced in current Tier 1* but are candidates for review at future Tier gates.

| Candidate Knob | Introduction Condition | Value Hypothesis |
|---|---|---|
| **`auto_rewind_on_first_hit`** (Easy mode #20) | Easy mode system implementation + 1-hit-kill accessibility verification (Q4 follow-up) | Inexperienced players get auto rewind trigger on *first hit* → eases learning curve. Pillar Challenge consistency review required. |
| **`friendly_fire_enabled` toggle** | combat playground / boss rush mode | Expresses debug/sandbox game mode. Inactive in main game due to Pillar conflict. |
| **`boss_hp_visible` toggle** (debug overlay) | dev build only | For balancing debug. Forced false in production builds. |
| **`hit_stun_duration` (enemy-only)** | Tier 3 full vision + weapon type expansion | Possibility of granting hit-stun to some weapons when weapon types expand. DEC-3 change required → major design decision. |

> **Tier policy**: G.3 entries are *currently disabled*. When activated, move from this table → G.1/G.2 + ADR required.

### G.4 Knob Safety Matrix

| Change Risk | Knobs |
|---|---|
| **LOW** (freely changeable in Tier 1) | `cause_taxonomy_entries` (append-only) |
| **MEDIUM** (other GDD updates required on change) | imported knobs (owned by Time Rewind / Boss Pattern — route through those GDDs), `hazard_grace_frames` |
| **HIGH** (ADR required on change) | `collision_layer/mask` bit matrix, `friendly_fire_enabled` toggle, **monotonic phase advance** (D.2.3) |
| **LOCKED** (change forbidden in Tier 1) | `hurtbox_default_monitorable`, `hitbox_default_monitoring`, `debug_unset_cause_emit_value`, `damage_frame_budget_ms`, `area2d_max_active`, all DEC-1–6 |

### G.5 Debug-only knobs + Steam Deck multiplier

**Debug-only push_error guard** (performance-analyst recommendation):

```gdscript
# In D.3.4 fallback:
if hb.cause == &"" and not _resolved_cause:
    if OS.is_debug_build():
        push_error("HitBox cause unset: %s" % hb.get_path())
    emit_cause = &"unknown"
```

Reason: Unset cause cases with 30 hazards × 60fps would call push_error 1,800 times/sec → stderr load + performance regression masking in release builds. `OS.is_debug_build()` guard makes it a silent fallback in release (signal still emits as `&"unknown"` — safety net preserved).

**Steam Deck CPU multiplier** (performance verification obligation):

| Environment | Estimated CPU Multiplier | Damage Budget Conversion |
|---|---|---|
| Dev PC (M1 Pro / Ryzen 5800X etc.) | 1.0× baseline | 1.0 ms target |
| **Steam Deck (Zen 2 4-core)** | **2.5× slower (conservative)** | **2.5 ms measured limit — exceeding 15% of 16.6ms frame is fail** |

**Obligation**: Before Tier 1 gate closes, measure Damage cumulative cost in *worst-case combat scene* (5 enemies + 20 projectiles + 5 hazards) on Steam Deck or Deck-equivalent throttled CPU. AC-30 new.

### G.6 Per-Tier Knob Activation Schedule (reference)

| Tier | Newly Activated |
|---|---|
| Tier 1 | All G.1 + G.5 LOCKED values (DEC-1–6) |
| Tier 2 | `friendly_fire_enabled` game-mode flag review, `area2d_max_active` 160 ceiling verification |
| Tier 3 | G.3 candidates (Easy auto_rewind, hit_stun_duration etc.) — separate ADR required |

---

## H. Acceptance Criteria

> **Status**: Approved 2026-05-09. All ACs are testable. Test Type column applies the coding-standards.md "Test Evidence by Story Type" matrix.

### H.1 Component Contracts (AC-1 ~ AC-4)

| AC | Verification Content | Test Method | Type |
|---|---|---|---|
| **AC-1** | `class_name HitBox extends Area2D` explicitly declared + holds `cause: StringName` (default `&""`) + `host: Node` + `monitoring: bool` (default `true`) | GUT: ClassDB.class_exists("HitBox") + instance property query | Logic |
| **AC-2** | `class_name HurtBox extends Area2D` explicitly declared + holds `entity_id: StringName` + `monitorable: bool` (default `true`) + `signal hurtbox_hit(cause: StringName)` | GUT: ClassDB + signal signature inspection | Logic |
| **AC-3** | `HitBox.area_entered(area)` handler calls `(area as HurtBox).hurtbox_hit.emit(self.cause)` only when `area is HurtBox` guard passes | GUT: HitBox + non-HurtBox Area2D collision → emit 0 times + duck-typed Area2D (has hurtbox_hit signal but does not inherit HurtBox) also emit 0 times | Logic |
| **AC-4** | ECHO Damage component exposes public methods `commit_death() -> void` + `cancel_pending_death() -> void` + `start_hazard_grace() -> void` (DEC-6 addition) | GUT: `has_method` verification for all 3 methods | Logic |

### H.2 Collision Predicate / Layer Matrix (AC-5 ~ AC-7)

| AC | Verification Content | Test Method | Type |
|---|---|---|---|
| **AC-5** | 6 bit assignments in C.2.1 exactly as specified (`echo_hurtbox=1`, `echo_projectile_hitbox=2`, `enemy_hurtbox=3`, `enemy_projectile_hitbox=4`, `hazard_hitbox=5`, `boss_hurtbox=6`) + each host .tscn instance layer/mask matrix matches | GUT: instantiate 6 host components + query collision_layer/mask values + strict comparison against C.2.2 matrix | Logic |
| **AC-6a** | D.1.1 cond (1) `hb.monitoring == false` → `hit = false` | GUT: HitBox.monitoring=false + normal layer/mask + overlap → emit 0 times | Logic |
| **AC-6b** | D.1.1 cond (2) `hh.monitorable == false` → `hit = false` | GUT: HurtBox.monitorable=false + normal layer/mask + overlap → `HitBox.area_entered` fires 0 times | Logic |
| **AC-6c** | D.1.1 cond (3) `layer_mask_check == false` → `hit = false` | GUT: mismatched layer/mask + overlap → emit 0 times | Logic |
| **AC-6d** | D.1.1 cond (4) `shape_overlap == false` → `hit = false` | GUT: normal layer/mask + non-overlapping position → emit 0 times | Logic |
| **AC-7** | ECHO Projectile HitBox (L2, mask `0b100100`) + ECHO HurtBox (L1) geometric overlap attempt → `HitBox.area_entered` emit 0 times (self-damage blocked). Separately, bit verification that ECHO Projectile mask does *not include* L4 (`0b001000`) | GUT: two Area2D geometric overlap + emit count + collision_mask `& 0b001000 == 0` verification | Logic |

### H.3 ECHO 2-stage Death (AC-8 ~ AC-12)

| AC | Verification Content | Test Method | Type |
|---|---|---|---|
| **AC-8** | On ECHO HurtBox area_entered, within same frame: `_pending_cause = cause` set, then `lethal_hit_detected(cause)` + `player_hit_lethal(cause)` each emitted exactly once (ordering invariant). Both signals have identical cause argument. **Added (Round 3)**: `HurtBox.hurtbox_hit` signal emitted exactly once (from HitBox side — C.1.2 step 2). Damage `_on_hurtbox_hit` handler does *not re-emit* `hurtbox_hit` | GUT: spy emit count (lethal_hit_detected=1, player_hit_lethal=1, hurtbox_hit=1, **re-emit 0 times**) + cause comparison + `_pending_cause` verification at emit time | Logic |
| **AC-9** | E.1 same-frame multi-hit: first emit sets `_pending_cause = cause₀`. **Round 5 update (2026-05-10)**: second hit is *primarily* immediately returned by Damage step 0 first-hit lock (C.3.2) → `lethal_hit_detected`/`player_hit_lethal` both emit 0 times. SM `_lethal_hit_latched` is secondary defence (active only if Damage step 0 is bypassed). `_pending_cause` maintains cause₀ — verification point is the same. | Integration: Damage component + SM stub + second area_entered → emit-count 0 times + `_pending_cause == cause₀` strict comparison (see AC-36 first-hit lock detail GUT scenario) | **Integration** |
| **AC-10** | When SM calls `damage.commit_death()`: `death_committed(_pending_cause)` emits + `_pending_cause == &""` after call | GUT: pre-set `_pending_cause` + commit_death call + spy | Logic |
| **AC-11** | When SM calls `damage.cancel_pending_death()`: `death_committed` emit 0 times + `_pending_cause == &""` after call | GUT: cancel_pending_death + emit count | Logic |
| **AC-12** | REWINDING simulation (echo_hurtbox.monitorable = false) + enemy HitBox area fired → `HitBox.area_entered` fires 0 times → `lethal_hit_detected` emit 0 times | Integration: SM RewindingState.enter() + HitBox spawn + spy count both signals | Integration |

### H.4 Boss Phase Transition (AC-13 ~ AC-16)

| AC | Verification Content | Test Method | Type |
|---|---|---|---|
| **AC-13** | D.2.1 branches: `remaining' > 0` → `boss_hit_absorbed(boss_id, phase_index)` emit (2-arg, DEC-5). `remaining' == 0 ∧ phase_index < final` → `boss_pattern_interrupted` then `boss_phase_advanced`. `remaining' == 0 ∧ phase_index == final` → `boss_pattern_interrupted` then `boss_killed` | GUT: 3 branch scenario emit spy + signal emit order verification (F.4.1 contract) | Logic |
| **AC-14** | E.4 same-frame multi-hit + **worst-case `phase_hp_table[next]=1`** (Round 3): `phase_hp_table=[2,1,5]`, `phase_index=0`, `phase_hits_remaining=2`, same-frame 3 hits → `boss_phase_advanced` exactly once (without lock: fires twice — D.2.3 counterexample). `phase_index` exactly +1 (single step only). `boss_pattern_interrupted` also exactly once. `_phase_advanced_this_frame` verification: true after `area_entered` callback, false reset at start of next `_physics_process` (D.2.3 lock invariant) | GUT: 3 simultaneous area_entered simulation + phase_index verification + signal count + lock flag lifecycle verification | Logic |
| **AC-15** | E.11 host misuse: Boss host's static method `validate_phase_table(table: Array[int], final_idx: int) -> bool` verifies (a) `table.size() == final_idx + 1` and (b) `table.all(func(v): return v >= 1)` (DEC-2 addition). Returns false for 4 invalid input cases | GUT: unit test that directly calls validate_phase_table (Boss instantiation not required — also verifiable in release builds) | Logic |
| **AC-16** | After `boss_phase_advanced` fires, `phase_hits_remaining == phase_hp_table[new_phase_index]` (new phase HP reloaded). `boss_pattern_interrupted` emit occurs *before* `boss_phase_advanced` (F.4.1 ordering) | GUT: member variable verification after transition + emit order spy | Logic |

### H.5 Hazard + Cause Taxonomy (AC-17 ~ AC-19)

| AC | Verification Content | Test Method | Type |
|---|---|---|---|
| **AC-17** | Hazard HitBox (L5) area_entered to ECHO HurtBox (L1) → C.3.2 normal flow. Emitted cause is the hazard instance's `cause` label (`&"hazard_spike"` etc.) as-is. cause has `&"hazard_"` prefix (DEC-6 prefix invariant) | GUT: hazard with cause + ECHO HurtBox + cause comparison + `cause.begins_with("hazard_")` verification | Logic |
| **AC-18a** | E.14 misuse: HitBox.cause unset (`&""`) + host not Boss/Enemy → emit value = `&"unknown"` (silent handling preserved) | GUT: HitBox with empty cause + hit simulation + signal argument verification | Logic |
| **AC-18b** | (ADVISORY — manual if automation not possible) In `OS.is_debug_build() == true` environment, running AC-18a scenario shows `push_error` once in Godot Output panel | Visual / Manual: debug build run + Output panel check. Verify push_error does not occur in release builds | Visual |
| **AC-19** | Boss Projectile HitBox is explicitly set `hb.cause = &"projectile_boss"` by Boss host at instantiation time (D.3.1 table host contract). C.1.2 emit propagates `self.cause` as-is — no branching logic. On ECHO hit, `lethal_hit_detected` argument is `&"projectile_boss"` | GUT: Boss child HitBox projectile (cause set in `_ready()`) + ECHO HurtBox hit simulation + cause comparison | Logic |

### H.6 i-frame Coordination (AC-20 ~ AC-22)

| AC | Verification Content | Test Method | Type |
|---|---|---|---|
| **AC-20** | On SM `RewindingState.enter()` call: `echo_hurtbox.monitorable == false`. On `RewindingState.exit()` call: `echo_hurtbox.monitorable == true` + `damage.start_hazard_grace()` called once | Integration: SM transition + direct monitorable value query + invocation spy | Integration |
| **AC-21** | Code search of Damage system shows 0 SM state queries (`state_machine.<member>` all access + `get_node("StateMachine").current_state` and other alias paths) | CI: `tools/ci/damage_static_check.sh` runs two greps → exit code 0 (no matches): (1) `grep -rE "state_machine\.[a-zA-Z_]+" src/systems/damage/` (blocks all member access — Round 4 broadening), (2) `grep -rE 'get_node\(.*StateMachine.*\)\.[a-zA-Z_]+' src/systems/damage/` (blocks node-path aliases). Additionally, PR review checklist (ADVISORY) states obligation to update regex when new SM members are named. | Logic (static) |
| **AC-22** | D.1 cond (2) failure simulation: `echo_hurtbox.monitorable = false` + enemy HitBox area geometric overlap → `HitBox.area_entered` fires 0 times (Godot 4.6 Area2D semantics verification) | GUT: HurtBox.monitorable=false + HitBox.monitoring=true + geometric overlap + HitBox spy → area_entered emit 0 times | Logic |

### H.7 Edge Cases Coverage (AC-23 ~ AC-25)

| AC | Verification Content | Test Method | Type |
|---|---|---|---|
| **AC-23** | (consolidated into AC-7 — `hurtbox_hit` end-to-end self-damage block verification) ECHO Projectile node spawn + 5 frame physics steps + passes through position overlapping ECHO HurtBox → `hurtbox_hit` emit 0 times | Integration: full spawn→move→collision cycle verified with physics_frame await | Integration |
| **AC-24** | E.13 hazard grace (DEC-6, Round 4 B-R4-1 fix): On RewindingState.exit(), `_hazard_grace_remaining = hazard_grace_frames + 1 = 13` set. Same-frame priority-2 decrement → 12. Subsequent 12 flush windows (F0+1 ~ F0+12) block hazard `lethal_hit_detected` + enemy projectile cause is normal hit. Hazard hits resume from F0+13 flush (counter=0). Expiry is spec'd 12 flushes — fail if 13 flushes are blocked (off-by-one regression). | Integration: REWINDING end + pre-placed hazard + 13 internal physics steps + per-cause emit count verification (12 blocked + 1 pass) | Integration |
| **AC-25** | E.12 projectile same-frame destroy: enemy projectile hits ECHO and calls `queue_free()` in same frame → `hurtbox_hit` emit normal 1 time + `await get_tree().physics_frame` then `is_instance_valid(projectile) == false` | GUT: hit + immediate queue_free + emit 1 time + next frame instance valid verification | Logic |

### H.8 Bidirectional Dependencies (AC-26 ~ AC-27)

| AC | Verification Content | Test Method | Type |
|---|---|---|---|
| **AC-26** | `design/gdd/time-rewind.md` F.1 table row #8 has no *(provisional)* tag + this GDD link (`design/gdd/damage.md`) exists + `lethal_hit_detected`/`death_committed` signatures specified | PR Review checklist (advisory): after F.5 update, grep `provisional` in `time-rewind.md`'s #8 row + link check | Manual |
| **AC-27** | `design/gdd/state-machine.md` F.1 table row #8 has no `provisional contract` tag + `player_hit_lethal(cause: StringName)` 1-arg signature specified + AC-22 reconcile note exists | PR Review checklist (advisory): after F.5 update, grep + signature line check | Manual |

> **AC-26/AC-27 policy change**: These two ACs are *document state checks* and are unsuitable as BLOCKING automated test gates (qa-lead recommendation). Downgraded to ADVISORY items in PR Review checklist. CI automation reverts to BLOCKING when `tools/ci/gdd_consistency_check.gd` (OQ-DMG-5) is written.

### H.9 New ACs (AC-28 ~ AC-36 — coverage gaps + DEC-5/6/F.4.1 + Round 5 first-hit lock)

| AC | Verification Content | Test Method | Type |
|---|---|---|---|
| **AC-28** | F.4.1 connect order invariant: After ECHO `_ready()` executes, index 0 of `damage.lethal_hit_detected.get_connections()` is TRC, index 0 of `damage.player_hit_lethal.get_connections()` is SM. This AC fails if order changes | GUT: `_ready()` execution + `get_connections()` inspection | Logic |
| **AC-29** | F.4.2 same-frame multi-enemy death emit order (Pillar 2 determinism): enemies A, B, C same-frame death simulation 1000 times → `enemy_killed` emit order *matches fixed fixture expected order in all 1000 cycles* (scene-tree-order based). | GUT: determinism 1000-cycle test. **expected_order is single-source defined by fixture** (e.g., `const EXPECTED_ORDER := [&"enemy_A", &"enemy_B", &"enemy_C"]` — parent-child + sibling index specified). Each cycle's actual emit order strict equality compared to fixture (run-1 self-capture forbidden — Round 4 fix; baseline self-reference passes even broken-from-t=0 systems). Fail if any single cycle mismatches. | Logic |
| **AC-30** | G.5 Steam Deck performance budget: 5 enemies + 20 projectiles + 5 hazards simultaneously active + 60fps 5-minute play: Damage system cumulative cost ≤ 2.5ms (Deck-equivalent throttled CPU) | Integration: Godot profiler + Deck-equivalent build (or Steam Deck measurement) + per-frame breakdown screenshot | Integration |
| **AC-31** | `commit_death()` idempotency: when called with `_pending_cause == &""`, `death_committed` emit 0 times + no state change | GUT: unset state commit_death + spy | Logic |
| **AC-32** | `cancel_pending_death()` idempotency: when called with `_pending_cause == &""`, silent no-op (no error) | GUT: unset state cancel_pending_death + push_error spy 0 times | Logic |
| **AC-33** | DEC-6 hazard grace diagnostic predicate: `should_skip_hazard(cause)` 4-case verification — (a) `_hazard_grace_remaining=0 + cause=hazard_spike` → false (b) `=12 + hazard_spike` → true (c) `=12 + projectile_enemy` → false (d) `=12 + cause=&""` → false | GUT: direct call for 4 cases | Logic |
| **AC-34** | `enemy_killed` signal full path: ECHO Projectile HitBox (L2) → Enemy HurtBox (L3) area_entered → `enemy_killed(entity_id, cause)` emit 1 time + cause determined by ECHO Projectile's `host` branch (D.3.1) | GUT: ECHO Projectile + Enemy HurtBox simulation + spy | Logic |
| **AC-35** | Layer completeness: when each of 6 hosts (`echo`, `echo_proj`, `enemy`, `enemy_proj`, `hazard`, `boss`) is instantiated, collision_layer has exactly single bit set + collision_mask exactly matches C.2.2 matrix | GUT: load 6 host .tscn + strict comparison of all 12 values (layer×6 + mask×6) | Logic |
| **AC-36** | C.3.2 step 0 first-hit lock (Round 5 cross-doc S1 fix 2026-05-10): ECHO Damage `_on_hurtbox_hit` entered with `cause₀` → `_pending_cause = cause₀`, `lethal_hit_detected` emit 1 time, `player_hit_lethal` emit 1 time. Re-entered with `cause₁` during *same frame N* or *DYING window N+1..N+11* → step 0 guard detects `_pending_cause != &""` → returns immediately → `_pending_cause` unchanged (`cause₀` preserved) + `lethal_hit_detected` emit 0 times (TRC `_lethal_hit_head` re-cache blocked) + `player_hit_lethal` emit 0 times. After `commit_death()` call, `_pending_cause = &""` cleared → next lethal event passes normally. | GUT: ECHO Damage instance + first `hurtbox_hit(cause₀)` + immediate second `hurtbox_hit(cause₁)` + `lethal_hit_detected`/`player_hit_lethal` emit-count spy + `_pending_cause` member strict comparison. Additional scenario: verify clear after `commit_death()` call + new `hurtbox_hit(cause₂)` → normal 1 emit. | Logic |

### H.10 Test File Layout (updated)

```text
tests/unit/damage/
├── damage_component_contract_test.gd       # AC-1 ~ AC-4 + AC-35
├── damage_collision_predicate_test.gd      # AC-5 ~ AC-7
├── damage_2stage_death_test.gd             # AC-8, AC-10, AC-11, AC-31, AC-32
├── damage_boss_phase_test.gd               # AC-13 ~ AC-16
├── damage_cause_taxonomy_test.gd           # AC-17 ~ AC-19
├── damage_iframe_coordination_test.gd      # AC-22, AC-33
├── damage_edge_cases_test.gd               # AC-25
├── damage_misuse_test.gd                   # AC-15, AC-18a
├── damage_signal_ordering_test.gd          # AC-28
├── damage_emit_determinism_test.gd         # AC-29 (1000-cycle)
└── damage_enemy_killed_test.gd             # AC-34

tests/integration/damage/
├── damage_rewinding_iframe_test.gd         # AC-12, AC-20
├── damage_hazard_grace_test.gd             # AC-24 (DEC-6)
├── damage_self_harm_e2e_test.gd            # AC-23 (consolidated)
├── damage_2stage_dying_latch_test.gd       # AC-9 (Integration moved)
└── damage_perf_budget_test.gd              # AC-30 (Steam Deck)

production/qa/evidence/damage/
├── damage_bidirectional_check_YYYYMMDD.md  # AC-26, AC-27 (PR review checklist)
└── damage_push_error_visual_check.md       # AC-18b (debug-build manual)

tools/ci/
└── damage_static_check.sh                   # AC-21 (grep CI)
```

### H.11 AC Statistics (Round 3 update — count math correction)

- **Total**: 39 AC
- **Logic GUT**: 29 (AC-1, 2, 3, 4, 5, 6a, 6b, 6c, 6d, 7, 8, 10, 11, 13, 14, 15, 16, 17, 18a, 19, 22, 25, 28, **29**, 31, 32, 33, 34, 35) — AC-29 (determinism 1000-cycle) explicitly enumerated
- **Integration**: 6 (AC-9, AC-12, AC-20, AC-23, AC-24, AC-30)
- **Visual / Manual (ADVISORY)**: 3 (AC-18b debug build push_error, AC-26/27 PR checklist)
- **Static CI**: 1 (AC-21 — `tools/ci/damage_static_check.sh`)
- **Sum verification**: 29 + 6 + 3 + 1 = **39 ✓**
- **Determinism 1000-cycle**: 1 (AC-29) — Pillar 2 determinism gate
- **New ACs (Round 2)**: AC-6a~6d (split), AC-18a/b (split), AC-28~35 (8 new)
- **Round 3 updated ACs**: AC-8 (added hurtbox_hit re-emit 0 times), AC-14 (worst-case `phase_hp_table[next]=1` + lock flag lifecycle), AC-19 (reframed as cause set at host instantiation)

> **Previous "Logic GUT: 27" error correction (Round 3)**: enumerated 28 + AC-29 implied = actual 29. New enumeration explicitly includes AC-29 to remove ambiguity.

---

## Z. Open Questions

> **Status**: Approved 2026-05-09.

| ID | Category | Question | Decision Point | Resolution Path |
|---|---|---|---|---|
| **OQ-DMG-1** | Future Tuning | Design of Tier 2 `friendly_fire` game mode — in combat playground / boss rush, are enemies killing each other *allowed*, *allowed but stats invalidated*, or *fully blocked*? | Tier 2 gate (when Game Modes system is introduced) | Game Designer review + cross-check when writing Player Movement #6 / Enemy AI #10 GDDs |
| ~~**OQ-DMG-2**~~ ✅ Resolved RR3 | Boss Cleanup | Handling of *existing boss projectiles* at Boss `phase_advanced` → `boss_pattern_interrupted` emit + Boss Pattern SM self-cleanup | C.4.2 + F.3 | DEC-RR3 |
| ~~**OQ-DMG-3**~~ ✅ Resolved RR4 | Boss Cleanup | Summon cleanup responsibility on `boss_killed` → Boss Pattern GDD #11 holds own summon registry + subscribes to `boss_killed` | C.4.2 + F.2 | DEC-RR4 |
| **OQ-DMG-4** | Pickup System | When Tier 2 system #15 (Pickup) is introduced, is collision_layer bit 7+ assignment + priority matrix with ECHO HurtBox needed? E.6 only describes *when it occurs*. | Tier 2 gate + when writing Pickup GDD | Pickup GDD *appends* this GDD's C.2 matrix to assign bit 7. Update E.6 table to *resolved*. |
| **OQ-DMG-5** | Tooling | Can H.8 (AC-26, AC-27) bidirectional check be CI automated? (e.g., grep + regex to verify absence of *(provisional)* tag in other GDD's row #8) | When DevOps system is built | Automate with `tools/ci/gdd_consistency_check.gd` or shell script. In current Tier 1: PR review checklist (ADVISORY). |
| **OQ-DMG-6** | Pillar Tuning | Should SM grant ECHO a *short grace* (e.g., 6-frame i-frame) at boss phase advance moment? Helps avoid phase transition explosion vs dilutes 1-hit catharsis | Tier 1 playtesting (after first boss encounter verification) | Current baseline: *not granted* — Pillar 1-hit consistency priority. Consider adding SM `BossPhaseGraceState` based on playtesting results. |
| **OQ-DMG-7** | Tier 1 Scope | Number of Tier 1 enemy archetypes — 1 type (drone only) vs 3 types (drone, security bot, STRIDER trash mobs). With 3 types: cause taxonomy `projectile_enemy_*` sub-entry addition required (B.3 learnability) | When writing Enemy AI GDD #10 | Enemy AI GDD determines archetype count → Damage GDD C.5.2 taxonomy update + VFX/Audio GDD mapping additions |
| **OQ-DMG-8** | ADR Queue | Write `D.2.3 monotonic +1 phase advance lock` ADR — explicitly state permanent closure of design space for perfect parry/skill skip | Immediately before writing Boss Pattern GDD #11 | `/architecture-decision boss-phase-advance-monotonicity` |
| **OQ-DMG-9** | ADR Queue | `signal emit ordering determinism` ADR — elevate F.4.1/F.4.2 determinism contract to architecture-level decision | Immediately before starting Tier 1 prototype | `/architecture-decision signal-emit-order-determinism` |
| **OQ-DMG-10** | Performance | Acquire Steam Deck measurement environment or set up Deck-equivalent throttled CPU build (AC-30 verification obligation) | Immediately before Tier 1 gate closes | DevOps + technical-director — measure Damage budget on Deck or equivalent environment |

### Resolved During Authoring (reference)

Questions *resolved* in this session:

| ID | Question | Decision | Location |
|---|---|---|---|
| OQ-SM-1 | `Damage.player_hit_lethal` signature | 1-arg `cause: StringName` | DEC-1 (top of this GDD) |
| (provisional in time-rewind) | Damage signal signatures | `lethal_hit_detected(cause)` + `death_committed(cause)` 1-arg | C.3.1 |
| (provisional in time-rewind) | hazard integration signals | All hazards use the same `lethal_hit_detected/player_hit_lethal` path + differentiated by cause label | C.5 + D.3 |
| (skeleton OQ) | i-frame control owner | SM toggles `echo_hurtbox.monitorable` (DEC-4) | C.6 + D.4 |
| OQ-DMG-RR1 (round 2) | Whether `boss_hit_absorbed` signature includes hits_remaining | DEC-5 — reduced to 2-arg (boss_id, phase_index). Protects binary data contract | C.4.2 + F.3 |
| OQ-DMG-RR2 (round 2) | E.13 hazard permanent residence policy | DEC-6 — 12-frame hazard-only grace + Pillar 1 protection | C.6.4 + E.13 |
| OQ-DMG-RR3 (round 2) | In-flight active pattern continuity | New `boss_pattern_interrupted` signal — Boss Pattern SM has cleanup responsibility | C.4.2 + F.3 |
| OQ-DMG-RR4 (round 2) | Summon cleanup owner | Boss Pattern GDD #11 holds own summon registry + subscribes to `boss_killed` to self-free | C.4.2 + F.2 |

---

## Appendix A. References

- `design/gdd/time-rewind.md` — System #9 (imposes 2-stage death obligation: Rule 4 + E-11)
- `design/gdd/state-machine.md` — System #5 (player_hit_lethal subscriber, AC-22 1-arg assumption → this GDD locks it in)
- `design/gdd/game-concept.md` — Pillar 1-hit kill (Challenge primary)
- `docs/architecture/adr-0003-determinism-strategy.md` — process_physics_priority ladder (enemies = 10, projectiles = 20)
- `docs/registry/architecture.yaml` — `forbidden_patterns.cross_entity_sm_transition_call`, `damage_polls_sm_state`, `rigidbody2d_for_gameplay_entities`, `api_decisions.collision_layer_assignment`, `interfaces.damage_signals`, `state_ownership.boss_phase_state`
- `.claude/docs/technical-preferences.md` — Naming + 16.6ms budget
- **Queued ADR**: `boss-phase-advance-monotonicity` (OQ-DMG-8 — D.2.3 lock)
- **Queued ADR**: `signal-emit-order-determinism` (OQ-DMG-9 — F.4.1 / F.4.2 lock)
- **Round 2 review (2026-05-09)**: 7-specialist adversarial review + creative-director synthesis. Verdict: MAJOR REVISION → all 8 BLOCKING + 12 RECOMMENDED applied. DEC-5/6 + 8 new ACs + ordering contract + Steam Deck verification obligation added.
