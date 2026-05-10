---
title: Hot Cache
updated: 2026-05-10
---

# Hot Cache

Most-relevant pages for current project context. Read this first when picking up the wiki.

## Active Research Topic

**결정론 게임에서 AI 활용 + 봇 검증** (2026-05-10). PlayerMovement GDD B 섹션 해석에서 출발 → 학습/결정론 통합 → 보스 디자인 적용 → 결정론 게임 AI 활용 패턴 → AI 봇 보스 검증 방법론. 2개 신규 페이지 (concept + synthesis).

→ **Concept 신규**: [[Deterministic Game AI Patterns]] — AI 활용 4 zone (런타임 BT/FSM, 메타 디렉터, 오프라인 분석, 플레이어 보조 고스트) + Echo Tier 1-3 권고
→ **Synthesis 신규**: [[AI Playtest Bot For Boss Validation]] — 4 봇 아키타입 + 메트릭 + Godot 4.6 구현 경로 + 4 검증 시나리오
→ **이전 활성 토픽**: 런앤건 시스템 카탈로그 3축 ([[Research Contra Series Per-Entry Differentiation]] · [[Research Run and Gun Innovative Systems]] · [[Research Cross-Genre Systems For Run and Gun]])
→ **메인 매트릭스**: [[Contra Per Entry Mechanic Matrix]] — 1987-2024 시스템별 생존 verdict
→ **스토리 락인**: [[Echo Story Spine]] — ECHO vs VEIL(AI) 5스테이지 (2026-05-08)
→ **베이스라인**: [[Solo Contra 2026 Concept]] — 시간 되감기 + 콜라주 + 가까운 미래 SF (v0)

## Top Pages To Read First

1. [[Deterministic Game AI Patterns]] — **NEW**. 결정론 게임 AI 활용 4 zone + Echo Tier 1-3 권고 (Cuphead FSM + Trackmania ghost + 사망 히트맵)
2. [[AI Playtest Bot For Boss Validation]] — **NEW**. 4 봇 아키타입 + 메트릭 + 시간메커닉 검증 시나리오 4종
3. [[Research Contra Series Per-Entry Differentiation]] — 콘트라 9 엔트리 차별화 + 생존 규칙
4. [[Research Run and Gun Innovative Systems]] — 7대 검증 혁신 카탈로그
5. [[Research Cross-Genre Systems For Run and Gun]] — 5대 이식 후보 + Echo 권고
6. [[Contra Per Entry Mechanic Matrix]] — 매트릭스 + 생존 규칙
7. [[Stealth Information Visualization]] — Mark of the Ninja 원칙. **Echo Tier 1 추천** — 시간 되감기 가시화
8. [[Time Manipulation Run and Gun]] — PoP/Braid/Katana Zero 3 모델 + Echo 선택 가이드
9. [[Hit Rate Grading System]] — Shattered Soldier 그레이딩 + Echo Tier 2 후보
10. [[Pink Parry System]] — Cuphead 색 어포던스
11. [[Roguelite Metaprogression For Run and Gun]] — slider-vs-gate 규칙 + Galuga 권고
12. [[Echo Story Spine]] — Echo 메인 시나리오 (2026-05-08)
13. [[Solo Contra 2026 Concept]] — 디자인 베이스라인 v0
14. [[Run and Gun Success Pattern Matrix]] — 5작품 불변 코어 7가지
15. [[Boss Two Phase Design]] — HP 임계값 + State Machine 보스 2페이즈

## TL;DR For my-game

**Echo Tier 1 두 번째 axis 권고 (2026-05-10):**

### 락인된 차별화 (변경 없음)
- 시간 되감기 (PoP-style 자원 모델 — 1히트 스테이크 보존, [[Time Manipulation Run and Gun]])
- 콜라주 비주얼 / 가까운 미래 SF / 솔로 + Easy 토글

### Tier 1 추가 권고: 스텔스 가시화 원칙 (Klei / Mark of the Ninja)
- **이유**: 시간 되감기는 본질적으로 "보이지 않는 상태"(토큰, 예측 궤적, 되감기 윈도우). Klei의 binary-affordance 원칙으로 모두 명시 가시화하면 학습 곡선·재미 모두 개선
- **구현 비용**: low (UI 오버레이만, 게임플레이 로직 없음)
- **시너지**: 시간 되감기 메카닉과 직결. 다른 후보(weapon fusion, 핑크 패리)는 입력·인지 부하 경쟁 우려
- **결정 항목**: (a) 빨간 예측 탄도 표시, (b) 은빛 잔상으로 되감기 윈도우, (c) HUD 토큰 카운터

### Tier 2/3 이연 후보
- **Tier 2 평가**: Galuga-style Perk Shop (slider 모델) — 토큰 +1 등 시간 메카닉 결합 perks
- **Tier 2 평가**: Hit Rate 그레이딩 — "rewinds-conserved" S-rank, 트루 엔딩 게이트는 거부 (현대 접근성)
- **Tier 3 only**: 반응형 내러티브 (Hades) — VEIL이 매 죽음마다 확률 멘트 갱신 (대사 양 매우 큼)
- **거부**: 무기 융합(Gunstar) — 인지 부하 경쟁 / 핑크 패리(Cuphead) — 입력 경쟁 / Mode 7·아이소(Neo Contra) — 관점 변경 금지

### 콘트라 생존 규칙 (Echo 설계 비협상 원칙)
1. 2D 측면 고수 — 3D / 톱다운 / 아이소 모두 거부 ([[Contra Rogue Corps]] 2019 사례)
2. 한 번에 한 axis만 추가 — Rogue Corps의 4축 동시 실패 학습
3. 두 후속에서 재사용 = 검증 자산. 단일 엔트리 실험은 옵션 (Mode 7, Neo Contra 아이소)

## Recent Decisions

- **[2026-05-10]** 🤖 **결정론 게임 AI 활용 정책 정립** — AI는 패턴을 만들거나 측정하거나 미러링할 수 있지만, 런타임에 학습 대상 패턴을 변형해서는 안 된다. Echo Tier 1 권고 = Cuphead FSM 보스 + Trackmania-style 고스트 리플레이 + 사망 히트맵 분석. RL 봇은 Tier 3 이연. (참고: [[Deterministic Game AI Patterns]] · [[AI Playtest Bot For Boss Validation]])
- **[2026-05-10]** 🎯 **Echo Tier 1 두 번째 axis = Mark of the Ninja 가시화 원칙** — 시간 되감기 메카닉의 보이지 않는 상태(토큰·예측 탄도·되감기 윈도우)를 모두 명시 가시화. cost low / synergy 매우 높음. weapon fusion·핑크 패리·메타프로그레션은 Tier 2/3 이연. (참고: [[Stealth Information Visualization]] · [[Research Cross-Genre Systems For Run and Gun]])
- **[2026-05-10]** 📊 **콘트라 9 엔트리 차별화 매트릭스 완성** — 1987-2024 시스템별 생존/실패 verdict. 2D-측면-고수 / 한-axis-한-번 규칙으로 Echo 설계 비협상 원칙 도출. (참고: [[Contra Per Entry Mechanic Matrix]] · [[Research Contra Series Per-Entry Differentiation]])
- **[2026-05-10]** 📚 **런앤건 7대 혁신 + 5대 cross-장르 카탈로그** — 재사용 메뉴 정립. Echo가 시간 되감기 외 어떤 axis를 추가할지 평가 자료 완비. (참고: [[Research Run and Gun Innovative Systems]] · [[Research Cross-Genre Systems For Run and Gun]])
- **[2026-05-08]** 📖 Echo Story Spine 락인 — ECHO vs VEIL in NEXUS 2038 (참고: [[Echo Story Spine]])
- **[2026-05-08]** 🎯 Solo Contra 2026 컨셉 락인 v0 — 시간 되감기 + 콜라주 + 가까운 미래 SF (참고: [[Solo Contra 2026 Concept]])
- **[2026-05-08]** 🔍 Q4/Q5 해소 — 1히트 현대 수용성 / 인디 자가퍼블 천장 (참고: [[Followup Modern Acceptance And Indie RnG Threshold]])

## Resolved Questions

> [!key-insight] 2026-05-10 해소
> - **Q (콘트라 시리즈 엔트리별 차별화 시스템은 무엇인가)**: 9 엔트리 모두 매핑 완료 ([[Contra Per Entry Mechanic Matrix]]). 생존 규칙 2개 도출 (2D-고수 / 한-axis).
> - **Q (런앤건에서 검증된 혁신 시스템은 무엇인가)**: 7대 카탈로그 ([[Research Run and Gun Innovative Systems]]).
> - **Q (런앤건에 cross-장르 이식 가능한 시스템은 무엇인가)**: 5대 후보 + Echo 적용 권고 ([[Research Cross-Genre Systems For Run and Gun]]).

> [!key-insight] 2026-05-08 해소
> - **Q4 (1히트 현대 수용성)**: 즉시 재시작 + 결정론 + Easy 토글 1개 조건부 수용
> - **Q5 (0퍼블리셔 200만 장 인디 런앤건)**: 사례 미존재. 자가퍼블 천장 10-20만

## Open Questions

### Echo Tier 1 (2026-05-10 추가)
- **[NEW]** 시간 되감기 가시화 시 빨간 예측 탄도 = 모든 적탄 vs 다음 1초 한정?
- **[NEW]** 토큰 충전 방식 — 자동 시간경과 vs 적 처치 vs 픽업?
- **[NEW]** Easy 모드는 토큰 무한 vs Easy = 가시화 자동 ON?

### Echo Tier 2 평가 후보 (2026-05-10 추가)
- **[NEW]** Perk Shop (Galuga 모델) 도입 여부 — Tier 2 게이트에서 결정
- **[NEW]** Hit Rate "rewinds-conserved" S-rank 도입 여부 — 게이팅 없이 코스메틱만
- **[NEW]** 분기 경로(Hard Corps 모델) — Tier 3 16개월 안에 가능한가?

### Echo Tier 1 (2026-05-08 미해결, 유지)
- **[OPEN]** ECHO 성별 — 코드명 유지 vs 명시 (Tier 1 콘셉트아트 후 결정)
- **[OPEN]** 스토리 톤 — 디스토피아 진지 vs 풍자 펑크 (디스토피아 *기본 가정*)
- **[OPEN]** 시간 되감기 시 적·탄환 동시 vs 플레이어만? (Braid vs 체크포인트 모델)
- **[OPEN]** 콜라주 캐릭터 사진 출처 — 스톡 / 직접 / 생성형 AI?
- **[OPEN]** Godot 4 시간 되감기 구현 패턴 — 상태 스냅샷 vs 입력 리플레이?
- **[OPEN]** 무기 4-5종 카탈로그 — Contra M/F/L/S/R/B 중 어느 3-4개를 SF 재해석?
- **[OPEN]** Easy/Hard 토큰 슬라이더 — 단일 토글 vs 슬라이더?

### 메타 / 장르 잔여 (2026-05-10 추가)
- **[NEW]** Mode 7 회전 스테이지(Contra III)가 후속에서 사라진 이유 — 하드웨어 의존 + 3D 등장 가설
- **[NEW]** Hit Rate 그레이딩이 Konami 외부에서 채택되지 않은 이유 — 현대 접근성 갈등 가설
- **[NEW]** Broforce 이후 파괴 지형 런앤건 후속 부재 이유 — 구현 비용 가설
- **[NEW]** 순수 2D 불릿타임(Max Payne식) 미존재 이유 — 2D 카메라 spectacle 약화 가설

### 그 외 미해결
- 장르 선택: 디펜스(A/B) vs 액션(C)?
- 모바일 적합도 — 런앤건은 PC/콘솔 친화
- 라이브서비스 목표 기간 — 1년 vs 5년+ vs 13년?
- CCGS로 출시된 완성 게임이 존재하는가?

## Cross-Reference Density

- Concepts: **36** (+6: Contra Per Entry Mechanic Matrix, Hit Rate Grading System, Pink Parry System, Time Manipulation Run and Gun, Roguelite Metaprogression For Run and Gun, Stealth Information Visualization)
- Reference games: **23** (+6: Contra Hard Corps, Contra III The Alien Wars, Contra Shattered Soldier, Neo Contra, Hard Corps Uprising, Contra Rogue Corps)
- Characters / fictional entities: 1
- Sources catalogued: 21 (no new dedicated source pages this session — URLs cited inline in synthesis pages)
- Synthesis pages: **13** (+3: Research Contra Series Per-Entry Differentiation, Research Run and Gun Innovative Systems, Research Cross-Genre Systems For Run and Gun)
- Design baselines: 1 (Solo Contra 2026 Concept v0)
- Story spines: 1 (Echo Story Spine)
- Total wiki files: **101** (.md, +15 this session)
