---
title: Run and Gun Level Design Patterns
tags: [concept, run-and-gun, level-design, horizontal-scroll, spawn-system, pacing]
aliases: [런앤건 레벨 디자인 패턴]
cssclasses: []
created: 2026-05-12
updated: 2026-05-12
---

# Run and Gun Level Design Patterns

수평 스크롤 런앤건 게임의 레벨/스테이지 설계 패턴. 스폰 시스템, 페이싱 원칙, 체크포인트 설계. Echo(Godot 4.6) 직접 적용.

---

## 스크롤 위치 기반 스폰 레코드

**신뢰도: HIGH** — ResearchGate 논문 + GameDev.net 포럼 확인

### 데이터 구조

```gdscript
# SpawnEntry.gd
class_name SpawnEntry
extends Resource

@export var scroll_position: float    # 이 X 좌표에서 스폰 트리거
@export var spawn_offset: Vector2     # 화면 상대 또는 월드 좌표 오프셋
@export var enemy_type: EnemyType
@export var ai_pattern: AIPattern
```

```gdscript
enum EnemyType { GRUNT, PATROL_GUARD, SNIPER, TURRET, FLYING, JUMPING }
enum AIPattern { STRAIGHT, SINE_WAVE, ADVANCE_RETREAT, DIVE_BOMB, STATIONARY }
```

### 작동 방식

```
1. 적은 월드에 비활성 상태로 존재
2. 카메라 X 위치가 SpawnEntry.scroll_position 도달
3. 해당 엔트리의 적 활성화
4. 이전 구간 적은 비활성화 유지 (재진입 없음)
```

**Echo 결정론 이점**: 스폰 레코드가 완전 결정론 — 동일 입력 = 동일 스폰 시퀀스. 시간 되감기와 완전 호환.

---

## AI 이동 패턴 (결정론)

| 패턴 | 설명 | 수식 |
|---|---|---|
| STRAIGHT | 직선 전진 | `x -= speed * delta` |
| SINE_WAVE | 수평 이동 + 수직 사인파 | `y = sin(t * freq) * amp` |
| ADVANCE_RETREAT | 접근 후 후퇴 반복 | 거리 임계값으로 전환 |
| DIVE_BOMB | 대각선 급강하 | 목표 방향으로 가속 |
| STATIONARY | 위치 고정 | 터렛/저격수 |

**모두 난수 없이 결정론 구현 가능** — Echo 요구사항 직접 충족.

---

## 페이싱 3원칙

**신뢰도: HIGH** — gamedeveloper.com + GameDev.net 교차 확인

### 원칙 1: 강도 곡선 (Intensity Curve)

```
스테이지 구조:
┌──────────────────────────────────────────────────┐
│ 낮음 → 에스컬레이션 → [회복] → 높음 → 피날레    │
└──────────────────────────────────────────────────┘
```

회복 구간 = 의도적 설계. "페이싱의 근본 도구."
피크와 피크 사이의 골짜기가 없으면 플레이어는 소진(fatigue).

### 원칙 2: 안전지대 통제

- **허용**: 스킬로 도달하는 안전 포지션 (회피 → 엄폐물 뒤)
- **차단**: 패시브 안전지대 (노력 없이 도달, 거기서 기다리면 승리)
  - 차단 방법: 측면 포위 적, 플라이어 투하, 환경 장해물

### 원칙 3: 새 적 첫 등장 = 저위험 문맥

```
올바른 순서:
① 단독 등장, 넓은 화면, 조합 없음 → 플레이어가 패턴 학습
② 두 번째 등장: 다른 적 1명과 조합
③ 세 번째 이후: 완전 조합으로 배치
```

---

## 적 조합 설계 원칙

**신뢰도: HIGH** — gamedeveloper.com "Combining Enemy Types" 기사

다른 기능의 적을 조합할 때 생기는 시너지:

| 조합 | 시너지 효과 |
|---|---|
| 그런트 + 저격수 | 근접 강제 불가 (그런트가 막음) + 원거리 위험 |
| 그런트 + 포대 | 포대 파괴 전에 근접 제거 필요 |
| 순찰 경비 + 비행 | 지상 경로 차단 + 수직 위협 |
| 그런트 + 도약체 | 패턴이 다른 두 근접 위협 동시 |

**규칙**: 각 적 타입에 명확한 역할(약점 및 강점)을 부여하면 플레이어가 직관적으로 우선순위를 결정할 수 있다.

---

## 체크포인트 설계

**신뢰도: MEDIUM** — 장르 표준; 구체적 구현 세부사항 소수

### 위치 선정
- 중간 보스 격파 후
- 새로운 지형 구간 진입 전
- 대략 균등한 스크롤 거리 간격

### 사망 처리
```
사망 → 마지막 체크포인트에서 리스폰
     → 짧은 무적 시간 부여
     → 현재 구간 적 리스폰 (이전 구간은 유지)
     → 무기 보유 상태 유지 (콘트라 스타일 — 무기 유지가 장르 기대치)
```

### Lives 시스템 (Contra 스타일)
- 목숨 소진 → Game Over → 해당 스테이지 처음부터
- 체크포인트는 목숨 내에서만 유효
- Echo 적용: 시간 되감기 토큰 = 실질적 목숨 확장 메카닉

---

## 수평 스크롤 카메라 패턴

**신뢰도: MEDIUM** — 일반 2D 플랫포머 지식 기반

| 방식 | 설명 | 적합 상황 |
|---|---|---|
| 스무드 팔로우 | 플레이어 뒤를 부드럽게 추적 | 탐험형 스테이지 |
| 존 트리거 | 플레이어가 구역 진입 시 카메라 잠금 이동 | 아레나/보스 방 |
| 잠금 스크롤 | 일정 속도로 강제 스크롤 (뒤처지면 화면 밖) | 긴박감 증폭 |

> [!gap] Echo 카메라 방식 미결정. 런앤건 고전은 zone-trigger 방식(메탈슬러그) 또는 smooth-follow(콘트라) 혼합.

---

## 레벨 데이터 예시 (Godot Resource)

```gdscript
# stage_1.tres
[gd_resource type="StageData"]

spawns = [
    SpawnEntry { scroll_position=200, spawn_offset=Vector2(50,0), 
                 enemy_type=GRUNT, ai_pattern=STRAIGHT },
    SpawnEntry { scroll_position=400, spawn_offset=Vector2(100,-50), 
                 enemy_type=SNIPER, ai_pattern=STATIONARY },
    SpawnEntry { scroll_position=600, spawn_offset=Vector2(80,0), 
                 enemy_type=GRUNT, ai_pattern=STRAIGHT },
    SpawnEntry { scroll_position=600, spawn_offset=Vector2(80,-80), 
                 enemy_type=FLYING, ai_pattern=SINE_WAVE },
    # ... 600 이후: 그런트+비행 조합 = 레벨 에스컬레이션 피크
]
```

---

## Echo 구현 체크리스트

```
[ ] SpawnEntry Resource 클래스 정의
[ ] StageData Resource (SpawnEntry 배열 포함)
[ ] 카메라 X 위치 기반 스폰 트리거 시스템
[ ] 강도 곡선 기반 스테이지 개요 설계
[ ] 체크포인트 노드 + 리스폰 로직
[ ] 카메라 방식 결정 (스무드/존트리거/잠금 중 선택)
[ ] 새 적 타입 첫 등장 = 단독 + 저위험 맥락
```

---

## 관련 페이지

- [[Run and Gun Enemy AI Archetypes]] — 적 타입별 행동
- [[Run and Gun Player Character Architecture]] — 플레이어 이동 시스템
- [[Deterministic Game AI Patterns]] — 결정론 스폰 패턴 정책
- [[Boss Rush Godot Implementation Pattern]] — 보스 아레나 전환
