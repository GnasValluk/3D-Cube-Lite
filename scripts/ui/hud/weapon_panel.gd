extends Control

## PANEL THÔNG TIN VŨ KHỊ ĐANG CẦM — góc trái dưới màn hình.
##  • Tên item
##  • Sát thương (attack_power + atk_bonus)
##  • Súng/nỏ: ĐẠN TRONG BĂNG / SỨC CHỨA + trạng thái nạp
## Cập nhật mỗi frame từ PlayerCharacter.

var _name_label: Label
var _stat_label: Label
var _ammo_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	position = Vector2(18, -118)
	size = Vector2(340, 110)
	_name_label = _mk_label(17, Color(1, 0.96, 0.86), 0)
	_stat_label = _mk_label(15, Color(0.92, 0.94, 0.98), 28)
	_ammo_label = _mk_label(20, Color(1.0, 0.82, 0.30), 54)

func _mk_label(fs: int, col: Color, y: float) -> Label:
	var l := Label.new()
	l.position = Vector2(0, y)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l

func set_info(name_text: String, stat_text: String, ammo_text: String) -> void:
	if _name_label == null:
		return
	_name_label.text = name_text
	_stat_label.text = stat_text
	_ammo_label.text = ammo_text
	visible = name_text != ""
