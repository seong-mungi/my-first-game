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

Echo's bot validation, time-rewind correctness, and competitive integrity all depend on a single property: same input produces same state, every frame, every run, every machine. This property is fragile — one unseeded `randf()`, one `_process` ordering shuffle, one platform float discrepancy and the property breaks invisibly.

The Replay Diff pattern is a CI-runnable test that proves determinism holds. It records inputs and per-frame state hashes; replay must produce the same hash stream. First divergence frame is the bug location.

## Why Determinism Verification Must Be Automated

Determinism failures are **silent**: the game still runs, plays, and ships. The defect surfaces later as:
- RL bot fails to converge (training drifts)
- Bot CI gate gives inconsistent verdicts
- Time-rewind restores to wrong state ([[Time Manipulation Run and Gun]])
- Speedrun community can't reproduce world records
- Replay-share feature breaks across patches

By the time a human notices, the regression is weeks deep.

## Architecture

```
┌─ Recording phase ──────────────────┐
│  Input log:    Array[InputFrame]   │
│  State hashes: Array[u64]          │ per-frame FNV-1a of canonical state
│  Seed:         u64                 │ initial RNG seed
└────────────────────────────────────┘
                ↓ saved to .replay file
┌─ Replay phase ─────────────────────┐
│  Re-seed RNG → same seed           │
│  Apply InputFrame[i] each frame    │
│  Hash state, compare to recorded   │
│  Fail at first mismatch            │
└────────────────────────────────────┘
```

## Replay File Format

```yaml
# .replay (binary or msgpack — example shown as YAML for clarity)
version: 1
build_hash: "a1b2c3d4"           # source revision
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
  # ... (60 entries per second)
state_hashes:
  - 0xa3f2e8b1c4d56091
  - 0xb4c5d6e7f8901234
  # one per frame
total_frames: 7200    # 2 minutes @ 60 fps
```

## Canonical State Hashing

Hash inputs (must be exhaustive):

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

> **Critical**: The hash function must visit state in **canonical order**. Iterating a Godot `Dictionary` is **non-deterministic across versions**. Always sort keys or use `Array` for hashable iteration.

## Float Determinism Pitfalls

Cross-platform float math is **not bit-identical** by default. Even within one platform, ordering of float operations can drift.

Mitigations:
- **Quantize** before hashing: `_fnv_mix(h, int(value * 1000.0))` — round to milli-units. This prevents accidental 1-bit float drift from breaking diff while still catching real divergence.
- **Avoid** trig functions in deterministic-critical paths where possible (or vendor a fixed-point implementation).
- **Pin** physics integration step (`Engine.physics_ticks_per_second = 60`).
- **Disable** `Engine.max_physics_steps_per_frame` > 1 — frame skipping breaks determinism.

## Godot 4.6 Known Determinism Footguns

| Footgun | Fix |
|---|---|
| `randf()` / `randi()` without seeded `RandomNumberGenerator` | Always create explicit `RandomNumberGenerator` per system; seed on `reset()` |
| `OS.get_ticks_msec()` for game logic | Use `Engine.get_physics_frames()` only |
| `_process(delta)` for game logic | Move to `_physics_process(delta)`; physics tick is fixed |
| `Dictionary` iteration order | Sort keys or use `Array` for canonical traversal |
| Signal emission order across `connect()` calls | Avoid order-dependent signal logic; or use `connect(..., CONNECT_DEFERRED)` consistently |
| `Node._ready()` order | Don't rely on cross-node init order; use explicit deps |
| Physics integrator (Jolt vs Godot Physics) | Pin in `project.godot`; document as ADR |
| `Time.get_unix_time_from_system()` | Banned in game logic |
| Threaded code touching game state | Banned in deterministic paths; only loaders may run threaded |
| Shader output (visual only — OK; logic — banned) | Never read shader pixels for gameplay |

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
    # Run 1: record
    run1 = subprocess.run([
        "./godot", "--headless", "--bot=heuristic_lag9",
        "--seed", str(seed), "--boss", boss, "--frames", str(frames),
        "--record-replay", "/tmp/run1.replay"
    ])
    # Run 2: record same conditions
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

When CI flags divergence, automatically bisect:

```python
def bisect_divergence(replay1: Replay, replay2: Replay) -> int:
    lo, hi = 0, len(replay1.hashes)
    while lo < hi:
        mid = (lo + hi) // 2
        if replay1.hashes[mid] == replay2.hashes[mid]:
            lo = mid + 1
        else:
            hi = mid
    return lo  # first divergent frame
```

Then dump full state at frame `divergence - 1` (last good) and frame `divergence` (first bad) for diff:

```
$ python tools/state_diff.py --replay1=run1.replay --replay2=run2.replay --frame=247
DIVERGENT at frame 247:
  player.position.x:  120.5      → 120.5
  player.position.y:  -64.0      → -64.0
  player.velocity.y:  3.21       → 3.22       ← DIFF
  ...
HYPOTHESIS: physics integrator step inconsistency
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

Beyond per-PR CI gate, run a periodic suite that catches platform / cross-version regressions:

| Test | Frequency | What it catches |
|---|---|---|
| Per-PR replay diff (100 seeds × 2 runs) | Every PR | Local non-determinism |
| Cross-platform (Linux + macOS + Windows) | Nightly | Platform float drift |
| Cross-Godot-version (current + RC) | Pre-Godot-update | Engine regression |
| Long-run soak (10 min × 100 seeds) | Weekly | Slow-leak float drift |
| Time-rewind torture (rewind every 5 frames × 1 hr) | Weekly | Snapshot/restore correctness |

## Time-Rewind Torture (Echo Signature)

Echo's time-rewind makes determinism doubly important: not only must the live timeline be deterministic, but the snapshot/restore path must reproduce the recorded state bit-identically.

```python
def torture_time_rewind(seed: int, frames: int) -> bool:
    """
    Run the boss with rewind triggered every 5 frames.
    After each rewind, hash state and verify it matches
    the snapshot's pre-recorded hash.
    """
    # ...
```

If torture passes but the regular replay diff fails, the bug is in core gameplay.
If torture fails but replay diff passes, the bug is in the snapshot/restore path.

## What This Catches (and What It Doesn't)

Catches:
- Unseeded RNG anywhere in game logic
- Order-dependent dictionary iteration
- Float drift across runs / platforms / versions
- Threaded code touching game state
- Cross-version Godot engine regressions
- Time-rewind state restoration bugs

Does NOT catch:
- Logic errors that produce identical wrong results every time (deterministic bugs)
- Visual / audio glitches (no state hash)
- Performance regressions (frame timing only)
- Memory leaks (state hash doesn't include allocation size)

## Echo Determinism Mandate

```yaml
echo_determinism:
  ci_gate: blocking          # PR cannot merge if determinism fails
  test_runs_per_pr: 100      # 100 seeds, each verified across 2 runs
  cross_platform_nightly: true
  cross_version_pre_update: true
  time_rewind_torture_weekly: true
```

## Anti-Patterns

| Anti-pattern | Why bad |
|---|---|
| Hash only player state | Misses projectile / boss / snapshot drift |
| Skip hash on visual-only state | Animation playback time matters for time-rewind |
| Allow CI to "occasionally fail" determinism | Determinism failure is binary; flaky = real bug |
| Disable determinism test on bug | The test is the contract; fix the bug, don't mute |
| Hash full float bits without quantization | Triggers false positives from 1-bit drift |
| Quantize so coarsely real bugs hide | 1ms quantization is the sweet spot for Echo |

## Open Questions

- **[NEW]** What's Echo's quantization unit — 1 millisecond? 1 millipixel? Both?
- **[NEW]** Should `.replay` files ship with builds for community speedrun verification?
- **[NEW]** Is the per-PR cost of 100 seeds × 2 runs sustainable, or scale to 25 seeds for CI / 100 for nightly?
- **[NEW]** Cross-platform CI is expensive — Linux only for PR, full triple for nightly?
- **[NEW]** When a Godot patch update breaks determinism, do we pin the old version or migrate replays?

## Related

- [[Bot Validation Pipeline Architecture]] — replay diff is the foundation under bot validation
- [[Time Manipulation Run and Gun]] — Echo's rewind is the most determinism-sensitive feature
- [[Deterministic Game AI Patterns]] — broader determinism philosophy
