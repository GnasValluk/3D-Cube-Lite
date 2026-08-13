extends Node3D

## Diagnostic: die at a specific position, then check where the DeathChest
## spawns relative to the death position (regression from commit 4eb2e92).

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_chest_pos: vi tri death chest ===")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	for i in range(300):
		await get_tree().process_frame

	var player: Node3D = world.get_node_or_null("CharacterManager/Player")
	if player == null:
		get_tree().quit(1)
		return

	# Teleport player away from spawn, put an item in inventory, then die.
	player.global_position = Vector3(120, 8, 90)
	var db: Dictionary = ItemDatabase.items_db
	var stone: ItemDef = db.get("stone")
	player.inventory.slots[0].item = stone
	player.inventory.slots[0].count = 5

	var death_pos: Vector3 = player.global_position
	player.take_damage(9999, null)
	_check(not player.is_alive, "player chết")

	for i in range(180):
		await get_tree().physics_frame

	var chest: Node = get_tree().current_scene.get_node_or_null("DeathChest")
	_check(chest != null, "rương đồ spawn")
	if chest != null:
		var cp: Vector3 = chest.global_position
		print("DEBUG | death_pos=%s chest_pos=%s dist=%.2f" % [death_pos, cp, death_pos.distance_to(cp)])
		_check(cp.distance_to(death_pos) < 2.0,
			"rương nằm tại điểm chết (dist < 2)")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
