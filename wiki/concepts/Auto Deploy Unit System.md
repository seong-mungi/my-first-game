---
type: concept
title: "Auto Deploy Unit System"
created: 2026-05-08
updated: 2026-05-08
tags:
  - game-design
  - mechanics
  - side-scrolling-defense
  - tug-of-war-defense
  - unit-system
status: developing
related:
  - "[[Side Scrolling Tug Of War Defense]]"
  - "[[Battle Cats]]"
  - "[[Resource Economy Tower Defense]]"
  - "[[Lane Defense]]"
  - "[[Wave Pacing]]"
sources:
  - "[[Wikipedia The Battle Cats]]"
  - "[[BlueStacks Battle Cats Guide]]"
confidence: high
---

# Auto Deploy Unit System

## 정의

**자동 전진 소환 시스템(Auto Deploy Unit System)**은 플레이어가 통화를 소비해 유닛을 소환하면, 유닛이 자동으로 적 기지 방향으로 이동하며 적을 만나면 자동으로 공격하는 메커닉이다.

[[Lane Defense]]의 **셀 고정 배치 방식**과 구별된다:
- 셀 고정(PvZ): 플레이어가 위치를 결정. 유닛은 그 자리를 지킨다.
- 자동 전진(Battle Cats): 플레이어는 "무엇을, 언제"만 결정. 유닛은 스스로 전진한다.

## 핵심 파라미터

모든 자동 전진 유닛은 다음 수치를 가진다:

| 파라미터 | 설명 | Battle Cats 예시 |
|---|---|---|
| **Deploy Cost** | 소환 비용 (인-배틀 통화) | 최소 45¥ ~ 최대 7,500¥ |
| **Recharge Time** | 동일 유닛 재소환까지 쿨다운 | 유닛별 상이 |
| **Movement Speed** | 전선 이동 속도 | 수치가 클수록 빠름 |
| **Attack Range** | 공격 사거리 (근거리 / 원거리) | 근접 vs 범위 공격 |
| **HP / Attack Power** | 내구도 / 화력 | 레어도에 따라 스케일 |

## 역할 분류 체계

자동 전진 시스템에서 유닛은 전선(frontline)에서의 역할로 분류된다:

### Meat Shield (고기방패)
- **저비용 + 높은 체력 + 짧은 쿨타임**이 필수
- 고급 딜러 유닛이 적에게 직접 닿지 않도록 전방에서 버텨준다
- Battle Cats 예: Normal Cat, Tank Cat (가장 기본적인 미트실드)
- 이 역할의 유닛을 지속 소환하는 것이 전투의 기본 템플릿

### Attacker / DPS
- 중~고비용, 높은 화력, 긴 사거리
- 미트실드 뒤에서 딜링. 전선에 직접 노출되면 빠르게 처리됨

### Crowd Controller
- 적 슬로우(slow), 넉백(knockback), 스턴(freeze/stop) 등 디버프
- 전선 압박이 심할 때 CC로 시간 구매
- 특히 보스 처치에서 CC 타이밍이 승부를 결정

### Specialist (Anti-Trait)
- 특정 적 특성에 강력한 보너스 데미지 / 특수 효과
- → See [[Battle Cats]] for anti-trait system detail

## 소환 타이밍 결정의 구조

자동 전진 시스템에서 플레이어의 핵심 결정은 **무엇을 언제 소환하느냐**다. 이것이 그리드 배치 게임의 "어디에"를 대체한다.

**결정 포인트:**
1. **자금 관리**: 저비용 미트실드 먼저 vs 고비용 딜러 기다리기
2. **전선 위기 대응**: 전선이 기지에 근접할 때 CC 또는 다량 소환
3. **보스 처치 전략**: 보스 등장 전 자금 비축 vs 지속 소환으로 전선 유지
4. **쿨타임 겹침 방지**: 동일 유닛 여러 장의 쿨다운이 겹치면 자금 낭비

## 경제와의 연동

→ See [[Resource Economy Tower Defense]] for two-currency theory

자동 전진 시스템의 인-배틀 경제:
- **자동 생성 통화 (Worker Cat)**: 배틀 중 자동 생성. 업그레이드로 생성 속도 향상. 초반에 Worker Cat 업그레이드에 먼저 투자하는 것이 기본 전략
- **킬 드롭 통화**: 적 처치 시 추가 금액 드롭 (Battle Cats: 주로 자동 생성 중심)
- **지갑(Wallet) 상한**: 보유 가능 통화 최대치. 상한 도달 시 통화 낭비. Accountant 업그레이드 필요

**통화 흐름 패턴:**
```
초반: Worker Cat 업 → 미트실드 지속 소환 → 전선 형성
중반: 자금 축적 → 딜러/CC 투입 → 전선 전진
후반: 보스 등장 → CC + 집중 딜 → 기지 격파
```

## 그리드 배치와 비교한 장단점

| 항목 | 자동 전진 소환 | 그리드 셀 고정 배치 |
|---|---|---|
| 입력 복잡도 | 낮음 (탭) | 높음 (드래그+위치 선택) |
| 공간 전략 | 없음 | 핵심 |
| 시간 전략 | 핵심 (타이밍) | 부차적 |
| 모바일 적합도 | 매우 높음 | 중간 (정밀도 요구) |
| 반복 플레이 피로 | 높음 (공간 변화 없음) | 낮음 (레인별 배치 변화) |
| 컨텐츠 확장 경로 | 유닛 추가 | 레인 환경 변화 |

> [!gap] 자동 전진 시스템에서 "위치 결정"을 복원하는 변종이 있는가? Battle Cats는 순수 자동 전진이지만, 일부 게임은 "소환 지점"을 선택하게 한다. 이 변종의 상업적 성공 사례는 확인되지 않음.

## Implications For This Project

1. **자동 전진 채택 시**: 소환 타이밍 UI가 핵심. 쿨다운 상태, 현재 잔액, 전선 위치를 동시에 파악할 수 있는 HUD 필수.
2. **미트실드 역할은 필수**: 저비용 소모 유닛이 없으면 고비용 유닛을 소환할 타이밍이 만들어지지 않는다. 비용 티어 설계를 먼저 해야 함.
3. **Worker Cat 유사 시스템**: 인-배틀 경제 생성 속도를 플레이어가 제어할 수 있어야 전략적 선택이 생긴다.
4. **반복성 대응**: 공간 변화 없이 반복성을 관리하려면 적 특성 변화(스테이지별 특성 조합)가 핵심 콘텐츠 드라이버가 되어야 한다.

## Open Questions

- 자동 전진 + 2레인(공중/지상 분리)을 합치면 공간 결정이 복원되는가?
- 유닛 소환 "예약 큐" 시스템(탭하면 대기열에 추가)이 전략 깊이를 높이는가, 아니면 복잡성만 추가하는가?
