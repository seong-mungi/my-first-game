---
title: Indie Game Community Platform Stack
tags: [concept, community, discord, steam, social]
aliases: [Community Stack, Discord Indie Game]
created: 2026-05-12
updated: 2026-05-12
---

# 인디 게임 커뮤니티 플랫폼 스택

CCGS `community-manager` 에이전트가 전략 문서를 작성한다. 실제 플랫폼 설정·운영은 개발자가 별도로 한다.

## 권장 스택 (소규모 → 확장)

### 1단계: Discord (즉시)

- **역할:** 실시간 플레이어 피드백, 알파/베타 테스터 모집, 데브로그 채널
- **왜 먼저:** 콘텐츠가 없어도 커뮤니티 빌딩 시작 가능. 인디 게임 커뮤니티 기본값.
- **비용:** 무료
- Source: Discord 개발자 블로그 (high, 2025)

### 2단계: Steam 커뮤니티 허브 (론치 시)

- **역할:** 론치 후 플레이어 지원, 공지사항. 플레이어가 이미 있는 곳.
- **비용:** Steamworks 포함 (무료)

### 3단계: Reddit / itch.io 데브로그 (콘텐츠 축적 후)

- **Reddit** (`r/indiegaming`, `r/godot`) — 더 넓은 인지도·개발자 커뮤니티
- **itch.io 데브로그** — 출시 전 개발 투명성 + 위시리스트 빌딩
- **적합 시점:** Discord + 스팀 허브 운영 안정화 후

> [!key-insight] 소스들이 일관되게 권고: 처음엔 Discord만 운영하라. 콘텐츠가 쌓인 후 Reddit·Steam 허브를 추가하라. 얇게 퍼지면 모두 소홀해진다.

## CCGS와의 관계

CCGS `community-manager` 에이전트:
- 커뮤니티 전략 문서, 패치 노트, 소셜 미디어 포스트 초안 생성
- Discord 서버 생성, Reddit 포스팅, Steam 허브 모더레이션 = 인간 작업

## Sources

- Discord 블로그: How to Build an Indie Game Community (high, 2025)
- Polydin: Top Indie Game Platforms 2025 (high, 2025)
- itch.io devlog feature (high)
