extends Node3D

## Headless verification: coal_ore / coal / charcoal có model riêng (không rơi
## vào fallback grey cube) và icon gen được.

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _count_meshes(root: Node3D) -> int:
	var n := 0
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi and mi.mesh:
			n += 1
	return n

func _ready() -> void:
	print("== test_coal_models: model + icon than ==")
	ItemDatabase.ensure_db()

	# ── 1. Item data ──────────────────────────────────────────────
	var coal_ore: ItemDef = ItemDatabase.items_db.get("coal_ore") as ItemDef
	var coal: ItemDef = ItemDatabase.items_db.get("coal") as ItemDef
	var charcoal: ItemDef = ItemDatabase.items_db.get("charcoal") as ItemDef
	_check(coal_ore != null and coal_ore.type == ItemDef.Type.BLOCK, "coal_ore tồn tại, loại BLOCK")
	_check(coal != null and coal.type == ItemDef.Type.MATERIAL, "coal (Than Đá) tồn tại, loại MATERIAL")
	_check(charcoal != null and charcoal.type == ItemDef.Type.MATERIAL, "charcoal (Than Củi) tồn tại, loại MATERIAL")

	# ── 2. Model build ────────────────────────────────────────────
	var blocks := ["coal_ore", "coal", "charcoal"]
	for id in blocks:
		var root := Node3D.new()
		add_child(root)
		ItemMesh.build(root, id)
		await get_tree().process_frame
		var n := _count_meshes(root)
		_check(n > 0, "model %s dựng được (meshes=%d)" % [id, n])
		_check(n >= 6 if id != "coal_ore" else n >= 1, "model %s đủ chi tiết (meshes=%d)" % [id, n])
		root.queue_free()

	# ── 3. AABB hợp lệ cho icon camera (centered, kích thước vừa phải) ──
	for id in blocks:
		var root := Node3D.new()
		add_child(root)
		ItemMesh.build(root, id)
		await get_tree().process_frame
		var aabb := _aabb(root)
		_check(aabb != AABB(), "model %s có AABB" % id)
		if aabb != AABB():
			var m := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
			_check(m > 0.01 and m < 1.5, "model %s kích thước vừa icon (max=%.2f)" % [id, m])
		root.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

static func _aabb(root: Node3D) -> AABB:
	var aabb: AABB
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if not mi or not mi.mesh:
			continue
		var ma := mi.global_transform * mi.mesh.get_aabb()
		if first:
			aabb = ma
			first = false
		else:
			aabb = aabb.merge(ma)
	return aabb