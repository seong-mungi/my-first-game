---
type: source
title: 런앤건 Art Bible 작성 가이드 & 레퍼런스
created: 2026-05-09
updated: 2026-05-09
status: active
tags: [source, art-bible, run-and-gun, pixel-art, visual-style, game-design, metal-slug]
---

# 런앤건 Art Bible 작성 가이드 & 레퍼런스

**리서치 날짜**: 2026-05-09  
**목적**: Metal Slug 스타일 런앤건 게임 아트 바이블 작성을 위한 방법론 및 레퍼런스

---

## Art Bible란

> "팀원 각각이 오늘 다른 장소에서 에셋을 만들어도, 같은 사람이 같은 날 만든 것처럼 보이게 만드는 문서"

GDD(게임 디자인 문서) 직후, **프로덕션 진입 전**에 작성. 에셋을 만들기 전 "어떻게 보여야 하는가"에 대한 팀 전체의 합의서.

**핵심 질문**: "우리 팀 각자가 에셋을 기여하기 위해 알아야 하는 것은 무엇인가?"

---

## Art Bible 표준 섹션 구조

```
Art Bible
├── 1. Vision Statement         ← 1-2문장으로 게임의 시각적 정체성 정의
├── 2. Mood Board               ← 레퍼런스 이미지 콜라주 (영화·게임·일러스트)
├── 3. Color Palette            ← Primary / Secondary / Accent / Zone별 팔레트
├── 4. Character Design Rules   ← 비율·실루엣·애니메이션 수·표현 규칙
├── 5. Enemy Design Rules       ← 위협 레벨 시각 언어, 실루엣 가독성
├── 6. Environment Design Rules ← 원근 레이어, FG/MG/BG 분리 규칙
├── 7. VFX Rules                ← 피격 피드백, 파괴 파티클, 발사체 색상 코드
├── 8. UI/HUD Rules             ← 폰트, 아이콘, 체력바 스타일
├── 9. Technical Specs          ← 해상도, 스프라이트 크기, 타일셋, 파일 포맷
├── 10. Do's & Don'ts           ← 금지 패턴 시각 비교
└── 11. Naming Conventions      ← 파일/폴더 명명 규칙
```

---

## 런앤건 장르 특화 추가 섹션

### Sprite Resolution & Animation Budget

| 요소 | 권장 범위 | Metal Slug 원본 |
|------|----------|----------------|
| 플레이어 스프라이트 크기 | 32×32 ~ 64×64 | ~48×48 (Neo Geo 기준) |
| 색상 수 / 스프라이트 | 16~32색 | **최대 15색** |
| 걷기 애니메이션 | 6~8프레임 | 8프레임 |
| 사격 포즈 수 | 최소 8방향 | 8방향 (45° 단위) |
| 적 사망 애니메이션 | 4~8프레임 | 6~12프레임 |

### 발사체 시각 언어 (색상 코드)

```
플레이어 발사체  → 밝은 노랑 / 흰색 계열  (아군 인식)
일반 적 발사체   → 붉은색 / 주황 계열     (회피 필요)
보스 발사체      → 붉은색 + 글로우 이펙트 (고위협)
폭발 / AoE      → 주황 → 빨강 그라데이션
```

### 화면 카오스 예산 (Chaos Budget)

동시에 화면에 존재할 수 있는 시각 요소 상한선:

```
플레이어 발사체:  최대 8개 동시
적 발사체:        최대 12개 동시
파티클/이펙트:    최대 15개 동시
적 캐릭터:        최대 6개 동시
```

### Enemy Silhouette Readability Rule

```
300ms 규칙: 적의 실루엣만 보고 0.3초 안에 위협 수준을 파악할 수 있어야 함

보병 (소위협)   → 직립 인간형, 작은 실루엣
중화기 (중위협) → 더 큰 실루엣 + 총기 돌출
차량 (고위협)   → 인간보다 1.5~2배 크기
보스 (최고위협) → 화면 20% 이상 점유
```

### Hit Feedback Visual Standard

```
피격 발생 시 의무 요소:
  1. 스프라이트 화이트 플래시  (2~3프레임)
  2. 카메라 쉐이크              (피해량 비례)
  3. 피격 파티클               (혈액 or 기계 파편)
  4. 사운드 피드백             (시각과 동기화 필수)
```

---

## Metal Slug 비주얼 룰 (6th Division's Den 분석)

### 3대 스프라이트 기둥

**1. Shaping (형태)**
- 머리 = 전체 신장의 1/3 (과장 비율)
- 팔다리 = 가장 긴 파트
- 목은 거의 숨김 (옷/머리로 가림)
- 차량 = 인간보다 약간 큼
- 비율 과장이 장르의 시각적 정체성

**2. Coloring (색상)**
- 스프라이트당 최대 15색 (Neo Geo 하드웨어 제약 → 시각 일관성 강제)
- 신체 부위별 색상 그룹 분리
- 단색 아닌 색조+명도 변화 그라데이션
- 아웃라인: 단색 검정 기본, 드물게 2~3색 혼용

**3. Shading (음영/디테일)**
- 단일 광원 (전면/측면/상단 중 택1 — 전체 일관)
- 얼굴: 최소한의 음영 (가독성 우선)
- 곡면 기법 3가지: stroking / dithering / 혼합
- 폭발/플래시: 명도 대비 극대화

---

## Hotline Miami × Katana Zero 비주얼 DNA

Achievers+Killers(2nd) / Challenge+Sensation 타겟 시각 언어:

| 요소 | Hotline Miami | Katana Zero | 적용 방향 |
|------|-------------|-------------|----------|
| 팔레트 | 네온 핑크·청록·보라 | 네온 파랑·보라·다크 | 네온 액센트 + 다크 베이스 |
| 배경 명도 | 낮음 (어두운 탑뷰) | 낮음 (도시 야경) | 배경 어둡게 → 캐릭터 돋보임 |
| VHS 이펙트 | 없음 | CRT 스캔라인, 글리치 | 레트로 필터 옵션 |
| 폭력 표현 | 추상화된 픽셀 피 | 영화적 슬로우모 | 추상화 수준 사전 결정 |
| 음악과 시각 싱크 | 마스크 선택 → 무드 | 슬로우모 타이밍 | 비트에 맞는 피격 이펙트 |
| 아웃라인 스타일 | 없음 (픽셀 직접) | 없음 | 유무 명시 필요 |

---

## 공개 Art Bible 레퍼런스 목록

| 자료 | URL | 특징 |
|------|-----|------|
| Polycount Wiki - Art Bible | http://wiki.polycount.com/wiki/Art_Bible | 업계 표준 섹션 목록 |
| dusthandler Art Bible | https://dusthandler.github.io/Art_Bible/ | GitHub Pages 공개 인디 예시 |
| kiwitrek Art Bible Guide | https://kiwitrek.github.io/ArtBible/ | 작성 방법론 가이드 |
| aeno.nl Art Bible PDF | https://www.aeno.nl/uploads/Art-bible.pdf | 완성 문서 샘플 PDF |
| 6th Division Metal Slug Tutorial | https://6th-divisions-den.com/ms_tutorial.html | MS 스프라이트 기술 기준 |
| Oleander Studios - Art Bible | https://www.oleanderstudios.com/what-is-an-art-bible-examples-practical-tips/ | Do's & Don'ts 중심 |
| NOVEM Dev Blog Art Bible | https://medium.com/novem-dev-blog/cr7001-art-bible-9c5c620e9418 | Lookdev 스타일 실제 인디 예시 |

---

## 실전 작성 순서 (솔로/소규모 팀)

```
Step 1. Vision Statement 1문장 확정
        예: "네온 다크 도시를 배경으로 한 픽셀아트 런앤건.
             Metal Slug의 유머러스한 폭력 + Katana Zero의 긴장감"

Step 2. Mood Board 제작 (Miro/Figma)
        레퍼런스 20~30장 → 공통 키워드 5개 추출

Step 3. Color Palette 확정 (가장 먼저!)
        팔레트 없이 스프라이트 작업 금지

Step 4. 플레이어 캐릭터 1개 완성 → Art Bible의 모든 규칙 검증

Step 5. 첫 적 캐릭터 1개로 Do's & Don'ts 작성

Step 6. 환경 타일셋 1세트로 Environment Rules 완성

Step 7. 문서화 → Notion / Google Slides / Markdown
```

---

## 핵심 교훈

**색상 팔레트는 가장 먼저, 가장 엄격하게** — 팔레트가 흔들리면 모든 에셋이 따로 놀게 됩니다. Metal Slug의 15색 제한은 Neo Geo 하드웨어 제약이었지만, 결과적으로 시각적 일관성을 강제하는 훌륭한 규칙이 되었습니다.

**Art Bible는 살아있는 문서** — 처음부터 완벽할 필요 없습니다. 첫 에셋이 만들어질 때마다 규칙을 검증하고 업데이트하는 것이 정상 흐름입니다.

---

## 관련

- [[Run-and-Gun Genre]] — 런앤건 장르 8대 시스템
- [[run-and-gun-game-systems-research-2026-05-08]] — 장르 게임시스템 리서치
- [[giacoballoccu-MetalSlugClone-code-analysis]] — 코드 구조 분석
- [[metal-slug-ip-avoidance-guide]] — IP 회피 전략
