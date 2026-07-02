## fish/fish_spawner.gd
## Spawn cá nước ngọt tại các vùng nước trong REAL_WORLD.
## - Vùng có phù sa (SILT): spawn nhiều, đa dạng loài
## - Vùng không có phù sa (SAND): spawn ít đến vừa
## Đặt node này trong cùng scene với WorldManager.

extends Node3D
class_name FishSpawner

const _FishChar = preload("res://scripts/characters/fish/fish_character.gd")
const _Dim      = preload("res://scripts/world/dimension_defs.gd")

# Số cá tối đa toàn scene
@export var max_fish: int = 40
# Bán kính xung quanh player để thử spawn
@export var spawn_check_radius: float = 48.0
# Khoảng cách tối thiểu giữa các cá
@export var min_fish_spacing: float = 3.5
# Interval kiểm tra spawn (giây)
@export var check_interval: float = 4.0

var _world_mgr: OpenWorldManager = null
var _fish_list: Array[FishCharacter] = []
var _timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Noise để phân biệt vùng SILT vs SAND (phải khớp với world_chunk logic)
var _noise: FastNoiseLite = null

func _ready() -> void:
	_rng.randomize()
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = WorldSeed.seed_value + 1000 + 5555   # khớp n_lake của REAL_WORLD
	_noise.frequency = 0.018

	await get_tree().process_frame
	await get_tree().process_frame
	_world_mgr = _find_world_manager()

func _process(delta: float) -> void:
	if _world_mgr == null:
		_world_mgr = _find_world_manager()
		return

	# Dọn cá đã chết hoặc bị xoá
	_fish_list = _fish_list.filter(func(f): return is_instance_valid(f) and f.is_alive)

	_timer += delta
	if _timer < check_interval:
		return
	_timer = 0.0

	if _fish_list.size() >= max_fish:
		return

	_try_spawn_batch()

func _try_spawn_batch() -> void:
	# Tìm player để spawn quanh đó
	var player := _find_player()
	if player == null:
		return

	var px: float = player.global_position.x
	var pz: float = player.global_position.z

	# Thử vài vị trí ngẫu nhiên mỗi tick
	var attempts: int = 12
	for _i in range(attempts):
		if _fish_list.size() >= max_fish:
			break

		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(12.0, spawn_check_radius)
		var wx: float = px + cos(angle) * radius
		var wz: float = pz + sin(angle) * radius
		# Bơi ở độ cao nước
		var wy: float = 0.15

		# Kiểm tra có phải vùng nước không
		if not _world_mgr.is_in_water(wx, wz, wy):
			continue

		# Kiểm tra khoảng cách với cá khác
		var too_close := false
		for existing in _fish_list:
			if existing.global_position.distance_to(Vector3(wx, wy, wz)) < min_fish_spacing:
				too_close = true
				break
		if too_close:
			continue

		# Tính loại hồ — khớp với world_chunk n_lake logic (seed+5555, freq 0.018)
		var lake_val: float = (_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
		var has_silt: bool = lake_val > 0.50

		_spawn_fish(wx, wy, wz, has_silt)

func _spawn_fish(wx: float, wy: float, wz: float, has_silt: bool) -> void:
	var fish := CharacterBody3D.new() as CharacterBody3D
	fish.set_script(_FishChar)

	# Vùng phù sa: đa dạng loài — chép, rô, trắm, mòng, vàng, linh
	# Vùng không phù sa: chủ yếu loài nhỏ — mòng, linh
	var variant: int
	if has_silt:
		# Phân bố đa dạng — có trọng số nhẹ về loài lớn hơn
		var r := _rng.randf()
		if r < 0.22:   variant = FishCharacter.FishVariant.CHEP   # 22%
		elif r < 0.40: variant = FishCharacter.FishVariant.RO     # 18%
		elif r < 0.55: variant = FishCharacter.FishVariant.TRAM   # 15%
		elif r < 0.70: variant = FishCharacter.FishVariant.MONG   # 15%
		elif r < 0.85: variant = FishCharacter.FishVariant.VANG   # 15%
		else:          variant = FishCharacter.FishVariant.LINH   # 15%
	else:
		# Vùng nghèo: chủ yếu cá nhỏ
		var r := _rng.randf()
		if r < 0.15:   variant = FishCharacter.FishVariant.CHEP   # 15%
		elif r < 0.35: variant = FishCharacter.FishVariant.RO     # 20%
		elif r < 0.50: variant = FishCharacter.FishVariant.MONG   # 15%
		elif r < 0.75: variant = FishCharacter.FishVariant.VANG   # 25%
		else:          variant = FishCharacter.FishVariant.LINH   # 25%

	fish.set("fish_variant", variant)
	fish.set("fish_scale", _rng.randf_range(0.85, 1.15))
	fish.name = "Fish_%d" % _fish_list.size()
	fish.set("_is_player", false)

	add_child(fish)
	fish.global_position = Vector3(wx, wy, wz)
	# Xoay ngẫu nhiên
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
