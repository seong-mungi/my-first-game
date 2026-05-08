---
type: concept
title: "Contra Weapon System"
created: 2026-05-08
updated: 2026-05-08
tags:
  - game-design
  - run-and-gun
  - weapons
  - contra
  - pickup-system
  - arcade
related:
  - "[[Contra]]"
  - "[[Weapon Letter Pickup System]]"
  - "[[Metal Slug]]"
  - "[[Run and Gun Base Systems]]"
  - "[[Run and Gun Extension Systems]]"
confidence: high
source_url: https://en.wikipedia.org/wiki/Contra_(video_game)
fetched: 2026-05-08
key_claims:
  - "Contra NES 무기 코드: M/L/F/S/R/B — 팔콘 심볼에 각인된 알파벳"
  - "S(Spread Shot)가 사실상 최강 무기로 알려짐"
  - "피격 시 무기 소실, 기본 무기로 복귀"
---

# Contra 무기 시스템

런앤건 장르의 [[Weapon Letter Pickup System]] 원형을 정의한 시스템.
[[Metal Slug]]의 H/R/F/L/S/I 코드 체계와 비교해 이해할 것.

## 픽업 형태

**팔콘 심볼(Falcon Symbol):** 날개 달린 매 모양의 아이콘 위에 알파벳이 표기된 아이템.
- 적 처치 또는 지정 위치 아이템 박스에서 등장
- 획득 즉시 현재 무기를 교체 (기본 무기 → 특수 무기, 또는 특수 무기 ↔ 특수 무기)
- 탄약 개념 없음 — 모든 특수 무기는 무제한 사용 가능
- 피격 사망 시 무기 소실, 기본 총기(Machine Gun)로 복귀

> [!gap] 아케이드 원판과 NES 버전의 무기 밸런스 차이 상세 데이터 부재.
> "R(Rapid Fire)과 B(Barrier)가 NES에서 더 자주 등장" 수준의 언급만 확인됨.

## 무기 코드표 (NES 버전 기준)

| 코드 | 무기명 | 투사체 패턴 | 전술적 용도 |
|---|---|---|---|
| **M** | Machine Gun | 고속 단발 연사, 전방 직선 | 범용 — 기본보다 빠름. 좁은 통로 유효 |
| **F** | Fireball | 포물선 탄도 (위아래 교차 코르크스크류) | 우회 탄도 필요 시. 조준 어려움 |
| **L** | Laser | 직선 관통 고데미지 단발 | 직선 보스 공략. 높은 클리어 속도 |
| **S** | Spread Shot | 5방향 扇형 산탄 동시 발사 | **사실상 최강** — 다수 방향 동시 커버 |
| **R** | Rapid Fire | 연사 속도 증가 버프 (무기 교체 아님) | 현재 무기 DPS 향상 |
| **B** | Barrier | 일시적 무적 방어막 | 위기 탈출용 방어 아이템 |

### Metal Slug 무기 코드와의 비교

| 항목 | Contra (1987) | Metal Slug (1996) |
|---|---|---|
| 총 코드 수 | 6종 (M/F/L/S/R/B) | 8~9종 (H/R/F/L/S/I/E/Z 등) |
| 탄약 | **무제한** — 소실은 피격 시만 | 한정 탄약 — 소진 시 권총 복귀 |
| 픽업 강제 교체 | 즉시 교체 | 즉시 교체 (MS6부터 인벤토리 방식) |
| 비무기 픽업 | B(Barrier), R(Rapid) 포함 | 수류탄 별도 슬롯 |
| 픽업 컨테이너 | 팔콘 심볼 | 아이템 박스 크레이트 |
| 기본 무기 | 소총(무제한) | 권총(무제한) |
| 탈것 통합 | 없음 | 슬러그(탈것) 탑승 시 별도 무장 |

## 시스템의 핵심 설계 원칙

### 1. 무기가 아닌 "상태"로서의 무기
Contra의 무기는 플레이어에게 **현재 파워 레벨의 시각적 표시**로 기능한다.
특수 무기 보유 = 강화 상태. 피격 = 상태 강등(downgrade). 이 구조가 생존에 대한 긴장감을 증폭시킨다.

Metal Slug의 탄약 소진 방식과 달리, Contra는 **"언제 죽느냐"가 무기 소실의 유일한 조건** — 탄약 관리 부담 없이 피격 회피에만 집중하게 만든다.

### 2. S(Spread Shot)의 지배적 설계
S샷은 5방향 동시 커버로 사실상 대부분의 상황에서 최선의 선택이다. 이는 설계 결함이 아닌 **의도된 보상 구조**:
- 강력한 무기를 찾는 탐색 동기 부여
- S샷을 가진 채 사망했을 때의 심리적 손실감 증폭
- 플레이어가 S샷 픽업 위치를 암기하도록 유도

→ [[Run and Gun Base Systems]]의 "위험/보상 구조"를 무기 레이어에서 구현한 사례.

### 3. 비무기 픽업 혼재
R(Rapid Fire)은 무기가 아닌 버프, B(Barrier)는 방어 아이템이다. 이를 동일한 픽업 풀에 포함시켜 **"알파벳만 보고 즉시 판단해야 하는" 인지 부담**을 만든다. 빠른 아케이드 환경에서의 숙련도 요소.

## Implications For my-game

1. **탄약 없는 무기 소실 방식**: Contra 방식(피격 시 소실)은 Metal Slug 방식(탄약 소진)보다 조작 집중도를 높인다. 탄약 관리 UI가 없어도 되는 단순한 구현.
2. **지배적 무기 1종 허용**: S샷처럼 "거의 최강" 무기가 있어도 된다. 오히려 그 무기를 얻고 잃는 사이클이 게임 긴장감의 핵심.
3. **비무기 픽업 혼재**: 방어/버프 아이템을 같은 픽업 시스템에 포함하면 같은 디자인 예산으로 다양성 확보 가능.
4. **기본 무기는 언제나 안전망**: 어떤 상황에서도 플레이어가 완전한 무력 상태가 되면 안 된다. Contra와 Metal Slug 모두 이 원칙 준수.

## See Also

- [[Weapon Letter Pickup System]] — 장르 전체의 픽업 패턴 비교
- [[Contra]] — 원게임 전체 시스템
- [[Metal Slug]] — Metal Slug 무기 코드 H/R/F/L/S/I와 비교
- [[Run and Gun Base Systems]] — 무기 시스템이 위치하는 장르 구조
