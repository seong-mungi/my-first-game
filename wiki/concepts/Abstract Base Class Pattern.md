---
type: concept
title: Abstract Base Class Pattern
created: 2026-05-08
updated: 2026-05-08
tags:
  - programming
  - design-pattern
  - oop
  - godot
  - csharp
related:
  - "[[metal-slug alfredo1995]]"
  - "[[Boss Two Phase Design]]"
  - "[[Run and Gun Base Systems]]"
  - "[[GitHub alfredo1995 metal-slug]]"
confidence: high
---

# Abstract Base Class Pattern

## 정의

**추상 기반 클래스(Abstract Base Class, ABC) 패턴**은 공통 인터페이스와 공유 구현을 하나의 추상 클래스에 정의하고, 구체적 서브클래스가 반드시 특정 메서드를 구현하도록 강제하는 OOP 패턴이다. 게임 개발에서는 여러 캐릭터(플레이어, 적, NPC)가 공통 동작(이동, 피격, 사망)을 공유하되 개별 행동(점프 방식, 공격 유형)을 다르게 구현할 때 자주 사용된다.

## 런앤건 게임에서의 활용

`alfredo1995/metal-slug` 저장소에서 실제 구현 사례 확인:

```csharp
// C# Unity 구현 (CLASSEPAI_HERO.cs)
public abstract class CLASSEPAI_HERO : MonoBehaviour {
    public InfosChar infChar;  // 공통 데이터: 이동속도, 점프력, 입력 버튼

    // 공통 초기화 — 모든 캐릭터 공유
    public virtual void Start() {
        infChar.pulo.onClick.AddListener(Pulo);
        infChar.tiro.onClick.AddListener(Tiro);
    }

    // 서브클래스 강제 구현 (점프, 사격)
    public abstract void Pulo();
    public abstract void Tiro();
}
```

(Source: [[GitHub alfredo1995 metal-slug]])

## Godot 4 이식 방법

### GDScript 방식 (Godot 4.5+ @abstract)
```gdscript
# Godot 4.5 이상: @abstract 어노테이션 사용
class_name CharacterBase extends CharacterBody2D

var max_speed: float = 200.0
var jump_force: float = 400.0

func _ready() -> void:
    _setup_input()

func _setup_input() -> void:
    pass  # 서브클래스에서 오버라이드

@abstract
func jump() -> void:
    pass

@abstract
func shoot() -> void:
    pass
```

### GDScript 방식 (Godot 4.4 이하 호환)
```gdscript
class_name CharacterBase extends CharacterBody2D

func jump() -> void:
    assert(false, "jump() must be implemented by subclass")

func shoot() -> void:
    assert(false, "shoot() must be implemented by subclass")
```

### C# 방식 (Godot 4 + C#)
```csharp
// Godot 4 C#: C# abstract 키워드 직접 사용 가능
public abstract partial class CharacterBase : CharacterBody2D
{
    [Export] public float MaxSpeed = 200.0f;
    [Export] public float JumpForce = 400.0f;

    public override void _Ready()
    {
        SetupInput();
    }

    protected virtual void SetupInput() { }

    public abstract void Jump();
    public abstract void Shoot();
}
```

## 런앤건에서 ABC 계층 설계 예시

```
CharacterBase (abstract)
├── PlayerCharacter (구체)
│   ├── SoldierPlayer
│   └── TankPlayer
└── EnemyBase (abstract)
    ├── SoldierEnemy
    ├── BossBase (abstract)
    │   ├── Boss1
    │   └── Boss2
    └── VehicleEnemy
```

## 주의사항

- Godot 4.6 기준: `@abstract` 어노테이션은 Godot 4.5에서 추가됨. 4.4 이하라면 `assert(false)` 패턴 사용.
- C#과 GDScript 혼용 프로젝트에서는 C# ABC가 GDScript 서브클래스에서 상속 불가 — 언어 경계를 명확히 정의해야 함.
- 과도한 계층화는 씬 구조와 충돌할 수 있음 — Godot에서는 컴포지션(노드 합성)이 종종 더 관용적.

> [!gap] 미확인 사항
> Godot 4.6에서 `@abstract` 어노테이션의 정확한 동작 방식은 공식 문서 교차 확인 필요.
