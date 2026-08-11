extends Node

## Chụp cận cảnh từng model (chest đóng/mở, crafting table, furnace) ra PNG.

const _Chest = preload("res://scripts/items/entities/chest.gd")
const _Craft = preload("res://scripts/items/entities/crafting_table.gd")
const _Furnace = preload("res://scripts/items/entities/furnace.gd")

var _cam: Camera3D

func _ready() -> void:
	print("== entity_close ==")
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.current = true
	add_child(_cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
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

	# chest
	var chest: Node = _Chest.new()
	add_child(chest)
	chest.position = Vector3(-2.5, 0, 0)
	await _shot("chest_close", Vector3(-2.5, 0.9, 3.2), Vector3(-2.5, 0.5, 0))
	# mở chest
	chest.open_ui()
	for i in 30:
		await get_tree().process_frame
	await _shot("chest_open", Vector3(-2.5, 0.9, 3.2), Vector3(-2.5, 0.5, 0))
	chest.queue_free()

	# craft
	var craft: Node = _Craft.new()
	add_child(craft)
	craft.position = Vector3(2.5, 0, 0)
	await _shot("craft_close", Vector3(2.5, 1.1, 3.4), Vector3(2.5, 0.6, 0))
	craft.queue_free()

	# furnace
	var furnace: Node = _Furnace.new()
	add_child(furnace)
	furnace.position = Vector3(7.5, 0, 0)
	await _shot("furnace_close", Vector3(7.5, 0.9, 3.4), Vector3(7.5, 0.5, 0))
	furnace.queue_free()

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
