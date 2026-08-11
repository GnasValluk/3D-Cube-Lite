class_name SkyLight
extends RefCounted

## Bầu trời procedural tự vẽ mặt trời/mặt trăng bằng shader — KHÔNG cần
## DirectionalLight3D. Dùng chung cho Real World (real_world_environment.gd)
## và Twilight World / Hub (twilight_environment.gd): màu nền theo giờ trong
## ngày + thời tiết, mặt trời/mặt trăng di chuyển theo chu kỳ ngày đêm.

const SKY_SHADER := preload("res://scripts/world/environment/sky.gdshader")

const DAY_TOP       := Color(0.22, 0.52, 0.92)
const DAY_HORIZON   := Color(0.74, 0.84, 0.94)
const NIGHT_TOP     := Color(0.012, 0.015, 0.05)
const NIGHT_HORIZON := Color(0.06, 0.06, 0.12)
const GRAY_TOP      := Color(0.42, 0.46, 0.52)
const GRAY_HORIZON  := Color(0.58, 0.60, 0.64)

const SUN_DAY_COLOR := Color(1.0, 0.96, 0.85)
const SUN_HORIZON   := Color(1.0, 0.45, 0.20)
const SUN_NIGHT     := Color(0.85, 0.90, 1.0)

# Chu kỳ giao hội của trăng (ngày trò chơi) — pha trăng + nguyệt thực.
const SYNODIC_MONTH: float = 29.53

static func _hash01(seed_i: int) -> float:
	return fposmod(sin(float(seed_i) * 127.1) * 43758.5453123, 1.0)

static func build_sky() -> Array:
	# [0] = Sky, [1] = ShaderMaterial
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	return [sky, mat]

## Cập nhật bầu trời theo giờ và thời tiết — toàn bộ bằng uniforms, không đụng
## tới DirectionalLight3D.
## - hour ∈ [0,24), weather_intensity ∈ [0,1]
## - dayf: số ngày đã trôi qua (đếm pha trăng). dayf < 0 → coi là full moon
##   (tương thích test/benchmark cũ vốn không truyền ngày).
static func update_sky(mat: ShaderMaterial, hour: float, weather: float, dayf: float = -1.0) -> void:
	if mat == null:
		return

	# 🔥 Elevation angle của mặt trời: 6h=0 (chân trời), 12h=90 (đỉnh), 18h=0.
	var e := (hour - 6.0) / 12.0 * PI
	var elev_deg: float = 90.0 * sin(e)
	var sun_lev: float = clamp(elev_deg / 90.0, 0.0, 1.0)  # 1 = trưa, 0 = dưới chân trời
	var day_t: float = clamp((elev_deg + 5.0) / 95.0, 0.0, 1.0)  # độ sáng của ngày
	var night_factor: float = 1.0 - day_t

	# Trạng thái sáng/chiều: morning đỉnh lúc 8h, evening đỉnh lúc 17h.
	var morning: float = clamp(1.0 - abs(hour - 8.0) / 3.5, 0.0, 1.0)
	var evening_t: float = clamp(1.0 - abs(hour - 17.0) / 3.0, 0.0, 1.0)
	var golden_hour: float = clamp(1.0 - abs(hour - 17.5) / 2.2, 0.0, 1.0)

	# Một số ngày chân trời chiều ngả cam-hồng thay vì cam thuần.
	var day_idx := int(maxf(dayf, 0.0))
	var pink_dusk: bool = _hash01(day_idx * 31 + 7) > 0.55

	# Bầu trời phai về xám khi mưa.
	var top_day := DAY_TOP.lerp(GRAY_TOP, weather)
	var top_night := NIGHT_TOP.lerp(GRAY_TOP, weather * 0.4)
	var hor_day := DAY_HORIZON.lerp(GRAY_HORIZON, weather)
	var hor_night := NIGHT_HORIZON.lerp(GRAY_HORIZON, weather * 0.4)

	# Bình minh / hoàng hôn → chân trời nóng cam (chỉ khi mặt trời gần chân trời).
	var dusk_color: Color = Color(0.98, 0.55, 0.22) if not pink_dusk else Color(0.99, 0.52, 0.40)

	var top_color: Color = top_night.lerp(top_day, day_t)
	var hor_color: Color = hor_night.lerp(hor_day, day_t)

	# Ánh lửa chân trời sáng/chiều: áp TRÊN màu final (không phụ thuộc day_t)
	# nên buổi sáng/chiều vẫn rực cam ngay cả khi trời đang chuyển tối.
	var sun_low_gate: float = clamp(1.0 - abs(elev_deg) / 25.0, 0.0, 1.0)  # gần chân trời
	var dawn_glow: float = morning * sun_low_gate     # bình minh (sớm, sun thấp)
	var dusk_glow: float = golden_hour * sun_low_gate  # hoàng hôn (sun vừa lặn)
	var glow: float = maxf(dawn_glow, dusk_glow) * (1.0 - weather * 0.5)
	hor_color = hor_color.lerp(dusk_color, glow * 0.9)
	var top_warm := Color(0.92, 0.78, 0.62) if not pink_dusk else Color(0.92, 0.72, 0.66)
	top_color = top_color.lerp(top_warm, glow * 0.30 * (0.5 + 0.5 * (day_t)))

	mat.set_shader_parameter("sky_top_color", top_color)
	mat.set_shader_parameter("sky_horizon_color", hor_color)
	mat.set_shader_parameter("sky_curve", 0.5)
	mat.set_shader_parameter("sky_energy", lerp(0.6, 1.35, day_t) * (1.0 - weather * 0.35))

	mat.set_shader_parameter("ground_bottom_color", top_night.lerp(DAY_TOP, day_t).darkened(0.55))
	mat.set_shader_parameter("ground_horizon_color", hor_night.lerp(hor_day, day_t).darkened(0.35))
	mat.set_shader_parameter("ground_curve", 0.25)
	mat.set_shader_parameter("ground_energy", 0.6)

	# Mặt trời: chân trời → cam đỏ, lên cao dần → vàng ấm → trắng-vàng.
	# Sø sáng: ngả vàng hơn ($ morning), chiều: ngả cam đỏ hơn (golden_hour).
	var sun_t: float = clamp(elev_deg / 70.0, 0.0, 1.0)
	var sun_low := Color(1.00, 0.60, 0.22)   # chạm chân trời: cam
	var sun_mid := Color(1.00, 0.86, 0.58)   # độ cao vừa: vàng ấm
	var sun_high := Color(1.00, 0.96, 0.84)  # cao: trắng-vàng
	var sun_kind: Color = sun_low.lerp(sun_mid, clamp((sun_t - 0.05) / 0.35, 0.0, 1.0))
	sun_kind = sun_kind.lerp(sun_high, clamp((sun_t - 0.50) / 0.40, 0.0, 1.0))
	# Buổi sáng: ấm vàng hơn; buổi chiều gần hoàng hôn: cam đỏ rực.
	sun_kind = sun_kind.lerp(Color(1.0, 0.90, 0.62), morning * 0.35)
	sun_kind = sun_kind.lerp(Color(1.0, 0.48, 0.16), golden_hour * 0.75)
	var sun_color := sun_kind.lerp(GRAY_HORIZON, weather * 0.7)
	# Ngả về tông trời đêm (xanh-trăng) CHỈ khi mặt trời đã lặn hẳn, không làm
	# mất màu cam đỏ mặt trời lúc bình minh/hoàng hôn.
	var sun_below: float = clamp((-elev_deg) / 8.0, 0.0, 1.0)
	sun_color = sun_color.lerp(SUN_NIGHT, sun_below * 0.9)

	# Hướng mặt trời: elevation theo giờ (6h chân trời đông, 12h đỉnh đầu, 18h tây).
	var yaw_deg: float = 90.0 - hour * 15.0
	# pitch = elevation trực tiếp: 0 = chân trời, +90 = đỉnh, -90 = dưới đất.
	var pitch_rad := deg_to_rad(elev_deg)
	var yaw_rad := deg_to_rad(yaw_deg)
	var sun_dir := Vector3(cos(pitch_rad) * cos(yaw_rad), sin(pitch_rad), cos(pitch_rad) * sin(yaw_rad))
	mat.set_shader_parameter("sun_dir", sun_dir)
	mat.set_shader_parameter("sun_color", sun_color)
	mat.set_shader_parameter("sun_energy", lerp(0.0, 2.4, day_t) * (1.0 - weather * 0.55))
	mat.set_shader_parameter("sun_angle_max", 5.0)
	mat.set_shader_parameter("sun_curve", 0.1)

	# ── Mặt trăng: quỹ đạo riêng, lệch so với mặt trời theo pha ──────────────
	# phase ∈ [0,1): 0 = trăng mới (cùng hướng mặt trời), 0.5 = trăng tròn.
	var dayf_c := dayf
	if dayf_c < 0.0:
		dayf_c = SYNODIC_MONTH * 0.5  # mặc định full moon (tương thích test cũ)
	var phase: float = fposmod(dayf_c / SYNODIC_MONTH, 1.0)

	# Điểm cao nhất của trăng (transit) lệch sau mặt trời theo pha:
	# trăng mới transit 12h (đi cùng nắng), trăng tròn transit ~0h (nửa đêm).
	var transit_hour := fposmod(12.0 + phase * 24.0, 24.0)
	# scan ∈ [0,24): 6 = mọc, 12 = đỉnh, 18 = lặn — quỹ đạo riêng theo transit.
	var moon_scan := fposmod(hour - transit_hour + 12.0, 24.0)
	# Độ cao & hướng tính NHẤT QUÁN từ cùng góc scan — trăng không bám yaw mặt trời.
	var moon_elev_deg: float = 90.0 * sin(deg_to_rad((moon_scan - 6.0) * 15.0))
	# Nghiêng quỹ đạo theo pha: trăng mọc lệch dần hướng bắc/nam qua các ngày
	# (thay vì phase*360 → luôn chạy song song trên cùng vĩ tuyến với mặt trời).
	var moon_yaw_deg: float = 90.0 - moon_scan * 15.0 + (phase - 0.5) * 40.0
	var mp_rad := deg_to_rad(moon_elev_deg)
	var my_rad := deg_to_rad(moon_yaw_deg)
	var moon_dir := Vector3(cos(mp_rad) * cos(my_rad), sin(mp_rad), cos(mp_rad) * sin(my_rad))
	mat.set_shader_parameter("moon_dir", moon_dir)
	mat.set_shader_parameter("moon_color", SUN_NIGHT.lerp(GRAY_HORIZON, weather * 0.4))
	mat.set_shader_parameter("moon_energy", lerp(0.0, 1.6, night_factor) * (1.0 - weather * 0.4))
	# Pha đẩy lên shader (dùng cho nguyệt thực + fallback sáng đĩa).
	mat.set_shader_parameter("moon_phase", phase)

	# Nguyệt thực: hiếm xảy ra (15% số trăng tròn), chỉ khi trăng đang cao.
	var full_cycle: int = int(dayf_c / SYNODIC_MONTH)
	var eclipse_chance: bool = _hash01(full_cycle * 71 + 3) < 0.15
	var moon_up: float = clamp(moon_elev_deg / 60.0, 0.0, 1.0)
	var eclipse: float = 0.0
	if eclipse_chance and abs(phase - 0.5) < 0.03:
		eclipse = moon_up
	mat.set_shader_parameter("moon_eclipse", eclipse)
	mat.set_shader_parameter("moon_eclipse_color", Color(0.70, 0.22, 0.12))

	mat.set_shader_parameter("night_factor", night_factor)
	mat.set_shader_parameter("weather", weather)
	mat.set_shader_parameter("star_time", Time.get_ticks_msec() / 1000.0)
