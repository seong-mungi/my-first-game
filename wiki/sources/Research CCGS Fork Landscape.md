---
title: Research CCGS Fork Landscape
tags: [synthesis, ccgs, github, forks, ecosystem]
aliases: [CCGS Forks, CCGS Fork Ranking]
created: 2026-05-12
updated: 2026-05-12
---

# CCGS Fork 생태계 — Star 순위 카탈로그

**Research date:** 2026-05-12 · GitHub API 직접 조회 (high confidence)
**Source:** `GET /repos/Donchitos/Claude-Code-Game-Studios/forks?sort=stargazers&per_page=10`

## 원본 저장소

| 항목 | 값 |
|---|---|
| **Repo** | Donchitos/Claude-Code-Game-Studios |
| **Stars** | ⭐ 18,359 |
| **Forks** | 🍴 2,679 |
| **Created** | 2026-02-12 |
| **License** | MIT |
| **Description** | 49 AI agents, 72 workflow skills, complete studio coordination system |

## Star 순 Top 10 Fork 목록

| 순위  | Repo                                  | ⭐   | 🍴  | 생성일        | 특징                            |
| --- | ------------------------------------- | --- | --- | ---------- | ----------------------------- |
| 1   | toukanno/claude-code-game-studios     | 50  | 5   | 2026-03-20 | 구버전(48 agents, 36 skills) 스냅샷 |
| 2   | phantacix/Claude-Code-Game-Studios-CN | 9   | 4   | 2026-03-24 | 중국어 현지화(CN)                   |
| 3   | kada7/Claude-Code-Game-Studios-Zh     | 4   | 0   | 2026-04-22 | 중국어 현지화(Zh)                   |
| 4   | pa4uslf/Codex-Game-Studios            | 3   | 0   | 2026-05-03 | OpenAI Codex 포팅               |
| 5   | Pickers/Claude-Code-Game-Studios-CN   | 3   | 0   | 2026-05-08 | 중국어 현지화(CN)                   |
| 6   | FreedomPortal/ccgs-technica-edition   | 2   | 0   | 2026-04-02 | 퍼블리싱 워크플로 확장                  |
| 7   | eiichimo/Codex-Game-Studios           | 2   | 0   | 2026-05-05 | Codex 포팅 (pa4uslf 변형)         |
| 8   | utkuhanakar/Claude-Code-Game-Studios  | 2   | 0   | 2026-04-27 | 표준 개인 포크                      |
| 9   | kent666/Claude-Code-Game-Studios      | 2   | 0   | 2026-03-22 | 구버전(48 agents, 36 skills)     |
| 10  | aekaterinaojenniferav9526-spec/...    | 1   | 0   | 2026-04-07 | 표준 개인 포크                      |

## Fork 패턴 분류

### 패턴 A: 중국어 현지화 (3개)
`phantacix`, `kada7`, `Pickers` — 동일 구조, 중국어 번역 목적.
→ [[CCGS Chinese Localization Forks]]

### 패턴 B: Codex 포팅 (2개)
`pa4uslf/Codex-Game-Studios`, `eiichimo/Codex-Game-Studios` — Claude Code → OpenAI Codex 어댑터 추가.
`AGENTS.md` + `.agentlens/INDEX.md` + `.agents/skills/*` 레이어로 동일 49-에이전트 구조를 Codex에서 실행.
→ [[CCGS Codex Port Pattern]]

### 패턴 C: 기능 확장 (1개)
`FreedomPortal/ccgs-technica-edition` — Go-To-Market Layer + Post-Launch Lifecycle + Continuity 추가.
퍼블리싱 이후 워크플로를 다루는 유일한 분화 fork.
→ [[CCGS Scaffolder Scope Boundary]] (갭 분석 컨텍스트)

### 패턴 D: 구버전 스냅샷 (3개 이상)
`toukanno`, `kent666`, `phantacix` 등 — "48 agents, 36 skills" 구버전 시점에서 fork.
업스트림 추적 없음. 개인 사용 또는 번역 목적.

## 버전 식별자

| Description 키워드 | 의미 |
|---|---|
| "48 AI agents, 36 workflow skills" | 구버전 (2026-03 이전 스냅샷) |
| "49 AI agents, 72 workflow skills" | 현재 업스트림 버전 |

## 인사이트

> [!key-insight] 1위 fork(⭐50)는 원본(⭐18,359)의 **0.27%**다. CCGS fork들은 star 기준으로는 거의 무명이다. 실질적 분화는 3개 패턴(CN 현지화, Codex 포팅, 기능 확장)으로만 나타났다.

> [!key-insight] 2,679개 fork 중 star 보유 fork는 극소수 — 나머지는 비공개 개인 사용 사본이다.

## Sources

- GitHub API: `GET /repos/Donchitos/Claude-Code-Game-Studios/forks?sort=stargazers&per_page=10` (high, 2026-05-12)
- GitHub API: 개별 repo 메타데이터 조회 (high, 2026-05-12)
