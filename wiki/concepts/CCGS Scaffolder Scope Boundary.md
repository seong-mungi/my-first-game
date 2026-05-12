---
title: CCGS Scaffolder Scope Boundary
tags: [concept, ccgs, scaffolding, process]
aliases: [CCGS Scope, Scaffolder Boundary]
created: 2026-05-12
updated: 2026-05-12
---

# CCGS Scaffolder 범위 경계

CCGS는 "무엇을·어떻게·잘 만들었는지"를 다루는 **프로세스 레이어**다. 실제 구현 툴체인과는 명확히 분리된다.

## CCGS가 하는 것 (IN SCOPE)

- GDD, ADR, 스프린트 플랜, 릴리즈 체크리스트 생성
- 49개 도메인별 AI 에이전트 조정
- 코드 리뷰, QA 플랜, 아키텍처 리뷰
- 커밋 위생, JSON 스키마 검증 훅
- 이벤트 택소노미 설계, 커뮤니티 전략 문서

## CCGS가 하지 않는 것 (OUT OF SCOPE)

- 스프라이트·텍스처·애니메이션 파일 생성
- 사운드 이펙트·음악 작곡·믹싱
- GitHub Actions YAML 워크플로 파일
- 텔레메트리 SDK 통합 코드
- Steamworks depot 빌드 스크립트
- Discord 서버 설정·커뮤니티 운영

## 경계 원칙

> [!key-insight] CCGS 에이전트가 "X를 해야 한다"고 명시하면, 그 X는 별도 툴로 구현해야 한다는 신호다.

예: `audio-director` 에이전트가 "FMOD 통합 필요"라는 스펙을 내놓는다 → 실제 FMOD GDExtension 설치·설정은 개발자가 별도로 해야 함.

## 관련 페이지

- [[Research CCGS Implementation Gap Full Stack]] — 전체 갭 매트릭스
- [[Research Godot 4.6 Ecosystem Toolchain]] — 필요 툴 카탈로그
