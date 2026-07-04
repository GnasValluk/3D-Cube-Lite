extends Node3D
class_name Bobber3D

var _player: Node3D
var _rod_pivot: Node3D
var _bitten: bool = false
var _reeling: bool = false
var _caught_item_id: String = ""
var _line_node: MeshInstance3D
var _bobber_mesh: MeshInstance3D
var _bite_timer: float = 0.0
var _bite_time: float = 0.0
var _bite_submerge: float = 0.0
var _bite_duration: float = 0.0
var _reel_progress: float = 0.0
var _reel_speed: float = 6.0
var _time: float = 0.0
var _water_y: float = 0.46
var _drift_offset: Vector2
var _cast_progress: float = 0.0
var _cast_speed: float = 0.6
var _cast_start: Vector3
var _cast_target: Vector3
var _casting: bool = true
var _landed_pos: Vector3
var _line_mat: StandardMaterial3D

func setup(player: Node3D, target_pos: Vector3, rod_pivot: Node3D = null) -> void:
	_player = player
	_rod_pivot = rod_pivot
	_water_y = 0.46
	_drift_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	_cast_start = _get_line_origin()
	_cast_target = target_pos
	_cast_target.y = _water_y + 0.05
	_landed_pos = _cast_target
	global_position = _cast_start
	_bite_time = randf_range(5.0, 40.0)
	_caught_item_id = _random_catch()
	_make_line_mat()
	_make_bobber()
	_make_line()

func _random_catch() -> String:
	var pool := ["ca_chep", "ca_ro", "ca_tram", "ca_mong", "ca_vang", "ca_linh"]
	return pool[randi() % pool.size()]

func _make_line_mat() -> void:
	_line_mat = StandardMaterial3D.new()
	_line_mat.albedo_color = Color(0.35, 0.30, 0.22)
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.metallic = 0.0
	_line_mat.roughness = 1.0

func _make_bobber() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.90, 0.30, 0.10)
	mat.metallic = 0.3
	mat.roughness = 0.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	_bobber_mesh = MeshInstance3D.new()
	_bobber_mesh.mesh = sphere
	_bobber_mesh.material_override = mat
	_bobber_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bobber_mesh)

func _make_line() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for _i in range(13):
		st.add_vertex(Vector3.ZERO)
	_line_node = MeshInstance3D.new()
	_line_node.mesh = st.commit()
	_line_node.material_override = _line_mat
	_line_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line_node)

func _get_line_origin() -> Vector3:
	if _rod_pivot and is_instance_valid(_rod_pivot):
		return _rod_pivot.global_transform * Vector3(0, 0.55, 0)
	return _player.global_position + Vector3(0, 1.2, 0)

func _update_line() -> void:
	if _player == null: return
	var origin := _get_line_origin()
	var bob := global_position
	var local_origin := to_local(origin)
	var local_bob := Vector3.ZERO
	var dx := local_bob.x - local_origin.x
	var dz := local_bob.z - local_origin.z
	var h_dist := sqrt(dx * dx + dz * dz)
	var sag: float = min(h_dist * 0.08, 1.2)
	var segments := maxi(4, mini(20, int(h_dist * 3.0)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var p: Vector3 = local_origin.lerp(local_bob, t)
		p.y -= sag * sin(t * PI)
		st.add_vertex(p)
	_line_node.mesh = st.commit()

func _process(delta: float) -> void:
	_time += delta

	if _casting:
		_cast_progress += delta / _cast_speed
		var t: float = clamp(_cast_progress, 0.0, 1.0)
		var pos: Vector3 = _cast_start.lerp(_cast_target, t)
		pos.y += sin(t * PI) * 1.5
		global_position = pos
		if t >= 1.0:
			_casting = false
			_landed_pos = _cast_target
		return

	if _reeling:
		_reel_progress += delta * _reel_speed
		var target := _player.global_position + Vector3(0, 0.8, 0)
		global_position = global_position.lerp(target, min(_reel_progress * delta * 4.0, 1.0))
		if global_position.distance_squared_to(target) < 0.25:
			_finish_reel()
			return
		_update_line()
		return

	var drift := Vector2(
		sin(_time * 0.5 + _drift_offset.x) * 0.06,
		cos(_time * 0.7 + _drift_offset.y) * 0.06
	)
	global_position.x = _landed_pos.x + drift.x
	global_position.z = _landed_pos.z + drift.y

	var bob := sin(_time * 2.0) * 0.03
	global_position.y = _water_y + 0.05 + bob

	if _bitten:
		_bite_duration -= delta
		_bite_submerge = move_toward(_bite_submerge, 0.08 if _bite_duration > 0 else 0.0, delta * 4.0)
		global_position.y = _water_y + 0.05 - _bite_submerge + bob
		if _bite_duration <= 0:
			_bitten = false
			_bite_timer = 0.0
			_bite_time = randf_range(8.0, 50.0)
			_caught_item_id = _random_catch()
		return

	_bite_timer += delta
	if _bite_timer >= _bite_time:
		_bitten = true
		_bite_duration = 1.5
		SFXManager.play_splash()

	_update_line()

func reel_in() -> bool:
	if _casting or _reeling: return false
	_reeling = true
	_reel_progress = 0.0
	return _bitten

func _finish_reel() -> void:
	if _player and _player.has_method("_on_bobber_done"):
		_player._on_bobber_done(_caught_item_id if _bitten else "")
	queue_free()
