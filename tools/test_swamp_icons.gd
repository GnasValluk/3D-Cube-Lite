extends Node

## Headless verification: 8 item đầm lầy/ngập mặn có model 3D (ItemMesh.build)
## để icon + drop không còn rơi vào FallbackMesh.

const _IM = preload("res://scripts/items/models/router.gd")

var _failures: int = 0

var _items := [
	"duckweed", "mangrove_seed", "mangrove_wood", "mud_crab",
	"spruce_wood", "swamp_sedge", "swamp_seed", "swamp_wood",
]

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	for item_id in _items:
		var pivot := Node3D.new()
		add_child(pivot)
		_IM.build(pivot, item_id)
		_check(pivot.get_child_count() > 0, "%s → tạo mesh (%d child)" % [item_id, pivot.get_child_count()])
		var has_mesh := false
		for ch in pivot.get_children():
			if ch is MeshInstance3D:
				has_mesh = true
				break
		_check(has_mesh, "%s → có MeshInstance3D" % item_id)
		pivot.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)