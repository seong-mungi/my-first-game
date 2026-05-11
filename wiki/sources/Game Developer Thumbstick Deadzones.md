---
type: source
title: "Game Developer: Doing Thumbstick Dead Zones Right"
source_type: industry-article
author: Josh Sutphin
date_published: 2014-09
url: https://www.gamedeveloper.com/business/doing-thumbstick-dead-zones-right
confidence: high
tags:
  - source
  - input
  - deadzone
  - gamepad
  - industry-canonical
status: catalogued
related:
  - "[[Analog Stick To 8-Way Quantization]]"
  - "[[Research 8-Way Aim Usability For Run-and-Gun]]"
key_claims:
  - "Axial (cross) deadzones cause direction snapping to cardinals, bad for free aim"
  - "Radial deadzones preserve smooth rotation, are industry consensus"
  - "Scaled radial remaps post-deadzone to [0,1], eliminates edge discontinuity"
  - "Hybrid scaled radial + sloped scaled axial is best of breed"
---

# Game Developer: Doing Thumbstick Dead Zones Right

산업 canonical 데드존 가이드. Josh Sutphin (2014). Game Developer (구 Gamasutra) 게시.

## 핵심 주장

### Axial (cross) deadzone — 거부
- per-axis threshold (`|x| > T` 또는 `|y| > T`)
- 결과: 카디널 (N/S/E/W)에 "snap"되고 대각선 도달이 어려움
- *우연히* 8방향 양자화와 정합하지만, 의도된 정밀성이 아니라 부작용

### Radial (circular) deadzone — 디폴트
- magnitude test (`|v| > T`)
- 부드러운 회전 보존
- 산업 합의

### Scaled radial — 정밀 게임 표준
- radial + 사후 [0,1]로 remap
- threshold 바로 위에서 magnitude가 0이 아닌 0+ε이 되는 edge discontinuity 제거
- "ship-quality" 정밀 게임에 권장

### Hybrid (scaled radial + sloped scaled axial) — 최선
- 두 방식 결합
- 6가지 데드존 비교 테스트에서 5/6 통과 (Minimuino 오픈소스 검증)
- twin-stick / run-and-gun에 권장

## Echo 적용

Echo는 **Scaled radial** 또는 **Hybrid** 채택 권고. Axial 절대 X — 대각선 조준이 핵심인 8방향 시스템에서 axial 사용 시 대각선이 reach-impossible.

상세: [[Analog Stick To 8-Way Quantization]] § Stage 1.

## 인용된 후속 작업

- Minimuino/thumbstick-deadzones GitHub 비교 테스트 (오픈소스 구현)
- Unity InputSystem이 이 가이드라인 채택 (0.125/0.925 디폴트)
- 다수의 indie 솔로 개발자 포스트모템에서 이 가이드 인용

## Credibility

- **High** — Game Developer (구 Gamasutra)는 산업 표준 publication
- Josh Sutphin은 indie 게임 개발자 (Third Helix), 실무자 관점
- 2014년 게시 후 12년간 표준으로 자리잡음, 반박 없음
- Unity / Unreal / Godot 모든 주요 엔진이 이 가이드라인을 InputSystem 디폴트로 채택

## Limitations

- 2014 시점 — Steam Deck (2022), Hall-effect 스틱 (2023+) 등장 전. Hardware drift floor 가이드 부족.
- Schmitt trigger / hysteresis 직접 다루지 않음 — 보완 출처 필요 (Unity InputSystem docs).
- Sector quantization (snap-to-N) 직접 다루지 않음 — JoyShockMapper 등 별도 출처.

## Related

- [[Analog Stick To 8-Way Quantization]] — Echo 적용 페이지
- [[Research 8-Way Aim Usability For Run-and-Gun]] — 부모 리서치
