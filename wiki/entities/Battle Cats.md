---
type: entity
title: "The Battle Cats"
created: 2026-05-08
updated: 2026-05-08
tags:
  - game
  - side-scrolling-defense
  - tug-of-war-defense
  - mobile
  - gacha
  - live-service
  - japanese-game
  - reference-game
status: stable
related:
  - "[[PONOS]]"
  - "[[Side Scrolling Tug Of War Defense]]"
  - "[[Auto Deploy Unit System]]"
  - "[[Gacha Unit Acquisition]]"
  - "[[Long Tail Mobile Live Service]]"
  - "[[Lane Defense]]"
  - "[[Resource Economy Tower Defense]]"
  - "[[Meta Progression]]"
  - "[[Plants vs Zombies]]"
  - "[[Cartoon Wars]]"
sources:
  - "[[Wikipedia The Battle Cats]]"
  - "[[Battle Cats 100M Downloads ANN]]"
  - "[[Campaign Asia Battle Cats Recovery]]"
confidence: high
---

# The Battle Cats (냥코대전쟁)

## Identity

- **Original Title:** にゃんこ大戦争 (Nyanko Daisenso)
- **Developer / Publisher:** PONOS Corporation (Kyoto, Japan)
- **Release:** Japan — November 15, 2012 (iOS); Worldwide — September 17, 2014
- **Genre:** Side-scrolling tug-of-war defense / free-to-play tower defense
- **Platforms:** iOS, Android; later Nintendo 3DS (2016), Switch (2018–2021), Windows (2017–2018)
- **Engine:** Proprietary (PONOS internal)

## Commercial Scale

- **Downloads:** 100 million worldwide (reached March 2025) (Source: [[Battle Cats 100M Downloads ANN]])
- **Revenue:** $700 million cumulative worldwide through June 2024 (Source: Sensor Tower via [[Wikipedia The Battle Cats]])
- **Revenue split:** Japan 68%, USA 11%, South Korea 8%
- **Longevity:** 13+ years of continuous live service (2012–2026)
- **Cultural reach:** PONOS became a Williams F1 team partner (2020–2021) via Battle Cats success (Source: [[Wikipedia The Battle Cats]])

## Core Game Structure

### 레인 구조 (Lane Architecture)

Battle Cats는 **단일 수평 레인(single horizontal lane)**을 사용한다 — PvZ의 5~6레인 그리드와 달리, 양쪽 기지가 하나의 평탄한 필드를 공유하며 유닛들이 왼쪽(플레이어)과 오른쪽(적)에서 서로를 향해 진격한다. 전장은 스크롤 가능한 2D 사이드뷰.

이는 [[Lane Defense]]의 "grid lane" 변종이 아니라 [[Side Scrolling Tug Of War Defense]]의 핵심 구조다.

### 배치 메커닉 (Deployment)

See [[Auto Deploy Unit System]] for full pattern analysis.

- 전투 중 자동으로 쌓이는 **인-배틀 통화(¥, "돈")**를 소비해 고양이 유닛을 기지에서 즉시 소환
- 소환된 유닛은 자동으로 오른쪽 방향으로 이동하며 적을 만나면 자동 공격
- 유닛마다 **배치 비용(Deploy Cost)**과 **재충전 시간(Recharge Time)** 보유
- 가장 저렴한 유닛: 꼬맹이 고양이 모히칸 45¥; 가장 비싼 유닛: 7,500¥
- **Wallet (지갑)**: 보유 가능한 최대 금액 — 업그레이드 가능. 지갑이 꽉 차면 고비용 유닛 소환 불가

### 고양이 유닛 시스템

6가지 레어도: Normal → Special → Rare → Super Rare → Uber Super Rare → Legend Rare

**역할 분류:**
- **Meat Shield (고기방패)**: 저비용, 높은 체력, 짧은 쿨타임. 고급 유닛 보호용
- **Attacker / DPS**: 중~고비용, 높은 화력
- **Crowd Controller**: 적 슬로우, 넉백, 스턴 등 디버프 부여
- **Backliner**: 긴 사거리, 아군 뒤에서 안전하게 딜링

**진화 시스템(Forms):** 각 유닛은 최대 4폼(Normal → Evolved → True → Ultra) 보유. 폼 변경은 배틀 전 메뉴에서. True Form은 레벨 30 + Catfruit 재료 필요.

**800+ 유닛** (버전 15 기준)

### 적 특성 / 안티 특성 시스템 (Anti-Trait System)

적 유닛은 특성(Trait)을 보유하며, 고양이 유닛은 특정 특성에 대한 안티 능력을 가질 수 있다:

| 적 특성 | 색상 | 설명 |
|---|---|---|
| Traitless (무특성) | White | 특성 없음. 안티-트레이틀리스 유닛 드묾 |
| Red | Red | 가장 초반에 등장 |
| Floating | Light Green | 공중 적 |
| Black | Dark | 고체력 적 |
| Metal | Gray | 배리어형. 크리티컬 히트만 유효 |
| Angel | Yellow | 중반 이후 등장 |
| Alien | Cyan | Into the Future 챕터의 주력 |
| Zombie | Purple | 부활 메커닉 보유 |
| Relic | Dark Green | 고난이도 레전드 스테이지 |
| Aku | Blue | 가장 최신. 쉴드+Death Surge 보유 |

**안티 시스템의 의의:** 적 특성이 덱 구성 결정을 강제한다. 스테이지별 등장 특성에 맞게 안티 유닛을 편성해야 하므로 메타 다양성이 유지된다.

### 경제 시스템 (Economy)

**인-배틀:**
- **¥(전투 통화)**: 자동 생성 + 적 처치 드롭. Worker Cat 업그레이드로 생성 속도 향상
- **Worker Cat**: 전투 시작 시 레벨 1, XP나 업그레이드로 최대 레벨 확장

**메타:**
- **XP**: 유닛 레벨업 + 기지 업그레이드 비용. 스테이지 클리어, XP 파밍 이벤트로 수급
- **Cat Food (고양이 밥)**: 프리미엄 통화. 가챠(150개 = 레어캡슐 1회), 에너지 충전, 특수 유닛 구매에 사용
- **Cat Energy**: 스테이지 도전 소비 체력. 최대 치는 레벨업으로 증가; 1분당 1 자동 회복. Leaderships로 즉시 충전

→ See [[Resource Economy Tower Defense]] for two-currency pattern comparison

### 기지 업그레이드 시스템 (Base Upgrades)

**Cat Cannon**: 플레이어 기지의 캐논 — 쿨다운 후 발사. 대규모 약체 적 처리 또는 강적 스턴에 최적

**업그레이드 항목 (XP 소비):**
- Cat Cannon Power / Range / Charge
- Worker Cat Rate (전투 중 통화 생성 속도)
- Base Defense (기지 HP)
- Research (유닛 재충전 속도)
- Accountant (지갑 최대치)
- Study (XP 획득량)
- Cat Energy (최대 에너지)

### 유저 랭크 시스템 (User Rank)

유저 랭크 = 보유한 모든 고양이 유닛 레벨의 합산. 랭크 상승으로 유닛 레벨 캡 해제, 특수 아이템, 할인 이벤트 제공.
- 랭크 800: 레어 캣 티켓
- 랭크 900–1410: 레어/슈퍼레어/우버레어 캡 30 해제
- 랭크 2700+: Cat Combo 시스템 해제

### Cat Combo 시스템

특정 유닛 조합을 덱에 편성하면 버프 발동: Base Defense Up, Research Power Up, XP Rewards 등. 덱 구성에 추가 레이어를 부여.

## 챕터 구조 (Chapter Structure)

**메인 사가 4개:**
1. **Empire of Cats** — 3챕터 × 48스테이지 = 144스테이지. 입문
2. **Into the Future** — Alien 특성 중심
3. **Cats of the Cosmos** — 고난이도
4. **The Aku Realms** — Aku 특성 중심, 최신

**레전드 스테이지:** Stories of Legend, Uncanny Legends, Zero Legends 등 추가 콘텐츠

### 트레져 시스템 (Treasure)

스테이지 클리어 시 드롭. 3등급: Bronze(Inferior) / Silver(Normal) / Gold(Superior)

기본 드롭률 35%; Treasure Festival 이벤트 시 70%. 지역별 트레져 컬렉션 완성 시 **영구 패시브 보너스** 부여 (HP/공격력 상승, 특성 약화 등). 챕터 클리어 전 골드 트레져 수집이 강하게 권장됨.

## 가챠 시스템 (Gacha)

→ See [[Gacha Unit Acquisition]] for full pattern

**캡슐 종류:**
- **Normal (Green) Capsule**: 실버 티켓 또는 Cat Food 사용. 기본 유닛만
- **Rare (Gold) Capsule**: 150 Cat Food 1회 / 1,500 Cat Food 11회. Rare~Legend Rare 등장

**티켓 종류:**
- Silver Ticket: 데일리 지급 + 특정 스테이지 드롭(30%)
- Gold/Rare Cat Ticket: PONOS 이벤트 선물 / 실버 5장 교환

**우버 레어 확률:** ~5%
**Guaranteed Uber**: 10연차 시 1개 보장 이벤트(Uber Rare Confirm 캠페인)

## 라이브 서비스 전략

- **정기 이벤트**: XP Festival, Treasure Festival, Catfruit Festival 등 주기적 파밍 이벤트
- **IP 콜라보**: Demon Slayer(귀멸의 칼날), Tower of Saviors 등 정기 크로스오버. 한정 유닛 + 한정 스테이지 제공
- **계절 이벤트**: 연간 캘린더 기반 반복 이벤트
- **복귀 캠페인**: 2023 한국/대만 캠페인으로 1.2M 이탈 플레이어 복귀 → 한국 DAU +137%, 매출 +207% (Source: [[Campaign Asia Battle Cats Recovery]])

→ See [[Long Tail Mobile Live Service]] for longevity pattern analysis

## 디자인 비교: Battle Cats vs Plants vs Zombies

| 항목 | Battle Cats | Plants vs Zombies |
|---|---|---|
| 레인 수 | 1 (단일 수평) | 5–6 (병렬 그리드) |
| 배치 방식 | 실시간 소환, 자동 이동 | 셀 고정 배치 |
| 공간 결정 | 없음 (유닛이 자동 전진) | 어느 셀? 어느 레인? |
| 핵심 결정 | 무엇을 언제 소환? | 무엇을 어디에 배치? |
| 경제 | 인-배틀 자동 생성 ¥ | Sun (generator + ambient) |
| 메타 단위 | 덱 8슬롯 편성 | 10식물 선택 |
| 복잡성 레이어 | 안티 특성, 가챠 컬렉션 | 환경(수영장/지붕/안개) |

→ See [[Plants vs Zombies]] for grid lane defense reference

## 오픈 퀘스천

- Battle Cats의 단일 레인 구조가 전략 깊이를 희생하는가, 아니면 다른 형태의 깊이(타이밍/카운터 픽)를 만드는가?
- 14년 라이브서비스에서 800+ 유닛 인플레이션이 신규 유저 진입장벽을 어떻게 관리하는가?
- IP 콜라보 의존도가 높아질수록 게임 자체 신규 콘텐츠 생산 속도는 어떻게 변하는가?
