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

Standardized template for the bot-validation rows in any Echo GDD's Acceptance Criteria section. The goal: every measurable design claim becomes a bot-checkable target with a concrete bot, run count, and pass/fail band.

If a design intent cannot be expressed in this template, it cannot be validated automatically — and either belongs to the human-playtest column, or needs to be sharpened.

## Where This Lives

Echo's CLAUDE.md mandates 8 GDD sections. Section 8 (Acceptance Criteria) gains two subsections:

```
8.1 Design Intent (human-validated)
8.2 Bot Validation (automated)        ← this template
```

## Schema (YAML, Embedded as Front-Matter or Code Block)

```yaml
bot_validation:
  enabled: true
  bot_suite: <suite-name>     # e.g. "boss_v1", "movement_v1"
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
      runs: 5000   # episodes
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
      target: { max: 0.5 }   # rewind rare on mobs
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
      target: { max: 0.5 }   # max pixel deviation
      bot: scripted_jump_grid
      runs: 100
      tier: ci
    - id: rewind_restore_position_drift
      target: { max: 0.0 }   # exact, no drift
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
      target: { max: 0.0 }   # exact frame match
      bot: scripted_rapid_fire
      runs: 100
      tier: ci
```

## Markdown Embed Pattern

Inside the GDD, embed the YAML inside a fenced code block tagged for parser detection:

```markdown
## 8. Acceptance Criteria

### 8.1 Design Intent (Human Validated)
- [ ] First-death-to-P1 reach time ~30s (5 human playtesters)
- [ ] Post-clear satisfaction ≥ 4/5 (5 human playtesters)
- [ ] Telegraph clarity rating ≥ 4/5 (5 human playtesters)

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

The CI tool reads:
1. All `*.md` files under `design/gdd/`.
2. Extracts `\`\`\`yaml bot-validation` fences.
3. Loads YAML, validates against schema.
4. Joins to live bot results (`production/qa/bots/reports/latest.json`).
5. Generates the verdict per criterion and emits a verdict markdown for PR comment.

## Tier Discipline

| Tier | Runs in | Cost budget |
|---|---|---|
| `ci` | Every PR | < 10 min total across all GDDs |
| `nightly` | Once daily on main | < 2 hr total |
| `release` | Pre-release gate | < 12 hr total |

Authoring tip: Keep `ci`-tier metrics small in count and runs. Heuristic-with-lag at 1000 runs costs ~3 min; reserve for the most critical bands. RL metrics belong in `release` tier exclusively.

## Anti-Patterns

| Anti-pattern | Why bad |
|---|---|
| Embedding raw test code in GDD | GDD is design intent, not implementation |
| Targets without runs / bot specified | Unreproducible — fails CI determinism guarantee |
| Soft targets ("around 50%") | Cannot machine-validate |
| `enabled: false` left in shipped GDD | Design claim with no validation = drift risk |
| Metrics that depend on RNG | Defeats the determinism precondition |
| Targets that change per build without history | Loses regression detection |

## Linking Conventions

- Each `bot_suite` name maps to a folder under `tools/bots/suites/<suite-name>/`.
- Each `bot` name maps to a class in `tools/bots/<bot>.gd` (Godot side) or `tools/bots/<bot>.py` (Python side for RL).
- Each `metric_id` maps to a key in the bot's JSON output schema.

## Echo's First GDD With This Template

When the boss `meaeokkun` GDD lands, it ships with the **Boss Validation** template above pre-filled. The values in that template are Echo's *de facto* defaults until overridden by data:
- Heuristic 30–70% band
- Death-by-Phase front-loaded (P1 ≥ 30% ≥ P4 ≤ 10%)
- Rewind Save Rate ≥ 70%
- Pattern-without-Rewind P3 = 0%

## Open Questions

- **[NEW]** Where does the bot-validation YAML schema live as authoritative spec — `docs/registry/` or in a new `tools/bots/schema.yaml`?
- **[NEW]** Should bot-validation YAML support inheritance (boss-specific overrides on top of a default boss template)?
- **[NEW]** Should the GDD authoring skill (`/design-system`) auto-insert an empty 8.2 Bot Validation block?
- **[NEW]** Should missing bot-validation block be a CI warning or accepted as "human-only validation intentional"?
