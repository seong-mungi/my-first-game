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

End-to-end pipeline for using bots to validate deterministic boss design. Three subsystems chain together as a single closed loop:

```
[B] Godot ↔ Python 브릿지 (RL 봇 학습) → JSON metrics
[C] Dashboard + CI Gate                → PASS/FAIL/CONCERNS verdict
[D] GDD Feedback Workflow              → design or code revision
                ↓
        [B] 재학습 (변경 검증)
```

This page captures the full architecture. Subsystem details live in their own pages: [[Heuristic Bot Reaction Lag Simulation]], [[GDD Bot Acceptance Criteria Template]], [[RL Reward Shaping For Deterministic Boss]].

## Subsystem B — Godot ↔ Python RL Bridge

### Five Architectural Decisions

| Decision | Echo choice | Rationale |
|---|---|---|
| Transport | TCP socket + msgpack | Light, language-agnostic, no gRPC overhead |
| Synchronization | Lockstep (Python step → Godot 1 frame) | Determinism preservation absolute for RL |
| Instance model | 1 Godot = 1 env, multi-process parallel | 8 envs = ~8× training throughput |
| Mode | `--headless --no-window` | Renderer-free, ~100× speedup |
| Python stack | Stable-Baselines3 + Gymnasium | PPO baseline, solo-dev friendly |

### Architecture

```
┌─ Python (training process) ─────┐
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
- `Engine.physics_ticks_per_second = 60` enforced
- `Engine.max_physics_steps_per_frame = 1` (no frame skipping)
- All RNG re-seeded in `reset(seed)`
- No `_process` (renderer-coupled) game logic
- No `OS.get_ticks_msec()` — only `Engine.get_physics_frames()`

## Subsystem C — Dashboard + CI Gate

### Output Artifacts

```
production/qa/bots/
├── reports/<date>-<boss>-<build>.html   per-build report
├── reports/<date>-<boss>-<build>.json   machine-readable
├── reports/latest.html                  symlink
├── history/<boss>.csv                   build trend
└── verdicts/<date>-<boss>.md            PR comment payload
```

### Dashboard Sections (HTML one-pager)

1. **Verdict header** — PASS / CONCERNS / FAIL with color
2. **Bot win-rate panel** — Random / Scripted / Heuristic / RL with target bands
3. **Death-by-Phase distribution** — bar chart, must be front-loaded
4. **Time-mechanic validation** — Rewind Usage, Save Rate, Pattern-Without-Rewind
5. **Learning curve (RL)** — HP-at-death over episodes
6. **Build comparison** — current vs previous (regression detector)

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

| Metric | PASS | CONCERNS | FAIL |
|---|---|---|---|
| Random win rate | < 0.5% | 0.5–2% | > 2% |
| Scripted win rate | 100% | 99–100% | < 99% |
| Heuristic win rate | 30–70% | 20–30% / 70–85% | < 20% / > 85% |
| Pattern-w/o-rewind P3 | 0% | 0–5% | > 5% |
| TTFC vs prev build | ±20% | ±20–50% | > 50% |

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

- **CI per-PR**: Random 100 + Scripted 10 + Heuristic 100 ≈ **5–10 min**
- **Nightly**: + Heuristic 1000 + RL 5000 ep ≈ **2 hr**
- **Release gate**: all bosses + Tier 2 metrics ≈ **6–12 hr**

## Subsystem D — Bot Results → GDD Feedback

### Core Principle

> **Bot results are pinned directly into the GDD's Acceptance Criteria section.**
> Design intent is expressed in measurable form; bots grade it.

### GDD AC Section — Bot Row Addition

Echo's 8-section GDD (per CLAUDE.md) gains a `8.2 Bot Validation` subsection. See [[GDD Bot Acceptance Criteria Template]] for the full schema.

### Feedback Loop

```
GDD authoring (designer)
    ↓
Implementation (programmer)
    ↓
Bot suite (CI)
    ↓
Metric vs GDD comparison
    ↓
   ┌───── branch ─────┐
   ↓                  ↓
  PASS            FAIL/CONCERNS — triage:
   ↓                  ① implementation bug → code fix
ship-ready            ② design unrealistic → GDD revision
                      ③ bot defect → bot fix
                          ↓
                      revision → re-validate (loop)
```

### Metric Violation → Decision Matrix

| Bot violation | Likely cause | Fix target |
|---|---|---|
| Random win > 1% | Safe-zone exploit, weak telegraph | Level or pattern |
| Scripted win < 100% | Non-determinism bug | Code |
| Heuristic win < 20% | Pattern too hard / dodge window < 9f | GDD Tuning Knob or pattern |
| Heuristic win > 80% | Pattern too easy / telegraph too long | GDD Tuning Knob |
| Pattern-w/o-rewind clearable | Death-sentence dodgeable conventionally | GDD pattern redesign |
| Death-by-Phase inverted (P4 > P1) | Learning curve broken | Pattern order redesign |
| TTFC > 50 | Entry barrier too high | P1 simplification |

### Designer's Daily Loop

```
AM:
  1. Read overnight RL bot report (production/qa/bots/latest.html)
  2. Triage CONCERNS / FAIL items
  3. Edit GDD or adjust Tuning Knob
PM:
  4. PR change
  5. CI bot suite (5-10 min)
  6. Review → merge
PM (late):
  7. Trigger overnight RL training (5000 ep, ~2 hr)
  8. Report ready next morning
```

### Bot vs Human Validation Split

| Verifiable | Bot | Human |
|---|---|---|
| Boss theoretically clearable | ✅ Scripted | — |
| Dodge window fairness | ✅ Heuristic+lag | ✅ |
| Learning curve shape | ✅ RL | ✅ |
| **Fun / satisfaction** | ❌ | ✅ |
| **Frustration vs challenge balance** | ❌ | ✅ |
| **Visual telegraph clarity** | ❌ | ✅ |
| **Audio cue effectiveness** | ❌ | ✅ |

> **Bots gate; humans grade.** Bots determine *is this design what we said it was*; humans determine *is this design fun*.

## Solo-Developer Priority

### 🟢 Week 1 MVP
1. Random + Scripted bots (~200 LOC)
2. JSON metric output (~50 LOC)
3. Markdown report generator (~100 LOC)
4. GitHub Actions CI gate (~50 LOC YAML)
→ ~1 week, per-boss validation in 5 minutes.

### 🟡 Month 1 Polish
5. Heuristic bot + 9-frame lag simulation ([[Heuristic Bot Reaction Lag Simulation]])
6. HTML dashboard + build comparison
7. GDD AC bot-row standardization ([[GDD Bot Acceptance Criteria Template]])

### 🔴 Tier 3 (Post-MVP)
8. RL bridge + Stable-Baselines3 + reward shaping ([[RL Reward Shaping For Deterministic Boss]])
9. Overnight training automation
10. GDD auto-drift detection from bot reports

## Open Questions

- **[NEW]** Single Python virtualenv or per-project? (RL deps are heavy)
- **[NEW]** Where to host overnight RL training — local workstation idle hours, or one-time cloud spend?
- **[NEW]** Should the bot suite be a submodule, or live in `tools/bots/` inside the main repo?
- **[NEW]** Per-PR full bot suite (slow but safe) vs nightly full / per-PR fast subset?

## The Bottom Line

> **Bots produce data, dashboards produce signals, GDDs produce decisions.**
> Echo's determinism is the asset that makes this loop automatable. The pipeline ships its first useful output (PASS/FAIL on Random + Scripted) in week 1; full RL takes Tier 3.
