## plains_monster_spawner.gd
## Spawn bầy quái đồng bằng quanh player về đêm (17h–6h). Mỗi pack chọn
## ngẫu nhiên một loài: Bóng Đêm (bắn tia tối từ xa). Chỉ spawn trên đất
## đồng bằng GRASS_DIRT — không trong sa mạc/hồ tuyết/đầm lầy/biển.
## Despawn khi xa player, respawn sau khi bị tiêu diệt.

extends Node3D
class_name PlainsMonsterSpawner

const _Wraith = preload("res://scripts/characters/wraith/wraith_character.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

enum MonsterType { WRAITH }

## Type được chọn theo tỷ lệ (tổng = 1.0)
const TYPE_CHANCES: Array[float] = [1.0]

class MonsterPack:
	var home: Vector3
	var radius: float = 8.0
	var target_size: int
	var mtype: int
	var monsters: Array = []
	var respawn_queue: Array[float] = []

	func alive_count() -> int:
		var c := 0
		for m in monsters:
			if is_instance_valid(m) and m.is_alive:
				c += 1
		return c

	func cleanup() -> void:
		monsters = monsters.filter(func(m): return is_instance_valid(m) and m.is_alive)

	func needs_respawn() -> int:
		cleanup()
		var alive := monsters.size()
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
		respawn_queue.append(420.0 + randf_range(0.0, 180.0))

	func full() -> bool:
		cleanup()
		return monsters.size() >= target_size

@export var max_packs: int = 5
@export var pack_spacing: float = 40.0
@export var pack_radius_min: float = 7.0
@export var pack_radius_max: float = 11.0
@export var pack_target_min: int = 2
@export var pack_target_max: int = 4
@export var pack_spawn_radius: float = 50.0
@export var despawn_distance: float = 95.0
@export var check_interval: float = 6.0
@export var scan_attempts: int = 14

var _world_mgr: Node = null
var _player: Node3D = null
var _packs: Array[MonsterPack] = []
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
		var before := pack.monsters.size()
		pack.cleanup()
		if pack.monsters.size() < before:
			pack.mark_dead()

	_packs = _packs.filter(func(p: MonsterPack):
		var dist_sq := p.home.distance_squared_to(player_pos)
		if dist_sq > despawn_sq:
			for m in p.monsters:
				if is_instance_valid(m):
					m.queue_free()
			return false
		return true
	)

	# Quái đồng bằng chỉ xuất hiện từ chiều tối (17h) tới sáng sớm (6h)
	if not _is_night_window():
		return

	_try_generate_packs(player_pos)

	for pack in _packs:
		var slots := pack.needs_respawn()
		for _i in range(slots):
			var spawn_pos: Variant = _pick_spawn_in_pack(pack)
			if spawn_pos != null:
				_spawn_monster(spawn_pos, pack)

func _try_generate_packs(player_pos: Vector3) -> void:
	if _packs.size() >= max_packs:
		return
	var px := player_pos.x
	var pz := player_pos.z

	for _i in range(scan_attempts):
		if _packs.size() >= max_packs:
			break

		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(20.0, pack_spawn_radius)
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
		if not _is_plains_zone(home_pos):
			continue

		var pack := MonsterPack.new()
		pack.home = home_pos
		pack.radius = _rng.randf_range(pack_radius_min, pack_radius_max)
		pack.target_size = _rng.randi_range(pack_target_min, pack_target_max)
		pack.mtype = _roll_type()
		_packs.append(pack)

		var spawn_count := _rng.randi_range(pack_target_min, pack.target_size)
		for _j in range(spawn_count):
			var spawn_pos: Variant = _pick_spawn_in_pack(pack)
			if spawn_pos != null:
				_spawn_monster(spawn_pos, pack)

func _roll_type() -> int:
	return MonsterType.WRAITH

func _pick_spawn_in_pack(pack: MonsterPack) -> Variant:
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
		if not _is_plains_zone(pos):
			continue
		return pos
	return null

func _spawn_monster(pos: Vector3, pack: MonsterPack) -> void:
	var mob := CharacterBody3D.new()
	mob.set_script(_Wraith)
	mob.set("bio_bonus_lv", WorldChunk.roll_bio_bonus_at(pos.x, pos.z)["bonus"])
	mob.name = "PlainsMonster_%d_%d" % [_packs.find(pack), pack.monsters.size()]
	mob.set("_is_player", false)
	add_child(mob)
	mob.global_position = pos
	mob.rotation.y = _rng.randf_range(0.0, TAU)
	mob.set("_home", pack.home)
	pack.monsters.append(mob)

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

## Đồng bằng = biome GRASS_DIRT (REAL_WORLD) — nguồn sự thật cùng địa hình.
## Loại trừ sa mạc DESERT, băng giá FROST, đầm lầy SWAMP, đồng cỏ vùng cao...
## Thêm điều kiện nền là cỏ để không spawn lên tảng đá/bãi trống.
func _is_plains_zone(pos: Vector3) -> bool:
	if _world_mgr == null or not _world_mgr.has_method("get_block"):
		return false
	const DIM: int = _Data._Dim.DimensionID.REAL_WORLD
	if WorldChunk.biome_at(pos.x, pos.z, DIM) != _Data.TileType.GRASS_DIRT:
		return false
	var below: int = _world_mgr.get_block(pos.x, pos.y - 0.2, pos.z)
	return below == _Data.BlockID.GRASS_DIRT or below == _Data.BlockID.GRASS \
		or below == _Data.BlockID.DARK_GRASS or below == _Data.BlockID.YOUNG_GRASS

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

## Flag hỗ trợ unit test — không dùng trong game
var unit_test_home_flag: bool = false
func _reset_for_test() -> void:
	_packs.clear()
	_timer = check_interval
func _pack_count() -> int:
	return _packs.size()
func _alive_total() -> int:
	var t := 0
	for p in _packs:
		t += p.alive_count()
	return t