---
title: Research CCGS Implementation Gap Full Stack
tags: [synthesis, ccgs, toolchain, indie-dev, godot]
aliases: [CCGS Gap Analysis, CCGS Full Stack]
created: 2026-05-12
updated: 2026-05-12
---

# CCGS Implementation Gap — Full Stack Catalog

**Research date:** 2026-05-12 · 2 parallel agents · ~25 web searches · 9 wiki pages

CCGS (Claude Code Game Studios)는 **프로세스·조정 레이어**만 제공한다. GDD 작성, ADR, 스프린트 플랜, 코드 리뷰 가이드, QA 플랜 등이 CCGS 산출물 전부다. 실제 구현을 위한 툴체인은 별도로 선택·통합해야 한다.

## CCGS가 실제로 제공하는 것

| 산출물 | 설명 |
|---|---|
| 49개 에이전트 정의 | 도메인별 전문 AI 에이전트 |
| 72개 슬래시 커맨드 스킬 | GDD 작성, 아키텍처 리뷰, 릴리즈 체크리스트 등 |
| 12개 훅 스크립트 | 커밋 위생, JSON 검증 |
| 39개 문서 템플릿 | 설계 문서, ADR, 테스트 계획 |

**CCGS가 제공하지 않는 것:** 에셋 제작, 오디오 저작, CI/CD 파이프라인 파일, 텔레메트리 인프라, Steamworks 통합, 커뮤니티 플랫폼 설정.

> [!key-insight] CCGS는 "무엇을 만들지·어떻게 만들지·잘 만들었는지"를 다룬다. "실제로 만드는" 툴은 전부 외부에 있다.

## 갭 매트릭스 — 레이어별 필요 툴

| 레이어         | CCGS 제공      | 별도 필요                                     |
| ----------- | ------------ | ----------------------------------------- |
| 아트 제작       | 에셋 스펙 문서     | Aseprite, Krita                           |
| 오디오 제작      | 오디오 디자인 스펙   | DAW, FMOD / Wwise / Godot 내장              |
| 테스트 실행      | GUT 호출 가이드   | GitHub Actions YAML, GUT/gdUnit4 러너       |
| CI/CD 파이프라인 | 릴리즈 체크리스트 문서 | GitHub Actions 워크플로 파일, SteamCMD          |
| 텔레메트리 수집    | 이벤트 택소노미 설계  | Talo 또는 GameAnalytics SDK (Godot 소스 내 통합) |
| 애널리틱스 대시보드  | 퍼널·메트릭 스펙    | GameAnalytics 대시보드, Amplitude             |
| A/B 테스트     | 테스트 설계 문서    | Amplitude Experimentation, Mixpanel       |
| 퍼블리싱        | 런치 체크리스트     | Steamworks SDK, SteamCMD, itch.io         |
| 커뮤니티        | 커뮤니티 전략 문서   | Discord, Steam 커뮤니티 허브                    |

## 세부 레이어별 권고

- **아트:** → [[Godot Art Pipeline Tools]]
- **오디오:** → [[Godot Audio Middleware Decision]]
- **테스트/CI:** → [[Godot CI CD Pipeline Pattern]]
- **애널리틱스:** → [[Godot Analytics Stack]]
- **퍼블리싱:** → [[Indie Game Publishing Pipeline]]
- **커뮤니티:** → [[Indie Game Community Platform Stack]]

## CCGS 커뮤니티 갭 인식

CCGS 갭이 충분히 크다는 인식은 커뮤니티에서도 확인됨:
- `CCGS: Technica Edition` (fork) — "Go-To-Market Layer, Post-Launch Lifecycle, Continuity" 레이어 추가 목적으로 분기 생성 (2026).
- Source: GitHub `FreedomPortal/ccgs-technica-edition` (confidence: high)

## Sources

- GitHub `Donchitos/Claude-Code-Game-Studios` README (primary, high)
- GitHub `FreedomPortal/ccgs-technica-edition` (high, 2026)
- Project `technical-preferences.md` (primary source)
