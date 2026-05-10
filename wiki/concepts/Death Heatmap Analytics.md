---
type: concept
title: Death Heatmap Analytics
created: 2026-05-10
updated: 2026-05-10
tags:
  - analytics
  - visualization
  - tuning
  - bot
  - playtest
  - design-pattern
  - echo-applicable
status: developing
related:
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Bot Human Validation Reconciliation]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[Boss Two Phase Design]]"
---

# Death Heatmap Analytics

Bot reports give numeric verdicts; death heatmaps give spatial-temporal-pattern *diagnoses*. The heatmap turns "Heuristic bot win rate 32%" into "P3 deaths cluster at the right wall during the death-beam telegraph", which is a directly actionable redesign target.

This page is the analytics contract: what to log per death, which views to render, which patterns trigger which design fix.

## Three Heatmap Views

Each death event is logged with full context. From one dataset, three orthogonal views answer different questions:

| View | Question answered | Primary axis |
|---|---|---|
| **Spatial heatmap** | *Where* on the arena are players dying? | x, y position |
| **Temporal heatmap** | *When* during a pattern do players die? | seconds since pattern start |
| **Pattern attribution** | *Which* boss state was active at death? | pattern ID + phase |

## Death Event Schema

Every death event captured by bots or humans logs:

```yaml
death_event:
  build_hash: "a1b2c3d"
  source: "bot_heuristic_lag9"   # or "human_session_42"
  attempt_number: 17
  frame: 7234
  player_pos: [x, y]
  player_velocity: [vx, vy]
  player_facing: -1
  boss_state: "telegraph_death_beam"
  boss_phase: "P3"
  boss_pattern_id: 4
  boss_pattern_progress: 0.83   # 0-1 through the pattern
  cause: "death_beam_direct_hit"
  rewind_tokens_at_death: 1
  hp_before_death: 1
  time_since_phase_start: 14.2  # seconds
  time_since_pattern_start: 0.83
```

Schema is shared between bot and human telemetry — same schema = same heatmap pipeline.

## View 1: Spatial Heatmap

2D arena overlay, intensity = death count per cell.

```python
import numpy as np
import matplotlib.pyplot as plt
from scipy.ndimage import gaussian_filter

def render_spatial_heatmap(deaths, arena_w, arena_h, phase=None, out_path=None):
    grid = np.zeros((arena_h, arena_w), dtype=np.float32)
    for d in deaths:
        if phase and d["boss_phase"] != phase: continue
        x, y = int(d["player_pos"][0]), int(d["player_pos"][1])
        if 0 <= x < arena_w and 0 <= y < arena_h:
            grid[y, x] += 1
    grid = gaussian_filter(grid, sigma=8)
    plt.imshow(grid, cmap="hot", origin="lower")
    plt.title(f"Deaths in {phase or 'all phases'}: n={len(deaths)}")
    plt.colorbar(label="density")
    plt.savefig(out_path)
```

### Diagnostic Reading

| Pattern in heatmap | Likely cause | Fix target |
|---|---|---|
| Single hot cluster | One pattern killing most players at one location | Adjust that pattern's spatial layout |
| Hot stripe at arena edge | Players cornered, no escape | Widen arena or remove kill volume there |
| Cold spot (no deaths) in middle of action | Safe-zone exploit | Patch arena geometry or pattern coverage |
| Hot cluster at entry point | P1 too aggressive at fight start | Slow P1 first 3 seconds |
| Concentric ring around boss | Players hugging boss for some pattern | Add inner kill zone |
| Even distribution | Boss "fair" but undifferentiated | OK if intended; bland if not |

## View 2: Temporal Heatmap

Time-since-pattern-start on x-axis, deaths binned per 1/60s.

```python
def render_temporal_heatmap(deaths, pattern_id, out_path):
    times = [d["time_since_pattern_start"] for d in deaths
             if d["boss_pattern_id"] == pattern_id]
    plt.hist(times, bins=60)
    plt.xlabel("seconds since pattern telegraph started")
    plt.ylabel("death count")
    plt.title(f"Pattern {pattern_id} death timing distribution")
    # Annotate dodge window
    plt.axvspan(0.4, 0.55, alpha=0.2, label="9-frame dodge window @ telegraph end")
    plt.legend()
    plt.savefig(out_path)
```

### Diagnostic Reading

| Pattern in temporal histogram | Likely cause |
|---|---|
| Spike outside the dodge window | Players don't recognize telegraph; visual issue |
| Spike at frame 1 of pattern | No telegraph at all; pure surprise kill |
| Spike at telegraph-end | Dodge window too short or unfair direction |
| Even distribution across pattern | Pattern has no clear "safe / unsafe" beat — pacing dull |
| Bimodal distribution | Two distinct failure modes — investigate both |

## View 3: Pattern Attribution

Which boss states / patterns are deadliest?

```python
def render_pattern_attribution(deaths, out_path):
    from collections import Counter
    counts = Counter(d["boss_pattern_id"] for d in deaths)
    patterns = sorted(counts.keys())
    values = [counts[p] for p in patterns]
    plt.bar(patterns, values)
    plt.xlabel("Pattern ID")
    plt.ylabel("Death count")
    plt.title("Deaths by boss pattern")
    plt.savefig(out_path)
```

### Diagnostic Reading

| Pattern | Likely action |
|---|---|
| One pattern accounts for > 50% of deaths | Pattern unfair → redesign |
| One pattern accounts for < 5% | Pattern trivial → remove or buff |
| Late patterns (P3, P4) account for < 10% | Players don't reach late phases — front-loaded difficulty broken |
| Late patterns account for > 60% | Difficulty curve OK but P4 may be too hard |

## Cluster Detection (Auto-Diagnose)

For arenas with thousands of deaths, manually reading hot zones doesn't scale. Use DBSCAN to extract clusters:

```python
from sklearn.cluster import DBSCAN

def detect_death_clusters(deaths, eps=24, min_samples=20):
    coords = np.array([d["player_pos"] for d in deaths])
    clustering = DBSCAN(eps=eps, min_samples=min_samples).fit(coords)
    clusters = []
    for label in set(clustering.labels_):
        if label == -1: continue   # noise
        mask = clustering.labels_ == label
        clusters.append({
            "center": coords[mask].mean(axis=0),
            "size": mask.sum(),
            "deaths": [deaths[i] for i in np.where(mask)[0]],
        })
    return sorted(clusters, key=lambda c: -c["size"])
```

Output: top 5 clusters with center coords, size, and dominant pattern. Attach to bot report.

## Safe-Zone Detection

Inverse problem: large arena regions with **zero** deaths despite player presence. Likely exploit.

```python
def detect_safe_zones(deaths, presence_grid, arena_w, arena_h, min_size=400):
    death_grid = np.zeros((arena_h, arena_w))
    for d in deaths:
        x, y = int(d["player_pos"][0]), int(d["player_pos"][1])
        death_grid[y, x] += 1
    # cells where presence > 0 but deaths == 0 over a continuous area
    # ... (flood fill on presence > 0 ∩ death == 0)
```

Designer review: safe-zone with high presence + zero deaths = **patch arena or extend pattern coverage**.

## Build Comparison (Regression Detector)

Render two heatmaps side-by-side: current build vs previous. Highlight cells with significant delta.

```python
def render_build_diff(deaths_now, deaths_before, out_path):
    grid_now = _to_grid(deaths_now)
    grid_before = _to_grid(deaths_before)
    diff = grid_now - grid_before
    plt.imshow(diff, cmap="RdBu", origin="lower")  # red = more deaths now
    plt.title("Death distribution change vs previous build")
    plt.colorbar(label="Δ deaths per cell")
    plt.savefig(out_path)
```

Use cases:
- After tuning a pattern, verify deaths shifted off the unfair location.
- After a refactor, verify no new hot zones emerged.
- Pre-release, verify smooth distribution evolution.

## Embedded in Bot Report

The HTML bot report ([[Bot Validation Pipeline Architecture]] subsystem C) embeds these views per boss:

```
┌─ Boss meaeokkun — Death Analytics ──────────────────┐
│                                                     │
│  [Spatial heatmap, P1]    [Spatial heatmap, P3]     │
│                                                     │
│  [Temporal: pattern 4]    [Pattern attribution]     │
│                                                     │
│  Clusters detected: 3                               │
│   1. (820, 540) — 47% of P3 deaths — death_beam     │
│   2. (200, 100) — 23% of P1 deaths — overhead_drop  │
│   3. (640, 720) — 12% of P2 deaths — sweep_left     │
│                                                     │
│  Safe zones detected: 1                             │
│   1. (40-100, 600-680) — 0 deaths, 38s presence     │
│      — exploit candidate                            │
│                                                     │
│  Build delta vs ci-12344: +12% P3 deaths in cluster │
│      1; tuning regression possible                  │
└─────────────────────────────────────────────────────┘
```

## Designer Workflow

```
Morning:
  1. Open latest bot report HTML
  2. Read clusters (top 3) — what's killing players most?
  3. Read safe zones — any exploit candidates?
  4. Read build delta — any regressions from yesterday?
Action:
  5. Pick one cluster → identify governing pattern
  6. Decide: arena geometry / pattern timing / telegraph clarity?
  7. Edit GDD or implementation
  8. Re-run bot suite → re-render heatmaps → diff
```

## Combining With Human Telemetry

Same schema for bot deaths and human deaths means heatmaps merge cleanly. Two ways:

1. **Side-by-side**: render bot heatmap + human heatmap; visually compare clusters.
2. **Layered**: bot heatmap as base layer (red), human heatmap as overlay (blue) with alpha.

Disagreements = ⚠️ Hidden Defect quadrant ([[Bot Human Validation Reconciliation]]):
- Cluster present in human heatmap but absent in bot → bot model misses this failure
- Cluster present in bot heatmap but absent in human → bot weaker than humans here
- Cluster present in both → genuine design defect

## Sample Size Guidance

| View | Useful sample size |
|---|---|
| Spatial heatmap (overall) | ≥ 500 deaths |
| Spatial heatmap (per phase) | ≥ 100 deaths per phase |
| Temporal histogram | ≥ 100 deaths per pattern |
| Pattern attribution | ≥ 200 deaths total |
| Cluster detection | ≥ 1000 deaths |
| Safe-zone detection | ≥ 5000 deaths + presence data |

> Bots produce these volumes in minutes; humans cannot. **Heatmaps are an offline-bot strength — humans contribute qualitative survey, not heatmap density.**

## Echo Default Output Locations

```
production/qa/bots/heatmaps/
├── <date>-<boss>-<build>/
│   ├── spatial_p1.png
│   ├── spatial_p2.png
│   ├── spatial_p3.png
│   ├── spatial_p4.png
│   ├── temporal_pattern_<id>.png   # one per pattern
│   ├── attribution.png
│   ├── clusters.json
│   ├── safe_zones.json
│   └── build_diff.png
```

## Anti-Patterns

| Anti-pattern | Why bad |
|---|---|
| Render heatmap once, never update | Drifts as design changes; trust evaporates |
| Aggregate all phases together | P1 and P3 collisions different — useless mixed |
| Ignore safe-zone detection | Hardest defect class; only automatable diagnostic |
| No build delta view | Regressions slip; tuning blind |
| Heatmap with n < 100 | Visual noise reads as signal |
| Render only spatial, skip temporal | Misses *when* of pattern failures |
| Skip cluster auto-detection | Designers eyeball wrong cluster as primary |

## Open Questions

- **[NEW]** Should heatmaps be live-updating during a long playtest (streaming render)?
- **[NEW]** What's Echo's arena cell resolution — 4×4 px? 8×8 px?
- **[NEW]** Should presence data be logged for every player frame, or sampled (every 10 frames)?
- **[NEW]** Cluster center coordinates — should they pin into the GDD as named landmarks ("P3 east kill cluster")?
- **[NEW]** Build-diff should fail CI if cluster size delta > X%?

## Related

- [[Bot Validation Pipeline Architecture]] — heatmaps live inside the dashboard subsystem
- [[Bot Human Validation Reconciliation]] — heatmaps are the visual layer of the four-quadrant matrix
- [[AI Playtest Bot For Boss Validation]] — bots produce the volume that makes heatmaps statistically meaningful
- [[Boss Two Phase Design]] — phase-specific heatmaps validate phase design
