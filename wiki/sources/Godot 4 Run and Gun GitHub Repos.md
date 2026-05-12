---
type: source
title: Godot 4 Run and Gun GitHub Repos
tags: [source, godot, github, run-and-gun, open-source, reference]
aliases: []
cssclasses: []
created: 2026-05-12
updated: 2026-05-12
source_type: repo-catalog
confidence: medium
---

# Godot 4 Run and Gun GitHub Repos

Godot 4 + GDScript 기반 런앤건/2D 슈팅 게임 레포 카탈로그. 2026-05-12 기준.

> [!gap] 고스타(>100) Godot 4 사이드스크롤링 런앤건 GDScript 레포 **없음** — 에코시스템 갭이 실재. 조각별 조합 전략이 현실적.

---

## A. 직접 런앤건 레포

### Succubus-With-A-Gun (Ideal-Void)
- **URL**: https://github.com/Ideal-Void/Succubus-With-A-Gun
- **설명**: "Metal Slug와 Celeste에서 영감받은 2D 사이드스크롤링 플랫포머/슈터"
- **엔진**: Godot 4 + GDScript
- **Stars**: ~1
- **Echo 관련성**: **최고** — 메탈슬러그 스타일 직접 명시
- Confidence: HIGH (설명 직접 일치)

### Chronobot (DevTheKar)
- **URL**: https://github.com/DevTheKar/Chronobot
- **설명**: 2D 슈팅 플랫포머. GDScript 100%. 이동·점프·슈팅·적·다중 레벨.
- **YouTube 시리즈 동반**: https://www.youtube.com/playlist?list=PLWTXKdBN8RZdvd3bbCC4mg2kHo3NNnBz7
- **Stars**: 0
- Confidence: HIGH (YouTube 시리즈 확인)

### JSolde/Godot-demo-2D-Side-Scrolling-and-Wraparound-Shooter
- **URL**: https://github.com/JSolde/Godot-demo-2D-Side-Scrolling-and-Wraparound-Shooter
- **설명**: Defender 아케이드 스타일 2D 스크롤 슈터 데모. Godot 4.2-4.4.1 테스트 완료.
- **기능**: 랩어라운드 월드, 적 스폰, 레이더
- **주의**: 플랫포밍 없음 — 수평 스크롤 슈터 아키텍처 참고용
- Confidence: HIGH (직접 fetch 확인, Godot 4.x)

---

## B. GDQuest 마이크로 데모 (모듈식 조합)

GDQuest는 단일 풀 게임이 아닌 **컴포넌트 데모**를 제공. 조합하면 런앤건 전투 시스템 구성 가능.

| 레포 | Stars | 기능 | URL |
|---|---|---|---|
| godot-4-ranged-attacks | ~6 | 원거리 공격 시스템 | https://github.com/gdquest-demos/godot-4-ranged-attacks |
| godot-4-hitbox-hurtbox | ~5 | 히트박스/허트박스 피격 판정 | https://github.com/gdquest-demos/godot-4-hitbox-hurtbox |
| godot-4-homing-missiles | - | 유도 미사일 | https://github.com/gdquest-demos/godot-4-homing-missiles |
| godot-4-reloading-ammo | - | 재장전/탄약 시스템 | https://github.com/gdquest-demos/godot-4-reloading-ammo |
| godot-4-juicy-attack | - | 공격 애니메이션 폴리시 | https://github.com/gdquest-demos/godot-4-juicy-attack |

모두 Confidence: HIGH (GDQuest 공식 org)

---

## C. 슈터 아키텍처 참고 (부분 적용)

### quiver-dev/top-down-shooter-core
- **URL**: https://github.com/quiver-dev/top-down-shooter-core
- **설명**: Godot 4 탑다운 슈터 오픈소스 템플릿
- **주의**: 사이드스크롤 아님 — 전투/슈팅 아키텍처만 참고
- Confidence: MEDIUM

### GDQuest 3D TPS Controller
- **URL**: https://github.com/gdquest-demos/godot-4-3d-third-person-controller
- **Stars**: 945
- **설명**: 달리기·점프·조준·슈팅·수류탄 투척 포함. 3D이나 슈팅 상태머신 아키텍처 참고용.
- Confidence: HIGH (구조 참고용)

---

## D. 불릿 풀 시스템

### qurobullet (quinnvoker)
- **URL**: https://github.com/quinnvoker/qurobullet
- **설명**: Godot GDExtension 기반 BulletServer. 풀 관리·충돌 보고·라이프사이클.
- **주의**: Godot 4.6 호환성 미검증 (GDExtension API 변경 가능)
- Confidence: MEDIUM

### Godot Asset Library "Fire Bullets" (#1990)
- **URL**: https://godotengine.org/asset-library/asset/1990
- **설명**: GDExtension 없음. 쿨다운·각도 분산·산탄 아크·스폰 포인트.
- Confidence: HIGH (Asset Library 등록)

---

## Echo 적용 우선순위

```
조합 전략:
1. GDQuest Side-Scroller Course (이동 베이스)
   + godot-4-ranged-attacks (슈팅)
   + godot-4-hitbox-hurtbox (피격 판정)
   = 런앤건 전투 핵심 레이어

2. Succubus-With-A-Gun (전체 프로젝트 구조 참고)
   or Chronobot (YouTube + 코드 동시 참고)

3. "Fire Bullets" 애셋 또는 BulletServer 직접 구현
   (qurobullet은 4.6 호환성 확인 후)
```

---

## 관련 페이지

- [[Godot 4 Run and Gun Tutorial Resources]] — YouTube + GDQuest 튜토리얼
- [[Run and Gun Bullet System Pattern]] — BulletServer 구현 패턴
- [[Research Boss Rush GitHub Baseline Repos]] — 보스 AI 레포 (LimboAI 등)
