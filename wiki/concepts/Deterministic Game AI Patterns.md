---
type: concept
title: Deterministic Game AI Patterns
created: 2026-05-10
updated: 2026-05-10
tags:
  - ai
  - game-ai
  - determinism
  - design-pattern
  - cross-genre
  - echo-applicable
status: developing
related:
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Time Manipulation Run and Gun]]"
  - "[[Boss Two Phase Design]]"
  - "[[Solo Contra 2026 Concept]]"
  - "[[Stealth Information Visualization]]"
  - "[[Cuphead]]"
  - "[[Katana Zero]]"
---

# Deterministic Game AI Patterns

Determinism (same input → same result) is the foundation that lets the player **learn** patterns. Adding AI to such a game is possible — but only in zones that do not corrupt the player-facing pattern surface. This page catalogs **where AI is verified safe**, where it is risky, and where it must be banned.

The player learns Pattern P. AI may help **make** P, **measure** P, or **mirror** P — but never **mutate** P at runtime.

## The Core Rule

> **AI builds patterns or analyzes patterns; AI does not change patterns the player has already started learning.**

Two senses of "AI":
- **Game AI** = enemy/NPC behavior logic (Behavior Trees, FSM, GOAP) — rule-based, designer-authored.
- **ML/AI** = learning systems (neural networks, RL, statistical analysis).

Both are usable in deterministic games. The constraints differ.

## Four Zones Where AI Is Safe (or Dangerous)

```
┌─ ① Runtime game AI (enemy/boss behavior) ──── determinism preservable
│
├─ ② Meta layer (director / matchmaking) ──── partial determinism trade-off
│
├─ ③ Offline (design / tuning) ────────────── determinism irrelevant
│
└─ ④ Player aid (ghosts / hints) ─────────── determinism preservable
```

**Echo's policy**: ① YES (FSM + Behavior Trees), ③ YES (offline tuning), ④ YES (replay ghosts), ② LIMITED (mob spawn director only — never boss patterns).

## Zone ①: Runtime Game AI (Verified Patterns)

| Pattern | Verified In | Determinism |
|---|---|---|
| **Behavior Tree** | Halo (2001), BioShock, Splinter Cell | ✅ same world state → same node selected |
| **Finite State Machine** | Hollow Knight, Cuphead bosses, Mega Man | ✅ closed set of transitions |
| **GOAP** (Goal-Oriented Action Planning) | F.E.A.R. (2005), Tomb Raider | ✅ same goals + same state → same plan |
| **Utility AI** | The Sims, Red Dead Redemption 2 | ✅ deterministic scoring function |
| **HTN** (Hierarchical Task Network) | Killzone 2, Horizon Zero Dawn | ✅ |

Core principle: behavior emerges from a function of (world state). No randomness, no time-based drift, no learning. Looks dynamic; provably deterministic.

> **Echo applicability**: Cuphead-style FSM + Behavior Tree per boss. Phases as states, attack patterns as nodes, transitions on HP %. Direct fit (Source: [[Boss Two Phase Design]]).

## Zone ②: Meta Layer (Trade-Offs)

| Pattern | Verified In | Determinism Cost |
|---|---|---|
| **AI Director** | Left 4 Dead 1·2 | Spawn timing dynamic — but each enemy still deterministic |
| **Nemesis System** | Shadow of Mordor (2014), War | Per-orc deterministic; population evolves |
| **Drivatar (cloud-trained AI)** | Forza Horizon | Asynchronous learning; runtime fixed |
| **Crowd Simulation** | Hitman, Watch Dogs | Seedable → deterministic given seed |

**Trade-off rule**: AI may decide *what* spawns or *who* shows up, but the unit of learning (boss patterns, weapon behaviors, player verbs) must remain frozen.

> **Echo applicability**: Nemesis is incompatible — bosses must be exactly the same on every encounter for learning to stick. Mob wave variety (within fixed AI behavior) is acceptable, scoped only to non-boss content.

## Zone ③: Offline AI (Largest ROI)

Determinism is irrelevant here — these are dev-time tools.

| Pattern | Verified In | Output |
|---|---|---|
| **Death Heatmap Analysis** | Halo 3, Battlefield series | Where players die → level tuning |
| **A/B Pattern Testing** | Candy Crush, Hearthstone | Which patterns produce best learning curves |
| **AI Playtest Bots** | DeepMind StarCraft (AlphaStar), OpenAI Dota (Five) | Auto-validate balance |
| **PCG Pattern Candidates** | Spelunky 2, No Man's Sky | AI generates 100, designer picks 5 |
| **AI-Assisted Pattern Design** | Promethean AI, modern ML game tools | Boss pattern variants for designer review |

> **Echo applicability**: The highest-leverage zone for a solo developer. Use bots to validate boss difficulty (Source: [[AI Playtest Bot For Boss Validation]]). Use death analytics to identify unfair patterns. AI-assisted pattern generation can stage candidates that the designer accepts or rejects.

## Zone ④: Player-Aid AI (Echo Sweet Spot)

| Pattern | Verified In | Determinism |
|---|---|---|
| **Ghost Replay** | Trackmania, Mario Kart, Super Meat Boy, Celeste | ✅ deterministic playback |
| **Best-Run Overlay** | Hollow Knight (speedrun mods), N++ | ✅ |
| **Death-Pattern Hint System** | Resident Evil 4 Remake (Mercenaries) | ✅ |
| **Adaptive Tutorial Triggers** | Half-Life 2 (player tracking) | ✅ |
| **Asynchronous Player Messages / Phantoms** | Dark Souls, Elden Ring | ✅ async, no runtime mutation |

> **Echo synergy**: 9-frame rewind + ghost overlay is a natural pairing. The player's previous best attempt can replay alongside the current run, reinforcing the "body memory" fantasy (Source: [[Time Manipulation Run and Gun]], [[Solo Contra 2026 Concept]]).

## Verified Reference Cases

### Cuphead (StudioMDHR, 2017) — FSM Boss Canon
All bosses run deterministic FSM. Phase order fixed. Zero RNG. Direct architectural model for Echo (Source: [[Cuphead]]).

### F.E.A.R. (Monolith, 2005) — GOAP
Soldiers plan dynamically (find cover → flank → fire) yet produce identical plans for identical states. The illusion of dynamic AI without breaking learnability. Useful reference for Echo mob AI.

### Trackmania (Nadeo, 2003+) — Ghost Canon
Personal best, friend, and world-record ghosts run alongside the player. Deterministic replay; learning amplifier. Direct candidate for Echo boss-replay overlay.

### Shadow of Mordor (Monolith, 2014) — Nemesis
Per-orc deterministic memory, dynamic narrative. **Not for Echo** — bosses must be reproducible, not personal.

### Left 4 Dead (Valve, 2008) — AI Director
Director adjusts spawn waves; never modifies zombie behavior. Establishes the boundary: dynamic *quantity*, deterministic *unit*. Partial fit for Echo mob waves only.

## Echo Priority Recommendations

### 🟢 Recommended (Tier 1)
1. **FSM + Behavior Tree per boss** — Cuphead model.
2. **Ghost replay system** — overlay personal best on retries.
3. **Developer death heatmap analytics** — identify unfair patterns from playtest data.

### 🟡 Evaluate (Tier 2)
4. **AI playtest bot** — automated balance check ([[AI Playtest Bot For Boss Validation]]).
5. **Mob wave director (light)** — vary spawn order within fixed AI; boss patterns untouched.
6. **AI-assisted pattern candidate generation** — designer-curated.

### 🔴 Banned (Echo Identity Conflict)
7. ❌ Runtime adaptive difficulty — breaks determinism, invalidates learning.
8. ❌ Random boss patterns — destroys core value.
9. ❌ ML-driven enemy behavior with online learning — same boss behaves differently per session.
10. ❌ Nemesis-style boss personalization — bosses must be uniform across players for community speedrun / shared-strategy value.

## The Golden Rule

> **AI is the designer's tool or the player's mirror — never the game's ruler.**

- Design time: AI generates, analyzes, tunes (offline OK).
- Runtime game loop: deterministic behavior systems (FSM, BT, GOAP).
- Player learning aid: deterministic replay (ghosts, hints).
- ❌ AI shaping the learning target itself, at runtime: forbidden.

## Anti-Patterns (Determinism Kills)

| Anti-Pattern | Why Banned |
|---|---|
| RNG in enemy behavior | Pattern unlearnable |
| Dynamic difficulty mid-fight | Pattern shifts under player |
| Procedural room generation | Nothing to memorize |
| Variable input buffer | "Why didn't that work?" emerges |
| Frame-drop-induced logic drift | Determinism leaks |
| ML model loaded at runtime that adapts to player | Boss is no longer a fixed exam |

## Open Questions

- **Echo Tier 1**: Should the ghost replay overlay be opt-in or always-on after first death?
- **Echo Tier 2**: Is a mob wave director worth implementing, or does fully-fixed mob spawning serve the deterministic identity better?
- **Echo Tier 3**: Could AI-generated boss pattern candidates accelerate Tier 3 content output without breaking the 2D-side-scrolling / one-axis-per-entry rule (Source: [[Contra Per Entry Mechanic Matrix]])?

## Sources

- DeepMind, "AlphaStar: Grandmaster level in StarCraft II" (2019).
- OpenAI, "Dota 2 with Large Scale Deep Reinforcement Learning" (2019).
- Monolith Productions, GDC talk on F.E.A.R. GOAP (2006).
- Valve, GDC talks on L4D AI Director.
