extends Node

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const SIZE := 32
const REAL: int = _D._Dim.DimensionID.REAL_WORLD
const TW: int = _D._Dim.DimensionID.TWILIGHT

var _stage: int = 0

func _ready() -> void:
	_W.prewarm_async()
	_stage = 1

func _process(_delta: float) -> void:
	if _stage == 1:
		if _W._networks_ready:
			_stage = 2
	elif _stage == 2:
		_stage = 3
		_time("FULL_REAL (0,0)", REAL)
		_time("FULL_TW   (0,0)", TW)
		_time("FAST_REAL (0,0)", REAL, true)
		_time("FAST_TW   (0,0)", TW, true)
		_time("FULL_REAL (1,0)", REAL)
		_time("FULL_REAL (0,1)", REAL)
		print("DONE")
		await WorldChunk.wait_for_tasks_async(get_tree())
		get_tree().quit(0)

func _time(name: String, dim: int, fast: bool = false) -> void:
	var t0 := Time.get_ticks_msec()
	_W.compute_chunk(0, 0, SIZE, dim, fast)
	print("%s=%dms" % [name, Time.get_ticks_msec() - t0])
