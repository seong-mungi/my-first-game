# ADR-0001: Time Rewind Scope — Player-Only Checkpoint Model

## Status
Accepted

## Date
2026-05-09

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (gameplay state management) |
| **Knowledge Risk** | HIGH — 4.6 is post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md` (Physics 4.6 section), Godot 4.6 release notes, `github.com/ImTani/godot-time-rewind-2d` (community plugin reference for 2D pattern), GDC 2010 Jonathan Blow Braid implementation talk |
| **Post-Cutoff APIs Used** | None — `CharacterBody2D`, `AnimationPlayer.seek()`, `Node.get_tree().physics_frame` are all pre-4.4 stable APIs. Jolt 4.6 default applies to 3D only and is not used by Echo (2D run-and-gun). |
| **Verification Required** | (1) Tier 1 Week 1 prototype confirms 60fps maintained with 90-frame ring buffer. (2) Determinism test: 1000 rewind cycles produce bit-identical state. (3) Memory profiler confirms ring buffer ≤ 5KB resident. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — this is the first ADR. |
| **Enables** | ADR-0002 (R-T2: storage format — snapshot vs input replay) and ADR-0003 (R-T3: determinism strategy — CharacterBody2D + direct transform) both reference this scope decision. |
| **Blocks** | `design-system time-rewind` GDD, `design-system damage` GDD, `design-system player-movement` GDD, `prototype time-rewind` (Tier 1 Week 1). |
| **Ordering Note** | R-T1 must be Accepted before R-T2 because storage format depends on what state is captured. R-T1 must be Accepted before R-T3 because determinism strategy depends on which entities are rewound. |

## Context

### Problem Statement

Echo의 핵심 차별화 메커닉인 *시간 회수 토큰* 발동 시 — 어떤 엔티티가 1.0-1.5초 전 상태로 되돌아가는가? 세 가지 후보가 있었다: (A) ECHO만 (체크포인트 모델), (B) ECHO + 적 + 탄환 + 환경 (Braid 모델), (C) ECHO + 탄환만 (Hybrid). 이 결정은 메커닉의 픽션 정합성, 결정성 보장, 솔로 개발 작업량, 카타르시스 정체성 모두에 영향을 미친다. GDD 작성 전에 락인되어야 한다.

### Constraints

- **Pillar 1**: 시간 되감기는 *처벌이 아닌 학습 도구*다 (game-concept.md 라인 132-136)
- **Pillar 2**: 결정론적 패턴 — 운(luck)은 적이다 (라인 138-142)
- **Pillar 5**: 첫 게임 = 작은 성공 > 큰 야심 (라인 152-156) — 솔로 4-6주 Tier 1 budget
- **Story 정합성**: REWIND Core는 ECHO 개인 군용 디바이스 (Echo Story Spine.md). 시간 회수 능력은 ECHO 한 명에 국한된 인간 비합리성의 비유.
- **Performance**: 60fps × 16.6ms / 500 draw call / 1.5GB 메모리 ceiling (technical-preferences.md)
- **Engine**: Godot 4.6 2D physics. AnimationMixer.advance(-delta) 미지원, GPUParticles2D reverse 미지원 (4.6 verified).

### Requirements

- 시간 되감기 발동 후 1.5초 이내 ECHO가 이전 위치/상태로 복원되어야 한다.
- 적 패턴 학습이 무의미해지면 안 된다 (Pillar 2).
- 메커닉↔픽션 정합성이 붕괴되면 안 된다 (REWIND Core = 개인 장비 설정).
- 60fps 유지 (메모리·CPU 영향 무시 가능 수준).
- Tier 1 4-6주 솔로 budget 안에서 구현 가능.

## Decision

**ECHO(플레이어)만 되감기 대상이다. 적, 탄환, 환경, 파티클은 정상 시뮬레이션을 계속한다.**

발동 시퀀스:
1. 사망 트리거 또는 플레이어 명시적 입력(예: 패드 좌측 트리거) 발생
2. REWIND 토큰 -1 (잔량 0이면 발동 불가, 일반 사망 처리)
3. ECHO의 마지막 90 프레임 (1.5s @ 60fps) 스냅샷 중에서 "사망 0.1초 전" 시점을 선택
4. ECHO state를 복원: position, velocity, facing, animation_time, weapon_state, alive=true
5. 화면 전체에 색반전 + 글리치 셰이더 (art-bible 원칙 C, ~0.5초)
6. 0.5초 후 정상 게임플레이 재개 — 적·탄환은 그동안 정지하지 않고 계속 시뮬레이트되었으므로 ECHO가 부활할 때 즉각 위협 가능

복원되는 ECHO 상태 필드 (R-T2 ADR에서 정확한 직렬화 포맷 결정):
- `global_position: Vector2`
- `velocity: Vector2`
- `facing_direction: int` (-1 / +1)
- `animation_name: StringName`
- `animation_time: float`
- `current_weapon_id: int`
- `is_grounded: bool`

복원되지 않는 것:
- 적 위치·체력·AI 상태 → 그대로 진행
- 탄환 위치·생명주기 → 그대로 진행 (ECHO가 부활한 시점에도 탄환은 살아있을 수 있음)
- 환경 파괴 상태 → 그대로 진행
- VFX 파티클 → REWIND 발동 순간 emitting=false (4.6 reverse 미지원), 0.5초 후 재발화

### Architecture Diagram

```
┌──────────────────────────┐
│ PlayerMovement           │
│ (CharacterBody2D + .gd)  │
│                          │ ──── records snapshot every physics tick ────┐
└──────────────┬───────────┘                                                 │
               │                                                              ▼
               │ on death OR rewind input                          ┌──────────────────────┐
               ├──────────────────────────────────────────────────│ RewindBuffer.gd      │
               │                                                   │ ring_buffer[90]:     │
               │                                                   │   PlayerSnapshot[]   │
               │                                                   └──────────┬───────────┘
               │                                                              │
               │           consume token + restore_from(buffer[N-9])          │
               ▼                                                              │
   ┌────────────────────────┐                                                 │
   │ TimeRewindController   │ ◄──────────────── reads ────────────────────────┘
   │ - consume_token()      │
   │ - on_player_death()    │ ─── emits signal: rewind_started, rewind_completed
   │ - restore_player()     │
   └────────────────────────┘
                                │
                                ▼
                ┌────────────────────────────┐
                │ HUDSystem (subscribes via  │
                │ signal): updates token UI  │
                └────────────────────────────┘

NOT participating in rewind (continue normal simulation):
  - Enemies (drone / security bot / STRIDER boss)
  - Bullets (player + enemy projectiles)
  - Environment (destructible props, hazards)
  - VFX (GPUParticles2D — emit pause + restart on rewind end)
```

### Key Interfaces

**Signal contracts** (registered as architectural stances):

```gdscript
# emitted by TimeRewindController (autoload or scene-local singleton TBD in R-T2)
signal rewind_started(remaining_tokens: int)
signal rewind_completed(player: Node2D, restored_to_frame: int)
signal token_consumed(remaining_tokens: int)
signal token_replenished(new_total: int)  # boss kill +1
```

**Snapshot interface** (PlayerSnapshot — Resource subclass for serialization):

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

**State ownership** (registered):
- `player_rewind_state` → owned by `TimeRewindController` (read-only access via `get_remaining_tokens()` and signals; HUDSystem subscribes to signals)

## Alternatives Considered

### Alternative 1: Braid Model — All Dynamic Entities Rewind

- **Description**: ECHO + 적 + 탄환 + 환경 모든 동적 객체에 ring buffer 부착, 발동 시 동기 되감기. Jonathan Blow Braid (2008)의 모델.
- **Pros**:
  - 시각 임팩트 강력 — "시간을 되돌린다" 메타포에 가장 충실
  - "한 번 더 다른 위치에서 시도" 가능 → 더 자유로운 카타르시스
- **Cons**:
  - **Pillar 2 위반**: 적이 되돌면 학습한 패턴이 다음 시도에서 무효화. 결정론 코어가 깨짐.
  - **Pillar 5 위반**: 모든 적/탄환에 snapshot 시스템 → 시스템 복잡도 ×N. 4-6주 솔로 budget 초과 위험
  - **Story 위반**: ECHO REWIND Core = 개인 장비 설정과 충돌. 왜 적도 되돌아가는가? — VEIL의 모델 외부=인간 비합리성 모티프 붕괴
  - **결정성 위험(R-T3 영향)**: Godot 4.6 2D physics에서 RigidBody2D state 복원 시 미세 비결정성 가능. Player만이면 transform 직접 set으로 100% 결정.
- **Rejection Reason**: Pillar 1, 2, 5 셋 다 위반. Story 정합성 손상. Echo의 정체성과 정반대 방향.

### Alternative 2: Hybrid Model — Player + Bullets Only

- **Description**: ECHO + 모든 탄환만 되감기, 적은 결정론 패턴 그대로 유지.
- **Pros**:
  - "사격 자체를 되돌릴 수 있다" 카타르시스 — 흥미로운 새 메커닉
  - Pillar 2 부분 보존 (적 패턴은 그대로)
- **Cons**:
  - **시각 노이즈**: 마젠타 탄환 20개가 동시에 역재생 → art-bible 원칙 A (명확성 우선 콜라주) 위반. 0.2초 글랜스 테스트 실패.
  - **작업량**: 탄환에 ring buffer + 모든 발사 이펙트에 snapshot → Player only 대비 ~3× 작업량
  - **Story 정합성 약함**: 왜 탄환만 되돌아가는가? 자연스러운 픽션 설명 없음
  - **카타르시스 모호**: "내가 다르게 행동" + "탄환이 되돌아감" 두 카타르시스 혼합 → 어느 것이 핵심인지 불명확
- **Rejection Reason**: 추가 카타르시스 가치보다 명확성·작업량·정합성 비용이 더 큼.

### Alternative 3: Player-Only (Selected)

- **Description**: ECHO만 ring buffer로 되감기. 적·탄환·환경은 정상 시뮬레이션 계속.
- **Pros**:
  - **Pillar 1 정확 일치**: "같은 적/탄환에 *내가* 다르게 대응" = 학습 도구 카타르시스 정의 그 자체
  - **Pillar 2 보존**: 적 패턴 학습이 다음 시도에서 100% 유효
  - **Pillar 5 정합**: 단일 객체 ring buffer = 솔로 작업량 최소
  - **Story 정합**: REWIND Core 개인 장비 + ECHO만이 인간 비합리성을 가진 존재 = VEIL 사각지대 정합성 ⭐⭐⭐⭐⭐
  - **결정성 안전(R-T3)**: CharacterBody2D + transform 직접 set으로 100% 결정적 복원
  - **메모리 부담 무시 가능**: ~3KB ring buffer
- **Cons**:
  - "탄환은 그대로 날아온다" 학습 곡선 — 첫 시도 시 직관적이지 않을 수 있음 (대응: 인트로 직후 짧은 첫 데스→되감기 시퀀스로 학습)
  - Braid 같은 화려한 시각 임팩트 부족 (대응: art-bible 원칙 C — 색반전+글리치 셰이더가 시각 임팩트를 채움)
- **Selection Reason**: 5 Pillars + Story Spine + 솔로 budget + 결정성 4 축에서 모두 최선. 트레이드오프(시각 임팩트)는 셰이더로 보완 가능.

## Consequences

### Positive

- **메커닉↔서사 정합성 락인**: ECHO만 되감기 = 인간 비합리성 = VEIL 모델 외부 (Story Spine 모티프 #2와 정확히 일치)
- **결정론 코어 보존**: Pillar 2가 깨지지 않음 → 적 패턴 디자인이 의미를 가짐
- **솔로 작업량 최소**: 단일 객체 snapshot = 다른 시스템(HUD, VFX, 보스 패턴) 작업에 budget 할당 가능
- **결정성 100% 보장**: Godot 4.6 2D 물리 미세 흔들림(R-T3 위험)이 ECHO 단일 객체에서는 transform 직접 set으로 회피 가능
- **R-T2 ADR 단순화**: 저장 포맷 결정이 단일 PlayerSnapshot 스키마로 압축 → ADR 의사결정 표면 축소

### Negative

- **시각 임팩트 보완 책임**: Braid의 화려한 동시 되감기 효과 포기. art-bible 원칙 C(색반전+글리치)가 임팩트를 채워야 함 → Time Rewind Visual Shader 시스템에 더 무거운 책임 부여.
- **튜토리얼 부담**: 첫 사용자는 "내 위치만 되돌아간다"를 학습해야 함 — 첫 데스 직후 짧은 시퀀스로 가르치는 디자인 책임 생김
- **인터랙션 디자인 제약**: 보스가 ECHO를 "정확히 쫓는" 패턴(예: 호밍 미사일)이 너무 많으면 되감기가 무의미해질 수 있음 → Boss Pattern System(GDD-11)에서 패턴 종류 균형 필요

### Risks

- **R1**: ECHO 위치만 되돌아갔을 때 즉시 같은 적·탄환에 재사망 → 사용자 좌절 ("쓸모없는 메커닉" 인식)
  - **Mitigation**: 되감기 발동 시 ECHO에 0.5-1.0초 무적 부여. 부활 후 재정위 시간 보장.
- **R2**: 적 AI가 "ECHO가 사라졌다 → 다시 나타났다"를 인지하지 못해 어색한 행동 (예: 빈 공간에 계속 사격)
  - **Mitigation**: Enemy AI(GDD-10)에 `on_player_rewind` 시그널 핸들러 추가 — 일부 적은 즉시 ECHO를 재인식, 다른 적은 인지 지연으로 게임플레이 깊이 부여.
- **R3**: 탄환이 되감기 발동 동안 계속 진행하므로 부활 직후 즉사 가능
  - **Mitigation**: R1과 동일 무적 부여 + 되감기 시 화면 전체 셰이더로 0.5초간 가시성 명확
- **R4**: Pickup 무기가 되돌아가지 않으므로 무기 픽업 → 사망 → 되감기 시 무기 보유 상태 불일치
  - **Mitigation**: PlayerSnapshot에 `current_weapon_id` 포함하므로 무기 상태도 복원됨. 단, 픽업 자체(월드의 픽업 오브젝트)는 사라진 상태 유지 → "되감기 후 같은 무기로 다시 시도"가 자연스러운 룰.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| game-concept.md | "1.0-1.5초 회수 시점 (시작 토큰 3, 보스 처치 시 +1)" (라인 75) | 90 프레임 ring buffer @ 60fps = 1.5초 윈도우. 토큰 카운터 시그널로 HUD 동기화. |
| game-concept.md | Pillar 1 "처벌이 아닌 학습 도구" (라인 132) | Player-only 모델은 적/탄환을 그대로 두므로 *학습된 패턴*에 *다르게 대응* 카타르시스가 정의 그대로 작동 |
| game-concept.md | Pillar 2 "결정론 패턴, 운은 적이다" (라인 138) | 적 행동이 되감기 영향을 받지 않음 → 결정론 보존 |
| game-concept.md | "Easy 토글: 토큰 무한, Hard: 토큰 0" (라인 64) | 토큰 시스템이 단일 카운터 변수이므로 Difficulty Toggle System(시스템 #20)에서 trivially 조작 가능 |
| Echo Story Spine.md | "REWIND Core = 디바이스 배터리 = 인간 비합리성 = VEIL 모델 외부" | ECHO만 되감기 = 픽션 일관성 정확히 보존. 적이 되돌아가면 이 정합성 깨짐. |
| systems-index.md System #9 | Time Rewind System Status: Blocked (ADRs) → Unblocked | R-T1 Accepted 후 R-T2/R-T3 ADR 작성 가능. 그 둘이 Accepted되면 Time Rewind GDD 시작. |

## Performance Implications

- **CPU**: 매 physics tick마다 1 PlayerSnapshot 생성 → 7 필드 복사 ≈ 50ns/tick. 60fps × 50ns = 0.3μs/sec → 0.0018% CPU. 무시 가능.
- **Memory**: PlayerSnapshot ≈ 32 bytes (Vector2×2 + int×3 + float×2 + bool×1 + StringName×1 (interned)). 90 프레임 ring buffer = 2.88KB resident. 1.5GB ceiling의 0.0002%. 무시 가능.
- **Load Time**: 시스템 초기화 시 ring buffer pre-allocate (90개 PlayerSnapshot Resource 인스턴스). ~0.1ms 1회 비용. 무시 가능.
- **Network**: N/A — Echo는 single-player.

## Migration Plan

신규 시스템이므로 마이그레이션 대상 없음. Tier 1 Week 1에 Time Rewind GDD를 작성하고 그 직후 prototype을 작성한다. 기존 코드 0줄 → 새 시스템 ~150줄 GDScript 추정.

## Validation Criteria

이 ADR이 옳았다는 증거:

1. **Tier 1 Week 1 prototype**: 90-frame ring buffer로 ECHO 단독 되감기 동작. 60fps 유지. Memory profiler 5KB 미만 확인.
2. **결정성 테스트**: 같은 입력 시퀀스 1000회 반복 실행 시 매 회 동일 시각 동일 위치에서 동일 적·탄환 상태 발생. PASS = 결정성 100%.
3. **Pillar 1 검증 (플레이테스트)**: 첫 사용자 5명 중 4명 이상이 "사망 후 다시 시도할 때 *적 패턴이 같으니 내가 다르게 행동해야겠다*"라고 자발적으로 표현. 실패 시 튜토리얼 디자인 보강.
4. **Pillar 2 검증 (개발자 테스트)**: 같은 적이 같은 시간에 같은 패턴으로 행동 — 이 사실이 되감기 발동 후에도 일관됨 확인.
5. **Story 정합성 검증**: 인트로 텍스트 5줄과 Stage 1 첫 사망→되감기 경험이 모순 없이 흐름. "VEIL은 모든 것을 계산한다 단 하나를 제외하고 — 나는 시간을 되돌릴 수 있다" 인식 가능.

이 5개 모두 PASS하면 R-T1 결정이 검증된다. 1-2개라도 FAIL하면 ADR 재검토 트리거.

## Related Decisions

- **ADR-0002 (R-T2)** [Pending] — Time Rewind 저장 방식: 상태 스냅샷 vs 입력 리플레이. R-T1이 Player-only이므로 단일 객체 스냅샷이 명백한 우선 후보 → R-T2는 비교적 단순한 결정이 될 것.
- **ADR-0003 (R-T3)** [Pending] — 결정성 전략: CharacterBody2D + 직접 transform set vs RigidBody2D + PhysicsServer 동기화. R-T1이 Player-only이므로 ECHO 단독 결정성만 보장하면 충분.
- **design/gdd/game-concept.md** — Echo 컨셉 + Pillar 정의 + Story Spine
- **design/art/art-bible.md** — 원칙 C "시간 되감기 = 색 반전 + 글리치" — 시각 임팩트 보완 책임 명시
- **design/gdd/systems-index.md** — System #9 Time Rewind System (Status: Blocked → R-T1 Accepted 후 부분 unblock)
- **wiki/concepts/Echo Story Spine.md** — REWIND Core 개인 장비 설정 + 인간 비합리성 모티프
- **wiki/sources/MI Final Reckoning Plot.md** — "AI는 모든 것을 계산하나 인간 비합리성은 모델 외부" 모티프 출처
