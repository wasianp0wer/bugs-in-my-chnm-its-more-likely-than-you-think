class_name FurnitureFactory
## Builds CHNM main-room furniture from primitives (spec §3).
## Layout items: {type, pos: [x, z], rot: 0|90|180|270, size: [w, d, h]}.
## Local frame: origin at the footprint centre on the floor, width along X,
## depth along Z, front facing +Z. rot turns the item about +Y, so rot 0 faces
## south, 90 east, 180 north and 270 west.

const LAYOUT_PATH := "res://data/furniture_layout.json"
const LAMP_BASE_Y := 0.75      # owl lamp stands on the credenza (credenza height)
const TV_HEIGHT := 0.65        # flat screen on top of the media stand
const PRINTER_HEIGHT := 0.4    # 3D printer on top of the AV cart
const COUNTER_HEIGHT := 0.92
const FRIDGE_WIDTH := 0.75
const UPPER_CABINET_MAX := 0.7 # kitchenette wall cabinets, back half of the depth
# Seated furniture: shared by the mesh builders and collision_boxes (heights as fractions of h).
const SOFA_ARM := 0.16
const SOFA_BACK := 0.22
const SOFA_SEAT_FRAC := 0.6
const SOFA_ARM_FRAC := 0.85
const TUB_LEG := 0.12
const TUB_SEAT_FRAC := 0.45
const TUB_BACK := 0.21         # back depth incl. its inset from the rear edge
const TUB_ARM := 0.15
const TUB_ARM_INSET := 0.025
const TUB_ARM_FRAC := 0.6
const SLING_SEAT_FRAC := 0.32  # seat centre height
const SLING_CANVAS := 0.04
const SLING_BACK := 0.28       # depth of the reclined back zone
const TASK_SEAT_FRAC := 0.47
const TASK_SEAT_THICK := 0.06
const TASK_BACK := 0.12
const STACK_SEAT := 0.45
const STACK_SEAT_THICK := 0.05
const STACK_BACK := 0.06

const NAVY := Color(0.10, 0.15, 0.42)
const WHITE := Color(0.93, 0.92, 0.88)
const LIGHT_WOOD := Color(0.80, 0.62, 0.40)
const OAK := Color(0.66, 0.47, 0.27)
const WOOD := Color(0.52, 0.34, 0.20)
const IVORY := Color(0.96, 0.92, 0.78)
const CERAMIC := Color(0.85, 0.80, 0.70)
const BLACK := Color(0.06, 0.06, 0.07)
const CHARCOAL := Color(0.14, 0.14, 0.15)
const SCREEN := Color(0.02, 0.03, 0.05)
const ALUMINIUM := Color(0.75, 0.76, 0.78)
const CHERRY := Color(0.45, 0.17, 0.11)
const GREY := Color(0.55, 0.56, 0.58)
const LEAF := Color(0.18, 0.42, 0.16)
const POT := Color(0.42, 0.27, 0.20)
const LAMINATE := Color(0.84, 0.80, 0.70)
const COUNTERTOP := Color(0.55, 0.52, 0.48)
const STEEL := Color(0.70, 0.72, 0.74)
const BEIGE_LAMINATE := Color("#d9cfb8")
const BOOKS: Array[Color] = [Color(0.6, 0.15, 0.12), Color(0.15, 0.3, 0.55), Color(0.85, 0.75, 0.4), Color(0.3, 0.45, 0.25)]

static var _materials := {}

# --- public API -------------------------------------------------------------

static func load_layout() -> Array[Dictionary]:
	var text := FileAccess.get_file_as_string(LAYOUT_PATH)
	var data: Variant = JSON.parse_string(text)
	var out: Array[Dictionary] = []
	if not data is Array:
		push_error("FurnitureFactory: cannot parse %s" % LAYOUT_PATH)
		return out
	for raw in data:
		out.append({
			"type": String(raw.type),
			"pos": [float(raw.pos[0]), float(raw.pos[1])],
			"rot": int(raw.rot),
			"size": [float(raw.size[0]), float(raw.size[1]), float(raw.size[2])],
		})
	return out

static func build(item: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = String(item.type).to_pascal_case()
	root.transform = _transform(item)
	var w: float = item.size[0]
	var d: float = item.size[1]
	var h: float = item.size[2]
	match String(item.type):
		"sofa": _sofa(root, w, d, h)
		"tub_chair": _tub_chair(root, w, d, h)
		"sling_chair": _sling_chair(root, w, d, h)
		"coffee_table": _coffee_table(root, w, d, h)
		"credenza": _credenza(root, w, d, h)
		"owl_lamp": _owl_lamp(root, w, d, h)
		"wardrobe": _wardrobe(root, w, d, h)
		"tv_stand": _tv_stand(root, w, d, h)
		"whiteboard": _whiteboard(root, w, d, h)
		"av_cart": _av_cart(root, w, d, h)
		"desk": _desk(root, w, d, h)
		"group_table": _group_table(root, w, d, h)
		"task_chair": _task_chair(root, w, d, h)
		"stack_chair": _stack_chair(root, w, d, h)
		"bookcase": _bookcase(root, w, d, h)
		"plant": _plant(root, w, d, h)
		"kitchenette": _kitchenette(root, w, d, h)
		"conference_table": _conference_table(root, w, d, h)
		_:
			push_error("FurnitureFactory: unknown type %s" % item.type)
			_box(root, Vector3(w, h, d), Vector3(0, h / 2.0, 0), GREY)
	return root

static func collision_boxes(item: Dictionary) -> Array[AABB]:
	var xf := _transform(item)
	var out: Array[AABB] = []
	for b in _local_boxes(String(item.type), item.size[0], item.size[1], item.size[2]):
		out.append(_snap(xf * b))
	return out

## Collision boxes in the local frame, following the visible geometry.
static func _local_boxes(type: String, w: float, d: float, h: float) -> Array[AABB]:
	var back := -d / 2.0
	match type:
		"sofa":
			var ax := w / 2.0 - SOFA_ARM
			return [
				_slab(-w / 2.0, w / 2.0, back, back + SOFA_BACK, h),
				_slab(-ax, ax, back + SOFA_BACK, d / 2.0, h * SOFA_SEAT_FRAC),
				_slab(-w / 2.0, -ax, back + SOFA_BACK, d / 2.0, h * SOFA_ARM_FRAC),
				_slab(ax, w / 2.0, back + SOFA_BACK, d / 2.0, h * SOFA_ARM_FRAC)]
		"tub_chair":
			var ox := w / 2.0 - TUB_ARM_INSET
			var arm_top := TUB_LEG + h * TUB_ARM_FRAC
			return [
				_slab(-w / 2.0, w / 2.0, back, back + TUB_BACK, h),
				_slab(-ox + TUB_ARM, ox - TUB_ARM, back + TUB_BACK, d / 2.0, TUB_LEG + h * TUB_SEAT_FRAC),
				_slab(-ox, -ox + TUB_ARM, back + TUB_BACK, d / 2.0, arm_top),
				_slab(ox - TUB_ARM, ox, back + TUB_BACK, d / 2.0, arm_top)]
		"sling_chair":
			return [
				_slab(-w / 2.0, w / 2.0, back, back + SLING_BACK, h),
				_slab(-w / 2.0, w / 2.0, back + SLING_BACK, d / 2.0, h * SLING_SEAT_FRAC + SLING_CANVAS / 2.0)]
		"task_chair":
			return [
				_slab(-w / 2.0, w / 2.0, back, back + TASK_BACK, h),
				_slab(-w / 2.0, w / 2.0, back + TASK_BACK, d / 2.0, h * TASK_SEAT_FRAC + TASK_SEAT_THICK / 2.0)]
		"stack_chair":
			return [
				_slab(-w / 2.0, w / 2.0, back, back + STACK_BACK, h),
				_slab(-w / 2.0, w / 2.0, back + STACK_BACK, d / 2.0, STACK_SEAT + STACK_SEAT_THICK / 2.0)]
		"owl_lamp":
			return [AABB(Vector3(-w / 2.0, LAMP_BASE_Y, back), Vector3(w, h, d))]
		"tv_stand":
			return [_slab(-w / 2.0, w / 2.0, back, d / 2.0, h + TV_HEIGHT)]
		"av_cart":
			var pw := _printer_width(w, d)
			return [
				_slab(-w / 2.0, w / 2.0, back, d / 2.0, h),
				AABB(Vector3(-pw / 2.0, h, -pw / 2.0), Vector3(pw, PRINTER_HEIGHT, pw))]
		"plant":
			var core := _pot_radius(w, d) * 2.0
			return [_slab(-core / 2.0, core / 2.0, -core / 2.0, core / 2.0, h)]
		"kitchenette":
			var fw := _fridge_width(w)
			var ch := minf(COUNTER_HEIGHT, h)
			var out: Array[AABB] = [
				_slab(-w / 2.0, -w / 2.0 + fw, back, d / 2.0, h),
				_slab(-w / 2.0 + fw, w / 2.0, back, d / 2.0, ch)]
			var uh := _upper_cabinet_height(h, ch)
			if uh > 0.0:
				out.append(AABB(Vector3(-w / 2.0 + fw, h - uh, back), Vector3(w - fw, uh, d / 2.0)))
			return out
	return [_slab(-w / 2.0, w / 2.0, back, d / 2.0, h)]

static func _slab(x0: float, x1: float, z0: float, z1: float, top: float) -> AABB:
	return AABB(Vector3(x0, 0.0, z0), Vector3(x1 - x0, top, z1 - z0))

static func build_all() -> Node3D:
	var root := Node3D.new()
	root.name = "Furniture"
	for item in load_layout():
		root.add_child(build(item))
	return root

static func all_boxes() -> Array[AABB]:
	var out: Array[AABB] = []
	for item in load_layout():
		out.append_array(collision_boxes(item))
	return out

# --- helpers ----------------------------------------------------------------

static func _transform(item: Dictionary) -> Transform3D:
	var basis := Basis(Vector3.UP, deg_to_rad(float(item.rot)))
	return Transform3D(basis, Vector3(float(item.pos[0]), 0.0, float(item.pos[1])))

static func _snap(b: AABB) -> AABB:
	# Rotations are multiples of 90°, so round away float noise (mm precision).
	var p := b.position.snappedf(0.0001)
	var e := b.end.snappedf(0.0001)
	return AABB(p, e - p)

static func _fridge_width(w: float) -> float:
	return minf(FRIDGE_WIDTH, w * 0.4)

static func _upper_cabinet_height(h: float, counter_h: float) -> float:
	return minf(UPPER_CABINET_MAX, h - counter_h - 0.5) if h > counter_h + 0.6 else 0.0

static func _printer_width(w: float, d: float) -> float:
	return minf(w, d) * 0.9

static func _pot_radius(w: float, d: float) -> float:
	return minf(w, d) / 2.0 * 0.6

static func _material(c: Color) -> StandardMaterial3D:
	if not _materials.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_materials[c] = m
	return _materials[c]

static func _box(parent: Node3D, size: Vector3, center: Vector3, c: Color, rot_x := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(c)
	mi.position = center
	mi.rotation.x = rot_x
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, top_r: float, bottom_r: float, height: float, center: Vector3, c: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(c)
	mi.position = center
	parent.add_child(mi)
	return mi

static func _legs(parent: Node3D, w: float, d: float, h: float, inset: float, r: float, c: Color) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_cyl(parent, r, r, h, Vector3(sx * (w / 2.0 - inset), h / 2.0, sz * (d / 2.0 - inset)), c)

# --- item builders (local frame, front = +Z) --------------------------------

static func _sofa(p: Node3D, w: float, d: float, h: float) -> void:
	# Klippan-like: boxy base, full-height back, square arms, two seat cushions.
	var seat_h := h * SOFA_SEAT_FRAC
	var seat_d := d - SOFA_BACK
	var seat_z := -d / 2.0 + SOFA_BACK + seat_d / 2.0
	_box(p, Vector3(w, seat_h * 0.7, d), Vector3(0, seat_h * 0.35, 0), NAVY)
	_box(p, Vector3(w, h, SOFA_BACK), Vector3(0, h / 2.0, -d / 2.0 + SOFA_BACK / 2.0), NAVY)
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(SOFA_ARM, h * SOFA_ARM_FRAC, d), Vector3(sx * (w / 2.0 - SOFA_ARM / 2.0), h * SOFA_ARM_FRAC / 2.0, 0), NAVY)
	var cw := (w - 2.0 * SOFA_ARM) / 2.0 - 0.02
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(cw, seat_h * 0.3, seat_d - 0.04), Vector3(sx * (cw / 2.0 + 0.01), seat_h * 0.85, seat_z),
			NAVY.lightened(0.08))

static func _tub_chair(p: Node3D, w: float, d: float, h: float) -> void:
	# Tullsta-like: white rounded tub on short light-wood legs.
	var r := minf(w, d) / 2.0
	var seat_h := h * TUB_SEAT_FRAC
	_legs(p, w * 0.8, d * 0.8, TUB_LEG, 0.03, 0.025, LIGHT_WOOD)
	_cyl(p, r, r * 0.95, seat_h, Vector3(0, TUB_LEG + seat_h / 2.0, 0), WHITE)
	_box(p, Vector3(w * 0.9, h - TUB_LEG, TUB_BACK - 0.03), Vector3(0, TUB_LEG + (h - TUB_LEG) / 2.0, -d / 2.0 + 0.03 + (TUB_BACK - 0.03) / 2.0), WHITE)
	var arm_d := d - TUB_BACK
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(TUB_ARM, h * TUB_ARM_FRAC, arm_d), Vector3(sx * (w / 2.0 - TUB_ARM_INSET - TUB_ARM / 2.0), TUB_LEG + h * TUB_ARM_FRAC / 2.0, d / 2.0 - arm_d / 2.0), WHITE)

static func _sling_chair(p: Node3D, w: float, d: float, h: float) -> void:
	# White canvas sling on a tubular frame, reclined.
	var tube := 0.02
	for sx in [-1.0, 1.0]:
		var x: float = sx * (w / 2.0 - tube)
		_box(p, Vector3(tube * 2.0, tube * 2.0, d), Vector3(x, tube, 0), WHITE)
		_box(p, Vector3(tube * 2.0, h * 0.55, tube * 2.0), Vector3(x, h * 0.275, d / 2.0 - 0.1), WHITE)
		_box(p, Vector3(tube * 2.0, tube * 2.0, d * 0.75), Vector3(x, h * 0.55, 0.0), WHITE)
	var seat_len := d * 0.6
	_box(p, Vector3(w - 0.08, SLING_CANVAS, seat_len), Vector3(0, h * SLING_SEAT_FRAC, d * 0.1), IVORY, deg_to_rad(-10.0))
	_box(p, Vector3(w - 0.08, 0.04, h * 0.75), Vector3(0, h * 0.62, -d / 2.0 + 0.15), IVORY, deg_to_rad(65.0))

static func _coffee_table(p: Node3D, w: float, d: float, h: float) -> void:
	_box(p, Vector3(w, 0.04, d), Vector3(0, h - 0.02, 0), OAK)
	_box(p, Vector3(w - 0.1, 0.025, d - 0.1), Vector3(0, 0.12, 0), OAK)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(p, Vector3(0.05, h - 0.04, 0.05), Vector3(sx * (w / 2.0 - 0.04), (h - 0.04) / 2.0, sz * (d / 2.0 - 0.04)), OAK.darkened(0.15))

static func _credenza(p: Node3D, w: float, d: float, h: float) -> void:
	_box(p, Vector3(w, h - 0.06, d), Vector3(0, (h - 0.06) / 2.0 + 0.03, 0), WOOD)
	_box(p, Vector3(w + 0.02, 0.03, d + 0.02), Vector3(0, h - 0.015, 0), WOOD.darkened(0.2))
	for sx in [-1.0, 0.0, 1.0]:
		_box(p, Vector3(0.01, h * 0.7, 0.01), Vector3(sx * w / 6.0, h * 0.5, d / 2.0 + 0.005), WOOD.darkened(0.35))

static func _owl_lamp(p: Node3D, w: float, d: float, h: float) -> void:
	# Stands on the credenza: two ceramic owls, a stem and a pleated drum shade.
	var base := LAMP_BASE_Y
	var r := minf(w, d) / 2.0
	_cyl(p, r * 0.5, r * 0.6, 0.03, Vector3(0, base + 0.015, 0), WOOD.darkened(0.3))
	for sx in [-1.0, 1.0]:
		var ox: float = sx * r * 0.28
		_cyl(p, r * 0.22, r * 0.28, h * 0.22, Vector3(ox, base + 0.03 + h * 0.11, 0), CERAMIC)
		_cyl(p, r * 0.2, r * 0.2, h * 0.08, Vector3(ox, base + 0.03 + h * 0.26, 0), CERAMIC)
		_box(p, Vector3(0.025, 0.025, 0.01), Vector3(ox, base + 0.03 + h * 0.26, r * 0.2), BLACK)
	_cyl(p, 0.012, 0.012, h * 0.3, Vector3(0, base + h * 0.45, 0), ALUMINIUM)
	_cyl(p, r * 0.85, r, h * 0.42, Vector3(0, base + h * 0.79, 0), IVORY)

static func _wardrobe(p: Node3D, w: float, d: float, h: float) -> void:
	_box(p, Vector3(w, h, d), Vector3(0, h / 2.0, 0), BLACK)
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(w / 2.0 - 0.02, h - 0.08, 0.01), Vector3(sx * w / 4.0, h / 2.0, d / 2.0 + 0.005), CHARCOAL)
		_box(p, Vector3(0.015, 0.2, 0.02), Vector3(sx * 0.04, h * 0.5, d / 2.0 + 0.02), ALUMINIUM)

static func _tv_stand(p: Node3D, w: float, d: float, h: float) -> void:
	# Black media stand with open shelves and a flat screen on top.
	for y in [0.03, h * 0.45, h - 0.025]:
		_box(p, Vector3(w, 0.04, d), Vector3(0, y, 0), BLACK)
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(0.04, h, d), Vector3(sx * (w / 2.0 - 0.02), h / 2.0, 0), BLACK)
	_box(p, Vector3(w * 0.25, 0.05, d * 0.4), Vector3(0, h + 0.025, 0), BLACK)
	_box(p, Vector3(w * 0.06, 0.12, 0.04), Vector3(0, h + 0.1, 0), BLACK)
	var tv_w := w * 1.05
	_box(p, Vector3(tv_w, TV_HEIGHT - 0.15, 0.06), Vector3(0, h + 0.15 + (TV_HEIGHT - 0.15) / 2.0, 0), BLACK)
	_box(p, Vector3(tv_w - 0.06, TV_HEIGHT - 0.21, 0.01), Vector3(0, h + 0.15 + (TV_HEIGHT - 0.15) / 2.0, 0.031), SCREEN)

static func _whiteboard(p: Node3D, w: float, d: float, h: float) -> void:
	# Mobile easel: white board in an aluminium frame on two legs with feet.
	var board_h := minf(0.9, h * 0.6)
	var cy := h - board_h / 2.0 - 0.05
	_box(p, Vector3(w, board_h, 0.03), Vector3(0, cy, 0), ALUMINIUM)
	_box(p, Vector3(w - 0.04, board_h - 0.04, 0.035), Vector3(0, cy, 0), Color(0.98, 0.98, 0.97))
	_box(p, Vector3(w * 0.8, 0.02, 0.06), Vector3(0, cy - board_h / 2.0 - 0.01, 0.03), ALUMINIUM)
	for sx in [-1.0, 1.0]:
		var x: float = sx * w * 0.48
		_box(p, Vector3(0.03, h, 0.03), Vector3(x, h / 2.0, 0), ALUMINIUM)
		_box(p, Vector3(0.04, 0.04, d), Vector3(x, 0.05, 0), ALUMINIUM)

static func _av_cart(p: Node3D, w: float, d: float, h: float) -> void:
	for y in [0.2, h - 0.02]:
		_box(p, Vector3(w, 0.03, d), Vector3(0, y, 0), BLACK)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(p, Vector3(0.03, h, 0.03), Vector3(sx * (w / 2.0 - 0.02), h / 2.0, sz * (d / 2.0 - 0.02)), BLACK)
			_cyl(p, 0.04, 0.04, 0.04, Vector3(sx * (w / 2.0 - 0.02), 0.04, sz * (d / 2.0 - 0.02)), CHARCOAL)
	# MakerBot-style printer: open black frame with a build plate.
	var pw := _printer_width(w, d)
	var top := h
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(p, Vector3(0.03, PRINTER_HEIGHT, 0.03), Vector3(sx * (pw / 2.0 - 0.015), top + PRINTER_HEIGHT / 2.0, sz * (pw / 2.0 - 0.015)), CHARCOAL)
	_box(p, Vector3(pw, 0.04, pw), Vector3(0, top + PRINTER_HEIGHT - 0.02, 0), CHARCOAL)
	_box(p, Vector3(pw, 0.06, pw), Vector3(0, top + 0.03, 0), CHARCOAL)
	_box(p, Vector3(pw * 0.6, 0.01, pw * 0.6), Vector3(0, top + PRINTER_HEIGHT * 0.45, 0), Color(0.75, 0.2, 0.15))

static func _desk(p: Node3D, w: float, d: float, h: float) -> void:
	# Cherry single-pedestal desk: drawer pedestal at local -X, panel leg at +X.
	_box(p, Vector3(w, 0.035, d), Vector3(0, h - 0.0175, 0), CHERRY)
	var ped_w := minf(0.42, w * 0.3)
	var ped_x := -w / 2.0 + ped_w / 2.0
	_box(p, Vector3(ped_w, h - 0.035, d - 0.04), Vector3(ped_x, (h - 0.035) / 2.0, 0), CHERRY.darkened(0.1))
	for i in 3:
		_box(p, Vector3(0.1, 0.015, 0.01), Vector3(ped_x, h * (0.25 + 0.25 * i), d / 2.0 - 0.015), ALUMINIUM)
	_box(p, Vector3(0.03, h - 0.035, d - 0.04), Vector3(w / 2.0 - 0.015, (h - 0.035) / 2.0, 0), CHERRY.darkened(0.1))
	_box(p, Vector3(w - 0.05, h * 0.5, 0.02), Vector3(0, h * 0.55, -d / 2.0 + 0.03), CHERRY.darkened(0.1))
	# Monitor facing the sitter (front = +Z side of the desk).
	_box(p, Vector3(0.2, 0.02, 0.16), Vector3(0.1, h + 0.01, -d / 2.0 + 0.2), BLACK)
	_box(p, Vector3(0.04, 0.2, 0.03), Vector3(0.1, h + 0.1, -d / 2.0 + 0.2), BLACK)
	_box(p, Vector3(0.56, 0.34, 0.03), Vector3(0.1, h + 0.32, -d / 2.0 + 0.22), BLACK)
	_box(p, Vector3(0.52, 0.30, 0.005), Vector3(0.1, h + 0.32, -d / 2.0 + 0.237), Color(0.25, 0.35, 0.5))

static func _group_table(p: Node3D, w: float, d: float, h: float) -> void:
	_box(p, Vector3(w, 0.03, d), Vector3(0, h - 0.015, 0), WHITE)
	_box(p, Vector3(w, 0.03, d), Vector3(0, h - 0.045, 0), BLACK)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (w / 2.0 - 0.1)
		_box(p, Vector3(0.04, h - 0.06, 0.04), Vector3(x, (h - 0.06) / 2.0, 0), BLACK)
		_box(p, Vector3(0.05, 0.03, d * 0.9), Vector3(x, 0.015, 0), BLACK)
	_box(p, Vector3(w - 0.2, 0.03, 0.03), Vector3(0, h * 0.4, 0), BLACK)

static func _conference_table(p: Node3D, w: float, d: float, h: float) -> void:
	# 12 x 4 ft meeting table: beige laminate top with a dark edge on two panel bases.
	_box(p, Vector3(w, 0.035, d), Vector3(0, h - 0.0175, 0), BEIGE_LAMINATE)
	_box(p, Vector3(w + 0.01, 0.02, d + 0.01), Vector3(0, h - 0.045, 0), CHARCOAL)
	for sx in [-1.0, 1.0]:
		var x: float = sx * w * 0.3
		_box(p, Vector3(0.06, h - 0.055, d * 0.55), Vector3(x, (h - 0.055) / 2.0, 0), CHARCOAL)
		_box(p, Vector3(0.1, 0.03, d * 0.75), Vector3(x, 0.015, 0), CHARCOAL)
	_box(p, Vector3(w * 0.6, 0.08, 0.04), Vector3(0, h * 0.5, 0), CHARCOAL)

static func _task_chair(p: Node3D, w: float, d: float, h: float) -> void:
	# Aeron-style: five-star base on casters, gas lift, mesh seat and back, arms.
	var seat_y := h * TASK_SEAT_FRAC
	for i in 5:
		var a := TAU * i / 5.0
		var leg := _box(p, Vector3(0.04, 0.03, w * 0.45), Vector3(sin(a) * w * 0.22, 0.06, cos(a) * w * 0.22), BLACK)
		leg.rotation.y = a
		_cyl(p, 0.025, 0.025, 0.04, Vector3(sin(a) * w * 0.43, 0.02, cos(a) * w * 0.43), CHARCOAL)
	_cyl(p, 0.025, 0.025, seat_y - 0.08, Vector3(0, (seat_y + 0.08) / 2.0, 0), ALUMINIUM)
	_box(p, Vector3(w * 0.8, TASK_SEAT_THICK, d * 0.75), Vector3(0, seat_y, 0.03), CHARCOAL)
	_box(p, Vector3(w * 0.75, h - seat_y - 0.05, 0.05), Vector3(0, (h + seat_y) / 2.0, -d / 2.0 + 0.06), CHARCOAL, deg_to_rad(-8.0))
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(0.04, 0.2, 0.04), Vector3(sx * w * 0.42, seat_y + 0.1, 0.0), BLACK)
		_box(p, Vector3(0.06, 0.03, d * 0.4), Vector3(sx * w * 0.42, seat_y + 0.21, 0.02), BLACK)

static func _stack_chair(p: Node3D, w: float, d: float, h: float) -> void:
	var seat_y := STACK_SEAT
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(p, Vector3(0.025, seat_y, 0.025), Vector3(sx * (w / 2.0 - 0.03), seat_y / 2.0, sz * (d / 2.0 - 0.03)), ALUMINIUM)
		_box(p, Vector3(0.025, h - seat_y, 0.025), Vector3(sx * (w / 2.0 - 0.03), (h + seat_y) / 2.0, -d / 2.0 + 0.03), ALUMINIUM)
	_box(p, Vector3(w, STACK_SEAT_THICK, d), Vector3(0, seat_y, 0), GREY)
	_box(p, Vector3(w, (h - seat_y) * 0.55, 0.04), Vector3(0, h - (h - seat_y) * 0.3, -d / 2.0 + 0.03), GREY)

static func _bookcase(p: Node3D, w: float, d: float, h: float) -> void:
	var t := 0.02
	_box(p, Vector3(w, h, t), Vector3(0, h / 2.0, -d / 2.0 + t / 2.0), BLACK)
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(t, h, d), Vector3(sx * (w / 2.0 - t / 2.0), h / 2.0, 0), BLACK)
	var shelves := 5
	for i in shelves + 1:
		var y := 0.05 + (h - 0.07) * i / shelves
		_box(p, Vector3(w, t, d), Vector3(0, y, 0), BLACK)
		if i < shelves:
			var gap := (h - 0.07) / shelves
			var x := -w / 2.0 + 0.05
			var k := i
			while x < w / 2.0 - 0.12:
				var bw := 0.05 + 0.04 * ((k * 7) % 3)
				_box(p, Vector3(bw - 0.005, gap * 0.75, d * 0.75), Vector3(x + bw / 2.0, y + t / 2.0 + gap * 0.375, 0.0), BOOKS[k % BOOKS.size()])
				x += bw
				k += 1

static func _plant(p: Node3D, w: float, d: float, h: float) -> void:
	# Potted ficus/palm: pot, trunk, stacked foliage cones.
	var r := minf(w, d) / 2.0
	var pot_h := minf(0.4, h * 0.25)
	_cyl(p, _pot_radius(w, d), r * 0.45, pot_h, Vector3(0, pot_h / 2.0, 0), POT)
	_cyl(p, 0.025, 0.035, h - pot_h, Vector3(0, pot_h + (h - pot_h) / 2.0, 0), WOOD)
	var layers := 3
	var fol := h - pot_h - 0.1
	for i in layers:
		var lh := fol * 0.45
		var y := pot_h + 0.1 + fol * (0.2 + 0.27 * i) + lh / 2.0 - lh * 0.3
		y = minf(y, h - lh / 2.0)
		_cyl(p, r * 0.15, r * (1.0 - 0.2 * i), lh, Vector3(0, y, 0), LEAF.lightened(0.06 * i))

static func _kitchenette(p: Node3D, w: float, d: float, h: float) -> void:
	# Fridge at the local -X end, base cabinets with counter and sink, upper cabinets.
	var fw := _fridge_width(w)
	var ch := minf(COUNTER_HEIGHT, h)
	_box(p, Vector3(fw - 0.02, h, d), Vector3(-w / 2.0 + fw / 2.0, h / 2.0, 0), WHITE)
	_box(p, Vector3(0.03, h * 0.4, 0.03), Vector3(-w / 2.0 + fw - 0.08, h * 0.55, d / 2.0 + 0.015), STEEL)
	_box(p, Vector3(fw - 0.04, 0.01, 0.01), Vector3(-w / 2.0 + fw / 2.0, h * 0.62, d / 2.0 + 0.005), GREY)
	var cw := w - fw
	var cx := -w / 2.0 + fw + cw / 2.0
	_box(p, Vector3(cw, ch - 0.04, d - 0.03), Vector3(cx, (ch - 0.04) / 2.0, -0.015), LAMINATE)
	_box(p, Vector3(cw, 0.04, d), Vector3(cx, ch - 0.02, 0), COUNTERTOP)
	var doors := maxi(1, int(cw / 0.5))
	for i in doors:
		var dx := -w / 2.0 + fw + cw * (i + 0.5) / doors
		_box(p, Vector3(cw / doors - 0.02, ch - 0.12, 0.01), Vector3(dx, (ch - 0.04) / 2.0, d / 2.0 - 0.025), LAMINATE.darkened(0.06))
	_box(p, Vector3(minf(0.5, cw * 0.4), 0.02, d * 0.6), Vector3(cx + cw * 0.15, ch + 0.002, 0), STEEL)
	_cyl(p, 0.012, 0.012, 0.25, Vector3(cx + cw * 0.15, ch + 0.125, -d / 2.0 + 0.08), STEEL)
	_box(p, Vector3(0.45, 0.28, 0.35), Vector3(cx - cw * 0.3, ch + 0.14, -0.05), BLACK)
	var uh := _upper_cabinet_height(h, ch)
	if uh > 0.0:
		_box(p, Vector3(cw, uh, d * 0.5), Vector3(cx, h - uh / 2.0, -d / 4.0), LAMINATE)
