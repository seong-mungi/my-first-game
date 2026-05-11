---
type: source
title: "Microsoft Xbox Accessibility Guidelines #107: Provide Aim Assist"
source_type: official-guideline
author: Microsoft Gaming Accessibility Team
date_published: 2023
url: https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/107
confidence: high
tags:
  - source
  - accessibility
  - aim-assist
  - microsoft
  - authoritative
  - industry-standard
status: catalogued
related:
  - "[[Aim Assist Accessibility Tiers]]"
  - "[[Research 8-Way Aim Usability For Run-and-Gun]]"
  - "[[Modern Difficulty Accessibility]]"
key_claims:
  - "Single-stick option required even for traditionally 2-stick games"
  - "Auto-fire toggle required for prolonged-hold actions"
  - "Aim assist must be granular (multiple intensity levels)"
  - "Sensitivity adjustment range ±50% required"
  - "Aim assist must not be coupled to difficulty selector"
---

# Microsoft XAG 107: Provide Aim Assist

Xbox Accessibility Guideline #107 — 권위 표준. Microsoft 게이밍 접근성 팀이 큐레이팅. Xbox 인증 시 의무 검토 항목.

## 핵심 요구사항

### 1. Single-stick option
> "Even games that traditionally require two sticks… can include options for single stick control."

- 운동 한계 플레이어 (CFAA, Xbox Adaptive Controller 사용자)에 의무
- 패턴: auto-fire + auto-aim-nearest = 2-stick 게임을 1-stick로 collapse
- 진행 게이트 X

### 2. Auto-fire toggle
- prolonged-hold action (지속 발사 등)에 의무
- Auto-jump / auto-sprint도 같은 카테고리
- Call of Duty Mobile "simple fire mode" (조준된 적 있을 때 자동 발사)가 canonical 예시

### 3. Granular aim assist
- 단일 ON/OFF X
- 다중 강도 권장 (Returnal 4-tier: Off/Low/Medium/High가 표준)
- 사용자가 자기 능력에 맞게 조정 가능해야 함

### 4. Sensitivity 조정
- ±50% 범위 의무
- Stick 감도 / 마우스 감도 둘 다

### 5. Difficulty와 직교
- 어시스트 ON/OFF가 난이도 선택과 결합 X
- Hard 모드에서도 어시스트 High 가능해야 함
- Easy 모드에서도 어시스트 Off 가능해야 함

## Echo 적용

상세: [[Aim Assist Accessibility Tiers]].

| 요구사항 | Echo Tier 1 게이트? |
|---|---|
| Single-stick 모드 | ✅ 필수 |
| Auto-fire 토글 | ✅ 필수 |
| 4-tier 어시스트 (Off/Low/Med/High) | ✅ 필수 |
| ±50% 감도 조정 | ✅ 필수 |
| 난이도 ↔ 어시스트 직교 | ✅ 비협상 |

> **Echo 출시 시 XAG 107 미준수 = Steam 출시는 가능하나 industry best practice 위반.** 솔로 indie도 모던 표준 충족 의무.

## Credibility

- **High** — Microsoft Game Studios 권위 가이드라인
- Xbox 인증 시 의무 검토
- AbleGamers, SpecialEffect 등 접근성 NPO 인용
- Game Accessibility Guidelines (산업 합의 표준)과 정합

## 보완 출처

- [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/) — 산업 합의 표준 (Microsoft, AbleGamers, SpecialEffect 공동)
- [Returnal Accessibility Review](https://www.familygamingdatabase.com/accessibility/Returnal) — XAG 107 모범 구현
- [AbleGamers APX](https://accessible.games/accessible-player-experiences/) — Accessible Player Experiences framework

## Echo Cross-References

- [[Modern Difficulty Accessibility]] — 1히트 즉사 + Easy 토글 의무 (Echo 베이스라인)
- [[Aim Assist Accessibility Tiers]] — Echo 4-tier 구현
- [[Accessibility Mode Bot Validation]] — XAG 107 준수 자동 검증
