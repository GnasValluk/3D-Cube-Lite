extends Node3D

enum Category { BLOCKS, ITEMS, CHARACTERS, ENVIRONMENT }
const CATEGORY_NAMES := ["Blocks", "Items", "Characters", "Environment"]

const BLOCK_IDS := [1, 2, 3, 4, 5, 7, 8, 9, 10, 11]
const ITEM_IDS := ["cup", "xeng", "riu", "kiem", "can_cau", "chest", "twilight_gate"]
const CHAR_NAMES := ["Player", "Raptor", "Dragon", "Warrior", "Beyordeath", "Dummy",
	"Ca Chep", "Ca Ro", "Ca Tram", "Ca Mong", "Ca Vang", "Ca Linh", "Ca La Han", "Tom"]
const ENV_NAMES := ["Rong Nhiet Doi", "Sen Thach Anh"]

const CHAR_ANIMS := {
	"Player": ["IDLE", "WALK", "SPRINT", "CROUCH", "DASH", "ATTACK", "JUMP", "FALL", "SWIM", "HIT", "DEAD"],
	"Raptor": ["IDLE", "WALK", "SPRINT", "DASH", "ATTACK", "DEVOUR", "JUMP", "FALL", "HIT", "DEAD"],
	"Dragon": ["IDLE", "WALK", "SPRINT", "DASH", "ATTACK", "DEVOUR", "JUMP", "FALL", "HIT", "DEAD", "FLY"],
	"Warrior": ["IDLE", "WALK", "SPRINT", "DASH", "ATTACK", "DEVOUR", "JUMP", "FALL", "HIT", "DEAD"],
	"Beyordeath": ["IDLE", "WALK", "SPRINT", "DASH", "ATTACK", "DEVOUR", "JUMP", "FALL", "HIT", "DEAD"],
	"Dummy": ["Rotate"],
	"Ca Chep": ["SWIM", "IDLE"],
	"Ca Ro": ["SWIM", "IDLE"],
	"Ca Tram": ["SWIM", "IDLE"],
	"Ca Mong": ["SWIM", "IDLE"],
	"Ca Vang": ["SWIM", "IDLE"],
	"Ca Linh": ["SWIM", "IDLE"],
	"Ca La Han": ["SWIM", "IDLE"],
	"Tom": ["SWIM", "IDLE"],
}

const ITEM_ANIMS := {
	"chest": ["Closed", "Open"],
}

const _CD = preload("res://scripts/world/chunk/chunk_data.gd")
const _WM = preload("res://scripts/characters/player/weapon_mesh.gd")
const _PlayerMesh = preload("res://scripts/characters/player/player_mesh.gd")
const _RaptorMesh = preload("res://scripts/characters/raptor/raptor_mesh.gd")
const _DragonMesh = preload("res://scripts/characters/dragon/dragon_mesh.gd")
const _WarriorMesh = preload("res://scripts/characters/warrior/warrior_mesh.gd")
const _BeyordeathMesh = preload("res://scripts/characters/beyordeath/beyordeath_mesh.gd")
const _FishMesh = preload("res://scripts/characters/fish/fish_mesh.gd")
const _FishAnim = preload("res://scripts/characters/fish/fish_animator.gd")
const _Aquatic = preload("res://scripts/world/chunk/chunk_aquatic.gd")

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

var _category: int = Category.BLOCKS
var _index: int = 0

var _container: Node3D
var _label: Label
var _cam: Camera3D
var _gizmo: Control
var _anim_panel: VBoxContainer
var _anim_buttons: Array[Button] = []
var _selected_anim: int = -1

var _current_root: Node3D
var _anim_driver
var _fish_anim

var _chest_lid: Node3D
var _chest_open: bool = false

var _yaw: float = 0.0
var _pitch: float = -25.0
var _dist: float = 3.0
var _target_pos: Vector3 = Vector3.ZERO
var _drag_start: Vector2
var _drag_button: int = -1
var _auto_rotate: bool = true

var _debug_open: bool = false
var _debug_panel: Panel
var _debug_ts_label: Label
var _debug_hour_slider: HSlider
var _debug_speed_slider: HSlider
var _debug_weather_btn: Button

func _ready() -> void:
	_container = $ModelAnchor
	_label = $CanvasLayer/Label
	_cam = $Camera3D
	_gizmo = $CanvasLayer/AxisGizmo
	_gizmo.camera = _cam
	_gizmo.view_rotated.connect(_on_gizmo_rotate)
	_gizmo.view_snapped.connect(_on_gizmo_snap)
	_build_grid()
	_setup_anim_panel()
	_setup_debug_menu()
	_refresh()

func _build_grid() -> void:
	var ground := MeshInstance3D.new()
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.15, 0.15, 0.18, 0.6)
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gmesh := BoxMesh.new()
	gmesh.size = Vector3(10.0, 0.01, 10.0)
	ground.mesh = gmesh
	ground.material_override = gmat
	ground.position.y = -0.3
	add_child(ground)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.3, 0.3, 0.35, 0.3)
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var step := 1.0
	for i in range(-5, 6):
		var lx := MeshInstance3D.new()
		var lz := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.01, 0.005, 10.0)
		lx.mesh = lm
		lx.material_override = lmat
		lx.position = Vector3(i * step, -0.29, 0.0)
		add_child(lx)
		var lm2 := BoxMesh.new()
		lm2.size = Vector3(10.0, 0.005, 0.01)
		lz.mesh = lm2
		lz.material_override = lmat
		lz.position = Vector3(0.0, -0.29, i * step)
		add_child(lz)

func _setup_anim_panel() -> void:
	var panel_bg := Panel.new()
	panel_bg.name = "AnimPanelBg"
	panel_bg.size = Vector2(160, 0)
	panel_bg.position = Vector2(8, 56)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.12, 0.80)
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = Color(1, 1, 1, 0.10)
	panel_bg.add_theme_stylebox_override("panel", bg)
	$CanvasLayer.add_child(panel_bg)

	var title := Label.new()
	title.position = Vector2(14, 4)
	title.size = Vector2(140, 20)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.70, 0.70, 0.85, 0.7))
	title.text = "ANIMATIONS"
	panel_bg.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "AnimScroll"
	scroll.position = Vector2(6, 24)
	scroll.size = Vector2(148, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_bg.add_child(scroll)

	_anim_panel = VBoxContainer.new()
	_anim_panel.name = "AnimList"
	_anim_panel.size = Vector2(136, 0)
	_anim_panel.add_theme_constant_override("separation", 2)
	scroll.add_child(_anim_panel)

func _update_anim_panel() -> void:
	for b in _anim_buttons:
		b.queue_free()
	_anim_buttons.clear()
	_selected_anim = -1
	var anims = []
	match _category:
		Category.CHARACTERS:
			var name := _char_name()
			if CHAR_ANIMS.has(name):
				anims = CHAR_ANIMS[name].duplicate()
		Category.ITEMS:
			var iid: String = ITEM_IDS[_index]
			if ITEM_ANIMS.has(iid):
				anims = ITEM_ANIMS[iid].duplicate()
		Category.ENVIRONMENT:
			var en: String = ENV_NAMES[_index]
			var env_anims := {"Rong Nhiet Doi": ["Sway"], "Sen Thach Anh": ["Bloom"]}
			if env_anims.has(en):
				anims = env_anims[en].duplicate()
	if anims.is_empty():
		_anim_panel.visible = false
		return
	_anim_panel.visible = true
	for i in len(anims):
		var btn := Button.new()
		btn.size = Vector2(136, 22)
		btn.text = anims[i]
		btn.add_theme_font_size_override("font_size", 11)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.12, 0.12, 0.20, 0.5)
		normal.corner_radius_top_left = 4; normal.corner_radius_top_right = 4
		normal.corner_radius_bottom_left = 4; normal.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate()
		hover.bg_color = Color(0.20, 0.20, 0.35, 0.6)
		btn.add_theme_stylebox_override("hover", hover)
		var pressed := normal.duplicate()
		pressed.bg_color = Color(0.30, 0.40, 0.60, 0.7)
		btn.add_theme_stylebox_override("pressed", pressed)
		var idx := i
		btn.pressed.connect(func(): _on_anim_selected(idx))
		_anim_panel.add_child(btn)
		_anim_buttons.append(btn)
	_highlight_selected()

func _highlight_selected() -> void:
	for i in len(_anim_buttons):
		var override := "pressed" if i == _selected_anim else "normal"
		_anim_buttons[i].add_theme_stylebox_override("normal",
			_anim_buttons[i].get_theme_stylebox(override).duplicate())

func _on_anim_selected(idx: int) -> void:
	_selected_anim = idx
	_highlight_selected()
	match _category:
		Category.ITEMS:
			if ITEM_IDS[_index] == "chest":
				_chest_open = idx == 1
				if _chest_lid:
					var target: float = -90.0 if _chest_open else 0.0
					_chest_lid.rotation.x = deg_to_rad(target)
		Category.ENVIRONMENT:
			pass
		Category.CHARACTERS:
			pass

func _anim_name(idx: int) -> String:
	match _category:
		Category.CHARACTERS:
			var n := _char_name()
			if CHAR_ANIMS.has(n) and idx < len(CHAR_ANIMS[n]):
				return CHAR_ANIMS[n][idx]
		Category.ITEMS:
			var iid: String = ITEM_IDS[_index]
			if ITEM_ANIMS.has(iid) and idx < len(ITEM_ANIMS[iid]):
				return ITEM_ANIMS[iid][idx]
	return ""

func _process(delta: float) -> void:
	if _auto_rotate and _drag_button < 0:
		_yaw += delta * 30.0
	_update_camera()
	if _gizmo:
		_gizmo.queue_redraw()
	_update_debug_menu()
	_update_model_animation(delta)

func _update_model_animation(delta: float) -> void:
	if _anim_driver:
		_anim_driver.time += delta
		if _fish_anim and _anim_driver:
			_fish_anim.animate(delta)
	if _category == Category.CHARACTERS and _char_name() == "Dummy" and _current_root:
		_current_root.rotation.y += delta * 0.5

func _update_camera() -> void:
	var offset := Vector3(0, 0, _dist)
	offset = offset.rotated(Vector3.UP, deg_to_rad(_yaw))
	offset = offset.rotated(Vector3.RIGHT, deg_to_rad(_pitch))
	_cam.global_position = _target_pos + offset
	_cam.look_at(_target_pos)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_LEFT:
					_drag_start = get_viewport().get_mouse_position()
					_drag_button = MOUSE_BUTTON_LEFT
					_auto_rotate = false
				MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
					_drag_start = get_viewport().get_mouse_position()
					_drag_button = mb.button_index
				MOUSE_BUTTON_WHEEL_UP:
					_dist = clamp(_dist - 0.5, 0.5, 30.0)
				MOUSE_BUTTON_WHEEL_DOWN:
					_dist = clamp(_dist + 0.5, 0.5, 30.0)
		else:
			if mb.button_index == _drag_button:
				_drag_button = -1
	if event is InputEventMouseMotion and _drag_button >= 0:
		var mm := event as InputEventMouseMotion
		var speed := 0.005 * _dist
		match _drag_button:
			MOUSE_BUTTON_LEFT:
				_yaw -= mm.relative.x * 0.3
				_pitch = clamp(_pitch - mm.relative.y * 0.3, -89.0, 89.0)
			MOUSE_BUTTON_MIDDLE:
				_target_pos += _cam.global_transform.basis.x * (-mm.relative.x * speed)
				_target_pos += _cam.global_transform.basis.y * (mm.relative.y * speed)
			MOUSE_BUTTON_RIGHT:
				_target_pos += _cam.global_transform.basis.x * (-mm.relative.x * speed)
				_target_pos += _cam.global_transform.basis.y * (mm.relative.y * speed)
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			var k_debug: int = ProjectSettings.get_setting("controls/debug", KEY_F2)
			if k.keycode == k_debug:
				_toggle_debug()
				return
			if _debug_open:
				return
			match k.keycode:
				KEY_RIGHT, KEY_D:
					_next()
				KEY_LEFT, KEY_A:
					_prev()
				KEY_UP, KEY_W:
					_category = (_category + 1) % 4
					_index = 0
					_auto_rotate = true
					_target_pos = Vector3.ZERO
					_refresh()
				KEY_DOWN, KEY_S:
					_category = (_category - 1 + 4) % 4
					_index = 0
					_auto_rotate = true
					_target_pos = Vector3.ZERO
					_refresh()
				KEY_SPACE:
					_auto_rotate = not _auto_rotate
				KEY_R:
					_target_pos = Vector3.ZERO
					_yaw = 0.0
					_pitch = -25.0
					_dist = 3.0

func _next() -> void:
	var mx := _max_index()
	if _index < mx:
		_index += 1
		_refresh()

func _prev() -> void:
	if _index > 0:
		_index -= 1
		_refresh()

func _max_index() -> int:
	match _category:
		Category.BLOCKS: return BLOCK_IDS.size() - 1
		Category.ITEMS: return ITEM_IDS.size() - 1
		Category.CHARACTERS: return CHAR_NAMES.size() - 1
		Category.ENVIRONMENT: return ENV_NAMES.size() - 1
	return 0

func _refresh() -> void:
	_anim_driver = null
	_fish_anim = null
	_chest_lid = null
	_selected_anim = -1
	for ch in _container.get_children():
		ch.queue_free()
	match _category:
		Category.BLOCKS: _show_block()
		Category.ITEMS: _show_item()
		Category.CHARACTERS: _show_character()
		Category.ENVIRONMENT: _show_environment()
	_update_label()
	_update_anim_panel()

func _show_block() -> void:
	var bid: int = BLOCK_IDS[_index]
	var col: Color = _CD.BLOCK_COLORS_RW[bid]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if bid == _CD.BlockID.WATER:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.5, 1.0)
	mi.mesh = mesh
	mi.material_override = mat
	_container.add_child(mi)

func _show_item() -> void:
	var iid: String = ITEM_IDS[_index]
	match iid:
		"cup", "xeng", "riu", "kiem", "can_cau":
			_WM.build(_container, iid)
		"chest":
			_build_chest()
		"twilight_gate":
			_build_twilight_gate()

func _build_chest() -> void:
	var root := Node3D.new()
	_container.add_child(root)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.45, 0.28, 0.15)
	body_mat.metallic = 0.1; body_mat.roughness = 0.8
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.50, 0.32, 0.18)
	lid_mat.metallic = 0.1; lid_mat.roughness = 0.7
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.35, 0.22, 0.12)
	var lock_mat := StandardMaterial3D.new()
	lock_mat.albedo_color = Color(0.60, 0.50, 0.30)

	var body_mi := MeshInstance3D.new()
	var body_box := BoxMesh.new(); body_box.size = Vector3(0.7, 0.35, 0.6)
	body_mi.mesh = body_box; body_mi.material_override = body_mat
	body_mi.position = Vector3(0, 0.175, 0)
	root.add_child(body_mi)

	var lid_root := Node3D.new()
	lid_root.position = Vector3(0, 0.38, 0)
	root.add_child(lid_root)
	var lid_mi := MeshInstance3D.new()
	var lid_box := BoxMesh.new(); lid_box.size = Vector3(0.72, 0.06, 0.62)
	lid_mi.mesh = lid_box; lid_mi.material_override = lid_mat
	lid_root.add_child(lid_mi)
	_chest_lid = lid_root

	var band := MeshInstance3D.new()
	var band_box := BoxMesh.new(); band_box.size = Vector3(0.74, 0.04, 0.08)
	band.mesh = band_box; band.material_override = band_mat
	band.position = Vector3(0, 0.20, 0.305)
	root.add_child(band)
	var lock := MeshInstance3D.new()
	var lock_box := BoxMesh.new(); lock_box.size = Vector3(0.10, 0.08, 0.06)
	lock.mesh = lock_box; lock.material_override = lock_mat
	lock.position = Vector3(0, 0.22, 0.305)
	root.add_child(lock)

func _build_twilight_gate() -> void:
	var pg := PortalGate.new()
	_container.add_child(pg)

func _show_character() -> void:
	var name := _char_name()
	var root := Node3D.new()
	_container.add_child(root)
	_current_root = root
	match name:
		"Player":
			var body := CharacterBody3D.new()
			root.add_child(body)
			var pm := _PlayerMesh.new()
			pm.build(body)
		"Raptor":
			var body := CharacterBody3D.new()
			root.add_child(body)
			var rm := _RaptorMesh.new()
			rm.build(body)
		"Dragon":
			var body := CharacterBody3D.new()
			root.add_child(body)
			var dm := _DragonMesh.new()
			dm.build(body)
		"Warrior":
			var body := CharacterBody3D.new()
			root.add_child(body)
			var wm := _WarriorMesh.new()
			wm.build(body)
		"Beyordeath":
			var body := CharacterBody3D.new()
			root.add_child(body)
			var bm := _BeyordeathMesh.new()
			bm.build(body)
		"Dummy":
			var mat_body := MeshBuilder.emit_mat(Color(0.90, 0.05, 0.10), Color(0,0,0), 0.0)
			MeshBuilder.box(root, Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 1.0), mat_body)
			var mat_glow := MeshBuilder.emit_mat(Color(0.90, 0.10, 0.15, 0.25), Color(0,0,0), 0.0)
			MeshBuilder.sphere(root, Vector3(0, 1.0, 0), 0.8, mat_glow)
			var mat_ring := MeshBuilder.emit_mat(Color(1.0, 0.20, 0.25), Color(0,0,0), 0.0)
			for i in range(2):
				var mi := MeshInstance3D.new()
				var tor := TorusMesh.new()
				tor.inner_radius = 0.7 + i * 0.1; tor.outer_radius = 0.04
				mi.mesh = tor; mi.material_override = mat_ring
				mi.position = Vector3(0, 1.0, 0)
				mi.rotation = Vector3(deg_to_rad(90), 0, deg_to_rad(i * 90))
				root.add_child(mi)
		"Ca Chep", "Ca Ro", "Ca Tram", "Ca Mong", "Ca Vang", "Ca Linh", "Ca La Han", "Tom":
			_build_fish_variant(root)

func _build_fish_variant(root: Node3D) -> void:
	var idx: int = _fish_variant_index()
	var cols: Array = FISH_COLORS[idx]
	var fm := _FishMesh.new()
	fm.color_body  = cols[0]
	fm.color_belly = cols[1]
	fm.color_fin   = cols[2]
	fm.color_pattern = FISH_PATTERN[idx]
	fm.body_z_scale  = FISH_BODY_Z[idx]
	if idx == 4:
		fm.body_triangular = true
		fm.has_horns = true
	elif idx == 5:
		fm.body_shape = _FishMesh.BodyShape.SHRIMP
	fm.build(root)

	var driver := Node.new()
	driver.set_script(null)
	driver.time = 0.0
	driver.velocity = Vector3(1, 0, 0)
	root.add_child(driver)
	_anim_driver = driver

	var fa := _FishAnim.new()
	fa.setup(fm, driver)
	_fish_anim = fa

func _fish_variant_index() -> int:
	var base := 6
	var idx := _index - base
	if idx < 0 or idx >= 6:
		return 0
	return idx

func _show_environment() -> void:
	var en: String = ENV_NAMES[_index]
	match en:
		"Rong Nhiet Doi":
			_build_weed()
		"Sen Thach Anh":
			_build_lotus()

func _build_weed() -> void:
	var root := Node3D.new()
	_container.add_child(root)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var _unused_lights: Array[Vector3] = []
	_Aquatic._add_tropical_weed(st, 42, 73, Vector3(0, -3.0, 0),
		0.05, 0.90, 0.5, 0.5, 123456789, 987654321,
		5.0, true, _unused_lights)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.position = Vector3(0, 3.0, 0)
	root.add_child(mi)

func _build_lotus() -> void:
	var root := Node3D.new()
	_container.add_child(root)
	var lily_mat := StandardMaterial3D.new()
	lily_mat.albedo_color = Color(0.08, 0.45, 0.12)
	lily_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var petal_mat := StandardMaterial3D.new()
	petal_mat.albedo_color = Color(0.92, 0.65, 0.70)
	petal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Lily pad: crossed quads (like game's _add_quad approach)
	for ri in range(2):
		var angle := float(ri) * PI * 0.25
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.28, 0.28)
		mi.mesh = plane; mi.material_override = lily_mat
		mi.rotation = Vector3(0, angle, 0)
		root.add_child(mi)

	# Stem
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.06, 0.50, 0.15)
	var stem_mi := MeshInstance3D.new()
	var stem_box := BoxMesh.new(); stem_box.size = Vector3(0.02, 0.20, 0.02)
	stem_mi.mesh = stem_box; stem_mi.material_override = stem_mat
	stem_mi.position = Vector3(0, -0.10, 0)
	root.add_child(stem_mi)

	# Crystal petals: 4 at 90°, rising with outward tilt (like game)
	for i in range(4):
		var pa := float(i) * PI * 0.5
		var petal_mi := MeshInstance3D.new()
		var petal_box := BoxMesh.new(); petal_box.size = Vector3(0.03, 0.14, 0.06)
		petal_mi.mesh = petal_box; petal_mi.material_override = petal_mat
		petal_mi.position = Vector3(cos(pa) * 0.05, 0.08, sin(pa) * 0.05)
		petal_mi.rotation = Vector3(deg_to_rad(-25), pa, 0)
		root.add_child(petal_mi)

func _char_name() -> String:
	return CHAR_NAMES[_index]

func _update_label() -> void:
	var cat: String = CATEGORY_NAMES[_category]
	var name := ""
	match _category:
		Category.BLOCKS:
			var bid: int = BLOCK_IDS[_index]
			name = _CD.BlockID.keys()[bid]
		Category.ITEMS:
			name = ITEM_IDS[_index]
		Category.CHARACTERS:
			name = CHAR_NAMES[_index]
		Category.ENVIRONMENT:
			name = ENV_NAMES[_index]
	_label.text = "[ %s ]  %s  (%d/%d)     [R] Reset  [Space] Auto-rotate  [F2] Debug" % [cat, name, _index + 1, _max_index() + 1]

func _on_gizmo_rotate(dy: float, dp: float) -> void:
	_yaw += dy
	_pitch = clamp(_pitch + dp, -89.0, 89.0)
	_auto_rotate = false

func _on_gizmo_snap(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = clamp(pitch, -89.0, 89.0)
	_auto_rotate = false

func _setup_debug_menu() -> void:
	_debug_panel = Panel.new()
	_debug_panel.visible = false
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.12, 0.90)
	bg.corner_radius_top_left = 8; bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8; bg.corner_radius_bottom_right = 8
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = Color(1, 1, 1, 0.15)
	_debug_panel.add_theme_stylebox_override("panel", bg)
	var vp := get_viewport().get_visible_rect().size
	_debug_panel.position = Vector2(vp.x * 0.5 - 175, vp.y * 0.5 - 130)
	_debug_panel.size = Vector2(350, 260)
	var title := Label.new()
	title.position = Vector2(12, 8); title.size = Vector2(326, 28)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.80, 0.80, 0.90, 0.9))
	title.text = "DEBUG MENU"
	_debug_panel.add_child(title)
	var close_btn := Button.new()
	close_btn.position = Vector2(320, 6); close_btn.size = Vector2(24, 24)
	close_btn.text = "X"; close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(_toggle_debug)
	_debug_panel.add_child(close_btn)
	var y: float = 44; var line_h: float = 36
	var ts_label := Label.new()
	ts_label.position = Vector2(12, y); ts_label.size = Vector2(326, 20)
	ts_label.add_theme_font_size_override("font_size", 13)
	ts_label.add_theme_color_override("font_color", Color(0.60, 0.60, 0.75, 0.85))
	ts_label.text = "Game Time:"; _debug_panel.add_child(ts_label); y += 20
	_debug_ts_label = Label.new()
	_debug_ts_label.position = Vector2(12, y); _debug_ts_label.size = Vector2(326, 20)
	_debug_ts_label.add_theme_font_size_override("font_size", 13)
	_debug_ts_label.add_theme_color_override("font_color", Color(0.80, 0.80, 0.90, 0.9))
	_debug_ts_label.text = ""; _debug_panel.add_child(_debug_ts_label); y += line_h
	var hour_lbl := Label.new()
	hour_lbl.position = Vector2(12, y); hour_lbl.size = Vector2(80, 20)
	hour_lbl.add_theme_font_size_override("font_size", 13)
	hour_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.75, 0.85))
	hour_lbl.text = "Hour:"; _debug_panel.add_child(hour_lbl)
	_debug_hour_slider = HSlider.new()
	_debug_hour_slider.position = Vector2(90, y); _debug_hour_slider.size = Vector2(240, 20)
	_debug_hour_slider.min_value = 0.0; _debug_hour_slider.max_value = 24.0
	_debug_hour_slider.step = 0.5; _debug_hour_slider.value = 6.0
	_debug_hour_slider.value_changed.connect(_on_debug_hour_changed)
	_debug_panel.add_child(_debug_hour_slider); y += line_h
	var speed_lbl := Label.new()
	speed_lbl.position = Vector2(12, y); speed_lbl.size = Vector2(80, 20)
	speed_lbl.add_theme_font_size_override("font_size", 13)
	speed_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.75, 0.85))
	speed_lbl.text = "Speed:"; _debug_panel.add_child(speed_lbl)
	_debug_speed_slider = HSlider.new()
	_debug_speed_slider.position = Vector2(90, y); _debug_speed_slider.size = Vector2(240, 20)
	_debug_speed_slider.min_value = 0.0; _debug_speed_slider.max_value = 50.0
	_debug_speed_slider.step = 0.5; _debug_speed_slider.value = 1.0
	_debug_speed_slider.value_changed.connect(_on_debug_speed_changed)
	_debug_panel.add_child(_debug_speed_slider); y += line_h
	var weather_lbl := Label.new()
	weather_lbl.position = Vector2(12, y); weather_lbl.size = Vector2(80, 20)
	weather_lbl.add_theme_font_size_override("font_size", 13)
	weather_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.75, 0.85))
	weather_lbl.text = "Weather:"; _debug_panel.add_child(weather_lbl)
	_debug_weather_btn = Button.new()
	_debug_weather_btn.position = Vector2(90, y - 2); _debug_weather_btn.size = Vector2(120, 24)
	_debug_weather_btn.add_theme_font_size_override("font_size", 13)
	_debug_weather_btn.text = "Clear"
	_debug_weather_btn.pressed.connect(_on_debug_weather_toggle)
	_debug_panel.add_child(_debug_weather_btn)
	$CanvasLayer.add_child(_debug_panel)

func _toggle_debug() -> void:
	_debug_open = not _debug_open
	_debug_panel.visible = _debug_open

func _update_debug_menu() -> void:
	if not _debug_open or not TimeSystem:
		return
	var h: int = TimeSystem.get_hour_int()
	var m: int = TimeSystem.get_minute()
	var day: int = TimeSystem.get_day()
	var month: String = TimeSystem.get_month_name()
	var year: int = TimeSystem.get_year() + 1
	var season: String = TimeSystem.get_season_name()
	var weather: String = TimeSystem.get_weather_name()
	_debug_ts_label.text = "%02d:%02d  %s %d, Year %d  |  %s  |  %s" % [h, m, month, day, year, season, weather]
	_debug_hour_slider.value = h
	_debug_speed_slider.value = TimeSystem.get_time_scale()
	if TimeSystem.get_weather() == TimeSystem.Weather.RAIN:
		_debug_weather_btn.text = "Rain"
	else:
		_debug_weather_btn.text = "Clear"

func _on_debug_hour_changed(value: float) -> void:
	if TimeSystem:
		TimeSystem.set_hour(value)

func _on_debug_speed_changed(value: float) -> void:
	if TimeSystem:
		TimeSystem.set_time_scale(value)

func _on_debug_weather_toggle() -> void:
	if not TimeSystem:
		return
	if TimeSystem.get_weather() == TimeSystem.Weather.CLEAR:
		TimeSystem.force_weather(TimeSystem.Weather.RAIN)
		_debug_weather_btn.text = "Rain"
	else:
		TimeSystem.force_weather(TimeSystem.Weather.CLEAR)
		_debug_weather_btn.text = "Clear"
