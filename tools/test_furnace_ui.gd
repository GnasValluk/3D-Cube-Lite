extends Node

## test_furnace_ui — Kiểm tra UI lò nung kiểu mới:
## 3 ô nguyên liệu / 3 ô thành phẩm / 2 ô nhiên liệu + icon lửa 2D nhấp nháy
## + thanh nhiên liệu. Mỗi chất đốt có lượng nhiên liệu riêng (giây), đốt dần
## theo thời gian — không tiêu 1 pcs/mẻ. Công thức nung gốc đã bị xoá → test
## bằng công thức mẫu chèn tạm.

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
	print("== test_furnace_ui: lò nung kiểu mới ==")

	ItemDatabase.ensure_db()
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
	ui.open(null, player)
	await get_tree().process_frame

	_check(ui.visible, "UI hiển thị sau khi mở")
	_check(ui._recipes.is_empty(), "công thức nung đã bị xoá (còn %d)" % ui._recipes.size())
	_check(ui._furnace_inv.slots.size() == 8, "lò có 8 ô (3 nung + 2 nhiên liệu + 3 thành phẩm)")
	_check(ui._input_panels.size() == 3, "3 ô nguyên liệu")
	_check(ui._fuel_panels.size() == 2, "2 ô nhiên liệu")
	_check(ui._output_panels.size() == 3, "3 ô thành phẩm")
	_check(ui._fire_label != null and ui._fire_glow != null, "có icon lửa 2D + hiệu ứng")
	_check(ui._fuel_bar != null and ui._fuel_fill != null, "có thanh process nhiên liệu")
	_check(ui._fuels.has("coal") and ui._fuels["coal"] > ui._fuels["palm_wood"],
		"mỗi chất đốt có lượng nhiên liệu riêng (coal > gỗ)")

	# Chèn công thức nung mẫu (đồng → thỏi đồng)
	ui._smelting_items["copper_ore"] = "copper_ingot"

	# Nạp nguyên liệu vào ô 0, nhiên liệu than vào ô 3
	ui._furnace_inv.slots[0].item = ItemDatabase.items_db["copper_ore"]
	ui._furnace_inv.slots[0].count = 3
	ui._furnace_inv.slots[3].item = ItemDatabase.items_db["coal"]
	ui._furnace_inv.slots[3].count = 1

	# Bắt đầu nung: coal (80s) chuyển thành năng lượng nhiên liệu → lửa sáng
	ui._smelt_time = 5.0
	ui._process(0.02)
	_check(ui._smelt_active, "lửa sáng khi có nguyên liệu + nhiên liệu")
	_check(not ui._fire_cold, "icon lửa ở trạng thái đốt (không tắt)")
	_check(ui._fuel_energy > 0.0, "than đã nạp vào nhiên liệu (%.1fs)" % ui._fuel_energy)

	# Sau 1 mẻ (5s): nguyên liệu tiêu 1, thành phẩm có thỏi; than chưa hết
	ui._process(5.0)
	_check(ui._furnace_inv.slots[0].count == 2, "sau 1 mẻ: còn 2 copper_ore")
	_check(not ui._furnace_inv.slots[5].is_empty() and ui._furnace_inv.slots[5].item.id == "copper_ingot",
		"sau 1 mẻ: thành phẩm copper_ingot trong ô sản phẩm")
	_check(ui._fuel_energy < 80.0 and ui._fuel_energy > 0.0, "nhiên liệu than giảm dần theo thời gian")

	# Nạp thêm 1 than để đốt cho hết nguyên liệu; đốt hết than → lửa tắt
	ui._furnace_inv.slots[3].item = ItemDatabase.items_db["coal"]
	ui._furnace_inv.slots[3].count = 1
	var smelt_before := ui._furnace_inv.slots[5].count
	ui._process(90.0)
	_check(ui._furnace_inv.slots[5].count > smelt_before, "nung tiếp ra thêm thỏi")
	_check(ui._fuel_energy <= 0.0, "hết nhiên liệu (%.1fs)" % ui._fuel_energy)
	_check(ui._smelt_active == false, "hết nhiên liệu → ngừng nung")
	_check(ui._fire_cold, "hết nhiên liệu → lửa tắt")

	# Chuyển sản phẩm về túi
	var ingot_before := player.inventory.get_item_count("copper_ingot")
	var out_count: int = ui._furnace_inv.slots[5].count
	ui._transfer_from_furnace(5, out_count)
	_check(player.inventory.get_item_count("copper_ingot") == ingot_before + out_count,
		"chuyển %d copper_ingot về túi" % out_count)

	ui.close()
	for i in range(40):
		await get_tree().process_frame
	_check(not ui.visible, "UI ẩn sau khi close")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)