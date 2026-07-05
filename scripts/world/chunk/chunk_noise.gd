extends RefCounted

const _Data = preload("chunk_data.gd")

static var _noise_cache: Dictionary = {}

static func _noise_for_dim(dim_id: int) -> Dictionary:
	if _noise_cache.has(dim_id):
		return _noise_cache[dim_id]

	var base_seed: int = WorldSeed.seed_value + dim_id * 1000
	var freq_bio: float = 0.008
	var freq_warp: float = 0.022

	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		freq_bio = 0.012

	var n_bio := FastNoiseLite.new()
	n_bio.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_bio.seed = base_seed
	n_bio.frequency = freq_bio

	var n_warp := FastNoiseLite.new()
	n_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_warp.seed = base_seed + 99
	n_warp.frequency = freq_warp

	var n_lake := FastNoiseLite.new()
	n_lake.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_lake.seed = base_seed + 5555
	n_lake.frequency = 0.018

	## n_lake_type: xác định hồ bùn hay hồ cát — tần số thấp hơn để patch lớn hơn
	var n_lake_type := FastNoiseLite.new()
	n_lake_type.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_lake_type.seed = base_seed + 8888
	n_lake_type.frequency = 0.008

	## n_continent: noise tần số rất thấp xác định lục địa vs biển
	## Chỉ dùng cho REAL_WORLD — Twilight không có biển
	var n_continent := FastNoiseLite.new()
	n_continent.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_continent.seed = base_seed + 31337
	n_continent.frequency = _Data.CONTINENT_FREQ
	# FractalOctaves cao hơn để tạo đường bờ biển tự nhiên, không phẳng
	n_continent.fractal_octaves = 4
	n_continent.fractal_lacunarity = 2.2
	n_continent.fractal_gain = 0.5

	var result := { "biome": n_bio, "warp": n_warp, "lake": n_lake,
		"lake_type": n_lake_type, "continent": n_continent }
	_noise_cache[dim_id] = result
	return result

static func _biome_at(wx: float, wz: float, dim_id: int) -> int:
	var nd: Dictionary = _noise_for_dim(dim_id)
	var n_bio: FastNoiseLite = nd["biome"]
	var n_warp: FastNoiseLite = nd["warp"]

	var wx_off: float = n_warp.get_noise_2d(wx, wz + 100.0) * 18.0
	var wz_off: float = n_warp.get_noise_2d(wx + 100.0, wz) * 18.0
	var n: float = (n_bio.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5

	var threshold: float = 0.50
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		threshold = 0.40

	if n < threshold: return _Data.TileType.GRASS
	return _Data.TileType.DARK_GRASS
