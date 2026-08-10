extends Node

## List every WorldEnvironment node in the ENTIRE tree (root + scene + autoloads),
## with their environment instance and active state.

func _ready() -> void:
	print("== all_we_nodes ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 20:
		await get_tree().process_frame

	var root := get_tree().root
	for nd in root.find_children("*", "WorldEnvironment", true, false):
		var we := nd as WorldEnvironment
		var env: Environment = we.environment
		print("WE node path=%s env_set=%s inst=%s mode=%s sky=%s"
			% [we.get_path(), str(env != null), str(env.get_instance_id() if env else -1),
			env.background_mode if env else -1, str(env.sky != null if env else false)])

	var cam: Camera3D = get_viewport().get_camera_3d()
	print("active cam=%s parent=%s" % [cam.name, cam.get_parent().name])
	get_tree().quit(0)