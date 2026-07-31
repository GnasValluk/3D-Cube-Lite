class_name FallbackMesh

static func item_voxel(p: Node3D, item_id: String) -> void:
	default(p)

static func default(p: Node3D) -> void:
	ItemMeshShared.add_cube(p, 0, 0, 0, 3.0, 3.0, 3.0, Color(0.50, 0.50, 0.50))
