class_name FallbackMesh

static func item_voxel(p: Node3D, item_id: String) -> void:
	var tex_path: String = ItemDatabase.get_icon_2d_path(item_id)
	if tex_path.is_empty():
		default(p)
		return
	var mesh_path := tex_path.replace("res://assets/icon_items/", "res://assets/models_items/").replace(".png", ".tres")
	if ResourceLoader.exists(mesh_path):
		var mi := MeshInstance3D.new()
		mi.mesh = load(mesh_path)
		p.add_child(mi)
	else:
		quad_fallback(p, tex_path)

static func quad_fallback(p: Node3D, tex_path: String) -> void:
	var tex := load(tex_path) as Texture2D
	if not tex:
		default(p)
		return
	var mi := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.5 * ItemMeshShared.V * 4, 2.5 * ItemMeshShared.V * 4)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = 1.5 * ItemMeshShared.V
	p.add_child(mi)

static func default(p: Node3D) -> void:
	ItemMeshShared.add_cube(p, 0, 0, 0, 3.0, 3.0, 3.0, Color(0.50, 0.50, 0.50))
