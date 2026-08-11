extends Node

## Đo khi đi bộ thật: player tiến dần +Z với tốc độ thực (5.27 m/s ~ 1 chunk / 3s),
## đo rolling avg & max mỗi 180 frame để phơi bày spike stream khi cắt chunk cũ + hiện chunk mới.

const _Main = preload("res://scenes/open_world_real.tscn")

var _root: Node
var _frames := 0
var _t_prev := 0
var _t_acc := 0.0
var _t_cnt := 0
var _t_max := 0.0
var _player: Node3D

func _ready() -> void:
	print("== walk ==")
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
	if _frames <= 900:
		return
	_player.global_position += Vector3(0, 0, 5.27 / 60.0)
	if _t_cnt >= 180:
		print("seg %d avg=%.2fms max=%.2fms (z=%.0f)" % [floori(_frames / 180.0), _t_acc / float(_t_cnt), _t_max, _player.global_position.z])
		_t_acc = 0.0
		_t_cnt = 0
		_t_max = 0.0
	if _player.global_position.z >= 400.0:
		get_tree().quit(0)