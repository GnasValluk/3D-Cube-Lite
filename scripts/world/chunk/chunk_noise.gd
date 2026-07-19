extends RefCounted

const _Data = preload("chunk_data.gd")

static var _noise_cache: Dictionary = {}

## Gọi để buộc tạo lại noise (vd: khi WorldSeed thay đổi)
static func clear_cache() -> void:
	_noise_cache.clear()

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
	n_lake.frequency = 0.025

	## n_lake_type: xác định hồ bùn hay hồ cát — tần số thấp hơn để patch lớn hơn
	var n_lake_type := FastNoiseLite.new()
	n_lake_type.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_lake_type.seed = base_seed + 8888
	n_lake_type.frequency = 0.020

	## n_continent: noise tần số rất thấp xác định lục địa vs biển
	## Chỉ dùng cho REAL_WORLD — Twilight không có biển
	var n_continent := FastNoiseLite.new()
	n_continent.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_continent.seed = base_seed + 31337
	n_continent.frequency = 0.00038  # giữ lại để biomes tham chiếu không bị lỗi
	n_continent.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_continent.fractal_octaves = 5
	n_continent.fractal_lacunarity = 2.0
	n_continent.fractal_gain = 0.45

	## n_ocean: noise tần số thấp ~10x n_lake → patch biển to ~10x hồ
	var n_ocean := FastNoiseLite.new()
	n_ocean.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_ocean.seed = base_seed + 77777
	n_ocean.frequency = 0.00025
	n_ocean.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_ocean.fractal_octaves = 4
	n_ocean.fractal_lacunarity = 2.0
	n_ocean.fractal_gain = 0.5

	## n_sea_rough: địa hình đáy biển gồ ghề — tần số cao hơn để có đồi/lõm nhỏ
	var n_sea_rough := FastNoiseLite.new()
	n_sea_rough.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_sea_rough.seed = base_seed + 12345
	n_sea_rough.frequency = 0.06
	n_sea_rough.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_sea_rough.fractal_octaves = 3
	n_sea_rough.fractal_lacunarity = 2.0
	n_sea_rough.fractal_gain = 0.5

	## n_sea_large: cấu trúc lớn đáy biển (bồn trũng, sống núi) — tần số cực thấp
	var n_sea_large := FastNoiseLite.new()
	n_sea_large.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_sea_large.seed = base_seed + 23456
	n_sea_large.frequency = 0.004
	n_sea_large.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_sea_large.fractal_octaves = 3
	n_sea_large.fractal_lacunarity = 2.0
	n_sea_large.fractal_gain = 0.4

	## n_sea_biome: phân bố block đáy biển (cát/đá/sỏi/bùn)
	var n_sea_biome := FastNoiseLite.new()
	n_sea_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_sea_biome.seed = base_seed + 34567
	n_sea_biome.frequency = 0.012
	n_sea_biome.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_sea_biome.fractal_octaves = 2
	n_sea_biome.fractal_lacunarity = 2.0
	n_sea_biome.fractal_gain = 0.5

	## n_ocean_warp: domain warping cho ocean mask → bờ biển lồi lõm bất quy tắc
	var n_ocean_warp := FastNoiseLite.new()
	n_ocean_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_ocean_warp.seed = base_seed + 45678
	n_ocean_warp.frequency = 0.0008
	n_ocean_warp.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_ocean_warp.fractal_octaves = 2
	n_ocean_warp.fractal_lacunarity = 2.0
	n_ocean_warp.fractal_gain = 0.5

	## n_sea_mountain: núi ngầm dưới đáy biển
	var n_sea_mountain := FastNoiseLite.new()
	n_sea_mountain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_sea_mountain.seed = base_seed + 56789
	n_sea_mountain.frequency = 0.005
	n_sea_mountain.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_sea_mountain.fractal_octaves = 4
	n_sea_mountain.fractal_lacunarity = 2.0
	n_sea_mountain.fractal_gain = 0.5

	## n_reef: phân bố bãi đá ngầm — tần số trung bình, cụm nhỏ
	var n_reef := FastNoiseLite.new()
	n_reef.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_reef.seed = base_seed + 88111
	n_reef.frequency = 0.025
	n_reef.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_reef.fractal_octaves = 2
	n_reef.fractal_lacunarity = 2.0
	n_reef.fractal_gain = 0.5

	# ── n_desert: sa mạc cấp lục địa — tần số cực thấp (ngang ocean) ─────────
	var n_desert := FastNoiseLite.new()
	n_desert.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_desert.seed = base_seed + 99999
	n_desert.frequency = 0.0003
	n_desert.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_desert.fractal_octaves = 3
	n_desert.fractal_lacunarity = 2.0
	n_desert.fractal_gain = 0.5

	var result := { "biome": n_bio, "warp": n_warp, "lake": n_lake,
		"lake_type": n_lake_type, "continent": n_continent, "ocean": n_ocean,
		"sea_rough": n_sea_rough, "sea_large": n_sea_large, "sea_biome": n_sea_biome,
		"ocean_warp": n_ocean_warp, "sea_mountain": n_sea_mountain,
		"reef": n_reef, "desert": n_desert }
	_noise_cache[dim_id] = result
	return result

static func _biome_at(wx: float, wz: float, dim_id: int) -> int:
	var nd: Dictionary = _noise_for_dim(dim_id)
	var n_bio: FastNoiseLite = nd["biome"]
	var n_warp: FastNoiseLite = nd["warp"]

	var wx_off: float = n_warp.get_noise_2d(wx, wz + 100.0) * 18.0
	var wz_off: float = n_warp.get_noise_2d(wx + 100.0, wz) * 18.0
	var n: float = (n_bio.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5

	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		var d: float = (nd["desert"].get_noise_2d(wx, wz) + 1.0) * 0.5
		if d > 0.55:
			return _Data.TileType.DESERT

	var threshold: float = 0.50
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		threshold = 0.40

	if n < threshold: return _Data.TileType.GRASS
	return _Data.TileType.DARK_GRASS
