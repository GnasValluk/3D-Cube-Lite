## ui/health_bar.gd
## Thanh HP dạng ProgressBar + Label.

extends PanelContainer
class_name HealthBar

@export var bar_color: Color = Color(0.2, 1.0, 0.5)
@export var bg_color: Color  = Color(0.1, 0.1, 0.15)
@export var label_text: String = ""

var _progress: ProgressBar
var _label: Label
var _target_hp: int = 0
var _target_max: int = 0

func _enter_tree() -> void:
	size = Vector2(220, 28)
	custom_minimum_size = Vector2(220, 28)

func _ready() -> void:
	_setup()

func _setup() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_right = 4
	bg.corner_radius_bottom_left = 4
	add_theme_stylebox_override("panel", bg)

	_progress = ProgressBar.new()
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	_progress.max_value = 100
	_progress.value     = 100
	_progress.show_percentage = false

	var fg := StyleBoxFlat.new()
	fg.bg_color = bar_color
	fg.corner_radius_top_left = 3
	fg.corner_radius_top_right = 3
	fg.corner_radius_bottom_right = 3
	fg.corner_radius_bottom_left = 3
	_progress.add_theme_stylebox_override("fill", fg)

	var bg2 := StyleBoxFlat.new()
	bg2.bg_color = Color(0.05, 0.05, 0.08)
	bg2.corner_radius_top_left = 3
	bg2.corner_radius_top_right = 3
	bg2.corner_radius_bottom_right = 3
	bg2.corner_radius_bottom_left = 3
	_progress.add_theme_stylebox_override("background", bg2)
	add_child(_progress)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	_update_label()

func set_hp(current: int, max_hp: int) -> void:
	_target_hp = current
	_target_max = max_hp
	if _progress:
		_progress.max_value = max_hp
		_progress.value     = current
	_update_label()

func set_label(text: String) -> void:
	label_text = text
	_update_label()

func _update_label() -> void:
	if _label:
		_label.text = "%s  %d/%d" % [label_text, _target_hp, _target_max]
