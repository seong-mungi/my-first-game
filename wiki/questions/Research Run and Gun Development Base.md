---
type: synthesis
title: "Research: Run and Gun Development Base"
created: 2026-05-12
updated: 2026-05-12
tags:
  - research
  - run-and-gun
  - godot
  - implementation
  - game-design
status: stable
related:
  - "[[Run and Gun Enemy AI Archetypes]]"
  - "[[Run and Gun Player Character Architecture]]"
  - "[[Run and Gun Bullet System Pattern]]"
  - "[[Run and Gun Level Design Patterns]]"
  - "[[Godot 4 Run and Gun GitHub Repos]]"
  - "[[Godot 4 Run and Gun Tutorial Resources]]"
  - "[[Run and Gun Dev Community Resources]]"
  - "[[Run and Gun Base Systems]]"
  - "[[Run and Gun Extension Systems]]"
sources:
  - "[[Godot 4 Run and Gun Tutorial Resources]]"
  - "[[Godot 4 Run and Gun GitHub Repos]]"
  - "[[Run and Gun Dev Community Resources]]"
---

# Research: Run and Gun Development Base

## Overview

런앤건 개발 구현 베이스 — Godot 4 튜토리얼·GitHub 레포·적 AI 아키타입·플레이어 캐릭터 구조·불릿 시스템·레벨 디자인 패턴 3라운드 종합 (2026-05-12). 기존 장르 분석([[Research Run and Gun Genre]], [[Research Run and Gun Success Patterns]])과 구별: 이 페이지는 **구현** 기반에 집중.

---

## Key Findings

### 1. Godot 4 전용 런앤건 오픈소스 레포는 극히 소수
Metal Slug 스타일 Godot 4 + GDScript 레포: `Succubus-With-A-Gun` (⭐1) 만이 직접 일치. 에코시스템 갭이 실재함 — 조각별 조합 전략이 현실적.
최적 조합: GDQuest 이동 모듈(locomotion) + ranged-attacks/hitbox-hurtbox 마이크로 데모(전투) + Chronobot(프로젝트 구조 참고). (Source: [[Godot 4 Run and Gun GitHub Repos]])

### 2. 적 AI 6가지 아키타입 — 각각 고유 FSM
런앤건 적은 6가지 아키타입으로 분류: 그런트·저격수·순찰 경비·포대·비행체·도약체. 각 타입은 고유한 감지 반경, 공격 패턴, 텔레그래프 애니메이션을 가진다. (Source: [[Run and Gun Enemy AI Archetypes]])

### 3. 플레이어는 이동+액션 이중 레이어 FSM
이동 상태(IDLE/WALK/RUN/JUMP/FALL)와 액션 상태(NOT_SHOOTING/SHOOTING/RELOADING)를 직교 레이어로 분리. `IDLE_SHOOTING`, `WALK_SHOOTING`처럼 조합 폭발을 피할 수 있음. 코요테 타임 + 점프 버퍼가 선결 구현. (Source: [[Run and Gun Player Character Architecture]])

### 4. BulletServer 패턴 — 풀링이 필수
총알은 `queue_free()`/`instantiate()` 금지, 비활성화/재활성화 재사용. `BulletServer` 싱글턴이 풀 관리. `Marker2D` 자식 노드가 발사 위치 앵커 — 무기 교체 시 씬만 교체하면 발사 위치도 자동 교체. (Source: [[Run and Gun Bullet System Pattern]])

### 5. 무기 교체는 WeaponData Resource 패턴
`WeaponData` Resource 서브클래스로 무기 데이터 정의. `WeaponHolder` 노드의 자식 씬 교체로 전환. 플레이어 로직을 건드리지 않음. (Source: [[Run and Gun Bullet System Pattern]])

### 6. 레벨 설계는 스크롤 위치 기반 스폰 레코드
`{scroll_position, spawn_x/y, enemy_type, ai_pattern}` 구조체로 완전 결정론 구현 가능. 적은 월드에 비활성으로 존재하다가 카메라가 도달 시 활성화. Echo의 결정론 요구사항과 직접 호환. (Source: [[Run and Gun Level Design Patterns]])

### 7. 레벨 페이싱 3원칙
① 강도 곡선 (낮음→에스컬레이션→회복→피날레) ② 패시브 안전지대 차단 (스킬로 도달하는 안전지대만 허용) ③ 새 적 첫 등장은 저위험 맥락에서 (단독, 넓은 화면). (Source: [[Run and Gun Level Design Patterns]])

### 8. Slynyrd 픽셀아트 블로그 = 런앤건 애니메이션 권위 레퍼런스
2026년 1월 갱신. 모든 이동 애니메이션(idle/walk/run/jump/fall)에 "슈팅 오버레이 변형" 프레임 필요. 점프 슈팅은 최소 1프레임으로도 성립. (Source: [[Godot 4 Run and Gun Tutorial Resources]])

---

## Key Entities

- [[Succubus-With-A-Gun]]: Godot 4 + GDScript 메탈슬러그 영감 레포 — 가장 직접적 구조 참고
- GDQuest (gdquest-demos org): ranged-attacks, hitbox-hurtbox, reloading-ammo 마이크로 데모 제공
- Chronobot (DevTheKar): YouTube 시리즈 + GitHub 레포, 2D 슈팅 플랫포머
- qurobullet (quinnvoker): Godot GDExtension 불릿 풀 구현

---

## Key Concepts

- [[Run and Gun Enemy AI Archetypes]]: 6가지 적 타입 FSM 설계
- [[Run and Gun Player Character Architecture]]: 이중 레이어 FSM + 코요테 타임 + 점프 버퍼
- [[Run and Gun Bullet System Pattern]]: BulletServer 풀링 + 무기 교체 패턴
- [[Run and Gun Level Design Patterns]]: 스크롤 스폰 레코드 + 페이싱 원칙
- [[Godot 4 Run and Gun Tutorial Resources]]: YouTube 5편 + GDQuest 마이크로 데모 카탈로그

---

## Contradictions

- **NavigationAgent 2D vs 3D**: 검색된 Godot 4 적 AI 튜토리얼은 3D 기반 (`NavigationAgent3D`). Echo는 2D — API 이름만 다르고 패턴은 동일하나, 타일맵 기반 네비게이션 메시 설정 방법은 별도 확인 필요.
- **코요테 타임 기본값**: 커뮤니티 권고값 6-12 프레임은 실측이 아닌 컨벤션. Echo에서 최적값은 플레이테스트로 결정.

---

## Open Questions

- Echo 결정론 요구사항 + NavigationAgent2D 경로 탐색 조합 가능한가? (경로 탐색은 프레임별 비결정론 요소 포함 가능)
- qurobullet GDExtension의 Godot 4.6 호환성 확인 필요
- 시간 되감기 + 적 AI FSM 상태 롤백: 적 감지 반경·추적 상태도 되감기 대상인가?
- 수평 스크롤 카메라 시스템 (zone-trigger vs smooth-follow vs 잠금) — Echo에 적합한 방식 미결정

---

## Sources

- [[Godot 4 Run and Gun GitHub Repos]]: Succubus-With-A-Gun, Chronobot, GDQuest 마이크로 데모
- [[Godot 4 Run and Gun Tutorial Resources]]: YouTube 5편 + GDQuest + Slynyrd 픽셀아트 블로그
- [[Run and Gun Dev Community Resources]]: Discord + Reddit + Godot 공식 채널
