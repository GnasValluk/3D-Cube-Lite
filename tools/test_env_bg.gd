extends Node

## Decisive bisect in FULL scene:
## 1) free camera rigs -> custom camera straight up
## 2) background_mode = BG_COLOR red  -> is env applied at all?
## 3) replace env.sky with trivial green shader -> is sky drawing broken?

func _snap() -> Array[Color]:
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	return [
		img.get_pixel(w / 2, int(h * 0.10)),
		img.get_pixel(w / 2, int(h * 0.30)),
		img.get_pixel(w / 2, int(h * 0.50)),
	]

func _ready() -> void:
	print("== env_bg_test ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 20:
		await get_tree().process_frame

	# Free camera rigs so they don't steal `current`.
	var rig := inst.get_node_or_null("CameraRig") as Node
	var tp := inst.get_node_or_null("TPCameraRig") as Node
	rig.queue_free()
	tp.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	var env := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var rw := env as RealWorldEnvironment
	print("env.free? exists=%s" % str(env != null))

	# Own camera straight up at small height
	var cam := Camera3D.new()
	cam.current = true
	cam.rotation_degrees = Vector3(90, 0, 0)
	cam.global_position = Vector3(0, 3, 0)
	add_child(cam)
	for i in 4:
		await get_tree().process_frame
	print("A) noon sky real-world = %s" % str(_snap()))

	# B) Force BG_COLOR red
	var e: Environment = rw.environment
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(1, 0, 0)
	for i in 4:
		await get_tree().process_frame
	print("B) BG_COLOR red        = %s (top should be red if env applied)" % str(_snap()))

	# Skip sky for now - restore
	e.background_mode = Environment.BG_SKY

	# C) Replace sky with trivial green shader
	var sh := Shader.new()
	sh.code = "shader_type sky; void sky() { COLOR = vec3(0.0, 1.0, 0.0); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var sky := Sky.new()
	sky.sky_material = mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	e.sky = sky
	for i in 4:
		await get_tree().process_frame
	print("C) green trivial sky   = %s (top should be green if sky works)" % str(_snap()))
	get_tree().quit(0)