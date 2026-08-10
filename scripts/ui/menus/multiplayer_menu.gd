extends Control

## UI Multiplayer — LAN browser.
## Mở menu sẽ quét broadcast để tìm các host đang mở thế giới trong mạng LAN.
## Có host thì hiển thị danh sách, không có thì không hiển thị. Ở dưới có nút
## "Nâng cao" — bấm sẽ mở ngay trong chính menu này (không mở UI mới) để nhập
## IP/Port thủ công khi host không tự quét thấy.

const BG_PANEL := Color(0.10, 0.07, 0.18)
const BG_CARD := Color(0.14, 0.10, 0.22)
const PURPLE := Color(0.22, 0.62, 0.28)
const TEAL := Color(0.12, 0.52, 0.32)
const TEXT_BRIGHT := Color(0.95, 0.92, 1.0)
const TEXT_MAIN := Color(0.82, 0.78, 0.95)
const TEXT_DIM := Color(0.55, 0.50, 0.72)
const TEXT_MUTED := Color(0.35, 0.32, 0.50)

var _name_input: LineEdit
var _hosts_container: VBoxContainer
var _hosts_scroll: ScrollContainer
var _status_label: Label
var _empty_label: Label

var _adv_btn: Button
var _adv_panel: Control
var _ip_input: LineEdit
var _port_input: LineEdit
var _join_btn: Button
var _adv_expanded: bool = false

func _ready() -> void:
	_build()

func _exit_tree() -> void:
	Net.stop_browser()

func setup() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_clear_host_rows()
	Net.found_hosts.clear()
	_show_status(tr("MP_SCANNING"))
	Net.start_browser()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_texts()

func _refresh_texts() -> void:
	if _adv_btn == null:
		return
	_adv_btn.text = tr("MP_ADVANCED")
	_join_btn.text = tr("MP_JOIN")
	_name_input.placeholder_text = tr("MP_YOUR_NAME")
	_show_status(_status_label.text)

func _make_style(bg: Color, radius: float, border_w: int, border_c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	s.set_border_width_all(border_w)
	s.border_color = border_c
	return s

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var pw: float = min(vp.x * 0.5, 580.0)
	var ph: float = min(vp.y * 0.66, 620.0)
	var px: float = (vp.x - pw) * 0.5
	var py: float = (vp.y - ph) * 0.5

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.size = vp
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := Panel.new()
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	panel.add_theme_stylebox_override("panel", _make_style(BG_PANEL, 14, 2, Color(0.35, 0.28, 0.50, 0.25)))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var accent := ColorRect.new()
	accent.position = Vector2(2, 2)
	accent.size = Vector2(pw - 4, 3)
	accent.color = PURPLE
	panel.add_child(accent)

	var input_style := _make_style(Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.80), 6, 2, Color(0.35, 0.28, 0.50, 0.20))
	var lx: float = 28.0
	var lw: float = pw - 56.0

	var title := Label.new()
	title.text = "Multiplayer"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.90))
	title.position = Vector2(lx, 22)
	title.size = Vector2(lw, 38)
	panel.add_child(title)

	var sub := Label.new()
	sub.text = tr("MP_SCANNING_HINT")
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.6))
	sub.position = Vector2(lx, 62)
	sub.size = Vector2(lw, 24)
	panel.add_child(sub)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = tr("MP_YOUR_NAME")
	_name_input.text = "Player"
	_name_input.add_theme_stylebox_override("normal", input_style)
	_name_input.add_theme_font_size_override("font_size", 19)
	_name_input.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.9))
	_name_input.add_theme_color_override("placeholder_color", TEXT_MUTED)
	_name_input.position = Vector2(lx, 94)
	_name_input.size = Vector2(lw, 40)
	_name_input.max_length = 20
	panel.add_child(_name_input)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.95))
	_status_label.position = Vector2(lx, 142)
	_status_label.size = Vector2(lw, 24)
	panel.add_child(_status_label)

	# ── Danh sách host (chỉ hiển thị khi có host) ─────────────────────────────
	_hosts_scroll = ScrollContainer.new()
	_hosts_scroll.position = Vector2(lx, 174)
	_hosts_scroll.size = Vector2(lw, ph - 300)
	_hosts_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hosts_scroll.visible = false
	panel.add_child(_hosts_scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	_hosts_scroll.add_child(inner)
	_hosts_container = inner

	_empty_label = Label.new()
	_empty_label.text = tr("MP_NO_HOSTS")
	_empty_label.add_theme_font_size_override("font_size", 18)
	_empty_label.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.7))
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.position = Vector2(lx, 174)
	_empty_label.size = Vector2(lw, ph - 300)
	_empty_label.visible = false
	panel.add_child(_empty_label)

	# ── Nâng cao (mở ngay trong menu, không mở UI mới) ───────────────────────
	_adv_btn = Button.new()
	_adv_btn.text = tr("MP_ADVANCED")
	_adv_btn.flat = true
	_adv_btn.add_theme_font_size_override("font_size", 18)
	_adv_btn.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.85))
	_adv_btn.add_theme_color_override("font_hover_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 1.0))
	_adv_btn.position = Vector2(lx, ph - 118)
	_adv_btn.size = Vector2(200, 34)
	_adv_btn.pressed.connect(_toggle_advanced)
	panel.add_child(_adv_btn)

	var back_btn := Button.new()
	back_btn.text = tr("BACK")
	back_btn.position = Vector2(28, ph - 64)
	back_btn.size = Vector2(160, 48)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.add_theme_stylebox_override("normal", _make_style(Color(0.40, 0.30, 0.55, 0.06), 8, 1, Color(0.40, 0.30, 0.55, 0.15)))
	back_btn.add_theme_stylebox_override("hover", _make_style(Color(0.40, 0.30, 0.55, 0.16), 8, 1, Color(0.40, 0.30, 0.55, 0.30)))
	back_btn.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.75))
	back_btn.pressed.connect(_on_back)
	panel.add_child(back_btn)

	_join_btn = Button.new()
	_join_btn.text = tr("MP_JOIN")
	_join_btn.position = Vector2(pw - 188, ph - 64)
	_join_btn.size = Vector2(160, 48)
	_join_btn.add_theme_font_size_override("font_size", 22)
	_join_btn.add_theme_stylebox_override("normal", _make_style(Color(TEAL.r, TEAL.g, TEAL.b, 0.20), 8, 2, Color(TEAL.r, TEAL.g, TEAL.b, 0.30)))
	_join_btn.add_theme_stylebox_override("hover", _make_style(Color(TEAL.r, TEAL.g, TEAL.b, 0.35), 8, 2, Color(TEAL.r, TEAL.g, TEAL.b, 0.50)))
	_join_btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.95))
	_join_btn.pressed.connect(_on_join)
	panel.add_child(_join_btn)

	# ── Panel nâng cao: nhập IP/Port thủ công ─────────────────────────────────
	_adv_panel = Control.new()
	_adv_panel.position = Vector2(lx, ph - 196)
	_adv_panel.size = Vector2(lw, 70)
	_adv_panel.visible = false
	panel.add_child(_adv_panel)

	var ip_lbl := Label.new()
	ip_lbl.text = "IP"
	ip_lbl.add_theme_font_size_override("font_size", 15)
	ip_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.55))
	ip_lbl.position = Vector2(0, 0)
	ip_lbl.size = Vector2(60, 22)
	_adv_panel.add_child(ip_lbl)

	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.add_theme_stylebox_override("normal", input_style)
	_ip_input.add_theme_font_size_override("font_size", 18)
	_ip_input.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.9))
	_ip_input.add_theme_color_override("placeholder_color", TEXT_MUTED)
	_ip_input.position = Vector2(60, 0)
	_ip_input.size = Vector2(lw - 60 - 110, 36)
	_ip_input.max_length = 45
	_adv_panel.add_child(_ip_input)

	var port_lbl := Label.new()
	port_lbl.text = "Port"
	port_lbl.add_theme_font_size_override("font_size", 15)
	port_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.55))
	port_lbl.position = Vector2(lw - 110, 0)
	port_lbl.size = Vector2(110, 22)
	_adv_panel.add_child(port_lbl)

	_port_input = LineEdit.new()
	_port_input.text = str(Net.DEFAULT_PORT)
	_port_input.add_theme_stylebox_override("normal", input_style)
	_port_input.add_theme_font_size_override("font_size", 18)
	_port_input.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.9))
	_port_input.add_theme_color_override("placeholder_color", TEXT_MUTED)
	_port_input.position = Vector2(lw - 110, 20)
	_port_input.size = Vector2(110, 36)
	_port_input.max_length = 5
	_adv_panel.add_child(_port_input)

	visible = false
	Net.hosts_updated.connect(_on_hosts_updated)

func _on_hosts_updated(hosts: Array) -> void:
	_clear_host_rows()
	if hosts.size() == 0:
		_hosts_scroll.visible = false
		_empty_label.visible = true
		_show_status("")
		return
	_hosts_scroll.visible = true
	_empty_label.visible = false
	_show_status("")
	for h in hosts:
		var row := Button.new()
		row.text = "%s  (%s)  •  %d người chơi" % [str(h.get("name", "?")), str(h.get("ip", "")), int(h.get("players", 1))]
		row.add_theme_font_size_override("font_size", 19)
		row.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.92))
		row.add_theme_stylebox_override("normal", _make_style(Color(0.18, 0.30, 0.20, 0.30), 8, 1, Color(TEAL.r, TEAL.g, TEAL.b, 0.20)))
		row.add_theme_stylebox_override("hover", _make_style(Color(0.18, 0.42, 0.24, 0.45), 8, 1, Color(TEAL.r, TEAL.g, TEAL.b, 0.40)))
		row.custom_minimum_size = Vector2(0, 46)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var host: Variant = h
		row.pressed.connect(_on_host_clicked.bind(host))
		_hosts_container.add_child(row)

func _clear_host_rows() -> void:
	for c in _hosts_container.get_children():
		(c as Control).queue_free()

func _show_status(text: String) -> void:
	_status_label.text = text

func _toggle_advanced() -> void:
	_adv_expanded = not _adv_expanded
	_adv_panel.visible = _adv_expanded

func _on_host_clicked(host: Dictionary) -> void:
	_ip_input.text = str(host.get("ip", ""))
	_port_input.text = str(int(host.get("port", Net.DEFAULT_PORT)))
	_join_manual()

func _on_join() -> void:
	_join_manual()

func _join_manual() -> void:
	var ip: String = _ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var port: int = int(_port_input.text.strip_edges()) if _port_input.text.strip_edges().is_valid_int() else Net.DEFAULT_PORT
	var name: String = _name_input.text.strip_edges()
	if name.is_empty():
		name = "Player"
	if not Net.join_game(ip, port, name):
		_show_status(tr("MP_JOIN_FAILED"))
		return
	Net.stop_browser()
	_show_status(tr("MP_CONNECTING"))
	Net.welcome_received.connect(_on_welcome_received, CONNECT_ONE_SHOT)
	Net.multiplayer_stopped.connect(_on_join_abort, CONNECT_ONE_SHOT)

func _on_welcome_received() -> void:
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")

func _on_join_abort() -> void:
	_show_status(tr("MP_JOIN_FAILED"))
	Net.start_browser()

func _on_back() -> void:
	Net.stop_browser()
	visible = false
