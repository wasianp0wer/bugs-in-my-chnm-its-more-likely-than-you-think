# Fix missing animals in exports; add chickens (2026-11-10)

## Bug: some animals don't appear in exported builds
**Root cause (verified):** 17 baked meshes in `sim/assets/animals/*.res` reference their
textures as external resources in `res://assets/animals/src/*.png` (e.g. deer -> `deer_Tex_Deer.png`,
dog -> `dog_dog_texture.png`). Both export presets exclude `assets/animals/src/*`, so the
textures never reach the .pck (no `.ctex` for them is packed). In the build the mesh load fails
and the species never spawns. In the editor the files are present, so it works.

## Tasks

### T1: Export only what the meshes need (parallel-safe with T2)
- Files: `sim/export_presets.cfg`, `README.md`, new `sim/tests/test_export_presets.gd`
- Depends on: none
- Test first: for every species mesh, every dependency (`ResourceLoader.get_dependencies`)
  must not match any preset's `exclude_filter` pattern. Fails today for 17 species.
- Fix: exclude only the source models (`assets/animals/src/*.glb`), keeping the textures.

### T2: Add chickens (parallel-safe with T1)
- Files: `models/chicken/chicken_quaternius_polypizza_Z3RCoCYss4.glb`, `models/CATALOG.md`,
  `sim/assets/animals/src/chicken.glb` (+ `.import`), `sim/assets/animals/chicken.res`,
  `sim/data/species.json`, `CREDITS.md`, `sim/CREDITS.md`, `sim/tests/species/test_species_db.gd`
- Depends on: none
- Model: "Chicken" by Quaternius, CC0 1.0, https://poly.pizza/m/Z3RCoCYss4
- Test first: species count 30 and `chicken` present; then bake and the existing baked-mesh /
  credits tests cover the rest.

T1 and T2 share no files. Merge T1, run the suite, merge T2, run the suite, then re-export both builds
and check the pack contains the textures.
