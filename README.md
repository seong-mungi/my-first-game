# Echo *(working title)*

> 2D 횡스크롤 run-and-gun + 1초 시간 되감기 토큰. 1히트 즉사 + 즉시 회수.
> Solo dev · Godot 4.6 / GDScript · PC Steam.

---

## Concept

VEIL이 계산한 죽음을 *철회*하는 인간 비합리성. 적 탄막에 가슴이 찢기는 *바로 그 프레임*에 좌트리거를 누르면 0.15초(9프레임) 전의 자기 몸으로 *재진입*한다 — 같은 패턴을 이번엔 *알고서* 다시 본다.

**시간 되감기 = 처벌이 아닌 학습 도구.**

NEXUS 메가시티 2038. ARCA Corporation의 예측 AI **VEIL**이 모든 시민의 미래를 0.1초 단위로 통제한다. 코드네임 **ECHO** — 등에 REWIND Core를 부착한 비예측 실험체. Original IP (Contra / MI 고유명사 없음).

## Pillars (locked 2026-05-08)

1. **시간 되감기 = 학습 도구** (처벌 아님)
2. **결정론적 패턴** (같은 입력 = 같은 결과)
3. **명확한 위협 읽기** (0.2초 glance test)
4. **코어 루프 5분 룰** (어떤 화면에서도 5분 안에 코어 루프 도달)
5. **작은 성공 > 큰 야심** (출시 가능 우선)

## Status — Pre-production (2026-05-10)

| | 항목 | 상태 |
|---|------|------|
| ✅ | Game Concept + 5 Pillars | Locked 2026-05-08 |
| ✅ | Art Bible (Collage SF — Höch + Monty Python cutout + Blade Runner/Akira/GitS + Cuphead) | Locked |
| ✅ | ADR-0001/2/3 (Time Rewind: scope / storage / determinism) | Accepted |
| ✅ | 4 / 24 시스템 GDD Designed | #5 State Machine, #6 Player Movement, #8 Damage, #9 Time Rewind |
| ⏳ | Tier 1 ring buffer prototype | 4-6 weeks (next) |

다음 GDD 작성 순서: **Input #1 → Scene Manager #2 → Player Shooting #7 → HUD #13 → Enemy AI #10 → Boss Pattern #11 → Time Rewind Visual Shader #16**.

## Tech Stack

| Layer | Choice |
|-------|--------|
| **Engine** | Godot 4.6 |
| **Language** | GDScript (statically typed, warnings-as-errors) |
| **Rendering** | Forward+ |
| **Physics** | Godot Physics 2D · CharacterBody2D + Area2D (RigidBody2D 게임플레이 entity 금지 per ADR-0003) |
| **Determinism clock** | `Engine.get_physics_frames()` (wall-clock 사용 금지) |
| **Test** | GUT (Godot Unit Test) — 코어 시스템 70% / balance formula 100% target |
| **Target** | PC Steam · gamepad primary · KB+M parity · Steam Deck verified |
| **Budget** | 60 fps locked · 16.6 ms · ≤500 draw calls · 1.5 GB resident |

## Tier 진행 일정

| Tier | Scope | Duration |
|------|-------|----------|
| **Tier 1 — Prototype** | 1 stage / 1 weapon / 1 boss (STRIDER) | 4-6 weeks |
| **Tier 2 — MVP** | 코어 시스템 전부 + 3 stages | ~6 months |
| **Tier 3 — Release** | Steam launch | ~16 months |

## Repo Structure

```
design/
  gdd/                 # 시스템 GDD (8 required sections + Visual/Audio + Z + Appendix)
  art/                 # Art Bible (Collage SF identity)
docs/
  architecture/        # ADRs (locked technical decisions)
  registry/            # architecture.yaml — state ownership / interfaces / forbidden patterns
src/                   # Game source (Tier 1 prototype 시작 시)
prototypes/            # Throwaway prototypes (ring buffer 등 — isolated from src/)
tests/                 # GUT unit / integration / performance / playtest
production/            # Sprint plans, milestones, session logs
```

## Workflow

Built on the **[Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)** template — 49 specialized subagents + 72 slash-skill workflow automate design-review, cross-doc consistency, forbidden-pattern enforcement, and architecture decision tracking.

Every system follows the collaborative principle:

> **Question → Options → Decision → Draft → Approval**

No autonomous file writes. No commits without explicit instruction. Solo dev with AI as a structured studio team, not a co-pilot.

## License

All rights reserved (solo project, license decision deferred to pre-launch).

---

*Working title; final title pending creative-director sign-off after Tier 2 vertical slice.*
