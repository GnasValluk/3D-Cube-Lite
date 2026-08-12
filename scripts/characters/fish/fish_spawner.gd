extends Node3D
class_name FishSpawner

const _FishChar = preload("res://scripts/characters/fish/fish_character.gd")
const _Dim      = preload("res://scripts/world/dimension_defs.gd")
const _Data     = preload("res://scripts/world/chunk/chunk_data.gd")

@export var max_fish: int = 60
@export var spawn_check_radius: float = 48.0
@export var despawn_distance: float = 80.0
@export var min_fish_spacing: float = 3.5
@export var check_interval: float = 6.0
@export var spawn_attempts: int = 16

var _world_mgr: OpenWorldManager = null
var _player: Node3D = null
var _fish_list: Array[FishCharacter] = []
var _timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _noise: FastNoiseLite = null

var _n_oc: FastNoiseLite = null
var _ow: FastNoiseLite = null
var _has_ocean: bool = false
var _ocean_ok: bool = false

func _ready() -> void:
	_rng.randomize()
	_timer = _rng.randf_range(0.0, check_interval)

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = WorldSeed.seed_value + 1000 + 5555
	_noise.frequency = 0.025

	await get_tree().process_frame
	await get_tree().process_frame
	_world_mgr = _find_world_manager()
	if _world_mgr:
		var nd: Dictionary = WorldChunk._noise_for_dim(1)
		_has_ocean = nd.has("ocean") and nd.has("ocean_warp")
		if _has_ocean:
			_n_oc = nd.get("ocean") as FastNoiseLite
			_ow = nd.get("ocean_warp") as FastNoiseLite
			_ocean_ok = true

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

	_fish_list = _fish_list.filter(func(f): return is_instance_valid(f) and f.is_alive)

	var any_despawned := false
	var i := _fish_list.size() - 1
	while i >= 0:
		var f := _fish_list[i]
		if f.global_position.distance_squared_to(player_pos) > despawn_sq:
			f.queue_free()
			_fish_list.remove_at(i)
			any_despawned = true
		i -= 1

	if _fish_list.size() >= max_fish:
		return

	_try_spawn_batch(player_pos)

func _try_spawn_batch(player_pos: Vector3) -> void:
	var px := player_pos.x
	var pz := player_pos.z

	for _i in range(spawn_attempts):
		if _fish_list.size() >= max_fish:
			break

		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(12.0, spawn_check_radius)
		var wx: float = px + cos(angle) * radius
		var wz: float = pz + sin(angle) * radius
		var wy: float = 0.15

		if not _world_mgr.is_in_water(wx, wz, wy):
			continue

		if _ocean_ok:
			var warp_x: float = _ow.get_noise_2d(wx * 0.5, wz * 0.5) * 200.0
			var warp_z: float = _ow.get_noise_2d(wx * 0.5 + 100.0, wz * 0.5 + 100.0) * 200.0
			var ov: float = (_n_oc.get_noise_2d(wx + warp_x, wz + warp_z) + 1.0) * 0.5
			if ov > _Data.OCEAN_THRESHOLD:
				continue

		var too_close := false
		var spawn_pos := Vector3(wx, wy, wz)
		for existing in _fish_list:
			if existing.global_position.distance_squared_to(spawn_pos) < min_fish_spacing * min_fish_spacing:
				too_close = true
				break
		if too_close:
			continue

		var lake_val: float = (_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
		var has_silt: bool = lake_val > 0.58

		_spawn_fish(wx, wy, wz, has_silt)

func _spawn_fish(wx: float, wy: float, wz: float, has_silt: bool) -> void:
	var fish := CharacterBody3D.new() as CharacterBody3D
	fish.set_script(_FishChar)

	var variant: int
	if has_silt:
		var r := _rng.randf()
		if r < 0.18:   variant = FishCharacter.FishVariant.CARP
		elif r < 0.32: variant = FishCharacter.FishVariant.PERCH
		elif r < 0.46: variant = FishCharacter.FishVariant.TILAPIA
		elif r < 0.63: variant = FishCharacter.FishVariant.SNAKEHEAD
		elif r < 0.85: variant = FishCharacter.FishVariant.SHRIMP
		else:          variant = FishCharacter.FishVariant.FLOWERHORN
	else:
		var r := _rng.randf()
		if r < 0.07:   variant = FishCharacter.FishVariant.CARP
		elif r < 0.20: variant = FishCharacter.FishVariant.PERCH
		elif r < 0.46: variant = FishCharacter.FishVariant.TILAPIA
		elif r < 0.63: variant = FishCharacter.FishVariant.SNAKEHEAD
		elif r < 0.85: variant = FishCharacter.FishVariant.SHRIMP
		else:          variant = FishCharacter.FishVariant.FLOWERHORN

	fish.set("fish_variant", variant)
	fish.set("fish_scale", _rng.randf_range(0.85, 1.15))
	fish.name = "Fish_%d" % _fish_list.size()
	fish.set("_is_player", false)
	fish.set("bio_bonus_lv", WorldChunk.roll_bio_bonus_at(wx, wz)["bonus"])

	add_child(fish)
	fish.global_position = Vector3(wx, wy, wz)
	fish.rotation.y = _rng.randf_range(0.0, TAU)

	if fish is FishCharacter:
		_fish_list.append(fish as FishCharacter)

func _find_world_manager() -> OpenWorldManager:
	var parent := get_parent()
	if parent and parent.has_node("WorldManager"):
		return parent.get_node("WorldManager") as OpenWorldManager
	return null

func _find_player() -> Node3D:
	var parent := get_parent()
	if parent == null:
		return null
	var mgr := parent.get_node_or_null("CharacterManager") as CharacterManager
	if mgr:
		return mgr.get_current_character()
	return null
