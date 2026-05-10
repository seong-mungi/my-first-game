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

PPO and similar policy-gradient algorithms learn whatever the reward function actually rewards — not what the designer meant. For Echo, the reward must induce the same learning curve a human would experience: survive, damage, learn patterns, use rewind correctly, never plateau.

This page is the reward-design contract for Echo's RL playtest bot. It exists because every bug in the reward becomes an exploit the bot finds in 100k episodes.

## Design Goals (What the Reward Must Encourage)

| Goal | Why it matters |
|---|---|
| Survive (don't take damage) | One-hit-death is core; any reward must penalize death heavily |
| Damage the boss | The whole point — ensure progress is rewarded |
| Use rewind on lethal threats | Rewind is signature; must not be ignored |
| Don't waste rewind | Rewind tokens are scarce; profligate use undermines learning |
| Learn phase-specific patterns | Bot's curve should mirror human's curve |
| Clear the boss | Strong terminal reward |

## Anti-Goals (What the Reward Must NOT Encourage)

| Anti-goal | Risk |
|---|---|
| Stalling for time bonus | Bot hides in safe zone, accumulates frame survival reward |
| Spamming rewind | Bot uses rewind every frame for "safety" |
| Ignoring boss | Bot survives forever without engaging |
| Dying then rewinding repeatedly | Bot exploits invincibility frames as a free buff |
| Reward hacking via wall clipping / glitches | Bot finds engine bugs |

## Reward Function (Echo Default)

```python
def compute_reward(prev_state, curr_state):
    r = 0.0

    # === Damage: dense positive, large weight ===
    boss_hp_delta = prev_state.boss_hp - curr_state.boss_hp
    r += boss_hp_delta * 10.0   # encourage offense

    # === Death: sparse, very large negative ===
    if curr_state.player_died_this_frame:
        r -= 100.0

    # === Clear: sparse, very large positive ===
    if curr_state.boss_hp == 0 and not prev_state.cleared:
        r += 500.0

    # === Phase progression: shaped milestone ===
    if curr_state.phase > prev_state.phase:
        r += 50.0   # encourage progressing through learning curve

    # === Rewind usage shaping ===
    if curr_state.rewind_consumed_this_frame:
        if prev_state.lethal_threat_imminent:
            r += 5.0   # correct usage
        else:
            r -= 2.0   # wasted

    # === Anti-stall: no reward for time alone ===
    # NOT: r += 0.01  ← REMOVED. This was a bug magnet.

    # === Mild engagement bonus: only when actively damaging ===
    if boss_hp_delta > 0:
        r += 0.1   # tiny tick to break ties favoring offense

    return r
```

## Why These Numbers (Calibration Logic)

| Component | Magnitude | Reasoning |
|---|---|---|
| `boss_hp_delta * 10` | up to ~100/frame | Match clear-bonus order of magnitude — clear = sum of damage rewards roughly equals 500 |
| `−100` per death | -100 | Strong but not infinite; bot must explore. With clear at +500, expected value of attempt > 0 only when win rate > 17% |
| `+500` clear | +500 | Strong terminal pull; dwarfs all dense rewards |
| `+50` per phase | +50 | Curriculum signal — phases are subgoals worth pursuing |
| `+5 / −2` rewind | small | Shape behavior without dominating |
| Frame survival | 0 | **Critical**: any positive value rewards stalling |

## Curriculum (Phase-Gated Training)

Train in stages to mirror a human's learning order:

```python
# Stage 1: P1 only (bot learns basic dodging)
env = EchoEnv(boss="meaeokkun", phase_lock="P1", episodes=2000)
model = PPO("MlpPolicy", env).learn(2_000_000)

# Stage 2: P1 + P2 (bot adapts dodging to harder pattern)
env = EchoEnv(boss="meaeokkun", phase_lock="P1-P2", episodes=2000)
model.set_env(env).learn(2_000_000)

# Stage 3: P1 + P2 + P3 (bot must learn rewind for death-sentence)
env = EchoEnv(boss="meaeokkun", phase_lock="P1-P3", episodes=2000)
model.set_env(env).learn(3_000_000)

# Stage 4: full boss
env = EchoEnv(boss="meaeokkun", phase_lock=None, episodes=5000)
model.set_env(env).learn(5_000_000)
```

Each stage warm-starts from the prior stage's weights. Without this, naive PPO often fails to discover rewind on P3 — same problem human players face, but bot has no narrative cue.

## Reward Hacking Watchlist (Echo-Specific)

| Exploit pattern | Symptom in metrics | Mitigation |
|---|---|---|
| Bot stalls in safe zone | TTFC rises, mean episode length explodes | Cap episode length (~30s); add −0.01 idle penalty if no boss damage in 5s |
| Bot spams rewind | Rewind usage per episode > N expected uses | Penalty when rewind consumed without prior `lethal_threat_imminent` |
| Bot dies → rewinds → dies again | Death rate same after training | Track consecutive deaths; cap at 1 per second |
| Bot clips through wall | Win rate suddenly 100% with weird trajectory | Manual replay review; fix engine bug |
| Bot abuses i-frame after rewind | Ignores telegraphs entirely | Reduce rewind reward to +1; never reward i-frame contact |

## `lethal_threat_imminent` Flag (Designer-Authored)

To reward rewind correctly, the env must signal when rewind is the *correct* response. This is a designer-authored signal, not RL-learned:

```gdscript
# In boss FSM
func _physics_process(_dt):
    self.lethal_threat_imminent = (
        self.state == "telegraph_death_beam" and
        self.attack_phase_t > 0.7 and
        player_in_lethal_path()
    )
```

This is why the boss FSM matters for RL — without designer-curated threat signals, reward shaping cannot distinguish "good rewind" from "panic rewind".

## Hyperparameter Defaults (PPO via Stable-Baselines3)

```python
PPO(
    "MlpPolicy",
    env,
    learning_rate=3e-4,
    n_steps=2048,
    batch_size=256,
    n_epochs=10,
    gamma=0.99,        # discount — high enough to value clears
    gae_lambda=0.95,
    clip_range=0.2,
    ent_coef=0.01,     # mild exploration; raise to 0.05 if bot underexplores
    vf_coef=0.5,
    max_grad_norm=0.5,
    seed=42,           # determinism
)
```

For Echo's observation size (~64 floats) and action space (`MultiDiscrete[3,2,2,2]`), PPO converges in ~10M timesteps for full boss with curriculum (~6 hours single-GPU laptop, ~2 hours 8-env parallel).

## Sparse vs Dense Trade-Off

Echo intentionally uses *both*:
- **Dense**: damage delta, rewind usage shaping
- **Sparse**: death penalty, clear bonus, phase progression

Pure-sparse (only death/clear) requires 10–100× more episodes — infeasible at solo-dev scale. Pure-dense (lots of frame-by-frame shaping) is exploitable. The mixed schedule above is the empirical sweet spot.

## Validation: Does the Reward Match Design Intent?

After training, audit the bot's behavior against design claims:

```python
# Log per-episode stats; verify they match GDD claims
metrics = {
    "avg_rewinds_per_clear": ...,
    "avg_damage_dealt_per_episode": ...,
    "phase_completion_rates": ...,
    "death_distribution_by_phase": ...,
}
```

If `avg_rewinds_per_clear` < 1 — RL bot is bypassing the rewind mechanic entirely; reward is mis-shaped. Fix the threat-imminent signal or raise the rewind reward.

If `death_distribution_by_phase` is uniform — phase rewards are too small to differentiate; raise `+50` per phase.

If `avg_episode_length` keeps growing — stall exploit; tighten anti-stall mitigations.

## When NOT to Use RL

For Echo at MVP / Tier 1 scale, RL is **overkill**. Use:
- Random + Scripted bots for floor/ceiling.
- Heuristic+lag bot for fairness ([[Heuristic Bot Reaction Lag Simulation]]).

RL becomes worthwhile only when:
- Heuristic bot's rules become unwieldy (>500 LOC of `if/else`).
- Need to validate "is this learnable in N attempts".
- Need to discover unintended exploits the heuristic missed.

This is firmly Tier 3 territory.

## Open Questions

- **[NEW]** Should reward shaping live alongside the boss GDD, or in `tools/bots/rewards/<boss>.py`? (Designer access vs co-location with code.)
- **[NEW]** Is curriculum training worth the orchestration cost at solo-dev scale, or is full-boss-from-scratch acceptable with longer training?
- **[NEW]** What metric flags reward hacking automatically (so it's caught before manual replay review)?
- **[NEW]** Should the death-sentence threat-imminent flag be exposed in the public boss API or remain an internal RL hook only?

## Related

- [[AI Playtest Bot For Boss Validation]] — parent context
- [[Bot Validation Pipeline Architecture]] — where this slots in
- [[Heuristic Bot Reaction Lag Simulation]] — Tier 2 alternative when RL overkill
- [[Deterministic Game AI Patterns]] — RL placement in Zone ③ (offline tools)
