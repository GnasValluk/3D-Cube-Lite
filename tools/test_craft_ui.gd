extends Node

## test_craft_ui — Kiểm tra UI chế tạo kiểu lưới (Minecraft):
## lưới 2x2 cầm tay / 3x3 bàn chế tạo, ô kết quả khớp theo hình dạng,
## nút chế tạo tiêu hao nguyên liệu → nhận sản phẩm. Công thức gốc đã bị xoá
## (danh sách trống) — test lưới bằng công thức mẫu chèn tạm vào RecipeDatabase.

const _CraftingUI = preload("res://scripts/items/ui/crafting_ui.gd")
const _RecipeDB = preload("res://scripts/items/core/recipe_database.gd")
const _CharManager = preload("res://scripts/core/character_manager.gd")
const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

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
	_load_translations()
	print("== test_craft_ui: bàn chế tạo kiểu lưới ==")

	ItemDatabase.ensure_db()
	# Công thức gốc đã bị xoá → danh sách phải trống.
	_RecipeDB.ensure()
	_check(_RecipeDB.recipes.is_empty(), "toàn bộ công thức chế tạo đã bị xoá (còn %d)" % _RecipeDB.recipes.size())

	# Chèn công thức mẫu (2x2: 2 gỗ dừa → thuyền) để test lưới.
	_RecipeDB.recipes.append({
		"id": "test_stick",
		"name": "Test Stick",
		"result": "fishing_rod",
		"count": 1,
		"grid_size": 2,
		"pattern": [["palm_wood", "palm_wood"], ["", ""]],
		"ingredients": { "palm_wood": 2 },
	})

	var cm := _CharManager.new()
	cm.name = "CharacterManager"
	var player := _PlayerChar.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	cm.add_child(player)
	add_child(cm)
	await get_tree().process_frame

	player.inventory.add_item(ItemDatabase.items_db["palm_wood"], 3)

	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := _CraftingUI.new()
	layer.add_child(ui)
	ui.open(player, 2)
	await get_tree().process_frame

	_check(ui.visible, "UI hiển thị sau khi mở")
	_check(ui._grid_size == 2, "lưới cầm tay 2x2")
	_check(ui._craft_inv.slots.size() == 4, "lưới 2x2 có 4 ô")
	_check(ui._recipe_cards.size() == 1, "danh sách hiển thị recipe mẫu")

	# Đặt nguyên liệu vào lưới theo pattern → ô kết quả khớp
	ui._transfer_to_grid(player.inventory.find_slot_of_item(ItemDatabase.items_db["palm_wood"]), "player", 2)
	await get_tree().process_frame
	ui._process(0.01)
	var matched := ui._matched()
	_check(matched.get("id", "") == "test_stick", "lưới đúng hình dạng → khớp recipe mẫu")
	_check(not ui._craft_btn.disabled, "nút chế tạo bật khi lưới khớp recipe")
	_check(not ui._output_icon.visible or ui._output_icon.texture != null, "ô kết quả có icon")

	# Chế tạo → lưới tiêu 2 gỗ (gỗ trong túi không đổi, vì đã chuyển sang lưới)
	var wood_before := player.inventory.get_item_count("palm_wood")
	var rod_before := player.inventory.get_item_count("fishing_rod")
	ui._craft()
	_check(player.inventory.get_item_count("palm_wood") == wood_before, "lưới tiêu 2 palm_wood (túi giữ nguyên)")
	_check(player.inventory.get_item_count("fishing_rod") == rod_before + 1, "nhận +1 fishing_rod")
	_check(ui._craft_inv.is_empty(), "lưới rỗng sau khi chế tạo")

	# Bàn chế tạo → lưới 3x3
	ui._player_ref = player
	ui.open(player, 3)
	await get_tree().process_frame
	_check(ui._grid_size == 3, "bàn chế tạo → lưới 3x3")
	_check(ui._craft_inv.slots.size() == 9, "lưới 3x3 có 9 ô")

	# Đóng → trả đồ trong lưới về túi
	_RecipeDB.recipes.clear()
	player.inventory.add_item(ItemDatabase.items_db["palm_wood"], 2)
	ui._transfer_to_grid(player.inventory.find_slot_of_item(ItemDatabase.items_db["palm_wood"]), "player", 2)
	var wb2 := player.inventory.get_item_count("palm_wood")
	ui.close()
	for i in range(40):
		await get_tree().process_frame
	_check(not ui.visible, "UI ẩn sau khi close")
	_check(player.inventory.get_item_count("palm_wood") == wb2 + 2, "đóng UI → đồ trong lưới trả về túi")

	_RecipeDB.recipes.clear()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)