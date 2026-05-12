---
title: Steam Genre Competition Density Matrix
tags: [concept, steam, genre, competition, market, density, matrix]
aliases: [장르 경쟁 밀도, Gap Score]
cssclasses: []
created: 2026-05-12
updated: 2026-05-12
---

# Steam Genre Competition Density Matrix

Steam 장르별 출시 밀도 (경쟁 수)와 수요를 교차한 매트릭스. Eastshade Studios 분석 기반.

---

## 핵심 측정 지표

**경쟁 밀도** = 3.5년 기간 동안 같은 서브장르 출시 수  
**Gap Score** = 낮은 경쟁 밀도 × 높은 유사작 성공률 → 진입 기회 지표

---

## 출시 밀도 데이터 (3.5년 누적, confidence: high)

| 장르/서브장르 | 3.5년 출시 수 | 연간 환산 | 비고 |
|---|---|---|---|
| 2D/3D 플랫포머 | **~1,900** | ~543/년 | 가장 포화 |
| Puzzle | 높음 | 300+/년 | 수익 대비 경쟁 과다 |
| Match-3 | 높음 | - | 모바일 포화 이전 |
| Bullet Heaven | 중간→높음 | 2023년 17히트→2024년 1히트 | 급격 포화 전환 |
| Cozy/Farm Sim | 중간 | - | 62% 유사 루프 |
| Action Roguelite | 높음 | - | 2024년 하락세 |
| **Roguelike Deckbuilder** | **~80** | **~23/년** | 4X와 합산 160개 |
| **4X 전략** | **~80** | **~23/년** | "적은 경쟁, 높은 수요" |
| **Job Simulator (블루칼라)** | 낮음 | - | 2024-2025 급성장 중 |
| **Idle/Incremental** | 낮음→중간 | 2024년 8히트 (2022/23년 3개 수준) | |

> [!gap] 출시 수 절대값은 Eastshade Studios 2022 분석 기반. 2024-2025 최신 데이터는 SteamDB 직접 조회 필요.

---

## 수요-공급 사분면

```
           수요 높음
               │
    Roguelike  │  Co-op 소셜 공포
    Deckbuilder│  (6%→36%)
    4X 전략    │
               │
공급 낮음 ─────┼───── 공급 높음
               │
    내러티브/  │  플랫포머
    탐험 게임  │  퍼즐 / Match-3
               │  Bullet Heaven
               │
           수요 낮음
```

**목표 사분면: 좌상단** — 수요 높음 + 공급 낮음

---

## 실행 가이드: 경쟁 밀도 자가 분석법

1. SteamDB → 태그 검색 → 최근 3년 출시 수 집계
2. 연간 50개 초과 = 경쟁 포화 경고
3. 연간 25개 미만 = 저경쟁 기회 구간
4. 상위 리뷰 게임 5개의 평균 리뷰 수 체크 → 수요 검증
5. Gap Score = 낮은 출시 수 × 높은 평균 리뷰 수

---

## 장르 선택 의사결정 트리

```
개발 기간 ≤ 6개월?
├── Yes → 직업 시뮬레이터 or 단편 공포
│         (저경쟁 + 빠른 개발)
└── No  → 6-12개월?
          ├── Yes → Co-op 소셜 공포 or Roguelike Deckbuilder
          └── No  → 12개월+ → 4X 전략 or Survival
```

---

## 포화 장르 진입 시 생존 조건

포화 장르에도 성공 사례는 있음. 필수 조건:
- **강한 IP 또는 팬덤** (HoloCure = VTuber IP 활용)
- **명확한 장르 외 차별화** (서브장르 퓨전)
- **마케팅 자원** (포화 = 발견성 전쟁)

Echo(런앤건)는 시간 되감기 메카닉으로 런앤건 포화 구간에서 차별화 포지셔닝.

---

## 출처

- Eastshade Studios: "Genre Viability on Steam and Other Trends" (Game Developer)
- HowToMarketAGame: Q2 2024 장르별 히트 게임 분석
- game-oracle.com: "Is Steam Really Saturated?" (2025)
- indielaunchlab.com: 20K+ Games Launched on Steam in 2025

→ [[Research Steam Low Competition Genre Analysis]]
→ [[Job Simulator Blue Collar Genre Pattern]]
→ [[Research Steam Indie Short Dev Genre Landscape]]
