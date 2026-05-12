---
title: Godot CI CD Pipeline Pattern
tags: [concept, godot, ci-cd, testing, github-actions]
aliases: [Godot CI, GitHub Actions Godot]
created: 2026-05-12
updated: 2026-05-12
---

# Godot CI/CD 파이프라인 패턴

Godot 4.x 헤드리스 CI 실행의 필수 두 단계 패턴. 이 패턴을 모르면 CI가 false failure를 냄.

## 핵심 패턴: 두 단계 실행

```yaml
# Step 1: Import warm-up (리소스 임포트 캐시 생성)
- name: Import assets
  run: godot --headless --editor --quit

# Step 2: 실제 테스트 실행
- name: Run GUT tests
  env:
    GODOT_DISABLE_LEAK_CHECKS: "1"
  run: godot --headless --script addons/gut/gut_cmdln.gd
```

> [!key-insight] Step 1(warm-up)을 생략하면 임포트 안 된 리소스로 인해 false failure가 발생한다. 이는 Godot CI 첫 설정의 가장 흔한 함정이다.

## 환경 변수

- `GODOT_DISABLE_LEAK_CHECKS=1` — 메모리 누수 체크 출력 억제. 없으면 CI 파서가 오탐 실패로 처리.

## 주요 GitHub Actions

| Action | 용도 | 별점 | 확인 버전 |
|---|---|---|---|
| `gdUnit4-action` (MikeSchulze) | GDScript + C# 테스트, JUnit XML 출력 | 57 ⭐ | Godot 4.4 |
| `ceceppa/godot-gut-ci` | GUT 특화 CI 러너 | — | 4.x |
| 수동 GitHub Actions YAML | 커스텀 빌드·익스포트·업로드 | — | 모든 버전 |

## 완전한 파이프라인 구성 요소

1. **테스트 게이트** — GUT or GdUnit4 헤드리스 실행
2. **빌드/익스포트** — `godot --headless --export-release`
3. **Steam 업로드** — SteamCMD via `steamcmd +login ... +run_app_build`
4. **선택: Codemagic** — Git push → Steam depot 원스텝 (Godot 4.6 확인 TBD)

## CCGS와의 관계

CCGS는 "CI/CD에서 테스트가 통과해야 한다"는 규칙을 명시하지만 실제 `.yml` 파일은 제공하지 않는다. 이 패턴이 그 갭을 채운다.

## Sources

- Medium: CI-tested GUT for Godot 4 (kpicaza, high, 2025)
- GdUnit4-action GitHub (MikeSchulze, high, 2026-05-07 updated)
- Godot 공식 문서 (high)
