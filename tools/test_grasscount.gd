extends Node

## Đếm tổng grass blade MultiMesh instances: mọi MultiMeshInstance3D dùng BoxMesh
## unit + unshaded (grass blades) — blade instance nhỏ (scale ~0.03) nên nhận diện
## bằng số instance lớn và mesh BoxMesh. Bỏ qua props/trees (instance ít hơn).

const _Main = preload("res://scenes/open_world_real.tscn")
const _Grass = preload("res://scripts/world/chunk/chunk_grass.gd")

var _root: Node
var _frames := 0
var _has_counter := false

func _ready() -> void:
	print("== grasscount ==")
	if _Grass.has_method("reset_debug"):
		_Grass.reset_debug()
	_has_counter = _Grass.has_method("reset_debug")
	_root = _Main.instantiate()
	add_child(_root)

func _process(_d: float) -> void:
	_frames += 1
	if _frames != 1200:
		return
	if _has_counter:
		print("grass_blades=%d" % _Grass.debug_count)
	else:
		var blades := 0
		var grass_mmis := 0
		var stack := [_root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MultiMeshInstance3D:
				var mm: MultiMesh = n.multimesh
				if mm != null and mm.instance_count > 50 and mm.mesh is BoxMesh:
					var bm := mm.mesh as BoxMesh
					if absf(bm.size.x - 1.0) < 0.01:
						grass_mmis += 1
						blades += mm.instance_count
			for c in n.get_children():
				stack.append(c)
		print("grass_mmis=%d total_blades=%d" % [grass_mmis, blades])
	get_tree().quit(0)