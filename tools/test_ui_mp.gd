extends Node

## Smoke test UI: multiplayer_menu (browser + advanced) và new_journey_ui
## (toggle Chế độ đa người chơi trong cài đặt nâng cao).

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_ui_mp ==")

	var menu := preload("res://scripts/ui/menus/multiplayer_menu.gd").new()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu._adv_btn != null, "multiplayer_menu có nút Nâng cao")
	_check(menu._adv_panel != null, "có panel nâng cao (cùng menu, không phải UI mới)")
	_check(not menu._adv_panel.visible, "ban đầu panel nâng cao ẩn")
	menu._toggle_advanced()
	await get_tree().process_frame
	_check(menu._adv_panel.visible, "bấm Nâng cao → mở ngay trong menu (không UI mới)")
	menu._toggle_advanced()
	_check(not menu._adv_panel.visible, "bấm lại → đóng panel nâng cao")

	var nju := preload("res://scripts/ui/menus/new_journey_ui.gd").new()
	add_child(nju)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(nju._mp_toggle != null, "new_journey_ui có toggle Chế độ đa người chơi")
	_check(nju._mp_hint != null, "có hint chế độ đa người chơi")
	_check(not nju._mp_toggle.button_pressed, "ban đầu toggle đa người chơi tắt")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
