extends Node

## Bisect: load world scene, sample sky; forward cam; then gradually free
## child subsystems to find which one knocks the sky to flat gray.

var _env_node: WorldEnvironment

func _sample_line() -> void:
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	for j in 3:
		var y := int(h * (0.05 + 0.07 * j))
		var c := img.get_pixel(w / 2, y)
		print("    y=%3d%% rgb=(%.3f %.3f %.3f)" % [int(100 * y / h), c.r, c.g, c.b])

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	print("== bisect ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 12:
		await get_tree().process_frame
	print("full scene:")
	_sample_line()

	# free subsystems một nhóm một
	var groups := [
		["HUD"],
		["CameraRig", "TPCameraRig"],
		["PlacementSystem", "ExploreSystem"],
		["FishSpawner", "PigSpawner"],
		["LotusLightManager", "RoadLampManager"],
		["RainManager"],
	]
	for g in groups:
		for name in g:
			var n := inst.get_node_or_null(name)
			if n:
				n.queue_free()
		await _wait_frames(6)
		print("after freeing %s:" % str(g))
		_sample_line()
	get_tree().quit(0)