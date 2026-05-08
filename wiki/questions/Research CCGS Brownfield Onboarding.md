---
type: question
title: Research CCGS Brownfield Onboarding
created: 2026-05-08
updated: 2026-05-08
tags:
  - ccgs
  - onboarding
  - brownfield
  - refactoring
  - process
  - research
  - adopt-skill
related:
  - "[[Brownfield Project Onboarding]]"
  - "[[CCGS Framework]]"
  - "[[CCGS Subagent Tier Architecture]]"
  - "[[Research CCGS Framework And Local Drift]]"
  - "[[CCGS Adopt Brownfield Example]]"
  - "[[CCGS Reverse Document Workflow Example]]"
sources:
  - "[[CCGS Adopt Brownfield Example]]"
  - "[[CCGS Reverse Document Workflow Example]]"
confidence: high
---

# Research CCGS Brownfield Onboarding

## 질문

기존 코드·아트·디자인이 있는 프로젝트(브라운필드)에 CCGS를 적용하는 절차는 무엇인가? 온보딩 이후 리팩터 단계는 어떤 순서로 진행해야 하는가?

## 보완 (2026-05-08) — 공식 가이드 발견 → 신뢰도 격상

> [!update] 초기 진단 정정
> 초기 작성 시 "공식 브라운필드 가이드 부재(medium)"으로 결론 냈으나, 사용자 지시로 업스트림 저장소를 재조사한 결과 **공식 예제 2건이 존재함**을 확인:
> - [[CCGS Adopt Brownfield Example]] — `/adopt` 스킬 8턴 30분 데모 세션
> - [[CCGS Reverse Document Workflow Example]] — `/reverse-document` 4-Stage 워크플로
>
> 이 두 출처는 본 페이지의 절차를 **공식 워크플로 기반**으로 재정의하며, 전체 신뢰도를 medium → **high**로 격상한다.
> 본 페이지의 추론 기반 절차는 [[Brownfield Project Onboarding]]에 통합 후 공식 절차로 교체되었다.

## 공식 절차 요약 (`/adopt` 스킬)

캐노니컬 절차는 [[Brownfield Project Onboarding]]에 통합 정리되었다. 핵심만 요약:

- **공식 엔트리포인트**: `/adopt` (technical-director 에이전트, **forked context** 실행 → 메인 세션 토큰 보호)
- **4-Phase 구조**: State Detection → Format Audit → Gap Classification → Migration Plan (`docs/adoption-plan-YYYY-MM-DD.md`)
- **갭 등급**: BLOCKING / HIGH / MEDIUM / LOW — `design/gdd/systems-index.md` 부재가 대표 BLOCKING
- **7-Step Migration Plan** (BLOCKING은 Step 1만, 나머지는 병렬·재정렬 가능):
  1. systems-index 생성 (`/map-systems`) — **BLOCKING**
  2. 기존 GDD retrofit (`/design-system retrofit [path]`)
  3. 기타 비완성 GDD retrofit
  4. 비정형 노트는 신규 작성 (`/design-system [name]`)
  5. ADR 추출 (`/reverse-document` + `/architecture-decision`)
  6. 마스터 아키텍처 (`/create-architecture`)
  7. 프로덕션 트래킹 (`/sprint-plan new`)
- **6 핵심 원칙**: 포맷 감사·마이그레이션 보존·BLOCKING 우선·인라인 즉시 수정·코드에서 추론·retrofit vs 신규 구분

상세는 [[Brownfield Project Onboarding]] · [[CCGS Adopt Brownfield Example]] · [[CCGS Reverse Document Workflow Example]] 참조.

---

## 초기 추론 절차 (보완 자료 발견 전 — 참고용)

다음 본문은 공식 예제 발견 전(2026-05-08 오전) 작성된 추론 절차다. 일부 항목은 공식 절차와 다르므로 [[Brownfield Project Onboarding]]의 캐노니컬 버전을 우선 참조할 것. 추론과 공식의 주요 차이:

| 항목 | 추론 (이 페이지 본문) | 공식 (`/adopt`) |
|---|---|---|
| 엔트리포인트 | `/reverse-document` 단일 | `/adopt` 오케스트레이터 (forked context) |
| Phase 명칭 | 내성 → 감사 → 리팩터 시퀀싱 → 검증 | State Detection → Format Audit → Gap Classification → Migration Plan |
| 첫 산출물 | `[TO BE CONFIGURED]` 채우기 | systems-index BLOCKING 갭 해결 |
| 컨텍스트 격리 | 미언급 | forked context 명시 |
| Retrofit 개념 | 없음 | `/design-system retrofit`이 핵심 패턴 |

## 브라운필드 온보딩이 그린필드와 다른 이유

| 항목 | 그린필드 | 브라운필드 |
|---|---|---|
| **시작점** | 빈 디렉터리 | 기존 코드·아트·디자인 |
| **온보딩 스킬** | `/start` → 즉시 | 먼저 내성(introspection) 필요 |
| **컨벤션** | 처음부터 설정 | 기존 컨벤션 발견 후 결정 |
| **위험** | 낮음 | 높음 (기존 작동 코드 손상 위험) |
| **첫 번째 에이전트 호출** | creative-director | reverse-document (아키텍처 역문서화) |

## Phase 1: 내성 — 존재하는 것을 먼저 이해한다

### 1-A. 기존 코드 역문서화
```
/reverse-document
```
기존 코드베이스를 스캔하여 아키텍처 문서를 자동 생성. `docs/architecture/` 에 저장.

**입력**: 기존 소스 디렉터리
**출력**: 시스템 다이어그램, 의존성 맵, 발견된 패턴 목록

### 1-B. 기술 선호도 슬롯 채우기

`.claude/docs/technical-preferences.md` 의 모든 `[TO BE CONFIGURED]` 항목 작성:

| 슬롯 | 작성 방법 |
|---|---|
| Engine / Language | 기존 프로젝트 파일 확인 (.gdproject, .csproj 등) |
| Target Platforms | 기존 빌드 설정 확인 |
| Naming Conventions | 기존 코드에서 패턴 추출 |
| Performance Budgets | 기존 프로파일링 데이터 또는 타겟 하드웨어에서 추론 |
| Testing Framework | 기존 테스트 폴더 확인 |

**검증**: `detect-gaps.sh` 훅 수동 실행 → `[TO BE CONFIGURED]` 0개 확인

### 1-C. 에이전트 시드(Seed)

각 에이전트가 프로젝트를 이해할 수 있도록 컨텍스트 주입:

```markdown
# .claude/agent-memory/technical-director/MEMORY.md 에 추가
## 브라운필드 컨텍스트
- 기존 코드: src/game/ (약 X 파일)
- 주요 시스템: [발견된 시스템 목록]
- 알려진 기술 부채: [기존 문제점]
- 변경 불가 파일: [레거시 의존성 목록]
```

## Phase 2: 초기 감사 — 각 티어가 무엇을 먼저 보는가

### Tier 1 (리더십) 감사

```
/architecture-review  ← technical-director 호출
```
- 전체 시스템 의존성 그래프
- 아키텍처 안티패턴 탐지
- 기술 부채 우선순위 지정

```
/review-all-gdds     ← creative-director + game-designer 호출
```
- GDD 존재 여부 확인 (없으면 `/reverse-document`로 생성)
- 설계와 구현 간 일치 여부

### Tier 2 (부서 리드) 감사

```
/consistency-check   ← lead-programmer 호출
```
- 네이밍 컨벤션 위반 탐지
- 코딩 표준 위반 목록

```
/map-systems         ← systems-designer 호출
```
- 시스템 간 상호의존성 시각화
- 결합도(coupling) 문제 탐지

### Tier 3 (전문가) 감사

- godot-specialist: Godot 4.6 API 호환성 검사 (지식 컷오프 이후 API 변경 위험)
- qa-lead: 테스트 커버리지 현황, CI 존재 여부

## Phase 3: 리팩터 시퀀싱

올바른 순서:

```
Step 1: 디렉터리 재구조화
        → CCGS 표준 레이아웃(src/, assets/, design/, tests/)으로 이동
        → 이동 후 즉시 빌드 확인 (CI 그린 필수)

Step 2: 네이밍 컨벤션 정렬
        → technical-preferences.md 컨벤션 확정 후 /consistency-check 로 위반 목록 생성
        → 신규 파일부터 적용, 기존 파일은 시스템 단위로 점진적 정리

Step 3: 테스팅 하네스 구축
        → /test-setup 으로 테스트 프레임워크 설치 (Godot: GdUnit4)
        → 리팩터 전 기존 동작에 대한 회귀 테스트 먼저 작성
        → 테스트 없이 Step 4로 진행 금지

Step 4: 아키텍처 결정 기록 소급
        → /architecture-decision 으로 이미 내려진 결정 문서화
        → docs/architecture/ 에 ADR 파일 생성

Step 5: 코딩 표준 정렬
        → coding-standards.md 업데이트
        → 신규 코드 즉시 적용, 기존 코드 점진적 마이그레이션
```

## 위험 함정 (하지 말아야 할 것)

| 함정 | 이유 | 대안 |
|---|---|---|
| 에이전트에게 기존 코드 자동 재작성 지시 | 작동하는 코드를 의도치 않게 망가뜨림 | 인간 검토 후 시스템 단위 점진적 리팩터 |
| Phase 순서 역전 | 테스트 없이 컨벤션 변경하면 회귀 탐지 불가 | 반드시 Step 3(테스팅) 완료 후 Step 4+ |
| 전체 일괄 변환 | 대규모 변경은 리뷰 불가, 롤백 불가 | 파일 단위·시스템 단위 소규모 변경 |
| `/architecture-decision` 건너뛰기 | 결정 근거 소실 → 미래에 같은 논의 반복 | 모든 아키텍처 결정을 ADR로 기록 |
| 브라운필드 컨텍스트 없이 에이전트 호출 | 에이전트가 그린필드 가정으로 잘못된 제안 | agent-memory에 기존 구조 명시적 기술 |

## 검증 게이트

| 체크포인트 | 검증 방법 |
|---|---|
| Phase 1 완료 | `detect-gaps.sh` 실행 → 미설정 0 |
| Phase 2 완료 | `/architecture-review` — BLOCKER 없음 |
| Step 1 완료 | CI 빌드 그린 |
| Step 3 완료 | 회귀 테스트 전부 통과 |
| 전체 완료 | `/gate-check` — 모든 게이트 PASS |

## 오픈 질문

> [!gap] 미확인 사항
> 1. `agent-memory/` 폴더에 브라운필드 컨텍스트를 얼마나 상세하게 기술해야 효과적인가?
> 2. `/reverse-document` 스킬이 Godot 4 `.gd` 파일을 올바르게 파싱하는가?
> 3. 기존 GDD가 없을 때 `/review-all-gdds` 는 어떻게 동작하는가?
