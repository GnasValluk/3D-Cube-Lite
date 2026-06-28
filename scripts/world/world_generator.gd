extends Node3D

@export var ground_size:  float = 130.0
@export var ground_thick: float = 0.5
@export var patch_res:    int   = 60
@export var tree_count:   int   = 220
@export var grass_count:  int   = 500
@export var spawn_seed:   int   = 42

const TILE_COLORS: Array[Dictionary] = [
	{ "base": Color(0.06, 0.22, 0.16), "emit": Color(0.08, 0.28, 0.20), "pow": 0.3 },
	{ "base": Color(0.03, 0.12, 0.08), "emit": Color(0.05, 0.16, 0.10), "pow": 0.2 },
	{ "base": Color(0.06, 0.20, 0.14), "emit": Color(0.10, 0.30, 0.20), "pow": 0.3 },
	{ "base": Color(0.04, 0.15, 0.10), "emit": Color(0.06, 0.20, 0.14), "pow": 0.2 },
	{ "base": Color(0.05, 0.28, 0.18), "emit": Color(0.08, 0.35, 0.22), "pow": 0.4 },
]

const C_FOL: Color = Color(0.10, 0.55, 0.40)
const C_FOL_EMIT: Color = Color(0.08, 0.45, 0.30)
const C_TRUNK: Color = Color(0.04, 0.10, 0.07)
const C_GRS: Color = Color(0.06, 0.25, 0.18)
const C_GRS_EMIT: Color = Color(0.08, 0.32, 0.22)

var _noise_biome: FastNoiseLite
var _noise_warp: FastNoiseLite

var _mat_gnd: Array[StandardMaterial3D] = []
var _mat_trunk: StandardMaterial3D
var _mat_fol: StandardMaterial3D
var _mat_grs: StandardMaterial3D
var _mat_grs_neon: StandardMaterial3D

func _ready() -> void:
	_noise_biome = FastNoiseLite.new()
	_noise_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_biome.seed = spawn_seed
	_noise_biome.frequency = 0.008
	_noise_warp = FastNoiseLite.new()
	_noise_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_warp.seed = spawn_seed + 99
	_noise_warp.frequency = 0.022

	for t in TILE_COLORS:
		_mat_gnd.append(_flat_emit(t["base"] as Color, t["emit"] as Color, t["pow"] as float))
	_mat_trunk = _flat(C_TRUNK)
	_mat_fol = _flat_emit(C_FOL, C_FOL_EMIT, 2.0)
	_mat_grs = _flat(C_GRS)
	_mat_grs_neon = _flat_emit(C_GRS, C_GRS_EMIT, 0.8)
	generate()

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = 1.0
	m.metallic_specular = 0.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _flat_emit(albedo: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m := _flat(albedo)
	if energy > 0.0:
		m.emission_enabled = true; m.emission = emit
		m.emission_energy_multiplier = energy
	return m

func _biome_at(wx: float, wz: float) -> int:
	var wx_off: float = _noise_warp.get_noise_2d(wx, wz + 100.0) * 18.0
	var wz_off: float = _noise_warp.get_noise_2d(wx + 100.0, wz) * 18.0
	var n: float = (_noise_biome.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5
	if n < 0.20: return 0
	elif n < 0.40: return 1
	elif n < 0.60: return 2
	elif n < 0.80: return 3
	return 4

func generate() -> void:
	for c in get_children():
		c.queue_free()
	_spawn_ground()

	var rng := RandomNumberGenerator.new()
	rng.seed = spawn_seed + 1

	for _i in range(grass_count):
		var px: float = rng.randf_range(-ground_size * 0.47, ground_size * 0.47)
		var pz: float = rng.randf_range(-ground_size * 0.47, ground_size * 0.47)
		_spawn_grass_patch(Vector3(px, 0.0, pz), rng)

	for _i in range(tree_count):
		var px: float  = rng.randf_range(-ground_size * 0.46, ground_size * 0.46)
		var pz: float  = rng.randf_range(-ground_size * 0.46, ground_size * 0.46)
		var sf: float = rng.randf_range(0.55, 1.40)
		_spawn_tree(Vector3(px, 0.0, pz), sf, rng)

func _spawn_ground() -> void:
	var sb := StaticBody3D.new()
	sb.position = Vector3(0.0, -ground_thick * 0.5, 0.0)
	add_child(sb)
	var col := CollisionShape3D.new()
	var cs  := BoxShape3D.new()
	cs.size  = Vector3(ground_size, ground_thick, ground_size)
	col.shape = cs; sb.add_child(col)

	var ps: float = ground_size / float(patch_res)
	var half: float = ground_size * 0.5
	for xi in range(patch_res):
		for zi in range(patch_res):
			var wx: float = -half + (float(xi) + 0.5) * ps
			var wz: float = -half + (float(zi) + 0.5) * ps
			var b: int = _biome_at(wx, wz)
			var mi  := MeshInstance3D.new()
			var msh := BoxMesh.new()
			msh.size = Vector3(ps, ground_thick, ps)
			mi.mesh  = msh; mi.position = Vector3(wx, 0.0, wz)
			mi.material_override = _mat_gnd[b]
			sb.add_child(mi)

func _spawn_grass_patch(base: Vector3, rng: RandomNumberGenerator) -> void:
	for _i in range(rng.randi_range(2, 5)):
		var ox: float = rng.randf_range(-0.28, 0.28)
		var oz: float = rng.randf_range(-0.28, 0.28)
		if rng.randf() < 0.6:
			var h: float = rng.randf_range(0.12, 0.28)
			var mi := MeshInstance3D.new()
			var msh := BoxMesh.new()
			msh.size = Vector3(0.05, h, 0.03)
			mi.mesh  = msh
			mi.position = base + Vector3(ox, h * 0.5, oz)
			mi.rotation_degrees.z = rng.randf_range(-20.0, 20.0)
			mi.material_override  = _mat_grs_neon
			add_child(mi)
		else:
			var r: float = rng.randf_range(0.06, 0.14)
			var mi := MeshInstance3D.new()
			var msh := SphereMesh.new()
			msh.radius = r; msh.height = r * 2.0
			msh.radial_segments = 6; msh.rings = 4
			mi.mesh  = msh; mi.scale = Vector3(1.0, 0.4, 1.0)
			mi.position = base + Vector3(ox, r * 0.2, oz)
			mi.material_override = _mat_grs_neon
			add_child(mi)

func _spawn_tree(base: Vector3, sf: float, rng: RandomNumberGenerator) -> void:
	var trunk_h: float = rng.randf_range(0.9, 1.9) * sf
	_add_cylinder(base + Vector3(0, trunk_h * 0.5, 0), 0.07 * sf, trunk_h, _mat_trunk)

	for i in range(rng.randi_range(2, 4)):
		var ay: float = deg_to_rad(float(i) * (360.0 / float(rng.randi_range(2, 4)))
						+ rng.randf_range(-25.0, 25.0))
		var blen: float = rng.randf_range(0.35, 0.75) * sf
		var bh:   float = trunk_h * rng.randf_range(0.40, 0.82)
		var bdir  := Vector3(sin(ay), rng.randf_range(0.22, 0.48), cos(ay)).normalized()
		_add_cylinder_dir(base + Vector3(0, bh, 0) + bdir * blen * 0.5,
						  0.036 * sf, blen, bdir, _mat_trunk)
		var tip := base + Vector3(0, bh, 0) + bdir * blen
		var tr: float = rng.randf_range(0.20, 0.40) * sf
		_add_sphere(tip + Vector3(0, tr * 0.4, 0), tr, _mat_fol)

	for k in range(rng.randi_range(3, 6)):
		var ang: float = deg_to_rad(float(k) * 60.0 + rng.randf_range(0.0, 40.0))
		var sp:  float = rng.randf_range(0.0, 0.28) * sf
		var cr:  float = rng.randf_range(0.26, 0.56) * sf
		_add_sphere(base + Vector3(sin(ang) * sp,
					trunk_h + cr * 0.58 + rng.randf_range(-0.08, 0.24) * sf,
					cos(ang) * sp), cr, _mat_fol)

	var lt := OmniLight3D.new()
	lt.position    = base + Vector3(0.0, trunk_h * 0.85, 0.0)
	lt.light_color  = Color(0.08, 0.45, 0.35)
	lt.light_energy = 1.5; lt.omni_range = 5.5
	add_child(lt)

func _add_sphere(pos: Vector3, r: float, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var msh := SphereMesh.new()
	msh.radius = r; msh.height = r * 2.0
	msh.radial_segments = 10; msh.rings = 6
	mi.mesh = msh; mi.position = pos; mi.material_override = mat
	add_child(mi)

func _add_cylinder(pos: Vector3, r: float, h: float,
				   mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var msh := CylinderMesh.new()
	msh.top_radius = r * 0.65; msh.bottom_radius = r; msh.height = h
	mi.mesh = msh; mi.position = pos; mi.material_override = mat
	add_child(mi)

func _add_cylinder_dir(pos: Vector3, r: float, length: float,
					   dir: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var msh := CylinderMesh.new()
	msh.top_radius = r * 0.45; msh.bottom_radius = r; msh.height = length
	mi.mesh = msh; mi.position = pos; mi.material_override = mat
	var axis := Vector3.UP.cross(dir)
	if axis.length_squared() > 0.0001:
		mi.transform = mi.transform.rotated(axis.normalized(), Vector3.UP.angle_to(dir))
		mi.position  = pos
	add_child(mi)
