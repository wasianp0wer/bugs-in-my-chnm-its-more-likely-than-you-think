class_name MotionRules
extends RefCounted
## Reference animal motion rules: the source of truth that critter_process.gdshader
## mirrors line for line. Change this first, then the shader.

const GRAVITY := 9.8
const MAX_DT := 0.05
const MAX_STEP := 0.02
const MAX_SUBSTEPS := 32
const HOP_YAW_MAX := deg_to_rad(30.0)

## Half the body length: how far the animal's centre keeps from walls and box sides.
static func clearance(sp: Dictionary) -> float:
	return 0.5 * float(sp.get("body_length_m", 0.0))

static func initial_velocity(sp: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var speed: float = sp["speed_mps"]
	if sp["motion"] == "hopper":
		var a := rng.randf() * TAU
		return Vector3(cos(a), 0.0, sin(a)) * speed
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(a), z, r * sin(a)) * speed

## inside_room_xz for all four corners p +- c: the whole footprint is in the room.
static func _inside_room_c(world: CollisionWorld, p: Vector2, c: float) -> bool:
	return world.inside_room_xz(Vector2(p.x - c, p.y - c)) and world.inside_room_xz(Vector2(p.x + c, p.y - c)) \
			and world.inside_room_xz(Vector2(p.x - c, p.y + c)) and world.inside_room_xz(Vector2(p.x + c, p.y + c))

## Box b grown by c in x and z (not y) contains q. Faces are solid (inclusive).
static func _in_box_c(b: AABB, q: Vector3, c: float) -> bool:
	return q.x >= b.position.x - c and q.x <= b.end.x + c and q.y >= b.position.y and q.y <= b.end.y \
			and q.z >= b.position.z - c and q.z <= b.end.z + c

## True if some box grown by c contains q while the old coordinate is not strictly inside
## that grown box's range on the moving axis (axis 0 = x, 2 = z): the move entered a side.
static func _entered_side(world: CollisionWorld, q: Vector3, old: Vector3, axis: int, c: float) -> bool:
	for b in world.boxes:
		if _in_box_c(b, q, c):
			if old[axis] <= b.position[axis] - c or old[axis] >= b.end[axis] + c:
				return true
	return false

## Returns [pos, vel]. dt is clamped to MAX_DT.
static func step(pos: Vector3, vel: Vector3, sp: Dictionary, world: CollisionWorld,
		dt: float, rng: RandomNumberGenerator) -> Array:
	dt = minf(dt, MAX_DT)
	var hopper: bool = sp["motion"] == "hopper"
	var hop_speed := SpeciesDB.hop_speed(sp)
	var cl := clearance(sp)
	var reach := vel.length() + (GRAVITY * dt if hopper else 0.0)
	var n := clampi(ceili(reach * dt / MAX_STEP), 1, MAX_SUBSTEPS)
	var h := dt / n
	for _i in n:
		if hopper:
			vel.y -= GRAVITY * h
		var p := pos + vel * h
		# Walls and box sides, kept cl away: x against the old z, z against the resolved x.
		if not _inside_room_c(world, Vector2(p.x, pos.z), cl) \
				or _entered_side(world, Vector3(p.x, pos.y, pos.z), pos, 0, cl):
			vel.x = -vel.x
			p.x = pos.x
		if not _inside_room_c(world, Vector2(p.x, p.z), cl) \
				or _entered_side(world, Vector3(p.x, pos.y, p.z), pos, 2, cl):
			vel.z = -vel.z
			p.z = pos.z
		# Vertical: among boxes (footprints grown by cl) containing p, the highest top
		# at/below pos.y (came from above) and the lowest bottom at/above pos.y (from below).
		var top := -1.0
		var bottom := INF
		for bx in world.boxes:
			if _in_box_c(bx, p, cl):
				if pos.y >= bx.end.y:
					top = maxf(top, bx.end.y)
				if pos.y <= bx.position.y:
					bottom = minf(bottom, bx.position.y)
		if p.y <= 0.0 or top >= 0.0:
			p.y = 0.0 if p.y <= 0.0 else top
			if hopper:
				vel.y = hop_speed
				var ang := rng.randf_range(-HOP_YAW_MAX, HOP_YAW_MAX)
				var c := cos(ang)
				var s := sin(ang)
				var vx := vel.x
				vel.x = vx * c - vel.z * s
				vel.z = vx * s + vel.z * c
			else:
				vel.y = absf(vel.y)
		elif p.y >= world.ceiling or bottom < INF:
			p.y = minf(p.y, world.ceiling) if p.y >= world.ceiling else bottom
			vel.y = -absf(vel.y)
		pos = p
	return [pos, vel]
