---
title: Run and Gun Player Character Architecture
tags: [concept, run-and-gun, player, FSM, movement, godot, implementation]
aliases: [런앤건 플레이어 캐릭터 구조]
cssclasses: []
created: 2026-05-12
updated: 2026-05-12
---

# Run and Gun Player Character Architecture

런앤건 플레이어 캐릭터 구현의 핵심 아키텍처: 이중 레이어 FSM + 코요테 타임 + 점프 버퍼 + 애니메이션 블렌드. Godot 4.6 GDScript 직접 적용.

---

## 핵심 원칙: 이동과 액션의 직교 분리

런앤건 플레이어는 이동과 공격을 **항상 동시에** 수행한다.
단일 상태 머신으로 구현하면 `IDLE_SHOOTING`, `WALK_SHOOTING`, `JUMP_SHOOTING` 등의 조합 폭발이 발생.

**해법: 두 독립 레이어를 병렬로 실행**

```
레이어 1 — 이동 (Locomotion, 상호 배타):
  IDLE | WALK | RUN | JUMP | FALL | LAND | CROUCH | SLIDE

레이어 2 — 액션 (Action, 이동과 동시):
  NOT_SHOOTING | SHOOTING | RELOADING | MELEE
```

매 프레임: 이동 레이어 먼저 해결 → 액션 레이어 오버레이.

---

## 핵심 이동 패턴

### 코요테 타임 (Coyote Time)

**신뢰도: HIGH** — 현대 2D 플랫포머 표준

- 정의: 플랫폼 가장자리에서 걸어 나간 후 N 프레임 동안 점프 허용
- 권장값: **6-12 프레임** (0.1-0.2 s @ 60 fps)

```gdscript
var time_since_grounded: float = 0.0
const COYOTE_TIME := 0.15  # 초

func _physics_process(delta: float) -> void:
    if is_on_floor():
        time_since_grounded = 0.0
    else:
        time_since_grounded += delta
    
    var can_jump := is_on_floor() or time_since_grounded < COYOTE_TIME
    if Input.is_action_just_pressed("jump") and can_jump:
        velocity.y = JUMP_VELOCITY
```

---

### 점프 버퍼 (Jump Buffering)

**신뢰도: HIGH**

- 정의: 착지 N 프레임 전에 점프 입력 시 착지 첫 프레임에 자동 점프
- 권장값: **8-12 프레임** (0.13-0.2 s @ 60 fps)

```gdscript
var jump_buffer_timer: float = 0.0
const JUMP_BUFFER_TIME := 0.17

func _physics_process(delta: float) -> void:
    if Input.is_action_just_pressed("jump"):
        jump_buffer_timer = JUMP_BUFFER_TIME
    else:
        jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
    
    if is_on_floor() and jump_buffer_timer > 0.0:
        velocity.y = JUMP_VELOCITY
        jump_buffer_timer = 0.0
```

---

### 가변 점프 높이 (Variable Jump Height)

**신뢰도: HIGH**

- 점프 버튼 조기 해제 시 추가 중력 배율 적용 → 탭 = 짧은 점프, 홀드 = 높은 점프

```gdscript
const FALL_MULTIPLIER := 2.5

func _physics_process(delta: float) -> void:
    if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
        velocity.y += FALL_MULTIPLIER * ProjectSettings.get_setting("physics/2d/default_gravity") * delta
```

---

### 이동 중 슈팅 (Shoot While Moving)

**신뢰도: HIGH** — 장르 정의 메카닉 (Slynyrd 픽셀아트 블로그 확인)

**규칙**: 슈팅 입력은 이동 입력을 절대 취소하지 않는다. 항상 동시.

**애니메이션**: `AnimationTree` + `AnimationNodeBlendTree` 사용:
- 하체: 이동 레이어 (IDLE/WALK/RUN/JUMP/FALL)
- 상체: 슈팅 오버레이 (`shoot: bool` 파라미터)

```
AnimationTree
└── BlendTree
    ├── LocomotionStateMachine (lower body)
    │   ├── idle_anim
    │   ├── walk_anim
    │   └── jump_anim
    └── ShootBlend (upper body blend, 0.0~1.0)
        ├── [normal] → locomotion output
        └── [shoot] → shoot variant frames
```

**Slynyrd 노트**: 모든 이동 애니메이션(idle/walk/run/jump/fall)에 "슈팅 오버레이 변형" 프레임 필요. 점프 슈팅은 최소 1프레임.

---

## 이동 레이어 전환 규칙

| 현재 → 다음 | 조건 |
|---|---|
| IDLE → WALK | `velocity.x > 0.1` |
| WALK → RUN | 속도가 run 임계값 초과 후 N 프레임 유지 |
| WALK/RUN → JUMP | `jump` 입력 + `can_jump` 참 |
| JUMP → FALL | `velocity.y > 0` (정점 통과) |
| FALL → LAND | `is_on_floor()` 감지 |
| LAND → IDLE/WALK | N 프레임 착지 회복 애니메이션 완료 |

**핵심 제약**:
- 모든 이동 상태에서 공격 허용 (잠금 없음)
- 8방향 조준은 모든 이동 상태에서 유효
- 코요테 타임·점프 버퍼는 상태 전환 소비보다 먼저 체크

---

## 노드 구조 (Godot 4 권장)

```
Player (CharacterBody2D)
├── Sprite2D (or AnimatedSprite2D)
├── AnimationTree
├── CollisionShape2D
├── HurtBox (Area2D)  ← 피격 판정
├── WeaponHolder (Node2D)
│   └── [CurrentWeaponScene]  ← 동적 교체
│       └── BulletSpawnPoint (Marker2D)
├── StateMachine (Node)  ← 이동 레이어
│   ├── IdleState
│   ├── WalkState
│   ├── RunState
│   ├── JumpState
│   └── FallState
└── ActionLayer (Node)   ← 액션 레이어 (병렬)
    ├── ShootState
    └── ReloadState
```

---

## Echo 특이 사항

### 시간 되감기와 플레이어 FSM
- 플레이어 상태도 시간 되감기 시 롤백 대상
- 속도(`velocity`), 이동 상태, 액션 상태 모두 스냅샷 포함 필요
- 스냅샷 간격 = 되감기 시스템 설계에 따라 결정 (→ [[Time Manipulation Run and Gun]])

### 8방향 조준
- 아날로그 → 이산 양자화 파이프라인 별도 구현 필요 (→ [[Analog Stick To 8-Way Quantization]])
- FACING_THRESHOLD 0.15 권장 (Steam Deck 드리프트 회피) (→ [[Research 8-Way Aim Usability For Run-and-Gun]])

---

## 구현 우선순위 체크리스트

```
[ ] 기본 CharacterBody2D 이동 (run/jump/gravity)
[ ] 코요테 타임 (6-12프레임)
[ ] 점프 버퍼 (8-12프레임)
[ ] 가변 점프 높이
[ ] 이중 레이어 FSM 분리
[ ] AnimationTree 슈팅 오버레이 블렌드
[ ] WeaponHolder + 무기 씬 교체
[ ] 8방향 조준 양자화 (→ Analog Stick To 8-Way Quantization)
[ ] 시간 되감기 상태 스냅샷 (→ Time Manipulation Run and Gun)
```

---

## 출처

- Slynyrd Pixelblog: "Side View Run 'N Gun" (2026-01-26)
- GDQuest Side-Scroller Character Module
- Godot 4 State Machine 패턴 (GDScript)
- [[Research 8-Way Aim Usability For Run-and-Gun]]

## 관련 페이지

- [[Run and Gun Enemy AI Archetypes]] — 적 FSM (대응 관계)
- [[Run and Gun Bullet System Pattern]] — 총알 시스템
- [[Analog Stick To 8-Way Quantization]] — 조준 입력 처리
- [[Time Manipulation Run and Gun]] — 되감기 상태 스냅샷
