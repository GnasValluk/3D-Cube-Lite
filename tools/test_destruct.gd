extends Node3D

## test_destruct — Vật đặt được (rương, bàn chế tạo, lò nung, thuyền, cổng)
## có máu như cây: đòn heavy (rìu/cúp/cuốc/đại kiếm) phá được; khi vỡ rớt lại
## vật phẩm; rương đổ toàn bộ đồ bên trong ra ngoài; thuyền đá tài xế ra.
## Chạy qua tools/test_destruct.tscn (không chạy trực tiếp file .gd).

const _Chest = preload("res://scripts/items/entities/chest.gd")
const _Table = preload("res://scripts/items/entities/crafting_table.gd")
const _Furnace = preload("res://scripts/items/entities/furnace.gd")
const _Boat = preload("res://scripts/items/entities/fishing_boat.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _wait_physics(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame

func _wait_seconds(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _count_drops() -> int:
	var n := 0
	for ch in get_children():
		if ch is DroppedItem:
			n += 1
	return n

func _drop_ids() -> Array[String]:
	var ids: Array[String] = []
	for ch in get_children():
		if ch is DroppedItem:
			ids.append(ch.item_def.id)
	return ids

## Bắn heavy tới khi vỡ, trả số đòn cần thiết.
func _break_with(host: Node, weapon_id: String, dmg: int) -> int:
	var hits: int = 0
	while not host._destroyed and hits < 50:
		if not host.try_destroy(weapon_id, dmg):
			break
		hits += 1
	return hits

func _ready() -> void:
	seed(20260806)
	print("== test_destruct: phá huỷ vật đặt được ==")

	ItemDatabase.ensure_db()
	var chest_def: ItemDef = ItemDatabase.items_db.get("chest") as ItemDef
	var table_def: ItemDef = ItemDatabase.items_db.get("crafting_table") as ItemDef
	var furnace_def: ItemDef = ItemDatabase.items_db.get("furnace") as ItemDef
	var boat_def: ItemDef = ItemDatabase.items_db.get("fishing_boat") as ItemDef
	_check(chest_def != null and table_def != null and furnace_def != null and boat_def != null,
		"4 item rơi khi phá đều tồn tại trong db")

	# ── 1. Rương: kiếm không phá được, rìu phá, đổ đồ ra ngoài ─────────────
	print("-- 1. Rương --")
	var chest = _Chest.new()
	chest.name = "TestChest"
	add_child(chest)
	chest.global_position = Vector3(0, 0.5, 0)
	var wood: ItemDef = ItemDatabase.items_db.get("palm_wood") as ItemDef
	var coco: ItemDef = ItemDatabase.items_db.get("coconut") as ItemDef
	var iron: ItemDef = ItemDatabase.items_db.get("iron_ingot") as ItemDef
	chest.inventory.add_item(wood, 5)
	chest.inventory.add_item(coco, 2)
	chest.inventory.add_item(iron, 1)
	_check(chest.max_hp == 60, "rương máu 60 (max_hp=%s)" % str(chest.max_hp))
	_check(chest.hp == 60, "rương đầy máu sau _ready")
	_check(chest.is_in_group("destroyable_props"), "rương vào nhóm destroyable_props")
	_check(not chest.try_destroy("iron_sword", 999), "kiếm (không heavy) không phá được rương")
	_check(chest.hp == 60, "kiếm đánh không giảm máu rương")
	_check(chest.try_destroy("axe", 8), "rìu gây sát thương (8)")
	_check(chest.hp == 52, "rương còn máu 52 sau 1 đòn rìu")
	_check(chest.try_destroy("hoe", 8) or chest.hp == 44, "cuốc (heavy) cũng đánh được")
	var axe_hits: int = _break_with(chest, "axe", 8)
	_check(chest._destroyed, "rương bị phá sau %s đòn rìu" % str(axe_hits))
	_check(not chest.try_destroy("axe", 8), "rương đã vỡ → không nhận thêm đòn")
	await _wait_seconds(0.6)
	var drop_ids: Array[String] = _drop_ids()
	_check(_count_drops() == 4, "4 vật rớt ra (rương + 3 ô đồ), được %s" % str(_count_drops()))
	_check("chest" in drop_ids, "rơi lại vật phẩm chest")
	_check("palm_wood" in drop_ids and "coconut" in drop_ids and "iron_ingot" in drop_ids,
		"toàn bộ đồ trong rương đổ ra ngoài")

	# ── 2. Bàn chế tạo: pickaxe phá ────────────────────────────────────────
	print("-- 2. Bàn chế tạo --")
	var table = _Table.new()
	table.name = "TestTable"
	add_child(table)
	table.global_position = Vector3(4, 0.5, 0)
	_check(table.max_hp == 60, "bàn máu 60")
	_check(table.is_in_group("destroyable_props"), "bàn vào nhóm destroyable_props")
	_check(not table.try_destroy("iron_sword", 999), "kiếm không phá được bàn")
	var table_hits: int = _break_with(table, "pickaxe", 3)
	_check(table._destroyed, "bàn bị phá bởi cúp (heavy) sau %s đòn" % str(table_hits))
	await _wait_seconds(0.6)
	_check("crafting_table" in _drop_ids(), "bàn vỡ rơi lại item crafting_table")

	# ── 3. Lò nung: hoe phá ─────────────────────────────────────────────────
	print("-- 3. Lò nung --")
	var furnace = _Furnace.new()
	furnace.name = "TestFurnace"
	add_child(furnace)
	furnace.global_position = Vector3(8, 0.5, 0)
	_check(furnace.max_hp == 100, "lò máu 100")
	_check(furnace.is_in_group("destroyable_props"), "lò vào nhóm destroyable_props")
	var furnace_hits: int = _break_with(furnace, "hoe", 2)
	_check(furnace._destroyed, "lò bị phá bởi cuốc (heavy) sau %s đòn" % str(furnace_hits))
	await _wait_seconds(0.6)
	_check("furnace" in _drop_ids(), "lò vỡ rơi lại item furnace")

	# ── 4. Thuyền: đá tài xế ra khi vỡ + rơi lại thuyền ────────────────────
	print("-- 4. Thuyền --")
	var boat = _Boat.new()
	boat.name = "TestBoat"
	add_child(boat)
	boat.global_position = Vector3(12, 0.5, 0)
	_check(boat.max_hp == 120, "thuyền máu 120")
	_check(boat.hp == 120, "thuyền đầy máu sau _ready")
	_check(boat.is_in_group("destroyable_props"), "thuyền vào nhóm destroyable_props")
	_check(not boat.try_destroy("iron_sword", 999), "kiếm không phá được thuyền")
	_check(boat.try_destroy("axe", 8) and boat.hp == 112, "rìu gây sát thương cho thuyền")
	var dscript := GDScript.new()
	dscript.source_code = "extends CharacterBody3D\nvar _is_player := true\n"
	dscript.reload()
	var driver := CharacterBody3D.new()
	driver.name = "DriverStub"
	driver.set_script(dscript)
	var dshape := CollisionShape3D.new()
	dshape.name = "CollisionShape3D"
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(0.6, 1.8, 0.6)
	dshape.shape = dbox
	driver.add_child(dshape)
	add_child(driver)
	driver.global_position = boat.global_position + Vector3(1.0, 0.5, 0)
	_check(boat.try_board(driver), "lên thuyền trước khi phá")
	var boat_hits: int = _break_with(boat, "axe", 8)
	_check(boat._destroyed, "thuyền bị phá sau %s đòn rìu" % str(boat_hits))
	_check(boat._driver == null, "thuyền vỡ → tài xế bị đá ra")
	_check(not driver.has_meta("driving_boat"), "tài xế nhả khóa điều khiển (meta bị xóa)")
	await _wait_seconds(0.6)
	_check("fishing_boat" in _drop_ids(), "thuyền vỡ rơi lại item fishing_boat")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
