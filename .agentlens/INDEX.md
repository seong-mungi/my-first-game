# AgentLens Index

Last updated: 2026-04-17

## How to Read This Repository Now

- `AGENTS.md`
  Repository-level Codex instructions, canonical source conventions, and synchronization workflow.
- `CLAUDE.md`
  Repository-level for full context, and synchronization workflow.
- `.agents/README.md`
  Codex adapter layer documentation, explaining why `.claude/` remains the source.
- `.agents/skills/INDEX.md`
  Auto-generated Codex skill index.
- `.agents/skills/ccgs-agent-router/SKILL.md`
  Routes requests to `.claude/agents/*.md` when the user names a specific studio role.
- `.claude/skills/*/SKILL.md`
  Original workflow definitions; still the single source of truth.
- `.claude/agents/*.md`
  Original role definitions.
- `.claude/docs/*`
  Templates, processes, rules, and engine references.

## Recommended Reading Order

1. `AGENTS.md` and the project `CLAUDE.md` for full context
2. `.agents/README.md`
3. `.claude/docs/quick-start.md`
4. `.claude/docs/workflow-catalog.yaml`
5. The relevant `.claude/skills/*/SKILL.md` or `.claude/agents/*.md`

## Directory Responsibilities

- `.agents/`
  Codex-consumable adapter layer; focused on mirroring and routing, without duplicating business content.
- `.claude/`
  Upstream Claude structure and official workflow definitions.
- `design/`
  Design assets such as GDDs, visuals, narrative, and levels.
- `docs/`
  Architecture, ADRs, engine references, and examples.
- `production/`
  Stages, iterations, stories, milestones, and session state.
- `src/`
  Game source code.

## Maintenance Rules

- To change skill content: edit `.claude/skills/*/SKILL.md`, then run `python3 tools/sync_codex_adapters.py`.
- To change role content: edit `.claude/agents/*.md`.
- To change Codex routing or generation strategy: edit `tools/sync_codex_adapters.py`, `.agents/README.md`, or `AGENTS.md`.
