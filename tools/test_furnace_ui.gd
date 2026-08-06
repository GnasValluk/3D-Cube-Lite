extends Node

## test_furnace_ui — Kiểm tra UI lò nung:
## 3 ô (nguyên liệu + chất đốt → thành phẩm), thanh công thức bên trái,
## nung tự động tiêu hao nguyên liệu + chất đốt → nhận sản phẩm.
## Chạy qua tools/test_furnace_ui.tscn.

const _FurnaceUI = preload("res://scripts/items/ui/furnace_ui.gd")
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
	print("== test_furnace_ui: lò nung 3 ô + thanh công thức ==")

	var cm := _CharManager.new()
	cm.name = "CharacterManager"
	var player := _PlayerChar.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	cm.add_child(player)
	add_child(cm)
	await get_tree().process_frame

	ItemDatabase.ensure_db()
	player.inventory.add_item(ItemDatabase.items_db["copper_ore"], 3)
	player.inventory.add_item(ItemDatabase.items_db["coal"], 2)

	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := _FurnaceUI.new()
	layer.add_child(ui)
	ui.open(null, player)
	await get_tree().process_frame

	_check(ui.visible, "UI hiển thị sau khi mở")
	_check(ui._recipes.size() == 8, "thanh công thức có đủ %d công thức nung" % ui._recipes.size())
	_check(ui._recipe_cards.size() == ui._recipes.size(), "mỗi công thức có 1 card")

	# Kiểm tra icon của card công thức: TextureRect phải có expand+stretch đúng
	# (gọn trong khung, không chỉ hiện góc trên-trái) — khớp chuẩn inventory.
	var card0 := ui._recipe_cards[0]
	var c0_slots := card0.get_children().filter(func(c): return c is Panel)
	_check(c0_slots.size() >= 2, "card công thức có 2 ô slot (input + output)")
	var slot_ok: bool = true
	for s in c0_slots:
		if not (s is Panel) or not s.clip_contents:
			slot_ok = false
			break
		for ch in s.get_children():
			if ch is TextureRect:
				var tr := ch as TextureRect
				if tr.position != Vector2(2, 2) or tr.size != Vector2(44, 44):
					slot_ok = false
				if tr.expand_mode != TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL:
					slot_ok = false
				if tr.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
					slot_ok = false
	_check(slot_ok, "icon slot công thức: vị trí/size/expand/stretch đúng chuẩn inventory")

	# Click công thức copper_ore → tự nạp 1 copper_ore vào ô nguyên liệu
	var copper_idx := -1
	for i in range(ui._recipes.size()):
		if ui._recipes[i].get("input", "") == "copper_ore":
			copper_idx = i
			break
	_check(copper_idx >= 0, "tìm thấy công thức copper_ore")

	ui._select_recipe(copper_idx)
	_check(ui._selected_recipe == copper_idx, "đã chọn công thức copper_ore")

	var ore_before := player.inventory.get_item_count("copper_ore")
	ui._try_fill_input(copper_idx)
	_check(player.inventory.get_item_count("copper_ore") == ore_before - 1, "click công thức → rút 1 copper_ore từ túi")
	_check(not ui._furnace_inv.slots[0].is_empty() and ui._furnace_inv.slots[0].item.id == "copper_ore",
		"ô nguyên liệu chứa copper_ore")

	# Nạp chất đốt vào ô fuel (như kéo thả / click chuyển)
	var coal_before := player.inventory.get_item_count("coal")
	ui._transfer_to_furnace(player.inventory.find_slot_of_item(ItemDatabase.items_db["coal"]), "player", 1)
	_check(player.inventory.get_item_count("coal") == coal_before - 1, "chuyển 1 coal vào lò")
	_check(not ui._furnace_inv.slots[1].is_empty() and ui._furnace_inv.slots[1].item.id == "coal",
		"ô chất đốt chứa coal")

	# Đẩy nhanh: hoàn tất 1 mẻ nung
	ui._smelt_time = 0.01
	ui._process(0.02)
	_check(ui._furnace_inv.slots[0].is_empty(), "sau 1 mẻ: nguyên liệu đã tiêu hao")
	_check(ui._furnace_inv.slots[1].is_empty(), "sau 1 mẻ: chất đốt đã tiêu hao")
	_check(not ui._furnace_inv.slots[2].is_empty() and ui._furnace_inv.slots[2].item.id == "copper_ingot",
		"sau 1 mẻ: thành phẩm copper_ingot trong ô sản phẩm")

	# Chuyển sản phẩm về túi
	var ingot_before := player.inventory.get_item_count("copper_ingot")
	ui._transfer_from_furnace(2, ui._furnace_inv.slots[2].count)
	_check(player.inventory.get_item_count("copper_ingot") == ingot_before + 1, "chuyển copper_ingot về túi")
	_check(ui._furnace_inv.slots[2].is_empty(), "ô sản phẩm trống sau khi chuyển")

	ui.close()
	for i in range(40):
		await get_tree().process_frame
	_check(not ui.visible, "UI ẩn sau khi close")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
