extends Node

## Sketch render smoke: instantiate real_world_environment + camera, render a few
## frames on the actual D3D12 driver, then quit. Captures shader/sky errors.

func _ready() -> void:
	print("== sky_render_sketch ==")
	var env_script: GDScript = load("res://scripts/world/environment/real_world_environment.gd")
	var we: WorldEnvironment = env_script.new() as WorldEnvironment
	add_child(we)
	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(0, 5, 8)
	cam.look_at(Vector3.ZERO)
	for i in 10:
		await get_tree().process_frame
	print("== sky_render_sketch done ==")
	get_tree().quit(0)