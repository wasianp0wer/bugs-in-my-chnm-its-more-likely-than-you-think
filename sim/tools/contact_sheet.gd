extends SceneTree
## Renders a labelled top-down grid of every species model so facing can be checked.
## Run WITHOUT --headless (needs a GPU):
##   godot --path sim -s res://tools/contact_sheet.gd -- raw      (source GLBs)
##   godot --path sim -s res://tools/contact_sheet.gd -- baked    (baked .res meshes)
## Optional second argument "side" renders from +X (+Z points to image left) instead of top-down.
## Writes PNGs to <repo>/build/contact/<mode>_<n>.png. The red arrow points along +Z
## and is the direction the head should face after baking.

const CELL := 300
const COLS := 5
const ROWS := 3

var _mode := "raw"
var _side := false
var _specs: Array[Dictionary] = []
var _page := 0
var _frames := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	_side = args.size() > 1 and args[1] == "side"
	_specs = SpeciesDB.load_all()
	root.size = Vector2i(CELL * COLS, CELL * ROWS)
	_build_page()


func _build_page() -> void:
	for c in root.get_children():
		c.queue_free()
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	root.add_child(grid)
	var start := _page * COLS * ROWS
	for i in range(start, mini(start + COLS * ROWS, _specs.size())):
		grid.add_child(_cell(_specs[i]))
	_frames = 0


func _cell(s: Dictionary) -> Control:
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(CELL, CELL)
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)

	var inst := _model(s)
	vp.add_child(inst)
	var box := _aabb(inst)
	var ctr := box.get_center()
	var ext := maxf(box.size.x, box.size.z)
	if _side:
		ext = maxf(ext, box.size.y)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.85, 0.87, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	vp.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, 30, 0)
	vp.add_child(light)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ext * 1.5
	cam.far = ext * 20.0 + 100.0
	vp.add_child(cam)
	var zdir := Vector3(0, 0, 1)  # direction the arrow points
	var a0 := Vector3(ctr.x, box.end.y + ext, ctr.z)
	if _side:
		cam.look_at_from_position(ctr + Vector3(box.size.x + ext * 5.0, 0, 0), ctr, Vector3.UP)
		a0 = Vector3(box.end.x + ext, box.end.y + ext * 0.1, ctr.z - ext * 0.3)
	else:
		cam.look_at_from_position(Vector3(ctr.x, box.end.y + ext * 5.0, ctr.z), Vector3(ctr.x, 0, ctr.z), Vector3(0, 0, 1))  # +Z points to image top

	# +Z arrow drawn over the model.
	var arrow := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var a1 := a0 + zdir * ext * 0.6
	var hw := ext * 0.08
	var wing := Vector3(-hw, 0, -hw) if not _side else Vector3(0, -hw, -hw)
	var wing2 := Vector3(hw, 0, -hw) if not _side else Vector3(0, hw, -hw)
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for p in [a0, a1, a1, a1 + wing, a1, a1 + wing2]:
		im.surface_add_vertex(p)
	im.surface_end()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0, 0)
	m.no_depth_test = true
	arrow.mesh = im
	arrow.material_override = m
	vp.add_child(arrow)

	var lbl := Label.new()
	lbl.text = "%s  +Z=%s" % [s["id"], "left" if _side else "up"]
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.add_theme_font_size_override("font_size", 18)
	svc.add_child(lbl)
	return svc


func _model(s: Dictionary) -> Node3D:
	var mi := MeshInstance3D.new()
	if _mode == "baked":
		mi.mesh = load(s["mesh_path"]) as Mesh
		return mi
	var scene := load("res://assets/animals/src/%s.glb" % s["id"]) as PackedScene
	var r := scene.instantiate() as Node3D
	mi.mesh = MeshMerge.merge_raw(r)
	r.free()
	return mi


func _aabb(node: Node) -> AABB:
	return (node as MeshInstance3D).mesh.get_aabb()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 8:
		var dir := ProjectSettings.globalize_path("res://").path_join("../build/contact")
		DirAccess.make_dir_recursive_absolute(dir)
		var img := root.get_texture().get_image()
		img.save_png("%s/%s%s_%d.png" % [dir, _mode, "_side" if _side else "", _page])
		_page += 1
		if _page * COLS * ROWS >= _specs.size():
			return true
		_build_page()
	return false
