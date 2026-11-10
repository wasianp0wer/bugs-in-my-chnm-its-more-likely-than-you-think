class_name MotionRules
extends RefCounted
## Reference animal motion rules: the source of truth that critter_process.gdshader
## mirrors line for line. Change this first, then the shader.

const GRAVITY := 9.8
const MAX_DT := 0.05
const MAX_STEP := 0.02
const MAX_SUBSTEPS := 32
const HOP_YAW_MAX := deg_to_rad(30.0)

static func initial_velocity(sp: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var speed: float = sp["speed_mps"]
	if sp["motion"] == "hopper":
		var a := rng.randf() * TAU
		return Vector3(cos(a), 0.0, sin(a)) * speed
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(a), z, r * sin(a)) * speed

## True if some box contains q while the old coordinate is not strictly inside
## that box's range on the moving axis (axis 0 = x, 2 = z): the move entered a box side.
static func _entered_side(world: CollisionWorld, q: Vector3, old: Vector3, axis: int) -> bool:
	for b in world.boxes:
		if q.x >= b.position.x and q.x <= b.end.x and q.y >= b.position.y and q.y <= b.end.y \
				and q.z >= b.position.z and q.z <= b.end.z:
			if old[axis] <= b.position[axis] or old[axis] >= b.end[axis]:
				return true
	return false

## Returns [pos, vel]. dt is clamped to MAX_DT.
static func step(pos: Vector3, vel: Vector3, sp: Dictionary, world: CollisionWorld,
		dt: float, rng: RandomNumberGenerator) -> Array:
	dt = minf(dt, MAX_DT)
	var hopper: bool = sp["motion"] == "hopper"
	var hop_speed: float = sqrt(2.0 * GRAVITY * float(sp["hop_height_m"]))
	var reach := vel.length() + (GRAVITY * dt if hopper else 0.0)
	var n := clampi(ceili(reach * dt / MAX_STEP), 1, MAX_SUBSTEPS)
	var h := dt / n
	for _i in n:
		if hopper:
			vel.y -= GRAVITY * h
		var p := pos + vel * h
		# Walls and box sides: x against the old z, z against the already-resolved x.
		if not world.inside_room_xz(Vector2(p.x, pos.z)) \
				or _entered_side(world, Vector3(p.x, pos.y, pos.z), pos, 0):
			vel.x = -vel.x
			p.x = pos.x
		if not world.inside_room_xz(Vector2(p.x, p.z)) \
				or _entered_side(world, Vector3(p.x, pos.y, p.z), pos, 2):
			vel.z = -vel.z
			p.z = pos.z
		# Vertical: among boxes containing p, the highest top at/below pos.y (came from
		# above) and the lowest bottom at/above pos.y (came from below).
		var top := -1.0
		var bottom := INF
		for bx in world.boxes:
			if p.x >= bx.position.x and p.x <= bx.end.x and p.y >= bx.position.y and p.y <= bx.end.y \
					and p.z >= bx.position.z and p.z <= bx.end.z:
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
