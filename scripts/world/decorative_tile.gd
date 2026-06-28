extends Node3D
class_name DecorativeTile

const VOXEL: float = 0.50
const TW: int = 5
const TD: int = 5

enum TileType {
	GRASS,
	DARK_GRASS,
	FLOWER,
	MUSHROOM,
	GREEN,
}

var tile_type: int = TileType.GRASS

func _ready() -> void:
	_build()

func _build() -> void:
	var base_color: Color
	var emissive_color: Color
	var emit_power: float
	var has_flowers: bool = false
	var has_mushrooms: bool = false
	var has_grass: bool = false

	match tile_type:
		TileType.GRASS:
			base_color = Color(0.06, 0.22, 0.16)
			emissive_color = Color(0.08, 0.28, 0.20)
			emit_power = 0.3
			has_grass = true
		TileType.DARK_GRASS:
			base_color = Color(0.03, 0.12, 0.08)
			emissive_color = Color(0.05, 0.16, 0.10)
			emit_power = 0.2
			has_grass = true
		TileType.FLOWER:
			base_color = Color(0.06, 0.20, 0.14)
			emissive_color = Color(0.10, 0.30, 0.20)
			emit_power = 0.3
			has_flowers = true
		TileType.MUSHROOM:
			base_color = Color(0.04, 0.15, 0.10)
			emissive_color = Color(0.06, 0.20, 0.14)
			emit_power = 0.2
			has_mushrooms = true
		TileType.GREEN:
			base_color = Color(0.05, 0.28, 0.18)
			emissive_color = Color(0.08, 0.35, 0.22)
			emit_power = 0.4

	var off: Vector3 = Vector3(-(TW - 1) * VOXEL * 0.5, 0.0, -(TD - 1) * VOXEL * 0.5)
	var base_mat: StandardMaterial3D = _make_mat(base_color, emissive_color, emit_power)

	for x in range(TW):
		for z in range(TD):
			var mi: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(VOXEL, VOXEL, VOXEL)
			mi.mesh = box
			mi.material_override = base_mat
			mi.position = off + Vector3(x * VOXEL, -VOXEL * 0.5, z * VOXEL)
			add_child(mi)

	var body: StaticBody3D = StaticBody3D.new()
	var bcol: CollisionShape3D = CollisionShape3D.new()
	var bcs: BoxShape3D = BoxShape3D.new()
	bcs.size = Vector3(TW * VOXEL, VOXEL, TD * VOXEL)
	bcol.shape = bcs
	bcol.position.y = -VOXEL * 0.5
	body.add_child(bcol)
	add_child(body)

	if has_grass:
		var grass_mat: StandardMaterial3D = _make_mat(Color(0.06, 0.25, 0.18), Color(0.08, 0.32, 0.22), 0.4)
		for i in range(8):
			var x: int = randi_range(0, TW - 1)
			var z: int = randi_range(0, TD - 1)
			var mi: MeshInstance3D = MeshInstance3D.new()
			var gb: BoxMesh = BoxMesh.new()
			gb.size = Vector3(VOXEL * 0.15, VOXEL * 0.15 + randf() * VOXEL * 0.2, VOXEL * 0.15)
			mi.mesh = gb
			mi.material_override = grass_mat
			mi.position = off + Vector3(x * VOXEL, 0.0, z * VOXEL) + Vector3(0.0, VOXEL * 0.25, 0.0)
			add_child(mi)

	if has_flowers:
		var flower_colors: Array[Color] = [
			Color(0.10, 0.60, 0.50),
			Color(0.15, 0.50, 0.60),
			Color(0.80, 0.55, 0.10),
			Color(0.10, 0.70, 0.55),
		]
		for i in range(3):
			var x: int = randi_range(0, TW - 1)
			var z: int = randi_range(0, TD - 1)
			var clr: Color = flower_colors[randi_range(0, flower_colors.size() - 1)]
			var fm: StandardMaterial3D = StandardMaterial3D.new()
			fm.albedo_color = clr
			fm.emission_enabled = true
			fm.emission = clr
			fm.emission_energy_multiplier = 2.0
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var mi: MeshInstance3D = MeshInstance3D.new()
			var sph: SphereMesh = SphereMesh.new()
			sph.radius = VOXEL * 0.10
			sph.height = VOXEL * 0.20
			mi.mesh = sph
			mi.material_override = fm
			mi.position = off + Vector3(x * VOXEL, VOXEL * 0.25, z * VOXEL)
			add_child(mi)

	if has_mushrooms:
		var stem_mat: StandardMaterial3D = _make_mat(Color(0.05, 0.10, 0.08), Color(0.07, 0.15, 0.10), 0.1)
		var cap_color: Color = Color(0.08, 0.35, 0.30)
		for i in range(2):
			var x: int = randi_range(0, TW - 1)
			var z: int = randi_range(0, TD - 1)
			var p: Vector3 = off + Vector3(x * VOXEL, 0.0, z * VOXEL)
			var stem: MeshInstance3D = MeshInstance3D.new()
			var sb: BoxMesh = BoxMesh.new()
			sb.size = Vector3(VOXEL * 0.12, VOXEL * 0.3, VOXEL * 0.12)
			stem.mesh = sb
			stem.material_override = stem_mat
			stem.position = p + Vector3(0.0, VOXEL * 0.15, 0.0)
			add_child(stem)
			var cm: StandardMaterial3D = StandardMaterial3D.new()
			cm.albedo_color = cap_color
			cm.emission_enabled = true
			cm.emission = cap_color
			cm.emission_energy_multiplier = 1.5
			cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var cap: MeshInstance3D = MeshInstance3D.new()
			var cs: SphereMesh = SphereMesh.new()
			cs.radius = VOXEL * 0.14
			cs.height = VOXEL * 0.14
			cap.mesh = cs
			cap.material_override = cm
			cap.position = p + Vector3(0.0, VOXEL * 0.3, 0.0)
			add_child(cap)

func _make_mat(albedo: Color, emissive: Color, emit_power: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = albedo
	if emit_power > 0.0:
		m.emission_enabled = true
		m.emission = emissive
		m.emission_energy_multiplier = emit_power
	return m
