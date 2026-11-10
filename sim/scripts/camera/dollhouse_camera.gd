class_name DollhouseCamera
extends Camera3D
## Thin input adapter over OrbitMath.

signal moved(cam_pos: Vector3)

@export var room_bounds: Rect2 = Rect2(0, 0, 31.5, 14.8)

var _math: OrbitMath
var _orbiting := false
var _panning := false

func _ready() -> void:
	near = 0.002
	far = 200.0
	_math = OrbitMath.new(room_bounds)
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
					_math.zoom(1.0)
					_apply()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_math.zoom(-1.0)
					_apply()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbiting:
			_math.orbit(mm.relative.x, mm.relative.y)
			_apply()
		elif _panning:
			_math.pan(mm.relative.x, mm.relative.y)
			_apply()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_math.zoom(log(mg.factor) / log(1.0 / OrbitMath.ZOOM_BASE))
		_apply()
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		_math.pan(-pg.delta.x * 10.0, -pg.delta.y * 10.0)
		_apply()
