---
type: concept
title: Aim Assist Accessibility Tiers
created: 2026-05-11
updated: 2026-05-11
tags:
  - accessibility
  - aim-assist
  - design-pattern
  - input
  - difficulty
  - echo-applicable
status: developing
related:
  - "[[Research 8-Way Aim Usability For Run-and-Gun]]"
  - "[[Modern Difficulty Accessibility]]"
  - "[[Accessibility Mode Bot Validation]]"
  - "[[Aim Lock Modifier Pattern]]"
  - "[[XAG 107 Aim Assist Guidelines]]"
  - "[[Returnal]]"
  - "[[Cuphead]]"
---

# Aim Assist Accessibility Tiers

조준 보조 시스템의 모던 (2018-2026) 표준 패턴. 핵심 원칙: **어시스트는 난이도와 직교 (decoupled)** — Easy = 어시스트 강제, Hard = 어시스트 금지 같은 결합은 안티 패턴. 모든 어시스트는 opt-in, 진척/업적과 분리.

## Industry-Standard 4-Tier 구조

Returnal (Housemarque, 2021)이 정착한 패턴:

| Tier | 동작 | 용도 |
|---|---|---|
| **Off** | 어시스트 0. 순수 입력 → 사격. | 베테랑, speedrun, "정통" 경험 |
| **Low** | 약한 sticky aim, 적이 사격 cone 안에 있을 때 미세 보정 (~10%) | 능숙한 컨트롤러 플레이어 |
| **Medium** | 중간 magnetism (~30%). 적 위치 근처에서 crosshair pull. **Returnal 디폴트** | 일반 캐주얼, 평론가 칭찬 |
| **High** | 강한 lock-on. 가장 가까운 적 자동 추적 (~60%). 거의 self-aim. | 라이트 캐주얼, 운동 한계 |

> **Echo 권고**: 4-tier 채택. 단 **디폴트는 Off** — Echo는 1-hit 즉사 + 9프레임 되감기 메카닉 → flick-disengage 패턴이 코어. Medium 디폴트는 정체성 손상.

## 2D 8방향에서의 어시스트 변형

3D 슈터의 "aim cone magnetism"이 2D 8방향에 직접 이식 X. 대응 변형:

### Variant A: Directional Snap
가장 가까운 적의 8방향 octant로 stick을 살짝 끌어옴. Angle threshold 안에 적 있을 때만 동작.

```
if angle_to_nearest_enemy < SNAP_THRESHOLD:
    target_octant = octant_to(nearest_enemy)
    if current_octant != target_octant:
        snap_pull_strength = TIER_DEPENDENT
```

### Variant B: Bullet Homing / Curving
입력은 그대로지만 발사된 탄환이 가까운 적으로 약하게 휘어짐. 강한 어시스트.

### Variant C: Auto-Fire-On-Aligned-Target
조준 방향에 적이 있을 때만 자동 발사. 1-stick 플레이 모드의 핵심 ([[XAG 107 Aim Assist Guidelines]]).

> **Echo 권고**: Variant A를 Low/Medium tier, Variant C를 High tier (single-stick 모드와 결합).

## 비-aim 어시스트 (참고)

런앤건 어시스트 패키지에 포함되는 다른 표준 옵션:

| 옵션 | 출처 | Echo 적용 |
|---|---|---|
| **Auto-fire toggle** | XAG 107 의무 | Tier 1 게이트 |
| **Hold-to-fire vs tap-to-fire** | XAG 107 | Tier 1 |
| **±50% 감도 조정** | XAG 107 | Tier 1 |
| **Damage reduction** (Hades II "God Mode") | Hades II | Tier 2 (Echo는 1-hit이라 부분 적용) |
| **Slow-motion** | Celeste Assist Mode | Tier 2 |
| **Infinite rewind tokens** | Echo-specific | Tier 1 Easy 모드 |

## 황금률 — 어시스트 ↔ 난이도 직교

> **Game Accessibility Guidelines**: "Assist modes must be opt-in, granular, and **decoupled** from difficulty/achievements."

```
❌ Anti-pattern:
  Easy mode → aim assist High 강제
  Hard mode → aim assist 금지
  
✅ Pattern:
  Difficulty: Easy / Normal / Hard (게임 mechanics)
  Aim assist: Off / Low / Med / High (입력 보조)
  Auto-fire: On / Off
  ... 각자 독립
  
Hard + Aim Assist High 가능. 
Easy + Aim Assist Off 가능.
업적/speedrun 카테고리: 어시스트 ON/OFF 별도 추적 (게이팅 X).
```

### Celeste 모델 (gold standard)

Celeste Assist Menu가 산업 표준:
- 게임 속도 (50-100%)
- 무적 모드
- 무한 점프
- 대시 보조
- 스테이지 스킵

각 옵션 독립 토글, 진행 게이트 X, 업적 게이트 X. Echo는 이 모델 직접 차용.

## Single-Stick Mode (XAG 107 의무)

운동 한계 플레이어 (CFAA, Xbox Adaptive Controller)를 위한 1-stick 모드:

```
Move: 왼쪽 stick (또는 d-pad)
Aim: 자동 (가장 가까운 적 octant)
Fire: 자동 (조준된 적이 있을 때) 또는 단일 키
Rewind: 단일 키 (또는 자동 — opt-in)
```

XAG 107: "even games that traditionally require two sticks… can include options for single stick control."

> **Echo 권고**: Tier 1 게이트. Echo는 8방향 aim + lock + rewind = 입력 다수. Single-stick 모드 없으면 운동 한계 플레이어 접근 차단.

## 시각 indicator (필수)

어시스트 활성 상태를 *dual-channel*로 시각화:

- **색**: crosshair 색 변경 (예: 흰색 → 시안)
- **모양/외곽선**: 적 lock-on 시 외곽선 펄스 또는 reticle 모양 변경

> **이유**: 색만으론 색맹 호환 X. 모양/외곽선이 redundant channel 역할.

## 어시스트와 시간 메커닉의 상호작용 (Echo-specific)

```
질문: 어시스트로 자동 회피한 입력이 9프레임 되감기 시 어떻게 처리?
```

| 옵션 | 동작 | 트레이드오프 |
|---|---|---|
| **Rewind with assist state** | 되감기 시 어시스트 상태도 함께 되감음 | 결정론 보존. "내 입력의 일관된 재경험" 시그니처 정합 |
| **Rewind raw input only** | 어시스트는 매번 새로 재계산 | 어시스트 상태 변경 시 재경험 다름 — 학습 단서 손실 |

> **Echo 권고**: Option 1 (rewind with assist state). 9프레임 되감기 정체성은 *완전 재현* — 어시스트 결정도 그 안에 포함 ([[Bot Validation Catalog Summary]] 결정론 비협상).

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| 어시스트 ON 시 업적 게이트 | GAG 위반. 접근성 stigma |
| 난이도와 어시스트 결합 | 어시스트 필요한 플레이어가 난이도 선택 자유 X |
| 어시스트 강도가 단일 ON/OFF만 | 4-tier (Off/Low/Med/High)이 모던 표준 |
| 어시스트 디폴트 강함 (Med/High) | 1-hit 게임에선 정체성 손상 (Echo) |
| Auto-fire 토글 부재 | XAG 107 위반 |
| ±50% 감도 조정 없음 | XAG 107 위반, 운동 한계 플레이어 접근 차단 |
| Aim assist 상태 시각 표시 없음 | 플레이어가 어시스트 켜져있는지 모름 |
| 어시스트 상태가 되감기에서 부정확 | 결정론 깨짐, 학습 신호 손실 |

## Echo 4-Tier 구현 표

```yaml
echo_aim_assist:
  tiers:
    off:
      directional_snap: 0
      bullet_curve: 0
      auto_fire: false
    low:
      directional_snap: 0.10    # 미세 보정
      snap_threshold_deg: 15
      bullet_curve: 0
      auto_fire: false
    medium:
      directional_snap: 0.30
      snap_threshold_deg: 25
      bullet_curve: 0.05
      auto_fire: false
    high:
      directional_snap: 0.60
      snap_threshold_deg: 40
      bullet_curve: 0.20
      auto_fire: false   # single-stick 모드에서만 true
  default: off
  user_adjustable: true
  achievement_gate: false   # 결정론 보존
  speedrun_category: tracked_separately   # 게이팅 X, 분류 O
```

## Open Questions

- **Echo Easy 모드 = 어시스트 Medium 디폴트 권고?** GAG는 직교 권고하나, 캐주얼 플레이어 디폴트 무관심 시 옵션 발견 못 함 — *권고만* (강제 X).
- **단일 스틱 모드 ↔ 시간 되감기**: 자동 되감기 (rewind tokens 자동 소비) 옵션? 학습 가치 vs 접근성 트레이드오프.
- **어시스트 ON speedrun 별도 카테고리?** ([[Speedrun Discovery Via RL Bot]] 글리치 분류 매트릭스 참조 — 어시스트는 "human achievable + valid" 분류로 별도 카테고리.)
- **8방향 양자화 ([[Analog Stick To 8-Way Quantization]])와 어시스트 상호작용** — 어시스트가 octant를 강제하면 양자화 sector 폭 의미 손실? 통합 설계 필요.

## Related

- [[Research 8-Way Aim Usability For Run-and-Gun]] — 부모 컨텍스트
- [[Modern Difficulty Accessibility]] — 1히트 즉사 현대 수용성 + 어시스트 의무
- [[Accessibility Mode Bot Validation]] — 어시스트 모드 봇 검증 (color-blind 자연 검증)
- [[Aim Lock Modifier Pattern]] — Lock과 어시스트는 보완 (Lock = 정밀, 어시스트 = 보조)
- [[XAG 107 Aim Assist Guidelines]] — Microsoft 권위 가이드라인
