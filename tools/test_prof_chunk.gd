extends Node

## Headless breakdown profiler: compute_chunk từng phase (S1..S13) — đo chi phí
## nội tại 1 chunk thật để tìm nút thắt stream. Chạy qua tools/test_prof_chunk.tscn.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const REAL: int = _D._Dim.DimensionID.REAL_WORLD
const SIZE := 32

func _ready() -> void:
	WorldSeed.seed_value = 20260802
	seed(20260802)
	_W.prewarm_async()

func _process(_delta: float) -> void:
	if not _W._networks_ready:
		return
	set_process(false)
	_run()

func _run() -> void:
	var chunks := [[0, 0], [1, 0], [-302, -230]]
	for pair in chunks:
		_W._prof_enabled = true
		var t0 := Time.get_ticks_usec()
		var data := _W.compute_chunk(pair[0], pair[1], SIZE, REAL)
		_W._prof_enabled = false
		print("CHUNK(%d,%d) total=%.1fms (%d block_data bytes)" % [
			pair[0], pair[1], (Time.get_ticks_usec() - t0) * 0.001,
			data["bd"]._data.size() if data.has("bd") else -1])
	await _W.wait_for_tasks_async(get_tree())
	get_tree().quit(0)