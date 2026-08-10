## ui/chat_overlay.gd
## Chat realtime giữa các player. Hiển thị cuối góc trái, nhập tin nhắn bằng
## phím Enter; Enter gửi, Esc đóng. Mọi máy nhận chat_message_received từ Net.
extends Control
class_name ChatOverlay

const MAX_LINES: int = 8
const PANEL_W: float = 520.0
const FONT_SIZE: int = 15

var _hud: HUD
var _panel: Panel
var _lines: VBoxContainer
var _input: LineEdit
var _bg_style: StyleBoxFlat
var _input_open: bool = false

signal message_submitted(text: String)

func _ready() -> void:
	_hud = get_parent() as HUD
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	visible = false

func _build_ui() -> void:
	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = Color(0.05, 0.03, 0.09, 0.55)
	_bg_style.set_corner_radius_all(8)

	_panel = Panel.new()
	_panel.position = Vector2(16, 0)
	_panel.add_theme_stylebox_override("panel", _bg_style)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_lines = VBoxContainer.new()
	_lines.position = Vector2(12, 10)
	_lines.size = Vector2(PANEL_W - 24, 0)
	_lines.add_theme_constant_override("separation", 2)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_lines)

	_input = LineEdit.new()
	_input.position = Vector2(12, 10)
	_input.size = Vector2(PANEL_W - 24, 30)
	_input.visible = false
	_input.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input.add_theme_font_size_override("font_size", FONT_SIZE)
	_input.placeholder_text = tr("CHAT_INPUT_HINT")
	_input.text_submitted.connect(_on_text_submitted)
	_panel.add_child(_input)

func _layout() -> void:
	var vp_h: float = get_viewport_rect().size.y if get_viewport() else 720.0
	_panel.position.y = vp_h - _panel.size.y - 60.0

func add_message(sender_name: String, sender_color: Color, text: String) -> void:
	var rtl := RichTextLabel.new()
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	rtl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	rtl.add_theme_constant_override("shadow_offset_x", 1)
	rtl.add_theme_constant_override("shadow_offset_y", 1)
	var name_color := sender_color.lightened(0.15)
	rtl.text = "[color=#%s]%s:[/color] %s" % [name_color.to_html(false), sender_name, text]
	rtl.custom_minimum_size = Vector2(PANEL_W - 24, 0)
	_lines.add_child(rtl)
	while _lines.get_child_count() > MAX_LINES:
		var first: Node = _lines.get_child(0)
		_lines.remove_child(first)
		first.queue_free()
	_panel.size.y = _lines.size.y + 20.0
	_layout()
	visible = true

func open_input() -> void:
	if _input_open:
		return
	_input_open = true
	_input.visible = true
	_input.text = ""
	_input.grab_focus()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_input.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true

func close_input() -> void:
	if not _input_open:
		return
	_input_open = false
	_input.text = ""
	_input.release_focus()
	_input.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input.mouse_filter = Control.MOUSE_FILTER_IGNORE

func is_input_open() -> bool:
	return _input_open

func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		close_input()
		return
	message_submitted.emit(text)
	close_input()
