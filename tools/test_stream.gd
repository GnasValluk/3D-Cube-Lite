extends Node

## Headless benchmark: tốc độ chunk stream khi player nhảy xa (teleport) —
## manager phải evict vòng cũ + nạp lại vòng full mới. Chạy qua tools/test_stream.tscn.
## Đo: số frame + ms thực để vùng full đạt ≥70 chunk (ring R=4: 9×9=81).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _Mgr = preload("res://scripts/world/open_world_manager.gd")

const R: int = 4
const RING_TARGET: int = (2 * R + 1) * (2 * R + 1)  # 81
const GOAL: int = RING_TARGET - 10  # đạt 71 chunk full là đủ (trừ chunk đang load)

var _mgr: Node3D = null
var _player: Node3D = null
var _stage: int = 0
var _frame: int = 0
var _tel_ms: int = 0
var _start_ms: int = 0
var _cleanup_done: bool = false

func _ready() -> void:
	WorldSeed.seed_value = 20260802
	seed(20260802)
	if SettingsManager:
		SettingsManager.chunk_view = R
	_W.prewarm_async()
	_mgr = _Mgr.new()
	add_child(_mgr)
	_player = Node3D.new()
	_player.name = "BenchPlayer"
	add_child(_player)
	_mgr._player = _player
	_stage = 1
	_start_ms = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if _stage == 1:
		if not _W._networks_ready:
			return
		_stage = 2
		# Nhảy thật xa khỏi vòng ban đầu (0,0) — ép evict toàn bộ + nạp lạantee
		_player.global_position = Vector3(32000.0, 20.0, -8000.0)
		_tel_ms = Time.get_ticks_msec()
		_frame = 0
		return

	if _stage == 2:
		_frame += 1
		if _frame == 2000:
			print("STREAM_TIMEOUT at frame %d: full=%d loading=%d pending=%d" % [
				_frame, _mgr._chunks.size(), _mgr._loading.size(), _mgr._pending.size()])
			_stage = 3
		else:
			if _mgr._chunks.size() >= GOAL:
				print("STREAM_GOAL %d full at frame %d, %.0fms after teleport (loading=%d pending=%d)" % [
					_mgr._chunks.size(), _frame, Time.get_ticks_msec() - _tel_ms,
					_mgr._loading.size(), _mgr._pending.size()])
				_stage = 3
	if _stage == 3:
		# Đợi 1 chút cho worker dọn rồi in backlog còn lại.
		_stage = 4
		_mgr.set_process(false)
		_mgr._player = null
		_player.queue_free()
		_cleanup_done = true
		await _W.wait_for_tasks_async(get_tree())
		print("STREAM_END total_ms=%d (seed_ready in %dms)" % [Time.get_ticks_msec() - _start_ms, _tel_ms - _start_ms])
		get_tree().quit(0)