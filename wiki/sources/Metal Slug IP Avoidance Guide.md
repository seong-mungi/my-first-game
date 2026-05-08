---
type: source
source_type: internal_research_guide
title: "메탈슬러그 팬아트 클론 제작 시 IP 라이선스 회피 가이드"
author: claude-obsidian-wiki 리서치 종합
date_published: 2026-05-08
date_accessed: 2026-05-08
url: ".raw/metal-slug-ip-avoidance-guide.md"
confidence: medium
key_claims:
  - 게임 메카닉은 미국·한국 공통 저작권 보호 대상이 아님
  - 비주얼(캐릭터·음악·로고) 교체만으로 합법적 상업 출시 가능
  - "Metal Slug" 이름과 SNK 상표는 사용 불가; 메카닉 모방은 자유
  - SV-001 탱크의 둥근 포탑·짧은 차체 실루엣은 SNK 트레이드마크
  - Broforce(Free Lives, 2015)가 모범 사례 — 패러디 + 오리지널 게임플레이로 Steam 상업 출시
  - 런앤건 8대 핵심 시스템(이동·무기·근접·차량·HP·적·스코어·레벨)은 모두 자유 구현 가능
related:
  - "[[Metal Slug]]"
  - "[[SNK]]"
  - "[[Run and Gun Genre]]"
  - "[[Run and Gun Base Systems]]"
  - "[[Weapon Letter Pickup System]]"
  - "[[IP Avoidance For Game Clones]]"
  - "[[Broforce]]"
tags:
  - source
  - internal
  - ip
  - legal
  - run-and-gun
  - my-game
---

# Metal Slug IP Avoidance Guide

## Summary

메탈슬러그 류의 런앤건 게임을 합법적으로 제작·상업 출시하기 위한 IP 회피 가이드. 핵심 명제는 **"게임 메카닉은 저작권 대상이 아니므로 자유롭게 모방 가능하나, 비주얼·이름·음악은 반드시 교체해야 한다"**. 미국과 한국의 공통 저작권 원칙에 기반하며, 본 프로젝트(`my-game`)가 런앤건 노선을 채택할 경우 곧바로 적용 가능한 실무 체크리스트를 제공한다.

## What It Contributes

### 1. 보호받지 않는 요소 (자유 구현 가능)

런앤건 장르의 메카닉 전체:

- 횡스크롤 이동 + 8방향 겨냥
- 특수 무기 픽업 → 기본 무기 복귀 시스템 (참고: [[Weapon Letter Pickup System]])
- 차량 탑승 / 내구도 시스템
- 포로 구출 → 스코어 보너스 구조
- 1히트 즉사 + 잔기 시스템 (참고: [[Run and Gun Base Systems]])
- 보스 멀티페이즈 패턴 구조
- 군인·악당 장군·외계인 등 장르 컨벤션 설정
- 유사 UI/HUD 레이아웃
- 유사 음악 장르 스타일 (군악·록 퓨전; **멜로디는 오리지널**)

### 2. 반드시 교체해야 하는 요소

| 카테고리 | 회피 필수 요소 |
|---|---|
| 캐릭터 | Marco Rossi / Tarma Roving / Eri Kasamoto / Fio Germi / General Morden 외형·이름 |
| 차량 | SV-001 탱크 실루엣(둥근 포탑 + 짧은 차체 + 만화적 비례) |
| 적 캐릭터 | 아랍병사·미라·좀비·화성인 등 구체적 외형 |
| 이름·상표 | "Metal Slug", "SNK", "SNK Playmore" |
| 음악·효과음 | Metal Slug OST 전체 |

판단 기준: **"알아보면 안 된다"** — 장르 컨벤션은 OK, SNK IP 식별은 NG.

### 3. 팬아트 클론 vs 오리지널 클론 비교 매트릭스

| 구분 | 팬아트 클론 | 오리지널 클론 |
|---|---|---|
| SNK 캐릭터 사용 | O | X |
| 법적 위험 | 높음(비상업만 묵인) | 낮음 |
| 상업화 가능 | 불가 | 가능 |
| 예시 | GitHub 현 클론 대부분 | [[Broforce]], Fury Fighter |

### 4. GitHub 클론 처리 패턴 (실증)

- `giacoballoccu/metal-slug-unity` (23★) — "metal slug" 이름 유지, 비상업 묵인
- `alfredo1995/metal-slug` (21★) — 동일 패턴
- `Valks-Games/SideScrollBattleGame` (1★) — 이름 완전 변경 + "inspired by" 명시 → 가장 안전

### 5. 런앤건 8대 핵심 시스템 (자유 구현)

| # | 시스템 | 핵심 요소 |
|---|---|---|
| 1 | 이동 | 수평이동·점프·앉기·대시·8방향 겨냥 |
| 2 | 무기 | 기본(무한) + 특수(유한·픽업·교체) + 투척 |
| 3 | 근접 공격 | 접근전 자동 발동, 근접 > 원거리 |
| 4 | 차량 | 탑승 시 내구도 완충 + 공격력↑ |
| 5 | HP/라이프 | 1히트 즉사(아케이드) vs HP바(현대) |
| 6 | 적 설계 | 보병·공중·기계화·포탑·미니보스·보스 |
| 7 | 스코어링 | 포로 구출 보너스 + 콤보 배수 |
| 8 | 레벨 디자인 | 자유/강제/수직 스크롤, 구간 변화 |

이 8요소는 [[Run and Gun Base Systems]]의 5요소 최소기능세트와 [[Run and Gun Extension Systems]]의 확장 카탈로그 중 일부와 직접 매칭된다.

## What's Missing

- 정확한 판례 인용 부재. "메카닉은 보호되지 않는다"는 미국 *Tetris Holding v. Xio Interactive* (2012)과 같은 핵심 판례를 명시하지 않음.
- 한국 저작권법 구체 조항(저작권법 제2조 1호·5조 등) 인용 없음.
- 일본 SNK 본사가 한국 출시작에 대해 실제로 어디까지 추적/소송하는지 사례가 부족.
- "둥근 포탑 + 짧은 차체"가 어디서부터 트레이드드레스 침해가 되는지 정량 기준 없음.
- 캐릭터 디자인의 "유사도 임계점" 정의가 주관적.

> [!gap] 본 가이드는 사내 리서치 종합이며 법률 자문이 아니다. 상업 출시 전 IP 전문 변호사 검토가 필요하다.

## Notes On Confidence

- "게임 메카닉은 저작권 보호 대상이 아니다"는 미국·한국 모두에서 통용되는 일반 원칙으로 high confidence.
- 구체적 판단(특정 캐릭터 디자인이 침해인지)은 사례별 판단이 필요하며 medium confidence.
- 일본 시장 출시 시 추가 리스크는 본 가이드가 다루지 않음 (low coverage).

## Implications For my-game

본 프로젝트가 런앤건 노선(선택 C)을 채택할 경우:

1. **메카닉 자유 모방.** 8대 시스템 그대로 구현해도 법적 문제 없음.
2. **비주얼 100% 오리지널 필수.** 캐릭터·차량·적·UI 스타일·음악 모두 자체 제작.
3. **이름 회피.** "Metal Slug", "SNK", "SV-001" 등 직접 언급 금지. 마케팅 카피에서도 주의.
4. **레퍼런스 모델은 [[Broforce]].** 패러디 + 오리지널 게임플레이로 Steam 상업 출시 성공.
5. **상업화 의도 시 사내 절차로 IP 검토 단계 명시.** v1 GDD에 IP 회피 체크리스트 임베드.

## See Also

- [[IP Avoidance For Game Clones]] — 본 가이드의 일반화 개념
- [[Broforce]] — 실증 모범 사례
- [[Metal Slug]] — 회피 대상 IP 본체
- [[SNK]] — 권리 보유사
- [[Run and Gun Genre]], [[Run and Gun Base Systems]], [[Run and Gun Extension Systems]] — 장르 시스템 분해
