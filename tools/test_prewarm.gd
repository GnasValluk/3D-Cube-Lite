extends Node

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _Road = preload("res://scripts/world/chunk/chunk_road.gd")
const _River = preload("res://scripts/world/chunk/chunk_river.gd")

var _stage: int = 0
var _t0: int = 0
var _async_road_count: int = 0
var _async_river_count: int = 0
var _async_samples: Array = []
var _async_prewarm_ms: int = 0
var _fails: int = 0
var _seed2_road_count: int = 0

const SEED := 987654321
const SAMPLE_STEP := 30.0

func _ready() -> void:
	WorldSeed.seed_value = SEED
	_t0 = Time.get_ticks_msec()
	_W.prewarm_async()
	_stage = 1
	print("PREWARM | started async")

func _process(_delta: float) -> void:
	if _stage == 1:
		if _W._networks_ready:
			_async_prewarm_ms = Time.get_ticks_msec() - _t0
			_check("prewarm finished", _async_prewarm_ms > 0)
			_check("networks_ready flag", _W._networks_ready)
			_stage = 2
	elif _stage == 2:
		# Idempotent: gọi lại không build thêm
		_W.prewarm_async()
		var t := Time.get_ticks_msec()
		_Road._ensure_roads()
		_River._ensure_rivers()
		var rebuild_ms := Time.get_ticks_msec() - t
		_check("no rebuild on warm", rebuild_ms < 50)
		_async_road_count = _Road._road_curves.size()
		_async_river_count = _River._river_curves.size()
		for x in range(-480, 481, int(SAMPLE_STEP)):
			for z in range(-480, 481, int(SAMPLE_STEP)):
				var wxf := float(x)
				var wzf := float(z)
				_async_samples.append([
					_Road.is_on_road(wxf, wzf),
					_River.is_on_river(wxf, wzf),
					_River.river_distance_factor(wxf, wzf),
				])
		_stage = 3
	elif _stage == 3:
		# Build sync lại với cùng seed → dữ liệu phải giống hệt (worker không corrupt)
		_Road._road_curves.clear()
		_Road._road_curve_bboxes.clear()
		_Road._road_spatial.clear()
		_Road._road_ready = false
		_River._river_curves.clear()
		_River._river_spatial.clear()
		_River._river_ready = false
		_River._int_cache.clear()
		_Road._int_cache.clear()
		var t := Time.get_ticks_msec()
		_Road._ensure_roads()
		_River._ensure_rivers()
		var sync_ms := Time.get_ticks_msec() - t
		_check("sync road count == async", _Road._road_curves.size() == _async_road_count)
		_check("sync river count == async", _River._river_curves.size() == _async_river_count)
		var i: int = 0
		for x in range(-480, 481, int(SAMPLE_STEP)):
			for z in range(-480, 481, int(SAMPLE_STEP)):
				var s: Array = _async_samples[i]
				var wxf := float(x)
				var wzf := float(z)
				if s[0] != _Road.is_on_road(wxf, wzf):
					_check("road sample (%d,%d) mismatch" % [x, z], false)
				if s[1] != _River.is_on_river(wxf, wzf):
					_check("river sample (%d,%d) mismatch" % [x, z], false)
				if not is_equal_approx(s[2], _River.river_distance_factor(wxf, wzf)):
					_check("river factor (%d,%d) mismatch" % [x, z], false)
				i += 1
		print("PREWARM_MS=%d" % _async_prewarm_ms)
		print("SYNC_REBUILD_MS=%d" % sync_ms)
		print("ROADS=%d RIVERS=%d SAMPLES=%d" % [_async_road_count, _async_river_count, _async_samples.size()])
		# Đổi seed → prewarm phải rebuild lại (không trả về data cũ)
		WorldSeed.seed_value = SEED + 1
		_W.prewarm_async()
		_check("seed change blocks ready", not _W._networks_ready)
		_stage = 4

	elif _stage == 4:
		if _W._networks_ready and _W._networks_seed == WorldSeed.seed_value:
			_seed2_road_count = _Road._road_curves.size()
			_check("seed change rebuilt roads", _seed2_road_count != _async_road_count)
			_check("networks_seed updated", _W._networks_seed == WorldSeed.seed_value)
			# Queries trên seed mới phải khác ít nhất 1 mẫu so với seed cũ
			var diff: int = 0
			var i: int = 0
			for x in range(-480, 481, int(SAMPLE_STEP)):
				for z in range(-480, 481, int(SAMPLE_STEP)):
					var s: Array = _async_samples[i]
					if s[0] != _Road.is_on_road(float(x), float(z)):
						diff += 1
					i += 1
			_check("new seed differs on samples", diff > 0)
			print("SEED2_ROADS=%d DIFF_SAMPLES=%d" % [_seed2_road_count, diff])
			if _fails == 0:
				print("TOTAL | PASS | 0 failures")
			else:
				print("TOTAL | FAIL | %d failures" % _fails)
			await WorldChunk.wait_for_tasks_async(get_tree())
			get_tree().quit(0 if _fails == 0 else 1)

func _check(name: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print(("PASS | " if ok else "FAIL | ") + name)
