---
type: source
title: GitHub giacoballoccu MetalSlugClone
created: 2026-05-08
updated: 2026-05-08
tags:
  - run-and-gun
  - unity
  - metal-slug
  - github
source_url: https://github.com/giacoballoccu/MetalSlugClone
fetched: 2026-05-08
key_claims:
  - "Unity 2D / C# 기반, 3레벨 Metal Slug 클론"
  - "라이선스 없음 (All Rights Reserved 기본 적용)"
  - "2021-04-28 이후 미업데이트 — 5년간 비활성"
  - "Boss2Controller는 BossController 비상속 — 추상 기반 클래스 패턴 없음"
  - "2페이즈 보스 설계 없음 — 단순 타이머 루프"
related:
  - "[[MetalSlugClone giacoballoccu]]"
  - "[[Opinion MetalSlugClone Base Plus Metal Slug Reference]]"
confidence: high
---

# GitHub giacoballoccu MetalSlugClone

## 소스 개요

GitHub API (`gh api repos/giacoballoccu/MetalSlugClone`) 및 콘텐츠 API를 통해 2026-05-08 수집.
`Boss2Controller.cs`, `BossController.cs` 원문 직접 확인.

## 핵심 수집 데이터

### 저장소 메타데이터
- **ID**: 256746918
- **생성**: 2020-04-18
- **마지막 푸시**: 2021-04-28 (약 5년 전)
- **스타**: 23 / **포크**: 12
- **라이선스**: 없음
- **언어**: C#
- **토픽**: android-game, clone, desktop, metal-slug, unity2d

### Boss2Controller.cs 원문 분석
```
class Boss2Controller : MonoBehaviour  // MonoBehaviour 직접 상속, 추상 기반 없음
├── top, topAnimator, bottomAnimator  // 상·하체 분리 Animator
├── FixedUpdate() → isBossActive 플래그 체크 → Fire() Coroutine
├── Fire() → 타이머 기반 단일 공격 패턴
└── activeBoss() → isBossActive = true
```

**2페이즈 없음**: hp 임계값 분기 없이 단일 공격 사이클만 반복.

### BossController.cs 원문 분석
```
class BossController : MonoBehaviour  // Boss1용, 상속 없음
├── speed, chargingSpeed, restSpeed, sprintSpeed  // 이동 속도 다단계
├── 투사체: normalFire, heavyBomb
└── FixedUpdate() → 플레이어 위치 추적 이동 + 발사 타이머
```

## 신뢰도 평가

- **데이터 출처**: GitHub REST API + 소스 코드 직접 확인 — 1차 소스
- **제한사항**: 라이선스 파일 부재로 법적 사용 가능성 불명확
