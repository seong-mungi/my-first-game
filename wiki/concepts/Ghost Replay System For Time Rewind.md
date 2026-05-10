---
type: concept
title: Ghost Replay System For Time Rewind
created: 2026-05-10
updated: 2026-05-10
tags:
  - replay
  - ghost
  - time-rewind
  - learning-aid
  - design-pattern
  - echo-applicable
  - echo-signature
status: developing
related:
  - "[[Time Manipulation Run and Gun]]"
  - "[[Deterministic Game AI Patterns]]"
  - "[[Determinism Verification Replay Diff]]"
  - "[[Solo Contra 2026 Concept]]"
  - "[[Stealth Information Visualization]]"
  - "[[Modern Difficulty Accessibility]]"
---

# Ghost Replay System For Time Rewind

Trackmania / Celeste / Super Meat Boy 같은 게임이 증명한 패턴: 학습은 자기 이전 시도를 *동시에 보면서* 가속된다. Echo의 9프레임 되감기는 이미 상태 캡처 인프라를 깔아놓았으므로 — 같은 인프라가 고스트 리플레이를 사실상 무비용으로 뒷받침한다.

이 페이지는 Echo의 고스트 시스템 디자인 계약이다: 고스트가 무엇이며, 9프레임 되감기와 어떻게 상호작용하며, 어떤 시각 처리를 받으며, 어떤 데이터 포맷으로 저장되는가.

## Why Ghost Replay Fits Echo

| Echo 자산 | 고스트로의 자연스러운 확장 |
|---|---|
| 결정론 (CharacterBody2D + 직접 transform) | 같은 입력 → 같은 궤적, 고스트 재생이 기록 시점과 bit-identical |
| 상태 스냅샷 (시간 되감기) | 매 프레임 상태가 이미 직렬화 가능, 고스트 = 스냅샷 스트림 |
| 1히트 즉사 + 즉시 재시작 | 시도 사이클이 짧아 고스트 한 시도가 ~30s–4min, 누적이 빠름 |
| 콜라주 비주얼 | 반투명 잔상이 시그니처 톤과 자연스럽게 어울림 |
| 9프레임 되감기 | 고스트 옆에서 자기 신체 기억 강화 — "내 몸이 기억한다" 판타지의 직접 확장 |

> **시그니처 시너지**: 고스트는 Echo의 시간 메커닉을 *학습 도구*에서 *몰입 도구*로 한 단계 더 밀어붙임.

## Three Ghost Sources

### A. Personal Best (PB)
- 플레이어의 가장 빠른/최고 클리어 시도 자동 저장.
- 매 시도마다 비교 대상이 자기 자신.
- **유스케이스**: 학습 곡선 시각화, "내가 어디서 늘고 있나" 피드백.

### B. Dev Gold Run
- 개발자가 작성한 모범 클리어 (스크립트 봇 또는 핸드 플레이).
- 모든 플레이어에 동일 베이스라인.
- **유스케이스**: 첫 클리어 전 "이렇게 하면 된다" 학습 보조.

### C. Asynchronous Phantom (Souls-style)
- 다른 플레이어의 클리어 영상이 비동기로 표시.
- 옵트인, 결정론 보존 (재생만, 변경 X).
- **유스케이스**: 커뮤니티 학습, speedrun 발견.

> **Echo Tier 1 권고**: A + B만. C는 Tier 3 (커뮤니티 형성 후).

## Time-Rewind Interaction (핵심 결정)

플레이어가 9프레임 되감기를 발동했을 때 고스트는?

### 옵션 1: 고스트도 같이 되감기 (시간 일관성)
- 플레이어 되감기 → 고스트도 9프레임 전 위치로 점프
- 두 신체가 동기화 유지
- 콜라주 시안-마젠타 찢김 효과가 양쪽에 적용

### 옵션 2: 고스트는 영향 받지 않음 (벤치마크 일관성)
- 플레이어가 되감기해도 고스트는 자기 타임라인 유지
- 고스트가 같은 패턴을 어떻게 회피했는지 계속 보여줌
- TPS 비교에 더 적합 (고스트 = 절대 기준)

### 옵션 3: 자기 타임라인 모드 + 동기화 모드 토글
- 플레이어가 설정에서 선택
- 학습 모드 = 옵션 1 (몰입), 벤치마크 모드 = 옵션 2 (비교)

> **Echo 권고**: **옵션 1 디폴트** + 옵션 2 토글. Echo 시그니처 (신체 기억)와 정합. 학습 곡선이 뚜렷한 플레이어가 옵션 2로 전환 가능.

## Visual Treatment

### Echo 시그니처 톤과의 정합
- 베이스: 반투명 (alpha 0.4–0.5)
- 컬러 시프트: 콜라주 시안 톤 (마젠타는 사용자 본체 전용 — 시각 분리)
- 잔상 (motion trail): 4–6 frames, 매 프레임 alpha 0.05 감소
- 외곽선 X — 깔끔한 실루엣이 콜라주 미학과 어울림

### Time-Rewind 발동 시
- 플레이어 본체: 시안-마젠타 찢김 효과
- 고스트: 시안 톤 강화 (마젠타 X — 분리 유지)
- 둘 다 옵션 1에서 9프레임 점프

### 우선순위 페어링
- 고스트가 플레이어 위에 그려질지, 아래에 그려질지?
- **권고**: 고스트가 항상 *아래* (반투명 + 컬러 분리로 충돌 회피)
- 보스/탄막은 항상 *위* (가시성 절대)

## Data Format

### 옵션 A: Input Log
- 입력 시퀀스만 저장 (move/jump/shoot/rewind per frame)
- 재생 시 시뮬레이터가 입력 적용 → 결정론으로 같은 궤적
- 크기: ~120 bytes/sec @ 60fps = ~7 KB / 분
- **장점**: 매우 작음, 결정론 검증과 같은 인프라
- **단점**: 코드 변경 시 리플레이 무효화 (재생산 X)

### 옵션 B: State Snapshot Stream
- 매 프레임 (또는 N 프레임마다) 풀 상태 캡처
- 재생 시 상태를 직접 복원
- 크기: ~500 bytes/sec @ 60fps = ~30 KB / 분 (압축 후)
- **장점**: 코드 변경 후에도 리플레이 가능 (구식 빌드 호환성)
- **단점**: 더 크고, 시간 되감기와 상태 충돌 위험

### 옵션 C: Hybrid (권고)
- Input log 우선, 매 5초마다 keyframe (state snapshot)
- 재생 시 input log로 시뮬, keyframe과 비교하여 드리프트 검증
- 빌드 호환성: keyframe만으로 fallback 재생 가능
- 크기: ~10 KB / 분

> **Echo 권고**: **옵션 C (Hybrid)**. 결정론 검증 인프라 ([[Determinism Verification Replay Diff]])와 직접 재사용.

## Storage Strategy

```
user://ghosts/
├── personal_best/
│   └── <boss_id>.replay      # 보스별 PB 1개 (덮어쓰기)
├── recent/
│   ├── <boss_id>_001.replay  # 마지막 5 시도 (롤링)
│   ├── <boss_id>_002.replay
│   └── ...
└── dev_gold/
    └── <boss_id>.replay      # 빌드와 함께 출시
```

크기: 보스 6개 × (PB 10 KB + recent 5 × 10 KB) ≈ 360 KB. 무시 가능.

## Implementation Sketch (Godot 4.6)

```gdscript
# Autoload: GhostManager.gd
extends Node

var _active_ghosts: Array[Ghost] = []

func load_pb_ghost(boss_id: String) -> void:
    var path := "user://ghosts/personal_best/%s.replay" % boss_id
    if not FileAccess.file_exists(path):
        return
    var ghost := Ghost.new()
    ghost.load_from_replay(path)
    ghost.set_visual_layer(GhostVisualLayer.PERSONAL_BEST)
    _active_ghosts.append(ghost)
    add_child(ghost)

func load_dev_gold_ghost(boss_id: String) -> void:
    var path := "res://assets/ghosts/dev_gold/%s.replay" % boss_id
    if not ResourceLoader.exists(path):
        return
    var ghost := Ghost.new()
    ghost.load_from_replay(path)
    ghost.set_visual_layer(GhostVisualLayer.DEV_GOLD)
    _active_ghosts.append(ghost)
    add_child(ghost)

func _on_player_rewind_consumed(rewind_target_frame: int) -> void:
    # 옵션 1: 모든 고스트도 동기화 되감기
    for ghost in _active_ghosts:
        ghost.rewind_to_frame(rewind_target_frame)

func _on_attempt_completed(boss_id: String, success: bool, replay: Replay) -> void:
    if success and replay.duration < _get_pb_time(boss_id):
        replay.save("user://ghosts/personal_best/%s.replay" % boss_id)
    # rolling recent
    _save_to_recent(boss_id, replay)
```

```gdscript
# Ghost.gd
class_name Ghost
extends Node2D

var _replay: Replay
var _current_frame: int = 0
var _modulate_base := Color(0.5, 0.9, 1.0, 0.45)  # 시안 톤

func _physics_process(_dt: float) -> void:
    if _current_frame >= _replay.total_frames:
        _current_frame = 0   # loop
    var state := _replay.get_state_at(_current_frame)
    position = state.player_pos
    $Sprite.flip_h = state.facing < 0
    $AnimationPlayer.seek(state.animation_time, true)
    _current_frame += 1

func rewind_to_frame(target_frame: int) -> void:
    _current_frame = max(0, target_frame)
```

## Reference Cases

### Trackmania (Nadeo, 2003+)
- PB + 친구 + 월드 1위 동시 표시.
- 결정론 재생.
- 자동차 게임이지만 "내가 어디서 잃고 있나" 학습 패러다임의 모범.

### Celeste (Maddy Makes Games, 2018)
- 데스 카운트 + best time 표시 (고스트는 모드).
- 챕터별 best run 저장.
- Echo의 보스별 PB와 직접 매핑.

### Super Meat Boy (Team Meat, 2010)
- 클리어 후 모든 시도가 동시에 표시되는 "리플레이 셔" 효과.
- 학습 시각화의 정점 — 카타르시스 모먼트.
- Echo의 보스 클리어 후 사용 검토 가치.

### Hollow Knight (Team Cherry, speedrun 모드)
- 커뮤니티 모드로 추가됨.
- best run 고스트가 플레이어 옆에서 달림.
- 본 게임에 통합되지 않은 점이 아쉬움 — Echo는 처음부터 통합.

## What Ghost Replay Does NOT Do

- 보스/적 행동 미리보기 X — 그건 텔레그래프 일.
- 인풋 가이드 X — 고스트는 결과만 보여줌.
- 자동 회피 X — 플레이어 도움이 아닌 비교 대상.
- 강제 X — 옵트아웃 가능.

## Settings

```yaml
ghost_settings:
  show_personal_best:
    default: false   # 첫 시도 후 자동 활성화
    user_toggle: true
  show_dev_gold:
    default: false   # 5번 사망 후 자동 활성화 (학습 보조)
    user_toggle: true
  rewind_sync:
    default: synced       # 옵션 1
    options: [synced, independent, disabled]
  visual_intensity:
    default: 0.45
    range: [0.2, 0.7]
```

## Sample Validation

고스트 시스템 자체에 봇 검증:

| 메트릭 | 목표 |
|---|---|
| 고스트 위치 드리프트 (재생 vs 기록) | < 0.5 px (1 ms 양자화 후) |
| 시간 되감기 후 고스트 동기화 | 정확 9프레임 점프 |
| 메모리 오버헤드 (보스 1개 + PB + dev gold) | < 2 MB |
| 렌더 비용 추가 | < 0.1 ms / frame |

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| 고스트가 플레이어 본체보다 시각적으로 강함 | 입력 혼란, 가시성 충돌 |
| 고스트가 보스/탄막 위에 그려짐 | 안전 정보 가림, 사망 원인 |
| 디폴트로 PB ON | 첫 플레이엔 PB 없으니 의미 X — 지능적 unlock 필요 |
| 디폴트로 Dev Gold ON | "처음부터 정답 보여줌" → 학습 발견 박탈 |
| 옵션 1 강제 (toggle X) | speedrun 커뮤니티가 옵션 2 필요 |
| 고스트 데이터를 빌드와 함께 ship X | 첫 플레이 학습 보조 손실 |

## Open Questions

- **[NEW]** Personal Best 정의 — 가장 빠른 클리어? 사망 가장 적은 클리어? rewinds-conserved? (Hit Rate Grading System 참조)
- **[NEW]** 고스트가 사망 시 어떻게 처리 — 사라짐? 같은 위치에서 정지? 자기 시작점에서 다시 시작?
- **[NEW]** 고스트 multi-display 한도 — PB + Dev Gold 둘 다 = 2개. 친구 베스트 추가 시 시각 노이즈 폭발 위험.
- **[NEW]** 고스트 데이터 빌드 간 호환성 — 코드 변경 시 PB 무효화 룰?
- **[NEW]** 콜라주 비주얼이 반투명 고스트와 어떻게 상호작용 — 알파 합성 vs additive blending?

## Tier Mapping

### Tier 1 (MVP)
- Personal Best 단일 고스트
- 옵션 1 (rewind sync) 디폴트
- Hybrid 데이터 포맷

### Tier 2
- Dev Gold ghost (출시와 함께)
- Settings 메뉴 통합
- 시간 되감기 시각 처리 정밀화

### Tier 3 (post-launch)
- Asynchronous phantom (Souls-style)
- Friends ghost 통합 (Steam friends API)
- Speedrun WR ghost 다운로드

## Related

- [[Time Manipulation Run and Gun]] — Echo 시간 되감기 베이스라인
- [[Deterministic Game AI Patterns]] — Zone ④ Player Aid에서 고스트 위치
- [[Determinism Verification Replay Diff]] — 고스트 데이터 인프라 공유
- [[Solo Contra 2026 Concept]] — 콜라주 비주얼 + 신체 기억 시그니처와 정합
- [[Modern Difficulty Accessibility]] — 고스트가 학습 곡선 가속하여 1히트 즉사 접근성 부담 완화
