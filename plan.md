# Jailbreak --- Game Development Plan for Codex

## 0. Mission

Build a complete first playable draft of a 2D comedy roguelite/strategy
game tentatively called **Jailbreak**.

The player assembles a team of five prisoners and attempts to escape a
procedurally generated prison. Every run should be different because the
available characters, party composition, prison layout, encounters,
choices, consequences, and power-ups are randomized.

This document is the implementation specification for the first playable
version.

The goal is NOT to build a giant production-ready game immediately.

The goal is to build a **fun, polished, playable vertical slice** that I
can run, play, and then edit. The systems must be data-driven so I can
easily change characters, traits, choices, numbers, events, and outcomes
later without rewriting the game architecture.

------------------------------------------------------------------------

# 1. Important Developer Instructions

## 1.1 Build the game, don't just explain it

Do not return only design documents or pseudocode.

Create the actual project and implement the playable game.

If a feature is not fully specified, make a sensible implementation
decision and continue. Do not stop repeatedly to ask questions.

Prioritize a working playable game over perfect architecture.

## 1.2 First draft \> perfection

This is a first draft.

Use placeholder/default content where necessary, but make the game feel
coherent and intentional.

I will later edit: - character names - character traits - stats -
dialogue - choices - event logic - balance - power-ups - story

The code must make these things easy to edit.

## 1.3 Art is part of the implementation

I have essentially no art/design experience.

Therefore, handle the visual direction yourself.

Do NOT leave the project as a collection of gray boxes unless absolutely
necessary.

Create a coherent original 2D visual style using assets that can legally
be distributed with the game.

Preferred visual direction:

-   humorous 2D cartoon
-   exaggerated prisoner characters
-   simple readable silhouettes
-   expressive faces
-   slightly absurd proportions
-   prison environment
-   clean UI
-   playful animations
-   readable typography
-   intentionally indie rather than photorealistic

Do not copy copyrighted characters, artwork, logos, or assets.

If generating assets procedurally or with code is easier, do that.

If external assets are needed, prefer permissively licensed assets and
document their licenses.

The project should work without requiring me to manually draw anything.

------------------------------------------------------------------------

# 2. Target Technology

Use **Godot 4.x** unless the repository/project already establishes
another engine.

Primary target: - Desktop/Web playable prototype

Later targets: - Steam - Android - iOS

Use a project structure that can eventually support all three.

Prefer: - GDScript - data-driven Resources/JSON where appropriate -
deterministic/randomized run seeds - modular managers/systems -
signals/events rather than excessive hard references

Do not over-engineer.

------------------------------------------------------------------------

# 3. Core Game Pitch

> Assemble five ridiculous prisoners and attempt the world's dumbest
> prison escape.

The player begins by selecting one main prisoner from three randomly
presented candidates.

The player then recruits four additional prisoners.

For each recruitment: - show three random candidates - candidates have
different strengths, weaknesses, traits, and personalities - player
chooses exactly one - chosen prisoner joins the party - once all five
are selected, the party is locked for that run

The player then attempts to escape a procedurally generated prison.

The player does not directly control the prisoners in a traditional
action game.

Instead, the game is primarily: - strategic decisions - event choices -
party composition - skill checks - resource management - risk/reward
decisions - consequences

After successful tasks/encounters, the player chooses one power-up from
five randomly generated options.

Four power-ups should be straightforward beneficial upgrades.

One power-up should secretly contain a catch.

The player should NOT initially know which one has the catch.

The game should produce funny stories and unexpected outcomes.

------------------------------------------------------------------------

# 4. Core Run Loop

Implement this exact high-level loop:

``` text
Main Menu
    ↓
Start New Run
    ↓
Choose Main Prisoner
    ↓
Recruit Prisoner #2
    ↓
Recruit Prisoner #3
    ↓
Recruit Prisoner #4
    ↓
Recruit Prisoner #5
    ↓
Party Locked
    ↓
Generate Prison
    ↓
Run Through Encounters
    ↓
Choose Character / Strategy
    ↓
Resolve Outcome
    ↓
Apply Consequences
    ↓
Power-up Selection
    ↓
Next Encounter
    ↓
Final Escape Attempt
    ↓
Success / Failure
    ↓
Run Summary
    ↓
Retry / Main Menu
```

------------------------------------------------------------------------

# 5. MVP Scope

Do NOT initially attempt: - multiplayer - online accounts - procedural
animation generation - complicated combat - inventory with hundreds of
items - complex NPC simulation - full voice acting - monetization -
ads - achievements integration - cloud saves - live service systems

The first playable version should contain approximately:

### Characters

15-20

### Starting/recruitment candidates

3 candidates shown at each selection

### Party

5 prisoners

### Stats

5-6 core stats

### Traits

20+ reusable traits

### Prison

1 prison theme

### Rooms/encounter types

10-15

### Events

30+ if practical; minimum 15 for the first playable version

### Power-ups

20+

### Power-up selection

5 choices: - 4 normal - 1 secretly cursed/catch

### Escape routes

At least 3 meaningful strategies

### Heat system

Yes

### Resources

At least: - money - health/injury state - heat - time/progress

### Endings

At least: - successful escape - normal failure - funny catastrophic
failure

------------------------------------------------------------------------

# 6. Visual Direction

Create a consistent visual language.

## 6.1 Overall style

2D cartoon comedy.

Think: - chunky shapes - thick readable outlines - simple shading -
exaggerated facial expressions - slightly goofy proportions - strong
silhouettes - prison gray/blue environment with occasional bright
accents - humorous UI

Avoid: - photorealism - anime unless deliberately chosen later - overly
detailed backgrounds - visually noisy screens

## 6.2 Characters

Characters should be visually distinct even when small.

Use: - different body shapes - different hairstyles - glasses - facial
hair - prison uniforms - hats/accessories where appropriate -
exaggerated expressions

Every character should have: - portrait - full/half-body representation
where useful - idle state - success reaction - failure reaction -
injured/scared reaction if feasible

Do not make 20 completely unique complex animation rigs.

A reusable character system with interchangeable visual components is
preferred.

## 6.3 Environment

Create a simple prison environment containing: - cell block -
cafeteria - yard - laundry - workshop - medical room - guard station -
maintenance area - sewer/tunnel area - outer wall

Use modular environment pieces.

## 6.4 UI

UI should feel like a polished indie game.

Important screens: - Main Menu - Character Selection - Recruitment -
Party Overview - Prison Map - Encounter - Choice/result - Power-up
selection - Run Summary

Use large readable buttons.

Make the game usable with: - mouse - keyboard where sensible -
touch-friendly button sizes for future mobile support

------------------------------------------------------------------------

# 7. Character System

Create a reusable Character data model.

Suggested fields:

``` text
id
name
nickname
description

strength
intelligence
stealth
charisma
luck
speed

health
max_health

traits[]
abilities[]

portrait
visual_profile

personality_tags[]

starting_items[]
```

Do not hard-code character behavior into UI scenes.

Characters should be data.

------------------------------------------------------------------------

# 8. Core Stats

Use these initial stats:

## Strength

Physical tasks.

Examples: - breaking doors - moving objects - fighting - climbing

## Intelligence

Technical/planning tasks.

Examples: - hacking - lockpicking - understanding systems - planning

## Stealth

Avoiding detection.

Examples: - sneaking - hiding - moving through restricted areas

## Charisma

Social manipulation.

Examples: - bribing - convincing - distracting - lying

## Luck

Randomness manipulation.

Examples: - unexpected lucky outcomes - rare event success - reducing
catastrophic failures

## Speed

Physical reaction and escape.

Examples: - running - reacting to guards - timed escapes

Use a simple 1-10 scale initially.

------------------------------------------------------------------------

# 9. Traits

Traits are more important than raw stats.

Each character should have: - 1-2 positive traits - 0-1 negative
traits - personality flavor

Traits can modify: - skill checks - heat - resource usage - encounter
availability - other character interactions - probability of funny
events

Example traits:

``` text
Strong as Hell
+2 Strength for physical actions.

Butterfingers
Failed actions have a chance to drop an item.

Nobody Suspects Grandma
Reduced detection when using this character for social/stealth actions.

Keyboard Warrior
+2 Intelligence for computer-related actions.

Loudmouth
Social actions are stronger, but failures generate extra Heat.

Lucky Idiot
Occasionally converts a failed random check into success.

Claustrophobic
Penalty inside tunnels.

Professional Liar
Better deception checks.

Walking Alarm
Higher chance of increasing Heat.

Gym Bro
Strength increases after physical successes.
```

Make the trait system generic enough that I can add/edit traits later.

------------------------------------------------------------------------

# 10. Party System

Party size is exactly 5.

During recruitment: - show 3 candidates - each candidate should be
visually distinct - display stats - display traits - display short
description - allow player to inspect details - choose exactly one

After selecting five: - party is locked for the run

Party overview must show: - portraits - names - stats - health -
traits - current status - selected power-ups affecting them

------------------------------------------------------------------------

# 11. Recruitment Algorithm

Use a weighted/random candidate generator.

At every recruitment: 1. Generate 3 candidates. 2. Avoid generating
three nearly identical candidates. 3. Encourage meaningful tradeoffs. 4.
Avoid making one candidate obviously superior every time. 5. Ensure
party diversity is possible. 6. Allow synergy.

Example:

``` text
Candidate A:
High Strength
Low Stealth
Trait: Loudmouth

Candidate B:
High Intelligence
Medium Stealth
Trait: Hacker

Candidate C:
High Charisma
High Luck
Trait: Professional Liar
```

The user should feel like they are making a strategic choice.

------------------------------------------------------------------------

# 12. Prison Generation

The prison should be different each run.

Use procedural generation, but constrain it enough that every generated
prison is playable.

Create room nodes such as:

``` text
Cell Block
Cafeteria
Yard
Laundry
Workshop
Medical
Guard Station
Security
Maintenance
Sewer
Outer Wall
```

Generate: - room order - connections - encounter placement - resource
placement - optional paths - risk/reward paths

The player should sometimes be able to choose between:

``` text
SAFE PATH
Low risk
Low reward

RISKY PATH
High Heat
Better reward

SECRET PATH
Requires certain character/stat/trait
Potentially huge reward
```

------------------------------------------------------------------------

# 13. Prison Map UI

The map should be visually readable.

Example:

``` text
        [Guard Tower]
             |
[Cell] -- [Cafeteria] -- [Laundry]
             |
        [Workshop]
             |
        [Maintenance]
             |
          [Sewer]
             |
         [Outside]
```

Fog/unvisited areas can be hidden.

Completed rooms should visually change.

Important: The map should feel like a journey, not a spreadsheet.

------------------------------------------------------------------------

# 14. Encounter System

Create a reusable encounter framework.

Each encounter should contain:

``` text
id
title
description

requirements
choices[]

success_outcomes[]
failure_outcomes[]

heat_change
resource_changes

available_traits[]
available_stats[]

follow_up_events[]
```

Example:

``` text
Encounter:
"The Guard Is Looking Directly At You"

Choice 1:
Hide behind laundry.
Requirement: Stealth 6

Choice 2:
Talk to guard.
Requirement: Charisma 7

Choice 3:
Send Big Dave.
Requirement: Strength 8

Choice 4:
Do absolutely nothing.
Luck check.
```

The game should clearly explain the consequences when appropriate.

------------------------------------------------------------------------

# 15. Skill Check System

Create one reusable skill-check function.

Suggested formula:

``` text
base_chance =
    40
    + (stat - 5) * 8
    + trait_modifiers
    + powerup_modifiers
    + situation_modifiers
```

Clamp result between approximately 5% and 95%.

Then roll random chance.

Do not make outcomes completely deterministic.

A character with 10 Intelligence should usually succeed at an
intelligence task, but should not have absolute certainty.

Luck can modify the roll.

Allow critical success and critical failure where appropriate.

Example:

``` text
Critical Success:
Extra reward
Reduced Heat
Funny special outcome

Success:
Normal positive outcome

Failure:
Normal consequence

Critical Failure:
Bad consequence
Extra Heat
Funny catastrophic outcome
```

Keep the system easy to tune.

------------------------------------------------------------------------

# 16. Heat System

Create a global run-level Heat value.

Range:

``` text
0-100
```

Display it prominently.

Suggested states:

``` text
0-25
Guards relaxed

26-50
Guards suspicious

51-75
Security increased

76-90
High alert

91-100
LOCKDOWN
```

Actions can: - increase Heat - decrease Heat - temporarily freeze Heat -
manipulate Heat

High Heat should change encounters.

Example: At high Heat: - more guards - harder stealth - fewer safe
options - more aggressive events - different final escape conditions

------------------------------------------------------------------------

# 17. Resources

Initial resources:

## Money

Used for: - bribes - black-market items - certain shortcuts

## Health

Each character can be injured.

Health reaching zero should not necessarily instantly end the run.

Instead: - unconscious - unavailable - medical event - party composition
changes

## Heat

Global detection level.

## Time

Optional resource representing prison routine progression.

Keep resource systems simple.

------------------------------------------------------------------------

# 18. Power-Up System

This is one of the game's signature mechanics.

After qualifying encounters, show 5 randomly selected power-ups.

Exactly one should contain a hidden catch.

The UI initially presents all five as plausible choices.

Example:

``` text
+2 STEALTH
+20 MONEY
MEDICAL KIT
GUARD SCHEDULE
MYSTERIOUS KEY
```

The player doesn't know which has a catch.

The catch may trigger: - immediately - later - conditionally - during
the final escape

Examples:

``` text
+3 Stealth
Catch:
Character becomes overconfident and has a chance to increase Heat.

Medical Kit
Catch:
Heals the target but consumes money later.

Mysterious Key
Catch:
It opens something... but not necessarily something useful.

Extra Money
Catch:
Money is counterfeit.

Perfect Map
Catch:
The map is upside down.
```

Important: The catch should be **funny**, not purely punitive.

Players should sometimes deliberately choose risky upgrades because the
possible upside is worth it.

------------------------------------------------------------------------

# 19. Power-Up Data Model

Suggested:

``` text
id
name
description
rarity

effects[]
catch_type
catch_description_hidden
catch_trigger

target_type
```

The actual catch must not be visible before selection.

After the catch is triggered, reveal it clearly.

------------------------------------------------------------------------

# 20. Party Synergy

Implement a simple synergy system.

Certain combinations of traits/classes can produce bonuses.

Examples:

``` text
Hacker + Engineer
Better technical checks.

Grandma + Charismatic character
Better social checks.

Two strong characters
Better physical actions.

Lucky + Risky character
More critical outcomes.
```

Do not hard-code every possible combination.

Use generic tags where possible:

``` text
tags:
strength
tech
social
stealth
chaos
luck
```

Synergy rules can reference tags.

------------------------------------------------------------------------

# 21. Character Status Effects

Implement a small set:

``` text
Healthy
Injured
Scared
Angry
Unconscious
Exhausted
Suspicious
```

Effects can modify stats.

Example:

``` text
Injured:
-2 Strength

Scared:
-2 Charisma
+1 Stealth

Angry:
+2 Strength
-2 Stealth

Exhausted:
-1 Speed
```

Make these data-driven.

------------------------------------------------------------------------

# 22. Comedy / Writing Direction

The game should take its mechanics seriously while treating the
characters as idiots.

Tone: - absurd - dry - sarcastic - playful - occasionally chaotic

Avoid: - grim realistic prison violence - excessive gore - depressing
tone

Prefer consequences such as:

``` text
"You successfully distracted the guard.

Unfortunately, you distracted him so well that he forgot where he was."

"You successfully hacked the security system.

You accidentally changed the prison's Wi-Fi password."

"Big Dave broke the door.

Technically, he also broke the wall.

Technically, he is still proud."
```

Build a reusable dialogue/event system so these can be edited later.

------------------------------------------------------------------------

# 23. Failure Design

Do NOT rely on generic "Game Over".

Failures should create stories.

Possible outcomes:

``` text
Caught
Injured
Party member lost
Heat reaches 100
Resources depleted
Wrong route chosen
Cursed power-up triggers
Catastrophic event
```

Every failure should have a funny explanation.

Example:

``` text
RUN FAILED

Reason:
Big Dave attempted to intimidate the guard.

The guard was not intimidated.

Big Dave was.

The party lost 12 Heat.
```

------------------------------------------------------------------------

# 24. Final Escape

The final escape should be a multi-step climax.

At minimum:

``` text
Approach Escape
    ↓
Choose escape strategy
    ↓
Use party strengths
    ↓
Resolve 2-3 final checks
    ↓
Success / failure
```

Possible routes:

### Tunnel

Best for: - Intelligence - Strength - Stealth

### Disguise

Best for: - Charisma - Intelligence - Stealth

### Riot

Best for: - Strength - Chaos - Luck

Add a fourth "ridiculous" route if easy:

### Completely Stupid Plan

Mostly Luck.

------------------------------------------------------------------------

# 25. Run Summary

After the run display:

``` text
ESCAPE ATTEMPT COMPLETE

Result:
ESCAPED / CAUGHT

Days Survived:
12

Rooms Cleared:
9

Guards Fooled:
7

Heat:
83

Money:
$43

Party:
Tony
Grandma
Big Dave
Hacker
Lawyer

Notable Events:
- Big Dave punched a vending machine.
- Hacker accidentally opened the laundry room.
- Grandma successfully bribed a guard.

FINAL SCORE:
7420
```

Make the summary fun enough that players want to replay.

------------------------------------------------------------------------

# 26. Main Menu

Implement:

``` text
JAILBREAK

[ NEW RUN ]

[ HOW TO PLAY ]

[ SETTINGS ]

[ QUIT ]
```

For Web: - Quit can simply return to title/menu.

Settings: - master volume - music volume - sound effects - text speed -
fullscreen/windowed if supported

------------------------------------------------------------------------

# 27. Save System

For MVP: - save settings - optionally save current run

At minimum support: - seed - current game state - party - stats -
power-ups - Heat - current map position - resources

Use a versioned save structure so it can evolve.

------------------------------------------------------------------------

# 28. Random Seeds

Every run should have a seed.

Display the seed somewhere in the run summary/debug menu.

Example:

``` text
RUN SEED: 839201
```

Add a debug option to start a run with a specific seed.

This is extremely useful for testing and balancing.

------------------------------------------------------------------------

# 29. Developer / Debug Tools

Create a debug mode accessible through a simple key or development-only
menu.

Useful commands:

``` text
Regenerate Party
Regenerate Prison
Set Heat
Add Money
Heal Party
Damage Party
Give Power-up
Force Event
Win Run
Lose Run
Set Seed
```

Do not expose these in release builds if easy to disable.

------------------------------------------------------------------------

# 30. Code Organization

Prefer a structure similar to:

``` text
project/
├── project.godot
│
├── scenes/
│   ├── main_menu/
│   ├── character_selection/
│   ├── recruitment/
│   ├── party/
│   ├── prison_map/
│   ├── encounter/
│   ├── powerups/
│   └── results/
│
├── scripts/
│   ├── managers/
│   ├── systems/
│   ├── ui/
│   └── utilities/
│
├── data/
│   ├── characters/
│   ├── traits/
│   ├── events/
│   ├── powerups/
│   └── prisons/
│
├── assets/
│   ├── characters/
│   ├── environments/
│   ├── ui/
│   ├── icons/
│   ├── audio/
│   └── fonts/
│
├── tests/
│
└── docs/
```

Adapt if Godot best practices suggest a better structure.

------------------------------------------------------------------------

# 31. Data-Driven Editing

This is extremely important.

I want to be able to later open a data file and change:

``` text
Character name
Stats
Traits
Trait effects
Descriptions
Event choices
Success chance
Failure outcome
Heat changes
Power-up effects
Power-up catches
```

without needing to understand the whole codebase.

Prefer resources or JSON for content.

Keep game logic separate from content.

------------------------------------------------------------------------

# 32. Content Examples

Create an initial cast.

Do not treat these names/examples as final. They are starter content
that I can replace.

Suggested archetypes:

1.  Big Dave

-   huge
-   strong
-   stupid
-   loud

2.  Professor

-   intelligent
-   weak
-   technical

3.  Grandma

-   charismatic
-   deceptively capable
-   physically weak

4.  Hacker

-   very intelligent
-   socially awkward

5.  Lawyer

-   very charismatic
-   mediocre physically

6.  Gym Bro

-   strong
-   fast
-   not very intelligent

7.  Pickpocket

-   stealthy
-   lucky

8.  Con Artist

-   charismatic
-   manipulative

9.  Janitor

-   knows the prison
-   average stats

10. Escape Artist

-   stealth
-   speed
-   low strength

Create enough additional characters to reach roughly 15-20.

Give each a distinct visual appearance.

------------------------------------------------------------------------

# 33. Art Asset Strategy

Because this is a first draft, use an efficient asset strategy.

Characters: - reusable base body - interchangeable hair - face - skin
tone - accessories - uniform variations - portraits generated from the
same visual system

Environment: - modular tiles - walls - floors - doors - tables - beds -
pipes - vents - lockers - security equipment

UI: - custom panels - buttons - stat icons - trait icons - resource
indicators

If custom generated vector/cartoon assets are easier than raster art,
use them.

The visual system should make it easy to replace individual assets
later.

------------------------------------------------------------------------

# 34. Audio

Add basic audio where possible.

At minimum: - button click - selection - success - failure - warning -
power-up selection - power-up reveal - Heat increase - room transition -
final escape - victory - defeat

Music: - main menu - gameplay loop - high heat tension - final escape -
result screen

Use legally distributable/original audio.

If using generated/simple synthesized audio, that is acceptable for the
prototype.

------------------------------------------------------------------------

# 35. Animations

Do not overbuild.

At minimum: - character idle - character selection reaction - successful
action - failed action - injured reaction - power-up reveal - Heat
warning - map transition

Use simple tweening where full animation is unnecessary.

------------------------------------------------------------------------

# 36. UX Requirements

The player should always understand:

1.  Where they are.
2.  What they can do.
3.  What stats matter.
4.  What the risk is.
5.  What the consequences were.
6.  What changed after an action.

Avoid unexplained randomness.

If randomness causes failure, explain it.

Example:

``` text
STEALTH CHECK

Your Stealth: 8
Trait bonus: +2
Situation: -1

Success chance: 82%

ROLL: 41

SUCCESS
```

This creates trust in the system.

------------------------------------------------------------------------

# 37. Mobile/Web Friendly Design

Even though desktop is the initial focus:

-   avoid tiny buttons
-   don't rely on hover-only interactions
-   use scalable UI
-   use resolution-independent layouts
-   avoid excessive keyboard dependence
-   keep important interactions clickable
-   keep game state independent of presentation

The same core game logic should eventually work on: - Web -
Windows/Linux/macOS - Android - iOS

------------------------------------------------------------------------

# 38. Performance

This game should be lightweight.

Target: - fast startup - minimal loading - smooth UI - no unnecessary 3D
systems - avoid expensive per-frame logic - procedural generation should
happen at run start or transition points

For Web: - minimize asset size - compress appropriately - avoid giant
textures - keep initial download reasonable

------------------------------------------------------------------------

# 39. Testing Requirements

Add basic automated tests for:

### Stats

-   stat calculations
-   modifiers

### Skill checks

-   min/max probabilities
-   trait modifiers
-   critical results

### Recruitment

-   exactly 3 candidates
-   valid candidate generation
-   no impossible candidate data

### Party

-   maximum 5
-   no duplicate unique characters unless explicitly allowed

### Heat

-   clamped 0-100

### Power-ups

-   exactly 5 choices
-   exactly 1 hidden catch in the standard selection
-   effects apply correctly

### Prison generation

-   generated map has valid start
-   generated map has valid escape route
-   no disconnected required path

### Save/load

-   state survives serialization

------------------------------------------------------------------------

# 40. Development Order

Implement in this order.

## Phase 1 --- Project Foundation

-   create Godot project
-   configure resolution
-   establish folder structure
-   establish basic scene flow
-   create game state
-   create random seed system

## Phase 2 --- Characters

-   character data
-   character generator
-   character portraits
-   character UI
-   stats
-   traits
-   party system

## Phase 3 --- Recruitment

-   main character selection
-   3 candidate recruitment UI
-   four recruitment rounds
-   party lock

## Phase 4 --- Prison

-   room data
-   procedural generation
-   prison map
-   navigation between rooms

## Phase 5 --- Encounters

-   encounter data
-   choices
-   skill checks
-   outcomes
-   consequences
-   party status

## Phase 6 --- Heat + Resources

-   Heat
-   money
-   health
-   status effects
-   time/progress

## Phase 7 --- Power-ups

-   random generation
-   5-card UI
-   hidden catch
-   effect system
-   reveal system

## Phase 8 --- Escape

-   escape routes
-   final checks
-   victory
-   defeat
-   funny endings

## Phase 9 --- Polish

-   animations
-   sound
-   music
-   particles
-   UI transitions
-   screen shake where appropriate
-   feedback
-   better typography

## Phase 10 --- Testing

-   automated tests
-   multiple full runs
-   edge cases
-   seeded reproducibility
-   Web build

------------------------------------------------------------------------

# 41. Definition of Done for First Playable Build

The prototype is considered complete when I can:

1.  Launch the game.
2.  Start a new run.
3.  Choose one of three starting prisoners.
4.  Recruit four more prisoners.
5.  View my five-person party.
6.  Enter a randomly generated prison.
7.  Navigate between rooms.
8.  Encounter events.
9.  Choose actions.
10. Have actions resolved using stats/traits/randomness.
11. See consequences.
12. Watch Heat change.
13. Lose health / apply status effects.
14. Receive five power-up choices.
15. Select one.
16. Eventually reach an escape attempt.
17. Choose an escape strategy.
18. Win or lose.
19. See a funny run summary.
20. Start another run and get a different experience.

The entire loop must be playable without developer intervention.

------------------------------------------------------------------------

# 42. Important Design Principle

The game should create **stories**, not just numbers.

The player should remember:

> "My team almost escaped but Grandma got caught because Big Dave
> accidentally set off the alarm."

rather than:

> "I lost because my stealth value was too low."

Numbers support the story.

They should not replace it.

------------------------------------------------------------------------

# 43. Future Expansion --- DO NOT BUILD YET

Design architecture so these can be added later:

### More prisons

-   maximum security
-   military prison
-   alien prison
-   underwater prison
-   luxury prison

### More escape methods

-   helicopter
-   tunnel
-   disguise
-   bribery
-   riot
-   fake transfer
-   ridiculous plans

### More characters

50+

### More events

100+

### Meta progression

Unlock: - prisoners - traits - events - power-ups - prisons

### Achievements

### Daily seeded runs

### Challenge modes

### Steam integration

### Mobile adaptation

### Localization

Do not implement these unless the MVP is already fun.

------------------------------------------------------------------------

# 44. Release Roadmap

After the first playable prototype:

``` text
Prototype
   ↓
Internal playtesting
   ↓
Small Web build
   ↓
Collect feedback
   ↓
Improve core loop
   ↓
Steam demo
   ↓
Steam wishlist campaign
   ↓
Polish + content
   ↓
Steam launch
   ↓
Mobile adaptation
   ↓
Android
   ↓
iOS
```

Do not begin Steam/mobile-specific work before the core game is fun.

------------------------------------------------------------------------

# 45. Codex Working Rules

When implementing:

1.  Inspect the repository before changing anything.
2.  If no game exists, initialize the Godot project.
3.  Keep the project runnable after every major phase.
4.  Prefer small, testable systems.
5.  Avoid giant monolithic scripts.
6.  Avoid hard-coded content when data-driven content is practical.
7.  Add comments only where they clarify non-obvious behavior.
8.  Keep names descriptive.
9.  Do not introduce unnecessary dependencies.
10. Do not remove working features to simplify implementation.
11. If a requested feature is ambiguous, choose a sensible default and
    document it.
12. If something cannot be implemented exactly, implement the closest
    useful version and continue.
13. Test the game after major changes.
14. Fix errors rather than leaving TODO placeholders for core
    functionality.
15. Build actual visuals and UI, not only backend systems.

------------------------------------------------------------------------

# 46. Final Instruction to Codex

Start by creating the complete first playable vertical slice.

Do not attempt to build the entire future game.

Prioritize this sequence:

``` text
PLAYABLE LOOP
    ↓
CHARACTERS
    ↓
RECRUITMENT
    ↓
PARTY
    ↓
PRISON GENERATION
    ↓
ENCOUNTERS
    ↓
SKILL CHECKS
    ↓
HEAT
    ↓
POWER-UPS
    ↓
ESCAPE
    ↓
RESULT
    ↓
POLISH
```

At the end, the game should feel like a real small indie game prototype
rather than a technical demo.

The first build does not need perfect balance.

It DOES need: - coherent art - readable UI - working game loop -
meaningful choices - random replayability - funny outcomes - clean
code - easy-to-edit content

Build the game now.
