---
type: source
title: GitHub alfredo1995 metal-slug
created: 2026-05-08
updated: 2026-05-08
tags:
  - run-and-gun
  - unity
  - metal-slug
  - github
source_url: https://github.com/alfredo1995/metal-slug
fetched: 2026-05-08
key_claims:
  - "Unity 2D / C# 기반, Metal Slug 재현 프로젝트"
  - "라이선스 없음 (All Rights Reserved 기본 적용)"
  - "2026-01-29 마지막 푸시 — 저활성이나 최근까지 유지"
  - "CLASSEPAI_HERO.cs: 진짜 C# abstract class — Pulo()/Tiro() 구현 강제"
  - "BossControl.cs: vida >= 50 / vida < 50 분기로 2페이즈 구현됨"
  - "외부 에셋: DOTween, Fungus, iTween 대거 포함"
related:
  - "[[metal-slug alfredo1995]]"
  - "[[Abstract Base Class Pattern]]"
  - "[[Boss Two Phase Design]]"
  - "[[Opinion MetalSlugClone Base Plus Metal Slug Reference]]"
confidence: high
---

# GitHub alfredo1995 metal-slug

## 소스 개요

GitHub API (`gh api repos/alfredo1995/metal-slug`) 및 콘텐츠 API를 통해 2026-05-08 수집.
`CLASSEPAI_HERO.cs`, `BossControl.cs` 원문 직접 확인.

## 핵심 수집 데이터

### 저장소 메타데이터
- **ID**: 773163631
- **생성**: 2024-03-16
- **마지막 푸시**: 2026-01-29
- **스타**: 21 / **포크**: 7
- **라이선스**: 없음
- **언어**: C#
- **토픽**: csharp, metal-slug, metal-slug-unity, run-and-gun, unity, unity2d, unityengine
- **itch.io**: https://alfredo1995.itch.io/metal-slug

### CLASSEPAI_HERO.cs 원문 분석

```csharp
[System.Serializable]
public class InfosChar {
    // 점프/사격 버튼, 물리, 방향 등 공통 데이터
    public float maxSpeed, jumpForce;
    public Button pulo, tiro;
    public Rigidbody2D rb;
    public JoyControl joyC;
}

public abstract class CLASSEPAI_HERO : MonoBehaviour {
    public InfosChar infChar;
    public Vector2 direcaoH;

    public virtual void Start() {
        infChar.pulo.onClick.AddListener(Pulo);
        infChar.tiro.onClick.AddListener(Tiro);
        direcaoH = Vector2.right;
    }

    public abstract void Pulo();  // 점프: 서브클래스 구현 필수
    public abstract void Tiro();  // 사격: 서브클래스 구현 필수
}
```

### BossControl.cs 원문 분석

```csharp
public int vida = 100;  // HP 변수

void Update() {
    if (GAMEMANAGER.inst.gameEstado == 0) {
        if (inicio) {
            // 2페이즈 분기
            if (vida >= 50) {
                TirosControll(5, 9);  // Phase 1: 발사 딜레이 5초
            } else if (vida < 50) {
                TirosControll(0, 9);  // Phase 2: 즉시 발사
            }
            Movimento();
        }
    }
}
```

**2페이즈 전환**: `vida` 50% 임계값 — 즉각 구현, 연출 없음.

## 신뢰도 평가

- **데이터 출처**: GitHub REST API + 소스 코드 직접 확인 — 1차 소스
- **제한사항**: 라이선스 파일 부재, 스크립트 파일명이 포르투갈어 (유지보수 가독성 낮음)
- **외부 의존성**: Fungus(135+ 파일), DOTween, iTween — 이식 시 모두 대체 필요
