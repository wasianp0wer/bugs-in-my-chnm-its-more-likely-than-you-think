class_name DollhouseCamera
extends Camera3D
## Thin input adapter over OrbitMath.

signal moved(cam_pos: Vector3)

@export var room_bounds: Rect2 = RoomGeometry.bounds()

## (ray_origin, ray_dir) -> Vector3 or null. Default: the y = 0 plane.
var pick_point: Callable = _pick_floor

var _math: OrbitMath
var _orbiting := false
var _panning := false

func _ready() -> void:
	near = 0.002
	far = 200.0
	fov = 50.0
	_math = OrbitMath.new(room_bounds)
	_apply()
	_apply.call_deferred()

## Jump to a view (yaw/pitch in radians, distance in metres) and emit `moved`.
func set_view(target: Vector3, yaw: float, pitch: float, distance: float) -> void:
	_math.set_view(target, yaw, pitch, distance)
	_apply()

static func _pick_floor(ray_origin: Vector3, ray_dir: Vector3) -> Variant:
	if absf(ray_dir.y) < 0.000001:
		return null
	var t := -ray_origin.y / ray_dir.y
	if t < 0.0:
		return null
	return ray_origin + ray_dir * t

func _zoom_at_mouse(steps: float) -> void:
	var mp := get_viewport().get_mouse_position()
	var hit: Variant = pick_point.call(project_ray_origin(mp), project_ray_normal(mp))
	if hit is Vector3:
		_math.zoom_toward(steps, hit)
	else:
		_math.zoom(steps)
	_apply()

func _apply() -> void:
	transform = _math.transform()
	moved.emit(transform.origin)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_orbiting = mb.pressed
			MOUSE_BUTTON_RIGHT:
				_panning = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_at_mouse(1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_at_mouse(-1.0)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_orbiting = false
		if not (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT):
			_panning = false
		if _orbiting:
			_math.orbit(mm.relative.x, mm.relative.y)
			_apply()
		elif _panning:
			_math.pan(mm.relative.x, mm.relative.y)
			_apply()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_zoom_at_mouse(log(mg.factor) / log(1.0 / OrbitMath.ZOOM_BASE))
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		_math.pan(-pg.delta.x * 10.0, -pg.delta.y * 10.0)
		_apply()
