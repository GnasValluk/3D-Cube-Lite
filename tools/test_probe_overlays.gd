extends Node

## Probe: active camera + top-level CanvasLayers and their full-rect Controls (depth-limited).

func _corner() -> void:
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	print("corner tl=%s mid=%s" % [img.get_pixel(2, 2).to_html(false), img.get_pixel(w / 2, int(h * 0.1)).to_html(false)])

var _dump_count := 0

func _dump(node: Node, depth: int) -> void:
	if _dump_count > 60:
		return
	_dump_count += 1
	var pad := "  ".repeat(depth)
	if node is CanvasLayer:
		print("%sL %s visible=%s layer=%s count=%d" % [pad, node.name, str(node.visible), node.layer, node.get_child_count()])
	elif node is Control:
		var c := node as Control
		var color := "-"
		var cr: Variant = c.get("color")
		if cr is Color:
			color = (cr as Color).to_html(false)
		var st: Variant = c.get("style_box")
		if st is StyleBoxFlat:
			color = (st as StyleBoxFlat).bg_color.to_html(false)
		if c.anchor_left == 0.0 and c.anchor_top == 0.0 and c.anchor_right == 1.0 and c.anchor_bottom == 1.0:
			print("%sC *FULL* %s visible=%s color=%s self_mod=%s" % [pad, c.name, str(c.visible), color, (c.self_modulate.to_html(false) if true else "")])
	if depth < 3 and node.get_child_count() < 30:
		for ch in node.get_children():
			_dump(ch, depth + 1)

func _ready() -> void:
	print("== probe_overlays2 ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 15:
		await get_tree().process_frame
	var cam: Camera3D = get_viewport().get_camera_3d()
	print("active cam=%s pos=%s rot=%s env_override=%s" % [cam.name, cam.global_position, cam.rotation_degrees, cam.environment])
	for ch in inst.get_children():
		_dump(ch, 1)
	print("--end dump--")
	_corner()
	get_tree().quit(0)