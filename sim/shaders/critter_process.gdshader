// GPU mirror of res://scripts/sim/motion_rules.gd (the source of truth).
// Keep the branch structure of process() parallel to MotionRules.step() so the two
// can be compared side by side; change the GDScript first, then this file.
//
// State: position in TRANSFORM[3].xyz, velocity in VELOCITY, landing counter in CUSTOM.x
// (a per-particle random stream for the hop yaw). Integration is manual
// (disable_velocity) so sub-stepping and collision fully own the position.
shader_type particles;
render_mode disable_velocity, disable_force;

const float GRAVITY = 9.8;
const float MAX_DT = 0.05;
const float MAX_STEP = 0.02;
const int MAX_SUBSTEPS = 32;
const float HOP_YAW_MAX = 0.5235987756; // deg_to_rad(30)
const float SPAWN_Y = 2.8;
const int SPAWN_TRIES = 16;
const float NO_BOTTOM = 1.0e30;         // stands in for INF

// World (CollisionWorld.to_shader_params(), plus area prefix sums for spawning).
uniform vec4 room_rects[8];             // (x0, z0, x1, z1)
uniform int room_rect_count = 0;
uniform float rect_cdf[8];              // normalised area prefix sums of room_rects
uniform vec3 box_min[128];
uniform vec3 box_max[128];
uniform int box_count = 0;
uniform float ceiling = 2.9;
// Species.
uniform bool is_hopper = false;
uniform float speed = 1.0;              // m/s
uniform float hop_speed = 0.0;          // vertical launch speed on landing, m/s
uniform float body_length = 0.01;       // uniform scale of the 1 m baked mesh
uniform float clearance = 0.0;          // MotionRules.clearance: half the body length, m
uniform int seed = 0;

float hash01(uint x) {
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return float(x) / 4294967295.0;
}

uint particle_seed(uint index, uint random_seed) {
	return index * 747796405u + random_seed * 2891336453u + uint(seed) * 3266489917u;
}

// CollisionWorld.inside_room_xz: boundaries count as inside.
bool inside_room_xz(vec2 p) {
	for (int i = 0; i < room_rect_count; i++) {
		vec4 r = room_rects[i];
		if (p.x >= r.x && p.x <= r.z && p.y >= r.y && p.y <= r.w) {
			return true;
		}
	}
	return false;
}

// MotionRules._inside_room_c: all four corners p +- c are in the room.
bool inside_room_c(vec2 p, float c) {
	return inside_room_xz(vec2(p.x - c, p.y - c)) && inside_room_xz(vec2(p.x + c, p.y - c))
			&& inside_room_xz(vec2(p.x - c, p.y + c)) && inside_room_xz(vec2(p.x + c, p.y + c));
}

// MotionRules._in_box_c: box b grown by c in x and z (not y) contains q. Faces are solid.
bool in_box_c(vec3 q, int b, float c) {
	vec3 g = vec3(c, 0.0, c);
	return all(greaterThanEqual(q, box_min[b] - g)) && all(lessThanEqual(q, box_max[b] + g));
}

// MotionRules._entered_side, boxes grown by c. axis 0 = x, 2 = z.
bool entered_side(vec3 q, vec3 old, int axis, float c) {
	for (int b = 0; b < box_count; b++) {
		if (in_box_c(q, b, c)) {
			float o = axis == 0 ? old.x : old.z;
			float lo = axis == 0 ? box_min[b].x : box_min[b].z;
			float hi = axis == 0 ? box_max[b].x : box_max[b].z;
			if (o <= lo - c || o >= hi + c) {
				return true;
			}
		}
	}
	return false;
}

// RoomGeometry._inside_any: some box grown by c in x/z contains q.
bool in_any_box(vec3 q, float c) {
	for (int b = 0; b < box_count; b++) {
		if (in_box_c(q, b, c)) {
			return true;
		}
	}
	return false;
}

// Area-weighted point in the room (RoomGeometry.random_spawn_xz), re-sampled up to
// SPAWN_TRIES times while the footprint xz +- cl leaves the room or the spawn point
// (x, SPAWN_Y, z) is inside a box grown by cl in x/z. Spawning above a low box is fine:
// the animal rains down onto the desk or sofa. (The GDScript re-samples until it
// succeeds; here, if every try fails, the last point is clamped cl inside its rect so
// the footprint at least starts within the walls.)
vec2 spawn_xz(uint s) {
	float cl = clearance;
	vec2 xz = vec2(0.0);
	for (int t = 0; t < SPAWN_TRIES; t++) {
		uint k = s + uint(t) * 3u;
		float u = hash01(k);
		int ri = max(room_rect_count - 1, 0);
		for (int i = 0; i < room_rect_count; i++) {
			if (u < rect_cdf[i]) {
				ri = i;
				break;
			}
		}
		vec4 r = room_rects[ri];
		xz = vec2(mix(r.x, r.z, hash01(k + 1u)), mix(r.y, r.w, hash01(k + 2u)));
		if (inside_room_c(xz, cl) && !in_any_box(vec3(xz.x, SPAWN_Y, xz.y), cl)) {
			return xz;
		}
		if (t == SPAWN_TRIES - 1) {
			xz = clamp(xz, r.xy + cl, r.zw - cl);
		}
	}
	return xz;
}

// Basis = R_y(yaw) * uniform scale; the mesh faces +Z. Keeps the last heading when
// the horizontal velocity is zero (e.g. a flyer moving straight up).
mat4 oriented(vec3 p, vec3 v, vec3 last_fwd) {
	vec2 d = v.xz;
	if (dot(d, d) < 1e-12) {
		d = last_fwd.xz;
		if (dot(d, d) < 1e-12) {
			d = vec2(0.0, 1.0);
		}
	}
	d = normalize(d);           // (sin yaw, cos yaw)
	float s = d.x * body_length;
	float c = d.y * body_length;
	return mat4(
		vec4(c, 0.0, -s, 0.0),
		vec4(0.0, body_length, 0.0, 0.0),
		vec4(s, 0.0, c, 0.0),
		vec4(p, 1.0));
}

void start() {
	uint s = particle_seed(INDEX, RANDOM_SEED);
	vec2 xz = spawn_xz(s);
	vec3 p = vec3(xz.x, SPAWN_Y, xz.y);
	// MotionRules.initial_velocity.
	vec3 v;
	if (is_hopper) {
		float a = hash01(s + 100u) * TAU;
		v = vec3(cos(a), 0.0, sin(a)) * speed;
		// Phase jitter so a swarm does not land and hop in lock-step.
		v.y = -hash01(s + 101u) * hop_speed;
	} else {
		float z = mix(-1.0, 1.0, hash01(s + 100u));
		float a = hash01(s + 101u) * TAU;
		float r = sqrt(1.0 - z * z);
		v = vec3(r * cos(a), z, r * sin(a)) * speed;
	}
	VELOCITY = v;
	CUSTOM = vec4(0.0);
	TRANSFORM = oriented(p, v, vec3(0.0, 0.0, 1.0));
}

// MotionRules.step, one frame.
void process() {
	float dt = min(DELTA, MAX_DT);
	vec3 pos = TRANSFORM[3].xyz;
	vec3 vel = VELOCITY;
	float landings = CUSTOM.x;
	uint s = particle_seed(INDEX, RANDOM_SEED) + 7919u;
	float reach = length(vel) + (is_hopper ? GRAVITY * dt : 0.0);
	int n = clamp(int(ceil(reach * dt / MAX_STEP)), 1, MAX_SUBSTEPS);
	float h = dt / float(n);
	float cl = clearance;
	for (int i = 0; i < n; i++) {
		if (is_hopper) {
			vel.y -= GRAVITY * h;
		}
		vec3 p = pos + vel * h;
		// Walls and box sides, kept cl away: x against the old z, z against the resolved x.
		if (!inside_room_c(vec2(p.x, pos.z), cl)
				|| entered_side(vec3(p.x, pos.y, pos.z), pos, 0, cl)) {
			vel.x = -vel.x;
			p.x = pos.x;
		}
		if (!inside_room_c(vec2(p.x, p.z), cl)
				|| entered_side(vec3(p.x, pos.y, p.z), pos, 2, cl)) {
			vel.z = -vel.z;
			p.z = pos.z;
		}
		// Vertical: among boxes (footprints grown by cl) containing p, the highest top
		// at/below pos.y (came from above) and the lowest bottom at/above pos.y (from below).
		float top = -1.0;
		float bottom = NO_BOTTOM;
		for (int b = 0; b < box_count; b++) {
			if (in_box_c(p, b, cl)) {
				if (pos.y >= box_max[b].y) {
					top = max(top, box_max[b].y);
				}
				if (pos.y <= box_min[b].y) {
					bottom = min(bottom, box_min[b].y);
				}
			}
		}
		if (p.y <= 0.0 || top >= 0.0) {
			p.y = p.y <= 0.0 ? 0.0 : top;
			if (is_hopper) {
				vel.y = hop_speed;
				float ang = mix(-HOP_YAW_MAX, HOP_YAW_MAX, hash01(s + uint(landings) * 2654435761u));
				landings += 1.0;
				float c = cos(ang);
				float sn = sin(ang);
				float vx = vel.x;
				vel.x = vx * c - vel.z * sn;
				vel.z = vx * sn + vel.z * c;
			} else {
				vel.y = abs(vel.y);
			}
		} else if (p.y >= ceiling || bottom < NO_BOTTOM) {
			p.y = p.y >= ceiling ? min(p.y, ceiling) : bottom;
			vel.y = -abs(vel.y);
		}
		pos = p;
	}
	VELOCITY = vel;
	CUSTOM.x = landings;
	TRANSFORM = oriented(pos, vel, TRANSFORM[2].xyz);
}
