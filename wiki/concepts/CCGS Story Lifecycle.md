---
title: CCGS Story Lifecycle
tags: [concept, ccgs, workflow, story, sprint, production]
aliases: [Story Lifecycle, CCGS Story Flow, story-readiness]
created: 2026-05-12
updated: 2026-05-12
---

# CCGS Story Lifecycle

Phase 5 Production의 핵심 반복 단위. 스토리 하나가 픽업에서 완료까지 거치는 공식 3단계 루프.

## 사이클 다이어그램

```
/story-readiness → 구현 → /story-done → 다음 스토리
       ↓               ↓           ↓
  READY/BLOCKED   에이전트 라우팅  8단계 리뷰
```

## 단계 1: Story Readiness

```
/story-readiness production/stories/[story].md
```

**검사 항목**:
- 디자인 완성도 (GDD 섹션 누락 없음)
- 아키텍처 커버리지 (ADR 참조 유효성)
- ADR 상태 — Proposed ADR 참조 시 자동 BLOCKED
- Control Manifest 버전 (구버전이면 경고)
- 스코프 명확성

**판정**: `READY` / `NEEDS WORK` / `BLOCKED`

## 단계 2: 구현

에이전트 라우팅 규칙:

| 코드 영역 | 에이전트 |
|---|---|
| 게임플레이 시스템 | `gameplay-programmer` |
| 엔진 코어 | `engine-programmer` |
| AI 행동 | `ai-programmer` |
| 멀티플레이어 | `network-programmer` |
| UI | `ui-programmer` |
| 개발 툴 | `tools-programmer` |

모든 에이전트 협업 패턴: 디자인 문서 읽기 → 질문 → 구조 옵션 제시 → 승인 → 구현.

`/dev-story [story-path]` — 올바른 프로그래머 에이전트로 자동 라우팅.

## 단계 3: Story Done

```
/story-done production/stories/[story].md
```

**8단계 완료 리뷰**:

| 단계 | 내용 |
|---|---|
| 1 | 스토리 파일 읽기 |
| 2 | 참조 GDD · ADR · Control Manifest 로드 |
| 3 | 수락 기준 검증 (자동 체크 / 수동 / 유예 분류) |
| 4 | GDD/ADR 편차 체크 (BLOCKING / ADVISORY / OUT OF SCOPE) |
| 5 | 코드 리뷰 요청 |
| 6 | 완료 보고서 생성 (COMPLETE / COMPLETE WITH NOTES / BLOCKED) |
| 7 | 스토리 `Status: Complete` + 완료 노트 업데이트 |
| 8 | 다음 READY 스토리 표시 |

테크 부채 발견 시 → `docs/tech-debt-register.md` 자동 기록.

## 스프린트 루프

스토리 사이클을 감싸는 스프린트 단위:

```
/sprint-plan new
  ↓
(story 반복: readiness → 구현 → done)
  ↓
/sprint-status  ← 언제든 30줄 진도 확인
/scope-check    ← 스코프 증가 감지 시
  ↓
/retrospective  ← 스프린트 종료 시
  ↓
/sprint-plan new (다음 스프린트)
```

**기계 가독 트래커**: `production/sprint-status.yaml`
- `/sprint-plan` 이 초기화
- `/story-done` 이 상태 업데이트
- `/sprint-status` · `/help` · `/story-done`(다음 스토리)이 읽음

## 스토리 파일 구조

각 스토리 파일이 임베드하는 핵심 요소:

| 요소 | 방식 | 이유 |
|---|---|---|
| GDD 요건 참조 | TR-ID (인용문 아님) | GDD 변경 시 자동 최신 유지 |
| ADR 참조 | Accepted ADR만 | Proposed → `Status: Blocked` |
| Control Manifest 버전 | 날짜 임베드 | 구버전 탐지 게이트 |
| 엔진별 구현 노트 | 직접 기재 | 에이전트 라우팅 힌트 |
| 수락 기준 | GDD 연동 | `/story-done` 검증 기반 |

## 에픽/스토리 생성 순서

```
/create-epics layer: foundation   # GDD+ADR → 에픽 (아키텍처 모듈 단위)
/create-stories [epic-slug]       # 에픽 → 스토리 파일
/create-epics layer: core
/create-stories [epic-slug]
```

`/estimate [story-path]` — 착수 전 노력·위험 추정.

## 관련 페이지

- [[CCGS 7-Phase Development Pipeline]] — Phase 5 컨텍스트
- [[CCGS Team Orchestration Skills]] — 복수 도메인 기능 시 팀 스킬로 전환
- [[CCGS Workflow Guide]] — 전체 참조 소스
- [[CCGS Framework]] — 에이전트·스킬·훅 기본 구조
