---
type: meta
title: "Lint Report 2026-05-12"
created: 2026-05-12
updated: 2026-05-12
tags: [meta, lint]
status: stable
---

# Lint Report: 2026-05-12

## Summary

- Pages scanned: 167
- Issues found: 75 (9 critical, 38 warnings, 28 suggestions)
- DragonScale Address Validation: skipped (not configured)
- Semantic Tiling: skipped (not configured)
- Auto-fixed: 0
- Needs review: 75

---

## Critical (must fix)

### C-1: Dead wikilinks — 32 links across multiple pages

**Group A — Missing entity/game pages:**

| Dead Link | Referenced In |
|---|---|
| `[[Hades]]` | `Research Cross-Genre Systems For Run and Gun.md` |
| `[[Mark of the Ninja]]` | `Stealth Information Visualization.md`, `Research Cross-Genre Systems For Run and Gun.md` |
| `[[Enter the Gungeon]]` | `Research 8-Way Aim Usability For Run-and-Gun.md` |
| `[[Returnal]]` | `Aim Assist Accessibility Tiers.md`, `Research 8-Way Aim Usability For Run-and-Gun.md` |
| `[[Nuclear Throne]]` | `Research 8-Way Aim Usability For Run-and-Gun.md` |
| `[[Max Payne]]` | `Research Cross-Genre Systems For Run and Gun.md` |
| `[[Contra 4]]` | `Contra III The Alien Wars.md` |
| `[[Furi (The Game Bakers)]]` | `Research Boss Rush Development Base.md` |
| `[[Succubus-With-A-Gun]]` | `Research Run and Gun Development Base.md` |
| `[[Triumvirate]]` | `Contra Shattered Soldier Story Source.md` |

**Group B — Missing Wikipedia source pages:**

| Dead Link | Referenced In |
|---|---|
| `[[Wikipedia Broforce]]` | `Research Run and Gun Innovative Systems.md` |
| `[[Wikipedia Cartoon Wars]]` | `Side Scrolling Tug Of War Defense.md`, `Cartoon Wars.md`, `Research Battle Cats Subgenre.md` |
| `[[Wikipedia Katana Zero]]` | `Followup Modern Acceptance And Indie RnG Threshold.md` |
| `[[Wikipedia Pizza Tower]]` | `Followup Modern Acceptance And Indie RnG Threshold.md` |
| `[[Wikipedia Vampire Survivors]]` | `Followup Modern Acceptance And Indie RnG Threshold.md` |

**Group C — Missing reference/guide source pages:**

| Dead Link | Referenced In |
|---|---|
| `[[Boss Rush Design Articles Game Developer]]` | `Research Boss Rush Development Base.md`, `Boss Rush Design Fundamentals.md` |
| `[[A NEAT Approach to Wave Generation]]` | `Wave Pacing.md` |
| `[[Dynamic Difficulty Adjustment]]` | `Wave Pacing.md` |
| `[[Dynamic Difficulty Adjustment in Tower Defence]]` | `Wave Pacing.md` |
| `[[Frontline Protocol Meta Progression]]` | `Meta Progression.md` |
| `[[Business of Apps Mobile Retention]]` | `Long Tail Mobile Live Service.md` |
| `[[ResearchGate Tower Defense Revenue Analysis]]` | `Grow Castle.md`, `Research Battle Cats Subgenre.md`, `Run and Gun Level Design Patterns.md` |
| `[[Bloons TD Wikipedia]]` | `Bloons TD.md` |
| `[[Bloons Wiki Towers]]` | `Upgrade Path System.md`, `Bloons TD.md` |
| `[[BlueStacks Battle Cats Guide]]` | `Auto Deploy Unit System.md` |
| `[[GachaZone Battle Cats Guide]]` | `Gacha Unit Acquisition.md` |
| `[[Google Play Grow Castle]]` | `Grow Castle.md`, `Research Battle Cats Subgenre.md` |
| `[[PocketGamer Cartoon Wars 5M]]` | `Cartoon Wars.md` |
| `[[Random Dice App Store]]` | `Merge Dice Mechanic.md`, `Random Dice.md`, `Research Lane Defense Game Systems.md` |
| `[[Random Dice BlueStacks]]` | `Merge Dice Mechanic.md`, `Random Dice.md` |
| `[[Astro Battlers TD]]` | `Lane Defense.md` |

**Group D — Case mismatch (breaks on case-sensitive filesystems):**

| Dead Link | Correct File | Referenced In |
|---|---|---|
| `[[Run And Gun Base Systems]]` | `Run and Gun Base Systems.md` | `Aim Lock Modifier Pattern.md` |

Fix: Change to `[[Run and Gun Base Systems]]` in `Aim Lock Modifier Pattern.md`.

---

### C-2: Hub files missing required frontmatter fields

| File | Missing Fields |
|---|---|
| `wiki/hot.md` | `type`, `status`, `created`, `tags` |
| `wiki/log.md` | `type`, `status` |
| `wiki/index.md` | `type`, `created`, `tags` |

---

## Warnings (should fix)

### W-1: Missing `type:` field — 38 pages

**New pages (this session) missing `type: concept`:**
- `Boss Rush Design Fundamentals.md`
- `Boss Identity Framework.md`
- `Shmup Boss Design Factors.md`
- `Boss Rush Content Sizing.md`
- `Run and Gun Enemy AI Archetypes.md`
- `Run and Gun Player Character Architecture.md`
- `Run and Gun Bullet System Pattern.md`
- `Run and Gun Level Design Patterns.md`

**Source pages missing `type: source`:**
- `Research CCGS Fork Landscape.md`, `Research CCGS Implementation Gap Full Stack.md`, `Research Steam Low Competition Genre Analysis.md`, `CCGS Workflow Guide.md`, `Research Boss Rush GitHub Baseline Repos.md`, `Research Steam Indie Short Dev Genre Landscape.md`, `Research Steam 2026 Genre Competition Update.md`, `Research Godot 4.6 Ecosystem Toolchain.md`

**Older concept pages (29 pages) missing `type: concept`:** `CCGS Framework.md`, `CCGS Subagent Tier Architecture.md`, `Abstract Base Class Pattern.md`, `Boss Two Phase Design.md`, `Contra Weapon System.md`, `Echo Story Spine.md`, `Cooperative Run and Gun Design.md`, `Run and Gun Success Pattern Matrix.md`, `Hit Rate Grading System.md`, `Pink Parry System.md`, `Indie Self Publishing Run and Gun.md`, `Modern Difficulty Accessibility.md`, `Brownfield Project Onboarding.md`, `Stealth Information Visualization.md`, `Roguelite Metaprogression For Run and Gun.md`, `Time Manipulation Run and Gun.md`, `Contra Per Entry Mechanic Matrix.md`, `Boss Rush Niche Genre Opportunity.md`, `Boss Rush Godot Implementation Pattern.md`, `Co-op Social Horror Genre Pattern.md`, `Chaotic Co-op Sub-genre Pattern.md`, `Bullet Heaven Survivors-like Dev Pattern.md`, `Job Simulator Blue Collar Genre Pattern.md`, `Steam Genre Competition Density Matrix.md`, `Steam Indie Genre Revenue Matrix 2024-2025.md`, `Indie Game Publishing Pipeline.md`, `Indie Game Community Platform Stack.md`, `Godot Analytics Stack.md`, `Godot Audio Middleware Decision.md`, `Godot Art Pipeline Tools.md`, `Godot CI CD Pipeline Pattern.md`, `CCGS 7-Phase Development Pipeline.md`, `CCGS Story Lifecycle.md`, `CCGS Team Orchestration Skills.md`, `CCGS Scaffolder Scope Boundary.md`, `CCGS Chinese Localization Forks.md`, `CCGS Codex Port Pattern.md`.

---

### W-2: Missing `status:` field — ~100 pages

**New pages (this session) missing `status: stable`:**
- All 8 new concept pages (see W-1 list)
- 6 new source pages: `GDC Boss Battle Design Talks.md`, `Boss Rush Jam 2025.md`, `Godot 4 Boss Tutorial Resources.md`, `Godot 4 Run and Gun GitHub Repos.md`, `Godot 4 Run and Gun Tutorial Resources.md`, `Run and Gun Dev Community Resources.md`

~88 older pages also lack `status:` — a bulk `status: stable` sweep is appropriate.

---

### W-3: Missing `created:` field — 8 pages

`Game Developer Tower Defense Rules.md`, `XAG 107 Aim Assist Guidelines.md`, `Metal Slug IP Avoidance Guide.md`, `Wikipedia Plants vs Zombies.md`, `Game Developer Thumbstick Deadzones.md`, `Tower Defense Design Guide.md`, `hot.md`, `index.md`

---

### W-4: Missing `updated:` field — 6 source pages

`Game Developer Tower Defense Rules.md`, `XAG 107 Aim Assist Guidelines.md`, `Metal Slug IP Avoidance Guide.md`, `Wikipedia Plants vs Zombies.md`, `Tower Defense Design Guide.md`, `Game Developer Thumbstick Deadzones.md`

---

### W-5: Large pages (>300 lines)

| Lines | Page |
|---|---|
| 507 | `log.md` — consider archiving old entries to `wiki/folds/` |
| 401 | `Research Run and Gun Genre.md` |
| 377 | `Non-Boss Bot Validation Suites.md` |
| 331 | `Determinism Verification Replay Diff.md` |
| 319 | `Death Heatmap Analytics.md` |
| 316 | `Bot Validation Pipeline Architecture.md` |
| 309 | `Echo Story Spine.md` |
| 301 | `Ghost Replay System For Time Rewind.md` |

---

### W-6: Empty sections in hub files

| File | Empty Section |
|---|---|
| `wiki/hot.md` | `## TL;DR For my-game` |
| `wiki/hot.md` | `## Open Questions` |

Note: `index.md` `## Concepts` and `## Entities` headings appear empty but have content under `###` sub-headings — likely false positives.

---

### W-7: `folds/` folder referenced but empty

`index.md` describes `folds/` as auto-generated rollup location, but no files exist there. With `log.md` at 507 lines, archival is overdue.

---

## Suggestions

### S-1: Missing pages for heavily cited entities

| Missing Page | Cited In |
|---|---|
| `[[Furi (The Game Bakers)]]` | 4 new boss rush pages — most urgent; canonical boss rush reference |
| `[[Hades]]` | 3 pages — key boss design reference |
| `[[Mark of the Ninja]]` | 2 pages |
| `[[Returnal]]` | 2 pages |
| `[[Enter the Gungeon]]` | 1 page |

---

### S-2: Missing source page for Boss Rush articles

`[[Boss Rush Design Articles Game Developer]]` is cited in `Research Boss Rush Development Base.md` frontmatter (sources list) and body (4 citations) and in `Boss Rush Design Fundamentals.md`. Create `wiki/sources/Boss Rush Design Articles Game Developer.md` cataloging the 7 gamedeveloper.com articles already listed inline in `GDC Boss Battle Design Talks.md`.

---

### S-3: Cross-reference gaps in new pages

- `Boss Rush Content Sizing.md` → add backlink to `[[Boss Rush Niche Genre Opportunity]]`
- `Shmup Boss Design Factors.md` → add `[[GDC Boss Battle Design Talks]]` to Related Pages
- `Run and Gun Level Design Patterns.md` → replace `[[ResearchGate Tower Defense Revenue Analysis]]` dead link with inline citation

---

### S-4: Wikilinks with `.md` extension

Some pages use `[[hot.md]]` and `[[log.md]]` (non-standard). Change to `[[hot]]` and `[[log]]`.

---

### S-5: `index.md ## By Tag` — #run-and-gun tag missing 4 new pages

Add to `#run-and-gun` tag entry:
- `[[Run and Gun Enemy AI Archetypes]]`
- `[[Run and Gun Player Character Architecture]]`
- `[[Run and Gun Bullet System Pattern]]`
- `[[Run and Gun Level Design Patterns]]`

---

## 16 New Pages Audit (this session)

| Page | type | status | Dead Links | Action |
|---|---|---|---|---|
| `Research Boss Rush Development Base` | synthesis ✓ | stable ✓ | `[[Boss Rush Design Articles Game Developer]]`, `[[Furi (The Game Bakers)]]` | Create source + entity pages |
| `Boss Rush Design Fundamentals` | MISSING | MISSING | none | Add `type: concept`, `status: stable` |
| `Boss Identity Framework` | MISSING | MISSING | none | Add `type: concept`, `status: stable` |
| `Shmup Boss Design Factors` | MISSING | MISSING | none | Add `type: concept`, `status: stable` |
| `Boss Rush Content Sizing` | MISSING | MISSING | none | Add `type: concept`, `status: stable`; add backlink |
| `GDC Boss Battle Design Talks` | source ✓ | MISSING | none | Add `status: stable` |
| `Boss Rush Jam 2025` | source ✓ | MISSING | none | Add `status: stable` |
| `Godot 4 Boss Tutorial Resources` | source ✓ | MISSING | none | Add `status: stable` |
| `Research Run and Gun Development Base` | synthesis ✓ | stable ✓ | `[[Succubus-With-A-Gun]]` | Create entity page or inline cite |
| `Run and Gun Enemy AI Archetypes` | MISSING | MISSING | none | Add `type: concept`, `status: stable` |
| `Run and Gun Player Character Architecture` | MISSING | MISSING | none | Add `type: concept`, `status: stable` |
| `Run and Gun Bullet System Pattern` | MISSING | MISSING | none | Add `type: concept`, `status: stable` |
| `Run and Gun Level Design Patterns` | MISSING | MISSING | `[[ResearchGate Tower Defense Revenue Analysis]]` | Add `type: concept`, `status: stable`; fix dead link |
| `Godot 4 Run and Gun GitHub Repos` | source ✓ | MISSING | none | Add `status: stable` |
| `Godot 4 Run and Gun Tutorial Resources` | source ✓ | MISSING | none | Add `status: stable` |
| `Run and Gun Dev Community Resources` | source ✓ | MISSING | none | Add `status: stable` |

---

## Fix Priority Order

**Immediate (before next ingest):**
1. Add `type: concept` + `status: stable` to 8 new concept pages (safe auto-fix)
2. Add `status: stable` to 6 new source pages (safe auto-fix)
3. Fix case-mismatch: `[[Run And Gun Base Systems]]` → `[[Run and Gun Base Systems]]` in `Aim Lock Modifier Pattern.md`
4. Create `wiki/sources/Boss Rush Design Articles Game Developer.md`

**Short-term (next lint cycle):**
5. Create `wiki/entities/Furi.md`
6. Add frontmatter to `hot.md`, `log.md`, `index.md`
7. Add missing `created:`/`updated:` to 6 source pages
8. Add 4 new RnG pages to `## By Tag` in `index.md`

**Backlog (bulk sweep):**
9. Add `type:` to ~38 older pages
10. Add `status:` to ~100 older pages (bulk `status: stable`)
11. Begin `wiki/folds/` log archival
