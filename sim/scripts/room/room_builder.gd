class_name RoomBuilder

const THICK := 0.15
const STUB_H := 0.5
const SILL := 0.75
const WIN_H := 1.6
const BANK_PAIRS := 4
const BANK_PAIR_W := 1.5
## Plain windows on the non-bank exterior edges, centred at these fractions of the edge.
const PLAIN_WINDOW_FRACTIONS := [0.25, 0.75]
const DOOR_W := 1.0
const DOOR_H := 2.1

const C_CARPET := Color("c8a96a")
const C_WALL := Color("efece4")
const C_DOOR := Color("c9a46b")

static var _mats: Dictionary = {}

static func _mat(key: String, color: Color, emissive := false) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	_mats[key] = m
	return m

static func _box(parent: Node3D, nm: String, lo: Vector3, hi: Vector3, mat: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = hi - lo
	mi.mesh = bm
	mi.position = (lo + hi) * 0.5
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Room"
	root.add_child(_build_floor())
	for w in RoomGeometry.walls():
		root.add_child(_build_wall(w))
	var boxes := RoomGeometry.column_boxes()
	for i in boxes.size():
		var mi := MeshInstance3D.new()
		mi.name = "Column_%d" % i
		var bm := BoxMesh.new()
		bm.size = boxes[i].size
		mi.mesh = bm
		mi.position = boxes[i].get_center()
		mi.material_override = _mat("column", C_WALL)
		root.add_child(mi)
	_add_lighting(root)
	return root

static func _build_floor() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for r in RoomData.RECTS:
		var p0 := Vector3(r.position.x, 0, r.position.y)
		var p1 := Vector3(r.end.x, 0, r.position.y)
		var p2 := Vector3(r.end.x, 0, r.end.y)
		var p3 := Vector3(r.position.x, 0, r.end.y)
		for p in [p0, p1, p2, p0, p2, p3]:
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	mi.mesh = st.commit()
	mi.material_override = _mat("carpet", C_CARPET)
	return mi

static func _build_wall(w: Dictionary) -> Node3D:
	var a: Vector2 = w.a
	var b: Vector2 = w.b
	var n: Vector2 = w.normal
	var idx: int = w.index
	var count := RoomData.OUTLINE.size()
	var mid := (a + b) * 0.5
	var ex := Vector3(n.y, 0, -n.x)       # local +X in world
	var ex2 := Vector2(ex.x, ex.z)
	var node := Node3D.new()
	node.name = "Wall_%d" % idx
	node.transform = Transform3D(Basis(ex, Vector3.UP, Vector3(n.x, 0, n.y)), Vector3(mid.x, 0, mid.y))

	# Extend at convex corners only (reflex corners are covered by the neighbour).
	var prev: Vector2 = RoomData.OUTLINE[idx] - RoomData.OUTLINE[(idx + count - 1) % count]
	var next: Vector2 = RoomData.OUTLINE[(idx + 2) % count] - RoomData.OUTLINE[(idx + 1) % count]
	var ext_a := THICK if n.dot(prev) > 0.0 else 0.0
	var ext_b := THICK if n.dot(next) < 0.0 else 0.0
	var ua := (a - mid).dot(ex2)
	var ub := (b - mid).dot(ex2)
	var lo := minf(ua, ub)
	var hi := maxf(ua, ub)
	if ua < ub:
		lo -= ext_a
		hi += ext_b
	else:
		lo -= ext_b
		hi += ext_a

	var full := Node3D.new()
	full.name = "Full"
	node.add_child(full)
	var stub := Node3D.new()
	stub.name = "Stub"
	stub.visible = false
	node.add_child(stub)
	var wall_mat := _mat("wall", C_WALL)

	_box(stub, "Slab", Vector3(lo, 0, 0), Vector3(hi, STUB_H, THICK), wall_mat)
	# stubs/solids sit outside the outline: local z in [0, THICK] is outward.
	var openings: Array = []
	if idx == RoomData.WINDOW_BANK_EDGE:
		openings = _bank_openings(a, b, mid, ex2)
	elif idx in RoomData.EXTERIOR_EDGES:
		openings = _plain_openings(a, b, mid, ex2)
	_solid_with_openings(full, lo, hi, openings, wall_mat)
	for i in openings.size():
		_add_pane(full, i, openings[i], idx == RoomData.WINDOW_BANK_EDGE)
	for d in RoomData.DOORS:
		if d.edge == idx:
			var c := Vector2(d.center, mid.y) if absf(n.y) > 0.5 else Vector2(mid.x, d.center)
			_add_door(full, idx, (c - mid).dot(ex2))
	return node

# Opening: {u0, u1, y0, y1}. Openings are laid out along the wall edge a -> b.
static func _opening(mid: Vector2, ex2: Vector2, p0: Vector2, p1: Vector2, y0: float, y1: float) -> Dictionary:
	var ua := (p0 - mid).dot(ex2)
	var ub := (p1 - mid).dot(ex2)
	return {"u0": minf(ua, ub), "u1": maxf(ua, ub), "y0": y0, "y1": y1}

## BANK_PAIRS evenly spaced pairs of panes along the whole edge a -> b.
static func _bank_openings(a: Vector2, b: Vector2, mid: Vector2, ex2: Vector2) -> Array:
	var out: Array = []
	var dir := (b - a).normalized()
	var pitch := a.distance_to(b) / BANK_PAIRS
	var pane_w := (BANK_PAIR_W - 0.06) * 0.5
	for p in BANK_PAIRS:
		var c := pitch * (p + 0.5)
		for s in 2:
			var w0 := c - BANK_PAIR_W * 0.5 + s * (pane_w + 0.06)
			out.append(_opening(mid, ex2, a + dir * w0, a + dir * (w0 + pane_w), SILL, SILL + WIN_H))
	return out

## One 1.5 m window centred at each PLAIN_WINDOW_FRACTIONS of the edge a -> b.
static func _plain_openings(a: Vector2, b: Vector2, mid: Vector2, ex2: Vector2) -> Array:
	var out: Array = []
	var dir := (b - a).normalized()
	for f in PLAIN_WINDOW_FRACTIONS:
		var c := a.lerp(b, f)
		out.append(_opening(mid, ex2, c - dir * 0.75, c + dir * 0.75, 0.9, 2.3))
	return out

static func _solid_with_openings(parent: Node3D, lo: float, hi: float, openings: Array, mat: Material) -> void:
	var ops := openings.duplicate()
	ops.sort_custom(func(p, q): return p.u0 < q.u0)
	var cur := lo
	var k := 0
	for o in ops:
		if o.u0 > cur + 0.001:
			_box(parent, "Seg_%d" % k, Vector3(cur, 0, 0), Vector3(o.u0, RoomData.CEILING, THICK), mat)
			k += 1
		_box(parent, "Sill_%d" % k, Vector3(o.u0, 0, 0), Vector3(o.u1, o.y0, THICK), mat)
		_box(parent, "Head_%d" % k, Vector3(o.u0, o.y1, 0), Vector3(o.u1, RoomData.CEILING, THICK), mat)
		k += 1
		cur = maxf(cur, o.u1)
	if hi > cur + 0.001:
		_box(parent, "Seg_%d" % k, Vector3(cur, 0, 0), Vector3(hi, RoomData.CEILING, THICK), mat)

static func _add_pane(parent: Node3D, i: int, o: Dictionary, blinds: bool) -> void:
	var glow := _mat("pane", Color("a9d8f5"), true)
	_box(parent, "Pane_%d" % i, Vector3(o.u0, o.y0, THICK * 0.5 - 0.01), Vector3(o.u1, o.y1, THICK * 0.5 + 0.01), glow, false)
	if blinds:
		var white := _mat("blind", Color("f6f6f2"))
		var slats := 10
		var h: float = o.y1 - o.y0
		for s in slats:
			var y: float = o.y0 + h * (s + 0.5) / slats
			_box(parent, "Slat_%d_%d" % [i, s], Vector3(o.u0, y - 0.012, -0.02), Vector3(o.u1, y + 0.012, 0.0), white, false)

static func _add_door(parent: Node3D, idx: int, u: float) -> void:
	var door := _box(parent, "Door_%d" % idx, Vector3(u - DOOR_W * 0.5, 0, -0.05), Vector3(u + DOOR_W * 0.5, DOOR_H, 0.0), _mat("door", C_DOOR))
	var slot := _box(door, "Slot", Vector3(-0.05, -0.3, -0.027), Vector3(0.05, 0.3, -0.023), _mat("slot", Color("2a2a2e")), false)
	slot.position.y += 0.45

static func _add_lighting(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-135, 0, 0)   # travels south (+z) and down, in through the north bank
	sun.light_energy = 1.2
	sun.light_color = Color("fffaf2")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	root.add_child(sun)
	var spots := [Vector2(6, 5), Vector2(11, 8), Vector2(17, 6), Vector2(23, 7), Vector2(29, 7), Vector2(26, 13), Vector2(8, 8.3)]
	for i in spots.size():
		var o := OmniLight3D.new()
		o.name = "Troffer_%d" % i
		o.position = Vector3(spots[i].x, 2.6, spots[i].y)
		o.omni_range = 13.0
		o.light_energy = 0.45
		o.light_color = Color("f7f9ff")
		o.shadow_enabled = false
		root.add_child(o)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("d9dde3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f2f4f7")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.35
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	# Additive so emitters (fireflies, panes) still bloom against the bright daylight
	# room; screen blend barely shows on light walls. Small levels suit tiny emitters.
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.6)
	env.glow_hdr_scale = 4.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
