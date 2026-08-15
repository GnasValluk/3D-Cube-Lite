extends Node3D

## Diagnostic: die at a specific position, then check where the dropped items
## (DroppedItem thay rương) spawn relative to the death position.

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_chest_pos: vi tri do roi khi chet ===")
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
	ItemDatabase.ensure_db()
	var db: Dictionary = ItemDatabase.items_db
	var stone: ItemDef = db.get("block_stone") as ItemDef
	_check(stone != null, "db có block_stone")
	player.inventory.add_item(stone, 3)
	print("DEBUG setup | alive=", player.is_alive, " slot0_item=", (player.inventory.slots[0].item.id if (player.inventory.slots[0].item and not player.inventory.slots[0].is_empty()) else "null"))

	var death_pos: Vector3 = player.global_position
	player.take_damage(9999, null)
	_check(not player.is_alive, "player chết")
	print("DEBUG after_damage | alive=", player.is_alive, " inv_empty=", player.inventory.is_empty())

	for i in range(180):
		await get_tree().physics_frame

	var chest: Node = get_tree().current_scene.get_node_or_null("DeathChest")
	_check(chest == null, "không còn rương đồ (đồ rơi thành DroppedItem)")
	print("DEBUG | inv_empty=%s net_active=%s" % [
		player.inventory.is_empty() if player.inventory else true,
		Net.is_active()])
	var drops: Array = []
	for ch in get_tree().current_scene.get_children():
		if ch is DroppedItem:
			drops.append("%s(%d)@%s" % [ch.item_def.id if ch.item_def else "?", ch.item_count, ch.global_position])
	print("DEBUG | drop_children=%d -> %s" % [drops.size(), "|".join(drops)])
	var nearest_dist := INF
	var stone_dropped := false
	for ch in get_tree().current_scene.get_children():
		if ch is DroppedItem and ch.item_def != null and ch.item_def.id == "block_stone":
			stone_dropped = true
			var d: float = death_pos.distance_to(ch.global_position)
			if d < nearest_dist:
				nearest_dist = d
	print("DEBUG | dropped=%s nearest_dist=%.2f" % [stone_dropped, nearest_dist])
	_check(stone_dropped, "đá rơi thành DroppedItem tại điểm chết")
	_check(nearest_dist < 4.0,
		"đồ rơi gần điểm chết (dist < 4, nearest=%.2f)" % nearest_dist)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
