## ui/hud.gd
## HUD chính: skill bar + switch hint.

extends CanvasLayer
class_name HUD

var _tracked: CharacterBase = null
var _dummy_label: Label
var _dummy_tracked: CharacterBase = null
var _skill_bar: SkillBar
var _switch_hint: Label

func _ready() -> void:
	_setup_ui()
	await get_tree().process_frame
	_find_and_track()

func _setup_ui() -> void:
	_dummy_label = Label.new()
	_dummy_label.position = Vector2(20, 20)
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
	_switch_hint.position = Vector2(20, 50)
	_switch_hint.add_theme_font_size_override("font_size", 12)
	_switch_hint.add_theme_color_override("font_color", Color(0.5, 0.7, 0.6, 0.6))
	_switch_hint.text = "Tab=Next  Shift+Tab=Prev  F1=Camera"
	add_child(_switch_hint)

func _process(_delta: float) -> void:
	if _dummy_tracked:
		_dummy_label.text = "DUMMY: %d / %d" % [_dummy_tracked.hp, _dummy_tracked.max_hp]
	else:
		_dummy_label.text = ""

func _find_and_track() -> void:
	var mgr := _find_manager()
	if mgr == null:
		await get_tree().create_timer(0.5).timeout
		_find_and_track()
		return
	_track_dummy(mgr)
	_track_character(mgr._characters[mgr._current] if not mgr._characters.is_empty() else null)
	mgr.character_switched.connect(_track_character)

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
