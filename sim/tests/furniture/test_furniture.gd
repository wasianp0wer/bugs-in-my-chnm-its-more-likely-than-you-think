extends GutTest

const TYPES := ["sofa", "tub_chair", "sling_chair", "coffee_table", "credenza", "owl_lamp",
	"wardrobe", "tv_stand", "whiteboard", "av_cart", "desk", "group_table", "task_chair",
	"stack_chair", "bookcase", "plant", "kitchenette"]
const CHAIRS := ["task_chair", "stack_chair"]
const TABLES := ["desk", "group_table"]
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
		"kitchenette": [1, 1]}
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
	for item in FurnitureFactory.load_layout():
		if item.type in ["credenza", "owl_lamp"]:
			continue
		for b in FurnitureFactory.collision_boxes(item):
			if _overlap(_footprint(b), sill):
				assert_true(b.end.y <= 0.75 + EPS, "%s at %s too tall under window" % [item.type, item.pos])

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
