# CHNM Critter Sim: design

Date: 2026-11-09. Status: draft for review.

## 1. Intent

This is a just-for-fun 3D toy. You fill the main room of the Roy Rosenzweig Center for History and New Media (RRCHNM, 4th floor, Research Hall, George Mason University) with animals and insects, and watch them bounce around. The point is a laugh: a familiar office overrun by 5,000 fleas, a deer, and a cloud of wasps.

Success means someone who knows the office recognizes it, adds a ridiculous number of fleas, zooms in on a desk, and laughs.

### Goals
- Show a recognizable 3D model of CHNM's main room, including as much of the real furniture as the reference photos support.
- Let the user pick any available species and a count, then add them to the room. Species can be mixed freely.
- Make the animals bounce around inside the room indefinitely.
- Make it shareable, both as a web link and as desktop builds.

### Non-goals
- Animated models (walk cycles, wing flaps). All models are static.
- Ecological or behavioral realism beyond "roughly realistic bounce per species". There is no predation, breeding or swarming AI.
- The rest of the 4th floor or the rest of Research Hall.
- Night mode or a lighting toggle.
- Collisions between animals.

### Anti-goals
These would make it a failure even if it technically works:
- The room isn't recognizable as CHNM.
- Animals escape the room or sink through floors and furniture.
- The camera makes it hard to look into the room. Walls must never block the view.

## 2. The space

The source is `floor_plan/Research-Fourth-Floor-Plan.pdf`, a GMU "Architectural Rooms" plan. The user circled the main room in blue: rooms **461, 462, 472, 479, 470, 478**. The estimated geometry is in `floor_plan/DIMENSIONS.md`:

| Section | Rooms | Approx. size (E–W × N–S) |
|---|---|---|
| North-west block | 462, 472 | 10.2 × 10.7 m |
| West notch | 461 (beside Pantry 1) | 2.9 × 4.8 m |
| East band | 479, 470, 478 (upper) | 18.3 × 6.8 m |
| South-east extension | 470, 478 (lower, toward CORR1) | 11.1 × 4.1 m |

- **Bounding box:** about 32 × 15 m, about 290 m².
- **Ceiling height:** 2.9 m (9.5 ft), assumed.
- **Scale:** 1 Godot unit = 1 metre. All animals and furniture are at true-to-life size.
- **Accuracy:** about ±10–15%, because the scale is derived from the OpenStreetMap footprint. Trace the polygon from the PDF and keep all room geometry in one data file (or scene), so the dimensions can be corrected later without touching code.

### One open room
The user's decision: **one open room.** The plan's internal lines between 461, 462, 472, 479, 470 and 478 are not modelled as walls; they are most likely space-accounting divisions. This matches the photos of the former "Robot Room", which show a single large open space. The whole outlined polygon is one space that animals roam freely, broken up only by **2–4 square drywall-clad columns** about 0.6 m across (seen in photo 01). Their positions are an inference: put them where the plan's interior lines meet.

### Walls, windows, ceiling
- **Perimeter walls:** all of them are full height (2.9 m). There are no interior walls.
- **Exterior walls:** these are inferred from the PDF. The **north wall of the 462/472 block** is on the building's outer edge, and so is the **east wall of 478**. Every other perimeter edge borders offices (473–477), the corridor (CORR1) or the pantry, so it is interior.
- **Window bank:** a "bank of windows" runs along the **north wall of 462/472**. The windows are about 1.5 m wide × 1.6 m tall, with the sill about 0.75 m above the floor. They are paired between white piers about 0.6 m wide and have white horizontal blinds (photo 02). The east wall of 478 gets a couple of plain windows (inferred).
- **Finishes:** off-white painted drywall.
- **Doors:** 1–3 light-oak doors with a narrow vision slot, on walls facing the corridor or pantry. They are decorative and always closed, so animals bounce off them.
- **Floor:** tan/gold broadloom carpet.
- **Ceiling:** the 2×2 tile ceiling with fluorescent troffers is **not drawn**. There is an invisible collision "lid" at 2.9 m, so animals bounce off it.

### Cutaway (dollhouse) behaviour
Walls between the camera and the room interior cut down to a stub about 0.5 m high, i.e. knee height. As the camera orbits, the stubbed set updates, and the transition is smooth or instant (builder's call). A cut wall **still collides at full height**; only its visual changes. Columns are never cut away.

## 3. Furniture

Reference material lives in `reference/FURNITURE.md`, with photos in `reference/photos/`. The photos are from 2006–2014; nothing newer was found. The main room is identified as the former "Robot Room": a large open area that CHNM took over in 2009, with a lounge in front of a bank of windows (photos 01, 02 and 03).

Model these items for the main room. "Seen" means the item appears in photos of this room:

| Item | Count | Size | Look | Basis |
|---|---|---|---|---|
| Sofa, boxy 3-seat (Klippan-like) | 2–3 | 1.8 × 0.9 × 0.7 m | navy blue fabric | seen |
| Tub armchair | 1–2 | 0.8 × 0.7 × 0.75 m | white, light-wood legs | seen |
| Sling lounge chair | 1–2 | 0.7 × 0.8 m | white canvas | seen |
| Coffee table with lower shelf | 1 | 1.2 × 0.6 × 0.45 m | medium oak | seen |
| Credenza under the window, with owl lamp | 1 | 1.5 × 0.5 × 0.75 m | wood, ivory lamp shade | seen |
| Tall wardrobe cabinets | 3–5 | 0.9 × 0.6 × 2.0 m | black laminate | seen |
| TV on media stand | 1 | stand 1.0 × 0.45 × 0.75 m | black | seen |
| Mobile whiteboard | 1–2 | 1.2 × 0.9 board, 1.8 m tall | white, aluminium | seen |
| AV cart with 3D printer | 1 | 0.8 × 0.5 × 0.9 m | black steel | seen |
| Desks, single pedestal / L | 6–12 | 1.5 × 0.75 m | cherry laminate | seen; count inferred |
| Folding group tables | 2–4 | 1.8 × 0.75 m | white top, black legs | seen; count inferred |
| Mesh task chairs | 10+ | standard | black mesh | seen |
| Stacking guest chairs | 3–4 | standard | grey | seen |
| Black bookcases | 1–3 | 0.9 × 0.3 × 1.8 m | black | inferred for this room |
| Plants (ficus/palm) | 1–2 | 1.2–1.8 m | green | inferred for this room |
| Kitchenette counter by pantry/461 | 1 | about 2.4 m run | laminate, sink, fridge | inferred, no photo |

**Layout** (builder's call, but follow this intent):
- **Lounge:** sofas in an L/U around the coffee table, against the window bank on the north wall of 462/472. The owl lamp credenza sits under a window.
- **Storage wall:** the black cabinets, TV and whiteboard go along an interior wall facing the lounge.
- **Workspace:** desks with task chairs fill the rest of the room, plus a couple of group tables.

Nothing documents the exact positions, so a plausible arrangement is fine. Keep the furniture layout in one editable scene, separate from the room geometry.

**Modelling approach** (builder's call):
- **Free CC0 furniture models:** use them where they fit, e.g. Kenney's Furniture Kit. Record each in the credits.
- **Simple primitives:** use simple shapes built in Godot or Blender for the rest.
- **Colours:** match the photos (navy sofas, black cabinets, cherry desks), rather than chasing detail.

Every furniture piece needs a simple collision shape: a box or a few boxes.

## 4. Animals

### Species
The picker offers **every species with a model on disk in `models/<species>/`**. That is 29 today:

ant, bat, bee, beetle, butterfly, cat, caterpillar, centipede, cockroach, crow, deer, dog, dragonfly, firefly, flea, frog, grasshopper, hornet, housefly, ladybug, moth, mouse, pigeon, raccoon, rat, snake, spider, squirrel, wasp.

- **Choosing a model:** where a species has more than one model, pick one, preferring GLB over `.blend` and the best-looking at low poly count. Record the choice in a species data file.
- **Model sources:** the firefly is `models/firefly/lowpoly_firefly.glb` ("Lowpoly Firefly", Caledhril, Sketchfab, CC-BY). The flea is `models/flea/flea.glb` ("Flea (animation test)", nodoxi, Sketchfab, CC-BY). Other provenance and licences are in `models/CATALOG.md`.
- **True-to-life size:** each species gets a real-world body length in its data entry, and the model is scaled to it. For example, a flea is about 2.5 mm, an ant about 6 mm, a wasp about 15 mm, a mouse about 8 cm body, a cat about 45 cm, a deer about 1.8 m long. Some of the source models are unit-less or arbitrarily scaled, so normalise them.
- **Fireflies:** give them an emissive abdomen or overall emissive tint, so there's a soft glow even in daylight.

### Motion
These rules are the user's.

- **Bounce forever:** animals never lose energy and never come to rest.
- **Hop rule** (my call, reconciling "bounce forever" with per-species hops): a hopper that lands on the floor or a furniture top is **relaunched upward at its species' hop speed**, rather than reflecting its incoming speed. So an animal that rained in from 2.9 m settles into its species hop after the first landing and keeps hopping at that height forever.
- **Horizontal motion** (my call): walkers and hoppers keep a constant horizontal speed. Their heading reflects off walls and furniture sides, and turns by a small random angle on each landing so the motion looks lively.
- **Collisions:** animals bounce off the floor, walls (always at full height, even when cut away), the invisible ceiling lid, and furniture. Animals pass through each other.
- **Per-species, roughly realistic:**
  - **Hoppers and walkers** (flea, ant, spider, cockroach, beetle, ladybug, grasshopper, caterpillar, centipede, frog, mouse, rat, squirrel, cat, dog, raccoon, deer, snake): under gravity, they bounce off the floor and furniture tops with a per-species launch speed and hop height. Fleas jump very high relative to their size (about 20 cm). Ants and caterpillars barely hop. Deer bound.
  - **Flyers** (firefly, wasp, hornet, bee, housefly, moth, butterfly, dragonfly, bat, crow, pigeon): no gravity. They travel in straight lines at a per-species speed and reflect off every surface, including the lid, so they fill the air.
  - **Facing:** each animal faces its direction of travel (yaw at least), so they don't look like sliding props.
- **Arrival:** new animals rain down through the open ceiling. They spawn just below the lid (or a little above, then fall in) at random x/z positions inside the room polygon, and not inside furniture.
- **No cap:** there is no limit on the count. If someone adds a million fleas and it slows to a crawl, that's part of the joke. The frame-rate readout makes the slowdown visible. Very large single adds should not freeze the UI for long, so spread spawning across frames if needed.

### Performance and architecture
These are the user's decisions:
- **Target:** at least **50,000 animals smooth (≥ 60 fps)** in the desktop build on a typical recent laptop, e.g. an Apple Silicon MacBook. The web build may be lower but should still handle tens of thousands. Past the target it may slow down; there is still no cap.
- **Motion runs on the GPU**, not in a GDScript loop. Use **one GPU particle system per species**, i.e. `GPUParticles3D` with the species mesh as the draw pass, driven by a **custom particle process shader**. That shader does the integration and collision against the simplified static geometry:
  - room polygon walls
  - floor and lid planes
  - columns
  - furniture boxes

  Pass the static geometry to the shader as uniforms or a small data texture. Particles never expire: they live forever and are added by raising the emitter's particle count, or with an equivalent approach.
- **Web is optional** (the user's update after approval): the desktop build on a laptop is the deliverable, and it is distributed through a git repo. Use the Forward+ renderer. Don't sacrifice desktop quality or effort for the Compatibility (WebGL2) renderer. If the web export doesn't work, drop it after the build is complete.
- **Testability:** the user requires test-driven development. Keep a **GDScript reference implementation** of the motion rules (step, reflect, hop relaunch, lid/floor/wall/box collision) that unit tests drive. The shader mirrors it. Where feasible, add a headless or visual check that a GPU run matches the reference qualitatively: e.g. after N seconds, no particle is outside the room or inside a box.
- Everything else is plain GDScript with unit tests: species data, spawning, counts, the cutaway selection and generating the geometry the shader reads.
- Animal-to-animal collisions are deliberately excluded.
- Tiny animals must stay stable at high speed with no tunnelling through thin geometry. Sub-step or clamp per-step distance.

## 5. Camera

- **View:** a dollhouse view looking down into the room from above at an angle.
- **Controls:**
  - Drag to orbit.
  - Scroll or pinch to zoom.
  - Right-drag or two-finger drag to pan.
- **Zoom range:** from the whole room in view down to close enough that a single 2.5 mm flea is clearly visible on a desk. The near clip plane must allow this.
- **Limits:** keep the orbit centre roughly within the room. Pitch stays between nearly top-down and about 20° above horizontal.
- **Starting view:** the whole room, looking toward the window bank.

## 6. Controls UI

The user picked the "floating cards" layout. Mockup: `.superpowers/brainstorm/*/content/controls-layout-v2.html`, option C.

- **Add card, top left:**
  - species dropdown, with all species alphabetical
  - quick-amount buttons 10 / 100 / 1k / 10k, which set the count field
  - a number field for any amount
  - an **Add** button
- **Counter card, top right:**
  - one line per species currently in the room, with its count
  - the total count
  - the current FPS
  - a **Clear** button that removes everything
  - a small **ⓘ** button that opens the credits screen
- The cards must not block camera drag elsewhere on screen.

## 7. Lighting

Daytime office only, with no toggle:
- bright, even interior light, as from the fluorescent troffers
- daylight through the window bank

A gentle glow post-effect may be used so fireflies read as glowing.

## 8. Credits and licensing

- **`CREDITS.md`** at the project root lists every third-party asset (animal models, furniture models, fonts) with its title, author, source URL and licence. CC-BY 3.0 models from Poly Pizza credit "Poly by Google" where they are labelled that way. CC0 models are listed as a courtesy.
- **In-app credits screen**, opened from ⓘ, shows the same content.
- Do not use non-commercial (NC) or share-alike (SA) assets. `models/CATALOG.md` flags them.
- `reference/photos/` is reference only. Do not ship it in builds. Some photos show identifiable people.

## 9. Technology and delivery

- **Engine:** Godot 4.6, scripted in **GDScript only**. C# can't export to the web.
- **Renderer:** use Forward+ for desktop. A web export is attempted at the end on a best-effort basis, and dropped if it doesn't work.
- **Deliverables** (exports only, the user's decision):
  1. **Unsigned desktop builds** for macOS and Windows. This is the required deliverable. The project is distributed through a git repo.
  2. A **web export**, which is optional and best-effort. Drop it if it doesn't work.

  Publishing, code signing and notarisation are out of scope. Mac users will need right-click → Open; note that in a short README.
- **Assets:**
  - GLB imported directly.
  - The two `.blend` files and the wasp `.zip` are optional and can be skipped, because each of those species already has GLB models.
  - Blender is optional and only for asset prep.
- **Tooling note:** Godot is not installed on this machine yet. Installing it is part of setup. Headless Godot, the `--headless` CLI, is needed for running tests.
- **Tests:** the user requires test-driven development. Use a GDScript test framework (GUT or gdUnit4, builder's call) that can run headless. Test the logic: the bounce integrator, collision reflection, species data loading and scaling, spawn placement inside the polygon and outside furniture, count bookkeeping, and the cutaway selection based on camera direction. The rendering itself doesn't need automated tests.

## 10. Left to the builder

- Exact furniture positions and counts within the ranges above.
- The exact per-species speeds and hop heights.
- Which model to use for multi-model species.
- The cutaway transition style.
- The test framework.
- The project layout inside the Godot project.
- Whether to model furniture as primitives or with CC0 kits.

## 11. Calls made by the designer (not confirmed by the user)

- **Exterior walls:** the window bank is on the north wall of 462/472, and the east wall of 478 is also exterior. Inferred from the PDF.
- **Columns:** 2–4, placed at the plan's internal line junctions.
- **Doors:** decorative, always closed.
- **Hop rule:** relaunch at species hop speed on every landing, plus a small random heading turn.
- **Performance target:** "smooth" means ≥ 60 fps at 50k on a recent laptop in the desktop build.
- **Cutaway:** walls cut to a 0.5 m stub, and columns are never cut.
- **Models:** the `.blend` and `.zip` models may be skipped.
