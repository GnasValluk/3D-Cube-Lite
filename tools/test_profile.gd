extends Node

## Profile thật trong game: boot main.tscn, chờ world stream + prop spawn xong,
## đo trong ~120 frame: frame time, draw, verts, đếm node theo loại (mesh/MMI/light/
## particles).

const _Main = preload("res://scenes/open_world_real.tscn")

var _root: Node
var _frames := 0
var _samples := 0
var _t_ms := 0.0
var _t_max := 0.0
var _t_prev := 0
var _counts: Dictionary = {}

func _ready() -> void:
	print("== profile ==")
	_root = _Main.instantiate()
	add_child(_root)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 180:
		return
	var now := Time.get_ticks_msec()
	if _t_prev > 0:
		var dt := float(now - _t_prev)
		_t_ms += dt
		_t_max = maxf(_t_max, dt)
		_samples += 1
	_t_prev = now
	if _frames < 300:
		return
	_count_recursive(_root)
	print("frame avg=%.2fms max=%.2fms over %d frames" % [_t_ms / maxf(_samples, 1), _t_max, _samples])
	for k in _counts.keys():
		print("  %s = %d" % [k, _counts[k]])
	print("time_us: process=%.1f physics=%.1f nav=%.1f" % [
		Performance.get_monitor(Performance.TIME_PROCESS) / 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) / 1000.0,
		Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) / 1000.0,
	])
	get_tree().quit(0)
	get_tree().quit(0)

func _count_recursive(n: Node) -> void:
	for c in n.get_children():
		if c is MultiMeshInstance3D:
			_counts["MultiMeshInstance3D"] = _counts.get("MultiMeshInstance3D", 0) + 1
		elif c is MeshInstance3D:
			_counts["MeshInstance3D"] = _counts.get("MeshInstance3D", 0) + 1
		elif c is OmniLight3D:
			_counts["OmniLight3D"] = _counts.get("OmniLight3D", 0) + 1
		elif c is DirectionalLight3D:
			_counts["DirectionalLight3D"] = _counts.get("DirectionalLight3D", 0) + 1
		elif c is CPUParticles3D or c is GPUParticles3D:
			_counts["Particles3D"] = _counts.get("Particles3D", 0) + 1
		_count_recursive(c)