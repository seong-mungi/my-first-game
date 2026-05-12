---
title: Run and Gun Enemy AI Archetypes
tags: [concept, run-and-gun, enemy-ai, FSM, game-design, implementation, godot]
aliases: [런앤건 적 AI 아키타입]
cssclasses: []
created: 2026-05-12
updated: 2026-05-12
---

# Run and Gun Enemy AI Archetypes

런앤건 장르의 6가지 표준 적 AI 아키타입. 메탈슬러그·콘트라·레벨 디자인 북·gamedeveloper.com 교차 분석. Echo(Godot 4.6 GDScript) 직접 적용 기준.

---

## 아키타입 1: 그런트 (Grunt / Ground Soldier)

**신뢰도: HIGH** — 메탈슬러그·콘트라 모든 출처에서 확인

### 행동
- 짧은 수평 범위(2-4 타일) 순찰
- 감지 반경 또는 시선 레이캐스트로 플레이어 감지
- 접근 후 2-3발 연사, 짧은 회복 정지, 다시 추격

### FSM
```
PATROL → ALERT → CHASE → ATTACK → COOLDOWN → CHASE
```

### 파라미터
| 파라미터 | 기본값 |
|---|---|
| 감지 반경 | ~5-8 타일 |
| 공격 사거리 | ~2-3 타일 |
| 포기 거리 | ~12-15 타일 |
| 공격 당 발 수 | 2-3 발 |
| 쿨다운 | 0.8-1.2 s |

### 텔레그래프
메탈슬러그 개발자 인터뷰: "공격 전 wind-up 애니메이션이 플레이어에게 타이밍 창을 가르친다."

---

## 아키타입 2: 저격수 (Sniper / Ranged Stationary)

**신뢰도: HIGH**

### 행동
- 고정 또는 최소 이동
- 조준 텔레그래프(0.5-1.0 s 가시적 windup) 후 고데미지 단발
- 긴 재장전 쿨다운(2-3 s)

### FSM
```
IDLE → AIM (장거리 감지) → FIRE → RELOAD → IDLE
```

### 파라미터
| 파라미터 | 기본값 |
|---|---|
| 감지 형태 | 좁고 긴 콘 (360° 아님) |
| 조준 텔레그래프 | 0.5-1.0 s |
| 데미지 | 높음 (적 중 최고) |
| 재장전 | 2-3 s |

### 디자인 노트
- 공격적인 플레이어가 근접하면 취약 → "거리 닫기 = 카운터" 교육
- 등 뒤에서는 감지하지 않음 (360° 감지 변형만 예외)

---

## 아키타입 3: 순찰 경비 (Patrol Guard / Area Defender)

**신뢰도: HIGH** — 그런트와 다른 점: 추격하지 않음

### 행동
- 두 웨이포인트 사이 무한 왕복
- 플레이어가 공격 구역 진입 시에만 공격
- 구역을 절대 벗어나지 않음

### FSM
```
PATROL (A→B→A) → ATTACK (플레이어 구역 진입) → RETURN_TO_PATROL
```

### Godot 4 구현 노트
- 웨이포인트: `Marker2D` 노드 2개
- 순찰 모드: BackAndForth 사이클
- 공격 구역: `Area2D` 트리거
- 그런트와 구분: 하나의 bool 파라미터 (`can_chase: bool`)로 전환 가능

---

## 아키타입 4: 포대 (Turret / Fixed Emplacement)

**신뢰도: HIGH**

### 행동
- 이동 없음
- 범위 내 플레이어 추적 회전
- 연속 사격 또는 타이머 기반 연사

### FSM
```
IDLE → TRACK (플레이어 범위 진입) → FIRE → OVERHEAT/PAUSE → TRACK
```

### 공격 변형
| 변형 | 설명 |
|---|---|
| 360° 느린 회전 | 예측 가능, 피하기 가능 |
| 직접 조준 연사 | 엄폐물 필요 강제 |

### 디자인 역할
포대는 **적이 아닌 환경 장해물**. 병목 구간 기하학을 정의하고 측면 이동을 강제.
네비게이션 불필요 — 구현 비용이 가장 낮은 아키타입.

---

## 아키타입 5: 비행 적 (Flying / Aerial Enemy)

**신뢰도: MEDIUM** — 개념 확인, 구현 세부사항 미검증

### 행동
- 사인파 또는 호 궤적으로 이동 (지형 무시)
- 플레이어 아래에서 폭탄 투하 또는 대각선 발사

### FSM
```
FLY (사인 경로 이동) → ENTER_ATTACK (플레이어 아래) → DROP/FIRE → EXIT
```

### 디자인 역할
지상 위협과 동시에 수직 방향 위협 강제 → 포지셔닝 복잡도 증가.
약점: 수평 이동 제한 → 리드샷(앞으로 쏘기) 유효.

---

## 아키타입 6: 도약 적 (Jumping / Leaping Enemy)

**신뢰도: MEDIUM**

### 행동
- 대기 후 플레이어 현재 위치를 향해 포물선 도약
- 정점 높이에서 피격 어려움

### FSM
```
IDLE → WIND_UP → JUMP (도약 시점의 플레이어 위치 타겟) → LAND → COOLDOWN
```

### 핵심 설계 규칙
도약은 **도약 시작 시점의** 플레이어 위치를 타겟. 착지 시점이 아님.
플레이어에게 가르쳐야 할 것: wind-up 시 옆으로 이동 (도약 중 이동 아님).

---

## 구현 우선순위 (Echo 기준)

| 순위 | 타입 | 이유 |
|---|---|---|
| 1 | 그런트 | 가장 높은 신뢰도, 프로토타입 용이 |
| 2 | 순찰 경비 | 그런트에서 `can_chase=false`로 파생 |
| 3 | 포대 | 네비게이션 불필요, 구현 최소 |
| 4 | 저격수 | 조준 텔레그래프 연출 추가 필요 |
| 5 | 비행 적 | 물리 오버라이드 필요, 마지막 |

---

## Godot 4 FSM 아키텍처 패턴

```gdscript
# enum 기반 5-상태 (2D 적 기본)
enum State { IDLE, PATROL, CHASE, ATTACK, STAGGER }

# 상태당 3개 메서드
func enter_state(s: State) -> void: ...
func update_state(delta: float) -> void: ...
func check_transitions() -> State: ...
```

**성능 노트**: `NavigationAgent2D` 타겟 갱신은 프레임마다 아닌 0.2 s 간격으로.

---

## 결정론 요구사항 (Echo 특이점)

Echo는 시간 되감기를 위해 결정론 요구. 문제 영역:
- `NavigationAgent2D` 경로 탐색 — 프레임 비의존 결과 보장 필요
- 적 AI 상태도 시간 되감기 시 롤백 대상 (되감기 범위 결정 필요)
- 공격 패턴은 난수 없이 순서형 설계 → [[Deterministic Game AI Patterns]] 참고

> [!gap] NavigationAgent2D + Godot 4.6 결정론 호환성 미검증. 순수 FSM(네비게이션 없는 직선/패턴 이동)이 결정론 관점에서 더 안전할 수 있음.

---

## 관련 페이지

- [[Run and Gun Player Character Architecture]] — 플레이어 FSM (대응 관계)
- [[Deterministic Game AI Patterns]] — Echo 결정론 AI 정책
- [[Boss Rush Godot Implementation Pattern]] — 보스 AI FSM 패턴
- [[Run and Gun Level Design Patterns]] — 적 배치 문맥
