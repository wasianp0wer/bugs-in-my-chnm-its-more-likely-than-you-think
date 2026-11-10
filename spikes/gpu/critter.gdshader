// Spike: GPU particle process shader for bouncing critters.
// Integration is done manually (render_mode disable_velocity) so that
// sub-stepping and reflection have full control of the position.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform vec4 room_rects[8];        // (x0, z0, x1, z1); spike uses rect 0 only
uniform int room_rect_count = 1;
uniform vec3 box_min[128];
uniform vec3 box_max[128];
uniform int box_count = 0;
uniform float ceiling = 2.9;
uniform float gravity = 9.8;
uniform float speed = 1.5;         // horizontal speed, m/s
uniform float hop_speed = 3.0;     // vertical launch speed on landing, m/s
uniform float body_length = 0.08;  // uniform scale applied to a 1 m mesh
uniform float spawn_y = 2.8;
uniform float max_step = 0.02;     // max distance per sub-step, m
uniform int max_substeps = 16;
uniform int force_substeps = 0;    // >0: always use this many sub-steps (perf test)
uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.1, 1.0);

float hash01(uint x) {
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return float(x) / 4294967295.0;
}

mat4 oriented(vec3 p, vec3 v) {
	// Yaw from horizontal velocity; mesh faces +Z. Basis = R_y(yaw) * scale.
	float yaw = atan(v.x, v.z);
	float c = cos(yaw) * body_length;
	float s = sin(yaw) * body_length;
	return mat4(
		vec4(c, 0.0, -s, 0.0),
		vec4(0.0, body_length, 0.0, 0.0),
		vec4(s, 0.0, c, 0.0),
		vec4(p, 1.0));
}

void start() {
	uint seed = INDEX * 747796405u + RANDOM_SEED * 2891336453u;
	vec4 r = room_rects[0];
	vec3 p = vec3(mix(r.x, r.z, hash01(seed)), spawn_y, mix(r.y, r.w, hash01(seed + 1u)));
	float a = hash01(seed + 2u) * TAU;
	VELOCITY = vec3(sin(a) * speed, 0.0, cos(a) * speed);
	TRANSFORM = oriented(p, VELOCITY);
	COLOR = tint;
}

void process() {
	vec3 p = TRANSFORM[3].xyz;
	vec3 v = VELOCITY;
	int n = force_substeps > 0 ? force_substeps
		: clamp(int(ceil(length(v) * DELTA / max_step)), 1, max_substeps);
	float h = DELTA / float(n);
	vec4 r = room_rects[0];
	for (int i = 0; i < n; i++) {
		v.y -= gravity * h;
		vec3 q = p + v * h;
		if (q.y <= 0.0) { q.y = 0.0; v.y = hop_speed; }
		if (q.y >= ceiling) { q.y = ceiling; v.y = -abs(v.y); }
		if (q.x < r.x) { q.x = 2.0 * r.x - q.x; v.x = abs(v.x); }
		if (q.x > r.z) { q.x = 2.0 * r.z - q.x; v.x = -abs(v.x); }
		if (q.z < r.y) { q.z = 2.0 * r.y - q.z; v.z = abs(v.z); }
		if (q.z > r.w) { q.z = 2.0 * r.w - q.z; v.z = -abs(v.z); }
		for (int b = 0; b < box_count; b++) {
			vec3 lo = box_min[b];
			vec3 hi = box_max[b];
			if (all(greaterThan(q, lo)) && all(lessThan(q, hi))) {
				if (p.y >= hi.y) { q.y = hi.y; v.y = hop_speed; }       // landed on top
				else if (p.y <= lo.y) { q.y = lo.y; v.y = -abs(v.y); } // hit underside
				else if (p.x <= lo.x || p.x >= hi.x) { q.x = p.x; v.x = -v.x; }
				else { q.z = p.z; v.z = -v.z; }
			}
		}
		p = q;
	}
	VELOCITY = v;
	TRANSFORM = oriented(p, v);
}
