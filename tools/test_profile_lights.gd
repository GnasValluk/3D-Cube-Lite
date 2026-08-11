extends Node

## Đo chi phí đèn CHÍNH XÁC: chờ world stream + prop ổn định (400 frame), rồi
## đo xen kẽ A (đèn bật) / B (đèn tắt) 3 cặp × 30 frame → avg từng phase.
## Loại bỏ nhiễu do world đang load gây frame giảm dần theo thời gian.

const _Main = preload("res://scenes/open_world_real.tscn")

var _root: Node
var _frames := 0
var _phase := -1        # -1 warmup, 0..5 đo
var _pair_count := 0
var _t_acc := 0.0
var _t_cnt := 0
var _t_prev := 0
var _results: Array = []

func _ready() -> void:
	print("== profile_lights2 ==")
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
		_lights(true)
		_t_acc = 0.0
		_t_cnt = 0
	elif _t_cnt >= 30:
		_results.append(_t_acc / _t_cnt)
		_phase += 1
		if _phase >= 6:
			print("A(on) : %.2f %.2f %.2f" % [_results[0], _results[2], _results[4]])
			print("B(off): %.2f %.2f %.2f" % [_results[1], _results[3], _results[5]])
			var a: float = (_results[0] + _results[2] + _results[4]) / 3.0
			var b: float = (_results[1] + _results[3] + _results[5]) / 3.0
			print("avg A=%.2fms B=%.2fms -> light cost=%.2fms" % [a, b, a - b])
			get_tree().quit(0)
		_lights(_phase % 2 == 0)
		_t_acc = 0.0
		_t_cnt = 0

func _lights(on: bool) -> void:
	for l in _root.find_children("*", "OmniLight3D", true, false):
		l.visible = on