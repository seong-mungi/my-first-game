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
related:
  - "[[CCGS Framework]]"
  - "[[CCGS Subagent Tier Architecture]]"
  - "[[Research CCGS Brownfield Onboarding]]"
confidence: medium
---

# Brownfield Project Onboarding

## 정의

**브라운필드(Brownfield) 온보딩**이란 기존 코드, 아트, 디자인이 이미 존재하는 프로젝트에 CCGS 같은 AI 에이전트 프레임워크를 사후 적용하는 절차다. 그린필드(처음부터 시작)와 반대되는 개념이며, 기존 자산을 보존하면서 에이전트 구조를 삽입해야 하므로 더 높은 주의가 필요하다.

## 4단계 절차

### Phase 1: 내성(Introspection) — 존재하는 것을 이해한다

> **목표**: `[TO BE CONFIGURED]` 슬롯을 실제 프로젝트 사실로 채운다.

1. **코드 탐색**: `/reverse-document` 스킬로 기존 코드에서 아키텍처 문서 자동 생성
2. **기술 스택 확정**: `.claude/docs/technical-preferences.md` 의 모든 `[TO BE CONFIGURED]` 항목 작성
   - 엔진·언어, 플랫폼, 입력 방식, 네이밍 컨벤션, 성능 예산
3. **디렉터리 매핑**: 기존 폴더 구조를 CCGS 표준 구조(`src/`, `assets/`, `design/`, `docs/`, `tests/`)에 매핑
4. **에이전트 시드**: 각 에이전트 정의 파일(`agent-memory/` 폴더)에 프로젝트 컨텍스트 주입

**검증 게이트**: `detect-gaps.sh` 훅 실행 → `[TO BE CONFIGURED]` 슬롯 0개 확인

### Phase 2: 초기 감사(Audit) — 각 티어가 무엇을 먼저 봐야 하는가

| 티어 | 담당 에이전트 | 리뷰 대상 |
|---|---|---|
| 리더십 | technical-director | 전체 아키텍처 구조, 기술 부채 |
| 리더십 | creative-director | 게임 컨셉, GDD 존재 여부 |
| 부서 리드 | lead-programmer | 코딩 컨벤션, 패턴 일관성 |
| 부서 리드 | qa-lead | 테스트 커버리지, CI 존재 여부 |
| 전문가 | godot-specialist | Godot 버전 API 호환성 |
| 전문가 | systems-designer | 게임 시스템 상호의존성 맵 |

**스킬 활용**: `/architecture-review`, `/consistency-check`, `/map-systems`

### Phase 3: 리팩터 시퀀싱 — 어떤 순서로 정리하는가

올바른 순서가 중요하다. 잘못된 순서는 반복 작업을 유발한다.

```
1. 디렉터리 재구조화
   → CCGS 표준 레이아웃으로 파일 이동
   → 이전 경로 임시 심볼릭 링크 유지 (빌드 깨짐 방지)

2. 네이밍 컨벤션 정렬
   → technical-preferences.md 컨벤션 결정 후 적용
   → /consistency-check 로 위반 탐지

3. 테스팅 하네스 구축
   → /test-setup 으로 프레임워크 설치
   → 기존 로직에 대한 회귀 테스트 먼저 작성 (리팩터 전 안전망)

4. 아키텍처 결정 기록
   → /architecture-decision 으로 기존 결정 소급 문서화
   → 변경 불가 결정과 변경 가능 결정 분리

5. 코딩 표준 정렬
   → coding-standards.md 업데이트
   → 신규 코드부터 적용, 기존 코드는 점진적 정리
```

### Phase 4: 검증 게이트

| 단계 완료 후 | 검증 방법 |
|---|---|
| Phase 1 완료 | `detect-gaps.sh` — 미설정 슬롯 0 |
| Phase 2 완료 | `/architecture-review` 리포트 — 블로커 없음 |
| Phase 3-1 완료 | CI 빌드 그린 (디렉터리 이동 후) |
| Phase 3-3 완료 | 회귀 테스트 전부 통과 |
| Phase 4 완료 | `/gate-check` — 모든 게이트 PASS |

## 위험 함정 (하지 말아야 할 것)

1. **에이전트에게 기존 작동 코드 자동 재작성 금지**: 리팩터는 인간 승인 후 점진적으로.
2. **`/architecture-decision` 건너뛰기 금지**: 결정이 문서 없이 이루어지면 나중에 근거를 잃는다.
3. **Phase 순서 역전 금지**: 테스트 없이 네이밍 리팩터를 하면 회귀 탐지 불가.
4. **전체 코드베이스 일괄 변환 금지**: 시스템 단위로 순차 적용.
5. **컨텍스트 없이 에이전트 호출 금지**: 브라운필드 컨텍스트를 에이전트에 명시적으로 전달해야 한다.

> [!gap] 미확인 사항
> CCGS 공식 문서에 브라운필드 온보딩 가이드가 존재하는지 확인되지 않았음.
> 이 절차는 CCGS 구조 분석과 일반적 리팩터링 원칙을 종합한 추론이다.
