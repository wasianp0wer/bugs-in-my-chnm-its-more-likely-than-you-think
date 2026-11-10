extends SceneTree
## Windowed visual and numeric check of the GPU swarms (needs a GPU; NOT --headless):
##   godot --path sim -s res://tools/swarm_check.gd 2>&1 | tee build/swarm_check.log
##   ! grep -q "SHADER ERROR" build/swarm_check.log
## Adds 50k fleas + 2k wasps + 3 deer to the bare room plus test boxes (a desk,
## a thin slab, a cabinet) and runs DURATION s. Prints the average FPS (t > 2 s) and saves
## <repo>/build/swarm_check.png (overview) and swarm_check_close.png (near the desk).
## Numeric check: PROBES single-particle batches per probe species, whose GPU read-back
## AABB (particles_get_current_aabb) is one particle's position grown by the mesh's
## longest axis, are checked once per second against the room and the boxes, both kept
## the species' clearance away (MotionRules.clearance, 0.9 m for a deer), and the
## big batches' AABBs against the room bounds. Exits 1 and prints FAIL on any violation.
## Pass `-- noprobes` to measure FPS without the 200 read-back probe batches.

const DURATION := 10.0
const PROBES := 40
const PROBE_SPECIES := ["flea", "wasp", "frog", "bee", "deer"]
const EPS := 1e-3
const TEST_BOXES: Array[AABB] = [
	AABB(Vector3(15.0, 0.0, 5.0), Vector3(1.5, 0.75, 0.75)),   # desk
	AABB(Vector3(5.0, 1.2, 2.0), Vector3(3.0, 0.03, 3.0)),     # thin slab (shelf)
	AABB(Vector3(24.0, 0.0, 12.0), Vector3(2.0, 1.8, 0.6)),    # cabinet
]

var _world: CollisionWorld
var _swarms: SwarmManager
var _probes: Array[SwarmBatch] = []
var _clearance := {}  # species id -> MotionRules.clearance
var _cam: Camera3D
var _elapsed := 0.0
var _next_tick := 1.0
var _fps: Array[float] = []
var _probe_checks := 0
var _over_test_box := 0  # probe samples above or below a desk/slab/cabinet footprint
var _violations: Array[String] = []
var _min_y := INF
var _max_y := -INF
var _shot := false


func _init() -> void:
	var boxes: Array[AABB] = []
	boxes.append_array(TEST_BOXES)
	_world = CollisionWorld.new(RoomData.RECTS, boxes, RoomData.CEILING)

	var scene := Node3D.new()
	root.add_child(scene)
	scene.add_child(RoomBuilder.build())
	var box_mat := StandardMaterial3D.new()
	box_mat.albedo_color = Color("8a6a4a")
	for b in TEST_BOXES:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b.size
		mi.mesh = bm
		mi.material_override = box_mat
		mi.position = b.get_center()
		scene.add_child(mi)
	_cam = Camera3D.new()
	scene.add_child(_cam)
	_cam.look_at_from_position(Vector3(15.75, 24.0, 30.0), Vector3(15.75, 0.0, 7.4))

	var shader_uniforms := SwarmBatch.SHADER.get_shader_uniform_list()
	if shader_uniforms.is_empty():
		_violations.append("shader has no uniforms (compile failure)")

	_swarms = SwarmManager.new()
	scene.add_child(_swarms)
	_swarms.configure(_world)
	_swarms.add(SpeciesDB.get_species("flea"), 50_000)
	_swarms.add(SpeciesDB.get_species("wasp"), 2_000)
	_swarms.add(SpeciesDB.get_species("deer"), 3)

	if not "noprobes" in OS.get_cmdline_user_args():
		var params := _world.to_shader_params()
		for id in PROBE_SPECIES:
			var sp := SpeciesDB.get_species(id)
			_clearance[id] = MotionRules.clearance(sp)
			for i in PROBES:
				var b := SwarmBatch.create(sp, 1, params, 1000 + _probes.size())
				scene.add_child(b)
				_probes.append(b)
	print("swarm_check: renderer=%s adapter=%s boxes=%d probes=%d" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(),
		boxes.size(), _probes.size()])


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed < _next_tick:
		return false
	_next_tick += 1.0
	var fps := Engine.get_frames_per_second()
	if _elapsed > 2.0:
		_fps.append(fps)
	_check_probes()
	_check_batches()
	print("t=%.0f fps=%.0f batches=%d counts=%s probe_checks=%d violations=%d" % [
		_elapsed, fps, _swarms.batch_count(), _swarms.count_by_species(), _probe_checks, _violations.size()])
	if _elapsed >= DURATION and not _shot:
		_shot = true
		_save("swarm_check.png")
		_cam.look_at_from_position(Vector3(13.0, 1.6, 7.5), Vector3(15.75, 0.4, 5.4))
		return false
	if _shot:
		_save("swarm_check_close.png")
		_finish()
		return true
	return false


func _particle_pos(b: SwarmBatch) -> Vector3:
	# The read-back AABB is the particle origins' AABB grown on every side by the
	# draw mesh's longest axis, so its centre is the particle's position.
	return RenderingServer.particles_get_current_aabb(b.get_base()).get_center()


func _check_probes() -> void:
	for b in _probes:
		var p := _particle_pos(b)
		_probe_checks += 1
		_min_y = minf(_min_y, p.y)
		_max_y = maxf(_max_y, p.y)
		# Clearance (half the body length; 0.9 m for a deer): the footprint p.xz +- c stays
		# in the room and the centre stays out of every box grown by c in x/z.
		var c: float = _clearance[b.species_id]
		var cw := maxf(c - EPS, 0.0)
		var outside := p.y < -EPS or p.y > _world.ceiling + EPS
		for dx in [-cw, cw]:
			for dz in [-cw, cw]:
				outside = outside or not _world.inside_room_xz(Vector2(p.x + dx, p.z + dz))
		var inside_box := -1
		for i in _world.boxes.size():
			var bx := _world.boxes[i]
			var grown := AABB(bx.position - Vector3(c, 0.0, c), bx.size + Vector3(2.0 * c, 0.0, 2.0 * c))
			if grown.grow(-EPS).has_point(p):
				inside_box = i
		for t in TEST_BOXES:
			if p.x >= t.position.x and p.x <= t.end.x and p.z >= t.position.z and p.z <= t.end.z:
				_over_test_box += 1
		if outside or inside_box >= 0:
			_violations.append("t=%.1f %s probe at %s %s" % [_elapsed, b.species_id, p,
				"outside room (clearance %.3f)" % c if outside else "within %.3f of box %d" % [c, inside_box]])


func _check_batches() -> void:
	var rb := RoomGeometry.bounds()
	var room := AABB(Vector3(rb.position.x, 0.0, rb.position.y), Vector3(rb.size.x, RoomData.CEILING, rb.size.y)).grow(EPS)
	for c in _swarms.get_children():
		var b := c as SwarmBatch
		var a := RenderingServer.particles_get_current_aabb(b.get_base())
		var mesh_grow := b.draw_pass_1.get_aabb().get_longest_axis_size()
		var origins := a.grow(-mesh_grow)
		if not room.encloses(origins):
			_violations.append("t=%.1f %s batch AABB %s leaves room" % [_elapsed, b.species_id, origins])


func _save(file_name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../build")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file_name).simplify_path()
	root.get_texture().get_image().save_png(path)
	print("swarm_check: saved %s" % path)


func _finish() -> void:
	var avg := 0.0
	for f in _fps:
		avg += f
	avg /= maxf(1.0, _fps.size())
	print("swarm_check: AVG fps (t>2s) = %.1f over %d samples" % [avg, _fps.size()])
	print("swarm_check: probe position checks = %d (%d over a test-box footprint), probe y range = [%.4f, %.4f], violations = %d" % [
		_probe_checks, _over_test_box, _min_y, _max_y, _violations.size()])
	for v in _violations.slice(0, 20):
		print("  VIOLATION ", v)
	var ok := _violations.is_empty() and avg >= 60.0
	print("swarm_check: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
