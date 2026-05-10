# Systems Index: Echo

> **Status**: Draft (v0)
> **Created**: 2026-05-09
> **Last Updated**: 2026-05-11 (System #6 Player Movement — **NEEDS REVISION** per fresh-session `/design-review design/gdd/player-movement.md` 2026-05-11. **MAJOR REVISION NEEDED** — 10 BLOCKING items across 7 specialists (creative-director synthesis): B1 INT_MIN sentinel int64 overflow → phantom jump after restore (D.3 Formula 5 + AC-H5-04 + C.3.3 Scenario C — flagged by systems-designer + qa-lead + godot-gdscript-specialist 3-way convergence); B2 `tools/ci/pm_static_check.sh` does not exist (3 BLOCKING ACs H7-03/H7-04/H3-04 silently pass — same trap damage.md AC-26/27 hit); B3 Godot 4.6 `AnimationPlayer.callback_mode_method` default unverified (DEFERRED would collapse `_is_restoring` guard architecture in C.4.x + AC-H1-02/03 + VA.5); B4 AC-H7-04 awk range pattern collapses to function-signature line (body never scanned); B5 DEC-PM-3 "resume with live ammo" Pillar 1 contradiction (creative call required — 3 options A partial restore / B snap exclusion / C schema amendment); B6 multi-domain DYING-12-frame concern (motor reaction <250ms + visual-as-hitch + orphan "Q5" audio cue — 3 specialists converged); B7 art-bible ABA-1..4 deferred but VA.6 budget cites them (circular gate); B8 4 footstep variants insufficient at 12 steps/sec sprint (robotic rattle in <1s); B9 AimLock 1-frame body paper-doll + VA.1/VA.7 internal contradiction (code-driven swap vs AnimationPlayer-driven mandate); B10 facing_threshold_outside == gamepad_deadzone (0.2/0.2) — Steam Deck stick drift flickers facing every frame (need hysteresis pair). Pillar 1 ("학습 도구") **not delivered as written** per creative-director — 4 independent failures (B1, B5, B6, B.2/C.4.0 mental model gap REC-G3). Scope L confirmed; ~2-3 focused solo days before re-review. ~22 RECOMMENDED + ~12 NICE-TO-HAVE deferred to revision pass. Report appended to `design/gdd/reviews/player-movement-review-log.md` (new file). Progress Tracker: Designed 1→0, started 4→4 (System #6 reverts to In Design).) | 이전: 2026-05-10 (System #6 Player Movement — **Designed** status applied per `player-movement.md` F.4.1 #5 obligation. 6 cross-doc edits batch verified/applied: (1) time-rewind.md F.1 row #6 *(provisional)* removed + 7-field interface verbatim + `class_name PlayerMovement extends CharacterBody2D` + `restore_from_snapshot(snap: PlayerSnapshot)` signature + `_is_restoring` guard cross-link [pre-applied 2026-05-10] · (2) state-machine.md F.2 row #6 (line 843) Downstream framework client lock-in [pre-applied 2026-05-10] + F.4 Mirror Verification line 870 bidirectional hygiene [this session] · (3) state-machine.md C.2.1 node tree (line 180-196) Round 5 cross-doc-contradiction exception applied [pre-applied] · (4) damage.md F.1 row #6 ECHO HurtBox/HitBox/Damage hosted as PlayerMovement(CharacterBody2D) children [pre-applied] · (5) systems-index #6 row this entry · (6) architecture.yaml 4 new entries: state_ownership.player_movement_state + interfaces.player_movement_snapshot + forbidden_patterns.delta_accumulator_in_movement + api_decisions.facing_direction_encoding [this session]. Progress Tracker: started 3→4, Designed 0→1. G/H/Visual-Audio/UI/Z/Appendix pending — qa-lead + art-director mandatory consults queued.) | 이전: 2026-05-10 (Round 6 housekeeping batch 2026-05-10 — **all 10 deferred items applied**: W2 (`rewind_completed` canonical sig footnote) · W3 (Rule 5 always-poll predicate note) · W5 (E-17 DEC-6 reciprocal — `hazard_oob` re-death = N+42) · D4 (Collage Rendering #15 soft-dep for Pillar 1) · I7 (`_lethal_hit_head` non-clear note) · D1 (silent cap-overflow contract gap → HUD coordination obligation) · I1 (`boss_pattern_interrupted` value comment) · I2 (AC-15 DYING→DEAD direct path enumeration) + AC-9/AC-D2 narrative-staleness nits resolved. Cross-doc consistency now fully clean. 3 GDDs Approved/LOCKED. Architecture work (#5/#8/#9) unblocked.) | 이전: 2026-05-10 (Round 5 since-last-review verifier 2026-05-10: **PASS** — S1 BLOCKER closed by `damage.md` C.3.2 step 0 first-hit lock + AC-36 + reciprocal Rule 17 split + W1 (F.4 row `+ 1`) + W4 (state-machine.md C.3.1 ladder Damage=2 row). All 3 GDDs returned to Approved/LOCKED. 6 W/I items deferred — non-blocking; queued for next housekeeping pass. Report: `design/gdd/gdd-cross-review-2026-05-10.md`.) | 이전: 2026-05-10 (`/review-all-gdds` full-mode 2026-05-10: **FAIL** — 1 BLOCKER (S1 `_pending_cause` overwrite + TRC re-cache during DYING — invariants asserted in damage.md E.1 + time-rewind.md Rule 17 not implemented; SM `_lethal_hit_latched` only blocks step 3 SM dispatch, Damage steps 1-2 + TRC handler unguarded; `DyingState.enter()` does NOT toggle `monitorable=false`). 7 warnings + 8 info. All 3 GDDs (#5/#8/#9) flagged 'Needs Revision'. Round 5 invoked on damage.md under cross-doc-contradiction exception. Holism PASS (Player Fantasies mutually load-bearing). 2 design-theory warnings (silent token cap overflow at boss kill, 58-frame aggregate invisible recovery window). Report: `design/gdd/gdd-cross-review-2026-05-10.md`.) | 이전: 2026-05-10 (System #9 Time Rewind System — **Round 2 design-review 2026-05-10: APPROVED** (lean re-review, single-session per `production/review-mode.txt`). Round 1 6 BLOCKING all verified applied. Round 2 7 RECOMMENDED applied inline: R2-1 AC-C2 latch clear on DYING→DEAD path · R2-2 E-23 Level Script Bypass edge case · R2-3 Rule 11 `set_deferred("monitorable")` race-safe pattern · R2-4 D6 `t_field_copy` 6→100-500 ns + 1 ms Envelope Sub-Partition (Shader 500 / Restore 300 / Headroom 200 μs + Steam Deck Zen 2 baseline) · R2-5 AC-D4/D5 frame-perfect injection harness · R2-6 AC-E1 [AUTO]→[MANUAL] + Time.get_ticks_usec() supplementary [AUTO] · R2-7 Section C.3 #6 `@export var player: PlayerMovement` wiring. AC count 33→34 cosmetic. Cross-doc consistency verified: damage.md F.4.1 / DEC-1, state-machine.md C.2.2 O1-O6, priority ladder. 11 DEFERRED post-lock observations remain Tier 1 playtest review-log only. Round 3 차단 except prototype empirical falsification 또는 cross-doc contradiction.) | 이전: 2026-05-10 (System #5 State Machine **Round 2 APPROVED**) · 2026-05-10 (System #9 Time Rewind Round 1 NEEDS REVISION → 6 BLOCKING applied) · 2026-05-09 (System #8 Damage **Round 4 LOCKED for prototype**)
> **Source Concept**: design/gdd/game-concept.md
> **Visual Bible**: design/art/art-bible.md
> **Engine**: Godot 4.6 / GDScript
> **Director Gate**: TD-SYSTEM-BOUNDARY / PR-SCOPE / CD-SYSTEMS — SKIPPED (Lean mode)

---

## Overview

Echo는 횡스크롤 2D 런앤건 + 시간 회수 토큰 메커닉을 핵심으로 하는 솔로 개발 PC 게임이다. 24개 시스템으로 분해되며, 그 중 18개가 Tier 1 MVP에서 동작해야 한다. 핵심 메커닉(시간 되감기)은 기술적·디자인적 위험이 가장 높아 모든 GDD 작성에 앞서 R-T1/R-T2/R-T3 ADR 3건이 선결되어야 한다. 콜라주 렌더링 파이프라인은 두 번째 위험 영역으로, 비주얼 시그니처(Pillar 3 마케팅 자산) 와 메모리 천장(1.5GB) 사이의 균형을 잡아야 한다.

핵심 루프 — 이동 → 적 발견 → 사격 → (회피 OR 시간 되감기) → 생존 — 은 8개 Core 시스템(Player Movement, Player Shooting, Damage, Time Rewind, Enemy AI, Boss Pattern, Stage/Encounter, State Machine)이 모두 동작해야 비로소 검증 가능하다.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|---|---|---|---|---|---|
| 1 | Input System | Core | MVP | Not Started | — | — |
| 2 | Scene / Stage Manager | Core | MVP | Not Started | — | — |
| 3 | Camera System | Core | MVP | Not Started | — | Scene Manager |
| 4 | Audio System | Audio | MVP | Not Started | — | Scene Manager |
| 5 | **State Machine Framework** | Core | MVP | **Approved (Round 2 + Round 5 since-last-review verifier 2026-05-10: PASS)** — Round 5 W4 fix applied inline (C.3.1 ladder Damage=2 row inserted between TRC=1 and enemies=10). I2 (AC-15 DYING→DEAD enumeration) still deferred — non-blocking. Previously: **Approved (Round 2 design-review 2026-05-10: APPROVED — Lean re-review)** — Round 1 8 BLOCKING all verified holding cross-doc (damage.md / time-rewind.md). Round 2 residuals applied inline: R2-1 AC count math 27→28 + Logic 25→26 (AC-17a separate enumerated row), R2-2 `_state_history` ring buffer Tier 2→Tier 1 promoted (AC-12 + AC-24 BLOCKING dependency). 12 RECOMMENDED + 5 nice-to-have remain v2-deferred per Round 1 director directive. Round 3 차단 except prototype empirical falsification or new cross-doc contradiction. Round 1 (이전): NEEDS REVISION → 8 BLOCKING (B1 B-range / B2 pause_swallow invariant / B3 sentinel guard / B4 intra-tick ordering / B5 call_deferred + null assert / B6 TRANSITION_QUEUE_CAP const / B7 extends StateMachine / B8 AC 카운트+검증법) applied via 7-specialist + creative-director synthesis. | [state-machine.md](state-machine.md) · [reviews/state-machine-review-log.md](reviews/state-machine-review-log.md) | — (Foundation; 시그널 소비자: Damage #8, Time Rewind #9, Scene #2, Input #1) |
| 6 | Player Movement | Gameplay | MVP | **In Design — NEEDS REVISION (fresh-session /design-review 2026-05-11: MAJOR REVISION NEEDED, 10 BLOCKING)** — Pillar 1 not delivered as written; B1 INT_MIN sentinel phantom jump (3-specialist convergence), B2 `tools/ci/pm_static_check.sh` 부재로 3 BLOCKING ACs 무효, B3 Godot 4.6 `callback_mode_method` 기본값 검증 필요, B5 DEC-PM-3 ammo Pillar 1 모순 (창의 결정), B6 12-frame DYING window 다도메인 우려. ~2-3일 솔로 revision 후 fresh-session 재검토. Specialists: game-designer + systems-designer + qa-lead + gameplay-programmer + godot-gdscript-specialist + art-director + audio-director + creative-director (synthesis). [reviews/player-movement-review-log.md](reviews/player-movement-review-log.md). Previously: **Designed (2026-05-10)** — Tier 1 6-state PlayerMovementSM (`idle/run/jump/fall/aim_lock/dead` per DEC-PM-1; `hit_stun` removed per damage.md DEC-3 binary 모델; dash/double_jump/wall_grip Tier 2 deferred). 7-필드 PlayerSnapshot interface verbatim locked (C.1.3 — time-rewind.md F.1 #6과 일치). `class_name PlayerMovement extends CharacterBody2D` (= ECHO root, A.Overview Decision A). Variable jump cut Celeste-style (DEC-PM-2). `facing_direction` int 0..7 enum CCW from East (Decision B 2026-05-10 — schema unchanged, ADR-0002 변경 없음). aim_lock grounded-only (Decision C). `_is_restoring` 가드 단일 출처 (C.4.4) — anim method-track 핸들러 (footstep SFX, dust VFX, bullet spawn) 복원 중 short-circuit. `process_physics_priority=0` (ADR-0003 ladder). 3 OQ deferred: OQ-PM-1 (Scene Manager 클리어 책임), OQ-PM-2 (Tier 1 looping anim seek 검증, time-rewind.md OQ-9 의존), E-PM-9 (Input #1 deadzone 책임). Sections A/B/C/D/E/F locked-in this session. G/H/Visual-Audio/UI/Z/Appendix pending — `qa-lead` (H) + `art-director` (Visual/Audio, character movement category REQUIRED) consults required. Cross-doc reciprocals applied: time-rewind.md F.1 #6 ✓ / state-machine.md F.2 row #6 (line 843) + C.2.1 노드 트리 (line 180-196 Round 5 exception) + F.4 mirror line 870 hygiene ✓ / damage.md F.1 #6 ✓ / architecture.yaml 4 신규 항목 ✓. | [player-movement.md](player-movement.md) | Input #1, State Machine #5, Scene Manager #2, Player Shooting #7 (provisional cache), Damage #8 (호스팅), Time Rewind #9 |
| 7 | Player Shooting / Weapon System | Gameplay | MVP | Not Started | — | Input, Player Movement, Damage |
| 8 | Damage / Hit Detection | Gameplay | MVP | **LOCKED for prototype (Round 5 cross-doc S1 fix 2026-05-10 applied + since-last-review verifier PASS)** — Round 5 surgical fixes: (1) C.3.2 step 0 `if _pending_cause != &"": return` first-hit lock — single enforcement site for `_pending_cause` first-hit and TRC `_lethal_hit_head` re-cache invariants; (2) E.1 outcome rewrite pointing to step 0; (3) F.4 row `start_hazard_grace()` `+ 1` correction (W1); (4) new AC-36 covering first-hit lock GUT scenarios. Verifier confirmed S1 closed + no regressions. AC-9 / AC-D2 narrative-staleness nits queued for Round 6 housekeeping. I1 (boss_pattern_interrupted comment) deferred. Previously: **LOCKED for prototype (Round 4 reviewed 2026-05-09)** — Round 2: 7-specialist + creative-director, MAJOR REVISION 8/12 적용. Round 3: 4-specialist + creative-director, NEEDS REVISION 4 BLOCKING 적용. Round 4: qa-lead + creative-director synthesis, LOCK & PROTOTYPE 2 surgical AC fixes (AC-21 regex broadening, AC-29 hardcoded fixture baseline). Round 5 차단 (post-lock observations only). ADR 3건 queued (boss-phase-advance-monotonicity, signal-emit-order-determinism, ADR-0003 priority 사다리 갱신). | [damage.md](damage.md) | State Machine #5, Time Rewind #9, Player Movement #6, Player Shooting #7, Enemy AI #10, Boss Pattern #11, Stage #12 |
| 9 | **Time Rewind System** ⚠️ | Gameplay | MVP | **Approved (Round 2 + Round 5 since-last-review verifier 2026-05-10: PASS on S1 reciprocal)** — Round 5 Rule 17 split applied: Primary guard (Damage step 0 — `damage.md` C.3.2) + Secondary guard (SM `_lethal_hit_latched`). Verifier confirmed cross-doc story coherent with damage.md C.3.2 / E.1 / AC-36. **Deferred (non-blocking warnings)**: W2 `rewind_completed` parameter name canonicalisation, W3 Rule 5 always-poll predicate note, W5 E-17 DEC-6 reciprocal note (Session 5 carry-over), D4 Collage Rendering #15 soft dependency for Pillar 1 readability, I7 `_lethal_hit_head` non-clear note, D1 silent cap-overflow contract gap (HUD coordination). All 6 are 1-paragraph edits, queued for next housekeeping pass. Previously: **Approved (Round 2 design-review 2026-05-10: APPROVED — Lean re-review per `production/review-mode.txt`)** — Round 1 6 BLOCKING all verified applied at every cited site (Rule 16/I2/E-06 priority ladder · Rule 4 + AC-A3 + 178 table TRC/SM signal split · D2 + ADR-0002 cap sync · ADR-0001 Amendment 1 ≤25 KB · ADR-0002 정본 pseudocode + Superseded subsection · game-concept "1.5초 lookback + 0.15s pre-death" copy). Round 2 7 RECOMMENDED applied this session: AC-C2 latch clear on DYING→DEAD · E-23 Level Script Bypass · Rule 11 `set_deferred("monitorable")` · D6 t_field_copy 6→100-500 ns + 1ms Envelope Sub-Partition (Shader 500 / Restore 300 / Headroom 200 + Steam Deck Zen 2 baseline) · AC-D4/D5 frame-perfect injection harness · AC-E1 [AUTO]→[MANUAL] reclass + Time.get_ticks_usec() supplementary [AUTO] · Section C.3 #6 `@export var player: PlayerMovement` wiring. Cosmetic R2 fix: AC count 33→34 (oversight in Round 1 sum). Cross-doc consistency confirmed: damage.md F.4.1 emit order (TRC connect-first), damage.md DEC-1 1-arg, state-machine.md C.2.2 6 의무 (O1-O6 cite Rule 17/18/16/E-16 verbatim), priority ladder (player=0/TRC=1/Damage=2/enemies/Boss=10/projectiles=20). 11 DEFERRED post-lock observations remain Tier 1 playtest review-log only. Round 3 차단 except (a) prototype empirical falsification (b) new cross-doc contradiction. | [time-rewind.md](time-rewind.md) · [reviews/time-rewind-review-log.md](reviews/time-rewind-review-log.md) | Input, Scene Manager, State Machine, Player Movement, Damage |
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

⚠️ 표시: High-risk system. 아래 High-Risk Systems 섹션 참조.

---

## Categories

| Category | Description | Systems in Echo |
|---|---|---|
| **Core** | 모든 것이 의존하는 토대 시스템 | Input, Scene Manager, Camera, State Machine |
| **Gameplay** | 코어 재미를 만드는 시스템 | Player Movement, Player Shooting, Damage, Time Rewind, Enemy AI, Boss Pattern, Stage/Encounter, Pickup |
| **Persistence** | 저장 / 진행 상태 | Save / Settings Persistence (Tier 2+) |
| **UI** | 플레이어 정보 표시 | HUD, Menu / Pause |
| **Audio** | 사운드·음악 | Audio System (Tier 1 placeholder, Tier 3 외주) |
| **Narrative** | 스토리 전달 | Story Intro Text System (Anti-Pillar 컷씬 X — 텍스트만) |
| **Presentation** | 비주얼·이펙트 | VFX / Particle, Collage Rendering, Time Rewind Visual Shader |
| **Meta** | 코어 외부 시스템 | Difficulty Toggle, Localization, Input Remapping, Accessibility |

진행 / 경제 카테고리는 Echo에서 사용하지 않는다 — 결정론 + 무계측 진행 (Pillar 2).

---

## Priority Tiers

| Tier | Definition | Echo Mapping | System Count |
|---|---|---|---|
| **MVP** | Tier 1 Prototype 4-6주에 동작해야 하는 시스템 | 1 stage 슬라이스 + 시간 되감기 토큰 + 1 boss + 1 weapon | 18 |
| **Vertical Slice** | Tier 2 MVP 6개월 누계: 3 stages + Easy 토글 | Pickup + Difficulty + Persistence | 3 |
| **Full Vision** | Tier 3 출시 16개월 누계 | Localization + Remapping + Accessibility | 3 |

---

## Dependency Map

### Foundation Layer (의존성 0)

1. **Input System** — KB+M / Gamepad 매핑, 8방향 + 액션 버튼. 모든 게임플레이가 의존.
2. **Scene / Stage Manager** — 씬 로드/언로드, 체크포인트 앵커, 재시작 로직. 메모리 천장(1.5GB) 직접 관리.
3. **State Machine Framework** — Player·Enemy·Boss 상태 표현 공통 패턴. GDScript pattern + class 베이스.
4. **Audio System** — SFX/BGM 버스, 더킹, CC0 플레이스홀더 지원. Tier 1은 stub-level.

### Core Layer (Foundation 의존)

5. **Camera System** — 횡스크롤 follow, 스크린쉐이크 후크, 보스 줌. depends: Scene Manager
6. **Player Movement** — 달리기/점프/낙하, 1히트 즉사, 리스폰 핸들링. depends: Input, State Machine, Scene
7. **Damage / Hit Detection** — 탄환 vs 엔티티, 1히트 룰, 히트박스 레이어. depends: State Machine, Scene
8. **Time Rewind System** ⚠️ — 상태 스냅샷 링버퍼, 토큰 소모, 복원 트리거. depends: Player Movement, State Machine, Damage. **R-T1/R-T2/R-T3 ADR 선결 필수.**

### Feature Layer (Core 의존)

9. **Player Shooting / Weapon System** — 8방향 조준, 발사체 스폰, 무기 스왑. depends: Input, Player Movement, Damage
10. **Enemy AI Base + Archetypes** — 공통 적 컨트롤러 + 드론/경비로봇/STRIDER 서브클래스. depends: State Machine, Damage, Player Movement
11. **Boss Pattern System** — 다페이즈 스크립트, 텔레그래프, HP 게이팅, REWIND 토큰 보상. depends: Enemy AI, Damage, Time Rewind
12. **Stage / Encounter System** — 룸별 트리거, 체크포인트. depends: Scene Manager, Enemy AI
13. **Pickup System** (Tier 2) — 무기 픽업 + 아이템. depends: Player Shooting, Stage

### Presentation Layer (Feature 의존)

14. **HUD System** — REWIND 토큰 카운터, 무기 아이콘, 보스 HP 바. depends: Time Rewind, Player Shooting, Boss Pattern
15. **VFX / Particle System** — 탄환 임팩트, 사망 플래시, REWIND 글리치. depends: Damage, Time Rewind
16. **Collage Rendering Pipeline** ⚠️ — 3레이어 콜라주 컴포지팅(사진+라인+컷아웃). depends: Scene Manager
17. **Time Rewind Visual Shader** ⚠️ — 색 반전 + 글리치 UV. depends: VFX, Time Rewind, Collage Rendering
18. **Story Intro Text System** — 5줄 타이프라이터 인트로. depends: Scene Manager
19. **Menu / Pause System** — 메인 메뉴, 일시정지, 옵션. depends: Input, Scene, Audio

### Polish Layer (Tier 2-3)

20. **Difficulty Toggle System** — Easy 토글 (토큰 무한) / Hard (토큰 0). depends: Time Rewind, Player Movement
21. **Save / Settings Persistence** — 옵션 파일, 진행 플래그. depends: Menu, Scene
22. **Localization System** (Tier 3) — depends: HUD, Menu. Anti-Pillar #6 — Tier 3 출시 시까지 deferred.
23. **Input Remapping** (Tier 3) — depends: Input, Menu. Anti-Pillar #6 deferred.
24. **Accessibility Options** (Tier 3) — depends: Menu, HUD

---

## Circular Dependencies

| 사이클 | 분석 | 해결 |
|---|---|---|
| Time Rewind ↔ Boss Pattern | Boss Pattern은 Time Rewind 토큰 보상에 의존 / Time Rewind는 Boss Pattern의 HP 게이팅 신호 의존 X (단방향) | **사이클 아님** — Boss → Time Rewind 단방향 통지(signal) 패턴 |
| HUD ↔ Time Rewind | HUD가 토큰 잔량 읽기 / Time Rewind가 HUD를 직접 호출 X | **사이클 아님** — Observer 패턴 (Time Rewind emits signal, HUD subscribes) |

진정한 사이클 없음. 모든 의존성은 단방향이며 시그널/이벤트로 디커플링.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|---|---|---|---|
| **Time Rewind System** | Technical + Design | Godot 4.6에서 시간 되감기 패턴 미검증 (스냅샷 vs 입력 리플레이). 1히트 즉사 게임 카타르시스를 *너무 많이* 완화해 코어 재미 손실 가능. | (1) **R-T1/R-T2/R-T3 ADR 3건 선결** — 범위(Player vs Braid), 저장 방식(스냅샷 vs 리플레이), 결정성 전략. (2) Tier 1 Week 1 단독 프로토타입 검증. 재미 없으면 차별화 메커닉 변경. |
| **Collage Rendering Pipeline** | Technical | 3레이어 합성 파이프라인이 60fps + 500 draw call + 1.5GB 메모리 제약 안에 동작 가능한지 불확실. Tier 3에서 5 stage 동시 콜라주 사진 텍스처 = 300MB 메모리 압박. | (1) Tier 1에서 1 scene만 풀 콜라주로 검증. (2) Tier 2 진입 전 스테이지 전환 시 텍스처 명시적 해제 ADR 작성. (3) 콜라주 조각 ≤30/스테이지 하드 캡. |
| **Time Rewind Visual Shader** | Technical | Godot 4.6 glow rework (4.5→4.6) 영향, D3D12 default Windows에서 셰이더 호환성 미검증. 콜라주 레이어와 합성 시 성능 미지수. | Tier 1 Week 2-3 셰이더 테스트씬 단독 검증. 60fps 유지 못하면 효과 단순화. |
| **Boss Pattern System** | Design | 다페이즈 결정론적 보스 패턴 5-6개 디자인 — 솔로 작업량 폭발 위험. Tier 3 실현 가능성 의문. | Tier 1에서 STRIDER 1개로 패턴 디자인 도구·작업량 검증. 실제 작업량 측정 후 Tier 3 보스 4개 또는 5-6개 결정. |

---

## Recommended Design Order

**원칙**: 솔로 개발 + 16개월 budget이므로 *위험 우선* 디자인. Foundation을 먼저 쓰지 않고, R-T1/T2/T3 ADR을 모든 GDD에 앞세운다. ADR 통과 후 Time Rewind GDD를 우선 작성하고, 나머지 Foundation/Core 시스템은 의존성 순서대로 따라간다.

| Order | System | Priority | Layer | Agent | Est. Effort | Notes |
|---|---|---|---|---|---|---|
| **0a** | ADR R-T1 (Time Rewind 범위) | — | — | godot-specialist + game-designer | S | 플레이어만 vs Braid 모델 |
| **0b** | ADR R-T2 (저장 방식) | — | — | godot-specialist + lead-programmer | S | 스냅샷 vs 입력 리플레이 |
| **0c** | ADR R-T3 (결정성 전략) | — | — | godot-specialist | S | CharacterBody2D + 직접 transform |
| 1 | Time Rewind System | MVP | Core | game-designer + godot-gdscript-specialist | L | 0a/0b/0c 모두 통과 후 |
| 2 | State Machine Framework | MVP | Foundation | godot-gdscript-specialist | S | 2-7과 병렬 가능 |
| 3 | Input System | MVP | Foundation | game-designer | S | 병렬 가능 |
| 4 | Scene / Stage Manager | MVP | Foundation | godot-specialist | M | 병렬 가능 |
| 5 | Camera System | MVP | Core | godot-specialist | S | 병렬 가능 |
| 6 | Audio System | MVP | Foundation | sound-designer | S | Tier 1 stub-level |
| 7 | Damage / Hit Detection | MVP | Core | game-designer | M | 1히트 즉사 룰 |
| 8 | Player Movement | MVP | Core | game-designer | M | depends: 2, 3, 4, 7 |
| 9 | Player Shooting | MVP | Feature | game-designer | M | depends: 8 |
| 10 | Enemy AI Base + 3 Archetypes | MVP | Feature | ai-programmer | L | depends: 2, 7, 8 |
| 11 | Boss Pattern System | MVP | Feature | game-designer + ai-programmer | L | depends: 1, 10 |
| 12 | Stage / Encounter System | MVP | Feature | level-designer | M | depends: 4, 10 |
| 13 | Collage Rendering Pipeline | MVP | Presentation | godot-shader-specialist + technical-artist | L | depends: 4. art-bible 8장 메모리 예산 준수 |
| 14 | Time Rewind Visual Shader | MVP | Presentation | godot-shader-specialist | M | depends: 1, 13 |
| 15 | VFX / Particle System | MVP | Presentation | technical-artist | M | depends: 7, 1 |
| 16 | HUD System | MVP | Presentation | game-designer + ux-designer | M | depends: 1, 9, 11 |
| 17 | Story Intro Text System | MVP | Presentation | writer + ux-designer | S | 5줄 인트로만 |
| 18 | Menu / Pause System | MVP | Presentation | ux-designer | M | depends: 3, 4, 6 |
| 19 | Pickup System | Vertical Slice | Feature | game-designer | S | Tier 2 |
| 20 | Difficulty Toggle | Vertical Slice | Meta | game-designer | S | Tier 2 |
| 21 | Save / Settings Persistence | Vertical Slice | Persistence | gameplay-programmer | S | Tier 2 |
| 22 | Localization System | Full Vision | Meta | localization-lead | M | Tier 3 |
| 23 | Input Remapping | Full Vision | Meta | ux-designer + ui-programmer | M | Tier 3 |
| 24 | Accessibility Options | Full Vision | Meta | accessibility-specialist | M | Tier 3 |

**Effort 표기**: S = 1 세션 GDD / M = 2-3 세션 / L = 4+ 세션. 솔로 개발자 1세션 ≈ 2-3시간 디자인 대화.

---

## Progress Tracker

| Metric | Count |
|---|---|
| Total systems identified | 24 |
| MVP systems | 18 |
| Vertical Slice systems | 3 |
| Full Vision systems | 3 |
| Design docs started | 4 |
| Design docs reviewed (Round 1 design-review 적어도 1회 적용) | 3 (System #5 State Machine, System #8 Damage, System #9 Time Rewind — 모두 NEEDS REVISION/LOCK 단계 도달) |
| Design docs approved (re-review 통과 or LOCKED for prototype) | 3 (System #5 State Machine — Round 2 + Round 5 W4 fix; System #8 Damage — Round 4 LOCKED + Round 5 cross-doc S1 fix; System #9 Time Rewind — Round 2 + Round 5 Rule 17 split. All verifier-confirmed PASS 2026-05-10.) |
| Design docs Designed (pending re-review after Round 1 BLOCKING applied) | 0 (System #6 Player Movement reverted to In Design — NEEDS REVISION per fresh-session /design-review 2026-05-11: MAJOR REVISION NEEDED, 10 BLOCKING; was Designed 2026-05-10 with G/H/Visual-Audio/UI/Z/Appendix complete but Pillar 1 unvalidated and 4 architectural integrity blockers surfaced — see [reviews/player-movement-review-log.md](reviews/player-movement-review-log.md)) |
| Deferred non-blocking warnings | 0 (Round 6 housekeeping batch 2026-05-10 applied all 10 items: W2/W3/W5/D1/D4/I1/I2/I7 + AC-9/AC-D2 nits — see `design/gdd/gdd-cross-review-2026-05-10.md`) |
| ADRs queued (R-T1/T2/T3) | 3 |
| ADRs approved | 3 (R-T1 → ADR-0001, R-T2 → ADR-0002 with Amendment 1, R-T3 → ADR-0003) |

---

## Open Issues

> [!resolved] R-T1/R-T2/R-T3 ADR 선결 (해소 2026-05-09)
> 3 ADR 모두 Accepted (R-T1 ADR-0001, R-T2 ADR-0002 with Amendment 1, R-T3 ADR-0003). Time Rewind System GDD가 작성되어 Designed 상태. fresh-session `/design-review design/gdd/time-rewind.md`로 검증 권장.

> [!gap] 폰트 라이선스 (Tier 3 게이트)
> 한국어 폰트 (Noto Sans KR vs 정식 라이선스) 결정은 Tier 3 출시 직전. Tier 1/2는 Noto Sans KR 기본 사용.

> [!gap] 콜라주 사진 출처 (Q2)
> Stock vs AI 생성 vs 직접 촬영 결정 — `/asset-spec` 또는 첫 콘셉트아트 라운드 시점에 IP·라이선스 비교.

---

## Next Steps

- [x] `/architecture-decision R-T1` — Time Rewind 범위: **Player-only** (ADR-0001 Accepted 2026-05-09)
- [x] `/architecture-decision R-T2` — 저장 방식: **State Snapshot ring buffer** (ADR-0002 Accepted 2026-05-09)
- [ ] `/architecture-decision R-T3` — 결정성 전략 (CharacterBody2D 직접 transform)
- [ ] `/design-system time-rewind` — ADR 3건 통과 후
- [ ] `/design-system [next-foundation]` — 병렬 가능: state-machine, input, scene-manager, camera, audio
- [ ] `/design-review` 각 GDD 작성 후 별도 세션
- [ ] `/gate-check pre-production` — MVP 18개 GDD 모두 작성된 후
- [ ] `/prototype time-rewind` — Tier 1 Week 1 검증 (R-T1/T2/T3 ADR 결정 직후)
