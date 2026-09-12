# Immersive UI overhaul

This branch keeps the existing game rules, data, RNG, saves and tests intact while making the prison feel like a place the crew actually occupies.

## What changed

- `RoomScene` is now a living prison scene rather than a static banner.
- The current party is rendered inside the room using the existing procedural `CharacterPortrait` system.
- Prisoners have subtle idle movement, floor shadows and activity labels such as `LOOKOUT`, `CHECKING WALL`, `WATCHING GUARD` and `PRETENDING TO WORK`.
- Room scenery is still generated at runtime, with different layouts for cells, cafeteria, yard, laundry, workshop, medical, security, maintenance, sewer, library, chapel and the outer wall.
- Existing room tinting, Heat-driven atmosphere and animation are preserved.
- `CrewScene` is available for larger future encounter/result beats where the whole crew should react together.

## Art decision

No external image assets were added. That is deliberate. The project already has a strong procedural art system: portraits, rooms and UI are drawn by code, which keeps the build lightweight, scalable and easy to edit. A future art pass can replace individual pieces without changing gameplay code.

## Visual direction

The target is a chunky 2D prison-comedy look:

- thick outlines
- dark concrete/metal environments
- warm prisoner uniforms
- expressive silhouettes
- small animated environmental details
- characters visibly occupying the same physical space as the event
- UI layered over the scene instead of replacing it

The minimum tappable height remains 52px and no information is communicated only through hover.
