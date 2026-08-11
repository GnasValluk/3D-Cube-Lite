extends Node

## Profile sâu: đếm MeshInstance3D và OmniLight3D theo script cha (source) để
## tìm nơi sinh ra nhiều draw call + light nhất trong Forward Mobile.

const _Main = preload("res://scenes/open_world_real.tscn")

var _root: Node
var _frames := 0
var _samples := 0
var _t_ms := 0.0
var _t_max := 0.0
var _t_prev := 0
var _meshes: Dictionary = {}
var _lights: Dictionary = {}
var _mmi_total := 0
var _omni_total := 0
var _light_energy_total := 0.0

func _ready() -> void:
	print("== profile_src ==")
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
	_collect(_root)
	print("frame avg=%.2fms max=%.2fms (%d frames)" % [_t_ms / maxf(_samples, 1), _t_max, _samples])
	print("-- MeshInstance3D theo nguồn --")
	for k in _meshes.keys():
		print("  %-40s %d" % [k, _meshes[k]])
	print("-- OmniLight3D theo nguồn --")
	for k in _lights.keys():
		print("  %-40s %d" % [k, _lights[k]])
	print("MMI total=%d  Omni total=%d  sum_energy=%.1f" % [_mmi_total, _omni_total, _light_energy_total])
	print("draw=%d prims=%d nodes=%d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	])
	get_tree().quit(0)

func _src_of(n: Node) -> String:
	var s := n.get_script() as Script
	if s != null:
		return s.resource_path.get_file().trim_suffix(".gd")
	var ch := n.get_parent()
	if ch != null and ch.get_script() != null:
		return "<%s>" % (ch.get_script() as Script).resource_path.get_file().trim_suffix(".gd")
	return "<plain>"

func _collect(n: Node) -> void:
	for c in n.get_children():
		if c is MultiMeshInstance3D:
			_mmi_total += 1
		elif c is MeshInstance3D:
			var src := _src_of(c.get_parent()) if c.get_parent() else "?"
			_meshes[src] = _meshes.get(src, 0) + 1
		elif c is OmniLight3D:
			var src := _src_of(c.get_parent()) if c.get_parent() else "?"
			_lights[src] = _lights.get(src, 0) + 1
			_omni_total += 1
			_light_energy_total += c.light_energy
		_collect(c)