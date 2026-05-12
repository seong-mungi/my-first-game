---
title: CCGS Codex Port Pattern
tags: [concept, ccgs, codex, openai, fork, porting]
aliases: [Codex Game Studios, CCGS Codex]
created: 2026-05-12
updated: 2026-05-12
---

# CCGS → OpenAI Codex 포팅 패턴

CCGS의 49-에이전트 구조를 Claude Code가 아닌 OpenAI Codex에서 실행하기 위한 어댑터 레이어 패턴.

## Fork 목록

| Repo | ⭐ | 생성일 | 특징 |
|---|---|---|---|
| pa4uslf/Codex-Game-Studios | 3 | 2026-05-03 | 원조 Codex 포팅 |
| eiichimo/Codex-Game-Studios | 2 | 2026-05-05 | pa4uslf 변형 |

## 포팅 구조

Codex 어댑터 레이어는 원본 `.claude/` 워크플로 에셋을 그대로 유지하고 위에 추가:

```
원본 CCGS
├── .claude/          ← 그대로 유지 (canonical source)
├── AGENTS.md         ← NEW: Codex 에이전트 진입점
├── .agentlens/
│   └── INDEX.md      ← NEW: Codex용 인덱스
└── .agents/
    └── skills/       ← NEW: Codex 스킬 어댑터
```

## 의미

- Claude Code에 종속되지 않고 동일한 스튜디오 계층 구조를 OpenAI 생태계에서 실행하려는 수요가 존재.
- 두 개의 독립적인 fork(pa4uslf, eiichimo)가 비슷한 시기(2026-05-03, 2026-05-05)에 생성 → 동일 니즈를 독립적으로 해결.

> [!gap] pa4uslf와 eiichimo의 구체적 차이는 README 확인 필요. 현재 description이 동일하여 실질적 차이 불명확.

## 관련 페이지

- [[Research CCGS Fork Landscape]] — 전체 fork 순위
- [[CCGS Scaffolder Scope Boundary]] — CCGS 원본 범위
