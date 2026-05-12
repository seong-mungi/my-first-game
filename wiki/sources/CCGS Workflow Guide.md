---
title: CCGS Workflow Guide
tags: [source, ccgs, workflow, pipeline, game-development]
aliases: [CCGS Workflow, CCGS Complete Workflow]
created: 2026-05-12
updated: 2026-05-12
---

# CCGS Workflow Guide — 7-Phase Pipeline Reference

**Source:** `docs/WORKFLOW-GUIDE.md` (project-local, canonical)
**Type:** 내부 워크플로 문서
**Confidence:** High

## 개요

CCGS 게임 개발 전체 워크플로를 7-Phase + 공식 게이트 체계로 정의하는 권위 문서. 48 에이전트, 66 슬래시 커맨드, 12 훅의 사용 순서와 협업 프로토콜을 포괄한다.

> [!key-insight] 커맨드 수 주의
> 도입부는 "68 slash commands"라고 표기하지만 Appendix B 실제 집계는 **66개**. 66이 정확한 수치.

## 7-Phase 구조 요약

| Phase | 이름 | 핵심 산출물 | 게이트 커맨드 |
|---|---|---|---|
| 1 | Concept | game-concept.md · systems-index.md | `/gate-check concept` |
| 2 | Systems Design | 전체 GDD · cross-GDD 리뷰 보고서 | `/gate-check systems-design` |
| 3 | Technical Setup | architecture.md · ADR 3+개 · control-manifest.md | `/gate-check technical-setup` |
| 4 | Pre-Production | UX 스펙 · 프로토타입 · 스토리 · Sprint #1 · Vertical Slice | `/gate-check pre-production` |
| 5 | Production | 스프린트 반복 (readiness → implement → done) | `/gate-check production` |
| 6 | Polish | 퍼포먼스 · 밸런스 · 플레이테스트 3회 · 팀-폴리시 | `/gate-check polish` |
| 7 | Release | 릴리스 체크리스트 · Go/No-Go · 배포 | — (ship) |

→ [[CCGS 7-Phase Development Pipeline]]

## 슬래시 커맨드 카탈로그 (66개)

카테고리별 분포:

| 카테고리 | 수 | 대표 커맨드 |
|---|---|---|
| 온보딩/탐색 | 5 | `/start` `/help` `/project-stage-detect` |
| 게임 디자인 | 6 | `/brainstorm` `/map-systems` `/design-system` `/review-all-gdds` |
| UX | 2 | `/ux-design` `/ux-review` |
| 아키텍처 | 4 | `/create-architecture` `/architecture-decision` `/architecture-review` `/create-control-manifest` |
| 스토리/스프린트 | 8 | `/create-epics` `/create-stories` `/dev-story` `/sprint-plan` `/story-readiness` `/story-done` |
| 리뷰/분석 | 10 | `/design-review` `/code-review` `/balance-check` `/gate-check` |
| QA/테스팅 | 9 | `/qa-plan` `/smoke-check` `/regression-suite` `/test-setup` `/skill-test` |
| 프로덕션 관리 | 6 | `/milestone-review` `/retrospective` `/bug-report` `/playtest-report` |
| 릴리스 | 5 | `/release-checklist` `/launch-checklist` `/changelog` `/patch-notes` `/hotfix` |
| 크리에이티브 | 2 | `/prototype` `/localize` |
| 팀 조율 | 9 | `/team-combat` `/team-narrative` `/team-ui` `/team-level` `/team-audio` `/team-polish` `/team-release` `/team-live-ops` `/team-qa` |

→ [[CCGS Team Orchestration Skills]]

## 협업 프로토콜

**Question → Options → Decision → Draft → Approval → Write**

- 모든 에이전트는 파일 쓰기 전 반드시 승인 요청 ("May I write this to [filepath]?")
- `AskUserQuestion` 도구: Explain then Capture (전체 분석 → 깔끔한 UI 피커)
- 자율 실행 금지 — 결정 권한은 항상 사용자

## 리뷰 모드 시스템

`production/review-mode.txt`에 저장. `/start` 시 1회 설정.

| 모드 | 실행 범위 | 적합 상황 |
|---|---|---|
| `full` | 모든 Director 게이트 매 단계 | 신규 프로젝트, 시스템 학습 |
| `lean` | 페이즈 전환 시에만 (`/gate-check`) | 경험 있는 개발자 |
| `solo` | Director 리뷰 없음 | 게임잼, 프로토타입, 최고 속도 |

`--review full/lean/solo` 플래그로 1회성 오버라이드 가능 (글로벌 설정 유지).

## 주요 파일 경로 참조

| 목적 | 경로 |
|---|---|
| 세션 상태 | `production/session-state/active.md` |
| 스프린트 트래커 | `production/sprint-status.yaml` |
| 스테이지 파일 | `production/stage.txt` |
| 리뷰 모드 | `production/review-mode.txt` |
| 아키텍처 | `docs/architecture/architecture.md` |
| Control Manifest | `docs/architecture/control-manifest.md` |
| TR Registry | `docs/architecture/tr-registry.yaml` |
| 협업 프로토콜 | `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` |
| 기술 결정 로그 | `docs/tech-debt-register.md` |
| 게이트 정의 | `.claude/docs/director-gates.md` |

## 브라운필드 적용 (기존 프로젝트)

```
/adopt             # 전체 감사 + 마이그레이션 계획
/adopt gdds        # GDD 갭만
/adopt adrs        # ADR 갭만
/adopt stories     # 스토리 갭만
/adopt infra       # 인프라 갭만
```

원칙: MIGRATION not REPLACEMENT — 기존 작업 재생성 없이 갭만 채운다.

개별 스킬 레트로핏 모드:
```
/design-system retrofit design/gdd/combat-system.md
/architecture-decision retrofit docs/architecture/adr-005.md
```

## 컨텍스트 복원 전략

- **세션 상태 파일** `production/session-state/active.md` — 주요 마일스톤마다 업데이트
- **증분 파일 쓰기** — 섹션 승인 즉시 파일에 기록 → 크래시/컴팩션 생존
- **자동 복원** — `session-start.sh` 훅이 `active.md`를 자동 감지·미리보기

## 관련 페이지

- [[CCGS Framework]] — 에이전트·스킬·훅 기본 구조
- [[CCGS 7-Phase Development Pipeline]] — 페이즈 상세 + 게이트 요건
- [[CCGS Story Lifecycle]] — readiness → 구현 → done 사이클
- [[CCGS Team Orchestration Skills]] — 9개 팀 스킬 6단계 파이프라인
- [[CCGS Scaffolder Scope Boundary]] — CCGS가 하는 것 vs 안 하는 것
- [[CCGS Subagent Tier Architecture]] — 3-Tier 계층 구조
