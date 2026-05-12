---
title: CCGS Team Orchestration Skills
tags: [concept, ccgs, workflow, team, orchestration, multi-agent]
aliases: [Team Skills, CCGS Team Pipeline, team-combat]
created: 2026-05-12
updated: 2026-05-12
---

# CCGS Team Orchestration Skills

복수 도메인에 걸친 기능을 구현할 때 사용하는 CCGS 팀 스킬. 6단계 협업 워크플로로 여러 전문 에이전트를 병렬 조율한다.

## 9개 팀 스킬

| 스킬 | 조율 내용 | 페이즈 |
|---|---|---|
| `/team-combat` | 전투 기능: 디자인 → 구현 완료 | 5 |
| `/team-narrative` | 내러티브: 구조 → 대화 | 5 |
| `/team-ui` | UI: UX 스펙 → 완성 구현 | 5 |
| `/team-level` | 레벨: 레이아웃 → 배치 완료 | 5 |
| `/team-audio` | 오디오: 방향 → 구현 이벤트 | 5-6 |
| `/team-polish` | 폴리시: 퍼포먼스 + 아트 + 오디오 + QA | 6 |
| `/team-release` | 릴리스: 빌드 + QA + 배포 | 7 |
| `/team-live-ops` | 라이브 옵스: 시즌 이벤트 · 배틀패스 · 리텐션 | 7+ |
| `/team-qa` | 전체 QA: 전략 · 실행 · 커버리지 · 승인 | 6-7 |

## 6단계 공동 파이프라인

모든 팀 스킬이 공유하는 구조:

| 단계 | 담당 에이전트 | 내용 |
|---|---|---|
| 1 Design | `game-designer` | 질문 → 옵션 제시 |
| 2 Architecture | `lead-programmer` | 코드 구조 제안 |
| 3 병렬 구현 | 전문 에이전트들 | 동시 독립 작업 |
| 4 Integration | `gameplay-programmer` | 전체 통합 |
| 5 Validation | `qa-tester` | 수락 기준 검증 |
| 6 Report | 조율자 | 상태 요약 |

> [!key-insight] 결정 지점은 항상 사용자 확인
> 오케스트레이션은 자동화되지만 디자인 선택, 아키텍처 결정, 통합 충돌 해소는 반드시 사용자가 승인한다.

## `/team-polish` 상세 (Phase 6)

4 전문가 병렬 수행:

| 담당 | 에이전트 |
|---|---|
| 퍼포먼스 최적화 | `performance-analyst` |
| 비주얼 폴리시 | `technical-artist` |
| 오디오 폴리시 | `sound-designer` |
| 게임 느낌/주스 | `gameplay-programmer` + `technical-artist` |

## `/team-release` 상세 (Phase 7)

`release-manager` + QA + DevOps 조율:

1. 사전 출시 검증
2. 빌드 관리
3. 최종 QA 승인
4. 배포 준비
5. Go/No-Go 결정

## 언제 팀 스킬 vs 단일 에이전트를 사용할까

| 상황 | 권고 |
|---|---|
| 4개 이상 도메인에 걸친 기능 | 팀 스킬 |
| 단일 시스템 단독 작업 | 해당 에이전트 직접 호출 |
| 수동으로 여러 에이전트 조율 | ❌ — 팀 스킬이 조율 담당 |

## 관련 페이지

- [[CCGS 7-Phase Development Pipeline]] — 팀 스킬 사용 페이즈 컨텍스트
- [[CCGS Story Lifecycle]] — 단일 스토리 사이클 (팀 스킬이 내부적으로 활용)
- [[CCGS Workflow Guide]] — 전체 참조 소스
- [[CCGS Framework]] — 에이전트·스킬·훅 기본 구조
