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

func test_zoom_in_close_enough_for_flea() -> void:
	var m := _make()
	m.zoom(1000)
	var half_fov := deg_to_rad(50.0) / 2.0
	var px := 0.0025 / (2.0 * m.distance * tan(half_fov)) * 900.0
	assert_gte(px, 20.0)
