---
title: Indie Game Publishing Pipeline
tags: [concept, publishing, steam, itch-io, distribution]
aliases: [Steam Publishing, Indie Publishing]
created: 2026-05-12
updated: 2026-05-12
---

# 인디 게임 퍼블리싱 파이프라인

Steam + itch.io를 타깃으로 하는 Godot 4.6 인디 게임 배포 파이프라인.

## 필수 구성 요소

### Steamworks SDK

- **용도:** Steam 플랫폼 필수 API. 업적, 클라우드 세이브, DRM, depot 업로드 포함.
- **대체 불가:** Steam 출시에 필수. 대안 없음.
- **비용:** 무료 (Steam Direct 등록비 $100 별도)
- **Godot 통합:** GodotSteam 플러그인 또는 수동 GDExtension
- Source: Valve 공식 문서 (high)

### SteamCMD

- **용도:** Steam 콘텐츠 관리 커맨드라인 툴. CI에서 depot 빌드·업로드 자동화.
- **CI 통합:** GitHub Actions에서 `steamcmd +login ... +run_app_build` 호출
- **비용:** 무료
- Source: 인디 개발 가이드 복수 출처 (high)

### itch.io

- **용도:** 개발자 친화적 스토어. 얼리 액세스, 데모 배포, 게임잼 참가.
- **역할:** Steam 출시 전 조기 피드백 + 위시리스트 빌딩
- **비용:** 무료 (수익 배분 선택제)
- Source: Polydin top indie platforms 2025 (high)

## 파이프라인 단계

```
개발 → itch.io (알파/베타) → Steam 위시리스트 등록
     → GitHub Actions 빌드·테스트 → Godot headless export
     → SteamCMD depot 업로드 → Steam 심사 → 출시
```

## Steam 2026 규정 주의사항

Steam은 2026년부터 AI 생성 콘텐츠 공개 의무 부과:
- 스토어 페이지에서 AI 생성 에셋 출처 명시 필요
- CCGS가 생성한 문서나 설계는 AI 보조 개발에 해당 — 에셋 자체 AI 생성 여부가 기준
- Source: strayspark.studio (high, 2026)

## CCGS와의 관계

CCGS `/release-checklist`, `/launch-checklist` 스킬 → 마크다운 체크리스트 생성.
실제 Steamworks SDK 통합, SteamCMD 스크립트, depot 설정 = 개발자 작업.

## Sources

- Valve Steamworks 공식 문서 (high)
- Wayline.io: Indie Game Dev Custom Build Pipelines (high)
- Polydin: Top Indie Game Platforms 2025 (high)
- strayspark.studio: Steam AI Disclosure 2026 (high, 2026)
