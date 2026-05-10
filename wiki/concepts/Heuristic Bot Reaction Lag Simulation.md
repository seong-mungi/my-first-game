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

A heuristic bot without artificial reaction lag is dishonest: it sees frame F and acts on frame F. No human plays this way. To make heuristic bot win-rate a meaningful proxy for human fairness, the bot must absorb the same temporal handicap a competent human carries.

The pattern: insert a fixed-frame delay between perception and action. Calibrate to match measured human reaction-time data.

## Why Lag Matters

Without lag, a heuristic bot validates only "is this dodgeable in principle". With realistic lag, it validates "is this dodgeable by a human who reads telegraphs". The Echo dodge window must be fair under the *human* lag, not the *machine* lag.

## Human Reaction-Time Reference

Empirical baselines (validated literature, ~2010–2024):

| Stimulus type | Mean reaction time | Frames @ 60 fps |
|---|---|---|
| Visual (simple) | ~250 ms | 15 |
| Visual (complex / choice) | ~350–450 ms | 21–27 |
| Audio | ~160 ms | 10 |
| Proprioceptive (own body) | ~80–100 ms | 5–6 |
| Trained gamer (anticipation present) | 150–200 ms | 9–12 |

> **Echo's 9-frame rewind window equals trained-gamer reaction floor.** This is by design — the rewind window must be at least as wide as the player's reaction window, otherwise the mechanic feels unfair (Source: [[Time Manipulation Run and Gun]]).

## Implementation Pattern

Two delay surfaces, both required:

### 1. Perception Lag (observation buffer)

Bot's "current observation" is observation from N frames ago.

### 2. Action Lag (execution queue)

Bot's decision applies M frames after the decision frame.

Total reaction lag = perception lag + action lag. Echo default: 6 + 3 = 9 frames.

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

    # Decide based on perceived (lagged) state
    if _obs_history.size() >= PERCEPTION_LAG:
        var perceived := _obs_history[-PERCEPTION_LAG]
        var decided := _decide(perceived)
        _action_queue.append({
            "action": decided,
            "fire_frame": _current_frame + ACTION_LAG
        })

    # Fire any actions whose time has come
    return _consume_due_action()

func _consume_due_action() -> Dictionary:
    var idle := {"move_x": 0, "jump": false, "shoot": false, "rewind": false}
    while not _action_queue.is_empty() and _action_queue[0].fire_frame <= _current_frame:
        idle = _action_queue.pop_front().action
    return idle

func _decide(perceived: Dictionary) -> Dictionary:
    # Telegraph → jump
    if perceived.boss_state == "telegraph_line" and perceived.boss_phase_t > 0.6:
        return {"jump": true, "shoot": true, "move_x": 0, "rewind": false}
    # Death-sentence telegraph → preempt rewind on next death
    if perceived.boss_state == "telegraph_death_beam":
        return {"jump": false, "shoot": false, "move_x": 0, "rewind": false}
    # Just died this frame? Rewind
    if perceived.hp == 0 and perceived.rewind_tokens > 0:
        return {"rewind": true}
    # Default: shoot toward boss
    return {
        "shoot": true,
        "move_x": sign(perceived.get("boss_pos_x", 0) - perceived.player_pos[0]),
        "jump": false,
        "rewind": false
    }
```

## Per-Modality Lag (Advanced)

Realistic humans react faster to audio than visual. Implement a per-source lag:

```gdscript
const LAG_BY_CHANNEL := {
    "visual_telegraph": 11,
    "audio_cue": 9,
    "screen_shake": 7,
    "own_state": 3,
}
```

Each rule pulls perception from `_obs_history[-LAG_BY_CHANNEL[channel]]`. This catches design failures where audio and visual telegraphs disagree on timing — the human strategy then becomes "trust audio first", which the bot will discover via its faster audio channel.

## Calibration Sweep

To determine the right lag for *Echo's specific player population*, sweep:

```
Run heuristic bot at lag = [3, 6, 9, 12, 15, 18] frames.
For each lag, measure dodge_success_rate per pattern.

Plot: dodge_rate vs lag.

The "fair" pattern has dodge_rate ≥ 70% at lag = 9.
The "unfair" pattern drops below 30% at lag = 9.
```

This sweep is a one-time calibration per pattern, not a per-CI cost. Run it during boss design, not on every PR.

## Noise / Imperfection Layer (Optional)

Real humans miss telegraphs ~5–10% of the time. Inject noise to model this:

```gdscript
const DECISION_DROP_RATE := 0.05
const PERCEPTION_DROP_RATE := 0.02

func _decide(perceived: Dictionary) -> Dictionary:
    if randf() < DECISION_DROP_RATE:
        return {}  # Missed the cue this frame
    # ...rest
```

> **Caution**: noise injection breaks pure determinism. Use only for calibration runs with fixed seed; do not enable in CI gate runs.

## What the Lagged Bot Catches

| Defect | How lag exposes it |
|---|---|
| Dodge window < 9 frames | Lagged bot's `dodge_success_rate` collapses |
| Telegraph too short | Perception buffer never has telegraph for long enough |
| Audio/visual disagreement | Per-modality lag bot finds asymmetry |
| Multi-step pattern (must react to 2 cues) | Action queue overflows, missed second cue |
| Patterns require sub-9-frame chaining | Provably impossible at human lag |

## What Lagged Bot Does NOT Catch

- **Cognitive load** — humans process 4 things at once badly; bot processes any number perfectly
- **Visual clarity** — bot reads exact pixels; human reads gestalt
- **Pattern memorization fatigue** — bot remembers everything; humans don't
- **Frustration / tilt** — bots have no emotional state

These remain human-playtest territory.

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
  decision_drop_rate: 0.0  # CI: deterministic; calibration: 0.05
  perception_drop_rate: 0.0
```

## Calibration Schedule
- **Per boss, design phase**: full lag sweep (3, 6, 9, 12, 15, 18) × 1000 runs each = ~6000 runs (~30 min headless)
- **Per PR**: lag = 9 only, 100 runs (~3 min)
- **Per release**: lag sweep at 3 / 9 / 15 to verify resilience to faster/slower players

## Related Patterns

- [[AI Playtest Bot For Boss Validation]] — parent context for this implementation
- [[Bot Validation Pipeline Architecture]] — where the lagged heuristic plugs in
- [[Time Manipulation Run and Gun]] — Echo's 9-frame rewind window rationale
- [[Modern Difficulty Accessibility]] — the dodge-window-fairness obligation under modern accessibility expectations

## Open Questions

- **[NEW]** Should lag be configurable per difficulty tier (Easy = 12 frames lag tolerance) to validate accessibility settings?
- **[NEW]** Is per-modality lag worth the complexity, or is uniform 9-frame sufficient at Echo's scale?
- **[NEW]** Should the calibration sweep results pin design defaults in the GDD Tuning Knobs section?
