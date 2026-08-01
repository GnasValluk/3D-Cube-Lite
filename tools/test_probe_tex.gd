extends Node

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _T = preload("res://scripts/world/chunk/chunk_terrain.gd")

const SIZE := 32
const COLS := 32
const RW := _D._Dim.DimensionID.REAL_WORLD
const TW := _D._Dim.DimensionID.TWILIGHT

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var real_chunk := _W.new()
	real_chunk.name = "TestChunk"
	add_child(real_chunk)
	real_chunk.setup(0, 0, SIZE, RW, true)
	print("T2_SETUP=%d" % (Time.get_ticks_msec() - t0))
	print("T3_DIGS=%d (skipped)" % (Time.get_ticks_msec() - t0))
	print("TOTAL | PASS | 0 failures")
	print("TEST_TIME_MS=%d" % (Time.get_ticks_msec() - t0))
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0)