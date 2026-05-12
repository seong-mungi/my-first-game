# Audio System

> **Status**: In Design
> **Author**: seong-mungi + game-designer / audio-director / sound-designer (per `.claude/skills/design-system` Section 6 routing for Audio systems)
> **Last Updated**: 2026-05-12
> **Implements Pillar**: Pillar 3 (Sensation — 사격 임팩트 + 시간 되감기 사운드) · Pillar 1 (학습 도구 — instant restart = audio resets cleanly)
> **Engine**: Godot 4.6 / GDScript (statically typed)
> **Review Mode**: lean (CD-GDD-ALIGN gate skipped per `production/review-mode.txt`)
> **Source Concept**: `design/gdd/game-concept.md`

---

## Overview

Audio System는 Echo의 사운드 출력 파이프라인을 소유하는 Foundation 시스템이다. `AudioManager` 오토로드가 4개 핵심 책임을 갖는다: (1) **AudioServer 버스 아키텍처** — Master / Music / SFX / UI 4-버스 계층 + 버스별 볼륨 제어 + 선택적 SFX-Music 더킹(보스 전투 · 시간 되감기 이벤트 시 Music 버스 일시 감쇄); (2) **SFX 오브젝트 풀** — 동시 재생을 위한 `AudioStreamPlayer` 노드 풀(Tier 1 cap: 8개) + CC0 스트림 null-safe 파사드; (3) **BGM 라이프사이클** — Tween 기반 크로스페이드 + 씬 전환 시 자동 페이드아웃; (4) **씬 시그널 구독** — `scene_will_change()` 구독으로 씬 경계 BGM 클리어, `boss_killed(boss_id)` 구독으로 보스 처치 스팅/음악 전환 트리거. **Tier 1 범위**: placeholder/CC0 OGG 스트림에 한정 — 오리지널 음악은 Anti-Pillar #4에 의해 Tier 3 외주까지 전면 금지. `AudioManager`는 ADR-0003 `_physics_process` 사다리에 슬롯을 점유하지 않고(Scene Manager Rule 2 패턴 준수) 시그널 기반 반응 전용으로 동작한다. **Tier 3**에서 외주 오리지널 트랙 도입 시 CC0 플레이스홀더를 1:1 교체하도록 인터페이스 계약을 설계한다.

## Player Fantasy

Echo의 화면이 *의도적으로 조립된 콜라주*이듯, Echo의 오디오도 같은 행위를 귀로 수행한다. `AudioManager`가 관리하는 모든 사운드 이벤트는 "정확한 효과음 재생"이 아니라 **소닉 콜라주의 조각 배치**다 — 각 클립은 믹스에 떨어진 발견된 오브젝트이며, 잡지 컷아웃 엣지처럼 의도적인 거칠함을 보존해야 한다.

**4개 감각 앵커 순간:**

- **총성 (SFX)**: 라이플 발사음은 AAA 폴리시가 아닌 건조하고 단단한 *타격* — 메가시티 ambient hum에 뚫린 인간-scale 구멍. SFX는 발사의 *확약*이며, 플레이어의 신경계는 히트 전에 이미 결과를 안다.
- **되감기 whoosh (SFX)**: 시간 토큰이 발동할 때 tape-reverse lo-fi 아티팩트가 들린다. 그 소리가 들리는 순간 몸은 이미 안다 — 실수가 취소되었고 다음 0.15초가 다시 내 것임을. (Pillar 1 달성의 *소닉 확인*.)
- **보스 BGM 전환**: Stage BGM이 하드 컷되면 ambient가 덕킹되고 저음 sustained pad가 상승한다 — 어깨가 전투 자세로 내려앉는 경보 사이렌. 음악적 페이드가 아닌 *하드 컷*은 콜라주 페이지 넘김과 동일한 편집 미학이다.
- **CC0 Tier 1 단계**: 오리지널 음악은 Anti-Pillar #4로 Tier 3 외주까지 금지되지만, Tier 1 placeholder의 거칠기는 타협이 아니라 *주제적 적합성*이다. Tier 3 작곡가의 임무는 그 hand-assembled 느낌을 보존하되 AAA 폴리시로 갈아내지 않는 것이다.

**Cross-reference**: Pillar 3 (Sensation / MDA Priority 2) · Pillar 1 (학습 도구 — 되감기 whoosh = 소닉 확인) · Anti-Pillar #4 — `design/gdd/game-concept.md`

**디자인 테스트**: 폴리시된 일반적 SFX vs 약간 mismatched하지만 *Echo답게 손으로 조립된* 클립 — 후자를 선택한다. 오디오 콜라주는 소닉 Pillar 3이다. Smoothness는 실패 상태다.

## Detailed Design

### Core Rules

**Rule 1 — Autoload identity and process ladder.**
`AudioManager`는 오토로드 싱글턴이며 `_physics_process` 또는 `_process`를 구현해서는 **안 된다**. ADR-0003 `process_physics_priority` 사다리에 슬롯을 갖지 않고 시그널 + 직접 호출 기반 반응 전용으로 동작한다(SceneManager Rule 2 패턴).

**Rule 2 — 버스 초기화 순서.**
`_ready()` 진입 시 AudioServer에 4개 버스가 정확히 존재하는지 assert한다: Master(index 0) / Music(index 1) / SFX(index 2) / UI(index 3). 버스는 `project.godot`에 정의하며 런타임에 생성하지 않는다. 버스 인덱스 또는 이름 불일치 시 `assert(false, "AudioManager: bus layout mismatch")` — 이후 어떤 오디오 코드도 실행되지 않는다.

**Rule 3 — SFX 풀 생성.**
버스 assert 통과 후 `_ready()`에서 `SFX_POOL_SIZE`(기본값: 8) 개의 `AudioStreamPlayer` 노드를 자식으로 생성하고 각각 `set_bus(&"SFX")` 후 `add_child()`한다. `_ready()` 외부에서 SFX 풀 노드를 생성해서는 안 된다.

**Rule 4 — Null-stream guard.**
스트림을 재생하는 모든 메서드는 `play()` 호출 전 스트림 인수가 non-null임을 확인한다. Null이면 호출을 무시하고 반환한다. 누락 에셋 식별자별 세션당 최대 1회 `push_warning()`을 emit한다(호출당 X — 로그 spam 방지). 크래시 없음, 에러 전파 없음.

**Rule 5 — SFX 풀 선택 및 소진 정책.**
SFX 재생 시 풀에서 `!is_playing()` 인 첫 번째 슬롯을 선형 스캔한다. 슬롯에 스트림을 할당하고 `play()`를 호출한다. 모든 슬롯이 사용 중이면 새 SFX를 에러 없이 **조용히 드롭**한다. Tier 1 동시 SFX 부하에서 소진은 예상되지 않는다(7개 SFX 파일, 낮은 동시성).

**Rule 6 — BGM play / stop API.**
`play_bgm(stream: AudioStream) -> void` — Music 버스 전용 `AudioStreamPlayer`에 대해 현재 BGM을 즉시 하드 컷(`stop()`)하고, Music 버스 볼륨을 0 dB로 리셋하고, 스트림을 할당하고 `play()`를 호출한다. Null-stream guard(Rule 4) 적용.
`stop_bgm() -> void` — BGM 플레이어에서 즉시 `stop()`을 호출한다. 페이드 없음. BGM 플레이어는 8-슬롯 SFX 풀과 분리된 전용 `AudioStreamPlayer`(Music 버스)다.

**Rule 7 — `scene_will_change` 시 Music 버스 하드 컷.**
AudioManager는 `SceneManager.scene_will_change()`를 구독한다. 수신 시: (1) Music 버스를 0 dB로 복원(Rule 9 guard — DUCKED 상태를 다음 씬으로 이월하지 않음), (2) `stop_bgm()` 호출. 두 단계는 동일 핸들러 내에서 이 순서로 실행된다.

**Rule 8 — `rewind_started` / `rewind_completed` ducking.**
AudioManager는 `TimeRewindController.rewind_started`를 구독한다. 수신 시: Tween으로 Music 버스를 0 dB → −6 dB까지 2프레임(≈ 0.033 s) 동안 감쇄하고, SFX 풀에서 `sfx_rewind_activate_01.ogg`를 재생한다.
AudioManager는 `TimeRewindController.rewind_completed`를 구독한다. 수신 시: Tween으로 Music 버스를 −6 dB → 0 dB까지 10프레임(≈ 0.167 s) 동안 선형 복원한다. 10프레임 ramp는 클릭(audio click) 방지를 위한 필수 값이다.
AudioManager는 `_duck_tween: Tween` 참조를 소유한다. 새 Tween을 생성하기 전에 항상 기존 `_duck_tween`을 kill한다(`_duck_tween.kill()` — null-safe). 이 kill 단계는 두 Tween이 동시에 Music 버스를 변경하는 것을 방지한다. AudioManager는 내부 프레임 타이머를 유지하지 않는다 — 언덕 타이밍은 TRC 시그널에 위임한다.

**Rule 9 — Ducking 멱등성 및 SILENT guard.**
Music 버스가 이미 −6 dB인 상태에서 `rewind_started`가 발동하면 볼륨 set은 멱등적이다(실질적 무-op). SILENT 상태(BGM 없음)에서 `rewind_started`가 발동해도 버스는 −6 dB로 설정된다. `play_bgm()`은 항상 Music 버스를 0 dB로 리셋한 후 스트림을 시작하므로 duck-후 BGM 시작이 감쇄된 볼륨으로 재생되는 상황을 방지한다.

**Rule 10 — UI 버스 격리 불변식.**
AudioManager의 모든 `AudioServer.set_bus_volume_db()` 호출은 Music 버스 인덱스만 대상으로 한다. UI 버스는 ducking 로직의 영향을 받지 않는다. `play_ui()`로 재생된 SFX는 rewind 상태, BGM 상태, Music 버스 볼륨 변경 어느 것에도 영향받지 않는다.

**Rule 11 — `play_ui(stream: AudioStream)` 파사드.**
AudioManager는 `play_ui(stream: AudioStream) -> void`를 노출한다. UI 버스에 할당된 전용 `AudioStreamPlayer`(SFX 풀 및 BGM 플레이어와 분리)에서 스트림을 재생한다. Tier 1에서 동시 UI SFX가 없으므로 풀링하지 않는다. Null-stream guard(Rule 4) 적용.

**Rule 12 — `play_rewind_denied()` 직접 호출 가능.**
TRC가 `_tokens == 0` + DYING + 되감기 입력을 감지할 때(TR AC-B4) EchoLifecycleSM이 `AudioManager.play_rewind_denied()`를 직접 호출한다. 시그널 없음. `sfx_rewind_token_depleted_01.ogg`를 SFX 풀에서 재생한다.

**Rule 13 — `boss_killed` 구독.**
AudioManager는 `Damage System.boss_killed(boss_id: StringName)`를 구독한다. 수신 시: SFX 풀에서 `sfx_boss_defeated_sting_01.ogg`를 재생한다. Tier 1에서 `boss_id` 파라미터는 무시된다.

**Rule 14 — `play_ammo_empty()` 직접 호출 가능.**
Player Shooting이 `ammo_count == 0` + 사격 입력 감지 시 `AudioManager.play_ammo_empty()`를 직접 호출한다(시그널 없음 — `play_rewind_denied()` 패턴과 동일). `sfx_player_ammo_empty_01.ogg`를 SFX 풀에서 재생한다.

**Rule 15 — 총성 음정 지터 (결정론 호환).**
`sfx_player_shoot_rifle_01.ogg` 재생 시 ±2–3% 음정 지터를 적용한다. 지터 값은 `Engine.get_physics_frames() & 0xFF`를 소형 사전계산 오프셋 테이블에 매핑하여 결정론적으로 생성한다(`randf()` 금지 — Pillar 2). 오디오는 시뮬레이션 상태가 아닌 프레젠테이션 레이어이므로 이 지터는 스냅샷/되감기 대상이 아니다. 총성을 6 rps로 연사할 때 반복 지각(repetition perception)을 방지한다.

**Rule 16 — `shot_fired` 구독.**
AudioManager는 `Player Shooting.shot_fired(direction: int)`를 구독한다. 수신 시: SFX 풀에서 `sfx_player_shoot_rifle_01.ogg`를 재생하고 Rule 15의 음정 지터(D.2)를 적용한다.

**Rule 17 — `player_hit_lethal` 구독.**
AudioManager는 `Damage System.player_hit_lethal(cause: StringName)`를 구독한다. 수신 시: SFX 풀에서 `sfx_player_death_01.ogg`를 재생한다. `cause` 파라미터는 Tier 1에서 무시된다.

---

### States and Transitions

| State | Entry Condition | Exit Condition | Music Bus Vol | SFX Behavior |
|---|---|---|---|---|
| **SILENT** | `_ready()` 부트; `stop_bgm()` 호출; `scene_will_change` 수신 | `play_bgm(non-null stream)` 호출 | 0 dB | SFX 풀 완전 활성 |
| **BGM_PLAYING** | `play_bgm(non-null stream)` 호출 | `stop_bgm()` 호출; `scene_will_change` 수신; `play_bgm()` 재호출(하드 컷) | 0 dB | SFX 풀 완전 활성 |
| **DUCKED** | `rewind_started` 수신 (SILENT 또는 BGM_PLAYING 어느 상태에서도) | `rewind_completed` 수신(10프레임 ramp 후 복원); 또는 `scene_will_change` 수신(Rule 7 핸들러에서 즉시 복원) | −6 dB (attack 2프레임 → hold → release 10프레임) | SFX 풀 완전 활성 — Music 버스만 감쇄 |

*DUCKED는 SILENT / BGM_PLAYING과 직교하는 상태다. Tier 1에서 보스 BGM 전환 전용 상태는 없다 — 보스 격파는 `boss_killed` SFX 스팅만 트리거하며, BGM 전환은 이후 씬 전환의 `scene_will_change` cascade로 처리한다.*

---

### Interactions with Other Systems

| Signal / Call | Producer | Consumer | AudioManager Action |
|---|---|---|---|
| `scene_will_change()` | SceneManager (#2) | AudioManager | Music 버스 → 0 dB 복원 → `stop_bgm()`. SILENT 전이. |
| `boss_killed(boss_id: StringName)` | Damage System (#8) | AudioManager | SFX 풀: `sfx_boss_defeated_sting_01.ogg` 재생. |
| `rewind_started(remaining_tokens: int)` | TimeRewindController (#9) | AudioManager | Music 버스 → −6 dB (2프레임 Tween). SFX: `sfx_rewind_activate_01.ogg`. |
| `rewind_completed` | TimeRewindController (#9) | AudioManager | Music 버스 → 0 dB (10프레임 linear Tween). |
| `shot_fired(direction: int)` | Player Shooting (#7) | AudioManager | SFX 풀: `sfx_player_shoot_rifle_01.ogg` + 음정 지터 (Rule 15). |
| `player_hit_lethal` | Damage System (#8) | AudioManager | SFX 풀: `sfx_player_death_01.ogg`. |
| `AudioManager.play_rewind_denied()` | EchoLifecycleSM (#5) via TR AC-B4 | AudioManager | SFX 풀: `sfx_rewind_token_depleted_01.ogg`. |
| `AudioManager.play_ammo_empty()` | Player Shooting (#7) direct call | AudioManager | SFX 풀: `sfx_player_ammo_empty_01.ogg`. |
| `AudioManager.play_bgm(stream)` | Stage/Encounter (#12) 또는 씬 부트 | AudioManager | Music 버스 0 dB 리셋 → hard cut → 새 BGM 재생. |
| `AudioManager.play_ui(stream)` | Menu/Pause System (#18, 미설계) | AudioManager | UI 버스 전용 플레이어: 스트림 재생. |

## Formulas

### D.1 Duck Tween Ramp

The duck_tween_ramp formula is defined as:

`vol_db(t) = piecewise linear over REWIND_SIGNATURE_FRAMES frames`

```
vol_db(t) =
  DUCK_START_DB + (DUCK_TARGET_DB − DUCK_START_DB) × (t / DUCK_ATTACK_FRAMES)
    if 0 ≤ t < DUCK_ATTACK_FRAMES                             [attack phase]

  DUCK_TARGET_DB
    if DUCK_ATTACK_FRAMES ≤ t < DUCK_ATTACK_FRAMES + t_hold  [hold phase]

  DUCK_TARGET_DB + (DUCK_START_DB − DUCK_TARGET_DB) × ((t − DUCK_ATTACK_FRAMES − t_hold) / DUCK_RELEASE_FRAMES)
    if t ≥ DUCK_ATTACK_FRAMES + t_hold                       [release phase]

where t_hold = REWIND_SIGNATURE_FRAMES − DUCK_ATTACK_FRAMES − DUCK_RELEASE_FRAMES = 18
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Elapsed frames | `t` | int | 0–30 | 프레임 오프셋. TRC 시그널 간격이 소유. AudioManager는 카운터를 유지하지 않는다. |
| Nominal vol | `DUCK_START_DB` | float | 0.0 (fixed) | Music 버스 기본 볼륨 (dB). |
| Duck floor | `DUCK_TARGET_DB` | float | −6.0 (fixed) | 되감기 중 Music 버스 감쇄 목표. 튜닝 노브 G.1 참조. |
| Attack frames | `DUCK_ATTACK_FRAMES` | int | 2 (fixed) | 하강 duration ≈ 0.033 s. Rule 8 소유. |
| Release frames | `DUCK_RELEASE_FRAMES` | int | 10 (fixed) | 상승 duration ≈ 0.167 s. 클릭 방지 최솟값. Rule 8 소유. |
| Hold frames | `t_hold` | int | 18 (derived) | Hold = 30 − 2 − 10. AudioManager 타이머 없음 — TRC 시그널 간격 위임. |
| Rewind window | `REWIND_SIGNATURE_FRAMES` | int | 30 (registry) | time-rewind.md 소유 상수. AudioManager는 설정하지 않는다. |
| Output | `vol_db(t)` | float | −6.0–0.0 | t 프레임 시점 Music 버스 볼륨 (dB). |

**Output Range:** −6.0 dB to 0.0 dB.

**Implementation:** AudioManager가 발행하는 Tween은 정확히 2건이다:
- `rewind_started` 수신 시: 0.0 dB → −6.0 dB, `DUCK_ATTACK_FRAMES / 60.0` s, `TRANS_LINEAR`
- `rewind_completed` 수신 시: −6.0 dB → 0.0 dB, `DUCK_RELEASE_FRAMES / 60.0` s, `TRANS_LINEAR`

**Example:** t=1(attack 중간) → −3.0 dB · t=10(hold) → −6.0 dB · t=25(release 중간, 5프레임 경과) → −3.0 dB · t=30(release 완료) → 0.0 dB.

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
| Table index | `i` | int | 0–255 | 생성 시 순회 인덱스. |
| Max offset | `JITTER_MAX` | float | 0.03 (fixed) | 최대 음정 오프셋 = 3%. 튜닝 노브 G.1. `randf()` 금지 (Pillar 2). |
| Prime | `JITTER_PRIME` | int | 211 (fixed) | 256과 서로소 — `(i × 211) % 256`이 0..255 전체를 순회(전주기 순열). |
| Table size | `JITTER_TABLE_SIZE` | int | 256 (fixed) | 2^8 — 비트 마스킹(`& 0xFF`) 허용, 나눗셈 없음. |
| Frame counter | `Engine.get_physics_frames()` | int | 0–2^63 | Godot 4.6 단조 증가 물리 프레임 카운터. ADR-0003 결정론 소스. 스냅샷 캡처 불필요 (오디오는 시뮬레이션이 아닌 프레젠테이션). |
| Pitch table | `pitch_table[i]` | float | 0.97–1.03 | `_ready()`에서 1회 생성 후 읽기 전용. |
| Output | `pitch_scale` | float | 0.97–1.03 | `AudioStreamPlayer.pitch_scale`에 적용. 1.0 = 변환 없음. |

**Output Range:** [0.97, 1.03]. 닫힌 선형 맵으로 생성 — 런타임 클램핑 불필요.

**Distribution property:** P=211은 256과 서로소이므로 10-프레임 stride에서 30발 풀 매거진(5초 연사) 동안 30개의 상이한 값이 반환된다. 256발 사이클 (~42초) 이전에는 반복 없음.

**Example:** 물리 프레임=1500 → index = `1500 & 0xFF = 236` → `(236×211)%256 = 100` → `pitch_table[236] = 1.0 + 0.03×(2×(100/255)−1) ≈ 0.9935` (−0.65% shift, 단발 지각 불가; 연사 시 다양성 발현).

---

### D.3 SFX Pool Utilization Invariant

The pool_utilization_invariant formula is defined as:

`N_worst = Σ ceil(duration_frames(e) / min_period_frames(e)) ≤ SFX_POOL_SIZE`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Event | `e` | enum | SFX_EVENT_SET (6 members) | 고유 SFX 트리거 이벤트. 아래 테이블 참조. |
| Duration | `duration_frames(e)` | int | 1–21 | 이벤트 `e`의 최대 재생 길이 (프레임). |
| Period | `min_period_frames(e)` | int | 1–10 | 이벤트 `e`의 최소 트리거 간격. |
| Peak slots | `N_slots(e)` | int | 1–3 | `ceil(duration / period)`. |
| Worst case | `N_worst` | int | ≤ 8 | 동시 최악 슬롯 합계. |
| Pool | `SFX_POOL_SIZE` | int | 8 (fixed) | 가용 풀 슬롯. |

**Per-event enumeration:**

| SFX Event | `duration_frames` | `min_period_frames` | `N_slots` | Mutual exclusion |
|---|---|---|---|---|
| Gunfire (`sfx_player_shoot_rifle_01.ogg`) | 21 | 10 (`FIRE_COOLDOWN_FRAMES`) | 3 | ALIVE 상태 필요. Death·Rewind와 동시 불가. |
| Rewind activate (`sfx_rewind_activate_01.ogg`) | ≤ 60 | unbounded | 1 | DYING→REWINDING 필요. Gunfire(ALIVE)와 상호 배타. |
| Rewind denied (`sfx_rewind_token_depleted_01.ogg`) | ≤ 60 | unbounded | 1 | `_tokens==0` 분기 — Rewind activate(`_tokens>0`)와 동일 프레임 동시 불가. |
| Player death (`sfx_player_death_01.ogg`) | ≤ 60 | unbounded | 1 | DYING→DEAD 필요. Gunfire(ALIVE)와 상호 배타. |
| Ammo empty (`sfx_player_ammo_empty_01.ogg`) | ≤ 60 | unbounded | 1 | ALIVE + ammo=0 필요. Death와 동시 불가. |
| Boss sting (`sfx_boss_defeated_sting_01.ogg`) | ≤ 60 | unbounded | 1 | 조우당 1회 고유 이벤트. 주기성 없음. |
| **N_worst** | | | **8** | |

**Invariant result:** `N_worst (8) ≤ SFX_POOL_SIZE (8)` — HOLDS.

**Mutual-exclusion argument (현실적 최대: 5슬롯):**
1. Gunfire(ALIVE)와 Death(`player_hit_lethal`)는 동일 프레임에 공존 불가 — lethal hit이 DYING으로 전이하면 이후 `shot_fired` 금지.
2. Rewind activate와 denied는 `_tokens` 조건 분기로 상호 배타 — 동일 프레임 2개 동시 발동 불가.
3. Gunfire(ALIVE)와 Rewind activate(DYING)는 유효 게임 상태를 공유하지 않는다.
4. **현실적 최대 시나리오**: 연사 3슬롯 + Ammo empty 1슬롯 + Boss sting 1슬롯 = **5슬롯** (62.5% 사용). 헤드룸 3슬롯.

**Fallback:** SFX_EVENT_SET에 항목이 추가될 때마다 불변식을 재평가한다. Rule 5 silent-drop이 이론적 최악 케이스를 커버한다.

**Example:** 마지막 총알이 보스를 처치하는 순간: 연사 3슬롯(진행 중) + boss_killed 1슬롯(동일 프레임) + ammo_empty 1슬롯(다음 프레임) = 최대 5슬롯 동시 사용. 풀 여유: 3슬롯.

## Edge Cases

- **If `scene_will_change` fires while `_duck_tween` is mid-flight (attack or release)**: kill `_duck_tween` 먼저(Rule 8), 그 다음 Music 버스를 0 dB로 동기 설정 → `stop_bgm()`(Rule 7 순서). kill 단계 없이 진행하면 Tween이 다음 프레임에 0 dB 설정을 덮어쓰고 DUCKED 상태가 다음 씬으로 이월된다.

- **If `rewind_started` fires while `_duck_tween` is mid-flight (attack ramp, 0→−6 dB 진행 중)**: kill `_duck_tween`, 현재 보간된 버스 볼륨에서 −6 dB까지 2프레임 attack Tween을 새로 시작한다(0 dB에서 재시작 X — 상향 점프 후 재하강으로 audible artifact 발생). `sfx_rewind_activate_01.ogg`를 SFX 풀에서 재재생한다.

- **If `rewind_started` fires while `_duck_tween` is mid-flight (release ramp, −6→0 dB 진행 중)**: kill `_duck_tween`, 현재 보간된 볼륨에서 −6 dB까지 2프레임 attack Tween을 새로 시작한다. Rule 9 멱등성이 −6 dB 이하 중간값을 안전하게 처리한다. `sfx_rewind_activate_01.ogg` 재재생.

- **If `rewind_completed` fires with no prior `rewind_started` in this scene (orphan signal)**: 핸들러가 조건 없이 실행된다 — 현재 Music 버스 볼륨(0 dB)에서 0 dB로의 release Tween을 생성한다. 0→0 Tween은 무해하다. `sfx_rewind_activate_01.ogg`는 재생하지 않는다(이 SFX는 `rewind_started` 핸들러 전용).

- **If `play_bgm()` is called while DUCKED**: kill `_duck_tween` 먼저(Rule 8), 그 다음 Rule 6 실행 — Music 버스를 0 dB로 동기 리셋 → 스트림 할당 → `play()`. Attack Tween이 kill되지 않으면 다음 프레임에 0 dB 리셋을 덮어써 BGM이 덕킹된 볼륨으로 재생된다.

- **If `boss_killed` fires on the same frame as `scene_will_change`**: AudioManager는 오토로드이므로 SFX 풀 `AudioStreamPlayer` 자식 노드가 `change_scene_to_packed` 이후에도 생존한다. 보스 처치 스팅은 씬 경계를 넘어 재생된다. Rule 7의 `stop_bgm()`은 Music 버스 BGM 플레이어만 정지하며 SFX 풀을 건드리지 않는다. 이 동작은 의도적이다.

- **If an SFX pool slot finishes playing mid-frame and a new SFX needs it**: `_physics_process`는 단일 스레드이므로 프레임 내 경쟁 없음. Rule 5 선형 스캔은 호출 시점의 상태를 원자적으로 관찰한다. **풀 소진으로 드롭된 SFX는 슬롯이 이후 프레임에 해제되어도 소급 큐잉되지 않는다** — 드롭은 영구적이다.

- **If `Engine.get_physics_frames()` overflows**: 공식 D.2의 `& (JITTER_TABLE_SIZE − 1)` 비트 마스킹은 카운터 크기에 무관하게 0..255 범위를 수학적으로 보장한다. 60 Hz에서 2^63 프레임은 약 48.7억 년이므로 도달 불가능하다. 별도 가드 불필요.

- **If `shot_fired` is connected before `pitch_table` generation completes in `_ready()`**: `pitch_table`은 필드 초기화자 또는 `_enter_tree()`에서 생성한다 — `_ready()` 내 시그널 연결 전에 실행되어 빈 테이블 접근 창이 제거된다. `_ready()`에 생성을 두어야 하는 경우, `_pitch_table_ready: bool` 가드로 미스 시 `pitch_scale = 1.0`을 반환한다.

- **If `shot_fired` is emitted while ECHO is in DYING / DEAD / REWINDING state**: AudioManager는 수명 주기 상태를 모른다 — 수신한 모든 `shot_fired`에 대해 `sfx_player_shoot_rifle_01.ogg`를 재생한다. 비-ALIVE 상태에서의 `shot_fired` 억제는 전적으로 Player Shooting의 책임이다(Player Shooting GDD 상태 게이트).

- **If `play_bgm()` is called with the stream already playing**: Rule 6은 무조건 하드 컷 — `stop()` → vol 0 dB 리셋 → 스트림 할당 → `play()`. 동일 스트림 전달 시 BGM은 처음부터 재시작된다. 중복 재시작 방지는 호출자(Stage/Encounter #12)의 책임이다.

- **If `boss_killed` is emitted twice for the same boss (duplicate emission)**: AudioManager는 중복 제거를 수행하지 않는다. 각 emit은 SFX 슬롯을 점유하거나 조용히 드롭된다. 보스 엔티티당 씬당 1회 emit 보장은 Damage System의 책임이다.

## Dependencies

### Upstream Dependencies (Audio System이 의존하는 시스템)

| # | System | Dependency Type | Interface | What Audio Needs |
|---|---|---|---|---|
| 2 | Scene Manager | HARD | `scene_will_change()` signal | BGM 하드 컷 + DUCKED 상태 클리어 타이밍 |
| 5 | State Machine Framework | HARD | `AudioManager.play_rewind_denied()` direct call | EchoLifecycleSM이 tokens=0+DYING+rewind_input 시 직접 호출 |
| 7 | Player Shooting | HARD | `shot_fired(direction: int)` signal + `AudioManager.play_ammo_empty()` direct call | 총성 SFX 트리거 + 탄창 빈 SFX 트리거 |
| 8 | Damage | HARD | `boss_killed(boss_id: StringName)` signal + `player_hit_lethal` signal | 보스 처치 스팅 + 플레이어 사망 SFX |
| 9 | Time Rewind | HARD | `rewind_started(remaining_tokens: int)` signal + `rewind_completed` signal | Music 버스 ducking + rewind whoosh SFX |

### Downstream Dependents (Audio System에 의존하는 시스템)

| # | System | Dependency Type | Interface | What They Need |
|---|---|---|---|---|
| 12 | Stage / Encounter System | HARD | `AudioManager.play_bgm(stream)` direct call | 씬 부트 시 BGM 시작. AudioManager 없으면 BGM 없음. |
| 18 | Menu / Pause System | HARD | `AudioManager.play_ui(stream)` direct call | UI SFX 재생 파사드. |

### Hard vs Soft Classification

모든 의존성은 **Hard**다 — 총성 없는 사격 루프, BGM 없는 씬 부트, 덕킹 없는 되감기 발생 시 Pillar 3 Sensation이 직접 손상된다. Tier 1 stub은 null-safe guard(Rule 4)로 에셋 누락을 크래시 없이 처리하므로 "에셋 미존재"와 "시스템 미존재"를 구분한다.

### Cross-doc Obligation Flags (Phase 5d batch)

이 GDD 승인 후 아래 교차 문서 역방향 행을 추가해야 한다:
- `time-rewind.md` — AudioManager가 `rewind_started` + `rewind_completed` 구독자임을 Downstream 행에 추가
- `damage.md` — AudioManager가 `boss_killed` + `player_hit_lethal` 소비자임을 추가
- `player-shooting.md` — AudioManager가 `shot_fired` 구독자 + `play_ammo_empty()` 피호출자임을 추가
- `state-machine.md` — EchoLifecycleSM이 `play_rewind_denied()` 직접 호출자임을 추가
- `scene-manager.md` — AudioManager가 `scene_will_change` 구독자임을 추가
- `systems-index.md` Row #4 — Depends On 컬럼을 Scene Manager 단독 → 5개 시스템으로 확장

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
GIVEN BGM_PLAYING state, WHEN `scene_will_change` fires, THEN — in this exact order — (1) Music bus volume is restored to 0 dB synchronously, (2) BGM player `stop()` is called. Neither step may occur in isolation or in reverse order.

**AC-D2 [BLOCKING]**
GIVEN `play_bgm(stream_A)` is playing, WHEN `play_bgm(stream_B)` is called, THEN stream_A stops immediately (hard cut, no fade, position 0), Music bus resets to 0 dB, and stream_B begins from position 0.

**AC-D3 [BLOCKING]**
GIVEN BGM_PLAYING state, WHEN `stop_bgm()` is called directly, THEN BGM player stops immediately with no fade and system transitions to SILENT.

---

### H.5 Music Bus Ducking (Rules 8–9, Formula D.1)

**AC-E1 [BLOCKING]**
GIVEN BGM_PLAYING state (Music bus at 0 dB), WHEN `rewind_started` fires, THEN Music bus reaches −6.0 dB within `DUCK_ATTACK_FRAMES` (2) physics frames (± 1 frame tolerance).

**AC-E2 [BLOCKING]**
GIVEN DUCKED state (Music bus at −6 dB), WHEN `rewind_completed` fires, THEN Music bus returns to 0.0 dB within `DUCK_RELEASE_FRAMES` (10) physics frames (± 1 frame tolerance).

**AC-E3 [BLOCKING]**
GIVEN `_duck_tween` is mid-attack (bus between 0 and −6 dB), WHEN a second `rewind_started` fires, THEN (1) prior Tween is killed; (2) fresh 2-frame Tween starts from the current interpolated bus volume — NOT reset to 0 dB; (3) Music bus reaches −6 dB within 2 frames of the second signal.

**AC-E4 [BLOCKING]**
GIVEN DUCKED state (possibly mid-tween), WHEN `scene_will_change` fires, THEN — in this order — (1) `_duck_tween` is killed; (2) Music bus is synchronously set to 0 dB; (3) `stop_bgm()` is called. DUCKED state must not carry into the next scene.

**AC-E5 [BLOCKING]**
GIVEN SILENT state (no BGM), WHEN `rewind_started` fires, THEN Music bus is set to −6 dB without crash and `sfx_rewind_activate_01.ogg` is dispatched to the SFX pool.

**AC-E6 [BLOCKING]**
GIVEN `_duck_tween` is mid-release (bus between −6 and 0 dB), WHEN `rewind_started` fires, THEN (1) prior Tween killed; (2) fresh 2-frame Tween starts from current interpolated volume — NOT from 0 dB; (3) Music bus reaches −6 dB within 2 frames.

**AC-E7 [BLOCKING]**
GIVEN no prior `rewind_started` in the current scene, WHEN `rewind_completed` fires (orphan signal), THEN (1) no crash; (2) `sfx_rewind_activate_01.ogg` does NOT play; (3) Music bus runs a 0 dB → 0 dB Tween (harmless no-op).

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
GIVEN Music bus is DUCKED at −6 dB, WHEN `play_ui(stream)` is called, THEN UI bus volume remains at 0 dB and the stream plays at full volume.

**AC-F2 [BLOCKING]**
GIVEN `play_ui(stream)` is called, WHEN handler runs, THEN `stream` plays on the dedicated UI-bus `AudioStreamPlayer` — not an SFX pool slot. Verified: SFX pool `is_playing()` count is unchanged after the call.

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
| OQ-AU-5 | **Menu/Pause #18 `play_ui()` SFX catalog** — Menu/Pause (#18, Not Started) hasn't defined which UI SFX events it will call. `play_ui()` uses a single dedicated UI player (no pool) — can play only one UI SFX at a time. Sufficient for typical menu navigation? Verify during `/design-system menu-pause`. | game-designer | `/design-system menu-pause` (#18) session |
