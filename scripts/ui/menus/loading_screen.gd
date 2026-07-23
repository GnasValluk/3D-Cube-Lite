extends CanvasLayer
class_name LoadingScreen

const BG_DEEP := Color(0.06, 0.04, 0.12)
const BG_PANEL := Color(0.10, 0.07, 0.18)
const BG_CARD := Color(0.14, 0.10, 0.22)
const PURPLE := Color(0.55, 0.35, 0.90)
const TEAL := Color(0.15, 0.72, 0.68)
const PINK := Color(0.82, 0.28, 0.52)
const ORANGE := Color(0.92, 0.52, 0.12)
const CYAN := Color(0.15, 0.62, 0.92)
const TEXT_BRIGHT := Color(0.95, 0.92, 1.0)
const TEXT_MAIN := Color(0.82, 0.78, 0.95)
const TEXT_DIM := Color(0.55, 0.50, 0.72)
const TEXT_MUTED := Color(0.35, 0.32, 0.50)

const MIN_DISPLAY_TIME: float = 2.0
const FADE_IN_TIME: float = 0.7
const FADE_OUT_TIME: float = 0.6

var _progress: float = 0.0
var _elapsed: float = 0.0
var _done: bool = false
var _started: bool = false
var _entering: bool = true
var _exiting: bool = false
var _exit_progress: float = 0.0

var _fade: ColorRect
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _bar_container: Control
var _title: Label
var _sub: Label
var _progress_lbl: Label
var _bar_width: float
var _bar_height: float = 26.0
var _pulse: float = 0.0

func _ready() -> void:
	_build()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_texts()

func _refresh_texts() -> void:
	if not _sub: return
	if WorldSeed.world_name.length() > 0:
		_sub.text = WorldSeed.world_name + "   |   " + tr("SEED").replace("%d", str(WorldSeed.seed_value))
	else:
		_sub.text = tr("SEED").replace("%d", str(WorldSeed.seed_value))
	_progress_lbl.text = tr("LOADING_TEXT")

func _load_translations() -> void:
	var path: String = "res://translations/game.csv"
	if not FileAccess.file_exists(path):
		return
	for locale in ["vi", "en"]:
		var col: int = 1 if locale == "en" else 2
		var t := Translation.new()
		t.locale = locale
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var header: bool = true
			while not f.eof_reached():
				var line = f.get_csv_line()
				if line.is_empty() or line[0].is_empty():
					continue
				if header:
					header = false
					continue
				if line.size() > col:
					t.add_message(line[0], line[col])
			f.close()
		TranslationServer.add_translation(t)

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	_bar_width = min(vp.x * 0.6, 560.0)

	var bg := ColorRect.new()
	bg.color = BG_DEEP
	bg.size = vp
	add_child(bg)

	var grid := ColorRect.new()
	grid.color = Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.4)
	grid.size = vp
	grid.material = _make_grid_mat(vp)
	add_child(grid)

	_title = Label.new()
	_title.text = "Tila'Adventure"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 80)
	_title.add_theme_color_override("font_color", Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.95))
	_title.add_theme_color_override("font_shadow_color", Color(0.30, 0.15, 0.50, 0.6))
	_title.add_theme_constant_override("shadow_offset_x", 3)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.position = Vector2(0, vp.y * 0.5 - 120)
	_title.size = Vector2(vp.x, 80)
	add_child(_title)

	_sub = Label.new()
	if WorldSeed.world_name.length() > 0:
		_sub.text = WorldSeed.world_name + "   |   " + tr("SEED").replace("%d", str(WorldSeed.seed_value))
	else:
		_sub.text = tr("SEED").replace("%d", str(WorldSeed.seed_value))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 22)
	_sub.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.6))
	_sub.add_theme_constant_override("shadow_offset_x", 1)
	_sub.add_theme_constant_override("shadow_offset_y", 1)
	_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_sub.position = Vector2(0, vp.y * 0.5 - 50)
	_sub.size = Vector2(vp.x, 30)
	add_child(_sub)

	_bar_container = Control.new()
	_bar_container.position = Vector2((vp.x - _bar_width) * 0.5, vp.y * 0.5 + 20)
	_bar_container.size = Vector2(_bar_width, _bar_height)
	add_child(_bar_container)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.9)
	_bar_bg.size = Vector2(_bar_width, _bar_height)
	_bar_bg.position = Vector2.ZERO
	_bar_container.add_child(_bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(TEAL.r, TEAL.g, TEAL.b, 0.85)
	_bar_fill.size = Vector2(0, _bar_height - 4)
	_bar_fill.position = Vector2(2, 2)
	_bar_container.add_child(_bar_fill)

	_progress_lbl = Label.new()
	_progress_lbl.text = tr("LOADING_TEXT")
	_progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_lbl.add_theme_font_size_override("font_size", 18)
	_progress_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.7))
	_progress_lbl.position = Vector2(0, _bar_container.position.y + _bar_height + 8)
	_progress_lbl.size = Vector2(vp.x, 24)
	add_child(_progress_lbl)

	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.size = vp
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

func _make_grid_mat(vp: Vector2) -> Material:
	var m := ShaderMaterial.new()
	m.shader = _grid_shader()
	m.set_shader_parameter("vp", vp)
	return m

static func _grid_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform vec2 vp;
void fragment() {
	vec2 uv = FRAGCOORD.xy / vp;
	vec2 g = fract(uv * 30.0);
	float l = min(g.x, g.y);
	float a = smoothstep(0.04, 0.02, l) * 0.15;
	COLOR = vec4(0.35, 0.25, 0.65, a);
}
"""
	return s

func _process(delta: float) -> void:
	_elapsed += delta
	_pulse += delta

	if _entering:
		var t: float = min(_elapsed / FADE_IN_TIME, 1.0)
		var ease := 1.0 - pow(1.0 - t, 3.0)
		_fade.color.a = 1.0 - ease
		var y_offset: float = (1.0 - ease) * 40.0
		_title.position.y = (get_viewport().get_visible_rect().size.y * 0.5 - 120) - y_offset
		_sub.modulate.a = ease * 0.6
		_bar_container.modulate.a = max(0.0, (t - 0.3) / 0.7)
		if t >= 1.0:
			_entering = false
		return

	if _exiting:
		_exit_progress += delta
		var t: float = min(_exit_progress / FADE_OUT_TIME, 1.0)
		var ease := t * t
		_fade.color.a = ease
		if t >= 1.0:
			var res := ResourceLoader.load_threaded_get(WorldSeed.target_scene)
			get_tree().change_scene_to_packed(res)
		return

	if not _started:
		_started = true
		ResourceLoader.load_threaded_request(WorldSeed.target_scene)

	if not _done:
		var st: Array = []
		var ret := ResourceLoader.load_threaded_get_status(WorldSeed.target_scene, st)
		if ret == ResourceLoader.THREAD_LOAD_LOADED:
			_done = true
			_progress = 1.0
		elif st.size() > 0:
			_progress = st[0] as float

	var pulse_wave := sin(_pulse * 3.0) * 0.03
	var fill_w: float = max(0.0, _bar_width - 4.0) * _progress
	_bar_fill.size.x = fill_w

	var base_color := TEAL
	var bright := 0.85 + pulse_wave * 2.0
	_bar_fill.color = Color(base_color.r * bright, base_color.g * bright, base_color.b * bright, 0.85)

	_title.add_theme_color_override("font_color", Color(
		PURPLE.r + pulse_wave * 0.2, PURPLE.g + pulse_wave * 0.15, PURPLE.b + pulse_wave * 0.1, 0.95))

	if _done:
		_progress_lbl.text = tr("READY_TEXT")
		if _elapsed >= MIN_DISPLAY_TIME:
			_exiting = true
			_exit_progress = 0.0
			_fade.color.a = 0.0
