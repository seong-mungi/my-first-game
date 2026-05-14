# Audio System

> **Status**: Approved · 2026-05-12
> **Author**: seong-mungi + game-designer / audio-director / sound-designer (per `.claude/skills/design-system` Section 6 routing for Audio systems)
> **Last Updated**: 2026-05-13 — status/proof cleanup after cross-GDD warning pass
> **Implements Pillar**: Pillar 3 (Sensation — gunfire impact + time rewind sound) · Pillar 1 (learning tool — instant restart = audio resets cleanly)
> **Engine**: Godot 4.6 / GDScript (statically typed)
> **Review Mode**: lean (CD-GDD-ALIGN gate skipped per `production/review-mode.txt`)
> **Source Concept**: `design/gdd/game-concept.md`

---

## Overview

Audio System is the Foundation system that owns Echo's sound output pipeline. The `AudioManager` autoload has 5 core responsibilities: (1) **AudioServer bus architecture** — Master / Music / SFX / UI 4-bus hierarchy + per-bus volume control + optional SFX-Music ducking (temporary Music bus attenuation during boss fights · time rewind events); (2) **SFX object pool** — `AudioStreamPlayer` node pool for concurrent playback (Tier 1 cap: 8) + CC0 stream null-safe facade; (3) **BGM lifecycle** — Tween-based crossfade + auto fadeout on scene transition; (4) **scene signal subscription** — subscribes to `scene_will_change()` to clear BGM at scene boundaries, subscribes to `boss_killed(boss_id)` to trigger boss defeat sting/music transition; (5) **session-only bus volume facade** — exposes Master/Music/SFX/UI slider values for Menu/Pause #18 without Save/Settings persistence. **Tier 1 scope**: limited to placeholder/CC0 OGG streams — original music is fully prohibited until Tier 3 outsourcing per Anti-Pillar #4. `AudioManager` does not occupy a slot in the ADR-0003 `_physics_process` ladder (following Scene Manager Rule 2 pattern) and operates exclusively as a signal-driven reactor. The interface contract is designed so that when Tier 3 original tracks are introduced, CC0 placeholders are replaced 1:1.

## Player Fantasy

Just as Echo's visuals are an *intentionally assembled collage*, Echo's audio performs the same act for the ears. Every sound event managed by `AudioManager` is not "playing the correct sound effect" but **placing a piece of the sonic collage** — each clip is a found object dropped into the mix, and must preserve its intentional roughness like the edge of a magazine cutout.

**4 sensory anchor moments:**

- **Gunfire (SFX)**: The rifle shot is a dry, hard *impact* — not AAA polish — a human-scale hole punched through the megacity ambient hum. The SFX is the *commitment* of firing; the player's nervous system already knows the result before the hit.
- **Rewind whoosh (SFX)**: When a time token activates, a tape-reverse lo-fi artifact is heard. The moment that sound plays, the body already knows — the mistake has been undone and the next 0.15 seconds are mine again. (The *sonic confirmation* of Pillar 1 achievement.)
- **Boss BGM transition**: The Stage BGM hard-cuts, ambient ducks, and a low sustained pad rises — an alarm siren that drops the shoulders into fighting posture. The *hard cut* rather than a musical fade is the same editorial aesthetic as turning a collage page.
- **CC0 Tier 1 stage**: Original music is banned until Tier 3 outsourcing per Anti-Pillar #4, but the roughness of the Tier 1 placeholder is not a compromise — it is *thematic fitness*. The Tier 3 composer's mission is to preserve that hand-assembled feel without grinding it down to AAA polish.

**Cross-reference**: Pillar 3 (Sensation / MDA Priority 2) · Pillar 1 (learning tool — rewind whoosh = sonic confirmation) · Anti-Pillar #4 — `design/gdd/game-concept.md`

**Design test**: Polished generic SFX vs slightly mismatched but *Echo-like hand-assembled* clips — choose the latter. Audio collage is sonic Pillar 3. Smoothness is a failure state.

## Detailed Design

### Core Rules

**Rule 1 — Autoload identity and process ladder.**
`AudioManager` is an autoload singleton and **must not** implement `_physics_process` or `_process`. It has no slot in the ADR-0003 `process_physics_priority` ladder and operates exclusively as a signal + direct-call driven reactor (SceneManager Rule 2 pattern).

**Rule 2 — Bus initialization order.**
On `_ready()` entry, assert that exactly 4 buses exist in AudioServer: Master(index 0) / Music(index 1) / SFX(index 2) / UI(index 3). Buses are defined in `project.godot` and must not be created at runtime. If bus index or name mismatches: `assert(false, "AudioManager: bus layout mismatch")` — no audio code executes afterward.

**Rule 3 — SFX pool creation.**
After the bus assert passes, create `SFX_POOL_SIZE` (default: 8) `AudioStreamPlayer` nodes as children in `_ready()`, call `set_bus(&"SFX")` on each, then `add_child()`. SFX pool nodes must not be created outside of `_ready()`.

**Rule 4 — Null-stream guard.**
Every method that plays a stream verifies the stream argument is non-null before calling `play()`. If null, ignore the call and return. Emit `push_warning()` at most once per session per missing asset identifier (not per call — prevents log spam). No crash, no error propagation.

**Rule 5 — SFX pool selection and exhaustion policy.**
When playing SFX, linearly scan the pool for the first slot where `!is_playing()`. Assign the stream to the slot and call `play()`. If all slots are in use, **silently drop** the new SFX without error. Exhaustion is not expected under Tier 1 concurrent SFX load (7 SFX files, low concurrency).

**Rule 6 — BGM play / stop API.**
`play_bgm(stream: AudioStream) -> void` — on the dedicated `AudioStreamPlayer` for the Music bus: immediately hard-cut the current BGM (`stop()`), reapply the Music session baseline with no duck offset, assign the stream and call `play()`. Null-stream guard (Rule 4) applies.
`stop_bgm() -> void` — immediately call `stop()` on the BGM player. No fade. The BGM player is a dedicated `AudioStreamPlayer` (Music bus) separate from the 8-slot SFX pool.

**Rule 7 — Hard cut Music bus on `scene_will_change`.**
AudioManager subscribes to `SceneManager.scene_will_change()`. On receipt: (1) kill any active `_duck_tween` if present (`_duck_tween.kill()` — null-safe), (2) restore Music bus to the Music session baseline (Rule 9 guard — do not carry DUCKED state into the next scene), (3) call `stop_bgm()`. All three steps execute in this order within the same handler. The Tween kill is part of the main rule, not only an edge-case patch.

**Rule 8 — `rewind_started` / `rewind_completed` ducking.**
AudioManager subscribes to `TimeRewindController.rewind_started`. On receipt: attenuate Music bus from the Music session baseline to `baseline_db - 6 dB` over 2 frames (≈ 0.033 s) via Tween, and play `sfx_rewind_activate_01.ogg` from the SFX pool.
AudioManager subscribes to `TimeRewindController.rewind_completed`. On receipt: linearly restore Music bus from `baseline_db - 6 dB` to the Music session baseline over 10 frames (≈ 0.167 s) via Tween. The 10-frame ramp is the mandatory minimum to prevent audio clicks.
AudioManager owns a `_duck_tween: Tween` reference. Always kill the existing `_duck_tween` before creating a new one (`_duck_tween.kill()` — null-safe). This kill step prevents two Tweens from simultaneously modifying the Music bus. AudioManager maintains no internal frame timer — timing is delegated to TRC signals.

**Rule 9 — Ducking idempotence and SILENT guard.**
If `rewind_started` fires while the Music bus is already at `baseline_db - 6 dB`, the volume set is idempotent (effectively a no-op). If `rewind_started` fires in the SILENT state (no BGM), the bus is still set to `baseline_db - 6 dB`. `play_bgm()` always reapplies the Music session baseline before starting the stream, preventing a scenario where BGM starts playing at attenuated volume after ducking.

**Rule 10 — UI bus isolation invariant.**
Time-rewind ducking only changes the Music bus effective volume. The UI bus is not affected by ducking logic; its effective volume is determined only by the UI session volume. SFX played via `play_ui()` are not affected by rewind state, BGM state, or Music bus ducking.

**Rule 11 — `play_ui(stream: AudioStream)` facade.**
AudioManager exposes `play_ui(stream: AudioStream) -> void`. Plays the stream on a dedicated `AudioStreamPlayer` assigned to the UI bus (separate from the SFX pool and BGM player). Not pooled, as there are no concurrent UI SFX in Tier 1. Null-stream guard (Rule 4) applies.

**Rule 12 — `play_rewind_denied()` directly callable.**
When TRC detects `_tokens == 0` + DYING + rewind input (TR AC-B4), EchoLifecycleSM directly calls `AudioManager.play_rewind_denied()`. No signal. Plays `sfx_rewind_token_depleted_01.ogg` from the SFX pool.

**Rule 13 — `boss_killed` subscription.**
AudioManager subscribes to `Damage System.boss_killed(boss_id: StringName)`. On receipt: play `sfx_boss_defeated_sting_01.ogg` from the SFX pool. The `boss_id` parameter is ignored in Tier 1.

**Rule 14 — `play_ammo_empty()` directly callable.**
When Player Shooting detects `ammo_count == 0` + fire input, it directly calls `AudioManager.play_ammo_empty()` (no signal — same pattern as `play_rewind_denied()`). Plays `sfx_player_ammo_empty_01.ogg` from the SFX pool.

**Rule 15 — Gunfire pitch jitter (determinism compatible).**
When playing `sfx_player_shoot_rifle_01.ogg`, apply ±2–3% pitch jitter. The jitter value is generated deterministically by mapping `Engine.get_physics_frames() & 0xFF` to a small precomputed offset table (no `randf()` — Pillar 2). Audio is a presentation layer, not simulation state, so this jitter is not subject to snapshot/rewind. Prevents repetition perception when firing at 6 rps.

**Rule 16 — `shot_fired` subscription.**
AudioManager subscribes to `Player Shooting.shot_fired(direction: int)`. On receipt: play `sfx_player_shoot_rifle_01.ogg` from the SFX pool and apply the pitch jitter from Rule 15 (D.2).

**Rule 17 — `player_hit_lethal` subscription.**
AudioManager subscribes to `Damage System.player_hit_lethal(cause: StringName)`. On receipt: play `sfx_player_death_01.ogg` from the SFX pool. The `cause` parameter is ignored in Tier 1.

**Rule 18 — Session bus volume facade.**
AudioManager exposes the only Tier 1 runtime volume-write API used by Menu/Pause #18:

- `set_session_bus_volume(bus_name: StringName, linear_value: float) -> void`
- `get_session_bus_volume(bus_name: StringName) -> float`

Allowed `bus_name` values are exactly `&"Master"`, `&"Music"`, `&"SFX"`, and `&"UI"`. Values are stored in memory in `_session_bus_linear: Dictionary[StringName, float]`, default `1.0` for all four buses at process start, clamped to `0.0..1.0` on write, and never saved to disk by Audio #4. Effective dB conversion is:

```text
session_bus_db(linear) = -80.0 if linear == 0.0 else linear_to_db(linear)
music_effective_db = session_bus_db(_session_bus_linear[&"Music"]) + current_duck_offset_db
```

`current_duck_offset_db` is `0.0` normally and `-6.0` during rewind ducking. Non-Music buses use `session_bus_db(linear)` directly. `FileAccess`, `ConfigFile`, and `user://` writes are forbidden in this facade; Save / Settings Persistence #21 owns future persistence.

---

### States and Transitions

| State | Entry Condition | Exit Condition | Music Bus Vol | SFX Behavior |
|---|---|---|---|---|
| **SILENT** | `_ready()` boot; `stop_bgm()` call; `scene_will_change` received | `play_bgm(non-null stream)` call | Music session baseline | SFX pool fully active |
| **BGM_PLAYING** | `play_bgm(non-null stream)` call | `stop_bgm()` call; `scene_will_change` received; `play_bgm()` re-call (hard cut) | Music session baseline | SFX pool fully active |
| **DUCKED** | `rewind_started` received (from either SILENT or BGM_PLAYING state) | `rewind_completed` received (restored after 10-frame ramp); or `scene_will_change` received (immediate restore in Rule 7 handler) | Music session baseline −6 dB (attack 2 frames → hold → release 10 frames) | SFX pool fully active — only Music bus attenuated |

*DUCKED is orthogonal to SILENT / BGM_PLAYING. There is no Tier 1 dedicated state for boss BGM transitions — boss defeat only triggers the `boss_killed` SFX sting; the BGM transition is handled by the `scene_will_change` cascade on the subsequent scene transition.*

---

### Interactions with Other Systems

| Signal / Call | Producer | Consumer | AudioManager Action |
|---|---|---|---|
| `scene_will_change()` | SceneManager (#2) | AudioManager | Kill `_duck_tween` → Music bus restore to session baseline → `stop_bgm()`. Transition to SILENT. |
| `boss_killed(boss_id: StringName)` | Damage System (#8) | AudioManager | SFX pool: play `sfx_boss_defeated_sting_01.ogg`. |
| `rewind_started(remaining_tokens: int)` | TimeRewindController (#9) | AudioManager | Music bus → session baseline −6 dB (2-frame Tween). SFX: `sfx_rewind_activate_01.ogg`. |
| `rewind_completed` | TimeRewindController (#9) | AudioManager | Music bus → session baseline (10-frame linear Tween). |
| `shot_fired(direction: int)` | Player Shooting (#7) | AudioManager | SFX pool: `sfx_player_shoot_rifle_01.ogg` + pitch jitter (Rule 15). |
| `player_hit_lethal` | Damage System (#8) | AudioManager | SFX pool: `sfx_player_death_01.ogg`. |
| `AudioManager.play_rewind_denied()` | EchoLifecycleSM (#5) via TR AC-B4 | AudioManager | SFX pool: `sfx_rewind_token_depleted_01.ogg`. |
| `AudioManager.play_ammo_empty()` | Player Shooting (#7) direct call | AudioManager | SFX pool: `sfx_player_ammo_empty_01.ogg`. |
| `AudioManager.play_bgm(stream)` | Stage/Encounter (#12) or scene boot | AudioManager | Music bus session baseline reapplied → hard cut → play new BGM. |
| `AudioManager.play_ui(stream)` | Menu/Pause System (#18) | AudioManager | Dedicated UI-bus player: play stream. |
| `AudioManager.set_session_bus_volume(bus_name, linear_value)` | Menu/Pause System (#18) | AudioManager | Clamp/store session bus volume; apply effective dB; no file write. |
| `AudioManager.get_session_bus_volume(bus_name)` | Menu/Pause System (#18) | AudioManager | Return current in-memory slider value. |

## Formulas

### D.1 Duck Tween Ramp

The duck_tween_ramp formula is defined as:

`vol_db(t) = piecewise linear offset from the current Music session baseline over REWIND_SIGNATURE_FRAMES frames`

```
vol_db(t) =
  BASELINE_DB + (DUCK_TARGET_DB × (t / DUCK_ATTACK_FRAMES))
    if 0 ≤ t < DUCK_ATTACK_FRAMES                             [attack phase]

  BASELINE_DB + DUCK_TARGET_DB
    if DUCK_ATTACK_FRAMES ≤ t < DUCK_ATTACK_FRAMES + t_hold  [hold phase]

  BASELINE_DB + DUCK_TARGET_DB × (1.0 − ((t − DUCK_ATTACK_FRAMES − t_hold) / DUCK_RELEASE_FRAMES))
    if t ≥ DUCK_ATTACK_FRAMES + t_hold                       [release phase]

where t_hold = REWIND_SIGNATURE_FRAMES − DUCK_ATTACK_FRAMES − DUCK_RELEASE_FRAMES = 18
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Elapsed frames | `t` | int | 0–30 | Frame offset. Owned by TRC signal interval. AudioManager maintains no counter. |
| Session baseline | `BASELINE_DB` | float | −80.0..0.0 | Current Music session volume converted by `session_bus_db(_session_bus_linear[&"Music"])`. |
| Duck offset | `DUCK_TARGET_DB` | float | −6.0 (fixed) | Music bus attenuation offset during rewind. See tuning knob G.1. |
| Attack frames | `DUCK_ATTACK_FRAMES` | int | 2 (fixed) | Descent duration ≈ 0.033 s. Owned by Rule 8. |
| Release frames | `DUCK_RELEASE_FRAMES` | int | 10 (fixed) | Ascent duration ≈ 0.167 s. Minimum for click prevention. Owned by Rule 8. |
| Hold frames | `t_hold` | int | 18 (derived) | Hold = 30 − 2 − 10. No AudioManager timer — delegated to TRC signal interval. |
| Rewind window | `REWIND_SIGNATURE_FRAMES` | int | 30 (registry) | Constant owned by time-rewind.md. AudioManager does not set it. |
| Output | `vol_db(t)` | float | `BASELINE_DB - 6.0`..`BASELINE_DB` | Music bus volume (dB) at frame t. |

**Output Range:** Music session baseline minus 6.0 dB to Music session baseline.

**Implementation:** AudioManager issues exactly 2 Tweens:
- On `rewind_started` received: `BASELINE_DB` → `BASELINE_DB - 6.0 dB`, `DUCK_ATTACK_FRAMES / 60.0` s, `TRANS_LINEAR`
- On `rewind_completed` received: `BASELINE_DB - 6.0 dB` → `BASELINE_DB`, `DUCK_RELEASE_FRAMES / 60.0` s, `TRANS_LINEAR`

**Example:** If Music session baseline is −12.0 dB, then t=1 (mid-attack) → −15.0 dB · t=10 (hold) → −18.0 dB · t=25 (mid-release, 5 frames elapsed) → −15.0 dB · t=30 (release complete) → −12.0 dB.

---

### D.2 Pitch Jitter Lookup

The pitch_jitter formula is defined as a two-step process:

**Step 1 — Table generation (called once at `_ready()`):**

`pitch_table[i] = 1.0 + JITTER_MAX × (2.0 × ((i × JITTER_PRIME) % JITTER_TABLE_SIZE) / (JITTER_TABLE_SIZE − 1) − 1.0)`

**Step 2 — Per-shot lookup (called on each `shot_fired`):**

`pitch_scale = pitch_table[Engine.get_physics_frames() & (JITTER_TABLE_SIZE − 1)]`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Table index | `i` | int | 0–255 | Iteration index during generation. |
| Max offset | `JITTER_MAX` | float | 0.03 (fixed) | Maximum pitch offset = 3%. Tuning knob G.1. No `randf()` (Pillar 2). |
| Prime | `JITTER_PRIME` | int | 211 (fixed) | Coprime with 256 — `(i × 211) % 256` traverses all of 0..255 (full-cycle permutation). |
| Table size | `JITTER_TABLE_SIZE` | int | 256 (fixed) | 2^8 — allows bit-masking (`& 0xFF`), no division. |
| Frame counter | `Engine.get_physics_frames()` | int | 0–2^63 | Godot 4.6 monotonically increasing physics frame counter. ADR-0003 determinism source. No snapshot capture needed (audio is presentation, not simulation). |
| Pitch table | `pitch_table[i]` | float | 0.97–1.03 | Generated once at `_ready()`, read-only thereafter. |
| Output | `pitch_scale` | float | 0.97–1.03 | Applied to `AudioStreamPlayer.pitch_scale`. 1.0 = no change. |

**Output Range:** [0.97, 1.03]. Generated as a closed linear map — no runtime clamping needed.

**Distribution property:** P=211 is coprime with 256, so at a 10-frame stride over a 30-shot full magazine (5 seconds of fire), 30 distinct values are returned. No repetition before the 256-shot cycle (~42 seconds).

**Example:** Physics frame=1500 → index = `1500 & 0xFF = 236` → `(236×211)%256 = 100` → `pitch_table[236] = 1.0 + 0.03×(2×(100/255)−1) ≈ 0.9935` (−0.65% shift, imperceptible on a single shot; variation emerges during sustained fire).

---

### D.3 SFX Pool Utilization Invariant

The pool_utilization_invariant formula is defined as:

`N_worst = Σ ceil(duration_frames(e) / min_period_frames(e)) ≤ SFX_POOL_SIZE`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Event | `e` | enum | SFX_EVENT_SET (6 members) | Unique SFX trigger events. See table below. |
| Duration | `duration_frames(e)` | int | 1–21 | Maximum playback length (frames) for event `e`. |
| Period | `min_period_frames(e)` | int | 1–10 | Minimum trigger interval for event `e`. |
| Peak slots | `N_slots(e)` | int | 1–3 | `ceil(duration / period)`. |
| Worst case | `N_worst` | int | ≤ 8 | Sum of worst-case concurrent slots. |
| Pool | `SFX_POOL_SIZE` | int | 8 (fixed) | Available pool slots. |

**Per-event enumeration:**

| SFX Event | `duration_frames` | `min_period_frames` | `N_slots` | Mutual exclusion |
|---|---|---|---|---|
| Gunfire (`sfx_player_shoot_rifle_01.ogg`) | 21 | 10 (`FIRE_COOLDOWN_FRAMES`) | 3 | Requires ALIVE at WeaponSlot priority 0. Can overlap with same-tick `player_hit_lethal` if Damage priority 2 emits later in the tick; blocked from tick N+1. |
| Rewind activate (`sfx_rewind_activate_01.ogg`) | ≤ 60 | unbounded | 1 | Requires DYING→REWINDING. Can overlap with lingering gunfire and same-tick lethal-hit when rewind input was buffered pre-hit. |
| Rewind denied (`sfx_rewind_token_depleted_01.ogg`) | ≤ 60 | unbounded | 1 | Mutually exclusive with Rewind activate in a single decision branch; covers `_tokens == 0` and `buffer_invalidated` denial reasons. |
| Player death (`sfx_player_death_01.ogg`) | ≤ 60 | unbounded | 1 | Triggered by `player_hit_lethal`; can overlap with same-tick gunfire because WeaponSlot runs before Damage. |
| Ammo empty (`sfx_player_ammo_empty_01.ogg`) | ≤ 60 | unbounded | 1 | Requires ALIVE + ammo=0 at WeaponSlot priority 0. Can overlap with later same-tick lethal-hit, but not with a successful current-shot `shot_fired` branch. |
| Boss sting (`sfx_boss_defeated_sting_01.ogg`) | ≤ 60 | unbounded | 1 | One unique event per encounter. Can overlap with scene change and with same-tick lethal-hit resolution. |
| **N_worst** | | | **8** | Theoretical sum across all event categories; still bounded by pool size. |

**Invariant result:** `N_worst (8) ≤ SFX_POOL_SIZE (8)` — HOLDS.

**Mutual-exclusion / overlap argument (realistic maximum: 7 slots):**
1. Gunfire is not mutually exclusive with same-tick lethal-hit: Player Shooting E-PS-14/PS-H4-14 specifies WeaponSlot priority 0 can emit `shot_fired` before Damage priority 2 emits `player_hit_lethal`; shooting is blocked from tick N+1.
2. Rewind activate and rewind denied remain mutually exclusive because one `try_consume_rewind()` decision branch returns either success or denial, not both.
3. Successful current-shot gunfire and ammo-empty are mutually exclusive in the same WeaponSlot branch, but lingering gunfire slots from previous shots can overlap with ammo-empty.
4. **Realistic worst-case scenario**: 3 lingering gunfire slots + 1 ammo-empty or current-shot branch + 1 `player_hit_lethal` death cue + 1 rewind activate/denied cue + 1 boss sting = **7 slots** (87.5% usage). 1 slot headroom remains.

**Fallback:** Re-evaluate the invariant whenever an item is added to SFX_EVENT_SET. Rule 5 silent-drop covers the theoretical worst case.

**Example:** The moment the last bullet defeats the boss and ECHO is also lethally hit: up to 3 gunfire slots (including lingering/current shot) + 1 `player_hit_lethal` death cue + 1 boss_killed sting + 1 buffered rewind activation/denial cue = max 6 concurrent slots. Pool headroom: 2 slots.

## Edge Cases

- **If `scene_will_change` fires while `_duck_tween` is mid-flight (attack or release)**: kill `_duck_tween` first (Rule 8), then synchronously set Music bus to the Music session baseline → `stop_bgm()` (Rule 7 order). Without the kill step, the Tween overwrites the baseline set in the next frame and the DUCKED state carries into the next scene.

- **If `rewind_started` fires while `_duck_tween` is mid-flight (attack ramp, baseline→baseline−6 dB in progress)**: kill `_duck_tween`, start a fresh 2-frame attack Tween from the current interpolated bus volume to `baseline_db - 6 dB` (NOT restart from baseline — doing so causes an audible artifact: upward jump then re-descent). Re-play `sfx_rewind_activate_01.ogg` from the SFX pool.

- **If `rewind_started` fires while `_duck_tween` is mid-flight (release ramp, baseline−6 dB→baseline in progress)**: kill `_duck_tween`, start a fresh 2-frame attack Tween from the current interpolated volume to `baseline_db - 6 dB`. Rule 9 idempotence safely handles intermediate values below the duck target. Re-play `sfx_rewind_activate_01.ogg`.

- **If `rewind_completed` fires with no prior `rewind_started` in this scene (orphan signal)**: the handler executes unconditionally — creates a release Tween from the current Music bus volume to the Music session baseline. A baseline→baseline Tween is harmless. `sfx_rewind_activate_01.ogg` does not play (this SFX is exclusive to the `rewind_started` handler).

- **If `play_bgm()` is called while DUCKED**: kill `_duck_tween` first (Rule 8), then execute Rule 6 — synchronously reset Music bus to the Music session baseline → assign stream → `play()`. If the attack Tween is not killed, it overwrites the baseline reset in the next frame and the BGM plays at a ducked volume.

- **If `boss_killed` fires on the same frame as `scene_will_change`**: since AudioManager is an autoload, its SFX pool `AudioStreamPlayer` child nodes survive after `change_scene_to_packed`. The boss defeat sting plays across the scene boundary. Rule 7's `stop_bgm()` stops only the Music bus BGM player and does not touch the SFX pool. This behavior is intentional.

- **If an SFX pool slot finishes playing mid-frame and a new SFX needs it**: `_physics_process` is single-threaded, so no intra-frame race condition. Rule 5's linear scan atomically observes state at call time. **SFX dropped due to pool exhaustion are not retroactively queued even if a slot is freed in a later frame** — drops are permanent.

- **If `Engine.get_physics_frames()` overflows**: the `& (JITTER_TABLE_SIZE − 1)` bit-masking in Formula D.2 mathematically guarantees the range 0..255 regardless of counter size. At 60 Hz, 2^63 frames is approximately 4.87 billion years — unreachable. No additional guard needed.

- **If `shot_fired` is connected before `pitch_table` generation completes in `_ready()`**: `pitch_table` is generated in a field initializer or `_enter_tree()` — executed before signal connections in `_ready()`, eliminating the empty-table access window. If generation must be placed in `_ready()`, guard with a `_pitch_table_ready: bool` flag and return `pitch_scale = 1.0` on miss.

- **If `shot_fired` is emitted while ECHO is in DYING / DEAD / REWINDING state**: AudioManager does not know the lifecycle state — it plays `sfx_player_shoot_rifle_01.ogg` for every `shot_fired` received. Suppressing `shot_fired` in non-ALIVE states is entirely the responsibility of Player Shooting (Player Shooting GDD state gate).

- **If `play_bgm()` is called with the stream already playing**: Rule 6 unconditionally hard-cuts — `stop()` → Music session baseline reapplied → assign stream → `play()`. If the same stream is passed, BGM restarts from the beginning. Preventing duplicate restarts is the caller's responsibility (Stage/Encounter #12).

- **If `boss_killed` is emitted twice for the same boss (duplicate emission)**: AudioManager performs no deduplication. Each emit occupies an SFX slot or is silently dropped. Guaranteeing at most one emit per boss entity per scene is the responsibility of Damage System.

## Dependencies

### Upstream Dependencies (systems that Audio System depends on)

| # | System | Dependency Type | Interface | What Audio Needs |
|---|---|---|---|---|
| 2 | Scene Manager | HARD | `scene_will_change()` signal | Timing for BGM hard cut + DUCKED state clear |
| 5 | State Machine Framework | HARD | `AudioManager.play_rewind_denied()` direct call | EchoLifecycleSM calls directly when tokens=0+DYING+rewind_input |
| 7 | Player Shooting | HARD | `shot_fired(direction: int)` signal + `AudioManager.play_ammo_empty()` direct call | Gunfire SFX trigger + empty magazine SFX trigger |
| 8 | Damage | HARD | `boss_killed(boss_id: StringName)` signal + `player_hit_lethal` signal | Boss defeat sting + player death SFX |
| 9 | Time Rewind | HARD | `rewind_started(remaining_tokens: int)` signal + `rewind_completed` signal | Music bus ducking + rewind whoosh SFX |

### Downstream Dependents (systems that depend on Audio System)

| # | System | Dependency Type | Interface | What They Need |
|---|---|---|---|---|
| 12 | Stage / Encounter System | HARD | `AudioManager.play_bgm(stream)` direct call | Start BGM on scene boot. No BGM without AudioManager. |
| 18 | Menu / Pause System | HARD | `AudioManager.play_ui(stream)`, `set_session_bus_volume(bus_name, linear_value)`, `get_session_bus_volume(bus_name)` direct calls | UI SFX playback facade + session-only volume slider facade. |

### Hard vs Soft Classification

All dependencies are **Hard** — shooting loop without gunfire, scene boot without BGM, and rewind without ducking directly damage Pillar 3 Sensation. The Tier 1 stub handles missing assets without crashing via the null-safe guard (Rule 4), distinguishing "asset absent" from "system absent."

### Cross-doc Obligation Flags (Phase 5d batch)

After this GDD is approved, the following reverse rows must be added to the cross-referenced documents:
- `time-rewind.md` — add Downstream row that AudioManager subscribes to `rewind_started` + `rewind_completed`
- `damage.md` — add that AudioManager consumes `boss_killed` + `player_hit_lethal`
- `player-shooting.md` — add that AudioManager subscribes to `shot_fired` + is callee of `play_ammo_empty()`
- `state-machine.md` — add that EchoLifecycleSM is direct caller of `play_rewind_denied()`
- `scene-manager.md` — add that AudioManager subscribes to `scene_will_change`
- `systems-index.md` Row #4 — expand the Depends On column from Scene Manager alone to 5 systems

## Tuning Knobs

### G.1 Externalized Knobs — `assets/data/audio_config.tres`

All four values below are exported fields on an `AudioConfig` resource.
`AudioManager._ready()` loads this resource and reads the values.
Designers adjust them in the Godot editor without touching code.

| Knob | Symbol | Default | Safe Range | Too Low | Too High |
|---|---|---|---|---|---|
| Duck depth | `DUCK_TARGET_DB` | −6.0 dB | −12.0 to −3.0 | < −12 dB: BGM inaudible during rewind; loses music-as-context | > −3 dB: Ducking imperceptible; rewind whoosh competes with undifferentiated BGM |
| Duck attack | `DUCK_ATTACK_FRAMES` | 2 | 1–6 | 1: Audio click risk at frame edge | > 6: Duck arrival lags `rewind_started` by > 0.1 s; sensation desyncs from visual shader |
| Duck release | `DUCK_RELEASE_FRAMES` | 10 | 8–20 | < 8: Audio click on release; 10 is the click-prevention minimum (Rule 8) | > 20: BGM absent > 0.33 s post-rewind; Pillar 1 "instant recovery" feel damaged |
| Gunfire pitch jitter | `JITTER_MAX` | 0.03 | 0.01–0.05 | < 0.01: Variation imperceptible; gunfire monotony returns at sustained 6 rps fire | > 0.05: > 5% shift audible as detuning error on single shot rather than variation |

### G.2 Cross-Knob Invariant (enforced at `_ready()`)

`DUCK_ATTACK_FRAMES + DUCK_RELEASE_FRAMES ≤ REWIND_SIGNATURE_FRAMES (30)`

Current values: 2 + 10 = 12 ≤ 30. Hold phase `t_hold = 30 − 2 − 10 = 18` frames.
If either attack or release is raised, verify `t_hold ≥ 0`. `REWIND_SIGNATURE_FRAMES`
is owned by `time-rewind.md` — Audio must not modify it.

`assert(DUCK_ATTACK_FRAMES + DUCK_RELEASE_FRAMES <= REWIND_SIGNATURE_FRAMES,
    "AudioManager: duck ramp exceeds rewind window")`

### G.3 Code Constants — not externalized

| Constant | Value | Why Kept in Code |
|---|---|---|
| `SFX_POOL_SIZE` | 8 | Instantiated as child nodes at `_ready()`. Changing at runtime is unsafe. D.3 verifies N_worst ≤ 8. If new SFX events are added, re-verify D.3 and raise this constant. |
| `JITTER_PRIME` | 211 | 256-coprime ensures full-cycle permutation — technical invariant, not a gameplay feel variable. |
| `JITTER_TABLE_SIZE` | 256 | Power-of-2; enables bit-mask `& 0xFF` lookup. Change only in lockstep with `JITTER_PRIME`. |

### G.4 Player Settings (not designer tuning knobs)

Bus volume levels (Master / Music / SFX / UI) are player preferences surfaced
in Menu/Pause (#18). They do not belong in `audio_config.tres`.

| Session value | Default | Range | Runtime API |
|---|---:|---:|---|
| `session_master_volume` | `1.0` | `0.0..1.0` | `set_session_bus_volume(&"Master", value)` |
| `session_music_volume` | `1.0` | `0.0..1.0` | `set_session_bus_volume(&"Music", value)` |
| `session_sfx_volume` | `1.0` | `0.0..1.0` | `set_session_bus_volume(&"SFX", value)` |
| `session_ui_volume` | `1.0` | `0.0..1.0` | `set_session_bus_volume(&"UI", value)` |

These values reset to defaults on process start. Save / Settings Persistence #21 owns future disk persistence and settings migration.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

### Pass / Fail Classification

- **BLOCKING** — automated test required in `tests/unit/audio/` or `tests/integration/audio/` before story is Done.
- **ADVISORY** — manual/playtest verification; documented in `production/qa/evidence/`.

---

### H.1 Boot / Initialization (Rules 1–3, G.2)

**AC-A1 [BLOCKING]**
GIVEN AudioManager autoloads, WHEN `_ready()` runs, THEN exactly 4 audio buses exist — `Master` / `Music` / `SFX` / `UI` in that order; if any bus is absent or mis-ordered, `assert(false, "AudioManager: bus layout mismatch")` fires before any signal subscription or pool creation executes.

**AC-A2 [BLOCKING]**
GIVEN `_ready()` completes, WHEN AudioManager's children are enumerated, THEN exactly `SFX_POOL_SIZE` (8) `AudioStreamPlayer` nodes exist as direct children, each with `bus == &"SFX"`.

**AC-A3 [BLOCKING]**
GIVEN AudioManager is in the scene tree, WHEN `has_method("_physics_process")` and `has_method("_process")` are queried, THEN both return `false`.

**AC-A4 [BLOCKING]**
GIVEN an `AudioConfig` resource where `DUCK_ATTACK_FRAMES + DUCK_RELEASE_FRAMES > REWIND_SIGNATURE_FRAMES (30)`, WHEN `_ready()` loads that config, THEN the G.2 invariant assert fires before any signal subscription is registered.

---

### H.2 Null Guard (Rule 4)

**AC-B1 [BLOCKING]**
GIVEN `play_sfx(null)` is called, WHEN the handler runs, THEN (1) no crash occurs; (2) `push_warning()` fires at most once per session for that event; (3) no SFX pool slot enters playing state.

---

### H.3 SFX Pool (Rules 3, 5)

**AC-C1 [BLOCKING]**
GIVEN all 8 SFX pool slots are actively playing, WHEN a 9th SFX play request arrives, THEN the request is silently dropped — no crash, no error log, pool slot count remains 8.

**AC-C2 [BLOCKING]**
GIVEN a pool slot finishes playing (`is_playing()` → false), WHEN the next SFX play request arrives in the same or immediately following frame, THEN the freed slot is assigned and `is_playing()` returns `true` for it.

---

### H.4 BGM Lifecycle (Rules 6, 7)

**AC-D1 [BLOCKING]**
GIVEN BGM_PLAYING state, WHEN `scene_will_change` fires, THEN — in this exact order — (1) Music bus volume is restored to the current Music session baseline synchronously, (2) BGM player `stop()` is called. Neither step may occur in isolation or in reverse order.

**AC-D2 [BLOCKING]**
GIVEN `play_bgm(stream_A)` is playing, WHEN `play_bgm(stream_B)` is called, THEN stream_A stops immediately (hard cut, no fade, position 0), Music bus reapplies the current Music session baseline, and stream_B begins from position 0.

**AC-D3 [BLOCKING]**
GIVEN BGM_PLAYING state, WHEN `stop_bgm()` is called directly, THEN BGM player stops immediately with no fade and system transitions to SILENT.

---

### H.5 Music Bus Ducking (Rules 8–9, Formula D.1)

**AC-E1 [BLOCKING]**
GIVEN BGM_PLAYING state with Music session baseline `B`, WHEN `rewind_started` fires, THEN Music bus reaches `B - 6.0 dB` within `DUCK_ATTACK_FRAMES` (2) physics frames (± 1 frame tolerance).

**AC-E2 [BLOCKING]**
GIVEN DUCKED state with Music bus at `B - 6.0 dB`, WHEN `rewind_completed` fires, THEN Music bus returns to session baseline `B` within `DUCK_RELEASE_FRAMES` (10) physics frames (± 1 frame tolerance).

**AC-E3 [BLOCKING]**
GIVEN `_duck_tween` is mid-attack (bus between `B` and `B - 6.0 dB`), WHEN a second `rewind_started` fires, THEN (1) prior Tween is killed; (2) fresh 2-frame Tween starts from the current interpolated bus volume — NOT reset to `B`; (3) Music bus reaches `B - 6.0 dB` within 2 frames of the second signal.

**AC-E4 [BLOCKING]**
GIVEN DUCKED state (possibly mid-tween), WHEN `scene_will_change` fires, THEN — in this order — (1) `_duck_tween` is killed; (2) Music bus is synchronously set to session baseline `B`; (3) `stop_bgm()` is called. DUCKED state must not carry into the next scene.

**AC-E5 [BLOCKING]**
GIVEN SILENT state (no BGM) with Music session baseline `B`, WHEN `rewind_started` fires, THEN Music bus is set to `B - 6.0 dB` without crash and `sfx_rewind_activate_01.ogg` is dispatched to the SFX pool.

**AC-E6 [BLOCKING]**
GIVEN `_duck_tween` is mid-release (bus between `B - 6.0 dB` and `B`), WHEN `rewind_started` fires, THEN (1) prior Tween killed; (2) fresh 2-frame Tween starts from current interpolated volume — NOT from `B`; (3) Music bus reaches `B - 6.0 dB` within 2 frames.

**AC-E7 [BLOCKING]**
GIVEN no prior `rewind_started` in the current scene, WHEN `rewind_completed` fires (orphan signal), THEN (1) no crash; (2) `sfx_rewind_activate_01.ogg` does NOT play; (3) Music bus runs a session-baseline → session-baseline Tween (harmless no-op).

---

### H.6 Signal → SFX Behavioral Path (Rules 8, 12–14, Interactions table)

**AC-E8 [BLOCKING]**
GIVEN any state, WHEN `rewind_started` fires, THEN `sfx_rewind_activate_01.ogg` is dispatched to the SFX pool (slot plays or is silently dropped if full — no crash either way).

**AC-H1 [BLOCKING]**
GIVEN `play_rewind_denied()` is called, WHEN handler runs, THEN `sfx_rewind_token_depleted_01.ogg` plays from an SFX pool slot.

**AC-H2 [BLOCKING]**
GIVEN `play_ammo_empty()` is called, WHEN handler runs, THEN `sfx_player_ammo_empty_01.ogg` plays from an SFX pool slot.

**AC-H3 [BLOCKING]**
GIVEN `boss_killed(boss_id)` fires with any `boss_id` value, WHEN handler runs, THEN `sfx_boss_defeated_sting_01.ogg` plays from an SFX pool slot regardless of `boss_id`.

**AC-H4 [BLOCKING]**
GIVEN `player_hit_lethal` fires, WHEN handler runs, THEN `sfx_player_death_01.ogg` plays from an SFX pool slot.

**AC-H5 [BLOCKING]**
GIVEN `shot_fired(direction)` fires, WHEN handler runs, THEN `sfx_player_shoot_rifle_01.ogg` plays from an SFX pool slot with `pitch_scale = pitch_table[Engine.get_physics_frames() & 0xFF]`.

---

### H.7 UI Bus Isolation (Rules 10–11)

**AC-F1 [BLOCKING]**
GIVEN Music bus is DUCKED at `B - 6.0 dB` and UI session volume is `U`, WHEN `play_ui(stream)` is called, THEN UI bus effective volume remains `session_bus_db(U)` and the stream plays on the UI bus without Music duck attenuation.

**AC-F2 [BLOCKING]**
GIVEN `play_ui(stream)` is called, WHEN handler runs, THEN `stream` plays on the dedicated UI-bus `AudioStreamPlayer` — not an SFX pool slot. Verified: SFX pool `is_playing()` count is unchanged after the call.

**AC-F3 [BLOCKING]**
GIVEN AudioManager has initialized, WHEN `set_session_bus_volume(&"UI", 0.5)` is called, THEN `get_session_bus_volume(&"UI") == 0.5`, the UI AudioServer bus is set to `linear_to_db(0.5)`, and no Master/Music/SFX session values change.

**AC-F4 [BLOCKING]**
GIVEN AudioManager has initialized, WHEN `set_session_bus_volume(&"Music", -1.0)` and `set_session_bus_volume(&"Music", 2.0)` are called, THEN stored Music values are clamped to `0.0` and `1.0` respectively; `0.0` maps to `-80.0 dB`, and no `FileAccess`, `ConfigFile`, or `user://` write occurs.

**AC-F5 [BLOCKING]**
GIVEN Music session volume is `0.5`, WHEN `rewind_started` then `rewind_completed` run, THEN the Music bus ducks from `linear_to_db(0.5)` to `linear_to_db(0.5) - 6.0 dB` and returns to `linear_to_db(0.5)` without overwriting the stored session value.

---

### H.8 Pitch Jitter (Formula D.2, Rule 15)

**AC-G1 [BLOCKING]**
GIVEN `pitch_table` is generated at `_ready()`, WHEN all 256 entries are read, THEN every value is in the closed range [0.97, 1.03].

**AC-G2 [BLOCKING]**
GIVEN the same `Engine.get_physics_frames() & 0xFF` index, WHEN `pitch_table` is queried at two different times in the same session, THEN both lookups return the identical `pitch_scale` value (table is read-only after `_ready()`; no `randf()` in path).

**AC-G3 [BLOCKING]**
GIVEN 30 consecutive `shot_fired` signals at `FIRE_COOLDOWN_FRAMES` (10-frame) intervals from frame 0, WHEN `pitch_scale` is recorded per shot, THEN exactly 30 distinct values appear (prime-modulo table guarantees full cycle over 256 shots; no repeat in first 30).

---

### H.9 Scene Boundary — Autoload SFX Survival (Edge Case)

**AC-J1 [BLOCKING]**
GIVEN `boss_killed` fires on the same frame as `scene_will_change`, WHEN `stop_bgm()` executes and `change_scene_to_packed` completes, THEN SFX pool `AudioStreamPlayer` nodes continue playing — `sfx_boss_defeated_sting_01.ogg` remains `is_playing() == true` after scene swap. (`stop_bgm()` targets only the BGM player, not pool slots.)

---

### H.10 Performance (G.1)

**AC-I1 [ADVISORY — requires Steam Deck Gen 1]**
GIVEN Steam Deck Gen 1 hardware, WHEN each signal handler (`scene_will_change`, `rewind_started`, `rewind_completed`, `boss_killed`, `shot_fired`, `player_hit_lethal`) is invoked in isolation via test harness, THEN wall-clock handler time < 0.5 ms per call. *Re-promote to BLOCKING before Beta milestone when Steam Deck is in the QA pipeline.*

---

### H.11 Audio Feel (manual / playtesting)

**AC-K1 [ADVISORY]**
GIVEN sustained gunfire at 6 rps for 5 seconds (30 shots), WHEN listened to, THEN no robotic pitch repetition is perceptible.

**AC-K2 [ADVISORY]**
GIVEN a rewind activation, WHEN `sfx_rewind_activate_01.ogg` plays, THEN it is audible and distinct from gunfire within a single playthrough.

**AC-K3 [ADVISORY]**
GIVEN boss fight with BGM → `boss_killed` → scene transition, WHEN the full sequence plays, THEN boss defeat sting is heard before BGM cuts — confirmed by audio director sign-off.

## Open Questions

| # | Question | Owner | Resolution Target |
|---|---|---|---|
| OQ-AU-1 | **CC0 SFX asset sourcing** — which specific CC0 pack(s) cover the 7 named .ogg files? Licensing (CC0 vs CC-BY) determines whether attribution is required in credits. | sound-designer | Before Tier 1 Week 2 (first playable with audio) |
| OQ-AU-2 | **AudioConfig resource definition** — is `AudioConfig` a custom `class_name AudioConfig extends Resource` with `@export` fields, or a plain Dictionary? Custom resource enables Godot editor knob-twisting without code; Dictionary is simpler but loses editor integration. | godot-gdscript-specialist | AudioManager implementation ADR or PR |
| OQ-AU-3 | **Tier 1 BGM placeholder** — complete silence, a CC0 ambient loop, or generative placeholder? Complete silence makes AC-E1/E2 (duck timing) untestable in integration — a CC0 loop is the minimum for test coverage. | sound-designer | Before Tier 1 integration test session |
| OQ-AU-4 | **Duck ramp re-verification gate** — `t_hold = REWIND_SIGNATURE_FRAMES − DUCK_ATTACK_FRAMES − DUCK_RELEASE_FRAMES`. If `time-rewind.md` changes `REWIND_SIGNATURE_FRAMES` (currently 30), no change gate is defined for re-verifying the G.2 invariant. Who owns the cascade update? | seong-mungi | Define via `/propagate-design-change` or ADR amendment when `time-rewind.md` is next revised |
| ~~OQ-AU-5~~ ✅ Resolved 2026-05-13 | **Menu/Pause #18 audio facade contract** — Menu/Pause #18 defines optional one-shot `menu_select`, `menu_confirm`, and `menu_cancel` events, limits Tier 1 to one UI SFX at a time, uses `AudioManager.play_ui(stream)` for UI SFX, and uses `set_session_bus_volume()` / `get_session_bus_volume()` for session-only Master/Music/SFX/UI sliders. The single dedicated UI player is sufficient; rapid ticks restart/drop deterministically rather than allocating a pool. | game-designer | Closed by `design/gdd/menu-pause.md` C.1 Rule 9/11 + E edge case + AC-MENU-09/10 |
