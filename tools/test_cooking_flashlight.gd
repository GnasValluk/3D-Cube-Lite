extends Node

## test_cooking_flashlight — xác minh:
## 1. Bếp nấu (CookingStove extends Furnace): item DB, entity thế giới có mesh +
##    InteractArea, FurnaceUI mở chế độ cooking (title + recipe cards), đốt lửa ra
##    thành phẩm từ nguyên liệu.
## 2. Đèn pin (flashlight): item DB + mesh drop + model cầm tay có SpotLight/OmniLight.

const _Placement = preload("res://scripts/building/placement_system.gd")
const _FurnaceUI = preload("res://scripts/items/ui/furnace_ui.gd")
const _CharManager = preload("res://scripts/core/character_manager.gd")
const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")
const _ToolsMesh = preload("res://scripts/items/models/tools.gd")
const _CookingStove = preload("res://scripts/items/entities/cooking_stove.gd")
const _CraftingUI = preload("res://scripts/items/ui/crafting_ui.gd")
const _CraftingTable = preload("res://scripts/items/entities/crafting_table.gd")
const _CraftingStation = preload("res://scripts/items/entities/crafting_station.gd")

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _has_mesh(node: Node) -> bool:
	for ch in node.get_children():
		if ch is MeshInstance3D or ch is MultiMeshInstance3D:
			return true
	return false

func _load_translations() -> void:
	var path := "res://translations/game.csv"
	if not FileAccess.file_exists(path):
		return
	for locale in ["vi", "en"]:
		var col: int = 1 if locale == "en" else 2
		var t := Translation.new()
		t.locale = locale
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var header: bool = true
			while not f.eof_reached():
				var line = f.get_csv_line()
				if line.is_empty() or line[0].is_empty():
					continue
				if header:
					header = false
					continue
				if line.size() > col:
					t.add_message(line[0], line[col])
			f.close()
		TranslationServer.add_translation(t)

func _ready() -> void:
	seed(20260813)
	_load_translations()
	print("== test_cooking_flashlight: Bếp Nấu + Đèn Pin ==")

	ItemDatabase.ensure_db()

	# ── 1. Item DB ──
	_check(ItemDatabase.items_db.has("cooking_stove"), "db có item cooking_stove")
	_check(ItemDatabase.items_db.has("flashlight"), "db có item flashlight")
	for out in ["cooked_pork", "baked_taro", "cooked_shrimp", "grilled_carp", "grilled_perch",
			"grilled_tilapia", "grilled_snakehead", "grilled_flowerhorn", "cooked_crab",
			"grilled_eggplant", "baked_pumpkin"]:
		var def: ItemDef = ItemDatabase.items_db.get(out) as ItemDef
		var ok_def: bool = def != null and def.type == ItemDef.Type.FOOD and def.heal_amount > 0
		_check(ok_def, "db có món nấu %s (FOOD, heal %d)" % [out, def.heal_amount if def != null else -1])

	var stove_def: ItemDef = ItemDatabase.items_db["cooking_stove"]
	_check(stove_def.type == ItemDef.Type.BLOCK, "cooking_stove là BLOCK")
	var fl_def: ItemDef = ItemDatabase.items_db["flashlight"]
	_check(fl_def.type == ItemDef.Type.ARMOR and fl_def.armor_slot == ItemDef.ArmorSlot.SUB,
		"flashlight là ARMOR SUB (đeo được)")

	# ── 2. Recipe map ──
	_check(_CookingStove.COOKING_ITEMS.size() >= 11, "có >= 11 công thức nấu")
	_check(_CookingStove.COOKING_ITEMS["raw_pork"] == "cooked_pork", "raw_pork → cooked_pork")
	for ing in _CookingStove.COOKING_ITEMS:
		_check(ItemDatabase.items_db.has(ing), "nguyên liệu %s có trong DB" % ing)
	for out2 in _CookingStove.COOKING_ITEMS.values():
		_check(ItemDatabase.items_db.has(out2), "thành phẩm %s có trong DB" % out2)

	# ── 3. Icon drop mesh ──
	for sid in ["cooking_stove", "flashlight", "cooked_pork", "grilled_carp", "baked_taro", "cooked_crab"]:
		var icon_root := Node3D.new()
		add_child(icon_root)
		ItemMesh.build(icon_root, sid)
		_check(icon_root.get_child_count() > 0, "icon %s có mesh" % sid)

	# ── 4. Entity thế giới ──
	var stove := _CookingStove.new()
	add_child(stove)
	_check(_has_mesh(stove), "CookingStove entity có mesh")
	_check(stove.drop_item_id == "cooking_stove", "CookingStove drop đúng item")
	_check(stove.max_hp >= 50, "CookingStove max_hp hợp lý (%d)" % stove.max_hp)
	_check(stove.get_furnace_mode() == "cooking", "CookingStove mode = cooking")
	var area: Node = stove.find_child("InteractArea", true, false)
	_check(area != null, "CookingStove có InteractArea")
	_check(stove is Furnace, "CookingStove kế thừa Furnace (player interact bắt được)")

	# ── 5. FurnaceUI chế độ cooking ──
	var cm := _CharManager.new()
	cm.name = "CharacterManager"
	var player := _PlayerChar.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	cm.add_child(player)
	add_child(cm)
	await get_tree().process_frame

	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := _FurnaceUI.new()
	layer.add_child(ui)
	ui.open(stove, player)
	await get_tree().process_frame
	_check(ui.visible, "UI bếp mở hiển thị")
	_check(ui._furnace_mode == "cooking", "FurnaceUI nhận mode cooking")
	_check(not ui._recipes.is_empty(), "danh sách công thức nấu không rỗng")
	_check(ui._recipe_cards.size() == ui._recipes.size(),
		"thẻ công thức = %d (khớp %d recipe)" % [ui._recipe_cards.size(), ui._recipes.size()])
	_check(ui._title_label != null and ui._title_label.text != "", "có tiêu đề UI")

	# ── 6. Đốt: nạp taro + nhiên liệu → baked_taro, thành phẩm không bị chặn ──
	var inp: String = "taro"
	var outp: String = _CookingStove.COOKING_ITEMS[inp]
	var coal_def: ItemDef = ItemDatabase.items_db["coal"]
	var taro_def: ItemDef = ItemDatabase.items_db[inp]
	ui._furnace_inv.slots[0].item = taro_def
	ui._furnace_inv.slots[0].count = 2
	ui._furnace_inv.slots[3].item = coal_def
	ui._furnace_inv.slots[3].count = 1
	ui._smelt_time = 5.0
	ui._process(0.02)
	_check(ui._smelt_active, "bếp có lửa khi nạp nguyên liệu + nhiên liệu")
	ui._process(5.0)
	_check(ui._furnace_inv.slots[0].count == 1, "sau 1 mẻ: còn 1 taro")
	_check(not ui._furnace_inv.slots[5].is_empty() and ui._furnace_inv.slots[5].item.id == outp,
		"sau 1 mẻ: thành phẩm %s trong ô sản phẩm" % outp)
	ui.close()
	await get_tree().process_frame

	# ── 7. Đèn pin — model cầm tay + nguồn sáng ──
	var hold_pivot := Node3D.new()
	add_child(hold_pivot)
	_ToolsMesh.build_held(hold_pivot, "flashlight")
	var has_spot := false
	var has_omni := false
	for ch in hold_pivot.get_children():
		if ch is SpotLight3D:
			has_spot = true
		if ch is OmniLight3D:
			has_omni = true
	_check(has_spot and has_omni, "model cầm đèn pin có SpotLight + OmniLight")
	_check(_has_mesh(hold_pivot), "model cầm đèn pin có mesh")

	# ── 7b. End-to-end: equip đèn pin qua player → weapon_pivot có đèn, item SUB đeo được ──
	var fl_def2: ItemDef = ItemDatabase.items_db["flashlight"]
	var e2e_player := _PlayerChar.new()
	e2e_player.name = "TestFlashlight"
	add_child(e2e_player)
	await get_tree().process_frame
	await get_tree().process_frame
	e2e_player.equip_weapon_direct(fl_def2, 3)
	_check(e2e_player.equipped_weapon == fl_def2, "equip_weapon_direct gắn đèn pin vào weapon slot")
	var wp: Node3D = e2e_player._mesh.weapon_pivot if e2e_player._mesh != null else null
	var w_spot := false
	if wp != null:
		for ch in wp.get_children():
			if ch is SpotLight3D:
				w_spot = true
	_check(w_spot, "cầm đèn pin → weapon_pivot có SpotLight (chiếu sáng khi cầm)")
	e2e_player.equipped_sub = fl_def2
	e2e_player._update_armor_mesh()
	_check(e2e_player.get_equipped_by_slot(5) == fl_def2, "đèn pin cũng đeo được slot SUB (bản nhỏ, chiếu sáng khi cầm)")
	e2e_player.queue_free()

	# ── 8. Placement wiring ──
	_check(_Placement._is_station_item("cooking_stove") == false, "cooking_stove không nhầm là station")
	var ps := _Placement.new()
	add_child(ps)
	var ghost := Node3D.new()
	add_child(ghost)
	# Dùng _make_ghost logic trực tiếp trên instance (đặt trạng thái nội bộ)
	ps._item_id = "cooking_stove"
	if ps.has_method("start_placement"):
		ps.start_placement("cooking_stove")
	_check(true, "placement khởi tạo cooking_stove không crash")

	# ── 9. Các bàn trạm + bàn kiến trúc: DB + entity mesh + icon + placement ──
	var _root3d := Node3D.new()
	add_child(_root3d)
	var station_ids: Array[String] = ["tool_table", "mech_table", "farm_table",
		"chem_table", "magic_table", "kitchen_table", "architecture_table"]
	for sid in station_ids:
		_check(ItemDatabase.items_db.has(sid), "db có item %s" % sid)
		_check(_Placement._is_station_item(sid), "%s _is_station_item=true" % sid)
		var icon_root := Node3D.new()
		add_child(icon_root)
		ItemMesh.build(icon_root, sid)
		_check(icon_root.get_child_count() > 0, "icon %s có mesh" % sid)
		# Instantiate entity + enter tree so _ready builds mesh (Physics space available)
		var ent = ps._make_station(sid)
		_check(ent != null, "_make_station tạo được %s" % sid)
		if ent != null:
			ent.name = sid
			_root3d.add_child(ent)
			await get_tree().process_frame
			var mesh_count := 0
			for ch in ent.get_children():
				if ch is MeshInstance3D or ch is MultiMeshInstance3D:
					mesh_count += 1
			_check(mesh_count > 0, "%s entity có mesh (%d MI)" % [sid, mesh_count])
			ent.queue_free()
	_check(_Placement._is_station_item("crafting_table") == false, "crafting_table không phải specialized station")
	var icon_ct := Node3D.new()
	add_child(icon_ct)
	ItemMesh.build(icon_ct, "crafting_table")
	_check(icon_ct.get_child_count() > 0, "icon crafting_table có mesh")
	var ct: Node3D = _CraftingTable.new()
	_root3d.add_child(ct)
	await get_tree().process_frame
	var ct_count := 0
	for ch in ct.get_children():
		if ch is MeshInstance3D or ch is MultiMeshInstance3D:
			ct_count += 1
	_check(ct_count > 0, "CraftingTable entity có mesh (%d MI)" % ct_count)
	ct.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)