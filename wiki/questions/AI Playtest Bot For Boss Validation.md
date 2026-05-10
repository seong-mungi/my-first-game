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

Deterministic games are the ideal substrate for bot-based validation: same input → same output, so 1000 runs are statistically meaningful and the headless engine can simulate hours of play in minutes. This page is the methodology for using bots to certify boss difficulty before exposing a boss to human playtesters.

Bots **cannot judge fun** — that is human-only — but they can prove that the designer's intent (phase distribution, rewind enforcement, learning curve) actually fires the way the GDD claims.

## Why Bots Work in Deterministic Games

| Deterministic | Non-deterministic |
|---|---|
| Same seed → same outcome | Run-to-run drift |
| Statistics meaningful at low N | Needs 10× sample size |
| Reproducible failure cases | Heisenbugs |
| Headless acceleration possible | Renderer-coupled timing |

Echo runs locked 60 fps with `CharacterBody2D` + direct transform (Source: [[Solo Contra 2026 Concept]] design baseline) — this stack is pure-function-of-state, so headless mode runs at multi-hundred-fps. **100 hours of human play = ~1 hour of bot time**.

## Four Bot Archetypes (Each Measures a Different Claim)

### ① Random Bot — "Floor" Check
- Random inputs every frame.
- **Question answered**: Can a monkey win this boss by luck?
- **Target**: 0% win rate over 1000 runs.
- **Failure signal**: ≥ 1% wins → safe-zone exists in the arena, or one phase is too forgiving.

### ② Scripted Bot — "Ceiling" Check
- Designer-authored optimal input sequence replayed.
- **Question answered**: Is the boss beatable at all?
- **Target**: 100% win rate over 100 runs.
- **Failure signal**: < 100% → non-determinism bug; same script ought to win identically every time.

### ③ Heuristic Bot — "Competent Player" Simulation
- Rule-based reactions: "telegraph visible → jump", "death-beam → consume rewind".
- **Question answered**: Does a player who reads telegraphs win sometimes?
- **Target**: 30–70% win rate.
- **Failure signal**: < 5% → too hard; > 80% → too easy; outside that band invalidates the difficulty claim.

### ④ Reinforcement-Learning Bot — "Human Learning Curve"
- PPO or similar; learns over thousands of episodes.
- **Question answered**: Does the boss reward learning, and how steeply?
- **Target**: Win rate ascending with episodes; plateau on a phase signals that phase as a learning bottleneck.
- **Failure signal**: Flat learning curve → boss is unlearnable; sudden mastery → boss is trivially scriptable.

## Metrics That Matter

### Clear Metrics
| Metric | Echo target (boss 1) |
|---|---|
| Time-to-First-Clear (TTFC) | 15–25 attempts |
| Mean clear time | 2–4 minutes |
| Clear rate at 30 attempts | ≥ 80% |

### Death-Distribution Metrics
- **Death-by-Phase**: P1 ~40%, P2 ~30%, P3 ~25%, P4 ~5% is the canonical learning-curve shape (front-loaded, tapering).
- **Death-by-Pattern**: Any single pattern responsible for > 50% of deaths is a tuning red flag.
- **Death Heatmap**: Per-position fatality density verifies safe-zone existence and reveals unintended kill pockets.

### Learning-Curve Metrics
- **HP-at-Death progression**: At attempt 1, 5, 10, 20 — boss HP remaining must trend down.
- **Survival Time progression**: Should rise per attempt.
- **Pattern Success Rate**: Per-pattern dodge rate climbing with attempts.

### Time-Mechanic Metrics (Echo-specific)
| Metric | Validates |
|---|---|
| **Rewind Usage Rate** | Fraction of deaths where rewind was attempted. Should approach 100% on the death-sentence pattern. |
| **Rewind Save Rate** | Survival rate after rewind consumption. Validates that the dodge window ≥ 9 frames. |
| **Pattern-Without-Rewind Clear** | Clear rate when rewind disabled. The death-sentence phase should hit 0% — proves rewind is actually mandatory. |

## Implementation Path (Echo / Godot 4.6)

### Step 1: Headless + Determinism Verification

```bash
godot --headless --no-window --fixed-fps 60 \
      --script tests/bots/run_boss_bot.gd \
      --bot-type=heuristic --boss=meaeokkun --runs=1000
```

First gate: run the same input log twice and confirm identical death frame. Any divergence is a non-determinism bug to fix before bot work proceeds.

### Step 2: Bot Interface Contract

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
        "boss_attack_phase_t": float, # 0..1 telegraph progress
        "projectiles": Array,
        "hp": int,
        "rewind_tokens": int,
        "frame": int
    }

# Bot → Game
func apply_action(action: Dictionary):
    # action = {move_x: -1/0/1, jump: bool, shoot: bool, rewind: bool}
```

### Step 3: Bot Archetype Stubs

**Random**:
```gdscript
func choose_action(obs) -> Dictionary:
    return {"move_x": randi_range(-1,1), "jump": randf() < 0.1,
            "shoot": randf() < 0.5, "rewind": randf() < 0.01}
```

**Scripted**: replay an authored `InputLog` resource frame by frame.

**Heuristic**: rule cascade (telegraph → jump; death-beam telegraph → rewind; default → shoot toward boss).

**RL**: Stable-Baselines3 PPO with a Python ↔ Godot socket. Reward = HP delta + clear bonus − death penalty. Determinism makes RL converge ~5–10× faster than equivalent stochastic environments.

## Validation Scenarios

### Scenario A — "Is this boss fair?"
1. Random bot × 1000 → expect 0% win rate.
2. Scripted bot × 100 → expect 100%.
3. Heuristic bot × 1000 → expect 40–60%.

Out-of-band results map directly to specific defects:
- Random > 0% → arena exploit, fix layout.
- Scripted < 100% → non-determinism bug.
- Heuristic < 5% → unfair; > 80% → trivial.

### Scenario B — "Which phase breaks the learning curve?"
RL bot × 5000 episodes; bin death distribution by attempt range. A phase that absorbs >50% of deaths after attempt 500 is a pattern that resists learning — likely a dodge window narrower than 9 frames.

### Scenario C — "Is rewind actually mandatory?"
Run heuristic bot with rewind disabled. P3 should hit 0% clear. If P3 still clears without rewind, the death-sentence pattern is dodgeable conventionally and the time-mechanic is decorative — design failure.

### Scenario D — "Is the 9-frame window enough?"
Heuristic bot with artificial 9-frame reaction lag. Dodge success rate ≥ 70% → window is fair. ≤ 30% → window too narrow even for an optimal reactor, much less a human (Source: [[Time Manipulation Run and Gun]]).

## Industry Reference Cases

| Studio / Game | Bot Type | Validates |
|---|---|---|
| **EA FIFA** | RL + scripted | AI difficulty rating calibration |
| **Riot Games (LoL)** | Heuristic | Champion balance, new champion verification |
| **Blizzard Hearthstone** | Scripted + RL | Card OP detection |
| **DeepMind AlphaStar (StarCraft II)** | RL | Grandmaster-level agent |
| **OpenAI Five (Dota 2)** | RL | Pro-level performance |
| **Spelunky 2 (Derek Yu)** | Scripted | Per-seed clearability check |
| **Niantic (Pokemon GO)** | Heuristic | Raid boss difficulty tier |
| **Ubisoft La Forge** | RL + heuristic | Watch Dogs / AC balance |

> **Solo-developer ROI**: Riot's heuristic-bot model + Spelunky's scripted-bot model is the right scale for Echo. RL-bot infrastructure is high-cost; deferred to Tier 3 only.

## Echo Bot-Tier Strategy

### Tier 1 (MVP) — Solo Developer Achievable
- Random bot — ~1 day.
- Scripted bot — ~0.5 day per boss.
- Simple heuristic bot — ~1 week.
- Death-by-Phase metric automation — ~3 days.

Required as a pre-launch boss gate.

### Tier 2 (Polish)
- Heuristic bot with 9-frame reaction-lag simulation.
- Per-attempt learning-curve charts.
- Rewind-enforcement validation (Scenario C).

### Tier 3 (Post-Launch / Stretch)
- RL bot via Stable-Baselines3 + PPO bridge.
- Auto-balance pattern recommendation from RL outcomes (designer review gated).

## Bot Validation Pitfalls

| Pitfall | Mitigation |
|---|---|
| **Bots aren't humans** | An 80% bot win rate is not 80% human win rate. Bot validates *intent*, not feel. |
| **Determinism dependency** | Tiny non-determinism breaks bot stats — bots double as a determinism test. |
| **Local optima** | A heuristic that finds one valid path doesn't prove other paths work. |
| **Meta-game blind spot** | Bots have no concept of frustration, satisfaction, or progression. |
| **Reward hacking (RL)** | RL bots find unintended exploits (wall-clip, invuln glitches) — useful as a free QA pass. |

## The Bottom Line

> **Bots are the deterministic game's auto-grader.** They prove the designer's intent (phase distribution, rewind enforcement, learning curve) actually executes. They cannot grade fun — that remains human work.

## Open Questions

- **[NEW]** Should bot validation be a CI gate (boss merge blocker) or a manual pre-release gate?
- **[NEW]** Is a Godot ↔ Python RL bridge worth building for Echo at MVP scale, or push to post-launch?
- **[NEW]** What is Echo's empirical reaction-lag baseline (frames) to set the heuristic bot's lag parameter realistically?
- **[NEW]** Can bot death-heatmaps feed into level-tuning automation, or only manual review?

## Sources

- DeepMind, AlphaStar (2019).
- OpenAI, "Dota 2 with Large Scale Deep RL" (2019).
- Microsoft, Project Malmo (Minecraft RL platform).
- Riot Games, GDC talks on champion-balance bot testing.
- Stable-Baselines3 documentation (PPO reference implementation).
