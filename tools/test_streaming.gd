extends Node

## test_streaming — benchmark process-time THỰC khi khám phá local (bounded).
## WorldManager thật + player đi ngoằn ngoèo quanh (0,0) qua đất & biển,
## đo Performance.TIME_PROCESS mỗi frame. Giới hạn khoảng cách để luôn stream
## chunk lân cận (không teleport — sát thực tế). Chạy qua tools/test_streaming.tscn.

const _WM = preload("res://scripts/world/open_world_manager.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _W = preload("res://scripts/world/chunk/world_chunk.gd")

const REAL: int = _D._Dim.DimensionID.REAL_WORLD
const SWEEP_FRAMES: int = 1500
const AMP: float = 480.0   # bán kính quét quanh gốc (~15 chunk)

var _stage: int = 0
var _wm = null
var _player: Node3D = null
var _f: int = 0

var _max: float = 0.0
var _max_at: int = 0
var _sum: float = 0.0
var _n: int = 0
var _spikes: int = 0
var _done: bool = false

func _ready() -> void:
	WorldSeed.seed_value = 20260806
	_W.props_enabled = false
	_W.prewarm_async()
	var root := Node3D.new()
	root.name = "WorldRoot"
	add_child(root)
	_wm = _WM.new()
	_wm.dimension_id = REAL
	_wm.name = "WorldManager"
	root.add_child(_wm)
	_player = Node3D.new()
	_player.name = "Player"
	_player.position = Vector3(0, 3, 0)
	root.add_child(_player)
	_wm._player = _player
	print("HELLO _W.props_enabled=%s" % str(_W.props_enabled))
	_stage = 1

func _process(_d: float) -> void:
	_f += 1
	if _f <= 5 or _f % 300 == 0:
		print("..tick f=%d stage=%d loaded=%d/%d pending=%d loading=%d" % [_f, _stage,
			_wm._loaded_initial, _wm._total_initial, _wm._pending.size(), _wm._loading.size()])
	# Quét ngoằn ngoèo bounded quanh gốc — đủ vượt ranh giới chunk đất/biển
	var ang := _f * 0.0038
	var px := (sin(_f * 0.007) * 0.55 + sin(ang)) * (AMP * 0.5)
	var pz := (cos(_f * 0.005) * 0.7 + cos(ang)) * (AMP * 0.5)
	_player.global_position = Vector3(px, 3.0, pz)

	if _stage == 1:
		if _wm._loaded_initial >= _wm._total_initial:
			print("== warmup xong — stream sweep %d frames ==" % SWEEP_FRAMES)
			_f = 0
			_stage = 2
		return

	# Đo process-time mỗi frame (chỉ khi có chunk mới đang load — tránh frame idle)
	if _wm._loading.size() > 0 or _wm._pending.size() > 0:
		var ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		if ms > _max:
			_max = ms
			_max_at = _f
		_sum += ms
		_n += 1
		if ms > 90.0:
			_spikes += 1
			print("SPIKE %.0fms @%d pos=(%.0f,%.0f) loading=%d pending=%d loaded=%d" % [
				ms, _f, _player.global_position.x, _player.global_position.z,
				_wm._loading.size(), _wm._pending.size(), _wm._loaded_initial])

	if _f >= SWEEP_FRAMES and not _done:
		_done = true
		print("MAX_PROCESS_TIME=%.2fms @sweepframe%d" % [_max, _max_at])
		print("AVG_PROCESS_TIME=%.2fms over %d active-load frames (SPIKE>90ms: %d)" % [_sum / maxi(_n, 1), _n, _spikes])
		await _W.wait_for_tasks_async(get_tree())
		get_tree().quit(0)
