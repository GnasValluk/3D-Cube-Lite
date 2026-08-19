extends Node

## Native S7 fill_blocks compare: WorldFill vs chunk_terrain.gd reference.
## Chạy qua tools/_native_fill_test.tscn (cần autoload WorldSeed + SeedSnapshot).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _Terrain = preload("res://scripts/world/chunk/chunk_terrain.gd")
const _Noise = preload("res://scripts/world/chunk/chunk_noise.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const PRELOAD_RIVER = preload("res://scripts/world/chunk/chunk_river.gd")

const REAL: int = _Data._Dim.DimensionID.REAL_WORLD
const TW: int = _Data._Dim.DimensionID.TWILIGHT
const SIZE := 32

var _fail := 0

func _ready() -> void:
	print("== NATIVE S7 FILL_BLOCKS COMPARE ==")
	WorldSeed.seed_value = 20260804
	seed(20260804)
	PRELOAD_RIVER._ensure_rivers()
	_W.prewarm_async()

func _process(_delta: float) -> void:
	if not _W._networks_ready:
		return
	set_process(false)
	_run()

func _run() -> void:
	var chunks := [[0, 0], [1, 0], [5, -3], [-302, -230], [-3, 7]]
	for c in chunks:
		await _check_chunk(c[0], c[1], REAL, "dim=1 chunk(%d,%d)" % [c[0], c[1]])
	await _check_chunk(0, 0, TW, "dim=0 chunk(0,0)")
	await _check_chunk(-7, 4, TW, "dim=0 chunk(-7,4)")
	_Terrain._force_gd_fallback = false
	print(_summary())
	get_tree().quit(0 if _fail == 0 else 1)

func _compute(cx: int, cz: int, dim_id: int) -> Dictionary:
	_Noise.clear_cache()
	return _W.compute_chunk(cx, cz, SIZE, dim_id)

func _check_chunk(cx: int, cz: int, dim_id: int, name: String) -> void:
	var native_data := _compute(cx, cz, dim_id)   # native path (DLL có)
	_Terrain._force_gd_fallback = true            # ép GDScript fallback
	var gd_data := _compute(cx, cz, dim_id)       # reference
	_Terrain._force_gd_fallback = false
	await _W.wait_for_tasks_async(get_tree())

	if not native_data.has("bd") or not gd_data.has("bd"):
		_check("%s native bd missing" % name, false)
		return
	var a: PackedByteArray = native_data["bd"]._data
	var b: PackedByteArray = gd_data["bd"]._data
	var bad := 0
	for i in range(a.size()):
		if a[i] != b[i]:
			bad += 1
			if bad <= 8:
				var x := i / (69 * SIZE)
				var y := (i / SIZE) % 69
				var z := i % SIZE
				print("  MISMATCH %s cell(%d,%d) ly=%d nat=%d gd=%d" % [name, x, z, y, a[i], b[i]])
	_check("blocks bit-exact %s (%d bytes)" % [name, a.size()], bad == 0)

func _check(name: String, ok: bool) -> void:
	if ok:
		print("  PASS: ", name)
	else:
		_fail += 1
		print("  FAIL: ", name)

func _summary() -> String:
	return "-- SUMMARY: %d failures" % _fail