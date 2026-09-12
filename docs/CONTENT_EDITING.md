# Editing the content

Everything the game says, and almost everything it decides, lives in `data/`.
Nothing here requires touching GDScript. Godot reloads all of it on launch.

If a file fails to parse, the game shows a dedicated error screen naming the
file rather than starting up broken. `python3 tools/balance_sim.py` will also
read your edits and complain about them, which is faster than launching.

---

## The six stats

`strength`, `intelligence`, `stealth`, `charisma`, `luck`, `speed` — all 1-10.

Luck is special twice over: it is a stat like any other, and it also adds a small
bonus to every check that is not already a Luck check.

---

## characters.json

```json
{
  "id": "big_dave",
  "name": "Big Dave",
  "nickname": "The Wall",
  "description": "Shown on the recruitment card.",
  "stats": { "strength": 10, "intelligence": 2, "stealth": 2,
             "charisma": 5, "luck": 5, "speed": 4 },
  "max_health": 12,
  "traits": ["strong_as_hell", "gym_bro", "walking_alarm"],
  "tags": ["strength", "chaos"],
  "quips": {
    "success": ["Printed under the outcome when they succeed."],
    "failure": ["...and when they don't."]
  },
  "visual": { "body": "huge", "skin": "#e0a878", "...": "see docs/ART.md" }
}
```

- `traits` must reference ids in `traits.json`. A typo means the trait silently
  does nothing, which is why `tests/test_content.gd` checks every reference.
- `tags` feed the synergy system. A character also inherits the tags of every
  trait they carry, so you rarely need many here.
- `max_health` is the main counterweight to high stats. The starting cast runs
  7-13; strong characters are fragile and vice versa.

## traits.json

Traits matter more than raw stats, and they are the main thing worth writing.

```json
{
  "id": "loudmouth",
  "name": "Loudmouth",
  "description": "Shown on the card, so write it for a player.",
  "polarity": "positive | negative | neutral",
  "tags": ["social", "chaos"],
  "effects": [
    { "type": "check_bonus", "value": 10, "contexts": ["social"] },
    { "type": "heat_on_fail", "value": 9 }
  ]
}
```

`polarity` is used by the recruitment generator to balance the wildcard trait it
occasionally hands out, and to colour the chip on the card.

### Effect types

Every effect may carry `contexts`, `min_heat` and `max_heat`. `contexts` is
matched against the **tags on the encounter choice**; an empty or missing list
means "always". `min_heat`/`max_heat` gate the effect to a Heat range.

| type | fields | what it does |
|---|---|---|
| `stat_bonus` | `stat`, `value` | Adds to the stat for this check. Worth 8% per point. |
| `check_bonus` | `value` | Adds percentage points directly to the success chance. |
| `crit_success_chance` | `value` | Widens the critical success band. |
| `crit_fail_chance` | `value` | Widens (positive) or narrows (negative) the critical failure band. |
| `save_chance` | `value` | Percent chance to convert a plain failure into a success. |
| `heat_on_success` | `value` | Heat change when the check succeeds. |
| `heat_on_fail` | `value` | Heat change when it fails. |
| `money_on_success` | `value`, `chance` | Cash on success; `chance` is a percentage. |
| `money_on_fail` | `value`, `chance` | Usually negative. |
| `grow_stat` | `stat`, `value`, `on`, `chance` | Permanent stat gain. `on` is `success` or `failure`. |
| `damage_taken` | `value` | Flat damage modifier. Negative is armour. Damage never drops below 1. |
| `heat_multiplier` | `value` | Scales all Heat this character generates. `-0.3` means 30% less. |

### Choice tags in use

`physical`, `tech`, `planning`, `social`, `deception`, `stealth`, `tunnel`,
`speed`, `medical`, `luck`, `chaos`. They are just strings — invent more, and
write traits, synergies and power-ups that reference them.

---

## events.json

```json
{
  "id": "guard_stare",
  "title": "The Guard Is Looking Directly At You",
  "rooms": ["cell_block", "cafeteria"],
  "weight": 12,
  "min_heat": 0,
  "max_heat": 100,
  "requires_injured": false,
  "description": "Two or three sentences. This is where the comedy lives.",
  "choices": [ ... ]
}
```

- `rooms` lists room ids, or `"any"` to make it available everywhere.
- `weight` is relative within the pool for that room. Unseen events are always
  preferred over repeats within a run.
- `min_heat`/`max_heat` are how you write events that only exist when the prison
  is calm, or only once the dogs are out.
- `requires_injured` gates the event on somebody actually being hurt.

### Choices

```json
{
  "text": "Slip behind the laundry cart.",
  "stat": "stealth",
  "tags": ["stealth"],
  "difficulty": 0,
  "hint": "Optional line under the button.",
  "cost_money": 25,
  "requires": { "trait": "eats_anything", "stat": { "intelligence": 7 } },
  "crit_success": { ... }, "success": { ... },
  "failure": { ... }, "crit_failure": { ... }
}
```

- `difficulty` is in whole steps. Each step is worth 8 percentage points;
  negative makes it easier. Risky map rooms add +1 on top, secret rooms -1.
- `requires` locks the choice. Locked choices are still shown, greyed out, with
  the requirement spelled out — that is deliberate, so the player can see what a
  different crew would have unlocked.
- `"auto": true` makes a choice resolve with no check at all. It needs only a
  `success` block. Every event should ideally have one thing anybody can do.

All four outcome tiers are required on a checked choice. `tests/test_content.gd`
fails the build if one is missing.

### Outcomes

```json
{
  "text": "What happened. Write it as a story, not a stat change.",
  "heat": -3,
  "money": 20,
  "damage": 1,
  "heal": 2,
  "status": "scared",
  "note": "bribed a guard with a sandwich"
}
```

All fields are optional.

- `heat` — positive raises it and is scaled by the actor's calming traits;
  negative lowers it and is applied at `HEAT_RELIEF_SCALE` (currently 50%) of
  face value. See `docs/BALANCE.md` for why.
- `money` — positive gains are multiplied by the room's reward multiplier, so
  risky and secret rooms genuinely pay better.
- `damage` — applied to the character who took the action.
- `heal` — applied to the whole crew.
- `status` — one of `healthy`, `injured`, `scared`, `angry`, `exhausted`,
  `suspicious`, `unconscious`.
- `note` — a short clause, prefixed with the character's name, collected into
  **Notable Events** on the run summary. Write it so `"Grandma Ruth " + note`
  reads as a sentence. These are the lines people screenshot; spend effort here.

---

## powerups.json and catches.json

The signature mechanic works by keeping the two apart. Five power-ups are drawn,
and then **one randomly chosen card has a randomly chosen catch attached to it**.
Nothing is baked in, so the same card is clean in one run and a trap in the next
and can never be memorised.

```json
{
  "id": "quiet_shoes", "name": "Quiet Shoes",
  "rarity": "common | uncommon | rare",
  "target": "party | one | run",
  "description": "Shown on the card. Say exactly what it does.",
  "flavor": "One line, small print.",
  "effects": [ { "type": "stat_bonus", "stat": "stealth", "value": 2 } ]
}
```

Power-up effects use the trait types above, plus these run-level ones:

| type | what it does |
|---|---|
| `max_health` / `heal` / `revive` | Immediate, whole crew. |
| `money` / `heat` | Immediate one-off. |
| `money_per_room` / `heat_decay` / `heat_per_room` | Applied on entering each room. |
| `escape_bonus` | Percentage points on every check during the final escape. |

```json
{
  "id": "counterfeit",
  "trigger": "delayed", "after": 2,
  "hint_after": "Leaked in the crew screen a room or more later.",
  "reveal_text": "The joke. This is the payoff - make it land.",
  "effects": [ { "type": "money", "value": -70 } ]
}
```

Triggers: `immediate`, `next_encounter`, `on_fail`, `on_crit_fail`, `delayed`
(with `after`), `at_escape`, `on_heat_above` (with `threshold`), `on_room_enter`.
The special effect `cancel_powerup` switches the power-up off entirely.

Keep catches funny rather than merely punishing. A player who laughs at a trap
takes the risk again; a player who feels cheated stops.

---

## rooms.json, synergies.json, status_effects.json, escape_routes.json

- **rooms.json** — room types and the five Heat bands. `affinity` nudges which
  stat secret gates ask for; `danger` and `color` drive presentation. Adding a
  room means adding an `icon` case in `scripts/ui/room_icon.gd` and a drawing
  branch in `scripts/ui/room_scene.gd`, or it falls back to a generic look.
- **synergies.json** — matched on **tags**, never on character ids, so they keep
  working after you rewrite the whole cast. `count` is how many distinct crew
  members must carry the tag; `requires_distinct_tags` needs one of each.
- **status_effects.json** — `stat_mods` apply to every check while active;
  `duration` is in rooms, `-1` meaning until healed.
- **escape_routes.json** — three steps each, `required_passes` of them to win.
  `heat_scaling` is how badly a loud run hurts this route; the riot's is
  negative, which is why it gets easier the worse things have got.
