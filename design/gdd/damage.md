# Damage / Hit Detection System

> **System**: #8 Damage / Hit Detection
> **Category**: Core / Gameplay
> **Priority**: MVP (Tier 1)
> **Status**: **LOCKED for prototype** (Round 4 review 2026-05-09 — 3 BLOCKING surgical 적용 완료: BLOCK-R4-1 AC-21 regex broadening (state_machine.* 모든 access + get_node alias 경로 포함), BLOCK-R4-2 AC-29 hardcoded fixture baseline (run-1 self-capture 금지), **B-R4-1 (systems-designer post-lock) DEC-6 hazard grace off-by-one** (`_hazard_grace_remaining` 초기값 `hazard_grace_frames + 1` — 동프레임 priority-2 decrement 보상; 12 flush windows 보장; AC-24 갱신). Round 3 review 2026-05-09: 4 BLOCKING 적용. Round 2 review 2026-05-09: 8 BLOCKING / 12 RECOMMENDED 적용. creative-director Round 4 verdict: **LOCK & PROTOTYPE** — Round 5 차단, 추가 발견은 post-lock observations로 review-log에만 기록. 신규 ADR 3건 queued: OQ-DMG-8/9, ADR-0003 priority 사다리 갱신.)
> **Author**: game-designer + godot-gdscript-specialist
> **Created**: 2026-05-09
> **Engine**: Godot 4.6 / GDScript (statically typed)
> **Depends On**: Player Movement #6 (Approved 2026-05-11) + Player Shooting #7 *(provisional)* + Enemy AI #10 *(provisional)* + Boss Pattern #11 *(provisional)* + Stage #12 *(provisional)* — HitBox/HurtBox 인스턴스화 클라이언트
> **Consumed By**: State Machine #5 (Approved — player_hit_lethal 구독) + Time Rewind #9 (Approved — i-frame 협조) + HUD #13 *(provisional)* — 보스 phase 시그널 옵션

---

## Locked Scope Decisions (2026-05-09 사용자 승인)

- **DEC-1**: `player_hit_lethal(cause: StringName)` 1-arg signature. **OQ-SM-1 해소**. cause taxonomy는 본 GDD가 단일 소유 (D.3).
- **DEC-2**: Boss HP = **discrete phase thresholds** (`phase_hits_remaining: int` per phase). UI HP bar 없음 (Anti-Pillar 일관성). HUD는 phase 전이 시그널만 소비.
- **DEC-3**: 표준 적 = **1-hit kill** (hit-stun 없음). Pillar 1히트 일관성. Tier 1 단순.
- **DEC-4**: i-frame 제어 = **SM이 ECHO HurtBox.monitorable 비활성화**. RewindingState.enter()/exit()가 ECHO HurtBox.monitorable 제어. Damage 시스템은 SM 상태 polling 안 함 (forbidden_pattern `cross_entity_sm_transition_call` 우회 + 단방향 데이터 흐름 보존). **2026-05-09 수정 (round 2)**: 초안 + 1차 정정에서 `monitoring`으로 잘못 기록된 7개 사이트(C.6.2, D.1.1 cond(2), D.4.1, D.4.2, D.4.3, D.4.4, AC-12, AC-20, AC-22) 일괄 `monitorable`로 정정. **Godot 4.6 Area2D 의미론**: HitBox가 능동 스캐너이며 `HitBox.area_entered`는 `HitBox.monitoring AND HurtBox.monitorable AND layer/mask AND shape_overlap`일 때만 발화. HurtBox.monitoring을 토글해도 `HitBox.area_entered`는 차단되지 *않으므로* 단일 i-frame 토글은 `HurtBox.monitorable`이 유일 단일 출처.
- **DEC-5** (2026-05-09 추가): `boss_hit_absorbed(boss_id, phase_index)` 2-arg. `hits_remaining` 파라미터 제거. B.1 "binary, not graded" 데이터 계약 보호 (스페셜리스트 game-designer 권고).
- **DEC-6** (2026-05-09 추가): REWINDING.exit() 직후 hazard-only grace 12프레임 도입. monitorable=true 복귀 후 12프레임(약 200ms) 동안 hazard cause(L5)만 차단. 적 탄환(L4)은 정상 수용. SM의 RewindingState.exit()가 Damage `start_hazard_grace()` 호출 → Damage가 `_hazard_grace_remaining: int = 12` 카운터 소유. `hurtbox_hit(cause)` 핸들에서 `cause`가 hazard 계열이고 카운터>0이면 즉시 return. E.13 Pillar 1 위반 해소책 (creative-director 권고).

---

## A. Overview

> **Status**: Approved 2026-05-09.

Damage 시스템은 *어떤 entity가 어떤 entity에게 치명타를 가했는가*를 단일하게 판정하고 그 사실을 시그널로 전파하는 hit-detection 코어다. Echo의 1히트 즉사 디자인(Pillar Challenge primary)에서, 본 시스템은 데미지를 *수치 계산*이 아닌 *binary 사건(hit or no-hit)*으로 정의한다. ECHO·표준 적·hazard 모두 단일 발사체 명중으로 처리 종결되며, 보스만 *discrete phase thresholds*(DEC-2)를 통해 다단계 격파를 표현한다 — UI HP bar는 의도적으로 부재한다. ECHO에 한해 Time Rewind 시스템이 부과한 2-stage 분리(Rule 4)를 강제하여 `lethal_hit_detected → 12프레임 grace → death_committed`의 결정 지연 윈도우를 호스팅한다. 모든 hit 통지는 `player_hit_lethal(cause: StringName)` (DEC-1) 1-arg 시그널로 통일되며, `cause` taxonomy(D.3)는 본 GDD가 단일 소유한다. REWINDING 30프레임 i-frame은 Damage 시스템이 *직접 인지하지 않는다* — State Machine이 ECHO HurtBox.monitorable을 비활성화함으로써(DEC-4) Damage는 단방향으로 충돌 신호를 발행할 뿐이다. Foundation 시스템은 아니지만 4개 entity 호스트(#6/#7/#10/#11/#12)에 HitBox/HurtBox 컴포넌트를 *제공*하며, 5개 시그널 소비자(#5/#9/#13/#14/#4)에 binary 사건을 *전파*한다.

**핵심 포지셔닝**:

- **Binary, not graded** — 모든 hit는 즉사 이벤트. 데미지 *수치*는 보스 phase 카운터에만 존재. `boss_hit_absorbed` 시그니처는 2-arg(`boss_id`, `phase_index`) — `hits_remaining` 불공개로 binary 데이터 계약 architectural 보호 (DEC-5).
- **Threat Symmetry, recovery 비대칭** — damage 모델은 대칭 (ECHO/적 모두 1히트). 회복 계층은 의도적 비대칭 (ECHO만 grace + rewind, 적은 즉사, 보스만 phase). 다운스트림 디자이너 오도 방지를 위해 명시 (B.2).
- **Single signal contract** — 9개 시그널 (`lethal_hit_detected`/`player_hit_lethal`/`death_committed`/`hurtbox_hit`/`enemy_killed`/`boss_hit_absorbed`/`boss_pattern_interrupted`/`boss_phase_advanced`/`boss_killed`). emit 순서는 결정적 contract (F.4.1).
- **No HP bar** — 적·ECHO HP UI 없음. 보스도 phase 전이만 표시 (HUD GDD 결정).
- **i-frame은 SM 책임 + DEC-6 hazard grace** — Damage는 SM 상태 미조회. SM이 `HurtBox.monitorable` 단일 토글 (DEC-4). REWINDING.exit() 직후 12프레임 hazard-only grace 추가 (DEC-6 — Pillar 1 보호).
- **2-stage는 ECHO 전용** — 표준 적/보스는 즉시 결정. 12프레임 grace는 ECHO 1히트 카타르시스 보존 장치.
- **솔로 budget 보호** — 9 시그널 + 3 invocation API (`commit_death`/`cancel_pending_death`/`start_hazard_grace`) — VFX/Audio/HUD 매핑 동기화 의무 (C.5.3).

---

## B. Player Fantasy

> **Status**: Approved 2026-05-09.

### B.1 Core Fantasy

**"한 발에 죽지만, 한 발에 죽지 *않을 수도* 있다."**

Echo의 데미지 시스템은 플레이어에게 **이진 명료성(binary clarity)** 을 약속한다. 어떤 순간에도 "내가 맞았는가, 맞지 않았는가" 두 상태만 존재한다. HP 게이지를 흘끗거리며 남은 데미지를 계산하거나, 잡몹의 누적 hit count를 머릿속에 적어둘 필요가 없다. 전투의 모든 인지 자원은 *적의 탄환 패턴 읽기*에만 집중된다.

이 명료성은 *공포*를 만든다. 한 발이 곧 죽음이라는 사실은 모든 적 탄환을 *진짜 위협*으로 만든다 — Pillar Challenge가 약속한 "공정하지만 잔혹한" 긴장감의 원천이다. 그러나 Time Rewind 시스템이 부과한 12프레임 grace 윈도우(Rule 4)가 이 공포를 *학습 도구*로 변환한다: 죽음 직후의 짧은 고요한 순간 — "왜 죽었지?" — 가 회수 결정의 비용이 된다. Damage 시스템은 그 grace의 시작점(`lethal_hit_detected`)과 종착점(`death_committed`)을 정직하게 분리해 송출하며, *결정의 무게*를 플레이어 손에 얹는다.

### B.2 Threat Symmetry (위협 대칭 — 명시적 비대칭 동반)

Echo의 세계에서 **damage 모델은 대칭이지만, 회복 계층은 의도적으로 비대칭이다**. ECHO의 1발이 표준 적을 즉사시킨다 — 적의 1발이 ECHO를 즉사시킨다 (DEC-3). damage 자체에는 권력의 비대칭이 없다.

**그러나 회복 비대칭은 의도된 핵심 메커닉이다**:
- ECHO만 12프레임 grace 윈도우(C.3) + Time Rewind 토큰 보유 (Pillar 1)
- 표준 적은 1히트 즉사 + 즉시 `queue_free` (DEC-3)
- 보스만 phase threshold (DEC-2) — UI는 부재 (Anti-Pillar)

이 비대칭은 *공정성의 위반*이 아니라 *코어 메커닉 그 자체*다. ECHO가 시간을 되돌릴 수 있다는 것이 게임의 픽션 명제(VEIL 사각지대)와 일치한다. 플레이어는 *모든 1히트가 진짜 위협*이라는 *위협 밀도 대칭*을 느끼며, 토큰을 소비한 회복은 그 위협의 비용을 지불한 *대가*다 — 무료 안전망이 아니다.

**중요한 다운스트림 의무**: 후속 레벨/적 디자이너는 "공격자/피해자 동일 규칙"을 *damage 모델 차원에서만* 가정해야 한다. 회복 비대칭을 "공정성 위반"으로 오해하여 적에게도 grace/respawn을 부여하면 Pillar 1과 충돌한다.

> **이전 명칭 폐기**: "Mirror Principle"이라는 이전 명칭은 회복 비대칭을 모호하게 만들어 다운스트림 디자이너 오도 위험. "Threat Symmetry"로 재명명하고 비대칭을 명시적으로 노출.

### B.3 Cause-Aware Death (이유 있는 죽음)

플레이어가 죽었을 때 **"무엇에 죽었는가"가 즉각 명료해야** 한다. 탄환이었는가, 가시였는가, 구덩이였는가, 보스 광역기였는가. 본 시스템은 모든 치명타에 `cause: StringName` (DEC-1)을 동봉하여, VFX·SFX·Time Rewind 글리치 시그니처가 *원인별로 차별화된 피드백*을 발화하도록 한다. 모호한 죽음은 학습을 막는다 — 학습 없는 죽음은 좌절이다. 본 시스템의 fantasy 의무는 *모든 죽음을 추적 가능하게 만드는 것*이다.

### B.4 Boss as Erosion (보스 = 벽을 깎아내는 감각)

표준 적이 *유리잔*이라면, 보스는 *벽*이다. 보스만이 phase threshold (DEC-2)를 통해 다단계 격파를 표현한다. 그러나 **HP 바는 노출되지 않는다** (Anti-Pillar "Reveal Through Action" 일관성). 플레이어는 보스의 *약점이 드러나는 순간*을 시각·청각·패턴 변화로 인지한다 — 갑자기 자세가 바뀌고, 새로운 탄막이 펼쳐지고, 콜라주 비주얼이 한 겹 벗겨진다. 숫자가 줄어드는 게 아니라 **세계가 변한다**. "한 단계 내려갔다"는 감각은 데이터가 아니라 *연출*에서 와야 한다.

### B.5 Anti-Fantasy (의도적으로 거부하는 것)

| 거부 | 이유 |
|---|---|
| **HP 바** (ECHO·표준 적·보스 모두) | "체력 추적 게임"이 아니다. 인지 자원은 패턴 읽기에 |
| **잡몹 hit count** ("이 적은 3발") | 1히트 즉사의 명료성을 희석. 적의 *탄환 패턴*만이 의미 있는 변별점 |
| **데미지 수치 popup** ("12!") | RPG 어휘. 본 게임은 binary 사건만 다룸 |
| **모호한 사인** (cause 미상) | 학습 불가능한 죽음은 좌절. cause taxonomy로 차단 |
| **i-frame 깜빡임 의존** (Damage가 SM 상태 polling) | 단방향 데이터 흐름 위반. SM이 HurtBox.monitorable 비활성화로 처리 (DEC-4) |
| **자기 발사체에 자해** | 슈팅 액션의 자기 일관성 파괴. F.1에서 collision_layer 분리로 보장 |

> **Tier 3 명시 제약 (armored 변종 미존재)**: B.5의 "잡몹 hit count" 거부는 *Tier 3까지 영구 lock*이다. armored 적/elite 변종이 디자인적으로 등장하려면 DEC-3 변경 + 별도 ADR + Enemy AI GDD #10 의 HURT 상태 추가 + Damage GDD H 섹션 신규 AC가 동시 필요. Tier 3 이내 도입을 *시도하지 않는다* — 솔로 budget 침식 위험. Tier 4(post-launch DLC) 검토 대상.

> **DEC-3 hit-stun 부재 → VFX near-miss 피드백 의무 (game-designer 권고)**: 빗나간 사격에 대한 피드백 부재 위험은 VFX(#14)가 *near-miss visual signature* (탄환이 적/플레이어 근접 통과 시 puff/스파크)를 *반드시* 제공함으로써 보상한다. 본 의무는 VFX GDD #14의 Tier 1 Acceptance Criteria로 등록. Damage 시스템 자체는 near-miss 정보를 *발행하지 않으나*, 단일 출처 cause taxonomy + 적 발사체 destroy 시점 (Player Shooting #7) 데이터로 VFX가 자체 근접 판정 가능.

### B.6 Pillar 정합성 매트릭스

| Pillar | Damage 시스템의 기여 |
|---|---|
| **Challenge — punishing but fair** | 1히트 즉사 + threat symmetry = punishing의 근간. cause 명료성 = fair의 근간. 회복 비대칭(ECHO grace + rewind)은 *코어 메커닉*이며 Pillar 1 학습 도구의 메커니컬 실현 (B.2) |
| **Time Rewind — defiant loop** | 2-stage 분리로 grace 윈도우 호스팅 (Rule 4 의무) |
| **Reveal Through Action** | 보스 phase 전이는 *연출*로만 표현. HP UI 부재 |
| **Collage SF** | cause taxonomy가 VFX/SFX의 차별화 기반 → 비주얼 정체성과 결합 |
| **Solo-craftable Scope** | binary 모델 → 밸런싱 표 폭발 방지 (다중 데미지 수치 vs 다중 HP 매트릭스 X) |

---

## C. Detailed Design

> **Status**: Approved 2026-05-09.

### C.1 HitBox / HurtBox 노드 패턴 (Damage 시스템 owned 컴포넌트)

본 시스템은 두 개의 `Area2D` 기반 컴포넌트를 *제공*한다. 호스트 시스템(F.1)은 본 컴포넌트를 자식 노드로 부착할 의무가 있다.

#### C.1.1 컴포넌트 정의

| 컴포넌트 | 역할 | 베이스 | `class_name` | 주요 속성 |
|---|---|---|---|---|
| `HitBox` | 데미지를 *가하는* 오프펜시브 박스 | `Area2D` | `class_name HitBox extends Area2D` | `cause: StringName`(인스턴스별, default `&""`), `host: Node` (인스턴스화 시 호스트가 명시 set, D.3.1 분기에 사용), `monitoring: bool` (**능동 스캐너 — 항상 true가 default**), `monitorable: bool` (사용 안 함, default true 유지) |
| `HurtBox` | 데미지를 *받는* 디펜시브 박스 | `Area2D` | `class_name HurtBox extends Area2D` | `entity_id: StringName`, `monitorable: bool` (**i-frame 토글 — DEC-4 단일 출처**), `monitoring: bool` (HurtBox는 능동 스캔 안 함 — 항상 default true 유지), `signal hurtbox_hit(cause: StringName)` |

> **Godot 4.6 Area2D 의미론 명세** (DEC-4 보강): HitBox가 능동 스캐너이고 HurtBox가 수동 타깃이다. `HitBox.area_entered(area: Area2D)`가 단일 발화점이며, 발화 조건은 `HitBox.monitoring AND HurtBox.monitorable AND layer/mask AND shape_overlap`. 즉 **i-frame은 `HurtBox.monitorable=false`로만 차단되며**, `HurtBox.monitoring`을 토글해도 `HitBox.area_entered`는 정상 발화한다 — 본 GDD의 모든 i-frame 토글은 `HurtBox.monitorable`로 통일한다.

#### C.1.2 시그널 흐름

`hurtbox_hit`의 **단일 emit 지점은 HitBox 스크립트**이며, *Damage 컴포넌트나 호스트 핸들러에서 재emit하지 않는다*. (Round 3 락인 — F.4.1 ECHO/Boss 블록과 일관.)

1. `HitBox.area_entered(area: Area2D)` 발화 (HitBox가 능동 스캐너)
2. `if area is HurtBox` 가드 통과 시 (정적 타입 narrowing):
   - `(area as HurtBox).hurtbox_hit.emit(self.cause)` (HitBox의 cause 라벨 전파 — 인스턴스 호출)
   - 동프레임 ECHO 자해 차단: collision_layer/mask로 사전 차단 (C.2), HitBox.cause 검증 불필요
3. HurtBox 호스트(ECHO/적/보스)의 호스트 스크립트가 `hurtbox_hit`를 구독하여 entity-specific 처리(C.3-C.5)

> **`HitBox.cause` 할당 책임 (Round 3 명확화)**: `HitBox.cause`는 **호스트가 인스턴스화 시점에 명시 set**한다 (F.1 Upstream Clients 표 참조). D.3.1의 cause 분기 표는 *호스트가 따라야 할 cause 할당 의무 표*이며 *런타임 함수가 아니다*. C.1.2 step 2의 `self.cause`는 이미 호스트가 set한 값을 그대로 전파한다 — 추가 분기 로직 없음.
>
> **단일 emit 검증**: Damage 컴포넌트의 `_on_hurtbox_hit(cause)` 핸들러는 `lethal_hit_detected` + `player_hit_lethal`만 발화하며 `hurtbox_hit`를 *재emit하지 않는다* (AC-8 검증).

> **시그널 connect 순서 invariant**: `lethal_hit_detected`와 `player_hit_lethal`은 *동일 emit 시점*에 발화되지만 (C.3.1), TRC가 SM보다 *먼저* connect되어야 한다 — 그래야 `_lethal_hit_head` 캐시(frame N)가 SM의 ALIVE→DYING 전이보다 앞서 실행된다. 이 순서는 호스트 ECHO 노드의 `_ready()`에서 *기록된 코드 라인 순서*로 강제하며, AC-28에서 검증한다.

#### C.1.3 컴포넌트 인스턴스화 책임 (단방향)

- 호스트 시스템(F.1 클라이언트)이 자기 .tscn에 HitBox/HurtBox를 *수동 인스턴스*. 본 GDD는 컴포넌트의 *클래스 정의*만 제공.
- 본 GDD는 호스트의 internal 노드 트리에 *touch하지 않는다* — composition over inheritance.

---

### C.2 충돌 레이어 매트릭스 (Godot 4.6 collision_layer / collision_mask)

Godot 4.6의 `Area2D.collision_layer` / `collision_mask`는 32비트. 본 시스템은 6 비트만 점유.

#### C.2.1 레이어 할당 (locked)

| Bit | Layer 이름 | 호스트 |
|---|---|---|
| **1** | `echo_hurtbox` | ECHO 본체 (#6) |
| **2** | `echo_projectile_hitbox` | 플레이어 발사체 (#7) |
| **3** | `enemy_hurtbox` | 표준 적 (#10) |
| **4** | `enemy_projectile_hitbox` | 적 발사체 + 보스 발사체 (#10/#11) |
| **5** | `hazard_hitbox` | 환경 hazard (#12) |
| **6** | `boss_hurtbox` | 보스 (#11) — 표준 적과 분리하여 phase 로직 격리 |

#### C.2.2 마스크 매트릭스 (전수)

| 컴포넌트 | layer | mask 비트 | 의미 |
|---|---|---|---|
| ECHO HurtBox | 1 | 4, 5 | 적 탄환 + hazard만 받음 — 자기 발사체 무시 |
| ECHO Projectile HitBox | 2 | 3, 6 | 표준 적 + 보스만 명중 — 자기·다른 ECHO 발사체 무시 |
| Enemy HurtBox | 3 | 2 | 플레이어 발사체만 받음 |
| Enemy Projectile HitBox | 4 | 1 | ECHO만 명중 — friendly fire 차단 |
| Hazard HitBox | 5 | 1 | ECHO만 — 적은 hazard에 영향 없음 (디자인 단순화) |
| Boss HurtBox | 6 | 2 | 플레이어 발사체만 |

> **자해 차단**: ECHO Projectile HitBox(L2)가 ECHO HurtBox(L1)를 mask하지 않음 → Godot 충돌 엔진이 사전에 area_entered emit 자체를 차단. 코드 가드 불필요.

> **friendly-fire 차단**: 적 발사체(L4)는 다른 적(L3)을 mask하지 않음 → Tier 1 단순화. (적 vs 적 협동 처치는 Tier 2 게이트의 검증 대상; 현 baseline은 비활성.)

---

### C.3 ECHO 2-stage death (Time Rewind GDD Rule 4 호스팅)

본 sub-section은 Time Rewind GDD가 부과한 의무(Rule 4 + E-11)를 만족시키는 *Damage 측 구현 계약*이다.

#### C.3.1 시그널 계약 (Damage 시스템 owned)

| 시그널 | 시그니처 | 발화 시점 | 소비자 |
|---|---|---|---|
| `lethal_hit_detected` | `(cause: StringName)` | ECHO HurtBox가 hit받은 *직후* (frame N) | TRC (`_lethal_hit_head` 캐시 트리거) |
| `player_hit_lethal` | `(cause: StringName)` | `lethal_hit_detected`와 *동프레임 동순간* | EchoLifecycleSM (DYING 전이) |
| `death_committed` | `(cause: StringName)` | grace 윈도우 만료 시 (frame N+12) | TRC (정리), HUD (사망 화면), Audio (스팅) |

> `lethal_hit_detected`와 `player_hit_lethal`은 의미상 동일 사건이지만 *별도 시그널*로 유지된다. 이유: TRC는 정확히 frame N에 캐시해야 하고(타이밍 critical), SM은 latch 가드를 거쳐야 하므로(E-13 다중 hit 방어), connect 순서·구독자 분리가 필요.

#### C.3.2 stage 1 — `lethal_hit_detected` 발화 (frame N)

```text
ECHO HurtBox.area_entered(HitBox)
  ↓ hurtbox_hit(cause) emit
  ↓ ECHO Damage 컴포넌트가 핸들
  0. if _pending_cause != &"": return       # ← Round 5 first-hit lock (cross-doc S1 fix 2026-05-10)
                                            #   E.1 / time-rewind.md Rule 17 invariants 단일 출처 enforcement
  1. _pending_cause = cause                 # stage 2 인스턴스 저장 — emit *이전*
  2. emit lethal_hit_detected(cause)        # TRC 캐시 (frame N)
  3. emit player_hit_lethal(cause)          # SM DYING 전이
```

> **Ordering invariant** (godot-gdscript-specialist 권고): `_pending_cause` 할당이 emit *이전*에 실행되어야 한다. 동기 시그널 핸들러가 `commit_death()`를 같은 호출 스택에서 호출하는 future edge case 방어. AC-9의 `_pending_cause = cause₀` 검증은 emit 후 시점에서 cause₀가 set 되어 있음을 가정.

> **First-hit lock invariant** (Round 5 cross-doc S1 fix 2026-05-10 — `gdd-cross-review-2026-05-10.md`): step 0 가드는 두 invariant의 *유일한 enforcement site*다 — (a) `damage.md` E.1 "_pending_cause는 첫 hit의 cause로 고정" 그리고 (b) `time-rewind.md` Rule 17 "같은 틱 다중 치명타가 `_lethal_hit_head`를 재캐시하는 것을 차단". SM `_lethal_hit_latched`는 step 3 이후의 *secondary* 가드일 뿐이며, lethal_hit_detected (step 2) 와 player_hit_lethal (step 3) 가 별도 시그널이기 때문에 SM 측 latch만으로는 TRC의 `_lethal_hit_head` 재캐시를 차단할 수 없다. `_pending_cause`는 `commit_death()` 또는 `cancel_pending_death()`에서 `&""`로 클리어되므로 다음 lethal 사건의 첫 hit는 정상 통과한다. AC-36 검증.

#### C.3.3 stage 2 — `death_committed` 발화 (frame N+k, k=12 default)

`death_committed`의 발화는 SM의 grace 카운터에 의해 결정된다. SM이 Damage를 *push*한다 (poll 금지, DEC-4):

```text
EchoLifecycleSM.DyingState.physics_process(delta):
  _grace_frames_remaining -= 1
  if _grace_frames_remaining == 0 and not _rewind_consumed_during_grace:
    transition_to(DeadState)
    # DyingState.exit() 안에서:
    damage.commit_death()    # Damage가 즉시 _pending_cause로 emit
```

`Damage.commit_death() -> void`는 본 GDD가 노출하는 단일 *invocation API*이다. 인자 없음 — 내부에서 `_pending_cause`를 사용. 호출 후 `_pending_cause`는 `&""`로 초기화.

> **Idempotency 가드** (systems-designer 권고): `commit_death()`는 진입 시 `if _pending_cause == &"": return`로 단락. `_pending_cause`가 이미 클리어된 상태에서 중복 호출되어도 `death_committed(&"")` empty-cause emit 차단. AC-31 검증.

> **`cancel_pending_death()` 가드**: 마찬가지로 `_pending_cause == &""` 상태에서 호출 시 silent no-op (에러 없음 — SM의 RewindingState.enter()가 정상 라이프사이클상 여러 진입 가능). AC-32 검증.

#### C.3.4 grace 단축 / 무효화 (Rewind 소비 시)

- 플레이어가 grace 안에 rewind input → SM `DyingState → RewindingState` 전이
- 이 경우 `death_committed`는 **emit되지 않는다** (사망이 retract됨)
- Damage 측 책임: `_pending_cause = &""` 초기화 (SM이 RewindingState.enter()에서 `damage.cancel_pending_death()` 호출)

---

### C.4 적 + 보스 데미지 모델

#### C.4.1 표준 적 (1-hit kill, DEC-3)

```text
Enemy HurtBox.area_entered(HitBox)
  ↓ hurtbox_hit(cause) emit
  ↓ enemy 호스트가 핸들
  1. emit enemy_killed(self.entity_id, cause)
  2. queue_free()  # 동프레임 처리
```

- hit-stun 없음. 즉시 제거.
- 같은 틱 다중 hit는 첫 hit가 emit + queue_free → 후속 area_entered는 *해제된 노드*에서 발생하지 않음 (Godot이 보장).

#### C.4.2 보스 (discrete phase thresholds, DEC-2)

보스 호스트는 `phase_hits_remaining: int`, `phase_index: int` (0-based), 그리고 `_phase_advanced_this_frame: bool` (Round 3 추가 — D.2.3 monotonic +1 lock)을 멤버로 보유한다. `_phase_advanced_this_frame`은 매 `_physics_process(delta)` 시작에서 `false`로 reset. 본 GDD는 *boss 호스트가 따라야 할 절차*를 규정한다:

```text
Boss HurtBox.area_entered(HitBox)
  ↓ hurtbox_hit(cause) emit (HitBox 측에서 — C.1.2 step 2)
  ↓ boss 호스트가 핸들 (재emit 안 함)
  0. if _phase_advanced_this_frame: return            # ← Round 3 lock — 같은 틱 다중 hit 단일 단계 보장
  1. phase_hits_remaining -= 1
  2. if phase_hits_remaining > 0:
       emit boss_hit_absorbed(self.entity_id, phase_index)
       # → VFX/SFX 피드백 트리거. UI 변화 없음. hits_remaining 비전파 (DEC-5).
  3. elif phase_index < final_phase_index:
       emit boss_pattern_interrupted(self.entity_id, phase_index)   # Boss Pattern SM cleanup 트리거 — emit value `phase_index`는 pre-increment 값 (= F.3 declared param `prev_phase_index`)
       phase_index += 1
       phase_hits_remaining = phase_hp_table[phase_index]
       _phase_advanced_this_frame = true                              # lock set
       emit boss_phase_advanced(self.entity_id, phase_index)
       # → HUD 옵션 알림 + VFX 변화 + 패턴 SM 재진입
  4. else:
       emit boss_pattern_interrupted(self.entity_id, phase_index)
       _phase_advanced_this_frame = true                              # lock set (boss_killed 분기도 일관)
       emit boss_killed(self.entity_id)
       # → 스테이지 클리어 트리거 (Stage Manager #12). Summon cleanup은 Boss Pattern GDD #11 책임 (자체 summon registry).
```

- `phase_hp_table: Array[int]`은 Boss Pattern GDD(#11)가 단일 소유. 본 GDD는 *형식*만 강제.
- **DEC-5** (2026-05-09 추가): `boss_hit_absorbed(boss_id, phase_index)` — 2-arg 시그니처. 초안의 `hits_remaining: int` 파라미터를 **제거**. 사유: B.1 "binary, not graded" 데이터 계약 보호 — VFX/Audio 소비자가 잔여 카운트를 *디자인 표면에 노출*할 수 없도록 architectural 차단. 다단계 강도 차별화가 필요하면 `phase_index` 또는 별도 boolean 플래그(`is_last_hit`) 도입 검토.
- `boss_hit_absorbed`는 phase 미전이 hit를 별도 시그널로 분리 (VFX 차별화). HUD 미구독.
- `boss_pattern_interrupted(boss_id, prev_phase_index)` (신규): phase 전이 또는 boss kill 직전 *동일 frame*에 emit. Boss Pattern GDD #11이 구독하여 in-flight active pattern(레이저 sweep, charge, AoE wind-up) 자체 cleanup. Damage GDD는 시그널만 발행하며 cleanup 메커니즘에 touch하지 않는다 (단방향 데이터 흐름).
- 페이즈 전이 *도중* 다중 hit (E.6): step 1에서 음수 카운트가 발생하더라도 phase는 *한 단계만* 전이. 잔여 음수 hits는 폐기 (DEC-2 일관성 — phase는 binary 게이트). **monotonic +1 lock의 디자인 결정 정당화는 ADR-00XX (Boss Phase Advance Monotonicity, queued)** — Tier 3에서 perfect parry / weapon-skip 등 디자인 공간을 열려면 새 ADR 필요.

---

### C.5 Hazard 통합 시그널 + cause taxonomy

#### C.5.1 Hazard 호스트 패턴

스테이지(#12)는 hazard를 다음 형태로 인스턴스화한다:

```text
Hazard (Area2D, layer=5, mask=1)
  ├─ CollisionShape2D
  └─ HitBox (자식 컴포넌트, cause = &"hazard_spike" 등)
```

- Hazard는 단일 `HitBox`만 보유 (HurtBox 없음 — 파괴 불가)
- ECHO HurtBox(L1)가 hazard HitBox(L5)와 충돌 → 표준 hurt 경로(C.3.2)와 *완전 동일* 처리 흐름
- Damage 시스템은 hazard와 적 발사체를 구분하지 않음. 차이는 오직 `cause` 라벨.

#### C.5.2 cause taxonomy (Tier 1 baseline, locked)

> **Tier 1 적 archetype 결정 의무 (game-designer 권고)**: Tier 1에 *드론 1종*만 존재한다면 baseline 6엔트리 충분. *3종 동시* 존재하면(`&"projectile_enemy_drone"`, `&"projectile_enemy_secbot"` 등) sub-entry 추가 필수 — B.3 "cause-aware death" 학습 가능성 보장. 결정은 Enemy AI GDD #10 작성 시 (OQ-DMG-7).

| StringName | 카테고리 | 발생원 |
|---|---|---|
| `&"projectile_enemy"` | 적 발사체 (Tier 1 baseline — 드론 1종) | 일반 적 (#10) |
| `&"projectile_boss"` | 보스 발사체 | 보스 (#11) |
| `&"hazard_spike"` | 환경 가시 (`hazard_` prefix invariant — DEC-6) | 스테이지 (#12) |
| `&"hazard_pit"` | 무한 낙하 | 스테이지 (#12) |
| `&"hazard_oob"` | OOB kill volume | 스테이지 (#12) — Time Rewind E-17 참조 |
| `&"hazard_crush"` | 압사 (이동 플랫폼) | 스테이지 (#12) — Tier 1 옵션 |

#### C.5.3 Tier 확장 정책

- Tier 2/3에 신규 cause를 추가할 때 본 표를 *append-only*로 갱신.
- 기존 cause의 시맨틱 변경 금지 (VFX/SFX/Audio 시스템이 결정론적으로 매핑하는 단일 출처).
- 신규 추가 시 `design/gdd/damage.md` D.3 갱신 + VFX(#14) / Audio(#4) GDD에서 매핑 표 업데이트 의무.

---

### C.6 i-frame 협조 (DEC-4 — SM이 HurtBox.monitorable 비활성화) + DEC-6 hazard grace

#### C.6.1 단방향 데이터 흐름 보존

본 GDD가 가장 강하게 방어하는 invariant: **Damage 시스템은 SM 상태를 알지 못한다**. 이로써 forbidden_pattern `cross_entity_sm_transition_call` + `damage_polls_sm_state` 위반을 원천 차단한다.

#### C.6.2 i-frame 메커니즘 (REWINDING)

| 시점 | 액터 | 액션 | 효과 |
|---|---|---|---|
| `RewindingState.enter()` | SM (외부 시스템) | `echo_hurtbox.monitorable = false` | Godot 충돌 엔진이 `HitBox.area_entered`를 발화하지 않음 → Damage는 자동으로 *침묵* |
| `RewindingState.exit()` | SM (외부 시스템) | `echo_hurtbox.monitorable = true` + `damage.start_hazard_grace()` | 적 탄환 검출 즉시 활성화. Hazard만 12프레임 grace (DEC-6) |

- "i-frame predicate"는 별도 변수가 아니라 `HurtBox.monitorable` 노드 속성 자체. 단일 출처.
- Damage 시스템은 `monitorable` 값을 *조회하지 않는다*. 다만 `HitBox.area_entered`가 *오지 않으면 작동하지 않는* 자명한 인과로 충분.

#### C.6.3 `lethal_hit_detected`와 monitorable 토글의 상호작용

- C.3.2에서 ECHO Damage 컴포넌트는 stage 1에서 *추가로* `echo_hurtbox.monitorable = false`를 자체 호출하지 **않는다**. SM이 DYING 전이 시점에 자기 책임으로 처리.
- 이유: Damage가 monitorable을 토글하면 두 출처(Damage + SM) 충돌. SM 단일 출처 원칙 (state-machine GDD AC-14 connect 순서 일관성).

#### C.6.4 Hazard grace 메커니즘 (DEC-6 — Pillar 1 보호)

`RewindingState.exit()` 직후 ECHO 위치가 hazard 영역 안에 거주하는 시나리오(가시 위 부활 등):

| 시점 | 액터 | 액션 | 효과 |
|---|---|---|---|
| `RewindingState.exit()` | SM | `damage.start_hazard_grace()` 호출 | Damage가 `_hazard_grace_remaining: int = hazard_grace_frames + 1 = 13` set (Round 4 B-R4-1 fix — `+1`은 동프레임 priority-2 decrement 보상) |
| `RewindingState.exit() + 1프레임` | Damage | `_physics_process(delta)` 시 `_hazard_grace_remaining -= 1` | 13 → 12 → ... → 1 카운트다운, 12개 flush 윈도우(200ms)에서 hazard 차단 |
| 카운트다운 중 hazard hit 도착 | Damage | `hurtbox_hit` 핸들에서 cause가 `&"hazard_*"` prefix이고 카운터>0이면 즉시 return | hazard cause만 차단, 적 탄환은 정상 수용 |
| 12프레임 만료 | Damage | 카운터 자연 0 도달 | 정상 hazard 검출 재활성화 |

**판정 술어**:

```text
should_skip_hazard(cause: StringName) :=
    _hazard_grace_remaining > 0
  ∧ str(cause).begins_with("hazard_")
```

> **`_physics_process` priority 사다리 등록 (Round 3 추가 — B-3 BLOCKING)**: ECHO Damage 컴포넌트의 `_physics_process`는 ADR-0003 `physics_step_ordering` 사다리에서 **priority = 2** 슬롯을 점유한다 (player=0, time-rewind-controller=1, **damage=2**, enemies=10, projectiles=20). 슬롯 선정 근거: TRC가 frame 상태를 캐시한 *후* (priority 1 종료) Damage 카운터가 감소해야 하며, 적 hit 디스패치 (priority 10) *이전*에 hazard grace 검사가 결정되어야 한다.
>
> **Frame-N 경계 invariant (Round 4 B-R4-1 정정)**: Godot 4.6에서 `Area2D.area_entered` 시그널은 PhysicsServer2D flush 단계에 동기 dispatch되며, 이는 모든 노드의 `_physics_process` *이전*에 발생한다. 그러나 SM의 `RewindingState.exit()`는 ECHO의 `_physics_process` (priority 0) **안에서** 호출되므로 `start_hazard_grace()`로 set된 counter는 같은 프레임의 priority-2 Damage `_physics_process`에서 즉시 1 감소한다. 따라서 *효과적 보호 길이는 `hazard_grace_frames` 개*가 되려면 초기값을 `hazard_grace_frames + 1`로 set해야 한다 (Round 4 B-R4-1 수정). 트레이스: F0 flush(monitorable=false 잔존, 차단)→F0 process(ECHO set 13, Damage 13→12)→F0+1 flush(counter=12, 차단)→...→F0+12 flush(counter=1, 차단)→F0+13 flush(counter=0, 통과). 12개 flush 윈도우 차단 ✓.
>
> **ADR-0003 갱신 의무 (queued)**: 본 priority 슬롯은 ADR-0003 사다리 표에 1줄 추가가 필요하다 — Boss Pattern GDD #11 작성 직전(OQ-DMG-9 ADR `signal-emit-order-determinism`과 함께)에 처리. 본 GDD가 단일 출처로 *선언*하며, ADR은 architecture-level 락인의 근거가 된다.

**디자인 정당화** (Pillar 1 "처벌이 아닌 학습 도구"):
- 플레이어가 토큰을 1개 소비하여 rewind했을 때 *학습 기회*를 보장.
- 12프레임은 입력 사이클 1회(60fps × 200ms = 12 ticks) — 점프/이동/사격 1회 가능 윈도우.
- 적 탄환은 차단하지 않음 — *환경 위험*만 grace 대상. 즉 "위치 회복 후 환경 재정비 시간"으로 판타지 일관.
- ECHO 외부 hazard cause(`hazard_spike`/`hazard_pit`/`hazard_oob`/`hazard_crush`) 4개 모두 grace 대상. 보스 발사체(`projectile_boss`)는 *대상 아님*.

**튜닝**: `hazard_grace_frames` knob (G.1) — Tier 1 lock 12, range 6-18.

#### C.6.5 `start_hazard_grace()` invocation API

`Damage.start_hazard_grace() -> void` (신규):
- 호출자: SM (RewindingState.exit())
- 효과: `_hazard_grace_remaining = hazard_grace_frames + 1` set (Round 4 B-R4-1 — `+1`은 동프레임 priority-2 decrement 보상; 효과적 12 flush 차단 윈도우)
- F.4에 등록. 단방향 SM → Damage.

#### C.6.6 hazard cause prefix convention

cause taxonomy(D.3.2)에서 `&"hazard_"` prefix를 *예약*. C.6.4 술어가 이 prefix로 환경 hazard와 적/보스 발사체를 구분. taxonomy 확장 시 (D.3.3 append-only) hazard 계열은 반드시 `&"hazard_"`로 시작 — 본 prefix invariant는 G.1 `cause_taxonomy_entries` knob 변경 시 의무.

---

## D. Formulas

> **Status**: Approved 2026-05-09.
>
> Echo는 binary 데미지 모델(DEC-3)이므로 `damage = base × crit × armor` 같은 *수치 공식*이 존재하지 않는다. 본 섹션의 "공식"은 (1) 충돌 술어(predicate), (2) 페이즈 상태 전이(transition), (3) cause 라벨링 mapping, (4) i-frame 술어(predicate) 4종으로 구성된다.

---

### D.1 HitBox-HurtBox 충돌 술어 (collision predicate)

#### D.1.1 정의

`hit(hb, hh) -> bool`은 다음 4개 조건의 **AND**로 결정된다 (Godot 4.6 Area2D 의미론 일관 — DEC-4):

```text
hit(hb: HitBox, hh: HurtBox) :=
    hb.monitoring                                          # (1) HitBox 능동 스캔 활성
  ∧ hh.monitorable                                         # (2) HurtBox 탐지 가능 (i-frame 단일 출처)
  ∧ layer_mask_check(hb.collision_mask, hh.collision_layer) # (3) 레이어 매트릭스
  ∧ shape_overlap(hb.shape, hh.shape, hb.xform, hh.xform)  # (4) 기하 겹침
```

> **[2026-05-09 수정 round 2]** 초안의 `hh.monitoring` 조건은 *제거*. Godot 4.6에서 HitBox(능동 스캐너)의 `area_entered`는 HurtBox `monitoring` 값과 무관하게 발화한다 — 따라서 `hh.monitoring`은 inert (무관) 조건이었다. 5개 → 4개 AND로 축소.

#### D.1.2 변수 정의

| 변수 | 타입 | 범위 | 출처 |
|---|---|---|---|
| `hb.monitoring` | bool | `{true, false}` (default true) | `Area2D.monitoring` (Godot 내장) — HitBox 능동 스캔 활성 |
| `hh.monitorable` | bool | `{true, false}` (default true) | `Area2D.monitorable` (Godot 내장) — i-frame 단일 출처 |
| `hb.collision_mask` | int (32비트) | `0` ~ `2^32-1`, 실제 사용 6비트 | C.2.2 매트릭스 |
| `hh.collision_layer` | int (32비트) | 단일 비트 (값 1·2·4·8·16·32 = bit 1·2·3·4·5·6) | C.2.1 할당 |
| `shape_overlap(...)` | bool | `{true, false}` | Godot 4.6 PhysicsServer2D 내장 |

> **레이어 표기 footnote**: C.2.1은 "Bit N" (1-indexed 위치)을 사용하고, D.1.2/예시는 collision_layer *값*(2^(N-1))을 사용한다. Godot 인스펙터 UI는 bit-index를, 코드 API(`collision_layer`, `collision_mask`)는 값을 다룬다. **변환**: bit 1 → value 1 (`0b000001`), bit 6 → value 32 (`0b100000`).

#### D.1.3 layer_mask_check 정의

```text
layer_mask_check(mask: int, layer: int) := (mask & layer) != 0
```

#### D.1.4 예시 계산

**예시 1 — 정상 hit (적 탄환이 ECHO에 명중)**

| 항목 | 값 |
|---|---|
| Enemy Projectile HitBox.monitoring | `true` |
| ECHO HurtBox.monitorable | `true` (ALIVE 상태) |
| HitBox.collision_mask | `0b000001` (L1만) |
| HurtBox.collision_layer | `0b000001` (L1) |
| `mask & layer` | `0b000001 ≠ 0` → true |
| shape_overlap | `true` (충돌) |
| **`hit(hb, hh)`** | **`true`** |

**예시 2 — i-frame 차단 (REWINDING 중 적 탄환)**

| 항목 | 값 |
|---|---|
| Enemy Projectile HitBox.monitoring | `true` |
| ECHO HurtBox.monitorable | **`false`** (SM이 RewindingState.enter()에서 비활성) |
| **`hit(hb, hh)`** | **`false`** (조건 (2) 실패 → 단락 평가. `HitBox.area_entered` 발화 자체가 차단됨) |

**예시 3 — 자해 차단 (ECHO 발사체가 ECHO에 겹침)**

| 항목 | 값 |
|---|---|
| ECHO Projectile HitBox.collision_mask | `0b100100` (L3·L6 = 4 + 32 = 36) |
| ECHO HurtBox.collision_layer | `0b000001` (L1 = 1) |
| `mask & layer` | `0b000000` → **0** |
| **`hit(hb, hh)`** | **`false`** (조건 (3) 실패 — Godot이 area_entered emit 자체를 차단) |

> **[2026-05-09 정정]** 초안의 `0b101100` (bits {3,4,6} = 44)은 typo. C.2.2 lock 매트릭스에 따르면 ECHO Projectile HitBox(L2)의 mask는 `{L3, L6}` = `0b100100` = 36. L4(enemy projectile) 비트는 mask에 포함되지 *않으며*, ECHO 탄환은 적 탄환을 명중시키지 않는다 (Tier 1 baseline — 탄환 cancel 메커닉 미존재).

---

### D.2 보스 phase 전이 공식 (DEC-2)

#### D.2.1 정의

같은 물리 틱 안에서 보스가 받은 hit 횟수를 `hits_in_tick(N)`이라 하자. Frame N → N+1의 상태 전이는:

```text
remaining'(b, N+1) := max(b.phase_hits_remaining(N) - hits_in_tick(N), 0)

if remaining'(b, N+1) > 0:
    state(b, N+1) := same phase, remaining = remaining'
elif b.phase_index(N) < b.final_phase_index:
    state(b, N+1) := advance phase, index += 1, remaining = b.phase_hp_table[index]
else:
    state(b, N+1) := killed
```

#### D.2.2 변수 정의

| 변수 | 타입 | 범위 | 의미 |
|---|---|---|---|
| `b.phase_index` | int | `0` ~ `final_phase_index` | 현재 페이즈 (0-based) |
| `b.phase_hits_remaining` | int | `0` ~ `phase_hp_table[phase_index]` | 잔여 hit 카운트 |
| `b.phase_hp_table` | `Array[int]` | length = `final_phase_index + 1`, 각 entry ≥ 1 | 페이즈별 시작 hit 수 — Boss Pattern GDD(#11) 단일 소유 |
| `b.final_phase_index` | int | ≥ 0 | 최종 페이즈 인덱스 (보통 1~3) |
| `hits_in_tick(N)` | int | ≥ 0 | 같은 프레임에 area_entered 발화된 횟수 |

#### D.2.3 페이즈 단일-단계 전이 보장 (E.6 보호)

`hits_in_tick(N) > b.phase_hits_remaining(N)`인 경우(같은 틱에 다중 명중):
- `remaining'`이 음수가 되지 않도록 `max(..., 0)` 클램프
- 페이즈 인덱스는 *오직 1만 증가* — 잔여 음수 hits는 폐기
- 이유: Pillar Reveal Through Action — 페이즈 전이는 *연출 게이트*이며, 서로 다른 페이즈를 한 프레임 안에 건너뛰면 시각·청각 계약 파괴

> **D.2.1 aggregate formula vs C.4.2 per-call handler 정합성 (Round 3 lock)**: D.2.1는 `hits_in_tick(N)`을 단일 aggregate로 다루는 *명세 모델*이지만, 실제 구현 경로는 C.4.2의 `area_entered` 콜백이 *hit별로 순차 호출*된다. 두 모델이 일치하려면 다음 invariant 중 하나가 필요:
>
> 1. **per-call lock (Round 3 채택)** — BossHost가 `_phase_advanced_this_frame: bool` 플래그 보유. 매 `_physics_process(delta)` 시작에서 `false` reset. 같은 물리 틱 안의 2회차 이후 `area_entered` 콜백은 lock 진입 시 즉시 `return` → 추가 `phase_hits_remaining` 감소·페이즈 전이·시그널 emit 없음. 잔여 hits 효과적으로 폐기 (D.2.1 max 클램프와 동등).
> 2. ~~aggregate buffer~~ — frame-end 일괄 처리 모델. 1프레임 처리 지연 발생; 채택 안 함.
> 3. ~~`phase_hp_table[i] >= max_simultaneous_projectile_count` 제약~~ — 동시 hit 수가 Boss Pattern GDD 통제권 밖이라 fragile; 채택 안 함.
>
> **반례 (lock 부재 시)**: `phase_hp_table=[2,1,5]`, `phase_index=0`, `phase_hits_remaining=2`, 동프레임 3 hits → call 1: remaining=1 (`boss_hit_absorbed`). call 2: remaining=0 → phase 0→1 (`boss_phase_advanced`). call 3: remaining=0 → phase 1→2 (**`boss_phase_advanced` 두 번째 emit**). lock 채택으로 call 3는 step 0에서 return → monotonic +1 보장.
>
> **AC-14 worst-case 갱신 의무**: 본 lock의 정합성은 AC-14가 `phase_hp_table[next] = 1` 케이스로 검증해야 한다 (이전 worked example의 `phase_hp_table=[5,8,12]`은 lock 부재에도 우연히 통과 — 공허 검증).

#### D.2.4 예시 계산

**예시 1 — 표준 단일 hit**

| 항목 | 값 |
|---|---|
| `phase_index(N)` | `0` |
| `phase_hits_remaining(N)` | `5` |
| `hits_in_tick(N)` | `1` |
| `remaining'(N+1)` | `max(5 - 1, 0) = 4` |
| 결과 | 동일 페이즈 유지, `remaining=4` |

**예시 2 — 페이즈 전이 (정확히 0)**

| 항목 | 값 |
|---|---|
| `phase_index(N)` | `0` |
| `phase_hits_remaining(N)` | `1` |
| `hits_in_tick(N)` | `1` |
| `remaining'(N+1)` | `0` |
| `final_phase_index` | `2`, `phase_hp_table = [5, 8, 12]` |
| 결과 | `phase_index → 1`, `phase_hits_remaining → 8` (`phase_hp_table[1]`) |

**예시 3 — 다중 hit 페이즈 전이 보호**

| 항목 | 값 |
|---|---|
| `phase_index(N)` | `0` |
| `phase_hits_remaining(N)` | `1` |
| `hits_in_tick(N)` | `3` (관통탄 + 일반탄 + 폭발) |
| `remaining'` | `max(1 - 3, 0) = 0` (음수 → 0 클램프) |
| 결과 | `phase_index → 1` (단일 단계만), `phase_hits_remaining → phase_hp_table[1]` |
| 폐기 | 잔여 -2 hits |

**예시 4 — 최종 페이즈 마지막 hit**

| 항목 | 값 |
|---|---|
| `phase_index(N)` | `2` (= final) |
| `phase_hits_remaining(N)` | `1` |
| `hits_in_tick(N)` | `1` |
| `remaining'` | `0` |
| 결과 | `boss_killed` emit, queue_free |

---

### D.3 cause taxonomy mapping (DEC-1 단일 소유)

#### D.3.1 cause 할당 의무 표 (호스트 측 contract — 런타임 함수 아님)

> **Round 3 명확화**: D.3.1은 *호스트가 인스턴스화 시점에 따라야 할 cause 할당 표*이지 *런타임 함수가 아니다*. C.1.2 step 2의 emit은 `self.cause`를 그대로 전파하며 분기 로직을 *수행하지 않는다*. 본 표는 호스트 시스템 작성자가 HitBox.cause를 set할 때 참조하는 documentation contract.

`HitBox.cause` 할당 규칙 (호스트 시스템 의무):

```text
host_assigns_cause(hb: HitBox, host_type) :=
    &"projectile_boss"   if host_type is Boss            # Boss Pattern GDD #11 의무
    else &"projectile_enemy"   if host_type is Enemy     # Enemy AI GDD #10 의무
    else <hazard label>                                   # Stage GDD #12 인스턴스별 라벨 ("hazard_spike" 등)
```

ECHO Projectile HitBox(L2)의 cause는 *명시적으로 미설정* (F.1 row #7) — ECHO 발사체는 적/보스 HurtBox를 명중시키며, 적/보스 측 핸들러(C.4)는 cause를 사용하지 않는다 (`enemy_killed`/`boss_*` 시그널만 emit; cause 인자는 그대로 forwarding). 미설정 fallback은 D.3.4에서 `&"unknown"` + debug-only push_error로 안전망.

#### D.3.2 cause 등록부 (Tier 1, append-only)

| StringName | 출처 (host 타입) | 발생 빈도 추정 |
|---|---|---|
| `&"projectile_enemy"` | 표준 적 (#10) 발사체 | 매우 높음 |
| `&"projectile_boss"` | 보스 (#11) 발사체 | 중간 |
| `&"hazard_spike"` | 스테이지 가시 | 중간 |
| `&"hazard_pit"` | 무한 낙하 영역 | 낮음 |
| `&"hazard_oob"` | OOB kill volume | 낮음 (디자인 안전망) |
| `&"hazard_crush"` | 압사 트랩 | 낮음 (Tier 1 옵션) |

#### D.3.3 변수 정의

| 변수 | 타입 | 범위 |
|---|---|---|
| `hb.host` | `Node` | 보스 / 적 / 스테이지 등 — `is`로 타입 판별 |
| `hb.cause` | `StringName` | D.3.2 표 entry 또는 `&""` (host 분기에서 결정 시) |

#### D.3.4 cause 미설정 시 fallback (E.7 처리)

`hb.cause == &""` 이면서 host 타입 분기도 적중하지 않을 경우:
- 시그널은 `&"unknown"`으로 emit (절대 silent 실패하지 않음)
- 동시에 Godot 콘솔에 `push_error("HitBox cause unset: %s" % hb.get_path())` 출력
- 의도된 영구 entry 아님 — 디버그 catch

---

### D.4 i-frame 술어 (HurtBox.monitorable 단일 출처)

#### D.4.1 정의

```text
is_invulnerable(echo_hurtbox: HurtBox) := !echo_hurtbox.monitorable
```

#### D.4.2 변수 정의

| 변수 | 타입 | 범위 | 의미 |
|---|---|---|---|
| `echo_hurtbox.monitorable` | bool | `{true, false}` | Godot Area2D 내장 속성. 단일 출처. |

#### D.4.3 단일 출처 계약

- `is_invulnerable`은 *별도 변수가 아니다*. `monitorable` 노드 속성의 부정.
- 본 시스템은 별도 `_iframe_timer`, `_invulnerable: bool` 캐시 변수를 보유하지 **않는다**.
- 무적 윈도우의 시작·종료 권한은 SM(`RewindingState.enter/exit`) + Time Rewind GDD Rule 11 (30프레임 시간 기반)이 단일 소유.
- Damage 시스템은 `is_invulnerable`을 *호출하지 않는다* — Godot 충돌 엔진이 `monitorable=false`인 HurtBox에 대해 *어떤 HitBox의* `area_entered`도 발화하지 않으므로, 본 술어는 외부 시스템(VFX 깜빡임 결정 등)의 *advisory* 조회용일 뿐.

> **`hazard_grace_remaining`은 별도 술어** (DEC-6 / C.6.4): hazard-only 부분 무적은 `is_invulnerable`과 직교. is_invulnerable은 *전체* 차단, hazard_grace는 *cause prefix 기반 부분* 차단. AC-33 검증.

#### D.4.4 예시

| 시점 | `monitorable` | `is_invulnerable` |
|---|---|---|
| ALIVE 정상 | `true` | `false` |
| DYING grace 윈도우 | `true` | `false` (취약 — 다중 hit 시 SM latch가 처리) |
| REWINDING 시작 (frame N+12) | `false` (SM이 비활성화) | `true` |
| REWINDING 종료 (frame N+42) | `true` (SM이 재활성화) | `false` (단, hazard cause는 12프레임 추가 grace — DEC-6) |

---

## E. Edge Cases

> **Status**: Approved 2026-05-09.

### E.1 동프레임 ECHO 다중 hit (관통탄 + 직접 충돌)

**상황**: 관통 적 탄환 + 직접 충돌하는 다른 적이 같은 물리 틱에 ECHO HurtBox에 area_entered emit.

**결과**:
- 첫 area_entered → ECHO Damage가 step 0 first-hit lock 가드(`_pending_cause == &""` → 통과) → step 1 `_pending_cause = cause₀` → step 2 `lethal_hit_detected(cause₀)` emit (TRC `_lethal_hit_head` 캐시) → step 3 `player_hit_lethal(cause₀)` emit. SM이 ALIVE → DYING 전이 + `_lethal_hit_latched = true` set.
- 두 번째 area_entered (같은 frame N 또는 DYING grace 중 N+k) → ECHO Damage `_on_hurtbox_hit(cause₁)` 재진입 → **step 0 first-hit lock**: `_pending_cause = cause₀ != &""` → 즉시 return. step 1/2/3 어느 것도 실행되지 않으며, `_pending_cause` 덮어쓰기 X · `lethal_hit_detected` 재emit X (TRC `_lethal_hit_head` 재캐시 X) · `player_hit_lethal` 재emit X. SM의 `_lethal_hit_latched` 가드는 step 3 이후의 secondary defence (Damage step 0이 이미 차단했으므로 도달 안 함).
- 결과: `_pending_cause = cause₀` 보존 → 12프레임 후 `commit_death(cause₀)` emit. TRC `_lethal_hit_head`도 첫 emit 시점에 캐시된 값 보존.
- **검증**: AC-36 (first-hit lock — Round 5 cross-doc S1 fix). 보조: state-machine.md AC-12 (단일 DYING 전이 + 단일 history entry). 단일 출처: `damage.md` C.3.2 step 0.

### E.2 REWINDING 중 적 탄환 명중 시도

**상황**: REWINDING 30프레임 윈도우 안에 적 탄환 HitBox가 ECHO 위치에 도달.

**결과**:
- SM의 `RewindingState.enter()`가 이미 `echo_hurtbox.monitorable = false` 설정.
- D.1.1 조건 (2) 실패 → Godot이 `HitBox.area_entered` 발화 자체를 차단.
- 적 탄환은 ECHO 좌표를 통과 (시각적으로는 그래픽이 겹쳐 보일 수 있음). 명중 효과 0.
- ECHO Damage 컴포넌트 코드 경로 진입 자체가 없음.
- **검증**: 통합 씬 테스트 — REWINDING 시뮬레이션 + 탄환 발사 + `lethal_hit_detected` 미emit 확인.

### E.3 hazard + 적 발사체 동프레임 명중

**상황**: ECHO가 가시(hazard_spike) 영역 안에서 동시에 적 탄환에 명중.

**결과**:
- 두 area_entered가 같은 frame N에 emit. Godot 4.6의 area_entered 호출 순서는 인스턴스 ID + 자식 인덱스 기반으로 결정론적이나 *어느 cause가 첫 emit인지*는 scene 구성에 의존.
- 첫 발화의 cause로 `lethal_hit_detected` emit + SM DYING. 두 번째는 latch 가드 (E.1과 동일).
- `_pending_cause`는 첫 발화 cause. VFX/SFX는 *어느 쪽이든* 학습 가능한 시그너처이므로 cause 비결정론은 *허용 가능*.
- **검증**: GUT — 두 area_entered 시뮬레이션 + 단일 `lethal_hit_detected` emit + cause는 첫 발화 매칭.

### E.4 보스 페이즈 전이 도중 다중 hit (D.2.3 cross-reference)

**상황**: `phase_hits_remaining = 1`일 때 동프레임 3 hits.

**결과**: D.2.3 적용. `remaining' = max(1-3, 0) = 0` → 페이즈 1단계만 전이. 잔여 -2 hits 폐기. `boss_phase_advanced` 정확히 1회 emit.

**검증**: GUT — phase_hits_remaining=1 + 3 hits emit + phase_index 정확히 +1 + advance 시그널 1회.

### E.5 적 시야 밖 데미지 (off-screen)

**상황**: ECHO가 카메라 viewport 밖에 있는 적에게 발사체로 명중.

**결과**:
- 본 시스템은 카메라/viewport를 *모른다*. HitBox.monitoring + HurtBox.monitorable + collision_layer만 판정 기준.
- 적이 active scene 트리에 있고 적 HurtBox.monitorable=true면 정상 처리 → `enemy_killed` emit.
- 적의 visibility-based 비활성화 최적화는 Enemy AI GDD(#10)의 책임. Damage는 무관.

### E.6 pickup vs damage HitBox 우선순위 (Tier 2 미래)

**상황**: 적 탄환 + 픽업 아이템이 ECHO 위치에 동시 도달.

**결과**:
- Pickup Area2D는 *별도 collision layer*(Tier 2 시스템 #15에서 할당 예정, 현 Tier 1에는 미존재).
- 두 area_entered는 *독립적*으로 ECHO 호스트의 별개 핸들러에서 처리.
- Damage가 `lethal_hit_detected` emit → SM DYING 전이.
- Pickup 처리는 ECHO 호스트의 자체 결정 (보통 DYING/REWINDING/DEAD 중 pickup 무시 — 별도 GDD 정의).
- **현 Tier 1**: pickup 시스템 미존재이므로 본 케이스 발생 불가. Tier 2 게이트에서 재방문.

### E.7 무기 swap 도중 데미지

**상황**: ECHO가 무기를 교체하는 사이(weapon-system #7 transition)에 적 탄환 명중.

**결과**:
- 본 시스템은 ECHO의 무기 상태를 *모른다*. ECHO HurtBox는 무기 swap 무관하게 active.
- 정상 hit 처리 — `lethal_hit_detected` emit → SM DYING.
- ECHO 호스트의 무기 swap 코루틴은 자체 cancel/cleanup 의무 (Player Movement #6 또는 Player Shooting #7 GDD 책임).

### E.8 발사체가 hazard 영역 통과

**상황**: 적 발사체 HitBox(L4)가 가시 hazard HitBox(L5) 영역을 통과.

**결과**:
- Enemy Projectile HitBox(L4)의 mask는 `0b000001` (L1만). L5 미포함 → 충돌 무시.
- 발사체는 가시를 *통과*. hazard와의 상호작용 없음.
- 만약 stage 디자인이 "가시가 발사체를 차단"하길 원하면, 가시는 별도 *발사체 차단 collider*를 추가 보유해야 함 (stage #12 책임). 본 GDD 무관.

### E.9 scene 경계 탄환 leak

**상황**: 발사체가 stage 경계 밖으로 이동.

**결과**:
- 본 시스템은 scene 경계를 *모른다*. 발사체 lifecycle은 호스트(#7/#10/#11)가 자체 관리.
- 발사체가 호스트에 의해 `queue_free()` 되면, 다음 프레임부터 area_entered 발화 안 함 (Godot 보장).
- 본 GDD는 호스트가 leak 방지 의무를 보유함을 *명시*만 함. 강제 mechanism 없음.

### E.10 ECHO 발사체가 ECHO 자기 HurtBox 명중 (자해 방지)

**상황**: ECHO 발사체가 발사 직후 자기 HurtBox와 기하 겹침.

**결과**: D.1.4 예시 3 적용. ECHO Projectile HitBox(L2)의 mask가 L1을 포함하지 않음 → Godot이 area_entered emit *자체*를 차단. 코드 가드 불필요.

### E.11 보스 phase_hp_table 길이 불일치 (호스트 misuse)

**상황**: Boss host가 `phase_hp_table.size() != final_phase_index + 1` 상태로 인스턴스화.

**결과**:
- D.2.1 단계 3에서 `phase_hp_table[index]` out-of-bounds 접근 시 Godot 런타임 에러.
- 본 GDD는 Boss host에 *검증 의무*를 부과: `_ready()` 안에 `assert(phase_hp_table.size() == final_phase_index + 1, "phase_hp_table length mismatch")`.
- 검증 누락 시 페이즈 전이 첫 시도에서 crash → 디자인 단계에서 즉시 catch.

### E.12 발사체 동프레임 명중 + 자체 destroy

**상황**: 적 발사체가 ECHO 명중 + 같은 프레임에 다른 collider(벽 등)에 부딪혀 `queue_free()`.

**결과**:
- Godot은 `queue_free()`를 *프레임 끝에* 처리 (idle phase). area_entered는 emit된 시점에 노드가 여전히 valid.
- ECHO HurtBox의 `hurtbox_hit` emit 정상 — `lethal_hit_detected` 정상 발화.
- 다음 프레임에 발사체 노드만 사라짐. ECHO 사망 처리는 영향 없음.

### E.13 RewindingState.exit() 직후 hazard 영구 거주

**상황**: ECHO가 가시 위에서 rewind 후 부활. REWINDING → ALIVE 전이.

**결과 [DEC-6 정책 — Pillar 1 보호]**:
- `RewindingState.exit()`가 `echo_hurtbox.monitorable = true` 복귀와 동시에 `damage.start_hazard_grace()` 호출 → `_hazard_grace_remaining = 12` set.
- 같은 frame 또는 다음 12프레임(약 200ms) 동안:
  - 적 탄환(`projectile_enemy`/`projectile_boss`) 명중 → 정상 처리 (DYING 진입). Pillar Challenge 일관성 — *해방* 아님.
  - hazard 명중(`hazard_*` prefix) → `hurtbox_hit` 핸들에서 즉시 return. 코드 경로 진입 0.
- 12프레임 내 플레이어가 입력 사이클 1회(점프/이동/사격) 행사 가능 → hazard 위치 이탈.
- 12프레임 만료 후 카운터 자연 0 → 정상 hazard 검출 재활성화. 이탈 실패 시 즉시 hazard 즉사.

**디자인 정당화** (Pillar 1 vs Pillar Challenge 균형):
- 토큰을 1개 소비한 플레이어가 *학습 기회 0*인 즉사 사이클에 갇히는 것을 방지 — 토큰이 *기능*하도록 보장.
- 12프레임 = 입력 사이클 1회 — *분석 시간 아님*, *반응 시간*. anti-fantasy "분노 시간이지 락아웃 아님" (Time Rewind GDD B.4) 일관.
- 적 탄환 면제 *없음* → punishing-but-fair 위협 밀도 보존. ECHO가 "탈출"한 것이 아니라 "환경에서 한 번 자리 옮길 시간"을 받았을 뿐.

**Level Design 의무 (보조 — 강제 아님)**: 0.15s 이전 위치가 hazard 영역 깊이 거주하지 않도록 배치 권장. 12프레임 grace는 *플레이어 input* 1회를 보장할 뿐, *모든* hazard 거주 케이스를 자동 해소하지 않는다.

> **Cross-doc 타이밍 정합성 (Round 4 — game-designer 권고 REC-R4-GD-1)**: `time-rewind.md` E-17 (`hazard_oob` 0.15s-ago 위치도 OOB 케이스)의 "re-death at i-frame end is intended behavior"는 REWINDING.exit() (frame N+30) 시점을 의미하지만, **DEC-6의 12프레임 hazard-only grace가 추가로 작동**하므로 실제 re-death 시점은 frame N+30+12 = N+42. 두 GDD를 따로 읽은 두 프로그래머가 다른 타이밍을 구현하지 않도록, time-rewind E-17에도 reciprocal note (DEC-6 12프레임 추가 지연 명시) 의무. **단일 출처는 본 GDD DEC-6 + C.6.4**.

**검증**: AC-24 (재작성).

### E.14 HitBox.cause 미설정 (호스트 misuse)

**상황**: Stage/Enemy 호스트가 `HitBox.cause`를 설정하지 않은 채 인스턴스화.

**결과**: D.3.4 fallback 적용. `&"unknown"` 시그널 + `push_error` 콘솔 출력. 디버그 catch 목적의 임시 entry.

**완화 책임**: 호스트 시스템은 `_ready()`에서 cause 설정 검증 권장 (강제 아님 — D.3.4 fallback이 안전망).

### E.15 보스 vs 보스 발사체 자해 (Tier 2 가능성)

**상황**: Tier 2/3에서 보스가 자기 발사체에 명중하는 디자인이 등장할 가능성.

**결과**:
- 현 Tier 1 매트릭스(C.2.2)에서 Boss HurtBox(L6)는 mask=2(L2 ECHO 발사체만). 보스 발사체(L4)는 L6 mask 안 함 → Godot이 차단.
- 만약 Tier 2 디자인에서 "보스 자해 페이즈"를 도입하려면 *별도 layer 비트 추가*(예: L7 self-vulnerable boss) 필요. 현 Tier 1 baseline은 자해 차단 보장.

---

## F. Dependencies

> **Status**: Approved 2026-05-09. F.5 갱신 의무는 Section H 완료 후 일괄 배치.

### F.1 Upstream Clients (HitBox/HurtBox 호스트)

본 GDD가 컴포넌트(HitBox/HurtBox 클래스 + cause taxonomy)를 *제공*하고, 다음 시스템들이 이를 자식 노드로 *인스턴스화*하여 호스트한다. 본 GDD는 호스트의 internal 구조에 touch하지 **않는다** (composition over inheritance).

| # | 시스템 | 호스트하는 컴포넌트 | 책임 |
|---|---|---|---|
| **#6** | [Player Movement](player-movement.md) | ECHO HurtBox (L1) + HitBox + Damage 노드 (PlayerMovement 자식 호스트) | **PM #6 Designed 락인 (2026-05-10)**: ECHO scene tree (= PlayerMovement CharacterBody2D root, player-movement.md A.Overview Decision A) 자식으로 인스턴스. ECHO HurtBox + HitBox + Damage 노드는 *PlayerMovement(CharacterBody2D)의 자식 노드*로 PM이 노드 *ownership*을 보유하며, lifecycle (특히 `monitorable` 토글)은 SM이 제어한다. `entity_id = &"echo"` 설정. **monitorable 토글 권한은 SM에 위임 (DEC-4) — 노드는 PM이 호스팅, lifecycle은 SM이 제어**. SM의 RewindingState.enter()/exit() + DEC-6 `start_hazard_grace()` invocation. |
| **#7** | Player Shooting | ECHO Projectile HitBox (L2) | 발사체 .tscn 자식으로 인스턴스. `cause` 미설정 (ECHO 발사체는 cause 라벨 무관 — 적/보스 destroy 측이 cause 미사용). |
| **#10** | Enemy AI | Enemy HurtBox (L3) + Enemy Projectile HitBox (L4) | 적 본체에 HurtBox, 적 발사체에 HitBox. HitBox.cause = `&"projectile_enemy"` (D.3 자동 분기). |
| **#11** | Boss Pattern | Boss HurtBox (L6) + Boss Projectile HitBox (L4) | `phase_hits_remaining` / `phase_index` / `phase_hp_table` 멤버 보유 의무 (E.11 검증 의무). HitBox.cause = `&"projectile_boss"` (D.3 자동 분기). |
| **#12** | Stage | Hazard HitBox (L5) | hazard Area2D 자식으로 인스턴스. `cause` 인스턴스별 라벨 설정 의무 (`&"hazard_spike"` 등). HurtBox 보유 안 함 (파괴 불가). |

### F.2 Downstream Consumers (시그널 구독자)

본 GDD가 *발행*하는 시그널을 다음 시스템들이 *구독*한다.

| # | 시스템 | 구독 시그널 | 핸들 동작 |
|---|---|---|---|
| **#5** | State Machine Framework | `player_hit_lethal(cause)` | EchoLifecycleSM이 ALIVE → DYING 전이 + `_lethal_hit_latched` set. `damage.commit_death()` / `damage.cancel_pending_death()` *호출* (단방향). |
| **#9** | Time Rewind | `lethal_hit_detected(cause)`, `death_committed(cause)` | TRC가 `_lethal_hit_head` 캐시 (frame N) + `death_committed`에서 buffer cleanup. ADR-0002 Amendment 1 일관. |
| **#13** | HUD | `boss_phase_advanced(boss_id, new_phase)` | 페이즈 전이 알림 (텍스트 또는 화면 효과). HP bar 미생성 (Anti-Pillar 일관). |
| **#14** | VFX | `hurtbox_hit(cause)`, `boss_hit_absorbed(...)`, `boss_phase_advanced(...)` | cause 기반 VFX 차별화 (cause taxonomy D.3 매핑). 보스 페이즈 전이 시 비주얼 layer 변화. |
| **#4** | [Audio System](audio.md) | `boss_killed(boss_id: StringName)`, `player_hit_lethal(cause: StringName)` | `boss_killed` → SFX 풀: `sfx_boss_defeated_sting_01.ogg` 재생 (audio.md Rule 13). `player_hit_lethal` → SFX 풀: `sfx_player_death_01.ogg` 재생 (audio.md Rule 17). Tier 1에서 cause + boss_id 무시. Audio #4 Approved 2026-05-12. |
| **#3** | [Camera System](camera.md) | `player_hit_lethal(_cause)`, `boss_killed(boss_id)` | Camera가 shake event 시작 — `player_hit_lethal` → 6 px / 12 frames impact shake; `boss_killed` → 10 px / 18 frames catharsis shake (camera.md R-C1-5 + F.1 row #4 reciprocal). cause는 무시 (Camera는 cause taxonomy 미사용 — 시그널 도착 자체가 트리거). Camera #3 Approved 2026-05-12 RR1 PASS. |

### F.3 시그널 발행 카탈로그 (Damage 시스템 owned, 단일 출처)

본 GDD가 발행하는 모든 시그널의 *전수 카탈로그*. 외부 시스템이 추가 시그널을 발화하려면 본 GDD를 갱신해야 함.

| 시그널 | 시그니처 | 발화 조건 | 소비자 |
|---|---|---|---|
| `lethal_hit_detected` | `(cause: StringName)` | ECHO HurtBox `HitBox.area_entered` (frame N) | #9 TRC |
| `player_hit_lethal` | `(cause: StringName)` | `lethal_hit_detected`와 동프레임 동순간 | #5 SM |
| `death_committed` | `(cause: StringName)` | SM이 `damage.commit_death()` 호출 시 (frame N+12) | #9 TRC, #4 Audio, #13 HUD |
| `hurtbox_hit` | `(cause: StringName)` | HurtBox 인스턴스 단위 (모든 entity 공통) | #14 VFX, #4 Audio |
| `enemy_killed` | `(enemy_id: StringName, cause: StringName)` | Enemy HurtBox 명중 시 | #4 Audio, (Tier 2: 통계 시스템) |
| `boss_hit_absorbed` | `(boss_id: StringName, phase_index: int)` | Boss phase 미전이 hit (DEC-5 — `hits_remaining` 제거) | #14 VFX |
| `boss_pattern_interrupted` | `(boss_id: StringName, prev_phase_index: int)` | phase 전이 또는 boss kill 직전 동프레임 emit (신규 — DEC-6 partner) | #11 Boss Pattern (in-flight active pattern cleanup) |
| `boss_phase_advanced` | `(boss_id: StringName, new_phase: int)` | Boss phase 전이 시 | #13 HUD, #14 VFX, #4 Audio, #11 Boss Pattern (자체 패턴 SM 재진입) |
| `boss_killed` | `(boss_id: StringName)` | Boss 최종 페이즈 마지막 hit | #2 Scene Manager (스테이지 클리어 트리거), #11 Boss Pattern (summon registry cleanup), #4 Audio |

### F.4 시스템 간 invocation API (단방향 method 호출)

시그널 외에 본 GDD가 *노출*하는 method API:

| API | 호출자 | 호출 시점 | 효과 |
|---|---|---|---|
| `Damage.commit_death() -> void` | #5 SM (DyingState.exit()) | grace 만료 시 | `_pending_cause`로 `death_committed` emit. `_pending_cause = &""` 초기화. **Idempotent**: `_pending_cause == &""`이면 즉시 return. |
| `Damage.cancel_pending_death() -> void` | #5 SM (RewindingState.enter()) | rewind 소비 시 | `_pending_cause = &""` 초기화. emit 없음. **Idempotent**: 이미 클리어 시 silent no-op. |
| `Damage.start_hazard_grace() -> void` | #5 SM (RewindingState.exit()) | 신규 (DEC-6) — i-frame 종료 직후 | `_hazard_grace_remaining = hazard_grace_frames + 1` set (Round 4 B-R4-1: `+ 1`은 동프레임 priority-2 decrement 보상; 효과적 12 flush 차단 윈도우). `_physics_process`에서 카운트다운. 단일 출처: C.6.5 / G.1. |

> **단방향성 보장**: 호출 방향은 *항상 외부 → Damage*. Damage는 외부 method를 호출하지 *않는다* — 시그널만 발행. 이로써 forbidden_pattern `cross_entity_sm_transition_call` + `damage_polls_sm_state` 우회 + 의존 그래프 순환 방지.

#### F.4.1 Emit 순서 결정론 contract (Pillar 2 — 신규)

같은 frame에 여러 시그널 emit이 발생할 때, 다중 소비자가 의존할 수 있는 *결정적* 순서를 명시한다. ADR-0003 `physics_step_ordering` 사다리는 `_physics_process` 호출 순서만 정렬하므로, 시그널 emit 순서는 본 GDD가 *추가로* 명시 의무가 있다.

**Frame N — ECHO HurtBox 명중 시 emit 순서**:

> **선행 emit (HitBox 측)**: `HurtBox.hurtbox_hit(cause)`는 *Damage 핸들러 진입 이전*에 HitBox 스크립트가 C.1.2 step 2에서 이미 emit. VFX/Audio는 그 시점에 수신.

```text
Damage._on_hurtbox_hit(cause):  # ← hurtbox_hit 수신 후 실행 (이 핸들러 안에서 hurtbox_hit 재emit 안 함)
  (1) _pending_cause = cause
  (2) emit lethal_hit_detected(cause)        # connect 1번: TRC → _lethal_hit_head 캐시
  (3) emit player_hit_lethal(cause)          # connect 1번: SM → ALIVE→DYING 전이 + latch set
                                              # connect 2번 이후: VFX/Audio (옵션)
```

**Frame N — Boss HurtBox 명중 + phase 전이 시 emit 순서**:

> **선행 emit (HitBox 측)**: `HurtBox.hurtbox_hit(cause)`는 *BossHost 핸들러 진입 이전*에 HitBox 스크립트가 C.1.2 step 2에서 이미 emit. VFX/Audio는 그 시점에 수신.

```text
BossHost._on_hurtbox_hit(cause):  # ← hurtbox_hit 수신 후 실행 (이 핸들러 안에서 재emit 안 함)
  (1) if _phase_advanced_this_frame:               # ← B-2 lock — 동프레임 2회차 hit는 lock 진입 시 즉시 폐기
        return
  (2) phase_hits_remaining -= 1
  (3) if phase_hits_remaining > 0:
        emit boss_hit_absorbed(boss_id, phase_index)
      elif phase_index < final_phase_index:
        emit boss_pattern_interrupted(boss_id, phase_index) # Boss Pattern SM cleanup 시그널 — phase_advanced 이전 의무
        phase_index += 1
        phase_hits_remaining = phase_hp_table[phase_index]
        _phase_advanced_this_frame = true                    # lock set
        emit boss_phase_advanced(boss_id, phase_index)      # HUD/VFX/Audio + Boss Pattern SM 재진입
      else:
        emit boss_pattern_interrupted(boss_id, phase_index)
        _phase_advanced_this_frame = true                    # lock set (boss_killed 분기도 monotonic +1 일관)
        emit boss_killed(boss_id)                           # Scene Manager + Boss Pattern (summon cleanup)
```

> **`_phase_advanced_this_frame` lifecycle**: BossHost는 본 bool 플래그를 멤버로 보유. 매 `_physics_process(delta)` 시작에서 `false`로 reset (혹은 동등한 frame-end deferred reset). 같은 물리 틱 안의 *2회차 이후* `area_entered` 콜백은 step (1) lock에서 즉시 return → D.2.3 monotonic +1 보장. AC-14 worst-case `phase_hp_table[next] = 1` + 3 simultaneous hits로 검증.

**연속 다중 소비자 순서**: `lethal_hit_detected` connect 순서 → `player_hit_lethal` connect 순서 → 각 시그널의 connect 순서가 결정적임을 *호스트 ECHO 노드의 `_ready()`*가 보장 (state-machine GDD AC-14 invariant + 본 GDD AC-28 신규).

**Connect 순서 invariant 코드** (ECHO 호스트의 `_ready()`):

```gdscript
# Damage 시그널 — 정해진 순서로 connect
damage.lethal_hit_detected.connect(trc._on_lethal_hit_detected)   # 1
damage.player_hit_lethal.connect(echo_lifecycle_sm._on_player_hit_lethal)   # 2
damage.death_committed.connect(trc._on_death_committed)            # 3
damage.death_committed.connect(audio._on_death_committed)          # 4
damage.death_committed.connect(hud._on_death_committed)            # 5
```

소비자 추가 시 본 GDD F.3 + F.4.1 표 동시 갱신 의무.

#### F.4.2 같은 frame 다중 enemy 사망 emit 순서

**상황**: 동프레임에 적 A·B·C가 동시 사망 (e.g., AOE 폭발).

**규칙** (Pillar 2 결정론):
- `enemy_killed` emit 순서는 *scene-tree 순서* (부모-자식 + 형제 인덱스). ADR-0003 spawn orchestrator가 `(spawn_frame, spawn_id)` 정렬 보장.
- 적 호스트의 `_on_hurtbox_hit` 핸들러는 `physics_step_ordering` 사다리 priority 10 슬롯에서 호출되며, 슬롯 안 동순위 형제는 scene-tree 순서로 결정적.
- 다중 소비자(VFX·Audio·Stats)가 *같은 순서*로 emit을 받음.

**검증**: AC-29 (신규).

### F.5 양방향 검증 — 갱신 의무 (rule 준수)

design-docs.md rule: *"Dependencies must be bidirectional — if system A depends on B, B's doc must mention A"*.

> **Round 1 (2026-05-09 초기) 갱신 완료** — 아래 모든 사이트.
> **Round 2 (2026-05-09 review)**: DEC-5/6 + 신규 시그널 (`boss_pattern_interrupted`) + 신규 invocation API (`start_hazard_grace`) 반영 의무.

| 다른 GDD | Round 1 상태 | Round 2 추가 의무 |
|---|---|---|
| `design/gdd/time-rewind.md` F.1 (Upstream 표) | *(provisional)* 제거 + 링크 + 시그니처 확정 ✓ | DEC-6 hazard grace = SM이 RewindingState.exit()에서 `damage.start_hazard_grace()` 호출 의무 추가 (Time Rewind GDD Rule 11 보강) |
| `design/gdd/state-machine.md` F.1 (Upstream 표) | provisional 제거 + 1-arg 확정 ✓ | RewindingState.exit() 시 `damage.start_hazard_grace()` invocation 1줄 추가 (DEC-6) |
| `design/gdd/state-machine.md` F.3 reverse-mention | "이미 멘션 — F.1" ✓ | 변경 없음 |
| `design/gdd/systems-index.md` System #8 row | Designed + Depends On 갱신 ✓ | Round 2 표기: "Designed (Round 2 reviewed 2026-05-09)" |
| `design/gdd/systems-index.md` Open Issue 표 | OQ-SM-1 Resolved ✓ | OQ-DMG-8/9 ADR queued 추가 |
| `docs/registry/architecture.yaml` | `interfaces.damage_signals` + `state_ownership.boss_phase_state` + `forbidden_patterns.damage_polls_sm_state` + `collision_layer_assignment` ✓ | Round 2: `damage_signals.signal_signature`에서 `boss_hit_absorbed` 2-arg + `boss_pattern_interrupted` 신규 + `start_hazard_grace` invocation_api 추가. `damage_signals.notes`에 emit ordering contract 1줄. |

> **시그널 naming convention 일관성 노트**: 프로젝트 convention(snake_case 과거형 — `health_changed`)과 비교 시 본 GDD의 시그널 명명은 다음과 같이 분류:
> - **과거형 일관**: `lethal_hit_detected`, `enemy_killed`, `boss_killed`, `boss_phase_advanced`, `boss_pattern_interrupted`, `boss_hit_absorbed`, `death_committed`, `hurtbox_hit`
> - **예외 (DEC-1 lock)**: `player_hit_lethal` — 형용사적 형태. 변경 시 state-machine GDD AC-14 + Time Rewind GDD Rule 4 동기화 필요. Round 2에서 보존 결정 (음성 분석: "player has been lethally hit" 의미상 과거형 일관, 단지 영어 어순 축약).

### F.6 의존성 그래프 (시각적 요약)

```text
                              ┌─────────────────────────────────────┐
                              │   Damage / Hit Detection (#8)       │
                              │   (HitBox/HurtBox 클래스 + cause)   │
                              └──────────────┬──────────────────────┘
                                             │
   ┌────────── HitBox/HurtBox 인스턴스 제공 ──┴── 시그널 발행 ────────┐
   │                                                                  │
   ▼ Upstream (호스트)                          Downstream (구독자) ▼

   #6 Player Movement      ────►              ────► #5 State Machine (player_hit_lethal)
   #7 Player Shooting      ────►              ────► #9 Time Rewind (lethal_hit_detected, death_committed)
   #10 Enemy AI            ────►              ────► #13 HUD (boss_phase_advanced)
   #11 Boss Pattern        ────►              ────► #14 VFX (hurtbox_hit, boss_*)
   #12 Stage (hazard)      ────►              ────► #4 Audio (hurtbox_hit, *_killed, *_committed)

                              ▲
                              │ method invocation (단방향)
                              │
                              #5 SM → Damage.commit_death() / cancel_pending_death()
```

---

## G. Tuning Knobs

> **Status**: Approved 2026-05-09.

### G.1 Owned Knobs (본 GDD가 단일 소유)

| Knob | 타입 / 단위 | 안전 범위 | 영향 영역 | 변경 시 의무 |
|---|---|---|---|---|
| **`cause_taxonomy_entries`** | `Array[StringName]` (append-only registry) | 전체 entry 수 ≤ 32 (Tier 1: 6) | cause 기반 VFX/SFX/Audio 차별화의 *어휘 풍부도*. hazard 계열은 `&"hazard_"` prefix 의무 (DEC-6). | append 시 VFX(#14)·Audio(#4)·HUD(#13) GDD에 매핑 추가 의무 |
| **`hurtbox_default_monitorable`** | const bool | locked: `true` (모든 HurtBox는 탐지 가능 상태로 인스턴스화) | 호스트가 명시적으로 비활성화하지 않는 한 *기본은 hit받음*. ECHO만 SM이 RewindingState에서 토글. | Tier 1에서 변경 금지 — 변경 시 적/보스도 i-frame 시스템 재설계 |
| **`hitbox_default_monitoring`** | const bool | locked: `true` | HitBox는 인스턴스화 즉시 능동 스캔. 발사체 launch 후 첫 프레임부터 명중 가능. | Tier 1에서 변경 금지 |
| **`hazard_grace_frames`** | const int | range 6-18, default **12** (locked Tier 1, DEC-6) | REWINDING.exit() 후 hazard cause 차단 윈도우 길이 (effective flush blocks). `start_hazard_grace()` 내부 set는 **`hazard_grace_frames + 1`** (Round 4 B-R4-1 — 동프레임 priority-2 decrement 보상). 짧으면 hazard 거주 미해결, 길면 적 탄환과 무관한 외부 위협 면제 길어짐. | Tier 1에서 변경 시 플레이테스트 + Pillar 1 vs Challenge 균형 재검증 |
| **`friendly_fire_enabled`** | const bool | locked: `false` (Tier 1) | 적 발사체(L4) ↔ 적 HurtBox(L3) 충돌 무시 — 적끼리 협동 처치 차단. | Tier 2 게이트에서 game-mode flag로 전환 검토 가능 (현 baseline 유지) |
| **`debug_unset_cause_emit_value`** | const StringName | locked: `&"unknown"` | E.14 미설정 cause 안전망. 디버그 빌드에서만 `push_error` 동반 (G.5). | Tier 1에서 변경 금지 — 디버그 catch 시그니처 |
| **`damage_frame_budget_ms`** | const float | locked: 1.0 ms (Tier 1) | per-frame Damage 시스템 누적 비용 상한 (gameplay+physics 6ms 중). signal fan-out + collision 핸들 + cause 분기 합산. | Tier 2에서 적 archetype 3종 도달 시 재측정. 초과 시 deferred connect 또는 cause cache 도입. |
| **`area2d_max_active`** | const int | locked: 80 (Tier 1) → 160 (Tier 3 천장) | 동시 활성 Area2D 개수 ceiling. ECHO·적·발사체·hazard 합산. Enemy AI GDD #10이 viewport-cull 책임 보유. | Tier 2 게이트에서 실측 후 갱신. Steam Deck 검증 의무. |

### G.2 Imported Knobs (다른 GDD 소유, 본 GDD가 *참조*)

본 GDD의 동작은 다음 외부 knob에 의해 결정되지만 *튜닝 권한은 보유하지 않는다*. 변경 요청은 소유 GDD를 경유.

| Knob | 소유 GDD | 본 GDD에서의 사용처 | 영향 영역 |
|---|---|---|---|
| **`dying_window_frames`** | Time Rewind GDD Rule 4 (default 12) | C.3.3 stage 2 발화 타이밍 | grace 윈도우 길이 — ECHO 1히트 카타르시스 vs 결정 시간 |
| **`REWIND_SIGNATURE_FRAMES`** | Time Rewind GDD Rule 11 (locked 30) | C.6.2 i-frame 윈도우 종료 시점 | REWINDING 후 ECHO 무적 시간 |
| **`phase_hp_table[boss_id]`** | Boss Pattern GDD (#11) per-boss | D.2.1 페이즈 전이 게이트 | 보스별 페이즈 hit 수 — 난이도 곡선 |
| **`final_phase_index[boss_id]`** | Boss Pattern GDD (#11) per-boss | D.2.1 마지막 phase 판정 | 보스 페이즈 단계 수 |
| **`collision_layer/mask` 비트 6개** | architecture.yaml `api_decisions.collision_layer_assignment` (F.5에서 등록 예정) | C.2.1, C.2.2 매트릭스 | 충돌 그래프 전체 — 디자인 변경 시 ADR 필요 |

### G.3 Future Knob Candidates (Tier 2/3, 현 Tier 1 활성화 안 함)

다음은 *현 Tier 1에서는 도입하지 않으나*, 향후 Tier 게이트에서 검토 가능한 후보.

| 후보 Knob | 도입 조건 | 가치 가설 |
|---|---|---|
| **`auto_rewind_on_first_hit`** (Easy mode #20) | Easy 모드 시스템 구현 + 1히트 즉사 접근성 검증 (Q4 후속) | 비숙련 플레이어가 *첫 hit*에서 자동 rewind 트리거 → 학습 곡선 완화. Pillar Challenge 일관성 검토 필요. |
| **`friendly_fire_enabled` toggle** | combat playground / boss rush 모드 | 디버그/sandbox 게임모드 표현. 본편 Pillar 부정합으로 메인 게임 비활성. |
| **`boss_hp_visible` toggle** (debug overlay) | dev build only | 밸런싱 디버그용. Production 빌드에서 강제 false. |
| **`hit_stun_duration` (적 전용)** | Tier 3 풀 비전 + 무기 종류 확장 | 무기 종류 확장 시 일부 무기에 hit-stun 부여 가능성. DEC-3 변경 필요 → 큰 디자인 결정. |

> **Tier 정책**: G.3 entries는 *현재 disabled*. 활성화 시 본 표 → G.1/G.2로 이전 + ADR 필요.

### G.4 Knob 안전성 매트릭스

| 변경 위험도 | Knobs |
|---|---|
| **LOW** (Tier 1에서 자유 변경 가능) | `cause_taxonomy_entries` (append-only) |
| **MEDIUM** (변경 시 다른 GDD 갱신 필요) | imported knobs (Time Rewind / Boss Pattern 소유 — 그쪽 GDD 경유), `hazard_grace_frames` |
| **HIGH** (변경 시 ADR 필요) | `collision_layer/mask` 비트 매트릭스, `friendly_fire_enabled` toggle, **monotonic phase advance** (D.2.3) |
| **LOCKED** (Tier 1에서 변경 금지) | `hurtbox_default_monitorable`, `hitbox_default_monitoring`, `debug_unset_cause_emit_value`, `damage_frame_budget_ms`, `area2d_max_active`, DEC-1~6 모두 |

### G.5 Debug-only knobs + Steam Deck 멀티플라이어

**Debug-only push_error 가드** (performance-analyst 권고):

```gdscript
# D.3.4 fallback에서:
if hb.cause == &"" and not _resolved_cause:
    if OS.is_debug_build():
        push_error("HitBox cause unset: %s" % hb.get_path())
    emit_cause = &"unknown"
```

이유: 미설정 cause 사례가 hazard 30개 × 60fps에서 1,800회/sec push_error 호출 → release 빌드에서 stderr 부담 + 성능 회귀 마스킹. `OS.is_debug_build()` 가드로 release에서 silent fallback (signal은 여전히 `&"unknown"`으로 emit됨 — 안전망 보존).

**Steam Deck CPU 멀티플라이어** (성능 검증 의무):

| 환경 | CPU 멀티플라이어 추정 | Damage budget 환산 |
|---|---|---|
| Dev PC (M1 Pro / Ryzen 5800X 등) | 1.0× baseline | 1.0 ms target |
| **Steam Deck (Zen 2 4-core)** | **2.5× slower (보수적)** | **2.5 ms 실측 시 한도 — 16.6ms 프레임 중 15% 초과는 fail** |

**의무**: Tier 1 게이트 종료 전 Steam Deck 또는 Deck-equivalent throttled CPU에서 *최악 케이스 combat scene* (5 enemies + 20 projectiles + 5 hazards) Damage 누적 비용 측정. AC-30 신규.

### G.6 Tier별 Knob 활성화 일정 (참고)

| Tier | 새로 활성화 |
|---|---|
| Tier 1 | G.1 + G.5 모두 LOCKED 값 (DEC-1~6) |
| Tier 2 | `friendly_fire_enabled` 게임모드 flag 검토, `area2d_max_active` 160 천장 검증 |
| Tier 3 | G.3 후보 (Easy auto_rewind, hit_stun_duration 등) — 별도 ADR 의무 |

---

## H. Acceptance Criteria

> **Status**: Approved 2026-05-09. 모든 AC는 testable. Test Type 컬럼은 coding-standards.md "Test Evidence by Story Type" 매트릭스 적용.

### H.1 Component Contracts (AC-1 ~ AC-4)

| AC | 검증 내용 | Test Method | Type |
|---|---|---|---|
| **AC-1** | `class_name HitBox extends Area2D` 명시 선언 + `cause: StringName` (default `&""`) + `host: Node` + `monitoring: bool` (default `true`) 보유 | GUT: ClassDB.class_exists("HitBox") + 인스턴스 속성 조회 | Logic |
| **AC-2** | `class_name HurtBox extends Area2D` 명시 선언 + `entity_id: StringName` + `monitorable: bool` (default `true`) + `signal hurtbox_hit(cause: StringName)` 보유 | GUT: ClassDB + 시그널 시그니처 inspection | Logic |
| **AC-3** | `HitBox.area_entered(area)` 핸들러가 `area is HurtBox` 가드 통과 시에만 `(area as HurtBox).hurtbox_hit.emit(self.cause)` 호출 | GUT: HitBox + non-HurtBox Area2D 충돌 시 emit 0회 + duck-typed Area2D (hurtbox_hit 시그널 보유하나 HurtBox 미상속)도 emit 0회 | Logic |
| **AC-4** | ECHO Damage 컴포넌트가 `commit_death() -> void` + `cancel_pending_death() -> void` + `start_hazard_grace() -> void` public method 노출 (DEC-6 추가) | GUT: `has_method` 검증 3개 메서드 모두 | Logic |

### H.2 Collision Predicate / Layer Matrix (AC-5 ~ AC-7)

| AC | 검증 내용 | Test Method | Type |
|---|---|---|---|
| **AC-5** | C.2.1 비트 할당 6개가 명세 그대로 (`echo_hurtbox=1`, `echo_projectile_hitbox=2`, `enemy_hurtbox=3`, `enemy_projectile_hitbox=4`, `hazard_hitbox=5`, `boss_hurtbox=6`) + 각 호스트 .tscn 인스턴스 layer/mask 매트릭스 일치 | GUT: 6개 호스트 컴포넌트 instantiate + collision_layer/mask 값 조회 + C.2.2 매트릭스 강비교 | Logic |
| **AC-6a** | D.1.1 cond (1) `hb.monitoring == false` → `hit = false` | GUT: HitBox.monitoring=false + 정상 layer/mask + overlap → emit 0회 | Logic |
| **AC-6b** | D.1.1 cond (2) `hh.monitorable == false` → `hit = false` | GUT: HurtBox.monitorable=false + 정상 layer/mask + overlap → `HitBox.area_entered` 발화 0회 | Logic |
| **AC-6c** | D.1.1 cond (3) `layer_mask_check == false` → `hit = false` | GUT: 미스매치 layer/mask + overlap → emit 0회 | Logic |
| **AC-6d** | D.1.1 cond (4) `shape_overlap == false` → `hit = false` | GUT: 정상 layer/mask + 비겹침 위치 → emit 0회 | Logic |
| **AC-7** | ECHO Projectile HitBox(L2, mask `0b100100`) + ECHO HurtBox(L1) 기하 겹침 시도 → `HitBox.area_entered` emit 0회 (자해 차단). 별도로 ECHO Projectile mask가 L4(`0b001000`)를 *포함하지 않음* 비트 검증 | GUT: 두 Area2D 기하 겹침 + emit 카운트 + collision_mask `& 0b001000 == 0` 검증 | Logic |

### H.3 ECHO 2-stage Death (AC-8 ~ AC-12)

| AC | 검증 내용 | Test Method | Type |
|---|---|---|---|
| **AC-8** | ECHO HurtBox area_entered 시 같은 frame 안에 `_pending_cause = cause` set 후 `lethal_hit_detected(cause)` + `player_hit_lethal(cause)` 정확히 1회씩 emit (Ordering invariant). 두 시그널 모두 동일 cause 인자. **추가 (Round 3)**: `HurtBox.hurtbox_hit` 시그널은 정확히 1회 emit (HitBox 측에서 — C.1.2 step 2). Damage `_on_hurtbox_hit` 핸들러는 `hurtbox_hit`를 재emit하지 *않음* | GUT: spy emit 카운트 (lethal_hit_detected=1, player_hit_lethal=1, hurtbox_hit=1, **재emit 0회**) + cause 비교 + emit 시점 `_pending_cause` 검증 | Logic |
| **AC-9** | E.1 동프레임 다중 hit: 첫 emit이 `_pending_cause = cause₀` set. **Round 5 갱신 (2026-05-10)**: 둘째 hit는 *primary*로는 Damage step 0 first-hit lock(C.3.2)에 의해 즉시 return → `lethal_hit_detected`/`player_hit_lethal` 둘 다 emit 0회. SM `_lethal_hit_latched`는 secondary defence (Damage step 0 우회 시에만 활성). `_pending_cause`는 cause₀ 유지 — 검증 시점은 동일. | Integration: Damage 컴포넌트 + SM stub + 두 번째 area_entered → emit-count 0회 + `_pending_cause == cause₀` 강비교 (AC-36 first-hit lock detail GUT scenario 참조) | **Integration** |
| **AC-10** | SM이 `damage.commit_death()` 호출 시 `death_committed(_pending_cause)` emit + 호출 후 `_pending_cause == &""` | GUT: pre-set `_pending_cause` + commit_death 호출 + spy | Logic |
| **AC-11** | SM이 `damage.cancel_pending_death()` 호출 시 `death_committed` emit 0회 + 호출 후 `_pending_cause == &""` | GUT: cancel_pending_death + emit 카운트 | Logic |
| **AC-12** | REWINDING 시뮬레이션 (echo_hurtbox.monitorable = false) + 적 HitBox area 발사 → `HitBox.area_entered` 발화 0회 → `lethal_hit_detected` emit 0회 | Integration: SM RewindingState.enter() + HitBox 스폰 + 두 시그널 모두 spy 카운트 | Integration |

### H.4 Boss Phase Transition (AC-13 ~ AC-16)

| AC | 검증 내용 | Test Method | Type |
|---|---|---|---|
| **AC-13** | D.2.1 분기: `remaining' > 0` → `boss_hit_absorbed(boss_id, phase_index)` emit (2-arg, DEC-5). `remaining' == 0 ∧ phase_index < final` → `boss_pattern_interrupted` 다음 `boss_phase_advanced`. `remaining' == 0 ∧ phase_index == final` → `boss_pattern_interrupted` 다음 `boss_killed` | GUT: 3개 분기 시나리오 emit spy + 시그널 emit 순서 검증 (F.4.1 contract) | Logic |
| **AC-14** | E.4 동프레임 다중 hit + **worst-case `phase_hp_table[next]=1`** (Round 3): `phase_hp_table=[2,1,5]`, `phase_index=0`, `phase_hits_remaining=2`, 동프레임 3 hits → `boss_phase_advanced` 정확히 1회 (lock 부재 시 2회 발화 — D.2.3 반례). `phase_index` 정확히 +1 (1단계만 전이). `boss_pattern_interrupted`도 정확히 1회. `_phase_advanced_this_frame` 검증: `area_entered` 콜백 후 true, 다음 `_physics_process` 시작 시 false reset (D.2.3 lock invariant) | GUT: 3 area_entered 동시 시뮬레이션 + phase_index 검증 + 시그널 카운트 + lock 플래그 lifecycle 검증 | Logic |
| **AC-15** | E.11 호스트 misuse: Boss host의 정적 메서드 `validate_phase_table(table: Array[int], final_idx: int) -> bool`가 (a) `table.size() == final_idx + 1` 검증 (b) `table.all(func(v): return v >= 1)` 검증 (DEC-2 추가). 잘못된 입력 4 case에서 false 반환 | GUT: validate_phase_table를 직접 호출하는 단위 테스트 (Boss 인스턴스화 불필요 — release 빌드도 검증 가능) | Logic |
| **AC-16** | `boss_phase_advanced` 발화 후 `phase_hits_remaining == phase_hp_table[new_phase_index]` (새 페이즈 HP 재로드). `boss_pattern_interrupted` emit이 `boss_phase_advanced` *직전* 발생 (F.4.1 ordering) | GUT: 전이 후 멤버 변수 검증 + emit 순서 spy | Logic |

### H.5 Hazard + Cause Taxonomy (AC-17 ~ AC-19)

| AC | 검증 내용 | Test Method | Type |
|---|---|---|---|
| **AC-17** | Hazard HitBox(L5)가 ECHO HurtBox(L1)에 area_entered → C.3.2 정상 흐름. emit된 cause는 hazard 인스턴스의 `cause` 라벨 (`&"hazard_spike"` 등) 그대로. cause는 `&"hazard_"` prefix 보유 (DEC-6 prefix invariant) | GUT: hazard with cause + ECHO HurtBox + cause 비교 + `cause.begins_with("hazard_")` 검증 | Logic |
| **AC-18a** | E.14 misuse: HitBox.cause 미설정 (`&""`) + host가 Boss/Enemy 미적중 → emit value = `&"unknown"` (silent fallback 보존) | GUT: cause 빈 HitBox + 명중 시뮬레이션 + 시그널 인자 검증 | Logic |
| **AC-18b** | (ADVISORY — 자동화 불가 시 manual) `OS.is_debug_build() == true` 환경에서 AC-18a 시나리오 실행 시 Godot Output 패널에 `push_error` 1회 노출 | Visual / Manual: 디버그 빌드 실행 + Output 패널 확인. release 빌드에서는 push_error 미발생 검증 | Visual |
| **AC-19** | Boss Projectile HitBox는 Boss host가 인스턴스화 시점에 `hb.cause = &"projectile_boss"`로 명시 set (D.3.1 표 호스트 contract). C.1.2 emit은 `self.cause`를 그대로 전파 — 분기 로직 없음. ECHO 명중 시 `lethal_hit_detected` 인자가 `&"projectile_boss"` | GUT: Boss 자식 HitBox 발사체 (cause set in `_ready()`) + ECHO HurtBox 명중 시뮬레이션 + cause 비교 | Logic |

### H.6 i-frame Coordination (AC-20 ~ AC-22)

| AC | 검증 내용 | Test Method | Type |
|---|---|---|---|
| **AC-20** | SM `RewindingState.enter()` 호출 시 `echo_hurtbox.monitorable == false`. `RewindingState.exit()` 호출 시 `echo_hurtbox.monitorable == true` + `damage.start_hazard_grace()` 1회 호출 | Integration: SM 전이 + monitorable 값 직접 조회 + invocation spy | Integration |
| **AC-21** | Damage 시스템 코드 검색에서 SM 상태 조회(`state_machine.<member>` 모든 access + `get_node("StateMachine").current_state` 등 alias 경로 포함) 호출 0회 | CI: `tools/ci/damage_static_check.sh`가 두 grep 실행 → exit code 0 (no matches): (1) `grep -rE "state_machine\.[a-zA-Z_]+" src/systems/damage/` (모든 멤버 access 차단 — Round 4 broadening), (2) `grep -rE 'get_node\(.*StateMachine.*\)\.[a-zA-Z_]+' src/systems/damage/` (node-path alias 차단). 추가로 PR review checklist (ADVISORY)가 새 SM 멤버 명명 시 정규식 갱신 의무를 명시. | Logic (static) |
| **AC-22** | D.1 cond (2) 실패 시뮬레이션: `echo_hurtbox.monitorable = false` 상태에서 적 HitBox area 기하 겹침 → `HitBox.area_entered` 발화 0회 (Godot 4.6 Area2D semantics 검증) | GUT: HurtBox.monitorable=false + HitBox.monitoring=true + 기하 overlap + HitBox spy → area_entered emit 0회 | Logic |

### H.7 Edge Cases Coverage (AC-23 ~ AC-25)

| AC | 검증 내용 | Test Method | Type |
|---|---|---|---|
| **AC-23** | (consolidated into AC-7 — `hurtbox_hit` end-to-end 자해 차단 검증) ECHO Projectile 노드 spawn + 5 frame physics step 진행 + ECHO HurtBox와 겹친 위치 통과 → `hurtbox_hit` emit 0회 | Integration: 전체 스폰→이동→충돌 사이클을 physics_frame await로 검증 | Integration |
| **AC-24** | E.13 hazard grace (DEC-6, Round 4 B-R4-1 fix): RewindingState.exit() 시 `_hazard_grace_remaining = hazard_grace_frames + 1 = 13` set. 동프레임 priority-2 decrement → 12. 후속 12개 flush 윈도우(F0+1 ~ F0+12)에서 hazard `lethal_hit_detected` 차단 + 적 탄환 cause는 정상 hit. F0+13 flush부터 hazard hit 재개 (counter=0). 만료 시점은 spec'd 12 flushes — 13 flushes 차단되면 fail (off-by-one regression). | Integration: REWINDING 종료 + 미리 배치된 hazard + 13개 internal physics step + cause-별 emit 카운트 검증 (12 차단 + 1 통과) | Integration |
| **AC-25** | E.12 발사체 동프레임 destroy: 적 발사체가 ECHO 명중과 같은 frame에 `queue_free()` 호출 → `hurtbox_hit` emit 정상 1회 + `await get_tree().physics_frame` 후 `is_instance_valid(projectile) == false` | GUT: 명중 + 즉시 queue_free + emit 1회 + 다음 frame instance valid 검증 | Logic |

### H.8 Bidirectional Dependencies (AC-26 ~ AC-27)

| AC | 검증 내용 | Test Method | Type |
|---|---|---|---|
| **AC-26** | `design/gdd/time-rewind.md` F.1 표의 #8 행에서 *(provisional)* 태그 부재 + 본 GDD 링크 (`design/gdd/damage.md`) 존재 + `lethal_hit_detected`/`death_committed` 시그니처 명시 | PR Review checklist (advisory): F.5 갱신 후 grep `provisional` in `time-rewind.md`의 #8 row + 링크 확인 | Manual |
| **AC-27** | `design/gdd/state-machine.md` F.1 표의 #8 행에서 `provisional contract` 태그 부재 + `player_hit_lethal(cause: StringName)` 1-arg 시그니처 명시 + AC-22 reconcile 노트 존재 | PR Review checklist (advisory): F.5 갱신 후 grep + 시그니처 라인 확인 | Manual |

> **AC-26/AC-27 정책 변경**: 본 두 AC는 *문서 상태 검사*이므로 BLOCKING 자동 테스트 게이트로 부적합 (qa-lead 권고). PR Review checklist의 ADVISORY 항목으로 격하. CI 자동화는 OQ-DMG-5 (`tools/ci/gdd_consistency_check.gd`) 작성 시 BLOCKING으로 환원.

### H.9 신규 ACs (AC-28 ~ AC-36 — 커버리지 갭 + DEC-5/6/F.4.1 + Round 5 first-hit lock)

| AC | 검증 내용 | Test Method | Type |
|---|---|---|---|
| **AC-28** | F.4.1 connect 순서 invariant: ECHO `_ready()` 실행 후 `damage.lethal_hit_detected.get_connections()`의 0번 인덱스가 TRC, `damage.player_hit_lethal.get_connections()`의 0번 인덱스가 SM. 순서 변경 시 본 AC 실패 | GUT: `_ready()` 실행 + `get_connections()` 검사 | Logic |
| **AC-29** | F.4.2 같은 frame 다중 enemy 사망 emit 순서 (Pillar 2 결정론): 적 A·B·C 동프레임 사망 시뮬레이션 1000회 → `enemy_killed` emit 순서가 *모든 1000회* **고정 fixture 기대 순서와 일치** (scene-tree-order 기반). | GUT: 결정성 1000-cycle 테스트. **expected_order는 fixture가 단일 출처로 정의** (예: `const EXPECTED_ORDER := [&"enemy_A", &"enemy_B", &"enemy_C"]` — 부모-자식 + 형제 인덱스 명시). 각 cycle의 actual emit 순서를 fixture와 strict equality 비교 (run-1 self-capture 금지 — Round 4 fix; baseline self-reference는 broken-from-t=0 시스템도 통과시킴). 1 cycle이라도 mismatch 시 fail. | Logic |
| **AC-30** | G.5 Steam Deck 성능 budget: 5 enemies + 20 projectiles + 5 hazards 동시 활성 + 60fps 5분 플레이 시 Damage 시스템 누적 비용 ≤ 2.5ms (Deck-equivalent throttled CPU) | Integration: Godot profiler + Deck-equivalent build (또는 Steam Deck 실측) + per-frame breakdown screenshot | Integration |
| **AC-31** | `commit_death()` idempotency: `_pending_cause == &""` 상태에서 호출 시 `death_committed` emit 0회 + 상태 변화 없음 | GUT: 미설정 상태 commit_death + spy | Logic |
| **AC-32** | `cancel_pending_death()` idempotency: `_pending_cause == &""` 상태에서 호출 시 silent no-op (에러 없음) | GUT: 미설정 상태 cancel_pending_death + push_error spy 0회 | Logic |
| **AC-33** | DEC-6 hazard grace 진단 술어: `should_skip_hazard(cause)` 4 case 검증 — (a) `_hazard_grace_remaining=0 + cause=hazard_spike` → false (b) `=12 + hazard_spike` → true (c) `=12 + projectile_enemy` → false (d) `=12 + cause=&""` → false | GUT: 4 case 직접 호출 | Logic |
| **AC-34** | `enemy_killed` 시그널 전체 경로: ECHO Projectile HitBox(L2) → Enemy HurtBox(L3) area_entered → `enemy_killed(entity_id, cause)` emit 1회 + cause는 ECHO Projectile의 `host` 분기로 결정 (D.3.1) | GUT: ECHO Projectile + Enemy HurtBox 시뮬레이션 + spy | Logic |
| **AC-35** | Layer 완전성: 6개 호스트(`echo`, `echo_proj`, `enemy`, `enemy_proj`, `hazard`, `boss`) 각각 인스턴스화 시 collision_layer 정확히 단일 비트 set + collision_mask가 C.2.2 매트릭스 정확 일치 | GUT: 6 호스트 .tscn 로드 + 12 값 (layer×6 + mask×6) 모두 강비교 | Logic |
| **AC-36** | C.3.2 step 0 first-hit lock (Round 5 cross-doc S1 fix 2026-05-10): ECHO Damage `_on_hurtbox_hit`에 `cause₀`로 진입 → `_pending_cause = cause₀`, `lethal_hit_detected` emit 1회, `player_hit_lethal` emit 1회. *같은 frame N* 또는 *DYING 윈도우 N+1..N+11 중* `cause₁`로 재진입 → step 0 가드가 `_pending_cause != &""` 감지 → 즉시 return → `_pending_cause` 변경 X (`cause₀` 보존) + `lethal_hit_detected` emit 0회 (TRC `_lethal_hit_head` 재캐시 차단) + `player_hit_lethal` emit 0회. `commit_death()` 호출 후 `_pending_cause = &""` 클리어 → 다음 lethal 사건은 정상 통과. | GUT: ECHO Damage 인스턴스 + 첫 `hurtbox_hit(cause₀)` + 즉시 두 번째 `hurtbox_hit(cause₁)` + `lethal_hit_detected`/`player_hit_lethal` emit-count spy + `_pending_cause` member 강비교. 추가 시나리오: `commit_death()` 호출 후 클리어 검증 + 새 `hurtbox_hit(cause₂)` → 정상 1회 emit. | Logic |

### H.10 Test File Layout (갱신)

```text
tests/unit/damage/
├── damage_component_contract_test.gd       # AC-1 ~ AC-4 + AC-35
├── damage_collision_predicate_test.gd      # AC-5 ~ AC-7
├── damage_2stage_death_test.gd             # AC-8, AC-10, AC-11, AC-31, AC-32
├── damage_boss_phase_test.gd               # AC-13 ~ AC-16
├── damage_cause_taxonomy_test.gd           # AC-17 ~ AC-19
├── damage_iframe_coordination_test.gd      # AC-22, AC-33
├── damage_edge_cases_test.gd               # AC-25
├── damage_misuse_test.gd                   # AC-15, AC-18a
├── damage_signal_ordering_test.gd          # AC-28
├── damage_emit_determinism_test.gd         # AC-29 (1000-cycle)
└── damage_enemy_killed_test.gd             # AC-34

tests/integration/damage/
├── damage_rewinding_iframe_test.gd         # AC-12, AC-20
├── damage_hazard_grace_test.gd             # AC-24 (DEC-6)
├── damage_self_harm_e2e_test.gd            # AC-23 (consolidated)
├── damage_2stage_dying_latch_test.gd       # AC-9 (Integration moved)
└── damage_perf_budget_test.gd              # AC-30 (Steam Deck)

production/qa/evidence/damage/
├── damage_bidirectional_check_YYYYMMDD.md  # AC-26, AC-27 (PR review checklist)
└── damage_push_error_visual_check.md       # AC-18b (debug-build manual)

tools/ci/
└── damage_static_check.sh                   # AC-21 (grep CI)
```

### H.11 AC 통계 (Round 3 갱신 — count math 정정)

- **Total**: 39 AC
- **Logic GUT**: 29 (AC-1, 2, 3, 4, 5, 6a, 6b, 6c, 6d, 7, 8, 10, 11, 13, 14, 15, 16, 17, 18a, 19, 22, 25, 28, **29**, 31, 32, 33, 34, 35) — AC-29(결정성 1000-cycle) 명시 enumerate
- **Integration**: 6 (AC-9, AC-12, AC-20, AC-23, AC-24, AC-30)
- **Visual / Manual (ADVISORY)**: 3 (AC-18b debug build push_error, AC-26/27 PR checklist)
- **Static CI**: 1 (AC-21 — `tools/ci/damage_static_check.sh`)
- **합계 검증**: 29 + 6 + 3 + 1 = **39 ✓**
- **결정성 1000-cycle**: 1 (AC-29) — Pillar 2 결정론 게이트
- **신규 AC (Round 2)**: AC-6a~6d (split), AC-18a/b (split), AC-28~35 (8건 신규)
- **Round 3 갱신 AC**: AC-8 (hurtbox_hit 재emit 0회 추가), AC-14 (worst-case `phase_hp_table[next]=1` + lock 플래그 lifecycle), AC-19 (host 인스턴스화 시 cause set로 reframe)

> **이전 "Logic GUT: 27" 오류 정정 (Round 3)**: enumerated 28 + AC-29 implied = 실제 29. 새 enumeration은 AC-29를 명시적으로 포함하여 ambiguity 제거.

---

## Z. Open Questions

> **Status**: Approved 2026-05-09.

| ID | 카테고리 | 질문 | 결정 시점 | Resolution Path |
|---|---|---|---|---|
| **OQ-DMG-1** | Future Tuning | Tier 2 `friendly_fire` 게임모드의 디자인 — combat playground / boss rush 시 적끼리 협동 처치 효과를 *허용*하는지, *허용하되 통계 무효*인지, *완전 차단*인지? | Tier 2 게이트 (Game Modes 시스템 도입 시) | Game Designer 검토 + Player Movement #6 / Enemy AI #10 GDD 작성 시 cross-check |
| ~~**OQ-DMG-2**~~ ✅ Resolved RR3 | Boss Cleanup | Boss `phase_advanced` 시점에 *기존 보스 발사체* 처리 → `boss_pattern_interrupted` emit + Boss Pattern SM이 자체 cleanup | C.4.2 + F.3 | DEC-RR3 |
| ~~**OQ-DMG-3**~~ ✅ Resolved RR4 | Boss Cleanup | `boss_killed` 시 summon cleanup → Boss Pattern GDD #11이 자체 summon registry 보유 + `boss_killed` 구독 | C.4.2 + F.2 | DEC-RR4 |
| **OQ-DMG-4** | Pickup System | Tier 2 시스템 #15 (Pickup) 도입 시 collision_layer 비트 7+ 할당 + ECHO HurtBox와의 우선순위 매트릭스 필요? E.6은 *발생 시점*만 기술. | Tier 2 게이트 + Pickup GDD 작성 시 | Pickup GDD가 본 GDD C.2 매트릭스를 *append*하여 비트 7 할당. E.6 표를 *resolved*로 갱신. |
| **OQ-DMG-5** | Tooling | H.8 (AC-26, AC-27) bidirectional check를 CI 자동화 가능한가? (예: grep + 정규식으로 다른 GDD의 #8 행에서 *(provisional)* 태그 부재 검증) | DevOps 시스템 구축 시 | `tools/ci/gdd_consistency_check.gd` 또는 shell 스크립트로 자동화. 현 Tier 1에서는 PR review checklist (ADVISORY). |
| **OQ-DMG-6** | Pillar Tuning | Boss phase advance 시점에 ECHO에게 *짧은 grace* (예: 6프레임 i-frame)를 SM이 부여해야 하는가? 페이즈 전이 폭발 회피 도움 vs 1히트 카타르시스 희석 | Tier 1 플레이테스트 (Boss 첫 인카운터 검증 후) | 현 baseline은 부여 *안 함* — Pillar 1히트 일관성 우선. 플레이테스트 결과에 따라 SM `BossPhaseGraceState` 추가 검토. |
| **OQ-DMG-7** | Tier 1 Scope | Tier 1 적 archetype 수 — 1종(드론만) vs 3종(드론·경비로봇·STRIDER 잡몹). 3종 시 cause taxonomy `projectile_enemy_*` sub-entry 추가 필수 (B.3 학습 가능성) | Enemy AI GDD #10 작성 시 | Enemy AI GDD가 archetype 수 결정 → Damage GDD C.5.2 taxonomy 갱신 + VFX·Audio GDD 매핑 추가 |
| **OQ-DMG-8** | ADR Queue | `D.2.3 monotonic +1 phase advance lock` ADR 작성 — perfect parry/skill skip 디자인 공간 영구 폐쇄 결정 명시 | Boss Pattern GDD #11 작성 직전 | `/architecture-decision boss-phase-advance-monotonicity` |
| **OQ-DMG-9** | ADR Queue | `signal emit ordering determinism` ADR — F.4.1/F.4.2 결정론 contract를 architecture-level 결정으로 격상 | Tier 1 prototype 시작 직전 | `/architecture-decision signal-emit-order-determinism` |
| **OQ-DMG-10** | Performance | Steam Deck 실측 환경 확보 또는 Deck-equivalent throttled CPU 빌드 셋업 (AC-30 검증 의무) | Tier 1 게이트 종료 직전 | DevOps + technical-director — Deck 또는 동등 환경에서 Damage budget 측정 |

### Resolved During Authoring (참고)

본 세션에서 *해소된* 질문:

| ID | 질문 | 결정 | 위치 |
|---|---|---|---|
| OQ-SM-1 | `Damage.player_hit_lethal` 시그니처 | 1-arg `cause: StringName` | DEC-1 (본 GDD 상단) |
| (provisional in time-rewind) | Damage 시그널 시그니처 | `lethal_hit_detected(cause)` + `death_committed(cause)` 1-arg | C.3.1 |
| (provisional in time-rewind) | hazard 통합 시그널 | 모든 hazard는 동일 `lethal_hit_detected/player_hit_lethal` 경로 + cause 라벨로 차별 | C.5 + D.3 |
| (skeleton OQ) | i-frame 제어 주체 | SM이 `echo_hurtbox.monitorable` 토글 (DEC-4) | C.6 + D.4 |
| OQ-DMG-RR1 (round 2) | `boss_hit_absorbed` 시그니처 hits_remaining 포함 여부 | DEC-5 — 2-arg (boss_id, phase_index)로 축소. binary 데이터 계약 보호 | C.4.2 + F.3 |
| OQ-DMG-RR2 (round 2) | E.13 hazard 영구 거주 정책 | DEC-6 — 12프레임 hazard-only grace + Pillar 1 보호 | C.6.4 + E.13 |
| OQ-DMG-RR3 (round 2) | in-flight active pattern 연속성 | `boss_pattern_interrupted` 시그널 신규 — Boss Pattern SM이 cleanup 책임 | C.4.2 + F.3 |
| OQ-DMG-RR4 (round 2) | summon cleanup 책임자 | Boss Pattern GDD #11이 자체 summon registry 보유 + `boss_killed` 구독해 자체 free | C.4.2 + F.2 |

---

## Appendix A. References

- `design/gdd/time-rewind.md` — System #9 (2-stage death 의무 부과: Rule 4 + E-11)
- `design/gdd/state-machine.md` — System #5 (player_hit_lethal 구독자, AC-22 1-arg 가정 → 본 GDD가 락인)
- `design/gdd/game-concept.md` — Pillar 1히트 즉사 (Challenge primary)
- `docs/architecture/adr-0003-determinism-strategy.md` — process_physics_priority 사다리 (적 = 10, 발사체 = 20)
- `docs/registry/architecture.yaml` — `forbidden_patterns.cross_entity_sm_transition_call`, `damage_polls_sm_state`, `rigidbody2d_for_gameplay_entities`, `api_decisions.collision_layer_assignment`, `interfaces.damage_signals`, `state_ownership.boss_phase_state`
- `.claude/docs/technical-preferences.md` — Naming + 16.6ms 예산
- **Queued ADR**: `boss-phase-advance-monotonicity` (OQ-DMG-8 — D.2.3 lock)
- **Queued ADR**: `signal-emit-order-determinism` (OQ-DMG-9 — F.4.1 / F.4.2 lock)
- **Round 2 review (2026-05-09)**: 7-specialist adversarial review + creative-director synthesis. Verdict: MAJOR REVISION → 8 BLOCKING + 12 RECOMMENDED 모두 적용. DEC-5/6 + AC 8건 신규 + ordering contract + Steam Deck 검증 의무 추가.
