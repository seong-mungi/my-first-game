# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6 (pinned 2026-05-08)
- **Language**: GDScript (statically typed; see Coding Standards)
- **Rendering**: Forward+ (default for desktop; PC Steam target)
- **Physics**: Godot Physics 2D (Echo is 2D only — Jolt 4.6 default applies to 3D and is unused here)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Steam)
- **Input Methods**: Gamepad, Keyboard/Mouse
- **Primary Input**: Gamepad (run-and-gun core feel calibrated to dual-stick + face buttons)
- **Gamepad Support**: Full
- **Touch Support**: None
- **Platform Notes**: Steam Deck verified target — input layouts must work with Steam Deck controls. All UI must be d-pad/stick navigable. Time-rewind input must be a single dedicated button (no chord). KB+M parity required for accessibility but tuned secondary.

## Naming Conventions

<!-- GDScript variant — see Appendix A2 of /setup-engine SKILL.md for the source-of-truth table. -->

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables/Functions**: snake_case (e.g., `move_speed`, `take_damage()`)
- **Signals**: snake_case past tense (e.g., `health_changed`, `rewind_consumed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`, `REWIND_WINDOW_SECONDS`)

## Performance Budgets

- **Target Framerate**: 60 fps locked
- **Frame Budget**: 16.6 ms total (suggested split: gameplay+physics 6 ms / rendering 7 ms / time-rewind subsystem ≤1 ms / headroom 2.6 ms)
- **Draw Calls**: ≤ 500 per frame (2D run-and-gun baseline; tighten if Steam Deck struggles)
- **Memory Ceiling**: 1.5 GB resident (Steam Deck-friendly; well under 8 GB minimum spec)

## Testing

- **Framework**: GUT (Godot Unit Test) — primary unit + integration test runner for `.gd` files
- **Minimum Coverage**: Balance formulas 100%, gameplay systems target 70%, UI/visual exempted (see Coding Standards Test Evidence by Story Type)
- **Required Tests**: Balance formulas, time-rewind state machine (snapshot/restore correctness), enemy AI determinism, weapon damage/cooldown formulas

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here. Do NOT pre-populate speculatively. -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- **Accepted ADRs as of 2026-05-14**:
  - **ADR-0001** — Time Rewind Scope: player-only checkpoint model
  - **ADR-0002** — Time Rewind Storage Format: state snapshot ring buffer
  - **ADR-0003** — Determinism Strategy: CharacterBody2D + direct transform / Area2D projectiles
  - **ADR-0004** — Scene Lifecycle and Checkpoint Restart Architecture
  - **ADR-0005** — Cross-System Signal Architecture and Event Ordering
  - **ADR-0006** — Save and Settings Persistence Boundary
  - **ADR-0007** — Input Polling, Pause Handling, and UI Focus Boundary
  - **ADR-0008** — Player Entity Composition and Lifecycle State Ownership
  - **ADR-0009** — Damage, HitBox/HurtBox, and Combat Event Ownership
  - **ADR-0010** — Collage Rendering and Rewind Shader Pipeline
  - **ADR-0011** — Enemy, Boss, and Projectile Deterministic Scheduling
- **Pending ADRs**: None required for current Tier 1 MVP architecture; future ADRs may be needed for Pickup/Difficulty, localization/accessibility, or expanded audio/VFX routing.

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only — likely unused for Echo's 2D scope)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code (collage compositing, time-rewind visual signals). Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
