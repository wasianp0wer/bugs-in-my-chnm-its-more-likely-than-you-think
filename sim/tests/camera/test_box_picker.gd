extends GutTest

const DESK := AABB(Vector3(14.0, 0.0, 4.0), Vector3(1.5, 0.75, 0.75))
const PILLAR := AABB(Vector3(7.7, 0.0, 5.2), Vector3(0.6, 2.9, 0.6))  # synthetic full-height box

func test_straight_down_hits_floor_when_no_boxes() -> void:
	var hit: Variant = BoxPicker.pick(Vector3(3, 10, 4), Vector3.DOWN, [])
	assert_true(hit is Vector3)
	assert_almost_eq(hit as Vector3, Vector3(3, 0, 4), Vector3.ONE * 1e-5)

func test_straight_down_onto_desk_hits_desktop() -> void:
	var boxes: Array[AABB] = [DESK]
	var hit: Variant = BoxPicker.pick(Vector3(14.5, 10, 4.3), Vector3.DOWN, boxes)
	assert_almost_eq(hit as Vector3, Vector3(14.5, 0.75, 4.3), Vector3.ONE * 1e-5)

func test_nearest_box_wins() -> void:
	# Looking east along z = 5.5 at y = 0.5: the pillar (x 7.7) comes before the desk.
	var far_desk := AABB(Vector3(10.0, 0.0, 5.0), Vector3(1.0, 1.0, 1.0))
	var boxes: Array[AABB] = [far_desk, PILLAR]
	var hit: Variant = BoxPicker.pick(Vector3(2, 0.5, 5.5), Vector3.RIGHT, boxes)
	assert_almost_eq(hit as Vector3, Vector3(7.7, 0.5, 5.5), Vector3.ONE * 1e-5)

func test_floor_before_box_wins() -> void:
	# A slanted ray reaches the floor before it would reach a far-off box.
	var far_box := AABB(Vector3(50, 0, 0), Vector3(1, 1, 1))
	var boxes: Array[AABB] = [far_box]
	var dir := Vector3(1, -1, 0).normalized()
	var hit: Variant = BoxPicker.pick(Vector3(0, 2, 0.5), dir, boxes)
	assert_almost_eq(hit as Vector3, Vector3(2, 0, 0.5), Vector3.ONE * 1e-5)

func test_miss_returns_null() -> void:
	var boxes: Array[AABB] = [DESK]
	assert_null(BoxPicker.pick(Vector3(0, 5, 0), Vector3.UP, boxes))

func test_boxes_behind_the_ray_are_ignored() -> void:
	var boxes: Array[AABB] = [DESK]
	var hit: Variant = BoxPicker.pick(Vector3(14.5, 10, 4.3), Vector3.UP, boxes)
	assert_null(hit)
