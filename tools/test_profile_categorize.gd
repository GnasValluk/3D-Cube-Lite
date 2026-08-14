extends Node

## Đếm MeshInstance3D theo 2 nhóm: DIRECT (con trực tiếp của chunk container,
## tức terrain/water/lava/aquatic/ore) vs NESTED (bên trong prop -> prop build).

const _Main = preload("res://scenes/open_world_real.tscn")

var _root: Node
var _frames := 0
var _direct := 0
var _nested := 0
var _mmi := 0
var _lights := 0
var _chunks := 0
var _props := 0

func _ready() -> void:
	print("== profile_direct_nested ==")
	_root = _Main.instantiate()
	add_child(_root)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 300:
		return
	_scan(_root)
	print("direct MI=%d  nested MI=%d  MMI=%d  lights=%d  chunks=%d  props=%d" % [
		_direct, _nested, _mmi, _lights, _chunks, _props])
	get_tree().quit(0)

func _is_direct_child(n: Node) -> bool:
	var parent := n.get_parent()
	if parent == null:
		return false
	var pp := parent.get_parent()
	return pp != null and pp.name.begins_with("Chunk")

func _scan(n: Node) -> void:
	for c in n.get_children():
		if c is OmniLight3D:
			_lights += 1
		elif c is MeshInstance3D:
			if _is_direct_child(c):
				_direct += 1
			else:
				_nested += 1
		elif c is MultiMeshInstance3D:
			_mmi += 1
		if c.name.begins_with("Chunk"):
			_chunks += 1
		_scan(c)