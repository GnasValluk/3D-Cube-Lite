shader_type sky;

// Bầu trời procedural phong cách "Ghibli voxel" với mây chân thật:
//  - Gradient pastel mềm (xanh ngọc → kem nhạt sát chân trời).
//  - Mây cumulus fbm domain-warp: đáy phẳng, đỉnh bồng xơi, có khối, đổ nắng
//    vàng/rim hoàng hôn, bạc trăng ban đêm + lớp cirrus mảnh trên cao.
//  - Mặt trời nhỏ, quầng ấm dịu.
//  - Mặt trăng nhỏ, pha theo hình cầu + quầng lạnh.
//  - Sao đêm nhấp nháy.
// Mọi tham số được đẩy từ GDScript (SkyLight.update_sky) mỗi frame;
// clouds_on (0/1) là nút bật/tắt mây từ setting đồ hoạ.

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
// 0 = tắt mây (bầu trời sạch), 1 = vẽ mây chân thật (đẩy từ setting đồ hoạ).
uniform float clouds_on = 1.0;

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

// fbm 2D trên lát 3D cố định — nền cho mây (đáy phẳng/bồng đều hơn _fbm 3D).
float _fbm2(vec2 p, int oct) {
	float v = 0.0;
	float amp = 0.5;
	float f = 1.0;
	for (int i = 0; i < oct; i++) {
		v += amp * _vnoise(vec3(p * f, 3.7));
		f *= 1.93;
		amp *= 0.5;
	}
	return v;
}

// Domain warp: bẻ cong không gian nhiễu → hình thù mây hữu cơ, không còn là
// các khối tròn đều đặn trên lưới giá trị.
float _cloud_noise(vec2 p) {
	vec2 warp = vec2(
		_vnoise(vec3(p * 0.30 + vec2(0.0, 0.0), 1.7)),
		_vnoise(vec3(p * 0.33 + vec2(5.2, 9.7), 3.1)));
	vec2 q = p + (warp - 0.5) * 2.7;
	float base = _fbm2(q * 1.35, 4);
	// Nhiễu mịn: gợn trên mặt mây (đỉnh bồng, không phẳng lì).
	float ruffle = _vnoise(vec3(q * 4.6, 8.0));
	return clamp(base * 0.70 + ruffle * 0.30, 0.0, 1.0);
}

// Mây cumulus bồng bềnh — đáy phẳng, đỉnh xơi cuộn + lớp cirrus mảnh trên cao.
// Trả về vec4(density, hr [0 đáy..1 đỉnh trong band], lit [0 tối..1 sáng], cirrus).
// Tất cả tham số đẩy từ GDScript mỗi frame; mây trôi bằng star_time.
vec4 _cloud_layer(vec3 dir) {
	float alt = dir.y;
	if (alt < 0.02 || alt > 0.48) {
		return vec4(0.0, 0.0, 0.0, 0.0);
	}
	float hr = clamp((alt - 0.02) / 0.46, 0.0, 1.0); // 0 đáy → 1 đỉnh band
	// Phối cảnh: mây phủ rộng gần chân trời, thu hẹp dần lên cao (−> nhìn sâu).
	float persp = mix(0.85, 2.1, smoothstep(0.02, 0.44, alt));
	vec2 p = dir.xz * persp / max(dir.y, 0.05);
	// Trôi mây chậm (x, z tốc độ khác nhau cho cảm giác có chiều sâu).
	p += vec2(star_time * 0.0032, star_time * 0.0011);

	// Cumulus: đáy phẳng (chỉ cụm mây dày mới lộ đáy), đỉnh bồng xơi mềm.
	float f = _cloud_noise(p);
	float thr = 0.56 - hr * 0.16;
	float density = smoothstep(thr, thr + 0.16, f);
	density *= smoothstep(0.06, 0.30, hr);          // tách mây khỏi sương chân trời
	density *= 1.0 - smoothstep(0.72, 1.0, hr);     // tan dần trên đỉnh band
	// Cuộn mặt mây: chỉ giữ puffy core, càng dày càng đặc.
	density *= 0.80 + 0.20 * _vnoise(vec3(p * 3.2, 5.6));

	// "Chiều dày" gần đúng: đỉnh sáng, đáy tối → mây có khối, không phải sticker.
	float lit = mix(0.32, 1.06, smoothstep(0.0, 1.0, hr));

	// Cirrus mảnh sọc ở tầng cao, mờ nhạt, không có 'đáy' rõ.
	float cir = _fbm2(p * 0.55 + vec2(3.3, 1.7), 3);
	float cir_band = smoothstep(0.40, 0.50, alt) * (1.0 - smoothstep(0.54, 0.66, alt));
	float cir_d = smoothstep(0.66, 0.88, cir) * cir_band;

	return vec4(clamp(density + cir_d * 0.6, 0.0, 1.0), hr, lit, cir_d);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun_dir_n = normalize(sun_dir);
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

	// ── Mây chân thật ───────────────────────────────────────────────────────
	float clouds_gate = cloud_cover * step(0.5, clouds_on);
	if (clouds_gate > 0.001) {
		vec4 cl = _cloud_layer(dir);
		if (cl.x > 0.001) {
			float sun_low = clamp(1.0 - abs(sun_dir.y) * 2.2, 0.0, 1.0);

			// Màu đỉnh (sáng trắng-kem) và đáy (xám xanh) mây.
			vec3 cloud_base = vec3(1.03, 1.02, 0.99);
			vec3 cloud_shadow = vec3(0.55, 0.60, 0.72);
			// Nắng thấp (sáng/chiều): mây ngả vàng cam ấm.
			cloud_base = mix(cloud_base, vec3(1.28, 1.06, 0.80), sun_low * 0.55);
			cloud_shadow = mix(cloud_shadow, vec3(0.72, 0.52, 0.38), sun_low * 0.4);
			// Ban đêm: mây trăng bạc xanh tối.
			cloud_base = mix(cloud_base, vec3(0.27, 0.31, 0.44), night_factor * 0.9);
			cloud_shadow = mix(cloud_shadow, vec3(0.10, 0.12, 0.20), night_factor * 0.9);
			// Mưa: xám nặng đầy u ám.
			float w = clamp(weather, 0.0, 1.0);
			cloud_base = mix(cloud_base, vec3(0.56, 0.57, 0.60), w * 0.95);
			cloud_shadow = mix(cloud_shadow, vec3(0.34, 0.35, 0.38), w * 0.95);

			// Khối mây: mix đáy↔đỉnh theo hr + lit; đỉnh sáng nhấp nháy dưới nắng.
			vec3 cloud_col = mix(cloud_shadow, cloud_base, cl.z);
			cloud_col *= mix(0.85, 1.45, clamp(sun_dir_n.y, 0.0, 1.0));
			// Rim vàng ở mép mây hướng nắng khi nắng thấp (giống Ghibli).
			float rim = clamp(dot(normalize(dir - dir.y * vec3(0.0, 1.0, 0.0)), sun_dir_n), 0.0, 1.0);
			float rim_amt = pow(rim, 2.5) * sun_low * 0.8;
			cloud_col = mix(cloud_col, vec3(1.0, 0.78, 0.48), rim_amt * cl.z);
			cloud_col *= mix(0.95, 1.25, sun_dir.y * 0.3 + 0.3) * (1.0 - w * 0.25);

			float cloud = cl.x * clouds_gate;
			col = mix(col, cloud_col, cloud);
		}
	}

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
