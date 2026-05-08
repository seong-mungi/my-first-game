---
type: concept
title: "Gacha Unit Acquisition"
created: 2026-05-08
updated: 2026-05-08
tags:
  - game-design
  - monetization
  - gacha
  - mobile
  - unit-acquisition
  - live-service
status: developing
related:
  - "[[Battle Cats]]"
  - "[[Meta Progression]]"
  - "[[Long Tail Mobile Live Service]]"
  - "[[Resource Economy Tower Defense]]"
  - "[[Random Dice]]"
sources:
  - "[[Wikipedia The Battle Cats]]"
  - "[[GachaZone Battle Cats Guide]]"
confidence: high
---

# Gacha Unit Acquisition

## 정의

**가챠 유닛 획득(Gacha Unit Acquisition)**은 모바일 게임에서 유닛/카드/캐릭터를 무작위 확률 뽑기(가챠 캡슐)를 통해 획득하는 메커닉이다. 단순 스테이지 클리어 보상이나 구매가 아닌, **확률적 결과**가 핵심이다.

Battle Cats는 이 모델의 대표 사례 중 하나로, 가챠가 수익화의 핵심 엔진이자 컬렉션 동기의 핵심 드라이버다.

## Battle Cats 가챠 구조

### 캡슐 종류

| 캡슐 | 비용 | 드롭 등급 |
|---|---|---|
| Normal (Green) Capsule | Silver Ticket or Cat Food | Normal, Special |
| Rare (Gold) Capsule | 150 Cat Food (1회) / 1,500 Cat Food (11회) | Rare, Super Rare, Uber Rare, Legend Rare |

### 레어도 확률 (근사치)

- **Rare:** ~70%
- **Super Rare:** ~25%
- **Uber Super Rare:** ~5%
- **Legend Rare:** 0.3% 미만 (특정 풀에서만 등장)

Uber Rare는 5% 확률이나, **Uber Rare Confirm 캠페인** 기간에는 10연차 시 1개 보장(Guaranteed Uber).

### 티켓 경제

- **Silver Ticket**: 데일리 지급 + 특정 스테이지 30% 드롭 + 시즈 이벤트 100% 드롭. Normal Capsule 전용
- **Gold (Rare Cat) Ticket**: PONOS 공식 이벤트 선물 / Silver Ticket 5장 교환. Rare Capsule 1회 사용 가능
- **Cat Food**: 프리미엄 통화. 150개 = Rare Capsule 1회 / 1,500개 = 11회 (보너스 1장 포함)

이 구조는 **무료 플레이어도 데일리 실버 티켓으로 꾸준히 Normal Capsule을 돌릴 수 있게** 하여 DAU를 유지하면서, **Uber Rare 목표**를 Cat Food 지출의 동기로 활용한다.

## 가챠가 만드는 메타게임

### 컬렉션 동기

800+ 유닛을 컬렉션하는 것 자체가 메타 목표가 된다. 유닛이 단순 수단(도구)이 아니라 **목적(컬렉션 아이템)**으로 기능한다. Battle Cats의 고양이 특유의 개성(이름, 디자인, 일러스트)이 이 컬렉션 욕구를 강화한다.

### 이벤트 가챠 풀 순환

Battle Cats는 **5일 단위로 Rare Capsule 풀(pool)이 순환**된다. 각 풀에는 특정 테마의 Uber 유닛들이 포함된다. 원하는 Uber가 있는 풀이 올 때까지 Cat Food를 비축했다가 집중 소비하는 전략이 커뮤니티에서 공유된다.

이 구조는 **이벤트 캘린더 기반 지출 리듬**을 만들어 플레이어의 세션을 이벤트 주기에 동기화시킨다.

### IP 콜라보 한정 가챠

귀멸의 칼날, Tower of Saviors 등 IP 콜라보 이벤트 기간에는 **한정 콜라보 유닛**이 Rare Capsule에 추가된다. 한정성이 FOMO(Fear of Missing Out)를 자극하며 단기 매출 스파이크를 만든다.

## 가챠의 설계 리스크

→ See [[Meta Progression]] for card-level vs unlock-led comparison

| 리스크 | 설명 | Battle Cats의 대응 |
|---|---|---|
| P2W 논란 | 고과금자가 무과금자를 압도 | PvE 중심 + Uber 없이도 클리어 가능한 스테이지 설계 |
| 신규 유저 진입장벽 | 800+ 유닛이 지나치게 복잡해 보임 | Normal Cat 기본 유닛 세트로 초반 상당 구간 클리어 가능 |
| 규제 리스크 | 일부 국가 확률형 아이템 규제 | 확률 공개, 보장 캠페인으로 대응 |
| 인플레이션 | 신유닛이 구유닛을 obsolete화 | 유닛별 역할 전문화로 완전 대체 방지 (일부 성공, 일부 실패) |

## 다른 장르에서의 가챠 비교

| 게임 | 가챠 방식 | 의의 |
|---|---|---|
| Battle Cats | Uber 5% / 풀 순환 / 보장 캠페인 | 코어 PvE 수익화 |
| Random Dice | 카드 뽑기 + 카드 레벨 업그레이드 | PvP 밸런스와 충돌하는 가챠 |
| Clash Royale | 카드 중복으로 업그레이드 | 경쟁적 P2W의 대표 사례 |

→ See [[Random Dice]] for the card-level gacha comparison

## Implications For This Project

1. **가챠 도입 결정은 전체 설계를 바꾼다.** 가챠가 있으면 유닛 밸런스를 PvP용이 아닌 컬렉션/PvE용으로 설계해야 함.
2. **무료 경로 설계 필수.** Silver Ticket 유사 데일리 무료 뽑기가 없으면 무과금 플레이어의 DAU가 급락한다.
3. **풀 순환 캘린더**는 이벤트 캘린더와 통합되어 지출 타이밍을 관리한다. 컬렉션 목표가 명확할수록 지출 의사결정이 쉬워진다.
4. **인디 v1에서 가챠 도입은 규제 및 기술 복잡도가 높다.** 대안: 직접 유닛 구매(unlock shop) + 소량 확률 요소로 시작.

## Open Questions

- 가챠 없이 Battle Cats 수준의 컬렉션 동기를 만들 수 있는 대안 메커닉이 존재하는가?
- 확률 규제가 강화되는 시장(유럽, 한국)에서 가챠 수익모델의 미래는?
- 가챠 풀 순환 5일 주기는 Battle Cats 데이터에서 최적화된 수치인가, 관행인가?
