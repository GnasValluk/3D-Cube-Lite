extends Node

## Native S3 ocean mask grid compare: WorldOcean.ocean_grid vs GDScript
## `_ocean_mask_at` stride-2 + odd fill (mirror compute_chunk). Bit-exact.
## Chạy qua tools/_native_ocean_test.tscn (cần autoload WorldSeed + SeedSnapshot).

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

const OCEAN_PAD: int = 26

var _fail := 0
var _wo: Object = null
var _seed := 0
var _nd: Dictionary = {}

func _ready() -> void:
	print("== NATIVE S3 OCEAN MASK COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	if not ClassDB.class_exists("WorldOcean"):
		print("FAIL: WorldOcean class not loaded")
		get_tree().quit(1)
		return
	_wo = ClassDB.instantiate("WorldOcean")
	if _wo == null:
		print("FAIL: instantiate WorldOcean null")
		get_tree().quit(1)
		return
	_seed = SeedSnapshot.ensure()
	_nd = load("res://scripts/world/chunk/chunk_noise.gd")._noise_for_dim(_Data._Dim.DimensionID.REAL_WORLD)

	var ok := true
	for cxz in [[0, 0], [1, 0], [5, -3], [-302, -230], [-3, 7], [12, -4], [40, 40]]:
		if not _compare_chunk(cxz[0], cxz[1]):
			ok = false
	print(_summary())
	get_tree().quit(0 if _fail == 0 else 1)

func _compare_chunk(cx: int, cz: int) -> bool:
	var cols := 32
	var half: float = cols * 0.5
	var oct_total: int = cols + 2 * OCEAN_PAD
	var world_ox: float = cx * cols
	var world_oz: float = cz * cols

	# GDScript reference: stride-2 + odd fill (giống compute_chunk).
	var gd := PackedByteArray()
	gd.resize(oct_total * oct_total)
	gd.fill(0)
	for pvx in range(0, oct_total, 2):
		for pvz in range(0, oct_total, 2):
			var wx: float = world_ox - half + (float(pvx - OCEAN_PAD) + 0.5)
			var wz: float = world_oz - half + (float(pvz - OCEAN_PAD) + 0.5)
			gd[pvx * oct_total + pvz] = 1 if _ocean_mask_gd(wx, wz) else 0
	for pvx in range(0, oct_total, 2):
		for pvz in range(0, oct_total, 2):
			var val: int = gd[pvx * oct_total + pvz]
			if pvx + 1 < oct_total: gd[(pvx + 1) * oct_total + pvz] = val
			if pvz + 1 < oct_total: gd[pvx * oct_total + pvz + 1] = val
			if pvx + 1 < oct_total and pvz + 1 < oct_total:
				gd[(pvx + 1) * oct_total + pvz + 1] = val

	var nat: PackedByteArray = _wo.ocean_grid(world_ox - half, world_oz - half, oct_total, _seed)
	if nat.size() != oct_total * oct_total:
		_check("grid size chunk(%d,%d)" % [cx, cz], false)
		return false
	var bad := 0
	for i in range(gd.size()):
		if gd[i] != nat[i]:
			bad += 1
			if bad <= 8:
				var pvx: int = i / oct_total
				var pvz: int = i % oct_total
				print("  MISMATCH cell(%d,%d) idx=%d gd=%d nat=%d" % [pvx, pvz, i, gd[i], nat[i]])
	_check("ocean grid %dx%d chunk(%d,%d)" % [oct_total, oct_total, cx, cz], bad == 0)
	return bad == 0

## Mirror world_chunk.gd `_ocean_mask_compute` qua `_ocean_mask_at` (dùng cache
## như game — cache chỉ memoization nên giá trị chuẩn).
func _ocean_mask_gd(wx: float, wz: float) -> bool:
	return load("res://scripts/world/chunk/world_chunk.gd")._ocean_mask_at(_nd, wx, wz)

func _check(name: String, ok: bool) -> void:
	if ok:
		print("  PASS: ", name)
	else:
		_fail += 1
		print("  FAIL: ", name)

func _summary() -> String:
	return "-- SUMMARY: %d failures" % _fail