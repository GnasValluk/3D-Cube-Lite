extends Node3D
class_name HubWorld

const SIZE: float = 16.0

func _ready() -> void:
	_build()
	_mark_explored()

func _mark_explored() -> void:
	var sys := get_node_or_null("ExploreSystem") as ExploreSystem
	if sys:
		sys.mark_all_explored_in_rect(-SIZE * 0.5, SIZE * 0.5, -SIZE * 0.5, SIZE * 0.5, Color(0.08, 0.26, 0.22))

func _build() -> void:
	var sb := StaticBody3D.new()
	add_child(sb)

	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(SIZE, 0.5, SIZE)
	col.shape = cs; col.position.y = -0.25
	sb.add_child(col)

	var mi := MeshInstance3D.new()
	var msh := BoxMesh.new()
	msh.size = Vector3(SIZE, 0.5, SIZE)
	mi.mesh = msh
	mi.position.y = -0.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.26, 0.22)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	sb.add_child(mi)
