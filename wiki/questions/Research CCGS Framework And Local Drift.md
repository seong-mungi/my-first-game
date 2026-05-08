---
type: question
title: Research CCGS Framework And Local Drift
created: 2026-05-08
updated: 2026-05-08
tags:
  - ccgs
  - framework
  - drift-analysis
  - ai-agents
  - research
related:
  - "[[CCGS Framework]]"
  - "[[CCGS Subagent Tier Architecture]]"
  - "[[Donchitos CCGS Repo]]"
  - "[[GitHub Donchitos Claude Code Game Studios]]"
  - "[[Brownfield Project Onboarding]]"
confidence: high
---

# Research CCGS Framework And Local Drift

## 질문

`Donchitos/Claude-Code-Game-Studios` 저장소는 어떤 구조인가? 로컬 my-game 프로젝트의 `.claude/` 설정과 비교했을 때 드리프트(upstream 대비 차이)가 있는가?

## 업스트림 저장소 요약

| 지표 | 값 |
|---|---|
| **에이전트 수** | 49개 |
| **스킬 수** | 72개 |
| **훅 수** | 12개 |
| **문서 파일** | 61개 |
| **전체 파일** | 412개 |
| **라이선스** | MIT |
| **버전** | v1.0.0-beta (2026-04-07) |
| **스타** | 17,713 |
| **기여자** | 1명 (Donchitos) |
| **마지막 푸시** | 2026-05-03 |

(Source: [[GitHub Donchitos Claude Code Game Studios]])

## 로컬 vs 업스트림 드리프트 분석

| 항목 | 업스트림 | 로컬 my-game | 상태 |
|---|---|---|---|
| **에이전트 수** | 49 | 49 | 일치 ✅ |
| **스킬 수** | 72 | 73 | +1 차이 ⚠️ |
| **훅 수** | 12 | 12 | 일치 ✅ |
| **CLAUDE.md** | 72줄 | 72줄 | 일치 ✅ |
| **에이전트 목록** | 동일 49개 | 동일 49개 | 일치 ✅ |

### 스킬 +1 차이: `omc-reference`

로컬 `.claude/skills/`에 업스트림에 없는 `omc-reference` 스킬이 1개 추가되어 있다. 이것은 **OMC(Oh-My-ClaudeCode) 프레임워크**가 주입한 스킬로, CCGS와 무관한 별도 레이어다. CCGS 드리프트가 아니라 로컬 OMC 통합의 결과다.

**결론**: 로컬 my-game 프로젝트는 **업스트림 현행(current)**이다. CCGS v1.0.0-beta 기준으로 드리프트 없음.

## 프레임워크 구조 분석

### 강점
1. **완전한 스튜디오 계층**: 리더십 → 부서 리드 → 전문가 3티어가 실제 스튜디오 조직을 모델링
2. **엔진 3종 지원**: Godot, Unity, Unreal 각각 5개 전문 서브에이전트 보유
3. **72개 스킬**: 컨셉 → 릴리스 전체 생명주기 커버
4. **MIT 라이선스 + is_template**: 즉시 포크·활용 가능
5. **훅 기반 자동화**: `validate-commit.sh`, `validate-push.sh`로 품질 게이트 강제
6. **협업 프로토콜**: Question → Options → Decision → Draft → Approval — 자율 실행 방지
7. **활발한 버그픽스**: 2026-04 ~ 05 지속 패치 (v1.0.0-beta 이후 5개 버그픽스)

### 약점 / 갭
1. **단일 기여자**: 버스 팩터 1 — 장기 유지보수 불확실
2. **완성 게임 사례 없음**: 이슈 #34 "Has anyone created a finished game?" — 미답변
3. **브라운필드 가이드 부재**: 기존 코드베이스에 CCGS 적용하는 공식 절차 없음
4. **`[TO BE CONFIGURED]` 초기 설정 비용**: technical-preferences.md의 모든 슬롯을 수동으로 채워야 함
5. **실제 게임 코드 없음**: CCGS는 프레임워크만 제공, 게임 시스템 구현은 전적으로 프로젝트 책임

## 업데이트 케이던스 평가

2026-04-07 v1.0.0-beta 이후 약 4주간 5개 버그픽스 커밋. 활발한 초기 유지보수 단계. 단일 기여자이므로 기여자 비활성화 시 버려질 위험 존재.

## 로컬 프로젝트 권고사항

1. **현재 상태 유지**: 업스트림 대비 드리프트 없으므로 별도 동기화 불필요
2. **엔진 설정 완료**: `/setup-engine` 스킬로 `[TO BE CONFIGURED]` 슬롯 채우기
3. **OMC 스킬 분리 유지**: `omc-reference`는 CCGS 스킬이 아님 — 혼동하지 말 것
4. **업스트림 모니터링**: GitHub Watch로 새 훅/에이전트 추가 추적 권장

## 오픈 질문

> [!gap] 미확인 사항
> 1. CCGS로 실제 출시된 게임이 존재하는가? (이슈 #34 미해결)
> 2. 업스트림의 `validate-skill-change.sh` 훅은 어떤 조건에서 트리거되는가?
> 3. OMC와 CCGS 간 스킬 네임스페이스 충돌 가능성이 있는가?
