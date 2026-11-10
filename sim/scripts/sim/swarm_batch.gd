class_name SwarmBatch
extends GPUParticles3D
## One GPU-simulated batch of a single species. Every particle spawns once and lives
## forever (one_shot + explosiveness 1 + huge lifetime); see spikes/gpu/REPORT.md.
## Never change `amount`, `emitting` or call restart() on a live batch: it re-spawns all.

const SHADER: Shader = preload("res://shaders/critter_process.gdshader")
const LIFETIME := 1.0e6
const VISIBILITY_MARGIN := 1.0
const EMISSION_COLOR := Color("#d8ff6a")
const EMISSION_ENERGY := 10.0
## Batches this large draw a decimated mesh and cast no shadows: at 50k animals the
## baked meshes (~0.5-5k triangles each) and their shadow passes dominate frame time.
const CROWD_MIN := 1000
## Crowd meshes keep at least 1/CROWD_DECIMATE_MAX of each surface's triangles.
const CROWD_DECIMATE_MAX := 8

static var _crowd_meshes: Dictionary = {}  # species id -> decimated ArrayMesh

var species_id: String = ""


static func create(sp: Dictionary, count: int, world_params: Dictionary, seed: int) -> SwarmBatch:
	var b := SwarmBatch.new()
	b.name = "%s_batch" % sp["id"]
	b.species_id = sp["id"]
	var pm := ShaderMaterial.new()
	pm.shader = SHADER
	pm.set_shader_parameter("is_hopper", sp["motion"] == "hopper")
	pm.set_shader_parameter("speed", float(sp["speed_mps"]))
	pm.set_shader_parameter("hop_speed", SpeciesDB.hop_speed(sp))
	pm.set_shader_parameter("body_length", float(sp["body_length_m"]))
	pm.set_shader_parameter("clearance", MotionRules.clearance(sp))
	pm.set_shader_parameter("seed", seed)
	b.process_material = pm
	b.set_world_params(world_params)
	var crowd := count >= CROWD_MIN
	b.draw_pass_1 = _draw_mesh(sp, crowd)
	if crowd:
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.amount = count
	b.lifetime = LIFETIME
	b.one_shot = true
	b.explosiveness = 1.0
	b.randomness = 0.0
	b.fixed_fps = 0
	b.interpolate = false
	b.emitting = true
	return b


## Applies CollisionWorld.to_shader_params() (safe on a live batch: no reset).
func set_world_params(params: Dictionary) -> void:
	var pm := process_material as ShaderMaterial
	pm.set_shader_parameter("room_rects", PackedVector4Array(params["room_rects"]))
	pm.set_shader_parameter("room_rect_count", params["room_rect_count"])
	pm.set_shader_parameter("rect_cdf", rect_cdf(params))
	pm.set_shader_parameter("box_min", PackedVector3Array(params["box_min"]))
	pm.set_shader_parameter("box_max", PackedVector3Array(params["box_max"]))
	pm.set_shader_parameter("box_count", params["box_count"])
	pm.set_shader_parameter("ceiling", params["ceiling"])
	visibility_aabb = _room_aabb(params).grow(VISIBILITY_MARGIN)


## Area prefix sums of the room rects, normalised to 1, padded with 1 to MAX_RECTS.
static func rect_cdf(params: Dictionary) -> PackedFloat32Array:
	var rects: Array = params["room_rects"]
	var n: int = params["room_rect_count"]
	var cdf := PackedFloat32Array()
	cdf.resize(CollisionWorld.MAX_RECTS)
	cdf.fill(1.0)
	var total := 0.0
	for i in n:
		var r: Vector4 = rects[i]
		total += (r.z - r.x) * (r.w - r.y)
	var acc := 0.0
	for i in n:
		var r: Vector4 = rects[i]
		acc += (r.z - r.x) * (r.w - r.y)
		cdf[i] = acc / total if total > 0.0 else 1.0
	if n > 0:
		cdf[n - 1] = 1.0  # exact, despite float rounding
	return cdf


static func _room_aabb(params: Dictionary) -> AABB:
	var rects: Array = params["room_rects"]
	var box := AABB()
	for i in int(params["room_rect_count"]):
		var r: Vector4 = rects[i]
		var a := AABB(Vector3(r.x, 0.0, r.y), Vector3(r.z - r.x, float(params["ceiling"]), r.w - r.y))
		box = a if i == 0 else box.merge(a)
	return box


## The shared baked mesh (decimated for crowds); emissive species get glowing
## material copies so the shared resources are never modified.
static func _draw_mesh(sp: Dictionary, crowd: bool) -> Mesh:
	var mesh := load(sp["mesh_path"]) as Mesh
	if crowd:
		if not _crowd_meshes.has(sp["id"]):
			_crowd_meshes[sp["id"]] = _decimate(mesh as ArrayMesh)
		mesh = _crowd_meshes[sp["id"]]
	if not sp.get("emissive", false):
		return mesh
	var copy := mesh.duplicate() as ArrayMesh
	for i in copy.get_surface_count():
		var m := (copy.surface_get_material(i) as BaseMaterial3D).duplicate() as BaseMaterial3D
		m.emission_enabled = true
		m.emission = EMISSION_COLOR
		m.emission_energy_multiplier = EMISSION_ENERGY
		copy.surface_set_material(i, m)
	return copy


## Per surface, the coarsest meshoptimizer LOD that keeps >= 1/CROWD_DECIMATE_MAX of
## the triangles. Materials are shared with the source mesh.
static func _decimate(mesh: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	for i in mesh.get_surface_count():
		im.add_surface(mesh.surface_get_primitive_type(i), mesh.surface_get_arrays(i),
				[], {}, mesh.surface_get_material(i), mesh.surface_get_name(i))
	im.generate_lods(25.0, 60.0, [])
	var out := ArrayMesh.new()
	for i in im.get_surface_count():
		var arrays := im.get_surface_arrays(i)
		var full := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		for lod in im.get_surface_lod_count(i):
			var idx := im.get_surface_lod_indices(i, lod)
			if idx.size() * CROWD_DECIMATE_MAX >= full and idx.size() < (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size():
				arrays[Mesh.ARRAY_INDEX] = idx
		out.add_surface_from_arrays(im.get_surface_primitive_type(i), arrays)
		out.surface_set_material(i, im.get_surface_material(i))
		out.surface_set_name(i, im.get_surface_name(i))
	return out
