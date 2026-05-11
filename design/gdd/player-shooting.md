# Player Shooting / Weapon System

> **Status**: In Design
> **System Index**: #7 (Feature Layer, MVP, depends on Input #1 / Player Movement #6 / Damage #8)
> **Author**: seong-mungi + Claude (game-designer / systems-designer / gameplay-programmer / godot-gdscript-specialist / art-director / audio-director / qa-lead specialists per section)
> **Last Updated**: 2026-05-11
> **Implements Pillars**: Pillar 1 (rewind = learning tool — via `ammo_count` restoration), Pillar 2 (determinism — no random spread), Pillar 4 (5-min rule — discoverable without tutorial)
> **Ratification Gate**: Closes ADR-0002 Amendment 2 (Proposed 2026-05-11) → Accepted. Closes OQ-PM-NEW (TRC orchestration vs Weapon `rewind_completed` subscription). Closes OQ-3 (silent fallback signaling). Closes input.md C.1.1 row 7 `shoot` detect mode.

## A. Overview

Player Shooting / Weapon은 ECHO의 *공격 액션 — 8방향 사격 + 무기 교체 + 발사체 스폰* 을 단일 책임자(`WeaponSlot extends Node2D`, PlayerMovement ECHO root의 자식)에서 호스팅하는 코어 게임플레이 시스템이다. 본 시스템은 두 측면의 단일 출처다:

**(1) 공격 레이어** — `Input.shoot` 폴링 + PM `facing_direction: int` 0..7 read + 8방향 발사체 인스턴스화 + 매 발 `ammo_count` decrement. PM은 `shoot`을 read하지 *않으며* movement도 freeze하지 *않는다* (game-concept "점프 + 사격 동시" 보존; player-movement.md C.1.3 / C.4.4 contract). 결정성(Pillar 2)은 **ADR-0003**의 projectile = `Area2D` + 직접 transform step + `process_physics_priority = 20` (PM=0 / TRC=1 / Damage=2 / enemies=10 / 본 시스템=20) 정책으로 보장한다 — solver를 거치지 않으므로 발사체 위치는 단일-출처 transform mutation이며 random spread 부재(Pillar 2 "운은 적이다"). Damage 시스템(#8)의 `echo_projectile_hitbox`(layer 2 → masks 3/6) 인스턴스화 책임을 본 시스템이 진다(damage.md F.1 표 #7); `cause: StringName` 라벨은 ECHO 발사체에서 미사용(`&""` default).

**(2) 데이터 레이어** — `ammo_count: int` 8번째 PM-노출 PlayerSnapshot 필드의 *Weapon single-writer 단일 출처* (**ADR-0002 Amendment 2** Proposed 2026-05-11). `WeaponSlot.ammo_count`는 매 `_physics_process` 틱 TRC에 의해 *read*되며(time-rewind.md AC-A1 Step (b)), PM `restore_from_snapshot(snap)`은 `snap.ammo_count`를 *ignore*한다. Weapon-side 복원 메커니즘(OQ-PM-NEW) — TRC orchestration 또는 `rewind_completed` 시그널 구독 — 은 본 GDD C 섹션에서 lock하며, 어느 경로든 rewind 성공 시 9프레임 전 ammo로 복원하여 Pillar 1 "처벌이 아닌 학습 도구" contract를 단일 출처로 보장한다(DYING 윈도우 중 ammo 0 도달 시에도 무위닝 상태 차단).

본 GDD는 4개 다운스트림 의무를 발생시킨다: PM `weapon_equipped(weapon_id: int)` signal 정의(PM F.4.2 obligation), `_on_anim_spawn_bullet` anim method-track 핸들러의 `_is_restoring` 가드 강제(PM C.4.4 reciprocal AC 본 GDD H에 mirror), Damage HitBox 인스턴스화(damage.md F.1 #7), `shoot` input action detect mode 결정(input.md C.1.1 row 7 — 본 GDD C에서 lock). Foundation 시스템은 아니지만 ADR-0002 Amendment 2 비준 + OQ-PM-NEW + OQ-3(`WeaponSlot.set_active(invalid_id)` silent fallback signal — damage.md/time-rewind.md E-15 locked terminology) + input row 7 detect mode 4개 게이트를 본 시스템 Designed 상태와 함께 일괄 종결한다.

## B. Player Fantasy

**Lead fantasy: 두 동사, 한 몸 — "이동과 사격이 하나의 연속된 표현이다."**

ECHO 작전 요원은 *달리면서 쏘고, 점프하면서 조준하고, 슬라이드 중에도 발사한다.* Contra 1987의 군인이 사격 자세에 *commit*해야 했다면, ECHO는 commit하지 않는다. 무기는 손에 *드는* 도구가 아니라 몸이 *입은* 장비 — sprint vector와 fire vector는 동시에 살아 있는 두 개의 동사다. 본 시스템이 발화하는 첫 인상 모먼트는 이것이다:

> "오른쪽으로 달리던 중 옥상의 저격수를 발견 → 점프 → 우상단 8방향 조준 (수평 속도 *보존*) → 발사 → 저격수가 점프 아크 중에 떨어지고, 착지하자마자 들어오는 다음 탄환 밑으로 슬라이드. 플레이어가 디스코드에 공유하며 쓰는 한 문장: '나 한 번도 안 멈췄어.'"

**핵심 정서 = *uninterrupted motion* (끊김 없는 흐름)**. 정확성은 결과일 뿐, 의도는 *흐름의 보존*이다. Hotline Miami의 즉각 재시작 카타르시스 + Katana Zero의 1히트 정밀함 + Contra의 8방향 무게감 — 셋의 교집합이 본 시스템이 노리는 자리다. 단, *Contra의 stance-commit 비용*은 제거된다. PM이 `shoot`을 read하지 않고 movement도 freeze하지 않는 game-concept "점프 + 사격 동시" 핵심 mechanic은 본 fantasy의 *메커닉 기반*이다 — 이 결정은 본 GDD에서 변경 불가.

**Pillar 정합**:

- **Pillar 4 (5분 룰 — 즉시 코어 루프)**: 본 시스템이 첫 인상 모먼트의 owner — 플레이어가 30초 안에 "잠깐, 이거 동시에 되네?"를 *발견*해야 한다. 이 발견 자체가 Steam 첫 인상 스크린샷 후보 (Pillar 3 콜라주 비주얼 + 본 시스템 fantasy의 결합 — 정지 이미지에 *수평 속도 벡터 + 대각선 fire 벡터* 가 함께 보임). 텍스트 튜토리얼 0줄.
- **Pillar 1 (시간 되감기 = 처벌이 아닌 학습 도구)**: ammo는 *추상적 자원*이 아니라 *흐름의 연료*다. 죽음 → 1초 회수 → 9프레임 전 ammo 복원 = 정서 단어로 "흐름 상태가 복원되었다" — "인벤토리가 복원되었다"가 아니다. Weapon-side `ammo_count` 복원(데이터 레이어, A.2)이 이 정서를 *단일 출처*로 보장한다. DYING 윈도우 중 ammo 0 = 무위닝 상태가 본 fantasy의 진정한 destroyer임을 인식하고 차단(ADR-0002 Amendment 2의 정서적 근거).
- **Pillar 2 (결정론 — 운은 적이다)**: random spread 부재 = 모든 빗나간 발사는 *플레이어의 실수*다. 적이 "운 좋게 피했다"는 변명 차단. ADR-0003 projectile = `Area2D` + 직접 transform step + `process_physics_priority = 20`이 결정성의 메커닉 단일 출처.

**Reference 게임에서 정확히 어떻게 다른가**:

| Reference | Echo가 차용 | Echo가 *다른* 부분 |
|---|---|---|
| **Contra** (1987-) | 8방향 사격 + 무기 픽업 + 결정론 패턴 + 1히트 즉사 | Contra는 사격 자세 commit (서거나 prone) — Echo는 *commit 없음*; movement freeze X (game-concept "점프+사격 동시") |
| **Katana Zero** (2019) | 1히트 즉사 + 시간 메커닉이 fantasy 단일 출처 | Katana는 검 + Will *사전* 시간 조작 — Echo는 사격 + *사후* rewind ammo 복원 (정서 단어 차원에서 다른 게임) |
| **Hotline Miami** (2012) | 즉시 재시작 + 결정론 + 빠른 살상 사이클 | HM은 탑다운 + 사이코 톤 — Echo는 횡스크롤 + 작전 요원 톤; HM의 "mania"가 아닌 *uninterrupted flow*가 정확한 단어 |

**"인프라가 아니다"**: 본 시스템은 *플레이어가 사랑해야 할* 메커닉이다. HUD에 ammo가 표시되고 무기 아이콘이 보이지만, 본 GDD의 fantasy 의무는 *카운터를 들여다보지 않게 만드는 것*이다 — ammo는 표시되지만 *흐름 중에는 무시되어야* 한다. 흐름이 끊겼을 때(rewind 후)에야 ammo가 *복원되어 있음*이 정서적으로 감지된다.

**Anti-fantasy (NOT)**:

- **NOT 무기 다양성 카탈로그** (Anti-Pillar #3 + Tier 1 = 1 rifle) — fantasy는 무기 *교체* 회로가 아니라 *흐름 보존* 회로다.
- **NOT 보스 위주** (Cuphead 모델) — Echo도 보스 임팩트는 있지만 본 시스템 fantasy는 *일상 적 처리의 흐름*이 1순위. 보스는 #11이 owner.
- **NOT 정밀 저격** (Sniper Elite 모델) — kill cam·zoom·breathing 메커닉 부재. Echo의 정밀은 *결정성*이지 *느림*이 아니다.
- **NOT "쿨한 처형"** (DOOM Eternal glory kill 모델) — hit-stun 부재(damage.md DEC-3), 즉시 1히트 binary, near-miss는 VFX #14가 own.

본 fantasy는 *두 개의 메커닉 결정*에 의해 보호된다: (1) game-concept "점프 + 사격 동시" + PM C.1.3 contract (movement 보존), (2) ADR-0002 Amendment 2 `ammo_count` rewind 복원 (흐름의 연료 보존). 이 두 결정이 동시에 깨지지 않는 한 본 fantasy는 깨지지 않는다.

## C. Detailed Design

### C.1 Core Rules

본 시스템은 12개의 락인된 핵심 규칙으로 정의된다. 각 규칙은 단일 출처 결정이며, 변경 시 본 GDD 갱신 + F.4 의무 cascade가 발생한다.

**규칙 1 (Detect + cooldown gate)** — Detect: `WeaponSlot._physics_process(delta)`이 매 틱 `Input.is_action_pressed("shoot")` 폴링 (NOT `is_action_just_pressed`; 탭-스팸은 cooldown counter가 게이트). Cooldown: `FIRE_COOLDOWN_FRAMES = 10` (6 rps @ 60 Hz) per fire — `_fire_cooldown_active = true; _fire_cooldown_frame = Engine.get_physics_frames()`. Tuning knob `fire_cooldown_frames: int` in `assets/data/weapons.tres`, safe range 6..20 (3..10 rps). **input.md C.1.1 row 7 closed** (F.4.1 #1 본 GDD 의무).

**규칙 2 (Aim resolution — 순수 8방향)** — `direction: int = _player.facing_direction` (PM C.1.3 #3) read inside `_try_fire()`. KB+M 마우스 free-aim 미지원; 가장 가까운 45° octant snap은 Input #1 layer 책임. PM `facing_direction: int` 0..7 enum (`architecture.yaml api_decisions.facing_direction_encoding`)이 양 input 프로파일 단일 출처. Pillar 2 결정성 + Pillar 4 즉시 학습성 단일 출처.

**규칙 3 (Projectile lifecycle)** —

- **Spawn position**: `Projectile.global_position = WeaponSlot.global_position + muzzle_offsets[direction]`. `muzzle_offsets: Array[Vector2]` length-8 in `assets/data/weapons.tres` (art-bible ABA-1 paper-doll arm overlay 따라 art-director tunable).
- **Motion**: `Projectile._physics_process(_delta)` runs `position += velocity * (1.0 / 60.0)`. `velocity = _DIR_VECTORS[direction] * projectile_speed_px_s`. `projectile_speed_px_s = 600.0` Tier 1 default (tuning range 400..800; 800+는 hitscan 시각 인식, 400 미만은 magic-bolt aesthetics).
- **Despawn**: `Engine.get_physics_frames() - _spawn_frame >= PROJECTILE_LIFETIME_FRAMES` → `queue_free()`. Tier 1 default 90 frames (~900 px @ 600 px/s; 1280px viewport 안전 clearance). NOT `VisibleOnScreenNotifier2D` (camera-relative, ADR-0001 player-only rewind에서 nondeterministic). Tuning `projectile_lifetime_frames: int`, safe 60..120.
- **Hit handler**: `area_entered(area: Area2D)` connect → `if area is HurtBox: queue_free()`. No pierce in Tier 1; 동프레임 다중 hit는 damage.md C.3.2 step 0 `_pending_cause != &""` 가드가 처리. Pierce / multi-hit는 Tier 2+ 무기 영역.

**규칙 4 (Ammo 모델 — magazine + 즉시 auto-reload)** — Initial: `_ready()`에서 `ammo_count = MAGAZINE_SIZE = 30`. Per `_try_fire()` 성공: `ammo_count -= 1`. 감소 후 `ammo_count == 0`이면 같은 tick에 `ammo_count = MAGAZINE_SIZE` auto-reload (Tier 1 `reload_frames = 0` — animation 없음). Tier 2+ pickup 도입 시 `reload_frames > 0` 분리 가능. Tuning `magazine_size: int` (10..60), `reload_frames: int` (Tier 1=0; Tier 2+ 0..60). **Pillar 4 5분 룰 — first shot immediate at boot**.

**규칙 5 (Firing guard ladder — INV-WS-1/2 enforcement site)** — `_try_fire()` 순차 가드, 어느 하나라도 fail 시 즉시 return (bool short-circuit, PM-B1 패턴):

| Guard | PASS condition (사격 허용) | Source |
|---|---|---|
| **G1** | `_active == true` | WeaponSlot internal (C.2 lifecycle subscription) |
| **G2** | `EchoLifecycleSM.current_state ∉ {DyingState, DeadState}` | state-machine.md C.2.1 (defense in depth, G1 mirror) |
| **G3** | `_player._is_restoring == false` | PM C.4.4 reciprocal (anim method-track cascade 가드) |
| **G4** | NOT (`_fire_cooldown_active` AND `Engine.get_physics_frames() - _fire_cooldown_frame < FIRE_COOLDOWN_FRAMES`) | 규칙 1 |
| **G5** | `ammo_count > 0` (규칙 4 auto-reload *후* 평가) | 규칙 4 |

> **REWINDING PASSes G1/G2** — time-rewind.md C.3 Rule 10 "REWINDING permits full input including firing from frame 1" (Approved 2026-05-10, locked). G3 (`_is_restoring`)이 restore tick만 차단; 그 외 REWINDING 프레임은 사격 허용. 본 결정은 Section B fantasy ("두 동사, 한 몸")의 메커닉 보호.
>
> **aim_lock PASSes** — PM DEC-PM-Decision C "aim_lock frees 8-way arm with frozen movement"는 정밀-사격 stance 의도. WeaponSlot은 aim_lock 별도 폴링 X (PM이 movement freeze 책임 단일 출처).

**규칙 6 (Concurrent projectile cap — INV-WS-3)** — `_active_projectile_count: int` member 유지. 사격 spawn 시점 `if _active_projectile_count >= PROJECTILE_CAP: return` silent skip (no SFX/VFX/error). `PROJECTILE_CAP = 8` Tier 1 default. Spawn 시 `_active_projectile_count += 1`; Projectile `tree_exiting` 시그널 → WeaponSlot handler `_active_projectile_count -= 1` (signal 기반 deterministic decrement). Tuning `projectile_cap: int`, safe 4..16.

**규칙 7 (Projectile parent target — Stage 호스팅, ECHO subtree 외부)** — `add_child` target = `get_tree().current_scene.find_child("Projectiles", true, false)`. NOT WeaponSlot's subtree — ECHO transform inheritance가 PM `restore_from_snapshot()` 이후 invalid 위치로 displace됨. ADR-0001 player-only scope 정합 (projectile은 rewind 대상이 아니므로 ECHO subtree 외부). **Stage GDD #12 (Not Started) F.4.1 obligation**: stage scene root는 `Projectiles: Node2D` 명명 노드를 포함해야 함; Scene Manager `scene_will_change` 시 컨테이너 free (scene-manager.md Rule 4).

**규칙 8 (HitBox attachment — 자식 Area2D + layer 분리)** — Projectile `.tscn` 노드 트리:

- `Projectile (Area2D, root)` — 지형 despawn 용 (collision_mask = terrain layer, Stage GDD #12 결정)
- `└── HitBox (class_name HitBox extends Area2D from damage.md)` — `collision_layer = 2`, `collision_mask = 3 | 6`, `monitoring = true`, `cause = &""` (damage.md C.1.1 ECHO default), `host = projectile_root`
- `    └── CollisionShape2D` (HitBox 자식)

별도 Area2D 분리 이유: root는 지형, HitBox는 적/보스 — layer 의미 충돌 방지 (damage.md C.2.4 표).

**규칙 9 (Self-fire 차단 — Godot 4.6 collision filter)** — ECHO Projectile HitBox `collision_layer = 2`, `collision_mask = 3 | 6`. ECHO HurtBox `collision_layer = 1`. layer 2 mask가 layer 1을 포함하지 않으므로 Godot 4.6 충돌 엔진이 `area_entered` emit 자체를 사전 차단. 코드 가드 불필요 (damage.md C.2.4 verbatim 일치). Same-frame ECHO 자해 차단 완전.

**규칙 10 (Knockback / hit-stop 부재 — PM C.1.3 movement 비준)** — `_try_fire()` 성공이 `_player.velocity`를 mutation하지 않음. PM C.1.3 movement vector는 PM 단일 출처. Camera micro-shake / 화면 흔들림 등 juice는 Camera #3 / VFX #14가 `shot_fired(direction: int)` 시그널 구독으로 처리 — 본 GDD는 시그널 *발화*만 명세, juice 디자인은 다운스트림 own. Section B fantasy "uninterrupted motion"의 메커닉 보호 (movement 흔들림 = 흐름 단절).

**규칙 11 (`set_active(invalid_id)` silent fallback — OQ-3 closure)** — `WeaponSlot.set_active(weapon_id: int) -> void`:

1. `if not WeaponConfig.is_valid_id(weapon_id): push_warning("WeaponSlot.set_active invalid id %d → no state change" % weapon_id); weapon_fallback_activated.emit(weapon_id); return` — state mutation 없음; VFX #14 + Audio가 fallback-specific 큐 발화 가능.
2. `if weapon_id == _active_id: return` — idempotent (동일 무기 재요청).
3. `_active_id = weapon_id; ammo_count = MAGAZINE_SIZE; weapon_equipped.emit(weapon_id)` — Pickup이 새 무기 ID 적용 시 정상 path.

본 결정으로 **time-rewind.md OQ-3 closed**. `weapon_fallback_activated(requested_id: int)` 신규 시그널은 `weapon_equipped`와 의미 분리 (fallback 식별 가능). Tier 1 single-weapon에서는 호출되지 않음; Tier 2 pickup이 첫 활성 site.

**규칙 12 (Initial boot — Tier 1 base rifle equip)** — `WeaponSlot._ready()` 종료 시점:

- `_active_id = 0` (base rifle ID); `ammo_count = MAGAZINE_SIZE`
- `weapon_equipped.emit(0)` 호출 → PM `_on_weapon_equipped(0)` subscriber가 `_current_weapon_id = 0` cache 갱신
- `@export var trc: TimeRewindController` declarative reference 검증 (null이면 boot assert; time-rewind.md C.3 row #6 wiring 패턴)

Tier 1 single-weapon — `_active_id`는 plot 흐름에서 항상 0; Tier 2+ pickup이 0 → {1, 2, 3} mutation 도입.

### C.2 States and Transitions

#### C.2.1 No state machine — read-driven design

WeaponSlot은 별도 StateMachine 자식 노드를 호스팅하지 *않는다*. PM (`PlayerMovementSM` 6 states), state-machine.md (`EchoLifecycleSM` 4 states)와 달리 본 시스템은 *behavioral phase*가 없으며 read-driven member-var + guard ladder 패턴으로 동작한다. Tier 2 weapon swap 디자인이 행동 phase를 필요로 할 때 SM 도입 재평가 (Pillar 5 — 작은 성공 > 큰 야심).

#### C.2.2 Member variable declarations (canonical site)

```gdscript
class_name WeaponSlot extends Node2D
# canonical path: src/gameplay/player_shooting/weapon_slot.gd

# --- Snapshot-exposed (ADR-0002 Amendment 2 — Weapon single-writer 단일 출처) ---
var ammo_count: int = 0  # initial set in _ready(); TRC reads per-tick via time-rewind.md AC-A1 Step (b)

# --- Lifecycle gating (INV-WS-5 single-writer) ---
var _active: bool = true  # written ONLY by _on_lifecycle_state_changed handler

# --- Weapon identity ---
var _active_id: int = 0  # Tier 1 base rifle; Tier 2+ pickup mutates

# --- Cooldown gate (bool short-circuit per PM-B1 active-flag pattern) ---
var _fire_cooldown_active: bool = false  # active-flag — INV-WS-4 prevents int overflow
var _fire_cooldown_frame: int = 0  # Engine.get_physics_frames() stamp; not consulted unless _fire_cooldown_active

# --- Concurrent projectile cap (INV-WS-3) ---
var _active_projectile_count: int = 0

# --- Wiring (declarative @export — null = boot assert; mirrors time-rewind.md C.3 #6 pattern) ---
@export var player: PlayerMovement
@export var muzzle: Marker2D
@export var projectile_scene: PackedScene
@export var trc: TimeRewindController
@export var lifecycle_sm: StateMachine  # EchoLifecycleSM reference

# --- Locked constants (Tier 1 defaults — tuning knobs in assets/data/weapons.tres override) ---
const FIRE_COOLDOWN_FRAMES_DEFAULT: int = 10
const MAGAZINE_SIZE_DEFAULT: int = 30
const PROJECTILE_CAP_DEFAULT: int = 8
const PROJECTILE_SPEED_PX_S_DEFAULT: float = 600.0
const PROJECTILE_LIFETIME_FRAMES_DEFAULT: int = 90
```

#### C.2.3 Lifecycle 동기화 (`_active` ownership — INV-WS-5)

`_active`는 WeaponSlot이 단일 writer이며 `EchoLifecycleSM.state_changed(from: StringName, to: StringName)` 시그널 구독으로 driven. 외부 어느 시스템도 `_active`에 직접 쓰지 않음.

```gdscript
func _ready() -> void:
    assert(player != null, "WeaponSlot.player must be set in editor")
    assert(projectile_scene != null, "WeaponSlot.projectile_scene must be set")
    assert(trc != null, "WeaponSlot.trc must be set (time-rewind.md C.3 #6 pattern)")
    assert(lifecycle_sm != null, "WeaponSlot.lifecycle_sm must be set")

    ammo_count = MAGAZINE_SIZE_DEFAULT  # 규칙 4 initial
    _active_id = 0                       # 규칙 12 Tier 1 base rifle
    lifecycle_sm.state_changed.connect(_on_lifecycle_state_changed)
    weapon_equipped.emit(_active_id)     # 규칙 12 PM subscriber notify

func _on_lifecycle_state_changed(_from: StringName, to: StringName) -> void:
    match to:
        &"AliveState", &"RewindingState":
            _active = true  # TR Rule 10 — REWINDING permits firing
        &"DyingState", &"DeadState":
            _active = false
        _:
            push_warning("WeaponSlot: unexpected lifecycle state %s" % to)
```

> **REWINDING `_active = true` 정합 (TR Rule 10 honor)**: time-rewind.md C.3 Rule 10 "REWINDING permits full input including firing from frame 1" — REWINDING 진입 시 `_active = true` 유지. 사격 차단은 G3 (`_is_restoring`) restore tick 1회만 발생.

#### C.2.4 Cross-state behavior 합본표

본 표는 EchoLifecycle × PlayerMovement × `_is_restoring` × `_active` 조합 전수를 Guard ladder (규칙 5) 결과로 매핑한다.

| EchoLifecycle | PlayerMovement | `_is_restoring` | `_active` | _try_fire 결과 |
|---|---|---|---|---|
| `AliveState` | `IDLE` / `RUN` | false | true | **PASS** (G1..G5 모두 평가) |
| `AliveState` | `JUMPING` / `FALLING` | false | true | **PASS** (game-concept "점프+사격 동시") |
| `AliveState` | `aim_lock` (Tier 2+) | false | true | **PASS** (PM DEC-PM-Decision C 정밀-사격 stance) |
| `RewindingState` | `REWINDING` | false | true | **PASS** (TR Rule 10) — Section B fantasy "두 동사, 한 몸" 보존 |
| `RewindingState` | `REWINDING` | **true** (restore tick 1회) | true | **BLOCK** at G3 (PM C.4.4 reciprocal — anim method-track cascade 가드) |
| `DyingState` | `DYING` (12-frame grace) | false | **false** | **BLOCK** at G1 (lifecycle gating — DYING은 사격 불가) |
| `DeadState` | `dead` | false | false | **BLOCK** at G1 |

> **DYING grace 정합**: damage.md DEC-6 + time-rewind.md C.3 Rule 10이 보장하는 12-frame DYING 윈도우(rewind 입력 grace)에서 사격은 차단된다. 본 grace는 *rewind 입력*을 위한 것이지 사격을 위한 것이 아님 (Pillar 1 학습-도구 시맨틱: 죽음 직전 사격으로 "탈출"하는 것은 fantasy 위반).

#### C.2.5 In-flight projectile 처리 (rewind 시점 ADR-0001 정합)

REWINDING 진입 시점에 이미 spawn된 projectile은 *rewind 대상이 아니다* — ADR-0001 player-only scope 단일 출처.

- **위치 / 속도 유지**: Projectile은 본 GDD 규칙 3 fixed-step motion을 계속 진행. PM이 9프레임 전 `global_position`으로 복원되어도 projectile은 *원래 진행 방향과 속도*로 유지.
- **수명 카운터 유지**: `_spawn_frame: int = Engine.get_physics_frames()` 시점 stamp; TR이 frame counter를 manipulate하지 않으므로 lifetime expiry는 정상 진행.
- **`_active_projectile_count` 정합**: Projectile `tree_exiting` 시그널이 발화될 때만 decrement; rewind는 트리 mutation을 일으키지 않으므로 cap counter는 보존.
- **Pickup 영구 소비 정합 (time-rewind.md E-14 mirror)**: Tier 2+에서 ECHO가 무기 픽업 직후 사망하고 복원되면 *픽업 자체는 복원되지 않음*; ECHO는 `_active_id`가 새 무기 ID로 유지된 채 `MAGAZINE_SIZE` ammo로 부활. one-way world mutation.
- **Section B fantasy 정합**: "흐름의 연료"로서 ammo는 *복원*되지만 *이미 발사된 총알*은 복원되지 않는다 — 시간을 되돌리는 것은 ECHO 자신이지 세계가 아니라는 픽션 단일 출처 (game-concept Pillar 1 narrative — "VEIL의 모델 외부").

#### C.2.6 TRC 동기 호출 contract (OQ-PM-NEW (a) lock site)

OQ-PM-NEW lock: TRC orchestration. `WeaponSlot`은 `rewind_completed` 시그널을 구독하지 *않으며*, 대신 TRC가 본 시스템의 `restore_from_snapshot(snap)` 메서드를 *동기 호출*한다.

```gdscript
# WeaponSlot — TRC가 동기 호출하는 entry point (signal NOT used)
func restore_from_snapshot(snap: PlayerSnapshot) -> void:
    # OQ-PM-NEW (a) lock — TRC orchestration, NOT signal subscription
    # Caller: TRC.try_consume_rewind() inside C.3 Rule 9 atomic sequence
    ammo_count = snap.ammo_count
    # Tier 1 single-weapon: snap.current_weapon_id always 0, _active_id 변경 없음
    # Tier 2+: if snap.current_weapon_id != _active_id: 무기 reload + weapon_equipped 재발화 (deferred)
```

**TRC C.3 Rule 9 시퀀스 (단일 tick, atomic)** — 본 GDD가 F.4.1 #2로 time-rewind.md C.3 Rule 9 pseudocode 갱신 의무:

1. `_player.restore_from_snapshot(snap)` — PM 7-필드 복원 (`snap.ammo_count` ignore per PM C.1.3)
2. `_weapon_slot.restore_from_snapshot(snap)` — WeaponSlot이 `ammo_count` 복원 (본 GDD method)
3. `rewind_completed.emit(player, restored_to_frame)` — **W2-locked signature 유지** (변경 없음)

3-step은 TRC `_physics_process` (`process_physics_priority = 1`) 내부에서 동기 실행. WeaponSlot 자체 `_physics_process` (`priority = 0` default; ECHO subtree 자식이므로 PM 직후 tree 순서)는 같은 tick에서 TRC 호출 *이전*에 이미 실행되었으나 — restore는 *direct method 호출*이므로 priority 순서와 무관 (TRC가 명시적으로 호출). 다음 tick `_try_fire()` 도달 시 ammo는 이미 복원된 상태.

### C.3 Interactions with Other Systems

본 절은 본 시스템이 발생시키는 cross-system 계약을 *direction × strength*로 분류한다 — F.1 Dependencies 표가 이 절의 entry point다.

#### C.3.1 Input System (#1) — Hard upstream

- **Polling 출처**: `Input.is_action_pressed("shoot")` (input.md C.1.1 row 7 — 본 GDD가 detect mode를 `is_action_pressed` (hold)로 lock; F.4.1 #1).
- **Polling 시점**: WeaponSlot `_physics_process` 내부 (input.md C.1.5 Phase 2 reader contract — 게임플레이 시스템은 `_physics_process` 안에서만 input 폴링).
- **Active profile coherence**: WeaponSlot은 KB+M / Gamepad 차이를 *읽지 않음* — Input #1의 ActiveProfileTracker autoload가 단일 출처. WeaponSlot은 `shoot` action만 폴링.
- **No deadzone re-read**: stick magnitude는 PM `facing_direction` 계산 시점에 이미 처리. WeaponSlot은 PM의 `facing_direction` int 0..7만 read.

#### C.3.2 Player Movement (#6) — Hard upstream + downstream

**Upstream (PM → WeaponSlot read)**:

- `_player.facing_direction: int` (PM C.1.3 row #3) — 발사 방향 단일 출처
- `_player._is_restoring: bool` (PM C.4.4 single-source guard flag) — G3 guard 평가

**Downstream (WeaponSlot → PM emit)**:

- `signal weapon_equipped(weapon_id: int)` 발화 — PM `_on_weapon_equipped` subscriber가 `_current_weapon_id` cache 갱신; PM C.4.5 `_is_restoring` 가드 적용
- `signal shot_fired(direction: int)` 발화 (Tier 1 optional, Tier 2+ obligatory) — PM 자체는 구독 X (movement 영향 없음); Camera #3 / VFX #14 / Audio가 잠재 구독자

**Spawn 트리거 단일-site 결정 (Tier 1 design call)**:
WeaponSlot `_try_fire`가 `spawn_projectile(facing_direction)` direct 호출 단일 site. PM의 `_on_anim_spawn_bullet`은 *guard hook으로만 존재* (PM C.4.4 `_is_restoring` 가드 단일 출처 유지) — 실제 method-track 키프레임은 Tier 1 anim에 추가 X (animation frame delay 회피, "uninterrupted motion" fantasy 보호). Tier 2+ 무기 wind-up anim 도입 시 method-track 활성화 + WeaponSlot._try_fire는 fire decision만 분리. **단일-spawn-site INVARIANT**: 어느 Tier에서도 spawn_projectile 호출은 동일 input 결정에서 *한 번만* 발생 (direct OR method-track, 둘 다 X).

**Cross-doc reciprocal obligation**:

- PM F.4.2 `Player Shooting #7` row의 (a)/(b)/(c) 의무 close: (a) `weapon_equipped(weapon_id: int)` 시그너처 정의 ✅ (본 GDD), (b) `_on_anim_spawn_bullet` `_is_restoring` 가드는 PM 단일 출처 유지, (c) ammo restoration은 DEC-PM-3 v2 ammo policy를 Weapon-side 단일 writer로 비준 (본 GDD 규칙 4 + ADR-0002 Amendment 2 ratification gate close).

#### C.3.3 Damage / Hit Detection (#8) — Hard downstream (HitBox host)

- **HitBox 인스턴스화**: 본 GDD 규칙 8 — Projectile `.tscn`의 자식 `Area2D` (class_name HitBox from damage.md C.1.1). `collision_layer = 2`, `collision_mask = 3 | 6`, `monitoring = true` (damage.md DEC-4), `cause = &""` (damage.md F.1 표 #7), `host = projectile_root_area2d`.
- **damage.md F.1 표 #7 obligation honored**: ECHO Projectile HitBox 인스턴스화 책임 = Player Shooting #7. damage.md 자체는 *클래스 정의*만 제공. 본 GDD가 *.tscn 인스턴스 구성* 단일 출처.
- **Hit detection emit**: damage.md C.1.2 단일 emit 지점 = HitBox 스크립트 (`area_entered` → `hurtbox_hit.emit(cause)`). 본 GDD는 hit emit 재구현 X.
- **Projectile despawn 트리거**: 본 GDD 규칙 3 `Projectile.area_entered(area)` → `if area is HurtBox: queue_free()` — 본 GDD root Area2D 책임. Tier 1 1-hit-1-kill: queue_free 즉시.
- **damage.md GDD 갱신 의무 없음** — F.4.1 cross-doc edit 불필요.

#### C.3.4 Time Rewind System (#9) — Hard upstream + downstream (OQ-PM-NEW lock site)

**Upstream (TRC → WeaponSlot read per-tick)**:

- TRC `_capture_to_ring()` Step (b)에서 `WeaponSlot.ammo_count` *read* (time-rewind.md AC-A1 3-tier ownership). TRC는 `ammo_count`에 *쓰지 않음*.

**Downstream (TRC → WeaponSlot direct method 호출 — OQ-PM-NEW (a) orchestration)**:

- TRC `try_consume_rewind() == true` 직후 atomic 시퀀스 (C.2.6 단일 출처): (1) `_player.restore_from_snapshot(snap)`, (2) `_weapon_slot.restore_from_snapshot(snap)` **← 본 GDD method**, (3) `rewind_completed.emit(player, restored_to_frame)` (W2-locked signature 유지).
- **본 GDD가 time-rewind.md C.3 Rule 9 pseudocode + AC-A4 갱신 의무** (F.4.1 #2): Rule 9 pseudocode에 step 2 추가; AC-A4 assertion 보강 (PM 7-필드 + WeaponSlot.ammo_count 모두 복원 검증).
- **OQ-PM-NEW closure**: (a) TRC orchestration 락인. (b) signal subscription 폐기 (W2-locked signature에 snap 부재로 dead-on-arrival).

**ADR-0002 Amendment 2 ratification gate close**: 본 시스템 Designed 상태 도달 시 `/architecture-review`에서 Amendment 2 Proposed → Accepted. 본 GDD는 `ammo_count` Weapon single-writer + Weapon-side restoration 메커니즘 (a 변형) 단일 출처.

#### C.3.5 State Machine Framework (#5) — Hard upstream (EchoLifecycleSM 구독)

- `EchoLifecycleSM.state_changed(from: StringName, to: StringName)` 구독 — `_on_lifecycle_state_changed` handler가 `_active` toggle (C.2.3).
- WeaponSlot은 `EchoLifecycleSM`의 *state read*만 수행 (G2 guard 시 `lifecycle_sm.current_state` 비교); state 전이 *trigger*하지 않음. SM `transition_to()` 호출 금지 (state-machine.md `cross_entity_sm_transition_call` forbidden_pattern 정합).
- **state-machine.md F.2 row #7 추가 의무 (F.4.1 #3)**: 신규 row "Player Shooting #7" 추가 — subscribes `state_changed`; transition 트리거 X; 단방향 read-only.

#### C.3.6 Scene Manager (#2) — Soft upstream (scene lifecycle 정합)

- **Projectiles 컨테이너 free**: scene-manager.md Rule 4 `scene_will_change` 시 Stage 씬 swap — Stage Projectiles 컨테이너 자식 모든 projectile은 Godot scene tree 의미론으로 자동 `queue_free`. WeaponSlot은 별도 cleanup 필요 없음.
- **Restart 시 ammo / cooldown ephemeral 처리**: scene_manager Rule 9 restart_window_max_frames=60 lifecycle 내부에서 WeaponSlot은 새 scene 인스턴스의 새 `_ready()`에서 `ammo_count = MAGAZINE_SIZE` 재설정 (Pillar 4 fresh restart).
- **Phase 5d 의무 없음** — Scene Manager F.4.1 cascade 없음.

#### C.3.7 Stage / Encounter (#12, Not Started) — Soft downstream (Projectiles 컨테이너 호스팅)

- **Stage 씬 root 의무**: Stage `.tscn`의 root 자식에 `Projectiles: Node2D` 명명 노드 1개 필수. WeaponSlot은 `get_tree().current_scene.find_child("Projectiles", true, false)` lookup; null이면 push_error (assert 형 — Stage 디자인 위반).
- **F.4.2 Stage GDD #12 obligation 발생**: Stage GDD H section에 "Projectiles: Node2D 명명 노드 root 자식 존재" AC 추가 의무 (본 GDD F.4.2 #1).
- Stage GDD는 *Not Started* — 본 의무는 *deferred until Stage 작성*.

#### C.3.8 HUD System (#13, Not Started) — Soft downstream (signal subscriber)

- `weapon_equipped(weapon_id: int)` 구독 → 무기 아이콘 변경
- `WeaponSlot.ammo_count` read → ammo counter UI 렌더 (per-tick polling 또는 새 시그널 `ammo_changed(new_count: int)` — HUD GDD 작성 시 결정)
- `weapon_fallback_activated(requested_id: int)` 구독 → optional "잘못된 무기" 인디케이터
- **F.4.2 HUD GDD obligation 발생** — HUD GDD H section에 위 3 contract AC.

#### C.3.9 VFX / Particle (#14, Not Started) — Soft downstream (signal subscriber + near-miss)

- `shot_fired(direction: int)` 구독 → 발사 muzzle flash VFX 트리거
- `weapon_fallback_activated(requested_id: int)` 구독 → optional "잘못된 무기" 시각 글리치
- **Near-miss obligation 영구 유지** (damage.md DEC-3): VFX #14가 ECHO projectile destroy 시점 (본 GDD 규칙 7 `queue_free()`) 데이터로 *자체 근접 판정* — 본 GDD는 near-miss 정보 *발행하지 않음*. damage.md DEC-3 사전 lock.

#### C.3.10 Audio System (#4, Not Started) — Soft downstream (signal subscriber)

- `shot_fired(direction: int)` 구독 → 사격 SFX 발화 (`sfx_player_shoot_rifle_01.ogg` placeholder Tier 1)
- `weapon_fallback_activated(requested_id: int)` 구독 → optional 큐
- **F.4.2 Audio GDD obligation 발생**.

#### C.3.11 Camera System (#3, Not Started) — Soft downstream

- `shot_fired(direction: int)` 구독 → 카메라 micro-shake (Camera GDD가 intensity / duration / falloff 결정).
- 본 GDD는 카메라 흔들림 spec 비명세; 시그널 발화만 책임 (규칙 10 단일 출처).

#### C.3.12 Pickup System (#19, Tier 2 deferred) — Soft downstream

- Pickup의 무기 픽업 이벤트가 `WeaponSlot.set_active(weapon_id)` direct 호출 (본 GDD 규칙 11 entry point).
- Invalid id 시 `weapon_fallback_activated` 시그널 발화 — Pickup GDD가 invalid id 발생 조건 lock 의무 (Tier 2 디자인).
- **F.4.2 Pickup GDD #19 obligation**.

#### C.3.13 ADR Architecture Decision 정합 (Locked references)

- **ADR-0001 (Accepted)**: ECHO-only rewind 정책 정합 — projectile은 normal simulation 유지 (C.2.5).
- **ADR-0002 Amendment 2 (Proposed → Accepted via 본 GDD)**: `ammo_count` 8번째 PM-노출 필드 Weapon single-writer; Weapon-side restoration = (a) TRC orchestration (본 GDD C.2.6). 본 GDD Designed 시 비준 게이트 close.
- **ADR-0003 (Accepted)**: projectile = `Area2D` + 직접 transform + `process_physics_priority = 20` 단일 출처 (C.1 규칙 5, 11). `1.0 / 60.0` fixed delta. AC-F1 결정성 검증에 본 시스템 발사체 포함.

본 절의 모든 cross-system 계약은 F.1 Dependencies 표에서 *direction × strength × interface*로 합본된다. F.4.1 cross-doc edit 의무는 F 섹션에서 단일 출처.

## D. Formulas

본 시스템은 6개 명명된 공식을 정의한다. 모든 공식은 (변수 표 + range + worked example) 트리플을 갖는다 — 기계적 implementability 단일 출처.

### D.1 Fire cooldown elapsed (G4 guard 평가)

The `fire_cooldown_elapsed_frames` formula is defined as:

`fire_cooldown_elapsed_frames = Engine.get_physics_frames() - _fire_cooldown_frame`

**Variables**:

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current frame | `Engine.get_physics_frames()` | int | 0..2^31-1 (monotonic) | 현재 physics tick index |
| Last fire frame | `_fire_cooldown_frame` | int | 0..2^31-1 | 직전 성공 사격 tick stamp (`_try_fire` 성공 시점 기록) |
| Cooldown threshold | `FIRE_COOLDOWN_FRAMES` | const int | 10 (tunable 6..20) | 사격 간 최소 간격 (60Hz frame 단위) |

**Output range**: 0..2^31-1 (delta는 항상 ≥0; PM-B1 int overflow 방지 — `_fire_cooldown_active == false`일 때 본 공식 비참조, bool short-circuit).

**G4 PASS 조건**: `(NOT _fire_cooldown_active) OR (fire_cooldown_elapsed_frames >= FIRE_COOLDOWN_FRAMES)`.

**Example**: `_fire_cooldown_frame = 1000`, `Engine.get_physics_frames() = 1015` → elapsed = 15; 15 ≥ 10 → G4 PASS, 사격 허용. tick 1009에서는 elapsed = 9; 9 < 10 → G4 BLOCK.

### D.2 Effective fire rate (derived from D.1)

The `effective_rps` formula is defined as:

`effective_rps = 60.0 / FIRE_COOLDOWN_FRAMES`

**Variables**: `FIRE_COOLDOWN_FRAMES` (tuning knob, int 6..20). `60.0` = physics_ticks_per_second (`technical-preferences.md` 락인).

**Output range**: 3.0..10.0 rounds/sec (defaults to 6.0). **Tier 1 default** = 6.0 rps (Contra III / Hard Corps baseline; C.1 규칙 1 인용).

**Example**: FIRE_COOLDOWN_FRAMES = 10 → effective_rps = 6.0. 10초 hold-fire 60발 = 2 magazine reload (D.5 auto-reload 통해). FIRE_COOLDOWN_FRAMES = 20 → 3.0 rps (느린 deliberate 사격).

### D.3 Projectile motion (per-tick position step — ADR-0003 결정성 단일 출처)

The `projectile_position_step` formula is defined as:

```text
new_position = current_position + velocity * FIXED_DELTA
velocity = _DIR_VECTORS[direction] * projectile_speed_px_s
FIXED_DELTA = 1.0 / 60.0   # Godot physics tick rate
```

**Variables**:

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Spawn 시점 facing | `direction` | int | 0..7 (PM enum) | PM `facing_direction` 인계 (CCW from East per `api_decisions.facing_direction_encoding`) |
| Lookup vector | `_DIR_VECTORS[direction]` | Vector2 | length=1 (모든 8개 정규화) | 방향 unit vector |
| 발사체 속도 | `projectile_speed_px_s` | float | 400..800 (Tier 1 default 600) | weapons.tres tuning knob |
| Fixed delta | `FIXED_DELTA` | const float | 1.0/60.0 = 0.0166667 | physics tick 간격 |

**`_DIR_VECTORS` 합본표** (대각선 정규화 — Pillar 2 결정성: 대각 사격이 수평/수직 사격과 동일 속도, "diagonal advantage" 봉쇄):

| direction | 8-방향 | `_DIR_VECTORS[i]` |
|---|---|---|
| 0 | E | `Vector2(1.0, 0.0)` |
| 1 | NE | `Vector2(0.7071, -0.7071)` |
| 2 | N | `Vector2(0.0, -1.0)` |
| 3 | NW | `Vector2(-0.7071, -0.7071)` |
| 4 | W | `Vector2(-1.0, 0.0)` |
| 5 | SW | `Vector2(-0.7071, 0.7071)` |
| 6 | S | `Vector2(0.0, 1.0)` |
| 7 | SE | `Vector2(0.7071, 0.7071)` |

**Output range**: position step magnitude = `projectile_speed_px_s * FIXED_DELTA` ≈ 600/60 = **10 px/frame** at Tier 1 defaults (tuning range 6.67..13.33 px/frame).

**Example**: spawn at `(100, 50)`, direction=1 (NE), speed=600 → tick 1: position = `(100 + 10*0.7071, 50 + 10*(-0.7071))` = `(107.07, 42.93)`. tick 90: position = `(100 + 90*10*0.7071, 50 + 90*10*(-0.7071))` = `(736.4, -586.4)` — viewport 1280×720 외부, D.4 lifetime expiry 도달.

### D.4 Projectile lifetime check (deterministic despawn)

The `projectile_lifetime_elapsed_frames` formula is defined as:

`projectile_lifetime_elapsed_frames = Engine.get_physics_frames() - _spawn_frame`

**Variables**:

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Spawn 시점 | `_spawn_frame` | int | 0..2^31-1 | Projectile `_ready()`에서 `Engine.get_physics_frames()` stamp |
| Lifetime ceiling | `PROJECTILE_LIFETIME_FRAMES` | const int | 90 (tunable 60..120) | despawn threshold |

**Output range**: 0..2^31-1 (monotonic). **Despawn 조건**: `>= PROJECTILE_LIFETIME_FRAMES` → `queue_free()` (C.1 규칙 3).

**Derived max distance**: `max_distance_px = (PROJECTILE_LIFETIME_FRAMES * projectile_speed_px_s) / 60` = `(90 * 600) / 60` = **900 px** at Tier 1 defaults (viewport 1280×720에서 1.4x clearance — 모든 미스 발사체는 화면 밖에서 despawn).

**Example**: `_spawn_frame = 5000`, tick 5089 → elapsed = 89; 89 < 90 → 유지. tick 5090 → elapsed = 90; 90 ≥ 90 → `queue_free()`.

### D.5 Magazine auto-reload (즉시 round-trip)

The `ammo_count_post_fire` formula is defined as:

```text
if ammo_count > 0:
    ammo_count = ammo_count - 1
    if ammo_count == 0:
        ammo_count = MAGAZINE_SIZE   # Tier 1 즉시 auto-reload (reload_frames = 0)
```

**Variables**:

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Magazine size | `MAGAZINE_SIZE` | const int | 30 (tunable 10..60) | round capacity per magazine |
| Pre-fire ammo | `ammo_count_in` | int | 1..MAGAZINE_SIZE | 사격 진입 시점 ammo (G5 PASS 조건이 보장 > 0) |

**Output range**: `ammo_count_post_fire ∈ {1, 2, ..., MAGAZINE_SIZE}` (0 fixed-point 부재 — auto-reload이 항상 ≥1 보장).

**Tier 2+ generalization**: `reload_frames > 0` 도입 시 `ammo_count = 0` 상태 유지 + `_reload_active = true` + `_reload_frame = Engine.get_physics_frames()` 기록; reload elapsed `>= reload_frames` 도달 시 `ammo_count = MAGAZINE_SIZE` (Tier 1 reload_frames=0이므로 동일 tick 즉시).

**Example**: ammo_count_in = 1, _try_fire 성공 → decrement → 0 → auto-reload trigger → ammo_count = 30 (다음 사격 즉시 가능). ammo_count_in = 30, _try_fire 성공 → 29 (auto-reload 미발동).

### D.6 Ammo restore round-trip identity (ADR-0002 Amendment 2 ratification — Pillar 1 단일 출처)

The `ammo_count_restored` formula is defined as:

```text
ammo_count_restored = snap.ammo_count   # where snap = ring_buffer[restore_idx]
restore_idx = (_lethal_hit_head - RESTORE_OFFSET_FRAMES + REWIND_WINDOW_FRAMES) % REWIND_WINDOW_FRAMES
```

**Variables** (모두 ADR-0002 Amendment 2 + entities.yaml 단일 출처):

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Lethal hit frame stamp | `_lethal_hit_head` | int | 0..89 | TRC가 lethal hit 시점 `_write_head` cache (Amendment 1 — `try_consume_rewind_restore_idx` formula 변수) |
| Restore offset | `RESTORE_OFFSET_FRAMES` | const int | 9 (entities.yaml) | 0.15s pre-death @ 60Hz |
| Window size | `REWIND_WINDOW_FRAMES` | const int | 90 (entities.yaml) | 1.5s lookback @ 60Hz |
| Snap ammo field | `snap.ammo_count` | int | 0..MAGAZINE_SIZE | PlayerSnapshot 8번째 PM-노출 필드 (ADR-0002 Amendment 2) |

**Output range**: 0..MAGAZINE_SIZE (snap.ammo_count의 도메인 일치).

**Pillar 1 contract**: rewind 성공 시 ECHO는 *DYING 윈도우 중 0으로 떨어진 ammo*가 아닌 *9프레임 전 시점의 ammo*로 회복 — "처벌이 아닌 학습 도구" 단일 출처 (Section B fantasy "흐름의 연료" 메커닉 구현).

**Example**: `_lethal_hit_head = 42`, `RESTORE_OFFSET_FRAMES = 9`, `REWIND_WINDOW_FRAMES = 90` → `restore_idx = (42 - 9 + 90) % 90 = 123 % 90 = 33`. Slot 33의 ammo (= 9프레임 전 ammo) 복원. DYING window 12프레임 + restore offset 9프레임 = 21프레임 전 ammo가 복원 source 후보 (구체 값은 plot/playtest 종속). 만약 21프레임 전 ammo가 5였다면 복원 후 5; rewind 직전 0이었어도 복원 후 5.

**Cross-doc 정합**: 본 공식은 `try_consume_rewind_restore_idx` formula (entities.yaml; ADR-0002 Amendment 1)의 ammo-field-specific instantiation. PM 7-필드 + Weapon 1-필드 (`ammo_count`)는 동일 `restore_idx`로 atomic 복원 (C.2.6 단일 출처).

## E. Edge Cases

본 절은 본 시스템의 비통상 상황을 *condition → exact outcome* 형식으로 합본한다. 모든 edge case는 BLOCKING 또는 OK; 모호한 "appropriately handle" 금지.

### E-PS-1 (Hold-fire 중 cooldown 잔여)

**If** 플레이어가 `Input.is_action_pressed("shoot") == true` 유지하고 `fire_cooldown_elapsed_frames < FIRE_COOLDOWN_FRAMES` (G4 BLOCK): WeaponSlot `_try_fire`은 silent return — 사격 효과음 / VFX / projectile spawn 발생 X. cooldown 경과 시점부터 다음 tick `_try_fire`이 PASS하여 정상 사격 재개. **결과**: 연속 hold-fire는 cooldown counter에 의해 정확히 `effective_rps` (Tier 1 = 6 rps)로 페이스.

### E-PS-2 (ammo_count == 0 직후 auto-reload 동일 tick)

**If** `_try_fire` 성공 시점에 `ammo_count_in == 1`: D.5 sequence — `ammo_count -= 1` → 0 → `ammo_count = MAGAZINE_SIZE`(같은 tick auto-reload). G5는 *decrement + auto-reload 적용 후* 평가 — 다음 `_try_fire` 호출(cooldown 경과 후)에서 `ammo_count = 30` → G5 PASS. **결과**: magazine 끝 사격에서 plumbing 끊김 없이 연속 fire 유지 (Pillar 4 흐름 보존).

### E-PS-3 (사격 + 같은 tick 치명타 동시 발생)

**If** tick N에 `_try_fire` 성공으로 projectile spawn AND 같은 tick N에 ECHO가 lethal hit 적중: spawn된 projectile은 정상 진행 (ADR-0001 player-only scope — projectile은 rewind 대상 외부). EchoLifecycleSM은 tick N에 DYING 진입; tick N+1부터 `_active = false` (C.2.3 handler 동작) → 후속 _try_fire G1 BLOCK. **결과**: "ECHO 사망 직전 발사한 총알이 enemy를 죽일 수 있다" — Pillar 1 학습-도구 시맨틱 정합 (죽음의 직전 *발견*이 보상됨).

### E-PS-4 (REWINDING hold-fire — restore tick 단일 차단)

**If** REWINDING 상태에서 플레이어가 hold-fire 유지: TR Rule 10 "REWINDING permits full input" 정합으로 `_active = true` 유지. restore tick(1프레임)에서만 G3 (`_player._is_restoring == true`) BLOCK; 그 외 REWINDING 모든 프레임에서 `_try_fire` 통상 평가 (G4 cooldown / G5 ammo는 정상 경합). **결과**: REWINDING signature window (`REWIND_SIGNATURE_FRAMES = 30` frames post-rewind i-frame) 내부 사격 가능 — Pillar 1 "되살아나자마자 다시 쏜다" 카타르시스 직접 메커닉화.

### E-PS-5 (Rewind 직후 cooldown 상태 — 자연 만료 일반화)

**If** rewind 직후 첫 `_try_fire` 호출: `_fire_cooldown_active` / `_fire_cooldown_frame`은 ADR-0002 Amendment 2 PlayerSnapshot에 *캡처되지 않으므로* 본 GDD에서 rewind가 cooldown을 reset하지 않음. 단, REWIND_WINDOW_FRAMES(=90) + DYING grace(12) ≫ FIRE_COOLDOWN_FRAMES(=10)이므로 `Engine.get_physics_frames() - _fire_cooldown_frame >= 10` 거의 항상 보장 → G4 PASS. **결과**: rewind 후 즉시 사격 가능 (cooldown은 자연 만료). 만약 cooldown=20(3 rps)으로 tuning 변경 시 동일 성립 (rewind window 90 > 20). cooldown_frames 변경 시 본 invariant 유지 의무는 본 GDD G section tuning knob 범위가 보장.

### E-PS-6 (PROJECTILE_CAP 도달 + hold-fire — silent skip)

**If** `_active_projectile_count >= PROJECTILE_CAP (=8)` AND hold-fire 유지: WeaponSlot `_try_fire` G1..G5 모두 PASS해도 spawn 시점 check가 silent skip 발동 (C.1 규칙 6) — no SFX/VFX/error/log/cooldown stamp. **결과**: 사용자에게 인지 불가능한 짧은 정지가 발생하지만, default 8 cap + 60 hz tick에서는 ~1.3초 sustained fire에서 1회 skip — 화면 외 발사체가 자연 expiry된 다음 tick부터 cap 미만 → 정상 fire 재개. Pillar 2 결정성 보존 (random spread X). cooldown stamp 미발생이므로 다음 tick fire가 "끊김 보상" 형태로 즉시 가능.

### E-PS-7 (Stage Projectiles 컨테이너 부재 — assert)

**If** Stage 씬 root에 `Projectiles: Node2D` 명명 노드 부재: WeaponSlot의 `find_child("Projectiles", true, false)` returns null → `push_error("Stage scene missing Projectiles container")` + `assert(false)` (디자인 위반). Tier 1 prototype에서는 Stage 디자인 작성 전 임시로 WeaponSlot이 `get_tree().current_scene` 자체에 add_child fallback 가능하나 — Stage GDD #12 작성 후에는 `assert` 정식 활성화. **결과**: 디자인 contract 위반 시 dev build crash; 정상 Stage에서는 발생 X.

### E-PS-8 (`set_active(invalid_id)` — silent fallback signal)

**If** `set_active(weapon_id)` 호출 시 `WeaponConfig.is_valid_id(weapon_id) == false`: C.1 규칙 11 단계 1 — `push_warning`, `weapon_fallback_activated.emit(weapon_id)`, return 즉시 (`_active_id` / `ammo_count` mutation 없음). **결과**: 잘못된 무기 ID가 active 무기에 영향 X; VFX #14 + Audio가 fallback-specific 큐 발화 가능 (downstream 구독). Tier 1 single-weapon에서는 호출 site 부재.

### E-PS-9 (`set_active(same_id)` — idempotent)

**If** `set_active(weapon_id)` 호출 시 `weapon_id == _active_id`: C.1 규칙 11 단계 2 — early return, ammo / 시그널 발화 모두 없음. **결과**: Pickup이 같은 무기를 두 번 픽업해도 ammo가 reset되지 않음 (Tier 2+ 경쟁 회피).

### E-PS-10 (HitBox.cause == `&""` 적중 시 enemy/boss 처리)

**If** ECHO Projectile HitBox(`cause = &""`)가 enemy/boss HurtBox에 적중: damage.md F.1 표 #7 contract — enemy/boss destroy 측은 cause 라벨 *사용하지 않음* (cause taxonomy는 ECHO 피격 시 cause-specific feedback에만 사용). enemy는 `hurtbox_hit(&"")` 수신 후 own destroy logic 실행 (1-hit-1-kill per damage.md DEC-2). **결과**: ECHO 발사체로 인한 enemy 처치는 cause 라벨 무관하게 정상 동작.

### E-PS-11 (ECHO viewport 외부 fire)

**If** ECHO가 viewport 밖(예: 화면 가장자리 ± offset)에서 fire: projectile은 정상 spawn (camera-relative 검사 없음 — D.4 frame-counter 단일 출처). Lifetime expiry까지 화면 외부 진행 후 자동 despawn. **결과**: 시각 인지 불가 사격은 정상이며 의도된 메커닉 — 예: Tier 2 무기 픽업 후 화면 끝에서 적 처치 가능. Pillar 2 결정성 정합.

### E-PS-12 (동일 tick 다중 projectile 동일 enemy 적중)

**If** tick N에 2개 이상의 ECHO projectile이 동일 enemy HurtBox에 동시 적중: damage.md C.3.2 step 0 `_pending_cause != &""` 가드가 두 번째 hit 처리 차단 (enemy는 단일 hit으로 destroy). 두 번째 projectile의 `area_entered` handler는 정상 발화하지만 `area is HurtBox`는 destroy 직전 HurtBox 객체 — `queue_free()` 호출 정상. **결과**: ammo 2발 소비 + enemy 1히트 처치 + 두 projectile 모두 destroy. cap counter는 두 번 decrement (정상). Pillar 2 정합 (deterministic — tree insertion order로 첫 hit 결정).

### E-PS-13 (Boot-time `@export` null reference)

**If** WeaponSlot의 `player` / `projectile_scene` / `trc` / `lifecycle_sm` 중 하나라도 editor에서 unassigned: C.2.3 `_ready()` `assert` 발동 — dev build crash, prod build 에러 메시지. **결과**: scene 디자인 완전성 부재 시 fail-fast (PM B7 path-error 트랩 재발 방지 — silent path failure 거부).

### E-PS-14 (Same-tick `_try_fire` 성공 + lethal hit emit)

**If** tick N에 WeaponSlot `_try_fire` 성공(spawn + ammo decrement + cooldown stamp) AND 같은 tick N에 damage 시스템이 `lethal_hit_detected(cause)` emit: damage.md priority=2 vs WeaponSlot (tree order로 PM 직후, priority 0)이므로 *WeaponSlot이 먼저 실행*. WeaponSlot은 fire 결정 시점에 EchoLifecycleSM 상태 polling — `AliveState`에서 G1/G2 PASS (DYING 전이는 priority 2 이후). 사격 후 같은 tick에 lethal_hit_detected emit → DYING 전이 → C.2.3 `_on_lifecycle_state_changed` → `_active = false`. **결과**: tick N+1부터 G1 BLOCK. tick N의 spawned projectile은 ADR-0001 정상 진행. E-PS-3과 같은 시퀀스를 priority 순서로 정밀화.

### E-PS-15 (REWIND_SIGNATURE_FRAMES i-frame 동안 사격)

**If** REWINDING signature window(`REWIND_SIGNATURE_FRAMES = 30` frames post-rewind i-frame) 동안 hold-fire: G1..G5 PASS (E-PS-4와 동일). ECHO HurtBox.monitorable=false (i-frame; damage.md DEC-4); 적의 발사체가 ECHO에 적중해도 ECHO damage 면제. *ECHO 발사체*는 layer 2 (HitBox)이며 active scanner이므로 i-frame과 무관 — enemy/boss에 정상 damage emit. **결과**: rewind 직후 0.5초(30프레임) 안전 사격 윈도우 — Pillar 1 "되살아나자마자 학습한 패턴을 깨뜨림" 메커닉 직접 활성.

### E-PS-16 (`_DIR_VECTORS` 대각 unit length 검증 — INV-WS-7)

**If** `_DIR_VECTORS` 테이블의 대각 vector magnitude가 1.0과 0.001 이상 차이 (`abs(_DIR_VECTORS[i].length() - 1.0) >= 0.001` for any `i ∈ {1,3,5,7}`): boot-time `assert` 발동 (`_ready()` 검증 step). **결과**: D.3 결정성 단일 출처 보존; `Vector2(0.707, -0.707)` 같은 약식 표기로 인한 magnitude 누적 오차 차단. Pillar 2 정합 (8방향 등속 보장).

### E-PS-17 (Tier 2+ pickup 직후 사망 — ADR-0002 Amendment 2 정합)

**If** Tier 2+에서 ECHO가 weapon W2 픽업 직후(예: 30프레임 이내) 사망 → rewind 성공: snap.current_weapon_id가 픽업 *전* W1 또는 *후* W2 중 무엇이 복원되는가는 `_lethal_hit_head - RESTORE_OFFSET_FRAMES` 시점에 종속 (time-rewind.md E-14: pickup 자체는 영구 소비). **결과**: snap이 픽업 *후*(W2)면 ECHO는 W2 + `snap.ammo_count` 복원; 픽업 *전*(W1)이면 ECHO는 W1 + W1의 `snap.ammo_count` 복원. 어느 쪽이든 픽업된 W2 픽업 object는 사라진 상태 유지 (one-way). **Tier 1에서는 발생 X** (single-weapon). Tier 2 Pickup GDD 작성 시 본 결과를 AC로 검증 의무.

### E-PS-18 (`weapons.tres` hot-reload 미지원)

**If** dev build 실행 중 `assets/data/weapons.tres` 값 변경 (tuning iteration): Godot 4.6 Resource 캐싱으로 인해 런타임 미반영 (`@export` 초기 load 후 캐시). **결과**: tuning iteration은 게임 재실행 필요. Tier 1에서 hot-reload 도입은 Tier 2+ 디자인 영역 (현재 GDD에서 비명세). Pillar 5 정합.

## F. Dependencies

본 절은 본 시스템이 발생시키는 cross-doc 의존성을 *direction × strength × interface*로 합본한다 — C.3 sub-section 합본의 entry point.

### F.1 Dependencies table (bidirectional, interface-explicit)

| # System | Direction | Strength | Interface | Status |
|---|---|---|---|---|
| #1 Input | upstream | Hard | `Input.is_action_pressed("shoot")` polling in `_physics_process` (Phase 2 reader); detect mode locked to hold in 본 GDD 규칙 1 | Approved |
| #6 Player Movement | upstream + downstream | Hard | Read: `_player.facing_direction: int`, `_player._is_restoring: bool`. Emit: `weapon_equipped(weapon_id: int)`, `shot_fired(direction: int)`. PM C.4.4 `_on_anim_spawn_bullet` guard hook은 Tier 1 dormant | Approved |
| #5 State Machine | upstream | Hard | Subscribe to `EchoLifecycleSM.state_changed(from, to)`; read `lifecycle_sm.current_state` for G2 guard; **no `transition_to()` trigger** (forbidden_pattern `cross_entity_sm_transition_call` honor) | Approved |
| #8 Damage | downstream | Hard | Instantiate `HitBox extends Area2D` (damage.md C.1.1) as child of Projectile root; `cause = &""`, `host = projectile_root`, `collision_layer = 2`, `collision_mask = 3 \| 6`, `monitoring = true`. damage.md F.1 #7 obligation honored | LOCKED |
| #9 Time Rewind | upstream + downstream | Hard | Upstream (read): TRC reads `WeaponSlot.ammo_count` per `_capture_to_ring()` Step (b) (time-rewind.md AC-A1). Downstream (sync method): TRC calls `WeaponSlot.restore_from_snapshot(snap)` inside Rule 9 atomic sequence (OQ-PM-NEW (a) lock). **NO signal subscription** | Approved |
| #2 Scene Manager | upstream | Soft | `scene_will_change` Stage swap 시 Stage's `Projectiles: Node2D` 컨테이너 + 자식 자동 free; WeaponSlot 별도 cleanup 없음. Restart 시 `_ready()` 재실행 (ammo + cooldown ephemeral reset) | Approved |
| #12 Stage / Encounter | downstream | Soft *(provisional)* | Stage `.tscn` root 자식에 `Projectiles: Node2D` 명명 노드 1개 필수; F.4.2 #1 | Not Started |
| #13 HUD | downstream | Soft *(provisional)* | Subscribe to `weapon_equipped`, `weapon_fallback_activated`; read `ammo_count`. F.4.2 #2 | Not Started |
| #14 VFX / Particle | downstream | Soft *(provisional)* | Subscribe to `shot_fired`, `weapon_fallback_activated`; near-miss obligation per damage.md DEC-3. F.4.2 #3 | Not Started |
| #4 Audio | downstream | Soft *(provisional)* | Subscribe to `shot_fired`, `weapon_fallback_activated`; placeholder `sfx_player_shoot_rifle_01.ogg`. F.4.2 #4 | Not Started |
| #3 Camera | downstream | Soft *(provisional)* | Subscribe to `shot_fired(direction)` for micro-shake (Camera GDD spec). F.4.2 #5 | Not Started |
| #19 Pickup (Tier 2) | downstream | Soft *(deferred)* | Call `WeaponSlot.set_active(weapon_id: int)` direct; invalid id → `weapon_fallback_activated` emit. F.4.2 #6 | Not Started, Tier 2 |
| ADR-0001 | architecture | locked ref | Player-only rewind scope — projectile은 normal simulation (C.2.5) | Accepted |
| ADR-0002 Amendment 2 | architecture | ratifies via 본 GDD | `ammo_count` 8번째 PM-노출 필드, Weapon single-writer; OQ-PM-NEW (a) TRC orchestration | Proposed → Accepted |
| ADR-0003 | architecture | locked ref | Projectile = Area2D + script transform; `process_physics_priority = 20`; `1.0/60.0` fixed delta | Accepted |

### F.2 Hard vs Soft 분류 합본

**Hard** (interface 위반 시 본 시스템 동작 불가능):

- Input #1 (`shoot` action 없으면 사격 불가)
- PM #6 (`facing_direction` 없으면 발사 방향 부재)
- SM #5 (`EchoLifecycleSM` 없으면 _active gating 불가)
- Damage #8 (HitBox 클래스 없으면 발사체 명중 emit 불가)
- TR #9 (`PlayerSnapshot.ammo_count` 8번째 필드 없으면 Pillar 1 contract 깨짐)

**Soft** (interface 부재 시 본 시스템은 동작하나 cascade 기능 부재):

- Scene Manager #2 (Tier 1 prototype에서 `_ready()` ephemeral reset 충분)
- Stage #12 *(provisional)* (Projectiles 컨테이너 부재 시 dev-build assert)
- HUD #13 / VFX #14 / Audio #4 / Camera #3 *(provisional)* (시그널 구독자 부재 시 본 시스템 동작 영향 없음; juice 부재만)
- Pickup #19 *(deferred)* (Tier 1 single-weapon에서 호출 site 없음)

### F.3 Cross-doc reciprocal status (HEAD 시점 stale-check)

| Source GDD | Row referencing #7 | Current 상태 | 본 GDD가 close하는 의무 |
|---|---|---|---|
| `player-movement.md` F.1 row #7 *(provisional)* | "PM이 WeaponSlot 자식 노드 호스팅 + `weapon_equipped(weapon_id)` signal 구독 → `_current_weapon_id` cache" | `*(provisional)*` | 본 GDD가 `weapon_equipped` signature 정의; PM F.4.2 의무 close |
| `player-movement.md` F.4.2 → #7 obligation | (a) signal 정의, (b) anim guard, (c) reload + ammo restoration DEC-PM-3 v2 비준 | 3 의무 모두 close | C.3.2 + 규칙 4 + C.2.6 |
| `time-rewind.md` F.1 row #7 *(provisional)* | "`WeaponSlot.set_active(invalid_id)` silent fallback to id=0; ammo 정책" | OQ-1 closed Session 17; OQ-3 본 GDD close | 규칙 11 |
| `time-rewind.md` C.3 Rule 9 pseudocode | TRC restore sequence (1) PM (2) emit | step (2) Weapon restore 추가 필요 | F.4.1 #2 |
| `time-rewind.md` AC-A1 + AC-A4 | TRC 3-tier read; post-rewind PM 7 + Weapon ammo 복원 검증 | AC-A4 WeaponSlot.ammo_count 추가 필요 | F.4.1 #2 |
| `damage.md` F.1 표 #7 | "ECHO Projectile HitBox (L2) — `cause` 미설정" | Tier 1 contract OK | damage.md edit 의무 없음 |
| `input.md` C.1.1 row 7 | `shoot` action detect mode *(provisional)* | `is_action_pressed` (hold) lock | F.4.1 #1 |
| `state-machine.md` F.2 | row #7 부재 | EchoLifecycleSM `state_changed` 구독 → SM F.2 row 추가 | F.4.1 #3 |
| `adr-0002-time-rewind-storage-format.md` Amendment 2 | OQ-PM-NEW (a) vs (b) 미결 | (a) TRC orchestration lock | F.4.1 #4 |
| `docs/registry/architecture.yaml` | `ammo_count` writer entry 부재 | 신규 항목 추가 | F.4.1 #5 |
| `design/registry/entities.yaml` | weapon constants 부재 | 신규 항목 (5 constants) | F.4.1 #6 |

### F.4 Cross-doc edit obligations

#### F.4.1 This GDD's batch (apply after Approved promotion gate)

| # | Target file | Edit | Owner | Status |
|---|---|---|---|---|
| 1 | `design/gdd/input.md` C.1.1 row 7 | `*(provisional)*` 제거; detect mode = `is_action_pressed` (hold) | Player Shooting #7 | Pending |
| 2 | `design/gdd/time-rewind.md` C.3 Rule 9 + AC-A4 | Rule 9 step (2) 추가 `_weapon_slot.restore_from_snapshot(snap)`; AC-A4 assertion에 `WeaponSlot.ammo_count == snap.ammo_count` 추가 | Player Shooting #7 | Pending |
| 3 | `design/gdd/state-machine.md` F.2 | 신규 row #7 Player Shooting 추가 — subscribes `state_changed`; transition trigger X | Player Shooting #7 | Pending |
| 4 | `docs/architecture/adr-0002-time-rewind-storage-format.md` Amendment 2 | Proposed → Accepted; OQ-PM-NEW = (a); Weapon-side capture = WeaponSlot per-tick; restoration = TRC sync method call | Player Shooting #7 (architecture-review ratifies) | Pending |
| 5 | `docs/registry/architecture.yaml` | 신규: `state_ownership.ammo_count` (owner=weapon-slot, write_access=weapon-slot-only-or-snapshot-restore); `interfaces.weapon_slot_signals` (signature 단일 출처); `forbidden_patterns.direct_ammo_count_write_outside_weapon_slot` | Player Shooting #7 | Pending |
| 6 | `design/registry/entities.yaml` | 신규 constants: `FIRE_COOLDOWN_FRAMES`, `MAGAZINE_SIZE`, `PROJECTILE_CAP`, `PROJECTILE_SPEED_PX_S`, `PROJECTILE_LIFETIME_FRAMES` | Player Shooting #7 | Pending |
| 7 | `design/gdd/systems-index.md` Row #7 | Not Started → Designed (pending re-review); Progress Tracker Designed +1 | Player Shooting #7 | Pending |

> **Approved promotion gate (BLOCKING)**: F.4.1 batch must be applied as commit follow-up before this GDD reaches `Approved` status. Phase 5d cross-doc batch pattern (mirrors scene-manager.md F.4.1 Approved promotion gate).

#### F.4.2 Future GDD obligations (downstream — apply when target GDD is authored)

| # | Target GDD (Not Started) | Obligation | Trigger |
|---|---|---|---|
| 1 | Stage / Encounter #12 | Stage `.tscn` root에 `Projectiles: Node2D` 명명 노드 자식 1개; H section AC × 1 | `/design-system stage-encounter` 시 |
| 2 | HUD #13 | `weapon_equipped`/`weapon_fallback_activated` 구독 + `ammo_count` read; H section AC × 3 | `/design-system hud` 시 |
| 3 | VFX #14 | `shot_fired`/`weapon_fallback_activated` 구독; near-miss 책임; H section AC × 2 | `/design-system vfx-particle` 시 |
| 4 | Audio #4 | `shot_fired`/`weapon_fallback_activated` 구독; placeholder `sfx_player_shoot_rifle_01.ogg`; H section AC × 2 | `/design-system audio-system` 시 |
| 5 | Camera #3 | `shot_fired` 구독 → micro-shake; H section AC × 1 | `/design-system camera` 시 |
| 6 | Pickup #19 (Tier 2) | `WeaponSlot.set_active(weapon_id)` direct call; invalid id 발생 조건; H section AC × 2 | `/design-system pickup` 시 (Tier 2) |

## G. Tuning Knobs

모든 본 시스템 tuning knob은 `assets/data/weapons.tres` (Tier 1 base rifle) Resource에 단일 출처로 저장된다. 코드 hardcode 금지 (forbidden_pattern `gameplay_value_in_code` 정합 — `.claude/docs/coding-standards.md`).

### G.1 Tuning knob 합본표 (Tier 1 base rifle 기준)

| # | Knob | Type | Default | Safe Range | Affects | Extreme behavior |
|---|---|---|---|---|---|---|
| G.1.1 | `fire_cooldown_frames` | int | 10 | 6..20 | Fire rate (D.2 `effective_rps`) — Tier 1 default = 6.0 rps | < 6: hitscan-blur feel + cap overflow 빈발; > 20: 사격 weight 과중, Pillar 4 즉시성 손실 |
| G.1.2 | `magazine_size` | int | 30 | 10..60 | 사격 burst 길이 (D.5 auto-reload trigger) — 5초 sustained fire @ 6 rps | < 10: reload 빈도 너무 잦아 흐름 단절 (Pillar 4 위반); > 60: ammo가 *추상적 자원*으로 회귀 — Section B fantasy "흐름의 연료" 정서 손실 |
| G.1.3 | `reload_frames` | int | 0 (Tier 1) | 0..60 (Tier 2+) | Reload 동안 사격 차단 frames | Tier 1: 0 강제 (instant auto-reload — Pillar 4 즉시성). Tier 2+ 무기마다 다른 reload 시간 도입 가능. > 60: > 1초 정지 — Section B "uninterrupted motion" fantasy 직접 위반 |
| G.1.4 | `projectile_cap` | int | 8 | 4..16 | C.1 규칙 6 silent skip 기준 | < 4: hold-fire 도중 잦은 skip (지각 가능); > 16: 메모리/성능 압박 + Pillar 2 결정성 검증 어려움 (cap-bound determinism 의존) |
| G.1.5 | `projectile_speed_px_s` | float | 600.0 | 400.0..800.0 | D.3 projectile motion — 시각 인식 가능성 | < 400: magic-bolt aesthetics (rifle 정체성 손실); > 800: hitscan 시각 인식 — Pillar 2 "see your shot" read 손실 |
| G.1.6 | `projectile_lifetime_frames` | int | 90 | 60..120 | D.4 despawn (= ~900 px @ default speed) | < 60: 화면 안에서 사라짐 (`max_distance_px ≈ 400` < viewport 너비); > 120: 화면 밖 누적 — cap에 도달하여 skip 빈발 |
| G.1.7 | `muzzle_offsets` | Array[Vector2] (length 8) | art-director defined per-direction | per-axis ±32 px | 사격 시각 anchor (Sprite2D Pillar 3 collage 정합) | art-director 결정. art-bible ABA-2 paper-doll arm overlay 위치와 일치 의무 (E-PS-16 보조 — magnitude는 unit length 아닌 anchor 위치) |

### G.2 Tuning knob 비-knob 비교 (의도적으로 hardcoded)

다음 값은 *tuning knob이 아니며* 변경 시 architecture review 또는 ADR 갱신이 필요하다 — 본 GDD에서 const로 hardcode:

| Const | Value | Source | Why not tuned |
|---|---|---|---|
| `_DIR_VECTORS` | length-8 Vector2 (CCW from East, 모든 단위 magnitude=1) | C.1 규칙 2 + D.3 | Pillar 2 결정성 단일 출처 — 8-way 정체성 (game-concept "8방향 조준"). 변경 시 PM `facing_direction` enum semantics 위반 |
| `FIXED_DELTA` | 1.0 / 60.0 | D.3 | `Engine.physics_ticks_per_second` 단일 출처 (`technical-preferences.md`). 변경 시 모든 결정성 검증 ACs 재실행 |
| `collision_layer` (HitBox) | 2 | C.1 규칙 8 + damage.md C.2.4 | damage.md owns layer schema 단일 출처. 변경 시 damage.md ADR 필요 |
| `collision_mask` (HitBox) | 3 \| 6 | C.1 규칙 8 + damage.md C.2.4 | 동일 |
| `cause` (ECHO Projectile HitBox) | `&""` | C.1 규칙 8 + damage.md F.1 표 #7 | damage.md F.1 contract 단일 출처 |
| `process_physics_priority` (Projectile) | 20 | C.1 규칙 5 + entities.yaml | ADR-0003 priority ladder. 변경 시 ADR-0003 amendment |

### G.3 Knob 상호작용 경고 (cross-knob invariants)

1. **`fire_cooldown_frames` × `projectile_cap` × `projectile_lifetime_frames` — cap overflow 임계점**:
   Theoretical max concurrent projectiles = `projectile_lifetime_frames / fire_cooldown_frames`. Default: `90 / 10 = 9`. Cap = 8 → 1 silent skip per cycle. **Invariant**: cap ≥ 4 AND cap ≥ (`projectile_lifetime_frames / fire_cooldown_frames` - 2) 권장 — 과도한 skip 방지.

2. **`fire_cooldown_frames` × `REWIND_WINDOW_FRAMES` — rewind 직후 cooldown 자연 만료 invariant (E-PS-5)**:
   rewind 후 즉시 사격 가능 contract는 `REWIND_WINDOW_FRAMES (=90) > fire_cooldown_frames` 일 때만 보장. **Invariant**: `fire_cooldown_frames < REWIND_WINDOW_FRAMES (=90)`. 안전 범위 6..20 모두 만족.

3. **`projectile_speed_px_s` × `projectile_lifetime_frames` — viewport clearance**:
   `max_distance_px = (projectile_lifetime_frames * projectile_speed_px_s) / 60`. **Invariant**: max_distance_px ≥ viewport_width (1280px) — 화면 외 영역까지 도달 보장. 400×60/60 = 400 < 1280 위반 가능 → speed × lifetime 양쪽 lower bound 동시 적용 금지.

4. **`magazine_size` × `reload_frames` (Tier 2+) — 사격 burst 빈도**:
   Average rounds per minute = `magazine_size / (magazine_size * fire_cooldown_frames / 60 + reload_frames / 60)` (정상화). Tier 1 reload_frames=0 → 단순 6 rps. Tier 2+ tuning 시 burst-fire 무기는 magazine_size 작고 reload_frames 크게, hold-fire 무기는 반대.

5. **`muzzle_offsets[i]` × art-bible ABA-2 arm overlay**:
   각 muzzle_offset 위치는 art-director가 ABA-2 arm overlay 스프라이트의 *총구 끝점*과 일치하도록 tune 의무. 미일치 시 Pillar 3 collage 시각 일관성 위반 (총구는 그려졌으나 다른 위치에서 발사 시각 효과). art-director sign-off 필수 — implementation phase 검증.

### G.4 Tier 1 specific (production-ready defaults)

Tier 1 prototype 4-6주 안에 단일 base rifle만 동작 — knob iteration은 playtest-driven. Initial values 위 G.1 default 컬럼 — 이는 game-designer 합의 (`/design-system player-shooting` 2026-05-11)에서 lock된 Contra III / Hard Corps baseline:

- **Pillar 4 (5분 룰) 검증 조건**: 첫 사격까지 < 30초; `magazine_size = 30` + `reload_frames = 0`이면 사격 30회 연속 가능 → magazine 한도 인지 5초 (60 rps 보조 사용 시 5초). pillar gate AC 통과.
- **Pillar 1 (rewind 학습-도구) 검증 조건**: ammo 0 직전 사망 → rewind → ammo 복원 시 `restore_idx` 시점 ammo > 0. D.6 round-trip identity AC가 검증.
- **Pillar 2 (결정성) 검증 조건**: `_DIR_VECTORS` 정규화 + `FIXED_DELTA` const + cap silent skip 결정성 = ADR-0003 AC-F1 1000-run bit-identical 검증.

## Visual / Audio Requirements

본 절은 art-director consult (`/design-system player-shooting` 2026-05-11)에서 lock된 시각·청각 spec을 단일 출처로 합본한다. 모든 자산은 art-bible (`design/art/art-bible.md` Approved 2026-05-09)의 ABA-1..4 amendment 범위 안에 위치 — **신규 ABA amendment 의무 없음**.

### V/A.1 Muzzle flash VFX (8-way 사격 시각)

- **Visual signature**: 종이 컷아웃 4-pointed star (hard-cut, no soft particle bloom). 선두 점(fire 방향)은 trailing 점들의 1.5x 길이로 비대칭 cropping — animation frame 없이도 정지 화면에서 방향성 인식 (art-bible Section 9 Monty Python cutout 논리).
- **Color**: 2-tone. Core = `#FFFFFF` (muzzle flash는 sub-frame 이벤트이므로 art-bible "pure white forbidden" 규칙의 예외). Outer petals = **Neon Cyan `#00F5D4`** (art-bible Section 4: REWIND Core 시각 정체성과 연결 — Pillar 1 hooks). **No magenta** (`#FF2D7F`은 enemy/VEIL 단일 출처).
- **Duration**: 3 frames @ 60Hz (50 ms total). Frame 1: 100% opacity. Frame 2: 60% opacity + scale +20%. Frame 3: 15% opacity + scale +35%. Frame 4: snap-off (no linger). art-bible Section 7 UI animation rule "컷인 — fade 없음" 정합.
- **Asset**: `vfx_muzzle_flash_base_small.png` — 8 방향 × 3 frames sprite sheet (16×16px cells, 32-cell layout in `atlas_vfx_tier1.png`).
- **Particle count**: **0 GPU particles in Tier 1** — 단일 `Sprite2D` 노드 swap 패턴 (1 draw call per active flash, atlas-batched). Tier 2+에서 `GPUParticles2D` 4-6 particles 도입 가능 (3 동시 emitter 한도; 100-call VFX 예산 내).
- **Position**: `WeaponSlot.muzzle_offsets[direction]` (G.1.7 tuning knob)를 따른다 — paper-doll arm overlay (ABA-2)의 총구 끝점과 art-director가 per-direction 일치 검증.

### V/A.2 Projectile sprite

- **Aesthetic**: 종이 컷아웃 neon line (NOT 픽셀 dot, NOT gradient streak). 12px × 4px PNG, 2px black border (art-bible Section 3 lineart "stroke 2-4px"), fill = **Neon Cyan `#00F5D4`**. Sprite는 spawn 시 `_DIR_VECTORS[direction]` 각도로 회전 (dart 실루엣).
- **Asset**: `vfx_bullet_base_travel_small.png` (16×8px cell with padding for diagonal rotation, in `atlas_vfx_tier1.png`).
- **No trail in Tier 1**: 10 px/frame 진행이라 trail (Line2D 또는 particles)은 draw call 예산 초과 위험 (8 cap × 1 trail each = 8 추가 draw calls). Tier 2+ 3-segment Line2D fading cyan→transparent over 4 frames.
- **Texture import**: `TextureFilter.NEAREST` (art-bible Section 8 import settings 정합).
- **Color-blind safety**: 모양(elongated dart with 2px border) + cyan luminance contrast → Deuteranopia-safe (art-bible Section 4 검증).

### V/A.3 Projectile despawn VFX (non-event)

- **Lifetime expiry (D.4, ~900px max)**: 즉시 `queue_free()` — VFX 없음. 화면 외 영역 despawn은 시각 비이벤트이며, 자산/draw call 비용 부재.
- **HurtBox 적중 (C.1 규칙 7)**: 즉시 `queue_free()` 본 시스템 측. **본 시스템은 impact VFX를 발화하지 않는다** — VFX #14가 own (damage.md DEC-3 near-miss + impact 의무).

### V/A.4 Hit VFX 핸드오프 (cross-system contract)

- **본 시스템 발화 신호**: `shot_fired(direction: int)` (muzzle flash trigger) + Projectile `tree_exiting` 또는 HitBox `area_entered` (impact position 데이터 source).
- **VFX #14의 책임**: HitBox의 `area.global_position`을 signal callback 시점에 read하여 impact VFX 합성. art-direction 권고: enemy impact = **Ad Magenta `#FF2D7F`** (art-bible Section 4 vocabulary: enemy/VEIL 위협 색).
- **No additional signal payload**: 본 시스템은 `shot_fired(direction)` + standard HitBox `area_entered` 외 추가 payload를 발화하지 않는다 — VFX GDD #14 작성 시 명세.

### V/A.5 Audio cue spec (Tier 1 placeholder)

| Cue | Trigger | Asset (Tier 1 placeholder/CC0) | Pool | Tier 2+ |
|---|---|---|---|---|
| 사격 발사음 | `shot_fired(direction)` emit | `sfx_player_shoot_rifle_01.ogg` | 2 AudioStreamPlayers (6 rps cutoff 방지) | 추가 무기 cue category 예약: `sfx_player_shoot_[weapon_id]_01.ogg` |
| 자동 reload | `ammo_count == 0` 직후 (D.5) | **없음 Tier 1** (reload_frames=0; 지각 가능 duration 부재) | — | Tier 2+ `sfx_player_reload_rifle_01.ogg` 예약 |
| 무기 교체 | `weapon_equipped(weapon_id)` (Tier 1 boot 0만) | **없음 Tier 1** (boot 시 light "ready" click optional, advisory) | — | Tier 2+ `sfx_player_weapon_swap_[weapon_id]_01.ogg` 예약 |
| 잘못된 무기 fallback | `weapon_fallback_activated(requested_id)` (Tier 1 미발화) | **없음 Tier 1** | — | Tier 2+ `sfx_player_weapon_invalid_01.ogg` 예약 |

**Sustained fire 모델**: single-shot SFX 6 rps 반복 (Contra / Metal Slug 패턴) — sustained loop 아님 (loop seam artifact 위험). AudioStreamPlayer pool 2개로 overlap allowed.

### V/A.6 Pillar 3 collage hook (Steam 마케팅 screenshot 후보)

Section B fantasy 모먼트 ("mid-jump, fire upper-right, no horizontal velocity lost")가 *정지 한 장*에서 3개 시각 vector 동시 인식 가능해야 한다:

1. **Sprint vector** — ECHO body 전경 45° leaning (art-bible Section 5) + jump arc 함의 + paper-doll 실루엣 kinetic read.
2. **Fire vector** — 8방향 arm overlay (direction=1 NE) + 12×4px cyan dart 45° NE + 3-frame muzzle flash 비대칭 선두 NE 방향.
3. **Coloured impact** — 화면 우상단 enemy (magenta glow) + VFX #14의 impact magenta burst → cyan/magenta 대비 = REWIND Core 시그너처.

**시각 선택 정합**: muzzle flash가 Neon Cyan (white/yellow 아님)이므로 정지 frame에 visible emission arc 발생; 검은 border가 콜라주 배경(Layer 1 photo texture + Layer 3 detail)과 명확히 분리; magenta enemy impact가 3-color anchor 완성. art-bible Principle B "photo texture + drawing line 동시 인식" test 통과.

### V/A.7 Steam Deck 성능 budget (art-bible Section 8 정합)

- **Tier 1 muzzle flash draw call**: 1 (atlas-batched `atlas_vfx_tier1.png`). 한 시점에 최대 1 active flash (6 rps cooldown gate이 frame 3 expiry < frame 10 next fire 보장).
- **Tier 1 projectile draw call**: 8 동시 (cap), atlas-batched = 효과적으로 1 draw call. + 1 muzzle flash = 합계 2 calls within 100-call VFX 예산.
- **Tier 2+ delta**: 동시 emitter 3개 한도 (overlapping muzzle flash particles in sustained fire) + Line2D trail × 8 cap. art-bible Section 8 100-call VFX 예산 내 fit 검증 의무.

### V/A.8 Asset / amendment status table

| Item | Status | Source |
|---|---|---|
| `vfx_muzzle_flash_base_small.png` | **NEW — Tier 1 production** | 본 GDD V/A.1 |
| `vfx_bullet_base_travel_small.png` | **NEW — Tier 1 production** | 본 GDD V/A.2 |
| `sfx_player_shoot_rifle_01.ogg` | **NEW — Tier 1 placeholder (CC0)** | 본 GDD V/A.5 |
| `atlas_vfx_tier1.png` 추가 cells | **Tier 1 production** | art-bible Section 8 budget 내 |
| `weapon_id_0` (Tier 1 base rifle) entry in `WeaponConfig` | **NEW — Tier 1** | 본 GDD 규칙 12 |
| Art-bible amendment | **None required** (ABA-1..4 cover) | art-director 2026-05-11 검증 |
| Tier 2+ Line2D trail / GPUParticles2D / 추가 weapon cues | **Deferred** | Tier 2 디자인 |

> **📌 Asset Spec** — Visual/Audio requirements are defined. art-bible Approved 후 `/asset-spec system:player-shooting` 실행하여 V/A.1–V/A.5 자산의 per-asset 시각 명세 + 치수 + AI 생성 prompt 생성.

## UI Requirements

본 시스템은 *direct UI 호스팅 책임이 없다* — 모든 player-facing UI 요소(ammo counter, 무기 아이콘, fallback indicator)는 HUD System #13 (Not Started)이 own. 본 절은 HUD GDD가 작성될 때 본 시스템에서 *어떤 데이터를 어떤 형식으로 expose*하는지를 단일 출처로 명세한다.

### UI.1 HUD가 본 시스템에서 read하는 데이터 (HUD GDD F.4.2 #2 obligation 참조)

| UI element | Data source | Format | Update trigger |
|---|---|---|---|
| 무기 아이콘 | `weapon_equipped(weapon_id: int)` signal | int 0..N (Tier 1: 0만; Tier 2+: 0..3) | 시그널 발화 시점 + 초기 boot |
| Ammo counter (현재 magazine 잔여) | `WeaponSlot.ammo_count` direct read | int 0..MAGAZINE_SIZE (Tier 1: 0..30) | per-tick polling (HUD GDD 결정) 또는 새 시그널 `ammo_changed(new_count: int)` |
| Fallback indicator (optional) | `weapon_fallback_activated(requested_id: int)` signal | int (invalid id) | 시그널 발화 시점 (Tier 1 미발화; Tier 2 Pickup 도입 시) |
| Magazine capacity (label) | `assets/data/weapons.tres` `magazine_size` | int (Tier 1: 30) | static (boot read; tuning change 시 게임 재시작 — E-PS-18) |

### UI.2 본 시스템이 *발화하지 않는* signals (HUD가 자체 polling/derive 의무)

- **사격 통계** (총 사격 수, 명중률 등) — Tier 2+ score tracker는 별도 시스템; 본 시스템은 통계 emit X.
- **Auto-reload 발동 시점** — D.5 ammo 0→MAGAZINE_SIZE 전이는 같은 tick에 발생; HUD가 `ammo_count` 값 변화로 derive 가능 (`old_value < new_value`).
- **Reload progress bar** (Tier 2+ `reload_frames > 0`) — Tier 1 reload_frames=0이므로 의무 없음; Tier 2 Pickup GDD 작성 시 `reload_progress: float 0.0..1.0` getter 추가 결정.

### UI.3 직접 호스팅 책임 없음 (Anti-scope)

본 시스템은 다음을 *디자인하지 않는다*:

- Ammo counter 시각 배치 / 색 / 폰트 (HUD #13 + art-bible UI Section 7 책임)
- 무기 아이콘 이미지 자산 (HUD #13 + art-bible 자산 budget)
- 메뉴 / pause UI 통합 (Menu #18 책임)
- Pickup prompt UI (Tier 2 Pickup #19 책임)
- Tutorial / 사격 발견 시각 도움 (Pillar 4 5분 룰은 *텍스트 0줄*; 별도 tutorial UI 부재)

### UI.4 Accessibility hooks (Tier 3 deferred — Anti-Pillar #6)

Tier 3 Accessibility Options #24 도입 시 본 시스템이 영향받을 surface:

- **Aim assist** (Tier 3 optional): 8-way snap을 보조하는 magnetism — 그러나 Pillar 2 결정성 위반 위험; Tier 3 디자인 결정.
- **Fire rate auto** (Tier 3 optional): hold-fire를 못하는 사용자를 위한 auto-fire 토글 — `Input.is_action_pressed`를 internal auto-repeat로 변환; 본 시스템 코드 변경 불필요 (Input #1 layer).
- **Audio cue alternatives**: 시각 장애 사용자를 위한 directional audio cue 보강은 Audio System #4가 own.

Tier 1에서는 위 surface 모두 *비활성* (Anti-Pillar #6 — Tier 3 deferred).

### UI.5 UX flag (skill 자동 출력)

> **📌 UX Flag — Player Shooting #7**: 본 시스템은 ammo counter + 무기 아이콘 UI 요구사항을 발생시킨다. Phase 4 (Pre-Production) 진입 시 `/ux-design` 실행하여 HUD #13 GDD 작성 *전*에 ammo counter / weapon icon 스크린 명세 생성. Story는 `design/ux/hud-ammo-counter.md` 등 ux 스펙 참조 (본 GDD 직접 참조 X). HUD #13 row가 systems-index에서 작성 trigger 시점 기준.

## H. Acceptance Criteria

본 절은 본 시스템 동작을 검증하는 acceptance criteria 합본이다. qa-lead consult (`/design-system player-shooting` 2026-05-11)에서 lock된 AC ID 체계 + Given/When/Then 표준 형식 + Logic/Integration/Static classification + BLOCKING/ADVISORY gate level을 따른다.

### H.0 AC 합본 preamble (grep-verifiable enumeration)

- **Total ACs**: 47 enumerated
- **Logic BLOCKING**: 25 (PS-H1-01..13, PS-H2-01..06, PS-H3-01/04/05, PS-H4-05/11)
- **Integration BLOCKING**: 7 (PS-H3-06, PS-H4-03/04/14, PS-H6-01/02/03)
- **Static (GREP) BLOCKING**: 9 (GREP-PS-0..7, PS-H6-05)
- **ADVISORY (playtest / manual)**: 7 (H.U1..H.U7) + Integration ADVISORY (PS-H4-07/10/12/15)
- **Total BLOCKING**: 41 / **Total ADVISORY**: 11

Per-classification enumeration line (grep verification): `PS-H1-01..13, PS-H2-01..06, PS-H3-01/04/05/06, PS-H4-03..15 (selective), PS-H6-01..05, GREP-PS-0..7, H.U1..7`.

### H.1 Logic / Per-Rule ACs (BLOCKING — GUT unless tagged)

**PS-H1-01** *(Logic BLOCKING)* — R1 Detect + cooldown gate.
**GIVEN** `Input.is_action_pressed("shoot") == true` AND `Engine.get_physics_frames() - _fire_cooldown_frame == 5` AND `_fire_cooldown_active == true` AND `FIRE_COOLDOWN_FRAMES = 10`,
**WHEN** `_try_fire()` 호출,
**THEN** projectile spawn 발생 X AND `shot_fired` 시그널 emit X AND `_active_projectile_count` 불변. _Rule 1 + Edge E-PS-1._

**PS-H1-02** *(Logic BLOCKING)* — R2 Aim resolution 8-way parametric.
**GIVEN** 모든 `direction ∈ {0, 1, 2, 3, 4, 5, 6, 7}`에서 `_player.facing_direction = direction` AND `_try_fire()` PASS,
**WHEN** `spawn_projectile(direction)` 호출,
**THEN** spawned projectile의 `velocity == _DIR_VECTORS[direction] * projectile_speed_px_s` (Vector2 component 0.001 tolerance). _Rule 2 + D.3._

**PS-H1-03a** *(Logic BLOCKING)* — R3 Spawn position.
**GIVEN** `WeaponSlot.global_position = (100, 50)` AND `muzzle_offsets[direction=0] = (12, 0)`,
**WHEN** `spawn_projectile(0)` 호출,
**THEN** Projectile `global_position == (112, 50)`. _Rule 3 Spawn position._

**PS-H1-03b** *(Logic BLOCKING)* — R3 Projectile motion + lifetime expiry.
**GIVEN** Projectile spawned at frame 5000 with `velocity = Vector2(600, 0)` AND `PROJECTILE_LIFETIME_FRAMES = 90`,
**WHEN** 89 physics ticks 경과 (frame 5089),
**THEN** Projectile alive AND `position.x ≈ 100 + 600 * (89/60) = 100 + 890 = 990` (tolerance 0.01). At frame 5090: `queue_free()` 호출됨. _Rule 3 motion + D.3 + D.4._

**PS-H1-03c** *(Logic BLOCKING)* — R3 Hit handler `queue_free`.
**GIVEN** Projectile + HurtBox 인스턴스 both Area2D in scene,
**WHEN** `Projectile.area_entered(hurtbox)` 발화,
**THEN** Projectile `queue_free()` 호출 (`_active_projectile_count` 다음 tick decrement via `tree_exiting`). _Rule 3 Hit handler._

**PS-H1-04** *(Logic BLOCKING)* — R4 Magazine + auto-reload (INV-WS-1 collapsed).
**GIVEN** `ammo_count = 1` AND `_try_fire()` G1..G5 모두 PASS,
**WHEN** `_try_fire()` 실행 완료,
**THEN** same tick post-condition: `ammo_count == MAGAZINE_SIZE (=30)` (D.5 auto-reload trigger 작동) AND projectile spawn 발생 OK AND `weapon_equipped` re-emit 발생 X. _Rule 4 + D.5 + INV-WS-1._

**PS-H1-05a** *(Logic BLOCKING)* — R5 G1 `_active` guard.
**GIVEN** `_active = false` (DyingState 진입 후),
**WHEN** `Input.is_action_pressed("shoot") == true`,
**THEN** `_try_fire()` G1 BLOCK; spawn / signal / mutation 부재. _Rule 5 G1._

**PS-H1-05b** *(Logic BLOCKING)* — R5 G2 lifecycle state read.
**GIVEN** `EchoLifecycleSM.current_state == DyingState` AND `_active = true` (race condition mock),
**WHEN** `_try_fire()` 호출,
**THEN** G2 BLOCK; G1이 PASS여도 G2 차단 (defense in depth). _Rule 5 G2._

**PS-H1-05c** *(Logic BLOCKING)* — R5 G3 `_is_restoring` guard (INV-WS-2 collapsed).
**GIVEN** `_player._is_restoring == true` (restore tick mid),
**WHEN** `_try_fire()` 호출,
**THEN** G3 BLOCK; ammo / cooldown / projectile 모두 불변. PM C.4.4 reciprocal 검증. _Rule 5 G3 + INV-WS-2._

**PS-H1-05d** *(Logic BLOCKING)* — R5 G4 cooldown guard (D.1 explicit).
**GIVEN** `_fire_cooldown_active = true` AND `_fire_cooldown_frame = 1000` AND `Engine.get_physics_frames() = 1009`,
**WHEN** `_try_fire()` 호출,
**THEN** G4 BLOCK (`elapsed = 9 < 10`). frame 1010: G4 PASS (`elapsed = 10 >= 10`). _Rule 5 G4 + D.1._

**PS-H1-05e** *(Logic BLOCKING)* — R5 G5 ammo guard (D.5 bypass mock).
**GIVEN** `ammo_count = 0` (auto-reload bypass mock — pre-D.5),
**WHEN** `_try_fire()` 호출,
**THEN** G5 BLOCK. (Tier 1에서 D.5 auto-reload이 이 상태를 즉시 transition; mock은 D.5 disable.) _Rule 5 G5._

**PS-H1-06** *(Logic BLOCKING)* — R6 Projectile cap silent skip (INV-WS-3 collapsed).
**GIVEN** `_active_projectile_count = 8` (PROJECTILE_CAP) AND `_try_fire()` G1..G5 모두 PASS,
**WHEN** `_try_fire()` 호출,
**THEN** spawn 발생 X AND `shot_fired` emit X AND `_fire_cooldown_frame` 변경 X AND `ammo_count` 변경 X. (silent skip — no SFX/VFX/error/log/cooldown stamp). _Rule 6 + E-PS-6 + INV-WS-3._

**PS-H1-07** *(Integration BLOCKING)* — R7 Projectile parent target.
**GIVEN** Stage scene root에 `Projectiles: Node2D` 컨테이너 존재,
**WHEN** `spawn_projectile()` 호출 후 spawned Projectile 추적,
**THEN** `spawned_projectile.get_parent().name == "Projectiles"` AND `spawned_projectile.get_parent() != _weapon_slot`. _Rule 7._

**PS-H1-08** *(Logic BLOCKING)* — R8 HitBox 자식 config.
**GIVEN** Projectile `.tscn` instantiation,
**WHEN** `_ready()` 직후 검증,
**THEN** Projectile root는 `HitBox extends Area2D` 자식 1개 보유 AND `HitBox.collision_layer == 2` AND `HitBox.collision_mask == 3 | 6 == 36` (bitmask 0b00100100) AND `HitBox.monitoring == true` AND `HitBox.cause == &""` AND `HitBox.host == Projectile root`. _Rule 8 + damage.md C.1.1 + DEC-4._

**PS-H1-09** *(Integration BLOCKING)* — R9 Self-fire 차단.
**GIVEN** Projectile HitBox `collision_layer = 2`, `collision_mask = 3 | 6` AND ECHO HurtBox `collision_layer = 1`,
**WHEN** ECHO 자체 Projectile이 ECHO HurtBox와 동일 spatial 위치,
**THEN** `area_entered` emit 발생 X (Godot 4.6 collision filter 사전 차단). _Rule 9 + damage.md C.2.4._

**PS-H1-10** *(Logic BLOCKING)* — R10 No knockback.
**GIVEN** `_player.velocity = Vector2(100, 0)` (run 중) AND `_try_fire()` PASS,
**WHEN** `_try_fire()` 실행 + spawn 후,
**THEN** `_player.velocity` *unchanged* (same magnitude + direction). _Rule 10 + PM C.1.3._

**PS-H1-11a** *(Logic BLOCKING)* — R11 invalid id silent fallback.
**GIVEN** `_active_id = 0`, `ammo_count = 15`,
**WHEN** `set_active(999)` 호출 (invalid; `WeaponConfig.is_valid_id(999) == false`),
**THEN** `_active_id == 0` (unchanged) AND `ammo_count == 15` (unchanged) AND `weapon_fallback_activated(999)` emit 발생 AND `weapon_equipped` emit 발생 X. _Rule 11 + E-PS-8._

**PS-H1-11b** *(Logic BLOCKING)* — R11 same_id idempotent.
**GIVEN** `_active_id = 0`, `ammo_count = 15`,
**WHEN** `set_active(0)` 호출,
**THEN** `_active_id == 0` AND `ammo_count == 15` (NOT reset to MAGAZINE_SIZE) AND signal emit 모두 발생 X. _Rule 11 + E-PS-9._

**PS-H1-12** *(Logic BLOCKING)* — R12 + INV-WS-7 + E-PS-16 boot path.
**GIVEN** WeaponSlot `_ready()` 진입,
**WHEN** `_ready()` 종료 시점 검증,
**THEN** `_active_id == 0` AND `ammo_count == MAGAZINE_SIZE_DEFAULT (=30)` AND `weapon_equipped(0)` emit 발생 OK (PM `_on_weapon_equipped` subscriber 호출됨) AND `_DIR_VECTORS.size() == 8` AND `for i in {1, 3, 5, 7}: abs(_DIR_VECTORS[i].length() - 1.0) < 0.001`. _Rule 12 + INV-WS-7 + E-PS-16._

> **Tension T1 (qa-lead H.10)** — WeaponSlot `process_physics_priority` config check: PM tree-child의 priority 0 자체가 G3 (`_player._is_restoring` read) 정확성을 보장하는 invariant. AC PS-H1-12에 `assert weapon_slot.process_physics_priority == 0` 한 줄 검증 추가 권장 — 구현 시 누락 방지.

**PS-H1-13** *(Logic BLOCKING)* — E-PS-13 boot-time null assert.
**GIVEN** WeaponSlot scene with `@export var player = null` (editor에서 unassigned),
**WHEN** `_ready()` 진입,
**THEN** `assert(player != null, ...)` 발동 → dev build crash; prod에서는 fail-fast error message. _E-PS-13 + Rule 12._

### H.2 Logic / Per-Formula ACs (BLOCKING)

**PS-H2-01** *(Logic BLOCKING)* — D.1 fire cooldown elapsed.
**GIVEN** `_fire_cooldown_active = true`, `_fire_cooldown_frame = 1000`, parametric `Engine.get_physics_frames() ∈ {1001, 1009, 1010, 1011, 2000}`,
**WHEN** D.1 공식 평가,
**THEN** elapsed values = `{1, 9, 10, 11, 1000}`; G4 PASS 조건: elapsed ≥ 10. `_fire_cooldown_active = false`일 때 D.1 비참조 (bool short-circuit PM-B1 패턴 검증). _D.1 + INV-WS-4._

**PS-H2-02** *(Logic BLOCKING)* — D.2 effective_rps parametric.
**GIVEN** `FIRE_COOLDOWN_FRAMES ∈ {6, 10, 20}` (safe range bounds + default),
**WHEN** D.2 공식 평가,
**THEN** `effective_rps = {10.0, 6.0, 3.0}` 각각. _D.2._

**PS-H2-03** *(Logic BLOCKING)* — D.3 `_DIR_VECTORS` unit length + position step.
**GIVEN** `_DIR_VECTORS` 정적 const 배열,
**WHEN** `for i in 0..7: assert abs(_DIR_VECTORS[i].length() - 1.0) < 0.001`,
**THEN** all 8 PASS. **AND** projectile spawn at (100, 50) direction=0, speed=600, FIXED_DELTA=1/60: position step magnitude `abs(velocity * FIXED_DELTA) == 10.0 px/frame`. _D.3._

**PS-H2-04** *(Logic BLOCKING)* — D.4 lifetime expiry frame counter.
**GIVEN** Projectile `_spawn_frame = 5000`,
**WHEN** parametric `Engine.get_physics_frames() ∈ {5089, 5090, 5091}`,
**THEN** at 5089: alive (elapsed=89 < 90); at 5090: `queue_free()` 발동 (elapsed=90 ≥ 90); at 5091: 노드 already freed. _D.4._

**PS-H2-05** *(Logic BLOCKING)* — D.5 magazine auto-reload round-trip.
**GIVEN** parametric `ammo_count_in ∈ {1, 30}`,
**WHEN** `_try_fire()` 성공 시퀀스 (D.5 apply),
**THEN** `ammo_count_in=1` → output 30 (auto-reload trigger); `ammo_count_in=30` → output 29 (정상 decrement). 출력 도메인 `∈ {1..MAGAZINE_SIZE}` invariant. _D.5._

**PS-H2-06** *(Integration BLOCKING)* — D.6 ammo restore round-trip identity (Pillar 1 lock).
**GIVEN** PlayerSnapshot factory snap with `ammo_count = 12` AND TRC + WeaponSlot wired,
**WHEN** `_weapon_slot.restore_from_snapshot(snap)` 동기 호출,
**THEN** `_weapon_slot.ammo_count == 12`.
**Chain extension**: snap.ammo_count=12 → ECHO DYING window 중 ammo decremented to 0 → TRC `try_consume_rewind() == true` → C.2.6 atomic sequence 실행 → post-sequence `_weapon_slot.ammo_count == 12` (NOT 0; Pillar 1 contract). _D.6 + C.2.6 + ADR-0002 Amendment 2._

### H.3 Logic / Per-Invariant ACs (BLOCKING — after H.1 collapse)

**PS-H3-01** *(Logic BLOCKING)* — INV-WS-1 ammo single-writer spy harness.
**GIVEN** `TestWeaponSlot extends WeaponSlot` with `_external_write_count: int = 0` override; TRC read path instrumented for N=90 ticks of `_capture_to_ring`,
**WHEN** TRC executes 90 ticks of snapshot capture (read path; no rewind),
**THEN** `_external_write_count == 0` AND `ammo_count` unchanged throughout (TRC는 read만; never write). _INV-WS-1 + time-rewind.md AC-A1 reciprocal._

**PS-H3-04** *(Logic BLOCKING)* — INV-WS-4 cooldown stamp non-negative.
**GIVEN** any successful `_try_fire()` 시점,
**WHEN** post-`_try_fire` 상태 검증,
**THEN** `_fire_cooldown_frame >= 0`. **AND** `_fire_cooldown_active == false`일 때 D.1 공식 비참조 (bool short-circuit). _INV-WS-4 + PM-B1 패턴._

**PS-H3-05** *(Logic BLOCKING)* — INV-WS-5 `_active` single-writer (R5 G1 + C.2.3 collapsed).
**GIVEN** WeaponSlot scene with EchoLifecycleSM signal connected,
**WHEN** parametric state transitions: AliveState → DyingState → RewindingState → AliveState,
**THEN** `_active` value follows: true → false → true → true (per C.2.3 handler). GREP-PS-4 static check가 외부 write site 0 검증. _INV-WS-5 + Rule 5 G1._

**PS-H3-06** *(Integration BLOCKING)* — INV-WS-6 TRC restore atomicity.
**GIVEN** PM stub + WeaponSlot stub with `_restore_frame_stamp: int` recorders; TRC `try_consume_rewind() == true`; snap.ammo_count = 17,
**WHEN** TRC `_physics_process` 실행 (C.2.6 3-step sequence),
**THEN** `pm.restore_frame_stamp == ws.restore_frame_stamp == Engine.get_physics_frames()` (same tick) AND both `<` `rewind_completed_emit_frame_stamp` AND `WeaponSlot.ammo_count == 17` post-sequence. _INV-WS-6 + C.2.6 + time-rewind.md AC-D4/D5 mirror._

### H.4 Integration / Per-Edge-Case ACs (BLOCKING / ADVISORY)

**PS-H4-03** *(Integration BLOCKING)* — E-PS-3 same-tick fire + lethal hit.
**GIVEN** tick N에 ECHO 상태 = AliveState AND `_try_fire()` G1..G5 모두 PASS AND ECHO HurtBox에 enemy projectile 충돌 예약,
**WHEN** tick N `_physics_process` 실행 (Damage at priority=2 → lifecycle DYING 전이),
**THEN** tick N에 spawn_projectile 정상 발생 (priority 0 WeaponSlot이 priority 2 Damage 이전 실행) AND tick N+1에 `_active == false` AND tick N+1 `_try_fire()` G1 BLOCK. _E-PS-3 + Rule 5 G1._

**PS-H4-04** *(Integration BLOCKING)* — E-PS-4 REWINDING hold-fire G3 1-tick block.
**GIVEN** REWINDING 진입 직후 + `_player._is_restoring == true` 1 tick,
**WHEN** hold-fire 유지 + restore tick 1프레임 + 30프레임 REWINDING signature window,
**THEN** restore tick에서 G3 BLOCK (1번); 그 외 30프레임에서 `_try_fire()` G3 PASS + cooldown/ammo 정상 평가 + spawn 발생. _E-PS-4 + TR Rule 10._

**PS-H4-05** *(Logic BLOCKING)* — E-PS-5 rewind 직후 cooldown 자연 만료.
**GIVEN** `_fire_cooldown_frame = K` (any value), rewind window passes (>=90 frames elapse),
**WHEN** rewind 직후 첫 `_try_fire()` 호출,
**THEN** G4 PASS automatically (`elapsed >= REWIND_WINDOW_FRAMES > FIRE_COOLDOWN_FRAMES`); 별도 cooldown reset 없음. _E-PS-5 + G.3 invariant 2._

**PS-H4-07** *(Logic ADVISORY)* — E-PS-7 Stage Projectiles container missing.
**GIVEN** Stage scene root에 `Projectiles` 명명 노드 부재 (dev build),
**WHEN** `_try_fire()` 성공 후 `spawn_projectile()` 호출,
**THEN** `push_error` 발동 + `assert(false)` (dev only; prod 환경 비검증). ADVISORY because assert path is dev-only. _E-PS-7._

**PS-H4-10** *(Integration ADVISORY)* — E-PS-10 `cause = &""` enemy hit.
**GIVEN** ECHO projectile HitBox(`cause = &""`) hits enemy HurtBox,
**WHEN** damage.md C.1.2 sequence 실행 (enemy-side),
**THEN** enemy destroy 정상 + cause 라벨 무관. **damage.md tests own**; ADVISORY here. _E-PS-10._

**PS-H4-11** *(Logic BLOCKING)* — E-PS-11 viewport-external fire.
**GIVEN** ECHO position = `(2000, -500)` (viewport 외부 가정),
**WHEN** `_try_fire()` G1..G5 모두 PASS,
**THEN** projectile 정상 spawn AND lifetime expiry까지 (D.4 frame counter) 정상 진행 (camera-relative 검사 부재). _E-PS-11._

**PS-H4-12** *(Integration ADVISORY)* — E-PS-12 same-tick multi-projectile multi-hit.
**GIVEN** 2 ECHO projectiles 동일 tick 동일 enemy HurtBox 적중,
**WHEN** damage.md C.3.2 step 0 guard 평가,
**THEN** 첫 hit이 enemy destroy; 두 번째 projectile `area_entered` 정상 발화 (queue_free 호출 OK). **damage.md tests own primary guard**; ADVISORY here. _E-PS-12 + damage.md C.3.2._

**PS-H4-14** *(Integration BLOCKING)* — E-PS-14 priority order vs lethal hit.
**GIVEN** WeaponSlot `process_physics_priority = 0` (tree child of PM) AND damage `priority = 2`,
**WHEN** tick N priority cascade 검증,
**THEN** WeaponSlot tick (PM 직후) → Damage tick (priority 2) 순서; tick N에 `_try_fire()` 성공 → ammo decrement 정상 → spawn 정상 → tick N에 lethal_hit_detected emit (Damage) → tick N+1부터 `_active == false`. _E-PS-14._

**PS-H4-15** *(Integration ADVISORY)* — E-PS-15 i-frame window shoot.
**GIVEN** REWINDING signature window (30 frames i-frame; HurtBox.monitorable = false per damage.md DEC-4),
**WHEN** hold-fire 유지,
**THEN** ECHO 발사체 정상 emit damage (layer 2 active scanner — i-frame과 무관) AND ECHO 자체는 enemy 발사체로부터 면제. **EchoLifecycleSM tests own i-frame toggle**; ADVISORY here. _E-PS-15._

### H.5 Integration / Cross-doc reciprocal ACs (BLOCKING)

**PS-H6-01** *(Integration BLOCKING)* — PM C.4.4 `_on_anim_spawn_bullet` guard mirror.
**GIVEN** PM `_is_restoring == true` AND PM의 AnimationPlayer가 method-track callback `_on_anim_spawn_bullet` 발화,
**WHEN** PM `_on_anim_spawn_bullet` 진입,
**THEN** early return 발동 (`_weapon_slot.spawn_projectile()` 호출 X); WeaponSlot `_active_projectile_count` 불변. PM AC-H1-03 mirror. _PM C.4.4 reciprocal._

**PS-H6-02** *(Integration BLOCKING)* — PM C.4.5 `_on_weapon_equipped` guard mirror.
**GIVEN** PM `_is_restoring == true` AND WeaponSlot `weapon_equipped(weapon_id != snap.current_weapon_id)` emit,
**WHEN** PM `_on_weapon_equipped` 진입,
**THEN** early return 발동; `_current_weapon_id` 불변 (restore step 3에서 snap 값 그대로 유지). PM AC-H1-04 mirror. _PM C.4.5 reciprocal._

**PS-H6-03** *(Integration BLOCKING)* — C.2.6 OQ-PM-NEW (a) direct-call lock.
**GIVEN** TRC signal `rewind_completed`가 WeaponSlot에 *connected 안 됨* (GREP-PS-7 static enforcement),
**WHEN** TRC `try_consume_rewind() == true` 실행,
**THEN** `WeaponSlot.ammo_count == snap.ammo_count` (restoration via TRC direct method call, NOT signal subscription). _C.2.6 + GREP-PS-7._

**PS-H6-05** *(Static BLOCKING)* — state-machine F.2 row #7 — no `transition_to`.
**GIVEN** `src/gameplay/player_shooting/` 디렉터리,
**WHEN** `grep -rEn "\.transition_to\(" src/gameplay/player_shooting/`,
**THEN** 0 matches (state-machine.md F.2 row #7 contract: WeaponSlot is read-only state subscriber). _state-machine.md F.2._

> **Tension T2 (qa-lead H.10)** — Boot signal ordering: WeaponSlot `_ready()` emits `weapon_equipped(0)`. PM이 subscriber가 되기 전 발화 위험. Tree order로 보장되지만 implementer가 `call_deferred` 패턴 적용 권장 (PM C.6 `EchoLifecycleSM` 선례 따름). 별도 PS-H6-04 AC 추가는 user choice (Section H Open Questions Z.5 참조).

### H.6 GREP / Static Analysis ACs (BLOCKING — all in `tools/ci/weapon_slot_static_check.sh`)

**GREP-PS-0** *(Static BLOCKING)* — **MUST RUN FIRST** — directory existence precheck (PS-B2 trap closure).
**GIVEN** `tools/ci/weapon_slot_static_check.sh` invoked,
**WHEN** script step 1 실행: `test -d src/gameplay/player_shooting || exit 1`,
**THEN** missing 시 exit 1 with message "PS-B2 trap: target directory missing — GREP ACs would silently pass". 모든 후속 GREP-PS-1..7 의무적 precheck 통과. _PM-B2 / Input-B7 / SM-RR4-2 trap closure._

**GREP-PS-1** *(Static BLOCKING)* — `ammo_count` write outside `weapon_slot.gd`.
**Pattern**: `grep -rEn "ammo_count\s*=" src/ | grep -v "src/gameplay/player_shooting/weapon_slot.gd" | grep -v "player_snapshot.gd"`,
**THEN** 0 matches (PlayerSnapshot Resource definition file의 RHS read는 scope exclusion 정합 — Tension T3 closure). _INV-WS-1._

**GREP-PS-2** *(Static BLOCKING)* — `_active_id` write outside weapon_slot.gd.
**Pattern**: `grep -rEn "_active_id\s*=" src/ | grep -v "weapon_slot.gd"` → 0 matches. _INV-WS-1._

**GREP-PS-3** *(Static BLOCKING)* — cooldown member write outside weapon_slot.gd.
**Pattern**: `grep -rEn "_fire_cooldown_(active|frame)\s*=" src/ | grep -v "weapon_slot.gd"` → 0 matches. _INV-WS-4._

**GREP-PS-4** *(Static BLOCKING)* — `_active` write outside weapon_slot.gd.
**Pattern**: `grep -rEn "weapon_slot\._active\s*=" src/` → 0 matches AND `grep -rEn "^\s*_active\s*=" src/gameplay/player_shooting/ | grep -v "weapon_slot.gd"` → 0 matches. _INV-WS-5._

**GREP-PS-5** *(Static BLOCKING)* — Projectile add_child 외부 site.
**Pattern**: `grep -rEn "add_child\(.*[Pp]rojectile" src/gameplay/player_shooting/ | grep -v "weapon_slot.gd"` → 0 matches (R7 — only WeaponSlot spawns to Stage Projectiles container). _Rule 7._

**GREP-PS-6** *(Static BLOCKING)* — `_DIR_VECTORS` const declaration.
**Pattern**: `grep -En "const\s+_DIR_VECTORS\s*:\s*Array\[Vector2\]" src/gameplay/player_shooting/weapon_slot.gd` → ≥ 1 match (must be `const`, not `var`). _D.3 + Pillar 2 결정성._

**GREP-PS-7** *(Static BLOCKING)* — `rewind_completed` signal subscription absent (OQ-PM-NEW (a) lock).
**Pattern**: `grep -rEn "rewind_completed\.connect" src/gameplay/player_shooting/` → 0 matches. _C.2.6 + OQ-PM-NEW (a)._

### H.7 Tooling deliverables

| Deliverable | Path | Source |
|---|---|---|
| Static analysis script | `tools/ci/weapon_slot_static_check.sh` | GREP-PS-0..7 (PM `pm_static_check.sh` precedent) |
| Fire / guard logic tests | `tests/unit/player_shooting/weapon_slot_fire_test.gd` | PS-H1-01..06, PS-H1-10, PS-H2-01..05 |
| Ammo / single-writer spy | `tests/unit/player_shooting/weapon_slot_ammo_test.gd` | PS-H1-04, PS-H3-01, PS-H2-05..06 |
| Projectile motion / unit vectors | `tests/unit/player_shooting/projectile_motion_test.gd` | PS-H1-02, PS-H1-03a..c, PS-H2-03..04 |
| Boot + signal ordering | `tests/unit/player_shooting/weapon_slot_boot_test.gd` | PS-H1-12, PS-H1-13, PS-H6-02 |
| Rewind restore integration | `tests/integration/player_shooting_rewind/ammo_restore_test.gd` | PS-H2-06, PS-H3-06, PS-H6-03 |
| Lifecycle state cascade | `tests/integration/player_shooting_lifecycle/active_flag_test.gd` | PS-H3-05, PS-H4-03/04/14 |
| Snapshot fixture factory | `tests/fixtures/player_snapshot_factory.gd` (extend existing or create) | PS-H2-06 |

`weapon_slot_static_check.sh` MUST: (1) GREP-PS-0 directory precheck FIRST, exit 1 if missing; (2) GREP-PS-1..7 patterns sequentially; (3) report all failures before exit. PM B2 / Input B7 / SM RR4-2 trap closure 의무.

### H.U Untestable surface (ADVISORY — playtest / manual)

| ID | Item | Evidence | Owner |
|---|---|---|---|
| H.U1 | Section B "두 동사, 한 몸" fantasy delivery — "나 한 번도 안 멈췄어" | Playtest questionnaire + free-text | QA tester |
| H.U2 | Pillar 3 Steam screenshot moment (sprint vector + diagonal fire vector + cyan/magenta impact simultaneously) | Screenshot + art-director sign-off | `production/qa/evidence/` |
| H.U3 | E-PS-18 `weapons.tres` hot-reload non-support | UX note only; not testable | Pillar 5 accepted |
| H.U4 | E-PS-15 i-frame shoot window feel (0.5초 안전 사격 윈도우) | Playtest sign-off | QA lead |
| H.U5 | Tier 2+ pickup / weapon swap / reload anim | Deferred to Pickup GDD #19 + Tier 2 weapons | Not in Tier 1 scope |
| H.U6 | `weapon_fallback_activated` downstream cue exercise | Tier 1 미발화; Tier 2 Pickup 도입 시 smoke check | Tier 2 gate |
| H.U7 | Steam Deck 1세대 actual draw call profile | Hardware playtest | Tier 1 Week 1 manual session |

## Z. Open Questions

본 절은 본 GDD 작성 시점에 *닫힌* OQ (resolved by this GDD)와 *열린* OQ (deferred to future Tier 2+ design)를 합본한다.

### Z.1 본 GDD가 closed한 cross-doc OQ (Resolved 2026-05-11)

| OQ ID | Source | Resolution site (본 GDD) | 비고 |
|---|---|---|---|
| **OQ-PM-NEW** | `player-movement.md` Z + time-rewind.md F6 + ADR-0002 Amendment 2 | C.2.6 + C.3.4 (a) TRC orchestration lock | Both specialists (systems-designer + gameplay-programmer) converged on (a); (b) signal subscription은 W2-locked `rewind_completed(player, restored_to_frame)` signature가 snap을 carry하지 않으므로 dead-on-arrival. F.4.1 #2 / #4 cross-doc edits로 락인. |
| **OQ-3** (time-rewind.md) | `WeaponSlot.set_active(invalid_id)` silent fallback signaling | C.1 규칙 11 + Rule 11 단계 1: `weapon_fallback_activated(requested_id: int)` 신규 signal | `weapon_equipped`와 의미 분리 (fallback 식별 가능). Tier 1 single-weapon 미발화; Tier 2 Pickup 첫 활성. |
| **input.md C.1.1 row 7 *(provisional)*** | `shoot` action detect mode (edge vs hold) | C.1 규칙 1 + D.1: `is_action_pressed` (hold) lock | Tap-spam은 cooldown counter가 게이트; Contra / HM 패턴 정합. F.4.1 #1 batch edit. |
| **PM F.4.2 → Player Shooting #7 obligations (a)/(b)/(c)** | PM Decision 의무 | C.3.2 + 규칙 4 + C.2.6: signal 정의 (a) + guard reciprocal (b) + ammo restoration policy (c) 모두 close | F.4.1 #2 (TR Rule 9 step 추가) + #5 (architecture.yaml ammo_count entry) cascade. |
| **ADR-0002 Amendment 2 Open Sub-Decisions** | (1) Weapon-side capture site, (2) Restoration mechanism | C.2.6 + F.4.1 #4 Amendment 2 Proposed → Accepted ratification gate | 본 GDD Designed 상태 도달 시 `/architecture-review`이 비준. (1) WeaponSlot per-tick `ammo_count` (TRC `_capture_to_ring` reads); (2) TRC sync method call `restore_from_snapshot(snap)`. |

### Z.2 본 GDD가 발생시키는 신규 OQ (Tier 2+ deferred)

| OQ ID | Question | Target system | Trigger | Tier |
|---|---|---|---|---|
| **OQ-PS-1** | Tier 2+ pickup-post-death `current_weapon_id` 복원 semantics — `_lethal_hit_head - RESTORE_OFFSET_FRAMES` 시점이 픽업 *전*/*후*에 따라 ECHO가 W1/W2 중 어느 무기로 복원되는가? E-PS-17 contract는 "snap 시점 무기"로 lock되지만 *pickup own-state* (예: `_active_id`가 W2 픽업 직후 `ammo_count = MAGAZINE_SIZE_W2`로 reset되었으나 rewind 시 W1으로 돌아가면 `ammo_count` mismatch 위험) | Pickup #19 (Tier 2) | `/design-system pickup` 시 | Tier 2 |
| **OQ-PS-2** | Boot signal ordering — `WeaponSlot._ready()`의 `weapon_equipped.emit(0)` 시점에 PM subscriber가 connect되어 있는가? Tree order로 일반 보장되지만 `call_deferred` 패턴 (PM C.6 EchoLifecycleSM 선례) 적용 권장 여부 | Tier 1 — implementation review | Tier 1 first integration | Tier 1 |
| **OQ-PS-3** | Tier 2+ reload animation — `reload_frames > 0` 도입 시 (1) reload anim spec (frames, sprite asset), (2) reload 도중 사격 차단 (`_reload_active: bool` 추가 member), (3) reload cancel 가능 여부 (weapon swap mid-reload?) | Pickup #19 + Tier 2 무기 디자인 | `/design-system pickup` 또는 Tier 2 무기 디자인 | Tier 2 |
| **OQ-PS-4** | Tier 2+ multi-weapon ammo 관리 — 픽업 시 새 무기 ammo = `MAGAZINE_SIZE_W2`. 이전 무기 ammo (`ammo_count_W1`) 는 (a) 폐기 / (b) 별도 reserve로 보존? | Pickup #19 + Inventory (Tier 2+) | Tier 2 무기 디자인 결정 | Tier 2 |
| **OQ-PS-5** | Tier 2+ pierce / multi-hit 무기 — C.1 규칙 3 hit handler `area is HurtBox: queue_free()` 는 Tier 1 single-hit 가정. Pierce 무기 (Tier 2+ spread/rocket 등)는 `queue_free` 대신 hit list 누적? | Tier 2 무기 디자인 | Tier 2 무기 catalog 결정 | Tier 2 |
| **OQ-PS-6** | Tier 3 accessibility aim assist — 8-way snap을 보조하는 magnetism이 Pillar 2 결정성 위반 위험 (`_DIR_VECTORS` 외 추가 vector 도입 = 결정성 검증 fail). Tier 3 도입 시 *결정성 우회 카테고리*로 분류 필요 | Accessibility #24 (Tier 3) | `/design-system accessibility` 시 | Tier 3 |
| **OQ-PS-7** | Sustained-fire SFX 모델 — Tier 2+에서 single-shot 반복 (Tier 1 Contra/HM 패턴) vs sustained loop (chainsaw 무기 등)? V/A.5 reserved category | Audio System #4 + Tier 2 무기 디자인 | Audio GDD 작성 또는 Tier 2 무기 디자인 | Tier 2 |
| **OQ-PS-8** | Tier 2+ hot-reload of `weapons.tres` — playtest iteration 가속화를 위한 런타임 reload 메커니즘 (E-PS-18 deferred) | dev tooling | Tier 2 디자인 결정 | Tier 2 |

### Z.3 Tier 1 Week 1 prototype 후 재평가 항목 (playtest-driven)

Tier 1 단일 base rifle prototype 동작 후 다음 항목을 playtest로 검증 + 본 GDD 갱신 가능:

1. **Fire rate feel** — 6 rps Tier 1 default가 Section B "uninterrupted motion" fantasy 정합 검증. 너무 빠르면 (4 cap overflow) tuning down; 너무 느리면 tuning up.
2. **Magazine size 30** — 5초 sustained fire 후 auto-reload tick이 시각/청각으로 인지되는지 검증 (HUD가 알려야 하나, 본 시스템은 ammo_count 변화만 expose).
3. **Projectile speed 600 px/s + lifetime 90 frames** — Steam Deck 1세대에서 시각 인식 가능성 검증. art-director's "see your shot" read test.
4. **Projectile cap 8 silent skip 인지성** — sustained hold-fire 시 ~1.3초당 1회 skip이 *체감 가능*한지. 체감 시 cap을 12+로 raise 또는 lifetime을 60으로 trim.
5. **Pillar 1 ammo restoration 카타르시스** — DYING window 중 ammo 0 도달 → rewind → ammo 복원이 player에게 "흐름 복원" 정서로 인식되는지 (D.6 + H.U1).

### Z.4 Open Question 등록 정책 (project pattern)

본 GDD가 발생시킨 OQ는 모두 *target system GDD*가 작성될 때 해당 GDD의 Z section에서 close 의무. OQ-PS-1..8은 본 GDD H section의 AC와 reciprocal 관계 — Tier 2 design 시 본 GDD H section의 ADVISORY AC (H.U5/H.U6)가 promote될 수 있다.
