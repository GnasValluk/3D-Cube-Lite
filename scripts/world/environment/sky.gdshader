shader_type sky;

// Bầu trời procedural tự vẽ mặt trời/mặt trăng — KHÔNG cần DirectionalLight3D.
// Mọi tham số (màu, hướng nắng, thời tiết, đêm) được đẩy từ GDScript mỗi frame.

uniform vec3 sun_dir = vec3(0.0, 0.5, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.85);
uniform float sun_energy : hint_range(0.0, 8.0) = 1.0;
uniform float sun_angle_max : hint_range(0.0, 40.0) = 8.0;
uniform float sun_curve : hint_range(0.0, 2.0) = 0.1;

uniform vec3 moon_dir = vec3(0.0, -0.5, -1.0);
uniform vec3 moon_color : source_color = vec3(0.9, 0.92, 1.0);
uniform float moon_energy : hint_range(0.0, 6.0) = 1.2;
uniform float moon_angle_max : hint_range(0.0, 40.0) = 7.0;
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;
uniform float moon_eclipse : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_eclipse_color : source_color = vec3(0.70, 0.22, 0.12);

uniform vec3 sky_top_color : source_color = vec3(0.22, 0.52, 0.92);
uniform vec3 sky_horizon_color : source_color = vec3(0.74, 0.84, 0.94);
uniform float sky_curve : hint_range(0.0, 2.0) = 0.5;
uniform float sky_energy : hint_range(0.0, 4.0) = 1.0;

uniform vec3 ground_bottom_color : source_color = vec3(0.09, 0.10, 0.13);
uniform vec3 ground_horizon_color : source_color = vec3(0.48, 0.52, 0.58);
uniform float ground_curve : hint_range(0.0, 2.0) = 0.25;
uniform float ground_energy : hint_range(0.0, 4.0) = 0.6;

uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float weather : hint_range(0.0, 1.0) = 0.0;

// Thời gian đẩy từ GDScript mỗi frame — TIME nội bộ của sky shader không chạy
// theo engine nên không dùng được cho hiệu ứng nhấp nháy.
uniform float star_time = 0.0;

float _hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

// Sao điểm nhỏ trên hình cầu (3D lattice theo hướng nhìn, size cố định theo góc
// nên không phình to ở chân trời). ~30% ô có sao, đĩa sao nhỏ ~1px, mỗi sao
// nhấp nháy độc lập theo star_time (đẩy từ GDScript vì TIME trong sky shader không chạy).
float _stars(vec3 dir, float scale) {
	float resident = 0.09;
	vec3 p = dir * scale;
	vec3 id = floor(p);
	vec3 cell = fract(p) - 0.5;
	float h = _hash(id);
	float d = length(cell);
	float star = smoothstep(resident, 0.0, d) * step(0.7, h);
	float tw = 0.35 + 0.65 * sin(star_time * (2.0 + h * 6.0) + h * 91.7);
	tw = max(tw, 0.0);
	return star * tw;
}

vec3 _star_color(float h) {
	// Trắng xanh là chủ đạo, pha lẫn vài sao vàng/cam nhạt.
	vec3 white = vec3(0.9, 0.94, 1.0);
	vec3 warm = vec3(1.0, 0.82, 0.6);
	return mix(warm, white, fract(h * 7.31));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;

	// Gradient trời: đỉnh -> chân trời.
	float h = clamp(y, 0.0, 1.0);
	vec3 col = mix(sky_horizon_color, sky_top_color, pow(h, sky_curve));

	// Gradient đất: chân trời -> đáy.
	float g = clamp(-y, 0.0, 1.0);
	vec3 ground = mix(ground_horizon_color, ground_bottom_color, pow(g, ground_curve));
	col = mix(col, ground, smoothstep(0.0, -0.02, y));

	// Ánh sáng khuếch tán của trời chỉ nhân vào nền gradient — các thiên thể
	// (sun/moon/stars) là nguồn sáng thêm SAU đó nên không bị làm mờ vào ban đêm.
	col *= mix(sky_energy, sky_energy * 0.4, night_factor * 0.6);

	// Mặt trời: render giống mặt trăng (đĩa sắc + quầng rất hẹp), size nhỏ hơn
	// trăng. Nhung nhỏ hơn trăng (sun_angle_max < moon_angle_max).
	float sun_cos = dot(dir, sun_dir);
	float s_edge = cos(radians(sun_angle_max * 1.2));
	float s_core = cos(radians(sun_angle_max * 0.4));
	float s_disc = smoothstep(s_edge, s_core, sun_cos);
	float s_glow = pow(max(sun_cos, 0.0), 100.0) * sun_energy * 0.7;
	col += sun_color * sun_energy * (s_disc + s_glow);

	// Đĩa mặt trăng + quầng rất hẹp (tránh che hết sao quanh trăng).
	// Terminator: phần đĩa có surface normal quay về phía mặt trời thì sáng.
	float moon_cos = dot(dir, moon_dir);
	float m_edge = cos(radians(moon_angle_max * 1.2));
	float m_core = cos(radians(moon_angle_max * 0.35));
	float m_disc = smoothstep(m_edge, m_core, moon_cos);
	// Hướng "xem" 1 điểm trên đĩa trăng ≈ dir (disc nhỏ). Surface normal của
	// quả cầu trăng bật góc theo offset: n = normalize(moon_dir + (dir - moon_dir*moon_cos)*k).
	vec3 disc_off = dir - moon_dir * moon_cos;
	vec3 surf_n = normalize(moon_dir + disc_off * 6.0);
	// Pha: ánh sáng trăng đến từ hướng ngược mặt trời (full moon đối diện nắng
	// → N·(−sun_dir) dương). Vẽ terminator theo hình cầu thật.
	float phase_amt = clamp(dot(surf_n, -sun_dir), 0.0, 1.0);
	phase_amt = smoothstep(-0.05, 0.5, phase_amt) * 0.35 + smoothstep(0.5, 0.75, phase_amt) * 0.65;
	// Nguyệt thực: toàn đĩa ngả đỏ thẫm, viền sáng còn lại dịu.
	vec3 moon_col = mix(moon_color, moon_eclipse_color, moon_eclipse);
	float ecl_bright = 1.0 - moon_eclipse * 0.75;
	float m_glow = pow(max(moon_cos, 0.0), 100.0) * moon_energy * 0.7;
	col += moon_col * moon_energy * (m_disc * phase_amt * ecl_bright + m_glow);

	// Sao đêm: 3 lớp lattice, mật độ và kích thước khác nhau cho chiều sâu.
	if (night_factor > 0.05 && y > 0.02) {
		float s1 = _stars(dir, 45.0) * 0.7;
		float s2 = _stars(dir, 90.0) * 0.9;
		float s3 = _stars(dir, 160.0) * 1.1;
		float stars = s1 + s2 + s3;
		vec3 star_col = _star_color(_hash(floor(dir * 45.0)));
		col += star_col * stars * night_factor;
	}

	// Thời tiết: phai về xám.
	vec3 grey = vec3(0.45, 0.48, 0.52);
	col = mix(col, grey, weather * 0.75);

	COLOR = col;
}