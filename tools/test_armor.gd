extends Node

## Headless verification: bộ giáp sắt + nhẫn vàng + ba lô da thú.
## - Giáp: nón HEAD +1.5 giáp +1 kháng crit, giáp BODY +4.5 (găng sắt đã hợp vào), giày FEET +1.
## - Nhẫn vàng SUB: +2 May mắn (chỉ số ẩn).
## - Ba lô da thú BACK: +4 slot kho đồ, +5% giới hạn tải.
## Chạy qua tools/test_armor.tscn (không chạy trực tiếp file .gd).

const _PlayerChar := preload("res://scripts/characters/player/player_character.gd")
const _Inv := preload("res://scripts/items/core/inventory.gd")
const _ItemDef := preload("res://scripts/items/core/item_def.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260810)
	ItemDatabase.ensure_db()
	var db := ItemDatabase.items_db

	# ── 1. ItemDef có các bonus mới ───────────────────────────────────────
	print("-- 1. Ban trang bị mới trong ItemDatabase --")
	var helm: ItemDef = db["iron_helmet"] as ItemDef
	var plate: ItemDef = db["iron_chestplate"] as ItemDef
	var boots: ItemDef = db["iron_boots"] as ItemDef
	var ring: ItemDef = db["golden_ring"] as ItemDef
	var pack: ItemDef = db["leather_backpack"] as ItemDef

	_check(helm.type == ItemDef.Type.ARMOR and helm.armor_slot == _ItemDef.ArmorSlot.HEAD, "iron_helmet → ARMOR/HEAD")
	_check(absf(helm.def_bonus - 1.5) < 0.0001, "nón sắt giáp 1.5 (float)")
	_check(absf(helm.crit_resist_bonus - 1.0) < 0.0001, "nón sắt kháng crit 1.0")

	_check(plate.armor_slot == _ItemDef.ArmorSlot.BODY, "giáp sắt → BODY")
	_check(absf(plate.def_bonus - 4.5) < 0.0001, "giáp sắt giáp 4.5 (đã gộp găng tay)")
	_check(db.get("iron_gauntlets", null) == null, "iron_gauntlets đã bị xóa")
	_check(absf(boots.def_bonus - 1.0) < 0.0001, "giày sắt giáp 1.0")

	_check(ring.armor_slot == _ItemDef.ArmorSlot.SUB, "nhẫn vàng → SUB")
	_check(absf(ring.luck_bonus - 2.0) < 0.0001, "nhẫn vàng +2 may mắn")

	_check(pack.armor_slot == _ItemDef.ArmorSlot.BACK, "ba lô da thú → BACK")
	_check(pack.inv_slots_bonus == 4, "ba lô +4 slot kho")
	_check(absf(pack.weight_multiplier - 1.05) < 0.0001, "ba lô x1.05 giới hạn tải")

	var name_probe := ItemDef.new("t2", "T2", ItemDef.Type.ARMOR, Color.WHITE, "A")
	name_probe.armor_slot = _ItemDef.ArmorSlot.BACK
	_check(name_probe.get_armor_slot_name() != "", "tên slot BACK")
	name_probe.armor_slot = _ItemDef.ArmorSlot.SUB
	_check(name_probe.get_armor_slot_name() != "", "tên slot SUB")

	# ── 2. Tổng giáp / kháng crit / may mắn trên nhân vật ─────────────────
	print("-- 2. Nhân vật: giáp, kháng crit, may mắn --")
	var pc := _PlayerChar.new()
	pc.name = "TestArmor"
	pc.defense = 2
	pc.luck = 0.5
	pc.max_weight = 100.0
	add_child(pc)
	await get_tree().process_frame
	await get_tree().process_frame

	# Chênh lệch delta — tránh phụ thuộc giá trị gốc bị _ready thiết lập lại
	var def0 := pc.get_total_def()
	var luck0 := pc.get_total_luck()

	# Equip nón + giày
	var ids := ["iron_helmet", "iron_boots"]
	for id in ids:
		pc.inventory.add_item(db[id], 1)
		var idx: int = pc.inventory.find_slot_of_item(db[id])
		pc.inventory.slots[idx].item = db[id]
		pc.use_item_from_inventory(idx)
	_check(absf((pc.get_total_def() - def0) - (1.5 + 1.0)) < 0.0001,
		"mang nón+giày → giáp +2.5")
	_check(absf(pc.get_total_crit_resist() - 1.0) < 0.0001, "nón sắt → kháng crit 1.0")

	pc.inventory.add_item(db["iron_chestplate"], 1)
	var ci: int = pc.inventory.find_slot_of_item(db["iron_chestplate"])
	pc.use_item_from_inventory(ci)
	_check(absf((pc.get_total_def() - def0) - (1.5 + 1.0 + 4.5)) < 0.0001,
		"mang cả giáp → giáp +7.0")

	# Nhẫn vàng → may mắn +2
	pc.inventory.add_item(db["golden_ring"], 1)
	var ri: int = pc.inventory.find_slot_of_item(db["golden_ring"])
	pc.use_item_from_inventory(ri)
	_check(absf((pc.get_total_luck() - luck0) - 2.0) < 0.0001, "nhẫn vàng → may mắn +2.0")

	# ── 3. Ba lô: +4 slot kho & x1.05 giới hạn tải ────────────────────────
	print("-- 3. Ba lô da thú --")
	var before: int = pc.inventory.slots.size()
	_check(before == _Inv.DEFAULT_SIZE, "kho mặc định %d slot (có %d)" % [_Inv.DEFAULT_SIZE, before])
	_check(absf(pc.get_max_weight() - 100.0) < 0.0001, "không ba lô → giới hạn 100")

	pc.inventory.add_item(pack, 1)
	var pi: int = pc.inventory.find_slot_of_item(pack)
	pc.use_item_from_inventory(pi)
	_check(pc.equipped_back == pack, "đã mặc ba lô")
	var _pack_shell: Node3D = null
	if pc._mesh != null and pc._mesh.back_gear_pivot != null:
		for ch in pc._mesh.back_gear_pivot.get_children():
			_pack_shell = ch as Node3D
			break
	_check(_pack_shell != null and absf(_pack_shell.rotation.y - PI) < 0.001,
		"ba lô đeo lưng đã xoay 180° quanh Y (mặt trang trí hướng ra sau)")
	_check(pc.inventory.slots.size() == _Inv.DEFAULT_SIZE + 4,
		"mặc ba lô → kho %d slot (có %d)" % [_Inv.DEFAULT_SIZE + 4, pc.inventory.slots.size()])
	_check(absf(pc.get_max_weight() - 105.0) < 0.0001, "ba lô → giới hạn tải 105")

	# Tháo ba lô (qua death chest path) → kho thu về 36
	pc.equipped_back = null
	pc._refresh_backpack_state()
	_check(pc.inventory.slots.size() == _Inv.DEFAULT_SIZE, "tháo ba lô → kho về %d" % _Inv.DEFAULT_SIZE)

	# ── 4. resize_slots thu hẹp giữ đồ ────────────────────────────────────
	print("-- 4. Inventory.resize_slots: thu hẹp không mất đồ --")
	var inv := _Inv.new()
	inv.resize_slots(_Inv.DEFAULT_SIZE + 4)
	_check(inv.slots.size() == _Inv.DEFAULT_SIZE + 4, "mở rộng → %d slot" % (_Inv.DEFAULT_SIZE + 4))
	inv.add_item(db["iron_helmet"], 1)
	inv.add_item(ItemDef.new("t1", "T1", ItemDef.Type.BLOCK, Color.WHITE, "T"), 1)
	inv.resize_slots(_Inv.DEFAULT_SIZE)
	_check(inv.slots.size() == _Inv.DEFAULT_SIZE, "thu hẹp → về %d slot" % _Inv.DEFAULT_SIZE)
	var kept: int = 0
	for s in inv.slots:
		if not s.is_empty():
			kept += 1
	_check(kept == 2, "2 món đồ vẫn giữ sau khi thu hẹp khô")
	pc.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)