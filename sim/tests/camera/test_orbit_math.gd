extends GutTest

const BOUNDS := Rect2(0, 0, 31.5, 14.8)

func _make() -> OrbitMath:
	return OrbitMath.new(BOUNDS)

func test_default_looks_at_target() -> void:
	var m := _make()
	assert_almost_eq(m.target, Vector3(15.75, 0.5, 7.4), Vector3(0.001, 0.001, 0.001))
	assert_almost_eq(m.pitch, deg_to_rad(50.0), 0.0001)
	assert_almost_eq(m.distance, 30.0, 0.0001)
	var t := m.transform()
	assert_gt(t.origin.z, m.target.z, "camera is south of target")
	assert_almost_eq(t.origin.x, m.target.x, 0.001)
	var fwd := -t.basis.z
	var to_target := (m.target - t.origin).normalized()
	assert_gt(fwd.dot(to_target), 0.9999)
	assert_lt(fwd.z, 0.0, "looks north")

func test_pitch_clamped() -> void:
	var m := _make()
	m.orbit(0, 100000)
	assert_almost_eq(m.pitch, deg_to_rad(89.0), 0.0001)
	m.orbit(0, -200000)
	assert_almost_eq(m.pitch, deg_to_rad(20.0), 0.0001)

func test_orbit_scale() -> void:
	var m := _make()
	var y0 := m.yaw
	m.orbit(100, 0)
	assert_almost_eq(absf(m.yaw - y0), 0.5, 0.0001)

func test_zoom_clamped() -> void:
	var m := _make()
	m.zoom(1000)
	assert_almost_eq(m.distance, 0.03, 0.00001)
	m.zoom(-1000)
	assert_almost_eq(m.distance, 45.0, 0.00001)

func test_zoom_step_factor() -> void:
	var m := _make()
	m.zoom(2)
	assert_almost_eq(m.distance, 30.0 * 0.81, 0.0001)

func test_pan_clamped_to_bounds() -> void:
	var m := _make()
	m.pan(-1000000, -1000000)
	m.pan(-1000000, -1000000)
	assert_almost_eq(m.target.x, 31.5, 0.001)
	assert_between(m.target.x, -0.0001, 31.5001)
	assert_between(m.target.z, -0.0001, 14.8001)
	m.pan(1000000, 1000000)
	assert_between(m.target.x, -0.0001, 31.5001)
	assert_between(m.target.z, -0.0001, 14.8001)
	assert_between(m.target.y, 0.0, 2.9)

func test_pan_moves_target() -> void:
	var m := _make()
	var before := m.target
	m.pan(100, 0)
	assert_lt(m.target.x, before.x, "drag right moves scene right, target left")
	assert_almost_eq(m.target.x, before.x - 100 * 30.0 * 0.0015, 0.001)

func test_camera_never_below_floor() -> void:
	var m := _make()
	m.target = Vector3(10, 0, 5)
	m.pitch = deg_to_rad(20.0)
	m.distance = 0.03
	assert_gte(m.transform().origin.y, 0.05)

func test_zoom_toward_floor_point_converges() -> void:
	var m := _make()
	var p := Vector3(5, 0, 3)
	for i in 100:
		m.zoom_toward(1.0, p)
	assert_almost_eq(m.target, p, Vector3(0.01, 0.01, 0.01))

func test_zoom_toward_desk_point_sets_target_y() -> void:
	var m := _make()
	var p := Vector3(15, 0.75, 7)
	for i in 100:
		m.zoom_toward(1.0, p)
	assert_almost_eq(m.target.y, 0.75, 0.01)

func test_zoom_toward_out_leaves_target() -> void:
	var m := _make()
	m.distance = 10.0
	var before := m.target
	m.zoom_toward(-2.0, Vector3(1, 0, 1))
	assert_eq(m.target, before)
	assert_almost_eq(m.distance, 10.0 / 0.81, 0.0001)

func test_zoom_toward_fraction() -> void:
	var m := _make()
	var before := m.target
	var p := Vector3(5, 0, 3)
	m.zoom_toward(1.0, p)
	assert_almost_eq(m.target, before.lerp(p, 0.1), Vector3(0.0001, 0.0001, 0.0001))
	assert_almost_eq(m.distance, 27.0, 0.0001)

func test_zoom_in_close_enough_for_flea() -> void:
	var cam := DollhouseCamera.new()
	add_child_autofree(cam)
	assert_almost_eq(cam.fov, 50.0, 0.0001)
	var m := _make()
	var p := Vector3(10, 0, 5)
	for i in 200:
		m.zoom_toward(1.0, p)
	var t := m.transform()
	var d := t.origin.distance_to(p)
	var px := 0.0025 / (2.0 * d * tan(deg_to_rad(cam.fov) / 2.0)) * 900.0
	assert_gte(px, 20.0)

func test_default_pick_point_hits_floor() -> void:
	var cam := DollhouseCamera.new()
	add_child_autofree(cam)
	var hit: Variant = cam.pick_point.call(Vector3(1, 5, 2), Vector3(0, -1, 0))
	assert_eq(hit, Vector3(1, 0, 2))
	assert_null(cam.pick_point.call(Vector3(1, 5, 2), Vector3(0, 1, 0)))

func test_moved_emitted_deferred_after_ready() -> void:
	var cam := DollhouseCamera.new()
	watch_signals(cam)
	add_child_autofree(cam)
	await get_tree().process_frame
	assert_signal_emit_count(cam, "moved", 2)

func test_set_view_places_camera_and_emits_moved() -> void:
	var cam := DollhouseCamera.new()
	add_child_autofree(cam)
	await get_tree().process_frame
	watch_signals(cam)
	var target := Vector3(14.6, 0.75, 4.3)
	cam.set_view(target, PI, deg_to_rad(30.0), 2.0)
	var m := OrbitMath.new(cam.room_bounds)
	m.target = target
	m.yaw = PI
	m.pitch = deg_to_rad(30.0)
	m.distance = 2.0
	assert_almost_eq(cam.transform.origin, m.transform().origin, Vector3.ONE * 1e-4)
	assert_true(cam.transform.origin.z < target.z, "yaw PI puts the camera north")
	assert_signal_emitted_with_parameters(cam, "moved", [cam.transform.origin])

func test_set_view_clamps_like_orbit_math() -> void:
	var cam := DollhouseCamera.new()
	add_child_autofree(cam)
	cam.set_view(Vector3(100, 10, -50), 0.0, deg_to_rad(5.0), 0.0001)
	var o := cam.transform.origin
	var b := cam.room_bounds
	assert_true(o.y >= OrbitMath.MIN_CAMERA_Y - 1e-4)
	assert_almost_eq(cam.transform.basis.z.dot(Vector3.UP), sin(OrbitMath.MIN_PITCH), 1e-3, "pitch clamped")
	assert_true(o.distance_to(Vector3(b.end.x, OrbitMath.MAX_TARGET_Y, b.position.y)) <= OrbitMath.MIN_DISTANCE + 1e-3, "target and distance clamped")

## However far out it orbits, the camera stays within the room bounds expanded by 20 m.
func test_camera_horizontal_clamped_to_bounds_plus_margin() -> void:
	var m := _make()
	var outer := BOUNDS.grow(20.0)
	for target in [Vector3(0, 0, 0), Vector3(31.5, 0, 14.8), Vector3(0, 0, 14.8), Vector3(31.5, 0, 0)]:
		for yaw_deg in range(0, 360, 15):
			m.set_view(target, deg_to_rad(yaw_deg), 0.0, 1000.0)
			var o := m.transform().origin
			assert_between(o.x, outer.position.x - 1e-4, outer.end.x + 1e-4, "x at yaw %d" % yaw_deg)
			assert_between(o.z, outer.position.y - 1e-4, outer.end.y + 1e-4, "z at yaw %d" % yaw_deg)
	assert_eq(OrbitMath.CAMERA_MARGIN, 20.0)

func test_geometry_constants_come_from_room() -> void:
	assert_eq(OrbitMath.MAX_TARGET_Y, RoomData.CEILING)
	var cam := DollhouseCamera.new()
	assert_eq(cam.room_bounds, RoomGeometry.bounds())
	cam.free()
