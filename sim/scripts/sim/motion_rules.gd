class_name MotionRules
extends RefCounted
## Reference animal motion. The T10 GPU shader mirrors step() line for line.

const GRAVITY := 9.8
const MAX_SUBSTEP_LEN := 0.02
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

static func _in_x(b: AABB, x: float) -> bool:
	return x >= b.position.x and x <= b.end.x

static func _in_z(b: AABB, z: float) -> bool:
	return z >= b.position.z and z <= b.end.z

## Returns [pos, vel].
static func step(pos: Vector3, vel: Vector3, sp: Dictionary, world: CollisionWorld,
		dt: float, rng: RandomNumberGenerator) -> Array:
	var hopper: bool = sp["motion"] == "hopper"
	var hop_speed: float = sqrt(2.0 * GRAVITY * float(sp["hop_height_m"]))
	var n := maxi(1, ceili(vel.length() * dt / MAX_SUBSTEP_LEN))
	var h := dt / n
	for _i in n:
		if hopper:
			vel.y -= GRAVITY * h
		var p := pos + vel * h
		# Walls and box sides: x against the old z, z against the already-resolved x.
		var bx := world.box_at(Vector3(p.x, pos.y, pos.z))
		if not world.inside_room_xz(Vector2(p.x, pos.z)) \
				or (bx >= 0 and not _in_x(world.boxes[bx], pos.x)):
			vel.x = -vel.x
			p.x = pos.x
		var bz := world.box_at(Vector3(p.x, pos.y, p.z))
		if not world.inside_room_xz(Vector2(p.x, p.z)) \
				or (bz >= 0 and not _in_z(world.boxes[bz], pos.z)):
			vel.z = -vel.z
			p.z = pos.z
		# Vertical: floor, box tops, lid, box undersides.
		var b := world.box_at(p)
		if p.y <= 0.0 or (b >= 0 and pos.y >= world.boxes[b].end.y):
			p.y = 0.0 if p.y <= 0.0 else world.boxes[b].end.y
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
		elif p.y >= world.ceiling or (b >= 0 and pos.y <= world.boxes[b].position.y):
			p.y = minf(p.y, world.ceiling) if p.y >= world.ceiling else world.boxes[b].position.y
			vel.y = -absf(vel.y)
		pos = p
	return [pos, vel]
