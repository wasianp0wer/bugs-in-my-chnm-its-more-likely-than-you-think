class_name OrbitMath
extends RefCounted
## Pure orbit-camera math. +X east, +Z south, +Y up. Yaw 0 puts the camera
## south of the target (a +Z offset) looking north.

const ORBIT_RAD_PER_PX := 0.005
const ZOOM_BASE := 0.9
const PAN_PER_PX := 0.0015
const MIN_PITCH := deg_to_rad(20.0)
const MAX_PITCH := deg_to_rad(89.0)
const MIN_DISTANCE := 0.03
const MAX_DISTANCE := 45.0
const MAX_TARGET_Y := RoomData.CEILING
const MIN_CAMERA_Y := 0.05
## The camera stays within the room bounds grown by this much horizontally (m).
const CAMERA_MARGIN := 20.0

var bounds: Rect2
var target: Vector3
var yaw: float = 0.0
var pitch: float = deg_to_rad(50.0)
var distance: float = 30.0

func _init(room_bounds: Rect2) -> void:
	bounds = room_bounds
	var c := bounds.get_center()
	target = Vector3(c.x, 0.5, c.y)

func orbit(dx_px: float, dy_px: float) -> void:
	yaw -= dx_px * ORBIT_RAD_PER_PX
	pitch = clampf(pitch + dy_px * ORBIT_RAD_PER_PX, MIN_PITCH, MAX_PITCH)

func zoom(steps: float) -> void:
	distance = clampf(distance * pow(ZOOM_BASE, steps), MIN_DISTANCE, MAX_DISTANCE)

## Zoom, and when zooming in, slide the target toward `point` by (1 - 0.9^steps).
func zoom_toward(steps: float, point: Vector3) -> void:
	zoom(steps)
	if steps > 0.0:
		target = target.lerp(point, 1.0 - pow(ZOOM_BASE, steps))
		_clamp_target()

## Jump to an explicit view; pitch, distance and target are clamped as usual.
func set_view(p_target: Vector3, p_yaw: float, p_pitch: float, p_distance: float) -> void:
	target = p_target
	yaw = p_yaw
	pitch = clampf(p_pitch, MIN_PITCH, MAX_PITCH)
	distance = clampf(p_distance, MIN_DISTANCE, MAX_DISTANCE)
	_clamp_target()

func pan(dx_px: float, dy_px: float) -> void:
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var s := distance * PAN_PER_PX
	target += (-right * dx_px + forward * dy_px) * s
	_clamp_target()

func _clamp_target() -> void:
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	target.y = clampf(target.y, 0.0, MAX_TARGET_Y)

func transform() -> Transform3D:
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	var pos := target + offset
	pos.y = maxf(pos.y, MIN_CAMERA_Y)
	var outer := bounds.grow(CAMERA_MARGIN)
	pos.x = clampf(pos.x, outer.position.x, outer.end.x)
	pos.z = clampf(pos.z, outer.position.y, outer.end.y)
	if pos.is_equal_approx(target):
		pos.y = target.y + MIN_CAMERA_Y
	return Transform3D(Basis.IDENTITY, pos).looking_at(target, Vector3.UP)
