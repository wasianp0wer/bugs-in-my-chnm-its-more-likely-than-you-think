extends GutTest

func test_contains_points() -> void:
	for p in [Vector2(1, 8), Vector2(5, 1), Vector2(20, 5), Vector2(30, 14), Vector2(20, 1), Vector2(30, 0.5)]:
		assert_true(RoomGeometry.contains_xz(p), "inside %s" % p)
	for p in [Vector2(1, 1), Vector2(20, 13), Vector2(32, 5), Vector2(15, 12), Vector2(-0.1, 8)]:
		assert_false(RoomGeometry.contains_xz(p), "outside %s" % p)

func test_area() -> void:
	assert_almost_eq(RoomGeometry.area(), 365.9, 1.0)
	var pts := RoomData.OUTLINE
	var s := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		s += a.x * b.y - b.x * a.y
	assert_almost_eq(absf(s) / 2.0, RoomGeometry.area(), 0.01)

## The user's request: the back wall is one straight wall, no alcove.
func test_back_wall_is_flat() -> void:
	var on_z0: Array[Dictionary] = []
	for w in RoomGeometry.walls():
		if is_equal_approx(w.a.y, 0.0) and is_equal_approx(w.b.y, 0.0):
			on_z0.append(w)
	assert_eq(on_z0.size(), 1, "walls on z = 0")
	if on_z0.size() == 1:
		var w: Dictionary = on_z0[0]
		assert_almost_eq(minf(w.a.x, w.b.x), 2.9, 0.001)
		assert_almost_eq(maxf(w.a.x, w.b.x), 31.5, 0.001)
		assert_eq(w.index, RoomData.MURAL_EDGE)

func test_doors_on_named_edges() -> void:
	assert_eq(RoomData.DOORS, [{"edge": 6, "center": 16.5}, {"edge": 7, "center": 8.3}])

func test_bounds() -> void:
	assert_true(RoomGeometry.bounds().is_equal_approx(Rect2(0, 0, 31.5, 14.8)))

func test_walls_outward_normals() -> void:
	var ws := RoomGeometry.walls()
	assert_eq(ws.size(), RoomData.OUTLINE.size())
	for w in ws:
		var mid: Vector2 = (w.a + w.b) * 0.5
		var n: Vector2 = w.normal
		assert_almost_eq(n.length(), 1.0, 0.0001)
		assert_false(RoomGeometry.contains_xz(mid + n * 0.05), "out wall %d" % w.index)
		assert_true(RoomGeometry.contains_xz(mid - n * 0.05), "in wall %d" % w.index)

func test_exterior_flags() -> void:
	var ext: Array[int] = []
	for w in RoomGeometry.walls():
		if w.exterior:
			ext.append(w.index)
	assert_eq(ext, [2, 3] as Array[int])
	var w2: Dictionary = RoomGeometry.walls()[2]
	assert_eq(w2.a.y, 0.0)
	assert_eq(w2.b.y, 0.0)

func test_doors_on_edges() -> void:
	var o := RoomData.OUTLINE
	for d in RoomData.DOORS:
		var a := o[d.edge]
		var b := o[(d.edge + 1) % o.size()]
		var horizontal := is_equal_approx(a.y, b.y)
		var along: float = a.x if horizontal else a.y
		var along_b: float = b.x if horizontal else b.y
		var lo := minf(along, along_b)
		var hi := maxf(along, along_b)
		assert_true(d.center - lo >= 0.6 and hi - d.center >= 0.6, "door edge %d" % d.edge)

func test_spawn_covers_all_rects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var obs: Array[AABB] = [AABB(Vector3(4, 0, 1), Vector3(2, 1, 2))]
	var counts: Array[int] = [0, 0, 0, 0]
	var n := 20000
	for i in n:
		var p := RoomGeometry.random_spawn_xz(rng, obs)
		assert_true(RoomGeometry.contains_xz(p))
		for r in RoomData.RECTS.size():
			if RoomData.RECTS[r].has_point(p):
				counts[r] += 1
				break
	for r in RoomData.RECTS.size():
		var frac := RoomData.RECTS[r].get_area() / RoomGeometry.area()
		assert_almost_eq(float(counts[r]) / n, frac, 0.03, "rect %d" % r)

## Spawns rain from SPAWN_Y: allowed above a low box (desk), never inside a tall one.
func test_spawn_rejects_only_points_inside_boxes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var desk := AABB(Vector3(4, 0, 1), Vector3(2, 0.75, 2))
	var pillar := AABB(Vector3(8, 0, 4), Vector3(2, RoomData.CEILING, 2))  # synthetic full-height obstacle
	var obs: Array[AABB] = [desk, pillar]
	var above_desk := 0
	var n := 20000
	for i in n:
		var p := RoomGeometry.random_spawn_xz(rng, obs)
		var q := Vector3(p.x, RoomGeometry.SPAWN_Y, p.y)
		for b in obs:
			assert_false(_in_box(b, q), "spawn %s inside %s" % [q, b])
		if Rect2(4, 1, 2, 2).has_point(p):
			above_desk += 1
	var expect := 4.0 / RoomGeometry.area() * n
	assert_gt(above_desk, int(expect * 0.5), "spawns above the desk footprint (expect ~%d)" % int(expect))

## With clearance c the whole square p.xz +- c is in the room and the 3D spawn point is
## outside every box grown by c in x/z.
func test_spawn_keeps_clearance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var c := 0.9
	var pillar := AABB(Vector3(8, 0, 4), Vector3(0.6, RoomData.CEILING, 0.6))  # synthetic full-height obstacle
	var obs: Array[AABB] = [pillar]
	var grown := AABB(pillar.position - Vector3(c, 0, c), pillar.size + Vector3(2 * c, 0, 2 * c))
	var counts: Array[int] = [0, 0, 0, 0]
	for i in 5000:
		var p := RoomGeometry.random_spawn_xz(rng, obs, c)
		for dx in [-c, c]:
			for dz in [-c, c]:
				assert_true(RoomGeometry.contains_xz(p + Vector2(dx, dz)), "corner of %s outside" % p)
		assert_false(_in_box(grown, Vector3(p.x, RoomGeometry.SPAWN_Y, p.y)), "spawn %s near pillar" % p)
		for r in RoomData.RECTS.size():
			if RoomData.RECTS[r].has_point(p):
				counts[r] += 1
				break
	for r in counts.size():
		assert_gt(counts[r], 0, "rect %d still reachable" % r)

func _in_box(b: AABB, q: Vector3) -> bool:
	return q.x >= b.position.x and q.x <= b.end.x and q.y >= b.position.y and q.y <= b.end.y \
			and q.z >= b.position.z and q.z <= b.end.z

func test_walls_facing_camera() -> void:
	var f := RoomGeometry.walls_facing_camera(Vector3(15, 10, -20))
	assert_true(f.has(2))
	assert_false(f.has(6))
	assert_false(f.has(7))
