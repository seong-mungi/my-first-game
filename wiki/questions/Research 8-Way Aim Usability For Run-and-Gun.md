---
type: synthesis
title: "Research: 8-Way Aim Usability For Run-and-Gun"
created: 2026-05-11
updated: 2026-05-11
tags:
  - research
  - run-and-gun
  - input
  - aim
  - 8-way
  - gamepad
  - keyboard-mouse
  - accessibility
  - echo-applicable
status: developing
question: "런앤건 게임에서 8방향 조준의 사용성을 위한 게임시스템은 무엇이며, 게임패드와 키보드+마우스에서 각각 어떻게 다른가?"
answer_quality: solid
related:
  - "[[Aim Lock Modifier Pattern]]"
  - "[[Analog Stick To 8-Way Quantization]]"
  - "[[Aim Assist Accessibility Tiers]]"
  - "[[Run and Gun Genre]]"
  - "[[Modern Difficulty Accessibility]]"
  - "[[Contra Per Entry Mechanic Matrix]]"
  - "[[Cuphead]]"
  - "[[Contra Operation Galuga]]"
sources:
  - "[[Game Developer Thumbstick Deadzones]]"
  - "[[XAG 107 Aim Assist Guidelines]]"
---

# Research: 8-Way Aim Usability For Run-and-Gun

## Overview

8방향 조준은 콘트라(1987) 이래 런앤건 장르의 시그니처 입력 패턴. 게임패드와 KB+M은 본질적으로 다른 사용성 도전을 가짐 — 게임패드는 *아날로그→이산* 양자화가 핵심 문제, KB+M은 *키보드 8방향 유지 vs 마우스 360° 전환* 결정이 핵심. 두 입력 모두 **`aim_lock` 수정자 키 (Lock-then-aim)** 가 모던 컨벤션으로 수렴.

## Key Findings

### 게임패드 (아날로그 → 8방향)

- **Lock-then-aim 패턴이 모던 표준** — Cuphead RB · Hard Corps L+R · Contra Galuga ZR 모두 같은 패밀리. Echo의 `aim_lock=RB` (gamepad) 결정은 on-pattern (Source: [[Aim Lock Modifier Pattern]]).
- **Radial 데드존 + Schmitt trigger**가 8방향 양자화의 정통 기법. Unity InputSystem 디폴트 0.125/0.925; Echo의 0.20/0.15 enter/exit는 Unity-derived 실무에 맞음 (Source: [[Analog Stick To 8-Way Quantization]]).
- **Steam Deck 드리프트 ~0.18 floor** — Echo의 `FACING_THRESHOLD_AIM_LOCK = 0.1`은 Steam Deck LCD 1세대에서 마진 부족. **0.15로 상향 권장**.
- **Snap-to-8 알고리즘**: `sector = round(atan2(y,x) / (TAU/8)) mod 8`. JoyShockMapper `FLICK_SNAP_MODE 8`이 레퍼런스.
- **각도 hysteresis ±3-5°** — 45° 경계에서 떨림 방지. 마그니튜드 Schmitt만으로 부족.
- **2-3 frame commitment timer** — 33-50 ms 동안 같은 sector가 유지되어야 전환. 각도 hysteresis와 결합 권장.
- **대각선 vs 카디널 균형**: 균등 45° 또는 약한 카디널 편향 (50°/40°). 대각선이 물리적으로 잡기 어려움.

### KB+M (8방향 유지 vs 마우스 360° 전환)

- **장르가 결정한다**: Top-down twin-stick (Hotline Miami, Enter the Gungeon, Nuclear Throne)은 마우스 360° 전환. Side-scroll run-and-gun (Cuphead PC, Contra Galuga PC)은 **WASD 8방향 유지 + lock 수정자**.
- **마우스-방향 조준 KB+M-only ≠ Echo**. Hotline Miami는 KB+M-first 설계 (top-down). Side-scroll run-and-gun 마우스 조준은 장르 정체성 파괴.
- **`aim_lock` 키 산업 표준 없음** — Cuphead=C, Contra Galuga=리바인드 디폴트 미공개, Hotline=Shift는 "look-ahead"용. **F는 방어 가능한 중립 선택** (Shift 대시 충돌 회피, RMB는 장르-wrong, Q/E는 무기 스왑 충돌).
- **RMB-as-ADS 패턴은 2D 런앤건에 이식 안 됨** — FPS 컨벤션이 사이드스크롤에서 무의미. Hotline은 RMB=grab, Gungeon은 RMB=dodge.
- **Chord 금지 (single-key)** — 6KRO 키보드에서 dead-key latency. Echo의 chord 금지 정책 ([[Bot Validation Catalog Summary]] 비협상 결정과 정합).

### 모던 접근성 (2018-2026)

- **XAG Guideline 107** (Microsoft) 의무: single-stick 모드 + auto-fire 토글 + ±50% 감도 조정.
- **Game Accessibility Guidelines**: 어시스트 모드는 *난이도와 직교* (decoupled). 어시스트 ON이라고 진척/업적 게이트 X.
- **Returnal 모델**: aim assist Off/Low/Medium/High 4단계, 디폴트 Medium. 난이도 선택과 독립.
- **Cuphead 패리 슈가**: 어시스트 모드 자체 거부하고 charm으로 우회. 현대 표준에 미달 — 커뮤니티 mod로 보충됨.
- **Single-stick 변형**: auto-fire + auto-aim-nearest = 1-stick로 2-stick 게임 플레이 가능. XAG 107 의무.
- **시각 표시**: aim-lock 활성 시 dual-channel (색 + 모양/외곽선). 색맹 호환.

## Key Entities

- [[Cuphead]] — Lock-then-aim의 indie revival 정점 (RB / C)
- [[Contra Operation Galuga]] — 360° 아날로그 + 8방향 토글 + ZR aim-lock (2024 모범)
- [[Hard Corps Uprising]] — L=strafe-lock / R=plant-lock 듀얼 버튼 (드문 패턴)
- [[Hotline Miami]] — KB+M 마우스 360° (top-down 전용, 사이드스크롤엔 X)
- [[Returnal]] — aim assist 4단계 + 난이도 독립 (모던 표준)
- [[Enter the Gungeon]] · [[Nuclear Throne]] — twin-stick → KB+M 표준 (마우스 360° aim)

## Key Concepts

- [[Aim Lock Modifier Pattern]] — Lock-then-aim 모던 컨벤션 (RB/C/F)
- [[Analog Stick To 8-Way Quantization]] — 데드존 + Schmitt + snap-to-8 알고리즘
- [[Aim Assist Accessibility Tiers]] — Off/Low/Med/High 표준 + XAG 107 의무

## Contradictions

- **Metal Slug 베이스 무기 4방향 vs 8방향**: StrategyWiki/Wikipedia는 베이스 권총 4방향이라 명시; Steam 커뮤니티는 8방향이라 주장. 원본 AES/MVS 1차 검증 필요 — 현재 미해소.
- **Aim assist 디폴트값**: Returnal=Medium 디폴트는 호평. 일부 비평가는 Off 디폴트를 권고 (1-hit-death 게임에서 flick-disengage 패턴 보존). **Echo는 1-hit 즉사 + 9프레임 되감기 → Off 디폴트 권장**.

## Open Questions

- **Cuphead 대각선 발견성** — 플레이어가 Lock 메카닉을 발견하는 데 평균 얼마? 어떤 튜토리얼 디자인이 발견 시간을 단축? (Steam 스레드 다수가 "Up+Right 안 되는데?" 호소.)
- **Echo 마우스 조준 옵션 제공?** — Contra Galuga는 거부 후 비판 받음. 접근성 vs 장르 정체성 트레이드오프.
- **Single-stick 모드의 auto-fire**: 조준된 적이 있을 때만 발사 vs 항상 발사? Echo의 1-hit + 토큰 회계와 충돌 가능.
- **대각선 vs 카디널 sector 폭**: 균등 45° vs 약한 카디널 편향 50°/40°? 데이터 부족.
- **어시스트 ON 시 speedrun 별도 카테고리?** — [[Speedrun Discovery Via RL Bot]]와 충돌 가능성.

## Echo Action Items

### 즉시 적용
- `FACING_THRESHOLD_AIM_LOCK 0.1 → 0.15` 상향 (Steam Deck 드리프트 floor 회피)
- 각도 hysteresis ±4° 추가 (45° 경계 떨림 방지)
- 2-3 프레임 sector commitment timer 추가
- KB+M `aim_lock=F` 유지 (Shift/RMB 회피 근거 강화)
- Gamepad `aim_lock=RB` 유지 (Cuphead/Galuga 컨벤션)

### Tier 1 게이트
- Aim assist 4단계 (Off/Low/Med/High) — 디폴트 Off (Echo의 1-hit + rewind 메카닉과 정합)
- XAG 107 준수 — auto-fire 토글 + ±50% 감도
- 어시스트 ↔ 난이도 직교 (Returnal 모델)

### Tier 3 평가
- Single-stick 모드 (CFAA / Xbox Adaptive)
- 마우스 360° aim 옵션 (장르 정체성 vs 접근성 균형 결정 필요)
- 시각 indicator dual-channel (색 + 모양)

## Sources

- [[Game Developer Thumbstick Deadzones]] — 산업 canonical 데드존 가이드
- [[XAG 107 Aim Assist Guidelines]] — Microsoft Xbox 접근성 의무
- [Game Developer — Doing Thumbstick Dead Zones Right](https://www.gamedeveloper.com/business/doing-thumbstick-dead-zones-right) — 2014, High
- [Unity InputSystem — Processors](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.0/manual/Processors.html) — Authoritative engine defaults (0.125/0.925)
- [Game Developer — Valve on Steam Deck drift](https://www.gamedeveloper.com/programming/valve-says-steam-deck-stick-drift-was-caused-by-deadzone-regression-bug) — 2023, Valve 1차
- [JoyShockMapper FLICK_SNAP_MODE](https://github.com/JibbSmart/JoyShockMapper) — 45° quantization 레퍼런스
- [Game Accessibility Guidelines — Aim Assist](https://gameaccessibilityguidelines.com/include-assist-modes-such-as-auto-aim-and-assisted-steering/) — 산업 표준
- [Microsoft Learn — XAG 107](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/107) — Xbox 권위 가이드라인
- [Steam Community — Cuphead Basics Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1310872602) — Lock=C KB+M, 2018
- [Steam — Contra Galuga mouse-aim refused](https://steamcommunity.com/app/2235020/discussions/0/4346607305577551216/) — 2024
- [Cuphead Fandom — Shoot/Lock](https://cuphead.fandom.com/wiki/Shoot_/_Lock) — Lock + 방향 = 8-way
- [Family Gaming Database — Returnal Accessibility](https://www.familygamingdatabase.com/accessibility/Returnal) — Off/Low/Med/High 4단계
- [Critical-Gaming — Analog Stick pt.2](https://critical-gaming.com/blog/2011/8/11/controller-design-analog-stick-pt2.html) — octagonal gate feel
- [GitHub — Minimuino/thumbstick-deadzones](https://github.com/Minimuino/thumbstick-deadzones) — 6 데드존 비교 테스트
