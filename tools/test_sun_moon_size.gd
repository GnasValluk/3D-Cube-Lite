extends Node

## Render sky day/night PNG để kiểm tra kích thước mặt trời/trăng sau khi nhỏ lại.
## dayf 14.8 = full moon (trăng đối diện mặt trời).

var _cam: Camera3D

func _ready() -> void:
	print("== sun_moon_size ==")
	var env_script: GDScript = load("res://scripts/world/environment/real_world_environment.gd")
	var we: WorldEnvironment = env_script.new() as WorldEnvironment
	add_child(we)
	we.set_process(false)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 60.0
	add_child(_cam)
	_cam.global_position = Vector3(0, 6, 8)
	_cam.look_at(Vector3(0, 0, 0))
	for i in 4:
		await get_tree().process_frame
	var rw := we as RealWorldEnvironment
	var mat: ShaderMaterial = rw._sky_mat

	# Trưa: mặt trời trên đỉnh (12h) — đĩa phải nhỏ.
	SkyLight.update_sky(mat, 12.0, 0.0, 14.8)
	await _shot("sun_small_noon")

	# Hoàng hôn 17h: mặt trời thấp.
	SkyLight.update_sky(mat, 17.0, 0.0, 14.8)
	await _shot("sun_small_dusk")

	# Đêm 22h: trăng lên cao, sáng rõ.
	SkyLight.update_sky(mat, 22.0, 0.0, 14.8)
	await _shot("moon_night")

	# Nửa đêm 0h: trăng đỉnh đầu.
	SkyLight.update_sky(mat, 0.0, 0.0, 14.8)
	await _shot("moon_midnight")

	print("TOTAL done")
	get_tree().quit(0)

func _shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/out/%s.png" % name)
	print("saved res://tools/out/%s.png" % name)
