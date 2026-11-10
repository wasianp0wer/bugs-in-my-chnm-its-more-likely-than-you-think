extends GutTest

var room: Node3D

func before_each() -> void:
	room = RoomBuilder.build()
	add_child_autofree(room)

func _aabb_of(m: MeshInstance3D) -> AABB:
	return m.global_transform * m.mesh.get_aabb()

func _meshes(n: Node, out: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)
	return out

func test_has_wall_per_edge() -> void:
	for i in RoomData.OUTLINE.size():
		var w := room.get_node_or_null("Wall_%d" % i)
		assert_not_null(w, "Wall_%d" % i)
		if w:
			assert_not_null(w.get_node_or_null("Full"))
			assert_not_null(w.get_node_or_null("Stub"))
	assert_not_null(room.get_node_or_null("Floor"))

func test_wall_heights() -> void:
	for i in RoomData.OUTLINE.size():
		var top_full := -INF
		for m in _meshes(room.get_node("Wall_%d/Full" % i)):
			top_full = maxf(top_full, _aabb_of(m).end.y)
		assert_almost_eq(top_full, 2.9, 0.001, "full %d" % i)
		var top_stub := -INF
		for m in _meshes(room.get_node("Wall_%d/Stub" % i)):
			top_stub = maxf(top_stub, _aabb_of(m).end.y)
		assert_almost_eq(top_stub, 0.5, 0.001, "stub %d" % i)

func test_wall_inner_face_on_outline() -> void:
	# wall 2 runs along z = 0; box occupies z in [-0.15, 0]
	var min_z := INF
	var max_z := -INF
	for m in _meshes(room.get_node("Wall_2/Stub")):
		var bb := _aabb_of(m)
		min_z = minf(min_z, bb.position.z)
		max_z = maxf(max_z, bb.end.z)
	assert_almost_eq(min_z, -0.15, 0.001)
	assert_almost_eq(max_z, 0.0, 0.001)

func test_window_count_on_bank() -> void:
	var n := 0
	for m in _meshes(room.get_node("Wall_2/Full")):
		if String(m.name).begins_with("Pane"):
			n += 1
	assert_eq(n, 8)
	var n5 := 0
	for m in _meshes(room.get_node("Wall_5/Full")):
		if String(m.name).begins_with("Pane"):
			n5 += 1
	assert_eq(n5, 2)

func test_doors_present() -> void:
	for d in RoomData.DOORS:
		assert_not_null(room.get_node_or_null("Wall_%d/Full/Door_%d" % [d.edge, d.edge]))

func test_columns_present() -> void:
	for i in RoomData.COLUMNS.size():
		assert_not_null(room.get_node_or_null("Column_%d" % i))

func test_lights_and_environment() -> void:
	assert_true(room.get_node("Sun") is DirectionalLight3D)
	var omnis := 0
	for c in room.get_children():
		if c is OmniLight3D:
			omnis += 1
	assert_gt(omnis, 2)
	var env: Environment = (room.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_true(env.glow_enabled)
	assert_almost_eq(env.glow_intensity, 0.6, 0.0001)
	assert_almost_eq(env.glow_hdr_threshold, 1.0, 0.0001)

func test_cutaway_toggles() -> void:
	Cutaway.apply(room, PackedInt32Array([2, 5]))
	for i in RoomData.OUTLINE.size():
		var f := i == 2 or i == 5
		assert_eq((room.get_node("Wall_%d/Full" % i) as Node3D).visible, not f, "full %d" % i)
		assert_eq((room.get_node("Wall_%d/Stub" % i) as Node3D).visible, f, "stub %d" % i)

func test_no_ceiling_mesh() -> void:
	for m in _meshes(room):
		assert_lte(_aabb_of(m).end.y, 2.95, m.name)

func _pane_centres(edge: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for m in _meshes(room.get_node("Wall_%d/Full" % edge)):
		if String(m.name).begins_with("Pane"):
			var c := _aabb_of(m).get_center()
			out.append(Vector2(c.x, c.z))
	return out

## Window placement is derived from RoomData: plain windows sit at 1/4 and 3/4 of every
## exterior edge other than the bank; the bank's panes lie within its edge's endpoints.
func test_windows_derived_from_room_data() -> void:
	var n := RoomData.OUTLINE.size()
	for e in RoomData.EXTERIOR_EDGES:
		var a: Vector2 = RoomData.OUTLINE[e]
		var b: Vector2 = RoomData.OUTLINE[(e + 1) % n]
		var centres := _pane_centres(e)
		if e == RoomData.WINDOW_BANK_EDGE:
			assert_eq(centres.size(), 2 * RoomBuilder.BANK_PAIRS)
			for c in centres:
				var t := (c - a).dot(b - a) / (b - a).length_squared()
				assert_between(t, 0.0, 1.0, "bank pane %s on edge %d" % [c, e])
		else:
			assert_eq(centres.size(), RoomBuilder.PLAIN_WINDOW_FRACTIONS.size(), "edge %d" % e)
			var ts: Array[float] = []
			for c in centres:
				ts.append((c - a).dot(b - a) / (b - a).length_squared())
			ts.sort()
			for i in ts.size():
				assert_almost_eq(ts[i], float(RoomBuilder.PLAIN_WINDOW_FRACTIONS[i]), 0.001, "edge %d pane %d" % [e, i])
	for e in n:
		if not e in RoomData.EXTERIOR_EDGES:
			assert_eq(_pane_centres(e).size(), 0, "interior edge %d has no windows" % e)
