# Godot Animation — Quick Reference

Last verified: 2026-02-12 | Engine: Godot 4.6

## What Changed Since ~4.3 (LLM Cutoff)

### 4.6 Changes
- **IK system fully restored**: Complete inverse kinematics for 3D skeletons
  - CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK
  - Applied via `SkeletonModifier3D` nodes (not the old IK approach)
- **Animation editor QoL**: Solo/hide/lock/delete for Bezier node groups; draggable timeline

### 4.5 Changes
- **BoneConstraint3D**: Bind bones to other bones with modifiers
  - `AimModifier3D`, `CopyTransformModifier3D`, `ConvertTransformModifier3D`

### 4.3 Changes (in training data)
- **AnimationMixer**: Base class for both AnimationPlayer and AnimationTree
  - `method_call_mode` → `callback_mode_method`
  - `playback_active` → `active`
  - `bone_pose_updated` signal → `skeleton_updated`
- **`Skeleton3D.add_bone()`**: Now returns `int32` (was `void`)

## Critical Default — `callback_mode_method` (verified 2026-05-11 vs PM #6 B3)

| Property | Default value | Source |
|----------|---------------|--------|
| `AnimationMixer.callback_mode_method` | `ANIMATION_CALLBACK_MODE_METHOD_DEFERRED` (0) | https://docs.godotengine.org/en/stable/classes/class_animationmixer.html |

**Mode semantics (verbatim from docs):**
- DEFERRED (0, default): "Batch method calls during the animation process, then do the calls after events are processed."
- IMMEDIATE (1): "Make method calls immediately when reached in the animation."

**Implication for time-rewind / snapshot-restore projects:**

When using a `_is_restoring` boolean guard pattern (set guard true before
`seek()`, clear guard after), method-track callbacks DO NOT fire under the
guard if `callback_mode_method` is left at the DEFERRED default. The deferred
calls run via `call_deferred`-style semantics — *after* the current frame's
events finish — so by the time the callback executes, the guard is already
cleared and the callback fires anyway.

**Required pattern for any system that relies on `_is_restoring`-style
suppression of animation method-track side-effects (audio cues, VFX spawns,
bullet emissions):**

```gdscript
@onready var anim_player: AnimationPlayer = %AnimationPlayer

func _ready() -> void:
    # MUST override the DEFERRED default for snapshot-restore guard to work
    anim_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
```

Without this override, the guard model is silently broken in production but
passes most unit tests because GUT often runs without a full main loop tick
between the seek and the assertion.

**Boot-time assert recommended** to make the requirement self-enforcing:

```gdscript
assert(anim_player.callback_mode_method == AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE,
    "PlayerMovement requires IMMEDIATE callback mode for _is_restoring guard")
```

**Cross-reference:** `design/gdd/player-movement.md` C.4.1/4.2/4.4 + VA.5 +
new AC-H1-NEW (boot assert).

## Current API Patterns

### AnimationPlayer (unchanged API, new base class)
```gdscript
@onready var anim_player: AnimationPlayer = %AnimationPlayer

func play_attack() -> void:
    anim_player.play(&"attack")
    await anim_player.animation_finished
```

### IK Setup (4.6 — NEW)
```gdscript
# Add SkeletonModifier3D-based IK nodes as children of Skeleton3D
# Available types:
# - SkeletonModifier3D (base)
# - TwoBoneIK (arms, legs)
# - FABRIK (chains, tentacles)
# - CCDIK (tails, spines)
# - Jacobian IK (complex multi-joint)
# - Spline IK (along curves)

# Configure in editor or code:
# 1. Add IK modifier node as child of Skeleton3D
# 2. Set target bone and tip bone
# 3. Add a Marker3D as the IK target
# 4. IK solver runs automatically each frame
```

### BoneConstraint3D (4.5 — NEW)
```gdscript
# Add as child of Skeleton3D
# Types:
# - AimModifier3D: Point bone at target
# - CopyTransformModifier3D: Mirror another bone's transform
# - ConvertTransformModifier3D: Remap transform values
```

### AnimationTree (base class changed in 4.3)
```gdscript
# AnimationTree now extends AnimationMixer (not Node directly)
# Use AnimationMixer properties:
@onready var anim_tree: AnimationTree = %AnimationTree

func _ready() -> void:
    anim_tree.active = true  # NOT playback_active (deprecated 4.3)
```

## Common Mistakes
- Using `playback_active` instead of `active` (deprecated since 4.3)
- Using `bone_pose_updated` signal instead of `skeleton_updated` (renamed in 4.3)
- Using old IK approach instead of SkeletonModifier3D system (restored in 4.6)
- Not checking `is AnimationMixer` when type-checking animation nodes
