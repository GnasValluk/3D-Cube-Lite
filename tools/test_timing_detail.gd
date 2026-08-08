extends Node

## Profiler section timing bên trong compute_chunk — bật _prof_enabled rồi chạy
## vài chunk đại diện (REAL land/REAL ocean/TWILIGHT). In ra từng section ms.
## Chạy: res://tools/test_timing_detail.tscn

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _T = preload("res://scripts/world/chunk/chunk_terrain.gd")
const SIZE := 32
const REAL: int = _D._Dim.DimensionID.REAL_WORLD
const TW: int = _D._Dim.DimensionID.TWILIGHT

var _stage: int = 0

func _ready() -> void:
	WorldSeed.seed_value = 20260804
	_W.prewarm_async()
	_stage = 1

func _process(_delta: float) -> void:
	if _stage == 1:
		if _W._networks_ready:
			_stage = 2
	elif _stage == 2:
		_stage = 3
		await _W.wait_for_tasks_async(get_tree())
		_W._prof_enabled = true
		_T._prof = true
		print("== FULL REAL (0,0) ==")
		_W.compute_chunk(0, 0, SIZE, REAL)
		_T._prof = false
		_W._prof_enabled = false
		print("DONE")
		await _W.wait_for_tasks_async(get_tree())
		get_tree().quit(0)
