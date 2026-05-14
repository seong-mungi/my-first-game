---
name: Echo Project Audio Context
description: Echo Tier 1 audio decisions — 7-file SFX catalogue, BGM sourcing brief, duck shape, pitch jitter policy, and asset spec targets
type: project
---

Echo is a 2D run-and-gun (Godot 4.6, PC Steam). Tone: dystopian serious (Blade Runner / Ghost in the Shell). Visual aesthetic: collage SF (1990s magazine cutout + megacity photography). Core mechanic: 1-hit kill + 1.5s time-rewind token.

**Why:** Sonic Pillar 3 — "audio as second collage." Hand-assembled, slightly rough, found-sound clips mirror the collage visual aesthetic. Smoothness is failure.

**How to apply:** When proposing SFX curation targets or reviewing audio, always test against Sonic Pillar 3: the rougher, hand-assembled clip beats the polished generic SFX.

## Tier 1 SFX Catalogue (7 files, all mono, OGG Vorbis q5, 44.1kHz)

| File | Duration cap | LUFS target | Pitch jitter |
|---|---|---|---|
| `sfx_player_shoot_01.ogg` | ≤ 350ms | −14 (anchor) | YES ±2–3% |
| `sfx_player_ammo_empty_01.ogg` | ≤ 300ms | −18 | NO |
| `sfx_rewind_activate_01.ogg` | ≤ 600ms | −17 | NO |
| `sfx_rewind_token_depleted_01.ogg` | ≤ 400ms | −20 | NO |
| `sfx_player_death_01.ogg` | ≤ 800ms | −17 | NO |
| `sfx_boss_defeated_sting_01.ogg` | ≤ 3.0s | −16 | NO |
| `bgm_stage_01_placeholder.ogg` | 2–3 min loop | −18 integrated | N/A |

SFX pool cap: 8 voices. Duration caps are hard constraints (pool starvation at 6 rps).

## BGM Sourcing Brief

60–80 BPM (or no pulse), dark ambient / synthwave instrumental. Reference axis: Vangelis *Blade Runner OST* + Kenji Kawai *Ghost in the Shell* (1995) — textural underlay only, no melodic hook, no drum kit. Seamlessly loopable (2–3 min). Hand-assembled imperfection (tape hiss floor, uneven reverb tail) is correct. CC0 sources: Freesound.org, Free Music Archive dark-ambient, NASA Audio public domain. BGM is stereo, all SFX are mono.

## Duck Shape (Tier 1, single trigger: rewind_started)

Attack 2 frames → Hold 18 frames → Release 10 frames = 30 frames total. Depth: −6 dB. Release is linear ramp (click prevention on sustained pad). Instant unduck will pop. Multi-source policy deferred to Tier 2 (max-depth-wins recommended).

## Pitch Jitter Policy

Gunfire only. Source: `Engine.get_physics_frames() & 0xFF` mapped to pre-computed 8–16 value offset table (−3% to +3%). Do NOT use randf() in audio path — must be replay-identical for integration test evidence. All other SFX: no jitter.

## AudioServer Bus Architecture

Master / Music / SFX / UI — 4 buses. All at 0 dB nominal. Duck applied via Tween on Music bus. Peak ceiling −1 dBTP across all assets.
