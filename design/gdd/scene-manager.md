# Scene / Stage Manager

> **Status**: In Design
> **Author**: seong-mungi + game-designer / systems-designer / gameplay-programmer / engine-programmer (per `.claude/skills/design-system` Section 6 routing for Foundation/Infrastructure)
> **Last Updated**: 2026-05-11
> **Implements Pillars**: Pillar 1 (학습 도구 — < 1초 재시작 절대 양보 X) · Pillar 2 (결정론 — boot-time RNG 금지) · Pillar 4 (5분 룰 — Press-any-key gate 금지) · Pillar 5 (작은 성공 — Tier 1 단일 스테이지 슬라이스 한정)
> **Engine**: Godot 4.6 / GDScript (statically typed)
> **Review Mode**: lean (CD-GDD-ALIGN gate skipped per `production/review-mode.txt`)
> **Source Concept**: `design/gdd/game-concept.md`
> **Cross-doc obligations carried in**: PM #6 OQ-PM-1 (8-var ephemeral clear ownership) · SM #5 OQ-SM-2 (boot() caller) · TR #9 OQ-4 (`scene_will_change` emit timing + token preservation)

---

## A. Overview

Scene / Stage Manager는 Echo의 씬 라이프사이클(로드 · 언로드 · 체크포인트 재시작)과 결정론적 부트 순서를 단일 출처로 소유하는 Foundation 시스템이다. `SceneManager` 오토로드 노드 하나가 다음 5개 책임을 갖는다: (1) **PackedScene 전환** — `change_scene_to_packed`을 통한 씬 swap 및 Tier 2 다중 스테이지 단계에서 도입될 비동기 사전 로드 분기, (2) **체크포인트 앵커 등록 + < 1초 재시작 보장** (Pillar 1 비협상 — 죽음 후 1초 이내 재시작 절대 양보 X), (3) **씬 경계 시그널 `scene_will_change()` emit** — 본 시그널은 Time Rewind Controller가 구독하여 ring buffer를 무효화(`_buffer_invalidate()` — E-16 invalid-coord 텔레포트 방지), EchoLifecycleSM이 구독하여 O6 cascade(`_lethal_hit_latched` + 입력 버퍼 + O8 idempotency 카운터 클리어) 구동, Player Movement의 8-var ephemeral state(4 coyote/buffer + 4 facing Schmitt flag)를 — 직접 구독이 아닌 EchoLifecycleSM 경유로 — cascade 클리어하는 단일 트리거다, (4) **`boss_killed(boss_id)` 시그널 구독** — 스테이지 클리어 분기, (5) **`scene_manager` 그룹 등록** (`_ready()` 첫 줄에서) — EchoLifecycleSM이 `get_first_node_in_group(&"scene_manager")`로 결정론적 디스커버리 가능하도록. ECHO 부트 시 ALIVE 상태로 강제 전이 + DEAD 상태로부터의 유일한 ALIVE 부활 경로(state-machine.md AC-26 / DeadState 영구성 contract) 두 가지 lifecycle 책임도 본 시스템이 단일 출처로 소유한다. **Tier 1 범위는 단일 스테이지 슬라이스 + 체크포인트 재시작에 한정**한다(Pillar 5 — Anti-Pillar #2: 5+ 스테이지 영구 배제 · Tier 1 = 1 stage); 다중 씬 전환과 콜라주 사진 텍스처 메모리(1.5 GB 천장) 명시적 해제는 Tier 2(3 stages) 진입 게이트로 이월하여 본 GDD 개정으로 추가한다.

## B. Player Fantasy

Scene Manager는 Foundation이며, fantasy는 *플레이어 감정*이 아닌 **플레이어가 결코 보지 말아야 할 비-이벤트**로 정의된다: (1) 죽음과 재시작 사이 1초를 초과하는 *생각할 틈* — Pillar 1 비협상; (2) 부트와 첫 입력 가능 사이 5분을 초과하는 *로딩 인내* — Pillar 4 5분 룰; (3) 체크포인트 앵커와 부활 위치 사이의 *비결정론적 드리프트* — Pillar 2 결정론. 이 세 invariant가 충족될 때 비로소 TR#9의 Defiant Loop와 PM#6의 ephemeral state 클리어 cascade가 정상 동작한다. 본 GDD는 *어떤 invariant로* cascade를 가능케 하는지만 정의하며, fantasy 본문은 `time-rewind.md` Section B가 소유한다.

**Cross-reference**:
- Pillar 1 (학습 도구) / Pillar 2 (결정론) / Pillar 4 (5분 룰) — `design/gdd/game-concept.md`
- Fantasy owner (Defiant Loop) — `design/gdd/time-rewind.md` Section B
- Cascade clear receiver (8-var ephemeral) — `design/gdd/player-movement.md` F.4.2 row #2

**Three invariants → AC mapping commitment**: 각 invariant는 Section H Acceptance Criteria에 testable 형태로 1:1 인코딩한다 — (1) checkpoint restart time ≤ 1.000 s (60 ticks @ 60 Hz); (2) cold-boot to first-actionable-input ≤ 300 s 측정 + headless smoke check; (3) `scene_will_change` emit timing 결정론 + ECHO `_ready()` spawn 위치 결정론. Section B의 fantasy 약속과 Section H의 검증 사이 1:1 대응을 유지한다 (state-machine.md B/H 패턴 준수).

## C. Detailed Design

### C.1 Core Rules

Scene Manager는 Godot `SceneTree`의 씬 수명주기를 소유하는 단일 `SceneManager` 오토로드 노드다. 아래 14개 규칙이 Foundation의 불변 계약을 형성한다.

---

**[그룹 등록 및 디스커버리]**

**Rule 1.** `SceneManager._ready()`의 **첫 번째 라인**은 반드시 `add_to_group(&"scene_manager")` 이어야 한다. 다른 어떤 초기화 코드도 그 이전에 실행되면 안 된다.
*Rationale*: Pillar 2 결정론 — `EchoLifecycleSM._ready()`(state-machine.md C.2.1 line 322) 의 `get_first_node_in_group(&"scene_manager")` 디스커버리가 `_ready()` 체인 내 어떤 시점에서도 null을 반환하지 않도록 보장. 오토로드는 씬 트리 인스턴스화 전에 초기화되므로 본 제약은 안전하다.

---

**[오토로드 아이덴티티 및 프로세스 사다리]**

**Rule 2.** `SceneManager`는 오토로드 싱글턴이며 `_physics_process` 또는 `_process`를 구현해서는 **안 된다**. ADR-0003 `process_physics_priority` 사다리(PlayerMovement=0, TRC=1, Damage=2, enemies=10, projectiles=20)는 씬 노드에만 적용된다; SceneManager는 이 사다리에서 슬롯을 차지하지 않는다.
*Rationale*: ADR-0003 결정성 — 시그널 기반 비동기 반응 + Tier 1에서는 단일 씬 슬라이스이므로 per-tick 폴링 불필요.

---

**[Tier 1 씬 전환 범위 — Anti-Pillar 게이트]**

**Rule 3.** Tier 1에서 유일하게 허용되는 씬 교체 API는 `SceneTree.change_scene_to_packed(packed: PackedScene)` 이다. `change_scene_to_file()`, `ResourceLoader.load_threaded_request()` 및 기타 비동기 로드 패턴은 Tier 1에서 **금지**된다. 콜라주 텍스처 메모리(1.5 GB 상한)에 대한 명시적 `ResourceLoader.load` 해제 또한 Tier 2 게이트로 이월된다.
*Rationale*: Pillar 5 (작은 성공) + Anti-Pillar #2 (5+ 스테이지 영구 배제) — Tier 1 = 1 stage 슬라이스 + 체크포인트 재시작만; 다중 씬 + 비동기 로드 + 텍스처 명시 해제는 Tier 2(3 stages) 진입 게이트로 본 GDD를 개정해 추가한다.

---

**[`scene_will_change` 시그널 — 단일 생산자 + 타이밍]**

**Rule 4.** `SceneManager`는 `scene_will_change()` 시그널의 **유일한 생산자**다. 이 시그널은 `change_scene_to_packed()` 호출 **이전**, 동일한 물리 틱 내에서 동기적으로 emit되어야 한다. 어떤 다른 노드도 `scene_will_change`를 emit해서는 안 된다.
*Rationale*: Pillar 2 결정론 + TR E-16 invalid-coord 텔레포트 방지 — 구독자(TRC `_buffer_invalidate()`, EchoLifecycleSM O6 cascade)는 아직 살아있는 씬 노드에 대한 유효한 참조가 필요. 언로드 시작 *후* emit은 부분적으로 해제된 트리에 대해 구독자가 경쟁하게 만든다.
*Resolves*: **OQ-4 (TR #9)** — emit 타이밍은 "트리거 진입 시 (`change_scene_to_packed` 호출 직전, 동일 틱)". "언로드 시작 후" 대안 거부.

---

**[`scene_will_change` 구독자 — PM 직접 구독 금지]**

**Rule 5.** `scene_will_change` 시그널을 구독하는 것이 허용된 시스템은 **TRC와 EchoLifecycleSM 두 가지**다. `PlayerMovement`는 `scene_will_change`를 직접 구독해서는 **안 된다**; PM의 8-var ephemeral state(player-movement.md F.4.2 row #2: 4 coyote/buffer + 4 facing Schmitt flag)는 EchoLifecycleSM의 O6 cascade를 통해서만 클리어된다.
*Rationale*: ADR-0001 + single-layer cascade design — PM은 ephemeral 클리어의 *내용*만 소유하고 *타이밍*은 EchoLifecycleSM에 위임. 직접 구독 시 PM이 씬 경계 타이밍에 대한 암묵적 지식을 갖게 되어 cross-cutting concern 누출.
*Resolves*: **OQ-PM-1 (PM #6)** — SM emit → EchoLifecycleSM `_on_scene_will_change()` → PM `_clear_ephemeral_state()` cascade.

---

**[Ring Buffer 접촉 금지]**

**Rule 6.** `SceneManager`는 TRC의 ring buffer(`_write_head`, `_buffer_primed`, `PlayerSnapshot` 슬롯)에 직접 접근하거나 수정해서는 **안 된다**. SM은 `scene_will_change()`만 emit하며, TRC가 자체 `_buffer_invalidate()` 핸들러에서 버퍼를 무효화하는 책임을 진다.
*Rationale*: ADR-0002 + `forbidden_patterns.direct_player_state_write_during_rewind` (architecture.yaml) — TRC가 ring buffer의 단일 소유자.

---

**[토큰 보존 불변성]**

**Rule 7.** `scene_will_change` emit 시 TRC의 `_tokens` 카운트는 **보존**된다. SM은 토큰 값을 읽거나 쓰거나 리셋해서는 **안 된다**. `_buffer_primed`와 `_write_head`만 TRC의 `_buffer_invalidate()`에 의해 리셋된다 (time-rewind.md F.1 row #2 + E-16).
*Rationale*: 토큰 경제는 메타 진행으로 씬 경계를 초월; ring buffer 좌표만 씬-로컬.

---

**[체크포인트 앵커 등록 — 결정론적 단일 출처]**

**Rule 8.** `SceneManager`는 씬 내 `checkpoint_anchor` 그룹으로 태깅된 노드의 `global_position`을 등록하는 **유일한 출처**다. 체크포인트 앵커 등록은 씬의 `_ready()` 체인이 완료된 후(다음 `_physics_process` 직전) 실행되어야 한다. 두 개 이상의 앵커가 한 씬에 존재하면 가장 최근에 등록된 앵커를 사용하고 `push_warning("Multiple checkpoint anchors in scene — using last")`을 남긴다.
*Rationale*: Pillar 2 결정론(boot-time RNG 금지) + Pillar 1 보조(앵커가 결정론적이지 않으면 < 1초 재시작이 무의미).

---

**[< 1초 재시작 — 비협상 타이밍 상한]**

**Rule 9.** 체크포인트 재시작 흐름(DEAD 진입 → `change_scene_to_packed` 완료 → EchoLifecycleSM ALIVE 진입)은 **60 물리 틱(60 Hz @ 1.000 s) 이내**에 완료되어야 한다. 이 예산은 **비협상**이다. SM의 `change_scene_to_packed` 호출은 동기 호출이어야 하며 코루틴이나 `call_deferred()`로 래핑해서는 안 된다.
*Rationale*: Pillar 1 비협상 — "1초 이내 재시작 절대 양보 X" (game-concept.md Pillar 1 Design test).
*Quality flag*: 60-tick 예산은 *계약*이지만 Godot 4.6에서 단일 `change_scene_to_packed` 호출이 소비하는 실제 틱 수는 씬 크기·텍스처 로드 등에 따라 다름 — Section H AC가 헤드리스 smoke check + Steam Deck 1세대 실측을 요구해야 함.

---

**[EchoLifecycleSM 부트 소유권 — 씬 트리 자연 부트]**

**Rule 10.** 새 씬 로드 후 `EchoLifecycleSM`의 ALIVE 강제 전이는 SM의 직접 `boot()` 호출이 아니라, Godot 씬 트리의 자연 `_ready()` 체인을 통해 `EchoLifecycleSM._ready()`가 **자체 부트**하는 방식으로 이루어진다. `SceneManager`는 `EchoLifecycleSM.boot()`를 직접 호출해서는 **안 된다**.
*Rationale*: ADR-0003 + state-machine.md C.2.1 — `EchoLifecycleSM._ready()` override가 `super._ready()` 호출 없이 시그널 connect + `boot()` 직접 수행으로 락인됨. SM이 직접 호출 시 이중 부트 위험 + 솔로 디버깅 복잡도 상승.
*Resolves*: **OQ-SM-2 (SM #5)** — EchoLifecycleSM이 자체 `_ready()`에서 부트; SM 추가 와이어링 불필요.

---

**[비-플레이어 상태 리셋 소유권 — 씬 교체 자체가 리셋]**

**Rule 11.** 체크포인트 재시작 시 적, 발사체, 환경 오브젝트의 상태 리셋은 `SceneManager`가 소유하지만 **개별 노드를 직접 리셋하지 않는다** — `change_scene_to_packed()`로 씬을 교체하면 적/발사체/환경은 씬 교체 자체에 의해 리셋된다. SM은 개별 노드에 대해 직접 상태 리셋 함수를 호출해서는 안 된다.
*Rationale*: ADR-0001 (Player-only rewind scope — TRC는 플레이어만 복원) + Tier 1 단일 씬 슬라이스 가정.
*Tier 2 revision warning*: "씬 교체가 리셋을 처리한다"는 Tier 1 가정. Tier 2의 "씬 교체 없는 인플레이스 체크포인트" 패턴(메모리 효율) 도입 시 본 규칙은 *명시적 그룹별 리셋 cascade*로 개정 필요.

---

**[`boss_killed` 구독 — 스테이지 클리어 단일 트리거]**

**Rule 12.** `SceneManager`는 `boss_killed(boss_id: StringName)` 시그널을 구독하여 스테이지 클리어 씬 전환을 트리거한다. 이 구독은 SM의 **유일한** Damage 시그널 구독이다. 스테이지 클리어 흐름의 세부 wiring(다음 씬 결정, 타이밍, 페이드)은 C.3에서 정의한다.
*Rationale*: damage.md F.4 9-signal contract single-source (AC-13 BLOCKING) — `boss_killed`는 최종 페이즈 마지막 hit에서 emit되는 단일 시그널. damage.md F.4 row 명시: `boss_killed → #2 Scene Manager (스테이지 클리어 트리거)`.
*Cross-doc drift flag*: `time-rewind.md` (Rules 15/16, E-05/06, AC-B2/B3/B5, F.1 row #11, F.4.1) + `state-machine.md` (B.2, C.2.2 O5, F.3 row, line 499)은 **stale `boss_defeated`** 참조를 보유 — damage.md Round 4 LOCK 이전의 carry-over로 추정. **Post-C.1 housekeeping batch 권장**: `boss_defeated` → `boss_killed` 일괄 교체 (time-rewind.md 13 sites + state-machine.md 4 sites = **17 simple replacements**, 비파괴적 단순 치환 — `grep -c boss_defeated` HEAD 실측 2026-05-11).

---

**[Cold Boot 5분 룰 — Press-any-key 금지]**

**Rule 13.** SM은 cold boot(게임 최초 실행)에서 첫 actionable input까지의 시간이 **300 s(5분)를 초과하지 않도록** 씬 로드 흐름을 설계해야 한다. **Press-any-key 게이트는 금지**된다; 첫 번째 입력 이벤트가 인트로 화면에서 자연스럽게 게임 시작을 트리거한다(input.md C.5 owner).
*Rationale*: Pillar 4 5분 룰 + Anti-Pillar #6 (인풋 리매핑·다국어 풀 옵션 제외 → 초기 옵션 메뉴 게이트 제거 가능).

---

**[No-op 보호 — 동일 씬 재로드 가드]**

**Rule 14.** `SceneManager.change_scene_to_packed()`를 호출하기 직전에 인자가 현재 로드된 씬과 동일한 `PackedScene` 참조이면서 의도가 "체크포인트 재시작이 아닌 단순 재전이"이면 early-return + `push_warning()`. 동일 씬 재로드가 *체크포인트 재시작의 일부*인 경우는 유효 — 동일성 검사는 `PackedScene` 참조 + `intent: TransitionIntent` 인자(C.2.3 enum)로 판단한다 (`intent == TransitionIntent.CHECKPOINT_RESTART` 만 통과; `TransitionIntent.STAGE_CLEAR` / `COLD_BOOT`은 의도가 "체크포인트 재시작 아님"으로 분류되어 early-return 대상).
*Rationale*: 방어적 — 코드 버그(중복 전이 호출)로 인한 의도치 않은 재시작 흐름 차단; 체크포인트 재시작은 명시적 intent flag로 통과.

---

**OQ 해결 요약 (Rules 4 / 5 / 10에서 인코딩)**

| OQ | 출처 | 해결 (인코딩 Rule) |
|---|---|---|
| **OQ-4** | TR #9 OQ list | `scene_will_change` emit 타이밍 = `change_scene_to_packed` 호출 직전, 동일 물리 틱 동기 emit (Rule 4) |
| **OQ-PM-1** | PM #6 OQ list | PM은 직접 구독하지 않음; EchoLifecycleSM O6 cascade로 PM 8-var 클리어 (Rule 5) |
| **OQ-SM-2** | SM #5 OQ list | EchoLifecycleSM이 자체 `_ready()`에서 부트; SceneManager는 `boot()` 직접 호출 금지 (Rule 10) |

**Cross-doc drift 발견 (Post-C.1 housekeeping batch 권장)**

| Drift | 영향 GDD | 사이트 추정 | 권장 |
|---|---|---|---|
| `boss_defeated` → `boss_killed` 통일 | time-rewind.md + state-machine.md | TR 13 + SM 4 = **17 simple replacements** (HEAD `grep -c` 실측 2026-05-11) | damage.md F.4 (LOCKED + AC-13 BLOCKING)이 single-source 권위. 본 GDD는 `boss_killed` 사용. 따로 응용 GDD 두 곳 일괄 치환 배치 (Session 19 후속 또는 Session 20 housekeeping) |

**Tier 2 revision 트리거 (사전 등록)**

| Rule | Tier 2 트리거 조건 | 개정 필요 부분 |
|---|---|---|
| Rule 3 | 다중 스테이지(≥ 2 stages) 도입 | 비동기 로드(`load_threaded_request`) + 콜라주 텍스처 명시적 해제 허용 |
| Rule 11 | 인플레이스 체크포인트(씬 교체 없이 적/발사체 리셋) | 그룹별 리셋 cascade 명시 |

### C.2 States and Transitions

Scene Manager는 두 개의 state machine을 보유한다: (a) **transition lifecycle phase machine**(C.2.1) — 모든 씬 전환이 통과하는 선형 5-phase 파이프라인 / (b) **stage boundary state diagram**(C.2.2) — Tier 1 단일 스테이지 경계 상태(BOOT_INTRO / ACTIVE / RESTART_PENDING / CLEAR_PENDING). 후자가 전자를 트리거한다.

#### C.2.1 Transition Lifecycle Phase Machine (linear 5-phase)

| Phase | Tick 예산 | 진입 트리거 | Body |
|---|---|---|---|
| **IDLE** | steady-state | (default) | 단일 씬 로드 완료, 전환 트리거 대기. 작업 없음. |
| **PRE-EMIT** | 틱 T (SWAPPING과 **co-tick**) | DEAD enter / `boss_killed` / cold-boot 첫 입력 | (a) `scene_will_change()` emit (Rule 4); (b) 동일 틱 내 핸들러 완료 대기 (TRC `_buffer_invalidate()`, EchoLifecycleSM `_on_scene_will_change()` cascade); (c) 동일 틱 T 내 SWAPPING으로 진행 |
| **SWAPPING** | M 틱 (Godot SceneTree 내부 — Section H AC 검증) | PRE-EMIT 완료 (동일 틱 T) | `SceneTree.change_scene_to_packed(packed)` 동기 호출. SM은 호출 내부의 per-tick 진행 관측 불가. |
| **POST-LOAD** | `K` 틱 (design guidance: `K < M`; D.1 binding constraint는 sum) | `change_scene_to_packed` 반환 | 새 씬 `_ready()` 체인 실행; SM이 `get_tree().process_frame.connect(_on_post_load, CONNECT_ONE_SHOT)` 패턴으로 다음 프레임 콜백을 1회 등록하여 `_ready()` cascade 완료 시점을 결정론적으로 포착 (코루틴 미사용 — Rule 9 비협상 준수; 시그널-콜백 기반); 콜백 본문이 (1) `checkpoint_anchor` 등록 (Rule 8); (2) **stage root에서 `stage_camera_limits: Rect2` query 후 boot-time assert `assert(limits.size.x > 0 and limits.size.y > 0)` (E-CAM-7 — invalid Rect2가 Camera2D `limit_*` setter를 무의미한 값으로 설정해 player가 visible world 밖으로 escape하는 시나리오 차단)**; (3) **`scene_post_loaded(anchor: Vector2, limits: Rect2)` 시그널 emit** (Camera #3 first-use 적용 2026-05-12 — Q2 closure; camera.md R-C1-10 + R-C1-12 핸들러 호출); (4) READY phase 전이. |
| **READY** | steady-state | EchoLifecycleSM이 `state_changed(_, &"alive")` emit | 입력 수락; SM IDLE-effective 복귀. |

**Budget formula** (Rule 9 비협상 계약):

```
SWAPPING(M ticks) + POST-LOAD(K ticks) + 1(READY 확인) ≤ 60 ticks (= 1.000 s @ 60 Hz)
   where K < M is design guidance; D.1 binding constraint is the sum.
```

PRE-EMIT은 SWAPPING의 첫 틱과 **co-tick**(Rule 4: `scene_will_change()` emit + `change_scene_to_packed()` 호출이 같은 물리 틱 T에서 발생) — 따라서 PRE-EMIT은 예산에 가산되지 **않는다**. M과 K의 실측 값은 Godot 4.6에서 미검증; Section H AC가 헤드리스 smoke check + Steam Deck 1세대 실측 의무를 보유한다.

**Linear, no branching**: 5 phases는 단일 forward chain을 형성한다. 어떤 트리거든(체크포인트 재시작 vs 스테이지 클리어 vs cold-boot) 동일한 PRE-EMIT → SWAPPING → POST-LOAD → READY 파이프라인을 통과한다. 트리거 간 차이는 *어떤 PackedScene이 로드되는지*에 있고, *어떻게 lifecycle이 진행되는지*에는 없다.

**Failure path**: PackedScene이 null이거나 OOM 발생 시 SM은 본 lifecycle을 벗어나 panic state로 라우팅된다 — 세부 처리는 Section E.1에서 정의.

#### C.2.2 Stage / Encounter Boundary State Diagram (Tier 1 minimal)

Tier 1 = 단일 스테이지 슬라이스. SM은 **씬 경계만** 소유하며, 스테이지 내부 encounter flow는 Stage / Encounter System #12(Not Started)가 소유한다.

| Boundary 상태 | 소유자 | 진입 트리거 | 다음 동작 |
|---|---|---|---|
| **BOOT_INTRO** | SM | cold boot 완료 | 첫 입력 도착 → PRE-EMIT 진입 (C.2.1) |
| **ACTIVE** | Stage #12 (Tier 1 deferred) | new scene `_ready()` 완료 + EchoLifecycleSM ALIVE 진입 | Stage #12이 encounter trigger 관장; SM은 다음 boundary 트리거 대기 |
| **RESTART_PENDING** | SM | EchoLifecycleSM DYING → DEAD 전이 | PRE-EMIT 진입 (C.2.1 — 동일 PackedScene 재로드) |
| **CLEAR_PENDING** | SM | `boss_killed` 수신 (Rule 12) | PRE-EMIT 진입 (C.2.1 — Tier 1에서는 단일 스테이지 = "victory screen" PackedScene 또는 동일 스테이지 재로드; Tier 2 진입 시 다음 스테이지 PackedScene으로 개정) |

본 4개 boundary 상태는 C.2.1 lifecycle을 트리거하는 *진입 슬롯*이다 — C.2.1 phase machine 내부에는 branching이 없다.

#### C.2.3 Implementation Pattern — Enum + match

내부 phase machine은 GDScript `enum Phase` + `match` 문으로 구현하며 **state-machine.md `State`/`StateMachine` 프레임워크는 사용하지 않는다**. 사유: (1) 단일 인스턴스(autoload), (2) 5-phase 선형 — 동시 리액션 없음, (3) signal-emit 외부 통지로 모든 외부 노드가 동기화 — `state_changed(from, to)` 같은 일반화된 시그널 불필요.

```gdscript
enum Phase { IDLE, PRE_EMIT, SWAPPING, POST_LOAD, READY }
enum TransitionIntent { COLD_BOOT, CHECKPOINT_RESTART, STAGE_CLEAR }
enum BoundaryState { BOOT_INTRO, ACTIVE, RESTART_PENDING, CLEAR_PENDING, PANIC }  # D.5 variable table 5-value enum

var _phase: Phase = Phase.IDLE
var _boundary_state: BoundaryState = BoundaryState.BOOT_INTRO  # C.2.2 cold-boot initial slot
var _respawn_position: Vector2 = Vector2.ZERO                  # D.3 selection result; AC-H3b/AC-H10
var current_scene_packed: PackedScene = null                   # Rule 14 same-PackedScene guard tracking (no `_` prefix — matches walkthroughs C.3.2/C.3.3 + AC-H18; RR6 rename)

@export var stage_1_packed: PackedScene        # G.2 designer-tunable (default `preload("res://scenes/stage_1.tscn")`). `@export` field — `_` prefix convention reserved for private vars; inspector-public field uses bare name (RR6 rename matching G.2 / walkthroughs)
@export var victory_screen_packed: PackedScene # G.2 designer-tunable (default `preload("res://scenes/victory_screen.tscn")`). `@export` field — bare name per inspector-public convention (RR6 rename)
```

상태 진입/이탈은 `_trigger_transition(packed: PackedScene, intent: TransitionIntent)` 함수의 동기적 단계 진행으로 처리된다 (코루틴 금지 — Rule 9 비협상). state-machine.md 프레임워크는 ECHO / 적 / 보스의 멀티-엔티티 동시 리액티브 머신을 타깃하며, SceneManager는 단일 인스턴스 선형 lifecycle이므로 프레임워크 오버헤드를 정당화하지 못한다.

**API 단일 출처 정책**: 외부 호출자(input.md C.5 cold-boot 라우터, 기타 future systems)는 `SceneManager.change_scene_to_packed(packed: PackedScene, intent: TransitionIntent)` 단일 진입점만 사용한다 — bool flag API는 채택하지 않는다 (cold-boot vs stage-clear vs checkpoint-restart 3-state 구분이 bool로 불가능). 내부 핸들러(`_on_boss_killed`, `_on_state_changed`)는 `_trigger_transition()`을 직접 호출하며 두 경로 모두 동일한 `TransitionIntent` enum을 사용한다. Rule 14 no-op 가드는 외부 API 진입점(`SceneManager.change_scene_to_packed`)에 적용되며, 내부 `_trigger_transition`은 Rule 14의 보호 대상이 아니다 (내부 핸들러는 D.5 boundary state 평가로 의도가 보장됨).

#### C.2.4 Ownership Boundary Note

- **SM이 소유**: 씬 경계, transition lifecycle (5 phases), `scene_will_change` emit, checkpoint anchor 등록, `boss_killed` 구독, 4-state boundary diagram (BOOT_INTRO / ACTIVE / RESTART_PENDING / CLEAR_PENDING).
- **SM이 소유하지 않음**: 스테이지 내 encounter flow (Stage #12), 적 스폰 (Stage #12), 보스 phase advance (damage.md D.2.1), 토큰 economy (TR #9 — Rule 7 보존 의무만), HUD 갱신 (HUD #13 — TR/Damage 시그널 직접 구독).

**Tier 1 boundary state evolution (RR6 surfaced)**: C.2.2 says `ACTIVE` 진입은 Stage #12이 소유 (Tier 1 deferred). 결과적으로 **Tier 1 production에서 `_boundary_state`는 ACTIVE에 도달하지 않는다** — 진화 경로는 BOOT_INTRO → (cold-boot transition close 후 BOOT_INTRO 유지) → RESTART_PENDING (첫 DEAD 후 영구) → CLEAR_PENDING (boss_killed 후). `_on_state_changed(_, &"alive")` 핸들러는 `_phase = READY`만 설정하고 `_boundary_state`는 그대로 둔다 (C.3.3 pattern). 이는 contract bug가 아니라 *incomplete state machine* — Stage #12 도입 시 ACTIVE 슬롯 owner가 채워지며 진화 경로가 BOOT_INTRO → ACTIVE → RESTART_PENDING/CLEAR_PENDING → ACTIVE로 정상화된다. Tier 1 AC들 (특히 AC-H18)은 핸들러의 state-agnostic 성질에 의존하여 mock으로 ACTIVE 상태를 생성하지 않고도 contract를 검증한다 — AC-H11과 AC-H18 모두 Given을 "SM is IDLE" 로만 요구한다.

### C.3 Interactions with Other Systems

#### C.3.1 SM 시그널 emit / subscribe matrix

**SM emits (2 signals — sole producer for both)**:

| Signal | Signature | Subscribers | Emit guard |
|---|---|---|---|
| `scene_will_change` | `()` (zero args) | TRC (`_buffer_invalidate()`) · EchoLifecycleSM (`_on_scene_will_change()` cascade — `_lethal_hit_latched` + 입력 버퍼 + O8 counter + PM 8-var via PM `_clear_ephemeral_state()` 호출) | Single-emit per transition (Rule 4); SM은 sole producer (Rule 4) |
| `scene_post_loaded` | `(anchor: Vector2, limits: Rect2)` | Camera #3 (`_on_scene_post_loaded` → snap-to-anchor + stage limit set + `reset_smoothing()`; camera.md R-C1-10 + R-C1-12) | POST-LOAD phase 안에서 `checkpoint_anchor` 등록 직후 + boot-time assert `limits.size > 0` (E-CAM-7) 통과 후 single-emit. Camera #3 first-use 2026-05-12 (Q2 closure — DEC-SM-9 status flip). Tier 2 진입 시 Stage #12 / HUD #13 추가 구독 가능. |

**SM subscribes (3 signals)**:

| Subscribed signal | Signature | Source | SM handler behavior |
|---|---|---|---|
| `boss_killed` | `(boss_id: StringName)` | damage.md F.4 (boss host emits at final phase last hit per damage.md D.2.1) | SM → boundary CLEAR_PENDING → C.2.1 PRE-EMIT 진입. boss_id는 향후 분석용 로깅, Tier 1에서는 미분기. |
| `state_changed(_, &"alive")` | from EchoLifecycleSM | state-machine.md C.2.1 framework | SM이 POST-LOAD → READY phase 전이 (lifecycle close) |
| `state_changed(_, &"dead")` | from EchoLifecycleSM | state-machine.md C.2.2 (DYING → DEAD 전이) | SM → boundary RESTART_PENDING → C.2.1 PRE-EMIT 진입 (단, C.3.3 동일-틱 우선순위 정책 우선) |

HUD #13, Audio #4, VFX #14, Camera #3은 SM의 시그널을 **직접 구독하지 않는다** — 각자 TR / Damage / EchoLifecycleSM의 시그널을 독립 구독한다 (의무 분리; SM은 씬 경계 owner이지 presentation 분배 hub가 아님).

#### C.3.2 Checkpoint Restart Wiring (DEAD → ALIVE in ≤ 60 ticks)

End-to-end tick-by-tick 표 (Rule 9 비협상 계약 검증):

| Tick | Owner | Action |
|---|---|---|
| T−1 | EchoLifecycleSM | DYING grace 만료 (12 frames, damage.md DEC-6) → DEAD enter (state-machine.md C.2.2) |
| T+0 | SM (`_on_state_changed`) | DEAD 감지 → boundary RESTART_PENDING → PRE-EMIT phase 진입 |
| T+0 | SM | emit `scene_will_change()` (Rule 4 — sole producer) |
| T+0 | TRC (`_on_scene_will_change`) | `_buffer_invalidate()`: `_buffer_primed = false`, `_write_head = 0`, `_tokens` **보존** (Rule 7 / TR E-16) |
| T+0 | EchoLifecycleSM (`_on_scene_will_change`) | O6 cascade: clear `_lethal_hit_latched`, 입력 버퍼, O8 counter; PM `_clear_ephemeral_state()` 호출 → PM 8-var (4 coyote/buffer + 4 facing Schmitt) reset (Rule 5; player-movement.md F.4.2 row #2) |
| T+0 | SM | `change_scene_to_packed(current_scene_packed)` 동기 호출 (Rule 4 co-tick) → SWAPPING phase |
| T+1 .. T+M | SceneTree (engine 내부) | 씬 unload + load — M ticks (Godot 4.6에서 unverified — Section H AC 실측) |
| T+M+1 .. T+M+K | new scene `_ready()` chain | EchoLifecycleSM 자체 `_ready()` 부트 (Rule 10) → 초기 상태 진입 + (다음 틱에) ALIVE state_changed emit |
| T+M+K | SM | `process_frame` one-shot 콜백 발화(T+M+K-1에서 `change_scene_to_packed` 반환 직후 `connect(..., CONNECT_ONE_SHOT)` 등록) → POST-LOAD phase 진입 → `checkpoint_anchor` 등록 (Rule 8) |
| T+M+K+1 | SM (`_on_state_changed`) | `state_changed(_, &"alive")` 수신 → READY phase 전이 (lifecycle close) |

**Budget check**: `M + K + 1 ≤ 60 ticks` (T+0 동일 틱 작업은 PRE-EMIT 단일 phase로 묶임, 가산 없음). M과 K의 실측은 Section H AC가 헤드리스 smoke check + Steam Deck 1세대 측정으로 검증.

**Same-PackedScene reload semantics** (Rule 14 보호): 체크포인트 재시작은 동일 PackedScene을 재로드하므로 Rule 14 no-op 가드가 `intent == TransitionIntent.CHECKPOINT_RESTART`로 통과시킨다 (C.2.3 enum). `TransitionIntent.STAGE_CLEAR` 또는 `COLD_BOOT` 시 동일 PackedScene 참조면 early-return + `push_warning()` — 정상 호출 경로에서는 발생하지 않는다 (cold-boot은 `stage_1_packed`, stage-clear는 `victory_screen_packed`로 서로 다른 참조).

#### C.3.3 Stage Clear Wiring (`boss_killed` → 스테이지 클리어)

End-to-end tick-by-tick 표:

| Tick | Owner | Action |
|---|---|---|
| T−1 | Damage system | 보스 최종 페이즈 마지막 hit → boss host의 D.2.1 분기: `remaining' == 0 ∧ phase_index == final` → `_phase_advanced_this_frame = true` set → emit `boss_killed(boss_id)` (damage.md AC-13) → `queue_free()` 예약 |
| T+0 | SM (`_on_boss_killed`) | boundary CLEAR_PENDING → PRE-EMIT phase 진입 |
| T+0 | SM | emit `scene_will_change()` (Rule 4) |
| T+0 | TRC + EchoLifecycleSM | (C.3.2와 동일 cascade — `_buffer_invalidate()` + O6 cascade; `_tokens` 보존; boss_killed 시 +1 토큰 grant는 TRC가 별도 처리 per TR Rule 15) |
| T+0 | SM | `change_scene_to_packed(victory_screen_packed)` — **Tier 1**: 단일 "victory screen" PackedScene; **Tier 2 진입 시**: 다음 스테이지 PackedScene으로 본 GDD 개정 |
| T+1 .. T+M+K+1 | (C.3.2와 동일 SWAPPING / POST-LOAD / READY 흐름) | (동일 lifecycle) |

**동일-틱 `boss_killed` + `state_changed(_, &"dead")` 우선순위 정책** (TR I2 / E-06 reciprocal):

같은 물리 틱에 두 시그널(`boss_killed` from Damage host + `state_changed(_, &"dead")` from EchoLifecycleSM)이 모두 SM 핸들러 큐에 도착할 수 있다. ADR-0003 process priority ladder는 PlayerMovement(0) / TRC(1) / Damage(2) / enemies(10) / projectiles(20)을 명시하지만 **EchoLifecycleSM의 슬롯은 ladder에 등록되어 있지 않다** — 따라서 두 시그널의 SM 도착 순서는 **undefined**로 간주한다. 본 정책은 도착 순서에 무관하게 동일 결과(CLEAR_PENDING 승)를 보장하도록 C.3.3 GDScript 패턴의 `_boundary_state == CLEAR_PENDING` early-return 가드로 구현된다:

| 동시 도착 시나리오 | SM 정책 |
|---|---|
| `boss_killed`와 `state_changed(_, &"dead")` 같은 틱 도착 | **CLEAR_PENDING이 RESTART_PENDING을 *우선*한다** — SM은 boss_killed 핸들러를 먼저 평가하고 boundary state를 CLEAR_PENDING으로 락 후, 같은 틱의 `state_changed(_, &"dead")` 핸들러는 boundary state == CLEAR_PENDING 시 **early-return** (boundary state 변경 없음, lifecycle 진행 변경 없음) |

**사유**: 보스 격파 후 사망은 stage end 의미가 우선 — 재시작이 아니라 클리어 화면으로 진행하는 것이 플레이어 멘탈 모델에 맞다 (Pillar 1 — 시간 되감기 *학습 도구* 모델은 stage 진행 흐름을 흔들지 않음). 본 정책은 SM이 단일 출처로 보유하며, EchoLifecycleSM이나 Damage 측에서는 우선순위 처리를 하지 않는다.

**구현 패턴**:

```gdscript
func _on_boss_killed(boss_id: StringName) -> void:
    _boundary_state = BoundaryState.CLEAR_PENDING
    _trigger_transition(victory_screen_packed, TransitionIntent.STAGE_CLEAR)

func _on_state_changed(from: StringName, to: StringName) -> void:
    if to == &"dead" and _boundary_state == BoundaryState.CLEAR_PENDING:
        return  # CLEAR_PENDING wins; ignore RESTART_PENDING request same tick
    if to == &"alive":
        _phase = Phase.READY
        return
    if to == &"dead":
        _boundary_state = BoundaryState.RESTART_PENDING
        _trigger_transition(current_scene_packed, TransitionIntent.CHECKPOINT_RESTART)
```

> **Pattern scope note**: 위 snippet은 same-tick CLEAR vs RESTART 우선순위 로직만 보여준다 — 본 GDD가 spec하는 다른 진입 가드는 별도로 production 핸들러에 포함되어야 한다: (a) **panic-state 가드** `if _boundary_state == BoundaryState.PANIC: return` (E.1 terminality + AC-H26); (b) **`_phase != Phase.IDLE` 가드** `if _phase != Phase.IDLE: push_warning(...); return` (E.4 `boss_killed` during transition + E.5 `dead` during transition + AC-H19/AC-H20). 두 핸들러 모두 함수 본문 *최상단*에 두 가드를 배치한다 (precedence: panic > phase ≠ idle > 동일-틱 우선순위).

#### C.3.4 Q2 Resolved — POST-LOAD 시그널 노출 (Camera #3 first-use 적용 2026-05-12)

C.2.1 POST-LOAD phase는 **`scene_post_loaded(anchor: Vector2, limits: Rect2)` 시그널을 emit한다** — Camera #3 first-use trigger (camera.md C.3.3 batch + F.1 row #1 HARD dependency 정합). 본 시그널은 `checkpoint_anchor` 등록 직후 + boot-time assert `limits.size.x > 0 ∧ limits.size.y > 0` (E-CAM-7) 통과 후 single-emit한다. 시그너처는 architecture.yaml `interfaces.scene_lifecycle.signal_signature`가 단일 출처이며 본 GDD는 그 reference를 보유한다.

| 시스템 | hook 필요성 | 트리거 조건 | 시그널 / Status |
|---|---|---|---|
| **Camera #3** | new scene 진입 시 camera snap-to-anchor (체크포인트 재시작에서 컷 없이 즉시 정렬) + stage limit 설정 | POST-LOAD entry → checkpoint_anchor `global_position` + stage `Rect2` 노출 | `scene_post_loaded(anchor: Vector2, limits: Rect2)` — **Active 2026-05-12 (Camera #3 Approved RR1 PASS first-use)** |
| Stage / Encounter #12 | encounter trigger node wiring 시점 | POST-LOAD에서 anchor 등록 직후 (동일 시그널) | 동일 시그널 재사용 (signature 비변경) — Stage #12 GDD 작성 시 구독 추가 |
| HUD #13 (Tier 2) | victory screen 전환 시 HUD fade-out timing | POST-LOAD에서 시그널 노출 또는 `state_changed(_, &"dead")` 직접 구독으로 대체 가능 | 미정 (Tier 2 HUD GDD 결정) |

**Tier 1 status (2026-05-12)**: POST-LOAD 시그널 노출 **Active** — Camera #3가 first-use 트리거. signal signature `scene_post_loaded(anchor: Vector2, limits: Rect2)`는 Camera #3 GDD authoring 시점에 Camera 측 R-C1-10 / R-C1-12 + AC-CAM-H5-01/02 의무를 만족하도록 2-arg (`anchor` + `limits`)로 결정됨 (`limits: Rect2`는 stage-by-stage 변동성 흡수 + Tier 2 멀티룸 진입 시 동일 시그널 재사용). 본 closure는 F.4.2 (후속 GDD 작성 시 의무)에서 Camera #3 row 의무 status를 "Active"로 flip하며, OQ-SM-A1 + DEC-SM-9 모두 resolved 처리.

#### C.3.5 Cross-doc Reciprocal Obligations (Phase 5d 일괄 적용)

본 GDD가 새로 추가하거나 변경한 시그널 contract는 다음 GDD에 반영되어야 한다 — Phase 5d Update Systems Index 시 일괄 적용:

| 영향 GDD | 변경 내용 | 변경 위치 |
|---|---|---|
| `time-rewind.md` | F.1 row #2 (Scene Manager) *(provisional)* → confirmed; signal signature `scene_will_change()` 락인 (0 args); `_buffer_invalidate()` 핸들러 owner 명시 (TRC self) | F.1 row #2 |
| `time-rewind.md` | OQ-4 → resolved (emit 타이밍 = `change_scene_to_packed` 호출 직전 동일 틱) | Section Z OQ table |
| `state-machine.md` | C.2.2 O6 — Scene Manager provisional contract → confirmed; signal `scene_will_change()` (0 args) 락인 | C.2.2 row O6 |
| `state-machine.md` | F.3 row #2 (Scene / Stage Manager — `scene_will_change()` 구독자) — provisional → confirmed | F.3 row #2 |
| `state-machine.md` | OQ-SM-2 → resolved (SM이 `EchoLifecycleSM.boot()` 호출하지 않음; 씬 트리 자연 부트 per state-machine.md C.2.1 lock-in) | Section Z OQ table |
| `player-movement.md` | F.4.2 row #2 (Scene Manager) — OQ-PM-1 closure: PM은 `scene_will_change` 직접 구독 안 함; EchoLifecycleSM cascade를 통한 `_clear_ephemeral_state()` 호출이 단일 경로 | F.4.2 row #2 |
| `docs/registry/architecture.yaml` | 새 항목 4종: `interfaces.scene_lifecycle` (signal `scene_will_change()` producer=scene-manager, consumers=[trc, echo-lifecycle-sm]); `state_ownership.scene_phase` (owner=scene-manager autoload); `api_decisions.scene_manager_group_name = "scene_manager"`; `api_decisions.checkpoint_anchor_group_name = "checkpoint_anchor"` | new entries |
| `design/registry/entities.yaml` | 새 constants 2종: `restart_window_max_frames = 60` (= 1.000 s @ 60 Hz Pillar 1 비협상 — Rule 9 contract); `cold_boot_max_seconds = 300` (Pillar 4 5분 룰 — Rule 13 contract) | constants section |
| `design/gdd/systems-index.md` | Row #2 Scene / Stage Manager: Status Not Started → Designed (or Approved post-review); Design Doc 링크 추가 + Depends On 비어있는 칸에 의존성 추가 (None — Foundation) | Row #2 |

**Cross-doc drift housekeeping** (C.1 Rule 12 discovery): `boss_defeated` → `boss_killed` 일괄 치환 — time-rewind.md 13 sites (Rules 15/16, E-05/06, AC-B2/B3/B5, F.1 row #11, F.4.1) + state-machine.md 4 sites (B.2, C.2.2 O5, F.3 row #11, line 499) = **17 simple replacements** (HEAD `grep -c` 실측 2026-05-11). damage.md F.4 LOCKED + AC-13 BLOCKING이 single-source 권위. **Phase 5d 외 별도 housekeeping 배치 권장** (17 단순 치환, 비파괴적; Session 19 후속 commit 또는 Session 20).

## D. Formulas

Scene Manager는 Foundation 시스템이므로 balance curve나 damage formula를 보유하지 않는다. 본 섹션의 6개 공식은 모두 **budget invariant 및 selection rule**이며, Pillar 1/2/4 비협상 계약을 falsifiable 형태로 인코딩한다.

---

### D.1 Restart Lifecycle Budget Invariant

**Serves**: Pillar 1 비협상 · Rule 9 · C.2.1 SWAPPING+POST-LOAD budget

**Named expression**:

```
M + K + 1 ≤ 60   (ticks @ 60 Hz = 1.000 s)
```

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| M | int | 1–59 | SWAPPING phase ticks: `change_scene_to_packed()` 호출부터 반환까지. Godot 4.6 engine-internal — design time unverified; Section H AC가 측정 의무 보유. |
| K | int | 0–58 | POST-LOAD phase ticks: new scene `_ready()` chain 완료 + `checkpoint_anchor` 등록 (Rule 8). C.2.1의 비공식 bound `K < M`는 design guidance이며, D.1의 binding constraint는 sum이다. |
| 1 | const int | 1 | READY confirmation tick: SM이 `state_changed(_, &"alive")` 수신 → READY phase 진입. |
| result | bool | {true, false} | `M + K + 1 ≤ 60` iff Pillar 1 honoured. `false` = blocking defect (비협상). |

**Output Range**: Boolean invariant. `true` = Pillar 1 honoured. `false` = blocking defect.

**Tick-zero note**: PRE-EMIT co-tick (Rule 4 — `scene_will_change` emit + `change_scene_to_packed` call이 같은 틱 T+0)는 SWAPPING phase의 시작에 포함되며 별도 가산되지 않는다 (no double-count).

**Worked example** (placeholder values — Section H 측정 대기):

```
M = 30 ticks  (0.500 s — Godot 4.6 estimate, single scene, no streaming)
K = 12 ticks  (0.200 s — _ready() chain + anchor 등록)
1 =  1 tick   (READY 확인)
──────────────────
sum = 43 ≤ 60 → PASS  (17-tick headroom)
```

Violation example: `M = 50, K = 10, 1 = 1 → 61 > 60 → FAIL (Pillar 1 breach)`.

**Edge**: `M = 0`는 invalid (동기 engine 호출은 최소 1 tick 소비). Boot-time assert 의무: `M ≥ 1`. `K = 0`은 legal하지만 (`_ready()` chain sub-tick 완료 가능) 검증되지 않음.

---

### D.2 Token Preservation Invariant

**Serves**: Rule 7 · TR E-16 · C.3.2 T+0 wiring

**Named expression**:

```
Δ_tokens_attributable_to_SM = 0
```

즉, SM은 `_tokens`에 대한 write site를 보유하지 **않는다**. 전환 전후 `_tokens` 값 변화가 관측되면 그것은 TR의 책임이며(예: TR Rule 15 `boss_killed` → `grant_token()`) SM의 책임이 아니다.

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `_tokens_pre` | int | 0–5 | `scene_will_change` emit 직전 틱의 TRC `_tokens` 값 |
| `_tokens_post_SM` | int | 0–5 | SM의 핸들러 체인 완료 후 TRC `_tokens` 값 (SM 기여분만) |
| `Δ_tokens_attributable_to_SM` | int | {0} | 반드시 0. SM은 `_tokens` 읽기/쓰기 사이트 없음. |
| result | bool | {true, false} | `Δ = 0` iff invariant 유지. `false` = code defect (SM이 `_tokens` 작성; TR 단일 소유 위반). |

**Output Range**: Boolean invariant. `false`는 code defect (SM이 `_tokens` 쓰기; TR 단일 소유 위반).

**Worked example — checkpoint restart (RESTART_PENDING)**:

```
_tokens_pre = 3
SM emits scene_will_change → TRC _buffer_invalidate() clears _buffer_primed + _write_head only
_tokens_post_SM = 3   → Δ = 0 → PASS
```

**Worked example — boss kill (CLEAR_PENDING, 같은 틱 TR grant)**:

```
_tokens_pre = 3
SM emits scene_will_change → TRC _buffer_invalidate()
TR grant_token() 발화 (TR Rule 15 — SM과 독립)
_tokens_post_SM = 3   (SM 기여분만)
TR 기여분: _tokens = 4 — TR attributable, SM 무관 → PASS
```

**Falsifiability**: `scene_manager.gd`에서 `_tokens` grep → 0 write-site. 1+ 매치 시 blocking defect.

---

### D.3 Checkpoint Anchor Selection Rule

**Serves**: Rule 8 · Pillar 2 결정론

**Named expression**:

```
respawn_position = anchors[N-1].global_position           (if N ≥ 1)
respawn_position = player.global_position (E.2 fallback)  (if N = 0; push_error + assert in debug — NOT BoundaryState.PANIC)
```

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| N | int | 0–∞ | 씬 `_ready()` chain 완료 후 `checkpoint_anchor` group 멤버 노드 수 |
| anchors[ ] | Node2D[] | — | 그룹 멤버의 ordered list. Godot scene-tree top-down 순서 (`.tscn` serialisation 결정론). 런타임 정렬 없음. |
| anchors[N-1] | Node2D | — | Last-registered = tree-bottom-most (시계 시간 가장 최근 X — reboot 결정론 유지). |
| `respawn_position` | Vector2 | scene-local, unbounded | 선택된 anchor의 `global_position`. Playable bounds 보장은 level designer 책임. |
| result | Vector2 | — | N ≥ 1 → anchor 위치; N = 0 → `player.global_position` (E.2 last-known-position 처리; **not** `BoundaryState.PANIC` — PANIC은 E.1 null-PackedScene 경로 전용). |

**Output Range**: `Vector2` — unbounded (scene 좌표 공간). Playable bounds clamping은 level designer 책임 (SM 외부).

**Worked example**:

```
씬에 anchor 1개 (320, 448):
  N = 1 → anchors[0].global_position = (320, 448) → respawn_position = (320, 448)

씬에 anchor 2개 (tree-order): A (100, 200), B (300, 400):
  N = 2 → anchors[1] = B → respawn_position = (300, 400)
  push_warning("Multiple checkpoint anchors in scene — using last")
```

**Edge**: `N = 0` → `push_error` + `_respawn_position = player.global_position` (마지막 알려진 위치) per E.2 — **not** `BoundaryState.PANIC` (PANIC은 E.1 null-PackedScene terminal 경로 전용 / D.5 5번째 enum value). N=0은 진단 신호이며 lifecycle은 IDLE/ACTIVE 정상 진행; AC-H10 verifies. `N > 1`은 level design warning이며 hard error 아님 (mid-stage + stage-start 다중 anchor 배치는 iteration 중 유효한 패턴일 수 있음; warning은 non-fatal).

---

### D.4 Cold Boot Budget

**Serves**: Pillar 4 5분 룰 · Rule 13

**Named expression**:

```
cold_boot_elapsed_s = (t_first_input_ms - t_process_start_ms) / 1000.0 ≤ 300.0
```

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `t_process_start_ms` | int | 0–∞ | OS epoch ms — 게임 프로세스 launch. Godot 등가: `SceneManager._ready()` 실행 시 `Time.get_ticks_msec()` 캡처. |
| `t_first_input_ms` | int | `t_process_start_ms`–∞ | 첫 accepted `InputEvent`가 gameplay action 트리거 (인트로 화면 → game start). Press-any-key 게이트 금지 (Rule 13); 첫 입력은 자연 gameplay trigger. |
| `cold_boot_elapsed_s` | float | 0.0–∞ | 프로세스 시작부터 첫 actionable input까지 elapsed seconds. Unbounded above; ≤ 300.0 s contract. |
| result | bool | {true, false} | `true` iff `cold_boot_elapsed_s ≤ 300.0`. |

**Output Range**: Boolean invariant on float. `false` = Pillar 4 breach; non-blocking advisory defect (D.1과 달리 비협상 아님). 실측 예상치는 ≪ 10 s; 300 s ceiling은 극단적 asset-streaming design 예방.

**Scope note**: D.4는 cold boot만 측정. Warm reload (체크포인트 재시작, D.1)는 제외 — D.1이 그 예산 보유.

**Engine bootloader gap (scope boundary)**: `t_process_start_ms`는 OS 프로세스 launch가 아닌 `SceneManager._ready()` 진입 시점에 캡처된다 — Godot 엔진 자체 bootloader 시간(GDScript 첫 실행 *이전*)은 본 측정에서 제외된다. SSD 환경 typical < 1 s; 본 갭은 일반적으로 무시 가능하지만, AC-H2b Steam Deck 1세대 실측이 300 s ceiling에 근접할 경우 (a) OS stopwatch로 외부 측정 의무 추가, 또는 (b) D.4 공식을 `t_process_start_ms = OS.get_unix_time_from_system()` 캡처로 개정. Tier 1 현재 measurements 예상치 ≪ 10 s이므로 본 갭은 advisory.

**Worked example**:

```
t_process_start_ms = 1_000_000
t_first_input_ms   = 1_004_200  (4.2 s boot — typical SSD load)
elapsed            = 4200 / 1000.0 = 4.200 s ≤ 300.0 → PASS

Pathological: elapsed = 310.0 s (streaming hang) → FAIL (Pillar 4 breach)
```

**Edge**: 헤드리스 smoke-check 환경 (Section H AC)에는 키보드 앞 사람 없음. 부팅 후 고정 frame count에 scripted input injection으로 자동화. Steam Deck 1세대 SSD가 real target hardware baseline.

---

### D.5 Same-Tick Boundary State Resolution

**Serves**: C.3.3 priority policy · Rule 12 · ADR-0003

**Named expression**:

```
new_boundary_state =
  CLEAR_PENDING    if boss_killed_seen = true
  RESTART_PENDING  if boss_killed_seen = false ∧ dead_seen = true
  (unchanged)      if boss_killed_seen = false ∧ dead_seen = false
```

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `boss_killed_seen` | bool | {true, false} | 현재 `_physics_process` 틱 내에서 SM의 `_on_boss_killed()` 핸들러 발화 시 true. Tick-scoped: 같은 틱의 boundary-state 평가 종료 시 false로 클리어. |
| `dead_seen` | bool | {true, false} | 현재 틱 내에서 SM의 `_on_state_changed()`가 `to == &"dead"` 수신 시 true. Tick-scoped: `boss_killed_seen`과 동일 lifetime. |
| `new_boundary_state` | BoundaryState enum | {BOOT_INTRO, ACTIVE, RESTART_PENDING, CLEAR_PENDING, PANIC} | 모든 핸들러 발화 후 SM boundary state. C.2.1 PRE-EMIT entry로 직결 (PANIC은 E.1 null PackedScene 경로 전용 — lifecycle 진행 차단). |
| result | BoundaryState | (enum — 5 values) | Deterministic; no RNG. |

**Output Range**: Enum — 5 discrete values. No clamping; 틱당 정확히 1회 설정. PANIC은 D.5 same-tick 평가 경로가 아니라 E.1 (null PackedScene) 진단 경로에서만 진입한다 — D.5의 `new_boundary_state`는 E.1 PANIC 분기를 포함하지 않으며, PANIC 진입 시 D.5 전체가 우회된다 (lifecycle 진행 차단).

**Boolean precedence**: `boss_killed_seen`이 `dead_seen`을 short-circuit. 본 인코딩은 player-mental-model contract — "보스가 죽고 플레이어가 같은 hit에 죽었다면, 스테이지는 클리어이지 재시작이 아니다" (Pillar 1 — Defiant Loop 학습 모델이 같은 틱 corner case에 흔들리지 않음).

**Worked example — normal restart**:

```
Tick: boss_killed_seen = false, dead_seen = true
→ new_boundary_state = RESTART_PENDING → C.2.1 PRE-EMIT (동일 PackedScene 재로드)
```

**Worked example — same-tick boss kill + player death**:

```
Tick: boss_killed_seen = true, dead_seen = true
→ new_boundary_state = CLEAR_PENDING  (boss_killed_seen wins)
→ 후속 dead_seen 핸들러: early-return, 상태 변경 없음
→ C.2.1 PRE-EMIT → victory screen PackedScene
```

**Edge**: 같은 틱에 `dead_seen`과 `boss_killed_seen`이 모두 true가 되는 경우, ADR-0003 priority ladder에 EchoLifecycleSM 슬롯이 등록되어 있지 않으므로 SM 핸들러 호출 순서는 **undefined**다 (`state_changed` 먼저 vs `boss_killed` 먼저 — 도착 순서 무관). C.3.3 GDScript pattern의 `_boundary_state == CLEAR_PENDING` early-return 가드가 도착 순서에 무관하게 동일 결과(CLEAR_PENDING 승)를 보장한다.

---

### D.6 `scene_will_change` Emit Cardinality Invariant

**Serves**: Rule 4 (sole producer) · Rule 6 (no buffer touch) · TR E-16 (TRC `_buffer_invalidate()` idempotency dependency)

**Named expression**:

```
emit_count(scene_will_change, per_transition) = 1
emit_count(scene_will_change, while_phase = IDLE) = 0
```

**Variable table**:

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `per_transition` | scope | — | 1개의 완전한 C.2.1 lifecycle pass: IDLE → PRE-EMIT → SWAPPING → POST-LOAD → READY. |
| `emit_count(e, scope)` | int | {0, 1} | `scope` 내에서 SM의 `scene_will_change` emit 회수. {0, 1} 외 값은 defect. |
| `phase_at_emit` | Phase enum | {PRE_EMIT} | Emit은 `_phase == Phase.PRE_EMIT` 시점에만 유효. 다른 phase에서 emit은 defect. |
| result | bool | {true, false} | Invariant holds iff `emit_count == 1` during transition AND `emit_count == 0` during IDLE. |

**Output Range**: Boolean invariant. 어느 한 절이라도 `false` = blocking defect — double-emit은 `_buffer_invalidate()` 이중 호출 → `_write_head` + `_buffer_primed` 중복 reset → 전환 이전 in-flight rewind sequence 손상 가능.

**Worked example — satisfied**:

```
Transition triggered (DEAD received):
  _phase: IDLE → PRE_EMIT
  emit scene_will_change()  [count = 1 ✓]
  _phase: PRE_EMIT → SWAPPING
  ... POST_LOAD ... READY ... IDLE
  No further emits [IDLE count = 0 ✓] → PASS
```

**Violation example** (D.6이 방어):

```
Bug: _on_state_changed가 한 틱에 두 번 발화 (duplicate signal connect)
  emit scene_will_change()  [count = 1]
  emit scene_will_change()  [count = 2 ✗] → FAIL
  → TRC _buffer_invalidate() 이중 호출 → _write_head 이중 reset → ring buffer 손상
```

**Falsifiability**: Unit test — `scene_will_change`에 counter 구독 연결 후 완전한 lifecycle pass 트리거 → READY 시점 `counter == 1` 검증. IDLE-phase 테스트: N 틱 동안 transition 미트리거 → `counter == 0` 검증.

---

**Registry 후보 (Phase 5b 일괄 등록)** — C.3.5에서 이미 큐잉됨:

- `restart_window_max_frames = 60` (D.1 ceiling)
- `cold_boot_max_seconds = 300` (D.4 ceiling)

## E. Edge Cases

10 edge cases organized as: **Panic conditions** (E.1–E.3 — SM cannot proceed) · **Lifecycle re-entrancy** (E.4–E.6 — concurrent triggers) · **Boot edge cases** (E.7–E.9) · **Performance/resource** (E.10).

### Panic conditions

- **E.1 — `change_scene_to_packed(packed)`에서 `packed == null`**: SM은 `change_scene_to_packed` 호출 *전*에 `packed != null` 가드 → null이면 `push_error("SceneManager: null PackedScene")` + `_boundary_state = BoundaryState.PANIC` 설정 (D.5 enum 5번째 값 — D.5 same-tick 평가 경로 우회) + `_phase = IDLE` 유지 (lifecycle 진행 차단) + 디버그 빌드에서는 `assert(false)`. Release 빌드는 디버그 라벨로 freeze된 현재 씬에 머무름 (DEAD enter 후 panic이면 플레이어는 작동 불가 상태 — 게임 종료 권장 UX). *Rationale*: PackedScene resource missing은 빌드 누락이며 게임플레이 중 정상 케이스 아님.
  - **PANIC terminality (Tier 1)**: Tier 1에서 PANIC은 **terminal** 상태다 — 회복 경로 미정의. `_boundary_state = BoundaryState.PANIC` 진입 후 SM은 어떠한 `_trigger_transition()` 호출도 발생시키지 **않는다**. 후속 `boss_killed` 또는 `state_changed(_, &"dead")` 시그널이 도달해도 C.3.3 핸들러는 panic-state 우선 가드(`if _boundary_state == BoundaryState.PANIC: return`)에 의해 early-return하며 `_boundary_state` 덮어쓰기 + `_trigger_transition` 호출 둘 다 차단된다. 결과적으로 lifecycle은 IDLE-locked 상태로 멈추며 정상 gameplay 진행 불가 — UX는 게임 종료 안내(별도 시스템) 또는 process exit. Tier 2 다중 스테이지 진입 시 panic 회복(예: stage 1 fallback) 정책이 도입되면 본 항목 + AC-H26을 함께 개정. *Guard AC*: AC-H26 (H.4 그룹)이 panic 진입 후 후속 시그널이 `_trigger_transition` 호출을 트리거하지 않음을 검증.

- **E.2 — N=0 checkpoint anchors (D.3 panic 분기)**: 씬 `_ready()` chain 완료 시점에 `checkpoint_anchor` 그룹 멤버 0개 → `push_error("SceneManager: no checkpoint anchor in scene")` + `respawn_position = current_player_position` (마지막 알려진 위치) fallback + 디버그 빌드 `assert(false)`. Tier 1 단일 스테이지에서는 level designer가 anchor 1+ 배치 의무 — 본 fallback은 디버그 신호일 뿐 정상 경로 아님.

- **E.3 — Out-of-memory during scene load**: `change_scene_to_packed`가 OS의 OOM 신호를 throw하지 않는다 (Godot 동작) — 메모리 1.5 GB ceiling 초과 시 SceneTree가 텍스처 로드 실패한 채 새 씬 반환. SM은 메모리 모니터링 하지 않음 (Tier 1 scope 밖); Tier 2 게이트에서 `OS.get_static_memory_usage()` 모니터링 + 75% 임계치 push_warning 도입.

### Lifecycle re-entrancy

- **E.4 — `boss_killed` arrives while `_phase != IDLE`**: SM이 transition lifecycle 진행 중(`_phase ∈ {PRE-EMIT, SWAPPING, POST-LOAD}`)에 `boss_killed` 시그널 수신 → `_on_boss_killed` 핸들러 early-return + `push_warning("boss_killed during transition — ignored")`. *Rationale*: lifecycle 진행 중 새 transition 트리거는 ill-defined; 진행 중 transition이 완료(READY 진입)된 후 자연스럽게 다음 boundary 평가에서 처리됨. 보스 격파 후 ECHO가 새 씬에 도착하면 보스 host가 이미 destroyed 상태이므로 추가 emit 없음.

- **E.5 — `state_changed(_, &"dead")` arrives while `_phase != IDLE`**: SM이 lifecycle 진행 중 ECHO DEAD 전이 시그널 수신 → 동일하게 early-return (E.4와 같은 정책). Tier 1에서는 transition 중 ECHO 노드 자체가 `queue_free()` 또는 새 씬 인스턴스화에 의해 교체되므로 정상적으로는 발생 안 함; 그러나 state-machine.md C.2.2 race (DYING + scene_will_change 동시 도착)의 SM-side coverage로 본 가드 보유.

- **E.6 — First input during BOOT_INTRO but EchoLifecycleSM not yet booted**: cold-boot 시 스플래시/인트로 화면에서 첫 입력이 도착하지만 EchoLifecycleSM이 아직 ALIVE 진입 전(Rule 10 — EchoLifecycleSM 자체 `_ready()` 부트 미완료). SM은 input을 받지 않음 — input 자체는 `input.md` C.5의 owner; SM은 input.md C.5가 `_input()`/`_unhandled_input()`에서 직접 `change_scene_to_packed` 트리거하지 않도록 보장. 대신 input.md은 "intro screen → game start" 라우터 노드를 통해 SM에 *transition request*를 보냄. Tier 1에서는 첫 입력 = `change_scene_to_packed(stage_1_packed)` 호출이 input.md C.5 라우터에서 동기 호출되며 SM이 PRE-EMIT 진입.

### Boot edge cases

- **E.7 — Cold boot 입력이 Esc / Pause 같은 game-start non-trigger 액션**: `input.md` C.5의 라우터가 intro 화면에서 어떤 input이 "game start" 트리거인지 결정. SM은 라우터 호출만 받으므로 본 케이스의 처리는 input.md C.5 owner (예: Esc는 quit-to-desktop, 다른 모든 input은 game start). 본 GDD는 라우터 contract만 등록.

- **E.8 — Scene file missing on disk (E.1 변형)**: 빌드 시점에 PackedScene이 export 누락 → `preload()` 실패 → null reference → E.1과 동일 panic 경로. Tier 1 단일 스테이지에서는 빌드 검증으로 방어; Tier 2+ 다중 스테이지에서는 SceneManager에 `_validate_scene_table()` boot-time check 추가 권장 (모든 stage PackedScene `is_class("PackedScene")` 검증).

- **E.9 — Save file references invalid scene**: Tier 1 = persistence 없음 (단일 스테이지 슬라이스). Tier 2+ 진입 시 본 케이스 처리는 Save / Settings Persistence #21 GDD가 보유 — invalid scene 참조 시 SM에 stage 1 fallback 요청.

### Performance / resource

- **E.10 — `change_scene_to_packed` exceeds 60-tick budget (D.1 violation)**: M+K+1 > 60 ticks 발생 → SM은 budget 위반을 *블로킹*하지 않음 (게임 멈춤 회피 — 1초 늦은 재시작이 정지 화면보다 나음); 그러나 `push_warning("Restart budget exceeded: %d ticks" % total_ticks)` + Tier 1 playtest review-log에 자동 기록. Tier 1 Week 1 prototype에서 Steam Deck 1세대 실측이 60-tick 일관 위반 시 (a) 씬 크기 축소 (b) async load 도입 (Tier 2 scope 조기 이월) 검토. *Rationale*: Pillar 1 비협상이지만 hard-crash 회피가 우선.

---

**Edge cases NOT in scope of SM** (defer to specified GDD):

- 토큰 grant cap overflow (TR Rule 3 / D1 ⇨ HUD #13)
- DYING grace 변화 (Damage DEC-6)
- TRC `_buffer_invalidate()` 자체 idempotency (TR E-16 — TRC 단일 소유)
- 입력 버퍼 ephemeral state 클리어 (SM #5 O6 cascade)
- 보스 페이즈 advance 이중 발화 (Damage `_phase_advanced_this_frame` lock — damage.md D.2.1)

## F. Dependencies

### F.1 Downstream Dependents (systems that depend on SM)

> **Numbering convention**: `#N` references the row number in `design/gdd/systems-index.md`. Status mirrors that index at HEAD; status drift between this table and the index is a lint signal.

| # | System | Status | Interface | Hard / Soft | Notes |
|---|---|---|---|---|---|
| **#1** | Input System | Approved | input.md C.5 router calls `SM.change_scene_to_packed(stage_1_packed, TransitionIntent.COLD_BOOT)` on first cold-boot input (E.6 / E.7) | **Hard** | Cold-boot trigger source (Pillar 4 5분 룰 critical path). input.md C.5 owns router; SM exposes receive API. F.3 reciprocal already present. Added Session 19 RR5 (was structural omission). |
| **#3** | Camera System | Approved (RR1 PASS 2026-05-12) | `scene_post_loaded(anchor: Vector2, limits: Rect2)` (Camera #3 first-use 2026-05-12 — Q2 closure per C.3.4) | **Hard** | Camera snap-to-anchor on checkpoint restart (no cut) + stage limit set. Active in Tier 1. camera.md R-C1-10 + R-C1-12 + AC-CAM-H5-01/02 reciprocal. |
| **#4** | Audio System | Not Started | `scene_will_change()` (bus reset Tier 2); `boss_killed` (stage clear SFX) | **Soft** | Tier 1 stub-level; bus reset 미적용. |
| **#5** | State Machine Framework | Approved | `scene_will_change()` → EchoLifecycleSM `_on_scene_will_change()` O6 cascade (state-machine.md C.2.2 O6) | **Hard** | Cascade triggers `_lethal_hit_latched` + 입력 버퍼 + O8 counter clear + PM `_clear_ephemeral_state()` 호출 |
| **#6** | Player Movement | Approved | (via #5 cascade — PM은 직접 구독 안 함; player-movement.md F.4.2 row #2) | **Hard (via cascade)** | OQ-PM-1 closure: SM emit → EchoLifecycleSM cascade → PM 8-var clear. PM은 SM에 직접 의존하지 않음. |
| **#8** | Damage / Hit Detection | LOCKED | `boss_killed(boss_id: StringName)` SM이 구독 (damage.md F.4) | **Hard** | Damage emit → SM CLEAR_PENDING → stage clear lifecycle (Rule 12 + C.3.3) |
| **#9** | Time Rewind System | Approved | `scene_will_change()` → TRC `_buffer_invalidate()` (time-rewind.md F.1 row #2 + E-16) | **Hard** | Ring buffer 무효화 단일 트리거; `_tokens` 보존 |
| **#12** | Stage / Encounter System | Not Started | `scene_post_loaded(anchor: Vector2, limits: Rect2)` (signature locked 2026-05-12 via Camera #3 first-use; Stage GDD가 stage root에서 `limits: Rect2` 노출 패턴 결정) + `boss_killed` (스테이지 클리어 라우터) | **Hard** | Stage #12 = SM의 1차 downstream client; SM은 boundary, Stage #12는 in-stage encounter flow 소유. F.4.2 Stage #12 row 의무 참조. |
| **#13** | HUD System | Not Started | (Tier 2 결정) `state_changed(_, &"dead")` 직접 구독 vs `scene_will_change()` 구독 | **Soft** | HUD는 TR / Damage / EchoLifecycleSM 시그널을 독립 구독 |
| **#15** | Collage Rendering Pipeline | Not Started | (Tier 2+) `scene_will_change()` → 텍스처 캐시 명시 해제 | **Soft (Tier 2)** | Tier 1 단일 스테이지에서는 명시 해제 불필요; Tier 2 진입 시 본 GDD 개정 |
| **#17** | Story Intro Text System | Not Started | SM은 stage_1 PackedScene 내 intro text 노드 인스턴스화 (씬 자체 wiring); 별도 시그널 없음 | **Soft** | Pillar 4 5분 룰 — intro 5줄 타이프라이터는 자체 완료 후 첫 입력 대기 |
| **#18** | Menu / Pause System | Not Started | (Tier 2 결정) Pause 시 SM `_phase` 동결 정책 | **Soft** | Pause는 process_mode 변경; SM은 IDLE phase에서만 정상 동작 |

### F.2 Upstream Dependencies (systems SM depends on)

| Upstream | Status | Reason |
|---|---|---|
| — | — | SM은 Foundation (Layer 0). Design-level upstream 의존성 없음. Engine-level only: Godot 4.6 `SceneTree` + autoload subsystem. |

### F.3 Bidirectional Verification — F.1 reciprocals already in Approved GDDs

| Approved GDD | SM-side claim (본 GDD) | Reciprocal location (target GDD) | Status |
|---|---|---|---|
| time-rewind.md | TRC subscribes `scene_will_change()` → `_buffer_invalidate()` | F.1 row #2 + E-16 | ✅ Present (*(provisional)* annotation to remove per C.3.5) |
| state-machine.md | EchoLifecycleSM subscribes `scene_will_change()` (O6 cascade) | C.2.2 O6 + F.3 row #2 | ✅ Present (provisional contract to confirm per C.3.5) |
| damage.md | `boss_killed` emit → "#2 Scene Manager (스테이지 클리어 트리거)" | F.4 row (`boss_killed → #2 Scene Manager`) | ✅ Present (미작성 annotation to remove per C.3.5) |
| player-movement.md | PM은 SM에 직접 의존 안 함; F.4.2 row #2 SM cascade obligation | F.4.2 row #2 | ✅ Present (OQ-PM-1 closure annotation to add — 8-var clear 책임 EchoLifecycleSM cascade 경유) |
| input.md | input event → game start (#2 Scene Manager owner) | C.5 (cold-boot router; F.4.1 #4 cross-doc row) | ✅ Present (no edit needed) |

### F.4 Cross-doc Reciprocal Obligations

#### F.4.1 One-time closures (apply at Phase 5d)

Detailed table in C.3.5 — 7 GDD edits + 2 registry batch (entities.yaml + architecture.yaml). Summary:

- `time-rewind.md` F.1 row #2 + OQ-4 closure
- `state-machine.md` C.2.2 O6 + F.3 row #2 + OQ-SM-2 closure
- ~~`damage.md` F.4 row `boss_killed` — *(미작성)* 제거~~ ✅ **Closed at RR5 2026-05-11**: annotation verified absent at HEAD; no edit needed.
- `player-movement.md` F.4.2 row #2 — OQ-PM-1 closure annotation update
- `docs/registry/architecture.yaml` — 4 new entries (`interfaces.scene_lifecycle`, `state_ownership.scene_phase`, 2 group-name `api_decisions`)
- `design/registry/entities.yaml` — 2 new constants (`restart_window_max_frames=60`, `cold_boot_max_seconds=300`)
- `design/gdd/systems-index.md` row #2 — In Design → Designed (Phase 5d) → Approved (post-review)

**Cross-doc drift housekeeping** (C.1 Rule 12 discovery): `boss_defeated` → `boss_killed` 일괄 치환 — time-rewind.md 13 sites + state-machine.md 4 sites = **17 simple replacements** (HEAD `grep -c` 실측 2026-05-11). damage.md F.4 LOCKED + AC-13 BLOCKING이 single-source 권위. Session 19 후속 housekeeping batch로 분리 (17 단순 치환, 비파괴적).

> **⚠️ Approved promotion gate (BLOCKING)**: F.4.1 Phase 5d batch는 본 GDD의 "Designed (pending re-review)" → **Approved** 승격 전 적용 필수. 미적용 시 F.3 bidirectional verification 항목들이 stale 상태로 남아 cross-review lint signal로 검출됨 (verified at HEAD 2026-05-11 re-review #4: PM F.1 row line 978 still `*(provisional re #2 Not Started)*`; PM F.4.2 row line 531 still `*(provisional)*` + `TBD` wiring). Phase 5d 7-GDD batch + 2 registry batch는 Approved 게이트의 일부이며 별도 commit으로 분리 가능하지만 게이트 통과 전에 완료되어야 함. Housekeeping batch (17-site `boss_defeated → boss_killed`)은 분리 commit이며 Approved 게이트 BLOCKING은 아님 (damage.md single-source 권위가 보장됨).

#### F.4.2 Future GDD obligations (target GDD 작성 시 의무)

각 target GDD의 H 섹션은 작성 시 reciprocal AC를 포함해야 한다 — 본 GDD의 current-PR PASS/FAIL gate 아님.

| Target GDD | 의무 | Closure trigger |
|---|---|---|
| ~~**Camera #3**~~ ✅ **Closed 2026-05-12 (Camera #3 Approved RR1 PASS)** | ~~(1) `scene_post_loaded(anchor: Vector2)` 시그널 추가 — 본 GDD revision 필요; (2) Camera snap-to-anchor on POST-LOAD entry; (3) AC: 체크포인트 재시작 후 1 tick 내 camera 정렬 완료~~ → **Resolved**: signal signature finalized as `scene_post_loaded(anchor: Vector2, limits: Rect2)` (2-arg — limits added for stage-by-stage variability absorption per camera.md C.3.3 + R-C1-12 single-source). C.2.1 POST-LOAD body now emits the signal after `checkpoint_anchor` registration + boot-time `assert(limits.size > 0)` (E-CAM-7). Camera handler R-C1-10 cost ≤ 1 tick (snap + 4 limit setters + reset_smoothing); fits within SM 60-tick restart budget without additional accounting. Camera AC-CAM-H5-01 (snap correctness) + AC-CAM-H5-02 (60-tick budget) verify the integration. Phase 5 cross-doc batch landed 2026-05-12. | Camera #3 GDD authoring (Closed) |
| **Audio #4** | (1) `scene_will_change()` → bus reset (Tier 2만); (2) `boss_killed` → stage clear SFX trigger; (3) AC: SFX bus 전환 시 audible crackle 없음 | Audio #4 GDD authoring |
| **Stage / Encounter #12** | (1) `scene_post_loaded(anchor: Vector2, limits: Rect2)` 2-arg signal 사용 — encounter trigger node wiring + stage root에서 `limits: Rect2` 노출 패턴 결정 (export var `stage_camera_limits: Rect2` 또는 `Marker2D` 자식 노드 query) — signature locked 2026-05-12 via Camera #3 first-use; (2) `boss_killed` 다음 PackedScene 라우팅 — Tier 2 진입 시 본 GDD `change_scene_to_packed` 인자 결정 로직 개정; (3) AC: stage 진입 시 모든 encounter trigger 등록 완료 + `limits.size > 0` boot assert 통과 (E-CAM-7) | Stage #12 GDD authoring |
| **HUD #13** | (1) `state_changed(_, &"dead")` 직접 구독 vs `scene_will_change()` 구독 결정; (2) AC: stage clear 시 HUD fade-out timing 결정론 | HUD #13 GDD authoring |
| **VFX #14** | (1) `scene_will_change()` 시 active particle 정리 정책 (즉시 free vs 자연 만료); (2) AC: 씬 전환 시 leftover particle 0 검증 | VFX #14 GDD authoring |
| **Collage Rendering #15** | Tier 2 진입 시 (1) `scene_will_change()` → 텍스처 캐시 명시 해제; (2) AC: 메모리 1.5 GB ceiling 미위반 + 새 씬 GPU 텍스처 로드 완료 검증 | Collage Rendering #15 GDD authoring (Tier 2 게이트) |
| **Menu / Pause #18** | (1) Pause 시 SM `_phase` 동결 정책; (2) AC: pause 중 `change_scene_to_packed` 트리거 미발생 | Menu #18 GDD authoring |
| **Save Persistence #21** | (Tier 2+) (1) invalid scene 참조 fallback → SM stage 1 요청; (2) AC: corrupt save 파일 → 게임 정상 부팅 | Save #21 GDD authoring (Tier 2 게이트) |

## G. Tuning Knobs

SM은 contract-driven Foundation 시스템이다. Pillar 1 (< 1초 재시작) + Pillar 4 (5분 룰)는 D.1/D.4 budget ceiling을 **비협상 invariant**로 락한다 — tunable 아님. Tier 1에서 designer-adjustable한 값은 intro pacing + 진단 warning threshold + scene table 항목뿐이다.

### G.1 Locked Constants (NOT tunable — Pillar 비협상)

| Constant | Locked value | Locked by | Modification gate |
|---|---|---|---|
| `restart_window_max_frames` | **60 frames** (= 1.000 s @ 60 Hz) | Pillar 1 / Rule 9 / D.1 | game-concept revision 필요 (Pillar 변경) — `/architecture-decision` |
| `cold_boot_max_seconds` | **300.0 s** | Pillar 4 / Rule 13 / D.4 | game-concept revision 필요 (Pillar 4 5분 룰 변경) |
| `scene_manager_group_name` | `&"scene_manager"` | state-machine.md C.2.1 line 322 cross-doc 락 | Cross-doc batch revision (5+ files) |
| `checkpoint_anchor_group_name` | `&"checkpoint_anchor"` | Rule 8 / D.3 | Cross-doc batch revision (level designer convention 변경) |

### G.2 Designer-Tunable (Tier 1)

| Knob | Default | Safe range | Affects | Out-of-range 동작 |
|---|---|---|---|---|
| `intro_screen_duration_seconds` | 8.0 | 5.0 – 30.0 | Pillar 4 5분 룰 직접 영향. 8.0 s는 인트로 5줄 타이프라이터 표시 + 첫 입력 안내 시간. | < 5.0 → 플레이어가 인트로 텍스트 읽기 전 게임 진입; > 30.0 → Pillar 4 위반 위험 (cold_boot 예산 잠식) |
| `multiple_anchors_warning_n` | 2 | 1 – 10 | Rule 8 / D.3 — `N > threshold` 시 `push_warning` 발화. 기본값 2 = "2개 이상이면 경고". | 1 → 항상 경고 (앵커가 1개여도 발화 — 잘못된 시그널); ≥ 10 → 사실상 무경고 (대형 씬에서 의도된 다중 앵커 패턴 무시) |
| `victory_screen_packed` | `preload("res://scenes/victory_screen.tscn")` | (PackedScene resource path) | Stage clear 시 `change_scene_to_packed` 인자 (Tier 1 단일 스테이지). Tier 2 진입 시 본 knob을 `next_stage_packed` 동적 lookup으로 개정. | `null` → E.1 panic 경로; 잘못된 PackedScene → 새 씬 진입 시 E.2 anchor 부재 panic |
| `stage_1_packed` | `preload("res://scenes/stage_1.tscn")` | (PackedScene resource path) | Cold boot 시 첫 `change_scene_to_packed` 인자. Tier 1 단일 스테이지. | `null` → E.1 panic; 잘못된 경로 → 빌드 export 누락 E.8 |

### G.3 Debug-only Toggles (NOT shipped in release builds)

| Knob | Default | Affects |
|---|---|---|
| `debug_print_phase_transitions` | `false` | `true` 시 `_phase` 전이마다 `print()` (lifecycle 추적 디버깅). Release 빌드에서 `false` 강제. |
| `debug_simulate_load_failure` | `false` | `true` 시 `change_scene_to_packed` 호출 직전 항상 panic state 진입 (E.1/E.8 시나리오 수동 테스트). Release 빌드에서 `false` 강제. |
| `debug_simulate_budget_overrun` | `false` | `true` 시 mock `change_scene_to_packed` shim이 deterministically M+K+1 > 60 ticks 소비하도록 강제 (E.10 / Rule 9 violation branch 자동화 테스트 용). Panic state는 진입하지 않으며, lifecycle은 budget 초과 후에도 READY phase에 도달 (E.10 contract — "1초 늦은 재시작이 정지 화면보다 나음"). Release 빌드에서 `false` 강제. **AC-H17 의존 — `debug_simulate_load_failure`와 별개 flag.** |
| `debug_panic_use_player_position` | `true` | E.2 (N=0 anchors) 진단 시그널 동작 — `false`로 설정 시 E.2 panic이 hard-freeze로 fall through (level designer가 anchor 누락을 즉시 발견하도록). Release 빌드에서는 항상 `true`로 강제. |

### G.4 Interaction Notes (knob 상호작용)

- **`intro_screen_duration_seconds` × `cold_boot_elapsed_s` 누적**: D.4 `cold_boot_elapsed_s` 범위는 `SceneManager._ready()` 진입 → 첫 actionable input까지이며 **Godot 엔진 부트로더 시간은 제외**됨 (D.4 "Engine bootloader gap (scope boundary)" 참조). 따라서 `cold_boot_max_seconds = 300` 예산 안에 들어와야 하는 누적은 `intro_screen_duration + 추가 씬 로드 + 첫 input 대기`이며 엔진 부트는 외부 측정. Tier 1 실측 예상: intro 8 s + 첫 stage 로드 < 1 s + input ~0 s ≈ 9 s ≪ 300 s ceiling. (엔진 부트 ~3 s는 별개 OS-측정 — D.4 advisory: Steam Deck 1세대 AC-H2b 결과가 ceiling에 근접 시 OS stopwatch 측정 의무 추가.)
- **`multiple_anchors_warning_n` vs Tier 2 stage 디자인**: Tier 2의 mid-stage checkpoint 도입 시 `N > 1`이 정상 패턴이 되므로 threshold를 3 이상으로 상향 권장.
- **Locked invariants (G.1) vs designer knobs (G.2) — 분리 enforce**: G.1 값은 코드 const + `@export_range` 없음 (Inspector 비노출); G.2 값은 `@export_range` decorator로 Inspector 노출 (designer 조정 허용).
- **Debug toggles (G.3) vs Release 빌드**: `Engine.is_editor_hint()` 또는 빌드 플래그로 release 진입 시 G.3 toggle 강제 reset. 디버그 빌드 전용 항목이 release에 누출되지 않도록 보장 (Pillar 4 비협상 — release 빌드에서 cold boot 5분 위반 차단).

## Visual / Audio Requirements

Scene Manager는 Foundation/Infrastructure 시스템이며 presentation asset을 직접 소유하지 않는다. 본 시스템의 시그널 emit이 downstream presentation 시스템의 동작을 트리거하지만, 각 시각/오디오 요소의 *내용*은 해당 owner GDD가 단일 소유한다.

| 시각/오디오 요소 | 트리거 시그널 (SM emit) | 단일 소유 GDD | Tier |
|---|---|---|---|
| 인트로 5줄 타이프라이터 (텍스트 + 효과음) | 없음 — 씬 자체 wiring | **Story Intro Text System #17** | Tier 1 |
| 인트로 → stage_1 fade-in transition | 없음 — Story Intro #17 완료 후 첫 input → SM `change_scene_to_packed` | Story Intro #17 (visual) | Tier 1 |
| 체크포인트 재시작 fade-out / fade-in | (Tier 2 결정) `scene_will_change()` 구독 가능 | **HUD #13** (Tier 2 게이트) | Tier 2 |
| 스테이지 클리어 victory screen 진입 fade | `boss_killed` → SM CLEAR_PENDING → `change_scene_to_packed(victory_screen)` | HUD #13 (Tier 1 minimal; Tier 2 풀 디자인) | Tier 1 minimal |
| 씬 전환 시 audio bus reset (crackle 방지) | `scene_will_change()` 구독 (Tier 2) | **Audio #4** | Tier 2 |
| Stage clear SFX | `boss_killed` 구독 | Audio #4 | Tier 1 stub |
| 씬 전환 시 active particle 정리 (시각적 leftover 방지) | `scene_will_change()` 구독 | **VFX #14** | Tier 1 |

**Tier 1 SM-owned visual/audio scope**: 없음. 모든 presentation은 downstream에 위임. Tier 1에서 SM은 시그널 emit과 PackedScene 교체만 수행; visual transition (fade) 자체는 PackedScene 내부 노드의 `_ready()` chain에서 자체 진행하거나 Story Intro #17 / HUD #13이 별도 구독으로 처리.

**Q2 deferred signal — `scene_post_loaded(anchor: Vector2)`** (C.3.4 참조): 본 시그널은 Camera #3 또는 Stage #12 GDD 작성 시 본 GDD revision으로 추가됨. POST-LOAD entry 시점에 emit하여 Camera snap-to-anchor + encounter trigger wiring을 가능하게 한다.

> **📌 Asset Spec**: Scene Manager는 sprite/SFX/VFX asset을 소유하지 않으므로 `/asset-spec system:scene-manager`는 적용 불필요. Asset spec은 각 downstream 시스템 (#4 / #13 / #14 / #17) 별도 실행.

## UI Requirements

Scene Manager는 직접 UI를 소유하지 않는다. SM의 시그널이 UI 시스템의 동작을 트리거하지만, UI surface (screen, widget, focus 관리)의 디자인은 해당 owner GDD가 보유한다.

| UI surface | SM 관여 | 단일 소유 GDD | Tier |
|---|---|---|---|
| Cold boot 인트로 screen (5줄 타이프라이터) | SM이 `stage_1_packed` 로드 직전 인트로 노드 인스턴스화 | **Story Intro Text System #17** | Tier 1 |
| Stage clear victory screen | SM이 `change_scene_to_packed(victory_screen_packed)` 호출 — UI 내용은 별도 PackedScene | **HUD #13** (Tier 1 minimal) | Tier 1 minimal |
| Pause menu | SM은 pause 상태에서 `_phase` 동결 (F.4.2 Menu #18 의무) — Menu UI는 별도 시스템 | **Menu / Pause System #18** | Tier 2 |
| Loading screen | Tier 1 = 동기 `change_scene_to_packed` 로 loading screen 불필요 (60-tick 예산 안에 완료). Tier 2 async load 진입 시 도입. | (Tier 2 결정 — HUD #13 또는 Menu #18) | Tier 2 |
| Game-over screen | Tier 1 = 즉시 체크포인트 재시작 (Pillar 1 < 1초 비협상) — game-over screen 없음. | — (Tier 1 N/A) | — |
| Quit-to-desktop confirm dialog | SM 무관 — input.md C.5 Esc 라우터 결정 (E.7) | Menu #18 | Tier 2 |

**Tier 1 SM-owned UI scope**: 없음. SM은 시그널 producer + scene swap executor일 뿐, UI surface는 모두 downstream에 위임.

**UX flow accessibility note**: Pillar 1 비협상 (< 1초 재시작) + Pillar 4 5분 룰 (no Press-any-key)로 인해 SM은 사용자가 직접 인지하는 UI element를 만들지 않는다 — 모든 SM 동작은 *invisible*이다. Accessibility 측면에서 본 시스템은 screen reader / colorblind mode / input remapping 직접 영향 없음 (F.4.2 Audio #4 / HUD #13 / Menu #18이 각각 처리).

> **📌 UX Flag — Scene Manager**: 본 시스템은 직접 UI requirement 없음. Phase 4 (Pre-Production) UX spec 작성 시 SM은 `/ux-design` 대상이 아님 — 대신 Story Intro #17, HUD #13 (victory screen), Menu #18 (pause) GDD 작성 시 각자 `/ux-design`을 수행.

## H. Acceptance Criteria

### H.0 Preamble

**Total ACs: 29**

| Classification | Count | Gate |
|---|---|---|
| Logic (automated unit test — GUT) | 16 | BLOCKING |
| Integration (automated integration test OR documented playtest) | 11 | BLOCKING |
| Visual/Feel | 0 | — |
| UI | 0 | — |
| **BLOCKING total** | **27** | |
| Manual only (`[MANUAL]`) | 2 | ADVISORY |

Scene Manager owns no presentation surface — Visual/Feel and UI counts are 0 by design (see UI Requirements section). Two ACs are `[MANUAL]` (AC-H2b, AC-H23) due to Steam Deck 1세대 hardware dependency; all others are automatable in CI. Logic AC enumeration: AC-H3a, AC-H3b, AC-H4..AC-H14, AC-H24, AC-H26, AC-H27. Integration AC enumeration (BLOCKING): AC-H1, AC-H2a, AC-H15..AC-H22, AC-H25. Integration ADVISORY: AC-H2b, AC-H23.

---

### H.1 Group 1 — Section B Invariant ACs (1:1 contract)

These three ACs fulfil the Section B "각 invariant는 Section H AC에 testable 형태로 1:1 인코딩한다" promise.

---

**AC-H1 — Checkpoint restart completes within 60 ticks (≤ 1.000 s)**
**Classification**: Integration — BLOCKING
**Covers**: B-Inv-1 · Rule 9 · D.1 · C.2.1 budget · C.3.2

- **Given** a running scene with a valid `checkpoint_anchor` node and EchoLifecycleSM in ALIVE state
- **When** EchoLifecycleSM emits `state_changed(_, &"dead")` (DYING → DEAD transition)
- **Then** `state_changed(_, &"alive")` is received by SM within ≤ 60 physics ticks from the DEAD signal tick, measured as `M + K + 1 ≤ 60`

**Test mechanism**: GUT integration test `test_restart_budget_within_60_ticks` — inject DEAD signal, advance `get_tree().physics_frame` in a loop, assert `alive_received_tick - dead_received_tick ≤ 60`. Uses mock `SceneTree.change_scene_to_packed` shim that completes in a deterministic M ticks.
**Test scope**: **contract-level** (mock shim). Validates the wiring contract (M+K+1 ≤ 60 budget arithmetic, signal ordering, phase transitions) but does NOT exercise the real Godot 4.6 `change_scene_to_packed` engine path. Real-engine path validation: AC-H23 `[MANUAL]` on Steam Deck 1세대 hardware.
**Note**: Rule 9 and E.10 present two faces of this invariant; see AC-H17 for the violation / warning face.

---

**AC-H2a — Cold boot headless smoke: first-input latency ≤ 300 s**
**Classification**: Integration — BLOCKING
**Covers**: B-Inv-2 · Rule 13 · D.4

- **Given** the game launched headless (`godot --headless`)
- **When** a scripted input injection fires at a fixed frame count after process start
- **Then** `cold_boot_elapsed_s = (t_first_input_ms - t_process_start_ms) / 1000.0 ≤ 300.0`

**Test mechanism**: Headless smoke check via `godot --headless --script tests/smoke/cold_boot_smoke.gd`; script captures `Time.get_ticks_msec()` at `SceneManager._ready()` and again at first `_input()` dispatch; asserts elapsed ≤ 300 s; exits non-zero on failure.

---

**AC-H2b — Cold boot Steam Deck 1세대 실측 ≤ 300 s** `[MANUAL]`
**Classification**: Integration — ADVISORY (hardware-dependent)
**Covers**: B-Inv-2 · Rule 13 · D.4

- **Given** the release build installed on Steam Deck 1세대 (first-gen OLED or LCD; SSD)
- **When** the game is cold-launched (not resumed)
- **Then** elapsed time from process launch to first actionable input ≤ 300 s; no Press-any-key gate appears

**Test mechanism**: Manual playtest tester starts a stopwatch at game launch, records time at first gameplay input. Log saved to `production/qa/evidence/scene-manager/steam-deck-coldboot-[YYYY-MM-DD].md`. Sign-off: QA Lead.

---

**AC-H3a — `scene_will_change` emits before `change_scene_to_packed` in same tick**
**Classification**: Logic — BLOCKING
**Covers**: B-Inv-3 · Rule 4 · D.6

- **Given** SM is IDLE
- **When** a transition is triggered (DEAD signal OR `boss_killed` signal)
- **Then** `scene_will_change` is emitted exactly once, and all subscriber handlers (`_buffer_invalidate`, `_on_scene_will_change`) complete before `change_scene_to_packed` is called within the same physics tick

**Test mechanism**: GUT unit test `test_scene_will_change_emits_before_scene_swap` — spy both `scene_will_change.emit()` call order and `SceneTree.change_scene_to_packed` call order using mocked SM; assert emit tick == swap tick and emit call-index < swap call-index.

---

**AC-H3b — ECHO `_ready()` respawn position equals last registered anchor**
**Classification**: Logic — BLOCKING
**Covers**: B-Inv-3 · Rule 8 · D.3

- **Given** the new scene contains exactly one node tagged `checkpoint_anchor` at `global_position = (Ax, Ay)`
- **When** SM completes POST-LOAD and `_register_checkpoint_anchor()` runs
- **Then** `SM._respawn_position == Vector2(Ax, Ay)` (deterministic; no RNG)

**Test mechanism**: GUT unit test `test_respawn_position_equals_anchor_global_position` — instantiate scene with known anchor position, call `_register_checkpoint_anchor()` directly, assert `_respawn_position`.

---

### H.2 Group 2 — Static / Grep ACs (forbidden writes + structural rules)

---

**AC-H4 — SM source contains zero `_tokens` write sites (D.2 grep gate)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 7 · D.2

- **Given** the file `src/core/scene_manager/scene_manager.gd` at HEAD
- **When** CI runs `grep -nE '_tokens\s*(=|\+=|-=)' src/core/scene_manager/scene_manager.gd`
- **Then** exit code 0, match count = 0

**Test mechanism**: `tools/ci/sm_static_check.sh` (pattern precedent: `pm_static_check.sh`). CI gate; any match = BLOCKING failure. Sub-check bundled in same script: `_tokens` read via property access is permitted; write site is not.

---

**AC-H5 — SM does not touch ring buffer, PM does not directly subscribe `scene_will_change`, SM does not call `EchoLifecycleSM.boot()`**
**Classification**: Logic — BLOCKING
**Covers**: Rule 5 · Rule 6 · Rule 10

- **Given** the files `src/core/scene_manager/scene_manager.gd` and `src/gameplay/player_movement.gd` at HEAD
- **When** `tools/ci/sm_static_check.sh` runs the following three grep patterns (comments stripped first per `pm_static_check.sh` precedent — `sed -E 's|#.*$||'` pipeline):
  1. `grep -nE '(_write_head|_buffer_primed|_buffer_invalidate)' src/core/scene_manager/scene_manager.gd` → 0 matches (Rule 6)
  2. `grep -nE '(\.connect\s*\(\s*&?"?scene_will_change|scene_will_change\.connect)' src/gameplay/player_movement.gd` → 0 matches (Rule 5 — targets *subscription* via `.connect(...)` only; bare-string mentions in docstrings/comments do not trip the gate)
  3. `grep -nE '\.boot\s*\(' src/core/scene_manager/scene_manager.gd` → 0 matches (Rule 10)
- **Then** all three patterns return 0 matches; any non-zero = BLOCKING CI failure

**Test mechanism**: `tools/ci/sm_static_check.sh` (extend `pm_static_check.sh` precedent). All three grep checks run in sequence; script exits non-zero on first failure.

---

**AC-H6 — `add_to_group(&"scene_manager")` is present in SM source (Rule 1 presence)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 1

- **Given** `src/core/scene_manager/scene_manager.gd` at HEAD
- **When** `grep -n 'add_to_group.*scene_manager' src/core/scene_manager/scene_manager.gd` runs
- **Then** match count ≥ 1; zero matches = BLOCKING failure

**Test mechanism**: `tools/ci/sm_static_check.sh`. Note — grep verifies *presence* only; first-line ordering is verified by code review checklist (see Untestable Surface note H.U1).

---

**AC-H7 — SM declares no `_process` or `_physics_process` override**
**Classification**: Logic — BLOCKING
**Covers**: Rule 2

- **Given** `src/core/scene_manager/scene_manager.gd` at HEAD
- **When** `grep -nE 'func (_process|_physics_process)' src/core/scene_manager/scene_manager.gd` runs
- **Then** match count = 0; any match = BLOCKING failure

**Test mechanism**: `tools/ci/sm_static_check.sh`.

---

### H.3 Group 3 — Lifecycle & Formula ACs

---

**AC-H8 — `scene_will_change` emits exactly once per transition, zero times during IDLE (D.6 cardinality)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 4 · D.6

- **Given** SM is IDLE with a counter subscribed to `scene_will_change`
- **When** one complete lifecycle pass is triggered (IDLE → PRE_EMIT → SWAPPING → POST_LOAD → READY → IDLE)
- **Then** counter == 1 at READY entry; counter remains 1 after N idle ticks with no transition triggered

**Test mechanism**: GUT unit test `test_scene_will_change_cardinality_one_per_transition` (counter subscriber) + `test_scene_will_change_zero_during_idle` (N ticks, no trigger). Both must pass.

---

**AC-H9 — Multiple checkpoint anchors triggers push_warning and uses last anchor (D.3 N>1)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 8 · D.3

- **Given** a scene with N=2 checkpoint anchors at positions A=(100, 200) and B=(300, 400) in scene-tree order
- **When** SM's `_register_checkpoint_anchor()` runs after `_ready()` chain completes
- **Then** `SM._respawn_position == Vector2(300, 400)` (last = anchors[N-1]) AND `push_warning` was called with message containing "Multiple checkpoint anchors"

**Test mechanism**: GUT unit test `test_multiple_anchors_uses_last_and_warns`.

---

**AC-H10 — N=0 anchors triggers push_error and uses fallback player position (E.2)**
**Classification**: Logic — BLOCKING
**Covers**: E.2 · D.3 (N=0 branch)

- **Given** a scene with zero nodes tagged `checkpoint_anchor`
- **When** SM's `_register_checkpoint_anchor()` runs after `_ready()` chain completes
- **Then** `push_error` is called with message containing "no checkpoint anchor" AND `SM._respawn_position == player.global_position` (last known position fallback)

**Test mechanism**: GUT unit test `test_zero_anchors_pushes_error_and_falls_back`.

---

**AC-H11 — `boss_killed_seen` short-circuits `dead_seen` in same-tick collision (D.5)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 12 · D.5 · C.3.3

- **Given** SM is IDLE
- **When** `_on_boss_killed()` and `_on_state_changed(_, &"dead")` both fire within the same physics tick (any order)
- **Then** `SM._boundary_state == BoundaryState.CLEAR_PENDING` and the `state_changed(&"dead")` handler returns without triggering RESTART_PENDING

**Test mechanism**: GUT unit test `test_boss_killed_wins_over_dead_same_tick` — call both handlers in sequence (dead-first and boss-first variants), assert final boundary state is CLEAR_PENDING both times.

---

**AC-H12 — No-op guard: same-scene non-restart call returns early with push_warning (Rule 14)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 14

- **Given** SM has a current scene loaded (PackedScene ref `S`)
- **When** `SceneManager.change_scene_to_packed(S, TransitionIntent.STAGE_CLEAR)` is called (or any non-CHECKPOINT_RESTART intent against same scene)
- **Then** `push_warning` fires, no `scene_will_change` is emitted, no scene swap occurs

**Test mechanism**: GUT unit test `test_same_scene_non_restart_noop_and_warns` — assert emit counter = 0 and swap not called. Verifies both `TransitionIntent.STAGE_CLEAR` and `TransitionIntent.COLD_BOOT` non-restart variants short-circuit.

---

**AC-H13 — Same-scene checkpoint restart intent bypasses no-op guard**
**Classification**: Logic — BLOCKING
**Covers**: Rule 14 (intent enum pass-through)

- **Given** SM has current scene `S` loaded
- **When** `SceneManager.change_scene_to_packed(S, TransitionIntent.CHECKPOINT_RESTART)` is called
- **Then** lifecycle proceeds normally (PRE_EMIT → SWAPPING) without early-return

**Test mechanism**: GUT unit test `test_same_scene_checkpoint_restart_proceeds`.

---

**AC-H14 — `change_scene_to_packed(null)` triggers panic state, no scene swap (E.1)**
**Classification**: Logic — BLOCKING
**Covers**: E.1

- **Given** SM is IDLE
- **When** `change_scene_to_packed(null)` is called (or triggered by `null` PackedScene reference)
- **Then** `push_error` fires with "null PackedScene", `_phase` remains IDLE, `_boundary_state == BoundaryState.PANIC` (D.5 5th enum value — distinguishes panic entry from any other IDLE state), and no `scene_will_change` is emitted

**Test mechanism**: GUT unit test `test_null_packed_scene_panics_no_emit` — assert all four post-conditions (push_error message, `_phase == Phase.IDLE`, `_boundary_state == BoundaryState.PANIC`, emit counter == 0). Pairs with AC-H26 (terminality after entry — this AC covers entry; AC-H26 covers post-entry signal suppression).

---

### H.4 Group 4 — Cascade / Integration ACs

---

**AC-H15 — Full DEAD→ALIVE cascade clears PM 8-var ephemeral state (Rule 5 cascade)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 5 · C.3.2

- **Given** PlayerMovement has non-zero values in all 8 ephemeral vars (4 coyote/buffer + 4 facing Schmitt flags)
- **When** SM triggers a full checkpoint restart lifecycle (DEAD → SWAPPING → READY)
- **Then** all 8 PM ephemeral vars == 0/false at READY phase entry (verified via EchoLifecycleSM O6 cascade → `_clear_ephemeral_state()`)

**Test mechanism**: GUT integration test `test_restart_clears_pm_8var_ephemeral_state` — instantiate SM + EchoLifecycleSM + PM mock; trigger DEAD; advance frames to READY; assert all 8 vars reset. Uses dependency-injected PM stub.

---

**AC-H16 — TRC `_buffer_invalidate()` called on `scene_will_change`; `_tokens` unchanged (Rule 6/7)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 6 · Rule 7 · D.2

- **Given** TRC has `_tokens = 3`, `_buffer_primed = true`, `_write_head = 5`
- **When** SM emits `scene_will_change()`
- **Then** TRC `_buffer_primed == false` AND `_write_head == 0` AND `_tokens == 3` (unchanged)

**Test mechanism**: GUT integration test `test_scene_will_change_invalidates_buffer_preserves_tokens`.

---

**AC-H17 — Budget overrun fires push_warning and game continues (E.10, Rule 9 violation face)**
**Classification**: Integration — BLOCKING
**Covers**: E.10 · Rule 9 (violation branch)

- **Given** SM is configured with `debug_simulate_budget_overrun = true` (forces M+K+1 > 60 via mock shim deterministic latency injection — see G.3; distinct from `debug_simulate_load_failure` which forces panic)
- **When** a checkpoint restart is triggered
- **Then** `push_warning` fires with message containing "Restart budget exceeded" and game continues (READY phase is eventually reached, no hard freeze)

**Test mechanism**: GUT integration test `test_budget_exceeded_warns_and_continues` — set `debug_simulate_budget_overrun = true`, trigger restart, advance frames past 60, assert warning fired and READY eventually reached. **Flag scope note**: `debug_simulate_budget_overrun` (this AC) and `debug_simulate_load_failure` (AC-H14 panic path) are mutually exclusive debug paths — see G.3. **Harness reuse note**: AC-H1 (contract-level mock shim, M-tick normal path) and this AC share the same mock `SceneTree.change_scene_to_packed` infrastructure parameterized by `latency_ticks: int` (AC-H1 default = M; this AC = **61**, chosen M/K-independent to guarantee `latency_ticks + K + 1 > 60` regardless of actual Godot 4.6 M/K values — `M+K+2` was rejected in RR6 as it yields 57 ticks at worked-example M=30/K=12, below the 60-tick ceiling). Consolidating reduces test rig duplication.

---

**AC-H18 — `boss_killed` signal triggers CLEAR_PENDING and stage clear lifecycle (Rule 12)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 12 · C.3.3

- **Given** SM is IDLE (mirror AC-H11 — handler is state-agnostic; `_on_boss_killed` unconditionally sets `_boundary_state = CLEAR_PENDING` per C.3.3 pattern regardless of prior boundary state. RR6 dropped earlier "in ACTIVE boundary state" qualifier — Tier 1 never enters ACTIVE without Stage #12 per C.2.2; see C.2.4 Tier 1 boundary state evolution note)
- **When** `boss_killed(&"boss_0")` signal fires
- **Then** `SM._boundary_state == CLEAR_PENDING` AND lifecycle proceeds through PRE_EMIT → `change_scene_to_packed(victory_screen_packed)` → SWAPPING

**Test mechanism**: GUT integration test `test_boss_killed_triggers_clear_pending_and_swap`.

---

**AC-H19 — `boss_killed` during active transition is ignored with push_warning (E.4)**
**Classification**: Integration — BLOCKING
**Covers**: E.4

- **Given** SM is in SWAPPING phase (lifecycle in progress)
- **When** `boss_killed(&"boss_0")` fires
- **Then** `push_warning` fires with message containing "boss_killed during transition — ignored"; `_boundary_state` does not change; lifecycle does not restart

**Test mechanism**: GUT integration test `test_boss_killed_during_transition_ignored`.

---

**AC-H20 — `state_changed(_, &"dead")` during active transition is ignored (E.5)**
**Classification**: Integration — BLOCKING
**Covers**: E.5

- **Given** SM is in SWAPPING phase
- **When** `state_changed(_, &"dead")` fires
- **Then** handler returns without changing `_boundary_state` or triggering a new lifecycle pass

**Test mechanism**: GUT integration test `test_dead_signal_during_transition_ignored`.

---

**AC-H21 — Non-player objects reset via scene swap; SM does not call direct reset on individual nodes (Rule 11)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 11

- **Given** a scene with enemy node E at non-origin position, SM in ACTIVE state
- **When** SM executes a checkpoint restart (`change_scene_to_packed` with same scene)
- **Then** enemy E is unloaded by scene swap and new instance starts at scene-default position; SM never calls any method directly on E before swap

**Test mechanism**: GUT integration test `test_non_player_reset_via_scene_swap_not_direct_call` — spy on enemy node methods; assert zero direct SM-→-E calls during restart.

---

**AC-H22 — Cold boot completes with no Press-any-key gate (Rule 13 / Pillar 4)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 13 · D.4 (structural gate, complements AC-H2a/b)

- **Given** the headless boot smoke test sequence (AC-H2a setup)
- **When** the scripted input fires immediately after EchoLifecycleSM ALIVE emit (no hold)
- **Then** the input event is consumed and gameplay proceeds; no "press any key" node exists in the scene tree at first input time

**Test mechanism**: Headless smoke — `godot --headless --script tests/smoke/cold_boot_smoke.gd`; after ALIVE state, search scene tree for any node with "press_any_key" or "any_key" in name/class; assert none found.

---

**AC-H23 — Checkpoint restart on Steam Deck 1세대 completes within 1.000 s wall-clock** `[MANUAL]`
**Classification**: Integration — ADVISORY (hardware-dependent)
**Covers**: B-Inv-1 · Rule 9 · D.1 (real-hardware confirmation of AC-H1)

- **Given** release build running on Steam Deck 1세대 with Tier 1 stage_1 scene
- **When** ECHO death is triggered (falls to hazard or enemy projectile)
- **Then** ECHO is alive and input-responsive within ≤ 1.000 s wall-clock, measured with phone stopwatch across 5 repeated deaths

**Test mechanism**: `[MANUAL]` playtest session. Log: `production/qa/evidence/scene-manager/steam-deck-restart-[YYYY-MM-DD].md`. Must record: 5× measured times, all ≤ 1.000 s. Sign-off: QA Lead.
**Test scope**: **real-engine path** on Steam Deck 1세대 hardware. Complements AC-H1's contract-level gate by validating the actual Godot 4.6 `change_scene_to_packed` tick consumption on target hardware. AC-H1 (contract) and AC-H23 (real path) together cover both faces of Rule 9 — AC-H1 catches wiring regressions in CI; AC-H23 catches engine/asset-budget regressions that only manifest on real hardware.

---

**AC-H24 — Only `change_scene_to_packed` (sync) is used for scene transitions; no async APIs present (Rule 3)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 3

- **Given** `src/core/scene_manager/scene_manager.gd` at HEAD
- **When** `grep -nE '(change_scene_to_file|load_threaded_request|load_threaded_get|await)' src/core/scene_manager/scene_manager.gd` runs
- **Then** match count = 0; any match = BLOCKING CI failure (Tier 1 async API forbidden)

**Test mechanism**: `tools/ci/sm_static_check.sh`.

---

**AC-H25 — EchoLifecycleSM self-boots via `_ready()`; SM does not wire any boot call (Rule 10, integration)**
**Classification**: Integration — BLOCKING
**Covers**: Rule 10 · C.3.2 T+M+K row

- **Given** SM triggers a checkpoint restart (DEAD → SWAPPING → POST-LOAD)
- **When** the new scene's `_ready()` chain completes
- **Then** EchoLifecycleSM reaches ALIVE state without any direct `boot()` call from SM (verified by absence of `boot()` invocation in SM's call log during POST-LOAD phase)

**Test mechanism**: GUT integration test `test_echo_lifecycle_sm_self_boots_no_sm_call` — spy on EchoLifecycleSM; assert SM issues zero `boot()` calls; assert EchoLifecycleSM reaches ALIVE within POST-LOAD + READY phases.

---

**AC-H26 — Panic state is terminal: subsequent signals do not trigger lifecycle (E.1 terminality)**
**Classification**: Logic — BLOCKING
**Covers**: E.1 (PANIC terminality clause) · D.5 (PANIC bypass) · Rule 4 (no spurious emit)

- **Given** SM has entered `_boundary_state == BoundaryState.PANIC` via the E.1 null-PackedScene path (`_phase == IDLE` held)
- **When** `_on_boss_killed(&"boss_0")` and `_on_state_changed(_, &"dead")` are each invoked (separately, then in the same tick) with a spy attached to `_trigger_transition`
- **Then** `_trigger_transition` is **never** called; `_boundary_state` remains `PANIC` (not overwritten to CLEAR_PENDING or RESTART_PENDING); `scene_will_change` emit counter remains 0

**Test mechanism**: GUT unit test `test_panic_state_is_terminal_no_further_transition` — set `_boundary_state = BoundaryState.PANIC` directly; install spy on `_trigger_transition` + counter subscriber on `scene_will_change`; call each handler in 3 orderings (boss_killed alone, dead alone, both same tick); assert spy call_count == 0 AND `_boundary_state == BoundaryState.PANIC` AND emit counter == 0 in all 3 cases.

---

**AC-H27 — `SceneTree.change_scene_to_packed` is called exactly once per transition (D.6 symmetric cardinality)**
**Classification**: Logic — BLOCKING
**Covers**: Rule 4 · D.6 (symmetric to scene_will_change emit cardinality)

- **Given** SM is IDLE with a mock `SceneTree.change_scene_to_packed` that records every call
- **When** one complete lifecycle pass is triggered (any of: DEAD signal, `boss_killed`, cold-boot first input)
- **Then** the mock swap-call counter == 1 at READY entry; counter remains 1 after N idle ticks with no further trigger

**Test mechanism**: GUT unit test `test_change_scene_to_packed_cardinality_one_per_transition` — install mock shim with counter; trigger each of 3 entry paths (DEAD, boss_killed, cold-boot first input via input.md router) in separate test cases; assert counter == 1 after each. Pairs with AC-H8 (scene_will_change emit cardinality) to close both faces of D.6.

---

### H.5 Coverage Summary Table

| AC | B-Inv | C Rules | D Formula | E Edge |
|---|---|---|---|---|
| AC-H1 | B-Inv-1 | Rule 9 | D.1 | — |
| AC-H2a | B-Inv-2 | Rule 13 | D.4 | — |
| AC-H2b `[M]` | B-Inv-2 | Rule 13 | D.4 | — |
| AC-H3a | B-Inv-3 | Rule 4 | D.6 | — |
| AC-H3b | B-Inv-3 | Rule 8 | D.3 | — |
| AC-H4 | — | Rule 7 | D.2 | — |
| AC-H5 | — | Rule 5, Rule 6, Rule 10 | — | — |
| AC-H6 | — | Rule 1 | — | — |
| AC-H7 | — | Rule 2 | — | — |
| AC-H8 | — | Rule 4 | D.6 | — |
| AC-H9 | — | Rule 8 | D.3 | — |
| AC-H10 | — | — | D.3 (N=0) | E.2 |
| AC-H11 | — | Rule 12 | D.5 | — |
| AC-H12 | — | Rule 14 | — | — |
| AC-H13 | — | Rule 14 | — | — |
| AC-H14 | — | — | D.5 (PANIC entry) | E.1 |
| AC-H15 | — | Rule 5 | — | — |
| AC-H16 | — | Rule 6, Rule 7 | D.2 | — |
| AC-H17 | — | Rule 9 | D.1 | E.10 |
| AC-H18 | — | Rule 12 | — | — |
| AC-H19 | — | — | — | E.4 |
| AC-H20 | — | — | — | E.5 |
| AC-H21 | — | Rule 11 | — | — |
| AC-H22 | — | Rule 13 | D.4 | — |
| AC-H23 `[M]` | B-Inv-1 | Rule 9 | D.1 | — |
| AC-H24 | — | Rule 3 | — | — |
| AC-H25 | — | Rule 10 | — | — |
| AC-H26 | — | Rule 4 (no spurious emit during PANIC) | D.5 (PANIC bypass) | E.1 (terminality) |
| AC-H27 | — | Rule 4 (swap-call cardinality symmetric to emit) | D.6 (swap-call face) | — |

**Section B Invariant coverage check**: B-Inv-1 → AC-H1, AC-H23; B-Inv-2 → AC-H2a, AC-H2b; B-Inv-3 → AC-H3a, AC-H3b. All 3 invariants covered. ✅

**Rule coverage check**:

| Rule | AC(s) |
|---|---|
| Rule 1 | AC-H6 |
| Rule 2 | AC-H7 |
| Rule 3 | AC-H24 |
| Rule 4 | AC-H3a, AC-H8, AC-H26 (panic-state no-emit guard), AC-H27 (symmetric swap-call cardinality) |
| Rule 5 | AC-H5, AC-H15 |
| Rule 6 | AC-H5, AC-H16 |
| Rule 7 | AC-H4, AC-H16 |
| Rule 8 | AC-H3b, AC-H9 |
| Rule 9 | AC-H1, AC-H17, AC-H23 |
| Rule 10 | AC-H5, AC-H25 |
| Rule 11 | AC-H21 |
| Rule 12 | AC-H11, AC-H18 |
| Rule 13 | AC-H2a, AC-H2b, AC-H22 |
| Rule 14 | AC-H12, AC-H13 |

All 14 rules covered. ✅

**Formula coverage check**:

| Formula | AC(s) |
|---|---|
| D.1 | AC-H1, AC-H17, AC-H23 |
| D.2 | AC-H4, AC-H16 |
| D.3 | AC-H3b, AC-H9, AC-H10 |
| D.4 | AC-H2a, AC-H2b, AC-H22 |
| D.5 | AC-H11, AC-H14 (PANIC entry), AC-H26 (PANIC bypass / terminality) |
| D.6 | AC-H3a, AC-H8 (emit face), AC-H27 (swap-call face) |

All 6 formulas covered. ✅

**Edge case coverage check**:

| Edge | AC | Status |
|---|---|---|
| E.1 null PackedScene | AC-H14 (panic entry) + AC-H26 (panic terminality) | Covered |
| E.2 N=0 anchors | AC-H10 | Covered |
| E.3 OOM | — | Deferred — see H.U2 |
| E.4 boss_killed during transition | AC-H19 | Covered |
| E.5 dead during transition | AC-H20 | Covered |
| E.6 first input before EchoLifecycleSM boot | — | Deferred to input.md C.5 (router owner); not SM AC scope |
| E.7 cold boot Esc/Pause input | — | Deferred to input.md C.5 (router owner per GDD E.7 text) |
| E.8 scene file missing | — | Deferred — covered by build-time validation; same code path as E.1 at runtime |
| E.9 save file invalid | — | Deferred to Tier 2 / Save Persistence #21 (Tier 1 has no persistence) |
| E.10 budget exceeded | AC-H17 | Covered |

---

### H.6 Untestable / Surfaced Items

**H.U1 — Rule 1: first-line ordering of `add_to_group` (partially untestable by grep)**

The AC-H6 grep verifies *presence* of `add_to_group(&"scene_manager")` in SM source, but cannot verify it is the *first executable statement* in `_ready()`. GDScript has no AST lint tool in CI at this project's current tooling.

**Workaround**: Add a manual code-review checklist item: "Verify `add_to_group(&"scene_manager")` is the first non-comment line inside `SceneManager._ready()` before any other initialization call." This checklist runs as part of the PR review gate, not CI. Classify as advisory review item.

---

**H.U2 — E.3 OOM: cannot trigger deterministically in CI**

OOM during `change_scene_to_packed` cannot be reproduced deterministically in headless CI without a real asset set approaching the 1.5 GB ceiling — which does not exist in Tier 1 scope.

**Workaround**: Deferred to Tier 2 gate. When Tier 2 collage texture pipeline is introduced (Collage Rendering #15), a stress test on Steam Deck low-memory mode (4 GB RAM device) should be added as a `[MANUAL]` AC. Document in F.4.2 Collage Rendering #15 obligation.

---

**H.U3 — Rule 9 / E.10 contract tension (non-blocking design ambiguity, surfaced)**

Rule 9 says ≤ 60-tick budget is "비협상" (non-negotiable), but E.10 says a violation produces `push_warning` and the game continues rather than hard-blocking. These are not contradictory: Rule 9 is the *design contract* (must not be violated under nominal conditions), and E.10 is the *runtime safety valve* (if violated, don't crash — log and continue). AC-H1 covers the nominal path (assert ≤ 60); AC-H17 covers the violation path (assert warning fires + game continues). Both must pass independently. If AC-H1 fails in CI, it is a BLOCKING defect regardless of AC-H17 passing.

## Open Questions

본 GDD 작성 (Session 19, 2026-05-11) 시점에 carried over한 3개 OQ (OQ-4 / OQ-PM-1 / OQ-SM-2)는 모두 C.1 Rules 4 / 5 / 10에서 인코딩되어 **resolved** 상태다. 본 섹션은 본 GDD 작성 중 새로 surfaced한 deferred items + Tier 2 revision triggers를 단일 출처로 보유한다.

| ID | Question | Closure Owner | Closure Trigger | Severity | Tier 1 임시 처리 |
|---|---|---|---|---|---|
| ~~**OQ-SM-A1**~~ ✅ **Resolved 2026-05-12 (Camera #3 first-use)** | ~~POST-LOAD phase 시그널 노출 — `scene_post_loaded(anchor: Vector2)` 시그널 추가 시점~~ → **Resolved**: signal added 2026-05-12 with 2-arg signature `scene_post_loaded(anchor: Vector2, limits: Rect2)` (Camera #3 GDD authoring + Approved RR1 PASS). C.2.1 POST-LOAD body emit + C.3.1 SM emits matrix entry + C.3.4 Q2 closure section. F.4.2 row Camera #3 status: Active. | (Closed) | (Closed) | — | — |
| **OQ-SM-A2** | 인플레이스 체크포인트 reset 패턴 (씬 교체 없이 적/발사체 리셋) — Tier 2 메모리 효율 향상 시 도입 | Stage / Encounter #12 GDD (Tier 2) | Tier 2 gate 통과 + 메모리 측정 결과 1.5 GB ceiling 압박 시 | MEDIUM (Tier 2) | Tier 1: Rule 11 "씬 교체가 리셋을 처리한다" 가정 유효 — 단일 스테이지 슬라이스 |
| **OQ-SM-A3** | Async load (`ResourceLoader.load_threaded_request`) 도입 시 D.1 60-tick budget formula 개정 | 본 GDD revision (Tier 2 게이트) | Tier 2 진입 + 비동기 로드 도입 결정 | MEDIUM (Tier 2) | Tier 1: Rule 3 (sync only) 유효; Steam Deck 1세대 실측에서 60-tick 위반 일관 발생 시 조기 이월 |
| **OQ-SM-A4** | Memory 명시 해제 (`ResourceLoader.load` 캐시 해제) — Tier 3 5 stage × 300MB 콜라주 텍스처 대응 | Collage Rendering #15 GDD (Tier 2 게이트) | Tier 2 진입 + 콜라주 텍스처 메모리 실측 | MEDIUM (Tier 2/3) | Tier 1: 단일 스테이지에서 메모리 명시 해제 불필요 |
| **OQ-SM-A5** | Multi-anchor checkpoint 패턴 — Tier 2 mid-stage checkpoint 도입 시 N>1 anchor 정상 패턴 지원 | Stage / Encounter #12 GDD (Tier 2) | Tier 2 진입 + 다중 anchor 사용 사례 발생 | LOW (Tier 2) | Tier 1: D.3 `push_warning` 정책 유효; `multiple_anchors_warning_n` knob 상향 권장 |

**Resolved this session (Session 19)**:

| OQ | Resolution | 인코딩 위치 |
|---|---|---|
| **OQ-4** (carried from TR #9) | `scene_will_change()` emit 타이밍 = `change_scene_to_packed` 호출 직전 동일 틱 (sync emit). 토큰은 항상 보존. | C.1 Rule 4 + Rule 7 |
| **OQ-PM-1** (carried from PM #6) | PM은 `scene_will_change` 직접 구독 안 함; EchoLifecycleSM O6 cascade를 통한 PM `_clear_ephemeral_state()` 호출이 단일 경로 | C.1 Rule 5 |
| **OQ-SM-2** (carried from SM #5) | SM은 `EchoLifecycleSM.boot()`를 직접 호출하지 않음; EchoLifecycleSM이 자체 `_ready()`에서 부트 (씬 트리 자연 부트) | C.1 Rule 10 |
| Q2 (Session 19 surfaced) | POST-LOAD 시그널 노출 deferred — Camera #3 / Stage #12 / HUD #13 첫 사용 사례 발생 시 본 GDD revision | C.3.4 + OQ-SM-A1 |

---

## Z. Appendix (References)

### A.1 Locked Decisions (Session 19, 2026-05-11)

| ID | Decision | Rationale | Cross-ref |
|---|---|---|---|
| **DEC-SM-1** | SM은 오토로드 싱글턴; `_physics_process` / `_process` 미사용 | ADR-0003 priority ladder는 씬 노드 대상; SM은 시그널 producer | C.1 Rule 2 |
| **DEC-SM-2** | Tier 1 = `change_scene_to_packed` (sync) only; async + memory release Tier 2 | Pillar 5 + Anti-Pillar #2; 단일 스테이지 슬라이스 | C.1 Rule 3 |
| **DEC-SM-3** | `scene_will_change()` emit 타이밍 = `change_scene_to_packed` 호출 직전 동일 틱 | OQ-4 closure; E-16 invalid-coord 텔레포트 방지 | C.1 Rule 4 |
| **DEC-SM-4** | PM은 `scene_will_change` 직접 구독 안 함; EchoLifecycleSM O6 cascade 단일 경로 | OQ-PM-1 closure; single-layer cascade design | C.1 Rule 5 |
| **DEC-SM-5** | EchoLifecycleSM 자체 `_ready()` 부트 (SM이 `boot()` 호출 안 함) | OQ-SM-2 closure; state-machine.md C.2.1 lock-in 유지 | C.1 Rule 10 |
| **DEC-SM-6** | `boss_killed` 신호 이름 채택 (`boss_defeated` 거부) | damage.md F.4 LOCKED 9-signal contract + AC-13 BLOCKING이 single-source | C.1 Rule 12 + C.3.5 housekeeping batch |
| **DEC-SM-7** | 같은-틱 `boss_killed` + `state_changed(_, &"dead")` → **CLEAR_PENDING 우선** | Pillar 1 — Defiant Loop 학습 모델이 same-tick corner case에 흔들리지 않음 | C.3.3 + D.5 |
| **DEC-SM-8** | 5-phase linear lifecycle (IDLE/PRE-EMIT/SWAPPING/POST-LOAD/READY) 구현은 `enum Phase` + `match` (state-machine.md 프레임워크 미사용) | 단일 인스턴스 autoload + 5-phase 선형 + 동시 리액션 없음 — 프레임워크 오버헤드 미정당 | C.2.3 |
| **DEC-SM-9** | POST-LOAD 시그널 노출 — **resolved 2026-05-12 (Camera #3 first-use)**: `scene_post_loaded(anchor: Vector2, limits: Rect2)` 2-arg signal active, Camera #3 first consumer, signature locked at architecture.yaml `interfaces.scene_lifecycle`. Stage #12 / HUD #13 (Tier 2)는 동일 signal 재사용 (signature 비변경) | Q2 closure via Camera #3 Approved RR1 PASS 2026-05-12 — was YAGNI deferred while all dependents Not Started; Camera #3 became first dependent → revision applied | C.3.4 + OQ-SM-A1 (resolved) |
| **DEC-SM-10** | Tier 2 revision triggers 사전 등록 — Rule 3 async load, Rule 11 in-place reset, OQ-SM-A2/A3/A4/A5 | Tier 1 commitment 보호 + Tier 2 게이트에 대비된 revision surface 명시 | C.1 Rules 3/11 + OQ section |

### A.2 Cross-doc Citations

| Cited GDD / Doc | Citation Location | Reason |
|---|---|---|
| `design/gdd/game-concept.md` | A · B · C.1 R3/R9/R13 · D.1/D.4 · G.1 | Pillar 1/2/4/5 lock |
| `design/gdd/state-machine.md` | C.1 R1/R5/R10 · C.3.2 · F.1 row #5 · F.3 · G.1 group name | EchoLifecycleSM O6 cascade owner; group discovery contract; SM framework 미사용 정당화 |
| `design/gdd/time-rewind.md` | C.1 R6/R7 · C.3.2 · C.3.5 · F.1 row #9 · F.3 · F.4.1 | TRC `_buffer_invalidate()` 단일 소유; `_tokens` 보존; OQ-4 closure |
| `design/gdd/damage.md` | C.1 R12 · C.3.3 · C.3.5 · F.1 row #8 · F.3 · F.4.1 | `boss_killed` F.4 9-signal contract single-source authority + AC-13 BLOCKING |
| `design/gdd/player-movement.md` | C.1 R5 · F.1 row #6 · F.3 · F.4.1 | PM 8-var ephemeral state F.4.2 row #2 obligation; OQ-PM-1 closure |
| `design/gdd/input.md` | C.1 R13 · E.6/E.7 · F.3 | input.md C.5 router owner for cold-boot game-start trigger |
| `docs/architecture/adr-0001-time-rewind-scope.md` | C.1 R11 · F.1 row #9 | Player-only rewind scope; SM이 비-플레이어 reset 소유 |
| `docs/architecture/adr-0002-time-rewind-storage-format.md` | C.1 R6/R7 · D.2 · G.1 | PlayerSnapshot 9-field ring buffer; SM은 ring buffer 미접촉 |
| `docs/architecture/adr-0003-determinism-strategy.md` | C.1 R2/R10 · C.3.3 · D.5 · F.1 row #5 | process_physics_priority 사다리; same-tick 시그널 처리 순서 |
| `docs/registry/architecture.yaml` | C.3.5 · F.4.1 | F.4.1 new entries 4종 (scene_lifecycle / scene_phase / 2 api_decisions) |
| `design/registry/entities.yaml` | C.3.5 · F.4.1 | F.4.1 new constants 2종 (restart_window_max_frames=60 / cold_boot_max_seconds=300) |

### A.3 Reference Games / External Tech Refs

본 GDD는 Foundation/Infrastructure 시스템이므로 reference game 직접 인용 없음. Pillar 1/4 인용은 game-concept.md를 통해 간접적으로 reference games (Hotline Miami < 1초 재시작, Katana Zero 즉시 재시작) 영향 반영.

| Tech Ref | Location | Reason |
|---|---|---|
| Godot 4.6 SceneTree API | C.1 R2/R3 · C.2.1 · D.1 · E.3 | `change_scene_to_packed` / `process_frame` one-shot connect / autoload subsystem |
| Godot 4.6 Time API | D.4 | `Time.get_ticks_msec()` cold boot 측정 |
| GUT (Godot Unit Test) | H section | 통합 테스트 프레임워크 (project standard per coding-standards.md) |
| `tools/ci/pm_static_check.sh` 선례 | H.2 + D.2 | Static grep CI gate 패턴 — `tools/ci/sm_static_check.sh` 신규 작성 의무 |

### A.4 Specialist Consult Log

| Specialist | Session 19 Role | Output |
|---|---|---|
| **creative-director** | Section B framing | 3 candidate framings (Pointer / Invariant frame / Claim < 1초 ownership); recommended Candidate B (Invariant frame parallel to state-machine.md). User accepted. |
| **systems-designer** (1) | Section C.1 Core Rules draft | 14 numbered rules with rationale; resolved 3 carried OQs (OQ-4 / OQ-PM-1 / OQ-SM-2); flagged `boss_killed` vs `boss_defeated` cross-doc drift |
| **systems-designer** (2) | Section C.2 adversarial review | Surfaced Q1 tick-arithmetic co-tick fix (PRE-EMIT not additive) + Q2 POST-LOAD observability gap (deferred to C.3.4) |
| **qa-lead** | Section H Acceptance Criteria draft | **Original Session 19 draft**: 25 ACs (12 Logic + 11 Integration + 2 `[MANUAL]`); 23 BLOCKING / 2 ADVISORY. **Post-RR cumulative HEAD state (canonical — see H.0 preamble)**: 29 ACs / 27 BLOCKING / 2 ADVISORY (16 Logic + 11 Integration BLOCKING + 2 ADVISORY) — additions: AC-H26 PANIC terminality (RR2), AC-H14 PANIC entry post-condition (RR3 enhancement, not new AC), AC-H27 swap-call cardinality (RR4). B-Inv-1/2/3 1:1 covered; all 14 Rules + 6 Formulas covered; H.U1–H.U3 untestable surfaced. **Note**: qa-lead wrote H directly to file violating Draft→Approval→Write protocol; user reviewed post-hoc and accepted content. **Guardrail for future authoring sessions**: agents must surface a user-visible draft and obtain explicit approval before any Write/Edit, regardless of section size or perceived quality. H's content quality is **not** a precedent for skipping protocol — see `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`. |

### A.5 Tier 2 Revision Triggers (pre-registered)

본 GDD가 Tier 2 게이트 통과 시 본 표의 트리거 조건에 따라 개정이 필요한 항목 사전 등록:

| Trigger | 본 GDD 개정 부위 | Owner GDD (closure) |
|---|---|---|
| 다중 스테이지(≥ 2 stages) 도입 | C.1 Rule 3 — async load + 메모리 명시 해제 허용 | 본 GDD (Tier 2 revision) |
| 인플레이스 체크포인트 패턴 (씬 교체 없이 리셋) | C.1 Rule 11 — 그룹별 reset cascade 명시 | Stage / Encounter #12 GDD |
| `scene_post_loaded` 첫 사용 사례 발생 | C.2.1 POST-LOAD 시그널 노출 추가 (Q2 closure) | Camera #3 OR Stage #12 GDD |
| `boss_killed` → 다음 스테이지 PackedScene 라우팅 | C.3.3 victory_screen → next_stage 동적 lookup | Stage #12 GDD |
| 메모리 1.5 GB ceiling 75% 도달 | E.3 — `OS.get_static_memory_usage()` 모니터링 + push_warning | Collage Rendering #15 GDD |
| Steam Deck 1세대 실측 60-tick 일관 위반 | D.1 worked example 실측치 업데이트 + 필요 시 async load 조기 이월 | 본 GDD (Tier 1 Week 1 playtest 결과) |

### A.6 Session 19 Status Header Update Queue (Phase 5d 적용)

본 GDD가 Designed 상태 도달 후 systems-index.md Row #2 status를 다음과 같이 업데이트한다:

- Status: **In Design (Session 19, A+B+C 완료)** → **Designed (Session 19 — All 11 sections + Appendix 완료)**
- Design Doc: `[scene-manager.md](scene-manager.md)` 링크 유지
- Depends On: `—` (Foundation; no upstream)
- Last Updated narrative: "Session 19 GDD authoring complete — **original 25 ACs** (23 BLOCKING / 2 ADVISORY); **post-RR cumulative HEAD state: 29 ACs / 27 BLOCKING / 2 ADVISORY** (RR2 added AC-H26 PANIC terminality; RR3 enhanced AC-H14 with PANIC entry post-condition; RR4 added AC-H27 swap-call cardinality). 3 carried OQs resolved (OQ-4 / OQ-PM-1 / OQ-SM-2), 5 new SM-specific OQs registered (Tier 2 deferred), cross-doc drift `boss_defeated → boss_killed` follow-up housekeeping batch queued."
- Progress Tracker: Designed 5 → 5 (no change yet — pending fresh-session `/design-review`); Designed (pending re-review) 0 → 1 if user wants intermediate state, otherwise hold.
