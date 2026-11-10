extends GutTest

func test_contains_points() -> void:
	for p in [Vector2(1, 8), Vector2(5, 1), Vector2(20, 5), Vector2(30, 14)]:
		assert_true(RoomGeometry.contains_xz(p), "inside %s" % p)
	for p in [Vector2(1, 1), Vector2(20, 13), Vector2(32, 5), Vector2(15, 12), Vector2(-0.1, 8)]:
		assert_false(RoomGeometry.contains_xz(p), "outside %s" % p)

func test_area() -> void:
	assert_almost_eq(RoomGeometry.area(), 294.0, 1.0)
	var pts := RoomData.OUTLINE
	var s := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		s += a.x * b.y - b.x * a.y
	assert_almost_eq(absf(s) / 2.0, RoomGeometry.area(), 0.01)

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
	assert_eq(ext, [2, 5] as Array[int])
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

func test_columns_inside() -> void:
	var h := RoomData.COLUMN_SIZE / 2.0
	for c in RoomData.COLUMNS:
		for dx in [-h, h]:
			for dz in [-h, h]:
				assert_true(RoomGeometry.contains_xz(c + Vector2(dx, dz)))
	var boxes := RoomGeometry.column_boxes()
	assert_eq(boxes.size(), RoomData.COLUMNS.size())
	assert_eq(boxes[0].size, Vector3(0.6, 2.9, 0.6))

func test_spawn_covers_all_rects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var obs: Array[AABB] = [AABB(Vector3(4, 0, 1), Vector3(2, 1, 2))]
	var counts: Array[int] = [0, 0, 0, 0]
	var n := 20000
	for i in n:
		var p := RoomGeometry.random_spawn_xz(rng, obs)
		assert_true(RoomGeometry.contains_xz(p))
		assert_false(Rect2(4, 1, 2, 2).has_point(p))
		for r in RoomData.RECTS.size():
			if RoomData.RECTS[r].has_point(p):
				counts[r] += 1
				break
	for r in RoomData.RECTS.size():
		var frac := RoomData.RECTS[r].get_area() / RoomGeometry.area()
		assert_almost_eq(float(counts[r]) / n, frac, 0.03, "rect %d" % r)

func test_walls_facing_camera() -> void:
	var f := RoomGeometry.walls_facing_camera(Vector3(15, 10, -20))
	assert_true(f.has(2))
	assert_false(f.has(8))
	assert_false(f.has(9))
