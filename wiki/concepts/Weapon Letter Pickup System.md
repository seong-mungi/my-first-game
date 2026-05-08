---
type: concept
title: "Weapon Letter Pickup System"
created: 2026-05-08
updated: 2026-05-08
tags:
  - game-design
  - run-and-gun
  - weapons
  - pickup-system
  - arcade
status: stable
related:
  - "[[Run and Gun Genre]]"
  - "[[Run and Gun Base Systems]]"
  - "[[Metal Slug]]"
  - "[[Contra]]"
  - "[[Gunstar Heroes]]"
  - "[[Arcade Difficulty Design]]"
sources:
  - "[[Wikipedia Metal Slug Series]]"
  - "[[Wikipedia Run and Gun]]"
confidence: high
---

# Weapon Letter Pickup System

## 패턴 정의

**무기 레터 픽업 시스템(Weapon Letter Pickup System)**은 런앤건 장르에서 표준화된 무기 획득 메커닉이다.

구조:
- 필드의 아이템 박스/적 처치 시 **알파벳 한 글자가 표시된 무기 크레이트** 드롭.
- 플레이어가 획득하면 **현재 무기를 즉시 교체**.
- 기본 무기(권총/소총)는 항상 보유 — 탄약 소진 시 자동 복귀.
- 특수 무기는 한정된 탄약 보유.

## 역사적 기원

- **Contra (1987)**: 팔콘 심볼 + 알파벳 (M/L/F/S/R/B). 장르 최초 표준.
- **Metal Slug (1996)**: 박스 크레이트 + 알파벳 (H/R/F/L/S/I/E/Z 등). 색상 코딩 추가.
- **Gunstar Heroes (1993)**: 알파벳 대신 4가지 원소 조합 방식 — 시스템의 발전형.

## Metal Slug 무기 레터 코드

| 코드 | 무기명 | 특성 |
|---|---|---|
| **H** | Heavy Machine Gun | 고연사, 광범위 커버. 가장 범용 |
| **R** | Rocket Launcher | 폭발 데미지, 탈것/보스에 유효 |
| **F** | Flame Shot | 단거리, 연속 화염 데미지 |
| **L** | Laser Gun | 관통, 최장 사거리 |
| **S** | Shotgun | 광범위 산탄, 근거리 최강 |
| **I** | Iron Lizard | 지면 활주 미사일 |
| **E** / **C** | Enemy Chaser | 유도 미사일 |
| **Z** | Thunder Shot | 전격, 체인 효과 |

## Contra 무기 레터 코드

| 코드 | 무기명 | 특성 |
|---|---|---|
| **M** | Machine Gun | 고속 연사 |
| **L** | Laser | 관통 |
| **F** | Fireball | 포물선 궤도 |
| **S** | Spread Shot | 5방향 산탄. 사실상 최강 |
| **R** | Rapid Fire | 연사 속도 증가 |
| **B** | Barrier | 임시 무적 |

## 시스템의 설계 원칙

### 즉각적 인식성
알파벳 한 글자 + 색상 코딩 → 아케이드 환경에서 **0.5초 내 식별 가능**.
복잡한 아이콘이나 설명 없이 픽업의 의미를 직관적으로 전달.

### 강제 교체의 긴장감
현재 무기를 버리고 새 무기를 획득 → "지금 내 무기를 버려야 하나?" 순간 결정.
때로는 약한 무기 박스를 의도적으로 회피하는 전술이 요구된다.

### 탄약 소진 위험
특수 무기는 한정 탄약 → 아껴 써야 하는 자원으로 기능.
탄약 소진 후 기본 무기 복귀 = 일시적 약화 → 위기감 조성.

### 기본 무기의 역할
무제한 기본 무기(Contra: 소총, Metal Slug: 권총)는 **안전망**으로 기능.
플레이어가 절대 "아무 무기 없음" 상태에 빠지지 않도록 보장.

## 시스템 변형 사례

| 게임 | 변형 방식 | 특징 |
|---|---|---|
| Contra | 알파벳 팔콘 심볼 | 원조. 획득 시 즉시 교체 |
| Metal Slug | 색상 박스 + 알파벳 | 색상으로 1차 분류, 알파벳으로 2차 식별 |
| Metal Slug 6+ | 3개 동시 보유 | 교체에서 인벤토리로 진화 |
| Gunstar Heroes | 4원소 조합 | 레터 시스템을 넘어선 빌드 조합 |
| Cuphead | 상점 구매 + Charms | 픽업이 아닌 영구 업그레이드로 전환 |
| Blazing Chrome | 4종 무기 세트 | 고정 4종 — 픽업 랜덤성 제거 |

## Implications For my-game

런앤건 무기 시스템을 설계할 때 고려할 선택지:

1. **순수 픽업 교체 방식 (Contra 원형)**: 구현 단순, 필드 배치가 중요. 위험/보상 명확.
2. **인벤토리 보유 방식 (Metal Slug 6+)**: 전술 유연성 향상. 복잡성 증가.
3. **조합 방식 (Gunstar Heroes)**: 빌드 다양성 최대. UX 비용 높음.
4. **상점 구매 방식 (Cuphead)**: 런 간 영구 성장. 로그라이트화 용이.

**최소 기능 세트(MVR)**: 3~5개 무기 타입 + 알파벳/아이콘 코딩 + 탄약 한계 + 기본 무기 폴백.
이 정도면 장르 정체성을 전달하면서 구현 복잡성을 관리 가능.

**무기 조합 원칙**: 각 무기는 "이런 상황에서 최선"이 명확해야 한다.
- H(기관총): 소형 다수 적
- R(로켓): 보스, 탈것, 그룹
- S(샷건): 근거리 위기 돌파
- L(레이저): 긴 통로, 관통 필요

## Open Questions

- 무기 강제 교체 vs 인벤토리 보유 중 어느 쪽이 더 많은 "결정 순간"을 만드는가?
- 현대 플레이어는 "탄약 소진 → 기본 무기 복귀"를 처벌로 인식하는가, 학습 기회로 인식하는가?
