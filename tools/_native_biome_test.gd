extends Node

## Native S1 biome sampling compare: WorldBiome vs chunk_noise.gd reference.
## Chạy qua tools/_native_biome_test.tscn (cần autoload WorldSeed + SeedSnapshot).

const _Noise = preload("res://scripts/world/chunk/chunk_noise.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

const REAL: int = _Data._Dim.DimensionID.REAL_WORLD
const TW: int = _Data._Dim.DimensionID.TWILIGHT

var _fail := 0
var _wb: Object = null
var _seed := 0

func _ready() -> void:
	print("== NATIVE S1 BIOME COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	if not ClassDB.class_exists("WorldBiome"):
		print("FAIL: WorldBiome class not loaded")
		get_tree().quit(1)
		return
	_wb = ClassDB.instantiate("WorldBiome")
	if _wb == null:
		print("FAIL: instantiate WorldBiome null")
		get_tree().quit(1)
		return
	_seed = SeedSnapshot.ensure()

	var ok := true
	for dim_id in [REAL, TW]:
		print("── dim_id=", dim_id, " seed=", _seed)
		if not _compare_single(dim_id):
			ok = false
		if not _compare_grid(dim_id):
			ok = false
	print(_summary())
	get_tree().quit(0 if _fail == 0 else 1)

func _compare_single(dim_id: int) -> bool:
	## Lưới điểm xung quanh (0,0) + vài điểm xa (~1200-1600 để chạm
	## desert/frost/swamp threshold của REAL_WORLD).
	var pts: Array[Vector2] = []
	for i in 70:
		for j in 70:
			pts.append(Vector2(float(i) - 35.0 + 0.5, float(j) - 35.0 + 0.5))
	var far: Array[Vector2] = [
		Vector2(1200.5, 1300.5), Vector2(-1400.5, 900.5),
		Vector2(1500.5, -1100.5), Vector2(-1600.5, -1600.5),
		Vector2(900.5, 900.5), Vector2(-900.5, -900.5),
	]
	pts.append_array(far)
	var bad := 0
	for p in pts:
		var gd: int = _Noise._biome_at_uncached(p.x, p.y, dim_id)
		var nat: int = _wb.biome_at_uncached(p.x, p.y, dim_id, _seed)
		if gd != nat:
			bad += 1
			if bad <= 8:
				print("  MISMATCH single (%.1f,%.1f) gd=%d nat=%d" % [p.x, p.y, gd, nat])
	_check("single-cell %d pts (dim %d)" % [pts.size(), dim_id], bad == 0)
	return bad == 0

func _compare_grid(dim_id: int) -> bool:
	## compute_biome_grid so với GDScript lặp từng ô.
	var cols := 32
	var total := cols + 2 * _Data.PAD
	for cxz in [[0, 0], [5, -3], [-12, 4]]:
		var world_ox: float = cxz[0] * 32.0
		var world_oz: float = cxz[1] * 32.0
		var half: float = 16.0
		var nat: PackedInt32Array = _wb.compute_biome_grid(
			world_ox, world_oz, cols, total, dim_id, _seed)
		if nat.size() != total * total:
			_check("grid size (chunk %s dim %d)" % [str(cxz), dim_id], false)
			return false
		var bad := 0
		for vx in range(total):
			for vz in range(total):
				var wx: float = world_ox - half + (float(vx - _Data.PAD) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(vz - _Data.PAD) + 0.5) * _Data.VOXEL
				var gd: int = _Noise._biome_at_uncached(wx, wz, dim_id)
				var g: int = nat[vx * total + vz]
				if gd != g:
					bad += 1
					if bad <= 8:
						print("  MISMATCH grid (chunk %s) cell(%d,%d) wx=%.2f wz=%.2f gd=%d nat=%d"
								% [str(cxz), vx, vz, wx, wz, gd, g])
		_check("grid %d cells (chunk %s dim %d)" % [total * total, str(cxz), dim_id], bad == 0)
	return true

func _check(name: String, ok: bool) -> void:
	if ok:
		print("  PASS: ", name)
	else:
		_fail += 1
		print("  FAIL: ", name)

func _summary() -> String:
	return "-- SUMMARY: %d failures" % _fail