---
type: concept
title: Accessibility Mode Bot Validation
created: 2026-05-10
updated: 2026-05-10
tags:
  - bot
  - validation
  - accessibility
  - difficulty
  - design-pattern
  - echo-applicable
  - tier-3
status: developing
related:
  - "[[Modern Difficulty Accessibility]]"
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[GDD Bot Acceptance Criteria Template]]"
  - "[[Solo Contra 2026 Concept]]"
---

# Accessibility Mode Bot Validation

Echo의 1히트 즉사 + 시간 되감기 시그니처는 [[Modern Difficulty Accessibility]] 권고로 Easy 토글이 의무화됨. 그런데 Easy 모드가 *정말로* 더 쉬운지 누가 검증하나? Easy가 Normal과 비슷하면 접근성 약속 위반. Easy가 너무 쉬워 챌린지 0이면 학습 곡선 무너짐. 이 페이지는 Easy/Normal/Hard 모드를 봇으로 자동 검증하는 패턴이다.

추가 보너스: 색맹 모드 / 자막 / 입력 보조 등 다른 접근성 설정도 봇 검증의 자연스러운 표면.

## Why Bot-Validate Accessibility Modes

| 모드 | 인간 플레이테스트 비용 | 봇 검증 가치 |
|---|---|---|
| Normal | 표준 (5-8명) | 메인 게이트 |
| Easy | Normal × 2 (다양한 스킬 레벨 필요) | 회귀 검출 매우 가치 |
| Hard | 추가 5명 (스피드러너) | 회귀 검출 가치 |
| Color-blind | 시각 다양성 풀 | 봇이 색상 무시 → 자연 검증 |
| Auto-jump / Auto-aim | 결정론 검증 필요 | 봇이 적격 |

> **결론**: 인간 풀 큐레이션 비용이 모드 수에 따라 곱연산. 봇 검증으로 회귀 검출만이라도 자동화하면 ROI 매우 큼.

## Echo Accessibility Modes (참고)

[[Modern Difficulty Accessibility]] + [[Solo Contra 2026 Concept]] 기반:

| 모드 | 변경 사항 |
|---|---|
| **Easy** | 되감기 토큰 무한, 텔레그래프 1.5×, 9 → 12 프레임 회피 윈도우 |
| **Normal** | 디폴트 (Echo 비협상 코어) |
| **Hard** | 토큰 50% (5→3), 텔레그래프 0.8× |
| **Color-blind 1 (deuteranopia)** | 빨강 → 주황, 시안 마젠타 시그니처 톤 보존 |
| **Color-blind 2 (protanopia)** | 빨강 → 노랑 |
| **Auto-Jump** | 갭 위에서 자동 점프 (입력 보조) |
| **Slow Motion** | 게임 속도 0.7× (입력 lag tolerance 가산) |

## Bot Strategy Per Mode

### Easy Mode 검증

```yaml
easy_mode_validation:
  - id: heuristic_clear_rate_easy
    target: { min: 0.85 }     # Easy는 능숙한 봇이 거의 항상 클리어
    bot: heuristic_lag9
    runs: 200
    tier: ci

  - id: heuristic_lag15_clear_rate
    target: { min: 0.70 }     # 느린 반응 (15f lag) 플레이어도 70%+
    bot: heuristic_lag15
    runs: 200
    tier: nightly

  - id: ttfc_easy_lag15
    target: { max: 10 }       # 첫 클리어 10시도 이내
    bot: heuristic_lag15
    runs: 1000   # 시도 카운트 measurement
    tier: nightly

  - id: rewind_used_per_episode_easy
    target: { max: 3 }        # 무한 토큰이지만 봇이 spam X
    bot: heuristic_lag9
    runs: 200
    tier: ci
```

핵심 통찰: Easy 모드 봇은 **lag 더 큰** 봇 사용. Easy가 정말 쉬운지 검증하려면 *덜 능숙한* 플레이어 시뮬이 필요.

### Hard Mode 검증

```yaml
hard_mode_validation:
  - id: heuristic_clear_rate_hard
    target: { min: 0.10, max: 0.40 }  # 능숙한 봇도 어려움
    bot: heuristic_lag9
    runs: 200
    tier: nightly

  - id: heuristic_lag6_clear_rate_hard
    target: { min: 0.40, max: 0.70 }  # 빠른 반응 (6f lag) 스피드러너 시뮬
    bot: heuristic_lag6
    runs: 200
    tier: nightly

  - id: pattern_no_rewind_hard_clear
    target: { max: 0.0 }      # death-sentence 강제 유지
    bot: heuristic_no_rewind
    runs: 200
    tier: ci
```

### Color-Blind Mode 검증 (자연 봇 검증)

```yaml
colorblind_validation:
  - id: heuristic_clear_rate_no_color_info
    target: { min: 0.40, max: 0.70 }  # Normal 봇 win rate와 거의 같아야
    bot: heuristic_no_color
    runs: 200
    tier: ci
```

봇이 텔레그래프를 모양/움직임으로만 인식 (색상 채널 0). Normal과 비슷한 win rate면 → 텔레그래프가 색상에 *과의존하지 않음* 증명. 차이 > 20pp면 색맹 플레이어가 Normal 못 깨는 결함.

> **자연 검증 통찰**: 봇은 색상 의미를 안 갖고 동작하므로, "색상 없이도 게임 가능"이 봇 패스 = 색맹 플레이어 게임 가능 ≈ 동치.

### Auto-Jump Mode 검증 (결정론 보존)

```yaml
auto_jump_validation:
  - id: auto_jump_rewind_drift
    target: { max: 0.0 }      # 자동 점프 + 되감기 위치 정확
    bot: scripted_auto_jump_torture
    runs: 1000
    tier: ci

  - id: auto_jump_traversal_rate
    target: { min: 1.0 }      # 모든 갭 자동 클리어
    bot: scripted_auto_jump_route
    runs: 50
    tier: ci

  - id: auto_jump_off_normal_traversal_consistency
    target: { max: 0.0 }      # auto-jump ON/OFF 사이 동일 결과
    bot: scripted_auto_jump_compare
    runs: 50
    tier: ci
```

### Slow Motion Mode 검증

```yaml
slow_motion_validation:
  - id: slow_motion_determinism
    target: { max: 0.0 }      # 0.7× 속도에서도 결정론 유지
    bot: scripted_slow_motion_torture
    runs: 100
    tier: ci

  - id: slow_motion_clear_easier
    target: { min: 0.20 }     # Slow motion으로 봇 win rate +20pp 이상
    bot: heuristic_lag9_slow_07x
    runs: 200
    tier: nightly
```

## Modes Comparison Matrix (자동 생성)

봇이 모든 모드 × 모든 보스에서 실행되어 매트릭스 자동 생성:

```
            | Normal | Easy  | Hard  | CB-1  | CB-2  | AJ    |
------------|--------|-------|-------|-------|-------|-------|
meaeokkun   |  47%   |  91%  |  18%  |  44%  |  46%  |  47%  |
spider_v    |  52%   |  88%  |  22%  |  51%  |  53%  |  52%  |
tank_M3     |  41%   |  85%  |  15%  |  39%  |  40%  |  41%  |
final_boss  |  31%   |  78%  |   8%  |  29%  |  30%  |  31%  |
```

자동 진단:
- Easy 컬럼이 모두 ≥ 80% → 약속 충족 ✅
- Hard 컬럼이 모두 < 30% → 의도된 챌린지 ✅
- CB-1 / CB-2가 Normal과 차이 > 5pp → 색상 의존성 결함 ❌
- AJ가 Normal과 다르면 → auto-jump 결정론 결함 ❌

## Implementation Approach

```gdscript
# tools/bots/run_accessibility_matrix.gd
func run_full_matrix() -> Dictionary:
    var bosses := ["meaeokkun", "spider_v", "tank_M3", "final_boss"]
    var modes := ["Normal", "Easy", "Hard", "ColorBlind1", "ColorBlind2", "AutoJump"]
    var matrix := {}
    for boss in bosses:
        matrix[boss] = {}
        for mode in modes:
            var bot_config := _select_bot_for_mode(mode)
            matrix[boss][mode] = _run_bot(boss, mode, bot_config, 200)
    return matrix

func _select_bot_for_mode(mode: String) -> BotConfig:
    match mode:
        "Easy": return BotConfig.new("heuristic_lag15")
        "Normal": return BotConfig.new("heuristic_lag9")
        "Hard": return BotConfig.new("heuristic_lag6")
        "ColorBlind1", "ColorBlind2": return BotConfig.new("heuristic_no_color")
        "AutoJump": return BotConfig.new("heuristic_lag9_auto_jump")
        _: return BotConfig.new("heuristic_lag9")
```

## Per-Mode Lag Mapping (디자이너 가정)

| 모드 | 봇 lag | 시뮬 대상 |
|---|---|---|
| Normal | 9 frames | 능숙한 게이머 |
| Easy | 15 frames | 캐주얼 / 신참 |
| Hard | 6 frames | 스피드러너 / 트레인드 |
| Color-blind | 9 frames + 색 채널 mask | 색맹 능숙 게이머 |
| Auto-Jump | 9 frames + auto behavior | 입력 보조 사용자 |

## Regression Detection (액세서빌리티 회귀)

```python
# 빌드 간 모드 매트릭스 비교
def detect_accessibility_regression(curr_matrix, prev_matrix):
    regressions = []
    for boss in curr_matrix:
        for mode in curr_matrix[boss]:
            curr = curr_matrix[boss][mode]
            prev = prev_matrix[boss][mode]
            delta = curr - prev
            if mode == "Easy" and delta < -0.05:
                regressions.append(f"Easy {boss} 어려워짐: {prev:.2%} → {curr:.2%}")
            if mode in ["ColorBlind1", "ColorBlind2"] and abs(delta) > 0.05:
                regressions.append(f"Color-blind {boss} 드리프트: 색상 의존도 변경 가능")
            if mode == "AutoJump" and abs(delta) > 0.01:
                regressions.append(f"Auto-jump {boss} 결정론 깨짐: 정확 일치해야 함")
    return regressions
```

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| Easy 모드를 디자이너 직관만으로 튜닝 | 매번 다른 보스에서 일관성 깨짐 |
| Easy 봇을 Normal과 같은 lag으로 검증 | "Easy가 더 쉬움" 검증 실패 |
| Color-blind 모드 출시 전 봇 검증 X | 색상 의존 텔레그래프가 출시 후 발견 |
| Auto-jump 모드 결정론 검증 X | speedrun WR 카테고리 비교 불가 |
| Slow motion 모드의 봇 검증 스킵 | 0.7× 속도 결정론 깨짐 발견 못 함 |
| Modes Comparison Matrix 매 빌드 갱신 X | 회귀가 한 모드에서만 발생 시 검출 못 함 |

## Validation Schedule

| Tier | 실행 시점 |
|---|---|
| `ci` | 매 PR — Normal + Easy 만 |
| `nightly` | 매일 — 전 모드 매트릭스 |
| `release` | 출시 전 — 매트릭스 + cross-platform |

CI 비용: 모드 6개 × 보스 4개 × 200 runs = 4800 runs ≈ ~30분 (헤드리스). PR마다 너무 비쌈 → CI는 Normal + Easy 1보스 정도만.

## Open Questions

- **[NEW]** Easy 모드 봇 lag 15 frames이 적절? 데이터 — 캐주얼 플레이어 평균 반응 시간?
- **[NEW]** Color-blind 모드 봇이 색상 채널 mask로 텔레그래프 인식 — 텔레그래프 모양 vs 색상 비중을 어떻게 측정?
- **[NEW]** Auto-jump 모드는 자동 점프 입력이 결정론 일관성 보존하나, 인간 플레이어가 점프 타이밍 학습 X → 학습 가치 손실?
- **[NEW]** 모드 별 봇 검증 결과를 GDD acceptance criteria에 자동 핀? (디자이너 작업량 vs 회귀 검출 ROI)
- **[NEW]** 모드 추가 (예: 한 손 모드 — 입력 키 절반 사용 가능) 시 봇 인프라 확장성?

## Related

- [[Modern Difficulty Accessibility]] — 1히트 즉사 현대 수용성 기반 + Easy 토글 의무
- [[Heuristic Bot Reaction Lag Simulation]] — Lag 변경으로 다양한 플레이어 풀 시뮬
- [[AI Playtest Bot For Boss Validation]] — 모드별 봇 적용 인프라
- [[GDD Bot Acceptance Criteria Template]] — Mode-aware 메트릭 표준화
- [[Bot Validation Pipeline Architecture]] — Modes Matrix가 어디 plug-in
