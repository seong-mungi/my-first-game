---
type: concept
title: Determinism Verification Replay Diff
created: 2026-05-10
updated: 2026-05-10
tags:
  - determinism
  - validation
  - replay
  - ci
  - tooling
  - godot
  - design-pattern
  - echo-applicable
status: developing
related:
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[Deterministic Game AI Patterns]]"
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[Time Manipulation Run and Gun]]"
---

# Determinism Verification Replay Diff

Echo의 봇 검증, 시간 되감기 정확성, 경쟁력 무결성 모두 단일 속성에 의존한다: 같은 입력 → 같은 상태, 매 프레임 매 실행 매 머신에서. 이 속성은 깨지기 쉽다 — 시드 안 박은 `randf()` 하나, `_process` 순서 셔플 하나, 플랫폼 float 차이 하나면 속성이 보이지 않게 깨진다.

Replay Diff 패턴은 결정론 유지를 증명하는 CI 실행 가능 테스트다. 입력과 프레임별 상태 해시를 기록하고, 재생 시 같은 해시 스트림이 나와야 한다. 첫 발산 프레임이 버그 위치다.

## Why Determinism Verification Must Be Automated

결정론 실패는 **무음**이다: 게임은 여전히 동작하고, 플레이되고, 출시된다. 결함은 추후 다음으로 표면화:
- RL 봇이 수렴 못 함 (학습 드리프트)
- 봇 CI 게이트가 일관되지 않은 verdict
- 시간 되감기가 잘못된 상태로 복원 ([[Time Manipulation Run and Gun]])
- Speedrun 커뮤니티가 월드 레코드 재현 못 함
- 패치 간 리플레이 공유 기능이 깨짐

인간이 알아챌 즈음엔 회귀가 수 주 깊이.

## Architecture

```
┌─ Recording phase ──────────────────┐
│  Input log:    Array[InputFrame]   │
│  State hashes: Array[u64]          │ 표준 상태의 프레임별 FNV-1a
│  Seed:         u64                 │ 초기 RNG seed
└────────────────────────────────────┘
                ↓ .replay 파일에 저장
┌─ Replay phase ─────────────────────┐
│  RNG 재시드 → 같은 seed             │
│  매 프레임 InputFrame[i] 적용       │
│  상태 해시 후 기록값과 비교          │
│  첫 불일치에서 실패                 │
└────────────────────────────────────┘
```

## Replay File Format

```yaml
# .replay (binary 또는 msgpack — 명료성 위해 YAML로 표시)
version: 1
build_hash: "a1b2c3d4"           # 소스 리비전
godot_version: "4.6.stable"
platform: "linux-x86_64"
seed: 42
input_log:
  - frame: 0
    move_x: 0
    jump: false
    shoot: false
    rewind: false
  - frame: 1
    move_x: 1
    jump: false
    shoot: true
    rewind: false
  # ... (초당 60 entries)
state_hashes:
  - 0xa3f2e8b1c4d56091
  - 0xb4c5d6e7f8901234
  # 프레임당 1개
total_frames: 7200    # 60fps × 2분
```

## Canonical State Hashing

해시 입력 (반드시 망라적이어야 함):

```gdscript
func _compute_canonical_state_hash() -> int:
    var h := FNV_1A_64_OFFSET
    h = _hash_player(h, player)
    h = _hash_boss(h, boss)
    for projectile in get_tree().get_nodes_in_group("projectiles"):
        h = _hash_projectile(h, projectile)
    for snapshot in time_rewind.snapshots:
        h = _hash_snapshot(h, snapshot)
    return h

func _hash_player(h: int, p: Player) -> int:
    h = _fnv_mix(h, p.position.x)
    h = _fnv_mix(h, p.position.y)
    h = _fnv_mix(h, p.velocity.x)
    h = _fnv_mix(h, p.velocity.y)
    h = _fnv_mix(h, p.facing_direction)
    h = _fnv_mix(h, p.hp)
    h = _fnv_mix(h, p.rewind_tokens)
    h = _fnv_mix(h, hash(p.state_machine.current_state))
    h = _fnv_mix(h, p.animation_player.current_animation_position * 1000.0)
    return h
```

> **결정적**: 해시 함수는 반드시 **표준 순서(canonical order)**로 상태를 방문해야 함. Godot `Dictionary` 순회는 **버전 간 비결정론적**. 항상 키를 정렬하거나 해시 가능 순회용 `Array`를 사용.

## Float Determinism Pitfalls

크로스 플랫폼 float 연산은 기본적으로 **bit-identical 아님**. 한 플랫폼 안에서도 float 연산 순서가 드리프트할 수 있음.

대응책:
- 해싱 전 **양자화(Quantize)**: `_fnv_mix(h, int(value * 1000.0))` — milli 단위 반올림. 우발적 1-bit float 드리프트가 diff를 깨는 걸 막으면서 진짜 발산은 잡음.
- 결정론 critical path에서 가능하면 trig 함수 **회피** (또는 fixed-point 구현 vendoring).
- 물리 적분 step **고정** (`Engine.physics_ticks_per_second = 60`).
- `Engine.max_physics_steps_per_frame > 1` **비활성화** — frame skipping은 결정론 깸.

## Godot 4.6 Known Determinism Footguns

| Footgun | 수정 |
|---|---|
| 시드 안 박은 `randf()` / `randi()` | 시스템마다 명시 `RandomNumberGenerator` 생성; `reset()`에서 시드 |
| 게임 로직에 `OS.get_ticks_msec()` | `Engine.get_physics_frames()` 만 사용 |
| 게임 로직에 `_process(delta)` | `_physics_process(delta)`로 이동; 물리 tick은 고정 |
| `Dictionary` 순회 순서 | 키 정렬 또는 표준 순회용 `Array` 사용 |
| `connect()` 호출 간 시그널 발행 순서 | 순서 의존 시그널 로직 회피; 또는 `connect(..., CONNECT_DEFERRED)`를 일관되게 사용 |
| `Node._ready()` 순서 | 노드 간 init 순서 의존 X; 명시 deps 사용 |
| 물리 적분기 (Jolt vs Godot Physics) | `project.godot`에 고정; ADR로 문서화 |
| `Time.get_unix_time_from_system()` | 게임 로직에서 금지 |
| 게임 상태 만지는 스레드 코드 | 결정론 path에서 금지; 로더만 스레드 가능 |
| Shader 출력 (시각만 — OK; 로직 — 금지) | 게임플레이용으로 shader 픽셀 읽기 절대 X |

## CI Determinism Gate

```yaml
# .github/workflows/determinism-gate.yml
name: Determinism Gate
on: [pull_request]
jobs:
  determinism:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./install_godot_4_6_headless.sh
      - run: |
          # 100 random seeds × 2 runs each
          for seed in $(seq 1 100); do
            python tools/replay_diff.py --seed=$seed --boss=meaeokkun \
                                       --frames=3600 || exit 1
          done
      - run: echo "All 100 seeds reproduced bit-identical"
```

`replay_diff.py`:

```python
def verify_determinism(seed: int, boss: str, frames: int) -> bool:
    # Run 1: 기록
    run1 = subprocess.run([
        "./godot", "--headless", "--bot=heuristic_lag9",
        "--seed", str(seed), "--boss", boss, "--frames", str(frames),
        "--record-replay", "/tmp/run1.replay"
    ])
    # Run 2: 같은 조건 기록
    run2 = subprocess.run([
        "./godot", "--headless", "--bot=heuristic_lag9",
        "--seed", str(seed), "--boss", boss, "--frames", str(frames),
        "--record-replay", "/tmp/run2.replay"
    ])
    # Diff
    r1 = parse_replay("/tmp/run1.replay")
    r2 = parse_replay("/tmp/run2.replay")
    for frame, (h1, h2) in enumerate(zip(r1.hashes, r2.hashes)):
        if h1 != h2:
            print(f"DIVERGENCE at frame {frame}: {h1:x} vs {h2:x}")
            return False
    return True
```

## Bisect Tool — Locate Source of Divergence

CI가 발산을 플래그 시 자동 bisect:

```python
def bisect_divergence(replay1: Replay, replay2: Replay) -> int:
    lo, hi = 0, len(replay1.hashes)
    while lo < hi:
        mid = (lo + hi) // 2
        if replay1.hashes[mid] == replay2.hashes[mid]:
            lo = mid + 1
        else:
            hi = mid
    return lo  # 첫 발산 프레임
```

이후 `divergence - 1` (마지막 정상)과 `divergence` (첫 비정상) 프레임의 전체 상태를 dump:

```
$ python tools/state_diff.py --replay1=run1.replay --replay2=run2.replay --frame=247
DIVERGENT at frame 247:
  player.position.x:  120.5      → 120.5
  player.position.y:  -64.0      → -64.0
  player.velocity.y:  3.21       → 3.22       ← DIFF
  ...
HYPOTHESIS: 물리 적분기 step 비일관성
```

## Replay Recording Hooks (Godot Side)

```gdscript
# Autoload: ReplayRecorder.gd
extends Node

var _input_log: Array = []
var _state_hashes: Array = []
var _is_recording := false
var _is_replaying := false
var _replay_input: Array = []

func start_recording(seed: int) -> void:
    _is_recording = true
    seed_all_rng(seed)

func _physics_process(_dt: float) -> void:
    if _is_recording:
        var input := _capture_input()
        _input_log.append(input)
        _state_hashes.append(_compute_state_hash())
    elif _is_replaying:
        var frame := Engine.get_physics_frames()
        if frame < _replay_input.size():
            _apply_replay_input(_replay_input[frame])

func save_replay(path: String) -> void:
    var data := {
        "version": 1,
        "seed": _seed,
        "input_log": _input_log,
        "state_hashes": _state_hashes,
    }
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_var(data)
```

## Determinism Test Suite

PR당 CI 게이트 너머로, 플랫폼/크로스 버전 회귀를 잡는 정기 스위트:

| 테스트 | 빈도 | 무엇을 잡나 |
|---|---|---|
| PR 별 replay diff (100 seed × 2 run) | 매 PR | 로컬 비결정론 |
| Cross-platform (Linux + macOS + Windows) | 나이트리 | 플랫폼 float 드리프트 |
| Cross-Godot-version (current + RC) | Godot 업데이트 전 | 엔진 회귀 |
| Long-run soak (10분 × 100 seed) | 주간 | 슬로우 리크 float 드리프트 |
| Time-rewind torture (5프레임마다 되감기 × 1시간) | 주간 | 스냅샷/복원 정확성 |

## Time-Rewind Torture (Echo Signature)

Echo의 시간 되감기는 결정론을 두 배로 중요하게 만든다: 라이브 타임라인뿐 아니라 스냅샷/복원 path가 기록 상태를 bit-identical 재현해야 함.

```python
def torture_time_rewind(seed: int, frames: int) -> bool:
    """
    5프레임마다 되감기 트리거하며 보스 실행.
    각 되감기 후 상태 해시를 스냅샷의 사전 기록 해시와 일치하는지 검증.
    """
    # ...
```

torture는 통과했는데 일반 replay diff가 실패하면 — 버그는 코어 게임플레이.
torture는 실패했는데 replay diff는 통과하면 — 버그는 스냅샷/복원 path.

## What This Catches (and What It Doesn't)

잡는 것:
- 게임 로직 어디든 시드 안 박은 RNG
- 순서 의존 dictionary 순회
- 실행/플랫폼/버전 간 float 드리프트
- 게임 상태 만지는 스레드 코드
- 크로스 버전 Godot 엔진 회귀
- 시간 되감기 상태 복원 버그

잡지 않는 것:
- 매 실행 동일한 결과를 내는 로직 오류 (결정론적 버그)
- 시각/오디오 글리치 (상태 해시 없음)
- 성능 회귀 (프레임 타이밍만)
- 메모리 누수 (상태 해시는 할당 사이즈 미포함)

## Echo Determinism Mandate

```yaml
echo_determinism:
  ci_gate: blocking          # 결정론 실패 시 PR merge 불가
  test_runs_per_pr: 100      # 100 seed, 각 2 run 검증
  cross_platform_nightly: true
  cross_version_pre_update: true
  time_rewind_torture_weekly: true
```

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| 플레이어 상태만 해싱 | projectile / boss / snapshot 드리프트 누락 |
| 시각 전용 상태에서 해시 스킵 | 시간 되감기엔 애니메이션 재생 시점이 중요 |
| CI 결정론 "가끔 실패" 허용 | 결정론 실패는 binary; flaky = 진짜 버그 |
| 버그 발생 시 결정론 테스트 비활성화 | 테스트가 계약; 버그 수정 (음소거 X) |
| 양자화 없이 전체 float bit 해시 | 1-bit 드리프트로 false positive 발생 |
| 너무 거칠게 양자화하여 진짜 버그 가림 | 1ms 양자화가 Echo 적정점 |

## Open Questions

- **[NEW]** Echo의 양자화 단위 — 1 ms? 1 millipixel? 양쪽?
- **[NEW]** `.replay` 파일을 빌드와 함께 출시하여 커뮤니티 speedrun 검증?
- **[NEW]** PR 당 100 seed × 2 run 비용이 지속 가능? CI는 25 seed / 나이트리는 100 seed?
- **[NEW]** 크로스 플랫폼 CI 비싸 — PR은 Linux only, 나이트리는 풀 트리플?
- **[NEW]** Godot 패치가 결정론 깰 때, 옛 버전 핀? 리플레이 마이그레이트?

## Related

- [[Bot Validation Pipeline Architecture]] — replay diff는 봇 검증 아래 기반
- [[Time Manipulation Run and Gun]] — Echo 되감기는 결정론 가장 민감 피처
- [[Deterministic Game AI Patterns]] — 광범위한 결정론 철학
