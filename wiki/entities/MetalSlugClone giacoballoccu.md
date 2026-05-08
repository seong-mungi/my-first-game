---
type: entity
title: MetalSlugClone giacoballoccu
created: 2026-05-08
updated: 2026-05-08
tags:
  - run-and-gun
  - metal-slug
  - unity
  - csharp
  - reference-project
related:
  - "[[metal-slug alfredo1995]]"
  - "[[Run and Gun Genre]]"
  - "[[IP Avoidance For Game Clones]]"
  - "[[Opinion MetalSlugClone Base Plus Metal Slug Reference]]"
  - "[[GitHub giacoballoccu MetalSlugClone]]"
confidence: high
---

# MetalSlugClone giacoballoccu

## 기본 정보

| 항목 | 값 |
|---|---|
| **저장소** | `giacoballoccu/MetalSlugClone` |
| **설명** | A three levels metal slug clone, available for mobile and desktop |
| **라이선스** | 없음 (No license) |
| **생성일** | 2020-04-18 |
| **최근 푸시** | 2021-04-28 (약 5년 전, 비활성) |
| **스타** | 23 |
| **포크** | 12 |
| **엔진** | Unity 2D |
| **언어** | C# |
| **플랫폼** | Android + Desktop |

> [!warning] 엔진 불일치
> 이 프로젝트는 **Unity/C#** 기반입니다. 현재 my-game 프로젝트는 **Godot 4** 를 사용합니다. 직접 스캐폴드로 사용할 수 없습니다.

## 코드 구조

```
Assets/Scripts/
├── Camera/           # CameraController, CameraManager, Parallaxing, TriggerCameraSwitch 등
├── Characters/
│   ├── Enemies/
│   │   ├── Boss/
│   │   │   ├── BossController.cs        # 1차 보스 (Boss1)
│   │   │   ├── Boss2/
│   │   │   │   ├── Boss2Controller.cs   # 2차 보스 — 독립 컨트롤러
│   │   │   │   ├── LineController.cs
│   │   │   │   ├── RockController.cs
│   │   │   │   └── TopController.cs
│   │   │   └── Boss3Controller.cs       # 3차 보스
│   │   ├── EnemyControl.cs
│   │   ├── EnemyBoatController.cs
│   │   └── HeliController.cs
│   ├── Health.cs
│   └── Player/
│       ├── PlayerController.cs
│       └── BulletMovement.cs
├── Managers/         # AudioManager, BulletManager, GameManager, UIManager 등
└── Missions/         # Mission1, Mission2, Mission3 스크립트
```

## 게임플레이 완성도

- **레벨 수**: 3개 (Mission 1-3)
- **보스**: 3개 (BossController, Boss2Controller, Boss3Controller)
- **플레이어**: 기본 이동·사격·피격 구현
- **적 종류**: 지상 병사, 보트, 헬리콥터, 반군 밴
- **수집물**: CollectibleController 구현
- **모바일 입력**: Joystick Pack 에셋 포함

## Boss2 구조 분석

`Boss2Controller.cs`는 `BossController`를 **상속하지 않는** 독립 컴포넌트다 — 즉 **컴포지션 방식**이며 추상 기반 클래스 패턴과 무관하다.

```csharp
// Boss2Controller: 단순 MonoBehaviour, 상속 없음
public class Boss2Controller : MonoBehaviour
{
    // Top(상체)과 Bottom(하체)을 별도 Animator로 제어
    public Animator topAnimator;
    public Animator bottomAnimator;

    void FixedUpdate()
    {
        if (isBossActive && health.IsAlive())
        {
            // 타이머 기반 단일 공격 패턴만 존재 — 2페이즈 없음
        }
    }
}
```

**2페이즈 설계 없음**: Boss2는 hp 임계값 기반 페이즈 전환이 구현되어 있지 않다. 단순 타이머 공격 루프만 있다.

## IP 리스크

- 저장소명에 "Metal Slug" 포함 → 클론임을 명시적으로 표방
- 라이선스 없음 → 법적 상태 불명확 (기본적으로 All Rights Reserved 해석)
- 상업용 기반으로 사용 시 IP 리스크 중첩 발생

(Source: [[GitHub giacoballoccu MetalSlugClone]], [[IP Avoidance For Game Clones]])
