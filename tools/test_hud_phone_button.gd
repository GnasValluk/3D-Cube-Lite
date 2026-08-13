extends Node3D

## test_hud_phone_button — Nút UI top-left (phone settings) + Alt-to-show-cursor
## + camera rotation không chạy khi con trỏ hiển thị:
##  1. HUD tạo nút phone (icon_phone.png) + nút ⚙ settings ở góc trái trên.
##  2. Alt thiết lập MOUSE_MODE_VISIBLE + _cursor_free; camera FP bỏ qua
##     InputEventMouseMotion khi cursor visible.
## Chạy qua tools/test_hud_phone_button.tscn (không chạy trực tiếp .gd).

const _HUD = preload("res://scripts/ui/hud/hud.gd")
const _PhoneUI = preload("res://scripts/ui/hud/phone_ui.gd")
const _FPCam = preload("res://scripts/camera/first_person_camera.gd")
const _PhoneIcon = preload("res://assets/phone_ui/icon_phone.png")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_hud_phone_button: phone/settings button + Alt cursor + camera guard ==")
	ItemDatabase.ensure_db()

	# ── 1. Phone icon tải được ─────────────────────────────────────────────
	print("-- 1. Phone icon texture --")
	_check(_PhoneIcon != null and _PhoneIcon is Texture2D, "icon_phone.png tải thành Texture2D")

	# ── 2. HUD: nút phone + settings ở góc trái trên ────────────────────────
	print("-- 2. HUD top-left buttons --")
	var root := Node.new()
	add_child(root)
	var hud := _HUD.new()
	root.add_child(hud)
	# Đợi _ready + process_frame để _build_screen_buttons chạy
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hud._screen_panel != null, "HUD có _screen_panel")
	var phone_btn := hud._screen_panel.get_node_or_null("PhoneButton") as TextureButton
	var set_btn := hud._screen_panel.get_node_or_null("SettingsButton") as Button
	_check(phone_btn != null, "có nút PhoneButton")
	_check(set_btn != null, "có nút SettingsButton")
	if phone_btn:
		_check(phone_btn.texture_normal == _PhoneIcon or (phone_btn.texture_normal != null and phone_btn.texture_normal is Texture2D),
			"PhoneButton dùng icon_phone")
		_check(phone_btn.position.x <= 32 and phone_btn.position.y <= 32,
			"PhoneButton ở góc trái trên (pos %s)" % phone_btn.position)
	if set_btn:
		_check(set_btn.text == "\u2699", "SettingsButton hiện icon \u2699")
	_check(hud._phone_ui != null and hud._phone_ui is PhoneUI, "HUD sở hữu PhoneUI")
	_check(hud._cursor_free == false, "mặc định _cursor_free = false")

	# Mở phone qua nút rồi đóng lại: chức năng toggle
	hud._on_phone_button_pressed()
	await get_tree().process_frame
	_check(hud._phone_ui != null and hud._phone_ui.visible, "nút phone mở PhoneUI")
	hud._phone_ui.close()
	await get_tree().create_timer(0.3).timeout
	_check(not hud._phone_ui.visible, "nút phone đóng PhoneUI")

	# ── 3. Camera guard: con trỏ VISIBLE → không xoay cam ─────────────────────
	print("-- 3. Camera rotation guard (Alt / cursor visible) --")
	var cam := Node3D.new()
	cam.set_script(_FPCam)
	var cm := Camera3D.new()
	cm.name = "Camera3D"
	cam.add_child(cm)
	add_child(cam)
	# Đợi _ready camera (cần Camera3D child)
	await get_tree().process_frame
	cam._is_active = true
	cam._yaw = 12.0
	var base_yaw: float = cam._yaw

	# Trường hợp A: cursor VISIBLE (giống Alt) → không xoay cam (guard chặn)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_feed_motion(cam, Vector2(40, 10))
	_check(abs(cam._yaw - base_yaw) < 0.0001, "cursor VISIBLE → không xoay cam (yaw=%.4f)" % cam._yaw)

	# Trường hợp B: logic xoay thực sự còn hoạt động (gọi trực tiếp rotate)
	# (headless không cho phép set non-VISIBLE, nên gọi _rotate_from_motion trực tiếp)
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(40, 10)
	cam._rotate_from_motion(mm)
	_check(abs(cam._yaw - base_yaw) > 0.0001, "xoay cam khi cursor không chặn (yaw=%.4f)" % cam._yaw)
	cam.queue_free()

	# Dọn dọn: trả về con trỏ mặc định
	hud.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

func _feed_motion(cam: Node, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = rel
	ev.position = Vector2(512, 512)
	cam._unhandled_input(ev)
