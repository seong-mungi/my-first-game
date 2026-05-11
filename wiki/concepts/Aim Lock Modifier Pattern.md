---
type: concept
title: Aim Lock Modifier Pattern
created: 2026-05-11
updated: 2026-05-11
tags:
  - input
  - aim
  - design-pattern
  - run-and-gun
  - 8-way
  - echo-applicable
status: developing
related:
  - "[[Research 8-Way Aim Usability For Run-and-Gun]]"
  - "[[Cuphead]]"
  - "[[Contra Operation Galuga]]"
  - "[[Hard Corps Uprising]]"
  - "[[Run And Gun Base Systems]]"
  - "[[Analog Stick To 8-Way Quantization]]"
---

# Aim Lock Modifier Pattern

런앤건의 8방향 조준에서 모던 컨벤션으로 수렴한 입력 패턴: **수정자 키를 누른 동안 이동을 정지(또는 strafe로 전환)하고 방향 입력이 조준만 변경**한다. 1987 콘트라의 "이동=조준" 강제 결합을 풀어, 플레이어가 정지한 채 8방향을 모두 조준할 수 있게 만든다.

## Core Mechanic

```
디폴트 (lock OFF):
  방향 입력 → 이동 + 조준 (결합)

Lock 수정자 HOLD:
  방향 입력 → 조준만 변경 (이동 정지 또는 strafe)
  발사 입력 → 조준된 방향으로 사격
```

## Verified Implementations

| 게임 | Lock 키 (Gamepad) | Lock 키 (KB+M) | 동작 |
|---|---|---|---|
| **Cuphead (2017)** | RB / R1 | C | 정지 + 8방향 조준. 점프 가능. Lock 중 대시/duck 불가. |
| **Contra: Operation Galuga (2024)** | ZR | 리바인드 (디폴트 미공개) | 정지 + 360° 또는 8방향 조준 (옵션 토글). |
| **Hard Corps: Uprising (2011)** | **L = strafe-lock**, **R = plant-and-rotate** | n/a | 듀얼 버튼: L은 strafe (이동 가능 + 조준 유지), R은 plant (정지 + 8방향). |
| **Gunstar Heroes (1993)** | 게임 시작 시 모드 선택 | n/a | Free Shot (이동=조준 결합) vs Fixed Shot (plant-lock 항시) 런 시작 시 락인. |
| **Echo (2026)** | RB | F | 정지 + 8방향 조준. 점프 가능 (DEC-PM-2). |

## 듀얼 vs 싱글 락 변종

- **Single-button** (Cuphead / Galuga / Echo): 한 키로 plant-and-rotate. 단순. 학습 쉬움.
- **Dual-button** (Hard Corps Uprising): strafe-lock + plant-lock 분리. 표현력 ↑, 학습 비용 ↑. 평론가 호평. 듣기엔 좋으나 indie 솔로 규모엔 과잉.
- **Stance toggle** (Gunstar Heroes): 런 시작 시 한번 선택. 학습 곡선 분리하나 두 모드를 같은 플레이어가 경험 못 함. 오래된 패턴.

## Echo 적용

### Gamepad
- `aim_lock = RB` — Cuphead/Galuga 컨벤션 정합.
- Lock 중 점프 허용 (DEC-PM-2 비협상).
- Lock 중 duck 허용? — 미정. Cuphead는 불허, Echo는 검토 필요.
- Lock 중 대시: Echo는 Tier 1에 대시 없음 ([[Contra Per Entry Mechanic Matrix]] 한-axis-한-번 룰).

### KB+M
- `aim_lock = F` — 산업 표준 없음 (Cuphead는 C). F가 방어 가능한 중립 선택:
  - Shift 회피 (Cuphead 대시 컨벤션 충돌)
  - RMB 회피 (FPS ADS는 2D 런앤건에 부적합)
  - Q/E 회피 (무기 스왑 컨벤션)
  - WASD 홈 위치에서 우측 약지 도달 가능
- 단일 키 (chord 금지) — 6KRO 키보드 dead-key latency 회피.

## 발견성 문제

**Cuphead Steam 스레드 다수**: 플레이어가 Lock 메카닉을 발견하지 못해 "대각선 조준 안 됨" 호소. 디자이너 의도와 무관하게 *발견*이 디자인 결함.

대응 패턴:
1. **명시 튜토리얼** — 1번 보스 전 강제 lock+direction 시나리오.
2. **첫 사망 hint** — "방향키만으론 조준이 결합됨. Lock을 시도하세요."
3. **HUD 텔레그래프** — 적이 대각선에 있을 때 Lock 키 아이콘 펄스.
4. **컨트롤 차트 표시** — 메뉴 첫 화면에 컨트롤 매핑 시각화.

Echo는 1히트 즉사 + 9프레임 되감기로 빠른 학습 사이클 가능 — *첫 사망 후 첫 되감기 시점이 자연스러운 hint 위치*.

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| Lock 중 이동도 가능 + 조준도 분리 | Lock의 *의미* 사라짐 — twin-stick 흉내가 됨. 사이드스크롤 정체성 손실. |
| Lock 키가 chord (Shift+X 등) | 6KRO 키보드 dead-key, dead-zone latency |
| Lock 토글 (press once = on) | "Lock 켜져있는지 모름" 상태 발생. Hold가 모던 표준 |
| Lock 키가 Shift/Ctrl | 대시/달리기 컨벤션 충돌 |
| KB+M Lock 키를 RMB로 | FPS ADS 컨벤션 거짓 일치 — Echo는 마우스 방향 조준 아님 |
| Mouse-aim과 Lock 동시 노출 | 어느 게 정통인지 혼란 |

## 호환성 / 게이트

- **Color-blind** 영향 X (입력 패턴, 시각 아님).
- **Single-stick 모드** ([[Aim Assist Accessibility Tiers]]) 시 Lock 불필요 — auto-fire + auto-aim-nearest로 대체.
- **Speedrun 카테고리**: Lock 사용 vs 비사용 분리? Cuphead 커뮤니티 분리 X (Lock 사용이 표준).

## Open Questions

- **Echo Lock 중 점프 시 8방향 사격 — 점프 자세 유지하면서 조준만 변경?** (Cuphead 처럼)
- **Lock 키 홀드 한도 시간 (예: 2초 후 자동 해제)?** 없음 권고 (모던 컨벤션).
- **Lock 활성 시 시각 indicator?** Echo의 콜라주 톤 + 시안-마젠타 시그니처와 어떻게 통합?
- **Tier 3 리바인드 시 Lock 키 chord 허용?** ([[Bot Validation Catalog Summary]] OQ-15 클로즈 — Default-only 권고).

## Related

- [[Research 8-Way Aim Usability For Run-and-Gun]] — 부모 컨텍스트
- [[Analog Stick To 8-Way Quantization]] — 게임패드 측 양자화 (Lock과 직교)
- [[Run And Gun Base Systems]] — 베이스 시스템 5가지에 aim_lock 포함되나? (현재 미언급, Echo 추가 검토)
- [[Contra Per Entry Mechanic Matrix]] — 콘트라 시리즈 aim 메카닉 비교
- [[Modern Difficulty Accessibility]] — Lock 발견성 ↔ 접근성
