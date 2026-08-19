extends Node

## Headless giả lập LOAD MAP R8 (17×17 chunk, view_radius=8, horizon 16) với
## player teleport xa — tái hiện đường load giống game thật (max_fps=60 mô phỏng
## nhịp frame). Đo: phân phối frame-delta (max/p99/mean) để tìm spike main-thread
## + thời gian đạt vùng full. Chạy qua tools/test_map_load.tscn.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _Mgr = preload("res://scripts/world/open_world_manager.gd")

const R: int = 8
const FULL_TARGET: int = (2 * R + 1) * (2 * R + 1)  # 289
const GOAL: int = FULL_TARGET - 15  # 274 chunk full là đủ (chunk đang load trừ ra)

var _mgr: Node3D = null
var _player: Node3D = null
var _stage: int = 0
var _frame: int = 0
var _deltas: Array[float] = []
var _prev_t: int = 0
var _start_ms: int = 0
var _tel_ms: int = 0
var _cleanup_done: bool = false

func _ready() -> void:
	WorldSeed.seed_value = 424242
	seed(424242)
	if SettingsManager:
		SettingsManager.chunk_view = R
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	_W.prewarm_async()
	_mgr = _Mgr.new()
	add_child(_mgr)
	_player = Node3D.new()
	_player.name = "MapLoadPlayer"
	add_child(_player)
	_mgr._player = _player
	_stage = 1
	_start_ms = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if _stage == 1:
		if not _W._networks_ready:
			return
		_stage = 2
		_player.global_position = Vector3(32000.0, 20.0, -8000.0)
		_tel_ms = Time.get_ticks_msec()
		_frame = 0
		_prev_t = _tel_ms
		return

	if _stage == 2:
		var now := Time.get_ticks_msec()
		_deltas.append(float(now - _prev_t))
		_prev_t = now
		_frame += 1
		if _mgr._chunks.size() >= GOAL:
			_stage = 3
			print("MAPLOAD_GOAL full=%d at frame %d, %.0fms after teleport (loading=%d loading_tiles=%d)" % [
				_mgr._chunks.size(), _frame, now - _tel_ms, _mgr._loading.size(), _mgr._loading_tiles.size()])
			_dump()
			_cleanup()
			return
		if _frame == 1500:
			_stage = 3
			print("MAPLOAD_TIMEOUT full=%d at frame %d (loading=%d loading_tiles=%d pending=%d)" % [
				_mgr._chunks.size(), _frame, _mgr._loading.size(), _mgr._loading_tiles.size(), _mgr._pending.size()])
			_dump()
			_cleanup()
			return
	if _stage == 3 and not _cleanup_done:
		pass

func _dump() -> void:
	if _deltas.is_empty():
		return
	_deltas.sort()
	var n: int = _deltas.size()
	var mean: float = 0.0
	for d in _deltas:
		mean += d
	mean /= float(n)
	var p99: float = _deltas[clampi(int(n * 0.99), 0, n - 1)]
	var maxv: float = _deltas[n - 1]
	var over50: int = 0
	var over100: int = 0
	for d in _deltas:
		if d > 50.0: over50 += 1
		if d > 100.0: over100 += 1
	print("MAPLOAD_DELTAS n=%d mean=%.1fms p99=%.1fms max=%.1fms >50ms=%d >100ms=%d" % [
		n, mean, p99, maxv, over50, over100])

func _cleanup() -> void:
	_cleanup_done = true
	_mgr.set_process(false)
	_mgr._player = null
	_player.queue_free()
	print("MAPLOAD_END total_ms=%d (seed_ready=%dms)" % [Time.get_ticks_msec() - _start_ms, _tel_ms - _start_ms])
	await _W.wait_for_tasks_async(get_tree())
	get_tree().quit(0)