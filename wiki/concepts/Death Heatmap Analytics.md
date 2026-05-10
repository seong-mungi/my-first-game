---
type: concept
title: Death Heatmap Analytics
created: 2026-05-10
updated: 2026-05-10
tags:
  - analytics
  - visualization
  - tuning
  - bot
  - playtest
  - design-pattern
  - echo-applicable
status: developing
related:
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Bot Human Validation Reconciliation]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[Boss Two Phase Design]]"
---

# Death Heatmap Analytics

봇 리포트는 숫자 verdict를, 데스 히트맵은 공간-시간-패턴 *진단*을 준다. 히트맵은 "Heuristic 봇 win rate 32%"를 "P3 사망이 death-beam 텔레그래프 동안 우측 벽에 클러스터됨"으로 변환하며, 후자는 직접 액션 가능한 재설계 타깃이다.

이 페이지는 분석 계약이다: 사망별 무엇을 기록할지, 어떤 뷰를 렌더링할지, 어떤 패턴이 어떤 디자인 수정을 트리거할지.

## Three Heatmap Views

각 사망 이벤트는 풀 컨텍스트로 기록됨. 한 데이터셋으로부터 세 직교 뷰가 다른 질문에 답:

| 뷰 | 답하는 질문 | 주축 |
|---|---|---|
| **Spatial heatmap** | 아레나 *어디서* 죽나? | x, y 위치 |
| **Temporal heatmap** | 패턴 *언제* 죽나? | 패턴 시작 후 초 |
| **Pattern attribution** | *어느* 보스 상태에서 죽었나? | pattern ID + phase |

## Death Event Schema

봇이든 인간이든, 모든 사망 이벤트는 다음을 로그:

```yaml
death_event:
  build_hash: "a1b2c3d"
  source: "bot_heuristic_lag9"   # 또는 "human_session_42"
  attempt_number: 17
  frame: 7234
  player_pos: [x, y]
  player_velocity: [vx, vy]
  player_facing: -1
  boss_state: "telegraph_death_beam"
  boss_phase: "P3"
  boss_pattern_id: 4
  boss_pattern_progress: 0.83   # 패턴 진행률 0-1
  cause: "death_beam_direct_hit"
  rewind_tokens_at_death: 1
  hp_before_death: 1
  time_since_phase_start: 14.2  # 초
  time_since_pattern_start: 0.83
```

봇 텔레메트리와 인간 텔레메트리 간 **공유 스키마** — 같은 스키마 = 같은 히트맵 파이프라인.

## View 1: Spatial Heatmap

2D 아레나 오버레이, 강도 = 셀당 사망 카운트.

```python
import numpy as np
import matplotlib.pyplot as plt
from scipy.ndimage import gaussian_filter

def render_spatial_heatmap(deaths, arena_w, arena_h, phase=None, out_path=None):
    grid = np.zeros((arena_h, arena_w), dtype=np.float32)
    for d in deaths:
        if phase and d["boss_phase"] != phase: continue
        x, y = int(d["player_pos"][0]), int(d["player_pos"][1])
        if 0 <= x < arena_w and 0 <= y < arena_h:
            grid[y, x] += 1
    grid = gaussian_filter(grid, sigma=8)
    plt.imshow(grid, cmap="hot", origin="lower")
    plt.title(f"Deaths in {phase or 'all phases'}: n={len(deaths)}")
    plt.colorbar(label="density")
    plt.savefig(out_path)
```

### Diagnostic Reading

| 히트맵 패턴 | 가능한 원인 | 수정 타깃 |
|---|---|---|
| 단일 핫 클러스터 | 한 패턴이 한 위치에서 대부분의 플레이어 죽임 | 그 패턴의 공간 레이아웃 조정 |
| 아레나 모서리에 핫 스트라이프 | 플레이어가 코너에 몰림, 도주 X | 아레나 확장 또는 그곳의 kill volume 제거 |
| 액션 중간에 콜드 스팟 (사망 없음) | 안전지대 익스플로잇 | 아레나 지오메트리 패치 또는 패턴 커버리지 |
| 진입점 핫 클러스터 | P1이 전투 시작 시 너무 공격적 | P1 첫 3초 슬로우 |
| 보스 주변 동심 링 | 어떤 패턴 동안 플레이어가 보스에 밀착 | 내부 kill zone 추가 |
| 균등 분포 | 보스 "공정"하나 무차별 | 의도면 OK; 단조롭다면 X |

## View 2: Temporal Heatmap

x축은 패턴 시작 후 시간, 사망은 1/60s 단위 bin.

```python
def render_temporal_heatmap(deaths, pattern_id, out_path):
    times = [d["time_since_pattern_start"] for d in deaths
             if d["boss_pattern_id"] == pattern_id]
    plt.hist(times, bins=60)
    plt.xlabel("패턴 텔레그래프 시작 후 초")
    plt.ylabel("사망 카운트")
    plt.title(f"Pattern {pattern_id} death timing distribution")
    # 회피 윈도우 어노테이션
    plt.axvspan(0.4, 0.55, alpha=0.2, label="9-frame dodge window @ telegraph end")
    plt.legend()
    plt.savefig(out_path)
```

### Diagnostic Reading

| 시간 히스토그램 패턴 | 가능한 원인 |
|---|---|
| 회피 윈도우 외 스파이크 | 플레이어가 텔레그래프 인지 못 함; 시각 이슈 |
| 패턴 1프레임에 스파이크 | 텔레그래프 자체 부재; 순수 기습 사망 |
| 텔레그래프 종료 시 스파이크 | 회피 윈도우 너무 짧거나 방향이 불공정 |
| 패턴 전체에 균등 분포 | 명확한 "안전 / 위험" 비트 없음 — 페이싱 단조 |
| 양봉 분포 | 두 가지 실패 모드 — 둘 다 조사 |

## View 3: Pattern Attribution

어느 보스 상태/패턴이 가장 치명적?

```python
def render_pattern_attribution(deaths, out_path):
    from collections import Counter
    counts = Counter(d["boss_pattern_id"] for d in deaths)
    patterns = sorted(counts.keys())
    values = [counts[p] for p in patterns]
    plt.bar(patterns, values)
    plt.xlabel("Pattern ID")
    plt.ylabel("사망 카운트")
    plt.title("패턴별 사망 분포")
    plt.savefig(out_path)
```

### Diagnostic Reading

| 패턴 | 가능한 액션 |
|---|---|
| 한 패턴이 사망 > 50% 차지 | 패턴 불공정 → 재설계 |
| 한 패턴이 사망 < 5% 차지 | 패턴 평범 → 제거 또는 강화 |
| 후기 패턴 (P3, P4)이 < 10% | 플레이어가 후기 페이즈 도달 못 함 — 전반부 난이도 깨짐 |
| 후기 패턴이 > 60% | 난이도 곡선 OK지만 P4가 너무 어려울 수 |

## Cluster Detection (Auto-Diagnose)

수천 사망 아레나에선 핫 존 수동 읽기가 비현실적. DBSCAN으로 클러스터 추출:

```python
from sklearn.cluster import DBSCAN

def detect_death_clusters(deaths, eps=24, min_samples=20):
    coords = np.array([d["player_pos"] for d in deaths])
    clustering = DBSCAN(eps=eps, min_samples=min_samples).fit(coords)
    clusters = []
    for label in set(clustering.labels_):
        if label == -1: continue   # noise
        mask = clustering.labels_ == label
        clusters.append({
            "center": coords[mask].mean(axis=0),
            "size": mask.sum(),
            "deaths": [deaths[i] for i in np.where(mask)[0]],
        })
    return sorted(clusters, key=lambda c: -c["size"])
```

출력: 상위 5 클러스터 + 중심 좌표 + 크기 + 우세 패턴. 봇 리포트에 첨부.

## Safe-Zone Detection

역문제: 플레이어 존재가 있음에도 **사망 0**인 큰 영역. 익스플로잇일 가능성.

```python
def detect_safe_zones(deaths, presence_grid, arena_w, arena_h, min_size=400):
    death_grid = np.zeros((arena_h, arena_w))
    for d in deaths:
        x, y = int(d["player_pos"][0]), int(d["player_pos"][1])
        death_grid[y, x] += 1
    # presence > 0 이면서 deaths == 0 인 연속 영역
    # ... (presence > 0 ∩ death == 0 위 flood fill)
```

디자이너 리뷰: 높은 존재 + 사망 0인 안전지대 = **아레나 패치 또는 패턴 커버리지 확장**.

## Build Comparison (Regression Detector)

두 히트맵을 나란히: 현재 빌드 vs 이전. 유의 델타 셀 강조.

```python
def render_build_diff(deaths_now, deaths_before, out_path):
    grid_now = _to_grid(deaths_now)
    grid_before = _to_grid(deaths_before)
    diff = grid_now - grid_before
    plt.imshow(diff, cmap="RdBu", origin="lower")  # 빨강 = 지금 사망 더 많음
    plt.title("이전 빌드 대비 사망 분포 변화")
    plt.colorbar(label="Δ deaths per cell")
    plt.savefig(out_path)
```

사용 사례:
- 패턴 튜닝 후, 사망이 불공정 위치에서 옮겨갔는지 검증
- 리팩터 후, 새 핫 존 출현 X 검증
- 출시 전, 분포 진화의 매끄러움 검증

## Embedded in Bot Report

HTML 봇 리포트 ([[Bot Validation Pipeline Architecture]] subsystem C)는 보스별 다음을 임베드:

```
┌─ Boss meaeokkun — Death Analytics ──────────────────┐
│                                                     │
│  [Spatial heatmap, P1]    [Spatial heatmap, P3]     │
│                                                     │
│  [Temporal: pattern 4]    [Pattern attribution]     │
│                                                     │
│  Clusters detected: 3                               │
│   1. (820, 540) — 47% of P3 deaths — death_beam     │
│   2. (200, 100) — 23% of P1 deaths — overhead_drop  │
│   3. (640, 720) — 12% of P2 deaths — sweep_left     │
│                                                     │
│  Safe zones detected: 1                             │
│   1. (40-100, 600-680) — 0 deaths, 38s presence     │
│      — exploit candidate                            │
│                                                     │
│  Build delta vs ci-12344: +12% P3 deaths in cluster │
│      1; tuning regression possible                  │
└─────────────────────────────────────────────────────┘
```

## Designer Workflow

```
오전:
  1. 최신 봇 리포트 HTML 열기
  2. 클러스터 (top 3) 읽기 — 무엇이 가장 많이 죽이나?
  3. 안전지대 읽기 — 익스플로잇 후보?
  4. 빌드 델타 읽기 — 어제 대비 회귀?
액션:
  5. 클러스터 1개 골라 → 지배 패턴 식별
  6. 결정: 아레나 지오메트리 / 패턴 타이밍 / 텔레그래프 명료성?
  7. GDD 또는 구현 편집
  8. 봇 스위트 재실행 → 히트맵 재렌더 → diff
```

## Combining With Human Telemetry

봇 사망과 인간 사망에 같은 스키마 → 히트맵 깔끔하게 병합. 두 가지 방법:

1. **Side-by-side**: 봇 히트맵 + 인간 히트맵 렌더; 시각 비교 클러스터.
2. **Layered**: 봇 히트맵 베이스 (빨강), 인간 히트맵 알파 오버레이 (파랑).

불일치 = ⚠️ Hidden Defect 사분면 ([[Bot Human Validation Reconciliation]]):
- 인간 히트맵에 클러스터 있는데 봇엔 없음 → 봇 모델이 이 실패 누락
- 봇 히트맵에 클러스터 있는데 인간엔 없음 → 봇이 인간보다 약함
- 양쪽 다 클러스터 → 진짜 디자인 결함

## Sample Size Guidance

| 뷰 | 의미 있는 표본 크기 |
|---|---|
| Spatial heatmap (전체) | ≥ 500 사망 |
| Spatial heatmap (페이즈별) | 페이즈당 ≥ 100 사망 |
| Temporal histogram | 패턴당 ≥ 100 사망 |
| Pattern attribution | 총 ≥ 200 사망 |
| Cluster detection | ≥ 1000 사망 |
| Safe-zone detection | ≥ 5000 사망 + presence 데이터 |

> 봇은 분 단위로 이 양을 생산; 인간은 불가능. **히트맵은 오프라인 봇 강점 — 인간은 정성 설문 기여, 히트맵 밀도가 아님.**

## Echo Default Output Locations

```
production/qa/bots/heatmaps/
├── <date>-<boss>-<build>/
│   ├── spatial_p1.png
│   ├── spatial_p2.png
│   ├── spatial_p3.png
│   ├── spatial_p4.png
│   ├── temporal_pattern_<id>.png   # 패턴당 1개
│   ├── attribution.png
│   ├── clusters.json
│   ├── safe_zones.json
│   └── build_diff.png
```

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| 히트맵 한 번 렌더 후 갱신 X | 디자인 변경마다 드리프트; 신뢰 증발 |
| 모든 페이즈 합산 | P1과 P3 충돌 다름 — 섞으면 무용 |
| 안전지대 검출 무시 | 가장 어려운 결함 클래스; 자동화 가능한 유일한 진단 |
| 빌드 델타 뷰 없음 | 회귀 슬립; 튜닝 맹목 |
| n < 100 히트맵 | 시각 노이즈가 신호로 오독 |
| Spatial만 렌더, temporal 스킵 | 패턴 실패의 *언제*가 누락 |
| 클러스터 자동 검출 스킵 | 디자이너가 잘못된 클러스터를 primary로 안목 |

## Open Questions

- **[NEW]** 긴 플레이테스트 동안 히트맵 라이브 갱신 (스트리밍 렌더)?
- **[NEW]** Echo 아레나 셀 해상도 — 4×4 px? 8×8 px?
- **[NEW]** Presence 데이터 — 모든 플레이어 프레임 로깅 vs 샘플링 (10프레임마다)?
- **[NEW]** 클러스터 중심 좌표를 GDD에 명명된 랜드마크로 핀? ("P3 동측 kill 클러스터")
- **[NEW]** 클러스터 크기 델타 > X% 시 빌드 diff가 CI 실패?

## Related

- [[Bot Validation Pipeline Architecture]] — 히트맵은 대시보드 subsystem 안에 위치
- [[Bot Human Validation Reconciliation]] — 히트맵은 4사분면 매트릭스의 시각 레이어
- [[AI Playtest Bot For Boss Validation]] — 봇이 통계적 의미를 만들 만한 양을 생산
- [[Boss Two Phase Design]] — 페이즈별 히트맵이 페이즈 디자인 검증
