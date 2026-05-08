---
type: source
title: CCGS Adopt SKILL Definition
source_url: file://.claude/skills/adopt/SKILL.md
source_type: local-skill-definition
fetched: 2026-05-08
created: 2026-05-08
updated: 2026-05-08
tags:
  - ccgs
  - adopt-skill
  - skill-definition
  - authoritative
  - upstream-doc
related:
  - "[[CCGS Framework]]"
  - "[[Brownfield Project Onboarding]]"
  - "[[CCGS Adopt Brownfield Example]]"
  - "[[CCGS Reverse Document Workflow Example]]"
  - "[[Donchitos CCGS Repo]]"
key_claims:
  - "/adopt 스킬은 technical-director 에이전트가 소유하며 user-invocable: true로 직접 호출 가능"
  - "argument-hint: '[focus: full | gdds | adrs | stories | infra]' — 5가지 감사 모드 (기본: full)"
  - "엔진 설정은 /adopt의 선결 조건이 아니다 — Phase 2f에서 자동 갭 검출 (Engine/Language/Rendering/Physics 미설정 시 HIGH, ADR 존재 시 BLOCKING)"
  - "fresh project (코드·GDD·ADR 모두 부재)는 /adopt가 작업을 거부하고 /start로 라우팅"
  - "Phase 1-7 워크플로 = State Detection → Format Audit → Gap Classification → Migration Plan → Summary → Write → First Action"
  - "갭 4단계: BLOCKING (스킬 silent 오작동) / HIGH (안전성 손상) / MEDIUM (품질 저하) / LOW (선택)"
  - "Phase 6b에서 production/review-mode.txt를 Full / Lean / Solo 중 선택해 작성"
  - "Phase 7에서 가장 시급한 1개 갭에 대한 즉시 처리 옵션을 사용자에게 제시 (한 번에 한 액션 원칙)"
confidence: high
---

# CCGS Adopt SKILL Definition

## 출처

로컬 CCGS 인스턴스의 `/adopt` 스킬 정의 파일. 이 파일은 [[CCGS Adopt Brownfield Example]]의 예제 세션이 시연하는 워크플로의 **권위 있는 정의**다. 예제는 사용자 친화적이지만 SKILL.md는 정확한 분기 조건과 등급 기준을 명시한다. (Local path: `.claude/skills/adopt/SKILL.md`, 17,863 bytes)

## 메타데이터

| 항목 | 값 |
|---|---|
| name | `adopt` |
| user-invocable | `true` (직접 슬래시 명령 호출 가능) |
| allowed-tools | Read, Glob, Grep, Write, AskUserQuestion |
| agent | `technical-director` |
| argument-hint | `[focus: full \| gdds \| adrs \| stories \| infra]` |

## 5가지 Audit Mode

| 모드 | 범위 |
|---|---|
| `full` (기본) | 모든 아티팩트 타입 |
| `gdds` | GDD 포맷 컴플라이언스만 |
| `adrs` | ADR 포맷 컴플라이언스만 |
| `stories` | 스토리 포맷 컴플라이언스만 |
| `infra` | 인프라 아티팩트 갭만 (registry, manifest, sprint-status, stage.txt) |

## /project-stage-detect와의 차이

> "`/project-stage-detect` answers: *what exists?*
> `/adopt` answers: *will what exists actually work with the template's skills?*"

존재 감사가 아닌 **포맷 감사**가 `/adopt`의 본질.

## Phase 1: State Detection — 존재·인퍼

### 존재 체크 (라인 44-53)

```
- production/stage.txt
- design/gdd/game-concept.md
- design/gdd/systems-index.md
- design/gdd/*.md (GDD 카운트)
- docs/architecture/adr-*.md (ADR 카운트)
- production/epics/**/*.md (스토리 카운트)
- .claude/docs/technical-preferences.md (엔진 설정 여부)
- docs/engine-reference/
- docs/adoption-plan-*.md (이전 플랜 존재 여부)
```

### Fresh Project 거부 분기 (라인 64-72)

아무 아티팩트도 없으면 **`/adopt`는 작업을 거부**하고 사용자에게 다음 옵션 제시:

- `/start` 실행 — 첫 온보딩
- 비표준 위치에 아티팩트 있음 — 수동 안내
- 취소

이는 [[Brownfield Project Onboarding]]의 "공식 엔트리포인트" 진입 조건을 정의한다 — *완전히 빈 프로젝트는 브라운필드가 아니다*.

## Phase 2: Format Audit — 6 서브감사

### 2a. GDD 8-Section 감사

8 필수 섹션을 헤딩 패턴으로 스캔:
Overview / Player Fantasy / Detailed Rules / Formulas / Edge Cases / Dependencies / Tuning Knobs / Acceptance Criteria.
+ `**Status**:` 필드 (In Design / Designed / In Review / Approved / Needs Revision).

### 2b. ADR 5-Section 감사 + 등급 매핑

| 섹션 | 미존재 시 영향 |
|---|---|
| `## Status` | **BLOCKING** — `/story-readiness` ADR 체크 silent 통과 |
| `## ADR Dependencies` | HIGH — `/architecture-review` 의존성 깨짐 |
| `## Engine Compatibility` | HIGH — post-cutoff API 리스크 미인지 |
| `## GDD Requirements Addressed` | MEDIUM — 추적 매트릭스 손실 |
| `## Performance Implications` | LOW |

### 2c. systems-index.md 감사

- **Parenthetical status values** (예: `Needs Revision (see notes)`) → **BLOCKING** (`/gate-check`, `/create-stories`, `/architecture-review` 깨짐)
- 유효 Status 값: `Not Started`, `In Progress`, `In Review`, `Designed`, `Approved`, `Needs Revision`
- 컬럼 구조: System / Layer / Priority / Status 최소 보장

### 2d. Story 감사

- `Manifest Version:` 필드 (LOW — auto-pass)
- TR-ID 패턴 `TR-[a-z]+-[0-9]+` (MEDIUM)
- ADR 참조 (`ADR-` 패턴)
- Status 필드
- Acceptance criteria 체크박스(`- [ ]`)

### 2e. Infrastructure 감사

| 아티팩트 | 경로 | 미존재 시 |
|---|---|---|
| TR registry | `docs/architecture/tr-registry.yaml` | HIGH |
| Control manifest | `docs/architecture/control-manifest.md` | HIGH |
| Sprint status | `production/sprint-status.yaml` | MEDIUM |
| Stage file | `production/stage.txt` | MEDIUM |
| Engine reference | `docs/engine-reference/[engine]/VERSION.md` | HIGH |

### 2f. Technical Preferences 감사

`[TO BE CONFIGURED]` 슬롯 자동 등급화:

| 슬롯 | 미설정 시 등급 |
|---|---|
| **Engine, Language, Rendering, Physics** | **HIGH** ("ADR skills fail") |
| Naming conventions | MEDIUM |
| Performance budgets | MEDIUM |
| Forbidden Patterns, Allowed Libraries | LOW (starts empty by design) |

## Phase 3: 갭 분류 (4 등급)

> [!key-insight] 엔진 미설정의 조건부 등급
> Phase 2f는 엔진 미설정을 단독으로는 **HIGH**로 등급화하지만, Phase 3 BLOCKING 정의에 다음 케이스가 명시되어 있다:
> "**BLOCKING** examples: ... **engine not configured when ADRs exist**."
> 즉 ADR이 이미 존재하는데 엔진이 미설정이면 등급은 BLOCKING으로 *상향*된다 — ADR이 엔진 정보를 참조하기 때문.

| 등급 | 정의 | 예 |
|---|---|---|
| **BLOCKING** | 스킬이 silent 오작동 | ADR Status 부재 / systems-index 괄호 / **엔진 미설정 + ADR 존재** |
| **HIGH** | 안전성 손상 | ADR Engine Compatibility 부재 / GDD Acceptance Criteria 부재 / tr-registry 부재 / **엔진 미설정 (ADR 부재 시)** |
| **MEDIUM** | 품질 저하 | GDD Tuning Knobs 부재 / 스토리 TR-ID 부재 |
| **LOW** | 선택 | 스토리 Manifest Version 부재 |

## Phase 4: Migration Plan 정렬 규칙

1. BLOCKING 우선
2. HIGH는 인프라 → GDD/ADR 콘텐츠 순
3. MEDIUM는 GDD → ADR → 스토리 순
4. LOW 마지막

## Phase 5: Summary 출력 형식 (라인 240-257)

```
## Adoption Audit Summary
Phase detected: [phase]
Engine: [configured / NOT CONFIGURED]
GDDs audited: [N] ([X] fully compliant, [Y] with gaps)
ADRs audited: [N] ([X] fully compliant, [Y] with gaps)
Stories audited: [N]

Gap counts:
  BLOCKING: [N] — template skills will malfunction without these fixes
  HIGH:     [N] — unsafe to run /create-stories or /story-readiness
  MEDIUM:   [N] — quality degradation
  LOW:      [N] — optional improvements

Estimated remediation: [X blocking items × ~Y min each = roughly Z hours]
```

→ "Engine: [configured / NOT CONFIGURED]" 항목이 출력 헤더의 *1차 항목*으로 명시되어, 엔진 미설정 자체가 입력 조건이 아닌 진단 출력임을 확인.

## Phase 6: 어댑션 플랜 작성

승인 시 `docs/adoption-plan-[date].md`에 6단계(Step 1: BLOCKING / Step 2: HIGH / Step 3: Bootstrap / Step 4: MEDIUM / Step 5: LOW + Step "What to Expect from Existing Stories" + Re-run 안내)로 작성.

플랜 헤더에 `**Engine**: [name + version, or "Not configured"]` 명시 (라인 290).

## Phase 6b: Review Mode 설정

`production/review-mode.txt`를 Full / Lean(권장) / Solo 중 선택 작성:
- Full: Director 전문가가 모든 단계에서 리뷰
- Lean (권장): `/gate-check` 페이즈 게이트에서만 Director 리뷰
- Solo: Director 리뷰 없음 (게임 잼/프로토타입)

## Phase 7: First Action 분기 (즉시 처리 1건)

가장 시급한 갭 1개에 대해 즉시 처리 옵션 제시 (한 번에 한 액션 원칙):

1. systems-index 괄호 status가 있으면 → 인플레이스 수정 제안
2. ADR Status 부재 → retrofit 제안
3. GDD Acceptance Criteria 부재 → retrofit 제안
4. BLOCKING/HIGH 0개 → 추가 옵션 제시 (`/project-stage-detect`, MEDIUM 워크스루, 사용자 자율)

## 협업 프로토콜 (라인 432-441)

1. **Read silently** — 전체 감사 완료 후 표시
2. **Show summary first** — 사용자가 스코프 인지 후 작성 요청
3. **Ask before writing** — 어댑션 플랜 작성 전 항상 확인
4. **Offer, don't force** — 플랜은 권고
5. **One action at a time** — 6개 동시 X, 1개 다음 단계만
6. **Never regenerate existing artifacts** — 갭만 채움, 콘텐츠 보존

## Open Question 해소

> [!key-insight] 본 페이지가 해소한 질문
> 이전에 [[Brownfield Project Onboarding]]에 열려 있던 "엔진 설정이 `/adopt`의 선결 조건인가?"는 본 SKILL.md 직접 검토로 **해소**되었다. **결론**: 선결 조건 아님 — `/adopt`는 미설정 상태에서도 동작하며 미설정 자체를 자동 진단·등급화한다. 단, 코드/GDD/ADR이 *전부* 없으면 fresh로 판정해 `/start`로 라우팅한다.

## See Also

- [[CCGS Adopt Brownfield Example]] — SKILL.md가 정의한 워크플로의 시연 세션
- [[Brownfield Project Onboarding]] — SKILL.md 기반의 일반화 절차
- [[CCGS Reverse Document Workflow Example]] — Step 5(`/reverse-document`)의 4-Stage 분해
