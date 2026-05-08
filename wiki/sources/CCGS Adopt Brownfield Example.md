---
type: source
title: CCGS Adopt Brownfield Example
source_url: https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/docs/examples/session-adopt-brownfield.md
source_type: upstream-doc
fetched: 2026-05-08
created: 2026-05-08
updated: 2026-05-08
tags:
  - ccgs
  - brownfield
  - onboarding
  - adopt-skill
  - upstream-doc
  - example-session
related:
  - "[[Donchitos CCGS Repo]]"
  - "[[CCGS Framework]]"
  - "[[Brownfield Project Onboarding]]"
  - "[[Research CCGS Brownfield Onboarding]]"
  - "[[CCGS Reverse Document Workflow Example]]"
key_claims:
  - "/adopt 스킬은 CCGS의 공식 브라운필드 엔트리포인트이며, 4-Phase 구조(상태 탐지 → 포맷 감사 → 갭 분류 → 마이그레이션 플랜)로 동작한다"
  - "감사는 파일 존재 여부가 아닌 *내부 포맷*을 검사한다 — gdd.md 파일이 있어도 8-section 템플릿을 만족하지 않으면 갭으로 분류"
  - "갭은 BLOCKING / HIGH / MEDIUM / LOW 4단계로 등급화되며, BLOCKING 갭이 우선 해결된다 (예: design/gdd/systems-index.md 부재는 모든 다운스트림 스킬을 차단)"
  - "마이그레이션 플랜은 7단계 순차 작업으로 산출되며, 1단계(systems-index 생성)만 BLOCKING이고 나머지는 병렬·재정렬 가능"
  - "/design-system retrofit [path]은 기존 콘텐츠를 보존하고 누락된 GDD 섹션만 채운다 (덮어쓰기 없음)"
  - "/adopt는 'Context: fork'로 실행되어 메인 세션 컨텍스트를 보호한다"
  - "systems-index는 기존 코드베이스를 읽어 자동 추론되며, 사용자가 검토·수정 후 작성된다"
confidence: high
---

# CCGS Adopt Brownfield Example

## 출처

CCGS 업스트림 저장소의 `docs/examples/session-adopt-brownfield.md` 공식 예제 세션. 이 파일은 v1.0.0-beta 시점의 공식 워크플로 데모로, 8턴 30분짜리 실제 세션 트랜스크립트 형식으로 작성되어 있다. (Source URL: https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/docs/examples/session-adopt-brownfield.md)

## 시나리오 요약

3개월간 CCGS 없이 게임을 빌드해 온 개발자가 뒤늦게 `/adopt` 스킬로 온보딩하는 8턴 세션. 시작 상태:

- `src/gameplay/` 약 4000라인의 Godot 4.6 GDScript
- `design/` 폴더에 비공식 마크다운 3개 (GDD 템플릿 미준수)
- `design/gdd/`, `docs/architecture/`, `production/`, `design/gdd/systems-index.md` 모두 부재
- `CLAUDE.md`만 엔진 설정 완료(Godot 4.6)

## /adopt 스킬의 4-Phase 구조

| Phase | 작업 | 산출물 |
|---|---|---|
| **1. State Detection** | 디렉터리·파일 존재 여부 매트릭스 작성 | 7-항목 체크리스트 (✅/⚠️/❌) |
| **2. Format Audit** | 발견된 디자인 파일의 *내부 구조* 검사 — 8-section GDD 템플릿 매칭 | 누락 섹션 목록 (per-file) |
| **3. Gap Classification** | 발견 갭을 4단계로 등급화 | BLOCKING / HIGH / MEDIUM / LOW |
| **4. Migration Plan** | 갭 해결 절차를 우선순위 순으로 7단계 마이그레이션 플랜 산출 | `docs/adoption-plan-YYYY-MM-DD.md` |

## 갭 등급 기준 (예시 세션 기반)

| 등급 | 예시 | 영향 |
|---|---|---|
| **BLOCKING** | `design/gdd/systems-index.md` 부재 | `/design-system`, `/create-stories`, `/gate-check` 전부 차단 |
| **HIGH** | GDD 파일이 8-section 템플릿 미준수 / `docs/architecture/` 부재 | TR-ID 참조 불가 / `/architecture-review` 실행 불가 |
| **MEDIUM** | `production/` 폴더 부재 | 스프린트·스토리 스킬 비작동 — 프로덕션 단계 진입 전까지는 비차단 |
| **LOW** | 브레인스토밍 노트(미정형) | GDD 입력 자료로 활용 가능, 차단 요인 아님 |

## 7-Step Migration Plan (예시 세션 산출)

| # | 단계 | 사용 스킬 | 우선순위 |
|---|---|---|---|
| 1 | `design/gdd/systems-index.md` 생성 | `/map-systems` 또는 `/adopt` 인라인 | **BLOCKING** |
| 2 | 가장 완성도 높은 기존 파일 retrofit | `/design-system retrofit design/inventory.md` | HIGH |
| 3 | 다른 비완성 GDD retrofit | `/design-system retrofit design/combat-notes.md` | HIGH |
| 4 | 비정형 노트는 retrofit 대신 신규 GDD 작성 | `/design-system crafting` | MEDIUM |
| 5 | 기존 코드에서 ADR 추출 | `/reverse-document` + `/architecture-decision` | HIGH |
| 6 | 마스터 아키텍처 문서 생성 | `/create-architecture` | HIGH |
| 7 | 프로덕션 트래킹 셋업 | `/sprint-plan new` | MEDIUM |

> **중요**: 1단계만 BLOCKING — 다른 단계는 병렬 또는 재정렬 가능.

## 핵심 원칙 6가지 (예시가 시연하는 것)

1. **포맷 감사, 존재 감사 아님** — 파일 이름이 `gdd.md`라도 내부에 8-section이 없으면 갭으로 분류
2. **마이그레이션, 교체 아님** — 기존 콘텐츠는 절대 덮어쓰지 않음. 갭만 채움
3. **BLOCKING 우선 표면화** — 가장 많은 다운스트림 스킬을 차단하는 갭이 1순위
4. **인라인 즉시 수정 제안** — 갭을 단순 보고하지 않고, 같은 세션에서 해결 제안
5. **코드에서 추론** — `systems-index`는 기존 폴더 구조에서 자동 추론. 브라운필드 코드는 이미 답을 가지고 있음
6. **Retrofit vs 신규 작성 구분** — `/design-system retrofit` (기존 보존) vs `/design-system [name]` (신규 작성)

## 컨텍스트 격리

`/adopt`는 **'Context: fork'** 모드로 실행된다. 이는 다음을 의미한다:

- 코드베이스 전체를 읽는 작업이 메인 세션 컨텍스트를 오염시키지 않음
- 포크 컨텍스트에서 분석 후 결과 요약만 메인 세션에 반환
- 대규모 브라운필드(수만 라인)에서도 메인 세션의 토큰 예산을 절약

## 사용자 협업 프로토콜

예시 세션에서 모든 결정 시점은 사용자 승인을 거친다:

- **Turn 3**: "May I write this plan to `docs/adoption-plan-2026-03-12.md`?" → 사용자 승인 후 작성
- **Turn 5**: 시스템 인덱스 초안 제시 → 사용자가 "Stamina 시스템 추가" 수정 요청
- **Turn 6**: 수정된 시스템 인덱스에 대한 최종 승인
- **Turn 8**: 다음 단계 명령 사용자 직접 입력

이는 CLAUDE.md의 "Question → Options → Decision → Draft → Approval" 협업 프로토콜과 일치한다.

## 직접 인용 (영문 원문)

> "FORMAT audit, not existence audit: `/adopt` doesn't just check whether files exist — it checks whether their internal structure matches what skills expect. A file named `gdd.md` with no template sections is flagged as a gap."

> "Migration, not replacement: existing content is never overwritten. The plan fills gaps only."

> "Inferred from code: the systems index is bootstrapped from the codebase structure, not written from scratch — brownfield code already contains the answer."

## See Also

- [[Brownfield Project Onboarding]] — 이 예제로부터 도출된 일반화 절차
- [[Research CCGS Brownfield Onboarding]] — 이 소스로 보완된 합성 페이지
- [[CCGS Reverse Document Workflow Example]] — 보완 자료(Stage 5 ADR 추출 절차)
- [[Donchitos CCGS Repo]] — 출처 저장소 메타데이터
