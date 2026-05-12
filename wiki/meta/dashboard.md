---
type: meta
title: "Dashboard"
updated: 2026-05-12
tags: [meta, dashboard]
status: living
---

# Wiki Dashboard

*Static snapshot — 2026-05-12. Update manually after lint cycles.*

## Stats

| Metric | Count |
|---|---|
| Total wiki files | 139 |
| Concept pages | 60 |
| Source pages | 29 |
| Synthesis pages | 19 |
| Entity pages | ~10 |
| Reference games | 23 |

## Recent Activity (last 7 days)

| Page | Type | Date |
|---|---|---|
| Research Run and Gun Development Base | synthesis | 2026-05-12 |
| Run and Gun Enemy AI Archetypes | concept | 2026-05-12 |
| Run and Gun Player Character Architecture | concept | 2026-05-12 |
| Run and Gun Bullet System Pattern | concept | 2026-05-12 |
| Run and Gun Level Design Patterns | concept | 2026-05-12 |
| Godot 4 Run and Gun GitHub Repos | source | 2026-05-12 |
| Godot 4 Run and Gun Tutorial Resources | source | 2026-05-12 |
| Run and Gun Dev Community Resources | source | 2026-05-12 |
| Research Boss Rush Development Base | synthesis | 2026-05-12 |
| Boss Rush Design Fundamentals | concept | 2026-05-12 |
| Boss Identity Framework | concept | 2026-05-12 |
| Shmup Boss Design Factors | concept | 2026-05-12 |
| Boss Rush Content Sizing | concept | 2026-05-12 |
| GDC Boss Battle Design Talks | source | 2026-05-12 |
| Boss Rush Jam 2025 | source | 2026-05-12 |
| Godot 4 Boss Tutorial Resources | source | 2026-05-12 |

## Dataview Queries (for when plugin is available)

```dataview
TABLE type, status, updated FROM "wiki" SORT updated DESC LIMIT 15
```

```dataview
LIST FROM "wiki" WHERE status = "seed" SORT updated ASC
```

```dataview
LIST FROM "wiki/concepts" WHERE !type OR !status SORT file.mtime DESC
```

```dataview
TABLE file.name, file.size FROM "wiki" WHERE file.size > 15000 SORT file.size DESC
```

## Known Issues (from lint-report-2026-05-12)

- 8 new concept pages missing `type: concept` + `status: stable`
- 6 new source pages missing `status: stable`
- ~100 older pages missing `status:` field
- 32 dead wikilinks (see lint report for full list)
- Case-mismatch dead link: `[[Run And Gun Base Systems]]` in `Aim Lock Modifier Pattern.md`
- `[[Boss Rush Design Articles Game Developer]]` source page needs creation

## Related

- [[lint-report-2026-05-12]]
