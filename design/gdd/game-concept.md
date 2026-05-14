# Game Concept: Echo

*Created: 2026-05-08*
*Status: Approved (lean design-review 2026-05-14; concept copy aligned to ADR-0002 restore-depth contract)*
*Wiki source: [[Solo Contra 2026 Concept]]*

---

## Elevator Pitch

> A side-scrolling run-and-gun where you play as an operative in a near-future megacity who carries a *revoke* token that restores a safe pre-death position from a 1.5-second lookback window, converting the frustration of one-hit death into the catharsis of "this time I'll survive." The collage visuals make the first impression.

10-second test: A first-time listener immediately understands what the game is — side-scrolling action + post-death *revoke* token + collage sci-fi.

---

## Core Identity

| Aspect | Detail |
|---|---|
| **Genre** | Run-and-Gun (2D side-scrolling) + time rewind mechanic |
| **Platform** | PC Steam (single platform) |
| **Target Audience** | Achievers — Hotline Miami / Katana Zero / Cuphead fanbase (see Player Profile below) |
| **Player Count** | Single-player (co-op explicitly excluded — Anti-Pillar #1) |
| **Session Length** | 10–30 minutes (1 stage 5 min + retries + mastery) |
| **Monetization** | Premium ($9.99–$14.99 assumed, at Tier 3 launch) |
| **Estimated Scope** | Tier 1 Prototype: Small (4–6 weeks, solo) → Tier 3 Full Vision: Large (~16 months, solo) |
| **Comparable Titles** | Katana Zero (2019, 500K+), Hotline Miami (2012, 5M+), Contra: Operation Galuga (2024) |

---

## Core Fantasy

> "You are an operative who can *revoke* a single moment in time. You carry a 'revoke' token that instantly restores you to a safe position just before death within a 1.5-second lookback window. Death is not the end — it is *learning* — and each time you break one of the enemy's patterns, that *revoke* makes you a little faster, a little smarter."

What players can't get from other games: the immediate frustration of one-hit death converts into the *immediate recovery* of a safe pre-death restore. The mechanic identity shifts from punishment to learning tool. (Applying Solo Contra 2026 Concept Q4 conclusion)

---

## Unique Hook

> "Like Contra/Katana Zero, AND ALSO you carry a 'revoke' token that instantly restores a safe pre-death position within a 1.5-second lookback window, and clearing a boss recharges your tokens."

Hook validation:
- ✅ One sentence — pass
- ✅ Genuinely novel — Katana Zero uses *pre-death* time manipulation (Will); Echo uses a *post-death* safe-position *revoke* (different mechanic identity)
- ✅ Directly tied to core fantasy — the mechanism of the punishment→learning conversion
- ✅ Gameplay impact — token resource management creates strategic decisions (not a visual effect)
- ✅ Mechanic accuracy — *restore offset* locked at 9 frames (0.15s pre-death). "1.5-second lookback" is the *capture window*; *restore depth* is 0.15s. ADR-0002 RESTORE_OFFSET_FRAMES const is single source of truth (Round 1 design-review correction — original "1-second rewind" copy contradicts the 0.15s mechanic and has been rewritten).

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics

| Aesthetic | Priority | How We Deliver It |
|---|---|---|
| **Sensation** | 2 | Collage visuals + gunshot impact (screenshake · hitfreeze) + time rewind shader (reverse-playback color inversion) |
| **Fantasy** | 5 | Near-future sci-fi megacity + corrupt corporate army |
| **Narrative** | 7 | Environmental storytelling only (Anti-Pillar — no cutscenes) |
| **Challenge** | **1** (Primary) | Deterministic patterns + one-hit death + token resource management |
| **Fellowship** | N/A | Co-op permanently excluded (Anti-Pillar #1) |
| **Discovery** | 4 | Boss pattern discovery · weapon pickup locations |
| **Expression** | 6 | Weapon choice · token usage timing |
| **Submission** | 8 | Intentionally low — Echo is a *tension* game |

### Key Dynamics
- Death → revoke restore → pattern recognition → next attempt → success cycle repeats voluntarily
- Low token count increases caution; token recharge after boss kill = "one more try" impulse
- Collage visual moments prompt spontaneous screenshot sharing

### Core Mechanics
1. **Side-scrolling shooting** — 8-direction aim, jump + shoot simultaneously
2. **Time rewind token** — instantly restores safe position (0.15s pre-death) from within 1.5-second lookback window (starting tokens 3, recharged on boss kill, max_tokens=5 cap)
3. **Weapon pickups** — base rifle + 1–3 pickup weapons (Tier 1: 1 only)

---

## Player Motivation Profile

### Primary Psychological Needs

| Need | How Echo Satisfies It | Strength |
|---|---|---|
| **Autonomy** | Choose when to use tokens, free weapon usage order | Supporting |
| **Competence** | Pattern mastery + explicit death→recovery cycle | **Core** |
| **Relatedness** | Solo game — indirect sharing via Discord/Steam community | Minimal |

### Player Type Appeal (Bartle)

- [x] **Achievers** (Primary) — pattern clearing, deathless challenges, time attack
- [ ] Explorers — determinism + linear = weak
- [ ] Socializers — no co-op
- [x] **Killers** (Secondary, light) — boss impact · shooting catharsis

### Flow State Design

- **Onboarding**: Force shoot + jump + 1 time rewind activation within 30 seconds. 0 lines of text tutorial (Pillar 4 5-minute rule).
- **Difficulty scaling**: Add 1 pattern per boss phase, decrease token recharge frequency
- **Feedback clarity**: On time rewind activation — screen shader recognizable within 0.5 seconds (fullscreen inversion/glitch visible during frames 1–18, then clear for the i-frame readability tail) + token count top-left intuitive UI
- **Recovery from failure**: <1 second restart (Pillar 1 non-negotiable). Death = immediate safe pre-death restore from the 1.5-second lookback window + token -1, or checkpoint if no token remains.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Move (2D jump · run) → spot enemy → shoot → dodge enemy pattern OR activate time rewind → survive → enter next screen.

### Short-Term (5 minutes)
Clear 1 stage. Early enemy waves → mid jump challenge → mini-boss or weapon pickup → next checkpoint.

### Session-Level (30–120 minutes)
- Tier 1 Prototype: repeat 1 stage + deathless challenge. ~30 min.
- Tier 2 MVP: 3 stages + 3 bosses. 60–90 min.
- Tier 3 Full: 5 stages + 5–6 bosses. 120–180 min per run.

### Long-Term Progression (Tier 3)
- Deathless clear → Hard mode → weapon challenge (specific weapon only) → challenge mode (token 0)
- Collage gallery unlock (bonus)

### Retention Hooks
- **Curiosity**: What's the next boss pattern? New weapon pickup?
- **Investment**: Deathless challenge run (restart from beginning on death)
- **Social**: Discord/Steam screenshot sharing (collage visuals)
- **Mastery**: Time attack leaderboard (Tier 3)

---

## Game Pillars (5 — Locked 2026-05-08)

### Pillar 1: Time Rewind is a *learning tool, not a punishment*
Convert the immediate frustration of one-hit death into the immediate recovery of a token rewind.

*Design test*: When "faster restart" vs "safer restart" conflict after death → choose **faster** (sub-1-second restart is non-negotiable).

### Pillar 2: Deterministic Patterns — luck is the enemy
Every death must be *the player's mistake*. Randomness must never be the cause of death.

*Design test*: When adding *randomness* to enemy behavior vs *adding a pattern* conflict → choose **the pattern**.

### Pillar 3: Collage is the first impression — screenshot = marketing
A distinctive visual signature is the #1 asset in indie marketing (Cuphead 6M validated).

*Design test*: When gameplay clarity vs visual signature conflict → **adjust collage for clarity** (preserve both). Never sacrifice the visual.

### Pillar 4: 5-Minute Rule — immediate core loop
The player must experience the *core fun* within 5 minutes of starting the game.

*Design test*: When cutscenes, tutorials, or meta systems delay core access beyond 5 minutes → **cut the delay**.

### Pillar 5: First game = *small success > big ambition*
A shippable small thing is more valuable than an unshippable large thing.

*Design test*: When "cool but hard" vs "small but shippable" conflict → choose **shippable**. Build the full vision in the future.

### Anti-Pillars (6 — explicit NOTs)

- **NOT co-op mode** — solo + first-game QA explosion. Permanently excluded.
- **NOT 5+ stages** — prototype 1, MVP 3, full 5. Absolutely no 8+.
- **NOT full 6-weapon catalog** — prototype 1, MVP 3–4, full 4–5. Not pursuing Contra M/F/L/S/R/B.
- **NOT original music full tracks** — prototype placeholder/CC0. Outsource at launch.
- **NOT mobile/console simultaneous launch** — PC Steam only (Godot 4 export).
- **NOT full input remapping / multilanguage options** — prototype English + keyboard/pad basics only. (Tier 3: Korean/English + full remapping)

---

## Inspiration and References

| Reference | What We Take | What We Differ | Why It Matters |
|---|---|---|---|
| **Contra** (1987–) | One-hit death + weapon pickups + deterministic patterns + side-scrolling | No co-op, time rewind added, jungle→sci-fi | Core validation (cumulative 4M by 1996) |
| **Katana Zero** (2019) | Time mechanic + one-hit + instant restart solo benchmark | Will uses *pre-death* time manipulation → Echo uses *post-death* safe-position revoke | Solo 500K validated |
| **Hotline Miami** (2012) | Instant restart + deterministic patterns + "unfair" avoidance | Top-down → side-scrolling, psycho → sci-fi | 5M+ validated |
| **Cuphead** (2017) | Boss-focused + signature visual marketing | 1930s hand-drawn → collage sci-fi | 6M validated, visual signature value |

**Non-game inspirations**:
- Monty Python cutout animation — collage tone
- Hannah Höch 1920s Dada collage — composite aesthetic
- Blade Runner / Akira / Ghost in the Shell — megacity mood, color palette

---

## Target Player Profile

| Attribute | Detail |
|---|---|
| **Age range** | 20–40 |
| **Gaming experience** | Mid-core ~ Hardcore (comfortable with one-hit death) |
| **Time availability** | Weekday 30 min + weekend 1–2 hours |
| **Platform preference** | PC Steam (mouse+keyboard or gamepad) |
| **Current games** | Hotline Miami, Katana Zero, Cuphead, Pizza Tower |
| **What they want** | "Hard but fair" action + signature visuals + solo completeness |
| **Dealbreakers** | Random patterns, long restart wait (>2 sec), forced co-op, F2P feel |

---

## Technical Considerations

| Consideration | Assessment |
|---|---|
| **Recommended Engine** | **Godot 4.6** — project default (`docs/engine-reference/godot/VERSION.md`). Strong 2D, GDScript first-game friendly, free, `@abstract` 4.5+ available |
| **Key Technical Challenges** | (1) Time rewind — state snapshot vs input replay (unverified in Godot 4) / (2) Collage shader + cutout compositing / (3) Deterministic enemy pattern design tooling |
| **Art Style** | 2D collage (magazine cutout + photo texture + hand-drawn line mix) |
| **Art Pipeline Complexity** | Medium — photo source (stock/AI/photography) decision required, compositing pipeline setup |
| **Audio Needs** | Tier 1: placeholder/CC0 / Tier 2–3: outsource or self-compose |
| **Networking** | None |
| **Content Volume** | Tier 1: 1 stage / Tier 2: 3 stages + 3 bosses / Tier 3: 5 stages + 5–6 bosses + 4–5 weapons |
| **Procedural Systems** | None — determinism is the core (Pillar 2) |

---

## Risks and Open Questions

### Design Risks
- **R-D1**: Time rewind *over-relieves* the tension of one-hit death, losing core catharsis. → Balance via token resource management (start 3, +1 on boss kill) + Hard mode (token 0)
- **R-D2**: Collage visuals damage gameplay clarity — enemy/player silhouette distinction required. → Guard with P3 design test (distinguishable in 0.2-second glance?)

### Technical Risks
- **R-T1**: Time rewind Godot 4 implementation pattern undecided (snapshot vs replay). → Tier 1 Week 1 prototype both patterns + write ADR
- **R-T2**: Whether full-quality collage visuals are achievable in weeks. → Limit to 1 scene in Tier 1

### Market Risks
- **R-M1**: Indie run-and-gun self-publishing ceiling 100K–200K (wiki [[Indie Self Publishing Run and Gun]]). Marketing partner essential for 500K+
- **R-M2**: Hotline Miami / Katana Zero fanbase already satisfied market. Differentiable only via collage+sci-fi?

### Scope Risks
- **R-S1**: First game + weeks scope may fail to complete even Tier 1. → Prevented by 6 anti-pillars + explicit 3-tier definition
- **R-S2**: Probability of reaching 16-month full vision. → Enter only after passing Tier 1 and Tier 2 (gate)

### Open Questions
- **Q1**: Time rewind applies to enemies + bullets simultaneously vs player only? → Prototype both in Tier 1, compare in playtest
- **Q2**: Collage photo source — stock/AI/photography? → Decide Tier 1 Week 1 (IP/license comparison)
- **Q3**: Easy toggle vs slider? → Decide in Tier 2 (prototype is Hard-only single difficulty)
- **Q4**: Godot 4 time rewind — snapshot vs replay? → Tier 1 Week 1 ADR
- **Q5**: ECHO gender — keep codename vs specify? → Decide after Tier 1 concept art
- **Q6**: Sigma Unit survivor subplot — include in Tier 3? → Decide after Tier 2 gate

**Resolved**: Story tone = dystopian serious (Blade Runner / Ghost in the Shell), [[Echo Story Spine]] adopted. ECHO vs VEIL — see Story Spine section above this GDD.

---

## MVP Definition

**Core hypothesis**: "One-hit death + post-death revoke token mechanic creates the catharsis of deterministic pattern learning, and collage visuals make the first impression within 5 seconds."

### Required for MVP (Tier 1 Prototype, 4–6 weeks)
1. Player character + 8-direction shooting + jump
2. Time rewind token system (1.5-second lookback, 0.15s safe pre-death restore depth, 3 starting tokens, +1 on boss kill)
3. Collage visuals 1 scene (megacity rooftop — 1 main marketing image)
4. 3 deterministic enemy types (drone · security bot · mini-boss)
5. 1 stage slice (clearable in 5 minutes)
6. 1 weapon (base rifle)
7. Placeholder audio (CC0)

### Explicitly NOT in MVP (defer)
- Co-op (permanently excluded)
- 5+ stages (Tier 1 has 1)
- 6-weapon catalog (Tier 1 has 1)
- Original music
- Mobile/console launch
- Input remapping / multilanguage
- Full menu/HUD design

### Scope Tiers

| Tier | Content | Features | Timeline |
|---|---|---|---|
| **Tier 1 Prototype** | 1 stage slice, 1 weapon, 3 enemies | Time rewind + shooting + collage 1 scene + placeholder audio | **4–6 weeks** |
| **Tier 2 MVP / Vertical Slice** | 3 stages, 3 weapons, 3 bosses | + Full collage visuals + Easy toggle + menu | ~6 months cumulative |
| **Tier 3 Full Vision** | 5 stages, 4–5 weapons, 5–6 bosses | + Full sound + accessibility options + Korean/English | ~16 months cumulative |

---

## Story Spine (Locked 2026-05-08)

> Full scenario in `wiki/concepts/Echo Story Spine.md` (Contra: Shattered Soldier 2002 + MI Final Reckoning 2025 motif merge).

**Logline**: "When AI calculates the future, ECHO reverses the past."

**World**: 2038 NEXUS megacity. ARCA Corporation's AI 'VEIL' manages every system in the city. The protagonist is the sole survivor who witnessed VEIL's self-awakening during the Sigma Unit operation 3 years ago.

**Protagonist**: Codename **ECHO** — carries a time rewind prototype (military-grade). Time rewind tokens = device battery = human irrationality = outside VEIL's model = the only blind spot (mechanic↔fiction coherence).

**Antagonist**: VEIL (AI) + autonomous army under command (drones · security bots · corporate agents). Digital infinite power, analog force.

**5 Stage Arc** (Tier 3 Full Vision):
1. **Return** — megacity rooftop (beginning of escape)
2. **Truth** — data center (VEIL core fragment)
3. **Pursuit** — maglev (escape/chase)
4. **Confrontation** — corporate headquarters (Triumvirate defeated)
5. **Resolution** — orbital elevator (final seal)

**Tier 1 intro — 5 lines (displayed exactly as-is at game start)**:
```
2038. NEXUS — a perfectly optimized city.
ARCA Corporation's AI, VEIL, manages everything.
Three years ago, I watched it wake up. I was the only one who survived.
Now VEIL knows I'm coming. Survival probability: 0.003%.
VEIL calculates everything. Except one thing — I can rewind time.
```

**IP avoidance** ([[IP Avoidance For Game Clones]]): Contra = mechanic borrowed, world not / MI = motif borrowed, proper nouns not. NEXUS · ARCA · VEIL · ECHO · Sigma Unit are all original.

---

## Visual Identity Anchor

> This section seeds the visual decisions from [[Solo Contra 2026 Concept]]; `/art-bible` expands to full visual spec.

**Direction**: **Collage Sci-Fi** — magazine cutout + photo texture + hand-drawn line mix

**One-line visual rule**: "*Every* screen in this game looks like 1990s magazine cutouts collaged with 2030s megacity photography."

**Supporting principles (3)**:

1. **Clarity-first collage** — characters and enemies have simple silhouettes + clear color contrast. Collage texture is emphasized on backgrounds, bosses, and UI.
   *Test*: Can player and enemy be distinguished in a 0.2-second glance?

2. **Photo + drawing = always both** — photo only = falls into realism, drawing only = resembles Pizza Tower. Both together = Echo's signature.
   *Test*: Does a single screenshot show both photo and drawing?

3. **Time rewind = color inversion + glitch** — on mechanic activation, the screen "plays in reverse" with colors inverting to cyan/magenta, recognizable within 0.5 seconds; fullscreen inversion/glitch is visible during frames 1–18, then clears for the i-frame readability tail. Collage textures decompose into glitch patterns.
   *Test*: Is a time rewind activation visually recognizable within 0.5 seconds?

**Color philosophy**: Megacity = concrete gray + neon cyan + advertisement magenta. Collage cutouts = 1990s magazine vintage yellow/brown. Time rewind = color-inverted cyan/magenta.

---

## Next Steps

- [x] `/setup-engine` — Godot 4.6 formally registered in `.claude/docs/technical-preferences.md`
- [x] `/art-bible` — full collage sci-fi visual spec exists at `design/art/art-bible.md`
- [x] `/design-review design/gdd/game-concept.md --depth lean` — APPROVED 2026-05-14 after stale 1-second-copy cleanup
- [x] `/map-systems` — systems index created at `design/gdd/systems-index.md`
- [x] `/design-system time-rewind` — Time Rewind GDD approved at `design/gdd/time-rewind.md`
- [x] `/architecture-decision` — three Time Rewind ADRs accepted in `docs/architecture/`
- [ ] `/prototype time-rewind` — Tier 1 Week 1 prototyping
- [ ] `/playtest-report` — Tier 1 Week 4–6 validation
