---
type: concept
title: CCGS Framework
created: 2026-05-08
updated: 2026-05-08
tags:
  - ccgs
  - ai-agents
  - framework
  - game-development
  - claude-code
related:
  - "[[Donchitos CCGS Repo]]"
  - "[[CCGS Subagent Tier Architecture]]"
  - "[[Brownfield Project Onboarding]]"
  - "[[Research CCGS Framework And Local Drift]]"
  - "[[GitHub Donchitos Claude Code Game Studios]]"
confidence: high
---

# CCGS Framework

## 정의

**Claude Code Game Studios (CCGS)**는 Claude Code를 48-49개의 협업 AI 서브에이전트로 구성된 인디 게임 스튜디오로 변환하는 오픈소스 프레임워크다. Donchitos가 제작하고 MIT 라이선스로 배포한다. 각 에이전트는 실제 게임 스튜디오의 직군(크리에이티브 디렉터, 기술 감독, 게임플레이 프로그래머, QA 등)을 거울처럼 반영하며, 도메인 분리와 품질 게이트를 강제한다.

(Source: [[GitHub Donchitos Claude Code Game Studios]])

## 핵심 구성 요소

### 1. 에이전트 (49개)
`.claude/agents/` 디렉터리에 마크다운으로 정의된 전문 역할 에이전트.

| 레이어 | 에이전트 예시 |
|---|---|
| 리더십 | creative-director, technical-director, producer |
| 프로그래밍 | lead-programmer, gameplay-programmer, ai-programmer |
| Godot 전문 | godot-specialist, godot-gdscript-specialist, godot-shader-specialist |
| Unity 전문 | unity-specialist, unity-dots-specialist, unity-addressables-specialist |
| Unreal 전문 | unreal-specialist, ue-blueprint-specialist, ue-gas-specialist |
| 디자인 | game-designer, systems-designer, level-designer, ux-designer |
| 생산 관리 | qa-lead, release-manager, analytics-engineer |

### 2. 스킬 (72개)
`.claude/skills/` 디렉터리의 `/` 슬래시 명령어. 각 스킬은 `SKILL.md`로 정의됨.

**단계별 워크플로 스킬:**
- `/start` — 프로젝트 온보딩
- `/setup-engine` — 엔진 설정
- `/brainstorm`, `/quick-design`, `/prototype` — 아이디어 단계
- `/create-epics`, `/create-stories`, `/sprint-plan` — 생산 계획
- `/dev-story`, `/code-review`, `/story-done` — 구현 사이클
- `/gate-check`, `/release-checklist`, `/launch-checklist` — 릴리스 게이트

**팀 조율 스킬:**
- `/team-combat`, `/team-ui`, `/team-narrative`, `/team-audio` 등 — 특정 부서 병렬 서브에이전트 실행

### 3. 훅 (12개)
`.claude/hooks/` 의 셸 스크립트로 자동화된 품질 게이트 구현:

| 훅 | 역할 |
|---|---|
| `session-start.sh` | 세션 시작 시 active.md 미리보기 |
| `session-stop.sh` | 세션 종료 로그 |
| `validate-commit.sh` | 커밋 전 코드 품질 검사 |
| `validate-push.sh` | 푸시 전 테스트 게이트 |
| `detect-gaps.sh` | 설정 미완료 슬롯 탐지 |
| `log-agent.sh` / `log-agent-stop.sh` | 에이전트 감사 추적 |
| `pre-compact.sh` / `post-compact.sh` | 컴팩션 전후 처리 |

### 4. 협업 프로토콜
모든 에이전트는 **Question → Options → Decision → Draft → Approval** 사이클을 따른다. 파일 쓰기 전 반드시 승인 요청. 자율 실행 금지.

## 모델 티어 배정

| 티어 | 모델 | 사용 시점 |
|---|---|---|
| Haiku | claude-haiku-4-5-20251001 | 상태 조회, 포맷팅, 단순 조회 |
| Sonnet | claude-sonnet-4-6 | 구현, 설계, 단일 시스템 분석 |
| Opus | claude-opus-4-6 | 다문서 종합, 고위험 게이트 판정 |

## 강점

- 실제 스튜디오 계층 구조를 그대로 반영한 에이전트 설계
- 72개 스킬로 전체 개발 생명주기(Concept → Release) 커버
- MIT 라이선스, GitHub Template으로 즉시 포크 가능
- 훅 기반 자동화로 품질 게이트 강제

## 약점 / 주의사항

- 단일 기여자 (버스 팩터 1) — 장기 유지보수 불확실
- 실제 완성 게임 사례 미공개 (이슈 #34)
- `[TO BE CONFIGURED]` 슬롯이 많아 초기 설정 비용이 높음
- 브라운필드(기존 코드베이스) 온보딩 절차가 명시적으로 문서화되어 있지 않음

> [!gap] 미확인 사항
> CCGS로 실제 출시된 게임 사례가 있는지 확인되지 않음.
> 브라운필드 온보딩 공식 가이드 존재 여부 불명확.

## 7-Phase 워크플로

CCGS는 7개 페이즈 + 공식 게이트(`/gate-check`) 구조로 전체 개발 생명주기를 커버한다.

- [[CCGS 7-Phase Development Pipeline]] — 페이즈별 게이트 요건 상세
- [[CCGS Story Lifecycle]] — Phase 5 스토리 사이클 (readiness → 구현 → done)
- [[CCGS Team Orchestration Skills]] — 9개 팀 스킬 6단계 파이프라인
- [[CCGS Workflow Guide]] — 워크플로 전체 참조 소스 (`docs/WORKFLOW-GUIDE.md`)

## 관련 페이지

- [[Donchitos CCGS Repo]]
- [[CCGS Subagent Tier Architecture]]
- [[Brownfield Project Onboarding]]
- [[Research CCGS Framework And Local Drift]]
- [[GitHub Donchitos Claude Code Game Studios]]
