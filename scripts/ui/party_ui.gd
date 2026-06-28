extends Control
class_name PartyUI

var _mgr: CharacterManager
var _all_chars: Array[String] = ["Raptor", "Dragon", "Warrior", "Beyordeath"]
var _party_order: Array[String] = []
var _selected: String = ""
var _quick_deploy: bool = false

var _ros_btns: Array[Button] = []
var _ros_icons: Array[TextureRect] = []

var _preview_name: Label
var _preview_element: Label
var _preview_level: Label
var _preview_avatar: TextureRect
var _stat_labels: Dictionary = {}
var _skill_labels: Array[Label] = []

var _btn_quick: Button
var _btn_confirm: Button
var _slot_indicators: Array[Label] = []

var _char_info: Dictionary = {
	"Raptor":     { "element": CharacterBase.Element.DIEN },
	"Dragon":     { "element": CharacterBase.Element.HAC_AM },
	"Warrior":    { "element": CharacterBase.Element.BANG },
	"Beyordeath": { "element": CharacterBase.Element.DECAY },
}

var _skill_data: Dictionary = {
	"Raptor": [
		{ "name": "LMB", "desc": "Bắn 3 phát liên tiếp", "mana": 0, "cd": 0.6 },
		{ "name": "Q", "desc": "Lướt điện — xuyên 3 lần", "mana": 50, "cd": 1.5 },
		{ "name": "R", "desc": "Tia sét 75 st + Buff 100% tốc 3s", "mana": 50, "cd": 5.0 },
		{ "name": "SPACE", "desc": "Lướt nhanh / Double-tap: —" },
	],
	"Dragon": [
		{ "name": "LMB", "desc": "Cầu lửa nổ vùng", "mana": 0, "cd": 1.0 },
		{ "name": "Q", "desc": "Lao vụt (2 stack, 5s hồi/stack)", "mana": 0, "cd": 5.0 },
		{ "name": "R", "desc": "Quả cầu hạt nhân — hút + 25st/tick", "mana": 100, "cd": 5.0 },
		{ "name": "SPACE", "desc": "Double-tap: Bay 10s" },
	],
	"Warrior": [
		{ "name": "LMB", "desc": "Chém tia băng", "mana": 0, "cd": 2.0 },
		{ "name": "Q", "desc": "Dậm băng 250 st vùng 15m + Hàn Băng buff", "mana": 130, "cd": 25.0 },
		{ "name": "R", "desc": "Nhảy đập 150 st + Khiên đỡ 20%HP toàn đội", "mana": 50, "cd": 10.0 },
		{ "name": "SPACE", "desc": "Lướt nhanh / Double-tap: —" },
	],
	"Beyordeath": [
		{ "name": "LMB", "desc": "Bắn 6 phát (17 st khi bay)", "mana": 0, "cd": 1.0 },
		{ "name": "Q", "desc": "Lướt (đất) / Thả bom liên tục (bay: 75 MP)", "mana": 0, "cd": 3.0 },
		{ "name": "R", "desc": "2 hỏa tiễn tự tìm — 100 st + AOE + DoT", "mana": 130, "cd": 7.0 },
		{ "name": "SPACE", "desc": "Nhảy / Double-tap: Biến chiến cơ 10s" },
	],
}

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var W: float = 960.0
	var H: float = 600.0
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
	left.size = Vector2(200, 440)
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

		var icon := TextureRect.new()
		icon.position = Vector2(10, 9)
		icon.size = Vector2(42, 42)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		btn.add_child(icon)

		_ros_btns.append(btn)
		_ros_icons.append(icon)

	_right_build(bg)

	var bottom_y: float = 500.0

	_btn_quick = Button.new()
	_btn_quick.position = Vector2(16, bottom_y)
	_btn_quick.size = Vector2(200, 38)
	_btn_quick.text = "THIẾT LẬP NHANH: TẮT"
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

	_btn_confirm = Button.new()
	_btn_confirm.position = Vector2(232, bottom_y)
	_btn_confirm.size = Vector2(140, 38)
	_btn_confirm.text = "XÁC NHẬN"
	_btn_confirm.add_theme_font_size_override("font_size", 14)
	_btn_confirm.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	var cf_bg := StyleBoxFlat.new()
	cf_bg.bg_color = Color(0.15, 0.40, 0.20, 0.85)
	cf_bg.corner_radius_top_left = 6; cf_bg.corner_radius_top_right = 6
	cf_bg.corner_radius_bottom_left = 6; cf_bg.corner_radius_bottom_right = 6
	cf_bg.border_width_left = 1; cf_bg.border_width_right = 1
	cf_bg.border_width_top = 1; cf_bg.border_width_bottom = 1
	cf_bg.border_color = Color(0.3, 0.7, 0.35, 0.6)
	_btn_confirm.add_theme_stylebox_override("normal", cf_bg)
	_btn_confirm.add_theme_stylebox_override("hover", cf_bg)
	_btn_confirm.pressed.connect(_on_confirm)
	_btn_confirm.visible = false
	bg.add_child(_btn_confirm)

	for i in range(3):
		var lbl := Label.new()
		lbl.position = Vector2(400 + i * 160, bottom_y + 8)
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

func _right_build(bg: Panel) -> void:
	var right := Panel.new()
	right.position = Vector2(232, 54)
	right.size = Vector2(480, 440)
	var right_bg := StyleBoxFlat.new()
	right_bg.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	right_bg.corner_radius_top_left = 10; right_bg.corner_radius_top_right = 10
	right_bg.corner_radius_bottom_left = 10; right_bg.corner_radius_bottom_right = 10
	right_bg.border_width_left = 1; right_bg.border_width_right = 1
	right_bg.border_width_top = 1; right_bg.border_width_bottom = 1
	right_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
	right.add_theme_stylebox_override("panel", right_bg)
	bg.add_child(right)

	_preview_avatar = TextureRect.new()
	_preview_avatar.position = Vector2(20, 16)
	_preview_avatar.size = Vector2(80, 80)
	_preview_avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(_preview_avatar)

	_preview_name = Label.new()
	_preview_name.position = Vector2(114, 20)
	_preview_name.size = Vector2(200, 30)
	_preview_name.add_theme_font_size_override("font_size", 22)
	_preview_name.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	right.add_child(_preview_name)

	_preview_element = Label.new()
	_preview_element.position = Vector2(114, 50)
	_preview_element.size = Vector2(200, 18)
	_preview_element.add_theme_font_size_override("font_size", 13)
	right.add_child(_preview_element)

	_preview_level = Label.new()
	_preview_level.name = "PreviewLevel"
	_preview_level.position = Vector2(114, 68)
	_preview_level.size = Vector2(200, 18)
	_preview_level.add_theme_font_size_override("font_size", 11)
	_preview_level.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 0.8))
	right.add_child(_preview_level)

	var stat_keys: Array[String] = ["hp", "mp", "atk", "def", "spd", "crit", "crit_dmg", "mp_regen", "mp_refund"]
	var stat_pos: Array[Vector2] = [
		Vector2(114, 90), Vector2(260, 90),
		Vector2(114, 110), Vector2(260, 110),
		Vector2(114, 130), Vector2(260, 130),
		Vector2(114, 150), Vector2(260, 150),
		Vector2(114, 170),
	]
	for i in range(stat_keys.size()):
		var lbl := Label.new()
		lbl.position = stat_pos[i]
		lbl.size = Vector2(130, 18)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85, 0.8))
		right.add_child(lbl)
		_stat_labels[stat_keys[i]] = lbl

	var div1 := ColorRect.new()
	div1.position = Vector2(20, 186)
	div1.size = Vector2(440, 1)
	div1.color = Color(0.3, 0.3, 0.4, 0.3)
	right.add_child(div1)

	var sk_header := Label.new()
	sk_header.text = "KỸ NĂNG"
	sk_header.position = Vector2(20, 192)
	sk_header.add_theme_font_size_override("font_size", 12)
	sk_header.add_theme_color_override("font_color", Color(0.45, 0.45, 0.65, 0.7))
	right.add_child(sk_header)

	for i in range(4):
		var lbl := Label.new()
		lbl.position = Vector2(20, 214 + i * 56)
		lbl.size = Vector2(440, 50)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.85))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		right.add_child(lbl)
		_skill_labels.append(lbl)

func _find_char(name_str: String) -> CharacterBase:
	if _mgr == null:
		return null
	for ch in _mgr.get_children():
		if ch is CharacterBase and ch.character_name == name_str:
			return ch as CharacterBase
	return null

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
		var tex_path: String = "res://assets/icon_character/" + name_str.to_lower() + ".png"
		_ros_icons[i].texture = load(tex_path) as Texture2D
		_ros_icons[i].modulate = Color(1, 1, 1, 1)

		var is_active: bool = name_str == active_name
		var is_sel: bool = name_str == _selected
		var in_party: bool = name_str in _party_order
		_ros_btns[i].text = ("  ▶ " if is_active else "  ") + name_str

		var btn_bg: StyleBoxFlat = _ros_btns[i].get_theme_stylebox("normal")
		if is_sel and is_active:
			btn_bg.border_color = Color(ec.r, ec.g, ec.b, 0.95)
			btn_bg.border_width_left = 3; btn_bg.border_width_right = 3
			btn_bg.border_width_top = 3; btn_bg.border_width_bottom = 3
			btn_bg.bg_color = Color(ec.r * 0.25, ec.g * 0.25, ec.b * 0.25, 0.9)
		elif is_sel:
			btn_bg.border_color = Color(ec.r, ec.g, ec.b, 0.8)
			btn_bg.border_width_left = 2; btn_bg.border_width_right = 2
			btn_bg.border_width_top = 2; btn_bg.border_width_bottom = 2
			btn_bg.bg_color = Color(ec.r * 0.2, ec.g * 0.2, ec.b * 0.2, 0.8)
		elif in_party:
			btn_bg.border_color = Color(ec.r, ec.g, ec.b, 0.55)
			btn_bg.border_width_left = 2; btn_bg.border_width_right = 2
			btn_bg.border_width_top = 2; btn_bg.border_width_bottom = 2
			btn_bg.bg_color = Color(0.12, 0.12, 0.20, 0.7)
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
	if _quick_deploy:
		_preview_name.text = "CHẾ ĐỘ NHANH"
		_preview_element.text = "Ấn XÁC NHẬN để áp dụng"
		_preview_avatar.texture = null
		_preview_avatar.modulate = Color(0.15, 0.15, 0.2, 1)
		_preview_level.text = ""
		for key in _stat_labels:
			_stat_labels[key].text = ""
		for lbl in _skill_labels:
			lbl.text = ""
		return

	if _selected == "":
		_preview_name.text = ""
		_preview_element.text = ""
		_preview_level.text = ""
		_preview_avatar.texture = null
		_preview_avatar.modulate = Color(0.15, 0.15, 0.2, 1)
		for key in _stat_labels:
			_stat_labels[key].text = ""
		for lbl in _skill_labels:
			lbl.text = ""
		return

	var active: CharacterBase = _mgr.get_current_character() if _mgr else null
	var is_active: bool = active != null and active.character_name == _selected
	var ec := _get_element_color(_selected)

	_preview_name.text = _selected.to_upper() + ("  ●" if is_active else "")
	var tex_path: String = "res://assets/icon_character/" + _selected.to_lower() + ".png"
	_preview_avatar.texture = load(tex_path) as Texture2D
	_preview_avatar.modulate = Color(1, 1, 1, 1)
	_preview_element.text = "Hệ: " + _get_element_name(_selected)
	_preview_element.add_theme_color_override("font_color", Color(ec.r, ec.g, ec.b, 0.9))

	var ch: CharacterBase = _find_char(_selected)
	if ch != null:
		_preview_level.text = "Cấp %d  |  EXP: %d/%d" % [ch.level, ch.exp, ch.exp_to_next]
		_stat_labels["hp"].text = "HP: %d/%d" % [ch.hp, ch.max_hp]
		_stat_labels["mp"].text = "MP: %d/%d" % [ch.mana, ch.max_mana]
		_stat_labels["atk"].text = "ATK: %d" % ch.attack_power
		_stat_labels["def"].text = "DEF: %d" % ch.defense
		_stat_labels["spd"].text = "SPD: %.1f" % ch.move_speed
		_stat_labels["crit"].text = "Tỉ lệ Crit: %d%%" % int(ch.crit_rate * 100.0)
		_stat_labels["crit_dmg"].text = "Sát thương Crit: %d%%" % int(ch.crit_dmg * 100.0)
		_stat_labels["mp_regen"].text = "Hồi MP: %.1f/s" % ch.mp_regen
		_stat_labels["mp_refund"].text = "Hoàn MP: %d" % ch.mp_refund
	else:
		_preview_level.text = ""
		_stat_labels["hp"].text = "HP: —"
		_stat_labels["mp"].text = "MP: —"
		_stat_labels["atk"].text = "ATK: —"
		_stat_labels["def"].text = "DEF: —"
		_stat_labels["spd"].text = "SPD: —"
		_stat_labels["crit"].text = "Tỉ lệ Crit: —"
		_stat_labels["crit_dmg"].text = "Sát thương Crit: —"
		_stat_labels["mp_regen"].text = "Hồi MP: —"
		_stat_labels["mp_refund"].text = "Hoàn MP: —"

	var skills: Array = _skill_data.get(_selected, [])
	for i in range(4):
		if i < skills.size():
			var s: Dictionary = skills[i]
			if s.has("mana"):
				var mana_str: String = "%d MP" % s.mana if s.mana > 0 else "0 MP"
				_skill_labels[i].text = "%s  |  CD: %.1fs  |  %s\n• %s" % [s.name, s.cd, mana_str, s.desc]
			else:
				_skill_labels[i].text = "%s\n• %s" % [s.name, s.desc]
		else:
			_skill_labels[i].text = ""

func _refresh_quick_btn() -> void:
	if _quick_deploy:
		_btn_quick.text = "THIẾT LẬP NHANH: BẬT"
		_btn_quick.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 0.95))
	else:
		_btn_quick.text = "THIẾT LẬP NHANH: TẮT"
		_btn_quick.add_theme_color_override("font_color", Color(0.65, 0.65, 0.85, 0.8))
	_btn_confirm.visible = _quick_deploy

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
	else:
		_selected = name_str

	_refresh()

func _show_error(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 0.95))
	lbl.position = Vector2(232, 456)
	lbl.size = Vector2(480, 30)
	add_child(lbl)
	get_tree().create_timer(1.8).timeout.connect(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	)

func _on_confirm() -> void:
	if _party_order.is_empty():
		_show_error("Cần ít nhất một nhân vật")
	else:
		_apply()
		hide_party()

func _on_toggle_quick() -> void:
	_quick_deploy = not _quick_deploy
	_selected = ""
	_refresh()

func _get_element_color(name_str: String) -> Color:
	var info: Dictionary = _char_info.get(name_str, {})
	var elem: Variant = info.get("element", 0)
	if typeof(elem) == TYPE_INT:
		return CharacterBase.ELEMENT_COLORS.get(elem as int, Color.WHITE)
	return Color.WHITE

func _get_element_name(name_str: String) -> String:
	var info: Dictionary = _char_info.get(name_str, {})
	var elem: Variant = info.get("element", CharacterBase.Element.DIEN)
	match elem:
		CharacterBase.Element.DIEN: return "Điện"
		CharacterBase.Element.HOA: return "Hỏa"
		CharacterBase.Element.BANG: return "Băng"
		CharacterBase.Element.HAC_AM: return "Hắc Ám"
		CharacterBase.Element.DECAY: return "Phân hủy"
		CharacterBase.Element.ANH_SANG: return "Ánh Sáng"
	return "?"
