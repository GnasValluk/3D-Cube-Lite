extends Node3D

## Benchmark hiệu năng CPU main-thread khi streaming chunk.
## Chạy: Godot --headless --path <project> res://tools/test_perf_world_stream.tscn
## Đo: frame delta (ms) theo 3 phase (idle, stream di chuyển). FPS cap 60
## → delta > 16.6ms là frame chậm vượt budget, > 33ms là giật rõ.
## In ra min/avg/p95/p99 + số frame quá ngưỡng + backlog CollisionQueue/loading.

const OUT_PHASES: Array[String] = ["idle", "stream"]

const _DUMP_PATH: String = "C:/Users/gnasv/AppData/Local/Temp/opencode/perf_dump.txt"

var _dump_f: FileAccess = null

func _logfile(msg: String) -> void:
	if _dump_f == null:
		_dump_f = FileAccess.open(_DUMP_PATH, FileAccess.WRITE_READ)
	if _dump_f != null:
		_dump_f.seek_end()
		_dump_f.store_line(msg)

var _phases: Dictionary = {}
var _last_t: int = -1
var _world_mgr = null
var _player: Node3D = null
var _phase_active: String = ""

func _new_phase() -> Dictionary:
	return {
		"frames": 0,
		"samples": PackedFloat64Array(),
		"max_backlog_collision": 0,
		"max_backlog_loading": 0,
		"max_backlog_water": 0,
	}

func _init_phases() -> void:
	for p in OUT_PHASES:
		_phases[p] = _new_phase()

func _collect_meta(ph: Dictionary, world_mgr) -> void:
	if is_instance_valid(CollisionQueue):
		ph["max_backlog_collision"] = maxi(ph["max_backlog_collision"], (CollisionQueue._queue as Array).size())
	if is_instance_valid(WaterRebuildQueue):
		var q = WaterRebuildQueue.get("_pending")
		if q != null:
			ph["max_backlog_water"] = maxi(ph["max_backlog_water"], (q as Array).size())
	if world_mgr != null:
		var load: Dictionary = world_mgr.get("_loading")
		if load != null:
			ph["max_backlog_loading"] = maxi(ph["max_backlog_loading"], load.size())

func _report(name: String) -> void:
	var ph: Dictionary = _phases[name]
	var s: PackedFloat64Array = ph["samples"]
	if s.is_empty():
		print("[perf] %-6s | no samples" % name)
		return
	var sorted: PackedFloat64Array = s.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var p95: float = sorted[int(round((n - 1) * 0.95))]
	var p99: float = sorted[int(round((n - 1) * 0.99))]
	var total: float = 0.0
	var overs: Dictionary = { "gt33": 0, "gt50": 0, "gt100": 0 }
	for v in s:
		total += v
		if v > 33.0: overs["gt33"] += 1
		if v > 50.0: overs["gt50"] += 1
		if v > 100.0: overs["gt100"] += 1
	print("[perf] %-6s | n=%5d min=%6.2f avg=%6.2f p95=%6.2f p99=%6.2f max=%6.2f | gt33=%4d gt50=%4d gt100=%4d | backlog col=%d load=%d water=%d" % [
		name, n, sorted[0], total / n, p95, p99, sorted[n - 1],
		overs["gt33"], overs["gt50"], overs["gt100"],
		ph["max_backlog_collision"], ph["max_backlog_loading"], ph["max_backlog_water"],
	])

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _last_t >= 0 and _phase_active != "":
		var ms: float = (now - _last_t) * 0.001
		var ph: Dictionary = _phases[_phase_active]
		ph["frames"] += 1
		ph["samples"].append(ms)
		_collect_meta(ph, _world_mgr)
	_last_t = now

func _ready() -> void:
	print("== test_perf_world_stream: đo CPU main-thread khi stream chunk ==")
	_logfile("=== run start ===")
	Engine.max_fps = 60
	_init_phases()
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	var tree := get_tree()
	tree.current_scene = world

	var t_boot := Time.get_ticks_usec()
	var mgr: Node = null
	for i in range(2500):
		await tree.process_frame
		mgr = world.get_node_or_null("WorldManager")
		if mgr != null and mgr.get("_initial_generated") == true:
			var ready: bool = mgr.get("_loading_ready")
			if ready == true:
				break
	var boot_ms: float = (Time.get_ticks_usec() - t_boot) * 0.001
	print("[perf] boot     | %.0fms to initial_chunks_ready" % boot_ms)
	_logfile("[perf] boot %.0fms" % boot_ms)

	_world_mgr = world.get_node_or_null("WorldManager")
	_player = world.get_node_or_null("CharacterManager/Player") as Node3D
	if _player == null:
		print("[perf] FAIL: không tìm thấy Player")
		await WorldChunk.wait_for_tasks_async(tree)
		tree.quit(1)
		return
	_print_node_counts("boot")

	# ── Phase 1: idle — đứng yên, đo cost frame nền ─────────────────────────
	_player.global_position = Vector3(0, 6, 0)
	var _t_proc := 0.0
	var _t_phys := 0.0
	var _t_nav := 0.0
	_phase_active = "idle"
	for i in range(180):
		await tree.process_frame
		_t_proc += float(Performance.get_monitor(Performance.TIME_PROCESS))
		_t_phys += float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		_t_nav += float(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS))
	_phase_active = ""
	_report("idle")
	print("[perf] idle     | sum proc=%.0fus phys=%.0fus nav=%.0fus" % [_t_proc, _t_phys, _t_nav])

	# ── Phase 2: stream — đi ngoằn ngoèo để cắt biên chunk liên tục ─────────
	# Bước nhỏ (~7u/frame) giống tốc độ chạy thật, không nhảy xa bất thường.
	_phase_active = "stream"
	var angle := 0.0
	var radius := 8.0
	var origin := Vector3(0, 90, 0)
	for i in range(180):
		angle += 0.03
		radius += 0.2
		var dx := cos(angle) * radius
		var dz := sin(angle) * radius
		_player.global_position = origin + Vector3(dx, 0, dz)
		if i == 60 or i == 120 or i == 179:
			var nodes_i := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			var phys := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 0.001
			print("[perf] stream frame=%d node_count=%d phys_ms=%.1f" % [i, int(nodes_i), phys])
			_logfile("[perf] stream frame=%d node_count=%d phys_ms=%.1f" % [i, int(nodes_i), phys])
			if nodes_i > 30000:
				_logfile("[perf] ABORT node explosion")
				await WorldChunk.wait_for_tasks_async(get_tree(), 5000)
				get_tree().quit(2)
				return
		await tree.process_frame
	_phase_active = ""
	_report("stream")
	_print_node_counts("stream")

	print("[perf] done")
	await WorldChunk.wait_for_tasks_async(tree)
	tree.quit(0)

func _print_node_counts(label: String) -> void:
	var nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	print("[perf] %-6s | node_count=%d" % [label, nodes])