extends Node

## test_craft_ui — Kiểm tra UI bàn chế tạo kiểu danh sách:
## đủ nguyên liệu mới chọn được, preview, nút chế tạo tiêu hao vật phẩm → nhận sản phẩm.
## Chạy qua tools/test_craft_ui.tscn.

const _CraftingUI = preload("res://scripts/items/ui/crafting_ui.gd")
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
	print("== test_craft_ui: bàn chế tạo kiểu danh sách ==")

	var cm := _CharManager.new()
	cm.name = "CharacterManager"
	var player := _PlayerChar.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	cm.add_child(player)
	add_child(cm)
	await get_tree().process_frame

	# Cung cấp nguyên liệu đúng bằng 1 mẻ (2 iron + 1 palm)
	ItemDatabase.ensure_db()
	player.inventory.add_item(ItemDatabase.items_db["iron_ingot"], 2)
	player.inventory.add_item(ItemDatabase.items_db["palm_wood"], 1)

	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := _CraftingUI.new()
	layer.add_child(ui)
	ui.open(player)
	await get_tree().process_frame

	_check(ui.visible, "UI hiển thị sau khi mở")
	_check(ui._recipes.size() >= 4, "danh sách có >= 4 công thức (có %d)" % ui._recipes.size())

	# Tìm recipe water_bucket (2 iron_ingot + 1 palm_wood)
	var idx := -1
	for i in range(ui._recipes.size()):
		if ui._recipes[i].get("result", "") == "water_bucket":
			idx = i
			break
	_check(idx >= 0, "tìm thấy công thức water_bucket")

	var r: Dictionary = ui._recipes[idx]
	_check(ui._can_craft(r), "có đủ nguyên liệu → craft được")
	_check(ui._cards[idx].modulate.a == 1.0, "card water_bucket sáng (không bị mờ)")

	# Recipe nặng (tractor: 6 steel + 8 iron + 10 palm) không có đủ → bị mờ
	var tr_idx := -1
	for i in range(ui._recipes.size()):
		if ui._recipes[i].get("result", "") == "tractor":
			tr_idx = i
			break
	_check(tr_idx >= 0 and not ui._can_craft(ui._recipes[tr_idx]), "tractor thiếu nguyên liệu → không craft được")

	# Chọn + preview
	ui._select(idx)
	await get_tree().process_frame
	_check(ui._selected_idx == idx, "đã chọn recipe water_bucket")
	_check(not ui._craft_btn.disabled, "nút chế tạo bật khi có đủ nguyên liệu")

	# Chế tạo: tiêu 2 iron + 1 palm → nhận 1 water_bucket
	var iron_before := player.inventory.get_item_count("iron_ingot")
	var palm_before := player.inventory.get_item_count("palm_wood")
	var wb_before := player.inventory.get_item_count("water_bucket")
	ui._craft()
	_check(player.inventory.get_item_count("iron_ingot") == iron_before - 2, "tiêu hao 2 iron_ingot")
	_check(player.inventory.get_item_count("palm_wood") == palm_before - 1, "tiêu hao 1 palm_wood")
	_check(player.inventory.get_item_count("water_bucket") == wb_before + 1, "nhận +1 water_bucket")

	# Sau khi thiếu nguyên liệu → button khoá lại
	await get_tree().process_frame
	_check(ui._craft_btn.disabled, "hết nguyên liệu → nút khoá")

	ui.close()
	for i in range(40):
		await get_tree().process_frame
	_check(not ui.visible, "UI ẩn sau khi close")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)