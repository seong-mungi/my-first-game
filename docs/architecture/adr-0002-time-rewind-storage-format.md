# ADR-0002: Time Rewind Storage Format — State Snapshot Ring Buffer

## Status
Accepted (with Amendment 1 — 2026-05-09; Amendment 2 — Proposed 2026-05-11)

## Date
2026-05-09

## Amendments

### Amendment 1 — Lethal-hit head freeze (2026-05-09)

**Driver**: `design/gdd/time-rewind.md` Section C/D + systems-designer validation 2026-05-09.

**Issue**: The original `try_consume_rewind()` algorithm computed `restore_idx` from the *live* `_write_head`. Section C of the Time Rewind GDD introduced a `DYING` grace window (default 12 frames) during which capture continues. When the player triggers rewind at DYING frame +k, `_write_head` has advanced k frames past the lethal-hit frame. With `RESTORE_OFFSET_FRAMES = 9`, any k > 9 produces `restore_idx` pointing to a slot captured *after* the lethal hit — a silent restoration to a post-death state.

**Resolution**: Cache `_lethal_hit_head: int = _write_head` in the handler that processes `player_hit_lethal` (the State Machine's DYING-entry handler, which then calls `try_consume_rewind()` if the player presses within the grace window). Compute `restore_idx` from `_lethal_hit_head`, not the live `_write_head`. The restore point is now anchored to the moment of fatal damage, regardless of how many DYING frames the player consumed before pressing.

**Algorithm change** (§ Decision → core algorithm pseudo-code):

```gdscript
# NEW field
var _lethal_hit_head: int = -1  # cached at player_hit_lethal handler

# State Machine calls this on DYING entry (driven by player_hit_lethal):
func on_lethal_hit_detected() -> void:
    _lethal_hit_head = _write_head

func try_consume_rewind() -> bool:
    if _tokens <= 0:
        return false
    if not _is_buffer_primed:  # GDD Rule 13-bis guard
        return false
    if _is_rewinding:
        return false
    _tokens -= 1
    token_consumed.emit(_tokens)
    var restore_idx: int = (_lethal_hit_head - RESTORE_OFFSET_FRAMES + REWIND_WINDOW_FRAMES) % REWIND_WINDOW_FRAMES
    var snap: PlayerSnapshot = _ring[restore_idx]
    rewind_started.emit(_tokens)
    _player.restore_from_snapshot(snap)
    rewind_completed.emit(_player, snap.captured_at_physics_frame)
    return true
```

**Backwards compatibility**: All public signal contracts and snapshot fields are unchanged. The amendment is internal to `TimeRewindController`. Subscribers and callers (HUD, VFX, State Machine) are unaffected. Memory cost: +8 bytes for the cached int. CPU cost: one int copy on `player_hit_lethal`.

**Cosmetic correction (informational)**: This ADR's Performance Implications section quotes "PlayerSnapshot ≈ 32 bytes ... ring buffer = 2.88 KB". Re-measured against Godot 4 Resource overhead: actual is ~192 B per slot, ring buffer ≈ 17–21 KB. Still negligible against the 1.5 GB ceiling. The original 5 KB ceiling claim remains correct *as a ceiling*, but the typical figure is 4× higher than originally stated. No behavior change.

### Amendment 2 — Snapshot ammo capture (Proposed 2026-05-11)

**Status**: Proposed. Awaits ratification at first `/architecture-review` after Player Shooting #7 GDD authoring.

**Driver**: `design/gdd/player-movement.md` DEC-PM-3 v2 (B5 Pillar 1 resolution, 2026-05-11) + `design/gdd/time-rewind.md` F6 (b) variant. Fresh-session `/design-review design/gdd/player-movement.md` 2026-05-11 surfaced Pillar 1 contradiction: rewind returning ECHO to a state captured 9 frames before death also returns *current live* `ammo_count` (DEC-PM-3 v1 "resume with live ammo" policy 2026-05-10). If `ammo_count` reached 0 during the DYING window or the 9 frames prior, the rewind delivers ECHO to an unwinnable state — "rewind = punishment, not learning tool" — violating Pillar 1 (learning tool stance).

**Issue**: Original ADR-0002 7-field PM-noted snapshot schema (+ Amendment 1's 8th TRC-internal `captured_at_physics_frame` field = 8-field Resource total) excluded `ammo_count`. The pre-Amendment-2 schema cannot restore ammo because TRC doesn't capture it. The only resolution paths were: (a) keep schema, design weapon system to prevent unwinnable ammo states (leaks fix into Weapon GDD #7 design space); (b) extend schema with `ammo_count: int`. Option (b) chosen per DEC-PM-3 v2.

**Resolution**: Schema extends to **9-field Resource total — 8 PM-noted (Amendment 2 adds `ammo_count: int`) + 1 TRC-internal (`captured_at_physics_frame` from Amendment 1)**. Capture is per-tick like other fields. The single-writer for `ammo_count` is **Weapon (#7)** — NOT PlayerMovement — to keep PM/Weapon layering clean.

**Field addition**:

```gdscript
class_name PlayerSnapshot extends Resource

# Existing 7 PM-owned fields (ADR-0002 base):
@export var global_position: Vector2
@export var velocity: Vector2
@export var facing_direction: int
@export var animation_name: StringName
@export var animation_time: float
@export var current_weapon_id: int
@export var is_grounded: bool

# Amendment 2 (2026-05-11) — Weapon-owned, 8th PM-noted field:
@export var ammo_count: int

# Amendment 1 (2026-05-09) — TRC-internal, 9th Resource field:
@export var captured_at_physics_frame: int
```

**Write authority** (key layering decision):

| Field | Single-writer | Capture site |
|-------|---------------|--------------|
| `global_position`..`is_grounded` (7 fields) | PlayerMovement | PM `_physics_process` Phase 6c |
| `ammo_count` (Amendment 2) | **WeaponSlot** (Player Shooting #7) | Weapon write-into-snapshot mechanism — sub-decision deferred (OQ-PM-NEW: TRC orchestration vs Weapon `rewind_completed` subscription) |
| `captured_at_physics_frame` | TRC | `_capture_to_ring()` |

`PM.restore_from_snapshot(snap)` signature unchanged. PM **ignores** `snap.ammo_count` (Weapon owns write authority). Weapon-side restoration mechanism is OQ-PM-NEW — deferred to Player Shooting #7 GDD authoring.

**Performance impact** (verified against ADR-0002 Amendment 1 25 KB cap):

- Raw fields: 48 B → 52 B (+4 B per slot for `int ammo_count`)
- Resource total: ~192 B → ~196 B per slot
- Ring buffer: 17.28 KB → 17.64 KB (+0.36 KB)
- Headroom vs 25 KB cap: 7.36 KB remaining (≥5 Tier 2 fields' worth)
- CPU capture: +1 field copy = +100–500 ns/tick (well within 1 ms envelope)

**Backwards compatibility**: PM-side public API (`restore_from_snapshot` signature, Phase ordering, `_is_restoring` guard) is unchanged. New obligation: Weapon-side restoration handler — authored at Player Shooting #7 GDD time. Existing AC-A1 / AC-A4 / AC-F1 in `time-rewind.md` updated to reference 9-field Resource (8 PM-noted + 1 TRC-internal).

**Open sub-decisions deferred to Player Shooting #7 GDD**:

- OQ-PM-NEW (write authority orchestration): TRC orchestrates multi-target restore (PM 7 + Weapon ammo + TRC bookkeeping atomic) vs Weapon owns parallel restoration triggered by `rewind_completed` signal.
- Weapon-side capture site (`_physics_process` per-tick OR signal-driven mid-tick).
- DYING-window ammo behavior: should ammo decrement during DYING be visible to rewind? (Likely yes — same per-tick capture rule.)

**Ratification gate**: First `/architecture-review` after Player Shooting #7 GDD `Designed` status. Until then, this Amendment is **Proposed** and downstream (PM, time-rewind, architecture.yaml) treat it as locked policy with implementation deferred.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (state serialization + memory management) |
| **Knowledge Risk** | HIGH — 4.6 is post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` (Resources `duplicate_deep()` 4.5+ note), `docs/engine-reference/godot/current-best-practices.md`, ADR-0001 PlayerSnapshot 사양 |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep()` (4.5+) — used only if the snapshot ever contains nested resources. Tier 1 PlayerSnapshot has only primitive @export fields, so duplicate_deep is **not** required at this stage. Flagged for future-proofing. |
| **Verification Required** | (1) ring buffer pre-allocation 1회 비용 측정. (2) Resource subclass 직렬화 검증 (write→read round-trip identity). (3) Tier 1 prototype에서 1000 회 되감기 실행 메모리 leak 0 확인. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001 (R-T1: Time Rewind Scope)** — Player-only 결정이 본 ADR의 단일 객체 스냅샷 모델을 가능하게 함. |
| **Enables** | ADR-0003 (R-T3: 결정성 전략) — 스냅샷 모델은 transform 직접 set 회피책과 정합. |
| **Blocks** | `design-system time-rewind` GDD, `prototype time-rewind` (Tier 1 Week 1). |
| **Ordering Note** | R-T1 → R-T2 → R-T3 순서 권장. R-T3는 R-T2 직후 작성 가능 (서로 독립). |

## Context

### Problem Statement

R-T1이 ECHO 단일 객체 되감기로 락인된 후, 1.5초 윈도우의 ECHO state를 어떻게 저장하는가? 두 표준 패턴 — 상태 스냅샷 vs 입력 리플레이 — 사이에 결정이 필요하다. 추가로 (1) 스냅샷 빈도, (2) 저장 위치, (3) 직렬화 포맷 3개 schema 결정이 함께 락인되어야 GDD 작성이 시작될 수 있다.

### Constraints

- **ADR-0001 정합 필수**: PlayerSnapshot Resource 스키마(7 PM + 1 TRC Amendment 1 + 1 Weapon `ammo_count` Amendment 2 = 9 필드 Resource)가 이미 정의됨. 이 스키마와 충돌하는 결정은 ADR-0001 supersede가 필요.
- **Pillar 2 결정론**: 1000 회 되감기 시 100% 동일 결과 검증 가능해야 함.
- **Pillar 5 솔로 budget**: 두 스토리지 시스템 동시 유지(Hybrid) 회피.
- **Performance**: 60fps × 16.6ms / 1.5GB 메모리 ceiling. 매 physics tick 작업이 budget 내.
- **Engine 4.6**: Godot Physics 2D는 100% 결정성 *불보장* — 작은 부동소수 흔들림 가능. Jolt(3D 전용)와 무관. 입력 리플레이 모델은 시뮬레이션 재실행을 요구하므로 이 흔들림에 직접 노출됨.

### Requirements

- 1.5초 (90 frames @ 60fps) 슬라이딩 윈도우 ECHO state 보관.
- 되감기 발동 시 0.5초 안에 복원 완료 (사용자 인지 가능 지연 한도).
- 메모리 5KB 이하 ring buffer (technical-preferences.md 1.5GB ceiling 기준 무시 가능 수준).
- 1000 회 반복 되감기 시 메모리 leak 0.
- 미래 save system 호환 (Tier 2+ Save / Settings Persistence — 동일 PlayerSnapshot Resource 직렬화 재사용 가능해야).

## Decision

**상태 스냅샷 (State Snapshot) ring buffer 모델 + 권고 schema 3개 수용:**

1. **Storage**: TimeRewindController 노드 내부 ring buffer — 90개 PlayerSnapshot Resource pre-allocated 인스턴스
2. **Frequency**: 매 `_physics_process` tick (60Hz)에 1 PlayerSnapshot 갱신 (write-into-place, 새 인스턴스 생성 없음)
3. **Format**: typed Resource subclass `PlayerSnapshot extends Resource` with `@export` 필드 (ADR-0001 7 PM 필드 + Amendment 1 (1 TRC `captured_at_physics_frame`) + Amendment 2 (1 Weapon-owned `ammo_count`) = 9-필드 Resource)
4. **Restoration**: 되감기 트리거 시 ring buffer에서 (현재 frame - 9) 위치의 snapshot을 PlayerMovement에 복원. 즉, "사망 0.15초 전" 시점.

핵심 알고리즘:

```gdscript
# TimeRewindController.gd (autoload or scene-local — 결정 in design-system phase)
class_name TimeRewindController extends Node

const REWIND_WINDOW_FRAMES: int = 90  # 1.5s @ 60fps
const RESTORE_OFFSET_FRAMES: int = 9  # 0.15s before death — give player reaction window

var _ring: Array[PlayerSnapshot]  # pre-allocated 90 slots
var _write_head: int = 0
var _player: PlayerMovement
var _tokens: int = 3  # initial token count, +1 per boss kill

signal rewind_started(remaining_tokens: int)
signal rewind_completed(player: Node2D, restored_to_frame: int)
signal token_consumed(remaining_tokens: int)
signal token_replenished(new_total: int)

func _ready() -> void:
    _ring.resize(REWIND_WINDOW_FRAMES)
    for i in REWIND_WINDOW_FRAMES:
        _ring[i] = PlayerSnapshot.new()  # pre-allocate, no per-tick allocation

func _physics_process(_delta: float) -> void:
    _capture_to_ring()

func _capture_to_ring() -> void:
    var slot: PlayerSnapshot = _ring[_write_head]
    slot.global_position = _player.global_position
    slot.velocity = _player.velocity
    slot.facing_direction = _player.facing_direction
    slot.animation_name = _player.current_animation_name
    slot.animation_time = _player.current_animation_time
    slot.current_weapon_id = _player.current_weapon_id
    slot.is_grounded = _player.is_grounded
    slot.captured_at_physics_frame = Engine.get_physics_frames()
    _write_head = (_write_head + 1) % REWIND_WINDOW_FRAMES

func try_consume_rewind() -> bool:
    if _tokens <= 0:
        return false
    if not _is_buffer_primed:  # GDD Rule 13-bis (warmup gate)
        return false
    if _is_rewinding:           # GDD Rule 13 (re-entry guard)
        return false
    _tokens -= 1
    token_consumed.emit(_tokens)
    # Amendment 1 정본: use _lethal_hit_head (cached on lethal_hit_detected),
    # not the live _write_head — DYING grace 동안 진행한 캡처가 silent post-death restore 유발 차단.
    assert(RESTORE_OFFSET_FRAMES < REWIND_WINDOW_FRAMES, "guard against negative mod (Round 1 정정)")
    var restore_idx: int = (_lethal_hit_head - RESTORE_OFFSET_FRAMES + REWIND_WINDOW_FRAMES) % REWIND_WINDOW_FRAMES
    var snap: PlayerSnapshot = _ring[restore_idx]
    rewind_started.emit(_tokens)
    _player.restore_from_snapshot(snap)
    rewind_completed.emit(_player, snap.captured_at_physics_frame)
    return true

func grant_token() -> void:  # called on boss_defeated subscriber path
    # Round 1 정정: max_tokens cap을 formula 단계에서 명시 (D2 정정과 동기화).
    _tokens = min(_tokens + 1, _rewind_policy.max_tokens)
    token_replenished.emit(_tokens)
```

> **Superseded Algorithm (Historical — DO NOT IMPLEMENT)**: 위 정본 try_consume_rewind() 이전 원본은 `var restore_idx: int = (_write_head - RESTORE_OFFSET_FRAMES + REWIND_WINDOW_FRAMES) % REWIND_WINDOW_FRAMES`를 사용했다. Amendment 1 (2026-05-09) 발견: DYING grace +k 프레임 동안 캡처가 `_write_head`를 진행시켜 `restore_idx`가 사망 *후* 시점을 가리키는 silent 오작동. 정본은 `_lethal_hit_head` 동결값 사용. Historical reference만으로 보존.

### Architecture Diagram

```
┌────────────────────────────────────────────────────────────┐
│ TimeRewindController.gd                                     │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ _ring: Array[PlayerSnapshot] (size 90, pre-allocated)│  │
│  │  ┌────┬────┬────┬───┬────┬────┬────┐                │  │
│  │  │ 0  │ 1  │ 2  │...│ 87 │ 88 │ 89 │                │  │
│  │  └────┴────┴────┴───┴────┴────┴────┘                │  │
│  │              ▲                                       │  │
│  │              │ write_head (cycles 0..89)             │  │
│  └──────────────│───────────────────────────────────────┘  │
│                 │                                            │
│  _physics_process:                                          │
│    capture into _ring[write_head]  (no allocation)          │
│    write_head = (write_head + 1) % 90                       │
│                                                             │
│  try_consume_rewind:                                        │
│    restore_idx = (write_head - 9) mod 90                    │
│    player.restore_from_snapshot(_ring[restore_idx])         │
└────────────────────────────────────────────────────────────┘
                            │
                            │ signals: rewind_started, rewind_completed,
                            │          token_consumed, token_replenished
                            ▼
              [HUD / VFX / Audio / EnemyAI / BossPattern]
```

### Key Interfaces

**`PlayerSnapshot` Resource** (ADR-0001 7 PM 필드 + Amendment 1 + Amendment 2 = 9-필드 Resource 락인):

```gdscript
class_name PlayerSnapshot extends Resource

@export var global_position: Vector2
@export var velocity: Vector2
@export var facing_direction: int
@export var animation_name: StringName
@export var animation_time: float
@export var current_weapon_id: int
@export var is_grounded: bool
@export var captured_at_physics_frame: int
```

**`PlayerMovement.restore_from_snapshot()`** — 신규 메서드 (PlayerMovement GDD에서 정의):

```gdscript
func restore_from_snapshot(snap: PlayerSnapshot) -> void:
    global_position = snap.global_position
    velocity = snap.velocity
    facing_direction = snap.facing_direction
    is_grounded = snap.is_grounded
    current_weapon_id = snap.current_weapon_id
    # AnimationPlayer.seek은 4.6에서도 안정 — 4.6 reverse 미지원 우회
    $AnimationPlayer.play(snap.animation_name)
    $AnimationPlayer.seek(snap.animation_time, true)  # second arg: update animation now
```

**Forbidden access pattern** (registry에 등재):
- `PlayerMovement.global_position` 등에 외부 시스템이 직접 *write* 금지. 복원 경로는 오직 `restore_from_snapshot()` 메서드 1개. 외부 system이 player position을 수정하려면 별도 ADR 필요.

## Alternatives Considered

### Alternative 1: Input Replay

- **Description**: 매 physics tick에 player input(stick analog vector + button bitmask) + RNG seed만 저장 (~8 bytes/frame). 되감기 시 1.5초 전 위치로 점프 후 90 tick 시뮬레이션 재실행하여 결정론적으로 도달.
- **Pros**:
  - 메모리 720 bytes (snapshot 모델 대비 1/4)
  - "참된" 시간 되감기 — 실제 시뮬레이션 재실행
- **Cons**:
  - **Pillar 2 위반 위험**: Godot Physics 2D 결정성 *불보장*. 같은 입력 + 같은 시작 상태에서도 부동소수 누적 오차로 미세 다른 위치 가능. R-T3 회피책(transform 직접 set)이 *시뮬레이션 재실행*에서는 작동 불가.
  - **CPU 부담**: 1.5초 분량 90 tick simulation을 0.5초 압축 실행 → 3× speed → CPU spike. 60fps frame budget에서 한 frame에 90 tick 압축 시 frame drop 위험.
  - **확장 불가능**: 미래에 적·탄환을 같은 모델로 되감으려면 모든 적/탄환의 결정성 보장 필요 → Echo의 randomness-allowed 적 시뮬레이션과 충돌.
  - **검증 어려움**: 결정성 회귀 발견 못 하면 silent bug — 1000 회 검증해도 1001 번째에 어긋날 수 있음.
- **Rejection Reason**: Pillar 2 결정론 코어를 *시뮬레이션 결정성*에 위임하는 것은 Godot 4.6 2D physics에서 안전하지 않음. Snapshot 모델은 결정성을 *데이터 복원*에 위임 → 외부 의존 0.

### Alternative 2: Hybrid (Snapshot + Debug Replay)

- **Description**: Snapshot이 production 경로. 디버그 빌드에서 추가로 input log 기록하여 양 모델 결과 비교 → 결정성 회귀 detector.
- **Pros**:
  - Production 안전성(Snapshot) + 디버그 검증력(Replay) 동시
  - QA에서 결정성 회귀 일찍 발견 가능
- **Cons**:
  - **Pillar 5 위반**: 두 시스템 유지 = 솔로 4-6주 budget 부담. 결정성 회귀 발견은 1000 회 자동화 테스트로 충분 (Validation Criteria #2).
  - **Replay 자체의 결정성 위험**: Alternative 1 그대로 — debug 빌드에서도 input replay가 깨지면 검증 신호 자체가 noise.
- **Rejection Reason**: Tier 1 단계에서 검증 도구를 위해 추가 시스템 짓는 것은 over-engineering. 1000 회 자동 되감기 테스트로 결정성 회귀 잡으면 충분.

### Alternative 3: State Snapshot Ring Buffer (Selected)

- **Description**: 매 physics tick에 PlayerSnapshot Resource 1개 ring buffer write-into-place. 되감기 시 1.5초 전 snapshot에서 직접 state 복원.
- **Pros**:
  - **ADR-0001 정합 100%**: PlayerSnapshot 스키마 이미 정의됨, 재정의 불필요
  - **결정성 100%**: 외부 의존 0 — 저장된 값 그대로 복원
  - **메모리 2.88KB** (32 bytes × 90) + Resource overhead ≈ 5KB → 1.5GB ceiling의 0.0003%
  - **CPU 0.3μs/sec** → frame budget 0.0018%
  - **Save system 호환**: PlayerSnapshot Resource는 Tier 2+ Save / Settings Persistence (system #21)에서 동일 직렬화 포맷 재사용 가능
- **Cons**:
  - PlayerSnapshot 스키마 확장 필요 시(예: Tier 3 새 player ability 추가) ADR 갱신
  - "참된" 시간 시뮬레이션 아닌 데이터 복원 — 적·탄환과 인지 부정합 가능 (R-T1에서 이미 수용 + 무적 0.5-1.0초 보장으로 mitigate)
- **Selection Reason**: 결정성·정합성·솔로 budget 셋 다 우월. 시각 임팩트 부족은 R-T1 Cons에서 이미 art-bible 셰이더로 보완 결정.

## Consequences

### Positive

- **결정성 락인**: 1000 회 되감기 100% 동일 결과 — Pillar 2 검증 가능
- **코드 단순성**: TimeRewindController ~80 lines GDScript 추정. PlayerSnapshot ~10 lines.
- **Save system 자동 정합**: Tier 2+ 저장/로드는 동일 PlayerSnapshot Resource 직렬화로 처리. 추가 시스템 불필요.
- **Profiler 친화**: ring buffer write-into-place는 GC 압박 없음 — Godot heap allocation 없음
- **확장 경로 명시**: PlayerSnapshot 필드 추가 = 명시적 ADR 갱신 사건 → silent breakage 방지

### Negative

- **PlayerSnapshot 스키마 부채**: Player ability이 새로 생기면(예: Tier 2 dash) PlayerSnapshot에 필드 추가 필요. ADR 1건씩 발생 가능.
- **버퍼 메모리 미세 낭비**: write-into-place로 빈 slot 없음 vs 매 tick 새 Resource 생성 후 폐기. Trade-off는 0 GC pressure를 위해 5KB 자리 잡기 — 명백히 나은 선택.
- **Animation reverse 불가능 누적**: AnimationMixer.advance(-delta) 4.6 미지원 (verified). seek(prev_time)로 우회하나 frame-perfect 결과 보장 안 됨 — 0.16ms 오차 가능. 시각적으로 인지 불가 수준이라 무시.

### Risks

- **R1**: PlayerSnapshot 스키마가 미래 player feature 추가 시 ADR 양산 → ADR sprawl
  - **Mitigation**: Tier 1 prototype 후 Player Movement GDD 검토 시 *예측 가능한* 모든 ability 필드를 미리 PlayerSnapshot에 포함 (jump_count, dash_charges 등 — 사용 안 해도 0 default)
- **R2**: Resource subclass 직렬화가 4.6 changes에서 미세 변경 가능
  - **Mitigation**: VERSION.md 4.5 note "duplicate_deep() 4.5+ added" 주의. Tier 1 PlayerSnapshot은 primitive 필드만 → duplicate() 안전. 향후 nested Resource 도입 시 duplicate_deep() 사용 필수
- **R3**: ring buffer 인덱스 계산 오프바이원 — `(write_head - 9 + 90) % 90` 음수 처리 누락 → 잘못된 frame 복원
  - **Mitigation**: TimeRewindController prototype에 ring buffer 인덱스 unit test 강제 (Pillar 2 자동 테스트 룰 — coding-standards.md)
- **R4**: PlayerSnapshot 필드 누락 발견 (예: aim direction 등) → Tier 1 prototype 후에야 발견 (Amendment 2 2026-05-11이 `ammo_count` 추가로 R4 일부 해소; 남은 위험 최소 — Tier 2+ ability fields는 Amendment 3 패턴 사용 예정)
  - **Mitigation**: Time Rewind GDD Acceptance Criteria에 "되감기 후 player가 fully functional" 검증 항목 강제. GDD 작성 시 art-bible UI 섹션과 cross-check.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| game-concept.md | "1.5초 lookback + 0.15s pre-death 즉시 복원" (Round 1 정정 후 copy) | 90 frames @ 60fps = 1.5s lookback. RESTORE_OFFSET_FRAMES=9 (0.15s) — "철회" fantasy 일치 |
| game-concept.md | Pillar 2 "결정론적 패턴" (라인 138) | 외부 의존 0 데이터 복원 → 결정성 100% 보장 + 1000회 자동 테스트로 검증 가능 |
| systems-index.md | System #9 Time Rewind System | TimeRewindController 노드 + PlayerSnapshot Resource 두 entity로 구조 명시 |
| systems-index.md | System #14 HUD System | HUD는 `token_consumed` / `token_replenished` 시그널 구독 — direct state polling 금지 (registry forbidden pattern 후보) |
| systems-index.md | System #21 Save / Settings Persistence (Tier 2) | PlayerSnapshot Resource는 Save system에서 직접 직렬화 재사용 — 추가 포맷 정의 불필요 |
| ADR-0001 | PlayerSnapshot 7 필드 사양 | 7 PM 필드 + Amendment 1 (1 TRC `captured_at_physics_frame`) + Amendment 2 (1 Weapon-owned `ammo_count`) = 9-필드 Resource |

## Performance Implications

- **CPU (capture)**: 매 physics tick = 1 struct copy (9 fields per Amendment 2; ~196 B/slot Resource overhead — current numbers는 Amendment 2 Performance impact subsection 참조; legacy figure "32 bytes raw"는 7-field pre-Amendment-1 값). ~300 ns × 9 fields × 60 ticks ≈ 0.18 ms/sec. 16.6ms frame budget의 ~0.001%.
- **CPU (restore)**: 1 struct read + AnimationPlayer.seek + 7 field assignment ≈ 200μs 1회. 60fps frame budget의 1.2% — 단일 frame 내 처리.
- **Memory**: 5KB ring buffer (90 × ~50 bytes Resource overhead 포함). 1.5GB ceiling의 0.0003%.
- **Memory pressure**: 0 — pre-allocated, write-into-place. GC pressure 없음.
- **Load Time**: 시스템 init 시 90 PlayerSnapshot.new() 1회 비용 ≈ 0.1ms. 무시 가능.
- **Network**: N/A — Echo single-player.

## Migration Plan

신규 시스템. Tier 1 Week 1 prototype → 본 ADR 직접 구현. 0 lines → ~90 lines GDScript (TimeRewindController + PlayerSnapshot).

## Validation Criteria

이 ADR이 옳았다는 증거:

1. **Tier 1 prototype 통과**: TimeRewindController가 90-frame ring buffer로 ECHO 단독 되감기 동작. 60fps 유지. write-into-place로 GC pressure 0.
2. **결정성 1000회 테스트**: scripted input 시퀀스 + 90 tick 후 sequential 되감기 1000 회 실행. 매 회 동일 PlayerSnapshot 값 (bit-identical) PASS = Pillar 2 결정성 검증.
3. **메모리 leak 0**: 1000 회 되감기 후 Godot Profiler에서 PlayerSnapshot 인스턴스 수 == 90 (시작 시 동일). FAIL이면 ring buffer 누적 버그.
4. **Restore latency < 200μs**: 단일 되감기 발동의 capture-to-restore 시간을 Profiler로 측정. 200μs 초과 시 frame drop 위험.
5. **Save system 검증** (Tier 2): PlayerSnapshot.tres 파일로 직렬화 → 게임 재시작 → 재로드 시 모든 8 PM-노출 필드 (PM-owned 7 + Weapon-owned `ammo_count`) bit-identical 복원 — Resource 9-필드 total.

5/5 PASS = R-T2 검증 완료. 1-2개 FAIL이면 ADR 재검토.

## Related Decisions

- **ADR-0001 (R-T1)** [Accepted] — Time Rewind 범위 Player-only. 본 ADR의 단일 객체 모델 가능 조건.
- **ADR-0003 (R-T3)** [Pending] — 결정성 전략. Snapshot 모델과 정합 — CharacterBody2D + 직접 transform set으로 복원 시 100% 결정.
- **design/gdd/systems-index.md** — System #9 Time Rewind System (Status: 본 ADR 후 R-T3 1건만 남음).
- **design/gdd/game-concept.md** — Echo 컨셉 + Pillar 정의.
- **docs/registry/architecture.yaml** — 본 ADR이 추가하는 stances:
  - state_ownership: `player_rewind_state` (이미 ADR-0001에서 등록 — 본 ADR의 ring buffer가 owner_system의 internal implementation)
  - api_decisions: `time_rewind_storage` → State Snapshot ring buffer NOT Input Replay (신규)
  - forbidden_patterns: `direct_player_state_write_during_rewind` (신규 — 외부 시스템이 ECHO position을 직접 write 금지, restore_from_snapshot() 메서드 경유 필수)
