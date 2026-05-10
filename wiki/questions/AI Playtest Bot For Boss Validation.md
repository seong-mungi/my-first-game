---
type: synthesis
title: "AI Playtest Bot For Boss Validation"
created: 2026-05-10
updated: 2026-05-10
tags:
  - research
  - ai
  - playtest
  - boss-design
  - validation
  - tooling
  - determinism
  - echo-applicable
status: developing
question: "결정론 게임에서 AI 플레이테스트 봇으로 보스 난이도를 어떻게 검증하는가?"
answer_quality: solid
related:
  - "[[Deterministic Game AI Patterns]]"
  - "[[Boss Two Phase Design]]"
  - "[[Time Manipulation Run and Gun]]"
  - "[[Solo Contra 2026 Concept]]"
  - "[[Modern Difficulty Accessibility]]"
  - "[[Hit Rate Grading System]]"
sources:
  - "[[Wikipedia Run and Gun]]"
---

# AI Playtest Bot For Boss Validation

결정론 게임은 봇 기반 검증의 이상적 토대다: 같은 입력 → 같은 출력 → 1000회 실행이 통계적으로 의미 있고, 헤드리스 엔진이 분 단위로 수 시간의 플레이를 시뮬레이트. 이 페이지는 봇으로 보스 난이도를 인간 플레이테스터에 노출하기 전에 인증하는 방법론이다.

봇은 **재미를 채점할 수 없다** — 그건 인간 전용 — 하지만 디자이너의 의도(페이즈 분포, 되감기 강제, 학습 곡선)가 GDD가 주장하는 대로 실제로 발화하는지를 증명할 수 있다.

## Why Bots Work in Deterministic Games

| 결정론 게임 | 비결정론 게임 |
|---|---|
| 같은 시드 → 같은 결과 | 실행 간 드리프트 |
| 낮은 N에서도 통계 의미 | 표본 10× 필요 |
| 재현 가능한 실패 케이스 | Heisenbug |
| 헤드리스 가속 가능 | 렌더 결합 타이밍 |

Echo는 60fps 락 + `CharacterBody2D` + 직접 transform (Source: [[Solo Contra 2026 Concept]])으로 달림 — 이 스택은 (상태)의 순수 함수라서 헤드리스 모드에서 수백 fps. **인간 플레이 100시간 = 봇 시간 약 1시간**.

## Four Bot Archetypes (Each Measures a Different Claim)

### ① Random Bot — "Floor" Check
- 매 프레임 랜덤 입력.
- **답하는 질문**: 운으로 이 보스 깰 수 있나?
- **목표**: 1000회에서 win rate 0%.
- **실패 신호**: ≥ 1% 승 → 아레나에 안전지대 존재 또는 한 페이즈 너무 관대.

### ② Scripted Bot — "Ceiling" Check
- 디자이너 작성 최적 입력 시퀀스 재생.
- **답하는 질문**: 이론상 보스 깰 수 있나?
- **목표**: 100회에서 win rate 100%.
- **실패 신호**: < 100% → 비결정론 버그; 같은 스크립트는 매번 동일 승.

### ③ Heuristic Bot — "능숙한 플레이어" 시뮬레이션
- 룰 기반 반응: "텔레그래프 보임 → 점프", "death-beam → 되감기 소비".
- **답하는 질문**: 텔레그래프 읽는 플레이어가 가끔 이기나?
- **목표**: 30–70% 승률.
- **실패 신호**: < 5% → 너무 어려움; > 80% → 너무 쉬움; 이 밴드 밖이면 난이도 클레임 무효.

### ④ Reinforcement-Learning Bot — "인간 학습 곡선" 시뮬
- PPO 등; 수천 에피소드 학습.
- **답하는 질문**: 보스가 학습을 보상하나, 그리고 곡선이 얼마나 가파른가?
- **목표**: 에피소드와 함께 win rate 상승; 페이즈에서 정체 = 그 페이즈가 학습 병목.
- **실패 신호**: 평탄한 학습 곡선 → 학습 불가 보스; 갑작스런 마스터 → 보스가 trivially scriptable.

## Metrics That Matter

### Clear Metrics
| 메트릭 | Echo 목표 (보스 1) |
|---|---|
| Time-to-First-Clear (TTFC) | 15–25 시도 |
| 평균 클리어 시간 | 2–4 분 |
| 30 시도 누적 클리어율 | ≥ 80% |

### Death-Distribution Metrics
- **Death-by-Phase**: P1 ~40%, P2 ~30%, P3 ~25%, P4 ~5% — 전반부 집중 형태가 정통 학습 곡선.
- **Death-by-Pattern**: 단일 패턴이 사망의 > 50% 차지면 튜닝 적신호.
- **Death Heatmap**: 위치별 사망 밀도가 안전지대 존재 검증, 의도하지 않은 kill pocket 노출.

### Learning-Curve Metrics
- **HP-at-Death progression**: 시도 1, 5, 10, 20에서 보스 잔량 HP — 감소 추세여야 함.
- **Survival Time progression**: 시도별 생존 시간 상승.
- **Pattern Success Rate**: 패턴별 회피율이 시도 수와 함께 상승.

### Time-Mechanic Metrics (Echo 고유)
| 메트릭 | 검증 |
|---|---|
| **Rewind Usage Rate** | 사망 직전 되감기 시도 비율. death-sentence 패턴에선 100%에 수렴해야 함. |
| **Rewind Save Rate** | 되감기 소비 후 생존율. 회피 윈도우 ≥ 9프레임 검증. |
| **Pattern-Without-Rewind Clear** | 되감기 비활성 클리어율. death-sentence 페이즈는 0% 도달해야 — 되감기 필수성 증명. |

## Implementation Path (Echo / Godot 4.6)

### Step 1: 헤드리스 + 결정론 검증

```bash
godot --headless --no-window --fixed-fps 60 \
      --script tests/bots/run_boss_bot.gd \
      --bot-type=heuristic --boss=meaeokkun --runs=1000
```

첫 게이트: 같은 입력 로그를 2번 돌려 동일 사망 프레임 확인. 발산 = 비결정론 버그, 봇 작업 진행 전 수정.

### Step 2: 봇 인터페이스 계약

```gdscript
class_name BotInterface

# Game → Bot
func get_observation() -> Dictionary:
    return {
        "player_pos": Vector2,
        "player_velocity": Vector2,
        "player_facing": int,
        "boss_state": String,        # "telegraphing", "attacking", ...
        "boss_pattern_id": int,
        "boss_attack_phase_t": float, # 0..1 텔레그래프 진행률
        "projectiles": Array,
        "hp": int,
        "rewind_tokens": int,
        "frame": int
    }

# Bot → Game
func apply_action(action: Dictionary):
    # action = {move_x: -1/0/1, jump: bool, shoot: bool, rewind: bool}
```

### Step 3: 봇 아키타입 스텁

**Random**:
```gdscript
func choose_action(obs) -> Dictionary:
    return {"move_x": randi_range(-1,1), "jump": randf() < 0.1,
            "shoot": randf() < 0.5, "rewind": randf() < 0.01}
```

**Scripted**: 작성된 `InputLog` 리소스를 프레임별 재생.

**Heuristic**: 룰 캐스케이드 (텔레그래프 → 점프; death-beam 텔레그래프 → 되감기; 기본 → 보스 향해 사격).

**RL**: Stable-Baselines3 PPO + Python ↔ Godot 소켓. 보상 = HP 델타 + 클리어 보너스 − 사망 페널티. 결정론으로 RL 수렴이 동등 확률 환경 대비 ~5–10× 빠름.

## Validation Scenarios

### Scenario A — "이 보스는 공정한가?"
1. Random 봇 × 1000 → 0% 승률 기대.
2. Scripted 봇 × 100 → 100% 기대.
3. Heuristic 봇 × 1000 → 40–60% 기대.

밴드 외 결과 = 특정 결함 매핑:
- Random > 0% → 아레나 익스플로잇, 레이아웃 수정.
- Scripted < 100% → 비결정론 버그.
- Heuristic < 5% → 불공정; > 80% → trivial.

### Scenario B — "어느 페이즈가 학습 곡선을 깨뜨리나?"
RL 봇 × 5000 에피소드; 시도 범위별 사망 분포 binning. 시도 500 이후에도 사망의 >50% 흡수하는 페이즈 = 학습 저항 패턴 — 회피 윈도우가 9프레임보다 좁을 가능성.

### Scenario C — "되감기가 진짜 강제되나?"
되감기 비활성 휴리스틱 봇 실행. P3는 0% 클리어 도달해야 함. P3가 여전히 깨지면 death-sentence 패턴이 정상 회피 가능 = 시간 메카닉 장식 → 디자인 실패.

### Scenario D — "9프레임 윈도우 충분한가?"
9프레임 인공 반응 lag을 가진 휴리스틱 봇. 회피 성공률 ≥ 70% → 윈도우 공정. ≤ 30% → 윈도우 너무 좁음 — 최적 반응자에게도, 인간엔 더더욱 (Source: [[Time Manipulation Run and Gun]]).

## Industry Reference Cases

| 스튜디오 / 게임 | 봇 종류 | 검증 |
|---|---|---|
| **EA FIFA** | RL + 스크립트 | AI 난이도 등급 캘리브레이션 |
| **Riot Games (LoL)** | 휴리스틱 | 챔프 밸런스, 신챔프 검증 |
| **Blizzard Hearthstone** | 스크립트 + RL | 카드 OP 검출 |
| **DeepMind AlphaStar (StarCraft II)** | RL | 그랜드마스터 레벨 에이전트 |
| **OpenAI Five (Dota 2)** | RL | 프로 레벨 성능 |
| **Spelunky 2 (Derek Yu)** | 스크립트 | 시드별 클리어 가능성 검증 |
| **Niantic (Pokemon GO)** | 휴리스틱 | 레이드 보스 난이도 tier |
| **Ubisoft La Forge** | RL + 휴리스틱 | Watch Dogs / AC 밸런스 |

> **솔로 개발자 ROI**: Riot의 휴리스틱 봇 모델 + Spelunky의 스크립트 봇 모델이 Echo 규모에 적합. RL 봇 인프라는 비용 큼; Tier 3로만 이연.

## Echo Bot-Tier Strategy

### Tier 1 (MVP) — 솔로 개발자 가능 범위
- Random 봇 — ~1일.
- Scripted 봇 — 보스당 ~0.5일.
- 단순 휴리스틱 봇 — ~1주.
- Death-by-Phase 메트릭 자동화 — ~3일.

출시 전 보스 게이트로 필수.

### Tier 2 (Polish)
- 9프레임 반응 lag 시뮬 휴리스틱 봇.
- 시도별 학습 곡선 차트.
- 되감기 강제 검증 (시나리오 C).

### Tier 3 (Post-Launch / 사치)
- Stable-Baselines3 + PPO 브릿지 RL 봇.
- RL 결과로부터 자동 밸런싱 패턴 추천 (디자이너 리뷰 게이팅).

## Bot Validation Pitfalls

| 함정 | 대응 |
|---|---|
| **봇은 인간 아님** | 봇 80% 승 ≠ 인간 80% 승. 봇은 *의도* 검증, *느낌* 아님. |
| **결정론 의존** | 미세한 비결정론이 봇 통계 깸 — 봇이 결정론 테스트 역할도 함. |
| **로컬 옵티멈** | 휴리스틱이 한 가지 유효 path 찾는다고 다른 path 작동 증명 X. |
| **메타게임 맹점** | 봇은 좌절·만족·진행 개념 없음. |
| **Reward Hacking (RL)** | RL 봇이 의도치 않은 익스플로잇 (벽 끼임, 무적 글리치) 발견 — 무료 QA 패스. |

## The Bottom Line

> **봇은 결정론 게임의 자동 채점기다.** 디자이너 의도(페이즈 분포, 되감기 강제, 학습 곡선)가 약속대로 실행됨을 증명. 재미는 채점 못 함 — 그건 여전히 인간 일.

## Open Questions

- **[NEW]** 봇 검증을 CI 게이트(보스 merge 차단)로 vs 수동 release 게이트로?
- **[NEW]** Echo MVP 규모에서 Godot ↔ Python RL 브릿지 가치? Post-launch 이연?
- **[NEW]** Echo 경험적 반응 lag 베이스라인 (frames) — 휴리스틱 봇 lag 파라미터 현실적으로 설정?
- **[NEW]** 봇 사망 히트맵을 레벨 튜닝 자동화에 피드 가능? 수동 리뷰만?

## Sources

- DeepMind, AlphaStar (2019).
- OpenAI, "Dota 2 with Large Scale Deep RL" (2019).
- Microsoft, Project Malmo (Minecraft RL platform).
- Riot Games, GDC talks on champion-balance bot testing.
- Stable-Baselines3 documentation (PPO 레퍼런스 구현).
