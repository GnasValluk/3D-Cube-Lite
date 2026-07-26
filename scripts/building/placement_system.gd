extends Node
class_name PlacementSystem

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const VOXEL: float = 0.50

var _placing: bool = false
var _item_id: String = ""
var _ghost: Node3D = null
var _ghost_valid: bool = false
var _ghost_pos: Vector3 = Vector3.ZERO
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
	get_tree().root.set_meta("building_placement_active", true)
	_make_ghost()

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
	elif _item_id == "chest":
		_build_ghost_chest()
	elif _Data.ITEM_TO_BLOCK.has(_item_id):
		_build_ghost_block()

func _build_ghost_block() -> void:
	var block_mat := _ghost_mat(Color(0.80, 0.80, 0.80, 0.30), Color(0.40, 0.40, 0.40), 0.0)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
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

func _build_ghost_chest() -> void:
	var body_mat := _ghost_mat(Color(0.35, 0.22, 0.12, 0.35), Color(0.15, 0.08, 0.05), 0.2)
	var body := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.7, 0.35, 0.6)
	body.mesh = body_box
	body.material_override = body_mat
	body.position = Vector3(0, 0.175, 0)
	_ghost.add_child(body)

	var lid_mat := _ghost_mat(Color(0.40, 0.28, 0.16, 0.35), Color(0.20, 0.12, 0.06), 0.2)
	var lid := MeshInstance3D.new()
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(0.72, 0.06, 0.62)
	lid.mesh = lid_box
	lid.material_override = lid_mat
	lid.position = Vector3(0, 0.38, 0)
	_ghost.add_child(lid)

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
		_ghost.visible = false
		_ghost_valid = false
		return
	var hit_pos: Vector3 = result.position
	var normal: Vector3 = result.normal
	var snapped: Vector3 = _snap_to_surface(hit_pos, normal)
	var y_offset: float = 0.0
	if _item_id == "twilight_gate":
		y_offset = VOXEL
	elif _Data.ITEM_TO_BLOCK.has(_item_id):
		y_offset = 0.0
	_ghost_pos = snapped + Vector3(0, y_offset, 0)
	_ghost.global_position = _ghost_pos
	_ghost.visible = true
	_ghost_valid = true

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
	elif item_id == "chest":
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
	elif item_id == "chest":
		var chest_obj := Chest.new()
		chest_obj.name = "Chest"
		parent.add_child(chest_obj)
		chest_obj.global_position = pos
		SFXManager.play_block_place()
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
