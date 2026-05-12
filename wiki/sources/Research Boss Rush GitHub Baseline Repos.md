---
title: Research Boss Rush GitHub Baseline Repos
tags: [synthesis, boss-rush, github, open-source, godot, baseline, reference]
aliases: []
cssclasses: []
created: 2026-05-12
updated: 2026-05-12
---

# Research Boss Rush GitHub Baseline Repos

Boss Rush 게임 개발 시 참고할 수 있는 GitHub 오픈소스 레포지토리 카탈로그.  
3라운드 웹 검색 (2026-05-12). Sources: github.com, itch.io, gamefromscratch.com, gdquest.com.

---

## 핵심 발견

1. **Boss Rush Jam** (itch.io) = 연간 개최 — 매년 다수의 오픈소스 레포 생성
2. **Godot 4 전용 보스 레포**는 소수 — 대부분 Unity 또는 엔진 미특정
3. **LimboAI** = Godot 4 보스 AI 구현의 사실상 표준 플러그인
4. 고품질 보스러시 오픈소스는 드물다 → 게임잼 제출작이 주요 레퍼런스

---

## Boss Rush 게임 GitHub 레포 카탈로그

### Godot 4 보스러시 레포

| 레포 | 설명 | 비고 |
|---|---|---|
| [DevKinantan/BossRush_2024](https://github.com/DevKinantan/BossRush_2024) | Godot 4 보스러시 잼 2024 제출작 "VVarmonger" — Void 행성계 SF | **Echo 엔진 일치** |
| [epicjim1/BossRushJam2025](https://github.com/epicjim1/BossRushJam2025) | Boss Rush Jam 2025 제출작 | Godot 여부 미확인 |
| [icutter/boss-rush-jam-2024](https://github.com/icutter/boss-rush-jam-2024) | "Lab Escape" — 2024 잼 제출 | Godot 여부 미확인 |

### 엔진 독립 / 기타 보스러시 레포

| 레포 | 엔진/언어 | 설명 |
|---|---|---|
| [mseffner/bullet-hell-shooter](https://github.com/mseffner/bullet-hell-shooter) | - | 불릿헬 보스러시, **3 보스 × 4 페이즈** 구조 |
| [DariusMiu/Irbis](https://github.com/DariusMiu/Irbis) | - | 2D 보스러시 게임 |
| [adamgraham/boss-rush](https://github.com/adamgraham/boss-rush) | - | 탑다운 트윈스틱 슈터, 보스전만 구성 |
| [thismarvin/robosses](https://github.com/thismarvin/robosses) | Python/Pygame | 2D 보스러시 플랫포머 (GameShell Jam 2019) |

### Godot 4 참고 아키텍처 레포 (보스러시 아님, 패턴 참고용)

| 레포 | 설명 |
|---|---|
| [gdquest-demos/godot-make-pro-2d-games](https://github.com/gdquest-demos/godot-make-pro-2d-games) | 보스 인카운터 포함 + 인벤토리/샵 시스템 |
| [limbonaut/limboai](https://github.com/limbonaut/limboai) | Godot 4 Behavior Tree + State Machine 플러그인 |
| [godot-addons/godot-finite-state-machine](https://github.com/godot-addons/godot-finite-state-machine) | Godot FSM 에드온 |
| [imjp94/gd-YAFSM](https://github.com/imjp94/gd-YAFSM) | AnimationTree 스타일 FSM — 보스 페이즈 전환에 적합 |

---

## Boss Rush Game Jam 생태계

**Boss Rush Jam** (itch.io 연간 행사):
- 2024: `icutter/boss-rush-jam-2024`, `DevKinantan/BossRush_2024`
- 2025: `epicjim1/BossRushJam2025`, 기타 다수
- 형식: 1-2주 잼 → 대부분 소규모 팀 제작 → GitHub 오픈소스

**활용법**: 잼 제출작은 코드 품질보단 아이디어·구조 참고용으로 적합.

---

## Echo 프로젝트 적용 추천 레포

1. **[DevKinantan/BossRush_2024](https://github.com/DevKinantan/BossRush_2024)** — Godot 4 + GDScript, Echo 엔진과 일치
2. **[mseffner/bullet-hell-shooter](https://github.com/mseffner/bullet-hell-shooter)** — 멀티 페이즈 보스 구조 참고 (3 보스 × 4 페이즈)
3. **[limbonaut/limboai](https://github.com/limbonaut/limboai)** — 보스 AI 구현 시 BT+SM 플러그인

> [!gap] 각 레포의 star 수, 활성도, 라이선스는 GitHub 직접 확인 필요. 링크는 검색 결과 기반.

---

## 관련 페이지

- [[Boss Rush Niche Genre Opportunity]]
- [[Boss Rush Godot Implementation Pattern]]
- [[Deterministic Game AI Patterns]]
