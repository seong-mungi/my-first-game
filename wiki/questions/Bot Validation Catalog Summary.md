---
type: synthesis
title: "Bot Validation Catalog Summary"
created: 2026-05-10
updated: 2026-05-10
tags:
  - catalog
  - summary
  - bot
  - validation
  - architecture
  - echo-applicable
  - meta
status: developing
question: "Echo 봇 검증 카탈로그 14 페이지의 통합 요약과 횡단 원칙은 무엇인가?"
answer_quality: solid
related:
  - "[[Deterministic Game AI Patterns]]"
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[GDD Bot Acceptance Criteria Template]]"
  - "[[RL Reward Shaping For Deterministic Boss]]"
  - "[[Bot Human Validation Reconciliation]]"
  - "[[Determinism Verification Replay Diff]]"
  - "[[Death Heatmap Analytics]]"
  - "[[Ghost Replay System For Time Rewind]]"
  - "[[Non-Boss Bot Validation Suites]]"
  - "[[AI Assisted Boss Pattern Generation]]"
  - "[[Accessibility Mode Bot Validation]]"
  - "[[Speedrun Discovery Via RL Bot]]"
sources: []
---

# Bot Validation Catalog Summary

Echo 봇 검증 카탈로그 14 페이지를 단일 진입점으로 압축. 4 tier 구조, 횡단 원칙, 솔로 개발자 로드맵, 그리고 카탈로그가 도출한 Echo 디자인 비협상 결정들의 인덱스다.

## 카탈로그 구조

```
WHY → WHAT → HOW (4) → GAP (3) → SIGNATURE (2) → FRONTIER (3)
[T0]  [T0]   [T0]      [T1]      [T2]              [T3]
```

**핵심 명제**: Echo의 결정론은 봇 검증을 자동화 가능하게 만드는 자산. 봇은 게이트(디자인 약속 검증), 인간은 등급(재미와 만족 검증).

## Tier 0 — Foundation (6 페이지)

### 정의 (WHY + WHAT)

| 페이지 | 핵심 |
|---|---|
| [[Deterministic Game AI Patterns]] | AI 활용 4 zone — ① 런타임 (BT/FSM/GOAP) ② 메타 (디렉터, 부분 양보) ③ 오프라인 (분석/튜닝, 무관) ④ 플레이어 보조 (고스트, 결정론 보존). 황금률: AI는 패턴을 만들거나 측정하거나 미러링 — 런타임 변형 X. |
| [[AI Playtest Bot For Boss Validation]] | 4 봇 아키타입 — Random (floor) / Scripted (ceiling) / Heuristic (능숙한 플레이어) / RL (인간 학습 곡선). 메트릭: 클리어, 사망 분포, 학습 곡선, 시간 메커닉. |

### 구현 (HOW × 4)

| 페이지 | 핵심 |
|---|---|
| [[Bot Validation Pipeline Architecture]] | B+C+D 통합. **B**: TCP+msgpack 락스텝 8 envs 병렬 학습 (~8× 가속). **C**: HTML 대시보드 + verdict 자동 + GitHub Actions CI 게이트. **D**: 봇 결과 → GDD AC 비교 → 코드 또는 디자인 수정 자동 루프. |
| [[Heuristic Bot Reaction Lag Simulation]] | 9프레임 인간 반응 지연 (perception 6f + action 3f). Per-modality lag (visual 11f / audio 9f / 자기 상태 3f). Echo의 9프레임 되감기 윈도우 = 트레인드 게이머 반응 floor. |
| [[GDD Bot Acceptance Criteria Template]] | GDD 8.2 봇 검증 섹션 표준 YAML. 4 시스템 템플릿 (boss / mob / movement / weapon). Tier discipline (ci < 10분 / nightly < 2시간 / release < 12시간). |
| [[RL Reward Shaping For Deterministic Boss]] | Echo PPO 보상 (damage×10 / death-100 / clear+500 / phase+50 / rewind+5/-2). 프레임 생존 = 0 (스톨 익스플로잇 차단). 커리큘럼 4단계. |

## Tier 1 — Gap Coverage (3 페이지)

| 페이지 | 핵심 통찰 |
|---|---|
| [[Bot Human Validation Reconciliation]] | 4사분면 — ✅ Ship / ⚠️ Hidden Defect (봇 PASS 인간 FAIL = 시각/오디오/인지 부하) / 🔧 Bot Weak (봇 FAIL 인간 PASS = lag 너무 큼) / ❌ Design Failure. 양방향 override 룰. |
| [[Determinism Verification Replay Diff]] | 같은 입력 2번 → 프레임별 state hash diff. 첫 발산 = 버그 위치. CI: 100 seed × 2 run. Godot 4.6 footgun 카탈로그 10종. Echo 시그니처: 시간 되감기 torture (라이브 vs 스냅샷/복원 path 분리 검증). |
| [[Death Heatmap Analytics]] | 3 직교 뷰 (spatial / temporal / pattern). DBSCAN 자동 클러스터, 안전지대 검출 (역문제: presence > 0 ∩ death == 0 flood fill). 빌드 비교 회귀 검출기. 봇/인간 텔레메트리 공유 스키마. |

**Tier 1 의의**: Tier 0 풀스택이 작동하기 위한 기반 — 인간 검증 통합 + 결정론 자동 검증 + 시각화 진단.

## Tier 2 — Signature & Coverage (2 페이지)

| 페이지 | 핵심 |
|---|---|
| [[Ghost Replay System For Time Rewind]] | Echo 시그니처 확장. 3 고스트 소스 (PB / Dev Gold / Async Phantom). 시간 되감기 동기화 디폴트. 콜라주 시안 톤 + alpha 0.45 + motion trail. Hybrid 데이터 포맷 (input log + 5초 keyframe). |
| [[Non-Boss Bot Validation Suites]] | 4 비-보스 스위트. **Movement**: 점프 그리드 + rewind torture. **Mob Wave**: 잡몹 비협상 룰 (되감기 없이 클리어 가능). **Weapon**: DPS ±5% + 무기-vs-적 매트릭스 자동 생성. **Cross-System**: 점프+사격 동시 (Echo 시그니처). |

**Tier 2 의의**: 보스 외 콘텐츠 커버리지 + Echo 시그니처를 학습 도구에서 몰입 도구로 강화.

## Tier 3 — Post-MVP Frontier (3 페이지)

| 페이지 | 핵심 |
|---|---|
| [[AI Assisted Boss Pattern Generation]] | 콘텐츠 양 폭발 도구. 3 메소드 (LLM / 절차 룰 / RL-discovered). Hard constraint 6종 자동 필터 → 봇 패스 → 디자이너 top 10-15. 적용: 잡몹 + 부 보스 + Hard Mode (시그니처 보스 직접 작성). |
| [[Accessibility Mode Bot Validation]] | 모드별 lag 매핑 (Easy 15f / Normal 9f / Hard 6f). Color-blind 자연 검증. Modes Comparison Matrix 자동 (6 모드 × 4 보스). 회귀 검출. |
| [[Speedrun Discovery Via RL Bot]] | RL 시간 페널티 보상. 발견 4분류 + 글리치 결정 매트릭스. **Trackmania 모델**: 출시 시 RL ghost 동봉. Echo 인프라 4단 (replay/leaderboard/glitch doc/ghost share). 솔로 인디 long-tail 동력. |

**Tier 3 의의**: 출시 후 long-tail (커뮤니티 자생, 콘텐츠 양산, 접근성)을 자동화 도구로 뒷받침.

## 5가지 황금률 (카탈로그 횡단)

1. **결정론은 절대** — 모든 봇 검증의 전제. RNG 0, 시드 고정 강제. ([[Determinism Verification Replay Diff]])
2. **AI는 도구 또는 거울** — 패턴을 *만들거나 측정* OK; 런타임 *변형* X. ([[Deterministic Game AI Patterns]])
3. **봇은 게이트, 인간은 등급** — 봇은 약속 검증, 인간은 재미 검증. 둘 다 필수. ([[Bot Human Validation Reconciliation]])
4. **잡몹 ≠ 보스** — 잡몹은 되감기 없이 클리어 가능. 되감기는 보스 시그니처. ([[Non-Boss Bot Validation Suites]])
5. **9프레임은 비협상** — 회피 윈도우 ≥ 9f, 트레인드 게이머 반응 한계 = Echo rewind 윈도우. ([[Heuristic Bot Reaction Lag Simulation]])

## 솔로 개발자 구현 로드맵

```
Week 1 (MVP)              Random + Scripted 봇 + JSON 메트릭 + CI 게이트 (~200 LOC)
                          → 보스당 검증 5분
Month 1 (Polish)          Heuristic+lag9 봇 + HTML 대시보드 + GDD 8.2 표준화
                          + Tier 1 갭 (인간 통합 + 결정론 자동 검증 + 히트맵)
                          → 디자이너 일일 워크플로 자동화
Month 2-3 (Tier 2)        고스트 리플레이 시스템 + 비-보스 봇 스위트 4종
                          → 시그니처 강화 + 콘텐츠 변경 안전성
Tier 3 (Post-MVP)         RL 봇 + AI 패턴 생성 + 접근성 매트릭스 + Speedrun 인프라
                          → 출시 후 long-tail 동력
```

## Echo 디자인에 미친 비협상 결정 (카탈로그 산물)

| 결정 | 도출 페이지 |
|---|---|
| 회피 윈도우 ≥ 9 프레임 | [[Heuristic Bot Reaction Lag Simulation]] |
| 보스 패턴 RNG 0 | [[Deterministic Game AI Patterns]] |
| 잡몹 패턴은 되감기 없이 클리어 가능 | [[Non-Boss Bot Validation Suites]] |
| 시그니처 보스 (1번 / 최종)는 디자이너 직접 작성 | [[AI Assisted Boss Pattern Generation]] |
| Easy 모드 = 토큰 무한 + 텔레그래프 1.5× + 회피 윈도우 12f | [[Accessibility Mode Bot Validation]] |
| 출시 시 RL ghost 동봉 (Trackmania 모델) | [[Speedrun Discovery Via RL Bot]] |
| 결정론 검증을 CI blocking gate | [[Determinism Verification Replay Diff]] |
| GDD 8.2 봇 검증 YAML 의무 임베드 | [[GDD Bot Acceptance Criteria Template]] |

## 진입점 가이드

**처음 카탈로그를 읽는다면**:
1. [[Deterministic Game AI Patterns]] (WHY)
2. [[AI Playtest Bot For Boss Validation]] (WHAT)
3. [[Bot Validation Pipeline Architecture]] (HOW 통합)

**구현 시작**:
1. [[GDD Bot Acceptance Criteria Template]] — 첫 GDD에 봇 검증 행 추가
2. [[Bot Validation Pipeline Architecture]] § Solo-Developer Priority Week 1
3. [[Determinism Verification Replay Diff]] — CI 게이트 first

**디자인 결정 시**:
1. [[Bot Human Validation Reconciliation]] — 봇/인간 verdict 충돌 시
2. [[Heuristic Bot Reaction Lag Simulation]] — 회피 윈도우 / 텔레그래프 길이 결정 시
3. [[RL Reward Shaping For Deterministic Boss]] — 보스 학습 곡선 검증 시

**출시 단계**:
1. [[Accessibility Mode Bot Validation]] — Easy/Hard/색맹 모드 검증
2. [[Speedrun Discovery Via RL Bot]] — long-tail 인프라 구축
3. [[Ghost Replay System For Time Rewind]] — 출시와 함께 ghost 동봉

## 한 줄 요약

> **결정론 위에 봇 검증을 쌓고, 봇 검증 위에 인간 등급을 얹고, 둘 위에 long-tail 인프라를 깐다.** 14 페이지가 이 한 문장의 펼침이다.

## Open Questions (카탈로그 메타 레벨)

- **[NEW]** Tier 1 (Week 1 MVP) 구현 후 카탈로그가 검증되었는가, 아니면 페이지가 더 필요한가?
- **[NEW]** 콘텐츠 도메인 외 (오디오 / 비주얼 / 내러티브)에 봇 검증과 동일한 풀스택 카탈로그 패턴 적용 가능?
- **[NEW]** 카탈로그 14 페이지 간 cross-link density는 충분한가? (lint 권장)
- **[NEW]** 카탈로그가 Echo 외 다른 결정론 게임에 일반화 가능한 범용 자산인가?

## Related (카탈로그 외부 연결)

- [[Solo Contra 2026 Concept]] — 결정론 베이스라인 + 시간 되감기 시그니처
- [[Time Manipulation Run and Gun]] — 9프레임 되감기 윈도우 근거
- [[Modern Difficulty Accessibility]] — 1히트 즉사 + Easy 토글 의무
- [[Boss Two Phase Design]] — 보스 페이즈 구조의 봇 검증 베이스
- [[Contra Per Entry Mechanic Matrix]] — 한-axis-한-번 룰 (AI 패턴 생성 hard constraint)
