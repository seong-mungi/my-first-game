---
title: Run and Gun Bullet System Pattern
tags: [concept, run-and-gun, bullet, projectile, weapon, godot, implementation]
aliases: [런앤건 불릿 시스템 패턴]
cssclasses: []
created: 2026-05-12
updated: 2026-05-12
---

# Run and Gun Bullet System Pattern

런앤건 게임의 불릿/투사체 시스템과 무기 교체 구현 패턴. Godot 4.6 GDScript 기준.

---

## BulletServer 패턴 (오브젝트 풀링)

**신뢰도: HIGH** — Godot 네이티브 소스 다수 확인

### 핵심 원칙

```
금지: queue_free() / instantiate() — GC 스파이크 발생
권장: 비활성화(hide/disable) → 재활성화(show/enable) 재사용
```

### BulletServer 싱글턴 구조

```gdscript
# BulletServer.gd (AutoLoad)
class_name BulletServer
extends Node

const POOL_SIZE := 64
var _pool: Array[Bullet] = []
var _pool_index: int = 0

func _ready() -> void:
    for i in POOL_SIZE:
        var b := BULLET_SCENE.instantiate() as Bullet
        b.visible = false
        b.process_mode = Node.PROCESS_MODE_DISABLED
        add_child(b)
        _pool.append(b)

func fire(origin: Vector2, direction: Vector2, data: BulletData) -> void:
    var b := _pool[_pool_index]
    _pool_index = (_pool_index + 1) % POOL_SIZE
    b.init(origin, direction, data)
    b.visible = true
    b.process_mode = Node.PROCESS_MODE_INHERIT

func recycle(b: Bullet) -> void:
    b.visible = false
    b.process_mode = Node.PROCESS_MODE_DISABLED
```

**풀 한계 도달 시**: 가장 오래된 활성 총알 재활용 — 메모리 상한선 보장, GC 스파이크 없음.

---

## 발사 위치: Marker2D 패턴

**신뢰도: HIGH** — Godot Recipes (kidscancode) 권장

```
Player
└── WeaponHolder (Node2D)
    └── [CurrentWeaponScene]
        └── BulletSpawnPoint (Marker2D)  ← 발사 위치 앵커
```

**장점**: 무기 씬 교체 시 `BulletSpawnPoint`가 함께 교체됨.
플레이어 코드에서 발사 위치 오프셋을 하드코딩할 필요 없음.

```gdscript
# Player.gd
func _shoot() -> void:
    var spawn: Marker2D = weapon_holder.get_child(0).get_node("BulletSpawnPoint")
    BulletServer.fire(spawn.global_position, facing_direction, current_weapon.data)
```

---

## 무기 교체 패턴: WeaponData Resource

**신뢰도: MEDIUM** — Unity 문서 기반 Godot 적용

### WeaponData Resource 서브클래스

```gdscript
# WeaponData.gd
class_name WeaponData
extends Resource

@export var weapon_name: String
@export var fire_rate: float = 0.15      # 초당 발사 간격
@export var bullet_count: int = 1        # 산탄 발 수
@export var spread_angle: float = 0.0    # 산탄 각도 (라디안)
@export var reload_time: float = 1.0
@export var ammo_max: int = 30
@export var bullet_speed: float = 800.0
@export var damage: float = 10.0
@export var sfx_fire: AudioStream
@export var weapon_scene: PackedScene     # 무기 씬 레퍼런스
```

### WeaponHolder 교체 로직

```gdscript
# Player.gd
@onready var weapon_holder: Node2D = $WeaponHolder

var equipped_weapons: Array[WeaponData] = []
var current_weapon_index: int = 0

func switch_weapon(index: int) -> void:
    if index < 0 or index >= equipped_weapons.size():
        return
    # 현재 무기 씬 제거
    for child in weapon_holder.get_children():
        child.queue_free()
    # 새 무기 씬 로드
    current_weapon_index = index
    var new_weapon := equipped_weapons[index].weapon_scene.instantiate()
    weapon_holder.add_child(new_weapon)
```

---

## 발사 패턴 유형

| 유형 | 설명 | 구현 방법 |
|---|---|---|
| 단발 (Single) | `bullet_count=1, spread=0` | 기본 |
| 산탄 (Shotgun) | `bullet_count=5, spread=0.3 rad` | for loop + 각도 오프셋 |
| 3점사 (Burst) | 0.05 s 간격 3발 | 타이머 or coroutine |
| 유도탄 | 목표 방향으로 조향 | 매 프레임 방향 업데이트 |
| 관통탄 | 히트 후 계속 진행 | 히트 카운트 추적 |

---

## 참고 애드온/레포

### Godot 애셋 라이브러리: "Fire Bullets" (#1990)
- URL: https://godotengine.org/asset-library/asset/1990
- GDExtension 없음 — 가장 낮은 마찰
- 기능: 쿨다운, 각도 분산, 산탄 아크, 설정 가능 스폰 포인트
- **Godot 4.6 호환성 확인 필요**

### qurobullet (quinnvoker)
- URL: https://github.com/quinnvoker/qurobullet
- GDExtension 풀 구현 — 가장 강력
- 기능: `BulletServer` 노드, 충돌 보고, 풀 라이프사이클 관리
- **주의**: Godot 4.6 호환성 미검증 (GDExtension API 변경 가능)

### GDQuest 마이크로 데모
- ranged-attacks: https://github.com/gdquest-demos/godot-4-ranged-attacks
- homing-missiles: https://github.com/gdquest-demos/godot-4-homing-missiles
- reloading-ammo: https://github.com/gdquest-demos/godot-4-reloading-ammo
- Confidence: HIGH (GDQuest 공식, Godot 4)

---

## 시간 되감기와 불릿 시스템 (Echo 특이점)

되감기 시 활성 총알도 롤백 대상인가?

| 선택 | 장점 | 단점 |
|---|---|---|
| 총알도 롤백 (Braid 모델) | 완전한 되감기 | 풀 상태 스냅샷 비용 |
| 총알은 즉시 소멸, 플레이어만 롤백 | 단순 | 비직관적 시각 효과 |
| 플레이어 + 적 롤백, 총알 소멸 | 절충 | 시각적으로 어색할 수 있음 |

> [!gap] Echo 되감기 스코프 미결정 (→ [[Time Manipulation Run and Gun]]).
> 총알 포함 여부에 따라 BulletServer 스냅샷 구조가 달라짐.

---

## 관련 페이지

- [[Run and Gun Player Character Architecture]] — WeaponHolder 노드 구조
- [[Run and Gun Enemy AI Archetypes]] — 적 투사체는 별도 풀 권장
- [[Time Manipulation Run and Gun]] — 되감기 스코프 결정
- [[Boss Rush Godot Implementation Pattern]] — 보스 공격 패턴 (투사체 공유 가능)
