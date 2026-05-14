# Time Rewind GDD Review Log

Design review history for `design/gdd/time-rewind.md`. Prepend new reviews *above*.

---

## Review — 2026-05-10 (Round 2) — Verdict: APPROVED → 7 RECOMMENDED applied + 1 cosmetic fix

Scope signal: **XL** (carryover) — but re-review surface narrow under Round 1 directive (only empirical falsification or cross-doc contradiction can BLOCK).
Specialists consulted: none (lean mode, single-session per `production/review-mode.txt` + Round 1 lock directive — Phase 3b skipped).
Senior: self-synthesis under Round 1 directive constraints.
Blocking items: **0** | Recommended applied this session: **7** | New cosmetic: **1** | Deferred (post-lock observations from Round 1): **11 unchanged**

### Summary

Round 2 lean re-review of System #9 Time Rewind GDD verified all 6 Round 1 BLOCKING items applied at every cited site (grep verification: Rule 16/I2/E-06 priority ladder · Rule 4 + AC-A3 + formula table H_lethal · D2 + ADR-0002 grant_token cap · ADR-0001 Amendment 1 ≤25 KB at 4 sites · ADR-0002 Decision section _lethal_hit_head with assert + Superseded subsection · game-concept Core Fantasy/Hook/verification-bullet/Mechanics 4 sites). Cross-doc consistency confirmed against damage.md F.4.1/DEC-1/C.3 and state-machine.md C.2.2 O1-O6 — TRC connect-first invariant, 1-arg `player_hit_lethal(cause: StringName)` signature, 6 SM obligations citing time-rewind.md Rule 17/18/16/E-16 verbatim, and process_physics_priority ladder (player=0 / TRC=1 / Damage=2 / enemies-Boss=10 / projectiles=20) all consistent.

No items qualified as BLOCKING under Round 1 directive criteria. The 7 RECOMMENDED items deferred to "next session" by user [A] in Round 1 were applied this session. 1 new cosmetic finding (AC count math 33→34 oversight in Round 1 sum) corrected.

### Round 1 BLOCKING — Verification Pass (all 6 ✓)

| ID | Verification |
|---|---|
| BLOCK-R1-1 (priority invariant) | Rule 16 (L95) + I2 (L145) + E-06 (L373) — consume-then-grant ladder consistent |
| BLOCK-R1-2 (signal split) | Rule 4 (L74) + H_lethal table (L178) + AC-A3 (L606) — TRC/SM split correct |
| BLOCK-R1-3 (D2 cap) | time-rewind.md L208 + ADR-0002 L161 grant_token() — synced |
| BLOCK-R1-4 (Amendment 1) | ADR-0001 status (L4) + Verification Required #3 (L30) + Performance Implications (L241) + Validation Criteria #1 (L253) — 4 sites updated |
| BLOCK-R1-5 (authoritative pseudocode) | ADR-0002 Decision (L140-157) + assert (L151) + Superseded subsection (L165) |
| BLOCK-R1-6 (game-concept copy) | Core Fantasy (L34) + Unique Hook (L42) + verification bullet (L49) + Core Mechanics (L75) |

### Round 2 RECOMMENDED Applied (7)

- **R2-1 (AC-C2 latch clear path — Round 1 GAP-1 systems-designer)**: AC-C2 reframed to assert `_lethal_hit_latched == false` on direct DYING→DEAD path; AC-C3 retained for REWINDING→ALIVE path. Rule 17 latch invariant now has *both* clear paths covered by tests, closing the previously asymmetric coverage.
- **R2-2 (E-23 Level Script Bypass — Round 1 GAP-2 systems-designer + godot-specialist)**: New Edge Case subsection "Level Script Bypass" with E-23 specifying that level scripts (cinematic triggers, scripted kill volumes, BossArenaScript) calling `Damage.commit_death()` directly must check `damage.is_in_iframe(player)` first. Damage GDD F.5 expected helper noted; dev-build assertion on REWINDING-time lethal commit; Tier 2+ Level Design Guide obligation tagged.
- **R2-3 (monitorable set_deferred — Round 1 godot-specialist Bug 3)**: Rule 11 changed from direct `echo_hurtbox.monitorable = true` assignment to `echo_hurtbox.set_deferred("monitorable", true)`. Rationale: physics callback context race-safety (4.6 PhysicsServer behavior).
- **R2-4 (D6 methodology + 1ms sub-partition — Round 1 BV-3 systems-designer + HIGH-1+2 performance-analyst)**: `t_field_copy` corrected from ~6 ns (native assumption) to ~100–500 ns (GDScript interpreter overhead). Capture per-tick recomputed: 0.8–4 μs worst case (was 50 ns). Conclusion (within 1 ms envelope) unchanged — methodology fix only. Added new "1ms Envelope Sub-Partition" table partitioning the 1 ms cap across Shader (≤500 μs / OQ-11) + Restore (≤300 μs / AC-E2) + Headroom (200 μs). Added Steam Deck Zen 2 baseline obligation for AC-E4 (no dev-machine 1:1 transfer).
- **R2-5 (AC-D4/D5 frame-perfect injection harness — Round 1 qa-lead)**: Both ACs now reference a `frame-perfect injection helper` fixture pattern that stubs `Engine.get_physics_frames()` polling and uses signal injection for deterministic frame-ordering control. AC-D5 reuses AC-D4 harness pattern.
- **R2-6 (AC-E1 reclassification — Round 1 qa-lead)**: AC-E1 changed from [AUTO] to [MANUAL] (Profiler-based; GUT headless cannot drive Godot editor Profiler) with a [AUTO] supplementary check using `Time.get_ticks_usec()` delta. Both must PASS for the AC to pass.
- **R2-7 (@export var player wiring — Round 1 godot-specialist)**: Section C.3 #6 row Player Movement entry now mandates `@export var player: PlayerMovement` declarative wiring; `get_parent()` and implicit lookup forbidden. Editor validates missing reference at scene save.

### New Cosmetic Fix

- **R2-Cosmetic (AC count 33→34)**: Acceptance Criteria header L599 declared "33 criteria" but actual enumeration is 34 (A:5 / B:8 / C:6 / D:5 / E:4 / F:2 / G:4). Header updated to "34 criteria" with breakdown.

### Round 1 Deferred Post-Lock Observations (11 unchanged)

Per Round 1 director directive — log only, do not gate prototype:
- C1 42-frame compound invulnerability (game-designer, Tier 1 playtest)
- C3 Tier 3 boss-kill refill at peak content (Tier 3 design)
- C4 Easy mode infinite=true Pillar 1 break (Tier 2/3 Difficulty Toggle GDD)
- I1 HUD aesthetic ownership gap (Tier 1 polish)
- I2 Hard 8-frame DYING window punitive feel (Tier 2 difficulty)
- I3 Shader self-terminate desync (apply only if const changes)
- I4 dry-thunk denial SFX tonal mismatch Hard (Tier 2 sound-designer)
- L1 grant_on_boss_kill diegetic bridge (narrative-director post-prototype)
- godot-specialist OQ-9 / E-21 / connect-order (Tier 1 Week 1 validation)
- performance-analyst MEDIUM AC build/encounter/CanvasLayer (Tier 1/2 perf-pass)
- performance-analyst LOW D5 worst-case 36 KB / field-add gate / AC-E3 thermal (Tier 1 perf)

### Director Directive (Round 3 carryover)

**Round 3 blocked** except for:
- (a) Locked Decision empirical falsification (spec-vs-actual mismatch discovered during Tier 1 prototype verification)
- (b) Cross-document contradiction discovered after lock

Aesthetic-only findings go to post-lock observations log only — add review-log entry only after Tier 1 playtest.

**Empirical falsification examples that WOULD reopen the lock**: Steam Deck profiling exceeds 1 ms / shader sub-cap (500 μs) / restore sub-cap (300 μs); Tier 1 playtest validates C1 0.7s safety-net reading; memory measurement exceeds 25 KB; priority ladder breaks (Boss Pattern GDD assigns priority < 2); GDScript field-copy measured outside 100–500 ns envelope.

### Validation Criteria — How We'll Know Round 2 Was Right

- Tier 1 prototype memory ≤ 25 KB on first measurement (validates BLOCK-R1-4)
- Tier 1 prototype TRC subsystem ≤ 1 ms on Steam Deck Zen 2 with sub-partition (validates R2-4)
- AC-C2 latch-clear assertion catches a Rule 17 regression in Tier 1 unit tests (validates R2-1)
- Frame-perfect injection harness produces deterministic AC-D4/D5 PASS across 100 reruns (validates R2-5)
- AC-E1 [MANUAL] Profiler + [AUTO] Time.get_ticks_usec() agree within ±2 μs jitter envelope (validates R2-6)
- E-23 trigger surfaces in any Tier 2+ scripted encounter without `is_in_iframe()` check (validates R2-2 — surfaces gap, doesn't break)

### Files Modified This Session

- `design/gdd/time-rewind.md` (11 edits across Section C/D/E/Acceptance Criteria + new "Level Script Bypass" subsection)
- `design/gdd/systems-index.md` (System #9 status row → Approved Round 2 + Last Updated header + Progress Tracker counts 2→3 approved / 1→0 designed-pending)
- `design/gdd/reviews/time-rewind-review-log.md` (this entry — prepended above Round 1)

---

## Review — 2026-05-10 (Round 1) — Verdict: MAJOR REVISION NEEDED → 6 BLOCKING applied

Scope signal: **XL** — 3 ADR cross-cut (0001/0002/0003), 6 formula (D1-D6), cross-document contradiction with locked Damage GDD, 5 specialist convergence on single root defect.
Specialists consulted: game-designer (async ✓), systems-designer (async ✓), qa-lead (async ✓), godot-specialist (async ✓), performance-analyst (async ✓)
Senior: creative-director (synthesis)
Blocking items: **6** | Recommended: **9 (deferred to next session per user [A] choice)** | Deferred (post-lock observations): **11**

### Summary

First Round 1 review of System #9 Time Rewind GDD (745 lines). 5 specialists spawned in parallel (full mode per skill default; `production/review-mode.txt` says lean for director gates which is independent of `--depth`). Three specialists (systems-designer + godot-specialist + qa-lead) independently identified the same root defect — Rule 16/I2 priority invariant inversion — making it the strongest convergent signal in the review.

Beyond that, structural defects in formula (D2 missing max_tokens cap), cross-document contradiction with locked Damage GDD (AC-A3 names `player_hit_lethal` but TRC subscribes to `lethal_hit_detected` per Damage F.1 #8), ADR drift (ADR-0001 ≤5 KB validation criterion auto-fails after Amendment 1 cosmetic correction in ADR-0002 not propagated), ADR-0002 broken pseudocode in primary Decision section, and player-facing copy contradiction ("recover 1 second" in game-concept.md vs 0.15s mechanic).

creative-director synthesis: Time Rewind is Echo's *unique hook* — failure = concept failure. Damage Round 4 lean precedent (defer non-empirical concerns) does not transfer wholesale; the bar is necessarily higher. 6 BLOCKING are all *structural defects* (wrong invariants, missing cap expressions, cross-doc contradictions, ADR drift, ship-stopper copy mismatch), not aesthetic preferences. game-designer's anti-fantasy concerns (C1 42-frame compound = safety-net risk, C2 pre-hit buffer + DYING pulse = "analysis time", C3 Tier 3 token refill at hardest content, C4 Easy mode breaks Pillar 1) demoted to ADVISORY/DEFERRED — playtest hypothesis register, not blocker list. godot-specialist's `@export` mutation concern demoted to RECOMMENDED implementation hardening item.

User chose option [A]: apply 6 BLOCKING in same session, defer 9 RECOMMENDED to next session.

### Fixes Applied (6 BLOCKING)

- **BLOCK-R1-1 (systems-designer + godot-specialist + qa-lead consensus)**: Rule 16 + I2 priority invariant rewritten. Original claimed "Boss(priority=10) issues grant_token() before Damage processing". Correction: process_physics_priority lower=earlier (Godot 4.x). Ladder: player=0, TRC=1, Damage=2 (damage.md Round 3 lock), enemies/Boss=10, projectiles=20. Actual same-tick order: Damage(2) → Boss(10) → projectile(20). Damage `lethal_hit_detected` first → SM tries `try_consume_rewind` if buffered input held (T → T-1, intermediate T=0 dip possible) → Boss `boss_defeated` → `grant_token` (T-1 → T, net zero). Intermediate T=0 dip unobserved within same tick. AC-B5 reframed to verify net-zero (was incorrectly asserting `token_replenished` *before* `token_consumed`). Boss Pattern GDD must add priority ≥ 10 upper-bound obligation. E-06 mirror update.

- **BLOCK-R1-2 (qa-lead BLOCKING #2)**: AC-A3 + Rule 4 + line 178 formula table signal name corrected. AC-A3 used `player_hit_lethal` (SM-bound) — but TRC subscribes to `lethal_hit_detected` per locked Damage GDD F.1 #8. Cross-document contradiction with already-locked sibling. Fixed all 3 TRC-side mentions (Rule 4 cache trigger, formula table H_lethal description, AC-A3 GIVEN clause). SM-side `player_hit_lethal` mentions (Rule 17 latch, AC-C1, AC-C4, AC-D1, AC-D2, state table DYING entry, F.1 #5 row, F.6 contracts) preserved unchanged — they are correct (SM does subscribe to `player_hit_lethal`). Two distinct signals, same frame N emit, different subscribers.

- **BLOCK-R1-3 (systems-designer CRIT-3)**: D2 formula `T_after_boss_kill = T + 1` → `min(T + 1, max_tokens)`. AC-B3 was testing the cap but formula spec (source of truth implementers read first) had no cap expression. Same fix in ADR-0002 `grant_token()` pseudocode: `_tokens = min(_tokens + 1, _rewind_policy.max_tokens)`. Behavior unchanged — this codifies what AC-B3 already validates.

- **BLOCK-R1-4 (systems-designer DRIFT-1)**: ADR-0001 Amendment 1 added. Original claimed PlayerSnapshot ≈ 32 bytes / ring buffer 2.88 KB / Validation Criteria #1 "≤ 5 KB". GDD F4 corrected to 17–21 KB but ADR-0001 unfixed → Tier 1 prototype's first memory profile would auto-fail despite correct implementation. Updated 4 locations: status header (Accepted with Amendment 1), Verification Required #3 (≤ 25 KB), Performance Implications memory line (17–21 KB typical, 36 KB worst case per performance-analyst Round 1), Validation Criteria #1 (≤ 25 KB). Documentation-only change, no behavior modification.

- **BLOCK-R1-5 (systems-designer DRIFT-2)**: ADR-0002 Decision section pseudocode reordered. Original Decision section retained the broken pre-Amendment 1 algorithm (`restore_idx` from live `_write_head`) with a warning comment. Implementer reading Decision first would copy-paste broken code before noticing Amendment 1 at top. Replaced try_consume_rewind() with corrected version (Amendment 1 authoritative) including all 3 guards (`_buffer_primed`, `_is_rewinding`, RESTORE_OFFSET assertion). Original demoted to "Superseded Algorithm — DO NOT IMPLEMENT" subsection at bottom for historical reference only. RECOMMENDED #7 (assert(O<W) guard) folded in as part of this fix.

- **BLOCK-R1-6 (systems-designer BV-2 + game-designer implied)**: Player-facing copy contradiction resolved. game-concept.md said "recover *post-mortem* 1.0-1.5 seconds" + Core Mechanics "1.0-1.5 second recovery" + Core Fantasy "recover 1 second of time" — but actual mechanic delivers 0.15s positional rollback (RESTORE_OFFSET_FRAMES=9 / 60). User chose option [A] (recommended): rewrite copy, preserve mechanic. New copy: "instantly restores a safe pre-death position from the 1.5-second lookback window — a 'revoke' token". The "1.5s" is the *capture window*; "0.15s pre-death" is the *restore depth*. Aligns with Defiant Loop fantasy ("enraged glitch" defiance, not Braid-style scrubbing). Updated 3 spots in game-concept.md (Core Fantasy line 34, Unique Hook line 42 + new ✅ verification bullet, Core Mechanics line 75) + 2 ADR cross-reference tables (ADR-0001 GDD Requirements Addressed, ADR-0002 GDD Requirements Addressed).

### Deferred to Next Session (9 RECOMMENDED — non-blocking)

User chose [A] (BLOCKING only). RECOMMENDED items queued for next revision session:

7. ✅ APPLIED-AS-PART-OF-#5: `assert(O < W)` guard in `_ready()` (folded into ADR-0002 authoritative pseudocode)
8. Rule 17 latch clear AC for `DYING → DEAD` direct path (systems-designer GAP-1) — currently AC-C3 only tests `REWINDING → ALIVE` clear path
9. E-23 addition: scripted kill volume bypass `monitorable=false` obligation + level script `is_in_iframe()` check (systems-designer GAP-2 + godot-specialist)
10. `monitorable = true` deferred-call pattern: `call_deferred("set_monitorable", true)` (godot-specialist Bug 3) — physics callback context safety
11. Pre-hit buffer + DYING visual reframe: 4-frame buffer as "intent commitment", DYING pulse as single-flash (game-designer C2 — "analysis time" anti-fantasy mitigation)
12. TRC 1ms envelope sub-partition: shader ≤500μs / restore ≤300μs / headroom 200μs + Steam Deck Zen 2 baseline (performance-analyst HIGH-1+2)
13. D6 t_field_copy 6ns → 100-500ns GDScript actual value correction (systems-designer BV-3 + performance-analyst EST-1) — methodology fix, conclusion (still under cap) unchanged
14. AC-D4/D5 frame-perfect injection harness spec + AC-E1 [AUTO]→[MANUAL] reclassification (qa-lead) — GUT headless cannot use Godot Profiler
15. `@export var player: PlayerMovement` explicit dependency node wiring (godot-specialist) — eliminate implicit `get_parent()` brittleness

### Deferred — Post-Lock Observations (per creative-director directive — log only, do not gate prototype)

- **[game-designer C1] 42-frame compound protection (30 i-frame + 12 hazard grace) = 0.7s** invulnerability, anti-fantasy "safety-net" risk. **Playtest hypothesis** — validates or falsifies at Tier 1 (only specialist to flag this; pillar tension is intentional design).
- **[game-designer C3] Tier 3 boss-kill refill at peak content** = invincibility power-fantasy macro scale risk. **Tier 3 design decision** — countermeasure design only after Tier 2 establishes per-boss baseline.
- **[game-designer C4] Easy mode `infinite=true`** structurally removes Pillar 1, not just softens. Need explicit Easy-mode aesthetic AC or acknowledgment that Pillar 1 doesn't apply in Easy. **Tier 2/3 mode design** — defer to Difficulty Toggle GDD.
- **[game-designer I1] HUD aesthetic ownership gap** — token_consumed visualization could feel like "earned reward" not "expensive resource used". HUD GDD has no binding directive over aesthetic character. **Tier 1 polish pass.**
- **[game-designer I2] Hard mode 8-frame DYING window** = 133ms < human reaction → punitive confirmation, not "defiant failure". Suggest B=0 or 1 on Hard for tokens>0 variants. **Tier 2 difficulty design.**
- **[game-designer I3] Shader self-terminate desync** if `REWIND_SIGNATURE_FRAMES` adjusted. Lock fragile at Tier 1 gate. **Apply only if const ever changes** (currently hardcoded with strong rationale).
- **[game-designer I4] dry-thunk denial SFX tonal mismatch** in Hard mode (every death = denial cue). Tonally Cuphead-punishment, not Echo-defiance. **Tier 2 audio sound-designer call.**
- **[game-designer L1] `grant_on_boss_kill` diegetic bridge** to Story Spine "REWIND Core = battery = human irrationality = VEIL blind spot" missing. **Narrative-director task post-prototype** — three options: reframe metaphor, add one-line Boss Pattern GDD bridge, or accept ludonarrative convenience explicitly.
- **[godot-specialist verify-at-prototype] OQ-9 `seek()` looping animations + E-21 method-track dispatch timing + signal connection-order requirements** — Tier 1 Week 1 explicit validation tasks (already in Open Questions section).
- **[performance-analyst MEDIUM] AC-E1/E2 build type (debug vs release profiler) + AC-E4 encounter underspecification (collage shader simultaneously active) + CanvasLayer batching break risk on 50+ bullets** — Tier 1/2 perf-pass tasks.
- **[performance-analyst LOW] D5 worst-case overhead 36 KB vs stated 25 KB + no field-addition perf gate + AC-E3 thermal throttling on 1000-rewind test (~83 minutes)** — Tier 1 perf instrumentation.

### Cross-GDD Sync (verified during BLOCKING #2 fix)

- `damage.md` F.1 #8 row → TRC subscribes to `lethal_hit_detected` (cache trigger) + `death_committed` (cleanup); SM subscribes to `player_hit_lethal`. **Locked sibling** — time-rewind.md AC-A3 + Rule 4 + formula table now match this contract.
- `state-machine.md` F.1 #8 row → ECHO 4-state machine references time-rewind.md as single source. SM-bound mentions (Rule 17 latch, AC-C1/C4/D1/D2, state table DYING entry) correctly use `player_hit_lethal`.
- `systems-index.md` System #9 row → bumped to "Designed (Round 1 NEEDS REVISION → 6 BLOCKING applied; 9 RECOMMENDED + 11 DEFERRED open)". Round 1 director directive captured.
- `architecture.yaml` registry items unchanged — all 5 stances (rewind_lifecycle 5 signals, etc.) remain correct after BLOCKING fixes.

### Director Directive

**Round 2 blocked** except for:
- (a) Locked Decision empirical falsification (spec-vs-actual mismatch discovered during Tier 1 prototype verification)
- (b) Cross-document contradictions discovered after lock

Aesthetic-only findings (game-designer C1-C4, etc.) go to post-lock observations log only — add review-log entry only after Tier 1 playtest.

**Empirical falsification examples that WOULD reopen the lock**:
- Steam Deck profiling shows TRC subsystem exceeds 1 ms cap under documented worst-case
- Tier 1 playtest shows 0.7s compound invulnerability genuinely reads as safety-net (C1 validated)
- Memory measurement at Tier 1 exceeds 25 KB (Amendment 1 figure)
- Frame-N priority ladder breaks (e.g., Boss Pattern GDD assigns Boss to priority < 2)

**What WILL NOT reopen the lock**:
- New aesthetic preferences without playtest data
- New "would be cool if" features
- Re-litigation of any of the 5 Pillars or 6 Anti-Pillars

### Validation Criteria — How We'll Know This Was Right

- All 6 BLOCKING items closed (this session — verified via grep)
- AC-A3 cross-validates against Damage GDD F.1 #8 signal name (no more drift) — verified
- ADR-0001 Tier 1 memory validation passes on first run (≤25 KB, not ≤5 KB) — Tier 1 prototype validation
- Tier 1 prototype demonstrates Defiant Loop fantasy in playtest (validates or falsifies C1) — Tier 1 playtest
- Time Rewind subsystem fits 1 ms cap on Steam Deck Zen 2 baseline (validates HIGH-1+2) — Tier 1 measurement

### Files Modified This Session

- `design/gdd/time-rewind.md` (Rule 4 / Rule 16 / I2 / line 178 formula table / D2 formula block / E-06 / AC-A3 / AC-B5)
- `docs/architecture/adr-0001-time-rewind-scope.md` (Status header / new Amendment 1 section / Verification Required #3 / Performance Implications memory line / Validation Criteria #1 / GDD Requirements Addressed game-concept row)
- `docs/architecture/adr-0002-time-rewind-storage-format.md` (Decision section try_consume_rewind() pseudocode / grant_token() pseudocode / Superseded Algorithm subsection / GDD Requirements Addressed game-concept row)
- `design/gdd/game-concept.md` (Core Fantasy / Unique Hook + new verification bullet / Core Mechanics)
- `design/gdd/systems-index.md` (System #9 status row + design doc link added)
- `design/gdd/reviews/time-rewind-review-log.md` (this file — new)
