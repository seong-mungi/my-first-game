---
title: Godot Analytics Stack
tags: [concept, analytics, telemetry, godot, indie-dev]
aliases: [Game Analytics Godot, Talo GameAnalytics]
created: 2026-05-12
updated: 2026-05-12
---

# Godot 애널리틱스 스택

Godot 4.x 프로젝트에서 플레이어 행동 텔레메트리를 수집·시각화하기 위한 툴 선택 가이드.

## 핵심 툴 두 가지

### Talo (개발 중 권장)

- **유형:** 오픈소스 게임 애널리틱스. Godot + Unity 네이티브 플러그인 제공.
- **기능:** 이벤트 트래킹, 플레이어 통계, 실시간 대시보드, 플레이어 세그먼트
- **비용:** 무료 (오픈소스, 셀프호스팅 가능)
- **Godot 통합:** Asset Library 등록 (asset #2936). 낮은 통합 복잡도.
- **적합 시점:** 알파/베타 내부 테스트 ~ 얼리 액세스
- Source: trytalo.com + Godot Asset Library (high, 2025)

### GameAnalytics (론치 후 권장)

- **유형:** 게임 특화 무료 입문 애널리틱스 플랫폼
- **기능:** 리텐션, 퍼널, 코호트, 진행률 분석. 게임 전용 설계.
- **비용:** 무료 (입문 티어). 데이터 엔지니어링 불필요.
- **적합 시점:** 스팀 론치 후 플레이어 텔레메트리
- Source: ThinkingData, Keewano, Mitzu 복수 독립 출처 (high, 2025-2026)

## 보조 툴

| 툴 | 용도 | 비용 | 확인 |
|---|---|---|---|
| Godotlitics | 경량 셀프호스팅 C# 애널리틱스 | 무료 | Asset Library 등록 (medium) |
| Godot Analytics (Titang Studio) | PostHog 연동 플러그인 | 무료 | itch.io (medium) |
| Amplitude | A/B 테스트 + 코호트 분석 | 유료 | 업계 표준 (high) |
| Mixpanel | 이벤트 기반 퍼널 분석 | 유료 | 게임 복잡도 한계 있음 (medium) |

## Echo 적용 권고

1. **즉시:** 이벤트 택소노미 설계 (CCGS analytics-engineer 에이전트 활용)
2. **스프린트 3+:** Talo SDK를 Godot 소스에 통합 → 개발 중 이벤트 수집 시작
3. **론치 전:** GameAnalytics 대시보드 연결 → 플레이어 리텐션 모니터링

> [!key-insight] CCGS analytics-engineer 에이전트는 이벤트 스펙을 설계하지만 SDK 통합 코드는 쓰지 않는다. Talo SDK는 개발자가 직접 Godot 소스에 추가해야 한다.

## CCGS와의 관계

CCGS `analytics-engineer` 에이전트 → 이벤트 택소노미, 퍼널 스펙, A/B 테스트 설계 문서 생성.
실제 파이프라인 = SDK + 백엔드 + 대시보드 (모두 CCGS 외부).

## Sources

- trytalo.com + Godot Asset Library #2936 (high, 2025)
- ThinkingData.io, Keewano.com, Mitzu.io (high, 2025-2026)
- Amplitude 공식 문서 (high)
