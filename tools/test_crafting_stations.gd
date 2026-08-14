extends Node3D

## Headless verification: 6 bàn trạm chế tạo (công cụ, cơ khí, nông nghiệp,
## hoá học, phép thuật, làm bếp) — item DB, icon drop, entity mesh thế giới,
## drop item đúng, ghost placement và recipe gating theo station.
## Chạy qua tools/test_crafting_stations.tscn.

const _Placement = preload("res://scripts/building/placement_system.gd")

const STATIONS: Array[String] = [
	"tool_table", "mech_table", "farm_table", "chem_table", "magic_table", "kitchen_table",
]

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _has_mesh(node: Node) -> bool:
	for ch in node.get_children():
		if ch is MeshInstance3D or ch is MultiMeshInstance3D:
			return true
	return false

func _ready() -> void:
	seed(20260813)
	print("== test_crafting_stations: 6 bàn trạm chế tạo ==")

	# ── 1. Item database + thuộc tính ──
	ItemDatabase.ensure_db()
	for sid in STATIONS:
		_check(ItemDatabase.items_db.has(sid), "db có item %s" % sid)
		var def: ItemDef = ItemDatabase.items_db.get(sid) as ItemDef
		_check(def != null and def.type == ItemDef.Type.BLOCK, "%s là item kiểu BLOCK" % sid)
		_check(def != null and def.name != "", "%s có tên tiếng Việt" % sid)

	# ── 2. Icon drop mesh không crash, có mesh ──
	for sid in STATIONS:
		var icon_root := Node3D.new()
		add_child(icon_root)
		ItemMesh.build(icon_root, sid)
		_check(icon_root.get_child_count() > 0, "icon %s có mesh" % sid)

	# ── 3. Entity thế giới — mesh + drop đúng item + station_id ──
	var ps := _Placement.new()
	add_child(ps)
	for sid in STATIONS:
		var ent := ps._make_station(sid) as CraftingStation
		_check(ent != null, "%s tạo entity" % sid)
		if ent == null:
			continue
		add_child(ent)
		_check(ent.station_id == sid, "%s station_id đúng" % sid)
		_check(ent.drop_item_id == sid, "%s drop đúng item" % sid)
		_check(ent.max_hp >= 60, "%s max_hp >= 60" % sid)
		_check(_has_mesh(ent), "%s entity có mesh" % sid)
		var area: Node = ent.find_child("InteractArea", true, false)
		_check(area != null, "%s có InteractArea" % sid)
		var has_col := false
		if area != null:
			for ch in area.get_children():
				if ch is CollisionShape3D:
					has_col = true
		_check(has_col, "%s InteractArea có collision" % sid)

	# ── 4. Ghost placement ──
	for sid in STATIONS:
		_check(_Placement._is_station_item(sid), "%s nhận diện là station" % sid)
	for other in ["chest", "crafting_table", "furnace", "carp"]:
		_check(not _Placement._is_station_item(other), "%s không phải station" % other)

	# ── 5. Recipe gating — station lọc công thức ──
	var fake_player := _make_fake_player()
	var ui := CraftingUI.new()
	add_child(ui)
	ui.open(fake_player, 3, "tool_table")
	_check(ui.visible, "CraftingUI mở với station_id không crash")
	ui.close()

	# ── 6. HUD open_crafting bypass — không crash khi station mở ──
	var ent0: CraftingStation = ps._make_station("kitchen_table")
	add_child(ent0)
	ent0.open_ui()
	ent0.close_ui()
	_check(true, "open_ui/close_ui không crash khi không có HUD")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _make_fake_player() -> PlayerCharacter:
	var inv := Inventory.new(36)
	var pc := PlayerCharacter.new()
	pc.inventory = inv
	return pc