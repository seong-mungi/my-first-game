---
type: source
title: CCGS Reverse Document Workflow Example
source_url: https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/docs/examples/reverse-document-workflow-example.md
source_type: upstream-doc
fetched: 2026-05-08
created: 2026-05-08
updated: 2026-05-08
tags:
  - ccgs
  - reverse-document
  - brownfield
  - workflow
  - upstream-doc
  - documentation-from-code
related:
  - "[[Donchitos CCGS Repo]]"
  - "[[CCGS Framework]]"
  - "[[Brownfield Project Onboarding]]"
  - "[[Research CCGS Brownfield Onboarding]]"
  - "[[CCGS Adopt Brownfield Example]]"
key_claims:
  - "/reverse-document 스킬은 4-Stage 워크플로(코드 분석 → 의도 발견 → 비전 정렬 → 문서 생성)로 동작한다"
  - "Game-Designer 에이전트가 워크플로의 메인 액터 — 단순 코드 기술이 아니라 *의도 질문*을 던지는 것이 핵심"
  - "산출물은 design/gdd/[system].md에 작성되며, [REVERSE-DOCUMENTED FROM IMPLEMENTATION] 태그와 후속 TODO가 포함된다"
  - "구현된 코드와 의도된 디자인이 다를 수 있음을 전제 — 사용자 응답으로 차이를 표면화하고 의도 측을 우선"
  - "후속 작업으로 밸런스 검증, ADR 작성, 튜토리얼 갱신을 자동 식별·플래깅한다"
  - "기존 코드 위치(예: src/gameplay/skills/, assets/data/skills/)를 GDD 본문에 명시적으로 참조"
confidence: high
---

# CCGS Reverse Document Workflow Example

## 출처

CCGS 업스트림 저장소의 `docs/examples/reverse-document-workflow-example.md` 공식 예제. 이 문서는 v1.0.0-beta 시점에 `/reverse-document` 스킬을 사용해 약 1200라인의 스킬 트리 구현 코드로부터 GDD를 역생성하는 프로세스를 단계별로 설명한다. (Source URL: https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/docs/examples/reverse-document-workflow-example.md)

## 4-Stage 워크플로

| Stage | 역할 | 행위자 | 핵심 활동 |
|---|---|---|---|
| **1. Code Analysis** | 구현 구조 파악 | game-designer | 코드 스캔 → 패턴 식별 (예: "3 skill trees: Combat/Survival/Tech, 5 tiers each, 45 total skills") |
| **2. Intent Discovery** | 설계 의도 추출 | game-designer | 사용자에게 *결정 근거* 질문 (단순 기술이 아님) |
| **3. Vision Alignment** | 의도 vs 구현 차이 발견 | 사용자 + game-designer | 사용자 응답으로 차이 표면화·해소 |
| **4. Documentation Generation** | GDD 산출 | game-designer | 8-section GDD 작성 + 출처 코드 참조 + TODO 항목 |

## Stage 2의 질문 유형 (예시 세션)

`/reverse-document`의 핵심은 코드 표면을 기술하지 않고 **숨은 디자인 결정**을 묻는 것이다. 예시 세션에서 던진 질문:

- **아키타입 vs 플레이스타일 유연성**: 스킬 트리는 캐릭터 아키타입(전사·도적·법사) 표현인가, 자유 빌드 유연성 보장인가?
- **리스펙 비용의 경제 목적**: 리스펙 비용은 실험 *장려*인가 *억제*인가?
- **시너지 의도 여부**: 트리 간 시너지가 의도된 기능인가, 부작용인가?
- **후반부 파워 커브 철학**: tier-5 보너스가 어떤 밸런스 철학을 따르는가?

## Stage 3에서 발견된 의도 vs 구현 차이 (예시)

| 항목 | 구현 | 의도 | 결과 |
|---|---|---|---|
| 리스펙 비용 | 실험 억제 (가파른 비용 증가) | 실험 장려 | TODO: 비용 곡선 완화 |
| Tier-5 보너스 | +50% 데미지 | +30% 데미지 | TODO: 다음 패치에 조정 |

→ 차이는 **GDD에 의도 측으로 기록**되고, 구현 수정은 TODO로 분리된다. 이는 "현재 코드가 정답"이라는 가정을 깨고, **GDD가 진실의 원천(source of truth)**임을 강제한다.

## Stage 4 산출물 구조

**파일 경로**: `design/gdd/[system].md` (예: `design/gdd/skill-system.md`)

**필수 8 섹션** (CCGS 표준 GDD 템플릿):

1. Overview
2. Player Fantasy
3. Detailed Design
4. Design Pillars
5. Balance Framework
6. Edge Cases
7. Acceptance Criteria
8. Tuning Knobs (또는 Dependencies)

**필수 마킹**:
- 문서 헤더에 `[REVERSE-DOCUMENTED FROM IMPLEMENTATION]` 태그
- 출처 코드 위치 명시: 예시 세션은 `src/gameplay/skills/` + `assets/data/skills/` 참조
- 후속 작업 TODO 목록

## 후속 작업 자동 식별 (Stage 4 직후)

`/reverse-document`는 GDD 작성으로 끝나지 않고, 이어져야 할 작업을 플래깅한다:

| 후속 작업 | 트리거 |
|---|---|
| 밸런스 검증 | Stage 3에서 의도 vs 구현 수치 차이 발견 시 |
| ADR(Architecture Decision Record) 작성 | 코드에서 발견된 비자명한 결정에 대해 `/architecture-decision` 호출 |
| 튜토리얼 갱신 | 시너지 등 플레이어가 이해해야 할 메카닉이 있을 때 |
| 스토리 생성 | 의도 vs 구현 차이를 좁히는 작업을 `/create-stories`로 백로그에 등록 |

## /adopt와의 관계

[[CCGS Adopt Brownfield Example]]의 7-Step Migration Plan에서 **Step 5**가 `/reverse-document` + `/architecture-decision` 조합이다:

```
Step 5: Create architecture ADRs from existing code
        → /reverse-document + /architecture-decision
        → Captures decisions already made in code
```

즉 `/reverse-document`는 `/adopt`의 하위 컴포넌트로 사용되며, 단독으로도 호출 가능하다. `/adopt`는 전체 브라운필드 온보딩 오케스트레이션, `/reverse-document`는 그 중 코드→문서 변환 단일 단계.

## 핵심 원칙

> [!key-insight] /reverse-document의 본질
> 단순 코드 기술이 아니라, **암묵적 설계 결정의 명시화**다. "이 코드가 무엇을 하는가"가 아니라 "왜 이렇게 했는가"를 묻는다. 사용자만이 답할 수 있는 질문 → 코드가 잊고 있던 의도가 GDD로 결정화된다.

## See Also

- [[Brownfield Project Onboarding]] — 이 워크플로가 통합되는 4-Phase 절차
- [[CCGS Adopt Brownfield Example]] — `/reverse-document`를 호출하는 상위 워크플로
- [[Research CCGS Brownfield Onboarding]] — 이 소스로 보완된 합성 페이지
