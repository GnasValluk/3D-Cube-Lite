extends RefCounted

const _Data = preload("chunk_data.gd")

static var _noise_cache: Dictionary = {}

## Gọi để buộc tạo lại noise (vd: khi WorldSeed thay đổi)
static func clear_cache() -> void:
	_noise_cache.clear()

static func _noise_for_dim(dim_id: int) -> Dictionary:
	if _noise_cache.has(dim_id):
		return _noise_cache[dim_id]

	var base_seed: int = SeedSnapshot.ensure() + dim_id * 1000
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

	## n_lake: hồ nội địa — tần số vừa, patch to hơn trước (λ ≈ 167 ô) để hồ
	## đồng bằng rộng hơn; ngưỡng quyết định mật độ nằm ở world_chunk.
	var n_lake := FastNoiseLite.new()
	n_lake.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_lake.seed = base_seed + 5555
	n_lake.frequency = 0.006

	## n_lake_type: xác định hồ bùn hay hồ cát — tần số thấp hơn để patch lớn hơn
	var n_lake_type := FastNoiseLite.new()
	n_lake_type.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_lake_type.seed = base_seed + 8888
	n_lake_type.frequency = 0.008

	## n_ocean: mask lục địa vs biển — tần số thấp, nhiều lục địa cỡ
	## ~800-1600 block xen kẽ bồn biển (λ ≈ 1670 block). Đi biển ~1.5-3k block
	## là gặp đất liền mới (trước đây λ 4000 → một bồn biển dài >5000 block).
	var n_ocean := FastNoiseLite.new()
	n_ocean.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_ocean.seed = base_seed + 77777
	n_ocean.frequency = 0.0006
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
	n_ocean_warp.frequency = 0.0006
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

	## n_highland: MASK vùng đồng bằng cao — tần số CAO HƠN n_bio (0.012) để
	## patch cao nguyên NHỎ HƠN đồng bằng (yêu cầu thiết kế). Vẫn dùng làm nền
	## độ cao cho cả cao nguyên lẫn cao nguyên sa mạc.
	var n_highland := FastNoiseLite.new()
	n_highland.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_highland.seed = base_seed + 77770
	n_highland.frequency = 0.018
	n_highland.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_highland.fractal_octaves = 3
	n_highland.fractal_lacunarity = 2.0
	n_highland.fractal_gain = 0.5

	## n_highland_terr: địa hình gồ ghề bên trong cao nguyên (đồi/gò/lòng chảo)
	var n_highland_terr := FastNoiseLite.new()
	n_highland_terr.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_highland_terr.seed = base_seed + 77771
	n_highland_terr.frequency = 0.02
	n_highland_terr.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_highland_terr.fractal_octaves = 3
	n_highland_terr.fractal_lacunarity = 2.0
	n_highland_terr.fractal_gain = 0.5

	## n_patch_var: biến thể block dạng CỤM (sa mạc: cồn cát/đất khô; đồng
	## bằng: đám đất trống/bãi cỏ rậm) — tần số vừa cho cụm rải rác có logic.
	var n_patch_var := FastNoiseLite.new()
	n_patch_var.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_patch_var.seed = base_seed + 77773
	n_patch_var.frequency = 0.03
	n_patch_var.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_patch_var.fractal_octaves = 2
	n_patch_var.fractal_lacunarity = 2.0
	n_patch_var.fractal_gain = 0.5

	## n_patch2: đốm NHỎ tần số cao hơn patch_var — rải cỏ già (đồng bằng),
	## cỏ thưa và cát phai (sa mạc) dạng điểm loang, không cắt thành mảng to.
	var n_patch2 := FastNoiseLite.new()
	n_patch2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_patch2.seed = base_seed + 77774
	n_patch2.frequency = 0.07
	n_patch2.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_patch2.fractal_octaves = 2
	n_patch2.fractal_lacunarity = 2.0
	n_patch2.fractal_gain = 0.5

	## n_patch_stone: BÃI ĐÁ rải rác — đốm đá lộ thiên ở vùng đất phẳng thấp,
	## đất bùn ven sông/đầm. Tần số thấp hơn patch_var để cụm đá rộng hơn.
	var n_patch_stone := FastNoiseLite.new()
	n_patch_stone.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_patch_stone.seed = base_seed + 77776
	n_patch_stone.frequency = 0.02
	n_patch_stone.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_patch_stone.fractal_octaves = 2
	n_patch_stone.fractal_lacunarity = 2.0
	n_patch_stone.fractal_gain = 0.5

	## n_patch_dirt: BÃI ĐẤT rộng ở đồng bằng — tần số RẤT thấp → vùng đất
	## đất thổ lớn (hàng chục ô), bên trong trộn nhiều loại đất theo patch_var.
	## Thay đốm dirt nhỏ tần cao (patch2 0.07) nhìn "kích thước quá bé".
	var n_patch_dirt := FastNoiseLite.new()
	n_patch_dirt.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_patch_dirt.seed = base_seed + 77777
	n_patch_dirt.frequency = 0.012
	n_patch_dirt.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_patch_dirt.fractal_octaves = 3
	n_patch_dirt.fractal_lacunarity = 2.0
	n_patch_dirt.fractal_gain = 0.4

	## n_mountain: MASK vùng NÚI vừa (núi đôi / dải núi) — tần số RẤT thấp → cụm
	## núi rộng, đắp cao 4..9 block so với đồi thường, tạo ranh núi mềm.
	var n_mountain := FastNoiseLite.new()
	n_mountain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_mountain.seed = base_seed + 77778
	n_mountain.frequency = 0.004
	n_mountain.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_mountain.fractal_octaves = 3
	n_mountain.fractal_lacunarity = 2.0
	n_mountain.fractal_gain = 0.5

	## n_basin: địa hình VÙNG TRŨNG — lòng chảo hạ thấp cục bộ trong đất liền
	## (dùng chung công thức địa hình, chỉ can thiệp cao độ trước khi biome vẽ).
	var n_basin := FastNoiseLite.new()
	n_basin.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_basin.seed = base_seed + 77775
	n_basin.frequency = 0.004
	n_basin.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_basin.fractal_octaves = 3
	n_basin.fractal_lacunarity = 2.0
	n_basin.fractal_gain = 0.5

	## n_mangrove: MASK rừng ngập mặn — vệt dọc bờ biển, tần số thấp để cụm
	## ven biển rộng; ngưỡng quyết định nằm ở world_chunk (kết hợp ocean mask).
	var n_mangrove := FastNoiseLite.new()
	n_mangrove.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_mangrove.seed = base_seed + 78001
	n_mangrove.frequency = 0.004
	n_mangrove.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_mangrove.fractal_octaves = 3
	n_mangrove.fractal_lacunarity = 2.0
	n_mangrove.fractal_gain = 0.5

	## n_mangrove_inner: mật độ bên trong rừng — đốm loang để bờ triều không
	## phải một dải bùn trơn; kết hợp "khoảng cách tới biển" tạo vùng lõi rừng.
	var n_mangrove_inner := FastNoiseLite.new()
	n_mangrove_inner.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_mangrove_inner.seed = base_seed + 78002
	n_mangrove_inner.frequency = 0.03
	n_mangrove_inner.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_mangrove_inner.fractal_octaves = 2
	n_mangrove_inner.fractal_lacunarity = 2.0
	n_mangrove_inner.fractal_gain = 0.5

	## n_mangrove_terr: độ gồ ghề đáy bùn bên trong rừng — mô đất thấp nhấp nhô
	## giữa các lạch nước, cho địa hình "bán ngập" sinh động.
	var n_mangrove_terr := FastNoiseLite.new()
	n_mangrove_terr.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_mangrove_terr.seed = base_seed + 78003
	n_mangrove_terr.frequency = 0.04
	n_mangrove_terr.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_mangrove_terr.fractal_octaves = 3
	n_mangrove_terr.fractal_lacunarity = 2.0
	n_mangrove_terr.fractal_gain = 0.5

	var result := { "biome": n_bio, "warp": n_warp, "lake": n_lake,
		"lake_type": n_lake_type, "ocean": n_ocean,
		"sea_rough": n_sea_rough, "sea_large": n_sea_large, "sea_biome": n_sea_biome,
		"ocean_warp": n_ocean_warp, "sea_mountain": n_sea_mountain,
		"reef": n_reef, "desert": n_desert,
		"highland": n_highland, "highland_terr": n_highland_terr,
		"patch_var": n_patch_var,
		"patch2": n_patch2,
		"patch_stone": n_patch_stone, "patch_dirt": n_patch_dirt,
		"basin": n_basin, "mountain": n_mountain,
		"mangrove": n_mangrove, "mangrove_inner": n_mangrove_inner,
		"mangrove_terr": n_mangrove_terr }
	_noise_cache[dim_id] = result
	return result

static func _biome_at(wx: float, wz: float, dim_id: int) -> int:
	var nd: Dictionary = _noise_for_dim(dim_id)

	# REAL_WORLD: chỉ desert noise quyết định — phần còn lại luôn GRASS_DIRT.
	# Bỏ warp×2 + biome noise (3/4 số noise call) vốn không ảnh hưởng kết quả.
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		var d: float = (nd["desert"].get_noise_2d(wx, wz) + 1.0) * 0.5
		if d > 0.55:
			return _Data.TileType.DESERT
		return _Data.TileType.GRASS_DIRT

	var n_bio: FastNoiseLite = nd["biome"]
	var n_warp: FastNoiseLite = nd["warp"]

	var wx_off: float = n_warp.get_noise_2d(wx, wz + 100.0) * 18.0
	var wz_off: float = n_warp.get_noise_2d(wx + 100.0, wz) * 18.0
	var n: float = (n_bio.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5

	# Bias vùng spawn (gốc tọa độ): nâng cao biome noise → người chơi luôn xuất
	# hiện trên đất cao khô ráo (khớp với bias ocean mask trong world_chunk).
	var d2: float = wx * wx + wz * wz
	if d2 < 2000000.0:
		n += 0.8 * exp(-d2 / 500000.0)

	var threshold: float = 0.50
	if n < threshold: return _Data.TileType.TWILIGHT_GRASS
	return _Data.TileType.TWILIGHT_DIRT
