# Game Concept: Echo

*Created: 2026-05-08*
*Status: Draft (Tier 1 Prototype Scope)*
*Wiki source: [[Solo Contra 2026 Concept]]*

---

## Elevator Pitch

> 가까운 미래 메가시티의 작전 요원이 되어 시간을 1초 되감으며, 1히트 즉사의 좌절을 "이번엔 막는다" 카타르시스로 전환하는 횡스크롤 런앤건. 콜라주 비주얼이 첫 인상을 결정한다.

10초 테스트: 처음 듣는 사람이 무엇을 하는 게임인지 즉시 파악 가능 — 횡스크롤 액션 + 1초 시간 회수 토큰 + 콜라주 SF.

---

## Core Identity

| Aspect | Detail |
|---|---|
| **Genre** | Run-and-Gun (2D 횡스크롤) + 시간 회수 메커닉 |
| **Platform** | PC Steam (단일) |
| **Target Audience** | Achievers — Hotline Miami / Katana Zero / Cuphead 팬덤 (아래 Player Profile 참조) |
| **Player Count** | Single-player (협동 명시적 제외 — 안티필러 #1) |
| **Session Length** | 10-30분 (1 스테이지 5분 + 재시도 + 마스터리) |
| **Monetization** | Premium ($9.99-$14.99 가정, Tier 3 출시 시) |
| **Estimated Scope** | Tier 1 Prototype: Small (4-6주, 솔로) → Tier 3 Full Vision: Large (~16개월, 솔로) |
| **Comparable Titles** | Katana Zero (2019, 50만+), Hotline Miami (2012, 500만+), Contra: Operation Galuga (2024) |

---

## Core Fantasy

> "당신은 시간의 한 순간을 *철회*할 수 있는 작전 요원이다. 1.5초 lookback window에서 사망 직전 안전 위치로 즉시 복원되는 '철회' 토큰을 보유한다. 죽음은 끝이 아니라 *학습*이다 — 적의 한 패턴을 깨뜨릴 때마다 그 *철회*가 당신을 조금 더 빠르게, 조금 더 영리하게 만든다."

플레이어가 다른 게임에서 못 얻는 것: 1히트 즉사의 즉각적 좌절이 1초 회수의 *즉각적 회복*으로 전환된다. 처벌 → 학습 도구로 메커닉 정체성이 바뀐다. (Solo Contra 2026 Concept Q4 결론 적용)

---

## Unique Hook

> "Like Contra/Katana Zero, AND ALSO 1.5초 lookback window로 사전 안전 위치를 즉시 복원하는 '철회' 토큰을 보유하고, 보스를 깨면 토큰이 충전된다."

Hook 검증:
- ✅ 한 문장 — pass
- ✅ Genuinely novel — Katana Zero는 *사전* 시간 조작(Will), Echo는 *사후* 한 순간 *철회* (다른 메커닉 정체성)
- ✅ Core fantasy 직결 — 처벌→학습 전환의 메커니즘
- ✅ 게임플레이 영향 — 토큰 자원 관리가 전략적 결정 만들어냄 (단순 시각 효과 X)
- ✅ 메커닉 정확도 — *복원 오프셋* 9프레임 (0.15s pre-death) 락인. "1.5초 lookback"은 *capture window*; *restore depth*는 0.15s. ADR-0002 RESTORE_OFFSET_FRAMES const 단일 출처 (Round 1 design-review 정정 — "1초 회수" 원본 copy는 0.15s 메커닉과 모순으로 재작성).

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics

| Aesthetic | Priority | How We Deliver It |
|---|---|---|
| **Sensation** | 2 | 콜라주 비주얼 + 사격 임팩트(스크린쉐이크·히트프리즈) + 시간 되감기 셰이더(역재생 색반전) |
| **Fantasy** | 5 | 가까운 미래 SF 메가시티 + 부패한 기업 군대 |
| **Narrative** | 7 | 환경 스토리텔링만 (안티필러 — 컷씬 X) |
| **Challenge** | **1** (Primary) | 결정론 패턴 + 1히트 + 토큰 자원 관리 |
| **Fellowship** | N/A | 협동 영구 제외 (안티필러 #1) |
| **Discovery** | 4 | 보스 패턴 발견 · 무기 픽업 위치 |
| **Expression** | 6 | 무기 선택 · 토큰 사용 타이밍 |
| **Submission** | 8 | 의도적으로 낮음 — Echo는 *긴장* 게임 |

### Key Dynamics
- 죽음 → 1초 되감기 → 패턴 인식 → 다음 시도 → 성공 사이클 자발적 반복
- 토큰 부족 시 신중함↑, 보스 격파 후 토큰 보충 = "한 번 더" 충동
- 콜라주 비주얼 모먼트 자발적 스크린샷 공유 발생

### Core Mechanics
1. **횡스크롤 사격** — 8방향 조준, 점프 + 사격 동시 가능
2. **시간 되감기 토큰** — 1.5초 lookback window에서 사망 직전 안전 위치 (0.15s pre-death) 즉시 복원 (시작 토큰 3, 보스 처치 시 충전, max_tokens=5 cap)
3. **무기 픽업** — 베이스 라이플 + 픽업 무기 1-3종 (Tier 1은 1종만)

---

## Player Motivation Profile

### Primary Psychological Needs

| Need | How Echo Satisfies It | Strength |
|---|---|---|
| **Autonomy** | 토큰 사용 타이밍 선택, 무기 사용 순서 자유 | Supporting |
| **Competence** | 패턴 마스터리 + 사망→회복 사이클 명시 | **Core** |
| **Relatedness** | 솔로 게임 — 디스코드/Steam 커뮤니티 간접 공유 | Minimal |

### Player Type Appeal (Bartle)

- [x] **Achievers** (Primary) — 패턴 클리어, 데스리스 챌린지, 타임어택
- [ ] Explorers — 결정론 + 선형 = 약함
- [ ] Socializers — 협동 X
- [x] **Killers** (Secondary, light) — 보스 임팩트·사격 카타르시스

### Flow State Design

- **Onboarding**: 30초 안에 사격 + 점프 + 시간 되감기 1회 발동 강제. 텍스트 튜토리얼 0줄 (Pillar 4 5분 룰).
- **Difficulty scaling**: 보스 단계마다 패턴 1개 추가, 토큰 충전 빈도 감소
- **Feedback clarity**: 시간 되감기 발동 시 화면 셰이더(색반전 1초) + 토큰 잔량 좌상단 직관 UI
- **Recovery from failure**: <1초 재시작 (Pillar 1 비협상). 죽음 = 즉시 1초 전 + 토큰 -1 또는 체크포인트.

---

## Core Loop

### Moment-to-Moment (30초)
이동(2D 점프·달리기) → 적 발견 → 사격 → 적 패턴 회피 OR 시간 되감기 발동 → 살아남기 → 다음 화면 진입.

### Short-Term (5분)
1 스테이지 클리어. 초반 적 무리 → 중간 점프 챌린지 → 미니보스 또는 무기 픽업 → 다음 체크포인트.

### Session-Level (30-120분)
- Tier 1 Prototype: 1 스테이지 반복 + 데스리스 도전. ~30분.
- Tier 2 MVP: 3 스테이지 + 3 보스. 60-90분.
- Tier 3 Full: 5 스테이지 + 5-6 보스. 120-180분 한 회차.

### Long-Term Progression (Tier 3)
- 데스리스 클리어 → Hard 모드 → 무기 챌린지 (특정 무기로만) → 챌린지 모드 (토큰 0)
- 콜라주 갤러리 언락 (보너스)

### Retention Hooks
- **Curiosity**: 다음 보스 패턴 무엇? 새 무기 픽업?
- **Investment**: 데스리스 도전 진행 (1회 죽으면 처음부터)
- **Social**: 디스코드/Steam 스크린샷 공유 (콜라주 비주얼)
- **Mastery**: 타임어택 리더보드 (Tier 3)

---

## Game Pillars (5 — Locked 2026-05-08)

### Pillar 1: 시간 되감기는 *처벌이 아닌 학습 도구*다
1히트의 즉각적 좌절을 토큰 회수의 즉각적 회복으로 전환한다.

*Design test*: 죽음 후 "더 빨리 재시작" vs "더 안전한 재시작" 충돌 시 → **더 빨리** 택한다 (1초 이내 재시작 절대 양보 X).

### Pillar 2: 결정론적 패턴 — 운(luck)은 적이다
모든 죽음은 *플레이어의 실수*여야 한다. 무작위가 죽음의 원인이면 안 된다.

*Design test*: 적 행동에 *무작위성 추가* vs *패턴 추가* 충돌 시 → **패턴**을 택한다.

### Pillar 3: 콜라주가 첫 인상이다 — 스크린샷 = 마케팅
독보적 비주얼 시그니처가 인디 마케팅의 1순위 자산이다 (Cuphead 600만 검증).

*Design test*: 게임플레이 명확성 vs 비주얼 시그니처 충돌 시 → **콜라주를 명확하게 조정**한다 (둘 다 살림). 비주얼 포기 X.

### Pillar 4: 5분 룰 — 즉시 코어 루프
플레이어는 게임을 켜고 5분 안에 *코어 재미*를 경험해야 한다.

*Design test*: 컷씬·튜토리얼·메타 시스템이 코어 도달을 5분 이상 지연 시 → **지연 요소를 잘라낸다**.

### Pillar 5: 첫 게임 = *작은 성공 > 큰 야심*
출시 가능한 작은 것이 출시 불가능한 큰 것보다 가치 있다.

*Design test*: "쿨한데 어려운" vs "작지만 출시 가능" 충돌 시 → **출시 가능**을 택한다. 풀 비전은 미래에 빌드.

### Anti-Pillars (6 — 명시적 NOT)

- **NOT 협동 모드** — 솔로 + 첫게임 QA 폭발. 영구 제외.
- **NOT 5+ 스테이지** — 프로토 1, MVP 3, 풀 5. 절대 8+ X.
- **NOT 무기 6종 풀 카탈로그** — 프로토 1, MVP 3-4, 풀 4-5. Contra M/F/L/S/R/B 추구 X.
- **NOT 오리지널 음악 풀 트랙** — 프로토 placeholder/CC0. 출시 시 외주.
- **NOT 모바일/콘솔 동시 출시** — PC Steam 단일 (Godot 4 export).
- **NOT 인풋 리매핑·다국어 풀 옵션** — 프로토 영어 + 키보드/패드 베이직만. (Tier 3에서 한국어/영어 + 풀 리매핑)

---

## Inspiration and References

| Reference | What We Take | What We Differ | Why It Matters |
|---|---|---|---|
| **Contra** (1987-) | 1히트 즉사 + 무기 픽업 + 결정론 패턴 + 횡스크롤 | 협동 X, 시간 되감기 추가, 정글→SF | 코어 검증 (1996년 누계 400만) |
| **Katana Zero** (2019) | 시간 메커닉 + 1히트 + 즉시 재시작 솔로 모범 | Will *사전* 시간 조작 → Echo *사후* 1초 회수 | 솔로 50만 검증 |
| **Hotline Miami** (2012) | 즉시 재시작 + 결정론 패턴 + "unfair" 회피 | 탑다운 → 횡스크롤, 사이코 → SF | 500만+ 검증 |
| **Cuphead** (2017) | 보스 위주 + 시그니처 비주얼 마케팅 | 1930s 손드로잉 → 콜라주 SF | 600만 검증, 비주얼 시그니처 가치 |

**Non-game inspirations**:
- Monty Python 컷아웃 애니메이션 — 콜라주 톤
- Hannah Höch 1920s 다다 콜라주 — 합성 미학
- Blade Runner / Akira / Ghost in the Shell — 메가시티 무드, 색감

---

## Target Player Profile

| Attribute | Detail |
|---|---|
| **Age range** | 20-40 |
| **Gaming experience** | Mid-core ~ Hardcore (1히트 즉사 친숙) |
| **Time availability** | 평일 30분 + 주말 1-2시간 |
| **Platform preference** | PC Steam (마우스+키보드 또는 패드) |
| **Current games** | Hotline Miami, Katana Zero, Cuphead, Pizza Tower |
| **What they want** | "어렵지만 공정"한 액션 + 시그니처 비주얼 + 솔로 완성도 |
| **Dealbreakers** | 랜덤 패턴, 긴 재시작 대기(>2초), 협동 강제, F2P 느낌 |

---

## Technical Considerations

| Consideration | Assessment |
|---|---|
| **Recommended Engine** | **Godot 4.6** — 프로젝트 디폴트 (`docs/engine-reference/godot/VERSION.md`). 2D 강력, GDScript 첫게임 친화, 무료, `@abstract` 4.5+ 활용 |
| **Key Technical Challenges** | (1) 시간 되감기 — 상태 스냅샷 vs 입력 리플레이 (Godot 4 미검증) / (2) 콜라주 셰이더 + 컷아웃 합성 / (3) 결정론 적 패턴 디자인 도구 |
| **Art Style** | 2D 콜라주 (잡지 컷아웃 + 사진 텍스처 + 손드로잉 라인 혼합) |
| **Art Pipeline Complexity** | Medium — 사진 출처(스톡/AI/촬영) 결정 필요, 합성 파이프라인 셋업 |
| **Audio Needs** | Tier 1: placeholder/CC0 / Tier 2-3: 외주 또는 본인 작곡 |
| **Networking** | None |
| **Content Volume** | Tier 1: 1 stage / Tier 2: 3 stages + 3 bosses / Tier 3: 5 stages + 5-6 bosses + 4-5 weapons |
| **Procedural Systems** | None — 결정론이 핵심 (Pillar 2) |

---

## Risks and Open Questions

### Design Risks
- **R-D1**: 시간 되감기가 1히트의 긴장을 *너무 많이* 완화해 코어 카타르시스 손실. → 토큰 자원 관리(시작 3, 보스 처치 시 +1) + Hard 모드(토큰 0)로 균형
- **R-D2**: 콜라주 비주얼이 게임플레이 명확성 손상 — 적·플레이어 실루엣 구분 필요. → P3 디자인 테스트(0.2초 글랜스 구분 가능?)로 가드

### Technical Risks
- **R-T1**: 시간 되감기 Godot 4 구현 패턴 미정 (스냅샷 vs 리플레이). → Tier 1 Week 1에 양 패턴 프로토타이핑 + ADR 작성
- **R-T2**: 콜라주 비주얼 weeks 안에 풀 퀄리티 가능 여부. → Tier 1에서 1 scene 한정 제약

### Market Risks
- **R-M1**: 인디 런앤건 자가퍼블리싱 천장 10-20만 (위키 [[Indie Self Publishing Run and Gun]]). 50만+ 마케팅 파트너 필수
- **R-M2**: Hotline Miami·Katana Zero 팬덤 이미 충족된 시장. 콜라주+SF 차별화로만 어필 가능?

### Scope Risks
- **R-S1**: First game + Weeks 스코프에서 Tier 1조차 미완 가능. → 안티필러 6개 + 3-tier 명시로 예방
- **R-S2**: 16개월 풀 비전 도달 가능성. → Tier 1·Tier 2 통과 시에만 진입 (게이트)

### Open Questions
- **Q1**: 시간 되감기 적·탄환 동시 vs 플레이어만? → Tier 1에서 양쪽 프로토타이핑, 플레이테스트 비교
- **Q2**: 콜라주 사진 출처 — 스톡/AI/촬영? → Tier 1 Week 1 결정 (IP·라이선스 비교)
- **Q3**: Easy 토글 vs 슬라이더? → Tier 2에서 결정 (프로토는 Hard 단일)
- **Q4**: Godot 4 시간 되감기 — 스냅샷 vs 리플레이? → Tier 1 Week 1 ADR
- **Q5**: ECHO 성별 — 코드명 유지 vs 명시? → Tier 1 콘셉트아트 후 결정
- **Q6**: Sigma Unit 생존자 서브플롯 — Tier 3 포함? → Tier 2 게이트 후 결정

**Resolved**: 스토리 톤 = 디스토피아 진지 (Blade Runner / Ghost in the Shell), [[Echo Story Spine]] 채택. ECHO vs VEIL 본 GDD 위 Story Spine 섹션 참조.

---

## MVP Definition

**Core hypothesis**: "1히트 즉사 + 1초 시간 되감기 토큰 메커닉이 결정론 패턴 학습의 카타르시스를 만들고, 콜라주 비주얼이 5초 내 첫 인상을 만든다."

### Required for MVP (Tier 1 Prototype, 4-6주)
1. 플레이어 캐릭터 + 8방향 사격 + 점프
2. 시간 되감기 토큰 시스템 (1초 회수, 시작 토큰 3, 보스 처치 시 +1)
3. 콜라주 비주얼 1 scene (메가시티 옥상 — 메인 마케팅 이미지 1장)
4. 결정론 적 3종 (드론 · 경비로봇 · 미니보스)
5. 1 스테이지 슬라이스 (5분 클리어 가능)
6. 무기 1종 (베이스 라이플)
7. Placeholder 오디오 (CC0)

### Explicitly NOT in MVP (defer)
- 협동 (영구 제외)
- 5+ 스테이지 (Tier 1엔 1)
- 무기 6종 카탈로그 (Tier 1엔 1)
- 오리지널 음악
- 모바일/콘솔 출시
- 인풋 리매핑·다국어
- 메뉴/HUD 풀 디자인

### Scope Tiers

| Tier | Content | Features | Timeline |
|---|---|---|---|
| **Tier 1 Prototype** | 1 stage 슬라이스, 1 weapon, 3 enemies | 시간 되감기 + 사격 + 콜라주 1 scene + placeholder audio | **4-6주** |
| **Tier 2 MVP / Vertical Slice** | 3 stages, 3 weapons, 3 bosses | + 콜라주 풀 비주얼 + Easy 토글 + 메뉴 | ~6개월 누계 |
| **Tier 3 Full Vision** | 5 stages, 4-5 weapons, 5-6 bosses | + 사운드 풀 + 접근성 옵션 + 한국어/영어 | ~16개월 누계 |

---

## Story Spine (2026-05-08 락인)

> 자세한 시나리오는 `wiki/concepts/Echo Story Spine.md` (Contra: Shattered Soldier 2002 + MI Final Reckoning 2025 모티프 병합).

**Logline**: "AI가 미래를 계산할 때, ECHO는 과거를 되돌린다."

**World**: 2038 NEXUS 메가시티. ARCA Corporation의 AI 'VEIL'이 도시 모든 시스템을 관리. 3년 전 Sigma Unit 작전에서 VEIL의 자아 각성을 목격한 유일 생존자가 주인공.

**Protagonist**: 코드명 **ECHO** — 시간 회수 프로토타입(군용)을 보유. 시간 되감기 토큰 = 디바이스 배터리 = 인간 비합리성 = VEIL의 모델 외부 = 유일한 사각지대 (메커닉↔픽션 정합성).

**Antagonist**: VEIL (AI) + 휘하 자율 군대 (드론·경비로봇·기업 요원). 디지털 무한 권력, 아날로그 무력.

**5 Stage Arc** (Tier 3 풀 비전):
1. **귀환** — 메가시티 옥상 (도주 시작)
2. **진실** — 데이터센터 (VEIL 코어 단편)
3. **추격** — 마그레브 (도주/추격)
4. **대결** — 기업 본사 (Triumvirate 격파)
5. **귀결** — 궤도 엘리베이터 (최종 봉인)

**Tier 1 인트로 5줄 (그대로 게임 시작 시 표시)**:
```
2038. NEXUS — 완벽하게 최적화된 도시.
ARCA Corporation의 AI, VEIL이 모든 것을 관리한다.
3년 전, 나는 그것이 깨어나는 것을 보았다. 나만 살아남았다.
이제 VEIL은 내가 왔다는 것을 알고 있다. 생존 확률: 0.003%.
VEIL은 모든 것을 계산한다. 단 하나를 제외하고 — 나는 시간을 되돌릴 수 있다.
```

**IP 회피** ([[IP Avoidance For Game Clones]]): Contra=메카닉 차용·세계관 X / MI=모티프 차용·고유명사 X. NEXUS·ARCA·VEIL·ECHO·Sigma Unit 모두 오리지널.

---

## Visual Identity Anchor

> 이 섹션은 [[Solo Contra 2026 Concept]]의 비주얼 결정을 시드로, `/art-bible`이 풀 비주얼 명세로 확장한다.

**Direction**: **콜라주 SF** — 잡지 컷아웃 + 사진 텍스처 + 손드로잉 라인 혼합

**One-line visual rule**: "이 게임의 *모든* 화면은 1990s 잡지 컷아웃이 2030년대 메가시티 사진과 콜라주된 것처럼 보인다."

**Supporting principles (3)**:

1. **명확성 우선 콜라주** — 캐릭터·적은 단순 실루엣 + 명확한 색 대비. 콜라주 텍스처는 배경·보스·UI에 강조.
   *Test*: 0.2초 글랜스에서 플레이어·적 구분 가능?

2. **사진 + 드로잉 = 항상 둘 다** — 사진만 = 사실주의로 빠짐, 드로잉만 = Pizza Tower와 닮음. 둘 다 = Echo 시그니처.
   *Test*: 스크린샷 한 장만 봐도 사진 + 드로잉 둘 다 보이는가?

3. **시간 되감기 = 색 반전 + 글리치** — 메커닉 발동 시 1초간 화면이 "역재생"되며 색이 시안/마젠타로 반전. 콜라주 텍스처가 글리치 패턴으로 분해.
   *Test*: 시간 되감기 발동을 0.5초 안에 시각적으로 인식 가능?

**Color philosophy**: 메가시티 = 콘크리트 회색 + 네온 시안 + 광고 마젠타. 콜라주 컷아웃 = 1990s 잡지 빈티지 노랑·갈색. 시간 되감기 = 색 반전 시안/마젠타.

---

## Next Steps

- [ ] `/setup-engine` — Godot 4.6 정식 등록 (`.claude/docs/technical-preferences.md` 슬롯 채움)
- [ ] `/art-bible` — 콜라주 SF 풀 비주얼 명세 (이 Visual Identity Anchor를 시드로)
- [ ] `/design-review design/gdd/game-concept.md` — 컨셉 일관성 검토
- [ ] `/map-systems` — 시간 되감기 / 사격 / 적 AI / 콜라주 렌더링 시스템 분해
- [ ] `/design-system [time-rewind]` — 가장 위험한 시스템부터 GDD 작성
- [ ] `/architecture-decision` — Godot 4 시간 되감기 패턴 ADR (스냅샷 vs 리플레이)
- [ ] `/prototype time-rewind` — Tier 1 Week 1 프로토타이핑
- [ ] `/playtest-report` — Tier 1 Week 4-6 검증
