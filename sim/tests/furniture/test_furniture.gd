extends GutTest

const TYPES := ["sofa", "tub_chair", "sling_chair", "coffee_table", "credenza", "owl_lamp",
	"wardrobe", "tv_stand", "whiteboard", "av_cart", "desk", "group_table", "task_chair",
	"stack_chair", "bookcase", "plant", "kitchenette", "conference_table"]
const CHAIRS := ["task_chair", "stack_chair"]
const TABLES := ["desk", "group_table", "conference_table"]
const EPS := 0.001

func _footprint(b: AABB) -> Rect2:
	return Rect2(b.position.x, b.position.z, b.size.x, b.size.z)

func _overlap(a: Rect2, b: Rect2) -> bool:
	# Strict overlap: sharing an edge is fine.
	return a.grow(-EPS).intersects(b.grow(-EPS))

func _item_rects(item: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b in FurnitureFactory.collision_boxes(item):
		out.append(_footprint(b))
	return out

func test_every_type_buildable() -> void:
	for t in TYPES:
		for rot in [0, 90, 180, 270]:
			var item := {"type": t, "pos": [5.0, 5.0], "rot": rot, "size": [1.0, 0.6, 0.9]}
			var node := FurnitureFactory.build(item)
			assert_not_null(node, "build %s" % t)
			assert_true(node.find_children("*", "MeshInstance3D", true, false).size() >= 1, "meshes %s" % t)
			var boxes := FurnitureFactory.collision_boxes(item)
			assert_true(boxes.size() >= 1, "boxes %s" % t)
			node.free()
	var all := FurnitureFactory.build_all()
	assert_eq(all.get_child_count(), FurnitureFactory.load_layout().size())
	all.free()

func test_collision_box_matches_rotation() -> void:
	var item := {"type": "desk", "pos": [10.0, 4.0], "rot": 90, "size": [1.5, 0.75, 0.75]}
	var b: AABB = FurnitureFactory.collision_boxes(item)[0]
	assert_true(b.is_equal_approx(AABB(Vector3(9.625, 0, 3.25), Vector3(0.75, 0.75, 1.5))), str(b))
	item.rot = 180
	b = FurnitureFactory.collision_boxes(item)[0]
	assert_true(b.is_equal_approx(AABB(Vector3(9.25, 0, 3.625), Vector3(1.5, 0.75, 0.75))), str(b))

func test_counts_within_spec_ranges() -> void:
	var ranges := {
		"sofa": [2, 3], "tub_chair": [1, 2], "sling_chair": [1, 2], "coffee_table": [1, 1],
		"credenza": [1, 1], "owl_lamp": [1, 1], "wardrobe": [3, 5], "tv_stand": [1, 1],
		"whiteboard": [1, 2], "av_cart": [1, 1], "desk": [6, 12], "group_table": [2, 4],
		"task_chair": [10, 99], "stack_chair": [3, 4], "bookcase": [1, 3], "plant": [1, 2],
		"kitchenette": [1, 1], "conference_table": [1, 1]}
	var counts := {}
	for item in FurnitureFactory.load_layout():
		assert_true(item.type in TYPES, "known type %s" % item.type)
		assert_true(int(item.rot) in [0, 90, 180, 270], "rot %s" % item.rot)
		counts[item.type] = counts.get(item.type, 0) + 1
	for t in ranges:
		var n: int = counts.get(t, 0)
		assert_between(n, ranges[t][0], ranges[t][1], "count %s" % t)

func test_all_items_inside_room() -> void:
	for item in FurnitureFactory.load_layout():
		for r in _item_rects(item):
			var inner := r.grow(-EPS)
			var steps := 20
			for i in steps + 1:
				var f := float(i) / steps
				for p in [Vector2(inner.position.x + inner.size.x * f, inner.position.y),
						Vector2(inner.position.x + inner.size.x * f, inner.end.y),
						Vector2(inner.position.x, inner.position.y + inner.size.y * f),
						Vector2(inner.end.x, inner.position.y + inner.size.y * f)]:
					assert_true(RoomGeometry.contains_xz(p), "%s at %s inside (%s)" % [item.type, item.pos, p])

func test_no_overlaps_except_chairs_at_desks() -> void:
	var layout := FurnitureFactory.load_layout()
	var columns: Array[Rect2] = []
	for c in RoomGeometry.column_boxes():
		columns.append(_footprint(c))
	for i in layout.size():
		var a: Dictionary = layout[i]
		for ra in _item_rects(a):
			for c in columns:
				assert_false(_overlap(ra, c), "%s at %s hits a column" % [a.type, a.pos])
		for j in range(i + 1, layout.size()):
			var b: Dictionary = layout[j]
			if _allowed_overlap(a, b) or _allowed_overlap(b, a):
				continue
			for ra in _item_rects(a):
				for rb in _item_rects(b):
					assert_false(_overlap(ra, rb), "%s at %s overlaps %s at %s" % [a.type, a.pos, b.type, b.pos])

func _allowed_overlap(a: Dictionary, b: Dictionary) -> bool:
	if a.type in CHAIRS and b.type in TABLES:
		return true  # chair tucked under a desk or table
	if a.type == "owl_lamp" and b.type == "credenza":
		var p := Vector2(a.pos[0], a.pos[1])
		return _item_rects(b)[0].has_point(p)  # the lamp stands on the credenza
	return false

func test_lamp_stands_on_credenza() -> void:
	var lamp := {}
	var cred := {}
	for item in FurnitureFactory.load_layout():
		if item.type == "owl_lamp":
			lamp = item
		elif item.type == "credenza":
			cred = item
	var lb: AABB = FurnitureFactory.collision_boxes(lamp)[0]
	var cb: AABB = FurnitureFactory.collision_boxes(cred)[0]
	assert_almost_eq(lb.position.y, cb.end.y, 0.01)
	assert_true(_footprint(cb).encloses(_footprint(lb)), "lamp footprint on credenza")

func test_doors_clear() -> void:
	var walls := RoomGeometry.walls()
	for door in RoomData.DOORS:
		var w: Dictionary = walls[door.edge]
		var a: Vector2 = w.a
		var b: Vector2 = w.b
		var along := (b - a).normalized()
		var inward: Vector2 = -w.normal
		var horizontal := absf(along.x) > 0.5
		var origin := Vector2(door.center, a.y) if horizontal else Vector2(a.x, door.center)
		var p1 := origin - along * 0.5
		var p2 := origin + along * 0.5 + inward * 1.0
		var zone := Rect2(p1, Vector2.ZERO).expand(p2)
		assert_almost_eq(zone.get_area(), 1.0, 0.001)
		assert_true(RoomGeometry.contains_xz(zone.get_center()), "door zone inside room")
		for item in FurnitureFactory.load_layout():
			for r in _item_rects(item):
				assert_false(_overlap(r, zone), "%s at %s blocks door %s" % [item.type, item.pos, door])

func test_box_heights() -> void:
	for b in FurnitureFactory.all_boxes():
		assert_true(b.end.y <= 2.2 + EPS, "height %s" % b)
		assert_true(b.position.y >= -EPS, "above floor %s" % b)

func test_window_sill_clear() -> void:
	var w: Dictionary = RoomGeometry.walls()[RoomData.WINDOW_BANK_EDGE]
	var sill := Rect2(minf(w.a.x, w.b.x), w.a.y, absf(w.b.x - w.a.x), 0.6)
	var too_tall: Array[String] = []
	for item in FurnitureFactory.load_layout():
		if item.type in ["credenza", "owl_lamp"]:
			continue
		for b in FurnitureFactory.collision_boxes(item):
			if _overlap(_footprint(b), sill) and b.end.y > 0.75 + EPS:
				too_tall.append("%s at %s" % [item.type, item.pos])
	assert_eq(too_tall, [] as Array[String], "too tall under the window")

func test_spawnable_area_remains() -> void:
	var used := 0.0
	for b in FurnitureFactory.all_boxes():
		used += b.size.x * b.size.z
	for c in RoomGeometry.column_boxes():
		used += c.size.x * c.size.z
	var free := RoomGeometry.area() - used
	assert_true(free >= 0.6 * RoomGeometry.area(), "free %.1f of %.1f" % [free, RoomGeometry.area()])

const SEATS := {
	"sofa": [1.8, 0.9, 0.7], "tub_chair": [0.8, 0.7, 0.75], "sling_chair": [0.7, 0.8, 0.8],
	"task_chair": [0.65, 0.65, 1.0], "stack_chair": [0.5, 0.52, 0.85]}

func _visible_top(node: Node3D, p: Vector2) -> float:
	# Highest mesh surface straight above p (exact ray vs triangles).
	var best := -1.0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = node.transform * (mi as MeshInstance3D).transform
		var faces: PackedVector3Array = (mi as MeshInstance3D).mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(p.x, 5.0, p.y), Vector3.DOWN,
				xf * faces[i], xf * faces[i + 1], xf * faces[i + 2])
			if hit != null:
				best = maxf(best, (hit as Vector3).y)
	return best

func _box_top(boxes: Array[AABB], p: Vector2) -> float:
	var best := -1.0
	for b in boxes:
		if _footprint(b).has_point(p):
			best = maxf(best, b.end.y)
	return best

func test_seat_boxes_follow_seat_height() -> void:
	for t in SEATS:
		for rot in [0, 90, 180, 270]:
			var item := {"type": t, "pos": [10.0, 5.0], "rot": rot, "size": SEATS[t]}
			var node := FurnitureFactory.build(item)
			var p := Vector2(10.05, 5.05)  # off-centre: the sofa has a seam between cushions
			var seat := _visible_top(node, p)
			node.free()
			assert_between(seat, 0.2, 0.55, "%s visible seat height" % t)
			assert_almost_eq(_box_top(FurnitureFactory.collision_boxes(item), p), seat, 0.03, "%s rot %d seat box" % [t, rot])
			assert_true(FurnitureFactory.collision_boxes(item).size() >= 2, "%s has a back box" % t)
			var top := 0.0
			for b in FurnitureFactory.collision_boxes(item):
				top = maxf(top, b.end.y)
			assert_almost_eq(top, float(SEATS[t][2]), 0.03, "%s back reaches full height" % t)

func test_kitchenette_upper_cabinets_have_collision() -> void:
	var item := {"type": "kitchenette", "pos": [5.0, 5.0], "rot": 0, "size": [2.4, 0.65, 1.8]}
	var boxes := FurnitureFactory.collision_boxes(item)
	var found := false
	for b in boxes:
		if b.position.y > 1.2 and b.end.y <= 1.8 + EPS and b.size.x > 1.0:
			found = true
	assert_true(found, "upper cabinet box in %s" % [boxes])

func test_av_cart_has_printer_box() -> void:
	var item := {"type": "av_cart", "pos": [5.0, 5.0], "rot": 0, "size": [0.8, 0.5, 0.9]}
	var boxes := FurnitureFactory.collision_boxes(item)
	assert_eq(boxes.size(), 2)
	assert_almost_eq(boxes[0].end.y, 0.9, 0.001)
	assert_almost_eq(boxes[1].position.y, 0.9, 0.001)
	assert_true(boxes[1].size.x < 0.8 and boxes[1].size.z <= 0.5, "printer narrower than cart")

func test_plant_box_is_core_only() -> void:
	var item := {"type": "plant", "pos": [5.0, 5.0], "rot": 0, "size": [0.7, 0.7, 1.6]}
	for b in FurnitureFactory.collision_boxes(item):
		assert_true(b.size.x <= 0.45 and b.size.z <= 0.45, "plant box %s" % b)

func test_boxes_have_positive_size() -> void:
	var boxes := FurnitureFactory.all_boxes()
	for t in TYPES:
		for rot in [0, 90, 180, 270]:
			boxes.append_array(FurnitureFactory.collision_boxes({"type": t, "pos": [5.0, 5.0], "rot": rot, "size": [1.0, 0.6, 0.9]}))
	for b in boxes:
		assert_true(b.size.x > 0.0 and b.size.y > 0.0 and b.size.z > 0.0, "positive size %s" % b)

func test_box_budget_for_shader() -> void:
	var n := FurnitureFactory.all_boxes().size() + RoomGeometry.column_boxes().size()
	assert_eq(RoomGeometry.column_boxes().size(), 4)
	assert_true(n <= 128, "total boxes %d" % n)

# --- the user's description of the real room (Task 13) -----------------------

const ALCOVE := Rect2(20.3, 10.7, 11.2, 4.1)
const NEAR_WALL_Z := 14.8
const WALL_SNAP := 0.15

func _of_type(t: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in FurnitureFactory.load_layout():
		if item.type == t:
			out.append(item)
	return out

func _one(t: String) -> Dictionary:
	var items := _of_type(t)
	assert_eq(items.size(), 1, "exactly one %s" % t)
	return items[0] if items.size() > 0 else {"type": t, "pos": [-99.0, -99.0], "rot": 0, "size": [1.0, 1.0, 1.0]}

func _item_footprint(item: Dictionary) -> Rect2:
	var rects := _item_rects(item)
	var r: Rect2 = rects[0]
	for x in rects:
		r = r.merge(x)
	return r

func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dz := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return sqrt(dx * dx + dz * dz)

func _against_near_or_left_wall(desk: Dictionary) -> bool:
	var r := _item_footprint(desk)
	var near_south := absf(r.end.y - 10.7) <= WALL_SNAP and r.end.x <= 20.3 + EPS     # edge 8
	var near_notch := absf(r.position.x - 0.0) <= WALL_SNAP and r.position.y >= 5.9 - EPS  # edge 9
	var near_west := absf(r.position.x - 2.9) <= WALL_SNAP and r.end.y <= 5.9 + EPS      # edge 1
	return near_south or near_notch or near_west

func test_tv_in_alcove_against_near_wall() -> void:
	var tv := _one("tv_stand")
	assert_true(ALCOVE.has_point(Vector2(tv.pos[0], tv.pos[1])), "tv at %s in alcove" % [tv.pos])
	assert_almost_eq(_item_footprint(tv).end.y, NEAR_WALL_Z, 0.1, "tv back on the near wall")

func test_couches_in_front_of_tv() -> void:
	var tv := _one("tv_stand")
	var sofas := _of_type("sofa")
	assert_true(sofas.size() >= 2, "sofas")
	var zone := Rect2(ALCOVE.position.x - 1.0, ALCOVE.position.y - 1.5, ALCOVE.size.x + 2.0, ALCOVE.size.y + 1.5)
	for s in sofas:
		assert_lt(float(s.pos[1]), float(tv.pos[1]), "sofa at %s north of the tv" % [s.pos])
		assert_true(zone.encloses(_item_footprint(s)), "sofa at %s in or just north of the alcove" % [s.pos])

func test_conference_table_behind_couches() -> void:
	var table := _one("conference_table")
	for s in _of_type("sofa"):
		assert_lt(float(table.pos[1]), float(s.pos[1]), "conference table behind sofa at %s" % [s.pos])

func test_kitchenette_left_of_tv() -> void:
	var k := _one("kitchenette")
	var tv := _one("tv_stand")
	assert_lt(float(k.pos[0]), float(tv.pos[0]), "kitchenette left of the tv")
	assert_true(ALCOVE.grow(EPS).encloses(_item_footprint(k)), "kitchenette in the alcove")

func test_filing_cabinets_next_to_kitchenette() -> void:
	var chain: Array[Rect2] = [_item_footprint(_one("kitchenette"))]
	var pending := _of_type("wardrobe")
	assert_true(pending.size() >= 3, "at least 3 filing cabinets")
	var grew := true
	while grew:
		grew = false
		for w in pending.duplicate():
			var r := _item_footprint(w)
			for c in chain:
				if _gap(r, c) <= 1.0:
					chain.append(r)
					pending.erase(w)
					grew = true
					break
	assert_eq(pending.size(), 0, "cabinets not chained to the kitchenette: %s" % [pending])

func test_desks_on_left() -> void:
	for d in _of_type("desk"):
		assert_lt(float(d.pos[0]), 20.3, "desk at %s on the left" % [d.pos])

func test_most_desks_against_near_or_left_walls() -> void:
	var desks := _of_type("desk")
	var n := 0
	for d in desks:
		if _against_near_or_left_wall(d):
			n += 1
	assert_true(n * 2 >= desks.size(), "%d of %d desks against the walls" % [n, desks.size()])

func test_two_desk_islands() -> void:
	var free: Array[Rect2] = []
	for d in _of_type("desk"):
		if not _against_near_or_left_wall(d):
			free.append(_item_footprint(d))
	var seen := {}
	var sizes: Array[int] = []
	for i in free.size():
		if seen.has(i):
			continue
		var stack: Array[int] = [i]
		seen[i] = true
		var size := 0
		while not stack.is_empty():
			var k: int = stack.pop_back()
			size += 1
			for j in free.size():
				if not seen.has(j) and _gap(free[k], free[j]) <= 0.1:
					seen[j] = true
					stack.append(j)
		sizes.append(size)
	assert_eq(sizes.size(), 2, "desk islands %s" % [sizes])
	for s in sizes:
		assert_true(s >= 2, "island of %d desks" % s)

func test_conference_table_buildable() -> void:
	var item := {"type": "conference_table", "pos": [27.0, 8.0], "rot": 0, "size": [3.6, 1.2, 0.75]}
	var node := FurnitureFactory.build(item)
	assert_eq(String(node.name), "ConferenceTable")
	assert_true(node.find_children("*", "MeshInstance3D", true, false).size() >= 1, "meshes")
	node.free()
	var top := 0.0
	for b in FurnitureFactory.collision_boxes(item):
		top = maxf(top, b.end.y)
	assert_almost_eq(top, 0.75, 0.001)
