## slime/slime_spawner.gd
## Spawn slime xanh lá quanh player — bầy nhỏ (2-4 con, đa kích cỡ),
## respawn sau khi chết, despawn khi xa.

extends Node3D
class_name SlimeSpawner

const _SlimeChar = preload("res://scripts/characters/slime/slime_character.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

class SlimePack:
	var home: Vector3
	var radius: float = 8.0
	var target_size: int
	var slimes: Array[SlimeCharacter] = []
	var respawn_queue: Array[float] = []

	func alive_count() -> int:
		var c := 0
		for s in slimes:
			if is_instance_valid(s) and s.is_alive:
				c += 1
		return c

	func cleanup() -> void:
		slimes = slimes.filter(func(s): return is_instance_valid(s) and s.is_alive)

	func needs_respawn() -> int:
		cleanup()
		var alive := slimes.size()
		var total_slots := target_size
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
		respawn_queue.append(300.0 + randf_range(0.0, 180.0))

	func full() -> bool:
		cleanup()
		return slimes.size() >= target_size

@export var max_packs: int = 4
@export var pack_spacing: float = 35.0
@export var pack_radius_min: float = 6.0
@export var pack_radius_max: float = 10.0
@export var pack_target_min: int = 2
@export var pack_target_max: int = 4
@export var pack_spawn_radius: float = 45.0
@export var despawn_distance: float = 90.0
@export var check_interval: float = 6.0
@export var scan_attempts: int = 10

var _world_mgr: Node = null
var _player: Node3D = null
var _packs: Array[SlimePack] = []
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

	for pack in _packs:
		var before := pack.slimes.size()
		pack.cleanup()
		if pack.slimes.size() < before:
			pack.mark_dead()

	_packs = _packs.filter(func(p: SlimePack):
		var dist_sq := p.home.distance_squared_to(player_pos)
		if dist_sq > despawn_sq:
			for s in p.slimes:
				if is_instance_valid(s):
					s.queue_free()
			return false
		return true
	)

	# Slime chỉ spawn từ chiều tối (17h) tới sáng sớm (6h) — ngoài giờ không spawn
	if not _is_night_window():
		return

	_try_generate_packs(player_pos)

	for pack in _packs:
		var slots := pack.needs_respawn()
		for _i in range(slots):
			var spawn_pos: Variant = _pick_spawn_in_pack(pack)
			if spawn_pos != null:
				_spawn_slime(spawn_pos, pack)

func _try_generate_packs(player_pos: Vector3) -> void:
	if _packs.size() >= max_packs:
		return
	var px := player_pos.x
	var pz := player_pos.z

	for _i in range(scan_attempts):
		if _packs.size() >= max_packs:
			break

		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(18.0, pack_spawn_radius)
		var wx: float = px + cos(angle) * radius
		var wz: float = pz + sin(angle) * radius

		var ground_y := _get_ground_y(wx, wz)
		if ground_y < -5.0:
			continue
		var home_pos := Vector3(wx, ground_y, wz)
		if _is_in_water(home_pos):
			continue

		var too_close := false
		for p in _packs:
			if p.home.distance_squared_to(home_pos) < pack_spacing * pack_spacing:
				too_close = true
				break
		if too_close:
			continue
		if not _is_valid_terrain(home_pos):
			continue
		if not _is_rice_grass_zone(home_pos):
			continue

		var pack := SlimePack.new()
		pack.home = home_pos
		pack.radius = _rng.randf_range(pack_radius_min, pack_radius_max)
		pack.target_size = _rng.randi_range(pack_target_min, pack_target_max)
		_packs.append(pack)

		var spawn_count := _rng.randi_range(pack_target_min, pack.target_size)
		for _j in range(spawn_count):
			var spawn_pos: Variant = _pick_spawn_in_pack(pack)
			if spawn_pos != null:
				_spawn_slime(spawn_pos, pack)

func _pick_spawn_in_pack(pack: SlimePack) -> Variant:
	for _i in range(8):
		var angle := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(1.5, pack.radius * 0.7)
		var wx := pack.home.x + cos(angle) * dist
		var wz := pack.home.z + sin(angle) * dist
		var ground_y := _get_ground_y(wx, wz)
		if ground_y < -5.0:
			continue
		var pos := Vector3(wx, ground_y, wz)
		if _is_in_water(pos):
			continue
		return pos
	return null

func _spawn_slime(pos: Vector3, pack: SlimePack) -> void:
	var slime := CharacterBody3D.new()
	slime.set_script(_SlimeChar)
	var size_roll := _rng.randf()
	var size: int = SlimeCharacter.SlimeSize.MEDIUM
	if size_roll < 0.30:
		size = SlimeCharacter.SlimeSize.SMALL
	elif size_roll < 0.70:
		size = SlimeCharacter.SlimeSize.MEDIUM
	else:
		size = SlimeCharacter.SlimeSize.LARGE
	slime.set("slime_size", size)
	slime.set("bio_bonus_lv", WorldChunk.roll_bio_bonus_at(pos.x, pos.z)["bonus"])
	slime.name = "Slime_%d_%d" % [_packs.find(pack), pack.slimes.size()]
	slime.set("_is_player", false)
	add_child(slime)
	slime.global_position = pos
	slime.rotation.y = _rng.randf_range(0.0, TAU)
	if slime is SlimeCharacter:
		var sc := slime as SlimeCharacter
		sc.set("_home", pack.home)
		pack.slimes.append(sc)

func _is_valid_terrain(pos: Vector3) -> bool:
	if _world_mgr == null or not _world_mgr.has_method("get_block"):
		return false
	var below: int = _world_mgr.get_block(pos.x, pos.y - 0.2, pos.z)
	var above: int = _world_mgr.get_block(pos.x, pos.y + 0.5, pos.z)
	return below != 0 and above == 0

# ── Giờ spawn: chiều tối → sáng sớm ──────────────────────────────────────────
const NIGHT_START_HOUR: float = 17.0  # chiều tối
const NIGHT_END_HOUR: float = 6.0     # sáng sớm

func _is_night_window() -> bool:
	var h: float = TimeSystem.get_hour()
	return h >= NIGHT_START_HOUR or h < NIGHT_END_HOUR

func _is_water_block(b: int) -> bool:
	return b == _Data.BlockID.WATER or b == _Data.BlockID.WATER_SOURCE \
		or (b >= _Data.BlockID.WATER_LEVEL_7 and b <= _Data.BlockID.WATER_LEVEL_1)

## Slime spawn gần bụi cỏ lúa: đất cỏ vùng trũng và có nước trong bán kính ~3 ô
## (cỏ lúa mọc sát nước — khớp chunk_grass near_water wdist <= 3). Đất lầy
## (DARK_GRASS/MUDDY_SAND) mặc định là ruộng lúa.
func _is_rice_grass_zone(pos: Vector3) -> bool:
	if _world_mgr == null or not _world_mgr.has_method("get_block"):
		return false
	var below: int = _world_mgr.get_block(pos.x, pos.y - 0.2, pos.z)
	if below == _Data.BlockID.DARK_GRASS or below == _Data.BlockID.MUDDY_SAND:
		return true
	if not _Data.is_grass_tile(below):
		return false
	const R: int = 3
	for ox in range(-R, R + 1):
		for oz in range(-R, R + 1):
			if ox == 0 and oz == 0:
				continue
			if _is_water_block(_world_mgr.get_block(pos.x + ox, pos.y - 0.2, pos.z + oz)):
				return true
	return false

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
