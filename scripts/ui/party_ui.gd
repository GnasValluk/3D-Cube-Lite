## ui/party_ui.gd
## Màn hình đội hình — absolute positioning, không dùng container.

extends Control
class_name PartyUI

var _mgr: CharacterManager
var _all_chars: Array[String] = ["Raptor", "Dragon", "Warrior", "Beyordeath"]
var _party_order: Array[String] = []
var _selected: String = ""
var _quick_deploy: bool = false

var _ros_btns: Array[Button] = []
var _ros_icons: Array[ColorRect] = []

var _preview_name: Label
var _preview_element: Label
var _preview_avatar: ColorRect
var _preview_skill_box: Control
var _btn_deploy: Button

var _btn_quick: Button
var _slot_indicators: Array[Label] = []

var _char_info: Dictionary = {
	"Raptor":     { "element": CharacterBase.Element.DIEN },
	"Dragon":     { "element": CharacterBase.Element.HAC_AM },
	"Warrior":    { "element": CharacterBase.Element.BANG },
	"Beyordeath": { "element": CharacterBase.Element.DECAY },
}

var _skill_texts: Dictionary = {
	"Raptor": [
		"Tả: Bắn 3 phát liên tiếp (Điện)",
		"Q: Lướt nhanh về phía trước",
		"R: Tia sét + Tăng 100% tốc độ 3s",
	],
	"Dragon": [
		"Tả: Cầu lửa nổ vùng",
		"Q: Lướt khi bay",
		"R: Quả cầu hạt nhân hút kẻ địch",
	],
	"Warrior": [
		"Tả: Chém tia băng",
		"Q: Lao nhanh về phía trước",
		"R: Nhảy đập gây choáng vùng",
	],
	"Beyordeath": [
		"Tả: Bắn 6 phát liên tiếp (Decay)",
		"Q: Lao nhanh về phía trước",
		"R: 2 hỏa tiễn tự tìm mục tiêu nổ vùng",
		"Space: Biến hình chiến cơ 10s",
	],
}

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var W: float = 960.0
	var H: float = 580.0
	var ox: float = (vp.x - W) * 0.5
	var oy: float = (vp.y - H) * 0.5

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	add_child(overlay)

	var bg := Panel.new()
	bg.position = Vector2(ox, oy)
	bg.size = Vector2(W, H)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.07, 0.07, 0.12, 0.95)
	bg_style.corner_radius_top_left = 14; bg_style.corner_radius_top_right = 14
	bg_style.corner_radius_bottom_left = 14; bg_style.corner_radius_bottom_right = 14
	bg_style.border_width_left = 2; bg_style.border_width_right = 2
	bg_style.border_width_top = 2; bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.3, 0.3, 0.45, 0.6)
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	var title := Label.new()
	title.text = "ĐỘI HÌNH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.position = Vector2(0, 10)
	title.size = Vector2(W, 34)
	bg.add_child(title)

	var div := ColorRect.new()
	div.position = Vector2(30, 46)
	div.size = Vector2(W - 60, 2)
	div.color = Color(0.3, 0.3, 0.45, 0.4)
	bg.add_child(div)

	var left := Panel.new()
	left.position = Vector2(16, 54)
	left.size = Vector2(200, 420)
	var left_bg := StyleBoxFlat.new()
	left_bg.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	left_bg.corner_radius_top_left = 10; left_bg.corner_radius_top_right = 10
	left_bg.corner_radius_bottom_left = 10; left_bg.corner_radius_bottom_right = 10
	left_bg.border_width_left = 1; left_bg.border_width_right = 1
	left_bg.border_width_top = 1; left_bg.border_width_bottom = 1
	left_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
	left.add_theme_stylebox_override("panel", left_bg)
	bg.add_child(left)

	var lib_lbl := Label.new()
	lib_lbl.text = "THƯ VIỆN"
	lib_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lib_lbl.add_theme_font_size_override("font_size", 14)
	lib_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75, 0.8))
	lib_lbl.position = Vector2(0, 8)
	lib_lbl.size = Vector2(200, 22)
	left.add_child(lib_lbl)

	for i in range(_all_chars.size()):
		var y: float = 36.0 + i * 68.0
		var btn := Button.new()
		btn.position = Vector2(10, y)
		btn.size = Vector2(180, 60)
		btn.add_theme_font_size_override("font_size", 14)
		btn.text = "  " + _all_chars[i]
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var btn_bg := StyleBoxFlat.new()
		btn_bg.bg_color = Color(0.1, 0.1, 0.18, 0.85)
		btn_bg.corner_radius_top_left = 8; btn_bg.corner_radius_top_right = 8
		btn_bg.corner_radius_bottom_left = 8; btn_bg.corner_radius_bottom_right = 8
		btn_bg.border_width_left = 1; btn_bg.border_width_right = 1
		btn_bg.border_width_top = 1; btn_bg.border_width_bottom = 1
		btn_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
		btn.add_theme_stylebox_override("normal", btn_bg)
		btn.add_theme_stylebox_override("hover", btn_bg)
		btn.pressed.connect(_on_roster_click.bind(i))
		left.add_child(btn)

		var icon := ColorRect.new()
		icon.position = Vector2(10, 9)
		icon.size = Vector2(42, 42)
		icon.color = Color(0.2, 0.2, 0.3)
		btn.add_child(icon)

		_ros_btns.append(btn)
		_ros_icons.append(icon)

	var right := Panel.new()
	right.position = Vector2(232, 54)
	right.size = Vector2(480, 420)
	var right_bg := StyleBoxFlat.new()
	right_bg.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	right_bg.corner_radius_top_left = 10; right_bg.corner_radius_top_right = 10
	right_bg.corner_radius_bottom_left = 10; right_bg.corner_radius_bottom_right = 10
	right_bg.border_width_left = 1; right_bg.border_width_right = 1
	right_bg.border_width_top = 1; right_bg.border_width_bottom = 1
	right_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
	right.add_theme_stylebox_override("panel", right_bg)
	bg.add_child(right)

	_preview_avatar = ColorRect.new()
	_preview_avatar.position = Vector2(24, 18)
	_preview_avatar.size = Vector2(90, 90)
	_preview_avatar.color = Color(0.2, 0.2, 0.3)
	var avatar_border := StyleBoxFlat.new()
	avatar_border.corner_radius_top_left = 8; avatar_border.corner_radius_top_right = 8
	avatar_border.corner_radius_bottom_left = 8; avatar_border.corner_radius_bottom_right = 8
	_preview_avatar.add_theme_stylebox_override("panel", avatar_border)
	right.add_child(_preview_avatar)

	_preview_name = Label.new()
	_preview_name.position = Vector2(128, 22)
	_preview_name.size = Vector2(240, 30)
	_preview_name.add_theme_font_size_override("font_size", 22)
	_preview_name.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	right.add_child(_preview_name)

	_preview_element = Label.new()
	_preview_element.position = Vector2(128, 54)
	_preview_element.size = Vector2(240, 18)
	_preview_element.add_theme_font_size_override("font_size", 13)
	right.add_child(_preview_element)

	var sk_lbl := Label.new()
	sk_lbl.text = "KỸ NĂNG"
	sk_lbl.position = Vector2(24, 118)
	sk_lbl.add_theme_font_size_override("font_size", 12)
	sk_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.65, 0.7))
	right.add_child(sk_lbl)

	var sk_div := ColorRect.new()
	sk_div.position = Vector2(24, 112)
	sk_div.size = Vector2(432, 1)
	sk_div.color = Color(0.3, 0.3, 0.4, 0.3)
	right.add_child(sk_div)

	_preview_skill_box = Control.new()
	_preview_skill_box.position = Vector2(24, 134)
	_preview_skill_box.size = Vector2(432, 140)
	right.add_child(_preview_skill_box)

	_btn_deploy = Button.new()
	_btn_deploy.position = Vector2(100, 300)
	_btn_deploy.size = Vector2(280, 44)
	_btn_deploy.text = "RA SÂN"
	_btn_deploy.add_theme_font_size_override("font_size", 17)
	_btn_deploy.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	var deploy_bg := StyleBoxFlat.new()
	deploy_bg.bg_color = Color(0.12, 0.28, 0.55, 0.85)
	deploy_bg.corner_radius_top_left = 8; deploy_bg.corner_radius_top_right = 8
	deploy_bg.corner_radius_bottom_left = 8; deploy_bg.corner_radius_bottom_right = 8
	deploy_bg.border_width_left = 1; deploy_bg.border_width_right = 1
	deploy_bg.border_width_top = 1; deploy_bg.border_width_bottom = 1
	deploy_bg.border_color = Color(0.3, 0.5, 0.8, 0.6)
	_btn_deploy.add_theme_stylebox_override("normal", deploy_bg)
	_btn_deploy.add_theme_stylebox_override("hover", deploy_bg)
	_btn_deploy.pressed.connect(_on_deploy)
	right.add_child(_btn_deploy)

	_btn_deploy.visible = false

	var bottom_y: float = 486.0

	_btn_quick = Button.new()
	_btn_quick.position = Vector2(16, bottom_y)
	_btn_quick.size = Vector2(200, 38)
	_btn_quick.text = "RA SÂN NHANH: TẮT"
	_btn_quick.add_theme_font_size_override("font_size", 12)
	_btn_quick.add_theme_color_override("font_color", Color(0.65, 0.65, 0.85, 0.8))
	var qb_bg := StyleBoxFlat.new()
	qb_bg.bg_color = Color(0.08, 0.08, 0.14, 0.85)
	qb_bg.corner_radius_top_left = 6; qb_bg.corner_radius_top_right = 6
	qb_bg.corner_radius_bottom_left = 6; qb_bg.corner_radius_bottom_right = 6
	qb_bg.border_width_left = 1; qb_bg.border_width_right = 1
	qb_bg.border_width_top = 1; qb_bg.border_width_bottom = 1
	qb_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
	_btn_quick.add_theme_stylebox_override("normal", qb_bg)
	_btn_quick.add_theme_stylebox_override("hover", qb_bg)
	_btn_quick.pressed.connect(_on_toggle_quick)
	bg.add_child(_btn_quick)

	for i in range(3):
		var lbl := Label.new()
		lbl.position = Vector2(240 + i * 160, bottom_y + 8)
		lbl.size = Vector2(150, 22)
		lbl.text = "V%d: —" % [i + 1]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75, 0.7))
		bg.add_child(lbl)
		_slot_indicators.append(lbl)

	var hint := Label.new()
	hint.text = "ESC / P — Đóng"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45, 0.55))
	hint.position = Vector2(0, H - 22)
	hint.size = Vector2(W, 20)
	bg.add_child(hint)

func show_party(mgr: CharacterManager) -> void:
	_mgr = mgr
	_party_order = mgr.party_names.duplicate()
	_selected = ""
	_quick_deploy = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()

func hide_party() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply() -> void:
	if _mgr:
		_mgr.set_party_order(_party_order)

func _refresh() -> void:
	_refresh_roster()
	_refresh_preview()
	_refresh_quick_btn()
	_refresh_slot_indicators()

func _refresh_roster() -> void:
	var active: CharacterBase = _mgr.get_current_character() if _mgr else null
	var active_name: String = active.character_name if active else ""

	for i in range(_all_chars.size()):
		var name_str: String = _all_chars[i]
		var ec: Color = _get_element_color(name_str)
		_ros_icons[i].color = ec

		var is_active: bool = name_str == active_name
		var is_sel: bool = name_str == _selected
		_ros_btns[i].text = ("  ▶ " if is_active else "  ") + name_str

		var btn_bg: StyleBoxFlat = _ros_btns[i].get_theme_stylebox("normal")
		if is_sel:
			btn_bg.border_color = Color(ec.r, ec.g, ec.b, 0.8)
			btn_bg.border_width_left = 2; btn_bg.border_width_right = 2
			btn_bg.border_width_top = 2; btn_bg.border_width_bottom = 2
			btn_bg.bg_color = Color(ec.r * 0.2, ec.g * 0.2, ec.b * 0.2, 0.8)
		elif is_active:
			btn_bg.border_color = Color(ec.r, ec.g, ec.b, 0.6)
			btn_bg.border_width_left = 2; btn_bg.border_width_right = 2
			btn_bg.border_width_top = 2; btn_bg.border_width_bottom = 2
			btn_bg.bg_color = Color(0.12, 0.12, 0.20, 0.7)
		else:
			btn_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
			btn_bg.border_width_left = 1; btn_bg.border_width_right = 1
			btn_bg.border_width_top = 1; btn_bg.border_width_bottom = 1
			btn_bg.bg_color = Color(0.1, 0.1, 0.18, 0.85)

func _refresh_preview() -> void:
	_clear_skills()
	if _selected == "":
		_preview_name.text = ""
		_preview_element.text = ""
		_preview_avatar.color = Color(0.15, 0.15, 0.2)
		_btn_deploy.visible = false
		return

	_btn_deploy.visible = true
	var active: CharacterBase = _mgr.get_current_character() if _mgr else null
	var is_active: bool = active != null and active.character_name == _selected
	_preview_name.text = _selected.to_upper() + ("  ●" if is_active else "")
	_btn_deploy.text = "ĐANG RA SÂN" if is_active else "RA SÂN"
	_btn_deploy.disabled = is_active
	var ec := _get_element_color(_selected)
	_preview_avatar.color = ec
	_preview_element.text = "Hệ: " + _get_element_name(_selected)
	_preview_element.add_theme_color_override("font_color", Color(ec.r, ec.g, ec.b, 0.9))

	var y: float = 0.0
	for txt in _skill_texts.get(_selected, []):
		var lbl := Label.new()
		lbl.text = "• " + txt
		lbl.position = Vector2(0, y)
		lbl.size = Vector2(440, 22)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.85))
		_preview_skill_box.add_child(lbl)
		y += 26.0

func _clear_skills() -> void:
	for ch in _preview_skill_box.get_children():
		ch.queue_free()

func _refresh_quick_btn() -> void:
	if _quick_deploy:
		_btn_quick.text = "RA SÂN NHANH: BẬT"
		_btn_quick.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 0.95))
	else:
		_btn_quick.text = "RA SÂN NHANH: TẮT"
		_btn_quick.add_theme_color_override("font_color", Color(0.65, 0.65, 0.85, 0.8))

func _refresh_slot_indicators() -> void:
	var active: CharacterBase = _mgr.get_current_character() if _mgr else null
	var active_name: String = active.character_name if active else ""

	for i in range(3):
		if i < _party_order.size():
			var ec := _get_element_color(_party_order[i])
			var is_active: bool = _party_order[i] == active_name
			_slot_indicators[i].text = ("▶ " if is_active else "") + "V%d: %s" % [i + 1, _party_order[i]]
			_slot_indicators[i].add_theme_color_override("font_color", Color(ec.r, ec.g, ec.b, 0.9 if is_active else 0.7))
		else:
			_slot_indicators[i].text = "V%d: —" % [i + 1]
			_slot_indicators[i].add_theme_color_override("font_color", Color(0.35, 0.35, 0.45, 0.5))

func _on_roster_click(idx: int) -> void:
	if idx >= _all_chars.size():
		return
	var name_str: String = _all_chars[idx]

	if _quick_deploy:
		var pos: int = _party_order.find(name_str)
		if pos != -1:
			_party_order.remove_at(pos)
		else:
			if _party_order.size() < 3:
				_party_order.append(name_str)
		_apply()
		_refresh()
	else:
		_selected = name_str
		_refresh()

func _on_deploy() -> void:
	if _selected != "" and _mgr:
		_mgr.switch_by_name(_selected)
		hide_party()

func _on_toggle_quick() -> void:
	_quick_deploy = not _quick_deploy
	_refresh()

func _get_element_color(name_str: String) -> Color:
	var info: Dictionary = _char_info.get(name_str, {})
	var elem: Variant = info.get("element", 0)
	if elem is int and (elem as int) > 0:
		var tmp: Variant = CharacterBase.ELEMENT_COLORS.get(elem as int)
		if tmp is Color:
			return tmp as Color
	return Color(0.3, 0.3, 0.5)

func _get_element_name(name_str: String) -> String:
	var info: Dictionary = _char_info.get(name_str, {})
	var elem: Variant = info.get("element", 0)
	if elem is int:
		match elem as int:
			CharacterBase.Element.DIEN:    return "Điện"
			CharacterBase.Element.BANG:    return "Băng"
			CharacterBase.Element.DECAY:   return "Decay"
			CharacterBase.Element.HOA:     return "Hoả"
			CharacterBase.Element.HAC_AM:  return "Hắc Ám"
			CharacterBase.Element.ANH_SANG: return "Ánh Sáng"
	return ""
