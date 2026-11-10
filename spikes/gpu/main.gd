extends Node3D
## Spike driver. User args (after `--`):
##   --batches=N        batches spawned at startup (default 1)
##   --count=N          particles per batch (default 50000)
##   --add_at=S         add one more batch at time S (runtime-add test)
##   --grow_at=S        raise batch 0 `amount` by 10000 at time S (amount-change test)
##   --ratio_at=S       start batch 0 at amount_ratio 0.5, raise to 1.0 at time S
##   --param_at=S       set hop_speed=5 on batch 0 at time S (live uniform change test)
##   --hide_at=S        hide batch 0 at S, show again at S+2 (does hidden pause processing?)
##   --away_at=S        turn the camera away from the room at S, back at S+2 (does culling pause?)
##   --lifetime=S       particle lifetime (default 1e6)
##   --boxtest          box covers the whole floor up to y=1.5 (numeric box check)
##   --substeps=N       force N sub-steps per frame (perf test)
##   --fixed_fps=N      GPUParticles3D.fixed_fps (default 0 = every frame)
##   --novsync          disable vsync for FPS measurement
##   --close            camera low inside the room (fill-rate worst case)
##   --aabb             print batch AABBs read back from the GPU every second
##   --duration=S       quit after S seconds (default: none; use --quit-after)
##   --shot=NAME        screenshot file name (default shot.png), taken at 5 s
##   --shot_at=S        screenshot time (default 5)
##   --shot2_at=S       optional second screenshot (NAME with "_2" suffix), to compare motion

const ROOM := Vector3(10.0, 2.9, 10.0)
const LIFETIME_DEFAULT := 1.0e6
const COLORS := [Color(1, 0.55, 0.1), Color(0.2, 0.8, 1), Color(0.4, 1, 0.3), Color(1, 0.3, 0.8), Color(1, 1, 0.3), Color(0.7, 0.5, 1)]

var opts: Dictionary = {}
var batches: Array[GPUParticles3D] = []
var shader: Shader = preload("res://critter.gdshader")
var draw_mesh: BoxMesh
var elapsed := 0.0
var next_print := 1.0
var frames := 0
var shot_done := false
var shot2_done := false
var fps_samples: Array[float] = []
var add_done := false
var grow_done := false
var ratio_done := false
var param_done := false
var hide_state := 0
var away_state := 0
var cam: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if opts.has("novsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_build_room()
	draw_mesh = BoxMesh.new()
	draw_mesh.size = Vector3(0.5, 0.4, 1.0)  # 1 m long along +Z, scaled by body_length
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	draw_mesh.material = mat
	for i in int(opts.get("batches", "1")):
		_add_batch()
	print("renderer=", RenderingServer.get_current_rendering_method(), " adapter=", RenderingServer.get_video_adapter_name(),
		" batches=", batches.size(), " count=", _count(), " opts=", opts)


func _build_room() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.position = Vector3(1, 0.5, 9.5) if opts.has("close") else Vector3(5, 11, 17)
	add_child(cam)
	cam.look_at(Vector3(4, 0.2, 7) if opts.has("close") else Vector3(5, 0.5, 5))
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.75, 0.75, 0.7)
	_slab(Vector3(5, -0.05, 5), Vector3(10, 0.1, 10), wall_mat)
	_slab(Vector3(-0.05, 1.45, 5), Vector3(0.1, 2.9, 10), wall_mat)
	_slab(Vector3(10.05, 1.45, 5), Vector3(0.1, 2.9, 10), wall_mat)
	_slab(Vector3(5, 1.45, -0.05), Vector3(10, 2.9, 0.1), wall_mat)
	_slab(Vector3(5, 1.45, 10.05), Vector3(10, 2.9, 0.1), wall_mat)
	var bmin := _box_min()
	var bmax := _box_max()
	var box_mat := StandardMaterial3D.new()
	box_mat.albedo_color = Color(0.45, 0.3, 0.2)
	_slab((bmin + bmax) * 0.5, bmax - bmin, box_mat)


func _box_min() -> Vector3:
	return Vector3(0, 0, 0) if opts.has("boxtest") else Vector3(3, 0, 3)


func _box_max() -> Vector3:
	return Vector3(10, 1.5, 10) if opts.has("boxtest") else Vector3(6, 1.2, 6)


func _slab(center: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = center
	add_child(mi)


func _add_batch() -> GPUParticles3D:
	var pm := ShaderMaterial.new()
	pm.shader = shader
	var rects := PackedVector4Array()
	rects.resize(8)
	rects[0] = Vector4(0, 0, ROOM.x, ROOM.z)
	pm.set_shader_parameter("room_rects", rects)
	pm.set_shader_parameter("room_rect_count", 1)
	# Arrays may be shorter than declared (1 of 128); the shader reads only box_count entries.
	pm.set_shader_parameter("box_min", PackedVector3Array([_box_min()]))
	pm.set_shader_parameter("box_max", PackedVector3Array([_box_max()]))
	pm.set_shader_parameter("box_count", 1)
	pm.set_shader_parameter("ceiling", ROOM.y)
	pm.set_shader_parameter("force_substeps", int(opts.get("substeps", "0")))
	pm.set_shader_parameter("tint", COLORS[batches.size() % COLORS.size()])
	var p := GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = draw_mesh
	p.amount = int(opts.get("count", "50000"))
	p.lifetime = float(opts.get("lifetime", str(LIFETIME_DEFAULT)))
	p.one_shot = true
	p.explosiveness = 1.0
	p.fixed_fps = int(opts.get("fixed_fps", "0"))
	p.interpolate = false
	p.visibility_aabb = AABB(Vector3(-0.5, -0.5, -0.5), ROOM + Vector3.ONE)
	p.randomness = 0.0
	if opts.has("ratio_at") and batches.is_empty():
		p.amount_ratio = 0.5
	p.emitting = true
	add_child(p)
	batches.append(p)
	return p


func _count() -> int:
	var n := 0
	for b in batches:
		n += b.amount
	return n


func _process(delta: float) -> void:
	elapsed += delta
	frames += 1
	if opts.has("add_at") and not add_done and elapsed >= float(opts["add_at"]):
		add_done = true
		_add_batch()
		print("t=%.2f ADDED batch %d (count now %d)" % [elapsed, batches.size() - 1, _count()])
		_print_aabbs("right after add")
	if opts.has("grow_at") and not grow_done and elapsed >= float(opts["grow_at"]):
		grow_done = true
		_print_aabbs("before grow")
		batches[0].amount += 10000
		print("t=%.2f GREW batch 0 amount to %d" % [elapsed, batches[0].amount])
	if opts.has("ratio_at") and not ratio_done and elapsed >= float(opts["ratio_at"]):
		ratio_done = true
		_print_aabbs("before ratio")
		batches[0].amount_ratio = 1.0
		print("t=%.2f RAISED batch 0 amount_ratio to 1.0" % elapsed)
	if opts.has("param_at") and not param_done and elapsed >= float(opts["param_at"]):
		param_done = true
		(batches[0].process_material as ShaderMaterial).set_shader_parameter("hop_speed", 5.0)
		print("t=%.2f SET hop_speed=5 on batch 0" % elapsed)
	if opts.has("hide_at"):
		var h := float(opts["hide_at"])
		if hide_state == 0 and elapsed >= h:
			hide_state = 1
			batches[0].visible = false
			print("t=%.2f HID batch 0" % elapsed)
		elif hide_state == 1 and elapsed >= h + 2.0:
			hide_state = 2
			batches[0].visible = true
			print("t=%.2f SHOWED batch 0" % elapsed)
	if opts.has("away_at"):
		var w := float(opts["away_at"])
		if away_state == 0 and elapsed >= w:
			away_state = 1
			cam.look_at(cam.position + Vector3(0, 0, 1))
			print("t=%.2f CAMERA AWAY" % elapsed)
		elif away_state == 1 and elapsed >= w + 2.0:
			away_state = 2
			cam.look_at(Vector3(5, 0.5, 5))
			print("t=%.2f CAMERA BACK" % elapsed)
	if elapsed >= next_print:
		next_print += 1.0
		var vp := get_viewport().get_viewport_rid()
		var fps := Engine.get_frames_per_second()
		if elapsed > 2.0:
			fps_samples.append(fps)
		print("t=%.0f fps=%.0f gpu_ms=%.2f cpu_ms=%.2f batches=%d particles=%d emitting0=%s" % [
			elapsed, fps, RenderingServer.viewport_get_measured_render_time_gpu(vp),
			RenderingServer.viewport_get_measured_render_time_cpu(vp), batches.size(), _count(),
			batches.size() > 0 and batches[0].emitting])
		if opts.has("aabb"):
			_print_aabbs("tick")
	if not shot_done and (elapsed >= float(opts.get("shot_at", "5")) or frames >= 590 and not opts.has("duration")):
		shot_done = true
		_save_shot(str(opts.get("shot", "shot.png")))
	if opts.has("shot2_at") and not shot2_done and elapsed >= float(opts["shot2_at"]):
		shot2_done = true
		_save_shot(str(opts.get("shot", "shot.png")).replace(".png", "_2.png"))
	if opts.has("duration") and elapsed >= float(opts["duration"]):
		var avg := 0.0
		for f in fps_samples:
			avg += f
		print("AVG fps (t>2s) = %.1f over %d samples" % [avg / maxf(1, fps_samples.size()), fps_samples.size()])
		get_tree().quit()


func _save_shot(file_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://" + file_name)
	img.save_png(path)
	print("t=%.2f saved %s" % [elapsed, path])


func _print_aabbs(label: String) -> void:
	for i in batches.size():
		var a := RenderingServer.particles_get_current_aabb(batches[i].get_base())
		print("  [%s] batch %d aabb pos=%s end=%s" % [label, i, a.position, a.end])
