## experience_orb.gd
## Hạt kinh nghiệm phát sáng — nhặt vào nhận 1 điểm XP.
## Rớt ra từ sinh vật bị giết (cá 5%, heo 7%).

class_name ExperienceOrb
extends Area3D

const MAGNET_RANGE: float = 3.2
const FLY_SPEED: float = 9.0
const PICKUP_DISTANCE: float = 1.5
const XP_VALUE: int = 1

var _time_alive: float = 0.0
var _can_pickup: bool = false
var _flying: bool = false
var _velocity: Vector3 = Vector3.ZERO
var _ground_y: float = 0.0
var _player: Node3D = null
var _mat: StandardMaterial3D = null
var _mesh: MeshInstance3D = null

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
	_mat.emission = Color(0.35, 1.0, 0.55)
	_mat.emission_energy_multiplier = 4.0
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(0.35, 1.0, 0.55, 0.95)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var core := SphereMesh.new()
	core.radius = 0.12
	core.height = 0.24
	_mesh = MeshInstance3D.new()
	_mesh.mesh = core
	_mesh.material_override = _mat
	_mesh.position = Vector3(0, 0.2, 0)
	add_child(_mesh)

	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color = Color(0.35, 1.0, 0.55, 0.22)
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glow := SphereMesh.new()
	glow.radius = 0.26
	glow.height = 0.52
	var glow_mi := MeshInstance3D.new()
	glow_mi.mesh = glow
	glow_mi.material_override = glow_mat
	glow_mi.position = Vector3(0, 0.2, 0)
	add_child(glow_mi)

	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.6)
	light.light_energy = 1.6
	light.omni_range = 2.4
	light.position = Vector3(0, 0.3, 0)
	add_child(light)

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

	# Nhấp nháy phát sáng
	if _mat:
		var pulse: float = 0.75 + sin(_time_alive * 6.0) * 0.25
		_mat.albedo_color = Color(0.35, 1.0, 0.55, pulse)
		_mat.emission = Color(0.35, 1.0, 0.55) * (2.0 + pulse)

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
