## core/character_manager.gd
## Quản lý danh sách nhân vật, điều phối switch, HUD tên nhân vật.
##
## Phím:  Tab = next   |   Shift+Tab = prev

extends Node3D
class_name CharacterManager

var _characters: Array[CharacterBase] = []
var _current:    int = 0

var _iso_rig: Node3D
var _tp_rig:  Node3D
var _label:   Label

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	for ch in get_children():
		if ch is CharacterBase:
			_characters.append(ch as CharacterBase)

	if _characters.is_empty():
		push_error("CharacterManager: không có CharacterBase nào!")
		return

	var root := get_parent()
	_iso_rig = root.get_node_or_null("CameraRig")
	_tp_rig  = root.get_node_or_null("TPCameraRig")

	_build_hud()

	# Tắt tất cả trước, bật nhân vật đầu
	for ch in _characters:
		ch.set_physics_process(false)
		ch.set_process_unhandled_input(false)
		ch.set_process_unhandled_key_input(false)

	await get_tree().process_frame

	for i in range(_characters.size()):
		if i == 0:
			_characters[i].set_active(true)
		else:
			_characters[i]._active = false
			if _characters[i]._rig:
				_characters[i]._rig.visible = false

	_aim_cameras_at(_characters[0])
	_update_hud()

# ── HUD ───────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color",        Color(0.8, 1.0, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_label)

func _update_hud() -> void:
	if not is_instance_valid(_label): return
	var ch := _characters[_current]
	var idx_str := "[%d/%d]" % [_current + 1, _characters.size()]
	var name_str: String = ch.name
	_label.text = "%s  %s    Tab=next  Shift+Tab=prev  F1=camera" % [idx_str, name_str]

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_TAB:
			if Input.is_key_pressed(KEY_SHIFT): _switch_prev()
			else:                               _switch_next()

func _switch_next() -> void:
	_switch_to((_current + 1) % _characters.size())

func _switch_prev() -> void:
	_switch_to((_current - 1 + _characters.size()) % _characters.size())

func _switch_to(idx: int) -> void:
	if idx == _current: return
	var prev_ch := _characters[_current]
	var next_ch := _characters[idx]

	_characters[_current].set_active(false)
	_current = idx

	# Teleport seamless
	next_ch.global_position = prev_ch.global_position
	next_ch.rotation        = prev_ch.rotation
	next_ch.velocity        = Vector3.ZERO
	next_ch.set_active(true)

	_aim_cameras_at(next_ch)
	_update_hud()
	_flash(next_ch.global_position)

# ── Camera ────────────────────────────────────────────────────────────────────
func _aim_cameras_at(ch: CharacterBase) -> void:
	if is_instance_valid(_iso_rig):
		if _iso_rig.has_method("set_target"): _iso_rig.set_target(ch)
		else: _iso_rig.set("_target", ch)
	if is_instance_valid(_tp_rig):
		if _tp_rig.has_method("set_target"):  _tp_rig.set_target(ch)
		else: _tp_rig.set("_target", ch)

# ── Swap flash ────────────────────────────────────────────────────────────────
func _flash(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_energy = 8.0
	light.omni_range   = 5.0
	light.light_color  = Color(0.6, 1.0, 0.8) if _current == 0 else Color(0.9, 0.3, 1.0)
	get_parent().add_child(light)
	light.global_position = pos + Vector3(0, 1, 0)
	get_tree().create_timer(0.25).timeout.connect(func(): light.queue_free())
