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
var _bow_charge_rate: float = 0.50
var _bow_max_charge: float = 2.0
var _bow_aim_dir: Vector3 = Vector3.FORWARD
var _bow_indicator_line: MeshInstance3D = null
var _bow_indicator_target: MeshInstance3D = null
var _bow_indicator_root: Node3D = null
var _bow_string_node: Node3D = null

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
	move_speed = 3.6
	sprint_speed = 6.8
	jump_height = 1.1
	dash_speed = 16.0
	attack_duration = 0.50
	attack_power = 80
	defense = 20
	melee_damage = 12
	lmb_cooldown = 0.0
	q_cooldown = 0.60
	r_cooldown = 1.0
	max_hp = 500
	mana_cost_lmb = 0
	mana_cost_q = 0
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
	if item_id in ["cup", "xeng", "riu", "kiem", "can_cau", "dai_kiem", "gang_tay_da_thu", "no", "mui_ten"]:
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
	var base: int = melee_damage
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
					_cancel_bow_aim()
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
			_fire_bow()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if _bow_aiming:
				_cancel_bow_aim()
				return
			if equipped_weapon != null and equipped_weapon.id == "cup" and _has_target:
				var old_block: int = _open_world_manager().break_block(_target_block.x, _target_block.y, _target_block.z)
				if old_block != 0:
					var item_id: String = _Data.BLOCK_TO_ITEM.get(old_block, "")
					if not item_id.is_empty():
						var def: ItemDef = ItemDatabase.items_db.get(item_id) as ItemDef
						if def:
							var world: Node = _open_world_manager()
							var drop_pos := Vector3(_target_block.x, _target_block.y, _target_block.z)
							DroppedItem.spawn(world, def, drop_pos)
				SFXManager.play_block_break()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _bow_aiming:
				return
			if equipped_weapon != null and equipped_weapon.id == "no":
				_start_bow_aim()
				return
			if equipped_weapon != null and equipped_weapon.id == "can_cau":
				_fishing_action()
				return
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
				if not try_skill(mana_cost_lmb):
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
		var line_mat := StandardMaterial3D.new()
		line_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.30)
		line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_mat.no_depth_test = true
		_bow_indicator_line = MeshInstance3D.new()
		_bow_indicator_line.mesh = BoxMesh.new()
		_bow_indicator_line.material_override = line_mat
		_bow_indicator_root.add_child(_bow_indicator_line)
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(1.0, 0.8, 0.3, 0.35)
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

func _update_bow_aim(delta: float) -> void:
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
	var charge_pct: float = _bow_charge / _bow_max_charge
	var range_len: float = lerp(8.0, 50.0, charge_pct)
	var end_pos := _bow_aim_dir * range_len
	end_pos.y = plane_y

	_bow_indicator_root.global_position = global_position + Vector3(0, 0.3, 0)
	_bow_indicator_line.position = end_pos * 0.5
	_bow_indicator_line.mesh.size = Vector3(0.04, 0.04, range_len)
	_bow_indicator_line.look_at(_bow_indicator_root.global_position + end_pos, Vector3.UP)
	_bow_indicator_target.global_position = _bow_indicator_root.global_position + end_pos

	var line_color := Color.WHITE.lerp(Color(1.0, 0.3, 0.1), charge_pct)
	line_color.a = 0.30
	_bow_indicator_line.material_override.albedo_color = line_color
	var ring_color := Color(1.0, 0.8, 0.3).lerp(Color(1.0, 0.2, 0.1), charge_pct)
	ring_color.a = 0.35
	_bow_indicator_target.material_override.albedo_color = ring_color

	_update_bow_pose()
	_update_bow_string(charge_pct)

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
	var base_dmg: int = (equipped_weapon.atk_bonus if equipped_weapon else 8) + melee_damage
	var total_dmg: int = int(base_dmg * lerp(0.5, 1.5, charge_pct))

	var arrow := ArrowProjectile.new()
	var world := get_tree().current_scene
	if world:
		world.add_child(arrow)
	else:
		add_child(arrow)
	arrow.global_position = global_position + Vector3(0, 0.5, 0) + _bow_aim_dir * 0.5
	arrow.setup(_bow_aim_dir, total_dmg, arrow_speed, range_len, self)

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

func _cancel_bow_aim() -> void:
	_bow_aiming = false
	_bow_charge = 0.0
	_update_bow_string(-1.0)
	if _bow_indicator_root:
		_bow_indicator_root.visible = false

func _update_block_target() -> void:
	if _block_highlight == null:
		return
	var holding_cup := equipped_weapon != null and equipped_weapon.id == "cup"
	if not holding_cup:
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
	if _bow_aiming:
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
	if _bow_aiming:
		if _state == State.HIT:
			_cancel_bow_aim()
		else:
			_update_bow_aim(delta)

func _ready() -> void:
	await super._ready()
	_init_highlight()

func _animate(delta: float) -> void:
	_anim.animate(delta)
