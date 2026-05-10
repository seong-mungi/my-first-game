---
type: synthesis
title: "Bot Validation Pipeline Architecture"
created: 2026-05-10
updated: 2026-05-10
tags:
  - architecture
  - tooling
  - ci
  - rl
  - playtest
  - godot
  - python
  - dashboard
  - gdd-workflow
  - echo-applicable
status: developing
question: "결정론 게임에서 봇 검증 파이프라인을 어떻게 설계하는가? (Godot ↔ Python 브릿지 + 메트릭 대시보드 + GDD 피드백 루프)"
answer_quality: solid
related:
  - "[[Deterministic Game AI Patterns]]"
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[GDD Bot Acceptance Criteria Template]]"
  - "[[RL Reward Shaping For Deterministic Boss]]"
  - "[[Boss Two Phase Design]]"
  - "[[Solo Contra 2026 Concept]]"
sources: []
---

# Bot Validation Pipeline Architecture

결정론 보스 디자인 검증을 위한 봇 사용의 엔드-투-엔드 파이프라인. 세 서브시스템이 단일 폐쇄 루프로 체이닝:

```
[B] Godot ↔ Python 브릿지 (RL 봇 학습) → JSON metrics
[C] Dashboard + CI Gate                → PASS/FAIL/CONCERNS verdict
[D] GDD Feedback Workflow              → 디자인 또는 코드 수정
                ↓
        [B] 재학습 (변경 검증)
```

이 페이지는 풀 아키텍처를 캡처. 서브시스템 디테일은 각자 페이지에 거주: [[Heuristic Bot Reaction Lag Simulation]], [[GDD Bot Acceptance Criteria Template]], [[RL Reward Shaping For Deterministic Boss]].

## Subsystem B — Godot ↔ Python RL Bridge

### Five Architectural Decisions

| 결정 | Echo 선택 | 이유 |
|---|---|---|
| 전송 | TCP socket + msgpack | 가벼움, 언어 독립, gRPC 오버헤드 회피 |
| 동기화 | Lockstep (Python step → Godot 1 frame) | RL에선 결정론 보존이 절대 |
| 인스턴스 모델 | 1 Godot = 1 env, 다중 프로세스 병렬 | 8 envs = ~8× 학습 처리량 |
| 모드 | `--headless --no-window` | 렌더 비용 0, ~100× 가속 |
| Python 스택 | Stable-Baselines3 + Gymnasium | PPO 베이스라인, 솔로 개발자 친화 |

### Architecture

```
┌─ Python (학습 프로세스) ─────────┐
│  Stable-Baselines3 PPO          │
│      ↓                          │
│  EchoGymEnv (Gymnasium)         │
│      ├─ reset(seed) → obs       │
│      └─ step(action) → obs,r,d  │
│              ↓ msgpack          │
└──────────────┬──────────────────┘
               │ TCP :5555-5562 (8 envs)
┌──────────────┴──────────────────┐
│  Godot 4.6 --headless           │
│  └─ EchoBotServer (autoload)    │
│      ├─ accept(action_msg)      │
│      ├─ advance_one_frame()     │
│      ├─ collect_observation()   │
│      └─ send(obs_msg)           │
└─────────────────────────────────┘
```

### Godot Server (key sketch)

```gdscript
# autoload: EchoBotServer.gd
extends Node

const PORT_BASE := 5555
var _server: TCPServer
var _client: StreamPeerTCP

func _physics_process(_dt: float) -> void:
    if _client == null: return
    _client.poll()
    if _client.get_available_bytes() < 4:
        get_tree().paused = true
        return
    get_tree().paused = false
    var action := _read_msgpack()
    _apply_action(action)
    _send_msgpack(_collect_observation())

func _collect_observation() -> Dictionary:
    return {
        "player_pos": [player.position.x, player.position.y],
        "player_vel": [player.velocity.x, player.velocity.y],
        "boss_state": boss.state_name,
        "boss_pattern_id": boss.current_pattern_id,
        "boss_phase_t": boss.attack_phase_t,
        "projectiles": _serialize_projectiles(),
        "hp": player.hp,
        "rewind_tokens": player.rewind_tokens,
        "frame": Engine.get_physics_frames(),
        "done": player.hp == 0 or boss.hp == 0,
        "reward": _compute_reward()
    }
```

### Python Client (key sketch)

```python
import gymnasium as gym, msgpack, socket, numpy as np

class EchoEnv(gym.Env):
    def __init__(self, port=5555, godot_path="godot"):
        self.observation_space = gym.spaces.Box(-1e4, 1e4, (64,), np.float32)
        self.action_space = gym.spaces.MultiDiscrete([3, 2, 2, 2])
        self._launch_godot(port, godot_path)
        self._connect(port)

    def step(self, action):
        msg = msgpack.packb({"cmd": "step", "action": action.tolist()})
        self.sock.sendall(len(msg).to_bytes(4, "big") + msg)
        obs = self._recv_obs_raw()
        return self._flatten(obs), obs["reward"], obs["done"], False, {"frame": obs["frame"]}
```

### Determinism Preservation Rules
- `Engine.physics_ticks_per_second = 60` 강제
- `Engine.max_physics_steps_per_frame = 1` (frame skipping 금지)
- 모든 RNG는 `reset(seed)`에서 재시드
- `_process` (렌더 결합) 게임 로직 X
- `OS.get_ticks_msec()` X — `Engine.get_physics_frames()` 만

## Subsystem C — Dashboard + CI Gate

### Output Artifacts

```
production/qa/bots/
├── reports/<date>-<boss>-<build>.html   빌드별 리포트
├── reports/<date>-<boss>-<build>.json   머신 리더블
├── reports/latest.html                  심볼릭 링크
├── history/<boss>.csv                   빌드 트렌드
└── verdicts/<date>-<boss>.md            PR 코멘트 페이로드
```

### Dashboard Sections (HTML one-pager)

1. **Verdict 헤더** — PASS / CONCERNS / FAIL 컬러
2. **봇 win-rate 패널** — Random / Scripted / Heuristic / RL + 목표 밴드
3. **Death-by-Phase 분포** — 막대 차트, 전반부 집중 형태
4. **시간 메커닉 검증** — Rewind Usage, Save Rate, Pattern-Without-Rewind
5. **학습 곡선 (RL)** — 에피소드 동안 HP-at-death
6. **빌드 비교** — 현재 vs 이전 (회귀 검출기)

### Verdict Computation

```python
def compute_verdict(m):
    if m["random_win_rate"] > 0.01: return "FAIL: Random bot exploit"
    if m["scripted_win_rate"] < 1.0: return "FAIL: Non-determinism"
    if not (0.3 <= m["heuristic_win_rate"] <= 0.7):
        return "CONCERNS: Heuristic out of band"
    if m["pattern_no_rewind_p3"] > 0:
        return "FAIL: Rewind not enforced on P3"
    return "PASS"
```

### CI Gate Thresholds (Echo defaults)

| 메트릭 | PASS | CONCERNS | FAIL |
|---|---|---|---|
| Random win rate | < 0.5% | 0.5–2% | > 2% |
| Scripted win rate | 100% | 99–100% | < 99% |
| Heuristic win rate | 30–70% | 20–30% / 70–85% | < 20% / > 85% |
| Pattern-w/o-rewind P3 | 0% | 0–5% | > 5% |
| 이전 빌드 대비 TTFC | ±20% | ±20–50% | > 50% |

### CI Workflow (GitHub Actions sketch)

```yaml
name: Bot Validation Gate
on: [pull_request]
jobs:
  bot-validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./install_godot_4_6_headless.sh
      - run: ./godot --headless --bot-server &
        timeout-minutes: 15
      - run: python tools/run_bot_suite.py --boss=all --tier=ci
      - run: python tools/bot_report.py production/qa/bots/latest.json
      - uses: marocchino/sticky-pull-request-comment@v2
        with: { path: production/qa/bots/verdict.md }
      - run: grep -q "VERDICT: FAIL" production/qa/bots/verdict.md && exit 1 || true
```

### Time Budgets

- **PR당 CI**: Random 100 + Scripted 10 + Heuristic 100 ≈ **5–10분**
- **나이트리**: + Heuristic 1000 + RL 5000 에피소드 ≈ **2시간**
- **릴리즈 게이트**: 모든 보스 + Tier 2 메트릭 ≈ **6–12시간**

## Subsystem D — Bot Results → GDD Feedback

### Core Principle

> **봇 결과는 GDD의 Acceptance Criteria 섹션에 직접 핀.**
> 디자인 의도가 측정 가능 형태로 표현되고, 봇이 그것을 채점.

### GDD AC Section — Bot Row Addition

Echo의 8 섹션 GDD (CLAUDE.md 기반)에 `8.2 Bot Validation` 서브섹션 추가. 풀 스키마는 [[GDD Bot Acceptance Criteria Template]] 참조.

### Feedback Loop

```
GDD 작성 (디자이너)
    ↓
구현 (프로그래머)
    ↓
봇 스위트 (CI)
    ↓
메트릭 vs GDD 비교
    ↓
   ┌───── 분기 ─────┐
   ↓                ↓
  PASS          FAIL/CONCERNS — triage:
   ↓                ① 구현 버그 → 코드 수정
ship-ready          ② 디자인 비현실 → GDD 수정
                    ③ 봇 결함 → 봇 수정
                       ↓
                    수정 → 재검증 (loop)
```

### Metric Violation → Decision Matrix

| 봇 위반 | 가능한 원인 | 수정 타깃 |
|---|---|---|
| Random win > 1% | 안전지대 익스플로잇, 약한 텔레그래프 | 레벨 또는 패턴 |
| Scripted win < 100% | 비결정론 버그 | 코드 |
| Heuristic win < 20% | 패턴 너무 어려움 / 회피 윈도우 < 9f | GDD Tuning Knob 또는 패턴 |
| Heuristic win > 80% | 패턴 너무 쉬움 / 텔레그래프 너무 김 | GDD Tuning Knob |
| Pattern-w/o-rewind 클리어 가능 | death-sentence 정상 회피 가능 | GDD 패턴 재설계 |
| Death-by-Phase 역분포 (P4 > P1) | 학습 곡선 깨짐 | 패턴 순서 재설계 |
| TTFC > 50 | 진입 장벽 너무 높음 | P1 단순화 |

### Designer's Daily Loop

```
오전:
  1. 야간 RL 봇 리포트 확인 (production/qa/bots/latest.html)
  2. CONCERNS / FAIL 항목 triage
  3. GDD 수정 또는 Tuning Knob 조정
오후:
  4. 변경 PR
  5. CI 봇 스위트 (5-10분)
  6. 리뷰 → merge
저녁:
  7. 야간 RL 학습 트리거 (5000 에피소드, ~2시간)
  8. 다음 날 오전 리포트 준비
```

### Bot vs Human Validation Split

| 검증 가능 | 봇 | 인간 |
|---|---|---|
| 보스 이론상 클리어 가능 | ✅ Scripted | — |
| 회피 윈도우 공정성 | ✅ Heuristic+lag | ✅ |
| 학습 곡선 형태 | ✅ RL | ✅ |
| **재미 / 만족도** | ❌ | ✅ |
| **좌절 vs 도전 균형** | ❌ | ✅ |
| **시각 텔레그래프 명료성** | ❌ | ✅ |
| **오디오 큐 효과** | ❌ | ✅ |

> **봇은 게이트, 인간은 등급.** 봇은 *디자인이 우리가 말한 그것인가*를 결정; 인간은 *디자인이 재미있는가*를 결정.

## Solo-Developer Priority

### 🟢 Week 1 MVP
1. Random + Scripted 봇 (~200 LOC)
2. JSON 메트릭 출력 (~50 LOC)
3. Markdown 리포트 생성기 (~100 LOC)
4. GitHub Actions CI 게이트 (~50 LOC YAML)
→ ~1주, 보스당 검증 5분.

### 🟡 Month 1 Polish
5. 9프레임 lag 시뮬 휴리스틱 봇 ([[Heuristic Bot Reaction Lag Simulation]])
6. HTML 대시보드 + 빌드 비교
7. GDD AC 봇-행 표준화 ([[GDD Bot Acceptance Criteria Template]])

### 🔴 Tier 3 (Post-MVP)
8. RL 브릿지 + Stable-Baselines3 + 보상 셰이핑 ([[RL Reward Shaping For Deterministic Boss]])
9. 야간 학습 자동화
10. 봇 리포트로부터 GDD 자동 드리프트 검출

## Open Questions

- **[NEW]** 단일 Python virtualenv vs 프로젝트별? (RL deps 무거움)
- **[NEW]** 야간 RL 학습 호스팅 — 로컬 워크스테이션 유휴 시간 vs 일회성 클라우드?
- **[NEW]** 봇 스위트 — submodule? 메인 repo `tools/bots/` 안?
- **[NEW]** PR당 풀 봇 스위트 (느리지만 안전) vs 나이트리 풀 / PR당 빠른 서브셋?

## The Bottom Line

> **봇은 데이터를, 대시보드는 신호를, GDD는 결정을 생산한다.**
> Echo 결정론은 이 루프를 자동화 가능하게 만드는 자산. 파이프라인 첫 유용 출력 (Random + Scripted PASS/FAIL)은 1주차에; 풀 RL은 Tier 3.
