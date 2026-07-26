extends CanvasLayer
class_name LoadingScreen

const MIN_DISPLAY_TIME: float = 2.0
const FADE_IN_TIME: float = 1.0
const FADE_OUT_TIME: float = 0.6

var _progress: float = 0.0
var _elapsed: float = 0.0
var _done: bool = false
var _started: bool = false
var _entering: bool = true
var _exiting: bool = false
var _exit_progress: float = 0.0
var _world_ready: bool = false
var _world_instance: Node = null

var _bg: ColorRect
var _fade: ColorRect
var _spinner: ColorRect
var _world_info: Label
var _spinner_container: Control

func _ready() -> void:
	layer = 100
	_build()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_texts()

func _refresh_texts() -> void:
	if not _world_info: return
	_update_world_info()

func _update_world_info() -> void:
	var info: String = ""
	if WorldSeed.world_name.length() > 0:
		info = WorldSeed.world_name + "  |  " + tr("SEED").replace("%d", str(WorldSeed.seed_value))
	else:
		info = tr("SEED").replace("%d", str(WorldSeed.seed_value))
	_world_info.text = info

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

	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 1.0)
	_bg.size = vp
	add_child(_bg)

	var margin: float = 24.0
	var spinner_size: float = 28.0

	_spinner_container = Control.new()
	_spinner_container.position = Vector2(vp.x - 180 - margin, vp.y - 80 - margin)
	_spinner_container.size = Vector2(180, 80)
	add_child(_spinner_container)

	_spinner = ColorRect.new()
	_spinner.color = Color(0.22, 0.62, 0.28, 0.85)
	_spinner.size = Vector2(spinner_size, spinner_size)
	_spinner.position = Vector2(0, 80 - spinner_size)
	_spinner_container.add_child(_spinner)

	_world_info = Label.new()
	_update_world_info()
	_world_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_world_info.add_theme_font_size_override("font_size", 16)
	_world_info.add_theme_color_override("font_color", Color(0.55, 0.50, 0.72, 0.5))
	_world_info.position = Vector2(0, 0)
	_world_info.size = Vector2(180, 60)
	_world_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spinner_container.add_child(_world_info)

	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.size = vp
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

func _process(delta: float) -> void:
	_elapsed += delta

	if _entering:
		var t: float = min(_elapsed / FADE_IN_TIME, 1.0)
		var ease := 1.0 - pow(1.0 - t, 3.0)
		_fade.color.a = 1.0 - ease
		_spinner_container.modulate.a = ease
		if t >= 1.0:
			_entering = false
		return

	if _exiting:
		if _exit_progress == 0.0:
			_world_instance.visible = true
			_bg.visible = false
			_fade.color.a = 1.0
		_exit_progress += delta
		var t: float = min(_exit_progress / FADE_OUT_TIME, 1.0)
		var ease := t * t
		_fade.color.a = 1.0 - ease
		if t >= 1.0:
			_finish_transition()
		return

	if not _started:
		_started = true
		ResourceLoader.load_threaded_request(WorldSeed.target_scene)
		return

	if not _done:
		var st: Array = []
		var ret := ResourceLoader.load_threaded_get_status(WorldSeed.target_scene, st)
		if ret == ResourceLoader.THREAD_LOAD_LOADED:
			_done = true
			_progress = 1.0
			_start_world()
		elif st.size() > 0:
			_progress = st[0] as float

	if _done and _world_ready:
		if _elapsed >= MIN_DISPLAY_TIME:
			_exiting = true
			_exit_progress = 0.0
			_fade.color.a = 0.0

	# Rotate spinner
	_spinner.rotation_degrees += delta * 360.0 * 0.6

func _start_world() -> void:
	var packed: PackedScene = ResourceLoader.load_threaded_get(WorldSeed.target_scene)
	_world_instance = packed.instantiate()
	_world_instance.visible = false
	get_tree().root.add_child(_world_instance)

	# Find the world manager and wait for initial chunks
	var mgr := _find_world_manager(_world_instance)
	if mgr:
		if mgr.get("_loading_ready"):
			_world_ready = true
		else:
			mgr.initial_chunks_ready.connect(_on_world_ready)
	else:
		_world_ready = true

func _find_world_manager(node: Node) -> Node:
	if node.has_signal("initial_chunks_ready"):
		return node
	for c in node.get_children():
		var found = _find_world_manager(c)
		if found:
			return found
	return null

func _on_world_ready() -> void:
	_world_ready = true

func _finish_transition() -> void:
	if _world_instance:
		get_tree().current_scene = _world_instance
	queue_free()
