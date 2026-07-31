extends CanvasLayer
class_name LoadingScreen

const _WorldChunk := preload("res://scripts/world/chunk/world_chunk.gd")

const MIN_DISPLAY_TIME: float = 2.0
const FADE_IN_TIME: float = 1.0
const FADE_OUT_TIME: float = 0.6
const VOXEL: float = 10.0
const NUM_VOX: int = 24
const TIPS: Array[String] = [
	"TIP_BUILD_SHELTER", "TIP_CRAFT_TOOLS", "TIP_FIND_FOOD",
	"TIP_EXPLORE_CAVES", "TIP_FISHING", "TIP_FARMING",
]
const TIP_FALLBACK: Dictionary = {
	"TIP_BUILD_SHELTER": "Build a shelter before nightfall!",
	"TIP_CRAFT_TOOLS": "Craft better tools to mine faster.",
	"TIP_FIND_FOOD": "Hungry? Fish or farm to stay fed.",
	"TIP_EXPLORE_CAVES": "Caves hold rare ores — but danger too.",
	"TIP_FISHING": "Cast your line near water to catch fish.",
	"TIP_FARMING": "Plant seeds near water for steady food.",
}

var _progress: float = 0.0
var _elapsed: float = 0.0
var _done: bool = false
var _started: bool = false
var _entering: bool = true
var _exiting: bool = false
var _exit_progress: float = 0.0
var _world_ready: bool = false
var _world_instance: Node = null
var _show_prompt: bool = false
var _prompt_state: bool = false
var _prompt_timer: float = 0.0

var _bg: ColorRect
var _fade: ColorRect
var _frame: ColorRect
var _voxels: Array[ColorRect] = []
var _voxel_bgs: Array[ColorRect] = []
var _tip_label: Label
var _prompt_label: Label
var _next_tip_btn: ColorRect
var _glow: ColorRect
var _cube_panels: Array[ColorRect] = []
var _ui_ready: bool = false

func _ready() -> void:
	layer = 100
	_build()
	_ui_ready = true

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	_bg = ColorRect.new()
	_bg.color = Color(0.03, 0.02, 0.06)
	_bg.size = vp
	add_child(_bg)

	# Stars in background
	for i in 60:
		var star := ColorRect.new()
		star.color = Color(1, 1, 1, randf_range(0.1, 0.5))
		star.size = Vector2(2, 2) if randf() > 0.3 else Vector2(1, 1)
		star.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y * 0.7))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)

	# Center cube diorama
	_build_cube(vp)

	# Progress bar frame
	var bw: float = NUM_VOX * (VOXEL + 2.0) - 2.0 + 20.0
	var bh: float = VOXEL + 20.0
	var bx: float = vp.x * 0.5 - bw * 0.5
	var by: float = vp.y * 0.5 + 130.0

	_frame = ColorRect.new()
	_frame.color = Color(0.08, 0.06, 0.14, 0.85)
	_frame.size = Vector2(bw, bh)
	_frame.position = Vector2(bx, by)
	add_child(_frame)

	var vx: float = bx + 10.0
	var vy: float = by + 10.0
	for i in NUM_VOX:
		var bg := ColorRect.new()
		bg.color = Color(0.10, 0.07, 0.18, 0.4)
		bg.size = Vector2(VOXEL, VOXEL)
		bg.position = Vector2(vx + i * (VOXEL + 2.0), vy)
		add_child(bg)
		_voxel_bgs.append(bg)
		var vox := ColorRect.new()
		vox.color = Color(0.22, 0.62, 0.28, 0.85)
		vox.size = Vector2(VOXEL, VOXEL)
		vox.position = Vector2(vx + i * (VOXEL + 2.0), vy)
		vox.visible = false
		add_child(vox)
		_voxels.append(vox)

	# Glow under progress bar
	_glow = ColorRect.new()
	_glow.color = Color(0.22, 0.62, 0.28, 0.08)
	_glow.size = Vector2(bw, 6.0)
	_glow.position = Vector2(bx, by + bh)
	add_child(_glow)

	# Tip label
	_tip_label = Label.new()
	_tip_label.position = Vector2(vp.x * 0.5 - 300, by + bh + 30.0)
	_tip_label.size = Vector2(600, 50)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.add_theme_font_size_override("font_size", 17)
	_tip_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.72, 0.7))
	_tip_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_tip_label.add_theme_constant_override("shadow_offset_x", 1)
	_tip_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_tip_label)
	_pick_tip()

	# Prompt label (hidden)
	_prompt_label = Label.new()
	_prompt_label.position = Vector2(vp.x * 0.5 - 200, vp.y * 0.5 + 60.0)
	_prompt_label.size = Vector2(400, 36)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 22)
	_prompt_label.add_theme_color_override("font_color", Color(0.22, 0.62, 0.28, 0.9))
	_prompt_label.text = tr("PRESS_ANY_KEY")
	_prompt_label.visible = false
	add_child(_prompt_label)

	# Fade overlay
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.size = vp
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	set_process_input(true)

func _build_cube(vp: Vector2) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5 - 40.0
	var cs: float = 60.0
	# 3 face cube (isometric style)
	var cols: Array[Color] = [
		Color(0.22, 0.62, 0.28, 0.7),
		Color(0.18, 0.52, 0.24, 0.7),
		Color(0.26, 0.70, 0.32, 0.7),
	]
	var offs: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(-cs * 0.25, -cs * 0.25),
		Vector2(0, -cs * 0.5),
	]
	for j in 3:
		var face := ColorRect.new()
		face.color = cols[j]
		face.size = Vector2(cs, cs)
		face.position = Vector2(cx - cs * 0.5 + offs[j].x, cy - cs * 0.5 + offs[j].y)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(face)
		_cube_panels.append(face)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_spawn_particles(event.position)
		if _show_prompt:
			_trigger_exit()

func _spawn_particles(pos: Vector2) -> void:
	for p in 6:
		var dot := ColorRect.new()
		dot.color = Color(randf_range(0.2, 0.9), randf_range(0.5, 0.9), randf_range(0.2, 0.9), 0.8)
		dot.size = Vector2(4, 4) if p % 2 == 0 else Vector2(3, 3)
		dot.position = pos + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		add_child(dot)
		var pt := create_tween()
		pt.tween_property(dot, "position", dot.position + Vector2(randf_range(-60, 60), randf_range(-60, 60)), 0.6).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(dot, "modulate:a", 0.0, 0.6)
		pt.tween_callback(dot.queue_free)

func _pick_tip() -> void:
	var key: String = TIPS[randi() % TIPS.size()]
	var txt: String = tr(key)
	if txt == key:
		txt = TIP_FALLBACK.get(key, key)
	_tip_label.text = txt

func _process(delta: float) -> void:
	_elapsed += delta
	var vp := get_viewport().get_visible_rect().size

	if _entering:
		var t: float = min(_elapsed / FADE_IN_TIME, 1.0)
		_fade.color.a = 1.0 - (1.0 - pow(1.0 - t, 3.0))
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
		_fade.color.a = 1.0 - (t * t)
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
			_WorldChunk.prewarm_async()
		elif st.size() > 0:
			_progress = (st[0] as float) * 0.85

	if _done and _world_instance == null \
			and _WorldChunk._networks_ready \
			and _WorldChunk._networks_seed == WorldSeed.seed_value:
		_progress = 1.0
		_start_world()

	# Update progress bar
	var filled: int = mini(NUM_VOX, floori(_progress * float(NUM_VOX)))
	for i in NUM_VOX:
		if i < filled and not _voxels[i].visible:
			_voxels[i].visible = true
			_voxels[i].modulate = Color(1, 1, 1, 0)
			_voxels[i].scale = Vector2(0.01, 0.01)
			var vt := create_tween()
			vt.tween_property(_voxels[i], "modulate", Color.WHITE, 0.15)
			vt.parallel().tween_property(_voxels[i], "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		elif i >= filled:
			if _voxels[i].visible:
				_voxels[i].visible = false

	if _done and _world_ready:
		if _elapsed >= MIN_DISPLAY_TIME and not _show_prompt:
			_show_prompt = true
			_prompt_label.visible = true
		if _show_prompt:
			_prompt_timer += delta
			if _prompt_timer >= 0.5:
				_prompt_timer = 0.0
				_prompt_state = not _prompt_state
				_prompt_label.modulate.a = 1.0 if _prompt_state else 0.3

	# Rotate center cube
	for j in 3:
		var f: ColorRect = _cube_panels[j]
		var c: float = cos(_elapsed * 0.5 + j * 2.0)
		f.modulate.a = 0.5 + c * 0.2

	# Glow pulse
	_glow.modulate.a = 0.06 + sin(_elapsed * 1.5) * 0.04

func _start_world() -> void:
	var packed: PackedScene = ResourceLoader.load_threaded_get(WorldSeed.target_scene)
	_world_instance = packed.instantiate()
	_world_instance.visible = false
	get_tree().root.add_child(_world_instance)

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
		var found := _find_world_manager(c)
		if found:
			return found
	return null

func _on_world_ready() -> void:
	_world_ready = true

func _trigger_exit() -> void:
	_exiting = true
	_exit_progress = 0.0
	_fade.color.a = 0.0
	# Shatter: scale all voxels to 0
	for v in _voxels:
		if v.visible:
			var vt := create_tween()
			vt.tween_property(v, "scale", Vector2(0.01, 0.01), 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			vt.parallel().tween_property(v, "modulate:a", 0.0, 0.3)
	for f in _cube_panels:
		var vt := create_tween()
		vt.tween_property(f, "scale", Vector2(0.01, 0.01), 0.3).set_ease(Tween.EASE_IN)
		vt.parallel().tween_property(f, "modulate:a", 0.0, 0.3)

func _finish_transition() -> void:
	if _world_instance:
		get_tree().current_scene = _world_instance
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _ui_ready:
		_pick_tip()
