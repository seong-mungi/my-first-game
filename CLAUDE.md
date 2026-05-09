# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 48 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Engine specialists for Godot live under `.claude/agents/godot-*`.
> Routing rules and file-extension mapping are in
> `.claude/docs/technical-preferences.md` (Engine Specialists section).

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md

## knowledge base wiki
**Structure:** `.raw/` (immutable sources, never modify) · `wiki/` (knowledge base)

**Usage:** Drop file in `.raw/`, say "ingest [filename]". Claude reads `wiki/hot.md` → `wiki/index.md` → specific pages. Lint every 10-15 ingests.

### Skills

| Trigger | Action |
|---|---|
| `/wiki` | Setup, scaffold |
| `ingest [source]` | Ingest source into wiki |
| `query: [question]` | Answer from wiki |
| `lint the wiki` | Health check |
| `/save` | Save conversation to wiki |
| `/autoresearch [topic]` | Autonomous research loop |
| `/canvas` | Add to Obsidian canvas |

