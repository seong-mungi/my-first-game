---
title: Wiki Log
updated: 2026-05-08
---

# Wiki Log

Reverse chronological log of wiki operations. Newest at top.

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
