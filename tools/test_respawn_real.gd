extends Node3D

## Reproduce death/respawn inside the real open_world scene.

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_respawn_real: chết trong world thật ==")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	# Chờ world khởi động + player active
	for i in range(300):
		await get_tree().process_frame

	var player: Node3D = world.get_node_or_null("CharacterManager/Player") 
	_check(player != null, "world có node Player (null=%s)" % (player == null))
	if player == null:
		await WorldChunk.wait_for_tasks_async(get_tree())
		get_tree().quit(1)
		return
	_check(player._is_player, "Player._is_player=true")

	_check(player.is_alive, "player sống ban đầu")
	player.take_damage(9999, null)
	_check(not player.is_alive, "player chết")

	for i in range(150):
		await get_tree().physics_frame

	_check(player.is_alive, "player hồi sinh lại trong world thật (is_alive=%s)" % player.is_alive)
	_check(player._active, "player active lại (_active=%s)" % player._active)

	var chest: Node = get_tree().current_scene.get_node_or_null("DeathChest")
	_check(chest == null, "không còn rương đồ (đồ rơi thành DroppedItem)")
	var has_drop := false
	for ch in get_tree().current_scene.get_children():
		if ch is DroppedItem:
			has_drop = true
			break
	print("DEBUG | has_drop=%s" % has_drop)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)