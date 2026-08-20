extends Node

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _Village = preload("res://scripts/world/chunk/village.gd")
const _Road = preload("res://scripts/world/chunk/chunk_road.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const REAL: int = _D._Dim.DimensionID.REAL_WORLD

func _ready() -> void:
	WorldSeed.seed_value = 20260802
	_W.prewarm_async()

func _process(_delta: float) -> void:
	if not _W._networks_ready:
		return
	set_process(false)
	_run()

func _run() -> void:
	for c in [[0, 0], [1, 0], [-302, -230]]:
		_W._prof_enabled = true
		var res: Dictionary = _W.compute_chunk(c[0], c[1], 32, REAL, false, false)
		_W._prof_enabled = false
		var gbd: Dictionary = res.get("grass_blade_data", {})
		var n_xforms: int = gbd.get("xforms", []).size()
		var rg := PackedByteArray()
		rg.resize(32 * 32)
		rg.fill(0)
		_Road.paint_road_grid(rg, 32, 32, c[0], c[1])
		var t0 := Time.get_ticks_usec()
		var vd := _Village.compute_village(c[0], c[1], 32, REAL,
				res["biome_grid"], res["height_grid"], rg, res["river_flag"], 32)
		var t1 := Time.get_ticks_usec()
		print("chunk(%d,%d) grass_blades=%d village_ms=%.1f village_has=%s xforms_in_vd=%d"
				% [c[0], c[1], n_xforms, (t1 - t0) * 0.001, vd.get("has", false), vd.get("xforms", []).size()])
	get_tree().quit(0)