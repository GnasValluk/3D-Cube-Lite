## ui/hud.gd
## HUD chính: HP bar nhân vật hiện tại, tên, chỉ số.

extends CanvasLayer
class_name HUD

@export var bar_width: float = 260.0

var _char_name: Label
var _hp_bar: HealthBar
var _stats_label: Label
var _tracked: CharacterBase = null
var _switch_hint: Label

func _ready() -> void:
	_setup_ui()
	await get_tree().process_frame
	_find_and_track()

func _setup_ui() -> void:
	# Character name
	_char_name = Label.new()
	_char_name.position = Vector2(20, 20)
	_char_name.add_theme_font_size_override("font_size", 22)
	_char_name.add_theme_color_override("font_color", Color(0.8, 1.0, 0.9))
	_char_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_char_name.add_theme_constant_override("shadow_offset_x", 2)
	_char_name.add_theme_constant_override("shadow_offset_y", 2)
	_char_name.text = ""
	add_child(_char_name)

	# HP bar
	_hp_bar = HealthBar.new()
	_hp_bar.position = Vector2(20, 52)
	_hp_bar.set_label("HP")
	add_child(_hp_bar)

	# Stats
	_stats_label = Label.new()
	_stats_label.position = Vector2(20, 90)
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.7))
	_stats_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_stats_label.add_theme_constant_override("shadow_offset_x", 1)
	_stats_label.add_theme_constant_override("shadow_offset_y", 1)
	_stats_label.text = ""
	add_child(_stats_label)

	# Switch hint
	_switch_hint = Label.new()
	_switch_hint.position = Vector2(20, 130)
	_switch_hint.add_theme_font_size_override("font_size", 12)
	_switch_hint.add_theme_color_override("font_color", Color(0.5, 0.7, 0.6, 0.6))
	_switch_hint.text = "Tab=Next  Shift+Tab=Prev  F1=Camera"
	add_child(_switch_hint)

func _find_and_track() -> void:
	var mgr := _find_manager()
	if mgr == null:
		await get_tree().create_timer(0.5).timeout
		_find_and_track()
		return
	_track_character(mgr._characters[mgr._current] if not mgr._characters.is_empty() else null)
	mgr.character_switched.connect(_track_character)

func _find_manager() -> CharacterManager:
	var root := get_parent()
	if root and root.has_node("CharacterManager"):
		return root.get_node("CharacterManager")
	return null

func _track_character(ch: CharacterBase) -> void:
	if _tracked:
		_tracked.hp_changed.disconnect(_on_hp_changed)
	_tracked = ch
	if ch == null:
		_char_name.text = ""
		_hp_bar.set_hp(0, 100)
		_stats_label.text = ""
		return
	ch.hp_changed.connect(_on_hp_changed)
	var name_str: String = ch.character_name
	if name_str.is_empty():
		name_str = ch.name
	_char_name.text = name_str
	_on_hp_changed(ch.hp, ch.max_hp)

func _on_hp_changed(current: int, max_hp_val: int) -> void:
	_hp_bar.set_hp(current, max_hp_val)
	if _tracked:
		_stats_label.text = "ATK: %d  DEF: %d  SPD: %.1f" % [
			_tracked.attack_power,
			_tracked.defense,
			_tracked.move_speed]
