extends Node

## Full scene, camera at high altitude looking up (pure sky), sample + probe fog.

func _ready() -> void:
	print("== scene_high_up ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 15:
		await get_tree().process_frame
	var env := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var cam := Camera3D.new()
	cam.current = true
	cam.rotation_degrees = Vector3(90, 0, 0)
	cam.global_position = Vector3(0, 120, 0)
	add_child(cam)
	for i in 6:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	for j in 5:
		var y := int(h * (0.15 + 0.16 * j))
		var c := img.get_pixel(w / 2, y)
		print("  y=%3d%% rgb=(%.3f %.3f %.3f)" % [int(100 * y / h), c.r, c.g, c.b])
	if env:
		var rw := env as RealWorldEnvironment
		var e: Environment = rw.environment if rw else null
		if e:
			print("bg_mode=%d sky!=null=%s fog_enabled=%s fog_density=%.4f fog_hd=%.4f"
				% [e.background_mode, str(e.sky != null), str(e.fog_enabled), e.fog_density, e.fog_height_density])
	get_tree().quit(0)