## experience_orb.gd
## Hạt kinh nghiệm phát sáng — nhặt vào nhận 1 điểm XP.
## Model: 1 voxel lấp lánh ánh sáng xanh-vàng; rớt ra từ sinh vật bị giết
## (cá 2%, heo 3%, slime 7% ở cấp cơ bản — tỷ lệ nhân theo level creature).

class_name ExperienceOrb
extends Area3D

const MAGNET_RANGE: float = 3.2
const FLY_SPEED: float = 9.0
const PICKUP_DISTANCE: float = 1.5
const XP_VALUE: int = 1
const VOXEL_SIZE: float = 0.15

var _time_alive: float = 0.0
var _can_pickup: bool = false
var _flying: bool = false
var _velocity: Vector3 = Vector3.ZERO
var _ground_y: float = 0.0
var _player: Node3D = null
var _settled: bool = false
var _fall_vel: float = 0.0
var _ground_measured: bool = false

const FALL_GRAVITY: float = 14.0
const FALL_EPS: float = 0.02
const REST_HEIGHT: float = 0.2
var _mat: StandardMaterial3D = null
var _glow_mat: StandardMaterial3D = null
var _mesh: MeshInstance3D = null
var _voxel: Node3D = null

const CORE_BLUE := Color(0.35, 0.75, 1.0)
const CORE_YELLOW := Color(1.0, 0.85, 0.30)

func _init() -> void:
	_setup_mesh()
	_setup_collision()
	call_deferred("_find_player")

	var pickup_timer := Timer.new()
	pickup_timer.one_shot = true
	pickup_timer.autostart = true
	pickup_timer.wait_time = 0.8
	pickup_timer.timeout.connect(func(): _can_pickup = true)
	add_child(pickup_timer)

	var lifetime := Timer.new()
	lifetime.one_shot = true
	lifetime.autostart = true
	lifetime.wait_time = 90.0
	lifetime.timeout.connect(queue_free)
	add_child(lifetime)

func _setup_mesh() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	_mat.emission = CORE_BLUE
	_mat.emission_energy_multiplier = 4.0
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true

	# 1 voxel lấp lánh: cube nhỏ, mỗi mặt đốm màu xanh-vàng luân phiên.
	_voxel = _build_voxel()
	add_child(_voxel)

	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.albedo_color = Color(0.45, 0.85, 1.0, 0.20)
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glow := SphereMesh.new()
	glow.radius = 0.24
	glow.height = 0.48
	var glow_mi := MeshInstance3D.new()
	glow_mi.mesh = glow
	glow_mi.material_override = _glow_mat
	glow_mi.position = Vector3(0, 0.2, 0)
	add_child(glow_mi)

	var light := OmniLight3D.new()
	light.light_color = CORE_BLUE
	light.light_energy = 1.8
	light.omni_range = 2.6
	light.position = Vector3(0, 0.3, 0)
	add_child(light)

## Voxel: 1 khối nhỏ 8 đỉnh, màu từng đỉnh thay đổi giữa xanh/vàng để lấp lánh.
func _build_voxel() -> Node3D:
	var root := Node3D.new()
	var arr := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var s := VOXEL_SIZE * 0.5
	var corners: Array[Vector3] = [
		Vector3(-s, -s, s), Vector3(s, -s, s), Vector3(s, s, s), Vector3(-s, s, s),
		Vector3(-s, -s, -s), Vector3(s, -s, -s), Vector3(s, s, -s), Vector3(-s, s, -s),
	]
	var face_i: Array = [
		[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4],
		[2, 3, 7, 6], [0, 3, 7, 4], [1, 2, 6, 5],
	]
	var face_n: Array[Vector3] = [
		Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(0, 1, 0),
		Vector3(0, -1, 0), Vector3(-1, 0, 0), Vector3(1, 0, 0),
	]
	var verts := 0
	for f in range(6):
		for i in [0, 1, 2, 0, 2, 3]:
			var c: int = face_i[f][i]
			arr.append(corners[c])
			normals.append(face_n[f])
			# Luân phiên xanh/vàng lấp lánh theo từng đỉnh
			var blue: bool = (c + f) % 2 == 0
			colors.append(CORE_BLUE if blue else CORE_YELLOW)
			indices.append(verts)
			verts += 1
	var array_mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = arr
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = array_mesh
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_mesh)
	root.position = Vector3(0, 0.2, 0)
	return root

func _setup_collision() -> void:
	var coll := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	coll.shape = shape
	add_child(coll)
	collision_layer = 1
	collision_mask = 0
	set_process(true)

func _find_player() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var world := tree.current_scene
	if world == null:
		return
	var mgr := world.get_node_or_null("CharacterManager") as CharacterManager
	if mgr:
		_player = mgr.get_current_character()

func launch(initial_velocity: Vector3, ground_y: float) -> void:
	_flying = true
	_velocity = initial_velocity
	_ground_y = ground_y
	# ground_y call-site là hint để kết thúc pha bay; sau khi bay xong phải đo
	# lại mặt đất thật (sinh vật có thể chết giữa không trung → hạt nổi trên trời).
	_ground_measured = false
	_settled = false

func _process(delta: float) -> void:
	if not is_instance_valid(self):
		return
	_time_alive += delta

	if _flying:
		_velocity.y -= 9.8 * delta
		position += _velocity * delta
		if position.y <= _ground_y:
			position.y = _ground_y
			_flying = false
	else:
		if not _settled:
			_fall(delta)
		# Nam châm hút về phía người chơi khi đủ gần
		if _can_pickup and _player and is_instance_valid(_player):
			var to_player := _player.global_position - global_position
			var dist := to_player.length()
			if dist <= PICKUP_DISTANCE:
				collect(_player)
				return
			if dist < MAGNET_RANGE:
				var dir := to_player / maxf(dist, 0.001)
				global_position += dir * FLY_SPEED * delta
				return
		var bob := sin(_time_alive * 3.0) * 0.07
		position.y += bob * delta * 2.0
		rotation.y += delta * 60.0
	# Nhấp nháy xanh-vàng lấp lánh + xoay voxel
	var sparkle: float = 0.6 + (sin(_time_alive * 7.0) * 0.5 + 0.5) * 0.4
	var mix: float = (sin(_time_alive * 4.0) * 0.5 + 0.5)
	var c := CORE_BLUE.lerp(CORE_YELLOW, mix)
	if _voxel:
		_voxel.rotation.y += delta * 3.0
		_voxel.rotation.x += delta * 1.5
		var sc := 0.85 + sin(_time_alive * 9.0) * 0.15
		_voxel.scale = Vector3.ONE * sc
	if _mat:
		_mat.emission = c * (2.0 + sparkle)
	if _glow_mat:
		var pulse: float = 0.15 + sparkle * 0.15
		_glow_mat.albedo_color = Color(c.r, c.g, c.b, pulse)

## Hạt kinh nghiệm rơi từ trên cao: có trọng lực, chạm đất thật rồi nổi lơ lửng
## (không định cư ở độ cao chỗ sinh vật chết giữa trời).
func _fall(delta: float) -> void:
	if not _ground_measured:
		var gy := _measure_ground_y()
		if gy <= -1.0e9:
			_fall_vel -= FALL_GRAVITY * delta
			position.y += _fall_vel * delta
			return
		_ground_measured = true
		_ground_y = gy
	if position.y - REST_HEIGHT > _ground_y + FALL_EPS:
		_fall_vel -= FALL_GRAVITY * delta
		position.y += _fall_vel * delta
	else:
		position.y = _ground_y + REST_HEIGHT
		_settled = true
		_fall_vel = 0.0

func _measure_ground_y() -> float:
	var space := get_world_3d().direct_space_state
	if space != null:
		var q := PhysicsRayQueryParameters3D.new()
		q.from = global_position
		q.to = global_position + Vector3(0, -60.0, 0)
		q.collide_with_areas = false
		q.collide_with_bodies = true
		q.exclude = [self]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return hit.position.y
	return -1.0e9

func collect(player: Node) -> bool:
	if not _can_pickup:
		return false
	if player.has_method("add_exp"):
		player.add_exp(XP_VALUE)
		SFXManager.play_orb()
		queue_free()
		return true
	return false

static func spawn(world: Node, pos: Vector3, ground_y: float = -INF) -> ExperienceOrb:
	var orb := ExperienceOrb.new()
	orb.position = pos + Vector3(0, 0.2, 0)
	var parent := _resolve_world_parent(world)
	if parent == null:
		orb.queue_free()
		return null
	parent.add_child(orb)
	var vel := Vector3(randf_range(-0.8, 0.8), randf_range(2.5, 4.0), randf_range(-0.8, 0.8))
	orb.launch(vel, ground_y if ground_y > -INF else pos.y)
	return orb

## Khi world truyền vào không phải Node3D, tìm thế giới 3D thực tế dưới root.
static func _resolve_world_parent(world: Node) -> Node3D:
	if world == null:
		return null
	if world is Node3D:
		return world as Node3D
	var tree := world.get_tree()
	if tree == null:
		return null
	for child in tree.root.get_children():
		if child is Node3D:
			return child as Node3D
	return null
