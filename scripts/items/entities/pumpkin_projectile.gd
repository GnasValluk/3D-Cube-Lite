class_name PumpkinProjectile
extends Node3D

var _damage: int = 12
var _shooter: Node = null
var _direction: Vector3
var _speed: float = 12.0
var _aoe_radius: float = 2.5
var _hit_something: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _vertical_speed: float = 8.0
var _mesh_root: Node3D
var _spin_speed: float = 6.0
var _trail_timer: float = 0.0
var _spawn_dist: float = 0.0

func setup(dir: Vector3, dmg: int, spd: float, aoe: float, vert_spd: float, shooter: Node) -> void:
	_direction = dir
	_damage = dmg
	_speed = spd
	_aoe_radius = aoe
	_vertical_speed = vert_spd
	_shooter = shooter

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(1.0, 0.55, 0.0)
	orange.roughness = 0.8
	orange.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var orange_dark := StandardMaterial3D.new()
	orange_dark.albedo_color = Color(0.75, 0.40, 0.0)
	orange_dark.roughness = 0.85
	orange_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.15, 0.55, 0.10)
	green.roughness = 0.7
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.45, 0.30, 0.10)
	brown.roughness = 0.9
	brown.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var body := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.2
	sph.height = 0.4
	sph.radial_segments = 12
	sph.rings = 8
	body.mesh = sph
	body.material_override = orange
	body.position = Vector3.ZERO
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_root.add_child(body)

	var ridges := [
		Vector3(0.18, 0.0, 0.0),
		Vector3(-0.18, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.18),
		Vector3(0.0, 0.0, -0.18),
	]
	for rp in ridges:
		var ridge := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.02
		rm.bottom_radius = 0.02
		rm.height = 0.35
		rm.radial_segments = 6
		ridge.mesh = rm
		ridge.material_override = orange_dark
		ridge.position = rp
		ridge.scale = Vector3(0.3, 1.0, 0.3)
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh_root.add_child(ridge)

	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.02
	stem_mesh.bottom_radius = 0.005
	stem_mesh.height = 0.08
	stem_mesh.radial_segments = 6
	stem.mesh = stem_mesh
	stem.material_override = green
	stem.position = Vector3(0, 0.24, 0)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_root.add_child(stem)

func _physics_process(delta: float) -> void:
	if _hit_something:
		return

	var h_step := _direction * _speed * delta
	_vertical_speed -= _gravity * delta
	var v_step := Vector3(0, _vertical_speed * delta, 0)
	var next_pos := global_position + h_step + v_step

	_mesh_root.rotation.x += delta * _spin_speed
	_mesh_root.rotation.z += delta * _spin_speed * 0.5

	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.03
		_spawn_trail()

	if _spawn_dist > 1.5:
		var space := get_world_3d().direct_space_state
		if space:
			var query := PhysicsRayQueryParameters3D.new()
			query.from = global_position
			query.to = next_pos
			query.collision_mask = 1
			if _shooter != null:
				query.exclude = [_shooter]
			var result := space.intersect_ray(query)
			if not result.is_empty():
				global_position = result.position
				_on_impact()
				return

	global_position = next_pos
	_spawn_dist += h_step.length() + abs(v_step.y)

	_check_hit()

	if global_position.y < -5.0:
		_on_impact()

func _check_hit() -> void:
	if _spawn_dist < 1.5:
		return
	for ch in _get_characters():
		if ch == _shooter:
			continue
		var offset: Vector3 = global_position - ch.global_position
		if offset.length() < 1.0:
			_on_impact()
			return

func _get_characters() -> Array:
	var chars: Array = []
	var root := get_tree().current_scene
	if root == null:
		return chars
	_scan_characters(root, chars)
	return chars

func _scan_characters(node: Node, chars: Array) -> void:
	if node is CharacterBase and node.is_alive:
		chars.append(node)
	for i in node.get_child_count():
		_scan_characters(node.get_child(i), chars)

func _spawn_trail() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mat := MeshBuilder.emit_mat(
		Color(1.0, 0.55, 0.0, 0.5),
		Color(1.0, 0.7, 0.2), 3.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.05
	sph.height = 0.10
	mi.mesh = sph
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = global_position - _direction * 0.06

	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 0.1), 0.35)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(mi.queue_free).set_delay(0.4)

func _deal_aoe_damage() -> void:
	for ch in _get_characters():
		if ch == _shooter:
			continue
		var offset: Vector3 = global_position - ch.global_position
		offset.y = 0.0
		if offset.length() < _aoe_radius:
			ch.take_damage(_damage, _shooter, 0)

func _on_impact() -> void:
	if _hit_something:
		return
	_hit_something = true

	_deal_aoe_damage()

	var parent := get_parent()
	if parent:
		var pool := SlowingPool.new()
		parent.add_child(pool)
		pool.setup(global_position, 3.0, _aoe_radius, _shooter)

	_spawn_explosion_vfx()

	set_physics_process(false)
	get_tree().create_timer(0.3).timeout.connect(queue_free)

func _spawn_explosion_vfx() -> void:
	var parent := get_parent()
	if parent == null:
		return

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.1)
	flash.light_energy = 20.0
	flash.omni_range = 8.0
	flash.light_specular = 0.0
	parent.add_child(flash)
	flash.global_position = global_position
	get_tree().create_timer(0.1).timeout.connect(
		func(): if is_instance_valid(flash): flash.queue_free())

	for i in range(8):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.5 + randf_range(0.0, 0.3), 0.0, 0.7)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.05
		sph.height = 0.1
		mi.mesh = sph
		mi.material_override = mat
		mi.position = Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", mi.position * 4.0, 0.25)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
		tw.tween_callback(mi.queue_free).set_delay(0.3)
