extends Node
class_name PlacementSystem

const _Dim = preload("res://scripts/world/dimension_defs.gd")

const VOXEL: float = 0.50
const TILE_W: int = 5
const TILE_D: int = 5

var _buildings: Array[Dictionary] = []
var _inventory: Dictionary = {}

var _placing: bool = false
var _placing_idx: int = -1
var _ghost: Node3D = null
var _ghost_valid: bool = false
var _ghost_pos: Vector3 = Vector3.ZERO

func _init() -> void:
	_buildings.append({ "key": "twilight_portal", "type": "unique", "placed": false, "name_key": "PORTAL_TWILIGHT_NAME", "desc_key": "PORTAL_TWILIGHT_DESC", "dest_dim": _Dim.DimensionID.TWILIGHT })
	_buildings.append({ "key": "real_world_portal", "type": "unique", "placed": false, "name_key": "PORTAL_REAL_NAME", "desc_key": "PORTAL_REAL_DESC", "dest_dim": _Dim.DimensionID.REAL_WORLD })

	_buildings.append({ "key": "floor_grass", "type": "tile", "tile_type": DecorativeTile.TileType.GRASS, "name_key": "TILE_GRASS_NAME", "desc_key": "TILE_GRASS_DESC" })
	_buildings.append({ "key": "floor_dark_grass", "type": "tile", "tile_type": DecorativeTile.TileType.DARK_GRASS, "name_key": "TILE_DARK_GRASS_NAME", "desc_key": "TILE_DARK_GRASS_DESC" })
	_buildings.append({ "key": "floor_flower", "type": "tile", "tile_type": DecorativeTile.TileType.FLOWER, "name_key": "TILE_FLOWER_NAME", "desc_key": "TILE_FLOWER_DESC" })
	_buildings.append({ "key": "floor_mushroom", "type": "tile", "tile_type": DecorativeTile.TileType.MUSHROOM, "name_key": "TILE_MUSHROOM_NAME", "desc_key": "TILE_MUSHROOM_DESC" })
	_buildings.append({ "key": "floor_green", "type": "tile", "tile_type": DecorativeTile.TileType.GREEN, "name_key": "TILE_GREEN_NAME", "desc_key": "TILE_GREEN_DESC" })

	for b in _buildings:
		if b.type == "tile":
			_inventory[b.key] = 10

func _exit_tree() -> void:
	if get_tree() != null and get_tree().root.has_meta("building_placement_active"):
		get_tree().root.set_meta("building_placement_active", false)

func get_buildings() -> Array[Dictionary]:
	return _buildings

func get_inventory() -> Dictionary:
	return _inventory

func is_placing() -> bool:
	return _placing

func get_ghost_position() -> Vector3:
	return _ghost_pos

func start_placement(idx: int) -> void:
	if idx < 0 or idx >= _buildings.size():
		return
	var data: Dictionary = _buildings[idx]
	if data.type == "unique" and data.placed:
		return
	if data.type == "tile":
		var count: int = _inventory.get(data.key, 0)
		if count <= 0:
			return
	_placing = true
	_placing_idx = idx
	get_tree().root.set_meta("building_placement_active", true)
	_make_ghost()

func _make_ghost() -> void:
	_ghost = Node3D.new()
	_ghost.visible = false
	add_child(_ghost)
	var data: Dictionary = _buildings[_placing_idx]
	if data.type == "unique":
		_build_ghost_portal()
	else:
		_build_ghost_tile()

func _build_ghost_portal() -> void:
	var base_mat: StandardMaterial3D = _ghost_mat(Color(0.1, 0.3, 0.3, 0.30), Color(0.08, 0.2, 0.2), 0.3)
	var off: Vector3 = Vector3(-(9 - 1) * VOXEL * 0.5, -VOXEL * 0.5, -(7 - 1) * VOXEL * 0.5)
	for x in range(9):
		for z in range(7):
			var mi: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(VOXEL, VOXEL, VOXEL)
			mi.mesh = box
			mi.material_override = base_mat
			mi.position = off + Vector3(x * VOXEL, 0.0, z * VOXEL)
			_ghost.add_child(mi)

	var ox: float = -(5 - 1) * VOXEL * 0.5
	var oz: float = 0.0
	var frame_mat: StandardMaterial3D = _ghost_mat(Color(0.15, 0.45, 0.40, 0.40), Color(0.10, 0.35, 0.30), 0.8)
	for x in range(5):
		for p in [Vector3(ox + x * VOXEL, 0.0, oz), Vector3(ox + x * VOXEL, (8 - 1) * VOXEL, oz)]:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(VOXEL, VOXEL, VOXEL)
			mi.mesh = box
			mi.material_override = frame_mat
			mi.position = p
			_ghost.add_child(mi)
	for y in range(1, 7):
		for p in [Vector3(ox, y * VOXEL, oz), Vector3(ox + 4 * VOXEL, y * VOXEL, oz)]:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(VOXEL, VOXEL, VOXEL)
			mi.mesh = box
			mi.material_override = frame_mat
			mi.position = p
			_ghost.add_child(mi)
	for side in [0, 4]:
		for v in range(2):
			var x_off: float = ox + side * VOXEL
			for seg in range(3):
				var y_pos: float = (4 + v * 2) * VOXEL - seg * VOXEL * 0.5
				var vine_mat: StandardMaterial3D = _ghost_mat(Color(0.10, 0.25, 0.20, 0.25), Color(0.06, 0.18, 0.12), 0.0)
				var mi: MeshInstance3D = MeshInstance3D.new()
				var box: BoxMesh = BoxMesh.new()
				box.size = Vector3(VOXEL * 0.15, VOXEL * 0.25, VOXEL * 0.15)
				mi.mesh = box
				mi.material_override = vine_mat
				mi.position = Vector3(x_off + (randf() - 0.5) * VOXEL * 0.2, y_pos, oz + (randf() - 0.5) * VOXEL * 0.3)
				_ghost.add_child(mi)
	var flower_mat: StandardMaterial3D = _ghost_mat(Color(0.2, 0.6, 0.5, 0.30), Color(0.15, 0.5, 0.4), 1.5)
	for side in [-1, 1]:
		for f in range(2):
			var y_pos: float = (2 + f * 3) * VOXEL
			var x_off: float = ox + 4 * VOXEL * 0.5 - side * VOXEL * 0.2
			var mi: MeshInstance3D = MeshInstance3D.new()
			var sph: SphereMesh = SphereMesh.new()
			sph.radius = VOXEL * 0.12
			sph.height = VOXEL * 0.24
			mi.mesh = sph
			mi.material_override = flower_mat
			mi.position = Vector3(x_off + side * VOXEL * 0.4, y_pos, oz + (randf() - 0.5) * VOXEL * 0.6)
			_ghost.add_child(mi)

func _build_ghost_tile() -> void:
	var tile_mat: StandardMaterial3D = _ghost_mat(Color(0.10, 0.35, 0.25, 0.35), Color(0.08, 0.28, 0.20), 0.5)
	var off: Vector3 = Vector3(-(TILE_W - 1) * VOXEL * 0.5, -VOXEL * 0.5, -(TILE_D - 1) * VOXEL * 0.5)
	for x in range(TILE_W):
		for z in range(TILE_D):
			var mi: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(VOXEL, VOXEL, VOXEL)
			mi.mesh = box
			mi.material_override = tile_mat
			mi.position = off + Vector3(x * VOXEL, 0.0, z * VOXEL)
			_ghost.add_child(mi)

func _ghost_mat(albedo: Color, emissive: Color, emit_power: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
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
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(from, dir)
	if typeof(hit) == TYPE_VECTOR3:
		var hit_pos: Vector3 = hit
		var snapped: Vector3 = _snap_to_grid(hit_pos)
		_ghost_pos = snapped + Vector3(0, 0.25, 0)
		_ghost.global_position = _ghost_pos
		_ghost.visible = true
		_ghost_valid = true
	else:
		_ghost.visible = false
		_ghost_valid = false

func _snap_to_grid(pos: Vector3) -> Vector3:
	var data: Dictionary = _buildings[_placing_idx]
	var half: float
	if data.type == "unique":
		half = 0.0
	else:
		half = TILE_W * VOXEL * 0.5
	var sx: float = round((pos.x - half) / VOXEL) * VOXEL + half
	var sz: float = round((pos.z - half) / VOXEL) * VOXEL + half
	return Vector3(sx, 0.0, sz)

func confirm_placement() -> bool:
	if not _placing or not _ghost_valid or _placing_idx < 0:
		return false
	var data: Dictionary = _buildings[_placing_idx]
	if data.type == "unique" and data.placed:
		return false
	if data.type == "tile":
		var count: int = _inventory.get(data.key, 0)
		if count <= 0:
			return false
		_inventory[data.key] = count - 1
	else:
		data["placed"] = true

	_remove_ghost()

	if data.type == "unique":
		var portal: PortalGate = PortalGate.new()
		portal.name = "PortalGate"
		portal.dest_dimension = data.get("dest_dim", _Dim.DimensionID.TWILIGHT)
		var parent := get_parent()
		if parent == null:
			_placing = false
			_placing_idx = -1
			get_tree().root.set_meta("building_placement_active", false)
			return false
		parent.add_child(portal)
		portal.global_position = _ghost_pos + Vector3(0, 0.25, 0)
		SFXManager.play_block_place()
	else:
		var tile: DecorativeTile = DecorativeTile.new()
		tile.tile_type = data.tile_type
		tile.name = "DecorativeTile"
		var parent := get_parent()
		if parent == null:
			_placing = false
			_placing_idx = -1
			get_tree().root.set_meta("building_placement_active", false)
			return false
		parent.add_child(tile)
		tile.global_position = _ghost_pos + Vector3(0, 0.25, 0)
		SFXManager.play_block_place()

	_placing = false
	_placing_idx = -1
	get_tree().root.set_meta("building_placement_active", false)
	return true

func cancel_placement() -> void:
	_placing = false
	_placing_idx = -1
	get_tree().root.set_meta("building_placement_active", false)
	_remove_ghost()

func serialize() -> Array:
	var out: Array = []
	for b in _buildings:
		var entry: Dictionary = {"key": b.key, "type": b.type, "placed": b.get("placed", false)}
		if b.has("tile_type"):
			entry["tile_type"] = b.tile_type
		if b.has("dest_dim"):
			entry["dest_dim"] = b.dest_dim
		out.append(entry)
	return out

func deserialize(data: Array) -> void:
	for entry in data:
		var key: String = entry.get("key", "")
		for b in _buildings:
			if b.key == key:
				b["placed"] = entry.get("placed", false)
				break

func _remove_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
