extends GutTest

const SHADER_PATH := "res://shaders/critter_process.gdshader"
const UNIFORMS := [
	"room_rects", "room_rect_count", "rect_cdf", "box_min", "box_max", "box_count", "ceiling",
	"is_hopper", "speed", "hop_speed", "body_length", "seed",
]

func _world() -> CollisionWorld:
	var boxes: Array[AABB] = RoomGeometry.column_boxes()
	boxes.append(AABB(Vector3(15, 0, 5), Vector3(1.5, 0.75, 0.75)))
	return CollisionWorld.new(RoomData.RECTS, boxes, RoomData.CEILING)

func _manager() -> SwarmManager:
	var m := SwarmManager.new()
	add_child_autofree(m)
	m.configure(_world())
	return m

func _total(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n

func test_shader_compiles() -> void:
	var shader := load(SHADER_PATH) as Shader
	assert_not_null(shader)
	var names: Array[String] = []
	for u in shader.get_shader_uniform_list():
		names.append(String(u["name"]))
	for want in UNIFORMS:
		assert_has(names, want, "uniform %s" % want)

## start() mirrors RoomGeometry.random_spawn_xz: reject a spawn only when the 3D point
## (x, SPAWN_Y, z) is inside a box, not when it is merely above a box footprint.
func test_shader_spawn_mirrors_room_geometry() -> void:
	var code := (load(SHADER_PATH) as Shader).code
	var m := RegEx.create_from_string("const float SPAWN_Y = ([0-9.]+);").search(code)
	assert_not_null(m)
	if m:
		assert_almost_eq(float(m.get_string(1)), RoomGeometry.SPAWN_Y, 1e-6)
	assert_false(code.contains("in_box_footprint"), "no footprint rejection")
	assert_true(code.contains("in_any_box(vec3(xz.x, SPAWN_Y, xz.y))"), "3D point rejection")

func test_rect_cdf_is_normalised_area_prefix_sums() -> void:
	var cdf := SwarmBatch.rect_cdf(_world().to_shader_params())
	assert_eq(cdf.size(), 8)
	var total := 0.0
	for r in RoomData.RECTS:
		total += r.get_area()
	var acc := 0.0
	for i in RoomData.RECTS.size():
		acc += RoomData.RECTS[i].get_area()
		assert_almost_eq(cdf[i], acc / total, 1e-6)
	for i in range(RoomData.RECTS.size(), 8):
		assert_eq(cdf[i], 1.0, "padding stays at 1")

func test_batch_settings() -> void:
	var sp := SpeciesDB.get_species("flea")
	var b := SwarmBatch.create(sp, 234, _world().to_shader_params(), 7)
	autofree(b)
	assert_eq(b.amount, 234)
	assert_eq(b.explosiveness, 1.0)
	assert_true(b.one_shot)
	assert_eq(b.lifetime, 1.0e6)
	assert_eq(b.fixed_fps, 0)
	assert_false(b.interpolate)
	assert_eq(b.species_id, "flea")
	assert_eq(b.draw_pass_1, load(sp["mesh_path"]))
	var room := AABB(Vector3.ZERO, Vector3(31.5, 2.9, 14.8))
	assert_true(b.visibility_aabb.encloses(room), "visibility covers room: %s" % b.visibility_aabb)
	assert_true(b.visibility_aabb.position.x < 0.0 and b.visibility_aabb.end.y > 2.9, "with a margin")

func test_batch_uniforms_match_world() -> void:
	var params := _world().to_shader_params()
	var b := SwarmBatch.create(SpeciesDB.get_species("wasp"), 10, params, 3)
	autofree(b)
	var pm := b.process_material as ShaderMaterial
	assert_eq(pm.shader, load(SHADER_PATH))
	for key in ["room_rects", "box_min", "box_max"]:
		assert_eq(Array(pm.get_shader_parameter(key)), Array(params[key]), key)
	for key in ["room_rect_count", "box_count", "ceiling"]:
		assert_eq(pm.get_shader_parameter(key), params[key], key)
	assert_eq(Array(pm.get_shader_parameter("rect_cdf")), Array(SwarmBatch.rect_cdf(params)))
	assert_eq(pm.get_shader_parameter("seed"), 3)

func test_batch_species_uniforms() -> void:
	var params := _world().to_shader_params()
	for id in ["flea", "wasp"]:
		var sp := SpeciesDB.get_species(id)
		var b := SwarmBatch.create(sp, 10, params, 1)
		autofree(b)
		var pm := b.process_material as ShaderMaterial
		assert_eq(pm.get_shader_parameter("is_hopper"), sp["motion"] == "hopper", id)
		assert_almost_eq(float(pm.get_shader_parameter("speed")), float(sp["speed_mps"]), 1e-6, id)
		assert_almost_eq(float(pm.get_shader_parameter("hop_speed")), SpeciesDB.hop_speed(sp), 1e-6, id)
		assert_almost_eq(float(pm.get_shader_parameter("body_length")), float(sp["body_length_m"]), 1e-6, id)

func test_emissive_species_gets_duplicated_emissive_materials() -> void:
	var sp := SpeciesDB.get_species("firefly")
	var shared := load(sp["mesh_path"]) as Mesh
	var b := SwarmBatch.create(sp, 10, _world().to_shader_params(), 1)
	autofree(b)
	var mesh := b.draw_pass_1
	assert_ne(mesh, shared, "mesh duplicated")
	assert_eq(mesh.get_surface_count(), shared.get_surface_count())
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i) as BaseMaterial3D
		var orig := shared.surface_get_material(i) as BaseMaterial3D
		assert_ne(m, orig, "surface %d material duplicated" % i)
		assert_true(m.emission_enabled)
		assert_eq(m.emission, Color("#d8ff6a"))
		assert_eq(m.emission_energy_multiplier, 4.0)
		assert_ne(orig.emission_energy_multiplier, 4.0, "shared material untouched")
		assert_ne(orig.emission, Color("#d8ff6a"), "shared material untouched")

func test_non_emissive_species_shares_mesh() -> void:
	var sp := SpeciesDB.get_species("wasp")
	var b := SwarmBatch.create(sp, 10, _world().to_shader_params(), 1)
	autofree(b)
	assert_eq(b.draw_pass_1, load(sp["mesh_path"]))

func _tris(mesh: Mesh) -> int:
	var n := 0
	for i in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n

func test_crowd_batch_uses_decimated_mesh_without_shadows() -> void:
	var sp := SpeciesDB.get_species("flea")
	var shared := load(sp["mesh_path"]) as Mesh
	var b := SwarmBatch.create(sp, SwarmBatch.CROWD_MIN, _world().to_shader_params(), 1)
	autofree(b)
	var mesh := b.draw_pass_1
	assert_ne(mesh, shared)
	assert_eq(mesh.get_surface_count(), shared.get_surface_count())
	var full := _tris(shared)
	var low := _tris(mesh)
	assert_lt(low, full, "fewer triangles")
	assert_gte(low * 8, full, "at most 8x fewer")
	assert_eq(mesh.surface_get_material(0), shared.surface_get_material(0), "materials kept")
	assert_eq(b.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

func test_every_species_has_a_crowd_mesh() -> void:
	var params := _world().to_shader_params()
	for sp in SpeciesDB.load_all():
		var shared := load(sp["mesh_path"]) as Mesh
		var b := SwarmBatch.create(sp, SwarmBatch.CROWD_MIN, params, 1)
		autofree(b)
		assert_eq(b.draw_pass_1.get_surface_count(), shared.get_surface_count(), sp["id"])
		assert_between(_tris(b.draw_pass_1) * 8, _tris(shared), _tris(shared) * 8, sp["id"])

func test_small_batch_keeps_full_mesh_and_shadows() -> void:
	var sp := SpeciesDB.get_species("deer")
	var b := SwarmBatch.create(sp, SwarmBatch.CROWD_MIN - 1, _world().to_shader_params(), 1)
	autofree(b)
	assert_eq(b.draw_pass_1, load(sp["mesh_path"]))
	assert_eq(b.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

func test_emissive_crowd_is_decimated_and_glows() -> void:
	var sp := SpeciesDB.get_species("firefly")
	var shared := load(sp["mesh_path"]) as Mesh
	var b := SwarmBatch.create(sp, 50_000, _world().to_shader_params(), 1)
	autofree(b)
	assert_lt(_tris(b.draw_pass_1), _tris(shared))
	for i in b.draw_pass_1.get_surface_count():
		var m := b.draw_pass_1.surface_get_material(i) as BaseMaterial3D
		assert_eq(m.emission, Color("#d8ff6a"))
		assert_eq(m.emission_energy_multiplier, 4.0)
		assert_ne(m, shared.surface_get_material(i))

func test_add_creates_batches() -> void:
	var m := _manager()
	m.add(SpeciesDB.get_species("flea"), 250_000)
	assert_eq(m.batch_count(), 1, "first batch immediately")
	await wait_process_frames(4)
	assert_eq(m.batch_count(), 3)
	var amounts: Array[int] = []
	for c in m.get_children():
		amounts.append((c as SwarmBatch).amount)
	amounts.sort()
	assert_eq(amounts, [50_000, 100_000, 100_000])
	assert_eq(m.count_by_species(), {"flea": 250_000})

func test_add_creates_one_batch_per_frame() -> void:
	var m := _manager()
	m.set_process(false)  # drive frames by hand
	m.add(SpeciesDB.get_species("flea"), 250_000)
	assert_eq(m.batch_count(), 1)
	m._process(0.016)
	assert_eq(m.batch_count(), 2)
	m._process(0.016)
	assert_eq(m.batch_count(), 3)
	m._process(0.016)
	assert_eq(m.batch_count(), 3)

func test_counts_include_pending_batches() -> void:
	var m := _manager()
	m.add(SpeciesDB.get_species("flea"), 250_000)
	assert_eq(m.count_by_species(), {"flea": 250_000})

func test_clear_frees_all() -> void:
	var m := _manager()
	m.add(SpeciesDB.get_species("flea"), 250_000)
	m.add(SpeciesDB.get_species("wasp"), 10)
	await wait_process_frames(1)
	m.clear()
	assert_eq(m.batch_count(), 0)
	assert_eq(m.count_by_species(), {})
	await wait_process_frames(3)
	assert_eq(m.get_child_count(), 0, "nodes freed, pending dropped")

func test_counts_by_species_mixed() -> void:
	var m := _manager()
	m.add(SpeciesDB.get_species("flea"), 150_000)
	m.add(SpeciesDB.get_species("wasp"), 2_000)
	m.add(SpeciesDB.get_species("deer"), 3)
	m.add(SpeciesDB.get_species("flea"), 7)
	await wait_process_frames(5)
	assert_eq(m.count_by_species(), {"flea": 150_007, "wasp": 2_000, "deer": 3})
	assert_eq(m.batch_count(), 5)
	assert_eq(_total(m.count_by_species()), 152_010)

func test_add_zero_is_noop() -> void:
	var m := _manager()
	m.add(SpeciesDB.get_species("flea"), 0)
	await wait_process_frames(1)
	assert_eq(m.batch_count(), 0)
	assert_eq(m.count_by_species(), {})
