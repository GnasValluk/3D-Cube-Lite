extends CharacterBase
class_name PlayerCharacter

const _BlockHighlight := preload("res://scripts/items/entities/block_highlight.gd")
const _BlockData := preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Data := preload("res://scripts/world/chunk/chunk_data.gd")
const _Bow := preload("player_bow.gd")
const _Mortar := preload("player_mortar.gd")
const _Halberd := preload("player_halberd.gd")
const _Fishing := preload("player_fishing.gd")

var _mesh: PlayerMesh
var _anim: PlayerAnimator
var inventory: Inventory = null
var _inventory_open: bool = false
var _held_item: Dictionary = {}
var food: int = 20
var max_food: int = 20
var _food_timer: float = 0.0
var _food_action_timer: float = 0.0

signal food_changed(current: int, max_food: int)

var equipped_weapon: ItemDef = null
var equipped_head: ItemDef = null
var equipped_body: ItemDef = null
var equipped_legs: ItemDef = null
var equipped_feet: ItemDef = null
var equipped_hands: ItemDef = null
var equipped_back: ItemDef = null
var equipped_sub: ItemDef = null

var combo_step: int = 0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 0.55
var _bobber: Node3D = null
var _block_highlight: Node3D = null
var _target_block: Vector3 = Vector3.ZERO
var _has_target: bool = false

var _bow_aiming: bool = false
var _bow_charge: float = 0.0
var _bow_charge_rate: float = 0.35
var _bow_max_charge: float = 2.0
var _mortar_vertical_speed: float = 8.0
var _mortar_launch_angle_deg: float = 60.0
var _bow_aim_dir: Vector3 = Vector3.FORWARD
var _bow_indicator_line: MeshInstance3D = null
var _bow_indicator_target: MeshInstance3D = null
var _bow_indicator_aoe: MeshInstance3D = null
var _bow_indicator_root: Node3D = null
var _bow_string_node: Node3D = null

const HALBERD_CHARGE_TIME: float = 0.7
const HALBERD_MIN_RANGE: float = 6.0
const HALBERD_MAX_RANGE: float = 16.67
var _halberd_charge_time: float = -1.0
var _halberd_throwing: bool = false
var _halberd_aim_dir: Vector3 = Vector3.FORWARD
var _halberd_dashing: bool = false
var _halberd_dash_hit: Dictionary = {}

func _ensure_highlight() -> void:
	if _block_highlight != null:
		return
	_block_highlight = _BlockHighlight.new()
	_block_highlight.visible = false
	add_child(_block_highlight)

func _build_character() -> void:
	combo_step = 0
	combo_timer = 0.0
	move_speed = 4.2
	sprint_speed = 7.5
	jump_height = 1.1
	dash_speed = 10.0
	attack_duration = 0.50
	attack_power = 1
	defense = 0
	show_world_hp_bar = false
	lmb_cooldown = 0.0
	q_cooldown = 0.60
	r_cooldown = 1.0
	max_hp = 20
	max_stamina = 150
	stamina = 150
	stamina_regen = 10.0
	sprint_stamina_cost = 0.0
	stamina_cost_lmb = 0
	stamina_cost_q = 0
	stamina_cost_r = 0
	character_name = "Player"
	element = 0

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
	_setup_pickup_area()
	_add_world_voxel_bars()
	food_changed.emit(food, max_food)

func _add_world_voxel_bars() -> void:
	var bars := preload("res://scripts/ui/hud/world_voxel_bars.gd").new()
	add_child(bars)
	bars.setup(self)

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
	_world_hp_enabled = true

func _on_pickup_area_entered(area: Area3D) -> void:
	if area is DroppedItem:
		var item := area as DroppedItem
		if item.item_def == null or not item.can_pickup:
			return
		var remaining: int = pickup_item(item.item_def, item.item_count)
		if remaining <= 0:
			item.queue_free()
		else:
			item.item_count = remaining

func interact_with_nearby() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	for child in world.get_children():
		if child is Chest and child.is_player_nearby():
			child.open_ui()
			return
		if child is CraftingTable and child.is_player_nearby():
			child.open_ui()
			return
		if child is Furnace and child.is_player_nearby():
			child.open_ui()
			return

func pickup_item(item_def: ItemDef, count: int) -> int:
	if inventory == null:
		return count
	var remaining: int = inventory.add_item(item_def, count)
	if remaining < count:
		SFXManager.play_orb()
		_scroll_inventory_message(tr("PICKUP_MSG").format({"s": item_def.name, "n": count - remaining}))
	return remaining

func _scroll_inventory_message(msg: String) -> void:
	var label := Label.new()
	label.text = msg
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75, 0.9))
	label.add_theme_color_override("font_shadow_color", Color(0.3, 0.2, 0.15, 0.7))
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
				var prev_food: int = food
				food = mini(max_food, food + item.heal_amount)
				var healed: int = food - prev_food
				if food >= 18 and hp < max_hp:
					heal(1)
				inventory.remove_item(idx, 1)
				food_changed.emit(food, max_food)
				_scroll_inventory_message(tr("ATE_FOOD").format({"s": item.name, "d": healed}))
		ItemDef.Type.WEAPON:
			var old: ItemDef = equipped_weapon
			equipped_weapon = item
			inventory.remove_item(idx, 1)
			if old != null:
				inventory.add_item(old, 1)
			_update_weapon_mesh()
			_scroll_inventory_message(tr("EQUIP_MSG").format({"s": item.name}))
		ItemDef.Type.ARMOR:
			var old: ItemDef
			match item.armor_slot:
				ItemDef.ArmorSlot.HEAD: old = equipped_head; equipped_head = item
				ItemDef.ArmorSlot.BODY: old = equipped_body; equipped_body = item
				ItemDef.ArmorSlot.LEGS: old = equipped_legs; equipped_legs = item
				ItemDef.ArmorSlot.FEET: old = equipped_feet; equipped_feet = item
				ItemDef.ArmorSlot.HANDS: old = equipped_hands; equipped_hands = item
				ItemDef.ArmorSlot.BACK: old = equipped_back; equipped_back = item
				ItemDef.ArmorSlot.SUB: old = equipped_sub; equipped_sub = item
			inventory.remove_item(idx, 1)
			if old != null:
				inventory.add_item(old, 1)
			_scroll_inventory_message(tr("WEAR_MSG").format({"s": item.name}))
		ItemDef.Type.TOOL:
			var old: ItemDef = equipped_weapon
			equipped_weapon = item
			inventory.remove_item(idx, 1)
			if old != null:
				inventory.add_item(old, 1)
			_update_weapon_mesh()
			_scroll_inventory_message(tr("EQUIP_MSG").format({"s": item.name}))

func _place_twilight_gate(idx: int) -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	inventory.remove_item(idx, 1)
	var portal := PortalGate.new()
	portal.name = "PortalGate"
	portal.position = global_position + -global_transform.basis.z * 2.5
	portal.position.y = 0.25
	world.add_child(portal)
	_scroll_inventory_message(tr("PORTAL_PLACED"))

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
	var drop_pos: Vector3 = global_position + global_transform.basis.z * 2.5
	drop_pos.y += 0.3
	var fwd := global_transform.basis.z
	var vel := (fwd * 2.0 + Vector3(0, 3.0, 0)) * 0.7
	DroppedItem.spawn(world, item_def, drop_pos, count, vel, drop_pos.y)
	_scroll_inventory_message(tr("DROP_MSG").format({"s": item_def.name, "n": count}))

func _update_weapon_mesh() -> void:
	if _mesh == null or _mesh.weapon_pivot == null:
		return
	var pivot: Node3D = _mesh.weapon_pivot
	for ch in pivot.get_children():
		ch.queue_free()
	var item_id: String = equipped_weapon.id if equipped_weapon != null else ""
	if item_id.is_empty():
		if _bow_aiming:
			_Bow.cancel_aim(self)
		return
	if item_id in ["pickaxe", "shovel", "axe", "iron_sword", "fishing_rod", "iron_greatsword", "leather_gloves", "crossbow", "arrow", "watermelon_cannon", "watermelon_nuke_ammo", "pumpkin_mortar", "iron_halberd"]:
		ToolsMesh.build_held(pivot, item_id)
		if item_id == "crossbow":
			_bow_string_node = null
	else:
		var held_scale := Node3D.new()
		held_scale.scale = Vector3(1.5, 1.5, 1.5)
		pivot.add_child(held_scale)
		ItemMesh.build(held_scale, item_id)

## Cầm weapon trực tiếp từ hotbar (không remove khỏi inventory)
func equip_weapon_direct(item: ItemDef) -> void:
	print("[Player] equip_weapon_direct: ", item.id if item != null else "null")
	equipped_weapon = item
	_update_weapon_mesh()

func get_total_atk() -> int:
	var base: int = attack_power
	if equipped_weapon != null:
		base += equipped_weapon.atk_bonus
	return base

func get_total_def() -> int:
	var base: int = defense
	for slot in [equipped_head, equipped_body, equipped_legs, equipped_feet, equipped_hands, equipped_back, equipped_sub]:
		if slot != null:
			base += slot.def_bonus
	return base

func _unhandled_key_input(event: InputEvent) -> void:
	if _is_building_placing():
		return
	if not _active or not _is_player:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if _bow_aiming:
				if k.keycode in [KEY_E, KEY_B, KEY_I, KEY_ESCAPE, KEY_SPACE]:
					var is_mortar := equipped_weapon != null and equipped_weapon.id == "pumpkin_mortar"
					if is_mortar:
						_Mortar.cancel_aim(self)
					else:
						_Bow.cancel_aim(self)
					return
			if (_halberd_charge_time >= 0.0 or _halberd_throwing) and k.keycode in [KEY_E, KEY_B, KEY_I, KEY_ESCAPE]:
				_Halberd.cancel_aim(self)
				return
			if k.keycode == KEY_SPACE and _freeze_timer <= 0.0:
				_jbuf = JUMP_BUFFER
			if k.keycode == KEY_F1:
				_toggle_camera()
			if k.keycode == KEY_F5:
				if SaveManager:
					SaveManager.save_game()
					_scroll_inventory_message(tr("GAME_SAVED"))

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if _is_building_placing():
		return
	if event is InputEventMouseMotion:
		_update_block_target()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _bow_aiming:
			if equipped_weapon and equipped_weapon.id == "crossbow":
				_Bow.fire(self)
			elif equipped_weapon and equipped_weapon.id == "pumpkin_mortar":
				_Mortar.fire(self)
			elif equipped_weapon and equipped_weapon.id == "watermelon_cannon":
				_Bow.fire_watermelon_cannon(self)
				_Bow.cancel_aim(self)
			return
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _halberd_charge_time >= 0.0:
			if _halberd_throwing:
				_Halberd.fire_throw(self)
			else:
				_Halberd.do_melee(self)
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if _bow_aiming:
				var is_mortar := equipped_weapon != null and equipped_weapon.id == "pumpkin_mortar"
				if is_mortar:
					_Mortar.cancel_aim(self)
				else:
					_Bow.cancel_aim(self)
				return
			if _halberd_charge_time >= 0.0 or _halberd_throwing:
				_Halberd.cancel_aim(self)
				return
			# Mining — cúp/xẻng on RIGHT click
			if equipped_weapon != null:
				var wep_id: String = equipped_weapon.id
				if wep_id == "pickaxe" or wep_id == "shovel":
					var target: Vector3
					if _has_target:
						target = _target_block
					else:
						target = _raycast_target_block()
					if target != Vector3.ZERO:
						var owm: Node = _open_world_manager()
						if owm:
							var blk_id: int = owm.get_block(target.x, target.y, target.z)
							if blk_id != _Data.BlockID.AIR and blk_id != _Data.BlockID.WATER:
								var can_dig: bool = false
								if wep_id == "pickaxe":
									can_dig = not _is_soft_block(target.x, target.y, target.z)
								else:
									can_dig = _is_soft_block(target.x, target.y, target.z)
								if can_dig:
									var old_block: int = owm.break_block(target.x, target.y, target.z)
									if old_block != 0:
										var item_id: String = _Data.BLOCK_TO_ITEM.get(old_block, "")
										if not item_id.is_empty():
											var def: ItemDef = ItemDatabase.items_db.get(item_id) as ItemDef
											if def:
												DroppedItem.spawn(owm, def, target)
										SFXManager.play_block_break()
								else:
									_scroll_inventory_message("(không thể đào)")
					return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var world := get_tree().current_scene
			if world:
				for ch in world.get_children():
					if ch is Chest and ch.is_player_nearby():
						ch.open_ui()
						return
					if ch is CraftingTable and ch.is_player_nearby():
						ch.open_ui()
						return
					if ch is Furnace and ch.is_player_nearby():
						ch.open_ui()
						return
			if _bow_aiming:
				return
			if equipped_weapon != null:
				match equipped_weapon.id:
					"crossbow": _Bow.start_aim(self); return
					"pumpkin_mortar": _Mortar.start_aim(self); return
					"watermelon_cannon": _Bow.start_cannon_aim(self); return
					"fishing_rod": _Fishing.action(self); return
					"iron_halberd": return
			if _freeze_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
				var wep_id: String = equipped_weapon.id if equipped_weapon else ""
				var is_heavy: bool = wep_id == "axe" or wep_id == "pickaxe"
				if is_heavy:
					if _attack_timer > 0.0: return
					combo_step = 0
				else:
					var max_step: int = 1 if wep_id == "iron_greatsword" else 2
					if combo_timer > 0.0 and combo_step < max_step:
						combo_step += 1
					elif _attack_timer <= 0.0:
						combo_step = 0
					else:
						return
					combo_timer = COMBO_WINDOW
				if not try_skill(stamina_cost_lmb):
					return
				_aim_dir = _calc_aim_dir()
				var fwd := global_transform.basis.z
				if _aim_dir.dot(fwd) < 0.99:
					rotation.y = atan2(_aim_dir.x, _aim_dir.z)
				_lmb_cd = 0.0
				match wep_id:
					"pickaxe": attack_duration = 0.65; _melee_hit_progress = 0.35
					"axe": attack_duration = 0.85; _melee_hit_progress = 0.35
					"iron_greatsword": attack_duration = 1.00; _melee_hit_progress = 0.40
					"leather_gloves": attack_duration = 0.35; _melee_hit_progress = 0.20
					_: attack_duration = 0.50; _melee_hit_progress = 0.25
				_attack_timer = attack_duration * (2.0 if _underwater else 1.0)
				_state = State.ATTACK
				_melee_hit_once = false
			return

func _on_bobber_done(item_id: String) -> void:
	_Fishing.on_bobber_done(self, item_id)

func _open_world_manager() -> OpenWorldManager:
	var ch: Node = self
	while ch:
		if ch is OpenWorldManager:
			return ch
		ch = ch.get_parent()
	# Fallback — OpenWorldManager might be a sibling node
	var tree := get_tree()
	if tree == null: return null
	var root := tree.current_scene
	if root == null: return null
	for child in root.get_children():
		if child is OpenWorldManager:
			return child
	return null

func _is_soft_block(bx: float, by: float, bz: float) -> bool:
	var owm := _open_world_manager()
	if owm == null:
		return false
	var blk: int = owm.get_block(bx, by, bz)
	return blk == _Data.BlockID.SAND or blk == _Data.BlockID.SAND_DEEP or blk == _Data.BlockID.OCEAN_SAND or blk == _Data.BlockID.MUDDY_SAND or blk == _Data.BlockID.OCEAN_GRAVEL or blk == _Data.BlockID.DIRT or blk == _Data.BlockID.DARK_DIRT or blk == _Data.BlockID.GRASS or blk == _Data.BlockID.DARK_GRASS

func _update_block_target() -> void:
	_ensure_highlight()
	var can_mine := equipped_weapon != null and (equipped_weapon.id == "pickaxe" or equipped_weapon.id == "shovel")
	if not can_mine:
		_block_highlight.visible = false
		_has_target = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	var mouse_pos := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var space := get_world_3d().direct_space_state
	if space == null: return
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = from + dir * 200.0
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [self]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		_block_highlight.visible = false
		_has_target = false
		return
	var hit_pos: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var bx := floorf(hit_pos.x - normal.x * 0.001) + 0.5
	var bz := floorf(hit_pos.z - normal.z * 0.001) + 0.5
	var ly := _BlockData.world_y_to_layer(hit_pos.y - normal.y * 0.001)
	var by := _BlockData.layer_to_world_y(ly)
	_target_block = Vector3(bx, by, bz)
	_has_target = true
	_block_highlight.show_at(_target_block)

func _process(delta: float) -> void:
	var is_cannon_aiming := _bow_aiming and equipped_weapon != null and equipped_weapon.id == "watermelon_cannon"
	var is_mortar_aiming := _bow_aiming and equipped_weapon != null and equipped_weapon.id == "pumpkin_mortar"
	var is_bow_aim_no_cannon := _bow_aiming and not is_cannon_aiming and not is_mortar_aiming and not _halberd_throwing
	if is_bow_aim_no_cannon:
		var reduced := 3.6 * 0.55
		move_speed = reduced
		sprint_speed = reduced
	elif is_cannon_aiming or is_mortar_aiming:
		move_speed = 3.6 * 0.70
		sprint_speed = 6.8 * 0.70
	elif _halberd_charge_time >= 0.0 or _halberd_throwing:
		var reduced := 3.6 * 0.55
		move_speed = reduced
		sprint_speed = reduced
	else:
		move_speed = 3.6
		sprint_speed = 6.8
	super._process(delta)
	_food_timer += delta
	_food_action_timer += delta
	if _food_timer >= 8.0 and food > 0:
		_food_timer = 0.0
		food -= 1
		food_changed.emit(food, max_food)
	if _food_action_timer >= 4.0:
		if food <= 0:
			_food_action_timer = 0.0
			_Damage.take_damage(self, 1)
		elif food >= 18 and hp < max_hp:
			_food_action_timer = 0.0
			heal(1)
	combo_timer = max(combo_timer - delta, 0.0)
	_update_block_target()
	_Bow.update_pose(self)
	if equipped_weapon != null and equipped_weapon.id == "iron_halberd":
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _halberd_charge_time < 0.0:
				_halberd_charge_time = 0.0
			_halberd_charge_time += delta
			if _halberd_charge_time >= HALBERD_CHARGE_TIME and not _halberd_throwing:
				_Halberd.start_throw_aim(self)
			if _halberd_throwing:
				_Halberd.update_aim(self, delta)
	if _bow_aiming:
		if _state == State.HIT:
			var is_mortar := equipped_weapon != null and equipped_weapon.id == "pumpkin_mortar"
			if is_mortar:
				_Mortar.cancel_aim(self)
			else:
				_Bow.cancel_aim(self)
		else:
			var is_mortar := equipped_weapon != null and equipped_weapon.id == "pumpkin_mortar"
			if is_mortar:
				_Mortar.update_aim(self, delta)
			else:
				_Bow.update_aim(self, delta)
	if _halberd_throwing and _state == State.HIT:
		_Halberd.cancel_aim(self)

func _on_dash() -> void:
	_Halberd.on_dash(self)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _halberd_dashing:
		if _state == State.DASH:
			_Halberd.check_dash_hit(self)
		else:
			_halberd_dashing = false

func _raycast_target_block() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null: return Vector3.ZERO
	var mouse_pos := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var space := get_world_3d().direct_space_state
	if space == null: return Vector3.ZERO
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = from + dir * 200.0
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [self]
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return Vector3.ZERO
	var normal: Vector3 = hit.normal
	var bx := floorf(hit.position.x - normal.x * 0.001) + 0.5
	var bz := floorf(hit.position.z - normal.z * 0.001) + 0.5
	var ly := _BlockData.world_y_to_layer(hit.position.y - normal.y * 0.001)
	var by := _BlockData.layer_to_world_y(ly)
	return Vector3(bx, by, bz)

func _ready() -> void:
	await super._ready()

func _animate(delta: float) -> void:
	_anim.animate(delta)
