---
title: Echo Art Bible
status: Draft (Tier 1 — v0 production-ready)
created: 2026-05-09
updated: 2026-05-09
project: Echo (working title)
engine: Godot 4.6 / GDScript
visual_anchor: Collage SF — 1990s magazine cutouts + 2030s megacity photography
related:
  - design/gdd/game-concept.md
  - .claude/docs/technical-preferences.md
  - wiki/concepts/Echo Story Spine.md
---

# Echo — Art Bible

> **Visual Identity Anchor (locked)**: "Every screen in this game looks like 1990s magazine cutouts collaged with 2030s megacity photography."
>
> **Art Director Sign-Off (AD-ART-BIBLE)**: SKIPPED — Lean mode (per `production/review-mode.txt`).
> Re-run with `--review full` if AAA-level director gate is needed before production.
>
> **Open Questions (block first concept-art round):**
> - **Q2** — Collage photo sources (stock / AI-generated / original photography) → decided after IP/license review
> - **Q5** — ECHO gender explicit vs. code name retained → decided after first concept-art round
>
> **v0 Note:** All color hex values are starting points and will be finalized after the first concept-art round (at `/asset-spec` time).

---

## 1. Visual Identity Statement

This section is the top-level contract that locks Echo's visual identity principles. It serves as the reference point for all subsequent art decisions.

**Locked Declaration (2026-05-09 lock-in):**

> "Every screen in this game looks like 1990s magazine cutouts collaged with 2030s megacity photography."

This declaration is a non-negotiable standard. Any asset that violates this principle is rejected.

---

### Principle A — Clarity-First Collage

**Supporting Pillar: Pillar 2 — Deterministic patterns, luck is the enemy**

Collage textures and layers are concentrated on backgrounds, bosses, and UI frames. The player character (ECHO) and all enemy characters maintain simple silhouettes and clear color contrast. The moment complex collage patterns intrude on character silhouettes, the Pillar 2 test fails.

**Design Test:** At 1080p resolution, can you distinguish the player, enemies, and bullets individually with a 0.2-second glance at a screenshot taken at real gameplay speed? "YES" or revise the asset.

**Violation Patterns (forbidden):**
- Enemy silhouettes with a similar hue to the magenta advertisement texture in the background
- Photo texture overlay on drone outlines → unreadable shape
- Bullet color identical to background neon color (indistinguishable)

---

### Principle B — Photo + Drawing Always Together

**Supporting Pillar: Pillar 3 — Collage is the first impression, screenshot = marketing**

Using only photography looks like a realism simulator. Using only drawing gets classified as a Pizza Tower clone. Echo's signature is the mixture itself — Hannah Höch-style photo cutouts with pen line drawings on top, and hand-lettering layered over that.

**Design Test:** Looking at one Steam capsule image and one screenshot, can you see both "photo texture" and "drawing lines" simultaneously? If either disappears from a marketing image, Principle B is violated.

**Layer Structure (applies to all scenes):**
1. Base: Photo texture background (megacity photography or AI-generated stock — pipeline finalized after Q2 decision)
2. Mid: Hand-drawn line-art characters/objects
3. Top: Magazine cutout typography, advertisement fragments, color flat shapes

---

### Principle C — Time-Rewind = Color Inversion + Glitch

**Supporting Pillar: Pillar 1 — Time rewind is a learning tool, not punishment**

REWIND Core activation must be immediately recognizable visually. The moment the mechanic fires, the entire screen color-inverts (cyan/magenta dominant) and collage textures decompose into glitch patterns. This is the visual confirmation of the "learning tool" — emphasizing the *recovery moment* rather than the death moment.

**Design Test:** Can you recognize REWIND Core activation within 0.5 seconds by looking at the screen alone? Is the activation effect distinguishable from background art?

**Activation Sequence (technical specs delegated to technical-artist):**
- Frame 0: Normal palette
- Frame 1-3: Full-screen cyan/magenta color inversion (shader)
- Frame 4-8: Collage layer glitch decomposition (UV distortion pattern)
- Frame 9-18: Reverse-playback animation + palette restoration

**REWINDING 30-frame i-frame visual rule (ABA-3 amendment 2026-05-11 — `player-movement.md` VA.3 single source of truth):**

For 30 frames immediately after restoration, ECHO is invincible but must visually signal *alive*. Since the color inversion shader may run concurrently, a **shape signal, not color** is the single source of truth.

- **Mechanism**: `Sprite2D.visible` **2:1 toggle** — `visible=true 2 frames / visible=false 1 frame` repeat (30 frames = 10 pulses = ~20 Hz)
- **Ownership**: `player-movement.md` PM side — driven from `EchoLifecycleSM.RewindingState._physics_update()`, NOT AnimationPlayer (avoids `seek()` interaction)
- **Color channel forbidden**: Expressing i-frames via color change/tinting conflicts with the REWIND shader color inversion pass → identification failure. Shape channel (visibility) only
- **Multi-channel safety net** (consistent with Section 4 backup #4): shape (visibility) + audio (rewind_protection_ended) + screen-shake (TR side) — 3-channel redundancy

> **DYING flicker (see ABA-4)** and **REWINDING i-frame flicker (this rule)** are *separate events* — different cadences (DYING 1:1 30 Hz vs REWINDING 2:1 20 Hz) and different owners (DYING REWIND Core glow only / REWINDING full sprite visibility). Do not confuse.

---

## 2. Mood & Atmosphere

This section specifies the emotional goals and visual atmosphere for each game state to ensure consistency across scenes.

| Game State | Emotional Goal | Lighting Characteristics | Atmosphere Adjectives | Energy Level | Key Visual Elements |
|---|---|---|---|---|---|
| **Combat** | Tension, focus, immediate response | Strong backlight, sharp shadows, neon flicker | Sharp / Urgent / Cold / Threatening | Maximum (9/10) | Drone silhouettes cut out against neon cyan backlight in a collage composition |
| **Exploration** | Curiosity, alertness, quiet tension | Ambient light dominant, soft magenta billboard reflections | Desolate / Surveilled / Empty / Urban | Medium (5/10) | Building walls engraved with VEIL surveillance camera icons, faded ARCA billboards |
| **Boss Reveal** | Awe, threat, overwhelming presence | Single powerful light source (boss core glow), surrounding darkness | Overwhelming / Massive / Cold / Mechanical | Rising fast (7→10) | Boss silhouette fills the screen on entry, surrounding collage layers fragment |
| **Time-Rewind Active** | Relief, disorientation, rapid reorientation | Full-screen cyan/magenta inversion, no light source | Surreal / Decomposing / Paradoxical / Urgent | Instant burst (10/10, 0.5 sec) | Full-screen color inversion + collage texture glitch fragments |
| **DYING (12-frame grace period after hit) (ABA-4 amendment 2026-05-11)** | Urgent reversal anticipation — "I can undo this, *now*" | No full-screen effect; ECHO character local only (Section 1 Principle A — readability first) | Tense / Frozen / Decision imminent / Recognizable | Instant maximum (10/10, 0.2 sec — 12 frames @ 60 fps) | **Hit-stagger pose held (not collapse)** + **REWIND Core glow 1:1 flicker** (`visible=true 1f / false 1f` toggle, 6 pulses = 30 Hz — `player-movement.md` VA.2 Dead row B6 fix 2026-05-11 single source; ≥4 Hz "intentional pulse" perception threshold distinguishes from engine hitch); no whiteout (deferred until DEAD stage progression); audio = `sfx_dying_pending_01.ogg` synth filter sweep 80→400 Hz over 200 ms (`time-rewind.md` Audio Events DYING entry — 1:1 envelope match) |
| **Death & Restart** | Immediate acceptance, desire to retry | 1-frame whiteout → immediate scene restoration | Crisp / Neutral / Immediate | Instant 0 → combat level | White flash 1 frame (no complex death animation — Pillar 1: <1 second restart absolute requirement) |
| **Menu/HUD** | Brand recognition, navigation clarity | Flat / unlit | Structured / Clear / Collage | Low (3/10) | Magazine cutout typography frame, concrete gray background with cyan highlights |
| **Story Intro Text** | Atmospheric immersion, worldbuilding absorption | Near darkness, single text light source | Grim / Restrained / Cold / Definitive | Lowest (2/10) | Typewriter-style typography over magazine cutout photo background, VEIL surveillance icon watermark |

**Common Lighting Rules:**
- Exterior (rooftop): Top backlight + urban neon reflected light. No natural light — 2038 NEXUS has direct sunlight blocked by a smog layer
- Interior (data center): Fluorescent flicker + server glow (green/cyan cold light)
- Darkness baseline: Not full black but concrete gray (#1A1A1E) — collage textures maintain presence even in darkness

---

## 3. Shape Language

This section defines the shape vocabulary for all visual elements in the game so that characters, environments, and UI share a single visual language.

### ECHO (Player Character) Silhouette Philosophy

**Supporting Pillars: Pillar 2 + Pillar 3**

ECHO has a sleek vertical silhouette. A helmet or mask covers the entire face, concealing gender (Q5 — ECHO gender undetermined). Core silhouette shapes: narrow shoulders, long leg proportions, REWIND Core device attached to the back (distinctive rectangular protrusion). Line-art favors angular broken lines over organic curves — the feel of a photo cutout cut with scissors.

**Sprite Specifications (ABA-1 amendment 2026-05-11 — `player-movement.md` VA.6 single source of truth):**
- **Character visual height**: 48px (at 1080p; consistent with Section 5 ECHO Visual Archetype table)
- **Sprite cell size**: **48×96px** (cell space including REWIND Core and other protrusions; 8-way arm overlay is a separate 32×32px cell — see Section 5 ABA-2)
- **Atlas placement**: `atlas_chars_tier1.png` 512×512 (Section 8 table — 17 body frames + 8 arm frames = 25 frames total Tier 1; ECHO single character)

**Thumbnail Readability Test (Pillar 2):**
- When scaled down to 32×32px, can you distinguish the head, torso, and weapon individually?
- Is ECHO's silhouette not confused with any of the three enemy archetypes?

**Q5 Application Rule:** All rules in the character direction section are about silhouette, proportion, and equipment. Face shape, hair, and voice tone remain undecided in this document. Visual gender cues are blocked by the helmet/mask.

---

### Enemy Archetype Silhouette Differentiation Rules

**Supporting Pillar: Pillar 2 — Guaranteed 0.2-second glance differentiation**

| Archetype | Dominant Shape | Distinguishing Feature | Size Ratio (vs. ECHO) | Forbidden Shapes |
|---|---|---|---|---|
| **Drone** | Circle/Ellipse — soft and fast feeling | Rotating blade silhouette, 2 glowing eyes, circular body | 0.3x (small) | Rectangular body (confused with boss) |
| **Security Bot** | Rectangle/Straight lines — heavy and threatening | Wide rectangular body, turret form without arms, track movement | 1.5x (large) | Circular elements, blade-like parts |
| **Mini-Boss (STRIDER — Tier 1)** | Inverted triangle — dominant and aggressive | Large drone platform descending from top of screen, 4 turrets, central core glow | 3-4x (1/3 of full screen width) | Vertical lines similar to ECHO |

**Shape Contrast Principle (Gestalt — Figure-Ground):**
- Small enemies (drone): Circular silhouette pops out against rectangular background buildings
- Large enemies (Security Bot): Straight-line grid contrasting with ECHO's organic lines
- Boss: Inverted triangle composition filling the screen frame — psychologically pressures the player

---

### Environment Shape Language — NEXUS Megacity

**Dominant Shape: Vertical straight lines + repeating grid (Corporate Brutalism)**

NEXUS buildings are all vertical blocks — no curves or organic forms. However, the advertisements, graffiti, and cutout fragments covering them introduce diagonals, irregular cuts, and circles. This contrast visualizes "human chaos over a controlled city."

- **Building base form:** Vertical rectangles, repeating window grids
- **Billboards:** Irregular rectangles + diagonal cutout layers (borrowing 1990s magazine layout)
- **Roads/Platforms:** Horizontal straight lines, parallel to player movement — reinforces movement direction (Visual Hierarchy)
- **Background buildings:** Silhouette only (no photo texture) — clear mid-ground/foreground differentiation

---

### UI Shape Grammar

- **Buttons/Panels:** Irregularly clipped corners (cutout aesthetic). Both full circles and full right angles are forbidden — the feel of being cut with scissors from a magazine
- **Icons:** Bold line (stroke ≥ 3px at 1080p) flat drawing. No photo texture — 0.2-second recognition first
- **Token Counter:** Circular badge — evokes drone shape (shape resonance with small in-game enemies)
- **Health Bar:** Segmented (no solid continuous bar — magazine cutout fragment structure)

---

### Hero vs. Supporting Shape Rules

- **Hero Objects (ECHO, weapons, tokens):** Sharp angular lines + high-saturation color outline → absorbs gaze first
- **Supporting Objects (backgrounds, platforms, props):** Low saturation + soft photo texture → lower visual priority
- **Hostile Objects (drones, Security Bots, bullets):** Red-family outline or glow + distinctive silhouette → immediate threat recognition

---

## 4. Color System

This section defines the color vocabulary for the entire game, specifying the meaning and usage of each color and accessibility handling.

### Primary Palette (v0 starting palette — finalized after first concept-art round)

| Role | Color Name | Hex | Meaning | Usage |
|---|---|---|---|---|
| **Base Neutral** | Concrete Dark | `#1A1A1E` | Control, suppression, corporate order | Background base, UI panel base |
| **Base Neutral 2** | Concrete Mid | `#3C3C44` | Infrastructure, middle-layer reality | Environment mid layer, inactive UI |
| **Main Signal** | Neon Cyan | `#00F5D4` | Freedom, REWIND Core energy, player | ECHO color outline, token UI, time-rewind glow |
| **Hostile Signal** | Ad Magenta | `#FF2D7F` | VEIL threat, advertising propaganda, danger | Enemy glow, VEIL UI elements, danger indicators |
| **Human Trace** | Vintage Yellow | `#F0C040` | Past, humanity, Sigma Unit memory | Collage cutout fragments, weapon pickups, select environmental props |
| **Decay Trace** | Sepia Brown | `#7A5C3A` | Age, memory, ARCA collapse | Old billboards, ARCA logo remnants, photo texture tint |
| **Time-Inversion Cyan** | Rewind Cyan | `#7FFFEE` | Time rewind activation (lighter version) | ECHO silhouette in color-inverted state, reverse-playback light source |

**Forbidden Color:** Fully saturated white (`#FFFFFF`) — permitted only once for the death flash whiteout. No pure white usage otherwise.

---

### Semantic Color Vocabulary

**When Cyan (Neon Cyan `#00F5D4`) is visible:**
- ECHO's presence, REWIND Core function, objects the player can use
- "This is on the player's side, this is related to time rewind"

**When Magenta (Ad Magenta `#FF2D7F`) is visible:**
- VEIL's control zone, enemy movement, danger area
- "This is death, this must be avoided"

**When Yellow (Vintage Yellow `#F0C040`) is visible:**
- Traces left by humans, pickup items, exploration rewards
- "This can be picked up, this is a memory"

**When wide areas of concrete gray are visible:**
- Background infrastructure, narratively neutral space
- "This can be passed through, it is VEIL's domain"

**When color inversion (cyan + magenta simultaneously) is visible:**
- REWIND Core activation — immediate visual recognition trigger
- "Time is being reversed right now" (Pillar 1)

---

### UI Palette

UI follows the world palette but with saturation reduced by 10%. The world takes visual priority over the UI.

| UI Element | Color | Hex | Notes |
|---|---|---|---|
| HUD background panel | Concrete Dark 40% transparent | `#1A1A1E99` | Semi-transparent — minimum obstruction of gameplay view |
| Active button | Neon Cyan | `#00F5D4` | Default interaction color |
| Danger/warning button | Ad Magenta | `#FF2D7F` | Cancel, danger confirmation |
| Inactive element | Concrete Mid | `#3C3C44` | Locked features, inactive menu items |
| Text (primary) | Off-white | `#E8E8E0` | Vintage feel instead of pure white |
| Text (secondary) | Concrete Mid | `#3C3C44` | Secondary information, description text |
| Token remaining | Neon Cyan (glow) | `#00F5D4` + glow | Highest visual priority |

---

### Color Blindness Safety Check

**Deuteranopia (red-green color blindness) risk pairs:**
- `Neon Cyan (#00F5D4)` + `Concrete Mid (#3C3C44)`: Sufficient brightness difference — relatively safe
- `Ad Magenta (#FF2D7F)` + `Vintage Yellow (#F0C040)`: Both colors may collapse into similar-brightness tan → risk

**Protanopia (red blindness) risk pairs:**
- `Ad Magenta (#FF2D7F)` used alone: When red component is lost, perceived as blue-gray → risk of losing VEIL threat signal

**Backup Guarantee Rules (covering all color blindness types):**

1. **Enemy bullets:** Ad Magenta outline + triangle/diamond shape (distinguishes from circular items). Not differentiated by color alone.
2. **VEIL danger zones:** Magenta color + grid pattern overlay. Recognizable by pattern even when color is removed.
3. **Token counter:** Cyan color + circular badge + numeric display. Any one of the three alone is sufficient to recognize remaining count.
4. **REWIND Core activation:** Color inversion + screen shake (0.3 seconds) + sound cue in combination (Anti-Pillar #4 response: implemented with Tier 1 CC0 sounds, not dependent on color signal alone).

---

## 5. Character Design Direction

This section defines the visual design standards for ECHO and the three enemy archetypes, and specifies resolutions achievable in solo development production.

### ECHO — Visual Archetype (Q5 gender undetermined applied)

**Silhouette and proportion rules (gender-neutral, valid for either interpretation):**

| Item | Specification | Rationale |
|---|---|---|
| Total height | Sprite 48px tall (at 1080p) | Security Bot 72px, Drone 16px — clear size hierarchy |
| Head:body:leg ratio | 1:2:2 | Action hero proportions — long legs = sense of speed |
| Face | Fully covered by front mask/helmet | No facial expression until Q5 resolved. REWIND Core status indicator on mask surface |
| Shoulders | Narrow and sharply angled | Contrasts with the wide shoulders of drones and Security Bots |
| Back device | REWIND Core (rectangular protrusion, cyan glow) | Unique feature that identifies ECHO in silhouette |
| Weapon | Clearly protruding to the right of the body | Direction recognizable even during 8-way aiming |
| **Facing visualization (ABA-2 amendment 2026-05-11)** | **`flip_h` body + 8-way arm overlay** — Contra-style modular cutout: body sprite 1 variant is the same (`char_echo_*`), left/right mirrored via `Sprite2D.flip_h`; arms (`char_echo_gunarm_*`) are 8 direction separate sprites (5 unique + 3 flip mirror) selected by facing_direction (`int 0..7 enum`, CCW from East — `player-movement.md` D.4 single source of truth) | Option C — `player-movement.md` Visual/Audio Section VA.1 2026-05-10 decision. Solo budget: 8 directions × 2 (L/R) = 16 full-body anims replaced by 5 arm unique + 3 flip = **62.5% asset reduction** + Pillar 5 (small wins). Arm overlay is z-order overlay above body; weapon change replaces arm only (Tier 2+) |
| Pose | Leaning 45 degrees forward during base movement | Conveys speed and purpose. Upright stance excluded |

**Expression/Pose Goal:** ECHO has no facial expression due to the mask. Emotion is conveyed through body language only — crouching when tense, momentary flicker backward when REWIND activates, knees bending to absorb impact on landing. Reference: Monty Python cutout animation — motion expressed through combinations of static poses.

**Art update scope when Q5 is resolved:** Helmet silhouette detail + 1 identity reveal cut (Tier 3 only). Sprite sheet itself changes minimally — reuse existing animation frames. Reduces solo production cost (Pillar 5).

---

### Enemy Archetypes — Distinguishing Feature Rules

**Drone (VEIL Reconnaissance Unit)**

| Item | Specification |
|---|---|
| Sprite size | 16×16px |
| Color theme | Magenta (`#FF2D7F`) glowing eyes, dark gray body |
| Unique feature | 2-4 propellers (rotating during movement), glowing eyes tracking ECHO |
| Movement pattern visualization | Zigzag + encirclement path — direction changes without movement telegraphing |
| Animation frames | 4 frames movement, 2 frames attack (solo production economy) |

**Security Bot (VEIL Ground Unit)**

| Item | Specification |
|---|---|
| Sprite size | 72×72px |
| Color theme | ARCA gray + magenta warning lights |
| Unique feature | Track movement, independent upper turret rotation, ARCA logo attached |
| Movement pattern visualization | Straight advance + stationary shooting — pattern clearly predictable (Pillar 2) |
| Animation frames | 4 frames movement, 2 frames firing, 3 frames destruction |

**Mini-Boss — STRIDER (Tier 1 Boss)**

| Item | Specification |
|---|---|
| Sprite size | 192×128px (dynamic scale in boss-exclusive scene) |
| Color theme | Dark metal + magenta core + 4 turret cyan targeting lines |
| Unique feature | Central core (destructible weak point glow), drone launch ports left and right, inverted triangle full silhouette |
| Boss pattern visualization | Core color changes per phase (magenta → orange → red) — health stage shown by color |
| Environmental storytelling | ARCA corporate logo + serial number sticker printed on body (collage aesthetic applied) |

---

### LOD (Level of Detail) Philosophy — 1080p Game Camera Distance

No 3D LOD applies since these are 2D sprites. Instead, **sprite resolution tiers** based on camera distance:

| Distance | Target | Resolution | Detail Level |
|---|---|---|---|
| Foreground (active in-screen play) | ECHO, small enemies, bullets | Reference resolution (specs above) | Full detail + frame animation |
| Midground (same room, inactive) | Security Bot idle state | Same sprite, color dumbed down | Color saturation -30%, brightness -15% |
| Background (background layer) | Background building silhouettes, drone swarms | 16px or smaller dot silhouettes | Shape only — no texture or line-art |

---

## 6. Environment Design Language

This section defines the spatial language and environmental storytelling vocabulary of the NEXUS megacity.

### NEXUS Megacity Architectural Style

**Core Style: Corporate Brutalism + Advertisement Overlay + Urban Decay**

Every building in NEXUS is an efficiency-optimized structure designed by ARCA — concrete straight lines, repeating grids, no human detail. However, two layers are added on top:

1. **ARCA Advertisement Layer**: Digital billboards and hologram ads placed at maximum efficiency by the VEIL optimization algorithm. Magenta + white palette. Bright and new-looking — this is "present domination."
2. **Human Decay Layer**: Graffiti sprayed over ARCA ads, faded paper, Sigma Unit memorial graffiti, torn posters. Yellow and brown palette. Old and irregular — this is "human resistance."

The conflict between these two layers is the environmental narrative of Stage 1 (rooftop).

---

### Texture Philosophy — Collage Layer Structure

All environment objects are composed as 3-layer composites:

**Layer 1 (Base): Photo Texture**
- Real concrete/metal photography or AI-generated stock (Q2: use grayscale placeholders until photo source is decided)
- Resolution: 128×128px tiles, repeat allowed
- Filter: Godot `TextureFilter.NEAREST` — no pixel interpolation, maintains collage edges

**Layer 2 (Character/Object): Hand-Drawn Line-Art**
- Black line (stroke 2-4px) vector style → raster output
- ECHO, enemies, and prop objects all on this layer
- Placed over photo texture — the feel of "a magazine illustration pasted onto a photo"

**Layer 3 (Collage Detail): Magazine Cutout Fragments**
- Advertisement typography fragments, geometric color blocks, VEIL/ARCA branding icons
- Stage 1 rooftop: includes ARCA billboard + Sigma Unit graffiti tags
- Replacing only this layer allows changing the stage atmosphere (solo production efficiency — Pillar 5)

---

### Prop Density Rules

| Stage Type | Density | Reason | Examples |
|---|---|---|---|
| **Rooftop (Tier 1)** | Low (5-8 props per screen) | Clarify movement paths, remove silhouette backgrounds | Water tank, VEIL antenna, billboard frame |
| **Data Center (Tier 2)** | High (15-20 props per screen) | Exploration complexity, hidden information | Server rack, cooling pipes, terminal, data fragments |
| **Maglev (Tier 2)** | Medium + motion (screen scroll) | Sense of speed, passing-through feel | Train cars, tunnel lighting, city panorama |
| **Corporate HQ (Tier 3)** | High + hierarchy | Place of power, decoration → enemy territory | Executive furniture, ARCA trophies, surveillance screens |
| **Orbital (Tier 3)** | Minimum (2-3 props per screen) | Isolation, disconnection, final battle | Server cluster units, space background |

---

### Environmental Storytelling Cues (Story Spine Integration)

Visual cues that tell the story without text in every scene:

**VEIL Surveillance Icon (repeating motif):**
- Style: Eye form without pupil inside a hexagon (collage magazine cut style)
- Placement: Minimum 2-3 on background buildings in every stage. Becomes clearer as camera gets closer
- Meaning conveyed: "You are always being watched"

**ARCA Branding Decay (progress visualization):**
- Stage 1: ARCA logo complete and shining (peak domination)
- Stage 2-3: Graffiti and tears layered over logo
- Stage 4-5: Logo overwritten by ECHO's REWIND Core mark
- Solo development application: Reuse the same billboard asset by replacing only the layer

**Sigma Unit Memorial Graffiti (traces of human resistance):**
- Style: Vintage yellow stencil spray → SIGMA Σ symbol
- Stage 1 rooftop only (found at ECHO's return point)
- Size: Small detail passing in the background — only attentive players notice

**VEIL Dialogue Typography Environment Placement:**
- VEIL probability dialogue fragments inserted in billboards: "Survival probability: 0.003%", "Optimization complete"
- Font: Monospace terminal style (same family as UI font) — implies VEIL has taken over the city's advertising

**REWIND Core Energy Residue (gameplay integration):**
- Cyan glowing cracks at checkpoint locations → "REWIND Core discharged here and recharged" narrative
- Cyan energy fragments remain in the space after defeating the boss

### Camera Viewport Contract (Camera System #3 2026-05-12)

This subsection specifies the visual contract that the camera system (Camera System #3) imposes on NEXUS megacity environment design. art-bible Approved → Camera #3 Approved RR1 PASS bidirectional consistency (Camera #3 GDD VA.6 + F.1 row #9 reciprocal).

**Screen shake displacement model (uniform displacement):**
- Camera shake moves the entire viewport uniformly via `camera.offset` (post-smoothing channel) — Base photo / Mid line-art / Top collage-detail 3 layers all move together with the same vector, so the distance between torn-paper edges changes by 0 pixels.
- Result: Even when shaking, the collage composite does not decompose (Principle A Clarity-First Collage consistency).
- Implementation note: Per-element independent movement patterns (e.g., each layer having independent parallax or wobble shader) are incompatible with this contract — adoption requires Camera #3 GDD revision.

**Readable Third (readable zone):**
- Define the **horizontal center ±213 px** (= viewport_width / 6) area as the "readable third" for Tier 1 viewport 1280×720.
- Camera maximum shake displacement is `MAX_SHAKE_PX = 12` (global length clamp; camera.md G.1.2). 12 px ≪ 213 px (~17× inner margin), so readability is guaranteed even at shake peak as long as key gameplay elements like boss silhouettes remain within the readable third.
- **Prop placement rule**: Gameplay-*critical* collage elements (boss silhouette, jump-threat hazards, REWIND Core residue narrative cues) must *not be placed alone outside the readable third* assuming 12 px MAX_SHAKE_PX displacement. Placement outside is possible, but must be accompanied by a paired hint or alternative read path inside the readable third.

**Vertical lookahead ratio (asymmetric):**
- Camera previews 20 px above ECHO's head on jump, 52 px below on fall (2.6× asymmetry — landing threats are more frequent than jump-apex threats in run-and-gun pacing).
- **Environment design obligation**: Landing hazards (spikes, floor enemies, fall traps) must be visually identifiable within the viewport bottom 52 px area relative to ECHO's foot position (Pillar 2 — "don't die by luck" consistency). Maintain sufficient contrast between hazard sprite silhouette gap (Section 3 shape-language) and collage background, coordinating with prop density (D.4 prop density rules).

**Tier 2 zoom range (deferred, art-direction intent locked now):**
- Tier 1: zoom = 1.0 fixed (DEC-CAM-A4).
- Activated when Tier 2 boss arena is introduced — `0.85..1.25×` range pre-locked (camera.md VA.2):
  - **0.85× min** (boss arena pull-out): ECHO 48 px sprite × 0.85 = 41 px apparent (Section 3 ≥32 px floor passed)
  - **1.25× max** (boss face push-in): STRIDER 192 px sprite × 1.25 = viewport 18.75% — inside readable third
- **Hard floor invariant** (register as new INV in Camera #3 GDD when Tier 2 is introduced): "ECHO rendered pixel height ≥ 32 px apparent at any Tier 2 zoom level" (Section 3 thumbnail test consistency — verified at 720p Steam Deck native).
- **Zoom transition curve**: Hard cut forbidden — use tween (Pillar 3 — collage composite "breathes" into the new frame; exact curve/speed decided at Tier 2 Boss Pattern #11 GDD revision).

**Cross-doc references**:
- camera.md VA.6 (Cross-doc Art-Bible Reciprocal — source spec for this amendment)
- camera.md F.1 row #9 (art-bible.md SOFT dependency — Pillar 3 collage signature preservation)
- camera.md F.5 art-bible reciprocal row (Phase 5 cross-doc placement)

---

## 7. UI/HUD Visual Direction

This section defines the visual design standards for the HUD and menu system, and specifies the navigation visualization optimized for gamepad-primary controls.

### Diegetic vs. Screen-Space Separation

**Recommended: Hybrid — Diegetic 70% / Screen-Space 30%**

Rationale: Echo is a one-hit-kill game. There is no traditional HUD like a health bar — ECHO dies from one hit. Instead, only the most important information (REWIND token count) is kept in screen-space, and the rest is embedded in the world.

| UI Element | Type | Placement | Reason |
|---|---|---|---|
| **REWIND Token Counter** | Screen-space | Fixed upper-left | 0.2-second glance required — Pillar 2 core. Diegetic placement risks going off-screen |
| **Health System** | No diegetic | N/A | One-hit-kill = no health bar |
| **Weapon Type Display** | Screen-space | Small icon lower-right | Need to recognize pickup weapon type |
| **VEIL Alert Level** | Diegetic | Background billboard color change | Express surveillance intensity through environment — Tier 2+ |
| **Boss Phase Pulse / Boss Title Flash** | Screen-space | Upper center or boss-safe frame | Appears only during boss fights; phase/presence notification only, no HP bar or hit counter |
| **Pause Menu** | Screen-space | Full overlay | Navigation clarity first |

---

### Typography

**Font Character Requirements:**
- English: Monospace (terminal/data feel) + magazine cutout display font in combination
- Korean: Gothic family (no Myungjo — inferior readability at pixel density)

**Candidate A — Monospace Terminal Family (recommended):**
- Representative examples: `IBM Plex Mono`, `Fira Code`, `JetBrains Mono`
- Used for VEIL dialogue, HUD numbers, data text
- Rationale: Consistent with the setting where VEIL controls all city terminals. Provides typewriter feel in collage aesthetic.

**Candidate B — Display Cutout Sans-Serif:**
- Representative examples: `Bebas Neue`, `Anton`, or hand-lettering scan font
- Used for titles, chapter headings, boss names
- Rationale: 1990s magazine headline aesthetic. Direct reference to Hannah Höch Dada collage typography.

**Recommended combination:** Candidate A (HUD/body text) + Candidate B (title/emphasis) mixed. Do not cover both roles with a single font.

**Q: Korean font selection — Nanum Square family vs Noto Sans KR vs system font?** Use Noto Sans KR as default for Tier 1, decide official licensed font at Tier 3 release.

---

### Icon Style

**Style: Bold Line Flat Drawing (Outlined Flat) — No photo texture**

Rationale: Pillar 2 — 0.2-second glance. Icons prioritize shape recognition. Adding collage texture to icons reduces identification speed.

- Line weight: 3px at 1080p (2px at 720p)
- Corners: Cutout style (irregular cuts, no full rounds)
- Colors: Only three — cyan (player-related) / magenta (threat/inactive) / yellow (collectible)

**REWIND Token Icon Detail:**
- Shape: Circle inside inverted triangle (expresses REWIND directionality + energy convergence)
- Active: Cyan glow + filled interior
- Spent: Gray outline only (Concrete Mid)
- Size: 32×32px per token, 3 arranged horizontally

---

### UI Animation Feel

- **Entry animation:** Cut-in (no fade) — collage aesthetic. The feel of a photo dropping onto the screen
- **Transition:** Glitch flicker 1 frame → cut. No smooth crossfade (feels like realism software)
- **Hover/focus feedback:** Line weight increase + cyan highlight. No size change (no layout shift)
- **Selection confirmation:** 0.1-second color flash + sound cue

---

### Gamepad Navigation Visualization (Gamepad Primary — Anti-Pillar #5 compliance)

D-pad directionality must be clear. Focus movement in menus must always show direction.

- **Focus indicator:** Cyan triangle pointer to the left of the active item (cursor style)
- **Directional movement feedback:** 0.05-second slide in movement direction (directional awareness)
- **On-screen cycling:** Pressing down on the last item goes to the first item — visually shows screen-edge wrap
- **Token counter gamepad glance test:** While playing with thumbs holding the actual pad, can you recognize the token count within 0.2 seconds? — Required verification item for Tier 1 playtesting

---

## 8. Asset Standards

This section defines asset specifications optimized for the Godot 4.6 pipeline within the range achievable by a solo developer. All values comply with the 60fps / 500 draw call / 1.5GB memory constraints.

### File Formats

| Asset Type | Format | Reason |
|---|---|---|
| Sprites (characters/enemies) | PNG (transparency support) | Alpha channel required |
| UI icons | PNG or SVG → runtime rasterization | Resolution-independent (multi-resolution support) |
| Environment tiles | PNG atlas | Draw call reduction |
| Parallax backgrounds | PNG (per layer) | Layer-separated compositing |
| VFX particles | PNG sprite sheet | Godot GPUParticles2D compatible |
| Fonts | TTF/OTF → Godot import | Runtime bitmap conversion |
| Audio (Tier 1) | OGG Vorbis (CC0 placeholder) | Godot 2D default format, streaming support |

---

### Naming Convention

`[category]_[name]_[variant]_[size].[ext]`

| Category | Examples |
|---|---|
| Characters | `char_echo_idle_01.png`, `char_echo_run_03.png` |
| Enemies | `char_drone_fly_01.png`, `char_secbot_idle_01.png`, `char_strider_phase2_01.png` |
| Environment tiles | `env_rooftop_concrete_large.png`, `env_rooftop_adboard_small.png` |
| Parallax | `env_bg_nexus_skyline_large.png`, `env_bg_veil_drone_swarm_medium.png` |
| UI | `ui_token_active_small.png`, `ui_btn_primary_hover.png`, `ui_boss_phase_pulse_large.png` |
| VFX | `vfx_rewind_glitch_loop_small.png`, `vfx_bullet_impact_small.png` |
| Collage fragments | `col_arca_logo_decay_medium.png`, `col_veil_icon_graffiti_small.png` |

GDScript file naming integration: `char_echo_*` assets are loaded by `echo_controller.gd`.

---

### Texture Resolution Tiers

| Asset Type | Base Resolution | Notes |
|---|---|---|
| ECHO sprite (1 frame) | 48×96px | Maintain screen ratio at 1080p |
| Drone sprite | 16×16px | Small, many on screen simultaneously |
| Security Bot sprite | 72×72px | Large, maximum 2-3 on screen |
| STRIDER boss sprite | 192×128px | Boss-exclusive, single instance |
| Environment tile (base) | 128×128px | Covers screen in 4×4 grid |
| Parallax background | 1920×360px (per layer) | 3 layers × 360px height |
| UI icons | 64×64px (max) | Raster backup if SVG preferred |
| Collage photo fragments | 256×256px or smaller | Excluded from atlas if exceeded |

---

### Atlas Budget (per stage)

**Tier 1 (Stage 1 Rooftop only):**

| Atlas | Contents | Size |
|---|---|---|
| `atlas_chars_tier1.png` | ECHO + Drone + Security Bot + STRIDER | 512×512px |
| `atlas_env_rooftop.png` | Full rooftop tile set | 512×512px |
| `atlas_ui.png` | Full HUD + menu icons | 256×256px |
| `atlas_vfx_tier1.png` | REWIND glitch + bullet impact | 256×256px |
| `atlas_collage_stage1.png` | Collage fragments (ARCA ads, VEIL icons, Sigma graffiti) | 512×512px |

**Total Tier 1 atlas memory: approx. 3.5MB (uncompressed)**
512×512 RGBA = 1MB × 2 + 256×256 RGBA = 0.25MB × 3 = 2.75MB. Sufficient headroom.

---

### Godot 4.6 Import Settings Recommendation

```
# Sprites (characters/UI):
filter = TextureFilter.NEAREST        # No pixel interpolation — maintains collage edges
repeat = TextureRepeat.DISABLED
mipmaps/generate = false              # Fixed 2D camera — mipmaps unnecessary

# Environment tiles (repeat needed):
filter = TextureFilter.NEAREST
repeat = TextureRepeat.ENABLED
mipmaps/generate = false

# Parallax backgrounds:
filter = TextureFilter.LINEAR         # Smooth sampling during scroll
repeat = TextureRepeat.ENABLED
mipmaps/generate = false

# Collage photo fragments:
filter = TextureFilter.LINEAR         # Natural look with linear filter for photo textures
repeat = TextureRepeat.DISABLED
mipmaps/generate = false
```

---

### Draw Call Budget Allocation (total ≤500)

| Category | Budget | Calculation Basis |
|---|---|---|
| Player + enemies | 80 | ECHO(1) + max 8 drones(8) + max 3 Security Bots(3) + STRIDER(1) + max 20 bullets(20) + max 8 hit effects(8) → approx. 80 after atlas batching |
| Environment tilemap | 100 | Godot TileMap batching. Foreground/midground/background 3 layers × approx. 30 tiles = approx. 90-100 |
| Parallax backgrounds | 50 | 3 layers × multiple meshes per background = approx. 40-50 |
| Collage layer | 80 | 20-30 collage fragments per stage, approx. 60-80 with atlas batching |
| VFX | 100 | GPUParticles2D batching. REWIND glitch (1 pass) + bullet trails + boss particles |
| UI / HUD | 40 | Token counter(3) + boss phase pulse(1) + weapon icon(1) + font render pass(~15) = approx. 40 |
| Shader fullscreen pass | 50 | 1 pass color inversion on REWIND activation, 1 pass vignette at rest = max 50 |
| **Total** | **500** | Exactly at the limit. No optimization headroom — controlling collage fragment count is the key lever |

**Note:** Collage photo textures (Principle B) put pressure on **memory** more than draw calls. See memory budget below.

---

### Memory Budget (per stage, 1.5GB constraint)

| Item | Estimated Memory | Calculation Method |
|---|---|---|
| Godot engine + GDScript runtime | ~350MB | Engine base overhead |
| Audio stream buffer (Tier 1 CC0) | ~20MB | OGG streaming, uncompressed buffer |
| Game code + scene data | ~30MB | GDScript compiled + scene tree |
| Sprite atlases (Tier 1, 5 total) | ~4MB | See atlas budget above |
| Parallax background textures | ~15MB | 1920×360 × 3 layers × RGBA |
| Collage photo source textures | ~60MB | 256×256 RGBA × max 60 images |
| VFX particle textures | ~5MB | Many small sprite sheets |
| Font bitmap cache | ~10MB | Runtime glyph cache |
| **Tier 1 estimated total** | **~494MB** | 33% of 1.5GB — ample headroom |

**Collage photo texture collision warning:**
At Tier 3 when loading 5 stages simultaneously, collage photo source textures alone could reach up to 300MB (60MB × 5). `collage-rendering.md` now locks the Tier 1 policy: clear Collage-owned local references on `scene_will_change()` and rely on single-stage scene unload. **Explicit release of previous stage textures remains a Tier 2 ADR gate** before multi-stage implementation; verify `ResourceLoader.load()` reference count in Godot 4.6 as part of that ADR.

**Solo development production note:**
Total Tier 1 assets (5 atlases + 3 backgrounds = approx. 30 PNG files) are within solo production range in 4-6 weeks. Pillar 5 (small wins > big ambitions) compliance: do not add collage photo sources without limit in Tier 1. A maximum of 30 collage fragments per stage acts as a lever for both draw calls and memory.

---

## 9. Reference Direction

This section specifies what Echo's visual development takes and avoids to prevent directional drift from misunderstanding references. Maximum 4 references (user-confirmed standard).

---

### Reference 1 — Hannah Höch (1920s Dada Collage)

**Role:** Historical origin of the collage composite aesthetic

**What to take:**
- Technique of placing magazine/newspaper photo cutouts alongside line drawings
- Ignoring scale — figures larger than buildings, letters covering faces
- Placing objects over photo backgrounds rather than blank white
- Revealing collage edges rather than hiding them (scissor marks are the aesthetic)

**What to avoid:**
- Erotic/political satire tone (Höch's original purpose — Echo is action/SF)
- Black-and-white or sepia monochrome compositions (Echo requires neon color)
- Abstract constructivist layouts (Echo prioritizes side-scrolling readability)

**Application:** All environment collage layers, Steam capsule image, boss reveal cuts

---

### Reference 2 — Monty Python Cutout Animation (Terry Gilliam, 1969-1975)

**Role:** Animation language of moving collage

**What to take:**
- Structure where static photos/illustrations move separated at joints (ECHO animation method)
- Exaggerated and discontinuous movement — cuts between poses without organic tweening
- Transparency of not hiding that the animation "was made"
- Expressing intense action with minimal frame count (directly tied to solo production efficiency — Pillar 5)

**What to avoid:**
- Comedy/absurdist tone (Monty Python's purpose — Echo is tense action)
- Brown/aged-dominant palette (1970s TV color)
- Exaggerated body distortion (Echo characters maintain action proportions)

**Application:** ECHO movement animation structure, enemy destruction effects, boss phase transition cuts

---

### Reference 3 — Asian Megacity Dystopia Cluster (Blade Runner 1982 / Akira 1988 / Ghost in the Shell 1995)

**Role:** Collective reference for NEXUS mood, color, and urban spatial grammar

All three works are treated as a single cluster — they all point in the same direction (Asian city-based SF dystopia mood).

**What to take (Blade Runner):**
- Neon reflections in rain (starting point for NEXUS nightscape palette)
- Urban layering where advertising and surveillance coexist
- Concrete darkness + color-point neon contrast

**What to take (Akira):**
- Motion blur expression for motorcycles and moving objects (Maglev Stage 3 background)
- Rubble aesthetic of a destroyed city (collage decay layer reference)
- Red/yellow energy explosions (boss defeat VFX — reinterpreted in Echo's palette)

**What to take (Ghost in the Shell):**
- Visual language of cyborgs/implants (ECHO's REWIND Core device design)
- Spatial composition where city infrastructure becomes the enemy (VEIL weaponizing NEXUS)
- Information layer HUD aesthetic (VEIL dialogue typography environmental placement)

**What to avoid:**
- 3D rendering realism (modern sequel style of this cluster)
- Slow mood-building (Echo is run-and-gun — no static atmosphere scenes)
- Gray/blue monochrome color (violates collage color diversity)

**Application:** Rooftop background photo texture direction, parallax background layer atmosphere, boss design spatial composition

---

### Reference 4 — Cuphead (2017, Studio MDHR)

**Role:** Indie precedent where a visual signature became a marketing asset (Pillar 3 rationale)

**What to take:**
- How completeness of a single visual language makes a game instantly recognizable
- Strategy of using boss design as a visual showcase
- Compositional power where a single Steam capsule/screenshot functions as a complete marketing image
- Sprite strategy that expresses lively motion while reducing frame count

**What to avoid:**
- 1930s cartoon style (rubber ink/grain/film damage effects)
- Round and cute character proportions (Echo has sharp action proportions)
- Jazz rhythm structure where music is synchronized with visuals (Anti-Pillar #4 — no music in Tier 1)
- 2D sprite composite over 3D background method (Echo is pure 2D)

**Application:** Steam capsule image composition principles, boss sprite showcase weight, marketing screenshot framing standard (Cuphead capsule composition study required when producing first Tier 1 marketing image)

---

*Art Bible — 9 sections complete. 2026-05-09.*
*v0 hex codes lock at first concept-art round.*
*Q2 (photo sources) and Q5 (ECHO gender) updated in respective sections after each trigger event.*
