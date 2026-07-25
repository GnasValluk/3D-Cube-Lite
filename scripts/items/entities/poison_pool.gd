class_name PoisonPool
extends Node3D

var _damage: int = 5
var _radius: float = 7.0
var _duration: float = 4.0
var _tick_interval: float = 0.5
var _shooter: Node = null
var _mesh_instance: MeshInstance3D
var _age: float = 0.0

func setup(pos: Vector3, dmg: int, radius: float, duration: float, shooter: Node) -> void:
	_damage = dmg
	_radius = radius
	_duration = duration
	_shooter = shooter
	global_position = pos + Vector3(0, 0.02, 0)

	var col := Color(0.25, 0.55, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.25)
	mat.emission_enabled = true
	mat.emission_color = col
	mat.emission_energy_multiplier = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true

	_mesh_instance = MeshInstance3D.new()
	var msh := CylinderMesh.new()
	msh.top_radius = _radius
	msh.bottom_radius = _radius
	msh.height = 0.04
	msh.radial_segments = 32
	_mesh_instance.mesh = msh
	_mesh_instance.material_override = mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = Color(col.r, col.g, col.b, 0.10)
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.no_depth_test = true

	var inner := MeshInstance3D.new()
	var inner_mesh := CylinderMesh.new()
	inner_mesh.top_radius = _radius - 0.2
	inner_mesh.bottom_radius = _radius - 0.2
	inner_mesh.height = 0.02
	inner_mesh.radial_segments = 32
	inner.mesh = inner_mesh
	inner.material_override = inner_mat
	inner.position = Vector3(0, 0.01, 0)
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inner)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.35)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = col
	ring_mat.emission_energy_multiplier = 0.6
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.no_depth_test = true

	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = _radius - 0.05
	tor.outer_radius = 0.05
	tor.ring_segments = 16
	tor.rings = 32
	ring.mesh = tor
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	get_tree().create_timer(_duration).timeout.connect(_on_expire)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		set_physics_process(false)
		return
	var elapsed := _age
	var prev_tick := int((elapsed - delta) / _tick_interval)
	var cur_tick := int(elapsed / _tick_interval)
	if cur_tick > prev_tick:
		_tick()

func _tick() -> void:
	for ch in _get_characters():
		if ch == _shooter:
			continue
		var offset: Vector3 = global_position - ch.global_position
		offset.y = 0.0
		if offset.length() < _radius:
			ch.take_damage(_damage, _shooter, 1)

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

func _on_expire() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mesh_instance, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	tw.tween_property(_mesh_instance.material_override, "albedo_color:a", 0.0, 0.4)
	tw.tween_property(_mesh_instance.material_override, "emission_energy_multiplier", 0.0, 0.4)
	tw.tween_callback(queue_free).set_delay(0.45)
