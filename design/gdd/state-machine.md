# State Machine Framework

> **System**: #5 State Machine Framework
> **Category**: Core / Foundation
> **Priority**: MVP (Tier 1)
> **Status**: **Approved (Round 2 design-review 2026-05-10: APPROVED — Round 1 8 BLOCKING items all verified, 2 residuals applied inline)** — Lean re-review (single-session, per `production/review-mode.txt`). Cross-doc consistency verified: `monitorable` matches damage.md DEC-4/C.6/D.4; B-range 2–6 matches time-rewind.md D-glossary; 1-arg `player_hit_lethal(cause: StringName)` matches damage.md DEC-1; 5-signal connect order matches F.1 + AC-14. Round 2 residuals applied: (R2-1) AC count math 27→28 + Logic 25→26 (AC-17a was separately enumerated row, not AC-17 sub-clause); (R2-2) `_state_history` ring buffer promoted from Tier 2 to Tier 1 in C.1.5 (AC-12 + AC-24 BLOCKING dependency resolution). Round 1 BLOCKING summary preserved: B1 B-range 2–8 → 2–6 (`time-rewind.md` 단일 출처 일치) · B2 `pause_swallow_states` framework invariant lock + Time Rewind Rule 18 인용 (OQ-SM-4 Resolved) · B3 D.2 input-buffer formula에 `(F_input ≥ 0)` sentinel 가드 인코딩 · B4 D.5 DyingState intra-tick ordering 규칙 명시 + 신규 AC-17a · B5 `EchoLifecycleSM._ready()` `call_deferred("_connect_signals")` 패턴 + null assert (OQ-SM-6 Resolved) · B6 `Q_cap` → `TRANSITION_QUEUE_CAP` const (OQ-SM-5 Resolved) · B7 `class_name EchoLifecycleSM extends StateMachine` 명시 · B8 AC verification methods 정정 + 신규 AC-27 (E-13). 12 RECOMMENDED + 5 nice-to-have는 v2 패스 / Tier 1 prototype 검증 후 평가. creative-director directive 유지: Round 3는 prototype empirical falsification 또는 cross-doc contradiction에만 발동.
> **Author**: game-designer + godot-gdscript-specialist
> **Created**: 2026-05-09 (Round 1 reviewed 2026-05-10)
> **Engine**: Godot 4.6 / GDScript (statically typed)
> **Depends On (provisional)**: — (Foundation; signals consumed from Input #1, Damage #8, Time Rewind #9, Scene Manager #2)
> **Consumed By (provisional)**: Player Movement #6, Enemy AI #10, Boss Pattern #11, Time Rewind System #9 (already locked)

---

## A. Overview

State Machine Framework는 Echo의 모든 게임플레이 엔티티(ECHO, 적, 보스)가 *명시적이고 결정론적인* 상태로 행동하도록 만드는 GDScript 프리미티브 모음이다. 두 가지 기본 클래스 — `State`(라이프사이클 가상 메서드 + 컨텍스트 참조)와 `StateMachine`(전이 + 시그널-리액티브 디스패치) — 만 제공하며, 어떤 엔티티에 대해서도 그 자체로 동작 정의를 강제하지 않는다. 시스템 #9 Time Rewind이 이미 락인한 ECHO 4-state 머신(ALIVE / DYING / REWINDING / DEAD)과 그에 부수하는 `_lethal_hit_latched` 래치 + pause-swallow 의무는 본 프레임워크 위에서 **호스팅**될 뿐, 그 정의 자체는 `design/gdd/time-rewind.md`가 단일 출처로 보유한다. Foundation 계층이므로 어떤 시스템에도 *직접* 의존하지 않으나, 시그널 소비자로서 Damage(`player_hit_lethal`) · Time Rewind(`rewind_started` 외 4개) · Scene Manager(`scene_will_change`) · Input의 메시지를 받아 전이를 구동한다. 솔로 16개월 예산 안에서는 Tier 1에서 ECHO + 1개 적 archetype + 1개 보스 페이즈 머신만으로 *재사용 가능성*을 입증하면 충분하며, 24개 시스템 전체 reuse는 Tier 2 게이트의 검증 대상이다.

**핵심 포지셔닝**:

- **Framework, not behavior** — primitive만 정의. ECHO 머신은 Time Rewind GDD가 소유.
- **Signal-reactive, not polled** — 자체 `_physics_process` 미사용. `physics_step_ordering` 사다리 슬롯 없음.
- **Reusable across entity types** — ECHO/적/보스 모두 동일 framework 위에 구축.
- **Solo-budget aware** — Tier 1에서 3종(ECHO + 1 적 + 1 보스) 검증, 풀 reuse는 Tier 2.

---

## B. Player Fantasy

State Machine Framework는 Foundation 시스템이며, 플레이어가 직접 인지하는 메커닉이 아니다. 따라서 본 섹션의 fantasy는 *플레이어 감정*이 아닌 **시스템 불변성** — 플레이어가 *결코 보지 말아야 할* 것들의 목록 — 으로 정의된다.

### B.1 The Invariant (플레이어가 보지 않는 것)

세 가지 *비-이벤트*가 본 프레임워크의 성공 기준이다:

1. **입력이 사라지는 순간이 없다.** ECHO가 죽기 직전 0.067초 동안 누른 점프·사격·되감기 입력은 어떤 상태 전이 도중에도 *드롭되지 않는다*. DYING 진입 직전 4프레임 + DYING 12프레임 + REWINDING 진입 0프레임은 입력 손실 0%를 보장하는 단일 윈도우다.

2. **UI가 깜빡이는 순간이 없다.** REWINDING 도중 `boss_defeated`가 도착해도 HUD 토큰 카운터는 즉시 갱신되지 않고 `rewind_protection_ended`까지 지연된다. 즉, 같은 0.5초 안에 시각 시그니처가 두 번 바뀌는 일이 없다. 이 지연 정책의 enforcer는 SM이다.

3. **상태 사이의 *경계없는 진공*이 없다.** ECHO는 항상 정확히 하나의 상태를 가진다. ALIVE에서 REWINDING으로 *직접* 점프하는 경로는 없다 — 반드시 DYING을 거친다. 플레이어가 데미지를 입은 직후 *0프레임짜리 무상태*에 빠지는 silent 버그(전이 함수가 시그널을 emit하면서 또 다른 전이를 트리거하는 경우)는 framework 차원에서 차단된다.

### B.2 The Cascade (간접 fantasy)

SM이 위 세 invariant를 보장할 때, *상위 시스템의 fantasy*가 비로소 가능해진다:

- **Time Rewind의 "Defiant Loop"** — 죽음의 0.2초가 *분노의 의사결정 시간*이 되려면, 그 시간이 입력 누락 없이 끝까지 살아 있어야 한다. SM의 입력 버퍼 + 래치가 그것을 보장한다.
- **Pillar 2 "결정론적 패턴"** — 보스가 매 시도마다 동일한 페이즈 전이를 따르는 것은, 보스 SM이 wall-clock이 아닌 *시그널 + 프레임 카운터*로 전이하기 때문이다.
- **Anti-Pillar #5 "스토리는 컷씬이 아니다"** — 게임 흐름이 SM 전이로 표현되는 한, 스토리 비트는 *플레이 가능한 상태*로 노출되며 컷씬 락아웃이 발생하지 않는다.

### B.3 Anti-Fantasy (시스템이 결코 만들지 말아야 할 감정)

- **"내가 입력했는데 캐릭터가 무시했다"** — 모든 폐기는 *명시적 거부 큐*(SFX + 시각 신호)로 표현된다. 침묵 폐기 금지.
- **"이 캐릭터는 지금 뭘 하고 있는 거지?"** — 모든 상태는 *디버그 가능*해야 한다. 디버그 빌드는 현 상태명을 표시하는 콜아웃을 띄울 수 있다(편의 기능, Tier 2 옵션).
- **"되감기로 죽음을 회피했는데 곧바로 죽었다"** — REWINDING의 30프레임 i-frame이 SM 차원에서 보장된다. *데미지 시그널 도착 → 무시* 경로는 SM이 차단.

### B.4 Reference

이 세 *cascade fantasy*의 출처는 다음 GDD/문서들이다:

- Time Rewind System #9 — Defiant Loop ([`design/gdd/time-rewind.md`](time-rewind.md) Section B)
- Pillar 2 결정론 ([`design/gdd/game-concept.md`](game-concept.md))
- Anti-Pillar #5 ([`design/gdd/game-concept.md`](game-concept.md))

본 GDD는 위 fantasy를 *재정의하지 않으며*, framework가 *어떤 invariant로 그것을 가능케 하는지*만 정의한다.

---

## C. Detailed Design

### C.1 Framework Primitives

State Machine Framework는 두 개의 핵심 클래스만 제공한다 — `State`와 `StateMachine`. 둘 다 `Node`를 상속하며, 호스트 엔티티의 자식으로 컴포지션된다(Autoload 금지).

#### C.1.1 클래스 계층 결정

| 결정 | 선택 | 거부된 대안 | 이유 |
|---|---|---|---|
| State 베이스 타입 | `Node` (extends Node) | `RefCounted` | 디버그 시 SceneTree 인스펙터에서 현 상태 트리가 즉시 보임. State 안에서 자식 Timer/AnimationPlayer 노드를 쓸 수 있음. 솔로 디버깅 효율 우선. |
| StateMachine 베이스 타입 | `Node` (extends Node) | Autoload | 엔티티별 인스턴스화 필수 (ECHO, 적 N개, 보스 N개). Autoload는 single-instance가 강제되어 부적합. |
| 계층 모델 | **Flat** (단일 레벨 머신) | Hierarchical (HSM) / Parallel | Tier 1은 ECHO 4-state + 적 5-state + 보스 N-페이즈 모두 flat으로 표현 가능. HSM 구현은 솔로 4-6주 budget 침식 위험. *복수 SM 컴포지션*으로 hierarchy 흉내 (PlayerMovement는 자체 sub-SM 보유). |
| 트랜지션 모델 | 명시적 호출 (`transition_to(state)`) | 가드 평가형 (자동 전이) | 시그널-리액티브 + 명시적 호출은 Godot 4 시그널 모델과 자연스럽게 정렬. 가드 평가는 `_process` 폴링 필요 → 결정성 약화. |

#### C.1.2 `State` 클래스 API

```gdscript
class_name State extends Node

## 컨텍스트 호스트 (이 State를 소유한 엔티티). _ready에서 부모 체인을 통해 자동 해결.
var host: Node = null

## 라이프사이클 — 모두 가상. 기본 구현은 no-op.
func enter(payload: Dictionary = {}) -> void: pass
func exit() -> void: pass

## 호스트의 _physics_process에서 호출됨. delta는 host의 delta 그대로.
## State 자체는 _physics_process를 사용하지 않는다 (이중 호출 방지).
func physics_update(delta: float) -> void: pass

## 시그널 핸들러 — host StateMachine이 라우팅. 미구현 시 no-op.
## 명명 규약: handle_<signal_name>(...) — StateMachine이 자동 dispatch.
## 예: handle_player_hit_lethal(cause: StringName) -> void: pass
```

**규칙**:
- `host`는 `_ready()` 시 부모(StateMachine) → 그랜드페어런트(엔티티) 체인으로 해결. 명시적 setter 미사용.
- `enter()`의 `payload`는 트랜지션 시 전달되는 임의 데이터(예: `{"cause": &"laser"}`). 사용 안 하면 무시.
- State는 자체 `_physics_process`/`_process`를 *override 금지*. 모든 per-tick 로직은 `physics_update(delta)`에 작성.
- State는 자체 시그널 emit 가능하나, 트랜지션 *결정*은 항상 StateMachine을 통해서. 즉 `state_machine.transition_to(...)` 호출은 허용, `host.global_position = ...` 와 같은 직접 변경도 허용. 직접 *상태 객체 교체*는 금지.

#### C.1.3 `StateMachine` 클래스 API

```gdscript
class_name StateMachine extends Node

signal state_changed(from_state: StringName, to_state: StringName)

## 현재 활성 State. 외부에서는 read-only로만 사용.
var current_state: State = null

## 마지막 전이가 발생한 physics frame (디버그/테스트용).
var last_transition_frame: int = -1

## 초기 상태로 진입한다. _ready에서 호스트가 한 번 호출.
## initial_state는 자식 노드 중 하나여야 한다.
func boot(initial_state: State, payload: Dictionary = {}) -> void

## 상태 전이를 요청한다. 큐잉 + atomic 보장 (C.1.4).
func transition_to(new_state: State, payload: Dictionary = {}, force_re_enter: bool = false) -> void

## 호스트의 _physics_process에서 호출. current_state.physics_update를 위임.
func physics_update(delta: float) -> void

## State의 명명 규약 핸들러를 dispatch한다. 시그널 emit 자동 라우팅용 헬퍼.
## 예: dispatch_signal(&"player_hit_lethal", [cause]) →
##     current_state에 handle_player_hit_lethal(cause) 가 있으면 호출.
func dispatch_signal(signal_name: StringName, args: Array = []) -> void
```

**규칙**:
- `current_state`는 `boot()` 호출 전 `null`. 외부 코드는 `null` 가드를 가정해야 한다.
- `transition_to(new_state)`에서 `new_state == current_state`이고 `force_re_enter == false`이면 no-op (E-7 self-transition 정책).
- 여러 자식 State 노드 중 하나만 활성. 비활성 State는 `_physics_process`가 호출되지 않으므로 추가 비용 0.

#### C.1.4 트랜지션 atomicity (재진입 방지)

`transition_to()`가 `current_state.exit()` 또는 `new_state.enter()` 도중 *다시* 호출되는 경우(예: enter 안에서 시그널이 emit되어 같은 SM에 다시 도달), 즉시 실행하지 않고 **단일 큐**에 enqueue한다. 현재 진행 중인 전이 호출이 반환된 후 큐를 flush한다.

| 단계 | 동작 |
|---|---|
| 1. 호출 | `transition_to(new_state, payload)` 진입 |
| 2. 가드 | 진행 중 플래그(`_is_transitioning`)가 true면 큐에 푸시하고 즉시 반환 |
| 3. 락 | `_is_transitioning = true` |
| 4. 종료 | `current_state.exit()` 호출 |
| 5. 교체 | `current_state = new_state`, `last_transition_frame = Engine.get_physics_frames()` |
| 6. 진입 | `new_state.enter(payload)` 호출 |
| 7. 시그널 | `state_changed.emit(from_name, to_name)` |
| 8. 언락 | `_is_transitioning = false` |
| 9. 플러시 | 큐가 비어있지 않으면 첫 항목을 pop해 transition_to 재귀 호출 |

**큐 길이 cap**: 4. 한 transition 호출이 5개 이상의 후속 전이를 트리거하면 *cascade 버그*로 간주하고 `push_error()` + 큐 폐기. 정상 게임플레이에서 큐 깊이는 1을 넘지 않아야 한다(E-6 참조).

#### C.1.5 디버그 지원

**Tier 1 — 결정성 검증 도구 (필수)**:

- `_state_history: Array[StringName]` — 마지막 32개 전이를 ring buffer로 보관 (32 entry × ~16 B StringName ≈ 512 B; per-instance overhead 무시 가능). `transition_to()` 9단계 atomic 시퀀스 끝에서 1회 push (오래된 entry는 ring overwrite). AC-12 `_state_history` 단일 entry 검증 + AC-24 1000-cycle 결정성 비교 도구로 사용. **Tier 1 BLOCKING AC가 본 필드에 의존**하므로 Tier 1 단계에서 활성 필수 (Round 2 design-review intra-doc 정합성 정정).

**Tier 2 — UX 편의 도구 (옵션)**:

- `state_changed` 시그널을 구독하는 디버그 오버레이 라벨 — 화면 우상단에 `[ECHO] ALIVE → DYING (frame 12345)` 표시. Tier 1은 필요 시 `print_debug` 한 줄로 대체.

### C.2 ECHO 머신 호스팅 의무

ECHO의 4-state 머신(ALIVE / DYING / REWINDING / DEAD)은 본 프레임워크의 *첫 번째 클라이언트*다. 단일 출처 원칙에 따라 4-state 머신 자체의 *행동 정의*는 [`design/gdd/time-rewind.md`](time-rewind.md) Section C가 보유하며, 본 GDD는 이 머신이 *프레임워크에 부과한 6가지 의무*만 명시한다. 의무 위반은 Time Rewind GDD AC를 깨므로, 본 프레임워크는 모든 의무를 *호스팅 가능*해야 한다.

#### C.2.1 호스팅 위치

ECHO 4-state 머신은 `time-rewind-controller`(TRC) 노드가 *아니라* **ECHO 엔티티의 자식 `StateMachine` 노드**에 위치한다. 이름은 `EchoLifecycleSM`. 자식 State 노드 4개:

> **Round 5 cross-doc-contradiction exception (2026-05-10, Decision A — player-movement.md F.4.1 #3 의무)**: 본 노드 트리는 player-movement.md A.Overview에서 락인된 모델 (`PlayerMovement extends CharacterBody2D` = ECHO root)에 정렬되도록 정정되었다. 이전 초안의 `ECHO (CharacterBody2D)` + `PlayerMovement (Node)` 분리 표기는 폐기 — ECHO 엔티티의 root 노드 *자체*가 PlayerMovement(CharacterBody2D)이며, EchoLifecycleSM / PlayerMovementSM / HurtBox / HitBox / Damage / WeaponSlot / AnimationPlayer / Sprite2D는 모두 그 자식 노드다.

```
PlayerMovement (CharacterBody2D, root — ECHO 엔티티 자체, process_physics_priority=0; player-movement.md A.Overview)
├── EchoLifecycleSM (StateMachine — 본 프레임워크 인스턴스, ALIVE/DYING/REWINDING/DEAD)
│   ├── AliveState (State)
│   ├── DyingState (State)
│   ├── RewindingState (State)
│   └── DeadState (State)
├── PlayerMovementSM (StateMachine — Player Movement GDD 소관, M2 reuse 검증 케이스; idle/run/jump/fall/aim_lock/dead — DEC-PM-1)
├── HurtBox (Damage GDD #8 — entity_id = &"echo", monitorable 토글 권한 = SM DEC-4)
├── HitBox (Damage GDD #8 — Tier 1 미사용; Tier 2 melee 시 활용)
├── Damage (Damage GDD #8 — 2-stage death host: lethal_hit_detected → 12-frame grace → death_committed)
├── WeaponSlot *(provisional Player Shooting #7 자식 노드)*
├── AnimationPlayer (Godot 4.6 — restore 시 `seek(time, true)` 강제 즉시 평가, time-rewind.md I4)
└── Sprite2D
```

TRC는 *별도 자율 노드*(process_physics_priority=1)로 ring buffer만 소유하고, EchoLifecycleSM과는 **시그널로만** 통신한다. SM이 TRC를 직접 함수 호출하는 경로는 단 하나 — `try_consume_rewind() -> bool` (Time Rewind GDD Rule 6).

**Class hierarchy** (B7 — Round 1 design-review BLOCKING):

```gdscript
class_name EchoLifecycleSM extends StateMachine
```

`EchoLifecycleSM`은 framework `StateMachine`의 **명시적 서브클래스**다. 부모 `StateMachine`의 transition queue · `_is_transitioning` atomicity · `dispatch_signal` 가드 평가는 *수정 없이 상속*되며, ECHO 전용 의무(O1–O6, C.2.2)는 다음 형태로만 *추가*된다:

- **인스턴스 멤버 변수**: `_lethal_hit_latched: bool`, `_rewind_input_pressed_at_frame: int`, `pause_swallow_states: Array[StringName]`
- **`_ready()` override**: `super._ready()` 호출 *없이* 시그널 connect + `boot()` 직접 수행 (부모 `StateMachine._ready()`는 no-op이므로 super 호출 불필요; 이 의무는 본 GDD에서 *기록*)
- **시그널 핸들러 메서드**: `_on_damage_lethal`, `_on_rewind_started`, `_on_rewind_completed`, `_on_rewind_protection_ended`, `_on_scene_will_change` (모두 `_` prefix — 외부 호출 금지)
- **외부 polling 메서드**: `should_swallow_pause() -> bool` (Pause 시스템 #18이 호출)

**framework 코드 변경 금지선**: `EchoLifecycleSM`은 부모의 `transition_to()` · `dispatch_signal()` · `physics_update()` · `boot()` · `state_changed` 시그널 정의를 *override 또는 shadow 금지*. 위반 시 AC-23(framework reuse) 실패. M2 DroneAISM / M3 StriderBossSM도 동일 원칙으로 `extends StateMachine`.

#### C.2.2 6가지 의무 (Time Rewind이 SM에 부과)

| # | 의무 | 출처 | 프레임워크 수용 방식 |
|---|---|---|---|
| **O1** | `_lethal_hit_latched: bool` 래치 소유 + `ALIVE → DYING` 전이 시 `true` 세트, `REWINDING → ALIVE` 또는 `DEAD` 전이 시 `false` 클리어 | time-rewind.md Rule 17 | `EchoLifecycleSM`이 자체 멤버 변수 `_lethal_hit_latched`를 소유. `dispatch_signal(&"player_hit_lethal", ...)` 호출 시 래치가 true면 *프레임워크 차원에서* 무시(현 State에 dispatch하지 않음). |
| **O2** | DYING/REWINDING 상태에서 `pause` 입력 swallow | time-rewind.md Rule 18 | `EchoLifecycleSM`이 `pause_swallow_states: Array[StringName] = [&"DyingState", &"RewindingState"]` 화이트리스트를 보유. Pause 시스템(#18)이 SM에 polling 함수 `should_swallow_pause() -> bool`를 호출. 현 state name이 화이트리스트에 있으면 true 반환. |
| **O3** | 입력 버퍼 — 치명타 직전 `B`프레임 + DYING 윈도우 동안 `"rewind_consume"` 입력 비드롭 | time-rewind.md Rule 5 | `EchoLifecycleSM`이 멤버 `_rewind_input_pressed_at_frame: int = -1`를 소유. AliveState/DyingState 모두 `physics_update`에서 `Input.is_action_just_pressed("rewind_consume")` 체크 → 발견 시 위 변수 갱신. DyingState가 `physics_update`에서 “윈도우 내 입력 존재 + 토큰 ≥ 1” 평가. |
| **O4** | 4개 시그널 구독 (`player_hit_lethal`, `rewind_started`, `rewind_completed`, `rewind_protection_ended`) | time-rewind.md Section C + ADR-0001 rewind_lifecycle | `EchoLifecycleSM._ready()`가 ECHO 자식 트리(`Damage` 컴포넌트, TRC 노드)에서 시그널을 connect. 모든 핸들러는 `dispatch_signal()`을 호출하여 현 State의 `handle_<name>(...)` 가상 메서드로 라우팅. |
| **O5** | `boss_defeated` REWINDING 중 도착 시 토큰 ++ 처리는 *TRC* 책임이지만, HUD 시각 갱신 지연(`rewind_protection_ended`까지)은 SM이 보장 | time-rewind.md Rule 15 | RewindingState가 `boss_defeated` 시그널을 *직접 구독하지 않는다*. TRC가 토큰 카운트를 갱신하고 `token_replenished`를 emit하지만 HUD가 그 시점에 즉시 갱신하지 않도록, HUD 자체가 `rewind_protection_ended` 발생 후 적용하는 buffered-update 패턴을 사용 (HUD GDD 소관 — 본 GDD는 *제약*만 declare). |
| **O6** | `scene_will_change` 도착 시 SM이 `_lethal_hit_latched` + 입력 버퍼 변수를 클리어 | time-rewind.md Rule 16(전제) + E-16 | `EchoLifecycleSM`이 Scene Manager(#2)의 `scene_will_change` 시그널을 구독. 핸들러가 모든 ephemeral 변수를 리셋(`_lethal_hit_latched = false`, `_rewind_input_pressed_at_frame = -1`). 현 state는 변경하지 않음(다음 씬 부트 시 Scene Manager가 ALIVE로 강제 전이). |

#### C.2.3 프레임워크가 *제공하지 않는* 것

ECHO 머신을 위해 본 프레임워크는 다음을 *제공하지 않는다*:

- **타이머 관리**: DYING의 12프레임 카운트다운, REWINDING의 30프레임 카운트다운은 각 State가 자체 카운터(`_frames_in_state: int`)로 구현. 프레임워크가 자동 타이머를 제공하지 않음 — 솔로 budget + 결정성 명료성 우선.
- **State 직렬화**: ECHO 4-state는 PlayerSnapshot에 *복원되지 않는다* (ADR-0002). 복원은 항상 ALIVE로 시작. 프레임워크는 직렬화 인터페이스 미제공.
- **시그널 우선순위**: 같은 틱에 여러 시그널 도착 시 처리 순서는 Godot 기본 순서(connect 순서)를 따름. 프레임워크가 우선순위 큐 미제공. (E-13 참조 — 다중 치명타는 latch가 자연 차단)

#### C.2.4 검증 책임 분리

| 검증 | 책임 GDD | 본 GDD에서 보장 |
|---|---|---|
| ECHO 4-state 전이 정확성 | time-rewind.md AC | — |
| 12프레임 grace 타이밍 | time-rewind.md AC | — |
| 30프레임 i-frame 타이밍 | time-rewind.md AC | — |
| 래치/swallow/입력버퍼 *호스팅 가능성* | **본 GDD AC** | Section H |
| `transition_to()` atomicity | **본 GDD AC** | Section H |
| `dispatch_signal()` 라우팅 정확성 | **본 GDD AC** | Section H |

즉, "DYING이 12프레임 후 DEAD로 가는가"는 Time Rewind QA. "EchoLifecycleSM이 4개 State 노드를 소유하고 각 State의 `handle_<signal>` 핸들러가 정확히 호출되는가"는 본 GDD QA.

### C.3 Process Order & Determinism

State Machine Framework의 결정성 보장은 두 핵심 원칙에 기댄다 — (1) **자체 `_physics_process` 미사용**으로 사다리 슬롯을 차지하지 않고, (2) **모든 전이는 동기적으로 실행**되어 같은 물리 틱 안에서 발생 시점이 결정적이다. 이 섹션은 ADR-0003의 `physics_step_ordering` 사다리와 본 프레임워크의 관계를 명시하고, 1000-cycle 결정성 테스트를 통과하기 위한 추가 제약을 정의한다.

#### C.3.1 사다리 슬롯 결정 — *없음*

ADR-0003은 다음 사다리를 정의했다:

| process_physics_priority | 시스템 |
|---|---|
| **0** | 플레이어 (PlayerMovement, ECHO 본체) |
| **1** | TimeRewindController |
| **2** | Damage component (`damage.md` C.6.4 — DEC-6 hazard grace counter decrement 슬롯) |
| **10** | 적 (CharacterBody2D archetypes) |
| **20** | 발사체 (Area2D) |

**StateMachine은 이 사다리에 슬롯을 가지지 않는다.** 이유:

- SM은 자체 `_physics_process`를 *override 하지 않는다*. 따라서 정렬할 콜백이 없다.
- SM의 `physics_update(delta)`는 *호스트가* 자신의 `_physics_process` 안에서 명시적으로 호출한다. 즉 SM의 per-tick 실행 시점은 **호스트의 priority를 그대로 상속**한다 — ECHO의 EchoLifecycleSM은 priority 0, 적의 EnemySM은 priority 10.
- SM 전이가 *시그널-리액티브*로 발생할 때(예: Damage가 `player_hit_lethal` emit), 핸들러는 emitter의 `emit_signal()` 호출 스택 안에서 동기적으로 실행된다. 별도 priority가 무의미.

이 결정은 ADR-0003 `physics_step_ordering` registry 항목을 *변경하지 않는다*. (architecture.yaml 갱신 불필요)

#### C.3.2 전이의 두 발생 경로

모든 SM 전이는 정확히 다음 둘 중 하나의 경로로 발생한다:

| 경로 | 트리거 | 실행 컨텍스트 | 예시 |
|---|---|---|---|
| **P1. Signal-reactive** | 외부 시스템의 `signal.emit(...)` | Emitter의 호출 스택 안에서 동기 실행 | Damage가 `player_hit_lethal` emit → EchoLifecycleSM의 핸들러가 `transition_to(DyingState)` 호출. 호출은 Damage의 `_physics_process` 끝나기 전에 완료. |
| **P2. Tick-driven** | 호스트의 `_physics_process(delta)` → `state_machine.physics_update(delta)` → `current_state.physics_update(delta)` 호출 후 State 내부에서 `transition_to(...)` | 호스트의 priority 0 (또는 호스트별) 슬롯에서 동기 실행 | DyingState가 `_frames_in_state >= D` 도달 시 `transition_to(DeadState)` 호출. ECHO priority 0 슬롯에서 발생. |

**P3 (금지)** — `_process` 또는 wall-clock 타이머에서 트리거되는 전이는 결정성 위반으로 금지. 어떤 State도 `_process` 또는 `Time.get_ticks_msec()`를 사용하지 못함(ADR-0003 결정성 클락 결정).

#### C.3.3 같은 틱 다중 시그널의 결정적 순서

Damage가 두 발사체에 의해 같은 물리 틱에 두 번 `player_hit_lethal` emit하는 상황(E-13)을 고려하자. 두 emit은 다음 순서로 실행된다:

1. Damage의 `_physics_process`가 발사체 충돌을 처리한다. 처리 순서는 `physics_step_ordering` 사다리의 priority 20 발사체 슬롯 안에서 **scene-tree-order**(부모-자식 + 형제 인덱스)로 결정된다 (ADR-0003 spawn orchestrator 규칙).
2. 첫 번째 emit이 동기적으로 EchoLifecycleSM 핸들러를 호출 → `transition_to(DyingState)` → `_lethal_hit_latched = true` 세트.
3. 두 번째 emit이 동기적으로 EchoLifecycleSM 핸들러를 호출 → 래치가 true이므로 dispatch_signal에서 *조용히 무시*.

**SM이 수동으로 보장해야 할 것**: dispatch_signal의 latch 체크는 `current_state.handle_*` 호출 *이전*에 일어나야 한다. 그래야 같은 틱 중복이 latch에 의해 차단된다. (Section H AC-11로 검증)

#### C.3.4 시그널 connect 순서 결정성

Godot 4의 `signal.emit()`은 connect된 핸들러를 *connect 순서*로 호출한다. SM이 외부 시그널을 connect하는 순서는 **항상 동일**해야 한다 — `EchoLifecycleSM._ready()`에서:

```gdscript
func _ready() -> void:
    # B5 (Round 1 design-review BLOCKING) — call_deferred 패턴.
    # 이유: ECHO 서브트리가 TRC/SceneManager 서브트리보다 scene-tree-order 상 먼저
    # 등장하면, EchoLifecycleSM._ready()가 TRC._ready()보다 먼저 실행되어
    # get_first_node_in_group(&"time_rewind_controller")가 null 반환 → .connect()
    # 호출이 hard-crash. call_deferred는 같은 프레임의 모든 _ready()가 끝난 후
    # 실행되므로 TRC의 add_to_group()이 보장된다.
    call_deferred("_connect_signals")

func _connect_signals() -> void:
    # 정해진 순서. 변경 시 1000-cycle 결정성 테스트 결과가 바뀔 수 있음.
    # 모든 lookup은 null assertion으로 silent failure 차단.
    var damage: Damage = host.get_node_or_null(^"Damage") as Damage
    assert(damage != null, "EchoLifecycleSM: host '%s' missing 'Damage' child or wrong type" % host.name)
    damage.player_hit_lethal.connect(_on_damage_lethal)  # CONNECT_DEFAULT (no flags)

    var trc: Node = get_tree().get_first_node_in_group(&"time_rewind_controller")
    assert(trc != null, "EchoLifecycleSM: no node in group 'time_rewind_controller'")
    trc.rewind_started.connect(_on_rewind_started)
    trc.rewind_completed.connect(_on_rewind_completed)
    trc.rewind_protection_ended.connect(_on_rewind_protection_ended)

    var scene_mgr: Node = get_tree().get_first_node_in_group(&"scene_manager")
    assert(scene_mgr != null, "EchoLifecycleSM: no node in group 'scene_manager'")
    scene_mgr.scene_will_change.connect(_on_scene_will_change)

    boot(get_node(^"AliveState") as State)
```

**규칙**:

- connect 순서는 `_connect_signals()` 내 *기록된 순서를 따른다*. 자동 정렬, 동적 순서 변경 금지.
- 모든 시그널 연결은 **`CONNECT_DEFAULT` (no flags)** 의무 — `CONNECT_DEFERRED`(flag 2)는 latch 가드(D.3)와 transition queue(C.1.4)의 atomicity 모델을 깨뜨리므로 *금지*. AC-14가 `Object.get_signal_connection_list()`로 검증.
- `boot()`는 모든 connect 완료 *후*에만 호출 — `_connect_signals()`의 마지막 줄. boot 전 시그널 도착은 E-3 가드 2번이 폐기.
- `get_first_node_in_group`은 group 등록 순서가 결정적이라는 가정에 의존 — Scene Manager + TRC는 자신의 `_ready()` 첫 줄에서 group에 등록할 의무 (Scene Manager GDD + Time Rewind GDD AC로 검증).
- 한 시그널을 *여러 SM*이 구독하는 경우(예: 적 SM이 player의 위치 변화 구독), 모든 SM의 `_ready()`가 같은 프레임에 실행되더라도 scene-tree-order로 순서가 고정.

**`_ready()` ↔ `_connect_signals()` 1프레임 윈도우**: `_ready()`가 `call_deferred`로 spawn한 `_connect_signals()`는 *같은* 프레임 끝에 실행된다(Godot deferred call 동작). 따라서 `_ready()` 직후 ~1프레임은 `current_state == null`이며 모든 시그널은 D.3 가드 2번에서 폐기된다(E-3). 정상 게임플레이에서는 boot 전에 입력 가능한 ECHO가 존재하지 않으므로 무영향. AC-19가 boot-pending 상태 응답 검증.

#### C.3.5 1000-cycle 결정성 테스트에서의 SM 검증

Time Rewind GDD AC-T31(추정 — 1000-cycle 결정성)은 SM 차원에서도 검증되어야 한다. 본 GDD의 결정성 보장은 Section H **AC-24**로 통합 검증한다 — 동일 입력 시퀀스로 1000회 실행 시 EchoLifecycleSM의 `_state_history` 마지막 32 entry가 매번 동일해야 함. EnemySM의 `last_transition_frame` 시퀀스 결정성은 Tier 2 게이트에서 같은 패턴(AC-24 재사용)으로 검증.

#### C.3.6 Hot-spot 회피 (성능 budget)

`.claude/docs/technical-preferences.md`의 16.6ms 예산 배분에서 *time-rewind subsystem ≤1ms*는 **TRC의 ring buffer 캡처**만을 가리키며 SM 비용은 별도이다. SM의 per-tick 비용 추정:

- ECHO: 1 SM × 1 active state × `physics_update` (단순 카운터/입력 폴링) = **<0.05 ms**
- 적: 최대 30 동시 SM × 1 active state × 단순 분기 = **<0.3 ms** (Tier 1 30개 적 동시 cap, Tier 2 재검토)
- 보스: 1 SM × phase logic = **<0.1 ms**

총 SM 비용 < 0.5 ms / 16.6 ms (3%). 게임플레이 6ms 예산에 흡수. 별도 budget 등록 불필요. (architecture.yaml `performance_budgets`는 빈 채로 유지)

### C.4 Reuse Across Entities

State Machine Framework는 *솔로 16개월 budget* 안에서 자기 정당화가 가능해야 한다. 즉 본 프레임워크는 ECHO만을 위해 존재해서는 안 되며, 적·보스도 같은 두 클래스(`State` / `StateMachine`)를 재사용해야 한다. 이 섹션은 Tier 1 reuse 검증 목표와 framework feature creep 방지 가드를 정의한다.

#### C.4.1 Tier 1 Reuse Target — 3-machine proof

Tier 1 (4-6주 prototype) 종료 시점까지 본 프레임워크 위에 **세 종류의 머신이 변경 없이** 동작해야 한다:

| # | 머신 | 호스트 엔티티 | 상태 수 | 머신 종류 |
|---|---|---|---|---|
| **M1** | EchoLifecycleSM | ECHO (CharacterBody2D) | 4 | ALIVE / DYING / REWINDING / DEAD (Time Rewind GDD) |
| **M2** | DroneAISM | 보안 드론 (CharacterBody2D, priority 10) | 5 | IDLE / PATROL / SPOT / FIRE / DEAD (Enemy AI GDD에서 정의 예정) |
| **M3** | StriderBossSM | STRIDER 보스 (CharacterBody2D, priority 10) | 페이즈 ≥ 3 | PHASE_1_LEGS / PHASE_2_LASER / PHASE_3_DESPERATION / DEFEATED (Boss Pattern GDD) |

**성공 기준**: M2/M3가 framework 코드(`State.gd`, `StateMachine.gd`)를 *복사·분기·수정 없이* 인스턴스화한다. 발견된 framework 결함은 framework 측에서 일반화된 형태로 수정되어 M1에도 reflux된다.

#### C.4.2 Tier 1 Out of Scope

다음은 *Tier 1에서 의도적으로 미지원*. Tier 2 재평가 대상:

- **Hierarchical State Machine (HSM)** — 부모-자식 상태 + 자동 부모 enter/exit. PlayerMovement는 Tier 1에서 *별도 sub-StateMachine*으로 hierarchy를 흉내낸다(EchoLifecycleSM과 PlayerMovementSM 두 머신을 ECHO에 부착). HSM의 가치는 Tier 2에 적 archetype이 5종 이상으로 늘어났을 때 재평가.
- **Parallel/Concurrent States** — 한 엔티티가 두 직교 머신을 동시 실행하는 패턴. Tier 1에서는 *복수 StateMachine 노드*로 충분(ECHO도 위와 같이 두 SM 보유).
- **Visual Editor / 그래프 도구** — Godot Editor 플러그인으로 SM을 시각화. 솔로 1인 budget 침식. State 수가 적어 코드만으로 충분.
- **State Persistence (저장/복원)** — 세이브 시스템과 통합되는 SM 상태 직렬화. ECHO 4-state는 ADR-0002로 *복원하지 않기로 결정*. 적/보스 SM도 Tier 1은 씬 재로드 시 초기 상태로 리셋.
- **Animation-driven States** — `AnimationPlayer.animation_finished`를 자동 전이 트리거로 매핑. Tier 1은 명시적 시그널 connect로 충분.

이 5개 미지원 기능을 *디자인 의도*로 본 GDD에 명시함으로써, 후속 시스템 GDD가 이 패턴들을 가정하지 못하도록 한다 (M3 STRIDER 보스 디자인 시 HSM 가정 금지 등).

#### C.4.3 Reuse 위반 발견 프로토콜

Tier 1 작성 도중 어떤 머신(예: M3 StriderBossSM)이 framework로는 표현 불가능하다고 판명되면:

1. **즉시 중단** — 해당 머신의 임시 분기 구현으로 진행하지 않는다.
2. **결함 분류** — *framework 일반화로 해소 가능*인지 *Tier 2 기능 미리당김*인지 판단.
3. **분류별 대응**:
   - 일반화 가능: framework 측에 추가 규약/메서드를 *최소 surface*로 추가. 예: `State.handle_animation_finished()` 가상 메서드 추가.
   - Tier 2 기능: 솔로 게임 디자이너 판단으로 (a) Tier 1 보스 패턴을 단순화(PHASE 수 축소)하거나 (b) Tier 1 budget을 1주 연장하고 framework feature를 도입.
4. **결정 기록** — 본 GDD Open Questions 섹션 또는 후속 ADR로 기록.

#### C.4.4 Tier 2 Reuse 확장 (참고)

Tier 2 (6개월 누계 / 3 stages) 게이트에서는 다음이 framework 위에 동작해야 한다:

- 적 archetype 3종(드론 / 보안로봇 / STRIDER 잡몹) — 각 5-7 상태
- 보스 2종(STRIDER 보스 + 추가 1) — 각 ≥ 4 페이즈
- PlayerMovement 자체 sub-SM — 7-9 상태(idle/run/jump/double_jump/fall/wall_grip/aim_lock/hit_stun/dash)
- Pickup 시스템의 보조 머신 (vertical slice 시점)

총 7~10개 SM이 단일 엔진 빌드 안에서 동시 동작. C.3.6의 비용 추정을 Tier 2 시점에 재측정. 측정 결과가 *< 1.0 ms / 16.6 ms*를 유지하면 framework는 검증 완료. 초과 시 hot-state(예: 적 SM의 `physics_update`)를 직접 호출 인라인하는 fast-path 도입 검토.

#### C.4.5 Framework 외 호스팅 금지 영역

다음 시스템은 *State Machine Framework를 사용하지 않는다*:

- **HUD 시스템 (#13)** — UI 상태(메뉴 열림/닫힘)는 단순 boolean 플래그로 충분. SM 도입은 over-engineering.
- **Scene/Stage Manager (#2)** — 씬 라이프사이클은 Godot의 SceneTree 자체에 위임. 별도 SM 불필요.
- **Audio System (#4)** — BGM 트랙 전환은 Audio Director의 cue chart로 표현. SM 미사용.
- **Input System (#1)** — 입력은 즉시값 폴링(`Input.is_action_pressed`)으로 충분. SM 미사용.
- **Time Rewind Controller** — TRC는 *State 없는 ring buffer 컨트롤러*. ECHO의 4-state 머신을 *호스팅하지 않는다* (C.2.1 호스팅 위치 결정).

이 5개 시스템에서 SM을 도입하려는 후속 PR은 본 섹션을 근거로 거부 가능.

---

## D. Formulas

State Machine Framework는 산술 공식이 적은 시스템이다 — 결정 로직이 *전이 관계*로 표현되기 때문. 본 섹션은 framework 차원에서 검증되어야 할 5개 *predicate / ordering / counter* 공식을 정의한다. 모든 변수는 D.1 용어집의 단일 출처에서 정의하며, ECHO 머신 전용 변수(D, B, R)는 [`time-rewind.md`](time-rewind.md)의 D-glossary를 import한다.

### D.1 변수 용어집

| 변수 | 타입 | 범위 | 의미 | 출처 |
|---|---|---|---|---|
| `D` | int | 8–18 (knob), default 12 | DYING grace window 길이 (frames) | time-rewind.md `RewindPolicy.dying_window_frames` |
| `B` | int | 2–6 (knob), default 4 | 입력 버퍼 pre-hit window 길이 (frames) | time-rewind.md `RewindPolicy.input_buffer_pre_hit_frames` (range owner: time-rewind.md) |
| `R` | int | 30 (hardcoded const) | REWINDING i-frame 길이 (frames) | time-rewind.md `REWIND_SIGNATURE_FRAMES` |
| `F_now` | int | ≥ 0 | 현재 physics frame count | `Engine.get_physics_frames()` |
| `F_lethal` | int | ≥ 0 | `_lethal_hit_latched`가 true로 set된 시점의 physics frame | EchoLifecycleSM 내부 |
| `F_input` | int | ≥ 0 또는 -1 | 마지막 `"rewind_consume"` `is_action_just_pressed` 발견 frame. -1은 미발생 | EchoLifecycleSM 내부 |
| `F_enter` | int | ≥ 0 | 현 State가 enter()된 시점의 physics frame | StateMachine.last_transition_frame |
| `Q_depth` | int | 0–4 | transition_to 큐 현재 깊이 | StateMachine 내부 |
| `TRANSITION_QUEUE_CAP` | int | 4 (const, hardcoded) | transition_to 큐 최대 길이 — *safety invariant*, knob 아님 (B6 — Round 1) | C.1.4 결정 |

### D.2 Input Buffer Window Predicate (E1)

`"rewind_consume"` 입력이 *유효 버퍼 윈도우* 안에 있는지 판정한다. DyingState의 `physics_update`에서 매 틱 평가.

**공식** (B3 — Round 1 design-review BLOCKING; sentinel guard 명시 인코딩):

```
input_in_window := (F_input >= 0)
                 ∧ (F_input >= F_lethal - B)
                 ∧ (F_input <= F_lethal + D - 1)
```

**변수 의미**:

- `F_input >= 0`: 입력이 *발생*했음을 보장. 이전 정의(`F_input == -1` 미발생 sentinel)에서, `F_lethal < B`인 게임 시작 직후 첫 프레임들에서 `F_lethal - B`가 음수가 되어 sentinel이 우연히 통과하던 buggy 경로를 차단. 산술이 아닌 *명시적 조기-차단 가드*.
- `F_input >= F_lethal - B`: 입력이 치명타 *직전* B프레임 안에 발생했거나 그 이후
- `F_input <= F_lethal + D - 1`: 입력이 DYING 윈도우 종료 *이전*에 발생 (DYING 윈도우는 `[F_lethal, F_lethal+D-1]` inclusive)

**Example (default knobs, D=12, B=4)**:

| Scenario | F_lethal | F_input | 판정 |
|---|---|---|---|
| 치명타 5프레임 전 입력 | 1000 | 995 | `995 ≥ 996` false → **out** (B=4이므로 `≥996` 필요) |
| 치명타 4프레임 전 입력 | 1000 | 996 | `996 ≥ 996` ∧ `996 ≤ 1011` → **in** |
| 치명타 직후 입력 | 1000 | 1000 | true ∧ true → **in** |
| DYING 11프레임 후 입력 | 1000 | 1011 | `1011 ≤ 1011` → **in** (마지막 프레임 포함) |
| DYING 12프레임 후 입력 | 1000 | 1012 | `1012 ≤ 1011` false → **out** (이미 DEAD 전이) |

**Edge cases (formula-encoded)**:

- `F_input == -1` (입력 미발생) 시 절 1(`F_input >= 0`)이 false → 전체 predicate false. 이전 prose-only 가드를 *공식 안*으로 끌어와 implementer가 prose를 못 보더라도 안전.
- 게임 시작 직후 `F_lethal < B` (예: F_lethal=2, B=4) — 절 2의 `F_lethal - B = -2`가 *수학적으로* 음수더라도 절 1이 -1을 차단. 따라서 sentinel 우연 통과(B3 degenerate path) 발생 안 함.

### D.3 Transition Guard Ordering (E2)

`StateMachine.dispatch_signal(signal_name, args)` 내부 가드 평가 순서. 순서 위반은 latch 우회 silent 버그를 발생시킨다 (C.3.3).

**공식 (의사 코드)**:

```
function dispatch_signal(name, args):
    1. if name == &"player_hit_lethal" ∧ _lethal_hit_latched:
           return                         # 래치 short-circuit (최우선)

    2. if current_state == null:
           return                         # boot() 전 시그널 무시

    3. handler_name := "handle_" + name
       if not current_state.has_method(handler_name):
           return                         # 미구현 핸들러 = no-op

    4. current_state.callv(handler_name, args)
       # 핸들러 내부에서 transition_to() 호출 가능 — atomicity는 C.1.4 큐가 보장
```

**Why this order**: 1번을 가드 2/3 뒤에 두면, current_state가 (예) AliveState이고 `handle_player_hit_lethal` 핸들러가 있을 때 *latch가 true임에도 핸들러가 실행되어* 두 번째 lethal-hit 처리가 발생. 순서 1번이 framework 차원의 invariant.

**Example**:

| 상황 | latch | current_state | name | 결과 |
|---|---|---|---|---|
| 정상 첫 치명타 | false | AliveState | `player_hit_lethal` | AliveState.handle_player_hit_lethal 호출 → DyingState 전이 |
| 같은 틱 두 번째 치명타 | true (1번 호출이 set) | DyingState | `player_hit_lethal` | 가드 1에서 return — 무시 |
| boot 전 시그널 | false | null | `rewind_started` | 가드 2에서 return |
| 핸들러 미구현 | false | DyingState | `boss_defeated` | 가드 3에서 return |

### D.4 Signal Handler Re-entrancy Budget (E3)

`transition_to()`가 enter/exit 도중 재호출될 때 큐 깊이가 cap을 넘지 않도록 강제. 일반 게임플레이에서 `Q_depth ≤ 1`이 invariant.

**공식**:

```
Q_depth_new := Q_depth + 1

if Q_depth_new > TRANSITION_QUEUE_CAP:
    push_error("StateMachine cascade — Q_depth exceeded TRANSITION_QUEUE_CAP (= 4)")
    Q_depth_new := Q_depth         # 큐 미증가 = 추가 전이 폐기
    return
else:
    enqueue(new_state, payload, force_re_enter)
```

**Example**:

| 시나리오 | Q_depth 진행 | 결과 |
|---|---|---|
| 정상 단일 전이 | 0 → 1 → 0 (atomic 종료 후) | 정상 |
| enter()가 1회 추가 전이 emit | 0 → 1 → 2 → 1 → 0 | 정상 (Q_depth ≤ 4) |
| enter()가 4회 추가 전이 emit (재귀) | 0 → 1 → 2 → 3 → 4 → 5 (cap 위반) | push_error + 5번째 전이 폐기 |

**기대값**: Tier 1 정상 게임플레이에서 `Q_depth_max ≤ 1`. Tier 2의 적 archetype에서 enter()가 audio cue + animation start를 트리거하더라도 ≤ 2.

### D.5 State Frame Counter (E4)

각 State는 자체 `_frames_in_state: int` 카운터를 가진다. DyingState/RewindingState의 만료 판정에 사용.

**공식**:

```
on enter(payload):
    _frames_in_state := 0

on physics_update(delta):
    _frames_in_state += 1
    # 만료 체크는 State별:
    # DyingState:     if _frames_in_state >= D: transition_to(DeadState)
    # RewindingState: if _frames_in_state >= R: transition_to(AliveState)
```

**불변식**: `_frames_in_state` 증가는 정확히 `physics_update` 호출당 1이며, *시그널 핸들러*에서 증가 금지.

**B4 — DyingState intra-tick ordering rule (Round 1 design-review BLOCKING)**:

`DyingState.physics_update(delta)` 내부 평가 순서는 *반드시* 다음 4단계로 고정한다. 순서 위반 시 마지막 valid 프레임(`F_lethal + D - 1`)의 입력이 silent dropped:

```
1. poll input  →  F_input := frame if Input.is_action_just_pressed("rewind_consume") else _prev
2. evaluate    →  if input_in_window (D.2):
                       transition_to(RewindingState)
                       return                          # 만료 체크 *전*에 즉시 종료
3. increment   →  _frames_in_state += 1
4. expiry      →  if _frames_in_state >= D:
                       transition_to(DeadState)         # → DyingState.exit() → damage.commit_death()
```

**왜 순서 1-2가 3-4보다 우선해야 하는가**:

- DyingState 마지막 프레임 (`_frames_in_state == D - 1`, e.g. D=12면 frame 11)에서 input이 도착했을 때:
  - 정상 순서: poll → predicate true → `transition_to(RewindingState)` → DyingState.exit()이 `damage.cancel_pending_death()` 호출 → 사망 회피 성공.
  - 위반 순서: increment 먼저 → `_frames_in_state == D` → expiry → `transition_to(DeadState)` → DyingState.exit()이 `damage.commit_death()` 호출 → 같은 틱의 input은 *영원히 dropped*. 12프레임 grace = "11프레임 grace" 으로 silent 축소.
- 이는 Time Rewind GDD Pillar 1("학습 도구") + AC-C2(*"frame 13 도착 시 DEAD"*)의 의미를 보존하는 *load-bearing* 순서.

**RewindingState**는 input 평가 분기가 없으므로 1-2 단계 생략 가능, 3-4만 적용.

**검증**: 본 ordering rule은 Section H **AC-17a (신규)** 로 검증 — fixture가 `_frames_in_state = D - 1`로 진입한 DyingState에 input 주입 → RewindingState 전이 + `damage.commit_death()` 미호출 확인.

**Example (D=12)**:

| Frame | physics_update 호출 횟수 | `_frames_in_state` | 만료? |
|---|---|---|---|
| F_enter | 0 (enter 호출만) | 0 | no |
| F_enter+1 | 1 | 1 | no |
| F_enter+11 | 11 | 11 | no |
| F_enter+12 | 12 | 12 | **yes** → DeadState |

**Why frame counter, not delta accumulation**: `delta`는 physics step이 *프레임 누락 시* 가변 — `0.0167` 대신 `0.0334` 등이 들어올 수 있어 12프레임 grace가 24프레임만큼 걸릴 수 있음. `Engine.get_physics_frames()`-기반 카운터는 프레임 누락이 발생해도 정확히 12 *물리 단계* 후 만료. (ADR-0003 결정성 클락 결정의 직접 적용)

### D.6 Hidden Risk — Connect-order Drift (F1)

D.3 가드 1번은 `dispatch_signal`이 가장 먼저 latch를 체크함을 보장한다. 그러나 *Damage가 emit한 시그널에 SM 외 다른 핸들러도 connect되어 있고 그 핸들러가 transition을 간접적으로 트리거*하면 D.3의 invariant가 깨질 수 있다. 예:

```
Damage.player_hit_lethal → connect 순서:
  1. EchoLifecycleSM._on_damage_lethal  (래치 set)
  2. SomeOtherSystem._on_damage_lethal  (간접적으로 다른 시그널 emit → SM 재진입)
```

핸들러 1이 래치를 set한 후 핸들러 2가 실행되어 *같은 시그널 처리 중*에 SM에 두 번째 진입을 만들 위험. **방지**: SM의 `_on_damage_lethal`은 *반드시 connect 순서 1번*. 이 의무는 C.3.4 connect 순서 규칙 + Section H **AC-14**(connect 순서)로 검증.

### D.7 Tuning Split (knob vs const)

| 변수 | 종류 | 출처 | 변경 범위 | 책임 |
|---|---|---|---|---|
| `D` | knob | RewindPolicy 리소스 | 8–18 | Time Rewind GDD (Section G) |
| `B` | knob | RewindPolicy 리소스 | 2–6 | Time Rewind GDD (Section G — range owner) |
| `R` | const | `REWIND_SIGNATURE_FRAMES` | hardcoded 30 | Time Rewind GDD (불변) |
| `TRANSITION_QUEUE_CAP` | const | StateMachine 클래스 const | hardcoded 4 | **본 GDD (safety invariant — knob 아님; G.1 미등록)** |
| 시그널 핸들러 connect 순서 | invariant | 코드 라인 순서 | 변경 금지 | **본 GDD (C.3.4)** |
| State 노드명 화이트리스트 (`pause_swallow_states`) | knob | EchoLifecycleSM export var | `[&"DyingState", &"RewindingState"]` | **본 GDD (Section G)** |

D-glossary는 framework 외에서 *변경 불가*. 본 GDD는 `TRANSITION_QUEUE_CAP` const, connect 순서 invariant, `pause_swallow_states` 화이트리스트(framework invariant — Time Rewind Rule 18에 의해 lock)만 소유.

---

## E. Edge Cases

본 섹션은 framework가 *명시적*으로 처리해야 할 **15개** edge case를 4개 카테고리로 정리한다(E-1 ~ E-15). 각 항목은 *어떻게 처리하는가*를 동작 단위로 기술하며, "graceful하게 처리"와 같은 모호한 표현은 사용하지 않는다.

### E.1 시그널 도착 / 재진입 (Signal Arrival & Re-entrancy)

#### E-1 — 같은 물리 틱에 두 번 이상 `player_hit_lethal` 도착

**상황**: 발사체가 ECHO에 동시 명중 (관통탄 + 충돌 등). Damage가 같은 틱에 `player_hit_lethal`을 두 번 emit.

**동작**:

1. 첫 번째 emit이 `EchoLifecycleSM._on_damage_lethal`에 도달.
2. SM이 즉시 `_lethal_hit_latched = true`로 set, `F_lethal = Engine.get_physics_frames()` 캐시.
3. `dispatch_signal(&"player_hit_lethal", ...)` 호출 → 가드 1번이 *현재* false인 latch를 보고 통과 → `AliveState.handle_player_hit_lethal` 실행 → `transition_to(DyingState)`.
4. 두 번째 emit이 도달. 이미 latch는 true. `dispatch_signal` 가드 1번에서 short-circuit return. 두 번째 시그널은 무시.

**검증**: 두 emit 사이 SM 상태는 정확히 한 번 ALIVE→DYING 전이. `_state_history`에 단일 entry. (AC-12)

#### E-2 — `enter()` 안에서 시그널 emit → SM 재진입

**상황**: `DyingState.enter()` 가 audio cue 이벤트를 emit하고, 그 이벤트 핸들러가 다시 `transition_to(...)`를 호출.

**동작**:

1. SM이 `_is_transitioning = true` 상태에서 `enter(payload)` 실행 중.
2. 재귀적 `transition_to()` 호출이 들어옴 → C.1.4 단계 2 가드가 *진행 중* 플래그를 보고 큐에 푸시.
3. 큐 깊이 1. `enter()` 종료 → `_is_transitioning = false` → 9단계에서 큐 flush → 추가 전이가 정상 atomic 실행.

**검증**: `_state_history`에 두 entry, `last_transition_frame` 동일 (같은 틱). 큐 깊이 max ≤ 1.

#### E-3 — `boot()` 호출 전 시그널 도착

**상황**: `EchoLifecycleSM._ready()`가 connect를 마치기 *전*에 다른 시스템의 `_ready()`가 시그널을 emit (Godot 4의 노드 부모 우선 ready 순서에 따라 발생 가능).

**동작**:

1. `current_state == null`.
2. `dispatch_signal()` 가드 2번이 즉시 return. 시그널 폐기.
3. 콘솔에 경고 없음 — 정상 라이프사이클 일부.

**검증**: `current_state`가 `null`인 동안 어떤 시그널도 transition을 트리거하지 못함. (AC-10)

#### E-4 — 미구현 `handle_<signal>` 핸들러

**상황**: AliveState는 `handle_rewind_started`를 구현하지 않으나, TRC가 `rewind_started`를 emit (예: 보스 토큰 보너스 시점).

**동작**:

1. `dispatch_signal(&"rewind_started", [tokens])` 가드 1/2 통과.
2. 가드 3번이 `current_state.has_method("handle_rewind_started")` 체크 → false → return.
3. 시그널은 폐기되며 에러/경고 발생 안 함. State별 *선택적 처리* 패턴이 정상.

**검증**: 핸들러 미구현 State에서 시그널 도착 시 SM 상태 무변경, 콘솔 청결.

### E.2 전이 자체 (Transition Mechanics)

#### E-5 — Self-transition (`transition_to(current_state)`)

**상황**: AliveState 도중 시그널 핸들러가 `transition_to(get_node("AliveState"))`를 호출.

**동작 (force_re_enter == false, 기본값)**:

1. `new_state == current_state` 체크 → no-op return. `exit()` 호출 X, `enter()` 호출 X, `state_changed` 시그널 emit X.

**동작 (force_re_enter == true)**:

1. C.1.4 표준 흐름 실행. `current_state.exit()` → 상태 교체(같은 객체 재할당) → `enter(payload)` → `state_changed.emit("AliveState", "AliveState")`.

**의도**: Tier 1은 *기본 false*. Tier 2 적 archetype에서 IDLE→IDLE *재시작*이 필요한 경우(예: 적이 새 patrol 경로로 리셋)에만 true 사용.

**검증**: AC-08 (force_re_enter false 시 enter/exit 미호출), AC-09 (true 시 호출).

#### E-6 — 큐 cap 초과 (cascade)

**상황**: 적 archetype의 `enter()`가 `transition_to`를 4회 연속 트리거 (디자인 결함).

**동작**:

1. Q_depth가 1→2→3→4까지 enqueue 정상 진행.
2. 5번째 호출에서 D.4 cap 체크 → `push_error("StateMachine cascade — Q_depth exceeded cap (= 4)")` + 5번째 항목 폐기.
3. 큐 처리 종료 후 SM은 *4번째 enqueue까지의 상태*로 정착.

**의도**: 결함 *마스킹*이 아닌 *조기 발견*. push_error는 디버그 빌드에서 콘솔 + 디버거 break. Tier 1 prototype에서 발견 시 디자인 수정 필수.

**검증**: AC-20 (5회 cascade 시 push_error 발생 + 4 entries만 전이됨).

#### E-7 — 큐 flush 도중 새 `transition_to` 도착

**상황**: 큐의 첫 항목 enter()가 또 다른 `transition_to`를 enqueue.

**동작**:

1. flush 진행 중에도 `_is_transitioning = true` 유지.
2. 새 호출은 큐 *끝*에 추가 (FIFO).
3. flush 루프가 큐가 빌 때까지 계속.

**Edge**: 무한 루프 위험 — *cap*이 안전망 (E-6).

#### E-8 — Boot 호출 누락

**상황**: 호스트가 `_ready()`에서 `boot()`를 잊어 `current_state == null`.

**동작**:

1. 호스트 `_physics_process` → `state_machine.physics_update(delta)` → `current_state == null` 체크 → return.
2. 시그널 도착 시 가드 2번이 폐기 (E-3과 동일).
3. SM은 *영구 무동작* 상태로 남음.

**검증**: AC-19 — boot 미호출 시 SM이 어떤 시그널/tick에도 응답하지 않음 (silent freeze 대신 *명시적 비활성*).

### E.3 라이프사이클 / 외부 이벤트 (Lifecycle & External)

#### E-9 — Pause 입력 — DYING/REWINDING 중 swallow

**상황**: ECHO가 DYING 또는 REWINDING 상태에서 플레이어가 Start 버튼.

**동작**:

1. Pause 시스템(#18)이 `EchoLifecycleSM.should_swallow_pause() -> bool`를 polling.
2. SM이 `current_state.name in pause_swallow_states` 체크 → DyingState/RewindingState면 true 반환.
3. Pause 시스템은 true 수신 시 pause UI를 띄우지 않음. 입력 폐기.

**의도**: Time Rewind GDD Rule 18 — 12프레임 grace를 *분석 시간*으로 변환 방지.

**검증**: AC-16 (DYING/REWINDING 중 pause 입력은 시각/오디오 응답 0).

#### E-10 — DEAD 상태 입력

**상황**: ECHO가 DEAD 상태에서 어떤 입력 (이동, 사격, rewind_consume).

**동작**:

1. DeadState의 `physics_update`가 `_frames_in_state`만 증가시킴 (별도 만료 없음 — Scene Manager가 transition).
2. DeadState는 `handle_*` 핸들러를 구현하지 않음 → 모든 시그널이 가드 3에서 폐기 (E-4).
3. ECHO PlayerMovement의 `physics_update`도 자체적으로 DeadState 감지 시 입력 무시 (PlayerMovement GDD 소관).

**의도**: 부활 경로 없음. Scene Manager의 체크포인트 재로드만이 ALIVE 복귀 경로.

**검증**: AC-26 (DeadState 진입 후 모든 입력은 ECHO 위치 무변경 — 신규 H.4 추가).

#### E-11 — `scene_will_change` 도중 DYING

**상황**: ECHO가 DYING 상태인데 (12프레임 grace 진행 중), 동시에 다른 트리거가 Scene Manager의 `scene_will_change`를 emit.

**동작**:

1. SM의 `_on_scene_will_change` 핸들러가 `_lethal_hit_latched = false`, `_rewind_input_pressed_at_frame = -1`로 리셋.
2. State는 *변경하지 않음* — DyingState 유지.
3. Scene Manager가 곧이어 씬 unload → ECHO 노드 자체가 destroy. SM도 함께 사라짐.
4. 다음 씬 로드 후 새 ECHO 인스턴스의 `EchoLifecycleSM._ready()` → `boot(AliveState)` 호출 → ALIVE 시작.

**의도**: 씬 경계에서 SM은 *ephemeral 변수만 클리어*. 상태 자체 전이는 호스트 노드 destruction에 위임.

**검증**: AC-18 (씬 전환 시 래치/입력 버퍼 초기값 + AC-19 다음 씬에서 boot이 호출되어 ALIVE 시작).

### E.4 오용 방지 (Misuse Prevention)

#### E-12 — 외부에서 `current_state` 직접 교체 시도

**상황**: 다른 시스템 코드가 `state_machine.current_state = some_node`를 시도 (잘못된 패턴).

**동작 (정적 타입 GDScript)**:

1. `current_state`는 **read-only로 의도되어 있다** — `var` 선언이지만 *외부 쓰기는 코드 리뷰에서 차단*.
2. `transition_to()` 외 경로로 `current_state` 변경 시 `_is_transitioning` 플래그가 false 상태로 머무르고 `state_changed` 시그널이 emit되지 않음 → 디버그 오버레이/로그가 *침묵*.
3. 자동 검출 불가능 → **AC-21**: GUT 테스트가 직접 할당 시도 → `state_changed` 시그널 미발생을 확인 (사용자 코드는 항상 `transition_to()` 사용해야 함을 강제).

**의도**: 솔로 개발 + 코드 리뷰 강도 낮음 — 정적 검사로 강제할 수 없으나 *결정적으로 오작동하는* 디자인으로 위반을 빠르게 노출.

#### E-13 — Host 노드 해결 실패

**상황**: State가 `_ready()`에서 `host = get_parent().get_parent()` 체인을 시도하나 부모 구조가 잘못됨.

**동작**:

1. `host == null` 시 모든 `physics_update` / `handle_*`이 *State 차원에서* `host == null` 가드를 거쳐 return.
2. SM `boot()` 시점에 `current_state.host == null`이면 `push_error("State host unresolved")` + `boot()` 거부.
3. 호스트 엔티티는 *비활성*으로 씬에 남음. 디자이너가 즉시 발견.

**의도**: silent 미동작이 아니라 *명시적 에러 + 거부*로 노출.

#### E-14 — 시그널 arg arity 불일치

**상황**: Damage가 `player_hit_lethal(cause: StringName)` 1-arg signal로 변경했는데, SM 핸들러가 0-arg를 가정.

**동작 (Godot 4 strict-typed signal)**:

1. `damage.player_hit_lethal.connect(_on_damage_lethal)` 시점에 connect 자체는 성공.
2. emit 시 Godot 런타임이 `_on_damage_lethal()` 시그니처와 emit args를 비교 → 불일치 시 콘솔 에러 + 호출 중단.
3. SM은 latch set + 전이 모두 발생하지 않음.

**의도**: 타입 안전 시그널 의무 — 모든 SM 핸들러는 시그널 시그니처와 *정확히* 일치하는 인자를 받아야 함. (AC-22)

#### E-15 — 동시 다중 SM의 시그널 처리 순서

**상황**: Time Rewind이 emit한 `rewind_started`를 EchoLifecycleSM + HUD + VFX + Audio + 적 archetype 5종이 모두 구독.

**동작**:

1. Connect 순서: ECHO 자식이 먼저 ready 됨 → EchoLifecycleSM이 1번. 다음 HUD, VFX, Audio. 적은 가장 늦게 (스폰 순간).
2. 시그널 emit 시 connect 순서대로 *동기 호출*. 한 핸들러가 *다음 핸들러를 차단할 수 없음* (Godot 시그널 모델).
3. EchoLifecycleSM의 핸들러가 다른 시그널을 emit하더라도, *원본 시그널의 다음 connect 핸들러*는 영향받지 않음.

**의도**: Connect 순서는 *결정적*이지만 *서로 격리됨*. SM은 다른 구독자의 동작을 가정하지 않음.

**검증**: AC-24 (동일 입력으로 1000회 실행 시 시그널 핸들러 호출 순서 동일).

---

## F. Dependencies

State Machine Framework는 Foundation 계층 시스템으로 *어떤 시스템에도 컴파일-타임 의존이 없다*. 의존 관계는 모두 (1) **시그널 구독**(upstream) 또는 (2) **컴포지션 클라이언트**(downstream) 형태로만 발생한다. 본 섹션은 두 방향 + 양방향 명시 검증 상태를 기술한다.

### F.1 Upstream — 시그널 소비자 (선택적)

본 프레임워크의 *기본 클래스* `State` / `StateMachine`은 어떤 외부 시그널도 모른다. **EchoLifecycleSM 인스턴스만이** 다음 4 시스템의 시그널을 구독한다 (C.3.4 connect 순서):

| Producer 시스템 | 시그널 | SM 핸들러 | 효과 | 상태 |
|---|---|---|---|---|
| **#8 Damage / Hit Detection** | `player_hit_lethal(cause: StringName)` | `_on_damage_lethal` | latch set + `transition_to(DyingState)` | **이미 Designed** — [`design/gdd/damage.md`](damage.md) C.3.1 / DEC-1. AC-22 1-arg `cause: StringName` 락인. SM은 `damage.commit_death()` / `cancel_pending_death()` invoke (damage.md F.4). **`RewindingState.exit()` 의무 (Round 3 추가)**: `echo_hurtbox.monitorable = true` 복귀 *직후* `damage.start_hazard_grace()` 1회 호출 (damage.md DEC-6 — 12프레임 hazard-only grace 트리거). `RewindingState.enter()` 의무 (DEC-4): `echo_hurtbox.monitorable = false`. |
| **#9 Time Rewind System (TRC)** | `rewind_started(remaining_tokens: int)` | `_on_rewind_started` | `transition_to(RewindingState)` | **이미 Designed** — `design/gdd/time-rewind.md` 계약 락인 |
| **#9 Time Rewind System (TRC)** | `rewind_completed(player: Node2D, restored_to_frame: int)` | `_on_rewind_completed` | RewindingState.handle_*에서 처리 (i-frame 카운트 시작 트리거) | **이미 Designed** |
| **#9 Time Rewind System (TRC)** | `rewind_protection_ended(player: Node2D)` | `_on_rewind_protection_ended` | `transition_to(AliveState)` | **이미 Designed** — ADR-0001 rewind_lifecycle 계약 확장 |
| **#2 Scene / Stage Manager** | `scene_will_change()` | `_on_scene_will_change` | latch + 입력 버퍼 ephemeral 변수 클리어 (E-11) | Scene Manager GDD 미작성 — *provisional contract* |
| **#1 Input System** | (시그널 아님 — 폴링) `Input.is_action_just_pressed("rewind_consume")` | AliveState/DyingState `physics_update`에서 폴링 | `_rewind_input_pressed_at_frame` 갱신 | Input GDD 미작성 — `InputMap` action 이름은 *provisional* |

추가로 **적 archetype별 SM (DroneAISM)** 은 #8 Damage의 `enemy_hit` 시그널을 구독할 가능성이 있으나 Tier 2 시점 결정 (Enemy AI GDD 소관).

### F.2 Downstream — 프레임워크 클라이언트

다음 시스템은 본 프레임워크의 `State` / `StateMachine` 클래스를 *컴포지션*하여 자체 머신을 구축한다 — *컴파일-타임 의존*이 발생.

| Client 시스템 | 머신 이름 | 노드 위치 | Tier | GDD 작성 시 의무 |
|---|---|---|---|---|
| **#9 Time Rewind System** | EchoLifecycleSM | ECHO 자식 (priority 0 슬롯 상속) | Tier 1 | `design/gdd/time-rewind.md` Section C에서 SM에 부과한 6 의무 (C.2.2) — **이미 작성됨** |
| **[#6 Player Movement](player-movement.md)** | PlayerMovementSM | PlayerMovement(CharacterBody2D root) 자식 (별도 SM 노드, EchoLifecycleSM과 sibling) | Tier 1 | **PM #6 Designed 락인 (2026-05-10)**: `class_name PlayerMovementSM extends StateMachine` — 본 framework의 M2 reuse 검증 케이스. PlayerMovementSM은 Tier 1 **6 states** (`idle/run/jump/fall/aim_lock/dead`, DEC-PM-1 — `hit_stun`은 damage.md DEC-3 binary 모델로 제거; dash/double_jump/wall_grip은 Tier 2 deferred). EchoLifecycleSM과는 **독립 (Tier 1 flat 컴포지션 — NOT parallel ownership)** — `dead` state는 EchoLifecycleSM `state_changed(_, &"DYING")` / `(_, &"DEAD")` signal에 *reactive*하게 force 전이 (player-movement.md T13). 부모 framework의 transition queue + `_is_transitioning` atomicity 인헤리트 (player-movement.md C.2.5). Framework 코드 변경 금지 (본 GDD C.2.1 line 206). |
| **#10 Enemy AI Base + Archetypes** | DroneAISM (보안 드론 등) | 적 엔티티 자식 (priority 10 슬롯 상속) | Tier 1 (1 archetype 검증) | Enemy AI GDD가 archetype별 5-7 상태 정의. C.4.1 M2 |
| **#11 Boss Pattern System** | StriderBossSM | 보스 엔티티 자식 (priority 10 슬롯 상속) | Tier 1 (STRIDER 1보스 검증) | Boss Pattern GDD가 phase별 상태 정의. C.4.1 M3 |
| **#19 Pickup System** (Tier 2) | (가능성) PickupBehaviorSM | 픽업 엔티티 자식 | Tier 2 | Pickup GDD가 idle/collected/expired 등 상태 정의 시 |

### F.3 Indirect Touchpoints — 시그널 *주변* 시스템

다음 시스템은 SM과 *직접 의존*하지는 않으나, SM 동작에 영향을 받음:

| 시스템 | 영향 형태 | 상호작용 |
|---|---|---|
| **#13 HUD System** | `boss_defeated` 토큰 시각 갱신을 `rewind_protection_ended`까지 지연 (C.2.2 O5) | HUD가 SM 시그널 직접 구독 안 함 — TRC의 `token_replenished`만 구독하나 *타이밍 정책*은 SM이 보장 |
| **#18 Menu / Pause System** | `EchoLifecycleSM.should_swallow_pause()` polling (E-9) | Pause 시스템이 SM에 *호출* — SM은 read-only 응답만 |
| **#14 VFX / Particle System** | `state_changed` 시그널 구독 (선택) | VFX가 DYING 진입 시 시각 펄스, REWINDING 진입 시 글리치 트리거 가능 — 본 프레임워크는 시그널만 emit, 의존 없음 |
| **#4 Audio System** | `state_changed` 시그널 구독 (선택) | DYING 진입 SFX, REWINDING 진입 SFX 트리거. VFX와 동형 |

### F.4 양방향 명시 검증 (Bidirectional Mirror Verification)

`design/CLAUDE.md` 규칙: *A가 B에 의존하면 B의 doc도 A를 멘션*. 본 GDD가 의존하는 4개 시스템 + 본 GDD를 의존하는 4개 시스템에 대한 양방향 상태:

| Direction | 시스템 | B doc → A 멘션 | 상태 |
|---|---|---|---|
| F.1 (SM ← 의존) | #8 Damage | `design/gdd/damage.md` | **이미 멘션** (2026-05-09) — Damage GDD F.2 (player_hit_lethal 구독자 = #5 SM) + F.3 (시그널 카탈로그) + F.4 (commit_death/cancel_pending_death invocation API) |
| F.1 (SM ← 의존) | #9 Time Rewind | `design/gdd/time-rewind.md` | **이미 멘션** — Rule 4-7, Rule 17-18, Section C 표, F dependencies, signals (C.2.2 cross-link) |
| F.1 (SM ← 의존) | #2 Scene Manager | `design/gdd/scene-manager.md` | **미작성** |
| F.1 (SM ← 의존) | #1 Input System | `design/gdd/input-system.md` | **미작성** |
| F.2 (SM → 의존됨) | #9 Time Rewind | `design/gdd/time-rewind.md` | **이미 멘션** — `*(provisional)*` 표시는 본 GDD designed 후 제거 의무 (Task #9) |
| F.2 (SM → 의존됨) | #6 Player Movement | [`design/gdd/player-movement.md`](player-movement.md) | **이미 멘션** (2026-05-10 PM #6 Designed) — F.1 #5 row가 PlayerMovementSM `extends StateMachine` (M2 reuse) + framework 코드 변경 금지 명시 + EchoLifecycleSM 독립 (Tier 1 flat composition, NOT parallel ownership) + `dead` state는 EchoLifecycleSM `state_changed` reactive force (T13). C.1 / C.2.5 transition queue + `_is_transitioning` atomicity 인헤리트. 본 행은 *bidirectional hygiene 갱신* (player-movement.md F.4.1 #2가 직접 위임한 F.2 표는 line 843 — 이미 PM 락인 적용됨). |
| F.2 (SM → 의존됨) | #10 Enemy AI | `design/gdd/enemy-ai.md` | **미작성** |
| F.2 (SM → 의존됨) | #11 Boss Pattern | `design/gdd/boss-pattern.md` | **미작성** |

**즉시 조치 (Task #9)**: 본 GDD `Designed` 상태 진입 후 `design/gdd/time-rewind.md`의 다음 행에서 *(provisional)* 표기 제거 + 링크 추가:

```diff
- | #5 | State Machine Framework *(provisional)* | SM이 사망 순간의 단일 중재자. ...
+ | [#5](state-machine.md) | State Machine Framework | SM이 사망 순간의 단일 중재자. ...
```

**미작성 GDD 양방향 의무 (Future)**: Damage/Scene Manager/Input/Player Movement/Enemy AI/Boss Pattern GDD 작성 시, 각 GDD의 Dependencies 섹션은 본 GDD를 명시 (link + Tier 1/2 책임). systems-index.md의 Depends On 컬럼은 이미 정확함 (확인 완료 — Section #6/#10/#11에 "State Machine" 명시).

### F.5 컴파일-타임 의존 분석

본 프레임워크의 *클래스 정의*는 다음 외부 클래스를 import하지 않는다:

- `State.gd`: extends `Node`. 외부 import: 없음.
- `StateMachine.gd`: extends `Node`. 외부 import: 없음 (`State` 클래스는 같은 디렉터리 sibling으로 `class_name`로 해결).

**즉**: `src/core/state_machine/`은 다른 어떤 시스템 코드도 참조하지 않는다. 다른 시스템이 SM을 import한다 — 단방향. 이 *역방향 청결도*가 Foundation 계층의 정의.

### F.6 Forbidden Compositions

다음 패턴은 본 프레임워크 사용 시 *금지*:

- **State가 다른 State 노드를 import** — 같은 SM 안의 sibling State끼리 직접 참조 금지. 전이는 항상 `state_machine.transition_to(...)` 경유. (위반 시 코드 리뷰 거부)
- **State가 다른 엔티티의 SM을 호출** — 적 SM이 ECHO SM의 `transition_to`를 호출 등. 시그널을 emit해서 ECHO SM이 자체 결정하도록 한다. (이유: cross-entity 강결합 = 결정성 위협)
- **Autoload Singleton에 SM 인스턴스화** — Time Rewind GDD/ADR이 TRC를 *Autoload 또는 노드 둘 중 하나*로 두는 것은 허용했으나, EchoLifecycleSM 자체는 *반드시 ECHO 자식 노드*. 씬 재로드 시 라이프사이클 동기화 보장 위해.

---

## G. Tuning Knobs

State Machine Framework는 *튜닝 가능한 값이 거의 없는 시스템*이다. 의도적으로 그러하다 — framework의 정확성은 *값이 아니라 invariant*에서 나오므로, knob을 늘릴수록 결정성 검증 표면이 커진다. 본 섹션은 (1) framework가 직접 소유하는 3개 knob, (2) framework가 *명시적으로 거부*하는 knob 후보 4개, (3) 외부 GDD에서 import되는 knob 2개를 표 형태로 정리한다.

### G.1 Framework Owned Knobs (1 knob + 1 framework invariant)

> **Round 1 design-review changes**: `Q_cap` 제거 (B6 — `TRANSITION_QUEUE_CAP` 클래스 const로 승격, knob 아님 — D.1/D.4/D.7 참조). `pause_swallow_states`는 **framework invariant**로 잠금 (B2 — Time Rewind Rule 18 위반 방지).

| Field | 위치 | 타입 | Safe Range | 기본값 | 영향 받는 게임플레이 측면 | 변경 시 재검증 |
|---|---|---|---|---|---|---|
| **`pause_swallow_states`** *(invariant)* | `EchoLifecycleSM` 멤버 (export 아님) | `Array[StringName]` | **고정 `[&"DyingState", &"RewindingState"]` — override 금지** | `[&"DyingState", &"RewindingState"]` | DYING/REWINDING 중 pause swallow는 Time Rewind GDD Rule 18 ("12프레임 grace를 *분석 시간*으로 변환 방지") 직접 인용. Easy 모드는 본 필드를 *override 금지* — `D` (`dying_window_frames`) 또는 `starting_tokens` 같은 별도 knob을 통해서만 난이도 조정. | 변경 불가 (framework invariant). |
| **`debug_overlay_enabled`** | `StateMachine` export var | bool | true / false | **false** (Tier 1) → **true** (Tier 2) | 디버그 빌드에서 우상단에 `[ECHO] ALIVE → DYING (frame 12345)` 라벨 표시. *런타임 비용 < 0.01ms* — 성능 영향 무시 가능. | Tier 2 게이트에서 debug 빌드 기본값을 true로 승격. |

### G.2 Imported Knobs (외부 GDD 소유, 본 GDD 참조만)

| Knob | 출처 | 본 GDD에서 사용 | 변경 권한 |
|---|---|---|---|
| **`D` (dying_window_frames)** | `RewindPolicy` resource (Time Rewind GDD Section G) | DyingState `_frames_in_state` 만료 임계 (D.5) | Time Rewind GDD 소유. 본 GDD는 8–18 범위 내라면 어떤 값도 *호스팅 가능* 보장. |
| **`B` (input_buffer_pre_hit_frames)** | `RewindPolicy` resource (Time Rewind GDD Section G) | 입력 버퍼 윈도우 predicate 시작점 (D.2) | Time Rewind GDD 소유. 본 GDD는 **2–6** 범위 호스팅 (range owner = `time-rewind.md`; B1 — Round 1 design-review로 정정, 이전 잘못된 `2–8` 표기). |

본 GDD가 `D`/`B`를 *수정 권한 없이 호스팅한다*는 명시는 systems-designer가 framework 결함과 게임플레이 튜닝을 혼동하지 않게 하는 가드.

### G.3 *명시적으로* 거부된 Knob 후보 (4개)

다음은 "knob이 될 수도 있어 보이지만 framework 차원에서 거부"한다. 거부 이유와 함께 명시.

| 후보 | 거부 이유 | 대안 |
|---|---|---|
| **`R` (rewind_protection_frames)** | 30프레임 i-frame은 *시각 시그니처*와 단일 출처(`REWIND_SIGNATURE_FRAMES` const). 변경 시 셰이더/오디오/AC 모두 다시 튜닝 필요 — 솔로 budget 초과. | Time Rewind GDD가 const로 락인. 변경 시 ADR 필요. |
| **시그널 connect 순서** | 결정성 invariant. 동적 순서 변경은 1000-cycle 테스트 결과를 *예측 불가능*하게 만든다. | C.3.4의 코드 라인 순서를 *유일한* 출처로 사용. |
| **State별 transition cooldown** | 대다수 SM 디자인 패턴이 제공하나, ECHO/적/보스 머신 설계에서 *어떤 상태도 cooldown이 필요하지 않음* (모든 만료는 `_frames_in_state` 카운터로 충분). knob 도입 = 미사용 코드 = 솔로 budget 침식. | 필요 시 State 자체에 `_frames_since_X` 필드 추가. framework 책임 아님. |
| **자동 시그널 라우팅 disable 토글** | `dispatch_signal`이 비활성화되면 framework의 핵심 안전망(latch, null 가드)이 우회됨. `bool` 한 값이 결정성을 깨는 *원격 무기*가 됨. | 핸들러를 단순히 미구현하면 자동 폐기 (E-4) — 별도 토글 불필요. |

### G.4 Tier별 Knob 활성화 일정

| Tier | 활성 Knob | 비고 |
|---|---|---|
| **Tier 1 (4-6주)** | `TRANSITION_QUEUE_CAP=4` (const), `pause_swallow_states=[DyingState, RewindingState]` (invariant) | `debug_overlay_enabled=false` (`print_debug` 한 줄로 대체) |
| **Tier 2 (6개월 누계)** | + `debug_overlay_enabled=true` (debug 빌드 기본값) + `_state_history` ring buffer | 1000-cycle 결정성 테스트 자동 실행 시 history 비교 도구로 사용 |
| **Tier 3 (16개월 출시)** | 추가 knob 0. **Easy 모드는 `pause_swallow_states` override 금지** (B2 — Time Rewind Rule 18 invariant). Difficulty Toggle (#20)은 `RewindPolicy.dying_window_frames` (D=8/16/18) 또는 `RewindPolicy.starting_tokens` 같은 *Time Rewind 소유 knob*만 조정. | Difficulty Toggle GDD가 본 GDD invariant를 *읽기 전용* 클라이언트로 등록. |

### G.5 *Knob 추가 거부 정책*

본 GDD에 knob을 추가하려는 후속 PR은 다음 3 질문에 모두 *yes*를 답하지 않으면 거부된다:

1. 이 knob을 *변경*하면 1000-cycle 결정성 테스트가 *여전히 PASS*하는가?
2. 이 knob의 safe range가 명시 가능한가? (open-ended 범위 = 거부)
3. 이 knob이 영향 미치는 게임플레이 측면이 *현존하는 GDD 한 개에 1:1로 매핑*되는가?

이 정책은 framework가 "범용 SM 라이브러리"로 부풀어나가는 것을 차단한다. 솔로 budget의 명시적 보호.

---

## H. Acceptance Criteria

총 **28개** acceptance criteria (Round 1 design-review B4 신규 AC-17a + B8 신규 AC-27 추가). *Logic*(GUT 자동 테스트, BLOCKING)이 **26개**, *Integration*(통합 테스트 또는 문서화된 플레이테스트, BLOCKING)이 **2개** (AC-23 + AC-25). 시각/UI ACs 0개 — Foundation 시스템이라 visual evidence 부재. 모든 AC는 Tier 1 prototype 종료 시점까지 PASS해야 한다.

> **Round 1 design-review fixes**: 카운트 산수 정정 (Logic 23/Integration 3 → Logic 25/Integration 2; AC-24 + AC-26은 Logic, AC-23 + AC-25만 Integration); AC-22 (a) 헤드리스 GUT assertable 아니므로 advisory로 강등; AC-25 측정 방법 `Time.get_ticks_usec()` instrumentation 명시; AC-14 verification은 `Object.get_signal_connection_list()` post-`_ready()` 조회로 변경; 신규 AC-17a (B4 intra-tick ordering); 신규 AC-27 (E-13 host==null boot 거부).
> **Round 2 design-review fix (2026-05-10)**: B8 카운트 산수 잔여 결함 정정 — AC-17a가 별도 행으로 enumerated되었으므로 AC-17의 sub-clause가 아닌 독립 카운트. 28 = Logic 26 + Integration 2 (mechanical row count via `grep -c`). H.7 Tier 1 게이트 row에 AC-17a 명시 추가.

### H.1 Framework Primitives (AC-01 ~ AC-05)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-01** | `State` 클래스가 `Node`를 상속하며 `host`, `enter()`, `exit()`, `physics_update(delta)` 4개 멤버를 제공한다. 기본 구현은 모두 no-op (`enter`/`exit`/`physics_update` 호출 시 콘솔 출력 0). | GUT: `State.new()` 인스턴스 호출 → `has_method` 검증 + 호출 시 부작용 0 확인 | Logic |
| **AC-02** | `StateMachine` 클래스가 `Node`를 상속하며 `current_state`, `last_transition_frame`, `state_changed` 시그널 + `boot()`, `transition_to()`, `physics_update()`, `dispatch_signal()` 메서드를 제공한다. | GUT: `StateMachine.new()` 인스턴스에서 `has_method` + `has_signal` 검증 | Logic |
| **AC-03** | `boot(initial_state, payload)` 호출 시 (a) `current_state == initial_state` (b) `initial_state.enter(payload)` 정확히 1회 호출 (c) `state_changed("", "InitialStateName")` emit 1회. | GUT: spy State 사용. 호출 횟수 + 시그널 카운터로 검증 | Logic |
| **AC-04** | 호스트가 `state_machine.physics_update(0.0167)` 호출 시 `current_state.physics_update(0.0167)`이 정확히 1회 호출된다. `current_state == null`이면 호출 0회 (silent return). | GUT: spy State + null 분기 두 케이스 | Logic |
| **AC-05** | `dispatch_signal(&"foo", [arg1, arg2])` 호출 시 `current_state.handle_foo(arg1, arg2)`가 정확히 1회 호출된다. 핸들러가 없으면 호출 0회 + 콘솔 청결. | GUT: spy State + 핸들러 유/무 두 케이스 | Logic |

### H.2 Transition Atomicity (AC-06 ~ AC-09)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-06** | 정상 `transition_to(B)` 호출 시 (a) `current_state.exit()` 호출 (b) `current_state := B` (c) `last_transition_frame := Engine.get_physics_frames()` 갱신 (d) `B.enter(payload)` 호출 (e) `state_changed("A_name", "B_name")` emit. 순서 a→b→c→d→e가 *strict*. | GUT: spy A/B + emit 순서 캡처 + frame counter mock | Logic |
| **AC-07** | A의 `enter()` 안에서 `transition_to(C)`를 호출하면 (a) C로의 전이는 *큐잉됨* (b) A의 `enter()`가 *완료된 후* C 전이가 atomic 실행된다 (c) `state_changed`는 두 번 emit (`"" → "A"` + `"A" → "C"`) (d) 두 emit 모두 같은 `Engine.get_physics_frames()` 값에 발생. | GUT: enter() 안에서 transition 트리거하는 spy + 시그널 타이밍 검증 | Logic |
| **AC-08** | `transition_to(current_state, force_re_enter=false)` 호출 시 (a) `current_state.exit()` 미호출 (b) `current_state.enter()` 미호출 (c) `state_changed` 미emit. | GUT: spy State에서 enter/exit 카운터 = 1 (boot 1회 외 추가 0회) | Logic |
| **AC-09** | `transition_to(current_state, force_re_enter=true)` 호출 시 AC-06의 절차가 정상 실행된다 (`exit` → 객체 재할당 → `enter` → emit). `from_name == to_name`인 emit이 발생. | GUT: AC-08과 동일 spy, force_re_enter 인자만 변경 | Logic |

### H.3 Signal Handling Guards (AC-10 ~ AC-13)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-10** | `current_state == null` 상태에서 `dispatch_signal(&"any", [])` 호출 시 (a) 핸들러 호출 0회 (b) 콘솔 에러/경고 0회 (c) `state_changed` emit 0회. | GUT: boot() 호출 *전*에 dispatch 시도 | Logic |
| **AC-11** | dispatch_signal 가드 평가 순서가 *latch first* (D.3 1번): `_lethal_hit_latched == true`이면 `name == &"player_hit_lethal"`인 경우 핸들러가 *구현되어 있어도* 호출되지 않는다. | GUT: latch 수동 set + AliveState `handle_player_hit_lethal` 구현 → dispatch → 호출 0회 검증 | Logic |
| **AC-12** | 같은 물리 틱에 `Damage.player_hit_lethal`을 두 번 emit 시 (a) ALIVE→DYING 전이 정확히 1회 (b) `_lethal_hit_latched`가 첫 emit 직후 true (c) 두 번째 emit이 가드 1번에서 폐기 (d) `_state_history`에 단일 entry. | GUT: 두 번 emit 시뮬레이션 + history 카운트 | Logic |
| **AC-13** | E-4 핸들러 미구현: `current_state` (예: AliveState)가 `handle_rewind_started`를 *미구현* 상태에서 TRC가 `rewind_started` emit 시 (a) 콘솔 청결 (b) SM 상태 무변경 (c) 다음 `dispatch_signal` 호출은 정상 동작. | GUT: 핸들러 의도적 누락한 spy State | Logic |

### H.4 ECHO Machine Hosting (AC-14 ~ AC-19, AC-26, AC-27)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-14** | `EchoLifecycleSM`은 `_connect_signals()`에서 시그널을 다음 *정확한* 순서로 connect한다 (모두 `CONNECT_DEFAULT`, no flags): (1) Damage.player_hit_lethal (2) TRC.rewind_started (3) TRC.rewind_completed (4) TRC.rewind_protection_ended (5) SceneManager.scene_will_change. 순서 변경 또는 `CONNECT_DEFERRED` 사용 시 본 AC 실패. | GUT (Round 1 B5 + Round 1 godot-specialist F1): `_ready()` 완료 후 `await get_tree().process_frame` (deferred flush) → `Damage.get_signal_connection_list(&"player_hit_lethal")[0].callable.get_method() == &"_on_damage_lethal"` 확인. TRC 4 시그널·SceneManager 1 시그널 동일 패턴. 각 connection의 `flags` 필드가 0(CONNECT_DEFAULT)인지 검증. | Logic |
| **AC-15** | O1 latch: `ALIVE → DYING` 전이 직후 `_lethal_hit_latched == true`. `REWINDING → ALIVE`, `REWINDING → DEAD`, **그리고 `DYING → DEAD` direct path** (grace 만료 시 — I2 fix 2026-05-10, time-rewind.md AC-C2 reciprocal) 전이 직후 모두 `false`. 다른 전이에서는 변화 없음. | GUT: 5 전이 시나리오 각각(`ALIVE→DYING` set / `DYING→REWINDING` 유지 / `REWINDING→ALIVE` clear / `REWINDING→DEAD` clear / `DYING→DEAD` clear) 에서 latch 값 검증 | Logic |
| **AC-16** | O2 pause swallow: `should_swallow_pause()`가 반환하는 값은 (a) ALIVE 상태에서 `false` (b) DYING 상태에서 `true` (c) REWINDING 상태에서 `true` (d) DEAD 상태에서 `false`. | GUT: 4 상태 각각에서 polling 결과 검증 | Logic |
| **AC-17** | O3 입력 버퍼: `D=12, B=4` 기본값에서 D.2 표의 5개 시나리오가 모두 정확히 판정된다 (in/out). 추가: `F_input == -1` (입력 미발생) 시 절 1(`F_input >= 0`)이 false → predicate false (B3 sentinel guard). | GUT: F_lethal 고정 + F_input 5 case + sentinel `-1` case → predicate 평가 | Logic |
| **AC-17a** *(신규 Round 1 B4)* | DyingState intra-tick ordering: fixture가 `_frames_in_state = D - 1` (default 11) 상태로 진입한 DyingState에 같은 틱 내 `Input.is_action_just_pressed("rewind_consume")` 주입 시 (a) `transition_to(RewindingState)` 호출 발생 (b) `damage.commit_death()` 호출 0회 (c) `_frames_in_state` 증가 0회 (입력 분기에서 early return). 위반 시 마지막 valid 프레임 입력이 silent dropped. | GUT: D.5 ordering rule 검증 — DyingState mock에 frame counter pre-set + input mock + transition spy + commit_death spy. | Logic |
| **AC-18** | O6 scene 클리어: `scene_will_change` 시그널 도착 시 (a) `_lethal_hit_latched == false` (b) `_rewind_input_pressed_at_frame == -1` (c) `current_state` 미변경. | GUT: latch+버퍼를 임의 값으로 set → 시그널 emit → 검증 | Logic |
| **AC-19** | E-8 boot 미호출 silent: 호스트가 `boot()` 호출을 누락한 경우 (a) `physics_update` 호출 시 0회 위임 (b) 시그널 도착 시 0회 핸들러 호출 (c) 콘솔 청결. *영구 비활성*. | GUT: boot 미호출 시 5종 입력 모두 응답 0 검증 | Logic |
| **AC-26** | E-10 DEAD 상태 입력 무응답: `current_state == DeadState`일 때 (a) DeadState는 `handle_*` 핸들러를 *구현하지 않음* → 모든 시그널이 D.3 가드 3번에서 폐기 (b) `physics_update`는 `_frames_in_state`만 증가 (c) `state_changed` 미emit (전이 없음). 부활 경로 없음 — Scene Manager 재로드만이 ALIVE 복귀 경로. *주의*: 본 AC는 SM 차원에서의 무응답을 검증할 뿐, 다운스트림 시스템(VFX/Audio/HUD)이 Damage의 `death_committed` 시그널에 응답하여 사망 피드백을 표현하는 것은 *차단하지 않음* (game-designer F5 advisory — DEAD silence는 SM 차원이며 player feedback은 Damage GDD F.3 다운스트림이 소유). | GUT: DeadState 진입 후 5종 시그널 emit + 입력 polling → SM 상태 무변화 + state_changed 카운터 == 0 검증 | Logic |
| **AC-27** *(신규 Round 1 B8)* | E-13 host==null boot 거부: `State` 인스턴스의 `host`가 `_ready()` 후 null로 남은 경우 `boot(state)` 호출 시 (a) `push_error("State host unresolved")` 정확히 1회 발생 (b) `current_state == null` 유지 (boot 거부) (c) 이후 `physics_update` 호출 시 0회 위임 (AC-19와 동일 silent path) (d) 시그널 도착 시 가드 2번에서 폐기. *명시적 비활성*. | GUT: host 미할당 State spy → boot() 호출 → push_error capture (`OS.has_feature("debug")` 환경) + current_state 검증 + 5종 입력 응답 0 검증. | Logic |

### H.5 Cascade & Misuse (AC-20 ~ AC-22)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-20** | E-6 큐 cap: `enter()`가 `transition_to`를 5회 연속 호출하는 디자인 결함 시 (a) 4번째 enqueue까지 정상 (b) 5번째 호출에서 `push_error` 발생 (c) 5번째 항목 폐기 (d) SM은 4번째 enqueue 결과 상태로 정착. | GUT: enter() 안에서 5회 transition 호출하는 spy + push_error 캡처 | Logic |
| **AC-21** | E-12 직접 할당 검출: 외부 코드가 `state_machine.current_state = some_state`로 직접 할당 시 (a) `state_changed` 시그널 미emit (b) `_is_transitioning` 플래그 변화 없음. **이 AC는 *명시적 침묵 시그니처*를 보장하는 negative test**. | GUT: 직접 할당 시도 → state_changed 카운터 == 0 검증 | Logic |
| **AC-22** | E-14 arity 불일치 (Round 1 B8): SM 핸들러가 시그널 시그니처와 인자 수가 다를 때 emit 시 **(a — BLOCKING)** `_lethal_hit_latched` 변화 0회 + `current_state` 변화 0회 + `state_changed` emit 0회. **(b — advisory)** Godot 콘솔 에러 발생 — 헤드리스 GUT에서 `print-error` 캡처 불가능하므로 *플레이테스트 시 육안 확인*으로 대체. **전제 조건**: 모든 `handle_*` 메서드는 정적 타입 인자 사용 (`func handle_foo(cause: StringName) -> void`, NOT `func handle_foo(cause)`) — 이 전제 없이는 (a)도 보장 안 됨 (godot-specialist FINDING-4). | GUT: 의도적으로 arg 수 불일치 → emit → 상태 3개(latch, current_state, signal count) 무변화 검증. | Logic |

### H.6 Reuse Across Entities (AC-23 ~ AC-25)

| # | Acceptance Criteria | Verification Method | Type |
|---|---|---|---|
| **AC-23** | Tier 1 종료 시점까지 다음 3 머신이 *framework 코드 변경 없이* 정상 동작한다: (M1) EchoLifecycleSM, (M2) DroneAISM (5 state), (M3) StriderBossSM (3 phase 이상). | Integration: 3 entity 통합 씬에서 manual playtest + GUT 머신별 단독 테스트 | Integration |
| **AC-24** | C.3.5 1000-cycle 결정성: 동일 시드 입력 시퀀스로 1000회 GUT 테스트 실행 시 EchoLifecycleSM의 마지막 32개 `_state_history` entry가 *모든 1000회 실행에 동일*. | GUT: seed 고정 + 1000 iter 실행 + 결과 hash 비교 | Logic |
| **AC-25** | C.3.6 성능 budget (Round 1 B8 측정 방법 명시 + performance-analyst Steam Deck 권고): ECHO + 30 적 + 1 보스 = 32 동시 SM이 가동되는 1 stage 기준 60fps **Steam Deck 하드웨어** 5분 플레이테스트에서 SM 호출 누적 < 0.5ms / frame. | Integration: 측정 방법 = `StateMachine.physics_update()` 진입/종료 시 `Time.get_ticks_usec()` 기록 → 32 SM × per-frame 누적값을 `Performance.add_custom_monitor(&"sm/frame_us", ...)` 에 등록 → Godot profiler 내보내기로 5분 평균값 산출. **Steam Deck 단독** 측정 (desktop-only profiling 불충분 — 데스크탑 ~0.6× CPU factor로 0.45–0.5ms 가까이 사용). 스크린샷은 측정값 + 씬 컨텍스트 포함. | Integration |

### H.7 Tier별 Gate

| Tier | 통과 필수 AC |
|---|---|
| **Tier 1 (4-6주)** | AC-01 ~ AC-22 (AC-17a 포함, 별도 enumerated row) + AC-24 + AC-26 + AC-27 = **26 Logic ACs** — *framework-only gate* (#10 Enemy AI · #11 Boss Pattern GDD 부재 시 평가 가능). AC-17a 신규 포함 (B4 intra-tick ordering). |
| **Tier 1 integration gate** *(가능 시점)* | AC-23 (3-machine reuse) + AC-25 (Steam Deck perf) — Enemy AI GDD #10 + Boss Pattern GDD #11 작성 + 구현 *후*에만 평가 가능 (qa-lead Round 1 BLOCKING #3·#10 — H.7 cross-system 의존 명시화). |
| **Tier 2 (6개월)** | + 적 archetype 3종 추가에서 AC-23 재검증 + 1000-cycle 결정성 (AC-24) auto-CI 통합 |
| **Tier 3 (16개월)** | + Difficulty Toggle 통합 시 `pause_swallow_states` **non-override** 검증 — Easy 모드가 본 invariant를 우회하지 *않음*을 확인 (Difficulty Toggle GDD 소관, B2 — Time Rewind Rule 18 보존) |

### H.8 GUT 테스트 파일 권장 경로

`.claude/docs/coding-standards.md` Test Evidence by Story Type에 따라:

```
tests/unit/state_machine/
├── state_machine_primitives_test.gd      # AC-01 ~ AC-05
├── state_machine_atomicity_test.gd       # AC-06 ~ AC-09
├── state_machine_dispatch_guards_test.gd # AC-10 ~ AC-13
├── echo_lifecycle_sm_test.gd             # AC-14 ~ AC-19, AC-26, AC-27, AC-17a
├── state_machine_misuse_test.gd          # AC-20 ~ AC-22
└── state_machine_determinism_test.gd     # AC-24

tests/integration/state_machine/
├── tier1_three_machine_reuse_test.gd     # AC-23
└── tier1_perf_budget_test.gd             # AC-25
```

명명 규약: `[system]_[feature]_test.gd` (coding-standards.md 준수). 테스트 함수명: `test_[scenario]_[expected]`.

---

## Z. Open Questions

본 GDD 작성 도중 남은 결정 사항. 카테고리별로 정리하며, 해소 시점/조건을 명시. Time Rewind GDD의 15 OQ와 동일 형식을 따른다.

### Z.1 외부 GDD 의존 (3) — 다른 시스템 GDD 작성 시 함께 결정

| ID | 질문 | 의존 GDD | 결정 시점 |
|---|---|---|---|
| ~~**OQ-SM-1**~~ ✅ **Resolved 2026-05-09** | ~~`Damage.player_hit_lethal` 시그니처가 `cause: StringName` 1-arg인가 0-arg인가?~~ → **1-arg `cause: StringName` 락인** (Damage GDD DEC-1). E-14/F.1/AC-22 가정 모두 일관 — 별도 변경 불필요. | [`design/gdd/damage.md`](damage.md) DEC-1 + C.3.1 | **Resolved** |
| **OQ-SM-2** | SM의 `boot()` 호출 책임자 — ECHO 노드의 `_ready()` 안에서 호출(현재 가정)? 아니면 Scene Manager가 ECHO 인스턴스화 직후 명시 호출? | `design/gdd/scene-manager.md` (#2) | Scene Manager GDD 작성 시 |
| **OQ-SM-3** | `Input.is_action_just_pressed("rewind_consume")` 이름이 확정인가? 또는 `rewind_action`/`time_rewind` 등 명명 표준? F.1/D.2/AC-17이 모두 *provisional* 가정. | `design/gdd/input-system.md` (#1) | Input GDD 작성 시 |

### Z.2 플레이테스트 결정 대기 (2)

| ID | 질문 | 결정 시점 |
|---|---|---|
| ~~**OQ-SM-4**~~ ✅ **Resolved 2026-05-10 (Round 1 design-review B2)** | ~~`pause_swallow_states` 빈 배열 override (Easy 모드 옵션)~~ → **Resolved as framework invariant, not a difficulty knob** (G.1 row + G.4 Tier 3 row + F.6 forbidden composition). Time Rewind Rule 18 ("12프레임 grace를 분석 시간으로 변환 방지")이 직접 인용되어 lock. Easy 모드 난이도 조정은 `RewindPolicy.dying_window_frames` (D=8/16/18) 또는 `RewindPolicy.starting_tokens` 같은 *Time Rewind 소유 knob*만 사용. | **Resolved** |
| ~~**OQ-SM-5**~~ ✅ **Resolved 2026-05-10 (Round 1 design-review B6)** | ~~`Q_cap=4` 기본값이 Tier 2에도 false positive 없이 유지되는가?~~ → **Resolved as `TRANSITION_QUEUE_CAP` const (safety invariant, not knob)**. Tier 2 측정 시 `Q_depth_max > 2`가 관측되면 *재측정*이 아니라 *디자인 결함*으로 간주(D.4 cap 의미 보존). Tier 2 게이트의 실측 의무는 D.7 footnote로 이전. | **Resolved** |

### Z.3 기술 검증 대기 (4) — Godot 4.6 동작 직접 확인 필요

| ID | 질문 | 검증 방법 | 시점 |
|---|---|---|---|
| **OQ-SM-6** | Godot 4.6의 노드 `_ready()` 호출 순서가 *항상* 자식 우선 + 형제 인덱스 결정적인가? 동적 `add_child()` 시점에 따른 ready 순서가 1000-cycle 결정성에 영향? | 1000회 빈 씬 add_child 테스트 + ready 호출 순서 캡처 | Tier 1 Week 1 (engine-reference 검증) |
| **OQ-SM-7** | `dispatch_signal`의 `current_state.callv()` 경로가 *동기 호출*인가? Godot 4.6에서 `callv`가 deferred되는 케이스는? | Godot docs + 실험 | Tier 1 Week 1 |
| **OQ-SM-8** | `_state_history` ring buffer를 1000-cycle 결정성 테스트에서 *해시 비교*에 사용할 때 GUT 테스트 1회 실행 시간이 60s 이내인가? 16ms × 60fps × 60s = 57,600 frames 시뮬레이션 부담. | GUT 프로토타입 테스트 | Tier 1 Week 4 |
| **OQ-SM-9** | Godot 4.6의 시그널 `connect` 순서가 *코드 라인 순서*와 정확히 일치하는가? 4.4→4.5의 변경에서 영향 받았는지 확인 필요. (engine-reference/godot/4.5 또는 4.6 release notes) | docs/engine-reference 직접 확인 | Tier 1 Week 1 |

### Z.4 향후 시스템 / Tier 2-3 평가 (2)

| ID | 질문 | 결정 시점 |
|---|---|---|
| **OQ-SM-10** | Hierarchical State Machine (HSM) 도입 — Tier 2에서 적 archetype이 5종 이상으로 늘었을 때 *공통 상태*(예: HIT_STUN, SLOWED) 중복 코드가 임계점 도달 시점에 평가. 도입 결정은 framework-level ADR로. | Tier 2 게이트 + 적 archetype 5종 도달 시점 |
| **OQ-SM-11** | Godot Editor 플러그인 형태의 Visual State Machine Editor — Tier 3 보스 페이즈 디자인 시 14+ 페이즈 머신을 코드 only로 유지 가능한가? 비용 vs 가치 평가. | Tier 3 게이트 (보스 4-6종 추가 시점) |

### Z.5 해소된 질문 (Resolved during this GDD)

작성 도중 *결정되었던* 질문들 — 차후 참조용:

- **(해소)** State 베이스 타입 — `Node` 선택 (C.1.1). 거부 대안: `RefCounted`.
- **(해소)** Hierarchical 모델 — Flat + 복수 SM 컴포지션 (C.1.1). HSM은 Tier 2 평가.
- **(해소)** ECHO 4-state의 호스팅 위치 — ECHO 자식 노드 (C.2.1). 거부 대안: TRC, Autoload.
- **(해소)** SM의 `physics_step_ordering` 사다리 슬롯 — *없음* (C.3.1). architecture.yaml 갱신 불필요.
- **(해소)** `force_re_enter` 기본값 — `false` (E-5, AC-08). 명시 호출 시에만 true.
- **(해소)** `TRANSITION_QUEUE_CAP` 상수 — `const int = 4` (D.1, D.4, D.7). 솔로 Tier 1에 적합. Round 1 design-review에서 *knob*에서 *safety invariant const*로 승격(B6).
- **(해소 — Round 1 B2)** `pause_swallow_states` framework invariant — Time Rewind Rule 18 lock. Easy 모드 override 금지.
- **(해소 — Round 1 B5)** `EchoLifecycleSM._ready()` connect race — `call_deferred("_connect_signals")` 패턴 + null assertion.
- **(해소 — Round 1 B7)** `EchoLifecycleSM` class hierarchy — `class_name EchoLifecycleSM extends StateMachine` (C.2.1).
- **(해소)** Player Fantasy 프레이밍 — Systemic invariant (B). ECHO Defiant Loop는 cascade fantasy로 인용.
- **(해소)** 4-state 머신 단일 출처 — `time-rewind.md` (C.2). 본 GDD는 호스팅 의무 6개만 명시.

---

## Appendix A. References

- `design/gdd/time-rewind.md` — System #9 Time Rewind System (locks ECHO 4-state machine + latch + pause swallow + signal contract)
- `docs/architecture/adr-0001-time-rewind-scope.md` — `rewind_lifecycle` signal contract (5 signals)
- `docs/architecture/adr-0003-determinism-strategy.md` — process_physics_priority ladder (player=0, TRC=1, enemies=10, projectiles=20)
- `docs/registry/architecture.yaml` — `interfaces.rewind_lifecycle`, `api_decisions.physics_step_ordering`
- `design/gdd/systems-index.md` — System #5 row + dependency map
- `.claude/docs/technical-preferences.md` — naming conventions, performance budgets, testing requirements
