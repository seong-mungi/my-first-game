---
type: question
title: Opinion MetalSlugClone Base Plus Metal Slug Reference
created: 2026-05-08
updated: 2026-05-08
tags:
  - opinion
  - run-and-gun
  - metal-slug
  - unity
  - godot
  - ip-risk
  - scaffold
  - research
related:
  - "[[MetalSlugClone giacoballoccu]]"
  - "[[metal-slug alfredo1995]]"
  - "[[IP Avoidance For Game Clones]]"
  - "[[Abstract Base Class Pattern]]"
  - "[[Boss Two Phase Design]]"
  - "[[Run and Gun Genre]]"
  - "[[Metal Slug]]"
  - "[[GitHub giacoballoccu MetalSlugClone]]"
  - "[[GitHub alfredo1995 metal-slug]]"
confidence: high
---

# Opinion MetalSlugClone Base Plus Metal Slug Reference

## 판정

> **❌ 거부(Rejected)**
>
> **근본 원인: 엔진 불일치.** 두 저장소 모두 **Unity/C#** 기반이며, 현재 my-game 프로젝트는 **Godot 4** 를 사용한다. Unity 코드를 Godot 스캐폴드로 사용하는 것은 불가능하고, 레퍼런스로 사용하더라도 패턴 이식 비용이 처음부터 작성하는 것보다 높다.

---

## 검토 대상

| 역할 | 저장소 | 엔진 | 언어 |
|---|---|---|---|
| 기반 스캐폴드 | `giacoballoccu/MetalSlugClone` | Unity 2D | C# |
| 레퍼런스 | `alfredo1995/metal-slug` | Unity 2D | C# |
| 현재 프로젝트 | my-game | **Godot 4** | GDScript / C# |

---

## 거부 근거 1: 엔진 불일치 (치명적)

두 저장소 모두 Unity 2D / C# 기반이다. 이 사실은 GitHub API 메타데이터(`"language": "C#"`, topics: `unity2d`)와 소스 코드(`using UnityEngine;` 헤더) 직접 확인으로 검증되었다.

**Unity → Godot 이식이 불가능한 이유:**
- Unity `MonoBehaviour` / `GameObject` 시스템은 Godot `Node` / `Scene` 시스템과 구조적으로 다르다
- Unity Physics (`Rigidbody2D`), Input (`Button.onClick`), Animation (`Animator`) API는 Godot에 직접 대응 없음
- Unity 에셋 포맷 (`.prefab`, `.unity`, `.asset`, `.anim`, `.controller`) Godot에서 사용 불가
- alfredo1995 저장소의 외부 의존성 (Fungus 대화 시스템 135+ 파일, DOTween, iTween)은 Unity 전용

(Source: [[GitHub giacoballoccu MetalSlugClone]], [[GitHub alfredo1995 metal-slug]])

---

## 거부 근거 2: 스캐폴드로서 giacoballoccu 저장소의 추가 문제

엔진 불일치와 별개로, 스캐폴드 후보로서도 적합하지 않다:

| 문제 | 세부 내용 |
|---|---|
| **비활성** | 마지막 푸시 2021-04-28 — 약 5년 전 |
| **라이선스 없음** | All Rights Reserved 기본 해석 → 상업 사용 금지 |
| **2페이즈 없음** | Boss2Controller는 단순 타이머 루프, HP 임계값 분기 없음 |
| **추상 기반 클래스 없음** | BossController / Boss2Controller 모두 `MonoBehaviour` 직접 상속 — 계층 없음 |
| **IP 리스크** | "Metal Slug" 명칭 사용, 라이선스 없는 클론 |

---

## 거부 근거 3: 레퍼런스로서 alfredo1995 저장소의 한계

alfredo1995 저장소는 두 패턴이 **실재**한다는 점에서 레퍼런스로서 가치는 있으나, 이식 가능성이 없다:

### 추상 기반 클래스 패턴 — 존재하나 이식 불가

`CLASSEPAI_HERO.cs`는 진짜 C# `abstract class`를 사용한다:
- `public abstract void Pulo()` — 점프 구현 강제
- `public abstract void Tiro()` — 사격 구현 강제

그러나 이 패턴은:
- Unity `MonoBehaviour` 상속에 묶여 있음
- `Button.onClick` 등 Unity UI 시스템에 의존
- 스크립트명이 포르투갈어로 가독성 낮음 (`CLASSEPAI_HERO`, `Pulo`, `Tiro`)

Godot 4에서 동등한 패턴은 처음부터 작성하는 것이 더 빠르다. (참고: [[Abstract Base Class Pattern]])

### 2페이즈 보스 — 존재하나 설계가 단순하고 연출 없음

`BossControl.cs`의 `if (vida >= 50) / else if (vida < 50)` 분기는 기능적으로 동작하지만:
- 페이즈 전환 연출 없음 (플래시, 사운드 변화, 일시 무적 없음)
- 이동 패턴 변화 없음 (양 페이즈에서 `Movimento()` 동일 호출)
- 시각적 피드백 없음

이 패턴을 레퍼런스로 "보스 2페이즈"의 *최소 요건*은 파악할 수 있으나, 구현 품질이 낮아 좋은 레퍼런스라고 보기 어렵다. (참고: [[Boss Two Phase Design]])

---

## IP 리스크 평가

두 저장소 모두 "Metal Slug"를 저장소명·설명에 사용하며 라이선스가 없다:

| 항목 | 평가 |
|---|---|
| 저장소 클론이 자체 IP 침해인가? | 아니다 — 메카닉은 저작권 비보호 영역 |
| 이 코드를 그대로 상업화 가능한가? | 아니다 — 라이선스 없음 = All Rights Reserved |
| 패턴(추상 기반 클래스, 2페이즈)을 아이디어로 참고하는 것은 안전한가? | 안전하다 — 메카닉은 아이디어 영역 |

SNK(Metal Slug IP 보유)는 팬 게임에 비교적 관대한 역사를 보여왔으나, 공식 입장은 없다. (Source: [[IP Avoidance For Game Clones]], [[Metal Slug]])

---

## 권고 대안

| 목표 | 권고 접근법 |
|---|---|
| **런앤건 스캐폴드** | CCGS `/prototype` 스킬로 Godot 4 런앤건 프로토타입을 처음부터 생성 |
| **추상 기반 클래스 패턴** | [[Abstract Base Class Pattern]] 페이지의 Godot 4 예제 코드 직접 사용 |
| **2페이즈 보스 설계** | [[Boss Two Phase Design]] 페이지의 State Machine 패턴 A 사용 |
| **런앤건 시스템 레퍼런스** | [[Run and Gun Base Systems]], [[Run and Gun Extension Systems]] 기존 wiki 페이지 활용 |
| **IP 안전 설계** | [[IP Avoidance For Game Clones]], [[Metal Slug IP Avoidance Guide]] 준수 |

---

## 오픈 질문

> [!gap] 미확인 사항
> 1. Godot 4 GDScript 전용 런앤건 오픈소스 스캐폴드가 존재하는가?
> 2. giacoballoccu MetalSlugClone의 3-레벨 게임플레이 루프는 실제로 완성되어 플레이 가능한 상태인가? (빌드 미확인)
> 3. alfredo1995 metal-slug의 itch.io 페이지에서 실제 플레이 가능한 빌드가 있는가?
