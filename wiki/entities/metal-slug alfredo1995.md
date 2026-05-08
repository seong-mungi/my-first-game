---
type: entity
title: metal-slug alfredo1995
created: 2026-05-08
updated: 2026-05-08
tags:
  - run-and-gun
  - metal-slug
  - unity
  - csharp
  - reference-project
related:
  - "[[MetalSlugClone giacoballoccu]]"
  - "[[Run and Gun Genre]]"
  - "[[Abstract Base Class Pattern]]"
  - "[[Boss Two Phase Design]]"
  - "[[IP Avoidance For Game Clones]]"
  - "[[Opinion MetalSlugClone Base Plus Metal Slug Reference]]"
  - "[[GitHub alfredo1995 metal-slug]]"
confidence: high
---

# metal-slug alfredo1995

## 기본 정보

| 항목 | 값 |
|---|---|
| **저장소** | `alfredo1995/metal-slug` |
| **설명** | Recreated the classic arcade action game (Metal Slug) in 2D style (Run and Gun) developed in the Unity Engine |
| **라이선스** | 없음 (No license) |
| **생성일** | 2024-03-16 |
| **최근 푸시** | 2026-01-29 (약 3개월 전, 저활성) |
| **스타** | 21 |
| **포크** | 7 |
| **엔진** | Unity 2D |
| **언어** | C# |
| **외부 에셋** | DOTween, Fungus (대화 시스템), iTween |

> [!warning] 엔진 불일치
> 이 프로젝트는 **Unity/C#** 기반입니다. 현재 my-game 프로젝트는 **Godot 4** 를 사용합니다. 직접 레퍼런스 이식이 불가능합니다.

## 커스텀 스크립트 구조

모든 커스텀 코드는 `Assets/SCRIPTS/` 에 집중:

```
CLASSEPAI_HERO.cs     ← 추상 기반 클래스 (Abstract Base Class)
HeroControll.cs       ← CLASSEPAI_HERO 구현체 (플레이어)
BossControl.cs        ← 2페이즈 보스 (hp 임계값 기반)
BALASBOSS_CONTROLL.cs ← 보스 투사체 제어
VilaoControll.cs      ← 일반 적 제어
GAMEMANAGER.cs        ← 게임 상태 관리
AJUDAVILAO.cs         ← 적 보조 AI
BarraVidaVilao.cs     ← 적 체력바 UI
```

## 추상 기반 클래스 패턴 분석

`CLASSEPAI_HERO.cs`는 명시적 C# `abstract class`를 사용:

```csharp
public abstract class CLASSEPAI_HERO : MonoBehaviour {
    public InfosChar infChar;  // 캐릭터 공통 데이터 구조체
    public Vector2 direcaoH;

    public virtual void Start() {
        // 점프/사격 버튼 이벤트 바인딩
        infChar.pulo.onClick.AddListener(Pulo);
        infChar.tiro.onClick.AddListener(Tiro);
    }

    public abstract void Pulo();  // 점프 — 구현 강제
    public abstract void Tiro();  // 사격 — 구현 강제
}
```

**패턴 특징**:
- `InfosChar` 직렬화 구조체로 공통 데이터 묶음
- `abstract` 메서드로 서브클래스 구현 강제
- `virtual Start()`로 공통 초기화 제공

**Godot 4 이식 시 주의**: Godot에는 C# 추상 클래스 패턴이 동작하지만 GDScript에서는 `class_name` + `@abstract` (Godot 4.5+) 또는 메서드 내 `assert(false)` 패턴으로 대체해야 한다.

## 2페이즈 보스 설계 분석

`BossControl.cs`는 `vida`(HP) 임계값 50%를 기준으로 페이즈 전환:

```csharp
void Update() {
    if (vida >= 50) {
        TirosControll(5, 9);  // Phase 1: 느린 발사 주기
    } else if (vida < 50) {
        TirosControll(0, 9);  // Phase 2: 즉시 발사, 더 공격적
    }
    Movimento();
}
```

**페이즈 전환 기준**: HP 50% 이하 → 발사 딜레이 0으로 변경 (즉각 사격)
**이동 패턴**: waypoint 배열 기반 순환 이동 (`points[]` → `atual` 인덱스)
**페이즈 전환 알림**: 별도 연출 없음 — 발사 속도만 변경

## IP 리스크

- 저장소명에 "metal-slug" 포함, 설명에도 명시적 "Metal Slug" 언급
- 라이선스 없음 → 기본적으로 All Rights Reserved
- Itch.io 페이지 존재 → 공개 배포 이력 있음

(Source: [[GitHub alfredo1995 metal-slug]], [[IP Avoidance For Game Clones]])
