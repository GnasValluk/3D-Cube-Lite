extends Node

const ICON_SIZE := 128

var _viewport: SubViewport
var _root: Node3D
var _camera: Camera3D

var _cache: Dictionary = {}
var _pending: Dictionary = {}
var _queue: Array[String] = []
var _rendering: String = ""

signal texture_ready(item_id: String, texture: Texture2D)

func _ready():
	_viewport = SubViewport.new()
	_viewport.name = "IconViewport"
	_viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = false
	add_child(_viewport)

	var world_env := WorldEnvironment.new()
	world_env.environment = Environment.new()
	world_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.environment.ambient_light_color = Color(0.4, 0.4, 0.45)
	world_env.environment.ambient_light_energy = 0.8
	_viewport.add_child(world_env)

	_root = Node3D.new()
	_root.name = "IconRoot"
	_viewport.add_child(_root)

	_camera = Camera3D.new()
	_camera.name = "IconCamera"
	_camera.current = true
	_camera.position = Vector3(0, 0.2, 0.6)
	_root.add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	for lp in [{pos=Vector3(2,4,3), en=1.2}, {pos=Vector3(-2,1,-3), en=0.4}]:
		var light := DirectionalLight3D.new()
		light.light_energy = lp.en
		light.position = lp.pos
		_root.add_child(light)
		light.look_at(Vector3.ZERO)

func get_texture(item_id: String) -> Texture2D:
	if _cache.has(item_id):
		return _cache[item_id]

	var path := ItemDatabase.get_icon_2d_path(item_id)
	if not path.is_empty():
		var tex := load(path) as Texture2D
		if tex:
			_cache[item_id] = tex
			return tex

	if not _pending.has(item_id):
		_pending[item_id] = true
		_queue.append(item_id)
	return null

func _process(_delta: float) -> void:
	if _rendering != "":
		var img := _viewport.get_texture().get_image()
		if img:
			var tex := ImageTexture.create_from_image(img)
			_cache[_rendering] = tex
			_pending.erase(_rendering)
			texture_ready.emit(_rendering, tex)
		_rendering = ""

	if _rendering == "" and _queue.size() > 0:
		var item_id: String = _queue.pop_front()
		_render_item(item_id)

func _render_item(item_id: String) -> void:
	for child in _root.get_children():
		if child != _camera:
			child.queue_free()

	var pivot := Node3D.new()
	pivot.name = "item"
	_root.add_child(pivot)

	if item_id in ["cup", "xeng", "riu", "kiem", "can_cau"]:
		ToolsMesh.build_held(pivot, item_id)
	elif item_id in ["mon_ngot", "rong_nhiet_doi"]:
		PlantProp.build_drop_mesh(pivot, item_id)
	else:
		ItemMesh.build(pivot, item_id)

	_rendering = item_id
