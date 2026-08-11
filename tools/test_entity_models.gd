extends Node

## Render 3 model (chest, crafting table, furnace) ra PNG để đánh giá chi tiết
## + đếm số box mỗi model. Cách dùng:
##   Godot --resolution 640x480 --quit-after 200 res://tools/test_entity_models.tscn

const _Chest = preload("res://scripts/items/entities/chest.gd")
const _Craft = preload("res://scripts/items/entities/crafting_table.gd")
const _Furnace = preload("res://scripts/items/entities/furnace.gd")

var _cam: Camera3D

func _ready() -> void:
	print("== entity_models ==")
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

	_spawn(_Chest, "chest", -3.0)
	_spawn(_Craft, "craft", 0.0)
	_spawn(_Furnace, "furnace", 3.0)

	for i in 10:
		await get_tree().process_frame
	await _shot("entity_front", Vector3(0, 0.9, 7.5), Vector3(0, 0.6, 0))
	await _shot("entity_side", Vector3(6.5, 0.9, 1.5), Vector3(0, 0.6, 0))

	print("TOTAL done")
	get_tree().quit(0)

func _spawn(cls: Script, label: String, x: float) -> void:
	var e: Node = cls.new()
	add_child(e)
	e.position = Vector3(x, 0, 0)
	var boxes := _count_box(e)
	print("%s boxes=%d" % [label, boxes])

func _count_box(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D:
		if node.mesh is BoxMesh:
			n += 1
	for c in node.get_children():
		n += _count_box(c)
	return n

func _shot(name: String, cam_pos: Vector3, look: Vector3) -> void:
	_cam.position = cam_pos
	_cam.look_at(look, Vector3.UP)
	for i in 3:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/out/%s.png" % name)
	print("saved res://tools/out/%s.png" % name)
