---
type: source
title: GitHub Donchitos Claude Code Game Studios
created: 2026-05-08
updated: 2026-05-08
tags:
  - ccgs
  - framework
  - ai-agents
  - github
source_url: https://github.com/Donchitos/Claude-Code-Game-Studios
fetched: 2026-05-08
key_claims:
  - "49개 에이전트, 72개 스킬, 12개 훅으로 구성된 인디 게임 스튜디오 AI 조율 프레임워크"
  - "MIT 라이선스, is_template: true — 직접 포크 가능"
  - "2026-02-12 생성, 2026-05-03 마지막 푸시, 단일 기여자(Donchitos)"
  - "스타 17,713개, 포크 2,582개 — 높은 커뮤니티 관심도"
  - "v1.0.0-beta: 2026-04-07 릴리스"
related:
  - "[[Donchitos CCGS Repo]]"
  - "[[CCGS Framework]]"
  - "[[Research CCGS Framework And Local Drift]]"
confidence: high
---

# GitHub Donchitos Claude Code Game Studios

## 소스 개요

GitHub API (`gh api repos/Donchitos/Claude-Code-Game-Studios`) 및 콘텐츠 API를 통해 2026-05-08 직접 수집한 데이터.

## 핵심 수집 데이터

### 저장소 메타데이터
- **ID**: 1155965274
- **생성**: 2026-02-12T05:21:38Z
- **마지막 푸시**: 2026-05-03T11:58:24Z
- **스타**: 17,713 / **포크**: 2,582 / **구독자**: 152
- **오픈 이슈**: 15 / **기여자**: 1 (Donchitos, 37 커밋)
- **라이선스**: MIT
- **템플릿**: true
- **토픽**: ai-agents, claude, claude-code, game-design, game-development, godot, indie-game-dev, unity, unreal-engine

### 구조 데이터 (gh API tree)
- 전체 파일: 412개
- `.claude/agents/`: 49개
- `.claude/skills/*/SKILL.md`: 72개 스킬
- `.claude/hooks/`: 12개 셸 스크립트
- `.claude/docs/`: 61개 문서

### CLAUDE.md 내용 확인
상류(upstream) CLAUDE.md는 72줄로 이 프로젝트의 로컬 CLAUDE.md와 내용 일치 확인됨.
기술 스택 섹션은 `[CHOOSE: Godot 4 / Unity / Unreal Engine 5]` 형태로 미설정 상태가 기본값.

### 최근 커밋 이력 (상위 10)
| 날짜 | SHA | 메시지 요약 |
|---|---|---|
| 2026-05-03 | 7ad8ab31 | Fix architecture-decision skill heading/numbering |
| 2026-05-02 | a1697d67 | Fix session-start preview order |
| 2026-05-02 | 9a4243b3 | Fix rg --type gdscript → --glob *.gd |
| 2026-04-24 | 9ccc5440 | Fix allowed-tools in /architecture-decision |
| 2026-04-10 | 666e0fcb | Fix log-agent hooks wrong field |
| 2026-04-07 | 49d1e457 | Release v1.0.0-beta |
| 2026-04-07 | 223949a0 | Prep v1 beta release |
| 2026-04-07 | 3614e1db | v0.6.0: skill/agent QA pass |
| 2026-04-06 | a73ff759 | v0.5.0: Skill Testing Framework |

## 신뢰도 평가

- **데이터 출처**: GitHub REST API — 1차 소스, 신뢰도 높음
- **콘텐츠 검증**: CLAUDE.md 원문 직접 확인
- **수집 방법**: `gh api` CLI — 인증 세션 사용, rate-limit 없음
