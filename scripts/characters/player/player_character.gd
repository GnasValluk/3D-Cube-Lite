extends CharacterBase
class_name PlayerCharacter

const _BlockHighlight := preload("res://scripts/items/entities/block_highlight.gd")
const _BlockData := preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Data := preload("res://scripts/world/chunk/chunk_data.gd")
const _Bow := preload("player_bow.gd")
const _AK := preload("player_ak.gd")
const _M200 := preload("player_m200.gd")
const _Mortar := preload("player_mortar.gd")
const _EggThrow := preload("player_egg_throw.gd")
const _Halberd := preload("player_halberd.gd")
const _Fishing := preload("player_fishing.gd")
const _TavernDoor := preload("res://scripts/world/chunk/tavern_door.gd")
const _Skin := preload("res://scripts/characters/player/player_skin.gd")

var _mesh: PlayerMesh
var _anim: PlayerAnimator
## Skin đang mặc (id trong PlayerSkin.SKINS).
var skin_id: String = ""
var inventory: Inventory = null
var _inventory_open: bool = false
var _held_item: Dictionary = {}
var food: int = 20
var max_food: int = 20
var _food_timer: float = 0.0
var _food_action_timer: float = 0.0
var _starve_timer: float = 0.0

## ── Trọng lượng / quá tải ────────────────────────────────────────────────────
## Ngưỡng tải tối đa: vượt ngưỡng → làm chậm 2 (30%); vượt >25% → làm chậm 5 (95%).
var max_weight: float = 100.0
## May mắn cơ bản (chỉ số ẩn, không hiện UI) — cộng thêm từ trang bị (nhẫn vàng +2).
var luck: float = 0.0
## Số slot ba lô đang áp dụng lên inventory (theo dõi để mở rộng/thu hồi đúng).
var _backpack_slots_applied: int = 0

## Slot hotbar đang chọn — HUD cập nhật khi đổi ô
var _selected_slot: int = 0

## Ăn bằng cách giữ chuột phải khi ô hotbar đang chọn chứa đồ ăn
var _eating: bool = false
var _eat_timer: float = 0.0
var _eat_slot: int = -1
var _eat_item: ItemDef = null

## Respawn khi chết: đồ rơi vương vãi tại điểm chết + hồi sinh tại điểm xuất phát
var _death_items_spawned: bool = false
const WORLD_SPAWN_POS := Vector3(0, 3, 0)

## Đói: 1 điểm / 60s khi đứng yên; nhanh hơn 75% khi di chuyển; nhanh hơn 100% khi bơi
const FOOD_IDLE_INTERVAL: float = 60.0

signal food_changed(current: int, max_food: int)

## Cờ ẩn/hiện model trang bị bên ngoài theo slot (0=head 1=body 2=legs 3=feet 4=back 5=sub)
var armor_visible: Dictionary = {}

var equipped_weapon: ItemDef = null
var equipped_head: ItemDef = null
var equipped_body: ItemDef = null
var equipped_legs: ItemDef = null
var equipped_feet: ItemDef = null
var equipped_back: ItemDef = null
var equipped_sub: ItemDef = null

var combo_step: int = 0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 0.55
var _bobber: Node3D = null
var _block_highlight: Node3D = null
var _target_block: Vector3 = Vector3.ZERO
var _has_target: bool = false

## Đào nhấn-giữ: tiến trình + thanh trên đầu block.
var _mining: bool = false
var _mine_progress: float = 0.0
var _mine_block: Vector3 = Vector3.ZERO
var _mine_block_id: int = 0
var _mine_bar: Node3D = null

## Độ bền công cụ: vị trí slot đang cầm (hotbar) hoặc độ bền rời (equip từ inventory UI).
var _equipped_slot_idx: int = -1
var _equipped_durability: int = -1

var _bow_aiming: bool = false
var _bow_charge: float = 0.0
var _bow_charge_rate: float = 0.35
var _bow_max_charge: float = 2.0
var _ak_fire_cooldown: float = 0.0
## Giật nòng AK-12: 0 → 1, dùng trong _AK.update_pose để ngả nòng nhẹ rồi hồi.
var _ak_recoil: float = 0.0
## Vị trí cầm gốc của weapon_pivot khi cầm AK — hồi recoil về đây (tránh trôi).
var _ak_hold_base: Vector3 = Vector3.ZERO
var _ak_hold_captured: bool = false
var _mortar_vertical_speed: float = 8.0
var _mortar_launch_angle_deg: float = 60.0
var _bow_aim_dir: Vector3 = Vector3.FORWARD
var _aim_world_point: Vector3 = Vector3.ZERO
var _aim_tp_mode: bool = false
var _mortar_launch_h: float = 0.0
var _mortar_launch_v: float = 0.0
var _bow_indicator_target: MeshInstance3D = null
var _bow_indicator_aoe: MeshInstance3D = null
var _bow_indicator_root: Node3D = null
var _bow_string_node: Node3D = null
## Súng bắn tỉa M200: cờ đang ngắm kính + thời gian hồi thoi nòng.
var _m200_aiming: bool = false
var _m200_bolt_cd: float = 0.0
var _m200_hold_base: Vector3 = Vector3.ZERO
var _m200_hold_captured: bool = false
var _m200_recoil: float = 0.0

const HALBERD_CHARGE_TIME: float = 0.7
## Tỷ lệ phóng to nhân vật người chơi (~20%): mesh + capsule + hit_radius.
const PLAYER_SCALE: float = 1.2
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
	crit_rate = 0.0
	crit_dmg = 1.0

	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.32 * PLAYER_SCALE
	cs.height = 1.10 * PLAYER_SCALE
	col.shape = cs
	col.position = Vector3(0, 0.55 * PLAYER_SCALE, 0)
	add_child(col)
	hit_radius = 0.32 * PLAYER_SCALE

	skin_id = _current_skin_id()
	_mesh = _Skin.make_mesh(skin_id)
	_mesh.set_palette(_Skin.palette_for(skin_id))
	_mesh.build(self)
	_mesh.ground_anchor.scale = Vector3.ONE * PLAYER_SCALE
	_rig = _mesh.rig

	_anim = PlayerAnimator.new()
	_anim.setup(_mesh, self)

	inventory = Inventory.new()
	_setup_pickup_area()
	_add_world_voxel_bars()
	food_changed.emit(food, max_food)

func _current_skin_id() -> String:
	if SettingsData and not SettingsData.player_skin.is_empty():
		return SettingsData.player_skin
	return _Skin.FALLBACK_ID

func _add_world_voxel_bars() -> void:
	var bars := preload("res://scripts/ui/hud/world_voxel_bars.gd").new()
	add_child(bars)
	bars.setup(self)

## Đổi skin người chơi — rebuild mesh nếu skin mới có model khác.
func apply_skin(new_id: String) -> void:
	if new_id.is_empty() or new_id == skin_id:
		return
	if _Skin.get_skin(new_id).is_empty():
		return

	var old_script: String = _Skin.get_skin(skin_id).get("mesh_script", "")
	var new_script: String = _Skin.get_skin(new_id).get("mesh_script", "")
	skin_id = new_id

	if old_script != new_script:
		# Model khác — cần rebuild toàn bộ mesh
		_rebuild_mesh()
	else:
		# Cùng model — chỉ đổi màu (nhanh, không gây giật)
		if _mesh != null:
			_mesh.apply_palette(_Skin.palette_for(skin_id))

	if SettingsData:
		SettingsData.player_skin = skin_id
		SettingsData.save_settings()

## Xóa mesh cũ và build lại từ đầu với skin hiện tại.
func _rebuild_mesh() -> void:
	# Tháo equipment khỏi pivot cũ (tránh dangling ref)
	_detach_all_equipment()

	# Xóa rig cũ (kèm ground anchor)
	if _mesh != null:
		if _mesh.ground_anchor != null and is_instance_valid(_mesh.ground_anchor):
			_mesh.ground_anchor.queue_free()
		elif _mesh.rig != null and is_instance_valid(_mesh.rig):
			_mesh.rig.queue_free()

	# Build mesh mới
	_mesh = _Skin.make_mesh(skin_id)
	_mesh.set_palette(_Skin.palette_for(skin_id))
	_mesh.build(self)
	_mesh.ground_anchor.scale = Vector3.ONE * PLAYER_SCALE
	_rig = _mesh.rig

	# Khởi lại animator với mesh mới
	if _anim != null:
		_anim.setup(_mesh, self)

	# Trang bị lại equipment lên pivot mới
	_reattach_all_equipment()

## Tháo tất cả equipment nodes khỏi pivot (trước khi xóa mesh).
func _detach_all_equipment() -> void:
	if _mesh == null:
		return
	var pivots := [_mesh.helmet_pivot, _mesh.chestplate_pivot,
		_mesh.gauntlet_l_pivot, _mesh.gauntlet_r_pivot,
		_mesh.boot_l_pivot, _mesh.boot_r_pivot,
		_mesh.leg_armor_l_pivot, _mesh.leg_armor_r_pivot,
		_mesh.ring_pivot, _mesh.back_gear_pivot]
	for pv in pivots:
		if pv == null or not is_instance_valid(pv):
			continue
		for ch in pv.get_children():
			pv.remove_child(ch)
			ch.queue_free()

## Gắn lại equipment hiện tại sau khi rebuild mesh.
## Đơn giản nhất: gọi lại _apply_equipped_items nếu có, hoặc noop nếu chưa implement.
func _reattach_all_equipment() -> void:
	if has_method("_apply_equipped_items"):
		call("_apply_equipped_items")

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
	elif area is ExperienceOrb:
		(area as ExperienceOrb).collect(self)

func interact_with_nearby() -> void:
	if not can_interact():
		return
	var world := get_tree().current_scene
	if world == null:
		return
	for child in world.get_children():
		if child is FishingBoat:
			var boat := child as FishingBoat
			if boat.is_player_nearby(self):
				boat.try_board(self)
				return
			if boat.is_driver(self):
				boat.try_exit()
				return
		if child is Tractor:
			var tr := child as Tractor
			if tr.is_player_nearby(self):
				tr.try_board(self)
				return
			if tr.is_driver(self):
				tr.try_exit()
				return
		if child is RescueHelicopter:
			var he := child as RescueHelicopter
			if he.is_player_nearby(self):
				he.try_board(self)
				return
			if he.is_driver(self):
				he.try_exit()
				return
		if child is Chest and child.is_player_nearby():
			child.open_ui()
			return
		if child is CraftingTable and child.is_player_nearby():
			child.open_ui()
			return
		if child is Furnace and child.is_player_nearby():
			child.open_ui()
			return
	for d in get_tree().get_nodes_in_group("tavern_doors"):
		var door := d as _TavernDoor
		if door != null and door.is_player_nearby():
			door.toggle()
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

# ── Đói / thức ăn ─────────────────────────────────────────────────────────────

func _tick_food(delta: float) -> void:
	var interval := FOOD_IDLE_INTERVAL
	if _underwater:
		interval = FOOD_IDLE_INTERVAL / 2.0
	elif velocity.length() > 1.0:
		interval = FOOD_IDLE_INTERVAL / 1.75
	_food_timer += delta
	if _food_timer >= interval and food > 0:
		_food_timer = 0.0
		food -= 1
		food_changed.emit(food, max_food)
	_starve_timer += delta
	if _starve_timer >= 3.0 and food <= 0:
		_starve_timer = 0.0
		_Damage.take_damage(self, maxi(1, ceili(max_hp * 0.05)))
	_food_action_timer += delta
	if _food_action_timer >= 4.0 and food >= 18 and hp < max_hp:
		_food_action_timer = 0.0
		heal(1)

func get_selected_item() -> ItemDef:
	if inventory == null or _selected_slot < 0 or _selected_slot >= inventory.slots.size():
		return null
	var slot: ItemSlot = inventory.slots[_selected_slot]
	if slot.is_empty():
		return null
	return slot.item

## Đang ngắm ném trứng (item hotbar là trứng + giữ chuột trái)
func _is_egg_aiming() -> bool:
	return _bow_aiming and _EggThrow.is_egg_item(get_selected_item())

# ── Ăn: cầm đồ ăn ở slot hotbar + giữ chuột phải ────────────────────────────

func _start_eating() -> void:
	if _eating or not _active or not is_alive or not can_interact():
		return
	var item := get_selected_item()
	if item == null or item.type != ItemDef.Type.FOOD or item.heal_amount <= 0:
		return
	_eating = true
	_eat_slot = _selected_slot
	_eat_item = item
	_eat_timer = 0.0
	_state = State.EAT

func _stop_eating() -> void:
	if not _eating:
		return
	_eating = false
	_eat_item = null
	_eat_slot = -1
	_eat_timer = 0.0

func _tick_eating(delta: float) -> void:
	if inventory == null or _eat_slot < 0 or _eat_slot >= inventory.slots.size():
		_stop_eating()
		return
	var slot: ItemSlot = inventory.slots[_eat_slot]
	if slot.is_empty() or slot.item != _eat_item:
		_stop_eating()
		return
	if _selected_slot != _eat_slot or _inventory_open:
		_stop_eating()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_stop_eating()
		return
	_eat_timer += delta
	if _eat_timer >= _eat_item.eat_time:
		_eat_timer = 0.0
		_eat_bite(_eat_slot)

func _eat_bite(slot_idx: int) -> void:
	if inventory == null or slot_idx < 0 or slot_idx >= inventory.slots.size():
		return
	var slot: ItemSlot = inventory.slots[slot_idx]
	if slot.is_empty():
		return
	var item: ItemDef = slot.item
	if item.heal_amount <= 0:
		return
	var prev_food: int = food
	food = mini(max_food, food + item.heal_amount)
	var gained: int = food - prev_food
	inventory.remove_item(slot_idx, 1)
	food_changed.emit(food, max_food)
	if food >= 18 and hp < max_hp:
		heal(1)
	_spawn_eat_vfx(item)
	SFXManager.play_eat()
	if gained > 0:
		_scroll_inventory_message(tr("ATE_FOOD").format({"s": item.name, "d": gained}))

func _spawn_eat_vfx(item: ItemDef) -> void:
	var vfx := GPUParticles3D.new()
	vfx.one_shot = true
	vfx.emitting = true
	vfx.amount = 8
	vfx.lifetime = 0.6
	vfx.explosiveness = 0.8
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 45.0
	pmat.gravity = Vector3(0, -3.0, 0)
	pmat.initial_velocity_min = 0.5
	pmat.initial_velocity_max = 1.3
	pmat.scale_min = 0.03
	pmat.scale_max = 0.07
	var c: Color = item.icon_color if item != null else Color(0.9, 0.7, 0.3)
	var grad := Gradient.new()
	grad.set_color(0, Color(c.r, c.g, c.b, 0.9))
	grad.set_color(1, Color(c.r, c.g, c.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pmat.color_ramp = grad_tex
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	vfx.draw_pass_1 = quad
	vfx.process_material = pmat
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(vfx)
	vfx.global_position = global_position + Vector3(0, 1.15, 0.3)
	vfx.finished.connect(vfx.queue_free)

# ── Chết: đồ rơi vương vãi + hồi sinh ─────────────────────────────────────────

## Thay thế rương đồ cũ: đồ (trang bị + kho) rơi rải rác quanh điểm chết thành
## các DroppedItem. Nhờ gravity fix, chúng tự rơi chạm đất thật. Multiplayer vẫn
## host-authoritative qua Net relay (mọi máy rải giống hệt payload từ host).
func _spawn_scattered_drops(death_pos: Vector3 = Vector3.INF) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	# player đã hồi sinh (teleport về spawn) trước khi function được deferred
	# → lưu trước vị trí chết, không dùng global_position sau khi respawn.
	if death_pos == Vector3.INF:
		death_pos = global_position
	# Gom đồ: trang bị 7 slot + toàn bộ kho (bỏ qua vũ khí đang cầm trong hotbar
	# vì slot đó sẽ được thêm qua equipped loop — tránh drop trùng 2 lần).
	var drop_entries: Array[Dictionary] = []
	var equipped: Array = [equipped_weapon, equipped_head, equipped_body, equipped_legs, equipped_feet, equipped_back, equipped_sub]
	for it in equipped:
		if it == null:
			continue
		drop_entries.append({"def": it, "count": 1})
	if inventory != null:
		for i in range(inventory.slots.size()):
			var slot: ItemSlot = inventory.slots[i]
			if slot.is_empty() or slot.item == null:
				continue
			if i == _equipped_slot_idx and slot.item == equipped_weapon:
				continue
			drop_entries.append({"def": slot.item, "count": slot.count})
	if Net.is_active():
		# Net: mọi máy rải đồ giống hệt từ payload của host.
		var inv_data: Array = []
		for e in drop_entries:
			inv_data.append({"id": e.def.id, "count": e.count})
		Net.announce_death_chest(death_pos + Vector3(0, 0.6, 0), inv_data)
	else:
		_scatter_drop_entries(drop_entries, death_pos + Vector3(0, 0.6, 0))
	if inventory != null:
		for slot in inventory.slots:
			slot.clear()
	equipped_weapon = null
	equipped_head = null
	equipped_body = null
	equipped_legs = null
	equipped_feet = null
	equipped_back = null
	equipped_sub = null
	_refresh_backpack_state()
	_equipped_slot_idx = -1
	_equipped_durability = -1
	_update_weapon_mesh()
	_update_armor_mesh()

## Spawn các DroppedItem vương vãi quanh một điểm. Velocity tung lên + văng ra
## theo phương ngang ngẫu nhiên → nhờ gravity fix sẽ tự rơi chạm đất thật.
func _scatter_drop_entries(entries: Array[Dictionary], around: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for e in entries:
		var def_: ItemDef = e.def
		var count: int = e.count
		var ang := randf() * TAU
		var radius := randf_range(0.2, 0.9)
		var scatter_pos := around + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		var vel := Vector3(cos(ang) * randf_range(1.5, 3.0), randf_range(2.5, 4.0), sin(ang) * randf_range(1.5, 3.0))
		DroppedItem.spawn(scene, def_, scatter_pos, count, vel, around.y)

func _do_respawn() -> void:
	_stop_mining()
	_stop_eating()
	if _bow_aiming:
		_Bow.cancel_aim(self)
	global_position = WORLD_SPAWN_POS
	velocity = Vector3.ZERO
	food = max_food
	oxygen = max_oxygen
	stamina = max_stamina
	food_changed.emit(food, max_food)
	oxygen_changed.emit(int(oxygen), int(max_oxygen))
	stamina_changed.emit(stamina, max_stamina)
	revive()
	# Miễn nhiễm sau hồi sinh để slime đang canh ở điểm spawn không giết lại
	# ngay lập tức (death loop vô hạn khi không có i-frame). `_invul_timer` chỉ
	# bị trừ một lần trong _physics_process → 5.0 này là đúng 5.0s thực tế
	# (trước đây bị trừ cả _process lẫn _physics_process nên chỉ ~2.5s).
	_invul_timer = 5.0
	_sync_camera()
	_death_items_spawned = false
	_scroll_inventory_message(tr("DEATH_CHEST_MSG"))
	if Net.is_active():
		Net.announce_respawn(global_position)

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
			var src_dur: int = inventory.slots[idx].durability if idx >= 0 and idx < inventory.slots.size() else -1
			_stop_mining()
			equipped_weapon = item
			inventory.remove_item(idx, 1)
			if old != null:
				var old_dur: int = -1
				var old_slot := inventory.find_slot_of_item(old)
				if old_slot >= 0:
					old_dur = inventory.slots[old_slot].durability
				inventory.add_item(old, 1)
				if old_dur >= 0:
					var os := inventory.find_slot_of_item(old)
					if os >= 0:
						inventory.slots[os].durability = old_dur
			_equipped_slot_idx = -1
			_equipped_durability = src_dur
			_update_weapon_mesh()
			_scroll_inventory_message(tr("EQUIP_MSG").format({"s": item.name}))
		ItemDef.Type.ARMOR:
			var old: ItemDef
			match item.armor_slot:
				ItemDef.ArmorSlot.HEAD: old = equipped_head; equipped_head = item
				ItemDef.ArmorSlot.BODY: old = equipped_body; equipped_body = item
				ItemDef.ArmorSlot.LEGS: old = equipped_legs; equipped_legs = item
				ItemDef.ArmorSlot.FEET: old = equipped_feet; equipped_feet = item
				ItemDef.ArmorSlot.BACK: old = equipped_back; equipped_back = item
				ItemDef.ArmorSlot.SUB: old = equipped_sub; equipped_sub = item
			inventory.remove_item(idx, 1)
			if old != null:
				inventory.add_item(old, 1)
			_refresh_backpack_state()
			_update_armor_mesh()
			_scroll_inventory_message(tr("WEAR_MSG").format({"s": item.name}))
		ItemDef.Type.TOOL:
			var old_t: ItemDef = equipped_weapon
			var src_dur_t: int = inventory.slots[idx].durability if idx >= 0 and idx < inventory.slots.size() else -1
			_stop_mining()
			equipped_weapon = item
			inventory.remove_item(idx, 1)
			if old_t != null:
				var old_dur_t: int = -1
				var old_slot_t := inventory.find_slot_of_item(old_t)
				if old_slot_t >= 0:
					old_dur_t = inventory.slots[old_slot_t].durability
				inventory.add_item(old_t, 1)
				if old_dur_t >= 0:
					var os_t := inventory.find_slot_of_item(old_t)
					if os_t >= 0:
						inventory.slots[os_t].durability = old_dur_t
			_equipped_slot_idx = -1
			_equipped_durability = src_dur_t
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

## Cập nhật mesh trang bị trên người cho mọi slot.
## Slot: 0=head 1=body 2=legs 3=feet 4=back 5=sub.
func _update_armor_mesh() -> void:
	if _mesh == null:
		return
	_clear_armor_pivot(_mesh.helmet_pivot)
	_clear_armor_pivot(_mesh.chestplate_pivot)
	_clear_armor_pivot(_mesh.gauntlet_l_pivot)
	_clear_armor_pivot(_mesh.gauntlet_r_pivot)
	_clear_armor_pivot(_mesh.leg_armor_l_pivot)
	_clear_armor_pivot(_mesh.leg_armor_r_pivot)
	_clear_armor_pivot(_mesh.boot_l_pivot)
	_clear_armor_pivot(_mesh.boot_r_pivot)
	_clear_armor_pivot(_mesh.ring_pivot)
	_clear_armor_pivot(_mesh.back_gear_pivot)
	if _mesh.backpack != null:
		_mesh.backpack.visible = not (equipped_back != null and _is_armor_visible(4))
	if _mesh.torso != null:
		_mesh.torso.visible = not (equipped_body != null and _is_armor_visible(1))
	if _mesh.hair_pivot != null:
		_mesh.hair_pivot.visible = not (equipped_head != null and _is_armor_visible(0))
	if _mesh.tails_pivot != null:
		_mesh.tails_pivot.visible = not (equipped_head != null and _is_armor_visible(0))
	if equipped_head != null and _is_armor_visible(0):
		_build_armor(_mesh.helmet_pivot, equipped_head.id)
	if equipped_body != null and _is_armor_visible(1):
		_build_armor(_mesh.chestplate_pivot, equipped_body.id)
		ItemMesh.build_gauntlet(_mesh.gauntlet_l_pivot)
		ItemMesh.build_gauntlet(_mesh.gauntlet_r_pivot)
	if equipped_legs != null and _is_armor_visible(2):
		_build_armor(_mesh.leg_armor_l_pivot, equipped_legs.id)
		_build_armor(_mesh.leg_armor_r_pivot, equipped_legs.id)
	if equipped_feet != null and _is_armor_visible(3):
		_build_armor(_mesh.boot_l_pivot, equipped_feet.id)
		_build_armor(_mesh.boot_r_pivot, equipped_feet.id)
	if equipped_sub != null and _is_armor_visible(5):
		_build_armor(_mesh.ring_pivot, equipped_sub.id)
	if equipped_back != null and _is_armor_visible(4):
		_build_armor(_mesh.back_gear_pivot, equipped_back.id)

func _clear_armor_pivot(pivot: Node3D) -> void:
	if pivot == null:
		return
	for ch in pivot.get_children():
		ch.queue_free()

func _build_armor(pivot: Node3D, item_id: String) -> void:
	if pivot == null:
		return
	var shell := Node3D.new()
	pivot.add_child(shell)
	ItemMesh.build(shell, item_id)
	# Ba lô da thú: mặt trang trí (nắp + khoá) được dựng ở +Z cục bộ, nhưng khi
	# đeo vào lưng (mặt lưng = -Z) phải quay 180° để mặt chính hướng ra ngoài.
	if item_id == "leather_backpack":
		shell.rotation.y = PI

func _is_armor_visible(slot_idx: int) -> bool:
	return armor_visible.get(slot_idx, true)

## Bật/tắt hiển thị model trang bị theo slot, sau đó refresh mesh ngay.
func set_armor_visible(slot_idx: int, visible: bool) -> void:
	armor_visible[slot_idx] = visible
	_update_armor_mesh()

func get_armor_visible(slot_idx: int) -> bool:
	return armor_visible.get(slot_idx, true)

## Truy cập trang bị theo thứ tự slot UI: 0=head 1=body 2=legs 3=feet 4=back 5=sub
func get_equipped_by_slot(idx: int) -> ItemDef:
	var arr := [equipped_head, equipped_body, equipped_legs, equipped_feet,
		equipped_back, equipped_sub]
	if idx < 0 or idx >= arr.size():
		return null
	return arr[idx] as ItemDef

func set_equipped_by_slot(idx: int, item: ItemDef) -> void:
	match idx:
		0: equipped_head = item
		1: equipped_body = item
		2: equipped_legs = item
		3: equipped_feet = item
		4: equipped_back = item
		5: equipped_sub = item
	_update_armor_mesh()
	if idx == 4:
		_refresh_backpack_state()

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
		_ak_recoil = 0.0
		_ak_hold_captured = false
		_m200_aiming = false
		_m200_bolt_cd = 0.0
		_m200_recoil = 0.0
		_m200_hold_captured = false
		return
	if item_id in ["pickaxe", "shovel", "axe", "hoe", "iron_sword", "fishing_rod", "iron_greatsword", "leather_gloves", "crossbow", "arrow", "watermelon_cannon", "watermelon_nuke_ammo", "pumpkin_mortar", "iron_halberd", "flashlight", "ak_12", "bullet_762mm", "m200", "bullet_338mm"]:
		if item_id != "ak_12":
			_ak_recoil = 0.0
			_ak_hold_captured = false
		if item_id != "m200":
			_m200_aiming = false
			_m200_bolt_cd = 0.0
			_m200_recoil = 0.0
			_m200_hold_captured = false
		ToolsMesh.build_held(pivot, item_id)
		if item_id == "crossbow":
			_bow_string_node = null
	else:
		var held_scale := Node3D.new()
		held_scale.scale = Vector3(1.5, 1.5, 1.5)
		pivot.add_child(held_scale)
		ItemMesh.build(held_scale, item_id)

## Cầm weapon trực tiếp từ hotbar (không remove khỏi inventory)
func equip_weapon_direct(item: ItemDef, slot_idx: int = -1) -> void:
	print("[Player] equip_weapon_direct: ", item.id if item != null else "null")
	_stop_mining()
	equipped_weapon = item
	_equipped_slot_idx = slot_idx
	_equipped_durability = -1
	_update_weapon_mesh()

func get_total_atk() -> int:
	var base: int = attack_power
	if equipped_weapon != null:
		base += equipped_weapon.atk_bonus
	return base

func get_total_def() -> float:
	var base: float = defense
	for slot in [equipped_head, equipped_body, equipped_legs, equipped_feet, equipped_back, equipped_sub]:
		if slot != null:
			base += slot.def_bonus
	return base

## Kháng sát thương chí mạng — cộng dồn từ trang bị (nón sắt +1).
func get_total_crit_resist() -> float:
	var r: float = 0.0
	for slot in [equipped_head, equipped_body, equipped_legs, equipped_feet, equipped_back, equipped_sub]:
		if slot != null:
			r += slot.crit_resist_bonus
	return r

## May mắn tổng (chỉ số ẩn) — ảnh hưởng tỷ lệ đồ hiếm khi câu cá.
func get_total_luck() -> float:
	var n: float = luck
	if equipped_sub != null:
		n += equipped_sub.luck_bonus
	return n

# ── Trọng lượng kho đồ & quá tải ──────────────────────────────────────────────
func get_total_weight() -> float:
	if inventory == null:
		return 0.0
	return inventory.get_total_weight()

## Giới hạn tải hiệu dụng — nhân với hệ số từ ba lô (+5%).
func get_max_weight() -> float:
	var mult: float = 1.0
	if equipped_back != null and equipped_back.weight_multiplier > 0.0:
		mult = equipped_back.weight_multiplier
	return maxf(max_weight, 0.0) * mult

## Đồng bộ kích thước kho đồ theo ba lô đang đeo (gọi khi trang bị/tháo ba lô).
func _refresh_backpack_state() -> void:
	if inventory == null:
		return
	var bonus: int = equipped_back.inv_slots_bonus if equipped_back != null else 0
	var target: int = Inventory.DEFAULT_SIZE + bonus
	var base_ok: bool = target <= inventory.slots.size() or bonus <= 0
	inventory.resize_slots(target)
	_backpack_slots_applied = maxi(0, inventory.slots.size() - Inventory.DEFAULT_SIZE) if base_ok else bonus

## Cập nhật hiệu ứng quá tải theo trọng lượng hiện tại (gọi mỗi frame).
##   - vượt ngưỡng        → làm chậm 2 (30%)
##   - vượt quá 25% ngưỡng → làm chậm 5 (95%, không nhảy, không tương tác)
func update_overload_effects() -> void:
	if effects == null:
		return
	var w := get_total_weight()
	var limit := get_max_weight()
	if w > limit * 1.25:
		effects.set_persistent_slow(5)
	elif w > limit:
		effects.set_persistent_slow(2)
	else:
		effects.set_persistent_slow(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if _is_building_placing():
		return
	if not _active or not is_alive or not _is_player:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if _bow_aiming:
				if k.is_action_pressed("controls/inventory") or k.is_action_pressed("controls/build") \
						or k.is_action_pressed("ui_cancel") or k.is_action_pressed("jump"):
					var is_mortar := equipped_weapon != null and equipped_weapon.id == "pumpkin_mortar"
					if _is_egg_aiming():
						_EggThrow.cancel_aim(self)
					elif is_mortar:
						_Mortar.cancel_aim(self)
					else:
						_Bow.cancel_aim(self)
					return
			if (_halberd_charge_time >= 0.0 or _halberd_throwing) and (k.is_action_pressed("controls/inventory") \
					or k.is_action_pressed("controls/build") or k.is_action_pressed("ui_cancel")):
				_Halberd.cancel_aim(self)
				return
			if k.is_action_pressed("jump") and _freeze_timer <= 0.0 and can_jump():
				_jbuf = JUMP_BUFFER
			if k.is_action_pressed("save_game"):
				if SaveManager:
					SaveManager.save_game()
					_scroll_inventory_message(tr("GAME_SAVED"))
	super._unhandled_key_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if not _active or not is_alive:
		return
	if _is_building_placing():
		return
	if event is InputEventMouseMotion:
		_update_block_target()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_stop_mining()
			_stop_eating()
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _bow_aiming:
			if equipped_weapon != null and equipped_weapon.id == "m200":
				# M200: nhả LMB = bắn 1 phát (kèm hồi thoi nòng).
				_M200.fire(self)
				return
			if equipped_weapon != null and equipped_weapon.id == "ak_12":
				# Nhả LMB: dừng bắn, ADS vẫn giữ (bật/tắt bằng RMB).
				return
			if _is_egg_aiming():
				_EggThrow.fire(self)
			elif equipped_weapon and equipped_weapon.id == "crossbow":
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
			# AK-12: chuột phải bật/tắt ADS (ngắm), chuột trái để bắn.
			if equipped_weapon != null and equipped_weapon.id == "ak_12":
				_AK.toggle_ads(self)
				return
			if _bow_aiming:
				var is_mortar := equipped_weapon != null and equipped_weapon.id == "pumpkin_mortar"
				if _is_egg_aiming():
					_EggThrow.cancel_aim(self)
				elif is_mortar:
					_Mortar.cancel_aim(self)
				else:
					_Bow.cancel_aim(self)
				return
			if _halberd_charge_time >= 0.0 or _halberd_throwing:
				_Halberd.cancel_aim(self)
				return
			# Ăn: cầm đồ ăn ở slot hotbar đang chọn — giữ chuột phải tới khi ăn xong
			var held := get_selected_item()
			if held != null and held.type == ItemDef.Type.FOOD:
				_start_eating()
				return
			# Mining — cúp/xẻng on RIGHT click (giữ chuột để đào)
			if equipped_weapon != null:
				var wep_id: String = equipped_weapon.id
				if wep_id == "hoe":
					var tgt: Vector3
					if _has_target:
						tgt = _target_block
					else:
						tgt = _raycast_target_block()
					if tgt != Vector3.ZERO:
						var owm_t: Node = _open_world_manager()
						if owm_t:
							var blk_id_t: int = owm_t.get_block(tgt.x, tgt.y, tgt.z)
							if _Data.is_tillable(blk_id_t):
								owm_t.till_block(tgt.x, tgt.y, tgt.z)
								SFXManager.play_block_break()
								_damage_equipped_tool(1)
							else:
								_scroll_inventory_message("(không thể cuốc)")
					return
				if wep_id == "pickaxe" or wep_id == "shovel" or wep_id == "axe":
					var mine_tgt: Vector3
					if _has_target:
						mine_tgt = _target_block
					else:
						mine_tgt = _raycast_target_block()
					if mine_tgt != Vector3.ZERO:
						_start_mining(mine_tgt)
					return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var holding_heavy: bool = equipped_weapon != null and \
				(equipped_weapon.id == "axe" or equipped_weapon.id == "pickaxe" or equipped_weapon.id == "hoe")
			if not holding_heavy and can_interact():
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
			if _EggThrow.is_egg_item(get_selected_item()):
				_EggThrow.start_aim(self)
				return
			if equipped_weapon != null:
				match equipped_weapon.id:
					"ak_12": _AK.start_fire(self); return
					"m200": _M200.start_aim(self); return
					"crossbow": _Bow.start_aim(self); return
					"pumpkin_mortar": _Mortar.start_aim(self); return
					"watermelon_cannon": _Bow.start_cannon_aim(self); return
					"fishing_rod": _Fishing.action(self); return
					"iron_halberd": return
				if _freeze_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
					var wep_id: String = equipped_weapon.id if equipped_weapon else ""
					var is_heavy: bool = wep_id == "axe" or wep_id == "pickaxe" or wep_id == "hoe"
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
						"hoe": attack_duration = 0.60; _melee_hit_progress = 0.30
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
	return _Data.is_shovelable(blk)

# ── Đào nhấn-giữ ────────────────────────────────────────────────────────────
## Bắt đầu đào: xác thực block/công cụ rồi bật trạng thái giữ chuột.
func _start_mining(target: Vector3) -> void:
	if not can_interact():
		return
	if equipped_weapon == null:
		return
	var owm := _open_world_manager()
	if owm == null or not owm.has_method("get_block"):
		return
	var bid: int = owm.get_block(target.x, target.y, target.z)
	if bid == _Data.BlockID.AIR:
		return
	# Nước: múc ngay (cơ chế cũ, không hao độ bền)
	if _Data.is_water(bid):
		if owm.break_block(target.x, target.y, target.z) != 0:
			SFXManager.play_block_break()
		return
	var hardness: float = _Data.get_block_hardness(bid)
	if hardness < 0.0:
		_scroll_inventory_message("(không thể phá)")
		return
	var wep := equipped_weapon.id
	if wep != "pickaxe" and wep != "shovel" and wep != "axe":
		return
	if _equipped_durability_now() == 0:
		_scroll_inventory_message("(công cụ đã vỡ)")
		return
	var correct: bool = (_Data.is_pickaxable(bid) and wep == "pickaxe") \
		or (_Data.is_shovelable(bid) and wep == "shovel") \
		or (_Data.is_axable(bid) and wep == "axe")
	if hardness <= 0.0 or not correct:
		if _Data.is_axable(bid):
			_scroll_inventory_message("(cần rìu để chặt gỗ)")
		elif wep == "pickaxe":
			_scroll_inventory_message("(cần xẻng để đào đất)")
		else:
			_scroll_inventory_message("(cần cúp để đào đá)")
		return
	_mining = true
	_mine_progress = 0.0
	_mine_block = target
	_mine_block_id = bid

func _stop_mining() -> void:
	_mining = false
	_mine_progress = 0.0
	_mine_bar_hide()

func _process_mining(delta: float) -> void:
	if not _mining:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_stop_mining()
		return
	if equipped_weapon == null \
			or (equipped_weapon.id != "pickaxe" and equipped_weapon.id != "shovel" \
			and equipped_weapon.id != "axe"):
		_stop_mining()
		return
	if _equipped_durability_now() <= 0:
		_stop_mining()
		return
	var target := _target_block if _has_target else Vector3.ZERO
	if target == Vector3.ZERO:
		_mine_progress = 0.0
		_mine_bar_hide()
		return
	if target != _mine_block:
		_mine_block = target
		_mine_block_id = 0
		_mine_progress = 0.0
	var owm := _open_world_manager()
	if owm == null:
		return
	var bid: int = owm.get_block(target.x, target.y, target.z)
	if bid == _Data.BlockID.AIR or bid != _mine_block_id:
		_mine_block_id = bid
		_mine_progress = 0.0
	if bid == _Data.BlockID.AIR:
		_mine_bar_hide()
		return
	var hardness: float = _Data.get_block_hardness(bid)
	if hardness <= 0.0:
		_mine_progress = 0.0
		_mine_bar_hide()
		return
	_mine_progress += delta / hardness
	if _mine_progress >= 1.0:
		_mine_progress = 0.0
		_mine_bar_hide()
		_break_mine_block(target, bid)
		return
	_mine_bar_ensure()
	_mine_bar.show_at(target + Vector3(0, 0.62, 0), _mine_progress)

func _break_mine_block(target: Vector3, bid: int) -> void:
	var owm := _open_world_manager()
	if owm == null:
		return
	var old_block: int = owm.break_block(target.x, target.y, target.z)
	if old_block != 0:
		var item_id: String = _Data.BLOCK_TO_ITEM.get(old_block, "")
		if not item_id.is_empty():
			var def: ItemDef = ItemDatabase.items_db.get(item_id) as ItemDef
			if def:
				DroppedItem.spawn(owm, def, target)
		SFXManager.play_block_break()
		_damage_equipped_tool(1)

func _mine_bar_ensure() -> void:
	if _mine_bar == null:
		_mine_bar = MiningProgressBar.new()
		add_child(_mine_bar)

func _mine_bar_hide() -> void:
	if _mine_bar != null:
		_mine_bar.hide_bar()

# ── Độ bền công cụ ──────────────────────────────────────────────────────────
## Độ bền hiện tại của vũ khí đang cầm (-1 = không dùng độ bền).
func _equipped_durability_now() -> int:
	if equipped_weapon == null or equipped_weapon.max_durability <= 0:
		return -1
	if inventory == null:
		return -1
	if _equipped_slot_idx >= 0 and _equipped_slot_idx < inventory.slots.size():
		var slot := inventory.slots[_equipped_slot_idx]
		if slot.item == equipped_weapon and slot.durability >= 0:
			return slot.durability
		_equipped_slot_idx = -1
	if _equipped_durability >= 0:
		return _equipped_durability
	return -1

## Hao mòn độ bền; vỡ thì hủy công cụ + bỏ cầm.
func _damage_equipped_tool(amount: int) -> void:
	if equipped_weapon == null or equipped_weapon.max_durability <= 0:
		return
	if inventory == null:
		return
	if _equipped_durability_now() < 0:
		return
	var broken := false
	if _equipped_slot_idx >= 0 and _equipped_slot_idx < inventory.slots.size() \
			and inventory.slots[_equipped_slot_idx].item == equipped_weapon:
		broken = not inventory.damage_slot_durability(_equipped_slot_idx, amount)
	else:
		_equipped_durability = maxi(_equipped_durability - amount, 0)
		broken = _equipped_durability <= 0
	if broken:
		_on_tool_broken()

func _on_tool_broken() -> void:
	if inventory != null and _equipped_slot_idx >= 0 and _equipped_slot_idx < inventory.slots.size():
		inventory.remove_item(_equipped_slot_idx, 1)
	_equipped_slot_idx = -1
	_equipped_durability = -1
	equipped_weapon = null
	_stop_mining()
	_update_weapon_mesh()
	SFXManager.play_hurt()
	_scroll_inventory_message("(công cụ đã vỡ — hết độ bền!)")

func _update_block_target() -> void:
	_ensure_highlight()
	var can_mine := equipped_weapon != null and (equipped_weapon.id == "pickaxe" or equipped_weapon.id == "shovel" or equipped_weapon.id == "axe" or equipped_weapon.id == "hoe")
	if not can_mine:
		_block_highlight.visible = false
		_has_target = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	# Cam 3 chuột bị khóa giữa màn hình → highlight block theo tâm thay vì con trỏ.
	var mouse_pos: Vector2 = get_viewport().get_visible_rect().size * 0.5 if _use_tp else get_viewport().get_mouse_position()
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
	var is_egg_aiming := _is_egg_aiming()
	var is_bow_aim_no_cannon := _bow_aiming and not is_cannon_aiming and not is_mortar_aiming and not is_egg_aiming and not _halberd_throwing
	if is_bow_aim_no_cannon:
		var reduced := 3.6 * 0.55
		move_speed = reduced
		sprint_speed = reduced
	elif is_cannon_aiming or is_mortar_aiming or is_egg_aiming:
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
	update_overload_effects()
	if _active and is_alive:
		_tick_food(delta)
		if _eating:
			_tick_eating(delta)
	combo_timer = max(combo_timer - delta, 0.0)
	_update_block_target()
	_process_mining(delta)
	_Bow.update_pose(self)
	_AK.update_pose(self, delta)
	_M200.update_pose(self, delta)
	if _m200_bolt_cd > 0.0:
		_m200_bolt_cd = maxf(_m200_bolt_cd - delta, 0.0)
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
			if equipped_weapon != null and equipped_weapon.id == "m200":
				_M200.cancel_aim(self)
			elif equipped_weapon != null and equipped_weapon.id == "ak_12":
				_AK.cancel_aim(self)
			elif _is_egg_aiming():
				_EggThrow.cancel_aim(self)
			elif is_mortar:
				_Mortar.cancel_aim(self)
			else:
				_Bow.cancel_aim(self)
		else:
			var is_mortar := equipped_weapon != null and equipped_weapon.id == "pumpkin_mortar"
			if equipped_weapon != null and equipped_weapon.id == "m200":
				_Bow.update_aim(self, delta)
			elif equipped_weapon != null and equipped_weapon.id == "ak_12":
				_Bow.update_aim(self, delta)
				_AK.update_fire(self, delta)
			elif _is_egg_aiming():
				_EggThrow.update_aim(self, delta)
			elif is_mortar:
				_Mortar.update_aim(self, delta)
			else:
				_Bow.update_aim(self, delta)
	_sync_aim_camera_zoom()
	if _halberd_throwing and _state == State.HIT:
		_Halberd.cancel_aim(self)

func _sync_aim_camera_zoom() -> void:
	# Góc 3: khi nhấn giữ chuột trái để aim (nỏ/súng cối/pháo dưa hấu)
	# thì zoom camera gần player theo kiểu bắn súng.
	if _use_tp and is_instance_valid(_tp_rig) and _tp_rig.has_method("set_aim"):
		var aiming := _bow_aiming
		if aiming:
			var is_egg := _is_egg_aiming()
			if is_egg or _halberd_throwing or _halberd_charge_time >= 0.0:
				aiming = false
		_tp_rig.set_aim(aiming)

func _on_dash() -> void:
	_Halberd.on_dash(self)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _eating and is_alive and _active and not _underwater:
		_state = State.EAT
		velocity.x *= 0.5
		velocity.z *= 0.5
	if not is_alive and _death_timer <= 0.0 and not _death_items_spawned:
		_death_items_spawned = true
		var death_pos: Vector3 = global_position
		_do_respawn()
		call_deferred("_spawn_scattered_drops", death_pos)
		return
	if _halberd_dashing:
		if _state == State.DASH:
			_Halberd.check_dash_hit(self)
		else:
			_halberd_dashing = false

func _raycast_target_block() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null: return Vector3.ZERO
	var aim_pos: Vector2 = get_viewport().get_visible_rect().size * 0.5 if _use_tp else get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(aim_pos)
	var dir := cam.project_ray_normal(aim_pos)
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
	if Net.is_active():
		Net.death_chest_spawned.connect(_on_net_death_chest_spawned)

func _on_net_death_chest_spawned(_owner_peer: int, pos: Vector3, inv_data: Array) -> void:
	var entries: Array[Dictionary] = []
	for entry in inv_data:
		if entry == null:
			continue
		var item_id: String = str(entry.get("id", ""))
		var def_: ItemDef = ItemDatabase.items_db.get(item_id) if ItemDatabase.items_db.has(item_id) else null
		if def_ == null:
			# Legacy payload từ Inventory.to_dict(): slot rỗng = null, item = có "id".
			continue
		var count: int = int(entry.get("count", 1))
		if count <= 0:
			continue
		entries.append({"def": def_, "count": count})
	_scatter_drop_entries(entries, pos)

func _animate(delta: float) -> void:
	_anim.animate(delta)
