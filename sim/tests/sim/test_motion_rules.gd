extends GutTest

const RECTS: Array[Rect2] = RoomData.RECTS
# body_length_m 0 = clearance 0: point animals, so these tests keep their original meaning.
const FLEA := {"motion": "hopper", "speed_mps": 0.5, "hop_height_m": 0.2, "body_length_m": 0.0}
const FLYER := {"motion": "flyer", "speed_mps": 1.5, "hop_height_m": 0.0, "body_length_m": 0.0}
const BEE := {"motion": "flyer", "speed_mps": 3.0, "hop_height_m": 0.0, "body_length_m": 0.0}
const FROG := {"motion": "hopper", "speed_mps": 2.0, "hop_height_m": 0.4, "body_length_m": 0.0}

func _world() -> CollisionWorld:
	var boxes: Array[AABB] = [
		AABB(Vector3(15, 0, 5), Vector3(1.5, 0.75, 0.75)),
		AABB(Vector3(6, 0, 3), Vector3(0.5, 2.9, 0.5)),
		AABB(Vector3(3, 1.2, 1), Vector3(5, 0.03, 5)),
	]
	return CollisionWorld.new(RECTS, boxes, 2.9)

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 12345
	return r

func test_hopper_relaunch_height() -> void:
	var w := _world()
	var rng := _rng()
	var pos := Vector3(8, 2.8, 8)
	var vel := MotionRules.initial_velocity(FLEA, rng)
	var dt := 1.0 / 60.0
	for i in 300:
		var s := MotionRules.step(pos, vel, FLEA, w, dt, rng)
		pos = s[0]; vel = s[1]
	var max_y := 0.0
	for i in 120:
		var s := MotionRules.step(pos, vel, FLEA, w, dt, rng)
		pos = s[0]; vel = s[1]
		max_y = maxf(max_y, pos.y)
	assert_almost_eq(max_y, 0.2, 0.02)

func test_hopper_horizontal_speed_constant() -> void:
	var w := _world()
	var rng := _rng()
	var pos := Vector3(8, 1.0, 8)
	var vel := MotionRules.initial_velocity(FROG, rng)
	for i in 1000:
		var s := MotionRules.step(pos, vel, FROG, w, 1.0 / 30.0, rng)
		pos = s[0]; vel = s[1]
		assert_almost_eq(Vector2(vel.x, vel.z).length(), 2.0, 1e-4)

func test_flyer_speed_constant_and_reflects_off_lid() -> void:
	var w := _world()
	var rng := _rng()
	var pos := Vector3(8, 2.85, 8)
	var vel := Vector3(1.0, 1.0, 0.0).normalized() * 1.5
	var s := MotionRules.step(pos, vel, FLYER, w, 0.1, rng)
	assert_lt(s[1].y, 0.0)
	assert_lte(s[0].y, 2.9 + 1e-5)
	for i in 1000:
		s = MotionRules.step(pos, vel, FLYER, w, 1.0 / 30.0, rng)
		pos = s[0]; vel = s[1]
		assert_almost_eq(vel.length(), 1.5, 1e-4)
		assert_lte(pos.y, 2.9 + 1e-5)
		assert_gte(pos.y, 0.0)

func test_reflect_off_wall() -> void:
	var w := _world()
	var s := MotionRules.step(Vector3(31.46, 1, 5), Vector3(1.5, 0, 0), FLYER, w, 0.2, _rng())
	assert_lt(s[1].x, 0.0)
	assert_lte(s[0].x, 31.5)

func test_notch_wall() -> void:
	var w := _world()
	var s := MotionRules.step(Vector3(1.0, 1, 5.95), Vector3(0, 0, -1.5), FLYER, w, 0.1, _rng())
	assert_gt(s[1].z, 0.0)
	assert_gte(s[0].z, 5.9)

func test_reflect_off_box_side() -> void:
	var w := _world()
	var s := MotionRules.step(Vector3(14.95, 0.4, 5.3), Vector3(1.5, 0, 0), FLYER, w, 0.2, _rng())
	assert_lt(s[1].x, 0.0)
	assert_lt(s[0].x, 15.0)

func test_lands_on_box_top() -> void:
	var w := _world()
	var rng := _rng()
	var pos := Vector3(15.75, 0.9, 5.4)
	var vel := Vector3(0.0, -1.0, 0.0)
	var landed := false
	for i in 60:
		var s := MotionRules.step(pos, vel, FLEA, w, 1.0 / 60.0, rng)
		pos = s[0]; vel = s[1]
		if vel.y > 0.0:
			landed = true
			break
	assert_true(landed)
	assert_almost_eq(pos.y, 0.75, 1e-6)

func test_flyer_bounces_off_box_underside() -> void:
	# floating box so the underside is reachable
	var boxes: Array[AABB] = [AABB(Vector3(5, 1.0, 5), Vector3(1, 0.5, 1))]
	var w2 := CollisionWorld.new(RECTS, boxes, 2.9)
	var s := MotionRules.step(Vector3(5.5, 0.99, 5.5), Vector3(0, 1.0, 0), FLYER, w2, 0.1, _rng())
	assert_lt(s[1].y, 0.0)
	assert_lte(s[0].y, 1.0)

func test_initial_velocity() -> void:
	var rng := _rng()
	for i in 20:
		var h := MotionRules.initial_velocity(FLEA, rng)
		assert_eq(h.y, 0.0)
		assert_almost_eq(Vector2(h.x, h.z).length(), 0.5, 1e-5)
		assert_almost_eq(MotionRules.initial_velocity(BEE, rng).length(), 3.0, 1e-5)

func _random_start(w: CollisionWorld, rng: RandomNumberGenerator) -> Vector3:
	while true:
		var r: Rect2 = RECTS[rng.randi() % RECTS.size()]
		var p := Vector3(rng.randf_range(r.position.x, r.end.x), rng.randf_range(0.0, 2.9),
			rng.randf_range(r.position.y, r.end.y))
		if w.box_at(p) < 0:
			return p
	return Vector3.ZERO

func _strictly_in_box(w: CollisionWorld, p: Vector3) -> bool:
	for b in w.boxes:
		if b.grow(-1e-4).has_point(p):
			return true
	return false

func test_never_escapes_large_dt() -> void:
	var w := _world()
	var rng := _rng()
	var species := [FLEA, FLYER, BEE, FROG]
	for a in 500:
		var sp: Dictionary = species[a % 4]
		var pos := _random_start(w, rng)
		var vel := MotionRules.initial_velocity(sp, rng)
		for i in 200:
			var s := MotionRules.step(pos, vel, sp, w, 0.5, rng)
			pos = s[0]; vel = s[1]
			if not w.inside_room_xz(Vector2(pos.x, pos.z)) or pos.y < 0.0 or pos.y > 2.9 + 1e-5 or _strictly_in_box(w, pos):
				fail_test("animal %d escaped at step %d: %s" % [a, i, pos])
				return
	pass_test("all stayed in bounds")

func test_never_comes_to_rest() -> void:
	var w := _world()
	var rng := _rng()
	var species := [FLEA, FLYER, BEE, FROG]
	for a in 40:
		var sp: Dictionary = species[a % 4]
		var pos := _random_start(w, rng)
		var vel := MotionRules.initial_velocity(sp, rng)
		for i in 3600:
			var s := MotionRules.step(pos, vel, sp, w, 1.0 / 60.0, rng)
			pos = s[0]; vel = s[1]
		assert_gt(vel.length(), 0.0)

func _overlap_world(b_first: bool) -> CollisionWorld:
	var seat := AABB(Vector3(4, 0, 4), Vector3(1, 0.45, 1))
	var desk := AABB(Vector3(4.5, 0, 4), Vector3(1.5, 0.75, 1))
	var boxes: Array[AABB] = []
	boxes.assign([desk, seat] if b_first else [seat, desk])
	var rects: Array[Rect2] = [Rect2(0, 0, 10, 10)]
	return CollisionWorld.new(rects, boxes, 2.9)

func test_overlapping_boxes_side_reflect_any_order() -> void:
	for b_first in [false, true]:
		var w := _overlap_world(b_first)
		var rng := _rng()
		var pos := Vector3(4.499, 0.45, 4.5)
		var vel := Vector3(0.5, 1.98, 0)
		for i in 300:
			var s := MotionRules.step(pos, vel, FLEA, w, 1.0 / 60.0, rng)
			pos = s[0]; vel = s[1]
			assert_true(not _strictly_in_box(w, pos), "inside box (b_first=%s) step %d at %s" % [b_first, i, pos])

func test_overlapping_boxes_land_on_highest_top() -> void:
	for b_first in [false, true]:
		var w := _overlap_world(b_first)
		var s := MotionRules.step(Vector3(4.7, 0.8, 4.5), Vector3(0, -1.0, 0), FLYER, w, 0.05, _rng())
		assert_almost_eq(s[0].y, 0.8 - 0.05, 1e-5)
		s = MotionRules.step(Vector3(4.7, 0.76, 4.5), Vector3(0, -2.0, 0), FLYER, w, 0.05, _rng())
		assert_gte(s[0].y, 0.75 - 1e-5, "landed on desk, not seat (b_first=%s)" % b_first)
		assert_gt(s[1].y, 0.0)

func test_thin_slab_no_tunnel() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 10, 10)]
	var boxes: Array[AABB] = [AABB(Vector3(2, 0.72, 2), Vector3(6, 0.03, 6))]
	var w := CollisionWorld.new(rects, boxes, 2.9)
	for seed_i in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		var pos := Vector3(5, 0.75 + rng.randf() * 0.2, 5)
		var vel := Vector3(0.5, 0, 0)
		var s := MotionRules.step(pos, vel, FLEA, w, 0.5, rng)
		assert_gte(s[0].y, 0.75 - 1e-5, "tunneled, seed %d" % seed_i)

func test_step_constants() -> void:
	assert_eq(MotionRules.MAX_DT, 0.05)
	assert_eq(MotionRules.MAX_STEP, 0.02)
	assert_eq(MotionRules.MAX_SUBSTEPS, 32)

func test_clearance_is_half_body_length() -> void:
	assert_almost_eq(MotionRules.clearance(SpeciesDB.get_species("deer")), 0.9, 1e-6)
	assert_eq(MotionRules.clearance({"motion": "flyer", "speed_mps": 1.0}), 0.0, "defaults to 0")

func _deer_world() -> CollisionWorld:
	var boxes: Array[AABB] = []
	boxes.append_array(_world().boxes)
	boxes.append(AABB(Vector3(24, 0, 12), Vector3(2, 0.45, 0.9)))  # sofa
	return CollisionWorld.new(RoomData.RECTS, boxes, RoomData.CEILING)

## All four corners p.xz +- c inside the room.
func _corners_inside(w: CollisionWorld, p: Vector3, c: float) -> bool:
	for dx in [-c, c]:
		for dz in [-c, c]:
			if not w.inside_room_xz(Vector2(p.x + dx, p.z + dz)):
				return false
	return true

## Centre strictly inside some box grown by c in x/z (not y).
func _strictly_in_grown_box(w: CollisionWorld, p: Vector3, c: float) -> int:
	for i in w.boxes.size():
		var b := w.boxes[i]
		if p.x > b.position.x - c + 1e-4 and p.x < b.end.x + c - 1e-4 \
				and p.y > b.position.y + 1e-4 and p.y < b.end.y - 1e-4 \
				and p.z > b.position.z - c + 1e-4 and p.z < b.end.z + c - 1e-4:
			return i
	return -1

func _deer_start(w: CollisionWorld, c: float, rng: RandomNumberGenerator) -> Vector3:
	while true:
		var r: Rect2 = RoomData.RECTS[rng.randi() % RoomData.RECTS.size()]
		var p := Vector3(rng.randf_range(r.position.x, r.end.x), RoomGeometry.SPAWN_Y,
			rng.randf_range(r.position.y, r.end.y))
		if _corners_inside(w, p, c) and _strictly_in_grown_box(w, p, c) < 0:
			return p
	return Vector3.ZERO

## A deer (1.8 m, c = 0.9) keeps its whole footprint in the room and never has its
## centre within c of a box side, over 60 s at 60 fps and with huge frame steps.
func test_deer_keeps_clearance_from_walls_and_boxes() -> void:
	var w := _deer_world()
	var deer := SpeciesDB.get_species("deer")
	var c := MotionRules.clearance(deer)
	var rng := _rng()
	for a in 12:
		var dt := 1.0 / 60.0 if a % 3 != 0 else 0.5
		var pos := _deer_start(w, c, rng)
		var vel := MotionRules.initial_velocity(deer, rng)
		for i in 3600:
			var s := MotionRules.step(pos, vel, deer, w, dt, rng)
			pos = s[0]; vel = s[1]
			if not _corners_inside(w, pos, c - 1e-3):
				fail_test("deer %d within clearance of a wall at step %d: %s" % [a, i, pos])
				return
			var bi := _strictly_in_grown_box(w, pos, c)
			if bi >= 0:
				fail_test("deer %d within clearance of box %d at step %d: %s" % [a, bi, i, pos])
				return
	pass_test("deer kept clearance")

## A deer whose footprint overlaps a box top lands on it (stands on the sofa edge).
func test_deer_lands_on_box_edge_within_clearance() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 10, 10)]
	var boxes: Array[AABB] = [AABB(Vector3(4, 0, 4), Vector3(2, 0.45, 1))]
	var w := CollisionWorld.new(rects, boxes, 2.9)
	var deer := SpeciesDB.get_species("deer")
	# Centre 0.5 m beyond the sofa's x end: outside the box, inside its grown footprint.
	var s := MotionRules.step(Vector3(6.5, 0.455, 4.5), Vector3(0, -1.0, 0), deer, w, 0.01, _rng())  # one substep
	assert_almost_eq(s[0].y, 0.45, 1e-5, "landed on the sofa top")
	assert_gt(s[1].y, 0.0)

## Every real species entry (flyers have no hop_height_m) steps through the reference.
func test_every_real_species_steps() -> void:
	var w := _deer_world()
	var rng := _rng()
	for sp in SpeciesDB.load_all():
		var c := MotionRules.clearance(sp)
		var pos := _deer_start(w, c, rng)
		var vel := MotionRules.initial_velocity(sp, rng)
		for i in 120:
			var s := MotionRules.step(pos, vel, sp, w, 1.0 / 60.0, rng)
			pos = s[0]; vel = s[1]
		assert_true(_corners_inside(w, pos, c - 1e-3), "%s in room" % sp["id"])
		assert_gt(vel.length(), 0.0, sp["id"])

## One gravity constant, in MotionRules; SpeciesDB.hop_speed uses it.
func test_single_gravity_constant() -> void:
	assert_false((load("res://scripts/species/species_db.gd") as Script).get_script_constant_map().has("GRAVITY"))
	var deer := SpeciesDB.get_species("deer")
	assert_almost_eq(SpeciesDB.hop_speed(deer), sqrt(2.0 * MotionRules.GRAVITY * 1.2), 1e-6)
