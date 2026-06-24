## ui/hud.gd
## HUD chính: skill bar + party HUD + party UI overlay.

extends CanvasLayer
class_name HUD

var _tracked: CharacterBase = null
var _dummy_label: Label
var _dummy_tracked: CharacterBase = null
var _skill_bar: SkillBar
var _switch_hint: Label
var _party_ui: PartyUI
var _settings_ui
var _settings_icon: Button
var _party_hud: Control
var _party_indicators: Array[Panel] = []
var _mgr: CharacterManager

func _ready() -> void:
	_setup_ui()
	await get_tree().process_frame
	_find_and_track()

func _setup_ui() -> void:
	_dummy_label = Label.new()
	_dummy_label.position = Vector2(20, 56)
	_dummy_label.add_theme_font_size_override("font_size", 14)
	_dummy_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.7))
	_dummy_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_dummy_label.add_theme_constant_override("shadow_offset_x", 1)
	_dummy_label.add_theme_constant_override("shadow_offset_y", 1)
	_dummy_label.text = ""
	add_child(_dummy_label)

	_skill_bar = SkillBar.new()
	add_child(_skill_bar)

	_switch_hint = Label.new()
	_switch_hint.position = Vector2(60, 16)
	_switch_hint.add_theme_font_size_override("font_size", 11)
	_switch_hint.add_theme_color_override("font_color", Color(0.5, 0.7, 0.6, 0.5))
	_switch_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_switch_hint.add_theme_constant_override("shadow_offset_x", 1)
	_switch_hint.add_theme_constant_override("shadow_offset_y", 1)
	_switch_hint.text = "Tab=Cycle  1/2/3=Pick  P=Team  ESC=Settings  F1=Camera"
	add_child(_switch_hint)

	_setup_settings_icon()
	_setup_party_hud()

	_party_ui = PartyUI.new()
	add_child(_party_ui)

	_settings_ui = SettingsUI.new()
	add_child(_settings_ui)

func _setup_settings_icon() -> void:
	_settings_icon = Button.new()
	_settings_icon.position = Vector2(12, 10)
	_settings_icon.size = Vector2(40, 40)
	_settings_icon.text = "⚙"
	_settings_icon.add_theme_font_size_override("font_size", 22)
	_settings_icon.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.6))
	var icon_bg := StyleBoxFlat.new()
	icon_bg.bg_color = Color(0.06, 0.06, 0.10, 0.55)
	icon_bg.corner_radius_top_left = 8; icon_bg.corner_radius_top_right = 8
	icon_bg.corner_radius_bottom_left = 8; icon_bg.corner_radius_bottom_right = 8
	icon_bg.border_width_left = 1; icon_bg.border_width_right = 1
	icon_bg.border_width_top = 1; icon_bg.border_width_bottom = 1
	icon_bg.border_color = Color(0.35, 0.35, 0.45, 0.4)
	_settings_icon.add_theme_stylebox_override("normal", icon_bg)
	var hover_bg := icon_bg.duplicate()
	hover_bg.bg_color = Color(0.1, 0.1, 0.18, 0.7)
	hover_bg.border_color = Color(0.5, 0.5, 0.7, 0.6)
	_settings_icon.add_theme_stylebox_override("hover", hover_bg)
	_settings_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_icon.pressed.connect(_toggle_settings)
	add_child(_settings_icon)

func _toggle_settings() -> void:
	if _settings_ui and _settings_ui.visible:
		_settings_ui.hide_settings()
	else:
		if _party_ui and _party_ui.visible:
			_party_ui.hide_party()
		_settings_ui.show_settings()

func _setup_party_hud() -> void:
	var W: float = 72.0
	var H: float = 78.0
	var G: float = 4.0

	_party_hud = Control.new()
	_party_hud.size = Vector2(W, H * 3 + G * 2)
	var vp := get_viewport().get_visible_rect().size
	_party_hud.position = Vector2(vp.x - W, (vp.y - _party_hud.size.y) * 0.5)
	add_child(_party_hud)

	for i in range(3):
		var y: float = i * (H + G)

		var panel := Panel.new()
		panel.size = Vector2(W, H)
		panel.position = Vector2(0, y)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_party_indicator_input.bind(i))
		_party_hud.add_child(panel)

		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.06, 0.06, 0.10, 0.92)
		bg.corner_radius_top_left = 10
		bg.corner_radius_top_right = 0
		bg.corner_radius_bottom_left = 10
		bg.corner_radius_bottom_right = 0
		bg.border_width_left = 3
		bg.border_width_right = 0
		bg.border_width_top = 2
		bg.border_width_bottom = 2
		bg.border_color = Color(0.5, 0.5, 0.6, 0.7)
		panel.add_theme_stylebox_override("panel", bg)

		var icon := ColorRect.new()
		icon.position = Vector2(10, 8)
		icon.size = Vector2(52, 52)
		icon.color = Color(0.8, 0.2, 0.2)
		panel.add_child(icon)

		var hp_bg := ColorRect.new()
		hp_bg.position = Vector2(6, 66)
		hp_bg.size = Vector2(60, 6)
		hp_bg.color = Color(0.04, 0.04, 0.08, 0.85)
		panel.add_child(hp_bg)

		var hp_bar := ColorRect.new()
		hp_bar.position = Vector2(6, 66)
		hp_bar.size = Vector2(60, 6)
		hp_bar.color = Color(0.3, 1.0, 0.3, 0.9)
		panel.add_child(hp_bar)

		var shield_bar := ColorRect.new()
		shield_bar.position = Vector2(6, 66)
		shield_bar.size = Vector2(0, 6)
		shield_bar.color = Color(0.20, 0.50, 1.0, 0.55)
		panel.add_child(shield_bar)

		var lbl := Label.new()
		lbl.position = Vector2(4, 5)
		lbl.size = Vector2(64, 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		lbl.text = str(i + 1)
		panel.add_child(lbl)

		var d: Dictionary = { "panel": panel, "bg": bg, "icon": icon, "hp_bar": hp_bar, "shield_bar": shield_bar }
		panel.set_meta("data", d)
		_party_indicators.append(panel)

func _on_party_indicator_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _mgr:
			var party := _mgr.get_party_characters()
			if idx < party.size():
				_mgr.switch_by_name(party[idx].character_name)

func _process(_delta: float) -> void:
	if _dummy_tracked:
		_dummy_label.text = "DUMMY: %d / %d" % [_dummy_tracked.hp, _dummy_tracked.max_hp]
	else:
		_dummy_label.text = ""

	if _mgr:
		_refresh_party_hud()
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_party_hud.position = Vector2(vp.x - 72, (vp.y - _party_hud.size.y) * 0.5)

func _refresh_party_hud() -> void:
	var party: Array[CharacterBase] = _mgr.get_party_characters()
	var active: CharacterBase = _mgr.get_current_character()

	for i in range(_party_indicators.size()):
		var panel: Panel = _party_indicators[i]
		var d: Dictionary = panel.get_meta("data")
		var bg: StyleBoxFlat = d["bg"]

		if i < party.size():
			var ch: CharacterBase = party[i]
			d["hp_bar"].visible = true
			d["shield_bar"].visible = true

			var max_hp_val: int = max(ch.max_hp, 1)
			var hp_ratio: float = float(ch.hp) / float(max_hp_val)
			d["hp_bar"].color = Color(
				1.0 - hp_ratio,
				0.3 + hp_ratio * 0.7,
				0.2,
				0.85)
			d["hp_bar"].size.x = max(2.0, 60.0 * hp_ratio)

			var shield_ratio: float = clamp(float(ch.shield) / float(max_hp_val), 0.0, 1.0)
			if shield_ratio > 0.0:
				d["shield_bar"].size.x = max(2.0, 60.0 * shield_ratio)
				d["shield_bar"].position.x = 6.0 + 60.0 * hp_ratio
			else:
				d["shield_bar"].size.x = 0.0

			var elem: Variant = ch.get("element")
			var ec: Color = Color(0.3, 0.3, 0.5)
			if elem is int and (elem as int) > 0:
				var tmp: Variant = CharacterBase.ELEMENT_COLORS.get(elem as int)
				if tmp is Color:
					ec = tmp as Color
			d["icon"].color = ec

			if active and ch.character_name == active.character_name:
				bg.border_color = Color(1, 1, 1, 0.95)
				bg.border_width_left = 2
				bg.border_width_right = 2
				bg.border_width_top = 2
				bg.border_width_bottom = 2
				bg.bg_color = Color(ec.r * 0.25, ec.g * 0.25, ec.b * 0.25, 0.9)
			else:
				bg.border_color = Color(ec.r, ec.g, ec.b, 0.7)
				bg.border_width_left = 2
				bg.border_width_right = 2
				bg.border_width_top = 2
				bg.border_width_bottom = 2
				bg.bg_color = Color(0.06, 0.06, 0.10, 0.85)
		else:
			d["hp_bar"].visible = false
			d["icon"].color = Color(0.1, 0.1, 0.15)
			bg.border_color = Color(0.2, 0.2, 0.3, 0.3)
			bg.border_width_left = 1
			bg.border_width_right = 1
			bg.border_width_top = 1
			bg.border_width_bottom = 1
			bg.bg_color = Color(0.06, 0.06, 0.10, 0.6)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_P:
				if _party_ui and _party_ui.visible:
					_party_ui.hide_party()
				elif _mgr and not (_settings_ui and _settings_ui.visible):
					_party_ui.show_party(_mgr)
			if k.keycode == KEY_ESCAPE:
				if _party_ui and _party_ui.visible:
					_party_ui.hide_party()
				elif _settings_ui and _settings_ui.visible:
					_settings_ui.hide_settings()
				else:
					_toggle_settings()

func _find_and_track() -> void:
	_mgr = _find_manager()
	if _mgr == null:
		await get_tree().create_timer(0.5).timeout
		_find_and_track()
		return
	_track_dummy(_mgr)
	_track_character(_mgr.get_current_character())
	_mgr.character_switched.connect(_track_character)

func _find_manager() -> CharacterManager:
	var root := get_parent()
	if root and root.has_node("CharacterManager"):
		return root.get_node("CharacterManager")
	return null

func _track_dummy(mgr: CharacterManager) -> void:
	for ch in mgr.get_children():
		if ch is CharacterBase and not ch._is_player:
			_dummy_tracked = ch
			if not ch.hp_changed.is_connected(_update_dummy_label):
				ch.hp_changed.connect(_update_dummy_label)
			return
	_dummy_tracked = null

func _update_dummy_label(_a: int = 0, _b: int = 0) -> void:
	if _dummy_tracked:
		_dummy_label.text = "DUMMY: %d / %d" % [_dummy_tracked.hp, _dummy_tracked.max_hp]

func _track_character(ch: CharacterBase) -> void:
	if _tracked:
		if _tracked.hp_changed.is_connected(_on_hp_changed):
			_tracked.hp_changed.disconnect(_on_hp_changed)
	_tracked = ch
	if ch == null:
		_dummy_label.text = ""
		return
	ch.hp_changed.connect(_on_hp_changed)
	_skill_bar.track(ch)
	_on_hp_changed(ch.hp, ch.max_hp)

func _on_hp_changed(_current: int, _max_hp_val: int) -> void:
	pass
