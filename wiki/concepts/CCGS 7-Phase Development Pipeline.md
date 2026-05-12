---
title: CCGS 7-Phase Development Pipeline
tags: [concept, ccgs, workflow, pipeline, gate-check]
aliases: [CCGS Pipeline, CCGS Phases, CCGS 7단계]
created: 2026-05-12
updated: 2026-05-12
---

# CCGS 7-Phase Development Pipeline

CCGS 전체 개발 워크플로를 7개 페이즈로 구분하고, 각 전환에 공식 게이트(`/gate-check`)를 배치한다. 게이트 통과 시에만 `production/stage.txt`가 업데이트되어 다음 페이즈로 진입한다.

## 페이즈 흐름

```
Concept → Systems Design → Technical Setup → Pre-Production → Production → Polish → Release
   ↓            ↓               ↓                ↓              ↓           ↓
gate-check  gate-check     gate-check        gate-check     gate-check  gate-check
 concept   systems-design technical-setup  pre-production  production    polish
```

## Phase 1: Concept

**목표**: "무엇을 만들까?"에서 "어떤 시스템이 필요한가?"까지.

| 스킬 | 산출물 |
|---|---|
| `/brainstorm` | `design/gdd/game-concept.md` (MDA + 필러 + USP + 안티-필러) |
| `/design-review game-concept.md` | 컨셉 검증 (선택이지만 권고) |
| `/setup-engine` | `.claude/docs/technical-preferences.md` + 엔진 버전 고정 |
| `/map-systems` | `design/gdd/systems-index.md` (의존성 · 우선순위 Tier · 설계 순서) |

**게이트 요건**: 엔진 설정 + `game-concept.md`(필러 포함) + `systems-index.md`(의존성 순서)

## Phase 2: Systems Design

**목표**: 코딩 없이 모든 MVP 시스템 GDD 작성 + 교차 검증.

순서: `/map-systems next` → `/design-system` → `/design-review` → (반복) → `/review-all-gdds`

**GDD 8개 필수 섹션**:

| # | 섹션 | 내용 |
|---|---|---|
| 1 | Overview | 시스템 한 단락 요약 |
| 2 | Player Fantasy | 플레이어가 느끼는 감각·경험 |
| 3 | Detailed Rules | 모호함 없는 규칙 |
| 4 | Formulas | 모든 계산식 + 변수 정의 |
| 5 | Edge Cases | 이상 상황 명시적 해결 |
| 6 | Dependencies | 양방향 시스템 연결 |
| 7 | Tuning Knobs | 조정 가능한 값과 안전 범위 |
| 8 | Acceptance Criteria | 측정 가능한 성공 조건 |

`/review-all-gdds` 2단계 분석:
- **Phase 1 (교차 일관성)**: 양방향 의존성·규칙 충돌·소유권 충돌·수식 범위 호환성
- **Phase 2 (설계 이론)**: 지배 전략·인지 부하·경제 루프 균형·필러 정합성

**게이트 요건**: MVP 시스템 전체 `Status: Approved` + cross-GDD 리뷰 PASS/CONCERNS

## Phase 3: Technical Setup

**목표**: 핵심 기술 결정을 ADR로 문서화 + 프로그래머용 Control Manifest 생성.

순서: `/create-architecture` → `/architecture-decision` (최소 3개) → `/architecture-review` → `/create-control-manifest`

추가 필수: `design/accessibility-requirements.md` — UX 스펙 전제조건이므로 Phase 3에서 작성.

ADR 라이프사이클: `Proposed` → `Accepted` → `Superseded/Deprecated`
- Proposed ADR를 참조하는 스토리 → 자동 `Status: Blocked`

**게이트 요건**: `architecture.md` + ADR 3+개 Accepted + 리뷰 완료 + `control-manifest.md` + `accessibility-requirements.md`

## Phase 4: Pre-Production

**목표**: UX 스펙 → 프로토타입 → 에픽/스토리 → 첫 스프린트 → Vertical Slice.

순서: `/ux-design` → `/ux-review` → `/prototype` → `/create-epics` → `/create-stories` → `/sprint-plan new`

> [!key-insight] 하드 게이트: Vertical Slice
> 실제 인간이 가이드 없이 3회 이상 플레이해야 통과. `/playtest-report` 없으면 `/gate-check`가 자동 FAIL.

**게이트 요건**: UX 스펙 1+개 + 리뷰 + 프로토타입 1+개(README 필수) + 스토리 파일 + 스프린트 계획 + 플레이테스트 리포트(3+회)

## Phase 5: Production

**목표**: 스프린트 반복으로 콘텐츠 완성.

핵심 사이클: `/story-readiness` → 구현 → `/story-done` → (다음 스토리)

→ [[CCGS Story Lifecycle]] (상세)

보조 도구:
- `/sprint-status` — 30줄 스냅샷
- `/scope-check` — 스코프 증가 탐지
- `/content-audit` — GDD 명세 vs 구현 갭 탐지
- `/propagate-design-change` — GDD 변경 후 영향 ADR/스토리 탐지
- `/milestone-review` — 마일스톤 체크포인트

→ [[CCGS Team Orchestration Skills]] (복수 도메인 기능)

**게이트 요건**: MVP 스토리 전체 완료 + 플레이테스트 3회(신규·중간·난이도 곡선) + 재미 가설 검증

## Phase 6: Polish

**목표**: 기능 완성 후 품질 향상.

파이프라인: `/perf-profile` → `/balance-check` → `/asset-audit` → `/playtest-report` (×3) → `/team-polish`

`/team-polish`는 4 전문가 병렬: 퍼포먼스(`performance-analyst`) + 비주얼(`technical-artist`) + 오디오(`sound-designer`) + 게임 느낌(`gameplay-programmer` + `technical-artist`)

**게이트 요건**: 플레이테스트 3+개 + `/team-polish` 완료 + 성능 블로커 없음 + 접근성 티어 충족

## Phase 7: Release

**목표**: 출시 준비 → 배포.

순서: `/release-checklist [버전]` → `/launch-checklist` (부서별 Go/No-Go) → `/team-release` → `git tag + push`

`/launch-checklist` 확인 부서: 엔지니어링·디자인·아트·오디오·QA·내러티브·현지화·접근성·스토어·마케팅·커뮤니티·인프라·법무

포스트-론치:
- `/hotfix "[이슈]"` — 긴급 패치 (hotfix 브랜치 자동 생성 + 개발 브랜치 백포트)
- 포스트모템: `.claude/docs/templates/post-mortem.md` 템플릿 사용

## 게이트 판정 체계

| 판정 | 의미 | 진행 가능 여부 |
|---|---|---|
| **PASS** | 모든 요건 충족 | ✅ |
| **CONCERNS** | 요건 충족 + 승인된 리스크 | ✅ (리스크 인지 후) |
| **FAIL** | 요건 미충족 + 구체적 처방 | ❌ |

게이트 통과 시에만 `production/stage.txt` 업데이트 → `/help` + 상태 표시줄 제어.

## 관련 페이지

- [[CCGS Workflow Guide]] — 전체 참조 소스
- [[CCGS Story Lifecycle]] — Phase 5 스토리 사이클 상세
- [[CCGS Team Orchestration Skills]] — Phase 5-6 팀 스킬
- [[CCGS Framework]] — 에이전트·스킬·훅 기본 구조
- [[CCGS Scaffolder Scope Boundary]] — CCGS 범위 경계
