class_name BoxPicker
## Pure ray pick against the floor plane (y = 0) and a list of solid boxes.

## Nearest hit of the ray (origin, dir) on the floor or any box, or null when it hits nothing.
static func pick(origin: Vector3, dir: Vector3, boxes: Array[AABB]) -> Variant:
	var best := INF
	if absf(dir.y) > 1e-6:
		var t := -origin.y / dir.y
		if t >= 0.0:
			best = t
	for b in boxes:
		var t := _ray_box(origin, dir, b)
		if t >= 0.0 and t < best:
			best = t
	if best == INF:
		return null
	return origin + dir * best

## Slab test: distance along the ray to the box entry (0 when inside), or -1 on a miss.
static func _ray_box(origin: Vector3, dir: Vector3, b: AABB) -> float:
	var t0 := 0.0
	var t1 := INF
	for axis in 3:
		var o := origin[axis]
		var lo := b.position[axis]
		var hi := b.end[axis]
		if absf(dir[axis]) < 1e-9:
			if o < lo or o > hi:
				return -1.0
			continue
		var ta := (lo - o) / dir[axis]
		var tb := (hi - o) / dir[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 > t1:
			return -1.0
	return t0
