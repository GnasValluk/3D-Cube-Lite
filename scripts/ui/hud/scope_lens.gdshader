shader_type canvas_item;

// Godot 4.7: SCREEN_TEXTURE không còn mặc định — phải khai báo uniform rõ.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Ống ngắm súng bắn tỉa M200 — overlay toàn màn hình:
//  - Vòng kính TRÒN (chuẩn hoá theo aspect, không méo theo tỉ lệ màn hình),
//    trong suốt để lộ camera 3D phía sau, chỉ nhuốm xanh cực nhẹ.
//  - BÊN NGOÀI kính: nền bị LÀM MỜ (blur) + tối dần ra mép thay vì đen kín.
//  - Viền kim loại quanh kính.
//  - Reticle thập trục mil MẢNH + vòng tâm; khi đang khóa địch (target_locked
//    = 1) reticle nhấp nháy đỏ theo thời gian.

uniform float lens_radius : hint_range(0.05, 0.95) = 0.42;
uniform float target_locked : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Chuẩn hoá theo tỉ lệ màn hình để vòng kính tròn thật sự (aspect-correct).
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float r = length(uv);

	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// Bên ngoài kính: blur nền 3D, mờ dần ra mép + tối (vignette).
	if (r > lens_radius) {
		float blur_t = clamp((r - lens_radius) / (0.5 - lens_radius), 0.0, 1.0);
		float blur_amp = mix(0.0025, 0.02, blur_t);
		vec3 bg = vec3(0.0);
		float wsum = 0.0;
		for (int i = -2; i <= 2; i++) {
			for (int j = -2; j <= 2; j++) {
				float w = exp(-float(i * i + j * j) * 0.55);
				bg += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(i), float(j)) * blur_amp).rgb * w;
				wsum += w;
			}
		}
		bg /= max(wsum, 0.0001);
		float dark = mix(0.85, 0.30, blur_t * blur_t);
		col = bg * dark;
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

	// Bên trong kính: trong suốt (alpha 0) → lộ thế giới 3D, chỉ nhuốm xanh cực nhẹ.
	if (r <= lens_radius) {
		col = mix(col, vec3(0.78, 0.86, 1.0) * 0.04, 1.0);
	}

	// Reticle MẢNH: thập trục + mils + vòng tâm. Nếu khóa địch → nhấp nháy đỏ.
	if (r <= lens_radius) {
		float half = 0.0012;
		float ax = abs(uv.y) <= half ? 1.0 : 0.0;
		float ay = abs(uv.x) <= half ? 1.0 : 0.0;
		float ret = max(ax, ay);
		float dot_r = 0.0022;
		float mils = 0.0;
		for (int i = 1; i <= 3; i++) {
			float d = 0.05 * float(i);
			mils = max(mils, smoothstep(dot_r, dot_r - 0.0006, distance(uv, vec2(d, 0.0))));
			mils = max(mils, smoothstep(dot_r, dot_r - 0.0006, distance(uv, vec2(-d, 0.0))));
			mils = max(mils, smoothstep(dot_r, dot_r - 0.0006, distance(uv, vec2(0.0, d))));
			mils = max(mils, smoothstep(dot_r, dot_r - 0.0006, distance(uv, vec2(0.0, -d))));
		}
		float ring = smoothstep(0.0014, 0.0006, abs(distance(uv, vec2(0.0)) - 0.040));
		ret = max(max(ret, mils), ring);
		vec3 retcol = vec3(0.0, 0.0, 0.0);
		if (target_locked > 0.5) {
			float pulse = 0.5 + 0.5 * sin(TIME * 12.0);
			retcol = vec3(1.0, 0.06, 0.0) * (0.45 + 0.55 * pulse);
		}
		col = mix(col, retcol, ret);
		alpha = max(alpha, ret);
	}

	COLOR = vec4(col, alpha);
}
