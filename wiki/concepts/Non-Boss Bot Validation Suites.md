---
type: concept
title: Non-Boss Bot Validation Suites
created: 2026-05-10
updated: 2026-05-10
tags:
  - bot
  - validation
  - movement
  - mob
  - weapon
  - platforming
  - design-pattern
  - echo-applicable
status: developing
related:
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[GDD Bot Acceptance Criteria Template]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[Determinism Verification Replay Diff]]"
  - "[[Death Heatmap Analytics]]"
---

# Non-Boss Bot Validation Suites

봇 검증 카탈로그는 보스 검증에 집중되어 왔지만 ([[AI Playtest Bot For Boss Validation]]), 보스는 게임의 일부일 뿐이다. 무브먼트, 잡몹 웨이브, 무기, 플랫폼 챌린지 — 이 모든 비-보스 콘텐츠도 결정론 봇 검증의 혜택을 받는다. 종종 더 빈번하고 더 빠른 회귀 검출이 필요한 영역들이다.

이 페이지는 Echo의 비-보스 봇 스위트 4종에 대한 디자인 계약이다: 무엇을 검증하며, 어떤 봇이 적합하며, 어떤 메트릭이 중요하며, 보스 스위트와 어떻게 다른지.

## Why Non-Boss Validation Often Trumps Boss Validation

| 비-보스 콘텐츠 | 변경 빈도 | 영향 |
|---|---|---|
| 무브먼트 (점프, 가속, 공중 제어) | 높음 (튜닝 자주) | 게임 전체 |
| 무기 (DPS, 쿨다운, 탄착) | 매우 높음 | 모든 적 인카운터 |
| 잡몹 웨이브 | 중간 (콘텐츠 제작) | 스테이지별 |
| 플랫폼 챌린지 | 중간 | 레벨별 |
| 보스 | 낮음 (확정 후 락) | 보스전만 |

> **결론**: 무기 DPS 변경이 모든 적 인카운터에 파급. 1주마다 회귀 검출 가치 = 보스 검증 1개월 가치와 비슷.

## Suite 1: Movement / Platforming Validation

### What It Validates

- 점프 궤적 결정론 (같은 입력 → 같은 거리)
- 공중 제어 계수 (≤ 1.0)
- 낙하 가속 일관성
- 시간 되감기 후 위치 정확 복원
- 코요테 타임 + 점프 버퍼 정확성
- 플랫폼 챌린지 클리어 가능성

### Bot Types

| 봇 | 역할 |
|---|---|
| `scripted_route` | 디자이너 작성 클리어 입력 시퀀스 |
| `scripted_jump_grid` | 거리/높이별 점프 그리드 시뮬 |
| `scripted_rewind_torture` | 5프레임마다 되감기 + 위치 검증 |

### Metrics

```yaml
movement_validation:
  - id: scripted_traversal_rate
    target: { min: 1.0, max: 1.0 }    # 100% 클리어
    bot: scripted_route
    runs: 50
    tier: ci
  - id: jump_arc_determinism
    target: { max: 0.5 }               # 픽셀 편차 ≤ 0.5
    bot: scripted_jump_grid
    runs: 100
    tier: ci
  - id: rewind_position_drift
    target: { max: 0.0 }               # 정확 복원
    bot: scripted_rewind_torture
    runs: 1000
    tier: ci
  - id: coyote_time_window
    target: { min: 6, max: 6 }         # 정확 6 프레임
    bot: scripted_coyote_probe
    runs: 100
    tier: ci
  - id: jump_buffer_window
    target: { min: 4, max: 4 }
    bot: scripted_buffer_probe
    runs: 100
    tier: ci
```

### Implementation Sketch

```gdscript
# tools/bots/scripted_jump_grid.gd
class_name ScriptedJumpGridBot

const JUMP_DISTANCES := [50, 75, 100, 125, 150, 175, 200]   # 픽셀
const JUMP_HEIGHTS := [0, 25, 50, 75]                        # 상대 Y

func run_grid() -> Dictionary:
    var results := {}
    for dist in JUMP_DISTANCES:
        for h in JUMP_HEIGHTS:
            var landed_pos := simulate_jump(dist, h)
            results["%d_%d" % [dist, h]] = landed_pos
    return results
```

CI 게이트: 위 그리드의 모든 셀이 ±0.5 px 안에 일치해야 함. 한 셀이 변경되면 무브먼트 회귀.

### Death Heatmap Integration

플랫폼 챌린지에선 사망 위치가 직접적 — 떨어진 곳 = 디자인 결함:
- 같은 갭에서 시도 30%+ 실패 → 갭이 점프 능력 초과
- 안전지대가 있으나 도달 불가 → 레벨 디자인 결함

## Suite 2: Mob / Wave Validation

### What It Validates

- 잡몹 웨이브 클리어 시간 (예상 ± 30%)
- 자원 소비 (HP, 되감기 토큰, 탄약 — 적용 시)
- 안전지대에서 사망 0
- 잡몹 AI 결정론 (같은 진입 → 같은 행동)
- 웨이브 난이도 곡선 (초기 < 후기)

### Bot Types

| 봇 | 역할 |
|---|---|
| `heuristic_lag9` | 텔레그래프 반응 능숙한 플레이어 시뮬 |
| `heuristic_no_rewind` | 되감기 없이 잡몹 클리어 가능 검증 |
| `random` | 운빨 클리어 floor 검증 |

### Metrics

```yaml
mob_wave_validation:
  - id: heuristic_clear_rate
    target: { min: 0.70, max: 0.95 }   # 잡몹은 보스보다 관대
    bot: heuristic_lag9
    runs: 200
    tier: ci
  - id: heuristic_no_rewind_clear_rate
    target: { min: 0.50 }              # 되감기 없이도 클리어 가능
    bot: heuristic_no_rewind
    runs: 200
    tier: ci
  - id: random_clear_rate
    target: { max: 0.05 }              # 운빨 클리어 5% 미만
    bot: random
    runs: 500
    tier: ci
  - id: avg_clear_time
    target: { min: 30, max: 90 }       # 30-90초
    bot: heuristic_lag9
    runs: 200
    tier: nightly
  - id: rewind_used_per_wave
    target: { max: 0.5 }               # 평균 0.5 토큰 미만
    bot: heuristic_lag9
    runs: 200
    tier: ci
  - id: deaths_in_safe_zones
    target: { max: 0.0 }
    bot: heuristic_lag9
    runs: 200
    tier: ci
```

### 잡몹 vs 보스 Rule

> **핵심 룰**: 잡몹은 되감기 없이 클리어 가능해야 함. 되감기는 보스 시그니처 — 잡몹에서 강제하면 토큰 인플레이션 + 메카닉 마모.

`heuristic_no_rewind_clear_rate ≥ 50%` 가 이 룰을 봇으로 강제.

## Suite 3: Weapon Validation

### What It Validates

- DPS 캘리브레이션 (목표 DPS ± 5%)
- 쿨다운 결정론 (정확 프레임)
- 탄착 정확성 (8방향 사격 각도)
- 무기-vs-적 매트릭스 (어느 무기가 어느 적 효율적)
- 무기 간 밸런스 (한 무기 dominant strategy 방지)

### Bot Types

| 봇 | 역할 |
|---|---|
| `scripted_dps_dummy` | 표적 더미에 연속 사격, DPS 측정 |
| `scripted_rapid_fire` | 최대 발사율로 쿨다운 검증 |
| `scripted_8way_aim` | 8방향 정확도 검증 |
| `heuristic_per_weapon` | 휴리스틱 봇이 각 무기로 같은 보스 클리어 시도 |

### Metrics

```yaml
weapon_validation:
  - id: dps_pistol
    target: { min: 95, max: 105 }      # 목표 100 DPS ± 5%
    bot: scripted_dps_dummy
    runs: 50
    tier: ci
  - id: dps_shotgun
    target: { min: 142, max: 158 }     # 목표 150 DPS ± 5%
    bot: scripted_dps_dummy
    runs: 50
    tier: ci
  - id: cooldown_pistol_frames
    target: { min: 6, max: 6 }         # 정확
    bot: scripted_rapid_fire
    runs: 100
    tier: ci
  - id: aim_angle_accuracy
    target: { max: 0.1 }               # 0.1 도 편차 이하
    bot: scripted_8way_aim
    runs: 100
    tier: ci
  - id: weapon_vs_boss_winrate_spread
    target: { max: 0.20 }              # 무기 간 win rate 차이 < 20%
    bot: heuristic_per_weapon
    runs: 100  # 무기당
    tier: nightly
```

### 무기-vs-무기 매트릭스 (Echo Tier 2 자산)

```
        | meaeokkun | spider_v | tank_M3 |
--------|-----------|----------|---------|
pistol  |    47%    |    62%   |   31%   |
shotgun |    51%    |    44%   |   58%   |
laser   |    55%    |    52%   |   49%   |
spread  |    49%    |    71%   |   24%   |
```

자동 생성. 디자이너 결정 매핑:
- spread vs spider_v 71% → spread가 spider 너무 강함, 너프 검토
- pistol vs tank_M3 31% → pistol이 tank 너무 약함, 약점 추가 또는 펄스 부여
- 행 분산 < 20% → 무기들이 서로 비슷한 스킬 천장, 차별화 필요

## Suite 4: Cross-System Validation

### What It Validates

- 무브먼트 + 무기 동시 사용 (run-and-gun 정의)
- 시간 되감기가 무기 쿨다운에 미치는 영향
- 8방향 사격 + 점프 동시 (Echo 시그니처)
- 잡몹 + 보스 transition

### Why It Matters

단일 시스템 봇 검증은 통과해도, 시스템 *상호작용*에서 결함 발생. 예:
- 점프 중 사격 = pistol DPS는 정상, but 사격 회수가 ground 대비 30% 감소 (점프 hitstun)
- 시간 되감기 = 무기 쿨다운도 되돌림 (의도) vs 안 됨 (버그)
- 잡몹 → 보스 transition = HP 회복 시점, 토큰 리셋 시점 일관성

### Metrics

```yaml
cross_system_validation:
  - id: jump_shoot_simultaneity
    target: { min: 1.0 }                # 점프 중 사격 가능 (Echo 비협상)
    bot: scripted_jump_shoot
    runs: 100
    tier: ci
  - id: rewind_resets_weapon_cooldown
    target: { min: 1.0 }                # 정확
    bot: scripted_rewind_weapon
    runs: 100
    tier: ci
  - id: phase_transition_state_consistency
    target: { max: 0.0 }                # 드리프트 0
    bot: scripted_phase_transition
    runs: 50
    tier: ci
  - id: 8way_aim_during_movement
    target: { max: 0.5 }                # 8방향 정확도 유지
    bot: scripted_8way_moving
    runs: 200
    tier: ci
```

## Tier Discipline (Non-Boss vs Boss)

| Suite | CI 비용 | Nightly 비용 | Release 비용 |
|---|---|---|---|
| Movement | < 2분 | < 30분 | < 1시간 |
| Mob Wave | < 3분 | < 1시간 | < 2시간 |
| Weapon | < 2분 | < 30분 | < 1시간 |
| Cross-System | < 2분 | < 30분 | < 1시간 |
| **Boss (참고)** | < 5분 | < 1시간 | < 6시간 |

비-보스 스위트는 보스보다 가벼우면서 더 자주 변경되는 영역 커버. ROI 높음.

## Implementation Priority

### 🟢 Tier 1 (MVP) — 다음 1-2주
1. **Movement Suite**: scripted_route + jump_grid + rewind_torture (≤ 1주)
2. **Weapon Suite**: scripted_dps_dummy + scripted_rapid_fire (≤ 0.5주)
3. **Mob Wave Suite**: heuristic_lag9 reuse (≤ 3일)

### 🟡 Tier 2 (Polish)
4. Cross-system validation
5. 무기-vs-무기 매트릭스 자동 생성
6. Death heatmap 통합 (잡몹 웨이브용)

### 🔴 Tier 3 (post-MVP)
7. RL bot for mob wave (의도치 않은 익스플로잇 발견)
8. 무기 progression 봇 검증 (Tier 2 unlock 무기 영향)

## Sample Boss-vs-Non-Boss Bot Suite Compare

| 측면 | 보스 스위트 | 비-보스 스위트 |
|---|---|---|
| Bot 다양성 | Random/Scripted/Heuristic/RL | Scripted 위주 |
| Run 횟수 (CI) | 100-1000 | 50-200 |
| 변경 빈도 | 낮음 (락 후) | 높음 |
| RL 사용 | Tier 3에 가치 | 거의 X (보상 함수 너무 단순) |
| 메트릭 종류 | 학습 곡선 + 페이즈 분포 | DPS / 거리 / 클리어 시간 |
| 인간 플레이테스트 비중 | 매우 높음 | 중간 |

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| 비-보스 검증 스킵 (보스만 봇 검증) | 무기/무브먼트 회귀가 전 스테이지 영향 |
| 보스와 동일한 봇 인프라 강제 | 비-보스는 RL 과잉, scripted로 충분 |
| 무기 DPS만 검증, 매트릭스 X | dominant 무기 발견 못 함 |
| Cross-system 검증 없음 | "각 시스템 OK"가 "조합 OK" 보장 X |
| 잡몹에 되감기 강제 검증 | Echo 룰 위반: 잡몹은 되감기 없이 가능해야 |

## Open Questions

- **[NEW]** 무기-vs-무기 매트릭스 자동 생성 — 매 PR? 매 nightly? 매 release?
- **[NEW]** 플랫폼 챌린지 검증을 별도 스위트로? Movement 안에 포함?
- **[NEW]** 잡몹 웨이브가 시드 의존이면 (스폰 디렉터) 봇 검증을 어떻게 — 시드 고정?
- **[NEW]** Cross-system 봇이 너무 fragile — 한 시스템 변경이 cross test 다 깨면 가치 손실?
- **[NEW]** 무기 progression (Tier 2 unlock)이 들어오면 무기 봇 스위트 explosion — 스위트 매트릭스 어떻게 관리?

## Echo Default Bot Suite Coverage

```yaml
echo_bot_suites:
  movement_v1:
    enabled: true
    files: ["tools/bots/movement/*.gd"]
    ci_gate: blocking
  mob_wave_v1:
    enabled: true
    files: ["tools/bots/mob_wave/*.gd"]
    ci_gate: advisory   # 콘텐츠라 advisory
  weapon_v1:
    enabled: true
    files: ["tools/bots/weapon/*.gd"]
    ci_gate: blocking
  cross_system_v1:
    enabled: false      # Tier 2에 활성화
    files: ["tools/bots/cross_system/*.gd"]
    ci_gate: advisory
  boss_v1:
    enabled: true       # 별도 페이지 참조
    files: ["tools/bots/boss/*.gd"]
    ci_gate: blocking
```

## Related

- [[AI Playtest Bot For Boss Validation]] — 보스 측 자매 페이지
- [[GDD Bot Acceptance Criteria Template]] — 4 시스템 템플릿이 이 스위트와 1:1 매핑
- [[Bot Validation Pipeline Architecture]] — 모든 스위트가 이 파이프라인에 plug-in
- [[Heuristic Bot Reaction Lag Simulation]] — Mob Wave Suite에서 재사용
- [[Determinism Verification Replay Diff]] — Movement Suite의 rewind torture가 직접 재사용
- [[Death Heatmap Analytics]] — Mob Wave + Platforming Suite의 시각화 레이어
