---
type: entity
title: "Contra"
created: 2026-05-08
updated: 2026-05-08
tags:
  - game
  - run-and-gun
  - arcade
  - konami
  - reference-game
  - genre-progenitor
status: stable
related:
  - "[[Run and Gun Genre]]"
  - "[[Weapon Letter Pickup System]]"
  - "[[Contra Weapon System]]"
  - "[[Konami Code]]"
  - "[[Arcade Difficulty Design]]"
  - "[[Cooperative Run and Gun Design]]"
  - "[[Metal Slug]]"
  - "[[Gunstar Heroes]]"
  - "[[Contra Operation Galuga]]"
sources:
  - "[[Wikipedia Run and Gun]]"
  - "[[Wikipedia Contra Series]]"
  - "[[Wikipedia Konami Code]]"
  - "[[Megacat Studios Run and Gun History]]"
confidence: high
---

# Contra (1987)

## Identity

- **Developer / Publisher**: Konami
- **First Release**: 1987 (arcade); 1988 (NES)
- **Genre**: Run and gun — 장르 표준을 확립한 원점
- **Platform Lineage**: Arcade → NES → SNES (Contra III) → Genesis (Contra Hard Corps) → 현재까지 시리즈 지속

## 장르에서의 위치

Contra는 [[Run and Gun Genre]]의 **장르 정의 게임**이다. 1987년 이전에도 런앤건 요소를 가진 게임은 있었으나, Contra는 다음을 하나로 통합했다:

- 사이드스크롤 플랫포머 이동
- 8방향 총기 조준 (동시 이동 중)
- 협동 2인 플레이
- 무기 아이템 픽업 시스템 (알파벳 마킹)
- 아케이드 코인 경제에 맞춘 난이도

## 핵심 게임 시스템

### 조작 체계
- 8방향 조이스틱 + 2버튼(사격/점프).
- 이동 중 8방향 자유 조준 — 점프 중 하강 사격 포함.
- 이것이 Contra 이전 런앤건과의 결정적 차이.

### 무기 시스템

→ [[Weapon Letter Pickup System]] 참조.

팔콘 심볼에 알파벳이 표기된 픽업 아이템:
- **M**: Machine Gun (고속 연사)
- **L**: Laser (관통)
- **F**: Fireball (포물선 궤도)
- **S**: Spread Shot (5방향 산탄) — 가장 인기 있는 무기
- **R**: Rapid Fire (연사 속도 증가)
- **B**: Barrier (임시 무적)

탄약 없음 — 무기는 피격 시 소실.

### 레벨 구조
- 7스테이지 (아케이드); NES 버전 8스테이지 + 구성 변경.
- 사이드스크롤 스테이지 + 슈도-3D 기지 침투 스테이지(탑뷰) 혼재.
- 스테이지마다 보스 존재.

### 협동 플레이
- **2인 동시 플레이** — 런앤건 장르에서 협동 코어로 굳힌 표준.
- 두 플레이어: Bill(파란 바지), Lance(빨간 바지).
- "게임 인기의 상당 부분이 2인 협동에서 비롯됐다"는 평가 (Source: [[Wikipedia Run and Gun]]).

### 난이도
- 1히트 즉사 (장르 표준).
- 아케이드: 코인 무제한 투입.
- NES: 코나미 코드(↑↑↓↓←→←→BA)로 30 목숨 — 사실상 문화 현상이 된 치트.

## 상업 성과

- 아케이드: 1987년 미국 최고 수익 아케이드 게임 4위 안에 듦 (Source: [[Wikipedia Run and Gun]]).
- NES 버전: 200만 장 판매.
- 시리즈: Contra III (SNES), Contra Hard Corps (Genesis), Contra 4 (DS), Contra: Rogue Corps 등 지속.

## 장르에 대한 영향

- 사이드스크롤 런앤건의 **무기 픽업 레터 시스템** 표준 확립.
- 협동 플레이를 런앤건의 핵심 경험으로 정착시킴.
- 이후 Gunstar Heroes(1993), Metal Slug(1996), Blazing Chrome(2019) 모두 Contra를 직접 참조.

## Implications For my-game

1. **Contra의 S샷(Spread Shot) 교훈**: 하나의 무기가 "거의 OP"하게 느껴지도록 설계해도 게임이 재미있다면 괜찮다. 플레이어는 강력한 무기를 찾는 즐거움을 원한다.
2. **8방향 조준**: 이동 중 자유 조준은 Contra가 검증한 핵심 컨트롤. 제한적 조준(Metal Slug 방식)과 자유 조준(Contra 방식) 중 선택이 필요.
3. **협동 플레이 코어**: 2인 협동은 아케이드 수익과 플레이어 경험 모두에 기여. v1에서 구현 가치가 높다.

## 생명 / 콘티뉴 시스템 (심층)

- **시작 잔기**: 3 목숨 (코나미 코드 미사용 시)
- **잔기 추가**: 점수 일정 임계값 도달 시 추가 잔기 지급 (NES 버전 기준 30,000점 및 이후 일정 간격)
- **사망 조건**: 총탄, 폭발, 추락, 적 접촉 — 모두 즉사. 무기 소실 후 기본 무기로 복귀.
- **콘티뉴**: 게임 오버 후 최대 3회 콘티뉴 가능 (아케이드: 코인 투입으로 무제한)
- **코나미 코드**: ↑↑↓↓←→←→BA → 30 목숨으로 시작. 사실상 NES 버전의 접근성 패치 역할 → [[Konami Code]] 참조

> [!gap] 점수 기반 추가 잔기의 정확한 임계값(30,000점 이후 간격) 확인 필요.

## NES 버전 스테이지 구조 (8스테이지)

| # | 스테이지명 | 스크롤 방식 | 특징 |
|---|---|---|---|
| 1 | Jungle | 사이드스크롤 | 시리즈 시작. 정글 지형, 다수 적 |
| 2 | Base 1 | 슈도-3D (탑뷰 기지) | 파이프/문 침투. 코어 파괴 목표 |
| 3 | Waterfall | 수직 스크롤 | 위에서 아래로 폭포 따라 하강 |
| 4 | Base 2 | 슈도-3D (탑뷰 기지) | Base 1과 유사 구조, 난이도 상승 |
| 5 | Snowfield | 사이드스크롤 | 설원 지형, 블리자드 연출 |
| 6 | Energy Zone | 사이드스크롤 | 에너지 설비 배경, 고밀도 적 |
| 7 | Hangar | 사이드스크롤 | 격납고 내부, 보스 집중 |
| 8 | Alien's Lair | 사이드스크롤 | 최종 보스. 외계 생명체 테마 |

**스테이지 다양화 패턴의 설계 의의:**
- 사이드스크롤 + 수직스크롤 + 슈도-3D 탑뷰의 3가지 뷰 혼재
- 각 뷰 전환이 조작 방식과 전술을 바꿔 단조로움 방지
- 슈도-3D 기지 스테이지(2, 4)는 이후 시리즈 및 후속 런앤건에서 거의 계승되지 않음

## 2인 동시 협동: 설계적 함의

→ 전체 분석은 [[Cooperative Run and Gun Design]] 참조

Contra의 협동 플레이는 런앤건 장르에서 **"진정한 동시 플레이" 표준을 확립**했다:
- 두 플레이어가 **같은 화면에서 동시에** 독립적으로 행동
- 화면 분할(split-screen) 없음 — 공유 화면이 협력과 충돌 양쪽을 만들어냄
- 무기 픽업 경쟁, 화면 스크롤 조율, 공동 화력 집중이 협동의 핵심 긴장 요소

> "게임 인기의 상당 부분이 2인 동시 협동에서 비롯됐다." (Source: [[Wikipedia Run and Gun]])

## 코나미 코드와 문화적 영향

→ [[Konami Code]] 참조

**치트 코드 (↑↑↓↓←→←→BA):**
- NES Contra에서 30 목숨 부여 — 접근성을 낮춰 대중화에 기여
- "Contra Code" 또는 "30 Lives Code"라는 별칭으로 북미 전역에 인지됨
- 이후 코나미 게임 전반, 타사 게임, 현대 디지털 플랫폼(Netflix, Discord 등)으로 확산

**문화적 레퍼런스:**
- 영화 *Predator* (1987), *Aliens* (1986)의 비주얼/분위기가 Contra에 직접 영향
- "Contra 같다"는 표현이 "극한 난이도 + 빠른 액션 런앤건"의 일반 어휘로 정착
- 1987~1990년대 일본/북미/한국 시장에서 "런앤건 = Contra"의 장르 대표 인식

## 시리즈 진화 타임라인

(Source: [[Wikipedia Contra Series]])

| 제목 | 연도 | 주요 변화 | 평가 |
|---|---|---|---|
| **Contra** | 1987 | 시리즈 원점. 사이드스크롤 + 슈도-3D 혼재 | 장르 정의 |
| **Super Contra** | 1988 | 슈도-3D → 탑뷰 오버헤드로 교체 | 호평 |
| **Contra III: The Alien Wars** | 1992 | 벽 타기, 듀얼 무기 교체, 스마트 봄 | SNES 명작 |
| **Contra: Hard Corps** | 1994 | 선택 캐릭터(고유 능력), 분기 스토리 | Genesis 최고작 평가 |
| **Contra: Shattered Soldier** | 2002 | 폴리곤 3D 그래픽 + 2D 사이드스크롤 유지 | 하드코어 팬 호평 |
| **Neo Contra** | 2004 | 아이소메트릭 시점 + 무기 커스터마이징 | 혼재 평가 |
| **Contra 4** | 2007 | WayForward. DS 듀얼스크린 + 그래플링 훅 | 비평 호평, 팬 환영 |
| **Hard Corps: Uprising** | 2011 | Arc System Works. 애니메이션 비주얼 | 독립적 호평 |
| **Contra: Rogue Corps** | 2019 | 3D 액션으로 변질 | 팬덤 혹평 |
| **Contra: Operation Galuga** | 2024 | WayForward 리메이크. 캐릭터 선택 + 스킬 추가 | 혼재 평가 |

**3D 실패 패턴:** Legacy of War(1996), C: The Contra Adventure(1998), Rogue Corps(2019) — 3D 전환 시도 모두 저평가. [[Run and Gun Success Pattern Matrix]] 참조.

**WayForward 부활(2007, 2024):** 외부 스튜디오가 원작 정신을 계승하는 두 번의 성공적 개입 → [[Contra Operation Galuga]] 참조.

1996년까지 시리즈 누적 **400만 장 이상** 판매. (Source: [[Wikipedia Contra Series]])

## Open Questions

- Contra의 슈도-3D 기지 스테이지(파이프 침투 등)는 왜 후속 런앤건에서 계승되지 않았는가?
- Contra 코나미 코드가 게임 판매에 도움이 됐는가, 아니면 방해가 됐는가? (접근성 vs 수익성)
- WayForward는 왜 Contra IP의 "정통 계승자"로 반복 선택됐는가? 코나미 내부 역량 공백인가?
- Hard Corps: Uprising(2011, Arc System Works)이 시리즈 정식 라인에서 자주 제외되는 이유?
