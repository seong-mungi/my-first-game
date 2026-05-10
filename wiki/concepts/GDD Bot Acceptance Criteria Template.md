---
type: concept
title: GDD Bot Acceptance Criteria Template
created: 2026-05-10
updated: 2026-05-10
tags:
  - gdd
  - template
  - acceptance-criteria
  - validation
  - tooling
  - documentation
  - echo-applicable
status: developing
related:
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[RL Reward Shaping For Deterministic Boss]]"
  - "[[Boss Two Phase Design]]"
---

# GDD Bot Acceptance Criteria Template

모든 Echo GDD의 Acceptance Criteria 섹션 안 봇 검증 행에 대한 표준화 템플릿. 목표: 모든 측정 가능한 디자인 클레임이 구체적 봇 + 실행 횟수 + pass/fail 밴드를 가진 봇 체크 가능 타깃이 됨.

이 템플릿으로 표현 불가한 디자인 의도는 자동 검증 불가 — 인간 플레이테스트 컬럼에 속하거나, sharpening 필요.

## Where This Lives

Echo의 CLAUDE.md는 GDD 8 섹션 의무. 섹션 8 (Acceptance Criteria)에 두 서브섹션 추가:

```
8.1 Design Intent (인간 검증)
8.2 Bot Validation (자동화)        ← 이 템플릿
```

## Schema (YAML, 프론트매터 또는 코드 블록 임베드)

```yaml
bot_validation:
  enabled: true
  bot_suite: <suite-name>     # 예: "boss_v1", "movement_v1"
  ci_gate: <blocking|advisory>
  metrics:
    - id: <metric_id>
      target:
        min: <float|null>
        max: <float|null>
      bot: <random|scripted|heuristic|heuristic_lag9|rl_ppo>
      runs: <int>
      tier: <ci|nightly|release>
```

## Per-System Templates

### Boss Validation

```yaml
bot_validation:
  enabled: true
  bot_suite: boss_v1
  ci_gate: blocking
  metrics:
    - id: random_win_rate
      target: { max: 0.005 }
      bot: random
      runs: 1000
      tier: ci
    - id: scripted_win_rate
      target: { min: 1.0, max: 1.0 }
      bot: scripted
      runs: 100
      tier: ci
    - id: heuristic_win_rate
      target: { min: 0.30, max: 0.70 }
      bot: heuristic_lag9
      runs: 1000
      tier: nightly
    - id: death_by_phase_p1_share
      target: { min: 0.30, max: 0.50 }
      bot: heuristic_lag9
      runs: 1000
      tier: nightly
    - id: death_by_phase_p4_share
      target: { max: 0.10 }
      bot: heuristic_lag9
      runs: 1000
      tier: nightly
    - id: rewind_save_rate_p3
      target: { min: 0.70 }
      bot: heuristic_lag9
      runs: 1000
      tier: ci
    - id: pattern_no_rewind_p3_clear
      target: { max: 0.0 }
      bot: heuristic_no_rewind
      runs: 200
      tier: ci
    - id: ttfc_rl_5k_episodes
      target: { min: 15, max: 25 }
      bot: rl_ppo
      runs: 5000   # 에피소드
      tier: release
```

### Mob / Wave Validation

```yaml
bot_validation:
  enabled: true
  bot_suite: mob_wave_v1
  ci_gate: advisory
  metrics:
    - id: heuristic_clear_rate
      target: { min: 0.70, max: 0.95 }
      bot: heuristic_lag9
      runs: 200
      tier: ci
    - id: rewind_used_per_wave
      target: { max: 0.5 }   # 잡몹에서 되감기 드물어야
      bot: heuristic_lag9
      runs: 200
      tier: ci
    - id: deaths_in_safe_zones
      target: { max: 0.0 }
      bot: heuristic_lag9
      runs: 200
      tier: ci
```

### Movement / Platforming Validation

```yaml
bot_validation:
  enabled: true
  bot_suite: movement_v1
  ci_gate: blocking
  metrics:
    - id: scripted_traversal_rate
      target: { min: 1.0, max: 1.0 }
      bot: scripted_route
      runs: 50
      tier: ci
    - id: jump_arc_determinism
      target: { max: 0.5 }   # 최대 픽셀 편차
      bot: scripted_jump_grid
      runs: 100
      tier: ci
    - id: rewind_restore_position_drift
      target: { max: 0.0 }   # 정확, 드리프트 없음
      bot: scripted_rewind_torture
      runs: 1000
      tier: ci
```

### Weapon Validation

```yaml
bot_validation:
  enabled: true
  bot_suite: weapon_v1
  ci_gate: advisory
  metrics:
    - id: dps_calibration
      target: { min_pct_of_target: 0.95, max_pct_of_target: 1.05 }
      bot: scripted_dps_dummy
      runs: 50
      tier: ci
    - id: cooldown_determinism
      target: { max: 0.0 }   # 정확 프레임 일치
      bot: scripted_rapid_fire
      runs: 100
      tier: ci
```

## Markdown Embed Pattern

GDD 안에서, YAML을 파서 검출용 펜스 안에 임베드:

```markdown
## 8. Acceptance Criteria

### 8.1 Design Intent (Human Validated)
- [ ] First-death-to-P1 도달 시간 ~30s (인간 플레이테스터 5명)
- [ ] Post-clear 만족도 ≥ 4/5 (인간 5명)
- [ ] 텔레그래프 명료성 등급 ≥ 4/5 (인간 5명)

### 8.2 Bot Validation (Automated)
\`\`\`yaml bot-validation
bot_validation:
  enabled: true
  bot_suite: boss_v1
  ci_gate: blocking
  metrics:
    - id: random_win_rate
      target: { max: 0.005 }
      bot: random
      runs: 1000
      tier: ci
    # …
\`\`\`

**Reports**: `production/qa/bots/reports/<latest>.html`
```

## Parser Contract

CI 도구는 다음을 읽음:
1. `design/gdd/` 아래 모든 `*.md` 파일.
2. `\`\`\`yaml bot-validation` 펜스 추출.
3. YAML 로드, 스키마 검증.
4. 라이브 봇 결과(`production/qa/bots/reports/latest.json`)와 조인.
5. criterion별 verdict 생성, PR 코멘트용 verdict 마크다운 emit.

## Tier Discipline

| Tier | 실행 시점 | 비용 예산 |
|---|---|---|
| `ci` | 매 PR | 모든 GDD 누계 < 10분 |
| `nightly` | main에서 일 1회 | 누계 < 2시간 |
| `release` | 출시 전 게이트 | 누계 < 12시간 |

작성 팁: `ci` tier 메트릭은 갯수와 runs 작게 유지. lag된 휴리스틱 1000 runs ≈ 3분; 가장 critical 한 밴드에 보존. RL 메트릭은 `release` tier 전용.

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| GDD에 raw 테스트 코드 임베드 | GDD는 디자인 의도, 구현 X |
| runs / bot 미지정 타깃 | 재현 불가 — CI 결정론 보장 실패 |
| 소프트 타깃 ("around 50%") | 머신 검증 불가 |
| 출시된 GDD에 `enabled: false` 잔존 | 검증 없는 디자인 클레임 = 드리프트 위험 |
| RNG에 의존하는 메트릭 | 결정론 전제 무력화 |
| 빌드별 변경되는 타깃 + 히스토리 없음 | 회귀 검출 손실 |

## Linking Conventions

- 각 `bot_suite` 이름은 `tools/bots/suites/<suite-name>/` 폴더에 매핑.
- 각 `bot` 이름은 `tools/bots/<bot>.gd` (Godot 측) 또는 `tools/bots/<bot>.py` (RL Python 측) 클래스에 매핑.
- 각 `metric_id`는 봇 JSON 출력 스키마의 키에 매핑.

## Echo's First GDD With This Template

보스 `meaeokkun` GDD 출시 시 위 **Boss Validation** 템플릿이 미리 채워진 채 출시됨. 이 템플릿의 값들은 데이터로 덮어쓰일 때까지 Echo의 *de facto* 디폴트:
- Heuristic 30–70% 밴드
- Death-by-Phase 전반부 집중 (P1 ≥ 30% ≥ P4 ≤ 10%)
- Rewind Save Rate ≥ 70%
- Pattern-without-Rewind P3 = 0%

## Open Questions

- **[NEW]** Bot-validation YAML 스키마 권위 사양 위치 — `docs/registry/` 또는 새 `tools/bots/schema.yaml`?
- **[NEW]** Bot-validation YAML이 상속 지원? (디폴트 보스 템플릿 위에 보스별 오버라이드)
- **[NEW]** GDD 작성 스킬 (`/design-system`)이 빈 8.2 Bot Validation 블록 자동 삽입?
- **[NEW]** Bot-validation 블록 부재가 CI 경고 vs "인간 전용 검증 의도"로 수용?
