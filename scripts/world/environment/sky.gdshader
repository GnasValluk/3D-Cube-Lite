shader_type sky;

// Bầu trời procedural phong cách "Ghibli voxel":
//  - Gradient pastel mềm (xanh ngọc → kem nhạt sát chân trời).
//  - Mây puffy dạng voxel (các khối cube mềm, 2 lớp xa/gần, có bóng + viền vàng
//    lúc bình minh/hoàng hôn).
//  - Mặt trời nhỏ, quầng ấm dịu.
//  - Mặt trăng nhỏ, pha theo hình cầu + quầng lạnh.
//  - Sao đêm nhấp nháy.
// Mọi tham số được đẩy từ GDScript (SkyLight.update_sky) mỗi frame.

uniform vec3 sun_dir = vec3(0.0, 0.5, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.85);
uniform float sun_energy : hint_range(0.0, 8.0) = 1.0;
uniform float sun_angle_max : hint_range(0.0, 40.0) = 2.2;
uniform float sun_curve : hint_range(0.0, 2.0) = 0.1;

uniform vec3 moon_dir = vec3(0.0, -0.5, -1.0);
uniform vec3 moon_color : source_color = vec3(0.9, 0.92, 1.0);
uniform float moon_energy : hint_range(0.0, 6.0) = 1.2;
uniform float moon_angle_max : hint_range(0.0, 40.0) = 1.7;
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;
uniform float moon_eclipse : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_eclipse_color : source_color = vec3(0.70, 0.22, 0.12);

uniform vec3 sky_top_color : source_color = vec3(0.36, 0.62, 0.95);
uniform vec3 sky_horizon_color : source_color = vec3(0.88, 0.90, 0.93);
uniform float sky_curve : hint_range(0.0, 2.0) = 0.5;
uniform float sky_energy : hint_range(0.0, 4.0) = 1.0;

uniform vec3 ground_bottom_color : source_color = vec3(0.09, 0.10, 0.13);
uniform vec3 ground_horizon_color : source_color = vec3(0.48, 0.52, 0.58);
uniform float ground_curve : hint_range(0.0, 2.0) = 0.25;
uniform float ground_energy : hint_range(0.0, 4.0) = 0.6;

uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float weather : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.35;

// Thời gian đẩy từ GDScript mỗi frame (trôi mây + nhấp nháy sao).
uniform float star_time = 0.0;

float _hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

// Value noise 3D (bằng interpolation mềm) — nền cho mây.
float _vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = _hash(i);
	float b = _hash(i + vec3(1.0, 0.0, 0.0));
	float c = _hash(i + vec3(0.0, 1.0, 0.0));
	float d = _hash(i + vec3(1.0, 1.0, 0.0));
	float e = _hash(i + vec3(0.0, 0.0, 1.0));
	float f2 = _hash(i + vec3(1.0, 0.0, 1.0));
	float g = _hash(i + vec3(0.0, 1.0, 1.0));
	float h = _hash(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(a, b, u.x), mix(c, d, u.x), u.y),
		mix(mix(e, f2, u.x), mix(g, h, u.x), u.y),
		u.z);
}

// fbm — nhiễu nhiều tầng.
float _fbm(vec3 p, int oct) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < oct; i++) {
		v += amp * _vnoise(p);
		p = p * 2.03 + vec3(17.31, 11.7, 5.3);
		amp *= 0.5;
	}
	return v;
}

// Sao điểm nhỏ trên hình cầu.
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
	vec3 white = vec3(0.9, 0.94, 1.0);
	vec3 warm = vec3(1.0, 0.82, 0.6);
	return mix(warm, white, fract(h * 7.31));
}

// Value noise trên lưới thô (mỗi "cube" là 1 blob) — bilinear để cạnh cube mềm.
float _cube_blob(vec2 q, float layer) {
	vec2 c = floor(q);
	vec2 f = smoothstep(0.0, 1.0, fract(q));
	float n00 = _vnoise(vec3(c, layer));
	float n10 = _vnoise(vec3(c + vec2(1.0, 0.0), layer));
	float n01 = _vnoise(vec3(c + vec2(0.0, 1.0), layer));
	float n11 = _vnoise(vec3(c + vec2(1.0, 1.0), layer));
	return mix(mix(n00, n10, f.x), mix(n01, n11, f.x), f.y);
}

// Mây voxel: 1 lớp blob to + 1 lớp facet nhỏ, giới hạn trong dải độ cao.
// Trả về [density, độ sáng] để tô màu puffy (đỉnh sáng, đáy tối).
vec2 _cloud_layer(vec3 dir) {
	float alt = dir.y;
	float band = smoothstep(0.05, 0.13, alt) * (1.0 - smoothstep(0.32, 0.46, alt));
	if (band <= 0.001) {
		return vec2(0.0, 0.0);
	}
	// Phối cảnh: mây gần chân trời to hơn, trên đỉnh nhỏ hơn (foreshortening).
	float persp = mix(0.55, 1.35, smoothstep(0.05, 0.42, alt));
	vec2 p = dir.xz * persp;
	// Trôi mây chậm.
	p += vec2(star_time * 0.004, star_time * 0.0015);

	float base = _cube_blob(p * 0.55, 0.0);
	float detail = _cube_blob(p * 1.9, 1.0);
	float d = base * 0.66 + detail * 0.34;

	float cov = smoothstep(0.46, 0.66, d);
	cov *= band;
	// Đỉnh blob sáng hơn đáy (giả 3D puffy).
	float light = mix(0.35, 1.0, smoothstep(0.42, 0.78, d));
	return vec2(cov, light);
}

// Màu mây: sáng trắng-kem ban ngày, vàng-cam lúc nắng thấp, xám khi mưa,
// xanh-tối ban đêm. Bóng mây ngả xanh dương nhạt.
vec3 _cloud_color(vec3 base, vec3 shadow, float lit, vec3 dir, vec3 sun_dir_n, float sun_low) {
	vec3 c = mix(shadow, base, lit);
	// Viền vàng phía mặt trời lúc nắng thấp (rim light kiểu Ghibli).
	float rim = clamp(dot(normalize(dir - dir.y * vec3(0.0, 1.0, 0.0)), sun_dir_n), 0.0, 1.0);
	float rim_amt = pow(rim, 3.0) * sun_low * 0.9;
	c = mix(c, vec3(1.0, 0.72, 0.42), rim_amt * lit);
	return c;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;

	// ── Gradient trời: đỉnh → chân trời (pastel mềm) ────────────────────────
	float h = clamp(y, 0.0, 1.0);
	vec3 col = mix(sky_horizon_color, sky_top_color, pow(h, sky_curve));

	// Dải ấm mỏng sát chân trời (đặc trưng Ghibli) — ngả vàng nhẹ, không trắng.
	// Áp cho CẢ trời và đất chân trời để không tạo seam phân cách.
	float day = smoothstep(-0.08, 0.25, sun_dir.y);
	vec3 warm_band = vec3(1.0, 0.88, 0.62);
	float band_amt = (1.0 - pow(h, 3.5)) * 0.10 * day;
	col = mix(col, warm_band, band_amt);

	// Gradient đất: chuyển mềm từ trời → đất trong ~0.09 rad để không còn dải
	// phân cách rõ rệt tại đường chân trời kể cả khi nhìn từ trên cao xuống.
	float g = clamp(-y, 0.0, 1.0);
	vec3 ground = mix(ground_horizon_color, ground_bottom_color, pow(g, ground_curve));
	// Nhuộm cùng dải ấm ngay sát chân trời để đất hòa màu trời không seam.
	ground = mix(ground, warm_band, band_amt * (1.0 - pow(g, 2.0)));
	col = mix(col, ground, smoothstep(0.0, -0.09, y));

	// Ánh sáng khuếch tán nền.
	col *= mix(sky_energy, sky_energy * 0.4, night_factor * 0.6);

	// ── Mây voxel ────────────────────────────────────────────────────────────
	vec2 cl = _cloud_layer(dir);
	float cloud = cl.x * cloud_cover;
	vec3 sun_dir_n = normalize(sun_dir);
	float sun_low = clamp(1.0 - abs(sun_dir.y) * 2.2, 0.0, 1.0);

	vec3 cloud_base = vec3(1.0, 1.0, 0.985);
	vec3 cloud_shadow = vec3(0.72, 0.78, 0.88);
	// Ban đêm: mây tối xanh dương.
	cloud_base = mix(cloud_base, vec3(0.22, 0.26, 0.40), night_factor * 0.85);
	cloud_shadow = mix(cloud_shadow, vec3(0.12, 0.14, 0.24), night_factor * 0.85);
	// Mưa: xám.
	float w = clamp(weather, 0.0, 1.0);
	cloud_base = mix(cloud_base, vec3(0.62, 0.63, 0.66), w * 0.9);
	cloud_shadow = mix(cloud_shadow, vec3(0.42, 0.43, 0.46), w * 0.9);

	vec3 cloud_col = _cloud_color(cloud_base, cloud_shadow, cl.y, dir, sun_dir_n, sun_low);
	cloud_col *= mix(0.95, 1.35, sun_dir.y * 0.3 + 0.3) * (1.0 - w * 0.3);
	col = mix(col, cloud_col, cloud);

	// ── Mặt trời (nhỏ, quầng ấm dịu) ────────────────────────────────────────
	float sun_cos = dot(dir, sun_dir);
	float s_edge = cos(radians(sun_angle_max * 1.35));
	float s_core = cos(radians(sun_angle_max * 0.5));
	float s_disc = smoothstep(s_edge, s_core, sun_cos);
	// Quầng: rất hẹp, ấm, không làm cháy bầu trời (halo nhỏ → trông xa hơn).
	float s_halo = pow(max(sun_cos, 0.0), 160.0) * 0.35;
	float s_soft = pow(max(sun_cos, 0.0), 40.0) * 0.08;
	col += sun_color * sun_energy * (s_disc * 1.15 + s_halo + s_soft);

	// ── Mặt trăng (nhỏ, pha hình cầu, quầng lạnh) ───────────────────────────
	float moon_cos = dot(dir, moon_dir);
	float m_edge = cos(radians(moon_angle_max * 1.35));
	float m_core = cos(radians(moon_angle_max * 0.5));
	float m_disc = smoothstep(m_edge, m_core, moon_cos);
	vec3 disc_off = dir - moon_dir * moon_cos;
	vec3 surf_n = normalize(moon_dir + disc_off * 6.0);
	float phase_amt = clamp(dot(surf_n, -sun_dir_n), 0.0, 1.0);
	phase_amt = smoothstep(-0.05, 0.5, phase_amt) * 0.35 + smoothstep(0.5, 0.75, phase_amt) * 0.65;
	// Vết mờ trên đĩa trăng (maria) cho cảm giác voxel/painted.
	float maria = mix(0.82, 1.0, _vnoise(surf_n * 5.0 + vec3(9.0, 3.0, 7.0)));
	float maria2 = mix(0.85, 1.0, _vnoise(surf_n * 9.0 + vec3(2.0, 11.0, 4.0)));
	vec3 moon_col = mix(moon_color, moon_eclipse_color, moon_eclipse) * (maria * maria2);
	float ecl_bright = 1.0 - moon_eclipse * 0.75;
	float m_halo = pow(max(moon_cos, 0.0), 180.0) * 0.25;
	float m_soft = pow(max(moon_cos, 0.0), 45.0) * 0.07;
	col += moon_col * moon_energy * (m_disc * phase_amt * ecl_bright + m_halo + m_soft);

	// ── Sao đêm ──────────────────────────────────────────────────────────────
	if (night_factor > 0.05 && y > 0.02) {
		float s1 = _stars(dir, 45.0) * 0.7;
		float s2 = _stars(dir, 90.0) * 0.9;
		float s3 = _stars(dir, 160.0) * 1.1;
		float stars = s1 + s2 + s3;
		vec3 star_col = _star_color(_hash(floor(dir * 45.0)));
		col += star_col * stars * night_factor;
	}

	// Thời tiết: phai về xám (mây đã có màu riêng, chỉ phai nền).
	vec3 grey = vec3(0.45, 0.48, 0.52);
	col = mix(col, grey, weather * 0.55);

	COLOR = col;
}
