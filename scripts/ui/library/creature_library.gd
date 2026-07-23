extends Control
class_name Library

const CREATURES := [
	{ "id": "player",     "name": "Player",      "cat": "party", "element": 6,
	  "hp": 500, "atk": 80, "def": 20, "spd": 3.6, "mp": 200,
	  "skills": "LMB: Vụt kiếm (0s)\nQ: Vụt sáng 80st (0.6s)\nR: Chém Xoáy 150st (1.0s)\nSPACE: Nhảy",
	  "spawn": "Overworld" },
	{ "id": "raptor",     "name": "Raptor",      "cat": "party", "element": 1,
	  "hp": 340, "atk": 135, "def": 26, "spd": 6.5, "mp": 200,
	  "skills": "LMB: Bắn 3 phát (0.6s)\nQ: Lướt điện xuyên 3 lần (1.5s)\nR: Tia sét 75st + Buff tốc 3s (5s)\nSPACE: Lướt nhanh",
	  "spawn": "Overworld" },
	{ "id": "dragon",     "name": "Dragon",      "cat": "party", "element": 5,
	  "hp": 600, "atk": 140, "def": 30, "spd": 3.6, "mp": 200,
	  "skills": "LMB: Cầu lửa nổ vùng (1.0s)\nQ: Lao vụt 2 stack (5s/stack)\nR: Quả cầu hạt nhân 25st/tick (5s)\nSPACE: Bay 10s",
	  "spawn": "Overworld" },
	{ "id": "warrior",    "name": "Warrior",     "cat": "party", "element": 2,
	  "hp": 800, "atk": 140, "def": 40, "spd": 3.2, "mp": 200,
	  "skills": "LMB: Chém tia băng (2.0s)\nQ: Dậm băng 250st + Buff (25s)\nR: Nhảy đập 150st + Khiên 20%HP (10s)\nSPACE: Lướt",
	  "spawn": "Overworld" },
	{ "id": "beyordeath", "name": "Beyordeath",  "cat": "party", "element": 3,
	  "hp": 450, "atk": 165, "def": 12, "spd": 5.0, "mp": 200,
	  "skills": "LMB: Bắn 6 phát (1.0s)\nQ: Lướt / Thả bom (3.0s)\nR: 2 hoả tiễn 100st + AOE (7.0s)\nSPACE: Biến chiến cơ 10s",
	  "spawn": "Overworld" },
	{ "id": "carp",       "name": "Carp",        "cat": "fish", "fi": 0,
	  "hp": 60, "atk": 0, "def": 0, "spd": 1.4, "spawn": "Silt / Sand lakes" },
	{ "id": "perch",      "name": "Climbing Perch", "cat": "fish", "fi": 1,
	  "hp": 40, "atk": 0, "def": 0, "spd": 2.0, "spawn": "Silt / Sand lakes" },
	{ "id": "tilapia",    "name": "Red Tilapia", "cat": "fish", "fi": 2,
	  "hp": 50, "atk": 0, "def": 0, "spd": 1.8, "spawn": "Silt / Sand lakes" },
	{ "id": "snakehead",  "name": "Snakehead",   "cat": "fish", "fi": 3,
	  "hp": 70, "atk": 0, "def": 0, "spd": 1.5, "spawn": "Silt / Sand lakes" },
	{ "id": "flowerhorn", "name": "Flowerhorn",  "cat": "fish", "fi": 4,
	  "hp": 70, "atk": 25, "def": 5, "spd": 1.2, "spawn": "Silt / Sand lakes" },
	{ "id": "shrimp",     "name": "Freshwater Shrimp", "cat": "fish", "fi": 5,
	  "hp": 15, "atk": 0, "def": 0, "spd": 0.8, "spawn": "Silt / Sand lakes (bottom)" },
]
const ELEMENT_SYMBOLS := { 1: "⚡", 2: "❄", 3: "☣", 5: "🌑", 6: "☀" }

const BG_DEEP := Color(0.06, 0.04, 0.12)
const BG_PANEL := Color(0.10, 0.07, 0.18)
const BG_CARD := Color(0.14, 0.10, 0.22)
const PURPLE := Color(0.55, 0.35, 0.90)
const TEAL := Color(0.15, 0.72, 0.68)
const PINK := Color(0.82, 0.28, 0.52)
const ORANGE := Color(0.92, 0.52, 0.12)
const CYAN := Color(0.15, 0.62, 0.92)
const TEXT_BRIGHT := Color(0.95, 0.92, 1.0)
const TEXT_MAIN := Color(0.82, 0.78, 0.95)
const TEXT_DIM := Color(0.55, 0.50, 0.72)
const TEXT_MUTED := Color(0.35, 0.32, 0.50)

enum Tab { CREATURES }

var _current_tab: int = Tab.CREATURES
var _selected: String = ""

# Creature
var _creature_left: Panel
var _creature_right: Panel
var _btn_group: Array[Button] = []
var _preview_name: Label
var _preview_element: Label
var _preview_stats: Label
var _preview_skills: Label
var _preview_spawn: Label

var _stats_title: Label
var _skills_title: Label
var _spawn_title: Label
var _cat_labels: Array[Label] = []
var _tab_label_keys: Array[String] = []

# Tab
var _tab_buttons: Array[Button] = []



func _get_element_name(elem: int) -> String:
	match elem:
		1: return tr("ELEM_ELECTRIC")
		2: return tr("ELEM_ICE")
		3: return tr("ELEM_DECAY")
		5: return tr("ELEM_DARK")
		6: return tr("ELEM_LIGHT")
	return ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _tab_buttons.size() > 0:
		_refresh_texts()


func _refresh_texts() -> void:
	for i in range(_tab_buttons.size()):
		var key := _tab_label_keys[i] if i < _tab_label_keys.size() else ""
		_tab_buttons[i].text = tr(key)
	for i in range(_cat_labels.size()):
		match i:
			0: _cat_labels[i].text = tr("LIB_SECTION_PARTY")
			_: _cat_labels[i].text = tr("LIB_SECTION_FISH")
	_stats_title.text = tr("LIB_HEADER_STATS")
	_skills_title.text = tr("LIB_HEADER_SKILLS")
	_spawn_title.text = tr("LIB_HEADER_SPAWN")
	if _selected:
		_update_preview()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var W: float = min(vp.x * 0.85, 1200.0)
	var H: float = vp.y * 0.8
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
	bg_style.corner_radius_top_left = 18; bg_style.corner_radius_top_right = 18
	bg_style.corner_radius_bottom_left = 18; bg_style.corner_radius_bottom_right = 18
	bg_style.border_width_left = 2; bg_style.border_width_right = 2
	bg_style.border_width_top = 2; bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.40, 0.30, 0.60, 0.6)
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	var title := Label.new()
	title.text = tr("CREATURE_LIBRARY_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", TEXT_BRIGHT)
	title.add_theme_color_override("font_shadow_color", Color(0.30, 0.15, 0.50, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.position = Vector2(0, 14)
	title.size = Vector2(W, 46)
	bg.add_child(title)

	var close_btn := Button.new()
	close_btn.position = Vector2(W - 50, 12)
	close_btn.size = Vector2(42, 42)
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", TEXT_DIM)
	var cb_bg := StyleBoxFlat.new()
	cb_bg.bg_color = Color(0, 0, 0, 0)
	close_btn.add_theme_stylebox_override("normal", cb_bg)
	close_btn.add_theme_stylebox_override("hover", cb_bg)
	close_btn.pressed.connect(_on_close)
	bg.add_child(close_btn)

	var div := ColorRect.new()
	div.position = Vector2(30, 60)
	div.size = Vector2(W - 60, 2)
	div.color = Color(0.40, 0.30, 0.60, 0.4)
	bg.add_child(div)

	_build_tabs(bg, W)

	_creature_left = _make_side_panel(bg, 20, 110, 250, int(H - 130))
	_creature_right = _make_side_panel(bg, 290, 110, int(W - 310), int(H - 130))
	_build_creature_list(_creature_left)
	_build_creature_preview(_creature_right)

	_update_tab_visibility()

func _make_side_panel(bg: Panel, x: float, y: float, w: float, h: float) -> Panel:
	var p := Panel.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.12, 0.92)
	s.corner_radius_top_left = 14; s.corner_radius_top_right = 14
	s.corner_radius_bottom_left = 14; s.corner_radius_bottom_right = 14
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	s.border_color = Color(0.40, 0.30, 0.60, 0.5)
	p.add_theme_stylebox_override("panel", s)
	bg.add_child(p)
	return p

func _build_tabs(bg: Panel, W: float) -> void:
	var tab_data := [
		{ "id": Tab.CREATURES, "label": "LIB_TAB_CREATURES" },
	]
	var tab_y: float = 64.0
	var tw: float = 140.0
	var th: float = 44.0
	var start_x: float = 38.0
	for i in range(tab_data.size()):
		var d: Dictionary = tab_data[i]
		var btn := Button.new()
		btn.position = Vector2(start_x + i * (tw + 4), tab_y)
		btn.size = Vector2(tw, th)
		btn.text = tr(d["label"])
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_tab_selected.bind(d["id"]))
		bg.add_child(btn)
		_tab_buttons.append(btn)
		_tab_label_keys.append(d["label"])
	_update_tab_styles()



func _on_tab_selected(tab: int) -> void:
	if _current_tab == tab:
		return
	_current_tab = tab
	_selected = ""
	_update_tab_visibility()
	if _current_tab == Tab.CREATURES and CREATURES.size() > 0:
		_on_select(CREATURES[0]["id"])



func _update_tab_visibility() -> void:
	_creature_left.visible = _current_tab == Tab.CREATURES
	_creature_right.visible = _current_tab == Tab.CREATURES
	_update_tab_styles()

func _update_tab_styles() -> void:
	for i in range(_tab_buttons.size()):
		var btn: Button = _tab_buttons[i]
		var active: bool = (i == _current_tab)
		var bg := StyleBoxFlat.new()
		if active:
			bg.bg_color = Color(0.30, 0.20, 0.45, 0.95)
			bg.border_color = Color(0.55, 0.35, 0.90, 0.5)
		else:
			bg.bg_color = Color(0.10, 0.07, 0.18, 0.85)
			bg.border_color = Color(0.40, 0.30, 0.60, 0.5)
		bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
		bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
		bg.border_width_left = 1; bg.border_width_right = 1
		bg.border_width_top = 1; bg.border_width_bottom = 1
		btn.add_theme_stylebox_override("normal", bg)
		btn.add_theme_stylebox_override("hover", bg)
		btn.add_theme_color_override("font_color", TEXT_BRIGHT if active else TEXT_DIM)

func _build_creature_list(left: Panel) -> void:
	var cats := build_categories()
	var y: float = 14.0
	for cat in cats:
		var cat_label := Label.new()
		cat_label.text = tr(cat["label"])
		cat_label.add_theme_font_size_override("font_size", 18)
		cat_label.add_theme_color_override("font_color", TEXT_DIM)
		cat_label.position = Vector2(10, y)
		cat_label.size = Vector2(230, 22)
		left.add_child(cat_label)
		_cat_labels.append(cat_label)
		y += 28.0
		for entry in cat["entries"]:
			var btn := Button.new()
			btn.position = Vector2(8, y)
			btn.size = Vector2(234, 44)
			btn.text = "  " + entry["name"]
			btn.add_theme_font_size_override("font_size", 20)
			btn.add_theme_color_override("font_color", TEXT_BRIGHT)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var btn_bg := StyleBoxFlat.new()
			btn_bg.bg_color = Color(0.14, 0.10, 0.22, 0.85)
			btn_bg.corner_radius_top_left = 6; btn_bg.corner_radius_top_right = 6
			btn_bg.corner_radius_bottom_left = 6; btn_bg.corner_radius_bottom_right = 6
			btn_bg.border_width_left = 1; btn_bg.border_width_right = 1
			btn_bg.border_width_top = 1; btn_bg.border_width_bottom = 1
			btn_bg.border_color = Color(0.40, 0.30, 0.60, 0.5)
			btn.add_theme_stylebox_override("normal", btn_bg)
			btn.add_theme_stylebox_override("hover", btn_bg)
			btn.pressed.connect(_on_select.bind(entry["id"]))
			left.add_child(btn)
			_btn_group.append(btn)
			y += 50.0

func build_categories() -> Array:
	var party := { "label": "LIB_SECTION_PARTY", "entries": [] }
	var fish := { "label": "LIB_SECTION_FISH", "entries": [] }
	for c in CREATURES:
		if c["cat"] == "party":
			party["entries"].append({ "id": c["id"], "name": c["name"] })
		else:
			fish["entries"].append({ "id": c["id"], "name": c["name"] })
	return [party, fish]

func _build_creature_preview(right: Panel) -> void:
	_preview_name = Label.new()
	_preview_name.position = Vector2(20, 12)
	_preview_name.size = Vector2(400, 36)
	_preview_name.add_theme_font_size_override("font_size", 34)
	_preview_name.add_theme_color_override("font_color", TEXT_BRIGHT)
	_preview_name.add_theme_color_override("font_shadow_color", Color(0.30, 0.15, 0.50, 0.8))
	_preview_name.add_theme_constant_override("shadow_offset_x", 1)
	_preview_name.add_theme_constant_override("shadow_offset_y", 1)
	right.add_child(_preview_name)

	_preview_element = Label.new()
	_preview_element.position = Vector2(20, 48)
	_preview_element.size = Vector2(400, 26)
	_preview_element.add_theme_font_size_override("font_size", 22)
	right.add_child(_preview_element)

	_stats_title = Label.new()
	_stats_title.text = tr("LIB_HEADER_STATS")
	_stats_title.position = Vector2(20, 82)
	_stats_title.size = Vector2(400, 22)
	_stats_title.add_theme_font_size_override("font_size", 20)
	_stats_title.add_theme_color_override("font_color", TEAL)
	right.add_child(_stats_title)

	_preview_stats = Label.new()
	_preview_stats.position = Vector2(20, 104)
	_preview_stats.size = Vector2(400, 110)
	_preview_stats.add_theme_font_size_override("font_size", 20)
	_preview_stats.add_theme_color_override("font_color", TEXT_MAIN)
	_preview_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_preview_stats)

	_skills_title = Label.new()
	_skills_title.text = tr("LIB_HEADER_SKILLS")
	_skills_title.position = Vector2(20, 212)
	_skills_title.size = Vector2(400, 22)
	_skills_title.add_theme_font_size_override("font_size", 20)
	_skills_title.add_theme_color_override("font_color", PURPLE)
	right.add_child(_skills_title)

	_preview_skills = Label.new()
	_preview_skills.position = Vector2(20, 236)
	_preview_skills.size = Vector2(400, 180)
	_preview_skills.add_theme_font_size_override("font_size", 18)
	_preview_skills.add_theme_color_override("font_color", TEXT_DIM)
	_preview_skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_preview_skills)

	_spawn_title = Label.new()
	_spawn_title.text = tr("LIB_HEADER_SPAWN")
	_spawn_title.position = Vector2(20, 430)
	_spawn_title.size = Vector2(400, 22)
	_spawn_title.add_theme_font_size_override("font_size", 20)
	_spawn_title.add_theme_color_override("font_color", ORANGE)
	right.add_child(_spawn_title)

	_preview_spawn = Label.new()
	_preview_spawn.position = Vector2(20, 454)
	_preview_spawn.size = Vector2(400, 60)
	_preview_spawn.add_theme_font_size_override("font_size", 20)
	_preview_spawn.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75, 0.85))
	_preview_spawn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_preview_spawn)

func _on_select(id: String) -> void:
	_selected = id
	_update_selection()
	_update_preview()

func _update_selection() -> void:
	for i in range(_btn_group.size()):
		var entry := _find_entry_by_idx(i)
		var selected: bool = entry != null and entry["id"] == _selected
		var bg := StyleBoxFlat.new()
		if selected:
			bg.bg_color = Color(0.30, 0.20, 0.45, 0.9)
			bg.border_color = Color(0.55, 0.35, 0.90, 0.5)
		else:
			bg.bg_color = Color(0.14, 0.10, 0.22, 0.85)
			bg.border_color = Color(0.40, 0.30, 0.60, 0.5)
		bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
		bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
		bg.border_width_left = 1; bg.border_width_right = 1
		bg.border_width_top = 1; bg.border_width_bottom = 1
		_btn_group[i].add_theme_stylebox_override("normal", bg)
		_btn_group[i].add_theme_stylebox_override("hover", bg)

func _update_preview() -> void:
	var data := _find_creature(_selected)
	if data.is_empty():
		_preview_name.text = ""
		_preview_element.text = ""
		_preview_stats.text = ""
		_preview_skills.text = ""
		_preview_spawn.text = ""
		return

	_preview_name.text = data["name"]

	if data["cat"] == "party":
		var el := data["element"] as int
		var sym: String = ELEMENT_SYMBOLS.get(el, "")
		var en: String = _get_element_name(el)
		_preview_element.text = "%s  %s" % [sym, en]
		_preview_stats.text = tr("LIB_STATS_FORMAT") % [data["hp"], data["atk"], data["def"], data["spd"], data["mp"]]
		_preview_skills.text = data.get("skills", "")
		_preview_spawn.text = "📍 " + data["spawn"]
	else:
		_preview_element.text = ""
		_preview_stats.text = tr("LIB_STATS_FORMAT2") % [data["hp"], data["atk"], data["def"], data["spd"]]
		_preview_skills.text = ""
		_preview_spawn.text = "📍 " + data["spawn"]

func _find_entry_by_idx(idx: int) -> Dictionary:
	var flat: Array = []
	for cat in build_categories():
		for e in cat["entries"]:
			flat.append(e)
	if idx < flat.size():
		for c in CREATURES:
			if c["id"] == flat[idx]["id"]:
				return c
	return {}

func _on_close() -> void:
	visible = false

func show_library() -> void:
	visible = true
	if _current_tab == Tab.CREATURES and _selected.is_empty() and CREATURES.size() > 0:
		_on_select(CREATURES[0]["id"])

func _find_creature(id: String) -> Dictionary:
	for c in CREATURES:
		if c["id"] == id:
			return c
	return {}

func show_creature_direct(creature_id: String, parent_control: Control) -> void:
	pass
