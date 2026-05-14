# Smoke Test: Critical Paths

**Purpose**: Run these 10–15 checks in under 15 minutes before any QA hand-off.  
**Run via**: `/smoke-check` (which reads this file).  
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash.
2. New game / session can be started from the main menu.
3. Main menu responds to all inputs without freezing.

## Core Mechanic (update per sprint)

4. [Primary mechanic — update when first core system is implemented.]

## Data Integrity

5. Save game completes without error once Save / Settings Persistence is implemented.
6. Load game restores correct state once Save / Settings Persistence is implemented.

## Performance

7. No visible frame-rate drops on target hardware (60 fps target).
8. No memory growth over 5 minutes of play once the core loop is implemented.
