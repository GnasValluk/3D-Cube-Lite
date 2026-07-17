class_name CreaturesMesh

static func fish(p: Node3D, body_color: Color) -> void:
	var belly := body_color.lightened(0.30)
	var dark := body_color.darkened(0.25)
	var tail := Color(0.70, 0.55, 0.30)
	ItemMeshShared.add_cube(p, -2, 0, 0, 2, 1.5, 1.2, dark)
	ItemMeshShared.add_cube(p, 0, 0, 0, 2, 1.8, 1.5, body_color)
	ItemMeshShared.add_cube(p, 2, 0, 0, 2, 1.5, 1.2, body_color)
	ItemMeshShared.add_cube(p, 4, 0, 0, 1.5, 0.8, 2.2, tail)
	ItemMeshShared.add_cube(p, 0, 2, 0, 0.8, 1.2, 1.2, dark)
	ItemMeshShared.add_cube(p, 0, -2, 0, 1.2, 0.8, 1.2, belly)
	ItemMeshShared.add_cube(p, -2, 1, 1.5, 0.6, 0.6, 0.6, Color(0.05, 0.05, 0.05))
	ItemMeshShared.add_cube(p, -2, 1, -1.5, 0.6, 0.6, 0.6, Color(0.05, 0.05, 0.05))

static func shrimp(p: Node3D) -> void:
	var body := Color(0.85, 0.35, 0.20)
	var dark := body.darkened(0.25)
	ItemMeshShared.add_cube(p, -2, 0, 0, 1.5, 1.0, 1.0, dark)
	ItemMeshShared.add_cube(p, 0, 0, 0, 2.0, 1.2, 1.2, body)
	ItemMeshShared.add_cube(p, 2, 0, 0, 2.0, 1.5, 1.2, body.lightened(0.15))
	ItemMeshShared.add_cube(p, 4, 0, 0, 1.5, 0.6, 1.8, dark)
	ItemMeshShared.add_cube(p, 0, 2, 0, 0.5, 1.5, 0.5, dark)
	ItemMeshShared.add_cube(p, -2, 0, 1.8, 3.0, 0.3, 0.5, body)
	ItemMeshShared.add_cube(p, -2, 1.5, 1.5, 0.3, 0.3, 1.5, dark)
	ItemMeshShared.add_cube(p, -2, 1.5, -1.5, 0.3, 0.3, 1.5, dark)
