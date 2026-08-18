shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Mây thể tích thật — raymarch 3D noise trong "lớp trời" (slab) quanh player.
// TẦNG MÂY (overcast deck) như mưa: phủ rộng, đáy khá phẳng, thân dày, đỉnh
// hơi u cục — khác cumulus cũ (cụm trắng bồng rời rạc). Đặt cao hơn hẳn
// (cloud_min_y/max_y ~ 100–210) để phủ trên núi. Trôi bay theo gió (TIME),
// sáng/tối theo mặt trời & trăng, đẩy từ môi trường mỗi frame.
// Để ra "tầng", trục y của noise được nén mạnh trong sample_cloud:
// mật độ thay đổi chủ yếu theo x/z → mảng mây phủ liền, có lỗ thưa tự nhiên.

uniform sampler3D cloud_noise_texture;
uniform float cloud_scale : hint_range(0.001, 0.05) = 0.0032;
uniform float cloud_threshold : hint_range(0.0, 1.0) = 0.62;
uniform int max_steps : hint_range(16, 200) = 128;
uniform float step_size : hint_range(0.1, 6.0) = 1.1;

// Trôi bay: hướng + tốc độ gió (đẩy từ TIME trong shader).
uniform vec3 cloud_movement_direction = vec3(0.5, 0.0, 0.8);
uniform float cloud_movement_speed : hint_range(0.0, 80.0) = 3.5;

uniform sampler3D detail_noise_texture;
uniform float detail_scatter : hint_range(0.0, 8.0) = 3.4;
uniform float detail_intensity : hint_range(0.0, 1.0) = 0.35;

uniform vec3 light_direction = vec3(0.3, 0.8, 0.4);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 0.98);
uniform float cloud_brightness : hint_range(0.0, 4.0) = 1.2;
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_alpha : hint_range(1.0, 300.0) = 20.0;

// Lớp trời: độ cao đáy/đỉnh mây (toạ độ world y) — cao hơn núi/đồi.
uniform float cloud_min_y = 100.0;
uniform float cloud_max_y = 210.0;
// Phai dần theo khoảng cách (khí quyển) để mây xa hoà vào bầu trời.
uniform float distance_fade : hint_range(0.0001, 0.01) = 0.0013;

// Lấy mật độ mây tại điểm (model space — box luôn quanh player).
float sample_cloud(vec3 p) {
	vec3 move = cloud_movement_direction * cloud_movement_speed * TIME;
	// Nén trục y: biến thiên hầu như theo x/z → TẦNG mây phủ rộng, không cụm.
	vec3 p_main = vec3(p.x, p.y * 0.16, p.z) * cloud_scale + move;
	vec3 p_detail = p * cloud_scale * detail_scatter + move * 1.7 + vec3(13.7, 0.0, 29.3);
	float main = texture(cloud_noise_texture, p_main).r;
	float det = texture(detail_noise_texture, p_detail).r;
	return mix(main, det, detail_intensity);
}

// Giao của tia với lớp trời (2 mặt phẳng ngang) — trả (t_near, t_far) hoặc -1.
vec2 ray_slab(vec3 ro, vec3 rd) {
	if (abs(rd.y) < 1e-6) {
		return (ro.y > cloud_min_y && ro.y < cloud_max_y)
			? vec2(0.0, 100000.0)
			: vec2(-1.0, -1.0);
	}
	float t1 = (cloud_min_y - ro.y) / rd.y;
	float t2 = (cloud_max_y - ro.y) / rd.y;
	float t_near = min(t1, t2);
	float t_far = max(t1, t2);
	t_near = max(t_near, 0.0);
	if (t_far <= t_near) {
		return vec2(-1.0, -1.0);
	}
	return vec2(t_near, t_far);
}

float raymarch_clouds(vec3 ro, vec3 rd, vec2 inter) {
	float total = 0.0;
	float shadow_acc = 0.0;
	float t = inter.x;
	float slab = max(cloud_max_y - cloud_min_y, 0.001);
	for (int i = 0; i < max_steps; i++) {
		if (t >= inter.y) break;
		vec3 p = ro + t * rd;
		float h = clamp((p.y - cloud_min_y) / slab, 0.0, 1.0);
		float d = sample_cloud(p);

		// Dáng TẦNG mây: đáy mềm, thân dày, đỉnh hơi u cục (giữ một phần đỉnh).
		// profile yếu (.55) → tổng mật độ khúc xạ dọc tia thấp → có lỗ thưa.
		float profile = smoothstep(0.08, 0.45, h) * (1.0 - smoothstep(0.58, 1.0, h) * 0.5) * 0.55;
		float dens = smoothstep(cloud_threshold, cloud_threshold + 0.12, d) * profile;

		// Tự đổ bóng: mây phía trước càng dày thì phía sau càng tối.
		dens *= 1.0 - shadow_intensity * shadow_acc;

		// Khí quyển: phai dần mây theo khoảng cách để hoà vào chân trời.
		dens *= exp(-(t - inter.x) * distance_fade);

		total += dens * step_size;
		shadow_acc = mix(shadow_acc, total, 0.10);
		t += step_size;
	}
	return total;
}

void fragment() {
	vec3 ro_world = INV_VIEW_MATRIX[3].xyz;
	vec4 clipPos = vec4((FRAGCOORD.xy / VIEWPORT_SIZE.xy) * 2.0 - 1.0, FRAGCOORD.z, 1.0);
	vec4 viewPos = INV_PROJECTION_MATRIX * clipPos;
	vec3 rd_world = normalize((INV_VIEW_MATRIX * vec4(viewPos.xyz / viewPos.w, 0.0)).xyz);

	// Đưa về model space (box không quay, chỉ tịnh tiến theo player).
	vec3 ro_model = (inverse(MODEL_MATRIX) * vec4(ro_world, 1.0)).xyz;
	vec3 rd_model = normalize((inverse(MODEL_MATRIX) * vec4(rd_world, 0.0)).xyz);

	// Giao với slab — dùng world y của camera thật, không phải model.
	vec2 inter = ray_slab(ro_world, rd_world);
	if (inter.x < 0.0 || inter.x >= inter.y) {
		discard;
	}

	float density = raymarch_clouds(ro_model, rd_model, inter);
	if (density <= 0.002) {
		discard;
	}

	// Chiếu sáng mây: đáy tối, đỉnh sáng; ban đêm tối dần theo light_direction.y.
	vec3 mid = ro_world + rd_world * ((inter.x + inter.y) * 0.5);
	float h_mid = clamp((mid.y - cloud_min_y) / (cloud_max_y - cloud_min_y), 0.0, 1.0);
	float light = mix(0.32, 1.0, smoothstep(0.0, 1.0, h_mid));
	light *= clamp(light_direction.y * 1.8 + 0.35, 0.18, 1.25);

	vec3 col = cloud_color * cloud_brightness * light;
	ALBEDO = col;
	ALPHA = clamp(density / cloud_alpha, 0.0, 1.0);
}