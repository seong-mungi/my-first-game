---
type: concept
title: Deterministic Game AI Patterns
created: 2026-05-10
updated: 2026-05-10
tags:
  - ai
  - game-ai
  - determinism
  - design-pattern
  - cross-genre
  - echo-applicable
status: developing
related:
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Time Manipulation Run and Gun]]"
  - "[[Boss Two Phase Design]]"
  - "[[Solo Contra 2026 Concept]]"
  - "[[Stealth Information Visualization]]"
  - "[[Cuphead]]"
  - "[[Katana Zero]]"
---

# Deterministic Game AI Patterns

결정론(같은 입력 → 같은 결과)은 플레이어가 패턴을 **학습**할 수 있게 하는 토대다. 이런 게임에 AI를 넣는 것은 가능하다 — 단, 플레이어가 마주하는 패턴 표면을 망가뜨리지 않는 영역에서만. 이 페이지는 **AI가 안전하다고 검증된 곳**, 위험한 곳, 그리고 절대 금지해야 할 곳을 카탈로그화한다.

플레이어는 패턴 P를 학습한다. AI는 P를 **만들거나(make)**, **측정하거나(measure)**, **거울처럼 비추는(mirror)** 일은 해도 좋다 — 하지만 런타임에 **변형(mutate)**해서는 안 된다.

## The Core Rule

> **AI는 패턴을 만들거나 분석한다; 이미 학습 시작된 패턴을 변경하지 않는다.**

"AI"의 두 가지 의미:
- **Game AI** = 적/NPC 행동 로직 (Behavior Tree, FSM, GOAP) — 룰 기반, 디자이너 작성.
- **ML/AI** = 학습 시스템 (신경망, RL, 통계 분석).

결정론 게임에서 둘 다 사용 가능. 단, 제약이 다르다.

## Four Zones Where AI Is Safe (or Dangerous)

```
┌─ ① Runtime game AI (적/보스 행동) ─────── 결정론 보존 가능
│
├─ ② Meta layer (디렉터 / 매칭) ─────────── 결정론 부분 양보
│
├─ ③ Offline (디자인 / 튜닝) ────────────── 결정론 무관
│
└─ ④ Player aid (고스트 / 힌트) ────────── 결정론 보존 가능
```

**Echo 정책**: ① YES (FSM + Behavior Tree), ③ YES (오프라인 튜닝), ④ YES (리플레이 고스트), ② LIMITED (잡몹 스폰 디렉터만 — 보스 패턴 절대 X).

## Zone ①: Runtime Game AI (Verified Patterns)

| 패턴 | 검증 사례 | 결정론 |
|---|---|---|
| **Behavior Tree** | Halo (2001), BioShock, Splinter Cell | ✅ 같은 월드 상태 → 같은 노드 선택 |
| **Finite State Machine** | Hollow Knight, Cuphead 보스, Mega Man | ✅ 닫힌 transition 집합 |
| **GOAP** (Goal-Oriented Action Planning) | F.E.A.R. (2005), Tomb Raider | ✅ 같은 goal + 같은 state → 같은 plan |
| **Utility AI** | The Sims, Red Dead Redemption 2 | ✅ 결정론적 점수 함수 |
| **HTN** (Hierarchical Task Network) | Killzone 2, Horizon Zero Dawn | ✅ |

핵심 원리: 행동이 (월드 상태) 함수로부터 발생. 난수, 시간 의존 드리프트, 학습 모두 X. 동적으로 보이지만 증명 가능 결정론.

> **Echo 적용성**: 보스마다 Cuphead-style FSM + Behavior Tree. 페이즈를 상태로, 공격 패턴을 노드로, HP%로 transition. 직접 적합 (Source: [[Boss Two Phase Design]]).

## Zone ②: Meta Layer (Trade-Offs)

| 패턴 | 검증 사례 | 결정론 비용 |
|---|---|---|
| **AI Director** | Left 4 Dead 1·2 | 스폰 타이밍 동적 — 적 자체는 여전히 결정론 |
| **Nemesis System** | Shadow of Mordor (2014), War | 오크 개체별 결정론; 인구 진화 |
| **Drivatar (클라우드 학습 AI)** | Forza Horizon | 비동기 학습; 런타임은 고정 |
| **Crowd Simulation** | Hitman, Watch Dogs | 시드 가능 → 시드 주어지면 결정론 |

**트레이드오프 룰**: AI는 *무엇이* 스폰될지나 *누가* 등장할지를 결정해도 되지만, 학습 단위(보스 패턴, 무기 행동, 플레이어 verb)는 **고정**되어야 함.

> **Echo 적용성**: Nemesis는 부적합 — 보스는 학습 정착을 위해 매 만남마다 정확히 동일해야 함. 잡몹 웨이브 다양성 (고정 AI 행동 안에서)은 OK이며, 비-보스 콘텐츠로 한정.

## Zone ③: Offline AI (Largest ROI)

여긴 결정론 무관 — 개발 시점 도구.

| 패턴 | 검증 사례 | 산출 |
|---|---|---|
| **Death Heatmap Analysis** | Halo 3, Battlefield 시리즈 | 사망 위치 → 레벨 튜닝 |
| **A/B Pattern Testing** | Candy Crush, Hearthstone | 어떤 패턴이 학습 곡선 좋은지 |
| **AI Playtest Bots** | DeepMind StarCraft (AlphaStar), OpenAI Dota (Five) | 자동 밸런스 검증 |
| **PCG Pattern Candidates** | Spelunky 2, No Man's Sky | AI가 100개 생성, 디자이너가 5개 선택 |
| **AI-Assisted Pattern Design** | Promethean AI, 최근 ML 게임 도구 | 보스 패턴 변종 → 디자이너 리뷰 |

> **Echo 적용성**: 솔로 개발자에게 가장 레버리지 높은 영역. 봇으로 보스 난이도 검증 (Source: [[AI Playtest Bot For Boss Validation]]). 사망 분석으로 불공정 패턴 식별. AI 보조 패턴 생성으로 디자이너가 채택/거부할 후보 무대화.

## Zone ④: Player-Aid AI (Echo Sweet Spot)

| 패턴 | 검증 사례 | 결정론 |
|---|---|---|
| **Ghost Replay** | Trackmania, Mario Kart, Super Meat Boy, Celeste | ✅ 결정론 재생 |
| **Best-Run Overlay** | Hollow Knight (speedrun mods), N++ | ✅ |
| **Death-Pattern Hint System** | Resident Evil 4 Remake (Mercenaries) | ✅ |
| **Adaptive Tutorial Triggers** | Half-Life 2 (player tracking) | ✅ |
| **Asynchronous Player Messages / Phantoms** | Dark Souls, Elden Ring | ✅ async, 런타임 변경 X |

> **Echo 시너지**: 9프레임 되감기 + 고스트 오버레이는 자연스러운 페어링. 플레이어의 이전 베스트 시도가 현재 런 옆에서 재생 → "신체 기억" 판타지 강화 (Source: [[Time Manipulation Run and Gun]], [[Solo Contra 2026 Concept]]).

## Verified Reference Cases

### Cuphead (StudioMDHR, 2017) — FSM Boss Canon
모든 보스가 결정론 FSM. 페이즈 순서 고정. 난수 0. Echo의 직접 아키텍처 모델 (Source: [[Cuphead]]).

### F.E.A.R. (Monolith, 2005) — GOAP
병사들이 동적으로 계획 (엄폐물 → 측면 이동 → 사격) — 그러나 같은 상태에선 같은 계획. 학습성을 깨지 않으면서 동적 AI 일루전. Echo 잡몹 AI 레퍼런스로 유용.

### Trackmania (Nadeo, 2003+) — Ghost Canon
개인 베스트, 친구, 월드 레코드 고스트가 플레이어 옆에서 동시 달림. 결정론 재생; 학습 증폭기. Echo 보스 리플레이 오버레이의 직접 후보.

### Shadow of Mordor (Monolith, 2014) — Nemesis
오크 개체별 결정론 메모리, 동적 내러티브. **Echo에는 X** — 보스는 재현 가능해야지 개인화되어선 안 됨.

### Left 4 Dead (Valve, 2008) — AI Director
디렉터가 스폰 웨이브 조정; 좀비 행동은 절대 변경 X. 경계선 정립: 동적 *수량*, 결정론 *단위*. Echo 잡몹 웨이브에만 부분 적합.

## Echo Priority Recommendations

### 🟢 Recommended (Tier 1)
1. **보스마다 FSM + Behavior Tree** — Cuphead 모델.
2. **고스트 리플레이 시스템** — 재시도에 개인 베스트 오버레이.
3. **개발자 사망 히트맵 분석** — 플레이테스트 데이터로 불공정 패턴 식별.

### 🟡 Evaluate (Tier 2)
4. **AI 플레이테스트 봇** — 자동 밸런스 검증 ([[AI Playtest Bot For Boss Validation]]).
5. **잡몹 웨이브 디렉터 (가벼움)** — 고정 AI 안에서 스폰 순서 다양화; 보스 패턴 절대 변경 X.
6. **AI 보조 패턴 후보 생성** — 디자이너 큐레이션.

### 🔴 Banned (Echo 정체성 충돌)
7. ❌ 런타임 적응형 난이도 — 결정론 깸, 학습 무효.
8. ❌ 랜덤 보스 패턴 — 코어 가치 파괴.
9. ❌ 온라인 학습 ML 적 행동 — 같은 보스가 세션마다 다름.
10. ❌ Nemesis-style 보스 개인화 — 보스는 커뮤니티 speedrun / 공유 전략 가치를 위해 플레이어 간 균일해야 함.

## The Golden Rule

> **AI는 디자이너의 도구이거나 플레이어의 거울이지, 게임의 주재자가 아니다.**

- 디자인 시점: AI 생성·분석·튜닝 (오프라인 OK).
- 런타임 게임 루프: 결정론 행동 시스템 (FSM, BT, GOAP).
- 플레이어 학습 보조: 결정론 리플레이 (고스트, 힌트).
- ❌ 학습 대상 자체를 AI가 런타임에 흔드는 것: 금지.

## Anti-Patterns (Determinism Kills)

| 안티 패턴 | 왜 금지 |
|---|---|
| 적 행동에 RNG | 패턴 학습 불가 |
| 전투 중 동적 난이도 | 패턴이 플레이어 발 밑에서 변함 |
| 절차적 룸 생성 | 외울 게 없음 |
| 가변 입력 버퍼 | "왜 안 됐지?" 발생 |
| 프레임드랍 유발 로직 드리프트 | 결정론 누수 |
| 런타임에 플레이어에 적응하는 ML 모델 | 보스가 더 이상 고정된 시험지 X |

## Open Questions

- **Echo Tier 1**: 고스트 리플레이 오버레이 — 옵트인? 첫 사망 후 항상 ON?
- **Echo Tier 2**: 잡몹 웨이브 디렉터 구현 가치? 완전 고정 스폰이 결정론 정체성에 더 부합?
- **Echo Tier 3**: AI 생성 보스 패턴 후보로 Tier 3 콘텐츠 산출 가속? 2D-측면-고수 / 한-axis-한-번 룰 깨지 않으며? (Source: [[Contra Per Entry Mechanic Matrix]])

## Sources

- DeepMind, "AlphaStar: Grandmaster level in StarCraft II" (2019).
- OpenAI, "Dota 2 with Large Scale Deep Reinforcement Learning" (2019).
- Monolith Productions, GDC talk on F.E.A.R. GOAP (2006).
- Valve, GDC talks on L4D AI Director.
