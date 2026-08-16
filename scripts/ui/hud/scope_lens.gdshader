shader_type canvas_item;

// Ống ngắm súng bắn tỉa M200 — overlay toàn màn hình:
//  - Vignette tối (gần đen) BÊN NGOÀI vòng kính.
//  - Vòng kính trong suốt (lộ camera 3D phía sau), chỉ nhuốm xanh nhẹ.
//  - Viền kim loại quanh kính.
//  - Reticle thập trục mil + vòng tâm tại giữa màn hình.

uniform float lens_radius : hint_range(0.05, 0.95) = 0.42;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv);

	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// Bên ngoài kính: đen kín (ẩn toàn bộ ngoại cảnh).
	if (r > lens_radius) {
		col = vec3(0.01, 0.01, 0.013);
		alpha = 0.98;
	}

	// Viền kim loại quanh kính.
	float metal = smoothstep(lens_radius, lens_radius + 0.010, r) *
				(1.0 - smoothstep(lens_radius + 0.010, lens_radius + 0.028, r));
	if (metal > 0.0) {
		col = mix(col, vec3(0.16, 0.18, 0.21), metal);
		alpha = max(alpha, metal);
	}
	float metal_hi = smoothstep(lens_radius, lens_radius + 0.004, r) *
				(1.0 - smoothstep(lens_radius + 0.004, lens_radius + 0.009, r));
	if (metal_hi > 0.0) {
		col = mix(col, vec3(0.6, 0.63, 0.68), metal_hi);
		alpha = max(alpha, metal_hi);
	}

	// Tint xanh nhẹ bên trong kính (trong suốt).
	if (r <= lens_radius) {
		float inner = smoothstep(lens_radius, lens_radius * 0.95, r);
		col = mix(col, vec3(0.85, 0.92, 1.0) * 0.06, inner * 0.0 + 0.0);
	}

	// Reticle: thập trục + mils + vòng tâm nhỏ (đen).
	if (r <= lens_radius) {
		float half = 0.006;
		float ax = abs(uv.y) <= half ? 1.0 : 0.0;
		float ay = abs(uv.x) <= half ? 1.0 : 0.0;
		float ret = max(ax, ay);
		float dot_r = 0.006;
		float mils = 0.0;
		for (int i = 1; i <= 3; i++) {
			float d = 0.05 * float(i);
			mils = max(mils, smoothstep(dot_r, dot_r - 0.002, distance(uv, vec2(d, 0.0))));
			mils = max(mils, smoothstep(dot_r, dot_r - 0.002, distance(uv, vec2(-d, 0.0))));
			mils = max(mils, smoothstep(dot_r, dot_r - 0.002, distance(uv, vec2(0.0, d))));
			mils = max(mils, smoothstep(dot_r, dot_r - 0.002, distance(uv, vec2(0.0, -d))));
		}
		float ring = smoothstep(0.004, 0.0015, abs(distance(uv, vec2(0.0)) - 0.045));
		ret = max(max(ret, mils), ring);
		col = mix(col, vec3(0.0, 0.0, 0.0), ret);
		alpha = max(alpha, ret);
	}

	COLOR = vec4(col, alpha);
}