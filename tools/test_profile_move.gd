extends Node

## Đo spike khi di chuyển qua chunk: teleport player tiến dần 8 chunk theo +Z,
## đo max frame time trong cửa sổ sau mỗi bước để phơi bày spike stream/apply.

const _Main = preload("res://scenes/open_world_real.tscn")

var _root: Node
var _frames := 0
var _t_acc := 0.0
var _t_cnt := 0
var _t_max := 0.0
var _t_prev := 0
var _step := 0
var _last: float = 0.0
var _player: Node3D

func _ready() -> void:
	print("== profile_move ==")
	_root = _Main.instantiate()
	add_child(_root)

func _process(_d: float) -> void:
	_frames += 1
	var now := Time.get_ticks_msec()
	if _t_prev > 0:
		var dt := float(now - _t_prev)
		if _step >= 0:
			_t_acc += dt
			_t_cnt += 1
			_t_max = maxf(_t_max, dt)
	_t_prev = now

	if _player == null:
		_player = _root.find_child("Player", true, false) as Node3D
		if _player == null:
			return
	if _frames >= 600 and _step < 0:
		_step = 0

	if _step < 0:
		return
	if _t_cnt >= 60:
		print("step %d avg=%.2fms max=%.2fms (pos z=%.0f)" % [_step, _t_acc / maxf(_t_cnt, 1), _t_max, _player.global_position.z])
		_t_acc = 0.0
		_t_cnt = 0
		_t_max = 0.0
		_step += 1
		if _step >= 6:
			get_tree().quit(0)
		_player.global_position += Vector3(0, 0, 16 * 4.0)
		_last = Time.get_ticks_msec()