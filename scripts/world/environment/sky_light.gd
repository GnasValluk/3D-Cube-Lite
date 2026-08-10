class_name SkyLight
extends RefCounted

## Bầu trời procedural cho cả Real World (real_world_environment.gd) và
## Twilight World / Hub (twilight_environment.gd): màu nền theo giờ trong
## ngày + thời tiết, mặt trời/mặt trăng di chuyển theo chu kỳ ngày đêm.

const DAY_TOP       := Color(0.22, 0.52, 0.92)
const DAY_HORIZON   := Color(0.74, 0.84, 0.94)
const NIGHT_TOP     := Color(0.012, 0.015, 0.05)
const NIGHT_HORIZON := Color(0.06, 0.06, 0.12)
const GRAY_TOP      := Color(0.42, 0.46, 0.52)
const GRAY_HORIZON  := Color(0.58, 0.60, 0.64)

const SUN_DAY_COLOR := Color(1.0, 0.96, 0.85)
const SUN_HORIZON   := Color(1.0, 0.45, 0.20)
const SUN_NIGHT     := Color(0.85, 0.90, 1.0)

static func build_sky() -> Array:
	# [0] = Sky, [1] = ProceduralSkyMaterial
	var mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	return [sky, mat]

## Cập nhật màu bầu trời + hướng/độ sáng nắng theo giờ và thời tiết.
## - hour ∈ [0,24), weather_intensity ∈ [0,1]
static func update_sky(mat: ProceduralSkyMaterial, dir_light: DirectionalLight3D, hour: float, weather: float) -> void:
	if mat == null:
		return

	# 🔥 Elevation angle của mặt trời: 6h=0 (chân trời), 12h=90 (đỉnh), 18h=0.
	var e := (hour - 6.0) / 12.0 * PI
	var elev_deg: float = 90.0 * sin(e)
	var sun_lev: float = clamp(elev_deg / 90.0, 0.0, 1.0)  # 1 = trưa, 0 = dưới chân trời
	var day_t: float = clamp((elev_deg + 5.0) / 95.0, 0.0, 1.0)  # độ sáng của ngày

	# Bầu trời phai về xám khi mưa.
	var top_day := DAY_TOP.lerp(GRAY_TOP, weather)
	var top_night := NIGHT_TOP.lerp(GRAY_TOP, weather * 0.4)
	var hor_day := DAY_HORIZON.lerp(GRAY_HORIZON, weather)
	var hor_night := NIGHT_HORIZON.lerp(GRAY_HORIZON, weather * 0.4)

	# Bình minh / hoàng hôn → chân trời nóng cam (chỉ khi mặt trời gần chân trời).
	var twilight: float = clamp(1.0 - abs(elev_deg) / 14.0, 0.0, 1.0)
	twilight *= clamp(sun_lev * 1.2, 0.0, 1.0)
	hor_day = hor_day.lerp(Color(0.98, 0.62, 0.30), twilight * (1.0 - weather * 0.6))

	mat.sky_top_color = top_night.lerp(top_day, day_t)
	mat.sky_horizon_color = hor_night.lerp(hor_day, day_t)
	mat.sky_curve = 0.5
	mat.sky_energy_multiplier = lerp(0.6, 1.35, day_t) * (1.0 - weather * 0.35)

	mat.ground_bottom_color = top_night.lerp(DAY_TOP, day_t).darkened(0.55)
	mat.ground_horizon_color = hor_night.lerp(hor_day, day_t).darkened(0.35)
	mat.ground_curve = 0.25
	mat.ground_energy_multiplier = 0.6

	# Mặt trời: ban ngày vàng, chân trời cam, đêm → mặt trăng xanh.
	var sun_kind := Color.WHITE
	if abs(elev_deg) < 8.0:
		sun_kind = SUN_HORIZON
	elif sun_lev > 0.0:
		sun_kind = SUN_DAY_COLOR
	var sun_color := sun_kind.lerp(GRAY_HORIZON, weather * 0.7)
	var moon_factor: float = 1.0 - sun_lev
	sun_color = sun_color.lerp(SUN_NIGHT, moon_factor * 0.9)

	mat.sun_angle_max = 10.0
	mat.sun_curve = 0.1

	# Hướng đèn mặt trời: quay theo độ cao mặt trời + góc phương vị dịch dần
	# theo giờ (6h đông, 12h nam, 18h tây). Cường độ đèn bám sát sun_lev để
	# đêm tự hạ sáng (không cần ProceduralSkyMaterial.sun_energy — đã bị bỏ).
	if dir_light != null:
		var yaw_deg: float = 90.0 - hour * 15.0
		var pitch_deg: float = -90.0 + 90.0 * sun_lev
		dir_light.rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0)
		dir_light.light_color = sun_color.lerp(Color(0.6, 0.6, 0.62), weather * 0.5)
		dir_light.light_energy = lerp(0.15, 2.4, sun_lev) * (1.0 - weather * 0.55)