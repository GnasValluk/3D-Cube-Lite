extends Node3D
class_name WorldVoxelBars

const BAR_OFFSET_Y: float = 3.2
const SUB_W: int = 880
const SUB_H: int = 340
const WORLD_W: float = 3.84
const WORLD_H: float = 1.2
const VS: float = 6.0

const DEF_TIERS: Array[Dictionary] = [
	{ "max": 0, "color": Color(0.15, 0.10, 0.20, 0.10) },
	{ "max": 2, "color": Color(0.55, 0.41, 0.08, 0.55)  },
	{ "max": 4, "color": Color(0.72, 0.45, 0.20, 0.60)  },
	{ "max": 7, "color": Color(0.65, 0.65, 0.65, 0.65)  },
	{ "max": 10, "color": Color(0.95, 0.80, 0.10, 0.65) },
	{ "max": 14, "color": Color(0.20, 0.85, 0.45, 0.65) },
	{ "max": 18, "color": Color(0.10, 0.75, 0.85, 0.70) },
	{ "max": 999, "color": Color(0.60, 0.20, 0.80, 0.75) },
]

var _player: CharacterBase
var _sub_viewport: SubViewport
var _health_vbar: VoxelBar
var _food_vbar: VoxelBar
var _oxygen_vbar: VoxelBar
var _shield_box: ColorRect
var _def_label: Label

func _get_def_tier(def_val: int) -> Color:
	for t in DEF_TIERS:
		if def_val <= t["max"]:
			return t["color"]
	return DEF_TIERS[-1]["color"]

func setup(target: CharacterBase) -> void:
	_player = target
	position = Vector3(0, BAR_OFFSET_Y, 0)
	_build()
	target.hp_changed.connect(_on_hp_changed)
	target.oxygen_changed.connect(_on_oxygen_changed)
	if target.has_signal("food_changed"):
		target.food_changed.connect(_on_food_changed)
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

	# ── Shield indicator ──
	_shield_box = ColorRect.new()
	_shield_box.size = Vector2(74, 140)
	_shield_box.position = Vector2(8, 116)
	_shield_box.color = DEF_TIERS[0]["color"]
	_shield_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shield_box)

	var shield_border := ColorRect.new()
	shield_border.color = Color(1, 1, 1, 0.06)
	shield_border.size = Vector2(74, 140)
	shield_border.position = Vector2(8, 116)
	shield_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shield_border)

	# Shield icon
	var sb := ColorRect.new()
	sb.color = Color(1, 1, 1, 0.15)
	sb.size = Vector2(34, 50)
	sb.position = Vector2(28, 126)
	sb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sb)

	var st := ColorRect.new()
	st.color = Color(1, 1, 1, 0.15)
	st.size = Vector2(26, 16)
	st.position = Vector2(32, 112)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(st)

	# DEF number
	_def_label = Label.new()
	_def_label.text = "0"
	_def_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_def_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_def_label.size = Vector2(74, 40)
	_def_label.position = Vector2(8, 192)
	_def_label.add_theme_font_size_override("font_size", 34)
	_def_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.80))
	root.add_child(_def_label)

	var dt := Label.new()
	dt.text = "DEF"
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dt.size = Vector2(74, 18)
	dt.position = Vector2(8, 230)
	dt.add_theme_font_size_override("font_size", 13)
	dt.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	root.add_child(dt)

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
	var def_val: int = _player.defense
	_shield_box.color = _get_def_tier(def_val)
	_def_label.text = str(def_val)

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
