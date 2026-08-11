extends Node
class_name PlacementSystem

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _FurnaceScript = preload("res://scripts/items/entities/furnace.gd")
const _FishingBoat = preload("res://scripts/items/entities/fishing_boat.gd")
const _Tractor = preload("res://scripts/items/entities/tractor.gd")
const _RescueHelicopter = preload("res://scripts/items/entities/rescue_helicopter.gd")
const _EggplantProp = preload("res://scripts/world/props/eggplant_prop.gd")
const _WatermelonVine = preload("res://scripts/world/props/watermelon_vine_prop.gd")
const _PumpkinVine = preload("res://scripts/world/props/pumpkin_vine_prop.gd")
const _OrangeTreeProp = preload("res://scripts/world/props/orange_tree_prop.gd")
const VOXEL: float = 0.50

var _placing: bool = false
var _item_id: String = ""
var _ghost: Node3D = null
var _ghost_valid: bool = false
var _ghost_pos: Vector3 = Vector3.ZERO
var _placement_rotation: float = 0.0
var _player_inv: Inventory = null
var _player: Node3D = null

var _pending_placement: bool = false
var _pending_item: String = ""
var _pending_pos: Vector3 = Vector3.ZERO
var _throw_duration: float = 0.0
var _throw_progress: float = 0.0
var _throw_mesh: Node3D = null
var _throw_start: Vector3 = Vector3.ZERO
var _throw_target: Vector3 = Vector3.ZERO
var _throw_arc_height: float = 4.0

func _exit_tree() -> void:
	if get_tree() != null and get_tree().root.has_meta("building_placement_active"):
		get_tree().root.set_meta("building_placement_active", false)
	if _throw_mesh != null and is_instance_valid(_throw_mesh):
		_throw_mesh.queue_free()
	_throw_mesh = null
	_pending_placement = false

func set_player_inventory(inv: Inventory, player_node: Node3D = null) -> void:
	_player_inv = inv
	if player_node != null:
		_player = player_node

func is_placing() -> bool:
	return _placing or _pending_placement

func get_ghost_position() -> Vector3:
	return _ghost_pos

func start_placement(item_id: String) -> void:
	if _player_inv == null:
		return
	var count: int = _player_inv.get_item_count(item_id)
	if count <= 0:
		return
	_item_id = item_id
	_placing = true
	_placement_rotation = 0.0
	get_tree().root.set_meta("building_placement_active", true)
	_make_ghost()

func rotate_placement(clockwise: bool = true) -> void:
	if not _placing or _pending_placement:
		return
	_placement_rotation += deg_to_rad(90.0 if clockwise else -90.0)
	if _ghost:
		_ghost.rotation.y = _placement_rotation

func _clear_ghost_children() -> void:
	if _ghost == null:
		return
	for child in _ghost.get_children():
		child.queue_free()

func _make_ghost() -> void:
	if _ghost == null:
		_ghost = Node3D.new()
		add_child(_ghost)
	else:
		_clear_ghost_children()
	_ghost.visible = false

	if _item_id == "twilight_gate":
		_build_ghost_portal()
	elif _item_id == "fishing_boat":
		_build_ghost_boat()
	elif _item_id == "tractor":
		_build_ghost_tractor()
	elif _item_id == "rescue_helicopter":
		_build_ghost_helicopter()
	elif _item_id == "chest":
		_build_ghost_chest()
	elif _item_id == "crafting_table":
		_build_ghost_crafting_table()
	elif _item_id == "furnace":
		_build_ghost_furnace()
	elif _is_seed_item(_item_id):
		_build_ghost_seed()
	elif _Data.ITEM_TO_BLOCK.has(_item_id):
		_build_ghost_block()
	_ghost.rotation.y = _placement_rotation

## ── Mầm cây ─────────────────────────────────────────────────────────────────
const SEED_ITEMS: Array[String] = ["coconut_seed", "taro_seed", "seaweed_seed", "seagrass_seed", "eggplant_seed", "watermelon_seed", "pumpkin_seed", "orange_seed"]

static func _is_seed_item(item_id: String) -> bool:
	return item_id in SEED_ITEMS

func _build_ghost_seed() -> void:
	var seed_mat := _ghost_mat(Color(0.30, 0.55, 0.20, 0.35), Color(0.15, 0.45, 0.20), 0.3)
	var base_mat := _ghost_mat(Color(0.40, 0.28, 0.14, 0.30), Color(0.10, 0.10, 0.10), 0.0)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(VOXEL * 0.7, VOXEL * 0.35, VOXEL * 0.7)
	mi.mesh = box
	mi.material_override = base_mat
	_ghost.add_child(mi)
	var sprout := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(VOXEL * 0.45, VOXEL * 0.9, VOXEL * 0.45)
	sprout.mesh = sbox
	sprout.material_override = seed_mat
	sprout.position = Vector3(0, VOXEL * 0.6, 0)
	_ghost.add_child(sprout)

## Nền trồng hợp lệ: dừa/môn chỉ trên đất tơi xốp; rong/cỏ biển trên cát/bùn dưới nước.
func _can_plant_seed(item_id: String, pos: Vector3) -> bool:
	var owm := _find_world_manager()
	if owm == null or not owm.has_method("get_block"):
		return false
	var below: int = owm.get_block(pos.x, pos.y - VOXEL, pos.z)
	if item_id == "seaweed_seed" or item_id == "seagrass_seed":
		if not _is_seaweed_bed(below):
			return false
		if not _Data.is_water(owm.get_block(pos.x, pos.y, pos.z)):
			return false
		if item_id == "seagrass_seed":
			var gap: float = _measure_water_gap(owm, pos)
			return gap >= 1.25 and gap <= 3.5
		return true
	return below == _Data.BlockID.TILLED_SOIL

static func _is_seaweed_bed(bid: int) -> bool:
	return bid == _Data.BlockID.SAND or bid == _Data.BlockID.SAND_DEEP \
		or bid == _Data.BlockID.OCEAN_SAND or bid == _Data.BlockID.MUDDY_SAND \
		or bid == _Data.BlockID.OCEAN_GRAVEL or bid == _Data.BlockID.OCEAN_MUD \
		or bid == _Data.BlockID.SILT

func _measure_water_gap(owm: Node, pos: Vector3) -> float:
	var gap := 0.0
	var y := pos.y
	while y < pos.y + 3.0:
		if not _Data.is_water(owm.get_block(pos.x, y, pos.z)):
			break
		gap += VOXEL
		y += VOXEL
	return gap

## Trồng mầm: dừa → cây dừa, môn → cây môn, rong/cỏ biển → cây thủy sinh.
func _plant_seed(item_id: String, pos: Vector3) -> void:
	var world_mgr := _find_world_manager()
	if world_mgr == null or not _can_plant_seed(item_id, pos):
		var item_def := ItemDatabase.items_db.get(item_id) as ItemDef
		if item_def and _player_inv:
			_player_inv.add_item(item_def, 1)
		SFXManager.play_block_break()
		return
	var prop: Node3D
	if item_id == "coconut_seed":
		prop = PalmProp.new(150, DestroyableProp.WeaponReq.AXE, "palm_wood")
		prop.setup("river")
	elif item_id == "taro_seed":
		prop = PlantProp.new(50, DestroyableProp.WeaponReq.SWORD, "taro")
		prop.setup("taro", randi(), randi(), true, 0.0)
	elif item_id == "seagrass_seed":
		prop = PlantProp.new(50, DestroyableProp.WeaponReq.SWORD, "seagrass")
		prop.setup("seagrass", randi(), randi(), true, _measure_water_gap(world_mgr, pos), false)
	elif item_id == "eggplant_seed":
		prop = _EggplantProp.new(40, DestroyableProp.WeaponReq.SWORD, "eggplant_fruit")
		prop.setup()
	elif item_id == "watermelon_seed":
		prop = _WatermelonVine.new(40, DestroyableProp.WeaponReq.SWORD, "watermelon")
		prop.setup()
	elif item_id == "pumpkin_seed":
		prop = _PumpkinVine.new(40, DestroyableProp.WeaponReq.SWORD, "pumpkin")
		prop.setup()
	elif item_id == "orange_seed":
		prop = _OrangeTreeProp.new(150, DestroyableProp.WeaponReq.AXE, "orange")
		prop.setup("plains")
	else:
		prop = PlantProp.new(50, DestroyableProp.WeaponReq.SWORD, "tropical_seaweed")
		prop.setup("weed", randi(), randi(), true, _measure_water_gap(world_mgr, pos))
	prop.name = "PlantedCrop"
	prop.position = pos
	world_mgr.add_child(prop)
	SFXManager.play_block_place()

func _build_ghost_block() -> void:
	var block_mat := _ghost_mat(Color(0.80, 0.80, 0.80, 0.30), Color(0.40, 0.40, 0.40), 0.0)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var bid: int = _Data.ITEM_TO_BLOCK.get(_item_id, 0)
	var shape: Vector3 = _Data.block_shape(bid)
	if shape != Vector3.ZERO:
		# Block hình dạng riêng — hộp đúng kích thước, đáy trùng với vị trí đặt
		box.size = shape
		mi.position = Vector3(0, shape.y * 0.5, 0)
	else:
		box.size = Vector3(VOXEL, VOXEL, VOXEL)
	mi.mesh = box
	mi.material_override = block_mat
	_ghost.add_child(mi)

func _build_ghost_portal() -> void:
	var base_mat := _ghost_mat(Color(0.10, 0.30, 0.30, 0.25), Color(0.06, 0.18, 0.18), 0.2)
	var off: Vector3 = Vector3(-2.0, -VOXEL * 0.5, -1.5)
	for x in range(9):
		for z in range(7):
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(VOXEL, VOXEL, VOXEL)
			mi.mesh = box
			mi.material_override = base_mat
			mi.position = off + Vector3(x * VOXEL, 0.0, z * VOXEL)
			_ghost.add_child(mi)

	var frame_mat := _ghost_mat(Color(0.15, 0.45, 0.40, 0.35), Color(0.10, 0.35, 0.30), 0.6)
	var ox: float = -1.0
	for y in range(0, 8):
		if y == 0 or y == 7:
			for x in range(5):
				var p := Vector3(ox + x * VOXEL, y * VOXEL, 0.0)
				var mi := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(VOXEL, VOXEL, VOXEL)
				mi.mesh = box
				mi.material_override = frame_mat
				mi.position = p
				_ghost.add_child(mi)
		else:
			for side in [0, 4]:
				var p := Vector3(ox + side * VOXEL, y * VOXEL, 0.0)
				var mi := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(VOXEL, VOXEL, VOXEL)
				mi.mesh = box
				mi.material_override = frame_mat
				mi.position = p
				_ghost.add_child(mi)

## Ghost thuyền: phác thảo theo kích thước thật (dài 3.4, rộng 1.4).
func _build_ghost_boat() -> void:
	var hull_mat := _ghost_mat(Color(0.50, 0.32, 0.14, 0.30), Color(0.15, 0.08, 0.04), 0.2)
	var deck_mat := _ghost_mat(Color(0.62, 0.45, 0.22, 0.30), Color(0.20, 0.12, 0.06), 0.2)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 0.55, 3.4)
	mi.mesh = box
	mi.material_override = hull_mat
	mi.position = Vector3(0, -0.14, 0)
	_ghost.add_child(mi)
	var deck := MeshInstance3D.new()
	var dbox := BoxMesh.new()
	dbox.size = Vector3(1.2, 0.1, 2.6)
	deck.mesh = dbox
	deck.material_override = deck_mat
	deck.position = Vector3(0, 0.14, 0.3)
	_ghost.add_child(deck)

## Ghost máy kéo: đầu kéo dài 2.6 + rơ-moọc dài 2.3 (bám mặt đất).
func _build_ghost_tractor() -> void:
	var body_mat := _ghost_mat(Color(0.72, 0.10, 0.08, 0.30), Color(0.30, 0.05, 0.04), 0.2)
	var trailer_mat := _ghost_mat(Color(0.45, 0.32, 0.16, 0.30), Color(0.16, 0.10, 0.05), 0.2)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 1.5, 2.6)
	mi.mesh = box
	mi.material_override = body_mat
	mi.position = Vector3(0, 0.75, 0.1)
	_ghost.add_child(mi)
	var tr := MeshInstance3D.new()
	var tbox := BoxMesh.new()
	tbox.size = Vector3(1.15, 1.1, 2.3)
	tr.mesh = tbox
	tr.material_override = trailer_mat
	tr.position = Vector3(0, 0.55, 2.85)
	_ghost.add_child(tr)

## Ghost trực thăng cứu hộ: thân 3.3 + đuôi 2.6 + cánh quạt.
func _build_ghost_helicopter() -> void:
	var body_mat := _ghost_mat(Color(0.78, 0.14, 0.10, 0.30), Color(0.30, 0.04, 0.04), 0.2)
	var white_mat := _ghost_mat(Color(0.92, 0.90, 0.86, 0.30), Color(0.30, 0.28, 0.26), 0.2)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.9, 3.1)
	mi.mesh = box
	mi.material_override = body_mat
	mi.position = Vector3(0, 0.75, 0.35)
	_ghost.add_child(mi)
	var tail := MeshInstance3D.new()
	var tbox := BoxMesh.new()
	tbox.size = Vector3(0.35, 0.4, 2.4)
	tail.mesh = tbox
	tail.material_override = white_mat
	tail.position = Vector3(0, 0.85, 3.1)
	_ghost.add_child(tail)

func _build_ghost_chest() -> void:
	var body_mat := _ghost_mat(Color(0.35, 0.22, 0.12, 0.35), Color(0.15, 0.08, 0.05), 0.2)
	var body := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(1.76, 0.36, 0.78)
	body.mesh = body_box
	body.material_override = body_mat
	body.position = Vector3(0, 0.18, 0)
	_ghost.add_child(body)

	var lid_mat := _ghost_mat(Color(0.40, 0.28, 0.16, 0.35), Color(0.20, 0.12, 0.06), 0.2)
	var lid := MeshInstance3D.new()
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(1.84, 0.06, 0.84)
	lid.mesh = lid_box
	lid.material_override = lid_mat
	lid.position = Vector3(0, 0.40, 0)
	_ghost.add_child(lid)

func _build_ghost_furnace() -> void:
	var body_mat := _ghost_mat(Color(0.25, 0.22, 0.20, 0.35), Color(0.12, 0.10, 0.08), 0.2)
	var body := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(1.60, 0.65, 0.80)
	body.mesh = body_box
	body.material_override = body_mat
	body.position = Vector3(0, 0.325, 0)
	_ghost.add_child(body)

func _build_ghost_crafting_table() -> void:
	var body_mat := _ghost_mat(Color(0.35, 0.22, 0.12, 0.35), Color(0.15, 0.08, 0.05), 0.2)
	var body := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(1.80, 0.05, 0.85)
	body.mesh = body_box
	body.material_override = body_mat
	body.position = Vector3(0, 0.625, 0)
	_ghost.add_child(body)

	var leg_mat := _ghost_mat(Color(0.30, 0.18, 0.10, 0.35), Color(0.12, 0.06, 0.03), 0.2)
	for x in [-0.84, 0.84]:
		for z in [-0.38, 0.38]:
			var leg := MeshInstance3D.new()
			var leg_box := BoxMesh.new()
			leg_box.size = Vector3(0.04, 0.60, 0.04)
			leg.mesh = leg_box
			leg.material_override = leg_mat
			leg.position = Vector3(x, 0.30, z)
			_ghost.add_child(leg)

func _ghost_mat(albedo: Color, emissive: Color, emit_power: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emissive
	m.emission_energy_multiplier = emit_power
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func update_placement() -> void:
	if _pending_placement:
		return
	if not _placing or _ghost == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var dir: Vector3 = cam.project_ray_normal(mouse_pos)
	var space_state: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	if space_state == null:
		return
	var params := PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = from + dir * 300.0
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var result: Dictionary = {}
	var skips := 3
	while skips > 0:
		result = space_state.intersect_ray(params)
		if result.is_empty():
			break
		if result.collider is StaticBody3D:
			break
		params.from = result.position + dir * 0.1
		skips -= 1
	if result.is_empty():
		if _item_id == "fishing_boat":
			# Ngắm ra mặt nước: chiếu ray xuống mặt nước mặc định (y = 0.5)
			_ghost_pos = _ray_to_water_plane(from, dir)
			_ghost_pos.y = 0.5
			_ghost.global_position = _ghost_pos
			_ghost_valid = _can_place_boat_pos(_ghost_pos)
			_ghost.visible = _ghost_valid
		else:
			_ghost.visible = false
			_ghost_valid = false
		return
	var hit_pos: Vector3 = result.position
	var normal: Vector3 = result.normal
	var snapped: Vector3 = _snap_to_surface(hit_pos, normal)
	if _item_id == "fishing_boat":
		# Thuyền luôn đặt trên mặt nước mặc định (nổi lên nếu ao cao hơn)
		snapped.y = 0.5
		_ghost_pos = snapped
		_ghost.global_position = _ghost_pos
		_ghost_valid = _can_place_boat_pos(_ghost_pos)
		_ghost.visible = _ghost_valid
		return
	var y_offset: float = 0.0
	if _item_id == "twilight_gate":
		y_offset = VOXEL
	elif _Data.ITEM_TO_BLOCK.has(_item_id):
		y_offset = 0.0
	_ghost_pos = snapped + Vector3(0, y_offset, 0)
	_ghost.global_position = _ghost_pos
	_ghost.visible = true
	_ghost_valid = true
	if _is_seed_item(_item_id):
		_ghost_valid = _can_plant_seed(_item_id, _ghost_pos)

## Giao điểm ray với mặt nước mặc định (y = 0.5) khi không trúng vật nào.
func _ray_to_water_plane(from: Vector3, dir: Vector3) -> Vector3:
	if absf(dir.y) < 0.0001:
		return from
	var t := (0.5 - from.y) / dir.y
	if t < 0.0:
		t = 0.0
	return from + dir * t

## Đặt thuyền hợp lệ khi có nước ở gần (khối nước mực 0.25 trong ô 3×3).
func _can_place_boat_pos(pos: Vector3) -> bool:
	var world_mgr := _find_world_manager()
	if world_mgr == null or not world_mgr.has_method("get_block"):
		return true
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var blk: int = world_mgr.get_block(pos.x + dx, 0.25, pos.z + dz)
			if _Data.is_water(blk):
				return true
	return false

func _snap_to_surface(hit_pos: Vector3, normal: Vector3) -> Vector3:
	var sx: float = round(hit_pos.x / VOXEL) * VOXEL
	var sz: float = round(hit_pos.z / VOXEL) * VOXEL
	var sy: float
	if normal.y > 0.5:
		sy = floor((hit_pos.y - 0.0001) / VOXEL) * VOXEL + VOXEL
	elif normal.y < -0.5:
		sy = ceil((hit_pos.y + 0.0001) / VOXEL) * VOXEL - VOXEL
	else:
		sy = hit_pos.y
	return Vector3(sx, sy, sz)

func confirm_placement() -> bool:
	if not _placing or not _ghost_valid or _item_id.is_empty():
		return false
	if _player_inv == null:
		return false
	var count: int = _player_inv.get_item_count(_item_id)
	if count <= 0:
		return false
	_pending_placement = true
	_pending_item = _item_id
	_pending_pos = _ghost_pos
	_player_inv.remove_item_by_id(_item_id, 1)
	_remove_ghost()
	_placing = false
	_item_id = ""
	_start_throw()
	return true

func _start_throw() -> void:
	if _player == null:
		_do_placement(_pending_item, _pending_pos)
		return
	var start_pos := _player.global_position + Vector3(0, 0.6, 0)
	var target := _pending_pos + Vector3(0, 0.25, 0)
	var dist := start_pos.distance_to(target)
	_throw_duration = 0.8
	_throw_arc_height = clampf(dist * 0.55, 2.0, 10.0)
	_throw_start = start_pos
	_throw_target = target
	_throw_progress = 0.0

	var parent := get_tree().current_scene
	if parent == null:
		_do_placement(_pending_item, _pending_pos)
		return
	_throw_mesh = _make_throw_mesh(_pending_item)
	parent.add_child(_throw_mesh)
	_throw_mesh.global_position = start_pos
	set_process(true)

func _make_throw_mesh(item_id: String) -> Node3D:
	var root := Node3D.new()
	if item_id == "twilight_gate":
		ItemMesh.build(root, item_id)
	elif item_id == "fishing_boat":
		ItemMesh.build(root, item_id)
	elif item_id == "tractor":
		ItemMesh.build(root, item_id)
	elif item_id == "rescue_helicopter":
		ItemMesh.build(root, item_id)
	elif item_id == "chest":
		ItemMesh.build(root, item_id)
	elif item_id == "crafting_table":
		ItemMesh.build(root, item_id)
	elif item_id == "furnace":
		ItemMesh.build(root, item_id)
	elif _Data.ITEM_TO_BLOCK.has(item_id):
		var pivot := Node3D.new()
		pivot.scale = Vector3(4.0, 4.0, 4.0)
		root.add_child(pivot)
		ItemMesh.build(pivot, item_id)
	else:
		var pivot := Node3D.new()
		pivot.scale = Vector3(4.0, 4.0, 4.0)
		root.add_child(pivot)
		ItemMesh.build(pivot, item_id)
	_enable_no_depth(root)
	_disable_shadow(root)
	return root

func _enable_no_depth(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = null
		if node.material_override != null:
			mat = node.material_override.duplicate()
		elif node.mesh and node.mesh.material != null:
			mat = node.mesh.material.duplicate()
		if mat is BaseMaterial3D:
			mat.no_depth_test = true
			node.material_override = mat
	for c in node.get_children():
		_enable_no_depth(c)

func _disable_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_disable_shadow(c)

func _process(delta: float) -> void:
	if not _pending_placement or _throw_mesh == null:
		set_process(false)
		return
	_throw_progress += delta / _throw_duration
	if _throw_progress >= 1.0:
		_throw_mesh.global_position = _throw_target
		_finish_throw()
		return
	var t := _throw_progress
	var mid := (_throw_start + _throw_target) * 0.5 + Vector3(0, _throw_arc_height, 0)
	var q0 := _throw_start.lerp(mid, t)
	var q1 := mid.lerp(_throw_target, t)
	_throw_mesh.global_position = q0.lerp(q1, t)
	_throw_mesh.rotation.x += delta * 6.0
	_throw_mesh.rotation.z += delta * 4.0

func _finish_throw() -> void:
	if _throw_mesh != null and is_instance_valid(_throw_mesh):
		_throw_mesh.queue_free()
	_throw_mesh = null
	_pending_placement = false
	_do_placement(_pending_item, _pending_pos)

func _do_placement(item_id: String, pos: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		_placing = false
		_item_id = ""
		_pending_placement = false
		get_tree().root.set_meta("building_placement_active", false)
		return
	if item_id == "twilight_gate":
		if not _can_place_portal_pos(pos):
			var item_def := ItemDatabase.items_db.get(item_id) as ItemDef
			if item_def:
				_player_inv.add_item(item_def, 1)
			_placing = false
			_item_id = ""
			get_tree().root.set_meta("building_placement_active", false)
			return
		var portal := PortalGate.new()
		portal.name = "PortalGate"
		parent.add_child(portal)
		portal.global_position = pos
		SFXManager.play_block_place()
	elif item_id == "fishing_boat":
		if not _can_place_boat_pos(pos):
			var item_def := ItemDatabase.items_db.get(item_id) as ItemDef
			if item_def and _player_inv:
				_player_inv.add_item(item_def, 1)
			_placing = false
			_item_id = ""
			get_tree().root.set_meta("building_placement_active", false)
			return
		var boat_obj = _FishingBoat.new()
		boat_obj.name = "FishingBoat"
		parent.add_child(boat_obj)
		boat_obj.global_position = pos
		boat_obj.rotation.y = _placement_rotation
		SFXManager.play_block_place()
	elif item_id == "tractor":
		var tractor_obj = _Tractor.new()
		tractor_obj.name = "Tractor"
		parent.add_child(tractor_obj)
		tractor_obj.global_position = pos
		tractor_obj.rotation.y = _placement_rotation
		SFXManager.play_block_place()
	elif item_id == "rescue_helicopter":
		var heli_obj = _RescueHelicopter.new()
		heli_obj.name = "RescueHelicopter"
		parent.add_child(heli_obj)
		heli_obj.global_position = pos
		heli_obj.rotation.y = _placement_rotation
		SFXManager.play_block_place()
	elif item_id == "chest":
		var chest_obj := Chest.new()
		chest_obj.name = "Chest"
		parent.add_child(chest_obj)
		chest_obj.global_position = pos
		chest_obj.rotation.y = _placement_rotation
		SFXManager.play_block_place()
	elif item_id == "crafting_table":
		var table_obj := CraftingTable.new()
		table_obj.name = "CraftingTable"
		parent.add_child(table_obj)
		table_obj.global_position = pos
		table_obj.rotation.y = _placement_rotation
		SFXManager.play_block_place()
	elif item_id == "furnace":
		var furnace_obj = _FurnaceScript.new()
		furnace_obj.name = "Furnace"
		parent.add_child(furnace_obj)
		furnace_obj.global_position = pos
		furnace_obj.rotation.y = _placement_rotation
		SFXManager.play_block_place()
	elif _is_seed_item(item_id):
		_plant_seed(item_id, pos)
	elif _Data.ITEM_TO_BLOCK.has(item_id):
		var block_id: int = _Data.ITEM_TO_BLOCK.get(item_id, 0)
		if block_id != 0:
			var world_mgr: Node = _find_world_manager()
			if world_mgr and world_mgr.has_method("place_block"):
				world_mgr.place_block(pos.x, pos.y, pos.z, block_id)
				SFXManager.play_block_place()
	set_process(false)
	if _player_inv and _player_inv.get_item_count(item_id) > 0:
		_item_id = item_id
		_placing = true
		_make_ghost()
		get_tree().root.set_meta("building_placement_active", true)
	else:
		_placing = false
		_item_id = ""
		get_tree().root.set_meta("building_placement_active", false)

func _can_place_portal_pos(pos: Vector3) -> bool:
	var world_mgr := _find_world_manager()
	if world_mgr == null or not world_mgr.has_method("get_block"):
		return true
	for x in range(9):
		for z in range(7):
			for y in range(8):
				var wx: float = pos.x - 2.0 + x * VOXEL + VOXEL * 0.5
				var wz: float = pos.z - 1.5 + z * VOXEL + VOXEL * 0.5
				var wy: float = pos.y - VOXEL * 0.5 + y * VOXEL + VOXEL * 0.5
				var blk: int = world_mgr.get_block(wx, wy, wz)
				if blk != 0:
					return false
	return true

func cancel_placement() -> void:
	_pending_placement = false
	if _throw_mesh != null and is_instance_valid(_throw_mesh):
		_throw_mesh.queue_free()
	_throw_mesh = null
	_placing = false
	_item_id = ""
	get_tree().root.set_meta("building_placement_active", false)
	_remove_ghost()

func _find_world_manager() -> Node:
	var p := get_parent()
	while p:
		if p.has_node("WorldManager"):
			return p.get_node("WorldManager")
		p = p.get_parent()
	return null

func serialize() -> Array:
	return []

func deserialize(_data: Array) -> void:
	pass

func _remove_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false
