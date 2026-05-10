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

### C.5 Input Contract (Provisional pending Input System #1)

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

#### C.5.3 Provisional flag

Input System #1 GDD 정식화 시 다음 4 항목 의무:
- `aim_lock` action 명명 confirm (DEC-PM-2 표기 그대로 사용 권장)
- `move_left/right/up/down` 4개 분리 vs `move_horizontal/vertical` 2 axis 결정
- 게임패드 stick deadzone 0.2 (Tier 1 default; G.1 tunable)
- KB+M 기본 키 (`A/D/W/S` move, `Space` jump, `Shift` aim_lock 추정)

본 표는 Input System #1 GDD 작성 후 *위 4 항목만* 정정 가능 (Round 5 cross-doc-contradiction exception 시).

### C.6 Interactions With Other Systems

본 표는 PlayerMovement가 다른 시스템과 데이터·시그널·메서드 호출을 어떻게 주고받는가의 단일 출처다. F.1-F.4가 양방향 정합성(referenced_by) 책임을 진다.

| 대상 시스템 | 방향 | Wiring 패턴 | 금지 alternatives |
|---|---|---|---|
| **TimeRewindController (#9)** | TRC가 매 tick PM 7-필드 read; REWINDING 시 `restore_from_snapshot(snap)` invoke | TRC 측 `@export var player: PlayerMovement` (declarative; missing-ref editor-visible) | `get_parent()` / autoload lookup / `find_node()` / scene-tree group lookup |
| **EchoLifecycleSM (#5)** | EchoLifecycleSM `state_changed` signal → PM `_on_lifecycle_state_changed`. DYING/DEAD 시 PlayerMovementSM force-transition to DeadState (T13). ALIVE 시 no-op | Signal-reactive: `_lifecycle_sm.state_changed.connect(_on_lifecycle_state_changed)` in PM `_ready()`. **call_deferred로 connect 권장** (state-machine.md C.3.4 — scene-tree-order race 회피) | PM polling `_lifecycle_sm.current_state` per tick (`cross_entity_sm_transition_call` forbidden_pattern 위반) |
| **Damage (#8)** | PM이 HurtBox + HitBox + Damage 노드 *호스팅만*. Damage 컴포넌트가 자체 wiring 소유. PM은 간접 — Damage emit `lethal_hit_detected`는 EchoLifecycleSM이 구독 (PM 직접 구독 금지) | Composition: `.tscn`에 자식 노드 인스턴스화. PM `_ready()`은 Damage 노드에 *touch 안 함* | PM이 `Damage.player_hit_lethal` / `lethal_hit_detected` 직접 구독 (C.2.3 forbidden); PM이 `HurtBox.monitorable` write (DEC-4 enforce site 위반) |
| **Input System #1** | PM이 `Input.is_action_*` polling per tick (`_physics_process` Phase 2 only) | `Input.is_action_pressed` / `is_action_just_pressed` / `get_vector` 직접 호출 | `_unhandled_input` / `_input` callback에 movement 로직 binding (latency + 시점 mismatch); InputEvent emit 구독 |
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

[To be designed]

### G.2 Imported Knobs (referenced from other GDDs)

[To be designed]

### G.3 Future Knobs (Tier 2+)

[To be designed]

### G.4 Safety / Forbidden Mutations

[To be designed]

---

## H. Acceptance Criteria

### H.1 Snapshot Restoration (TR contract)

[To be designed]

### H.2 Movement State Machine (PlayerMovementSM)

[To be designed]

### H.3 Per-Tick Determinism

[To be designed]

### H.4 Input → Velocity Mapping

[To be designed]

### H.5 Jump / Gravity / Coyote / Buffer

[To be designed]

### H.6 Damage / SM Integration

[To be designed]

### H.7 Static Analysis & Forbidden Patterns

[To be designed]

### H.8 Bidirectional Update Verification

[To be designed]

---

## Visual / Audio Requirements

[To be designed]

---

## UI Requirements

[To be designed]

---

## Z. Open Questions

[To be designed]

---

## Appendix: References

[To be designed]
