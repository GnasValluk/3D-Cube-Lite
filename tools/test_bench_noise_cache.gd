extends Node

## Benchmark: compute_chunk trên 5x5 chunk cận kề — đo lợi ích cache
## biome/ocean dùng chung giữa các chunk (overlap padding). So sánh turn 1
## (cold) vs turn 2 (warm) — nếu cache hiệu quả, turn 2 nhanh hẳn.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const SIZE := 32
const REAL: int = _D._Dim.DimensionID.REAL_WORLD

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
		_bench("cold")
	elif _stage == 3:
		_stage = 4
		_bench("warm")
	elif _stage == 4:
		get_tree().quit(0)

func _bench(tag: String) -> void:
	var centers: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(5, -3), Vector2i(-12, 4),
		Vector2i(3, 9), Vector2i(-4, -6),
	]
	var total_us := 0.0
	var chunks := 0
	for c in centers:
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var t0 := Time.get_ticks_usec()
				_W.compute_chunk(c.x + dx, c.y + dz, SIZE, REAL)
				total_us += Time.get_ticks_usec() - t0
				chunks += 1
	print("[%s] %d chunks total=%.1fms avg=%.2fms" % [tag, chunks, total_us * 0.001, total_us * 0.001 / chunks])