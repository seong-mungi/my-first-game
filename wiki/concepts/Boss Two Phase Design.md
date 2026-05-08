---
type: concept
title: Boss Two Phase Design
created: 2026-05-08
updated: 2026-05-08
tags:
  - game-design
  - combat
  - boss
  - run-and-gun
  - design-pattern
related:
  - "[[metal-slug alfredo1995]]"
  - "[[MetalSlugClone giacoballoccu]]"
  - "[[Abstract Base Class Pattern]]"
  - "[[Run and Gun Genre]]"
  - "[[Metal Slug]]"
  - "[[Boss Two Phase Design]]"
confidence: high
---

# Boss Two Phase Design

## 정의

**보스 2페이즈 설계(Boss Two-Phase Design)**란 보스 전투를 HP 임계값(또는 시간, 이벤트)으로 구분된 두 단계로 나누어, 각 단계에서 다른 행동 패턴·속도·공격을 보여주는 전투 설계 패턴이다. 플레이어에게 진행감과 긴장감 상승을 제공하며, 단조로운 단일-패턴 보스를 피하기 위한 기초 도구다.

## 런앤건 게임에서의 전통

Metal Slug 시리즈에서 보스 멀티페이즈는 장르 관례로 자리잡았다. 보스 격파 시 폭발과 함께 더 빠른 공격 패턴으로 전환하거나, 신체 일부를 분리하여 2페이즈로 돌입하는 방식이 대표적이다. 이는 [[IP Avoidance For Game Clones]] 관점에서 **메카닉(아이디어) 영역**에 해당하므로 자유롭게 모방 가능하다.

## 실제 구현 사례 분석

### alfredo1995/metal-slug — BossControl.cs

HP 50% 임계값 기반 가장 단순한 형태:

```csharp
void Update() {
    if (vida >= 50) {
        TirosControll(5, 9);   // Phase 1: 5초 딜레이, 최대 9방향
    } else if (vida < 50) {
        TirosControll(0, 9);   // Phase 2: 딜레이 0, 즉각 9방향 — 훨씬 공격적
    }
    Movimento();  // 이동은 양 페이즈 동일
}
```

**장점**: 구현 단순, 즉각 이해 가능
**단점**: 전환 연출 없음, 이동 패턴 변화 없음, 페이즈 2 시각적 구분 약함

(Source: [[GitHub alfredo1995 metal-slug]])

### giacoballoccu/MetalSlugClone — Boss2Controller.cs

2페이즈 없음. 단순 타이머 루프:

```csharp
// HP 임계값 분기 없음 — 단일 공격 패턴
if (health.IsAlive()) {
    if (shotTime > nextFire) {
        StartCoroutine(Fire());  // 항상 동일한 Fire() 호출
    }
}
```

(Source: [[GitHub giacoballoccu MetalSlugClone]])

## Godot 4 구현 패턴

### 패턴 A: HP 임계값 State Machine (권장)

```gdscript
class_name BossBase extends CharacterBody2D

enum Phase { PHASE_1, PHASE_2 }

var current_phase: Phase = Phase.PHASE_1
var max_health: float = 1000.0
var health: float = max_health

func take_damage(amount: float) -> void:
    health -= amount
    _check_phase_transition()

func _check_phase_transition() -> void:
    if current_phase == Phase.PHASE_1 and health / max_health <= 0.5:
        _enter_phase_2()

func _enter_phase_2() -> void:
    current_phase = Phase.PHASE_2
    # 연출: 플래시, 사운드, 일시 무적
    _play_phase_transition_effect()
    # 행동 패턴 변경
    attack_speed_multiplier = 2.0
    _unlock_new_attack_patterns()
```

### 패턴 B: 이벤트 기반 페이즈 전환

```gdscript
signal phase_changed(new_phase: int)

func _enter_phase_2() -> void:
    phase_changed.emit(2)
    # 다른 노드들이 시그널 수신 → 음악 변경, 환경 변화 등
```

## 페이즈 전환 설계 체크리스트

| 항목 | Phase 1 → 2 |
|---|---|
| **전환 트리거** | HP 50% (또는 시간, 이벤트) |
| **전환 연출** | 폭발/플래시 + 사운드 변화 |
| **일시 무적** | 전환 중 0.5~1초 무적 (연출 보호) |
| **음악 변화** | 페이즈 2 BGM으로 전환 |
| **시각적 구분** | 외형 변화 (색상, 파티클, 크기) |
| **공격 패턴** | 신규 패턴 추가 또는 기존 패턴 강화 |
| **이동 패턴** | 속도 증가 또는 방향 전환 |
| **아레나 변화** | (선택) 장애물 추가, 배경 변화 |

## IP 안전성

보스 2페이즈 메카닉 자체는 **메카닉(아이디어) 영역**으로 저작권 보호 대상이 아니다. Metal Slug 특유의 보스 *외형·이름*만 교체하면 된다. (Source: [[IP Avoidance For Game Clones]])
