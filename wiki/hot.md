---
title: Hot Cache
updated: 2026-05-08
---

# Hot Cache

Most-relevant pages for current project context. Read this first when picking up the wiki.

## Active Research Topic

**CCGS 프레임워크 분석 + 브라운필드 온보딩(공식 절차 보완) + MetalSlugClone 통합 검토** — 4번째 리서치 라운드 + 공식 예제 보완 (2026-05-08).

→ 보완 (Topic 2 신뢰도 medium→high): [[CCGS Adopt Brownfield Example]] · [[CCGS Reverse Document Workflow Example]]
→ 캐노니컬 절차: [[Brownfield Project Onboarding]] (`/adopt` 4-Phase + 7-Step + 6 원칙)
→ 합성 (Topic 3 판정): [[Opinion MetalSlugClone Base Plus Metal Slug Reference]] (❌ 거부 — 엔진 불일치)
→ 합성 (Topic 1): [[Research CCGS Framework And Local Drift]] (드리프트 없음 확인)
→ 이전 인제스트: [[Metal Slug IP Avoidance Guide]] · [[IP Avoidance For Game Clones]] · [[Broforce]]
→ 이전 합성: [[Research Run and Gun Genre]] · [[Research Battle Cats Subgenre]] · [[Research Lane Defense Game Systems]]

## Top Pages To Read First

1. [[Brownfield Project Onboarding]] — **REVISED 2026-05-08 (high)**. `/adopt` 공식 4-Phase + 7-Step Migration Plan + 6 핵심 원칙. 캐노니컬 절차.
2. [[CCGS Adopt Brownfield Example]] — **NEW**. `/adopt` 8턴 30분 공식 데모 세션. forked context, 갭 4단계, BLOCKING 우선 표면화.
3. [[CCGS Reverse Document Workflow Example]] — **NEW**. `/reverse-document` 4-Stage(Code Analysis → Intent Discovery → Vision Alignment → Generation).
4. [[Opinion MetalSlugClone Base Plus Metal Slug Reference]] — ❌ 거부 판정 + 대안 권고. Unity↔Godot 불일치 정리.
5. [[Research CCGS Brownfield Onboarding]] — Topic 2 합성 + 공식 절차 vs 추론 차이 비교 표.
6. [[Research CCGS Framework And Local Drift]] — 로컬 my-game은 CCGS v1.0.0-beta 현행. 단일 기여자 + 완성 사례 0건 약점.
7. [[CCGS Framework]] — 49 에이전트 / 72 스킬 / 12 훅 프레임워크 개요.
8. [[Abstract Base Class Pattern]] — Godot 4 GDScript/C# 추상 기반 클래스 구현 가이드.
9. [[Boss Two Phase Design]] — State Machine 기반 보스 2페이즈 + 페이즈 전환 연출 체크리스트.
10. [[IP Avoidance For Game Clones]] — 클론 제작 합법 전략 매트릭스. my-game 어떤 장르를 가도 적용.

## TL;DR For my-game

**핵심 장르 선택 분기 (2026-05-08 기준, 3개 옵션):**

### 선택 A: PvZ형 그리드 레인 디펜스
- 5레인, 9×5 그리드, 셀 배치 (공간 결정)
- Sun/Coin 2통화, 첫 10웨이브 수작업
- 덱 5–10슬롯 캡

### 선택 B: Battle Cats형 단일 레인 터그오브워
- 단일 레인, 탭 소환, 자동 전진 (시간 결정)
- 인-배틀 자동 생성 통화 + XP/에너지 메타
- 안티 특성 시스템으로 전략 깊이 보완
- PvE 중심 + 가챠 또는 언락형 수집

### 선택 C: 런앤건 (메탈슬러그형 액션)
- 5요소 코어: 이동·점프·동시사격·적패턴·피격결과
- 무기 픽업 시스템(Metal Slug H/R/F/L/S/I 패턴) 또는 무기 조합(Gunstar Heroes)
- 세 가지 포지셔닝 선택: 순수계승 / 보스러시(Cuphead) / 로그라이트(Huntdown: Overtime)
- 코어가 재미없으면 어떤 확장도 구제 불가 — 코어 프로토타입 우선

### 공통 권장 사항
- PvE vs PvP 조기 결정 (v1에서 둘 다 위험)
- 모바일 vs PC/콘솔 조기 결정 (런앤건은 모바일 적합도 낮음)
- 이벤트 캘린더를 출시 전 6개월치 준비 (라이브서비스 노선일 때)
- 카드 레벨 메타는 v1에서 도입 보류
- **IP 회피 절차** ([[IP Avoidance For Game Clones]]): 어떤 장르를 가도 메카닉 자유 모방 + 비주얼·이름·음악 100% 오리지널. 상업 출시 전 IP 변호사 1회 검토 마일스톤 추가.
- **외부 스캐폴드 채택 전 엔진 일치 확인 의무** ([[Opinion MetalSlugClone Base Plus Metal Slug Reference]]): Unity 코드는 Godot에 이식 불가. 패턴 *아이디어*만 차용하고 Godot 4에서 처음부터 작성 — 더 빠르다.
- **CCGS 활용 시 절차** ([[Research CCGS Brownfield Onboarding]]): 그린필드면 `/start`, 브라운필드면 먼저 `/reverse-document` → 슬롯 채우기 → 에이전트 시드. 테스팅 하네스 구축 전 컨벤션 변경 금지.
- **에이전트 자동 재작성 금지** — 인간 검토 후 시스템 단위 점진적 리팩터.

## Recent Decisions

- **[2026-05-08]** 🔍 `/adopt` 엔진 선결 조건 Q&A 해소 — SKILL.md 권위 출처 직접 검토. 결론: 선결 조건 아님. 엔진 미설정은 Phase 2f에서 자동 진단되며, ADR 존재 여부에 따라 HIGH/BLOCKING으로 등급화. 코드·GDD·ADR 전부 부재인 fresh project만 `/adopt`가 거부. (참고: [[CCGS Adopt SKILL Definition]])
- **[2026-05-08]** 📘 브라운필드 온보딩 캐노니컬 절차 확정 — CCGS `/adopt` 스킬 4-Phase + 7-Step Migration Plan 공식 채택. 초기 추론 절차(medium) → 공식 절차(high)로 격상. (참고: [[Brownfield Project Onboarding]] · [[CCGS Adopt Brownfield Example]])
- **[2026-05-08]** ❌ giacoballoccu/MetalSlugClone + alfredo1995/metal-slug 통합 전략 거부 — 엔진 불일치(Unity 2D ↔ Godot 4). 두 패턴(추상 기반 클래스, 2페이즈 보스)은 [[Abstract Base Class Pattern]] / [[Boss Two Phase Design]]의 Godot 4 예제로 처음부터 구현. (참고: [[Opinion MetalSlugClone Base Plus Metal Slug Reference]])
- **[2026-05-08]** ✅ 로컬 my-game은 CCGS v1.0.0-beta 업스트림 현행 — 별도 동기화 불필요. (참고: [[Research CCGS Framework And Local Drift]])

## Open Questions

- **[NEW]** CCGS로 출시된 완성 게임이 존재하는가? (이슈 #34 미해결 — 프레임워크 검증 부재)
- **[NEW]** Godot 4 GDScript 전용 런앤건 오픈소스 스캐폴드 존재 여부 — Unity 레퍼런스 거부 후 대체 필요
- **[NEW]** `/reverse-document` 스킬이 Godot 4 `.gd` 파일을 정확히 파싱하는가? (브라운필드 온보딩 핵심)
- **[NEW]** Godot 4.5+ `@abstract` 어노테이션의 정확한 동작 방식 — 4.6 환경에서 공식 문서 교차 확인 필요
- **[NEW]** OMC와 CCGS 간 스킬 네임스페이스 충돌 가능성
- 장르 선택: 디펜스(A/B) vs 액션(C)? 팀 역량과 시장 포지션이 결정 변수
- 런앤건이라면 3가지 포지셔닝 — 순수계승 / 보스러시 / 로그라이트?
- 모바일 적합도 — A/B는 모바일 친화, C는 PC/콘솔 친화
- 단일 레인(Battle Cats형) vs 5레인(PvZ형)?
- 가챠 수익화 여부 — 규제 환경과 팀 역량 고려 필요
- 라이브서비스 목표 기간 — 1년 vs 5년+ vs 13년?
- Match length target? Determines whether to use unit variety or upgrade paths.
- Single-player roguelite vs PvP-first?
- Theme/IP for plants/zombies analogue?

## Cross-Reference Density

- Concepts: 22 (장르 17 + Production/IP 1 + Tooling/Framework/Process 5)
- Reference games: 13 (PvZ, Random Dice, Bloons TD, Battle Cats, Cartoon Wars, Grow Castle, Metal Slug, Contra, Gunstar Heroes, Cuphead, Broforce, MetalSlugClone giacoballoccu, metal-slug alfredo1995)
- Sources catalogued: **15** (+2 공식 CCGS 예제: Adopt Brownfield, Reverse Document Workflow)
- Developers / orgs / repos: 4 (George Fan, PONOS, SNK, Donchitos CCGS Repo)
- Synthesis pages: 6 (3 genre research + CCGS framework + brownfield + MetalSlugClone verdict)
- High-confidence pages: **+1** (Brownfield Project Onboarding medium → high after supplement)
