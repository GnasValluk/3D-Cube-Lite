class_name ItemMeshShared

const V: float = 0.030

static func add_cube(p: Node3D, x: float, y: float, z: float, sx: float, sy: float, sz: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(sx * V, sy * V, sz * V)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	mi.mesh = mesh
	mi.position = Vector3(x * V, y * V, z * V)
	p.add_child(mi)

static func add_cube_shaded(p: Node3D, x: float, y: float, z: float, sx: float, sy: float, sz: float,
	color: Color, metalness: float = 0.0, roughness: float = 1.0, emissive: Color = Color(0, 0, 0)) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(sx * V, sy * V, sz * V)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metalness
	mat.roughness = roughness
	mat.emission = emissive
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	mi.mesh = mesh
	mi.position = Vector3(x * V, y * V, z * V)
	p.add_child(mi)

static func make_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

static func fruit_pivot(p: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.scale = Vector3(1.25, 1.25, 1.25)
	p.add_child(pivot)
	return pivot
