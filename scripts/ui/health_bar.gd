## ui/health_bar.gd
## Thanh HP đẹp với animation mượt + delayed bar + glow.

extends Control
class_name HealthBar

var _bg: ColorRect
var _delay_bar: ColorRect
var _hp_bar: ColorRect
var _glow: ColorRect
var _label: Label

var _hp: float = 100.0
var _max_hp: float = 100.0
var _bar_hp: float = 100.0
var _delay_hp: float = 100.0
var _bar_width: float = 240.0
var _bar_height: float = 18.0

var _tween: Tween

func _enter_tree() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _ready() -> void:
	_setup()

func _setup() -> void:
	size = Vector2(_bar_width + 20, 80)
	custom_minimum_size = size

	_bg = ColorRect.new()
	_bg.size = Vector2(_bar_width, _bar_height)
	_bg.position = Vector2(10, 24)
	_bg.color = Color(0.04, 0.04, 0.08, 0.85)
	_bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bg)

	_delay_bar = ColorRect.new()
	_delay_bar.size = Vector2(_bar_width, _bar_height)
	_delay_bar.position = Vector2(10, 24)
	_delay_bar.color = Color(0.15, 0.25, 0.50, 0.7)
	_delay_bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_delay_bar)

	_hp_bar = ColorRect.new()
	_hp_bar.size = Vector2(_bar_width, _bar_height)
	_hp_bar.position = Vector2(10, 24)
	_hp_bar.color = Color(0.15, 1.0, 0.55)
	_hp_bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_hp_bar)

	_glow = ColorRect.new()
	_glow.size = Vector2(_bar_width, 6)
	_glow.position = Vector2(10, 22)
	_glow.color = Color(0.15, 1.0, 0.55, 0.25)
	_glow.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_glow)

	_label = Label.new()
	_label.position = Vector2(10, 0)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.90))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_label)

	_update_label()

func set_hp(current: int, max_hp: int) -> void:
	_hp = float(current)
	_max_hp = float(max_hp)

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)

	var ratio: float = _hp / _max_hp if _max_hp > 0 else 0.0

	_tween.tween_method(_update_bar, _bar_hp, ratio, 0.15).set_ease(Tween.EASE_OUT)

	_tween.tween_method(_update_delay, _delay_hp, ratio, 0.55).set_ease(Tween.EASE_OUT).set_delay(0.08)

	var c: Color = _hp_color(ratio)
	_tween.tween_method(func(v: float): _hp_bar.color = c.lerp(Color(c.r, c.g, c.b, 0.0), 1.0 - v), 1.0, 0.0, 0.15)

	_bar_hp = ratio
	_delay_hp = ratio

	_update_label()

func _update_bar(v: float) -> void:
	_bar_hp = v
	_hp_bar.size.x = max(2.0, _bar_width * v)
	_glow.size.x = max(2.0, _bar_width * v)

func _update_delay(v: float) -> void:
	_delay_hp = v
	_delay_bar.size.x = max(2.0, _bar_width * v)

func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.15, 1.0, 0.55)
	elif ratio > 0.25:
		return Color(1.0, 0.75, 0.15)
	else:
		return Color(1.0, 0.15, 0.15)

func set_label(text: String) -> void:
	_label.text = text

func _update_label() -> void:
	if _label:
		_label.text = "HP"

func get_hp_text() -> String:
	return "%d / %d" % [_hp, _max_hp]
