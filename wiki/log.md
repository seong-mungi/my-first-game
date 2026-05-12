---
title: Wiki Log
updated: 2026-05-10
---

# Wiki Log

Reverse chronological log of wiki operations. Newest at top.

## [2026-05-12] autoresearch | CCGS fork 생태계 — Star 순 Top 10

- **Mode:** autoresearch · GitHub API 직접 조회 · 3 페이지 생성
- **Topic:** CCGS fork 버전 중 star가 많은 순으로 10개 리서치
- **Method:** `GET /repos/Donchitos/Claude-Code-Game-Studios/forks?sort=stargazers&per_page=10` (high confidence)
- **Pages created (3):**
  - Synthesis: [[Research CCGS Fork Landscape]] — 원본(⭐18,359/🍴2,679) + Top 10 fork 테이블 + 3패턴 분류
  - Concept: [[CCGS Chinese Localization Forks]] — CN 현지화 3종 (⭐9/⭐4/⭐3)
  - Concept: [[CCGS Codex Port Pattern]] — Codex 포팅 2종 (⭐3/⭐2) + AGENTS.md 어댑터 구조
- **Key insights:**
  - 1위 fork(toukanno ⭐50)는 원본(⭐18,359)의 **0.27%** — fork star는 극소.
  - 2,679개 fork 중 named/star 보유 fork는 극소수. 나머지는 비공개 개인 사본.
  - 버전 식별자: "48 agents 36 skills" = 구버전(2026-03 이전), "49 agents 72 skills" = 현재 업스트림.
  - 3대 패턴: CN 현지화(3개) · Codex 포팅(2개) · 기능 확장 Technica(1개).
  - FreedomPortal/ccgs-technica-edition: ⭐2 — 실제 기능 분화 fork 중 유일 (퍼블리싱 워크플로).

## [2026-05-12] autoresearch | CCGS scaffolder 갭 — 구현 툴체인

- **Mode:** autoresearch · 2 parallel agents · ~25 web searches · 9 페이지 생성
- **Topic:** CCGS가 scaffolder만 제공한다면 구현까지의 나머지 부분에 필요한 프레임워크와 툴
- **Sources:** GitHub README (primary), Godot Asset Library, GitHub repos, 인디 dev 블로그, 공식 문서
- **Pages created (9):**
  - Synthesis: [[Research CCGS Implementation Gap Full Stack]] — CCGS 갭 전체 매트릭스 (아트/오디오/CI/애널리틱스/퍼블리싱/커뮤니티)
  - Synthesis: [[Research Godot 4.6 Ecosystem Toolchain]] — Godot 에코시스템 빠른 참조 테이블
  - Concept: [[CCGS Scaffolder Scope Boundary]] — IN/OUT SCOPE 경계 명확화
  - Concept: [[Godot CI CD Pipeline Pattern]] — 두 단계 패턴 (import warm-up → test), GODOT_DISABLE_LEAK_CHECKS
  - Concept: [[Godot Analytics Stack]] — Talo (개발 중) + GameAnalytics (론치 후) + Amplitude
  - Concept: [[Godot Audio Middleware Decision]] — FMOD(856⭐) vs Wwise(407⭐) vs 내장 결정 트리 + Echo 시간 되감기 특이점
  - Concept: [[Godot Art Pipeline Tools]] — Aseprite + godot-4-aseprite-importers (2026-05-07 활성) + Steam 2026 AI 공개 규정
  - Concept: [[Indie Game Publishing Pipeline]] — Steamworks SDK + SteamCMD + itch.io + Steam 2026 AI 의무
  - Concept: [[Indie Game Community Platform Stack]] — Discord(즉시) → Steam 허브(론치) → Reddit/itch.io(확장)
- **Key insights:**
  - CCGS는 프로세스·조정 레이어만 제공. 실제 구현 툴 6개 레이어 전부 외부.
  - CCGS Technica Edition fork가 이 갭을 커뮤니티가 인식한 증거 (2026).
  - Godot CI: two-step 패턴(import warm-up 필수) 모르면 false failure 반복.
  - 아트: Aseprite + godot-4-aseprite-importers가 정석 (낮은 복잡도, 활발히 유지).
  - 오디오: Echo 초기엔 내장으로 시작; FMOD는 시간 되감기 오디오 복잡도 결정 시 전환.
  - 애널리틱스: Talo(개발 중 Godot 네이티브) + GameAnalytics(론치 후) 이분화 권고.

## [2026-05-12] save | CCGS Context Bloat Remediation

- **Mode:** main agent · /save · 1 concept 페이지
- **Pages created (1):**
  - Concept: [[CCGS Context Bloat Remediation]] — CCGS 프로젝트의 GDD 비대화 구조적 문제 진단/처방. Echo 실측 (systems-index.md 52 KB) 기반, 5 원인 분석 (Status 컬럼 narrative / "Last Updated" 헤더 / GDD 본체 inline / CLAUDE.md auto-import / review-log 중복) + 5 황금률 + Tier 1-4 처방. CCGS upstream 기여 권고 4항 포함.
- **Key insights captured:**
  - **본질적 원인**: 활성 데이터(현재 상태)와 이력 데이터(과거 결정 narrative)가 같은 파일에 섞임. 매 review session이 systems-index Status 컬럼에 narrative append → 영구 누적.
  - **Echo 실측**: systems-index.md 52 KB · player-movement.md 1,893 줄 · 4 GDD 1,000줄+. 같은 정보가 review-log + systems-index 2× 중복.
  - **Tier 1 즉시 액션**: Status 컬럼 truncate (~30 KB 절감) + "Last Updated" 헤더 정리 (~20 KB) + CLAUDE.md 임포트 점검 → systems-index.md 52 KB → 5-7 KB (90% 절감).
  - **Tier 2 워크플로**: design-docs.md 룰에 "Status enum + 날짜 + log path만 허용" 추가. /design-review + /review-all-gdds 스킬에 auto-compact 의무 추가. Next Steps 갱신 책임자 부여 (현재 /map-systems만 작성, 갱신 책임자 없음 → stale).
  - **Tier 3 인프라**: 계층적 CLAUDE.md (design/CLAUDE.md, design/gdd/CLAUDE.md), systems-index 분할, frontmatter 표준화 → dashboard 자동 생성.
  - **5 황금률**: ① 활성/이력 분리 ② Status는 enum, narrative는 link ③ auto-import에 가변 데이터 X ④ 계층적 CLAUDE.md ⑤ Auto-compact가 default.
  - **CCGS upstream 기여 권고**: 비대화는 Echo 한정 X — CCGS 프레임워크 자체의 디자인 갭. 4항 upstream 패치 권고 (design-docs 룰 / 스킬 narrative compaction / systems-index 템플릿 / design/gdd/CLAUDE.md 템플릿).
- **Pages updated (meta):** [[index.md]] (Tooling/Framework +1), [[log.md]] (이 블록), [[hot.md]] (Recent Decisions + Cross-Ref Density)
- **Source conversation**: 사용자가 "CCGS로 게임 제작 시 design-system 파일이 비대해지고 세션 시작 컨텍스트 증가 문제" 호소 → 진단/처방 답변 생성 → 사용자가 wiki 저장 요청.

## [2026-05-11] autoresearch | 런앤건 8방향 조준 사용성 (gamepad + KB+M + 접근성)

- **Mode:** main agent · 4 parallel research agents · 3 rounds (combined) · 33 web searches · 6 pages
- **Topic:** 런앤건 게임 8방향 조준 사용성 시스템 — 게임패드 + 키보드+마우스 + 접근성
- **Pages created (6):**
  - Synthesis: [[Research 8-Way Aim Usability For Run-and-Gun]] — 마스터 통합 페이지, 게임패드/KB+M/접근성 3축 + Echo action items
  - Concept: [[Aim Lock Modifier Pattern]] — Lock-then-aim 모던 컨벤션 (Cuphead/Galuga/Hard Corps 비교) + 발견성 문제 + 안티 패턴
  - Concept: [[Analog Stick To 8-Way Quantization]] — 4단계 파이프라인 (radial deadzone → Schmitt → sector → hysteresis) + Steam Deck floor + Echo 디폴트
  - Concept: [[Aim Assist Accessibility Tiers]] — Returnal 4-tier + XAG 107 의무 + 어시스트 ↔ 난이도 직교 + 시간 메커닉 통합
  - Source: [[Game Developer Thumbstick Deadzones]] — Josh Sutphin 2014 산업 canonical (axial 거부, radial 표준, scaled radial 정밀)
  - Source: [[XAG 107 Aim Assist Guidelines]] — Microsoft Xbox 접근성 가이드 #107 권위
- **Key findings:**
  - **게임패드 — Lock-then-aim 컨벤션 수렴**: Cuphead RB / Hard Corps L+R / Galuga ZR 모두 같은 패밀리. Echo `aim_lock=RB` on-pattern.
  - **양자화 4단계 표준**: scaled radial deadzone + 마그니튜드 Schmitt (0.20/0.15) + sector snap-to-8 + 각도 hysteresis (±4°) + commitment timer (2-3 frame).
  - **Steam Deck 드리프트 floor ~0.18** — Echo `FACING_THRESHOLD_AIM_LOCK = 0.10`은 LCD 1세대에서 마진 부족. **0.15로 상향 권장**.
  - **KB+M — 마우스 360° vs WASD 8방향은 *장르가 결정***: top-down twin-stick (Hotline/Gungeon/Throne)은 마우스 360°. Side-scroll run-and-gun (Cuphead/Galuga PC)은 WASD 8방향 + lock 수정자.
  - **`aim_lock` KB+M 산업 표준 없음**. Cuphead=C, Galuga=리바인드 미공개. Echo `aim_lock=F`는 방어 가능 (Shift/RMB/Q-E 회피 근거 강함).
  - **Returnal 4-tier 어시스트가 모던 표준** (Off/Low/Medium/High). 디폴트 Medium은 일반 게임 권장, **Echo는 1-hit + rewind 메카닉 → Off 디폴트 권장**.
  - **XAG 107 의무**: single-stick + auto-fire + 4-tier 어시스트 + ±50% 감도 + 난이도 ↔ 어시스트 직교. Echo Tier 1 게이트.
  - **Game Accessibility Guidelines**: 어시스트 ON 시 업적 게이트 X (Celeste 모델 gold standard).
- **Echo Action Items (입력 #1 GDD 갱신 후보):**
  1. `FACING_THRESHOLD_AIM_LOCK 0.10 → 0.15` (Steam Deck 드리프트 floor 회피)
  2. 각도 hysteresis ±4° 추가 (45° 경계 떨림 방지)
  3. 2-3 프레임 sector commitment timer 추가
  4. KB+M `aim_lock=F` 유지 + 근거 강화 (Shift 대시 충돌, RMB 장르-wrong, Q/E 무기 스왑 충돌)
  5. Gamepad `aim_lock=RB` 유지 (Cuphead/Galuga 컨벤션)
  6. Aim assist 4-tier 디폴트 Off + XAG 107 준수 (single-stick + auto-fire + ±50% sensitivity)
- **Open questions filed:** Metal Slug 베이스 무기 4-way vs 8-way 1차 검증 / Cuphead 대각선 발견 시간 데이터 / Echo 마우스 360° aim 옵션 제공 여부 / Single-stick 모드 auto-fire 발사 조건 / 어시스트 ON speedrun 별도 카테고리.
- **Constraints**: 4 agent 병렬 + program.md 15 페이지 한도 안에서 6 페이지 작성 (synthesis 1 + concept 3 + source 2). Round 3 신짐 패스 불필요 — Round 2에서 갭 충분 해소. High credibility 출처 우선 (Microsoft Learn / Game Developer / Unity docs / Valve 1차).
- **Pages updated (meta):** [[index.md]] (Synthesis +1, Tooling/Framework +3, Sources +2), [[log.md]] (이 블록), [[hot.md]] (Active Topic + Top Pages 갱신)

## [2026-05-10] save | Bot Validation Catalog Summary (14 페이지 단일 진입점)

- **Mode:** main agent · /save · 1 synthesis 페이지 (메타 인덱스)
- **Pages created (1):**
  - Synthesis: [[Bot Validation Catalog Summary]] — 14 페이지 카탈로그 통합 진입점. Tier 0-3 구조 (WHY/WHAT/HOW/GAP/SIGNATURE/FRONTIER), 5 황금률, 솔로 개발자 로드맵 (Week 1 / Month 1 / Month 2-3 / Tier 3), Echo 비협상 결정 8종, 진입점 가이드 (처음 / 구현 / 디자인 / 출시).
- **Key insights captured:**
  - **카탈로그 핵심 명제**: Echo의 결정론은 봇 검증을 자동화 가능하게 만드는 자산. 봇은 게이트(약속), 인간은 등급(재미). 14 페이지가 이 한 명제의 펼침.
  - **5 황금률**: ① 결정론 절대 ② AI는 도구/거울 (변형 X) ③ 봇=게이트, 인간=등급 ④ 잡몹 ≠ 보스 ⑤ 9프레임 비협상.
  - **카탈로그 도출 비협상 결정 8종**: 회피 윈도우 ≥ 9f, 보스 RNG 0, 잡몹 되감기 없이 클리어, 시그니처 보스 디자이너 직접, Easy 토큰 무한 + 텔레그래프 1.5×, RL ghost 출시 동봉, 결정론 CI blocking, GDD 8.2 YAML 의무.
  - **진입점 분기**: 처음 (WHY → WHAT → HOW 통합) / 구현 (template → pipeline → determinism) / 디자인 결정 (reconciliation → lag → reward) / 출시 (accessibility → speedrun → ghost).
  - **카탈로그 외부 의존**: Solo Contra 2026 Concept, Time Manipulation Run and Gun, Modern Difficulty Accessibility, Boss Two Phase Design, Contra Per Entry Mechanic Matrix — 5 외부 페이지가 카탈로그의 디자인 근거.
- **Pages updated (meta):** [[index.md]] (Tooling/Framework +1 — total +15 누적), [[log.md]] (이 블록), [[hot.md]] (skip — 카탈로그 인덱스라 별도 active topic 갱신 X)
- **Source conversation**: Tier 3 페이지 작성 후 사용자가 "query: Tier 0~3 정리" 요청 → 카탈로그 횡단 요약 답변 생성 → 사용자가 그 답변을 wiki에 저장 요청.
- **Cumulative**: 이번 세션 총 15 페이지 (Tier 1 9 + Tier 2 2 + Tier 3 3 + Catalog Summary 1). **봇 검증 카탈로그 단일 진입점 closure 완성**.

## [2026-05-10] save | Tier 3 Pages (AI 패턴 생성 + 접근성 모드 + Speedrun 발견)

- **Mode:** main agent · /save (3 신규 페이지) · 한글 바디 + 영문 제목 (프로젝트 관습)
- **Pages created (3):**
  - Concept: [[AI Assisted Boss Pattern Generation]] — Tier 3 콘텐츠 양 폭발 도구. 3 생성 메소드 (LLM / 절차 룰 / RL-discovered) + hard constraints 6종 (9f 회피 윈도우, 결정론, 2D, 누적 페이즈, 텔레그래프, 되감기 강제) + soft constraints + LLM 프롬프트 템플릿 + 자동 필터 → 봇 검증 → 디자이너 큐레이션 워크플로.
  - Concept: [[Accessibility Mode Bot Validation]] — Easy/Hard/Color-blind/Auto-Jump/Slow-Motion 모드별 봇 검증. 모드별 lag 매핑 (Easy=15f, Normal=9f, Hard=6f), Modes Comparison Matrix 자동 생성, 회귀 검출. Color-blind 자연 검증 (봇이 색상 무시 = 색맹 플레이어 가능 동치).
  - Concept: [[Speedrun Discovery Via RL Bot]] — RL 봇 시간 페널티 보상 (-0.05/frame + 빠른 클리어 보너스) + 발견 분류 (Optimal Strategy / Edge Case / Unintended Glitch) + 글리치 결정 매트릭스 + 인간 도달성 검증 + Echo speedrun 인프라 (replay sharing, leaderboard, glitch documentation, ghost sharing) + Trackmania 모델 적용.
- **Key insights captured:**
  - **AI 패턴 생성 — 적용 영역**: 시그니처 보스(첫/최종)는 디자이너 직접 작성 유지. AI 보조는 잡몹 + 부 보스 + Hard Mode 변종에만. 디자인 정체성 보존이 ROI보다 우선.
  - **AI 패턴 생성 워크플로**: GDD 작성 → AI 50-100 후보 → hard constraint 자동 필터 (50% drop) → random+scripted 봇 패스 → heuristic 시뮬 → 디자이너 top 10-15 수동 리뷰 → 채택/거부.
  - **접근성 봇 핵심 통찰**: Easy 모드 봇은 *더 큰 lag* (15f) 사용. "Easy가 정말 쉬운지" 검증하려면 *덜 능숙한 플레이어* 시뮬 필수. Color-blind는 자연 검증 — 봇이 색상 의미 안 갖고 동작하므로 봇 패스 = 색맹 플레이어 가능.
  - **Modes Comparison Matrix**: 6 모드 × 4 보스 자동 매트릭스. Easy 컬럼 ≥ 80%, Hard < 30%, Color-blind는 Normal과 ±5pp 안. 회귀 자동 검출.
  - **Speedrun 결정 룰**: RL 발견 트릭을 4 분류로 — (인간 도달 O + Speedrun valid) 받아들임 + 카테고리 분리; (인간 도달 X + Game-breaking) 수정; (인간 도달 O + 트리비얼화) 수정; (인간 도달 X + 트리비얼화) 수정.
  - **Trackmania 모델 적용**: 출시 시 RL 봇 ghost 동봉 ("AI 21초 — 너는?"). 30일 후 인간 WR가 RL 시간 갱신. 이게 의도된 long-tail 진행. 솔로 인디 출시에 무료 long-tail 마케팅 동력.
  - **Echo Speedrun 인프라 4단**: `.replay` 업로드/다운로드 (결정론 검증 인프라 재사용), Steam Leaderboards (카테고리: Any%/Glitchless/No-Rewind/Boss-Rush), 글리치 카탈로그 (커뮤니티 자율 분화), WR Ghost 다운로드 (Trackmania 모델).
- **Pages updated (meta):** [[index.md]] (Tooling/Framework +3 — total +14 누적), [[log.md]] (이 블록), [[hot.md]] (Active Topic 갱신 + Top Pages 14 페이지 + Recent Decisions + Cross-Ref Density)
- **Source conversation**: Tier 3 갭 (6) AI 패턴 생성 + (7) 접근성 봇 + (8) Speedrun 발견 → 3 페이지 일괄 작성.
- **Cumulative**: 이번 세션 총 14 페이지 (Tier 1 9 + Tier 2 2 + Tier 3 3). **봇 검증 + Echo 시그니처 강화 + 솔로 인디 long-tail 카탈로그 closure 완성**.

## [2026-05-10] save | Tier 2 Pages (고스트 리플레이 + 비-보스 봇 스위트)

- **Mode:** main agent · /save (2 신규 페이지) · 한글 바디 + 영문 제목 (프로젝트 관습)
- **Pages created (2):**
  - Concept: [[Ghost Replay System For Time Rewind]] — Echo 시그니처 확장. 3 고스트 소스 (Personal Best / Dev Gold / Asynchronous Phantom), 시간 되감기 상호작용 3 옵션 (synced / independent / toggle), 콜라주 시각 처리 (시안 톤, alpha 0.45, motion trail), Hybrid 데이터 포맷 (input log + 5초 keyframe), Tier 1-3 매핑.
  - Concept: [[Non-Boss Bot Validation Suites]] — 4 봇 스위트 (movement_v1 / mob_wave_v1 / weapon_v1 / cross_system_v1). Movement = 점프 그리드 + rewind torture, Mob Wave = 잡몹은 되감기 없이 클리어 가능 룰, Weapon = DPS 매트릭스 자동 생성 + 무기-vs-적 매트릭스, Cross-System = 점프 중 사격 + 페이즈 transition.
- **Key insights captured:**
  - **Ghost Replay 핵심**: Echo의 결정론 + 상태 스냅샷 + 9프레임 되감기 인프라가 고스트 시스템을 사실상 무비용으로 뒷받침. "내 몸이 기억한다" 시그니처를 학습 도구에서 몰입 도구로 한 단계 더 밀어붙임.
  - **Time-Rewind 동기화 결정**: 옵션 1 (synced) 디폴트 + 옵션 2 (independent) 토글. synced가 신체 기억 시그니처 정합, independent는 speedrun 벤치마크용.
  - **시각 처리 룰**: 고스트는 항상 플레이어 본체 *아래* 레이어, 보스/탄막은 항상 *위*. 컬러 분리 (고스트 = 시안, 본체 = 마젠타 가능) → 가시성 절대 보존.
  - **Non-Boss ROI**: 무기/무브먼트는 보스보다 변경 빈도 5-10×. 비-보스 봇 스위트 1주 ROI = 보스 봇 1개월 ROI에 견줌.
  - **잡몹 비협상 룰**: 잡몹은 되감기 없이 클리어 가능해야 함 (`heuristic_no_rewind_clear_rate ≥ 50%` 봇 메트릭으로 자동 강제). 되감기는 보스 시그니처 — 잡몹 강제 시 토큰 인플레이션 + 메카닉 마모.
  - **무기 매트릭스 자동 생성**: 휴리스틱 봇이 각 무기로 같은 보스 클리어 시도 → 무기-vs-적 매트릭스. dominant strategy / dominated weapon 자동 발견 → 디자이너 결정 매핑.
  - **RL은 비-보스에 과잉**: scripted + heuristic으로 충분. RL은 Tier 3 only.
- **Pages updated (meta):** [[index.md]] (Tooling/Framework +2 — total +11 누적), [[log.md]] (이 블록), [[hot.md]] (Top Pages + Cross-Ref Density 갱신)
- **Source conversation**: Tier 2 갭 (4) Ghost Replay + (5) Non-Boss Bot Suites → 2 페이지 일괄 작성.
- **Cumulative**: 이번 세션 총 11 페이지 (Tier 1 9 + Tier 2 2). 봇 검증 + Echo 시그니처 확장 카탈로그 closure.

## [2026-05-10] save | Tier 1 Gap Coverage (인간 통합 + 결정론 검증 + 데스 히트맵) + 9페이지 한글화

- **Mode:** main agent · /save (3 신규 페이지) + 9 페이지 한글 변환 (제목 영문 유지, 바디 한글)
- **Pages created (3):**
  - Concept: [[Bot Human Validation Reconciliation]] — 봇 verdict ↔ 인간 플레이테스트 화해. 4사분면 매트릭스 (✅ Ship / ⚠️ Hidden Defect / 🔧 Bot Weak / ❌ Design Failure), Echo 표준 설문지 10문항, override 룰 양방향, 화해 리포트 템플릿.
  - Concept: [[Determinism Verification Replay Diff]] — 결정론 자동 검증. Replay 파일 포맷 + canonical state hashing + Godot 4.6 footgun 카탈로그 10종 + bisect 도구 + 시간 되감기 torture (Echo 시그니처) + cross-platform/cross-version 테스트 스위트.
  - Concept: [[Death Heatmap Analytics]] — 사망 분석 시각화. 3 뷰 (spatial / temporal / pattern attribution) + DBSCAN 클러스터 자동 검출 + 안전지대 검출 (역문제) + 빌드 비교 회귀 검출기 + 봇/인간 텔레메트리 공유 스키마.
- **Pages translated (9, 영문 → 한글, 제목 유지):**
  - [[Deterministic Game AI Patterns]] · [[AI Playtest Bot For Boss Validation]] · [[Bot Validation Pipeline Architecture]]
  - [[Heuristic Bot Reaction Lag Simulation]] · [[GDD Bot Acceptance Criteria Template]] · [[RL Reward Shaping For Deterministic Boss]]
  - [[Bot Human Validation Reconciliation]] · [[Determinism Verification Replay Diff]] · [[Death Heatmap Analytics]]
- **Key insights captured:**
  - **Reconciliation 핵심**: 봇 PASS / 인간 FAIL = 봇이 못 보는 것 (시각 명료성, 인지 부하, 오디오, 좌절). 봇 FAIL / 인간 PASS = 봇 모델이 인간보다 약함 (lag 너무 큼). 화해 리포트가 모든 criterion을 4사분면에 배치하고 액션 매핑.
  - **Override 룰 양방향**: 봇 PASS여도 clear satisfaction < 3.5 / "unfair" 3+ / 텔레그래프 < 4 시 출시 X. 인간 PASS여도 Random > 1% / Scripted < 100% / Pattern-w/o-rewind P3 > 0 시 출시 X.
  - **결정론 검증 핵심**: 같은 입력 시퀀스 2번 실행 → 프레임별 state hash diff. 첫 발산 프레임 = 버그 위치. CI에서 100 seed × 2 run. Float은 1ms 양자화 후 해싱 (1-bit 드리프트 false positive 방지). Time-rewind torture는 라이브 타임라인과 스냅샷/복원 path를 분리 검증.
  - **Godot 4.6 footgun 10종**: 시드 안 박은 RNG, `OS.get_ticks_msec`, `_process` 게임 로직, Dictionary 순회, 시그널 순서, Node init 순서, 물리 적분기, system time, threaded state mutation, shader pixel readback.
  - **히트맵 3 뷰 직교**: spatial = "어디서", temporal = "언제", attribution = "어느 패턴". DBSCAN으로 자동 클러스터, 안전지대 검출은 presence > 0 ∩ death == 0 영역 flood fill. 빌드 diff (RdBu colormap)으로 회귀 검출.
  - **봇/인간 통합 히트맵**: 같은 schema → 같은 파이프라인. 인간 클러스터 있는데 봇 없음 = 봇 모델 누락. 봇 클러스터 있는데 인간 없음 = 봇이 인간보다 약함. 양쪽 클러스터 = 진짜 결함.
  - **한글화 정책**: 제목 영문 (PascalCase 프로젝트 관습 유지), 바디 한글 (프로즈), 코드/YAML/표 영문 키워드 유지, wikilink 영문, section header 영문 (## Architecture, ## Open Questions 등 프로젝트 관습).
- **Pages updated (meta):** [[index.md]] (Tooling/Framework +3 — total +6 over both saves), [[log.md]] (이 블록), [[hot.md]] (Active Topic + Top Pages + Recent Decisions 갱신)
- **Source conversation**: Tier 1 갭 식별 (인간 통합 / 결정론 검증 / 히트맵) → 3 페이지 작성 → 사용자 한글화 요청 → 9 페이지 일괄 변환.
- **Cumulative**: 이번 세션 총 9 페이지 (이전 6 + 이번 3). 봇 검증 풀스택 카탈로그 closure 도달.

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
