---
type: concept
title: RL Reward Shaping For Deterministic Boss
created: 2026-05-10
updated: 2026-05-10
tags:
  - rl
  - reward-shaping
  - bot
  - reinforcement-learning
  - design-pattern
  - echo-applicable
  - python
  - ppo
status: developing
related:
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[Deterministic Game AI Patterns]]"
  - "[[Time Manipulation Run and Gun]]"
---

# RL Reward Shaping For Deterministic Boss

PPO와 같은 정책 그래디언트 알고리즘은 보상 함수가 실제로 보상하는 것을 학습한다 — 디자이너가 의도한 것이 아니라. Echo에서 보상은 인간이 경험하는 것과 동일한 학습 곡선을 유도해야 한다: 생존, 데미지, 패턴 학습, 되감기 올바른 사용, 정체 없음.

이 페이지는 Echo의 RL 플레이테스트 봇 보상 디자인 계약이다. 보상의 모든 버그가 봇이 100k 에피소드 안에 발견할 익스플로잇이 되기 때문에 존재.

## Design Goals (보상이 장려해야 할 것)

| 목표 | 왜 중요 |
|---|---|
| 생존 (피해 안 받음) | 1히트 즉사 코어; 보상은 죽음을 강하게 페널티해야 |
| 보스에 데미지 | 핵심 — 진행 보상 보장 |
| Lethal 위협에 되감기 사용 | 시그니처 메카닉; 무시되면 안 됨 |
| 되감기 낭비 X | 토큰 희소; 남용은 학습 무력화 |
| 페이즈별 패턴 학습 | 봇 곡선이 인간 곡선 미러 |
| 보스 클리어 | 강한 terminal reward |

## Anti-Goals (보상이 장려해선 안 되는 것)

| 안티 목표 | 위험 |
|---|---|
| 시간 보너스 위해 stalling | 봇이 안전지대에 숨어 프레임 생존 보상 누적 |
| 되감기 스팸 | 봇이 매 프레임 "안전" 위해 되감기 |
| 보스 무시 | 봇이 engage 없이 영원히 생존 |
| 죽고 되감기 반복 | 봇이 i-frame을 무료 버프로 익스플로잇 |
| 벽 클리핑 / 글리치 보상 해킹 | 봇이 엔진 버그 발견 |

## Reward Function (Echo Default)

```python
def compute_reward(prev_state, curr_state):
    r = 0.0

    # === Damage: dense positive, 큰 가중치 ===
    boss_hp_delta = prev_state.boss_hp - curr_state.boss_hp
    r += boss_hp_delta * 10.0   # 공격 장려

    # === Death: sparse, 매우 큰 negative ===
    if curr_state.player_died_this_frame:
        r -= 100.0

    # === Clear: sparse, 매우 큰 positive ===
    if curr_state.boss_hp == 0 and not prev_state.cleared:
        r += 500.0

    # === Phase progression: 셰이프된 milestone ===
    if curr_state.phase > prev_state.phase:
        r += 50.0   # 학습 곡선 진행 장려

    # === 되감기 사용 셰이핑 ===
    if curr_state.rewind_consumed_this_frame:
        if prev_state.lethal_threat_imminent:
            r += 5.0   # 올바른 사용
        else:
            r -= 2.0   # 낭비

    # === Anti-stall: 시간만으로 보상 X ===
    # NOT: r += 0.01  ← 제거. 버그 자석.

    # === 약한 engagement 보너스: 활발히 데미지 줄 때만 ===
    if boss_hp_delta > 0:
        r += 0.1   # 동률 시 공격 우선의 작은 tick

    return r
```

## Why These Numbers (Calibration Logic)

| 컴포넌트 | 크기 | 근거 |
|---|---|---|
| `boss_hp_delta * 10` | 최대 ~100/프레임 | 클리어 보너스와 같은 자릿수 — 클리어 = 데미지 보상 합 ≈ 500 |
| 사망당 `−100` | -100 | 강하지만 무한 X; 봇 탐색 가능. 클리어 +500과 함께, 시도 EV > 0은 win rate > 17% 일 때만 |
| 클리어 `+500` | +500 | 강한 terminal pull; 모든 dense 보상 압도 |
| 페이즈당 `+50` | +50 | 커리큘럼 신호 — 페이즈는 추구할 가치 있는 서브골 |
| 되감기 `+5 / −2` | 작음 | 행동 셰이핑하나 지배 X |
| 프레임 생존 | 0 | **결정적**: positive 값은 stalling 보상 |

## Curriculum (Phase-Gated Training)

인간 학습 순서를 미러하기 위해 단계별 학습:

```python
# Stage 1: P1 only (봇이 기본 회피 학습)
env = EchoEnv(boss="meaeokkun", phase_lock="P1", episodes=2000)
model = PPO("MlpPolicy", env).learn(2_000_000)

# Stage 2: P1 + P2 (봇이 어려운 패턴에 회피 적응)
env = EchoEnv(boss="meaeokkun", phase_lock="P1-P2", episodes=2000)
model.set_env(env).learn(2_000_000)

# Stage 3: P1 + P2 + P3 (봇이 death-sentence 위해 되감기 학습)
env = EchoEnv(boss="meaeokkun", phase_lock="P1-P3", episodes=2000)
model.set_env(env).learn(3_000_000)

# Stage 4: 풀 보스
env = EchoEnv(boss="meaeokkun", phase_lock=None, episodes=5000)
model.set_env(env).learn(5_000_000)
```

각 단계는 이전 단계의 weight에서 warm-start. 이거 없으면 naive PPO는 종종 P3에서 되감기 발견 실패 — 인간 플레이어가 직면하는 동일 문제, 봇은 내러티브 큐 없음.

## Reward Hacking Watchlist (Echo-Specific)

| 익스플로잇 패턴 | 메트릭 증상 | 대응 |
|---|---|---|
| 안전지대에서 stall | TTFC 상승, 평균 에피소드 길이 폭발 | 에피소드 길이 캡 (~30s); 보스 데미지 5초간 없으면 −0.01 idle 페널티 |
| 되감기 스팸 | 에피소드당 되감기 사용 > 예상 N회 | `lethal_threat_imminent` 사전 없이 되감기 소비 시 페널티 |
| 죽고 → 되감고 → 다시 죽기 | 학습 후 사망률 동일 | 연속 사망 추적; 초당 1회로 캡 |
| 봇이 벽 클리핑 | 갑자기 win rate 100% + 이상한 궤적 | 수동 리플레이 리뷰; 엔진 버그 수정 |
| 되감기 후 i-frame 남용 | 텔레그래프 완전 무시 | 되감기 보상을 +1로 감소; i-frame 접촉 절대 보상 X |

## `lethal_threat_imminent` Flag (Designer-Authored)

되감기를 올바르게 보상하려면, env가 되감기가 *올바른* 응답인 시점을 신호해야 함. 이건 디자이너 작성 신호, RL 학습 X:

```gdscript
# 보스 FSM 안
func _physics_process(_dt):
    self.lethal_threat_imminent = (
        self.state == "telegraph_death_beam" and
        self.attack_phase_t > 0.7 and
        player_in_lethal_path()
    )
```

이게 RL에 보스 FSM이 중요한 이유 — 디자이너 큐레이션 위협 신호 없이는 보상 셰이핑이 "좋은 되감기"를 "패닉 되감기"와 구분 불가.

## Hyperparameter Defaults (Stable-Baselines3 PPO)

```python
PPO(
    "MlpPolicy",
    env,
    learning_rate=3e-4,
    n_steps=2048,
    batch_size=256,
    n_epochs=10,
    gamma=0.99,        # discount — 클리어 가치 두기에 충분히 높음
    gae_lambda=0.95,
    clip_range=0.2,
    ent_coef=0.01,     # 약한 탐색; 봇 underexplore 시 0.05로 상승
    vf_coef=0.5,
    max_grad_norm=0.5,
    seed=42,           # 결정론
)
```

Echo의 관찰 크기 (~64 floats) + 액션 공간 (`MultiDiscrete[3,2,2,2]`)에서, PPO는 커리큘럼 풀 보스에 ~10M timesteps 수렴 (~6시간 single-GPU laptop, ~2시간 8-env 병렬).

## Sparse vs Dense Trade-Off

Echo는 의도적으로 *둘 다* 사용:
- **Dense**: damage delta, 되감기 사용 셰이핑
- **Sparse**: death penalty, clear bonus, phase progression

순수 sparse (death/clear만) = 10–100× 더 많은 에피소드 필요 — 솔로 개발자 규모에선 비현실. 순수 dense (프레임 단위 셰이핑 다수) = 익스플로잇 가능. 위 mixed 스케줄이 경험적 sweet spot.

## Validation: 보상이 디자인 의도와 일치하나?

학습 후, 봇 행동을 디자인 클레임 대비 감사:

```python
# 에피소드별 통계 로깅; GDD 클레임과 일치 검증
metrics = {
    "avg_rewinds_per_clear": ...,
    "avg_damage_dealt_per_episode": ...,
    "phase_completion_rates": ...,
    "death_distribution_by_phase": ...,
}
```

`avg_rewinds_per_clear` < 1 → RL 봇이 되감기 메카닉 완전 우회; 보상 mis-shaped. threat-imminent 신호 수정 또는 되감기 보상 상승.

`death_distribution_by_phase` 균등 → 페이즈 보상 너무 작아 미분화; 페이즈당 `+50` 상승.

`avg_episode_length` 계속 증가 → stall 익스플로잇; anti-stall 강화.

## When NOT to Use RL

Echo MVP / Tier 1 규모에선 RL은 **과잉**. 사용:
- floor/ceiling엔 Random + Scripted 봇.
- 공정성엔 Heuristic+lag 봇 ([[Heuristic Bot Reaction Lag Simulation]]).

RL은 다음 시 가치 있음:
- 휴리스틱 봇 룰이 다루기 어려워짐 (>500 LOC `if/else`).
- "N회 안에 학습 가능?" 검증 필요.
- 휴리스틱이 놓친 의도치 않은 익스플로잇 발견 필요.

확실히 Tier 3 영역.

## Open Questions

- **[NEW]** 보상 셰이핑이 보스 GDD 옆에 살아야 하나, `tools/bots/rewards/<boss>.py`? (디자이너 접근 vs 코드 co-location.)
- **[NEW]** 솔로 규모에서 커리큘럼 학습이 오케스트레이션 비용 가치 있나, 풀 보스 처음부터 더 긴 학습 시간으로 수용 가능?
- **[NEW]** 어떤 메트릭이 보상 해킹을 자동 플래그? (수동 리플레이 리뷰 전 캐치)
- **[NEW]** death-sentence threat-imminent 플래그가 public 보스 API에 노출 vs 내부 RL hook only?

## Related

- [[AI Playtest Bot For Boss Validation]] — 부모 컨텍스트
- [[Bot Validation Pipeline Architecture]] — 어디 slot-in
- [[Heuristic Bot Reaction Lag Simulation]] — RL 과잉 시 Tier 2 대안
- [[Deterministic Game AI Patterns]] — Zone ③ (offline tools)에 RL 배치
