extends Node

## test_bench_rebuild — đo thời gian thật của rebuild_mesh trên chunk 32×32
## sau khi đặt block (single vs bulk). Cho biết mỗi lần place tốn bao nhiêu ms.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")

const REAL: int = _D._Dim.DimensionID.REAL_WORLD
const _FAILURES: int = 0

func _ready() -> void:
	print("== test_bench_rebuild ==")
	WorldSeed.seed_value = 20260806
	_W.props_enabled = false
	_W.clear_noise_cache()

	var d := _W.compute_chunk(0, 0, 32, REAL, false, false)
	var bd := _BD.new()
	bd.from_bytes(d["block_data_bytes"], 32, 32)
	var chunk := _W.new()
	chunk._cols = 32
	chunk._cx = 0
	chunk._cz = 0
	chunk._dimension_id = REAL
	chunk.block_data = bd
	chunk._init_materials()
	add_child(chunk)

	chunk.rebuild_mesh()

	var t := Time.get_ticks_usec()
	chunk.rebuild_mesh()
	print("rebuild_mesh full (no change): %.2f ms" % ((Time.get_ticks_usec() - t) / 1000.0))

	var tl: int = chunk._top_ly_cache[16 * 32 + 16]
	var wby: float = (float(tl + _BD.Y_MIN) + 0.5) * _BD.SLAB_HEIGHT
	print("surface y at (16,16) = %.2f (top layer %d)" % [wby, tl])

	t = Time.get_ticks_usec()
	var ok: bool = chunk.place_block_at(16.5, wby, 15.5, _D.BlockID.STONE_PLATFORM, _BD.OFF_CENTER)
	print("place_block_at 1 block: ok=%s rebuild %.2f ms" % [str(ok), (Time.get_ticks_usec() - t) / 1000.0])

	var positions: Array[Vector3] = []
	var bids: Array[int] = []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			positions.append(Vector3(16.0 + dx, wby, 16.0 + dz))
			bids.append(_D.BlockID.STONE_PLATFORM)
	t = Time.get_ticks_usec()
	var n: int = chunk.place_blocks_at(positions, bids, _BD.OFF_CENTER)
	print("place_blocks_at bulk 9: placed=%d rebuild %.2f ms" % [n, (Time.get_ticks_usec() - t) / 1000.0])

	chunk.queue_free()
	print("== test_bench_rebuild done (%d fail) ==" % _FAILURES)
	get_tree().quit(0)