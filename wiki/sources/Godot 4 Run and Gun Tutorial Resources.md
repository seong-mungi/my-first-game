---
type: source
title: Godot 4 Run and Gun Tutorial Resources
tags: [source, godot, tutorial, youtube, run-and-gun, implementation]
aliases: []
cssclasses: []
created: 2026-05-12
updated: 2026-05-12
source_type: tutorial-catalog
confidence: medium
---

# Godot 4 Run and Gun Tutorial Resources

Godot 4 런앤건/2D 슈팅 플랫포머 구현 튜토리얼 카탈로그. YouTube·GDQuest·Godot Recipes·Slynyrd.

> [!gap] "런앤건" 라벨 전용 Godot 4 튜토리얼 시리즈는 없음. 2D 슈팅 플랫포머 + 컴포넌트 조합 전략이 최선.

---

## A. YouTube 튜토리얼

| 우선순위 | 제목 | URL | 내용 | 신뢰도 |
|---|---|---|---|---|
| ★★★ | Chronobot — 2D Metroidvania Shooting Platformer (Playlist) | https://www.youtube.com/playlist?list=PLWTXKdBN8RZdvd3bbCC4mg2kHo3NNnBz7 | 전체 슈팅 플랫포머 시리즈. 이동·슈팅·애니메이션·적·다중 레벨. GitHub 레포 동반. | MEDIUM |
| ★★★ | 2D Platformer Attacks and Enemy Setup | https://www.youtube.com/watch?v=NVAXjTzqTyE | 공격 시스템 + 적 설정 단독 튜토리얼. 런앤건 전투 레이어 직접 적용 가능. | HIGH |
| ★★ | 2D Platformer Tutorial in Godot 4 (Playlist) | https://www.youtube.com/playlist?list=PLCcur7_Y2zTdKIQ2oM2Ec8MEfeBnAbEXT | 멀티파트 2D 플랫포머 시리즈. 공격 + 적 포함. | MEDIUM |
| ★★ | Make A 2D Top-down Shooter In 10 MINUTES (Godot 4) | https://www.youtube.com/watch?v=DA7O9hjjHjE | 빠른 슈터 입문. 탑다운이지만 총알 스폰·플레이어 조준·충돌 패턴 전이 가능. | HIGH |
| ★ | Finite State Machines in Godot 4 Under 10 Minutes | https://www.youtube.com/watch?v=ow_Lum-Agbs | FSM 기초 프라이머 — 적 AI 구현 전 선행 | MEDIUM |

---

## B. GDQuest (권위 있는 Godot 4 튜토리얼)

### Side-Scroller Character Module (Course)
- **URL**: https://school.gdquest.com/courses/learn_2d_gamedev_godot_4/side_scroller_character/overview
- **내용**: 운동역학적 점프, 수평/수직 점프 제어, 더블 점프, 코요테 타임, 파티클 폴리시
- **주의**: 슈팅 미포함 — 이동 레이어 기반만 제공
- Confidence: HIGH (GDQuest school 확인)

### GDQuest 마이크로 데모 (GitHub)
| 레포 | 기능 | URL |
|---|---|---|
| godot-4-ranged-attacks | 원거리 공격 (AOE 포함) | https://github.com/gdquest-demos/godot-4-ranged-attacks |
| godot-4-hitbox-hurtbox | 히트박스/허트박스 | https://github.com/gdquest-demos/godot-4-hitbox-hurtbox |
| godot-4-homing-missiles | 유도 미사일 | https://github.com/gdquest-demos/godot-4-homing-missiles |
| godot-4-reloading-ammo | 재장전/탄약 | https://github.com/gdquest-demos/godot-4-reloading-ammo |
| godot-4-juicy-attack | 공격 폴리시 | https://github.com/gdquest-demos/godot-4-juicy-attack |

모두 Confidence: HIGH

---

## C. Godot Recipes (kidscancode)

- **URL**: https://kidscancode.org/godot_recipes/4.x/
- **2D 슈팅 레시피**: https://kidscancode.org/godot_recipes/4.x/2d/2d_shooting/index.html
- **내용**: `Marker2D` 스폰 포인트 패턴, 인스턴스 + Area2D 충돌, 간단한 불릿 스크립트
- **특징**: 짧은 레시피 형식 — 특정 패턴만 빠르게 참고
- Confidence: HIGH (Godot 공식 커뮤니티 사이트)

---

## D. Slynyrd 픽셀아트 블로그

- **URL**: https://www.slynyrd.com/blog/2026/1/26/side-view-run-n-gun
- **갱신**: 2026년 1월 26일
- **내용**: 사이드뷰 런앤건 애니메이션 프레임 가이드
- **핵심 발견**:
  - 모든 이동 상태(idle/walk/run/jump/fall)에 "슈팅 오버레이 변형" 프레임 필요
  - 점프 슈팅 = 최소 1프레임으로 성립
  - `AnimationTree` 블렌드 트리로 상체 슈팅 레이어 구현 권장
- Confidence: HIGH (2026년 1월 직접 확인)

---

## E. 학술/기술 참고

### Boss Engineering (Clemens Fromm, PDF)
- **URL**: https://collab.dvb.bayern/download/attachments/77832795/BT_Clemens_Fromm_Boss_Engineering.pdf
- **내용**: 보스 시스템 기술 아키텍처 — 페이즈 클래스·공격 패턴 클래스·불리언 플래그
- Confidence: MEDIUM (미fetch)

### Godot 4 Enemy AI Tutorial (CodingQuests, 2026-02)
- **URL**: https://codingquests.io/blog/godot-4-enemy-ai-tutorial
- **내용**: PATROL/CHASE/ATTACK FSM, Marker2D 웨이포인트, NavigationAgent2D, 2026년 2월
- Confidence: HIGH (직접 fetch 확인)

---

## Echo 적용 우선순위

```
Step 1: GDQuest Side-Scroller Module — 이동 레이어 기반 확립
Step 2: Chronobot YouTube + GitHub — 전체 프로젝트 구조 참고
Step 3: godot-4-ranged-attacks + godot-4-hitbox-hurtbox — 전투 컴포넌트
Step 4: Godot Recipes 2D Shooting — Marker2D 발사 패턴
Step 5: Slynyrd 블로그 — 애니메이션 프레임 계획 전 참고
Step 6: CodingQuests AI Tutorial — 적 AI FSM 구현 시
```

---

## 관련 페이지

- [[Godot 4 Run and Gun GitHub Repos]] — 레포 카탈로그
- [[Godot 4 Boss Tutorial Resources]] — 보스 전용 튜토리얼
- [[Run and Gun Player Character Architecture]] — 이동 + 슈팅 구현 패턴
- [[Run and Gun Enemy AI Archetypes]] — 적 AI 구현 패턴
