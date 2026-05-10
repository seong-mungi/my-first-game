---
type: concept
title: Bot Human Validation Reconciliation
created: 2026-05-10
updated: 2026-05-10
tags:
  - validation
  - playtest
  - bot
  - reconciliation
  - methodology
  - design-pattern
  - echo-applicable
status: developing
related:
  - "[[AI Playtest Bot For Boss Validation]]"
  - "[[Bot Validation Pipeline Architecture]]"
  - "[[Heuristic Bot Reaction Lag Simulation]]"
  - "[[GDD Bot Acceptance Criteria Template]]"
  - "[[Modern Difficulty Accessibility]]"
---

# Bot Human Validation Reconciliation

Bots and humans grade different things. Bots check **whether designed mechanics work as specified**; humans check **whether playing them is rewarding**. The two grades disagree often, and each disagreement is diagnostic — it points at a specific category of design defect that lives outside what bots can perceive.

This page is the reconciliation contract: how to read bot reports next to playtest data, what the four quadrants mean, and which design lever fixes which mismatch.

## The Four Quadrants

```
                  HUMAN PASS               HUMAN FAIL
              ┌─────────────────────┬───────────────────────┐
   BOT PASS   │  ✅ SHIP-READY      │  ⚠️ HIDDEN DEFECT      │
              │  All criteria met   │  Bot misses something │
              ├─────────────────────┼───────────────────────┤
   BOT FAIL   │  🔧 BOT MODEL WEAK  │  ❌ DESIGN FAILURE     │
              │  Bot underspec'd    │  Fix design, retest   │
              └─────────────────────┴───────────────────────┘
```

Each off-diagonal quadrant maps to a specific class of fix.

## Quadrant ⚠️ — Bot PASS / Human FAIL (Hidden Defect)

The most informative quadrant. Bot says "design works"; humans say "design doesn't feel right". By definition the gap lives in what bot cannot see.

| Symptom in playtest | Likely cause | Fix |
|---|---|---|
| "I couldn't tell when to dodge" | Visual telegraph unclear | Increase telegraph saturation / contrast / size |
| "It felt random" | Pattern memorization defeated by visual noise | Reduce particle clutter on telegraph; raise audio cue volume |
| "I never thought to use rewind" | Rewind affordance hidden | Add HUD prompt; unlock tutorial that forces first rewind |
| "It was unfair" but bot dodge rate fine | Cognitive load — multiple simultaneous cues | Stagger telegraphs; cut one decoy element |
| "I got bored" | Pacing — too long between learning beats | Shorten phase, add intermediate beat |
| "The 9-frame window felt impossible" | Audio cue absent or buried | Audio mix surgery |

**Diagnostic rule**: If bot heuristic clears at 50% and humans clear at <20%, the gap is *perception*, not *mechanics*. Mechanics are validated; perception is not.

## Quadrant 🔧 — Bot FAIL / Human PASS (Bot Underspec'd)

Less common but still informative. Bot says "design fails"; humans clear it.

| Symptom in bot report | Likely cause | Fix |
|---|---|---|
| Heuristic win < 20% but humans win 50% | Lag too aggressive (bot's >9f, humans use anticipation) | Lower lag in calibration; humans read tells before telegraph fully shows |
| Pattern-without-rewind clear = 0 in bot but humans bypass | Heuristic's rule cascade misses dodge variant | Add the dodge variant rule |
| Bot stalls / doesn't engage | Reward shaping issue (RL only) | See [[RL Reward Shaping For Deterministic Boss]] |
| Rewind never used by bot but humans use it freely | Bot's threat detection lags actual lethal timing | Improve `lethal_threat_imminent` flag; lower lag |

**Diagnostic rule**: If a competent human consistently outperforms the heuristic bot, the bot model is *weaker* than a competent human. Either tune the bot up or accept this is a "human skill ceiling" feature.

## Quadrant ✅ / ❌ — Both Agree

Both PASS = ship-ready (still survey for fun separately).
Both FAIL = unambiguous design failure. Fix the design, retest.

## Echo Standard Playtest Survey

Every Echo playtest collects this baseline data alongside the bot report:

```yaml
playtest_survey:
  per_session:
    - id: telegraph_clarity_p1
      type: likert_5
      question: "How clearly could you read the boss's attack tells in P1?"
    - id: telegraph_clarity_p3
      type: likert_5
      question: "How clearly could you read the boss's attack tells in P3 (death-beam)?"
    - id: rewind_discoverability
      type: likert_5
      question: "Did you feel you understood when to use rewind?"
    - id: rewind_satisfaction
      type: likert_5
      question: "When you used rewind, did it feel powerful?"
    - id: frustration_moments
      type: open_text
      question: "Describe any moment that felt unfair or like a 'cheap death'."
    - id: learning_sense
      type: likert_5
      question: "Did each death teach you something?"
    - id: audio_cue_clarity
      type: likert_5
      question: "Did the boss's sound cues match what was happening visually?"
    - id: cognitive_overload
      type: likert_5
      question: "Were there moments where too much was happening at once?"
    - id: progression_pull
      type: likert_5
      question: "How much did you want to try again after dying?"
    - id: clear_satisfaction
      type: likert_5
      question: "After clearing the boss, how satisfying was it? (skip if not cleared)"
  per_session_metric:
    - id: human_attempts
      auto: true   # logged by game
    - id: human_clear_time
      auto: true
    - id: human_rewind_count
      auto: true
```

## Reconciliation Decision Matrix

Compare bot metrics against survey aggregates:

| Bot metric | Human equivalent | Reconciliation rule |
|---|---|---|
| Heuristic win rate | Player clear rate | If diff > 20pp → diagnose perception |
| Rewind Save Rate | Survey: rewind_satisfaction (≥4 = success) | If bot 70% but humans 3.0/5 → discoverability problem |
| Death-by-Phase distribution | Player attempt-to-clear distribution | If bot front-loaded but humans back-loaded → pacing inversion |
| TTFC (RL) | Median human attempts | If bot 20 but humans 40 → tutorial / onboarding gap |
| Pattern-no-rewind P3 = 0 | Survey: rewind_discoverability | If bot enforces but humans never trigger → tutorial gap |

## Sample Size Per Side

| Validation kind | Bot sample size | Human sample size |
|---|---|---|
| Boss CI gate | 1000 heuristic + 100 scripted | — (CI is bot-only) |
| Boss release gate | + 5000 RL episodes | 5–8 humans, 60–90 min each |
| Difficulty calibration | Lag sweep × 1000 | 12–15 humans across skill levels |
| Tutorial | Scripted-walkthrough verify | 10+ first-time players |

> **Power principle**: Bot N can be 1000s; human N must be ≥ 5 with stratified skill levels (novice / mid / experienced). Below 5 humans, qualitative survey trumps statistical test.

## When Surveys Override Bot Verdicts

A bot PASS does not ship if any of these fire:
- Average **clear satisfaction** < 3.5 / 5
- ≥ 50% of testers cite the same **frustration moment**
- ≥ 3 testers describe the boss as "**unfair**" or "**cheap**"
- **Telegraph clarity** < 4 / 5 on the boss's signature pattern

These trigger redesign even if every bot metric is green.

## When Bot Verdicts Override Surveys

A human PASS does not ship if any of these fire:
- **Random bot wins > 1%** (regardless of human reception — luck-based)
- **Scripted bot < 100%** (non-determinism — invisible to humans now, fatal later)
- **Pattern-without-rewind P3 clears > 0** (rewind not enforced — defeats core mechanic)

These are mechanical defects humans don't perceive yet but will once speedrun community forms.

## Workflow

```
1. Implement boss → run CI bot suite → green
2. Run nightly RL bot suite → green
3. Run release bot suite (full bot tier) → green
4. Schedule human playtest (5–8 testers, 90 min)
5. Aggregate: bot report + survey + auto-logged human metrics
6. Generate reconciliation report (4-quadrant placement per criterion)
7. Each off-diagonal item → fix list
8. Loop until all on-diagonal
```

## Reconciliation Report Template

```markdown
# Boss [meaeokkun] — Reconciliation Report 2026-05-12

## Summary
- Bot verdict: PASS
- Human verdict: CONCERNS
- Reconciliation: ⚠️ Hidden Defect — telegraph clarity gap on P3

## Per-Criterion Quadrant Placement
| Criterion | Bot | Human | Quadrant | Action |
|---|---|---|---|---|
| Pattern dodgeable | PASS | FAIL (3.1/5 clarity) | ⚠️ Hidden | Increase P3 telegraph contrast |
| Rewind enforces | PASS | PASS (4.6/5) | ✅ Ship | — |
| TTFC | PASS (TTFC=22) | FAIL (median=38) | ⚠️ Hidden | Add P1 tutorial beat |
| Cognitive load | — | FAIL (3.0/5 overload) | ⚠️ Hidden | Stagger P3 telegraphs |

## Action Items
1. P3 telegraph: brightness +50%, particle count -30%
2. P1 tutorial: forced rewind on first death
3. P3 cue stagger: separate audio + visual by 3 frames

## Re-validation
- Bot CI: required pre-merge
- Re-playtest: 3 of original 8 testers, 30 min each
```

## Anti-Patterns

| Anti-pattern | Why bad |
|---|---|
| Shipping Bot PASS without human playtest | Bots can't grade fun; missing whole defect class |
| Re-running playtest after every Tuning Knob change | Cost-prohibitive; gate at sprint level not commit |
| Letting human verdict override Random bot detection | Players don't notice luck wins until release |
| Single tester overrides bot data | n=1 is not data; need ≥ 5 |
| Ignoring "hidden defect" quadrant | Bot reports become rubber-stamp instead of diagnosis |

## Open Questions

- **[NEW]** Should the reconciliation report be generated automatically from bot JSON + survey CSV?
- **[NEW]** What's Echo's default human playtester pool size — 5 (minimum) or 8 (better stratification)?
- **[NEW]** How to weight novice vs experienced playtester verdicts when they conflict?
- **[NEW]** Should Tuning Knob changes that affect only "human" axes (visual clarity) skip bot CI?

## Related

- [[Bot Validation Pipeline Architecture]] — where reconciliation fits in the pipeline
- [[AI Playtest Bot For Boss Validation]] — bot side of the equation
- [[Modern Difficulty Accessibility]] — accessibility playtest considerations
