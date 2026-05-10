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

[To be designed]

### C.2 Movement States and Transitions (PlayerMovementSM)

[To be designed]

### C.3 Per-Tick Frame Loop (`_physics_process`)

[To be designed]

### C.4 Restore Path (`restore_from_snapshot()` + `_is_restoring` Guard)

[To be designed]

### C.5 Input Contract (Provisional pending Input System #1)

[To be designed]

### C.6 Interactions With Other Systems

[To be designed]

---

## D. Formulas

### D.1 Run Acceleration / Deceleration

[To be designed]

### D.2 Jump Velocity / Gravity / Apex

[To be designed]

### D.3 Coyote Time / Jump Buffer Predicates

[To be designed]

### D.4 Facing Direction Update

[To be designed]

---

## E. Edge Cases

[To be designed]

---

## F. Dependencies

### F.1 Upstream Dependencies (Player Movement consumes)

[To be designed]

### F.2 Downstream Dependents (consume Player Movement state/signals)

[To be designed]

### F.3 Signal Catalog (owned by Player Movement)

[To be designed]

### F.4 Bidirectional Update Obligations

[To be designed]

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
