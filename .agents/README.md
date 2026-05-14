# Codex Adapter Layer

Last updated: 2026-04-17

This directory turns the repository from a "Claude-first" structure into a version Codex can also consume directly, without duplicating and maintaining the entire workflow system.

## Design Principles

- `.claude/` remains the canonical source.
- `.agents/skills/*/SKILL.md` is the Codex adapter layer. It consistently tells Codex which canonical skill to read and how to translate Claude-specific tool semantics into Codex behavior.
- This avoids maintaining dozens of skill bodies separately in two directories.

## Where to Make Changes

- To change a skill workflow or wording: edit `.claude/skills/*/SKILL.md`.
- To change a role definition: edit `.claude/agents/*.md`.
- To change Codex adapter generation rules: edit `tools/sync_codex_adapters.py`.

## Resync

```bash
python3 tools/sync_codex_adapters.py
python3 tools/sync_codex_adapters.py --check
```

## Additional Entry Point

- `.agents/skills/ccgs-agent-router/SKILL.md`
  Routes role requests such as "creative-director / lead-programmer / qa-lead / art-director ..." to the original agent definitions.
