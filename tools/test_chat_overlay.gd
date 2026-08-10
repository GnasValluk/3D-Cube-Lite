extends Node

## Smoke test ChatOverlay UI: build UI, add_message hiển thị, open/close input,
## text_submitted phát message_submitted.

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_chat_overlay ==")
	var overlay := preload("res://scripts/ui/chat_overlay.gd").new()
	add_child(overlay)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(overlay._panel != null, "chat overlay có panel")
	_check(overlay._lines != null, "chat overlay có vùng tin nhắn")
	_check(overlay._input != null, "chat overlay có LineEdit input")
	_check(not overlay.is_input_open(), "ban đầu input đóng")

	overlay.add_message("Host", Color(0.3, 0.7, 1.0), "xin chao")
	await get_tree().process_frame
	_check(overlay._lines.get_child_count() >= 1, "add_message thêm 1 dòng")
	_check(overlay.visible, "chat overlay hiện khi có tin nhắn")

	overlay.add_message("Client", Color(1.0, 0.6, 0.3), "chaoban")
	overlay.add_message("A", Color.WHITE, "1")
	overlay.add_message("B", Color.WHITE, "2")
	overlay.add_message("C", Color.WHITE, "3")
	overlay.add_message("D", Color.WHITE, "4")
	overlay.add_message("E", Color.WHITE, "5")
	overlay.add_message("F", Color.WHITE, "6")
	overlay.add_message("G", Color.WHITE, "7")
	overlay.add_message("H", Color.WHITE, "8")
	overlay.add_message("I", Color.WHITE, "9")
	overlay.add_message("J", Color.WHITE, "10")
	await get_tree().process_frame
	_check(overlay._lines.get_child_count() <= overlay.MAX_LINES, "số dòng bị giới hạn MAX_LINES")

	overlay.open_input()
	_check(overlay.is_input_open(), "open_input mở input")
	_check(overlay._input.visible, "LineEdit hiện khi mở input")

	var submitted: Array = []
	overlay.message_submitted.connect(func(t: String): submitted.append(t))
	overlay._input.text = "hello"
	overlay._on_text_submitted("hello")
	_check(submitted.size() == 1 and str(submitted[0]) == "hello", "submit phát message_submitted với text")
	_check(not overlay.is_input_open(), "sau submit input đóng lại")

	overlay._on_text_submitted("   ")
	_check(submitted.size() == 1, "submit rỗng không gửi message")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
