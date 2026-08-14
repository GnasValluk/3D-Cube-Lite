extends Node

## Đo chi phí SKY (BG_SKY vs BG_COLOR) interleaved A/B/A/B/A/B — loại nhiễu
## do world đang stream gây giảm dần frame time.

const _Main = preload("res://scenes/open_world_real.tscn")

var _root: Node
var _env: WorldEnvironment
var _frames := 0
var _phase := -1
var _t_acc := 0.0
var _t_cnt := 0
var _t_prev := 0
var _results: Array = []

func _ready() -> void:
	print("== profile_sky2 ==")
	_root = _Main.instantiate()
	add_child(_root)

func _process(_d: float) -> void:
	_frames += 1
	if _frames < 420:
		return
	var now := Time.get_ticks_msec()
	if _t_prev > 0:
		_t_acc += float(now - _t_prev)
		_t_cnt += 1
	_t_prev = now

	if _phase < 0:
		_phase = 0
		_sky(true)
		_t_acc = 0.0
		_t_cnt = 0
	elif _t_cnt >= 30:
		_results.append(_t_acc / _t_cnt)
		_phase += 1
		if _phase >= 6:
			print("A(sky) : %.2f %.2f %.2f" % [_results[0], _results[2], _results[4]])
			print("B(flat): %.2f %.2f %.2f" % [_results[1], _results[3], _results[5]])
			var a: float = (_results[0] + _results[2] + _results[4]) / 3.0
			var b: float = (_results[1] + _results[3] + _results[5]) / 3.0
			print("avg sky=%.2fms flat=%.2fms -> sky cost=%.2fms" % [a, b, a - b])
			get_tree().quit(0)
		_sky(_phase % 2 == 0)
		_t_acc = 0.0
		_t_cnt = 0

func _sky(on: bool) -> void:
	if _env == null:
		_env = _root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if _env == null or _env.environment == null:
		return
	if on:
		_env.environment.background_mode = Environment.BG_SKY
	else:
		_env.environment.background_mode = Environment.BG_COLOR
		_env.environment.background_color = Color(0.5, 0.6, 0.7)