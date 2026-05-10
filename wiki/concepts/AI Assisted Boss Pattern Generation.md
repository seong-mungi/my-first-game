---
type: concept
title: AI Assisted Boss Pattern Generation
created: 2026-05-10
updated: 2026-05-10
tags:
  - ai
  - design-tool
  - boss
  - pattern-generation
  - offline
  - design-pattern
  - echo-applicable
  - tier-3
status: developing
related:
  - "[[Deterministic Game AI Patterns]]"
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Boss Two Phase Design]]"
  - "[[GDD Bot Acceptance Criteria Template]]"
  - "[[Time Manipulation Run and Gun]]"
  - "[[Contra Per Entry Mechanic Matrix]]"
---

# AI Assisted Boss Pattern Generation

[[Deterministic Game AI Patterns]] Zone ③ (Offline Tools) 안에서 가장 미탐색된 영역: 보스 패턴 자체를 AI가 생성하고 디자이너가 큐레이팅하는 워크플로우. 솔로 개발자가 Tier 3 콘텐츠 양을 늘릴 수 있는 가장 큰 레버리지 지점. 단, AI가 디자인 핵심을 휘두르지 않도록 엄격한 제약과 검증이 필수.

이 페이지는 Echo의 AI 보조 패턴 생성 워크플로 디자인 계약이다: 무엇을 생성하고, 어떤 제약 위에서, 어떻게 검증하며, 디자이너가 어떻게 채택/거부하는가.

## When to Reach For This

| 상황 | AI 보조 가치 |
|---|---|
| Tier 1 (3-5 보스) | 매우 낮음 — 디자이너가 직접 작성 |
| Tier 2 (10-15 보스) | 중간 — 변종 생성에 가치 |
| Tier 3 (16개월 풀 콘텐츠) | 높음 — 패턴 양 폭발 시 ROI |
| 잡몹 패턴 (수백 개 변종) | 매우 높음 |

> **Echo 권고**: Tier 3에서 **잡몹 패턴 + 보스 변종**에만 적용. 시그니처 보스 (1번 보스, 최종 보스)는 디자이너 직접 작성 유지.

## Three Generation Methods

### Method A: LLM-Based (Claude / GPT)
- LLM이 GDD를 읽고 패턴 후보 자연어 → JSON으로 제안
- **장점**: 디자인 의도 컨텍스트 이해, 자연어 제약 반영 가능
- **단점**: 결정론 보장 X (LLM 출력 검증 필요), 사양 외 패턴 생성 가능
- **사용처**: 텔레그래프 디자인 brainstorm, 패턴 변종 생성

### Method B: Procedural with Rules
- 디자이너가 패턴 문법 정의 (탄막 발사 각도, 텔레그래프 길이, 회피 윈도우 등)
- 룰 엔진이 문법 안에서 조합 폭발
- **장점**: 출력 100% 사양 준수
- **단점**: 디자이너 사전 작업 다대, "재미 보존" 자동 X
- **사용처**: 잡몹 변종 대량 생성

### Method C: RL-Discovered
- RL 봇이 보스 클리어 학습 시, 봇이 *어려워하는* 패턴이 좋은 후보
- 또는 절차적으로 생성한 후보들을 RL로 검증, 학습 곡선 기준으로 selecting
- **장점**: 검증된 어려움
- **단점**: 비용 (학습 시간), 사람 재미와 일치 X
- **사용처**: 패턴 hard mode 변종

> **Echo 권고**: **A + B 조합**. C는 너무 비쌈.

## Hard Constraints (절대 위반 X)

AI가 생성한 패턴이 자동 거부되는 조건:

```yaml
hard_constraints:
  - name: dodge_window_minimum
    rule: "회피 윈도우 ≥ 9 frames"
    rationale: "Echo 9프레임 되감기 윈도우 = 인간 반응 한계"
    
  - name: determinism_preserved
    rule: "패턴이 RNG 의존 X"
    rationale: "Echo 핵심 가치"
    
  - name: 2d_side_scrolling
    rule: "패턴이 2D 횡스크롤 안에서 동작"
    rationale: "콘트라 생존 룰 (Source: Contra Per Entry Mechanic Matrix)"
    
  - name: cumulative_phase_structure
    rule: "P_n 패턴은 P_(n-1) 모든 패턴과 호환"
    rationale: "학습 곡선 누적 보존"
    
  - name: telegraph_required
    rule: "모든 lethal 공격은 ≥ 24 frame 텔레그래프"
    rationale: "공정성 + 학습 가능성"
    
  - name: rewind_solvable
    rule: "death-sentence 패턴은 9프레임 되감기로만 회피 가능"
    rationale: "시간 메커닉 강제 (Echo 시그니처)"
```

## Soft Constraints (디자이너 검토 후 조정 가능)

```yaml
soft_constraints:
  - name: pattern_duration
    range: [2.0, 6.0]
    units: seconds
    
  - name: simultaneous_threats
    range: [1, 3]
    rationale: "인지 부하 한계"
    
  - name: arena_coverage
    range: [0.3, 0.7]
    rationale: "안전지대 보존하되 익스플로잇 X"
    
  - name: visual_complexity
    range: [low, medium]
    rationale: "콜라주 톤 가독성"
```

## Generation Workflow

```
1. 디자이너 → GDD section 8 (Acceptance Criteria) + 1 (Overview) 작성
2. AI 보조 도구 → 50-100 패턴 후보 생성 (Method A + B 혼합)
3. 자동 필터: hard constraint 위반 후보 제거 (예상 50% drop)
4. 봇 검증: 남은 후보들에 random + scripted 봇 패스
   - random win > 1% → 제거
   - scripted win < 100% → 제거
5. 휴리스틱 봇 시뮬: dodge_success_rate 측정
   - rate < 30% → "너무 어려움" tag
   - rate > 80% → "너무 쉬움" tag
   - 30-70% → "검토 후보"
6. 디자이너 수동 리뷰: top 10-15 후보 시각 검토
7. 디자이너 채택/거부/수정
8. 채택 패턴 → 보스 GDD 통합 → 인간 플레이테스트
```

## LLM Prompt Template (Method A)

```
당신은 Echo 보스 패턴 디자이너입니다.

## Echo 비협상 제약
- 회피 윈도우 ≥ 9 frame
- 결정론 (RNG X)
- 2D 횡스크롤
- 시간 되감기 메커닉 통합
- 1히트 즉사

## 보스 컨텍스트
{{GDD section 1-2 + 게임 디자인 규약 자동 임베드}}

## 기존 패턴 (P1-P{n-1})
{{기존 패턴 JSON}}

## 임무
P{n}의 패턴 후보 5개를 다음 JSON 스키마로 생성:
{
  "name": "pattern_<id>",
  "telegraph_frames": int,
  "attack_duration_frames": int,
  "dodge_window_frames": int,
  "cause_of_death_if_hit": string,
  "is_death_sentence": bool,
  "spatial_layout": "horizontal_sweep" | "overhead_drop" | ...,
  "audio_cue_type": ...,
  "rationale": "왜 이 패턴이 P{n}에 적합한가, 학습 가치"
}

## 추가 제약
- 패턴마다 P1-P{n-1}과 학습 시너지 1개씩 식별
- death-sentence 패턴은 1개만, 9프레임 되감기 강제
```

## Verified Industry Cases

### Promethean AI (2019+)
- 환경/레벨 디자인 보조
- 디자이너가 "숲" 명령 → 도구가 나무·바위 배치 후보
- 패턴 X 환경 X 둘 다 같은 워크플로 (제안 → 수동 큐레이션)

### OpenAI Game Test Tools (2022+)
- ML 모델이 게임 룰 생성 후보 제안
- 디자이너가 fine-tune
- 학술 논문 단계, 양산 도구 X

### Spelunky 2 (Derek Yu, 2020)
- 절차 생성 룸 + 디자이너 검수
- 시드별 클리어 가능성 봇 검증 (Method B 모범)
- 솔로 개발자 규모 직접 참조 가능

### Hearthstone Dev Tools (Blizzard 비공개)
- 카드 OP 검증을 RL 봇이 수행
- 디자이너가 "이 카드 효과 어떨까" 시뮬레이션

> **Echo 솔로 규모 적합**: Spelunky 2 모델 + LLM 보조. AAA 도구는 over-engineering.

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| AI 생성 패턴 자동 채택 (디자이너 리뷰 X) | 디자인 정체성 표류 — AI는 평균치, 시그니처 X |
| Hard constraint 부재 | 9프레임 미만 회피 윈도우 패턴 통과 → 불공정 보스 |
| 시그니처 보스(첫 보스, 최종 보스)에 AI 보조 | 가장 기억에 남는 패턴이 derivative 됨 |
| LLM 출력을 봇 검증 없이 사용 | 결정론 위반 후보 통과 가능 |
| 한-axis-한-번 룰 위반 (4축 동시 새 패턴) | Contra Rogue Corps 실패 패턴 (Source: [[Contra Per Entry Mechanic Matrix]]) |
| AI 생성 패턴 100% 잡몹/보스 양 채움 | "AI가 만든 콘텐츠" 인식 → 정통성 손실 |

## Tier 3 Implementation Plan

### Phase 1: 절차적 잡몹 변종 생성기
- 잡몹 패턴 문법 정의
- 100 변종 생성 → 봇 필터 → 디자이너 top 20 선택
- ROI: 디자이너 1주 작업 → 100 변종 큐레이팅으로 단축

### Phase 2: LLM 보조 보스 변종
- Tier 3 의 부 보스(side bosses)에 한정
- LLM이 5 후보 → 디자이너가 1 채택 + 수정
- 시그니처 보스는 제외

### Phase 3: RL-Discovered Hard Mode
- 클리어한 보스에 RL 봇이 학습 → 봇이 어려워하는 변종 식별
- Hard Mode 패턴 후보로 사용
- 옵션 (NG+ 또는 챌린지 모드)

## Validation Metrics (AI 도구 자체 검증)

```yaml
ai_tool_validation:
  - id: hard_constraint_pass_rate
    target: { min: 0.40 }     # 50% 이상 통과해야 도구 가치 있음
    
  - id: designer_acceptance_rate
    target: { min: 0.10 }     # 10% 이상 채택되어야 도구 ROI 있음
    
  - id: time_to_pattern_authored
    target: { max: 0.30 }     # 도구 사용 시 패턴 작성 시간 30% 이하
    
  - id: post_acceptance_human_playtest_pass
    target: { min: 0.80 }     # AI 보조 패턴이 인간 플레이테스트 80%+ 통과
```

## Open Questions

- **[NEW]** LLM 비용 — 매 패턴 100개 생성 시 GPT/Claude API 비용 vs 디자이너 시간 절약?
- **[NEW]** 절차 생성 잡몹 패턴이 기존 콘트라 시리즈와 너무 유사하면 IP 위험? ([[IP Avoidance For Game Clones]])
- **[NEW]** AI 보조 패턴을 plays 후 player 가 인지 가능? (uncanny valley 효과)
- **[NEW]** Hard Mode AI 패턴이 Tier 1-2 디자이너 패턴보다 나으면 정체성 위기?
- **[NEW]** AI 생성 패턴의 출처를 GDD에 표기 의무? (Echo Story Spine narrative와 충돌 가능)

## Related

- [[Deterministic Game AI Patterns]] — Zone ③에 위치
- [[AI Playtest Bot For Boss Validation]] — 생성된 패턴 검증 인프라 재사용
- [[Boss Two Phase Design]] — 패턴이 들어갈 보스 구조
- [[GDD Bot Acceptance Criteria Template]] — 패턴이 충족해야 할 검증 기준
- [[Contra Per Entry Mechanic Matrix]] — 한-axis-한-번 룰의 디자인 근거
- [[Time Manipulation Run and Gun]] — 9프레임 되감기 윈도우 제약 근거
