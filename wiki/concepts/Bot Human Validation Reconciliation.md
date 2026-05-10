---
type: concept
title: Bot Human Validation Reconciliation
created: 2026-05-10
updated: 2026-05-10
tags:
  - validation
  - playtest
  - bot
  - reconciliation
  - methodology
  - design-pattern
  - echo-applicable
status: developing
related:
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[GDD Bot Acceptance Criteria Template]]"
  - "[[Modern Difficulty Accessibility]]"
---

# Bot Human Validation Reconciliation

봇과 인간은 다른 것을 채점한다. 봇은 **설계된 메카닉이 사양대로 동작하는가**를 확인하고, 인간은 **그 메카닉을 플레이하는 것이 보상되는가**를 확인한다. 두 채점은 자주 어긋나며, 어긋남 하나하나가 진단 신호다 — 봇이 감지할 수 없는 영역에 있는 특정 결함 클래스를 가리킨다.

이 페이지는 그 화해(reconciliation) 계약이다: 봇 리포트를 플레이테스트 데이터 옆에 놓고 어떻게 읽을지, 4사분면이 의미하는 바, 그리고 어떤 디자인 레버가 어떤 불일치를 고치는지.

## The Four Quadrants

```
                  HUMAN PASS               HUMAN FAIL
              ┌─────────────────────┬───────────────────────┐
   BOT PASS   │  ✅ SHIP-READY      │  ⚠️ HIDDEN DEFECT      │
              │  모든 기준 충족      │  봇이 놓친 결함        │
              ├─────────────────────┼───────────────────────┤
   BOT FAIL   │  🔧 BOT MODEL WEAK  │  ❌ DESIGN FAILURE     │
              │  봇 모델 부족        │  디자인 수정, 재검증   │
              └─────────────────────┴───────────────────────┘
```

대각선이 아닌 두 사분면(off-diagonal)은 각각 특정 종류의 수정으로 매핑된다.

## Quadrant ⚠️ — Bot PASS / Human FAIL (Hidden Defect)

가장 정보량이 큰 사분면. 봇은 "디자인 작동" 인데 인간은 "느낌이 안 맞음". 정의상 갭은 봇이 볼 수 없는 곳에 있다.

| 플레이테스트 증상 | 가능한 원인 | 수정 |
|---|---|---|
| "언제 회피할지 알 수 없었음" | 시각 텔레그래프 불명확 | 텔레그래프 채도/대비/크기 증가 |
| "랜덤하게 느껴졌음" | 시각적 노이즈가 패턴 암기 방해 | 텔레그래프 위 파티클 감소; 오디오 큐 증폭 |
| "되감기를 쓸 생각조차 못함" | 되감기 어포던스 숨겨짐 | HUD 프롬프트 추가; 첫 되감기 강제 튜토리얼 |
| 봇 회피율은 정상인데 "불공정함" | 인지 부하 — 동시 큐 다수 | 텔레그래프 시차 분리; 데코 요소 1개 제거 |
| "지루했음" | 페이싱 — 학습 비트 사이 너무 김 | 페이즈 단축, 중간 비트 추가 |
| "9프레임 윈도우가 불가능했음" | 오디오 큐 부재 또는 묻힘 | 오디오 믹스 수술 |

**진단 룰**: 봇 휴리스틱이 50% 클리어인데 인간이 < 20% 클리어면, 갭은 *지각(perception)*이지 *메카닉*이 아니다. 메카닉은 검증되었고, 지각은 미검증.

## Quadrant 🔧 — Bot FAIL / Human PASS (Bot Underspec'd)

덜 흔하지만 여전히 정보적. 봇은 "디자인 실패" 인데 인간은 클리어.

| 봇 리포트 증상 | 가능한 원인 | 수정 |
|---|---|---|
| 휴리스틱 win < 20% 인데 인간 win 50% | 봇 lag 너무 큼 (>9f) — 인간은 anticipation 사용 | 캘리브레이션에서 lag 낮춤; 인간은 텔레그래프 완료 전에 단서 읽음 |
| 봇은 Pattern-w/o-rewind 클리어 0인데 인간은 우회 | 휴리스틱 룰 캐스케이드가 회피 변종 누락 | 회피 변종 룰 추가 |
| 봇이 stall / engage 안 함 | 보상 셰이핑 이슈 (RL 한정) | [[RL Reward Shaping For Deterministic Boss]] 참조 |
| 봇은 되감기 안 쓰는데 인간은 자주 사용 | 봇의 위협 감지가 실제 lethal 타이밍 대비 늦음 | `lethal_threat_imminent` 플래그 개선; lag 낮춤 |

**진단 룰**: 능숙한 인간이 휴리스틱 봇을 계속 능가한다면, 봇 모델이 능숙한 인간보다 *약함*. 봇을 튠업하거나 "인간 스킬 천장" 피처로 받아들임.

## Quadrant ✅ / ❌ — Both Agree

둘 다 PASS = ship-ready (재미는 별도 설문).
둘 다 FAIL = 명백한 디자인 실패. 디자인 수정 후 재검증.

## Echo Standard Playtest Survey

모든 Echo 플레이테스트는 봇 리포트와 함께 다음 baseline 데이터를 수집:

```yaml
playtest_survey:
  per_session:
    - id: telegraph_clarity_p1
      type: likert_5
      question: "P1에서 보스의 공격 신호를 얼마나 명확히 읽을 수 있었나요?"
    - id: telegraph_clarity_p3
      type: likert_5
      question: "P3 (death-beam)에서 보스의 공격 신호를 얼마나 명확히 읽을 수 있었나요?"
    - id: rewind_discoverability
      type: likert_5
      question: "되감기를 언제 써야 하는지 이해됐나요?"
    - id: rewind_satisfaction
      type: likert_5
      question: "되감기를 사용했을 때, 강력하게 느껴졌나요?"
    - id: frustration_moments
      type: open_text
      question: "불공정하거나 '값싼 죽음'으로 느껴진 순간을 적어주세요."
    - id: learning_sense
      type: likert_5
      question: "각 죽음이 무언가를 가르쳐줬나요?"
    - id: audio_cue_clarity
      type: likert_5
      question: "보스의 사운드 큐가 시각적으로 일어나는 일과 일치했나요?"
    - id: cognitive_overload
      type: likert_5
      question: "동시에 너무 많은 일이 벌어진 순간이 있었나요?"
    - id: progression_pull
      type: likert_5
      question: "죽은 후 다시 시도하고 싶은 정도는?"
    - id: clear_satisfaction
      type: likert_5
      question: "보스를 깬 후, 만족도는? (클리어 못 했으면 skip)"
  per_session_metric:
    - id: human_attempts
      auto: true   # 게임이 자동 로깅
    - id: human_clear_time
      auto: true
    - id: human_rewind_count
      auto: true
```

## Reconciliation Decision Matrix

봇 메트릭을 설문 집계와 비교:

| 봇 메트릭 | 인간 등가물 | 화해 룰 |
|---|---|---|
| Heuristic win rate | Player clear rate | 차이 > 20pp → 지각(perception) 진단 |
| Rewind Save Rate | 설문: rewind_satisfaction (≥4 = 성공) | 봇 70%인데 인간 3.0/5 → 발견성 문제 |
| Death-by-Phase distribution | Player attempt-to-clear distribution | 봇은 front-loaded 인데 인간은 back-loaded → 페이싱 역전 |
| TTFC (RL) | 인간 평균 시도 횟수 | 봇 20인데 인간 40 → 튜토리얼 / 온보딩 갭 |
| Pattern-no-rewind P3 = 0 | 설문: rewind_discoverability | 봇은 강제하는데 인간은 트리거 안 함 → 튜토리얼 갭 |

## Sample Size Per Side

| 검증 종류 | 봇 표본 크기 | 인간 표본 크기 |
|---|---|---|
| Boss CI gate | 1000 휴리스틱 + 100 스크립트 | — (CI는 봇 전용) |
| Boss release gate | + 5000 RL 에피소드 | 5–8명, 60–90분/명 |
| Difficulty calibration | Lag sweep × 1000 | 12–15명 (스킬 레벨 층화) |
| Tutorial | Scripted-walkthrough verify | 첫경험 플레이어 10명+ |

> **검정력 원칙**: 봇 N은 수천이 가능하지만, 인간 N은 ≥ 5 + 스킬 층화 필수. 인간 5명 이하면 정성적 설문이 통계 검정보다 우선.

## When Surveys Override Bot Verdicts

봇 PASS여도 다음 중 하나 발생 시 출시 안 함:
- 평균 **clear satisfaction** < 3.5 / 5
- 테스터 ≥ 50%가 동일 **frustration moment** 언급
- 테스터 ≥ 3명이 보스를 "**unfair**" 또는 "**cheap**"으로 묘사
- 보스 시그니처 패턴의 **telegraph clarity** < 4 / 5

이런 경우 봇 메트릭 다 녹색이어도 재설계 트리거.

## When Bot Verdicts Override Surveys

인간 PASS여도 다음 중 하나 발생 시 출시 안 함:
- **Random bot wins > 1%** (인간 반응 무관 — 운빨)
- **Scripted bot < 100%** (비결정론 — 지금 인간엔 안 보이지만 추후 치명적)
- **Pattern-without-rewind P3 clears > 0** (되감기 미강제 — 코어 메카닉 무력화)

이건 인간이 아직 인지 못 하지만 speedrun 커뮤니티 형성 시 드러나는 메카닉 결함.

## Workflow

```
1. 보스 구현 → CI 봇 스위트 → green
2. 나이트리 RL 봇 스위트 → green
3. 릴리즈 봇 스위트 (전체 봇 tier) → green
4. 인간 플레이테스트 스케줄 (5–8명, 90분)
5. 집계: 봇 리포트 + 설문 + 자동 로깅 인간 메트릭
6. 화해 리포트 생성 (criterion당 4사분면 배치)
7. 대각선 외 항목별 → fix list
8. 모두 대각선 위로 올 때까지 루프
```

## Reconciliation Report Template

```markdown
# Boss [meaeokkun] — Reconciliation Report 2026-05-12

## Summary
- Bot verdict: PASS
- Human verdict: CONCERNS
- Reconciliation: ⚠️ Hidden Defect — P3에서 텔레그래프 명료성 갭

## Per-Criterion Quadrant Placement
| Criterion | Bot | Human | Quadrant | Action |
|---|---|---|---|---|
| Pattern dodgeable | PASS | FAIL (3.1/5 명료성) | ⚠️ Hidden | P3 텔레그래프 대비 증가 |
| Rewind enforces | PASS | PASS (4.6/5) | ✅ Ship | — |
| TTFC | PASS (TTFC=22) | FAIL (median=38) | ⚠️ Hidden | P1 튜토리얼 비트 추가 |
| Cognitive load | — | FAIL (3.0/5 과부하) | ⚠️ Hidden | P3 텔레그래프 시차 분리 |

## Action Items
1. P3 텔레그래프: 밝기 +50%, 파티클 -30%
2. P1 튜토리얼: 첫 죽음 시 강제 되감기
3. P3 큐 시차: 오디오와 시각 3프레임 분리

## Re-validation
- Bot CI: PR merge 전 필수
- 재플레이테스트: 원래 8명 중 3명, 30분/명
```

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| 인간 플레이테스트 없이 Bot PASS만으로 출시 | 봇은 재미를 채점 못 함; 결함 클래스 통째로 누락 |
| Tuning Knob 변경마다 플레이테스트 재실행 | 비용 과다; 스프린트 단위로 게이트 |
| Random bot 검출을 인간 verdict로 덮어씀 | 출시 전까지 운빨 승리를 못 알아챔 |
| 단일 테스터가 봇 데이터 덮어씀 | n=1은 데이터 아님; ≥ 5 필요 |
| "Hidden Defect" 사분면 무시 | 봇 리포트가 진단 대신 도장 찍기로 전락 |

## Open Questions

- **[NEW]** 화해 리포트를 봇 JSON + 설문 CSV로부터 자동 생성?
- **[NEW]** Echo의 디폴트 인간 플레이테스터 풀 크기 — 5명 (최소) vs 8명 (층화 더 좋음)?
- **[NEW]** 초보 vs 숙련 플레이테스터 verdict 충돌 시 어떻게 가중?
- **[NEW]** "인간 축"만 영향 받는 (시각 명료성) Tuning Knob 변경은 봇 CI 스킵?

## Related

- [[Bot Validation Pipeline Architecture]] — 화해가 파이프라인 어디에 위치하는지
- [[AI Playtest Bot For Boss Validation]] — 방정식의 봇 측
- [[Modern Difficulty Accessibility]] — 접근성 플레이테스트 고려사항
