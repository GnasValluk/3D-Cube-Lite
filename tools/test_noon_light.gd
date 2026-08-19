extends Node

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_noon_light ==")
	var SL: Script = load("res://scripts/world/environment/sky_light.gd")
	var RWE: Script = load("res://scripts/world/environment/real_world_environment.gd")

	var mat := ShaderMaterial.new()
	# Bầu trời 12h: năng lượng giữ mức buổi sáng (~9h), không gắt
	SL.update_sky(mat, 12.0, 0.0, -1.0)
	var sun_e: float = mat.get_shader_parameter("sun_energy")
	var sky_e: float = mat.get_shader_parameter("sky_energy")
	_check(sun_e < 1.6, "sun_energy trưa ≈ mức sáng (~1.51, hiện %.2f)" % sun_e)
	_check(sky_e < 1.1, "sky_energy trưa dịu (hiện %.2f)" % sky_e)
	_check(mat.get_shader_parameter("sun_color").r >= 0.9, "mặt trời vẫn vàng ấm")

	# Đèn hướng trưa: sáng như buổi sáng, tông ấm nhẹ (không bạc gắt)
	var env: WorldEnvironment = RWE.new()
	var sun := DirectionalLight3D.new()
	add_child(env)
	env.add_child(sun)
	env._sun = sun
	env._moon = DirectionalLight3D.new()
	env.add_child(env._moon)
	# Warm của trưa (h=12): morning_w=0.3 → màu ấm nhẹ hơn tông trắng.
	env._update_sun(12.0, 1.0)
	var c: Color = sun.light_color
	_check(c.r >= c.g and c.g > c.b, "trưa giữ tông ấm sáng (%s)" % c)
	_check(sun.light_energy >= 1.0, "nắng trưa đủ sáng như buổi sáng (%.2f)" % sun.light_energy)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)