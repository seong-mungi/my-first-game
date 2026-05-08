---
type: entity
title: Donchitos CCGS Repo
created: 2026-05-08
updated: 2026-05-08
tags:
  - ccgs
  - framework
  - ai-agents
  - game-development
  - claude-code
related:
  - "[[CCGS Framework]]"
  - "[[CCGS Subagent Tier Architecture]]"
  - "[[Research CCGS Framework And Local Drift]]"
  - "[[GitHub Donchitos Claude Code Game Studios]]"
confidence: high
---

# Donchitos CCGS Repo

## 기본 정보

| 항목 | 값 |
|---|---|
| **저장소** | `Donchitos/Claude-Code-Game-Studios` |
| **설명** | Turn Claude Code into a full game dev studio — 49 AI agents, 72 workflow skills, and a complete coordination system mirroring real studio hierarchy |
| **라이선스** | MIT |
| **생성일** | 2026-02-12 |
| **최근 푸시** | 2026-05-03 |
| **스타** | 17,713 |
| **포크** | 2,582 |
| **공개 이슈** | 15 |
| **기여자** | 1명 (Donchitos, 37 commits) |
| **기본 언어** | Shell |
| **템플릿 여부** | is_template: true |

## 구조 요약

- `.claude/agents/` — 49개 에이전트 정의 파일
- `.claude/skills/` — 72개 스킬 (각 `SKILL.md` 포함)
- `.claude/hooks/` — 12개 셸 훅
- `.claude/docs/` — 61개 문서 (템플릿·가이드 포함)
- `CLAUDE.md` — 마스터 설정 진입점 (72줄)

## 에이전트 티어 구성

49개 에이전트는 3가지 엔진(Godot, Unity, Unreal) 전문 서브에이전트를 포함한 다층 계층:

- **리더십**: creative-director, technical-director, producer, narrative-director, audio-director, art-director
- **프로그래밍**: lead-programmer, gameplay-programmer, engine-programmer, ui-programmer, ai-programmer, network-programmer, tools-programmer, performance-analyst, security-engineer, devops-engineer
- **Godot 전문**: godot-specialist, godot-gdscript-specialist, godot-csharp-specialist, godot-shader-specialist, godot-gdextension-specialist
- **Unity 전문**: unity-specialist, unity-shader-specialist, unity-ui-specialist, unity-dots-specialist, unity-addressables-specialist
- **Unreal 전문**: unreal-specialist, ue-blueprint-specialist, ue-gas-specialist, ue-replication-specialist, ue-umg-specialist
- **디자인/기타**: game-designer, systems-designer, level-designer, economy-designer, live-ops-designer, ux-designer, world-builder, writer, localization-lead, community-manager, prototyper, qa-lead, qa-tester, release-manager, sound-designer, technical-artist, analytics-engineer, accessibility-specialist

## 업데이트 이력 (최근 10 커밋)

| 날짜 | 내용 |
|---|---|
| 2026-05-03 | Fix architecture-decision skill: duplicate heading + broken step numbering |
| 2026-05-02 | Fix: session-start preview shows most recent state instead of oldest |
| 2026-05-02 | Fix: rg --type gdscript invalid — use --glob *.gd |
| 2026-04-24 | Fix missing allowed-tools in /architecture-decision and /story-done |
| 2026-04-10 | Fix log-agent hooks reading wrong field |
| 2026-04-07 | v1.0.0-beta 릴리스 |
| 2026-04-07 | v0.6.0: full skill/agent QA pass, 3 new agents |
| 2026-04-06 | v0.5.0: CCGS Skill Testing Framework, skill-improve, 4 new skills |

## 오픈 이슈 샘플

- #46: "실제로 완성 가능한 게임을 만들 수 있나?" (커뮤니티 질문)
- #40: Adobe, Blender MCP + Unity MCP 통합 요청
- #22: Web/THREE.js 지원 요청
- #24: Codex Skill 지원 시점 문의

## 평가

**강점**: MIT 라이선스, 풍부한 스킬셋(72개), 엔진 3종 지원, 훅 기반 자동화, 활발한 버그픽스
**약점**: 기여자 1명(버스 팩터 1), 실제 완성 게임 사례 미확인(#34 이슈), 문서가 프레임워크 자체에 집중되어 게임별 적용 예시 부족

(Source: [[GitHub Donchitos Claude Code Game Studios]])
