# ADR-0005: Cross-System Signal Architecture and Event Ordering

## Status
Accepted (ratified 2026-05-14)

## Date
2026-05-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting / Signals / Event Ordering |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md`, `.claude/docs/technical-preferences.md`, `docs/registry/architecture.yaml`, `docs/architecture/architecture.md`, `docs/architecture/adr-0001-time-rewind-scope.md`, `docs/architecture/adr-0002-time-rewind-storage-format.md`, `docs/architecture/adr-0003-determinism-strategy.md`, `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md`, `design/gdd/scene-manager.md`, `design/gdd/state-machine.md`, `design/gdd/damage.md`, `design/gdd/time-rewind.md`, `design/gdd/player-shooting.md`, `design/gdd/camera.md`, `design/gdd/hud.md`, `design/gdd/vfx-particle.md`, `design/gdd/audio.md` |
| **Post-Cutoff APIs Used** | None. This ADR relies on stable Godot 4.x signals, `Callable`-style `signal.connect(callable)`, `CONNECT_DEFAULT`, `Object.get_signal_connection_list()`, `StringName`, and `Engine.get_physics_frames()`. It explicitly forbids deprecated string-based `connect("signal", obj, "method")` and any gameplay timing based on `Time.get_ticks_msec()`, `OS.get_ticks_msec()`, or `InputEvent.timestamp`. |
| **Verification Required** | (1) Typed signal connections use Callable-style `signal.connect(handler)` with `CONNECT_DEFAULT` unless a source GDD explicitly allows deferred delivery. (2) Same-signal handler invocation order matches the declared connection order in fixtures for 1000 repeated runs. (3) No gameplay event uses string-based connect, a global event bus, wall-clock timing, or unordered Dictionary iteration to decide outcomes. (4) Damage same-frame emit order matches `hurtbox_hit -> lethal_hit_detected -> player_hit_lethal` and boss phase/kill ordering. (5) Camera/VFX/HUD/Audio remain observers and do not mutate gameplay state. (6) Static checks confirm forbidden direct cross-entity `transition_to` calls and raw SceneTree scene swaps outside SceneManager remain absent. |

> Engine validation note: primary engine specialist from `.claude/docs/technical-preferences.md` is `godot-specialist`. In this Codex adapter run, no subagent was spawned because the repository adapter limits `Task`/subagent use to explicit user-requested delegation. The draft was validated locally against the pinned Godot 4.6 reference files listed above. No blocking Godot 4.6 signal API incompatibility was found. Because local engine-reference files do not prove every connect-order edge case, this ADR requires direct Godot 4.6 fixture tests before production coding claims are accepted.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Time Rewind Scope; ADR-0002 Time Rewind Storage Format; ADR-0003 Determinism Strategy; ADR-0004 Scene Lifecycle and Checkpoint Restart Architecture. These must be accepted before implementing event-order-sensitive gameplay stories. |
| **Enables** | Scene Manager signal wiring, Damage/StateMachine/TimeRewind integration, Player Shooting downstream feedback wiring, Camera scene/rewind/shake consumers, HUD/VFX/Audio observer wiring, and future `/test-setup` static checks for signal purity. |
| **Blocks** | Any production story that wires cross-system gameplay signals, adds a new signal signature, changes connection order, introduces an event bus, changes Damage emit order, or adds a new observer to a gameplay signal must wait for this ADR to be accepted. |
| **Ordering Note** | ADR-0005 complements ADR-0004: ADR-0004 owns the scene lifecycle signals; ADR-0005 owns the general cross-system signal pattern and same-frame ordering rules across all systems. |

## Context

### Problem Statement

Echo's MVP GDDs already define many signal contracts:

- Scene lifecycle: `scene_will_change()` and `scene_post_loaded(anchor, limits)`.
- Damage lifecycle: `lethal_hit_detected`, `player_hit_lethal`, `death_committed`, boss phase/kill signals, and per-HurtBox `hurtbox_hit`.
- Time Rewind lifecycle: `rewind_started`, `rewind_completed`, `rewind_protection_ended`, `token_consumed`, and `token_replenished`.
- Weapon feedback: `weapon_equipped`, `shot_fired(direction)`, and `weapon_fallback_activated`.
- State machines: `state_changed(from_state, to_state)`.
- Presentation observers: Camera, HUD, VFX, and Audio consume subsets of those signals.

The current architecture registry records these as GDD-owned contracts, but implementation still needs one Foundation ADR that answers:

1. Is Tier 1 using direct typed Godot signals or a global event bus?
2. What determines same-frame event order when multiple systems emit signals in one physics tick?
3. Which direct method calls are allowed despite the signal-first architecture?
4. What are observers allowed to do when consuming gameplay signals?
5. How do new signals get added without creating circular dependencies or silent order drift?

This ADR locks the cross-system event model before coding starts.

### Constraints

- Godot 4.6 / GDScript, statically typed.
- Single-player, local-only Tier 1; no network replication or RPC ordering requirements.
- Pillar 2 determinism: same input sequence and same encounter seed must produce the same gameplay event order on the dev machine.
- ADR-0003 already locks gameplay physics priority ordering: Player/Weapon at priority 0, TRC at 1, Damage at 2, enemies/boss at 10, projectiles at 20, Camera at 30.
- ADR-0004 already locks SceneManager as the sole raw scene lifecycle owner.
- No global event bus exists in Tier 1.
- GDScript deprecated APIs forbid string-based `connect()` and favor Callable-style typed signal connections.
- Presentation systems may consume signals but must not become gameplay authorities.

### Requirements

- **R-EVT-01**: Tier 1 cross-system events use producer-owned typed Godot signals, not a global event bus.
- **R-EVT-02**: Signal signatures are owned by the producer GDD/ADR and mirrored in `docs/registry/architecture.yaml`.
- **R-EVT-03**: Every gameplay-affecting signal must define at least one of: source priority, intra-producer emit order, or explicit connection-order requirement.
- **R-EVT-04**: Same-signal multiple-consumer order is deterministic only when the producer or host wiring section explicitly declares connection order; otherwise consumers must not depend on order.
- **R-EVT-05**: `CONNECT_DEFAULT` is required for gameplay signals unless an ADR/GDD explicitly marks a presentation-only deferred delivery.
- **R-EVT-06**: Observers may read payloads and public owner APIs, spawn presentation-only output, or cache local presentation state; they may not mutate gameplay state.
- **R-EVT-07**: Cross-entity state machine transitions use signals; one entity's SM may not call another entity's `transition_to`.
- **R-EVT-08**: Direct calls are allowed only for small owner APIs explicitly listed in this ADR or a later accepted ADR.
- **R-EVT-09**: New signal contracts require a reciprocal update to the source GDD, dependent GDDs, tests, and registry candidates.
- **R-EVT-10**: Same-frame conflict outcomes that matter to gameplay must be specified in the source GDD and tested.

## Decision

Use **direct producer-owned typed Godot signals for Tier 1 cross-system events**, with explicit same-frame ordering rules layered on top of ADR-0003's physics priority ladder. Do **not** introduce a global event bus in Tier 1.

### Event Architecture Diagram

```text
Gameplay owner emits typed signal
  Damage / TimeRewindController / SceneManager / WeaponSlot / StateMachine
        │
        ▼
Explicit Callable-style connections
  signal.connect(receiver_method) using CONNECT_DEFAULT
        │
        ▼
Receivers react inside their ownership boundary
  - gameplay owner receivers may transition their own state or call approved owner APIs
  - presentation observers may render / play / display only
        │
        ▼
Ordering evidence
  - source priority from ADR-0003 where applicable
  - producer-local emit order table
  - host wiring connection-order test
  - static grep for forbidden direct calls / event bus / deprecated connect
```

### Ordering Model

Event order is determined by the following layers, in priority order:

1. **Producer-local emit order**: if one producer emits multiple signals in one call stack, the source GDD/ADR owns the sequence. Example: Damage emits `lethal_hit_detected(cause)` before `player_hit_lethal(cause)`.
2. **Same-signal connection order**: if multiple receivers connect to the same signal and the order matters, the host wiring section must declare connection order and tests must verify it using `get_signal_connection_list()`.
3. **Inter-producer same-tick order**: if multiple producers can emit in one physics tick, ADR-0003 `process_physics_priority` determines `_physics_process`-originated order. If the event originates from a Godot physics callback such as `Area2D.area_entered`, the owning source GDD must normalize the callback into a producer-local emit order before other systems depend on it.
4. **Presentation observer tie-break**: if multiple observer-only signals arrive in one tick, observers process them in received order. They must not sort by screen position, dictionary key, distance, or random priority unless their GDD defines that as presentation-only and non-gameplay-affecting.
5. **Undefined order is unusable for gameplay**: if none of the above layers defines order, gameplay code must not rely on that order.

### Canonical Tier 1 Signal Families

| Contract | Producer | Pattern | Ordering Rule |
|----------|----------|---------|---------------|
| `scene_lifecycle` | SceneManager | Signal | ADR-0004 owns phase order. `scene_will_change()` before raw scene swap; `scene_post_loaded(anchor, limits)` after anchor/limits registration. |
| `damage_signals` | Damage / per-host damage handlers | Signal | Damage GDD owns same-frame emit order and connect-order obligations. |
| `rewind_lifecycle` | TimeRewindController | Signal | TRC Rule 9 owns token consume → restore → `rewind_completed` sequence; protection end is separate. |
| `state_lifecycle` | Any StateMachine instance | Signal | `transition_to()` atomic sequence emits `state_changed` after exit/enter and state assignment. |
| `weapon_slot_signals` | WeaponSlot | Signal | `shot_fired(direction)` only emits after projectile spawn succeeds; boot `weapon_equipped` may use deferred delivery because it is a wiring-completion notification, not a gameplay decision. |
| `camera_shake_events` | Multi-source: WeaponSlot + Damage | Signal grouping | Camera consumes incoming source order; shake amplitudes are Camera-owned and clamped locally. |

### Key Interfaces

```gdscript
# Callable-style connection only for gameplay signals
damage.lethal_hit_detected.connect(trc._on_lethal_hit_detected)
damage.player_hit_lethal.connect(echo_lifecycle_sm._on_player_hit_lethal)
trc.rewind_started.connect(echo_lifecycle_sm._on_rewind_started)
scene_manager.scene_will_change.connect(trc._buffer_invalidate)

# Deprecated / banned
damage.connect("player_hit_lethal", echo_lifecycle_sm, "_on_player_hit_lethal")
event_bus.emit("player_hit_lethal", cause)
call_deferred("_on_player_hit_lethal", cause) # banned for gameplay events unless explicitly presentation-only
```

### Allowed Direct Calls

Signals are the default cross-system notification pattern, but the following direct calls are explicitly allowed because they target owner APIs and are already GDD-owned:

| Caller | Callee | Method | Reason |
|--------|--------|--------|--------|
| EchoLifecycleSM / DyingState | TimeRewindController | `try_consume_rewind() -> bool` | Rewind decision must return success/failure synchronously inside the DYING input window. |
| EchoLifecycleSM / DyingState | Damage | `commit_death() -> void` | Damage owns pending cause and emits `death_committed`; SM owns grace expiry timing. |
| EchoLifecycleSM / RewindingState | Damage | `cancel_pending_death() -> void` | Rewind retracts pending death without Damage polling SM state. |
| EchoLifecycleSM / RewindingState | Damage | `start_hazard_grace() -> void` | Hazard-only grace begins at SM-controlled i-frame exit. |
| TimeRewindController | PlayerMovement | `restore_from_snapshot(snap: PlayerSnapshot) -> void` | ADR-0002 single legitimate restoration path for PM-owned fields. |
| TimeRewindController | WeaponSlot | `restore_from_snapshot(snap: PlayerSnapshot) -> void` | ADR-0002 Amendment 2 / Player Shooting #7 locks Weapon-owned ammo restoration by TRC orchestration, not signal subscription. |
| PauseHandler | EchoLifecycleSM | `can_pause() -> bool` / `should_swallow_pause() -> bool` | Pause initiation needs synchronous veto; Menu/Pause remains UI-only. |
| HUD | TimeRewindController | `get_remaining_tokens() -> int` | Read-only initialization of token display. |

Any new direct call across systems must be added through a GDD revision or ADR and must specify why a signal cannot satisfy the requirement.

### Observer Boundary

Camera, HUD, VFX, Audio, Story Intro, and Menu/Pause UI are observers or presentation owners unless their own GDD explicitly says otherwise.

They may:

- connect to approved signals;
- read public owner APIs or payloads;
- spawn presentation-only nodes;
- play approved audio through AudioManager;
- cache local presentation state;
- clear local presentation state on scene boundary.

They must not:

- grant/consume rewind tokens;
- call `transition_to()` on a foreign StateMachine;
- write PlayerMovement, WeaponSlot, Damage, Boss, Stage, or TRC gameplay state;
- change scenes directly;
- add gameplay `Area2D` hit checks;
- change the source signal order;
- sort same-frame gameplay events into a new order.

### Signal Addition Protocol

Adding or changing a cross-system signal requires all of the following:

1. Update the producer GDD signal catalog with the exact typed signature.
2. Add or update downstream consumer rows in dependent GDDs.
3. Specify producer-local emit order if multiple signals can fire in one call stack.
4. Specify same-signal connect order only if consumers depend on it.
5. Add or update `docs/registry/architecture.yaml` candidates after explicit approval.
6. Add unit/integration tests for emit cardinality, handler arity, and deterministic order.
7. Add static grep checks if the contract bans an alternative pattern.

### Registry Candidates

`docs/registry/architecture.yaml` is not updated by this ADR draft without explicit approval. If approved, the registry should mirror this decision with candidates equivalent to:

- `decisions.event_architecture_tier1`: direct producer-owned typed Godot signals; no global gameplay event bus.
- `decisions.event_ordering_model`: producer-local emit order, then declared same-signal connection order, then ADR-0003 physics priority for `_physics_process` producers, with undefined order banned for gameplay decisions.
- `forbidden_patterns.global_gameplay_event_bus`: bans `EventBus`, `event_bus`, generic gameplay `emit_event`, and topic-string/Dictionary payload routing for Tier 1 gameplay.
- `forbidden_patterns.deferred_gameplay_signal_delivery`: bans `call_deferred` / deferred connections for gameplay-critical events except explicitly approved presentation-only or boot notification carve-outs.
- `forbidden_patterns.observer_gameplay_state_mutation`: reinforces Camera/HUD/VFX/Audio observer-only boundaries.
- `forbidden_patterns.string_based_signal_connect`: reinforces deprecated `connect("signal", obj, "method")` ban.
- `interfaces.*.referenced_by`: add this ADR to `scene_lifecycle`, `damage_signals`, `rewind_lifecycle`, `state_lifecycle`, `weapon_slot_signals`, and `camera_shake_events`.
- `interfaces.damage_signals.emit_ordering_contract`: mirror `design/gdd/damage.md` F.4.1 by recording `HurtBox.hurtbox_hit` as the preceding source emit, followed by Damage `_pending_cause set -> lethal_hit_detected -> player_hit_lethal`.

## Alternatives Considered

### Alternative 1: Direct Producer-Owned Typed Signals (Selected)

- **Description**: Keep Tier 1 on Godot typed signals with producer-owned signatures and explicit ordering contracts.
- **Pros**:
  - Matches current GDD and registry contracts.
  - Minimal solo-team infrastructure.
  - Easy to test producer emit order and connection order.
  - Keeps ownership visible: the producer owns the event, each consumer owns its reaction.
  - Avoids premature abstraction before Tier 1 proves the loop.
- **Cons**:
  - Requires discipline when adding consumers; connect order can drift.
  - Cross-GDD reciprocal updates are mandatory.
  - No central event history unless debug tooling subscribes separately.
- **Selection Reason**: Smallest architecture that preserves determinism, readability, and current GDD intent.

### Alternative 2: Global Event Bus

- **Description**: All systems publish events to an autoload bus; subscribers register to named topics.
- **Pros**:
  - Central event log is easier to inspect.
  - New subscribers can attach without direct producer references.
  - Future analytics/debug tooling could be unified.
- **Cons**:
  - Adds global mutable routing before Tier 1 needs it.
  - Topic strings or generic payloads weaken typed signature safety.
  - Same-frame ordering becomes bus-policy-dependent instead of source-owned.
  - Makes the scene and damage critical paths harder to reason about.
- **Rejection Reason**: Premature and riskier for deterministic one-hit gameplay. Reconsider only at a Tier 2 instrumentation/event-log gate.

### Alternative 3: Direct Method Calls for All Cross-System Communication

- **Description**: Systems call each other directly instead of emitting signals.
- **Pros**:
  - Synchronous call order is obvious in one call stack.
  - Easy to return values.
- **Cons**:
  - Creates circular dependencies and foreign state authority.
  - Breaks cross-entity StateMachine boundaries.
  - Presentation systems become easy to accidentally turn into gameplay writers.
  - Hard to add multiple observers without producer bloat.
- **Rejection Reason**: Violates `cross_entity_sm_transition_call`, observer boundaries, and the existing GDD signal catalog. Keep only explicitly approved owner API calls.

### Alternative 4: Deferred / Queued Event Queue

- **Description**: Queue events and drain them at a fixed end-of-frame or next-frame phase.
- **Pros**:
  - Can batch events and avoid re-entrant signal chains.
  - Debug replay logs are straightforward.
- **Cons**:
  - Adds one-frame latency to deaths, rewinds, scene boundaries, and camera snap unless heavily special-cased.
  - Violates Damage/SM/TRC same-frame contracts.
  - Makes `scene_will_change()` too late for old-scene node cleanup if deferred incorrectly.
- **Rejection Reason**: Tier 1 relies on same-tick signal handling for lethal-hit cache, rewind consume, and scene boundary invalidation.

## Consequences

### Positive

- Locks "no global event bus in Tier 1" as an architecture decision.
- Preserves typed signal safety and producer-owned signature authority.
- Gives QA clear ordering tests: emit order, connection order, priority order, observer-only side effects.
- Keeps Camera/HUD/VFX/Audio as observer systems.
- Protects one-hit/death/rewind same-frame interactions from accidental reordering.
- Defines the exact path for adding new signals without design drift.

### Negative

- Requires more cross-doc discipline when adding consumers.
- Connection order becomes an explicitly tested artifact where relied upon.
- Debug event history is decentralized unless a future debug overlay subscribes to the same signals.
- Deferred boot notifications such as `weapon_equipped.emit.call_deferred` require clear carve-outs so implementers do not copy deferred delivery into gameplay-critical events.

### Risks

- **Godot 4.6 connect-order assumption**: mitigate with direct fixture tests using `get_signal_connection_list()` and 1000-run repeat checks.
- **Observer authority creep**: mitigate with static grep for gameplay writes in HUD/VFX/Audio/Camera modules and code-review checklists.
- **Signal arity drift**: mitigate with typed handler tests and registry signature mirror.
- **Same-frame ambiguity between producers**: mitigate by requiring source GDDs to define conflict outcomes before implementation.
- **Event bus reintroduced ad hoc**: mitigate with grep for `EventBus`, `event_bus`, generic `emit_event`, and Dictionary payload topics in gameplay code.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/scene-manager.md` | `scene_will_change()` emits exactly once before scene swap. | Treats scene lifecycle as producer-owned typed signals and defers scene-specific timing to ADR-0004. |
| `design/gdd/state-machine.md` | Cross-entity transitions use signals, never direct foreign SM calls. | Locks signal-mediated cross-entity SM rule and preserves `cross_entity_sm_transition_call` ban. |
| `design/gdd/player-shooting.md` | `shot_fired(direction)` is public event for VFX/audio/camera feedback. | Keeps `shot_fired(direction: int)` as WeaponSlot-owned signal; downstream systems own their own reactions. |
| `design/gdd/damage.md` | Damage emits lethal/boss/enemy signals in deterministic order. | Elevates Damage F.4.1 emit ordering into architecture-level event-order policy. |
| `design/gdd/time-rewind.md` | TRC signals drive rewind lifecycle while direct restore calls remain owner APIs. | Distinguishes typed notifications from allowed synchronous owner API calls. |
| `design/gdd/camera.md` | Camera consumes scene/damage/weapon/rewind events for snap, limits, freeze, and shake. | Classifies Camera as an observer; it may react but not reorder or mutate gameplay state. |
| `design/gdd/hud.md` | HUD is observer-only CanvasLayer and never mutates simulation state. | Locks observer boundary for HUD token, prompt, ammo, and boss phase displays. |
| `design/gdd/vfx-particle.md` | VFX owns presentation-only effects and must follow source signal order. | Locks presentation-only authority and received-order processing. |
| `design/gdd/audio.md` | AudioManager owns sound playback; gameplay emits events only. | Keeps Audio as playback owner and prevents gameplay systems from raw bus control. |
| `docs/architecture/architecture.md` | Event/signal architecture needs ADR before coding. | Provides the Foundation ADR covering TR-scene-002, TR-state-002, TR-ps-002, TR-damage-002, and TR-camera-002. |

## Performance Implications

- **CPU**: Direct Godot signals have minimal per-event overhead for Tier 1 event volume. Avoiding an event bus prevents per-frame topic dispatch or Dictionary payload churn.
- **Memory**: No central event queue or log is allocated in production Tier 1. Debug-only event history may be added later as a separate tool.
- **Load Time**: No impact.
- **Network**: None; single-player local game. If networking is introduced later, this ADR must be superseded for replication/event authority.

## Migration Plan

No production implementation exists yet. Implementation should proceed as follows after ADR acceptance:

1. Create a signal contract checklist from `docs/registry/architecture.yaml`.
2. Implement producer signals using typed declarations and Callable-style connections.
3. Implement host wiring in declared order for Damage/TRC/SM/SceneManager critical paths.
4. Add GUT fixtures for signal arity, connection flags, connection order, and repeated-run determinism.
5. Add static checks for string-based connect, global event bus names, forbidden direct `transition_to`, raw scene swaps outside SceneManager, and observer gameplay writes.
6. Add source-GDD reciprocal update checks to architecture review so any signal signature change fails until consumers are updated.
7. Leave global event-log tooling as debug-only future work; do not introduce a runtime event bus.

## Validation Criteria

This decision is correct if the following pass:

- `test_damage_emit_order_echo_hurtbox_hit`
- `test_damage_boss_emit_order_phase_and_kill`
- `test_echo_lifecycle_connect_order_and_flags`
- `test_signal_handler_invocation_order_1000_runs`
- `test_rewind_consume_restore_emit_sequence`
- `test_scene_will_change_precedes_scene_swap`
- `test_observers_do_not_mutate_gameplay_state_static`
- `test_no_global_event_bus_in_gameplay_static`
- `test_no_string_based_connect_static`
- `test_no_cross_entity_sm_transition_call_static`
- `test_no_raw_scene_swap_outside_scene_manager_static`
- `test_camera_vfx_hud_audio_received_order_observer_reactions`

## Related Decisions

- `docs/architecture/adr-0001-time-rewind-scope.md` — Time Rewind signal family and player-only scope.
- `docs/architecture/adr-0002-time-rewind-storage-format.md` — Direct snapshot restore owner APIs.
- `docs/architecture/adr-0003-determinism-strategy.md` — Physics priority ladder and deterministic clock.
- `docs/architecture/adr-0004-scene-lifecycle-and-checkpoint-restart-architecture.md` — Scene lifecycle signal timing.
- `docs/registry/architecture.yaml` — current GDD-owned interface contracts and forbidden patterns.
- `design/gdd/damage.md`
- `design/gdd/state-machine.md`
- `design/gdd/time-rewind.md`
- `design/gdd/player-shooting.md`
- `design/gdd/camera.md`
- `design/gdd/hud.md`
- `design/gdd/vfx-particle.md`
- `design/gdd/audio.md`
