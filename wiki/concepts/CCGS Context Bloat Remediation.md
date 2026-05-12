---
type: concept
title: CCGS Context Bloat Remediation
created: 2026-05-12
updated: 2026-05-12
tags:
  - ccgs
  - workflow
  - design-pattern
  - context-management
  - documentation
  - echo-applicable
  - cross-project
status: developing
related:
  - "[[CCGS Framework]]"
  - "[[CCGS Subagent Tier Architecture]]"
  - "[[Brownfield Project Onboarding]]"
---

# CCGS Context Bloat Remediation

CCGS (Claude Code Game Studios)로 게임을 제작하면 시간이 지남에 따라 `design/gdd/` 디렉토리가 비대해지고, 세션 시작 시 자동 로드되는 컨텍스트가 증가하는 구조적 문제가 발생한다. 이 페이지는 그 원인 분석, 5 황금률, Tier 1-4 처방을 카탈로그화한다 — 모든 CCGS 프로젝트에 적용 가능.

## 진단 — Echo 케이스 (2026-05 측정)

| 파일 | 크기 | 문제 |
|---|---|---|
| `design/gdd/systems-index.md` | **~52 KB** | 단일 파일이 50 KB+ |
| `design/gdd/player-movement.md` | 1,893 줄 | 1,500줄+ |
| `design/gdd/time-rewind.md` | 1,000줄+ | |
| `design/gdd/damage.md` | 1,000줄+ | |
| `design/gdd/state-machine.md` | 1,000줄+ | |
| `design/gdd/input.md` | 1,000줄+ | |

> **핵심 패턴**: 같은 정보가 *두 곳에 중복* — `reviews/<system>-review-log.md` (정통 위치) + `systems-index.md` Status 컬럼 narrative.

## 비대화 5 원인

| 원인 | 규모 | 비고 |
|---|---|---|
| **Status 컬럼 narrative 누적** | ~30 KB | 매 review마다 추가, 줄어들지 않음 |
| **"Last Updated" 헤더 누적** | ~20 KB | 단일 라인에 모든 review 압축 |
| **GDD 본체 inline 결정 로그** | ~5 KB/GDD | 결정마다 narrative 추가 |
| **CLAUDE.md auto-import** | 가변 | `@design/gdd/systems-index.md` 임포트 시 통째 로드 |
| **Review-log 중복** | 2× | 같은 내용이 review-log + systems-index 양쪽 |

본질: **활성 데이터(현재 상태)** 와 **이력 데이터(과거 결정 narrative)** 가 같은 파일에 섞임.

## 5 황금률

1. **활성 데이터와 이력 데이터를 같은 파일에 섞지 마라** — 활성=현재 상태, 이력=과거 narrative.
2. **Status는 enum, narrative는 link** — `systems-index` Status 컬럼은 머신 리더블.
3. **세션 시작 시 자동 로드되는 파일에 가변 데이터 X** — `@import` 대상은 *룰 + 규약만*.
4. **계층적 CLAUDE.md** — `design/`에 들어갈 때만 design 룰 로드.
5. **Auto-compact가 default** — 매 review가 narrative를 영구 append하지 않음.

## Tier 1 — 즉시 적용 (인프라 변경 X)

### (1) Status 컬럼 narrative 단순화 — 가장 큰 ROI

**Before**:
```
Status: **Approved (re-review APPROVED 2026-05-11 lean mode + 
cross-review B3 fix VERIFIED 2026-05-11)** — `/review-all-gdds 
since-last-review` 2026-05-11 PASS on B3 boundary off-by-one 
closure. Option β tighten applied inline... [3,000+ 자]
```

**After**:
```
Status: Approved | 2026-05-11 | reviews/player-movement-review-log.md
```

→ **~30 KB 즉시 절감.** Narrative는 이미 review-log에 존재 (중복일 뿐).

### (2) "Last Updated" 헤더 단순화

**Before**: 25 KB single-line narrative.
**After**:
```
> Last Updated: 2026-05-11 — see design/gdd/reviews/ for full history
```

→ **~20 KB 절감.**

### (3) CLAUDE.md 임포트 점검

- `@design/gdd/systems-index.md` 임포트 제거
- 참조만 유지:
```markdown
See design/gdd/systems-index.md for current systems status.
GDDs in design/gdd/. Reviews in design/gdd/reviews/.
```

→ 세션 시작 시 자동 로드 X. 필요한 스킬이 명시적으로 read.

### Tier 1 결과 (Echo 실측 추정)
- systems-index.md: **52 KB → 5-7 KB** (~90% 절감)
- 세션 시작 컨텍스트 비용 동등 절감

## Tier 2 — 워크플로 패턴 (스킬 수정)

### (4) Status 컬럼 enum 룰 강제

`.claude/rules/design-docs.md` 추가:
```markdown
- systems-index.md Status 컬럼은 다음 형식만 허용:
  - `<Status enum> | <YYYY-MM-DD> | <review-log path>`
  - Status enum: Not Started / In Design / Designed / Approved / LOCKED
  - 추가 narrative 금지 — 모두 review-log 파일로
```

`/design-review`, `/review-all-gdds` 스킬이 이 룰 강제. 위반 시 자동 truncate.

### (5) Frontmatter as 머신-리더블 인덱스

각 GDD frontmatter:
```yaml
---
system_id: 6
status: Approved
last_reviewed: 2026-05-11
blocking_count: 0
recommended_count: 4
review_log: reviews/player-movement-review-log.md
---
```

스킬이 frontmatter만 grep → dashboard 자동 생성 (전체 GDD 읽지 않음).

### (6) Auto-compact 룰 (review-all-gdds)

`/review-all-gdds` 스킬에 추가:
```markdown
After review:
  - 최근 3개 review entry는 verbose 유지
  - 그보다 오래된 entry는 1-line summary로 압축
  - 압축 전 verbose 버전은 reviews/archive/ 로 이동
```

자연스러운 회수 메커니즘.

### (7) Next Steps 섹션 갱신 책임 부여

CCGS 일반 갭: `systems-index.md` Next Steps 섹션은 `/map-systems`가 최초 작성 후 갱신 책임자 없음 → stale.

`.claude/skills/review-all-gdds/SKILL.md` 또는 `.claude/skills/design-review/SKILL.md`에 추가:
```markdown
## Post-Review Index Maintenance

1. Read `design/gdd/systems-index.md` § Next Steps
2. Mark completed checkboxes for items this review closed
3. Add new pending items surfaced (e.g. new ADR ratification gates)
4. Update "Recommended Next" prose if priority order changed
5. Confirm with user: "May I update Next Steps section?"
```

## Tier 3 — 인프라 분리

### (8) 계층적 CLAUDE.md 활용

```
프로젝트 루트 CLAUDE.md         — 최소 (엔진/언어/룰)
design/CLAUDE.md                 — design 작업 시만 로드
design/gdd/CLAUDE.md             — GDD 작업 시만 로드 (신규)
```

Claude Code의 `CLAUDE.md` 계층 메커니즘이 디렉토리 진입 시만 로드.

### (9) systems-index 분할

```
design/gdd/systems-index.md         — 1-페이지 요약 (~5 KB)
design/gdd/systems-detail.md        — 각 시스템 1-paragraph 설명 (~20 KB)
design/gdd/dependency-graph.md      — 의존성 그래프 (~3 KB)
design/gdd/reviews/                 — 모든 review 이력
```

스킬이 필요한 것만 read.

### (10) GDD 본체 섹션 분할 (큰 GDD만)

1,500줄+ GDD에 한해:
```
design/gdd/player-movement.md            — Overview + Player Fantasy + Dependencies
design/gdd/player-movement-rules.md      — Detailed Rules + Edge Cases
design/gdd/player-movement-formulas.md   — Formulas (수식 무거움)
design/gdd/player-movement-ac.md         — Acceptance Criteria + Tuning Knobs
```

> **주의**: "GDD 1 파일에 8 섹션" 룰과 충돌. 부모 파일이 자식 파일을 link하는 방식으로 룰 만족 가능. CCGS 컨벤션 협의 필요.

## Tier 4 — 대규모 리아키텍처 (필요시)

### (11) 데이터 분리 — CSV + 마크다운

```
design/gdd/systems.csv              — 머신 리더블 표 (~3 KB)
design/gdd/systems-snapshot.md      — 사람용 현재 스냅샷, CSV로부터 생성 (~8 KB)
design/gdd/reviews/                 — 이력
```

스킬이 CSV read. 사람이 snapshot.md read.

### (12) Vector RAG (overkill)

GDD를 embedding → 스킬이 의미 기반 retrieval. **인디 솔로 규모엔 과잉**. AAA 팀 규모 또는 100+ GDD 시점에서만 검토.

## 구현 순서 권장

### 🟢 1시간 (수동 즉시)
1. systems-index.md Status 컬럼 truncate (~30 KB 절감)
2. "Last Updated" 헤더 정리 (~20 KB 절감)
3. CLAUDE.md 임포트 점검 + 가변 데이터 제거

→ **systems-index.md 52 KB → 5-7 KB.**

### 🟡 1주 (스킬 수정)
4. design-docs.md 룰 추가 (Status 컬럼 narrative 금지)
5. `/design-review` 스킬에 narrative-to-review-log 강제 로직
6. `/review-all-gdds` 스킬에 auto-compact 로직
7. Next Steps 갱신 책임 부여

→ 자동 유지. 다음부터 다시 비대화되지 않음.

### 🔴 1개월 (Tier 3)
8. Frontmatter 표준화 → dashboard 자동 생성
9. design/gdd/CLAUDE.md 분리
10. 큰 GDD section pagination

## Anti-Patterns

| 안티 패턴 | 왜 나쁜가 |
|---|---|
| Review narrative를 systems-index Status 컬럼에 append | 활성/이력 분리 위반. 영구 누적 |
| `@design/gdd/systems-index.md` CLAUDE.md 임포트 | 매 세션 50 KB 자동 로드 |
| GDD 본체에 결정 narrative inline | 결정마다 GDD 비대. review-log 무력화 |
| Review-log 파일 + systems-index 둘 다 narrative | 정확히 같은 정보 2× 저장 |
| "Last Updated" 헤더에 매 review 추가 | 한 줄에 모든 history 압축 — 무한 비대 |
| 자동 압축 메커니즘 부재 | 시간에 따라 단조 증가 |
| Status 컬럼이 자유 텍스트 (enum X) | 머신 리더블 X, dashboard 생성 불가 |

## CCGS 측 권고 (업스트림)

Echo는 다운스트림 프로젝트. 비대화는 CCGS 프레임워크 자체의 디자인 갭. CCGS upstream 기여 가능:

1. `.claude/rules/design-docs.md`에 활성/이력 분리 룰 추가
2. `/design-review`, `/review-all-gdds`, `/map-systems` 스킬에 narrative compaction 의무 추가
3. systems-index 템플릿을 머신 리더블 표 형식으로 변경
4. `design/gdd/CLAUDE.md` 권장 템플릿 추가 (계층 로딩)

## Open Questions

- **[NEW]** Echo 외 다른 CCGS 프로젝트들도 같은 비대화 겪고 있나? (CCGS upstream 사례 조사 필요)
- **[NEW]** 자동 compaction 시 어느 entry를 "verbose 유지" vs "1-line 압축"으로 분류? 최근 3개 default 합리?
- **[NEW]** GDD 본체 분할이 "1 파일에 8 섹션" 룰을 깨뜨림 — CCGS 컨벤션 어떻게 협의?
- **[NEW]** Frontmatter 기반 dashboard 자동 생성 — Pythonic? Bash? Godot tools?
- **[NEW]** 비대화 회귀 자동 감지 (CI gate): systems-index.md 크기 > N KB이면 fail?

## Echo 적용 액션 아이템

### 즉시 (Tier 1)
- [ ] `design/gdd/systems-index.md` Status 컬럼 모두 truncate
- [ ] "Last Updated" 헤더 정리
- [ ] CLAUDE.md auto-import 검토

### 단기 (Tier 2)
- [ ] `.claude/rules/design-docs.md` 룰 추가
- [ ] `/design-review` 스킬 패치
- [ ] `/review-all-gdds` 스킬에 auto-compact

### 중기 (Tier 3)
- [ ] Frontmatter 표준 + dashboard 자동 생성
- [ ] design/gdd/CLAUDE.md 분리

## Related

- [[CCGS Framework]] — 부모 프레임워크
- [[CCGS Subagent Tier Architecture]] — 에이전트 위계
- [[Brownfield Project Onboarding]] — 기존 프로젝트 도입 절차에서 비대화 점검 포함 가능
