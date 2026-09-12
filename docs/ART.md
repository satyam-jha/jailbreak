# The art system

There are no image files in this project. Every portrait, room, icon and piece of
UI is drawn at runtime from code, which means:

- nothing to license, credit, or ship;
- a new character costs a JSON block, not a drawing;
- the whole game scales cleanly to any resolution;
- the web build is tiny.

The style is deliberately chunky: thick dark outlines, flat fills, exaggerated
proportions, strong silhouettes. Characters should be identifiable at 44px.

---

## Characters — `scripts/ui/character_portrait.gd`

Each character is composed from named parts listed in their `visual` block.
Everything is drawn in a 200x240 virtual space and scaled to the control, so the
same code produces a 44px map thumbnail and a 320px hero portrait.

```json
"visual": {
  "body": "huge", "skin": "#e0a878",
  "hair": "buzz", "hair_color": "#3b2b1d",
  "beard": "stubble", "glasses": "none", "hat": "none",
  "uniform": "#e2761f", "eyes": "beady", "brow": "normal", "extra": "tattoo"
}
```

| field | options |
|---|---|
| `body` | `huge` `wide` `normal` `thin` `short` |
| `hair` | `none` `bald` `buzz` `short` `messy` `spiky` `mohawk` `slick` `bun` `long` `braids` `afro` `receding` |
| `beard` | `none` `stubble` `mustache` `goatee` `full` `long` |
| `glasses` | `none` `round` `square` `shades` `monocle` |
| `hat` | `none` `beanie` `cap` `hardhat` `bandana` `headband` `chef` `visor` |
| `eyes` | `normal` `beady` `wide` `tired` `sharp` `dot` |
| `brow` | `normal` `angry` `worried` `raised` |
| `extra` | `none` `scar` `earring` `bandage` `freckles` `tattoo` `tooth_gap` |
| `skin`, `hair_color`, `uniform` | any hex colour |

Unknown values fall back to something sensible rather than crashing, so a typo
degrades instead of breaking.

`body` does most of the work. Silhouette is what distinguishes a character at
thumbnail size, so when adding cast members, vary `body` before anything else.

### Expressions

The same portrait draws nine faces: `idle`, `happy`, `sad`, `scared`, `angry`,
`hurt`, `tired`, `worried`, `out`. Statuses map onto them automatically via
`CharacterPortrait.expression_for_status()`, and screens override explicitly —
the encounter result screen shows `happy` on a success and `out` on a critical
failure, which is where most of the comedy in the UI comes from.

Brows carry the expression more than the mouth does. If a new expression reads
weakly, adjust `_draw_face()`'s brow angles first.

### Adding a part

Add a branch to `_draw_hair()`, `_draw_hat()`, `_draw_beard()` or `_draw_extra()`
and a string to somebody's JSON. The helpers available inside the portrait are
`_v(x, y)` to convert virtual to screen coordinates, `_u(n)` to scale a length,
`_ellipse()`, `_rounded()`, `_poly()` (filled plus outline), `_stroke()`,
`_line()` and `_dot()`. Draw back-to-front; `_draw()` lists the order.

---

## Rooms — `scripts/ui/room_scene.gd`

Each room type is a banner illustration: a wall, a floor, and a handful of
rectangles arranged into bunks, dryers, monitors or pipes, tinted from the
room's `color` in `rooms.json`. Several animate gently — the laundry drums turn,
the security monitors scanline, the wall tower sweeps a searchlight.

Add a room by adding a `case` to the `match room_id` in `_draw()`. An unknown
room falls back to the cell block.

## Icons — `scripts/ui/room_icon.gd`

Small line glyphs, referenced by the `icon` field in `rooms.json` and reused for
power-up cards and escape routes: `bars` `tray` `sun` `shirt` `wrench` `cross`
`badge` `screen` `gear` `pipe` `book` `candle` `wall` `flame` `star`.

## Backdrop — `scripts/ui/backdrop.gd`

The drifting cell-bar background behind every screen. It retints per screen and
its searchlight brightens as Heat rises, so the game gets visibly tenser without
anybody saying so.

---

## Colour and typography — `scripts/ui/palette.gd`, `scripts/ui/ui_kit.gd`

`Palette` is the entire colour vocabulary of the game; retinting is a one-file
job. `UIKit` builds the Godot `Theme` and the handful of widgets the screens use
repeatedly — buttons, chips, stat bars, panels, section headings.

Two constraints worth preserving:

- **`UIKit.TOUCH_HEIGHT` (52px)** is the minimum height for anything tappable,
  so the same build works on a phone later.
- **Nothing is hover-only.** Hover adds polish; it never carries information.

Typography uses Godot's built-in font at explicit sizes. If you want a custom
face later, drop a `.ttf` in `assets/fonts/` and set it in `UIKit.build_theme()`
— that one function is the only place font choice is decided.

---

## Audio — `scripts/autoload/audio_manager.gd`

Also fully synthesised. Sound effects are short square/saw/sine envelopes built
as `AudioStreamWAV` at startup; music is a four-bar minor-scale arpeggio-and-bass
loop generated lazily per mood (`menu`, `gameplay`, `tension`, `escape`,
`victory`, `defeat`).

A new sound effect is one line in `_build_sfx()` using `_tone()`, `_arp()`,
`_sweep()` or `_noise()`. If you later replace all this with recorded audio, the
only thing the rest of the game uses is `Audio.play("name")` and
`Audio.play_music("mood")`.
