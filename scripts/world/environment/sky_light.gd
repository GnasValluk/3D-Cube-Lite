class_name SkyLight
extends RefCounted

## Bầu trời procedural tự vẽ mặt trời/mặt trăng bằng shader — KHÔNG cần
## DirectionalLight3D. Dùng chung cho Real World (real_world_environment.gd)
## và Twilight World / Hub (twilight_environment.gd): màu nền theo giờ trong
## ngày + thời tiết, mặt trời/mặt trăng di chuyển theo chu kỳ ngày đêm.

const SKY_SHADER := preload("res://scripts/world/environment/sky.gdshader")

const DAY_TOP       := Color(0.32, 0.60, 0.94)
const DAY_HORIZON   := Color(0.78, 0.85, 0.95)
const NIGHT_TOP     := Color(0.015, 0.018, 0.06)
const NIGHT_HORIZON := Color(0.08, 0.09, 0.18)
const GRAY_TOP      := Color(0.45, 0.48, 0.54)
const GRAY_HORIZON  := Color(0.60, 0.62, 0.66)

const SUN_DAY_COLOR := Color(1.0, 0.96, 0.85)
const SUN_HORIZON   := Color(1.0, 0.50, 0.24)
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
## - clouds: bật/tắt mây chân thật (nút setting đồ hoạ). Mặc định true.
static func update_sky(mat: ShaderMaterial, hour: float, weather: float, dayf: float = -1.0, clouds: bool = true) -> void:
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
	# Golden hour chiều: đỉnh 16.5h, rộng hơn → vàng cam bắt đầu từ ~14h,
	# không chỉ phút cuối trước khi tối.
	var golden_hour: float = clamp(1.0 - abs(hour - 16.5) / 3.0, 0.0, 1.0)

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
	# Ngưỡng rộng hơn (±50°) → vàng cam bắt đầu từ ~15h30 thay vì chỉ phút cuối.
	var sun_low_gate: float = clamp(1.0 - abs(elev_deg) / 50.0, 0.0, 1.0)  # gần chân trời
	var dawn_glow: float = morning * sun_low_gate     # bình minh (sớm, sun thấp)
	var dusk_glow: float = golden_hour * sun_low_gate  # hoàng hôn (sun vừa lặn)
	# Warm wash nền: cả bầu trời ngả vàng theo giờ (không đợi sun xuống thấp)
	# → chiều vàng cam từ sớm, chân trời rực hơn khi sun xuống.
	var warm_wash: float = maxf(morning, golden_hour) * (0.45 + 0.55 * sun_low_gate)
	var glow: float = maxf(dawn_glow, dusk_glow) * (1.0 - weather * 0.5)
	# Mạnh hơn lúc vàng cam rực (chiều): đẩy glow chiều lên cao.
	var warm_strength: float = 1.0 + golden_hour * 0.6
	hor_color = hor_color.lerp(dusk_color, glow * warm_strength + warm_wash * 0.25)
	var top_warm := Color(0.92, 0.78, 0.62) if not pink_dusk else Color(0.92, 0.72, 0.66)
	top_color = top_color.lerp(top_warm, glow * 0.35 * (0.5 + 0.5 * (day_t)) + warm_wash * 0.30)

	mat.set_shader_parameter("sky_top_color", top_color)
	mat.set_shader_parameter("sky_horizon_color", hor_color)
	mat.set_shader_parameter("sky_curve", 0.5)
	mat.set_shader_parameter("sky_energy", lerp(0.6, 1.2, day_t) * (1.0 - weather * 0.35))

	# Đất dưới chân trời: chân trời đất HÒA cùng màu trời (haze khí quyển) để
	# không còn dải xám phân cách, chỉ tối dần xuống dưới thành tông đất ấm.
	var ground_day_bottom := Color(0.15, 0.22, 0.13)
	var ground_night_bottom := Color(0.03, 0.05, 0.09)
	var g_bottom: Color = ground_night_bottom.lerp(ground_day_bottom, day_t)
	mat.set_shader_parameter("ground_bottom_color", g_bottom)
	mat.set_shader_parameter("ground_horizon_color", hor_color)
	mat.set_shader_parameter("ground_curve", 0.5)
	mat.set_shader_parameter("ground_energy", 0.8)

	# Mặt trời: chân trời → cam đỏ, lên cao dần → vàng ấm → trắng-vàng.
	# Sø sáng: ngả vàng hơn ($ morning), chiều: ngả cam đỏ hơn (golden_hour).
	var sun_t: float = clamp(elev_deg / 70.0, 0.0, 1.0)
	var sun_low := Color(1.00, 0.60, 0.22)   # chạm chân trời: cam
	var sun_mid := Color(1.00, 0.86, 0.58)   # độ cao vừa: vàng ấm
	var sun_high := Color(1.00, 0.94, 0.76)  # cao: vàng ấm dịu (không trắng gắt)
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
	mat.set_shader_parameter("sun_energy", lerp(0.0, 2.1, day_t) * (1.0 - weather * 0.55))
	# Mặt trời nhỏ + xa: chỉ ~1.1° (bán kính), quầng mềm trong shader.
	mat.set_shader_parameter("sun_angle_max", 1.1)
	mat.set_shader_parameter("sun_curve", 0.1)

	# ── Mặt trăng: quỹ đạo riêng, LUÔN đối diện mặt trời ──────────────────────
	# Trăng luôn nằm phía ngược với mặt trời nên đêm nào cũng thấy trăng:
	# mọc ~18h, đỉnh đầu lúc nửa đêm, lặn ~6h. Quỹ đạo nghiêng nhẹ (orbital
	# tilt cố định) so với mặt trời để không trùng đường đi của nắng.
	var moon_scan := fposmod(hour + 12.0, 24.0)  # 6 = mọc, 12 = đỉnh, 18 = lặn
	var moon_elev_deg: float = 90.0 * sin(deg_to_rad((moon_scan - 6.0) * 15.0))
	var moon_yaw_deg: float = 90.0 - moon_scan * 15.0 + 22.0
	var mp_rad := deg_to_rad(moon_elev_deg)
	var my_rad := deg_to_rad(moon_yaw_deg)
	var moon_dir := Vector3(cos(mp_rad) * cos(my_rad), sin(mp_rad), cos(mp_rad) * sin(my_rad))
	mat.set_shader_parameter("moon_dir", moon_dir)
	mat.set_shader_parameter("moon_color", SUN_NIGHT.lerp(GRAY_HORIZON, weather * 0.4))
	mat.set_shader_parameter("moon_energy", lerp(0.0, 0.55, night_factor) * (1.0 - weather * 0.4))
	# Mặt trăng nhỏ + xa: ~0.8° bán kính (nhỏ hơn mặt trời một chút).
	mat.set_shader_parameter("moon_angle_max", 0.8)

	# Pha trăng (theo ngày) chỉ dùng để chọn ngày nguyệt thực — không còn quyết
	# định vị trí trăng nữa. Nguyệt thực = trăng tròn bị bóng tối che một phần.
	var dayf_c := dayf
	if dayf_c < 0.0:
		dayf_c = SYNODIC_MONTH * 0.5  # mặc định full moon (tương thích test cũ)
	var phase: float = fposmod(dayf_c / SYNODIC_MONTH, 1.0)
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
	# Độ phủ mây: trời quang ~35%, mưa nhẹ ~60%, mưa to ~95%.
	# Mưa/tuyết → KHÔNG có mây (bầu trời quang đãng để thấy hạt rơi rõ hơn).
	# Trời quang: mây puffy ~35%; khi mưa/tuyết: 0%.
	mat.set_shader_parameter("cloud_cover", lerp(0.35, 0.0, weather))
	# Nút bật/tắt mây ở setting đồ hoạ — tắt hoàn toàn (bầu trời sạch, + FPS).
	mat.set_shader_parameter("clouds_on", 1.0 if clouds else 0.0)
	mat.set_shader_parameter("star_time", Time.get_ticks_msec() / 1000.0)
