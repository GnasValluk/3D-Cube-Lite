extends Node3D

## Reproduce death+respawn inside the real open_world with FULL gear:
## iron armor + weapon + backpack (45-slot inventory) filled to the brim.
## Goal: catch script errors in the death-chest path that leave the player
## dead and physics-disabled forever ("bị đơ, không spawn được").

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_respawn_kit: chết + giáp + ba lô + kho đầy ==")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	for i in range(300):
		await get_tree().process_frame

	var player: Node3D = world.get_node_or_null("CharacterManager/Player")
	_check(player != null, "world có Player")
	if player == null:
		await WorldChunk.wait_for_tasks_async(get_tree())
		get_tree().quit(1)
		return

	# Trang bị đầy đủ: vũ khí + 4 món giáp sắt + ba lô.
	var db: Dictionary = ItemDatabase.items_db
	for id in ["iron_sword", "iron_helmet", "iron_chestplate", "iron_leggings", "iron_boots", "leather_backpack"]:
		_check(db.has(id), "db có " + id)
	player.equipped_weapon = db.get("iron_sword")
	player.equipped_head = db.get("iron_helmet")
	player.equipped_body = db.get("iron_chestplate")
	player.equipped_legs = db.get("iron_leggings")
	player.equipped_feet = db.get("iron_boots")
	player.equipped_back = db.get("leather_backpack")
	player._refresh_backpack_state()
	_check(player.inventory != null, "inventory có")
	var inv_size: int = player.inventory.slots.size() if player.inventory else 0
	_check(inv_size == 40, "ba lô mở rộng kho lên 40 slot (size=%d)" % inv_size)

	# Đưa vũ khí vào hotbar slot 0 + equip đúng luồng thật để hotbar không tháo ra.
	if player.inventory != null:
		var sword: ItemDef = db.get("iron_sword")
		player.inventory.slots[0].item = sword
		player.inventory.slots[0].count = 1
		player.equip_weapon_direct(sword, 0)

	# Đổ đầy slot để ép lối resize_slots khi chết.
	var fill_def: ItemDef = db.get("stone")
	for i in range(player.inventory.slots.size()):
		if player.inventory.slots[i].is_empty():
			player.inventory.slots[i].item = fill_def
			player.inventory.slots[i].count = 1
	player._update_armor_mesh()
	player._update_weapon_mesh()

	_check(player.is_alive, "player sống ban đầu")
	print("DEBUG | equipped_weapon=%s head=%s inv_filled=%d" % [
		player.equipped_weapon.id if player.equipped_weapon else "null",
		player.equipped_head.id if player.equipped_head else "null",
		player.inventory.count_filled_slots() if player.inventory else -1])
	player.take_damage(9999, null)
	_check(not player.is_alive, "player chết")
	# Nhặt lỗi scripts khi spawn rương/hồi sinh (death_timer 1.8s)
	for i in range(200):
		await get_tree().physics_frame

	_check(player.is_alive, "player HỒI SINH sau khi chết (is_alive=%s)" % player.is_alive)
	_check(player._active, "player active lại (_active=%s)" % player._active)
	_check(player.is_physics_processing(), "physics bật lại")
	_check(player.equipped_weapon == null, "vũ khí đã tháo khi chết")

	var chest: Node = get_tree().current_scene.get_node_or_null("DeathChest")
	_check(chest == null, "không còn rương đồ (đồ rơi thành DroppedItem)")
	var has_sword := false
	var has_helmet := false
	var drop_ids: Array[String] = []
	for ch in current_scene_children_drops():
		if ch.item_def != null:
			drop_ids.append("%s(%d)" % [ch.item_def.id, ch.item_count])
			if ch.item_def.id == "iron_sword":
				has_sword = true
			if ch.item_def.id == "iron_helmet":
				has_helmet = true
	print("DROP_IDS | " + "|".join(drop_ids))
	_check(has_sword, "rơi ra DroppedItem chứa kiếm")
	_check(has_helmet, "rơi ra DroppedItem chứa giáp")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

func current_scene_children_drops() -> Array:
	var out: Array = []
	for ch in get_tree().current_scene.get_children():
		if ch is DroppedItem:
			out.append(ch)
	return out