class_name SlowingPool
extends Node3D

var _duration: float = 3.0
var _radius: float = 2.5
var _age: float = 0.0
var _mesh_instance: MeshInstance3D
var _area: Area3D
var _slowed_entries: Dictionary = {}
var _shooter: Node = null
func setup(pos: Vector3, duration: float = 3.0, radius: float = 2.5, shooter: Node = null) -> void:
	_shooter = shooter
	_duration = duration
	_radius = radius
	global_position = pos + Vector3(0, 0.02, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.1, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_mesh_instance = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = _radius
	ring.bottom_radius = _radius
	ring.height = 0.04
	ring.radial_segments = 24
	_mesh_instance.mesh = ring
	_mesh_instance.material_override = mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = Color(1.0, 0.7, 0.15, 0.15)
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var inner := MeshInstance3D.new()
	var inner_mesh := CylinderMesh.new()
	inner_mesh.top_radius = _radius - 0.15
	inner_mesh.bottom_radius = _radius - 0.15
	inner_mesh.height = 0.02
	inner_mesh.radial_segments = 24
	inner.mesh = inner_mesh
	inner.material_override = inner_mat
	inner.position = Vector3(0, 0.01, 0)
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inner)

	_area = Area3D.new()
	var shape := CollisionShape3D.new()
	var col := CylinderShape3D.new()
	col.radius = _radius
	col.height = 0.5
	shape.shape = col
	_area.add_child(shape)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	add_child(_area)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = _duration
	timer.timeout.connect(_on_expire)
	add_child(timer)
	timer.start()

func _process(delta: float) -> void:
	_age += delta

func _on_body_entered(body: Node) -> void:
	if body is CharacterBase and body != _get_shooter():
		if _slowed_entries.has(body):
			return
		_slowed_entries[body] = true
		if body.effects != null:
			# Làm chậm cấp 3 (giảm 50%) trong thời gian còn lại của hồ
			body.effects.apply_slow(3, maxf(_duration - _age, 0.5))

func _on_body_exited(body: Node) -> void:
	if body is CharacterBase:
		_restore_slow(body)

func _get_shooter() -> Node:
	return _shooter

func _restore_slow(body: Node) -> void:
	if not _slowed_entries.has(body):
		return
	_slowed_entries.erase(body)
	if body is CharacterBase and body.effects != null:
		body.effects.clear_slow()

func _on_expire() -> void:
	for body in _slowed_entries.keys():
		if is_instance_valid(body):
			_restore_slow(body)
	_slowed_entries.clear()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mesh_instance, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_property(_mesh_instance.material_override, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(queue_free).set_delay(0.35)
