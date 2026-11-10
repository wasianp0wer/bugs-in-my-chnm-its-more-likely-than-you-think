extends GutTest

const RECTS: Array[Rect2] = RoomData.RECTS

func _world() -> CollisionWorld:
	var boxes: Array[AABB] = [AABB(Vector3(15, 0, 5), Vector3(1.5, 0.75, 0.75))]
	return CollisionWorld.new(RECTS, boxes, 2.9)

func test_inside_room_xz_rects_and_boundary() -> void:
	var w := _world()
	assert_true(w.inside_room_xz(Vector2(1.0, 8.0)))
	assert_true(w.inside_room_xz(Vector2(25.0, 12.0)))
	assert_true(w.inside_room_xz(Vector2(0.0, 5.9)), "boundary counts as inside")
	assert_true(w.inside_room_xz(Vector2(20.3, 12.0)), "left edge of a rect counts as inside")
	assert_false(w.inside_room_xz(Vector2(1.0, 5.0)), "notch is outside")
	assert_false(w.inside_room_xz(Vector2(32.0, 8.0)))

func test_box_at() -> void:
	var w := _world()
	assert_eq(w.box_at(Vector3(15.5, 0.5, 5.5)), 0)
	assert_eq(w.box_at(Vector3(15.0, 0.75, 5.0)), 0, "faces are solid")
	assert_eq(w.box_at(Vector3(15.5, 0.9, 5.5)), -1)
	assert_eq(w.box_at(Vector3(10.0, 0.5, 5.5)), -1)

func test_shader_params_padded_and_packed() -> void:
	var w := _world()
	var p := w.to_shader_params()
	assert_eq(p["room_rect_count"], 4)
	assert_eq(p["box_count"], 1)
	assert_eq(p["ceiling"], 2.9)
	assert_eq(p["room_rects"].size(), 8)
	assert_eq(p["box_min"].size(), 128)
	assert_eq(p["box_max"].size(), 128)
	var r0: Vector4 = p["room_rects"][0]
	assert_almost_eq(r0.x, 0.0, 1e-6)
	assert_almost_eq(r0.y, 5.9, 1e-6)
	assert_almost_eq(r0.z, 2.9, 1e-6)
	assert_almost_eq(r0.w, 10.7, 1e-5)
	assert_eq(p["box_min"][0], Vector3(15, 0, 5))
	assert_eq(p["box_max"][0], Vector3(16.5, 0.75, 5.75))
	assert_eq(p["room_rects"][7], Vector4.ZERO)
	assert_eq(p["box_min"][127], Vector3.ZERO)

## Over the shader's limits (MAX_RECTS / MAX_BOXES): push_error, then clamp, even in
## release builds where assert() is stripped.
func test_too_many_rects_and_boxes_error_and_clamp() -> void:
	var rects: Array[Rect2] = []
	for i in CollisionWorld.MAX_RECTS + 1:
		rects.append(Rect2(i, 0, 1, 1))
	var boxes: Array[AABB] = []
	for i in CollisionWorld.MAX_BOXES + 2:
		boxes.append(AABB(Vector3(i, 0, 0), Vector3.ONE))
	var w := CollisionWorld.new(rects, boxes, 2.9)
	assert_push_error_count(2, "one error each for rects and boxes")
	assert_eq(w.rects.size(), CollisionWorld.MAX_RECTS)
	assert_eq(w.boxes.size(), CollisionWorld.MAX_BOXES)
	assert_eq(w.boxes[CollisionWorld.MAX_BOXES - 1], boxes[CollisionWorld.MAX_BOXES - 1], "keeps the first ones")
	var p := w.to_shader_params()
	assert_eq(p["box_count"], CollisionWorld.MAX_BOXES)
	assert_eq(p["room_rect_count"], CollisionWorld.MAX_RECTS)
	assert_eq(boxes.size(), CollisionWorld.MAX_BOXES + 2, "caller's array untouched")
