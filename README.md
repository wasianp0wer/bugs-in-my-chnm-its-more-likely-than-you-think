# CHNM Critter Sim

A small Godot 4.7 desktop toy that fills the main room of the Roy Rosenzweig Center for History and New Media (CHNM) with true-scale bouncing animals. Pick a species, type a count (there is no cap; very large counts just run slower), and watch them ricochet around a dollhouse-style cutaway of the office. Every animal is modelled at its real size relative to the room and furniture.

## Running from source

Requires [Godot 4.7.2](https://godotengine.org/download).

```sh
godot --path sim
```

## Using the builds

Builds are unsigned. Use the builds shared alongside this repo (or build them yourself, below).

- **macOS:** unzip `CHNM-Critter-Sim.zip`. Because the app is unsigned, do not double-click it the first time. Right-click (or Control-click) the app and choose **Open**, then confirm.
- **Windows:** run `CHNM-Critter-Sim.exe`. If SmartScreen warns about an unrecognised app, click **More info**, then **Run anyway**.

## Controls

- **Orbit:** drag with the left mouse button.
- **Zoom:** scroll wheel or trackpad pinch; zoom moves toward the cursor.
- **Pan:** right-drag, or a two-finger trackpad drag.
- **HUD:**
  - Choose a species from the dropdown.
  - Type a count (for example `5000`, or `10k`) or use the quick buttons (10, 100, 1k, 10k), then press **Add** or Enter.
  - **Clear** removes all critters.
  - The panel shows per-species counts, the total, and the frame rate.
  - The **info** button opens the credits screen.

## Building the exports

1. Install the official export templates once. Download `Godot_v4.7.2-stable_export_templates.tpz` from the [Godot 4.7.2 release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable), then unzip it (it is a zip file) so that its files sit directly in:
   - macOS: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`
   - Windows: `%APPDATA%\Godot\export_templates\4.7.2.stable\`
   - Linux: `~/.local/share/godot/export_templates/4.7.2.stable/`
2. From the repo root, export (output goes to the gitignored `build/`):

```sh
godot --headless --path sim --export-release "macOS" ../build/mac/CHNM-Critter-Sim.zip
godot --headless --path sim --export-release "Windows Desktop" ../build/win/CHNM-Critter-Sim.exe
```

The presets live in `sim/export_presets.cfg`. They leave out `tools/`, `tests/`, `addons/gut/` and `assets/animals/src/`.

## Tests

```sh
scripts/test.sh
```

Runs the GUT suite headlessly. Extra arguments pass through to GUT, for example `scripts/test.sh -gselect=name_fragment`.

## Regenerating the animal meshes

The baked meshes in `sim/assets/animals/*.res` are generated from the sources in `sim/assets/animals/src/`:

```sh
godot --headless --path sim -s res://tools/bake_meshes.gd
```

## Where things came from

- **Room dimensions:** estimated from the university floor plan; see `floor_plan/DIMENSIONS.md`.
- **Furniture and reference photos:** `reference/` (photos plus `reference/FURNITURE.md`).
- **Credits and licences** for models and other assets: `CREDITS.md` (also shown in-app via the info button).

## Why there is no Web build

A Web export technically succeeds, but the project uses the default Forward+ renderer, which browsers do not support (Web needs the Compatibility renderer). Supporting it would mean re-checking the rendering and performance of the whole app, so the Web preset was dropped.
