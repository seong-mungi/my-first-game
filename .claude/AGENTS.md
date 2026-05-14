# `.claude/` Working Notes

- This directory remains the canonical source for this repository's workflows, roles, rules, and templates.
- When editing skill body content, update `.claude/skills/*/SKILL.md`; do not edit `.agents/skills/*/SKILL.md` first.
- After editing skill body content, run `python3 ../tools/sync_codex_adapters.py` to synchronize the Codex adapters.
- `.claude/agents/*.md` contains the original role definitions; Codex consumes them through `.agents/skills/ccgs-agent-router/SKILL.md`.
