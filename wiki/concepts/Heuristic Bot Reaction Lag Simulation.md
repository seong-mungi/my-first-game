---
type: concept
title: Heuristic Bot Reaction Lag Simulation
created: 2026-05-10
updated: 2026-05-10
tags:
  - bot
  - heuristic
  - reaction-time
  - validation
  - design-pattern
  - echo-applicable
  - godot
status: developing
related:
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[Deterministic Game AI Patterns]]"
  - "[[Time Manipulation Run and Gun]]"
  - "[[Modern Difficulty Accessibility]]"
---

# Heuristic Bot Reaction Lag Simulation

인공 반응 지연(reaction lag)이 없는 휴리스틱 봇은 부정직하다: 프레임 F를 보고 프레임 F에 행동한다. 이렇게 플레이하는 인간은 없다. 휴리스틱 봇 win rate가 인간 공정성의 의미 있는 프록시가 되려면, 봇이 능숙한 인간이 짊어지는 동일한 시간적 핸디캡을 흡수해야 한다.

패턴: 지각(perception)과 행동(action) 사이에 고정 프레임 지연을 삽입. 측정된 인간 반응 시간 데이터에 매칭되도록 캘리브레이션.

## Why Lag Matters

Lag 없으면 휴리스틱 봇은 "원리적으로 회피 가능한가"만 검증. 현실적 lag 있으면 "텔레그래프를 읽는 인간이 회피 가능한가"를 검증. Echo의 회피 윈도우는 *인간* lag 하에 공정해야지, *기계* lag 하에 공정해선 안 됨.

## Human Reaction-Time Reference

경험적 베이스라인 (검증된 문헌, ~2010–2024):

| 자극 종류 | 평균 반응 시간 | 프레임 @ 60 fps |
|---|---|---|
| 시각 (단순) | ~250 ms | 15 |
| 시각 (복잡 / 선택) | ~350–450 ms | 21–27 |
| 오디오 | ~160 ms | 10 |
| 자기 수용 (자기 신체) | ~80–100 ms | 5–6 |
| 훈련된 게이머 (anticipation 존재) | 150–200 ms | 9–12 |

> **Echo의 9프레임 되감기 윈도우 = 훈련된 게이머 반응 바닥.** 이건 의도된 설계 — 되감기 윈도우는 최소한 플레이어 반응 윈도우만큼 넓어야 하고, 안 그러면 메카닉이 불공정하게 느껴짐 (Source: [[Time Manipulation Run and Gun]]).

## Implementation Pattern

두 지연 표면, 둘 다 필요:

### 1. Perception Lag (관찰 버퍼)

봇의 "현재 관찰"은 N 프레임 전 관찰.

### 2. Action Lag (실행 큐)

봇의 결정이 결정 프레임 M 프레임 후 적용.

총 반응 lag = perception lag + action lag. Echo 디폴트: 6 + 3 = 9 frames.

## GDScript Reference Implementation

```gdscript
class_name LaggedHeuristicBot
extends RefCounted

const PERCEPTION_LAG := 6   # frames
const ACTION_LAG := 3       # frames
const BUFFER_SIZE := PERCEPTION_LAG + ACTION_LAG + 4

var _obs_history: Array[Dictionary] = []
var _action_queue: Array = []      # [{action: Dict, fire_frame: int}]
var _current_frame := 0

func tick(observation: Dictionary) -> Dictionary:
    _current_frame = observation.frame
    _obs_history.append(observation)
    if _obs_history.size() > BUFFER_SIZE:
        _obs_history.pop_front()

    # 지각된 (lag된) 상태 기준 결정
    if _obs_history.size() >= PERCEPTION_LAG:
        var perceived := _obs_history[-PERCEPTION_LAG]
        var decided := _decide(perceived)
        _action_queue.append({
            "action": decided,
            "fire_frame": _current_frame + ACTION_LAG
        })

    # 발화 시점 도래한 액션 소비
    return _consume_due_action()

func _consume_due_action() -> Dictionary:
    var idle := {"move_x": 0, "jump": false, "shoot": false, "rewind": false}
    while not _action_queue.is_empty() and _action_queue[0].fire_frame <= _current_frame:
        idle = _action_queue.pop_front().action
    return idle

func _decide(perceived: Dictionary) -> Dictionary:
    # 텔레그래프 → 점프
    if perceived.boss_state == "telegraph_line" and perceived.boss_phase_t > 0.6:
        return {"jump": true, "shoot": true, "move_x": 0, "rewind": false}
    # death-sentence 텔레그래프 → 다음 죽음 시 되감기 prefetch
    if perceived.boss_state == "telegraph_death_beam":
        return {"jump": false, "shoot": false, "move_x": 0, "rewind": false}
    # 이번 프레임 사망? 되감기
    if perceived.hp == 0 and perceived.rewind_tokens > 0:
        return {"rewind": true}
    # 디폴트: 보스 향해 사격
    return {
        "shoot": true,
        "move_x": sign(perceived.get("boss_pos_x", 0) - perceived.player_pos[0]),
        "jump": false,
        "rewind": false
    }
```

## Per-Modality Lag (Advanced)

현실적 인간은 시각보다 오디오에 빠르게 반응. 소스별 lag 구현:

```gdscript
const LAG_BY_CHANNEL := {
    "visual_telegraph": 11,
    "audio_cue": 9,
    "screen_shake": 7,
    "own_state": 3,
}
```

각 룰이 `_obs_history[-LAG_BY_CHANNEL[channel]]`에서 지각 풀어냄. 오디오·시각 텔레그래프가 타이밍 불일치하는 디자인 결함을 잡음 — 인간 전략은 "오디오 우선 신뢰"로 가고, 봇은 빠른 오디오 채널로 그것을 발견.

## Calibration Sweep

*Echo의 특정 플레이어 풀*에 맞는 lag을 결정하려면 sweep:

```
휴리스틱 봇을 lag = [3, 6, 9, 12, 15, 18] 프레임으로 실행.
각 lag에서 패턴별 dodge_success_rate 측정.

플롯: dodge_rate vs lag.

"공정한" 패턴은 lag = 9 에서 dodge_rate ≥ 70%.
"불공정한" 패턴은 lag = 9 에서 30% 이하.
```

이 sweep은 패턴별 일회성 캘리브레이션, 매 PR 비용 X. 보스 디자인 시점에 실행, 매 PR엔 실행 X.

## Noise / Imperfection Layer (Optional)

진짜 인간은 ~5–10% 텔레그래프 놓침. 노이즈 주입으로 모델링:

```gdscript
const DECISION_DROP_RATE := 0.05
const PERCEPTION_DROP_RATE := 0.02

func _decide(perceived: Dictionary) -> Dictionary:
    if randf() < DECISION_DROP_RATE:
        return {}  # 이번 프레임 큐 놓침
    # ...rest
```

> **주의**: 노이즈 주입은 순수 결정론 깸. 시드 고정 캘리브레이션 런에서만 사용; CI 게이트 런에서 활성화 X.

## What the Lagged Bot Catches

| 결함 | lag이 어떻게 노출 |
|---|---|
| 회피 윈도우 < 9 프레임 | Lag된 봇의 `dodge_success_rate` 붕괴 |
| 텔레그래프 너무 짧음 | 지각 버퍼에 텔레그래프가 충분히 오래 남지 않음 |
| 오디오/시각 불일치 | Per-modality lag 봇이 비대칭 발견 |
| 다단계 패턴 (2개 큐 반응) | 액션 큐 오버플로, 두 번째 큐 누락 |
| 9프레임 미만 체이닝 패턴 | 인간 lag에서 증명적으로 불가능 |

## What Lagged Bot Does NOT Catch

- **인지 부하** — 인간은 4가지 동시 처리 못 함; 봇은 어떤 수든 완벽 처리
- **시각 명료성** — 봇은 픽셀을 정확히 읽음; 인간은 게슈탈트 읽음
- **패턴 암기 피로** — 봇은 모든 것 기억; 인간은 X
- **좌절 / 틸트** — 봇엔 감정 상태 없음

이건 인간 플레이테스트 영역.

## Echo Defaults

```yaml
echo_heuristic_bot:
  perception_lag: 6
  action_lag: 3
  total_lag: 9
  per_modality_lag:
    visual_telegraph: 11
    audio_cue: 9
    screen_shake: 7
    own_state: 3
  decision_drop_rate: 0.0  # CI: 결정론; 캘리브레이션: 0.05
  perception_drop_rate: 0.0
```

## Calibration Schedule
- **보스별, 디자인 페이즈**: 풀 lag sweep (3, 6, 9, 12, 15, 18) × 각 1000 run = ~6000 run (~30분 헤드리스)
- **PR당**: lag = 9만, 100 run (~3분)
- **릴리즈당**: lag sweep at 3 / 9 / 15 — 빠른/느린 플레이어 회복력 검증

## Related Patterns

- [[AI Playtest Bot For Boss Validation]] — 이 구현의 부모 컨텍스트
- [[Bot Validation Pipeline Architecture]] — lag된 휴리스틱이 어디 plug-in
- [[Time Manipulation Run and Gun]] — Echo의 9프레임 되감기 윈도우 근거
- [[Modern Difficulty Accessibility]] — 현대 접근성 기대 하의 회피 윈도우 공정성 의무

## Open Questions

- **[NEW]** 난이도 tier별 lag 구성 (Easy = 12프레임 lag tolerance) → 접근성 설정 검증?
- **[NEW]** Per-modality lag이 복잡성 가치 있나, 아니면 Echo 규모에서 균등 9프레임 충분?
- **[NEW]** 캘리브레이션 sweep 결과를 GDD Tuning Knob 섹션의 디자인 디폴트로 핀?
