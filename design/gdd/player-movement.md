# Player Movement

> **Status**: In Design
> **Author**: user + game-designer + godot-gdscript-specialist + systems-designer (planned consultations)
> **Created**: 2026-05-10
> **Last Updated**: 2026-05-10
> **Implements Pillar**: Pillar 2 (결정론적 패턴) primary; Pillar 1 (시간 되감기 = 학습 도구) via clean `restore_from_snapshot()` single-writer; Pillar 5 (출시 가능 우선) via 6-state Tier 1 floor (DEC-PM-1).
> **Engine**: Godot 4.6 / GDScript / 2D / `CharacterBody2D`
> **System #**: 6 (Core / Gameplay)
> **Tier 1 State Count**: 6 (idle / run / jump / fall / aim_lock / dead) — locked 2026-05-10 (revised post-advisor 2026-05-10: `hit_stun` removed per damage.md DEC-3 binary lethal model — no non-lethal damage trigger exists in Tier 1)

---

## Locked Scope Decisions

> *Decisions locked during authoring. Each line is permanent unless explicitly amended via Round 5 cross-doc-contradiction exception. Re-discussion not needed in fresh sessions.*

- **DEC-PM-1** (2026-05-10): Tier 1 PlayerMovementSM = **6 states** (`idle / run / jump / fall / aim_lock / dead`). `hit_stun` removed per damage.md DEC-3 (binary 1-hit lethal — no non-lethal damage trigger). `dash`, `double_jump`, `wall_grip` deferred to Tier 2 evaluation (Pillar 5 작은 성공). Reconsideration trigger: introduction of any non-lethal damage source in Damage GDD or knockback mechanic in Boss Pattern GDD.
- **DEC-PM-2** (2026-05-10): `aim_lock` 의미 = **hold-button** (Cuphead-style lock-aim). 별도 input action `aim_lock` 보유. 버튼 누른 동안 ECHO 정지 + 자유 8-방향 조준 + facing_direction 갱신; 버튼 떼면 즉시 idle/run 복귀. `shoot` 입력은 movement을 freeze하지 *않으며* aim_lock과 독립 (game-concept "점프 + 사격 동시 가능" 보존). Input System #1 GDD가 `aim_lock` action 명명 final 확정 의무.
- **DEC-PM-3** (2026-05-10): Time Rewind 복원 시 ammo 정책 = **"resume with live ammo"** (PlayerSnapshot은 ammo 캡처 안 함). `restore_from_snapshot()` 후 ECHO는 *현재 라이브* `ammo_count`를 사용. DYING grace 안에서 ammo가 0이 된 경우 복원 후에도 0. `time-rewind.md` OQ-1 / E-22 / F6 해소. ADR-0002 amendment 불필요. Player Shooting #7 GDD가 ammo 자체 시맨틱 소유.

---

## A. Overview

Player Movement는 ECHO의 *2D 횡스크롤 이동 · 사격 자세 · 사망 후 복원*을 단일 책임자(`PlayerMovement extends CharacterBody2D`)에서 호스팅하는 코어 게임플레이 시스템이다. 본 시스템은 두 측면의 단일 출처다: (1) **이동 레이어** — 달리기 · 점프 · 낙하 컨트롤 응답성, 8방향 사격용 `facing_direction`, `aim_lock` 동안의 movement-freeze + 자유 8-방향 조준 (DEC-PM-2 hold-button 시맨틱), 그리고 PlayerMovementSM이 호스팅하는 Tier 1 **6 상태** (`idle / run / jump / fall / aim_lock / dead`; DEC-PM-1) — Pillar 1 "1히트 즉사 → 1초 회수 카타르시스"의 *반응성 측면* 담당. (2) **데이터 레이어** — Time Rewind(#9)가 매 `_physics_process` 틱에 read하는 7-필드 `PlayerSnapshot` 스키마 (`global_position` · `velocity` · `facing_direction` · `animation_name` · `animation_time` · `current_weapon_id` · `is_grounded`; ADR-0001 / ADR-0002 락인) + 사망·되감기 시점에 `restore_from_snapshot(snap: PlayerSnapshot) -> void` *단일 경로*로만 write 허용 (forbidden_pattern `direct_player_state_write_during_rewind`의 enforcement site). 결정론(Pillar 2)은 ADR-0003의 `CharacterBody2D` + 직접 transform + `process_physics_priority = 0` 정책으로 보장한다 — solver를 거치지 않으므로 `restore_from_snapshot()`의 직접 필드 할당이 다음 틱의 *권위 있는* state다. Foundation은 아니지만 3중 호스트 책임을 진다: ECHO HurtBox(#8 자식 노드 — DEC-4에 따라 `monitorable` 토글은 SM 책임이며 본 GDD는 노드 *호스팅*만 담당), WeaponSlot(#7), 적·보스가 추격 타깃으로 read하는 위치 데이터(#10/#11). 본 GDD는 이동 메커닉 디자인을 소유하고, 복원 절차의 정확성은 time-rewind.md C.3-C.4 + ADR-0001/0002/0003과의 양방향 정합 의무로 단일 출처를 유지한다.

---

## B. Player Fantasy

### B.1 Core Fantasy — 신체가 기억한다

> "VEIL은 내 몸의 *다음* 위치를 안다. 나는 내 몸의 *이전* 위치로 돌아간다."

Echo의 PlayerMovement는 *카메라가 보는 캐릭터*가 아니라 *손가락 끝이 느끼는 관성*이다. 본 시스템이 호스팅하는 모든 이동 결정 — 달리기 가속 곡선, 점프 각도, 공중 제어 계수, `aim_lock` 동안의 정지+자유 8-방향 조준 (DEC-PM-2), 그리고 사망·되감기 시점의 재진입 — 은 *플레이어의 신체가 화면 안에서 무엇을 기억하고 있는가*에 대한 정의다. 다른 어떤 게임도 *이전 상태로 돌아가는 운동학적 신체 자체*를 핵심 판타지로 만들지 않는다. PlayerMovement는 시간 되감기의 *발현 표면*이며, ECHO의 몸이 0.15초 전의 자기 자신으로 *재진입*하는 그 단일 순간이 Pillar 1 ("시간 되감기는 처벌이 아닌 학습 도구다")을 *플레이어의 손가락 끝에 도달*시킨다.

### B.2 Anchored Player Moment — 9프레임 회수

보스 광역 탄막이 ECHO의 가슴을 찢는 *바로 그 프레임* — 플레이어는 좌트리거(`rewind_consume`)를 누른다. 화면이 시안-마젠타로 찢기고, 0.15초(9프레임) 전의 자신이 *자기 몸 안으로 돌아온다*. 점프 중이었다면 점프 중간 높이로, 좌측 조준이었다면 좌측 조준 그대로 (`PlayerSnapshot.facing_direction` 복원). 입력은 끊기지 않는다 — 같은 좌트리거가 떨어진 직후 새로운 입력이 *연속*된다 (i-frame 30프레임 + DEC-6 hazard grace 12프레임 동안 보호). 9프레임을 *되-실행*하며 플레이어는 같은 탄막을 다시 본다. 이번엔 자신이 그것을 *알고 있다* — 이 *재경험*이 패턴 학습의 단일 운동학적 표상이다.

### B.3 Reference Lineage

| 게임 | 가져온 것 | Echo와 다른 점 |
|---|---|---|
| **Celeste** (2018) | Madeline의 점프 무게감 — 매 프레임 입력이 신체에 닿는 1:1 정확성 | Celeste는 죽음 후 *씬 리셋*; Echo는 *몸 리셋, 세계 유지* |
| **Katana Zero** (2019) | 시간 메커닉 + 1히트 + 즉시 재시작 솔로 표준 | Katana Zero의 Will은 *예지 후 시뮬레이션 재실행*; Echo는 *기억 후 신체 재진입* (사후 vs 사전) |
| **Hotline Miami** (2012) | 즉시 재시작 + 결정론 패턴 + "unfair" 회피 | HM은 탑다운 *씬 리셋*; Echo는 횡스크롤 *연속 신체* (입력 끊기지 않음) |
| **Contra** (1987-2024) | 횡스크롤 + 8방향 사격 + 1히트 즉사의 운동학적 템플릿 | Contra의 점프는 약간의 모멘텀 jitter 허용; Echo는 0 jitter (Pillar 2 + ADR-0003) |

### B.4 The Pillar 1 Bridge — 비협상 두 항목

Pillar 1의 손-끝 도달은 *복원 절차의 정확성*에 의존한다. 다음 두 항목은 비협상이다:

1. **신체 연속성** — `restore_from_snapshot()` 직후 입력이 끊기지 않는다. 토큰 소비 입력(`rewind_consume`)은 그 자체로 *마지막 입력*이 아니며, 다음 `_physics_process` 틱부터 새로운 입력 시퀀스를 즉시 받는다. 입력 큐 reset 금지.
2. **재진입의 가시성** — 콜라주 톤 화면 안에서 *9프레임 전*의 자기 몸이 정확히 그 위치 · facing · 애니메이션 시점으로 재구성됨이 시각·감각적으로 식별 가능해야 한다. `AnimationPlayer.seek(animation_time, true)` 강제 즉시 평가가 단일 출처 (time-rewind.md I4).

### B.5 Anti-Fantasy

| Anti-Fantasy | 왜 Movement이 *그것이 아닌가* | 보장 메커니즘 |
|---|---|---|
| **느낌만 좋고 결정론 깨진 운동** (Contra-style 모멘텀 jitter) | Pillar 2 위반 — 같은 입력 다른 결과는 학습 불가 | ADR-0003 `CharacterBody2D` + 직접 transform; `process_physics_priority = 0` |
| **무거운 운동이 시그니처** (Blasphemous 의도적 sluggishness) | Pillar 4 5분 룰 위반 — 코어 루프 도달 지연 | 입력→velocity 매핑 1프레임 지연 한계 (D.1) |
| **Tier 1에서 dash · double_jump · wall_grip · hit_stun** | Pillar 5 출시 가능 우선 위반 — DEC-PM-1 6-state 락인 (2026-05-10) | C.2 머신은 Tier 1 6 상태만; `hit_stun`은 damage.md DEC-3 binary lethal로 trigger 부재 (Tier 2+); dash/double_jump/wall_grip 확장은 Tier 2 게이트 |
| **사망 후 입력 *대기*가 강제됨** (Contra restart wait 회상) | Pillar 1 해체 — "처벌"의 부활 | `restore_from_snapshot()` 직후 입력 즉시 수용 (B.4 항목 1) |
| **공중에서 360° 제어** (현대 플랫포머 트렌드) | 결정론 패턴 학습 가치 희석 — 공중에서 전부 조정 가능하면 점프 타이밍 학습 무의미 | 공중 제어 계수 < 1.0 (D.1) |

### B.6 Pillar Service Matrix

| 디자인 결정 | Pillar 1 학습 도구 | Pillar 2 결정론 | Pillar 5 작은 성공 |
|---|---|---|---|
| 6-state Tier 1 락인 (DEC-PM-1; hit_stun 제거) | — | direct | **primary** |
| `restore_from_snapshot()` 단일 경로 | **primary** | direct | — |
| `_is_restoring` 플래그 + anim method-track 가드 | direct | **primary** | — |
| 공중 제어 계수 < 1.0 | direct | direct | — |
| `CharacterBody2D` + 직접 transform | direct | **primary** | direct |
| 8방향 사격 + 점프 동시 | direct | — | direct |

---

## C. Detailed Design

### C.1 Node Structure & Class Definition

#### C.1.1 Class hierarchy

`PlayerMovement`는 ECHO root 노드 — `class_name PlayerMovement extends CharacterBody2D` 스크립트가 attach된 `CharacterBody2D` 인스턴스다. Tier 1 이동 레이어(달리기 / 점프 / 낙하 / aim_lock — 6 movement states)와 7-필드 PlayerSnapshot 데이터 레이어를 동시에 단일 호스팅한다.

`process_physics_priority = 0` (ADR-0003 사다리: PM = 0, TimeRewindController = 1, enemies = 10). **속성 위치**: `.tscn` root 노드 Inspector에서 set — 스크립트 전용이 *아니다* (씬 작성 시 누락 위험).

#### C.1.2 노드 트리 (.tscn — 단일 출처)

```
PlayerMovement (CharacterBody2D, process_physics_priority=0)
  [script: player_movement.gd / class_name PlayerMovement]
├── EchoLifecycleSM (Node)
│     [class_name EchoLifecycleSM extends StateMachine — state-machine.md C.2.1]
│   ├── AliveState     (Node — class_name AliveState extends State)
│   ├── DyingState     (Node)
│   ├── RewindingState (Node)
│   └── DeadState      (Node)
├── PlayerMovementSM (Node)
│     [class_name PlayerMovementSM extends StateMachine — state-machine.md M2 reuse]
│   ├── IdleState      (State)
│   ├── RunState       (State)
│   ├── JumpState      (State)
│   ├── FallState      (State)
│   ├── AimLockState   (State)
│   └── DeadState      (State — reactive to EchoLifecycleSM.DYING; NOT parallel ownership)
├── HurtBox            (Area2D — class_name HurtBox, damage.md C.1.1)
├── HitBox             (Area2D — class_name HitBox, damage.md C.1.1)
├── Damage             (Node   — class_name Damage, damage.md C.1; owns HurtBox/HitBox signal wiring)
├── WeaponSlot         (Node2D — Player Shooting #7 (provisional))
├── AnimationPlayer
└── Sprite2D
```

`EchoLifecycleSM`과 `PlayerMovementSM`은 **flat composition** — 어느 한쪽도 다른 쪽을 포함하지 않는다. `PlayerMovementSM.DeadState`는 `EchoLifecycleSM.state_changed` 시그널의 DYING/DEAD 값에 *반응적*으로 진입한다 (signal-reactive, NOT polled — C.6 wiring 명세). 본 트리는 ECHO root 노드 모델의 **단일 출처**이며, state-machine.md C.2.1 line 178-188은 F.4 Bidirectional Update에서 본 GDD에 정렬된다 (Round 5 cross-doc-contradiction exception — A.Overview에서 lock된 `PlayerMovement extends CharacterBody2D` 모델이 권위).

#### C.1.3 7-필드 PlayerSnapshot 출처표 (PlayerMovement single-writer)

| Field | Type | 출처 | Write site (단일 경로) |
|---|---|---|---|
| `global_position` | Vector2 | CharacterBody2D 상속 | `move_and_slide()` 결과 (Phase 5) OR `restore_from_snapshot()` |
| `velocity` | Vector2 | CharacterBody2D 상속 | per-tick velocity 계산 (Phase 4) OR `restore_from_snapshot()` |
| `facing_direction` | int | PlayerMovement 신규 `var facing_direction: int` | per-tick (Phase 6c) OR `restore_from_snapshot()` |
| `current_animation_name` | StringName | `_anim.current_animation` proxy (read-only property) | `AnimationPlayer.play()` (자동 갱신) |
| `current_animation_time` | float | `_anim.current_animation_position` proxy (read-only property) | AnimationPlayer 자체 (자동 갱신) |
| `current_weapon_id` | int | PlayerMovement 신규 `_current_weapon_id` 멤버 | WeaponSlot `weapon_equipped` signal handler OR `restore_from_snapshot()` |
| `is_grounded` | bool | PlayerMovement 신규 `_is_grounded` 멤버 (cached) | `is_on_floor()` 결과 (Phase 6a, post-`move_and_slide()`) OR `restore_from_snapshot()` |

> **TRC 캡처 추가 메타 (PM 노출 X)**: TRC가 ring buffer slot에 8번째 필드 `captured_at_physics_frame: int`을 별도로 기록 (ADR-0002 Amendment 1). PlayerMovement는 이 필드를 노출하지 않으며 TRC가 `_capture_to_ring()` 시점에 `Engine.get_physics_frames()`을 직접 read한다.

**Single-writer policy** (forbidden_pattern `direct_player_state_write_during_rewind` 단일 enforce site):

- 위 7개 필드는 PlayerMovement의 per-tick 갱신 경로와 `restore_from_snapshot()` *외*에는 어떤 외부 시스템도 직접 쓰지 못한다.
- `restore_from_snapshot()` 호출 중 `_is_restoring: bool = true` 플래그가 모든 cascade write 경로(anim method-track 핸들러 / WeaponSlot signal handler / 외부 emit)를 가드한다 — 상세 C.4.
- 본 정책은 **PlayerMovement 자신의 7 필드에만** 적용. 호스팅하는 child 노드의 자체 멤버(예: `HurtBox.monitorable`)는 각 owning GDD가 단일 출처 — `HurtBox.monitorable`은 `EchoLifecycleSM.RewindingState.enter()/exit()` (damage.md DEC-4).

#### C.1.4 자식 노드 GDD 소유권 분리표

| Child node | Class | 호스팅 GDD 소유 | PlayerMovement 역할 |
|---|---|---|---|
| `EchoLifecycleSM` | `extends StateMachine` | state-machine.md (framework) + time-rewind.md (4-state 행동 정의) | parent 노드 제공만 |
| `PlayerMovementSM` | `extends StateMachine` | **본 GDD** (C.2 6-state matrix) | parent + 행동 정의 |
| `HurtBox` | `extends Area2D` | damage.md C.1.1 | 노드 인스턴스 호스팅만; `monitorable` 쓰기 *금지* (DEC-4) |
| `HitBox` | `extends Area2D` | damage.md C.1.1 | 노드 인스턴스 호스팅만 |
| `Damage` | `extends Node` (script) | damage.md C.1 | 노드 인스턴스 호스팅만; 자체 wiring 소유 |
| `WeaponSlot` | `extends Node2D` | Player Shooting #7 *(provisional)* | 노드 인스턴스 호스팅 + `current_weapon_id`만 cache (signal 구독) |
| `AnimationPlayer` | Godot 빌트인 | — | per-tick에서 `current_animation_name/_time` proxy; restore 시 `play()` + `seek(time, true)` |
| `Sprite2D` | Godot 빌트인 | — (art pipeline) | facing_direction 시각화 (flip_h vs 좌/우 anim 분기 — Visual/Audio 섹션 결정) |

### C.2 Movement States and Transitions (PlayerMovementSM)

#### C.2.1 6-state 정의

DEC-PM-1 락인된 6 states. 각 state는 `extends State` 자체 클래스이며 framework state-machine.md 패턴을 재사용 (M2 reuse 검증 케이스 — state-machine.md AC-23).

| State | class_name | 진입 조건 (요약) | 주요 행동 |
|---|---|---|---|
| Idle | IdleState | 기본 시작 + 정지 + grounded | `velocity.x → 0` (decel ramp), `facing_direction` 유지 |
| Run | RunState | `move_axis.x ≠ 0` + grounded | `velocity.x` ramp to ±run_top_speed; **facing_direction = 8-way composite (sign(move_axis.x), sign(move_axis.y))** |
| Jump | JumpState | jump (edge) + (grounded OR coyote) | `velocity.y = −jump_velocity_initial`; `gravity_rising` 적용; **facing_direction = 8-way composite** continually updated |
| Fall | FallState | `velocity.y ≥ 0` (apex) OR jump released early (variable cut) OR floor 잃음 | `gravity_falling`; `air_control_coefficient < 1.0`; **facing_direction = 8-way composite** continually updated |
| AimLock | AimLockState | aim_lock pressed (hold) + **grounded only** (OQ-1 lock) | `velocity = Vector2.ZERO`; **facing_direction = 8-way input (move_axis 전체)** |
| Dead | DeadState | `EchoLifecycleSM.state_changed` → DYING OR DEAD (signal-reactive 단일 경로) | `velocity = Vector2.ZERO`; 입력 무시; anim "dead" |

#### C.2.2 Transition matrix (전수)

> **변동 점프 (OQ-4 lock — Celeste cut)**: jump 입력이 *떨어진 시점*에 `velocity.y < 0` (still rising) 이면 `velocity.y = max(velocity.y, -jump_cut_velocity)` 적용 후 Fall 전이.

> **facing_direction (OQ-2 lock — Composite 8-way)**: outside aim_lock에서도 `move_axis.y`는 `facing_direction` 8-way 갱신에 *사용* (movement에는 영향 없음). 즉 Run/Jump/Fall 동안 ECHO는 좌/우로 달리거나 점프하면서 위/아래 조준이 가능 — B.6 "8방향 사격 + 점프 동시" fantasy 보존.

| # | From | Trigger | Condition | To | Side effects |
|---|---|---|---|---|---|
| T1 | Idle | `move_axis.x ≠ 0` | grounded | Run | `facing_direction` 갱신 |
| T2 | Run | `move_axis.x = 0` | grounded | Idle | velocity.x decel ramp |
| T3 | Idle/Run | jump (edge) | grounded OR `coyote_frames > 0` | Jump | `velocity.y = −jump_velocity_initial`; coyote / jump_buffer 클리어 |
| T4 | Idle/Run | aim_lock pressed (hold) | **grounded only** | AimLock | `velocity = Vector2.ZERO` |
| T5 | Idle/Run | `is_on_floor() = false` | — | Fall | gravity_falling; `_last_grounded_frame` 잠금 (coyote 시작) |
| T6 | Jump | `velocity.y ≥ 0` | — | Fall | gravity_falling 적용 |
| T7 | Jump | jump released (edge) | `velocity.y < 0` (still rising) | Fall | `velocity.y = max(velocity.y, -jump_cut_velocity)`; gravity_falling 적용 |
| T8 | Fall | `is_on_floor() = true` | `move_axis.x = 0` | Idle | velocity.y = 0; landing anim |
| T9 | Fall | `is_on_floor() = true` | `move_axis.x ≠ 0` | Run | velocity.y = 0; facing_direction 갱신 |
| T10 | AimLock | aim_lock released (edge) | `move_axis.x = 0` | Idle | velocity unfreeze (= 0); 입력 정상 복귀 |
| T11 | AimLock | aim_lock released (edge) | `move_axis.x ≠ 0` | Run | velocity unfreeze; facing_direction 갱신 |
| T12 | AimLock | `is_on_floor() = false` (platform 손실) | — | Fall | aim_lock 자동 해제 (입력 hold 무관); gravity_falling |
| T13 | (Idle/Run/Jump/Fall/AimLock) | `EchoLifecycleSM.state_changed` (val=DYING OR DEAD) | signal-reactive | Dead | velocity = Vector2.ZERO; anim "dead" |
| T14 | Dead | `restore_from_snapshot(snap)` | `snap.is_grounded = true, abs(snap.velocity.x) < ε` | Idle | C.4 `_derive_movement_state(snap)` |
| T15 | Dead | `restore_from_snapshot(snap)` | `snap.is_grounded = true, abs(snap.velocity.x) ≥ ε` | Run | C.4 |
| T16 | Dead | `restore_from_snapshot(snap)` | `snap.is_grounded = false, snap.velocity.y < 0` | Jump | C.4 |
| T17 | Dead | `restore_from_snapshot(snap)` | `snap.is_grounded = false, snap.velocity.y ≥ 0` | Fall | C.4 |

> **T14-T17 노트**: Dead → 정상 movement state 분기는 `restore_from_snapshot()` 내부에서 *forced re-enter* (`transition_to(target, payload, force=true)`)로 발화한다. EchoLifecycleSM의 REWINDING→ALIVE `state_changed` signal은 이 시점 *이후* 30프레임에 fire하지만 PlayerMovementSM은 이미 정상 state이므로 추가 전이 강제 안 함 — `_on_lifecycle_state_changed` ALIVE handler에서 `if current_state is not DeadState: return` 가드.

#### C.2.3 Trigger 제약 (PlayerMovementSM signal 구독 정책)

| Trigger 후보 | 허용? | 비고 |
|---|---|---|
| `EchoLifecycleSM.state_changed` (DYING/DEAD) | ✅ 허용 | PM Dead 진입의 *유일* 외부 시그널 경로 (T13) |
| `Damage.player_hit_lethal` 직접 구독 | ❌ 금지 | forbidden_pattern `cross_entity_sm_transition_call`. EchoLifecycleSM 경유만 |
| `Damage.lethal_hit_detected` 직접 구독 | ❌ 금지 | 동상 |
| 자체 polling (`if damage.is_in_iframe(): ...`) | ❌ 금지 | 단방향 데이터 흐름 위반 (damage.md DEC-4) |
| `TimeRewindController.rewind_started` / `rewind_completed` 직접 구독 | ❌ 금지 | EchoLifecycleSM이 시그널 단일 중재자 (state-machine.md C.2.2 O4); PM은 `restore_from_snapshot()` 메서드 호출만 받음 |
| `restore_from_snapshot()` 호출 (PM 자체 메서드) | ✅ 허용 | T14-T17 forced re-enter 트리거 |
| `Input.is_action_*` polling | ✅ 허용 | per-tick `_physics_process` Phase 2 input snapshot |

#### C.2.4 입력 무시 규칙 (헷갈리는 케이스)

- **AimLock 동안 jump 입력**: *무시* (jump_buffer에 추가 안 됨). Cuphead-style hold semantics. 플레이어는 aim_lock 떼고 jump 별도 입력해야 함. AC 의무: AimLock 동안 `jump_just_pressed` 발화 → 다음 tick 점프 발화 안 함.
- **AimLock 동안 `move_axis.x`**: *움직임용 무시* (Run/Idle 전이 안 됨; ECHO velocity = ZERO 유지). 단 `move_axis` 전체(x + y)는 `facing_direction` 8-way 갱신에 사용 (DEC-PM-2 자유 8방향 조준).
- **Outside aim_lock에서 `move_axis.y`**: *movement에 영향 없음*. `facing_direction` 8-way 갱신에만 사용. ECHO는 좌/우로 달리며 위/아래/대각선 조준 가능.
- **Jump/Fall 동안 aim_lock 입력 hold**: *무시* (T4 grounded 가드 위반; 전이 안 됨). 다음 grounded tick에 hold 지속 시 T4 자연 발화.
- **Dead 동안 모든 입력**: *무시*. 다음 `restore_from_snapshot()` (T14-T17)까지 입력 처리 안 함.
- **`rewind_consume` 입력**: *PM이 처리 안 함*. EchoLifecycleSM의 DyingState가 polling (state-machine.md C.2.2 O3). PM 무관.

#### C.2.5 Framework atomicity 인헤리트 (cross-tick deferred queue 미도입 결정)

PlayerMovementSM은 `extends StateMachine` 으로 framework의 transition queue + `_is_transitioning` atomicity를 *수정 없이* 상속한다 (state-machine.md C.2.1 line 196-206). 결과:

- 같은 tick 안 cascade 시나리오 — 예: PM `move_and_slide()` 도중 Area2D `area_entered` → Damage `lethal_hit_detected` 동기 emit → EchoLifecycleSM 동기 DYING 전이 → `state_changed` 동기 emit → PlayerMovementSM `_on_lifecycle_state_changed` 동기 호출 → `transition_to(DeadState)` — 가 *모두 같은 tick에 동기로 처리*된다.
- 동기 cascade 중 PlayerMovementSM 자체 transition이 진행 중이면 framework의 `_is_transitioning` 가드가 nested transition을 차단; pending queue에 enqueue되어 현재 transition 종료 후 자동 dispatch.
- **PM 레이어는 별도 cross-tick deferred queue를 도입하지 않는다** — framework atomicity로 Tier 1 충분. M2 reuse 검증 (state-machine.md AC-23) 케이스 일치.
- 검증: state-machine.md AC-23 (framework reuse) + 본 GDD 신규 H 섹션 AC (mid-tick lethal cascade 결정성).

### C.3 Per-Tick Frame Loop (`_physics_process`)

#### C.3.1 Phase ordering (PM priority=0, 16.6ms frame budget)

`PlayerMovement._physics_process(delta: float)`은 프레임마다 다음 7 Phase를 *동기 순차*로 실행한다. TRC가 priority=1로 PM 직후 실행되므로 Phase 6c 종료 시점에 7-필드 PlayerSnapshot은 *권위 있는* state여야 한다 (TRC가 같은 tick에서 `_capture_to_ring()` 호출).

| Phase | 작업 | 핵심 행동 |
|---|---|---|
| 1 | `_is_restoring` clear | `_is_restoring = false` (이전 tick의 restore 가드 종료). 이 줄이 메서드 *최상단*. |
| 2 | Input snapshot read | `move_axis: Vector2 = Input.get_vector("move_left","move_right","move_up","move_down")` / `jump_pressed = Input.is_action_just_pressed("jump")` / `jump_released = Input.is_action_just_released("jump")` / `aim_lock_held = Input.is_action_pressed("aim_lock")` 등 로컬 변수에 캐시. *상태 mutation 없음*. `shoot`은 PM에서 *읽지 않음* (Player Shooting #7 owned). |
| 3a | SM input-driven transitions | PlayerMovementSM이 input 기반 transition 평가: T3 (jump edge → Jump), T4 (aim_lock pressed + grounded → AimLock), T1/T2 (move_axis.x change → Run/Idle), T10/T11 (aim_lock released → Idle/Run), T7 (Jump 중 jump_released → Fall + cut). Phase 4 velocity 계산이 정확한 state로 dispatch되려면 *반드시 Phase 4 이전*. |
| 4 | Target velocity 계산 | 현재 PlayerMovementSM state 기반 dispatch: AimLock → `velocity = Vector2.ZERO`; Jump 진입 첫 frame → `velocity.y = -jump_velocity_initial`; Jump → `velocity.y += gravity_rising * delta`, `velocity.x = move_toward(velocity.x, target_vx, step_size_air)` (D.1 step 공식 — D.1으로 통일된 unbounded-fix); Fall → `velocity.y += gravity_falling * delta`, lateral 동상; Run/Idle → `velocity.x = move_toward(velocity.x, target_vx, step_size_ground_*)` frame-count ramp (delta 누적 *금지* — D.1). Dead → no-op. |
| 5 | `move_and_slide()` | CharacterBody2D 빌트인 호출 (`up_direction = Vector2.UP` default). 이 호출 직후 `is_on_floor()`가 정확한 값. ADR-0003의 "직접 transform"은 *RigidBody2D 솔버 우회* 의미이며 `move_and_slide()`가 그 자체 (deterministic integration). |
| 6a | `is_grounded` cache + coyote 갱신 | `is_grounded = is_on_floor()` (PM 자체가 단일 출처 — TRC priority=1는 `is_grounded` *읽기만*, `is_on_floor()` 직접 호출 *금지*). `if is_grounded: _last_grounded_frame = Engine.get_physics_frames()`. |
| 6b | SM physics-driven transitions | PlayerMovementSM이 physics 결과 기반 transition 평가: T6 (apex → Fall), T8/T9 (landing → Idle/Run), T12 (AimLock floor lost → Fall), T5 (Idle/Run → Fall on floor lost). Phase 4 velocity 결과를 평가. |
| 6c | facing_direction + animation cache | `facing_direction` 8-way composite 갱신 (C.2.4 규칙); `_anim.current_animation`/`_anim.current_animation_position`은 read-only property로 자동 노출 (별도 cache 변수 불요). |
| 7 | (TRC implicit at priority=1) | 본 PM `_physics_process` 종료 → Godot이 priority=1 노드(`TimeRewindController`)의 `_physics_process` 호출 → TRC `_capture_to_ring()`이 7개 필드 read. PM 측 obligation: 이 시점에 모든 필드가 *권위 있는* 값일 것. |

#### C.3.2 Forbidden patterns within `_physics_process`

| 금지 행위 | 이유 |
|---|---|
| `Time.get_ticks_msec()` / wall-clock 의존 | ADR-0003 결정성 클락 위반. 모든 timer는 `Engine.get_physics_frames()` 차감 |
| `delta` 누적 카운터 (`_coyote_remaining += delta`) | float drift + restore boundary 동기화 실패. 코드 리뷰에서 강제 거부 |
| `await get_tree().physics_frame` / coroutine 기반 transition | 결정성 위반. 모든 SM transition은 동기 처리 (C.2.5) |
| Phase 5 *이후* `velocity` mutation | `move_and_slide()` 결과가 TRC priority=1 read의 *공식 출처*. Phase 6+에서 velocity 변경 시 1-tick lag |
| Phase 4 *이전* `move_and_slide()` 호출 | input → state → velocity → physics integration 순서 깨짐 |
| Phase 1 *이전* `PlayerMovementSM.transition_to()` | `_is_restoring` 클리어 전 transition 발화 시 anim guard 미작동 → method-track callback stale write 가능성 |
| `is_on_floor()` Phase 5 *이전* 호출 | `move_and_slide()` 실행 전이라 stale 값. Phase 6a에서 단 1회만 호출 |

#### C.3.3 Coyote / jump buffer predicates (frame-counter 기반)

`Engine.get_physics_frames()` 차감으로 결정론적 측정. delta 누적 *금지*.

```gdscript
# Phase 6a 갱신:
if is_grounded:
    _last_grounded_frame = Engine.get_physics_frames()

# Phase 3a 평가 (jump 발화 가드):
var coyote_eligible: bool = (
    Engine.get_physics_frames() - _last_grounded_frame <= coyote_frames
    and not (current_movement_state is JumpState)
)
# jump 발화 조건: is_grounded OR coyote_eligible

# Phase 2 (input edge 감지) 시 jump_buffer 등록:
if jump_pressed:
    _jump_buffered_at_frame = Engine.get_physics_frames()

# Phase 3a 평가 (착지 직후 자동 발화):
var jump_buffered: bool = (
    Engine.get_physics_frames() - _jump_buffered_at_frame <= jump_buffer_frames
    and is_grounded
)
# Dead 진입 시 _jump_buffered_at_frame = INT_MIN — phantom jump 방지.
# restore_from_snapshot()도 동일 클리어 (C.4).
```

#### C.3.4 mid-`move_and_slide()` SM cascade (atomicity 인헤리트)

Phase 5 도중 ECHO HurtBox와 적 HitBox shape이 겹치면 `Area2D.area_entered`가 *동기 emit*되어 cascade 발생 가능 (damage.md C.1.2 + C.2.5):

```
move_and_slide() (Phase 5, PM priority=0)
  └─ HitBox.area_entered emit (동기)
     └─ HurtBox.hurtbox_hit emit (동기)
        └─ Damage._on_hurtbox_hit emit lethal_hit_detected (동기)
           └─ EchoLifecycleSM transition_to(DyingState) (동기)
              └─ EchoLifecycleSM.state_changed emit (DYING)
                 └─ PlayerMovementSM._on_lifecycle_state_changed
                    └─ PlayerMovementSM.transition_to(DeadState) (동기)
```

cascade는 Phase 5 내부에서 *완료*. Phase 6a 도착 시점에 PlayerMovementSM은 이미 DeadState. Phase 6b의 physics-driven transition 평가는 DeadState에서 무의미하므로 자동 no-op (DeadState.physics_update가 `return`). Phase 6c의 facing_direction 갱신도 DeadState에서 skip.

framework `_is_transitioning` atomicity는 PlayerMovementSM in-flight transition을 보장 — 예: Phase 3a에서 Run→Jump transition 중에 위 cascade가 발화하면 Dead transition이 pending queue로 enqueue되어 Run→Jump 종료 후 즉시 dispatch (C.2.5 결정).

### C.4 Restore Path (`restore_from_snapshot()` + `_is_restoring` Guard)

#### C.4.0 Metaphor bridge — restoration이 *world rewind이 아닌* 이유

B.2 ("9프레임 *되-실행*", "같은 탄막을 다시 본다") 어휘는 *world rewind*를 암시할 수 있다. 그러나 ADR-0001 Player-only checkpoint scope (time-rewind.md Rule 12)에 따라 적·탄환·hazard·환경은 DYING / REWINDING / i-frame 전 구간에서 *계속 시뮬레이트된다*. `restore_from_snapshot()`은 PlayerMovement 본체의 7개 필드 + AnimationPlayer만 mutate하며, 월드 시뮬레이션은 `frame = rewind_trigger` 이후 정상 진행 중이다.

**플레이어가 "같은 탄막을 다시 본다"의 메커니즘은 *세계 재실행*이 아니라 *결정론적 반복*이다** — ADR-0003의 결정성 보장 (`Engine.get_physics_frames()` clock + CharacterBody2D + `process_physics_priority` 사다리)이 같은 frame 시퀀스에서 적/탄환이 *동일한* 경로를 따르도록 만들기 때문이다. 9프레임 전의 ECHO 위치로 복귀 → 같은 프레임 시퀀스 안에서 적/탄환의 결정론적 경로가 *재진입한 ECHO와 새로운 충돌 시퀀스*를 생성. 이 *결정론적 반복 + 신체 재진입*의 결합이 Pillar 1 "처벌이 아닌 학습 도구"의 운동학적 표상이다.

따라서 본 시스템이 호스팅하는 restore 경로는 *오직* PM 자체의 7-필드 + AnimationPlayer.seek + PlayerMovementSM force-transition만 다룬다. 적/탄환/HUD/씬 전반에 대한 mutation은 *없다* — 다른 시스템에 대해 invariant respect 의무 (forbidden_pattern `direct_player_state_write_during_rewind`은 PM 7-필드에 대한 single-writer로 한정).

#### C.4.1 `restore_from_snapshot()` 시그니처 + 단일 출처 mutation 경로

```gdscript
class_name PlayerMovement extends CharacterBody2D

# Single guard flag — Phase 1 시점에 매 tick `false`로 클리어 (C.3.1).
# restore_from_snapshot 내부에서 `true` set, 다음 _physics_process Phase 1에서 자동 클리어.
var _is_restoring: bool = false

# PlayerSnapshot 적용 단일 경로. TRC priority=1이 호출. 외부 시스템 직접 호출 금지.
# forbidden_pattern `direct_player_state_write_during_rewind` 단일 우회 메서드.
func restore_from_snapshot(snap: PlayerSnapshot) -> void:
    # Step 1 — _is_restoring을 *first line*에 set. 이후의 모든 cascade write를 가드.
    #   anim method-track callback / WeaponSlot.weapon_equipped signal handler / 외부 emit.
    _is_restoring = true

    # Step 2 — Transform + physics 필드 직접 할당 (CharacterBody2D 상속).
    #   ADR-0003: Godot Physics 솔버를 거치지 않으므로 다음 tick의 *권위 있는* state.
    global_position = snap.global_position
    velocity = snap.velocity

    # Step 3 — 논리 state 필드 (PM 신규 멤버).
    facing_direction = snap.facing_direction
    _current_weapon_id = snap.current_weapon_id
    _is_grounded = snap.is_grounded

    # Step 4 — Coyote / jump_buffer 카운터 명시적 클리어 — phantom jump 방지 (C.3.3).
    _last_grounded_frame = INT_MIN if not snap.is_grounded else Engine.get_physics_frames()
    _jump_buffered_at_frame = INT_MIN

    # Step 5 — PlayerMovementSM forced re-enter (T14-T17 derivation).
    #   target은 idle/run/jump/fall 중 하나. dead/aim_lock은 절대 target 아님 (C.4.3).
    var target_state: State = _derive_movement_state(snap)
    _movement_sm.transition_to(target_state, {"is_restoring": true}, true)
    #                                          ^payload: enter()가 anim play를 skip하도록 신호
    #                                                                      ^force_re_enter=true

    # Step 6 — Animation: play() *먼저* (track switch), 그 다음 seek(time, true).
    #   AnimationPlayer.seek 두 번째 arg `true`는 *강제 즉시 평가* (time-rewind.md I4 단일 출처).
    #   `seek(time)` 단독 호출은 허용되지 않음 — 다음 frame까지 기준 frame이 갱신되지 않아 capture lag.
    _anim.play(snap.animation_name)
    _anim.seek(snap.animation_time, true)
```

#### C.4.2 `_is_restoring` 생애주기

| 시점 | 값 | 효과 |
|---|---|---|
| Phase 1 (매 tick `_physics_process` 최상단) | `false` 강제 set (이전 tick의 잔류 클리어) | 정상 입력 처리 재개 |
| `restore_from_snapshot()` Step 1 | `true` set | 모든 cascade write 가드 활성 |
| `restore_from_snapshot()` Step 6 (`seek(time, true)`) | `true` 유지 | seek가 method-track callback을 *동기 호출*; 가드가 stale write 차단 |
| `restore_from_snapshot()` 종료 | `true` 유지 | 같은 tick 후속 cascade도 가드 (예: WeaponSlot signal) |
| 다음 tick Phase 1 | `false` 자동 클리어 | 정상 동작 재개 |

> **단일-tick lifetime**: TRC priority=1이 PM priority=0의 `_physics_process` 종료 *후* 실행되므로 `restore_from_snapshot()`은 항상 PM의 *해당 tick 후반*에 호출된다 (TRC가 `try_consume_rewind()` 처리). 다음 tick PM `_physics_process` 시작 시점에 `_is_restoring` 자동 클리어 → 가드는 정확히 1 tick (= seek + 후속 same-tick cascade) 동안만 활성.

#### C.4.3 `_derive_movement_state(snap)` — T14-T17 derivation

```gdscript
const _ABS_VEL_X_EPS: float = 0.5  # px/s; 정지 판정 deadzone (G.1 tunable)

func _derive_movement_state(snap: PlayerSnapshot) -> State:
    if snap.is_grounded:
        if absf(snap.velocity.x) < _ABS_VEL_X_EPS:
            return _movement_sm.get_node(^"IdleState") as State    # T14
        else:
            return _movement_sm.get_node(^"RunState") as State     # T15
    else:
        if snap.velocity.y < 0.0:
            return _movement_sm.get_node(^"JumpState") as State    # T16
        else:
            return _movement_sm.get_node(^"FallState") as State    # T17
```

**의도적 omission**:
- `DeadState`는 절대 target *아님*. EchoLifecycleSM의 REWINDING→ALIVE 전이가 30 프레임 후 fire하지만 PlayerMovementSM은 이미 정상 movement state. `_on_lifecycle_state_changed` ALIVE handler는 `if current_state is not DeadState: return` (C.2.2 T13 노트).
- `AimLockState`는 절대 target *아님*. PlayerSnapshot은 aim_lock 입력 hold 상태를 캡처하지 않음 (B.4 비협상 #1: 입력 큐 reset 금지 + 입력은 외부 polling). 복원 *직후* tick Phase 2에서 aim_lock 입력 폴링; 여전히 hold 중이면 다음 tick T4가 자연 발화 (1-tick latency — DEC-PM-2 hold-button 시맨틱과 일관).

#### C.4.4 Anim method-track 핸들러 가드 패턴 (의무)

`AnimationPlayer.seek(time, true)`은 method-track 키프레임을 *동기 호출*한다. stale callback emit (예: 발사체 spawn) 위험 (time-rewind.md I9 + AC-D5). **모든 anim method-track 핸들러**는 다음 가드 패턴 의무:

```gdscript
# 발사체 spawn method-track 핸들러 (Player Shooting #7와 협력)
func _on_anim_spawn_bullet() -> void:
    if _is_restoring:
        return  # Stale spawn 차단 — 정상 재생이 다시 발화하기까지 대기
    _weapon_slot.spawn_projectile(facing_direction)
```

| 가드 적용 대상 | Owner | 비고 |
|---|---|---|
| `_on_anim_spawn_bullet` | Player Shooting #7 / WeaponSlot | 가장 흔한 케이스 — 가드 강제 |
| `_on_anim_play_footstep_sfx` | Audio (#21) | 가벼운 SFX는 가드 *생략 가능* — Audio GDD 결정 |
| `_on_anim_emit_dust_vfx` | VFX (#14) | 가드 권장 — restore 시 stale dust trail 차단 |
| `_on_anim_advance_phase_flag` | Boss Pattern (#11) — ECHO 무관 | ECHO 측 가드 무관 |

> **AC 의무 (H 섹션)**: ECHO 자체 anim method-track 핸들러 *전수* (`grep "method_track\|anim_method"` 정적 분석)에 대해 `_is_restoring` 가드 존재 여부를 GUT 테스트로 검증. *부분* 가드는 silent 회귀 위험.

#### C.4.5 외부 cascade 가드 (WeaponSlot signal 등)

`restore_from_snapshot()` Step 3 `_current_weapon_id = snap.current_weapon_id` 직접 할당은 setter나 signal handler를 통해 cascade emit할 수 있다. **`_current_weapon_id`는 *direct field assignment*만 — setter 정의 금지**. WeaponSlot의 `weapon_equipped` signal handler 또한 `_is_restoring` 가드 의무:

```gdscript
# PlayerMovement._on_weapon_equipped — WeaponSlot signal handler
func _on_weapon_equipped(weapon_id: int) -> void:
    if _is_restoring:
        return  # restore 도중 WeaponSlot 측 자동 emit 무시 — 7-field가 권위
    _current_weapon_id = weapon_id
    # 정상 swap UI/SFX cue 등...
```

### C.5 Input Contract (Locked — Input System #1 Designed 2026-05-11)

> **F.4.1 #1 closure (2026-05-11 — Input #1 re-review APPROVED)**: "(Provisional pending Input System #1)" header removed. Input #1 GDD now exists at [`design/gdd/input.md`](input.md). The 4 items previously deferred to Input #1 authorship are **verbatim locked** per Input #1 single source — see C.5.3 below for the resolution map.

#### C.5.1 Action map (Tier 1 floor — `project.godot` already mapped)

본 GDD가 *직접 read하는* input action 목록. Input System #1 GDD가 정식화 시 본 표가 단일 출처.

| Action | PM Read site | Detect mode | Buffer / Notes |
|---|---|---|---|
| `move_left` / `move_right` | Phase 2 (`_physics_process`) | **Analog axis** (`Input.get_vector` 또는 `get_axis`) | No buffer; 매 tick sample |
| `move_up` / `move_down` | Phase 2 | Analog axis | Run/Jump/Fall 동안 facing_direction 8-way 갱신용 (movement 영향 없음 — OQ-2 lock); aim_lock 동안 8방향 조준 (DEC-PM-2) |
| `jump` | Phase 2 + Phase 3a | **Edge-triggered** (`is_action_just_pressed`) + Edge-released (`is_action_just_released` for variable cut OQ-4) | `jump_buffer_frames` (default 6) pre-grounded window + `coyote_frames` (default 6) post-leave |
| `aim_lock` | Phase 2 + Phase 3a | **Hold-detect** (`is_action_pressed`) | No buffer. held=AimLock state, released=instant 복귀 (T10/T11). DEC-PM-2 hold semantics |
| `shoot` | **PM이 read 안 함** | — (Player Shooting #7 owned) | PM은 `shoot` 입력에 반응 X. movement freeze 안 함 (game-concept "점프 + 사격 동시" 보존) |
| `rewind_consume` | **PM이 read 안 함** | — (EchoLifecycleSM owned, state-machine.md C.2.2 O3) | PM은 `restore_from_snapshot()` 호출만 수신; `rewind_consume` 입력 무관 |
| `pause` | **PM이 read 안 함** | — | EchoLifecycleSM의 `should_swallow_pause()` polling (state-machine.md O2) |

#### C.5.2 Buffer window contract

| Window | Default | 단위 | 측정 source | 클리어 시점 |
|---|---|---|---|---|
| `jump_buffer_frames` | 6 frames (~100ms @60fps) | frames | `Engine.get_physics_frames()` 차감 | T3 발화 OR Dead 진입 OR `restore_from_snapshot()` |
| `coyote_frames` | 6 frames (~100ms @60fps) | frames | `Engine.get_physics_frames() - _last_grounded_frame` | T3 발화 OR Jump 진입 (직접) OR Dead 진입 OR `restore_from_snapshot()` |

**Celeste 정밀도 일치**: 두 값 모두 Maddy Thorson published 6 frames 기준 (G.1 tunable).

#### C.5.3 Resolved Lock (Input #1 F.4.1 closure 2026-05-11)

Input System #1 GDD `design/gdd/input.md` (re-review APPROVED 2026-05-11 lean mode) is the single source for the 4 items previously deferred to Input #1 authorship. Each item below is now **verbatim locked** with cross-ref:

| # | PM provisional item | Input #1 single source | Locked value |
|---|---|---|---|
| 1 | `aim_lock` action naming confirm (DEC-PM-2) | input.md C.1.1 row 6 + C.4 `InputActions.AIM_LOCK` | `aim_lock` (StringName const `&"aim_lock"`) |
| 2 | `move_left/right/up/down` 4-action split vs 2-axis decision | input.md C.1.1 rows 1–4 + C.4 (4 separate `MOVE_*` constants) | **4 separate actions** (`move_left`, `move_right`, `move_up`, `move_down`); composed via `Input.get_vector(...)` for radial composite. Locked. |
| 3 | Gamepad stick deadzone 0.2 (Tier 1 default) | input.md C.1.3 + D.3 + G.1.1; INVARIANT-IN-1/IN-2 cross-knob constraints | **0.2 radial composite** in `project.godot` `[input]` block for all 4 move actions. Tier 3 mutation only via `SettingsManager.apply_deadzone()` paused-tree apply. |
| 4 | KB+M default keys | input.md C.3.1 (KB+M Profile table) + A.1 Decision Log row "KB+M aim_lock = F" | `A/D/W/S` move, `Space` jump, **`F` aim_lock** (NOT `Shift` — Shift conflict resolved to `rewind_consume`; rationale: Hotline Miami Shift-aim muscle-memory separation per input.md C.3.1 row + B6 fix Session 14), `LMB` shoot, `Shift` rewind_consume, `Escape` pause |

**AimLock-jump exclusivity AC** (PM F.4.2 obligation): locked at input.md C.3.3 — InputMap fires `aim_lock` (hold) + `jump` (just_pressed) as independent events with zero chord-swallow logic. PM Phase 2 polling sees both action states simultaneously. Replaces PM AC-H4-04 (now obsolete — Input AC-IN-16 BLOCKING is the canonical contract).

**Deadzone enforcement** (PM E-PM-9 obligation): locked at input.md C.1.3 + AC-IN-06/07 — `project.godot` 0.2 radial composite is the single enforcement site; PM does NOT re-implement deadzone math (`forbidden_patterns.deadzone_in_consumer` per architecture.yaml). PM B10 `facing_threshold_outside` hysteresis is a **separate concern** (PM-side asymmetric thresholds enter=0.2 / exit=0.15 per PM B10 fix) and does not conflict with Input deadzone single source.

**No further mutation expected**: per Input #1 C.2 Tier 1 invariant + Round-7 cross-doc-contradiction exception protocol, any future change to the 4 locked values requires (a) Input #1 GDD revision, (b) PM C.5.3 sync update via cross-doc exception, (c) reciprocal architecture.yaml registry update.

### C.6 Interactions With Other Systems

본 표는 PlayerMovement가 다른 시스템과 데이터·시그널·메서드 호출을 어떻게 주고받는가의 단일 출처다. F.1-F.4가 양방향 정합성(referenced_by) 책임을 진다.

| 대상 시스템 | 방향 | Wiring 패턴 | 금지 alternatives |
|---|---|---|---|
| **TimeRewindController (#9)** | TRC가 매 tick PM 7-필드 read; REWINDING 시 `restore_from_snapshot(snap)` invoke | TRC 측 `@export var player: PlayerMovement` (declarative; missing-ref editor-visible) | `get_parent()` / autoload lookup / `find_node()` / scene-tree group lookup |
| **EchoLifecycleSM (#5)** | EchoLifecycleSM `state_changed` signal → PM `_on_lifecycle_state_changed`. DYING/DEAD 시 PlayerMovementSM force-transition to DeadState (T13). ALIVE 시 no-op | Signal-reactive: `_lifecycle_sm.state_changed.connect(_on_lifecycle_state_changed)` in PM `_ready()`. **call_deferred로 connect 권장** (state-machine.md C.3.4 — scene-tree-order race 회피) | PM polling `_lifecycle_sm.current_state` per tick (`cross_entity_sm_transition_call` forbidden_pattern 위반) |
| **Damage (#8)** | PM이 HurtBox + HitBox + Damage 노드 *호스팅만*. Damage 컴포넌트가 자체 wiring 소유. PM은 간접 — Damage emit `lethal_hit_detected`는 EchoLifecycleSM이 구독 (PM 직접 구독 금지) | Composition: `.tscn`에 자식 노드 인스턴스화. PM `_ready()`은 Damage 노드에 *touch 안 함* | PM이 `Damage.player_hit_lethal` / `lethal_hit_detected` 직접 구독 (C.2.3 forbidden); PM이 `HurtBox.monitorable` write (DEC-4 enforce site 위반) |
| **[Input System #1](input.md)** *(F.4.1 #2 closure 2026-05-11 — Input #1 Designed; provisional flag removed)* | PM이 `Input.is_action_*` polling per tick (`_physics_process` Phase 2 only). 폴링 패턴 + 콜백 금지의 단일 출처는 [`input.md` C.1.2 Rule 1+2](input.md) — PM은 그 규칙의 *consumer*이며 자체 정책 X | `Input.is_action_pressed` / `is_action_just_pressed` / `get_vector` 직접 호출 (input.md C.4 `InputActions.*` StringName const 사용 의무) | `_unhandled_input` / `_input` callback에 movement 로직 binding (latency + 시점 mismatch — input.md C.1.2 Rule 2 단일 출처 forbidden, `forbidden_patterns.gameplay_input_in_callback` CI gate per architecture.yaml + AC-IN-05); InputEvent emit 구독; `&"jump"` literal 산발 (input.md C.4 + AC-IN-04 BLOCKING) |
| **WeaponSlot (#7)** | PM이 WeaponSlot 자식 노드 호스팅. `weapon_equipped(weapon_id: int)` signal → PM `_on_weapon_equipped`이 `_current_weapon_id` cache. `restore_from_snapshot()`은 7-필드 권위 — WeaponSlot signal cascade는 `_is_restoring` 가드로 차단 (C.4.5) | Composition: 자식 노드. signal-reactive cache | `_is_restoring` 동안 `WeaponSlot.set_active(...)` 발화 (silent fallback도 7-필드 권위 침범) |
| **Scene Manager #2** *(provisional)* | PM은 `scene_will_change` 시그널을 *직접 구독하지 않음*. EchoLifecycleSM이 O6 의무로 ephemeral state 클리어 (state-machine.md C.2.2 O6). PM의 `_last_grounded_frame` / `_jump_buffered_at_frame` 클리어는 **OQ-PM-1로 deferred** (Scene Manager #2 GDD 작성 시 결정) | TBD | PM이 독립적으로 `scene_will_change` 구독 (duplicate handler, race with SM clear) |
| **AnimationPlayer (Godot 빌트인)** | PM이 자식 노드 호스팅 + per-tick read property + restore 시 `play()` + `seek(time, true)` 호출 | `_anim.current_animation` / `current_animation_position` proxy; `_anim.play(name)` / `_anim.seek(time, true)` | `_anim.seek(time)` 단독 호출 (second arg `true` 누락 — capture lag); `_anim.advance(delta)` (결정성 위반) |
| **Sprite2D (Godot 빌트인)** | PM이 자식 노드 호스팅. facing_direction 시각화 — `flip_h` 토글 vs 좌/우 anim 분기 결정은 **Visual/Audio 섹션**에서 art-director consult | TBD | — |
| **Enemy AI (#10) / Boss Pattern (#11)** | 적/보스가 PM `global_position` *read만* (chase target). PM은 적/보스의 어떤 시그널도 구독 안 함 | Read-only: `var target_pos := player.global_position` | 적/보스가 PM 메서드 호출 / signal emit / state mutation |

---

## D. Formulas

### D.1 Run Acceleration / Deceleration

**Formula** (frame-count based, `move_toward()` — *NOT* delta-accumulator):

```
target_vx = sign(move_axis.x) * run_top_speed       if abs(move_axis.x) > 0
target_vx = 0                                       if abs(move_axis.x) = 0

step_size_ground_accel = run_top_speed / run_accel_frames    # accelerating toward non-zero target
step_size_ground_decel = run_top_speed / run_decel_frames    # decel to 0 OR sign-reversal pass-through
step_size_air          = (active_step_ground) * air_control_coefficient

velocity.x = move_toward(velocity.x, target_vx, active_step)
```

`active_step` 선택:
- ground (Idle/Run): `target_vx ≠ 0 AND sign(target_vx) == sign(velocity.x)` → accel; else → decel
- air (Jump/Fall): 위 ground choice + `air_control_coefficient` 곱셈

Sign reversal은 `move_toward()`가 자연 처리 — `+200 → -200` 시 decel 8 frames + accel 6 frames = 14 frames.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `run_top_speed` | v_max | float | 160–240 px/s | 최대 수평 velocity (지상 + 공중 공통 cap) |
| `run_accel_frames` | f_accel | int | 4–10 frames | 정지 → v_max 도달 frame 수 (Tier 1 = 6) |
| `run_decel_frames` | f_decel | int | 5–12 frames | v_max → 정지 frame 수 (Tier 1 = 8) |
| `air_control_coefficient` | k_air | float | 0.5–0.85 (B.5 hard cap < 1.0) | 공중 step_size multiplier (Tier 1 = 0.65) |
| `move_axis.x` | a_x | float | -1.0 ~ 1.0 | analog input (Input layer deadzone 적용) |
| `velocity.x` | v_x | float | ≈ -200 ~ +200 px/s | 수평 velocity; `move_and_slide()` 입력 |

**Output Range:** `move_toward` cap에 의해 `velocity.x` ∈ `[-run_top_speed, +run_top_speed]` 항상 — 공중에서도 unbounded accumulation 없음.

**Worked Example (Tier 1 v_max=200, f_accel=6, f_decel=8, k_air=0.65):**

```
Ground accel step = 200/6 ≈ 33.3 px/s/frame
Ground decel step = 200/8 = 25.0 px/s/frame
Air accel step    = 33.3 × 0.65 ≈ 21.7 px/s/frame

Ground accel from 0 (run): frames 1-6 = 33, 67, 100, 133, 167, 200 → cap
Ground decel from 200 (release): frames 1-8 = 175, 150, 125, 100, 75, 50, 25, 0
Sign reversal +200 → -200: decel 8 frames + accel 6 frames = 14 frames total
Air accel 0 → 200 (jump+run): 200/21.7 ≈ 9.2 frames
```

### D.2 Jump Velocity / Gravity / Apex

> **Tier 1 height invariant lock (Decision A 2026-05-10)**: `jump_velocity_initial = 480 px/s`, `gravity_rising = 800 px/s²` → `jump_height_max_px = 480² / (2 × 800) = 144 px` 정확히. (gameplay-programmer 기존 144 px target 보존; gravity_rising 900→800으로 조정.)

**Formula 1 — Jump impulse (JumpState.enter() 시):**
```
velocity.y = -jump_velocity_initial    # = -480 px/s (upward)
```

**Formula 2 — Height invariant (검증식):**
```
jump_height_max_px = jump_velocity_initial² / (2 × gravity_rising)
                   = 480² / (2 × 800) = 144 px ✓
```

**Formula 3 — Rising gravity integration (Phase 4 per-tick):**
```
velocity.y += gravity_rising * delta    # delta = 1/60 s; per-tick *single-use* integration
```

**Formula 4 — Apex predicate (T6 trigger):**
```
velocity.y >= 0   → Jump → Fall
```

**Formula 5 — Variable jump cut (T7, OQ-4 Celeste cut):**
```
if jump_released AND velocity.y < 0:
    velocity.y = max(velocity.y, -jump_cut_velocity)    # jump_cut_velocity = 160 px/s (Tier 1)
    transition_to(FallState)
```

**Formula 6 — Falling gravity integration (Phase 4 per-tick):**
```
velocity.y += gravity_falling * delta    # gravity_falling = 1620 px/s²
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `jump_velocity_initial` | v_j | float | 420–560 px/s | 점프 진입 위쪽 velocity (양수 magnitude) |
| `gravity_rising` | g_up | float | 700–1100 px/s² | velocity.y < 0 (rising) 시 적용 (Tier 1 = 800) |
| `gravity_falling` | g_down | float | 980–2200 px/s² | velocity.y ≥ 0 (falling) 시 적용 (1.4–2.0× g_up) |
| `jump_cut_velocity` | v_cut | float | 100–200 px/s | jump 떨어진 시점 위쪽 velocity 상한 (Tier 1 = 160) |
| `delta` | dt | float | ≈ 0.01667 s | 60fps frame; per-tick *single-use* integration |
| `velocity.y` | v_y | float | ≈ -560 ~ +∞ | 수직 velocity; − = 위쪽 |

**Output Range:**
- 최대 apex (full hold): 144 px
- 최소 apex (frame 1 cut): `160² / (2 × 1620) ≈ 7.9 px`
- Falling: 위쪽 cap 없음 (level design / void에 의해 자연 종결)

**Worked Example (Tier 1 v_j=480, g_up=800, g_down=1620, v_cut=160, dt=0.01667):**

```
Full press path (점프 끝까지 hold):
  Jump entry: velocity.y = -480
  per-frame Δv = 800 × 0.01667 ≈ 13.33 px/s
  Frames to apex: 480 / 13.33 ≈ 36 frames (apex tick when velocity.y >= 0)
  Apex height: 480² / (2 × 800) = 144 px ✓

Frame-4 cut path (jump 4 frames 후 release):
  Frame 4 velocity.y: -480 + 4 × 13.33 = -426.7 px/s
  jump_released → velocity.y = max(-426.7, -160) = -160 px/s; Fall 전이
  Continued rise after cut (now g_falling=1620): 160² / 3240 ≈ 7.9 px
  Frames 1-4 rise (avg velocity ≈ -460 px/s × 4 frames × 0.01667) ≈ 30 px
  Total apex: ~38 px (절반 미만, 짧은 hop)

Frame-12 cut path (꽤 늦게 release):
  Frame 12 velocity.y: -480 + 12 × 13.33 = -320 px/s
  -320 < -(-160) → cut: velocity.y = -160 px/s
  Frames 1-12 rise: ≈ 80 px + 7.9 ≈ 88 px (≈ 60% of full)
```

### D.3 Coyote Time / Jump Buffer Predicates

**Formula 1 — Coyote eligibility (Phase 3a 평가):**
```
coyote_eligible = (
    Engine.get_physics_frames() - _last_grounded_frame <= coyote_frames
    AND not (current_movement_state is JumpState)
)
```

**Formula 2 — Jump buffer eligibility (Phase 3a 평가):**
```
jump_buffered = (
    Engine.get_physics_frames() - _jump_buffered_at_frame <= jump_buffer_frames
    AND is_grounded
)
```

**Formula 3 — Combined jump-fire predicate (T3 트리거):**
```
should_jump = (
    (jump_pressed AND (is_grounded OR coyote_eligible))
    OR jump_buffered
)
```

**Formula 4 — Buffer 등록 (Phase 2 jump_pressed 시):**
```
_jump_buffered_at_frame = Engine.get_physics_frames()    # only on edge fire
```

**Formula 5 — Sentinel reset (Dead 진입 + restore_from_snapshot):**
```
_jump_buffered_at_frame = INT_MIN    # GDScript: -9223372036854775808
_last_grounded_frame    = INT_MIN    # only if not snap.is_grounded
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `coyote_frames` | C | int | 4–8 frames | Floor 떠난 후 jump 여전히 가능한 윈도우 (Tier 1 = 6) |
| `jump_buffer_frames` | B | int | 4–8 frames | grounded 직전 buffered jump 자동 발화 윈도우 (Tier 1 = 6) |
| `_last_grounded_frame` | F_g | int | INT_MIN ~ current | 마지막 `is_on_floor() = true` 프레임; Phase 6a set |
| `_jump_buffered_at_frame` | F_b | int | INT_MIN ~ current | 가장 최근 jump press 프레임; INT_MIN = inactive |

**Output Range:** boolean. INT_MIN sentinel은 `(current - INT_MIN) > any threshold`이므로 reset 직후 항상 false 보장.

**Worked Example:**

```
Scenario A (coyote): platform 떠난 후 3 frames에 jump
  Frame N:    is_grounded=true → _last_grounded_frame = N
  Frame N+1:  is_grounded=false (edge 떠남)
  Frame N+3:  jump_pressed = true
              coyote_eligible: (N+3 - N) ≤ 6 → 3 ≤ 6 → TRUE; not in JumpState → TRUE
              should_jump: (TRUE AND (FALSE OR TRUE)) = TRUE → T3 발화

Scenario B (buffer): 착지 3 frames 전에 jump
  Frame N:    jump_pressed → _jump_buffered_at_frame = N; is_grounded=false
  Frames N+1, N+2:  is_grounded=false
  Frame N+3:  is_grounded=true (착지)
              jump_buffered: (N+3 - N) ≤ 6 AND is_grounded → 3 ≤ 6 AND TRUE → TRUE
              should_jump: (FALSE OR TRUE) = TRUE → T3 발화 on landing tick

Scenario C (sentinel): Dead 진입 후 buffer 클리어
  Frame N (Dead 진입): _jump_buffered_at_frame = INT_MIN
  Frame N+10 (restore_from_snapshot): _jump_buffered_at_frame remains INT_MIN
  Frame N+11 post-restore: jump_buffered = (N+11 - INT_MIN) > 6 → FALSE (no phantom jump)
```

### D.4 Facing Direction Update

> **Encoding lock (Decision B 2026-05-10)**: `facing_direction: int` 0..7 enum. CCW from East — 0=E, 1=NE, 2=N, 3=NW, 4=W, 5=SW, 6=S, 7=SE. PlayerSnapshot 7-필드 schema 호환 유지 (ADR-0002 변경 없음). PM 내부 helper `_encode_facing()` / `_decode_facing()`이 단일 출처.

**Formula 1 — Encoding helpers (PM private):**
```gdscript
# (x, y) ∈ {-1, 0, 1} × {-1, 0, 1}, (0,0) → -1 sentinel "preserve"
const _FACING_TABLE: Array[int] = [
    3, 4, 5,    # row x=-1: NW(=3), W(=4), SW(=5)
    2, -1, 6,   # row x=0:  N(=2),  PRESERVE(=-1), S(=6)
    1, 0, 7     # row x=1:  NE(=1), E(=0), SE(=7)
]

static func _encode_facing(v: Vector2i) -> int:
    var idx: int = (v.x + 1) * 3 + (v.y + 1)  # 0..8
    return _FACING_TABLE[idx]    # -1 sentinel for (0,0)

const _DIRS: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, -1),
    Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)
]

static func _decode_facing(f: int) -> Vector2i:
    return _DIRS[f]  # f ∈ 0..7 항상
```

**Formula 2 — Outside aim_lock (Run/Jump/Fall/Idle Phase 6c):**
```gdscript
const FACING_THRESHOLD_OUTSIDE: float = 0.2

if absf(move_axis.x) >= FACING_THRESHOLD_OUTSIDE \
   or absf(move_axis.y) >= FACING_THRESHOLD_OUTSIDE:
    var v: Vector2i = Vector2i(signi(move_axis.x), signi(move_axis.y))
    var encoded: int = _encode_facing(v)
    if encoded != -1:    # (0,0) sentinel → preserve
        facing_direction = encoded
# else: preserve previous
```

**Formula 3 — Inside AimLockState (Phase 6c override):**
```gdscript
const FACING_THRESHOLD_AIM_LOCK: float = 0.1    # Decision C — finer aim precision

if absf(move_axis.x) >= FACING_THRESHOLD_AIM_LOCK \
   or absf(move_axis.y) >= FACING_THRESHOLD_AIM_LOCK:
    var v: Vector2i = Vector2i(signi(move_axis.x), signi(move_axis.y))
    var encoded: int = _encode_facing(v)
    if encoded != -1:
        facing_direction = encoded
# else: preserve previous
```

**Formula 4 — null-input preservation rule:**
양 축 모두 threshold 미만 → `facing_direction` *변경 없음* (직전 값 유지). `(0,0)` "방향 미정"이 *공식 facing*으로 저장되지 않음. PlayerSnapshot에는 항상 0..7 enum 유효 값 보장.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `facing_direction` | f | int | 0..7 enum | 8-way 방향 (E~SE CCW); PlayerSnapshot capture 대상 |
| `move_axis` | a | Vector2 | -1.0 ~ 1.0 per axis | analog input (Phase 2 read) |
| `FACING_THRESHOLD_OUTSIDE` | t1 | float | 0.1–0.35 | outside aim_lock threshold (Tier 1 = 0.2) |
| `FACING_THRESHOLD_AIM_LOCK` | t2 | float | 0.05–0.2 | aim_lock threshold (Tier 1 = 0.1) |

**Output Range:** `facing_direction` ∈ {0..7}. `(0,0)` ≡ -1 sentinel은 *내부에서만*; 외부 노출 facing_direction은 항상 유효 enum.

**Worked Example:**

```
Initial:   facing_direction = 0 (E, _ready default)

Frame 1:   move_axis=(0.8, 0.0) → x ≥ 0.2; v=(1,0) → enc=0=E; facing=0 (변동 없음)
Frame 2:   move_axis=(0.8, -0.7) → 둘 다 ≥ 0.2; v=(1,-1) → enc=1=NE; facing=1 ✓ (대각선 상우)
Frame 3:   move_axis=(0.05, 0.0) → 둘 다 < 0.2; preserve; facing=1 ✓ (held aim)
Frame 4:   move_axis=(0.0, 0.0) → 둘 다 < 0.2; preserve; facing=1 ✓ (스틱 release)
Frame 5:   move_axis=(-0.9, 0.0) → x ≥ 0.2; v=(-1,0) → enc=4=W; facing=4 ✓ (좌측 flip)

AimLock 진입 (threshold 0.1 적용):
Frame 10:  AimLockState; move_axis=(0.0, -0.15)
           y ≥ 0.1 (0.15); v=(0,-1) → enc=2=N; facing=2 ✓
           (outside threshold 0.2였으면 미달 → preserve일 것)

null input 보존:
AimLock + move_axis=(0,0): preserve; PlayerSnapshot facing=직전값 (예 2=N).
*결코* "방향 미정"이 캡처되지 않음.
```

---

## E. Edge Cases

본 섹션은 PlayerMovement 단독 + 다른 시스템과의 interaction에서 발생할 수 있는 비정상 / 모서리 상황을 명시한다. 각 항목은 *조건 → 결과* 형식 ("handle gracefully" 금지). 5 카테고리: Snapshot 복원 / 입력 / 물리 / Animation / SM cascade.

### E.1 Snapshot 복원

- **E-PM-1**: `snap.is_grounded = true`이지만 `snap.global_position`이 floor 위 공중 좌표 (e.g., 캡처 시점 platform이 무너짐 + 씬 변경 missed). → `restore_from_snapshot()`은 `is_grounded` 값 그대로 신뢰; 다음 tick Phase 5 `move_and_slide()` + Phase 6a가 `is_grounded = is_on_floor()` 재계산하여 자연 정정. 1-tick lag 동안 IdleState/RunState 유지 (gravity 미적용). 다음 tick에서 floor 미감지 시 T5 자연 발화 → Fall.
- **E-PM-2**: `snap.velocity.y < 0` AND `snap.is_grounded = true` (이론상 모순 — 캡처 시점 ground-launching). → `_derive_movement_state()`는 `is_grounded` 우선 — Run/Idle. velocity.y 그대로 복원 (다음 tick Phase 5에서 jump처럼 동작 가능). 디자인 의도 *불명*; 정상 캡처 시나리오에서 발생 불가능 (jump entry 시 is_grounded false 즉시 처리).
- **E-PM-3**: `snap.animation_name`이 캡처 이후 *제거*된 anim (e.g., hot-reload 중 제거). → `_anim.play(snap.animation_name)`은 silent no-op (warning print). `seek()`도 invalid track에서 no-op. PM은 facing/velocity/position만 복원, anim은 default 유지. 의도: *graceful degradation*. AC 의무: `tests/integration/`에서 invalid anim_name fixture 검증.
- **E-PM-4**: `snap.animation_time` 음수 또는 anim 길이 초과. → `seek(time, true)`는 Godot이 `[0, length]` clamp. silent. 단 `time = NaN` 시 미정 — `_is_restoring` set 후 `assert(not is_nan(snap.animation_time))` dev-only 가드 의무 (G.4).
- **E-PM-5**: `snap.current_weapon_id`가 *invalid* (e.g., 무기 디자인 변경 후 id 폐기). → `_current_weapon_id = snap.current_weapon_id` 직접 할당; `_on_weapon_equipped` cascade는 `_is_restoring` 가드 차단 (C.4.5). 다음 tick `_on_weapon_equipped` 정상 호출되어 fallback to id=0 (time-rewind.md E-15 contract). PM은 invalid id를 캐시하고 다음 weapon_equipped signal 시 갱신.

### E.2 입력 edge cases

- **E-PM-6**: AimLock 진입 + jump 입력 *동일 tick*. → Phase 2 read에서 `aim_lock_held=true`, `jump_pressed=true` 동시. Phase 3a: T4 (AimLock) 먼저 평가 → state=AimLock; jump_pressed는 C.2.4 규칙으로 무시 (buffer 등록 X). 결과: AimLock 진입 + jump 폐기.
- **E-PM-7**: AimLock hold 중 frame N에 floor 손실 (T12) + frame N+1에 floor 재획득. → frame N: T12 → Fall. frame N+1: is_grounded=true → T8/T9 → Idle/Run; `aim_lock_held = true`이므로 frame N+2 Phase 3a T4 자연 재발화 → AimLock. **Net effect**: 2-tick AimLock 중단 후 자연 복귀.
- **E-PM-8**: Coyote 도중 jump_pressed → Run/Fall → Jump 전이됨. 같은 tick mid-`move_and_slide()` Damage cascade → Dead. → framework atomicity로 Run/Fall→Jump pending → Dead 순차 처리 (C.2.5). 정상 시퀀스: Run → Jump (current tick) → Dead (다음 tick mid-`move_and_slide` Damage cascade arrival).
- **E-PM-9**: Input deadzone 미적용 noise (`abs(move_axis.x) ≈ 0.05`)가 PM에 도달 시 GDScript `sign(0.05) = 1.0`이라 Run 전이 잘못 발화. → **Input System #1 GDD가 0.2 deadzone을 입력 layer에서 보장 의무**; 본 GDD는 deadzone-applied input만 받는 것을 가정. 검증은 Input System #1 AC 책임 (provisional flag).

### E.3 물리 edge cases

- **E-PM-10**: `move_and_slide()` 결과 ECHO가 *벽에 끼임* (corner clip). → `is_on_floor()` 결과 그대로, `velocity.x`는 벽 충돌로 0 clamp. state 머신 정상 진행. 시각적 이상은 Tier 2 wall-grip 디자인 검토 (deferred per DEC-PM-1).
- **E-PM-11**: 1000-cycle determinism: 동일 starting state + 동일 input sequence → 1000회 실행마다 동일한 7-필드 결과. ADR-0003 R-RT3-01 검증. PM은 결정성 보장의 일부 — `Engine.get_physics_frames()` 차감 + `move_toward()` 결정성 + `move_and_slide()` 결정성 (Godot 4.6 CharacterBody2D + Forward+ 검증). AC-F1 (time-rewind.md) 인 PlayerSnapshot bit-identical 검증이 본 시스템 확인 책임도 포함.
- **E-PM-12**: 60fps drop으로 한 tick에서 delta가 0.05s (3 frames worth)로 누적. → ADR-0003 Validation #4 — Godot은 `_physics_process`를 *3회 분할 호출*; delta는 항상 1/60 ≈ 0.01667s. PM은 delta 변동에 노출되지 않음. `Engine.get_physics_frames()`도 그만큼 증가 — 결정성 유지.

### E.4 Animation edge cases

- **E-PM-13**: `seek(time, true)` 직후 method-track callback이 *자기 state transition* 트리거 (e.g., anim_method가 `_movement_sm.transition_to(JumpState)` 호출). → framework atomicity (C.2.5) nested transition 차단; pending queue. `_is_restoring` 가드가 *callback 자체*를 차단 (C.4.4) primary defense. 2-layer 방어로 stale callback이 PM state mutation 못함.
- **E-PM-14**: Looping animation에 `seek(snap.animation_time)` — 캡처 시 anim_time = 0.5 (1.0s 길이의 looping anim). → seek는 [0, length] clamp; loop 위치 0.5 정확히 재현. 다음 frame부터 loop 자연 진행. **Tier 1 검증 필요 (HIGH risk Godot 4.6)**: OQ-PM-2 — Tier 1 prototype에서 looping anim seek 동작 확인 (time-rewind.md OQ-9 동일 dependence).

### E.5 SM cascade edge cases

- **E-PM-15**: REWINDING 상태에서 ECHO HurtBox.monitorable=false → 적 발사체 충돌 안 함. PM 측 시각 표현은 정상 (anim play, position update). PM은 i-frame *직접 인지하지 않음* — DEC-4 단방향. Tier 1 visual cue (i-frame flicker 또는 outline)는 Visual/Audio 섹션 art-director 결정.
- **E-PM-16**: Dead 진입 직후 *동일 tick*에 `restore_from_snapshot()` 호출 (TRC가 DyingState input buffer 만족 시 즉시 처리). → 같은 tick cascade: ALIVE → DYING (Damage) → 12-frame grace 시작 → input buffer 만족 → REWINDING 진입 → restore. PM은 cascade *마지막 단계*에서 `restore_from_snapshot()` 받음. 순차: PM Run/Jump → Dead → Re-derive (T14-T17). framework atomicity 보장.
- **E-PM-17**: `restore_from_snapshot()` 직후 *다음 tick* Damage cascade로 즉시 Dead 재진입. → `_is_restoring`은 다음 tick Phase 1에서 `false` 클리어; Phase 5 `move_and_slide()` cascade 정상 발화. 결과: 1-tick ALIVE → Dead. **i-frame은 PM 책임이 아니라 EchoLifecycleSM RewindingState.enter()의 `HurtBox.monitorable=false` 책임** (DEC-4) — 정상 흐름에서는 REWINDING 30 frames i-frame 활성이며 본 시나리오 *불가능*; 단 dev/test fixture에서 EchoLifecycleSM bypass 시 발생 가능 (PM은 silently 처리).

---

## F. Dependencies

### F.1 Upstream Dependencies (Player Movement consumes)

| # | 시스템 | 데이터 흐름 | 인터페이스 | Hard/Soft |
|---|---|---|---|---|
| **#1** | Input System *(provisional)* | PM이 InputMap actions polling | `Input.is_action_pressed/just_pressed/just_released` + `Input.get_vector("move_left","move_right","move_up","move_down")`. Action 명: `move_left/move_right/move_up/move_down/jump/aim_lock` 직접 read. `shoot/rewind_consume/pause`는 read X | **Hard** |
| **#2** | Scene / Stage Manager *(provisional)* | `scene_will_change` 시 PM ephemeral state 클리어 — *EchoLifecycleSM 경유* | EchoLifecycleSM이 `scene_will_change` 구독 (state-machine.md C.2.2 O6); PM 직접 구독 X. PM `_last_grounded_frame` / `_jump_buffered_at_frame` 클리어 책임 OQ-PM-1로 deferred | **Soft** *(provisional)* |
| **#5** | State Machine Framework | PlayerMovementSM이 `extends StateMachine` 으로 framework 활용 | `class_name PlayerMovementSM extends StateMachine` (M2 reuse). framework transition queue + atomicity 인헤리트 (C.2.5). framework 코드 변경 금지 (state-machine.md C.2.1 line 206) | **Hard** |
| **#5** | EchoLifecycleSM (instance) | `state_changed` signal → PM `_on_lifecycle_state_changed`. DYING/DEAD 시 PlayerMovementSM force `Dead` (T13). ALIVE 시 no-op | `signal state_changed(from: StringName, to: StringName, frame: int)` (state-machine.md C.1.5). PM은 `to` 값만 read | **Hard** |
| **#7** | Player Shooting / Weapon *(provisional)* | PM이 WeaponSlot 자식 노드 호스팅 + `weapon_equipped(weapon_id: int)` signal 구독 → `_current_weapon_id` cache | `signal weapon_equipped(weapon_id: int)` (Player Shooting GDD 정의 예정). PM은 read만 | **Soft** *(cache; provisional)* |
| **#8** | Damage / Hit Detection | PM이 HurtBox + HitBox + Damage 노드 *호스팅만*. Damage signals 직접 구독 X — EchoLifecycleSM 경유 | Composition only. PM `_ready()`은 Damage 노드에 *touch 안 함* | **Indirect Hard** *(호스팅)* |
| **#9** | Time Rewind | TRC가 매 tick PM 7-필드 read; `restore_from_snapshot(snap)` invoke | TRC `@export var player: PlayerMovement`. PM은 `func restore_from_snapshot(snap: PlayerSnapshot) -> void` 노출. forbidden_pattern `direct_player_state_write_during_rewind` 단일 enforce site | **Hard** |
| **engine** | Godot 4.6 CharacterBody2D / AnimationPlayer | `move_and_slide()`, `is_on_floor()`, `AnimationPlayer.play()/seek(time, true)` | Godot 빌트인 API. `seek` 두 번째 arg `true` 필수 (time-rewind.md I4) | **Hard** |

### F.2 Downstream Dependents (consume Player Movement state/signals)

| # | 시스템 | 데이터 흐름 | 인터페이스 | Hard/Soft |
|---|---|---|---|---|
| **#9** | Time Rewind | F.1 #9 reciprocal | F.1 #9 참조 | **Hard** |
| **#5** | State Machine Framework | PlayerMovementSM이 framework M2 reuse 검증 케이스 | state-machine.md AC-23 검증 대상 | **Hard** |
| **#10** | Enemy AI | 적이 PM `global_position` *read만* (chase target) | `var target_pos := player.global_position` | **Soft** *(read-only)* |
| **#11** | Boss Pattern | 보스가 PM `global_position` + `velocity` read (예측 사격) | Read-only | **Soft** |
| **#13** | HUD | (Tier 1 없음) — HUD는 토큰 카운트 / 보스 phase만; PM state 직접 노출 X | — | — |
| **#14** | VFX | dust trail / landing puff 등 PM 자식 method-track 트리거 (`_on_anim_emit_dust_vfx`) | anim method-track emit | **Soft** |
| **engine** | rendering | `facing_direction` → `Sprite2D.flip_h` or anim 분기 | TBD (Visual/Audio 섹션 결정) | — |

### F.3 Signal Catalog (owned by Player Movement)

PlayerMovement는 자체 signal을 *Tier 1에서 owns 하지 않는다*.

| Signal | 시그니처 | Emit 시점 | 구독자 |
|---|---|---|---|
| (없음 — Tier 1) | — | — | — |

> **Tier 1 결정 근거**: PM state는 *direct field read* + *PlayerMovementSM `state_changed` (framework 인헤리트)* + *EchoLifecycleSM `state_changed`*만으로 외부 system이 충분히 알 수 있다. 자체 signal은 Tier 2에서 cinematic / animation 트리거 요구 시 재평가 (e.g., `landed(impact_force: float)` for landing dust VFX). 솔로 budget + Pillar 5 "작은 성공".

### F.4 Bidirectional Update Obligations

#### F.4.1 즉시 의무 (본 GDD F 섹션 직후 적용 — 6 cross-doc edits)

| # | 대상 파일 | Edit 종류 | 사유 |
|---|---|---|---|
| 1 | `time-rewind.md` F.1 row #6 | `*(provisional)*` 마커 제거 + 7-필드 인터페이스 verbatim 락인 (C.1.3 표 그대로) + `class_name PlayerMovement extends CharacterBody2D` 명시 + `restore_from_snapshot(snap: PlayerSnapshot) -> void` 시그니처 + `_is_restoring` 가드 cross-link | Player Movement #6 Designed로 승격 |
| 2 | `state-machine.md` F.2 row #6 | "PlayerMovementSM is independent of EchoLifecycleSM (Tier 1 flat composition)" 명시 + `extends StateMachine` (M2 reuse) 명시 + `Dead` state는 reactive (NOT parallel ownership) | C.1.2 + C.2.5 단일 출처 cross-link |
| 3 | `state-machine.md` C.2.1 line 178-188 노드 트리 정정 (**Round 5 cross-doc-contradiction exception** per Decision A 2026-05-10) | `ECHO (CharacterBody2D)` + `PlayerMovement (Node)` 분리 표기를 `PlayerMovement (CharacterBody2D, root)` 단일 + 자식 (`EchoLifecycleSM`, `PlayerMovementSM`, `HurtBox`, `HitBox`, `Damage`, `WeaponSlot`, `AnimationPlayer`, `Sprite2D`)로 통합 정정 | A.Overview 락인된 `PlayerMovement extends CharacterBody2D` 모델 권위 |
| 4 | `damage.md` F.1 row | ECHO HurtBox + HitBox + Damage 노드는 PlayerMovement(CharacterBody2D) *자식 노드*로 호스팅 명시 (HurtBox lifecycle = SM, 노드 ownership = PM) | C.1.4 책임 분리표 cross-link |
| 5 | `design/gdd/systems-index.md` System #6 row | Status `Designed` + Design Doc 링크 + Depends On expansion + Progress Tracker 갱신 + Last Updated | 본 GDD 완료 |
| 6 | `docs/registry/architecture.yaml` | 4 신규: (1) `state_ownership.player_movement_state` (2) `interfaces.player_movement_snapshot` (3) `forbidden_patterns.delta_accumulator_in_movement` (4) `api_decisions.facing_direction_encoding` (int 0..7 enum) | 본 GDD architecture stance 4건 |

#### F.4.2 후속 GDD 작성 시 의무

| 후속 GDD | 의무 |
|---|---|
| **Input System #1** | (a) `aim_lock` action 명명 confirm; (b) `move_left/right/up/down` 분리 vs axis 결정; (c) deadzone 0.2 (E-PM-9 차단); (d) KB+M 기본 키 (C.5.3) |
| **Player Shooting #7** | (a) `weapon_equipped(weapon_id: int)` signal 정의; (b) `_on_anim_spawn_bullet` `_is_restoring` 가드 의무 (C.4.4); (c) reload + ammo restoration이 DEC-PM-3 재평가 trigger인지 |
| **Scene Manager #2** | `scene_will_change` emit 시점 + PM `_last_grounded_frame` / `_jump_buffered_at_frame` 클리어 책임 (OQ-PM-1 해소) |
| **VFX #14** | landing puff / dust trail method-track callback `_is_restoring` 가드 정책 (C.4.4 referenced_by) |
| **Audio #21** | footstep SFX method-track `_is_restoring` 가드 생략 정책 (lightweight artifact) |
| **Visual/Audio (본 GDD)** | `facing_direction` 시각화 (`flip_h` vs 좌/우 anim 분기) art-director 결정 (C.6 + C.1.4) |
| **HUD #13** | PM signal 노출 정책 재평가 (Tier 2; F.3 Tier 1 결정 = None) |

#### F.4.3 후속 ADR 의무

| ADR | 의무 |
|---|---|
| **ADR-0003** | PM `process_physics_priority = 0` 이미 등록; 본 GDD 변경 없음 |
| **ADR-0002** | PlayerSnapshot 7-필드 schema 변경 *없음* (Decision B 인코딩 호환). Amendment 불필요 |
| **신규 ADR 후보** *(lean mode 생략 가능)* | "Variable jump cut policy" — DEC-PM-1/2/3은 GDD 자체 lock |

---

## G. Tuning Knobs

### G.1 Owned Knobs (PlayerMovement Resource)

> **Storage policy** (Decision G-A 2026-05-10): All 13 owned numeric knobs live in `class_name PlayerMovementTuning extends Resource` (.tres asset at `assets/data/tuning/player_movement_tuning.tres`). PlayerMovement holds `@export var tuning: PlayerMovementTuning`. **Structural constants** (`INT_MIN` sentinels, the 9-entry `_FACING_TABLE`, `_DIRS` array) remain as `const` in `player_movement.gd` — they are *encoding logic*, not balance. Resource hot-reload supported in editor; **runtime mutation of any owned knob during gameplay is forbidden** (G.4.1 invariant). Heading retains "PlayerMovement Resource" wording per skeleton; the canonical Resource class name is `PlayerMovementTuning`.

13 fields total. All `@export`-typed for editor visibility. Source formula column links to D-section verbatim.

| # | Knob | Type | Tier 1 default | Safe range | Source formula | Gameplay aspect |
|---|------|------|---------------|------------|----------------|-----------------|
| 1 | `run_top_speed` | float (px/s) | **200.0** | 160–240 | D.1 | Run velocity cap (지상 + 공중 공통). Below 160 = sluggish; above 240 = level layout 재튜닝 필요 |
| 2 | `run_accel_frames` | int (frames) | **6** | 4–10 | D.1 step_size_ground_accel | 정지 → v_max 도달 시간. Below 4 = ice-feel; above 10 = sluggish |
| 3 | `run_decel_frames` | int (frames) | **8** | 5–12 | D.1 step_size_ground_decel | v_max → 정지 시간. Below 5 = snap stop (anti-feel); above 12 = sliding |
| 4 | `air_control_coefficient` | float | **0.65** | 0.5–0.85 | D.1 step_size_air | 공중 step_size multiplier. **Hard cap < 1.0** (B.5 anti-fantasy). Below 0.5 = floaty no-control; ≥1.0 = 결정론 패턴 학습 가치 희석 |
| 5 | `jump_velocity_initial` | float (px/s) | **480.0** | 420–560 | D.2 Formula 1 | Jump 진입 위쪽 magnitude. 144 px max apex 보존하려면 g_rising 동기 조정 필요 (D.2 Decision A invariant) |
| 6 | `gravity_rising` | float (px/s²) | **800.0** | 700–1100 | D.2 Formula 3 | 상승 중 적용. **Invariant: ≤ gravity_falling** (G.4.1 INV-1). `2 × gravity_rising / jump_velocity_initial² = 1/apex_height` |
| 7 | `gravity_falling` | float (px/s²) | **1620.0** | 980–2200 | D.2 Formula 6 | 하강 중 적용. 1.4–2.0× gravity_rising 권장 (Celeste-style snappy fall) |
| 8 | `jump_cut_velocity` | float (px/s) | **160.0** | 100–200 | D.2 Formula 5 | 점프 중 release 시 위쪽 velocity cap. 100 = aggressive cut; 200 = subtle cut |
| 9 | `coyote_frames` | int (frames) | **6** | 4–8 | D.3 Formula 1 | Floor 떠난 후 jump 가능 윈도우 (~100ms @60fps). Maddy Thorson Celeste 표준 |
| 10 | `jump_buffer_frames` | int (frames) | **6** | 4–8 | D.3 Formula 2 | Grounded 직전 buffered jump 윈도우. coyote와 동일 default; 비대칭 튜닝 시 버그 보고 다발 |
| 11 | `facing_threshold_outside` | float | **0.2** | 0.1–0.35 | D.4 Formula 2 | Outside aim_lock에서 facing 갱신 deadzone. Input #1 deadzone (0.2)와 일치 권장 |
| 12 | `facing_threshold_aim_lock` | float | **0.1** | 0.05–0.2 | D.4 Formula 3 | AimLock 내부 facing precision (조준 정밀도). 항상 ≤ facing_threshold_outside |
| 13 | `abs_vel_x_eps` | float (px/s) | **0.5** | 0.1–2.0 | C.4.3 `_ABS_VEL_X_EPS` | T14↔T15 derive boundary. Below 0.1 = float drift thrashing; above 2.0 = 가짜 Idle restore |

**Tuning Resource skeleton:**

```gdscript
class_name PlayerMovementTuning
extends Resource

# D.1 — Run accel/decel
@export_range(160.0, 240.0) var run_top_speed: float = 200.0
@export_range(4, 10)        var run_accel_frames: int = 6
@export_range(5, 12)        var run_decel_frames: int = 8
@export_range(0.5, 0.85)    var air_control_coefficient: float = 0.65
# D.2 — Jump / gravity / cut
@export_range(420.0, 560.0)  var jump_velocity_initial: float = 480.0
@export_range(700.0, 1100.0) var gravity_rising: float = 800.0
@export_range(980.0, 2200.0) var gravity_falling: float = 1620.0
@export_range(100.0, 200.0)  var jump_cut_velocity: float = 160.0
# D.3 — Coyote / buffer
@export_range(4, 8) var coyote_frames: int = 6
@export_range(4, 8) var jump_buffer_frames: int = 6
# D.4 — Facing thresholds
@export_range(0.1, 0.35) var facing_threshold_outside: float = 0.2
@export_range(0.05, 0.2) var facing_threshold_aim_lock: float = 0.1
# C.4.3 — Movement-state derive epsilon
@export_range(0.1, 2.0) var abs_vel_x_eps: float = 0.5

# Validation called by PlayerMovement._ready() — see G.4.1 INV-1..7.
func _validate() -> void:
    assert(gravity_falling >= gravity_rising,
        "INV-1: gravity_falling must be >= gravity_rising")
    assert(air_control_coefficient < 1.0,
        "INV-2: air_control_coefficient must be < 1.0 (B.5 anti-fantasy)")
    assert(abs_vel_x_eps > 0.0,
        "INV-3: abs_vel_x_eps must be > 0 to prevent T14↔T15 thrashing")
    assert(facing_threshold_aim_lock <= facing_threshold_outside,
        "INV-4: aim_lock threshold must be <= outside threshold")
    var apex_h: float = (jump_velocity_initial * jump_velocity_initial) \
        / (2.0 * gravity_rising)
    assert(apex_h >= 50.0 and apex_h <= 250.0,
        "INV-5: apex height %f px out of [50, 250] range" % apex_h)
    assert(coyote_frames + jump_buffer_frames <= 16,
        "INV-6: coyote + jump_buffer must be <= 16 frames")
```

### G.2 Imported Knobs (referenced from other GDDs)

PM consumes these values via cross-system contracts; **owning GDD is single source**. PM may not redefine, mutate, or duplicate; PM AC must verify behaviour by *observation*, not by hardcoded comparison to the imported numeric value.

| Knob | Owner GDD | Owner value | PM use site | Mutation policy |
|------|-----------|-------------|-------------|-----------------|
| `hazard_grace_frames` (+1 compensation) | `damage.md` DEC-6 / G.1 | 12 (effective 13 due to RewindingState.exit() priority sequencing — `damage.md` B-R4-1 fix) | E-PM-13 (anim method-track stale callback timing); E-PM-16 (mid-tick lethal cascade timing); referenced as upper bound for any Visual/Audio fade decisions | Mutate in `damage.md` only; PM AC must verify via observation, never hardcode |
| `i_frame_frames` | `time-rewind.md` Rule 11 | 30 (REWINDING phase length, ≈0.5 s @60fps) | Visual/Audio i-frame flicker timing reference; E-PM-15 (PM does NOT directly inspect, but Visual cue duration = this value) | Mutate in `time-rewind.md` only |
| `gamepad_deadzone` | `Input System #1` *(provisional)* | 0.2 (Tier 1 default; C.5.3) | E-PM-9 (`sign(0.05)` Run mistrigger 차단). PM consumes *deadzone-applied* `move_axis`; PM's `facing_threshold_outside=0.2` aligns so that input below the threshold contributes neither to movement nor to facing | Input #1 owns; PM regression test asserts upstream deadzone applied before PM's Phase 2 read |

> **Not imported**: `REWIND_WINDOW_SECONDS` (1.0 s) and `max_tokens` (5) from `time-rewind.md` are *not referenced* by PM — TRC owns ring buffer slot count and token economy entirely. PM only receives `restore_from_snapshot(snap)` calls and is agnostic to the buffer's age semantics. DEC-PM-3 also explicitly excludes ammo from PlayerSnapshot, isolating PM from token + ammo state.

### G.3 Future Knobs (Tier 2+)

DEC-PM-1 locks Tier 1 to 6 states (`idle / run / jump / fall / aim_lock / dead`). The following knobs are **deferred**, *not designed*; each requires a documented DEC-PM-1 reconsideration trigger before authoring. Listed for traceability only — do not pre-allocate fields in `PlayerMovementTuning` until the trigger fires.

| Future Knob | Tier 2 state introduced | Reconsideration trigger | Current status |
|-------------|------------------------|-------------------------|----------------|
| `dash_velocity` (px/s), `dash_frames` (int), `dash_cooldown_frames` (int) | DashState (DEC-PM-1 deferred) | Pillar 5 "작은 성공" 통과 후 Tier 2 게이트 — design-driven (no external trigger) | Deferred |
| `double_jump_velocity` (px/s), `max_air_jumps` (int) | DoubleJumpState (DEC-PM-1 deferred) | Tier 2 게이트 — design-driven | Deferred |
| `wall_grip_friction` (float), `wall_jump_velocity` (Vector2) | WallGripState (DEC-PM-1 deferred) | Tier 2 게이트 — design-driven; level-designer 협의 의무 (벽 surfaces 디자인) | Deferred |
| `hit_stun_frames` (int) | HitStunState (DEC-PM-1 deferred) | **External trigger only** — `damage.md` DEC-3 (binary 1-hit lethal)이 *non-lethal damage source*로 변경되거나 boss knockback 메커니즘 신규 도입 시. damage.md GDD 갱신이 선행 의무 | Deferred (damage.md DEC-3 lock 유지 시 영구 deferred) |
| `knockback_velocity` (float), `knockback_decel_frames` (int) | (no new state; modifies existing Run/Fall accelerations) | Boss Pattern #11 GDD가 knockback 도입 시 | Deferred |

> **Tier 2 게이트 의무**: 위 knob 도입 시 (1) DEC-PM-1 amendment 발행 (Locked Scope Decisions 갱신), (2) PlayerMovementSM transition matrix 확장 (C.2.2), (3) `restore_from_snapshot()` `_derive_movement_state()` 분기 추가 (C.4.3), (4) `PlayerMovementTuning` Resource 필드 추가 + `_validate()` invariant 갱신, (5) AC 신규 (H 섹션). 단일 GDD 작업 단위 = 1 Tier 2 state 추가.

### G.4 Safety / Forbidden Mutations (3-layer enforcement)

본 섹션은 G.1 owned knobs와 PM 7-필드(C.1.3)에 대한 mutation 정책을 정의한다. 3-layer defense (Decision G-C 2026-05-10) — `damage.md` AC-21 / AC-29 precedent를 PM에 확장.

#### G.4.1 Dev-only `assert()` invariants (runtime, debug builds)

`PlayerMovementTuning._validate()`이 `PlayerMovement._ready()`에서 호출 (G.1 skeleton 참조). Release 빌드에서는 Godot `assert()`가 컴파일 아웃됨.

| # | Invariant | Assertion (요약) | Reason |
|---|-----------|------------------|--------|
| INV-1 | `gravity_falling >= gravity_rising` | `assert(tuning.gravity_falling >= tuning.gravity_rising)` | Inverted gravity = anti-feel; Celeste-style snappy fall 위반 |
| INV-2 | `air_control_coefficient < 1.0` | `assert(tuning.air_control_coefficient < 1.0)` | B.5 anti-fantasy (공중 360° 제어 = 결정론 패턴 학습 가치 희석) |
| INV-3 | `abs_vel_x_eps > 0.0` | `assert(tuning.abs_vel_x_eps > 0.0)` | 0 시 T14↔T15 boundary thrashing (float noise) |
| INV-4 | `facing_threshold_aim_lock <= facing_threshold_outside` | `assert(...)` | aim_lock = 정밀 조준; outside보다 둔감하면 의미 모순 |
| INV-5 | apex height invariant: `(jump_velocity_initial² / (2 × gravity_rising))` ∈ [50.0, 250.0] px | `assert(50.0 <= h <= 250.0)` where `h = v_j²/(2*g_up)` | level-designer 협의 시 144 px target (D.2 Decision A) 보호 — 50 px 이하는 not-jumpy, 250 px 이상은 platform spacing 재튜닝 의무 |
| INV-6 | `coyote_frames + jump_buffer_frames <= 16` | `assert(tuning.coyote_frames + tuning.jump_buffer_frames <= 16)` | 합 > 16 = 입력 feel 과도 관용 (~270 ms total slack); QA 회귀 다발 |
| INV-7 | restore 도중 owned knob 변경 금지 | runtime: PlayerMovement는 `_is_restoring=true` 동안 `tuning.set_*` 호출 시 `assert(not _is_restoring)` (Tier 1에서는 setter 정의 없음 — `@export` 직접 할당으로 충분; 향후 setter 도입 시 의무) | Resource hot-swap이 restore 중간에 발생하면 mid-tick 결정성 breach |

PlayerMovement._ready() 호출 패턴 (G.1 skeleton에 명시; 본 표는 INV catalog만 정의):

```gdscript
func _ready() -> void:
    assert(tuning != null, "PlayerMovementTuning resource not assigned")
    tuning._validate()    # all INV-1..INV-6 checks
    # INV-7는 setter 도입 시점에 추가
```

#### G.4.2 Static grep regressions (CI gate)

`tools/ci/forbidden-patterns.gd` (또는 동등한 grep step in CI) — `damage.md` AC-21 / AC-29 precedent의 PM 확장.

| # | Pattern | Reason | architecture.yaml 등록 여부 |
|---|---------|--------|----------------------------|
| GREP-PM-1 | `\.global_position\s*=\|\.velocity\s*=\|\.facing_direction\s*=\|\._current_weapon_id\s*=\|\._is_grounded\s*=` outside `player_movement.gd` | forbidden_pattern `direct_player_state_write_during_rewind` 단일 enforce site (C.1.3) | ✅ 등록됨 (Session 9 architecture.yaml 갱신) |
| GREP-PM-2 | `[a-zA-Z_]+\s*\+=\s*delta` in `player_movement.gd` (excluding the two `velocity.x/y` per-tick gravity integrations in Phase 4) | forbidden_pattern `delta_accumulator_in_movement` (float drift + restore boundary) | ✅ 등록됨 (Session 9) |
| GREP-PM-3 | `Time\.get_ticks_msec\|OS\.get_ticks_msec\|Time\.get_unix_time` in `player_movement.gd` | ADR-0003 결정성 클락 — 모든 timing은 `Engine.get_physics_frames()` 차감 | (architecture.yaml ADR-0003 cross-link 시 추가 후보) |
| GREP-PM-4 | `_anim\.seek\s*\([^,]*\)` (single-arg seek) in `player_movement.gd` | `seek(time, true)` 강제 즉시 평가 누락 (time-rewind.md I4) | (architecture.yaml `api_decisions`에 추가 후보) |
| GREP-PM-5 | `_is_restoring\s*=\s*(true\|false)` outside `player_movement.gd` `restore_from_snapshot()` 메서드 | `_is_restoring` 외부 mutation 금지 (single-writer = restore 메서드만; C.4.1) | (등록 후보) |
| GREP-PM-6 | `await\s+get_tree\(\)\.physics_frame\|await\s+.*\.timeout` inside `player_movement.gd` SM transition handlers | 결정성 위반 — 모든 SM transition은 동기 처리 (C.2.5) | (등록 후보) |
| GREP-PM-7 | `is_on_floor\(\)` 호출 위치 — `player_movement.gd` 안에서 Phase 6a 외 호출 시 fail | C.3.2 forbidden — Phase 5 이전 stale 값 | (등록 후보) |

> **CI script obligation (devops-engineer / tools-programmer 작업)**: 위 7 grep을 CI workflow에 추가. False-positive 면제는 `# ALLOW-PM-GREP-N` 인라인 주석 + justification 의무 (`damage.md` AC-21 패턴과 일치).

#### G.4.3 GUT unit tests (H.7 연계)

H.7 *Static Analysis & Forbidden Patterns* 섹션이 `INV-1..7` + `GREP-PM-1..7` 모두에 대한 GUT test fixture 의무화. 본 G.4 섹션은 catalog만 정의; 테스트 spec은 H.7이 단일 출처.

| Coverage 의무 | H.7 AC ID (예정) |
|---------------|-----------------|
| INV-1..6 invariant 발화 (debug 빌드) | H.7 AC가 fail-fast PlayerMovementTuning 픽스처로 invariant violation 검증 |
| GREP-PM-1..7 정적 분석 | H.7 AC가 grep regex로 `player_movement.gd` + 외부 .gd 파일 검증 (`damage.md` AC-21 패턴) |
| `_is_restoring` 가드 누락 anim method-track 검출 | H.7 AC: `grep "method_track\|anim_method"` + `_is_restoring` 가드 부재 시 fail (C.4.4 obligation) |

#### G.4.4 결정 요약 (architecture.yaml 등록 상태)

| forbidden_pattern | architecture.yaml 등록 | 출처 |
|-------------------|------------------------|------|
| `direct_player_state_write_during_rewind` | ✅ Session 9 등록 (C.1.3 single-writer policy 단일 enforce) | F.4.1 #6 |
| `delta_accumulator_in_movement` | ✅ Session 9 등록 (C.3.2 + D.1 step_size unbounded-fix) | F.4.1 #6 |
| `single_arg_anim_seek` | ⏳ Tier 1 prototype 시점에 추가 (`time-rewind.md` I4 단일 출처와 reciprocal) | (deferred) |
| `cross_entity_sm_transition_call` | (이미 `damage.md` / `state-machine.md`에 등록) | C.2.3 외부 system 직접 구독 금지 |
| `wall_clock_in_gameplay_logic` | (이미 ADR-0003에 등록 후보) | C.3.2 |

ADR 신규 발행 *불필요* — 위 항목은 모두 `damage.md` AC-21 precedent + ADR-0003 결정성 사다리의 PM 인스턴스화. `lean` mode 정책에 부합.

---

## H. Acceptance Criteria

### H.1 Snapshot Restoration (TR contract)

> **Coverage**: C.4.1 6-step `restore_from_snapshot()` · C.4.2 `_is_restoring` lifetime · C.4.3 `_derive_movement_state()` T14-T17 · C.4.4 anim method-track guard · C.4.5 WeaponSlot signal guard · DEC-PM-3 ammo-not-captured. **6 AC** (all BLOCKING Logic GUT unless tagged).

**AC-H1-01** *(Logic GUT — BLOCKING)* — 7-field round-trip identity.
**GIVEN** `PlayerMovement` is in `DeadState` and a `PlayerSnapshot` with `is_grounded=true, abs(velocity.x) < abs_vel_x_eps, global_position=(100,200), velocity=(0,-5), facing_direction=3, current_weapon_id=2, animation_name=&"idle", animation_time=0.3` is applied via `restore_from_snapshot(snap)`,
**WHEN** the call returns,
**THEN** `global_position == snap.global_position` AND `velocity == snap.velocity` AND `facing_direction == snap.facing_direction` AND `_current_weapon_id == snap.current_weapon_id` AND `_is_grounded == snap.is_grounded` AND `AnimationPlayer.current_animation == snap.animation_name` AND `abs(AnimationPlayer.current_animation_position - snap.animation_time) < 0.002`.
*Mirror: time-rewind.md AC-A4 (TRC-side capture; both must pass for full TR contract).*

**AC-H1-02** *(Logic GUT — BLOCKING)* — `_is_restoring` single-tick lifetime.
**GIVEN** `_is_restoring == false` before `restore_from_snapshot(snap)` is called,
**WHEN** `restore_from_snapshot(snap)` begins (Step 1),
**THEN** `_is_restoring == true` throughout the body including the `AnimationPlayer.seek(snap.animation_time, true)` synchronous method-track invocation in Step 6;
**AND WHEN** the next `_physics_process` tick fires Phase 1,
**THEN** `_is_restoring == false`. Guard active for exactly one tick.

**AC-H1-03** *(Logic GUT — BLOCKING)* — anim method-track stale-spawn block.
**GIVEN** PlayerMovement hosts an anim method-track callback `_on_anim_spawn_bullet` AND `_is_restoring == true`,
**WHEN** `AnimationPlayer.seek(snap.animation_time, true)` synchronously fires the method-track key,
**THEN** `_on_anim_spawn_bullet` returns immediately without calling `_weapon_slot.spawn_projectile()`; projectile spawn count during restore tick = 0.
*Mirror: time-rewind.md AC-D5 (validates same guard from TRC seek-call side).*

**AC-H1-04** *(Logic GUT — BLOCKING)* — WeaponSlot cascade signal block.
**GIVEN** `PlayerMovement._on_weapon_equipped(new_id: int)` is connected to `WeaponSlot.weapon_equipped` signal AND `_is_restoring == true`,
**WHEN** `weapon_equipped` fires with `new_id != snap.current_weapon_id`,
**THEN** `_current_weapon_id` remains equal to `snap.current_weapon_id` (the value just set in Step 3); handler returns without mutating the field; `_current_weapon_id` change count during restore tick = 0.

**AC-H1-05** *(Logic GUT + Static grep — BLOCKING)* — DEC-PM-3 ammo-not-captured.
**GIVEN** `PlayerSnapshot` schema is defined,
**WHEN** the test inspects `PlayerSnapshot.get_property_list()` (or equivalent reflection),
**THEN** no property named `ammo_count` (or `ammo`/`current_ammo`) exists; AND
**WHEN** static grep runs `grep -n 'ammo' src/.../player_movement.gd src/.../player_snapshot.gd`,
**THEN** zero matches in both files (DEC-PM-3 isolation: ammo is Player Shooting #7 territory).
*Resolves: time-rewind.md OQ-1 / E-22 / F6.*

**AC-H1-06** *(Logic GUT — BLOCKING)* — T14-T17 4-branch derive correctness.
**GIVEN** four fixture snapshots covering the 4 valid branches:
- *Snap-T14*: `is_grounded=true, abs(velocity.x) < abs_vel_x_eps`
- *Snap-T15*: `is_grounded=true, abs(velocity.x) >= abs_vel_x_eps`
- *Snap-T16*: `is_grounded=false, velocity.y < 0`
- *Snap-T17*: `is_grounded=false, velocity.y >= 0`

**WHEN** `_derive_movement_state(snap)` is called for each,
**THEN** returns are: `IdleState`, `RunState`, `JumpState`, `FallState` respectively. No call ever returns `DeadState` or `AimLockState`.
**AND** for the pathological case (`is_grounded=true, velocity.y < 0` — E-PM-2 GAP-1 Decision A 2026-05-10 *is_grounded wins*): derive returns `IdleState` or `RunState` per `velocity.x` (is_grounded authority); the next-tick Phase 5 `move_and_slide()` + Phase 6a re-evaluation auto-corrects via T5 → Fall. Test asserts the 1-tick state at restore-tick is Idle/Run, NOT Jump.
*Cross-ref: state-machine.md AC-09 (force_re_enter mechanics).*

### H.2 Movement State Machine (PlayerMovementSM)

> **Coverage**: C.2.1 6 states · C.2.2 17-row T-matrix · C.2.3 trigger constraints · C.2.4 input ignore rules · C.2.5 framework atomicity (M2 reuse). **5 AC** (all BLOCKING).

**AC-H2-01** *(Logic GUT — BLOCKING)* — AimLock blocks jump buffer (C.2.4 input ignore).
**GIVEN** `PlayerMovementSM` is in `AimLockState` AND a `jump_just_pressed = true` is injected in Phase 2,
**WHEN** Phase 3a evaluates transitions,
**THEN** `JumpState` is NOT entered; `current_state` remains `AimLockState`; `_jump_buffered_at_frame` is NOT updated (buffer registration skipped). Verified on the press tick AND the following tick.
*Cross-ref obligation: Input System #1 must include reciprocal AC asserting `aim_lock` hold + `jump` press are independent input events with PM ignore semantics — F.4.2 obligation.*

**AC-H2-02** *(Logic GUT — BLOCKING)* — T13 signal-reactive Dead entry.
**GIVEN** `PlayerMovementSM` is in `Idle` or `Run` AND `EchoLifecycleSM.state_changed` fires with value `DYING`,
**WHEN** `_on_lifecycle_state_changed` is called,
**THEN** `PlayerMovementSM` transitions to `DeadState`; `velocity == Vector2.ZERO`; `state_changed` emits with `to == &"DeadState"` exactly 1 time.
**AND GIVEN** the signal fires with value `DEAD`,
**THEN** same result (T13 handles DYING and DEAD identically). Verify also: PM does NOT poll `EchoLifecycleSM.current_state` during the test (signal-reactive only — C.2.3 forbidden).

**AC-H2-03** *(Logic GUT — BLOCKING)* — Variable jump cut (T7).
**GIVEN** `PlayerMovementSM` is in `JumpState` with `velocity.y = -426.7` (mid-rise after 4 frames of g_rising integration; derived from D.2 worked example),
**WHEN** `jump_released = true` is injected in Phase 3a,
**THEN** `velocity.y = max(-426.7, -160.0) = -160.0` exactly (cut applied); `FallState` entered the same tick; next Phase 4 uses `gravity_falling = 1620` instead of `gravity_rising = 800`.
*D.2 Formula 5 + Frame-4 cut path worked example.*

**AC-H2-04** *(Integration GUT — BLOCKING)* — M2 framework atomicity reuse.
**GIVEN** `PlayerMovementSM` extends framework `StateMachine` AND a `transition_to(DeadState)` is called mid-execution of a `Run → Jump` transition (framework `_is_transitioning == true`),
**WHEN** the second transition is requested,
**THEN** Dead transition is enqueued (NOT dropped, NOT immediately applied); after `Run → Jump` completes, Dead dispatches atomically; final `current_state == DeadState`. `state_changed` emits exactly twice in order: `Run → Jump` then `Jump → Dead`. No state skipped.
*Mirror: state-machine.md AC-23 (full-scene M2 reuse integration gate); H2-04 is the unit-level component test.*

**AC-H2-05** *(Logic GUT — BLOCKING)* — REWINDING → ALIVE no-op guard.
**GIVEN** `PlayerMovementSM.current_state` is already `IdleState` (or any non-Dead state, having been re-derived by `restore_from_snapshot()` 30 frames earlier) AND `EchoLifecycleSM.state_changed` fires with value `ALIVE`,
**WHEN** `_on_lifecycle_state_changed` handles ALIVE,
**THEN** the guard `if current_state is not DeadState: return` fires; `current_state` is NOT mutated; `state_changed` does NOT emit. `DeadState` entry count over the full restore + ALIVE sequence stays at 1 (boot-to-restore — only the initial Dead before restore).
*C.2.2 T13 note + C.4.3 intentional omission. Prevents double-transition on the 30-frame-deferred ALIVE signal.*

### H.3 Per-Tick Determinism

> **Coverage**: C.3.1 7-phase ordering · C.3.2 forbidden patterns · 1000-cycle bit-identical PlayerSnapshot · `delta = 1/60` invariant · ADR-0003 `process_physics_priority = 0` sequencing with TRC=1. **4 AC**.

**AC-H3-01** *(Integration GUT — BLOCKING)* — 1000-cycle bit-identical PlayerSnapshot.
**GIVEN** a scripted test sequence with fixed `move_axis` input timeline, fixed `PlayerMovementTuning` (G.1 Tier 1 defaults), fixed starting `global_position` and `velocity`, AND the same machine + build,
**WHEN** the sequence runs 1000 times from identical starting state,
**THEN** all 7 `PlayerSnapshot` fields captured at every tick N are bit-identical across all 1000 runs. Specifically: `global_position`, `velocity`, `facing_direction`, `current_animation_name`, `current_animation_time`, `current_weapon_id`, `is_grounded` produce identical values per (run, tick) pair.
**FORBIDDEN**: run-1 capture as expected baseline (per damage.md AC-29 precedent — expected order must be defined as a `const` array, never self-captured).
*Mirror: time-rewind.md AC-F1 (bit-identical PlayerSnapshot from TRC ring buffer side) + AC-F2 (post-rewind position identity). Together form full ADR-0003 R-RT3-01 validation.*

**AC-H3-02** *(Logic GUT + Static grep — BLOCKING)* — Delta accumulator absence (GREP-PM-2).
**GIVEN** `player_movement.gd` is committed,
**WHEN** static grep runs `grep -nE '[a-zA-Z_]+\s*\+=\s*delta' player_movement.gd`,
**THEN** the only matches are the two authorised per-tick velocity integrations in Phase 4 (`velocity.y += gravity_rising * delta` and `velocity.y += gravity_falling * delta`). Zero matches on counter-style accumulators (`_coyote_remaining += delta`, `_elapsed += delta`, etc).
**AND GIVEN** an integration GUT runs `_physics_process` with `delta = 1.0/60.0`,
**WHEN** Phase 4 executes the rising-gravity integration once,
**THEN** post-integration `velocity.y` differs from pre-integration by exactly `gravity_rising / 60.0 ≈ 13.333 px/s` (tolerance ±0.001).
*C.3.2 forbidden + GREP-PM-2.*

**AC-H3-03** *(Integration GUT + Static grep — BLOCKING, GAP-3 Decision A 2026-05-10)* — `process_physics_priority` Inspector-set + ordering.
**(a) Static grep**: `grep -nE 'process_physics_priority\s*=\s*0' src/<player_movement_scene>.tscn` MUST return exactly 1 match (.tscn-side enforcement).
**(b) Static grep negative**: `grep -nE 'process_physics_priority\s*=' src/.../player_movement.gd` MUST return zero matches (no script override allowed).
**(c) Runtime GUT**: a test scene with `PlayerMovement` (priority=0) and a `TimeRewindController` stub (priority=1) runs one physics frame; a spy in TRC's `_physics_process` records its read values for the 7 PlayerSnapshot fields; those values match PM's Phase 6c final state byte-for-byte. Additionally `assert(player_movement.process_physics_priority == 0)` and `assert(trc.process_physics_priority == 1)`.
*C.1.1 `.tscn` Inspector obligation + ADR-0003 priority ladder. Belt + suspenders per GAP-3 resolution.*

**AC-H3-04** *(Static grep / CI — BLOCKING)* — Wall-clock + async + single-arg seek absence.
**GIVEN** `player_movement.gd` is committed,
**WHEN** CI runs the grep step in `tools/ci/pm_static_check.sh` (or equivalent),
**THEN** zero matches for each of:
- `Time\.get_ticks_msec\|OS\.get_ticks_msec\|Time\.get_unix_time` (GREP-PM-3, ADR-0003 결정성 클락)
- `await\s+get_tree\(\)\.physics_frame\|await\s+.*\.timeout` (GREP-PM-6, async transition forbidden)
- `_anim\.seek\s*\([^,)]*\)` matching single-arg `seek(time)` without the second `true` arg (GREP-PM-4, time-rewind.md I4 단일 출처)

Any non-zero match → CI fail. False-positive exemption: `# ALLOW-PM-GREP-N` inline comment with justification.
*C.3.2 forbidden patterns + matches damage.md AC-21 precedent.*

### H.4 Input → Velocity Mapping

> **Coverage**: D.1 run accel/decel formula · D.4 facing 8-way encoding · C.5 input contract · E-PM-9 deadzone provisional. **4 AC**.

**AC-H4-01** *(Logic GUT — BLOCKING)* — Run accel reaches v_max in exactly run_accel_frames.
**GIVEN** `PlayerMovement` is in `RunState` with Tier 1 defaults (`run_top_speed = 200.0`, `run_accel_frames = 6`) AND `velocity.x == 0.0`,
**WHEN** Phase 4 executes for 6 consecutive ticks with `move_axis.x = 1.0`,
**THEN** `velocity.x` at end of tick 6 == `200.0` exactly (cap reached); at no intermediate tick does `velocity.x` exceed `200.0`. At end of tick 1, `velocity.x ≈ 33.333` (tolerance ±0.01).
**AND GIVEN** sign-reversal scenario (start `velocity.x = +200, move_axis.x = -1.0`),
**WHEN** ticks elapse,
**THEN** `velocity.x` reaches 0 at tick 8 (decel phase, `run_decel_frames = 8`) and reaches `-200` at tick 14 (decel 8 + accel 6). Per D.1 worked example.

**AC-H4-02** *(Logic GUT — BLOCKING)* — 8-way facing encoding worked-example sequence.
**GIVEN** outside-aim_lock with `facing_threshold_outside = 0.2`, the input sequence Frame 1 = `(0.8, 0.0)`, Frame 2 = `(0.8, -0.7)`, Frame 3 = `(0.05, 0.0)`, Frame 4 = `(0.0, 0.0)`, Frame 5 = `(-0.9, 0.0)`,
**WHEN** Phase 6c runs each frame,
**THEN** `facing_direction` sequence is exactly: `0` (E) → `1` (NE) → `1` (preserve, both axes < 0.2) → `1` (preserve, (0,0)) → `4` (W).
**AND GIVEN** `AimLockState` with `facing_threshold_aim_lock = 0.1`, input `(0.0, -0.15)`,
**WHEN** Phase 6c runs,
**THEN** `facing_direction = 2` (N) — the finer threshold passes where `0.2` would preserve.
*D.4 worked example verbatim.*

**AC-H4-03** *(Logic GUT — BLOCKING)* — AimLock freezes movement but updates facing.
**GIVEN** `PlayerMovementSM` is in `AimLockState` AND `move_axis = (0.5, -0.8)`,
**WHEN** Phase 4 executes,
**THEN** `velocity == Vector2.ZERO` (movement frozen — DEC-PM-2 hold semantics);
**AND** Phase 6c executes,
**THEN** `facing_direction == 1` (NE — encoding of `(sign(0.5), sign(-0.8)) = (1,-1)`). `RunState` is NOT entered despite non-zero `move_axis.x` (C.2.4 input ignore).

**AC-H4-04** *(Manual / Playtest — ADVISORY)* — E-PM-9 deadzone observation.
**GIVEN** Input System #1 GDD is not yet authored AND `project.godot` Tier 1 deadzone defaults are configured,
**WHEN** a 5-minute Tier 1 prototype playtest is conducted with a controller (analog stick at near-rest position),
**THEN** no unintended `RunState` entry is observable from stick noise below 0.2; documented in `production/qa/evidence/pm-deadzone-playtest-[date].md`. Provisional pending Input System #1 AC (C.5.3 deadzone obligation).
*F.4.2 obligation: Input #1 must include deadzone enforcement AC (0.2 default per C.5.3); upgrades H4-04 from ADVISORY to obsolete on Input #1 GDD authoring.*

### H.5 Jump / Gravity / Coyote / Buffer

> **Coverage**: D.2 jump impulse · apex height invariant (144 px) · variable cut · D.3 coyote/buffer predicates · INT_MIN sentinel reset on Dead/restore. **4 AC** (count-34 plan: coyote + buffer collapsed into one compound AC).

**AC-H5-01** *(Logic GUT — BLOCKING)* — Jump impulse + apex height invariant.
**GIVEN** `PlayerMovement` is in `RunState` (grounded) with Tier 1 defaults (`jump_velocity_initial = 480.0`, `gravity_rising = 800.0`),
**WHEN** `jump_pressed = true` is injected (T3) and `JumpState.enter()` executes,
**THEN** `velocity.y == -480.0` exactly.
**AND WHEN** Phase 4 runs for 36 ticks with jump held (no release),
**THEN** `velocity.y >= 0.0` is reached at tick 36 (apex predicate triggers T6); maximum upward `global_position.y` displacement from launch equals `480² / (2 × 800) = 144 px` exactly (tolerance ±1 px).
*D.2 Formula 2 — Tier 1 height invariant lock (Decision A 2026-05-10).*

**AC-H5-02** *(Logic GUT — BLOCKING)* — Variable jump cut + post-cut rise.
**GIVEN** `JumpState` is active with `velocity.y = -426.7` (Frame 4 of full press, derived from D.2 worked example),
**WHEN** `jump_released = true` is injected and Phase 3a evaluates T7,
**THEN** `velocity.y = max(-426.7, -160.0) = -160.0` exactly; `FallState` entered same tick; gravity switches to `gravity_falling = 1620.0`.
**AND WHEN** post-cut Phase 4 ticks elapse until `velocity.y >= 0`,
**THEN** additional upward rise from `velocity.y = -160` equals `160² / (2 × 1620) ≈ 7.901 px` (tolerance ±0.5 px).
*D.2 Formula 5 + Frame-4 cut path worked example.*

**AC-H5-03** *(Logic GUT — BLOCKING, COMPOUND)* — Coyote + jump buffer predicates (boundary fixtures).
Combined per count-34 plan; both predicates use `Engine.get_physics_frames()` differencing with identical Tier 1 defaults (`coyote_frames = 6`, `jump_buffer_frames = 6`).

*Coyote case:*
**GIVEN** PM was grounded at frame N (`_last_grounded_frame = N`), is in `FallState`, and `coyote_frames = 6`,
**WHEN** `jump_pressed = true` fires at frame N+3,
**THEN** `coyote_eligible = (N+3 - N) <= 6 = true`; T3 fires; `JumpState` entered.
**AND WHEN** `jump_pressed` fires at frame N+7,
**THEN** `coyote_eligible = false`; T3 does NOT fire (window expired).

*Buffer case:*
**GIVEN** `jump_pressed = true` fires at frame M while `is_grounded = false` (`_jump_buffered_at_frame = M`), `jump_buffer_frames = 6`,
**WHEN** PM lands at frame M+3,
**THEN** `jump_buffered = (M+3 - M) <= 6 AND is_grounded = true`; T3 auto-fires on landing tick without fresh `jump_pressed` input.
**AND WHEN** PM lands at frame M+7,
**THEN** `jump_buffered = false`; no auto-T3.
*D.3 Formulas 1, 2, 3 — both PASS and FAIL boundaries required per AC.*

**AC-H5-04** *(Logic GUT — BLOCKING)* — INT_MIN sentinel reset on Dead + restore.
**GIVEN** `_jump_buffered_at_frame = M` (valid buffer registered) AND `PlayerMovementSM` transitions to `DeadState` (T13),
**WHEN** `DeadState.enter()` fires,
**THEN** `_jump_buffered_at_frame == INT_MIN` (specifically `-9223372036854775808`).
**AND WHEN** `restore_from_snapshot(snap)` is later called (Step 4),
**THEN** `_jump_buffered_at_frame == INT_MIN` (re-cleared); also `_last_grounded_frame == INT_MIN` if `not snap.is_grounded` else equals current frame.
**AND WHEN** the post-restore tick evaluates `jump_buffered`,
**THEN** `(current_frame - INT_MIN)` overflows to a large positive number greater than `jump_buffer_frames` → `jump_buffered = false`; no phantom jump fires without fresh `jump_pressed` input.
*D.3 Formula 5 + C.3.3 Scenario C. Phantom-jump prevention is critical for Pillar 1 input continuity (B.4 #1).*

### H.6 Damage / SM Integration

> **Coverage**: C.3.4 mid-`move_and_slide()` cascade · C.6 Damage composition (PM hosts only) · DEC-4 single-direction (HurtBox.monitorable owned by SM, NOT PM) · E-PM-15..17 · EchoLifecycleSM signal-reactive Dead entry. **5 AC**.

**AC-H6-01** *(Integration GUT — BLOCKING)* — Mid-`move_and_slide()` lethal cascade atomicity.
**GIVEN** `PlayerMovement._physics_process` is executing Phase 5 (`move_and_slide()`) AND a collision triggers the full cascade chain `HitBox.area_entered → HurtBox.hurtbox_hit → Damage.lethal_hit_detected → EchoLifecycleSM transition_to(DyingState) → state_changed(DYING) → PlayerMovementSM._on_lifecycle_state_changed → transition_to(DeadState)`,
**WHEN** Phase 5 returns control to PM,
**THEN** `PlayerMovementSM.current_state == DeadState`; the entire cascade completed within the single physics tick; Phase 6a/6b/6c proceed with DeadState (physics-driven transitions in 6b are no-ops, 6c facing skip from Dead). Tick boundary verification: `Engine.get_physics_frames()` is identical at Phase 1 entry and Phase 7 exit (same frame).
*Mirror: damage.md AC-9 (Damage-side dying latch) + AC-36 (first-hit lock) + state-machine.md AC-15 (latch lifecycle). PM-side completion test for the full cascade.*

**AC-H6-02** *(Logic GUT — BLOCKING, NEGATIVE)* — PM does NOT directly subscribe to Damage signals.
**GIVEN** `PlayerMovement._ready()` has completed,
**WHEN** the test inspects the Damage component's signal connections via `Damage.get_signal_connection_list(&"player_hit_lethal")` and `Damage.get_signal_connection_list(&"lethal_hit_detected")`,
**THEN** no callable in either list points to a method on the `PlayerMovement` instance (or any descendant of `PlayerMovement` other than `EchoLifecycleSM` itself, which IS allowed). PM ↔ Damage is composition-only per C.6.
**AND** static grep `grep -nE 'damage.*\.connect\b|lethal_hit_detected\b|player_hit_lethal\b' player_movement.gd` returns zero matches.
*C.6 + C.2.3 forbidden subscription. Negative test prevents future regression where someone connects PM to Damage directly.*

**AC-H6-03** *(Integration GUT — BLOCKING, NEGATIVE)* — `HurtBox.monitorable` single-writer (DEC-4).
**GIVEN** `EchoLifecycleSM` transitions to `RewindingState` (REWINDING),
**WHEN** `RewindingState.enter()` fires,
**THEN** `HurtBox.monitorable == false` (verified by direct property read).
**AND WHEN** an enemy `HitBox` with matching collision layers overlaps `HurtBox` during REWINDING,
**THEN** `HitBox.area_entered` emits 0 times (Godot 4.6 Area2D: `monitorable=false` blocks detection).
**AND WHEN** `RewindingState.exit()` fires,
**THEN** `HurtBox.monitorable == true` restored.
**AND** static grep over `player_movement.gd`: `grep -nE 'HurtBox.*\.monitorable\s*=|hurt_box.*\.monitorable\s*=' player_movement.gd` returns zero matches (PM does NOT write the field at any point — DEC-4 single-direction enforce).
*Mirror: damage.md AC-12 + AC-20. Negative-direction enforcement on PM side.*

**AC-H6-04** *(Logic GUT — BLOCKING)* — `_is_restoring` clears before next-tick cascade (E-PM-17).
**GIVEN** `restore_from_snapshot(snap)` fires (T14-T17 derive) at tick T (sets `_is_restoring = true`) AND a damage cascade is set up to fire at tick T+1 mid-Phase 5,
**WHEN** tick T+1 begins Phase 1,
**THEN** `_is_restoring = false` cleared (single-tick lifetime per AC-H1-02);
**AND WHEN** Phase 5 cascade reaches `EchoLifecycleSM.state_changed(DYING) → PlayerMovementSM.transition_to(DeadState)`,
**THEN** the Dead transition fires normally (no `_is_restoring` block); final state at tick T+1 = Dead.
Total `DeadState` entry count over the two-tick (restore + re-hit) sequence = 2.
*E-PM-17 dev/test fixture scenario. In normal flow (REWINDING 30-frame i-frame active), this is unreachable; covered for fixture-bypass safety.*

**AC-H6-05** *(Integration GUT — BLOCKING)* — Mid-transition Dead enqueue + dispatch (E-PM-8).
**GIVEN** `PlayerMovementSM` is mid-`Run → Jump` transition (framework `_is_transitioning == true`) AND `EchoLifecycleSM.state_changed(DYING)` fires synchronously during Phase 5 cascade,
**WHEN** `_on_lifecycle_state_changed` calls `transition_to(DeadState)`,
**THEN** Dead enters the framework pending queue (per state-machine.md C.2.5); `Run → Jump` completes; Dead immediately dispatches; final `current_state == DeadState`. `state_changed` emits exactly: `(Run → Jump)` then `(Jump → Dead)` in that order. No state skipped, no transition dropped.
*Mirror: state-machine.md AC-07 (queue atomicity from framework side). E-PM-8 coyote + mid-`move_and_slide()` Damage overlap is covered by this same fixture.*

### H.7 Static Analysis & Forbidden Patterns

> **Coverage**: G.4.1 INV-1..7 assertion fixtures · G.4.2 GREP-PM-1..7 regex CI gates · anim method-track `_is_restoring` guard scan · matches damage.md AC-21/29 precedent. **5 AC**.

**AC-H7-01** *(Logic GUT — BLOCKING)* — Tuning invariant assertions fire (INV-1..6).
**GIVEN** `PlayerMovementTuning` Resource is instantiated with each of these 6 violation fixtures (one per test case):
- (a) `gravity_falling = 799.0, gravity_rising = 800.0` → INV-1 violation
- (b) `air_control_coefficient = 1.0` → INV-2 violation
- (c) `abs_vel_x_eps = 0.0` → INV-3 violation
- (d) `facing_threshold_aim_lock = 0.25, facing_threshold_outside = 0.2` → INV-4 violation
- (e) `jump_velocity_initial = 100.0, gravity_rising = 800.0` (apex `100²/(2×800) = 6.25 px < 50 px`) → INV-5 violation
- (f) `coyote_frames = 10, jump_buffer_frames = 8` (sum = 18 > 16) → INV-6 violation

**WHEN** `tuning._validate()` is called for each fixture in a debug build (`OS.is_debug_build() == true`),
**THEN** each fires exactly 1 `assert()` failure (captured via push_error or assertion-trap mechanism).
**AND** a baseline-valid `PlayerMovementTuning` (G.1 Tier 1 defaults) calls `_validate()` with 0 assertions firing.
*G.4.1 INV-1..6 catalogue.*

**AC-H7-02** *(Logic GUT — ADVISORY/DEFERRED)* — INV-7 deferred enforcement gate.
**GIVEN** Tier 1 has no setter on `PlayerMovementTuning` fields (direct `@export` assignment only),
**WHEN** the test scans `PlayerMovementTuning` script for `set_*` setter methods,
**THEN** zero setters exist (INV-7 trivially passes — no setter = no runtime mutation path during restore).
**AND IF** a setter is later introduced for any tuning field,
**THEN** the test FAIL — the regression test fixture: inject a setter stub that calls `assert(not _is_restoring)` → invoke during `_is_restoring=true` → assert guard fires.
*G.4.1 INV-7 (conditional/deferred). Documents the contract for future Tier 2 setter introduction; passes trivially in Tier 1.*

**AC-H7-03** *(Static grep / CI — BLOCKING)* — External direct-write + `_is_restoring` mutation + Phase 6a `is_on_floor` enforce.
**GIVEN** `player_movement.gd` and all files in `src/` are committed,
**WHEN** CI runs `tools/ci/pm_static_check.sh` grep step,
**THEN** zero matches for each of:
- (a) GREP-PM-1: `grep -rnE '\.global_position\s*=|\.velocity\s*=|\.facing_direction\s*=|\._current_weapon_id\s*=|\._is_grounded\s*=' src/ --exclude=player_movement.gd` (external write to PM 7 fields forbidden)
- (b) GREP-PM-5: `grep -nE '_is_restoring\s*=\s*(true|false)' player_movement.gd` outside the `restore_from_snapshot()` method body (single-writer enforce)
- (c) GREP-PM-7: `grep -cE 'is_on_floor\(\)' player_movement.gd` returns exactly 1 (the Phase 6a single call site; any additional call = stale-value risk per C.3.2)

False-positive exemption: `# ALLOW-PM-GREP-N` inline comment + justification (matches damage.md AC-21 precedent).
*G.4.2 GREP-PM-1, 5, 7 consolidated.*

**AC-H7-04** *(Static grep / CI — BLOCKING, GAP-6 Decision A 2026-05-10)* — Anim method-track `_is_restoring` guard universal scan.
**GIVEN** `player_movement.gd` is committed,
**WHEN** CI runs:
```
grep -nE '^func _on_anim_[a-z_]+' player_movement.gd \
  | while read line; do
      func_name=$(echo "$line" | sed -E 's/.*(_on_anim_[a-z_]+).*/\1/')
      body=$(awk "/^func $func_name/,/^func |^[a-zA-Z_]+/" player_movement.gd)
      if ! echo "$body" | grep -qE '_is_restoring' \
         && ! echo "$body" | grep -qE '# ALLOW-PM-GREP-4'; then
          echo "VIOLATION: $func_name lacks _is_restoring guard"
          exit 1
      fi
  done
```
(or a Godot-native equivalent in `tools/ci/pm_static_check.sh`),
**THEN** every `_on_anim_*` function in `player_movement.gd` either contains `_is_restoring` (`if _is_restoring: return` typically as first guard line) OR has `# ALLOW-PM-GREP-4: <justification>` inline comment.
Universal guard policy with explicit opt-out (lightweight SFX e.g. footstep can opt out via comment per Audio GDD decision — F.4.2 obligation gate).
*C.4.4 obligation. Partial guard = silent regression risk.*

**AC-H7-05** *(Logic GUT — BLOCKING)* — 1000-cycle PlayerMovementSM transition determinism.
**GIVEN** a fixture stubs `Engine.get_physics_frames()` to a deterministic counter AND scripts a fixed input sequence producing transitions `Idle → Run → Jump → Fall → Idle` (with apex T6, landing T8),
**WHEN** the fixture executes 1000 times from identical seed,
**THEN** `state_changed` emit sequence is byte-identical across all 1000 cycles. Expected sequence is defined by the fixture as:
```gdscript
const EXPECTED_TRANSITIONS: Array[StringName] = [
    &"Idle", &"Run", &"Jump", &"Fall", &"Idle"  # exact order; tick numbers also fixed
]
```
**FORBIDDEN**: run-1 self-capture (per damage.md AC-29 precedent — expected sequence must be a `const`, never the result of run-1).
*G.4.1 determinism + extends damage.md AC-29 to PM SM layer.*

### H.8 Bidirectional Update Verification

> **Coverage**: F.4.1 6 cross-doc reciprocals (compound — verified at architecture.yaml + grep level) + F.4.2 future GDD obligation registry. **1 compound AC** (count-34 plan: collapse 3→1).

**AC-H8-01** *(Manual / PR Review checklist — ADVISORY, COMPOUND)* — F.4.1 6-edit cross-doc reciprocals all present.
**GIVEN** Session 9 has applied the F.4.1 cross-doc edits batch (per `production/session-state/active.md` Session 9 close-out),
**WHEN** the PR Review reviewer runs the following grep checks against the repository working tree,
**THEN** all 6 patterns return matches consistent with the F.4.1 spec:

| # | F.4.1 obligation | Verification command | Expected result |
|---|------------------|----------------------|-----------------|
| 1 | `time-rewind.md` F.1 row #6 — `*(provisional)*` removed + 7-field interface locked + `restore_from_snapshot(snap: PlayerSnapshot) -> void` signature + `_is_restoring` cross-link | `grep -n 'provisional' design/gdd/time-rewind.md \| grep -i 'player_movement\|player movement\|#6'` | 0 matches (provisional marker gone) |
| 2 | `state-machine.md` F.2 row #6 — `PlayerMovementSM extends StateMachine` M2 reuse + flat composition + Dead reactive | `grep -n 'PlayerMovementSM\|extends StateMachine' design/gdd/state-machine.md \| grep -i 'F\.2\|row 6\|#6'` | ≥1 match in F.2 row #6 region naming `PlayerMovementSM` + `extends StateMachine` |
| 3 | `state-machine.md` C.2.1 lines 178-188 — node tree corrected to `PlayerMovement (CharacterBody2D, root)` model (Round 5 cross-doc-contradiction exception) | `grep -n 'CharacterBody2D' design/gdd/state-machine.md \| grep -i 'PlayerMovement'` | ≥1 match showing PM is the CharacterBody2D root, not split into ECHO + PlayerMovement Node |
| 4 | `damage.md` F.1 row — ECHO HurtBox + HitBox + Damage are PM child nodes; HurtBox lifecycle = SM, ownership = PM | `grep -n 'PlayerMovement\|player_movement' design/gdd/damage.md` | ≥1 match in F.1 row showing host/lifecycle ownership split |
| 5 | `design/gdd/systems-index.md` System #6 row Status = `Designed (2026-05-10)` + design doc link + Progress Tracker counts updated + Last Updated header | `grep -nE 'Designed.*2026-05-10\|player-movement\.md' design/gdd/systems-index.md` | ≥2 matches (status row + Last Updated entry) |
| 6 | `docs/registry/architecture.yaml` 4 new entries: `state_ownership.player_movement_state`, `interfaces.player_movement_snapshot`, `forbidden_patterns.delta_accumulator_in_movement`, `api_decisions.facing_direction_encoding` | `grep -nE 'player_movement_state\|player_movement_snapshot\|delta_accumulator_in_movement\|facing_direction_encoding' docs/registry/architecture.yaml` | exactly 4 matches (one per key) |

**AND** `python3 -c "import yaml; yaml.safe_load(open('docs/registry/architecture.yaml'))"` returns 0 exit code (YAML validity post-edits).

**Failure mode**: any check returns 0 matches when ≥1 expected, or fails YAML validation → PR Review BLOCKED until F.4.1 batch corrected.

**ADVISORY classification rationale** (per damage.md AC-26/27 precedent): document-state checks are PR Review checklist items, not BLOCKING automated CI gates, until `tools/ci/gdd_consistency_check.gd` is authored. **Upgrade path**: when CI tool is built (queued under damage.md OQ-DMG-5 tooling pattern), this AC promotes to BLOCKING with the same grep specs as the CI step.

> **F.4.2 obligations registry** (separate from this AC — *deferred to target GDD authoring*): ~~Input #1 (deadzone + AimLock-jump exclusivity)~~ ✅ **Resolved 2026-05-11** (Input #1 GDD Designed + re-review APPROVED 2026-05-11 lean mode; deadzone locked at input.md C.1.3 + AC-IN-06/07 BLOCKING; AimLock-jump exclusivity locked at input.md C.3.3 + AC-IN-16 BLOCKING; PM AC-H4-04 ADVISORY ⇒ **obsolete** — Input #1 BLOCKING ACs replace; F.4.1 #3 closure batch 2026-05-11), Player Shooting #7 (`_on_anim_spawn_bullet` `_is_restoring` guard + ammo restoration policy review), Scene Manager #2 (`_last_grounded_frame` / `_jump_buffered_at_frame` clear responsibility — OQ-PM-1), VFX #14 (`_is_restoring` guard policy), Audio #21 (footstep guard decision — gates AC-H7-04 ALLOW exemption policy), Visual/Audio (this GDD's own pending section), HUD #13 (PM signal exposure re-eval). **Each target GDD's H section MUST include the reciprocal AC at authoring time** — this is not a current-PR PASS/FAIL gate.

---

## Visual / Audio Requirements

> **Authorship**: art-director (PRIMARY — character movement = REQUIRED visual category) + audio-director (LIGHT). Consults run 2026-05-10. Source: `design/art/art-bible.md` Sections 1/3/5/9, this GDD Sections B/C/D/E, `time-rewind.md` Visual/Audio + Rule 11.
> **Pillar anchors**: Pillar 1 (학습 도구 — Section VA.3 i-frame visual + restore re-entry visibility), Pillar 5 (출시 가능 우선 — Section VA.6 25-frame asset budget).

### VA.1 Sprite2D facing_direction visualization (resolves C.1.4 + C.6 TBD)

**Decision (locked 2026-05-10): Option C — Modular body + 8-way arm overlay** (Contra-style cutout — pre-committed by art-bible.md Section 5 "총기 몸통 오른쪽에 명확히 돌출 — 8방향 조준 중에도 방향 인식 가능").

| Element | Implementation | Asset class |
|---------|---------------|-------------|
| **Body** | Single E-facing sprite set per state. `Sprite2D.flip_h = (facing_direction in [3, 4, 5])` — W/NW/SW quadrant. Driven by PM code (NOT AnimationPlayer track) | `char_echo_<state>.png` E-facing |
| **Gun arm overlay** | Separate `Sprite2D` child node (sibling of body Sprite2D); 8 directional sprites swapped per `facing_direction` (0..7); pose-to-pose cut, no interpolation (Section 9 Ref 2 cutout aesthetic) | `char_echo_arm_<dir>_01.png` × 8 (reducible to 5 unique + 3 flip) |

**facing_direction → flip_h + arm sprite map:**

| `facing_direction` | Body `flip_h` | Arm sprite |
|---|---|---|
| 0 (E) | false | `char_echo_arm_e_01.png` |
| 1 (NE) | false | `char_echo_arm_ne_01.png` |
| 2 (N) | false | `char_echo_arm_n_01.png` |
| 3 (NW) | **true** | `char_echo_arm_nw_01.png` (or flip of NE) |
| 4 (W) | **true** | `char_echo_arm_w_01.png` (or flip of E) |
| 5 (SW) | **true** | `char_echo_arm_sw_01.png` (or flip of SE) |
| 6 (S) | false (canonical default) | `char_echo_arm_s_01.png` |
| 7 (SE) | false | `char_echo_arm_se_01.png` |

**Implementation owner**: Code-driven swap (PM `_on_facing_changed` → `_arm_sprite.texture = _arm_textures[facing_direction]`). NOT 8 parallel AnimationPlayer tracks. Delegate to `technical-artist` + `godot-gdscript-specialist` for final shape.

### VA.2 State-specific visual feedback (per PlayerMovementSM 6 states)

All ECHO body sprites authored at **60fps** (mandatory — see VA.7 RISK HIGH for Godot 4.6 `seek` precision). Cutout aesthetic per art-bible.md Section 9 Ref 2 — held poses, not tweens. Frame counts are Tier 1 floors.

| State | Frames | Hold pose / notes | Method-track keys |
|-------|--------|-------------------|-------------------|
| **Idle** | 4 (loop) | 1 base lean (E-facing reference frame for `_derive_movement_state` T14 restore target) + 2 weight-shift + 1 return; REWIND Core glow steady `#00F5D4` | none |
| **Run** | 6 (loop) | 2 contact + 2 passing + 2 transition; 45° forward lean (Section 5); cutout angular feet; NO motion blur on sprite (Section 9 Ref 2 forbids) | Frames 1 + 4 = `_on_anim_play_footstep_sfx` (foot-contact) |
| **Jump** | 2 | F1 ascent (knees drawn, REWIND Core silhouette pop) + F2 apex tuck (optional — single held pose acceptable Tier 1) | F1 = `_on_anim_play_jump_sfx` (one-shot launch) |
| **Fall** | 2 | F1 descent + F2 landing-prep (knees flex). Fall must read as committed weight (B.5 anti-fantasy: not floaty 360° control) | none on Fall; landing key on first frame of post-T8/T9 anim |
| **AimLock** | 1 | Static body anchor (no lean — squared/planted); REWIND Core glow brighter (luminosity bump) — signals "charged precision". 8-way arm overlay sweeps independently with `facing_threshold_aim_lock=0.1` | T4 entry → `_on_anim_play_aimlock_press_sfx` |
| **Dead** | 1 (DYING) + 1 (DEAD) | DYING = hit-stagger held pose (NOT collapse) + REWIND Core flicker — held for 12-frame `damage.md` DEC-6 grace; DEAD = transition to 1-frame `#FFFFFF` whiteout (art-bible.md Section 4 — only permitted pure-white use) → scene checkpoint | none — TR owns death audio |

**Cancellation by restore**: If `restore_from_snapshot()` fires during DYING grace, the stagger pose is cut by `seek(animation_time, true)` — no death animation completes. The rewind *cancels* the death, does not *reverse* it (matches B.2 fantasy + C.4.0 metaphor bridge).

### VA.3 Time-rewind cue interaction (PM role boundaries)

| Sub-effect | Owner | PM obligation |
|------------|-------|---------------|
| Cyan-magenta full-screen tear (frames 1–18 of restore) | **System #16 (Time Rewind Visual Shader)** + `time-rewind.md` Rule 11 | PM must NOT set `Sprite2D.modulate` / `self_modulate` color during REWINDING — would contaminate shader's color-inversion pass |
| 30-frame REWINDING i-frame (`HurtBox.monitorable=false`) — **PM-side visual cue** | **PM** (this GDD; flicker added to art-bible.md Section 1 Principle C as Amendment 3) | `Sprite2D.visible` 2:1 toggle (visible=true 2 frames / visible=false 1 frame) for 30 frames. Color-neutral (form signal — survives shader inversion). Driven from `EchoLifecycleSM.RewindingState._physics_update()`, NOT AnimationPlayer (avoids `seek()` interaction). Multi-channel safety per art-bible.md Section 4 backup #4 (form + audio + screen-shake redundancy) |
| Restore re-entry punctuation (the moment `restore_from_snapshot()` fires) | **TR** + screen-shake (art-bible.md Section 4) + `seek(animation_time, true)` snap | **PM owns no punctuation visual** — the frame-accurate snap to pre-death pose is itself the visual signal (B.4 #2 satisfied via 3-channel: tear + shake + pose-snap). Adding a PM-side flash would compete with shader's frame 1–3 inversion peak. VFX #14 (if it exists) may author position-localized burst on `rewind_completed` — that's its scope, not PM's |
| `rewind_completed` audio stinger | **TR + Audio GDD #21** | PM emits no audio during REWINDING — silent (audio-director Section 3 confirmed) |

### VA.4 PM-owned audio events (per state)

`Mix.Player.Movement` bus at -6 dB; ducks fully under TR's `rewind_consume`/`rewind_started` foreground stinger; peer-level with combat SFX. **Mix bus architecture is Audio GDD #21 scope** — this section provides the positioning contract.

| State / event | Trigger | Asset | Character |
|---------------|---------|-------|-----------|
| Idle ambient | none | none | **Silent Tier 1** — combat tension preserved; defer breath loop to Tier 3 if narrative-director requests |
| Run footstep | AnimationPlayer method-track keys at frames 1 + 4 of run loop; alternating L/R via internal `_footstep_side` toggle | `sfx_player_run_footstep_concrete_01..04.ogg` × 4 variants (randomised) | Dry percussive transient ≤100 ms; cutout aesthetic (paper-on-concrete); Tier 1 single surface |
| Jump launch | Method-track on JumpState entry frame (T3) | `sfx_player_jump_launch_01.ogg` × 1 | Synthetic exertion ≤150 ms; pitch-up whoosh / paper-tear; NO vocal grunt (Q5 unresolved) |
| Fall | none | none | Silent — landing cue carries the arc |
| Land impact | Method-track on T8/T9 landing frame (knee-bend impact pose) | `sfx_player_land_impact_01.ogg` × 1 | Heavier dull thud ≤150 ms; Tier 1 single tier (no hard/soft split — defer Tier 2) |
| AimLock press | T4 entry (movement freeze + body anchor snap) | `sfx_player_aimlock_press_01.ogg` × 1 | Mechanical "lock" click ≤80 ms (camera-autofocus reference) |
| AimLock held ambient | none | none | **Silent Tier 1** — visual freeze + crosshair carries held-state communication |
| AimLock 8-way facing change tick | none | none | **Silent Tier 1** — high-frequency stick sweep would produce rattle; visual sufficient |
| DYING / DEAD | **`time-rewind.md` Audio Events table owns** | n/a | DYING = synthwave filter sweep rising (TR); DEAD = silence cut (TR). PM emits zero audio in Dead state |

**Tier 1 PM-owned audio asset count: 7 .ogg files** (4 footstep + 1 jump + 1 land + 1 aim-press). All OGG Vorbis per art-bible.md Section 8 format spec.

### VA.5 Method-track guard policy (resolves GAP-6 from H.7)

Per-callback `_is_restoring` guard decisions, locking the AC-H7-04 ALLOW-PM-GREP-4 exemption matrix:

| Callback | Guard? | ALLOW-PM-GREP-4 justification | Rationale |
|----------|--------|------------------------------|-----------|
| `_on_anim_play_footstep_sfx` | **ALLOW** (opt-out) | `# ALLOW-PM-GREP-4: lightweight SFX, restore-tick double-fire masked by rewind stinger, no state mutation` | Rhythmic transient ≤100 ms; perceptually masked by TR foreground stinger; no state-corrupting side effect |
| `_on_anim_play_landing_sfx` | **ALLOW** (opt-out) | `# ALLOW-PM-GREP-4: lightweight SFX, restore-tick double-fire masked by rewind stinger, no state mutation` | Same as footstep — pure playback, masked under stinger |
| `_on_anim_play_jump_sfx` | **GUARD required** (no opt-out) | n/a | Salient one-shot upward-motion semantic; stale fire during rewind = perceptual contradiction with backward-time visual; pitch-up character could read through stinger |
| `_on_anim_play_aimlock_press_sfx` | **GUARD required** | n/a | Mode-shift confirmation cue; semantic event (not rhythmic) — stale fire = false UI feedback |
| `_on_anim_spawn_bullet` (Player Shooting #7) | **GUARD required** | n/a | C.4.4 mandatory + state-mutation cascade (ammo decrement, projectile entity spawn) |
| `_on_anim_emit_dust_vfx` (VFX #14) | **GUARD recommended** | acceptable for opt-out per VFX GDD | Cosmetic cascade — VFX GDD owns final policy |
| `_on_anim_advance_phase_flag` (Boss Pattern #11) | n/a — not on ECHO tracks | n/a | ECHO never authors phase-flag method-tracks (forbidden — narrative state mutation cannot be safely re-fired) |

**Forbidden on PM tracks**: One-shot story flag setters (`_on_anim_trigger_lore_unlock`, `_on_anim_complete_tutorial_step`). Tier 1 has none; Tier 2+ would require both `_is_restoring` guard AND idempotency check.

### VA.6 Tier 1 asset list summary

**ECHO Body sprites (E-facing; W via runtime flip_h):**

| Animation | Frames |
|-----------|--------|
| `char_echo_idle` | 4 (loop) |
| `char_echo_run` | 6 (loop) |
| `char_echo_jump` | 2 |
| `char_echo_fall` | 2 |
| `char_echo_aimlockbody` | 1 |
| `char_echo_dying` | 1 (held 12 frames) |
| `char_echo_dead` | 1 (pre-whiteout) |
| **Subtotal** | **17 frames** |

**ECHO Gun-arm overlay**: 8 directional sprites (5 unique + 3 flip-mirrors if gun art is symmetric).

| Asset class | Count | Pixel area (48×96 body / 32×32 arm) |
|-------------|-------|-------------------------------------|
| Body frames | 17 | ~78,336 px |
| Arm frames | 8 | ~8,192 px |
| **Total ECHO** | **25 frames** | **~86 K px uncompressed** (fits 512×512 `atlas_chars_tier1.png` per art-bible.md Section 8) |

**Audio**: 7 OGG files (Section VA.4). Effort estimate (solo, placeholder pixel art OK per Pillar 5): **4–6 day art task** within Tier 1 4–6 week window — within art-bible.md Section 8 budget ("Tier 1 에셋 총량 4-6주 안에 솔로 생산 가능").

**Color palette references** (art-bible.md Section 4 swatches; v0 — confirm at first concept-art round):

| Element | Color | Hex |
|---------|-------|-----|
| Lineart / outline | Black ink stroke (2-4 px) | per Section 6 Layer 2 |
| REWIND Core glow (steady) | Neon Cyan | `#00F5D4` |
| REWIND Core glow (REWINDING / AimLock luminosity) | Rewind Cyan | `#7FFFEE` |
| Body suit base | Concrete Dark | `#1A1A1E` |
| Body suit mid-tone | Concrete Mid | `#3C3C44` |
| Helmet/mask accent | Neon Cyan | `#00F5D4` |
| DEAD whiteout | Pure White | `#FFFFFF` (single permitted use per Section 4) |

### VA.7 Engine constraints + risk flags

| # | Risk | Severity | Detail |
|---|------|----------|--------|
| R-VA-1 | `AnimationPlayer.seek(time, true)` on looping anim in Godot 4.6 | **HIGH** — post-cutoff API; OQ-PM-2 + `time-rewind.md` OQ-9 | Tier 1 prototype MUST verify before idle/run frame authoring is finalised. Looping seek may have unexpected behaviour (loop counter reset, loop-end callback fire, drift). If broken, idle + run animations have restore artifacts. |
| R-VA-2 | `Sprite2D.visible` toggle vs `self_modulate.a` for i-frame flicker | **MEDIUM** | `visible=false` removes node from draw list → batching-friendly (preserves ≤500 draw call budget per art-bible.md Section 8). `self_modulate.a` translucent path may break Forward+ batching. Lock `visible` toggle as the implementation. |
| R-VA-3 | REWIND Core `#00F5D4` inverts to ~`#FF0A2B` (magenta-red) during shader inversion frames 1–3 | **LOW** (aesthetically intentional) | Player-identification color appears to invert during peak inversion — semantically correct (reinforces inversion metaphor); do NOT shader-protect the cyan. |
| R-VA-4 | `Sprite2D` + AnimationPlayer (NOT `AnimatedSprite2D`) — pipeline lock | **LOW** | C.1.2 specifies `Sprite2D` driven by AnimationPlayer; `AnimatedSprite2D` has different `seek` API, breaks `restore_from_snapshot()`. Animator pipeline mandate: all ECHO sprites authored as AnimationPlayer-driven Sprite2D frame sequences. |
| R-VA-5 | `TextureFilter.NEAREST` on all character sprites | **LOW** | Standard project filter (art-bible.md Section 8). 48×96 sprites at 1:1 1080p are correctly served by NEAREST. |

### VA.8 Art bible amendment flags (deferred F.4.2 obligations)

art-director consult identified 4 amendments needed in `design/art/art-bible.md`. **NOT applied this session — flagged for separate `/quick-design` art-bible amendment pass**:

| # | Section | Amendment |
|---|---------|-----------|
| ABA-1 | Section 3 | Clarify ECHO sprite size: "캐릭터 시각 높이 48px; 스프라이트 셀 48×96px (REWIND Core 등 돌출부 포함 셀 공간)." |
| ABA-2 | Section 5 (ECHO) | Add: "facing_direction 시각화 = flip_h 몸체 + 8방향 팔 오버레이 (Option C — System #6 Visual/Audio 2026-05-10 결정)." |
| ABA-3 | Section 1 Principle C | Add: "REWINDING 30프레임 i-frame 시각 = `Sprite2D.visible` 2:1 flicker (PM 소유, 색 신호 아님 — 색 반전 중에도 식별 가능)." |
| ABA-4 | Section 2 Mood Table | Add row "DYING (피격 후 12프레임 유예)": emotional target "긴박한 반전 기대"; visual: "히트-스태거 포즈 유지 + REWIND Core 깜박임; 화이트아웃 없음." |

> **📌 Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved (ABA-1..4 amendments applied), run `/asset-spec system:player-movement` to produce per-asset visual descriptions, dimensions, and AI generation prompts for the 25 sprite frames + 7 audio files from this section.

---

## UI Requirements

**Tier 1 PM-owned UI: NONE.**

PlayerMovement does not author HUD elements, menus, dialogs, or any `Control` / `CanvasLayer` content in Tier 1. The system contributes *data* (velocity, facing_direction, is_grounded, current_weapon_id) and *state events* (`PlayerMovementSM.state_changed`, `EchoLifecycleSM.state_changed`) that other systems may consume for UI purposes, but PM does not host or render any UI surface.

| HUD/UI element candidate | Owner GDD | PM contribution |
|--------------------------|-----------|-----------------|
| Time-rewind token count | **HUD #13** *(provisional)* | None — `time-rewind.md` Token State authority owns; PM agnostic to token economy (DEC-PM-3) |
| Boss phase indicator | **HUD #13** *(provisional)* | None — Boss Pattern #11 owns |
| Health bar | Likely none (binary 1-hit lethal — `damage.md` DEC-3); if added Tier 2+, **HUD #13** owns | None |
| Aim crosshair (8-way during AimLock) | **TBD** — likely Player Shooting #7 or HUD #13 | PM exposes `facing_direction` 0..7 enum (D.4) as read-only property; consumer renders crosshair |
| Damage flash / hit indicator | `damage.md` Visual/Audio + system #16 shader | None — full-screen effect, not PM-local |
| i-frame visual cue | **PM** (Section VA.3 — `Sprite2D.visible` 2:1 flicker) | This IS PM's responsibility; documented in VA.3, not a HUD element (it's character sprite visibility, NOT a Control node overlay) |
| Pause menu / settings / weapon swap UI | UI Systems (likely separate GDD) + Input #1 | None — PM's `pause` action is read by `EchoLifecycleSM`, not PM (C.5.1) |

**F.4.2 obligation reminder**: HUD #13 GDD authoring (Tier 2) must re-evaluate whether PlayerMovement should expose any signal for UI consumption (e.g., `landed(impact_force)` for screen-shake on hard landings). Tier 1 decision: no PM signals (F.3 — relies on PlayerMovementSM `state_changed` from framework + `EchoLifecycleSM.state_changed`).

**Accessibility note** (for future Accessibility GDD coordination): PM-owned visual feedback (i-frame flicker, REWIND Core glow brightening during AimLock) uses **form + color** redundancy per `art-bible.md` Section 4 backup safety #4. The flicker (form-based) survives colorblind-mode shader transformations; the cyan luminosity bump (color-based) is the supplementary signal. Multi-channel design satisfies WCAG-style information redundancy without PM-side UI work in Tier 1.

---

## Z. Open Questions

본 표는 GDD 작성 도중 후속 GDD / ADR / 프로토타입 단계로 이월된 미해소 결정의 단일 출처다. 각 항목은 *closure trigger*가 발생하면 해당 GDD의 *F.4.2 의무 표*에서 갱신 처리된다.

| OQ ID | 질문 | Owner / Resolver | Closure trigger | 우선순위 | 비고 |
|-------|------|-----------------|-----------------|---------|------|
| **OQ-PM-1** | `_last_grounded_frame` / `_jump_buffered_at_frame` 카운터를 `scene_will_change` 시점에 클리어할 책임자 (PM `_ready()` reconnect vs EchoLifecycleSM scene reset cascade vs Scene Manager direct call) | **Scene Manager #2 GDD** | Scene Manager #2 GDD 작성 시 (F.4.2 obligation) | MEDIUM (Tier 2 다중 스테이지 도입 시 hot bug 후보) | 임시: Tier 1 단일 스테이지에서는 `restore_from_snapshot()` Step 4의 `INT_MIN` 클리어로 충분 |
| **OQ-PM-2** | Godot 4.6 `AnimationPlayer.seek(time, true)` looping animation 호환성 — `time-rewind.md` OQ-9 + 본 GDD R-VA-1과 동일 의존 | **Tier 1 prototype** (gameplay-programmer + technical-artist) | Tier 1 ring buffer 프로토타입에서 idle/run looping anim에 대해 60fps capture + restore 1000-cycle 결정성 검증 | **HIGH** (loop counter reset / loop-end callback fire / seek drift 셋 중 하나라도 발생하면 idle/run 프레임 작업 차단) | art-director 권고: Tier 1 art 작업 *전*에 검증 |
| **OQ-PM-3** | E-PM-2 derive policy *empirical falsification* — `is_grounded=true AND velocity.y<0` pathological snapshot의 1-tick 자동 정정 (Idle/Run → next-tick T5 → Fall) 시각적 artifact 허용 가능? | **Tier 1 prototype** | dev/test fixture로 pathological snap 인젝션 + 시각 검증 | LOW | GAP-1 Decision A 2026-05-10 *is_grounded wins* 락인. Empirically broken 시 Round 5 cross-doc-contradiction exception으로 derive 분기 추가 (option C dev assert) 재평가 |
| **OQ-PM-4** | `Mix.Player.Movement` bus 명명 + 압축/리미터 체인 + ducking automation script | **Audio GDD #21** | Audio #21 작성 시 (F.4.2 obligation) | LOW | 본 GDD VA.4 mix priority 문장만 정의; 실제 bus implementation Audio가 소유 |
| **OQ-PM-5** | 8-way 팔 오버레이 비대칭 무기 art (예: 좌우 비대칭 총기 디테일) — flip mirror 5 unique + 3 mirrors 충분? 아니면 8 unique 강제? | **First concept-art round** (art-director) | 1차 컨셉 아트 round | MEDIUM | art-director 권고: 1차 라운드에서 art 단순도 확정 후 lock |
| **OQ-PM-6** | `art-bible.md` ABA-1 (sprite size 명시), ABA-2 (8-way 시각화 spec), ABA-3 (i-frame flicker rule), ABA-4 (DYING mood-table row) — 4 amendment 적용 | **art-bible amendment pass** (art-director — `/quick-design art-bible` 또는 직접 edit) | art-bible.md 4 amendment landed | MEDIUM | 본 GDD Visual/Audio Section VA.8 단일 출처 |
| **OQ-PM-7** | E-PM-9 deadzone 0.2 — Input System #1 GDD가 enforce하기 *전*까지 Tier 1 prototype에서 noise drift 발생 시 임시 PM-side guard 추가 여부 | **Input System #1 GDD** | Input #1 GDD 작성 시 (F.4.2 obligation) | LOW | Tier 1 임시: `project.godot` `deadzone = 0.2` 직접 설정으로 충분 |
| **OQ-PM-8** | `_on_anim_emit_dust_vfx` (VFX #14) `_is_restoring` 가드 정책 (RECOMMENDED vs ALLOW exemption) | **VFX #14 GDD** | VFX #14 GDD 작성 시 (F.4.2 obligation) | LOW | 본 GDD VA.5 = "GUARD recommended"로 잠정 lock; 최종 결정 VFX GDD 소유 |
| **OQ-PM-9** | Tier 2 게이트 — DEC-PM-1 reconsideration 트리거 (dash / double_jump / wall_grip / hit_stun / knockback) 발화 시점 | **개별 Tier 2 GDD amendment** | (a) `damage.md` DEC-3 binary lethal 변경 시 OR (b) Boss Pattern #11 knockback 도입 시 OR (c) Pillar 5 통과 시점 | LOW | G.3 Future Knobs 표가 trigger 단일 출처 |

### Resolved during authoring (참고 — 미오픈 차단)

| Resolved-OQ | 해결 위치 | Decision |
|-------------|----------|----------|
| ~~OQ-1~~ AimLock floor-loss 자동 해제 | C.2.2 T12 + AimLockState definition | aim_lock 입력 hold 무관 자동 해제 (T12); 다음 grounded tick 자연 재진입 (E-PM-7) |
| ~~OQ-2~~ Outside aim_lock에서 `move_axis.y` 의미 | C.2.2 + D.4 | facing_direction composite 8-way 갱신용 (movement 영향 없음 — Run/Jump/Fall 동안 좌우 이동 + 위/아래/대각선 조준 가능) |
| ~~OQ-3~~ AimLock 진입 grounded 가드 | C.2.2 T4 condition | grounded only — aim_lock pressed in air 무시 (DEC-PM-2 hold semantics) |
| ~~OQ-4~~ Variable jump cut policy | D.2 Formula 5 + AC-H5-02 | Celeste cut: `velocity.y = max(velocity.y, -jump_cut_velocity)` (Tier 1 = 160 px/s) |
| ~~GAP-1~~ E-PM-2 derive policy | AC-H1-06 + GAP-1 Decision A 2026-05-10 | is_grounded wins → Idle/Run; 1-tick 자동 정정 |
| ~~GAP-3~~ `process_physics_priority` enforce | AC-H3-03 + GAP-3 Decision A 2026-05-10 | .tscn grep + 런타임 GUT 양방향 belt-and-suspenders |
| ~~GAP-6~~ H7-04 footstep guard 정책 | VA.5 + GAP-6 Decision A 2026-05-10 | 보편 가드 + ALLOW-PM-GREP-4 per-callback 예외 (footstep/landing ALLOW; jump/aim_lock_press GUARD) |
| ~~Decision A (Visual/Audio)~~ Sprite2D facing 시각화 | VA.1 | Option C — flip_h body + 8-way arm overlay |
| ~~Decision G-A~~ Tuning storage | G.1 | Single `PlayerMovementTuning` Resource (.tres) |
| ~~Decision G-C~~ G.4 enforcement | G.4 | 3-layer (assert + grep + GUT) |

---

## Appendix: References

### A.1 Locked Decisions in this GDD (single source)

| ID | Section | Date | Summary |
|----|---------|------|---------|
| DEC-PM-1 | Locked Scope Decisions (top of file) | 2026-05-10 | Tier 1 PlayerMovementSM = 6 states (`idle/run/jump/fall/aim_lock/dead`); `hit_stun` removed (damage.md DEC-3 binary lethal); dash/double_jump/wall_grip Tier 2 |
| DEC-PM-2 | Locked Scope Decisions | 2026-05-10 | `aim_lock` = hold-button Cuphead-style (movement freeze + free 8-way aim); independent of `shoot` (jump+shoot 동시 fantasy 보존); Input #1 owns final action naming |
| DEC-PM-3 | Locked Scope Decisions | 2026-05-10 | Time-rewind restore ammo policy = "resume with live ammo"; PlayerSnapshot does NOT capture ammo; Player Shooting #7 owns ammo state |
| Decision A (jump height) | D.2 (note above Formula 1) | 2026-05-10 | `jump_velocity_initial=480`, `gravity_rising=800` → `jump_height_max_px=144` exact (gameplay-programmer 144 px target preserved) |
| Decision B (facing encoding) | D.4 (note above Formula 1) | 2026-05-10 | `facing_direction: int` 0..7 enum CCW from East; `_FACING_TABLE` 9-entry LUT; `(0,0)→-1` preserve sentinel internal-only |
| Decision G-A | G.1 (Storage policy) | 2026-05-10 | All 13 owned numeric knobs in `PlayerMovementTuning extends Resource`; structural constants stay `const` in script |
| Decision G-C | G.4 | 2026-05-10 | 3-layer enforcement (assert INV-1..7 + static grep GREP-PM-1..7 + GUT H.7) — `damage.md` AC-21/29 precedent |
| GAP-1 (E-PM-2 derive) | H.1 AC-H1-06 | 2026-05-10 | Pathological `is_grounded=true AND velocity.y<0` snapshot → is_grounded wins; 1-tick auto-correct via T5 |
| GAP-3 (priority enforce) | H.3 AC-H3-03 | 2026-05-10 | `.tscn` grep + runtime GUT belt-and-suspenders for `process_physics_priority=0` Inspector-set obligation |
| GAP-6 (H7-04 guard policy) | H.7 AC-H7-04 + VA.5 | 2026-05-10 | Universal `_is_restoring` guard + per-callback `# ALLOW-PM-GREP-4` opt-out (footstep/landing ALLOW; jump/aim_lock_press/spawn_bullet GUARD) |
| Decision (Visual/Audio Option C) | VA.1 | 2026-05-10 | Sprite2D facing visualization = flip_h body + 8-way arm overlay (Contra-style modular cutout) |
| AC count target | H section preamble | 2026-05-10 | 34 AC total (28 BLOCKING + 6 ADVISORY); collapse plan: H.5 coyote+buffer compound, H.8 doc-state compound |

### A.2 Cross-doc citations (read for full context)

| Document | Sections cited | Relationship |
|----------|---------------|--------------|
| `design/gdd/game-concept.md` | Pillars 1, 2, 5 | Pillar service matrix (B.6) anchors all decisions |
| `design/gdd/systems-index.md` | System #6 row | Status: `Designed (2026-05-10)` Session 9 update |
| `design/gdd/time-rewind.md` | Rule 4 (12-frame grace), Rule 9 (`rewind_completed` signature), Rule 11 (REWINDING 30 frames i-frame), Rule 12 (Player-only checkpoint scope), Rule 17 (Primary Damage step 0 + Secondary SM latch), Visual/Audio (cyan-magenta tear), I4 (`seek(time, true)` 강제 즉시 평가), Audio Events table (DYING/DEAD owns), F.1 row #6 (TR-PM contract); F.4.1 #1 reciprocal applied Session 9; AC-A4/D5/F1/F2 mirror obligations | **Hard upstream + downstream** (highest dependency); 4 mirror AC pairs |
| `design/gdd/state-machine.md` | C.1 (signal contract), C.2.1 (framework definitions + line 178-188 node tree per Round 5 cross-doc-contradiction exception), C.2.2 (host obligations), C.2.5 (`_lethal_hit_latched` secondary), C.3.4 (`call_deferred` connect best practice), AC-07 (queue atomicity), AC-09 (force_re_enter), AC-15 (DYING→DEAD direct path), AC-23 (3-machine M2 reuse integration); F.4.1 #2 + #3 reciprocals applied Session 9 | **Hard upstream** (framework + host obligations); 3 mirror AC |
| `design/gdd/damage.md` | C.1.1/C.1.2 (HurtBox/HitBox composition), C.3.2 step 0 (first-hit lock primary guard — Round 5 fix 2026-05-10), C.6.4/C.6.5 (priority ladder + frame-N invariant), DEC-3 (binary 1-hit lethal), DEC-4 (`HurtBox.monitorable` SM-owned single-direction), DEC-6 (12-frame hazard grace + 1 priority compensation), AC-9 (DYING latch), AC-12 (REWINDING monitorable=false), AC-20 (Rewinding enter/exit toggle), AC-21 (grep regex CI precedent), AC-29 (1000-cycle determinism), AC-36 (first-hit lock GUT); F.4.1 #4 reciprocal applied Session 9 | **Hard upstream** (composition only — no direct subscribe); 5 mirror AC |
| `design/art/art-bible.md` | Section 1 Principle A (Clarity-First Collage 0.2s glance test), Principle C (REWIND inversion + glitch), Section 2 Mood Table (DYING/DEAD), Section 3 (ECHO Silhouette 48px + dorsal REWIND Core), Section 4 (Color Palette — Neon Cyan `#00F5D4` / Rewind Cyan `#7FFFEE` / Concrete Dark `#1A1A1E` / Concrete Mid `#3C3C44`; backup safety #4 multi-channel), Section 5 (ECHO 8-way arm protrusion design), Section 6 (lineart layer 검은 stroke 2-4 px), Section 8 (`atlas_chars_tier1.png` 512×512 NEAREST PNG OGG; ≤500 draw calls), Section 9 Ref 2 (Monty Python cutout) + Ref 4 (Cuphead frame economy) | **Visual single-source**; 4 amendment flags (ABA-1..4 — `art-director` consult 2026-05-10) |
| `docs/architecture/adr-0001-time-rewind-scope.md` | R-T1 Player-only checkpoint | Lock for `restore_from_snapshot()` scope (PM 7 fields only — no world rewind) |
| `docs/architecture/adr-0002-time-rewind-storage-format.md` | R-T2 State Snapshot ring buffer (90 PlayerSnapshot, write-into-place) + Amendment 1 (lethal-hit head freeze + `captured_at_physics_frame` 8th field) | 7-field schema lock — DEC-PM-3 ammo exclusion compatible (no Amendment 2 needed) |
| `docs/architecture/adr-0003-determinism-strategy.md` | R-T3 `CharacterBody2D` + 직접 transform (no RigidBody2D); `Engine.get_physics_frames()` clock; `process_physics_priority` ladder PM=0, TRC=1, enemies=10 | C.1.1, C.3.1, C.3.2, D.3 sentinel reset 핵심 의존 |
| `docs/registry/architecture.yaml` | `state_ownership.player_movement_state`, `interfaces.player_movement_snapshot`, `forbidden_patterns.delta_accumulator_in_movement`, `api_decisions.facing_direction_encoding` (4 entries Session 9 등록) | F.4.1 #6 reciprocal landed; AC-H8-01 grep verifier |
| `.claude/docs/coding-standards.md` | Test Evidence by Story Type (Logic/Integration/Visual/UI/Config-Data); Automated Test Rules (determinism + isolation + no hardcoded data); CI/CD Rules (Godot headless GUT4 runner) | H.1-H.8 AC test type tagging 정합 |
| `.claude/docs/technical-preferences.md` | Engine pin (Godot 4.6 / GDScript / Forward+ / Godot Physics 2D); 60fps 16.6ms budget; ≤500 draw calls; 1.5 GB memory ceiling; Steam Deck verified target | VA.7 R-VA-1..R-VA-5 risk flags 정합 |

### A.3 Reference games (B.3 Reference Lineage — full citation)

| Game | Year | Mechanic borrowed | Echo distinction |
|------|------|-------------------|-----------------|
| **Celeste** (Maddy Thorson / Noel Berry) | 2018 | Coyote time + jump buffer 6 frames; variable jump cut policy; jump weight feel | Death = scene reset (Celeste) vs body reset world preserved (Echo) |
| **Katana Zero** (Justin Stander / Askiisoft) | 2019 | Time mechanic + 1-hit + instant restart solo standard | Predict-then-replay (Katana Zero) vs remember-then-reenter (Echo); ex-ante vs ex-post |
| **Hotline Miami** (Dennaton Games) | 2012 | Instant restart + deterministic patterns + "unfair" avoidance | Top-down scene reset (HM) vs side-scroll continuous body (Echo) — input never breaks |
| **Contra** (Konami; series) | 1987–2024 | Side-scroll + 8-way shooting + 1-hit lethal kinematic template; modular character (gun overlay) | Contra has slight momentum jitter; Echo has 0 jitter (Pillar 2 + ADR-0003) |
| **Cuphead** (StudioMDHR) | 2017 | Reduced frame count + maximum expressiveness; cutout marketing-screenshot aesthetic | art-bible.md Section 9 Ref 4 (Tier 1 frame economy direct lineage) |

### A.4 External technical references

| Reference | Source | Used for |
|-----------|--------|----------|
| Godot 4.6 release notes (2026-01) | `https://godotengine.org/releases/4.6/` | Engine pin verification (R-VA-1 risk flag context) |
| Godot 4.5 → 4.6 migration guide | `https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html` | Forward+ default + Jolt 3D default (2D unaffected); Inspector-set property semantics |
| Maddy Thorson — "Celeste & Forgiveness" (GDC 2019 / Celeste devlog series) | published Celeste post-mortem articles | 6-frame coyote + 6-frame buffer industry-standard reference (D.3 Tier 1 default justification) |
| `damage.md` AC-21 grep CI precedent | this repo | H.7 AC-H7-03/04 pattern + `tools/ci/pm_static_check.sh` template |
| `damage.md` AC-29 1000-cycle determinism | this repo | H.3 AC-H3-01 + H.7 AC-H7-05 fixture pattern (run-1 self-capture forbidden) |

### A.5 Specialist consult log (this GDD authoring sessions)

| Session | Date | Specialists consulted | Sections produced |
|---------|------|----------------------|-------------------|
| Session 7 | 2026-05-09 | game-designer, gameplay-programmer, godot-gdscript-specialist (parallel) — A/B framing | A. Overview + B. Player Fantasy + Locked Scope Decisions DEC-PM-1/2/3 |
| Session 8 | 2026-05-10 | game-designer + gameplay-programmer + godot-gdscript-specialist (parallel for C); systems-designer (D); advisor (Phase 4 unbounded-accumulator post-write fix) | C.1–C.6 (Detailed Design) + D.1–D.4 (Formulas) + E (17 edge cases) + F.1–F.4 (Dependencies) |
| Session 9 | 2026-05-10 | advisor (pre-write blocker on `facing_direction_encoding` verification) | F.4.1 6 cross-doc reciprocal edits batch (time-rewind.md F.1, state-machine.md F.2 + C.2.1 + F.4 line 870, damage.md F.1, systems-index.md System #6 + Last Updated + Progress Tracker, architecture.yaml 4 new entries) |
| **Session 10** | **2026-05-10** | **systems-designer (light, G framing); qa-lead (MANDATORY for H, 37→34 AC validation + 7 GAPs surfaced); art-director (MANDATORY for Visual/Audio, Option C lock + 4 art-bible amendment flags); audio-director (LIGHT for Visual/Audio, per-callback guard policy locking AC-H7-04)** | **G.1–G.4 (Tuning Knobs) + H.1–H.8 (34 AC) + Visual/Audio Requirements + UI Requirements + Z. Open Questions + Appendix: References** |

### A.6 Round 5 cross-doc-contradiction exception log

본 GDD가 작성 도중 invoke한 Round 5 exception 1건 — `state-machine.md` C.2.1 lines 178-188 노드 트리 정정 (F.4.1 #3): A.Overview에서 lock된 `PlayerMovement extends CharacterBody2D` root 모델 권위로 state-machine.md의 `ECHO (CharacterBody2D)` + `PlayerMovement (Node)` 분리 표기를 통합 정정. Surgical edit, 디자인 공간 재오픈 없음. Session 9에 적용 완료.

### A.7 Status header (top of file) — 갱신 후보 (Session 11 housekeeping)

> *현재 Status header (line 3)는 "In Design"으로 남아있음. Phase 5d 후속 housekeeping에서 본 GDD 완료 시 다음으로 갱신 권장*:
>
> ```
> > **Status**: Designed (2026-05-10) — pending fresh-session `/design-review`
> > **Creative Director Review (CD-GDD-ALIGN)**: Skipped — Lean mode (per `production/review-mode.txt`)
> ```

### A.8 Recommended next actions (post-completion)

1. **Fresh-session `/design-review design/gdd/player-movement.md`** — independent validation of all 8 sections + 34 AC + cross-doc consistency. NEVER run inline per skill protocol.
2. **`/consistency-check`** — verify no value conflicts across the now-4 designed system GDDs (#5/#6/#8/#9).
3. **Session 11 housekeeping**: Status header update (A.7 above) + commit Session 8/9/10 combined (recommended commit message in `production/session-state/active.md` Session 9 close-out).
4. **Tier 1 prototype OQ-PM-2 unblocking** — `seek(time, true)` looping anim verification BEFORE idle/run frame authoring (R-VA-1 HIGH risk).
5. **`/quick-design art-bible`** — apply 4 amendments ABA-1..4 (Section VA.8) to `design/art/art-bible.md`.
6. **Next system**: per recommended design order, candidates are Input #1 (resolves OQ-PM-7 + AimLock-jump exclusivity), Scene Manager #2 (resolves OQ-PM-1), Player Shooting #7 (resolves WeaponSlot signal contract + `_on_anim_spawn_bullet` policy), or HUD #13 (Tier 1 token UI).
