extends Node

## Render 4 loáº¡i cÃ¢y á»Ÿ gÃ³c nhÃ¬n NGANG (cam y=thÃ¢n) Ä‘á»ƒ kiá»ƒm tra tÃ¡n kÃ­n
## (khÃ´ng cÃ²n khe rá»—ng giá»¯a cube) + Ä‘áº¿m sá»‘ MultiMesh draw call má»—i cÃ¢y.

const _Oak = preload("res://scripts/world/props/oak_prop.gd")
const _Dense = preload("res://scripts/world/props/dense_tree_prop.gd")
const _Palm = preload("res://scripts/world/props/palm_prop.gd")
const _Orange = preload("res://scripts/world/props/orange_tree_prop.gd")

var _cam: Camera3D

func _ready() -> void:
	print("== props_visual ==")
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.current = true
	add_child(_cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -30, 0)
	light.light_energy = 1.4
	add_child(light)
	var ws := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.40, 0.42, 0.48)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	ws.environment = env
	add_child(ws)

	_spawn(_Oak, "plains", -7.5, Color(0.6, 0.85, 0.4))
	_spawn(_Dense, "plains", -2.5, Color(0.3, 0.6, 0.3))
	_spawn(_Palm, "river", 2.5, Color(0.2, 0.7, 0.5))
	_spawn(_Orange, "plains", 7.5, Color(0.9, 0.6, 0.2))

	await get_tree().process_frame
	await get_tree().process_frame
	for x in range(-8, 9, 4):
		await get_tree().process_frame
	print("frames done")
	for i in 30:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _take_shot("props_side", Vector3(0.0, 2.4, 15), Vector3.ZERO)
	await get_tree().create_timer(0.5).timeout
	await _take_shot("props_top", Vector3(0.0, 16, 0.001), Vector3.ZERO)

	get_tree().quit(0)

func _spawn(cls: Script, variant: String, y: float, tag_col: Color) -> void:
	var p: Node = cls.new()
	p.setup(variant)
	add_child(p)
	p.position = Vector3(y, 0, 0)
	p.set_birth_age_days(999.0)
	_override_unshaded(p)
	print("%s maturity=%s voxels=%d mm_drawcalls=%d" % [
		cls.resource_path.get_file(), p._stage,
		p._ordered.size() if p.get("_ordered") else -1,
		_count_mmi(p)
	])

func _override_unshaded(root: Node) -> void:
	# Bật UNSHADED cho mọi MMI để đo silhouette không nhiễu bởi bóng đổ.
	for c in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		c.material_override = mat

func _count_mmi(node: Node) -> int:
	var n := 0
	if node is MultiMeshInstance3D:
		n += 1
	for c in node.get_children():
		n += _count_mmi(c)
	return n

func _take_shot(name: String, cam_pos: Vector3, look: Vector3) -> void:
	_cam.position = cam_pos
	_cam.look_at(look, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/out/%s.png" % name)
	print("saved res://tools/out/%s.png" % name)