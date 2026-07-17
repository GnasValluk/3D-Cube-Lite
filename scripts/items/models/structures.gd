class_name StructuresMesh

static func chest(p: Node3D) -> void:
	var wood := Color(0.50, 0.32, 0.10)
	var lid := Color(0.55, 0.35, 0.12)
	var metal := Color(0.70, 0.65, 0.40)
	ItemMeshShared.add_cube(p, 0, 0, 0, 2.5, 1.5, 2.5, wood)
	ItemMeshShared.add_cube(p, 0, 2, 0, 2.5, 0.8, 2.5, lid)
	ItemMeshShared.add_cube(p, 0, 1.5, 0, 1.5, 0.3, 1.5, metal)

static func gate(p: Node3D) -> void:
	var frame := Color(0.10, 0.50, 0.45)
	var glow := Color(0.20, 0.70, 0.65)
	ItemMeshShared.add_cube(p, -2, 0, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, -2, 1, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, -2, 2, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, -2, 3, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 2, 0, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 2, 1, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 2, 2, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 2, 3, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 0, 3, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 0, 4, 0, 3.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 0, 1, 0, 2.0, 1.0, 0.5, glow)
