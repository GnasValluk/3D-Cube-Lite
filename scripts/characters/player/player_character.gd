extends CharacterBase
class_name PlayerCharacter

const _BlockHighlight := preload("res://scripts/items/entities/block_highlight.gd")
const _BlockData := preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Data := preload("res://scripts/world/chunk/chunk_data.gd")

var _mesh: PlayerMesh
var _anim: PlayerAnimator
var inventory: Inventory = null
var _inventory_open: bool = false
var _held_item: Dictionary = {}
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

func _init_highlight() -> void:
	_block_highlight = _BlockHighlight.new()
	_block_highlight.visible = false
	var root := get_tree().current_scene
	if root:
		root.add_child(_block_highlight)
	else:
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
	defense = 25
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
				heal(item.heal_amount)
				inventory.remove_item(idx, 1)
				_scroll_inventory_message(tr("ATE_FOOD").format({"s": item.name, "d": item.heal_amount}))
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
			_cancel_bow_aim()
		return
	if item_id in ["cup", "xeng", "riu", "kiem", "can_cau", "dai_kiem", "gang_tay_da_thu", "no", "mui_ten", "phao_dua_hau", "dan_hat_nhan_dua_hau", "phao_coi_bi_do", "iron_halberd"]:
		ToolsMesh.build_held(pivot, item_id)
		if item_id == "no":
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
	call_deferred("_update_weapon_mesh")

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
					var is_mortar := equipped_weapon != null and equipped_weapon.id == "phao_coi_bi_do"
					if is_mortar:
						_cancel_mortar_aim()
					else:
						_cancel_bow_aim()
					return
			if (_halberd_charge_time >= 0.0 or _halberd_throwing) and k.keycode in [KEY_E, KEY_B, KEY_I, KEY_ESCAPE]:
				_cancel_halberd_aim()
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
			if equipped_weapon and equipped_weapon.id == "no":
				_fire_bow()
			elif equipped_weapon and equipped_weapon.id == "phao_coi_bi_do":
				_fire_mortar()
			elif equipped_weapon and equipped_weapon.id == "phao_dua_hau":
				_fire_watermelon_cannon()
				_cancel_bow_aim()
			return
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _halberd_charge_time >= 0.0:
			if _halberd_throwing:
				_fire_halberd_throw()
			else:
				_do_halberd_melee()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if _bow_aiming:
				var is_mortar := equipped_weapon != null and equipped_weapon.id == "phao_coi_bi_do"
				if is_mortar:
					_cancel_mortar_aim()
				else:
					_cancel_bow_aim()
				return
			if _halberd_charge_time >= 0.0 or _halberd_throwing:
				_cancel_halberd_aim()
				return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _bow_aiming:
				return
			if equipped_weapon != null:
				match equipped_weapon.id:
					"no": _start_bow_aim(); return
					"phao_coi_bi_do": _start_mortar_aim(); return
					"phao_dua_hau": _start_cannon_aim(); return
					"can_cau": _fishing_action(); return
					"iron_halberd": return
			if _freeze_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
				var wep_id: String = equipped_weapon.id if equipped_weapon else ""
				var is_heavy: bool = wep_id == "riu" or wep_id == "cup"
				if is_heavy:
					if _attack_timer > 0.0: return
					combo_step = 0
				else:
					var max_step: int = 1 if wep_id == "dai_kiem" else 2
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
					"cup": attack_duration = 0.65; _melee_hit_progress = 0.35
					"riu": attack_duration = 0.85; _melee_hit_progress = 0.35
					"dai_kiem": attack_duration = 1.00; _melee_hit_progress = 0.40
					"gang_tay_da_thu": attack_duration = 0.35; _melee_hit_progress = 0.20
					_: attack_duration = 0.50; _melee_hit_progress = 0.25
				_attack_timer = attack_duration * (2.0 if _underwater else 1.0)
				_state = State.ATTACK
				_melee_hit_once = false
			return
		if _has_target and equipped_weapon != null:
			var wep_id: String = equipped_weapon.id
			var old_block: int = 0
			if wep_id == "cup" and not _is_soft_block(_target_block.x, _target_block.y, _target_block.z):
				old_block = _open_world_manager().break_block(_target_block.x, _target_block.y, _target_block.z)
			elif wep_id == "xeng" and _is_soft_block(_target_block.x, _target_block.y, _target_block.z):
				old_block = _open_world_manager().break_block(_target_block.x, _target_block.y, _target_block.z)
			if old_block != 0:
				var item_id: String = _Data.BLOCK_TO_ITEM.get(old_block, "")
				if not item_id.is_empty():
					var def: ItemDef = ItemDatabase.items_db.get(item_id) as ItemDef
					if def:
						var world: Node = _open_world_manager()
						var drop_pos := Vector3(_target_block.x, _target_block.y, _target_block.z)
						DroppedItem.spawn(world, def, drop_pos)
			if old_block != 0:
				SFXManager.play_block_break()
		return

func _fishing_action() -> void:
	var holding_rod := equipped_weapon != null and equipped_weapon.id == "can_cau"
	if holding_rod:
		if _bobber != null:
			if _bobber.reel_in():
				SFXManager.play_retrieve()
		else:
			_cast_fishing_line()
	elif _bobber != null:
		_bobber.reel_in()

func _cast_fishing_line() -> void:
	var target := _calc_aim_dir() * 8.0 + global_position
	target.y = 0.46
	var bob := preload("res://scripts/items/entities/fishing_bobber.gd").new()
	var root := get_tree().current_scene
	if root:
		root.add_child(bob)
	else:
		add_child(bob)
	var pivot: Node3D = _mesh.weapon_pivot if _mesh != null else null
	bob.setup(self, target, pivot)
	_bobber = bob
	SFXManager.play_cast()

func _on_bobber_done(item_id: String) -> void:
	_bobber = null
	if item_id != "":
		ItemDatabase.ensure_db()
		var def: ItemDef = ItemDatabase.items_db.get(item_id)
		if def and inventory.add_item(def, 1) == 0:
			_scroll_inventory_message("+1 " + def.name)
		else:
			_scroll_inventory_message(tr("INVENTORY_FULL"))
	else:
		_scroll_inventory_message(tr("FISH_MISS"))

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

func _has_arrows() -> bool:
	if inventory == null:
		return false
	for slot in inventory.slots:
		if not slot.is_empty() and slot.item.id == "mui_ten":
			return true
	return false

func _consume_arrow() -> bool:
	if inventory == null:
		return false
	for i in range(inventory.slots.size()):
		var slot := inventory.slots[i]
		if not slot.is_empty() and slot.item.id == "mui_ten":
			inventory.remove_item(i, 1)
			return true
	return false

func _has_watermelon_ammo() -> bool:
	if inventory == null:
		return false
	for slot in inventory.slots:
		if not slot.is_empty() and slot.item.id == "dan_hat_nhan_dua_hau":
			return true
	return false

func _consume_watermelon_ammo() -> bool:
	if inventory == null:
		return false
	for i in range(inventory.slots.size()):
		var slot := inventory.slots[i]
		if not slot.is_empty() and slot.item.id == "dan_hat_nhan_dua_hau":
			inventory.remove_item(i, 1)
			return true
	return false

func _start_bow_aim() -> void:
	if not equipped_weapon or equipped_weapon.id != "no":
		return
	_bow_aiming = true
	_bow_charge = 0.0
	_bow_string_node = null
	if _mesh != null and _mesh.weapon_pivot != null:
		for ch in _mesh.weapon_pivot.get_children():
			if ch.name == "BowString":
				_bow_string_node = ch
				break
	if _bow_indicator_root == null:
		_bow_indicator_root = Node3D.new()
		_bow_indicator_root.name = "BowAimIndicator"
		get_tree().current_scene.add_child(_bow_indicator_root)
	else:
		for ch in _bow_indicator_root.get_children():
			ch.queue_free()
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
	line_mat.emission_enabled = true
	line_mat.emission_color = Color(1.0, 1.0, 1.0)
	line_mat.emission_energy_multiplier = 0.4
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.no_depth_test = true
	_bow_indicator_line = MeshInstance3D.new()
	_bow_indicator_line.mesh = BoxMesh.new()
	_bow_indicator_line.material_override = line_mat
	_bow_indicator_root.add_child(_bow_indicator_line)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.40)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = Color(1.0, 0.85, 0.4)
	ring_mat.emission_energy_multiplier = 0.5
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.no_depth_test = true
	_bow_indicator_target = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.5
	ring.bottom_radius = 0.5
	ring.height = 0.05
	ring.radial_segments = 16
	_bow_indicator_target.mesh = ring
	_bow_indicator_target.material_override = ring_mat
	_bow_indicator_root.add_child(_bow_indicator_target)
	_bow_indicator_root.visible = true
	_update_bow_string(0.0)

func _make_aoe_ring(radius: float, color: Color) -> void:
	if _bow_indicator_aoe:
		_bow_indicator_aoe.queue_free()
	var aoe_mat := StandardMaterial3D.new()
	aoe_mat.albedo_color = color
	aoe_mat.emission_enabled = true
	aoe_mat.emission_color = color
	aoe_mat.emission_energy_multiplier = 0.6
	aoe_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aoe_mat.no_depth_test = true
	aoe_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bow_indicator_aoe = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = radius - 0.06
	tor.outer_radius = 0.06
	tor.ring_segments = 12
	tor.rings = 24
	_bow_indicator_aoe.mesh = tor
	_bow_indicator_aoe.material_override = aoe_mat
	_bow_indicator_aoe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bow_indicator_root.add_child(_bow_indicator_aoe)

func _start_cannon_aim() -> void:
	if not equipped_weapon or equipped_weapon.id != "phao_dua_hau":
		return
	if not _has_watermelon_ammo():
		return
	_bow_aiming = true
	_bow_charge = _bow_max_charge
	if _bow_indicator_root == null:
		_bow_indicator_root = Node3D.new()
		_bow_indicator_root.name = "BowAimIndicator"
		get_tree().current_scene.add_child(_bow_indicator_root)
	else:
		for ch in _bow_indicator_root.get_children():
			ch.queue_free()
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.9, 0.35, 0.35, 0.40)
	line_mat.emission_enabled = true
	line_mat.emission_color = Color(1.0, 0.4, 0.4)
	line_mat.emission_energy_multiplier = 0.5
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.no_depth_test = true
	_bow_indicator_line = MeshInstance3D.new()
	_bow_indicator_line.mesh = BoxMesh.new()
	_bow_indicator_line.material_override = line_mat
	_bow_indicator_root.add_child(_bow_indicator_line)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.45)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = Color(1.0, 0.85, 0.4)
	ring_mat.emission_energy_multiplier = 0.6
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.no_depth_test = true
	_bow_indicator_target = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.5
	ring.bottom_radius = 0.5
	ring.height = 0.05
	ring.radial_segments = 16
	_bow_indicator_target.mesh = ring
	_bow_indicator_target.material_override = ring_mat
	_bow_indicator_root.add_child(_bow_indicator_target)
	_bow_indicator_root.visible = true
	_make_aoe_ring(7.0, Color(1.0, 0.3, 0.1, 0.30))

func _update_bow_aim(delta: float) -> void:
	var is_cannon := equipped_weapon != null and equipped_weapon.id == "phao_dua_hau"
	if is_cannon:
		_bow_charge = _bow_max_charge
	else:
		_bow_charge = min(_bow_charge + delta * _bow_charge_rate, _bow_max_charge)

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var dir: Vector3 = cam.project_ray_normal(mouse_pos)
	var plane_y: float = global_position.y
	_bow_aim_dir = global_transform.basis.z
	if abs(dir.y) > 0.001:
		var t: float = (plane_y - from.y) / dir.y
		var ground_hit: Vector3 = from + dir * max(t, 0.0)
		var to_target: Vector3 = ground_hit - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			_bow_aim_dir = to_target.normalized()
	rotation.y = atan2(_bow_aim_dir.x, _bow_aim_dir.z)

	if _bow_indicator_root == null or _bow_indicator_line == null or _bow_indicator_target == null:
		return
	var range_len: float = 25.0 if is_cannon else lerp(8.0, 50.0, _bow_charge / _bow_max_charge)
	var end_pos := _bow_aim_dir * range_len
	end_pos.y = plane_y

	_bow_indicator_root.global_position = global_position + Vector3(0, 0.3, 0)
	_bow_indicator_line.position = end_pos * 0.5
	_bow_indicator_line.mesh.size = Vector3(0.04, 0.04, range_len)
	_bow_indicator_line.look_at(_bow_indicator_root.global_position + end_pos, Vector3.UP)
	_bow_indicator_target.global_position = _bow_indicator_root.global_position + end_pos
	if _bow_indicator_aoe:
		_bow_indicator_aoe.global_position = _bow_indicator_target.global_position

	if is_cannon:
		_bow_indicator_line.material_override.albedo_color = Color(0.8, 0.3, 0.3, 0.35)
		_bow_indicator_target.material_override.albedo_color = Color(1.0, 0.8, 0.3, 0.40)
	else:
		var cp: float = _bow_charge / _bow_max_charge
		var line_color := Color.WHITE.lerp(Color(1.0, 0.3, 0.1), cp)
		line_color.a = 0.30
		_bow_indicator_line.material_override.albedo_color = line_color
		var ring_color := Color(1.0, 0.8, 0.3).lerp(Color(1.0, 0.2, 0.1), cp)
		ring_color.a = 0.35
		_bow_indicator_target.material_override.albedo_color = ring_color

	if not is_cannon:
		_update_bow_pose()
		_update_bow_string(_bow_charge / _bow_max_charge)

func _update_bow_pose() -> void:
	if _mesh == null or _mesh.weapon_pivot == null or _mesh.arm_r == null:
		return
	var is_no := equipped_weapon != null and equipped_weapon.id == "no"
	if not is_no:
		return
	_mesh.weapon_pivot.rotation_degrees = _mesh.weapon_pivot.rotation_degrees.lerp(Vector3(90, 0, 0), 0.15)
	if _bow_aiming:
		_mesh.arm_r.rotation.x = lerp(_mesh.arm_r.rotation.x, -0.35, 0.15)
	else:
		_mesh.arm_r.rotation.x = lerp(_mesh.arm_r.rotation.x, 0.0, 0.12)

func _fire_bow() -> void:
	if not _bow_aiming:
		return
	_bow_aiming = false
	_update_bow_string(-1.0)
	if _bow_indicator_root:
		_bow_indicator_root.visible = false

	if not _has_arrows():
		_scroll_inventory_message(tr("BOW_NO_ARROWS"))
		return

	if not _consume_arrow():
		_scroll_inventory_message(tr("BOW_NO_ARROWS"))
		return

	var charge_pct: float = _bow_charge / _bow_max_charge
	var range_len: float = lerp(8.0, 50.0, charge_pct)
	var arrow_speed: float = lerp(15.0, 50.0, charge_pct)
	var base_dmg: int = attack_power + (equipped_weapon.atk_bonus if equipped_weapon else 8)
	var total_dmg: int = int(base_dmg * lerp(0.5, 1.5, charge_pct))

	var arrow := ArrowProjectile.new()
	var world := get_tree().current_scene
	if world:
		world.add_child(arrow)
	else:
		add_child(arrow)
	arrow.global_position = global_position + Vector3(0, 0.5, 0) + _bow_aim_dir * 0.5
	arrow.setup(_bow_aim_dir, total_dmg, arrow_speed, range_len, self)

func _fire_watermelon_cannon() -> void:
	if not try_skill(stamina_cost_lmb):
		return
	if not equipped_weapon or equipped_weapon.id != "phao_dua_hau":
		return
	if not _consume_watermelon_ammo():
		return
	var dir := _calc_aim_dir()
	var base_dmg: int = attack_power + equipped_weapon.atk_bonus
	var proj := WatermelonProjectile.new()
	var world := get_tree().current_scene
	if world:
		world.add_child(proj)
	else:
		add_child(proj)
	var spawn_pos: Vector3 = global_position + Vector3(0, 0.6, 0) + dir * 0.5
	if _mesh and _mesh.weapon_pivot:
		spawn_pos = _mesh.weapon_pivot.global_transform * Vector3(0, 0.42, 0)
	proj.global_position = spawn_pos
	proj.setup(dir, base_dmg, 17.0, 25.0, 7.0, self)
	# Đẩy lùi người bắn
	var kb_dir := -dir
	kb_dir.y = 0.0
	if kb_dir.length_squared() > 0.01:
		velocity += kb_dir * 4.0
	# Khói từ nòng súng to hơn
	if _mesh and _mesh.weapon_pivot:
		for i in 12:
			var smoke := MeshInstance3D.new()
			smoke.mesh = SphereMesh.new()
			smoke.mesh.radius = 0.08
			smoke.mesh.height = 0.16
			var smat := StandardMaterial3D.new()
			smat.albedo_color = Color(0.6, 0.6, 0.6, 0.6)
			smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			smat.no_depth_test = true
			smoke.material_override = smat
			smoke.position = Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
			smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var muzzle := _mesh.weapon_pivot.global_transform * Vector3(0, 0.44, 0)
			get_tree().current_scene.add_child(smoke)
			smoke.global_position = muzzle
			var tw := create_tween().set_parallel()
			tw.tween_property(smoke, "position", smoke.position + Vector3(randf_range(-0.25, 0.25), randf_range(0, 0.3), randf_range(-0.25, 0.25)), 0.4)
			tw.tween_property(smat, "albedo_color:a", 0.0, 0.4)
			tw.tween_callback(smoke.queue_free).set_delay(0.45)
		# Recoil
		var tw2 := create_tween().set_parallel()
		var orig_pos := _mesh.weapon_pivot.position
		var orig_rot := _mesh.weapon_pivot.rotation
		tw2.tween_property(_mesh.weapon_pivot, "position:y", orig_pos.y - 0.03, 0.04)
		tw2.tween_property(_mesh.weapon_pivot, "position:y", orig_pos.y, 0.07).set_delay(0.04)
		tw2.tween_property(_mesh.weapon_pivot, "rotation:x", orig_rot.x + 0.03, 0.04)
		tw2.tween_property(_mesh.weapon_pivot, "rotation:x", orig_rot.x, 0.07).set_delay(0.04)

func _update_bow_string(charge_pct: float) -> void:
	if _bow_string_node == null:
		return
	var left_seg: MeshInstance3D = _bow_string_node.get_node_or_null("SegLeft")
	var right_seg: MeshInstance3D = _bow_string_node.get_node_or_null("SegRight")
	if left_seg == null or right_seg == null:
		return
	var pull: float = charge_pct * 0.12 if charge_pct >= 0.0 else 0.0
	var left_anchor := Vector3(-0.210, 0.26, -0.030)
	var right_anchor := Vector3(0.210, 0.26, -0.030)
	var pull_pt := Vector3(0, 0.26 - pull, -0.030)
	_place_cylinder_between(left_seg, left_anchor, pull_pt)
	_place_cylinder_between(right_seg, right_anchor, pull_pt)

static func _place_cylinder_between(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	var dist := a.distance_to(b)
	var dir := (b - a).normalized()
	mi.position = mid
	mi.mesh.height = dist
	var up := Vector3(0, 1, 0)
	if dir.distance_squared_to(up) < 0.0001:
		mi.basis = Basis.IDENTITY
	elif dir.distance_squared_to(-up) < 0.0001:
		mi.basis = Basis.IDENTITY.rotated(Vector3(1, 0, 0), PI)
	else:
		var axis := up.cross(dir).normalized()
		var angle := acos(up.dot(dir))
		mi.basis = Basis(axis, angle)

func _start_mortar_aim() -> void:
	if not equipped_weapon or equipped_weapon.id != "phao_coi_bi_do":
		return
	if not _has_ammo("pumpkin"):
		_scroll_inventory_message(tr("NO_MORTAR_AMMO"))
		return
	_bow_aiming = true
	_bow_charge = 0.0
	_setup_mortar_indicator()

func _setup_mortar_indicator() -> void:
	if _bow_indicator_root == null:
		_bow_indicator_root = Node3D.new()
		_bow_indicator_root.name = "BowAimIndicator"
		get_tree().current_scene.add_child(_bow_indicator_root)
	for ch in _bow_indicator_root.get_children():
		ch.queue_free()
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.7, 0.1, 0.50)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = Color(1.0, 0.7, 0.1)
	ring_mat.emission_energy_multiplier = 0.6
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.no_depth_test = true
	_bow_indicator_target = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.8
	ring.bottom_radius = 0.8
	ring.height = 0.05
	ring.radial_segments = 20
	_bow_indicator_target.mesh = ring
	_bow_indicator_target.material_override = ring_mat
	_bow_indicator_target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bow_indicator_root.add_child(_bow_indicator_target)
	_bow_indicator_root.visible = true
	_make_aoe_ring(2.5, Color(1.0, 0.7, 0.1, 0.30))

func _update_mortar_aim(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var dir: Vector3 = cam.project_ray_normal(mouse_pos)
	var plane_y: float = global_position.y
	_bow_aim_dir = global_transform.basis.z
	if abs(dir.y) > 0.001:
		var t: float = (plane_y - from.y) / dir.y
		var ground_hit: Vector3 = from + dir * max(t, 0.0)
		var to_target: Vector3 = ground_hit - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			_bow_aim_dir = to_target.normalized()
	rotation.y = atan2(_bow_aim_dir.x, _bow_aim_dir.z)

	_bow_charge = min(_bow_charge + delta * _bow_charge_rate, _bow_max_charge)
	var cp: float = _bow_charge / _bow_max_charge
	var h_speed: float = lerp(2.0, 15.0, cp)
	var v_speed: float = lerp(3.0, 12.0, cp)
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

	var start_pos := global_position + Vector3(0, 0.8, 0) + _bow_aim_dir * 0.5
	if _mesh and _mesh.weapon_pivot:
		start_pos = _mesh.weapon_pivot.global_transform * Vector3(0, 0.35, 0)

	var a: float = -0.5 * g
	var b: float = v_speed
	var c: float = start_pos.y
	var discriminant: float = b * b - 4.0 * a * c
	var flight_time: float = 0.0
	if discriminant >= 0.0:
		flight_time = (-b - sqrt(discriminant)) / (2.0 * a)
		if flight_time < 0.0:
			flight_time = (-b + sqrt(discriminant)) / (2.0 * a)
	if flight_time <= 0.0:
		return
	var range_h: float = h_speed * flight_time
	var end_pos := _bow_aim_dir * range_h

	if _bow_indicator_root == null or _bow_indicator_target == null:
		return
	_bow_indicator_root.global_position = start_pos
	_bow_indicator_target.position = Vector3(end_pos.x, -start_pos.y, end_pos.z)
	if _bow_indicator_aoe:
		_bow_indicator_aoe.position = _bow_indicator_target.position

	for ch in _bow_indicator_root.get_children():
		if ch != _bow_indicator_target and ch != _bow_indicator_aoe:
			ch.queue_free()
	var dot_mat := StandardMaterial3D.new()
	dot_mat.albedo_color = Color(1.0, 0.65, 0.15, 0.35)
	dot_mat.emission_enabled = true
	dot_mat.emission_color = Color(1.0, 0.65, 0.15)
	dot_mat.emission_energy_multiplier = 0.5
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.no_depth_test = true
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.05
	dot_mesh.height = 0.10
	var steps: int = 24
	for i in range(steps):
		var t: float = float(i + 1) / float(steps)
		var ft := flight_time * t
		var hx := _bow_aim_dir.x * h_speed * ft
		var hz := _bow_aim_dir.z * h_speed * ft
		var vy := v_speed * ft - 0.5 * g * ft * ft
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.material_override = dot_mat
		dot.position = Vector3(hx, vy, hz)
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bow_indicator_root.add_child(dot)

func _fire_mortar() -> void:
	if not _bow_aiming:
		return
	_bow_aiming = false
	if _bow_indicator_root:
		_bow_indicator_root.visible = false

	if not try_skill(stamina_cost_lmb):
		return
	if not _consume_ammo("pumpkin"):
		_scroll_inventory_message(tr("NO_MORTAR_AMMO"))
		return

	var dir := _calc_aim_dir()
	if dir.length_squared() < 0.01:
		dir = -global_transform.basis.z
	var cp: float = _bow_charge / _bow_max_charge
	var h_speed: float = lerp(2.0, 15.0, cp)
	var v_speed: float = lerp(3.0, 12.0, cp)
	var base_dmg: int = attack_power + (equipped_weapon.atk_bonus if equipped_weapon else 12)

	var proj := PumpkinProjectile.new()
	var world := get_tree().current_scene
	if world:
		world.add_child(proj)
	else:
		add_child(proj)
	var spawn_pos: Vector3 = global_position + Vector3(0, 0.8, 0) + dir * 0.5
	if _mesh and _mesh.weapon_pivot:
		spawn_pos = _mesh.weapon_pivot.global_transform * Vector3(0, 0.35, 0)
	proj.global_position = spawn_pos
	proj.setup(dir, base_dmg, h_speed, 2.5, v_speed, self)

	# Muzzle smoke
	if _mesh and _mesh.weapon_pivot:
		for i in 6:
			var smoke := MeshInstance3D.new()
			smoke.mesh = SphereMesh.new()
			smoke.mesh.radius = 0.06
			smoke.mesh.height = 0.12
			var smat := StandardMaterial3D.new()
			smat.albedo_color = Color(0.6, 0.6, 0.6, 0.5)
			smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			smat.no_depth_test = true
			smoke.material_override = smat
			smoke.position = Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), randf_range(-0.04, 0.04))
			smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			get_tree().current_scene.add_child(smoke)
			smoke.global_position = spawn_pos
			var tw := create_tween().set_parallel()
			tw.tween_property(smoke, "position", smoke.position + Vector3(randf_range(-0.2, 0.2), randf_range(0, 0.25), randf_range(-0.2, 0.2)), 0.35)
			tw.tween_property(smat, "albedo_color:a", 0.0, 0.35)
			tw.tween_callback(smoke.queue_free).set_delay(0.4)

		# Recoil
		var tw2 := create_tween().set_parallel()
		var orig := _mesh.weapon_pivot.position
		tw2.tween_property(_mesh.weapon_pivot, "position:y", orig.y - 0.05, 0.05)
		tw2.tween_property(_mesh.weapon_pivot, "position:y", orig.y, 0.08).set_delay(0.05)

func _cancel_mortar_aim() -> void:
	_bow_aiming = false
	if _bow_indicator_root:
		_bow_indicator_root.visible = false

func _has_ammo(item_id: String) -> bool:
	if inventory == null:
		return false
	for slot in inventory.slots:
		if not slot.is_empty() and slot.item.id == item_id:
			return true
	return false

func _consume_ammo(item_id: String) -> bool:
	if inventory == null:
		return false
	for i in range(inventory.slots.size()):
		var slot := inventory.slots[i]
		if not slot.is_empty() and slot.item.id == item_id:
			inventory.remove_item(i, 1)
			return true
	return false

func _cancel_bow_aim() -> void:
	_bow_aiming = false
	_bow_charge = 0.0
	_update_bow_string(-1.0)
	if _bow_indicator_root:
		_bow_indicator_root.visible = false

func _is_soft_block(bx: float, by: float, bz: float) -> bool:
	var owm := _open_world_manager()
	if owm == null:
		return false
	var blk: int = owm.get_block(bx, by, bz)
	return blk == _Data.BlockID.SAND or blk == _Data.BlockID.SAND_DEEP or blk == _Data.BlockID.OCEAN_SAND or blk == _Data.BlockID.MUDDY_SAND or blk == _Data.BlockID.OCEAN_GRAVEL or blk == _Data.BlockID.DIRT or blk == _Data.BlockID.DARK_DIRT or blk == _Data.BlockID.GRASS or blk == _Data.BlockID.DARK_GRASS

func _update_block_target() -> void:
	if _block_highlight == null:
		return
	var can_mine := equipped_weapon != null and (equipped_weapon.id == "cup" or equipped_weapon.id == "xeng")
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
	var is_cannon_aiming := _bow_aiming and equipped_weapon != null and equipped_weapon.id == "phao_dua_hau"
	var is_mortar_aiming := _bow_aiming and equipped_weapon != null and equipped_weapon.id == "phao_coi_bi_do"
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
	combo_timer = max(combo_timer - delta, 0.0)
	_update_block_target()
	_update_bow_pose()
	if equipped_weapon != null and equipped_weapon.id == "iron_halberd":
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _halberd_charge_time < 0.0:
				_halberd_charge_time = 0.0
			_halberd_charge_time += delta
			if _halberd_charge_time >= HALBERD_CHARGE_TIME and not _halberd_throwing:
				_start_halberd_throw_aim()
			if _halberd_throwing:
				_update_halberd_aim(delta)
	if _bow_aiming:
		if _state == State.HIT:
			var is_mortar := equipped_weapon != null and equipped_weapon.id == "phao_coi_bi_do"
			if is_mortar:
				_cancel_mortar_aim()
			else:
				_cancel_bow_aim()
		else:
			var is_mortar := equipped_weapon != null and equipped_weapon.id == "phao_coi_bi_do"
			if is_mortar:
				_update_mortar_aim(delta)
			else:
				_update_bow_aim(delta)
	if _halberd_throwing and _state == State.HIT:
		_cancel_halberd_aim()

func _start_halberd_throw_aim() -> void:
	_halberd_throwing = true
	_bow_aiming = false
	if _bow_indicator_root == null:
		_bow_indicator_root = Node3D.new()
		_bow_indicator_root.name = "BowAimIndicator"
		get_tree().current_scene.add_child(_bow_indicator_root)
	else:
		for ch in _bow_indicator_root.get_children():
			ch.queue_free()
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.3, 0.8, 0.6, 0.35)
	line_mat.emission_enabled = true
	line_mat.emission_color = Color(0.3, 0.8, 0.6)
	line_mat.emission_energy_multiplier = 0.5
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.no_depth_test = true
	_bow_indicator_line = MeshInstance3D.new()
	_bow_indicator_line.mesh = BoxMesh.new()
	_bow_indicator_line.material_override = line_mat
	_bow_indicator_root.add_child(_bow_indicator_line)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.3, 0.8, 0.6, 0.50)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = Color(0.3, 0.8, 0.6)
	ring_mat.emission_energy_multiplier = 0.6
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.no_depth_test = true
	_bow_indicator_target = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.5
	ring.bottom_radius = 0.5
	ring.height = 0.05
	ring.radial_segments = 16
	_bow_indicator_target.mesh = ring
	_bow_indicator_target.material_override = ring_mat
	_bow_indicator_target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bow_indicator_root.add_child(_bow_indicator_target)
	_bow_indicator_root.visible = true

func _update_halberd_aim(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	var mouse_pos := get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var dir: Vector3 = cam.project_ray_normal(mouse_pos)
	var plane_y: float = global_position.y
	_halberd_aim_dir = global_transform.basis.z
	if abs(dir.y) > 0.001:
		var t: float = (plane_y - from.y) / dir.y
		var ground_hit: Vector3 = from + dir * max(t, 0.0)
		var to_target: Vector3 = ground_hit - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			_halberd_aim_dir = to_target.normalized()
	rotation.y = atan2(_halberd_aim_dir.x, _halberd_aim_dir.z)
	var charge_pct: float = _halberd_charge_time / (HALBERD_CHARGE_TIME + _bow_max_charge)
	charge_pct = clamp(charge_pct, 0.0, 1.0)
	var range_len: float = lerp(HALBERD_MIN_RANGE, HALBERD_MAX_RANGE, charge_pct)
	var end_pos := _halberd_aim_dir * range_len
	end_pos.y = plane_y
	if _bow_indicator_root == null or _bow_indicator_line == null or _bow_indicator_target == null: return
	_bow_indicator_root.global_position = global_position + Vector3(0, 0.3, 0)
	_bow_indicator_line.position = end_pos * 0.5
	_bow_indicator_line.mesh.size = Vector3(0.04, 0.04, range_len)
	_bow_indicator_line.look_at(_bow_indicator_root.global_position + end_pos, Vector3.UP)
	_bow_indicator_target.global_position = _bow_indicator_root.global_position + end_pos
	var line_color := Color(0.3, 0.8, 0.6).lerp(Color(1.0, 0.4, 0.3), charge_pct)
	line_color.a = 0.35
	_bow_indicator_line.material_override.albedo_color = line_color
	var ring_color := Color(0.3, 0.8, 0.6).lerp(Color(1.0, 0.4, 0.3), charge_pct)
	ring_color.a = 0.50
	_bow_indicator_target.material_override.albedo_color = ring_color

func _fire_halberd_throw() -> void:
	_halberd_throwing = false
	var saved_charge: float = _halberd_charge_time
	_halberd_charge_time = -1.0
	if _bow_indicator_root:
		_bow_indicator_root.visible = false
	if not try_skill(stamina_cost_lmb):
		return
	var dir := _halberd_aim_dir
	if dir.length_squared() < 0.01:
		dir = -global_transform.basis.z
	var halberd_slot_idx: int = -1
	for i in range(inventory.slots.size()):
		var slot: ItemSlot = inventory.slots[i]
		if not slot.is_empty() and slot.item.id == "iron_halberd":
			halberd_slot_idx = i
			break
	if halberd_slot_idx < 0:
		return
	inventory.remove_item(halberd_slot_idx, 1)
	if equipped_weapon != null and equipped_weapon.id == "iron_halberd":
		equipped_weapon = null
		_update_weapon_mesh()
	var charge_pct: float = clamp(saved_charge / (HALBERD_CHARGE_TIME + _bow_max_charge), 0.0, 1.0)
	var range_len: float = lerp(HALBERD_MIN_RANGE, HALBERD_MAX_RANGE, charge_pct)
	var plane_y: float = global_position.y
	var landing_pos: Vector3 = global_position + dir * range_len
	landing_pos.y = plane_y
	var space := get_world_3d().direct_space_state
	if space:
		var q := PhysicsRayQueryParameters3D.new()
		q.from = landing_pos + Vector3(0, 2.0, 0)
		q.to = landing_pos + Vector3(0, -4.0, 0)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			landing_pos.y = hit.position.y
	var world := get_tree().current_scene
	if world:
		var def: ItemDef = ItemDatabase.items_db.get("iron_halberd")
		if def:
			var launch_pos := global_position + Vector3(0, 0.6, 0) + dir * 0.5
			if _mesh and _mesh.weapon_pivot:
				launch_pos = _mesh.weapon_pivot.global_transform * Vector3(0, 0.35, 0)
			var h_dist := Vector2(landing_pos.x - launch_pos.x, landing_pos.z - launch_pos.z).length()
			var h_speed: float = lerp(14.0, 24.0, charge_pct)
			var flight_time: float = maxf(h_dist / maxf(h_speed, 0.1), 0.1)
			var vx: float = (landing_pos.x - launch_pos.x) / flight_time
			var vz: float = (landing_pos.z - launch_pos.z) / flight_time
			var vy: float = (landing_pos.y - launch_pos.y) / flight_time
			var item := DroppedItem.spawn(world, def, launch_pos, 1)
			var ground_y: float = landing_pos.y
			var base_dmg: int = attack_power + (equipped_weapon.atk_bonus if equipped_weapon else 10)
			item.fly_straight(Vector3(vx, vy, vz), ground_y, base_dmg, self)
	var msg: String = tr("THREW_MSG") if tr("THREW_MSG") != "THREW_MSG" else "Đã ném Kích Sắt"
	_scroll_inventory_message(msg)

func _cancel_halberd_aim() -> void:
	_halberd_throwing = false
	_halberd_charge_time = -1.0
	if _bow_indicator_root:
		_bow_indicator_root.visible = false

func _on_dash() -> void:
	if equipped_weapon and equipped_weapon.id == "iron_halberd":
		_halberd_dashing = true
		_halberd_dash_hit = {}

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _halberd_dashing:
		if _state == State.DASH:
			_check_halberd_dash_hit()
		else:
			_halberd_dashing = false

func _check_halberd_dash_hit() -> void:
	var dir := _dash_dir
	if dir.length_squared() < 0.01:
		return
	var fwd := dir.normalized()
	var right := Vector3.UP.cross(fwd).normalized()
	var box_center := global_position + fwd * 1.2 + Vector3(0, 0.4, 0)
	var half := Vector3(0.5, 0.4, 1.6)

	var mgr := _find_character_manager()
	if mgr:
		for ch in mgr.get_children():
			if ch is CharacterBase and ch != self and ch.is_alive and ch._active:
				_try_dash_hit(ch, box_center, right, fwd, half)

	var pig_nodes := get_tree().get_nodes_in_group("pig")
	for pn in pig_nodes:
		if is_instance_valid(pn) and pn.get("is_alive"):
			_try_dash_hit(pn as CharacterBase, box_center, right, fwd, half)

	var spawner := _find_fish_spawner()
	if spawner:
		for f in spawner.get_children():
			if f is FishCharacter and f.is_alive:
				_try_dash_hit(f as CharacterBase, box_center, right, fwd, half)

func _try_dash_hit(ch: CharacterBase, box_center: Vector3, right: Vector3, fwd: Vector3, half: Vector3) -> void:
	if _halberd_dash_hit.has(ch.get_instance_id()):
		return
	var to_target := ch.global_position - box_center
	var local := Vector3(to_target.dot(right), to_target.dot(Vector3.UP), to_target.dot(fwd))
	if abs(local.x) < half.x and abs(local.y) < half.y and abs(local.z) < half.z:
		_halberd_dash_hit[ch.get_instance_id()] = true
		var dmg: int = get_total_atk()
		ch.take_damage(dmg, self)
		SFXManager.play_damage_hit()

func _do_halberd_melee() -> void:
	_halberd_charge_time = -1.0
	if _freeze_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
		var max_step: int = 1
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
		match combo_step:
			0:
				attack_duration = 0.85
				_melee_hit_progress = 0.35
			1:
				attack_duration = 0.70
				_melee_hit_progress = 0.30
		_attack_timer = attack_duration * (2.0 if _underwater else 1.0)
		_state = State.ATTACK
		_melee_hit_once = false

func _ready() -> void:
	await super._ready()
	_init_highlight()

func _animate(delta: float) -> void:
	_anim.animate(delta)
