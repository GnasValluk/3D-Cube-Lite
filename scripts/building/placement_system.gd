extends Node
class_name PlacementSystem

const VOXEL: float = 0.50

var _placing: bool = false
var _item_id: String = ""
var _ghost: Node3D = null
var _ghost_valid: bool = false
var _ghost_pos: Vector3 = Vector3.ZERO
var _player_inv: Inventory = null

func _exit_tree() -> void:
	if get_tree() != null and get_tree().root.has_meta("building_placement_active"):
		get_tree().root.set_meta("building_placement_active", false)

func set_player_inventory(inv: Inventory) -> void:
	_player_inv = inv

func is_placing() -> bool:
	return _placing

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

func _make_ghost() -> void:
	_ghost = Node3D.new()
	_ghost.visible = false
	add_child(_ghost)

	if _item_id == "twilight_gate":
		_build_ghost_portal()
	elif _item_id == "chest":
		_build_ghost_chest()

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
	params.to = from + dir * 50.0
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var result: Dictionary = space_state.intersect_ray(params)
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
	elif _item_id == "chest":
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
	_player_inv.remove_item_by_id(_item_id, 1)
	_remove_ghost()
	var parent := get_parent()
	if parent == null:
		_placing = false
		_item_id = ""
		get_tree().root.set_meta("building_placement_active", false)
		return false
	if _item_id == "twilight_gate":
		var portal := PortalGate.new()
		portal.name = "PortalGate"
		parent.add_child(portal)
		portal.global_position = _ghost_pos
		SFXManager.play_block_place()
	elif _item_id == "chest":
		var chest_obj := Chest.new()
		chest_obj.name = "Chest"
		parent.add_child(chest_obj)
		chest_obj.global_position = _ghost_pos
		SFXManager.play_block_place()
	_placing = false
	_item_id = ""
	get_tree().root.set_meta("building_placement_active", false)
	return true

func cancel_placement() -> void:
	_placing = false
	_item_id = ""
	get_tree().root.set_meta("building_placement_active", false)
	_remove_ghost()

func serialize() -> Array:
	return []

func deserialize(_data: Array) -> void:
	pass

func _remove_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
