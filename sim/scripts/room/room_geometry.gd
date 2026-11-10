class_name RoomGeometry

## Height animals spawn at before falling (mirrors SPAWN_Y in critter_process.gdshader).
const SPAWN_Y := 2.8

static func contains_xz(p: Vector2) -> bool:
	for r in RoomData.RECTS:
		if p.x >= r.position.x and p.x <= r.end.x and p.y >= r.position.y and p.y <= r.end.y:
			return true
	return false

static func area() -> float:
	var total := 0.0
	for r in RoomData.RECTS:
		total += r.get_area()
	return total

static func bounds() -> Rect2:
	var b: Rect2 = RoomData.RECTS[0]
	for r in RoomData.RECTS:
		b = b.merge(r)
	return b

static func _signed_outline_area2() -> float:
	var pts := RoomData.OUTLINE
	var s := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		s += a.x * b.y - b.x * a.y
	return s

static func walls() -> Array[Dictionary]:
	var pts := RoomData.OUTLINE
	# With shoelace sum s > 0 the outward normal of edge d is (d.y, -d.x); flip otherwise.
	var sgn := 1.0 if _signed_outline_area2() > 0.0 else -1.0
	var out: Array[Dictionary] = []
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var d := b - a
		out.append({
			"a": a,
			"b": b,
			"normal": (Vector2(d.y, -d.x) * sgn).normalized(),
			"exterior": i in RoomData.EXTERIOR_EDGES,
			"index": i,
		})
	return out

static func column_boxes() -> Array[AABB]:
	var out: Array[AABB] = []
	var s := RoomData.COLUMN_SIZE
	for c in RoomData.COLUMNS:
		out.append(AABB(Vector3(c.x - s / 2.0, 0.0, c.y - s / 2.0), Vector3(s, RoomData.CEILING, s)))
	return out

## Some box grown by c in x/z (not y) contains q; faces are solid (inclusive), as in
## MotionRules._in_box_c.
static func _inside_any(q: Vector3, boxes: Array[AABB], c: float) -> bool:
	for b in boxes:
		if MotionRules._in_box_c(b, q, c):
			return true
	return false

## All four corners p +- c are in the room (MotionRules._inside_room_c).
static func _contains_c(p: Vector2, c: float) -> bool:
	return contains_xz(Vector2(p.x - c, p.y - c)) and contains_xz(Vector2(p.x + c, p.y - c)) \
			and contains_xz(Vector2(p.x - c, p.y + c)) and contains_xz(Vector2(p.x + c, p.y + c))

## Area-weighted xz in the room, re-sampled until the animal's footprint (p +- clearance)
## is in the room and the spawn point (x, SPAWN_Y, z) is in no box grown by clearance in
## x/z; spawning above a low box (a desk) is fine, the animal rains down onto it.
static func random_spawn_xz(rng: RandomNumberGenerator, obstacles: Array[AABB],
		clearance := 0.0) -> Vector2:
	var total := area()
	while true:
		var pick := rng.randf() * total
		var r: Rect2 = RoomData.RECTS[RoomData.RECTS.size() - 1]
		for cand in RoomData.RECTS:
			if pick < cand.get_area():
				r = cand
				break
			pick -= cand.get_area()
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		if _contains_c(p, clearance) and not _inside_any(Vector3(p.x, SPAWN_Y, p.y), obstacles, clearance):
			return p
	return Vector2.ZERO

static func walls_facing_camera(cam_pos: Vector3) -> PackedInt32Array:
	var cam := Vector2(cam_pos.x, cam_pos.z)
	var out := PackedInt32Array()
	for w in walls():
		var mid: Vector2 = (w.a + w.b) * 0.5
		if (w.normal as Vector2).dot(cam - mid) > 0.0:
			out.append(w.index)
	return out
