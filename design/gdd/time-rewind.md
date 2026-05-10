# Time Rewind System

> **Status**: In Design
> **Author**: User + Claude (game-designer + creative-director + systems-designer + qa-lead + art-director)
> **Last Updated**: 2026-05-09
> **Implements Pillar**: Pillar 1 (primary — "처벌이 아닌 학습 도구") + Pillar 2 (secondary — 결정론 보존)
> **Implements ADRs**: ADR-0001 (R-T1 scope), ADR-0002 (R-T2 storage), ADR-0003 (R-T3 determinism)

## Overview

Time Rewind System은 ECHO의 플레이 가능한 상태를 매 물리 틱(60Hz)마다 1.5초 슬라이딩 윈도우 ring buffer에 캡처하고, 플레이어가 유한한 토큰 자원을 소비해 사망 직전 상태를 즉시 복원할 수 있게 한다. 1히트 즉사를 *세션 리셋*이 아닌 *학습 비트*로 전환하는 메커니즘이다.

플레이어는 3개의 직접 접점을 통해 시스템과 상호작용한다:

1. HUD 좌상단의 토큰 카운터(잔량 + 충전 잠금 표시).
2. 단일 전용 입력(게임패드 좌트리거 / KB+M 기본 키)으로 발동하는 명시적 토큰 소비.
3. 발동 즉시 약 0.5초 동안 재생되는 화면 전체 색반전 + 콜라주 글리치 비주얼 시그니처 (`design/art/art-bible.md` 원칙 C).

그 아래에서 시스템은 스냅샷 캡처, 토큰 경제, 복원 시퀀싱을 처리하지만 메뉴나 설정 UI로 노출하지 않는다.

**Player Fantasy** — "VEIL은 모든 것을 계산한다. 단 하나만 빼고 — 나는 시간을 되돌릴 수 있다." 1히트 즉사의 즉각적 좌절이 토큰을 소비한 1초 회수의 즉각적 회복으로 전환된다. 죽음이 끝이 아니라 *학습*이다 (Pillar 1, primary).

이 시스템 없이는 Echo의 1히트 즉사 코어가 단순 처벌로 변하며 Pillar 1이 무너진다. Hotline Miami / Katana Zero가 검증한 "긴장 → 카타르시스" 사이클로 진입할 수 없다. **이 시스템은 Echo의 차별화 메커닉이자 게임 컨셉 hook 그 자체이다** (`design/gdd/game-concept.md` Unique Hook 참조).

**Implementation locked by ADRs (참조용 — 본 GDD는 행동 명세, 아래는 구현 권위 출처):**

- **ADR-0001 (R-T1)** — Player-only scope. ECHO만 되감기 대상이며 적·탄환·환경은 정상 시뮬레이션 계속. 7-field `PlayerSnapshot` Resource 스키마. 시그널 계약 4종(`rewind_started`, `rewind_completed`, `token_consumed`, `token_replenished`).
- **ADR-0002 (R-T2)** — Ring buffer 90 pre-allocated `PlayerSnapshot` Resources, write-into-place 방식(per-tick allocation 0).
- **ADR-0003 (R-T3)** — `CharacterBody2D` + direct field assign 복원. Determinism source = `Engine.get_physics_frames()`. `process_physics_priority` 사다리(player=0, enemies=10, projectiles=20).

## Player Fantasy

> **Anchor handle**: *Defiant Loop* (creative-director consultation 2026-05-09; selected from 3 candidates).

### The Moment

탄환이 나를 찾는다 — 그리고 나는 그것을 거부한다. 시간 회수 버튼을 누르는 순간, 화면이 시안과 마젠타로 찢기며 콜라주 텍스처가 글리치로 분해된다. VEIL은 내 죽음을 밀리초 단위로 계산했다. 나는 그 계산을 *지운다*. 1.0초 동안 나는 알고리즘이 예측하지 못한 변수가 되고, 돌아왔을 때 나는 단지 살아있는 것이 아니다 — 적의가 *정당해진다*. 보스가 나를 죽인 것이 아니다. 보스가 내 *철회*를 보았을 뿐이다.

### Lineage

Katana Zero의 누아르-스릴러 반항심이 직접적인 조상이지만 시간 축이 뒤집혔다. Katana Zero는 전투를 *계획*한다 — Will이 미리 시뮬레이션을 본다. Echo는 손실을 *철회*한다 — REWIND Core가 사후에 결과를 되감는다. 이 차이는 판타지의 톤을 결정한다: Katana는 차가운 암살자, Echo는 *분노한 글리치* — 더 인간적이고, 덜 침착하며, 시스템에 대해 더 적대적이다.

Hotline Miami의 즉시 재시작이 *층 단위* 정보 갱신이라면 Echo의 REWIND는 *순간 단위* 정보 갱신이다. Cuphead의 패턴 학습이 *시도 사이*에 일어난다면 Echo의 학습은 *시도 안*에 압축된다.

### Tone Register

Echo 고유의 감정: 신스웨이브 누아르 + 콜라주-글리치 분노. Hotline Miami의 클리니컬 폭력보다 뜨겁고, Cuphead의 보드빌 극장보다 어두우며, Katana Zero의 절제된 누아르보다 *날 것*이다. 시각 시그니처(`design/art/art-bible.md` 원칙 C: 색반전 + 글리치)는 이 톤의 직접 발현이다 — 치료가 아닌 항의.

### Story Anchor

이 판타지는 Echo Story Spine의 핵심 모티프와 일대일로 일치한다 — VEIL은 인간 행동을 모델링하지만 *비합리성*은 모델 외부다. ECHO의 REWIND Core가 그 사각지대다. 메커닉을 사용하는 모든 순간 플레이어는 픽션의 명제를 행동으로 증명한다: *"AI가 미래를 계산할 때, ECHO는 과거를 되돌린다."* Pillar 1 ("처벌이 아닌 학습 도구")과 스토리 모티프가 같은 호흡으로 발화된다.

### Anti-Fantasy (시스템이 결코 만들지 말아야 할 감정)

이 시스템은 다음 느낌을 *절대* 유발하면 안 된다. 각 항목은 후속 섹션(특히 Tuning Knobs와 Acceptance Criteria)의 가드 기준으로 사용된다.

- **무적 파워 판타지**. 토큰을 사용하는 것이 "구원받았다"가 아니라 "비싼 자원을 썼다"로 읽혀야 한다. 토큰이 자동·넉넉·공짜로 느껴지는 순간 반항심은 권리의식으로 변질된다.
- **안전망**. 죽음의 *현실성*이 매번 살아있어야 한다. 토큰이 떨어지면 다음 1히트는 진짜 끝이다 — 이 영구성이 반항심의 무게를 만든다 (Hard 모드 토큰 0이 핵심 감정 앵커인 이유).
- **시간 정지**. REWIND는 *현재의 타임아웃*이 아니라 *과거의 철회*다. 적·탄환·환경은 발동 동안에도 계속 시뮬레이트된다 (ADR-0001 Player-only scope의 감정적 정당화).
- **튜토리얼 팝업**. 발동 효과가 *가르침*이나 *친절*로 느껴지면 Challenge aesthetic(MDA Primary)이 무너진다. 시그니처는 0.5초 — 분석 시간이 아닌 분노 시간이다.

## Detailed Design

### Core Rules

**Capture & Resource Rules**

1. 매 `_physics_process` 틱에 `TimeRewindController`는 1개 `PlayerSnapshot`을 ring buffer에 *write-into-place* (allocation 0)로 갱신한다 (ADR-0002).
2. 캡처는 `rewind_started` emit 시 일시 정지하고 `rewind_protection_ended` emit 시 재개한다. `_write_head`는 일시 정지 동안 동결된다.
3. 시스템 시작 시 `_tokens = RewindPolicy.starting_tokens` (기본 3). Easy 모드는 토큰 무한(unclamped 정수 흉내), Hard 모드는 0. `RewindPolicy`는 `_ready()`에서 1회 주입되며 런타임 mutation 금지 — 씬 리로드 시에만 정책 변경이 적용된다.

**Trigger & Window Rules**

4. ECHO에 치명타 명중 시 State Machine(System #5)은 즉시 `ALIVE → DYING` 전이를 발생시키고 `RewindPolicy.dying_window_frames` 프레임(기본 12 / 0.2s) grace window를 연다. Damage 시스템은 사망 *결정*을 같은 길이만큼 지연한다. **`lethal_hit_detected` 시그널 수신 즉시 TRC는 `_lethal_hit_head: int = _write_head`를 캐시한다** (TRC는 `lethal_hit_detected` 구독, SM은 `player_hit_lethal` 구독 — 두 시그널은 같은 프레임 N에 Damage가 emit. F.1 #8 row 단일 출처) — 이 동결 값이 향후 `restore_idx` 계산의 기준이 되며, 이는 DYING grace 동안 캡처가 계속 진행되어도 복원 시점이 *사망 직전*에 고정되도록 보장한다 (systems-designer 검증 2026-05-09 — ADR-0002 amendment 동반).
5. 입력 버퍼: 치명타 등록 직전 `RewindPolicy.input_buffer_pre_hit_frames` 프레임(기본 4 / 0.067s)부터 DYING 윈도우 종료까지의 `"rewind_consume"` 입력은 유효하다. 이 윈도우 안의 입력은 절대 드롭되지 않는다. 4프레임 기본값은 게임패드/USB 폴 jitter(8-4ms 간격) 흡수 + Celeste의 6프레임 coyote-time 대비 보수적 선택.
    - **Implementation contract (W3 fix 2026-05-10)**: 본 윈도우는 *backwards-looking history*가 아닌 *forward-looking predicate*로 구현된다. SM이 AliveState/DyingState 양쪽의 `physics_update`에서 매 틱 `Input.is_action_just_pressed("rewind_consume")` 폴링 → 발견 시 `_rewind_input_pressed_at_frame: int` 멤버 갱신. 유효성 판정은 `state-machine.md` D.2 술어 `F_input >= F_lethal - B ∧ F_input <= F_lethal + D - 1`가 단일 출처. 즉 입력 시점은 *언제든* 기록되고, lethal_hit_detected 도착 시 SM이 술어 평가하여 *retroactively* 유효 입력인지 판단한다. 이 방식이 입력 history log 없이도 "치명타 직전 4프레임" 윈도우를 보장한다.
6. 윈도우 내 입력 + `_tokens > 0` ⇒ State Machine은 `TimeRewindController.try_consume_rewind()`를 호출한다. `true` 반환 시 `DYING → REWINDING` 전이.
7. 윈도우 내 입력 + `_tokens == 0` ⇒ 입력은 no-op. 거부 오디오 큐 1회 재생(별도 SFX 식별자 — 토큰 소비 큐와 구분). DYING 카운트다운은 계속 진행된다.
8. 윈도우 시간 초과 ⇒ `DYING → DEAD`. Scene Manager가 체크포인트/재시작 흐름을 수행 (본 GDD 범위 외).

**Restoration Rules**

9. `try_consume_rewind()`는 단일 물리 틱 안에서 다음 순서로 실행된다 (ADR-0002 amendment 적용): `_tokens -= 1` → `token_consumed.emit(_tokens)` → **`restore_idx = (_lethal_hit_head - RESTORE_OFFSET_FRAMES + REWIND_WINDOW_FRAMES) mod REWIND_WINDOW_FRAMES`** 계산 (Rule 4의 동결 값 사용 — 이 amendment가 없으면 DYING grace +k 프레임의 캡처가 `_write_head`를 진행시켜 `restore_idx`가 사망 *후* 시점을 가리키는 silent 오작동 발생) → `rewind_started.emit(_tokens)` → `_player.restore_from_snapshot(snap)` → `rewind_completed.emit(_player, snap.captured_at_physics_frame)`. 이때 `rewind_completed`의 의미는 *복원 호출 완료*이며 i-frame 보호 종료가 아니다.
    - **Canonical signal signature (W2 fix 2026-05-10)**: `signal rewind_completed(player: Node2D, restored_to_frame: int)` — 단일 출처는 `docs/registry/architecture.yaml` `interfaces.rewind_lifecycle.signal_signature`. emit 시 두 번째 인자로 전달하는 값은 `snap.captured_at_physics_frame` (캡처 당시 frame == 복원된 frame). 다운스트림 구독자(`HUD`, `VFX`, `state-machine.md` F.1 row #9)는 `_on_rewind_completed(player: Node2D, restored_to_frame: int)` 시그니처를 사용한다.
10. REWINDING 진입 직후 30프레임(0.5s) i-frame 보호가 활성화된다. ECHO는 모든 데미지에 면역이며, 1프레임부터 풀 입력(이동·점프·사격·무기 스왑) 가능하다.
11. 30프레임 카운트다운 종료 시 `REWINDING → ALIVE` 전이 + 신규 시그널 `rewind_protection_ended(player: Node2D)` emit. 이 시그널이 i-frame 종료를 알리는 단일 출처다 — 본 GDD가 ADR-0001 `rewind_lifecycle` 계약에 추가한 시그널이다 (Phase 5b registry 갱신 대상). **Hazard grace 의무 (Round 3 — damage.md DEC-6 cross-link)**: `RewindingState.exit()`은 `echo_hurtbox.set_deferred("monitorable", true)` (Round 2 정정 — 직접 `monitorable = true` 할당은 physics callback 컨텍스트에서 race 위험; deferred-call 패턴 의무) 복귀 *직후* `damage.start_hazard_grace()` 1회 호출 의무가 있다. 이는 12프레임 *hazard-only* grace 윈도우를 열어 (적 탄환은 정상 차단; `&"hazard_*"` prefix cause만 차단) Pillar 1 "처벌이 아닌 학습 도구" 보호. 단일 출처 정의는 `damage.md` DEC-6 + C.6.4 + E.13.
12. 적·탄환·환경은 DYING / REWINDING / i-frame 전 구간에서 계속 시뮬레이트된다 (ADR-0001 Player-only scope, anti-fantasy "시간 정지 아님").

**Re-entry & Concurrency Rules**

13. REWINDING 상태에서 `try_consume_rewind()` 재호출은 즉시 `false` 반환. `_is_rewinding: bool` 가드를 사용한다. 재입력은 묵음 처리 (거부 큐 X — *진행 중* 신호로 침묵 사용).
13-bis. **Buffer-primed 가드**: `Engine.get_physics_frames() < REWIND_WINDOW_FRAMES` 인 동안(세션 시작 후 첫 1.5초) `try_consume_rewind()`는 즉시 `false` 반환. ring buffer가 채워지기 전에는 `restore_idx`가 `PlayerSnapshot.new()` 기본값(원점·zero velocity) 슬롯을 가리켜 ECHO를 잘못된 위치로 텔레포트시키기 때문. `_buffer_primed: bool` 플래그를 frame counter가 처음 `W`에 도달할 때 `true`로 설정. 같은 틱에 frame=W 도달과 lethal hit이 동시 발생 시 `_buffer_primed` 갱신을 시그널 처리 *이전*에 강제 (ordering rule, E-20).
17. **Lethal-hit latch (secondary guard)**: SM은 `_lethal_hit_latched: bool` 플래그를 소유한다. `ALIVE → DYING` 전이 시 `true`로 설정, `REWINDING → ALIVE` 또는 `DEAD` 전이 시 `false`로 클리어. 래치가 `true`인 동안 추가 `player_hit_lethal` 시그널은 SM이 무시한다.
    - **Primary guard (단일 출처: `damage.md` C.3.2 step 0 — Round 5 cross-doc S1 fix 2026-05-10)**: TRC의 `_lethal_hit_head` 재캐시 차단은 *Damage 측 first-hit lock*이 담당한다. `lethal_hit_detected` (TRC 구독) 와 `player_hit_lethal` (SM 구독) 는 별도 시그널이므로 SM `_lethal_hit_latched`만으로는 TRC 재캐시를 막을 수 없다. Damage `_on_hurtbox_hit` 진입 시 `if _pending_cause != &"": return` 가드가 두 시그널 emit을 모두 차단함으로써 (a) `_pending_cause` 첫 hit 보존 (`damage.md` E.1) 과 (b) `_lethal_hit_head` 재캐시 차단 (본 Rule) 두 invariant를 유일하게 enforce한다. 연속 데미지(산성 풀, 레이저 sweep)와 같은 틱 다중 치명타가 첫 hit 이후 묵음 처리되는 시각적 결과는 `damage.md` E.1 + AC-36이 검증한다.
    - SM 측 `_lethal_hit_latched`는 (1) Damage step 0가 우회된 미래 corner case (host wiring 변경 등)에 대한 *secondary defence*, (2) `current_state.handle_player_hit_lethal()` 내부 분기 정합성 검사 (E-12, E-13) 두 역할을 유지한다.
18. **Pause swallow**: SM은 `DYING` 또는 `REWINDING` 상태에서 pause 입력을 인터셉트해 무효화한다. 12프레임 grace를 자유 결정 시간으로 변환 시 anti-fantasy "분석 시간이 아닌 분노 시간"이 위반되기 때문 (E-19). pause 시스템 GDD에 본 예외 명시 의무.
14. DEAD 상태에서 입력은 무조건 무시. 부활 경로 없음.
15. `boss_defeated` 시그널이 REWINDING 중 도착하면 `_tokens` 즉시 증가 + `token_replenished` emit. HUD는 `rewind_protection_ended` 까지 시각 갱신을 지연한다(시그니처 중 UI 변동 차단).
16. `boss_defeated`와 `lethal_hit_detected`가 같은 물리 틱에 도착하는 경우 — **실제 invariant** (Round 1 design-review 정정): process_physics_priority lower=earlier (Godot 4.x). 사다리: player=0, TRC=1, Damage=2 (damage.md Round 3 lock), enemies/Boss=10, projectiles=20. 따라서 같은 틱 실행 순서는 Damage(2) → Boss(10) → projectile(20). Damage가 먼저 `lethal_hit_detected` emit → SM이 buffered rewind input 보유 시 `try_consume_rewind()` → `_tokens -= 1` (T → T-1, 중간 T=0 dip 가능) → Boss가 `boss_defeated` emit → `grant_token()` → `_tokens = min(T+1, max_tokens)` (T-1 → T, net zero). 중간 T=0 dip은 같은 틱 내 비관측 (AC-B5는 net-zero 검증, 중간 상태 검증 안 함). **불변 깨짐 조건**: Boss가 자체 `_physics_process` 노드에서 priority < 2 슬롯 획득 시. Boss Pattern GDD가 priority ≥ 10 상한 의무.

### States and Transitions

ECHO Time-Rewind State Machine (System #5 협력 영역).

| State | 진입 조건 | 종료 조건 | 비고 |
|---|---|---|---|
| **ALIVE** | 세션 시작 / `REWINDING` 만료 / Scene Manager 부활 | 치명타 명중 → DYING | 정상 게임플레이. 매 틱 ring buffer 캡처 활성. |
| **DYING** | Damage가 `player_hit_lethal` emit | 12프레임 내 입력 + 토큰 ≥ 1 → REWINDING <br> 12프레임 만료 또는 토큰 0 → DEAD | 캡처 계속 (마지막 0.2s가 buffer에 남도록). 입력 버퍼 활성. |
| **REWINDING** | DYING + `try_consume_rewind() == true` | 30프레임 만료 → ALIVE | 캡처 PAUSE (`_write_head` 동결). i-frame 활성. 풀 입력 활성. 시각 시그니처 0.5s 동시 진행. |
| **DEAD** | DYING grace 윈도우 만료 | Scene Manager 체크포인트/재시작 → ALIVE | 종착점. Time Rewind 비활성. |

**Time Rewind이 강제하는 전이**: `DYING → REWINDING`, `REWINDING → ALIVE`.

**Time Rewind이 차단하는 전이**: REWINDING 동안 모든 데미지 입력(i-frame), DEAD에서 어떤 부활도 차단.

**REWINDING 동안 허용되는 입력**: 이동, 점프, 사격, 무기 스왑 (1프레임부터). 시각 시그니처는 *분노 시간*이지 락아웃이 아님 (Anti-fantasy).

**Hard 모드 동작**: 토큰 0이지만 DYING 12프레임 윈도우는 그대로 존재한다. 입력 시 거부 큐 → DEAD. 이는 *플레이어가 시도했음*을 확인시키는 의도된 디자인이며 anti-fantasy "안전망"의 정반대 기제다.

### Interactions with Other Systems

모든 의존 시스템은 GDD 미작성 상태이므로 인터페이스를 *provisional*로 표시한다. 해당 시스템의 GDD 작성 시점에 본 절을 다시 검토해 정합성을 확인한다.

#### Upstream

| # | 시스템 | 방향 | 인터페이스 | Hard/Soft |
|---|---|---|---|---|
| [#5](state-machine.md) | State Machine Framework | SM이 사망 순간의 단일 중재자. Damage `player_hit_lethal` 구독, DYING 진입, 입력 시 `try_consume_rewind()` 호출. TRC는 SM 상태를 직접 읽지 않는다. SM 측 의무는 `state-machine.md` C.2.2의 6 의무로 정식화 (latch O1 / pause swallow O2 / 입력 버퍼 O3 / 4-시그널 구독 O4 / boss_defeated 지연 O5 / scene 클리어 O6). | TRC가 노출: `try_consume_rewind() -> bool`. SM이 구독: `rewind_started`, `rewind_completed`, `rewind_protection_ended`. | **Hard** |
| #6 | [Player Movement](player-movement.md) | TRC가 매 틱 PlayerMovement 속성을 *읽기*; `restore_from_snapshot()`을 *쓰기 단일 경로*로 호출. **Wiring (Round 2 추가)**: TRC는 명시적 `@export var player: PlayerMovement` 노드 참조를 통해 PlayerMovement에 연결한다 — `get_parent()` / implicit lookup 금지. 에디터에서 missing reference 검출 가능 + dependency가 declarative 형태로 명시. **PM #6 Designed 락인 (2026-05-10)**: PlayerMovement는 `class_name PlayerMovement extends CharacterBody2D` (= ECHO root 노드 자체, player-movement.md A.Overview Decision A). `_is_restoring: bool` 가드 (player-movement.md C.4.4 단일 출처)는 anim method-track 핸들러가 복원 중 발화 차단. `facing_direction`은 int 0..7 enum (architecture.yaml api_decisions.facing_direction_encoding) — 7-필드 스냅샷 schema 변경 없음. | 캡처 (read): `global_position: Vector2`, `velocity: Vector2`, `facing_direction: int`, `current_animation_name: StringName`, `current_animation_time: float`, `current_weapon_id: int`, `is_grounded: bool`. 복원 (write): `func restore_from_snapshot(snap: PlayerSnapshot) -> void` (player-movement.md C.4.2 verbatim 일치). Forbidden pattern `direct_player_state_write_during_rewind` 적용 — 단일 enforce site는 PlayerMovement 자체. | **Hard** |
| #8 | [Damage / Hit Detection](damage.md) | Damage emit; TRC와 SM 양쪽 구독. TRC는 `lethal_hit_detected(cause)` (frame N, `_lethal_hit_head` 캐시 트리거) + `death_committed(cause)` (frame N+12, buffer cleanup) 양쪽 구독. SM은 `player_hit_lethal(cause)`만 구독. SM이 grace 만료 시 `damage.commit_death()` invoke (단방향). | Damage GDD F.3 시그널 카탈로그 (단일 출처): `signal lethal_hit_detected(cause: StringName)` + `signal player_hit_lethal(cause: StringName)` + `signal death_committed(cause: StringName)`. 1-arg locked DEC-1. 2-stage 분리는 SM이 12프레임 grace를 끼워 넣게 한다 (Rule 4 + `damage.md` C.3). cause taxonomy는 Damage GDD가 단일 소유 (D.3). | **Hard** (간접) |
| #1 | Input System | InputMap action 매핑. SM이 DYING 진입 시 액션을 폴한다. | InputMap action `"rewind_consume"`. 게임패드 좌트리거 (`JOY_AXIS_TRIGGER_LEFT`, threshold 0.5). KB+M 기본 `Shift`. 단일 버튼, 코드 X (technical-preferences 제약). | **Hard** |
| #2 | Scene / Stage Manager *(provisional)* | Scene Manager가 씬 unload 직전 emit; TRC 구독해 ring buffer invalidate. | `signal scene_will_change()` (Scene Manager 소유) → TRC가 `_buffer_invalidate()` 호출: `_buffer_primed = false`, `_write_head = 0`. 토큰 카운트는 보존. 다음 DYING은 buffer-primed 가드(Rule 13-bis)에 의해 자동 차단되어 `DEAD`로 직행. 씬 경계의 invalid 좌표 복원을 방지 (E-16). | **Hard** |

#### Downstream

| # | 시스템 | 방향 | 인터페이스 | Hard/Soft |
|---|---|---|---|---|
| #11 | Boss Pattern *(provisional)* | Boss 사망 시 emit; TRC가 구독해 자기 호출. 직접 호출 금지. | `signal boss_defeated(boss_id: StringName)` → TRC가 구독해 `self.grant_token()` 호출 → `token_replenished(new_total: int)` emit. | **Hard** (토큰 경제) |
| #13 | HUD *(provisional)* | HUD가 TRC 시그널 구독 (observer, 폴 금지). | `token_consumed(remaining_tokens: int)`, `token_replenished(new_total: int)` 구독. 초기 표시는 `TimeRewindController.get_remaining_tokens() -> int`. HUD는 `_displayed_tokens == remaining_tokens` diff 체크 후 갱신 (per-fire allocation 0). | **Soft** |
| #14 | VFX / Particle *(provisional)* | VFX가 `rewind_started` 구독해 `GPUParticles2D.emitting = false` 설정. `rewind_protection_ended` 구독해 재발화. | `rewind_started(remaining_tokens: int)` + `rewind_protection_ended(player: Node2D)` 구독. (ADR-0001: GPUParticles2D reverse 4.6 미지원 → emit-pause + restart 워크어라운드.) | **Soft** |
| #16 | Time Rewind Visual Shader *(provisional)* | Shader가 `rewind_started`만 구독 + 내부 0.5s `Timer` (one-shot)로 종료. `rewind_completed`에 종료 와이어링 금지(같은 틱 emit). | `rewind_started(remaining_tokens: int)` 구독. 내부 Timer one-shot 0.5s. | **Soft** |
| #20 | Difficulty Toggle *(provisional)* | Difficulty가 `RewindPolicy` Resource를 제공; TRC가 `_ready()`에서 주입받는다. 런타임 mutation 금지. | `class_name RewindPolicy extends Resource`: `@export var starting_tokens: int`, `@export var max_tokens: int`, `@export var grant_on_boss_kill: bool`, `@export var infinite: bool`, `@export var dying_window_frames: int = 12`(range 8–18), `@export var input_buffer_pre_hit_frames: int = 4`(range 2–6). TRC: `@export var rewind_policy: RewindPolicy`. | **Soft** (null 시 기본값 사용) |

#### Integration Risks (GDD 차원에서 락인)

| ID | Risk | Mitigation |
|---|---|---|
| **I1** | Damage emit + SM 사망 처리 + 입력이 같은 틱에 중첩 | SM이 단일 중재자. Damage는 `lethal_hit_detected`와 `death_committed` 2단계로 분리. TRC는 SM이 호출할 때만 동작. |
| **I2** | `boss_defeated`와 `lethal_hit_detected` 같은 틱 중첩 시 토큰 invariant | **Round 1 정정**: 실제 순서는 consume-then-grant (Damage priority=2 < Boss priority=10). 같은 틱 내 net-zero (T → T-1 → T), 중간 T=0 dip 비관측. Boss가 priority < 2 슬롯 획득 시 invariant 깨짐 — Boss Pattern GDD가 priority ≥ 10 상한 의무. process priority 사다리 (player=0, TRC=1, Damage=2, enemies/Boss=10, projectiles=20). |
| **I3** | REWINDING 중 `try_consume_rewind()` 재호출 | `_is_rewinding: bool` 가드. 즉시 `false` 반환. SM은 REWINDING 종료까지 입력 무시. |
| **I4** | `AnimationPlayer.seek()` 시 1프레임 포즈 팝 | `_anim.seek(snap.animation_time, true)` `update=true` 강제 즉시 평가. 잔여 ~0.16ms 드리프트 시각 임계 미만 — known acceptable. |
| **I5** | Shader가 `rewind_completed` 종료 트리거로 와이어링 시 0프레임 효과 | Shader는 `rewind_started`만 구독 + 내부 Timer 0.5s. 본 GDD가 단일 출처 명시. |
| **I6** | HUD `token_consumed` 콜백에서 String 할당 | HUD diff 체크 의무. 변경 시에만 `Label.text` 변형. 1ms HUD budget 보장. |
| **I7** | `RewindPolicy` 런타임 mutation 시 `_tokens` vs `max_tokens` 레이스 | `RewindPolicy`는 `_ready()` 후 read-only. Difficulty 변경은 씬 리로드 시점에만 효과. setter 비공개. |
| **I8** | TRC와 PlayerMovement sibling 시 process priority 미설정으로 stale read | TRC `process_physics_priority = 1` 의무. PlayerMovement 0 직후, enemies 10 이전. 씬 트리에 정적 추가 (런타임 add/remove 금지). |
| **I9** | mid-shooting-anim 중 `seek()` 시 method-track 키프레임이 stale 발사체를 재발화 | `PlayerMovement._is_restoring: bool = true` 플래그를 `restore_from_snapshot()` 호출 직전 set, 다음 `_physics_process` 시작에 false. 모든 anim method-track 핸들러(예: `_on_anim_spawn_bullet()`)는 `if _is_restoring: return` 가드. PlayerMovement GDD 의무 (E-21). |

#### 신규 시그널 추가 (ADR-0001 계약 확장)

본 GDD는 ADR-0001 `rewind_lifecycle` 계약에 1개 시그널을 추가한다:

```gdscript
signal rewind_protection_ended(player: Node2D)  # REWINDING → ALIVE 전이 시 emit (rewind_started 후 30프레임)
```

기존 4개 시그널(`rewind_started`, `rewind_completed`, `token_consumed`, `token_replenished`)은 모두 보존(하위 호환). VFX·State Machine·HUD가 i-frame 종료를 단일 출처에서 알 수 있도록 한다. Phase 5b에서 `docs/registry/architecture.yaml`의 `interfaces.rewind_lifecycle.signal_signature`를 갱신한다.

## Formulas

> systems-designer 검증 2026-05-09. 모든 시간 계산은 단조 정수 frame counter(`Engine.get_physics_frames()`) 기반 — wall clock 의존 금지(ADR-0003 `determinism_clock`).

### 공유 변수 용어집

| 기호 | 타입 | 범위 | 설명 |
|---|---|---|---|
| `W` | int | 90 (const) | `REWIND_WINDOW_FRAMES` — ring buffer 슬롯 수 |
| `O` | int | 9 (const) | `RESTORE_OFFSET_FRAMES` — 사망 직전 복원 오프셋 |
| `R` | int | 30 (const) | `REWIND_SIGNATURE_FRAMES` — i-frame + 시각 시그니처 단일 출처 (shader timer와 동일 값) |
| `D` | int | 8–18 (knob) | `RewindPolicy.dying_window_frames` — DYING grace |
| `B` | int | 2–6 (knob) | `RewindPolicy.input_buffer_pre_hit_frames` — 사망 직전 입력 forgiveness |
| `H` | int | 0–89 | `_write_head` — 다음 쓰기 슬롯 (cycles 0..W-1) |
| `H_lethal` | int | 0–89 | `_lethal_hit_head` — `lethal_hit_detected` 시 동결된 H 사본 (TRC 구독 시그널) |
| `P` | int | ≥ 0 | `Engine.get_physics_frames()` — 단조 물리 프레임 카운터 |
| `T` | int | 0–∞ (Easy), 0 (Hard) | `_tokens` — 현재 토큰 수 |
| `Ts` | int | 0–∞ | `RewindPolicy.starting_tokens` |
| `fps` | int | 60 | 물리 틱 레이트 (technical-preferences.md 고정) |

---

### D1. Restore Index (ADR-0002 amendment)

`restore_idx` 공식은 다음과 같이 정의된다:

`restore_idx = (H_lethal − O + W) mod W`

**변수**: 위 용어집 참조. `+ W`가 `H_lethal < O` 경우의 음수 피연산자를 방지하므로 모든 `H_lethal ∈ [0, W-1]`에서 안전.

**Output Range**: `[0, W-1] = [0, 89]`.

**Example**: `H_lethal = 5`, `O = 9`, `W = 90` → `(5 − 9 + 90) mod 90 = 86`. 슬롯 86이 9틱 전(0.15s 이전)의 스냅샷을 보유.

**ADR-0002 amendment 정당화**: ADR-0002 원본 알고리즘은 `restore_idx`를 *live* `_write_head`에서 계산했다. Section C에서 도입된 DYING grace window 동안 캡처가 계속 진행되므로(Rule 2), `try_consume_rewind()` 호출 시점의 `_write_head`는 lethal-hit 시점보다 0–`D`-1 프레임 더 진행된 상태. 라이브 `H` 사용 시 `H − O`가 사망 *후*를 가리켜 silent 오작동. lethal-hit 동결 사본 `H_lethal`을 사용하면 복원 시점이 항상 *사망 직전*에 고정.

---

### D2. Token State Transitions

토큰 상태 전이 공식:

```
T_after_consume   = max(0, T − 1)                       -- on try_consume_rewind() (when not infinite)
T_after_boss_kill = min(T + 1, max_tokens)              -- on grant_token() (when grant_on_boss_kill); cap per RewindPolicy.max_tokens
T_session_start   = Ts                                   -- on _ready(); Ts = 3 (Normal), 0 (Hard)
T_easy_guard      = ∞ (no clamp; checks skipped) — RewindPolicy.infinite == true
T_hard_guard      = 0 (constant)                         -- starting_tokens=0, grant_on_boss_kill=false
```

**Round 1 정정 (cap expression)**: 원본 `T_after_boss_kill = T + 1`은 cap 표현 누락 — silent overshoot 가능 (예: 시그널 중복 emit). AC-B3가 cap 검증하므로 동작은 옳지만 formula spec이 source of truth. ADR-0002 `grant_token()` pseudocode 동기화 의무.

**변수**:

| 기호 | 타입 | 범위 | 설명 |
|---|---|---|---|
| `T` | int | 0–∞ | 전이 전 토큰 수 |
| `T_after_*` | int | 0–∞ | 전이 후 토큰 수 |
| `infinite` | bool | {true, false} | Easy 모드 플래그 |
| `grant_on_boss_kill` | bool | {true, false} | 보스 킬 시 +1 여부 |

**Output Range**: `T ≥ 0` 항상. Easy 모드: 무한대 (GDScript int은 충분히 크다). Hard 모드: T 영구 0.

**Example (Normal)**: 세션 시작 → `T = 3`. 보스 킬 → `T = 4`. 토큰 소비 → `T = 3`. 세 번 소비 → `T = 0`. 다음 명중: `try_consume_rewind()` false 반환, `DYING → DEAD`.

---

### D3. Capture Cadence

`_capture_to_ring()` 호출 빈도와 ring 진행 공식:

```
snapshots_per_second   = fps   = 60
H_after_capture        = (H + 1) mod W
capture_active         = NOT _is_rewinding AND _buffer_primed_or_warmup
```

**변수**: 용어집 참조. `_is_rewinding: bool` REWINDING 상태 동안 true(Rule 2 — write_head 동결).

**Output Range**: `H ∈ [0, W-1]`. W 틱마다 가장 오래된 스냅샷이 덮어 써진다 (write-into-place). 세션 시작 후 첫 W 틱 동안은 캡처는 진행되지만(warmup) `try_consume_rewind()`는 차단(Rule 13-bis).

**Example**: `H = 89` → 캡처 후 `H = (89 + 1) mod 90 = 0`. 자연스럽게 wrap. 200틱 시 buffer는 frame 110–199 보유.

---

### D4. Window-Depth Derivations

프레임 → 초 환산 (모든 시간 계산이 `fps = 60` 기반 단조 정수):

```
t_window  = W / fps  = 90 / 60 = 1.5  s    -- 되감기 lookback 깊이
t_offset  = O / fps  =  9 / 60 = 0.15 s    -- 사망 직전 복원 마진
t_signat  = R / fps  = 30 / 60 = 0.5  s    -- i-frame + 시각 시그니처
t_dying   = D / fps  = 12 / 60 = 0.2  s    -- (기본) DYING grace
t_buf     = B / fps  =  4 / 60 ≈ 0.067 s   -- (기본) 사망 직전 입력 buffer
```

**Output Range**: 모든 결과 양수, 단위 초. ADR + Pillar 1/2 + anti-fantasy 가드 만족.

**Example (full sequence, Normal)**: lethal hit at T=0 → DYING T∈[0, 0.2]s → 입력 at T=0.05s (3프레임 진입) → `try_consume_rewind()` 발동 → REWINDING T∈[0.05, 0.55]s → 0.15s 사망 전 위치로 복원 → i-frame 0.5s → ALIVE at T=0.55s.

---

### D5. Memory Budget

PlayerSnapshot resident byte 계산:

```
fields_bytes        = 8 + 8 + 4 + 8 + 4 + 4 + 4 + 8 = 48 B  (raw fields)
resource_overhead   ≈ 128–192 B  (Godot 4 Resource 베이스)
snapshot_total      ≈ 192 B
ring_buffer_bytes   = W × snapshot_total = 90 × 192 ≈ 17,280 B ≈ 17 KB
ceiling_bytes       = 1.5 GB ≈ 1.61 × 10^9 B
budget_fraction     = 17,280 / 1.61e9 ≈ 0.001%
```

**Field 분해**:

| Field | GDScript 타입 | Bytes |
|---|---|---|
| `global_position` | Vector2 | 8 |
| `velocity` | Vector2 | 8 |
| `facing_direction` | int | 4 |
| `animation_name` | StringName (포인터) | 8 |
| `animation_time` | float | 4 |
| `current_weapon_id` | int | 4 |
| `is_grounded` | bool | 4 |
| `captured_at_physics_frame` | int | 8 |
| **Raw 합계** | | **48 B** |

**Output Range**: 17–21 KB resident. `_ready()`에서 1회 사전 할당 (per-tick allocation 0). StringName은 Godot 문자열 테이블에 interned되므로 포인터 비용은 8B 일정.

**Example**: 90 슬롯 × 192 B = 17,280 B. TRC 노드 오버헤드(~500 B) 추가 시 ~17.8 KB. 1.5 GB ceiling 대비 0.001%.

**ADR-0001/0002 figure 정정**: 두 ADR이 표기한 "2.88 KB / ≤ 5 KB"는 Resource overhead 미반영. 정정 figure는 **17–21 KB** (4× 차이). 절대 ceiling 대비는 여전히 무시 가능 — cosmetic 정정.

---

### D6. CPU Budget Per Tick

`_capture_to_ring()`와 `restore_from_snapshot()`의 비용:

```
t_capture_per_tick  ≈ N_fields × t_field_copy = 8 × ~100–500 ns ≈ 0.8–4 μs   (write-into-place; Round 2 정정 — GDScript 인터프리터 오버헤드 반영)
t_restore_one_time  ≈ N_fields × t_field_copy + t_anim_seek
                    ≈ 8 × ~300 ns + 200 μs ≈ 202 μs                          (AnimationPlayer.seek dominate; t_field_copy 영향 미미)
frame_budget        = 16,600 μs (1 / 60 fps)
rewind_subsys_cap   = 1,000 μs  (≤1 ms envelope, technical-preferences.md)
capture_fraction    ≤ 4 μs / 16,600 μs ≈ 0.024% per tick                     (worst case — Round 2 정정)
restore_fraction    = 202 μs / 16,600 μs ≈ 1.2% (단발성, rewind 발동 프레임만)
```

**변수**:

| 기호 | 타입 | 범위 | 설명 |
|---|---|---|---|
| `N_fields` | int | 8 | PlayerSnapshot 필드 수 |
| `t_field_copy` | ns | ~100–500 | GDScript 단일 필드 copy (Round 2 정정 — 이전 ~6 ns 표기는 native 가정; 인터프리터 오버헤드 반영. 결론(봉투 안 안전) 불변, methodology 보정만) |
| `t_anim_seek` | μs | ~200 | `AnimationPlayer.seek(time, true)` 1회 비용 |
| `frame_budget` | μs | 16,600 | 60fps 한 프레임 |
| `rewind_subsys_cap` | μs | 1,000 | 본 서브시스템 봉투 |

**Output Range**: 캡처는 매 틱 0.0003% — 무시 가능. 복원은 발동 프레임 1.2% — 1 ms 봉투 안 안전.

**Example**: 정상 플레이 60fps에서 캡처 비용 = ~300 ns × 8 fields × 60 ticks ≈ 144 μs/sec → 전체 CPU 시간의 0.0009% (Round 2 정정). 1회 rewind 발동: 발동 프레임에 202 μs, ≤ 1 ms 봉투 만족.

### 1ms Envelope Sub-Partition (Round 2 추가)

본 시스템 1 ms 봉투(`rewind_subsys_cap`)는 발동 프레임 기준 다음 sub-budget으로 partition된다 — performance-analyst Round 1 HIGH-1+2 mitigation:

| Sub-budget | Cap (μs) | 책임 시스템 | 검증 AC |
|---|---|---|---|
| **Shader** (System #16 fullscreen post-process) | ≤ 500 | art-bible Principle C 18-frame inversion + UV distortion | OQ-11 (Tier 2 final shader) |
| **Restore** (`restore_from_snapshot()` + `AnimationPlayer.seek`) | ≤ 300 | TRC + PlayerMovement 협력 | AC-E2 (≤ 1,000 μs total — sub-cap이 더 엄격) |
| **Headroom** (HUD diff 갱신 + signal cascade + 잡음) | 200 | HUD I6, signal 5-구독자 cascade | AC-E1 통과 시 자동 |
| **합계** | **1,000** | — | technical-preferences.md ≤ 1 ms envelope |

**Steam Deck Zen 2 baseline 의무**: AC-E4 측정은 Steam Deck Zen 2 APU 기준; dev 머신(보통 더 빠른 x86 데스크탑) 측정값을 일대일 transfer 금지. Tier 1 perf-pass에서 device-specific calibration 수행 (HIGH-2 mitigation).

---

### Tuning Split (RewindPolicy 필드 vs hardcoded const)

| 상수 | 분류 | 근거 |
|---|---|---|
| `REWIND_WINDOW_FRAMES = 90` | **hardcoded const** | ADR-0001/0002 락. 변경 시 ring buffer 재할당 필요. 아키텍처 계약. |
| `RESTORE_OFFSET_FRAMES = 9` | **hardcoded const** | ADR-0002 락. `restore_idx` 공식 + lethal-hit 상호작용(D1)에 결합. |
| `REWIND_SIGNATURE_FRAMES = 30` | **hardcoded const** | shader timer와 i-frame 단일 출처 (art-bible 원칙 C). 한쪽만 변경 시 시각·메커닉 계약 분기. |
| `dying_window_frames` | **RewindPolicy 필드** | 플레이어 feel knob. Hard=8, Easy=16 가능. 결정성 계약 무영향. |
| `input_buffer_pre_hit_frames` | **RewindPolicy 필드** | 입력 forgiveness는 명시적 난이도 레버. range 2–6. ring buffer 수학 무관. |
| `starting_tokens` | RewindPolicy 필드 | (Section C 정의) |
| `max_tokens` | RewindPolicy 필드 | (Section C 정의) |
| `grant_on_boss_kill` | RewindPolicy 필드 | (Section C 정의) |
| `infinite` | RewindPolicy 필드 | (Section C 정의) |

---

### Hidden Formula Risks (구현 시 가드 의무)

**F1 — restore_idx vs DYING window**: D1 amendment로 해소. `_lethal_hit_head` 동결값 사용이 mandatory.

**F2 — Off-by-one at session start**: 첫 W 프레임 동안 ring buffer가 default 슬롯(원점) 보유. `_buffer_primed` 가드(Rule 13-bis)가 `try_consume_rewind()`를 차단.

**F3 — `captured_at_physics_frame` 갭**: REWINDING 동안 `_write_head` 동결. resume 후 첫 스냅샷의 `captured_at_physics_frame`은 직전 스탬프와 R(30) 프레임 갭. 의도된 invariant — 미래 replay 시스템은 갭당 R 프레임 가산을 가정해야 한다.

**F4 — Memory figure 4× 정정 (정보)**: ADR-0001/0002의 "2.88 KB / 5 KB" 표기를 실측 17–21 KB로 정정. 1.5 GB ceiling 대비 무시 가능.

**F5 — `animation_time` float drift**: f32 누적 오차 100프레임 후 ~10⁻⁵s — 시각 임계 미만. 단, `_capture_to_ring()`은 `_player._anim.current_animation_position`을 직접 읽어야 한다 (수동 delta 누적 금지).

**F6 — 탄약 카운트 비복원 (의도적 정책)**: `PlayerSnapshot`은 무기 ID(`current_weapon_id`)는 복원하지만 ammo 카운트는 캡처하지 않는다. 복원 후 ECHO는 *현재 라이브* ammo 값을 그대로 사용. DYING 윈도우 안에서 ammo가 0이 되면 복원 후에도 0. Weapon GDD가 두 가지 중 하나를 비준해야 한다: (a) "resume with live ammo" 정책 수용 (간단, ammo는 soft resource), (b) `PlayerSnapshot`에 `ammo_count: int` 추가 (ADR-0002 amendment 필요). 구현 락 이전에 결정 의무 (E-22).

## Edge Cases

> systems-designer 검증 2026-05-09. E-01 ~ E-10은 Section C/D의 Rule/Risk 항목으로 이미 락인되어 본 섹션에서 재기재하지 않음. E-11 이하가 본 섹션 추가분.

### Already locked (Sections C/D 참조)

- **E-01** Buffer not primed (warmup, P < W) → `try_consume_rewind()` no-op (Rule 13-bis)
- **E-02** Tokens = 0 + DYING 입력 → no-op + 거부 오디오 큐 (Rule 7)
- **E-03** REWINDING 중 재진입 → `false` 반환 + 침묵 (Rule 13)
- **E-04** DEAD 입력 → 무시 (Rule 14)
- **E-05** REWINDING 중 boss_defeated → 토큰 즉시 +1, HUD 시각 갱신은 `rewind_protection_ended` 까지 지연 (Rule 15)
- **E-06** boss_defeated와 lethal_hit_detected 같은 틱 → consume-then-grant 순서 (Damage priority=2 < Boss priority=10), net-zero, 중간 T=0 dip 비관측 (Rule 16 정정)
- **E-07** AnimationPlayer.seek mid-blend → `update=true` 강제 즉시 평가 (I4)
- **E-08** lethal-hit head 동결 (DYING grace 캡처 진행) → ADR-0002 Amendment 1 + Rule 9
- **E-09** `animation_time` f32 누적 → `current_animation_position` 직접 읽기 (F5)
- **E-10** `captured_at_physics_frame` REWINDING 갭 → 의도된 invariant (F3)

### Damage Source

- **E-11**: hazard(가시·구덩이·즉사 바닥)가 치명타를 가하면 적 탄환과 동일하게 DYING 진입한다. `player_hit_lethal(cause: StringName)`이 발화되며 `cause`는 hazard 타입. `_lethal_hit_head` 캐시 + 12프레임 grace 윈도우 진행. Damage GDD가 모든 hazard 소스에 동일 시그널 발행 의무.
- **E-12**: 연속 데미지 소스(산성 풀, 레이저 sweep)가 DYING 중 추가 치명타를 발화하면 SM의 `_lethal_hit_latched` 래치(Rule 17)가 무시한다. `_lethal_hit_head` 재캐시 차단으로 anchor 정합성 보장.
- **E-13**: 같은 물리 틱에 다중 치명타(관통탄+충돌)가 도착하면 tree-order로 첫 시그널만 처리하고 나머지는 latch가 차단. 둘 다 같은 프레임이므로 anchor `_lethal_hit_head`는 동일.

### Weapon and Pickup

- **E-14**: ECHO가 W2를 픽업한 직후 사망하고 복원 시점이 W1 캡처 시점이면 `current_weapon_id = W1`이 복원된다. 월드의 W2 픽업 오브젝트는 영구 소비된 상태로 유지(rewind 무영향, ADR-0001 Player-only scope). ECHO는 W1으로 부활. Pickup/Weapon GDD가 *one-way world mutation* 명시 의무.
- **E-15**: 만료된 weapon_id가 복원되면 `WeaponSlot.set_active(invalid_id)`는 silent fallback to id=0 (기본 무기). 어설션·크래시 금지. Weapon GDD 의무.

### Scene Boundaries

- **E-16**: ECHO가 씬 전환 트리거를 통과한 직후 사망하면 복원 좌표가 이전 씬 좌표계에 있어 새 씬에서 invalid 위치로 텔레포트. Scene Manager가 unload 직전 `scene_will_change()`를 emit하고 TRC가 `_buffer_invalidate()`를 호출 — `_buffer_primed = false`, `_write_head = 0`, 토큰 보존. 다음 사망은 buffer-primed 가드(Rule 13-bis)에 의해 자동으로 `DYING → DEAD` 처리.
- **E-17**: ECHO가 OOB(out-of-bounds) kill volume에 진입하면 hazard 치명타로 처리(E-11 적용). 단, 0.15s 전 위치도 OOB라면 복원 후 i-frame 종료 시점에 다시 사망 — 이는 의도된 동작. Level Design 가이드는 OOB 볼륨을 0.15s 전 위치가 거의 OOB가 아닌 형태로 배치할 의무(레벨 디자인 제약, TRC 책임 아님).
    - **Cross-doc 타이밍 보정 (W5 fix 2026-05-10 — `damage.md` DEC-6 reciprocal)**: `hazard_oob` cause는 hazard prefix(`damage.md` C.5.2)이므로 `RewindingState.exit()` 후 DEC-6 12프레임 hazard-only grace가 **추가 적용**된다. 실제 re-death 시점은 `lethal_hit_detected` frame N 기준 N+30 (i-frame end) + 12 (hazard grace) = **N+42 frames** (= 0.7s @60fps). 단순 "i-frame 종료 시점에 다시 사망" 표기는 N+30이 아니라 N+42임에 주의. 단일 출처: `damage.md` DEC-6 + C.6.4 + E.13.

### Boss Coupling

- **E-18**: 보스 페이즈 전환(HP 임계 통과)이 frame F에 발생하고 ECHO가 F+3에 사망하면 복원 시점은 F-9 (페이즈 전환 *이전*)이지만 보스의 `_phase`는 새 페이즈 그대로 유지. ADR-0001 명시: 적은 rewind 대상 아님. 결과적으로 ECHO는 더 안전한 위치에서 새 페이즈를 빨리 학습 — Pillar 2 의도. Boss Pattern GDD가 phase 전이의 rewind-immunity 명시 의무.

### Input Pathological

- **E-19**: DYING 또는 REWINDING 상태에서 pause 입력은 SM이 swallow한다(Rule 18). 12프레임 grace를 자유 결정 시간으로 변환 시 anti-fantasy "분노 시간" 위반. pause 시스템 GDD가 본 예외 명시 의무.

### State Machine Corner

- **E-20**: ECHO가 정확히 frame `W` (buffer가 처음 primed되는 틱)에 사망하면 `_buffer_primed` 갱신을 같은 틱의 시그널 처리 *이전*에 실행하는 ordering rule이 보장. 따라서 `try_consume_rewind()`는 성공한다 (Rule 13-bis 보강).

### Animation Pathological

- **E-21**: ECHO가 mid-shooting-animation 중 사망하고 복원 시 `seek()`가 method-track 키프레임(예: spawn-projectile event)을 재발화하면 stale 발사체가 생성된다. PlayerMovement는 `_is_restoring: bool` 플래그를 `seek()` 호출 직전 `true` 설정, 다음 `_physics_process`에서 `false` 복원. 모든 anim method-track 핸들러는 `if _is_restoring: return` 가드 의무 (PlayerMovement GDD에 명시, I9 mitigation).
- **E-22**: ECHO가 ammo 0이 된 직후 사망 → 복원 후에도 ammo 0. PlayerSnapshot은 ammo를 캡처하지 않는다(F6 의도된 정책). Weapon GDD가 (a) "resume with live ammo" 정책 비준 또는 (b) `PlayerSnapshot.ammo_count: int` 추가 ADR-0002 amendment 중 하나를 구현 락 이전에 선택 의무.

### Level Script Bypass

- **E-23** (Round 2 추가): 레벨 스크립트(예: 시네마틱 트리거, scripted kill volume, BossArenaScript)가 `Damage.commit_death(cause)`를 *직접* 호출해 i-frame 보호를 우회 시도하는 경로. **Mitigation**: (a) Damage GDD DEC-4의 `monitorable=false` 보호는 *충돌-구동* 데미지에만 작동하므로 script-driven path는 별도 의무가 필요 — 모든 level script가 `commit_death()` 호출 전 `damage.is_in_iframe(player) -> bool` 확인 의무를 진다 (Damage GDD F.5 expected helper). (b) 보호 위반 시 silent — Damage가 어설션 발동, REWINDING 중 lethal commit 시도는 dev build에서 즉시 fail. (c) Tier 1 prototype에서는 script-driven kill volume 0개 (직접 hazard 노드만) → 본 edge case는 Tier 2+ scripted encounter 도입 시 Level Design Guide에 의무로 등재.

## Dependencies

본 절은 의존성 *지도*를 제공한다. 인터페이스 세부 — 시그널 시그니처·메서드 시그니처·Hard/Soft 분류 — 는 Section C.3 "Interactions with Other Systems"에 단일 출처로 유지된다.

### Upstream Dependencies (이 시스템이 의존)

| # | 시스템 | Hard/Soft | 데이터 흐름 | 의존 본질 |
|---|---|---|---|---|
| **#1** | Input System | Hard | InputMap action `"rewind_consume"` 폴 | SM이 DYING 진입 시 액션 상태 폴 |
| **#2** | Scene / Stage Manager | Hard | `signal scene_will_change()` | 씬 unload 직전 ring buffer invalidate (E-16). systems-index 등재 갱신 필요 |
| **#5** | State Machine Framework | Hard | TRC가 시그널 발행, SM이 구독·중재 | SM이 사망 순간 단일 중재자 (Rule 17, 18) |
| **#6** | Player Movement | Hard | TRC가 매 틱 7개 필드 read + `restore_from_snapshot()` write | 캡처 대상 + 복원 단일 경로 |
| **#8** | Damage / Hit Detection | Hard (간접) | `player_hit_lethal(cause)` → SM이 구독 | TRC는 직접 구독 X — SM 경유 |
| **#15** | Collage Rendering Pipeline | Soft (Pillar 1 정합성) | 데이터 흐름 없음 — *비주얼 readability* 의존 | **D4 fix 2026-05-10**: Pillar 1 ("처벌→학습 도구") 정합성은 0.2s 글랜스에서 적·탄환·hazard가 콜라주 레이어에 가려지지 않을 때만 성립 (game-concept R-D2). 콜라주 가독성 실패 시 rewind는 *학습 도구*가 아닌 *지각 실패 패치*로 변질. Collage Rendering #15 GDD 작성 시 0.2s 글랜스 테스트가 acceptance criterion으로 명시 의무. |

### Downstream Dependents (이 시스템에 의존)

| # | 시스템 | Hard/Soft | 데이터 흐름 | 의존 본질 |
|---|---|---|---|---|
| **#11** | Boss Pattern | Hard (토큰 경제) | `boss_defeated(boss_id)` → TRC가 `grant_token()` 호출 | 토큰 보충 단일 메커니즘 |
| **#13** | HUD | Soft | `token_consumed`, `token_replenished` 시그널 + `get_remaining_tokens()` 폴 | UI 표시 (presentation) |
| **#14** | VFX / Particle | Soft | `rewind_started` + `rewind_protection_ended` 시그널 | GPUParticles2D emit-pause / restart |
| **#16** | Time Rewind Visual Shader | Soft | `rewind_started` 시그널만 + 내부 0.5s Timer | 색반전 + 글리치 시각 시그니처 |
| **#20** | Difficulty Toggle | Soft | `RewindPolicy` Resource 주입 (`_ready()` 1회) | 토큰 정책 + 윈도우 knob |

### 계약 의무 누적 (다른 GDD에 떨어진 책임)

본 GDD가 다른 시스템에 부여한 명시적 계약 의무들 — 해당 시스템 GDD 작성 시 반영 의무:

| 대상 시스템 | 의무 | 근거 |
|---|---|---|
| #2 Scene Manager | `scene_will_change()` 시그널 emit + TRC 구독 가능 노출 | E-16 |
| #5 State Machine | `_lethal_hit_latched` 래치 소유 + DYING/REWINDING pause swallow | Rule 17, 18 |
| #6 Player Movement | `restore_from_snapshot()`, 7-필드 노출, `_is_restoring: bool` 가드, anim method-track 핸들러의 `_is_restoring` 체크 | C.3, I9 |
| #8 Damage | `player_hit_lethal(cause: StringName)` 발행, `lethal_hit_detected`/`death_committed` 분리, 모든 hazard 동일 시그널 | E-11 |
| #11 Boss Pattern | `boss_defeated(boss_id: StringName)` 발행, phase 전이 rewind-immunity 명시, `process_physics_priority = 10` | C.3, E-18 |
| #13 HUD | `_displayed_tokens` diff 체크 (per-fire allocation 0), REWINDING 동안 시각 갱신 지연 | I6, Rule 15 |
| #14 VFX | `rewind_started`에서 emit pause, `rewind_protection_ended`에서 restart | C.3 |
| #16 Visual Shader | `rewind_started`만 구독, 내부 0.5s Timer로 종료 (`rewind_completed` 종료 와이어링 금지) | I5 |
| #19 Pickup | one-way world mutation 명시 (rewind 무영향) | E-14 |
| #7 Player Shooting / Weapon | `WeaponSlot.set_active(invalid_id)` silent fallback to id=0; ammo 정책 결정 (resume with live ammo vs ADR amendment) | E-15, E-22, F6 |
| pause 시스템 | DYING/REWINDING 중 pause swallow 명시 | Rule 18 |

### Systems-Index 갱신 필요 사항

`design/gdd/systems-index.md` System #9 행의 "Depends On" 컬럼에 `Input System`(#1)과 `Scene Manager`(#2)를 추가 의무 — Phase 5d Update Systems Index에서 일괄 적용.

### 순환 의존성 점검

| 후보 사이클 | 분석 | 판정 |
|---|---|---|
| Boss Pattern (#11) ↔ Time Rewind (#9) | Boss → TRC 단방향 (시그널). TRC → Boss 직접 호출 없음. | 사이클 아님 |
| HUD (#13) ↔ Time Rewind (#9) | HUD → TRC 단방향 (시그널 구독 + getter 폴). TRC → HUD 직접 호출 없음. | 사이클 아님 |
| State Machine (#5) ↔ Time Rewind (#9) | SM → TRC 단방향 (`try_consume_rewind()` 호출). TRC → SM 시그널만 (SM이 구독). | 사이클 아님 |
| Damage (#8) ↔ Time Rewind (#9) | Damage → SM → TRC. TRC는 Damage를 직접 구독·호출하지 않음. | 사이클 아님 |
| Visual Shader (#16) ↔ Time Rewind (#9) | Shader → TRC 단방향 (시그널 구독). | 사이클 아님 |

진정한 사이클 없음 — 모든 의존성은 단방향이며 Observer 패턴으로 디커플.

## Tuning Knobs

Section D Tuning Split의 분류를 *튜닝 사양서* 형식으로 재구성. 각 knob에 현재 값, 안전 범위, 극단 동작, 다른 knob과의 상호작용 기재.

### Designer-Adjustable (RewindPolicy Resource 필드)

| Knob | 기본값 | 안전 범위 | 너무 낮으면 | 너무 높으면 | Hard 제안 | Easy 제안 |
|---|---|---|---|---|---|---|
| `starting_tokens` | 3 | 0–10 | 0 = Hard 모드 (의도). 1-2 = 첫 보스 전 학습 곡선 가파름 | 5+ = Pillar 1 압박 약화, "안전망" anti-fantasy 위협 | 0 | ∞ (`infinite=true`) |
| `max_tokens` | 5 | 1–10 | 1 = boss kill 충전 의미 약화 | 10+ = 토큰 자원 관리 카타르시스 무력화 | N/A | N/A (`infinite` 처리) |

> **D1 fix 2026-05-10 — Silent cap-overflow contract gap (HUD coordination 의무)**: `_tokens == max_tokens` (5) 상태에서 `boss_defeated` 도착 시 `grant_token()`은 silent clamp ─ `_tokens` 변화 없음, `token_replenished` emit는 발화 (Rule 3 / AC-B3 invariant). 그러나 anti-fantasy "비싼 자원을 썼다 — 모든 거래가 느껴져야"가 cap에서 깨짐 (보스 처치 보상이 시각/청각적으로 invisible). **HUD 의무**: HUD GDD #13 작성 시 `token_replenished` 핸들러는 emit *전* `_tokens == max_tokens` 분기를 *별도 cap-full feedback*(짧은 다른 색 펄스 또는 별도 SFX)로 처리할 의무. 본 GDD는 시그널 contract만 보유; presentation 분기는 HUD 단일 소유. Tier 1 baseline에서 cap-full 케이스는 1회 이상 발생 가능 (시작 3 토큰, 보스 4-5체 처치 시 cap 도달).
| `grant_on_boss_kill` | true | bool | false + tokens=3 = 4-6주 Tier 1 budget에서는 OK | true (default) | false | true |
| `infinite` | false | bool | false (기본 정책 적용) | true = Easy 모드, 토큰 검사 모두 우회 | false | **true** |
| `dying_window_frames` | 12 | 8–18 | 8 (Hard) = 입력 반응 한계 (~133ms). 6 이하는 Pillar 1 위반 | 18 (Easy) = 안락 confirmation. 24 이상은 anti-fantasy 위반 | 8 | 16 |
| `input_buffer_pre_hit_frames` | 4 | 2–6 | 2 = 단일 폴 jitter로 입력 손실 가능 | 6 = preemptive 스팸 가능, 그러나 anti-fantasy까진 도달 못 함 | 4 | 6 |

### Hardcoded const (변경 = 아키텍처 계약 위반)

| Const | 값 | 변경 시 영향 | 조정 가능 시점 |
|---|---|---|---|
| `REWIND_WINDOW_FRAMES` | 90 | ring buffer 재할당 + ADR-0001/0002 amendment 필요. 1.5s 윈도우는 game-concept Unique Hook의 정확한 사양. | Tier 2 게이트에서 재고려 가능 (그 외 시점 변경 금지) |
| `RESTORE_OFFSET_FRAMES` | 9 | `restore_idx` 공식 + lethal-hit head freeze 상호작용 변경 → ADR-0002 amendment 필요 | Tier 1 prototype 검증 후 ADR 갱신 가능 |
| `REWIND_SIGNATURE_FRAMES` | 30 | i-frame 보호 + shader timer + art-bible 원칙 C 시각 시그니처가 모두 결합 — 단일 출처. 한쪽만 변경 시 시각·메커닉 분기 | Tier 1 prototype 검증 후 art-director 합의 시 변경 가능 |

### Knob 상호작용 (변경 시 균형 재검토)

- **`starting_tokens` × `grant_on_boss_kill`**: 둘 다 후자 false면 토큰은 게임 전체에서 `starting_tokens` 회로 한정. 토큰 자원 관리 긴장이 *전체 게임 단위*에서 작동. 디자인 의도된 조합.
- **`dying_window_frames` × `input_buffer_pre_hit_frames`**: 실제 입력 가능 윈도우 = `B + D = 4 + 12 = 16` 프레임 ≈ 0.27s. 둘 다 조정 시 합 결과를 확인. Easy(B=6, D=16) → 22 프레임 ≈ 0.37s 인지적 여유. Hard(B=4, D=8) → 12 프레임 ≈ 0.2s 정밀 요구.
- **`infinite` × `grant_on_boss_kill`**: `infinite=true` 시 후자 무관 (토큰 검사 자체를 우회). 두 값을 모두 true로 둬도 무해 — Easy 모드는 단일 플래그 점검.
- **`max_tokens` × `grant_on_boss_kill`**: 후자 false면 전자도 무의미(`starting_tokens`이 사실상 cap). 정책 일관성 위해 두 값을 함께 설정.

### Tier별 권장 매트릭스

| 시점 | starting_tokens | max_tokens | grant_on_boss_kill | infinite | dying_window_frames | input_buffer_pre_hit_frames |
|---|---|---|---|---|---|---|
| **Tier 1 Prototype** | 3 | 5 | true | false | 12 | 4 |
| **Tier 2 MVP — Easy** | ∞ | (N/A) | true | **true** | 16 | 6 |
| **Tier 2 MVP — Normal** | 3 | 5 | true | false | 12 | 4 |
| **Tier 2 MVP — Hard** | 0 | 0 | false | false | 8 | 4 |
| **Tier 3 Full — 챌린지(토큰 0)** | 0 | 0 | false | false | 8 | 2 |

### 디자인 가드 (튜닝 시 절대 위반 금지)

1. `infinite=true` + `dying_window_frames < 6` 금지 — Easy 모드 사용자가 입력 한계로 사망하면 모드 자체 정합성 붕괴.
2. `starting_tokens > 5` 금지 (특별한 디자인 결정 없이) — anti-fantasy "안전망" 위반 임계.
3. `input_buffer_pre_hit_frames > dying_window_frames` 금지 — pre-hit 윈도우가 grace 윈도우보다 길면 윈도우 의미 붕괴.
4. `REWIND_SIGNATURE_FRAMES` 변경 시 i-frame과 shader timer 동시 변경 의무 — 한쪽만 변경 시 시각·메커닉 계약 분기 (Section D D4 인용).

## Visual/Audio Requirements

> Locked references: art-bible principle C, sections 1–4 + ADR-0001 R3 mitigation.
> art-director consultation 2026-05-09. Tier 1은 placeholder VFX/SFX; Tier 2 final shader; Tier 3 audio outsourcing.

### Visual Events (Section C 상태 전이별)

| Event | What player sees | Duration | Layer | Principle | Performance |
|---|---|---|---|---|---|
| **DYING entry** (lethal hit, grace 시작) | ECHO 아웃라인이 Neon Cyan `#00F5D4` → Ad Magenta `#FF2D7F`로 1회 펄스. fullscreen 효과 없음 | 12프레임 (`dying_window_frames` 기본값과 일치) | Character-local; world-space 변경 없음 | Principle A — grace 윈도우 동안 silhouette 가독성 유지 | ≤ 50 μs GPU (outline pass) |
| **rewind_consume** (입력 + 토큰 등록) | Frame 0 사전-플래시: 1프레임 fullscreen cyan burst `#00F5D4`, 30% alpha | 1프레임 | Fullscreen post-process | Principle C — color-inversion onset 사전 신호; Neon Cyan = player/REWIND 의미 | < 1 ms; `rewind_started`와 같은 틱 발화 |
| **rewind_started** (REWINDING 진입) | Frames 1–3: fullscreen cyan/magenta inversion (Rewind Cyan `#7FFFEE` 우세). Frames 4–8: UV-distortion 콜라주-레이어 글리치 분해. Frames 9–18: 역재생 애니메이션 + 팔레트 복원. | 18프레임 (art-bible Principle C 풀 시퀀스) | Fullscreen post-process (System #16 shader) | Principle C — "시간 되감기 = 색 반전 + 글리치" | Shader ≤ 500 μs/frame (≤ 1 ms rewind subsystem 봉투 안) |
| **REWINDING 중 — frames 19–30** (i-frame 꼬리) | Fullscreen 효과 클리어. ECHO가 2 px Rewind Cyan `#7FFFEE` halo outline을 모든 레이어 위에 렌더, frames 19–30 동안 100% → 0% alpha 감쇠. 월드는 정상 팔레트 복귀. | 12프레임 (frame 30 = `REWIND_SIGNATURE_FRAMES`까지의 꼬리) | Character-local halo above post-process | Principle A — ECHO 가독성 회복; UI text 없이 i-frame 활성 신호 | ≤ 80 μs GPU |
| **rewind_protection_ended** (REWINDING → ALIVE) | Halo 소멸. 지연된 HUD 토큰 갱신 발화 (Rule 15: HUD가 본 시그널까지 시각 갱신 지연) | 1프레임 (즉시) | HUD 시그널 계약만; world-space 없음 | Principle A — 시각 노이즈 없음; 클린 상태 복귀 | Nil |
| **Token replenishment** (boss kill + `token_replenished`) | REWINDING 중 발화 시: `rewind_protection_ended`까지 가시 변화 없음 (Rule 15). ALIVE 중 발화 시: 토큰 카운터 짧은 플래시 (System #13 HUD GDD 소유 — 본 GDD는 시그널 계약만) | REWINDING 중이면 protection-end 프레임으로 지연 | HUD 시그널 계약; world-space 없음 | Semantic Color: Neon Cyan = player-resource gain | Nil (시그널 emit) |
| **Token denied** (`tokens == 0`, 입력 등록) | Fullscreen 효과 없음. ECHO 아웃라인이 white-adjacent `#E8F8F4` (순백 X)로 3프레임 플래시. 토큰 카운터 거부 시각화는 System #13 HUD GDD 소유 | 3프레임 (character-local만) | Character-local | Principle A — grace-pulse와 구별되는 실패 신호; 적 가독성 보존 위해 Magenta로 씬 가득 채우지 않음 | ≤ 30 μs GPU |
| **DEAD entry** (DYING grace 만료) | 1프레임 `#FFFFFF` whiteout (art-bible Mood table "사망 후 재시작" — 순백의 단 1회 sanctioned 사용, Section 4 forbidden-color 예외) → 즉시 씬 복원 | 1프레임 | Fullscreen post-process | Mood table — "간결한 / 중립적인 / 즉각적인"; 사망 ceremony 없음, Pillar 1 < 1s 재시작 절대 기준 | ≤ 1 ms (1프레임) |

**Visual Tier note**: 모든 fullscreen post-process 행은 Tier 1에서 flat-color shader stub. 최종 inversion + UV-distortion shader (System #16)는 Tier 2. Character-local outline은 Tier 1에서 단순 `CanvasItem.draw_circle` mock 가능.

### Audio Events

| Event | Sound character | Mix priority | Distinct from | Tier note |
|---|---|---|---|---|
| **DYING entry** | 긴장된 mid-frequency pulse — synthwave filter sweep, rising | Mid; ambient duck, combat SFX 미duck | 모든 rewind cue — "데미지 등록, rewind 아님" 가독성 | Tier 1 placeholder |
| **rewind_consume** | 날카로운 synthwave glitch tear — bright attack, sub 100ms decay | **Foreground**; frames 1–8 동안 모든 mid/background duck | `denied` cue (AC-B4a 바인딩); DYING pulse | Tier 1 placeholder |
| **rewind_started** | `rewind_consume` cue가 low-drone reverse-sweep tail로 이어짐; 단일 합성 cue로 인식 (같은 물리 틱 — 1프레임 offset 불필요) | **Foreground**; consume과 동일 duck chain | Denied cue, ambient, enemy SFX | Tier 1: 단일 placeholder; Tier 2: 분할 레이어 |
| **rewind_protection_ended** | 부드러운 resolution click — low-pass, settled | Mid; 본 cue에서 duck lift | 모든 활성 rewind cue | Tier 1 placeholder |
| **Token replenishment** | Synthwave token-charge chime — 상승 2-note | Mid; REWINDING 중 발화 시 `rewind_protection_ended`까지 지연 (Rule 15) | Consume cue (gain으로 읽혀야 함, spend 아님) | Tier 1 placeholder |
| **Token denied** | 건조한 null-thunk — 둔탁한 low transient, reverb 없음 | **Foreground** (짧음); duck 없음 | **`rewind_consume` cue (AC-B4a 바인딩)** — 인지적으로 더 짧고, 더 낮고, synthwave 캐릭터 없음 | Tier 1 placeholder |
| **DEAD entry** | Silence cut — 즉시 오디오 정지, death sting 없음 | — 씬 리로드 1프레임 전 모든 활성 오디오 duck | 모든 rewind cue | Tier 1: hard mute; Tier 3: optional sub-100ms micro-sting |

### Critical Visual Requirements (binding gates)

1. **Full-viewport coverage**: frames 1–18 inversion 효과(System #16 shader)는 viewport 100% 커버 의무. character-local-only fallback은 본 게이트 실패. ECHO의 복원 위치가 사망 지점에서 멀 수 있어 — 시그니처가 *전체 씬*에 rewind 활성을 알린다.
2. **ECHO 가독성 0.5s glance (Principle A)**: frames 1–18 inversion 동안 ECHO는 0.5s 안에 식별 가능 의무. 구현 바인딩: ECHO sprite와 모든 bullet sprite는 post-process shader 위 CanvasLayer에 렌더 (렌더 순서: world → post-process shader → ECHO + bullets on top CanvasLayer). **이것이 R3 mitigation** — bullets는 fullscreen pass *후* compositing되므로 inversion 통과해 가시 유지. 대안 (luminance-mask threshold)은 CanvasLayer 정렬이 perf regression 유발 시 technical-artist에 secondary로 위임.
3. **Color-swap identity rule (Pillar 2)**: inversion 동안 ECHO (Neon Cyan → 마젠타로 보임)와 적 (Ad Magenta → cyan으로 보임)이 swap. 이는 silhouette 혼동을 야기해서는 안 됨. silhouette differentiation (Section 3 Shape Language)이 identity carrier — color-swap은 "월드 뒤집힘"으로 읽혀야지 "ally/enemy 혼동" 아님. Gate test: 1080p 0.2s glance test에서 색에 의존 없이 ECHO vs drone 식별 의무.
4. **Consume vs denied audio 구별 (AC-B4a 바인딩)**: `rewind_consume` cue는 bright/synthwave/attack. `denied` cue는 dry/thunk/short. 인지적으로 다름 의무. QA 테스트: blind listen 100% 정확 식별.
5. **Frames 19–30 꼬리 정의**: art-bible Principle C 18-프레임 시퀀스 후 12-프레임 꼬리는 ECHO halo decay (Visual Events 테이블 "REWINDING 중" 행). Principle C frame 18과 `REWIND_SIGNATURE_FRAMES = 30` 사이 갭을 닫는다.
6. **HUD 시그널 계약 (System #13 경계)**: 본 GDD는 시그널 이벤트만 명시. 토큰 카운터 레이아웃·애니메이션·포지셔닝은 System #13 HUD GDD 소유. 토큰 replenishment 시각화는 Rule 15에 따라 `rewind_protection_ended`로 지연.

### VFX Asset Spec Hooks

- `vfx_rewind_signature_loop_large.gdshader` — fullscreen inversion + UV distortion shader, frames 1–18; spec at `/asset-spec` Tier 2. Tier 1 stub: flat `#7FFFEE` 40% alpha fullscreen `ColorRect`.
- `vfx_echo_halo_decay_small.png` — 2 px Rewind Cyan outline sprite, frames 19–30 꼬리 + DYING pulse 사용; character-local CanvasItem draw. 명명 규약 `vfx_[effect]_[variant]_[size]`.
- `vfx_dead_whiteout_flash_large.png` — 1-프레임 `#FFFFFF` fullscreen sprite (Mood table sanctioned 순백 사용 — 단 1회). 단일 프레임, loop variant 불필요.

📌 **Asset Spec** — Visual/Audio 요건 정의됨. art-bible 승인 후 `/asset-spec system:time-rewind` 실행해 본 섹션에서 per-asset visual descriptions, dimensions, generation prompts 생성.

### Open Visual/Audio Questions

1. **Frames 1–18 CanvasLayer 정렬 vs shader 성능**: ECHO + bullet sprite를 post-process pass 위 top CanvasLayer에 두는 것이 batching 깨거나 Steam Deck 500 μs shader budget 초과 안 함을 technical-artist와 확인. 초과 시 luminance-mask fallback 평가.
2. **DYING pulse 색**: 현재 사양은 Neon Cyan → Ad Magenta pulse. Tier 1 플레이테스트에서 REWINDING inversion onset과 혼동되면 DYING pulse를 Vintage Yellow `#F0C040`로 변경 (art-bible 충돌 없음 — Yellow는 Sigma Unit / 인간 흔적, 경고로 읽힘). 첫 플레이테스트로 결정 지연.
3. **`rewind_consume` + `rewind_started` 합성 오디오**: 단일 합성 cue로 명시 (같은 틱). technical-artist의 Tier 2 구현이 split-layer 아키텍처(consume = attack layer, started = tail layer) 요구 시, 인지 결과가 silence gap 없는 단일 연속 이벤트인 한 허용.

## UI Requirements

> Time Rewind은 자체 UI 위젯을 소유하지 않는다. 모든 UI 표시 — 토큰 카운터, 거부 시각화, 충전 애니메이션 — 는 **System #13 HUD GDD가 소유**한다. 본 절은 HUD가 *어떤 데이터를* 본 시스템으로부터 받아 표시해야 하는지의 **데이터 계약**만 명시한다.

### HUD가 본 시스템으로부터 받는 데이터

| 데이터 | 소스 | 갱신 주기 | 표시 의무 |
|---|---|---|---|
| `remaining_tokens: int` | `TimeRewindController.get_remaining_tokens()` (초기) + `token_consumed`, `token_replenished` 시그널 (이후) | 시그널 driven | 좌상단 카운터. 정확한 정수값 표시. `RewindPolicy.infinite == true`일 때 "∞" 또는 무한 기호 표시. |
| `rewind_state: enum {ALIVE, DYING, REWINDING}` | SM이 소유; HUD가 SM 시그널 구독 | 상태 전이 시점 | DYING 동안 카운터에 거부 잠금 표시(`tokens == 0`인 경우만). REWINDING 동안 카운터 갱신 지연(Rule 15). |
| `consume event` (1회성) | `token_consumed` 시그널 | 발화 즉시 | 카운터 -1 애니메이션. art-bible Neon Cyan 펄스. 즉시 갱신 (REWINDING 진입 *이전* 시각화). |
| `replenish event` (1회성) | `token_replenished` 시그널 | REWINDING 중 발화 시 `rewind_protection_ended`까지 지연 | 카운터 +1 애니메이션. |
| `denied event` (1회성) | SM이 `tokens == 0 && DYING` 시 발행 (HUD 전용 시그널 또는 SM exposed) | 입력 즉시 | 카운터 거부 시각화 (System #13 HUD GDD가 정의 — Visual Events 테이블 "Token denied" 행에 character-local 부분만 명세) |

### HUD 구현 제약 (binding)

- HUD는 `_displayed_tokens` 캐시를 보유해 변경 시에만 `Label.text`를 갱신 의무 (Integration Risk I6, AC-B4 보조).
- HUD는 TRC를 폴링 금지 — 시그널 구독 only (observer 패턴).
- HUD는 REWINDING 동안 시각 갱신을 buffer하고 `rewind_protection_ended`에서 flush 의무 (Rule 15).

### Rationale

토큰 카운터의 정확한 위치·크기·애니메이션 타이밍·폰트·색은 art-bible 색 팔레트와 Mood table을 따라 HUD GDD에서 통합 결정된다 — Time Rewind이 단독으로 결정할 경우 HUD 일관성이 깨진다. 본 GDD가 결정하는 것은 데이터 계약뿐이다.

## Acceptance Criteria

> Test framework: GUT (Godot Unit Test). Coverage targets: balance formulas 100%, gameplay logic 70%.
> 34개 기준을 A–G 7군으로 분류 (A:5 / B:8 / C:6 / D:5 / E:4 / F:2 / G:4 — Round 2 정정, 이전 표기 33은 오집계). 자동화는 [AUTO], 수동 테스트는 [MANUAL].
> Determinism은 단일 머신·단일 빌드 보장 (ADR-0003 R5). qa-lead 검증 2026-05-09.

### A. Capture & Restoration

- **AC-A1** [AUTO] GIVEN 세션이 W(90) 물리 프레임 이상 진행, WHEN `_physics_process` 발화, THEN `_capture_to_ring()`이 8개 `PlayerSnapshot` 필드를 `_ring[_write_head]`에 기록하고 `_write_head = (_write_head + 1) % 90`을 같은 틱에 진행. _Rule 1 / Formula D3 검증._
- **AC-A2** [AUTO] GIVEN `rewind_started` emit됨, WHEN REWINDING 동안 `_physics_process` 실행, THEN `_write_head` 불변. GIVEN `rewind_protection_ended` 발화, WHEN 다음 `_physics_process` 실행, THEN `_write_head`가 정확히 1 진행. _Rule 2 검증._
- **AC-A3** [AUTO] GIVEN `lethal_hit_detected`이 frame F에 발화 (TRC 구독 시그널 — Damage 2-stage F.1 #8), WHEN DYING grace 윈도우(F~F+11) 어느 시점이든 `try_consume_rewind()` 호출, THEN `restore_idx == (_lethal_hit_head − 9 + 90) % 90`이며 `_lethal_hit_head`는 frame F의 `_write_head` 동결값(호출 시점 값 아님). 테스트 fixture는 frame F의 `_write_head`를 spy 변수로 별도 기록 후 `_lethal_hit_head`와 비교. _Rule 9 / Formula D1 / ADR-0002 Amendment 1 검증._
- **AC-A4** [AUTO] GIVEN `try_consume_rewind()` 가 `true` 반환, WHEN `restore_from_snapshot(snap)` 완료, THEN player 노드의 `global_position`, `velocity`, `facing_direction`, `current_weapon_id`, `animation_name`, `animation_time`, `is_grounded` 모두 `snap` 값과 일치. `AnimationPlayer.seek(snap.animation_time, true)` 호출됨. _Rule 10 / ADR-0001 7-field 계약 검증._
- **AC-A5** [AUTO] GIVEN SM이 frame R에 REWINDING 진입, WHEN `rewind_protection_ended` 까지 프레임 카운팅, THEN 정확히 30 프레임. `physics_frames(rewind_protection_ended) − physics_frames(rewind_started) == 30`. _Rule 11 / `REWIND_SIGNATURE_FRAMES` 검증._

### B. Token Economy

- **AC-B1** [AUTO] GIVEN `_ready()`가 `starting_tokens=3`, `infinite=false` `RewindPolicy`로 호출됨, WHEN `get_remaining_tokens()` 즉시 폴, THEN 3 반환. _Rule 3 / Formula D2 `T_session_start` 검증._
- **AC-B2** [AUTO] GIVEN `grant_on_boss_kill=true`, WHEN `boss_defeated` 시그널 발화, THEN `get_remaining_tokens()` 정확히 1 증가, `token_replenished` 새 합계로 emit. _Rule 15 / Formula D2 검증._
- **AC-B3** [AUTO] GIVEN `get_remaining_tokens() == max_tokens`(기본 5), WHEN `boss_defeated` 재발화, THEN `get_remaining_tokens()`이 `max_tokens` 초과 안 함. _Rule 3 / `RewindPolicy.max_tokens` cap 검증._
- **AC-B4** [AUTO] GIVEN `_tokens == 0` AND ECHO DYING 상태, WHEN `rewind_consume` 입력 등록, THEN `try_consume_rewind()` `false` 반환, SM은 DYING 유지, 거부 SFX 식별자(소비 SFX와 구분) 1회 발화. 토큰 카운트 0 유지. _Rule 7 / Formula D2 검증._
- **AC-B4a** [MANUAL] GIVEN AC-B4 조건, WHEN 거부 SFX 재생, THEN 토큰 소비 사운드와 인지적으로 구분되는 별개 오디오 큐 청취 가능. _Rule 7 anti-confusion audio 검증._
- **AC-B5** [AUTO] GIVEN test harness에서 같은 물리 프레임에 `boss_defeated`와 `lethal_hit_detected` 주입 (Boss `process_physics_priority=10`, Damage `process_physics_priority=2` per damage.md Round 3 lock), 플레이어 input은 사전 buffered (Rule 5 input_buffer_pre_hit_frames), WHEN 시그널 처리, THEN signal log에서 **`token_consumed`가 `token_replenished` *이전* 관측** (Round 1 정정 — Damage(2) → SM consume → Boss(10) grant 순서), 두 이벤트 후 `get_remaining_tokens()`이 이벤트 전 값과 동일 (consume + grant = net zero). 중간 T=0 dip은 같은 틱 내 비관측이므로 직접 검증 안 함. _Rule 16 / Integration Risk I2 검증._
- **AC-B6** [AUTO] GIVEN `RewindPolicy`가 `_ready()`에서 `@export var rewind_policy`로 주입됨, WHEN 외부 caller가 `_ready()` 완료 후 `rewind_policy` 필드 mutation 시도, THEN `_tokens`·`_is_rewinding`·기타 파생 상태에 영향 없음(setter 비공개; export 참조는 read-only post-ready). _Rule 3 / Integration Risk I7 검증._
- **AC-B7** [AUTO] GIVEN `RewindPolicy.infinite == true` (Easy), WHEN `try_consume_rewind()`을 임의 횟수 호출, THEN `_tokens` 절대 감소 안 함(토큰 검사 경로 우회), buffer가 primed이고 상태가 DYING인 한 항상 `true` 반환. _Formula D2 `T_easy_guard` 검증 — checks skipped, not infinity arithmetic._

### C. State Machine

- **AC-C1** [AUTO] GIVEN ECHO ALIVE, WHEN `player_hit_lethal` 발화, THEN SM이 같은 물리 틱 안에 DYING 전이, `_lethal_hit_latched`가 `true` 설정. _Rule 4 / States and Transitions 검증._
- **AC-C2** [AUTO] GIVEN ECHO DYING AND 12프레임 경과 with no valid rewind input, WHEN frame 13 도착, THEN SM이 DEAD 전이 AND `_lethal_hit_latched`가 `false`로 클리어됨 (직접 DYING→DEAD 경로의 latch 해제 — Round 2 추가). _Rule 8 + Rule 17 latch clear 양 경로(DYING→DEAD 본 AC + REWINDING→ALIVE AC-C3) / `dying_window_frames` 기본 12 검증._
- **AC-C3** [AUTO] GIVEN ECHO REWINDING, WHEN 30 프레임 경과, THEN `rewind_protection_ended` emit + SM이 ALIVE 전이. `_lethal_hit_latched`가 `false`로 클리어됨. _Rule 11 / States and Transitions 검증._
- **AC-C4** [AUTO] GIVEN `_lethal_hit_latched == true` (이미 DYING), WHEN 두 번째 `player_hit_lethal` 발화, THEN SM이 무시 — `_lethal_hit_head` 재캐시 안 함, DYING 카운트 reset 안 함. _Rule 17 / E-12, E-13 검증._
- **AC-C5** [AUTO] GIVEN ECHO DYING 또는 REWINDING, WHEN pause 입력 디스패치, THEN SM 인터셉트해 swallow — pause 시스템 미발동, DYING/REWINDING 카운트 중단 없이 진행. _Rule 18 / E-19 검증._
- **AC-C5a** [MANUAL] GIVEN 실제 pause UI 연결, WHEN 플레이어가 DYING 동안 pause 버튼 누름, THEN pause 메뉴 표시 안 됨, DYING 타이머 가시적 진행 지속. _Rule 18을 풀 씬 컨텍스트에서 검증._

### D. Edge Cases

- **AC-D1** [AUTO] GIVEN hazard 소스(가시·구덩이·kill volume)가 `player_hit_lethal(cause)` 발화, `cause`는 hazard 타입 식별, WHEN SM이 수신, THEN ECHO가 발사체 치명타와 동일하게 DYING 진입 — `_lethal_hit_head` 캐시, 12프레임 grace 윈도우 개시. _E-11 검증._
- **AC-D2** [AUTO] GIVEN ECHO DYING AND 연속 데미지 소스가 후속 프레임에 둘째 `player_hit_lethal` 발화, WHEN SM 처리, THEN `_lethal_hit_latched`가 차단, `_lethal_hit_head` 원래 값 유지, DYING 카운트 연장·reset 없음. _E-12 검증._
    - **Round 5 갱신 노트 (2026-05-10)**: 둘째 hit의 `player_hit_lethal` emit 자체가 *primary*로는 Damage step 0 first-hit lock(`damage.md` C.3.2 + AC-36)에 의해 차단된다. 본 AC가 검증하는 SM `_lethal_hit_latched`는 secondary defence (Damage step 0이 우회된 미래 corner case 대비). Primary block 차단 시에는 둘째 emit 자체가 발화 안 되어 본 AC의 SM 처리 분기는 도달 안 함; 본 AC는 SM stub로 직접 `player_hit_lethal` 주입 시나리오로 latch 동작을 격리 검증한다.
- **AC-D3** [AUTO] GIVEN `scene_will_change` 시그널 발화, WHEN `_buffer_invalidate()` 실행, THEN `_buffer_primed = false`, `_write_head = 0`, `_tokens` 불변. 새 씬에서 W 프레임 전 lethal hit 시 `DYING → DEAD`(buffer-primed 가드 Rule 13-bis). _E-16 검증._
    - **Note (I7 fix 2026-05-10)**: `_lethal_hit_head`는 `_buffer_invalidate()`가 명시적으로 클리어하지 않는다(의도). Rule 13-bis buffer-primed 가드가 새 씬 첫 W 프레임 동안 `try_consume_rewind()`를 즉시 false 반환시키므로 `_lethal_hit_head`의 stale 값이 새 씬에서 사용될 가능성은 0이다. 새 lethal_hit_detected 도달 시 Rule 4가 `_write_head` 현재값으로 덮어쓴다. `_lethal_hit_head`를 명시적 클리어하지 않는 것이 단순성·결정성 모두에 우월.
- **AC-D4** [AUTO] GIVEN ECHO DYING 동안 보스 페이즈 전환(HP 임계 통과), WHEN SM이 전환 처리, THEN 보스 페이즈 rewind 발생 안 함 — ECHO 복원 후에도 보스 `_phase`가 새 값 유지. **Test harness (Round 2 추가)**: frame-perfect injection helper — fixture가 deterministic physics frame counter를 stub해 frame F에 lethal hit + frame F+k에 boss phase advance를 결정적으로 주입(Engine.get_physics_frames() 직접 polling 금지; signal injection으로 정확한 frame ordering 강제). _E-18 / ADR-0001 Player-only scope 검증._
- **AC-D5** [AUTO] GIVEN ECHO mid-shooting-animation 중 `restore_from_snapshot()` 호출, WHEN `AnimationPlayer.seek()` 발화로 method-track key (예: `_on_anim_spawn_bullet`)가 평소대로면 트리거 시점, THEN 발사체 spawn 안 됨 — `PlayerMovement._is_restoring == true`이기 때문. `_is_restoring`은 다음 `_physics_process`에서 `false` 복원. **Test harness (Round 2 추가)**: frame-perfect injection — animation 시작 후 정확한 frame offset에 lethal hit를 주입하는 fixture (시간 기반 polling 대신 frame-counter 결정적 매핑, AC-D4 harness와 동일 패턴 재사용). _E-21 / Integration Risk I9 검증._

### E. Performance

- **AC-E1** [MANUAL] GIVEN 60 Hz 게임 + TRC 활성 (Round 2 reclassification: [AUTO]→[MANUAL] — GUT headless로는 Godot 에디터 내장 Profiler 구동 불가), WHEN `_capture_to_ring()` 비용을 600 연속 프레임 동안 Godot 에디터 내장 Profiler로 샘플링, THEN per-tick 평균 ≤ 16.6 ms 프레임 budget의 0.05% (≤ 8.3 μs/tick — D6 정정 후 worst case 4 μs/tick은 봉투 안 안전). **자동화 가능 보조 검사 [AUTO]**: GUT에서 `Time.get_ticks_usec()` delta로 capture 비용 측정 (Profiler 정확도 대비 인터프리터 jitter 허용오차 ±2 μs). 두 측정 모두 cap 만족 시 PASS. _Formula D6 / technical-preferences.md 시간 되감기 서브시스템 cap 검증._
- **AC-E2** [AUTO] GIVEN test harness에서 단일 rewind 이벤트 트리거, WHEN `restore_from_snapshot()` 실행 (AnimationPlayer.seek 포함), THEN restore 호출 총 경과 시간 ≤ 1 ms (1,000 μs). _Formula D6 / `rewind_subsys_cap` 검증._
- **AC-E3** [AUTO] GIVEN `_ready()`가 90개 `PlayerSnapshot` Resource 사전 할당, WHEN test 씬에서 1000회 연속 rewind 이벤트 트리거 후 Godot 메모리 스냅샷, THEN `PlayerSnapshot` 인스턴스 개수가 정확히 90 (per-tick allocation 0, leak 0). ring buffer resident 메모리 ≤ 25 KB. _Formula D5 정정 figure 검증._
- **AC-E4** [MANUAL] GIVEN Steam Deck 위에 대표 encounter (적 30+, 활성 발사체 50+), WHEN 플레이어가 rewind 트리거, THEN 60fps 유지: ≥ 99% 프레임이 16.6 ms 이내 완료(Godot 내장 frame-time 오버레이 측정). _technical-preferences.md 60 fps locked 검증._

### F. Determinism

- **AC-F1** [AUTO] GIVEN 스크립트된 test 시퀀스(고정 player input, 고정 enemy `ai_seed`, 고정 `spawn_physics_frame`), WHEN 같은 머신·빌드에서 시퀀스 1000회 실행, THEN 모든 복원 이벤트가 1000 runs 전체에서 bit-identical `PlayerSnapshot` 값 (position, velocity, facing_direction, animation_time, weapon_id, is_grounded). _ADR-0003 Validation #1 / R5(단일 머신 보장) 검증._
- **AC-F2** [AUTO] GIVEN 같은 encounter seed + deterministic input 시퀀스, WHEN ECHO가 같은 지점에서 두 독립 test run에서 사망 + rewind, THEN `rewind_protection_ended` 다음 프레임의 ECHO `global_position`·`velocity`가 두 run 간 동일 (bit-identical, 같은 머신). _ADR-0003 R-RT3-01 / Formula D1 검증._

### G. Anti-Fantasy Guards

- **AC-G1** [AUTO] GIVEN boss kill 이벤트 미발화, WHEN 임의 물리 프레임 경과, THEN `_tokens` 감소·증가 모두 없음 (passive decay 금지, passive grant 금지) — 토큰 변화는 `try_consume_rewind()`(소비) 또는 `grant_token()`(boss kill)으로만. _Section B Anti-Fantasy "무적 파워 판타지" / Rule 3 검증._
- **AC-G2** [AUTO] GIVEN ECHO DYING + 플레이어가 frame F에 pause 입력 등록, WHEN SM이 pause swallow (Rule 18), THEN DYING grace 윈도우가 frame F + (12 − elapsed)에 만료, pause 시도 영향 없음. 윈도우 연장 안 됨. _Anti-Fantasy "시간 정지 아님" / Rule 18 / Section G design guard 검증._
- **AC-G3** [AUTO] GIVEN `RewindPolicy`가 `starting_tokens=0` AND `infinite=false` (Hard), WHEN ECHO 치명타 수신, THEN SM이 정확히 `dying_window_frames` 프레임 동안 DYING 진입, 임의 rewind 입력 시 거부 큐 발화, 만료 시 DEAD 전이. 토큰 0에서도 DYING 윈도우 존재. _Section G Tuning guard / States and Transitions Hard 모드 노트 검증._
- **AC-G3a** [MANUAL] GIVEN AC-G3 Hard 조건, WHEN 플레이어가 DYING 동안 rewind 입력 시도, THEN 거부 audio cue 청취 가능 + DYING 시각 상태 가시 (예: rewind 시각 시그니처 미발화). _Hard 모드 UX 의도 검증._

### Test Evidence Mapping

| Coverage area | Test type | Evidence location |
|---|---|---|
| Capture cadence & ring buffer | Unit (GUT) | `tests/unit/time-rewind/` |
| `_lethal_hit_head` freeze / `restore_idx` | Unit (GUT) | `tests/unit/time-rewind/` |
| 7-field restore correctness | Unit (GUT) | `tests/unit/time-rewind/` |
| REWINDING 30프레임 정확성 | Unit (GUT) | `tests/unit/time-rewind/` |
| 토큰 경제 (start, grant, cap, consume, infinite) | Unit (GUT) | `tests/unit/time-rewind/` |
| 같은 틱 boss/lethal 시그널 ordering | Integration (GUT) | `tests/integration/time-rewind/` |
| State machine 4-state 전이 | Unit (GUT) | `tests/unit/time-rewind/` |
| Lethal-hit latch / 연속 데미지 | Unit (GUT) | `tests/unit/time-rewind/` |
| Pause swallow (SM 레벨) | Unit (GUT) | `tests/unit/time-rewind/` |
| 씬 전환 시 buffer invalidate | Unit (GUT) | `tests/unit/time-rewind/` |
| Animation method-track `_is_restoring` 가드 | Unit (GUT) | `tests/unit/time-rewind/` |
| 1000-cycle determinism | Integration (GUT) | `tests/integration/time-rewind/` |
| Resident 메모리 / no-leak (1000 rewinds) | Integration (GUT) | `tests/integration/time-rewind/` |
| 거부 audio cue 구분성 | Manual playtest | `production/qa/evidence/` |
| Pause swallow 풀 씬 | Manual playtest | `production/qa/evidence/` |
| Steam Deck 60fps 부하 | Manual (target HW) | `production/qa/evidence/` |
| Hard 모드 UX (거부 cue, DYING 가시) | Manual playtest | `production/qa/evidence/` |

### Out-of-Scope (의도적으로 본 GDD에서 테스트하지 않음)

다른 시스템 GDD가 소유하는 통합 계약 — test evidence는 그쪽에 위치:

- **Damage System (#8)**: `lethal_hit_detected`/`death_committed` 2단계 분리; 모든 hazard 소스의 `player_hit_lethal(cause)` emit; 같은 틱 다중 탄환 hits에 대한 deterministic damage policy (ADR-0003 R6).
- **Scene Manager (#2)**: `scene_will_change()` 발행 타이밍과 보장; TRC 구독 와이어링.
- **HUD (#13)**: `_displayed_tokens` diff 체크 per-fire allocation 방지; REWINDING 중 시각 갱신 지연.
- **Visual Shader (#16)**: 내부 0.5s `Timer` `rewind_started`만 와이어링; `rewind_completed` 종료 트리거 *부재* (Integration Risk I5).
- **Weapon / Pickup (#7, #19)**: `WeaponSlot.set_active(invalid_id)` silent fallback to `id=0`; ammo 카운트 복원 정책 결정 (F6 / E-22 — Weapon GDD 작성 시까지 미결).
- **Boss Pattern (#11)**: `process_physics_priority = 10` 강제; phase 전환 rewind-immunity 문서화.
- **Pause System**: DYING/REWINDING pause-swallow 예외 pause GDD 명시 (Rule 18 의무).

## Open Questions

본 GDD 작성 중 식별된 미결 질문 목록. 각 항목은 **owner(해결 책임자)**와 **target(해결 시점)**을 가진다.

### 외부 GDD 의존 (다른 시스템 GDD 작성 시 결정)

| ID | Question | Owner | Target |
|---|---|---|---|
| **OQ-1** | Ammo 카운트 복원 정책 — (a) "resume with live ammo" 비준 vs (b) `PlayerSnapshot.ammo_count` 추가 ADR amendment? (E-22, F6) | Weapon GDD (#7) | Weapon GDD 작성 시 |
| **OQ-2** | Damage 시스템이 `lethal_hit_detected`와 `death_committed` 2단계 분리를 어떻게 구현하는가? (E-11, Integration Risk I1) | Damage GDD (#8) | Damage GDD 작성 시 |
| **OQ-3** | `WeaponSlot.set_active(invalid_id)` silent fallback의 정확한 동작 — id=0 (기본 무기) 외에 fallback 시 시각·오디오 신호 필요 여부? (E-15) | Weapon GDD (#7) | Weapon GDD 작성 시 |
| **OQ-4** | `scene_will_change()` 시그널이 정확히 언제 emit되는가 — 트리거 진입 시점 vs unload 시작 시점? 토큰은 무조건 보존? (E-16) | Scene Manager GDD (#2) | Scene Manager GDD 작성 시 |
| **OQ-5** | DYING/REWINDING 중 pause swallow의 UX 신호 — pause 시도 시 거부 cue를 발화할 것인가, 침묵으로 처리할 것인가? (Rule 18, E-19) | Pause System GDD | Pause System GDD 작성 시 |

### 플레이테스트 결정 대기

| ID | Question | Owner | Target |
|---|---|---|---|
| **OQ-6** | DYING pulse 색 — 현재 사양 Neon Cyan → Ad Magenta. REWINDING inversion onset과 혼동 시 Vintage Yellow `#F0C040`로 변경 (V/A Open Q2) | art-director + qa-lead | Tier 1 첫 플레이테스트 |
| **OQ-7** | `dying_window_frames` 기본값 — 12프레임이 Defiant Loop fantasy 충족하는지, 너무 관대한지? Easy 16 / Hard 8 분기가 충분한지? | game-designer + qa-lead | Tier 1 prototype 플레이테스트 (3-5인) |
| **OQ-8** | `input_buffer_pre_hit_frames` 기본값 — 4프레임이 jitter 흡수에 충분한지? 컨트롤러 다양성에서 입력 손실 발생 시 6으로 상향? | gameplay-programmer + qa-lead | Tier 1 prototype 컨트롤러 호환성 테스트 |

### 기술 검증 대기

| ID | Question | Owner | Target |
|---|---|---|---|
| **OQ-9** | `AnimationPlayer.seek(time, true)` exact-frame restore 동작이 looping animation에서 글리치 없이 작동하는지 (Engine context HIGH risk) | technical-artist + godot-specialist | Tier 1 Week 1 prototype |
| **OQ-10** | 1000-cycle determinism test가 dev 머신에서 단일 머신·단일 빌드 보장으로 PASS하는지 (ADR-0003 R5; AC-F1) | gameplay-programmer | Tier 1 Week 1 prototype |
| **OQ-11** | Frames 1–18 fullscreen post-process + ECHO·bullet sprite를 top CanvasLayer로 분리하는 구조가 Steam Deck에서 500 μs shader budget 안 유지하는지 (V/A Open Q1) | technical-artist | Tier 2 final shader 작성 시 |
| **OQ-12** | `rewind_consume` + `rewind_started` 단일 합성 오디오 cue가 split-layer 구현으로 Tier 2에 가능한지 (V/A Open Q3) | audio-director | Tier 2 audio 외주 시 |

### 향후 시스템 결정

| ID | Question | Owner | Target |
|---|---|---|---|
| **OQ-13** | Easy 토글 인터페이스 — game-concept Q3 (단일 토글 Cuphead Simple vs 슬라이더 Hades God Mode) — Difficulty Toggle GDD가 결정 | game-designer | Difficulty Toggle GDD (#20) 작성 시 |
| **OQ-14** | KB+M 기본 키 `Shift` 적합성 — Steam Deck KB+M 모드와 데스크탑 모드에서 ergonomic 검증 | ux-designer | Tier 2 입력 매핑 정식화 |
| **OQ-15** | Tier 3 Input Remapping에서 `"rewind_consume"` 액션이 chord (다중 키)로 매핑 가능한지 — technical-preferences "단일 버튼, no chord" 제약 유지? | ux-designer + game-designer | Tier 3 Input Remapping 시스템 (#23) 작성 시 |

### 해결됨 (참고용)

다음 질문들은 본 GDD 작성 중 해결되어 ADR/Section에 락인됨:

- ✅ Trigger model (explicit / auto / hybrid) → Constrained-A: explicit + DYING 12프레임 grace (Rule 4-7)
- ✅ Post-restore protection 길이 → 30 frames (0.5s) i-frame, time-based, signature와 동일 출처 (Rule 11)
- ✅ Re-entry 정책 → REWINDING 중 silent ignore (Rule 13), DEAD 무조건 차단 (Rule 14)
- ✅ State machine 4-state 합의 (ALIVE / DYING / REWINDING / DEAD)
- ✅ 캡처 PAUSE 정책 → REWINDING 동안만 동결 (Rule 2). 누적 토큰 사용 시 더 멀리 되감기는 시각·메커닉 정합 효과
- ✅ rewind_completed 의미 충돌 → 옵션 α 신규 시그널 `rewind_protection_ended` 추가 (ADR-0001 계약 확장)
- ✅ Boss 토큰 충전 — 시그널 기반, 직접 호출 금지 (Rule 16, C.3 #11)
- ✅ `RewindPolicy` 런타임 mutation — 금지, 씬 리로드 시에만 (Rule 3, AC-B6)
- ✅ TRC `process_physics_priority = 1` 위치 (architecture.yaml 갱신 대상)
- ✅ `restore_idx` lethal-hit head freeze (ADR-0002 Amendment 1)
- ✅ Buffer-primed 가드 (Rule 13-bis, AC-D3와 보완)
- ✅ Lethal-hit latch (Rule 17, E-12, E-13)
- ✅ DYING/REWINDING pause swallow (Rule 18, E-19)
- ✅ Animation method-track `_is_restoring` 가드 (E-21, I9)
