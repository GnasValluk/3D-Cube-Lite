extends Node3D

## test_logs — Khúc cây (log): mỗi loại cây khi chặt drop khúc cây riêng thay
## cho khối gỗ cũ. Kiểm tra: 6 item log tồn tại trong db, model build được,
## 6 cây gỗ drop đúng log + KHÔNG còn drop block gỗ.
## Chạy qua tools/test_logs.tscn (không chạy trực tiếp file .gd).

const _Oak = preload("res://scripts/world/props/oak_prop.gd")
const _Dense = preload("res://scripts/world/props/dense_tree_prop.gd")
const _Frost = preload("res://scripts/world/props/frost_tree_prop.gd")
const _Swamp = preload("res://scripts/world/props/swamp_tree_prop.gd")
const _Mangrove = preload("res://scripts/world/props/mangrove_prop.gd")
const _Palm = preload("res://scripts/world/props/palm_prop.gd")
const _ItemMesh = preload("res://scripts/items/models/router.gd")

const LOG_IDS: Array[String] = [
	"log_oak", "log_hard_wood", "log_spruce", "log_swamp", "log_mangrove", "log_palm",
]
const OLD_WOOD_IDS: Array[String] = [
	"block_oak_wood", "block_hard_wood", "spruce_wood", "swamp_wood", "mangrove_wood", "palm_wood",
]

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260818)
	ItemDatabase.ensure_db()

	# ── 1. Item log trong db ──────────────────────────────────────────────
	print("-- 1. Item khúc cây --")
	for id in LOG_IDS:
		var def: ItemDef = ItemDatabase.items_db.get(id) as ItemDef
		_check(def != null, "item %s tồn tại" % id)
		if def != null:
			_check(def.type == ItemDef.Type.MATERIAL, "%s loại MATERIAL" % id)
			_check(def.name != "", "%s có tên" % id)

	# ── 2. Model build được cho từng log ──────────────────────────────────
	print("-- 2. Model khúc cây --")
	for id in LOG_IDS:
		var host := Node3D.new()
		_ItemMesh.build(host, id)
		var found_mmi := false
		var total_instances := 0
		for ch in host.get_children():
			if ch is MultiMeshInstance3D:
				found_mmi = true
				var mm: MultiMesh = (ch as MultiMeshInstance3D).multimesh
				total_instances += mm.instance_count
		_check(found_mmi and total_instances >= 40, "%s build bộ xương thân cây voxel thật (%d voxel)" % [id, total_instances])
		host.queue_free()

	# ── 3. Drop của từng cây: log đúng loại, không còn block gỗ ───────────
	print("-- 3. Drop cây gỗ --")
	var cases: Array = [
		[_Oak.new(250, DestroyableProp.WeaponReq.AXE, "log_oak"), "log_oak"],
		[_Dense.new(200, DestroyableProp.WeaponReq.AXE, "log_hard_wood"), "log_hard_wood"],
		[_Frost.new(220, DestroyableProp.WeaponReq.AXE, "log_spruce"), "log_spruce"],
		[_Swamp.new(220, DestroyableProp.WeaponReq.AXE, "log_swamp"), "log_swamp"],
		[_Mangrove.new(220, DestroyableProp.WeaponReq.AXE, "log_mangrove"), "log_mangrove"],
		[_Palm.new(150, DestroyableProp.WeaponReq.AXE, "log_palm"), "log_palm"],
	]
	for c in cases:
		var tree: Node3D = c[0]
		var want_id: String = c[1]
		var tag: String = want_id
		tree.name = "Tree_%s" % tag
		add_child(tree)
		tree.global_position = Vector3(0, 0.5, 0)
		tree.set_birth_age_days(999.0)
		_check(tree._stage == GrowingProp.Stage.MATURE, "%s trưởng thành (để drop đủ)" % tag)
		tree.try_destroy("axe", 9999)
		_check(tree._destroyed, "%s đã chặt" % tag)
		var ids: Array[String] = []
		for ch in get_children():
			if ch is DroppedItem:
				ids.append(ch.item_def.id)
		_check(want_id in ids, "%s drop %s" % [tag, want_id])
		var has_old_wood := false
		for wid in OLD_WOOD_IDS:
			if wid in ids:
				has_old_wood = true
		_check(not has_old_wood, "%s không drop block gỗ cũ (%s)" % [tag, str(ids)])
		await get_tree().create_timer(0.6).timeout

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
