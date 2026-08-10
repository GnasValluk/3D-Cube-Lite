## characters/player/remote_player.gd
## Đại diện một người chơi từ xa (host hoặc client khác) trên máy này.
## Nhẹ: chỉ có collision capsule + mesh nhân vật + Label3D tên, nhận trạng thái
## di chuyển từ Net (net_move) và lerp mượt. KHÔNG nhận input, KHÔNG chạy
## physics đầy đủ như PlayerCharacter.

extends CharacterBody3D
class_name RemotePlayer

const _Skin := preload("res://scripts/characters/player/player_skin.gd")
const _VoxelBar := preload("res://scripts/ui/hud/voxel_bar.gd")

var peer_id: int = 0
var display_name: String = ""
var hp: int = 100
var max_hp: int = 100
var food: int = 20
var max_food: int = 20
var shield: int = 0
var level: int = 1
var alive: bool = true
var inventory_data: Array = []

var _mesh: PlayerMesh = null
var _label: Label3D = null
var _target_pos: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _moving: bool = false
var _anim_t: float = 0.0

const BAR_W: int = 440
const BAR_H: int = 120
const BAR_SCALE: float = 4.5
const _hp_color := Color(0.78, 0.14, 0.14)
const _food_color := Color(0.77, 0.55, 0.10)

var _sub_viewport: SubViewport = null
var _health_vbar: VoxelBar = null
var _food_vbar: VoxelBar = null
var _bar_mesh: MeshInstance3D = null
var _was_alive: bool = true

func setup(pid: int, p_name: String, spawn_pos: Vector3) -> void:
	peer_id = pid
	display_name = p_name
	build_collision()
	build_visual()
	_target_pos = spawn_pos

func is_remote_for(pid: int) -> bool:
	return peer_id == pid

func set_name_label(p_name: String) -> void:
	display_name = p_name
	if _label:
		_label.text = p_name

func build_collision() -> void:
	collision_layer = 0
	collision_mask = 0
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.32
	cs.height = 1.10
	col.shape = cs
	col.position = Vector3(0, 0.55, 0)
	add_child(col)

func build_visual() -> void:
	var skin_id: String = _Skin.FALLBACK_ID
	_mesh = _Skin.make_mesh(skin_id)
	_mesh.set_palette(_Skin.palette_for(skin_id))
	_mesh.build(self)

	_label = Label3D.new()
	_label.text = display_name
	_label.font_size = 48
	_label.outline_size = 12
	_label.modulate = Color(1, 1, 1, 0.92)
	_label.outline_modulate = Color(0, 0, 0, 0.6)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 1.9, 0)
	add_child(_label)

	_build_health_bar()

func _build_health_bar() -> void:
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(BAR_W, BAR_H)
	_sub_viewport.transparent_bg = true
	_sub_viewport.handle_input_locally = false
	_sub_viewport.disable_3d = true
	add_child(_sub_viewport)

	var root := Control.new()
	root.size = Vector2(BAR_W, BAR_H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_viewport.add_child(root)

	var hb := _VoxelBar.new()
	hb.setup(_hp_color, Color(0.18, 0.04, 0.04), 16, 20)
	hb.position = Vector2(0, 0)
	hb.scale = Vector2(BAR_SCALE, BAR_SCALE)
	root.add_child(hb)
	_health_vbar = hb

	var fb := _VoxelBar.new()
	fb.setup(_food_color, Color(0.15, 0.10, 0.03), 16, 20)
	fb.position = Vector2(0, 60)
	fb.scale = Vector2(BAR_SCALE, BAR_SCALE)
	root.add_child(fb)
	_food_vbar = fb

	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 0.55)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _sub_viewport.get_texture()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_keep_scale = true

	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = mat
	mesh.position = Vector3(0, 1.55, 0)
	add_child(mesh)
	_bar_mesh = mesh

	_refresh_bars()

func apply_state(p_hp: int, p_max_hp: int, p_food: int, p_max_food: int, p_shield: int, p_level: int, p_alive: bool) -> void:
	hp = p_hp
	max_hp = p_max_hp
	food = p_food
	max_food = p_max_food
	shield = p_shield
	level = p_level
	if alive != p_alive:
		alive = p_alive
		_refresh_alive_visual()
	_refresh_bars()

## Ẩn/hiện toàn bộ visual của remote theo trạng thái sống/chết: player chết thì
## rig + bar + tên biến mất (giống local player ẩn rig), respawn thì hiện lại.
func _refresh_alive_visual() -> void:
	var show: bool = alive and hp > 0
	if _mesh and _mesh.rig:
		_mesh.rig.visible = show
	if _label:
		_label.visible = show
	if _bar_mesh:
		_bar_mesh.visible = show

func apply_inventory(data: Array) -> void:
	inventory_data = data

func _refresh_bars() -> void:
	if _health_vbar:
		_health_vbar.max_value = maxi(max_hp, 1)
		_health_vbar.value = hp
	if _food_vbar:
		_food_vbar.max_value = maxi(max_food, 1)
		_food_vbar.value = food if max_food > 0 else 0
		_food_vbar.visible = max_food > 0

func apply_net_state(pos: Vector3, yaw: float, moving: bool) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_moving = moving

func snap_to(pos: Vector3) -> void:
	_target_pos = pos
	global_position = pos

func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(_target_pos, minf(1.0, delta * 12.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, minf(1.0, delta * 12.0))
	if _mesh == null or _mesh.rig == null:
		return
	# Walk swing đơn giản (tay/chân đung đưa khi di chuyển).
	if _moving:
		_anim_t += delta * 9.0
		var s: float = sin(_anim_t)
		if _mesh.leg_l:
			_mesh.leg_l.rotation.x = s * 0.5
		if _mesh.leg_r:
			_mesh.leg_r.rotation.x = -s * 0.5
		if _mesh.arm_l:
			_mesh.arm_l.rotation.x = -s * 0.4
		if _mesh.arm_r:
			_mesh.arm_r.rotation.x = s * 0.4
	else:
		_anim_t = 0.0
		if _mesh.leg_l:
			_mesh.leg_l.rotation.x = 0.0
		if _mesh.leg_r:
			_mesh.leg_r.rotation.x = 0.0
		if _mesh.arm_l:
			_mesh.arm_l.rotation.x = 0.0
		if _mesh.arm_r:
			_mesh.arm_r.rotation.x = 0.0
