---
type: concept
title: Analog Stick To 8-Way Quantization
created: 2026-05-11
updated: 2026-05-11
tags:
  - input
  - gamepad
  - quantization
  - deadzone
  - design-pattern
  - engineering
  - echo-applicable
  - godot
status: developing
related:
  - "[[Research 8-Way Aim Usability For Run-and-Gun]]"
  - "[[Aim Lock Modifier Pattern]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[Game Developer Thumbstick Deadzones]]"
---

# Analog Stick To 8-Way Quantization

아날로그 스틱 (연속 2D 벡터)을 8개 이산 방향으로 양자화하는 엔지니어링 패턴. 런앤건 8방향 조준의 게임패드 측 핵심 문제: 같은 입력이 매번 같은 방향을 산출하면서 (결정론), 떨림 없이 (hysteresis), 카디널/대각선 균형 잡힌 (sector 폭) 변환을 보장.

## Three-Stage Pipeline

```
1. Raw stick vector (x, y) ∈ [-1, 1]²
       ↓
2. Magnitude deadzone (radial) — 노이즈 floor 제거
       ↓
3. Sector quantization — atan2 → 8 octant
       ↓
4. Hysteresis + commitment timer — 경계 떨림 방지
       ↓
Output: facing_direction ∈ {0..7}
```

## Stage 1: Deadzone Shapes

| 모양 | 동작 | 8방향 적합성 |
|---|---|---|
| **Axial (cross)** | x, y 각각 threshold | ❌ 카디널만 sticky, 대각선 도달 어려움 |
| **Radial (circular)** | `|v| < threshold` 시 무시 | ✅ 산업 표준. 부드러운 회전 보존 |
| **Scaled radial** | radial + 사후 [0,1] remapping | ✅ "ship-quality" 정밀 게임 표준 |
| **Hybrid (scaled radial + sloped scaled axial)** | 6 비교 테스트에서 5/6 통과 | ✅ twin-stick / run-and-gun 권장 |

> **Echo 권고**: Scaled radial 또는 Hybrid. Axial 절대 X (대각선 죽음).

## Stage 2: Magnitude Schmitt Trigger

Stick magnitude `|v|`에 dual threshold 적용 — 노이즈 영역과 활성 영역 분리.

```gdscript
# Echo 디폴트
const ENTER_THRESHOLD := 0.20    # 활성 진입
const EXIT_THRESHOLD := 0.15     # 활성 이탈
const FACING_THRESHOLD_AIM_LOCK := 0.15   # ← 0.10에서 0.15로 상향 권장

var _stick_active := false

func update_stick_active(magnitude: float) -> void:
    if not _stick_active and magnitude > ENTER_THRESHOLD:
        _stick_active = true
    elif _stick_active and magnitude < EXIT_THRESHOLD:
        _stick_active = false
```

### 산업 디폴트 비교

| 출처 | Enter | Exit |
|---|---|---|
| **Unity InputSystem** | 0.125 | 0.925 (안쪽 데드존 / 바깥쪽 saturation) |
| **Echo (현)** | 0.20 | 0.15 |
| **Steam Deck 권장 floor** | ≥ 0.20 | ≥ 0.15 |
| **개발자 일반 heuristic** | 0.25 | 0.20 |

> Echo의 0.20/0.15는 Unity-derived 실무에 정합. 단 `FACING_THRESHOLD_AIM_LOCK = 0.10`은 **Steam Deck LCD 1세대 드리프트 ~0.18 floor에 부족** → 0.15로 상향 권장.

## Stage 3: Sector Quantization (Snap-to-8)

표준 알고리즘:

```gdscript
const SECTOR_COUNT := 8
const SECTOR_RADIANS := TAU / SECTOR_COUNT    # PI/4 = 45°

func quantize_to_8(v: Vector2) -> int:
    var angle := atan2(v.y, v.x)
    var sector := int(round(angle / SECTOR_RADIANS)) % SECTOR_COUNT
    return (sector + SECTOR_COUNT) % SECTOR_COUNT   # negative wrap
```

레퍼런스 구현: [JoyShockMapper `FLICK_SNAP_MODE 8`](https://github.com/JibbSmart/JoyShockMapper).

### Sector 폭 선택

| 옵션 | 카디널 폭 | 대각선 폭 | 트레이드오프 |
|---|---|---|---|
| **Even (45°/45°)** | 45° | 45° | 균등. "d-pad 같은 느낌". 디폴트 권장. |
| **Cardinal bias (50°/40°)** | 50° | 40° | 카디널이 잡기 쉬움. 슈팅 게임 친화 (직선 사격 자주). |
| **Diagonal bias (40°/50°)** | 40° | 50° | 대각선 잡기 쉬움. 드물게 권장. |

> **Echo 권고**: Even 45° 디폴트. 카디널 편향은 Tier 1 플레이테스트 후 데이터 기반 조정.

## Stage 4: Angular Hysteresis + Commitment Timer

Sector 경계 (예: NE/E 경계 = 22.5°)에서 떨림 방지.

### 각도 hysteresis

```
new_sector = quantize_to_8(v)
if new_sector != current_sector:
    # 경계 진입 시 ±HYSTERESIS_DEG 추가 마진 요구
    if angle_distance(angle, boundary_of(current_sector)) < HYSTERESIS_DEG:
        return current_sector    # 유지
```

`HYSTERESIS_DEG = 4°` 권장 (3-5° 범위). 

### Commitment timer

```
new_sector candidate = quantize_to_8(v)
if new_sector_candidate != current_sector:
    if frames_held_at_candidate < COMMITMENT_FRAMES:
        return current_sector    # 유지
    else:
        current_sector = new_sector_candidate
```

`COMMITMENT_FRAMES = 2` 권장 (33 ms @ 60fps). 각도 hysteresis와 결합 — *둘 다* 필요.

## Steam Deck 특수

- LCD 1세대 스틱 드리프트 ~0.18 floor (Valve 공식 인정 — firmware 데드존 regression 버그).
- OLED 1세대는 개선되었으나 보장 X.
- **모든 게임패드 threshold 사용자 노출 권장** — 설정 메뉴에 ±0.05 슬라이더.

## Echo 전체 디폴트 (권장)

```yaml
echo_gamepad_quantization:
  deadzone_shape: scaled_radial
  enter_threshold: 0.20
  exit_threshold: 0.15
  facing_threshold_aim_lock: 0.15   # 0.10 → 0.15 상향
  sector_count: 8
  sector_width: even_45deg
  angular_hysteresis_deg: 4
  commitment_frames: 2
  user_adjustable_range: ±0.05
```

## 결정론 검증 ([[Determinism Verification Replay Diff]])

- 매 프레임 같은 (x, y) → 같은 sector 출력 (시드 무관, RNG 없음).
- Replay diff 자동 검증 가능.
- Steam Deck 드리프트는 *입력 노이즈*이지 비결정론 X — 같은 노이즈 입력은 같은 출력 (드리프트 자체는 결정론).

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| Axial deadzone + 8방향 양자화 | 대각선 도달 불가 (카디널 sticky) |
| Schmitt 없음 (단일 threshold) | 노이즈 floor에서 활성/비활성 떨림 |
| 각도 hysteresis 없음 | 45° 경계에서 sector 떨림 |
| Commitment timer 없음 | 1프레임 spike가 sector 변경 |
| 사용자 노출 threshold 없음 | Steam Deck 드리프트 플레이어 게임 못 함 |
| FACING_THRESHOLD = 0.10 | Steam Deck 1세대 드리프트 floor 미달 |
| Sector 폭 비대칭 + 시각 표시 없음 | 플레이어가 어디가 어디 방향인지 추측 |

## Open Questions

- **Hall-effect 스틱 (Steam Deck OLED, Xbox Elite Series 2)** floor가 ~0.05까지 내려가는데, 0.15가 너무 보수적? 컨트롤러별 프로파일 필요?
- **대각선 vs 카디널 sector 폭** 실제 플레이테스트 데이터 부족. 봇 검증 가능? ([[Non-Boss Bot Validation Suites]] movement_v1에 통합?)
- **Angular hysteresis와 commitment timer 둘 다 vs 하나만**: 실측 비교 데이터 없음. Echo 권고는 안전 측면 둘 다.
- **JoyShockMapper FLICK_SNAP_MODE 8 vs custom Godot 구현** 동등성? Steam Input layer가 game 위에서 또 양자화 가능 — Echo에서 어떻게 처리?

## Related

- [[Research 8-Way Aim Usability For Run-and-Gun]] — 부모 컨텍스트
- [[Aim Lock Modifier Pattern]] — Lock과 양자화는 직교 (Lock 없어도 양자화 필요)
- [[Determinism Verification Replay Diff]] — 양자화 결정론 검증
- [[Heuristic Bot Reaction Lag Simulation]] — 9프레임 lag 봇이 이 양자화를 거쳐 입력
- [[Game Developer Thumbstick Deadzones]] — 산업 canonical 출처
