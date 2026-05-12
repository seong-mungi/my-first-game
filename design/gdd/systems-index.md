# Systems Index: Echo

> **Status**: Draft (v0)
> **Created**: 2026-05-09
> **Last Updated**: 2026-05-12 — see design/gdd/reviews/ for full review history.
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
| 1 | Input System | Core | MVP | Approved · 2026-05-11 | [input.md](input.md) · [reviews/input-review-log.md](reviews/input-review-log.md) | — |
| 2 | Scene / Stage Manager | Core | MVP | Approved · 2026-05-11 | [scene-manager.md](scene-manager.md) · [reviews/scene-manager-review-log.md](reviews/scene-manager-review-log.md) | — (Foundation — no upstream dependencies) |
| 3 | Camera System | Core | MVP | Designed · 2026-05-12 · pending re-review | [camera.md](camera.md) | Scene Manager #2 (HARD — first-use of `scene_post_loaded(anchor, limits)` signal); Player Movement #6 (HARD — target.global_position); State Machine #5 (HARD — PlayerMovementSM state read); Damage #8 (HARD — player_hit_lethal, boss_killed signals); Time Rewind #9 (HARD — rewind_started, rewind_completed signals); Player Shooting #7 (SOFT — shot_fired micro-shake feedback); ADR-0003 (HARD — process_physics_priority=30 ladder slot); ADR-0002 (HARD — negative dep: Camera state NOT in PlayerSnapshot); art-bible.md (SOFT — Section 6 composition / readable third) |
| 4 | Audio System | Audio | MVP | Not Started | — | Scene Manager |
| 5 | **State Machine Framework** | Core | MVP | Approved · 2026-05-10 | [state-machine.md](state-machine.md) · [reviews/state-machine-review-log.md](reviews/state-machine-review-log.md) | — (Foundation; 시그널 소비자: Damage #8, Time Rewind #9, Scene #2, Input #1) |
| 6 | Player Movement | Gameplay | MVP | Approved · 2026-05-11 | [player-movement.md](player-movement.md) · [reviews/player-movement-review-log.md](reviews/player-movement-review-log.md) | Input #1, State Machine #5, Scene Manager #2, Player Shooting #7 (provisional cache), Damage #8 (호스팅), Time Rewind #9 |
| 7 | Player Shooting / Weapon System | Gameplay | MVP | Approved · 2026-05-11 | [player-shooting.md](player-shooting.md) · [reviews/player-shooting-review-log.md](reviews/player-shooting-review-log.md) | Input #1, Player Movement #6, Damage #8 |
| 8 | Damage / Hit Detection | Gameplay | MVP | LOCKED · 2026-05-10 | [damage.md](damage.md) · [reviews/damage-review-log.md](reviews/damage-review-log.md) | State Machine #5, Time Rewind #9, Player Movement #6, Player Shooting #7, Enemy AI #10, Boss Pattern #11, Stage #12 |
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
| Design docs started | 8 |
| Design docs reviewed (Round 1 design-review 적어도 1회 적용) | 3 |
| Design docs approved (re-review 통과 or LOCKED for prototype) | 7 |
| Design docs Designed (pending re-review after Round 1 BLOCKING applied) | 1 |
| Deferred non-blocking warnings | 0 |
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

### Completed (Sessions 5–22)

- [x] `/architecture-decision R-T1` — Time Rewind 범위: **Player-only** (ADR-0001 Accepted 2026-05-09)
- [x] `/architecture-decision R-T2` — 저장 방식: **State Snapshot ring buffer** (ADR-0002 Accepted 2026-05-09; **Amendment 2 Accepted 2026-05-11** via Player Shooting #7 ratification)
- [x] `/architecture-decision R-T3` — 결정성 전략 (ADR-0003 Accepted 2026-05-09; CharacterBody2D + 직접 transform + `process_physics_priority` 사다리)
- [x] `/design-system input` (#1) — Approved
- [x] `/design-system scene-manager` (#2) — Approved (RR7 PASS 2026-05-11)
- [x] `/design-system state-machine` (#5) — Approved
- [x] `/design-system player-movement` (#6) — Approved
- [x] `/design-system player-shooting` (#7) — Approved (Round 2; closed ADR-0002 Amendment 2 ratification gate)
- [x] `/design-system damage` (#8) — LOCKED for prototype
- [x] `/design-system time-rewind` (#9) — Approved
- [x] `/design-system camera` (#3) — Designed (Session 22 2026-05-12; pending fresh-session re-review)

### Queued — Next GDD Authoring (sorted by unblocking value)

- [ ] `/design-review design/gdd/camera.md --depth lean` — Fresh-session independent verdict on Camera #3 (Effort S read-only sweep)
- [ ] `/architecture-review` — Validate cross-ADR consistency post-Amendment-2-Accepted (Effort S read-only sweep)
- [ ] `/design-system audio` (#4) — Audio. Depends on Scene Manager #2. Tier 1 stub-level. Effort S
- [ ] `/design-system stage-encounter` (#12) — Feature. Depends on Scene Manager #2 + Enemy AI #10. Effort M
- [ ] `/design-system enemy-ai` (#10) + 3 archetypes — Feature. Depends on State Machine + Damage + Player Movement. Effort L
- [ ] `/design-system hud` (#13) — UI. Depends on Time Rewind + Player Shooting + Boss Pattern. Closes TR D1 silent cap-overflow contract gap obligation. Effort M
- [ ] `/design-system boss-pattern` (#11) — Feature. Depends on Enemy AI + Damage + Time Rewind. Effort L

### Gates & Reviews

- [ ] `/design-review` each GDD after authoring (fresh session — never run in authoring session)
- [ ] `/review-all-gdds` after MVP 18 GDDs all in at least Designed status — holistic cross-doc consistency + game design theory review
- [ ] `/gate-check pre-production` — MVP 18개 GDD 모두 Approved 후 + 18 cross-system reciprocal batches landed

### Prototype & Tier 1 Playtest

- [ ] `/prototype time-rewind` — Tier 1 Week 1 검증 (now unblocked — Scene Manager #2 + Player Shooting #7 both Approved)
- [ ] Tier 1 Steam Deck 1세대 device session — S1 AimLock facing-strobe drift ±0.18 perceptibility test (Pillar 3 visual signature)
- [ ] Tier 1 playtest D1 review — AimLock-turret candidate dominant strategy (after Enemy AI #10 / Boss #11 / Stage #12 GDDs land)

### Outstanding Open Questions (deferred to later sessions)

- [ ] **D1** AimLock-turret dominant strategy → Tier 1 playtest after Enemy AI #10 / Boss #11 / Stage #12
- [ ] **S1** AimLock facing-strobe Steam Deck drift → creative call: (a) raise `FACING_THRESHOLD_AIM_LOCK` to ≥0.20 with hysteresis exit ≥0.15, or (b) INV-9 enforcing `FACING_THRESHOLD_AIM_LOCK > documented_steam_deck_drift_floor`. Defer to first Steam Deck Tier 1 device session.
