extends Node

## Đo khi vượt chunk mới thực tế: teleport player +16m (1 chunk) mỗi 240 frame,
## đo avg/max frame trong window 240 frame — đúng nhịp đi bộ stream (1 chunk/4s).

const _Main = preload("res://scenes/open_world_real.tscn")

var _root: Node
var _frames := 0
var _t_prev := 0
var _t_acc := 0.0
var _t_cnt := 0
var _t_max := 0.0
var _step := 0
var _player: Node3D

func _ready() -> void:
	print("== stepchunk ==")
	_root = _Main.instantiate()
	add_child(_root)

func _process(_d: float) -> void:
	_frames += 1
	var now := Time.get_ticks_msec()
	if _t_prev > 0:
		var dt := float(now - _t_prev)
		_t_acc += dt
		_t_cnt += 1
		_t_max = maxf(_t_max, dt)
	_t_prev = now
	if _player == null:
		_player = _root.find_child("Player", true, false) as Node3D
		if _player == null:
			return
	if _frames < 600:
		return
	if _t_cnt >= 240:
		print("step %d avg=%.2fms max=%.2fms (z=%.0f)" % [_step, _t_acc / float(_t_cnt), _t_max, _player.global_position.z])
		_t_acc = 0.0
		_t_cnt = 0
		_t_max = 0.0
		_step += 1
		if _step >= 10:
			get_tree().quit(0)
		_player.global_position += Vector3(0, 0, 16.0)