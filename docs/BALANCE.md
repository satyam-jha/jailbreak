# Balance

## The six numbers that decide how hard the game is

| constant | file | current | effect |
|---|---|---|---|
| `BASE_CHANCE` | `scripts/systems/skill_check.gd` | 34 | Success chance for a stat of 5 with no modifiers. Moves everything at once. |
| `MAX_CHANCE` | `scripts/systems/skill_check.gd` | 85 | The ceiling. Deliberately under 100 — a maxed character is reliable, never certain. This is the single strongest dial. |
| `HEAT_RELIEF_SCALE` | `scripts/systems/effect_resolver.gd` | 0.5 | Fraction of a written Heat *reduction* that is actually applied. Increases land in full. |
| `HEAT_DRIFT_BASE` / `_PER_LAYER` | `scripts/autoload/game_state.gd` | 3.0 / 0.8 | Heat added on entering each room, growing with depth. This is the run clock. |
| `MIN_LAYERS` / `MAX_LAYERS` | `scripts/systems/prison_generator.gd` | 10 / 13 | Run length. Multiplies every other pressure. |
| `required_passes` | `data/escape_routes.json` | 2 of 3 | How forgiving the climax is. |

`PER_POINT` (8) is the exchange rate between a stat point and a percentage point,
and `difficulty` in the content is denominated in the same unit. Changing it
rescales every trait and every event difficulty at once, so change the others
first.

## Why Heat relief is halved

Without it, a competent crew simply drives Heat to zero and stays there: most
successful outcomes reduce Heat, and a good player succeeds most of the time, so
the resource the whole game is built around drifts in the player's favour and the
run has no clock. Halving relief while leaving increases at face value means
Heat ratchets upward over a run — you can slow it, but not reverse it — which is
what makes the last few rooms tense and the escape route choice matter.

The alternative was rewriting the Heat number on all ~130 outcomes in
`events.json`, which would have made the content harder to edit for no benefit.

## Where the numbers came from

`tools/balance_sim.py` reimplements the rules in Python against the same `data/`
files and plays thousands of runs under two strategies:

- **smart** — a perfect-information optimiser. It computes the exact odds of
  every choice and always takes the best one, prefers risky rooms while quiet
  and safe rooms once loud, takes the rarest power-up, and picks the escape route
  its crew actually suits. This is the ceiling; no human plays this well.
- **random** — legal moves chosen at random. This is the floor.

Current figures over 2000 runs each:

```
SMART    escaped 74%   caught 25%   disaster 1%   ~10 rooms   peak Heat median 91
RANDOM   escaped 19%   caught 80%   disaster 1%   ~7.5 rooms  peak Heat median 100
```

A real player should land somewhere between, which is roughly the 35-50% win
rate a comedy roguelite wants: losing has to be common enough to be funny and
rare enough to be annoying.

The gap between the two columns is the part that matters. If a change makes smart
and random converge, it has removed a decision rather than balanced one.

## Using the tool

```bash
python3 tools/balance_sim.py --runs 4000
python3 tools/balance_sim.py --runs 500 --verbose    # also lists events that never fired
```

It reports win rates, rooms cleared, peak Heat, money, power-ups taken, how often
hidden catches actually go off, and how many distinct events fired. It also fails
loudly on three content problems the game itself would only reveal in play:

- `bad_map` — a generated prison that cannot be walked start to finish;
- `stalled` — a run that reached a room with no enterable exit;
- `no_choice` — an encounter where the crew qualified for nothing.

All three should always read `none`.

Every event should fire over a few thousand runs. One that never does is usually
gated to a room that generation cannot produce, or to a Heat band the run never
reaches.

**The caveat:** the simulator is a second implementation, not the game. The
GDScript in `scripts/systems/` is authoritative. If you change a formula there,
change `check_chance()` and friends in the simulator too, or it will quietly
start giving you confident wrong answers. The environment variables at the top
(`JB_BASE`, `JB_MAX`, `JB_RELIEF`, `JB_DRIFT`, `JB_DRIFTL`) exist so you can
sweep a value before committing it to the GDScript.

## Tuning without touching code

Most balance work should happen in `data/`:

- **an event is too generous** — lower its outcome `money`/`heat` numbers, or
  raise the `difficulty` on its easiest choice;
- **a trait is dominating** — lower its `value`, or narrow its `contexts` so it
  only applies to a specific kind of action;
- **a power-up is an auto-pick** — move it to `rare`, or give the effect a
  downside by pairing it with a second, negative effect;
- **a route is always chosen** — raise its `heat_scaling`, or add difficulty to
  its middle step.

Re-run the simulator after any of these. It takes about ten seconds for 4000
runs and will tell you immediately whether you moved the win rate or just moved
a number.
