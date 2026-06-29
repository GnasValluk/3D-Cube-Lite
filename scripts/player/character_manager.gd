## character_manager.gd
## Quản lý danh sách nhân vật, xử lý chuyển đổi bằng phím Tab.
## Đặt script này lên node "CharacterManager" (Node3D) là cha của tất cả nhân vật.
##
## Phím điều khiển:
##   Tab        → chuyển sang nhân vật tiếp theo
##   Shift+Tab  → chuyển về nhân vật trước

extends Node3D

# ── Characters list (tự động lấy tất cả CharacterBase con) ───────────────────
var _characters: Array[CharacterBase] = []
var _current_idx: int = 0

# ── Camera rigs (gán lại target khi switch) ───────────────────────────────────
var _iso_rig: Node3D
var _tp_rig:  Node3D

# ── HUD label (tuỳ chọn) ─────────────────────────────────────────────────────
var _label: Label

func _ready() -> void:
	# Thu thập tất cả CharacterBase con trực tiếp
	for child in get_children():
		if child is CharacterBase:
			_characters.append(child as CharacterBase)

	if _characters.is_empty():
		push_error("CharacterManager: không tìm thấy CharacterBase nào!")
		return

	# Lấy camera rigs từ scene cha
	var scene_root := get_parent()
	_iso_rig = scene_root.get_node_or_null("CameraRig")
	_tp_rig  = scene_root.get_node_or_null("TPCameraRig")

	for i in range(_characters.size()):
		_characters[i].set_physics_process(false)
		_characters[i].set_process_unhandled_input(false)
		_characters[i].set_process_unhandled_key_input(false)
		var pl := _characters[i].get_node_or_null("PlayerLight") as OmniLight3D
		if pl:
			pl.light_energy = 0.0

	# Tạo HUD hiển thị tên nhân vật
	_build_hud()

	# Kích hoạt nhân vật đầu tiên sau 1 frame (chờ _build_character xong)
	await get_tree().process_frame
	for i in range(_characters.size()):
		if i == 0:
			_characters[i].set_active(true)
		else:
			# Ẩn rig của nhân vật không active
			_characters[i]._active = false
			if _characters[i]._rig:
				_characters[i]._rig.visible = false
	_point_cameras_at(_characters[0])
	_update_label()

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_label)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_TAB:
				if Input.is_key_pressed(KEY_SHIFT):
					_switch_prev()
				else:
					_switch_next()

func _switch_next() -> void:
	var next := (_current_idx + 1) % _characters.size()
	_switch_to(next)

func _switch_prev() -> void:
	var prev := (_current_idx - 1 + _characters.size()) % _characters.size()
	_switch_to(prev)

func _switch_to(idx: int) -> void:
	if idx == _current_idx:
		return
	var prev_idx := _current_idx
	_deactivate(prev_idx)
	_current_idx = idx
	# Teleport nhân vật mới về vị trí nhân vật cũ
	var prev_ch := _characters[prev_idx]
	var new_ch  := _characters[idx]
	new_ch.global_position = prev_ch.global_position
	new_ch.rotation        = prev_ch.rotation
	new_ch.velocity        = Vector3.ZERO
	new_ch.set_active(true)
	_point_cameras_at(new_ch)
	_update_label()
	_spawn_swap_effect(new_ch.global_position)

func _point_cameras_at(ch: CharacterBase) -> void:
	if is_instance_valid(_iso_rig):
		if _iso_rig.has_method("set_target"):
			_iso_rig.set_target(ch)
		else:
			_iso_rig.set("_target", ch)
	if is_instance_valid(_tp_rig):
		if _tp_rig.has_method("set_target"):
			_tp_rig.set_target(ch)
		else:
			_tp_rig.set("_target", ch)

func _deactivate(idx: int) -> void:
	if idx >= _characters.size(): return
	_characters[idx].set_active(false)

func _update_label() -> void:
	if not is_instance_valid(_label): return
	var names: Array[String] = ["① Raptor", "② Dragon"]
	var hint: String  = "  [Tab] chuyển nhân vật"
	var n: String
	if _current_idx < names.size():
		n = names[_current_idx]
	else:
		n = "Nhân vật %d" % (_current_idx + 1)
	_label.text = n + hint

func _spawn_swap_effect(pos: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var light := OmniLight3D.new()
	light.light_color   = Color(0.6, 1.0, 0.8) if _current_idx == 0 \
		else Color(0.9, 0.3, 1.0)
	light.light_energy  = 6.0
	light.omni_range    = 4.0
	parent.add_child(light)
	light.global_position = pos + Vector3(0, 1, 0)
	var timer := get_tree().create_timer(0.25)
	timer.timeout.connect(func(): light.queue_free())
