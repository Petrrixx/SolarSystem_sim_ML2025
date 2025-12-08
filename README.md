# SolarSystem\_sim\_ML2025

A MATLAB GUI application that visualizes the Solar System in 2D with sprites and optional 3D OBJ previews (textured planets), driven by simple OOP models, timers, and JSON-loaded body data.

## Quick start
- Requirements: MATLAB (tested with App Designer/uifigure APIs), Image Processing Toolbox recommended for texture handling.
- Run: open `Main.m` and press **Run**, or call `Main` from the MATLAB prompt. The app builds the GUI, loads body data from `assets/data/bodies.json`, and starts animation.
- Assets: 2D sprites live in `assets/<Body>/...`, background in `assets/Backgrounds/space2D.png`, 3D models/textures in `assets/<Body>/<Body>.obj` with `.mtl` and texture files.

## GUI overview
- **Sky view (2D)**: uiaxes with a space background, orbit ellipses, body sprites, and optional trails (animatedline). Scroll to zoom around cursor; click a body to focus. Orbits and trails can be toggled.
- **Controls panel**:
  - Play/Pause toggle.
  - Speed slider (days per second) with label; changing it updates simulation speed and the time-ratio labels.
  - Show Orbits / Show Trails checkboxes.
  - Body dropdown and **Show 3D Model** button (enabled when an OBJ is present).
  - **Reset View** button: restores defaults (speed, orbits on, trails off), recenters zoom, clears trails/marks, resets time counters.
  - Time readouts: simulated days elapsed, real time elapsed since launch, and the dynamic ratio `1s real : Xs sim`.
  - Info panel: body parameters plus a short fact pulled via HTTP GET (Wikipedia summary API, cached; falls back if offline).
- **Bodies table**: lists name/type/central body/a/period for all loaded objects.
- **3D viewer**: opens a new figure with a textured OBJ rendered via patch. Models are centered, vertex-colored from texture (with subdivision + bilinear sampling), have per-body auto-spin about a Y-up axis, and support mouse rotate/zoom.

## Object model (OOP)
- Base class `CelestialBody` stores orbital elements, sprite info, and description. Implements `positionAtTime` (Kepler) and a Newton-Raphson Kepler solver.
- Subclasses extend behavior:
  - `Star`: overrides `positionAtTime` to stay at origin.
  - `Planet`, `Moon`: inherit base motion; display/orbit scaling can be set via JSON.
- `BodyDataLoader` reads `assets/data/bodies.json` (file management via `fileread`, `jsondecode`) and instantiates the appropriate subclass.
- `SpriteManager` loads sprites from disk (imread) and manages alpha.
- `SolarSystemApp` orchestrates UI, timers, event handlers, and rendering.
- `ObjModelViewer` reads OBJ/MTL, triangulates faces, preserves UVs/normals, subdivides for smoother textures, samples textures into per-vertex colors, recenters geometry, and auto-rotates per body.

## Timers and simulation loop
- A `timer` (fixedSpacing, ~0.03s period) advances `SimTime` by `elapsed * TimeSpeedFactor` (days/sec).
- The loop recomputes body positions, updates sprites, orbits, and trails, and refreshes info/time labels. `drawnow limitrate` keeps UI responsive.
- Reset reinitializes time counters and clears trails; StartWallTime tracks real elapsed time for ratio display.

## File and network handling
- Body data: `assets/data/bodies.json` parsed with `jsondecode`.
- Images: sprites/backgrounds/OBJ textures loaded via `imread`; textures converted to double for sampling.
- OBJ/MTL: custom parser reads vertices, faces, UVs, normals, materials, and map\_Kd. Faces are triangulated with aligned UV/normal indices; vertices are duplicated at seams; optional subdivision increases vertex density. Textures are sampled with bilinear `interp2`.
- Facts: HTTP GET to Wikipedia REST summary API via `webread` (short timeout), cached per body. Network failures are tolerated with a fallback message.

## Rendering details
- **2D**: orbits drawn with `plot`, trails with `animatedline`, sprites with `image` on a black/space background; axes are equal-scaled and zoomable; click-to-select uses nearest-sprite hit testing.
- **3D**: patch with `FaceColor='interp'` using texture-sampled per-vertex colors; normals computed if missing. Models are centered so auto-spin is about their own axis. Default spin axis is Y-up; rates vary per body (retrograde for Venus, faster for gas giants, etc.). Closing the viewer stops the spin timer.

## Controls and interactions
- Play/Pause toggles the simulation timer.
- Speed slider changes days/sec; labels and ratio update immediately.
- Show Orbits / Show Trails toggle visibility; trails clear when turned off or on reset.
- Reset View restores defaults, clears trails, recenters view, resets timers, and reselects the first body.
- Scroll to zoom around cursor; click bodies to focus; select from dropdown; launch 3D model if available.

## Extending or modifying
- Add/adjust bodies in `assets/data/bodies.json` (name, type, a, e, period, centralBody, spriteFile, scales, description).
- Add 3D models/textures under `assets/<Name>/<Name>.obj` (with `.mtl` and textures). Ensure map\_Kd paths in MTL point to the texture file.
- Tune auto-spin in `ObjModelViewer.defaultSpinRate` and `defaultSpinAxis`.
- Adjust performance vs. quality: in `ObjModelViewer.readObj`, reduce subdivision levels for faster rendering or increase for sharper textures.

## Code patterns used
- OOP with class inheritance and method overrides (`CelestialBody` → `Planet`, `Moon`, `Star`).
- Event-driven UI callbacks (buttons, sliders, checkboxes, dropdowns).
- Timers for animation loops.
- Control flow: conditionals for visibility toggles, missing data handling, and network fallbacks; loops for iterating bodies, orbits, faces, and subdivision.
- File I/O (JSON/image/OBJ/MTL) and network I/O (HTTP GET facts).
- Graphics: 2D plotting, imagesc background, animated lines, patch-based 3D rendering with lighting and per-vertex colors.

## Known behaviors
- Texture sampling is per-vertex; sharpness depends on subdivision level vs. model resolution.
- Wikipedia fact fetch is best-effort; cached once per body; may return fallback if offline.
- Auto-spin uses a simplified Y-up axis; obliquity is approximated.

## Running tests
- No automated tests included; manual verification: launch `Main`, toggle controls, change speed, open 3D models, and verify timers/ratios update.
