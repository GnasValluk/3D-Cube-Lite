extends Node

## Render skin hiện tại ra PNG (front + side) để đánh giá chi tiết.

const _Skin = preload("res://scripts/characters/player/player_skin.gd")

var _cam: Camera3D

func _ready() -> void:
	print("== skin_baseline ==")
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.current = true
	add_child(_cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.6
	add_child(light)
	var ws := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.50, 0.58)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	ws.environment = env
	add_child(ws)

	for s in _Skin.all():
		var sid: String = s["id"]
		var root := CharacterBody3D.new()
		add_child(root)
		var pm := _Skin.make_mesh(sid)
		pm.set_palette(_Skin.palette_for(sid))
		pm.build(root)
		root.position = Vector3(0, 0, 0)
		await _shot(sid + "_front", Vector3(0, 1.0, 3.0), Vector3(0, 1.0, 0))
		await _shot(sid + "_side", Vector3(3.0, 1.0, 0), Vector3(0, 1.0, 0))
		root.queue_free()

	print("TOTAL done")
	get_tree().quit(0)

func _shot(name: String, cam_pos: Vector3, look: Vector3) -> void:
	_cam.position = cam_pos
	_cam.look_at(look, Vector3.UP)
	for i in 3:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/out/%s.png" % name)
	print("saved res://tools/out/%s.png" % name)
