extends Node3D
class_name PigSpawner

const _PigChar = preload("res://scripts/characters/pig/pig_character.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

class PigHerd:
	var home: Vector3
	var radius: float = 14.0
	var target_size: int
	var pigs: Array[PigCharacter] = []
	var respawn_queue: Array[float] = []  # remaining cooldown per dead slot
	var is_sand: bool = false

	func alive_count() -> int:
		var c := 0
		for p in pigs:
			if is_instance_valid(p) and p.is_alive:
				c += 1
		return c

	func cleanup() -> void:
		pigs = pigs.filter(func(p): return is_instance_valid(p) and p.is_alive)

	func needs_respawn() -> int:
		cleanup()
		var alive := pigs.size()
		var total_slots := target_size
		# Count how many slots are ready to respawn
		var open := 0
		var i := 0
		while i < respawn_queue.size() and alive + open < total_slots:
			respawn_queue[i] -= 1.0
			if respawn_queue[i] <= 0.0:
				open += 1
				respawn_queue.remove_at(i)
			else:
				i += 1
		return open

	func mark_dead() -> void:
		respawn_queue.append(480.0 + randf_range(0.0, 240.0))

	func full() -> bool:
		cleanup()
		return pigs.size() >= target_size

@export var max_herds: int = 4
@export var herd_spacing: float = 40.0
@export var herd_radius_min: float = 8.0
@export var herd_radius_max: float = 12.0
@export var herd_target_min: int = 1
@export var herd_target_max: int = 3
@export var herd_spawn_radius: float = 50.0
@export var despawn_distance: float = 80.0
@export var check_interval: float = 8.0
@export var scan_attempts: int = 10

var _world_mgr: Node = null
var _player: Node3D = null
var _herds: Array[PigHerd] = []
var _timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_timer = _rng.randf_range(0.0, check_interval)
	await get_tree().process_frame
	await get_tree().process_frame
	_world_mgr = _find_world_manager()

func _process(delta: float) -> void:
	if _world_mgr == null:
		_world_mgr = _find_world_manager()
		return

	_timer += delta
	if _timer < check_interval:
		return
	_timer -= check_interval

	_player = _find_player()
	if _player == null:
		return

	var player_pos := _player.global_position
	var despawn_sq := despawn_distance * despawn_distance

	# Clean dead pigs and track deaths
	for herd in _herds:
		var before := herd.pigs.size()
		herd.cleanup()
		if herd.pigs.size() < before:
			herd.mark_dead()

	# Despawn herds too far
	_herds = _herds.filter(func(h: PigHerd):
		var dist_sq := h.home.distance_squared_to(player_pos)
		if dist_sq > despawn_sq:
			for p in h.pigs:
				if is_instance_valid(p):
					p.queue_free()
			return false
		return true
	)

	# Generate new herds in unexplored areas
	_try_generate_herds(player_pos)

	# Spawn pigs for each herd
	for herd in _herds:
		var slots := herd.needs_respawn()
		for _i in range(slots):
			var spawn_pos: Variant = _pick_spawn_in_herd(herd)
			if spawn_pos != null:
				_spawn_pig(spawn_pos, herd)

func _try_generate_herds(player_pos: Vector3) -> void:
	if _herds.size() >= max_herds:
		return

	var px := player_pos.x
	var pz := player_pos.z
	var spawned := 0

	for _i in range(scan_attempts):
		if _herds.size() >= max_herds or spawned >= 1:
			break

		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(18.0, herd_spawn_radius)
		var wx: float = px + cos(angle) * radius
		var wz: float = pz + sin(angle) * radius

		var ground_y := _get_ground_y(wx, wz)
		if ground_y < -5.0:
			continue

		var home_pos := Vector3(wx, ground_y, wz)

		if _is_in_water(home_pos):
			continue

		# Check minimum distance from existing herds
		var too_close := false
		for h in _herds:
			if h.home.distance_squared_to(home_pos) < herd_spacing * herd_spacing:
				too_close = true
				break
		if too_close:
			continue

		# Check if terrain supports a herd (not too steep, valid block)
		if not _is_valid_terrain(home_pos):
			continue

		var is_sand := _is_desert_ground(wx, ground_y, wz)
		var herd := PigHerd.new()
		herd.home = home_pos
		herd.radius = _rng.randf_range(herd_radius_min, herd_radius_max)
		herd.target_size = _rng.randi_range(herd_target_min, herd_target_max)
		herd.is_sand = is_sand
		_herds.append(herd)

		# Spawn initial pigs for this herd
		var spawn_count := _rng.randi_range(herd_target_min, herd.target_size)
		for _j in range(spawn_count):
			var spawn_pos: Variant = _pick_spawn_in_herd(herd)
			if spawn_pos != null:
				_spawn_pig(spawn_pos, herd)

func _pick_spawn_in_herd(herd: PigHerd) -> Variant:
	for _i in range(8):
		var angle := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(2.0, herd.radius * 0.7)
		var wx := herd.home.x + cos(angle) * dist
		var wz := herd.home.z + sin(angle) * dist
		var ground_y := _get_ground_y(wx, wz)
		if ground_y < -5.0:
			continue
		var pos := Vector3(wx, ground_y, wz)
		if _is_in_water(pos):
			continue
		return pos
	return null

func _spawn_pig(pos: Vector3, herd: PigHerd) -> void:
	var pig := CharacterBody3D.new()
	pig.set_script(_PigChar)
	pig.set("pig_variant", PigCharacter.Variant.SAND if herd.is_sand else PigCharacter.Variant.NORMAL)
	var is_baby := _rng.randf() < 0.25
	pig.set("is_baby", is_baby)
	pig.set("pig_scale", _rng.randf_range(0.45, 0.55) if is_baby else _rng.randf_range(0.85, 1.15))
	pig.name = "Pig_%d_%d" % [_herds.find(herd), herd.pigs.size()]
	pig.set("_is_player", false)
	add_child(pig)
	pig.global_position = pos
	pig.rotation.y = _rng.randf_range(0.0, TAU)
	if pig is PigCharacter:
		var pc := pig as PigCharacter
		pc.set("_home", herd.home)
		herd.pigs.append(pc)

func _is_valid_terrain(pos: Vector3) -> bool:
	if _world_mgr == null or not _world_mgr.has_method("get_block"):
		return false
	# Check that the block below is solid and block above is air
	var below: int = _world_mgr.get_block(pos.x, pos.y - 0.2, pos.z)
	var above: int = _world_mgr.get_block(pos.x, pos.y + 0.5, pos.z)
	return below != 0 and above == 0

func _get_ground_y(wx: float, wz: float) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return -99.0
	var from := Vector3(wx, 30.0, wz)
	var to := Vector3(wx, -5.0, wz)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit:
		return hit.position.y
	return -99.0

func _is_in_water(pos: Vector3) -> bool:
	if _world_mgr == null:
		return false
	if _world_mgr.has_method("is_in_water"):
		return _world_mgr.is_in_water(pos.x, pos.z, pos.y)
	return false

func _is_desert_ground(wx: float, wy: float, wz: float) -> bool:
	if _world_mgr == null or not _world_mgr.has_method("get_block"):
		return false
	var blk: int = _world_mgr.get_block(wx, wy - 0.1, wz)
	return blk == _Data.BlockID.SAND or blk == _Data.BlockID.SAND_DEEP or blk == _Data.BlockID.OCEAN_SAND

func _find_world_manager():
	var parent := get_parent()
	if parent and parent.has_node("WorldManager"):
		return parent.get_node("WorldManager")
	return null

func _find_player() -> Node3D:
	var parent := get_parent()
	if parent == null:
		return null
	var mgr := parent.get_node_or_null("CharacterManager") as CharacterManager
	if mgr:
		return mgr.get_current_character()
	return null
