---
type: concept
title: "Run and Gun Genre"
created: 2026-05-08
updated: 2026-05-08
tags:
  - game-design
  - genre
  - run-and-gun
  - arcade
  - side-scrolling
status: stable
related:
  - "[[Run and Gun Base Systems]]"
  - "[[Run and Gun Extension Systems]]"
  - "[[Arcade Difficulty Design]]"
  - "[[Weapon Letter Pickup System]]"
  - "[[Metal Slug]]"
  - "[[Contra]]"
  - "[[Gunstar Heroes]]"
  - "[[Cuphead]]"
  - "[[Lane Defense]]"
sources:
  - "[[Wikipedia Run and Gun]]"
  - "[[Megacat Studios Run and Gun History]]"
confidence: high
---

# Run and Gun Genre

## 장르 정의

**런앤건(Run and Gun)**은 슈팅 게임의 하위 장르. 핵심 정의:

- 플레이어 캐릭터가 **발로 걸어다니며(on foot)** 이동
- 이동과 사격을 **동시에** 수행 (no camping)
- 횡스크롤 또는 탑뷰 2D 환경
- 다수의 적을 쏘아 넘기며 스테이지 진행

슈팅 장르의 하위이면서 플랫포머 장르와 접점을 갖는 혼합형.

## 장르 분류 (Taxonomy)

### 관점별 분류

| 서브타입 | 관점 | 대표 게임 | 이동 방식 |
|---|---|---|---|
| 사이드스크롤링 | 횡스크롤 | Contra, Metal Slug, Gunstar Heroes | 좌우 스크롤 |
| 오버헤드/탑다운 | 탑뷰 수직 스크롤 | Commando(1985), Ikari Warriors(1986) | 위로 스크롤 |
| 등각/아이소메트릭 | 45도 탑뷰 | 일부 변종 | 대각 이동 |
| 보스 러시 하이브리드 | 혼합 | Cuphead(2017) | 스테이지+보스 |

**사이드스크롤링이 장르의 주류**이며, "런앤건"이라 하면 통상 이 타입을 지칭.

### 인접 장르와의 경계

| 장르 | 플레이어 | 이동 | 시점 | 핵심 차이 |
|---|---|---|---|---|
| **런앤건** | 보병 | 스크롤 | 2D 횡/탑뷰 | 이동+사격 동시, 점프 포함 |
| **플랫포머** | 보병 | 스크롤 | 2D 횡 | 사격보다 점프/이동이 주 메커닉 |
| **슈팅 게임(shmup)** | 기체/탈것 | 스크롤 | 2D | 지상 이동 없음, 탑승체 조종 |
| **트윈스틱 슈터** | 보병 | 360° 아레나 | 탑다운 | 자유 360° 이동+사격, 스크롤 없음 |
| **TPS(3인칭 슈터)** | 보병 | 3D 자유 | 3D | 3D 공간, 커버 시스템, 리로드 |

> [!gap] 장르 경계는 역사적으로 논쟁적. Contra를 "사이드스크롤 플랫포머"로 분류하는 출처도 있음. 현재 업계 표준은 런앤건으로 통용.

## 하드웨어 계보 (Hardware Lineage)

```
아케이드 황금기 (1985–1995)
  Commando → Contra → Metal Slug
  [코인 투입 경제, 고난이도, 짧은 플레이 세션]
         ↓
가정용 콘솔 이식 (1988–2000)
  NES Contra → SNES Contra III → Genesis Gunstar Heroes → Neo Geo/PSX Metal Slug
  [무제한 컨티뉴, 더 긴 세션, 접근성 향상]
         ↓
3D 전환기 — 장르 쇠퇴 (2000–2010)
  3D 전환에 실패. TPS(3인칭 슈터)가 주류 흡수.
  런앤건은 휴대용(GBA, DS)에서 명맥 유지.
         ↓
인디 부활 (2010–현재)
  Alien Hominid → Broforce(2015) → Cuphead(2017) → Blazing Chrome(2019)
  → Huntdown(2020) → Huntdown: Overtime(2026, 로그라이트)
  [Steam/Switch 플랫폼, 레트로 픽셀아트, 극한 난이도 부활]
```

## 장르 역사의 핵심 마일스톤

| 연도 | 게임 | 의의 |
|---|---|---|
| 1981 | Jump Bug | 최초 사이드스크롤 런앤건 |
| 1985 | Commando | 탑다운 런앤건 표준 |
| 1987 | **Contra** | 사이드스크롤 런앤건 장르 정의. 8방향 조준 + 협동 |
| 1993 | **Gunstar Heroes** | 장르 크래프트 정점. 무기 조합, 거대 보스 |
| 1996 | **Metal Slug** | 아케이드 시각 예술 정점. 탈것, POW, 유머 |
| 2015 | Broforce | 인디 부활. 완전 파괴 가능 환경 |
| 2017 | **Cuphead** | 현대 인디 최대 상업 성공. Boss Rush 하이브리드 |
| 2019 | Blazing Chrome | 순수 장르 계승. Contra+Metal Slug DNA |
| 2026 | Huntdown: Overtime | 로그라이트 하이브리드로 장르 확장 |

## 왜 장르가 3D 전환에 실패했는가

런앤건의 핵심 경험(밀집한 적 처리, 패턴 암기, 화면 장악)은 **2D 평면에 최적화**된 구조.
3D로 전환 시:
- 카메라 관리가 조작에 개입 → 핵심 플로우 파괴
- 적 밀도와 투명도 관리 어려움
- 플랫포머 점프의 정밀도 저하

결과: 런앤건 3D 시도는 Contra: Legacy of War(1996), Metal Slug 3D(2004) 등 대부분 부진.
**반면 TPS가 이 자리를 차지** (Cabal → Wild Guns → Gears of War 계보).

## 인디 부활의 조건

2010년대 이후 인디 런앤건 부활을 가능하게 한 세 요인:
1. **Steam/Switch의 인디 생태계**: 소규모 팀도 전 세계 배포 가능.
2. **레트로 픽셀아트 수용**: AAA 대비 열위 없이 경쟁 가능한 아트 스타일.
3. **노스탤지어 시장**: 1990년대 아케이드 세대가 30~40대 구매력 있는 게이머로 성장.

## Implications For my-game

런앤건 장르를 참조하거나 채택할 때의 핵심 고려사항:

1. **관점 선택**: 사이드스크롤이 장르의 주류이자 가장 검증된 형태. 탑다운은 다른 경험을 제공하지만 사례가 적다.
2. **장르 경계 명확화**: 플랫포머, shmup, 트윈스틱과의 경계를 설계 초기에 정해야 한다. "이 게임에서 점프가 중심인가, 사격이 중심인가?"
3. **3D 전환 위험**: 런앤건의 핵심 경험은 2D에서 최적화됨. 3D 런앤건은 역사적으로 실패율이 높다.
4. **인디 포지셔닝**: Cuphead와 Blazing Chrome의 성공 공식 — 복고 미학 + 극한 난이도 + 협동 플레이. 이 세 요소 중 하나 이상을 갖춰야 시장에서 구분된다.

## Open Questions

- 런앤건 장르가 모바일에서 성공한 사례가 없는 이유는 무엇인가? (터치 조작의 한계? 세션 길이? 가격 모델?)
- 런앤건과 로그라이트의 결합(Huntdown: Overtime 등)이 장르의 다음 주류 방향인가?
