extends Node3D
class_name WorldVoxelBars

const BAR_OFFSET_Y: float = 3.2
const SUB_W: int = 880
const SUB_H: int = 340
const WORLD_W: float = 3.84
const WORLD_H: float = 1.2
const VS: float = 6.0

# ── Màu nền hộp LEVEL theo cấp độ người chơi (tối đa 100) ──
const LV_TIERS: Array[Dictionary] = [
	{ "lv": 0,   "color": Color(0.12, 0.30, 0.14, 0.70) },
	{ "lv": 20,  "color": Color(0.12, 0.45, 0.30, 0.72) },
	{ "lv": 40,  "color": Color(0.16, 0.45, 0.72, 0.72) },
	{ "lv": 60,  "color": Color(0.45, 0.35, 0.80, 0.72) },
	{ "lv": 80,  "color": Color(0.80, 0.35, 0.70, 0.72) },
	{ "lv": 100, "color": Color(0.95, 0.75, 0.15, 0.75) },
]

var _player: CharacterBase
var _sub_viewport: SubViewport
var _health_vbar: VoxelBar
var _food_vbar: VoxelBar
var _oxygen_vbar: VoxelBar
var _level_box: ColorRect
var _level_label: Label
var _effects_label: Label
var _effects_icon: ColorRect

func _get_level_color(lv: int) -> Color:
	for t in LV_TIERS:
		if lv <= t["lv"]:
			return t["color"]
	return LV_TIERS[-1]["color"]

func setup(target: CharacterBase) -> void:
	_player = target
	position = Vector3(0, BAR_OFFSET_Y, 0)
	_build()
	target.hp_changed.connect(_on_hp_changed)
	target.oxygen_changed.connect(_on_oxygen_changed)
	if target.has_signal("food_changed"):
		target.food_changed.connect(_on_food_changed)
	if target.has_signal("level_up"):
		target.level_up.connect(func(_lv: int): _update_level())
	_on_hp_changed(target.hp, target.max_hp)
	_on_oxygen_changed(int(target.oxygen), int(target.max_oxygen))

func _build() -> void:
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(SUB_W, SUB_H)
	_sub_viewport.transparent_bg = true
	_sub_viewport.handle_input_locally = false
	_sub_viewport.disable_3d = true
	add_child(_sub_viewport)

	var root := Control.new()
	root.size = Vector2(SUB_W, SUB_H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_viewport.add_child(root)

	# ── Oxygen bar (separate, above) ──
	var ob := VoxelBar.new()
	ob.setup(Color(0.20, 0.68, 0.92), Color(0.03, 0.12, 0.18), 16, 100)
	ob.position = Vector2(72, 18)
	ob.scale = Vector2(VS, VS)
	root.add_child(ob)
	_oxygen_vbar = ob

	# ── Cấp độ người chơi (nền màu theo level, số = level) ──
	_level_box = ColorRect.new()
	_level_box.size = Vector2(74, 140)
	_level_box.position = Vector2(8, 116)
	_level_box.color = _get_level_color(_player.level)
	_level_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_level_box)

	var level_border := ColorRect.new()
	level_border.color = Color(1, 1, 1, 0.06)
	level_border.size = Vector2(74, 140)
	level_border.position = Vector2(8, 116)
	level_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(level_border)

	# LEVEL number
	_level_label = Label.new()
	_level_label.text = str(_player.level)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.size = Vector2(74, 40)
	_level_label.position = Vector2(8, 192)
	_level_label.add_theme_font_size_override("font_size", 34)
	_level_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
	root.add_child(_level_label)

	var lv_text := Label.new()
	lv_text.text = "LV"
	lv_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_text.size = Vector2(74, 18)
	lv_text.position = Vector2(8, 230)
	lv_text.add_theme_font_size_override("font_size", 13)
	lv_text.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	root.add_child(lv_text)

	# ── HP row ──
	var hb := VoxelBar.new()
	hb.setup(Color(0.78, 0.14, 0.14), Color(0.18, 0.04, 0.04), 16, 20)
	hb.position = Vector2(92, 116)
	hb.scale = Vector2(VS, VS)
	root.add_child(hb)
	_health_vbar = hb

	# ── Food row (same width as HP) ──
	var fb := VoxelBar.new()
	fb.setup(Color(0.77, 0.55, 0.10), Color(0.15, 0.10, 0.03), 16, 20)
	fb.position = Vector2(92, 206)
	fb.scale = Vector2(VS, VS)
	root.add_child(fb)
	_food_vbar = fb

	# ── Hiệu ứng trạng thái (icon + cấp độ) bên dưới thanh thức ăn ──
	_effects_icon = ColorRect.new()
	_effects_icon.color = Color(0.35, 0.70, 0.95, 0.22)
	_effects_icon.size = Vector2(44, 40)
	_effects_icon.position = Vector2(92, 258)
	_effects_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_icon.visible = false
	root.add_child(_effects_icon)

	_effects_label = Label.new()
	_effects_label.add_theme_font_size_override("font_size", 26)
	_effects_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 0.95))
	_effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effects_label.size = Vector2(44, 34)
	_effects_label.position = Vector2(92, 258)
	_effects_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_label.visible = false
	root.add_child(_effects_label)

	# ── 3D mesh ──
	var quad := QuadMesh.new()
	quad.size = Vector2(WORLD_W, WORLD_H)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _sub_viewport.get_texture()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_keep_scale = true

	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = mat
	add_child(mesh)

func _on_hp_changed(current: int, max_hp_val: int) -> void:
	if not is_instance_valid(_player): return
	_health_vbar.value = current
	_update_level()

func _update_level() -> void:
	if not is_instance_valid(_player): return
	_level_label.text = str(_player.level)
	_level_box.color = _get_level_color(_player.level)

func _on_food_changed(current: int, max_food_val: int) -> void:
	if not is_instance_valid(_player): return
	if max_food_val <= 0: return
	_food_vbar.value = current

func _on_oxygen_changed(current: int, max_oxy: int) -> void:
	if not is_instance_valid(_player): return
	if max_oxy <= 0:
		_oxygen_vbar.visible = false
		return
	_oxygen_vbar.value = current
	_oxygen_vbar.visible = current < max_oxy

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var lvl: int = 0
	if _player.effects != null:
		lvl = _player.effects.get_slow_level()
	var has_slow: bool = lvl > 0
	_effects_icon.visible = has_slow
	_effects_label.visible = has_slow
	if has_slow:
		_effects_label.text = "\u2744 " + str(lvl)
