---
title: Hot Cache
updated: 2026-05-12
---

# Hot Cache

Most-relevant pages for current project context. Read this first when picking up the wiki.

## Active Research Topic

**ADR Foundation Core Steps Ingest** (2026-05-14). 1 source file ingested. 2 pages created: source + concept.

→ **Concept**: [[Echo ADR Foundation Steps]] — 6 pre-coding foundation ADRs (scene lifecycle · signals · save · input · player entity · damage/combat)
→ **Source**: [[ADR Foundation Core Steps Explanation]] — plain-language guide with analogies + GDD cross-refs

## 이전 활성 (런앤건 개발 베이스 — 2026-05-12)

**런앤건 개발 베이스 종합 리서치** (2026-05-12). 1라운드 · ~18회 웹검색. 구현 기반(적 AI·플레이어 FSM·불릿·레벨). 8 페이지 생성.

→ **Synthesis**: [[Research Run and Gun Development Base]] — 구현 베이스 8 핵심 발견
→ **Concept**: [[Run and Gun Enemy AI Archetypes]] — 6종 FSM (그런트·저격수·순찰경비·포대·비행·도약)
→ **Concept**: [[Run and Gun Player Character Architecture]] — 이중 레이어 FSM + 코요테 타임 + AnimationTree
→ **Concept**: [[Run and Gun Bullet System Pattern]] — BulletServer 풀링 + Marker2D + WeaponData
→ **Concept**: [[Run and Gun Level Design Patterns]] — 스크롤 스폰 레코드 + 결정론 패턴
→ **Source**: [[Godot 4 Run and Gun GitHub Repos]] — Succubus-With-A-Gun + GDQuest 마이크로 데모
→ **Source**: [[Godot 4 Run and Gun Tutorial Resources]] — YouTube + GDQuest + Slynyrd
→ **Source**: [[Run and Gun Dev Community Resources]] — Discord + Reddit 허브

## 이전 활성 (Boss Rush 개발 베이스 — 2026-05-12)

**Boss Rush 개발 베이스 종합 리서치** (2026-05-12). 2라운드 · ~20회 웹검색. 설계 이론·성공작·튜토리얼·커뮤니티. 8 페이지 생성.

→ **Synthesis**: [[Research Boss Rush Development Base]] — 10 핵심 발견 (설계원칙·케이스스터디·스코프·커뮤니티)
→ **Concept**: [[Boss Rush Design Fundamentals]] — 8원칙
→ **Concept**: [[Boss Identity Framework]] — 5-축 모델 + 공격 패턴 어휘
→ **Concept**: [[Shmup Boss Design Factors]] — 슘프 5팩터
→ **Concept**: [[Boss Rush Content Sizing]] — $12.99 = 10-12 보스 · 즉시 재시작

## 이전 활성 (Boss Rush GitHub 베이스라인 — 2026-05-12)

→ **Synthesis**: [[Research Boss Rush GitHub Baseline Repos]] — 레포 7종 + LimboAI
→ **Concept**: [[Boss Rush Godot Implementation Pattern]] — FSM/BT/AnimationTree + 체크리스트

## 이전 활성 (Steam 장르 분석 시리즈 — 2026-05-12)

→ [[Research Steam 2026 Genre Competition Update]] · [[Research Steam Low Competition Genre Analysis]] · [[Research Steam Indie Short Dev Genre Landscape]]

## Top Pages To Read First

0. [[Research Run and Gun Development Base]] — **NEW LATEST**. 런앤건 구현 베이스 종합
0b. [[Run and Gun Enemy AI Archetypes]] — 6종 FSM + Echo 구현 우선순위
0c. [[Run and Gun Player Character Architecture]] — 이중 레이어 FSM + 코요테 타임 (GDScript 코드 포함)
0d. [[Run and Gun Bullet System Pattern]] — BulletServer + WeaponData (GDScript 코드 포함)
1. [[Research Boss Rush Development Base]] — 보스러시 설계 8원칙 종합
2. [[Boss Rush Design Fundamentals]] — 보스 GDD 작성 전 필독
3. [[Boss Identity Framework]] — 5-축 모델 + 패턴 어휘
4. [[Research 8-Way Aim Usability For Run-and-Gun]] — Echo Input #1 GDD 갱신 권고 6항
5. [[Bot Validation Catalog Summary]] — 14 페이지 단일 진입점

## TL;DR For my-game

### 락인된 차별화 (변경 없음)
- 시간 되감기 (PoP-style 자원 모델)
- 콜라주 비주얼 / 가까운 미래 SF / 솔로 + Easy 토글

### 런앤건 구현 베이스 핵심 결론 (2026-05-12 신규)
- **적 구현 순서**: 그런트 → 순찰경비 → 포대 → 저격수 → 비행체
- **플레이어**: 이중 레이어 FSM (이동 ⊥ 액션) + 코요테 타임(6-12f) + 점프 버퍼(8-12f)
- **불릿**: BulletServer 싱글턴 풀링, Marker2D 스폰, WeaponData Resource
- **레벨**: 스크롤 위치 기반 스폰 레코드 → 결정론 + 시간 되감기 호환
- **구현 조합**: GDQuest 이동 모듈 + ranged-attacks + hitbox-hurtbox + Chronobot 구조 참고

### 보스러시 베이스 핵심 (2026-05-12)
- 10-12 보스 / $12.99 / 즉시 재시작 / 각 보스에 시그니처 무브 1개

### Tier 1 두 번째 axis (2026-05-10)
- Mark of the Ninja 가시화 원칙 (→ [[Stealth Information Visualization]])

### 콘트라 생존 규칙
1. 2D 측면 고수 · 2. 한 번에 한 axis · 3. 두 후속 재사용 = 검증 자산

## Recent Decisions

- **[2026-05-12]** 🎮 **런앤건 구현 베이스 완료** — 6종 적 AI FSM, 이중 레이어 플레이어 FSM, BulletServer 풀링, 스크롤 스폰 레코드. GDD 구현 단계 진입 준비 완료.
- **[2026-05-12]** 🎮 **Boss Rush 개발 베이스 완료** — 8원칙·5-축·슘프 5팩터·10-12보스/$12.99. 보스 GDD 작성 준비 완료.
- **[2026-05-11]** 🎯 **8방향 조준 검증** — FACING_THRESHOLD 0.15, hysteresis ±4°, XAG 107.
- **[2026-05-10]** 🤖 **봇 검증 카탈로그 14페이지 완성** (→ [[Bot Validation Catalog Summary]])
- **[2026-05-08]** 📖 Echo Story Spine 락인 (→ [[Echo Story Spine]])

## Open Questions

### 런앤건 구현 (2026-05-12 신규)
- **[NEW]** NavigationAgent2D + Godot 4.6 결정론 호환성 — 경로 탐색 비결정론 요소 가능
- **[NEW]** 시간 되감기 + 적 AI FSM 상태 롤백 스코프 미결정
- **[NEW]** qurobullet GDExtension Godot 4.6 호환성 미검증
- **[NEW]** 수평 스크롤 카메라 방식 미결정 (zone-trigger vs smooth-follow)

### Boss Rush 구현
- Echo 시간 되감기 + 보스 FSM 롤백 호환성 미검증
- LimboAI BT 상태 스냅샷 직렬화 미검증

### Echo Tier 1
- 시간 되감기 가시화: 빨간 예측 탄도 = 모든 적탄 vs 다음 1초?
- 토큰 충전 방식 (자동/적 처치/픽업)

## Cross-Reference Density

- Concepts: **60** (+4: Run and Gun Enemy AI Archetypes, Run and Gun Player Character Architecture, Run and Gun Bullet System Pattern, Run and Gun Level Design Patterns)
- Reference games: 23
- Characters / fictional entities: 1
- Sources catalogued: **29** (+3: Godot 4 Run and Gun GitHub Repos, Godot 4 Run and Gun Tutorial Resources, Run and Gun Dev Community Resources)
- Synthesis pages: **19** (+1: Research Run and Gun Development Base)
- Design baselines: 1 · Story spines: 1
- Total wiki files: **139** (.md, +8 — 런앤건 개발 베이스 리서치)
