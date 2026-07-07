extends Control
class_name CreatureLibrary

var _selected: String = ""
var _creature_list: Array[Dictionary] = []
var _btn_group: Array[Button] = []
var _preview_name: Label
var _preview_element: Label
var _preview_stats: Label
var _preview_skills: Label
var _preview_spawn: Label

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _cam: Camera3D
var _model_root: Node3D

var _cam_rot: float = 0.0

const _PlayerMesh = preload("res://scripts/characters/player/player_mesh.gd")
const _RaptorMesh = preload("res://scripts/characters/raptor/raptor_mesh.gd")
const _DragonMesh = preload("res://scripts/characters/dragon/dragon_mesh.gd")
const _WarriorMesh = preload("res://scripts/characters/warrior/warrior_mesh.gd")
const _BeyordeathMesh = preload("res://scripts/characters/beyordeath/beyordeath_mesh.gd")
const _FishMesh = preload("res://scripts/characters/fish/fish_mesh.gd")

const FISH_COLORS := [
	[Color(0.95, 0.70, 0.10), Color(0.98, 0.95, 0.80), Color(0.85, 0.55, 0.05)],
	[Color(0.30, 0.30, 0.30), Color(0.65, 0.65, 0.65), Color(0.20, 0.20, 0.20)],
	[Color(0.88, 0.55, 0.45), Color(0.95, 0.80, 0.70), Color(0.85, 0.40, 0.30)],
	[Color(0.30, 0.25, 0.15), Color(0.65, 0.60, 0.50), Color(0.20, 0.18, 0.10)],
	[Color(0.92, 0.25, 0.15), Color(0.90, 0.55, 0.45), Color(0.75, 0.15, 0.10)],
	[Color(0.85, 0.35, 0.20), Color(0.92, 0.55, 0.35), Color(0.75, 0.25, 0.15)],
]

const FISH_PATTERN := [
	Color(0.15, 0.10, 0.05),
	Color(0, 0, 0, 0),
	Color(0, 0, 0, 0),
	Color(0, 0, 0, 0),
	Color(0.15, 0.10, 0.08),
	Color(0, 0, 0, 0),
]

const FISH_BODY_Z := [1.0, 1.0, 1.0, 1.8, 1.0, 1.0]

const CREATURES := [
	# Party characters
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
	# Fish
	{ "id": "carp",       "name": "Carp",        "cat": "fish", "fi": 0,
	  "hp": 60, "atk": 0, "def": 0, "spd": 1.4,
	  "spawn": "Silt / Sand lakes" },
	{ "id": "perch",      "name": "Climbing Perch", "cat": "fish", "fi": 1,
	  "hp": 40, "atk": 0, "def": 0, "spd": 2.0,
	  "spawn": "Silt / Sand lakes" },
	{ "id": "tilapia",    "name": "Red Tilapia", "cat": "fish", "fi": 2,
	  "hp": 50, "atk": 0, "def": 0, "spd": 1.8,
	  "spawn": "Silt / Sand lakes" },
	{ "id": "snakehead",  "name": "Snakehead",   "cat": "fish", "fi": 3,
	  "hp": 70, "atk": 0, "def": 0, "spd": 1.5,
	  "spawn": "Silt / Sand lakes" },
	{ "id": "flowerhorn", "name": "Flowerhorn",  "cat": "fish", "fi": 4,
	  "hp": 70, "atk": 25, "def": 5, "spd": 1.2,
	  "spawn": "Silt / Sand lakes" },
	{ "id": "shrimp",     "name": "Freshwater Shrimp", "cat": "fish", "fi": 5,
	  "hp": 15, "atk": 0, "def": 0, "spd": 0.8,
	  "spawn": "Silt / Sand lakes (bottom)" },
]

const ELEMENT_SYMBOLS := { 1: "⚡", 2: "❄", 3: "☣", 5: "🌑", 6: "☀" }
const ELEMENT_NAMES := { 1: "Electric", 2: "Ice", 3: "Decay", 5: "Dark", 6: "Light" }

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
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

	_build_creature_list(bg)
	_build_preview(bg)

func _build_creature_list(bg: Panel) -> void:
	var left := Panel.new()
	left.position = Vector2(16, 54)
	left.size = Vector2(200, 540)
	var left_bg := StyleBoxFlat.new()
	left_bg.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	left_bg.corner_radius_top_left = 10; left_bg.corner_radius_top_right = 10
	left_bg.corner_radius_bottom_left = 10; left_bg.corner_radius_bottom_right = 10
	left_bg.border_width_left = 1; left_bg.border_width_right = 1
	left_bg.border_width_top = 1; left_bg.border_width_bottom = 1
	left_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
	left.add_theme_stylebox_override("panel", left_bg)
	bg.add_child(left)

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

func _build_preview(bg: Panel) -> void:
	var right := Panel.new()
	right.position = Vector2(230, 54)
	right.size = Vector2(714, 540)
	var right_bg := StyleBoxFlat.new()
	right_bg.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	right_bg.corner_radius_top_left = 10; right_bg.corner_radius_top_right = 10
	right_bg.corner_radius_bottom_left = 10; right_bg.corner_radius_bottom_right = 10
	right_bg.border_width_left = 1; right_bg.border_width_right = 1
	right_bg.border_width_top = 1; right_bg.border_width_bottom = 1
	right_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
	right.add_theme_stylebox_override("panel", right_bg)
	bg.add_child(right)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.position = Vector2(340, 10)
	_viewport_container.size = Vector2(360, 360)
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(360, 360)
	_viewport.transparent_bg = true
	_viewport.world_3d = World3D.new()
	_viewport_container.add_child(_viewport)

	_cam = Camera3D.new()
	_cam.position = Vector3(0, 0.5, 2.0)
	_cam.transform.basis = Basis.looking_at(Vector3(0, -0.5, -2.0))
	_viewport.add_child(_cam)

	_model_root = Node3D.new()
	_viewport.add_child(_model_root)

	var world_env := WorldEnvironment.new()
	world_env.environment = Environment.new()
	world_env.environment.ambient_light_color = Color(0.4, 0.4, 0.5)
	world_env.environment.ambient_light_energy = 1.5
	_viewport.add_child(world_env)

	var lbl := Label.new()
	lbl.text = tr("CREATURE_3D_VIEW")
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.6, 0.6))
	lbl.position = Vector2(350, 370)
	lbl.size = Vector2(200, 16)
	right.add_child(lbl)

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

func _on_select(id: String) -> void:
	_selected = id
	_update_selection()
	_update_preview()
	_rebuild_model()

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

func _process(delta: float) -> void:
	if not visible:
		return
	_cam_rot += delta * 0.5
	_cam.position = Vector3(sin(_cam_rot) * 2.0, 0.5, cos(_cam_rot) * 2.0)
	_cam.look_at(Vector3.ZERO)

func show_library() -> void:
	visible = true
	if _selected.is_empty() and CREATURES.size() > 0:
		_on_select(CREATURES[0]["id"])

func _rebuild_model() -> void:
	for c in _model_root.get_children():
		_model_root.remove_child(c)
		c.free()

	if _selected.is_empty():
		return

	var data := _find_creature(_selected)
	if data.is_empty():
		return

	if data["cat"] == "party":
		var body := CharacterBody3D.new()
		_model_root.add_child(body)
		_build_party_mesh(body, data["id"])
	else:
		var body := Node3D.new()
		_model_root.add_child(body)
		_build_fish_mesh(body, data["fi"])

func _find_creature(id: String) -> Dictionary:
	for c in CREATURES:
		if c["id"] == id:
			return c
	return {}

func _build_party_mesh(body: Node3D, id: String) -> void:
	match id:
		"player":
			var pm := _PlayerMesh.new()
			pm.build(body)
		"raptor":
			var rm := _RaptorMesh.new()
			rm.build(body)
		"dragon":
			var dm := _DragonMesh.new()
			dm.build(body)
		"warrior":
			var wm := _WarriorMesh.new()
			wm.build(body)
		"beyordeath":
			var bm := _BeyordeathMesh.new()
			bm.build(body)

func _build_fish_mesh(body: Node3D, fi: int) -> void:
	var cols: Array = FISH_COLORS[fi]
	var fm := _FishMesh.new()
	fm.color_body  = cols[0]
	fm.color_belly = cols[1]
	fm.color_fin   = cols[2]
	fm.color_tail  = (cols[0] as Color) * 0.8
	fm.color_pattern = FISH_PATTERN[fi]
	fm.body_z_scale  = FISH_BODY_Z[fi]
	if fi == 4:
		fm.body_triangular = true
		fm.has_horns = true
	elif fi == 5:
		fm.body_shape = _FishMesh.BodyShape.SHRIMP
	fm.build(body)

func show_creature_direct(creature_id: String, parent_control: Control) -> void:
	pass
