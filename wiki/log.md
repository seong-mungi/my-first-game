---
title: Wiki Log
updated: 2026-05-10
---

# Wiki Log

Reverse chronological log of wiki operations. Newest at top.

## [2026-05-10] save | Bot Validation Pipeline (B+C+D) + 3 supporting concepts (E/F/G)

- **Mode:** main agent · /save (4 pages from same conversation thread) · 4 pages
- **Pages created (4):**
  - Synthesis: [[Bot Validation Pipeline Architecture]] — B (Godot↔Python RL 브릿지) + C (Dashboard + CI 게이트) + D (GDD 피드백 루프) 통합 아키텍처. msgpack/TCP 락스텝, GitHub Actions YAML, 메트릭 위반 → 결정 매트릭스, 솔로 개발자 우선순위 Tier 1-3.
  - Concept: [[Heuristic Bot Reaction Lag Simulation]] — 휴리스틱 봇에 perception(6f)+action(3f)=9f 인간 반응 지연 주입. Per-modality lag (visual 11f / audio 9f / proprioceptive 3f), GDScript 레퍼런스 구현, 캘리브레이션 sweep 프로토콜.
  - Concept: [[GDD Bot Acceptance Criteria Template]] — GDD 8.2 봇 검증 섹션 표준 YAML 템플릿. 보스/잡몹/무브먼트/무기 4종 템플릿 + tier discipline (ci/nightly/release) + 안티패턴 6종.
  - Concept: [[RL Reward Shaping For Deterministic Boss]] — Echo PPO 보상 함수 디자인. damage*10, death-100, clear+500, phase+50, rewind+5/-2. 커리큘럼 4단계, reward hacking watchlist 5종, lethal_threat_imminent 디자이너-인증 시그널.
- **Key insights captured:**
  - **B 핵심**: TCP+msgpack 락스텝 8 envs 병렬 = 결정론 보존 + ~8× 학습 가속. `Engine.physics_ticks_per_second=60`, `max_physics_steps_per_frame=1`, RNG 시드 reset, no `_process` 의존, no `OS.get_ticks_msec()`.
  - **C 핵심**: 5단계 verdict 계산 (Random>1%, Scripted<100%, Heuristic 30-70%, Pattern-w/o-rewind P3=0%, TTFC ±20%) → CI 패스 5-10분 / 나이트리 2시간 / 릴리즈 6-12시간.
  - **D 핵심**: GDD AC 8.2 봇 검증 행 → 봇 결과 → 메트릭 위반 매트릭스 → GDD 또는 코드 수정 → 재검증 자동 루프. 디자이너 일일 워크플로 정립.
  - **E 핵심**: 인간 반응 시간 (visual 250ms / audio 160ms / 트레인드 게이머 150-200ms = 9-12 frames) = Echo 9프레임 rewind 윈도우와 정확히 일치. 봇 lag = 인간 lag 일 때만 휴리스틱 win-rate가 인간 공정성의 프록시 역할.
  - **F 핵심**: 모든 측정 가능한 디자인 의도는 (메트릭 ID + bot + runs + target band + tier)로 표현 가능. 표현 불가능하면 → 인간 검증 컬럼 또는 의도 sharpening 필요.
  - **G 핵심**: 프레임 생존 보상 = 0 (스톨 익스플로잇 차단). dense+sparse 혼합 (damage delta + 죽음/클리어/페이즈 milestone). lethal_threat_imminent는 디자이너가 큐레이트해야 RL이 rewind를 올바르게 학습.
- **Pages updated (meta):** [[index.md]] (Synthesis +1, Tooling/Framework +3 — total +4), [[log.md]] (이 블록), [[hot.md]] (활성 토픽 + Top Pages 갱신)
- **Source conversation**: 봇 검증 방법론 → 사용자 옵션 (B/C/D) 선택 → 통합 파이프라인 답변 → 사용자 옵션 (E/F/G) 선택 → 4 페이지 일괄 저장
- **Cumulative**: 이번 세션 6 페이지 (이전 2 + 이번 4). 봇 검증 카탈로그 완성: WHY → WHAT → HOW → INTEGRATION.

## [2026-05-10] save | Deterministic Game AI Patterns + AI Playtest Bot For Boss Validation

- **Mode:** main agent · /save (conversation distillation) · 2 pages
- **Pages created (2):**
  - Concept: [[Deterministic Game AI Patterns]] — 결정론 게임에서 AI 활용 가능한 4 zone (런타임 game AI, 메타 레이어, 오프라인 디자인, 플레이어 보조) + 검증 게임 매트릭스 + Echo Tier 1-3 권고
  - Synthesis: [[AI Playtest Bot For Boss Validation]] — 4 봇 아키타입 (Random/Scripted/Heuristic/RL) + clear/death/learning/time-mechanic 메트릭 + Echo Godot 4.6 구현 경로 + 4 검증 시나리오
- **Key insights captured:**
  - **The Core Rule**: AI는 패턴을 만들거나 측정하거나 미러링할 수 있지만, 플레이어가 학습 중인 패턴을 런타임에 변형해서는 안 된다.
  - **4 Zone 분류**: ① Runtime game AI (BT/FSM/GOAP — 결정론 보존 가능), ② Meta layer (디렉터/넴시스 — 부분 양보), ③ Offline tools (분석·튜닝·생성 — 결정론 무관), ④ Player aid (고스트·힌트 — 결정론 보존).
  - **Echo Tier 1 권고**: Cuphead-style FSM 보스 + Trackmania-style 고스트 리플레이 + 사망 히트맵 분석. RL 봇은 Tier 3로 이연.
  - **봇 아키타입 검증 매핑**: Random=floor / Scripted=ceiling+결정론 검증 / Heuristic=학습 곡선 시뮬 / RL=인간 학습 곡선.
  - **Echo 시간메커닉 봇 메트릭**: Rewind Usage Rate / Rewind Save Rate / Pattern-Without-Rewind Clear Rate — 9프레임 윈도우 공정성 + 사형선고 패턴의 되감기 강제 검증.
  - **금지 영역**: 런타임 적응형 난이도 / 랜덤 보스 패턴 / 온라인 학습 적 행동 / Nemesis-style 보스 개인화 — Echo의 결정론 학습 정체성과 충돌.
- **Pages updated (meta):** [[index.md]] (Synthesis +1, Tooling/Framework +1), [[log.md]] (이 블록), [[hot.md]] (활성 토픽 + Top 페이지 갱신)
- **Source conversation**: GDD player-movement.md B 섹션 해석 → 학습/결정론 통합 설계 → 보스 디자인 적용 → 결정론 게임의 AI 활용 → AI 봇 검증 방법론 (5턴 연쇄)

## [2026-05-10] autoresearch | 콘트라 엔트리별 차별화 + 런앤건 혁신 시스템 + cross-장르 이식

- **Mode:** main agent · 3-topic combined research · 2 rounds · 10 web searches · 15 pages
- **Targets (3 topics):**
  1. Contra 시리즈 엔트리별 차별화 게임시스템 분석
  2. 런앤건에서 검증·기발·혁신 게임시스템 조사
  3. 런앤건에 적용 가능한 cross-장르 게임시스템 조사
- **Pages created (15):**
  - Synthesis (3): [[Research Contra Series Per-Entry Differentiation]], [[Research Run and Gun Innovative Systems]], [[Research Cross-Genre Systems For Run and Gun]]
  - Entities — Contra 엔트리 6신규 (1992-2019): [[Contra III The Alien Wars]], [[Contra Hard Corps]], [[Contra Shattered Soldier]], [[Neo Contra]], [[Hard Corps Uprising]], [[Contra Rogue Corps]]
  - Concepts (6): [[Contra Per Entry Mechanic Matrix]], [[Hit Rate Grading System]], [[Pink Parry System]], [[Time Manipulation Run and Gun]], [[Roguelite Metaprogression For Run and Gun]], [[Stealth Information Visualization]]
- **Key findings:**
  - **Topic 1 — 콘트라 생존 규칙**: (a) 2D 측면 고수 = 생존, 3D/관점 변경 = 실패 (1996/1998/2019 모두). (b) 한 번에 한 메카닉 축만 추가 = 성공, 4축 동시 추가(Rogue Corps) = 실패. (c) 두 후속 엔트리에서 재사용된 시스템(슬라이딩, 듀얼 무기, 캐릭터 셀렉트)만 검증 자산.
  - **Topic 2 — 7대 검증 혁신**: 무기 융합(Gunstar 4×pair=14), 분기+캐릭터(Hard Corps), Hit Rate(Shattered Soldier), 핑크 패리(Cuphead), 파괴 지형(Broforce), 2-overload 스왑(Galuga 2024), 무한 1차+제한 2차(Huntdown).
  - **Topic 3 — 5대 cross-장르 이식**: 시간 조작(PoP/Braid/Katana Zero), 로그라이트 메타(Dead Cells/Hades/Uprising/Galuga), 반응형 내러티브(Hades), 불릿타임(Max Payne — 2D 이식 희소), 스텔스 가시화(Mark of the Ninja).
- **Echo 적용 권고 (Tier 1)**: 시간 되감기(잠금) + **Mark of the Ninja 가시화 원칙**(예측 탄도, 토큰 카운트, 되감기 윈도우 명시 표시) — cost low / synergy high. 무기 융합·핑크 패리·메타프로그레션은 Tier 2/3 평가로 이연.
- **Pages updated (meta):** [[index.md]] (Synthesis +3, Concepts Run-and-Gun +3, Cross-Genre 신규 섹션 +3, Entities Games +6, By Tag #cross-genre·#mechanic-comparison 신규), [[log.md]] (이 블록), [[hot.md]] (활성 토픽 전환 + Top 페이지 갱신 + Cross-Reference Density)
- **Constraints**: villains.fandom·contra.fandom 일부 페이지 403 → Wikipedia/StrategyWiki/contrapedia/PCGamer/GameDeveloper으로 대체. fandom.com Hit Rate / Parry Slap 페이지는 접근 가능. Confidence high (다중 출처 일치).
- **Open questions filed:** Mode 7이 후속에서 사라진 이유 / Hit Rate 외부 채택 부재 이유 / 파괴지형 후속 부재 이유 / 2D 불릿타임 부재 이유 / Echo Tier 2 두 번째 axis 선택.

## [2026-05-08] autoresearch | Contra 시나리오 + MI Final Reckoning 병합 → Echo Story Spine

- **Mode:** sub-agent (sonnet) 콘텐츠 페이지 생성 → 메인 에이전트 메타 갱신
- **Targets (3-step):**
  1. 콘트라 시리즈 시나리오 톱 식별
  2. 영화 *Mission: Impossible — The Final Reckoning* (2025) 시나리오 서치
  3. {1}+{2} 병합 → Echo 초기 게임 시나리오 작성
- **Pages created (5):**
  - Synthesis (1): [[Research Contra Best Story Series]] — Shattered Soldier(2002) 선정 비교표
  - Concepts (1): [[Echo Story Spine]] — Echo 메인 시나리오 골격
  - Entities (1): [[The Entity AI Villain]] — MI 빌런 → VEIL 변환
  - Sources (2): [[Contra Shattered Soldier Story Source]], [[MI Final Reckoning Plot]]
- **Step 1 결과**: **Contra: Shattered Soldier (PS2, 2002)** 선정 — Hard Corps 분기 서사 선구를 잇되 Triumvirate 음모 + "영웅은 체제의 도구였다" 반전 + 랭크 기반 3+1 다중 엔딩으로 시리즈 시나리오 정점. Metacritic 78, EGM 9/10.
- **Step 2 결과**: MI Final Reckoning(2025) 차용 핵심 모티프 3가지:
  1. 디지털 vs 아날로그 — Entity는 디지털 모든 곳을 조작하나 아날로그(종이·키)에 무력. "진실은 물리적이다" 주제축
  2. AI=신적 알고리즘, 인간 비합리성=유일한 약점 — 자기희생/감정/무모한 선택은 모델 외부
  3. 대리인→본체 + 카운트다운 — Gabriel 격파해도 Entity 건재 + 핵 카운트다운
- **Step 3 결과 — Echo Story Spine 로그라인**: "AI가 미래를 계산할 때, ECHO는 과거를 되돌린다."
  - 세계: NEXUS 메가시티 (2038), ARCA Corporation, AI=VEIL
  - 주인공: 코드명 ECHO — Sigma Unit 유일 생존자, 시간 회수 프로토타입 보유
  - 5 스테이지: 1)귀환 옥상, 2)진실 데이터센터, 3)추격 마그레브, 4)대결 본사, 5)귀결 궤도
  - 메커닉↔픽션 정합성: 시간 되감기 토큰 = 인간 비합리성 = VEIL의 유일한 사각지대 (MI 모티프 #2 직결)
- **Tier 1 인트로 5줄 (게임 시작 시 그대로 사용)**:
  ```
  2038. NEXUS — 완벽하게 최적화된 도시.
  ARCA Corporation의 AI, VEIL이 모든 것을 관리한다.
  3년 전, 나는 그것이 깨어나는 것을 보았다. 나만 살아남았다.
  이제 VEIL은 내가 왔다는 것을 알고 있다. 생존 확률: 0.003%.
  VEIL은 모든 것을 계산한다. 단 하나를 제외하고 — 나는 시간을 되돌릴 수 있다.
  ```
- **Pages updated (meta):** [[index.md]] (Synthesis +1, Concepts My Game Baselines +1, Entities Characters/Fictional 신규 섹션 +1, Sources +2), [[log.md]] (이 블록), [[hot.md]] (활성 토픽 전환·Top 페이지 15개로 확장·Recent Decisions 2개 추가·Open Questions Echo 카테고리 신규·Cross-Reference Density 갱신 81→86)
- **Cross-links:** [[Solo Contra 2026 Concept]], [[Contra]], [[Contra Operation Galuga]], [[IP Avoidance For Game Clones]], [[Run and Gun Success Pattern Matrix]], [[Cooperative Run and Gun Design]]
- **Open questions:** ECHO 성별(코드명 유지 vs 명시) / 스토리 톤(디스토피아 진지 vs 풍자 펑크 — Solo Contra Q3 이월) / Sigma Unit 생존자 서브플롯 Tier 3 포함 여부
- **Constraints:** villains.fandom.com·contra.fandom.com·missionimpossible.fandom.com·themoviespoiler.com 전부 HTTP 403 — Wikipedia/IMDb/SlashFilm/OtakuKart/contrapedia.wordpress.com/oldgamehermit.com으로 대체. Shattered Soldier "Bahamut" 캐릭터 소속 위키 데이터 불명확(Hard Corps: Uprising 추정) — Echo Spine 미포함. Confidence medium (1차 소스 일부 미확인).

## [2026-05-08] design-decision | Solo Contra 2026 컨셉 락인 (v0)

- **Mode:** 사용자 결정 → 메인 에이전트가 합성 페이지 작성 + 메타 동기화
- **Decision summary (사용자):**
  - 차별화 메커닉: **시간 되감기** (Katana Zero × Contra)
  - 비주얼 시그니처: **콜라주** (잡지 컷아웃·믹스드 미디어)
  - 무대: **가까운 미래 SF** (2030-2040)
- **Pages created (1):** [[Solo Contra 2026 Concept]] — design-baseline-v0, status: medium confidence. 7코어 적용 매트릭스(5 유지, 1 축소, 1 제거) + 시간 되감기 v0 규칙 + 콜라주 비주얼 + 5스테이지 후보 + 16개월 작업량 + 의사결정 트리 3단계 + 6 미해결 질문.
- **Pages updated (meta):** [[index.md]] (Synthesis +1, Concepts Run-and-Gun +2, My Game Design Baselines 신규 섹션 +1, Entities Games +3, Sources +1), [[log.md]] (이 블록), [[hot.md]] (활성 토픽·Top 페이지 12개로 확장·Resolved Questions 신규·Open Questions 재구성·Cross-Reference Density 갱신)
- **7코어 → Solo 적용 결과:**
  - ✅ 유지 (5): 횡스크롤 2D / 1히트 즉사 + Easy 토글 / 결정론 적 / 기본 무기 안전망 / 보스 5-6개로 한정
  - ⚠️ 축소 (1): 무기 다변화 — Contra 6종(M/F/L/S/R/B) → 4-5종으로 축소
  - ❌ 제거 (1): 2인+ 협동 — 솔로 QA 비현실적, Katana Zero·Hotline Miami 솔로용 성공 검증
- **다음 3단계 (의사결정 트리):**
  1. 시간 되감기 v0 프로토타입 (1주, Godot 4) — 단독 재미 검증
  2. 콜라주 비주얼 컨셉아트 1장 (3-5일) — 톤 락인
  3. 스테이지 1 수직 슬라이스 (4주) — 핵심 재미 검증
- **현실 매출 기대치 ([[Indie Self Publishing Run and Gun]]):** 마케팅 파트너 없으면 10-20만 장이 천장. 50만+는 시그니처 비주얼(콜라주가 강점) + 인디 페스티벌 + 인플루언서 캠페인 동시 필요.
- **Cross-links:** [[Run and Gun Success Pattern Matrix]], [[Modern Difficulty Accessibility]], [[Followup Modern Acceptance And Indie RnG Threshold]], [[Katana Zero]], [[Cooperative Run and Gun Design]], [[Contra Weapon System]], [[IP Avoidance For Game Clones]]
- **Open questions (6 신규):** 시간 되감기 적·탄환 동시 vs 플레이어만 / 콜라주 사진 출처(스톡/촬영/AI) / 스토리 톤(디스토피아 vs 펑크) / Godot 4 시간 되감기 구현 패턴(스냅샷 vs 입력 리플레이) / 무기 4-5종 SF 재해석 카탈로그 / Easy/Hard 토글 vs 슬라이더

## [2026-05-08] followup | Q4/Q5 후속 리서치 — 1히트 현대 수용성 + 인디 매출 천장

- **Mode:** sub-agent (sonnet) 콘텐츠 페이지 생성 → 메인 에이전트 메타 갱신
- **Targets:** Q4 (2026 플레이어가 1히트 즉사 수용?) + Q5 (인디 런앤건 + 0퍼블리셔 200만 장 사례?)
- **Pages created (7):**
  - Synthesis (1): [[Followup Modern Acceptance And Indie RnG Threshold]]
  - Concepts (2): [[Modern Difficulty Accessibility]], [[Indie Self Publishing Run and Gun]]
  - Entities (3): [[Pizza Tower]], [[Katana Zero]], [[Hotline Miami]]
  - Sources (1): [[Steam Indie 1Hit Kill Reviews]]
- **Q4 결론:** 장르 팬은 *즉시 재시작 + 결정론 패턴 + Easy 토글 1개* 조건에서 1히트 즉사 수용. Hotline Miami(500만+) / Katana Zero(50만 1년) 검증. Steam "unfair" 논쟁의 실제 원인은 즉사가 아닌 랜덤 패턴·긴 재시작.
- **Q5 결론:** 0-퍼블리셔 200만 장 인디 런앤건 사례 **미존재**. Cuphead=Microsoft, Broforce·Katana Zero·Hotline Miami=Devolver. 자가퍼블리싱 런앤건 현실 천장 10-20만, 50만+는 마케팅 파트너 + 시그니처 비주얼 + 페스티벌 동시 필요.
- **Cross-links:** [[Run and Gun Success Pattern Matrix]], [[Cuphead]], [[Broforce]], [[Contra]], [[IP Avoidance For Game Clones]]
- **Open questions:** Pizza Tower 정확 판매량 / Blazing Chrome·Huntdown 실제 판매 / 2024+ 인디 런앤건 난이도 옵션 표준화 비율
- **Constraints:** Steam 판매량은 SteamSpy/VGInsights 추정 / "unfair" 빈도 정량 통계 부재 / Vampire Survivors 6M은 levvvel.com 집계치

## [2026-05-08] autoresearch | Contra 시스템 분석 + 런앤건 성공 패턴 메타 분석

- **Mode:** sub-agent (sonnet) creates content pages → main agent updates index/log/hot
- **Topics (2):**
  1. Contra 시스템 분석 (deep dive: 무기·생명·스테이지·협동·시리즈 진화·문화적 영향)
  2. 성공한 런앤건 5작품 공통 요소 메타 분석 (Contra/Metal Slug/Gunstar Heroes/Cuphead/Broforce)
- **Pages created (9):**
  - Synthesis (2): [[Research Contra System Analysis]] (158줄), [[Research Run and Gun Success Patterns]] (235줄)
  - Concepts (4): [[Contra Weapon System]], [[Konami Code]], [[Cooperative Run and Gun Design]], [[Run and Gun Success Pattern Matrix]] (210줄)
  - Entities (1): [[Contra Operation Galuga]] (WayForward 2024 리메이크)
  - Sources (2): [[Wikipedia Contra Series]], [[Wikipedia Konami Code]]
- **Pages enriched (1):** [[Contra]] — 103줄 → 186줄. 생명/콘티뉴 심층, NES 8스테이지 전체 테이블, 협동 설계 함의, 시리즈 진화 타임라인(1987~2024), Open Questions 3개 추가.
- **Pages updated (meta):** [[index.md]] (Synthesis +2, Concepts Run-and-Gun +4, Entities Games +1, Sources +2, Tags 3 신규 카테고리), [[log.md]] (이 블록), [[hot.md]] (활성 토픽·Top 페이지·결정 로그·교차참조 밀도 갱신)
- **Topic 1 핵심 결론 (Contra):** 콘트라의 차별성은 *무기 차별화* + *동시 협동(2P 양보 X)* + *코나미 코드 문화 전파*에 있다. 1987 NES 출시 이후 1996년 이미 누적 400만 장. 3D 전환은 3차례(1996 Legacy of War, 1998 Adventure, 2019 Rogue Corps) 모두 실패하고 2024 Operation Galuga로 2D 회귀. WayForward의 외부 개발 의존이 구조화됨.
- **Topic 2 핵심 결론 — 불변 코어 7가지 (5작품 모두 공유):**
  1. 횡스크롤 2D + 점프 + 이동 중 동시 사격
  2. 1히트 즉사 (체력바 X)
  3. 무기 다변화 — 상황별 최적 무기 명확
  4. 보스 전투 (스테이지당 최소 1개)
  5. 2인 이상 협동
  6. 패턴 학습 가능한 결정론적 적
  7. 기본 무기 안전망 (무한 탄약 보장)
- **my-game 체크리스트 Top 5:**
  1. "어렵지만 공정"은 비협상 — 랜덤 X + 패턴 학습 가능 = "just one more try"
  2. 독보적 비주얼이 인디 마케팅 (Cuphead 600만 장 근거)
  3. 2D 고수 — 3D 전환은 콘트라 시리즈에서만 3번 반복 실패
  4. 협동 필수, 온라인은 선택 (Cuphead 로컬만으로 600만)
  5. 차별화는 1개 메커닉 집중 (Metal Slug 탈것, Broforce 파괴 환경, Gunstar 무기 조합)
- **Cross-links:** [[Run and Gun Genre]], [[Run and Gun Base Systems]], [[Run and Gun Extension Systems]], [[Metal Slug]], [[Gunstar Heroes]], [[Cuphead]], [[Broforce]], [[Arcade Difficulty Design]], [[IP Avoidance For Game Clones]], [[Research Run and Gun Genre]]
- **Open questions:** 슈도-3D 기지 스테이지 미계승 이유 / 코나미 코드의 판매 효과 정량 데이터 / WayForward 반복 외주 패턴 / 2026년 플레이어가 아케이드 1히트 즉사를 동일하게 수용하는가 / 인디 런앤건 + 퍼블리셔 없이 200만 장 사례 존재 여부
- **Constraints:** GiantBomb 403 (Operation Galuga 상세 미확보) / namu.wiki 우회 / Operation Galuga 판매 수치 비공개 / Metal Slug·Gunstar 판매 비공개 정책

## [2026-05-08] q&a | /adopt 엔진 선결 조건 해소

- **트리거:** 사용자 질문 — "/adopt가 [TO BE CONFIGURED] 미완료 CLAUDE.md로도 동작하는가, 엔진 설정이 선결 조건인가?"
- **권위 출처:** 로컬 `.claude/skills/adopt/SKILL.md` (17,863 bytes) 직접 검토
- **Pages created (1):** [[CCGS Adopt SKILL Definition]] — Phase 1-7 분기·갭 등급·5 audit mode·협업 프로토콜 분해 (key_claims 8건, confidence high)
- **Pages updated:** [[Brownfield Project Onboarding]] (Open Questions의 Q1 해소 → Resolved Questions에 key-insight 콜아웃 이동), [[index.md]] Sources +1, [[log.md]] (이 블록), [[hot.md]] (Q&A 결정 로그 +1)
- **Answer:** ❌ **엔진 설정은 선결 조건이 아니다.** `/adopt`는 미설정 상태에서도 작동하며 `[TO BE CONFIGURED]`를 자동 진단·등급화한다. 등급은 조건부:
  - Engine·Language·Rendering·Physics 단독 미설정 → **HIGH** (Phase 2f, "ADR skills fail")
  - 엔진 미설정 + ADR 존재 → **BLOCKING** (Phase 3 명시 케이스, ADR이 엔진 정보 참조)
  - 코드·GDD·ADR 전부 부재 → `/adopt` 거부, `/start`로 라우팅 (Phase 1 fresh 분기)
- **Phase 5 요약 출력에 `Engine: [configured / NOT CONFIGURED]`가 1차 항목으로 명시** — 엔진 상태는 입력 조건이 아닌 *진단 출력*임을 SKILL 정의가 직접 입증.
- **Cross-links:** [[CCGS Adopt Brownfield Example]], [[CCGS Reverse Document Workflow Example]], [[CCGS Framework]]

## [2026-05-08] supplement | Brownfield Onboarding 공식 예제 보완

- **트리거:** 사용자가 Topic 2 보충용 업스트림 공식 예제 2건 제공
- **출처 (2건, 공식 MIT):**
  - https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/docs/examples/session-adopt-brownfield.md
  - https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/docs/examples/reverse-document-workflow-example.md
- **Pages created (2):** [[CCGS Adopt Brownfield Example]] (소스 + 4-Phase 분해), [[CCGS Reverse Document Workflow Example]] (소스 + 4-Stage 분해)
- **Pages updated:**
  - [[Brownfield Project Onboarding]] — **전면 개정**. `/adopt` 4-Phase + 7-Step Migration Plan + 6 핵심 원칙 + 컨텍스트 격리(forked context)로 교체. 신뢰도 medium→high.
  - [[Research CCGS Brownfield Onboarding]] — 상단에 update 콜아웃 추가, 공식 절차 요약 섹션 추가, 기존 추론 본문은 "참고용"으로 명시 + 추론↔공식 차이 비교 표 추가.
  - [[index.md]] (Sources +2), [[log.md]] (이 블록), [[hot.md]] (활성 토픽·Top 페이지·결정 로그·교차참조 밀도 갱신)
- **Key correction:** 초기 진단 "공식 브라운필드 가이드 부재(medium)"는 **틀렸다**. CCGS는 `/adopt` 전용 스킬을 보유하고, 8턴 30분 예제 세션 + `/reverse-document` 4-Stage 워크플로를 공식 docs/examples/에 게시한다. 핵심 식별: `/adopt`는 'Context: fork'로 실행되어 코드베이스 전체 스캔이 메인 세션 토큰을 오염시키지 않으며, "FORMAT audit, not existence audit"(파일 존재가 아닌 *내부 구조* 감사)와 "Migration, not replacement"(기존 콘텐츠 절대 보존, retrofit으로 누락 섹션만 채움)가 두 핵심 원칙.
- **Cross-links:** [[Donchitos CCGS Repo]], [[CCGS Framework]], [[Research CCGS Framework And Local Drift]]
- **Open questions:** `/adopt`가 `[TO BE CONFIGURED]` 미완료 CLAUDE.md로 동작하는지 / forked context 토큰 한도 / `/reverse-document`의 .gd 파싱 정확도 / 50K+ 라인 코드베이스 처리 시간

## [2026-05-08] autoresearch | CCGS Framework + Brownfield + MetalSlugClone Verdict

- **Mode:** sub-agent (sonnet) creates content pages → main agent updates index/log/hot
- **Topics (3):**
  1. Donchitos/Claude-Code-Game-Studios 저장소 분석 + 로컬 my-game 드리프트 확인
  2. CCGS 활용 브라운필드 프로젝트 온보딩 절차 + 후속 리팩터 단계
  3. giacoballoccu/MetalSlugClone(기반) + alfredo1995/metal-slug(레퍼런스) 통합 전략에 대한 의견
- **Pages created (12):**
  - Synthesis (3): [[Research CCGS Framework And Local Drift]], [[Research CCGS Brownfield Onboarding]], [[Opinion MetalSlugClone Base Plus Metal Slug Reference]]
  - Concepts (5): [[CCGS Framework]], [[CCGS Subagent Tier Architecture]], [[Brownfield Project Onboarding]], [[Abstract Base Class Pattern]], [[Boss Two Phase Design]]
  - Entities (3): [[Donchitos CCGS Repo]], [[MetalSlugClone giacoballoccu]], [[metal-slug alfredo1995]]
  - Sources (3): [[GitHub Donchitos Claude Code Game Studios]], [[GitHub giacoballoccu MetalSlugClone]], [[GitHub alfredo1995 metal-slug]]
- **Pages updated:** [[index.md]] (Synthesis +3, Tooling/Framework/Process 신규 섹션, Entities Games +2 / Organizations +1, Sources +3, Tags +5 카테고리), [[log.md]], [[hot.md]]
- **Topic 1 핵심 결론:** 로컬 my-game은 CCGS v1.0.0-beta 업스트림 현행이다. 에이전트 49개·훅 12개·CLAUDE.md 동일, 스킬은 +1(`omc-reference`) — OMC 통합 결과이지 CCGS 드리프트 아님. 단일 기여자(버스 팩터 1) + 완성 게임 사례 0건이 약점. 활발한 초기 유지보수(2026-04-07 v1 이후 5개 패치).
- **Topic 2 핵심 결론:** 공식 브라운필드 가이드는 부재(신뢰도 medium). 추론 절차: Phase 1 내성(`/reverse-document` → 슬롯 채우기 → 에이전트 시드) → Phase 2 Tier 1·2·3 감사 → Phase 3 5단계 리팩터(디렉터리 → 네이밍 → 테스팅 하네스 → ADR 소급 → 코딩 표준). 핵심 함정: 테스트 없이 컨벤션 변경(회귀 탐지 불가), 일괄 변환(롤백 불가), 에이전트 자동 재작성(작동 코드 손상).
- **Topic 3 판정:** ❌ **거부(Rejected).** 두 저장소 모두 Unity 2D / C# 기반 → my-game(Godot 4)과 엔진 불일치. Unity `MonoBehaviour`·`Rigidbody2D`·`Animator` API와 외부 에셋(Fungus 135+ 파일, DOTween, iTween)은 Godot에 직접 대응 없음. 추가로 giacoballoccu는 2021년 이후 비활성·라이선스 없음·Boss2에 2페이즈 분기 없음, alfredo1995도 라이선스 없음·페이즈 전환 연출 없음. 패턴(추상 기반 클래스, 2페이즈 보스)의 *아이디어*는 안전하게 참고 가능하나 Godot 4에서 처음 작성하는 것이 이식 비용보다 빠르다. 대안: [[Abstract Base Class Pattern]] / [[Boss Two Phase Design]] 페이지의 Godot 4 예제 코드 직접 사용.
- **Cross-links:** [[IP Avoidance For Game Clones]], [[Run and Gun Genre]], [[Run and Gun Base Systems]], [[Metal Slug]], [[SNK]], [[Broforce]]
- **Open questions:** CCGS로 출시된 완성 게임 존재 여부(이슈 #34) / Godot 4 GDScript 전용 런앤건 오픈소스 스캐폴드 존재 / `/reverse-document` 스킬의 .gd 파일 파싱 정확도 / Godot 4.5+ `@abstract` 어노테이션 정확한 동작 / `validate-skill-change.sh` 트리거 조건
- **Constraints:** zsh 글로브 충돌(`?recursive=1` 따옴표 처리로 해결) / 두 Metal Slug 저장소 라이선스 파일 부재(소스 페이지에 기록) / CCGS 공식 브라운필드 가이드 없음(추론 절차로 대체)

## [2026-05-08] ingest | Metal Slug IP Avoidance Guide

- **Source:** `.raw/metal-slug-ip-avoidance-guide.md` (hash `d98067bd4644448714f8ab30e2279122`)
- **Summary:** [[Metal Slug IP Avoidance Guide]]
- **Pages created (3):** [[Metal Slug IP Avoidance Guide]] (source), [[IP Avoidance For Game Clones]] (concept), [[Broforce]] (entity)
- **Pages updated:** [[index.md]] (Concepts: Production/IP/Legal 섹션 신설; Entities/Sources/Tags 등록), [[hot.md]], [[log.md]]
- **Key insight:** 게임 메카닉은 미국·한국 공통 저작권 보호 대상이 아니므로 메탈슬러그 8대 시스템(이동·무기·근접·차량·HP·적·스코어·레벨)은 자유 모방 가능. 비주얼·이름·음악만 100% 교체하면 합법적 상업 출시까지 가능하며, [[Broforce]]가 모범 사례다. my-game이 런앤건 노선을 채택할 경우 즉시 적용 가능한 실무 체크리스트 확보.
- **Cross-links:** [[Metal Slug]], [[SNK]], [[Run and Gun Base Systems]], [[Run and Gun Extension Systems]], [[Weapon Letter Pickup System]], [[Cuphead]]
- **Open questions:** SNK 본사 추적 임계점 / 한국 캐릭터 외형 유사도 판단 기준 / AI 생성 자산 책임 귀속 / 메카닉 특허 검색 절차

## [2026-05-08] autoresearch | Metal Slug · Run and Gun Genre

- **Rounds:** 2 (broad search × 7 queries + deep fetches × 4 URLs; gap fill × 4 searches + 4 fetches)
- **Sources found:** 11 search queries, 8 deep fetches; 3 new sources catalogued (Wikipedia Run and Gun, Wikipedia Metal Slug, Megacat Studios retrospective)
- **Pages created:** 14 total (server: sub-agent / index update: main agent)
  - Synthesis (1): [[Research Run and Gun Genre]]
  - Concepts (5): [[Run and Gun Genre]], [[Run and Gun Base Systems]], [[Run and Gun Extension Systems]], [[Weapon Letter Pickup System]], [[Arcade Difficulty Design]]
  - Entities (5): [[Metal Slug]], [[SNK]], [[Contra]], [[Gunstar Heroes]], [[Cuphead]]
  - Sources (3): [[Wikipedia Run and Gun]], [[Wikipedia Metal Slug Series]], [[Megacat Studios Run and Gun History]]
- **Key finding:** 런앤건의 최소 기능 세트는 5가지(이동·점프·동시사격·적패턴·피격결과)이며, 이 코어가 매력적이지 않으면 어떤 확장도 구제할 수 없다. Metal Slug의 차별점은 "근접공격이 총기보다 강하다"는 한 줄의 규칙이 장르 무게중심을 "쏘면서 달리기"에서 "적 속으로 뛰어들기"로 옮긴 것. 3D 전환은 구조적으로 실패했고(2D 평면 최적화 장르), 인디 부활(Cuphead 600만 장)은 "어렵지만 공정 + 무제한 재시도 + 비주얼이 마케팅"의 결합으로 가능했다.
- **Key follow-ups:** 런앤건 모바일 실패의 구조적 원인 / 보스러시가 독립 장르인지 런앤건 하위인지 / 로그라이트 런앤건의 시장 검증 (Huntdown: Overtime 2026 Early Access 결과 추적) / my-game의 3가지 포지셔닝 선택 — 순수 계승 vs 보스러시 vs 로그라이트
- **Constraints:** namu.wiki HTTP 403 (Wikipedia/검색결과로 우회), Treasure 스튜디오 단독 페이지는 Gunstar Heroes에 통합하여 14/15 페이지 사용

## [2026-05-08] autoresearch | Battle Cats Subgenre

- **Rounds:** 2 (broad search × 7 queries + deep fetches × 5 URLs; gap fill × 5 searches + 2 fetches)
- **Sources found:** ~20 candidate URLs; 6 fetched in depth (Wikipedia, Campaign Asia, ANN press release, BlueStacks guide, GachaZone guide, Mechanics of Magic analysis)
- **Pages created:** 13 total
  - Synthesis (1): [[Research Battle Cats Subgenre]]
  - Concepts (4): [[Side Scrolling Tug Of War Defense]], [[Auto Deploy Unit System]], [[Gacha Unit Acquisition]], [[Long Tail Mobile Live Service]]
  - Entities (4): [[Battle Cats]], [[PONOS]], [[Cartoon Wars]], [[Grow Castle]]
  - Sources (3): [[Wikipedia The Battle Cats]], [[Campaign Asia Battle Cats Recovery]], [[Battle Cats 100M Downloads ANN]]
- **Key finding:** Battle Cats는 PvZ형 "그리드 레인 디펜스"가 아닌 "단일 레인 사이드스크롤링 터그오브워 디펜스"의 별도 서브장르다. 상업적으로 $700M/1억 DL/13년 라이브서비스를 달성한 핵심은 ① 탭 기반 단순 입력 + 안티 특성 전략 깊이의 조합, ② PvE 중심 가챠로 P2W 없는 컬렉션 동기 구축, ③ IP 콜라보 + 이벤트 캘린더 기반 라이브서비스 운영이다.
- **Key follow-ups:** 단일 레인 + 복수 레인 하이브리드 변종의 상업 사례 탐색; Battle Cats 복잡성 인플레이션의 신규 유저 진입장벽 데이터; 가챠 규제 강화 시장(한국/유럽)에서의 대안 수익모델 사례

## [2026-05-08] autoresearch | 라인 디펜스 게임 시스템

- **Rounds:** 2 (broad search + gap fill)
- **Sources found:** ~15 candidate URLs across web search; 3 fetched in depth
- **Pages created:** 13 total
  - Synthesis: [[Research Lane Defense Game Systems]]
  - Concepts (7): [[Lane Defense]], [[Grid Placement System]], [[Wave Pacing]], [[Resource Economy Tower Defense]], [[Upgrade Path System]], [[Meta Progression]], [[Merge Dice Mechanic]]
  - Entities (4): [[Plants vs Zombies]], [[Random Dice]], [[Bloons TD]], [[George Fan]]
  - Sources (3): [[Wikipedia Plants vs Zombies]], [[Game Developer Tower Defense Rules]], [[Tower Defense Design Guide]]
- **Synthesis:** [[Research Lane Defense Game Systems]]
- **Key finding:** 라인디펜스는 PvZ가 정의한 "5–6레인 + 그리드 셀 + 두 통화 + 환경 다변화" 4종 골격이 핵심이며, Random Dice는 머지 메커닉으로 배치 결정을 대체한 가장 성공적인 변종이다.
- **Key follow-ups:** Part 2 of Game Developer's TD Rules article; primary George Fan interviews; deeper numerical tuning data for PvZ economy; circular-path defense ("circuit defense") classification.
