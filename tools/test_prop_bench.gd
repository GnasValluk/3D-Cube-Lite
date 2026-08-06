extends Node

## Headless benchmark: đo thời gian build + số MultiMesh instance của từng
## loại cây blob (oak, dense, orange, palm). Chạy qua tools/test_prop_bench.tscn.

const _Oak = preload("res://scripts/world/props/oak_prop.gd")
const _Dense = preload("res://scripts/world/props/dense_tree_prop.gd")
const _Orange = preload("res://scripts/world/props/orange_tree_prop.gd")
const _Palm = preload("res://scripts/world/props/palm_prop.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _mm_instances(n: Node) -> int:
	var total := 0
	for ch in n.get_children():
		if ch is MultiMeshInstance3D:
			var mmi := ch as MultiMeshInstance3D
			if mmi.multimesh != null:
				total += mmi.multimesh.instance_count
		total += _mm_instances(ch)
	return total

func _bench(script: GDScript, variant: String, n: int) -> void:
	var worst := 0.0
	var total := 0.0
	var max_inst := 0
	var build_ms := 0.0
	var commit_ms := 0.0
	for i in range(n):
		var p := script.new() as Node
		p.setup(variant)
		p.position = Vector3(i * 20.0, 0.0, 0.0)
		var t0 := Time.get_ticks_usec()
		add_child(p)
		var t1 := Time.get_ticks_usec()
		build_ms += (t1 - t0) * 0.001
		var dt := (t1 - t0) * 0.001
		total += dt
		worst = maxf(worst, dt)
		commit_ms += 0.0
		max_inst = maxi(max_inst, _mm_instances(p))
		p.queue_free()
	await get_tree().process_frame
	var avg := total / float(n)
	print("  %s: avg=%.1fms worst=%.1fms max_inst=%d" % [script.resource_path.get_file(), avg, worst, max_inst])

func _ready() -> void:
	seed(20260805)
	ItemDatabase.ensure_db()

	print("── PROP BUILD BENCH ──")
	await _bench(_Oak, "plains", 8)
	await _bench(_Dense, "plains", 8)
	await _bench(_Orange, "plains", 8)
	await _bench(_Palm, "river", 8)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)