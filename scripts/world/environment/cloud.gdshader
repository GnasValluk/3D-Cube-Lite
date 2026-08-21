shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled;

// TẦNG MÂY TRÔI ở độ cao cố định (y=25).
// Plane lớn bám theo người chơi nhưng NOISE lấy mẫu theo tọa độ THẾ GIỚI
// (VERTEX sau MODEL_MATRIX) → hình mây đứng yên so với đất, chỉ trôi nhờ
// gió (TIME * wind). Alpha từ fbm 2 lớp trôi khác hướng/tốc độ.
// Cạnh plane phai mờ theo bán kính để không thấy mép.

uniform float cloud_scale : hint_range(0.0008, 0.02) = 0.0045;
uniform float coverage : hint_range(0.0, 1.0) = 0.52;
uniform float wind_speed : hint_range(0.0, 0.05) = 0.011;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform vec4 cloud_color : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.55, 0.58, 0.68, 1.0);
uniform float alpha_mult : hint_range(0.0, 1.5) = 0.9;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.13 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Đỉnh plane hơi nhấp nhô để mây không hoàn toàn phẳng
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += fbm(wp.xz * cloud_scale * 3.0 + wind_dir * TIME * wind_speed) * 2.2 - 1.1;
}

void fragment() {
	vec2 wuv = UV * 900.0;   // world-metre gần đúng: UV*plane size
	vec2 drift = wind_dir * TIME * wind_speed;
	float n1 = fbm((wuv + drift * 620.0) * cloud_scale);
	float n2 = fbm((wuv * 1.9 - drift * 340.0) * cloud_scale + 41.7);
	float n = n1 * 0.65 + n2 * 0.35;

	// Coverage ngưỡng mềm: n > coverage mới thành mây
	float a = smoothstep(coverage, coverage + 0.24, n);
	// Sáng mặt trên/dày, tối viền mỏng
	float thick = smoothstep(coverage + 0.05, coverage + 0.42, n);
	vec3 col = mix(shade_color.rgb, cloud_color.rgb, thick);

	// Phai theo khoảng cách tới tâm plane (mép vô hình)
	float edge = 1.0 - smoothstep(280.0, 430.0, length(wuv - vec2(450.0)));
	ALBEDO = col;
	ALPHA = a * edge * alpha_mult;
}
