extends Node

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const REAL: int = _D._Dim.DimensionID.REAL_WORLD
const SIZE := 32

var _stage: int = 0
var _parent: Node3D = null
var _chunks: Dictionary = {}
var _keys: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
var _water_ok: int = 0
var _wait: int = 0
var _start_ms: int = 0

func _ready() -> void:
	WorldSeed.seed_value = 123456789
	_W.prewarm_async()
	_parent = Node3D.new()
	add_child(_parent)
	var ps = GDScript.new()
	ps.source_code = "extends Node3D\nvar _chunks = {}\nvar _loading = {}\nvar _last_chunk = Vector2i(99999,99999)\nvar _pending = []\nvar _initial_generated = true\nvar _loading_ready = true\nfunc _sort_chunks(a, b): return true\n"
	ps.reload()
	_parent.set_script(ps)
	_stage = 1

func _process(_delta: float) -> void:
	if _stage == 1:
		if _W._networks_ready:
			_stage = 2
			_run()
	elif _stage == 2:
		# Chờ các worker tasks (collision + water) xong hẳn rồi mới đọc kết quả.
		# Headless chạy không vsync → dựa vào wall-clock, không phải frame count.
		_wait += 1
		if Time.get_ticks_msec() - _start_ms < 1200:
			return
		_stage = 3
		var total_water := 0
		for k in _keys:
			var c = _chunks[k]
			if c._has_water:
				total_water += 1
			if c._water_mesh_instance != null and c._water_mesh_instance.mesh != null \
					and c._water_mesh_instance.mesh.get_surface_count() > 0:
				_water_ok += 1
		print("WATER_APPLIED=%d/%d (has_water=%d)" % [_water_ok, _keys.size(), total_water])
		var ok: bool = _water_ok == _keys.size()
		print("TOTAL | %s" % ["PASS" if ok else "FAIL"])
		await WorldChunk.wait_for_tasks_async(get_tree())
		get_tree().quit(0 if ok else 1)

func _run() -> void:
	var data_map := {}
	var t0 := Time.get_ticks_msec()
	for k in _keys:
		data_map[k] = _W.compute_chunk(k.x, k.y, SIZE, REAL)
	print("COMPUTE_5=%dms" % [Time.get_ticks_msec() - t0])

	var chunks := {}
	var apply_total := 0
	for k in _keys:
		var c := _W.new()
		c.name = "C%d_%d" % [k.x, k.y]
		c.position = Vector3(k.x * SIZE, 0, k.y * SIZE)
		c._cx = k.x; c._cz = k.y; c._size = SIZE
		c._dimension_id = REAL
		c._cols = int(SIZE / _D.VOXEL)
		c._tiles_per_chunk = int(c._cols / _D.TILE_W)
		c._init_materials()
		_parent.add_child(c)
		chunks[k] = c
		var t := Time.get_ticks_msec()
		c.apply_chunk(data_map[k])
		c._pending_data = {}
		var ms := Time.get_ticks_msec() - t
		apply_total += ms
		print("APPLY %s=%dms" % [k, ms])
	_parent._chunks = chunks
	_chunks = chunks
	print("APPLY_TOTAL=%dms" % apply_total)

	var center: Node3D = chunks[Vector2i(0, 0)]
	_start_ms = Time.get_ticks_msec()
	var t2 := Time.get_ticks_msec()
	center.refresh_boundary_water()
	print("REFRESH_WATER=%dms" % [Time.get_ticks_msec() - t2])
