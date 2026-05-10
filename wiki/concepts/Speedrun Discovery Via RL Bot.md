---
type: concept
title: Speedrun Discovery Via RL Bot
created: 2026-05-10
updated: 2026-05-10
tags:
  - speedrun
  - rl
  - bot
  - emergent-design
  - design-pattern
  - echo-applicable
  - tier-3
status: developing
related:
  - "[[RL Reward Shaping For Deterministic Boss]]"
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Determinism Verification Replay Diff]]"
  - "[[Ghost Replay System For Time Rewind]]"
  - "[[Time Manipulation Run and Gun]]"
  - "[[Solo Contra 2026 Concept]]"
---

# Speedrun Discovery Via RL Bot

RL 봇이 보스 클리어를 최적화 학습 시, 봇이 발견한 최단 경로는 사실상 speedrun world record (WR) 후보다. Trackmania가 증명한 패턴: AI가 인간보다 빠른 라인을 찾으면 인간 스피드러너가 그 라인 모방 학습 → 커뮤니티 깊이 증가.

이 페이지는 Echo의 RL 봇을 speedrun 도구로 활용하는 디자인 계약이다: 보상 함수 수정, 발견 검증, 인간 도달 가능성 확인, 의도치 않은 글리치 결정 매트릭스, 커뮤니티 형성 인프라.

## Why Speedrun Matters For Echo

[[Solo Contra 2026 Concept]] + [[Time Manipulation Run and Gun]] + 결정론 베이스라인이 Echo를 speedrun-friendly 게임으로 자연 배치:

| Echo 자산 | Speedrun 시너지 |
|---|---|
| 결정론 (CharacterBody2D + 직접 transform) | 같은 입력 = 같은 시간, WR 비교 가능 |
| 1히트 즉사 + 즉시 재시작 | 시도 사이클 짧음, attempts 폭발 가능 |
| 9프레임 되감기 | "되감기 없이 클리어" 카테고리 자연 발생 |
| 시간 메커닉 깊이 | 발견 가능한 trick / 최적화 다수 |
| 1히트 / 보스 분리 구조 | "Any%" / "Boss only" / "No-rewind" 카테고리 |

> **솔로 인디 출시에 speedrun 커뮤니티 = 무료 long-tail 마케팅** ([[Indie Self Publishing Run and Gun]] 천장 10-20만 장 너머의 long-tail 동력).

## RL Reward Modification (Time-Aware)

기존 [[RL Reward Shaping For Deterministic Boss]] 보상 함수에 시간 페널티 추가:

```python
def compute_reward_speedrun(prev_state, curr_state):
    # 기존 보상 함수 (damage, death, clear, phase)
    r = compute_reward_base(prev_state, curr_state)

    # === 시간 페널티: 매 프레임 작은 음수 ===
    r -= 0.05   # 60fps × 0.05 = 3 reward/sec 감소

    # === 빠른 클리어 보너스: 클리어 시점 시간 의존 ===
    if curr_state.boss_hp == 0 and not prev_state.cleared:
        elapsed_seconds = curr_state.frame / 60.0
        time_bonus = max(0, 600 - elapsed_seconds * 5)  # 빠르면 보너스
        r += time_bonus

    return r
```

조정 logic:
- 매 프레임 −0.05 → stalling 봇 자연 회피
- 빠른 클리어 보너스가 일반 클리어 +500보다 더 클 가능 → 봇이 시간 최적화 동기 갖춤
- 의도된 동작: 봇이 "안전하게 천천히" → "빠르게 risky"로 탐색 이동

## What RL Bot Discovers

RL이 5000+ 에피소드 학습 후 흔히 발견:

### Type 1: Optimal Strategy (의도된 발견)
- 보스 패턴별 최적 회피 위치 / 타이밍
- 무기-vs-적 최적 조합 매트릭스
- 페이즈 transition 직전 무료 데미지 윈도우

> **디자이너 결정**: 모두 채택. 의도된 깊이 — speedrunner도 같은 발견.

### Type 2: Edge Case Optimization
- 텔레그래프 0.05초 빠르게 회피 (인간 9f lag 한계 도달)
- 무기 쿨다운 정확 프레임 + 1프레임 재발사 (frame-perfect tech)
- 점프 모서리 픽셀 정확 사용 (subpixel precision)

> **디자이너 결정**: 채택. Speedrun 깊이 = 게임 깊이. 단, 인간 도달 가능 검증 필수.

### Type 3: Unintended Glitch
- 벽 클리핑 (충돌 검출 결함)
- 무적 i-frame 익스플로잇
- 시간 되감기 + 사망 동시 발화로 무한 토큰
- 보스 페이즈 skip (transition 트리거 우회)

> **디자이너 결정**: 매트릭스 (아래 참조).

## Glitch Decision Matrix

```
            | 인간 도달 가능? | 게임플레이 영향 | 결정         |
------------|----------------|------------------|--------------|
1프레임 wall│  No            |  Major exploit   | 수정         |
clipping    │                │                  │              |
------------|----------------|------------------|--------------|
i-frame     │  Yes (frame-   │  Speedrun valid  | 받아들임     |
chain       │  perfect)      │                  │ + 별도 카테고리 |
------------|----------------|------------------|--------------|
무한 토큰    │  Yes (어려움)  │  Game-breaking   │ 수정         |
글리치      │                │                  │              |
------------|----------------|------------------|--------------|
페이즈 skip │  No            │  Speedrun        │ 수정         |
            │                │  trivial         │              |
------------|----------------|------------------|--------------|
sub-pixel   │  Yes (학습     │  Tech depth      │ 받아들임     |
jump        │  가능)         │                  │              |
```

룰:
- **인간 도달 X + Game-breaking** → 수정
- **인간 도달 O + Speedrun valid** → 받아들임 + 별도 speedrun 카테고리 ("Glitchless" / "Any%")
- **인간 도달 O + 트리비얼화** → 수정 (게임 가치 보호)
- **인간 도달 X + 트리비얼화** → 수정 (정직성)

## Human Achievability Verification

RL이 발견한 트릭이 인간에게 가능한지 봇으로 재검증:

```python
def verify_human_achievable(trick_replay):
    """
    트릭을 휴리스틱+lag9 봇으로 재현 시도.
    봇이 같은 결과 도달 가능 = 인간도 가능 (능숙한 게이머).
    """
    bot = HeuristicLag9Bot()
    bot.load_trick_template(trick_replay)
    success_rate = run_bot(bot, runs=100)
    if success_rate >= 0.30:
        return "human_achievable"
    elif success_rate >= 0.05:
        return "frame_perfect_only"   # 스피드러너 한정
    else:
        return "inhuman"              # 글리치 의심
```

매핑:
- ≥ 30%: 채택. 일반 깊이.
- 5-30%: Frame-perfect 카테고리. 스피드러너만.
- < 5%: 글리치 의심, 수동 리뷰.

## Trackmania 모델 (검증된 사례)

Nadeo의 Trackmania (2003+):
- AI 봇이 트랙별 최적 라인 발견
- 인간 스피드러너가 라인 모방
- Trackmania 커뮤니티가 1990년대 이후 가장 큰 인디 racing 커뮤니티
- 게임 출시 후 20년 long-tail 유지

> **Echo 적용**: 출시 시 RL 봇 발견 PB ghost를 게임에 동봉. 첫날부터 "AI가 21초 클리어 — 너는?" 도전장.

## Echo Speedrun Infrastructure

### 인프라 1: Replay Sharing
- `.replay` 파일 ([[Determinism Verification Replay Diff]] 인프라 재사용)
- 결정론 → 같은 빌드 + 같은 시드 = 같은 시간
- 플레이어가 `.replay` 업로드 → 게임이 자동 재생 + 검증

### 인프라 2: Leaderboard
- Steam Leaderboards API
- 카테고리: Any% / Glitchless / No-Rewind / Boss Rush / Easy Mode (별도)
- 자동 검증: 업로드 시 봇이 replay 재생 → 시간 확인 + 글리치 검출

### 인프라 3: Glitch Documentation
- 알려진 글리치 카탈로그 (게임 위키)
- 카테고리별 허용 / 금지 트릭 명시
- 디자이너가 "받아들인" 글리치를 공식화 (경쟁 공정성)

### 인프라 4: Ghost Sharing
- WR ghost 다운로드 → 다음 시도에 오버레이 ([[Ghost Replay System For Time Rewind]] 확장)
- "1위 기록과 함께 달리기" — Trackmania 핵심 기능

## RL-Discovered WR vs Human WR Race

출시 시점의 권장 시나리오:

```
Day 0:  RL 봇이 모든 보스에 대해 PB 발견 (예: meaeokkun 18s)
Day 0:  게임 출시, RL ghost 동봉 ("Beat the AI: 18s")
Day 1-30: 인간 스피드러너가 RL 라인 모방 + 인간 한정 트릭 추가
Day 30: 인간 WR가 RL 시간 갱신 (예: 16.5s)
Day 30+: 커뮤니티 자생 - 새 글리치 발견, 카테고리 분화
```

이게 *의도된* 진행이고 Echo의 long-tail 가치.

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| RL 발견 트릭을 무조건 게임에 통합 | 봇만 가능한 inhuman 트릭이 카테고리 trivialize |
| 글리치 발견 시 모두 수정 | Speedrun depth 사망 — Echo의 long-tail 가치 손실 |
| RL 봇 시간을 "공식 WR"로 표기 | 인간 vs AI 비교 부정직 |
| 출시 후 패치마다 결정론 깨짐 | 모든 .replay 무효화 → 커뮤니티 신뢰 파괴 |
| 글리치 결정을 비공개 | 커뮤니티가 카테고리 자율 분화 X → 자생 실패 |
| Easy mode에서 speedrun 허용 | "쉬운 모드 WR 14초" — 정통성 손실 |

## Tier 3 Implementation Plan

### Phase 1: RL 봇 + 시간 페널티 보상 (5일)
- 기존 RL 인프라 재사용
- 시간 페널티 추가, 보스 1개에 시범 학습
- 발견된 트릭 수동 검증

### Phase 2: 글리치 결정 매트릭스 (3일)
- 발견 트릭 카테고리별 분류
- 디자이너 결정 → 게임 위키 인프라

### Phase 3: Replay Infrastructure (2주)
- `.replay` 업로드/다운로드
- Steam Leaderboards 통합
- 자동 검증 봇

### Phase 4: WR Ghost (1주)
- 게임에 RL ghost 동봉
- 커뮤니티 ghost 다운로드 통합

총 ~5주. Tier 3 콘텐츠 완성 후 마지막 마일스톤으로 적합.

## Validation Metrics (Speedrun 인프라 자체 검증)

```yaml
speedrun_infra_validation:
  - id: replay_determinism_cross_session
    target: { max: 0.0 }      # 다른 머신에서 같은 replay = 같은 시간
    bot: scripted_replay_torture
    runs: 100
    tier: ci

  - id: leaderboard_glitch_detection_rate
    target: { min: 0.95 }     # 알려진 글리치 95%+ 자동 검출
    bot: scripted_known_glitches
    runs: all
    tier: ci

  - id: rl_human_gap
    target: { max: 0.30 }     # RL WR vs 인간 추정 WR 차이 < 30%
    bot: rl_ppo_speedrun
    runs: 5000
    tier: release
```

## Open Questions

- **[NEW]** RL 봇 발견 트릭이 너무 inhuman이면 (예: frame-perfect 1-frame 입력 체인) 별도 표시? "AI-only category"?
- **[NEW]** 출시 후 패치가 결정론 깨지 않게 한다 — 어떻게 강제? 결정론 결과 hash가 지속되는 한 패치 가능?
- **[NEW]** WR Ghost 다운로드는 옵트인 — 디폴트 ON / OFF?
- **[NEW]** Easy 모드 / Hard 모드 별도 leaderboard? (정통성 vs 접근성 충돌)
- **[NEW]** 무한 토큰 글리치 같은 경우 — 인간이 할 수 있어도 game-breaking이면 수정해야 하는데, 결정 룰 어떻게 명문화?
- **[NEW]** Speedrun.com과 별도 카테고리 vs 게임 내 leaderboard 통합? (커뮤니티 표준)

## Related

- [[RL Reward Shaping For Deterministic Boss]] — 시간 페널티 추가 위한 베이스
- [[AI Playtest Bot For Boss Validation]] — RL 봇 인프라 재사용
- [[Determinism Verification Replay Diff]] — Replay 공유 인프라 재사용
- [[Ghost Replay System For Time Rewind]] — WR ghost 다운로드와 직접 연결
- [[Time Manipulation Run and Gun]] — 9프레임 되감기가 speedrun 카테고리 다양성 유발
- [[Solo Contra 2026 Concept]] — 결정론 베이스라인이 speedrun을 가능케 함
