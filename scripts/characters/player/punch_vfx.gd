extends Node3D
class_name PunchVFX

var _mat: StandardMaterial3D

func _init(power: float = 1.0, color: Color = Color(0.85, 0.72, 0.40)) -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 4.0 * power
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh(0.06, 0.22 * power)
	ring.material_override = _mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	for i in 6:
		var a := float(i) / 6.0 * TAU
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(color.r, color.g, color.b, 0.6)
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.emission_enabled = true
		sm.emission = color
		sm.emission_energy_multiplier = 3.0 * power
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var li := MeshInstance3D.new()
		li.mesh = _ray_mesh(0.28 * power)
		li.material_override = sm
		li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		li.rotation = Vector3(0, 0, a)
		add_child(li)
		li.scale = Vector3(1, 1, 0.3)

	var tween := create_tween().set_parallel()
	tween.tween_method(func(a: float): _mat.albedo_color.a = a, 0.5, 0.0, 0.22)
	tween.tween_method(func(e: float): _mat.emission_energy_multiplier = e, 4.0 * power, 0.0, 0.22)
	tween.tween_property(self, "scale", Vector3(1.8, 1.8, 1.8), 0.22)
	tween.tween_callback(queue_free).set_delay(0.22)

static func _ring_mesh(inner: float, outer: float) -> ArrayMesh:
	var segs := 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(segs + 1):
		var a := float(i) / float(segs) * TAU
		var c := cos(a)
		var s := sin(a)
		st.add_vertex(Vector3(outer * c, outer * s, 0.0))
		st.add_vertex(Vector3(inner * c, inner * s, 0.0))
	return st.commit()

static func _ray_mesh(len: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(Vector3.ZERO)
	st.add_vertex(Vector3(len, 0.005, 0.0))
	st.add_vertex(Vector3(len, -0.005, 0.0))
	return st.commit()
