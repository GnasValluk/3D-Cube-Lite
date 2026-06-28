extends CharacterBase
class_name PlayerCharacter

const _ChestScript = preload("res://scripts/items/chest.gd")

var _mesh: PlayerMesh
var _anim: PlayerAnimator
var inventory: Inventory = null
var _inventory_open: bool = false
var _held_item: Dictionary = {}
var equipped_weapon: ItemDef = null
var equipped_armor: ItemDef = null
var _start_chest = null

func _build_character() -> void:
	move_speed = 4.2
	sprint_speed = 8.5
	jump_height = 1.3
	dash_speed = 16.0
	attack_duration = 0.4
	attack_power = 80
	defense = 20
	melee_damage = 12
	lmb_cooldown = 1.2
	q_cooldown = 1.0
	r_cooldown = 1.0
	max_hp = 500
	mana_cost_lmb = 0
	mana_cost_q = 9999
	mana_cost_r = 9999
	character_name = "Player"
	element = Element.ANH_SANG

	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.28
	cs.height = 0.90
	col.shape = cs
	col.position = Vector3(0, 0.45, 0)
	add_child(col)

	_mesh = PlayerMesh.new()
	_mesh.build(self)
	_rig = _mesh.rig

	_anim = PlayerAnimator.new()
	_anim.setup(_mesh, self)

	inventory = Inventory.new()
	Inventory.seed_inventory(inventory)

	_setup_pickup_area()
	call_deferred("_spawn_start_chest")

func _setup_pickup_area() -> void:
	var pickup := Area3D.new()
	pickup.name = "PickupArea"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	shape.shape = sphere
	pickup.add_child(shape)
	pickup.area_entered.connect(_on_pickup_area_entered)
	add_child(pickup)

func _on_pickup_area_entered(area: Area3D) -> void:
	if area is DroppedItem:
		var item := area as DroppedItem
		if item.item_def == null:
			return
		var remaining: int = pickup_item(item.item_def, item.item_count)
		if remaining <= 0:
			item.queue_free()
		else:
			item.item_count = remaining

func _spawn_start_chest() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	var chest := _ChestScript.new()
	var forward: Vector3 = -global_transform.basis.z
	chest.position = global_position + forward * 3.0 + Vector3(0, 0, 0)
	chest.position.y = 0.0
	world.add_child(chest)
	_start_chest = chest

	var db: Dictionary = Inventory.create_item_db()
	var gate_def: ItemDef = db.get("twilight_gate")
	if gate_def:
		chest.inventory.add_item(gate_def, 1)

func interact_with_nearby() -> void:
	if _start_chest == null:
		return
	var dist: float = global_position.distance_to(_start_chest.global_position)
	if dist < 3.0:
		_start_chest.open_ui()

func pickup_item(item_def: ItemDef, count: int) -> int:
	if inventory == null:
		return count
	var remaining: int = inventory.add_item(item_def, count)
	if remaining < count:
		_scroll_inventory_message("Nhặt: " + item_def.name + (" x%d" % (count - remaining)))
	return remaining

func _scroll_inventory_message(msg: String) -> void:
	var label := Label.new()
	label.text = msg
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7, 0.9))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.position = Vector2(300, 300)
	label.size = Vector2(400, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hud: HUD = _find_hud()
	if hud:
		hud.add_child(label)
	else:
		var top := get_tree().current_scene
		if top:
			top.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(label.queue_free).set_delay(2.2)

func _find_hud() -> HUD:
	var root := get_tree().current_scene
	if root == null:
		return null
	for child in root.get_children():
		if child is HUD:
			return child
	return null

func use_item_from_inventory(idx: int) -> void:
	if inventory == null:
		return
	var slot: ItemSlot = inventory.slots[idx]
	if slot.is_empty():
		return
	var item: ItemDef = slot.item

	if item.id == "twilight_gate":
		_place_twilight_gate(idx)
		return

	match item.type:
		ItemDef.Type.FOOD:
			if item.heal_amount > 0:
				heal(item.heal_amount)
				inventory.remove_item(idx, 1)
				_scroll_inventory_message("Đã ăn " + item.name + " (+%d HP)" % item.heal_amount)
		ItemDef.Type.WEAPON:
			var old: ItemDef = equipped_weapon
			equipped_weapon = item
			inventory.remove_item(idx, 1)
			if old != null:
				inventory.add_item(old, 1)
			_scroll_inventory_message("Trang bị: " + item.name)
		ItemDef.Type.ARMOR:
			var old: ItemDef = equipped_armor
			equipped_armor = item
			inventory.remove_item(idx, 1)
			if old != null:
				inventory.add_item(old, 1)
			_scroll_inventory_message("Mặc: " + item.name)
		ItemDef.Type.TOOL:
			var old: ItemDef = equipped_weapon
			equipped_weapon = item
			inventory.remove_item(idx, 1)
			if old != null:
				inventory.add_item(old, 1)
			_scroll_inventory_message("Trang bị: " + item.name)

func _place_twilight_gate(idx: int) -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	inventory.remove_item(idx, 1)
	var portal := PortalGate.new()
	portal.name = "PortalGate"
	var forward: Vector3 = -global_transform.basis.z
	portal.position = global_position + forward * 2.5
	portal.position.y = 0.0
	world.add_child(portal)
	_scroll_inventory_message("Đã đặt Cổng Twilight!")

func drop_item(idx: int) -> void:
	if inventory == null:
		return
	var slot: ItemSlot = inventory.slots[idx]
	if slot.is_empty():
		return
	var item_def: ItemDef = slot.item
	var count: int = slot.count

	var world := get_tree().current_scene
	if world == null:
		return

	inventory.remove_item(idx, count)
	DroppedItem.spawn(world, item_def, global_position + global_transform.basis.z * (-1.5), count)
	_scroll_inventory_message("Vứt bỏ: " + item_def.name + (" x%d" % count))

func get_total_atk() -> int:
	var base: int = melee_damage
	if equipped_weapon != null:
		base += equipped_weapon.atk_bonus
	return base

func get_total_def() -> int:
	var base: int = defense
	if equipped_armor != null:
		base += equipped_armor.def_bonus
	return base

func _unhandled_key_input(event: InputEvent) -> void:
	if _is_building_placing():
		return
	if not _active or not _is_player:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_SPACE and _freeze_timer <= 0.0:
				_jbuf = JUMP_BUFFER
			if k.keycode == KEY_F1:
				_toggle_camera()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if _is_building_placing():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _lmb_cd <= 0.0 and _freeze_timer <= 0.0 and _attack_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
				_aim_dir = _calc_aim_dir()
				var fwd := global_transform.basis.z
				if _aim_dir.dot(fwd) < 0.99:
					rotation.y = atan2(_aim_dir.x, _aim_dir.z)
				_lmb_cd = lmb_cooldown
				_attack_timer = attack_duration
				_state = State.ATTACK
				_melee_hit_once = false
				_on_primary_attack()

func _animate(delta: float) -> void:
	_anim.animate(delta)
