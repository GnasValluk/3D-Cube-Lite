extends Node

## Verify moon phase geometry + lunar eclipse days.
## Pushes SkyLight.update_sky directly, prints shader params per moon cycle.

func _ready() -> void:
	print("== sky_moon_phase ==")
	var env_script: GDScript = load("res://scripts/world/environment/real_world_environment.gd")
	var we: WorldEnvironment = env_script.new() as WorldEnvironment
	add_child(we)
	we.set_process(false)
	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(0, 6, 8)
	cam.look_at(Vector3(0, 0, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	var rw := we as RealWorldEnvironment
	var mat: ShaderMaterial = rw._sky_mat

	# Pha trăng: new → first quarter → full → last quarter trên 1 chu kỳ 29.53.
	for dayf in [0.0, 3.7, 7.38, 14.76, 22.15, 26.0, 29.5]:
		SkyLight.update_sky(mat, 22.0, 0.0, dayf)
		var phase: float = mat.get_shader_parameter("moon_phase")
		var ecl: float = mat.get_shader_parameter("moon_eclipse")
		var mdir: Vector3 = mat.get_shader_parameter("moon_dir")
		var sdir: Vector3 = mat.get_shader_parameter("sun_dir")
		var myaw := rad_to_deg(atan2(mdir.z, mdir.x))
		var syaw := rad_to_deg(atan2(sdir.z, sdir.x))
		print("dayf %5.1f phase=%.2f ecl=%.2f moon_yaw=%6.1f sun_yaw=%6.1f" % [dayf, phase, ecl, myaw, syaw])

	# Quỹ đạo độc lập: trăng full (dayf 14.8) phải mọc 18h/lặn 6h, lên cao nhất nửa đêm.
	print("-- moon daily path (full moon dayf=14.8) --")
	for hour in [6.0, 12.0, 18.0, 22.0, 0.0, 3.0]:
		SkyLight.update_sky(mat, hour, 0.0, 14.8)
		var mdir: Vector3 = mat.get_shader_parameter("moon_dir")
		var elev := rad_to_deg(asin(clamp(mdir.y, -1.0, 1.0)))
		var myaw := rad_to_deg(atan2(mdir.z, mdir.x))
		print("hour %5.1f moon_elev=%6.1f moon_yaw=%6.1f" % [hour, elev, myaw])

	# Nguyệt thực: tìm chu kỳ trăng tròn đủ điều kiện (15% random theo hash).
	var found := false
	for cycle in range(0, 40):
		var d: float = cycle * 29.53 + 14.76
		SkyLight.update_sky(mat, 22.0, 0.0, d)
		var ecl: float = mat.get_shader_parameter("moon_eclipse")
		if ecl > 0.0:
			print("ECLIPSE found dayf=%5.1f (cycle %d) ecl=%.2f" % [d, cycle, ecl])
			found = true
	print("eclipse_found=%s" % [str(found)])
	get_tree().quit(0)