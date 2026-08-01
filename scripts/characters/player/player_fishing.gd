class_name PlayerFishing
extends RefCounted

static func action(player) -> void:
	var holding_rod: bool = player.equipped_weapon != null and player.equipped_weapon.id == "fishing_rod"
	if holding_rod:
		if player._bobber != null:
			if player._bobber.reel_in():
				SFXManager.play_retrieve()
		else:
			cast_line(player)
	elif player._bobber != null:
		player._bobber.reel_in()

static func cast_line(player) -> void:
	var target: Vector3 = player._calc_aim_dir() * 8.0 + player.global_position
	target.y = 0.46
	player._damage_equipped_tool(1)
	var bob: Node = load("res://scripts/items/entities/fishing_bobber.gd").new()
	var root: Node = player.get_tree().current_scene
	if root:
		root.add_child(bob)
	else:
		player.add_child(bob)
	var pivot: Node3D = player._mesh.weapon_pivot if player._mesh != null else null
	bob.setup(player, target, pivot)
	player._bobber = bob
	SFXManager.play_cast()

static func on_bobber_done(player, item_id: String) -> void:
	player._bobber = null
	if item_id != "":
		ItemDatabase.ensure_db()
		var def: ItemDef = ItemDatabase.items_db.get(item_id)
		if def and player.inventory.add_item(def, 1) == 0:
			player._scroll_inventory_message("+1 " + def.name)
		else:
			player._scroll_inventory_message(player.tr("INVENTORY_FULL"))
	else:
		player._scroll_inventory_message(player.tr("FISH_MISS"))
