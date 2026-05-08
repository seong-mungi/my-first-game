---
type: concept
title: Brownfield Project Onboarding
created: 2026-05-08
updated: 2026-05-08
tags:
  - ccgs
  - onboarding
  - brownfield
  - refactoring
  - process
  - adopt-skill
related:
  - "[[CCGS Framework]]"
  - "[[CCGS Subagent Tier Architecture]]"
  - "[[Research CCGS Brownfield Onboarding]]"
  - "[[CCGS Adopt Brownfield Example]]"
  - "[[CCGS Reverse Document Workflow Example]]"
sources:
  - "[[CCGS Adopt Brownfield Example]]"
  - "[[CCGS Reverse Document Workflow Example]]"
confidence: high
---

# Brownfield Project Onboarding

## 정의

**브라운필드(Brownfield) 온보딩**이란 기존 코드, 아트, 디자인이 이미 존재하는 프로젝트에 CCGS 같은 AI 에이전트 프레임워크를 사후 적용하는 절차다. 그린필드(처음부터 시작)와 반대되는 개념이며, 기존 자산을 보존하면서 에이전트 구조를 삽입해야 하므로 더 높은 주의가 필요하다.

> [!update] 2026-05-08 보완
> 이 페이지는 초기 작성 시 "공식 가이드 부재(신뢰도 medium)" 추론 절차였으나, 업스트림 공식 예제 [[CCGS Adopt Brownfield Example]] · [[CCGS Reverse Document Workflow Example]] 발견으로 **`/adopt` 공식 절차 기반으로 전면 개정**되었다. 신뢰도 high로 격상.

## 공식 엔트리포인트: `/adopt` 스킬

CCGS는 브라운필드 온보딩을 위한 전용 스킬을 보유한다:

```
/adopt
```

이 스킬은 **technical-director** 에이전트가 **forked context**(메인 세션 토큰 보호)에서 실행하며, 코드베이스 전체를 스캔해도 메인 세션 컨텍스트를 오염시키지 않는다. (Source: [[CCGS Adopt Brownfield Example]])

## 4-Phase 절차 (`/adopt` 공식 워크플로)

### Phase 1: State Detection — 무엇이 있고 없는지 매트릭스

7-항목 체크리스트로 디렉터리·파일 존재 여부를 매핑:

| 항목 카테고리 | 체크 |
|---|---|
| Engine configuration (`CLAUDE.md`) | ✅/❌ |
| Source code (`src/`) | ✅/❌ |
| Design docs (`design/`) | ✅/⚠️/❌ |
| Architecture docs (`docs/architecture/`) | ✅/❌ |
| **Systems index (`design/gdd/systems-index.md`)** | ✅/❌ — **BLOCKING 후보** |
| Production tracking (`production/`) | ✅/❌ |
| Sprint/story files | ✅/❌ |

⚠️ 표식은 "존재하지만 포맷 불완전"을 의미한다 — Phase 2에서 자세히 검사.

### Phase 2: Format Audit — *내부 구조* 검사

**핵심 원칙**: 파일 *존재*가 아니라 *내부 포맷*을 감사한다. 이름이 `gdd.md`라도 8-section 템플릿을 만족하지 않으면 갭으로 분류.

각 디자인 파일을 8-section GDD 템플릿(Overview / Player Fantasy / Detailed Rules / Formulas / Edge Cases / Dependencies / Tuning Knobs / Acceptance Criteria)에 매칭하여 누락 섹션을 추출.

### Phase 3: Gap Classification — 4단계 등급화

| 등급 | 기준 | 예시 |
|---|---|---|
| **BLOCKING** | 다수 다운스트림 스킬을 차단 | `design/gdd/systems-index.md` 부재 → `/design-system`, `/create-stories`, `/gate-check` 전부 차단 |
| **HIGH** | 핵심 워크플로 차단 | GDD 8-section 미준수, `docs/architecture/` 부재 |
| **MEDIUM** | 특정 단계 차단 (당장 차단 아님) | `production/` 폴더 부재 — 프로덕션 진입 전까지 비차단 |
| **LOW** | 입력 자료로 활용 가능 | 비정형 브레인스토밍 노트 |

### Phase 4: Migration Plan — 7-Step 마이그레이션 플랜

`docs/adoption-plan-YYYY-MM-DD.md`에 작성되는 기본 플랜 구조 (Source: [[CCGS Adopt Brownfield Example]]):

| # | 단계 | 사용 스킬 | 우선순위 |
|---|---|---|---|
| 1 | `design/gdd/systems-index.md` 생성 | `/map-systems` 또는 `/adopt` 인라인 | **BLOCKING** |
| 2 | 가장 완성도 높은 기존 GDD retrofit | `/design-system retrofit [path]` | HIGH |
| 3 | 기타 비완성 GDD retrofit | `/design-system retrofit [path]` | HIGH |
| 4 | 비정형 노트는 신규 GDD 작성 | `/design-system [name]` | MEDIUM |
| 5 | 기존 코드에서 ADR 추출 | `/reverse-document` + `/architecture-decision` | HIGH |
| 6 | 마스터 아키텍처 문서 생성 | `/create-architecture` | HIGH |
| 7 | 프로덕션 트래킹 셋업 | `/sprint-plan new` | MEDIUM |

> **중요**: Step 1만 BLOCKING — 다른 단계는 병렬 또는 재정렬 가능.

## Step 5 심화: `/reverse-document`의 4-Stage

기존 코드에서 GDD를 역생성할 때 [[CCGS Reverse Document Workflow Example]]가 제시하는 4단계:

| Stage | 활동 | 행위자 |
|---|---|---|
| 1. Code Analysis | 코드 패턴·구조 식별 | game-designer |
| 2. Intent Discovery | 사용자에게 *결정 근거* 질문 | game-designer |
| 3. Vision Alignment | 의도 vs 구현 차이 표면화 | 사용자 + game-designer |
| 4. Documentation Generation | 8-section GDD + `[REVERSE-DOCUMENTED FROM IMPLEMENTATION]` 태그 + TODO | game-designer |

**핵심**: "이 코드가 무엇을 하는가"가 아니라 "*왜 이렇게 했는가*"를 묻는다. 의도 vs 구현 차이는 GDD에 **의도 측으로 기록**되고 구현 수정은 TODO로 분리.

## 핵심 원칙 6가지

1. **포맷 감사, 존재 감사 아님** — 파일이 있어도 템플릿 미준수면 갭
2. **마이그레이션, 교체 아님** — 기존 콘텐츠는 절대 덮어쓰지 않음. `/design-system retrofit`은 누락 섹션만 채움
3. **BLOCKING 우선** — 가장 많은 다운스트림을 차단하는 갭이 1순위
4. **인라인 즉시 수정 제안** — 갭 단순 보고가 아닌 같은 세션에서 해결 제안
5. **코드에서 추론** — `systems-index`는 폴더 구조 자동 추론. 브라운필드 코드는 이미 답을 가짐
6. **Retrofit vs 신규 작성 구분** — `/design-system retrofit` (보존) vs `/design-system [name]` (신규)

## 위험 함정 (하지 말아야 할 것)

| 함정 | 이유 | 대안 |
|---|---|---|
| 에이전트에게 기존 작동 코드 자동 재작성 지시 | 작동 코드를 의도치 않게 손상 | 인간 검토 후 시스템 단위 점진적 리팩터 |
| 기존 GDD 파일 덮어쓰기 | 사용자 콘텐츠 소실 | 항상 `/design-system retrofit`으로 누락 섹션만 채움 |
| BLOCKING 우선순위 무시 | 후속 스킬이 동작 안 함 | systems-index를 **반드시** 먼저 생성 |
| `/reverse-document` 후 ADR 작성 건너뛰기 | 코드 결정 근거 소실 | Step 5의 `+ /architecture-decision` 부분 필수 |
| `/adopt` 외 메인 세션에서 코드베이스 전체 읽기 | 메인 세션 토큰 폭발 | `/adopt`의 forked context 활용 |
| Phase 순서 역전 | 테스트·구조 없이 컨벤션 변경 → 회귀 탐지 불가 | 마이그레이션 플랜 순서 준수 |

## 검증 게이트

| 단계 완료 후 | 검증 방법 |
|---|---|
| Phase 1-3 완료 | `/adopt` 출력에 갭 매트릭스가 BLOCKING 명시 |
| Phase 4 완료 | `docs/adoption-plan-YYYY-MM-DD.md` 작성 + 사용자 승인 |
| Step 1 완료 | `design/gdd/systems-index.md` 작성 → 모든 다운스트림 스킬 언락 |
| Step 2-4 완료 | `/review-all-gdds` — 시스템 간 일관성 점검 통과 |
| Step 5-6 완료 | `/architecture-review` — 블로커 없음 |
| 전체 완료 | `/gate-check` — 모든 게이트 PASS |

## 사용자 협업 프로토콜

`/adopt`는 CCGS의 협업 원칙(Question → Options → Decision → Draft → Approval)을 엄격히 따른다. 예시 세션의 모든 결정 시점에서 사용자 승인 필수:

- 마이그레이션 플랜 작성 전 "May I write this plan to ...?" 확인
- systems-index 초안 제시 → 사용자가 "Stamina 시스템 추가"처럼 수정
- 수정안 다시 제시 → 최종 승인 후 작성

자율 실행 금지 — 모든 산출물은 사용자 승인 후 디스크 기록.

## See Also

- [[CCGS Adopt Brownfield Example]] — 본 절차의 1차 출처(공식 예제 세션)
- [[CCGS Reverse Document Workflow Example]] — Step 5 심화(4-Stage)
- [[Research CCGS Brownfield Onboarding]] — 본 페이지를 사용하는 합성 연구
- [[CCGS Framework]] — 상위 프레임워크 컨텍스트
- [[CCGS Subagent Tier Architecture]] — Phase 2 감사에서 어느 티어가 무엇을 보는지

## Resolved Questions

> [!key-insight] 2026-05-08 해소: 엔진 미설정과 `/adopt`의 관계
> **`/adopt`는 엔진 미설정 상태에서도 작동한다 — 선결 조건 아님.** `[TO BE CONFIGURED]` 슬롯은 Phase 2f에서 자동 진단되고 다음과 같이 등급화된다 (Source: [[CCGS Adopt SKILL Definition]]):
>
> | 상황 | 엔진 미설정 등급 |
> |---|---|
> | ADR이 *없음* (코드만 존재) | **HIGH** (단독 갭) |
> | ADR이 *존재* | **BLOCKING** (ADR이 엔진 정보를 참조) |
> | 코드·GDD·ADR이 *전부* 부재 | `/adopt` 거부 → `/start`로 라우팅 |
>
> Phase 5 요약 출력에 `Engine: [configured / NOT CONFIGURED]`가 1차 항목으로 명시된다 — 엔진 상태는 입력 조건이 아니라 *진단 출력*이다.

## Open Questions

> [!gap] 미확인 사항
> 1. forked context의 정확한 토큰 한도와 메인 세션과의 통신 방식은?
> 2. `/reverse-document`가 Godot `.gd` 파일을 정확히 파싱하는가? (예시는 GDScript 가정)
> 3. 매우 큰 코드베이스(>50K 라인)에서 `/adopt` Phase 1-2가 완료되는 시간 한도?
> 4. `/adopt` 재실행 시 이전 `docs/adoption-plan-*.md`와의 diff 동작이 없는데, 사용자가 수동 추적해야 하는가?
