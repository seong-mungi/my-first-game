---
title: Boss Rush Godot Implementation Pattern
tags: [concept, godot, boss-rush, implementation, FSM, AI, pattern]
aliases: [보스러시 구현 패턴]
cssclasses: []
created: 2026-05-12
updated: 2026-05-12
---

# Boss Rush Godot Implementation Pattern

Godot 4 GDScript 기반 보스러시 게임 구현의 핵심 패턴. Echo 프로젝트 아키텍처 직접 적용 가능.

---

## 보스 AI 구현 3가지 접근법

| 접근법 | 도구 | 장점 | 단점 | 추천 대상 |
|---|---|---|---|---|
| **FSM (Finite State Machine)** | 노드 기반 or gd-YAFSM | 단순, 직관적, 디버그 용이 | 상태 증가 시 복잡도 증가 | 단순 보스 (3-5 패턴) |
| **Behavior Tree** | LimboAI | 복잡 AI 표현, 재사용 용이 | 학습 비용 높음 | 다단계 보스 (6+ 패턴) |
| **AnimationTree + 스크립트** | Godot 내장 | 에디터 친화, 비주얼 확인 | AI 로직과 분리 어려움 | 비주얼 중심 페이즈 전환 |

**Echo 권고**: FSM 기반 + AnimationTree 조합 (Cuphead 모델 — [[Deterministic Game AI Patterns]])

---

## 보스 페이즈 구조 설계

**기본 패턴 (mseffner/bullet-hell-shooter 레퍼런스)**:

```
Boss
├── Phase 1 (HP 100%→75%) — 기본 패턴
├── Phase 2 (HP 75%→50%)  — 속도 증가 + 패턴 추가
├── Phase 3 (HP 50%→25%)  — 신규 공격 추가
└── Phase 4 (HP 25%→0%)   — 격노 모드
```

**Godot 4 FSM 노드 구조**:
```
BossEnemy (Node2D)
├── StateMachine (Node)
│   ├── IdleState
│   ├── Phase1State
│   ├── Phase2State
│   ├── Phase3State
│   └── DeathState
├── AnimationPlayer
├── HurtBox (Area2D)
└── AttackPatterns (Node)
    ├── BulletSpawner
    └── ChargeAttack
```

---

## 핵심 플러그인 & 에드온

### LimboAI (보스 AI용 권장)
- **레포**: [limbonaut/limboai](https://github.com/limbonaut/limboai)
- **특징**: C++ 플러그인 + GDScript 완전 지원, Behavior Tree 에디터 내장
- **설치**: GDExtension (Asset Library) or C++ 모듈 빌드
- **적합 케이스**: 복잡한 보스 패턴 (6+ 행동, 조건부 전환)
- **주의**: Godot 4.4-4.5 버전용 Asset ID: 3787 / 4.3 버전: 3228

### gd-YAFSM (단순 FSM용)
- **레포**: [imjp94/gd-YAFSM](https://github.com/imjp94/gd-YAFSM)
- **특징**: AnimationTree 스타일 UI, 클래스 상속 불필요
- **적합 케이스**: 단순 페이즈 전환 (3-5 상태)

### GDQuest FSM (학습용)
- **URL**: https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/
- **특징**: 노드 기반 FSM 패턴 무료 튜토리얼 + 예제 코드
- **적합 케이스**: 첫 보스 구현 학습

---

## 보스러시 게임 핵심 시스템 체크리스트

```
[ ] 보스 HP 바 UI (페이즈별 색상 변화)
[ ] 페이즈 전환 연출 (flash, 일시정지, 사운드)
[ ] 피격 판정 (HurtBox/HitBox Area2D)
[ ] 패턴 스케줄러 (무작위 or 순서형)
[ ] 텔레그래프 시스템 (공격 예고 신호)
[ ] 보스 죽음 연출 (파티클, 슬로우모)
[ ] 보스 간 전환 씬 (이동/로딩)
[ ] 글로벌 점수/클리어타임 추적
```

---

## 참고 레포 우선순위 (Echo 적용 기준)

1. **[DevKinantan/BossRush_2024](https://github.com/DevKinantan/BossRush_2024)** — Godot 4 GDScript, 구조 참고
2. **[mseffner/bullet-hell-shooter](https://github.com/mseffner/bullet-hell-shooter)** — 멀티 페이즈 보스 3개 × 4페이즈 구현 참고
3. **[limbonaut/limboai](https://github.com/limbonaut/limboai)** — Godot 4 보스 AI (BT + SM)
4. **[gdquest-demos/godot-make-pro-2d-games](https://github.com/gdquest-demos/godot-make-pro-2d-games)** — 보스 인카운터 포함 프로 수준 코드

---

## Echo 관련성

- 시간 되감기 + 보스 FSM = 되감기 시 보스 상태도 롤백 필요 → 상태 스냅샷 설계 필수
- Echo의 결정론 요구사항: 보스 패턴은 난수 없이 순서형으로 설계 (Cuphead 모델)
- LimboAI BT는 상태 스냅샷 직렬화 지원 여부 확인 필요

> [!gap] Echo의 시간 되감기 + LimboAI BT 호환성은 미검증. 직접 테스트 필요.

---

## 출처

- GitHub: limbonaut/limboai README (2024-2025)
- GDQuest: Finite State Machine tutorial (gdquest.com)
- GitHub: DevKinantan/BossRush_2024 (Godot 4 잼 제출작)
- GameFromScratch: LimboAI for Godot 4.x 리뷰

→ [[Research Boss Rush GitHub Baseline Repos]]
→ [[Boss Rush Niche Genre Opportunity]]
→ [[Deterministic Game AI Patterns]]
