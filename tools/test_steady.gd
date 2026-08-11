extends Node

## Đo steady-state khi world đã load xong: instantiate scene, đợi 900 frame
## settle, rồi đo avg/max frame time trong 300 frame.

const _Main = preload("res://scenes/open_world_real.tscn")

var _root: Node
var _frames := 0
var _t_prev := 0
var _acc := 0.0
var _cnt := 0
var _max := 0.0

func _ready() -> void:
	print("== steady ==")
	_root = _Main.instantiate()
	add_child(_root)

func _process(_d: float) -> void:
	_frames += 1
	var now := Time.get_ticks_msec()
	if _frames <= 900:
		_t_prev = now
		return
	if _t_prev > 0:
		var dt := float(now - _t_prev)
		_acc += dt
		_cnt += 1
		_max = maxf(_max, dt)
	_t_prev = now
	if _cnt >= 300:
		print("steady avg=%.2fms max=%.1fms" % [_acc / float(_cnt), _max])
		get_tree().quit(0)