# Camera System

> **Status**: Approved · 2026-05-12 · RR1 PASS — see design/gdd/reviews/camera-review-log.md for full history.
> **System**: #3 — Core layer, MVP priority
> **Author**: solo dev + game-designer / ux-designer / gameplay-programmer / systems-designer / qa-lead / art-director / creative-director (inline consults)
> **Last Updated**: 2026-05-12 — see design/gdd/reviews/camera-review-log.md for full history.
> **Implements Pillars**: Pillar 3 (콜라주 first impression — screenshot composition) · Pillar 1 (sub-second checkpoint restart — snap-no-cut) · Pillar 2 (determinism — shake RNG seeded, no smoothing residual across rewind)
> **Depends on**: Scene Manager #2 (Approved RR7 PASS 2026-05-11) — triggers Q2 deferred signal addition `scene_post_loaded(anchor: Vector2)` to scene-manager.md C.2.1 (Phase 5 cross-doc batch — this GDD is the first-use case per Session 19 design call)
> **Engine**: Godot 4.6 / GDScript / 2D Forward+ / 60 fps locked

---

## A. Overview

Camera2D는 ECHO를 따라가는 횡스크롤 카메라이며, **세 가지 책임**을 가진다:

1. **Follow** — 플레이어 위치를 수평 deadzone 기반으로 추적 (수직은 grounded 기준 lookahead lerp).
2. **Snap** — 체크포인트 재시작 시 Scene Manager가 emit하는 `scene_post_loaded(anchor: Vector2)` 시그널 수신 즉시 `global_position = anchor` + `reset_smoothing()` 호출하여 **1 프레임 내에** 무지연 정렬 (Pillar 1 비협상 — 60-tick restart budget 내부).
3. **Shake** — 게임플레이 이벤트(`shot_fired` 미세 진동, `player_hit_lethal` 임팩트, `boss_killed` 강진동) 시각 강조. 진동 강도/지속/주파수는 본 GDD가 단일 출처로 정의 (architecture.yaml 358행 등록 contract).

### 데이터 레이어 (infrastructure framing)

`extends Camera2D`; 단일 노드(autoload 아님 — PlayerMovement의 형제 노드로 stage root에 배치). 매 프레임 `global_position` = `target.global_position + look_offset + shake_offset`이며, `shake_offset`은 `Engine.get_physics_frames()`-seeded `RandomNumberGenerator`로 결정 → ADR-0003 determinism boundary 정합.

### 플레이어 체감 레이어 (player-facing framing)

ECHO는 화면 중앙 ±deadzone(수평 64 px, 수직 32 px)에서 자유롭게 이동하고, 데드존 가장자리에 닿으면 카메라가 따라온다. 점프 정점에서 미세 lookahead로 ECHO 머리 위 여유 공간 확보, 사격 시 1-3 px 미세 진동(공격감), 1히트 즉사 시 6 px 강진동(좌절→리셋 시각 신호), 보스 격파 시 8-12 px 강진동(카타르시스). 콜라주 비주얼 시그너처(Pillar 3) 보존을 위해 zoom은 Tier 1에서 1.0 고정 (Tier 2 보스 줌으로 확장 deferred).

### ADR 참조

- **ADR-0001 (Player-only rewind)**: 카메라는 rewind 대상이 **아님** — 시간 되감기 후 카메라는 ECHO 복원 위치(ADR-0003 단일 writer `PlayerMovement.restore_from_snapshot()`)에서 다음 follow 사이클을 새로 시작.
- **ADR-0002 (Snapshot 9-field)**: 카메라 상태는 PlayerSnapshot에 **포함되지 않는다**. `rewind_completed` 시그널 수신 시 카메라는 (a) shake state 즉시 0으로 클램프 (잔여 진동 폐기), (b) `global_position`을 복원된 player position 기점으로 재계산. snapshot scope 확장 불필요.
- **ADR-0003 (Determinism)**: shake offset은 `Engine.get_physics_frames()` + 이벤트 발생 프레임으로 시드된 per-event RNG로 deterministic; camera-relative 결정 금지 (예: VisibleOnScreenNotifier2D로 발사체 despawn 결정 — Player Shooting #7 G.3 invariant #3에서 이미 금지됨).

### 한 줄 요약

> ECHO를 항상 화면 중심 ±deadzone 내에 두고, 게임플레이 임팩트를 결정론적 진동으로 강조하며, 체크포인트 재시작 시 1 프레임 내에 새 앵커로 정렬한다.

### A.1 Locked Decisions (this section)

| ID | Decision | Source |
|---|---|---|
| **DEC-CAM-A1** | Camera2D **NOT autoload** — PlayerMovement 형제 노드로 stage root에 배치 (단일 인스턴스 per scene; Scene Manager는 씬 교체 시 새 인스턴스 생성) | Scene Manager #2 C.2.4 ownership boundary 정합 — 씬 경계 owner는 SM, 씬 내부 노드는 stage 책임 |
| **DEC-CAM-A2** | Camera state **NOT in PlayerSnapshot** — ADR-0002 9-field lock 유지; rewind 후 카메라는 새로 시작 | ADR-0002 Amendment 2 (9 fields 락); snapshot scope 확장은 메모리 budget (Tier 1 17.64 KB) 압박 + Pillar 1 1초 restart 의무 위반 위험 |
| **DEC-CAM-A3** | Shake `Engine.get_physics_frames()`-seeded RNG — ADR-0003 결정성 정합 | ADR-0003 R-RT3-02 + R-RT3-06 (cosmetic exempt이지만 shake는 발사체 visual feedback에 cross-link → strict 결정성 채택) |
| **DEC-CAM-A4** | Tier 1 zoom=1.0 고정 — Tier 2 보스 줌 deferred | Pillar 5 (작은 성공 > 큰 야심); art-bible 1080p/720p 기준선 (3px line @ 1080p; 1280×720 Steam Deck native) |
| **DEC-CAM-A5** | **Split horizontal/vertical position model**: 수평 incremental advance (`camera.x += overshoot` when \|delta_x\|>DEADZONE_HALF_X), 수직 target+lookahead (`camera.y = target.y + look_offset.y`). `look_offset.x`는 항상 0 (unused). | Session 22 design-review BLOCKING #1 resolution 2026-05-12 — 이전 unified `camera = target + look_offset` 모델은 F-CAM-2 worked example + AC-CAM-H1-01 (`camera.x = 501`)과 산술적으로 양립 불가; deadzone semantics 정합 위해 split (Katana Zero/Celeste pattern) |

## B. Player Fantasy

> **카메라는 잊지 않는다.**
>
> 시간이 되감기고, 플레이어가 되감겨도, 카메라는 되감기지 않는다. 1.5초 lookback에서 세계는 리셋되지만 카메라는 자기 자리를 지킨다 — 방금 당한 죽음과 지금 잡는 두 번째 기회 사이의 **유일한 연속선**이다. *시간은 되감겨도, 시선은 되감기지 않는다.* 카메라는 플레이어의 기억이 물리적 형태로 존재하는 것이다.

### B.1 무엇을 느끼는가

| Pillar | 어떻게 카메라가 기여하는가 |
|---|---|
| **Pillar 1** (학습 도구) | 시간 되감기 직후 카메라가 정지점에서 lerp 없이 ECHO 복원 위치로부터 재구성된다 — 플레이어가 "*세계가 나를 되감았다*"가 아니라 "*내가 나를 되감았다*"로 읽도록. 시점 연속성이 rewind를 *비처벌*적 학습 도구로 만든다. |
| **Pillar 2** (결정성) | 진동 offset은 `Engine.get_physics_frames()` + 이벤트 발생 프레임으로 시드된 RNG로 결정. 같은 입력 시퀀스 → 같은 흔들림 → 같은 스크린샷. 운(luck)이 카메라에 진입하지 않는다. |
| **Pillar 3** (콜라주 첫 인상) | Sub-principle "**The camera that remembers also composes**": 보스 격파 진동(8-12 px) 정점에서도 보스 실루엣은 화면의 readable third(중앙 가독 영역) 안에 머문다 — 진동이 콜라주 합성을 무너뜨리지 않는다. 스크린샷 시그너처 보존. |

### B.2 0.2-초 디자인 테스트 (3개)

본 테스트는 단일 프레임에서 카메라가 player fantasy를 *눈에 보이게* 깨뜨릴 수 있는 조건을 명시한다. 모두 acceptance criteria의 시드.

| ID | 0.2-초 모먼트 | 합격 조건 | 실패 시 깨지는 fantasy |
|---|---|---|---|
| **DT-CAM-1** | Rewind complete frame (T+0, RESTORE_OFFSET_FRAMES=9 적용 후) | 카메라 `global_position`이 T+0 직전의 위치와 동일 — 0 px 드리프트, 0 frame 스무딩 잔여 | "내가 되감았다" → "세계가 나를 되감았다"로 오독 (Pillar 1 학습 도구 정체성 붕괴) |
| **DT-CAM-2** | `boss_killed` emit 직후 8-12 px 진동 피크 프레임 | 보스 sprite 실루엣이 viewport의 readable third (수평 중앙 ±213 px @ 1280 width) 내부에 유지 | Pillar 3 콜라주 시그너처 붕괴 — 카타르시스 스크린샷이 보스를 화면 밖에 두고 찍힘 |
| **DT-CAM-3** | `player_hit_lethal` emit 프레임 | 6 px 임팩트 진동이 *rewind UI/플래시 전에* 시작, 진동 종료 후 rewind 시각 효과 진입 | 카메라 진동이 UI chrome으로 읽힘 (결과의 무게가 사라짐) — Pillar 1 사망→학습 전환 카타르시스 약화 |

### B.3 무엇을 느끼지 *않는가* (negative space)

- **카메라 컨트롤 액션 없음**: 플레이어는 카메라를 직접 조작하지 않는다 (RT-stick free-look, dedicated zoom button 등 모두 **명시적 거부** — Tier 1 Anti-Pillar #6 input remapping 배제 + Pillar 5 작은 성공).
- **시네마틱 컷씬 없음**: 보스 등장/격파에서 카메라가 player control을 빼앗아 cut-to-boss-portrait 같은 cinematic 연출을 하지 않는다 (Anti-Pillar Story Spine 컷씬 X + Pillar 4 5분 룰 + Pillar 1 1초 restart 의무).
- **카메라 lerp lag로 인한 시야 부족 없음**: 점프 정점 lookahead가 충분하여 ECHO 머리 위 공간 부족으로 플레이어가 머리 위 위협을 못 보는 일이 없다 (Pillar 2 결정성과 직결 — 운으로 죽지 않음).

### B.4 Locked Decisions (this section)

| ID | Decision | Source |
|---|---|---|
| **DEC-CAM-B1** | Player Fantasy 헤드라인 = "카메라는 잊지 않는다" — Section A `Camera NOT in PlayerSnapshot` 결정의 player-facing 번역 | creative-director 합의 (Session 22 2026-05-12); Framing C 채택, Framing B는 Pillar 3 sub-principle로 흡수, Framing A 모티프는 DT-CAM-3에 통합 |
| **DEC-CAM-B2** | 3개 0.2-초 디자인 테스트 (DT-CAM-1/2/3) → Section H acceptance criteria의 직접 시드 | 모든 GDD player fantasy는 falsifiable한 0.2-초 테스트로 환원되어야 한다 (game-concept.md Pillar 3 design test 패턴 정합) |
| **DEC-CAM-B3** | 카메라는 player control input을 받지 않음 — Tier 1 / Tier 2 / Tier 3 모두 | Anti-Pillar #6 (input remapping deferred) + Pillar 5 (small successes) + Pillar 4 (5분 룰 — 학습할 컨트롤 추가 금지) |

## C. Detailed Design

### C.1 Core Rules (12 numbered rules — evaluation order)

본 12개 룰은 단일 `_physics_process(_delta)` 콜백 안에서 **순서대로** 평가된다. R-C1-1이 frame budget의 핵심 계산이며, 나머지는 가드, 응답, 또는 시그널 핸들러로 분리된다.

**R-C1-1 (Per-frame position formula — split horizontal/vertical model)**

매 `_physics_process` tick에서, 수평·수직 분리 모델 (Session 22 design-review 2026-05-12 BLOCKING #1 resolution — DEC-CAM-A5):

```
# 수평: deadzone incremental advance (R-C1-3에서 즉시 적용)
delta_x = target.global_position.x - camera.global_position.x
if abs(delta_x) > DEADZONE_HALF_X:
    camera.global_position.x += delta_x - sign(delta_x) * DEADZONE_HALF_X
# else: camera.global_position.x 변경 없음 (데드존 내부)

# 수직: target + lookahead (state-scaled)
camera.global_position.y = target.global_position.y + look_offset.y

# Shake: smoothing pass 뒤 채널
camera.offset = shake_offset                        # NOTE: offset, NOT global_position
```

수평/수직 분리는 **load-bearing**: 수평은 incremental advance (Katana Zero/Celeste 데드존 패턴 — camera trails target by DEADZONE_HALF_X 정확히 in steady-state), 수직은 target+lookahead (점프/낙하 사전 가시화). `look_offset`은 Vector2이나 `.x`는 항상 0이며 vertical lookahead `look_offset.y`만 의미를 갖는다 (DEC-CAM-A5).

이중 분리는 `position_smoothing_enabled=true`로 follow를 부드럽게 유지하면서, shake는 smoothing pass 뒤에 적용되는 `offset` 채널에 쓰여 lerp에 의해 흐려지지 않는다. Godot 4.6 Camera2D는 `offset`을 post-smoothing 변위로 처리한다 (gameplay-programmer 검증 2026-05-12).

`limit_left/right/top/bottom` 클램프는 Camera2D 내장 (Rule R-C1-12 stage limit 셋업 참조).

**R-C1-2 (Rewind freeze guard)**

`is_rewind_frozen == true`이면 R-C1-1 전체를 skip. `global_position`과 `offset` 모두 마지막 unfrozen tick 값에서 동결. Pillar 1 "시선은 되감기지 않는다" 정합 + DT-CAM-1 (rewind 종료 시 0 px drift) 자명한 검증 경로.

**R-C1-3 (Horizontal deadzone follow — incremental advance)**

```
delta_x = target.global_position.x - camera.global_position.x
if abs(delta_x) <= DEADZONE_HALF_X (= 64):
    camera.global_position.x 변경 없음   # 데드존 내부
else:
    # Limit-boundary guard (E-CAM-1 amendment 2026-05-12 — defense-in-depth under split-H/V):
    # 카메라가 이미 limit_left에 clamp되어 있는데 delta_x < 0이면 (player가 더 좌측으로 가려 함),
    # 또는 limit_right clamp + delta_x > 0이면 — advance skip (Godot 내장 clamp가 흡수하지만 명시).
    if (camera.global_position.x <= limit_left and delta_x < 0) or \
       (camera.global_position.x >= limit_right and delta_x > 0):
        pass  # 벽에 박혀 있을 때 advance skip
    else:
        camera.global_position.x += delta_x - sign(delta_x) * DEADZONE_HALF_X  # incremental advance
```

ECHO가 화면 중심 ±64 px 안에 있으면 camera.x는 정지; 데드존 경계를 통과하는 순간 camera.x가 overshoot 분만큼 즉시 advance한다 (steady-state에서 camera는 target.x를 정확히 DEADZONE_HALF_X 만큼 trail). 64 px = viewport_width 1280의 5%, Katana Zero(80) ~ Celeste(32) 사이의 중간점 — 6 rps run-and-gun 페이싱에 적합 (ux-designer 검증 2026-05-12).

**Limit-boundary guard 근거** (E-CAM-1, 2026-05-12 systems-designer 검증 + Session 22 BLOCKING #1 amendment): split-H/V 모델 (DEC-CAM-A5)에서는 `look_offset.x`가 없으므로 wall-pinch 시 deficit 누적이 구조적으로 발생하지 않는다 — Godot 내장 `limit_*` clamp가 매 tick advance를 흡수. 본 명시적 guard는 defense-in-depth — Godot clamp 실패 시 또는 미래 변경에 대한 보호.

**R-C1-4 (Vertical asymmetric lookahead — state-scaled)**

| Player Movement state | `look_offset.y` 타겟 | Lerp |
|---|---|---|
| `IDLE` / `RUN` (grounded) | `0` | — (즉시) |
| `JUMPING` (rising) | `-JUMP_LOOKAHEAD_UP_PX` (= -20) | `LOOKAHEAD_LERP_FRAMES` (= 8 frames) |
| `FALLING` | `FALL_LOOKAHEAD_DOWN_PX` (= 52) | 8 frames |
| `REWINDING` / `DYING` | 즉시 0으로 클램프 | — (즉시) |

`y`축은 화면 위 방향이 음수 (Godot 표준). Run-and-gun 착지 위협 (스파이크, 바닥 적)이 점프 정점 위협보다 빈번하므로 fall 방향이 2.6× 더 깊다 (52/20 ≈ 2.6). State-scaled가 velocity-scaled를 이긴다 — velocity 기반은 rewind 후 잔여 lerp residual을 만들어 DT-CAM-1을 위협 (ux-designer + game-designer 합의).

**R-C1-5 (Shake — per-event timer pool)**

각 shake 이벤트는 독립적 timer 슬롯을 가진다 (per-event, NOT 단일 trauma 스칼라):

```
class ShakeEvent:
    amplitude_peak_px: float
    duration_frames: int
    frame_start: int           # Engine.get_physics_frames() at emit
    event_seed: int            # 단조 카운터, per-camera-instance
```

매 tick `shake_offset` 계산:

```
shake_offset = Vector2.ZERO
for event in active_events:
    frame_elapsed = current_frame - event.frame_start
    if frame_elapsed >= event.duration_frames:
        remove(event); continue
    decay = 1.0 - (frame_elapsed / event.duration_frames)        # linear decay
    rng.seed = (current_frame * 1_000_003) ^ event.event_seed     # patch-stable (NOT hash())
    direction = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
    shake_offset += direction * event.amplitude_peak_px * decay
shake_offset = shake_offset.limit_length(MAX_SHAKE_PX)            # = 12 px clamp
```

이벤트 파라미터 (Tier 1):

| 이벤트 시그널 | Peak amplitude (px) | Duration (frames) | 출처 |
|---|---|---|---|
| `shot_fired` | 2 (range 1-3) | 6 | Player Shooting #7 (6 rps fire rate; FIRE_COOLDOWN_FRAMES=10 > 6 → 다음 발사 전 자연 감쇠) |
| `player_hit_lethal` | 6 | 12 | Damage #8 |
| `boss_killed` | 10 (range 8-12) | 18 | Damage #8 |

**R-C1-6 (Shake stacking — sum-clamped)**

같은 tick에서 2+ 이벤트 동시 활성 시 amplitudes는 vector-sum되고 `MAX_SHAKE_PX = 12`로 clamp. 더 큰 이벤트가 시각적으로 dominate (boss_killed의 10 px가 동시 shot_fired의 2 px를 흡수). 이벤트는 서로를 cancel하지 않는다 (Vlambeer trauma 모델 변형; Nuclear Throne 패턴 정합 — ux-designer 인용 2026-05-12).

`shot_fired` 6-frame duration < FIRE_COOLDOWN_FRAMES 10-frame → 미세 진동 누적은 **구조적으로** 차단된다 (clamp만이 아니라 timeline gap으로 보장).

**R-C1-7 (Shake RNG determinism)**

Per-event `event_seed`는 카메라 인스턴스 단조 카운터 (`var _shake_event_seed_counter: int = 0`; `_shake_event_seed_counter += 1`이 매 emit handler에서 호출). RNG 시드 = `(current_frame * 1_000_003) ^ event_seed`로 매 frame 재시드 (gameplay-programmer 검증: `hash(Vector2i(...))`는 Godot 4.6 patch-stability 보장 안 됨; 명시적 prime mix가 안전).

ADR-0003 R-RT3-02 정합: shake offset은 `Engine.get_physics_frames()` 단조 카운터의 순함수.

**R-C1-8 (`rewind_started` handler)**

```gdscript
func _on_rewind_started() -> void:
    is_rewind_frozen = true
    # 활성 shake events는 timer 카운트다운 계속하나, R-C1-2가 R-C1-1을 skip하므로 visual에 미반영
```

카메라는 freeze 상태에서 ECHO를 추적하지 않는다 — "시선은 되감기지 않는다" 의 literal 구현. Player Fantasy Framing C의 architecture-to-experience 직역.

**R-C1-9 (`rewind_completed` handler)**

```gdscript
func _on_rewind_completed(player_node: PlayerMovement, restored_to_frame: int) -> void:
    is_rewind_frozen = false
    active_events.clear()                          # 모든 활성 shake 강제 종료
    shake_offset = Vector2.ZERO
    offset = Vector2.ZERO
    look_offset = _compute_initial_look_offset(player_node)   # .x = 0 (unused per DEC-CAM-A5); .y = state-mapped
    # Split H/V reset (per R-C1-1 model):
    global_position.x = player_node.global_position.x         # deadzone re-establishes next ticks via R-C1-3
    global_position.y = player_node.global_position.y + look_offset.y
    reset_smoothing()                              # smoothing accumulator를 새 위치로 강제 동기화
    # 다음 _physics_process tick부터 R-C1-1 정상 평가
```

순서 비협상: (1) freeze 해제, (2) shake 클리어, (3) look_offset 재계산, (4) global_position.x/.y 할당, (5) reset_smoothing 호출. **(5)는 반드시 (4) 뒤** — `reset_smoothing()` 호출이 (4) 앞에 오면 old position을 새 anchor로 간주해 lerp residual 발생 (gameplay-programmer 검증 2026-05-12).

**`_compute_initial_look_offset(player_node)` spec (BLOCKING #3 resolution Session 22 2026-05-12)**:

```gdscript
func _compute_initial_look_offset(player_node: PlayerMovement) -> Vector2:
    var target_y: float = _target_y_for_state(player_node.movement_sm.state)
    return Vector2(0.0, target_y)   # .x = 0 always (split-H/V model — DEC-CAM-A5)

func _target_y_for_state(state: StringName) -> float:
    match state:
        &"JUMPING":             return -JUMP_LOOKAHEAD_UP_PX        # −20
        &"FALLING":             return  FALL_LOOKAHEAD_DOWN_PX      # +52
        &"REWINDING", &"DYING": return 0.0                          # immediate clamp
        _:                      return 0.0                          # IDLE / RUN / default
```

R-C1-4 state→target_y 매핑과 1:1 정합. AC-CAM-H4-02 field (e)가 본 spec을 직접 assert.

DT-CAM-1 자명한 검증: T+0 (`rewind_completed` 직후 1 tick) `global_position.x`은 `player.global_position.x` (deterministic, identity 함수), `global_position.y`는 `player.global_position.y + look_offset.y` (deterministic, state-mapped) — 0 px drift, 0 frame smoothing residual.

**R-C1-10 (`scene_post_loaded(anchor: Vector2, limits: Rect2)` handler — checkpoint snap)**

```gdscript
func _on_scene_post_loaded(anchor: Vector2, limits: Rect2) -> void:
    limit_left   = int(limits.position.x)
    limit_right  = int(limits.position.x + limits.size.x)
    limit_top    = int(limits.position.y)
    limit_bottom = int(limits.position.y + limits.size.y)
    look_offset  = Vector2.ZERO
    offset       = Vector2.ZERO
    active_events.clear()
    is_rewind_frozen = false
    global_position = anchor
    reset_smoothing()
```

Scene Manager #2 C.2.1 POST-LOAD phase에서 동일 tick에 emit (Q2 deferred 시그널의 first-use case — Phase 5 cross-doc 의무 참조). 카메라 cost = **≤ 1 tick** in SM 60-tick restart budget (`M + K + 1 ≤ 60` 의 K 안에 흡수, 추가 가산 없음 — 단순 assignment 9건 + `reset_smoothing()`).

`limits: Rect2`는 stage-by-stage 변동성 흡수. Tier 1 단일 스테이지 = 단일 `Rect2`; Tier 2 멀티룸 진입 시 동일 시그널 재사용 (signature 비변경).

**R-C1-11 (`_physics_process` priority = 30)**

```gdscript
func _ready() -> void:
    process_physics_priority = 30
    process_callback = CAMERA2D_PROCESS_PHYSICS
    position_smoothing_enabled = true
    position_smoothing_speed = 32.0    # exponential decay rate; ~5-frame settle on 64 px delta
    zoom = Vector2.ONE                 # Tier 1 lock; Tier 2 boss zoom deferred
```

ADR-0003 ladder 정합: player=0, TRC=1, Damage=2, enemies=10, projectiles=20, **Camera=30**. 모든 gameplay source가 같은 tick 안에서 settle한 후 카메라가 final 위치를 계산. priority 100은 거부 — ADR-0003 ladder의 의도된 다음 슬롯이 30 (70 빈 슬롯은 향후 시스템용; 30은 "post-gameplay visual layer" 자연 슬롯).

`CAMERA2D_PROCESS_PHYSICS` callback mode 비협상 — `IDLE` mode는 player transform과 1-tick out-of-phase → rewind snap correctness 깨짐 (godot-specialist 검증 2026-05-12).

`position_smoothing_speed = 32.0`은 **exponential decay rate** (godot 4.6 doc "points/sec"은 misleading — 실제는 `pos = pos.lerp(target, speed * delta)` per-frame): 64 px delta가 5 frames 내 ~1 px 잔여까지 수렴 (`(1 - 32 * 0.0167)^5 ≈ 0.014` → 64 × 0.014 ≈ 0.9 px). `reset_smoothing()`은 1-call로 accumulator 강제 동기화 → snap 후 residual 0.

**R-C1-12 (Stage limits — single source via signal)**

Stage limits는 `scene_post_loaded(anchor, limits: Rect2)`의 `limits` 인자가 **단일 출처**. R-C1-10 핸들러가 `limit_left/right/top/bottom`을 atomic으로 set. 어떤 다른 경로도 limits를 쓸 수 없다 (single-writer 원칙).

**Boot ordering contract** (scene-manager.md C.2.1 lifecycle 정합): SM 5-phase lifecycle은 POST-LOAD phase 안에서 `scene_post_loaded` emit 후에 READY로 전이하고, READY 전에 player 입력 dispatch가 시작되지 않으므로 첫 `scene_post_loaded` emit이 카메라의 첫 의미 있는 `_physics_process` tick보다 항상 먼저 도착한다. 카메라 측 별도 가드 불필요 — 이 ordering은 SM contract가 구조적으로 보장한다 (AC-CAM-H-INTEG-1 검증).

---

### C.2 States and Transitions

카메라는 **단일 논리 상태 `FOLLOWING`**을 가지며, 2개의 bool 플래그가 R-C1-1의 분기를 가드한다:

| Flag | 셋 시점 | 클리어 시점 | 효과 |
|---|---|---|---|
| `is_rewind_frozen` | `_on_rewind_started` (R-C1-8) | `_on_rewind_completed` (R-C1-9) | R-C1-1 skip — 카메라 동결 |
| `apply_snap_next_frame` | `_on_scene_post_loaded` 안에서 set, 같은 핸들러 안에서 consume 후 클리어 | — | R-C1-10 본문 직접 실행 (1-tick latency 없음) |

**Why no formal state machine**: 카메라의 분기는 단일 update flow 안의 if-가드로 표현 가능하며, state-machine.md의 `extends StateMachine` 프레임워크는 멀티 인스턴스 + 동시 reactive transitions를 타깃한다. Camera는 단일 인스턴스 per scene, 단일 호출자, 단일 update path → 프레임워크 오버헤드를 정당화하지 못한다 (Scene Manager #2 C.2.3 enum+match 패턴 precedent 정합).

**REWIND_FREEZE를 별도 state로 두지 않는 이유**: α-freeze (현 결정) vs β-follow-player-back 두 옵션 중 α 채택. β는 `is_rewind_frozen=false`이고 rewind 중에 카메라가 player position을 따라가는 모델이지만, rewind 종료 시점에 lerp residual을 만들어 DT-CAM-1 (0 px drift / 0 frame smoothing residual) 검증을 fragile하게 만든다. α는 trivially testable — `global_position(T+0) == global_position(T-1, last frozen frame)` 단일 equality assert.

**Diagram**:

```
                ┌──────────────────────┐
                │                      │
                │  FOLLOWING           │ ← 모든 tick의 동작은 R-C1-1
                │  (single state)      │
                │                      │
                │  flags:              │
                │   is_rewind_frozen   │ ← R-C1-8 set / R-C1-9 clear
                │   apply_snap_next    │ ← R-C1-10 핸들러 내부 self-consume
                │                      │
                └──────────────────────┘
                    (entry: _ready;
                     no exit — node persists for stage lifetime)
```

---

### C.3 Interactions with Other Systems

#### C.3.1 Signal Subscribe Matrix (Camera는 6 시그널 구독, 0 시그널 emit)

| Signal | Signature | Emitter | Camera handler | Side-effect | Frame cost |
|---|---|---|---|---|---|
| `scene_post_loaded` | `(anchor: Vector2, limits: Rect2)` | Scene Manager #2 (Q2 deferred, **본 GDD가 first-use trigger — Phase 5 cross-doc 의무**) | `_on_scene_post_loaded` (R-C1-10) | `limit_*` 4건 set + position snap + `reset_smoothing()` | ≤ 1 tick |
| `shot_fired` | `(weapon_id: int)` | Player Shooting #7 (Approved 2026-05-11; F.4.2 Camera #3 obligation 등록) | `_on_shot_fired` | active_events에 micro shake (2 px / 6 frames) 추가 | negligible |
| `player_hit_lethal` | `(_cause: StringName)` | Damage #8 (LOCKED for prototype) | `_on_player_hit_lethal` | active_events에 impact shake (6 px / 12 frames) 추가 | negligible |
| `boss_killed` | `(boss_id: StringName)` | Damage #8 F.4 LOCKED single-source | `_on_boss_killed` | active_events에 catharsis shake (10 px / 18 frames) 추가 | negligible |
| `rewind_started` | `()` | Time Rewind #9 Approved | `_on_rewind_started` (R-C1-8) | `is_rewind_frozen = true` | negligible |
| `rewind_completed` | `(player: PlayerMovement, restored_to_frame: int)` | Time Rewind #9 Approved (canonical signature per W2 housekeeping 2026-05-10) | `_on_rewind_completed` (R-C1-9) | freeze 해제 + shake 클리어 + position 재유도 + `reset_smoothing()` | ≤ 1 tick |

**Camera emits**: **NONE in Tier 1**. Pillar 3 콜라주 스크린샷 capture는 Steam 내장 기능 + 사용자 트리거 (F12 기본); 카메라가 emit해야 할 downstream 없음. 가설적 future emitter `composition_changed` 등은 dependents 부재 → YAGNI 거부.

#### C.3.2 ADR-0003 Determinism Boundary

카메라는 ADR-0003 determinism boundary의 **outside** 또는 **edge**에 위치한다:

- **Outside (cosmetic-exempt 후보)**: `global_position` / `offset`은 gameplay-affecting 상태가 아니며 PlayerSnapshot에 포함되지 않음 → ADR-0003 R-RT3-06 cosmetic exemption clause 적용 가능.
- **그러나 본 GDD는 stricter contract 채택**: shake RNG가 `Engine.get_physics_frames()`-seeded이므로 cosmetic exemption을 받지 않고도 ADR-0003 R-RT3-02 (deterministic w.r.t. frame counter, no wall clock, no global RNG)를 자명히 만족한다. 이유: (1) 카메라 visual은 Pillar 3 콜라주 스크린샷 시그너처 — bit-identical replay가 마케팅 이미지 일관성 보장, (2) Tier 2+ replay/share 기능 도입 시 카메라 결정성이 prerequisite, (3) cosmetic exemption은 boundary-creep 위험 → strict 채택으로 future 확장 보호.

**Forbidden patterns 검증**:
- ❌ `VisibleOnScreenNotifier2D`로 gameplay 트리거 결정 — 이미 Player Shooting #7 G.3 invariant #3에서 금지 (projectile despawn camera-relative 금지).
- ❌ `Time.get_ticks_msec()` / `OS.get_unix_time()` 기반 shake — wall-clock 의존, ADR-0003 위반.
- ❌ `randf()` 글로벌 RNG — per-event `RandomNumberGenerator` 사용.
- ❌ `hash(Vector2i(...))` 시드 — Godot 4.6 patch-stability 불보장; explicit `(frame * 1_000_003) ^ event_seed` 사용 (gameplay-programmer 검증).

#### C.3.3 Cross-doc Reciprocal Obligations (Phase 5 일괄 적용 — BLOCKING gate)

본 GDD가 first-use trigger인 시그널 contract는 다음 GDD에 반영되어야 한다 (Phase 5 cross-doc batch — Approved promotion gate 의무, scene-manager.md F.4.1 RR4 precedent 정합):

| 영향 GDD | 변경 내용 | 변경 위치 |
|---|---|---|
| `design/gdd/scene-manager.md` | C.2.1 POST-LOAD phase: SM-internal 노출 안 함 → **`scene_post_loaded(anchor: Vector2, limits: Rect2)` 시그널 추가**. C.3 signal matrix에 emitter row 추가. C.3.4 Q2 obligation 닫기 (Camera #3 first-use). DEC-SM-9 status flip: deferred → resolved | C.2.1 + C.3.1 + C.3.4 + DEC-SM-9 |
| `design/gdd/scene-manager.md` | F.4.2 row Camera #3: 의무 status check — "본 GDD revision으로 시그널 추가" → "done (Camera #3 #C.1.10 핸들러 호출)" | F.4.2 row #3 |
| `design/gdd/scene-manager.md` | OQ-SM-A1 → resolved (Camera #3 first-use 발생) | Z OQ table |
| `design/gdd/scene-manager.md` | C.2.1 POST-LOAD emit handler에 boot-time assert 추가: `assert(limits.size.x > 0 and limits.size.y > 0)` (E-CAM-7 — invalid Rect2 방지) | C.2.1 POST-LOAD body |
| `design/art/art-bible.md` | Section 6 (Environment Design Language) 끝에 "Camera Viewport Contract" 서브섹션 추가 — screen-shake uniform 변위 + readable third 정의 + Tier 2 zoom bound 0.85..1.25× + ECHO ≥32 px apparent height floor (art-director 검증 2026-05-12) | Section 6 |
| `docs/registry/architecture.yaml` | `interfaces.scene_lifecycle.signals` 항목에 `scene_post_loaded(anchor: Vector2, limits: Rect2)` 추가 + consumers=[camera] (Tier 2 진입 시 stage + hud append) | interfaces.scene_lifecycle |
| `docs/registry/architecture.yaml` | 새 항목 `interfaces.camera_shake_events` — consumers=[camera-system], producers=[player-shooting, damage] | new entry |
| `docs/registry/architecture.yaml` | 새 forbidden pattern `camera_state_in_player_snapshot` — Camera state 절대 PlayerSnapshot에 포함 금지 (ADR-0002 9-field lock 보호) | forbidden_patterns |
| `design/registry/entities.yaml` | 새 constants 6종: `DEADZONE_HALF_X`, `JUMP_LOOKAHEAD_UP_PX`, `FALL_LOOKAHEAD_DOWN_PX`, `LOOKAHEAD_LERP_FRAMES`, `MAX_SHAKE_PX`, `POSITION_SMOOTHING_SPEED` | constants |
| `design/gdd/systems-index.md` | Row #3 Camera System: Status Not Started → Designed (or Approved post-review); Design Doc 링크 추가 | Row #3 |

## D. Formulas

본 섹션의 모든 공식은 Section C 규칙을 falsifiable한 정량 형태로 인코딩한다. 모든 변수는 표로 정의되고 출력 범위 + worked example을 포함한다.

---

### F-CAM-1 — Per-Frame Position Resolution (split H/V model)

```
# Horizontal: incremental deadzone advance (F-CAM-2)
delta_x = target.global_position.x - camera.global_position.x
if abs(delta_x) > DEADZONE_HALF_X:
    camera.global_position.x += delta_x - sign(delta_x) * DEADZONE_HALF_X

# Vertical: target + lookahead
camera.global_position.y = target.global_position.y + look_offset.y

# Shake: smoothing-bypass channel
camera.offset = shake_offset
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `target.global_position` | Vector2 | stage-bounded (Tier 1 single-stage) | Player world position this tick |
| `look_offset.x` | — | always 0 (unused per DEC-CAM-A5) | Reserved field; horizontal uses incremental advance, not offset |
| `look_offset.y` | float | −20..+52 px | Vertical lookahead (F-CAM-3 state-scaled lerp output) |
| `shake_offset` | Vector2 | length ≤ MAX_SHAKE_PX (=12 px) | Post-smoothing screen displacement (F-CAM-5 output) |
| `camera.global_position.x` | float | stage-limit-clamped by Camera2D 내장 | Incremental — trails target.x by DEADZONE_HALF_X in steady-state |
| `camera.global_position.y` | float | stage-limit-clamped by Camera2D 내장 | = target.global_position.y + look_offset.y |
| `camera.offset` | Vector2 | length ≤ 12 px | Post-smoothing pixel offset (bypasses smoothing) |

**Output range**: `camera.global_position`은 `limit_*` 내장 clamp 적용; `camera.offset`은 F-CAM-5 clamp로 12 px 이내. 두 쓰기 사이트 분리 비협상 — Godot 4.6 Camera2D는 `offset`을 smoothing pass 뒤 적용하여 shake가 lerp에 흐려지지 않도록 보장 (Pillar 2/3).

**Worked example**: ECHO at world position `(640, 360)`, ECHO has been sprinting right such that camera trails target by exactly DEADZONE_HALF_X (steady-state), shake 비활성, grounded (look_offset.y = 0):
- 이전 tick `camera.x = 576` (= 640 − 64), ECHO 새 위치 `target.x = 643` → `delta_x = 67 > 64` → `camera.global_position.x += 67 − 64 = +3` → `camera.x = 579`.
- `camera.global_position.y = 360 + 0 = 360`
- `camera.offset = Vector2(0, 0)`
- 결과: ECHO는 viewport 중심에서 +64 px 우측 (`viewport_relative.x = ECHO.x − camera.x = 643 − 579 = 64 px`); deadzone 가장자리에 머무는 한 camera는 player와 lock-step 진행.

---

### F-CAM-2 — Horizontal Deadzone Camera Advance

```
delta_x = target.global_position.x − camera.global_position.x
if abs(delta_x) > DEADZONE_HALF_X:
    camera.global_position.x += delta_x − sign(delta_x) × DEADZONE_HALF_X
# else: camera.global_position.x 유지 (데드존 내부 — 변경 없음)
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `delta_x` | float | unbounded | `target.x − camera.x` (이번 tick, advance 전) |
| `DEADZONE_HALF_X` | int (locked) | **64 px** | 수평 deadzone half-width |
| `camera.global_position.x` | float | stage-limit-clamped (Godot 내장 `limit_left/right`) | Incremental advance 결과값 (이번 tick after update) |

**Output range**: `camera.global_position.x`은 overshoot 분만큼 advance; Godot 내장 `limit_left/right` clamp 적용. Steady-state에서 camera는 target.x를 정확히 DEADZONE_HALF_X 만큼 trail.

**Worked example** — 데드존 가장자리 통과 (AC-CAM-H1-01 정합):
- 이전 tick `camera.x = 500`, 새 tick `target.x = 565` → `delta_x = 65`, `|65| > 64` → `camera.global_position.x += 65 − sign(65) × 64 = +1 px` → `camera.x = 501`.
- 다음 tick `target.x = 566` → `delta_x = 566 − 501 = 65` → 또 다시 `+1 px` advance → `camera.x = 502`.
- ECHO가 데드존 가장자리에 머무는 한 카메라는 player와 동일 속도로 lock-step 추적 (camera trails target by DEADZONE_HALF_X=64 exactly). Pillar 1 — 결정론적 sub-pixel residual 없음.

---

### F-CAM-3 — Vertical Lookahead State Lerp

```
look_offset.y = lerp(look_offset.y, target_y, 1.0 / LOOKAHEAD_LERP_FRAMES)
```

State → `target_y` 매핑:

| State | `target_y` (px) |
|---|---|
| IDLE / RUN (grounded) | 0 |
| JUMPING (rising) | −JUMP_LOOKAHEAD_UP_PX = **−20** |
| FALLING | +FALL_LOOKAHEAD_DOWN_PX = **+52** |
| REWINDING / DYING | 0 (즉시 클램프 — lerp 없음) |

| Variable | Type | Range | Description |
|---|---|---|---|
| `look_offset.y` | float | −20..+52 px | 현재 vertical leading offset |
| `target_y` | int | {−20, 0, +52} px | State 기반 target |
| `LOOKAHEAD_LERP_FRAMES` | int (locked) | **8 frames** | Lerp rate reciprocal |
| `JUMP_LOOKAHEAD_UP_PX` | int (locked) | **20 px** | Jump 정점 lookahead |
| `FALL_LOOKAHEAD_DOWN_PX` | int (locked) | **52 px** | Fall lookahead (2.6× asymmetric — 착지 위협 우세) |

**Output range**: bounded −20..+52. REWINDING/DYING 시 즉시 클램프 (lerp 미적용)로 rewind 경계를 넘는 residual 방지 (Pillar 1 DT-CAM-1 0 px drift).

**Worked example** — JUMP → APEX → FALL key frames (per-tick `lerp(y, target, 1/8)`; exponential convergence — *not* linear settle):

| Frame | State | `look_offset.y` (computed, rounded) | % to target |
|---|---|---|---|
| 0 (JUMPING entry) | JUMPING | 0 (pre-lerp) | 0% |
| 1 | JUMPING | **−2.5** | 13% |
| 4 | JUMPING | **−8.3** | 41% |
| 8 | JUMPING | **−13.1** | 66% |
| 9 (FALLING entry, lerp toward +52) | FALLING | **−5.0** | — (re-targeting from −13.1) |
| 17 (8 ticks into FALLING) | FALLING | **+29.6** | 66% to +52 |
| 24 (16 ticks into FALLING) | FALLING | **+43.7** | 87% |
| 36 (apex-equivalent window) | FALLING | **+50.6** | 97% |

**Note** (Session 22 design-review BLOCKING #2 resolution 2026-05-12): `LOOKAHEAD_LERP_FRAMES = 8`은 *time-constant* (~66% 수렴 frame count)이지 settle frame count가 아니다. 이전 worked example은 ~rate 1/4 수렴값을 표시하여 formula와 양립 불가였음. INV-CAM-5 ("정점 도달 전 settle 완료")는 본 time-constant가 frames_to_apex=36보다 작음 (8<36)이라는 사실로 충족 — 정점에서 ~97% 수렴.

(Pillar 3 — lookahead으로 ECHO 머리 위 공간 확보, 점프 정점에서 콜라주 합성 무너지지 않음.)

---

### F-CAM-4 — Shake Amplitude Decay (per active event, linear)

```
amplitude_this_frame = amplitude_peak_px × (1.0 − frame_elapsed / duration_frames)
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `amplitude_peak_px` | float | 1..10 px | 이벤트 시작 시 peak shake magnitude |
| `frame_elapsed` | int | 0..(duration_frames − 1) | 이벤트 시작 이후 경과 frame |
| `duration_frames` | int | 6..18 | 이벤트 lifetime |
| `amplitude_this_frame` | float | 0..amplitude_peak_px | F-CAM-5에 공급되는 scalar amplitude |

**Output range**: `frame_elapsed == duration_frames` 시 0 (이벤트는 이 frame 직전 active_events에서 제거 — render 전에 사라짐). 단조 감소.

**Worked example** — `shot_fired` (peak=2, duration=6):

| `frame_elapsed` | `amplitude_this_frame` |
|---|---|
| 0 | 2 × (1 − 0/6) = **2.000** |
| 1 | 2 × (1 − 1/6) = **1.667** |
| 2 | 2 × (1 − 2/6) = **1.333** |
| 3 | 2 × (1 − 3/6) = **1.000** |
| 4 | 2 × (1 − 4/6) = **0.667** |
| 5 | 2 × (1 − 5/6) = **0.333** |
| 6 | event removed (≥ duration) |

---

### F-CAM-5 — Shake Vector-Sum + Length Clamp

```
shake_offset = Vector2.ZERO
for each active event e:
    decay = 1.0 − (frame_elapsed_e / duration_frames_e)
    rng.seed = (current_frame × 1_000_003) XOR event_seed_e          # F-CAM-6
    dir = Vector2(rng.randf_range(−1, 1), rng.randf_range(−1, 1)).normalized()
    shake_offset += dir × amplitude_peak_px_e × decay
shake_offset = shake_offset.limit_length(MAX_SHAKE_PX)               # = 12 px
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `shake_offset` | Vector2 | length ≤ 12 px | `camera.offset`에 쓰일 최종 변위 |
| `dir` | unit Vector2 | normalized | 이벤트별·프레임별 RNG-시드된 방향 |
| `MAX_SHAKE_PX` | int (locked) | **12 px** | 글로벌 length clamp |

**Output range**: 항상 길이 ≤ 12 px (Pillar 2 결정성; Pillar 3 readability floor 보존).

**Worked example** — `shot_fired` (frame 0, amplitude=2) + `player_hit_lethal` (frame 0, amplitude=6) 동시 활성. Worst-case collinear sum = 2 + 6 = 8 px < 12 → **clamp 미작동**. Clamp가 작동하는 시나리오: `boss_killed` (10) + `player_hit_lethal` (6) → sum = 16 → **12 px로 clamped**. 단일 이벤트는 결코 clamp에 도달하지 않음 (INV-CAM-4).

---

### F-CAM-6 — Shake RNG Seed → Direction Unit Vector

```
rng.seed = (current_frame × 1_000_003) XOR event_seed
direction = Vector2(rng.randf_range(−1, 1), rng.randf_range(−1, 1)).normalized()
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `current_frame` | int (≥ 0) | `Engine.get_physics_frames()` 단조 카운터 | ADR-0003 결정성 시계 |
| `1_000_003` | int (prime constant) | — | Avalanche multiplier; 작은 frame 값에서의 cycle-1 패턴 회피 |
| `event_seed` | int (≥ 0) | 카메라 인스턴스 단조 카운터, emit handler마다 +1 | per-event 고유 시드 |
| `direction` | unit Vector2 | normalized | (current_frame, event_seed) 쌍에 의해 결정 |

**Output range**: `direction.length() ≈ 1.0`. (`(0,0)` 확률 = `randf_range`의 정확한 0 발생 확률 — Godot PCG 구현에서 negligible; `.normalized()`은 zero-vector 입력 시 zero를 반환하므로 worst case는 1 frame zero shake로 graceful.)

**Reproducibility 검증**: `frame=100`, `event_seed=0` → `rng.seed = 100 × 1_000_003 XOR 0 = 100_000_300`. Engine.get_physics_frames + per-event counter의 두 정수만으로 결정되므로 same build + same input sequence → bit-identical direction (Pillar 2 ADR-0003 R-RT3-02 guarantee). `hash()` 함수는 명시적으로 미사용 — Godot 4.6 patch-stability 미보장 (R-C1-7 + gameplay-programmer 검증 2026-05-12).

---

### F-CAM-7 — Settle Time for Position Smoothing (reference formula)

```
frames_to_settle = ceil(log(ε / δ) / log(1 − speed × delta))
```

| Variable | Type | Description |
|---|---|---|
| `δ` | float | Initial offset to target (px) |
| `ε` | float | Tolerance — frames to come within ε px (px) |
| `speed` | float | `position_smoothing_speed` (32.0 Tier 1 default) |
| `delta` | float | `_physics_process` delta (1/60 ≈ 0.01667 s @ 60 Hz) |

**Worked example** — `δ = 64 px` (DEADZONE_HALF_X step), `ε = 1 px`, `speed = 32.0`, `delta = 1/60`:
- `1 − 32 × 0.01667 = 1 − 0.5333 = 0.4667` per frame multiplier
- `log(1/64) / log(0.4667) = log(0.0156) / log(0.4667) ≈ −4.16 / −0.762 ≈ 5.46`
- `ceil(5.46) = 6` frames (실용적으로 5-frame 시점 잔여 ≈ `64 × 0.4667^5 ≈ 0.9 px` — 시각 감지 불가 수준).

본 공식은 R-C1-11 `position_smoothing_speed = 32.0` 선택의 정당화 근거 (INV-CAM-3 cross-knob invariant 검증).

---

### G.3 Cross-Knob Invariants

본 invariants는 G (Tuning Knobs)에서 노출되는 값들이 서로 어떤 관계를 유지해야 게임플레이가 깨지지 않는지 명시한다. CI / boot-time assert 후보.

| ID | Invariant | Formal condition | Serves Pillar |
|---|---|---|---|
| **INV-CAM-1** | `shot_fired` shake가 다음 발사 전 완전 감쇠 | `shot_fired_duration_frames (6) < FIRE_COOLDOWN_FRAMES (10)` — 4-frame 자연 gap; sustained fire 시 micro shake 누적 구조적 차단 | P2 (예측 가능성), P3 (가독성) |
| **INV-CAM-2** | Peak shake가 가독성 readable third 침범 안 함 | `MAX_SHAKE_PX (12) << viewport_width / 6 (=213 px)` — worst case clamp 작동 시에도 보스 silhouette는 readable third 중심부 유지 (DT-CAM-2 검증) | P3 (콜라주 시그너처) |
| **INV-CAM-3** | Smoothing이 deadzone trigger 윈도 내 settle | `frames_to_settle(δ=64, ε=1, speed=32, delta=1/60) ≤ 6` (F-CAM-7) — 카메라는 데드존 cross 후 6 frame 이상 player 뒤처지지 않음 | P1 (sub-second restart 정합), P2 |
| **INV-CAM-4** | 단일 shake 이벤트가 clamp 단독 도달 불가 | All peak {2, 6, 10} < `MAX_SHAKE_PX (12)` — clamp는 multi-event collinear worst-case sum에만 engage | P2, P3 |
| **INV-CAM-5** | Vertical lookahead가 점프 정점 도달 전 settle 완료 | `LOOKAHEAD_LERP_FRAMES (8) < frames_to_apex (=36)` — `frames_to_apex = jump_velocity_initial / gravity_rising × 60 = 480/800 × 60 = 36`. Lookahead은 정점 28 frame 전에 settle 완료 → DT-CAM-2 holds | P2, P3 |
| **INV-CAM-6** | Tuning knob safe-range 하한 — designer misconfig 방지 (E-CAM-9) | `SHOT_FIRED_DURATION_FRAMES > 0` ∧ `PLAYER_HIT_LETHAL_DURATION_FRAMES > 0` ∧ `BOSS_KILLED_DURATION_FRAMES > 0` ∧ `POSITION_SMOOTHING_SPEED > 0.0` — F-CAM-4 division-by-zero / lerp lock 방지 | P2 (production stability) |

**Boot-time assert 후보** (Tier 1 `tools/ci/camera_static_check.sh`에서 정적 검증; H.5에 acceptance criteria로 등록):
```
assert(shot_fired_duration_frames < FIRE_COOLDOWN_FRAMES)              # INV-CAM-1
assert(MAX_SHAKE_PX × 6 < viewport_width)                              # INV-CAM-2 (실수에 안전한 정수 변형)
assert(LOOKAHEAD_LERP_FRAMES < int(jump_velocity_initial / gravity_rising × 60))  # INV-CAM-5
assert(shot_fired_duration_frames > 0)                                 # INV-CAM-6
assert(player_hit_lethal_duration_frames > 0)                          # INV-CAM-6
assert(boss_killed_duration_frames > 0)                                # INV-CAM-6
assert(position_smoothing_speed > 0.0)                                 # INV-CAM-6
```

## E. Edge Cases

본 섹션은 Section C 규칙과 Section D 공식이 다루지 않는 모서리 시나리오를 명시한다. 각 항목은 분류 태그를 가진다:

- **[DESIGN-RESOLVED]**: 이미 본 GDD가 정의한 contract 또는 invariant로 해결됨.
- **[CROSS-DOC]**: 다른 GDD의 contract / assert로 해결되며 Phase 5 cross-doc 배치에 포함.
- **[ESCALATE-TO-C]**: 본 항목이 Section C 규칙 amendment를 트리거 (이미 본 세션에서 적용).
- **[DEFERRED-PLAYTEST]**: Tier 1 플레이테스트 데이터 필요.
- **[WONT-FIX-COSMETIC]**: 실용적으로 발생 불가 또는 visual-only.

---

**E-CAM-1 (wall-pinch deadzone drift)** [ESCALATE-TO-C / **applied 2026-05-12** + amended Session 22 BLOCKING #1]: 원본 unified `camera = target + look_offset` 모델에서 wall-pinch 시 `look_offset.x`가 directional deficit를 누적하여 reversal lag 발생 위험이 있었다. **현재 split-H/V 모델 (DEC-CAM-A5)에서는 `look_offset.x`가 존재하지 않으므로 deficit 누적이 구조적으로 발생하지 않는다** — Godot 내장 `limit_*` clamp가 매 tick advance를 흡수. **해결**: R-C1-3 limit-boundary guard는 defense-in-depth로 유지 (camera clamp 상태 + delta_x가 clamp 방향이면 advance skip) — Godot clamp 실패 시 또는 limit setter race condition에 대한 보호.

**E-CAM-2 (signal dispatch order — umbrella resolution)** [DESIGN-RESOLVED]: 같은 tick의 모든 게임플레이 시그널은 `process_physics_priority` ladder 순서로 동기 dispatch된다 (Player=0, TRC=1, Damage=2, enemies=10, projectiles=20, Camera=30 — 항상 마지막). 카메라는 모든 게임플레이 source가 settle한 뒤에야 시그널을 처리 — 이 한 가지 contract가 아래 E-CAM-3/4/5 모두를 구조적으로 해결한다. ADR-0003 R-RT3-05 정합.

**E-CAM-3 (rewind_completed + boss_killed same frame)** [DESIGN-RESOLVED — cites E-CAM-2]: 같은 tick에 둘 다 emit되면 dispatch 순서는 emitter priority 따름 (TRC=1 < Damage=2 → `rewind_completed` 먼저). R-C1-9가 `active_events.clear()` + reset_smoothing()을 먼저 수행하고, 그 다음 `boss_killed` 핸들러가 fresh 카타르시스 shake event 추가. 결과: 카메라는 rewind 종료 시점에 단 하나의 shake event를 갖고 cross-contamination 없음.

**E-CAM-4 (rewind_started while boss_killed shake mid-decay)** [DESIGN-RESOLVED]: R-C1-8이 `is_rewind_frozen = true` 설정 → R-C1-2가 매 tick R-C1-1 skip. 활성 shake event들은 timer 내부 카운트다운을 계속하나 visual에 미반영 (R-C1-2 short-circuit). R-C1-9가 `rewind_completed` 시 `active_events.clear()` 강제 호출하여 모든 잔여 decay 폐기. Rewind 경계를 넘는 잔여 shake 없음 — Pillar 1 "시선은 되감기지 않는다" literal.

**E-CAM-5 (scene_post_loaded during rewind freeze)** [DESIGN-RESOLVED]: SM C.2.1 lifecycle은 POST-LOAD phase에서만 `scene_post_loaded` emit하며, POST-LOAD는 in-flight rewind와 시간 겹치지 않는다 (rewind는 ALIVE state 안에서만 발동 가능). 만일 race가 발생해도 R-C1-10이 unconditional하게 `is_rewind_frozen = false`를 명시 설정한 뒤 snap을 수행하므로 안전 (defensive — contract violation 시 graceful 종료).

**E-CAM-6 (shot_fired during rewind freeze)** [CROSS-DOC]: Tier 1에서 발생 불가 — Player Shooting #7 C.1 Rule 1이 `fire` 입력을 `PlayerMovementSM not in REWINDING` state에서만 dispatch하도록 게이트. Camera 측 defensive handler 불필요 — upstream gate가 contract boundary. **Cross-doc 의무**: Player Shooting #7 의 fire gate가 REWINDING + DYING state에서 차단됨을 Camera #3가 의존함을 player-shooting.md F.4.2 row에 명시 (이미 Player Shooting #7 F.4.2 row #5 "Camera #3 obligation" 등록 — 본 GDD가 closes).

**E-CAM-7 (invalid `limits: Rect2` from scene_post_loaded)** [CROSS-DOC]: `limits.size.x ≤ 0` 또는 `limits.size.y ≤ 0` (zero-size 또는 inverted Rect2) → Camera2D `limit_*` setter가 의미 없는 값을 받아 player가 즉시 visible world 밖으로 escape. **해결**: scene-manager.md C.2.1 emit 직전에 boot-time assert 추가 — `assert(limits.size.x > 0 and limits.size.y > 0)`. Phase 5 cross-doc 배치 항목 (C.3.3 table 추가 항목).

**E-CAM-8 (player node freed while camera still ticking)** [DESIGN-RESOLVED]: Tier 1에서 Camera2D는 PlayerMovement와 stage root의 형제 노드. Scene Manager C.2.4 teardown은 stage subtree 전체를 atomic하게 free — Camera는 PlayerMovement와 동일한 tree-free call에서 함께 free된다. Camera가 freed `target`을 가진 채 tick하는 윈도 없음. `is_instance_valid()` 방어 코드는 Tier 2+ 멀티 씬 아키텍처용 (Tier 1 불필요).

**E-CAM-9 (designer misconfig — `duration_frames ≤ 0`, `position_smoothing_speed = 0`)** [DESIGN-RESOLVED via **INV-CAM-6**]: F-CAM-4가 0 또는 음수 `duration_frames`에 division-by-zero; `position_smoothing_speed = 0`은 lerp factor 0 → 카메라 영구 lock. 둘 다 designer 오타. **새 invariant INV-CAM-6** 추가 (G.3 표 + `tools/ci/camera_static_check.sh` boot-time assert):

```
assert(SHOT_FIRED_DURATION_FRAMES > 0)
assert(PLAYER_HIT_LETHAL_DURATION_FRAMES > 0)
assert(BOSS_KILLED_DURATION_FRAMES > 0)
assert(POSITION_SMOOTHING_SPEED > 0.0)
```

본 4개 assert는 G의 tuning knob 정의에서 각 knob의 "safe range" 하한과 일치.

**E-CAM-10 (event_seed overflow / stray second Camera2D)** [WONT-FIX-COSMETIC]: `event_seed`는 GDScript `int` (64-bit signed). 6 rps sustained fire @ 60 Hz로 overflow까지 ≈ 97 billion years — 비실용적. Stray 두 번째 Camera2D 노드가 `make_current()` 호출 (debug probe, editor artifact) → 원본 카메라의 signal은 정상 처리되나 rendering이 두 번째 카메라로 전환. 둘 다 Tier 1 single-camera 단일 인스턴스 배포에서 운영상 비이슈. 코드 변경 불필요.

**E-CAM-11 (player position NaN/Inf)** [DESIGN-RESOLVED — upstream contract]: PlayerMovement는 ADR-0003 R-RT3-01에 의해 결정론적 transform writer; NaN/Inf는 ADR-0002 PlayerSnapshot 시리얼라이제이션에서 발생 불가 (primitive float fields가 valid). Camera는 player.global_position을 신뢰 — 별도 validation 불필요. Tier 2 enemy/projectile bug로 player가 invalid position에 도달하면 PlayerMovement 측 boot assert가 우선 발화.

**E-CAM-12 (deadzone span > viewport width — Tier 2 risk)** [DEFERRED-PLAYTEST]: Tier 1 viewport_width = 1280, DEADZONE_HALF_X = 64 → deadzone 128 px ≪ 1280, 안전 margin 충분. Tier 2에서 viewport 축소 (옵션 메뉴 letterbox) 또는 deadzone 확대 시 `2 × DEADZONE_HALF_X < viewport_width` invariant 유지 필요 — 현재 미발생, Tier 2 도입 시 INV-CAM-2 family에 추가 검토.

---

### E.S — Section E Summary

| Edge case | Resolution | Where applied |
|---|---|---|
| E-CAM-1 | Section C R-C1-3 limit-boundary guard | **applied this session 2026-05-12** |
| E-CAM-2..5 | DESIGN-RESOLVED by signal priority ladder + R-C1-2/8/9/10 | No edit needed |
| E-CAM-6 | CROSS-DOC — Player Shooting #7 fire gate (closes F.4.2 #5) | Phase 5 verify (no new edit) |
| E-CAM-7 | CROSS-DOC — scene-manager.md boot assert | **Phase 5 batch — new C.3.3 row** |
| E-CAM-8 | DESIGN-RESOLVED (Tier 1 scope) | — |
| E-CAM-9 | New INV-CAM-6 + `camera_static_check.sh` boot asserts | **G.3 amendment + new tooling deliverable** |
| E-CAM-10 | WONT-FIX-COSMETIC | — |
| E-CAM-11 | DESIGN-RESOLVED — upstream ADR-0003 / ADR-0002 contract | — |
| E-CAM-12 | DEFERRED-PLAYTEST (Tier 2) | OQ로 등록 (Z 섹션) |

## F. Dependencies

### F.1 — Upstream Dependencies (Camera depends on)

| # | System | Status | Interface | Hard / Soft | Description |
|---|---|---|---|---|---|
| 1 | **Scene Manager #2** | Approved (RR7 PASS 2026-05-11) | `scene_post_loaded(anchor: Vector2, limits: Rect2)` signal — **Q2 deferred, Camera #3 first-use trigger** | **HARD** | Camera snap to anchor + stage limit set on checkpoint restart / cold-boot / stage clear. 60-tick budget compliance. |
| 2 | **Player Movement #6** | Approved (re-review 2026-05-11) | `target.global_position` (Vector2 read per tick) | **HARD** | R-C1-1 / R-C1-3 / R-C1-4 모두 ECHO position을 follow base로 사용. ADR-0003 R-RT3-01 (CharacterBody2D + 직접 transform) 정합. |
| 3 | **State Machine #5** (PlayerMovementSM) | Approved (Round 2 + Round 5) | `player_movement_sm.state` read (state enum: IDLE/RUN/JUMPING/FALLING/REWINDING/DYING) | **HARD** | R-C1-4 state-scaled lookahead target_y 선택; REWINDING/DYING 시 즉시 0 클램프. |
| 4 | **Damage #8** | LOCKED for prototype (Round 5 cross-doc S1 fix) | `player_hit_lethal(_cause: StringName)` + `boss_killed(boss_id: StringName)` signals | **HARD** | R-C1-5 shake event 시작 (각각 6 px / 12f, 10 px / 18f). `boss_killed`는 damage.md F.4 LOCKED single-source authority. |
| 5 | **Time Rewind #9** | Approved (Round 2 + Round 5 + cross-review B1+B2 fix) | `rewind_started()` + `rewind_completed(player: PlayerMovement, restored_to_frame: int)` signals (canonical signature per W2 housekeeping 2026-05-10) | **HARD** | R-C1-8 freeze + R-C1-9 unfreeze/clear/snap — Pillar 1 "시선은 되감기지 않는다" 정합 + DT-CAM-1 검증. |
| 6 | **Player Shooting #7** | Approved (re-review Round 2 2026-05-11) | `shot_fired(weapon_id: int)` signal — Player Shooting F.4.2 row #5 "Camera #3 obligation" registered | **SOFT** | R-C1-5 micro shake (2 px / 6f). 게임플레이 정상 작동에 비필수 — shake 차단 시에도 코어 루프 작동. P3 폴리시 기여. |
| 7 | **ADR-0003 (Determinism)** | Accepted 2026-05-09 | `process_physics_priority = 30` 슬롯 (player=0/TRC=1/Damage=2/enemies=10/projectiles=20 ladder의 다음 슬롯) + `Engine.get_physics_frames()` 결정성 시계 + `RandomNumberGenerator` per-event 시드 | **HARD** | R-C1-7 / R-C1-11 / F-CAM-6 모두 ADR-0003 contract 위에 구축. shake가 ADR-0003 strict 채택 (cosmetic exemption 거부). |
| 8 | **ADR-0002 (Snapshot 9-field)** | Accepted (Amendment 2 ratified via Player Shooting #7) | **Negative dependency** — Camera state는 PlayerSnapshot에 **포함되지 않는다** | **HARD** | DEC-CAM-A2 lock; new forbidden pattern `camera_state_in_player_snapshot` (Phase 5 architecture.yaml 등록). 본 결정이 B의 player fantasy headline "카메라는 잊지 않는다" 의 architectural 원천. |
| 9 | **art-bible.md** | Approved (Session 15 ABA-1..4 applied) | 1280×720 baseline + readable third composition principle | **SOFT** | Pillar 3 콜라주 시그너처 보존을 위한 readable third 정의 (INV-CAM-2). DT-CAM-2 검증 criterion 출처. |

---

### F.2 — Downstream Dependents (these systems depend on Camera)

| # | System | Status | What they need from Camera | Source GDD |
|---|---|---|---|---|
| 1 | **HUD #13** | Not Started | Camera coordinate system 참조 (screen-anchored UI vs world-anchored boss HP bar). Camera는 HUD가 직접 구독할 signal을 emit하지 않음 — HUD가 Camera Node의 `get_screen_center_position()` 또는 viewport transform을 직접 read. | F.4.2 row #1 |
| 2 | **VFX / Particle #14** | Not Started | Screenshake state read (camera.offset)로 particle emitter가 world vs viewport-anchored 결정. Time Rewind Visual Shader #16과 별도 timing. | F.4.2 row #2 |
| 3 | **Stage / Encounter #12** | Not Started | Stage scene이 카메라의 `limits: Rect2`를 `scene_post_loaded` payload에 전달 (Scene Manager #2 C.2.1 emit 직전 stage root에서 query). `Marker2D` `StageBoundsMin` / `StageBoundsMax` 또는 stage root export var 패턴 중 Stage GDD가 결정. | F.4.2 row #3 |
| 4 | **Boss Pattern #11** | Not Started | Tier 2 진입 시 boss arena 진입에서 camera zoom 또는 locked-locked composition 요청 — Tier 1 deferred (DEC-CAM-A4 lock). Boss GDD 작성 시 본 GDD revision으로 `boss_arena_entered(arena_rect: Rect2)` 등 시그널 추가 검토. | F.4.2 row #4 (deferred Tier 2) |
| 5 | **Time Rewind Visual Shader #16** | Not Started | Shader fade timing이 R-C1-9 `reset_smoothing()` 호출과 align되어야 ux-designer F3 답변의 option (c) "shader inherits camera snap" 작동. Shader GDD 작성 시 본 GDD `rewind_completed` 핸들러 순서 시퀀스 참조. | F.4.2 row #5 |

---

### F.3 — Interface Contracts (signal signature lock-ins)

본 Camera #3 GDD가 다른 GDD와 lock-in하는 시그널 contracts:

| Signal | Owner | Producers | Consumers | Status |
|---|---|---|---|---|
| `scene_post_loaded(anchor: Vector2, limits: Rect2)` | Scene Manager #2 | Scene Manager only | **Camera #3 first** (Tier 1) → Stage #12 (Tier 2) → HUD #13 (Tier 2) | **Confirmed by this GDD authoring** — Phase 5 cross-doc 배치로 scene-manager.md에 signal 추가 (Q2 deferral closure) |
| `shot_fired(weapon_id: int)` | Player Shooting #7 | Player Shooting only | Camera #3, Audio #4 (deferred), VFX #14 (deferred) | Approved 2026-05-11 (player-shooting.md C.3 + F.4.2 #5) |
| `player_hit_lethal(_cause: StringName)` | Damage #8 | Damage only | Camera #3, Time Rewind #9, EchoLifecycleSM | Approved (damage.md DEC-1 1-arg signature) |
| `boss_killed(boss_id: StringName)` | Damage #8 | Damage F.4 LOCKED single-source | Camera #3, Scene Manager #2, Time Rewind #9 | Approved (damage.md F.4 LOCKED + AC-13 BLOCKING) |
| `rewind_started()` | Time Rewind #9 | TR only | Camera #3, VFX #14 (deferred), Audio #4 (deferred) | Approved (TR Rule 4 + AC-A3) |
| `rewind_completed(player: PlayerMovement, restored_to_frame: int)` | Time Rewind #9 | TR only | Camera #3, VFX #14 (deferred) | Approved (TR canonical signature W2 housekeeping 2026-05-10) |

---

### F.4 — Cross-Doc Reciprocal Obligations

#### F.4.1 — Phase 5 Cross-Doc Batch (BLOCKING for Approved promotion gate)

Camera #3 Designed 상태 promotion은 scene-manager.md F.4.1 RR4 precedent에 따라 다음 cross-doc 배치 적용이 BLOCKING 게이트. 본 GDD가 first-use trigger인 `scene_post_loaded` 시그널 contract를 닫는 edits + 새 architecture/entities registry 항목 + 호스트 GDD systems-index update:

**See C.3.3 table** — 10-row 배치 (9 cross-doc edits + 1 systems-index row update). E-CAM-7의 Rect2 validation assert 포함.

#### F.4.2 — Future-GDD Obligations (downstream systems가 작성 시 의무)

다음 GDD들이 Tier 1 이후 작성될 때 Camera #3 contract와 정합되도록 충족해야 할 의무:

| # | Target GDD | 의무 내용 | 트리거 시점 |
|---|---|---|---|
| 1 | **HUD #13** | HUD GDD는 (a) Camera Node 참조 패턴 선택 (autoload으로 노출 vs `get_tree().get_first_node_in_group("camera")`); (b) screen-anchored vs world-anchored UI element 분류; (c) Camera에 새 signal 요청 시 본 GDD revision으로 처리 | HUD GDD 작성 시 |
| 2 | **VFX / Particle #14** | VFX GDD는 (a) screenshake offset (camera.offset) consume 패턴 정의; (b) world-anchored vs viewport-anchored particle emitter 분류 contract 명시; (c) Time Rewind Visual Shader #16과의 timing 조율 | VFX GDD 작성 시 |
| 3 | **Stage / Encounter #12** | Stage GDD는 (a) stage root에 `limits: Rect2` 노출 패턴 결정 (export var `stage_camera_limits: Rect2` 또는 `Marker2D` 자식 노드 query); (b) Scene Manager가 stage root에서 Rect2 추출 후 `scene_post_loaded` payload에 전달하는 contract 명시 | Stage GDD 작성 시 |
| 4 | **Boss Pattern #11** (Tier 2) | Boss GDD는 boss arena 진입 시 카메라 zoom/lock 동작 요청 시 본 Camera #3 GDD revision으로 `boss_arena_entered(arena_rect: Rect2)` 등 새 signal contract 추가 | Tier 2 진입 시 |
| 5 | **Time Rewind Visual Shader #16** | Shader GDD는 본 Camera #3 R-C1-9 `rewind_completed` 핸들러 순서 시퀀스(freeze 해제 → shake 클리어 → reset_smoothing)와 shader fade timing이 동기화되도록 명시 | Shader GDD 작성 시 |
| 6 | **Player Shooting #7** | (status: **Already done** — Player Shooting F.4.2 row #5 "Camera #3 obligation" 등록 완료 2026-05-11 Round 2). 본 GDD가 closes — Phase 5 verify no edit. | — |

---

### F.5 — Bidirectional Consistency Check

본 GDD의 F.1 (upstream)과 모든 upstream GDD의 F.2 (downstream Camera #3 row)가 일치하는지 verify (단방향 dependency 방지 — design-docs.md 룰 "Dependencies must be bidirectional"):

| Upstream | Camera #3 F.1 row | Their F.2 Camera #3 row 존재? |
|---|---|---|
| Scene Manager #2 | F.1 #1 (HARD) | ✅ scene-manager.md F.2 row Camera #3 (already listed); Phase 5 batch에서 status flip "Q2 deferred" → "resolved (Camera #3 first-use)" |
| Player Movement #6 | F.1 #2 (HARD) | ✅ player-movement.md F.2 row Camera #3 added 2026-05-12 (Phase 5 batch) — read-only `target.global_position` per-tick + camera.md F.1 #2 reciprocal explicit |
| State Machine #5 | F.1 #3 (HARD) | ✅ state-machine.md F.2 row Camera #3 added 2026-05-12 (Phase 5 batch) — read-only state subscriber pattern (Player Shooting #7 row precedent), `transition_to()` 호출 금지 + 6-signal subscribe contract reciprocal |
| Damage #8 | F.1 #4 (HARD) | ✅ damage.md F.2 row Camera #3 added 2026-05-12 (Phase 5 batch) — `player_hit_lethal` (6 px / 12f impact shake) + `boss_killed` (10 px / 18f catharsis shake) consumer; cause taxonomy 무시 |
| Time Rewind #9 | F.1 #5 (HARD) | ✅ time-rewind.md Downstream Dependents row Camera #3 added 2026-05-12 (Phase 5 batch) — `rewind_started` freeze + `rewind_completed` clear/snap cascade; DT-CAM-1 0 px drift verification path |
| Player Shooting #7 | F.1 #6 (SOFT) | ✅ player-shooting.md F.4.2 row #5 Camera #3 obligation 이미 등록 (Round 2 2026-05-11) |
| ADR-0003 | F.1 #7 (HARD) | ✅ ADR-0003 "Enables" 섹션에 Camera #3는 명시 안 됨 (Player Movement, Damage, Enemy AI, Player Shooting, Boss만 명시) — but Camera 결정성 contract는 ADR-0003 R-RT3-02 / R-RT3-05에 의해 cover됨. ADR revision은 비필요 (downstream relationship implicit). |
| ADR-0002 | F.1 #8 (HARD, negative dep) | ✅ Phase 5 architecture.yaml에 새 forbidden pattern `camera_state_in_player_snapshot` 등록으로 닫힘 |

**Phase 5 cross-doc 배치 (landed 2026-05-12)**: 위 4건 reciprocity (Player Movement / State Machine / Damage / Time Rewind 에 Camera #3 downstream row 추가) + C.3.3 원본 10-row = 총 14-row 배치 적용 완료. Bidirectional-dep 룰 (`.claude/rules/design-docs.md`) 충족. F.5 row status 모두 ✅ 전환.

## G. Tuning Knobs

본 섹션은 Camera #3가 노출하는 designer-tunable 값을 명시한다. 모든 knob은 `@export` annotation으로 Godot inspector에 노출하고, `assets/data/camera.tres` Resource (Tier 1 단일 인스턴스)에 default를 기록한다. Section D의 INV-CAM-1..6 invariants가 cross-knob constraint를 정의 — knob 값 변경은 invariants를 위반하지 않아야 한다 (boot-time assert로 강제 검증).

### G.1 Knob Catalog

#### G.1.1 — Follow Knobs

| Knob | Default | Safe Range | Unit | Effect | Cross-knob constraints |
|---|---|---|---|---|---|
| `DEADZONE_HALF_X` | **64** | 32..128 | px | 수평 데드존 half-width. 작을수록 카메라가 ECHO를 빠르게 따라옴(Celeste-tight) / 클수록 자유 이동 폭 늘어남(Contra-loose). | INV-CAM-3: `position_smoothing_speed` 적정성에 영향 (큰 deadzone은 큰 step → 5-frame settle 가능 여부) |
| `JUMP_LOOKAHEAD_UP_PX` | **20** | 12..32 | px (음수 방향) | JUMPING state에서 카메라가 viewport 위쪽으로 미리 이동하는 양. 작을수록 ECHO 머리 위 정보 줄어듦. | — |
| `FALL_LOOKAHEAD_DOWN_PX` | **52** | 32..72 | px (양수 방향) | FALLING state에서 카메라가 viewport 아래쪽으로 미리 이동하는 양. Run-and-gun 착지 위협 가독성 핵심. | INV-CAM-5: lookahead가 정점 도달 전 settle 완료 |
| `LOOKAHEAD_LERP_FRAMES` | **8** | 4..16 | frames | state entry/exit 시 lookahead lerp 완료 시간. 작을수록 snappy / 클수록 cinematic. | INV-CAM-5: `< frames_to_apex (=36)` |
| `POSITION_SMOOTHING_SPEED` | **32.0** | 16.0..64.0 | exponential decay rate | `position_smoothing_speed` Godot 4.6 Camera2D 내장. 작을수록 lag, 클수록 snap. | INV-CAM-3: 64 px step ≤ 5 frame settle; INV-CAM-6: `> 0.0` |

#### G.1.2 — Shake Knobs

| Knob | Default | Safe Range | Unit | Effect | Cross-knob constraints |
|---|---|---|---|---|---|
| `MAX_SHAKE_PX` | **12** | 6..20 | px | 글로벌 shake length clamp (F-CAM-5). 작을수록 가독성 우선, 클수록 임팩트 우선. | INV-CAM-2: `× 6 < viewport_width (=1280)` ⇒ ≤ 213 readable third |
| `SHOT_FIRED_PEAK_PX` | **2** | 1..3 | px | 미세 진동 peak amplitude. | INV-CAM-4: `< MAX_SHAKE_PX` |
| `SHOT_FIRED_DURATION_FRAMES` | **6** | 3..9 | frames | 미세 진동 lifetime. 짧을수록 sustained fire 가독성 우선. | INV-CAM-1: `< FIRE_COOLDOWN_FRAMES (=10)`; INV-CAM-6: `> 0` |
| `PLAYER_HIT_LETHAL_PEAK_PX` | **6** | 4..8 | px | 1히트 즉사 impact shake peak. 사망 카타르시스 신호 강도. | INV-CAM-4: `< MAX_SHAKE_PX` |
| `PLAYER_HIT_LETHAL_DURATION_FRAMES` | **12** | 6..18 | frames | impact shake lifetime. | INV-CAM-6: `> 0` |
| `BOSS_KILLED_PEAK_PX` | **10** | 8..12 | px | 보스 격파 카타르시스 shake peak. 가장 강한 단일 이벤트. | INV-CAM-4: `< MAX_SHAKE_PX (=12)` (default 10 / cap 12 — 2 px headroom) |
| `BOSS_KILLED_DURATION_FRAMES` | **18** | 12..30 | frames | 보스 격파 shake lifetime. Tier 1 카타르시스 0.3 s 길이. | INV-CAM-6: `> 0` |

#### G.1.3 — Locked (Tier 1 — not tunable)

| Knob | Locked Value | Reason | Tier 2 review |
|---|---|---|---|
| `zoom` | `Vector2(1.0, 1.0)` | DEC-CAM-A4 lock — Pillar 5 (작은 성공) + art-bible 1280×720 baseline 정합 | Tier 2 boss zoom 도입 시 본 lock 해제, Boss Pattern #11 GDD에서 hook 정의 |
| `process_callback` | `CAMERA2D_PROCESS_PHYSICS` | godot-specialist V2 — `IDLE` mode는 player transform과 1-tick out-of-phase → rewind snap 깨짐 | Tier 2 unchanged (deterministic core) |
| `process_physics_priority` | `30` | ADR-0003 ladder slot (player=0, TRC=1, Damage=2, enemies=10, projectiles=20). 모든 gameplay source가 settle한 뒤 카메라 계산 | Tier 2 enemy AI 추가 시에도 30 유지 (40 free for future systems) |
| `position_smoothing_enabled` | `true` | gameplay-programmer Q2 — toggle 대신 `reset_smoothing()` 단일 snap path 사용 | Tier 2 unchanged |

---

### G.2 Tuning Resource Pattern (Godot 4.6)

```gdscript
class_name CameraTuning extends Resource

@export_range(32, 128) var deadzone_half_x: int = 64
@export_range(12, 32)  var jump_lookahead_up_px: int = 20
@export_range(32, 72)  var fall_lookahead_down_px: int = 52
@export_range(4, 16)   var lookahead_lerp_frames: int = 8
@export_range(16.0, 64.0, 0.5) var position_smoothing_speed: float = 32.0

@export_range(6, 20)   var max_shake_px: int = 12
@export_range(1, 3)    var shot_fired_peak_px: int = 2
@export_range(3, 9)    var shot_fired_duration_frames: int = 6
@export_range(4, 8)    var player_hit_lethal_peak_px: int = 6
@export_range(6, 18)   var player_hit_lethal_duration_frames: int = 12
@export_range(8, 12)   var boss_killed_peak_px: int = 10
@export_range(12, 30)  var boss_killed_duration_frames: int = 18
```

Camera 노드는 `@export var tuning: CameraTuning = preload("res://assets/data/camera.tres")` 로 reference. 인스펙터에서 default `camera.tres` 외 alternate tuning Resource로 swap 가능 (Tier 2 difficulty toggle 또는 Steam Deck-specific 튜닝 슬롯).

---

### G.3 Cross-Knob Invariants — 이미 D.G.3에 명시 (INV-CAM-1..6)

G.1의 cross-knob constraints column은 D.G.3 invariant 표를 참조한다. Knob value 변경 시 invariant violation 발생하면 boot-time assert 발화 — `tools/ci/camera_static_check.sh`가 release fixture에서 0 emit 검증 (H.5에 acceptance criteria 등록).

**Knob 간 의도된 상호작용** (knob A 변경이 knob B를 무의미하게 만드는 관계):

| Knob A 변경 | Knob B 영향 |
|---|---|
| `DEADZONE_HALF_X` ↑ | `POSITION_SMOOTHING_SPEED` 재튜닝 필요 — 큰 deadzone은 큰 step → INV-CAM-3 5-frame settle 위반 위험 |
| `MAX_SHAKE_PX` ↓ | 모든 `*_PEAK_PX` 비례 검토 — peak가 clamp에 너무 자주 닿으면 차별성 손실 |
| `FIRE_COOLDOWN_FRAMES` (Player Shooting #7 owns) ↓ | `SHOT_FIRED_DURATION_FRAMES` 재검토 — INV-CAM-1 violation 위험 (sustained fire에서 미세 진동 누적) |
| `jump_velocity_initial` / `gravity_rising` (Player Movement #6 owns) 변경 | `LOOKAHEAD_LERP_FRAMES` 재검토 — INV-CAM-5 `< frames_to_apex` violation 위험 |

위 4개 의존성은 architecture.yaml `interfaces.camera_tuning_dependencies` 새 항목으로 등록 (Phase 5 batch).

---

### G.4 Designer Notes

- **첫 playtest 우선 튜닝 후보**: `FALL_LOOKAHEAD_DOWN_PX` (52 px가 Steam Deck 1세대 720p screen에서 적정한지 — DT-CAM-2 미세 조정 가능).
- **Tier 1 미사용 reserved**: zoom, vertical drag margins (drag_top_margin / drag_bottom_margin Godot 내장 미사용 — R-C1-4의 lerp가 대체). Tier 2 boss arena 도입 시 zoom + drag margin 추가 검토.
- **Audio 연계**: 본 GDD는 audio knobs를 노출하지 않음 — shake 강도가 Audio #4의 SFX ducking 강도와 align할지는 Audio GDD 작성 시 결정 (`amplitude_peak_px` × ducking_coefficient 같은 derived signal 가능).

## H. Acceptance Criteria

### H.0 Preamble

총 **26 AC**. 분류: **20 BLOCKING** (Logic 18 / Integration 2) + **6 ADVISORY** (Config 1 / Visual-Feel 5).

**Counting convention**: shake 이벤트 3종(`shot_fired` / `player_hit_lethal` / `boss_killed`)은 동일 test path의 파라미터 변형으로 통합되며 각 variant를 별도 AC로 카운트하지 않는다 (AC-CAM-H3-01 parameterized fixture가 3종 cover). ADVISORY-Visual/Feel ACs (H.X)는 자동화 불가능 → 매뉴얼 sign-off 의무.

**BLOCKING 분포 검증** (per coding-standards.md Test Evidence by Story Type):
- Logic BLOCKING (18): H.1×5 + H.2×4 + H.3×4 + H.4×3 + H.5×1 + H.6×1 = 18 ✓
- Integration BLOCKING (2): AC-CAM-H4-04 + AC-CAM-H5-02 = 2 ✓
- ADVISORY (6): AC-CAM-H6-02 (Config) + AC-CAM-HX-01..05 (Visual/Feel) = 6 ✓

---

### H.1 Per-Frame Position + Deadzone (R-C1-1, R-C1-3, F-CAM-1/2, E-CAM-1)

**AC-CAM-H1-01** [BLOCKING-Logic] — **GIVEN** `camera.x = 500`, `look_offset.y = 0`, no shake, `target.x = 565`; **WHEN** `_physics_process(1/60)` runs once; **THEN** `camera.global_position.x == 501.0` AND `look_offset.x == 0.0` (unused per DEC-CAM-A5).
- Covers: R-C1-1 horizontal incremental advance, R-C1-3, F-CAM-2 worked example.
- Test: `tests/unit/camera/test_deadzone_edge_crossing_advances_one_pixel.gd`.
- Mechanism: inject `MockTarget`, set fields, call `_physics_process`, assert `camera.global_position.x == 501` (split-H/V incremental).

**AC-CAM-H1-02** [BLOCKING-Logic] — **GIVEN** `camera.x = 500`, `target.x = 520` (delta=20 ≤ 64); **WHEN** one tick runs; **THEN** `camera.global_position.x == 500.0` (데드존 내부 — advance 없음).
- Covers: R-C1-3 (deadzone inside no-update branch).
- Test: `tests/unit/camera/test_deadzone_inside_no_camera_move.gd`.

**AC-CAM-H1-03** [BLOCKING-Logic] — **GIVEN** active ShakeEvent with `shake_offset == Vector2(5, 3)` (frozen direction via RNG override), `look_offset.y = 10`, `target.x` inside deadzone (no horizontal advance); **WHEN** one tick runs; **THEN** `camera.global_position.y == target.global_position.y + 10` AND `camera.offset == Vector2(5, 3)` (수직 쓰기와 offset 쓰기 site 독립 assert).
- Covers: R-C1-1 split-H/V dual-write contract (load-bearing per F-CAM-1) — shake가 vertical follow에 흐려지지 않음.
- Test: `tests/unit/camera/test_position_and_offset_write_sites_independent.gd`.
- Mechanism: inject deterministic ShakeEvent, override RNG seed for direction control, assert `camera.global_position.y`와 `.offset`를 별도 비교.

**AC-CAM-H1-04** [BLOCKING-Logic] — **GIVEN** `camera.global_position.x == limit_left == 100`, `target.x = 30` (delta_x = −70, |−70| > 64); **WHEN** one tick runs; **THEN** wall-pinch guard fires → `camera.global_position.x == 100` (변경 없음; advance skip).
- Covers: R-C1-3 wall-pinch guard, E-CAM-1 defense-in-depth resolution.
- Test: `tests/unit/camera/test_wall_pinch_guard_no_deficit.gd`.

**AC-CAM-H1-05** [BLOCKING-Logic] — **GIVEN** camera wall-pinched at `limit_left = 100` for 10 ticks (target oscillating left of camera, guard firing each tick), then player reverses right; **WHEN** `target.x` first exceeds `camera.x + DEADZONE_HALF_X (=164)`; **THEN** 같은 tick 안에 `camera.global_position.x` advances (즉시 follow — split-H/V 모델에서 deficit 누적이 구조적으로 발생하지 않으므로 reversal lag 없음).
- Covers: R-C1-3 guard 검증, E-CAM-1 retrofit fix, F-CAM-2.
- Test: `tests/unit/camera/test_wall_pinch_guard_reversal_no_lag.gd`.

---

### H.2 Vertical Lookahead State Lerp (R-C1-4, F-CAM-3)

**AC-CAM-H2-01** [BLOCKING-Logic] — **GIVEN** player `state=JUMPING`, `look_offset.y=0`; **WHEN** 8 ticks 경과; **THEN** `look_offset.y`가 **−13.1 ± 0.5 px** 범위 (per F-CAM-3 time-constant — target −20에 ~66% 수렴; ≥99% 수렴은 frame ~36 ≈ apex).
- Covers: R-C1-4, F-CAM-3 worked example frame 8.
- Test: `tests/unit/camera/test_jump_lookahead_lerp_8frames.gd`.
- Mechanism: `MockPlayerMovementSM.state = "JUMPING"`, 8 `_physics_process` 호출, frame-by-frame look_offset.y 기록.
- Note (Session 22 BLOCKING #2 resolution): 이전 `−18.7 ± 1.0` tolerance는 rate 1/4 수렴값으로 잘못 derived. 정정값은 `y_n = −20 × (1 − (7/8)^n)` 으로 계산.

**AC-CAM-H2-02** [BLOCKING-Logic] — **GIVEN** player `state=FALLING`, `look_offset.y=0`; **WHEN** 8 ticks 경과; **THEN** `look_offset.y`가 **+34.1 ± 0.5 px** 범위 (per F-CAM-3 time-constant — target +52에 ~66% 수렴).
- Covers: R-C1-4 FALLING branch, F-CAM-3.
- Test: `tests/unit/camera/test_fall_lookahead_lerp_8frames.gd`.
- Note (Session 22 BLOCKING #2 resolution): 이전 `≥ +47.0` (≥90%) tolerance는 rate 1/4 수렴값으로 잘못 derived; 정정값 계산식 `y_n = +52 × (1 − (7/8)^n)`.

**AC-CAM-H2-03** [BLOCKING-Logic] — **GIVEN** look_offset.y == −15.0 (mid-jump lerp), player state가 REWINDING으로 전이; **WHEN** one tick runs; **THEN** `look_offset.y == 0.0` (즉시 클램프, lerp 미적용).
- Covers: R-C1-4 REWINDING immediate clamp, DT-CAM-1 prerequisite.
- Test: `tests/unit/camera/test_rewind_state_clamps_lookahead_immediately.gd`.

**AC-CAM-H2-04** [BLOCKING-Logic] — **GIVEN** look_offset.y == +30.0, player state가 DYING으로 전이; **WHEN** one tick runs; **THEN** `look_offset.y == 0.0`.
- Covers: R-C1-4 DYING immediate clamp.
- Test: `tests/unit/camera/test_dying_state_clamps_lookahead_immediately.gd`.

---

### H.3 Shake — Decay, Sum-Clamp, RNG Determinism (R-C1-5/6/7, F-CAM-4/5/6)

**AC-CAM-H3-01** [BLOCKING-Logic] — **GIVEN** `shot_fired` ShakeEvent (peak=2, duration=6) at frame F=0; **WHEN** frame_elapsed=3; **THEN** `amplitude_this_frame == 1.0` (= 2 × (1 − 3/6)). Parameterized for `player_hit_lethal` (peak=6, duration=12, elapsed=6 → 3.0) + `boss_killed` (peak=10, duration=18, elapsed=9 → 5.0) — 3종 cover.
- Covers: R-C1-5 timer pool, F-CAM-4 linear decay.
- Test: `tests/unit/camera/test_shake_linear_decay_midpoint.gd`.
- Mechanism: GUT `parameterize` 패턴 — 3 variant 동일 fixture, 각 frame_elapsed에서 amplitude_this_frame assert.

**AC-CAM-H3-02** [BLOCKING-Logic] — **GIVEN** `boss_killed` (peak=10, frame_elapsed=0) + `player_hit_lethal` (peak=6, frame_elapsed=0) 동시 활성, RNG direction을 collinear (1, 0) worst-case로 override; **WHEN** one tick runs; **THEN** `camera.offset.length() <= MAX_SHAKE_PX (=12)`.
- Covers: R-C1-6 sum-clamp, F-CAM-5 worked example, INV-CAM-4.
- Test: `tests/unit/camera/test_shake_sum_clamp_multi_event.gd`.
- Mechanism: inject 두 events, RNG override으로 direction 결정성 보장, assert .offset.length().

**AC-CAM-H3-03** [BLOCKING-Logic] — **GIVEN** event_seed=0, current_frame=100; **WHEN** seed formula `(100 × 1_000_003) XOR 0` 계산 2회; **THEN** 2회 결과 direction 벡터가 bit-identical (component-wise equality assert).
- Covers: R-C1-7 patch-stable formula, F-CAM-6, ADR-0003 R-RT3-02.
- Test: `tests/unit/camera/test_shake_rng_determinism_same_seed_same_direction.gd`.
- Mechanism: 동일 input으로 seed formula 2회 호출, 각각 normalized direction 추출, bit-equal assert.

**AC-CAM-H3-04** [BLOCKING-Logic] — **GIVEN** `shot_fired` 첫 emit at frame 0 (active frames 0..5), 다음 `shot_fired` at frame 10 (FIRE_COOLDOWN_FRAMES 만족); **WHEN** frame 10 도착; **THEN** frame 0..5 event는 이미 active_events에서 제거됨 (frame 6 부터); frame 10의 새 event는 fresh peak로 시작 (stacking 없음).
- Covers: R-C1-5 event lifecycle, INV-CAM-1 (`shot_fired_duration < FIRE_COOLDOWN`), F-CAM-4 decay-to-removal.
- Test: `tests/unit/camera/test_shot_fired_duration_less_than_cooldown_no_stacking.gd`.

---

### H.4 Rewind Freeze / Unfreeze (R-C1-2/8/9, DT-CAM-1, DT-CAM-3)

**AC-CAM-H4-01** [BLOCKING-Logic] — **GIVEN** `rewind_started` 수신 (is_rewind_frozen=true), player.global_position이 +100 px 이동; **WHEN** 5 ticks 경과; **THEN** `camera.global_position`이 last unfrozen tick 값에서 변경 없음.
- Covers: R-C1-2 freeze guard, R-C1-8, Pillar 1 "시선은 되감기지 않는다" literal.
- Test: `tests/unit/camera/test_rewind_freeze_skips_position_update.gd`.

**AC-CAM-H4-02** [BLOCKING-Logic] — **GIVEN** frozen camera at pos P, active shake events 2종, `look_offset.y = −15` (`look_offset.x` 항상 0 per DEC-CAM-A5); **WHEN** `rewind_completed(player, restored_to_frame)` 수신; **THEN** 동일 tick 안에 다음 fields 동시 통과:
  (a) `is_rewind_frozen == false`
  (b) `active_events.size() == 0`
  (c) `shake_offset == Vector2.ZERO`
  (d) `camera.offset == Vector2.ZERO`
  (e) `look_offset == _compute_initial_look_offset(player)` — 즉 `look_offset.x == 0.0` AND `look_offset.y == _target_y_for_state(player.movement_sm.state)` (R-C1-9 inline spec)
  (f) split-H/V: `camera.global_position.x == player.global_position.x` AND `camera.global_position.y == player.global_position.y + look_offset.y`
- Covers: R-C1-9 unfreeze cascade, **DT-CAM-1** 0 px drift 자명 검증, Player Fantasy Framing C headline literal, BLOCKING #3 `_compute_initial_look_offset` spec.
- Test: `tests/unit/camera/test_rewind_completed_clears_all_state.gd`.
- Mechanism: inject frozen camera + stale events, call `_on_rewind_completed`, single-tick에서 fields assert (split-H/V 분리 검증).

**AC-CAM-H4-03** [BLOCKING-Logic] — **GIVEN** `_on_rewind_completed` 구현; **WHEN** GDScript source order inspection; **THEN** `reset_smoothing()` call site가 `global_position = ...` 할당 사이트 *뒤*에 위치.
- Covers: R-C1-9 call order 비협상 (gameplay-programmer Q2 검증: 역순 호출 시 lerp residual 발생).
- Test: `tests/unit/camera/test_rewind_completed_reset_smoothing_order.gd`.
- Mechanism: subclass `CameraSystem`, `reset_smoothing()` 오버라이드로 call index 기록 + `global_position` setter spy → assert `_global_position_set_index < _reset_smoothing_call_index`.

**AC-CAM-H4-04** [BLOCKING-Integration] — **GIVEN** `player_hit_lethal` emit at frame T; **WHEN** timeline 검사; **THEN** frame T에서 `camera.offset.length() > 0` (shake가 동일 frame에 시작) AND frame T+1 이전 frame에 `rewind_started` 미발화.
- Covers: R-C1-5 + DT-CAM-3 ordering — shake가 rewind UI 전에 firing.
- Test: `tests/integration/camera/test_lethal_shake_before_rewind_ui.gd`.
- Mechanism: integration harness — mock `TimeRewindSystem` + mock `Damage`. Damage emits `player_hit_lethal(T)`, frame-by-frame `camera.offset`과 TR `rewind_started` emit 시점 기록, assert temporal ordering.

---

### H.5 Checkpoint Snap (R-C1-10/11/12, F-CAM-7)

**AC-CAM-H5-01** [BLOCKING-Logic] — **GIVEN** `scene_post_loaded(anchor=Vector2(320, 180), limits=Rect2(0, 0, 2560, 720))` 수신; **WHEN** 핸들러 완료; **THEN** 동일 tick에서: `camera.global_position == Vector2(320, 180)`, `limit_left == 0`, `limit_right == 2560`, `limit_top == 0`, `limit_bottom == 720`, `look_offset == Vector2.ZERO`, `shake_offset == Vector2.ZERO`, `active_events.size() == 0`.
- Covers: R-C1-10, R-C1-12.
- Test: `tests/unit/camera/test_scene_post_loaded_snap_and_limits.gd`.

**AC-CAM-H5-02** [BLOCKING-Integration] — **GIVEN** mock SceneManager가 60-tick restart budget 내부 `scene_post_loaded` emit; **WHEN** Camera handler 실행; **THEN** handler 진입과 완료 사이 `Engine.get_physics_frames()` delta ≤ 1 (실제 정상 케이스는 0 — 동일 tick 내 완료).
- Covers: R-C1-10 + R-C1-11 + SM 60-tick budget Pillar 1 정합.
- Test: `tests/integration/camera/test_scene_post_loaded_within_60tick_budget.gd`.

---

### H.6 Invariants + Boot Asserts (INV-CAM-1..6)

**AC-CAM-H6-01** [BLOCKING-Logic] — **GIVEN** default `assets/data/camera.tres` tuning Resource; **WHEN** `tools/ci/camera_static_check.sh`를 release fixture에서 실행; **THEN** 7-assert 모두 통과 + script exit code 0:
```
assert SHOT_FIRED_DURATION_FRAMES (6) < FIRE_COOLDOWN_FRAMES (10)        # INV-CAM-1
assert MAX_SHAKE_PX (12) × 6 < viewport_width (1280)                     # INV-CAM-2
assert LOOKAHEAD_LERP_FRAMES (8) < int(480 / 800 × 60) (=36)             # INV-CAM-5
assert SHOT_FIRED_DURATION_FRAMES > 0                                    # INV-CAM-6
assert PLAYER_HIT_LETHAL_DURATION_FRAMES > 0                             # INV-CAM-6
assert BOSS_KILLED_DURATION_FRAMES > 0                                   # INV-CAM-6
assert POSITION_SMOOTHING_SPEED > 0.0                                    # INV-CAM-6
```
- Covers: INV-CAM-1, INV-CAM-2, INV-CAM-5, INV-CAM-6 (4 invariants 정적 검증).
- Test: `tools/ci/camera_static_check.sh` (PM #6 `pm_static_check.sh` 패턴 정합). CI gate before manual QA hand-off.

**AC-CAM-H6-02** [ADVISORY-Config] — **GIVEN** designer가 G.1 safe range 내에서 임의 tuning Resource 변형 생성 (boundary value 포함 — 최소/최대); **WHEN** Godot editor에서 game boot; **THEN** GDScript runtime assert 발화 없음 + Godot output panel에 boot error/warning log 없음.
- Covers: INV-CAM-6 boot-time enforcement, E-CAM-9 designer misconfig 방지.
- Test: Smoke check — alternate `.tres` boundary fixtures (low + high) 로드 → manual editor boot.

---

### H.X ADVISORY — Visual/Feel Sign-Off Items (자동화 불가, 매뉴얼 sign-off)

**AC-CAM-HX-01** [ADVISORY-Visual] — Pillar 3 콜라주 시그너처 aesthetic — **WHEN** Tier 1 첫 playtest screenshots (peak shake frame at `boss_killed`); **THEN** art-director sign-off: boss silhouette이 readable third (±213 px center) 내부에 있고, 콜라주 합성 readability가 무너지지 않았다.
- Covers: DT-CAM-2 aesthetic half. AC-CAM-H3-02가 spatial math를 BLOCKING으로 검증; 본 AC는 perceptual 검증.
- Evidence: `production/qa/evidence/dt-cam-2-peak-shake-{stage1}.png` + art-director sign-off comment.

**AC-CAM-HX-02** [ADVISORY-Feel] — DT-CAM-3 emotional read — **WHEN** Tier 1 첫 playtest 진행; **THEN** ≥ 3명의 tester가 questionnaire에 "사망 진동이 *결과의 무게*로 느껴짐 (UI chrome으로 읽히지 않음)" 항목에 동의.
- Covers: DT-CAM-3 perceptual half. AC-CAM-H4-04가 temporal ordering BLOCKING.
- Evidence: `production/qa/evidence/playtest-q-dt-cam-3.md`.

**AC-CAM-HX-03** [ADVISORY-Feel] — Follow smoothness — **WHEN** Tier 1 playtest; **THEN** tester가 "카메라가 캐릭터에 lag되거나 floaty하게 느껴짐" 항목에 부정 응답 (POSITION_SMOOTHING_SPEED=32.0 적정).
- Covers: F-CAM-7 + INV-CAM-3 perceptual side.
- Evidence: `production/qa/evidence/playtest-q-camera-feel.md`.

**AC-CAM-HX-04** [ADVISORY-Feel] — Checkpoint snap perception — **WHEN** 사망 후 재시작 시 playtester 인식; **THEN** "화면이 cut되지 않고 즉시 snap되었다"는 응답 우세.
- Covers: R-C1-10 + DT-CAM-1 perceptual half. AC-CAM-H4-02가 spatial 0 drift BLOCKING.
- Evidence: `production/qa/evidence/playtest-q-restart-snap.md`.

**AC-CAM-HX-05** [ADVISORY-Visual] — Lookahead asymmetric ratio (52/20) playtest 검증 — **WHEN** Tier 1 playtest 착지 위협 (스파이크 등) 등장 인카운터; **THEN** tester ≥ 80%가 착지 직전 위협을 보지 못해 죽었다고 보고하지 않음 (Pillar 2 — "운으로 죽지 않음" 정합).
- Covers: R-C1-4 FALL_LOOKAHEAD_DOWN_PX 적정성. E-CAM-12 Tier 2 viewport 변동 시 재검토.
- Evidence: `production/qa/evidence/playtest-q-fall-lookahead.md`.

---

### H.7 0.2-Sec Design Test Coverage Map

각 DT-CAM은 ≥ 1 BLOCKING + ≥ 1 ADVISORY로 양면 cover:

| DT | Spatial (BLOCKING) | Perceptual (ADVISORY) |
|---|---|---|
| **DT-CAM-1** (0 drift rewind complete) | AC-CAM-H4-02, AC-CAM-H4-03, AC-CAM-H2-03 | AC-CAM-HX-04 |
| **DT-CAM-2** (readable third peak shake) | AC-CAM-H3-02 | AC-CAM-HX-01 |
| **DT-CAM-3** (shake before rewind UI) | AC-CAM-H4-04 | AC-CAM-HX-02 |

---

### H.8 Test Deliverables

**(a) Unit test files** (`tests/unit/camera/`):

1. `test_deadzone_edge_crossing_advances_one_pixel.gd`
2. `test_deadzone_inside_no_camera_move.gd`
3. `test_position_and_offset_write_sites_independent.gd`
4. `test_wall_pinch_guard_no_deficit.gd`
5. `test_wall_pinch_guard_reversal_no_lag.gd`
6. `test_jump_lookahead_lerp_8frames.gd`
7. `test_fall_lookahead_lerp_8frames.gd`
8. `test_rewind_state_clamps_lookahead_immediately.gd`
9. `test_dying_state_clamps_lookahead_immediately.gd`
10. `test_shake_linear_decay_midpoint.gd`
11. `test_shake_sum_clamp_multi_event.gd`
12. `test_shake_rng_determinism_same_seed_same_direction.gd`
13. `test_shot_fired_duration_less_than_cooldown_no_stacking.gd`
14. `test_rewind_freeze_skips_position_update.gd`
15. `test_rewind_completed_clears_all_state.gd`
16. `test_rewind_completed_reset_smoothing_order.gd`
17. `test_scene_post_loaded_snap_and_limits.gd`

**(b) Integration test files** (`tests/integration/camera/`):

1. `test_lethal_shake_before_rewind_ui.gd` — mock `TimeRewindSystem` + mock `Damage` harness
2. `test_scene_post_loaded_within_60tick_budget.gd` — mock `SceneManager` emitter fixture

**(c) CI tooling**:

1. `tools/ci/camera_static_check.sh` — `assets/data/camera.tres` 읽고 INV-CAM-1/2/5/6 조건 평가, violation 시 exit 1. CI gate before manual QA hand-off (PM `pm_static_check.sh` 패턴 정합).

**(d) Required fixtures / mocks**:

1. `MockTarget` (Node2D, settable `global_position`) — H.1, H.2, H.4 unit tests 공유.
2. `MockPlayerMovementSM` — controllable `.state: StringName` getter; H.2 tests에 사용.
3. `MockEngine_get_physics_frames` — GUT `partial_double` 패턴으로 monotone counter 주입 (ADR-0003 결정성). H.3 tests에 사용.
4. `MockSceneManagerEmitter` — `scene_post_loaded` 시그널을 configurable args (anchor + limits)로 emit. H.5 integration tests에 사용.

**(e) Source path** (project convention 정합):

- `src/gameplay/camera/camera_system.gd` (PM `src/gameplay/player_movement/` 패턴 정합 — Camera는 gameplay layer source). Tier 1 단일 인스턴스, autoload 아님.

---

### H.9 Test Evidence by Story Type (project coding-standards.md 정합)

| AC group | Story type | Evidence requirement | Location |
|---|---|---|---|
| AC-CAM-H1..H3, H4-01..03, H5-01, H6-01 (Logic BLOCKING ×18) | Logic | Automated GUT test PASS | `tests/unit/camera/` |
| AC-CAM-H4-04, H5-02 (Integration BLOCKING ×2) | Integration | Mock-harness GUT test PASS | `tests/integration/camera/` |
| AC-CAM-H6-02 (Config ADVISORY ×1) | Config/Data | Smoke check PASS | `production/qa/smoke-{date}.md` |
| AC-CAM-HX-01..05 (Visual/Feel ADVISORY ×5) | Visual/Feel | Screenshot + lead sign-off OR playtester questionnaire | `production/qa/evidence/` |

## Visual / Audio Requirements

본 섹션은 Camera #3가 visual/audio 경계에 대해 가지는 contract를 명시한다. **Camera는 본 GDD scope에서 어떤 visual asset도 own하지 않는다** (Camera2D는 코드 노드; 텍스처/머티리얼 미사용). 음향 이벤트도 Camera는 own하지 않는다 (Audio #4가 shake-source SFX를 own; Camera는 그저 visual response).

### VA.1 — Shake Amplitudes vs Collage Readability (art-director 검증 2026-05-12)

art-director 분석 (이번 세션 inline consult): Tier 1 amplitude 스케일 (2 / 6 / 10 px 대 1280 px viewport = 0.16% / 0.47% / 0.78% 폭) 은 conservative — Vlambeer 표준 대비 보수적, MAX_SHAKE_PX=12는 readable third (±213 px)의 ~17× 안쪽. **Section C/G amplitude 변경 불필요**.

**중요 architectural confirmation**: art-bible Section 6 collage 3-layer (Base photo / Mid line-art / Top collage-detail) 모두 world-space geometry. `camera.offset`은 viewport 전체 uniform displacement → 레이어 간 differential displacement 없음 → torn-paper edge 가 wobble로 읽히지 **않음** (per-element 독립 움직임 없음).

**미세 흔들림 readability sign-off criterion** (AC-CAM-HX-01 evidence base):
- Freeze `boss_killed` frame at peak shake (frame 1, decay=1.0, offset = 10 px max direction).
- STRIDER sprite (192×128 px from art-bible Section 3) 와 background collage layer가 동일 vector로 shift.
- torn-paper boundary 사이의 distance가 0 픽셀 변화.
- **PASS**: layered composition은 흔들려도 분해되지 않는다.

### VA.2 — Tier 2 Zoom Bounds (deferred, but art-direction intent locked now)

Tier 1: `zoom = Vector2(1.0, 1.0)` 고정 (DEC-CAM-A4). Tier 2 boss arena 도입 시 zoom 활성화 — 본 GDD가 Tier 2 작업 시 art-direction intent를 미리 기록:

| Zoom 시나리오 | Range | Constraint source |
|---|---|---|
| Arena pull-out (boss 등장) | `0.85` min | art-bible Principle A: ECHO 식별성 — 48 px sprite × 0.85 zoom → ~41 px apparent (≥32 px floor 통과) |
| Boss face push-in (phase transition) | `1.25` max | art-bible Section 3 shape-language: STRIDER 192 px at 1.25× = viewport 18.75% — readable third 내부 |
| Tier 2 default (normal gameplay) | `1.0` | Tier 1 baseline carry-forward |

**Hard floor** (Tier 2 GDD revision 시 새 INV로 등록): "any Tier 2 zoom level에서 ECHO 렌더된 픽셀 높이 ≥ 32 px apparent" (art-bible Section 3 thumbnail test). 720p Steam Deck native에서 검증.

**Zoom transitions**: 하드 cut이 아닌 tween (Pillar 3 — 콜라주 합성이 새 frame에 "숨을 쉬며" 진입해야; 하드 cut은 glitch로 읽힘). 정확한 tween 곡선/속도는 Tier 2 GDD revision에서 결정.

### VA.3 — Ownership Boundary Table (Camera가 NOT 소유하는 visual signal)

본 표는 종종 혼동되는 ownership을 명시적으로 distinguishes한다 (downstream GDD 작성 시 boundary clarity):

| Visual signal | Owner | Camera #3 role |
|---|---|---|
| **Rewind 시 color inversion + glitch** | **Time Rewind Visual Shader #16** (art-bible Section 1 Principle C locks) | Camera는 NOT own. Camera의 R-C1-9 `reset_smoothing()` call timing이 shader fade window와 동기화 (ux-designer F3 option (c) — shader inherits camera snap) |
| **`player_hit_lethal` 시 screen flash** | **VFX #14** (CanvasLayer top overlay). Damage #8은 signal source, VFX가 renderer | Camera는 NOT own. shake와 visual overlap 없음 — 별도 채널 |
| **Boss arena letterbox bars** (Tier 2) | **VFX #14** (CanvasLayer overlay, screen-space). Camera 결합 회피 — single-responsibility | Camera는 NOT own. Tier 2 진입 시 VFX GDD에서 명시 |
| **Particle world-vs-viewport anchoring during shake** | **VFX #14** (Camera.offset을 readable property로 poll). 시그널 비필요 — Camera는 state expose만 | Camera는 NOT own. C.3.1 signal matrix에 emit 시그널 없음 |

### VA.4 — Audio Events (Camera는 owner 아님 — Audio #4 cross-ref)

본 GDD scope의 모든 shake-source 이벤트 (`shot_fired`, `player_hit_lethal`, `boss_killed`)는 자체 SFX를 emit하지만 **Camera #3는 audio output을 own하지 않는다**. Audio routing/mixing/ducking은 Audio #4 (Tier 1 stub-level, Not Started)가 own.

**향후 Audio #4 GDD 작성 시 reciprocal 의무** (F.4.2 row #6 candidate): Audio가 `shot_fired` SFX의 amplitude를 Camera의 shake amplitude와 align할지는 Audio GDD가 결정 (예: `MAX_SHAKE_PX` 도달 시 SFX ducking 강화). 현재 Camera 측 no-op.

### VA.5 — Asset Spec Implications (zero asset)

Camera #3는 다음 asset을 **요구하지 않는다**:
- 텍스처 (Camera2D는 코드 노드)
- 머티리얼 / 셰이더 (포스트프로세싱은 Shader #16이 owns)
- 오디오 파일 (Audio #4 owns)
- 애니메이션 (Tier 1 zoom 고정; Tier 2 zoom transition은 GDScript Tween)
- 모델 / 메시 (2D)

**`/asset-spec system:camera` 실행 시 결과**: empty asset manifest. Tier 2 zoom transition 도입 시 별도 asset 추가 검토 (예: zoom curve resource — `Tween` 내장으로 충분).

### VA.6 — Cross-doc Art-Bible Reciprocal (Phase 5 추가)

art-director가 art-bible.md **Section 6 (Environment Design Language)** 에 "Camera Viewport Contract" 서브섹션 추가 권장 (이번 세션 inline consult Q4):

> **Camera Composition Contract (Camera System #3 2026-05-12):** Screen-shake는 `camera.offset` (post-smoothing) 으로 모든 레이어를 uniform 이동. Readable third = viewport 수평 중심 ±213 px; 게임플레이 중요 collage 요소는 12 px MAX_SHAKE_PX 변위 가정 하에 본 band 외부에 *단독 배치*되어서는 안 된다. Tier 2 zoom 범위 0.85–1.25×는 ECHO apparent height ≥ 32 px 유지 (Section 3 thumbnail test).

본 amendment는 Phase 5 cross-doc batch에 1 row 추가 (C.3.3 + F.4.1 batch 보강).

📌 **Asset Spec**: Visual/Audio requirements are defined as **zero new assets** for Tier 1 + art-direction intent for Tier 2 zoom. art-bible은 이미 Approved + ABA-1..4 landed (2026-05-11) → 본 Camera #3 GDD는 추가 asset blocker 없음. `/asset-spec system:camera` 실행 시 empty manifest 예상 (Tier 2 진입까지).

## UI Requirements

**Camera #3는 UI 요소를 own하지 않는다**. Camera2D는 게임 월드 viewport를 제어하는 인프라 노드이며, HUD/메뉴/오버레이 등 사용자 인터페이스는 별도 시스템이 소유한다.

### UI.1 — Camera가 NOT 제공하는 UI surface

- HUD elements (REWIND token counter, weapon icon, boss HP bar) — **HUD #13** owns.
- Pause/menu overlays — **Menu #18** owns (Anti-Pillar #6: Tier 1 minimal — pause overlay only).
- Story intro 5-line typewriter — **Story Intro Text System #17** owns.
- Boss arena letterbox bars (Tier 2 deferred) — **VFX #14** owns (per VA.3 ownership boundary).
- Screenshot capture UI / share — Steam 내장 (F12 default).

### UI.2 — Camera가 노출하는 coordinate primitives (HUD 등이 read)

Downstream UI 시스템이 Camera에서 read할 수 있는 primitives:

| Primitive | Type | Usage |
|---|---|---|
| `camera.global_position` | Vector2 | HUD가 world-anchored UI (예: 보스 위 HP bar) 위치 계산 시 read |
| `camera.offset` | Vector2 | shake state read — VFX가 particle world-vs-viewport anchoring 결정 시 read (UI는 일반적으로 read 안 함) |
| `camera.get_screen_center_position()` | Vector2 (Godot 4.6 내장) | viewport 중심 world coord — HUD anchoring 보조 |
| `camera.get_viewport_rect()` | Rect2 (Godot 4.6 내장) | viewport bounds — screen-anchored UI placement |

**HUD #13 의무** (F.4.2 row #1 정합): HUD GDD 작성 시 (a) Camera Node 참조 패턴 결정 (`get_tree().get_first_node_in_group("camera")` 또는 autoload 노출 vs sibling lookup); (b) screen-anchored (CanvasLayer top) vs world-anchored (sibling in stage tree) UI 분류; (c) Camera에 새 signal 요청 발생 시 본 GDD revision으로 처리.

### UI.3 — UX Flag (NO new ux-spec required)

Camera #3는 ux-spec 작성을 트리거하지 않는다 — 시각적 UI screen이 없기 때문. `/ux-design` 실행은 HUD #13 / Menu #18 / Story Intro #17 GDD 작성 시 별도 수행. **본 GDD는 ux-design 의무를 발생시키지 않는다**.

## Z. Open Questions

본 섹션은 본 GDD에서 해소되지 않은 결정을 명시한다. 각 항목은 owner + target resolution 시점을 갖는다.

### Z.1 — Closed (this session)

| ID | Question | Resolution | Resolved In |
|---|---|---|---|
| **OQ-CAM-CLOSED-1** | Camera2D vs Phantom Camera vs 커스텀 Node2D | stock Camera2D + thin script (`extends Camera2D`) — godot-specialist V1 검증 | A.1 DEC-CAM-A1 |
| **OQ-CAM-CLOSED-2** | Camera state PlayerSnapshot 포함 여부 | NOT included — ADR-0002 9-field lock 유지 (Pillar 1 / B headline) | A.1 DEC-CAM-A2 |
| **OQ-CAM-CLOSED-3** | Shake RNG 시드 패턴 | `(frame × 1_000_003) ^ event_seed` (patch-stable; `hash()` 거부) — gameplay-programmer Q3 + godot-specialist V4 검증 | R-C1-7, F-CAM-6 |
| **OQ-CAM-CLOSED-4** | Rewind playback 중 카메라 행동 | α-freeze (current — `is_rewind_frozen` 가드로 R-C1-1 skip) — β-follow는 lerp residual로 DT-CAM-1 깨짐 | R-C1-8/9, C.2 |
| **OQ-CAM-CLOSED-5** | Stage limit 전달 패턴 | scene_post_loaded signal에 `limits: Rect2` 인자 추가 (single-source atomic delivery) — godot-specialist V5 추천 채택 | R-C1-10/12, C.3.3 |
| **OQ-CAM-CLOSED-6** | Player Fantasy headline 선정 | Framing C "카메라는 잊지 않는다" — creative-director 추천 + A architectural decision의 player-facing 번역 | B.4 DEC-CAM-B1 |
| **OQ-CAM-CLOSED-7** | Shake stacking policy (replace / add-capped / decay-replace) | Add-capped (per-event timer pool + vector-sum + length-clamp 12 px) — ux-designer F2 + game-designer C.1 융합 | R-C1-6, F-CAM-5 |
| **OQ-CAM-CLOSED-8** | Wall-pinch deadzone drift (E-CAM-1) | R-C1-3에 limit-boundary guard 추가 (systems-designer E.section consult에서 surfaced) | R-C1-3 amendment, E-CAM-1 |
| **OQ-CAM-CLOSED-9** | Per-frame position formula contradiction (Session 22 design-review BLOCKING #1) | Split horizontal/vertical 모델 채택 — 수평 incremental advance, 수직 target+lookahead. unified `camera = target + look_offset`는 deadzone semantics와 양립 불가 (F-CAM-2 worked example + AC-CAM-H1-01 `camera.x = 501`) | A.1 DEC-CAM-A5, R-C1-1, F-CAM-1, F-CAM-2 |
| **OQ-CAM-CLOSED-10** | F-CAM-3 lerp rate vs worked example numerical inconsistency (BLOCKING #2) | LOOKAHEAD_LERP_FRAMES=8 유지, worked example을 실제 rate 1/8 수렴값으로 재계산 (frame 8 ≈ −13.1; time-constant 해석). AC-CAM-H2-01/02 tolerance 업데이트 | F-CAM-3 worked example, AC-CAM-H2-01/02 |
| **OQ-CAM-CLOSED-11** | `_compute_initial_look_offset(player_node)` 미정의 (BLOCKING #3) | Inline spec 추가 — `Vector2(0.0, _target_y_for_state(state))` with state→target_y mapping per R-C1-4 (split-H/V 정합) | R-C1-9 inline definition |

### Z.2 — Open / Deferred

| ID | Question | Owner | Target resolution | Priority | Notes |
|---|---|---|---|---|---|
| **OQ-CAM-1** | Tier 1 Steam Deck 1세대 실측 — POSITION_SMOOTHING_SPEED=32.0이 시각적으로 lag 또는 floaty하게 느껴지는가? INV-CAM-3는 spatial 안전성 보장하나 perceptual은 미검증 | game-designer + ux-designer | Tier 1 Week 1 playtest | MEDIUM | AC-CAM-HX-03 evidence 수집 |
| **OQ-CAM-2** | FALL_LOOKAHEAD_DOWN_PX=52 적정성 — 착지 위협 시야 충분한가? 80% threshold 미달 시 60 px 또는 70 px로 상향 검토 | game-designer | Tier 1 Week 1-2 playtest (착지 위협 인카운터 등장 시) | MEDIUM | AC-CAM-HX-05 evidence; INV-CAM-5 36 frames 한계 내에서만 변경 가능 |
| **OQ-CAM-3** | Tier 2 zoom 도입 시점 — boss arena 진입 → zoom-out (0.85×) 가치 있나? Cuphead-locked 단순 letterbox만으로 충분하지 않나? | art-director + game-designer | Tier 2 Boss Pattern #11 GDD 작성 시 | LOW (Tier 2 deferred) | VA.2 기록된 0.85..1.25× intent, 본 결정은 Boss GDD가 own |
| **OQ-CAM-4** | Tier 2 zoom transition curve — linear lerp vs ease-in/ease-out? "콜라주가 새 frame에 숨을 쉬며 진입" 의 정확한 곡선 | art-director | Tier 2 zoom 도입 시 (Boss #11 GDD) | LOW (Tier 2) | VA.2 "tween" 명시했으나 곡선 미정 |
| **OQ-CAM-5** | Camera Node reference pattern — HUD #13가 `get_tree().get_first_node_in_group("camera")` vs autoload 노출 vs 직접 sibling lookup 중 어느 것? | ui-designer + ux-designer | HUD #13 GDD 작성 시 | LOW | F.4.2 row #1 / UI.2 deferred to HUD owner |
| **OQ-CAM-6** | Audio #4 와의 ducking align — Camera shake amplitude (`shake_offset.length()`)가 SFX ducking 강도와 align해야 하나? 예: `boss_killed` peak 10 px 시 BGM ducking 강화 | audio-director | Audio #4 GDD 작성 시 | LOW | VA.4 reciprocal candidate, 현재 Camera no-op |
| **OQ-CAM-7** | Tier 2 viewport 변동 시나리오 (옵션 메뉴 letterbox 또는 멀티-룸 시 viewport 축소) → DEADZONE_HALF_X 재튜닝 필요? INV-CAM-2의 `× 6 < viewport_width` 검증 재실행 | game-designer + ux-designer | Tier 2 viewport scaling 도입 시 | LOW (Tier 2) | E-CAM-12 carry-over |
| **OQ-CAM-8** | Tier 2 `boss_arena_entered(arena_rect: Rect2)` 등 새 signal 도입 필요성 — boss arena가 stage scene 변경 없이 camera lock만 트리거하는 경우 | game-designer + boss-pattern-designer | Boss Pattern #11 GDD 작성 시 | LOW (Tier 2) | F.4.2 row #4 reciprocal candidate |

### Z.3 — Tension / Untestable

본 항목은 OQ가 아니라 자동화 불가능한 ADVISORY criteria (이미 H.X 섹션에 enumerated):

| ID | Tension | Resolution path |
|---|---|---|
| **T-CAM-1** | Pillar 3 콜라주 시그너처 aesthetic 검증 자동화 불가 | AC-CAM-HX-01 art-director sign-off |
| **T-CAM-2** | DT-CAM-3 emotional read ("결과의 무게로 느껴짐") 자동화 불가 | AC-CAM-HX-02 playtester questionnaire |
| **T-CAM-3** | Follow smoothness perceptual feel ("floaty/lag" 부재) 자동화 불가 | AC-CAM-HX-03 playtester feedback |
| **T-CAM-4** | Snap-no-cut perception ("cut되지 않고 snap") 자동화 불가 | AC-CAM-HX-04 playtester questionnaire |
| **T-CAM-5** | Lookahead asymmetric ratio (52/20) 실효성 — playtest 데이터 필요 | AC-CAM-HX-05 + OQ-CAM-2 cycle
