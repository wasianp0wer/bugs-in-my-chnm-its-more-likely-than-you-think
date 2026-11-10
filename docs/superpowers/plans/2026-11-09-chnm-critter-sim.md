# CHNM Critter Sim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a desktop Godot app that shows CHNM's main room as a cutaway dollhouse. The user picks a species and a count, the animals rain into the room at true-to-life scale, and they bounce around forever.

**Architecture:**
- **Project layout:** the Godot project lives in `sim/`. Reference photos and raw models stay outside it, so they never get imported or shipped.
- **Data:** the room geometry and furniture layout are data files.
- **Animal motion:** each "Add" creates one `GPUParticles3D` batch. A custom particle process shader integrates motion and collides against a union of axis-aligned room rectangles plus obstacle boxes passed as uniform arrays.
- **Testing:** a GDScript reference implementation of the same motion rules is unit-tested (GUT, headless), and the shader mirrors it.

**Tech Stack:** Godot 4.7.2 (`/opt/homebrew/bin/godot`), GDScript only, Forward+ renderer, GUT for tests.

**Spec:** `docs/superpowers/specs/2026-11-09-chnm-critter-sim-design.md`

## Global Constraints

- **Units:** 1 Godot unit = 1 m. Every animal and every piece of furniture is at true-to-life size.
- **Room space:**
  - Room local coordinates: origin at the NW corner of the room's bounding box, +X = east, +Z = south, +Y = up. Floor is at y = 0.
  - Ceiling / invisible lid is at y = 2.9.
  - There are no interior walls; it is one open room.
- **Animal motion:**
  - Animals never lose energy and never come to rest. They pass through each other.
  - Hoppers that land on the floor or a box top are relaunched at their species hop speed (`sqrt(2*g*hop_height)`, g = 9.8). Their horizontal speed is constant, and their heading turns by a random angle in [-30°, +30°] on each landing.
  - Flyers have no gravity. They move in straight lines at the species speed and reflect off every surface, including the lid.
  - New animals spawn at y = 2.8 at uniformly random x/z inside the room, and never inside a box.
- **Population:** no cap on animal count.
- **Cutaway:** walls between the camera and the room interior show as a 0.5 m stub but still collide at full height. Columns are never cut.

> **2026-11-09 (Task 16, user request):** the columns were removed. There are no columns and `column_boxes()` is gone; the cutaway rule "columns are never cut" no longer applies. A group table (no chairs) now stands against the east wall under the top-right window (z = 3.7).

- **HUD:** floating cards.
  - Add card, top left: species dropdown (alphabetical), quick buttons 10/100/1k/10k that set the count field, a count field, and an Add button.
  - Counter card, top right: per-species counts, the total, FPS, a Clear button, and an ⓘ credits button.
- **Lighting:** daytime only, with a gentle glow post-effect. Fireflies are emissive.
- **Assets:** no NC or SA assets. `reference/` is never inside `sim/`. `CREDITS.md` at the repo root is also shown in the app.
- **Deliverables:** unsigned macOS and Windows desktop exports are required. A web export is best-effort.
- **Tests:** all tests run headless with `scripts/test.sh`. Write a failing test first for every unit of logic.

## Review Focus

1. **Count field input:** empty text, `0`, `-5`, `abc`, `5,000`, `1e6` and `10000000`.
   - Invalid input shows an inline error and adds nothing.
   - `5,000` means 5000.
   - Huge valid counts are accepted. Test this in T6 `parse_count`.
   - In T10/T11, a single add is split into batches of ≤ 100,000 particles.
2. **Frame hitch (dt = 0.5 s) or a fast flea near a thin desk:** animals must not tunnel out of the room or into boxes. The reference sub-steps so that no step moves more than 0.02 m. T7 tests this.
3. **Spawning in the non-convex parts** (the 461 notch, the SE extension): spawn points cover every room rectangle in proportion to its area, and none land outside the room or inside a box. T3 tests this.
4. **Rapid repeated Add/Clear:** counts stay consistent, and Clear frees every batch node. T11 tests this.
5. **Zoomed all the way in:** the camera never goes below y = 0.05 or outside the room bounding box expanded by 20 m, and pitch stays within its clamps. T5 tests this.

## Dependency graph and parallelism

| Task | Depends on | Parallel group |
|---|---|---|
| T1 Scaffold | — | 0 (alone) |
| T2 GPU spike | T1 | A |
| T3 Room data + geometry | T1 | A |
| T4 Species data + mesh baking + credits | T1 | A |
| T5 Camera math | T1 | A |
| T6 HUD | T1 | A |
| T7 Motion reference | T1 | A |
| T8 Furniture | T3 | B |
| T9 Room visuals + cutaway | T3 | B |
| T10 Particle shader + swarms | T2, T4, T7 | B |
| T11 Main scene integration | all above | C (alone) |
| T12 Exports + README | T11 | D (alone) |

- **Tasks in the same group:** they touch disjoint files, so they're parallel-safe. Each runs in its own git worktree.
- **`project.godot`:** only T1, T11 and T12 may edit it. Other tasks must not.
- **Merging:** merge back one at a time and run `scripts/test.sh` after each merge.

## File map

```
sim/project.godot                         T1 (T11, T12 edit)
sim/addons/gut/                           T1 (vendored GUT)
scripts/test.sh                           T1
sim/tests/test_smoke.gd                   T1
spikes/gpu/                               T2 (throwaway Godot project, not merged into sim)
sim/scripts/room/room_data.gd             T3
sim/scripts/room/room_geometry.gd         T3
sim/tests/room/test_room_geometry.gd      T3
sim/data/species.json                     T4
sim/scripts/species/species_db.gd         T4
sim/tools/bake_meshes.gd                  T4
sim/assets/animals/<id>.res               T4 (generated)
CREDITS.md, sim/CREDITS.md                T4 (T8 appends if it uses any asset)
sim/tests/species/test_species_db.gd      T4
sim/tests/species/test_baked_meshes.gd    T4
sim/scripts/camera/orbit_math.gd          T5
sim/scripts/camera/dollhouse_camera.gd    T5
sim/tests/camera/test_orbit_math.gd       T5
sim/scenes/ui/hud.tscn, hud.gd            T6
sim/scripts/ui/count_parser.gd            T6
sim/tests/ui/test_count_parser.gd, test_hud.gd   T6
sim/scripts/sim/collision_world.gd        T7
sim/scripts/sim/motion_rules.gd           T7
sim/tests/sim/test_collision_world.gd, test_motion_rules.gd   T7
sim/data/furniture_layout.json            T8
sim/scripts/furniture/furniture_factory.gd   T8
sim/tests/furniture/test_furniture.gd     T8
sim/scripts/room/room_builder.gd          T9
sim/scripts/room/cutaway.gd               T9
sim/tests/room/test_room_builder.gd       T9
sim/shaders/critter_process.gdshader      T10
sim/scripts/sim/swarm_batch.gd            T10
sim/scripts/sim/swarm_manager.gd          T10
sim/tests/sim/test_swarm_manager.gd       T10
sim/scenes/main.tscn, sim/scripts/main.gd T11
sim/scripts/sim/population.gd             T11
sim/tests/test_population.gd, test_main.gd   T11
sim/tools/screenshot.gd                   T11
sim/export_presets.cfg, README.md         T12
```

---

### Task 1: Scaffold the repo, the Godot project and the test runner

**Files:** Create `.gitignore`, `sim/project.godot`, `sim/addons/gut/` (vendored), `scripts/test.sh`, `sim/tests/test_smoke.gd`.

**Interfaces:** Produces `scripts/test.sh [gut args]`. It runs `godot --headless --path sim --import`, then `godot --headless --path sim -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`, and exits non-zero on any failure.

- [ ] **Step 1:** At the repo root, run `git init`. Write `.gitignore` with `.godot/`, `.superpowers/`, `build/`, `*.import` **excluded from the ignore** (that is, do commit `*.import`) and `.DS_Store`. Commit the existing `docs/`, `floor_plan/`, `models/` and `reference/` as the initial commit.
- [ ] **Step 2:** Create `sim/project.godot`:
  - name "CHNM Critter Sim", Godot 4.7, Forward+
  - main scene left unset for now
  - window 1600×900, resizable
- [ ] **Step 3:** Vendor GUT. Use the latest GUT release that supports Godot 4.7, copying `addons/gut` from a GitHub release tag into `sim/addons/gut`. Enable the plugin in `project.godot`.
- [ ] **Step 4:** Write a failing smoke test, `sim/tests/test_smoke.gd`, with `test_fails_first(): assert_eq(1, 2)`. Write `scripts/test.sh`, run it, and confirm it exits non-zero and reports 1 failure.
- [ ] **Step 5:** Change the assertion to `assert_eq(1 + 1, 2)`, run it, and confirm it exits 0.
- [ ] **Step 6:** Commit with the message "chore: scaffold Godot project with GUT test runner".

---

### Task 2: GPU particle spike (throwaway)

**Purpose:** Before building on it, prove the architecture in Godot 4.7.2 Forward+ on this M4 Pro Mac. This is a spike: no tests are required, and the code is not merged into `sim/`.

**Files:** `spikes/gpu/` (its own `project.godot`) and `spikes/gpu/REPORT.md`.

- [ ] **Step 1:** Build a scene with a box room (floor plus 4 walls, 10×10×2.9 m), a camera and a `GPUParticles3D` whose `process_material` is a `ShaderMaterial` with `shader_type particles;`. The shader:
  - in `start()`, places each particle at a random x/z at y = 2.8 with a random horizontal velocity
  - in `process()`, applies gravity and relaunches at a fixed hop speed on reaching y = 0, and reflects off x/z = 0 and 10
  - declares `uniform vec4 room_rects[8]; uniform vec3 box_min[128]; uniform vec3 box_max[128]; uniform int box_count;` and reflects off one box set from GDScript

  Use `amount = 50000`, `explosiveness = 1.0`, `one_shot = true`, a lifetime of 1e6 s, and `visibility_aabb` covering the room. The draw pass is a small box mesh.
- [ ] **Step 2:** Run windowed: `godot --path spikes/gpu --quit-after 600`. Print the FPS every second to stdout, and save a screenshot to `spikes/gpu/shot.png` after 5 s.
- [ ] **Step 3:** Answer these in `REPORT.md`:
  - FPS with 1 batch of 50k, and with 5 batches of 50k
  - whether uniform arrays work in particle shaders
  - whether `one_shot` plus a huge lifetime keeps particles alive and frozen in time
  - whether adding a second `GPUParticles3D` node at runtime works without resetting the first
  - how to scale and rotate `TRANSFORM` per particle
  - any shader-compile gotchas
  - also try `godot --path spikes/gpu --rendering-method gl_compatibility` for the same scene and record the result
- [ ] **Step 4:** Commit `spikes/gpu/` with the message "spike: GPU particle feasibility".

**If 50k can't reach ≥ 60 fps, or any of these mechanisms fails, stop and report rather than redesign.**

---

### Task 3: Room data and geometry

**Files:** Create `sim/scripts/room/room_data.gd`, `sim/scripts/room/room_geometry.gd` and `sim/tests/room/test_room_geometry.gd`.

**Room data:** derived in `floor_plan/DIMENSIONS.md`. It is exact copy, so use these values.

```gdscript
class_name RoomData
const CEILING := 2.9
# Union of axis-aligned rects (x, z, w, d) in metres
const RECTS: Array[Rect2] = [
	Rect2(0.0, 5.9, 2.9, 4.8),     # 461 notch (west, by pantry)
	Rect2(2.9, 0.0, 10.2, 10.7),   # 462/472 block
	Rect2(13.1, 3.9, 18.4, 6.8),   # 479/470/478 band
	Rect2(20.3, 10.7, 11.2, 4.1),  # SE extension (470/478 lower)
]
# Outline, clockwise from the notch's NW corner
const OUTLINE: PackedVector2Array = [
	Vector2(0,5.9), Vector2(2.9,5.9), Vector2(2.9,0), Vector2(13.1,0),
	Vector2(13.1,3.9), Vector2(31.5,3.9), Vector2(31.5,14.8), Vector2(20.3,14.8),
	Vector2(20.3,10.7), Vector2(0,10.7)]
const EXTERIOR_EDGES := [2, 5]   # OUTLINE edge i = OUTLINE[i]→OUTLINE[i+1]: north of 462/472, east of 478
const MURAL_EDGE := 2
const COLUMNS: Array[Vector2] = [Vector2(8.0,5.5), Vector2(13.1,7.3), Vector2(20.3,7.3), Vector2(26.0,7.3)]
const COLUMN_SIZE := 0.6
const DOORS := [ {"edge": 8, "center": 16.5}, {"edge": 9, "center": 8.3} ]  # edge index, coordinate along that edge's axis
```

Edge indices run from `OUTLINE[i]` to `OUTLINE[i+1]`:
- edge 1 is the west wall of 462/472 (the storage wall)
- edge 2 is the north window bank
- edge 5 is the east wall of 478
- edge 8 is the south wall onto corridor CORR1 (the corridor door is at x = 16.5)
- edge 9 is the notch's west wall onto Pantry 1 (the pantry door is at z = 8.3)

**Interfaces (Produces), all static on `RoomGeometry`:**
- `contains_xz(p: Vector2) -> bool`: true if p is inside any rect. Boundaries count as inside.
- `area() -> float`: area of the rect union, about 294 m².
- `bounds() -> Rect2`: Rect2(0, 0, 31.5, 14.8).
- `walls() -> Array[Dictionary]`: one per outline edge, `{a: Vector2, b: Vector2, normal: Vector2 (outward, unit), exterior: bool, index: int}`.
- `column_boxes() -> Array[AABB]`: full-height boxes, 0.6×2.9×0.6.
- `random_spawn_xz(rng: RandomNumberGenerator, obstacles: Array[AABB]) -> Vector2`: area-weighted rect choice, then uniform within it. Reject points inside any obstacle's xz footprint.
- `walls_facing_camera(cam_pos: Vector3) -> PackedInt32Array`: indices of walls where `normal.dot(cam_xz - wall_midpoint) > 0`.

**Tests (write first, watch each fail, then implement):**
- `test_contains_points`: these points are inside: (1,8), (5,1), (20,5), (30,14). These are outside: (1,1), (20,13), (32,5), (15,12) (the corridor below the band), (-0.1,8).
- `test_area`: `assert_almost_eq(area(), 294.0, 1.0)`. Also check that the outline polygon area (shoelace formula) equals `area()` within 0.01.
- `test_walls_outward_normals`: for each wall, the midpoint plus 0.05·normal is outside, and the midpoint minus 0.05·normal is inside.
- `test_exterior_flags`: exactly the walls at indices 2 and 5 are exterior. Wall 2 lies on z = 0.
- `test_doors_on_edges`: each door centre is on its edge and at least 0.6 m from both ends.
- `test_columns_inside`: every column footprint is fully inside the room.
- `test_spawn_covers_all_rects`: 20,000 samples with a seeded rng. All are inside, none are inside the obstacle `AABB(Vector3(4,0,1),Vector3(2,1,2))`, and each rect gets a share within ±3% of its area fraction (Review Focus 3).
- `test_walls_facing_camera`: from a camera at (15,10,-20) (north of the room), wall 2 (the north wall) is in the result and the south walls are not.

Commit with the message "feat(room): room data and geometry".

---

### Task 4: Species data, mesh baking and credits

**Files:** Create `sim/data/species.json`, `sim/scripts/species/species_db.gd`, `sim/tools/bake_meshes.gd`, `sim/assets/animals/*.res`, `sim/tests/species/test_species_db.gd`, `sim/tests/species/test_baked_meshes.gd`, `CREDITS.md` and `sim/CREDITS.md` (an identical copy).

**Species JSON entry:**

```json
{"id":"flea","name":"Flea","source":"../models/flea/flea.glb","body_length_m":0.0025,
 "motion":"hopper","speed_mps":0.5,"hop_height_m":0.2,"emissive":false,
 "credit":{"title":"Flea (animation test)","author":"nodoxi","url":"…","license":"CC-BY 4.0"}}
```

- Include all 29 species with a model in `models/<id>/` (the list is in spec §4).
- Choose one GLB per species, preferring Quaternius (CC0) where it exists. Take the credit fields from `models/CATALOG.md`.
- Pinned anchors:
  - flea: hopper, 2.5 mm, hop 0.2 m, 0.5 m/s
  - ant: hopper, 6 mm, hop 0.005 m, 0.03 m/s
  - deer: hopper, 1.8 m, hop 1.2 m, 3 m/s
  - wasp: flyer, 15 mm, 2.5 m/s
  - firefly: flyer, 12 mm, 0.5 m/s, emissive true
  - housefly: flyer, 7 mm, 2 m/s
- Flyers are: firefly, wasp, hornet, bee, housefly, moth, butterfly, dragonfly, bat, crow, pigeon. All others are hoppers.
- The implementer picks plausible values for the rest.

**Interfaces (Produces):**
- `SpeciesDB.load_all() -> Array[Dictionary]`: sorted by `name`, and each entry gains `mesh_path: "res://assets/animals/<id>.res"`.
- `SpeciesDB.get_species(id: String) -> Dictionary`
- `SpeciesDB.hop_speed(s: Dictionary) -> float`: equals `sqrt(2*9.8*hop_height_m)`, and 0 for flyers.
- The baked mesh for every species is an `ArrayMesh` in which all GLB mesh instances are merged with their node transforms applied and their materials kept. It is normalised so that its longest horizontal extent is 1.0 along +Z (the model faces +Z), its minimum y is 0, and it is centred in x/z.
  - At runtime, scale it by `body_length_m`.
  - For `emissive` species, add emission (colour `#d8ff6a`, energy 4) to every surface material.
- `sim/tools/bake_meshes.gd` is an `extends SceneTree` script, run with `godot --headless --path sim -s res://tools/bake_meshes.gd`. It needs the GLBs importable, so copy the chosen GLBs into `sim/assets/animals/src/<id>.glb` first.

**Tests (write first):**
- `test_all_species_present`: 29 entries, the ids are unique, and every `motion` is `hopper` or `flyer`.
- `test_anchor_values`: the flea and deer values exactly match the pinned values above, and `hop_speed(flea)` ≈ 1.98.
- `test_sorted_by_name`
- `test_no_nc_or_sa_license`: no `license` contains "NC" or "SA".
- `test_baked_meshes`: for every species, the `.res` loads as a Mesh, the AABB longest horizontal extent is 1.0 ± 0.01 along z, min y is 0 ± 0.001, and the centre in x/z is within 0.01 of 0.
- `test_credits_lists_every_species`: `res://CREDITS.md` contains every species' credit title and author.

Commit with the message "feat(species): species data, baked meshes, credits".

---

### Task 5: Dollhouse camera

**Files:** Create `sim/scripts/camera/orbit_math.gd` (pure), `sim/scripts/camera/dollhouse_camera.gd` (`extends Camera3D`) and `sim/tests/camera/test_orbit_math.gd`.

**Interfaces (Produces):**
- `OrbitMath.new(room_bounds: Rect2)` has the fields `target: Vector3`, `yaw: float` (rad), `pitch: float` (rad, measured downward from horizontal) and `distance: float`.
- Defaults: the target is the centre of the bounds at y = 0.5, pitch is 50°, distance 30, and yaw places the camera south of the room (a +Z offset) looking north toward the window bank on wall 2.
- Methods:
  - `orbit(dx_px: float, dy_px: float)`: 0.005 rad per pixel.
  - `zoom(steps: float)`: distance *= 0.9^steps.
  - `pan(dx_px, dy_px)`: moves along the camera's ground-plane axes, scaled by distance·0.0015.
  - `transform() -> Transform3D`
- Clamps:
  - pitch in [20°, 89°]
  - distance in [0.03, 45]
  - target xz inside the bounds; target y in [0, 2.9]
  - camera position y ≥ 0.05
- `DollhouseCamera` has `@export var room_bounds: Rect2`. It maps left-drag to orbit, the wheel and trackpad pinch (`InputEventMagnifyGesture`) to zoom, and right-drag and two-finger pan (`InputEventPanGesture`) to pan. It sets `near = 0.002` and `far = 200`, and emits `moved(cam_pos: Vector3)`.

**Tests (write first):**
- `test_default_looks_at_target`
- `test_pitch_clamped`: a large orbit up and a large orbit down respect 20° and 89°.
- `test_zoom_clamped`: 0.03 and 45.
- `test_pan_clamped_to_bounds`
- `test_camera_never_below_floor`: at pitch 20° and distance 0.03 with target y = 0, the transform origin y is ≥ 0.05 (Review Focus 5).
- `test_zoom_in_close_enough_for_flea`: at the minimum distance, a 2.5 mm object at the target spans at least 20 px vertically for a 900 px tall viewport with fov 50°.

Commit with the message "feat(camera): dollhouse orbit camera".

---

### Task 6: HUD (floating cards)

**Files:** Create `sim/scripts/ui/count_parser.gd`, `sim/scenes/ui/hud.tscn`, `sim/scenes/ui/hud.gd`, `sim/tests/ui/test_count_parser.gd` and `sim/tests/ui/test_hud.gd`.

**Interfaces (Produces):**
- `CountParser.parse(text: String) -> int`: returns the count, or -1 if invalid. Accepted forms:
  - digits with optional thousands commas
  - optional surrounding whitespace
  - optional `k` or `m` suffix with an integer or one-decimal mantissa, e.g. `1.5k`
  
  Must be > 0. There is no upper limit.
- `Hud` (`extends Control`, full rect, `mouse_filter = IGNORE` on the root so camera drags pass through):
  - signals `add_requested(species_id: String, count: int)`, `clear_requested()`, `credits_requested()`
  - `set_species(list: Array[Dictionary])`: fills the dropdown with name text and id metadata
  - `set_counts(counts: Dictionary, names: Dictionary)`: one line per species, e.g. "Flea  5,000", plus "Total 5,203"
  - `set_fps(fps: float)`
  - `show_credits(text: String)`: a modal panel with a scrollable RichTextLabel and a Close button
- Layout:
  - Add card, top left: OptionButton, then buttons 10 / 100 / 1k / 10k that set the LineEdit text, then the LineEdit (default "100"), then Add.
  - Counter card, top right: counts, total, FPS, Clear and ⓘ.
- Invalid count: a red inline label, "Enter a whole number like 5000", and no signal.

**Tests (write first):**
- `test_parse_valid`:
  - "5000"→5000
  - "5,000"→5000
  - " 42 "→42
  - "10k"→10000
  - "1.5k"→1500
  - "2m"→2000000
  - "10000000"→10000000
- `test_parse_invalid`: "", "0", "-5", "abc", "1e6", "5,00", "1.55k" all return -1 (Review Focus 1).
- `test_quick_buttons_set_field`
- `test_add_emits_with_selected_species`
- `test_add_invalid_shows_error_no_signal`
- `test_counts_display_and_total`: "5,000" uses thousands separators.
- `test_root_ignores_mouse`

Commit with the message "feat(ui): floating-card HUD".

---

### Task 7: Motion reference rules

**Files:** Create `sim/scripts/sim/collision_world.gd`, `sim/scripts/sim/motion_rules.gd`, `sim/tests/sim/test_collision_world.gd` and `sim/tests/sim/test_motion_rules.gd`.

**Interfaces (Produces):**
- `CollisionWorld.new(rects: Array[Rect2], boxes: Array[AABB], ceiling: float)`
  - `inside_room_xz(p: Vector2) -> bool`
  - `box_at(p: Vector3) -> int`: the index of the box containing p, or -1.
  - `to_shader_params() -> Dictionary`: keys `room_rects` (Array[Vector4]: x, z, x+w, z+d), `room_rect_count`, `box_min` (Array[Vector3]), `box_max`, `box_count`, `ceiling`. Arrays are padded to 8 rects and 128 boxes; asserts fail if there are more.
- `MotionRules` (static): `step(pos: Vector3, vel: Vector3, sp: Dictionary, world: CollisionWorld, dt: float, rng: RandomNumberGenerator) -> Array` returns `[pos, vel]`.

**The algorithm** is exact, because the shader in T10 must mirror it line for line:

```
n = max(1, ceil(|vel| * dt / 0.02));  h = dt / n
repeat n times:
  if hopper: vel.y -= 9.8 * h
  p = pos + vel * h
  # walls & column/box sides: test axes separately against the OLD position
  if not inside_room_xz(p.x, pos.z) or box_at(p.x, pos.y, pos.z) >= 0 with pos not inside that box in x: vel.x = -vel.x; p.x = pos.x
  if not inside_room_xz(pos.x, p.z) or box_at(pos.x, pos.y, p.z) >= 0 with ... z: vel.z = -vel.z; p.z = pos.z
  # vertical: floor, lid, box tops/bottoms
  b = box_at(p)
  if p.y <= 0 or (b >= 0 and pos.y >= box_max[b].y):     # landed on floor or a box top
      p.y = (p.y <= 0) ? 0 : box_max[b].y
      if hopper: vel.y = hop_speed; rotate (vel.x, vel.z) by rng angle in [-30°, 30°]
      else: vel.y = abs(vel.y)
  elif p.y >= ceiling or (b >= 0 and pos.y <= box_min[b].y):  # hit lid or box underside
      p.y = min(p.y, ceiling) if p.y >= ceiling else box_min[b].y; vel.y = -abs(vel.y)
  pos = p
```

The implementer cleans this into idiomatic GDScript while keeping the semantics. Initial state for new animals:
- hoppers: horizontal speed `speed_mps` at a random heading, vel.y = 0
- flyers: a random unit direction × `speed_mps`

That is `MotionRules.initial_velocity(sp, rng) -> Vector3`.

**Tests (write first):**
- `test_shader_params_padded_and_packed`
- `test_hopper_relaunch_height`: a flea dropped from 2.8 settles; after 5 s, its max y over the next 2 s is 0.2 ± 0.02.
- `test_hopper_horizontal_speed_constant`: within 1e-4 across 1,000 steps.
- `test_flyer_speed_constant_and_reflects_off_lid`
- `test_reflect_off_wall`: a flyer heading east at (31.4, 1, 5) ends with vel.x < 0 and pos.x ≤ 31.5.
- `test_notch_wall`: an animal crossing from the notch north into the outside (z < 5.9 at x = 1) reflects.
- `test_lands_on_box_top`: a hopper above a 0.75 m desk box lands at y = 0.75.
- `test_never_escapes_large_dt` (Review Focus 2): 500 random animals of mixed species, 200 steps at dt = 0.5. All stay inside the room, within [0, 2.9] in y, and outside every box.
- `test_never_comes_to_rest`: after 60 s simulated, every animal's speed is > 0.

Commit with the message "feat(sim): reference motion rules and collision world".

---

### Task 8: Furniture

**Files:** Create `sim/data/furniture_layout.json`, `sim/scripts/furniture/furniture_factory.gd` and `sim/tests/furniture/test_furniture.gd`.

**Interfaces:**
- Consumes `RoomGeometry` and `RoomData` from T3.
- Produces:
  - `FurnitureFactory.load_layout() -> Array[Dictionary]`. Items have the form `{type: String, pos: [x, z], rot: 0|90|180|270, size: [w, d, h]}`.
  - `FurnitureFactory.build(item) -> Node3D`: built from primitives (`BoxMesh`, `CylinderMesh`) with `StandardMaterial3D` colours from spec §3, and composite where it helps recognition. For example, a sofa is a base plus a back plus arms, and a desk is a top plus a pedestal.
  - `FurnitureFactory.collision_boxes(item) -> Array[AABB]`: one or a few world-space AABBs, exact because the allowed rotations are multiples of 90°.
  - `FurnitureFactory.build_all() -> Node3D` and `FurnitureFactory.all_boxes() -> Array[AABB]`.
- Types are those in spec §3: sofa, tub_chair, sling_chair, coffee_table, credenza, owl_lamp, wardrobe, tv_stand, whiteboard, av_cart, desk, group_table, task_chair, stack_chair, bookcase, plant, kitchenette.
- Layout intent (spec §3):
  - **Lounge:** in the 462/472 block against its north wall (z ≈ 0.4–3.5), with the credenza and owl lamp under a window.
  - **Storage wall:** wardrobes, TV and whiteboard along the west wall of 462/472 (x ≈ 3.0), facing the lounge.
  - **Workspace:** desks with chairs in rows in the 479/470/478 band.
  - **Group tables:** in the SE extension.
  - **Kitchenette:** in the 461 notch, against the west wall.

**Tests (write first):**
- `test_every_type_buildable`
- `test_counts_within_spec_ranges`: for example, sofas 2–3, wardrobes 3–5, desks 6–12, task chairs ≥ 10.
- `test_all_items_inside_room`: every box's xz footprint is inside the room.
- `test_no_overlaps_except_chairs_at_desks`: for non-chair items, footprints don't overlap.
- `test_doors_clear`: a 1.0 m × 1.0 m area in front of each door is free.
- `test_box_heights`: max y ≤ 2.2.
- `test_spawnable_area_remains`: free area is ≥ 60% of the room area.

Commit with the message "feat(furniture): CHNM main-room furniture".

---

### Task 9: Room visuals and cutaway

> Note: the north window bank built in this task was later replaced by the Rosenzweig mural (Task 14), and the furniture layout was rearranged per the user (Task 13).

**Files:** Create `sim/scripts/room/room_builder.gd`, `sim/scripts/room/cutaway.gd` and `sim/tests/room/test_room_builder.gd`.

**Interfaces:**
- Consumes T3.
- Produces:
  - `RoomBuilder.build() -> Node3D`. Its children:
    - a `Floor` mesh following the rects, in tan carpet `#c8a96a`
    - `Wall_<i>` nodes, one per outline edge, each a `Node3D` with children `Full` (2.9 m, off-white `#efece4`, 0.15 m thick, outside the outline) and `Stub` (0.5 m)
    - window bank openings on wall 2: four pairs, 1.5 × 1.6 m with sill 0.75 m, white piers, light-blue emissive "daylight" panes with a white blinds texture or slats
    - two plain windows on wall 5
    - `Door_*` meshes (light oak `#c9a46b` with a narrow dark vision slot) on their walls
    - `Column_<i>` boxes
    - a `DirectionalLight3D` "sun" through the window bank
    - an even interior fill made of a few `OmniLight3D` (troffer stand-ins, no visible ceiling)
    - a `WorldEnvironment` with a glow setting of intensity 0.6 and threshold 1.0
  - `Cutaway.apply(room: Node3D, facing: PackedInt32Array)`: for each wall `i`, `Full.visible = i not in facing` and `Stub.visible = i in facing`.

**Tests (write first):**
- `test_has_wall_per_edge`
- `test_wall_heights`: Full is 2.9 and Stub is 0.5.
- `test_window_count_on_bank`: 8 panes on wall 2.
- `test_columns_present`
- `test_cutaway_toggles`
- `test_no_ceiling_mesh`: no mesh has a top above 2.95.

Commit with the message "feat(room): room visuals and cutaway".

---

### Task 10: Particle shader and swarms

**Files:** Create `sim/shaders/critter_process.gdshader`, `sim/scripts/sim/swarm_batch.gd`, `sim/scripts/sim/swarm_manager.gd` and `sim/tests/sim/test_swarm_manager.gd`.

**Interfaces:**
- Consumes:
  - from T7: `CollisionWorld.to_shader_params()` and the `MotionRules` algorithm (mirror it)
  - from T4: species dicts and `mesh_path`
  - from T2: the mechanisms listed in `spikes/gpu/REPORT.md`. Read it first.
- Produces:
  - `SwarmBatch` (`extends GPUParticles3D`) is created by `SwarmBatch.create(sp: Dictionary, count: int, world_params: Dictionary, seed: int) -> SwarmBatch`. Settings:
    - amount = count, explosiveness 1, one_shot, lifetime 1e6
    - visibility_aabb covering the room
    - draw pass = the baked mesh
    - shader uniforms: `room_rects`, `room_rect_count`, `box_min`, `box_max`, `box_count`, `ceiling`, `is_hopper`, `speed`, `hop_speed`, `body_length`
  - `SwarmManager` (`extends Node3D`):
    - `configure(world: CollisionWorld)`
    - `add(sp: Dictionary, count: int) -> void`: splits the count into batches of ≤ 100,000 and adds one batch per frame for large adds, so the UI stays responsive.
    - `clear()`: frees all batches.
    - `count_by_species() -> Dictionary`
    - `batch_count() -> int`
- **The shader** follows the T7 algorithm. Sub-step in `process()`, mirroring the 0.02 m step bound, with the sub-step count capped at 16.
  - **State:** keep velocity in `VELOCITY` and position in `TRANSFORM[3]`.
  - **start():** spawn at y = 2.8 at a random point. Choose a rect weighted by area (pass the area prefix sums as `uniform float rect_cdf[8]`), sample within it, and re-sample up to 8 times if inside a box footprint. Use `hash`-based randomness from `INDEX` and `RANDOM_SEED`.
  - **Facing:** write `TRANSFORM` basis = yaw rotation (`atan(vel.x, vel.z)`) × uniform scale `body_length`.

**Tests (headless; the rendering itself is not tested):**
- `test_add_creates_batches`: an add of 250,000 results in 3 batches after the frames are processed, with counts summing to 250,000.
- `test_clear_frees_all`
- `test_counts_by_species_mixed`
- `test_batch_uniforms_match_world`: the material parameters equal `to_shader_params()`.
- `test_shader_compiles`: load the shader and check that `RenderingServer.shader_get_parameter_list` (or `Shader.get_shader_uniform_list()`) contains every uniform name above.

**Visual verification (windowed, not headless):** a `sim/tools/swarm_check.gd` scene adds 50k fleas plus 2k wasps plus 3 deer to the bare room plus boxes. It runs 10 s, prints the average FPS, saves `build/swarm_check.png`, and greps stderr for "SHADER ERROR". Expected: FPS ≥ 60, no shader errors, and the screenshot shows animals inside the room. The coordinator inspects the screenshot.

Commit with the message "feat(sim): GPU particle swarms".

---

### Task 11: Main scene integration

**Files:**
- Create `sim/scenes/main.tscn`, `sim/scripts/main.gd`, `sim/scripts/sim/population.gd`, `sim/tests/test_population.gd`, `sim/tests/test_main.gd` and `sim/tools/screenshot.gd`.
- Modify `sim/project.godot` to set the main scene.

**Interfaces:**
- Consumes everything above.
- Produces `Population`: `add(id, count)`, `clear()`, `counts() -> Dictionary`, `total() -> int`.
- `main.gd` wiring:
  - **Scene:** builds the room (T9) and furniture (T8). It builds a `CollisionWorld` from the rects, the column boxes plus the furniture boxes, and the ceiling, and configures the `SwarmManager`.
  - **Camera:** adds the camera, whose `moved` signal goes through `RoomGeometry.walls_facing_camera` to `Cutaway.apply`.
  - **HUD:** fills it from `SpeciesDB`. `add_requested` goes to `SwarmManager.add` and `Population.add`, and `clear_requested` clears both. `credits_requested` shows `res://CREDITS.md`.
  - **Readout:** the FPS readout updates every 0.5 s.

**Tests (write first):**
- `test_population_bookkeeping`
- `test_main_wires_add`: instantiate `main.tscn`, emit the HUD's `add_requested("flea", 10)`, process frames, and check that `Population.counts()["flea"] == 10` and that the swarm manager count matches.
- `test_add_clear_spam`: 20 alternating adds and clears end with zero batches and zero counts (Review Focus 4).
- `test_cutaway_follows_camera`: moving the camera north of the room stubs wall 2.
- `test_credits_loads`

**Visual verification:** `sim/tools/screenshot.gd` runs the main scene windowed. It adds 5,000 fleas, 200 fireflies, 50 wasps and 2 deer, then saves screenshots from 3 camera presets (overview, lounge close-up, a desk close-up at a distance of 0.1 m) to `build/shots/`. The coordinator inspects them for recognisable furniture, the cutaway and visible fleas.

Commit with the message "feat: main scene wiring".

---

### Task 12: Exports and README

**Files:**
- Create `sim/export_presets.cfg` and `README.md`.
- Modify `.gitignore` if needed (`build/`).

- [ ] **Step 1:** Install the Godot 4.7.2 export templates. Download `Godot_v4.7.2-stable_export_templates.tpz` from the official GitHub release, then unzip it into `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`.
- [ ] **Step 2:** Create presets:
  - "macOS": universal, unsigned (`codesign/codesign=0`)
  - "Windows Desktop": x86_64
  - "Web": best-effort
  
  Exclude filters for each: `tools/*`, `tests/*`, `addons/gut/*` and `assets/animals/src/*`.
- [ ] **Step 3:** Run `godot --headless --path sim --export-release "macOS" ../build/mac/CHNM-Critter-Sim.zip`. The macOS export needs the zip extension. Then export Windows to `../build/win/CHNM-Critter-Sim.exe`, then Web to `../build/web/index.html`. Mac and Windows must succeed. If Web fails, record why in the README and drop it.
- [ ] **Step 4:** Unzip the mac build and launch it with `open`. Confirm it starts by capturing a screenshot via `screencapture` after 5 s, then quit.
- [ ] **Step 5:** Write `README.md`: what it is, how to run from source (`godot --path sim`), the downloaded builds (macOS: right-click → Open), the controls, how to run the tests (`scripts/test.sh`), how to regenerate meshes, and a credits pointer.
- [ ] **Step 6:** Run the full test suite, then commit with the message "build: desktop exports and README".
