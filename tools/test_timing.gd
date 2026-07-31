extends Node

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _Lamp = preload("res://scripts/world/chunk/chunk_road_lamp.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const SIZE := 32

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_Lamp._Road._ensure_roads()
	print("ROADS=%dms curves=%d" % [Time.get_ticks_msec() - t0, _Lamp._Road._road_curves.size()])
	t0 = Time.get_ticks_msec()
	_W._River._ensure_rivers()
	print("RIVERS=%dms curves=%d" % [Time.get_ticks_msec() - t0, _W._River._river_curves.size()])
	print("DONE")
	get_tree().quit(0)
