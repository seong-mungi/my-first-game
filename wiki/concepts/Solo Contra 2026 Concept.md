---
type: concept
title: Solo Contra 2026 Concept
created: 2026-05-08
updated: 2026-05-08
tags:
  - my-game
  - run-and-gun
  - solo-dev
  - design-baseline
  - contra-inspired
  - near-future-sf
  - collage
  - time-rewind
related:
  - "[[Run and Gun Success Pattern Matrix]]"
  - "[[Run and Gun Base Systems]]"
  - "[[Modern Difficulty Accessibility]]"
  - "[[Indie Self Publishing Run and Gun]]"
  - "[[Katana Zero]]"
  - "[[Contra Weapon System]]"
  - "[[Cooperative Run and Gun Design]]"
  - "[[Followup Modern Acceptance And Indie RnG Threshold]]"
  - "[[IP Avoidance For Game Clones]]"
sources:
  - "[[Research Run and Gun Success Patterns]]"
  - "[[Research Contra System Analysis]]"
confidence: medium
status: design-baseline-v0
---

# Solo Contra 2026 Concept

## 한 줄 요약

**솔로 개발자가 콘트라의 코어를 가까운 미래 SF + 시간 되감기 + 콜라주 비주얼로 재해석하는 횡스크롤 런앤건.** [[Run and Gun Success Pattern Matrix]]의 7코어 + Q4/Q5 결론을 솔로 제약으로 통과시킨 결과.

## 사용자 결정 (2026-05-08)

| 축 | 선택 |
|---|---|
| 차별화 메커닉 1개 | **시간 되감기** (Katana Zero × Contra) |
| 비주얼 시그니처 | **콜라주** (잡지 컷아웃 · 믹스드 미디어) |
| 무대 | **가까운 미래 SF** (2030-2040) |

## 7코어 적용 매트릭스

| 코어 | 선택 | 비고 |
|---|---|---|
| 횡스크롤 2D | ✅ 유지 | 솔로 친화 + 3D 전환 금지 ([[Run and Gun Success Pattern Matrix]]) |
| 1히트 즉사 | ✅ 유지 | 즉시 재시작(<1초) + Easy 토글 1개 ([[Modern Difficulty Accessibility]]) |
| 무기 다변화 | ✅ 4-5개로 축소 | M/F/L 베이스에 SF 재해석 |
| 보스 전투 | ✅ 5-6개 한정 | 솔로 작업량 통제 (Cuphead 19개보다 적게) |
| 2인+ 협동 | ❌ **제외** | 솔로 QA 비현실적 ([[Cooperative Run and Gun Design]]) — Katana Zero·Hotline Miami로 솔로용 성공 검증 |
| 결정론적 적 | ✅ 유지 | 시간 되감기와 결정론은 시너지 |
| 기본 무기 안전망 | ✅ 유지 | 무기 픽업 사망 시 베이스 |

## 차별화 메커닉: 시간 되감기

**규칙 v0 (튜닝 대상)**:
- 사망 시 자동으로 1.0-1.5초 전 시점으로 되감김 (한 번/인카운터)
- 토큰 형태 — 보스 처치/체크포인트 통과 시 충전
- 무한 사용 X — 결정론 패턴 학습을 우회 못 하게
- Easy 토글: 토큰 무한, Hard: 토큰 0

**근거**:
- Q4 "공정한 1히트" 결론을 *메커닉으로* 해결 — 처벌이 아닌 학습 기회로 재구성
- [[Katana Zero]] 시간 메커닉 + 1히트 즉사 조합이 50만 장으로 검증
- 결정론 패턴과 충돌 없음 — 패턴 학습은 그대로, 1회 실수만 회수

> [!gap] 결정 필요
> - 되감기 시 적·탄환도 같이 되감는가 (Braid 모델) vs 플레이어만 (체크포인트 모델)?
> - UI: 토큰 잔량 표시 위치, 되감기 발동 시 화면 셰이더(시각적 신호)
> - 보스전 vs 스테이지에서 작동 방식 차이? (보스만 토큰 차감 가능?)

## 비주얼 시그니처: 콜라주

**참조 톤 (구별)**:
- Pizza Tower의 Y2K 카툰 = 통일된 손드로잉
- Cuphead의 1930s = 풀 셀 애니메이션
- **본 작품 = 사진 텍스처 + 컷아웃 + 손드로잉 라인 혼합** (몬티 파이튼 애니메이션의 SF 버전)

**솔로 친화 이유**:
- 손드로잉 풀 애니메이션(Cuphead급) = 솔로 불가능
- 콜라주는 *기존 텍스처 합성* — 픽셀·풀 셀보다 작업량↓
- 시그니처 효과 강력 — Cut the Rope, Patapon처럼 즉시 인식 가능

> [!gap] 톤 결정 필요
> - 다크/디스토피아 (Blade Runner 진지) vs 풍자/펑크 (Bioshock × Monty Python 풍)?
> - 캐릭터 사진 출처 — 스톡 / 직접 촬영 / 생성형 AI? (라이선스 + IP 회피 [[IP Avoidance For Game Clones]])

## 무대: 가까운 미래 SF (2030-2040)

**원작과의 거리두기** ([[IP Avoidance For Game Clones]]):
- 콘트라 원작 = 1980s 정글 + 외계인 → 직접 베끼면 IP 위험
- 본 작품 = **메가시티 + 부패한 기업 군대 + 자율 드론**. 외계인 X, 정글 X
- 메카닉 자유 모방, 비주얼·이름·세계관 100% 오리지널

**스테이지 후보 (5개 v0)**:
1. 메가시티 옥상 — 드론 떼와의 추격
2. 부패한 데이터센터 — 자율 경비로봇 + 시간 되감기 첫 등장
3. 지하 마그레브 라인 — 빠른 스크롤 + 무기 픽업 다수
4. 기업 본사 옥상 — 보스러시 직전 셋피스
5. 궤도 엘리베이터 진입 — 최종 보스

> [!gap] 톤 결정 필요
> - 정치성 강도 — Bioshock급 사회 비평 vs 가벼운 펄프 액션?
> - 기술 수준 — 사이버펑크 풀 옵션 vs 절제된 근미래(2030)?

## 작업량 추정 (12-18개월 솔로)

| 항목 | 솔로 시간 |
|---|---|
| 메인 캐릭터 1명 (12 애니메이션) | 4주 |
| 적 8-10종 (각 5 애니메이션) | 8주 |
| 보스 5-6개 (각 2-3 페이즈) | 16주 |
| 스테이지 5개 (각 5분 클리어) | 12주 |
| 시간 되감기 시스템 (코드) | 6주 |
| 무기 4-5종 (비주얼/사운드/밸런스) | 4주 |
| 사운드 (음악 6-8 + SFX) | 8주 |
| 메뉴/UI/접근성 (Easy 토글 포함) | 4주 |
| QA·튜닝 | 8주 |
| **총합** | **~70주 ≈ 16개월** |

→ 일정 압박 시 보스 4개 + 스테이지 4개로 축소.

## 매출 기대치

[[Indie Self Publishing Run and Gun]] 결론:
- 마케팅 파트너 없으면 **10-20만 장**이 천장
- 50만+는 시그니처 비주얼(콜라주가 강점) + 인디 페스티벌 + 인플루언서 캠페인 *동시* 필요
- 0-퍼블리셔 200만 장 사례는 런앤건 장르에 미존재 — 현실 목표 10-20만

## 다음 단계 (의사결정 트리)

1. **시간 되감기 v0 프로토타입** (1주) — Godot 4에서 시간 되감기 단독 검증. 재미 없으면 차별화 메커닉 변경.
2. **콜라주 비주얼 컨셉아트 1장** (3-5일) — 톤 확정. 사용자 피드백 후 톤 락인.
3. **스테이지 1 수직 슬라이스** (4주) — 1 캐릭터 + 시간 되감기 + 콜라주 배경 + 적 3종. 핵심 재미 검증.
4. 위 3개 통과 시에만 풀 프로덕션 진입.

> [!key-insight] 솔로 안전망 3중
> 협동 제거 + 보스 5-6 한정 + 콜라주 비주얼 = 작업량 통제 3중 안전망. 그래도 12-18개월. 처음부터 *제외 결정*을 명시해 스코프 크리프 방지.

## 미해결 질문 (다음 라운드)

> [!gap] Solo Contra 2026 미해결
> 1. 시간 되감기 시 적·탄환 동시 vs 플레이어만? (Braid vs 체크포인트)
> 2. 콜라주 캐릭터 사진 출처 — 스톡/촬영/AI? IP·라이선스 비교
> 3. 스토리 톤 — 디스토피아 진지 vs 풍자 펑크?
> 4. Godot 4 시간 되감기 구현 패턴 — 상태 스냅샷 vs 입력 리플레이?
> 5. 4-5개 무기 카탈로그 — Contra M/F/L/S/R/B 중 어느 3-4개를 SF 재해석?
> 6. Easy/Hard 토큰 슬라이더 — 단일 토글(Cuphead Simple) vs 슬라이더(Hades God Mode)?

## See Also

- [[Run and Gun Success Pattern Matrix]] — 본 컨셉이 통과시킨 7코어
- [[Modern Difficulty Accessibility]] — 1히트 + Easy 토글 결론
- [[Indie Self Publishing Run and Gun]] — 매출 천장
- [[Katana Zero]] — 시간 메커닉 + 1히트 모범 사례
- [[Contra Weapon System]] — 무기 4-5개 도출 베이스
- [[IP Avoidance For Game Clones]] — 메카닉 모방·비주얼 오리지널 원칙
- [[Cooperative Run and Gun Design]] — 협동 제외 근거
- [[Followup Modern Acceptance And Indie RnG Threshold]] — Q4/Q5 결론
