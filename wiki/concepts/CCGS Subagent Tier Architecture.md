---
type: concept
title: CCGS Subagent Tier Architecture
created: 2026-05-08
updated: 2026-05-08
tags:
  - ccgs
  - ai-agents
  - architecture
  - multi-agent
related:
  - "[[CCGS Framework]]"
  - "[[Donchitos CCGS Repo]]"
  - "[[Research CCGS Framework And Local Drift]]"
confidence: high
---

# CCGS Subagent Tier Architecture

## 개요

CCGS는 실제 게임 스튜디오의 조직 계층을 Claude Code 서브에이전트로 모델링한다. 49개 에이전트는 수직 위임(Vertical Delegation)과 수평 협의(Horizontal Consultation) 두 규칙으로 조율된다.

(Source: [[GitHub Donchitos Claude Code Game Studios]], [[Donchitos CCGS Repo]])

## 3-Tier 수직 계층

```
Tier 1: 리더십 (Leadership)
    creative-director | technical-director | producer
    narrative-director | audio-director | art-director
         ↓ 위임
Tier 2: 부서 리드 (Department Leads)
    lead-programmer | game-designer | qa-lead
    systems-designer | ux-designer | release-manager
         ↓ 위임
Tier 3: 전문가 (Specialists)
    [엔진 전문가] [언어 전문가] [도메인 전문가]
```

## 엔진별 전문가 서브트리

### Godot 서브트리 (5개)
```
godot-specialist
├── godot-gdscript-specialist
├── godot-csharp-specialist
├── godot-shader-specialist
└── godot-gdextension-specialist
```

### Unity 서브트리 (5개)
```
unity-specialist
├── unity-shader-specialist
├── unity-ui-specialist
├── unity-dots-specialist
└── unity-addressables-specialist
```

### Unreal 서브트리 (5개)
```
unreal-specialist
├── ue-blueprint-specialist
├── ue-gas-specialist
├── ue-replication-specialist
└── ue-umg-specialist
```

## 조율 규칙

1. **수직 위임**: 리더십 → 부서 리드 → 전문가. 계층 건너뜀 금지.
2. **수평 협의**: 같은 티어끼리 협의 가능하나 도메인 밖 결정 금지.
3. **갈등 해결**: 설계 갈등 → creative-director, 기술 갈등 → technical-director.
4. **변경 전파**: 다중 도메인 영향 변경은 producer가 조율.
5. **교차 도메인 변경 금지**: 명시적 위임 없이 다른 디렉터리 수정 불가.

## 병렬 실행 프로토콜

독립적인 두 에이전트의 입력이 서로 의존하지 않으면 동시에 Task 호출:

```
# 예시: /review-all-gdds
Phase 1 (독립 병렬): consistency-checker | design-theory-reviewer
Phase 2 (의존적 순차): synthesis-agent (Phase 1 결과 필요)
```

## 서브에이전트 vs 에이전트 팀

| 방식 | 사용 시점 |
|---|---|
| **서브에이전트** (기본) | 단일 세션 내 Task 호출. 권한 컨텍스트 공유. |
| **에이전트 팀** (실험적) | 30분 이상, 파일 충돌 없는 독립 워크스트림. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 필요. |

## 파일 라우팅 (my-game 기준)

| 파일 유형 | 담당 에이전트 |
|---|---|
| `.gd` (GDScript) | godot-gdscript-specialist |
| `.cs` (C# in Godot) | godot-csharp-specialist |
| 셰이더 파일 | godot-shader-specialist |
| 씬 파일 `.tscn` | godot-specialist |
| GDExtension | godot-gdextension-specialist |
| 아키텍처 검토 | technical-director |
