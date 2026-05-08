---
type: synthesis
title: "Research: 라인 디펜스 게임 시스템"
created: 2026-05-08
updated: 2026-05-08
tags:
  - research
  - lane-defense
  - tower-defense
  - game-design
  - genre-study
status: developing
related:
  - "[[Lane Defense]]"
  - "[[Wave Pacing]]"
  - "[[Resource Economy Tower Defense]]"
  - "[[Grid Placement System]]"
  - "[[Upgrade Path System]]"
  - "[[Meta Progression]]"
  - "[[Merge Dice Mechanic]]"
  - "[[Plants vs Zombies]]"
  - "[[Random Dice]]"
  - "[[Bloons TD]]"
  - "[[George Fan]]"
sources:
  - "[[Wikipedia Plants vs Zombies]]"
  - "[[Game Developer Tower Defense Rules]]"
  - "[[Tower Defense Design Guide]]"
---

# Research: 라인 디펜스 게임 시스템

## Overview

라인디펜스(Lane Defense)는 타워디펜스의 하위 장르로, 적이 미로/경로가 아닌 **고정된 평행 레인**을 따라 진격하며, 같은 레인의 유닛만 해당 적에게 영향을 줄 수 있는 구조다. 장르의 결정적 시작점은 2009년 PopCap Games의 *Plants vs. Zombies* (디자이너: George Fan)로, 이후 모바일 시장을 중심으로 *Random Dice* (111%, 한국, 2019), *Bloons TD Battles*, *Cookie Run* 시리즈, *Astro Battlers TD* 등으로 분기 진화했다.

이 리서치는 라인디펜스의 **시스템 구성요소**(레인/그리드/경제/웨이브/업그레이드/메타)를 6개 핵심 컨셉으로 분해하고, 3개의 대표 게임에서 각 시스템이 어떻게 구현되는지 비교한다. 결론은 본 프로젝트(my-game) 적용 가이드라인으로 통합한다.

## Key Findings

### 1. 라인디펜스는 타워디펜스의 "공간 단순화" 변종이다

전통 TD가 미로 설계와 경로 통제로 전략을 만든다면, 라인디펜스는 공간을 **5–6개의 평행 레인**으로 단순화하고 그 대신 **레인별 유닛 운용**으로 전략을 만든다 (Source: [[Game Developer Tower Defense Rules]]). 모바일 화면과 짧은 세션에 최적화된 형태이며, 캐주얼 가독성이 핵심 설계 동기다. → [[Lane Defense]]

### 2. George Fan의 "왜 적이 타워를 못 때리지?"가 장르의 출발점이다

George Fan은 기존 TD의 "적이 타워를 공격하지 않는다"는 비직관성을 문제로 정의하고, 5–6레인 그리드 + 적이 식물을 직접 먹는 구조로 해결했다 (Source: [[Wikipedia Plants vs Zombies]]). 장르 시작점이 *디자인 비판*이었다는 점이 중요하다 — 새 라인디펜스를 설계할 때도 같은 질문을 던져야 한다: "기존 작품에서 어떤 부분이 부자연스러운가?"

### 3. 그리드는 더 적은 깊이가 아니라 더 *깨끗한* 깊이를 만든다

PvZ의 9×5 그리드는 셀 기반 단일 점유 규칙으로 "어떤 셀에 무엇을 둘 것인가"라는 이산적 결정을 만든다 (Source: [[Game Developer Tower Defense Rules]]). 자유 배치보다 매치별 깊이는 낮지만, 매치 간 일관성과 밸런스 시그널이 훨씬 깨끗해 모바일/라이브서비스에 절대적으로 유리하다. → [[Grid Placement System]]

### 4. 두 가지 통화 구조가 표준이다

거의 모든 성공 사례는 **인-라운드 통화**(매치 내 배치/업그레이드용, 매치 종료 시 리셋)와 **메타 통화**(매치 외 영구 진행) 두 개를 운영한다 (Source: [[Game Developer Tower Defense Rules]]). 한 통화로 묶으면 매치 긴장이 사라지고, 분리해야 즉시적 결정과 장기적 동기가 모두 작동한다. → [[Resource Economy Tower Defense]]

### 5. 웨이브 페이싱은 타이밍 문제이지 콘텐츠 문제가 아니다

기억에 남는 웨이브와 잊혀지는 웨이브의 차이는 적의 *수*나 *종류*가 아니라 **타이밍 패턴**이다. 일제 등장(All-at-once), 스태거(Staggered), 웨이브 버스트(Wave burst) 세 패턴을 혼합해야 한다 (Source: [[Tower Defense Design Guide]]). HP/Gold 비율(powHPG)이 난이도 곡선의 1차 레버다. → [[Wave Pacing]]

### 6. 업그레이드는 *경로*로 분기시켜야 정체성이 생긴다

선형 업그레이드(숫자만 커짐)는 결정의 무게가 없다. Bloons TD 6의 **3경로 × 5티어 + 크로스패스 제한** 구조가 업계 표준이며, 핵심은 "한 경로만 5티어 도달, 다른 경로는 2티어까지" 제약이 *결정을 강제한다*는 점이다. 라인디펜스는 매치 길이가 짧으면 *유닛 다양성*으로, 길면 *경로 업그레이드*로 다양성을 만든다. → [[Upgrade Path System]]

### 7. 머지(Merge) 메커닉은 라인디펜스의 강력한 변종이다

Random Dice는 배치 결정 자체를 **머지 트리**로 대체한다 (Source: [[Random Dice App Store]]). 5종 덱에서 같은 핍 같은 타입을 합치면 핍+1, PvP 양쪽이 같은 웨이브를 공유하고 먼저 무너지는 쪽이 패배한다. 짧은 모바일 PvP(약 5분 매치)에 최적화된 형태이며, 한국 인디 팀이 라인디펜스를 만든다면 반드시 검토해야 할 레퍼런스다. → [[Merge Dice Mechanic]]

### 8. 메타 진행은 가장 큰 잔존(retention) 동력이자 가장 큰 함정이다

언락 기반(unlock-led) 메타는 안전하다. 카드 레벨 기반(card-level) 메타는 잔존이 강하지만 P2W로 변질되기 쉽다 — Random Dice가 그 사례다. 인디 v1에서는 카드 레벨 시스템 도입을 미루는 것이 권장된다. → [[Meta Progression]]

## Key Entities

- [[Plants vs Zombies]] — 라인디펜스 장르의 정전(canonical) 레퍼런스. 모든 후속작이 여기서 분기.
- [[Random Dice]] — 모바일 PvP 라인디펜스의 가장 성공한 한국 사례. 머지 메커닉 도입.
- [[Bloons TD]] — 경로 기반 TD이지만 업그레이드 경로 시스템(3×5 + 크로스패스)의 표준.
- [[George Fan]] — PvZ 디자이너. 장르 창시자급.

## Key Concepts

- [[Lane Defense]] — 장르의 구조적 정의와 하위 변종(grid lane, free-position lane, symmetric PvP lane).
- [[Grid Placement System]] — 9×5 그리드의 인지적 속성, 자유 배치 대비 장단점.
- [[Resource Economy Tower Defense]] — 두 가지 통화, 4가지 통화 생성 패러다임, sun/sunflower 패턴.
- [[Wave Pacing]] — 3가지 스폰 타이밍, powHPG 난이도 레버, DDA 구조.
- [[Upgrade Path System]] — Bloons 3×5 표준, 크로스패스 제약, Paragon 디자인 패턴.
- [[Merge Dice Mechanic]] — Random Dice의 머지-치환 모델, 머지 트리 vs 경로 업그레이드.
- [[Meta Progression]] — 6가지 메타 레이어와 잔존/밸런스 리스크 매트릭스.

## Contradictions

- [[Tower Defense Design Guide]]는 "tower-vs-wave 균형이 핵심"이라는 통상적 명제를 제시하나, [[Game Developer Tower Defense Rules]]는 그것이 *결과*이고 1차 변수는 *경제 구조*라고 본다. 결론: 두 관점은 충돌이라기보다 추상화 층위의 차이. 디자이너는 경제 → 웨이브 → 타워 순으로 튜닝해야 함.
- 라인디펜스 카논으로 PvZ를 두는 것에는 일부 이견이 있다. 일부 분류는 PvZ를 "그리드 TD"로, 라인디펜스는 *Castle Defense*류 단일 레인 게임으로 좁게 정의하기도 한다. 이 리서치는 **넓은 정의**(5–6 평행 레인 포함)를 채택했다.

## Open Questions

- 단일 레인(1행) 디펜스는 라인디펜스인가 오토배틀러인가? [[Lane Defense]]의 sub-variant 4번 항목 참조.
- Cookie Run: Kingdom의 Guardian of the Rift처럼 **원형 경로** 디펜스는 라인/타워디펜스 어느 쪽도 아닌 제3의 변종 — "circuit defense"로 별도 분류 필요.
- 절차적 웨이브 생성(NEAT 기반 등)이 손으로 짠 웨이브를 능가하는가? — 학술 논문은 능가한다고 주장하나, 상업 게임 채택 사례는 거의 없음. 왜?
- 머지 메커닉과 경로 업그레이드를 같은 게임에 공존시킬 수 있는가? 현재까지의 시도는 모두 한쪽으로 수렴.
- 한국 시장 vs 서구 인디 시장의 메타 진행 수용 한계점은 어디인가? Random Dice 수준의 카드 레벨 메타는 한국에서 통하지만 서구에서는 부정적 리뷰가 더 많음.

## Implications For my-game

라인디펜스 채택 시 우선순위 결정 가이드라인:

1. **레인 수: 5** — PvZ 표준에서 출발. 더 적으면 얕고, 더 많으면 모바일에서 가독성 붕괴.
2. **그리드: 9×5** — 검증된 비율. 셀을 데이터로 모델링.
3. **경제: 2통화** — 인-라운드(sun-style) + 메타(coin-style). 인디 v1에서 카드 레벨 시스템 미도입.
4. **덱 슬롯: 5–10** — 더 적으면 결정이 가벼워지고, 더 많으면 디자인 부담이 폭증.
5. **웨이브: 첫 10웨이브 손으로 작성**, 그 이후 절차적 또는 데이터 드리븐.
6. **업그레이드: 매치 길이로 결정** — 5분 미만 매치면 유닛 다양성, 10분+ 매치면 2×3 경로 업그레이드.
7. **PvP vs PvE 조기 결정** — 두 갈래는 밸런스 작업이 근본적으로 다름. 둘 다 노리는 v1은 위험.
8. **머지 메커닉**은 도입할 거면 *전체 게임을 머지에 거는* 결정. 절반은 어색하다.

엔진 측면에서 Godot 4.6이 픽셀 퍼펙트 2D + Tilemap 기반 그리드를 잘 지원하므로 라인디펜스는 본 프로젝트 엔진 적합도가 높다.

## Sources

- [[Wikipedia Plants vs Zombies]] — 백과사전, high confidence
- [[Game Developer Tower Defense Rules]] — 산업지, high confidence (taxonomy)
- [[Tower Defense Design Guide]] — 튜토리얼, medium confidence
- 추가 미카탈로그 출처 (Round 1–2 검색 결과 요약): MasterClass TD genre guide, Bloons Wiki Towers/Crosspathing, Random Dice 스토어 페이지(App Store, Google Play, BlueStacks, TapTap)
