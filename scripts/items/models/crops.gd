class_name FruitMeshes

static func pumpkin(p: Node3D) -> void: 
	var piv = ItemMeshShared.fruit_pivot(p)
	var orange := Color(0.85, 0.45, 0.10)
	var light := Color(0.92, 0.55, 0.15)
	var dark := Color(0.70, 0.35, 0.08)
	var stem := Color(0.35, 0.30, 0.10)
	ItemMeshShared.add_cube(piv, 0, 0, 0, 4.0, 3.5, 3.5, orange)
	ItemMeshShared.add_cube(piv, -1.5, 0, 0, 1.0, 3.2, 3.8, light)
	ItemMeshShared.add_cube(piv, 1.5, 0, 0, 1.0, 3.2, 3.8, light)
	ItemMeshShared.add_cube(piv, -2.5, 0, 0, 0.6, 2.8, 3.2, dark)
	ItemMeshShared.add_cube(piv, 2.5, 0, 0, 0.6, 2.8, 3.2, dark)
	ItemMeshShared.add_cube(piv, 0, 0, -1.5, 3.8, 3.2, 1.0, light)
	ItemMeshShared.add_cube(piv, 0, 0, 1.5, 3.8, 3.2, 1.0, light)
	ItemMeshShared.add_cube(piv, 0, 2.2, 0, 2.0, 0.5, 2.0, dark.darkened(0.1))
	ItemMeshShared.add_cube(piv, 0, 2.8, 0, 0.6, 1.2, 0.6, stem)

