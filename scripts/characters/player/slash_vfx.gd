extends Node3D
class_name SlashVFX

var _material: StandardMaterial3D

func _init(arc_angle: float = 70.0, outer_r: float = 0.5, inner_r: float = 0.12, color: Color = Color.WHITE) -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1, 1, 1, 0.6)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled = true
	_material.emission = Color(1, 1, 1)
	_material.emission_energy_multiplier = 3.0
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mi := MeshInstance3D.new()
	mi.mesh = _build_arc_mesh(arc_angle, outer_r, inner_r)
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var tween := create_tween().set_parallel()
	tween.tween_method(func(a: float): _material.albedo_color.a = a, 0.6, 0.0, 0.3)
	tween.tween_method(func(e: float): _material.emission_energy_multiplier = e, 3.0, 0.0, 0.3)
	tween.tween_property(self, "scale", Vector3(1.4, 1.4, 1.4), 0.3)
	tween.tween_callback(queue_free).set_delay(0.3)

static func _build_arc_mesh(half_deg: float, outer_r: float, inner_r: float) -> ArrayMesh:
	var segs := 10
	var half_a := deg_to_rad(half_deg)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var a := lerpf(-half_a, half_a, t)
		var ca := cos(a)
		var sa := sin(a)
		st.add_vertex(Vector3(outer_r * ca, outer_r * sa, 0.0))
		st.add_vertex(Vector3(inner_r * ca, inner_r * sa, 0.0))
	return st.commit()
