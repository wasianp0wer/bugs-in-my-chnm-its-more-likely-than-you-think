# GPU particle spike: report

Godot 4.7.2 stable, macOS, Apple M4 Pro, Metal 3.2. The window is 1600×900, and the screenshots are 1600×900, so it renders at 1× and not at Retina 2×.

**Verdict:** every mechanism works, and 50k (and 250k) particles run at the display refresh rate. There are no blockers for Task 10. Five behaviours need care, and Task 10 must follow them:

1. **lifetime must be huge.** With a short lifetime, the particles freeze.
2. **Never change `amount` on a live batch.** Doing so resets every particle in it.
3. **Hidden or culled batches pause.** They resume where they left off and do not reset.
4. **Everything spawned with the same start state hops in lock-step.** Add per-particle jitter.
5. **`emitting` reads `false` immediately.** Do not "fix" it by setting it back to `true`, because that restarts the batch.

Files: `critter.gdshader` (process shader), `main.gd` (driver; its CLI flags are at the top), `main.tscn` and `project.godot`.
Run: `godot --path spikes/gpu --quit-after 600` (the brief's command). Extra flags go after `--`, e.g. `-- --batches=5 --duration=8`.

## 1. FPS

Each run lasted 8 s. The FPS is the average of `Engine.get_frames_per_second()` once per second, skipping the first 2 s. Each particle is a 12-triangle box with the default StandardMaterial3D and vertex colour, plus one directional light.

| Config | Particles | FPS, Forward+ | FPS, Compatibility |
|---|---|---|---|
| 0 batches (empty room) | 0 | 119 | – |
| **1 batch × 50k** | 50k | **120** (119.9) | 119 |
| **5 batches × 50k** | 250k | **120** (120.0) | 120 |
| 5 × 50k, forced 16 sub-steps every frame | 250k | 120 | – |
| 1 batch × 250k | 250k | 120 | – |
| 5 × 50k, camera low inside the room (fill worst case) | 250k | 111–118 | 119 |
| 10 × 50k | 500k | 116–138 | – |
| 10 × 50k, 16 sub-steps | 500k | 116 | – |
| 20 × 50k | 1M | 72 / 113 / 117 | 63 |
| 20 × 50k, close camera | 1M | 53–66 | – |
| 40 × 50k | 2M | 101 / 134 / 141 | – |
| 80 × 50k | 4M | 81 | – |

- With vsync on (the default), the display caps at about 120 Hz (ProMotion). Up to 500k particles the cap is reached, so 50k has a lot of headroom.
- macOS frame pacing is noisy. Repeated runs of the same configuration varied by ±30 fps above about 1M particles. Some runs reported over 120 even with vsync on. Treat 1M+ numbers as rough.
- **`--novsync` is useless on this Mac.** With vsync disabled, every configuration, including an *empty room with 0 particles*, sits at about 80 fps. That is an artifact of the platform's presentation, not a measure of particle cost. Measure with vsync on.
- `viewport_get_measured_render_time_gpu()` always returns 0.00 on Metal, so GPU timing is not available. CPU frame time stays at 0.03–0.3 ms whatever the count: the particle work is entirely on the GPU.
- Forcing 16 sub-steps per frame (each with a box loop) had no measurable cost at 250k–500k.
- `fixed_fps` 30 vs 0 made no FPS difference (82 vs 80 in the capped novsync mode).

## 2. Uniform arrays: they work

`uniform vec4 room_rects[8]; uniform vec3 box_min[128]; uniform vec3 box_max[128]; uniform int box_count;` compile and read correctly in a `shader_type particles` shader, in both Forward+ and Compatibility.

- **How it was proven:** I used GPU read-back through `RenderingServer.particles_get_current_aabb(batch.get_base())` with `--boxtest`, a single box covering the whole floor up to y = 1.5. The minimum particle y stayed at or above 1.5 (1.62–1.94) for the whole run. So `box_min[0]`, `box_max[0]` and `box_count` reach the shader. In the normal run, x/z never left [0, 10], so `room_rects[0]` works.
- **Setting from GDScript:** pass a `PackedVector4Array` or `PackedVector3Array`. The array may be **shorter than declared**: I passed 1 of 128 elements and it worked. Loop only to `box_count`.
  ```gdscript
  var rects := PackedVector4Array(); rects.resize(8); rects[0] = Vector4(x0, z0, x1, z1)
  mat.set_shader_parameter("room_rects", rects)
  mat.set_shader_parameter("box_min", PackedVector3Array([Vector3(3, 0, 3)]))
  mat.set_shader_parameter("box_max", PackedVector3Array([Vector3(6, 1.2, 6)]))
  mat.set_shader_parameter("box_count", 1)
  ```
- **Live changes:** changing a uniform on a running batch, e.g. `hop_speed` 3 → 5 at t = 3 s, takes effect next frame with **no reset**.
- **Uniform listing:** unused uniforms (e.g. `room_rect_count`) are still listed by `Shader.get_shader_uniform_list()`. This works **headless** too (dummy renderer), so Task 10's `test_shader_compiles` works headless. Array uniforms report `type=38` (PackedVector4Array) and `type=36` (PackedVector3Array).
- **Shader errors:** a broken shader prints `SHADER ERROR: ...` and `ERROR: Shader compilation failed.` to stderr, even headless. `get_shader_uniform_list()` then returns `[]`.

## 3. Per-particle state persists

`TRANSFORM`, `VELOCITY`, `COLOR` and `CUSTOM` persist between frames, so:

- velocity lives in `VELOCITY`
- position lives in `TRANSFORM[3].xyz`
- the colour or tint is written once in `start()`.

Use `render_mode disable_velocity` so that Godot does **not** also add `VELOCITY * DELTA` to the position after `process()`. Without it you would integrate twice. `disable_force` turns off the built-in gravity and attractor terms.

```glsl
shader_type particles;
render_mode disable_velocity, disable_force;
void process() {
    vec3 p = TRANSFORM[3].xyz;
    vec3 v = VELOCITY;
    int n = clamp(int(ceil(length(v) * DELTA / max_step)), 1, max_substeps);
    float h = DELTA / float(n);
    for (int i = 0; i < n; i++) { v.y -= gravity * h; vec3 q = p + v * h; /* collide q, v */ p = q; }
    VELOCITY = v;
    TRANSFORM = oriented(p, v);   // see section 6
}
```

Randomness comes from an integer hash of `INDEX` and `RANDOM_SEED`, both `uint`. `uint`, hex literals with a `u` suffix, `^`, `>>` and `TAU` all compile in both renderers:

```glsl
float hash01(uint x) { x ^= x >> 16u; x *= 0x7feb352du; x ^= x >> 15u; x *= 0x846ca68bu; x ^= x >> 16u; return float(x) / 4294967295.0; }
void start() { uint seed = INDEX * 747796405u + RANDOM_SEED * 2891336453u; float r0 = hash01(seed), r1 = hash01(seed + 1u); ... }
```

Each batch gets a different `RANDOM_SEED` automatically. Two batches added at different times did not overlap, as the colours show in `shot_add.png`. Task 10 wants a `seed` parameter as well: pass it as a uniform and mix it in.

## 4. Alive forever: `one_shot` + `explosiveness 1` + lifetime 1e6

This works. It is required, and so is the lifetime.

- **Lifetime 1e6:** particles stayed alive and kept moving for a 30 s run with no change. (Read-back showed the AABB kept oscillating in the synchronised `--boxtest` run through 8 s.)
- **Control run with `--lifetime=2`:** the particles do **not** disappear. Custom process shaders never clear `ACTIVE`; only `ParticleProcessMaterial`'s generated code does that. But the emitter goes **inactive** at about 2× lifetime: between t = 4 s and t = 5 s the read-back AABB froze and stayed identical for every following second. The particles are still drawn, but **frozen in time**. So the huge lifetime is what keeps them processing. Keep `lifetime = 1e6`.
- **`emitting` after spawn:** `emitting` reads `false` from the first second on. A one-shot explosive emitter spawns everything on frame 1 and clears the flag. This is normal, and the particles keep simulating. **Do not set `emitting = true` again and do not call `restart()`**: both re-run `start()` for every particle.
- **Batch settings that work:**
  ```gdscript
  p.amount = count
  p.lifetime = 1.0e6
  p.one_shot = true
  p.explosiveness = 1.0
  p.randomness = 0.0
  p.fixed_fps = 0          # simulate every rendered frame (default is 30!)
  p.interpolate = false    # interpolation only matters with fixed_fps > 0
  p.visibility_aabb = AABB(Vector3(-0.5, -0.5, -0.5), room_size + Vector3.ONE)
  p.process_material = shader_material
  p.draw_pass_1 = mesh
  p.emitting = true
  ```
  The node is left at the identity transform. `local_coords` stays at its default (false), so `TRANSFORM` is in world space.

## 5. Adding batches at runtime: a new node works; changing `amount` resets

- **New `GPUParticles3D` added at t = 3 s:** batch 0 is **not** reset.
  - Its read-back AABB right after the add is continuous with the second before.
  - `shot_add.png` (t = 3.2 s) shows batch 0 (orange) still hopping on the floor while batch 1 (blue) falls from y = 2.8.
  - The two batches then bounce out of phase, which proves independent state.
  - This works in both Forward+ and Compatibility (`shot_compat_close.png`).
- **Raising `amount` on a live batch (50k → 60k) re-spawns *all* of its particles** at y = 2.8 (`shot_grow.png`). The buffer is reallocated and the emitter restarts. Never grow a batch; add a new node.
- **`amount_ratio` 0.5 → 1.0 on a one-shot batch** did not visibly emit the missing particles. It is not a way to add particles either.
- **Read-back right after adding:** `particles_get_current_aabb()` on a batch added *this frame* errors with `Condition "buffer.size() != ..."`, because the buffer is not allocated yet. It is harmless, but tests that read back must wait a frame.

So `SwarmManager.add()` = one new `SwarmBatch` node per ≤ 100k chunk. Adding one per frame never disturbed existing batches. A single batch of 250k also ran at 120 fps, so there is **no practical `amount` limit** at these sizes.

## 6. Orienting and scaling `TRANSFORM`

Write the full basis every frame. It is not cumulative, so it is safe to rebuild from velocity.

**Basis** = R_y(yaw) × uniform scale. The mesh is modelled 1 m long, facing +Z.

```glsl
uniform float body_length = 0.08;
mat4 oriented(vec3 p, vec3 v) {
    float yaw = atan(v.x, v.z);            // yaw that maps +Z onto horizontal velocity
    float c = cos(yaw) * body_length;
    float s = sin(yaw) * body_length;
    return mat4(vec4(c, 0.0, -s, 0.0),     // column 0 = image of +X
                vec4(0.0, body_length, 0.0, 0.0),
                vec4(s, 0.0, c, 0.0),      // column 1 = +Y; column 2 = image of +Z = (sin, 0, cos)
                vec4(p, 1.0));             // column 3 = position
}
```

- `shot_close.png` and `shot_fwd_close.png` show the boxes elongated along their direction of travel, at the expected size.
- GLSL `mat4(...)` takes **columns**.
- Use `atan(y, x)` with two arguments, as Godot does; it means `atan2`.
- If `v.xz` is zero, the facing is undefined, which in practice means +Z. Not tested. Keep a last-heading fallback if speed can be zero.
- Optional: `normalize(v.xz)` gives `sin` and `cos` directly without trig.

## 7. Other gotchas

- **`fixed_fps` defaults to 30**, with `interpolate = true`. Set `fixed_fps = 0` so that `DELTA` = frame delta and every frame simulates, and set `interpolate = false`.
- **`visibility_aabb`:** the default is ±4 m around the node. Cover the whole room plus a margin, or particles get culled when the AABB leaves the view.
- **Hidden or culled batches pause:**
  - Setting `visible = false` for 2 s, or turning the camera away from the room for 2 s (the visibility AABB is off-screen), **pauses simulation**. The read-back stayed identical.
  - When the batch is visible again it resumes from where it was, with no reset.
  - So animals don't move while unseen. That is fine for this toy, but cutaway or hiding logic must not expect off-screen motion.
- **Lock-step hopping:**
  - Every particle starts at the same y with `vy = 0`, so they all land and hop **in lock-step**. This is obvious in `--boxtest`, where the read-back AABB height is 0 because every particle is at the same y.
  - Task 10 should jitter the initial `vy` or y per particle using the hash, or randomise `hop_speed` slightly.
- **Stuck in a box:** a particle spawned inside a box is trapped. That doesn't happen here, because spawn y = 2.8 is above the box. Task 10's re-sample loop is still needed for tall boxes.
- **`particles_get_current_aabb()`:**
  - It does a full GPU read-back (slow, debug only).
  - The returned AABB is grown on every side by the draw-pass mesh's longest axis: 1.0 here, so subtract 1.
  - It is the only way to get numbers out of the GPU sim for checks. A Task 10 visual check could use it to assert, for example, that `aabb.position + 1 >= room min`.
- **No shader-compile gotchas** came up. The shader compiled first try on Metal (Forward+) and on OpenGL 4.1 over Metal (Compatibility). It uses `uint`, bit ops, `for` loops bounded by uniforms, uniform arrays indexed by a loop variable, `all(greaterThan(...))`, and `source_color` on a `vec4` uniform.

## 8. Compatibility renderer (`--rendering-method gl_compatibility`)

It works: OpenGL API 4.1 over Metal on the M4 Pro.

- The same shader compiles unchanged, with no errors.
- Motion, walls, box, orientation and the runtime add all match Forward+. Compare `shot_compat_close.png` with `shot_fwd_close.png`, both taken at t = 3.1 s.
- FPS is 119–120 for 1 and 5 batches of 50k, and 63 for 1M.
- `particles_get_current_aabb()` read-back also works there.

This was desktop GL only. A real WebGL2 export was not tried (out of scope).

## Screenshots

| File | What it shows |
|---|---|
| `shot.png` | The brief's run (1 × 50k, t = 5 s) |
| `shot_add.png` | t = 3.2 s, just after a second batch was added at runtime (orange keeps hopping) |
| `shot_grow.png` | t = 3.2 s, just after raising `amount`: the whole batch reset to the top |
| `shot_close.png` | 5 × 50k, low camera: per-particle yaw and scale |
| `shot_fwd_close.png`, `shot_compat_close.png` | The same scene in Forward+ and in Compatibility |
