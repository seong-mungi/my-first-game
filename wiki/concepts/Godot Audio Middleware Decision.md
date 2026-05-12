---
title: Godot Audio Middleware Decision
tags: [concept, audio, fmod, wwise, godot, middleware]
aliases: [FMOD Godot, Wwise Godot, Audio Middleware]
created: 2026-05-12
updated: 2026-05-12
---

# Godot 오디오 미들웨어 결정 가이드

Godot 내장 오디오 vs FMOD vs Wwise 선택 기준. Echo(run-and-gun + 시간 되감기) 맥락에서 분석.

## 세 가지 옵션 비교

| 항목 | Godot 내장 | FMOD | Wwise |
|---|---|---|---|
| 비용 | 무료 | 무료(매출 $200k 미만) | 무료(매출 $250k 미만) |
| Godot 통합 | 내장 | GDExtension (856 ⭐) | GDExtension (407 ⭐) |
| Godot 4.6 확인 | ✅ | 4.3 확인, 4.6 TBD | 4.3 확인, 4.6 TBD |
| 통합 복잡도 | 없음 | 높음 (2-3일 예산) | 높음 (3-5일 예산) |
| 인터랙티브 뮤직 | 제한적 | ✅ 풀 지원 | ✅ 풀 지원 |
| 학습 곡선 | 없음 | 중간 | 높음 |

## 결정 트리

```
게임플레이 상태(체력, 전투 긴장감, 시간 되감기)에 따라
오디오가 동적으로 반응해야 하는가?
  ├── YES → FMOD (Godot 커뮤니티 채택률 더 높음: 856 vs 407 ⭐)
  └── NO  → Godot 내장으로 충분
```

## Echo 특이점: 시간 되감기

시간 되감기 중 오디오 처리는 비표준 케이스:
- 되감기 시 BGM 역재생 or 전용 SFX 재생
- 되감기 상태에서 플레이어 SFX 억제

FMOD를 사용한다면 rewind 상태를 FMOD 파라미터로 노출 → 인터랙티브 뮤직 전환으로 처리 가능.
Godot 내장으로도 `AudioServer` + 상태 플래그로 구현 가능 (단, 인터랙티브 전환 품질은 낮음).

> [!key-insight] Echo 초기 스프린트에서는 Godot 내장으로 시작할 것. FMOD 전환 결정은 오디오 디자이너가 시간 되감기 사운드를 설계할 때 내리는 것이 적절하다.

## FMOD GDExtension 주의사항

- GitHub `utopia-rise/fmod-gdextension` (856 ⭐)
- FMOD Studio 2.02.25 + Godot 4.3 stable 확인
- Godot 4.6 호환성: GDExtension API 안정성으로 인해 동작 가능성 높으나 공식 확인 필요
- 설정 후 SoundBank baking 단계 필수

## CCGS와의 관계

CCGS `audio-director` 에이전트가 오디오 미들웨어 스펙을 작성함. 실제 FMOD Studio 설치·GDExtension 빌드·SoundBank 통합은 개발자 작업.

## Sources

- fmod-gdextension GitHub utopia-rise (856 ⭐, high, 2025)
- wwise-godot-integration GitHub alessandrofama (407 ⭐, high, 2024)
- Audiokinetic 블로그: Wwise 2024.1 for Godot (high, 2024)
- strayspark.studio: Wwise vs FMOD vs MetaSounds 2026 (high, 2026)
- thegameaudioco.com: Wwise or FMOD guide (high)
