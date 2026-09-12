# Jailbreak

> Assemble five ridiculous prisoners and attempt the world's dumbest prison escape.

A 2D comedy roguelite/strategy prototype in **Godot 4**. You pick a crew of five
from a rotating cast, walk them through a procedurally generated prison, and make
a series of increasingly poor decisions until you either get over the wall or
become an anecdote.

This is the first playable vertical slice built from `plan.md`. Every character,
trait, event, power-up and escape route lives in `data/*.json` and can be
rewritten without touching a line of code.

---

## How to run

### 1. Install Godot

You need **Godot 4.3 or newer** (developed and tested against 4.7.2). There are
no other dependencies, no plugins, no asset downloads and no package manager.

**macOS**

```bash
brew install --cask godot
godot --version        # e.g. 4.7.2.stable.official
```

Or download the .dmg from [godotengine.org/download](https://godotengine.org/download).

**Linux / WSL** — one self-contained binary:

```bash
mkdir -p ~/.local/share/godot ~/.local/bin
cd ~/.local/share/godot
curl -sSLO https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
python3 -c "import zipfile; zipfile.ZipFile('Godot_v4.7.2-stable_linux.x86_64.zip').extractall('.')"
chmod +x Godot_v4.7.2-stable_linux.x86_64
ln -sf ~/.local/share/godot/Godot_v4.7.2-stable_linux.x86_64 ~/.local/bin/godot
godot --version        # 4.7.2.stable.official
```

**Windows** — `winget install GodotEngine.GodotEngine`, or the .zip from the
same page. Substitute `godot.exe` for `godot` in everything below.

### 2. First-time import (clone / fresh checkout)

The `.godot/` cache is not in git. Import once so `class_name` scripts register:

```bash
cd /path/to/jailbreak
godot --headless --path . --import --quit-after 1
```

Skip this if you already opened the project in the Godot editor.

### 3. Play

```bash
cd /path/to/jailbreak
godot --path .
```

Or open the folder from the Godot project manager and press **F5**. The whole game
is one scene (`scenes/main.tscn`); screens are built in code and swapped by
`scripts/main.gd`.

| | |
|---|---|
| `F1` | debug menu — set seed, set Heat, grant power-ups, jump to the escape, win/lose |
| `F11` | fullscreen |

Everything else is mouse or touch. No interaction depends on hover or on the
keyboard, and every control is at least 52px tall.

### Tests

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

139 assertions, about 30 seconds, exit code 0 on success. Covers stat maths,
skill-check clamping and critical bands, recruitment fairness, Heat, power-up
offers and hidden catches, prison connectivity across 300 seeds, save/load round
trips, and **60 complete runs played end to end with no UI involved**.

### Screen smoke test

```bash
godot --path . tests/screen_smoke.tscn
```

Walks all eleven screens with a fixed seed, drives an encounter through to a
resolved skill check, and writes a PNG of each to
`user://screens/` (the absolute path is printed on exit — on Linux that is
`~/.local/share/godot/app_userdata/Jailbreak/screens/`). It fails loudly if a
screen renders blank. This needs a display; the headless suite above does not.

### Balance tool

```bash
python3 tools/balance_sim.py --runs 4000
python3 tools/balance_sim.py --runs 500 --verbose    # also lists events that never fired
```

A Python mirror of the rules that reads the same `data/` files, so you can retune
JSON and see the effect in about ten seconds. It also reports content problems —
an unwalkable map, an encounter the crew can meet no condition of, an event no
room can fire. See `docs/BALANCE.md`.

### If the audio is silent

On a bare WSL or container install Godot prints `libasound.so.2: cannot open
shared object file` and falls back to a dummy audio driver. The game is
unaffected apart from being silent. Install the system audio libraries to get
sound: `sudo apt install libasound2t64 libpulse0`.

---

## What is in the box

| | |
|---|---|
| Characters | 20, each procedurally drawn |
| Traits | 28, fully data-driven |
| Encounters | 34, with 3-4 choices each and four outcome tiers per choice |
| Rooms | 13 types, each with its own drawn illustration |
| Power-ups | 28, plus 15 hidden catches attached at random |
| Escape routes | 4, three checks each |
| Endings | escaped, caught, and total catastrophe |

Balanced so that a perfect-information optimiser wins about 75% of runs and
random play about 17%, which puts a real player somewhere in between. The
figures are reproducible with the balance tool below.

A run is about 10 rooms. Every run has a seed, shown in the status bar and the
summary; replaying a seed reproduces the prison, the candidates and the rolls.

---

## Project layout

```
project.godot            Godot config, autoloads, display settings
scenes/main.tscn         The only scene in the project

scripts/
  main.gd                Screen router - owns the HUD, backdrop and debug panel
  autoload/
    content.gd           Loads data/*.json once at startup (singleton: Content)
    rng_service.gd       Seeded RNG - every random decision goes through it (Rng)
    game_state.gd        The whole run: party, Heat, money, map, power-ups (Game)
    audio_manager.gd     Synthesises all sound and music at runtime (Audio)
    save_system.gd       Settings and run saves under user:// (SaveSystem)
  systems/               Pure rules, no UI
    prisoner.gd          One crew member
    skill_check.gd       The single check function everything routes through
    check_result.gd      An inspectable check result, including the arithmetic
    character_factory.gd Recruitment candidate generation
    prison_generator.gd  The layered map, plus a connectivity validator
    encounter_engine.gd  Event selection and choice gating
    powerup_system.gd    The five-card offer and the hidden catch
    effect_resolver.gd   Turns data dictionaries into state changes
    synergy.gd           Tag-based party synergies
    escape_system.gd     The final three checks
  ui/                    Reusable widgets, all drawn in code
  screens/               One file per screen

data/                    All content. This is the file you want.
tests/                   Headless test suite + the screen smoke test
tools/balance_sim.py     Python balance and content checker
docs/                    Content, art and balance references
```

---

## Editing the game

Start with `docs/CONTENT_EDITING.md`. The short version:

- **A new character** - copy a block in `data/characters.json`, give it a new
  `id`, and pick `visual` fields from the lists in `docs/ART.md`. It will be
  drawn, portraited and recruitable immediately.
- **A new trait** - copy a block in `data/traits.json`. The `effects` list is
  interpreted generically; the legal types are documented and all of them are
  already used by something.
- **A new encounter** - copy a block in `data/events.json`. Four outcome tiers
  per choice, any of which may change Heat, money, health, or status.
- **Tuning** - the numbers that decide how hard the game is are six constants,
  listed in `docs/BALANCE.md`.

Every JSON file opens with a `_readme` key explaining its own schema.

---

## Exporting

`export_presets.cfg` ships with Web, Linux and Windows presets. The one setting
that matters is `include_filter="*.json"` - Godot does not treat `.json` as a
resource, so without it the entire `data/` folder is left out of the build. If
that ever happens the game says so on a dedicated screen instead of failing in a
dozen confusing ways.

The project renders with the GL Compatibility backend and a 1280x720 base
viewport that scales, so the same build is intended to work on desktop, web and
eventually touch. All interactions are clickable with a 52px minimum target
height; nothing depends on hover or on the keyboard.

---

## Disabling the debug menu

The `F1` menu is gated on `Game.debug_enabled` in
`scripts/autoload/game_state.gd`. Set it to `false` for a release build, or
delete `scripts/ui/debug_panel.gd` and the two references to it in
`scripts/main.gd`.

---

## Assets and licensing

There are no third-party assets. Every portrait, room, icon, sound effect and
piece of music is generated at runtime from code in `scripts/ui/` and
`scripts/autoload/audio_manager.gd`, so the whole project is distributable
without attribution obligations. `docs/ART.md` explains how the drawing system
works and how to extend or replace it.
