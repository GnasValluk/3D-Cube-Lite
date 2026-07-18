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
const ELEMENT_NAMES := { 1: "Electric", 2: "Ice", 3: "Decay", 5: "Dark", 6: "Light" }

enum Tab { CREATURES, ITEMS }

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

# Item
var _item_left: Panel
var _item_right: Panel
var _item_btn_group: Array[Button] = []
var _item_name_label: Label
var _item_type_label: Label
var _item_desc_label: Label
var _item_stats_label: Label
var _item_db: Dictionary = {}

# Tab
var _tab_buttons: Array[Button] = []



func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	ItemDatabase.ensure_db()
	_item_db = ItemDatabase.items_db
	_build()

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var W: float = 960.0
	var H: float = 640.0
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
	title.text = tr("CREATURE_LIBRARY_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.position = Vector2(0, 10)
	title.size = Vector2(W, 34)
	bg.add_child(title)

	var close_btn := Button.new()
	close_btn.position = Vector2(W - 40, 8)
	close_btn.size = Vector2(32, 32)
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.8))
	var cb_bg := StyleBoxFlat.new()
	cb_bg.bg_color = Color(0, 0, 0, 0)
	close_btn.add_theme_stylebox_override("normal", cb_bg)
	close_btn.add_theme_stylebox_override("hover", cb_bg)
	close_btn.pressed.connect(_on_close)
	bg.add_child(close_btn)

	var div := ColorRect.new()
	div.position = Vector2(30, 46)
	div.size = Vector2(W - 60, 2)
	div.color = Color(0.3, 0.3, 0.45, 0.4)
	bg.add_child(div)

	_build_tabs(bg, W)

	_creature_left = _make_side_panel(bg, 16, 90, 200, 510)
	_creature_right = _make_side_panel(bg, 230, 90, 714, 510)
	_build_creature_list(_creature_left)
	_build_creature_preview(_creature_right)

	_item_left = _make_side_panel(bg, 16, 90, 200, 510)
	_item_right = _make_side_panel(bg, 230, 90, 714, 510)
	_build_item_list(_item_left)
	_build_item_preview(_item_right)

	_update_tab_visibility()

func _make_side_panel(bg: Panel, x: float, y: float, w: float, h: float) -> Panel:
	var p := Panel.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	s.corner_radius_top_left = 10; s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10; s.corner_radius_bottom_right = 10
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	s.border_color = Color(0.25, 0.25, 0.35, 0.5)
	p.add_theme_stylebox_override("panel", s)
	bg.add_child(p)
	return p

func _build_tabs(bg: Panel, W: float) -> void:
	var tab_data := [
		{ "id": Tab.CREATURES, "label": "Sinh vật" },
		{ "id": Tab.ITEMS,     "label": "Vật phẩm" },
	]
	var tab_y: float = 50.0
	var tw: float = 110.0
	var th: float = 34.0
	var start_x: float = 30.0
	for i in range(tab_data.size()):
		var d: Dictionary = tab_data[i]
		var btn := Button.new()
		btn.position = Vector2(start_x + i * (tw + 4), tab_y)
		btn.size = Vector2(tw, th)
		btn.text = d["label"]
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_tab_selected.bind(d["id"]))
		bg.add_child(btn)
		_tab_buttons.append(btn)
	_update_tab_styles()



func _on_tab_selected(tab: int) -> void:
	if _current_tab == tab:
		return
	_current_tab = tab
	_selected = ""
	_update_tab_visibility()
	if _current_tab == Tab.CREATURES and CREATURES.size() > 0:
		_on_select(CREATURES[0]["id"])
	elif _current_tab == Tab.ITEMS:
		var ids := _item_db.keys()
		if ids.size() > 0:
			_on_item_select(ids[0])



func _update_tab_visibility() -> void:
	_creature_left.visible = _current_tab == Tab.CREATURES
	_creature_right.visible = _current_tab == Tab.CREATURES
	_item_left.visible = _current_tab == Tab.ITEMS
	_item_right.visible = _current_tab == Tab.ITEMS
	_update_tab_styles()

func _update_tab_styles() -> void:
	for i in range(_tab_buttons.size()):
		var btn: Button = _tab_buttons[i]
		var active: bool = (i == _current_tab)
		var bg := StyleBoxFlat.new()
		if active:
			bg.bg_color = Color(0.18, 0.22, 0.38, 0.95)
			bg.border_color = Color(0.4, 0.55, 0.9, 0.5)
		else:
			bg.bg_color = Color(0.08, 0.08, 0.14, 0.85)
			bg.border_color = Color(0.3, 0.3, 0.45, 0.5)
		bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
		bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
		bg.border_width_left = 1; bg.border_width_right = 1
		bg.border_width_top = 1; bg.border_width_bottom = 1
		btn.add_theme_stylebox_override("normal", bg)
		btn.add_theme_stylebox_override("hover", bg)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.9) if active else Color(0.7, 0.7, 0.85, 0.8))

func _build_creature_list(left: Panel) -> void:
	var cats := build_categories()
	var y: float = 10.0
	for cat in cats:
		var cat_label := Label.new()
		cat_label.text = cat["label"]
		cat_label.add_theme_font_size_override("font_size", 12)
		cat_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7, 0.8))
		cat_label.position = Vector2(10, y)
		cat_label.size = Vector2(180, 18)
		left.add_child(cat_label)
		y += 22.0
		for entry in cat["entries"]:
			var btn := Button.new()
			btn.position = Vector2(8, y)
			btn.size = Vector2(184, 34)
			btn.text = "  " + entry["name"]
			btn.add_theme_font_size_override("font_size", 13)
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var btn_bg := StyleBoxFlat.new()
			btn_bg.bg_color = Color(0.1, 0.1, 0.18, 0.85)
			btn_bg.corner_radius_top_left = 6; btn_bg.corner_radius_top_right = 6
			btn_bg.corner_radius_bottom_left = 6; btn_bg.corner_radius_bottom_right = 6
			btn_bg.border_width_left = 1; btn_bg.border_width_right = 1
			btn_bg.border_width_top = 1; btn_bg.border_width_bottom = 1
			btn_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
			btn.add_theme_stylebox_override("normal", btn_bg)
			btn.add_theme_stylebox_override("hover", btn_bg)
			btn.pressed.connect(_on_select.bind(entry["id"]))
			left.add_child(btn)
			_btn_group.append(btn)
			y += 40.0

func build_categories() -> Array:
	var party := { "label": "— PARTY —", "entries": [] }
	var fish := { "label": "— FISH —", "entries": [] }
	for c in CREATURES:
		if c["cat"] == "party":
			party["entries"].append({ "id": c["id"], "name": c["name"] })
		else:
			fish["entries"].append({ "id": c["id"], "name": c["name"] })
	return [party, fish]

func _build_creature_preview(right: Panel) -> void:
	_preview_name = Label.new()
	_preview_name.position = Vector2(16, 10)
	_preview_name.size = Vector2(320, 28)
	_preview_name.add_theme_font_size_override("font_size", 22)
	_preview_name.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_preview_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_preview_name.add_theme_constant_override("shadow_offset_x", 1)
	_preview_name.add_theme_constant_override("shadow_offset_y", 1)
	right.add_child(_preview_name)

	_preview_element = Label.new()
	_preview_element.position = Vector2(16, 38)
	_preview_element.size = Vector2(320, 20)
	_preview_element.add_theme_font_size_override("font_size", 14)
	right.add_child(_preview_element)

	var stats_title := Label.new()
	stats_title.text = "STATS"
	stats_title.position = Vector2(16, 64)
	stats_title.size = Vector2(320, 18)
	stats_title.add_theme_font_size_override("font_size", 13)
	stats_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8, 0.7))
	right.add_child(stats_title)

	_preview_stats = Label.new()
	_preview_stats.position = Vector2(16, 82)
	_preview_stats.size = Vector2(320, 90)
	_preview_stats.add_theme_font_size_override("font_size", 13)
	_preview_stats.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95, 0.9))
	_preview_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_preview_stats)

	var skills_title := Label.new()
	skills_title.text = "SKILLS"
	skills_title.position = Vector2(16, 168)
	skills_title.size = Vector2(320, 18)
	skills_title.add_theme_font_size_override("font_size", 13)
	skills_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8, 0.7))
	right.add_child(skills_title)

	_preview_skills = Label.new()
	_preview_skills.position = Vector2(16, 186)
	_preview_skills.size = Vector2(320, 150)
	_preview_skills.add_theme_font_size_override("font_size", 12)
	_preview_skills.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85, 0.85))
	_preview_skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_preview_skills)

	var spawn_title := Label.new()
	spawn_title.text = "SPAWN"
	spawn_title.position = Vector2(16, 340)
	spawn_title.size = Vector2(320, 18)
	spawn_title.add_theme_font_size_override("font_size", 13)
	spawn_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8, 0.7))
	right.add_child(spawn_title)

	_preview_spawn = Label.new()
	_preview_spawn.position = Vector2(16, 358)
	_preview_spawn.size = Vector2(320, 50)
	_preview_spawn.add_theme_font_size_override("font_size", 13)
	_preview_spawn.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75, 0.85))
	_preview_spawn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_preview_spawn)

func _build_item_list(left: Panel) -> void:
	var type_order: Array = [
		ItemDef.Type.BLOCK, ItemDef.Type.TOOL, ItemDef.Type.WEAPON,
		ItemDef.Type.FOOD, ItemDef.Type.MATERIAL
	]
	var type_labels := {
		ItemDef.Type.BLOCK: "— BLOCK —",
		ItemDef.Type.TOOL: "— TOOL —",
		ItemDef.Type.WEAPON: "— WEAPON —",
		ItemDef.Type.FOOD: "— FOOD —",
		ItemDef.Type.MATERIAL: "— MATERIAL —",
	}
	var by_type: Dictionary = {}
	for id in _item_db:
		var item: ItemDef = _item_db[id]
		if not by_type.has(item.type):
			by_type[item.type] = []
		by_type[item.type].append(item)
	for t in type_order:
		var arr: Array = by_type.get(t, []).duplicate()
		arr.sort_custom(func(a, b): return a.name < b.name)
		by_type[t] = arr

	var y: float = 8.0
	for t in type_order:
		var items: Array = by_type.get(t, [])
		if items.is_empty():
			continue
		var cat_label := Label.new()
		cat_label.text = type_labels.get(t, "")
		cat_label.add_theme_font_size_override("font_size", 12)
		cat_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7, 0.8))
		cat_label.position = Vector2(10, y)
		cat_label.size = Vector2(180, 18)
		left.add_child(cat_label)
		y += 20.0

		for item in items:
			var btn := Button.new()
			btn.position = Vector2(8, y)
			btn.size = Vector2(184, 34)
			btn.text = "  " + item.name
			btn.add_theme_font_size_override("font_size", 13)
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var btn_bg := StyleBoxFlat.new()
			btn_bg.bg_color = Color(0.1, 0.1, 0.18, 0.85)
			btn_bg.corner_radius_top_left = 6; btn_bg.corner_radius_top_right = 6
			btn_bg.corner_radius_bottom_left = 6; btn_bg.corner_radius_bottom_right = 6
			btn_bg.border_width_left = 1; btn_bg.border_width_right = 1
			btn_bg.border_width_top = 1; btn_bg.border_width_bottom = 1
			btn_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
			btn.add_theme_stylebox_override("normal", btn_bg)
			btn.add_theme_stylebox_override("hover", btn_bg)
			btn.pressed.connect(_on_item_select.bind(item.id))
			left.add_child(btn)
			_item_btn_group.append(btn)
			y += 38.0

func _build_item_preview(right: Panel) -> void:
	_item_name_label = Label.new()
	_item_name_label.position = Vector2(370, 10)
	_item_name_label.size = Vector2(320, 28)
	_item_name_label.add_theme_font_size_override("font_size", 22)
	_item_name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_item_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_item_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_item_name_label.add_theme_constant_override("shadow_offset_y", 1)
	right.add_child(_item_name_label)

	_item_type_label = Label.new()
	_item_type_label.position = Vector2(370, 38)
	_item_type_label.size = Vector2(320, 20)
	_item_type_label.add_theme_font_size_override("font_size", 13)
	right.add_child(_item_type_label)

	var desc_title := Label.new()
	desc_title.text = "MÔ TẢ"
	desc_title.position = Vector2(370, 64)
	desc_title.size = Vector2(320, 18)
	desc_title.add_theme_font_size_override("font_size", 13)
	desc_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8, 0.7))
	right.add_child(desc_title)

	_item_desc_label = Label.new()
	_item_desc_label.position = Vector2(370, 82)
	_item_desc_label.size = Vector2(320, 60)
	_item_desc_label.add_theme_font_size_override("font_size", 13)
	_item_desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95, 0.9))
	_item_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_item_desc_label)

	var stats_title := Label.new()
	stats_title.text = "CHỈ SỐ"
	stats_title.position = Vector2(370, 148)
	stats_title.size = Vector2(320, 18)
	stats_title.add_theme_font_size_override("font_size", 13)
	stats_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8, 0.7))
	right.add_child(stats_title)

	_item_stats_label = Label.new()
	_item_stats_label.position = Vector2(370, 166)
	_item_stats_label.size = Vector2(320, 120)
	_item_stats_label.add_theme_font_size_override("font_size", 13)
	_item_stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95, 0.9))
	_item_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_item_stats_label)

func _on_select(id: String) -> void:
	_selected = id
	_update_selection()
	_update_preview()

func _on_item_select(id: String) -> void:
	_selected = id
	_update_item_selection()
	_update_item_preview()

func _update_selection() -> void:
	for i in range(_btn_group.size()):
		var entry := _find_entry_by_idx(i)
		var selected: bool = entry != null and entry["id"] == _selected
		var bg := StyleBoxFlat.new()
		if selected:
			bg.bg_color = Color(0.18, 0.22, 0.35, 0.9)
			bg.border_color = Color(0.4, 0.55, 0.9, 0.5)
		else:
			bg.bg_color = Color(0.1, 0.1, 0.18, 0.85)
			bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
		bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
		bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
		bg.border_width_left = 1; bg.border_width_right = 1
		bg.border_width_top = 1; bg.border_width_bottom = 1
		_btn_group[i].add_theme_stylebox_override("normal", bg)
		_btn_group[i].add_theme_stylebox_override("hover", bg)

func _update_item_selection() -> void:
	for i in range(_item_btn_group.size()):
		var item := _find_item_by_btn_idx(i)
		var selected: bool = item != null and item.id == _selected
		var bg := StyleBoxFlat.new()
		if selected:
			bg.bg_color = Color(0.18, 0.22, 0.35, 0.9)
			bg.border_color = Color(0.4, 0.55, 0.9, 0.5)
		else:
			bg.bg_color = Color(0.1, 0.1, 0.18, 0.85)
			bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
		bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
		bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
		bg.border_width_left = 1; bg.border_width_right = 1
		bg.border_width_top = 1; bg.border_width_bottom = 1
		_item_btn_group[i].add_theme_stylebox_override("normal", bg)
		_item_btn_group[i].add_theme_stylebox_override("hover", bg)

func _find_item_by_btn_idx(idx: int) -> ItemDef:
	var flat: Array[ItemDef] = []
	var type_order := [ItemDef.Type.BLOCK, ItemDef.Type.TOOL, ItemDef.Type.WEAPON, ItemDef.Type.FOOD, ItemDef.Type.MATERIAL]
	for t in type_order:
		var items: Array[ItemDef] = []
		for id in _item_db:
			var item: ItemDef = _item_db[id]
			if item.type == t:
				items.append(item)
		items.sort_custom(func(a, b): return a.name < b.name)
		flat.append_array(items)
	if idx < flat.size():
		return flat[idx]
	return null

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
		var en: String = ELEMENT_NAMES.get(el, "")
		_preview_element.text = "%s  %s" % [sym, en]
		_preview_stats.text = "HP: %d   ATK: %d   DEF: %d   SPD: %.1f   MP: %d" % [data["hp"], data["atk"], data["def"], data["spd"], data["mp"]]
		_preview_skills.text = data.get("skills", "")
		_preview_spawn.text = "📍 " + data["spawn"]
	else:
		_preview_element.text = ""
		_preview_stats.text = "HP: %d   ATK: %d   DEF: %d   SPD: %.1f" % [data["hp"], data["atk"], data["def"], data["spd"]]
		_preview_skills.text = ""
		_preview_spawn.text = "📍 " + data["spawn"]

func _update_item_preview() -> void:
	var item: ItemDef = _item_db.get(_selected)
	if item == null:
		_item_name_label.text = ""
		_item_type_label.text = ""
		_item_desc_label.text = ""
		_item_stats_label.text = ""
		return
	_item_name_label.text = item.name
	_item_type_label.text = "[ " + item.get_type_name() + " ]"
	_item_type_label.add_theme_color_override("font_color", _type_color(item.type))
	_item_desc_label.text = item.desc

	var stats: String = ""
	if item.atk_bonus > 0:  stats += "ATK: +%d\n" % item.atk_bonus
	if item.def_bonus > 0:  stats += "DEF: +%d\n" % item.def_bonus
	if item.heal_amount > 0: stats += "Hồi: +%d HP\n" % item.heal_amount
	if item.stackable:       stats += "Xếp chồng: %d\n" % item.max_stack
	if not item.stackable:   stats += "Không thể xếp chồng\n"
	if stats.is_empty():     stats = "Không có chỉ số đặc biệt"
	_item_stats_label.text = stats

func _type_color(type: int) -> Color:
	match type:
		ItemDef.Type.BLOCK:    return Color(0.54, 0.32, 0.12)
		ItemDef.Type.TOOL:     return Color(0.65, 0.55, 0.40)
		ItemDef.Type.WEAPON:   return Color(0.75, 0.30, 0.30)
		ItemDef.Type.FOOD:     return Color(0.30, 0.80, 0.30)
		ItemDef.Type.MATERIAL: return Color(0.80, 0.75, 0.30)
		_:                     return Color(0.7, 0.7, 0.7)

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
	elif _current_tab == Tab.ITEMS:
		var ids := _item_db.keys()
		if ids.size() > 0:
			_on_item_select(ids[0])

func _find_creature(id: String) -> Dictionary:
	for c in CREATURES:
		if c["id"] == id:
			return c
	return {}

func show_creature_direct(creature_id: String, parent_control: Control) -> void:
	pass
