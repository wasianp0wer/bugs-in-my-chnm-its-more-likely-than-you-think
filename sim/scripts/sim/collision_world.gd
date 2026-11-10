class_name CollisionWorld
extends RefCounted
## Static collision geometry: walkable room rectangles (x, z), solid boxes and a lid.

const MAX_RECTS := 8
const MAX_BOXES := 128

var rects: Array[Rect2]
var boxes: Array[AABB]
var ceiling: float

func _init(p_rects: Array[Rect2], p_boxes: Array[AABB], p_ceiling: float) -> void:
	# The shader's uniform arrays hold MAX_RECTS / MAX_BOXES; extra ones are dropped.
	rects = p_rects
	if rects.size() > MAX_RECTS:
		push_error("CollisionWorld: %d room rects, keeping the first %d" % [rects.size(), MAX_RECTS])
		rects = rects.slice(0, MAX_RECTS)
	boxes = p_boxes
	if boxes.size() > MAX_BOXES:
		push_error("CollisionWorld: %d boxes, keeping the first %d" % [boxes.size(), MAX_BOXES])
		boxes = boxes.slice(0, MAX_BOXES)
	ceiling = p_ceiling

## Boundaries count as inside.
func inside_room_xz(p: Vector2) -> bool:
	for r in rects:
		if p.x >= r.position.x and p.x <= r.end.x and p.y >= r.position.y and p.y <= r.end.y:
			return true
	return false

## Index of the box containing p (faces are solid), or -1.
func box_at(p: Vector3) -> int:
	for i in boxes.size():
		var b := boxes[i]
		var e := b.end
		if p.x >= b.position.x and p.x <= e.x and p.y >= b.position.y and p.y <= e.y \
				and p.z >= b.position.z and p.z <= e.z:
			return i
	return -1

func to_shader_params() -> Dictionary:
	var rr: Array[Vector4] = []
	for r in rects:
		rr.append(Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
	rr.resize(MAX_RECTS)
	var bmin: Array[Vector3] = []
	var bmax: Array[Vector3] = []
	for b in boxes:
		bmin.append(b.position)
		bmax.append(b.end)
	bmin.resize(MAX_BOXES)
	bmax.resize(MAX_BOXES)
	return {
		"room_rects": rr, "room_rect_count": rects.size(),
		"box_min": bmin, "box_max": bmax, "box_count": boxes.size(),
		"ceiling": ceiling,
	}
